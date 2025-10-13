// src/stores/club.js
import { defineStore } from 'pinia'
import api from '../lib/api'

export const useClubStore = defineStore('club', {
  state: () => ({
    data: null,
    loading: false,
    saving: false,
    error: null,
  }),

  getters: {
    name: (s) => (s.data?.name || ''),
    logoUrl: (s) => (s.data?.logo_url || ''),
  },

  actions: {
    $reset() {
      this.data = null
      this.loading = false
      this.saving = false
      this.error = null
    },

    async fetch() {
      this.loading = true
      this.error = null
      try {
        const { data } = await api.get('/preferences')
        this.data = data.data
      } catch (e) {
        this.error = e?.response?.data?.error || e.message
        throw e
      } finally {
        this.loading = false
      }
    },

    async update(payload) {
      this.saving = true
      this.error = null
      try {
        const { data } = await api.put('/preferences', { club: payload })
        this.data = data.data
        return data.data
      } catch (e) {
        this.error = e?.response?.data?.errors?.join(', ') || e.message
        throw e
      } finally {
        this.saving = false
      }
    },

    async uploadLogo(file) {
      const fd = new FormData()
      // el backend espera params[:logo]
      fd.append('logo', file)

      this.saving = true
      this.error = null
      try {
        const { data } = await api.put('/preferences', fd, {
          headers: { 'Content-Type': 'multipart/form-data' }
        })
        this.data = data.data
      } catch (e) {
        this.error = e?.response?.data?.errors?.join(', ') || e.message
        throw e
      } finally {
        this.saving = false
      }
    },

    async removeLogo() {
      this.saving = true
      this.error = null
      try {
        const { data } = await api.put('/preferences', { purge_logo: true })
        this.data = data.data
      } catch (e) {
        this.error = e?.response?.data?.errors?.join(', ') || e.message
        throw e
      } finally {
        this.saving = false
      }
    },
  },
})


