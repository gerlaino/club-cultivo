<template>
  <!-- Una sola ficha: el login es una puerta, no un folleto. Lo que cuenta qué es la plataforma
       vive en /bienvenida. Misma dirección visual que la página pública («Herbario»). -->
  <div class="herbario hb-pagina">
    <button type="button" class="hb-volver" @click="volver">
      <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" aria-hidden="true"><path d="M19 12H5M11 18l-6-6 6-6"/></svg>
      Volver
    </button>

    <div class="lv__col">
      <div class="hb-ficha">
        <RouterLink to="/bienvenida" class="hb-ficha__logo" aria-label="Volver a la página de inicio">
          <img src="/logo-ce-redondo.png" alt="Cultivo Espacial" />
        </RouterLink>

        <p class="hb-ceja">Cultivo Espacial</p>
        <h1 class="hb-titulo">Ingresá</h1>

        <form @submit.prevent="onSubmit" novalidate class="hb-form">
          <div class="hb-campo">
            <label class="hb-label" for="lv-usuario">Usuario</label>
            <input id="lv-usuario" v-model.trim="email" type="email" class="hb-input"
                   placeholder="tu@organizacion.org"
                   autocomplete="username" required :disabled="auth.loading" />
          </div>

          <div class="hb-campo">
            <label class="hb-label" for="lv-pass">Contraseña</label>
            <div class="lv__pass">
              <input id="lv-pass" v-model="password" :type="showPass ? 'text' : 'password'"
                     class="hb-input lv__pass-input"
                     autocomplete="current-password" required :disabled="auth.loading" />
              <button type="button" class="lv__eye" @click="showPass=!showPass" tabindex="-1"
                      :aria-label="showPass ? 'Ocultar contraseña' : 'Mostrar contraseña'">
                <svg v-if="!showPass" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                  <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/>
                </svg>
                <svg v-else width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                  <path d="M17.94 17.94A10.07 10.07 0 0112 20c-7 0-11-8-11-8a18.45 18.45 0 015.06-5.94M9.9 4.24A9.12 9.12 0 0112 4c7 0 11 8 11 8a18.5 18.5 0 01-2.16 3.19m-6.72-1.07a3 3 0 11-4.24-4.24"/>
                  <line x1="1" y1="1" x2="23" y2="23"/>
                </svg>
              </button>
            </div>
            <RouterLink to="/olvide-contrasena" class="hb-link lv__olvide">¿Olvidaste tu contraseña?</RouterLink>
          </div>

          <!-- Espera larga pero normal (servidor despertando). No es un error: va como nota,
               no en rojo, y sólo aparece si no hay un error de verdad que mostrar. -->
          <Transition name="err">
            <div v-if="auth.aviso && !auth.error" class="hb-nota hb-nota--fila">
              <DsSpinner :size="13" />
              {{ auth.aviso }}
            </div>
          </Transition>

          <Transition name="err">
            <div v-if="auth.error" class="hb-error">{{ auth.error }}</div>
          </Transition>

          <button class="hb-btn" type="submit" :disabled="auth.loading || retrying || !email || !password">
            <DsSpinner v-if="auth.loading || retrying" :size="18" />
            <span v-else>Ingresar</span>
          </button>
        </form>

        <p class="hb-pie">¿Cultivás en casa y no tenés cuenta? <RouterLink to="/registro" class="hb-link">Probá gratis</RouterLink></p>
      </div>

      <!-- Qué build está corriendo. Es la forma de saber, sin adivinar, si el dispositivo
           tiene la última versión o una cacheada. -->
      <div class="lv__ver" :title="`Build ${BUILD} · ${BUILD_AT}`">v0.1.0 beta · {{ BUILD }}</div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '../stores/auth'
import DsSpinner from '../design-system/components/Spinner.vue'
import { cargarFuentesHerbario } from '../lib/fuentesHerbario.js'
import '../assets/herbario.css'

const auth = useAuthStore()
const route = useRoute()
const router = useRouter()
cargarFuentesHerbario()

// Siempre a la página, nunca «atrás»: después de cerrar sesión, atrás es una pantalla de adentro
// que el guard vuelve a mandar acá, y el botón parecería no hacer nada.
function volver () {
  router.push('/bienvenida')
}

const email      = ref('')
const password   = ref('')
const showPass   = ref(false)
const BUILD    = __APP_BUILD__
const BUILD_AT = __APP_BUILD_AT__
const retrying     = ref(false)
const lastSubmitAt = ref(0)
const COOLDOWN_MS  = 600

// Al usuario lo expulsó el interceptor (su club apagó el módulo de su rol mientras estaba
// adentro). El motivo viajó por sessionStorage porque en el medio hay una recarga completa.
onMounted(() => {
  try {
    const motivo = sessionStorage.getItem('login_error')
    if (motivo) {
      auth.error = motivo
      sessionStorage.removeItem('login_error')
    }
  } catch {}
})

function esErrorDeConexion(e) {
  const status = e?.response?.status
  return !status || status >= 500
}

async function intentarLogin(opciones = {}) {
  await auth.login(email.value, password.value, route.query.redirect || null, opciones)
}

async function onSubmit() {
  const now = Date.now()
  if (auth.loading || retrying.value || now - lastSubmitAt.value < COOLDOWN_MS) return
  lastSubmitAt.value = now
  try {
    await intentarLogin()
  } catch (e) {
    // Sólo se reintenta lo que puede andar la próxima vez: un servidor dormido o una conexión
    // que cortó. Una contraseña equivocada no mejora sola, y su mensaje ya está puesto.
    if (!esErrorDeConexion(e)) return

    auth.error = 'El servidor no respondió. Reintentando…'
    retrying.value = true
    setTimeout(async () => {
      try {
        // `conservarError`: sin esto el reintento borraba el "Reintentando…" y dejaba el
        // formulario mudo con el botón girando — lo que se ve como un cuelgue.
        await intentarLogin({ conservarError: true })
      } catch (_) {
        // El mensaje definitivo lo puso el store. Nunca se queda sin uno.
      } finally {
        retrying.value = false
      }
    }, 2000)
  }
}
</script>

<style scoped>
/* Las piezas (ficha, campos, botón, nota, error) son las de `assets/herbario.css`; acá sólo lo propio. */
.lv__col { width: 100%; max-width: 446px; display: flex; flex-direction: column; align-items: center; }

.lv__pass { position: relative; }
.lv__pass-input { padding-right: 2.9rem; }
.lv__eye {
  position: absolute; top: 0; right: 0; bottom: 0; width: 2.9rem;
  display: flex; align-items: center; justify-content: center;
  background: none; border: none; color: var(--hb-tinta-2); cursor: pointer;
}
.lv__eye:hover { color: var(--hb-tinta); }
.lv__olvide { align-self: flex-end; margin-top: 2px; font-size: .8rem; }

.err-enter-active, .err-leave-active { transition: all .2s; }
.err-enter-from, .err-leave-to { opacity: 0; transform: translateY(-4px); }

.lv__ver { margin-top: 14px; font: 11px var(--hb-mono); color: var(--hb-tinta-2); opacity: .6; text-align: center; }
</style>
