import { defineStore } from "pinia"
import { signIn as apiSignIn, signOut as apiSignOut, me } from "../lib/api"
import router from "../router"

export const useAuthStore = defineStore("auth", {
  state: () => ({
    user: null,
    loading: false,
    error: null,
  }),
  getters: {
    isAuthenticated: (s) => !!s.user,
    email: (s) => s.user?.email || "",
  },
  actions: {
    async fetchMe() {
      try {
        const { data } = await me()
        this.user = data
      } catch {
        this.user = null
      }
    },
    async signIn(email, password) {
      this.loading = true; this.error = null
      try {
        await apiSignIn(email, password)
        await this.fetchMe()
        router.push({ name: "dashboard" })
      } catch (e) {
        this.error = "Credenciales inválidas"
        throw e
      } finally {
        this.loading = false
      }
    },
    async signOut() {
      try {
        await apiSignOut()
      } catch (_) {
        // ignoramos errores de signout
      } finally {
        this.user = null
        router.push({ name: "login" })
      }
    }
  }
})

