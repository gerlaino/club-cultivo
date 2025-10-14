// src/stores/socios.js
import { defineStore } from "pinia"
import {
  listSocios, getSocio, createSocio, updateSocio, deleteSocio,
  listSocioNotas, createSocioNota, deleteSocioNota
} from "../lib/api"

export const useSociosStore = defineStore("socios", {
  state: () => ({
    items: [],
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
        const { data } = await listSocios(params)
        this.items = data?.data || data || []   // por si tu backend responde {data: []}
      } catch (e) {
        this.error = e?.response?.data?.error || e.message
      } finally {
        this.loading = false
      }
    },

    async fetchOne(id) {
      this.loading = true; this.error = null; this.current = null
      try {
        const { data } = await getSocio(id)
        this.current = data?.data || data
        return this.current
      } catch (e) {
        this.error = e?.response?.data?.error || e.message
        throw e
      } finally {
        this.loading = false
      }
    },

    async create(payload) {
      this.saving = true; this.error = null
      try {
        const { data } = await createSocio(payload)
        const socio = data?.data || data
        this.items = [socio, ...this.items]
        return socio
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
        const { data } = await updateSocio(id, payload)
        const socio = data?.data || data
        this.items = this.items.map(s => (s.id === id ? socio : s))
        if (this.current?.id === id) this.current = socio
        return socio
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
        await deleteSocio(id)
        this.items = this.items.filter(s => s.id !== id)
        if (this.current?.id === id) this.current = null
      } catch (e) {
        this.error = e?.response?.data?.errors?.join(", ") || e.message
        throw e
      } finally {
        this.removing = false
      }
    },

    // --- Notas ---
    async fetchNotas(socioId) {
      this.notasLoading = true; this.notasError = null
      try {
        const { data } = await listSocioNotas(socioId)
        this.notas = data?.data || data || []
      } catch (e) {
        this.notasError = e?.response?.data?.error || e.message
      } finally {
        this.notasLoading = false
      }
    },

    async addNota(socioId, contenido) {
      this.creandoNota = true; this.notasError = null
      try {
        const { data } = await createSocioNota(socioId, contenido)
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
        await deleteSocioNota(notaId)
        this.notas = this.notas.filter(n => n.id !== notaId)
      } catch (e) {
        this.notasError = e?.response?.data?.errors?.join(", ") || e.message
        throw e
      }
    }
  }
})
