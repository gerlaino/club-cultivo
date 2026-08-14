import { describe, it, expect } from 'vitest'
import { mensajeDeErrorDeLogin } from '../stores/auth.js'

// AC (Germán): "si hay error de login, mostrar el error claro".
//
// El síntoma reportado fue un botón con spinner y NINGÚN texto. Dos causas: el reintento
// automático borraba el mensaje anterior mientras esperaba, y el caso final caía en `e.message`,
// que para un timeout de axios es "timeout of 10000ms exceeded" — el texto interno de una
// librería, en inglés, mostrado como explicación.
describe('mensajeDeErrorDeLogin', () => {
  // La regla que hay que sostener: pase lo que pase, hay un texto.
  it('nunca devuelve vacío, ni con un error que no tiene nada adentro', () => {
    for (const e of [undefined, null, {}, new Error(''), { response: {} }]) {
      expect(mensajeDeErrorDeLogin(e)).toBeTruthy()
    }
  })

  it('credenciales equivocadas lo dicen sin rodeos', () => {
    expect(mensajeDeErrorDeLogin({ response: { status: 401 } })).toMatch(/contraseña incorrectos/i)
  })

  // Usuario y contraseña estaban bien: lo que falta es el módulo del que vive su rol. El backend
  // nombra cuál, así que ese mensaje se muestra tal cual — es el único que sabe la respuesta.
  it('con el módulo del rol apagado muestra la explicación del backend', () => {
    const e = { response: { status: 403, data: { modulo_rol_apagado: true, error: 'Tu organización no tiene activo el módulo Cultivo.' } } }

    expect(mensajeDeErrorDeLogin(e)).toBe('Tu organización no tiene activo el módulo Cultivo.')
  })

  it('lo mismo con la organización suspendida', () => {
    const e = { response: { status: 403, data: { club_suspendido: true, error: 'Esta organización está suspendida.' } } }

    expect(mensajeDeErrorDeLogin(e)).toBe('Esta organización está suspendida.')
  })

  it('un 500 no le echa la culpa al usuario', () => {
    expect(mensajeDeErrorDeLogin({ response: { status: 500 } })).toMatch(/servidor/i)
  })

  // El caso que dejó la pantalla muda.
  describe('cuando no hubo respuesta', () => {
    it('un timeout no muestra el texto interno de axios', () => {
      const msg = mensajeDeErrorDeLogin({ code: 'ECONNABORTED', message: 'timeout of 10000ms exceeded' })

      expect(msg).not.toMatch(/timeout of/i)
      expect(msg).toMatch(/tardando en responder/i)
    })

    // Sin conexión y servidor lento son cosas distintas: lo que hay que hacer es distinto.
    it('sin conexión se distingue de un servidor lento', () => {
      const sinRed = mensajeDeErrorDeLogin({ message: 'Network Error' })

      expect(sinRed).toMatch(/conexión/i)
      expect(sinRed).not.toEqual(mensajeDeErrorDeLogin({ code: 'ECONNABORTED', message: 'timeout' }))
    })
  })
})
