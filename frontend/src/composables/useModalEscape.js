import { onMounted, onUnmounted } from 'vue'

export function useModalEscape(onEscape) {
  function handler(e) {
    if (e.key === 'Escape') onEscape()
  }
  onMounted(()  => document.addEventListener('keydown', handler))
  onUnmounted(() => document.removeEventListener('keydown', handler))
}
