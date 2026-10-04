<template>
  <div class="rg">
    <!-- Volver: el formulario se abre desde la página pública y tiene que tener salida a la vista. -->
    <button type="button" class="rg__volver" @click="volver">
      <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" aria-hidden="true"><path d="M19 12H5M11 18l-6-6 6-6"/></svg>
      Volver
    </button>
    <div class="rg__card">
      <RouterLink to="/bienvenida" class="rg__logo" aria-label="Volver a la página de inicio">
        <img src="/logo-ce-redondo.png" class="rg__logo-img" alt="Cultivo Espacial" />
      </RouterLink>

      <p class="rg__ceja">Uso personal · cuenta nueva</p>
      <h1 class="rg__h">Probalo en tu cultivo</h1>
      <p class="rg__p">
        <template v-if="info">{{ info.dias_prueba }} días gratis, sin tarjeta.</template>
        Entrás en el momento; el mail lo confirmás después.
      </p>

      <form @submit.prevent="crear" novalidate class="rg__form">
        <div class="rg__field">
          <label class="rg__label" for="rg-nombre">Tu nombre</label>
          <input id="rg-nombre" v-model="nombre" type="text" class="rg__input" autocomplete="name"
                 maxlength="80" :disabled="enviando" autofocus />
        </div>
        <div class="rg__field">
          <label class="rg__label" for="rg-email">Mail</label>
          <input id="rg-email" v-model.trim="email" type="email" class="rg__input" autocomplete="email"
                 placeholder="vos@ejemplo.com" :disabled="enviando" />
          <span class="rg__ayuda">Es con lo que vas a entrar.</span>
        </div>
        <div class="rg__field">
          <label class="rg__label" for="rg-pass">Contraseña</label>
          <input id="rg-pass" v-model="password" type="password" class="rg__input" autocomplete="new-password"
                 :disabled="enviando" />
          <span class="rg__ayuda">Mínimo {{ minimo }} caracteres.</span>
        </div>

        <!-- Campo trampa: una persona no lo ve; un robot lo completa y el backend lo descarta. -->
        <input v-model="sitio" type="text" name="sitio" class="rg__trampa" tabindex="-1" autocomplete="off" aria-hidden="true" />

        <label class="rg__check">
          <input v-model="acepta" type="checkbox" :disabled="enviando" />
          <span>
            Soy mayor de 18 años, leí y acepto los
            <RouterLink to="/terminos" target="_blank">Términos y condiciones</RouterLink>
            y la <RouterLink to="/privacidad" target="_blank">Política de privacidad</RouterLink>,
            y presto mi <strong>consentimiento expreso</strong> para que mis datos de cultivo y de
            salud se guarden para darme el servicio, también en servidores fuera de la Argentina.
          </span>
        </label>

        <div v-if="error" class="rg__error">
          {{ error }}
          <RouterLink v-if="yaExiste" to="/login" class="rg__link">Ir a ingresar</RouterLink>
        </div>

        <button class="rg__btn" type="submit" :disabled="enviando || !puedeEnviar">
          <DsSpinner v-if="enviando" :size="18" />
          <span v-else>Crear mi cuenta</span>
        </button>
      </form>

      <p class="rg__pie">
        ¿Ya tenés cuenta? <RouterLink to="/login" class="rg__link">Ingresá</RouterLink>
        · ¿Es para una organización? <RouterLink :to="{ path: '/bienvenida', hash: '#contacto' }" class="rg__link">Escribinos</RouterLink>
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
const sitio    = ref('')
const enviando = ref(false)
const error    = ref(null)
const yaExiste = ref(false)

const minimo = computed(() => info.value?.password_minimo || 8)
const puedeEnviar = computed(() => nombre.value.trim() && email.value && password.value && acepta.value)

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
      acepta_terminos: acepta.value, sitio: sitio.value,
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
/* Misma dirección visual que la página pública («Herbario»): papel, tinta verde, Fraunces. */
.rg {
  --hb-papel: #EEF5EF; --hb-papel-claro: #F8FBF7; --hb-tinta: #15301F; --hb-tinta-2: #4E6858;
  --hb-regla: #CDE0D2; --hb-verde: #2E6B4A; --hb-verde-osc: #1F5137; --hb-salvia: #BCD8C3;
  --hb-salvia-suave: #DCEDE1; --hb-error: #9B2C1E;
  position: fixed; inset: 0; overflow: auto; z-index: 1;
  display: grid; place-items: center; padding: 64px 16px 32px;
  background: var(--hb-papel); color: var(--hb-tinta);
  font: 16px/1.55 'Public Sans', system-ui, sans-serif;
}
.rg *, .rg *::before, .rg *::after { box-sizing: border-box; }
.rg__volver {
  position: fixed; top: max(14px, env(safe-area-inset-top)); left: 14px; z-index: 2;
  display: inline-flex; align-items: center; gap: 6px; min-height: 40px; padding: 0 14px;
  background: var(--hb-papel-claro); color: var(--hb-tinta); border: 1px solid var(--hb-regla); border-radius: 999px;
  font: 600 14px 'Public Sans', system-ui, sans-serif; cursor: pointer;
}
.rg__volver:hover { border-color: var(--hb-tinta); }
.rg__card {
  width: calc(100% - 6px); max-width: 440px; margin-right: 6px; /* la sombra de 6px no se sale */
  background: var(--hb-papel-claro); border: 1.5px solid var(--hb-verde); box-shadow: 6px 6px 0 var(--hb-salvia);
  padding: 28px 24px 22px; display: flex; flex-direction: column; gap: 14px;
}
.rg__logo { display: flex; justify-content: center; }
.rg__logo-img { width: 48px; height: 48px; border-radius: 50%; object-fit: cover; }
.rg__ceja { margin: 0; text-align: center; font: 500 11px 'JetBrains Mono', ui-monospace, monospace; letter-spacing: .14em; text-transform: uppercase; color: var(--hb-tinta-2); }
.rg__h { margin: -4px 0 0; font: 600 1.9rem/1.1 'Fraunces', Georgia, serif; letter-spacing: -.015em; text-align: center; }
.rg__p { margin: 0; font-size: .92rem; color: var(--hb-tinta-2); text-align: center; }

.rg__form { display: flex; flex-direction: column; gap: 14px; }
.rg__field { display: flex; flex-direction: column; gap: 5px; }
.rg__label { font: 500 11px 'JetBrains Mono', ui-monospace, monospace; letter-spacing: .1em; text-transform: uppercase; color: var(--hb-tinta-2); }
.rg__ayuda { font-size: .76rem; color: var(--hb-tinta-2); }
.rg__input {
  width: 100%; font: 16px 'Public Sans', system-ui, sans-serif; color: var(--hb-tinta);
  background: var(--hb-papel-claro); border: 1px solid var(--hb-regla); border-radius: 6px; padding: .75rem .85rem; outline: none;
}
.rg__input:focus { border-color: var(--hb-verde); box-shadow: 0 0 0 3px var(--hb-salvia-suave); }
.rg__input:disabled { opacity: .55; }
.rg__trampa { position: absolute; left: -10000px; width: 1px; height: 1px; opacity: 0; }

.rg__check { display: flex; gap: .65rem; align-items: flex-start; font-size: .8rem; color: var(--hb-tinta-2); line-height: 1.5; cursor: pointer; }
.rg__check input { margin-top: .2rem; width: 18px; height: 18px; flex-shrink: 0; accent-color: var(--hb-verde); }
.rg__check a { color: var(--hb-verde); font-weight: 600; }

.rg__error { border-left: 3px solid var(--hb-error); padding: .2rem 0 .2rem .7rem; color: var(--hb-error); font-size: .85rem; display: flex; flex-direction: column; gap: .3rem; }

.rg__btn {
  display: flex; align-items: center; justify-content: center; gap: .45rem;
  width: 100%; min-height: 50px; border-radius: 999px;
  background: var(--hb-verde); color: var(--hb-papel-claro); border: none;
  font: 600 16px 'Public Sans', system-ui, sans-serif; cursor: pointer; transition: background .2s;
}
.rg__btn:hover:not(:disabled) { background: var(--hb-verde-osc); }
.rg__btn:disabled { opacity: .4; cursor: not-allowed; }

.rg__pie { margin: 0; font-size: .82rem; color: var(--hb-tinta-2); text-align: center; line-height: 1.7; border-top: 1px dashed var(--hb-regla); padding-top: 12px; }
.rg__link { color: var(--hb-verde); font-weight: 600; text-decoration: none; }
.rg__link:hover { text-decoration: underline; }
</style>
