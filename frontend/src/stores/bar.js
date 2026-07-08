import { logger } from '../utils/logger.js'
// frontend/src/stores/bar.js — POS + panel del bar (Bloque 3).
import { defineStore } from "pinia";
import {
  listBarProductos, createBarProducto, updateBarProducto, deleteBarProducto,
  reponerBarProducto, crearBarVenta, getBarDashboard,
} from "../lib/api";

export const useBarStore = defineStore("bar", {
  state: () => ({
    productos: [],
    dashboard: null,
    loading:   false,
    error:     null,
    saving:    false,
    saveError: null,
    // carrito del POS: [{ producto, cantidad }]
    carrito:   [],
  }),

  getters: {
    activos:      (s) => s.productos.filter(p => p.activo),
    totalCarrito: (s) => s.carrito.reduce((a, l) => a + l.producto.precio_ars * l.cantidad, 0),
    cantItems:    (s) => s.carrito.reduce((a, l) => a + l.cantidad, 0),
  },

  actions: {
    async fetchProductos(params = {}) {
      this.loading = true; this.error = null;
      try {
        const { data } = await listBarProductos(params);
        this.productos = data || [];
      } catch (e) {
        this.error = e?.response?.data?.error || e.message;
      } finally {
        this.loading = false;
      }
    },

    async fetchDashboard() {
      try {
        const { data } = await getBarDashboard();
        this.dashboard = data;
      } catch (e) {
        logger.error("Bar.fetchDashboard", e);
      }
    },

    // ── Carrito ──────────────────────────────────────────────
    agregar(producto) {
      if (producto.stock <= 0) return;
      const linea = this.carrito.find(l => l.producto.id === producto.id);
      const enCarrito = linea ? linea.cantidad : 0;
      if (enCarrito + 1 > producto.stock) return; // no vender más que el stock
      if (linea) linea.cantidad++;
      else this.carrito.push({ producto, cantidad: 1 });
    },
    quitar(productoId) {
      const i = this.carrito.findIndex(l => l.producto.id === productoId);
      if (i === -1) return;
      if (this.carrito[i].cantidad > 1) this.carrito[i].cantidad--;
      else this.carrito.splice(i, 1);
    },
    vaciar() { this.carrito = []; },

    async cobrar(medio_pago = 'efectivo') {
      if (!this.carrito.length) return null;
      this.saving = true; this.saveError = null;
      try {
        const lineas = this.carrito.map(l => ({ bar_producto_id: l.producto.id, cantidad: l.cantidad }));
        const { data } = await crearBarVenta({ lineas, medio_pago });
        this.vaciar();
        await this.fetchProductos(); // refresca stock
        return data;
      } catch (e) {
        this.saveError = e?.response?.data?.error || "No se pudo cobrar";
        throw e;
      } finally {
        this.saving = false;
      }
    },

    // ── Config de productos (admin) ──────────────────────────
    async crearProducto(payload) {
      return this._guardar(() => createBarProducto(payload), (d) => { this.productos = [...this.productos, d]; });
    },
    async actualizarProducto(id, payload) {
      return this._guardar(() => updateBarProducto(id, payload), (d) => { this._merge(d); });
    },
    async eliminarProducto(id) {
      await deleteBarProducto(id);
      this.productos = this.productos.filter(p => p.id !== id);
    },
    async reponer(id, cantidad) {
      return this._guardar(() => reponerBarProducto(id, cantidad), (d) => { this._merge(d); });
    },

    _merge(d) {
      const i = this.productos.findIndex(p => p.id === d.id);
      if (i !== -1) this.productos[i] = { ...this.productos[i], ...d };
      else this.productos.push(d);
    },

    async _guardar(apiCall, applyLocal) {
      this.saving = true; this.saveError = null;
      try {
        const { data } = await apiCall();
        applyLocal(data);
        return data;
      } catch (e) {
        this.saveError = e?.response?.data?.errors?.join(", ") || e?.response?.data?.error || "No se pudo guardar";
        throw e;
      } finally {
        this.saving = false;
      }
    },
  },
});
