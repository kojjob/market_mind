defmodule MarketMind.LLM do
  @moduledoc """
  Behavior for LLM (Large Language Model) providers.

  This behavior defines the contract that any LLM provider must implement.
  Currently supports:
  - Text completion (free-form responses)
  - JSON completion (structured responses with schema validation)

  ## Configuration

  Configure the LLM provider in your config:

      config :market_mind, :llm_client, MarketMind.LLM.Gemini

  In tests, use the mock:

      config :market_mind, :llm_client, MarketMind.LLM.Mock

  ## Usage

      iex> MarketMind.LLM.complete("Explain Elixir in one sentence")
      {:ok, "Elixir is a functional, concurrent programming language..."}

      iex> MarketMind.LLM.complete_json("Extract product info", %{name: :string})
      {:ok, %{"name" => "My Product"}}

  """

  @doc """
  Completes a prompt and returns the text response.

  ## Options

  - `:temperature` - Controls randomness (0.0 to 1.0, default: 0.7)
  - `:max_tokens` - Maximum tokens in response (default: 2048)
  - `:model` - Model to use (default: "gemini-1.5-flash")

  ## Returns

  - `{:ok, response_text}` on success
  - `{:error, reason}` on failure

  """
  @callback complete(prompt :: String.t(), opts :: keyword()) ::
              {:ok, String.t()} | {:error, term()}

  @doc """
  Completes a prompt and returns a structured JSON response.

  The response is validated against the provided schema and parsed into a map.

  ## Options

  Same as `complete/2`

  ## Returns

  - `{:ok, parsed_json_map}` on success
  - `{:error, :invalid_json}` if response is not valid JSON
  - `{:error, reason}` on API failure

  """
  @callback complete_json(prompt :: String.t(), schema :: map(), opts :: keyword()) ::
              {:ok, map()} | {:error, term()}

  @doc """
  Returns the configured LLM client module.
  """
  def client do
    Application.get_env(:market_mind, :llm_client, MarketMind.LLM.Gemini)
  end

  @doc """
  Delegates to the configured client's complete/2 function.
  """
  def complete(prompt, opts \\ []) do
    client().complete(prompt, opts)
  end

  @doc """
  Delegates to the configured client's complete_json/3 function.
  """
  def complete_json(prompt, schema, opts \\ []) do
    client().complete_json(prompt, schema, opts)
  end
end
