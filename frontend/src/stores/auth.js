import { defineStore } from "pinia";
import { signIn, signOut, me } from "../lib/api";
import router from "../router";

export const useAuthStore = defineStore("auth", {
  state: () => ({
    user: null,
    loading: false,
    error: null,
    redirectTo: null,
    bootstrapped: false, // ← sabemos si ya se consultó /me
  }),
  getters: {
    isAuthenticated: (s) => !!s.user,
    email: (s) => s.user?.email || "",
    role:  (s) => s.user?.role  || "",
    displayName: (s) => {
      const u = s.user;
      if (!u) return "";
      const name = [u.first_name, u.last_name].filter(Boolean).join(" ").trim();
      return name || u.email;
    },
    isClubAdmin: (s) => {
      const r = s.user?.role;
      return r === "admin" || r === "super_admin";
    },
    avatarUrl: (s) => s.user?.avatar_url || "",
    initials: (s) => {
      const u = s.user;
      const name = [u?.first_name, u?.last_name].filter(Boolean).join(" ").trim() || u?.email || "";
      return name.split(/\s+/).slice(0, 2).map(x => x[0]?.toUpperCase() || "").join("") || "?";
    },
  },
  actions: {
    async fetchMe() {
      this.loading = true;
      this.error = null;
      try {
        const { data } = await me();
        this.user = data;
      } catch {
        this.user = null;
      } finally {
        this.loading = false;
        this.bootstrapped = true; // ← marca terminado
      }
    },

    // Úsalo para asegurarte de que /me ya se consultó (una sola vez por carga)
    async ensureBootstrapped() {
      if (!this.bootstrapped) {
        await this.fetchMe();
      }
    },

    async login(email, password) {
      this.loading = true; this.error = null;
      try {
        await signIn(email, password);
        await this.fetchMe();           // carga user
        router.push({ name: "dashboard" });
      } catch (e) {
        this.error = "Credenciales inválidas";
        throw e;
      } finally {
        this.loading = false;
      }
    },

    async logOut() {
      this.loading = true; this.error = null;
      try {
        await signOut();
      } catch (_) {
        // ignoramos errores de signout
      } finally {
        this.user = null;
        this.bootstrapped = true; // ya “sabemos” que no hay sesión
        router.push({ name: "login" });
        this.loading = false;
      }
    }
  }
});


