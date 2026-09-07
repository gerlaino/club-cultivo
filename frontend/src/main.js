import { createApp } from "vue";
import { vModal } from "./directives/modal.js";
import { createPinia } from "pinia";
import router from "./router";
import App from "./App.vue";

// Design System — must be first to provide tokens to all styles
// fonts loaded via index.html <link> tags (avoids Vite @import url() issues)
import "./design-system/tokens.css";
import "./design-system/reset.css";
// Capa del portal del paciente: su paleta sale de los tokens de arriba y del color de cada
// organización. Va después de `tokens.css` porque los usa.
import "./design-system/portal.css";

// Bootstrap CSS & Icons
import "bootstrap/dist/css/bootstrap.min.css";
import "bootstrap-icons/font/bootstrap-icons.css";
import "bootstrap/dist/js/bootstrap.bundle.min.js";

import "./assets/theme.css";
import "./assets/responsive.css";
import {useAuthStore} from "./stores/auth.js";
import {useClubStore} from "./stores/club.js";

import { registerSW } from 'virtual:pwa-register'
import { anotarReload, leerReloads } from './utils/reloadTrace.js'

// Para leer desde la consola por qué se recargó sola la pantalla: `ceReloads()`.
window.ceReloads = leerReloads

// NUEVA VERSIÓN → SE APLICA SOLA. Y HAY QUE IR A BUSCARLA.
//
// Actualizar solo ya estaba (antes había un banner que en el teléfono casi nadie tocaba), pero el
// navegador pregunta si hay versión nueva UNA sola vez: al registrar el service worker, o sea al
// arrancar en frío. Y una PWA instalada casi nunca arranca en frío — se resume desde el conmutador
// de apps— así que un teléfono podía quedarse días con la versión vieja mientras producción ya
// tenía el arreglo. Un arreglo que no llega al teléfono es un arreglo que no existe: pasó con el
// modal de dispensa, deployado y sin llegar.
//
// Se pregunta al VOLVER a la app (que es el momento en que la persona la va a usar) y cada media
// hora si quedó abierta.
//
// PERO NO SE RECARGA ENCIMA DE ALGUIEN QUE ESTÁ TRABAJANDO. Aplicar la versión nueva recarga la
// página, y hacerlo con una dispensa a medio cargar —el paciente enfrente y el carrito armado— es
// peor que estar una hora desactualizado. Si hay un diálogo abierto se posterga hasta que se
// cierre.
let swPendiente = false

function hayAlgoAbierto() {
  return !!document.querySelector('.mnd__overlay, .cnt__back, [role="dialog"], .sheet-bottom--open')
}

function aplicarActualizacion() {
  if (hayAlgoAbierto()) { swPendiente = true; return }
  swPendiente = false
  updateSW(true)   // skipWaiting → controllerchange → reload (abajo)
}

const updateSW = registerSW({
  immediate: true,
  onNeedRefresh: aplicarActualizacion,
  onRegisteredSW(_url, registro) {
    if (!registro) return

    const preguntar = () => { if (navigator.onLine !== false) registro.update().catch(() => {}) }
    setInterval(preguntar, 30 * 60 * 1000)
    document.addEventListener('visibilitychange', () => {
      if (document.hidden) return
      // Si ya había una versión esperando porque estaba trabajando, se aplica ahora.
      if (swPendiente) aplicarActualizacion()
      preguntar()
    })
  },
})

// Cuando el SW nuevo toma control, recargar para servir assets frescos
let swRecargando = false
navigator.serviceWorker?.addEventListener('controllerchange', () => {
  if (swRecargando) return
  swRecargando = true
  anotarReload('sw-controllerchange')
  window.location.reload()
})

const app = createApp(App);

app.use(createPinia());
app.use(router);

app.directive('click-outside', {
  mounted(el, binding) {
    el._clickOutside = (e) => { if (!el.contains(e.target)) binding.value(e) }
    document.addEventListener('click', el._clickOutside)
  },
  unmounted(el) {
    document.removeEventListener('click', el._clickOutside)
  },
});

// Montamos YA. NO bloquear el render esperando /api/me: si el backend está
// despertando (free tier) o /me tarda, bloquear acá dejaba la pantalla en negro
// (la app nunca montaba). El router (ensureBootstrapped) maneja la sesión por ruta.
// Foco al primer campo, ESC para salir y el Tab atrapado adentro: en el overlay de cada modal.
app.directive('modal', vModal);

// La rueda del mouse sobre un campo numérico ENFOCADO le cambia el valor, y pasa al scrollear
// un formulario largo: el número se mueve solo y queda escrito en stock o en plata. Se saca el
// foco en vez de bloquear la rueda, así la página sigue scrolleando normal.
document.addEventListener('wheel', (e) => {
  const el = document.activeElement
  if (el === e.target && el?.tagName === 'INPUT' && el.type === 'number') el.blur()
}, { passive: true })

app.mount("#app");

// Bootstrap en segundo plano (sesión + preferencias del club).
//
// VA POR ensureBootstrapped, NO por fetchMe directo. Dos razones, y las dos rompían el login:
//   1. `fetchMe()` sin `silent` levanta `auth.loading`, que es el flag con el que el formulario
//      de login deshabilita su botón y muestra el spinner. Como esto corre en CADA arranque,
//      el botón quedaba trabado hasta que /me contestara — y con el backend dormido, eso es
//      "no puedo iniciar sesión".
//   2. El router también dispara el bootstrap: por dos caminos distintos salían dos /me en
//      paralelo. `ensureBootstrapped` está memoizado y comparte una sola request.
const auth = useAuthStore()
const club = useClubStore()
auth.ensureBootstrapped()
  .then(() => { if (auth.user) club.fetch() })
  .catch(() => {})


