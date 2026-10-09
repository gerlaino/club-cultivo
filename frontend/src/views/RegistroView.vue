<template>
  <div class="herbario hb-pagina">
    <!-- Volver: el formulario se abre desde la página pública y tiene que tener salida a la vista. -->
    <button type="button" class="hb-volver" @click="volver">
      <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" aria-hidden="true"><path d="M19 12H5M11 18l-6-6 6-6"/></svg>
      Volver
    </button>
    <div class="hb-ficha">
      <RouterLink to="/bienvenida" class="hb-ficha__logo" aria-label="Volver a la página de inicio">
        <img src="/logo-ce-redondo.png" alt="Cultivo Espacial" />
      </RouterLink>

      <p class="hb-ceja">Autocultivo · cuenta nueva</p>
      <h1 class="hb-titulo">Probalo en tu cultivo</h1>
      <p class="hb-bajada">
        <template v-if="info">{{ info.dias_prueba }} días gratis, sin tarjeta.</template>
        Entrás en el momento; el mail lo confirmás después.
      </p>

      <form @submit.prevent="crear" novalidate class="hb-form">
        <div class="hb-campo">
          <label class="hb-label" for="rg-nombre">Tu nombre</label>
          <input id="rg-nombre" v-model="nombre" type="text" class="hb-input" autocomplete="name"
                 maxlength="80" :disabled="enviando" autofocus />
        </div>
        <div class="hb-campo">
          <label class="hb-label" for="rg-email">Mail</label>
          <input id="rg-email" v-model.trim="email" type="email" class="hb-input" autocomplete="email"
                 placeholder="vos@ejemplo.com" :disabled="enviando" />
          <span class="hb-ayuda">Es con lo que vas a entrar.</span>
        </div>
        <div class="hb-campo">
          <label class="hb-label" for="rg-pass">Contraseña</label>
          <input id="rg-pass" v-model="password" type="password" class="hb-input" autocomplete="new-password"
                 :disabled="enviando" />
          <span class="hb-ayuda">Mínimo {{ minimo }} caracteres.</span>
        </div>

        <!-- Campo trampa: una persona no lo ve; un robot lo completa y el backend lo descarta. -->
        <input v-model="sitio" type="text" name="sitio" class="rg__trampa" tabindex="-1" autocomplete="off" aria-hidden="true" />

        <!-- La edad es una declaración propia, aparte de los términos, y queda registrada
             (9-oct-2026): no hay cómo verificarla, pero declararla en falso es de quien lo hace. -->
        <label class="rg__check">
          <input v-model="mayor" type="checkbox" :disabled="enviando" />
          <span>Declaro que soy <strong>mayor de 18 años</strong>.</span>
        </label>

        <label class="rg__check">
          <input v-model="acepta" type="checkbox" :disabled="enviando" />
          <span>
            Leí y acepto los
            <RouterLink to="/terminos" target="_blank">Términos y condiciones</RouterLink>
            y la <RouterLink to="/privacidad" target="_blank">Política de privacidad</RouterLink>,
            y presto mi <strong>consentimiento expreso</strong> para que mis datos de cultivo y de
            salud se guarden para darme el servicio, también en servidores fuera de la Argentina.
          </span>
        </label>

        <div v-if="error" class="hb-error">
          {{ error }}
          <RouterLink v-if="yaExiste" to="/login" class="hb-link">Ir a ingresar</RouterLink>
        </div>

        <button class="hb-btn" type="submit" :disabled="enviando || !puedeEnviar">
          <DsSpinner v-if="enviando" :size="18" />
          <span v-else>Crear mi cuenta</span>
        </button>
      </form>

      <p class="hb-pie">
        ¿Ya tenés cuenta? <RouterLink to="/login" class="hb-link">Ingresá</RouterLink>
        · ¿Es para una organización? <RouterLink :to="{ path: '/bienvenida/organizaciones', hash: '#contacto' }" class="hb-link">Escribinos</RouterLink>
      </p>
    </div>
  </div>
</template>

<script setup>
// AUTOREGISTRO DE USO PERSONAL (plan A de Germán, 4-oct-2026): nombre, mail y contraseña, y entra
// en el momento. El backend arma la cuenta (`Registros::CrearPersonal`) y guarda la constancia de
// los términos; acá, después de crearla, se entra con el login de siempre — así la sesión, la
// cookie y el destino por rol son los mismos que para cualquiera.
//
// Los días de prueba y el mínimo de la contraseña los dice el backend (`GET /public/registro`).
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { cargarFuentesHerbario } from '../lib/fuentesHerbario.js'
import '../assets/herbario.css'
import DsSpinner from '../design-system/components/Spinner.vue'
import { getRegistroInfo, registrarPersonal } from '../lib/api.js'
import { useAuthStore } from '../stores/auth'

const auth = useAuthStore()
const router = useRouter()
cargarFuentesHerbario()

// Si llegó desde la página, vuelve a donde estaba; si abrió el link directo, a la página.
function volver () {
  if (window.history.state?.back) router.back()
  else router.push('/bienvenida')
}

const info     = ref(null)
const nombre   = ref('')
const email    = ref('')
const password = ref('')
const acepta   = ref(false)
const mayor    = ref(false)
const sitio    = ref('')
const enviando = ref(false)
const error    = ref(null)
const yaExiste = ref(false)

const minimo = computed(() => info.value?.password_minimo || 8)
const puedeEnviar = computed(() => nombre.value.trim() && email.value && password.value && mayor.value && acepta.value)

onMounted(async () => {
  try { info.value = (await getRegistroInfo()).data } catch {}
})

async function crear () {
  error.value = null
  yaExiste.value = false
  if (password.value.length < minimo.value) {
    error.value = `La contraseña tiene que tener al menos ${minimo.value} caracteres.`
    return
  }
  enviando.value = true
  try {
    await registrarPersonal({
      nombre: nombre.value.trim(), email: email.value, password: password.value,
      acepta_terminos: acepta.value, mayor_de_edad: mayor.value, sitio: sitio.value,
    })
  } catch (e) {
    const status = e?.response?.status
    error.value = status === 429
      ? 'Hubo demasiados intentos desde esta conexión. Probá de nuevo en un rato.'
      : (e?.response?.data?.error || 'No se pudo crear la cuenta. Probá de nuevo.')
    yaExiste.value = /Ya hay una cuenta/.test(error.value)
    enviando.value = false
    return
  }
  // La cuenta ya existe: si el login fallara (backend despertando), que entre por /login.
  try {
    await auth.login(email.value, password.value)
  } catch {
    error.value = 'Tu cuenta está creada, pero no pudimos hacerte entrar. Ingresá con tu mail y tu contraseña.'
    yaExiste.value = true
  } finally {
    enviando.value = false
  }
}
</script>

<style scoped>
/* Las piezas (ficha, campos, botón) son las de `assets/herbario.css`; acá sólo lo propio. */
.rg__trampa { position: absolute; left: -10000px; width: 1px; height: 1px; opacity: 0; }

.rg__check { display: flex; gap: .65rem; align-items: flex-start; font-size: .8rem; color: var(--hb-tinta-2); line-height: 1.5; cursor: pointer; }
.rg__check input { margin-top: .2rem; width: 18px; height: 18px; flex-shrink: 0; accent-color: var(--hb-verde); }
.rg__check a { color: var(--hb-verde); font-weight: 600; }
</style>
