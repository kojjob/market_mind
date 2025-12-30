defmodule MarketMind.Agents.CompetitorAgentTest do
  use ExUnit.Case, async: true

  alias MarketMind.Agents.CompetitorAgent
  alias MarketMind.LLM.Gemini

  @test_project %MarketMind.Products.Project{
    id: Ecto.UUID.generate(),
    name: "MarketMind",
    url: "https://marketmind.ai",
    description: "AI-powered marketing automation for indie makers",
    analysis_data: %{
      "product_name" => "MarketMind",
      "tagline" => "AI Marketing for Indie Makers",
      "value_propositions" => [
        "Complete GTM automation at SMB prices",
        "Multi-product portfolio management"
      ],
      "target_audience" => "Solo founders and indie makers",
      "industries" => ["SaaS", "Marketing Technology"]
    }
  }

  @valid_competitor_response %{
    "competitors" => [
      %{
        "name" => "HubSpot",
        "url" => "https://hubspot.com",
        "description" => "All-in-one marketing, sales, and service platform",
        "strengths" => ["Brand recognition", "Comprehensive feature set", "Strong integrations"],
        "weaknesses" => ["Expensive for small teams", "Complex setup", "Steep learning curve"],
        "pricing_strategy" => "Premium",
        "market_gap" => "MarketMind can win by offering simpler, AI-first automation at a fraction of the cost"
      },
      %{
        "name" => "Mailchimp",
        "url" => "https://mailchimp.com",
        "description" => "Email marketing and automation platform",
        "strengths" => ["Easy to use", "Free tier available", "Good email templates"],
        "weaknesses" => ["Limited AI capabilities", "Basic automation", "Email-focused only"],
        "pricing_strategy" => "Freemium",
        "market_gap" => "MarketMind offers broader marketing automation beyond just email"
      },
      %{
        "name" => "Buffer",
        "url" => "https://buffer.com",
        "description" => "Social media management and scheduling tool",
        "strengths" => ["Intuitive interface", "Good scheduling", "Affordable"],
        "weaknesses" => ["Social media only", "No content generation", "Limited analytics"],
        "pricing_strategy" => "Low-cost",
        "market_gap" => "MarketMind provides AI-generated content and multi-channel automation"
      }
    ]
  }

  describe "analyze/1" do
    test "returns competitors when API call succeeds" do
      Req.Test.stub(Gemini, fn conn ->
        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(@valid_competitor_response)}]
              }
            }
          ]
        })
      end)

      assert {:ok, competitors} = CompetitorAgent.analyze(@test_project)
      assert is_list(competitors)
      assert length(competitors) == 3
    end

    test "returns competitor details" do
      Req.Test.stub(Gemini, fn conn ->
        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(@valid_competitor_response)}]
              }
            }
          ]
        })
      end)

      {:ok, [first_competitor | _]} = CompetitorAgent.analyze(@test_project)

      assert first_competitor["name"] == "HubSpot"
      assert first_competitor["url"] == "https://hubspot.com"
      assert is_binary(first_competitor["description"])
      assert is_list(first_competitor["strengths"])
      assert is_list(first_competitor["weaknesses"])
      assert first_competitor["pricing_strategy"] == "Premium"
      assert is_binary(first_competitor["market_gap"])
    end

    test "handles response with competitors at top level" do
      top_level_response = @valid_competitor_response["competitors"]

      Req.Test.stub(Gemini, fn conn ->
        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(top_level_response)}]
              }
            }
          ]
        })
      end)

      assert {:ok, competitors} = CompetitorAgent.analyze(@test_project)
      assert is_list(competitors)
      assert length(competitors) == 3
    end

    test "returns strengths and weaknesses as lists" do
      Req.Test.stub(Gemini, fn conn ->
        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(@valid_competitor_response)}]
              }
            }
          ]
        })
      end)

      {:ok, [first_competitor | _]} = CompetitorAgent.analyze(@test_project)

      assert length(first_competitor["strengths"]) == 3
      assert length(first_competitor["weaknesses"]) == 3
      assert "Brand recognition" in first_competitor["strengths"]
      assert "Expensive for small teams" in first_competitor["weaknesses"]
    end
  end

  describe "error handling" do
    test "returns error when API call fails" do
      Req.Test.stub(Gemini, fn conn ->
        conn
        |> Plug.Conn.put_status(500)
        |> Req.Test.json(%{"error" => %{"message" => "Internal server error"}})
      end)

      assert {:error, {:api_error, 500, _}} = CompetitorAgent.analyze(@test_project)
    end

    test "returns error when response format is unexpected" do
      Req.Test.stub(Gemini, fn conn ->
        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => ~s({"unexpected": "format"})}]
              }
            }
          ]
        })
      end)

      assert {:error, :unexpected_response_format} = CompetitorAgent.analyze(@test_project)
    end

    test "returns error when competitors is not a list" do
      Req.Test.stub(Gemini, fn conn ->
        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => ~s({"competitors": "not a list"})}]
              }
            }
          ]
        })
      end)

      assert {:error, :unexpected_response_format} = CompetitorAgent.analyze(@test_project)
    end

    test "handles rate limit error" do
      Req.Test.stub(Gemini, fn conn ->
        conn
        |> Plug.Conn.put_status(429)
        |> Req.Test.json(%{"error" => %{"message" => "Rate limit exceeded"}})
      end)

      assert {:error, {:rate_limited, _}} = CompetitorAgent.analyze(@test_project)
    end
  end

  describe "prompt building" do
    test "includes product information in prompt" do
      Req.Test.stub(Gemini, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        request = Jason.decode!(body)

        prompt_text = hd(request["contents"])["parts"] |> hd() |> Map.get("text")

        assert prompt_text =~ "MarketMind"
        assert prompt_text =~ "https://marketmind.ai"
        assert prompt_text =~ "AI-powered marketing automation"

        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(@valid_competitor_response)}]
              }
            }
          ]
        })
      end)

      CompetitorAgent.analyze(@test_project)
    end

    test "requests competitor-specific analysis" do
      Req.Test.stub(Gemini, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        request = Jason.decode!(body)

        prompt_text = hd(request["contents"])["parts"] |> hd() |> Map.get("text")

        assert prompt_text =~ "competitor"
        assert prompt_text =~ "strengths"
        assert prompt_text =~ "weaknesses"
        assert prompt_text =~ "pricing strategy"
        assert prompt_text =~ "Market Gap"

        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(@valid_competitor_response)}]
              }
            }
          ]
        })
      end)

      CompetitorAgent.analyze(@test_project)
    end

    test "includes analysis data in prompt" do
      Req.Test.stub(Gemini, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        request = Jason.decode!(body)

        prompt_text = hd(request["contents"])["parts"] |> hd() |> Map.get("text")

        assert prompt_text =~ "Existing Analysis"

        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(@valid_competitor_response)}]
              }
            }
          ]
        })
      end)

      CompetitorAgent.analyze(@test_project)
    end
  end
end
