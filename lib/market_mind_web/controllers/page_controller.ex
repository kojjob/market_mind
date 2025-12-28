defmodule MarketMindWeb.PageController do
  use MarketMindWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
