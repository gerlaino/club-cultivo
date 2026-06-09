<script setup>
import { ref, computed, onMounted, onUnmounted, watch } from 'vue'
import { useRoute } from 'vue-router'

const props = defineProps({ backPath: { type: String, default: '/pacientes' } })
import { usePacientesStore } from '../stores/pacientes'
import { useAuthStore } from '../stores/auth'
import Breadcrumb from '../components/ui/Breadcrumb.vue'
import IndicacionesMedicas from '../components/pacientes/IndicacionesMedicas.vue'
import Dispensaciones from '../components/pacientes/Dispensaciones.vue'
import PatientDocuments from '../components/pacientes/PacienteDocumentos.vue'
import { getPacienteTimeline } from '../lib/api.js'
import {
  User, ShieldCheck, Pill, BookOpen, FileText, ClipboardList, Clock,
  Pencil, AlertTriangle, Info, Wallet, CreditCard, Mail
} from 'lucide-vue-next'
import { REPROCANN_ESTADOS } from '../composables/useSocioEditar.js'
import DsSpinner               from '../design-system/components/Spinner.vue'
import SocioTabTimeline        from '../components/pacientes/SocioTabTimeline.vue'
import SocioTabCuentaCorriente from '../components/pacientes/SocioTabCuentaCorriente.vue'
import SocioTabCorreo          from '../components/pacientes/SocioTabCorreo.vue'
import SocioTabHistoria        from '../components/pacientes/SocioTabHistoria.vue'
import SocioTabNotas           from '../components/pacientes/SocioTabNotas.vue'
import SocioEditarModal        from '../components/pacientes/SocioEditarModal.vue'

const route  = useRoute()
const store  = usePacientesStore()
const auth   = useAuthStore()

const socioId   = Number(route.params.id)
const loading   = ref(true)
const error     = ref(null)
const activeTab = ref('info')

const canEdit    = computed(() => ['admin', 'medico', 'super_admin'].includes(auth.user?.role))
const s          = computed(() => store.current)
const edadSocio  = computed(() => s.value ? edad(s.value.fecha_nacimiento) : null)

const reprocannEstadoMeta = computed(() =>
  REPROCANN_ESTADOS.find(e => e.value === (s.value?.reprocann_estado || 'sin_registro'))
)

const editarOpen = ref(false)

const ccRefreshKey = ref(0)
function onDispensacionCreada() { ccRefreshKey.value++ }

// ── Timeline ──────────────────────────────────────────────────────────────────
const timeline        = ref([])
const timelineLoading = ref(false)
const timelineLoaded  = ref(false)

async function loadTimeline() {
  if (timelineLoaded.value) return
  timelineLoading.value = true
  try {
    const { data } = await getPacienteTimeline(socioId)
    timeline.value = data.timeline ?? []
    timelineLoaded.value = true
  } catch {
    timeline.value = []
  } finally {
    timelineLoading.value = false
  }
}

watch(activeTab, (tab) => {
  if (tab === 'timeline') loadTimeline()
})

// ── Helpers ───────────────────────────────────────────────────────────────────
function safeDate(d) {
  if (!d) return null
  return /^\d{4}-\d{2}-\d{2}$/.test(d) ? new Date(d + 'T00:00:00') : new Date(d)
}
function formatDate(d) {
  if (!d) return '—'
  return safeDate(d).toLocaleDateString('es-AR', { day: 'numeric', month: 'long', year: 'numeric' })
}
function edad(fn) {
  if (!fn) return null
  return Math.floor((Date.now() - safeDate(fn).getTime()) / (1000 * 60 * 60 * 24 * 365.25))
}

const reprocannStatus = computed(() => {
  if (!s.value?.reprocann_vencimiento) return null
  const days = Math.floor((safeDate(s.value.reprocann_vencimiento) - new Date()) / 86400000)
  if (days < 0)   return { label: 'Vencido',                        color: '#dc2626', bg: 'rgba(220,38,38,.1)',   key: 'danger'  }
  if (days <= 30) return { label: `Vence en ${days} días`,           color: '#d97706', bg: 'rgba(217,119,6,.1)',  key: 'warning' }
  return               { label: `Vigente — ${days} días restantes`, color: '#15803d', bg: 'rgba(21,128,61,.1)',  key: 'success' }
})

const AVATAR_COLORS = ['#1b5e20','#0369a1','#7c3aed','#b45309','#0891b2','#dc2626','#15803d']
function avatarColor(id) { return AVATAR_COLORS[(id || 0) % AVATAR_COLORS.length] }

const ALL_TABS = [
  { key: 'info',             label: 'Datos',            icon: User },
  { key: 'reprocann',        label: 'REPROCANN',         icon: ShieldCheck },
  { key: 'dispensaciones',   label: 'Dispensaciones',    icon: Pill },
  { key: 'cuenta_corriente', label: 'Cuenta corriente',  icon: Wallet,        roles: ['admin', 'dispensador'] },
  { key: 'historia',         label: 'Historia clínica',  icon: ClipboardList, roles: ['admin', 'medico'] },
  { key: 'notas',            label: 'Notas',             icon: BookOpen,      roles: ['admin', 'medico'] },
  { key: 'documentos',       label: 'Documentos',        icon: FileText,      roles: ['admin', 'medico', 'auditor', 'abogado'] },
  { key: 'timeline',         label: 'Timeline',          icon: Clock,         roles: ['admin', 'medico'] },
  { key: 'correo',           label: 'Correo',            icon: Mail,          roles: ['admin', 'supervisor'] },
]


const TABS = computed(() => {
  const role = auth.user?.role
  return ALL_TABS.filter(t => !t.roles || t.roles.includes(role))
})

function escapeHandler(e) {
  if (e.key !== 'Escape') return
  if (editarOpen.value) { editarOpen.value = false }
}
onMounted(async () => {
  document.addEventListener('keydown', escapeHandler, true)
  try {
    await store.fetchOne(socioId)
    await store.fetchNotas(socioId)
  } catch (e) {
    error.value = store.error || 'No se pudo cargar el paciente'
  } finally {
    loading.value = false
  }
})
onUnmounted(() => { document.removeEventListener('keydown', escapeHandler, true) })
</script>

<template>
  <div class="sd">

    <!-- Loading -->
    <div v-if="loading" class="sd__loading">
      <DsSpinner />
    </div>
    <div v-else-if="error" class="sd__error">{{ error }}</div>
    <div v-else-if="!s" class="sd__error">Paciente no encontrado.</div>

    <template v-else>

      <!-- Breadcrumb -->
      <Breadcrumb :items="[{ label: 'Pacientes', to: props.backPath }, { label: `${s.nombre} ${s.apellido}` }]" />

      <!-- Hero -->
      <div class="sd__hero">
        <div class="sd__hero-left">
          <div class="sd__avatar" :style="{ background: avatarColor(s.id) }">
            {{ (s.nombre?.[0] || '') + (s.apellido?.[0] || '') }}
          </div>
          <div class="sd__hero-info">
            <h1 class="sd__hero-name">{{ s.nombre }} {{ s.apellido }}</h1>
            <div class="sd__hero-meta">
              <span>DNI {{ s.dni || '—' }}</span>
              <span v-if="edadSocio" class="sd__meta-sep">·</span>
              <span v-if="edadSocio">{{ edadSocio }} años</span>
            </div>
            <div class="sd__hero-badges">
              <span v-if="reprocannStatus"
                    class="sd__repro-badge"
                    :style="{ background: reprocannStatus.bg, color: reprocannStatus.color }">
                {{ reprocannStatus.label }}
              </span>
              <span v-else class="sd__repro-badge sd__repro-badge--none">Sin REPROCANN</span>
              <span v-if="s.es_paciente" class="sd__status-badge sd__status-badge--active">En tratamiento</span>
              <span v-else class="sd__status-badge">Inactivo</span>
            </div>
          </div>
        </div>
        <div class="sd__hero-actions">
          <RouterLink v-if="s?.carnet_token" :to="`/c/${s.carnet_token}`" target="_blank" class="sd__btn-carnet">
            <CreditCard :size="14" :stroke-width="1.75" /> Carnet
          </RouterLink>
          <button v-if="canEdit" class="sd__btn-edit" @click="editarOpen = true">
            <Pencil :size="14" :stroke-width="1.75" /> Editar
          </button>
        </div>
      </div>

      <!-- Alerta REPROCANN -->
      <div v-if="reprocannStatus?.key === 'danger'" class="sd__alerta sd__alerta--danger">
        <AlertTriangle :size="16" />
        <div><strong>REPROCANN vencido</strong> — El certificado venció el {{ formatDate(s.reprocann_vencimiento) }}.</div>
      </div>
      <div v-else-if="reprocannStatus?.key === 'warning'" class="sd__alerta sd__alerta--warning">
        <AlertTriangle :size="16" />
        <div><strong>REPROCANN por vencer</strong> — El certificado vence el {{ formatDate(s.reprocann_vencimiento) }}.</div>
      </div>

      <!-- Tabs -->
      <div class="sd__tabs">
        <button
          v-for="tab in TABS" :key="tab.key"
          class="sd__tab"
          :class="{ 'sd__tab--active': activeTab === tab.key }"
          @click="activeTab = tab.key"
        >
          <component :is="tab.icon" :size="14" :stroke-width="1.75" />
          {{ tab.label }}
          <span v-if="tab.key === 'notas' && store.notas.length" class="sd__tab-badge">
            {{ store.notas.length }}
          </span>
        </button>
      </div>

      <!-- ── Tab: Datos ── -->
      <div v-show="activeTab === 'info'" class="sd__tab-content">
        <div class="sd__card">
          <div class="sd__card-header">
            <div class="sd__card-icon sd__card-icon--blue"><User :size="15" /></div>
            <span class="sd__card-title">Datos personales</span>
          </div>
          <div class="sd__info-grid">
            <div class="sd__info-item">
              <div class="sd__info-label">Nombre completo</div>
              <div class="sd__info-val">{{ s.nombre }} {{ s.apellido }}</div>
            </div>
            <div class="sd__info-item">
              <div class="sd__info-label">DNI</div>
              <div class="sd__info-val sd__info-val--mono">{{ s.dni || '—' }}</div>
            </div>
            <div class="sd__info-item">
              <div class="sd__info-label">Fecha de nacimiento</div>
              <div class="sd__info-val">{{ formatDate(s.fecha_nacimiento) }}</div>
            </div>
            <div class="sd__info-item">
              <div class="sd__info-label">Edad</div>
              <div class="sd__info-val">{{ edadSocio ? edadSocio + ' años' : '—' }}</div>
            </div>
            <div class="sd__info-item sd__info-item--full">
              <div class="sd__info-label">Email</div>
              <div class="sd__info-val">{{ s.email || '—' }}</div>
            </div>
            <div class="sd__info-item sd__info-item--full">
              <div class="sd__info-label">Teléfono</div>
              <div class="sd__info-val">{{ s.telefono || '—' }}</div>
            </div>
          </div>
        </div>
        <div class="sd__sys-info">
          <span>ID sistema: <strong>#{{ s.id }}</strong></span>
          <span>Registrado: <strong>{{ formatDate(s.created_at) }}</strong></span>
          <span>Actualizado: <strong>{{ formatDate(s.updated_at) }}</strong></span>
        </div>
      </div>

      <!-- ── Tab: REPROCANN ── -->
      <div v-show="activeTab === 'reprocann'" class="sd__tab-content">
        <div class="sd__card" :class="reprocannStatus?.key === 'danger' ? 'sd__card--danger' : reprocannStatus?.key === 'warning' ? 'sd__card--warning' : ''">
          <div class="sd__card-header">
            <div class="sd__card-icon sd__card-icon--green"><ShieldCheck :size="15" /></div>
            <span class="sd__card-title">Datos REPROCANN</span>
          </div>
          <div class="sd__info-grid">
            <div class="sd__info-item">
              <div class="sd__info-label">Estado REPROCANN</div>
              <div class="sd__info-val">
                <span class="sd__inline-badge"
                      :style="{ background: reprocannEstadoMeta?.bg, color: reprocannEstadoMeta?.color, borderColor: reprocannEstadoMeta?.color }">
                  {{ reprocannEstadoMeta?.label || '—' }}
                </span>
              </div>
            </div>
            <div class="sd__info-item">
              <div class="sd__info-label">N° autorización</div>
              <div class="sd__info-val sd__info-val--mono">{{ s.reprocann_numero || '—' }}</div>
            </div>
            <div class="sd__info-item">
              <div class="sd__info-label">Vencimiento</div>
              <div class="sd__info-val">
                <span v-if="s.reprocann_vencimiento">
                  {{ formatDate(s.reprocann_vencimiento) }}
                  <span v-if="reprocannStatus" class="sd__inline-badge"
                        :style="{ background: reprocannStatus.bg, color: reprocannStatus.color }">
                    {{ reprocannStatus.label }}
                  </span>
                </span>
                <span v-else class="sd__val-empty">Sin datos</span>
              </div>
            </div>
            <div class="sd__info-item">
              <div class="sd__info-label">Estado del tratamiento</div>
              <div class="sd__info-val">
                <span v-if="s.es_paciente" style="color:#15803d;font-weight:600">✓ En tratamiento activo</span>
                <span v-else class="sd__val-empty">Inactivo</span>
              </div>
            </div>
          </div>
          <div class="sd__card-note">
            <Info :size="12" />
            Vigencia del certificado: 3 años (Res. 1780/2025). Las ONG deben renovar anualmente.
          </div>
        </div>
        <div class="sd__card" style="margin-top:1rem">
          <div class="sd__card-header">
            <div class="sd__card-icon sd__card-icon--green"><FileText :size="15" /></div>
            <span class="sd__card-title">Indicaciones médicas</span>
          </div>
          <IndicacionesMedicas :socio-id="socioId" />
        </div>
      </div>

      <!-- ── Tab: Dispensaciones ── -->
      <div v-show="activeTab === 'dispensaciones'" class="sd__tab-content">
        <div class="sd__card">
          <Dispensaciones
            :socio-id="socioId"
            :paciente-nombre="s ? `${s.nombre} ${s.apellido}`.trim() : ''"
            :limite-mensual-g="s?.limite_dispensacion_mensual_g ? Number(s.limite_dispensacion_mensual_g) : null"
            :dispensado-mes-g="s?.dispensado_mes_actual_g ?? null"
            :saldo-cc="s?.saldo_cc ?? null"
            :limite-cc="s?.limite_cc ?? null"
            :saldo-cc-g="s?.saldo_cc_g ?? null"
            :limite-cc-g="s?.limite_cc_g ?? null"
            :cc-gramos-activo="s?.cc_gramos_activo ?? false"
            :descuento-porcentaje="Number(s?.descuento_porcentaje ?? 0)"
            @dispensacion-creada="onDispensacionCreada"
          />
        </div>
      </div>

      <!-- ── Tab: Cuenta corriente ── -->
      <div v-show="activeTab === 'cuenta_corriente'" class="sd__tab-content">
        <SocioTabCuentaCorriente
          :socio-id="socioId"
          :refresh-key="ccRefreshKey"
          :readonly="auth.user?.role === 'dispensador'"
        />
      </div>

      <!-- ── Tab: Historia clínica ── -->
      <div v-show="activeTab === 'historia'" class="sd__tab-content">
        <SocioTabHistoria :socio-id="socioId" :s="s" />
      </div>

      <!-- ── Tab: Notas ── -->
      <div v-show="activeTab === 'notas'" class="sd__tab-content">
        <SocioTabNotas :socio-id="socioId" :can-edit="canEdit" />
      </div>

      <!-- ── Tab: Documentos ── -->
      <div v-show="activeTab === 'documentos'" class="sd__tab-content">
        <div class="sd__card">
          <PatientDocuments :socio-id="socioId" :socio-nombre="`${s.nombre} ${s.apellido}`" />
        </div>
      </div>

      <!-- ── Tab: Timeline ── -->
      <div v-show="activeTab === 'timeline'" class="sd__tab-content">
        <SocioTabTimeline :timeline="timeline" :timeline-loading="timelineLoading" />
      </div>

      <!-- ── Tab: Correo ── -->
      <div v-show="activeTab === 'correo'" class="sd__tab-content">
        <SocioTabCorreo :socio-id="socioId" :socio="s" @open-edit="editarOpen = true" />
      </div>

    </template>
  </div>

  <SocioEditarModal v-model:open="editarOpen" :socio-id="socioId" @saved="store.fetchOne(socioId)" />
</template>

<style scoped>
.sd { padding: 2rem 1.75rem 3rem; max-width: 1100px; margin: 0 auto; font-family: system-ui, -apple-system, sans-serif; color: #0f172a; }
@media (max-width: 768px) { .sd { padding: 1.25rem 1rem 2rem; } }

/* Loading / Error */
.sd__loading { display: flex; align-items: center; justify-content: center; min-height: calc(100vh - 56px); }
.sd__error { background: #fef2f2; border: 1px solid #fecaca; color: #dc2626; padding: 1rem; border-radius: 10px; }

/* Hero */
.sd__hero { display: flex; align-items: flex-start; justify-content: space-between; gap: 1.25rem; margin-bottom: 1.25rem; flex-wrap: wrap; }
.sd__hero-left { display: flex; align-items: center; gap: 1.1rem; }
.sd__avatar { width: 64px; height: 64px; border-radius: 16px; display: flex; align-items: center; justify-content: center; color: #fff; font-size: 1.4rem; font-weight: 800; flex-shrink: 0; letter-spacing: -.02em; }
.sd__hero-name { font-size: 1.6rem; font-weight: 800; margin: 0 0 .2rem; letter-spacing: -.04em; }
.sd__hero-meta { font-size: .82rem; color: #64748b; margin-bottom: .5rem; display: flex; align-items: center; gap: .4rem; }
.sd__meta-sep { color: #cbd5e1; }
.sd__hero-badges { display: flex; align-items: center; gap: .5rem; flex-wrap: wrap; }
.sd__repro-badge { font-size: .72rem; font-weight: 700; padding: .25em .75em; border-radius: 999px; }
.sd__repro-badge--none { background: rgba(100,116,139,.1); color: #64748b; }
.sd__status-badge { font-size: .7rem; font-weight: 600; padding: .22em .65em; border-radius: 6px; background: #f1f5f9; color: #64748b; }
.sd__status-badge--active { background: rgba(21,128,61,.1); color: #15803d; }

/* Alertas */
.sd__alerta { display: flex; align-items: flex-start; gap: .75rem; padding: .875rem 1.1rem; border-radius: 12px; font-size: .875rem; margin-bottom: 1.25rem; }
.sd__alerta--danger { background: #fef2f2; border: 1px solid #fecaca; color: #7f1d1d; }
.sd__alerta--warning { background: #fffbeb; border: 1px solid #fde68a; color: #78350f; }

/* Tabs */
.sd__tabs { display: flex; gap: .25rem; border-bottom: 2px solid #e2e8f0; margin-bottom: 1.5rem; flex-wrap: wrap; }
.sd__tab { display: flex; align-items: center; gap: .4rem; padding: .65rem 1rem; border-radius: 8px 8px 0 0; border: none; border-bottom: 2px solid transparent; margin-bottom: -2px; background: none; font-size: .82rem; font-weight: 600; color: #64748b; cursor: pointer; transition: all .15s; }
.sd__tab:hover { color: #0f172a; background: #f8fafc; }
.sd__tab--active { color: #1b5e20; border-bottom-color: #1b5e20; }
.sd__tab-badge { background: #e8f5e9; color: #1b5e20; font-size: .65rem; font-weight: 700; padding: .1em .5em; border-radius: 999px; }

/* Cards */
.sd__card { background: #fff; border: 1px solid #e2e8f0; border-radius: 14px; overflow: hidden; margin-bottom: 1rem; }
.sd__card--mt { margin-top: 1rem; }
.sd__card--danger { border-color: #fecaca; border-left: 3px solid #dc2626; }
.sd__card--warning { border-color: #fde68a; border-left: 3px solid #d97706; }
.sd__card-header { display: flex; align-items: flex-start; gap: .65rem; padding: 1rem 1.25rem; border-bottom: 1px solid #f1f5f9; background: #fafbfc; }
.sd__card-icon { width: 32px; height: 32px; border-radius: 9px; display: flex; align-items: center; justify-content: center; flex-shrink: 0; }
.sd__card-icon--blue  { background: rgba(3,105,161,.1);  color: #0369a1; }
.sd__card-icon--green { background: rgba(21,128,61,.1);  color: #15803d; }
.sd__card-icon--amber { background: rgba(180,83,9,.1);   color: #b45309; }
.sd__card-title { font-size: .875rem; font-weight: 700; color: #0f172a; margin-top: .15rem; }
.sd__card-subtitle { font-size: .72rem; color: #64748b; margin-top: .1rem; }
.sd__card-note { padding: .75rem 1.25rem; border-top: 1px solid #f1f5f9; font-size: .72rem; color: #94a3b8; display: flex; align-items: center; gap: .4rem; background: #fafbfc; }

/* Info grid */
.sd__info-grid { display: grid; grid-template-columns: 1fr 1fr; }
.sd__info-item { padding: .875rem 1.25rem; border-bottom: 1px solid #f8fafc; border-right: 1px solid #f8fafc; }
.sd__info-item:nth-child(even) { border-right: none; }
.sd__info-item--full { grid-column: 1 / -1; border-right: none; }
.sd__info-label { font-size: .68rem; color: #94a3b8; font-weight: 500; text-transform: uppercase; letter-spacing: .05em; margin-bottom: .25rem; }
.sd__info-val { font-size: .875rem; font-weight: 600; color: #0f172a; }
.sd__info-val--mono { font-family: monospace; }
.sd__val-empty { color: #94a3b8; font-weight: 400; }
.sd__inline-badge { display: inline-flex; align-items: center; font-size: .68rem; font-weight: 700; padding: .18em .6em; border-radius: 6px; margin-left: .4rem; }

/* Sys info */
.sd__sys-info { display: flex; gap: 2rem; flex-wrap: wrap; padding: .875rem 1.25rem; background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 10px; font-size: .78rem; color: #64748b; }

/* Buttons */
.sd__btn-edit { display: inline-flex; align-items: center; gap: .4rem; background: #fff; color: #475569; border: 1.5px solid #e2e8f0; padding: .55rem 1rem; border-radius: 9px; font-size: .82rem; font-weight: 600; cursor: pointer; transition: all .15s; }
.sd__btn-edit:hover { border-color: #1b5e20; color: #1b5e20; background: #f0fdf4; }
.sd__btn-carnet { display: inline-flex; align-items: center; gap: .4rem; background: #1b5e20; color: #fff; border: none; padding: .55rem 1rem; border-radius: 9px; font-size: .82rem; font-weight: 600; cursor: pointer; transition: background .15s; text-decoration: none; }
.sd__btn-carnet:hover { background: #144a18; }
.sd__btn-primary { display: inline-flex; align-items: center; gap: .4rem; background: #1b5e20; color: #fff; border: none; padding: .6rem 1.1rem; border-radius: 9px; font-size: .82rem; font-weight: 600; cursor: pointer; transition: background .15s; }
.sd__btn-primary:hover:not(:disabled) { background: #144a18; }
.sd__btn-primary:disabled { opacity: .5; cursor: not-allowed; }
.sd__btn-ghost { display: inline-flex; align-items: center; gap: .4rem; background: none; color: #475569; border: 1.5px solid #e2e8f0; padding: .6rem 1.1rem; border-radius: 9px; font-size: .82rem; font-weight: 600; cursor: pointer; transition: all .15s; }
.sd__btn-ghost:hover { border-color: #94a3b8; }

/* Documento REPROCANN */
.sd__repro-doc-body { padding: 1rem 1.25rem; }
.sd__repro-doc-row { display: flex; align-items: center; gap: .75rem; }
.sd__repro-doc-link { display: inline-flex; align-items: center; gap: .4rem; font-size: .875rem; font-weight: 600; color: #0369a1; text-decoration: none; padding: .45rem .9rem; border: 1.5px solid #bae6fd; border-radius: 8px; background: #f0f9ff; transition: all .15s; }
.sd__repro-doc-link:hover { background: #e0f2fe; border-color: #0369a1; }
.sd__repro-upload-row { display: flex; align-items: center; gap: .75rem; flex-wrap: wrap; }
.sd__repro-hint { font-size: .72rem; color: #94a3b8; }

/* Modal genérico */
.sd__overlay { position: fixed; inset: 0; background: rgba(0,0,0,.45); z-index: 9999; display: flex; align-items: center; justify-content: center; padding: 1rem; }
.sd__modal { background: white; border-radius: 16px; max-height: 90vh; overflow-y: auto; width: 100%; box-shadow: 0 20px 60px rgba(0,0,0,.2); }
.sd__modal-header { display: flex; align-items: center; justify-content: space-between; padding: 1.25rem 1.5rem; border-bottom: 1px solid #f1f5f9; }
.sd__modal-title { font-size: 1rem; font-weight: 700; color: #1a1a1a; margin: 0; }
.sd__modal-close { background: none; border: none; cursor: pointer; color: #94a3b8; padding: .25rem; border-radius: 6px; }
.sd__modal-close:hover { background: #f8fafc; color: #475569; }
.sd__modal-body { padding: 1.25rem 1.5rem; display: flex; flex-direction: column; gap: 1rem; }
.sd__modal-footer { padding: 1rem 1.5rem; border-top: 1px solid #f1f5f9; display: flex; justify-content: flex-end; gap: .75rem; }
.sd__form-row { display: flex; flex-direction: column; gap: .35rem; }
.sd__form-label { font-size: .75rem; font-weight: 600; color: #475569; }
.sd__form-input { padding: .55rem .8rem; border: 1px solid #cbd5e1; border-radius: 7px; font-size: .875rem; width: 100%; box-sizing: border-box; outline: none; font-family: inherit; }
.sd__form-input:focus { border-color: #1b5e20; box-shadow: 0 0 0 2px #dcfce7; }

/* Renovaciones REPROCANN */
.sd__reno-form { padding: .75rem 1.25rem; display: flex; flex-direction: column; gap: .6rem; border-bottom: 1px solid #f1f5f9; }
.sd__reno-row { display: flex; flex-direction: column; gap: .25rem; }
.sd__reno-row label { font-size: .75rem; font-weight: 600; color: #475569; }
.sd__reno-input { width: 100%; padding: .45rem .7rem; border: 1px solid #cbd5e1; border-radius: 6px; font-size: .875rem; outline: none; }
.sd__reno-input:focus { border-color: #1b5e20; box-shadow: 0 0 0 2px #dcfce7; }
.sd__reno-actions { display: flex; justify-content: flex-end; gap: .5rem; }
.sd__reno-empty { padding: 1rem 1.25rem; color: #94a3b8; font-size: .85rem; }
.sd__reno-list { display: flex; flex-direction: column; gap: 0; }
.sd__reno-item { padding: .75rem 1.25rem; border-bottom: 1px solid #f1f5f9; }
.sd__reno-item:last-child { border-bottom: none; }
.sd__reno-item-head { display: flex; align-items: center; gap: .6rem; flex-wrap: wrap; }
.sd__reno-estado { font-size: .7rem; font-weight: 700; padding: .15rem .5rem; border-radius: 999px; }
.sd__reno-numero { font-size: .8rem; font-weight: 600; color: #334155; }
.sd__reno-fecha { font-size: .75rem; color: #94a3b8; margin-left: auto; }
.sd__reno-acciones { display: flex; gap: .3rem; }
.sd__reno-obs { margin-top: .3rem; font-size: .8rem; color: #64748b; }
.sd__reno-aprobado { margin-top: .3rem; font-size: .78rem; color: #15803d; font-weight: 600; }
.sd__btn-tiny { display: inline-flex; align-items: center; padding: .25rem .4rem; border: 1px solid; border-radius: 5px; cursor: pointer; background: transparent; transition: all .15s; }
.sd__btn-tiny--ok { border-color: #bbf7d0; color: #15803d; }
.sd__btn-tiny--ok:hover { background: #dcfce7; }
.sd__btn-tiny--danger { border-color: #fecaca; color: #dc2626; }
.sd__btn-tiny--danger:hover { background: #fee2e2; }
.sd__btn-tiny--ghost { border-color: #e2e8f0; color: #94a3b8; }
.sd__btn-tiny--ghost:hover { background: #f8fafc; color: #475569; }

</style>
