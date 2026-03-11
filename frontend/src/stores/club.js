// src/stores/club.js
import { defineStore } from 'pinia'
import api, {getPreferences} from '../lib/api'

export const useClubStore = defineStore('club', {
  state: () => ({
    data: null,
    loading: false,
    saving: false,
    error: null,
  }),

  getters: {
    name: (s) => (s.data?.name || 'Cultivo Espacial'),
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
        const {data} = await getPreferences()
        this.data = data
      } catch (e) {
        this.error = "No se pudieron cargar las preferencias del club"
        this.data = null
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
        const { data } = await api.post('/preferences/upload_logo', fd, {
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


