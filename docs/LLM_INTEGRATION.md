# LLM Integration Specifications

> API specifications and patterns for LLM integrations in MarketMind.

## Overview

MarketMind uses a multi-LLM strategy:
- **Primary:** Google Gemini 1.5 Flash (cost optimization)
- **Complex Tasks:** Anthropic Claude 3.5 Sonnet (tool use, reasoning)

## LLM Behaviour

```elixir
# lib/market_mind/llm/client.ex
defmodule MarketMind.LLM.Client do
  @moduledoc """
  Behaviour for LLM client implementations.
  """

  @type message :: %{role: String.t(), content: String.t()}
  @type tool :: %{name: String.t(), description: String.t(), parameters: map()}
  
  @type completion_opts :: %{
    optional(:temperature) => float(),
    optional(:max_tokens) => integer(),
    optional(:tools) => [tool()],
    optional(:system) => String.t(),
    optional(:response_format) => :text | :json
  }

  @callback complete(
    model :: String.t(),
    messages :: [message()],
    opts :: completion_opts()
  ) :: {:ok, String.t()} | {:error, term()}

  @callback stream(
    model :: String.t(),
    messages :: [message()],
    opts :: completion_opts(),
    callback :: (String.t() -> any())
  ) :: {:ok, String.t()} | {:error, term()}

  @callback count_tokens(text :: String.t()) :: {:ok, integer()} | {:error, term()}
end
```

---

## Gemini Integration

### Configuration

```elixir
# config/runtime.exs
config :market_mind, MarketMind.LLM.Gemini,
  api_key: System.get_env("GEMINI_API_KEY"),
  base_url: "https://generativelanguage.googleapis.com/v1beta",
  default_model: "gemini-1.5-flash",
  timeout: 60_000
```

### API Endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/models/{model}:generateContent` | POST | Text generation |
| `/models/{model}:streamGenerateContent` | POST | Streaming generation |
| `/models/{model}:countTokens` | POST | Token counting |

### Implementation

```elixir
# lib/market_mind/llm/gemini.ex
defmodule MarketMind.LLM.Gemini do
  @behaviour MarketMind.LLM.Client
  
  @models %{
    "gemini-1.5-flash" => "models/gemini-1.5-flash",
    "gemini-1.5-pro" => "models/gemini-1.5-pro"
  }

  @impl true
  def complete(model, messages, opts \\ %{}) do
    body = build_request_body(messages, opts)
    
    case post("/#{@models[model]}:generateContent", body) do
      {:ok, %{status: 200, body: response}} ->
        extract_content(response)
      {:ok, %{status: 429}} ->
        {:error, :rate_limited}
      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_request_body(messages, opts) do
    %{
      contents: format_messages(messages),
      generationConfig: %{
        temperature: Map.get(opts, :temperature, 0.7),
        maxOutputTokens: Map.get(opts, :max_tokens, 4096),
        responseMimeType: response_mime_type(opts)
      }
    }
    |> maybe_add_system(opts)
  end

  defp format_messages(messages) do
    Enum.map(messages, fn
      %{role: "user", content: content} ->
        %{role: "user", parts: [%{text: content}]}
      %{role: "assistant", content: content} ->
        %{role: "model", parts: [%{text: content}]}
    end)
  end

  defp maybe_add_system(body, %{system: system}) when is_binary(system) do
    Map.put(body, :systemInstruction, %{parts: [%{text: system}]})
  end
  defp maybe_add_system(body, _), do: body

  defp response_mime_type(%{response_format: :json}), do: "application/json"
  defp response_mime_type(_), do: "text/plain"

  defp extract_content(%{"candidates" => [%{"content" => %{"parts" => [%{"text" => text}]}} | _]}) do
    {:ok, text}
  end
  defp extract_content(response) do
    {:error, {:unexpected_response, response}}
  end

  defp post(path, body) do
    Req.post(
      base_url() <> path,
      json: body,
      params: [key: api_key()],
      receive_timeout: timeout()
    )
  end

  defp base_url, do: Application.get_env(:market_mind, __MODULE__)[:base_url]
  defp api_key, do: Application.get_env(:market_mind, __MODULE__)[:api_key]
  defp timeout, do: Application.get_env(:market_mind, __MODULE__)[:timeout]
end
```

### Request/Response Examples

**Request:**
```json
{
  "contents": [
    {
      "role": "user",
      "parts": [{"text": "Write a blog post about AI marketing"}]
    }
  ],
  "systemInstruction": {
    "parts": [{"text": "You are an expert marketing copywriter."}]
  },
  "generationConfig": {
    "temperature": 0.7,
    "maxOutputTokens": 4096,
    "responseMimeType": "application/json"
  }
}
```

**Response:**
```json
{
  "candidates": [
    {
      "content": {
        "parts": [{"text": "# AI Marketing: The Future..."}],
        "role": "model"
      },
      "finishReason": "STOP"
    }
  ],
  "usageMetadata": {
    "promptTokenCount": 45,
    "candidatesTokenCount": 1200,
    "totalTokenCount": 1245
  }
}
```

---

## Claude Integration

### Configuration

```elixir
# config/runtime.exs
config :market_mind, MarketMind.LLM.Claude,
  api_key: System.get_env("ANTHROPIC_API_KEY"),
  base_url: "https://api.anthropic.com/v1",
  default_model: "claude-3-5-sonnet-20241022",
  timeout: 120_000  # Longer for tool use
```

### API Endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/messages` | POST | Text generation with tool use |

### Implementation

```elixir
# lib/market_mind/llm/claude.ex
defmodule MarketMind.LLM.Claude do
  @behaviour MarketMind.LLM.Client
  
  @api_version "2023-06-01"

  @impl true
  def complete(model, messages, opts \\ %{}) do
    body = build_request_body(model, messages, opts)
    
    case post("/messages", body) do
      {:ok, %{status: 200, body: response}} ->
        extract_content(response)
      {:ok, %{status: 429, headers: headers}} ->
        retry_after = get_retry_after(headers)
        {:error, {:rate_limited, retry_after}}
      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_request_body(model, messages, opts) do
    %{
      model: model,
      messages: format_messages(messages),
      max_tokens: Map.get(opts, :max_tokens, 4096)
    }
    |> maybe_add_system(opts)
    |> maybe_add_tools(opts)
    |> maybe_add_temperature(opts)
  end

  defp format_messages(messages) do
    Enum.map(messages, fn %{role: role, content: content} ->
      %{role: role, content: content}
    end)
  end

  defp maybe_add_system(body, %{system: system}) when is_binary(system) do
    Map.put(body, :system, system)
  end
  defp maybe_add_system(body, _), do: body

  defp maybe_add_tools(body, %{tools: tools}) when is_list(tools) and tools != [] do
    formatted_tools = Enum.map(tools, &format_tool/1)
    Map.put(body, :tools, formatted_tools)
  end
  defp maybe_add_tools(body, _), do: body

  defp format_tool(tool) do
    %{
      name: tool.name,
      description: tool.description,
      input_schema: tool.parameters
    }
  end

  defp maybe_add_temperature(body, %{temperature: temp}) do
    Map.put(body, :temperature, temp)
  end
  defp maybe_add_temperature(body, _), do: body

  defp extract_content(%{"content" => content, "stop_reason" => "tool_use"}) do
    # Handle tool use response
    tool_uses = Enum.filter(content, &(&1["type"] == "tool_use"))
    {:tool_use, tool_uses}
  end
  defp extract_content(%{"content" => [%{"type" => "text", "text" => text} | _]}) do
    {:ok, text}
  end
  defp extract_content(response) do
    {:error, {:unexpected_response, response}}
  end

  defp post(path, body) do
    Req.post(
      base_url() <> path,
      json: body,
      headers: [
        {"x-api-key", api_key()},
        {"anthropic-version", @api_version},
        {"content-type", "application/json"}
      ],
      receive_timeout: timeout()
    )
  end

  defp get_retry_after(headers) do
    case List.keyfind(headers, "retry-after", 0) do
      {_, value} -> String.to_integer(value)
      nil -> 60
    end
  end

  defp base_url, do: Application.get_env(:market_mind, __MODULE__)[:base_url]
  defp api_key, do: Application.get_env(:market_mind, __MODULE__)[:api_key]
  defp timeout, do: Application.get_env(:market_mind, __MODULE__)[:timeout]
end
```

### Tool Use Example

**Request with tools:**
```json
{
  "model": "claude-3-5-sonnet-20241022",
  "max_tokens": 4096,
  "system": "You are a competitive analysis assistant.",
  "tools": [
    {
      "name": "web_search",
      "description": "Search the web for information",
      "input_schema": {
        "type": "object",
        "properties": {
          "query": {"type": "string", "description": "Search query"}
        },
        "required": ["query"]
      }
    },
    {
      "name": "fetch_webpage",
      "description": "Fetch and parse a webpage",
      "input_schema": {
        "type": "object",
        "properties": {
          "url": {"type": "string", "description": "URL to fetch"}
        },
        "required": ["url"]
      }
    }
  ],
  "messages": [
    {"role": "user", "content": "Analyze the pricing page of competitor.com"}
  ]
}
```

**Tool use response:**
```json
{
  "content": [
    {
      "type": "tool_use",
      "id": "toolu_01ABC",
      "name": "fetch_webpage",
      "input": {"url": "https://competitor.com/pricing"}
    }
  ],
  "stop_reason": "tool_use"
}
```

---

## LLM Router

Routes tasks to appropriate LLM based on skill configuration and task complexity.

```elixir
# lib/market_mind/llm/router.ex
defmodule MarketMind.LLM.Router do
  @moduledoc """
  Routes LLM requests to appropriate provider based on task requirements.
  """

  alias MarketMind.LLM.{Gemini, Claude}

  @doc """
  Get the appropriate client for a skill.
  """
  def client_for(%{llm_provider: :gemini}), do: Gemini
  def client_for(%{llm_provider: :claude}), do: Claude
  def client_for(_), do: Gemini  # Default

  @doc """
  Determine if task requires Claude (tool use, complex reasoning).
  """
  def requires_claude?(%{tools: tools}) when is_list(tools) and tools != [], do: true
  def requires_claude?(%{complexity: :high}), do: true
  def requires_claude?(_), do: false

  @doc """
  Execute with automatic fallback.
  """
  def complete_with_fallback(skill, messages, opts) do
    client = client_for(skill)
    
    case client.complete(skill.llm_model, messages, opts) do
      {:ok, result} -> 
        {:ok, result}
      {:error, :rate_limited} ->
        # Try alternate provider
        fallback_client = fallback_for(client)
        fallback_client.complete(fallback_model(fallback_client), messages, opts)
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp fallback_for(Gemini), do: Claude
  defp fallback_for(Claude), do: Gemini

  defp fallback_model(Gemini), do: "gemini-1.5-flash"
  defp fallback_model(Claude), do: "claude-3-5-haiku-20241022"
end
```

---

## Response Caching

Cache LLM responses to reduce costs and latency.

```elixir
# lib/market_mind/llm/cache.ex
defmodule MarketMind.LLM.Cache do
  @moduledoc """
  Caches LLM responses using content-based hashing.
  """

  use Nebulex.Cache,
    otp_app: :market_mind,
    adapter: Nebulex.Adapters.Local

  @ttl :timer.hours(24)

  def get_or_complete(client, model, messages, opts) do
    key = cache_key(model, messages, opts)
    
    case get(key) do
      nil ->
        case client.complete(model, messages, opts) do
          {:ok, result} = success ->
            put(key, result, ttl: @ttl)
            success
          error ->
            error
        end
      cached ->
        {:ok, cached}
    end
  end

  defp cache_key(model, messages, opts) do
    data = %{model: model, messages: messages, opts: Map.drop(opts, [:timeout])}
    :crypto.hash(:sha256, :erlang.term_to_binary(data))
    |> Base.encode16(case: :lower)
  end
end
```

---

## Rate Limiting

```elixir
# lib/market_mind/llm/rate_limiter.ex
defmodule MarketMind.LLM.RateLimiter do
  @moduledoc """
  Token bucket rate limiter for LLM API calls.
  """

  use GenServer

  # Gemini: 1500 RPM, Claude: 50 RPM
  @limits %{
    gemini: %{requests_per_minute: 1500, tokens_per_minute: 1_000_000},
    claude: %{requests_per_minute: 50, tokens_per_minute: 100_000}
  }

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def acquire(provider, estimated_tokens \\ 1000) do
    GenServer.call(__MODULE__, {:acquire, provider, estimated_tokens})
  end

  @impl true
  def init(_opts) do
    state = %{
      gemini: %{requests: 0, tokens: 0, reset_at: next_minute()},
      claude: %{requests: 0, tokens: 0, reset_at: next_minute()}
    }
    schedule_reset()
    {:ok, state}
  end

  @impl true
  def handle_call({:acquire, provider, tokens}, _from, state) do
    limits = @limits[provider]
    current = state[provider]
    
    cond do
      current.requests >= limits.requests_per_minute ->
        {:reply, {:error, :rate_limited}, state}
      current.tokens + tokens > limits.tokens_per_minute ->
        {:reply, {:error, :token_limit}, state}
      true ->
        new_current = %{current | requests: current.requests + 1, tokens: current.tokens + tokens}
        {:reply, :ok, Map.put(state, provider, new_current)}
    end
  end

  @impl true
  def handle_info(:reset, _state) do
    schedule_reset()
    {:noreply, %{
      gemini: %{requests: 0, tokens: 0, reset_at: next_minute()},
      claude: %{requests: 0, tokens: 0, reset_at: next_minute()}
    }}
  end

  defp schedule_reset do
    Process.send_after(self(), :reset, 60_000)
  end

  defp next_minute do
    DateTime.utc_now() |> DateTime.add(60, :second)
  end
end
```

---

## Cost Tracking

```elixir
# lib/market_mind/llm/cost_tracker.ex
defmodule MarketMind.LLM.CostTracker do
  @moduledoc """
  Tracks LLM usage costs per project.
  """

  # Prices per 1M tokens (as of Dec 2024)
  @pricing %{
    "gemini-1.5-flash" => %{input: 0.075, output: 0.30},
    "gemini-1.5-pro" => %{input: 1.25, output: 5.00},
    "claude-3-5-sonnet-20241022" => %{input: 3.00, output: 15.00},
    "claude-3-5-haiku-20241022" => %{input: 0.25, output: 1.25}
  }

  def calculate_cost(model, input_tokens, output_tokens) do
    pricing = @pricing[model] || @pricing["gemini-1.5-flash"]
    
    input_cost = (input_tokens / 1_000_000) * pricing.input
    output_cost = (output_tokens / 1_000_000) * pricing.output
    
    Float.round(input_cost + output_cost, 6)
  end

  def record_usage(project_id, model, input_tokens, output_tokens) do
    cost = calculate_cost(model, input_tokens, output_tokens)
    
    %MarketMind.Analytics.LLMUsage{}
    |> MarketMind.Analytics.LLMUsage.changeset(%{
      project_id: project_id,
      model: model,
      input_tokens: input_tokens,
      output_tokens: output_tokens,
      cost_usd: cost
    })
    |> MarketMind.Repo.insert()
  end
end
```

---

## Error Handling

```elixir
# lib/market_mind/llm/errors.ex
defmodule MarketMind.LLM.Errors do
  @moduledoc """
  Standard error handling for LLM operations.
  """

  defmodule RateLimitError do
    defexception [:provider, :retry_after]
    
    def message(%{provider: provider, retry_after: retry_after}) do
      "Rate limited by #{provider}. Retry after #{retry_after} seconds."
    end
  end

  defmodule ContentFilterError do
    defexception [:reason]
    
    def message(%{reason: reason}) do
      "Content filtered: #{reason}"
    end
  end

  defmodule TokenLimitError do
    defexception [:limit, :requested]
    
    def message(%{limit: limit, requested: requested}) do
      "Token limit exceeded. Limit: #{limit}, Requested: #{requested}"
    end
  end

  def handle_api_error({:error, :rate_limited}), do: {:error, %RateLimitError{}}
  def handle_api_error({:error, {:rate_limited, retry_after}}), do: 
    {:error, %RateLimitError{retry_after: retry_after}}
  def handle_api_error({:error, {400, %{"error" => %{"message" => msg}}}}), do:
    {:error, %ContentFilterError{reason: msg}}
  def handle_api_error(error), do: error
end
```
