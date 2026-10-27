import { defineStore } from "pinia"
import {
  listPacientes, getPaciente, createPaciente, updatePaciente, deletePaciente,
  listPacienteNotas, createPacienteNota, deletePacienteNota
} from "../lib/api"

// El último `fetchOne` pedido: una respuesta que llega después de otra más nueva se descarta.
let ultimoPedido = null

export const usePacientesStore = defineStore("pacientes", {
  state: () => ({
    items: [],
    // Los contadores del padrón los calcula el backend sobre TODO el club. Antes se derivaban
    // de `items`, que es sólo la página cargada: un club de 38 mostraba "20 en la nómina".
    kpis: null,
    total: 0,
    current: null,
    loading: false,
    error: null,

    saving: false,
    removing: false,

    notas: [],
    notasLoading: false,
    notasError: null,
    creandoNota: false,
  }),

  getters: {
    byId: (s) => (id) => s.items.find(x => String(x.id) === String(id)) || null,
  },

  actions: {
    async fetch(params = {}) {
      this.loading = true; this.error = null
      try {
        const { data } = await listPacientes(params)
        this.items = data?.data || data || []
        this.kpis  = data?.meta?.kpis || null
        this.total = data?.meta?.total ?? this.items.length
      } catch (e) {
        this.error = e?.response?.data?.error || e.message
      } finally {
        this.loading = false
      }
    },

    // Refrescos SILENCIOSOS, para cuando otra pantalla cambió algo (aviso en vivo de `pacientes`):
    // sin «cargando», sin vaciar lo que se ve y sin pisar el error de la carga de verdad.
    async refrescar(params = {}) {
      try {
        const { data } = await listPacientes(params)
        this.items = data?.data || data || []
        this.kpis  = data?.meta?.kpis || null
        this.total = data?.meta?.total ?? this.items.length
      } catch { /* la próxima carga lo intenta de nuevo */ }
    },

    async refrescarActual(id) {
      try {
        const { data } = await getPaciente(id)
        if (String(this.current?.id) === String(id)) this.current = data?.data || data
      } catch { /* idem */ }
    },

    // Recargar la MISMA ficha (después de guardar, o por un aviso) no la vacía: la pantalla
    // seguía mostrando «no encontrado» o la ruedita mientras viajaba el pedido, y rearmaba todas
    // sus solapas. Sólo cambiar de ficha la vacía. Y si llegan dos respuestas, gana la última.
    async fetchOne(id) {
      const mismo = String(this.current?.id) === String(id)
      if (!mismo) { this.loading = true; this.current = null }
      this.error = null
      const pedido = (ultimoPedido = {})
      try {
        const { data } = await getPaciente(id)
        if (pedido === ultimoPedido) this.current = data?.data || data
        return data?.data || data
      } catch (e) {
        if (pedido === ultimoPedido) this.error = e?.response?.data?.error || e.message
        throw e
      } finally {
        if (pedido === ultimoPedido) this.loading = false
      }
    },

    // Devuelve `{ paciente, aviso, acceso }`. El `aviso` es para lo que salió distinto de lo
    // pedido sin que el alta falle — típicamente que el mail de bienvenida no pudo salir. El
    // paciente se creó igual, así que no es un error: es algo que el usuario tiene que saber.
    // `acceso` trae la cuenta del portal recién creada (usuario y contraseña inicial), y sólo
    // viene si la organización tiene el módulo y el alta quedó aprobada.
    async create(payload, { enviarBienvenida = false, turno = null } = {}) {
      this.saving = true; this.error = null
      try {
        const { data } = await createPaciente(payload, { enviarBienvenida, turno })
        const paciente = data?.data || data
        this.items = [paciente, ...this.items]
        return { paciente, aviso: data?.aviso || null, acceso: data?.acceso || null }
      } catch (e) {
        this.error = e?.response?.data?.errors?.join(", ") || e.message
        throw e
      } finally {
        this.saving = false
      }
    },

    async update(id, payload) {
      this.saving = true; this.error = null
      try {
        const { data } = await updatePaciente(id, payload)
        const paciente = data?.data || data
        this.items = this.items.map(s => (s.id === id ? paciente : s))
        if (this.current?.id === id) this.current = paciente
        return paciente
      } catch (e) {
        this.error = e?.response?.data?.errors?.join(", ") || e.message
        throw e
      } finally {
        this.saving = false
      }
    },

    async remove(id) {
      this.removing = true; this.error = null
      try {
        await deletePaciente(id)
        this.items = this.items.filter(s => s.id !== id)
        if (this.current?.id === id) this.current = null
      } catch (e) {
        this.error = e?.response?.data?.errors?.join(", ") || e.message
        throw e
      } finally {
        this.removing = false
      }
    },

    async fetchNotas(pacienteId) {
      this.notasLoading = true; this.notasError = null
      try {
        const { data } = await listPacienteNotas(pacienteId)
        this.notas = data?.data || data || []
      } catch (e) {
        this.notasError = e?.response?.data?.error || e.message
      } finally {
        this.notasLoading = false
      }
    },

    async addNota(pacienteId, contenido) {
      this.creandoNota = true; this.notasError = null
      try {
        const { data } = await createPacienteNota(pacienteId, contenido)
        const nota = data?.data || data
        this.notas = [nota, ...this.notas]
        return nota
      } catch (e) {
        this.notasError = e?.response?.data?.errors?.join(", ") || e.message
        throw e
      } finally {
        this.creandoNota = false
      }
    },

    async removeNota(notaId) {
      this.notasError = null
      try {
        await deletePacienteNota(notaId)
        this.notas = this.notas.filter(n => n.id !== notaId)
      } catch (e) {
        this.notasError = e?.response?.data?.errors?.join(", ") || e.message
        throw e
      }
    }
  }
})
