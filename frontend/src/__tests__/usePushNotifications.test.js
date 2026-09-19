import { describe, it, expect, vi, beforeEach } from 'vitest'
import { createPinia, setActivePinia } from 'pinia'
import { defineComponent, h } from 'vue'
import { mount } from '@vue/test-utils'

const post = vi.fn(() => Promise.resolve({ data: {} }))
vi.mock('../lib/api.js', () => ({ default: { post: (...a) => post(...a), delete: vi.fn() } }))

import { usePushNotifications, MOTIVOS } from '../composables/usePushNotifications.js'
import { useAuthStore } from '../stores/auth'

// Un navegador que sabe de push: service worker listo y un pushManager que anota con qué
// clave lo suscribieron.
const pushSubscribe = vi.fn(() => Promise.resolve({
  endpoint: 'https://push.example/abc',
  toJSON: () => ({ endpoint: 'https://push.example/abc', keys: { p256dh: 'p', auth: 'a' } }),
}))
function navegadorConPush(permiso = 'granted') {
  Object.defineProperty(navigator, 'serviceWorker', {
    configurable: true,
    value: { ready: Promise.resolve({ pushManager: { subscribe: pushSubscribe, getSubscription: () => Promise.resolve(null) } }) },
  })
  window.PushManager = function () {}
  window.Notification = { permission: permiso === 'denied' ? 'denied' : 'default', requestPermission: vi.fn(() => Promise.resolve(permiso)) }
}

function montar(user) {
  let api
  const Comp = defineComponent({ setup() { api = usePushNotifications(); return () => h('div') } })
  const auth = useAuthStore()
  auth.user = user
  mount(Comp)
  return api
}

// La clave pública VAPID la manda el backend en /me. Antes salía del build
// (`VITE_VAPID_PUBLIC_KEY`), que en producción nadie fijaba: «Activar notificaciones» quedó
// compilado como `return false` y nunca hubo una suscripción a la que mandarle un push.
describe('usePushNotifications — la clave la manda el backend', () => {
  beforeEach(() => { setActivePinia(createPinia()); post.mockClear(); pushSubscribe.mockClear(); navegadorConPush() })

  it('sin clave del servidor no se ofrece el botón, y suscribir dice por qué', async () => {
    const api = montar({ id: 1, push_vapid_public_key: null })

    expect(api.disponible.value).toBe(false)
    expect(await api.subscribe()).toBe('no_configurado')
    expect(MOTIVOS.no_configurado).toMatch(/no están configuradas/)
    expect(window.Notification.requestPermission).not.toHaveBeenCalled()
    expect(post).not.toHaveBeenCalled()
  })

  it('con clave del servidor se suscribe con ESA clave y la registra en el backend', async () => {
    const api = montar({ id: 1, push_vapid_public_key: 'BBYoR0F5-2KvtR_n' })

    expect(api.disponible.value).toBe(true)
    expect(await api.subscribe()).toBe(true)
    expect(pushSubscribe).toHaveBeenCalledTimes(1)
    expect(pushSubscribe.mock.calls[0][0].applicationServerKey).toBeInstanceOf(Uint8Array)
    expect(post).toHaveBeenCalledWith('/push_subscriptions', expect.objectContaining({
      endpoint: 'https://push.example/abc', p256dh_key: 'p', auth_key: 'a',
    }))
    expect(api.subscribed.value).toBe(true)
  })

  it('si el navegador bloquea el permiso lo dice, sin registrar nada', async () => {
    navegadorConPush('denied')
    const api = montar({ id: 1, push_vapid_public_key: 'BBYoR0F5-2KvtR_n' })

    expect(await api.subscribe()).toBe('denegado')
    expect(api.denied.value).toBe(true)
    expect(post).not.toHaveBeenCalled()
  })
})
