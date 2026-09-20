import { ref, computed, onMounted, onUnmounted } from 'vue'
import api from '../lib/api.js'
import { useAuthStore } from '../stores/auth'

// La clave pública VAPID la manda el backend en `/me` (`push_vapid_public_key`), NO el build.
// Hasta el 19-sep-2026 salía de `import.meta.env.VITE_VAPID_PUBLIC_KEY`, que en Render nadie
// pasaba a `npm run build`: Vite compilaba `subscribe()` como `return false`, «Activar
// notificaciones» no hacía nada y nunca hubo una suscripción a la que mandarle un push. El
// único que tiene el par es el backend (`PushNotificationJob`), así que es el que dice con cuál
// suscribirse; sin clave, este servidor no manda push y el botón no se ofrece.
function urlBase64ToUint8Array(base64) {
  const padding = '='.repeat((4 - (base64.length % 4)) % 4)
  const b64 = (base64 + padding).replace(/-/g, '+').replace(/_/g, '/')
  const raw = window.atob(b64)
  return Uint8Array.from(raw, c => c.charCodeAt(0))
}

// Por qué no se pudo: el botón nunca más se queda mudo. Cada valor tiene su texto en
// `MOTIVOS`, para que quien lo muestre no invente el suyo.
export const MOTIVOS = {
  no_soportado:   'Este navegador no soporta notificaciones push.',
  ios_instalar:   'En iPhone las notificaciones sólo funcionan con la app agregada a la pantalla de inicio: en Safari tocá Compartir → «Agregar a inicio» y abrila desde ahí.',
  no_configurado: 'Las notificaciones push no están configuradas en este servidor.',
  sin_sw:         'La app no terminó de instalarse en este navegador. Recargá la página y probá de nuevo.',
  denegado:       'Este navegador tiene las notificaciones bloqueadas para la app. Para permitirlas: tocá el candado (o el ícono de ajustes) a la izquierda de la dirección, entrá a «Notificaciones» y elegí «Permitir». Después volvé acá y tocá de nuevo.',
  rechazado:      'No se dio permiso para notificar.',
  error:          'No se pudo activar. Probá de nuevo; si sigue, avisá.',
}

// `navigator.serviceWorker.ready` es una promesa que NUNCA rechaza: sin service worker (el dev
// server no registra uno; en producción, si falló la instalación) se queda esperando para
// siempre, y con ella el botón, deshabilitado y mudo. Con techo: pasado el plazo, se dice.
const SW_ESPERA_MS = 8000
function swListo() {
  return Promise.race([
    navigator.serviceWorker.ready,
    new Promise((_, reject) => setTimeout(() => reject(new Error('sin_sw')), SW_ESPERA_MS)),
  ])
}

export function usePushNotifications() {
  const auth       = useAuthStore()
  const supported  = 'serviceWorker' in navigator && 'PushManager' in window && 'Notification' in window
  // iPhone desde Safari, sin instalar: Apple no da push ahí (recién con la app en la pantalla de
  // inicio aparece `PushManager`). Se distingue del «no soportado» genérico para poder decirle
  // a la persona qué hacer, en vez de esconder el botón.
  const esIOS         = /iPhone|iPad|iPod/.test(navigator.userAgent)
  const standalone    = window.matchMedia?.('(display-mode: standalone)')?.matches || navigator.standalone === true
  const iosSinInstalar = esIOS && !standalone && !('PushManager' in window)
  const subscribed = ref(false)
  const loading    = ref(false)
  const denied     = ref(false)
  const vapidKey   = computed(() => auth.user?.push_vapid_public_key || null)
  // Sólo se ofrece donde puede andar: navegador que sabe Y servidor que manda.
  const disponible = computed(() => supported && !!vapidKey.value)

  async function checkStatus() {
    if (!supported) return
    // El permiso se lee ANTES de esperar al service worker: es síncrono y es lo que decide
    // si el botón dice «bloqueadas». Esperar al SW para saberlo dejaba el texto viejo.
    denied.value = Notification.permission === 'denied'
    try {
      const reg = await swListo()
      const sub = await reg.pushManager.getSubscription()
      subscribed.value = !!sub
    } catch {}
  }

  // Devuelve `true` si quedó suscripto, o la clave del motivo (`MOTIVOS`) si no.
  async function subscribe() {
    if (iosSinInstalar)  return 'ios_instalar'
    if (!supported)      return 'no_soportado'
    if (!vapidKey.value) return 'no_configurado'
    loading.value = true
    try {
      const permission = await Notification.requestPermission()
      if (permission !== 'granted') {
        denied.value = permission === 'denied'
        return denied.value ? 'denegado' : 'rechazado'
      }

      const reg = await swListo()
      const sub = await reg.pushManager.subscribe({
        userVisibleOnly:      true,
        applicationServerKey: urlBase64ToUint8Array(vapidKey.value),
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
      return e?.message === 'sin_sw' ? 'sin_sw' : 'error'
    } finally {
      loading.value = false
    }
  }

  // Devuelve `true` si quedó desuscripto. Primero el navegador y después el servidor: si el
  // servidor falla, el endpoint ya está muerto y el job lo apaga solo al primer 410.
  async function unsubscribe() {
    if (!supported) return 'no_soportado'
    loading.value = true
    try {
      const reg = await swListo()
      const sub = await reg.pushManager.getSubscription()
      if (sub) {
        await sub.unsubscribe()
        await api.delete('/push_subscriptions', { data: { endpoint: sub.endpoint } })
      }
      subscribed.value = false
      return true
    } catch (e) {
      console.error('[push] unsubscribe error:', e)
      await checkStatus()
      return e?.message === 'sin_sw' ? 'sin_sw' : 'error'
    } finally {
      loading.value = false
    }
  }

  // Se vuelve a mirar cada vez que la persona vuelve a la pestaña: si fue a desbloquear las
  // notificaciones en la configuración del navegador, el botón tiene que volver a «Activar»
  // solo, sin recargar.
  const alVolver = () => { if (!document.hidden) checkStatus() }
  onMounted(() => { checkStatus(); document.addEventListener('visibilitychange', alVolver); window.addEventListener('focus', alVolver) })
  onUnmounted(() => { document.removeEventListener('visibilitychange', alVolver); window.removeEventListener('focus', alVolver) })

  return { supported, disponible, iosSinInstalar, subscribed, loading, denied, subscribe, unsubscribe, checkStatus }
}
