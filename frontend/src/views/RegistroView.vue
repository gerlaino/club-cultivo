<template>
  <div class="rg">
    <div class="rg__card">
      <RouterLink to="/bienvenida" class="rg__logo" aria-label="Volver a la página de inicio">
        <img src="/logo-ce-redondo.png" class="rg__logo-img" alt="Cultivo Espacial" />
      </RouterLink>

      <h1 class="rg__h">Probá Cultivo Espacial en tu cultivo</h1>
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
import DsSpinner from '../design-system/components/Spinner.vue'
import { getRegistroInfo, registrarPersonal } from '../lib/api.js'
import { useAuthStore } from '../stores/auth'

const auth = useAuthStore()

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
*, *::before, *::after { box-sizing: border-box; }

.rg {
  position: fixed; inset: 0; overflow: auto;
  display: grid; place-items: center; padding: 1.25rem 1rem;
  font-family: var(--font-ui, 'Inter', system-ui, sans-serif);
  background:
    radial-gradient(ellipse 70% 70% at 50% 50%, rgba(45,74,62,.45) 0%, transparent 65%),
    linear-gradient(170deg, var(--c-leaf-900) 0%, #0B1F16 45%, var(--c-leaf-900) 100%);
}
.rg__card {
  width: 100%; max-width: 430px;
  background: rgba(255,255,255,.97);
  border-radius: 26px; padding: 1.75rem 1.5rem 1.4rem;
  box-shadow: 0 0 0 1px rgba(255,255,255,.15), 0 40px 80px rgba(0,0,0,.7);
  display: flex; flex-direction: column; gap: .9rem;
}
.rg__logo { display: flex; justify-content: center; }
.rg__logo-img { width: 56px; height: 56px; border-radius: 50%; object-fit: cover; }
.rg__h { margin: 0; font-size: 1.2rem; font-weight: 800; color: var(--c-slate-900); letter-spacing: -.01em; text-align: center; }
.rg__p { margin: 0; font-size: .84rem; color: var(--c-slate-500); line-height: 1.55; text-align: center; }

.rg__form { display: flex; flex-direction: column; gap: .8rem; }
.rg__field { display: flex; flex-direction: column; gap: .28rem; }
.rg__label { font-size: .65rem; font-weight: 700; color: var(--c-slate-700); text-transform: uppercase; letter-spacing: .07em; }
.rg__ayuda { font-size: .72rem; color: var(--c-slate-500); }
.rg__input {
  width: 100%; border: 1.5px solid var(--c-slate-200); background: var(--c-slate-50);
  border-radius: 12px; padding: .8rem .9rem; font-size: .9rem; color: var(--c-slate-900); outline: none;
  transition: all .2s;
}
.rg__input:focus { border-color: var(--c-leaf-800); background: #fff; box-shadow: 0 0 0 3px rgba(26,61,46,.1); }
.rg__input:disabled { opacity: .55; }
.rg__trampa { position: absolute; left: -10000px; width: 1px; height: 1px; opacity: 0; }

.rg__check { display: flex; gap: .6rem; align-items: flex-start; font-size: .78rem; color: var(--c-slate-600); line-height: 1.5; cursor: pointer; }
.rg__check input { margin-top: .2rem; width: 18px; height: 18px; flex-shrink: 0; accent-color: var(--c-leaf-700); }
.rg__check a { color: var(--c-leaf-700); font-weight: 600; }

.rg__error {
  background: var(--c-rust-100); border: 1px solid #fecaca; color: var(--c-rust-600);
  padding: .55rem .8rem; border-radius: 9px; font-size: .8rem; font-weight: 500; line-height: 1.5;
  display: flex; flex-direction: column; gap: .3rem;
}

.rg__btn {
  display: flex; align-items: center; justify-content: center; gap: .45rem;
  width: 100%; padding: .9rem; min-height: 48px;
  background: linear-gradient(135deg, var(--c-leaf-800) 0%, var(--c-leaf-600) 100%);
  color: #fff; border: none; border-radius: 12px;
  font-size: .95rem; font-weight: 700; cursor: pointer; transition: all .25s;
  box-shadow: 0 4px 16px rgba(15,42,30,.45);
}
.rg__btn:hover:not(:disabled) { transform: translateY(-2px); }
.rg__btn:disabled { opacity: .45; cursor: not-allowed; }

.rg__pie { margin: 0; font-size: .78rem; color: var(--c-slate-500); text-align: center; line-height: 1.7; }
.rg__link { color: var(--c-leaf-700); font-weight: 600; text-decoration: none; }
.rg__link:hover { text-decoration: underline; }
</style>
