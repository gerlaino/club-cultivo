import { reactive } from 'vue'

const state = reactive({
  open:        false,
  title:       '',
  message:     '',
  variant:     'danger',
  confirmText: 'Confirmar',
  cancelText:  'Cancelar',
  resolve:     null,
})

export function useConfirm() {
  function confirm(opts = {}) {
    state.title       = opts.title       || '¿Estás seguro?'
    state.message     = opts.message     || ''
    state.variant     = opts.variant     || 'danger'
    state.confirmText = opts.confirmText || 'Confirmar'
    state.cancelText  = opts.cancelText  || 'Cancelar'
    state.open        = true
    return new Promise((resolve) => { state.resolve = resolve })
  }

  function accept() {
    state.open = false
    state.resolve?.(true)
  }

  function cancel() {
    state.open = false
    state.resolve?.(false)
  }

  return { confirm, state, accept, cancel }
}
