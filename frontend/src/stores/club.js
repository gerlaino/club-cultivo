// src/stores/club.js
import { defineStore } from 'pinia'
import api from '../lib/api'

// El pedido de /preferences en vuelo: dos llamadas simultáneas (el arranque de la app y el guard
// de una ruta con módulo) comparten el mismo, en vez de pedirlo dos veces.
let enVuelo = null

export const useClubStore = defineStore('club', {
  state: () => ({
    data: null,
    loading: false,
    saving: false,
    error: null,
  }),

  getters: {
    name:    (s) => s.data?.name    || 'Cultivo Espacial',
    logoUrl: (s) => s.data?.logo_url || '',
  },

  actions: {
    $reset() {
      this.data    = null
      this.loading = false
      this.saving  = false
      this.error   = null
    },

    fetch() {
      if (!enVuelo) enVuelo = this._pedir().finally(() => { enVuelo = null })
      return enVuelo
    },

    async _pedir() {
      // El paciente no lee la configuración de su organización: lo suyo viene de `/portal/*` y el
      // backend le cierra `/preferences` (`paciente_solo_en_su_portal!`). Sin esto, cada pantalla
      // del portal pedía y recibía un 403.
      const { useAuthStore } = await import('./auth.js')
      if (useAuthStore().user?.role === 'paciente') return
      this.loading = true
      this.error   = null
      try {
        const { data } = await api.get('/preferences')
        // El backend ahora devuelve el objeto directamente (sin wrapper data:)
        this.data = data
      } catch (e) {
        this.error = 'No se pudieron cargar las preferencias del club'
        this.data  = null
      } finally {
        this.loading = false
      }
    },

    async update(payload) {
      this.saving = true
      this.error  = null
      try {
        const { data } = await api.put('/preferences', { club: payload })
        this.data = data
        return data
      } catch (e) {
        this.error = e?.response?.data?.errors?.join(', ') || e.message
        throw e
      } finally {
        this.saving = false
      }
    },

    async uploadLogo(file) {
      const fd = new FormData()
      fd.append('logo', file)
      this.saving = true
      this.error  = null
      try {
        const { data } = await api.post('/preferences/upload_logo', fd, {
          headers: { 'Content-Type': 'multipart/form-data' },
        })
        this.data = data
      } catch (e) {
        this.error = e?.response?.data?.errors?.join(', ') || e.message
        throw e
      } finally {
        this.saving = false
      }
    },

    async removeLogo() {
      this.saving = true
      this.error  = null
      try {
        const { data } = await api.put('/preferences', { purge_logo: true })
        this.data = data
      } catch (e) {
        this.error = e?.response?.data?.errors?.join(', ') || e.message
        throw e
      } finally {
        this.saving = false
      }
    },
  },
})
