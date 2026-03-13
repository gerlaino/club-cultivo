import { defineStore } from "pinia";
import {
  listLotes,
  createLote,
  getLote,
  updateLote,
  deleteLote,
} from "../lib/api";

export const useLotesStore = defineStore("lotes", {
  state: () => ({
    items: [],
    itemsBySala: new Map(),
    current: null,
    loading: false,
    error: null,

    creating: false,
    createError: null,

    updating: false,
    updateError: null,

    removing: false,
    removeError: null,
  }),

  getters: {
    bySala: (state) => (salaId) =>
      state.itemsBySala.get(String(salaId)) || [],
  },

  actions: {
    async fetch() {
      this.loading = true; this.error = null;
      try {
        const { data } = await listLotes();
        this.items = data || [];
      } catch (e) {
        console.error("Lotes.fetch", e);
        this.error = e?.response?.data?.error || e.message;
      } finally {
        this.loading = false;
      }
    },

    async fetchBySala(salaId) {
      this.loading = true; this.error = null;
      try {
        const { data } = await listLotes(salaId);
        this.itemsBySala.set(String(salaId), data || []);
      } catch (e) {
        console.error("Lotes.fetchBySala", e);
        this.error = e?.response?.data?.error || e.message;
      } finally {
        this.loading = false;
      }
    },

    async createInSala(salaId, payload) {
      this.creating = true; this.createError = null;
      try {
        const { data } = await createLote(salaId, payload);
        const arr = this.bySala(salaId);
        this.itemsBySala.set(String(salaId), [data, ...arr]);
        return data;
      } catch (e) {
        console.error("Lotes.createInSala", e);
        this.createError = e?.response?.data?.errors?.join(", ") || "No se pudo crear el lote";
        throw e;
      } finally {
        this.creating = false;
      }
    },

    async fetchOne(id) {
      this.loading = true; this.error = null; this.current = null;
      try {
        const { data } = await getLote(id);
        this.current = data;
        return data;
      } catch (e) {
        console.error("Lotes.fetchOne", e);
        this.error = e?.response?.data?.error || e.message;
        throw e;
      } finally {
        this.loading = false;
      }
    },

    async update(id, payload, salaId = null) {
      this.updating = true; this.updateError = null;
      try {
        const { data } = await updateLote(id, payload);
        if (salaId) {
          const arr = this.bySala(salaId).map(l => (l.id === id ? data : l));
          this.itemsBySala.set(String(salaId), arr);
        } else {
          this.items = this.items.map(l => (l.id === id ? data : l));
        }
        if (this.current?.id === id) this.current = data;
        return data;
      } catch (e) {
        console.error("Lotes.update", e);
        this.updateError = e?.response?.data?.errors?.join(", ") || "No se pudo actualizar el lote";
        throw e;
      } finally {
        this.updating = false;
      }
    },

    async remove(id, salaId = null) {
      this.removing = true; this.removeError = null;
      try {
        await deleteLote(id);
        if (salaId) {
          const arr = this.bySala(salaId).filter(l => l.id !== id);
          this.itemsBySala.set(String(salaId), arr);
        } else {
          this.items = this.items.filter(l => l.id !== id);
        }
        if (this.current?.id === id) this.current = null;
      } catch (e) {
        console.error("Lotes.remove", e);
        this.removeError = e?.response?.data?.errors?.join(", ") || "No se pudo eliminar el lote";
        throw e;
      } finally {
        this.removing = false;
      }
    },
  },
});
