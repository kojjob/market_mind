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

    test "handles response with blog_posts at top level" do
      top_level_response = @valid_blog_response["blog_posts"]

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

      assert {:ok, posts} = ContentWriterAgent.generate(@test_project, @test_persona)
      assert is_list(posts)
      assert length(posts) == 2
      assert hd(posts).persona_id == @test_persona.id
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

    test "handles response with blog_posts at top level" do
      top_level_response = @valid_blog_response["blog_posts"]

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

      assert {:ok, posts} = ContentWriterAgent.generate(@test_project)
      assert is_list(posts)
      assert length(posts) == 2
    end

    test "returns error when API call fails" do
      Req.Test.stub(Gemini, fn conn ->
        conn
        |> Plug.Conn.put_status(500)
        |> Req.Test.json(%{"error" => %{"message" => "Internal server error"}})
      end)

      assert {:error, {:api_error, 500, _}} = ContentWriterAgent.generate(@test_project)
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

      assert {:error, :unexpected_response_format} = ContentWriterAgent.generate(@test_project)
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

      assert {:error, :unexpected_response_format} = ContentWriterAgent.generate(@test_project)
    end

    test "handles rate limit error" do
      Req.Test.stub(Gemini, fn conn ->
        conn
        |> Plug.Conn.put_status(429)
        |> Req.Test.json(%{"error" => %{"message" => "Rate limit exceeded"}})
      end)

      assert {:error, {:rate_limited, _}} = ContentWriterAgent.generate(@test_project)
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

  describe "edge cases" do
    test "handles project with nil analysis_data" do
      project_without_analysis = %MarketMind.Products.Project{
        id: Ecto.UUID.generate(),
        name: "TestProduct",
        url: "https://test.com",
        description: "A test product",
        analysis_data: nil
      }

      Req.Test.stub(Gemini, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        request = Jason.decode!(body)
        prompt_text = hd(request["contents"])["parts"] |> hd() |> Map.get("text")

        # Should include the fallback message for nil analysis_data
        assert prompt_text =~ "No analysis data available."

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

      assert {:ok, posts} = ContentWriterAgent.generate(project_without_analysis, @test_persona)
      assert length(posts) == 2
    end

    test "handles persona with nil arrays" do
      persona_with_nils = %MarketMind.Personas.Persona{
        id: Ecto.UUID.generate(),
        name: "Nil Nancy",
        role: "Developer",
        description: "A developer persona with nil arrays.",
        pain_points: nil,
        goals: nil,
        motivations: nil,
        keywords: nil,
        channels: nil,
        is_primary: false
      }

      Req.Test.stub(Gemini, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        request = Jason.decode!(body)
        prompt_text = hd(request["contents"])["parts"] |> hd() |> Map.get("text")

        # Should include persona name without crashing on nil arrays
        assert prompt_text =~ "Nil Nancy"
        assert prompt_text =~ "Developer"

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

      assert {:ok, posts} = ContentWriterAgent.generate(@test_project, persona_with_nils)
      assert length(posts) == 2
      assert hd(posts).persona_id == persona_with_nils.id
    end

    test "handles response with missing optional fields" do
      minimal_response = %{
        "blog_posts" => [
          %{
            "title" => "Minimal Post",
            "meta_description" => "A minimal description",
            "target_keyword" => "minimal keyword",
            "secondary_keywords" => nil,
            "introduction" => nil,
            "sections" => nil,
            "conclusion" => nil,
            "call_to_action" => nil
          }
        ]
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

      assert {:ok, [post]} = ContentWriterAgent.generate(@test_project, @test_persona)
      assert post.title == "Minimal Post"
      assert post.secondary_keywords == []
      assert post.body == ""
    end

    test "handles response with empty sections array" do
      empty_sections_response = %{
        "blog_posts" => [
          %{
            "title" => "Post With Empty Sections",
            "meta_description" => "A description",
            "target_keyword" => "test keyword",
            "secondary_keywords" => ["one", "two"],
            "introduction" => "This is the intro.",
            "sections" => [],
            "conclusion" => "This is the conclusion.",
            "call_to_action" => "Try it now!"
          }
        ]
      }

      Req.Test.stub(Gemini, fn conn ->
        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(empty_sections_response)}]
              }
            }
          ]
        })
      end)

      assert {:ok, [post]} = ContentWriterAgent.generate(@test_project, @test_persona)
      assert post.body =~ "This is the intro."
      assert post.body =~ "This is the conclusion."
      assert post.body =~ "Try it now!"
      # No section headings since sections is empty
      refute post.body =~ "##"
    end

    test "handles project with partial analysis_data" do
      project_with_partial_data = %MarketMind.Products.Project{
        id: Ecto.UUID.generate(),
        name: "PartialProduct",
        url: "https://partial.com",
        description: "A product with partial analysis data",
        analysis_data: %{
          "product_name" => "PartialProduct",
          "tagline" => nil,
          "value_propositions" => nil,
          "key_features" => [],
          "target_audience" => nil,
          "industries" => []
        }
      }

      Req.Test.stub(Gemini, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        request = Jason.decode!(body)
        prompt_text = hd(request["contents"])["parts"] |> hd() |> Map.get("text")

        # Should include product name from analysis_data
        assert prompt_text =~ "PartialProduct"

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

      assert {:ok, posts} = ContentWriterAgent.generate(project_with_partial_data, @test_persona)
      assert length(posts) == 2
    end
  end

  describe "prompt building without persona" do
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

      ContentWriterAgent.generate(@test_project)
    end

    test "includes analysis data in prompt without persona" do
      Req.Test.stub(Gemini, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        request = Jason.decode!(body)

        prompt_text = hd(request["contents"])["parts"] |> hd() |> Map.get("text")

        assert prompt_text =~ "Product Analyzer"
        assert prompt_text =~ "Persona Builder"
        assert prompt_text =~ "SaaS, Marketing Technology"

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

      ContentWriterAgent.generate(@test_project)
    end

    test "does not include persona section in prompt" do
      Req.Test.stub(Gemini, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        request = Jason.decode!(body)

        prompt_text = hd(request["contents"])["parts"] |> hd() |> Map.get("text")

        # Should NOT contain persona-specific sections
        refute prompt_text =~ "Target Persona:"
        refute prompt_text =~ "Pain Points:"
        refute prompt_text =~ "Goals:"
        refute prompt_text =~ "Solo Steve"

        # But should still have the SEO requirements
        assert prompt_text =~ "SEO"
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

      ContentWriterAgent.generate(@test_project)
    end

    test "requests content for general audience" do
      Req.Test.stub(Gemini, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        request = Jason.decode!(body)

        prompt_text = hd(request["contents"])["parts"] |> hd() |> Map.get("text")

        # Should mention general audience
        assert prompt_text =~ "general audience"

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

      ContentWriterAgent.generate(@test_project)
    end
  end

  describe "generate/1 with full analysis_data" do
    test "includes all analysis fields in prompt" do
      # This ensures format_list and format_features with non-empty lists are hit
      # for the generate/1 (without persona) path
      project_with_full_data = %MarketMind.Products.Project{
        id: Ecto.UUID.generate(),
        name: "FullDataProduct",
        url: "https://fulldata.example.com",
        description: "A product with complete analysis data",
        analysis_data: %{
          "product_name" => "FullDataProduct",
          "tagline" => "Complete Data Testing",
          "value_propositions" => ["Value 1", "Value 2"],
          "key_features" => [
            %{"name" => "Feature A", "description" => "Description A"},
            %{"name" => "Feature B", "description" => "Description B"}
          ],
          "target_audience" => "Testers",
          "industries" => ["Testing", "QA"]
        }
      }

      Req.Test.stub(Gemini, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        request = Jason.decode!(body)

        prompt_text = hd(request["contents"])["parts"] |> hd() |> Map.get("text")

        # Verify all fields are included in prompt
        assert prompt_text =~ "FullDataProduct"
        assert prompt_text =~ "Complete Data Testing"
        assert prompt_text =~ "Value 1"
        assert prompt_text =~ "Value 2"
        assert prompt_text =~ "Feature A"
        assert prompt_text =~ "Feature B"
        assert prompt_text =~ "Description A"
        assert prompt_text =~ "Testing"
        assert prompt_text =~ "QA"

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

      assert {:ok, posts} = ContentWriterAgent.generate(project_with_full_data)
      assert length(posts) == 2
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
