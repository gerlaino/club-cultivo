import { defineStore } from "pinia";
import { signIn, signOut, me, clearAuthToken } from "../lib/api";
import { useClubStore } from "../stores/club.js";
import { usePlan } from '../composables/usePlan.js'

// Promesa del bootstrap en vuelo. Fuera del state a propósito: no es dato de la app, es un
// candado para que dos navegaciones seguidas no disparen dos /me.
let bootstrapPromise = null;

// Cuánto espera el arranque por /me antes de seguir de largo. Si el backend está dormido,
// más vale mostrar el login que dejar la pantalla colgada.
const BOOTSTRAP_TIMEOUT_MS = 8000;

// Techo duro del login: pasado esto, el botón vuelve a estar disponible aunque la request
// siga en vuelo. Un spinner que no termina nunca es peor que un reintento.
// Por encima del timeout del propio request de login (45 s, ver `signIn` en lib/api.js): es una
// red de seguridad para que el botón no quede trabado si algo más se cuelga, no un plazo que
// deba ganarle a la request. Antes eran 15 s y cortaba ANTES que el request, dejando el
// formulario liberado mientras el login seguía en vuelo.
const LOGIN_TIMEOUT_MS = 50000;

// Cuándo contarle al usuario que la espera es normal (servidor despertando).
const AVISO_DEMORA_MS = 6000;

/**
 * Por qué no se pudo entrar, en castellano y accionable.
 *
 * Antes el `else` final caía en `e.message`, que para un timeout de axios es literalmente
 * "timeout of 10000ms exceeded": el texto interno de una librería, en inglés, mostrado como si
 * fuera una explicación. Y un error de transporte (sin `response`) no tiene ni eso.
 *
 * La regla: SIEMPRE devuelve un texto. Un login que falla sin decir nada deja al usuario
 * mirando un botón gris sin saber si se equivocó él, si se cayó el servidor o si tiene que
 * esperar.
 */
export function mensajeDeErrorDeLogin(e) {
  const status = e?.response?.status;
  const data   = e?.response?.data;

  if (status === 401) return "Email o contraseña incorrectos.";
  // El backend ya explica cuál módulo falta o por qué está suspendida la organización.
  if (data?.modulo_rol_apagado || data?.club_suspendido) return data.error;
  if (status === 403) return data?.error || "Tu usuario no tiene permiso para entrar.";
  if (status === 422) return data?.error || "Revisá los datos e intentá de nuevo.";
  if (status >= 500)  return "El servidor tuvo un problema. Probá de nuevo en unos segundos.";

  // Sin respuesta: o cortó la conexión, o el servidor tardó más que el timeout. Se distinguen
  // porque la acción que corresponde es distinta (revisar internet vs. volver a intentar).
  if (e?.code === "ECONNABORTED" || /timeout/i.test(e?.message || "")) {
    return "El servidor está tardando en responder. Esperá unos segundos y probá de nuevo.";
  }
  if (!e?.response) return "No pudimos conectar con el servidor. Revisá tu conexión e intentá de nuevo.";

  return data?.error || "No pudimos iniciar sesión. Probá de nuevo.";
}

// Generación de la sesión. Login y logout la incrementan. Un /me que salió ANTES de ese
// cambio ya no puede escribir el estado cuando vuelve: si no, el 401 tardío del arranque
// (que no llevaba cookie) pisaba con `user = null` un login que ya había funcionado, y la app
// te devolvía al formulario. Es la carrera que hacía que "iniciar sesión con otro usuario"
// se trabara de forma intermitente.
let authEpoch = 0;

export const useAuthStore = defineStore("auth", {
  state: () => ({
    user: null,
    loading: false,
    error: null,
    // Aviso NEUTRO mientras el login está en vuelo (no es un error): sirve para el caso del
    // servidor dormido, donde la espera es larga y legítima. Sin esto, la única señal es un
    // spinner, y un spinner largo sin texto se lee como "se colgó".
    aviso: null,
    redirectTo: null,
    bootstrapped: false,
    // Mientras cerramos sesión, los 401 de requests en vuelo NO deben capturar la
    // ruta actual como ?redirect (si no, el próximo usuario cae en la página del anterior).
    loggingOut: false,
    // La organización fue suspendida. El backend 403-ea TODO, así que la app queda inservible:
    // en vez de una sucesión de pantallas vacías y errores sueltos, se muestra un cartel que
    // explica qué pasó. Lo prende el interceptor de axios.
    clubSuspendido: false,
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
    // `loading` es EXCLUSIVO del formulario de login: es el flag con el que deshabilita su
    // botón y muestra el spinner. fetchMe NO lo toca, a propósito y sin opción de hacerlo.
    // Traer /me es algo que la app hace sola al arrancar y en cada cambio de ruta; si eso
    // levantara `loading`, el botón de "Ingresar" aparecería trabado sin que el usuario haya
    // apretado nada. Fue exactamente el bug que dejó a la PWA sin poder iniciar sesión.
    async fetchMe() {
      const epoch = authEpoch;
      this.error = null;
      try {
        const { data } = await me();
        if (epoch === authEpoch) this.user = data;
      } catch {
        // Una respuesta vieja no borra una sesión nueva.
        if (epoch === authEpoch) this.user = null;
      } finally {
        this.bootstrapped = true;
      }
    },

    // Memoizada: el guard corre en cada navegación y puede entrar dos veces antes de que la
    // primera termine (p. ej. landing → login con el backend despertando). Sin esto se
    // disparaban dos /me en paralelo peleándose el estado.
    //
    // Con techo de tiempo: el guard hace `await` de esto, así que un /me colgado —el free tier
    // de Render tarda en despertar— dejaba la app entera trabada en la pantalla de arranque,
    // sin siquiera llegar a mostrar el login. Pasados los 8s seguimos como "sin sesión": si
    // había sesión, el /me que llegue tarde igual completa el user.
    async ensureBootstrapped() {
      if (this.bootstrapped) return;
      bootstrapPromise ||= this.fetchMe().finally(() => { bootstrapPromise = null; });
      return Promise.race([
        bootstrapPromise,
        new Promise((resolve) => setTimeout(resolve, BOOTSTRAP_TIMEOUT_MS)),
      ]);
    },

    // `conservarError`: en un reintento automático NO se borra el mensaje anterior. Se borraba
    // siempre, así que entre el "Reintentando…" y la respuesta el formulario quedaba mudo: un
    // spinner sin una línea de texto, que es exactamente lo que parece un cuelgue.
    async login(email, password, redirect = null, { conservarError = false } = {}) {
      authEpoch++;           // invalida cualquier /me en vuelo del arranque
      bootstrapPromise = null;
      this.loading = true;
      // Red de seguridad: si algo se cuelga, el botón se libera igual. Preferimos que el
      // usuario pueda reintentar antes que dejarlo mirando un spinner eterno.
      const destrabar = setTimeout(() => {
        this.loading = false;
        // Y con una explicación: liberar el botón en silencio deja la pantalla igual que antes
        // de apretarlo, como si el click no hubiera existido.
        if (!this.error) this.error = "El servidor está tardando en responder. Probá de nuevo.";
      }, LOGIN_TIMEOUT_MS);
      // A los pocos segundos se cuenta qué está pasando. El backend puede estar dormido y tardar
      // bastante en despertar: la espera es normal, pero hay que decirlo.
      const avisar = setTimeout(() => {
        if (this.loading) this.aviso = "El servidor estaba en reposo y está arrancando. Puede tardar unos segundos.";
      }, AVISO_DEMORA_MS);
      this.aviso = null;
      if (!conservarError) this.error = null;
      this.loggingOut = false;
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
        // El club (logo, nombre, preferencias) se carga en SEGUNDO PLANO. Antes se esperaba
        // acá con await, ANTES de navegar: si /preferences colgaba —backend despertando—, el
        // botón se quedaba con el spinner y no entrabas nunca. Y solo pasaba con los roles sin
        // home propia (admin, dispensador, cultivador, manicura, supervisor), que son
        // justamente los que fallaban. Ninguna vista necesita el club para pintar: usan
        // `club.data?.…` y App.vue lo recarga si falta.
        if (!roleHome) useClubStore().fetch().catch(() => {});
        // Si veníamos de un deep-link / QR (?redirect=…), volvemos ahí. PERO nunca a la
        // home de OTRO rol (un redirect viejo del usuario anterior no debe ganar): los
        // deep-links normales (QR, fichas, etc.) sí se respetan.
        const r = redirect ? String(redirect) : null
        const homesDeRol = Object.values(ROLE_HOME)
        const apuntaAOtraHome = r && homesDeRol.some(h => (r === h || r.startsWith(h + '/')) && h !== roleHome)
        if (r && !apuntaAOtraHome) {
          router.push(r);
        } else {
          router.push(roleHome ? { path: roleHome } : { name: "dashboard" });
        }
      } catch (e) {
        // Una sola función decide el texto (ver `mensajeDeErrorDeLogin`), para que ningún camino
        // termine mostrando el mensaje interno de axios en inglés.
        this.error = mensajeDeErrorDeLogin(e);
        throw e;
      } finally {
        clearTimeout(destrabar);
        clearTimeout(avisar);
        this.aviso = null;
        this.loading = false;
      }
    },

    async logOut() {
      authEpoch++;
      bootstrapPromise = null;
      this.loading = true;
      this.error = null;
      this.loggingOut = true;   // los 401 en vuelo no deben setear ?redirect
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
        try {
          // Las migas de `reloadTrace` sobreviven al logout: no llevan nada de la sesión (motivo,
          // hora, ruta y build) y son la única evidencia del refresh de hace media hora. Si el
          // clear se las lleva, cerrar sesión borra justo lo que se está investigando.
          const migas = localStorage.getItem('ce_reload');
          localStorage.clear(); sessionStorage.clear();
          if (migas) localStorage.setItem('ce_reload', migas);
        } catch (_) {}
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
