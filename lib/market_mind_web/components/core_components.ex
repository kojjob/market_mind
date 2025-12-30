defmodule MarketMindWeb.CoreComponents do
  @moduledoc """
  Provides core UI components.

  At first glance, this module may seem daunting, but its goal is to provide
  core building blocks for your application, such as tables, forms, and
  inputs. The components consist mostly of markup and are well-documented
  with doc strings and declarative assigns. You may customize and style
  them in any way you want, based on your application growth and needs.

  The foundation for styling is Tailwind CSS, a utility-first CSS framework,
  augmented with daisyUI, a Tailwind CSS plugin that provides UI components
  and themes. Here are useful references:

    * [daisyUI](https://daisyui.com/docs/intro/) - a good place to get
      started and see the available components.

    * [Tailwind CSS](https://tailwindcss.com) - the foundational framework
      we build on. You will use it for layout, sizing, flexbox, grid, and
      spacing.

    * [Heroicons](https://heroicons.com) - see `icon/1` for usage.

    * [Phoenix.Component](https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html) -
      the component system used by Phoenix. Some components, such as `<.link>`
      and `<.form>`, are defined there.

  """
  use Phoenix.Component
  use Gettext, backend: MarketMindWeb.Gettext

  alias Phoenix.LiveView.JS

  @doc """
  Renders flash notices.

  ## Examples

      <.flash kind={:info} flash={@flash} />
      <.flash kind={:info} phx-mounted={show("#flash")}>Welcome Back!</.flash>
  """
  attr :id, :string, doc: "the optional id of flash container"
  attr :flash, :map, default: %{}, doc: "the map of flash messages to display"
  attr :title, :string, default: nil
  attr :kind, :atom, values: [:info, :error], doc: "used for styling and flash lookup"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"

  slot :inner_block, doc: "the optional inner block that renders the flash message"

  def flash(assigns) do
    assigns = assign_new(assigns, :id, fn -> "flash-#{assigns.kind}" end)

    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
      role="alert"
      class="fixed top-6 right-6 z-50 w-80 sm:w-96 animate-in slide-in-from-right duration-300"
      {@rest}
    >
      <div class={[
        "flex items-start gap-4 p-5 rounded-3xl shadow-2xl border soft-card",
        @kind == :info && "bg-white dark:bg-[#122C36] border-[#F1F3F5] dark:border-white/5 text-[#4a5568] dark:text-[#A0AEC0]",
        @kind == :error && "bg-red-500 text-white border-red-600"
      ]}>
        <div class={[
          "size-10 rounded-2xl flex items-center justify-center shrink-0 shadow-sm",
          @kind == :info && "bg-primary/10 text-primary",
          @kind == :error && "bg-white/20 text-white"
        ]}>
          <.icon :if={@kind == :info} name="hero-information-circle" class="size-6" />
          <.icon :if={@kind == :error} name="hero-exclamation-circle" class="size-6" />
        </div>
        <div class="flex-1 pt-1">
          <p :if={@title} class="text-sm font-bold mb-0.5">{@title}</p>
          <p class="text-sm font-bold leading-relaxed">{msg}</p>
        </div>
        <button type="button" class="size-8 flex items-center justify-center rounded-xl hover:bg-black/5 transition-colors" aria-label={gettext("close")}>
          <.icon name="hero-x-mark" class="size-5 opacity-50" />
        </button>
      </div>
    </div>
    """
  end

  @doc """
  Renders a button with navigation support.

  ## Examples

      <.button>Send!</.button>
      <.button phx-click="go" variant="primary">Send!</.button>
      <.button navigate={~p"/"}>Home</.button>
  """
  attr :rest, :global, include: ~w(href navigate patch method download name value disabled)
  attr :class, :any
  attr :variant, :string, values: ~w(primary outline)
  slot :inner_block, required: true

  def button(%{rest: rest} = assigns) do
    variants = %{
      "primary" => "bg-primary text-white hover:bg-primary/90 shadow-lg shadow-primary/20",
      "outline" => "border-2 border-[#edf2f7] text-[#718096] hover:bg-gray-50",
      nil => "bg-primary/10 text-primary hover:bg-primary/20"
    }

    assigns =
      assign_new(assigns, :class, fn ->
        [
          "inline-flex items-center justify-center px-8 py-3.5 rounded-2xl font-extrabold text-sm transition-all duration-200 active:scale-95",
          Map.fetch!(variants, assigns[:variant])
        ]
      end)

    if rest[:href] || rest[:navigate] || rest[:patch] do
      ~H"""
      <.link class={@class} {@rest}>
        {render_slot(@inner_block)}
      </.link>
      """
    else
      ~H"""
      <button class={@class} {@rest}>
        {render_slot(@inner_block)}
      </button>
      """
    end
  end

  @doc """
  Renders an input with label and error messages.

  A `Phoenix.HTML.FormField` may be passed as argument,
  which is used to retrieve the input name, id, and values.
  Otherwise all attributes may be passed explicitly.

  ## Types

  This function accepts all HTML input types, considering that:

    * You may also set `type="select"` to render a `<select>` tag

    * `type="checkbox"` is used exclusively to render boolean values

    * For live file uploads, see `Phoenix.Component.live_file_input/1`

  See https://developer.mozilla.org/en-US/docs/Web/HTML/Element/input
  for more information. Unsupported types, such as radio, are best
  written directly in your templates.

  ## Examples

  ```heex
  <.input field={@form[:email]} type="email" />
  <.input name="my-input" errors={["oh no!"]} />
  ```

  ## Select type

  When using `type="select"`, you must pass the `options` and optionally
  a `value` to mark which option should be preselected.

  ```heex
  <.input field={@form[:user_type]} type="select" options={["Admin": "admin", "User": "user"]} />
  ```

  For more information on what kind of data can be passed to `options` see
  [`options_for_select`](https://hexdocs.pm/phoenix_html/Phoenix.HTML.Form.html#options_for_select/2).
  """
  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any

  attr :type, :string,
    default: "text",
    values: ~w(checkbox color date datetime-local email file month number password
               search select tel text textarea time url week hidden)

  attr :field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :errors, :list, default: []
  attr :checked, :boolean, doc: "the checked flag for checkbox inputs"
  attr :prompt, :string, default: nil, doc: "the prompt for select inputs"
  attr :options, :list, doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2"
  attr :multiple, :boolean, default: false, doc: "the multiple flag for select inputs"
  attr :class, :any, default: nil, doc: "the input class to use over defaults"
  attr :error_class, :any, default: nil, doc: "the input error class to use over defaults"

  attr :rest, :global,
    include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                multiple pattern placeholder readonly required rows size step)

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(errors, &translate_error(&1)))
    |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> input()
  end

  def input(%{type: "hidden"} = assigns) do
    ~H"""
    <input type="hidden" id={@id} name={@name} value={@value} {@rest} />
    """
  end

  def input(%{type: "checkbox"} = assigns) do
    assigns =
      assign_new(assigns, :checked, fn ->
        Phoenix.HTML.Form.normalize_value("checkbox", assigns[:value])
      end)

    ~H"""
    <div class="mb-6">
      <label class="flex items-center gap-3 cursor-pointer group">
        <input
          type="hidden"
          name={@name}
          value="false"
          disabled={@rest[:disabled]}
          form={@rest[:form]}
        />
        <input
          type="checkbox"
          id={@id}
          name={@name}
          value="true"
          checked={@checked}
          class={[
            "size-5 rounded-lg border-[#F1F3F5] dark:border-white/10 text-primary focus:ring-primary/20 transition-all cursor-pointer bg-white dark:bg-white/5",
            @class
          ]}
          {@rest}
        />
        <span class="text-sm font-bold text-[#4a5568] dark:text-[#A0AEC0] group-hover:text-[#0B222C] dark:group-hover:text-white transition-colors">
          {@label}
        </span>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "select"} = assigns) do
    ~H"""
    <div class="mb-6">
      <label>
        <span :if={@label} class="block text-sm font-bold text-[#1a202c] mb-2 ml-1">
          {@label}
        </span>
        <select
          id={@id}
          name={@name}
          class={[
            "block w-full rounded-2xl border-[#F1F3F5] dark:border-white/10 bg-[#F9FAFB] dark:bg-white/5 text-[#4a5568] dark:text-[#A0AEC0] text-sm font-bold focus:bg-white dark:focus:bg-white/10 focus:border-primary focus:ring-4 focus:ring-primary/10 transition-all h-[56px] px-5",
            @errors != [] && "border-red-500 focus:border-red-500 focus:ring-red-500/10",
            @class
          ]}
          multiple={@multiple}
          {@rest}
        >
          <option :if={@prompt} value="">{@prompt}</option>
          {Phoenix.HTML.Form.options_for_select(@options, @value)}
        </select>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "textarea"} = assigns) do
    ~H"""
    <div class="mb-6">
      <label>
        <span :if={@label} class="block text-sm font-bold text-[#1a202c] mb-2 ml-1">
          {@label}
        </span>
        <textarea
          id={@id}
          name={@name}
          class={[
            "block w-full rounded-2xl border-[#F1F3F5] dark:border-white/10 bg-[#F9FAFB] dark:bg-white/5 text-[#4a5568] dark:text-[#A0AEC0] text-sm font-bold focus:bg-white dark:focus:bg-white/10 focus:border-primary focus:ring-4 focus:ring-primary/10 transition-all min-h-[140px] p-5",
            @errors != [] && "border-red-500 focus:border-red-500 focus:ring-red-500/10",
            @class
          ]}
          {@rest}
        >{Phoenix.HTML.Form.normalize_value("textarea", @value)}</textarea>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  # All other inputs text, datetime-local, url, password, etc. are handled here...
  def input(assigns) do
    ~H"""
    <div class="mb-6">
      <label>
        <span :if={@label} class="block text-sm font-bold text-[#1a202c] mb-2 ml-1">
          {@label}
        </span>
        <input
          type={@type}
          name={@name}
          id={@id}
          value={Phoenix.HTML.Form.normalize_value(@type, @value)}
          class={[
            "block w-full rounded-2xl border-[#F1F3F5] dark:border-white/10 bg-[#F9FAFB] dark:bg-white/5 text-[#4a5568] dark:text-[#A0AEC0] text-sm font-bold focus:bg-white dark:focus:bg-white/10 focus:border-primary focus:ring-4 focus:ring-primary/10 transition-all h-[56px] px-5",
            @errors != [] && "border-red-500 focus:border-red-500 focus:ring-red-500/10",
            @class
          ]}
          {@rest}
        />
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  # Helper used by inputs to generate form errors
  defp error(assigns) do
    ~H"""
    <p class="mt-2 flex gap-2 items-center text-xs font-bold text-red-500 ml-1">
      <.icon name="hero-exclamation-circle" class="size-4" />
      {render_slot(@inner_block)}
    </p>
    """
  end

  @doc """
  Renders a header with title.
  """
  slot :inner_block, required: true
  slot :subtitle
  slot :actions

  def header(assigns) do
    ~H"""
    <header class={[@actions != [] && "flex items-center justify-between gap-6", "mb-10"]}>
      <div>
        <h1 class="text-3xl font-extrabold text-[#0B222C] dark:text-white tracking-tight">
          {render_slot(@inner_block)}
        </h1>
        <p :if={@subtitle != []} class="text-base font-bold text-[#718096] dark:text-[#A0AEC0] mt-2">
          {render_slot(@subtitle)}
        </p>
      </div>
      <div class="flex items-center gap-3">{render_slot(@actions)}</div>
    </header>
    """
  end

  @doc """
  Renders a table with generic styling.

  ## Examples

      <.table id="users" rows={@users}>
        <:col :let={user} label="id">{user.id}</:col>
        <:col :let={user} label="username">{user.username}</:col>
      </.table>
  """
  attr :id, :string, required: true
  attr :rows, :list, required: true
  attr :row_id, :any, default: nil, doc: "the function for generating the row id"
  attr :row_click, :any, default: nil, doc: "the function for handling phx-click on each row"

  attr :row_item, :any,
    default: &Function.identity/1,
    doc: "the function for mapping each row before calling the :col and :action slots"

  slot :col, required: true do
    attr :label, :string
  end

  slot :action, doc: "the slot for showing user actions in the last table column"

  def table(assigns) do
    assigns =
      with %{rows: %Phoenix.LiveView.LiveStream{}} <- assigns do
        assign(assigns, row_id: assigns.row_id || fn {id, _item} -> id end)
      end

    ~H"""
    <div class="overflow-hidden rounded-[2rem] border border-[#F1F3F5] dark:border-white/5 bg-white dark:bg-[#122C36] shadow-soft">
      <table class="w-full text-left border-collapse">
        <thead class="bg-[#F9FAFB] dark:bg-white/5 border-b border-[#F1F3F5] dark:border-white/5">
          <tr>
            <th :for={col <- @col} class="px-6 py-5 text-[0.75rem] font-extrabold text-[#A0AEC0] uppercase tracking-widest">
              {col[:label]}
            </th>
            <th :if={@action != []} class="px-6 py-5 text-[0.75rem] font-extrabold text-[#A0AEC0] uppercase tracking-widest text-right">
              {gettext("Actions")}
            </th>
          </tr>
        </thead>
          <tbody id={@id} phx-update={is_struct(@rows, Phoenix.LiveView.LiveStream) && "stream"} class="divide-y divide-[#F1F3F5] dark:divide-white/5">
          <tr :for={row <- @rows} id={@row_id && @row_id.(row)} class="hover:bg-[#F9FAFB] dark:hover:bg-white/5 transition-colors group">
            <td
              :for={col <- @col}
              phx-click={@row_click && @row_click.(row)}
              class={["px-6 py-6 text-sm font-bold text-[#4a5568] dark:text-[#A0AEC0]", @row_click && "cursor-pointer"]}
            >
              {render_slot(col, @row_item.(row))}
            </td>
            <td :if={@action != []} class="px-6 py-5 text-right">
              <div class="flex justify-end gap-3">
                <%= for action <- @action do %>
                  {render_slot(action, @row_item.(row))}
                <% end %>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  @doc """
  Renders a data list.

  ## Examples

      <.list>
        <:item title="Title">{@post.title}</:item>
        <:item title="Views">{@post.views}</:item>
      </.list>
  """
  slot :item, required: true do
    attr :title, :string, required: true
  end

  def list(assigns) do
    ~H"""
    <div class="rounded-3xl border border-[#F1F3F5] dark:border-white/5 bg-white dark:bg-[#122C36] overflow-hidden shadow-soft">
      <dl class="divide-y divide-[#F1F3F5] dark:divide-white/5">
        <div :for={item <- @item} class="flex flex-col sm:flex-row sm:items-center gap-2 px-6 py-6 hover:bg-[#F9FAFB] dark:hover:bg-white/5 transition-colors">
          <dt class="text-sm font-extrabold text-[#A0AEC0] sm:w-1/3 shrink-0 uppercase tracking-wider">{item.title}</dt>
          <dd class="text-sm font-bold text-[#0B222C] dark:text-white">{render_slot(item)}</dd>
        </div>
      </dl>
    </div>
    """
  end

  @doc """
  Renders a modal.

  ## Examples

      <.modal id="confirm-modal">
        This is a modal.
      </.modal>

  JS commands may be passed to the `:on_cancel` to configure
  the closing/canceling of the modal, for example:

      <.modal id="confirm" on_cancel={JS.navigate(~p"/posts")}>
        Is it confirmed?
      </.modal>
  """
  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :on_cancel, Phoenix.LiveView.JS, default: %JS{}
  slot :inner_block, required: true

  def modal(assigns) do
    ~H"""
    <div
      id={@id}
      phx-mounted={@show && show("##{@id}")}
      phx-remove={hide("##{@id}")}
      data-cancel={JS.exec(@on_cancel, "phx-remove")}
      class="relative z-50 hidden"
    >
      <div id={"#{@id}-bg"} class="bg-gray-900/40 fixed inset-0 transition-opacity backdrop-blur-sm" aria-hidden="true" />
      <div
        class="fixed inset-0 overflow-y-auto"
        aria-labelledby={"#{@id}-title"}
        aria-describedby={"#{@id}-description"}
        role="dialog"
        aria-modal="true"
        tabindex="-1"
      >
        <div class="flex min-h-full items-center justify-center p-4 sm:p-6 text-center">
          <div
            id={"#{@id}-container"}
            phx-click-away={JS.exec("data-cancel", to: "##{@id}")}
            phx-window-keydown={JS.exec("data-cancel", to: "##{@id}")}
            phx-key="escape"
            class="relative transform overflow-hidden rounded-[2.5rem] bg-white dark:bg-[#0B222C] p-8 sm:p-12 text-left align-middle shadow-2xl transition-all w-full max-w-2xl border border-[#F1F3F5] dark:border-white/10"
          >
            <div class="absolute top-6 right-6">
              <button
                phx-click={JS.exec("data-cancel", to: "##{@id}")}
                type="button"
                class="size-10 flex items-center justify-center rounded-2xl bg-gray-50 text-[#718096] hover:text-[#1a202c] hover:bg-gray-100 transition-all"
                aria-label={gettext("close")}
              >
                <.icon name="hero-x-mark" class="size-6" />
              </button>
            </div>
            <div id={"#{@id}-content"}>
              {render_slot(@inner_block)}
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders a [Heroicon](https://heroicons.com).

  Heroicons come in three styles – outline, solid, and mini.
  By default, the outline style is used, but solid and mini may
  be applied by using the `-solid` and `-mini` suffix.

  You can customize the size and colors of the icons by setting
  width, height, and background color classes.

  Icons are extracted from the `deps/heroicons` directory and bundled within
  your compiled app.css by the plugin in `assets/vendor/heroicons.js`.

  ## Examples

      <.icon name="hero-x-mark" />
      <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
  """
  attr :name, :string, required: true
  attr :class, :any, default: "size-4"

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end

  ## JS Commands

  def show(js \\ %JS{}, selector) do
    JS.show(js,
      to: selector,
      time: 300,
      transition:
        {"transition-all ease-out duration-300",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
         "opacity-100 translate-y-0 sm:scale-100"}
    )
  end

  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 200,
      transition:
        {"transition-all ease-in duration-200", "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
    )
  end

  @doc """
  Translates an error message using gettext.
  """
  def translate_error({msg, opts}) do
    # When using gettext, we typically pass the strings we want
    # to translate as a static argument:
    #
    #     # Translate the number of files with plural rules
    #     dngettext("errors", "1 file", "%{count} files", count)
    #
    # However the error messages in our forms and APIs are generated
    # dynamically, so we need to translate them by calling Gettext
    # with our gettext backend as first argument. Translations are
    # available in the errors.po file (as we use the "errors" domain).
    if count = opts[:count] do
      Gettext.dngettext(MarketMindWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(MarketMindWeb.Gettext, "errors", msg, opts)
    end
  end

  @doc """
  Translates the errors for a field from a keyword list of errors.
  """
  def translate_errors(errors, field) when is_list(errors) do
    for {^field, {msg, opts}} <- errors, do: translate_error({msg, opts})
  end
end
