import { defineStore } from "pinia";
import { signIn, signOut, me, clearAuthToken } from "../lib/api";
import { useClubStore } from "../stores/club.js";
import { usePlan } from '../composables/usePlan.js'

export const useAuthStore = defineStore("auth", {
  state: () => ({
    user: null,
    loading: false,
    error: null,
    redirectTo: null,
    bootstrapped: false,
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
        this.bootstrapped = true;
      }
    },

    async ensureBootstrapped() {
      if (!this.bootstrapped) {
        await this.fetchMe();
      }
    },

    async login(email, password, redirect = null) {
      this.loading = true;
      this.error = null;
      try {
        await signIn(email, password);
        await this.fetchMe();

        if (!this.user) {
          this.error = "No se pudo obtener el usuario. Intentá de nuevo.";
          return;
        }

        const { default: router } = await import("../router");
        const ROLE_HOME = {
          super_admin: '/super-admin',
          auditor:     '/auditor',
          medico:      '/medico',
          abogado:     '/abogado',
          delivery:    '/delivery',
        }
        const roleHome = ROLE_HOME[this.user?.role]
        // Los roles "normales" (admin, dispensador, etc.) necesitan el club cargado.
        if (!roleHome) {
          const club = useClubStore();
          await club.fetch();
        }
        // Si veníamos de un deep-link / QR (?redirect=…), volvemos ahí sin importar el rol.
        // Si el rol no tiene permiso para ese destino, el router.beforeEach lo reencauza
        // a su home — así nunca perdemos a dónde quería ir el usuario.
        if (redirect) {
          router.push(String(redirect));
        } else {
          router.push(roleHome ? { path: roleHome } : { name: "dashboard" });
        }
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
        clearAuthToken();
        const { planData } = usePlan();
        planData.value = null;
        // Borra TODOS los cachés del service worker (incl. el SW viejo aún instalado
        // en la PWA): evita que tras el logout se sirva un /me viejo cacheado, que es
        // la causa de "no cierra sesión" en mobile/PWA.
        if (typeof caches !== 'undefined') {
          try {
            const keys = await caches.keys();
            await Promise.all(keys.map((k) => caches.delete(k)));
          } catch (_) {}
        }
        try { localStorage.clear(); sessionStorage.clear(); } catch (_) {}
        // Hard reload (con replace) limpia todos los stores de Pinia y evita volver
        // atrás a una pantalla autenticada. Cache-bust para saltear cualquier SW.
        window.location.replace('/login?loggedout=' + Date.now());
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
