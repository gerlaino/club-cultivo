import { logger } from '../utils/logger.js'
// frontend/src/stores/insumos.js — depósito de insumos (Bloque 2).
import { defineStore } from "pinia";
import { listInsumos, createInsumo, updateInsumo, comprarInsumo, consumirInsumo } from "../lib/api";

export const useInsumosStore = defineStore("insumos", {
  state: () => ({
    items:            [],
    valorizadoTotal:  0,
    loading:          false,
    error:            null,
    saving:           false,
    saveError:        null,
  }),

  getters: {
    activos:    (s) => s.items.filter(i => i.activo),
    stockBajo:  (s) => s.items.filter(i => i.stock_bajo),
  },

  actions: {
    async fetch(params = {}) {
      this.loading = true;
      this.error   = null;
      try {
        const { data } = await listInsumos(params);
        this.items           = data.insumos || [];
        this.valorizadoTotal = data.valorizado_total || 0;
      } catch (e) {
        this.error = e?.response?.data?.error || e.message;
      } finally {
        this.loading = false;
      }
    },

    async crear(payload) {
      return this._guardar(() => createInsumo(payload), (data) => { this.items = [...this.items, data]; });
    },

    async actualizar(id, payload) {
      return this._guardar(() => updateInsumo(id, payload), (data) => { this._merge(data); });
    },

    // Compra: el backend devuelve el insumo actualizado (stock + costo promedio nuevos).
    async comprar(id, payload) {
      return this._guardar(() => comprarInsumo(id, payload), (data) => { this._merge(data); });
    },

    // Consumo: idem, con stock descontado.
    async consumir(id, payload) {
      return this._guardar(() => consumirInsumo(id, payload), (data) => { this._merge(data); });
    },

    _merge(data) {
      const idx = this.items.findIndex(i => i.id === data.id);
      if (idx !== -1) this.items[idx] = { ...this.items[idx], ...data };
      else this.items.push(data);
    },

    async _guardar(apiCall, applyLocal) {
      this.saving    = true;
      this.saveError = null;
      try {
        const { data } = await apiCall();
        applyLocal(data);
        return data;
      } catch (e) {
        this.saveError = e?.response?.data?.errors?.join(", ") || e?.response?.data?.error || "No se pudo guardar";
        logger.error("Insumos._guardar", e);
        throw e;
      } finally {
        this.saving = false;
      }
    },
  },
});
