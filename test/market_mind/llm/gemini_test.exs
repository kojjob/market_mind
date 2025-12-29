defmodule MarketMind.LLM.GeminiTest do
  use ExUnit.Case, async: true

  import Mox

  alias MarketMind.LLM.Gemini

  # Make sure mocks are verified when the test exits
  setup :verify_on_exit!

  describe "complete/2" do
    test "returns response text on successful API call" do
      # This test will use Req's test adapter to mock HTTP
      Req.Test.stub(Gemini, fn conn ->
        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => "Elixir is a functional programming language."}]
              }
            }
          ]
        })
      end)

      assert {:ok, response} = Gemini.complete("Explain Elixir")
      assert response == "Elixir is a functional programming language."
    end

    test "handles empty response from API" do
      Req.Test.stub(Gemini, fn conn ->
        Req.Test.json(conn, %{"candidates" => []})
      end)

      assert {:error, :no_content} = Gemini.complete("test prompt")
    end

    test "handles API error response" do
      Req.Test.stub(Gemini, fn conn ->
        conn
        |> Plug.Conn.put_status(500)
        |> Req.Test.json(%{"error" => %{"message" => "Internal server error"}})
      end)

      assert {:error, {:api_error, 500, _}} = Gemini.complete("test prompt")
    end

    test "handles rate limit error (429)" do
      Req.Test.stub(Gemini, fn conn ->
        conn
        |> Plug.Conn.put_status(429)
        |> Req.Test.json(%{"error" => %{"message" => "Rate limit exceeded"}})
      end)

      assert {:error, {:rate_limited, _}} = Gemini.complete("test prompt")
    end

    test "handles network timeout" do
      Req.Test.stub(Gemini, fn _conn ->
        raise Req.TransportError, reason: :timeout
      end)

      assert {:error, {:network_error, :timeout}} = Gemini.complete("test prompt")
    end

    test "respects custom temperature option" do
      Req.Test.stub(Gemini, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        request = Jason.decode!(body)

        # Verify temperature is passed correctly
        assert request["generationConfig"]["temperature"] == 0.2

        Req.Test.json(conn, %{
          "candidates" => [
            %{"content" => %{"parts" => [%{"text" => "Response"}]}}
          ]
        })
      end)

      assert {:ok, _} = Gemini.complete("test", temperature: 0.2)
    end

    test "respects custom max_tokens option" do
      Req.Test.stub(Gemini, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        request = Jason.decode!(body)

        # Verify max_tokens is passed correctly
        assert request["generationConfig"]["maxOutputTokens"] == 500

        Req.Test.json(conn, %{
          "candidates" => [
            %{"content" => %{"parts" => [%{"text" => "Response"}]}}
          ]
        })
      end)

      assert {:ok, _} = Gemini.complete("test", max_tokens: 500)
    end

    test "uses default model when not specified" do
      Req.Test.stub(Gemini, fn conn ->
        # Verify the URL contains the default model
        assert conn.request_path =~ "gemini-2.5-flash"

        Req.Test.json(conn, %{
          "candidates" => [
            %{"content" => %{"parts" => [%{"text" => "Response"}]}}
          ]
        })
      end)

      assert {:ok, _} = Gemini.complete("test")
    end

    test "uses custom model when specified" do
      Req.Test.stub(Gemini, fn conn ->
        # Verify the URL contains the custom model
        assert conn.request_path =~ "gemini-1.5-pro"

        Req.Test.json(conn, %{
          "candidates" => [
            %{"content" => %{"parts" => [%{"text" => "Response"}]}}
          ]
        })
      end)

      assert {:ok, _} = Gemini.complete("test", model: "gemini-1.5-pro")
    end
  end

  describe "complete_json/3" do
    test "returns parsed JSON on successful API call" do
      Req.Test.stub(Gemini, fn conn ->
        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [
                  %{
                    "text" => ~s({"product_name": "MarketMind", "tagline": "AI Marketing"})
                  }
                ]
              }
            }
          ]
        })
      end)

      schema = %{
        product_name: :string,
        tagline: :string
      }

      assert {:ok, result} = Gemini.complete_json("Analyze this product", schema)
      assert result["product_name"] == "MarketMind"
      assert result["tagline"] == "AI Marketing"
    end

    test "handles JSON wrapped in markdown code blocks" do
      Req.Test.stub(Gemini, fn conn ->
        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [
                  %{
                    "text" => """
                    ```json
                    {"name": "Test Product", "price": 99}
                    ```
                    """
                  }
                ]
              }
            }
          ]
        })
      end)

      assert {:ok, result} = Gemini.complete_json("test", %{})
      assert result["name"] == "Test Product"
      assert result["price"] == 99
    end

    test "returns error for invalid JSON response" do
      Req.Test.stub(Gemini, fn conn ->
        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => "This is not valid JSON at all"}]
              }
            }
          ]
        })
      end)

      assert {:error, :invalid_json} = Gemini.complete_json("test", %{})
    end

    test "includes schema in prompt for structured output" do
      Req.Test.stub(Gemini, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        request = Jason.decode!(body)

        # The prompt should include schema information
        prompt_text = hd(request["contents"])["parts"] |> hd() |> Map.get("text")
        assert prompt_text =~ "JSON"
        assert prompt_text =~ "product_name"

        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => ~s({"product_name": "Test"})}]
              }
            }
          ]
        })
      end)

      schema = %{product_name: :string}
      assert {:ok, _} = Gemini.complete_json("Analyze", schema)
    end

    test "handles nested JSON structures" do
      Req.Test.stub(Gemini, fn conn ->
        Req.Test.json(conn, %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [
                  %{
                    "text" => ~s({
                      "product": {
                        "name": "Test",
                        "features": ["Feature 1", "Feature 2"]
                      },
                      "pricing": {"amount": 99, "currency": "USD"}
                    })
                  }
                ]
              }
            }
          ]
        })
      end)

      assert {:ok, result} = Gemini.complete_json("test", %{})
      assert result["product"]["name"] == "Test"
      assert result["product"]["features"] == ["Feature 1", "Feature 2"]
      assert result["pricing"]["amount"] == 99
    end

    test "handles API errors same as complete/2" do
      Req.Test.stub(Gemini, fn conn ->
        conn
        |> Plug.Conn.put_status(500)
        |> Req.Test.json(%{"error" => %{"message" => "Server error"}})
      end)

      assert {:error, {:api_error, 500, _}} = Gemini.complete_json("test", %{})
    end
  end

  describe "API key configuration" do
    test "uses API key from application config" do
      Req.Test.stub(Gemini, fn conn ->
        # Verify API key is in the query string
        assert conn.query_string =~ "key="

        Req.Test.json(conn, %{
          "candidates" => [
            %{"content" => %{"parts" => [%{"text" => "Response"}]}}
          ]
        })
      end)

      assert {:ok, _} = Gemini.complete("test")
    end

    test "returns error when API key is not configured" do
      # This test would need to temporarily unset the API key
      # In practice, this would be tested by checking the error at startup
      # or by using a separate test configuration
      assert {:error, :missing_api_key} = Gemini.complete("test", api_key: nil)
    end
  end

  describe "token counting" do
    test "returns token count in metadata when requested" do
      Req.Test.stub(Gemini, fn conn ->
        Req.Test.json(conn, %{
          "candidates" => [
            %{"content" => %{"parts" => [%{"text" => "Response"}]}}
          ],
          "usageMetadata" => %{
            "promptTokenCount" => 10,
            "candidatesTokenCount" => 5,
            "totalTokenCount" => 15
          }
        })
      end)

      assert {:ok, response, metadata} = Gemini.complete_with_metadata("test")
      assert response == "Response"
      assert metadata.prompt_tokens == 10
      assert metadata.completion_tokens == 5
      assert metadata.total_tokens == 15
    end
  end
end
