import { defineStore } from "pinia";
import {
  listPlantsByLote,
  createPlantInLote,
  getPlant,
  updatePlant,
  deletePlant,
} from "../lib/api";

export const usePlantsStore = defineStore("plants", {
  state: () => ({
    itemsByLote: new Map(),  // loteId -> Plant[]
    current: null,           // detalle
    loading: false,
    error: null,
    creating: false,
    updating: false,
    removing: false,
  }),

  getters: {
    byLote: (state) => (loteId) =>
      state.itemsByLote.get(String(loteId)) || [],
  },

  actions: {
    async fetchByLote(loteId) {
      this.loading = true; this.error = null;
      try {
        const { data } = await listPlantsByLote(loteId);
        this.itemsByLote.set(String(loteId), data || []);
      } catch (e) {
        console.error("Plants.fetchByLote", e);
        this.error = e?.response?.data?.error || e.message;
      } finally {
        this.loading = false;
      }
    },

    async createInLote(loteId, payload) {
      this.creating = true; this.error = null;
      try {
        const { data } = await createPlantInLote(loteId, payload);
        const arr = this.byLote(loteId);
        this.itemsByLote.set(String(loteId), [data, ...arr]);
        return data;
      } catch (e) {
        this.error = e?.response?.data?.errors?.join(", ") || e.message;
        throw e;
      } finally {
        this.creating = false;
      }
    },

    async fetchOne(id) {
      this.loading = true; this.error = null; this.current = null;
      try {
        const { data } = await getPlant(id);
        this.current = data;
        return data;
      } catch (e) {
        this.error = e?.response?.data?.error || e.message;
        throw e;
      } finally {
        this.loading = false;
      }
    },

    async update(id, payload, loteId = null) {
      this.updating = true; this.error = null;
      try {
        const { data } = await updatePlant(id, payload);
        if (loteId) {
          const arr = this.byLote(loteId).map(p => (p.id === id ? data : p));
          this.itemsByLote.set(String(loteId), arr);
        }
        if (this.current?.id === id) this.current = data;
        return data;
      } catch (e) {
        this.error = e?.response?.data?.errors?.join(", ") || e.message;
        throw e;
      } finally {
        this.updating = false;
      }
    },

    async remove(id, loteId = null) {
      this.removing = true; this.error = null;
      try {
        await deletePlant(id);
        if (loteId) {
          const arr = this.byLote(loteId).filter(p => p.id !== id);
          this.itemsByLote.set(String(loteId), arr);
        }
        if (this.current?.id === id) this.current = null;
      } catch (e) {
        this.error = e?.response?.data?.errors?.join(", ") || e.message;
        throw e;
      } finally {
        this.removing = false;
      }
    },
  },
});
