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
registerSW({ immediate: true })

// Cuando el nuevo Service Worker toma control, recargar para servir assets frescos
navigator.serviceWorker?.addEventListener('controllerchange', () => {
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


