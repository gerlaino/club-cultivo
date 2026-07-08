import { logger } from '../utils/logger.js'
// frontend/src/stores/eventosBar.js — eventos de un bar (Capa 2).
import { defineStore } from "pinia";
import {
  listEventosBar, getEventoBar, createEventoBar, updateEventoBar, deleteEventoBar,
  createEventoCosto, updateEventoCosto, deleteEventoCosto,
  createEventoTarea, updateEventoTarea, deleteEventoTarea,
  createTipoEntrada, updateTipoEntrada, deleteTipoEntrada, venderEntradas,
} from "../lib/api";

export const useEventosBarStore = defineStore("eventosBar", {
  state: () => ({
    eventos:  [],
    actual:   null,   // evento con detalle (costos + tareas)
    loading:  false,
    error:    null,
    saving:   false,
    saveError: null,
  }),

  actions: {
    async fetchLista(barId) {
      this.loading = true; this.error = null;
      try {
        const { data } = await listEventosBar(barId);
        this.eventos = data || [];
      } catch (e) {
        this.error = e?.response?.data?.error || e.message;
      } finally {
        this.loading = false;
      }
    },

    async fetchDetalle(barId, id) {
      this.loading = true;
      try {
        const { data } = await getEventoBar(barId, id);
        this.actual = data;
      } catch (e) {
        this.error = e?.response?.data?.error || e.message;
      } finally {
        this.loading = false;
      }
    },

    async crear(barId, payload)         { return this._save(() => createEventoBar(barId, payload)); },
    async actualizar(barId, id, payload) { return this._save(() => updateEventoBar(barId, id, payload), true); },
    async eliminar(barId, id)           { await deleteEventoBar(barId, id); this.eventos = this.eventos.filter(e => e.id !== id); },

    // Costos: al volver, refrescamos el detalle (recalcula P&L / presupuesto en el server).
    async crearCosto(barId, evId, p)          { await this._call(() => createEventoCosto(barId, evId, p)); await this.fetchDetalle(barId, evId); },
    async actualizarCosto(barId, evId, id, p) { await this._call(() => updateEventoCosto(barId, evId, id, p)); await this.fetchDetalle(barId, evId); },
    async eliminarCosto(barId, evId, id)      { await this._call(() => deleteEventoCosto(barId, evId, id)); await this.fetchDetalle(barId, evId); },

    async crearTarea(barId, evId, p)          { await this._call(() => createEventoTarea(barId, evId, p)); await this.fetchDetalle(barId, evId); },
    async actualizarTarea(barId, evId, id, p) { await this._call(() => updateEventoTarea(barId, evId, id, p)); await this.fetchDetalle(barId, evId); },
    async eliminarTarea(barId, evId, id)      { await this._call(() => deleteEventoTarea(barId, evId, id)); await this.fetchDetalle(barId, evId); },

    // Tipos de entrada + venta
    async crearTipo(barId, evId, p)           { await this._call(() => createTipoEntrada(barId, evId, p)); await this.fetchDetalle(barId, evId); },
    async actualizarTipo(barId, evId, id, p)  { await this._call(() => updateTipoEntrada(barId, evId, id, p)); await this.fetchDetalle(barId, evId); },
    async eliminarTipo(barId, evId, id)       { await this._call(() => deleteTipoEntrada(barId, evId, id)); await this.fetchDetalle(barId, evId); },
    async vender(barId, evId, tipoId, p)      { await this._call(() => venderEntradas(barId, evId, tipoId, p)); await this.fetchDetalle(barId, evId); },

    async _save(apiCall, isUpdate = false) {
      this.saving = true; this.saveError = null;
      try {
        const { data } = await apiCall();
        this.actual = data;
        if (isUpdate) this.eventos = this.eventos.map(e => e.id === data.id ? { ...e, ...data } : e);
        else this.eventos = [data, ...this.eventos];
        return data;
      } catch (e) {
        this.saveError = e?.response?.data?.errors?.join(", ") || e?.response?.data?.error || "No se pudo guardar";
        throw e;
      } finally {
        this.saving = false;
      }
    },

    async _call(apiCall) {
      this.saving = true; this.saveError = null;
      try { return (await apiCall()).data; }
      catch (e) {
        this.saveError = e?.response?.data?.errors?.join(", ") || e?.response?.data?.error || "No se pudo guardar";
        logger.error("EventosBar._call", e);
        throw e;
      } finally { this.saving = false; }
    },
  },
});
