defmodule DiscourseAppWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use DiscourseAppWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div class="relative min-h-screen overflow-hidden text-[color:var(--text-main)]">
      <div class="pointer-events-none absolute inset-0 overflow-hidden">
        <div
          class="absolute -left-16 top-0 h-72 w-72 rounded-full blur-3xl"
          style="background: var(--accent-soft);"
        >
        </div>
        <div
          class="absolute right-0 top-24 h-80 w-80 rounded-full blur-3xl"
          style="background: var(--accent-2-soft);"
        >
        </div>
        <div
          class="absolute bottom-[-6rem] left-1/3 h-64 w-64 rounded-full blur-3xl"
          style="background: var(--accent-soft);"
        >
        </div>
      </div>

      <header class="sticky top-0 z-40 px-4 py-4 sm:px-6 lg:px-8">
        <div class="surface-panel mx-auto flex max-w-[1600px] flex-col gap-4 rounded-[1.8rem] px-5 py-4 sm:px-6 lg:flex-row lg:items-center lg:justify-between">
          <div class="flex items-center gap-4">
            <div
              class="flex h-12 w-12 items-center justify-center rounded-[1.2rem] text-white shadow-lg"
              style="background: linear-gradient(135deg, var(--accent) 0%, var(--accent-strong) 100%);"
            >
              <.icon name="hero-share" class="size-6" />
            </div>
            <div class="space-y-1">
              <div class="dna-kicker">
                <span class="h-2.5 w-2.5 rounded-full" style="background: var(--accent);"></span>
                Discourse Network Platform
              </div>
              <div>
                <div class="text-xl font-semibold tracking-[-0.03em] text-[color:var(--text-main)]">
                  Project intelligence cockpit
                </div>
                <p class="text-sm text-[color:var(--text-muted)]">
                  Upload documents, converge actors and concepts, and inspect stance evidence in one place.
                </p>
              </div>
            </div>
          </div>

          <div class="flex flex-col gap-3 sm:flex-row sm:items-center">
            <div
              class="hidden rounded-full px-4 py-2 text-xs font-semibold uppercase tracking-[0.18em] lg:inline-flex"
              style="background: var(--surface-muted); color: var(--text-muted); border: 1px solid var(--line);"
            >
              Phoenix LiveView + SQLite
            </div>
            <.theme_toggle />
          </div>
        </div>
      </header>

      <main class="relative px-4 pb-10 sm:px-6 lg:px-8">
        <div class="mx-auto max-w-[1600px] space-y-4">
          {render_slot(@inner_block)}
        </div>
      </main>

      <.flash_group flash={@flash} />
    </div>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite" class="dna-flash-stack">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="theme-toggle" role="group" aria-label="Theme selection">
      <button
        type="button"
        class="theme-option"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
        data-theme-option="system"
      >
        <span class="theme-swatch theme-swatch-system"></span>
        <.icon name="hero-computer-desktop" class="size-4" />
        <span class="hidden sm:inline">System</span>
      </button>

      <button
        type="button"
        class="theme-option"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="paper"
        data-theme-option="paper"
      >
        <span class="theme-swatch theme-swatch-paper"></span>
        <.icon name="hero-sun" class="size-4" />
        <span class="hidden sm:inline">Paper</span>
      </button>

      <button
        type="button"
        class="theme-option"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="reef"
        data-theme-option="reef"
      >
        <span class="theme-swatch theme-swatch-reef"></span>
        <.icon name="hero-sparkles" class="size-4" />
        <span class="hidden sm:inline">Reef</span>
      </button>

      <button
        type="button"
        class="theme-option"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="midnight"
        data-theme-option="midnight"
      >
        <span class="theme-swatch theme-swatch-midnight"></span>
        <.icon name="hero-moon" class="size-4" />
        <span class="hidden sm:inline">Midnight</span>
      </button>
    </div>
    """
  end
end
