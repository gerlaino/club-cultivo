import { defineStore } from "pinia";
import {
  listLotes,                // compat global opcional
  listLotesBySala,          // lotes de una sala
  createLoteInSala,
  getLote,                  // 👈 usamos esto para el detalle
  updateLote,
  deleteLote,
} from "../lib/api";

export const useLotesStore = defineStore("lotes", {
  state: () => ({
    items: [],               // compat global
    itemsBySala: new Map(),  // salaId -> array de lotes
    current: null,           // 👈 detalle de un lote
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
    // --- compat global ---
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

    // --- por sala ---
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

    // --- DETALLE ---
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
      this.updating = true; this.error = null;
      try {
        const { data } = await updateLote(id, payload);
        if (salaId) {
          const arr = this.bySala(salaId).map(l => (l.id === id ? data : l));
          this.itemsBySala.set(String(salaId), arr);
        } else {
          this.items = this.items.map(l => (l.id === id ? data : l));
        }
        if (this.current?.id === id) this.current = data; // mantener detalle al día
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
        if (this.current?.id === id) this.current = null;
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
