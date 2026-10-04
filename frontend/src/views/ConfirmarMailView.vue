<template>
  <div class="cm">
    <div class="cm__card">
      <img src="/logo-ce-redondo.png" class="cm__logo" alt="Cultivo Espacial" />

      <template v-if="estado === 'cargando'">
        <DsSpinner :size="22" />
        <p class="cm__p">Confirmando tu mail…</p>
      </template>

      <template v-else-if="estado === 'ok'">
        <h1 class="cm__h">¡Listo, mail confirmado!</h1>
        <p class="cm__p">Gracias. Tu cuenta queda activa y no se va a pausar por esto.</p>
        <RouterLink :to="auth.isAuthenticated ? '/' : '/login'" class="cm__btn">
          {{ auth.isAuthenticated ? 'Volver a la app' : 'Ingresar' }}
        </RouterLink>
      </template>

      <template v-else>
        <h1 class="cm__h">No pudimos confirmarlo</h1>
        <p class="cm__p">{{ error }}</p>
        <form class="cm__form" @submit.prevent="reenviar">
          <input v-model.trim="email" type="email" class="cm__input" placeholder="Tu mail" autocomplete="email" />
          <button class="cm__btn" type="submit" :disabled="!email || enviando">Mandarme un link nuevo</button>
        </form>
        <p v-if="reenviado" class="cm__ok">Si ese mail tiene una cuenta sin confirmar, te mandamos un link nuevo.</p>
      </template>
    </div>
  </div>
</template>

<script setup>
// El link del mail de confirmación (`/registro/confirmar?token=…`). Se abre con o sin sesión: lo
// que importa es el token. Si la cuenta se había pausado por no confirmar, esto la despausa.
import { ref, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import DsSpinner from '../design-system/components/Spinner.vue'
import { confirmarMailRegistro, reenviarConfirmacion } from '../lib/api.js'
import { useAuthStore } from '../stores/auth'

const route = useRoute()
const auth  = useAuthStore()

const estado    = ref('cargando')
const error     = ref(null)
const email     = ref('')
const enviando  = ref(false)
const reenviado = ref(false)

onMounted(async () => {
  const token = route.query.token
  if (!token) {
    estado.value = 'error'
    error.value = 'A este link le falta el código. Abrilo desde el mail que te mandamos, o pedí uno nuevo.'
    return
  }
  try {
    await confirmarMailRegistro(String(token))
    estado.value = 'ok'
    // Que el aviso de «confirmá tu mail» desaparezca sin recargar.
    if (auth.isAuthenticated) auth.fetchMe().catch(() => {})
  } catch (e) {
    estado.value = 'error'
    error.value = e?.response?.data?.error || 'No se pudo confirmar. Probá de nuevo en un rato.'
  }
})

async function reenviar () {
  enviando.value = true
  try { await reenviarConfirmacion(email.value) } catch {}
  reenviado.value = true
  enviando.value = false
}
</script>

<style scoped>
.cm {
  position: fixed; inset: 0; overflow: auto; display: grid; place-items: center; padding: 1.25rem 1rem;
  font-family: var(--font-ui, 'Inter', system-ui, sans-serif);
  background: linear-gradient(170deg, var(--c-leaf-900) 0%, #0B1F16 45%, var(--c-leaf-900) 100%);
}
.cm__card {
  width: 100%; max-width: 400px; background: rgba(255,255,255,.97); border-radius: 26px;
  padding: 1.75rem 1.5rem; display: flex; flex-direction: column; align-items: center; gap: .9rem; text-align: center;
}
.cm__logo { width: 56px; height: 56px; border-radius: 50%; object-fit: cover; }
.cm__h { margin: 0; font-size: 1.15rem; font-weight: 800; color: var(--c-slate-900); }
.cm__p { margin: 0; font-size: .85rem; color: var(--c-slate-500); line-height: 1.55; }
.cm__form { display: flex; flex-direction: column; gap: .6rem; width: 100%; }
.cm__input { border: 1.5px solid var(--c-slate-200); background: var(--c-slate-50); border-radius: 12px; padding: .75rem .9rem; font-size: .9rem; }
.cm__btn {
  display: inline-flex; justify-content: center; align-items: center; width: 100%; min-height: 46px; padding: .8rem;
  background: linear-gradient(135deg, var(--c-leaf-800) 0%, var(--c-leaf-600) 100%);
  color: #fff; border: none; border-radius: 12px; font-weight: 700; font-size: .92rem; text-decoration: none; cursor: pointer;
}
.cm__btn:disabled { opacity: .45; cursor: not-allowed; }
.cm__ok { margin: 0; font-size: .8rem; color: var(--c-leaf-700); }
</style>
