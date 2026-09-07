import { describe, it, expect, vi } from 'vitest'

// UNA RESPUESTA DE ERROR, UNA SOLA FORMA DE LEERLA.
//
// El backend contesta a veces `{ error: "…" }` y a veces `{ errors: [...] }` —las validaciones de
// modelo, con `full_messages`—, y en las pantallas conviven las dos lecturas: 219 leen
// `data.error` y 42 leen `data.errors[0]`. Las que leen sólo `error` se COMÍAN el motivo y
// mostraban un "no se pudo" pelado, que es el peor mensaje posible: la persona no sabe si es la
// caja, el stock o la fecha, y no tiene qué hacer con eso.
//
// Pasó al entregar una reserva desde el teléfono: el backend decía "La caja del mostrador está
// cerrada: contá y abrila antes de dispensar" y en pantalla se leía "No se pudo entregar".
//
// Se normaliza en el interceptor y no en cada pantalla: son doscientos lugares, y la que se
// agregue mañana nace bien.

vi.mock('../utils/reloadTrace.js', () => ({ anotarReload: vi.fn(), leerReloads: () => [] }))

// El interceptor de errores, tal como lo registra `api.js`.
async function interceptorDeError () {
  const registrados = []
  vi.doMock('axios', () => ({
    default: {
      create: () => ({
        interceptors: {
          request:  { use: () => {} },
          response: { use: (_ok, fallo) => registrados.push(fallo) },
        },
        get: vi.fn(), post: vi.fn(), put: vi.fn(), patch: vi.fn(), delete: vi.fn(),
      }),
    },
  }))
  vi.resetModules()
  await import('../lib/api.js')
  return registrados[0]
}

async function pasarPor (data, status = 422) {
  const alFallar = await interceptorDeError()
  const error = { response: { status, data }, config: { url: '/reservas/7/entregar' } }
  await alFallar(error).catch(() => {})
  return error.response.data
}

describe('El motivo del rechazo llega a la pantalla', () => {
  it('con `errors` del backend, queda legible en `error`', async () => {
    const data = await pasarPor({ errors: ['La caja del mostrador está cerrada: contá y abrila antes de dispensar.'] })

    expect(data.error).toContain('caja del mostrador está cerrada')
  })

  it('con varias validaciones, se leen todas', async () => {
    const data = await pasarPor({ errors: ['Falta el stock', 'Crédito insuficiente'] })

    expect(data.error).toContain('Falta el stock')
    expect(data.error).toContain('Crédito insuficiente')
  })

  it('y si ya venía `error`, no se pisa', async () => {
    const data = await pasarPor({ error: 'La reserva no está pendiente', errors: ['otra cosa'] })

    expect(data.error).toBe('La reserva no está pendiente')
  })

  it('sin cuerpo no explota', async () => {
    const alFallar = await interceptorDeError()
    await expect(alFallar({ response: { status: 500 }, config: {} }).catch(e => e)).resolves.toBeTruthy()
  })
})
