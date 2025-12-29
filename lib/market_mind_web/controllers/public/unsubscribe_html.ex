defmodule MarketMindWeb.Public.UnsubscribeHTML do
  @moduledoc """
  HTML view module for unsubscribe pages.

  Renders the unsubscribe confirmation and success templates.
  """
  use MarketMindWeb, :html

  embed_templates "unsubscribe_html/*"
end
