defmodule MarketMind.Agents.CroAgentTest do
  use ExUnit.Case, async: true

  alias MarketMind.Agents.CroAgent
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

  @valid_cro_response %{
    "overall_score" => 72,
    "clarity_rating" => 8,
    "trust_rating" => 6,
    "cta_rating" => 7,
    "findings" => [
      %{
        "area" => "Hero Section",
        "issue" => "Headline doesn't communicate specific benefit",
        "recommendation" => "Replace with outcome-focused headline that mentions the key transformation",
        "impact" => "High"
      },
      %{
        "area" => "Trust Signals",
        "issue" => "Missing customer testimonials and social proof",
        "recommendation" => "Add 3-5 customer logos and at least one testimonial with photo",
        "impact" => "High"
      },
      %{
        "area" => "CTA Button",
        "issue" => "CTA text 'Get Started' is generic",
        "recommendation" => "Use value-focused CTA like 'Start Automating Free'",
        "impact" => "Medium"
      },
      %{
        "area" => "Value Proposition",
        "issue" => "Features listed without clear benefits",
        "recommendation" => "Reframe each feature as a benefit with specific outcomes",
        "impact" => "Medium"
      }
    ],
    "hero_rewrite" => %{
      "headline" => "Automate Your Marketing in 10 Minutes, Not 10 Weeks",
      "subheadline" => "The AI marketing assistant that turns your SaaS URL into a complete go-to-market strategy—no marketing team required."
    }
  }

  describe "audit/1" do
    test "returns CRO audit when API call succeeds" do
      Req.Test.stub(Gemini, fn conn ->
        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(@valid_cro_response)}]
              }
            }
          ]
        })
      end)

      assert {:ok, audit_data} = CroAgent.audit(@test_project)
      assert is_map(audit_data)
    end

    test "returns overall score as integer" do
      Req.Test.stub(Gemini, fn conn ->
        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(@valid_cro_response)}]
              }
            }
          ]
        })
      end)

      {:ok, audit_data} = CroAgent.audit(@test_project)
      assert is_integer(audit_data["overall_score"])
      assert audit_data["overall_score"] == 72
    end

    test "returns individual ratings as integers" do
      Req.Test.stub(Gemini, fn conn ->
        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(@valid_cro_response)}]
              }
            }
          ]
        })
      end)

      {:ok, audit_data} = CroAgent.audit(@test_project)

      assert is_integer(audit_data["clarity_rating"])
      assert is_integer(audit_data["trust_rating"])
      assert is_integer(audit_data["cta_rating"])
      assert audit_data["clarity_rating"] == 8
      assert audit_data["trust_rating"] == 6
      assert audit_data["cta_rating"] == 7
    end

    test "returns findings list" do
      Req.Test.stub(Gemini, fn conn ->
        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(@valid_cro_response)}]
              }
            }
          ]
        })
      end)

      {:ok, audit_data} = CroAgent.audit(@test_project)
      assert is_list(audit_data["findings"])
      assert length(audit_data["findings"]) == 4
    end

    test "returns findings with required fields" do
      Req.Test.stub(Gemini, fn conn ->
        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(@valid_cro_response)}]
              }
            }
          ]
        })
      end)

      {:ok, audit_data} = CroAgent.audit(@test_project)
      [first_finding | _] = audit_data["findings"]

      assert first_finding["area"] == "Hero Section"
      assert is_binary(first_finding["issue"])
      assert is_binary(first_finding["recommendation"])
      assert first_finding["impact"] in ["High", "Medium", "Low"]
    end

    test "returns hero rewrite with headline and subheadline" do
      Req.Test.stub(Gemini, fn conn ->
        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(@valid_cro_response)}]
              }
            }
          ]
        })
      end)

      {:ok, audit_data} = CroAgent.audit(@test_project)
      hero_rewrite = audit_data["hero_rewrite"]

      assert is_map(hero_rewrite)
      assert is_binary(hero_rewrite["headline"])
      assert is_binary(hero_rewrite["subheadline"])
      assert hero_rewrite["headline"] =~ "Automate"
    end

    test "returns findings covering different areas" do
      Req.Test.stub(Gemini, fn conn ->
        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(@valid_cro_response)}]
              }
            }
          ]
        })
      end)

      {:ok, audit_data} = CroAgent.audit(@test_project)
      areas = Enum.map(audit_data["findings"], & &1["area"])

      assert "Hero Section" in areas
      assert "Trust Signals" in areas
      assert "CTA Button" in areas
    end
  end

  describe "error handling" do
    test "returns error when API call fails" do
      Req.Test.stub(Gemini, fn conn ->
        conn
        |> Plug.Conn.put_status(500)
        |> Req.Test.json(%{"error" => %{"message" => "Internal server error"}})
      end)

      assert {:error, {:api_error, 500, _}} = CroAgent.audit(@test_project)
    end

    test "handles rate limit error" do
      Req.Test.stub(Gemini, fn conn ->
        conn
        |> Plug.Conn.put_status(429)
        |> Req.Test.json(%{"error" => %{"message" => "Rate limit exceeded"}})
      end)

      assert {:error, {:rate_limited, _}} = CroAgent.audit(@test_project)
    end

    test "handles authorization error" do
      Req.Test.stub(Gemini, fn conn ->
        conn
        |> Plug.Conn.put_status(401)
        |> Req.Test.json(%{"error" => %{"message" => "Invalid API key"}})
      end)

      assert {:error, {:api_error, 401, _}} = CroAgent.audit(@test_project)
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
                "parts" => [%{"text" => Jason.encode!(@valid_cro_response)}]
              }
            }
          ]
        })
      end)

      CroAgent.audit(@test_project)
    end

    test "requests CRO-specific evaluation criteria" do
      Req.Test.stub(Gemini, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        request = Jason.decode!(body)

        prompt_text = hd(request["contents"])["parts"] |> hd() |> Map.get("text")

        assert prompt_text =~ "Conversion Rate Optimization"
        assert prompt_text =~ "Clarity"
        assert prompt_text =~ "Value Proposition"
        assert prompt_text =~ "Trust Signals"
        assert prompt_text =~ "CTA"

        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(@valid_cro_response)}]
              }
            }
          ]
        })
      end)

      CroAgent.audit(@test_project)
    end

    test "requests overall score and ratings in prompt" do
      Req.Test.stub(Gemini, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        request = Jason.decode!(body)

        prompt_text = hd(request["contents"])["parts"] |> hd() |> Map.get("text")

        assert prompt_text =~ "overall score"
        assert prompt_text =~ "Ratings"
        assert prompt_text =~ "0-100"

        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(@valid_cro_response)}]
              }
            }
          ]
        })
      end)

      CroAgent.audit(@test_project)
    end

    test "requests hero section rewrite in prompt" do
      Req.Test.stub(Gemini, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        request = Jason.decode!(body)

        prompt_text = hd(request["contents"])["parts"] |> hd() |> Map.get("text")

        assert prompt_text =~ "Hero Section Rewrite"
        assert prompt_text =~ "headline"
        assert prompt_text =~ "subheadline"

        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(@valid_cro_response)}]
              }
            }
          ]
        })
      end)

      CroAgent.audit(@test_project)
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
                "parts" => [%{"text" => Jason.encode!(@valid_cro_response)}]
              }
            }
          ]
        })
      end)

      CroAgent.audit(@test_project)
    end
  end
end
