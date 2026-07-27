import { logger } from '../utils/logger.js'
// frontend/src/stores/insumos.js — depósito de insumos (Bloque 2).
import { defineStore } from "pinia";
import { listInsumos, createInsumo, updateInsumo, comprarInsumo, consumirInsumo, transferirInsumo, transferirInsumoDeposito, revertirCompraInsumo, reconteoInsumo, deleteInsumo } from "../lib/api";

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

    // Transferencia entre sedes: el origen baja stock, el destino sube (o se crea). El backend
    // devuelve { origen, destino }. Refrescamos ambos; si el destino no estaba en el filtro actual,
    // igual queda cacheado (el refetch por sede lo ordena).
    async transferir(id, payload) {
      return this._guardar(() => transferirInsumo(id, payload), ({ origen, destino }) => {
        if (origen)  this._merge(origen);
        if (destino) this._merge(destino);
      });
    },
    // Transferencia a OTRO depósito (reclasificación de stock, sin egreso).
    async transferirDeposito(id, payload) {
      return this._guardar(() => transferirInsumoDeposito(id, payload), ({ origen, destino }) => {
        if (origen)  this._merge(origen);
        if (destino) this._merge(destino);
      });
    },

    // Revierte una compra desde el depósito: baja stock, recalcula costo promedio y borra el
    // asiento contable asociado. El backend devuelve el insumo actualizado.
    async revertirCompra(id, compraId) {
      return this._guardar(() => revertirCompraInsumo(id, compraId), (data) => { this._merge(data); });
    },

    // Reconteo de inventario (corrección de dato o merma). Devuelve el insumo actualizado.
    async reconteo(id, payload) {
      return this._guardar(() => reconteoInsumo(id, payload), (data) => { this._merge(data); });
    },

    // Elimina el insumo por completo. El backend lo saca (o 422 si tuvo consumos → desactivar).
    async eliminar(id) {
      return this._guardar(() => deleteInsumo(id), () => { this.items = this.items.filter(i => i.id !== id); });
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
