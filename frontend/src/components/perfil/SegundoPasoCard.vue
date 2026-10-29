<script setup>
// Segundo paso al entrar (29-oct-2026, seguridad tanda 2): el super admin, además de la clave, pone
// el código de seis números de una app. Acá se activa: la clave (para que una sesión ajena no ate
// la cuenta a otro teléfono), el QR y un primer código que prueba que quedó bien. Ya activo no se
// desactiva desde acá: perder el teléfono se resuelve por consola (`seguridad:segundo_paso:reiniciar`).
import { onMounted, ref } from 'vue'
import QRCode from 'qrcode'
import { getSegundoPaso, iniciarSegundoPaso, activarSegundoPaso } from '../../lib/api'
import { useAuthStore } from '../../stores/auth'
import DsSpinner from '../../design-system/components/Spinner.vue'

const auth = useAuthStore()

const estado   = ref(null)
const paso     = ref('estado') // estado → clave → qr
const clave    = ref('')
const secreto  = ref('')
const qr       = ref('')
const codigo   = ref('')
const error    = ref('')
const enviando = ref(false)

onMounted(async () => {
  try { estado.value = (await getSegundoPaso()).data } catch { estado.value = null }
})

function textoDeError(e, porDefecto) {
  return e?.response?.data?.error || e?.response?.data?.errors?.join(', ') || porDefecto
}

async function empezar() {
  error.value = ''
  enviando.value = true
  try {
    const { data } = await iniciarSegundoPaso(clave.value)
    secreto.value = data.secreto
    qr.value = await QRCode.toDataURL(data.uri, { margin: 2, width: 220 })
    clave.value = ''
    paso.value = 'qr'
  } catch (e) {
    error.value = textoDeError(e, 'No se pudo empezar. Probá de nuevo.')
  } finally {
    enviando.value = false
  }
}

async function activar() {
  error.value = ''
  enviando.value = true
  try {
    estado.value = (await activarSegundoPaso(codigo.value)).data
    paso.value = 'estado'
    secreto.value = ''
    qr.value = ''
    codigo.value = ''
    // `/me` deja de decir «pendiente»: la app ya lo deja ir a todos lados.
    await auth.fetchMe()
  } catch (e) {
    error.value = textoDeError(e, 'No se pudo activar. Probá de nuevo.')
  } finally {
    enviando.value = false
  }
}
</script>

<template>
  <div class="spc" data-testid="segundo-paso">
    <div class="spc__header">
      <div>
        <div class="spc__title">Segundo paso para entrar</div>
        <div class="spc__desc">Además de la contraseña, un código de seis números que cambia cada 30 segundos en tu teléfono.</div>
      </div>
      <span v-if="estado?.activo" class="spc__pill spc__pill--on" data-testid="segundo-paso-estado">Activo</span>
      <span v-else-if="estado" class="spc__pill" data-testid="segundo-paso-estado">Sin activar</span>
    </div>

    <div v-if="!estado" class="spc__cargando"><DsSpinner :size="18" /></div>

    <template v-else-if="estado.activo">
      <p class="spc__texto">
        Cada vez que entrás te pedimos el código de tu app. Si cambiás o perdés el teléfono, hay que reiniciarlo desde la plataforma
        (no se puede sacar desde acá, a propósito: quien tenga tu sesión no le puede quitar el candado a la cuenta).
      </p>
    </template>

    <template v-else-if="paso === 'estado' || paso === 'clave'">
      <div v-if="estado.obligatorio" class="spc__aviso">
        Tu cuenta abre todas las organizaciones: hasta activarlo no podés seguir.
      </div>
      <ol class="spc__pasos">
        <li>Instalá una app de códigos en el teléfono: Google Authenticator, 1Password, Authy o la que uses.</li>
        <li>Escribí tu contraseña y escaneá el código QR que aparece.</li>
        <li>Escribí el código que te muestra la app.</li>
      </ol>
      <label class="spc__label" for="spc-clave">Tu contraseña</label>
      <input id="spc-clave" v-model="clave" type="password" class="spc__input" autocomplete="current-password"
             data-testid="segundo-paso-clave" @keyup.enter="clave && empezar()" />
      <div v-if="error" class="spc__error">{{ error }}</div>
      <button class="spc__btn" :disabled="!clave || enviando" data-testid="segundo-paso-empezar" @click="empezar">
        <DsSpinner v-if="enviando" :size="16" />
        <span v-else>Mostrar el código QR</span>
      </button>
    </template>

    <template v-else>
      <div class="spc__qr-fila">
        <img :src="qr" alt="Código QR para tu app" class="spc__qr" width="180" height="180" />
        <div class="spc__qr-texto">
          <p class="spc__texto">Escanealo con la app. Si no podés, cargá esta clave a mano:</p>
          <code class="spc__secreto" data-testid="segundo-paso-secreto">{{ secreto }}</code>
        </div>
      </div>
      <label class="spc__label" for="spc-codigo">El código que muestra la app</label>
      <input id="spc-codigo" v-model.trim="codigo" class="spc__input spc__input--codigo" inputmode="numeric"
             autocomplete="one-time-code" maxlength="6" placeholder="123456" data-testid="segundo-paso-codigo"
             @keyup.enter="codigo.length === 6 && activar()" />
      <div v-if="error" class="spc__error">{{ error }}</div>
      <button class="spc__btn" :disabled="codigo.length !== 6 || enviando" data-testid="segundo-paso-activar" @click="activar">
        <DsSpinner v-if="enviando" :size="16" />
        <span v-else>Activar</span>
      </button>
    </template>
  </div>
</template>

<style scoped>
.spc { background: var(--c-paper); border: 1.5px solid var(--c-slate-200); border-radius: 14px; padding: 1.25rem; margin-bottom: 1rem; display: flex; flex-direction: column; gap: .75rem; }
.spc__header { display: flex; justify-content: space-between; align-items: flex-start; gap: 1rem; }
.spc__title { font-size: .95rem; font-weight: 700; color: var(--c-slate-900); }
.spc__desc { font-size: .78rem; color: var(--c-slate-500); margin-top: .1rem; }
.spc__pill { font-size: .72rem; font-weight: 700; border-radius: 999px; padding: .2rem .6rem; background: var(--c-slate-100); color: var(--c-slate-600); white-space: nowrap; }
.spc__pill--on { background: var(--c-leaf-100); color: var(--c-leaf-700); }
.spc__cargando { display: flex; justify-content: center; padding: .5rem; }
.spc__aviso { background: var(--c-amber-100); border: 1px solid var(--c-amber-500); color: var(--c-rust-600); border-radius: 10px; padding: .6rem .8rem; font-size: .82rem; font-weight: 600; }
.spc__pasos { margin: 0; padding-left: 1.1rem; font-size: .82rem; color: var(--c-slate-700); display: flex; flex-direction: column; gap: .2rem; }
.spc__texto { font-size: .82rem; color: var(--c-slate-700); margin: 0; line-height: 1.5; }
.spc__label { font-size: .8rem; font-weight: 600; color: var(--c-slate-700); }
.spc__input { padding: .55rem .75rem; border: 1.5px solid var(--c-slate-200); border-radius: 8px; font-size: .875rem; color: var(--c-slate-900); background: var(--c-paper); outline: none; width: 100%; max-width: 320px; box-sizing: border-box; }
.spc__input:focus { border-color: var(--c-leaf-900); }
.spc__input--codigo { letter-spacing: .3em; font-variant-numeric: tabular-nums; font-size: 1.05rem; max-width: 180px; }
.spc__error { font-size: .8rem; color: var(--c-rust-600); }
.spc__btn { align-self: flex-start; display: inline-flex; align-items: center; gap: .4rem; background: var(--c-leaf-900); color: var(--c-paper); border: 0; border-radius: 9px; padding: .55rem 1rem; font-size: .85rem; font-weight: 600; cursor: pointer; }
.spc__btn:disabled { opacity: .6; cursor: not-allowed; }
.spc__qr-fila { display: flex; gap: 1rem; align-items: center; flex-wrap: wrap; }
.spc__qr { border: 1px solid var(--c-slate-200); border-radius: 10px; }
.spc__qr-texto { flex: 1; min-width: 180px; display: flex; flex-direction: column; gap: .4rem; }
.spc__secreto { font-size: .82rem; background: var(--c-slate-50); border: 1px solid var(--c-slate-200); border-radius: 6px; padding: .35rem .5rem; word-break: break-all; letter-spacing: .05em; }
</style>
