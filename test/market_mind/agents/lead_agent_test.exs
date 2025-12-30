defmodule MarketMind.Agents.LeadAgentTest do
  use ExUnit.Case, async: true

  alias MarketMind.Agents.LeadAgent
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

  @valid_lead_response %{
    "segments" => [
      %{
        "name" => "Solo SaaS Founders",
        "pain_points" => [
          "Wearing too many hats - can't focus on product",
          "Limited marketing budget for agencies",
          "Lack of marketing expertise"
        ],
        "lead_magnet_idea" => "The Solo Founder Marketing Automation Checklist: 50 Tasks You Can Automate Today",
        "outreach_hook" => "I noticed you're building [product]. Are you spending more time on marketing than coding?",
        "where_to_find" => [
          "r/SaaS subreddit",
          "Indie Hackers community",
          "Product Hunt launch discussions",
          "Twitter #buildinpublic hashtag"
        ]
      },
      %{
        "name" => "Early-Stage Startup CMOs",
        "pain_points" => [
          "Pressure to show ROI with limited resources",
          "Need to scale marketing without hiring",
          "Difficulty measuring attribution"
        ],
        "lead_magnet_idea" => "Startup CMO Toolkit: AI-Powered Marketing Stack for Under $100/Month",
        "outreach_hook" => "Saw your recent product launch. How's the marketing team scaling with growth?",
        "where_to_find" => [
          "LinkedIn Growth CMO groups",
          "CMO Summit attendee lists",
          "Startup accelerator alumni networks"
        ]
      },
      %{
        "name" => "Growth Hackers & Indie Marketers",
        "pain_points" => [
          "Too many tools to manage",
          "Repetitive content creation tasks",
          "Need for faster experimentation"
        ],
        "lead_magnet_idea" => "Growth Automation Playbook: 10 AI Experiments That Actually Work",
        "outreach_hook" => "Your growth experiments are impressive. Ever tried automating the repetitive parts?",
        "where_to_find" => [
          "GrowthHackers.com community",
          "LinkedIn Growth Marketing groups",
          "No-code/low-code communities"
        ]
      }
    ]
  }

  describe "discover/1" do
    test "returns lead segments when API call succeeds" do
      Req.Test.stub(Gemini, fn conn ->
        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(@valid_lead_response)}]
              }
            }
          ]
        })
      end)

      assert {:ok, segments} = LeadAgent.discover(@test_project)
      assert is_list(segments)
      assert length(segments) == 3
    end

    test "returns segment details" do
      Req.Test.stub(Gemini, fn conn ->
        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(@valid_lead_response)}]
              }
            }
          ]
        })
      end)

      {:ok, [first_segment | _]} = LeadAgent.discover(@test_project)

      assert first_segment["name"] == "Solo SaaS Founders"
      assert is_list(first_segment["pain_points"])
      assert is_binary(first_segment["lead_magnet_idea"])
      assert is_binary(first_segment["outreach_hook"])
      assert is_list(first_segment["where_to_find"])
    end

    test "handles response with segments at top level" do
      top_level_response = @valid_lead_response["segments"]

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

      assert {:ok, segments} = LeadAgent.discover(@test_project)
      assert is_list(segments)
      assert length(segments) == 3
    end

    test "returns pain points as list" do
      Req.Test.stub(Gemini, fn conn ->
        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(@valid_lead_response)}]
              }
            }
          ]
        })
      end)

      {:ok, [first_segment | _]} = LeadAgent.discover(@test_project)

      assert length(first_segment["pain_points"]) == 3
      assert "Wearing too many hats - can't focus on product" in first_segment["pain_points"]
    end

    test "returns where_to_find as list" do
      Req.Test.stub(Gemini, fn conn ->
        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(@valid_lead_response)}]
              }
            }
          ]
        })
      end)

      {:ok, [first_segment | _]} = LeadAgent.discover(@test_project)

      assert length(first_segment["where_to_find"]) == 4
      assert "r/SaaS subreddit" in first_segment["where_to_find"]
      assert "Indie Hackers community" in first_segment["where_to_find"]
    end

    test "returns lead magnet ideas for each segment" do
      Req.Test.stub(Gemini, fn conn ->
        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(@valid_lead_response)}]
              }
            }
          ]
        })
      end)

      {:ok, segments} = LeadAgent.discover(@test_project)

      Enum.each(segments, fn segment ->
        assert is_binary(segment["lead_magnet_idea"])
        assert String.length(segment["lead_magnet_idea"]) > 10
      end)
    end

    test "returns outreach hooks for each segment" do
      Req.Test.stub(Gemini, fn conn ->
        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(@valid_lead_response)}]
              }
            }
          ]
        })
      end)

      {:ok, segments} = LeadAgent.discover(@test_project)

      Enum.each(segments, fn segment ->
        assert is_binary(segment["outreach_hook"])
        assert String.length(segment["outreach_hook"]) > 10
      end)
    end
  end

  describe "error handling" do
    test "returns error when API call fails" do
      Req.Test.stub(Gemini, fn conn ->
        conn
        |> Plug.Conn.put_status(500)
        |> Req.Test.json(%{"error" => %{"message" => "Internal server error"}})
      end)

      assert {:error, {:api_error, 500, _}} = LeadAgent.discover(@test_project)
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

      assert {:error, :unexpected_response_format} = LeadAgent.discover(@test_project)
    end

    test "returns error when segments is not a list" do
      Req.Test.stub(Gemini, fn conn ->
        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => ~s({"segments": "not a list"})}]
              }
            }
          ]
        })
      end)

      assert {:error, :unexpected_response_format} = LeadAgent.discover(@test_project)
    end

    test "handles rate limit error" do
      Req.Test.stub(Gemini, fn conn ->
        conn
        |> Plug.Conn.put_status(429)
        |> Req.Test.json(%{"error" => %{"message" => "Rate limit exceeded"}})
      end)

      assert {:error, {:rate_limited, _}} = LeadAgent.discover(@test_project)
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
                "parts" => [%{"text" => Jason.encode!(@valid_lead_response)}]
              }
            }
          ]
        })
      end)

      LeadAgent.discover(@test_project)
    end

    test "requests lead generation specific content" do
      Req.Test.stub(Gemini, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        request = Jason.decode!(body)

        prompt_text = hd(request["contents"])["parts"] |> hd() |> Map.get("text")

        assert prompt_text =~ "lead generation"
        assert prompt_text =~ "customer segments"
        assert prompt_text =~ "Pain Points"
        assert prompt_text =~ "Lead Magnet"
        assert prompt_text =~ "Outreach Hook"
        assert prompt_text =~ "Where to find"

        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(@valid_lead_response)}]
              }
            }
          ]
        })
      end)

      LeadAgent.discover(@test_project)
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
                "parts" => [%{"text" => Jason.encode!(@valid_lead_response)}]
              }
            }
          ]
        })
      end)

      LeadAgent.discover(@test_project)
    end

    test "requests specific locations to find leads" do
      Req.Test.stub(Gemini, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        request = Jason.decode!(body)

        prompt_text = hd(request["contents"])["parts"] |> hd() |> Map.get("text")

        assert prompt_text =~ "subreddits"
        assert prompt_text =~ "LinkedIn"
        assert prompt_text =~ "directories"

        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(@valid_lead_response)}]
              }
            }
          ]
        })
      end)

      LeadAgent.discover(@test_project)
    end
  end
end
