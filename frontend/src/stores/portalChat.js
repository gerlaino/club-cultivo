// El chat del paciente con su organización (27-oct-2026). Un store y no estado de la pantalla
// porque lo leen dos lugares: la pantalla del chat y el botón flotante con los «sin leer», que
// vive en todo el portal.
//
// En vivo por `PacienteChannel` (recurso `mensajes`): un mensaje nuevo, «leído» o «está
// escribiendo». El aviso no trae datos: se re-pide la conversación.
import { defineStore } from 'pinia'
import { getPortalMensajes, enviarPortalMensaje, marcarPortalMensajesLeidos } from '../lib/portalApi'
import { alCambiar, avisarAlCanal } from '../lib/cambios.js'

let timerEscribiendo = null

export const usePortalChatStore = defineStore('portalChat', {
  state: () => ({
    mensajes: [],
    conversacion: {},
    sinLeer: 0,
    // «Javier está escribiendo…» (o null). Se apaga solo a los 5 s sin otro aviso.
    escribiendo: null,
    cargado: false,
    cargando: false,
    enviando: false,
    error: null,
    // La pantalla del chat está abierta: lo que llega se marca leído en el acto.
    abierto: false,
  }),
  actions: {
    escuchar() {
      // Una vez por store (y el store es uno por sesión: cerrar sesión recarga la página).
      if (this._soltar) return
      this._soltar = alCambiar('mensajes', (ev) => {
        if (ev?.accion === 'escribiendo') {
          this.escribiendo = `${ev.por || 'La organización'} está escribiendo…`
          clearTimeout(timerEscribiendo)
          timerEscribiendo = setTimeout(() => { this.escribiendo = null }, 5000)
          return
        }
        if (ev?.accion === 'creado') this.escribiendo = null
        this.cargar({ silencioso: true })
      })
    },

    async cargar({ silencioso = false } = {}) {
      if (!silencioso) this.cargando = true
      try {
        const r = await getPortalMensajes()
        this.mensajes = r.data || []
        this.conversacion = r.conversacion || {}
        this.sinLeer = r.sin_leer || 0
        this.cargado = true
        this.error = null
        if (this.abierto && this.sinLeer > 0) await this.marcarLeidos()
      } catch (e) {
        if (!silencioso) this.error = 'No pudimos traer tus mensajes. Probá de nuevo en un rato.'
      } finally {
        this.cargando = false
      }
    },

    async enviar({ texto, archivo, dispensacionId }) {
      this.enviando = true
      try {
        const m = await enviarPortalMensaje({ texto, archivo, dispensacionId })
        if (!this.mensajes.some((x) => x.id === m.id)) this.mensajes.push(m)
        return m
      } finally {
        this.enviando = false
      }
    },

    async marcarLeidos() {
      if (this.sinLeer === 0) return
      this.sinLeer = 0
      try { await marcarPortalMensajesLeidos() } catch { /* se marca la próxima vez */ }
    },

    avisarQueEscribo() { avisarAlCanal('escribiendo') },
  },
})
