defmodule MarketMind.ProductsTest do
  use MarketMind.DataCase, async: true

  alias MarketMind.Products
  alias MarketMind.Products.Project
  alias MarketMind.Products.WebsiteFetcher
  alias MarketMind.LLM.Gemini

  import MarketMind.Fixtures

  # Sample analysis response for stubs
  @sample_analysis_json ~s({"product_name": "Test", "tagline": "Best", "value_propositions": [], "key_features": [], "target_audience": "All", "pricing_model": "free", "industries": [], "tone": "casual", "unique_differentiators": []})

  describe "projects" do
    @valid_attrs %{
      name: "My SaaS Product",
      url: "https://mysaas.com",
      description: "A great product"
    }
    @invalid_attrs %{name: nil, url: nil}

    test "list_projects_for_user/1 returns all projects for a user" do
      user = user_fixture()
      {:ok, project} = Products.create_project(user, @valid_attrs)

      assert Products.list_projects_for_user(user) == [project]
    end

    test "list_projects_for_user/1 returns empty list for user with no projects" do
      user = user_fixture()
      assert Products.list_projects_for_user(user) == []
    end

    test "list_projects_for_user/1 does not return other users' projects" do
      user1 = user_fixture()
      user2 = user_fixture()

      {:ok, _project1} = Products.create_project(user1, @valid_attrs)
      {:ok, project2} = Products.create_project(user2, %{@valid_attrs | name: "Other Product"})

      assert Products.list_projects_for_user(user2) == [project2]
    end

    test "get_project!/1 returns the project with given id" do
      user = user_fixture()
      {:ok, project} = Products.create_project(user, @valid_attrs)

      assert Products.get_project!(project.id) == project
    end

    test "get_project!/1 raises if project does not exist" do
      assert_raise Ecto.NoResultsError, fn ->
        Products.get_project!(Ecto.UUID.generate())
      end
    end

    test "create_project/2 with valid data creates a project" do
      user = user_fixture()
      assert {:ok, %Project{} = project} = Products.create_project(user, @valid_attrs)

      assert project.name == "My SaaS Product"
      assert project.url == "https://mysaas.com"
      assert project.description == "A great product"
      assert project.user_id == user.id
      assert project.analysis_status == "pending"
      assert project.slug != nil
    end

    test "create_project/2 generates a unique slug from name" do
      user = user_fixture()
      {:ok, project} = Products.create_project(user, @valid_attrs)

      assert project.slug =~ "my-saas-product"
    end

    test "create_project/2 handles duplicate slugs by appending unique suffix" do
      user = user_fixture()
      {:ok, project1} = Products.create_project(user, @valid_attrs)
      {:ok, project2} = Products.create_project(user, @valid_attrs)

      refute project1.slug == project2.slug
    end

    test "create_project/2 with invalid data returns error changeset" do
      user = user_fixture()
      assert {:error, %Ecto.Changeset{}} = Products.create_project(user, @invalid_attrs)
    end

    test "create_project/2 validates url format" do
      user = user_fixture()
      invalid_url_attrs = %{@valid_attrs | url: "not-a-valid-url"}

      assert {:error, changeset} = Products.create_project(user, invalid_url_attrs)
      assert "must be a valid URL" in errors_on(changeset).url
    end

    test "update_project/2 with valid data updates the project" do
      user = user_fixture()
      {:ok, project} = Products.create_project(user, @valid_attrs)

      update_attrs = %{name: "Updated Name", description: "Updated description"}
      assert {:ok, %Project{} = updated} = Products.update_project(project, update_attrs)

      assert updated.name == "Updated Name"
      assert updated.description == "Updated description"
    end

    test "update_project/2 with invalid data returns error changeset" do
      user = user_fixture()
      {:ok, project} = Products.create_project(user, @valid_attrs)

      assert {:error, %Ecto.Changeset{}} = Products.update_project(project, @invalid_attrs)
      assert project == Products.get_project!(project.id)
    end

    test "delete_project/1 deletes the project" do
      user = user_fixture()
      {:ok, project} = Products.create_project(user, @valid_attrs)

      assert {:ok, %Project{}} = Products.delete_project(project)
      assert_raise Ecto.NoResultsError, fn -> Products.get_project!(project.id) end
    end
  end

  describe "analysis status management" do
    @valid_attrs %{name: "Test Product", url: "https://test.com"}

    test "update_analysis_status/2 updates status to analyzing" do
      user = user_fixture()
      {:ok, project} = Products.create_project(user, @valid_attrs)

      assert {:ok, updated} = Products.update_analysis_status(project, "analyzing")
      assert updated.analysis_status == "analyzing"
    end

    test "update_analysis_status/3 updates status with analysis data" do
      user = user_fixture()
      {:ok, project} = Products.create_project(user, @valid_attrs)

      analysis_data = %{
        "product_name" => "Test Product",
        "tagline" => "The best test product",
        "value_propositions" => ["Fast", "Reliable", "Affordable"],
        "key_features" => [
          %{"name" => "Feature 1", "description" => "Does something cool"}
        ],
        "target_audience" => "Developers",
        "pricing_model" => "subscription",
        "industries" => ["Technology"],
        "tone" => "professional",
        "unique_differentiators" => ["Best in class support"]
      }

      assert {:ok, updated} =
               Products.update_analysis_status(project, "completed", analysis_data)

      assert updated.analysis_status == "completed"
      assert updated.analysis_data == analysis_data
      assert updated.analyzed_at != nil
    end

    test "update_analysis_status/2 with failed status" do
      user = user_fixture()
      {:ok, project} = Products.create_project(user, @valid_attrs)

      assert {:ok, updated} = Products.update_analysis_status(project, "failed")
      assert updated.analysis_status == "failed"
    end

    test "queue_analysis/1 enqueues an analysis job and updates status" do
      user = user_fixture()
      {:ok, project} = Products.create_project(user, @valid_attrs)

      # Stub WebsiteFetcher and Gemini since Oban inline mode executes immediately
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

      assert {:ok, updated} = Products.queue_analysis(project)
      assert updated.analysis_status == "queued"

      # Note: With Oban inline mode, the job executes immediately after queue_analysis returns.
      # The returned project has "queued" status, but the worker updates it to "completed".
    end
  end

  describe "project queries" do
    test "get_project_by_slug/1 returns project with given slug" do
      user = user_fixture()
      {:ok, project} = Products.create_project(user, %{name: "My Product", url: "https://my.com"})

      found = Products.get_project_by_slug(project.slug)
      assert found.id == project.id
    end

    test "get_project_by_slug/1 returns nil for non-existent slug" do
      assert Products.get_project_by_slug("non-existent-slug") == nil
    end

    test "list_pending_projects/0 returns projects with pending status" do
      user = user_fixture()
      {:ok, pending} = Products.create_project(user, %{name: "Pending", url: "https://p.com"})
      {:ok, queued} = Products.create_project(user, %{name: "Queued", url: "https://q.com"})
      Products.update_analysis_status(queued, "queued")

      pending_projects = Products.list_pending_projects()
      assert length(pending_projects) == 1
      assert hd(pending_projects).id == pending.id
    end
  end
end
