import { describe, it, expect } from 'vitest'
import { iniciarSentry, limpiarEvento, limpiarMiga } from '../lib/sentry.js'

// AC (pendiente «Sentry front», 26-oct-2026): los errores del navegador llegan a Sentry SÓLO si el
// build trae el DSN, y nunca sale un dato de la persona: ni DNI, ni mail, ni lo que se buscó en la
// dirección, ni lo que se imprimió en la consola, ni el usuario. Mismo criterio que el backend.

describe('Sentry del navegador', () => {
  it('sin DSN queda apagado y no baja la librería', async () => {
    expect(await iniciarSentry({}, {}, { MODE: 'production' })).toBe(false)
  })

  it('un error que trae un DNI o un mail en el mensaje sale sin ellos', () => {
    const ev = limpiarEvento({
      message: 'No se encontró 30.123.456',
      exception: { values: [{ value: 'paciente juana.perez@gmail.com con DNI 30123456 no existe' }] },
    })
    expect(ev.message).not.toMatch(/30\.123\.456/)
    expect(ev.exception.values[0].value).not.toMatch(/juana|30123456/)
  })

  it('la dirección viaja sin lo que se buscó, y el usuario no viaja', () => {
    const ev = limpiarEvento({
      user: { id: 7, email: 'a@b.com' },
      request: { url: 'https://cultivoespacial.com/socios?q=30123456#x', query_string: 'q=30123456', cookies: 'jwt_token=x',
                 headers: { Referer: 'https://cultivoespacial.com/socios?q=30123456', 'User-Agent': 'x' } },
    })
    expect(JSON.stringify(ev)).not.toMatch(/30123456/)
    expect(ev.request.headers['User-Agent']).toBe('x')
    expect(ev.user).toBeUndefined()
    expect(ev.request.url).toBe('https://cultivoespacial.com/socios')
    expect(ev.request.query_string).toBeUndefined()
    expect(ev.request.cookies).toBeUndefined()
  })

  it('lo que pidió a la API queda sin la consulta, y la consola no sale', () => {
    expect(limpiarMiga({ category: 'console', message: '{dni: 30123456}' })).toBeNull()
    const pedido = limpiarMiga({ category: 'xhr', data: { url: '/api/socios/buscar?dni=30123456', method: 'GET' } })
    expect(pedido.data.url).toBe('/api/socios/buscar')
    const nav = limpiarMiga({ category: 'navigation', data: { from: '/socios?q=perez', to: '/socios/12' } })
    expect(nav.data.from).toBe('/socios')

    const ev = limpiarEvento({ breadcrumbs: [{ category: 'console', message: 'x' }, { category: 'xhr', data: { url: '/api/x?dni=1' } }] })
    expect(ev.breadcrumbs).toEqual([{ category: 'xhr', data: { url: '/api/x' } }])
  })

  it('las mediciones de rendimiento tampoco llevan lo que se buscó', () => {
    const tr = limpiarEvento({ spans: [
      { description: 'GET /api/pacientes?query=30123456', data: { 'http.url': '/api/pacientes?query=30123456', 'url.full': 'http://x/api/pacientes?query=30123456', 'http.query': '?query=30123456' } },
    ] })
    expect(JSON.stringify(tr)).not.toMatch(/30123456/)
    expect(tr.spans[0].description).toBe('GET /api/pacientes')
  })
})
