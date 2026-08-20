import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'
import { mount } from '@vue/test-utils'
import { setActivePinia, createPinia } from 'pinia'
import { readFileSync } from 'node:fs'
import { resolve, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'

const AQUI = dirname(fileURLToPath(import.meta.url))
const SRC  = resolve(AQUI, '..')
const leer = (rel) => readFileSync(resolve(SRC, rel), 'utf8')
const offlineApiSrc = leer('lib/offlineApi.js')

// AC: sin conexión, la app tiene que ABRIR y tiene que DECIR LA VERDAD.
//
// Los dos agujeros que esto fija:
//
//   1. La PWA instalada no abría. `start_url` es /m, y una navegación a /m no matchea la entrada
//      `index.html` del precache —workbox prueba /m.html y /m/index.html, que no existen—, así que
//      salía a la red y moría en el dinosaurio de Chrome. En producción lo tapa el `spa_fallback`
//      de Rails; offline no hay servidor, que es justo cuando hace falta.
//   2. El cartel prometía "los registros se guardan localmente", y eso vale para TRES flujos
//      (dispensar, ambiente, entregas del repartidor) y para ninguno más. El manicura no tiene
//      cola: leía la promesa, cargaba el pesaje, le fallaba y se iba creyendo que había quedado.

describe('El service worker sirve la app sin conexión', () => {
  const sw = leer('sw.js')

  it('tiene fallback de navegación al shell', () => {
    expect(sw).toContain('NavigationRoute')
    expect(sw).toContain("createHandlerBoundToURL('index.html')")
  })

  // Devolver el HTML de la app cuando alguien pide un PDF o la API es peor que fallar: parece que
  // anduvo y el error aparece más tarde y en otro lado.
  it('no le devuelve el shell a lo que no sirve la SPA', () => {
    const denylist = sw.slice(sw.indexOf('denylist:'), sw.indexOf('\n}))', sw.indexOf('denylist:')))

    for (const ruta of ['api', 'rails', 'sidekiq', 'cable', 'up']) {
      expect(denylist, `falta ${ruta} en el denylist`).toContain(ruta)
    }
  })

  // /me no se cachea a propósito: servido del caché, después de un logout el SW devolvía el
  // usuario viejo y parecía que la sesión seguía abierta. No tocar sin resolver eso.
  it('sigue sin cachear los endpoints de sesión', () => {
    expect(sw).toContain("AUTH_BYPASS = ['/me'")
  })
})

describe('El cartel de sin conexión', () => {
  let OfflineIndicator

  beforeEach(async () => {
    setActivePinia(createPinia())
    localStorage.clear()
    vi.stubGlobal('navigator', { onLine: false })
    vi.resetModules()
    OfflineIndicator = (await import('../components/ui/OfflineIndicator.vue')).default
  })
  afterEach(() => { vi.unstubAllGlobals() })

  const montar = () => mount(OfflineIndicator)

  it('no promete que se guarda: eso no lo sabe, lo sabe cada pantalla', () => {
    const w = montar()

    expect(w.text()).toContain('Sin conexión')
    expect(w.text()).not.toContain('se guardan localmente')
  })

  it('con entregas del repartidor guardadas, las cuenta', async () => {
    localStorage.setItem('entregas_pendientes_v1', JSON.stringify([
      { id_local: 'a', tipo: 'entrega', dispensacion_id: 1, payload: {} },
      { id_local: 'b', tipo: 'fallo',   dispensacion_id: 2, motivo: 'ausente' },
    ]))
    vi.resetModules()
    const Comp = (await import('../components/ui/OfflineIndicator.vue')).default

    const w = mount(Comp)

    expect(w.text()).toContain('2 sin enviar')
  })
})

// Qué se puede guardar sin señal es una decisión de DOMINIO, no un detalle de implementación.
// Este test la deja escrita: si alguien suma o saca un flujo de la cola, falla y hay que venir acá
// a decir por qué.
describe('Qué se guarda sin señal', () => {
  const offlineApi = leer('lib/offlineApi.js')

  it('el ambiente se encola: no mueve stock ni plata', () => {
    for (const v of ['components/ambiente/LecturaManualForm.vue',
                     'components/salas/RegistrarLecturaModal.vue',
                     'components/lotes/registro/RegistroLoteModal.vue']) {
      expect(leer(v)).toContain('registrarLecturaOffline')
    }
  })

  // Está frente a la balanza y ya pesó: perder el número significa volver a pesar todo. No genera
  // stock —espera la confirmación del admin—, y esa confirmación es la red que atrapa un duplicado.
  it('el pesaje del manicura se encola', () => {
    expect(leer('views/manicura/MncLoteDetailView.vue')).toContain('registrarPesajeManicuraOffline')
    expect(offlineApi).toContain('registrarPesajeManicuraOffline')
  })

  // Un 409 `needs_choice` no se le puede preguntar a nadie desde una cola que corre sola, y como
  // tiene `response` la cola lo marcaría FALLIDO y perdería el pesaje.
  it('el pesaje encolado fuerza jornada nueva, para que el reintento no muera en un 409', () => {
    expect(offlineApi).toContain('force_new: true')
  })

  // DISPENSAR NO. Es la única escritura que mueve stock y plata a la vez, y encolarla descontaba
  // de una caché local que puede estar vieja: dos dispensadores sin señal entregaban el mismo gramo.
  it('dispensar NO se encola, y lo dice claro en vez de prometer que se guardó', () => {
    const modal = leer('components/pacientes/ModalNuevaDispensacion.vue')

    expect(modal).not.toContain('offlineApi')
    expect(modal).toContain('Sin conexión: la dispensación NO se registró')
    expect(offlineApi).not.toContain('dispensarOffline')
  })

  // El repartidor tiene su propia cola, en su propio localStorage: lo que se pierde ahí es la FIRMA
  // del paciente, que no se puede volver a pedir porque la persona ya se fue.
  it('el repartidor guarda la entrega antes de mandarla', () => {
    expect(leer('views/delivery/DeliveryDashboard.vue')).toContain('useEntregasOffline')
  })
})

// El bug que hacía que NADA de lo encolado llegara nunca al servidor.
describe('Las URLs de la cola', () => {
  it('no llevan /api: el baseURL de axios ya lo pone', () => {
    // Con `/api/lotes/...` guardado, el reintento pegaba a `/api/api/lotes/...` y volvía 404. Y un
    // 404 tiene `response`, así que `procesarCola` lo tomaba como error de validación y lo marcaba
    // FALLIDO en vez de reintentar: el registro se perdía y el usuario sólo veía "no pudo
    // sincronizarse".
    expect(leer('lib/api.js')).toContain('baseURL')

    const encoladas = [...offlineApiSrc.matchAll(/url:\s*`([^`]+)`/g)].map(m => m[1])

    expect(encoladas.length).toBeGreaterThan(0)
    for (const url of encoladas) {
      expect(url, `${url} no debe llevar el prefijo /api`).not.toMatch(/^\/api\//)
    }
  })
})

// El reintento de un pesaje que YA había entrado. La planta es la clave de idempotencia natural
// —se pesa una sola vez— así que el backend no puede duplicar; lo que faltaba era que lo DIJERA,
// porque desde la cola un 422 "ya estaba pesado" es idéntico a un 422 de validación.
describe('La cola distingue "ya estaba hecho" de "falló"', () => {
  const request = vi.fn()
  const toast   = { success: vi.fn(), warning: vi.fn() }

  beforeEach(() => {
    vi.resetModules()
    vi.clearAllMocks()
    setActivePinia(createPinia())
    localStorage.clear()
    vi.doMock('../lib/api.js', () => ({ default: { request } }))
    vi.doMock('../composables/useToast.js', () => ({ useToast: () => toast }))
  })

  async function correrCola(item) {
    const { useSyncQueueStore } = await import('../stores/syncQueue.js')
    const { useOfflineSync }    = await import('../composables/useOfflineSync.js')
    const queue = useSyncQueueStore()
    queue.encolar(item.tipo, { url: item.url, payload: item.payload })
    await useOfflineSync().procesarCola()
    return queue
  }

  const PESAJE = {
    tipo: 'pesaje_manicura',
    url: '/lotes/1/pesajes_manicura',
    payload: { plant_ids: [1, 2], peso_total_g: 100, enviar: true, force_new: true },
  }

  // Lo que veía la manicura antes: "no pudo sincronizarse", sobre un pesaje que SÍ había entrado.
  // Si a partir de ese aviso lo volvía a cargar, ahí sí quedaban dos jornadas.
  it('un 422 con ya_registrado se da por enviado, no por fallido', async () => {
    request.mockRejectedValue({ response: { status: 422, data: { ya_registrado: true } } })

    const queue = await correrCola(PESAJE)

    expect(queue.fallidos.length).toBe(0)
    expect(queue.total).toBe(0)
    expect(toast.warning).not.toHaveBeenCalled()
  })

  it('un 422 común sigue siendo un fallo: no se lo traga en silencio', async () => {
    request.mockRejectedValue({ response: { status: 422, data: { error: 'Peso inválido' } } })

    const queue = await correrCola(PESAJE)

    expect(queue.fallidos.length).toBe(1)
  })

  // Sin respuesta es sin señal: se conserva para el próximo intento, no se descarta.
  it('un error de red deja el item pendiente', async () => {
    request.mockRejectedValue({})

    const queue = await correrCola(PESAJE)

    expect(queue.pendientes.length).toBe(1)
    expect(queue.fallidos.length).toBe(0)
  })
})
