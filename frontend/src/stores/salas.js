// frontend/src/stores/salas.js
import { defineStore } from "pinia";
import { listSalas, createSala, updateSala, deleteSala } from "../lib/api";

export const useSalasStore = defineStore("salas", {
  state: () => ({
    items: [],
    loading: false,
    error: null,
    creating: false,
    createError: null,
  }),

  actions: {
    async fetch() {
      this.loading = true;
      this.error = null;
      try {
        const { data } = await listSalas();
        this.items = data || [];
      } catch (err) {
        console.error("Salas.fetch error", err);
        this.error = "No se pudieron cargar las salas";
      } finally {
        this.loading = false;
      }
    },

    async create(payload) {
      this.creating = true;
      this.createError = null;
      try {
        const { data } = await createSala(payload);
        // agregamos al principio para que se vea “arriba”
        this.items = [data, ...this.items];
        return data;
      } catch (err) {
        console.error("Salas.create error", err);
        this.createError =
          err?.response?.data?.errors?.join(", ") ||
          "No se pudo crear la sala";
        throw err;
      } finally {
        this.creating = false;
      }
    },

    async update(id, payload) {
      this.updating = true; this.updateError = null;
      try {
        const { data } = await updateSala(id, payload);
        this.items = this.items.map(s => (s.id === id ? data : s));
        return data;
      } catch (err) {
        console.error("Salas.update", err);
        this.updateError = err?.response?.data?.errors?.join(", ") || "No se pudo actualizar la sala";
        throw err;
      } finally {
        this.updating = false;
      }
    },

    async remove(id) {
      this.removing = true; this.removeError = null;
      try {
        await deleteSala(id);
        this.items = this.items.filter(s => s.id !== id);
      } catch (err) {
        console.error("Salas.remove", err);
        this.removeError = err?.response?.data?.errors?.join(", ") || "No se pudo eliminar la sala";
        throw err;
      } finally {
        this.removing = false;
      }
    },

  },
});
