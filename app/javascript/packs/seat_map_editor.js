// Seat Map Editor pack — Konva-based graphical editor for seat geometry and
// zones. Loaded only on admin/seat_maps#editor via javascript_pack_tag.
import { boot } from '../seat_map_editor/editor'

document.addEventListener('DOMContentLoaded', () => {
  const root = document.getElementById('seat-map-editor-app')
  if (!root) return

  boot(root).catch((err) => {
    const status = document.getElementById('editor-status')
    if (status) {
      status.textContent = err.message
      status.className = 'editor-status error'
    }
    console.error('Seat map editor failed to boot', err)
  })
})
