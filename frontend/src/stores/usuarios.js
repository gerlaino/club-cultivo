import { defineStore } from "pinia"
import { listUsers, getUser, updateUser, deleteUser, resetUserPassword } from "../lib/api"

// El último pedido de la ficha: una respuesta que llega después de otra más nueva se descarta.
let ultimoPedido = null

export const useUsuariosStore = defineStore("usuarios", {
  state: () => ({
    items: [],
    current: null,
    loading: false,
    saving: false,
    removing: false,
    error: null,
  }),

  getters: {
    byId: (s) => (id) => s.items.find(u => String(u.id) === String(id)) || null,
  },

  actions: {
    async fetch(params = {}) {
      this.loading = true; this.error = null
      try {
        const { data } = await listUsers(params)
        this.items = data?.data || data || []
      } catch (e) {
        this.error = e?.response?.data?.error || e.message
      } finally {
        this.loading = false
      }
    },

    // Recargar la MISMA ficha (después de guardar, o por un aviso) no la vacía: la pantalla
    // seguía mostrando «no encontrado» o la ruedita mientras viajaba el pedido, y rearmaba todas
    // sus solapas. Sólo cambiar de ficha la vacía. Y si llegan dos respuestas, gana la última.
    async fetchOne(id) {
      const mismo = String(this.current?.id) === String(id)
      if (!mismo) { this.loading = true; this.current = null }
      this.error = null
      const pedido = (ultimoPedido = {})
      try {
        const { data } = await getUser(id)
        if (pedido === ultimoPedido) this.current = data?.data || data
        return data?.data || data
      } catch (e) {
        if (pedido === ultimoPedido) this.error = e?.response?.data?.error || e.message
        throw e
      } finally {
        if (pedido === ultimoPedido) this.loading = false
      }
    },

    // Sin `create`: el alta del equipo la hace la plataforma (super admin) desde el 12-oct-2026;
    // la organización la pide (`pedirUsuario`).

    async update(id, payload) {
      this.saving = true; this.error = null
      try {
        const { data } = await updateUser(id, payload)
        const user = data?.data || data
        this.items = this.items.map(u => u.id === id ? user : u)
        if (this.current?.id === id) this.current = user
        return user
      } catch (e) {
        this.error = e?.response?.data?.errors?.join(", ") || e.message
        throw e
      } finally {
        this.saving = false
      }
    },

    async remove(id) {
      this.removing = true; this.error = null
      try {
        await deleteUser(id)
        this.items = this.items.filter(u => u.id !== id)
        if (this.current?.id === id) this.current = null
      } catch (e) {
        this.error = e?.response?.data?.errors?.join(", ") || e.message
        throw e
      } finally {
        this.removing = false
      }
    },

    async sendReset(id) {
      try {
        await resetUserPassword(id)
      } catch (e) {
        this.error = e?.response?.data?.errors?.join(", ") || e.message
        throw e
      }
    }
  }
})
