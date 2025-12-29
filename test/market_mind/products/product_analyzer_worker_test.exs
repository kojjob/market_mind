defmodule MarketMind.Products.ProductAnalyzerWorkerTest do
  use MarketMind.DataCase, async: false

  alias MarketMind.Products
  alias MarketMind.Products.ProductAnalyzerWorker
  alias MarketMind.Products.WebsiteFetcher
  alias MarketMind.LLM.Gemini

  # Sample analysis response from LLM
  @sample_analysis_json ~s({
    "product_name": "TestProduct",
    "tagline": "The best testing product",
    "value_propositions": ["Fast", "Reliable", "Easy to use"],
    "key_features": [
      {"name": "Feature 1", "description": "Does something great"},
      {"name": "Feature 2", "description": "Does something else"}
    ],
    "target_audience": "Developers and QA engineers",
    "pricing_model": "freemium",
    "industries": ["Technology", "Software"],
    "tone": "professional",
    "unique_differentiators": ["Best in class", "Open source"]
  })

  setup do
    # Create a user for our tests
    {:ok, user} =
      MarketMind.Repo.insert(%MarketMind.Accounts.User{
        email: "test@example.com",
        hashed_password: "hashedpassword123"
      })

    # Create a project to analyze
    {:ok, project} =
      Products.create_project(user, %{
        name: "Test Product",
        url: "https://testproduct.example.com"
      })

    %{user: user, project: project}
  end

  describe "perform/1" do
    test "successfully analyzes a project and stores results", %{project: project} do
      # Stub the website fetcher
      Req.Test.stub(WebsiteFetcher, fn conn ->
        Req.Test.html(conn, """
        <html>
          <head><title>TestProduct - The Best Testing Product</title></head>
          <body>
            <h1>TestProduct</h1>
            <p>The best testing product for developers.</p>
          </body>
        </html>
        """)
      end)

      # Stub the Gemini API
      Req.Test.stub(Gemini, fn conn ->
        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => @sample_analysis_json}]
              }
            }
          ]
        })
      end)

      # Run the worker
      job = %Oban.Job{args: %{"project_id" => project.id}}
      assert :ok = ProductAnalyzerWorker.perform(job)

      # Verify the project was updated
      updated_project = Products.get_project!(project.id)
      assert updated_project.analysis_status == "completed"
      assert updated_project.analyzed_at != nil
      assert updated_project.analysis_data != nil

      # Verify the analysis data structure
      analysis = updated_project.analysis_data
      assert analysis["product_name"] == "TestProduct"
      assert analysis["tagline"] == "The best testing product"
      assert is_list(analysis["value_propositions"])
      assert is_list(analysis["key_features"])
      assert analysis["target_audience"] == "Developers and QA engineers"
      assert analysis["pricing_model"] == "freemium"
    end

    test "updates status to analyzing before processing", %{project: project} do
      # Use a process to capture the intermediate status
      test_pid = self()

      Req.Test.stub(WebsiteFetcher, fn conn ->
        # Check the status during fetch
        current_project = Products.get_project!(project.id)
        send(test_pid, {:status_during_fetch, current_project.analysis_status})

        Req.Test.html(conn, "<html><head><title>Test</title></head><body>Content</body></html>")
      end)

      Req.Test.stub(Gemini, fn conn ->
        Req.Test.json(conn, %{
          "candidates" => [
            %{"content" => %{"parts" => [%{"text" => @sample_analysis_json}]}}
          ]
        })
      end)

      job = %Oban.Job{args: %{"project_id" => project.id}}
      assert :ok = ProductAnalyzerWorker.perform(job)

      # Verify intermediate status was "analyzing"
      assert_receive {:status_during_fetch, "analyzing"}
    end

    test "handles website fetch failure gracefully", %{project: project} do
      # Stub website fetcher to fail
      Req.Test.stub(WebsiteFetcher, fn conn ->
        conn
        |> Plug.Conn.put_status(404)
        |> Req.Test.html("<html><body>Not Found</body></html>")
      end)

      job = %Oban.Job{args: %{"project_id" => project.id}}
      assert {:error, _reason} = ProductAnalyzerWorker.perform(job)

      # Verify the project was marked as failed
      updated_project = Products.get_project!(project.id)
      assert updated_project.analysis_status == "failed"
    end

    test "handles LLM API failure gracefully", %{project: project} do
      # Website fetch succeeds
      Req.Test.stub(WebsiteFetcher, fn conn ->
        Req.Test.html(conn, "<html><head><title>Test</title></head><body>Content</body></html>")
      end)

      # LLM fails
      Req.Test.stub(Gemini, fn conn ->
        conn
        |> Plug.Conn.put_status(500)
        |> Req.Test.json(%{"error" => %{"message" => "Internal server error"}})
      end)

      job = %Oban.Job{args: %{"project_id" => project.id}}
      assert {:error, _reason} = ProductAnalyzerWorker.perform(job)

      # Verify the project was marked as failed
      updated_project = Products.get_project!(project.id)
      assert updated_project.analysis_status == "failed"
    end

    test "handles invalid JSON response from LLM", %{project: project} do
      Req.Test.stub(WebsiteFetcher, fn conn ->
        Req.Test.html(conn, "<html><head><title>Test</title></head><body>Content</body></html>")
      end)

      Req.Test.stub(Gemini, fn conn ->
        Req.Test.json(conn, %{
          "candidates" => [
            %{"content" => %{"parts" => [%{"text" => "This is not valid JSON"}]}}
          ]
        })
      end)

      job = %Oban.Job{args: %{"project_id" => project.id}}
      assert {:error, _reason} = ProductAnalyzerWorker.perform(job)

      updated_project = Products.get_project!(project.id)
      assert updated_project.analysis_status == "failed"
    end

    test "handles network timeout during website fetch", %{project: project} do
      Req.Test.stub(WebsiteFetcher, fn _conn ->
        raise Req.TransportError, reason: :timeout
      end)

      job = %Oban.Job{args: %{"project_id" => project.id}}
      assert {:error, _reason} = ProductAnalyzerWorker.perform(job)

      updated_project = Products.get_project!(project.id)
      assert updated_project.analysis_status == "failed"
    end

    test "handles non-existent project", %{} do
      non_existent_id = Ecto.UUID.generate()
      job = %Oban.Job{args: %{"project_id" => non_existent_id}}

      assert {:error, :project_not_found} = ProductAnalyzerWorker.perform(job)
    end

    test "broadcasts completion via PubSub", %{project: project} do
      # Subscribe to the project's analysis topic
      Phoenix.PubSub.subscribe(MarketMind.PubSub, "project:#{project.id}")

      Req.Test.stub(WebsiteFetcher, fn conn ->
        Req.Test.html(conn, "<html><head><title>Test</title></head><body>Content</body></html>")
      end)

      Req.Test.stub(Gemini, fn conn ->
        Req.Test.json(conn, %{
          "candidates" => [
            %{"content" => %{"parts" => [%{"text" => @sample_analysis_json}]}}
          ]
        })
      end)

      job = %Oban.Job{args: %{"project_id" => project.id}}
      assert :ok = ProductAnalyzerWorker.perform(job)

      # Verify the broadcast was sent
      assert_receive {:analysis_completed, %{project_id: received_id, status: "completed"}}
      assert received_id == project.id
    end

    test "broadcasts failure via PubSub on error", %{project: project} do
      Phoenix.PubSub.subscribe(MarketMind.PubSub, "project:#{project.id}")

      Req.Test.stub(WebsiteFetcher, fn conn ->
        conn
        |> Plug.Conn.put_status(500)
        |> Req.Test.html("<html><body>Error</body></html>")
      end)

      job = %Oban.Job{args: %{"project_id" => project.id}}
      ProductAnalyzerWorker.perform(job)

      # Verify the failure broadcast was sent
      assert_receive {:analysis_completed, %{project_id: received_id, status: "failed"}}
      assert received_id == project.id
    end
  end

  describe "job configuration" do
    test "uses the analysis queue" do
      # Build a job and check its queue
      job = ProductAnalyzerWorker.new(%{project_id: Ecto.UUID.generate()})
      assert job.changes[:queue] == "analysis"
    end

    test "has reasonable max attempts" do
      job = ProductAnalyzerWorker.new(%{project_id: Ecto.UUID.generate()})
      assert job.changes[:max_attempts] in 1..5
    end
  end
end
