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
          </div>
        </div>
      </div>

      <h2 class="qr__title qr__title--login">Iniciá sesión para ver el detalle</h2>

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

    <!-- Estado: manicura_pesaje — pesaje por QR -->
    <div v-else-if="estado === 'manicura_pesaje'" class="qr__screen qr__screen--pesaje">

      <!-- Header del lote -->
      <div class="qr__lote-header">
        <div class="qr__lote-badge">
          <i class="bi bi-box-seam"></i>
          {{ plantaDetalle?.lote?.codigo }}
        </div>
        <div class="qr__lote-genetica" v-if="plantaDetalle?.genetica">
          {{ plantaDetalle.genetica.nombre }}
        </div>
      </div>

      <!-- Planta escaneada -->
      <div class="qr__plant-card qr__plant-card--scan">
        <div class="qr__plant-emoji">🌿</div>
        <div class="qr__plant-info">
          <div class="qr__plant-nombre">{{ plantaDetalle?.nombre }}</div>
          <div class="qr__plant-meta">
            <span class="qr__plant-qr">{{ codigoQr }}</span>
          </div>
        </div>
        <div v-if="pesoAnterior" class="qr__ya-pesada">
          <i class="bi bi-check-circle-fill"></i>
          {{ pesoAnterior }}g
        </div>
      </div>

      <!-- Progreso del lote -->
      <div class="qr__progreso">
        <div class="qr__progreso-nums">
          <span class="qr__progreso-cnt">
            <strong>{{ progreso.pesadas }}</strong> / {{ progreso.total }} plantas
          </span>
          <span class="qr__progreso-total">{{ progreso.peso_total_g.toFixed(1) }}g total</span>
        </div>
        <div class="qr__progreso-bar">
          <div
            class="qr__progreso-fill"
            :style="{ width: progresoPorc + '%' }"
            :class="{ 'qr__progreso-fill--completo': progreso.completado }"
          ></div>
        </div>
        <div v-if="progreso.completado" class="qr__progreso-label qr__progreso-label--ok">
          <i class="bi bi-check-circle-fill"></i> Todas las plantas pesadas
        </div>
        <div v-else class="qr__progreso-label">
          Faltan {{ progreso.total - progreso.pesadas }} plantas
        </div>
      </div>

      <!-- Formulario de peso -->
      <div class="qr__peso-form">
        <div class="qr__field">
          <label>Peso seco (g)</label>
          <div class="qr__peso-input-wrap">
            <input
              v-model="pesoInput"
              type="number"
              min="0.1"
              step="0.1"
              placeholder="0.0"
              class="qr__peso-input"
              :disabled="registrando"
              ref="pesoInputRef"
            />
            <span class="qr__peso-unit">g</span>
          </div>
        </div>

        <div v-if="registroError" class="qr__error">
          <i class="bi bi-exclamation-triangle"></i> {{ registroError }}
        </div>

        <div v-if="registroOk" class="qr__registro-ok">
          <i class="bi bi-check-circle-fill"></i> Peso registrado correctamente
        </div>

        <button
          class="qr__btn-primary"
          @click="registrarPeso"
          :disabled="registrando || !pesoInput"
        >
          <div v-if="registrando" class="qr__spinner qr__spinner--sm"></div>
          <i v-else class="bi bi-check2-circle"></i>
          {{ pesoAnterior ? 'Actualizar peso' : 'Registrar peso' }}
        </button>
      </div>

      <!-- Volver al lote -->
      <RouterLink :to="`/mnc/lotes/${plantaDetalle?.lote?.id}`" class="qr__btn-secondary qr__btn-volver">
        <i class="bi bi-arrow-left"></i> Volver al lote
      </RouterLink>

    </div>

  </div>
</template>

<script setup>
import { ref, computed, onMounted, nextTick } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '../stores/auth'
import { useClubStore } from '../stores/club'
import { usePermissions } from '../composables/usePermissions'
import { getPlant, listPlants, registrarPesoPlanta } from '../lib/api'
import axios from 'axios'

const route  = useRoute()
const router = useRouter()
const auth   = useAuthStore()
const club   = useClubStore()

const codigoQr   = route.params.codigo_qr
const estado     = ref('cargando')
const plantaInfo = ref(null)
const clubNombre = ref('')
const clubLogo   = ref('')

// Login
const loginForm     = ref({ email: '', password: '' })
const loginCargando = ref(false)
const loginError    = ref(null)

// Manicura pesaje
const plantaDetalle = ref(null)
const pesoInput     = ref('')
const pesoAnterior  = ref(null)
const registrando   = ref(false)
const registroError = ref(null)
const registroOk    = ref(false)
const pesoInputRef  = ref(null)

const progreso = ref({ pesadas: 0, total: 0, peso_total_g: 0, completado: false })

const progresoPorc = computed(() => {
  if (!progreso.value.total) return 0
  return Math.min(100, Math.round((progreso.value.pesadas / progreso.value.total) * 100))
})

onMounted(async () => {
  await auth.ensureBootstrapped()

  const backendBase = (import.meta.env.VITE_API_URL || 'http://localhost:3001/api').replace(/\/api\/?$/, '')
  try {
    const { data } = await axios.get(`${backendBase}/p/${codigoQr}`)
    plantaInfo.value = data
    clubNombre.value = data.club_nombre || ''
    clubLogo.value   = data.club_logo   || ''
  } catch {
    estado.value = 'no_encontrada'
    return
  }

  if (!auth.isAuthenticated) {
    estado.value = 'login'
    return
  }

  await resolverEstado()
})

async function resolverEstado() {
  const { can } = usePermissions()
  if (!can('plantas', 'show')) {
    estado.value = 'sin_permisos'
    return
  }

  // Cargar detalle autenticado para saber el estado real del lote
  try {
    const { data } = await getPlant(plantaInfo.value.id)
    plantaDetalle.value = data

    const loteEstado = data.lote?.estado
    const esManicura = auth.user?.role === 'manicura'

    if (esManicura && ['en_manicura', 'secado'].includes(loteEstado)) {
      await cargarProgreso(data)
      estado.value = 'manicura_pesaje'
      if (data.peso_seco && data.peso_seco > 0) {
        pesoAnterior.value = data.peso_seco
        pesoInput.value = String(data.peso_seco)
      }
      await nextTick()
      pesoInputRef.value?.focus()
    } else {
      router.replace({ name: 'planta-detalle', params: { id: plantaInfo.value.id } })
    }
  } catch {
    router.replace({ name: 'planta-detalle', params: { id: plantaInfo.value.id } })
  }
}

async function cargarProgreso(detalle) {
  try {
    const { data: plantas } = await listPlants({ lote_id: detalle.lote.id })
    const total   = plantas.length
    const pesadas = plantas.filter(p => p.peso_seco && p.peso_seco > 0).length
    const pesoTotal = plantas.reduce((s, p) => s + (p.peso_seco || 0), 0)
    progreso.value = {
      pesadas,
      total,
      peso_total_g: pesoTotal,
      completado: pesadas >= total,
    }
  } catch {
    // si falla usamos plants_count del detalle
    progreso.value = {
      pesadas:      detalle.peso_seco > 0 ? 1 : 0,
      total:        detalle.lote?.plants_count || 1,
      peso_total_g: detalle.peso_seco || 0,
      completado:   false,
    }
  }
}

async function registrarPeso() {
  const peso = parseFloat(pesoInput.value)
  if (!peso || peso <= 0) return

  registrando.value  = true
  registroError.value = null

  try {
    const { data } = await registrarPesoPlanta(plantaDetalle.value.id, { peso_seco_g: peso })
    pesoAnterior.value = peso
    progreso.value     = data.progreso
    registroOk.value   = true
    setTimeout(() => { registroOk.value = false }, 3000)
  } catch (e) {
    registroError.value = e?.response?.data?.error || 'No se pudo registrar el peso'
  } finally {
    registrando.value = false
  }
}

async function hacerLogin() {
  if (!loginForm.value.email || !loginForm.value.password) return
  loginCargando.value = true
  loginError.value    = null

  try {
    await auth.login(loginForm.value.email, loginForm.value.password)
    await club.fetch()
    await resolverEstado()
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
.qr__spinner--dark { border-top-color: #1b5e20; border-color: rgba(27,94,32,.2); }
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
.qr__screen--pesaje {
  padding: 1.75rem 1.5rem;
  gap: 1.25rem;
  align-items: stretch;
  text-align: left;
}

.qr__club-header {
  display: flex; align-items: center; gap: .6rem;
  padding: .5rem 1rem; background: #f0fdf4;
  border-radius: 999px; margin-bottom: .25rem;
  align-self: center;
}
.qr__club-logo img { width: 24px; height: 24px; border-radius: 50%; object-fit: cover; }
.qr__club-nombre { font-size: .82rem; font-weight: 600; color: #1b5e20; }

.qr__icon { font-size: 3rem; line-height: 1; }
.qr__icon--warn { filter: grayscale(.2); }

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

/* Lote header */
.qr__lote-header {
  display: flex; align-items: center; justify-content: space-between;
}
.qr__lote-badge {
  display: inline-flex; align-items: center; gap: .35rem;
  background: #e8f5e9; color: #1b5e20;
  font-size: .78rem; font-weight: 700;
  padding: .3rem .75rem; border-radius: 999px;
}
.qr__lote-genetica {
  font-size: .78rem; color: #60725d; font-weight: 500;
}

/* Plant preview */
.qr__plant-card {
  display: flex; align-items: center; gap: .75rem;
  background: #f0fdf4; border: 1px solid #c8e6c9;
  border-radius: 12px; padding: .875rem 1.1rem;
  width: 100%; text-align: left; box-sizing: border-box;
}
.qr__plant-card--scan { position: relative; }
.qr__plant-emoji { font-size: 1.5rem; flex-shrink: 0; }
.qr__plant-info  { flex: 1; min-width: 0; }
.qr__plant-nombre { font-size: .95rem; font-weight: 700; color: #1a1a1a; }
.qr__plant-meta   { font-size: .78rem; color: #60725d; margin-top: .15rem; }
.qr__plant-qr     { font-family: monospace; color: #94a3b8; }
.qr__plant-preview {
  background: #f0fdf4; border: 1px solid #c8e6c9;
  border-radius: 10px; padding: .75rem 1rem;
  width: 100%;
}
.qr__plant-codigo { font-size: .9rem; font-weight: 700; color: #1a1a1a; }
.qr__plant-sub    { font-size: .75rem; color: #60725d; margin-top: .1rem; }

.qr__ya-pesada {
  display: flex; align-items: center; gap: .3rem;
  font-size: .78rem; font-weight: 700;
  color: #16a34a; white-space: nowrap;
}
.qr__ya-pesada i { font-size: .85rem; }

/* Progreso */
.qr__progreso {
  background: #f8faf8; border: 1px solid #e0ece0;
  border-radius: 12px; padding: .875rem 1rem;
}
.qr__progreso-nums {
  display: flex; justify-content: space-between; align-items: baseline;
  margin-bottom: .5rem;
}
.qr__progreso-cnt  { font-size: .85rem; color: #374151; }
.qr__progreso-cnt strong { font-size: 1rem; color: #1a1a1a; }
.qr__progreso-total { font-size: .78rem; color: #16a34a; font-weight: 600; }
.qr__progreso-bar {
  height: 6px; background: #d4e6d4; border-radius: 999px; overflow: hidden;
  margin-bottom: .5rem;
}
.qr__progreso-fill {
  height: 100%; background: #1b5e20; border-radius: 999px;
  transition: width .4s ease;
}
.qr__progreso-fill--completo { background: #16a34a; }
.qr__progreso-label {
  font-size: .72rem; color: #6b7280;
}
.qr__progreso-label--ok {
  color: #16a34a; font-weight: 600;
  display: flex; align-items: center; gap: .3rem;
}

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
.qr__peso-form {
  display: flex; flex-direction: column; gap: .75rem;
}
.qr__field {
  display: flex; flex-direction: column; gap: .3rem;
}
.qr__field label {
  font-size: .72rem; font-weight: 700; color: #374151;
  text-transform: uppercase; letter-spacing: .05em;
}
.qr__field input,
.qr__peso-input {
  background: #f4f8f4; border: 1.5px solid #d4e6d4;
  border-radius: 9px; padding: .65rem .9rem;
  font-size: .9rem; color: #1a1a1a; width: 100%; box-sizing: border-box;
  transition: border .15s; font-family: inherit;
}
.qr__field input:focus,
.qr__peso-input:focus { outline: none; border-color: #1b5e20; background: #fff; }
.qr__field input:disabled,
.qr__peso-input:disabled { opacity: .6; }

.qr__peso-input-wrap {
  position: relative; display: flex; align-items: center;
}
.qr__peso-input-wrap .qr__peso-input {
  padding-right: 2.5rem;
}
.qr__peso-unit {
  position: absolute; right: .9rem;
  font-size: .85rem; font-weight: 600; color: #6b7280;
  pointer-events: none;
}

.qr__peso-input[type=number]::-webkit-inner-spin-button,
.qr__peso-input[type=number]::-webkit-outer-spin-button { opacity: 0; }

.qr__error {
  background: #fef2f2; color: #dc2626; border-radius: 8px;
  padding: .6rem .9rem; font-size: .82rem;
  display: flex; align-items: center; gap: .5rem;
}

.qr__registro-ok {
  display: flex; align-items: center; gap: .4rem;
  font-size: .78rem; font-weight: 600; color: #15803d;
  background: #dcfce7; border: 1px solid #bbf7d0;
  border-radius: 8px; padding: .5rem .75rem;
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
.qr__btn-primary--warn {
  background: linear-gradient(135deg, #92400e, #b45309);
  box-shadow: 0 4px 14px rgba(146,64,14,.25);
}

.qr__btn-secondary {
  display: inline-flex; align-items: center; gap: .4rem;
  background: transparent; color: #1b5e20;
  border: 1.5px solid #c8e6c9; padding: .6rem 1.25rem;
  border-radius: 9px; font-size: .85rem; font-weight: 500;
  cursor: pointer; transition: all .15s; margin-top: .5rem;
  align-self: center;
}
.qr__btn-secondary:hover { background: #f0fdf4; border-color: #1b5e20; }

.qr__btn-volver {
  text-decoration: none;
  align-self: center;
}
</style>
