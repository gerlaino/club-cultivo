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
    displayName: (s) => {
      const u = s.user
      if (!u) return ""
      const name = [u.first_name, u.last_name].filter(Boolean).join(" ").trim()
      return name || u.email
    },
    isClubAdmin: (s) => {
      const r = s.user?.role
      return r === "admin" || r === "super_admin"
    },
    avatarUrl: (state) => state.user?.avatar_url || "",  // asegúrate que /me lo devuelva
    initials: (state) => {
      const u = state.user
      const name = [u?.first_name, u?.last_name].filter(Boolean).join(" ").trim() || u?.email || ""
      return name
        .split(/\s+/)
        .slice(0, 2)
        .map(s => s[0]?.toUpperCase() || "")
        .join("") || "?"
    },
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

