<template>
  <div class="qr">

    <!-- Estado: cargando -->
    <div v-if="estado === 'cargando'" class="qr__loading">
      <div class="qr__logo">
        <svg viewBox="0 0 40 40" fill="none" class="qr__logo-icon">
          <circle cx="20" cy="20" r="18" stroke="#1b5e20" stroke-width="2" opacity=".2"/>
          <path d="M20 4C20 4 28 10 28 20C28 30 20 36 20 36C20 36 12 30 12 20C12 10 20 4 20 4Z" fill="#1b5e20" opacity=".8"/>
        </svg>
        <span class="qr__logo-text">Cultivo Espacial</span>
      </div>
      <div class="qr__spinner"></div>
      <div class="qr__loading-text">Verificando planta…</div>
    </div>

    <!-- Estado: no encontrada -->
    <div v-else-if="estado === 'no_encontrada'" class="qr__screen">
      <div class="qr__icon qr__icon--warn">⚠️</div>
      <h2 class="qr__title">Planta no encontrada</h2>
      <p class="qr__desc">El código QR escaneado no corresponde a ninguna planta registrada en el sistema.</p>
      <div class="qr__code-badge">{{ codigoQr }}</div>
    </div>

    <!-- Estado: sin permisos -->
    <div v-else-if="estado === 'sin_permisos'" class="qr__screen">
      <div class="qr__club-header" v-if="clubNombre">
        <div class="qr__club-logo" v-if="clubLogo">
          <img :src="clubLogo" :alt="clubNombre" />
        </div>
        <span class="qr__club-nombre">{{ clubNombre }}</span>
      </div>
      <div class="qr__icon qr__icon--lock">🔒</div>
      <h2 class="qr__title">Acceso restringido</h2>
      <p class="qr__desc">
        No tenés permisos suficientes para ver el detalle de esta planta.<br>
        Ponete en contacto con el administrador de <strong>{{ clubNombre || 'tu club' }}</strong>.
      </p>
      <div class="qr__plant-preview" v-if="plantaInfo">
        <div class="qr__plant-codigo">{{ plantaInfo.nombre }}</div>
        <div class="qr__plant-sub">{{ plantaInfo.lote?.codigo }}</div>
      </div>
      <button class="qr__btn-secondary" @click="irAlDashboard">
        Ir al inicio
      </button>
    </div>

    <!-- Estado: necesita login -->
    <div v-else-if="estado === 'login'" class="qr__screen">
      <div class="qr__logo qr__logo--top">
        <svg viewBox="0 0 40 40" fill="none" class="qr__logo-icon">
          <circle cx="20" cy="20" r="18" stroke="#1b5e20" stroke-width="2" opacity=".2"/>
          <path d="M20 4C20 4 28 10 28 20C28 30 20 36 20 36C20 36 12 30 12 20C12 10 20 4 20 4Z" fill="#1b5e20" opacity=".8"/>
        </svg>
        <span class="qr__logo-text">Cultivo Espacial</span>
      </div>

      <div class="qr__scan-badge">
        <i class="bi bi-qr-code-scan"></i>
        <span>QR escaneado</span>
      </div>

      <div class="qr__plant-card" v-if="plantaInfo">
        <div class="qr__plant-emoji">🌱</div>
        <div class="qr__plant-info">
          <div class="qr__plant-nombre">{{ plantaInfo.nombre }}</div>
          <div class="qr__plant-meta">
            <span v-if="plantaInfo.lote?.codigo">{{ plantaInfo.lote.codigo }}</span>
            <span v-if="plantaInfo.estado" class="qr__plant-estado">· {{ plantaInfo.estado }}</span>
          </div>
        </div>
      </div>

      <h2 class="qr__title qr__title--login">Iniciá sesión para ver el detalle</h2>

      <!-- Formulario de login inline -->
      <form class="qr__form" @submit.prevent="hacerLogin">
        <div class="qr__field">
          <label>Email</label>
          <input
            v-model="loginForm.email"
            type="email"
            placeholder="tu@email.com"
            autocomplete="email"
            :disabled="loginCargando"
          />
        </div>
        <div class="qr__field">
          <label>Contraseña</label>
          <input
            v-model="loginForm.password"
            type="password"
            placeholder="••••••••"
            autocomplete="current-password"
            :disabled="loginCargando"
          />
        </div>
        <div v-if="loginError" class="qr__error">
          <i class="bi bi-exclamation-triangle"></i> {{ loginError }}
        </div>
        <button type="submit" class="qr__btn-primary" :disabled="loginCargando">
          <div v-if="loginCargando" class="qr__spinner qr__spinner--sm"></div>
          <i v-else class="bi bi-box-arrow-in-right"></i>
          {{ loginCargando ? 'Ingresando…' : 'Ingresar' }}
        </button>
      </form>
    </div>

  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '../stores/auth'
import { useClubStore } from '../stores/club'
import { usePermissions } from '../composables/usePermissions'
import api from '../lib/api'

const route  = useRoute()
const router = useRouter()
const auth   = useAuthStore()
const club   = useClubStore()

const codigoQr   = route.params.codigo_qr
const estado     = ref('cargando')
const plantaInfo = ref(null)
const clubNombre = ref('')
const clubLogo   = ref('')

const loginForm    = ref({ email: '', password: '' })
const loginCargando = ref(false)
const loginError   = ref(null)

onMounted(async () => {
  await auth.ensureBootstrapped()

  // Buscar datos básicos de la planta (endpoint público)
  try {
    const { data } = await api.get(`/p/${codigoQr}`)
    plantaInfo.value = data
    clubNombre.value = data.club_nombre || ''
    clubLogo.value   = data.club_logo   || ''
  } catch {
    estado.value = 'no_encontrada'
    return
  }

  // Si no está autenticado → mostrar login contextual
  if (!auth.isAuthenticated) {
    estado.value = 'login'
    return
  }

  // Está autenticado → verificar permisos
  const { can } = usePermissions()
  if (!can('plantas', 'show')) {
    estado.value = 'sin_permisos'
    return
  }

  // Tiene permisos → ir directo
  router.replace({ name: 'planta-detalle', params: { id: plantaInfo.value.id } })
})

async function hacerLogin() {
  if (!loginForm.value.email || !loginForm.value.password) return
  loginCargando.value = true
  loginError.value    = null

  try {
    await auth.signIn(loginForm.value.email, loginForm.value.password)
    await club.fetch()

    // Verificar permisos post-login
    const { can } = usePermissions()
    if (!can('plantas', 'show')) {
      estado.value = 'sin_permisos'
      return
    }

    // Ir a la planta
    router.replace({ name: 'planta-detalle', params: { id: plantaInfo.value.id } })
  } catch (e) {
    loginError.value = e?.response?.data?.error || 'Email o contraseña incorrectos'
  } finally {
    loginCargando.value = false
  }
}

function irAlDashboard() {
  router.push('/')
}
</script>

<style scoped>
.qr {
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  background: linear-gradient(160deg, #f0fdf4 0%, #e8f5e9 50%, #f0fdf4 100%);
  padding: 1.5rem;
  font-family: system-ui, -apple-system, sans-serif;
}

/* Loading */
.qr__loading {
  display: flex; flex-direction: column; align-items: center; gap: 1.5rem;
  text-align: center;
}
.qr__spinner {
  width: 36px; height: 36px;
  border: 3px solid rgba(27,94,32,.15);
  border-top-color: #1b5e20;
  border-radius: 50%;
  animation: qr-spin .7s linear infinite;
}
.qr__spinner--sm { width: 16px; height: 16px; border-width: 2px; border-top-color: #fff; border-color: rgba(255,255,255,.3); }
@keyframes qr-spin { to { transform: rotate(360deg); } }
.qr__loading-text { font-size: .9rem; color: #4a7c59; font-weight: 500; }

/* Logo */
.qr__logo {
  display: flex; align-items: center; gap: .6rem;
}
.qr__logo--top { margin-bottom: .5rem; }
.qr__logo-icon { width: 32px; height: 32px; }
.qr__logo-text { font-size: 1.1rem; font-weight: 700; color: #1b5e20; letter-spacing: -.02em; }

/* Screens */
.qr__screen {
  background: white;
  border-radius: 20px;
  padding: 2.5rem 2rem;
  max-width: 400px;
  width: 100%;
  box-shadow: 0 20px 60px rgba(27,94,32,.12);
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 1rem;
  text-align: center;
}

.qr__club-header {
  display: flex; align-items: center; gap: .6rem;
  padding: .5rem 1rem; background: #f0fdf4;
  border-radius: 999px; margin-bottom: .25rem;
}
.qr__club-logo img { width: 24px; height: 24px; border-radius: 50%; object-fit: cover; }
.qr__club-nombre { font-size: .82rem; font-weight: 600; color: #1b5e20; }

.qr__icon { font-size: 3rem; line-height: 1; }
.qr__icon--warn { filter: grayscale(.2); }
.qr__icon--lock {}

.qr__title {
  font-size: 1.3rem; font-weight: 800; color: #1a1a1a;
  margin: 0; letter-spacing: -.02em;
}
.qr__title--login { font-size: 1.1rem; color: #374151; font-weight: 600; }

.qr__desc {
  font-size: .875rem; color: #6b7280; line-height: 1.6; margin: 0;
}

.qr__code-badge {
  font-family: monospace; font-size: .75rem; color: #94a3b8;
  background: #f8fafc; border: 1px solid #e2e8f0;
  padding: .4rem .8rem; border-radius: 6px;
}

/* Plant preview */
.qr__plant-card {
  display: flex; align-items: center; gap: .75rem;
  background: #f0fdf4; border: 1px solid #c8e6c9;
  border-radius: 12px; padding: .875rem 1.1rem;
  width: 100%; text-align: left;
}
.qr__plant-emoji { font-size: 1.5rem; flex-shrink: 0; }
.qr__plant-info  { flex: 1; min-width: 0; }
.qr__plant-nombre { font-size: .95rem; font-weight: 700; color: #1a1a1a; }
.qr__plant-meta   { font-size: .78rem; color: #60725d; margin-top: .15rem; }
.qr__plant-estado { color: #94a3b8; }
.qr__plant-preview {
  background: #f0fdf4; border: 1px solid #c8e6c9;
  border-radius: 10px; padding: .75rem 1rem;
  width: 100%;
}
.qr__plant-codigo { font-size: .9rem; font-weight: 700; color: #1a1a1a; }
.qr__plant-sub    { font-size: .75rem; color: #60725d; margin-top: .1rem; }

/* Scan badge */
.qr__scan-badge {
  display: inline-flex; align-items: center; gap: .4rem;
  background: #dcfce7; color: #1b5e20;
  font-size: .75rem; font-weight: 600;
  padding: .3rem .85rem; border-radius: 999px;
}

/* Form */
.qr__form {
  display: flex; flex-direction: column; gap: .75rem;
  width: 100%; margin-top: .25rem;
}
.qr__field {
  display: flex; flex-direction: column; gap: .3rem; text-align: left;
}
.qr__field label {
  font-size: .72rem; font-weight: 700; color: #374151;
  text-transform: uppercase; letter-spacing: .05em;
}
.qr__field input {
  background: #f4f8f4; border: 1.5px solid #d4e6d4;
  border-radius: 9px; padding: .65rem .9rem;
  font-size: .9rem; color: #1a1a1a; width: 100%; box-sizing: border-box;
  transition: border .15s; font-family: inherit;
}
.qr__field input:focus { outline: none; border-color: #1b5e20; background: #fff; }
.qr__field input:disabled { opacity: .6; }

.qr__error {
  background: #fef2f2; color: #dc2626; border-radius: 8px;
  padding: .6rem .9rem; font-size: .82rem;
  display: flex; align-items: center; gap: .5rem; text-align: left;
}

/* Buttons */
.qr__btn-primary {
  display: flex; align-items: center; justify-content: center; gap: .5rem;
  background: linear-gradient(135deg, #1b5e20, #2e7d32);
  color: #e8f5e9; border: none; padding: .8rem 1.5rem;
  border-radius: 10px; font-size: .9rem; font-weight: 600;
  cursor: pointer; transition: opacity .2s; width: 100%;
  box-shadow: 0 4px 14px rgba(27,94,32,.25);
}
.qr__btn-primary:hover:not(:disabled) { opacity: .9; }
.qr__btn-primary:disabled { opacity: .6; cursor: not-allowed; }

.qr__btn-secondary {
  display: inline-flex; align-items: center; gap: .4rem;
  background: transparent; color: #1b5e20;
  border: 1.5px solid #c8e6c9; padding: .6rem 1.25rem;
  border-radius: 9px; font-size: .85rem; font-weight: 500;
  cursor: pointer; transition: all .15s; margin-top: .5rem;
}
.qr__btn-secondary:hover { background: #f0fdf4; border-color: #1b5e20; }
</style>
