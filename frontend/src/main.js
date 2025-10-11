import { createApp } from "vue"
import { createPinia } from "pinia"
import router from "./router"
import App from "./App.vue"

// Bootstrap CSS & Icons
import "bootstrap/dist/css/bootstrap.min.css"
import "bootstrap-icons/font/bootstrap-icons.css"

// Bootstrap JS (incluye Popper)
import "bootstrap/dist/js/bootstrap.bundle.min.js"

import { useAuthStore } from "./stores/auth";

const auth = useAuthStore();
auth.fetchMe();

const app = createApp(App)
app.use(createPinia())
app.use(router)
app.mount("#app")
