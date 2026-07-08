import { logger } from '../utils/logger.js'
// frontend/src/stores/catalogoFinanzas.js
// Catálogo editable de Finanzas: categorías contables + unidades de negocio.
// Molde: stores/contabilidad.js.
import { defineStore } from "pinia";
import {
  listCategoriasContables, createCategoriaContable, updateCategoriaContable, deleteCategoriaContable,
  listUnidadesNegocio, createUnidadNegocio, updateUnidadNegocio, deleteUnidadNegocio,
} from "../lib/api";

export const useCatalogoFinanzasStore = defineStore("catalogoFinanzas", {
  state: () => ({
    categorias: [],
    unidades:   [],
    loading:    false,
    error:      null,
    saving:     false,
    saveError:  null,
  }),

  getters: {
    categoriasActivas: (s) => s.categorias.filter(c => c.activa),
    unidadesActivas:   (s) => s.unidades.filter(u => u.activa),
    ingresoCategorias: (s) => s.categorias.filter(c => c.tipo === 'ingreso'),
    egresoCategorias:  (s) => s.categorias.filter(c => c.tipo === 'egreso'),
    unidadPorId:       (s) => (id) => s.unidades.find(u => u.id === id) || null,
  },

  actions: {
    // Trae categorías y unidades juntas (una sola carga para toda la sección).
    async fetchAll() {
      this.loading = true;
      this.error   = null;
      try {
        const [cats, unis] = await Promise.all([
          listCategoriasContables(),
          listUnidadesNegocio(),
        ]);
        this.categorias = cats.data || [];
        this.unidades   = unis.data || [];
      } catch (e) {
        this.error = e?.response?.data?.error || e.message;
      } finally {
        this.loading = false;
      }
    },

    async fetchCategorias(params = {}) {
      try {
        const { data } = await listCategoriasContables(params);
        this.categorias = data || [];
      } catch (e) {
        logger.error("CatalogoFinanzas.fetchCategorias", e);
      }
    },

    async fetchUnidades(params = {}) {
      try {
        const { data } = await listUnidadesNegocio(params);
        this.unidades = data || [];
      } catch (e) {
        logger.error("CatalogoFinanzas.fetchUnidades", e);
      }
    },

    // ── Categorías ──────────────────────────────────────────────
    async crearCategoria(payload) {
      return this._guardar(
        () => createCategoriaContable(payload),
        (data) => { this.categorias = [...this.categorias, data]; },
      );
    },

    async actualizarCategoria(id, payload) {
      return this._guardar(
        () => updateCategoriaContable(id, payload),
        (data) => { this.categorias = this.categorias.map(c => c.id === id ? data : c); },
      );
    },

    async eliminarCategoria(id) {
      await deleteCategoriaContable(id);
      this.categorias = this.categorias.filter(c => c.id !== id);
    },

    // ── Unidades ────────────────────────────────────────────────
    async crearUnidad(payload) {
      return this._guardar(
        () => createUnidadNegocio(payload),
        (data) => { this.unidades = [...this.unidades, data]; },
      );
    },

    async actualizarUnidad(id, payload) {
      return this._guardar(
        () => updateUnidadNegocio(id, payload),
        (data) => { this.unidades = this.unidades.map(u => u.id === id ? data : u); },
      );
    },

    async eliminarUnidad(id) {
      await deleteUnidadNegocio(id);
      this.unidades = this.unidades.filter(u => u.id !== id);
    },

    // Wrapper común de guardado: maneja saving/saveError y aplica el efecto local.
    async _guardar(apiCall, applyLocal) {
      this.saving    = true;
      this.saveError = null;
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
