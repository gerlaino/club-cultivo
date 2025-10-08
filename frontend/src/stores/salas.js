import { defineStore } from "pinia";
import {
  listSalas,
  getSala,
  createSala,
  updateSala,
  deleteSala,
} from "../lib/api";

export const useSalasStore = defineStore("salas", {
  state: () => ({
    items: [],
    current: null,
    loading: false,
    error: null,
  }),
  actions: {
    async load() {
      this.loading = true;
      this.error = null;
      try {
        const { data } = await listSalas();
        this.items = data;
      } catch (e) {
        this.error = "No se pudo cargar la lista de salas";
        throw e;
      } finally {
        this.loading = false;
      }
    },

    async fetchOne(id) {
      this.error = null;
      try {
        const { data } = await getSala(id);
        this.current = data;
        const idx = this.items.findIndex((s) => s.id === data.id);
        if (idx >= 0) this.items[idx] = data;
        else this.items.push(data);
        return data;
      } catch (e) {
        this.error = "No se pudo cargar la sala";
        throw e;
      }
    },

    async create(payload) {
      this.error = null;
      try {
        const { data } = await createSala(payload);
        this.items.unshift(data);
        return data;
      } catch (e) {
        this.error = "No se pudo crear la sala";
        throw e;
      }
    },

    async update(id, payload) {
      this.error = null;
      try {
        const { data } = await updateSala(id, payload);
        const idx = this.items.findIndex((s) => s.id === id);
        if (idx >= 0) this.items[idx] = data;
        if (this.current && this.current.id === id) this.current = data;
        return data;
      } catch (e) {
        this.error = "No se pudo actualizar la sala";
        throw e;
      }
    },

    async remove(id) {
      this.error = null;
      try {
        await deleteSala(id);
        this.items = this.items.filter((s) => s.id !== id);
        if (this.current && this.current.id === id) this.current = null;
      } catch (e) {
        this.error = "No se pudo eliminar la sala";
        throw e;
      }
    },
  },
});


