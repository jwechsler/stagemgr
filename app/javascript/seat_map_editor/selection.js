// Selection behaviors: click / shift-click, rubber-band marquee on empty
// background, and en-masse dragging of the whole selection (e.g. moving a
// full row). Plain drag on background = marquee; hold SPACE to pan instead.

import Konva from 'konva'
import * as SeatStore from './seats'

export function initSelection(ctx) {
  const { stage, overlayLayer } = ctx

  let marquee = null
  let marqueeStart = null

  stage.on('mousedown', (e) => {
    if (ctx.spacePanning || ctx.addMode) return
    if (e.target !== stage && e.target.getClassName() !== 'Image') return

    marqueeStart = stage.getRelativePointerPosition()
    marquee = new Konva.Rect({
      x: marqueeStart.x,
      y: marqueeStart.y,
      width: 0,
      height: 0,
      fill: 'rgba(0, 161, 255, 0.15)',
      stroke: '#00A1FF',
      strokeWidth: 1 / ctx.currentScale(),
      listening: false
    })
    overlayLayer.add(marquee)
  })

  stage.on('mousemove', () => {
    if (!marquee) return
    const pos = stage.getRelativePointerPosition()
    marquee.setAttrs({
      x: Math.min(marqueeStart.x, pos.x),
      y: Math.min(marqueeStart.y, pos.y),
      width: Math.abs(pos.x - marqueeStart.x),
      height: Math.abs(pos.y - marqueeStart.y)
    })
    overlayLayer.batchDraw()
  })

  stage.on('mouseup', (e) => {
    if (!marquee) return
    const box = marquee.getClientRect()
    const dragged = marquee.width() > 2 || marquee.height() > 2
    marquee.destroy()
    marquee = null
    overlayLayer.batchDraw()

    if (dragged) {
      const keys = []
      ctx.nodes.forEach((node, key) => {
        if (Konva.Util.haveIntersection(box, node.getClientRect())) keys.push(key)
      })
      ctx.setSelection(keys, { additive: e.evt.shiftKey })
    } else if (e.target === stage || e.target.getClassName() === 'Image') {
      ctx.setSelection([]) // click on empty background clears
    }
  })

  // --- Group drag -----------------------------------------------------------
  let dragStartPositions = null

  ctx.onSeatNode = (node, key) => {
    node.on('click', (e) => {
      e.cancelBubble = true
      if (e.evt.shiftKey) {
        ctx.toggleSelected(key)
      } else {
        ctx.setSelection([key])
      }
    })

    node.on('dragstart', () => {
      if (!ctx.selection.has(key)) ctx.setSelection([key])
      SeatStore.beginMutation(ctx.store)
      dragStartPositions = new Map()
      ctx.selection.forEach((k) => {
        const n = ctx.nodes.get(k)
        if (n) dragStartPositions.set(k, { x: n.x(), y: n.y() })
      })
    })

    node.on('dragmove', () => {
      if (!dragStartPositions) return
      const origin = dragStartPositions.get(key)
      const dx = node.x() - origin.x
      const dy = node.y() - origin.y
      ctx.selection.forEach((k) => {
        if (k === key) return
        const n = ctx.nodes.get(k)
        const start = dragStartPositions.get(k)
        if (n && start) n.position({ x: start.x + dx, y: start.y + dy })
      })
      ctx.seatLayer.batchDraw()
    })

    node.on('dragend', () => {
      if (!dragStartPositions) return
      const moved = []
      ctx.selection.forEach((k) => {
        const n = ctx.nodes.get(k)
        if (n) moved.push({ key: k, x: n.x(), y: n.y() })
      })
      dragStartPositions = null
      SeatStore.setPositions(ctx.store, moved)
      ctx.onMutated()
    })
  }
}
