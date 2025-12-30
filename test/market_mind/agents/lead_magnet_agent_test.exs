defmodule MarketMind.Agents.LeadMagnetAgentTest do
  use ExUnit.Case, async: true

  alias MarketMind.Agents.LeadMagnetAgent
  alias MarketMind.LLM.Gemini

  @test_project %MarketMind.Products.Project{
    id: Ecto.UUID.generate(),
    name: "MarketMind",
    url: "https://marketmind.ai",
    description: "AI-powered marketing automation for indie makers",
    brand_voice: "friendly and professional",
    tone: "helpful and educational"
  }

  @test_content %MarketMind.Content.Content{
    id: Ecto.UUID.generate(),
    title: "10 Marketing Automation Tips for Solo Founders",
    body: """
    Marketing automation can transform how solo founders approach growth.
    Here are ten essential tips:

    1. Start with email automation - it's the highest ROI channel
    2. Use behavioral triggers to send relevant messages
    3. Segment your audience based on engagement
    4. Create drip campaigns for onboarding new users
    5. Automate social media posting to save time
    6. Set up abandoned cart recovery sequences
    7. Use personalization tokens in your emails
    8. A/B test your subject lines continuously
    9. Track conversion metrics, not just open rates
    10. Integrate your tools to avoid data silos

    By implementing these strategies, you can compete with larger companies
    while focusing on what matters most: building a great product.
    """,
    target_keyword: "marketing automation tips",
    slug: "marketing-automation-tips-1234567890"
  }

  @valid_lead_magnet_response %{
    "title" => "The Solo Founder's Marketing Automation Checklist",
    "description" => "A comprehensive checklist to automate your marketing in just one week. Perfect for busy founders who want to save 10+ hours weekly.",
    "headline" => "Automate Your Marketing in 7 Days or Less",
    "subheadline" => "Join 2,000+ solo founders who transformed their marketing with this proven checklist. No technical skills required.",
    "content" => """
    ## Getting Started
    - [ ] Set up your email marketing platform
    - [ ] Import your existing contacts
    - [ ] Create your first welcome email

    ## Core Automation
    - [ ] Build your onboarding sequence
    - [ ] Set up behavioral triggers
    - [ ] Configure audience segmentation

    ## Advanced Tactics
    - [ ] Create abandoned cart recovery
    - [ ] Implement personalization
    - [ ] Set up A/B testing
    """,
    "cta_text" => "Get Your Free Checklist",
    "thank_you_message" => "Check your inbox! Your Marketing Automation Checklist is on its way. Start with the first three items today for quick wins.",
    "meta_description" => "Free marketing automation checklist for solo founders. Save 10+ hours weekly with proven automation strategies."
  }

  describe "generate/3" do
    test "returns lead magnet attrs when API call succeeds with default type" do
      Req.Test.stub(Gemini, fn conn ->
        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(@valid_lead_magnet_response)}]
              }
            }
          ]
        })
      end)

      assert {:ok, result} = LeadMagnetAgent.generate(@test_project, @test_content)
      assert is_map(result)
    end

    test "returns normalized result with all expected fields" do
      Req.Test.stub(Gemini, fn conn ->
        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(@valid_lead_magnet_response)}]
              }
            }
          ]
        })
      end)

      {:ok, result} = LeadMagnetAgent.generate(@test_project, @test_content)

      assert result.title == "The Solo Founder's Marketing Automation Checklist"
      assert result.description =~ "comprehensive checklist"
      assert result.headline == "Automate Your Marketing in 7 Days or Less"
      assert is_binary(result.subheadline)
      assert is_binary(result.content)
      assert result.cta_text == "Get Your Free Checklist"
      assert is_binary(result.thank_you_message)
      assert is_binary(result.meta_description)
    end

    test "adds content_id and magnet_type to result" do
      Req.Test.stub(Gemini, fn conn ->
        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(@valid_lead_magnet_response)}]
              }
            }
          ]
        })
      end)

      {:ok, result} = LeadMagnetAgent.generate(@test_project, @test_content)

      assert result.content_id == @test_content.id
      assert result.magnet_type == "checklist"
    end

    test "uses specified magnet_type in result" do
      Req.Test.stub(Gemini, fn conn ->
        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(@valid_lead_magnet_response)}]
              }
            }
          ]
        })
      end)

      {:ok, result} = LeadMagnetAgent.generate(@test_project, @test_content, "guide")

      assert result.magnet_type == "guide"
    end

    test "provides default cta_text if not in response" do
      response_without_cta = Map.delete(@valid_lead_magnet_response, "cta_text")

      Req.Test.stub(Gemini, fn conn ->
        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(response_without_cta)}]
              }
            }
          ]
        })
      end)

      {:ok, result} = LeadMagnetAgent.generate(@test_project, @test_content)

      assert result.cta_text == "Get Free Access"
    end
  end

  describe "generate/3 with different magnet types" do
    test "succeeds with checklist type" do
      Req.Test.stub(Gemini, fn conn ->
        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(@valid_lead_magnet_response)}]
              }
            }
          ]
        })
      end)

      assert {:ok, result} = LeadMagnetAgent.generate(@test_project, @test_content, "checklist")
      assert result.magnet_type == "checklist"
    end

    test "succeeds with guide type" do
      Req.Test.stub(Gemini, fn conn ->
        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(@valid_lead_magnet_response)}]
              }
            }
          ]
        })
      end)

      assert {:ok, result} = LeadMagnetAgent.generate(@test_project, @test_content, "guide")
      assert result.magnet_type == "guide"
    end

    test "succeeds with cheatsheet type" do
      Req.Test.stub(Gemini, fn conn ->
        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(@valid_lead_magnet_response)}]
              }
            }
          ]
        })
      end)

      assert {:ok, result} = LeadMagnetAgent.generate(@test_project, @test_content, "cheatsheet")
      assert result.magnet_type == "cheatsheet"
    end

    test "succeeds with template type" do
      Req.Test.stub(Gemini, fn conn ->
        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(@valid_lead_magnet_response)}]
              }
            }
          ]
        })
      end)

      assert {:ok, result} = LeadMagnetAgent.generate(@test_project, @test_content, "template")
      assert result.magnet_type == "template"
    end

    test "succeeds with worksheet type" do
      Req.Test.stub(Gemini, fn conn ->
        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(@valid_lead_magnet_response)}]
              }
            }
          ]
        })
      end)

      assert {:ok, result} = LeadMagnetAgent.generate(@test_project, @test_content, "worksheet")
      assert result.magnet_type == "worksheet"
    end
  end

  describe "type validation" do
    test "returns error for invalid magnet type" do
      assert {:error, {:invalid_type, "invalid_type"}} =
               LeadMagnetAgent.generate(@test_project, @test_content, "invalid_type")
    end

    test "returns error for empty string type" do
      assert {:error, {:invalid_type, ""}} =
               LeadMagnetAgent.generate(@test_project, @test_content, "")
    end

    test "returns error for nil type" do
      assert {:error, {:invalid_type, nil}} =
               LeadMagnetAgent.generate(@test_project, @test_content, nil)
    end

    test "valid_types/0 returns all valid types" do
      types = LeadMagnetAgent.valid_types()

      assert is_list(types)
      assert "checklist" in types
      assert "guide" in types
      assert "cheatsheet" in types
      assert "template" in types
      assert "worksheet" in types
      assert length(types) == 5
    end
  end

  describe "error handling" do
    test "returns error when API call fails" do
      Req.Test.stub(Gemini, fn conn ->
        conn
        |> Plug.Conn.put_status(500)
        |> Req.Test.json(%{"error" => %{"message" => "Internal server error"}})
      end)

      assert {:error, {:api_error, 500, _}} =
               LeadMagnetAgent.generate(@test_project, @test_content)
    end

    test "handles rate limit error" do
      Req.Test.stub(Gemini, fn conn ->
        conn
        |> Plug.Conn.put_status(429)
        |> Req.Test.json(%{"error" => %{"message" => "Rate limit exceeded"}})
      end)

      assert {:error, {:rate_limited, _}} =
               LeadMagnetAgent.generate(@test_project, @test_content)
    end

    test "handles authorization error" do
      Req.Test.stub(Gemini, fn conn ->
        conn
        |> Plug.Conn.put_status(401)
        |> Req.Test.json(%{"error" => %{"message" => "Invalid API key"}})
      end)

      assert {:error, {:api_error, 401, _}} =
               LeadMagnetAgent.generate(@test_project, @test_content)
    end
  end

  describe "prompt building" do
    test "includes project information in prompt" do
      Req.Test.stub(Gemini, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        request = Jason.decode!(body)

        prompt_text = hd(request["contents"])["parts"] |> hd() |> Map.get("text")

        assert prompt_text =~ "MarketMind"
        assert prompt_text =~ "AI-powered marketing automation"
        assert prompt_text =~ "friendly and professional"
        assert prompt_text =~ "helpful and educational"

        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(@valid_lead_magnet_response)}]
              }
            }
          ]
        })
      end)

      LeadMagnetAgent.generate(@test_project, @test_content)
    end

    test "includes content information in prompt" do
      Req.Test.stub(Gemini, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        request = Jason.decode!(body)

        prompt_text = hd(request["contents"])["parts"] |> hd() |> Map.get("text")

        assert prompt_text =~ "10 Marketing Automation Tips"
        assert prompt_text =~ "marketing automation tips"
        assert prompt_text =~ "email automation"

        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(@valid_lead_magnet_response)}]
              }
            }
          ]
        })
      end)

      LeadMagnetAgent.generate(@test_project, @test_content)
    end

    test "includes magnet type in prompt" do
      Req.Test.stub(Gemini, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        request = Jason.decode!(body)

        prompt_text = hd(request["contents"])["parts"] |> hd() |> Map.get("text")

        assert prompt_text =~ "checklist"
        assert prompt_text =~ "CHECKLIST"

        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(@valid_lead_magnet_response)}]
              }
            }
          ]
        })
      end)

      LeadMagnetAgent.generate(@test_project, @test_content, "checklist")
    end

    test "includes type-specific instructions for guide" do
      Req.Test.stub(Gemini, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        request = Jason.decode!(body)

        prompt_text = hd(request["contents"])["parts"] |> hd() |> Map.get("text")

        assert prompt_text =~ "GUIDE"
        assert prompt_text =~ "MINI-GUIDE FORMAT REQUIREMENTS"
        assert prompt_text =~ "5-7 key sections"

        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(@valid_lead_magnet_response)}]
              }
            }
          ]
        })
      end)

      LeadMagnetAgent.generate(@test_project, @test_content, "guide")
    end

    test "includes type-specific instructions for cheatsheet" do
      Req.Test.stub(Gemini, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        request = Jason.decode!(body)

        prompt_text = hd(request["contents"])["parts"] |> hd() |> Map.get("text")

        assert prompt_text =~ "CHEATSHEET"
        assert prompt_text =~ "CHEATSHEET FORMAT REQUIREMENTS"
        assert prompt_text =~ "quick reference"

        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(@valid_lead_magnet_response)}]
              }
            }
          ]
        })
      end)

      LeadMagnetAgent.generate(@test_project, @test_content, "cheatsheet")
    end

    test "includes type-specific instructions for template" do
      Req.Test.stub(Gemini, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        request = Jason.decode!(body)

        prompt_text = hd(request["contents"])["parts"] |> hd() |> Map.get("text")

        assert prompt_text =~ "TEMPLATE"
        assert prompt_text =~ "TEMPLATE FORMAT REQUIREMENTS"
        assert prompt_text =~ "fill-in-the-blank"

        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(@valid_lead_magnet_response)}]
              }
            }
          ]
        })
      end)

      LeadMagnetAgent.generate(@test_project, @test_content, "template")
    end

    test "includes type-specific instructions for worksheet" do
      Req.Test.stub(Gemini, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        request = Jason.decode!(body)

        prompt_text = hd(request["contents"])["parts"] |> hd() |> Map.get("text")

        assert prompt_text =~ "WORKSHEET"
        assert prompt_text =~ "WORKSHEET FORMAT REQUIREMENTS"
        assert prompt_text =~ "interactive exercises"

        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(@valid_lead_magnet_response)}]
              }
            }
          ]
        })
      end)

      LeadMagnetAgent.generate(@test_project, @test_content, "worksheet")
    end

    test "requests all required fields in prompt" do
      Req.Test.stub(Gemini, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        request = Jason.decode!(body)

        prompt_text = hd(request["contents"])["parts"] |> hd() |> Map.get("text")

        assert prompt_text =~ "title"
        assert prompt_text =~ "description"
        assert prompt_text =~ "headline"
        assert prompt_text =~ "subheadline"
        assert prompt_text =~ "content"
        assert prompt_text =~ "cta_text"
        assert prompt_text =~ "thank_you_message"
        assert prompt_text =~ "meta_description"

        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(@valid_lead_magnet_response)}]
              }
            }
          ]
        })
      end)

      LeadMagnetAgent.generate(@test_project, @test_content)
    end
  end

  describe "result normalization" do
    test "converts string keys to atom keys" do
      Req.Test.stub(Gemini, fn conn ->
        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(@valid_lead_magnet_response)}]
              }
            }
          ]
        })
      end)

      {:ok, result} = LeadMagnetAgent.generate(@test_project, @test_content)

      # All keys should be atoms
      assert is_atom(Enum.at(Map.keys(result), 0))
    end

    test "handles missing optional fields with empty strings" do
      minimal_response = %{
        "title" => "Test Title"
      }

      Req.Test.stub(Gemini, fn conn ->
        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(minimal_response)}]
              }
            }
          ]
        })
      end)

      {:ok, result} = LeadMagnetAgent.generate(@test_project, @test_content)

      assert result.title == "Test Title"
      assert result.description == ""
      assert result.headline == ""
      assert result.subheadline == ""
      assert result.content == ""
      assert result.cta_text == "Get Free Access"
      assert result.thank_you_message == ""
      assert result.meta_description == ""
    end
  end
end
