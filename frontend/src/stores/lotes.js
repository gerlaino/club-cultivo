import { defineStore } from "pinia"
import { listLotes, createLote } from "../lib/api"

export const useLotesStore = defineStore("lotes", {
  state: () => ({ items: [], loading: false, error: null }),
  actions: {
    async fetchAll() {
      this.loading = true; this.error = null
      try { const { data } = await listLotes(); this.items = data }
      catch (e) { this.error = "No se pudieron cargar los lotes" }
      finally { this.loading = false }
    },
    async create(payload) {
      await createLote(payload); await this.fetchAll()
    }
  }
})
