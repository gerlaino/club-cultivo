import { reactive } from 'vue'

const state = reactive({
  open:        false,
  title:       '',
  message:     '',
  variant:     'danger',
  confirmText: 'Confirmar',
  cancelText:  'Cancelar',
  neutralText: '',      // botón intermedio opcional (3ª opción). Vacío = no se muestra.
  // Un texto opcional que se pide junto con la confirmación (p. ej. el motivo de «no se hizo»).
  // Con `campo`, aceptar resuelve `{ valor }` en vez de `true`.
  campo:       null,    // { label, placeholder }
  valor:       '',
  resolve:     null,
})

export function useConfirm() {
  // Resuelve: true (aceptar) | false (cancelar/descartar) | 'neutral' (3ª opción, si hay).
  function confirm(opts = {}) {
    state.title       = opts.title       || '¿Estás seguro?'
    state.message     = opts.message     || ''
    state.variant     = opts.variant     || 'danger'
    state.confirmText = opts.confirmText || 'Confirmar'
    state.cancelText  = opts.cancelText  || 'Cancelar'
    state.neutralText = opts.neutralText || ''
    state.campo       = opts.campo || null
    state.valor       = ''
    state.open        = true
    return new Promise((resolve) => { state.resolve = resolve })
  }

  function accept() {
    state.open = false
    state.resolve?.(state.campo ? { valor: state.valor.trim() } : true)
  }

  function cancel() {
    state.open = false
    state.resolve?.(false)
  }

  function neutral() {
    state.open = false
    state.resolve?.('neutral')
  }

  return { confirm, state, accept, cancel, neutral }
}
