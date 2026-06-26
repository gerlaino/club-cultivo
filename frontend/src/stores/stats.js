import { defineStore } from 'pinia'
import api from '../lib/api.js'

export const useStatsStore = defineStore('stats', {
  state: () => ({
    loading: false,
    error:   null,
    data:    null, // respuesta cruda del servidor
  }),

  getters: {
    // ── Plantas ─────────────────────────────────────────────
    plantasActivas: (s) => s.data?.plantas ?? 0,
    plantasPorFase: (s) => ({
      germinacion: s.data?.germinacion ?? 0,
      vegetativo:  s.data?.vegetativo  ?? 0,
      floracion:   s.data?.floracion   ?? 0,
    }),
    plantasPorGenetica: (s) => s.data?.plantas_por_genetica ?? [],
    plantasPorLote:     (s) => s.data?.plantas_por_lote     ?? {},
    plantasPorSede:     (s) => s.data?.plantas_por_sede     ?? [],

    // ── Pacientes ───────────────────────────────────────────
    reprocannVencidos:   (s) => s.data?.reprocann_vencidos   ?? s.data?.vencimientos ?? 0,
    reprocannPorVencer:  (s) => s.data?.reprocann_por_vencer ?? 0,
    totalPacientes:      (s) => s.data?.pacientes ?? s.data?.socios ?? 0,

    // ── Salas y lotes ───────────────────────────────────────
    totalSalas:  (s) => s.data?.salas  ?? 0,
    totalLotes:  (s) => s.data?.lotes  ?? 0,
    salasOcupacion: (s) => s.data?.salas_ocupacion ?? [],
  },

  actions: {
    async fetchAll() {
      if (this.loading) return
      this.loading = true
      this.error   = null
      try {
        const { data } = await api.get('/stats')
        this.data = data
      } catch {
        this.error = 'No se pudieron cargar las estadísticas'
      } finally {
        this.loading = false
      }
    },

    // Ocupación de una sala específica
    getOcupacionSala(salaId) {
      const found = (this.data?.salas_ocupacion ?? []).find(s => s.sala_id === salaId)
      if (found) return found
      return { sala_id: salaId, plants_count: 0, capacidad: 0, porcentaje: 0, inconsistente: false }
    },

    // Plantas activas filtradas (calcula del estado local)
    getPlantasActivas({ sedeId, salaId, loteId, fase } = {}) {
      if (loteId) {
        return this.plantasPorLote[loteId] ?? 0
      }
      if (sedeId) {
        const found = this.plantasPorSede.find(s => s.sede_id === sedeId)
        return found?.plantas_count ?? 0
      }
      if (salaId) {
        return this.getOcupacionSala(salaId).plants_count
      }
      if (fase) {
        return this.plantasPorFase[fase] ?? 0
      }
      return this.plantasActivas
    },

    // Forzar recarga (para después de crear/borrar plantas)
    invalidate() {
      this.data = null
    },
  },
})
