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
import * as d3 from "d3"

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
    const container = d3.select(this.el)
    container.selectAll("*").remove()
    const palette = this.palette()

    const width = this.el.clientWidth || 800
    const height = this.el.clientHeight || 600

    const svg = container.append("svg")
      .attr("width", "100%")
      .attr("height", "100%")
      .attr("viewBox", [0, 0, width, height])

    if (nodes.length === 0) {
      container.append("div")
        .attr("class", "flex h-full items-center justify-center px-6 text-center text-sm font-medium")
        .style("color", palette.empty)
        .text("No converged network yet")

      return
    }

    const simulation = d3.forceSimulation(nodes)
      .force("link", d3.forceLink(links).id(d => d.id).distance(d => 120 + ((d.weight || 1) * 4)))
      .force("charge", d3.forceManyBody().strength(-520))
      .force("center", d3.forceCenter(width / 2, height / 2))
      .force("collision", d3.forceCollide().radius(d => this.nodeRadius(d) + 8))

    const link = svg.append("g")
      .attr("stroke-opacity", 0.6)
      .selectAll("line")
      .data(links)
      .join("line")
      .attr("stroke-width", d => 1.5 + (d.weight || 1))
      .attr("stroke", d => {
        if (d.stance === "pro") return palette.pro
        if (d.stance === "contra") return palette.contra
        return palette.neutral
      })

    const node = svg.append("g")
      .selectAll("circle")
      .data(nodes)
      .join("circle")
      .attr("r", d => this.nodeRadius(d))
      .attr("fill", d => d.group === "actor" ? palette.actor : palette.concept)
      .attr("stroke", palette.stroke)
      .attr("stroke-width", 2)
      .call(this.drag(simulation))

    node.append("title")
      .text(d => `${d.label || d.id} • ${d.weight || 1} references`)

    const label = svg.append("g")
      .selectAll("text")
      .data(nodes)
      .join("text")
      .attr("dy", d => -(this.nodeRadius(d) + 10))
      .attr("text-anchor", "middle")
      .text(d => d.label || d.id)
      .style("font-size", "12px")
      .style("font-weight", "600")
      .style("fill", palette.label)

    simulation.on("tick", () => {
      link.attr("x1", d => d.source.x).attr("y1", d => d.source.y)
          .attr("x2", d => d.target.x).attr("y2", d => d.target.y)
      node.attr("cx", d => d.x).attr("cy", d => d.y)
      label.attr("x", d => d.x).attr("y", d => d.y)
    })
  },

  nodeRadius(node) {
    const weight = node.weight || 1
    const base = node.group === "actor" ? 14 : 18
    return Math.min(base + (weight * 1.4), 34)
  },

  drag(simulation) {
    function dragstarted(event) {
      if (!event.active) simulation.alphaTarget(0.3).restart()
      event.subject.fx = event.subject.x
      event.subject.fy = event.subject.y
    }
    function dragged(event) {
      event.subject.fx = event.x
      event.subject.fy = event.y
    }
    function dragended(event) {
      if (!event.active) simulation.alphaTarget(0)
      event.subject.fx = null
      event.subject.fy = null
    }
    return d3.drag().on("start", dragstarted).on("drag", dragged).on("end", dragended)
  }
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

