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
    # Capture consent info during mount (only time connect_info is available)
    consent_info = build_consent_info(socket)

    case fetch_lead_magnet(project_slug, slug) do
      {:ok, lead_magnet} ->
        {:ok,
         socket
         |> assign(:lead_magnet, lead_magnet)
         |> assign(:project, lead_magnet.project)
         |> assign(:form, to_form(%{"email" => "", "first_name" => ""}))
         |> assign(:submitted, false)
         |> assign(:error, nil)
         |> assign(:page_title, lead_magnet.title)
         |> assign(:consent_info, consent_info)}

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

    # Use consent info captured during mount (get_connect_info only available in mount)
    consent_info = socket.assigns.consent_info

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
    <div class="min-h-screen bg-[#f8fafc] font-sans antialiased">
      <div class="max-w-4xl mx-auto px-6 py-20 sm:px-8 lg:px-12">
        <%= if @submitted do %>
          <!-- Thank You State -->
          <div class="text-center animate-in fade-in slide-in-from-bottom-4 duration-700">
            <div class="mx-auto flex items-center justify-center size-24 rounded-3xl bg-primary/10 text-primary mb-10 shadow-xl shadow-primary/5">
              <.icon name="hero-check-badge" class="size-12" />
            </div>

            <h1 class="text-4xl font-bold text-[#1a202c] mb-6 tracking-tight">
              You're In!
            </h1>

            <div class="prose prose-lg mx-auto text-[#4a5568] mb-12 leading-relaxed">
              <%= if @lead_magnet.thank_you_message do %>
                <%= raw(@lead_magnet.thank_you_message) %>
              <% else %>
                <p class="font-medium">Thank you for subscribing! Check your email for your download link.</p>
              <% end %>
            </div>

            <%= if @lead_magnet.download_url do %>
              <a
                href={@lead_magnet.download_url}
                class="inline-flex items-center px-10 py-5 rounded-2xl text-white bg-primary hover:bg-primary/90 transition-all shadow-xl shadow-primary/20 font-bold text-lg"
              >
                <.icon name="hero-arrow-down-tray" class="mr-3 size-6" />
                Download Now
              </a>
            <% else %>
              <a
                href={~p"/p/#{@project.slug}/#{@lead_magnet.slug}/download/#{@subscriber.id}"}
                class="inline-flex items-center px-10 py-5 rounded-2xl text-white bg-primary hover:bg-primary/90 transition-all shadow-xl shadow-primary/20 font-bold text-lg"
              >
                <.icon name="hero-arrow-down-tray" class="mr-3 size-6" />
                Download Now
              </a>
            <% end %>
          </div>
        <% else %>
          <!-- Landing Page State -->
          <div class="text-center mb-16 animate-in fade-in slide-in-from-top-4 duration-700">
            <div class="inline-flex items-center px-4 py-1.5 rounded-full text-xs font-bold bg-primary/10 text-primary uppercase tracking-widest mb-6">
              Free {@lead_magnet.magnet_type}
            </div>

            <h1 class="text-4xl sm:text-6xl font-extrabold text-[#1a202c] tracking-tight mb-8 leading-[1.1]">
              {@lead_magnet.headline || @lead_magnet.title}
            </h1>

            <%= if @lead_magnet.subheadline do %>
              <p class="text-xl text-[#718096] max-w-2xl mx-auto font-medium leading-relaxed">
                {@lead_magnet.subheadline}
              </p>
            <% end %>
          </div>

          <div class="bg-white rounded-[2.5rem] shadow-2xl shadow-gray-200/50 overflow-hidden max-w-xl mx-auto border border-[#edf2f7]">
            <div class="px-8 py-12 sm:p-16">
              <%= if @lead_magnet.description do %>
                <p class="text-[#4a5568] mb-10 text-center text-lg font-medium leading-relaxed">
                  {@lead_magnet.description}
                </p>
              <% end %>

              <.form for={@form} phx-submit="submit" class="space-y-6">
                <div class="space-y-2">
                  <label for="first_name" class="block text-sm font-bold text-[#1a202c] ml-1">
                    First Name <span class="text-[#718096] font-medium">(optional)</span>
                  </label>
                  <input
                    type="text"
                    name="first_name"
                    id="first_name"
                    value={@form.params["first_name"]}
                    placeholder="Your first name"
                    class="block w-full px-6 py-4 rounded-2xl border-[#edf2f7] bg-gray-50/50 focus:bg-white focus:ring-4 focus:ring-primary/10 focus:border-primary transition-all text-[#1a202c] font-medium placeholder:text-[#a0aec0]"
                  />
                </div>

                <div class="space-y-2">
                  <label for="email" class="block text-sm font-bold text-[#1a202c] ml-1">
                    Email Address <span class="text-red-500">*</span>
                  </label>
                  <input
                    type="email"
                    name="email"
                    id="email"
                    value={@form.params["email"]}
                    placeholder="you@example.com"
                    required
                    class="block w-full px-6 py-4 rounded-2xl border-[#edf2f7] bg-gray-50/50 focus:bg-white focus:ring-4 focus:ring-primary/10 focus:border-primary transition-all text-[#1a202c] font-medium placeholder:text-[#a0aec0]"
                  />
                </div>

                <%= if @error do %>
                  <div class="rounded-2xl bg-red-50 p-4 border border-red-100 animate-in shake duration-500">
                    <div class="flex items-center gap-3">
                      <.icon name="hero-exclamation-circle" class="size-5 text-red-500" />
                      <p class="text-sm text-red-700 font-bold">{@error}</p>
                    </div>
                  </div>
                <% end %>

                <button
                  type="submit"
                  class="w-full flex justify-center py-5 px-8 rounded-2xl shadow-xl shadow-primary/20 text-lg font-bold text-white bg-primary hover:bg-primary/90 focus:ring-4 focus:ring-primary/20 transition-all active:scale-[0.98]"
                >
                  {@lead_magnet.cta_text || "Get Free Access"}
                </button>

                <p class="text-xs text-[#718096] text-center mt-8 font-medium leading-relaxed">
                  By subscribing, you agree to receive emails from {@project.name}.
                  <br />You can unsubscribe at any time.
                </p>
              </.form>
            </div>
          </div>

          <!-- Content Preview (if available) -->
          <%= if @lead_magnet.content do %>
            <div class="mt-20 max-w-2xl mx-auto">
              <div class="flex items-center gap-4 mb-8 justify-center">
                <div class="h-px w-12 bg-[#edf2f7]"></div>
                <h2 class="text-sm font-bold text-[#718096] uppercase tracking-widest">
                  What's Inside
                </h2>
                <div class="h-px w-12 bg-[#edf2f7]"></div>
              </div>
              <div class="bg-white rounded-3xl shadow-sm border border-[#edf2f7] p-10 prose prose-primary max-w-none text-[#4a5568]">
                <%= raw(preview_content(@lead_magnet.content)) %>
              </div>
            </div>
          <% end %>
        <% end %>

        <!-- Footer -->
        <div class="mt-24 text-center">
          <p class="text-sm font-bold text-[#a0aec0] uppercase tracking-widest">
            Powered by <span class="text-[#718096]">{@project.name}</span>
          </p>
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
