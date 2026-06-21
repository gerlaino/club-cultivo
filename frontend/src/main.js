import { createApp } from "vue";
import { createPinia } from "pinia";
import router from "./router";
import App from "./App.vue";

// Design System — must be first to provide tokens to all styles
// fonts loaded via index.html <link> tags (avoids Vite @import url() issues)
import "./design-system/tokens.css";
import "./design-system/reset.css";

// Bootstrap CSS & Icons
import "bootstrap/dist/css/bootstrap.min.css";
import "bootstrap-icons/font/bootstrap-icons.css";
import "bootstrap/dist/js/bootstrap.bundle.min.js";

import "./assets/theme.css";
import "./assets/responsive.css";
import {useAuthStore} from "./stores/auth.js";
import {useClubStore} from "./stores/club.js";

import { registerSW } from 'virtual:pwa-register'

// Nueva versión disponible → aplicar la actualización automáticamente.
// (Antes mostraba un banner "Actualizar" que en mobile casi nadie tocaba, y los
//  dispositivos quedaban con la versión vieja. Ahora se actualiza solo.)
const updateSW = registerSW({
  immediate: true,
  onNeedRefresh() {
    updateSW(true)   // skipWaiting → controllerchange → reload (abajo)
  },
})

function mostrarBannerActualizacion() {
  if (document.getElementById('sw-update-banner')) return
  const banner = document.createElement('div')
  banner.id = 'sw-update-banner'
  banner.style.cssText = 'position:fixed;bottom:16px;left:50%;transform:translateX(-50%);z-index:9999;' +
    'display:flex;align-items:center;gap:12px;background:#0f172a;color:#fff;padding:10px 16px;' +
    'border-radius:12px;box-shadow:0 8px 24px rgba(0,0,0,.25);font:600 13px system-ui,sans-serif;'
  banner.innerHTML = '<span>Hay una nueva versión de la app</span>'
  const btn = document.createElement('button')
  btn.textContent = 'Actualizar'
  btn.style.cssText = 'background:#4ade80;color:#0f172a;border:none;border-radius:8px;' +
    'padding:6px 14px;font:700 13px system-ui,sans-serif;cursor:pointer;'
  btn.onclick = () => { btn.textContent = 'Actualizando…'; updateSW(true) }
  banner.appendChild(btn)
  document.body.appendChild(banner)
}

// Cuando el SW nuevo toma control (tras aceptar el banner), recargar para servir assets frescos
let swRecargando = false
navigator.serviceWorker?.addEventListener('controllerchange', () => {
  if (swRecargando) return
  swRecargando = true
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

const auth = useAuthStore()
const club = useClubStore()

// Primero intentamos recuperar sesión
await auth.fetchMe?.()

// Si hay sesión, traemos preferencias del club (logo_url, nombre, etc.)
if (auth.user) {
  await club.fetch()
}

app.mount("#app");


