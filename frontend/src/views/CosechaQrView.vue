<template>
  <div class="cqr">

    <div v-if="estado === 'cargando'" class="cqr__center">
      <i class="bi bi-arrow-repeat cqr__spin"></i>
    </div>

    <div v-else-if="estado === 'no_encontrada'" class="cqr__card">
      <div class="cqr__header">
        <span class="cqr__header-emoji">✂️</span>
        <div>
          <div class="cqr__header-club">Cultivo Espacial</div>
          <div class="cqr__header-sub">Trazabilidad de cosecha</div>
        </div>
      </div>
      <div class="cqr__body cqr__body--center">
        <div class="cqr__err-ico">⚠️</div>
        <div class="cqr__err-title">Cosecha no encontrada</div>
        <div class="cqr__err-desc">El código QR escaneado no corresponde a ninguna cosecha registrada.</div>
      </div>
    </div>

    <!-- Vista pública: info de cosecha sin login -->
    <div v-else-if="estado === 'publico'" class="cqr__card">
      <div class="cqr__header">
        <img v-if="clubLogo" :src="clubLogo" class="cqr__header-logo" />
        <span v-else class="cqr__header-emoji">✂️</span>
        <div>
          <div class="cqr__header-club">{{ clubNombre }}</div>
          <div class="cqr__header-sub">Cosecha · Trazabilidad</div>
        </div>
      </div>
      <div class="cqr__body cqr__body--center">
        <div class="cqr__cosecha-ico">🌾</div>
        <div class="cqr__cosecha-codigo">{{ cosechaInfo?.codigo }}</div>
        <div v-if="cosechaInfo?.genetica" class="cqr__cosecha-gen">{{ cosechaInfo.genetica.nombre }}</div>
        <div class="cqr__cosecha-plants">{{ cosechaInfo?.plants_count }} plantas</div>
      </div>
      <div class="cqr__login-hint">
        <button class="cqr__login-hint-btn" @click="estado = 'login'">
          <i class="bi bi-scissors"></i> Soy manicurador — Iniciar sesión
        </button>
      </div>
      <div class="cqr__footer"><span class="cqr__footer-dot"></span> {{ clubNombre }}</div>
    </div>

    <!-- Login para manicurador -->
    <div v-else-if="estado === 'login'" class="cqr__card">
      <div class="cqr__header">
        <img v-if="clubLogo" :src="clubLogo" class="cqr__header-logo" />
        <span v-else class="cqr__header-emoji">✂️</span>
        <div>
          <div class="cqr__header-club">{{ clubNombre }}</div>
          <div class="cqr__header-sub">Acceso del equipo</div>
        </div>
      </div>
      <div class="cqr__body">
        <div class="cqr__login-ref">
          🌾 <strong>{{ cosechaInfo?.codigo }}</strong> · {{ cosechaInfo?.plants_count }} plantas
        </div>
        <div class="cqr__login-title">Iniciá sesión para continuar</div>
        <form class="cqr__form" @submit.prevent="hacerLogin">
          <div class="cqr__field">
            <label>Email</label>
            <input v-model="loginForm.email" type="email" placeholder="tu@email.com" autocomplete="email" :disabled="loginCargando" />
          </div>
          <div class="cqr__field">
            <label>Contraseña</label>
            <input v-model="loginForm.password" type="password" placeholder="••••••••" autocomplete="current-password" :disabled="loginCargando" />
          </div>
          <div v-if="loginError" class="cqr__err-inline">{{ loginError }}</div>
          <button type="submit" class="cqr__btn-primary" :disabled="loginCargando">
            {{ loginCargando ? 'Ingresando…' : 'Ingresar' }}
          </button>
        </form>
      </div>
    </div>

  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '../stores/auth'
import { useClubStore } from '../stores/club'
import axios from 'axios'

const route  = useRoute()
const router = useRouter()
const auth   = useAuthStore()
const club   = useClubStore()

const codigoQr    = route.params.codigo_qr
const estado      = ref('cargando')
const cosechaInfo = ref(null)
const clubNombre  = ref('')
const clubLogo    = ref('')
const loginForm     = ref({ email: '', password: '' })
const loginCargando = ref(false)
const loginError    = ref(null)

onMounted(async () => {
  await auth.ensureBootstrapped()
  const base = (import.meta.env.VITE_API_URL || 'http://localhost:3001/api').replace(/\/api\/?$/, '')
  try {
    const { data } = await axios.get(`${base}/cos/${codigoQr}`, { timeout: 12000 })
    cosechaInfo.value = data
    clubNombre.value  = data.club_nombre || ''
    clubLogo.value    = data.club_logo   || ''
  } catch {
    estado.value = 'no_encontrada'
    return
  }

  if (auth.isAuthenticated) {
    router.replace(`/m/mnc/lotes/${cosechaInfo.value.id}`)
  } else {
    estado.value = 'login'
  }
})

async function hacerLogin() {
  loginCargando.value = true; loginError.value = null
  try {
    await auth.login(loginForm.value.email, loginForm.value.password)
    await club.fetch()
    router.replace(`/m/mnc/lotes/${cosechaInfo.value.id}`)
  } catch {
    loginError.value = 'Email o contraseña incorrectos'
  } finally { loginCargando.value = false }
}
</script>

<style scoped>
* { box-sizing: border-box; }
.cqr { min-height: 100dvh; display: flex; align-items: center; justify-content: center; background: linear-gradient(160deg,#1c1028 0%,#4a1d96 50%,#1c1028 100%); padding: 1.25rem; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, sans-serif; }
.cqr__center { color: #c4b5fd; font-size: 2.5rem; animation: spin .8s linear infinite; }
@keyframes spin { to { transform: rotate(360deg); } }
.cqr__card { width: 100%; max-width: 390px; background: #fff; border-radius: 20px; overflow: hidden; box-shadow: 0 24px 64px rgba(0,0,0,.4); }
.cqr__header { background: linear-gradient(135deg,#1c1028 0%,#4a1d96 60%,#7c3aed 100%); padding: 1.25rem 1.5rem; display: flex; align-items: center; gap: 1rem; }
.cqr__header-logo { width: 48px; height: 48px; border-radius: 12px; object-fit: cover; }
.cqr__header-emoji { font-size: 1.75rem; }
.cqr__header-club { font-size: 1rem; font-weight: 800; color: #fff; }
.cqr__header-sub  { font-size: .68rem; color: rgba(255,255,255,.6); text-transform: uppercase; letter-spacing: .06em; margin-top: .15rem; }
.cqr__body { padding: 1.5rem; display: flex; flex-direction: column; gap: 1rem; }
.cqr__body--center { align-items: center; text-align: center; }
.cqr__cosecha-ico   { font-size: 3.5rem; line-height: 1; }
.cqr__cosecha-codigo { font-family: monospace; font-size: 1.3rem; font-weight: 900; color: #0f172a; }
.cqr__cosecha-gen    { font-size: .9rem; color: #7c3aed; font-weight: 600; }
.cqr__cosecha-plants { font-size: .8rem; color: #64748b; }
.cqr__err-ico   { font-size: 3rem; }
.cqr__err-title { font-size: 1.1rem; font-weight: 800; color: #0f172a; }
.cqr__err-desc  { font-size: .82rem; color: #64748b; line-height: 1.5; }
.cqr__login-ref { text-align: center; font-size: .85rem; color: #374151; padding: .75rem; background: #f5f3ff; border-radius: 10px; }
.cqr__login-title { font-size: .95rem; font-weight: 700; color: #374151; }
.cqr__form { display: flex; flex-direction: column; gap: .75rem; }
.cqr__field { display: flex; flex-direction: column; gap: .3rem; }
.cqr__field label { font-size: .72rem; font-weight: 700; color: #374151; text-transform: uppercase; letter-spacing: .05em; }
.cqr__field input { background: #f8fafc; border: 1.5px solid #e2e8f0; border-radius: 9px; padding: .65rem .875rem; font-size: .9rem; color: #1a1a1a; outline: none; }
.cqr__field input:focus { border-color: #7c3aed; }
.cqr__err-inline { background: #fef2f2; border: 1px solid #fecaca; color: #dc2626; padding: .5rem .75rem; border-radius: 8px; font-size: .82rem; }
.cqr__btn-primary { width: 100%; background: #7c3aed; color: #fff; border: none; border-radius: 10px; padding: .875rem; font-size: .925rem; font-weight: 700; cursor: pointer; }
.cqr__btn-primary:disabled { opacity: .5; }
.cqr__login-hint { padding: .75rem 1.5rem; border-top: 1px solid #f1f5f9; display: flex; justify-content: center; }
.cqr__login-hint-btn { background: none; border: none; color: #94a3b8; font-size: .75rem; cursor: pointer; display: flex; align-items: center; gap: .35rem; }
.cqr__login-hint-btn:hover { color: #7c3aed; }
.cqr__footer { background: #f8fafc; border-top: 1px solid #f1f5f9; padding: .75rem 1.5rem; display: flex; align-items: center; gap: .5rem; font-size: .73rem; color: #64748b; }
.cqr__footer-dot { width: 7px; height: 7px; border-radius: 50%; background: #7c3aed; flex-shrink: 0; }
</style>
