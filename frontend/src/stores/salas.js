import { defineStore } from "pinia"
import { listSalas, createSala } from "../lib/api"

export const useSalasStore = defineStore("salas", {
  state: () => ({ items: [], loading: false, error: null }),
  actions: {
    async fetchAll() {
      this.loading = true; this.error = null
      try { const { data } = await listSalas(); this.items = data }
      catch (e) { this.error = "No se pudieron cargar las salas" }
      finally { this.loading = false }
    },
    async create(payload) {
      await createSala(payload); await this.fetchAll()
    }
  }
})
