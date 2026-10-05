<template>
  <div class="herbario hb-pagina">
    <RouterLink to="/login" class="hb-volver">
      <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" aria-hidden="true"><path d="M19 12H5M11 18l-6-6 6-6"/></svg>
      Volver a ingresar
    </RouterLink>

    <div class="hb-ficha">
      <RouterLink to="/bienvenida" class="hb-ficha__logo" aria-label="Volver a la página de inicio">
        <img src="/logo-ce-redondo.png" alt="Cultivo Espacial" />
      </RouterLink>
      <p class="hb-ceja">Recuperar acceso</p>

      <!-- ── Pedir el link ── -->
      <template v-if="modo === 'pedir'">
        <h1 class="hb-titulo">¿Olvidaste tu contraseña?</h1>
        <p class="hb-bajada">
          Escribí tu usuario de ingreso o tu mail personal y te mandamos un link para elegir una nueva.
        </p>

        <form v-if="!resultado" @submit.prevent="pedir" novalidate class="hb-form">
          <div class="hb-campo">
            <label class="hb-label" for="ra-usuario">Usuario o mail</label>
            <input id="ra-usuario" v-model.trim="usuario" type="text" class="hb-input"
                   placeholder="admin@tuorganizacion.com" autocomplete="username"
                   :disabled="enviando" autofocus />
          </div>
          <div v-if="error" class="hb-error">{{ error }}</div>
          <button class="hb-btn" type="submit" :disabled="enviando || !usuario">
            <DsSpinner v-if="enviando" :size="18" />
            <span v-else>Mandarme el link</span>
          </button>
        </form>

        <!-- Lo que pasó, dicho con lo que la persona tiene que hacer a continuación. -->
        <div v-else class="hb-nota" :class="{ 'hb-nota--aviso': resultado.sin_mail }">
          <p>{{ resultado.mensaje }}</p>
          <button v-if="resultado.sin_mail" type="button" class="hb-link" @click="resultado = null">
            Probar con otro usuario
          </button>
        </div>
      </template>

      <!-- ── Elegir la nueva ── -->
      <template v-else>
        <h1 class="hb-titulo">Elegí una contraseña nueva</h1>

        <div v-if="listo" class="hb-nota">
          <p>Listo. Tu contraseña cambió: entrá con <strong>{{ listo }}</strong> y la nueva.</p>
          <RouterLink to="/login" class="hb-btn ra__btn-listo">Ir a ingresar</RouterLink>
        </div>

        <div v-else-if="!token" class="hb-nota hb-nota--aviso">
          <p>A este link le falta el código. Abrilo desde el mail que te mandamos, o pedí uno nuevo.</p>
          <RouterLink to="/olvide-contrasena" class="hb-link">Pedir un link nuevo</RouterLink>
        </div>

        <form v-else @submit.prevent="restablecer" novalidate class="hb-form">
          <p class="hb-bajada">Mínimo 8 caracteres. Después entrás con tu usuario de siempre y esta contraseña.</p>
          <div class="hb-campo">
            <label class="hb-label" for="ra-pass">Contraseña nueva</label>
            <input id="ra-pass" v-model="password" type="password" class="hb-input"
                   autocomplete="new-password" :disabled="enviando" autofocus />
          </div>
          <div class="hb-campo">
            <label class="hb-label" for="ra-pass2">Repetila</label>
            <input id="ra-pass2" v-model="password2" type="password" class="hb-input"
                   autocomplete="new-password" :disabled="enviando" />
          </div>
          <div v-if="error" class="hb-error">
            {{ error }}
            <RouterLink v-if="tokenInvalido" to="/olvide-contrasena" class="hb-link">Pedir un link nuevo</RouterLink>
          </div>
          <button class="hb-btn" type="submit" :disabled="enviando || !password || !password2">
            <DsSpinner v-if="enviando" :size="18" />
            <span v-else>Guardar contraseña</span>
          </button>
        </form>
      </template>
    </div>
  </div>
</template>

<script setup>
// «Olvidé mi contraseña», las dos mitades en una pantalla: pedir el link (`/olvide-contrasena`)
// y elegir la nueva con el token que trae el mail (`/restablecer?token=`). Es la misma tarjeta
// con otro formulario, así que vive en un solo componente. Misma ficha «Herbario» que el login y el
// registro (piezas en `assets/herbario.css`).
import { ref, computed } from 'vue'
import { useRoute } from 'vue-router'
import { solicitarRestablecimiento, restablecerContrasena } from '../lib/api'
import DsSpinner from '../design-system/components/Spinner.vue'
import { cargarFuentesHerbario } from '../lib/fuentesHerbario.js'
import '../assets/herbario.css'

cargarFuentesHerbario()

const route = useRoute()
const modo  = computed(() => (route.path === '/restablecer' ? 'elegir' : 'pedir'))
const token = computed(() => String(route.query.token || ''))

const usuario   = ref('')
const password  = ref('')
const password2 = ref('')
const enviando  = ref(false)
const error     = ref('')
const resultado = ref(null)   // { enviado, sin_mail, mensaje }
const listo     = ref('')     // el usuario con el que entrar, cuando la nueva ya se guardó
const tokenInvalido = ref(false)

function motivoDe(e, porDefecto) {
  return e?.response?.data?.error || e?.response?.data?.errors?.[0] || porDefecto
}

async function pedir() {
  if (!usuario.value || enviando.value) return
  enviando.value = true
  error.value = ''
  try {
    const { data } = await solicitarRestablecimiento(usuario.value)
    resultado.value = data
  } catch (e) {
    error.value = e?.response?.status === 429
      ? 'Demasiados intentos seguidos. Esperá unos minutos y probá de nuevo.'
      : motivoDe(e, 'No se pudo mandar el link. Probá de nuevo en un momento.')
  } finally {
    enviando.value = false
  }
}

async function restablecer() {
  if (enviando.value) return
  error.value = ''
  tokenInvalido.value = false
  if (password.value !== password2.value) {
    error.value = 'Las dos contraseñas no coinciden.'
    return
  }
  enviando.value = true
  try {
    const { data } = await restablecerContrasena(token.value, password.value, password2.value)
    listo.value = data.email
  } catch (e) {
    tokenInvalido.value = Boolean(e?.response?.data?.token_invalido)
    error.value = motivoDe(e, 'No se pudo guardar la contraseña. Probá de nuevo en un momento.')
  } finally {
    enviando.value = false
  }
}
</script>

<style scoped>
.ra__btn-listo { margin-top: .4rem; }
</style>
