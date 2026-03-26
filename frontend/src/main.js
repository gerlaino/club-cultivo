import { createApp } from "vue";
import { createPinia } from "pinia";
import router from "./router";
import App from "./App.vue";

// Bootstrap CSS & Icons
import "bootstrap/dist/css/bootstrap.min.css";
import "bootstrap-icons/font/bootstrap-icons.css";
import "bootstrap/dist/js/bootstrap.bundle.min.js";

import "./assets/theme.css";
import {useAuthStore} from "./stores/auth.js";
import {useClubStore} from "./stores/club.js";

import { registerSW } from 'virtual:pwa-register'
registerSW({ immediate: true })

const app = createApp(App);

app.use(createPinia());
app.use(router);

const auth = useAuthStore()
const club = useClubStore()

// Primero intentamos recuperar sesión
await auth.fetchMe?.()

// Si hay sesión, traemos preferencias del club (logo_url, nombre, etc.)
if (auth.user) {
  await club.fetch()
}

app.mount("#app");


