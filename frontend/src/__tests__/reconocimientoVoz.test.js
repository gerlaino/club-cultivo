import { describe, it, expect, beforeEach, vi } from 'vitest'
import { useReconocimientoVoz } from '../composables/useReconocimientoVoz.js'

// Reporte de Germán: "quise registrar por voz desde la PWA como admin y me tira error, como que
// no me escucha" → el cartel era siempre "No escuché nada. Intentá de nuevo.".
//
// Los tests afirman lo que la persona necesita que pase, no cómo está resuelto: que el motivo
// real llegue a la pantalla, que lo dicho no se pierda, y que en el teléfono se pueda hablar más
// de una frase.

// Doble del motor del navegador. Sólo guarda los handlers y deja disparar los eventos a mano:
// el que decide qué pasa es el composable.
class MotorFalso {
  static ultima = null
  static creadas = 0
  constructor() {
    this.lang = ''; this.continuous = false; this.interimResults = false
    this.arranques = 0; this.detenido = false; this.abortado = false
    MotorFalso.ultima = this
    MotorFalso.creadas++
  }
  start()  { this.arranques++ }
  stop()   { this.detenido = true }
  abort()  { this.abortado = true }

  // Atajos para escribir los ejemplos como se leen.
  emitirInicio()          { this.onstart?.() }
  emitirError(codigo)     { this.onerror?.({ error: codigo }) }
  emitirFin()             { this.onend?.() }
  emitirTexto(txt, final = true) {
    this.onresult?.({ results: [Object.assign([{ transcript: txt }], { isFinal: final })] })
  }
}

function montarNavegador({ movil = false, permiso = true } = {}) {
  window.SpeechRecognition = MotorFalso
  window.webkitSpeechRecognition = MotorFalso
  Object.defineProperty(navigator, 'userAgent', {
    value: movil ? 'Mozilla/5.0 (Linux; Android 14)' : 'Mozilla/5.0 (X11; Linux x86_64)',
    configurable: true,
  })
  Object.defineProperty(navigator, 'mediaDevices', {
    value: {
      getUserMedia: permiso
        ? vi.fn().mockResolvedValue({ getTracks: () => [{ stop: vi.fn() }] })
        : vi.fn().mockRejectedValue(Object.assign(new Error('denied'), { name: 'NotAllowedError' })),
    },
    configurable: true,
  })
}

describe('useReconocimientoVoz', () => {
  beforeEach(() => { MotorFalso.ultima = null; MotorFalso.creadas = 0; montarNavegador() })

  describe('un solo motor a la vez', () => {
    // El permiso se pide antes de arrancar, así que entre el toque y el `onstart` pasa un rato
    // con el botón todavía apretable. Dos toques dejaban una instancia huérfana pero viva, y su
    // `onend` terminaba pisando el dictado nuevo con lo dictado antes.
    it('dos toques seguidos no levantan dos motores', async () => {
      const voz = useReconocimientoVoz()

      const primero = voz.iniciar()   // sin await: el segundo llega mientras espera el permiso
      const segundo = voz.iniciar()

      expect(await primero).toBe(true)
      expect(await segundo).toBe(false)
      expect(MotorFalso.creadas).toBe(1)
    })

    // La contracara: una vez que la sesión cerró, el botón tiene que volver a servir.
    it('terminada una grabación se puede arrancar otra', async () => {
      const voz = useReconocimientoVoz()
      await voz.iniciar()
      MotorFalso.ultima.emitirInicio()
      MotorFalso.ultima.emitirTexto('regué el lote')
      voz.detener()
      MotorFalso.ultima.emitirFin()

      expect(await voz.iniciar()).toBe(true)
      expect(MotorFalso.creadas).toBe(2)
    })
  })

  describe('cuando no sale texto, dice por qué', () => {
    // El bug de fondo: el error real se pisaba con "No escuché nada", así que las tres causas
    // (permiso, servicio bloqueado, sin internet) se veían idénticas y ninguna decía qué hacer.
    it('el servicio bloqueado de la PWA no se confunde con silencio', async () => {
      const voz = useReconocimientoVoz()
      await voz.iniciar()

      MotorFalso.ultima.emitirInicio()
      MotorFalso.ultima.emitirError('service-not-allowed')
      voz.detener()
      MotorFalso.ultima.emitirFin()

      expect(voz.error.value).toMatch(/bloqueó el dictado/i)
      expect(voz.error.value).not.toMatch(/no escuché nada/i)
    })

    it('sin internet lo dice, porque el dictado es un servicio remoto', async () => {
      const voz = useReconocimientoVoz()
      await voz.iniciar()

      MotorFalso.ultima.emitirInicio()
      MotorFalso.ultima.emitirError('network')
      voz.detener()
      MotorFalso.ultima.emitirFin()

      expect(voz.error.value).toMatch(/internet/i)
    })

    // El permiso se pide con getUserMedia ANTES de dictar: en la PWA instalada el motor no
    // siempre muestra el cartel y falla en silencio.
    it('el permiso denegado se detecta antes de arrancar el motor', async () => {
      montarNavegador({ permiso: false })
      const voz = useReconocimientoVoz()

      const ok = await voz.iniciar()

      expect(ok).toBe(false)
      expect(voz.error.value).toMatch(/permiso de micrófono/i)
      expect(MotorFalso.ultima).toBeNull()   // ni se instanció
    })

    // Sólo cuando de verdad escuchó y no hubo nada.
    it('el silencio real sí dice que no te escuchó', async () => {
      const voz = useReconocimientoVoz()
      await voz.iniciar()

      MotorFalso.ultima.emitirInicio()
      voz.detener()
      MotorFalso.ultima.emitirFin()

      expect(voz.error.value).toMatch(/no te escuché/i)
    })

    // Tocar dos veces rápido no es un error de la persona.
    it('cortar antes de que el motor arranque no muestra ningún cartel', async () => {
      const voz = useReconocimientoVoz()
      await voz.iniciar()

      voz.detener()   // sin emitirInicio: el servicio nunca llegó a escuchar

      expect(voz.error.value).toBeNull()
    })
  })

  describe('lo que se dijo no se pierde', () => {
    // Se veía el texto en pantalla y el cartel decía "no escuché nada": `onresult` sólo guardaba
    // los tramos confirmados, y en frases cortas el último queda sin confirmar al cortar.
    it('el tramo que quedó sin confirmar cuenta igual', async () => {
      const alTerminar = vi.fn()
      const voz = useReconocimientoVoz({ alTerminar })
      await voz.iniciar()

      MotorFalso.ultima.emitirInicio()
      MotorFalso.ultima.emitirTexto('regué con EC uno ocho', false)  // interim, nunca final
      voz.detener()
      MotorFalso.ultima.emitirFin()

      // El segundo argumento es `porPedido`: acá la persona apretó "parar", así que lo dictado
      // está completo y quien llama puede mandarlo. Se afirma junto con el texto porque los dos
      // juntos son la decisión — el texto solo no dice si la frase terminó.
      expect(alTerminar).toHaveBeenCalledWith('regué con EC uno ocho', true)
      expect(voz.error.value).toBeNull()
    })
  })

  describe('en el teléfono', () => {
    // Chrome Android cierra la sesión en CADA pausa. Sin relevantar, todo lo dicho después de la
    // primera coma se perdía sin aviso: quedaba registrada la primera frase y nada más.
    it('se puede hablar más de una frase: la sesión se relevanta sola', async () => {
      montarNavegador({ movil: true })
      const alTerminar = vi.fn()
      const voz = useReconocimientoVoz({ alTerminar })
      await voz.iniciar()
      const motor = MotorFalso.ultima

      expect(motor.continuous).toBe(false)

      motor.emitirInicio()
      motor.emitirTexto('regué el lote')
      motor.emitirFin()                 // pausa: el servicio corta solo

      expect(motor.arranques).toBe(2)   // volvió a levantar
      expect(alTerminar).not.toHaveBeenCalled()

      motor.emitirInicio()
      motor.emitirTexto('con EC uno ocho')
      voz.detener()
      motor.emitirFin()

      expect(alTerminar).toHaveBeenCalledWith('regué el lote con EC uno ocho', true)
    })

    // Una pausa larga pensando qué decir tampoco tiene que cortar la sesión.
    it('una pausa de silencio no termina la grabación', async () => {
      montarNavegador({ movil: true })
      const voz = useReconocimientoVoz()
      await voz.iniciar()
      const motor = MotorFalso.ultima

      motor.emitirInicio()
      motor.emitirTexto('regué el lote')
      motor.emitirError('no-speech')
      motor.emitirFin()

      expect(motor.arranques).toBe(2)
      expect(voz.escuchando.value).toBe(true)
    })

    // Si el servicio cortara al instante una y otra vez, sin tope quedaría girando.
    it('el relevantado tiene tope y no queda en bucle', async () => {
      montarNavegador({ movil: true })
      const voz = useReconocimientoVoz()
      await voz.iniciar()
      const motor = MotorFalso.ultima

      motor.emitirInicio()
      for (let i = 0; i < 40; i++) motor.emitirFin()

      expect(motor.arranques).toBeLessThanOrEqual(9)   // 1 inicial + 8 de tope
      expect(voz.escuchando.value).toBe(false)
    })
  })
})
