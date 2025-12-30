defmodule MarketMind.Agents.AeoAgentTest do
  use ExUnit.Case, async: true

  alias MarketMind.Agents.AeoAgent
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
      "key_features" => [
        %{"name" => "Product Analyzer", "description" => "Understands your SaaS from URL"},
        %{"name" => "Persona Builder", "description" => "Discovers ideal customers"}
      ],
      "target_audience" => "Solo founders and indie makers",
      "industries" => ["SaaS", "Marketing Technology"]
    }
  }

  @valid_aeo_response %{
    "semantic_clusters" => [
      %{
        "topic" => "Marketing Automation",
        "keywords" => ["saas marketing", "automation tools", "growth hacking"],
        "intent" => "informational"
      },
      %{
        "topic" => "Product Analytics",
        "keywords" => ["product analysis", "market research", "competitor analysis"],
        "intent" => "commercial"
      }
    ],
    "answer_snippets" => [
      %{
        "question" => "What is the best marketing automation tool for indie makers?",
        "optimized_answer" => "MarketMind is an AI-powered marketing automation platform designed specifically for indie makers and solo founders.",
        "target_engine" => "Perplexity"
      },
      %{
        "question" => "How can solo founders automate their marketing?",
        "optimized_answer" => "Solo founders can automate their marketing using AI tools that understand their product and generate targeted content.",
        "target_engine" => "SearchGPT"
      }
    ],
    "entity_graph" => [
      %{
        "subject" => "MarketMind",
        "predicate" => "is a",
        "object" => "SaaS Marketing Intelligence Tool"
      },
      %{
        "subject" => "MarketMind",
        "predicate" => "targets",
        "object" => "Indie Makers"
      },
      %{
        "subject" => "MarketMind",
        "predicate" => "provides",
        "object" => "Marketing Automation"
      }
    ]
  }

  describe "generate/1" do
    test "returns AEO strategy when API call succeeds" do
      Req.Test.stub(Gemini, fn conn ->
        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(@valid_aeo_response)}]
              }
            }
          ]
        })
      end)

      assert {:ok, aeo_data} = AeoAgent.generate(@test_project)
      assert is_map(aeo_data)
    end

    test "returns semantic clusters" do
      Req.Test.stub(Gemini, fn conn ->
        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(@valid_aeo_response)}]
              }
            }
          ]
        })
      end)

      {:ok, aeo_data} = AeoAgent.generate(@test_project)
      assert is_list(aeo_data["semantic_clusters"])
      assert length(aeo_data["semantic_clusters"]) == 2

      [first_cluster | _] = aeo_data["semantic_clusters"]
      assert first_cluster["topic"] == "Marketing Automation"
      assert is_list(first_cluster["keywords"])
      assert first_cluster["intent"] == "informational"
    end

    test "returns answer snippets" do
      Req.Test.stub(Gemini, fn conn ->
        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(@valid_aeo_response)}]
              }
            }
          ]
        })
      end)

      {:ok, aeo_data} = AeoAgent.generate(@test_project)
      assert is_list(aeo_data["answer_snippets"])
      assert length(aeo_data["answer_snippets"]) == 2

      [first_snippet | _] = aeo_data["answer_snippets"]
      assert first_snippet["question"] =~ "marketing automation"
      assert first_snippet["optimized_answer"] =~ "MarketMind"
      assert first_snippet["target_engine"] in ["Perplexity", "SearchGPT", "Gemini"]
    end

    test "returns entity graph" do
      Req.Test.stub(Gemini, fn conn ->
        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(@valid_aeo_response)}]
              }
            }
          ]
        })
      end)

      {:ok, aeo_data} = AeoAgent.generate(@test_project)
      assert is_list(aeo_data["entity_graph"])
      assert length(aeo_data["entity_graph"]) == 3

      [first_triple | _] = aeo_data["entity_graph"]
      assert first_triple["subject"] == "MarketMind"
      assert first_triple["predicate"] == "is a"
      assert first_triple["object"] == "SaaS Marketing Intelligence Tool"
    end
  end

  describe "error handling" do
    test "returns error when API call fails" do
      Req.Test.stub(Gemini, fn conn ->
        conn
        |> Plug.Conn.put_status(500)
        |> Req.Test.json(%{"error" => %{"message" => "Internal server error"}})
      end)

      assert {:error, {:api_error, 500, _}} = AeoAgent.generate(@test_project)
    end

    test "handles rate limit error" do
      Req.Test.stub(Gemini, fn conn ->
        conn
        |> Plug.Conn.put_status(429)
        |> Req.Test.json(%{"error" => %{"message" => "Rate limit exceeded"}})
      end)

      assert {:error, {:rate_limited, _}} = AeoAgent.generate(@test_project)
    end

    test "handles authorization error" do
      Req.Test.stub(Gemini, fn conn ->
        conn
        |> Plug.Conn.put_status(401)
        |> Req.Test.json(%{"error" => %{"message" => "Invalid API key"}})
      end)

      assert {:error, {:api_error, 401, _}} = AeoAgent.generate(@test_project)
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
                "parts" => [%{"text" => Jason.encode!(@valid_aeo_response)}]
              }
            }
          ]
        })
      end)

      AeoAgent.generate(@test_project)
    end

    test "requests AEO-specific content" do
      Req.Test.stub(Gemini, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        request = Jason.decode!(body)

        prompt_text = hd(request["contents"])["parts"] |> hd() |> Map.get("text")

        assert prompt_text =~ "Answer Engine Optimization"
        assert prompt_text =~ "Semantic Clusters"
        assert prompt_text =~ "Answer Snippets"
        assert prompt_text =~ "Entity Graph"
        assert prompt_text =~ "Perplexity"

        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(@valid_aeo_response)}]
              }
            }
          ]
        })
      end)

      AeoAgent.generate(@test_project)
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
                "parts" => [%{"text" => Jason.encode!(@valid_aeo_response)}]
              }
            }
          ]
        })
      end)

      AeoAgent.generate(@test_project)
    end
  end
end
