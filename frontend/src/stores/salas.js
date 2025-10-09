// frontend/src/stores/salas.js
import { defineStore } from "pinia";
import { listSalas, createSala, updateSala, deleteSala } from "../lib/api";

export const useSalasStore = defineStore("salas", {
  state: () => ({
    items: [],
    loading: false,
    error: null,

    creating: false,
    updating: false,
    removing: false,
  }),

  getters: {
    // Buscar por id (string/number indistinto)
    byId: (state) => (id) =>
      state.items.find((s) => String(s?.id) === String(id)) || null,

    count: (state) => state.items.length,
  },

  actions: {
    async fetch() {
      this.loading = true;
      this.error = null;
      try {
        const { data } = await listSalas();
        this.items = Array.isArray(data) ? data.filter(Boolean) : [];
      } catch (e) {
        console.error("salas.fetch", e);
        this.items = [];
        this.error =
          e?.response?.data?.error || "No se pudieron cargar las salas";
      } finally {
        this.loading = false;
      }
    },

    async create(payload) {
      this.creating = true;
      try {
        const { data } = await createSala(payload);
        if (data) this.items.unshift(data);
        return data;
      } finally {
        this.creating = false;
      }
    },

    async update(id, payload) {
      this.updating = true;
      try {
        const { data } = await updateSala(id, payload);
        this.items = this.items.map((s) =>
          String(s?.id) === String(id) ? data : s
        );
        return data;
      } finally {
        this.updating = false;
      }
    },

    async remove(id) {
      this.removing = true;
      try {
        await deleteSala(id);
        this.items = this.items.filter((s) => String(s?.id) !== String(id));
      } finally {
        this.removing = false;
      }
    },
  },
});

