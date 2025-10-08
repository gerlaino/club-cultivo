import { defineStore } from "pinia";
import { getStats } from "../lib/api";

export const useStatsStore = defineStore("stats", {
  state: () => ({
    loading: false,
    error: null,
    totals: { salas: 0, lotes: 0 },
    recent_salas: [],
    recent_lotes: [],
  }),
  actions: {
    async load() {
      this.loading = true; this.error = null;
      try {
        const { data } = await getStats();
        this.totals = data.totals || { salas: 0, lotes: 0 };
        this.recent_salas = data.recent_salas || [];
        this.recent_lotes = data.recent_lotes || [];
      } catch (e) {
        this.error = "No se pudieron cargar las estadísticas";
      } finally {
        this.loading = false;
      }
    }
  }
});
