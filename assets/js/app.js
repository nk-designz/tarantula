// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/discourse_app"
import topbar from "../vendor/topbar"

let Hooks = {}

Hooks.DiscourseNetwork = {
  mounted() {
    this.graphData = {nodes: [], links: []}
    this.redraw = () => this.drawGraph(this.cloneNodes(), this.cloneLinks())
    this.handleThemeChange = () => this.redraw()

    this.handleEvent("render_network", (data) => {
      this.graphData = {
        nodes: data.nodes || [],
        links: data.links || [],
      }

      this.redraw()
    })

    this.resizeObserver = new ResizeObserver(() => this.redraw())
    this.resizeObserver.observe(this.el)
    window.addEventListener("app:theme-changed", this.handleThemeChange)
  },

  destroyed() {
    this.resizeObserver?.disconnect()
    window.removeEventListener("app:theme-changed", this.handleThemeChange)
  },

  cloneNodes() {
    return (this.graphData.nodes || []).map((node) => ({...node}))
  },

  cloneLinks() {
    return (this.graphData.links || []).map((link) => ({...link}))
  },

  palette() {
    const styles = getComputedStyle(document.documentElement)

    return {
      actor: styles.getPropertyValue("--graph-actor").trim() || "#0f766e",
      concept: styles.getPropertyValue("--graph-concept").trim() || "#d0672d",
      pro: styles.getPropertyValue("--graph-pro").trim() || "#0f766e",
      contra: styles.getPropertyValue("--graph-contra").trim() || "#b74434",
      neutral: styles.getPropertyValue("--graph-neutral").trim() || "#607086",
      label: styles.getPropertyValue("--graph-label").trim() || "#24313f",
      empty: styles.getPropertyValue("--text-soft").trim() || "#94a3b8",
      stroke: styles.getPropertyValue("--surface-strong").trim() || "#ffffff",
    }
  },

  drawGraph(nodes, links) {
    this.el.innerHTML = ""
    const palette = this.palette()

    const width = this.el.clientWidth || 800
    const height = this.el.clientHeight || 600

    if (nodes.length === 0) {
      const empty = document.createElement("div")
      empty.className = "flex h-full items-center justify-center px-6 text-center text-sm font-medium"
      empty.style.color = palette.empty
      empty.textContent = "No converged network yet"
      this.el.appendChild(empty)

      return
    }

    const byId = new Map(nodes.map((node, index) => [node.id, {...node, ...this.nodePosition(index, nodes.length, width, height)}]))

    const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg")
    svg.setAttribute("width", "100%")
    svg.setAttribute("height", "100%")
    svg.setAttribute("viewBox", `0 0 ${width} ${height}`)

    const linkLayer = document.createElementNS("http://www.w3.org/2000/svg", "g")
    linkLayer.setAttribute("stroke-opacity", "0.62")

    links.forEach((link) => {
      const source = byId.get(link.source)
      const target = byId.get(link.target)
      if (!source || !target) return

      const line = document.createElementNS("http://www.w3.org/2000/svg", "line")
      line.setAttribute("x1", source.x)
      line.setAttribute("y1", source.y)
      line.setAttribute("x2", target.x)
      line.setAttribute("y2", target.y)
      line.setAttribute("stroke-width", `${1.5 + (link.weight || 1)}`)
      line.setAttribute("stroke", link.stance === "pro" ? palette.pro : link.stance === "contra" ? palette.contra : palette.neutral)
      linkLayer.appendChild(line)
    })

    const nodeLayer = document.createElementNS("http://www.w3.org/2000/svg", "g")
    const labelLayer = document.createElementNS("http://www.w3.org/2000/svg", "g")

    byId.forEach((node) => {
      const radius = this.nodeRadius(node)
      const circle = document.createElementNS("http://www.w3.org/2000/svg", "circle")
      circle.setAttribute("cx", node.x)
      circle.setAttribute("cy", node.y)
      circle.setAttribute("r", radius)
      circle.setAttribute("fill", node.group === "actor" ? palette.actor : palette.concept)
      circle.setAttribute("stroke", palette.stroke)
      circle.setAttribute("stroke-width", "2")

      const title = document.createElementNS("http://www.w3.org/2000/svg", "title")
      title.textContent = `${node.label || node.id} • ${node.weight || 1} references`
      circle.appendChild(title)
      nodeLayer.appendChild(circle)

      const label = document.createElementNS("http://www.w3.org/2000/svg", "text")
      label.setAttribute("x", node.x)
      label.setAttribute("y", node.y - (radius + 10))
      label.setAttribute("text-anchor", "middle")
      label.setAttribute("font-size", "12")
      label.setAttribute("font-weight", "600")
      label.setAttribute("fill", palette.label)
      label.textContent = node.label || node.id
      labelLayer.appendChild(label)
    })

    svg.appendChild(linkLayer)
    svg.appendChild(nodeLayer)
    svg.appendChild(labelLayer)
    this.el.appendChild(svg)
  },

  nodePosition(index, total, width, height) {
    const columns = Math.max(3, Math.ceil(Math.sqrt(total)))
    const rows = Math.max(2, Math.ceil(total / columns))
    const col = index % columns
    const row = Math.floor(index / columns)

    return {
      x: ((col + 1) * width) / (columns + 1),
      y: ((row + 1) * height) / (rows + 1),
    }
  },

  nodeRadius(node) {
    const weight = node.weight || 1
    const base = node.group === "actor" ? 14 : 18
    return Math.min(base + (weight * 1.4), 34)
  },

  drag() { return null }
}

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {...colocatedHooks, ...Hooks},
})

// Show progress bar on live navigation and form submits
const configureTopbar = () => {
  const accent = getComputedStyle(document.documentElement).getPropertyValue("--topbar").trim() || "#d0672d"
  topbar.config({barColors: {0: accent}, shadowColor: "rgba(0, 0, 0, .22)"})
}

configureTopbar()
window.addEventListener("app:theme-changed", configureTopbar)
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", _e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}

