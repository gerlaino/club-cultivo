import { ref, onMounted } from 'vue'
import api from '../lib/api.js'

const VAPID_PUBLIC_KEY = import.meta.env.VITE_VAPID_PUBLIC_KEY

function urlBase64ToUint8Array(base64) {
  const padding = '='.repeat((4 - (base64.length % 4)) % 4)
  const b64 = (base64 + padding).replace(/-/g, '+').replace(/_/g, '/')
  const raw = window.atob(b64)
  return Uint8Array.from(raw, c => c.charCodeAt(0))
}

export function usePushNotifications() {
  const supported  = 'serviceWorker' in navigator && 'PushManager' in window && 'Notification' in window
  const subscribed = ref(false)
  const loading    = ref(false)
  const denied     = ref(false)

  async function checkStatus() {
    if (!supported) return
    try {
      const reg = await navigator.serviceWorker.ready
      const sub = await reg.pushManager.getSubscription()
      subscribed.value = !!sub
      denied.value = Notification.permission === 'denied'
    } catch {}
  }

  async function subscribe() {
    if (!supported || !VAPID_PUBLIC_KEY) return false
    loading.value = true
    try {
      const permission = await Notification.requestPermission()
      if (permission !== 'granted') {
        denied.value = permission === 'denied'
        return false
      }

      const reg = await navigator.serviceWorker.ready
      const sub = await reg.pushManager.subscribe({
        userVisibleOnly:      true,
        applicationServerKey: urlBase64ToUint8Array(VAPID_PUBLIC_KEY),
      })

      const json = sub.toJSON()
      await api.post('/push_subscriptions', {
        endpoint:    json.endpoint,
        p256dh_key:  json.keys.p256dh,
        auth_key:    json.keys.auth,
        device_name: navigator.platform || navigator.userAgent.slice(0, 50),
      })

      subscribed.value = true
      return true
    } catch (e) {
      console.error('[push] subscribe error:', e)
      return false
    } finally {
      loading.value = false
    }
  }

  async function unsubscribe() {
    if (!supported) return
    loading.value = true
    try {
      const reg = await navigator.serviceWorker.ready
      const sub = await reg.pushManager.getSubscription()
      if (sub) {
        await api.delete('/push_subscriptions', { data: { endpoint: sub.endpoint } })
        await sub.unsubscribe()
      }
      subscribed.value = false
    } catch (e) {
      console.error('[push] unsubscribe error:', e)
    } finally {
      loading.value = false
    }
  }

  onMounted(checkStatus)

  return { supported, subscribed, loading, denied, subscribe, unsubscribe, checkStatus }
}
