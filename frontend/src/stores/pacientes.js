import { defineStore } from "pinia"
import {
  listPacientes, getPaciente, createPaciente, updatePaciente, deletePaciente,
  listPacienteNotas, createPacienteNota, deletePacienteNota
} from "../lib/api"

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

    async fetchOne(id) {
      this.loading = true; this.error = null; this.current = null
      try {
        const { data } = await getPaciente(id)
        this.current = data?.data || data
        return this.current
      } catch (e) {
        this.error = e?.response?.data?.error || e.message
        throw e
      } finally {
        this.loading = false
      }
    },

    // Devuelve `{ paciente, aviso }`. El `aviso` es para lo que salió distinto de lo pedido sin
    // que el alta falle — típicamente que el mail de bienvenida no pudo salir. El paciente se
    // creó igual, así que no es un error: es algo que el usuario tiene que saber.
    async create(payload, { enviarBienvenida = false } = {}) {
      this.saving = true; this.error = null
      try {
        const { data } = await createPaciente(payload, { enviarBienvenida })
        const paciente = data?.data || data
        this.items = [paciente, ...this.items]
        return { paciente, aviso: data?.aviso || null }
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
