import { defineStore } from "pinia";
import {
  listSalas, getSala, createSala, updateSala, deleteSala
} from "../lib/api";

export const useSalasStore = defineStore("salas", {
  state: () => ({
    items: [],
    currentSala: null,   // detalle
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
    byId: (state) => (id) =>
      state.items.find((s) => String(s.id) === String(id)) || null,
  },

  actions: {
    async fetch() {
      this.loading = true; this.error = null;
      try {
        const { data } = await listSalas();
        this.items = data || [];
      } catch (e) {
        console.error("Salas.fetch", e);
        this.error = e?.response?.data?.error || e.message;
      } finally {
        this.loading = false;
      }
    },

    async fetchSala(id) {
      this.loading = true; this.error = null; this.currentSala = null;
      try {
        const { data } = await getSala(id);
        this.currentSala = data;
        return data;
      } catch (e) {
        console.error("Salas.fetchSala", e);
        this.error = e?.response?.data?.error || e.message;
        throw e;
      } finally {
        this.loading = false;
      }
    },

    async create(payload) {
      this.creating = true; this.createError = null;
      try {
        const { data } = await createSala(payload);
        this.items = [data, ...this.items];
        return data;
      } catch (e) {
        console.error("Salas.create", e);
        this.createError = e?.response?.data?.errors?.join(", ") || "No se pudo crear la sala";
        throw e;
      } finally {
        this.creating = false;
      }
    },

    async update(id, payload) {
      this.updating = true; this.updateError = null;
      try {
        const { data } = await updateSala(id, payload);
        this.items = this.items.map(s => (s.id === id ? data : s));
        if (this.currentSala?.id === id) this.currentSala = data;
        return data;
      } catch (e) {
        console.error("Salas.update", e);
        this.updateError = e?.response?.data?.errors?.join(", ") || "No se pudo actualizar la sala";
        throw e;
      } finally {
        this.updating = false;
      }
    },

    async remove(id) {
      this.removing = true; this.removeError = null;
      try {
        await deleteSala(id);
        this.items = this.items.filter(s => s.id !== id);
        if (this.currentSala?.id === id) this.currentSala = null;
      } catch (e) {
        console.error("Salas.remove", e);
        this.removeError = e?.response?.data?.errors?.join(", ") || "No se pudo eliminar la sala";
        throw e;
      } finally {
        this.removing = false;
      }
    },

    clearCurrent() {
      this.currentSala = null;
      this.error = null;
    },
  },
});
