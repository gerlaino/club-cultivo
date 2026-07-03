<template>
  <div class="qr">

    <!-- Cargando -->
    <div v-if="estado === 'cargando'" class="qr__full-center">
      <div class="qr__loading-ico">🌱</div>
      <DsSpinner :size="32" />
    </div>

    <!-- No encontrada -->
    <div v-else-if="estado === 'no_encontrada'" class="qr__card">
      <div class="qr__header">
        <div class="qr__header-logo-wrap"><span class="qr__header-emoji">🌿</span></div>
        <div>
          <div class="qr__header-club">Cultivo Espacial</div>
          <div class="qr__header-sub">Trazabilidad de planta</div>
        </div>
      </div>
      <div class="qr__body qr__body--center">
        <div class="qr__err-ico">⚠️</div>
        <div class="qr__err-title">Planta no encontrada</div>
        <div class="qr__err-desc">El código QR escaneado no corresponde a ninguna planta registrada en el sistema.</div>
        <div class="qr__code-badge">{{ codigoQr }}</div>
      </div>
      <div class="qr__footer">No verificado</div>
    </div>

    <!-- Mensaje informativo (planta cosechada / aún no en manicura / etc.) -->
    <div v-else-if="estado === 'mensaje'" class="qr__card">
      <div class="qr__header">
        <div class="qr__header-logo-wrap">
          <img v-if="clubLogo" :src="clubLogo" :alt="clubNombre" class="qr__header-logo" />
          <span v-else class="qr__header-emoji">🌿</span>
        </div>
        <div>
          <div class="qr__header-club">{{ clubNombre || 'Cultivo Espacial' }}</div>
          <div class="qr__header-sub">Trazabilidad de planta</div>
        </div>
      </div>
      <div class="qr__body qr__body--center">
        <div class="qr__err-ico">{{ mensajeCard.ico }}</div>
        <div class="qr__err-title">{{ mensajeCard.title }}</div>
        <div class="qr__err-desc">{{ mensajeCard.desc }}</div>
        <div v-if="plantaInfo?.nombre" class="qr__code-badge">{{ plantaInfo.nombre }}</div>
        <button class="qr__btn-secondary" @click="irAlDashboard">Ir al inicio</button>
      </div>
      <div class="qr__footer"><span class="qr__footer-dot"></span> {{ clubNombre }}</div>
    </div>

    <!-- Público: info de planta sin login -->
    <div v-else-if="estado === 'publico'" class="qr__card">
      <div class="qr__header">
        <div class="qr__header-logo-wrap">
          <img v-if="clubLogo" :src="clubLogo" :alt="clubNombre" class="qr__header-logo" />
          <span v-else class="qr__header-emoji">🌿</span>
        </div>
        <div>
          <div class="qr__header-club">{{ clubNombre || 'Cultivo Espacial' }}</div>
          <div class="qr__header-sub">Trazabilidad de planta</div>
        </div>
      </div>

      <div class="qr__body">
        <div class="qr__plant-center">
          <div class="qr__plant-big-emoji">🌱</div>
          <div class="qr__plant-codigo-big">{{ plantaInfo?.nombre }}</div>
          <div class="qr__plant-estado-badge" :class="`qr__plant-estado-badge--${plantaInfo?.estado}`">
            <span class="qr__plant-estado-dot"></span>
            {{ estadoPlantaLabel(plantaInfo?.estado) }}
          </div>
          <div v-if="plantaInfo?.lote?.codigo" class="qr__plant-lote-ref">
            <span class="qr__plant-lote-label">Lote</span>
            <span class="qr__plant-lote-cod">{{ plantaInfo.lote.codigo }}</span>
          </div>
        </div>
      </div>

      <div class="qr__footer">
        <span class="qr__footer-dot"></span>
        Planta registrada y verificada
        <span class="qr__footer-sep">·</span>
        {{ clubNombre }}
      </div>

      <div class="qr__login-hint">
        <button class="qr__login-hint-btn" @click="estado = 'login'">
          <i class="bi bi-person-badge"></i> Soy del equipo — Iniciar sesión
        </button>
      </div>
    </div>

    <!-- Sin permisos -->
    <div v-else-if="estado === 'sin_permisos'" class="qr__card">
      <div class="qr__header">
        <div class="qr__header-logo-wrap">
          <img v-if="clubLogo" :src="clubLogo" :alt="clubNombre" class="qr__header-logo" />
          <span v-else class="qr__header-emoji">🌿</span>
        </div>
        <div>
          <div class="qr__header-club">{{ clubNombre || 'Cultivo Espacial' }}</div>
          <div class="qr__header-sub">Trazabilidad de planta</div>
        </div>
      </div>
      <div class="qr__body qr__body--center">
        <div class="qr__err-ico">🔒</div>
        <div class="qr__err-title">Acceso restringido</div>
        <div class="qr__err-desc">No tenés permisos para ver el detalle de esta planta. Contactá al administrador de <strong>{{ clubNombre || 'tu club' }}</strong>.</div>
        <button class="qr__btn-secondary" @click="irAlDashboard">Ir al inicio</button>
      </div>
      <div class="qr__footer"><span class="qr__footer-dot"></span> {{ clubNombre }}</div>
    </div>

    <!-- Login (solo para manicurador que necesita autenticarse para pesaje) -->
    <div v-else-if="estado === 'login'" class="qr__card">
      <div class="qr__header">
        <div class="qr__header-logo-wrap">
          <img v-if="clubLogo" :src="clubLogo" :alt="clubNombre" class="qr__header-logo" />
          <span v-else class="qr__header-emoji">🌿</span>
        </div>
        <div>
          <div class="qr__header-club">{{ clubNombre || 'Cultivo Espacial' }}</div>
          <div class="qr__header-sub">Acceso del equipo</div>
        </div>
      </div>
      <div class="qr__body">
        <div class="qr__login-info">
          <div class="qr__plant-big-emoji" style="font-size:1.75rem;margin-bottom:.25rem">🌱</div>
          <div class="qr__plant-codigo-big" style="font-size:1rem;margin-bottom:.1rem">{{ plantaInfo?.nombre }}</div>
          <div class="qr__plant-lote-ref">
            <span class="qr__plant-lote-label">Lote</span>
            <span class="qr__plant-lote-cod">{{ plantaInfo?.lote?.codigo }}</span>
          </div>
        </div>
        <div class="qr__login-title">Iniciá sesión para continuar</div>
        <form class="qr__form" @submit.prevent="hacerLogin">
          <div class="qr__field">
            <label>Email</label>
            <input v-model="loginForm.email" type="email" placeholder="tu@email.com" autocomplete="email" :disabled="loginCargando" />
          </div>
          <div class="qr__field">
            <label>Contraseña</label>
            <input v-model="loginForm.password" type="password" placeholder="••••••••" autocomplete="current-password" :disabled="loginCargando" />
          </div>
          <div v-if="loginError" class="qr__err-inline">
            <i class="bi bi-exclamation-triangle"></i> {{ loginError }}
          </div>
          <button type="submit" class="qr__btn-primary" :disabled="loginCargando">
            <DsSpinner v-if="loginCargando" :size="16" />
            <i v-else class="bi bi-box-arrow-in-right"></i>
            {{ loginCargando ? 'Ingresando…' : 'Ingresar' }}
          </button>
        </form>
      </div>
      <div class="qr__footer"><span class="qr__footer-dot"></span> {{ clubNombre }}</div>
    </div>

    <!-- Manicura: pesaje por QR -->
    <div v-else-if="estado === 'manicura_pesaje'" class="qr__card">

      <!-- Header -->
      <div class="qr__header">
        <div class="qr__header-logo-wrap">
          <img v-if="clubLogo" :src="clubLogo" :alt="clubNombre" class="qr__header-logo" />
          <span v-else class="qr__header-emoji">✂️</span>
        </div>
        <div>
          <div class="qr__header-club">{{ clubNombre || 'Cultivo Espacial' }}</div>
          <div class="qr__header-sub">Pesaje de manicura</div>
        </div>
      </div>

      <!-- Lote info bar -->
      <div class="qr__lote-bar">
        <span class="qr__lote-bar-ico">📦</span>
        <span class="qr__lote-bar-cod">{{ plantaDetalle?.lote?.codigo }}</span>
        <span v-if="plantaDetalle?.genetica?.nombre" class="qr__lote-bar-gen">{{ plantaDetalle.genetica.nombre }}</span>
      </div>

      <div class="qr__body">

        <!-- Planta escaneada -->
        <div class="qr__pesaje-plant-card" :class="{ 'qr__pesaje-plant-card--pesada': pesoAnterior }">
          <span class="qr__pesaje-plant-ico">🌿</span>
          <div class="qr__pesaje-plant-info">
            <div class="qr__pesaje-plant-nombre">{{ plantaDetalle?.nombre }}</div>
            <div class="qr__pesaje-plant-cod">{{ codigoQr }}</div>
          </div>
          <div v-if="pesoAnterior" class="qr__pesaje-ya">
            <i class="bi bi-check-circle-fill"></i> {{ pesoAnterior }}g
          </div>
        </div>

        <!-- Progreso del lote -->
        <div class="qr__progreso">
          <div class="qr__progreso-top">
            <span class="qr__progreso-cnt"><strong>{{ progreso.pesadas }}</strong> / {{ progreso.total }} plantas</span>
            <span class="qr__progreso-total">{{ Number(progreso.peso_total_g || 0).toFixed(1) }}g total</span>
          </div>
          <div class="qr__progreso-bar">
            <div class="qr__progreso-fill"
              :style="{ width: progresoPorc + '%' }"
              :class="{ 'qr__progreso-fill--completo': progreso.completado }">
            </div>
          </div>
          <div class="qr__progreso-label" :class="{ 'qr__progreso-label--ok': progreso.completado }">
            <template v-if="progreso.completado"><i class="bi bi-check-circle-fill"></i> Todas las plantas pesadas</template>
            <template v-else>Faltan {{ progreso.total - progreso.pesadas }} plantas</template>
          </div>
        </div>

        <!-- Formulario -->
        <div class="qr__peso-form">
          <div class="qr__field">
            <label>Peso bruto al corte <span class="qr__field-opt">opcional</span></label>
            <div class="qr__peso-wrap">
              <input v-model="pesoHumedoInput" type="number" min="0.1" step="0.1" placeholder="0.0" class="qr__peso-input" :disabled="registrando" />
              <span class="qr__peso-unit">g</span>
            </div>
            <span class="qr__field-hint">Antes del recorte / manicura</span>
          </div>
          <div class="qr__field">
            <label>Peso seco post-manicura</label>
            <div class="qr__peso-wrap">
              <input v-model="pesoInput" type="number" min="0.1" step="0.1" placeholder="0.0" class="qr__peso-input" :disabled="registrando" ref="pesoInputRef" />
              <span class="qr__peso-unit">g</span>
            </div>
          </div>

          <div v-if="registroError" class="qr__err-inline">
            <i class="bi bi-exclamation-triangle"></i> {{ registroError }}
          </div>
          <div v-if="registroOk" class="qr__registro-ok">
            <i class="bi bi-check-circle-fill"></i> Peso registrado correctamente
          </div>

          <button class="qr__btn-primary" @click="registrarPeso" :disabled="registrando || !pesoInput">
            <DsSpinner v-if="registrando" :size="16" />
            <i v-else class="bi bi-check2-circle"></i>
            {{ pesoAnterior ? 'Actualizar peso' : 'Registrar peso' }}
          </button>
        </div>

        <RouterLink :to="`/mnc/lotes/${plantaDetalle?.lote?.id}`" class="qr__btn-volver">
          <i class="bi bi-arrow-left"></i> Volver al lote
        </RouterLink>

      </div>

      <div class="qr__footer"><span class="qr__footer-dot"></span> {{ clubNombre }}</div>
    </div>

  </div>
</template>

<script setup>
import { ref, computed, onMounted, nextTick } from 'vue'
import { useRoute, useRouter, RouterLink } from 'vue-router'
import { useAuthStore } from '../stores/auth'
import { useClubStore } from '../stores/club'
import { usePermissions } from '../composables/usePermissions'
import { getPlant, listPlants, registrarPesoPlanta, getPlantaPorQR } from '../lib/api'
import DsSpinner from '../design-system/components/Spinner.vue'

const route  = useRoute()
const router = useRouter()
const auth   = useAuthStore()
const club   = useClubStore()

const codigoQr   = route.params.codigo_qr
const estado     = ref('cargando')
const plantaInfo = ref(null)
const clubNombre = ref('')
const clubLogo   = ref('')

const loginForm     = ref({ email: '', password: '' })
const loginCargando = ref(false)
const loginError    = ref(null)

const plantaDetalle   = ref(null)
const pesoInput       = ref('')
const pesoHumedoInput = ref('')
const pesoAnterior    = ref(null)
const registrando     = ref(false)
const registroError   = ref(null)
const registroOk      = ref(false)
const pesoInputRef    = ref(null)
const progreso        = ref({ pesadas: 0, total: 0, peso_total_g: 0, completado: false })

const progresoPorc = computed(() => {
  if (!progreso.value.total) return 0
  return Math.min(100, Math.round((progreso.value.pesadas / progreso.value.total) * 100))
})


const ESTADO_LABELS = {
  semilla: 'Semilla', esqueje: 'Esqueje', vegetativo: 'Vegetativo',
  floracion: 'Floración', cosecha: 'Cosecha', en_manicura: 'Manicura', curado: 'Curado', finalizado: 'Finalizado',
}
function estadoPlantaLabel(e) { return ESTADO_LABELS[e] || e || '—' }

onMounted(async () => {
  // Mismo patrón que LoteQrView: la ruta /p/:codigo_qr exige auth, así que llegamos
  // siempre logueados. Usamos la instancia api autenticada (cookie + CORS de /api que
  // ya funcionan) en vez del fetch crudo cross-origin al endpoint público, que en
  // producción (front y API en hosts distintos) se colgaba.
  try {
    const { data } = await getPlantaPorQR(codigoQr)
    plantaInfo.value = data
    clubNombre.value = club.name || ''
    clubLogo.value   = club.logoUrl || ''
    await resolverEstado()
  } catch (e) {
    estado.value = 'no_encontrada'
  }
})

// Una planta está "cosechada" (fuera del dominio del cultivador) una vez que pasó
// a cosecha o más adelante (secado, manicura, curado, finalizado).
const ESTADOS_POST_COSECHA = ['cosecha', 'en_manicura', 'curado', 'finalizado']
const LOTE_EN_MANICURA     = ['en_manicura']

const mensajeCard = ref({ ico: '🌿', title: '', desc: '' })

// Decide qué mostrar según el rol del usuario y la fase de la planta/lote.
// IMPORTANTE: decide solo con la data pública (sin getPlant previo). El código viejo
// llamaba a getPlant para todos y, en el navegador del celular sin cookie cross-site,
// el 401 disparaba el interceptor (→ /login) a la vez que el catch redirigía al detalle:
// dos navegaciones en carrera = pantalla en blanco.
async function resolverEstado() {
  const role       = auth.user?.role
  const plantState = plantaInfo.value.estado
  const loteEstado = plantaInfo.value.lote?.estado
  const cosechada  = ESTADOS_POST_COSECHA.includes(plantState) || ESTADOS_POST_COSECHA.includes(loteEstado)

  // Manicura: pesaje si el lote está en manicura/secado; si no, mensaje según la fase.
  if (role === 'manicura') {
    if (LOTE_EN_MANICURA.includes(loteEstado)) {
      await iniciarPesaje()
      return
    }
    mensajeCard.value = cosechada
      ? { ico: '✅', title: 'Etapa de manicura completada', desc: 'Esta planta ya pasó la etapa de manicura. No hay pesaje pendiente.' }
      : { ico: '⏳', title: 'Aún no disponible', desc: 'Esta planta todavía no está en etapa de manicura. Vas a poder pesarla cuando el lote pase a manicura.' }
    estado.value = 'mensaje'
    return
  }

  // Cultivador: detalle solo mientras NO esté cosechada; después es dominio de manicura.
  if (role === 'cultivador') {
    if (cosechada) {
      mensajeCard.value = { ico: '🌾', title: 'Planta cosechada', desc: 'Esta planta ya fue cosechada y pasó a post-cosecha. No tenés permisos para ver su detalle.' }
      estado.value = 'mensaje'
      return
    }
    return irADetalle()
  }

  // Admin / supervisor: siempre al detalle.
  if (role === 'admin' || role === 'supervisor') {
    return irADetalle()
  }

  // Otros roles: detalle si tienen permiso de ver plantas; si no, sin permisos.
  if (usePermissions().can('plantas', 'show')) return irADetalle()
  estado.value = 'sin_permisos'
}

function irADetalle() {
  router.replace({ name: 'planta-detalle', params: { id: plantaInfo.value.id } })
}

// Carga el detalle completo de la planta para el flujo de pesaje de manicura.
async function iniciarPesaje() {
  try {
    const { data } = await getPlant(plantaInfo.value.id)
    plantaDetalle.value = data
    await cargarProgreso(data)
    estado.value = 'manicura_pesaje'
    if (data.peso_seco && data.peso_seco > 0) {
      pesoAnterior.value = data.peso_seco
      pesoInput.value    = String(data.peso_seco)
    }
    if (data.peso_humedo && data.peso_humedo > 0) {
      pesoHumedoInput.value = String(data.peso_humedo)
    }
    await nextTick()
    pesoInputRef.value?.focus()
  } catch {
    mensajeCard.value = { ico: '⚠️', title: 'No se pudo cargar la planta', desc: 'Reintentá en unos segundos. Si el problema persiste, avisá al administrador.' }
    estado.value = 'mensaje'
  }
}

async function cargarProgreso(detalle) {
  try {
    const { data: plantas } = await listPlants({ lote_id: detalle.lote.id })
    const total    = plantas.length
    // peso_seco llega como string (decimal de Rails): parseamos antes de comparar/sumar,
    // si no el reduce concatena strings y el .toFixed del render explota.
    const pesadas  = plantas.filter(p => parseFloat(p.peso_seco) > 0).length
    const pesoTotal = plantas.reduce((s, p) => s + (parseFloat(p.peso_seco) || 0), 0)
    progreso.value = { pesadas, total, peso_total_g: pesoTotal, completado: pesadas >= total }
  } catch {
    progreso.value = {
      pesadas:      parseFloat(detalle.peso_seco) > 0 ? 1 : 0,
      total:        detalle.lote?.plants_count || 1,
      peso_total_g: parseFloat(detalle.peso_seco) || 0,
      completado:   false,
    }
  }
}

async function registrarPeso() {
  const peso       = parseFloat(pesoInput.value)
  const pesoHumedo = parseFloat(pesoHumedoInput.value)
  if (!peso || peso <= 0) return
  registrando.value   = true
  registroError.value = null
  const payload = { peso_seco_g: peso }
  if (pesoHumedo > 0) payload.peso_humedo_g = pesoHumedo
  try {
    const { data } = await registrarPesoPlanta(plantaDetalle.value.id, payload)
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

function irAlDashboard() { router.push('/') }
</script>

<style scoped>
* { box-sizing: border-box; }

.qr {
  min-height: 100dvh;
  display: flex; align-items: center; justify-content: center;
  background: linear-gradient(160deg, #0f2417 0%, #1a3d2e 50%, #0f2417 100%);
  padding: 1.25rem;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, sans-serif;
}

.qr__full-center {
  display: flex; flex-direction: column; align-items: center;
  gap: 1.5rem; color: #a7f3d0;
}
.qr__loading-ico { font-size: 3rem; animation: qr-pulse 2s ease-in-out infinite; }
@keyframes qr-pulse { 0%,100% { opacity: .7; } 50% { opacity: 1; } }

/* Card */
.qr__card {
  width: 100%; max-width: 390px;
  background: #fff; border-radius: 20px; overflow: hidden;
  box-shadow: 0 24px 64px rgba(0,0,0,.4), 0 4px 16px rgba(0,0,0,.2);
}

/* Header */
.qr__header {
  background: linear-gradient(135deg, #0f2417 0%, #1b5e20 60%, #2e7d32 100%);
  padding: 1.25rem 1.5rem;
  display: flex; align-items: center; gap: 1rem;
}
.qr__header-logo-wrap {
  width: 48px; height: 48px; border-radius: 12px;
  background: rgba(255,255,255,.12); display: flex; align-items: center;
  justify-content: center; flex-shrink: 0; overflow: hidden;
}
.qr__header-logo  { width: 100%; height: 100%; object-fit: contain; }
.qr__header-emoji { font-size: 1.5rem; }
.qr__header-club  { font-size: 1rem; font-weight: 800; color: #fff; letter-spacing: -.01em; }
.qr__header-sub   { font-size: .68rem; color: rgba(255,255,255,.6); text-transform: uppercase; letter-spacing: .06em; margin-top: .15rem; }

/* Lote bar (manicura) */
.qr__lote-bar {
  background: #f0fdf4; border-bottom: 1px solid #dcfce7;
  padding: .6rem 1.5rem; display: flex; align-items: center; gap: .5rem;
  font-size: .82rem;
}
.qr__lote-bar-ico  { font-size: .9rem; }
.qr__lote-bar-cod  { font-family: monospace; font-weight: 800; color: #1b5e20; }
.qr__lote-bar-gen  { color: #4a7c59; }

/* Body */
.qr__body { padding: 1.5rem; display: flex; flex-direction: column; gap: 1.25rem; }
.qr__body--center { align-items: center; text-align: center; }

/* Planta pública */
.qr__plant-center { display: flex; flex-direction: column; align-items: center; gap: .75rem; text-align: center; padding: .5rem 0; }
.qr__plant-big-emoji { font-size: 3.5rem; line-height: 1; }
.qr__plant-codigo-big { font-family: 'Courier New', monospace; font-size: 1.2rem; font-weight: 900; color: #0f172a; letter-spacing: .02em; }

/* Estado badge */
.qr__plant-estado-badge {
  display: inline-flex; align-items: center; gap: .45rem;
  padding: .4rem 1rem; border-radius: 999px;
  font-size: .82rem; font-weight: 800;
}
.qr__plant-estado-dot { width: 8px; height: 8px; border-radius: 50%; background: currentColor; }
.qr__plant-estado-badge--vegetativo  { background: #dcfce7; color: #15803d; }
.qr__plant-estado-badge--floracion   { background: #f3e8ff; color: #7c3aed; }
.qr__plant-estado-badge--cosecha     { background: #fef3c7; color: #d97706; }
.qr__plant-estado-badge--en_manicura,.qr__plant-estado-badge--secado { background: #fef3c7; color: #d97706; }
.qr__plant-estado-badge--curado      { background: #dbeafe; color: #1d4ed8; }
.qr__plant-estado-badge--finalizado  { background: #f1f5f9; color: #64748b; }

.qr__plant-lote-ref { display: flex; align-items: center; gap: .4rem; font-size: .8rem; }
.qr__plant-lote-label { color: #94a3b8; font-size: .72rem; text-transform: uppercase; letter-spacing: .04em; }
.qr__plant-lote-cod   { font-family: monospace; font-weight: 700; color: #334155; }

/* Login hint */
.qr__login-hint { padding: .75rem 1.5rem; border-top: 1px solid #f1f5f9; display: flex; justify-content: center; }
.qr__login-hint-btn {
  background: none; border: none; color: #94a3b8; font-size: .75rem;
  cursor: pointer; display: flex; align-items: center; gap: .35rem;
  padding: .3rem .5rem; border-radius: 6px; transition: color .15s;
}
.qr__login-hint-btn:hover { color: #1b5e20; }

/* Login form */
.qr__login-info { text-align: center; padding: .5rem 0; }
.qr__login-title { font-size: .95rem; font-weight: 700; color: #374151; margin-bottom: .25rem; }
.qr__form { display: flex; flex-direction: column; gap: .75rem; }
.qr__field { display: flex; flex-direction: column; gap: .3rem; }
.qr__field label { font-size: .72rem; font-weight: 700; color: #374151; text-transform: uppercase; letter-spacing: .05em; }
.qr__field input {
  background: #f4f8f4; border: 1.5px solid #d4e6d4; border-radius: 9px;
  padding: .65rem .875rem; font-size: .9rem; color: #1a1a1a; outline: none;
  transition: border-color .15s;
}
.qr__field input:focus { border-color: #1b5e20; }
.qr__field-opt { font-weight: 400; color: #94a3b8; font-size: .68rem; }
.qr__field-hint { font-size: .7rem; color: #94a3b8; }

/* Pesaje */
.qr__pesaje-plant-card {
  display: flex; align-items: center; gap: .75rem;
  background: #f0fdf4; border: 1.5px solid #bbf7d0; border-radius: 12px;
  padding: .875rem 1rem;
}
.qr__pesaje-plant-card--pesada { border-color: #22c55e; }
.qr__pesaje-plant-ico   { font-size: 1.5rem; flex-shrink: 0; }
.qr__pesaje-plant-info  { flex: 1; min-width: 0; }
.qr__pesaje-plant-nombre { font-size: .95rem; font-weight: 700; color: #0f172a; }
.qr__pesaje-plant-cod    { font-size: .72rem; color: #94a3b8; font-family: monospace; }
.qr__pesaje-ya { display: flex; align-items: center; gap: .3rem; font-size: .78rem; font-weight: 800; color: #16a34a; white-space: nowrap; }

/* Progreso */
.qr__progreso { background: #f8faf8; border: 1px solid #e0ece0; border-radius: 12px; padding: .875rem 1rem; }
.qr__progreso-top { display: flex; justify-content: space-between; align-items: baseline; margin-bottom: .5rem; }
.qr__progreso-cnt { font-size: .85rem; color: #374151; }
.qr__progreso-cnt strong { font-size: 1rem; color: #0f172a; }
.qr__progreso-total { font-size: .78rem; color: #16a34a; font-weight: 600; }
.qr__progreso-bar { height: 6px; background: #d4e6d4; border-radius: 999px; overflow: hidden; margin-bottom: .5rem; }
.qr__progreso-fill { height: 100%; background: #1b5e20; border-radius: 999px; transition: width .4s ease; }
.qr__progreso-fill--completo { background: #16a34a; }
.qr__progreso-label { font-size: .72rem; color: #6b7280; display: flex; align-items: center; gap: .3rem; }
.qr__progreso-label--ok { color: #16a34a; font-weight: 700; }

/* Peso form */
.qr__peso-form { display: flex; flex-direction: column; gap: .75rem; }
.qr__peso-wrap { display: flex; align-items: center; gap: .4rem; }
.qr__peso-input {
  flex: 1; background: #f4f8f4; border: 1.5px solid #d4e6d4; border-radius: 9px;
  padding: .65rem .875rem; font-size: 1.05rem; font-weight: 700; color: #0f172a; outline: none;
  transition: border-color .15s;
}
.qr__peso-input:focus { border-color: #1b5e20; }
.qr__peso-unit { font-size: .9rem; font-weight: 700; color: #4a7c59; }

/* Feedback */
.qr__err-inline { display: flex; align-items: center; gap: .4rem; background: #fef2f2; border: 1px solid #fecaca; color: #dc2626; padding: .6rem .875rem; border-radius: 8px; font-size: .82rem; }
.qr__registro-ok { display: flex; align-items: center; gap: .4rem; background: #f0fdf4; color: #16a34a; font-size: .82rem; font-weight: 700; padding: .6rem .875rem; border-radius: 8px; }

/* Error states */
.qr__err-ico   { font-size: 3rem; margin-bottom: .5rem; }
.qr__err-title { font-size: 1.1rem; font-weight: 800; color: #0f172a; margin-bottom: .4rem; }
.qr__err-desc  { font-size: .82rem; color: #64748b; line-height: 1.5; margin-bottom: .75rem; }
.qr__code-badge { font-family: monospace; font-size: .72rem; color: #94a3b8; background: #f1f5f9; border: 1px solid #e2e8f0; padding: .35rem .75rem; border-radius: 6px; }

/* Buttons */
.qr__btn-primary {
  width: 100%; display: flex; align-items: center; justify-content: center; gap: .5rem;
  background: #1b5e20; color: #fff; border: none; border-radius: 10px;
  padding: .875rem; font-size: .925rem; font-weight: 700; cursor: pointer; transition: background .15s;
}
.qr__btn-primary:hover:not(:disabled) { background: #14532d; }
.qr__btn-primary:disabled { opacity: .5; cursor: not-allowed; }
.qr__btn-secondary {
  display: inline-flex; align-items: center; gap: .4rem;
  background: #f1f5f9; color: #475569; border: none; border-radius: 8px;
  padding: .55rem 1rem; font-size: .82rem; font-weight: 600; cursor: pointer;
}
.qr__btn-volver {
  display: inline-flex; align-items: center; gap: .4rem;
  color: #4a7c59; font-size: .82rem; font-weight: 600; text-decoration: none;
  padding: .4rem 0;
}
.qr__btn-volver:hover { color: #1b5e20; }

/* Footer */
.qr__footer {
  background: #f8fafc; border-top: 1px solid #f1f5f9;
  padding: .75rem 1.5rem;
  display: flex; align-items: center; gap: .5rem;
  font-size: .73rem; color: #64748b;
}
.qr__footer-dot { width: 7px; height: 7px; border-radius: 50%; background: #22c55e; flex-shrink: 0; }
.qr__footer-sep { opacity: .4; }
</style>
