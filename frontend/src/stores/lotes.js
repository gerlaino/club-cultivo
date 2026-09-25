import { logger } from '../utils/logger.js'
import { defineStore } from "pinia";
import {
  listLotes,
  listLotesDeSala,
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
    // `silencioso`: re-pedir sin prender `loading`. Lo usa el refresco por cable: la pantalla
    // ya tiene datos, y un spinner encima de una lista que sólo cambia un número es un parpadeo.
    async fetch({ silencioso = false } = {}) {
      if (!silencioso) { this.loading = true; this.error = null; }
      try {
        const { data } = await listLotes();
        this.items = data || [];
      } catch (e) {
        logger.error("Lotes.fetch", e);
        // Un refresco silencioso que falla no pinta un error encima de una lista que se ve bien.
        if (!silencioso) this.error = e?.response?.data?.error || e.message;
      } finally {
        this.loading = false;
      }
    },

    async fetchBySala(salaId, { silencioso = false } = {}) {
      if (!silencioso) { this.loading = true; this.error = null; }
      try {
        const { data } = await listLotesDeSala(salaId);
        this.itemsBySala.set(String(salaId), data || []);
      } catch (e) {
        logger.error("Lotes.fetchBySala", e);
        if (!silencioso) this.error = e?.response?.data?.error || e.message;
      } finally {
        this.loading = false;
      }
    },

    // Cuando el backend avisa que un lote cambió: se re-pide sólo lo que ya está cargado.
    async refrescar() {
      const tareas = [];
      if (this.items.length) tareas.push(this.fetch({ silencioso: true }));
      for (const salaId of this.itemsBySala.keys()) tareas.push(this.fetchBySala(salaId, { silencioso: true }));
      if (this.current?.id) tareas.push(this.fetchOne(this.current.id, { silencioso: true }).catch(() => {}));
      await Promise.all(tareas);
    },

    async createInSala(salaId, payload) {
      this.creating = true; this.createError = null;
      try {
        const { data } = await createLote(salaId, payload);
        const arr = this.bySala(salaId);
        this.itemsBySala.set(String(salaId), [data, ...arr]);
        return data;
      } catch (e) {
        logger.error("Lotes.createInSala", e);
        this.createError = e?.response?.data?.errors?.join(", ") || "No se pudo crear el lote";
        throw e;
      } finally {
        this.creating = false;
      }
    },

    async fetchOne(id, { silencioso = false } = {}) {
      if (!silencioso) { this.loading = true; this.error = null; this.current = null; }
      try {
        const { data } = await getLote(id);
        this.current = data;
        // Mantener la lista en sync: si el lote ya está en items / itemsBySala, lo
        // reemplazamos para que /lotes (y la sala) no queden con el estado viejo tras editar.
        if (this.items.some(l => l.id === data.id)) {
          this.items = this.items.map(l => (l.id === data.id ? data : l));
        }
        for (const [k, arr] of this.itemsBySala) {
          if (arr.some(l => l.id === data.id)) {
            this.itemsBySala.set(k, arr.map(l => (l.id === data.id ? data : l)));
          }
        }
        return data;
      } catch (e) {
        logger.error("Lotes.fetchOne", e);
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
        logger.error("Lotes.update", e);
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
        logger.error("Lotes.remove", e);
        this.removeError = e?.response?.data?.errors?.join(", ") || "No se pudo eliminar el lote";
        throw e;
      } finally {
        this.removing = false;
      }
    },
  },
});
