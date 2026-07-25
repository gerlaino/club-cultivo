import { logger } from '../utils/logger.js'
// frontend/src/stores/bar.js — bar como entidad por sede + POS + panel.
import { defineStore } from "pinia";
import {
  listBares, createBar, updateBar, deleteBar, getBarDashboard,
  listBarProductos, createBarProducto, updateBarProducto, deleteBarProducto,
  reponerBarProducto, crearBarVenta, abrirCaja, cerrarCaja,
  getCajaActual, confirmarAperturaCaja, solicitarCierreCaja, confirmarCierreCaja,
} from "../lib/api";

export const useBarStore = defineStore("bar", {
  state: () => ({
    bares:     [],
    barActual: null,      // objeto bar seleccionado
    productos: [],
    dashboard: null,
    cajaActiva: null,     // caja del turno activa (abierta/pendiente_cierre) — chip + CajaSheet
    cajaLoading: false,
    loading:   false,
    error:     null,
    saving:    false,
    saveError: null,
    carrito:   [],        // POS: [{ producto, cantidad }]
  }),

  getters: {
    activos:      (s) => s.productos.filter(p => p.activo),
    totalCarrito: (s) => s.carrito.reduce((a, l) => a + l.producto.precio_ars * l.cantidad, 0),
    cantItems:    (s) => s.carrito.reduce((a, l) => a + l.cantidad, 0),
  },

  actions: {
    // ── Bares (entidad) ──────────────────────────────────────
    async fetchBares() {
      this.loading = true; this.error = null;
      try {
        const { data } = await listBares();
        this.bares = data || [];
      } catch (e) {
        this.error = e?.response?.data?.error || e.message;
      } finally {
        this.loading = false;
      }
    },
    async crearBar(payload) {
      return this._guardar(() => createBar(payload), (d) => { this.bares = [...this.bares, d]; });
    },
    async actualizarBar(id, payload) {
      return this._guardar(() => updateBar(id, payload), (d) => { this.bares = this.bares.map(b => b.id === id ? d : b); });
    },
    async eliminarBar(id) {
      await deleteBar(id);
      this.bares = this.bares.filter(b => b.id !== id);
    },

    // ── Contexto de un bar ───────────────────────────────────
    async fetchDashboard(barId) {
      try {
        const { data } = await getBarDashboard(barId);
        this.dashboard = data;
        this.barActual = data.bar;
      } catch (e) {
        logger.error("Bar.fetchDashboard", e);
      }
    },
    async fetchProductos(barId, params = {}) {
      this.loading = true;
      try {
        const { data } = await listBarProductos(barId, params);
        this.productos = data || [];
      } catch (e) {
        this.error = e?.response?.data?.error || e.message;
      } finally {
        this.loading = false;
      }
    },

    // ── Carrito (POS) ────────────────────────────────────────
    agregar(producto) {
      if (producto.stock <= 0) return;
      const linea = this.carrito.find(l => l.producto.id === producto.id);
      const enCarrito = linea ? linea.cantidad : 0;
      if (enCarrito + 1 > producto.stock) return;
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

    async cobrar(barId, medio_pago = 'efectivo', evento_bar_id = null) {
      if (!this.carrito.length) return null;
      this.saving = true; this.saveError = null;
      try {
        const lineas = this.carrito.map(l => ({ bar_producto_id: l.producto.id, cantidad: l.cantidad }));
        const { data } = await crearBarVenta(barId, { lineas, medio_pago, evento_bar_id: evento_bar_id || undefined });
        this.vaciar();
        await this.fetchProductos(barId, { activos: 'true' });
        return data;
      } catch (e) {
        this.saveError = e?.response?.data?.error || "No se pudo cobrar";
        throw e;
      } finally {
        this.saving = false;
      }
    },

    // ── Caja de turno (con confirmación entre roles) ─────────
    // Fuente única del estado de la caja para el chip + CajaSheet, en cualquier pantalla del bar
    // (el dispensador no carga el dashboard, así que no puede depender de él).
    async fetchCajaActual(barId) {
      this.cajaLoading = true;
      try {
        const { data } = await getCajaActual(barId);
        this.cajaActiva = data?.caja || null;
      } catch (e) {
        logger.error("Bar.fetchCajaActual", e);
      } finally {
        this.cajaLoading = false;
      }
    },
    // Tras cualquier transición: refrescamos la caja siempre, y el dashboard solo si ya estaba cargado.
    async _trasCaja(barId) {
      await this.fetchCajaActual(barId);
      if (this.dashboard?.bar && String(this.dashboard.bar.id) === String(barId)) await this.fetchDashboard(barId);
    },
    async abrirCaja(barId, monto_inicial_ars) {
      const data = await this._guardar(() => abrirCaja(barId, { monto_inicial_ars }), () => {});
      await this._trasCaja(barId);
      return data;
    },
    async confirmarApertura(barId, cajaId) {
      const data = await this._guardar(() => confirmarAperturaCaja(barId, cajaId), () => {});
      await this._trasCaja(barId);
      return data;
    },
    async solicitarCierre(barId, cajaId, payload) {
      const data = await this._guardar(() => solicitarCierreCaja(barId, cajaId, payload), () => {});
      await this._trasCaja(barId);
      return data;
    },
    async confirmarCierre(barId, cajaId) {
      const data = await this._guardar(() => confirmarCierreCaja(barId, cajaId), () => {});
      await this._trasCaja(barId);
      return data;
    },
    async cerrarCaja(barId, cajaId, payload) {
      const data = await this._guardar(() => cerrarCaja(barId, cajaId, payload), () => {});
      await this._trasCaja(barId);
      return data;
    },

    // ── Config de productos (admin) ──────────────────────────
    async crearProducto(barId, payload) {
      return this._guardar(() => createBarProducto(barId, payload), (d) => { this.productos = [...this.productos, d]; });
    },
    async actualizarProducto(barId, id, payload) {
      return this._guardar(() => updateBarProducto(barId, id, payload), (d) => { this._merge(d); });
    },
    async eliminarProducto(barId, id) {
      await deleteBarProducto(barId, id);
      this.productos = this.productos.filter(p => p.id !== id);
    },
    async reponer(barId, id, cantidad) {
      return this._guardar(() => reponerBarProducto(barId, id, cantidad), (d) => { this._merge(d); });
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
