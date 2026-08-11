import { logger } from '../utils/logger.js'
// frontend/src/stores/contabilidad.js
import { defineStore } from "pinia";
import {
  getContableDashboard,
  listMovimientos,
  createMovimiento,
  updateMovimiento,
  deleteMovimiento,
  exportMovimientosCSV,
} from "../lib/api";

export const useContabilidadStore = defineStore("contabilidad", {
  state: () => ({
    items:       [],
    totales:     { ingresos: 0, egresos: 0, balance: 0, count: 0 },
    // 10 por página: con 50 la tabla del libro se hacía larga y la página, pesada.
    pagination:  { page: 1, per_page: 10, total: 0, total_pages: 1 },
    loading:     false,
    error:       null,

    dashboard:        null,
    loadingDashboard: false,
    dashboardSede:    null, // sede_id activa en dashboard

    creating:    false,
    createError: null,
    updating:    false,
    updateError: null,
    removing:    false,
    removeError: null,

    filtros: {
      tipo:      "",
      categoria: "",
      sede_id:   "",
      lote_id:   "",
      desde:     "",
      hasta:     "",
      page:      1,
      per_page:  10,
    },
  }),

  actions: {
    async fetchDashboard(sede_id = null) {
      this.loadingDashboard = true;
      this.dashboardSede    = sede_id;
      try {
        const params = sede_id ? { sede_id } : {};
        const { data } = await getContableDashboard(params);
        this.dashboard = data;
      } catch (e) {
        logger.error("Contabilidad.fetchDashboard", e);
      } finally {
        this.loadingDashboard = false;
      }
    },

    async fetch(filtros = {}) {
      this.loading = true;
      this.error   = null;
      const params = { ...this.filtros, ...filtros };
      Object.keys(params).forEach(k => { if (!params[k]) delete params[k]; });
      try {
        const { data } = await listMovimientos(params);
        this.items      = data.movimientos  || [];
        this.totales    = data.totales      || { ingresos: 0, egresos: 0, balance: 0, count: 0 };
        this.pagination = data.pagination   || this.pagination;
      } catch (e) {
        this.error = e?.response?.data?.error || e.message;
      } finally {
        this.loading = false;
      }
    },

    async create(payload) {
      this.creating    = true;
      this.createError = null;
      try {
        const { data } = await createMovimiento(payload);
        this.items = [data, ...this.items];
        this.totales.count++;
        if (["ingreso","recupero_costo"].includes(data.tipo)) {
          this.totales.ingresos = +(this.totales.ingresos + data.monto_ars).toFixed(2);
        } else {
          this.totales.egresos = +(this.totales.egresos + data.monto_ars).toFixed(2);
        }
        this.totales.balance = +(this.totales.ingresos - this.totales.egresos).toFixed(2);
        return data;
      } catch (e) {
        this.createError = e?.response?.data?.errors?.join(", ") || "No se pudo crear el movimiento";
        throw e;
      } finally {
        this.creating = false;
      }
    },

    async update(id, payload) {
      this.updating    = true;
      this.updateError = null;
      try {
        const { data } = await updateMovimiento(id, payload);
        this.items = this.items.map(m => m.id === id ? data : m);
        return data;
      } catch (e) {
        this.updateError = e?.response?.data?.errors?.join(", ") || "No se pudo actualizar";
        throw e;
      } finally {
        this.updating = false;
      }
    },

    async remove(id) {
      this.removing    = true;
      this.removeError = null;
      try {
        await deleteMovimiento(id);
        this._quitarDeListas(id);
      } catch (e) {
        // 404 = ya no existía en el servidor (borrado previo / lista desactualizada):
        // sincronizamos las listas locales en lugar de fallar
        if (e?.response?.status === 404) {
          this._quitarDeListas(id);
          return;
        }
        this.removeError = e?.response?.data?.error || "No se pudo eliminar";
        throw e;
      } finally {
        this.removing = false;
      }
    },

    // Saca el movimiento de TODAS las listas locales (libro + últimos del dashboard).
    // Antes solo se filtraba items: la fila seguía visible en el dashboard y un
    // segundo click producía un 404.
    _quitarDeListas(id) {
      this.items = this.items.filter(m => m.id !== id);
      this.totales.count--;
      if (this.dashboard?.ultimos_movimientos) {
        this.dashboard.ultimos_movimientos =
          this.dashboard.ultimos_movimientos.filter(m => m.id !== id);
      }
    },

    // `formato`: 'xlsx' (por defecto) o 'csv'. El Excel trae los montos como números, las
    // fechas como fechas, totales y filtros; el CSV queda para quien lo quiera crudo.
    async exportCSV(params = {}, formato = "xlsx") {
      try {
        const esXlsx   = formato === "xlsx";
        const response = esXlsx ? await exportMovimientosXLSX(params) : await exportMovimientosCSV(params);
        const url  = window.URL.createObjectURL(new Blob([response.data]));
        const link = document.createElement("a");
        link.href  = url;
        link.setAttribute("download", `movimientos_${new Date().toISOString().slice(0,10)}.${esXlsx ? "xlsx" : "csv"}`);
        document.body.appendChild(link);
        link.click();
        link.remove();
        window.URL.revokeObjectURL(url);
      } catch (e) {
        logger.error("Export error", e);
      }
    },

    setFiltro(key, value) {
      this.filtros[key] = value;
      this.filtros.page = 1;
    },

    resetFiltros() {
      this.filtros = { tipo: "", categoria: "", sede_id: "", lote_id: "",
        desde: "", hasta: "", page: 1, per_page: 10 };
    },
  },
});
