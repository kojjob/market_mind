# UI Components Specification

> Design system and component library specifications for MarketMind.

## Design Tokens

### Colors

```css
/* Primary - Indigo */
--color-primary-50: #eef2ff;
--color-primary-100: #e0e7ff;
--color-primary-200: #c7d2fe;
--color-primary-300: #a5b4fc;
--color-primary-400: #818cf8;
--color-primary-500: #6366f1;  /* Main */
--color-primary-600: #4f46e5;  /* Hover */
--color-primary-700: #4338ca;
--color-primary-800: #3730a3;
--color-primary-900: #312e81;

/* Success - Green */
--color-success-500: #22c55e;
--color-success-600: #16a34a;

/* Warning - Amber */
--color-warning-500: #f59e0b;
--color-warning-600: #d97706;

/* Error - Red */
--color-error-500: #ef4444;
--color-error-600: #dc2626;

/* Neutral - Gray */
--color-gray-50: #f9fafb;
--color-gray-100: #f3f4f6;
--color-gray-200: #e5e7eb;
--color-gray-300: #d1d5db;
--color-gray-400: #9ca3af;
--color-gray-500: #6b7280;
--color-gray-600: #4b5563;
--color-gray-700: #374151;
--color-gray-800: #1f2937;
--color-gray-900: #111827;
```

### Typography

```css
/* Font Family */
--font-sans: 'Inter', system-ui, sans-serif;
--font-mono: 'JetBrains Mono', monospace;

/* Font Sizes */
--text-xs: 0.75rem;    /* 12px */
--text-sm: 0.875rem;   /* 14px */
--text-base: 1rem;     /* 16px */
--text-lg: 1.125rem;   /* 18px */
--text-xl: 1.25rem;    /* 20px */
--text-2xl: 1.5rem;    /* 24px */
--text-3xl: 1.875rem;  /* 30px */
--text-4xl: 2.25rem;   /* 36px */
```

### Spacing

```css
/* Spacing Scale (Tailwind default) */
--space-1: 0.25rem;   /* 4px */
--space-2: 0.5rem;    /* 8px */
--space-3: 0.75rem;   /* 12px */
--space-4: 1rem;      /* 16px */
--space-5: 1.25rem;   /* 20px */
--space-6: 1.5rem;    /* 24px */
--space-8: 2rem;      /* 32px */
--space-10: 2.5rem;   /* 40px */
--space-12: 3rem;     /* 48px */
```

---

## Core Components

### 1. Button

```elixir
# lib/market_mind_web/components/core_components.ex

attr :type, :string, default: nil
attr :variant, :string, default: "primary", values: ~w(primary secondary ghost danger)
attr :size, :string, default: "md", values: ~w(sm md lg)
attr :disabled, :boolean, default: false
attr :loading, :boolean, default: false
attr :class, :string, default: ""
attr :rest, :global

slot :inner_block, required: true

def button(assigns) do
  ~H"""
  <button
    type={@type}
    disabled={@disabled || @loading}
    class={[
      "inline-flex items-center justify-center font-medium rounded-lg transition-colors",
      "focus:outline-none focus:ring-2 focus:ring-offset-2",
      "disabled:opacity-50 disabled:cursor-not-allowed",
      button_size_class(@size),
      button_variant_class(@variant),
      @class
    ]}
    {@rest}
  >
    <.loading_spinner :if={@loading} class="mr-2" />
    <%= render_slot(@inner_block) %>
  </button>
  """
end

defp button_size_class("sm"), do: "px-3 py-1.5 text-sm"
defp button_size_class("md"), do: "px-4 py-2 text-sm"
defp button_size_class("lg"), do: "px-6 py-3 text-base"

defp button_variant_class("primary") do
  "bg-indigo-600 text-white hover:bg-indigo-700 focus:ring-indigo-500"
end
defp button_variant_class("secondary") do
  "bg-white text-gray-700 border border-gray-300 hover:bg-gray-50 focus:ring-indigo-500"
end
defp button_variant_class("ghost") do
  "text-gray-600 hover:text-gray-900 hover:bg-gray-100 focus:ring-gray-500"
end
defp button_variant_class("danger") do
  "bg-red-600 text-white hover:bg-red-700 focus:ring-red-500"
end
```

**Usage:**
```heex
<.button>Save Project</.button>
<.button variant="secondary" size="sm">Cancel</.button>
<.button variant="danger" loading={@saving}>Delete</.button>
```

---

### 2. Card

```elixir
attr :class, :string, default: ""
attr :padding, :string, default: "md", values: ~w(none sm md lg)

slot :header
slot :inner_block, required: true
slot :footer

def card(assigns) do
  ~H"""
  <div class={["bg-white rounded-lg shadow", @class]}>
    <div :if={@header != []} class="px-6 py-4 border-b border-gray-200">
      <%= render_slot(@header) %>
    </div>
    <div class={card_padding_class(@padding)}>
      <%= render_slot(@inner_block) %>
    </div>
    <div :if={@footer != []} class="px-6 py-4 border-t border-gray-200 bg-gray-50 rounded-b-lg">
      <%= render_slot(@footer) %>
    </div>
  </div>
  """
end

defp card_padding_class("none"), do: ""
defp card_padding_class("sm"), do: "p-4"
defp card_padding_class("md"), do: "p-6"
defp card_padding_class("lg"), do: "p-8"
```

**Usage:**
```heex
<.card>
  <:header>
    <h3 class="text-lg font-semibold">Project Settings</h3>
  </:header>
  
  <p>Card content goes here...</p>
  
  <:footer>
    <.button>Save Changes</.button>
  </:footer>
</.card>
```

---

### 3. Input

```elixir
attr :id, :any, default: nil
attr :name, :any
attr :label, :string, default: nil
attr :type, :string, default: "text"
attr :value, :any
attr :field, Phoenix.HTML.FormField
attr :errors, :list, default: []
attr :help_text, :string, default: nil
attr :class, :string, default: ""
attr :rest, :global

def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
  assigns
  |> assign(field: nil, id: assigns.id || field.id)
  |> assign(:errors, Enum.map(field.errors, &translate_error/1))
  |> assign_new(:name, fn -> field.name end)
  |> assign_new(:value, fn -> field.value end)
  |> input()
end

def input(assigns) do
  ~H"""
  <div class={@class}>
    <label :if={@label} for={@id} class="block text-sm font-medium text-gray-700 mb-1">
      <%= @label %>
    </label>
    <input
      type={@type}
      name={@name}
      id={@id}
      value={Phoenix.HTML.Form.normalize_value(@type, @value)}
      class={[
        "block w-full rounded-lg border-gray-300 shadow-sm",
        "focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm",
        @errors != [] && "border-red-300 text-red-900 focus:ring-red-500 focus:border-red-500"
      ]}
      {@rest}
    />
    <p :if={@help_text && @errors == []} class="mt-1 text-sm text-gray-500">
      <%= @help_text %>
    </p>
    <.error :for={msg <- @errors}><%= msg %></.error>
  </div>
  """
end

def error(assigns) do
  ~H"""
  <p class="mt-1 text-sm text-red-600">
    <%= render_slot(@inner_block) %>
  </p>
  """
end
```

**Usage:**
```heex
<.input field={@form[:name]} label="Project Name" placeholder="My SaaS App" />
<.input field={@form[:url]} label="Website URL" type="url" help_text="We'll analyze this to understand your product" />
```

---

### 4. Badge

```elixir
attr :variant, :string, default: "default", values: ~w(default success warning error info)
attr :size, :string, default: "md", values: ~w(sm md)
attr :class, :string, default: ""

slot :inner_block, required: true

def badge(assigns) do
  ~H"""
  <span class={[
    "inline-flex items-center font-medium rounded-full",
    badge_size_class(@size),
    badge_variant_class(@variant),
    @class
  ]}>
    <%= render_slot(@inner_block) %>
  </span>
  """
end

defp badge_size_class("sm"), do: "px-2 py-0.5 text-xs"
defp badge_size_class("md"), do: "px-2.5 py-1 text-xs"

defp badge_variant_class("default"), do: "bg-gray-100 text-gray-800"
defp badge_variant_class("success"), do: "bg-green-100 text-green-800"
defp badge_variant_class("warning"), do: "bg-yellow-100 text-yellow-800"
defp badge_variant_class("error"), do: "bg-red-100 text-red-800"
defp badge_variant_class("info"), do: "bg-blue-100 text-blue-800"
```

**Usage:**
```heex
<.badge>Draft</.badge>
<.badge variant="success">Approved</.badge>
<.badge variant="warning">Pending Review</.badge>
```

---

### 5. Status Indicator

```elixir
attr :status, :atom, required: true
attr :label, :string, default: nil
attr :pulse, :boolean, default: false

def status_indicator(assigns) do
  ~H"""
  <div class="flex items-center gap-2">
    <span class={[
      "inline-block w-2 h-2 rounded-full",
      status_color(@status),
      @pulse && "animate-pulse"
    ]} />
    <span :if={@label} class="text-sm text-gray-600"><%= @label %></span>
  </div>
  """
end

defp status_color(:pending), do: "bg-gray-400"
defp status_color(:running), do: "bg-blue-500"
defp status_color(:completed), do: "bg-green-500"
defp status_color(:failed), do: "bg-red-500"
defp status_color(:available), do: "bg-green-500"
defp status_color(:working), do: "bg-yellow-500"
defp status_color(_), do: "bg-gray-400"
```

---

### 6. Modal

```elixir
attr :id, :string, required: true
attr :show, :boolean, default: false
attr :on_cancel, JS, default: %JS{}
attr :size, :string, default: "md", values: ~w(sm md lg xl)

slot :title
slot :inner_block, required: true
slot :footer

def modal(assigns) do
  ~H"""
  <div
    id={@id}
    phx-mounted={@show && show_modal(@id)}
    phx-remove={hide_modal(@id)}
    data-cancel={JS.exec(@on_cancel, "phx-remove")}
    class="relative z-50 hidden"
  >
    <!-- Backdrop -->
    <div
      id={"#{@id}-bg"}
      class="fixed inset-0 bg-gray-900/50 transition-opacity"
      aria-hidden="true"
    />
    
    <!-- Modal -->
    <div
      class="fixed inset-0 overflow-y-auto"
      aria-labelledby={"#{@id}-title"}
      role="dialog"
      aria-modal="true"
      tabindex="0"
    >
      <div class="flex min-h-full items-center justify-center p-4">
        <.focus_wrap
          id={"#{@id}-container"}
          phx-window-keydown={JS.exec("data-cancel", to: "##{@id}")}
          phx-key="escape"
          phx-click-away={JS.exec("data-cancel", to: "##{@id}")}
          class={[
            "relative bg-white rounded-xl shadow-xl",
            modal_size_class(@size)
          ]}
        >
          <!-- Close button -->
          <button
            type="button"
            class="absolute top-4 right-4 text-gray-400 hover:text-gray-500"
            phx-click={JS.exec("data-cancel", to: "##{@id}")}
          >
            <.icon name="hero-x-mark" class="w-5 h-5" />
          </button>
          
          <!-- Title -->
          <div :if={@title != []} class="px-6 py-4 border-b border-gray-200">
            <h3 id={"#{@id}-title"} class="text-lg font-semibold text-gray-900">
              <%= render_slot(@title) %>
            </h3>
          </div>
          
          <!-- Content -->
          <div class="px-6 py-4">
            <%= render_slot(@inner_block) %>
          </div>
          
          <!-- Footer -->
          <div :if={@footer != []} class="px-6 py-4 border-t border-gray-200 flex justify-end gap-3">
            <%= render_slot(@footer) %>
          </div>
        </.focus_wrap>
      </div>
    </div>
  </div>
  """
end

defp modal_size_class("sm"), do: "w-full max-w-sm"
defp modal_size_class("md"), do: "w-full max-w-md"
defp modal_size_class("lg"), do: "w-full max-w-lg"
defp modal_size_class("xl"), do: "w-full max-w-xl"
```

---

### 7. Empty State

```elixir
attr :title, :string, required: true
attr :description, :string, default: nil
attr :icon, :string, default: "hero-folder-open"

slot :action

def empty_state(assigns) do
  ~H"""
  <div class="text-center py-12">
    <.icon name={@icon} class="mx-auto h-12 w-12 text-gray-400" />
    <h3 class="mt-4 text-lg font-medium text-gray-900"><%= @title %></h3>
    <p :if={@description} class="mt-2 text-sm text-gray-500 max-w-sm mx-auto">
      <%= @description %>
    </p>
    <div :if={@action != []} class="mt-6">
      <%= render_slot(@action) %>
    </div>
  </div>
  """
end
```

**Usage:**
```heex
<.empty_state
  title="No projects yet"
  description="Get started by creating your first project."
  icon="hero-folder-plus"
>
  <:action>
    <.button phx-click="new_project">Create Project</.button>
  </:action>
</.empty_state>
```

---

### 8. Stats Card

```elixir
attr :title, :string, required: true
attr :value, :string, required: true
attr :change, :float, default: nil
attr :change_type, :atom, default: :neutral, values: [:increase, :decrease, :neutral]
attr :icon, :string, default: nil

def stats_card(assigns) do
  ~H"""
  <div class="bg-white rounded-lg shadow p-6">
    <div class="flex items-center justify-between">
      <p class="text-sm font-medium text-gray-600"><%= @title %></p>
      <.icon :if={@icon} name={@icon} class="w-5 h-5 text-gray-400" />
    </div>
    <div class="mt-2 flex items-baseline gap-2">
      <p class="text-3xl font-semibold text-gray-900"><%= @value %></p>
      <span
        :if={@change}
        class={[
          "text-sm font-medium",
          change_color(@change_type)
        ]}
      >
        <%= if @change >= 0, do: "+", else: "" %><%= @change %>%
      </span>
    </div>
  </div>
  """
end

defp change_color(:increase), do: "text-green-600"
defp change_color(:decrease), do: "text-red-600"
defp change_color(:neutral), do: "text-gray-500"
```

---

### 9. Progress Bar

```elixir
attr :value, :integer, required: true
attr :max, :integer, default: 100
attr :size, :string, default: "md", values: ~w(sm md lg)
attr :color, :string, default: "primary"
attr :show_label, :boolean, default: false

def progress_bar(assigns) do
  percentage = min(100, round(assigns.value / assigns.max * 100))
  assigns = assign(assigns, :percentage, percentage)
  
  ~H"""
  <div>
    <div class="flex justify-between mb-1" :if={@show_label}>
      <span class="text-sm text-gray-600">Progress</span>
      <span class="text-sm font-medium text-gray-900"><%= @percentage %>%</span>
    </div>
    <div class={["bg-gray-200 rounded-full overflow-hidden", progress_height(@size)]}>
      <div
        class={["rounded-full transition-all duration-300", progress_color(@color)]}
        style={"width: #{@percentage}%"}
      />
    </div>
  </div>
  """
end

defp progress_height("sm"), do: "h-1"
defp progress_height("md"), do: "h-2"
defp progress_height("lg"), do: "h-3"

defp progress_color("primary"), do: "bg-indigo-600 h-full"
defp progress_color("success"), do: "bg-green-600 h-full"
defp progress_color("warning"), do: "bg-yellow-500 h-full"
```

---

### 10. Loading Spinner

```elixir
attr :size, :string, default: "md", values: ~w(sm md lg)
attr :class, :string, default: ""

def loading_spinner(assigns) do
  ~H"""
  <svg
    class={["animate-spin text-current", spinner_size(@size), @class]}
    xmlns="http://www.w3.org/2000/svg"
    fill="none"
    viewBox="0 0 24 24"
  >
    <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" />
    <path
      class="opacity-75"
      fill="currentColor"
      d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
    />
  </svg>
  """
end

defp spinner_size("sm"), do: "w-4 h-4"
defp spinner_size("md"), do: "w-5 h-5"
defp spinner_size("lg"), do: "w-8 h-8"
```

---

## Page Layout Components

### App Shell

```elixir
# lib/market_mind_web/components/layouts/app_layout.ex

slot :sidebar
slot :header
slot :inner_block, required: true

def app_layout(assigns) do
  ~H"""
  <div class="min-h-screen bg-gray-100">
    <!-- Sidebar -->
    <aside class="fixed inset-y-0 left-0 w-64 bg-white border-r border-gray-200">
      <%= render_slot(@sidebar) %>
    </aside>
    
    <!-- Main content -->
    <div class="pl-64">
      <!-- Header -->
      <header class="h-16 bg-white border-b border-gray-200 flex items-center px-6">
        <%= render_slot(@header) %>
      </header>
      
      <!-- Page content -->
      <main class="p-6">
        <%= render_slot(@inner_block) %>
      </main>
    </div>
  </div>
  """
end
```

### Sidebar Navigation

```elixir
attr :current_path, :string, required: true

def sidebar_nav(assigns) do
  ~H"""
  <nav class="flex-1 px-4 py-6 space-y-1">
    <.nav_item href={~p"/dashboard"} icon="hero-home" current={@current_path}>
      Dashboard
    </.nav_item>
    <.nav_item href={~p"/projects"} icon="hero-folder" current={@current_path}>
      Projects
    </.nav_item>
    <.nav_item href={~p"/personas"} icon="hero-users" current={@current_path}>
      Personas
    </.nav_item>
    <.nav_item href={~p"/content"} icon="hero-document-text" current={@current_path}>
      Content
    </.nav_item>
    <.nav_item href={~p"/agents"} icon="hero-cpu-chip" current={@current_path}>
      Agents
    </.nav_item>
    <.nav_item href={~p"/settings"} icon="hero-cog-6-tooth" current={@current_path}>
      Settings
    </.nav_item>
  </nav>
  """
end

attr :href, :string, required: true
attr :icon, :string, required: true
attr :current, :string, required: true
slot :inner_block, required: true

def nav_item(assigns) do
  active = String.starts_with?(assigns.current, assigns.href)
  assigns = assign(assigns, :active, active)
  
  ~H"""
  <.link
    href={@href}
    class={[
      "flex items-center gap-3 px-3 py-2 rounded-lg text-sm font-medium transition-colors",
      @active && "bg-indigo-50 text-indigo-700",
      !@active && "text-gray-700 hover:bg-gray-100"
    ]}
  >
    <.icon name={@icon} class="w-5 h-5" />
    <%= render_slot(@inner_block) %>
  </.link>
  """
end
```

---

## Usage Guidelines

### Do's
- Use semantic color names (primary, success, error) not raw colors
- Keep components small and focused
- Use slots for flexible composition
- Always provide loading and empty states
- Use consistent spacing (4px increments)

### Don'ts
- Don't add custom CSS unless absolutely necessary
- Don't nest cards within cards
- Don't use more than 3 button variants on one screen
- Don't mix icon libraries (use Heroicons only)
- Don't override Tailwind utilities with custom classes
