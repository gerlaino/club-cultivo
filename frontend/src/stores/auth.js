import { defineStore } from "pinia";
import { signIn, signOut, me } from "../lib/api";
import router from "../router";
import { useClubStore } from "../stores/club.js";
import { usePlan } from '../composables/usePlan.js'

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
        // Solo intentar fetchear si hay token
        const token = localStorage.getItem('jwt_token');
        if (token) {
          await this.fetchMe();
        } else {
          this.bootstrapped = true;
        }
      }
    },

    async login(email, password) {
      this.loading = true;
      this.error = null;

      try {
        await signIn(email, password);
        await this.fetchMe();

        // ⚡ Cargar preferencias del club tras login
        const club = useClubStore();
        await club.fetch();

        router.push({ name: "dashboard" });
      } catch (e) {
        if (e?.response?.status === 401) {
          this.error = "Credenciales inválidas";
        } else {
          this.error = e?.message || "Error al iniciar sesión";
        }
        throw e;
      } finally {
        this.loading = false;
      }
    },

    async logOut() {
      this.loading = true;
      this.error = null;
      try {
        await signOut();
      } catch (_) {
      } finally {
        this.user = null;
        this.bootstrapped = true;
        const { planData } = usePlan();
        planData.value = null;
        router.push({ name: "login" });
        this.loading = false;
      }
    },

    async refreshUser() {
      try {
        const { data } = await me()
        this.user = data
      } catch (_) {}
    },
  }
});


