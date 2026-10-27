// El chat con los pacientes, del lado de la organización (27-oct-2026): la bandeja, cuántas
// esperan respuesta (el contador del menú) y la alerta de «mensaje nuevo». Lo leen la bandeja,
// la solapa Chat de la ficha, el menú (compu y teléfono) y la alerta, que vive en toda la app.
//
// En vivo por `ClubChannel` (recurso `mensajes`, `id` = el paciente): un mensaje nuevo, «leído»
// o «está escribiendo». Sin datos en el aviso: se re-pide la bandeja.
import { defineStore } from 'pinia'
import { listChatPacientes } from '../lib/api'
import { alCambiar } from '../lib/cambios.js'

const timersEscribiendo = {}

export const useChatPacientesStore = defineStore('chatPacientes', {
  state: () => ({
    bandeja: [],
    sinResponder: 0,
    cargado: false,
    // { pacienteId: true } mientras ese paciente está escribiendo.
    escribiendo: {},
    // La conversación que tiene abierta esta pantalla: lo que llega ahí no dispara la alerta.
    abiertoPacienteId: null,
    // { pacienteId, nombre, texto } — el mensaje nuevo que todavía no se miró.
    alerta: null,
    // Las pantallas abiertas se anotan acá para re-pedir su conversación cuando cambia.
    version: 0,
    ultimoEvento: null,
  }),
  actions: {
    escuchar() {
      // Una vez por store (y el store es uno por sesión: cerrar sesión recarga la página).
      if (this._soltar) return
      this._soltar = alCambiar('mensajes', (ev) => {
        const id = ev?.id
        if (ev?.accion === 'escribiendo') {
          this.escribiendo = { ...this.escribiendo, [id]: true }
          clearTimeout(timersEscribiendo[id])
          timersEscribiendo[id] = setTimeout(() => { this.escribiendo = { ...this.escribiendo, [id]: false } }, 5000)
          return
        }
        if (ev?.accion === 'creado') this.escribiendo = { ...this.escribiendo, [id]: false }
        this.ultimoEvento = ev
        this.version++
        this.refrescar(ev)
      })
    },

    async cargar(params = {}) {
      try {
        const { data } = await listChatPacientes(params)
        this.bandeja = data.data || []
        this.sinResponder = data.sin_responder || 0
        this.cargado = true
      } catch { /* sin permiso o sin módulo: el contador queda en cero */ }
    },

    // Re-pide la bandeja y, si lo nuevo es un mensaje del paciente que esta pantalla no tiene
    // abierto, levanta la alerta con su nombre y lo que escribió.
    async refrescar(ev) {
      const antes = Object.fromEntries(this.bandeja.map((c) => [c.paciente.id, c.ultimo?.at]))
      await this.cargar()
      if (ev?.accion !== 'creado' || ev.id === this.abiertoPacienteId) return
      const fila = this.bandeja.find((c) => c.paciente.id === ev.id)
      if (!fila || fila.ultimo?.autor !== 'paciente' || antes[ev.id] === fila.ultimo?.at) return
      this.alerta = {
        pacienteId: fila.paciente.id,
        nombre: `${fila.paciente.nombre} ${fila.paciente.apellido || ''}`.trim(),
        texto: fila.ultimo?.texto || '',
      }
    },

    cerrarAlerta() { this.alerta = null },
  },
})
