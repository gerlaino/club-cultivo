<template>
  <div class="ra">
    <div class="ra__card">
      <div class="ra__logo">
        <img src="/logo-ce-redondo.png" class="ra__logo-img" alt="Cultivo Espacial" />
      </div>

      <!-- ── Pedir el link ── -->
      <template v-if="modo === 'pedir'">
        <h1 class="ra__h">¿Olvidaste tu contraseña?</h1>
        <p class="ra__p">
          Escribí tu usuario de ingreso o tu mail personal y te mandamos un link para elegir una nueva.
        </p>

        <form v-if="!resultado" @submit.prevent="pedir" novalidate class="ra__form">
          <div class="ra__field">
            <label class="ra__label" for="ra-usuario">Usuario o mail</label>
            <input id="ra-usuario" v-model.trim="usuario" type="text" class="ra__input"
                   placeholder="admin@tuorganizacion.com" autocomplete="username"
                   :disabled="enviando" autofocus />
          </div>
          <div v-if="error" class="ra__error">{{ error }}</div>
          <button class="ra__btn" type="submit" :disabled="enviando || !usuario">
            <DsSpinner v-if="enviando" :size="18" />
            <span v-else>Mandarme el link</span>
          </button>
        </form>

        <!-- Lo que pasó, dicho con lo que la persona tiene que hacer a continuación. -->
        <div v-else class="ra__resultado" :class="{ 'ra__resultado--aviso': resultado.sin_mail }">
          <p>{{ resultado.mensaje }}</p>
          <button v-if="resultado.sin_mail" type="button" class="ra__link" @click="resultado = null">
            Probar con otro usuario
          </button>
        </div>
      </template>

      <!-- ── Elegir la nueva ── -->
      <template v-else>
        <h1 class="ra__h">Elegí una contraseña nueva</h1>

        <div v-if="listo" class="ra__resultado">
          <p>Listo. Tu contraseña cambió: entrá con <strong>{{ listo }}</strong> y la nueva.</p>
          <RouterLink to="/login" class="ra__btn ra__btn--link">Ir a ingresar</RouterLink>
        </div>

        <div v-else-if="!token" class="ra__resultado ra__resultado--aviso">
          <p>A este link le falta el código. Abrilo desde el mail que te mandamos, o pedí uno nuevo.</p>
          <RouterLink to="/olvide-contrasena" class="ra__link">Pedir un link nuevo</RouterLink>
        </div>

        <form v-else @submit.prevent="restablecer" novalidate class="ra__form">
          <p class="ra__p">Mínimo 8 caracteres. Después entrás con tu usuario de siempre y esta contraseña.</p>
          <div class="ra__field">
            <label class="ra__label" for="ra-pass">Contraseña nueva</label>
            <input id="ra-pass" v-model="password" type="password" class="ra__input"
                   autocomplete="new-password" :disabled="enviando" autofocus />
          </div>
          <div class="ra__field">
            <label class="ra__label" for="ra-pass2">Repetila</label>
            <input id="ra-pass2" v-model="password2" type="password" class="ra__input"
                   autocomplete="new-password" :disabled="enviando" />
          </div>
          <div v-if="error" class="ra__error">
            {{ error }}
            <RouterLink v-if="tokenInvalido" to="/olvide-contrasena" class="ra__link ra__link--inline">Pedir un link nuevo</RouterLink>
          </div>
          <button class="ra__btn" type="submit" :disabled="enviando || !password || !password2">
            <DsSpinner v-if="enviando" :size="18" />
            <span v-else>Guardar contraseña</span>
          </button>
        </form>
      </template>

      <RouterLink to="/login" class="ra__back">← Volver a ingresar</RouterLink>
    </div>
  </div>
</template>

<script setup>
// «Olvidé mi contraseña», las dos mitades en una pantalla: pedir el link (`/olvide-contrasena`)
// y elegir la nueva con el token que trae el mail (`/restablecer?token=`). Es la misma tarjeta
// con otro formulario, así que vive en un solo componente — igual que el login, del que toma la
// paleta pero no el cosmos: acá la persona vino a resolver un problema, no a que la reciban.
import { ref, computed } from 'vue'
import { useRoute } from 'vue-router'
import { solicitarRestablecimiento, restablecerContrasena } from '../lib/api'
import DsSpinner from '../design-system/components/Spinner.vue'

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
*, *::before, *::after { box-sizing: border-box; }

.ra {
  position: fixed; inset: 0; overflow: auto;
  display: grid; place-items: center; padding: 1.25rem;
  font-family: var(--font-ui, 'Inter', system-ui, sans-serif);
  background:
    radial-gradient(ellipse 70% 70% at 50% 50%, rgba(45,74,62,.45) 0%, transparent 65%),
    linear-gradient(170deg, #0F2A1E 0%, #0B1F16 45%, #0F2A1E 100%);
}
.ra__card {
  width: 100%; max-width: 400px;
  background: rgba(255,255,255,.97);
  border-radius: 26px; padding: 1.75rem 1.5rem 1.4rem;
  box-shadow: 0 0 0 1px rgba(255,255,255,.15), 0 40px 80px rgba(0,0,0,.7);
  display: flex; flex-direction: column; gap: .9rem;
}
.ra__logo { display: flex; justify-content: center; }
.ra__logo-img { width: 56px; height: 56px; border-radius: 50%; object-fit: cover; }
.ra__h { margin: 0; font-size: 1.15rem; font-weight: 800; color: var(--c-slate-900); letter-spacing: -.01em; text-align: center; }
.ra__p { margin: 0; font-size: .82rem; color: var(--c-slate-500); line-height: 1.55; text-align: center; }

.ra__form { display: flex; flex-direction: column; gap: .8rem; }
.ra__field { display: flex; flex-direction: column; gap: .28rem; }
.ra__label { font-size: .65rem; font-weight: 700; color: #374151; text-transform: uppercase; letter-spacing: .07em; }
.ra__input {
  width: 100%; border: 1.5px solid var(--c-slate-200); background: var(--c-slate-50);
  border-radius: 12px; padding: .8rem .9rem; font-size: .88rem; color: var(--c-slate-900); outline: none;
  transition: all .2s;
}
.ra__input:focus { border-color: var(--c-leaf-800, #1A3D2E); background: #fff; box-shadow: 0 0 0 3px rgba(26,61,46,.1); }
.ra__input:disabled { opacity: .55; }

.ra__error {
  background: var(--c-rust-100, #FEE2E2); border: 1px solid #fecaca; color: var(--c-rust-600, #DC2626);
  padding: .55rem .8rem; border-radius: 9px; font-size: .78rem; font-weight: 500; line-height: 1.5;
}

.ra__btn {
  display: flex; align-items: center; justify-content: center; gap: .45rem;
  width: 100%; padding: .9rem; text-decoration: none;
  background: linear-gradient(135deg, var(--c-leaf-800, #1A3D2E) 0%, var(--c-leaf-600, #3F6452) 100%);
  color: #fff; border: none; border-radius: 12px;
  font-size: .93rem; font-weight: 700; cursor: pointer; transition: all .25s;
  box-shadow: 0 4px 16px rgba(15,42,30,.45);
}
.ra__btn:hover:not(:disabled) { transform: translateY(-2px); }
.ra__btn:disabled { opacity: .45; cursor: not-allowed; }
.ra__btn--link { margin-top: .5rem; }

.ra__resultado {
  background: var(--c-leaf-50, #EEF5F0); border: 1px solid var(--c-leaf-100, #E8F0EB);
  border-radius: 12px; padding: .9rem 1rem; font-size: .84rem; color: var(--c-leaf-900, #0F2A1E); line-height: 1.55;
  display: flex; flex-direction: column; gap: .5rem;
}
.ra__resultado p { margin: 0; }
.ra__resultado--aviso { background: var(--c-amber-100, #FEF3C7); border-color: #F5D98B; color: #6B4A00; }

.ra__link {
  background: none; border: none; padding: 0; cursor: pointer;
  font-size: .8rem; font-weight: 700; color: var(--c-leaf-800, #1A3D2E); text-decoration: underline; align-self: flex-start;
}
.ra__link--inline { display: inline; margin-left: .35rem; color: inherit; }

.ra__back { align-self: center; font-size: .72rem; font-weight: 600; color: var(--c-slate-500); text-decoration: none; }
.ra__back:hover { color: var(--c-leaf-800, #1A3D2E); }
</style>
