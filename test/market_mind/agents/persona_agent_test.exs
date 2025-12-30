defmodule MarketMind.Agents.PersonaAgentTest do
  use ExUnit.Case, async: true

  alias MarketMind.Agents.PersonaAgent
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

  @valid_persona_response %{
    "personas" => [
      %{
        "name" => "Solo Steve",
        "role" => "Solo Founder",
        "description" => "A bootstrapped founder building a SaaS product while managing all aspects of the business. He needs efficient tools to handle marketing without hiring a team.",
        "demographics" => %{
          "age_range" => "28-40",
          "location" => "US/Europe",
          "job_title" => "Founder/CEO",
          "company_size" => "1-5 employees"
        },
        "goals" => [
          "Launch product to market quickly",
          "Build sustainable revenue stream",
          "Automate repetitive tasks"
        ],
        "pain_points" => [
          "Wearing too many hats",
          "Limited marketing budget",
          "Lack of marketing expertise"
        ],
        "objections" => [
          "Not sure if AI can understand my niche",
          "Worried about the learning curve",
          "Previous bad experiences with marketing tools"
        ],
        "motivations" => [
          "Financial independence",
          "Building something meaningful",
          "Work-life flexibility"
        ],
        "channels" => [
          "Twitter/X",
          "Indie Hackers",
          "Product Hunt",
          "Reddit r/SaaS"
        ],
        "keywords" => [
          "marketing automation",
          "growth hacking for startups",
          "AI marketing tools"
        ],
        "personality_traits" => %{
          "openness" => "High - always exploring new tools and ideas",
          "conscientiousness" => "High - detail-oriented and organized",
          "extraversion" => "Medium - active online but prefers async communication",
          "agreeableness" => "Medium - collaborative but independent",
          "neuroticism" => "Medium-High - stress from wearing many hats"
        },
        "is_primary" => true
      },
      %{
        "name" => "Agency Alice",
        "role" => "Agency Owner",
        "description" => "Runs a small digital marketing agency and is always looking for tools to improve efficiency and deliver better results for clients.",
        "demographics" => %{
          "age_range" => "30-45",
          "location" => "North America",
          "job_title" => "Agency Owner/Director",
          "company_size" => "5-20 employees"
        },
        "goals" => [
          "Scale agency operations",
          "Deliver better client results",
          "Reduce manual work"
        ],
        "pain_points" => [
          "Managing multiple client accounts",
          "Keeping up with AI trends",
          "Training team on new tools"
        ],
        "objections" => [
          "Already using established tools",
          "Need white-label capabilities",
          "Concerned about reliability"
        ],
        "motivations" => [
          "Agency growth and profitability",
          "Client satisfaction",
          "Competitive differentiation"
        ],
        "channels" => [
          "LinkedIn",
          "Agency community forums",
          "Marketing conferences"
        ],
        "keywords" => [
          "agency marketing tools",
          "white-label AI marketing",
          "client reporting automation"
        ],
        "personality_traits" => %{
          "openness" => "High - early adopter of new technologies",
          "conscientiousness" => "Very High - manages multiple projects",
          "extraversion" => "High - networking is key to business",
          "agreeableness" => "High - client-focused",
          "neuroticism" => "Low-Medium - experienced with pressure"
        },
        "is_primary" => false
      },
      %{
        "name" => "Startup Sam",
        "role" => "Marketing Lead",
        "description" => "First marketing hire at a seed-stage startup, responsible for building the entire marketing function from scratch.",
        "demographics" => %{
          "age_range" => "25-35",
          "location" => "Tech hubs (SF, NYC, Austin, Remote)",
          "job_title" => "Head of Marketing / Marketing Lead",
          "company_size" => "10-50 employees"
        },
        "goals" => [
          "Prove marketing ROI to founders",
          "Build scalable marketing processes",
          "Generate qualified leads"
        ],
        "pain_points" => [
          "Limited budget for tools",
          "Pressure to show results quickly",
          "Small team doing big tasks"
        ],
        "objections" => [
          "Need approval from founders for new tools",
          "Integration with existing stack",
          "Security and data privacy concerns"
        ],
        "motivations" => [
          "Career growth and impact",
          "Building something from ground up",
          "Learning cutting-edge techniques"
        ],
        "channels" => [
          "LinkedIn",
          "GrowthHackers",
          "Marketing Twitter",
          "Slack communities"
        ],
        "keywords" => [
          "startup marketing strategy",
          "growth marketing tools",
          "marketing automation for startups"
        ],
        "personality_traits" => %{
          "openness" => "Very High - loves experimenting",
          "conscientiousness" => "High - data-driven decision maker",
          "extraversion" => "Medium-High - comfortable presenting to leadership",
          "agreeableness" => "Medium - balances stakeholder interests",
          "neuroticism" => "Medium - handles startup stress"
        },
        "is_primary" => false
      }
    ]
  }

  describe "generate/1" do
    test "returns personas when API call succeeds" do
      Req.Test.stub(Gemini, fn conn ->
        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(@valid_persona_response)}]
              }
            }
          ]
        })
      end)

      assert {:ok, personas} = PersonaAgent.generate(@test_project)
      assert is_list(personas)
      assert length(personas) == 3
    end

    test "returns persona details with all required fields" do
      Req.Test.stub(Gemini, fn conn ->
        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(@valid_persona_response)}]
              }
            }
          ]
        })
      end)

      {:ok, [first_persona | _]} = PersonaAgent.generate(@test_project)

      assert first_persona.name == "Solo Steve"
      assert first_persona.role == "Solo Founder"
      assert is_binary(first_persona.description)
      assert is_map(first_persona.demographics)
      assert is_list(first_persona.goals)
      assert is_list(first_persona.pain_points)
      assert is_list(first_persona.objections)
      assert is_list(first_persona.motivations)
      assert is_list(first_persona.channels)
      assert is_list(first_persona.keywords)
      assert is_map(first_persona.personality_traits)
      assert first_persona.is_primary == true
    end

    test "returns demographics with nested fields" do
      Req.Test.stub(Gemini, fn conn ->
        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(@valid_persona_response)}]
              }
            }
          ]
        })
      end)

      {:ok, [first_persona | _]} = PersonaAgent.generate(@test_project)
      demographics = first_persona.demographics

      assert demographics["age_range"] == "28-40"
      assert demographics["location"] == "US/Europe"
      assert demographics["job_title"] == "Founder/CEO"
      assert demographics["company_size"] == "1-5 employees"
    end

    test "returns personality traits with Big Five dimensions" do
      Req.Test.stub(Gemini, fn conn ->
        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(@valid_persona_response)}]
              }
            }
          ]
        })
      end)

      {:ok, [first_persona | _]} = PersonaAgent.generate(@test_project)
      traits = first_persona.personality_traits

      assert Map.has_key?(traits, "openness")
      assert Map.has_key?(traits, "conscientiousness")
      assert Map.has_key?(traits, "extraversion")
      assert Map.has_key?(traits, "agreeableness")
      assert Map.has_key?(traits, "neuroticism")
    end

    test "handles response with personas at top level" do
      top_level_response = @valid_persona_response["personas"]

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

      assert {:ok, personas} = PersonaAgent.generate(@test_project)
      assert is_list(personas)
      assert length(personas) == 3
    end

    test "marks exactly one persona as primary" do
      Req.Test.stub(Gemini, fn conn ->
        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(@valid_persona_response)}]
              }
            }
          ]
        })
      end)

      {:ok, personas} = PersonaAgent.generate(@test_project)
      primary_personas = Enum.filter(personas, & &1.is_primary)

      assert length(primary_personas) == 1
      assert hd(primary_personas).name == "Solo Steve"
    end

    test "returns goals as list" do
      Req.Test.stub(Gemini, fn conn ->
        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(@valid_persona_response)}]
              }
            }
          ]
        })
      end)

      {:ok, [first_persona | _]} = PersonaAgent.generate(@test_project)

      assert length(first_persona.goals) == 3
      assert "Launch product to market quickly" in first_persona.goals
    end

    test "returns pain points as list" do
      Req.Test.stub(Gemini, fn conn ->
        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(@valid_persona_response)}]
              }
            }
          ]
        })
      end)

      {:ok, [first_persona | _]} = PersonaAgent.generate(@test_project)

      assert length(first_persona.pain_points) == 3
      assert "Wearing too many hats" in first_persona.pain_points
    end

    test "returns objections as list" do
      Req.Test.stub(Gemini, fn conn ->
        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(@valid_persona_response)}]
              }
            }
          ]
        })
      end)

      {:ok, [first_persona | _]} = PersonaAgent.generate(@test_project)

      assert length(first_persona.objections) == 3
      assert "Not sure if AI can understand my niche" in first_persona.objections
    end

    test "returns channels as list" do
      Req.Test.stub(Gemini, fn conn ->
        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(@valid_persona_response)}]
              }
            }
          ]
        })
      end)

      {:ok, [first_persona | _]} = PersonaAgent.generate(@test_project)

      assert length(first_persona.channels) == 4
      assert "Twitter/X" in first_persona.channels
      assert "Indie Hackers" in first_persona.channels
    end

    test "returns keywords as list" do
      Req.Test.stub(Gemini, fn conn ->
        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(@valid_persona_response)}]
              }
            }
          ]
        })
      end)

      {:ok, [first_persona | _]} = PersonaAgent.generate(@test_project)

      assert length(first_persona.keywords) == 3
      assert "marketing automation" in first_persona.keywords
    end

    test "returns distinct personas covering different segments" do
      Req.Test.stub(Gemini, fn conn ->
        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(@valid_persona_response)}]
              }
            }
          ]
        })
      end)

      {:ok, personas} = PersonaAgent.generate(@test_project)
      names = Enum.map(personas, & &1.name)
      roles = Enum.map(personas, & &1.role)

      # All personas have unique names
      assert length(Enum.uniq(names)) == 3

      # All personas have different roles
      assert "Solo Founder" in roles
      assert "Agency Owner" in roles
      assert "Marketing Lead" in roles
    end
  end

  describe "normalization" do
    test "handles missing optional fields with defaults" do
      minimal_response = %{
        "personas" => [
          %{
            "name" => "Test User",
            "role" => "Tester",
            "description" => "A test persona"
            # Missing: demographics, goals, pain_points, objections, motivations, channels, keywords, personality_traits, is_primary
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

      {:ok, [persona]} = PersonaAgent.generate(@test_project)

      assert persona.name == "Test User"
      assert persona.role == "Tester"
      assert persona.description == "A test persona"
      assert persona.demographics == %{}
      assert persona.goals == []
      assert persona.pain_points == []
      assert persona.objections == []
      assert persona.motivations == []
      assert persona.channels == []
      assert persona.keywords == []
      assert persona.personality_traits == %{}
      assert persona.is_primary == false
    end

    test "normalizes all personas in response" do
      Req.Test.stub(Gemini, fn conn ->
        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(@valid_persona_response)}]
              }
            }
          ]
        })
      end)

      {:ok, personas} = PersonaAgent.generate(@test_project)

      Enum.each(personas, fn persona ->
        assert Map.has_key?(persona, :name)
        assert Map.has_key?(persona, :role)
        assert Map.has_key?(persona, :description)
        assert Map.has_key?(persona, :demographics)
        assert Map.has_key?(persona, :goals)
        assert Map.has_key?(persona, :pain_points)
        assert Map.has_key?(persona, :objections)
        assert Map.has_key?(persona, :motivations)
        assert Map.has_key?(persona, :channels)
        assert Map.has_key?(persona, :keywords)
        assert Map.has_key?(persona, :personality_traits)
        assert Map.has_key?(persona, :is_primary)
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

      assert {:error, {:api_error, 500, _}} = PersonaAgent.generate(@test_project)
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

      assert {:error, :unexpected_response_format} = PersonaAgent.generate(@test_project)
    end

    test "returns error when personas is not a list" do
      Req.Test.stub(Gemini, fn conn ->
        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => ~s({"personas": "not a list"})}]
              }
            }
          ]
        })
      end)

      assert {:error, :unexpected_response_format} = PersonaAgent.generate(@test_project)
    end

    test "handles rate limit error" do
      Req.Test.stub(Gemini, fn conn ->
        conn
        |> Plug.Conn.put_status(429)
        |> Req.Test.json(%{"error" => %{"message" => "Rate limit exceeded"}})
      end)

      assert {:error, {:rate_limited, _}} = PersonaAgent.generate(@test_project)
    end

    test "handles authorization error" do
      Req.Test.stub(Gemini, fn conn ->
        conn
        |> Plug.Conn.put_status(401)
        |> Req.Test.json(%{"error" => %{"message" => "Invalid API key"}})
      end)

      assert {:error, {:api_error, 401, _}} = PersonaAgent.generate(@test_project)
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
                "parts" => [%{"text" => Jason.encode!(@valid_persona_response)}]
              }
            }
          ]
        })
      end)

      PersonaAgent.generate(@test_project)
    end

    test "requests persona-specific content" do
      Req.Test.stub(Gemini, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        request = Jason.decode!(body)

        prompt_text = hd(request["contents"])["parts"] |> hd() |> Map.get("text")

        assert prompt_text =~ "Ideal Customer Profiles"
        assert prompt_text =~ "Personas"
        assert prompt_text =~ "Demographics"
        assert prompt_text =~ "Pain Points"
        assert prompt_text =~ "Goals"
        assert prompt_text =~ "Objections"
        assert prompt_text =~ "Motivations"
        assert prompt_text =~ "Channels"
        assert prompt_text =~ "Keywords"
        assert prompt_text =~ "Personality Traits"

        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(@valid_persona_response)}]
              }
            }
          ]
        })
      end)

      PersonaAgent.generate(@test_project)
    end

    test "includes analysis data in prompt" do
      Req.Test.stub(Gemini, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        request = Jason.decode!(body)

        prompt_text = hd(request["contents"])["parts"] |> hd() |> Map.get("text")

        assert prompt_text =~ "Existing Analysis Data"

        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(@valid_persona_response)}]
              }
            }
          ]
        })
      end)

      PersonaAgent.generate(@test_project)
    end

    test "requests Big Five personality traits" do
      Req.Test.stub(Gemini, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        request = Jason.decode!(body)

        prompt_text = hd(request["contents"])["parts"] |> hd() |> Map.get("text")

        assert prompt_text =~ "Big Five"
        assert prompt_text =~ "Openness"
        assert prompt_text =~ "Conscientiousness"
        assert prompt_text =~ "Extraversion"
        assert prompt_text =~ "Agreeableness"
        assert prompt_text =~ "Neuroticism"

        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(@valid_persona_response)}]
              }
            }
          ]
        })
      end)

      PersonaAgent.generate(@test_project)
    end

    test "requests primary persona designation" do
      Req.Test.stub(Gemini, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        request = Jason.decode!(body)

        prompt_text = hd(request["contents"])["parts"] |> hd() |> Map.get("text")

        assert prompt_text =~ "Primary"
        assert prompt_text =~ "exactly one persona"

        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(@valid_persona_response)}]
              }
            }
          ]
        })
      end)

      PersonaAgent.generate(@test_project)
    end

    test "requests distinct market segments" do
      Req.Test.stub(Gemini, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        request = Jason.decode!(body)

        prompt_text = hd(request["contents"])["parts"] |> hd() |> Map.get("text")

        assert prompt_text =~ "distinct"
        assert prompt_text =~ "different segments"

        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(@valid_persona_response)}]
              }
            }
          ]
        })
      end)

      PersonaAgent.generate(@test_project)
    end

    test "requests 3 personas" do
      Req.Test.stub(Gemini, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        request = Jason.decode!(body)

        prompt_text = hd(request["contents"])["parts"] |> hd() |> Map.get("text")

        assert prompt_text =~ "3 distinct"

        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(@valid_persona_response)}]
              }
            }
          ]
        })
      end)

      PersonaAgent.generate(@test_project)
    end
  end
end
