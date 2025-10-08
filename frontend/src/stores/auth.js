import { defineStore } from "pinia"
import { me, signIn, signOut } from "../lib/api"

export const useAuthStore = defineStore("auth", {
  state: () => ({ user: null, loading: false, error: null }),
  actions: {
    async fetchMe() {
      this.loading = true; this.error = null
      try { const { data } = await me(); this.user = data }
      catch (e) { this.user = null }
      finally { this.loading = false }
    },
    async login(email, password) {
      this.loading = true; this.error = null
      try { await signIn(email, password); await this.fetchMe() }
      catch (e) { this.error = "Credenciales inválidas"; throw e }
      finally { this.loading = false }
    },
    async logout() {
      await signOut(); this.user = null
    }
  }
})
