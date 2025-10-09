import { defineStore } from "pinia";
import {
  listLotes,                // compat (si alguna parte del código lo usa)
  listLotesBySala,          // nuevo (usado en SalaDetail)
  createLoteInSala,
  getLote,
  updateLote,
  deleteLote,
} from "../lib/api";

export const useLotesStore = defineStore("lotes", {
  state: () => ({
    items: [],               // compat global
    itemsBySala: new Map(),  // salaId -> array de lotes
    loading: false,
    error: null,
    creating: false,
    updating: false,
    removing: false,
  }),

  getters: {
    bySala: (state) => (salaId) =>
      state.itemsBySala.get(String(salaId)) || [],
  },

  actions: {
    // --- compat global (si lo necesitas en otro lado) ---
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

    // --- recomendado: por sala ---
    async fetchBySala(salaId) {
      this.loading = true; this.error = null;
      try {
        const { data } = await listLotesBySala(salaId);
        this.itemsBySala.set(String(salaId), data || []);
      } catch (e) {
        console.error("Lotes.fetchBySala", e);
        this.error = e?.response?.data?.error || e.message;
      } finally {
        this.loading = false;
      }
    },

    async createInSala(salaId, payload) {
      this.creating = true; this.error = null;
      try {
        const { data } = await createLoteInSala(salaId, payload);
        const arr = this.bySala(salaId);
        this.itemsBySala.set(String(salaId), [data, ...arr]);
        return data;
      } catch (e) {
        console.error("Lotes.createInSala", e);
        this.error = e?.response?.data?.errors?.join(", ") || e.message;
        throw e;
      } finally {
        this.creating = false;
      }
    },

    async update(id, payload, salaId = null) {
      this.updating = true; this.error = null;
      try {
        const { data } = await updateLote(id, payload);
        if (salaId) {
          const arr = this.bySala(salaId).map(l => (l.id === id ? data : l));
          this.itemsBySala.set(String(salaId), arr);
        } else {
          this.items = this.items.map(l => (l.id === id ? data : l));
        }
        return data;
      } catch (e) {
        console.error("Lotes.update", e);
        this.error = e?.response?.data?.errors?.join(", ") || e.message;
        throw e;
      } finally {
        this.updating = false;
      }
    },

    async remove(id, salaId = null) {
      this.removing = true; this.error = null;
      try {
        await deleteLote(id);
        if (salaId) {
          const arr = this.bySala(salaId).filter(l => l.id !== id);
          this.itemsBySala.set(String(salaId), arr);
        } else {
          this.items = this.items.filter(l => l.id !== id);
        }
      } catch (e) {
        console.error("Lotes.remove", e);
        this.error = e?.response?.data?.errors?.join(", ") || e.message;
        throw e;
      } finally {
        this.removing = false;
      }
    },
  },
});
