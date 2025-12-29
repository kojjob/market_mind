defmodule MarketMind.Agents.ContentWriterAgentTest do
  use ExUnit.Case, async: true

  alias MarketMind.Agents.ContentWriterAgent
  alias MarketMind.LLM.Gemini

  # Sample project for testing
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

  @test_persona %MarketMind.Personas.Persona{
    id: Ecto.UUID.generate(),
    name: "Solo Steve",
    role: "Solo Founder",
    description: "A technical solo founder juggling multiple micro-SaaS products.",
    pain_points: ["No time for marketing", "High customer acquisition cost", "Context switching"],
    goals: ["Automate marketing", "Scale revenue", "Reduce manual work"],
    motivations: ["Freedom", "Impact", "Passive income"],
    keywords: ["marketing automation", "saas growth", "founder tools"],
    channels: ["Twitter", "Indie Hackers", "Product Hunt"],
    is_primary: true
  }

  @valid_blog_response %{
    "blog_posts" => [
      %{
        "title" => "5 Marketing Automation Strategies for Solo Founders",
        "meta_description" => "Discover proven marketing automation strategies that help solo founders scale their SaaS without hiring a marketing team.",
        "target_keyword" => "marketing automation for solo founders",
        "secondary_keywords" => ["saas marketing", "founder marketing", "automated marketing"],
        "introduction" => "As a solo founder, you're wearing every hat in the company. Marketing often falls by the wayside...",
        "sections" => [
          %{
            "heading" => "Why Solo Founders Need Marketing Automation",
            "content" => "The average solo founder spends 10-20 hours per week on marketing tasks. This is time that could be spent building your product..."
          },
          %{
            "heading" => "Strategy 1: Email Drip Campaigns",
            "content" => "Email automation is the foundation of effective marketing. Set up sequences that nurture leads while you sleep..."
          },
          %{
            "heading" => "Strategy 2: Social Media Scheduling",
            "content" => "Batch your social media content creation and schedule posts for the week ahead..."
          }
        ],
        "conclusion" => "Marketing automation isn't just for big companies with dedicated teams. As a solo founder, these strategies will help you compete with larger players while maintaining your sanity.",
        "call_to_action" => "Ready to automate your marketing? Start with MarketMind's free product analysis to see how AI can help you scale."
      },
      %{
        "title" => "How to Reduce Customer Acquisition Cost as a Bootstrap Founder",
        "meta_description" => "Learn practical strategies to lower your CAC and grow your SaaS profitably without venture capital.",
        "target_keyword" => "reduce customer acquisition cost",
        "secondary_keywords" => ["bootstrap saas", "cac optimization", "organic growth"],
        "introduction" => "Customer acquisition cost (CAC) can make or break a bootstrapped SaaS...",
        "sections" => [
          %{
            "heading" => "Understanding Your True CAC",
            "content" => "Before optimizing, you need to measure. Calculate your CAC by dividing total marketing spend..."
          },
          %{
            "heading" => "Organic Content Marketing",
            "content" => "Content marketing has the lowest CAC of any channel for most SaaS companies..."
          }
        ],
        "conclusion" => "Lowering CAC is a continuous process. Focus on channels that work, cut those that don't, and always measure.",
        "call_to_action" => "Use MarketMind to identify your ideal customer personas and create targeted content that converts."
      }
    ]
  }

  describe "generate/2 with persona" do
    test "returns blog posts when API call succeeds" do
      Req.Test.stub(Gemini, fn conn ->
        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(@valid_blog_response)}]
              }
            }
          ]
        })
      end)

      assert {:ok, posts} = ContentWriterAgent.generate(@test_project, @test_persona)
      assert length(posts) == 2

      [first_post | _] = posts
      assert first_post.title == "5 Marketing Automation Strategies for Solo Founders"
      assert first_post.target_keyword == "marketing automation for solo founders"
      assert length(first_post.secondary_keywords) == 3
    end

    test "includes meta_description in normalized output" do
      Req.Test.stub(Gemini, fn conn ->
        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(@valid_blog_response)}]
              }
            }
          ]
        })
      end)

      {:ok, [first_post | _]} = ContentWriterAgent.generate(@test_project, @test_persona)
      assert first_post.meta_description =~ "solo founders"
    end

    test "assembles full body from sections" do
      Req.Test.stub(Gemini, fn conn ->
        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(@valid_blog_response)}]
              }
            }
          ]
        })
      end)

      {:ok, [first_post | _]} = ContentWriterAgent.generate(@test_project, @test_persona)

      assert first_post.body =~ "As a solo founder"
      assert first_post.body =~ "## Why Solo Founders Need Marketing Automation"
      assert first_post.body =~ "## Strategy 1: Email Drip Campaigns"
      assert first_post.body =~ "Marketing automation isn't just for big companies"
    end

    test "sets persona_id in normalized output" do
      Req.Test.stub(Gemini, fn conn ->
        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(@valid_blog_response)}]
              }
            }
          ]
        })
      end)

      {:ok, [first_post | _]} = ContentWriterAgent.generate(@test_project, @test_persona)
      assert first_post.persona_id == @test_persona.id
    end

    test "sets content_type to blog_post" do
      Req.Test.stub(Gemini, fn conn ->
        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(@valid_blog_response)}]
              }
            }
          ]
        })
      end)

      {:ok, posts} = ContentWriterAgent.generate(@test_project, @test_persona)
      assert Enum.all?(posts, &(&1.content_type == "blog_post"))
    end

    test "sets status to draft" do
      Req.Test.stub(Gemini, fn conn ->
        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(@valid_blog_response)}]
              }
            }
          ]
        })
      end)

      {:ok, posts} = ContentWriterAgent.generate(@test_project, @test_persona)
      assert Enum.all?(posts, &(&1.status == "draft"))
    end
  end

  describe "generate/1 without persona" do
    test "returns blog posts without persona association" do
      Req.Test.stub(Gemini, fn conn ->
        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(@valid_blog_response)}]
              }
            }
          ]
        })
      end)

      assert {:ok, posts} = ContentWriterAgent.generate(@test_project)
      assert length(posts) == 2

      [first_post | _] = posts
      assert first_post.persona_id == nil
    end
  end

  describe "error handling" do
    test "returns error when API call fails" do
      Req.Test.stub(Gemini, fn conn ->
        conn
        |> Plug.Conn.put_status(500)
        |> Req.Test.json(%{"error" => %{"message" => "Internal server error"}})
      end)

      assert {:error, {:api_error, 500, _}} = ContentWriterAgent.generate(@test_project, @test_persona)
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

      assert {:error, :unexpected_response_format} = ContentWriterAgent.generate(@test_project, @test_persona)
    end

    test "returns error when blog_posts is not a list" do
      Req.Test.stub(Gemini, fn conn ->
        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => ~s({"blog_posts": "not a list"})}]
              }
            }
          ]
        })
      end)

      assert {:error, :unexpected_response_format} = ContentWriterAgent.generate(@test_project, @test_persona)
    end

    test "handles rate limit error" do
      Req.Test.stub(Gemini, fn conn ->
        conn
        |> Plug.Conn.put_status(429)
        |> Req.Test.json(%{"error" => %{"message" => "Rate limit exceeded"}})
      end)

      assert {:error, {:rate_limited, _}} = ContentWriterAgent.generate(@test_project, @test_persona)
    end
  end

  describe "prompt building" do
    test "includes project information in prompt" do
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
                "parts" => [%{"text" => Jason.encode!(@valid_blog_response)}]
              }
            }
          ]
        })
      end)

      ContentWriterAgent.generate(@test_project, @test_persona)
    end

    test "includes persona information in prompt" do
      Req.Test.stub(Gemini, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        request = Jason.decode!(body)

        prompt_text = hd(request["contents"])["parts"] |> hd() |> Map.get("text")

        assert prompt_text =~ "Solo Steve"
        assert prompt_text =~ "Solo Founder"
        assert prompt_text =~ "No time for marketing"
        assert prompt_text =~ "Automate marketing"

        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(@valid_blog_response)}]
              }
            }
          ]
        })
      end)

      ContentWriterAgent.generate(@test_project, @test_persona)
    end

    test "includes analysis data in prompt" do
      Req.Test.stub(Gemini, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        request = Jason.decode!(body)

        prompt_text = hd(request["contents"])["parts"] |> hd() |> Map.get("text")

        assert prompt_text =~ "Product Analyzer"
        assert prompt_text =~ "Persona Builder"

        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(@valid_blog_response)}]
              }
            }
          ]
        })
      end)

      ContentWriterAgent.generate(@test_project, @test_persona)
    end

    test "requests SEO-optimized content" do
      Req.Test.stub(Gemini, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        request = Jason.decode!(body)

        prompt_text = hd(request["contents"])["parts"] |> hd() |> Map.get("text")

        assert prompt_text =~ "SEO"
        assert prompt_text =~ "meta_description"
        assert prompt_text =~ "target_keyword"

        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(@valid_blog_response)}]
              }
            }
          ]
        })
      end)

      ContentWriterAgent.generate(@test_project, @test_persona)
    end
  end

  describe "content quality" do
    test "generates posts with reasonable word counts" do
      # Simulate a response with substantial content
      response = %{
        "blog_posts" => [
          %{
            "title" => "Test Post",
            "meta_description" => "Test description",
            "target_keyword" => "test keyword",
            "secondary_keywords" => ["test"],
            "introduction" => String.duplicate("word ", 100),
            "sections" => [
              %{
                "heading" => "Section 1",
                "content" => String.duplicate("word ", 300)
              },
              %{
                "heading" => "Section 2",
                "content" => String.duplicate("word ", 300)
              }
            ],
            "conclusion" => String.duplicate("word ", 100),
            "call_to_action" => "Try MarketMind today."
          }
        ]
      }

      Req.Test.stub(Gemini, fn conn ->
        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(response)}]
              }
            }
          ]
        })
      end)

      {:ok, [post]} = ContentWriterAgent.generate(@test_project, @test_persona)

      # Body should contain introduction, sections, conclusion, and CTA
      word_count = post.body |> String.split() |> length()
      assert word_count > 500
    end
  end
end
