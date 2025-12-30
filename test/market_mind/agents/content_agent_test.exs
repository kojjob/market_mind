defmodule MarketMind.Agents.ContentAgentTest do
  use ExUnit.Case, async: true

  alias MarketMind.Agents.ContentAgent
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
        %{"name" => "Content Generator", "description" => "Creates marketing content"}
      ],
      "target_audience" => "Solo founders and indie makers",
      "industries" => ["SaaS", "Marketing Technology"]
    }
  }

  @valid_content_response %{
    "strategy" => "Focus on pain-point content that resonates with indie makers struggling with marketing. Use atomized content to maximize reach across platforms while maintaining consistent messaging.",
    "content_atoms" => [
      %{
        "platform" => "Twitter",
        "format" => "Thread",
        "hook" => "I spent $50k on marketing agencies before realizing I could automate 90% of it. Here's what I learned:",
        "body_outline" => "1. Most marketing tasks are repetitive\n2. AI can handle content creation\n3. Automation saves hours weekly\n4. Cost comparison: agency vs AI tools",
        "cta" => "Try MarketMind free and see the difference in your first week."
      },
      %{
        "platform" => "LinkedIn",
        "format" => "Long Post",
        "hook" => "The biggest mistake indie makers make with marketing isn't spending too little—it's spending too much on the wrong things.",
        "body_outline" => "1. Common marketing overspend areas\n2. What actually moves the needle\n3. How AI changes the equation\n4. Real ROI numbers from users",
        "cta" => "Comment 'AI' and I'll share our free marketing automation checklist."
      },
      %{
        "platform" => "Blog",
        "format" => "How-to Guide",
        "hook" => "The Complete Guide to Marketing Automation for Solo Founders",
        "body_outline" => "Introduction to marketing automation\nTools comparison\nStep-by-step setup guide\nMeasuring success\nCommon pitfalls to avoid",
        "cta" => "Start your free trial of MarketMind today."
      },
      %{
        "platform" => "Twitter",
        "format" => "Short Post",
        "hook" => "Hot take: Most SaaS founders don't need a marketing team. They need better automation.",
        "body_outline" => "Single powerful statement with implied value proposition",
        "cta" => "Link in bio to learn more."
      },
      %{
        "platform" => "LinkedIn",
        "format" => "Story Post",
        "hook" => "Last month, I launched a product with zero marketing budget. Here's how it got 1000 signups:",
        "body_outline" => "The challenge\nThe strategy\nThe tools used\nThe results\nKey takeaways",
        "cta" => "Follow for more indie maker marketing tips."
      }
    ]
  }

  describe "generate/1" do
    test "returns content strategy when API call succeeds" do
      Req.Test.stub(Gemini, fn conn ->
        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(@valid_content_response)}]
              }
            }
          ]
        })
      end)

      assert {:ok, content_data} = ContentAgent.generate(@test_project)
      assert is_map(content_data)
    end

    test "returns strategy string" do
      Req.Test.stub(Gemini, fn conn ->
        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(@valid_content_response)}]
              }
            }
          ]
        })
      end)

      {:ok, content_data} = ContentAgent.generate(@test_project)
      assert is_binary(content_data["strategy"])
      assert content_data["strategy"] =~ "indie makers"
    end

    test "returns content atoms list" do
      Req.Test.stub(Gemini, fn conn ->
        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(@valid_content_response)}]
              }
            }
          ]
        })
      end)

      {:ok, content_data} = ContentAgent.generate(@test_project)
      assert is_list(content_data["content_atoms"])
      assert length(content_data["content_atoms"]) == 5
    end

    test "returns content atoms with required fields" do
      Req.Test.stub(Gemini, fn conn ->
        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(@valid_content_response)}]
              }
            }
          ]
        })
      end)

      {:ok, content_data} = ContentAgent.generate(@test_project)
      [first_atom | _] = content_data["content_atoms"]

      assert first_atom["platform"] == "Twitter"
      assert first_atom["format"] == "Thread"
      assert is_binary(first_atom["hook"])
      assert is_binary(first_atom["body_outline"])
      assert is_binary(first_atom["cta"])
    end

    test "returns content atoms for multiple platforms" do
      Req.Test.stub(Gemini, fn conn ->
        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(@valid_content_response)}]
              }
            }
          ]
        })
      end)

      {:ok, content_data} = ContentAgent.generate(@test_project)
      platforms = Enum.map(content_data["content_atoms"], & &1["platform"])

      assert "Twitter" in platforms
      assert "LinkedIn" in platforms
      assert "Blog" in platforms
    end

    test "returns content atoms with various formats" do
      Req.Test.stub(Gemini, fn conn ->
        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(@valid_content_response)}]
              }
            }
          ]
        })
      end)

      {:ok, content_data} = ContentAgent.generate(@test_project)
      formats = Enum.map(content_data["content_atoms"], & &1["format"])

      assert "Thread" in formats
      assert "Long Post" in formats
      assert "How-to Guide" in formats
    end
  end

  describe "error handling" do
    test "returns error when API call fails" do
      Req.Test.stub(Gemini, fn conn ->
        conn
        |> Plug.Conn.put_status(500)
        |> Req.Test.json(%{"error" => %{"message" => "Internal server error"}})
      end)

      assert {:error, {:api_error, 500, _}} = ContentAgent.generate(@test_project)
    end

    test "handles rate limit error" do
      Req.Test.stub(Gemini, fn conn ->
        conn
        |> Plug.Conn.put_status(429)
        |> Req.Test.json(%{"error" => %{"message" => "Rate limit exceeded"}})
      end)

      assert {:error, {:rate_limited, _}} = ContentAgent.generate(@test_project)
    end

    test "handles authorization error" do
      Req.Test.stub(Gemini, fn conn ->
        conn
        |> Plug.Conn.put_status(401)
        |> Req.Test.json(%{"error" => %{"message" => "Invalid API key"}})
      end)

      assert {:error, {:api_error, 401, _}} = ContentAgent.generate(@test_project)
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
                "parts" => [%{"text" => Jason.encode!(@valid_content_response)}]
              }
            }
          ]
        })
      end)

      ContentAgent.generate(@test_project)
    end

    test "requests content atomization strategy" do
      Req.Test.stub(Gemini, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        request = Jason.decode!(body)

        prompt_text = hd(request["contents"])["parts"] |> hd() |> Map.get("text")

        assert prompt_text =~ "Content Atomization"
        assert prompt_text =~ "content strategy"
        assert prompt_text =~ "Content Atoms"
        assert prompt_text =~ "Platform"
        assert prompt_text =~ "Hook"
        assert prompt_text =~ "CTA"

        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(@valid_content_response)}]
              }
            }
          ]
        })
      end)

      ContentAgent.generate(@test_project)
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
                "parts" => [%{"text" => Jason.encode!(@valid_content_response)}]
              }
            }
          ]
        })
      end)

      ContentAgent.generate(@test_project)
    end

    test "requests multiple platforms in prompt" do
      Req.Test.stub(Gemini, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        request = Jason.decode!(body)

        prompt_text = hd(request["contents"])["parts"] |> hd() |> Map.get("text")

        assert prompt_text =~ "Twitter"
        assert prompt_text =~ "LinkedIn"
        assert prompt_text =~ "Blog"

        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(@valid_content_response)}]
              }
            }
          ]
        })
      end)

      ContentAgent.generate(@test_project)
    end
  end
end
