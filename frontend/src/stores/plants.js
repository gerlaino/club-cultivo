import { defineStore } from "pinia";
import { listPlants, getPlant } from "../lib/api";

export const usePlantsStore = defineStore("plants", {
  state: () => ({
    itemsByLote: new Map(),
    current: null,
    loading: false,
    error: null,
  }),
  getters: {
    byLote: (state) => (loteId) =>
      state.itemsByLote.get(String(loteId)) || [],
  },
  actions: {
    async fetchByLote(loteId) {
      this.loading = true; this.error = null;
      try {
        const { data } = await listPlants({ lote_id: loteId });
        this.itemsByLote.set(String(loteId), data || []);
      } catch (e) {
        console.error("Plants.fetchByLote", e);
        this.error = e?.response?.data?.error || e.message;
      } finally {
        this.loading = false;
      }
    },
    async fetchOne(id) {
      this.loading = true; this.error = null; this.current = null;
      try {
        const { data } = await getPlant(id);
        this.current = data;
        return data;
      } catch (e) {
        console.error("Plants.fetchOne", e);
        this.error = e?.response?.data?.error || e.message;
        throw e;
      } finally {
        this.loading = false;
      }
    },
    addToLote(loteId, planta) {
      const arr = this.itemsByLote.get(String(loteId)) || [];
      this.itemsByLote.set(String(loteId), [...arr, planta]);
    },
  },
});
