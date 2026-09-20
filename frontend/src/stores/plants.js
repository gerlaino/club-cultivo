import { logger } from '../utils/logger.js'
import { defineStore } from "pinia";
import { listPlants, getPlant } from "../lib/api";

export const usePlantsStore = defineStore("plants", {
  state: () => ({
    itemsByLote: {},
    current: null,
    loading: false,
    error: null,
  }),
  getters: {
    byLote: (state) => (loteId) =>
      state.itemsByLote[String(loteId)] || [],
  },
  actions: {
    async fetchByLote(loteId, { silencioso = false } = {}) {
      if (!silencioso) { this.loading = true; this.error = null; }
      try {
        const { data } = await listPlants({ lote_id: loteId });
        this.itemsByLote[String(loteId)] = data || [];
      } catch (e) {
        logger.error("Plants.fetchByLote", e);
        this.error = e?.response?.data?.error || e.message;
      } finally {
        this.loading = false;
      }
    },
    // Refresco por cable: sólo los lotes cuyas plantas ya se pidieron, sin spinner.
    async refrescar(evento) {
      const lotes = Object.keys(this.itemsByLote);
      await Promise.all(lotes.map(l => this.fetchByLote(l, { silencioso: true })));
      if (this.current?.id && (!evento?.id || evento.id === this.current.id)) {
        try { this.current = (await getPlant(this.current.id)).data; } catch {}
      }
    },

    async fetchOne(id) {
      this.loading = true; this.error = null; this.current = null;
      try {
        const { data } = await getPlant(id);
        this.current = data;
        return data;
      } catch (e) {
        logger.error("Plants.fetchOne", e);
        this.error = e?.response?.data?.error || e.message;
        throw e;
      } finally {
        this.loading = false;
      }
    },
    addToLote(loteId, planta) {
      const arr = this.itemsByLote[String(loteId)] || [];
      this.itemsByLote[String(loteId)] = [...arr, planta];
    },
  },
});
