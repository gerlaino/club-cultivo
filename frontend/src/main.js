import { createApp } from "vue"
import { createPinia } from "pinia"
import router from "./router"
import App from "./App.vue"

// Bootstrap CSS & Icons
import "bootstrap/dist/css/bootstrap.min.css"
import "bootstrap-icons/font/bootstrap-icons.css"
import "bootstrap/dist/js/bootstrap.bundle.min.js"

import "./assets/theme.css"

import { useAuthStore } from "./stores/auth"

const app = createApp(App)
const pinia = createPinia()

// 🧩 Primero registrar Pinia
app.use(pinia)
app.use(router)

// 🧩 Ahora sí, usar el store
const auth = useAuthStore()
auth.fetchMe?.() // el ? evita errores si fetchMe no existe

// 🧩 Finalmente montar la app
app.mount("#app")

