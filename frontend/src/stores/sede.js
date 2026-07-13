// frontend/src/stores/sede.js
// Proveedor de la LISTA de sedes del club (para los filtros locales por sede de cada vista).
// No hay "contexto de sede global": el admin ve el total del club y filtra por sede a demanda,
// dentro de cada vista (cada una con su propio filtro local). Ver decisión jul-2026.
import { defineStore } from "pinia";
import { listSedes } from "../lib/api";

export const useSedeStore = defineStore("sede", {
  state: () => ({
    sedes:  [],
    loaded: false,
  }),

  actions: {
    async fetchSedes() {
      try {
        const { data } = await listSedes();
        this.sedes = data || [];
      } catch { /* sin sedes o sin permiso */ }
      finally { this.loaded = true; }
    },
  },
});
