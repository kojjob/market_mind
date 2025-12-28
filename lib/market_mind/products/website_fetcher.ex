defmodule MarketMind.Products.WebsiteFetcher do
  @moduledoc """
  Fetches and parses website content for product analysis.

  This module handles:
  - HTTP fetching with proper error handling
  - HTML parsing to extract meaningful content
  - Removal of non-content elements (scripts, styles, navigation)
  - Content normalization and cleaning

  ## Usage

      {:ok, result} = WebsiteFetcher.fetch("https://example.com")
      # => %{title: "Example", content: "...", meta_description: "..."}

  """

  @default_timeout 30_000
  @user_agent "MarketMind Bot/1.0 (+https://marketmind.app)"

  @doc """
  Fetches website content and extracts structured data.

  ## Returns

  - `{:ok, %{title: String.t(), content: String.t(), meta_description: String.t() | nil}}`
  - `{:error, :invalid_url}` for malformed or unsupported URLs
  - `{:error, {:http_error, status_code}}` for HTTP errors
  - `{:error, {:network_error, reason}}` for network failures

  """
  def fetch(url) do
    with :ok <- validate_url(url),
         {:ok, html} <- fetch_html(url),
         {:ok, result} <- parse_html(html) do
      {:ok, result}
    end
  end

  # URL Validation

  defp validate_url(nil), do: {:error, :invalid_url}
  defp validate_url(""), do: {:error, :invalid_url}

  defp validate_url(url) when is_binary(url) do
    case URI.parse(url) do
      %URI{scheme: scheme, host: host}
      when scheme in ["http", "https"] and is_binary(host) and host != "" ->
        :ok

      _ ->
        {:error, :invalid_url}
    end
  end

  defp validate_url(_), do: {:error, :invalid_url}

  # HTTP Fetching

  defp fetch_html(url) do
    req =
      Req.new(
        url: url,
        method: :get,
        headers: [{"user-agent", @user_agent}],
        receive_timeout: @default_timeout,
        max_redirects: 5,
        retry: false
      )
      |> maybe_attach_test_adapter()

    try do
      case Req.request(req) do
        {:ok, %{status: status, body: body}} when status in 200..299 ->
          {:ok, body}

        {:ok, %{status: status}} ->
          {:error, {:http_error, status}}

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

  defp maybe_attach_test_adapter(req) do
    if Application.get_env(:market_mind, :env) == :test do
      Req.merge(req, plug: {Req.Test, __MODULE__})
    else
      req
    end
  end

  # HTML Parsing

  defp parse_html(html) do
    case Floki.parse_document(html) do
      {:ok, document} ->
        title = extract_title(document)
        content = extract_content(document)
        meta_description = extract_meta_description(document)

        {:ok,
         %{
           title: title,
           content: content,
           meta_description: meta_description
         }}

      {:error, _reason} ->
        {:ok,
         %{
           title: "",
           content: html,
           meta_description: nil
         }}
    end
  end

  defp extract_title(document) do
    case Floki.find(document, "title") do
      [title_element | _] ->
        title_element
        |> Floki.text()
        |> String.trim()

      [] ->
        ""
    end
  end

  defp extract_content(document) do
    document
    |> remove_non_content_elements()
    |> Floki.find("body")
    |> extract_text()
    |> normalize_whitespace()
  end

  defp remove_non_content_elements(document) do
    document
    |> Floki.filter_out("script")
    |> Floki.filter_out("style")
    |> Floki.filter_out("nav")
    |> Floki.filter_out("footer")
    |> Floki.filter_out("noscript")
    |> Floki.filter_out("iframe")
  end

  defp extract_text([]), do: ""

  defp extract_text(elements) do
    elements
    |> Floki.text(sep: " ")
    |> String.trim()
  end

  defp normalize_whitespace(text) do
    text
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  defp extract_meta_description(document) do
    # Try standard meta description first
    case find_meta_content(document, "name", "description") do
      nil ->
        # Fall back to Open Graph description
        find_meta_content(document, "property", "og:description")

      description ->
        description
    end
  end

  defp find_meta_content(document, attr_name, attr_value) do
    selector = "meta[#{attr_name}=\"#{attr_value}\"]"

    case Floki.find(document, selector) do
      [meta_element | _] ->
        case Floki.attribute(meta_element, "content") do
          [content | _] when content != "" -> content
          _ -> nil
        end

      [] ->
        nil
    end
  end
end
