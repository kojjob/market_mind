defmodule MarketMind.LLM.Gemini do
  @moduledoc """
  Google Gemini API client implementation.

  This module implements the MarketMind.LLM behavior for Google's Gemini API.
  It handles both text completion and structured JSON responses.

  ## Configuration

  Set your API key in the environment or config:

      config :market_mind, MarketMind.LLM.Gemini,
        api_key: System.get_env("GEMINI_API_KEY")

  ## Usage

      # Text completion
      {:ok, response} = MarketMind.LLM.Gemini.complete("Explain Elixir")

      # JSON completion
      schema = %{name: :string, features: [:string]}
      {:ok, data} = MarketMind.LLM.Gemini.complete_json("Analyze this product", schema)

  """

  @behaviour MarketMind.LLM

  @base_url "https://generativelanguage.googleapis.com/v1beta/models"
  # Updated to gemini-2.5-flash (latest stable, released June 2025)
  # Available models: gemini-2.5-flash (latest), gemini-2.0-flash (stable)
  @default_model "gemini-2.5-flash"
  @default_temperature 0.7
  # Increased from 2048 to allow complete structured JSON responses
  # Analysis responses can be 3000+ tokens for complex products
  @default_max_tokens 4096

  # Retry configuration for rate limiting
  # Gemini free tier: 20 requests/minute, so we wait with exponential backoff
  @max_retries 3
  # Delays are configurable via application config for testing
  # In test mode, we use 1ms delays to speed up tests
  @default_base_delay_ms 5_000  # Start with 5 seconds
  @default_max_delay_ms 60_000  # Cap at 60 seconds

  @doc """
  Completes a prompt and returns the text response.

  ## Options

  - `:temperature` - Controls randomness (0.0 to 1.0, default: 0.7)
  - `:max_tokens` - Maximum tokens in response (default: 2048)
  - `:model` - Model to use (default: "gemini-1.5-flash")
  - `:api_key` - Override API key (default: from config)

  ## Returns

  - `{:ok, response_text}` on success
  - `{:error, reason}` on failure

  """
  @impl MarketMind.LLM
  def complete(prompt, opts \\ []) do
    case get_api_key(opts) do
      nil ->
        {:error, :missing_api_key}

      api_key ->
        model = Keyword.get(opts, :model, @default_model)

        body = build_request_body(prompt, opts)

        case make_request(model, api_key, body) do
          {:ok, response} ->
            extract_text_content(response)

          {:error, _} = error ->
            error
        end
    end
  end

  @doc """
  Completes a prompt and returns a structured JSON response.

  The response is parsed into a map. The schema is included in the prompt
  to guide the model's output format.

  ## Options

  Same as `complete/2`

  ## Returns

  - `{:ok, parsed_json_map}` on success
  - `{:error, :invalid_json}` if response is not valid JSON
  - `{:error, reason}` on API failure

  """
  @impl MarketMind.LLM
  def complete_json(prompt, schema, opts \\ []) do
    enhanced_prompt = build_json_prompt(prompt, schema)

    case complete(enhanced_prompt, opts) do
      {:ok, text} ->
        parse_json_response(text)

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Completes a prompt and returns both the response and usage metadata.

  ## Returns

  - `{:ok, response_text, metadata}` on success where metadata contains token counts
  - `{:error, reason}` on failure

  """
  def complete_with_metadata(prompt, opts \\ []) do
    case get_api_key(opts) do
      nil ->
        {:error, :missing_api_key}

      api_key ->
        model = Keyword.get(opts, :model, @default_model)
        body = build_request_body(prompt, opts)

        case make_request(model, api_key, body) do
          {:ok, response} ->
            case extract_text_content(response) do
              {:ok, text} ->
                metadata = extract_metadata(response)
                {:ok, text, metadata}

              {:error, _} = error ->
                error
            end

          {:error, _} = error ->
            error
        end
    end
  end

  # Private functions

  defp get_api_key(opts) do
    case Keyword.get(opts, :api_key, :not_provided) do
      :not_provided ->
        config = Application.get_env(:market_mind, __MODULE__, [])
        Keyword.get(config, :api_key) || System.get_env("GEMINI_API_KEY")

      nil ->
        nil

      key ->
        key
    end
  end

  defp build_request_body(prompt, opts) do
    %{
      contents: [
        %{
          parts: [%{text: prompt}]
        }
      ],
      generationConfig: %{
        temperature: Keyword.get(opts, :temperature, @default_temperature),
        maxOutputTokens: Keyword.get(opts, :max_tokens, @default_max_tokens)
      }
    }
  end

  defp build_json_prompt(prompt, schema) do
    schema_description = format_schema(schema)

    """
    #{prompt}

    Respond with valid JSON only. No markdown, no explanation, just JSON.
    Use this structure:
    #{schema_description}
    """
  end

  defp format_schema(schema) when is_map(schema) do
    Jason.encode!(schema, pretty: true)
  end

  defp format_schema(_), do: "{}"

  defp make_request(model, api_key, body) do
    make_request_with_retry(model, api_key, body, 0)
  end

  defp make_request_with_retry(model, api_key, body, attempt) when attempt >= @max_retries do
    # Max retries exhausted, make final attempt without retry
    do_make_request(model, api_key, body)
  end

  defp make_request_with_retry(model, api_key, body, attempt) do
    case do_make_request(model, api_key, body) do
      {:error, {:rate_limited, message}} = error ->
        if attempt < @max_retries do
          delay = calculate_backoff_delay(attempt)
          log_rate_limit_retry(attempt, delay, message)
          Process.sleep(delay)
          make_request_with_retry(model, api_key, body, attempt + 1)
        else
          error
        end

      result ->
        result
    end
  end

  defp do_make_request(model, api_key, body) do
    url = "#{@base_url}/#{model}:generateContent?key=#{api_key}"

    req =
      Req.new(
        url: url,
        method: :post,
        json: body,
        receive_timeout: 60_000
      )
      |> maybe_attach_test_adapter()

    try do
      case Req.request(req) do
        {:ok, %{status: 200, body: body}} ->
          {:ok, body}

        {:ok, %{status: 429, body: body}} ->
          message = get_in(body, ["error", "message"]) || "Rate limit exceeded"
          {:error, {:rate_limited, message}}

        {:ok, %{status: status, body: body}} ->
          message = get_in(body, ["error", "message"]) || "Unknown error"
          {:error, {:api_error, status, message}}

        {:error, %Req.TransportError{reason: reason}} ->
          {:error, {:network_error, reason}}

        {:error, reason} ->
          {:error, {:network_error, reason}}
      end
    rescue
      e in Req.TransportError ->
        {:error, {:network_error, e.reason}}
    end
  end

  defp calculate_backoff_delay(attempt) do
    {base_delay, max_delay} = get_retry_delays()
    # Exponential backoff: base_delay * 2^attempt, with jitter
    base = base_delay * :math.pow(2, attempt) |> round()
    capped = min(base, max_delay)
    # Add random jitter (0-25% of delay) to prevent thundering herd
    # In test mode with 1ms delays, jitter = 0 (div(0, 4) = 0)
    jitter = if capped > 0, do: :rand.uniform(max(div(capped, 4), 1)), else: 0
    capped + jitter
  end

  defp get_retry_delays do
    # In test mode, use minimal delays to speed up tests
    if Application.get_env(:market_mind, :env) == :test do
      {1, 1}  # 1ms delays in test mode
    else
      {@default_base_delay_ms, @default_max_delay_ms}
    end
  end

  defp log_rate_limit_retry(attempt, delay, message) do
    require Logger

    Logger.warning(
      "[Gemini] Rate limited (attempt #{attempt + 1}/#{@max_retries}). " <>
        "Retrying in #{div(delay, 1000)}s. Reason: #{message}"
    )
  end

  defp maybe_attach_test_adapter(req) do
    if Application.get_env(:market_mind, :env) == :test do
      Req.merge(req, plug: {Req.Test, __MODULE__})
    else
      req
    end
  end

  defp extract_text_content(response) do
    case get_in(response, ["candidates"]) do
      [%{"content" => %{"parts" => [%{"text" => text} | _]}} | _] ->
        {:ok, text}

      [] ->
        {:error, :no_content}

      _ ->
        {:error, :unexpected_response_format}
    end
  end

  defp extract_metadata(response) do
    usage = Map.get(response, "usageMetadata", %{})

    %{
      prompt_tokens: Map.get(usage, "promptTokenCount", 0),
      completion_tokens: Map.get(usage, "candidatesTokenCount", 0),
      total_tokens: Map.get(usage, "totalTokenCount", 0)
    }
  end

  defp parse_json_response(text) do
    # Handle JSON wrapped in markdown code blocks
    cleaned_text = clean_json_text(text)

    case Jason.decode(cleaned_text) do
      {:ok, parsed} ->
        {:ok, parsed}

      {:error, _} ->
        {:error, :invalid_json}
    end
  end

  defp clean_json_text(text) do
    text
    |> String.trim()
    |> remove_markdown_code_blocks()
    |> String.trim()
  end

  defp remove_markdown_code_blocks(text) do
    # Remove ```json and ``` markers
    text
    |> String.replace(~r/^```json\s*/m, "")
    |> String.replace(~r/^```\s*/m, "")
    |> String.replace(~r/\s*```$/m, "")
  end
end
