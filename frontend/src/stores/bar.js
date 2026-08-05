import { logger } from '../utils/logger.js'
// frontend/src/stores/bar.js — bar como entidad por sede + POS + panel.
import { defineStore } from "pinia";
import {
  listBares, createBar, updateBar, deleteBar, getBarDashboard,
  listBarProductos, createBarProducto, updateBarProducto, deleteBarProducto,
  reponerBarProducto, crearBarVenta, abrirCaja, cerrarCaja,
  getCajaActual, confirmarAperturaCaja, solicitarCierreCaja, confirmarCierreCaja,
} from "../lib/api";

// Convierte lo que sea vendible a la línea del carrito. Dos formas de entrada:
//   • producto del bar (del listado del POS): { id, nombre, precio_ars, stock }
//   • vendible de otro depósito (buscador /vendibles): { vendible_type, vendible_id, disponible… }
function normalizarVendible(x, precioManual = null) {
  if (!x) return null;
  const esOtroDeposito = !!x.vendible_type;
  const tipo = esOtroDeposito ? x.vendible_type : 'BarProducto';
  const id   = esOtroDeposito ? x.vendible_id   : x.id;
  const precio = precioManual != null ? Number(precioManual) : Number(x.precio_ars) || 0;
  return {
    key: `${tipo}-${id}`, tipo, id,
    nombre: x.nombre,
    precio,
    precio_manual: precioManual != null,
    disponible: Number(esOtroDeposito ? x.disponible : x.stock) || 0,
    deposito: esOtroDeposito ? x.deposito : 'salon',
    unidad: x.unidad || 'u',
  };
}

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
    activos:      (s) => s.productos.filter(p => p.activo && p.vendible !== false), // POS: solo lo vendible
    totalCarrito: (s) => s.carrito.reduce((a, l) => a + l.precio * l.cantidad, 0),
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
    // El mostrador vende de cualquier depósito: la línea del carrito es genérica
    // ({ tipo, id, nombre, precio, disponible, deposito }), no un BarProducto.
    // `agregar` acepta las dos formas: un producto del bar (uso histórico) o un vendible
    // del buscador cross-depósito ({ vendible_type, vendible_id, ... }).
    agregar(x, { precio = null } = {}) {
      const it = normalizarVendible(x, precio);
      if (!it || it.disponible <= 0) return;
      const linea = this.carrito.find(l => l.key === it.key);
      const enCarrito = linea ? linea.cantidad : 0;
      if (enCarrito + 1 > it.disponible) return;
      if (linea) linea.cantidad++;
      else this.carrito.push({ ...it, cantidad: 1 });
    },
    sumar(key) {
      const linea = this.carrito.find(l => l.key === key);
      if (linea && linea.cantidad + 1 <= linea.disponible) linea.cantidad++;
    },
    quitar(key) {
      const i = this.carrito.findIndex(l => l.key === key);
      if (i === -1) return;
      if (this.carrito[i].cantidad > 1) this.carrito[i].cantidad--;
      else this.carrito.splice(i, 1);
    },
    vaciar() { this.carrito = []; },

    // Línea SUELTA: algo que no está en el catálogo (el admin todavía no lo cargó). Se vende
    // con nombre y precio a mano; no descuenta stock porque no hay de qué descontarlo. La venta
    // y su ingreso quedan registrados igual — que es el punto: que no se cobre por fuera.
    agregarSuelto({ nombre, precio }) {
      const n = String(nombre || '').trim();
      const p = Number(precio) || 0;
      if (!n || p <= 0) return false;
      this.carrito.push({
        key: `suelto-${Date.now()}`, suelto: true,
        nombre: n, precio: p, cantidad: 1,
        disponible: Infinity, deposito: null, unidad: 'u',
      });
      return true;
    },

    async cobrar(barId, medio_pago = 'efectivo', evento_bar_id = null) {
      if (!this.carrito.length) return null;
      this.saving = true; this.saveError = null;
      try {
        // El precio solo viaja cuando es manual (ítem sin precio propio): el backend lo acepta
        // únicamente de admin/supervisor.
        const lineas = this.carrito.map(l => (
          l.suelto
            // Sin vendible: el backend la registra como venta suelta.
            ? { nombre: l.nombre, cantidad: l.cantidad, precio_unitario_ars: l.precio }
            : {
                vendible_type: l.tipo, vendible_id: l.id, cantidad: l.cantidad,
                ...(l.precio_manual ? { precio_unitario_ars: l.precio } : {}),
              }
        ));
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
    async crearProducto(barId, payload, carga = null) {
      return this._guardar(() => createBarProducto(barId, payload, carga), (d) => { this.productos = [...this.productos, d]; });
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
