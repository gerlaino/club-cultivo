// frontend/src/stores/sede.js
// Contexto global de "sede actual": la capa de abstracción de la UI. Cuando hay una sede activa,
// las vistas de-sede (cultivo, stock, salón, insumos…) filtran por ella. `null` = todas (consolidado).
// Se persiste en localStorage para que el contexto sobreviva a recargas.
import { defineStore } from "pinia";
import { listSedes } from "../lib/api";

const KEY = "sede-actual";
const guardado = () => {
  if (typeof localStorage === "undefined") return null;
  const v = localStorage.getItem(KEY);
  return v ? Number(v) : null;
};

export const useSedeStore = defineStore("sede", {
  state: () => ({
    sedes:  [],
    sedeId: guardado(),   // null = todas las sedes (consolidado)
    loaded: false,
  }),

  getters: {
    sedeActual:    (s) => s.sedes.find(x => x.id === s.sedeId) || null,
    esConsolidado: (s) => s.sedeId == null,
    // valor a pasar en los params de los fetch (undefined cuando es "todas", para no mandar la clave)
    sedeParam:     (s) => (s.sedeId == null ? undefined : s.sedeId),
  },

  actions: {
    async fetchSedes() {
      try {
        const { data } = await listSedes();
        this.sedes = data || [];
        // Si la sede guardada ya no existe (o no es accesible), volvemos a consolidado.
        if (this.sedeId != null && !this.sedes.some(s => s.id === this.sedeId)) this.setSede(null);
      } catch { /* sin sedes o sin permiso: queda en consolidado */ }
      finally { this.loaded = true; }
    },

    setSede(id) {
      this.sedeId = id ?? null;
      if (typeof localStorage !== "undefined") {
        if (this.sedeId == null) localStorage.removeItem(KEY);
        else localStorage.setItem(KEY, String(this.sedeId));
      }
    },
  },
});
