defmodule MarketMindWeb.Router do
  use MarketMindWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {MarketMindWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", MarketMindWeb do
    pipe_through :browser

    get "/", PageController, :home

    # Project LiveViews
    live "/projects", ProjectLive.Index, :index
    live "/projects/new", ProjectLive.New, :new
    live "/projects/:slug", ProjectLive.Show, :show

    # Persona LiveViews
    live "/projects/:slug/personas/compare", PersonaLive.Compare, :index
    live "/projects/:slug/personas/:id", PersonaLive.Show, :show
    live "/projects/:slug/personas/:id/edit", PersonaLive.Show, :edit
  end

  # Public routes (no authentication required)
  # These are accessed from email links and public landing pages
  scope "/p", MarketMindWeb.Public do
    pipe_through :browser

    # Lead magnet landing pages
    live "/:project_slug/:slug", LeadMagnetLive, :show

    # Lead magnet file downloads (after email capture)
    get "/:project_slug/:slug/download/:subscriber_id", LeadMagnetController, :download

    # Email unsubscribe flow
    get "/unsubscribe/:token", UnsubscribeController, :show
    post "/unsubscribe/:token", UnsubscribeController, :unsubscribe
  end

  # Other scopes may use custom stacks.
  # scope "/api", MarketMindWeb do
  #   pipe_through :api
  # end
end
