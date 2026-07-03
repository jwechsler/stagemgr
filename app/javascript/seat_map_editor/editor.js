// Seat map editor: Konva stage over the venue's base PNG. Geometry editing
// (drag / marquee multi-select / group move / add / delete), zone painting,
// wheel-zoom + space-drag pan, single-level undo, explicit batch Save.

import Konva from 'konva'
import { loadEditorData, saveSeats } from './api'
import * as SeatStore from './seats'
import { zoneColor, zoneProgression } from './zone_colors'
import { initSelection } from './selection'
import { initZonePanel } from './zone_panel'
import { initRadiusPanel } from './radius_panel'
import { initCoordinatePanels } from './coordinate_panel'
import { initLabelPanel } from './label_panel'

const MIN_ZOOM = 0.5
const MAX_ZOOM = 4
const ZOOM_STEP = 1.08

export async function boot(root) {
  const config = root.dataset
  const data = await loadEditorData(config.editorDataUrl)

  const container = document.getElementById('seatmap-editor')
  const mapWidth = data.seat_map.width || 1200
  const mapHeight = data.seat_map.height || 900

  const stage = new Konva.Stage({
    container: 'seatmap-editor',
    width: container.clientWidth,
    height: Math.max(480, window.innerHeight - container.getBoundingClientRect().top - 24)
  })
  const imageLayer = new Konva.Layer({ listening: true })
  const seatLayer = new Konva.Layer()
  const overlayLayer = new Konva.Layer({ listening: false })
  stage.add(imageLayer, seatLayer, overlayLayer)

  // Fit the map into the viewport; zoom multiplies this base scale.
  const baseScale = Math.min(stage.width() / mapWidth, stage.height() / mapHeight)
  let zoom = 1
  stage.scale({ x: baseScale, y: baseScale })

  const ctx = {
    stage,
    imageLayer,
    seatLayer,
    overlayLayer,
    store: SeatStore.createStore(data.seats),
    nodes: new Map(),
    selection: new Set(),
    onSelectionChanged: [],
    spacePanning: false,
    addMode: false,
    onSeatNode: null, // provided by initSelection
    currentScale: () => baseScale * zoom,
    setStatus,
    onMutated: refreshDirtyState
  }

  // --- UI elements ----------------------------------------------------------
  const ui = {
    addBtn: document.getElementById('add-seat-btn'),
    deleteBtn: document.getElementById('delete-seats-btn'),
    undoBtn: document.getElementById('undo-btn'),
    saveBtn: document.getElementById('save-btn'),
    labelInput: document.getElementById('label-input'),
    zoneInput: document.getElementById('zone-input'),
    radiusInput: document.getElementById('radius-input'),
    xInput: document.getElementById('x-input'),
    yInput: document.getElementById('y-input'),
    status: document.getElementById('editor-status'),
    newSeatForm: document.getElementById('new-seat-form')
  }

  function setStatus(message, kind = 'info') {
    ui.status.textContent = message || ''
    ui.status.className = kind === 'error' ? 'editor-status error' : 'editor-status'
  }

  // --- Base image -----------------------------------------------------------
  if (data.seat_map.image_url) {
    const img = new window.Image()
    img.onload = () => {
      imageLayer.add(new Konva.Image({ image: img, width: mapWidth, height: mapHeight }))
      imageLayer.batchDraw()
    }
    img.src = data.seat_map.image_url
  }

  // --- Seat rendering -------------------------------------------------------
  function seatStyle(node, seat, selected) {
    node.setAttrs({
      stroke: zoneColor(seat.zone, ctx.zoneProgression),
      strokeWidth: selected ? 4 : 2,
      fill: selected ? 'rgba(0, 161, 255, 0.6)' : seat.deletable ? 'rgba(0, 0, 255, 0.35)' : 'rgba(0, 200, 0, 0.45)',
      shadowColor: 'black',
      shadowBlur: selected ? 6 : 0,
      shadowOpacity: 0.4
    })
  }

  function render() {
    // Per-map color progression, recomputed so newly stamped zones color up
    // immediately (matches ZoneHelper's per-map assignment).
    ctx.zoneProgression = zoneProgression(ctx.store.seats)

    // Remove nodes for seats gone from the store (deleted or undone adds).
    Array.from(ctx.nodes.keys()).forEach((key) => {
      if (!ctx.store.seats.has(key)) {
        ctx.nodes.get(key).destroy()
        ctx.nodes.delete(key)
        ctx.selection.delete(key)
      }
    })

    ctx.store.seats.forEach((seat, key) => {
      let node = ctx.nodes.get(key)
      if (!node) {
        node = new Konva.Circle({ draggable: true })
        ctx.nodes.set(key, node)
        seatLayer.add(node)
        ctx.onSeatNode(node, key)
      }
      node.setAttrs({ x: seat.origin_x, y: seat.origin_y, radius: seat.width || 8 })
      seatStyle(node, seat, ctx.selection.has(key))
    })
    seatLayer.batchDraw()
    notifySelectionChanged()
  }

  function notifySelectionChanged() {
    ctx.onSelectionChanged.forEach((fn) => fn())
    ui.deleteBtn.disabled = ctx.selection.size === 0
  }

  ctx.setSelection = (keys, { additive = false } = {}) => {
    if (!additive) ctx.selection.clear()
    keys.forEach((k) => ctx.selection.add(k))
    ctx.zoneProgression = zoneProgression(ctx.store.seats)
    ctx.store.seats.forEach((seat, key) => {
      const node = ctx.nodes.get(key)
      if (node) seatStyle(node, seat, ctx.selection.has(key))
    })
    seatLayer.batchDraw()
    notifySelectionChanged()
  }

  ctx.toggleSelected = (key) => {
    if (ctx.selection.has(key)) ctx.selection.delete(key)
    else ctx.selection.add(key)
    ctx.setSelection(Array.from(ctx.selection))
  }

  function refreshDirtyState() {
    const dirty = SeatStore.isDirty(ctx.store)
    ui.saveBtn.disabled = !dirty
    ui.undoBtn.disabled = !SeatStore.canUndo(ctx.store)
    document.getElementById('dirty-indicator').style.display = dirty ? 'inline' : 'none'
    render()
  }

  // --- Zoom & pan -----------------------------------------------------------
  stage.on('wheel', (e) => {
    e.evt.preventDefault()
    const pointer = stage.getPointerPosition()
    const oldScale = ctx.currentScale()
    zoom = Math.min(MAX_ZOOM, Math.max(MIN_ZOOM, zoom * (e.evt.deltaY < 0 ? ZOOM_STEP : 1 / ZOOM_STEP)))
    const newScale = ctx.currentScale()

    const mapPoint = {
      x: (pointer.x - stage.x()) / oldScale,
      y: (pointer.y - stage.y()) / oldScale
    }
    stage.scale({ x: newScale, y: newScale })
    stage.position({ x: pointer.x - mapPoint.x * newScale, y: pointer.y - mapPoint.y * newScale })
    stage.batchDraw()
  })

  window.addEventListener('keydown', (e) => {
    if (e.code === 'Space' && !isTyping(e)) {
      e.preventDefault()
      ctx.spacePanning = true
      stage.draggable(true)
      container.style.cursor = 'grab'
    }
  })
  window.addEventListener('keyup', (e) => {
    if (e.code === 'Space') {
      ctx.spacePanning = false
      stage.draggable(false)
      container.style.cursor = ''
    }
  })

  function isTyping(e) {
    return ['INPUT', 'TEXTAREA', 'SELECT'].includes(e.target.tagName)
  }

  // --- Add seat -------------------------------------------------------------
  function setAddMode(on) {
    ctx.addMode = on
    ui.addBtn.classList.toggle('hollow', !on)
    container.style.cursor = on ? 'crosshair' : ''
    if (!on) hideNewSeatForm()
  }

  ui.addBtn.addEventListener('click', () => setAddMode(!ctx.addMode))
  ui.addBtn.disabled = false // rendered disabled until this handler exists

  stage.on('click', () => {
    if (!ctx.addMode) return
    const pos = stage.getRelativePointerPosition()
    const suggestion = SeatStore.suggestNewSeat(ctx.store, pos.x, pos.y)
    showNewSeatForm(suggestion)
  })

  function field(name) {
    return ui.newSeatForm.querySelector(`[name="${name}"]`)
  }

  function showNewSeatForm(suggestion) {
    ;['row', 'seat_number', 'location', 'zone'].forEach((f) => {
      field(f).value = suggestion[f]
    })
    ui.newSeatForm.dataset.originX = suggestion.origin_x
    ui.newSeatForm.dataset.originY = suggestion.origin_y
    ui.newSeatForm.dataset.width = suggestion.width
    ui.newSeatForm.dataset.height = suggestion.height
    ui.newSeatForm.style.display = 'block'
    field('location').focus()
  }

  function hideNewSeatForm() {
    ui.newSeatForm.style.display = 'none'
  }

  ui.newSeatForm.querySelector('.confirm').addEventListener('click', () => {
    const zone = field('zone').value.trim().toUpperCase() || 'A'
    const location = field('location').value.trim()
    if (!SeatStore.ZONE_FORMAT.test(zone)) {
      setStatus('Zone must be 1-2 characters A-Z or 0-9', 'error')
      return
    }
    if (!location) {
      setStatus('Location is required', 'error')
      return
    }
    if (SeatStore.locationTaken(ctx.store, location)) {
      setStatus(`Location ${location} is already used on this map`, 'error')
      return
    }
    const seat = SeatStore.addSeat(ctx.store, {
      row: field('row').value.trim(),
      seat_number: parseInt(field('seat_number').value, 10) || 1,
      location,
      zone,
      origin_x: parseInt(ui.newSeatForm.dataset.originX, 10),
      origin_y: parseInt(ui.newSeatForm.dataset.originY, 10),
      width: parseInt(ui.newSeatForm.dataset.width, 10) || 8,
      height: parseInt(ui.newSeatForm.dataset.height, 10) || 8
    })
    hideNewSeatForm()
    setAddMode(false)
    setStatus(`Added seat ${seat.location}`)
    refreshDirtyState()
    ctx.setSelection([seat.key])
  })

  ui.newSeatForm.querySelector('.cancel').addEventListener('click', () => {
    hideNewSeatForm()
    setAddMode(false)
  })

  // --- Delete ---------------------------------------------------------------
  function deleteSelection() {
    if (ctx.selection.size === 0) return
    const result = SeatStore.deleteSeats(ctx.store, Array.from(ctx.selection))
    if (result.blocked.length) {
      const locations = result.blocked.map((s) => s.location).join(', ')
      setStatus(`Cannot delete seats with sold or held tickets: ${locations}`, 'error')
      return
    }
    setStatus('Seat(s) deleted (not saved yet)')
    refreshDirtyState()
  }

  ui.deleteBtn.addEventListener('click', deleteSelection)

  // --- Undo -----------------------------------------------------------------
  function undo() {
    if (SeatStore.undo(ctx.store)) {
      setStatus('Undid last change')
      refreshDirtyState()
    }
  }
  ui.undoBtn.addEventListener('click', undo)

  window.addEventListener('keydown', (e) => {
    if (isTyping(e)) return
    if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === 'z') {
      e.preventDefault()
      undo()
    } else if (e.key === 'Delete' || e.key === 'Backspace') {
      e.preventDefault()
      deleteSelection()
    } else if (e.key === 'Escape') {
      setAddMode(false)
      ctx.setSelection([])
    }
  })

  // --- Save -----------------------------------------------------------------
  ui.saveBtn.addEventListener('click', async () => {
    const ops = SeatStore.computeOps(ctx.store)
    if (!ops.length) return
    ui.saveBtn.disabled = true
    setStatus('Saving…')
    try {
      await saveSeats(config.saveUrl, ops)
      const fresh = await loadEditorData(config.editorDataUrl)
      ctx.store = SeatStore.createStore(fresh.seats)
      ctx.selection.clear()
      setStatus(`Saved ${ops.length} change(s)`)
      refreshDirtyState()
    } catch (err) {
      setStatus(err.message, 'error')
      ui.saveBtn.disabled = false
    }
  })

  window.addEventListener('beforeunload', (e) => {
    if (SeatStore.isDirty(ctx.store)) {
      e.preventDefault()
      e.returnValue = ''
    }
  })

  // --- Boot -----------------------------------------------------------------
  initSelection(ctx)
  initLabelPanel(ctx, ui.labelInput)
  initZonePanel(ctx, ui.zoneInput)
  initRadiusPanel(ctx, ui.radiusInput)
  initCoordinatePanels(ctx, ui.xInput, ui.yInput)
  render()
  refreshDirtyState()
  setStatus(`Loaded ${ctx.store.seats.size} seats`)
}
