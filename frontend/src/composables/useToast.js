import { reactive } from 'vue'

const toasts = reactive([])
let nextId = 0

const ICONS = {
  success: 'bi-check-circle-fill',
  error:   'bi-x-circle-fill',
  warning: 'bi-exclamation-triangle-fill',
  info:    'bi-info-circle-fill',
}

function add(msg, type = 'success', timeout = 3000) {
  const id = ++nextId
  toasts.push({ id, msg, type, icon: ICONS[type] || ICONS.info })
  setTimeout(() => remove(id), timeout)
}

function remove(id) {
  const idx = toasts.findIndex(t => t.id === id)
  if (idx !== -1) toasts.splice(idx, 1)
}

export function useToast() {
  return {
    success: (msg, opts = {}) => add(msg, 'success', opts.timeout ?? 3000),
    error:   (msg, opts = {}) => add(msg, 'error',   opts.timeout ?? 4500),
    info:    (msg, opts = {}) => add(msg, 'info',     opts.timeout ?? 3000),
    warning: (msg, opts = {}) => add(msg, 'warning',  opts.timeout ?? 3500),
    toasts,
    remove,
  }
}
