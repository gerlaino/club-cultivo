import { logger } from '../utils/logger.js'
import { defineStore } from "pinia";
import { listPlants, getPlant } from "../lib/api";

// El último pedido de la ficha: una respuesta que llega después de otra más nueva se descarta.
let ultimoPedido = null;

export const usePlantsStore = defineStore("plants", {
  state: () => ({
    itemsByLote: {},
    current: null,
    loading: false,
    error: null,
  }),
  getters: {
    byLote: (state) => (loteId) =>
      state.itemsByLote[String(loteId)] || [],
  },
  actions: {
    async fetchByLote(loteId, { silencioso = false } = {}) {
      if (!silencioso) { this.loading = true; this.error = null; }
      try {
        const { data } = await listPlants({ lote_id: loteId });
        this.itemsByLote[String(loteId)] = data || [];
      } catch (e) {
        logger.error("Plants.fetchByLote", e);
        this.error = e?.response?.data?.error || e.message;
      } finally {
        this.loading = false;
      }
    },
    // Refresco por cable: sólo los lotes cuyas plantas ya se pidieron, sin spinner.
    async refrescar(evento) {
      const lotes = Object.keys(this.itemsByLote);
      await Promise.all(lotes.map(l => this.fetchByLote(l, { silencioso: true })));
      if (this.current?.id && (!evento?.id || evento.id === this.current.id)) {
        try { this.current = (await getPlant(this.current.id)).data; } catch {}
      }
    },

    // Recargar la MISMA ficha (después de guardar, o por un aviso) no la vacía: la pantalla
    // seguía mostrando «no encontrado» o la ruedita mientras viajaba el pedido, y rearmaba todas
    // sus solapas. Sólo cambiar de ficha la vacía. Y si llegan dos respuestas, gana la última.
    async fetchOne(id) {
      const mismo = String(this.current?.id) === String(id);
      if (!mismo) { this.loading = true; this.current = null; }
      this.error = null;
      const pedido = (ultimoPedido = {});
      try {
        const { data } = await getPlant(id);
        if (pedido === ultimoPedido) this.current = data;
        return data;
      } catch (e) {
        logger.error("Plants.fetchOne", e);
        if (pedido === ultimoPedido) this.error = e?.response?.data?.error || e.message;
        throw e;
      } finally {
        if (pedido === ultimoPedido) this.loading = false;
      }
    },
    addToLote(loteId, planta) {
      const arr = this.itemsByLote[String(loteId)] || [];
      this.itemsByLote[String(loteId)] = [...arr, planta];
    },
  },
});
