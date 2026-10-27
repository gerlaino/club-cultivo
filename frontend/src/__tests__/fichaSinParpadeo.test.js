import { describe, it, expect, vi, beforeEach } from 'vitest'
import { createPinia, setActivePinia } from 'pinia'
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'

// EL CARTEL ROJO QUE APARECÍA UN INSTANTE (Germán, 27-oct-2026: «cuando creás una nueva
// dispensación y la confirmás, por un milisegundo aparece un cartel rojo de error de carga… y no es
// el único lugar»).
//
// Lo que tiene que pasar: recargar la ficha que se está mirando (después de guardar, o por un
// aviso) NO la deja vacía mientras viaja el pedido —vacía, la pantalla decía «Paciente no
// encontrado» y rearmaba sus solapas—. Abrir OTRA ficha sí arranca de cero. Y si dos respuestas
// llegan desordenadas, queda la del último pedido.

const api = vi.hoisted(() => ({
  getPaciente: vi.fn(), getUser: vi.fn(), getPlant: vi.fn(), getLote: vi.fn(), getSala: vi.fn(),
}))
vi.mock('../lib/api', () => ({
  getPaciente: (...a) => api.getPaciente(...a),
  getUser:     (...a) => api.getUser(...a),
  getPlant:    (...a) => api.getPlant(...a),
  getLote:     (...a) => api.getLote(...a),
  getSala:     (...a) => api.getSala(...a),
}))

import { usePacientesStore } from '../stores/pacientes'
import { useUsuariosStore } from '../stores/usuarios'
import { usePlantsStore } from '../stores/plants'
import { useLotesStore } from '../stores/lotes'
import { useSalasStore } from '../stores/salas'

// Un pedido que se resuelve cuando la prueba quiere.
function diferido () {
  let resolver
  const promesa = new Promise((r) => { resolver = r })
  return { promesa, resolver }
}

const FICHAS = [
  { nombre: 'paciente', store: usePacientesStore, pedir: 'getPaciente', cargar: (s, id) => s.fetchOne(id), actual: (s) => s.current, respuesta: (d) => ({ data: { data: d } }) },
  { nombre: 'usuario',  store: useUsuariosStore,  pedir: 'getUser',     cargar: (s, id) => s.fetchOne(id), actual: (s) => s.current, respuesta: (d) => ({ data: d }) },
  { nombre: 'planta',   store: usePlantsStore,    pedir: 'getPlant',    cargar: (s, id) => s.fetchOne(id), actual: (s) => s.current, respuesta: (d) => ({ data: d }) },
  { nombre: 'lote',     store: useLotesStore,     pedir: 'getLote',     cargar: (s, id) => s.fetchOne(id), actual: (s) => s.current, respuesta: (d) => ({ data: d }) },
  { nombre: 'sala',     store: useSalasStore,     pedir: 'getSala',     cargar: (s, id) => s.fetchSala(id), actual: (s) => s.currentSala, respuesta: (d) => ({ data: d }) },
]

beforeEach(() => {
  setActivePinia(createPinia())
  Object.values(api).forEach((f) => f.mockReset())
})

describe.each(FICHAS)('La ficha de $nombre al recargar', (f) => {
  async function abierta (id = 7) {
    const s = f.store()
    api[f.pedir].mockResolvedValueOnce(f.respuesta({ id, nombre: 'antes' }))
    await f.cargar(s, id)
    return s
  }

  it('recargar la misma no la vacía ni muestra «cargando» mientras viaja el pedido', async () => {
    const s = await abierta(7)
    const d = diferido()
    api[f.pedir].mockReturnValueOnce(d.promesa)

    const recarga = f.cargar(s, 7)
    expect(f.actual(s)).toMatchObject({ id: 7, nombre: 'antes' })
    expect(s.loading).toBe(false)

    d.resolver(f.respuesta({ id: 7, nombre: 'después' }))
    await recarga
    expect(f.actual(s)).toMatchObject({ id: 7, nombre: 'después' })
    expect(s.loading).toBe(false)
  })

  it('abrir otra ficha sí arranca vacía y cargando', async () => {
    const s = await abierta(7)
    const d = diferido()
    api[f.pedir].mockReturnValueOnce(d.promesa)

    const otra = f.cargar(s, 8)
    expect(f.actual(s)).toBeNull()
    expect(s.loading).toBe(true)

    d.resolver(f.respuesta({ id: 8, nombre: 'otra' }))
    await otra
    expect(f.actual(s)).toMatchObject({ id: 8 })
    expect(s.loading).toBe(false)
  })

  it('si las respuestas llegan desordenadas, queda la del último pedido', async () => {
    const s = await abierta(7)
    const vieja = diferido()
    const nueva = diferido()
    api[f.pedir].mockReturnValueOnce(vieja.promesa).mockReturnValueOnce(nueva.promesa)

    const p1 = f.cargar(s, 8)
    const p2 = f.cargar(s, 9)
    nueva.resolver(f.respuesta({ id: 9 }))
    await p2
    vieja.resolver(f.respuesta({ id: 8 }))
    await p1
    expect(f.actual(s)).toMatchObject({ id: 9 })
    expect(s.loading).toBe(false)
  })
})

describe('Dispensar desde el teléfono', () => {
  // La pantalla escuchaba `created` y el modal avisa con `saved`: la lista no se refrescaba.
  // Se cruzan las dos fuentes reales, no una lista de memoria.
  it('escucha el aviso que el modal de la dispensa efectivamente emite', () => {
    const leer = (p) => readFileSync(resolve(__dirname, '..', p), 'utf8')
    const modal = leer('components/pacientes/ModalNuevaDispensacion.vue')
    const vista = leer('views/mobile/MDispensarView.vue')
    const emite = modal.match(/defineEmits\(\[([^\]]*)\]\)/)[1]
    const escucha = vista.match(/<ModalNuevaDispensacion[\s\S]*?\/>/)[0].match(/@([\w-]+)=/g).map((e) => e.slice(1, -1))
    expect(escucha).toContain('saved')
    for (const ev of escucha) expect(emite).toContain(`'${ev}'`)
  })
})
