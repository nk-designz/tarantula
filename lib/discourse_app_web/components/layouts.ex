defmodule DiscourseAppWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use DiscourseAppWeb, :html

  alias DiscourseApp.Projects

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

  attr :current_project, :map, default: nil, doc: "the project currently in view"

  attr :nav_section, :atom,
    default: :dashboard,
    values: [:dashboard, :projects, :project, :documents, :actors, :concepts, :graph, :analyzer],
    doc: "the active navbar section"

  slot :inner_block, required: true

  def app(assigns) do
    assigns = assign(assigns, :nav_projects, Projects.list_projects())

    ~H"""
    <div class="app-shell">
      <%!-- Ambient background blobs --%>
      <div class="pointer-events-none fixed inset-0 z-0 overflow-hidden">
        <div
          class="ambient-blob"
          style="top: -6rem; left: -6rem; width: 28rem; height: 28rem; background: var(--accent-soft);"
        >
        </div>
        <div
          class="ambient-blob"
          style="top: 12rem; right: -4rem; width: 24rem; height: 24rem; background: var(--accent-2-soft);"
        >
        </div>
        <div
          class="ambient-blob"
          style="bottom: -8rem; left: 40%; width: 22rem; height: 22rem; background: var(--accent-soft);"
        >
        </div>
      </div>

      <%!-- Sidebar: overlay on mobile, inline on desktop --%>
      <aside id="site-sidebar" class="sidebar">
        <%!-- Logo / brand --%>
        <div class="sidebar-header">
          <div class="flex items-center gap-3">
            <div class="sidebar-logo">
              <.icon name="hero-share" class="size-5" />
            </div>
            <div class="min-w-0">
              <div class="sidebar-brand-name">Discourse</div>
              <div class="sidebar-brand-sub">Intelligence cockpit</div>
            </div>
          </div>
          <button
            type="button"
            class="sidebar-close-btn lg:hidden"
            phx-click={hide_sidebar()}
            aria-label="Close navigation"
          >
            <.icon name="hero-x-mark" class="size-4" />
          </button>
        </div>

        <%!-- Primary nav --%>
        <nav class="sidebar-nav" aria-label="Main navigation">
          <div class="sidebar-nav-section">
            <span class="sidebar-nav-label">Navigation</span>
            <.link
              navigate={~p"/"}
              class={nav_item_class(@nav_section == :dashboard)}
              phx-click={hide_sidebar()}
            >
              <.icon name="hero-home" class="size-4" /> Dashboard
            </.link>
            <.link
              navigate={~p"/projects"}
              class={nav_item_class(@nav_section == :projects)}
              phx-click={hide_sidebar()}
            >
              <.icon name="hero-folder" class="size-4" /> Projects
            </.link>
          </div>

          <%= if @current_project do %>
            <div class="sidebar-nav-section">
              <span class="sidebar-nav-label">{@current_project.name}</span>
              <.link
                navigate={~p"/projects/#{@current_project.id}"}
                class={nav_item_class(@nav_section == :project)}
                phx-click={hide_sidebar()}
              >
                <.icon name="hero-information-circle" class="size-4" /> Overview
              </.link>
              <.link
                navigate={~p"/projects/#{@current_project.id}/documents"}
                class={nav_item_class(@nav_section == :documents)}
                phx-click={hide_sidebar()}
              >
                <.icon name="hero-document-text" class="size-4" /> Documents
              </.link>
              <.link
                navigate={~p"/projects/#{@current_project.id}/actors"}
                class={nav_item_class(@nav_section == :actors)}
                phx-click={hide_sidebar()}
              >
                <.icon name="hero-user-group" class="size-4" /> Actors
              </.link>
              <.link
                navigate={~p"/projects/#{@current_project.id}/concepts"}
                class={nav_item_class(@nav_section == :concepts)}
                phx-click={hide_sidebar()}
              >
                <.icon name="hero-light-bulb" class="size-4" /> Concepts
              </.link>
              <.link
                navigate={~p"/projects/#{@current_project.id}/graph"}
                class={nav_item_class(@nav_section == :graph)}
                phx-click={hide_sidebar()}
              >
                <.icon name="hero-share" class="size-4" /> DNA Graph
              </.link>
            </div>
          <% end %>
        </nav>

        <%!-- Project switcher --%>
        <%= if @nav_projects != [] do %>
          <div class="sidebar-switcher">
            <details class="group">
              <summary class="sidebar-switcher-trigger">
                <.icon name="hero-arrows-right-left" class="size-3.5 shrink-0" />
                <span class="min-w-0 truncate">
                  {if @current_project, do: @current_project.name, else: "Switch project"}
                </span>
                <.icon
                  name="hero-chevron-down"
                  class="size-3.5 shrink-0 ml-auto transition-transform group-open:rotate-180"
                />
              </summary>
              <div class="sidebar-switcher-menu">
                <%= for project <- @nav_projects do %>
                  <.link
                    navigate={project_nav_path(project.id, @nav_section)}
                    phx-click={hide_sidebar()}
                    class={[
                      "sidebar-switcher-item",
                      @current_project && @current_project.id == project.id &&
                        "sidebar-switcher-item-active"
                    ]}
                  >
                    {project.name}
                  </.link>
                <% end %>
              </div>
            </details>
          </div>
        <% end %>

        <%!-- Bottom: theme + version --%>
        <div class="sidebar-footer">
          <.theme_toggle />
          <p class="sidebar-version">Phoenix LiveView · SQLite</p>
        </div>
      </aside>

      <%!-- Mobile overlay backdrop --%>
      <button
        id="sidebar-overlay"
        type="button"
        class="fixed inset-0 z-40 hidden bg-black/30 backdrop-blur-sm lg:hidden"
        phx-click={hide_sidebar()}
        aria-label="Close menu"
      >
      </button>

      <%!-- Mobile hamburger --%>
      <button
        id="sidebar-open-button"
        type="button"
        class="hamburger-btn lg:hidden"
        phx-click={show_sidebar()}
        aria-label="Open navigation"
      >
        <.icon name="hero-bars-3" class="size-5" />
      </button>

      <%!-- Page content --%>
      <div class="app-content">
        <main class="app-main">
          {render_slot(@inner_block)}
        </main>
      </div>

      <.flash_group flash={@flash} />
    </div>
    """
  end

  defp nav_item_class(true),
    do: "nav-item nav-item-active"

  defp nav_item_class(false),
    do: "nav-item"

  defp show_sidebar(js \\ %JS{}) do
    js
    |> JS.remove_class("-translate-x-full", to: "#site-sidebar")
    |> JS.add_class("translate-x-0", to: "#site-sidebar")
    |> JS.show(to: "#sidebar-overlay", display: "block")
  end

  defp hide_sidebar(js \\ %JS{}) do
    js
    |> JS.remove_class("translate-x-0", to: "#site-sidebar")
    |> JS.add_class("-translate-x-full", to: "#site-sidebar")
    |> JS.hide(to: "#sidebar-overlay")
  end

  defp project_nav_path(project_id, :documents), do: ~p"/projects/#{project_id}/documents"
  defp project_nav_path(project_id, :actors), do: ~p"/projects/#{project_id}/actors"
  defp project_nav_path(project_id, :concepts), do: ~p"/projects/#{project_id}/concepts"
  defp project_nav_path(project_id, :graph), do: ~p"/projects/#{project_id}/graph"
  defp project_nav_path(project_id, :project), do: ~p"/projects/#{project_id}"
  defp project_nav_path(project_id, :analyzer), do: ~p"/projects/#{project_id}/documents"
  defp project_nav_path(_project_id, :dashboard), do: ~p"/"
  defp project_nav_path(_project_id, :projects), do: ~p"/projects"
  defp project_nav_path(project_id, _section), do: ~p"/projects/#{project_id}"

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
