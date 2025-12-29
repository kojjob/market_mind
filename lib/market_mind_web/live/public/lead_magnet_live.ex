defmodule MarketMindWeb.Public.LeadMagnetLive do
  @moduledoc """
  Public LiveView for lead magnet landing pages.

  Displays the lead magnet landing page and handles email capture
  with GDPR-compliant consent tracking.

  ## Route

      live "/p/:project_slug/:slug", Public.LeadMagnetLive, :show

  ## Flow

  1. User visits public landing page
  2. Enters email and optional first name
  3. System creates subscriber with consent tracking
  4. Triggers email sequence for lead_magnet_download
  5. Shows thank you message with download access
  """
  use MarketMindWeb, :live_view

  alias MarketMind.LeadMagnets
  alias MarketMind.Leads
  alias MarketMind.EmailMarketing

  @impl true
  def mount(%{"project_slug" => project_slug, "slug" => slug}, _session, socket) do
    case fetch_lead_magnet(project_slug, slug) do
      {:ok, lead_magnet} ->
        {:ok,
         socket
         |> assign(:lead_magnet, lead_magnet)
         |> assign(:project, lead_magnet.project)
         |> assign(:form, to_form(%{"email" => "", "first_name" => ""}))
         |> assign(:submitted, false)
         |> assign(:error, nil)
         |> assign(:page_title, lead_magnet.title)}

      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, "Lead magnet not found")
         |> redirect(to: "/")}
    end
  end

  defp fetch_lead_magnet(project_slug, slug) do
    {:ok, LeadMagnets.get_active_lead_magnet_by_slugs!(project_slug, slug)}
  rescue
    Ecto.NoResultsError -> {:error, :not_found}
  end

  @impl true
  def handle_event("submit", %{"email" => email, "first_name" => first_name}, socket) do
    lead_magnet = socket.assigns.lead_magnet
    project = socket.assigns.project

    # Build consent info from connection
    consent_info = build_consent_info(socket)

    attrs = %{
      email: email,
      first_name: first_name,
      source: "lead_magnet",
      source_id: lead_magnet.id,
      tags: ["lead_magnet:#{lead_magnet.slug}"]
    }

    case Leads.create_subscriber(project, attrs, consent_info) do
      {:ok, subscriber} ->
        # Increment download count
        LeadMagnets.increment_download_count(lead_magnet)

        # Trigger email sequence for lead magnet download
        EmailMarketing.trigger_sequence(subscriber, "lead_magnet_download", lead_magnet.id)

        {:noreply,
         socket
         |> assign(:submitted, true)
         |> assign(:subscriber, subscriber)}

      {:error, %Ecto.Changeset{} = changeset} ->
        error = extract_error(changeset)

        {:noreply,
         socket
         |> assign(:error, error)
         |> assign(:form, to_form(%{"email" => email, "first_name" => first_name}))}
    end
  end

  defp build_consent_info(socket) do
    %{
      ip: get_connect_info(socket, :peer_data) |> format_ip(),
      user_agent: get_connect_info(socket, :user_agent)
    }
  end

  defp format_ip(nil), do: nil
  defp format_ip(%{address: {a, b, c, d}}), do: "#{a}.#{b}.#{c}.#{d}"
  defp format_ip(%{address: address}) when is_tuple(address), do: :inet.ntoa(address) |> to_string()
  defp format_ip(_), do: nil

  defp extract_error(changeset) do
    case changeset.errors[:email] do
      {msg, _opts} -> "Email #{msg}"
      nil -> "Unable to subscribe. Please try again."
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-indigo-50 via-white to-purple-50">
      <div class="max-w-4xl mx-auto px-4 py-16 sm:px-6 lg:px-8">
        <%= if @submitted do %>
          <!-- Thank You State -->
          <div class="text-center">
            <div class="mx-auto flex items-center justify-center h-16 w-16 rounded-full bg-green-100 mb-6">
              <svg class="h-8 w-8 text-green-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
              </svg>
            </div>

            <h1 class="text-3xl font-bold text-gray-900 mb-4">
              You're In!
            </h1>

            <div class="prose prose-lg mx-auto text-gray-600 mb-8">
              <%= if @lead_magnet.thank_you_message do %>
                <%= raw(@lead_magnet.thank_you_message) %>
              <% else %>
                <p>Thank you for subscribing! Check your email for your download link.</p>
              <% end %>
            </div>

            <%= if @lead_magnet.download_url do %>
              <a
                href={@lead_magnet.download_url}
                class="inline-flex items-center px-6 py-3 border border-transparent text-base font-medium rounded-md shadow-sm text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
              >
                <svg class="mr-2 h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
                </svg>
                Download Now
              </a>
            <% end %>
          </div>
        <% else %>
          <!-- Landing Page State -->
          <div class="text-center mb-12">
            <div class="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-indigo-100 text-indigo-800 mb-4">
              Free <%= String.capitalize(@lead_magnet.magnet_type) %>
            </div>

            <h1 class="text-4xl sm:text-5xl font-extrabold text-gray-900 tracking-tight mb-4">
              <%= @lead_magnet.headline || @lead_magnet.title %>
            </h1>

            <%= if @lead_magnet.subheadline do %>
              <p class="text-xl text-gray-600 max-w-2xl mx-auto">
                <%= @lead_magnet.subheadline %>
              </p>
            <% end %>
          </div>

          <div class="bg-white rounded-2xl shadow-xl overflow-hidden max-w-xl mx-auto">
            <div class="px-6 py-8 sm:p-10">
              <%= if @lead_magnet.description do %>
                <p class="text-gray-600 mb-6 text-center">
                  <%= @lead_magnet.description %>
                </p>
              <% end %>

              <.form for={@form} phx-submit="submit" class="space-y-4">
                <div>
                  <label for="first_name" class="block text-sm font-medium text-gray-700 mb-1">
                    First Name <span class="text-gray-400">(optional)</span>
                  </label>
                  <input
                    type="text"
                    name="first_name"
                    id="first_name"
                    value={@form.params["first_name"]}
                    placeholder="Your first name"
                    class="block w-full px-4 py-3 rounded-lg border border-gray-300 shadow-sm focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
                  />
                </div>

                <div>
                  <label for="email" class="block text-sm font-medium text-gray-700 mb-1">
                    Email Address <span class="text-red-500">*</span>
                  </label>
                  <input
                    type="email"
                    name="email"
                    id="email"
                    value={@form.params["email"]}
                    placeholder="you@example.com"
                    required
                    class="block w-full px-4 py-3 rounded-lg border border-gray-300 shadow-sm focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
                  />
                </div>

                <%= if @error do %>
                  <div class="rounded-md bg-red-50 p-3">
                    <div class="flex">
                      <svg class="h-5 w-5 text-red-400" viewBox="0 0 20 20" fill="currentColor">
                        <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd" />
                      </svg>
                      <p class="ml-2 text-sm text-red-700"><%= @error %></p>
                    </div>
                  </div>
                <% end %>

                <button
                  type="submit"
                  class="w-full flex justify-center py-3 px-4 border border-transparent rounded-lg shadow-sm text-base font-medium text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 transition-colors"
                >
                  <%= @lead_magnet.cta_text || "Get Free Access" %>
                </button>

                <p class="text-xs text-gray-500 text-center mt-4">
                  By subscribing, you agree to receive emails from <%= @project.name %>.
                  You can unsubscribe at any time.
                </p>
              </.form>
            </div>
          </div>

          <!-- Content Preview (if available) -->
          <%= if @lead_magnet.content do %>
            <div class="mt-12 max-w-2xl mx-auto">
              <h2 class="text-lg font-semibold text-gray-900 mb-4 text-center">
                What's Inside
              </h2>
              <div class="bg-white rounded-lg shadow p-6 prose prose-indigo max-w-none">
                <%= raw(preview_content(@lead_magnet.content)) %>
              </div>
            </div>
          <% end %>
        <% end %>

        <!-- Footer -->
        <div class="mt-16 text-center text-sm text-gray-500">
          <p>Powered by <%= @project.name %></p>
        </div>
      </div>
    </div>
    """
  end

  # Show a preview of the content (first ~200 chars, preserving markdown structure)
  defp preview_content(content) when is_binary(content) do
    content
    |> String.split("\n")
    |> Enum.take(10)
    |> Enum.join("\n")
    |> truncate_with_ellipsis(500)
    |> Earmark.as_html!()
  end

  defp preview_content(_), do: ""

  defp truncate_with_ellipsis(text, max_length) when byte_size(text) <= max_length, do: text

  defp truncate_with_ellipsis(text, max_length) do
    String.slice(text, 0, max_length) <> "..."
  end
end
