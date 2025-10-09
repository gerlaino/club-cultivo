// frontend/src/stores/plants.js
import { defineStore } from "pinia";
import {
  listPlantsBySala,
  listPlantsByLote,
  getPlant,
  createPlantInLote,
  updatePlant,
  deletePlant,
} from "../lib/api";

export const usePlantsStore = defineStore("plants", {
  state: () => ({
    items: [],         // listado (por sala o por lote)
    current: null,     // planta seleccionada
    loading: false,
    error: null,
    creating: false,
    updating: false,
  }),

  actions: {
    async fetchBySala(salaId) {
      this.loading = true; this.error = null;
      try {
        const { data } = await listPlantsBySala(salaId);
        this.items = data || [];
      } catch (e) {
        console.error(e);
        this.error = "No se pudieron cargar las plantas";
      } finally {
        this.loading = false;
      }
    },

    async fetchByLote(loteId) {
      this.loading = true; this.error = null;
      try {
        const { data } = await listPlantsByLote(loteId);
        this.items = data || [];
      } catch (e) {
        console.error(e);
        this.error = "No se pudieron cargar las plantas";
      } finally {
        this.loading = false;
      }
    },

    async show(id) {
      this.loading = true; this.error = null;
      try {
        const { data } = await getPlant(id);
        this.current = data;
        return data;
      } catch (e) {
        console.error(e);
        this.error = "No se pudo cargar la planta";
        throw e;
      } finally {
        this.loading = false;
      }
    },

    async createInLote(loteId, payload) {
      this.creating = true; this.error = null;
      try {
        const { data } = await createPlantInLote(loteId, payload);
        // opcional: inserto al principio si la lista actual es de la misma sala/lote
        this.items = [data, ...this.items];
        return data;
      } catch (e) {
        console.error(e);
        this.error = e?.response?.data?.errors?.join(", ") || "No se pudo crear la planta";
        throw e;
      } finally {
        this.creating = false;
      }
    },

    async update(id, payload) {
      this.updating = true; this.error = null;
      try {
        const { data } = await updatePlant(id, payload);
        // actualizar current e items
        if (this.current?.id === data.id) this.current = data;
        this.items = this.items.map(p => (p.id === data.id ? data : p));
        return data;
      } catch (e) {
        console.error(e);
        this.error = e?.response?.data?.errors?.join(", ") || "No se pudo actualizar la planta";
        throw e;
      } finally {
        this.updating = false;
      }
    },
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
});
