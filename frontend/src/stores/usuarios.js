import { defineStore } from "pinia"
import { listUsers, getUser, createUser, updateUser, deleteUser, resetUserPassword } from "../lib/api"

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

    async fetchOne(id) {
      this.loading = true; this.error = null; this.current = null
      try {
        const { data } = await getUser(id)
        this.current = data?.data || data
        return this.current
      } catch (e) {
        this.error = e?.response?.data?.error || e.message
        throw e
      } finally {
        this.loading = false
      }
    },

    async create(payload) {
      this.saving = true; this.error = null
      try {
        const { data } = await createUser(payload)
        const user = data?.data || data
        this.items = [user, ...this.items]
        return user
      } catch (e) {
        this.error = e?.response?.data?.errors?.join(", ") || e.message
        throw e
      } finally {
        this.saving = false
      }
    },

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
