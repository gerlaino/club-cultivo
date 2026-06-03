import { ref, onMounted, onUnmounted } from 'vue'

// Singleton: una sola instancia compartida en toda la app
const isOnline  = ref(typeof navigator !== 'undefined' ? navigator.onLine : true)
const listeners = []

if (typeof window !== 'undefined') {
  window.addEventListener('online',  () => { isOnline.value = true  })
  window.addEventListener('offline', () => { isOnline.value = false })
}

export function useNetwork() {
  return { isOnline }
}
