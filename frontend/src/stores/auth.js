import { defineStore } from "pinia"
import { signIn, signOut, me } from "../lib/api"
import router from "../router"

export const useAuthStore = defineStore("auth", {
  state: () => ({
    user: null,
    loading: false,
    error: null,
    redirectTo: null,
  }),
  getters: {
    isAuthenticated: (s) => !!s.user,
    email: (s) => s.user?.email || "",
    role: (s) => s.role || "",
  },
  actions: {
    async fetchMe() {
      this.loading = true
      this.error = null
      try {
        const { data } = await me()
        this.user = data
      } catch {
        this.user = null
      } finally {
        this.loading = false
      }
    },
    async login(email, password) {
      this.loading = true; this.error = null
      try {
        await signIn(email, password)
        await this.fetchMe()
        router.push({ name: "dashboard" })
      } catch (e) {
        this.error = "Credenciales inválidas"
        throw e
      } finally {
        this.loading = false
      }
    },
    async logOut() {
      this.loading = true
      this.error = null
      try {
        await signOut()
      } catch (_) {
        // ignoramos errores de signout
      } finally {
        this.user = null
        router.push({ name: "login" })
        this.loading = false
      }
    }
  }
})

