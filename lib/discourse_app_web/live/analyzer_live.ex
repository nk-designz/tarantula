defmodule DiscourseAppWeb.AnalyzerLive do
  use DiscourseAppWeb, :live_view
  alias DiscourseApp.Analyzer

  def mount(_params, _session, socket) do
    {:ok, assign(socket, form_text: "", loading: false, error: nil)}
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-slate-50 text-slate-900 font-sans antialiased">
      <nav class="sticky top-0 z-50 bg-white/80 backdrop-blur-md border-b border-slate-200 px-4 py-3 sm:px-6">
        <div class="max-w-7xl mx-auto flex items-center justify-between">
          <div class="flex items-center gap-3">
            <div class="h-9 w-9 bg-indigo-600 rounded-xl flex items-center justify-center shadow-md shadow-indigo-200">
              <svg class="h-5 w-5 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M11 3.055A9.001 9.001 0 1020.945 13H11V3.055z"
                />
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M20.488 9H15V3.512A9.025 9.025 0 0120.488 9z"
                />
              </svg>
            </div>
            <div>
              <span class="font-bold text-slate-900 tracking-tight block sm:inline">Discourse</span>
              <span class="text-indigo-600 font-semibold sm:inline">Network</span>
            </div>
          </div>
          <div class="flex items-center gap-2 text-xs font-medium text-slate-500 bg-slate-100 px-3 py-1.5 rounded-full">
            <span class="w-2 h-2 rounded-full bg-emerald-500 animate-pulse"></span>
            Ollama Lokal (Qwen2.5)
          </div>
        </div>
      </nav>

      <main class="max-w-7xl mx-auto p-4 sm:p-6 lg:p-8 space-y-6">
        <div
          class="sm:hidden grid grid-cols-2 bg-slate-200 p-1 rounded-xl"
          id="mobile-tabs"
          phx-update="ignore"
        >
          <button
            onclick="document.getElementById('input-panel').classList.remove('hidden'); document.getElementById('graph-panel').classList.add('hidden-mobile'); this.classList.add('bg-white', 'shadow-sm'); this.nextElementSibling.classList.remove('bg-white', 'shadow-sm')"
            class="py-2.5 text-sm font-medium text-center rounded-lg bg-white shadow-sm transition"
          >
            1. Text Input
          </button>
          <button
            onclick="document.getElementById('graph-panel').classList.remove('hidden-mobile'); document.getElementById('input-panel').classList.add('hidden'); this.classList.add('bg-white', 'shadow-sm'); this.previousElementSibling.classList.remove('bg-white', 'shadow-sm')"
            class="py-2.5 text-sm font-medium text-center rounded-lg transition"
          >
            2. Netzwerk Graph
          </button>
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-12 gap-6 items-start">
          <section
            id="input-panel"
            class="lg:col-span-5 bg-white border border-slate-200 rounded-2xl shadow-sm p-5 space-y-4 flex flex-col h-[calc(100vh-12rem)] lg:h-[700px]"
          >
            <div class="flex items-center justify-between border-b border-slate-100 pb-3">
              <div>
                <h2 class="font-bold text-slate-800 text-lg">Dokumenten-Analyse</h2>
                <p class="text-xs text-slate-400">Füge dein Markdown-Protokoll hier ein.</p>
              </div>
            </div>

            <form phx-submit="analyze" class="flex flex-col flex-grow gap-4 h-full">
              <div class="relative flex-grow h-full">
                <textarea
                  name="markdown"
                  class="absolute inset-0 w-full h-full p-4 bg-slate-50/50 border border-slate-200 rounded-xl focus:ring-2 focus:ring-indigo-500/20 focus:border-indigo-500 transition resize-none font-mono text-xs sm:text-sm leading-relaxed"
                  placeholder="# Überschrift&#10;Akteur X sagt: 'Ich bin für das Konzept Y...'"
                ><%= @form_text %></textarea>
              </div>

              <button
                type="submit"
                disabled={@loading}
                class="w-full py-3.5 px-4 bg-indigo-600 hover:bg-indigo-700 disabled:bg-indigo-400 text-white font-semibold rounded-xl shadow-md shadow-indigo-100 transition duration-200 flex justify-center items-center gap-2 text-sm"
              >
                <%= if @loading do %>
                  <svg
                    class="animate-spin h-5 w-5 text-white"
                    xmlns="http://www.w3.org/2000/svg"
                    fill="none"
                    viewBox="0 0 24 24"
                  >
                    <circle
                      class="opacity-25"
                      cx="12"
                      cy="12"
                      r="10"
                      stroke="currentColor"
                      stroke-width="4"
                    >
                    </circle>
                    <path
                      class="opacity-75"
                      fill="currentColor"
                      d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
                    >
                    </path>
                  </svg>
                  Extrahiere Argumente...
                <% else %>
                  Analyse starten
                <% end %>
              </button>
            </form>

            <%= if @error do %>
              <div class="p-3 bg-rose-50 text-rose-700 border border-rose-100 rounded-xl text-xs flex items-start gap-2">
                <svg
                  class="h-4 w-4 shrink-0 mt-0.5"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"
                  />
                </svg>
                <span>{@error}</span>
              </div>
            <% end %>
          </section>

          <section id="graph-panel" class="hidden-mobile lg:block lg:col-span-7 space-y-4">
            <div class="bg-white border border-slate-200 rounded-2xl shadow-sm overflow-hidden h-[calc(100vh-16rem)] lg:h-[620px] relative flex flex-col">
              <div class="p-4 bg-slate-50 border-b border-slate-100 flex flex-wrap items-center justify-between gap-3 z-10">
                <div>
                  <h2 class="font-bold text-slate-800 text-sm sm:text-base">
                    Interaktives Diskursnetzwerk
                  </h2>
                  <p class="text-xs text-slate-400">Ziehe Knoten, um das Netz zu explorieren.</p>
                </div>

                <div class="flex flex-wrap gap-3 text-xs font-medium text-slate-600 bg-white px-3 py-1.5 rounded-lg border border-slate-200">
                  <span class="flex items-center gap-1.5">
                    <span class="w-2.5 h-2.5 rounded-full bg-blue-500 block"></span>Akteur
                  </span>
                  <span class="flex items-center gap-1.5">
                    <span class="w-2.5 h-2.5 rounded-full bg-amber-500 block"></span>Konzept
                  </span>
                  <span class="flex items-center gap-1.5">
                    <span class="w-4 h-1 bg-emerald-500 rounded block"></span>Pro
                  </span>
                  <span class="flex items-center gap-1.5">
                    <span class="w-4 h-1 bg-rose-500 rounded block"></span>Contra
                  </span>
                </div>
              </div>

              <%= if not @loading and @form_text == "" do %>
                <div class="absolute inset-0 flex flex-col items-center justify-center text-slate-400 p-6 text-center bg-white">
                  <svg
                    class="h-12 w-12 text-slate-300 mb-2"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke="currentColor"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="1.5"
                      d="M7 12l3-3 3 3 4-4M8 21h8a2 2 0 002-2V5a2 2 0 00-2-2H8a2 2 0 00-2 2v14a2 2 0 002 2z"
                    />
                  </svg>
                  <p class="text-sm font-medium">Noch keine Daten vorhanden</p>
                  <p class="text-xs text-slate-400 max-w-xs mt-1">
                    Füge links ein Dokument ein und klicke auf "Analyse starten", um das Netzwerk zu visualisieren.
                  </p>
                </div>
              <% end %>

              <div
                id="network-container"
                phx-hook="DiscourseNetwork"
                phx-update="ignore"
                class="w-full flex-grow bg-white cursor-grab active:cursor-grabbing"
              >
              </div>
            </div>

            <p class="text-center text-slate-400 text-xs hidden lg:block">
              Tipp: Nutze ein Trackpad oder die Maus zum Ziehen der Elemente.
            </p>
          </section>
        </div>
      </main>
    </div>

    <style>
      @media (max-width: 639px) {
        .hidden-mobile { display: none !important; }
      }
    </style>
    """
  end

  def handle_event("analyze", %{"markdown" => markdown}, socket) do
    # Wir holen uns die PID der aktuellen LiveView
    live_view_pid = self()

    # Wir starten die schwere Arbeit in einem separaten Hintergrund-Task!
    Task.start(fn ->
      case DiscourseApp.Analyzer.analyze_markdown(markdown) do
        {:ok, d3_data} ->
          # Wenn fertig, schicke eine Nachricht an die LiveView zurück
          send(live_view_pid, {:analysis_success, d3_data})

        {:error, msg} ->
          send(live_view_pid, {:analysis_failure, msg})
      end
    end)

    # Die LiveView schaltet SOFORT auf Ladezustand und bleibt absolut responsiv!
    {:noreply, assign(socket, loading: true, error: nil, form_text: markdown)}
  end

  # 2. Wenn der Hintergrund-Task nach 4 Minuten ERFOLGREICH fertig ist
  def handle_info({:analysis_success, d3_data}, socket) do
    # Jetzt schieben wir die Daten an D3.js. Der Kanal ist garantiert noch offen!
    {:noreply,
     socket
     |> assign(loading: false)
     |> push_event("render_network", d3_data)}
  end

  # 3. Wenn der Hintergrund-Task FEHLSCHLÄGT
  def handle_info({:analysis_failure, msg}, socket) do
    {:noreply, assign(socket, loading: false, error: msg)}
  end
end
