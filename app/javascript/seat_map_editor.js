// Seat map editor entry point: Konva-based graphical editor for seat geometry
// and zones. `yarn build` bundles it with esbuild into app/assets/builds/,
// which Sprockets serves; loaded only on admin/seat_maps#editor.
import { boot } from './seat_map_editor/editor'

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
