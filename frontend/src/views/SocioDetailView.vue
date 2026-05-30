<script setup>
import { ref, computed, onMounted, onUnmounted, watch } from 'vue'
import { useRoute } from 'vue-router'

const props = defineProps({ backPath: { type: String, default: '/pacientes' } })
import { usePacientesStore } from '../stores/pacientes'
import { useAuthStore } from '../stores/auth'
import Breadcrumb from '../components/ui/Breadcrumb.vue'
import { useConfirm } from '../composables/useConfirm.js'
import IndicacionesMedicas from '../components/pacientes/IndicacionesMedicas.vue'
import Dispensaciones from '../components/pacientes/Dispensaciones.vue'
import PatientDocuments from '../components/pacientes/PacienteDocumentos.vue'
import { getPacienteTimeline } from '../lib/api.js'
import {
  User, ShieldCheck, Pill, BookOpen, FileText, ClipboardList, Clock,
  Pencil, Plus, Trash2, AlertTriangle, CheckCircle, Info, X, Save, Wallet,
  CreditCard, Mail
} from 'lucide-vue-next'
import { useSocioEditar, REPROCANN_ESTADOS } from '../composables/useSocioEditar.js'
import { useSocioHistoriaClinica }           from '../composables/useSocioHistoriaClinica.js'
import { useSocioCorreo, MAIL_TEMPLATES }    from '../composables/useSocioCorreo.js'
import { useSocioCuentaCorriente }           from '../composables/useSocioCuentaCorriente.js'
import DsSpinner from '../design-system/components/Spinner.vue'

const route  = useRoute()
const store  = usePacientesStore()
const auth   = useAuthStore()
const { confirm } = useConfirm()

const socioId   = Number(route.params.id)
const loading   = ref(true)
const error     = ref(null)
const activeTab = ref('info')

const canEdit    = computed(() => ['admin', 'medico', 'super_admin'].includes(auth.user?.role))
const canClinica = computed(() => ['admin', 'medico', 'super_admin'].includes(auth.user?.role))
const s          = computed(() => store.current)

const reprocannEstadoMeta = computed(() =>
  REPROCANN_ESTADOS.find(e => e.value === (s.value?.reprocann_estado || 'sin_registro'))
)

// ── Composables ───────────────────────────────────────────────────────────────
const {
  editOpen, editForm, editSaving, editError,
  openEdit, saveEdit,
} = useSocioEditar(socioId)

const {
  notasClinicas, notasClinicasSaved, notasClinicasSaving,
  hcForm, saveNotasClinicas,
} = useSocioHistoriaClinica(socioId, { s })

const {
  mailHistory, mailLoading, mailSending, mailPreview, mailTemplate, mailForm,
  applyMailTemplate, loadMailHistory, submitMail,
} = useSocioCorreo(socioId, { s })

const {
  cc, loadingCC,
  limiteEditOpen, limiteEditVal, savingLimite,
  togglingGramos,
  limiteGOpen, limiteGVal, savingLimiteG,
  cargarGOpen, cargarGVal, savingCargarG,
  fmtARS, ccDeudaActual, ccMargen, ccPorcentaje,
  openLimiteEdit, loadCC, saveLimite, toggleGramos, saveLimiteG, doCargarG,
  onDispensacionCreada: _onDispCC,
} = useSocioCuentaCorriente(socioId)

function onDispensacionCreada() { _onDispCC(activeTab.value) }

// ── Notas rápidas ─────────────────────────────────────────────────────────────
const notaTexto = ref('')
async function agregarNota() {
  const txt = notaTexto.value.trim()
  if (!txt) return
  try { await store.addNota(socioId, txt); notaTexto.value = '' } catch {}
}
async function borrarNota(n) {
  const ok = await confirm({ title: '¿Eliminar esta nota?', confirmText: 'Eliminar' })
  if (!ok) return
  try { await store.removeNota(n.id) } catch {}
}

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
  if (tab === 'cuenta_corriente') loadCC()
  if (tab === 'correo' && mailHistory.value.length === 0) loadMailHistory()
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
function formatDateTime(d) {
  if (!d) return '—'
  return new Date(d).toLocaleString('es-AR', { day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' })
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

const TIMELINE_COLORS = {
  dispensacion: '#0369a1',
  nota: '#b45309',
  indicacion: '#7c3aed',
  alta: '#15803d',
}
function timelineColor(tipo) { return TIMELINE_COLORS[tipo] || '#64748b' }
function timelineLabel(tipo) {
  const L = { dispensacion: 'Dispensación', nota: 'Nota clínica', indicacion: 'Indicación médica', alta: 'Alta' }
  return L[tipo] || tipo
}

const ALL_TABS = [
  { key: 'info',             label: 'Datos',            icon: User },
  { key: 'reprocann',        label: 'REPROCANN',         icon: ShieldCheck },
  { key: 'dispensaciones',   label: 'Dispensaciones',    icon: Pill },
  { key: 'cuenta_corriente', label: 'Cuenta corriente',  icon: Wallet,        roles: ['admin'] },
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
  if (editOpen.value) { editOpen.value = false }
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
              <span v-if="edad(s.fecha_nacimiento)" class="sd__meta-sep">·</span>
              <span v-if="edad(s.fecha_nacimiento)">{{ edad(s.fecha_nacimiento) }} años</span>
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
          <button v-if="canEdit" class="sd__btn-edit" @click="openEdit">
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
              <div class="sd__info-val">{{ edad(s.fecha_nacimiento) ? edad(s.fecha_nacimiento) + ' años' : '—' }}</div>
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
            :saldo-cc-g="cc?.saldo_disponible_g ?? s?.saldo_cc_g ?? null"
            :limite-cc-g="cc?.limite_credito_g ?? s?.limite_cc_g ?? null"
            :cc-gramos-activo="cc?.credito_gramos_activo ?? s?.cc_gramos_activo ?? false"
            @dispensacion-creada="onDispensacionCreada"
          />
        </div>
      </div>

      <!-- ── Tab: Cuenta corriente ── -->
      <div v-show="activeTab === 'cuenta_corriente'" class="sd__tab-content">
        <div v-if="loadingCC" class="sd__cc-loading"><DsSpinner :size="40" /></div>
        <template v-else-if="cc">

          <!-- Saldo, margen y límite -->
          <div class="sd__cc-header">

            <!-- Saldo actual -->
            <div class="sd__cc-saldo-block" :class="cc.saldo_disponible < 0 ? 'sd__cc-saldo-block--deuda' : ''">
              <span class="sd__cc-saldo-label">{{ cc.saldo_disponible < 0 ? 'Deuda actual' : 'Saldo a favor' }}</span>
              <span class="sd__cc-saldo-valor"
                    :class="cc.saldo_disponible < 0 ? 'sd__cc-saldo--deuda' : cc.saldo_disponible > 0 ? 'sd__cc-saldo--ok' : 'sd__cc-saldo--zero'">
                {{ cc.saldo_disponible < 0 ? '−' : '' }}{{ fmtARS(Math.abs(cc.saldo_disponible)) }}
              </span>
              <span class="sd__cc-saldo-hint">
                {{ cc.saldo_disponible < 0 ? 'El socio nos debe este monto' : cc.saldo_disponible > 0 ? 'Pagó por adelantado' : 'Sin saldo ni deuda' }}
              </span>
            </div>

            <!-- Margen disponible (el número que importa para dispensar) -->
            <div class="sd__cc-margen-block" :class="cc.limite_credito > 0 && ccMargen <= 0 ? 'sd__cc-margen-block--agotado' : ''">
              <span class="sd__cc-saldo-label">Puede retirar aún</span>
              <span class="sd__cc-margen-valor" :class="!cc.limite_credito ? 'sd__cc-margen--zero' : ccMargen <= 0 ? 'sd__cc-margen--agotado' : ccMargen < cc.limite_credito * 0.2 ? 'sd__cc-margen--bajo' : 'sd__cc-margen--ok'">
                {{ fmtARS(Math.max(0, ccMargen)) }}
              </span>
              <span class="sd__cc-saldo-hint">
                {{ ccMargen <= 0 ? (cc.limite_credito === 0 ? 'Sin límite configurado' : 'Límite agotado — bloqueado') : 'Antes de ser bloqueado' }}
              </span>
            </div>

            <!-- Límite (editable) -->
            <div class="sd__cc-limite-block">
              <span class="sd__cc-limite-label">Límite de crédito</span>
              <template v-if="!limiteEditOpen">
                <div class="sd__cc-limite-valor-row">
                  <span class="sd__cc-limite-valor">{{ fmtARS(cc.limite_credito) }}</span>
                  <button class="sd__cc-limite-edit-btn" @click="openLimiteEdit" title="Editar límite">
                    <Pencil :size="12" :stroke-width="1.75" />
                  </button>
                </div>
              </template>
              <template v-else>
                <div class="sd__cc-limite-form">
                  <input
                    type="number"
                    min="0"
                    step="100"
                    v-model.number="limiteEditVal"
                    class="sd__cc-limite-input"
                    placeholder="0"
                    @keydown.enter="saveLimite"
                    @keydown.esc="limiteEditOpen = false"
                  />
                  <button class="sd__cc-btn sd__cc-btn--primary sd__cc-btn--sm" :disabled="savingLimite" @click="saveLimite">
                    {{ savingLimite ? '…' : 'Guardar' }}
                  </button>
                  <button class="sd__cc-btn sd__cc-btn--ghost sd__cc-btn--sm" @click="limiteEditOpen = false">
                    Cancelar
                  </button>
                </div>
              </template>
            </div>
          </div>

          <!-- ── Crédito en gramos ── -->
          <div class="sd__cc-gramos-section">
            <div class="sd__cc-gramos-header">
              <div class="sd__cc-gramos-title">
                <i class="bi bi-flower1"></i> Crédito en gramos
              </div>
              <button
                class="sd__cc-toggle"
                :class="cc.credito_gramos_activo ? 'sd__cc-toggle--on' : 'sd__cc-toggle--off'"
                :disabled="togglingGramos"
                @click="toggleGramos"
                :title="cc.credito_gramos_activo ? 'Desactivar crédito en gramos' : 'Activar crédito en gramos'"
              >
                <span class="sd__cc-toggle-knob"></span>
              </button>
            </div>

            <template v-if="cc.credito_gramos_activo">
              <div class="sd__cc-gramos-stats">
                <div class="sd__cc-gramos-stat">
                  <span class="sd__cc-gramos-stat-label">Disponible</span>
                  <span class="sd__cc-gramos-stat-val" :class="cc.saldo_disponible_g <= 0 ? 'sd__cc-gramos--agotado' : 'sd__cc-gramos--ok'">
                    {{ (cc.saldo_disponible_g ?? 0).toFixed(1) }}g
                  </span>
                </div>
                <div class="sd__cc-gramos-stat">
                  <span class="sd__cc-gramos-stat-label">Límite</span>
                  <span class="sd__cc-gramos-stat-val">{{ cc.limite_credito_g ? cc.limite_credito_g.toFixed(1) + 'g' : '—' }}</span>
                </div>
              </div>

              <div class="sd__cc-gramos-actions">
                <!-- Editar límite -->
                <template v-if="!limiteGOpen">
                  <button class="sd__cc-btn sd__cc-btn--ghost sd__cc-btn--sm" @click="limiteGOpen = true; limiteGVal = cc.limite_credito_g ?? null">
                    <Pencil :size="11" :stroke-width="2" /> Límite
                  </button>
                </template>
                <template v-else>
                  <div class="sd__cc-gramos-form">
                    <input type="number" min="0.1" step="0.5" v-model.number="limiteGVal"
                           class="sd__cc-limite-input" placeholder="ej: 50"
                           @keydown.enter="saveLimiteG" @keydown.esc="limiteGOpen = false" />
                    <span class="sd__cc-gramos-unit">g</span>
                    <button class="sd__cc-btn sd__cc-btn--primary sd__cc-btn--sm" :disabled="savingLimiteG" @click="saveLimiteG">
                      {{ savingLimiteG ? '…' : 'OK' }}
                    </button>
                    <button class="sd__cc-btn sd__cc-btn--ghost sd__cc-btn--sm" @click="limiteGOpen = false">✕</button>
                  </div>
                </template>

                <!-- Cargar gramos -->
                <template v-if="!cargarGOpen">
                  <button class="sd__cc-btn sd__cc-btn--primary sd__cc-btn--sm" @click="cargarGOpen = true; cargarGVal = null">
                    + Cargar gramos
                  </button>
                </template>
                <template v-else>
                  <div class="sd__cc-gramos-form">
                    <input type="number" min="0.1" step="0.5" v-model.number="cargarGVal"
                           class="sd__cc-limite-input" placeholder="ej: 20"
                           @keydown.enter="doCargarG" @keydown.esc="cargarGOpen = false" />
                    <span class="sd__cc-gramos-unit">g</span>
                    <button class="sd__cc-btn sd__cc-btn--primary sd__cc-btn--sm" :disabled="savingCargarG" @click="doCargarG">
                      {{ savingCargarG ? '…' : 'Cargar' }}
                    </button>
                    <button class="sd__cc-btn sd__cc-btn--ghost sd__cc-btn--sm" @click="cargarGOpen = false">✕</button>
                  </div>
                </template>
              </div>
            </template>
            <p v-else class="sd__cc-gramos-hint">Activá para permitir que el socio dispense sin pagar en el momento, descontando de un cupo en gramos.</p>
          </div>

          <!-- Barra de deuda utilizada (solo muestra si hay límite Y deuda) -->
          <div v-if="cc.limite_credito > 0 && ccDeudaActual > 0" class="sd__cc-bar-wrap">
            <div class="sd__cc-bar">
              <div class="sd__cc-bar-fill"
                   :style="{ width: ccPorcentaje + '%' }"
                   :class="ccPorcentaje >= 90 ? 'sd__cc-bar-fill--danger' : ccPorcentaje >= 70 ? 'sd__cc-bar-fill--warn' : ''">
              </div>
            </div>
            <span class="sd__cc-bar-pct">{{ ccPorcentaje }}% del crédito utilizado</span>
          </div>

          <!-- Historial de movimientos -->
          <div class="sd__cc-historial">
            <div class="sd__cc-historial-title">Historial</div>
            <div v-if="!cc.movimientos?.length" class="sd__cc-empty">Sin movimientos registrados</div>
            <div v-else class="sd__cc-movs">
              <div v-for="m in cc.movimientos" :key="m.id" class="sd__cc-mov">
                <div class="sd__cc-mov-tipo" :class="`sd__cc-mov-tipo--${m.tipo}`">{{ m.tipo_label }}</div>
                <div class="sd__cc-mov-desc">{{ m.descripcion || '—' }}</div>
                <div class="sd__cc-mov-monto" :class="m.monto >= 0 ? 'sd__cc-mov--pos' : 'sd__cc-mov--neg'">
                  {{ m.monto >= 0 ? '+' : '' }}{{ fmtARS(m.monto) }}
                </div>
                <div class="sd__cc-mov-saldo">Saldo: {{ fmtARS(m.saldo_nuevo) }}</div>
                <div class="sd__cc-mov-meta">{{ m.created_by }} · {{ new Date(m.created_at).toLocaleDateString('es-AR', { day:'numeric', month:'short', year:'numeric' }) }}</div>
              </div>
            </div>
          </div>

        </template>
        <div v-else class="sd__cc-empty">No se pudo cargar la cuenta corriente.</div>
      </div>

      <!-- ── Tab: Historia clínica ── -->
      <div v-show="activeTab === 'historia'" class="sd__tab-content">
        <div class="sd__card">
          <div class="sd__card-header">
            <div class="sd__card-icon sd__card-icon--amber"><ClipboardList :size="15" /></div>
            <div>
              <div class="sd__card-title">Historia clínica estructurada</div>
              <div class="sd__card-subtitle">Solo visible para admin y médico</div>
            </div>
          </div>
          <div class="sd__historia-body" v-if="canClinica">

            <!-- Sección: Datos básicos -->
            <div class="sd__hc-section">
              <div class="sd__hc-section-title">Datos básicos</div>
              <div class="sd__grid">
                <div class="sd__field">
                  <label class="sd__label">Grupo sanguíneo</label>
                  <input v-model="hcForm.grupo_sanguineo" class="sd__input" placeholder="Ej: A+, O-" style="max-width:120px;" />
                </div>
                <div class="sd__field">
                  <label class="sd__label">Alergias</label>
                  <input v-model="hcForm.alergias" class="sd__input" placeholder="Alergias conocidas" />
                </div>
                <div class="sd__field sd__field--full">
                  <label class="sd__label">Medicación habitual</label>
                  <input v-model="hcForm.medicacion_habitual" class="sd__input" placeholder="Medicamentos que toma regularmente" />
                </div>
              </div>
            </div>

            <!-- Sección: Consulta -->
            <div class="sd__hc-section">
              <div class="sd__hc-section-title">Consulta</div>
              <div class="sd__field sd__field--full">
                <label class="sd__label">Motivo de consulta</label>
                <textarea v-model="hcForm.motivo_consulta" class="sd__textarea" rows="3" placeholder="Razón por la que el paciente consulta…" />
              </div>
              <div class="sd__field sd__field--full">
                <label class="sd__label">Anamnesis</label>
                <textarea v-model="hcForm.anamnesis" class="sd__textarea" rows="4" placeholder="Historia de la enfermedad actual, síntomas, evolución…" />
              </div>
            </div>

            <!-- Sección: Antecedentes -->
            <div class="sd__hc-section">
              <div class="sd__hc-section-title">Antecedentes</div>
              <div class="sd__field sd__field--full">
                <label class="sd__label">Antecedentes personales</label>
                <textarea v-model="hcForm.antecedentes_personales" class="sd__textarea" rows="3" placeholder="Enfermedades previas, cirugías, hospitalizaciones…" />
              </div>
              <div class="sd__field sd__field--full">
                <label class="sd__label">Antecedentes familiares</label>
                <textarea v-model="hcForm.antecedentes_familiares" class="sd__textarea" rows="3" placeholder="Enfermedades en familiares directos…" />
              </div>
            </div>

            <!-- Sección: Diagnóstico y evolución -->
            <div class="sd__hc-section">
              <div class="sd__hc-section-title">Diagnóstico</div>
              <div class="sd__grid">
                <div class="sd__field">
                  <label class="sd__label">Diagnóstico principal</label>
                  <input v-model="hcForm.diagnostico_principal" class="sd__input" placeholder="Diagnóstico principal (CIE-10 o libre)" />
                </div>
                <div class="sd__field">
                  <label class="sd__label">Diagnóstico secundario</label>
                  <input v-model="hcForm.diagnostico_secundario" class="sd__input" placeholder="Diagnóstico secundario (opcional)" />
                </div>
              </div>
              <div class="sd__field sd__field--full">
                <label class="sd__label">Evolución clínica</label>
                <textarea v-model="hcForm.evolucion_clinica" class="sd__textarea" rows="4" placeholder="Evolución del paciente, respuesta al tratamiento, observaciones…" />
              </div>
            </div>

            <!-- Sección: Notas libres (compatibilidad) -->
            <div class="sd__hc-section">
              <div class="sd__hc-section-title">Notas adicionales</div>
              <div class="sd__field sd__field--full">
                <label class="sd__label">Notas libres</label>
                <textarea v-model="notasClinicas" class="sd__textarea" rows="5" placeholder="Cualquier otra observación clínica…" />
              </div>
            </div>

            <div class="sd__historia-foot">
              <span v-if="notasClinicasSaved" class="sd__save-ok">
                <CheckCircle :size="13" /> Guardado
              </span>
              <span v-else class="sd__save-pending">Sin guardar</span>
              <button class="sd__btn-primary" :disabled="notasClinicasSaving || notasClinicasSaved" @click="saveNotasClinicas">
                <Save :size="13" :stroke-width="2" />
                {{ notasClinicasSaving ? 'Guardando…' : 'Guardar historia' }}
              </button>
            </div>
          </div>
          <div v-else class="sd__empty">
            <div class="sd__empty-icon"><ClipboardList :size="32" /></div>
            <div class="sd__empty-title">Sin acceso a historia clínica</div>
          </div>
        </div>
      </div>

      <!-- ── Tab: Notas ── -->
      <div v-show="activeTab === 'notas'" class="sd__tab-content">
        <div class="sd__card">
          <div class="sd__card-header">
            <div class="sd__card-icon sd__card-icon--amber"><BookOpen :size="15" /></div>
            <div>
              <div class="sd__card-title">Notas del equipo</div>
              <div class="sd__card-subtitle">Registros internos — no visibles para el paciente</div>
            </div>
          </div>
          <div v-if="canEdit" class="sd__nota-form">
            <textarea
              v-model.trim="notaTexto"
              class="sd__textarea"
              rows="3"
              placeholder="Agregar nota, observación o seguimiento…"
            ></textarea>
            <div class="sd__nota-form-foot">
              <span class="sd__char-count">{{ notaTexto.length }} caracteres</span>
              <button class="sd__btn-primary" :disabled="store.creandoNota || !notaTexto" @click="agregarNota">
                <Plus :size="13" />
                Agregar nota
              </button>
            </div>
          </div>
          <div v-if="store.notasLoading" class="sd__loading-sm"><DsSpinner :size="40" /></div>
          <div v-else-if="!store.notas.length" class="sd__empty">
            <div class="sd__empty-icon"><BookOpen :size="28" /></div>
            <div class="sd__empty-title">Sin notas registradas</div>
          </div>
          <div v-else class="sd__notas">
            <div v-for="n in store.notas" :key="n.id" class="sd__nota">
              <div class="sd__nota-header">
                <div class="sd__nota-meta">{{ formatDateTime(n.created_at) }}</div>
                <button v-if="canEdit" class="sd__btn-icon-danger" @click="borrarNota(n)">
                  <Trash2 :size="13" />
                </button>
              </div>
              <p class="sd__nota-text">{{ n.contenido }}</p>
            </div>
          </div>
        </div>
      </div>

      <!-- ── Tab: Documentos ── -->
      <div v-show="activeTab === 'documentos'" class="sd__tab-content">
        <div class="sd__card">
          <PatientDocuments :socio-id="socioId" :socio-nombre="`${s.nombre} ${s.apellido}`" />
        </div>
      </div>

      <!-- ── Tab: Timeline ── -->
      <div v-show="activeTab === 'timeline'" class="sd__tab-content">
        <div class="sd__card">
          <div class="sd__card-header">
            <div class="sd__card-icon sd__card-icon--blue"><Clock :size="15" /></div>
            <span class="sd__card-title">Timeline del paciente</span>
          </div>
          <div v-if="timelineLoading" class="sd__loading-sm"><DsSpinner :size="40" /></div>
          <div v-else-if="!timeline.length" class="sd__empty">
            <div class="sd__empty-icon"><Clock :size="28" /></div>
            <div class="sd__empty-title">Sin eventos registrados</div>
          </div>
          <div v-else class="sd__timeline">
            <div v-for="(ev, i) in timeline" :key="i" class="sd__tl-item">
              <div class="sd__tl-dot" :style="{ background: timelineColor(ev.tipo) }"></div>
              <div class="sd__tl-body">
                <div class="sd__tl-tipo" :style="{ color: timelineColor(ev.tipo) }">{{ timelineLabel(ev.tipo) }}</div>
                <div class="sd__tl-desc">{{ ev.descripcion }}</div>
                <div class="sd__tl-fecha">{{ formatDateTime(ev.fecha) }}</div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- ── Tab: Correo ── -->
      <div v-show="activeTab === 'correo'" class="sd__tab-content">

        <!-- Sin email: warning -->
        <div v-if="s && !s.email" class="sd__mail-noemail">
          <AlertTriangle :size="20" class="sd__mail-noemail-ico" />
          <div>
            <strong>Este paciente no tiene email registrado.</strong>
            <span> Editá sus datos para agregar uno antes de enviar mensajes.</span>
          </div>
          <button class="sd__mail-edit-link" @click="openEdit()">Editar datos →</button>
        </div>

        <!-- Compose card -->
        <div class="sd__card sd__mail-compose" :class="{ 'sd__mail-compose--disabled': !s?.email }">
          <!-- Header: Para -->
          <div class="sd__mail-to">
            <Mail :size="14" class="sd__mail-to-ico" />
            <span class="sd__mail-to-label">Para:</span>
            <span class="sd__mail-to-name">{{ s?.nombre }} {{ s?.apellido }}</span>
            <span v-if="s?.email" class="sd__mail-to-email">&lt;{{ s.email }}&gt;</span>
            <span v-else class="sd__mail-to-missing">sin email</span>
          </div>

          <!-- Templates -->
          <div class="sd__mail-templates">
            <button
              v-for="tpl in MAIL_TEMPLATES"
              :key="tpl.key"
              class="sd__mail-tpl-chip"
              :class="{ 'sd__mail-tpl-chip--active': mailTemplate === tpl.key }"
              @click="applyMailTemplate(tpl.key)"
            >
              {{ tpl.icon }} {{ tpl.label }}
            </button>
          </div>

          <!-- Preview mode -->
          <div v-if="mailPreview" class="sd__mail-preview">
            <div class="sd__mail-preview-subject">{{ mailForm.asunto || '(sin asunto)' }}</div>
            <div class="sd__mail-preview-body">{{ mailForm.cuerpo || '(sin contenido)' }}</div>
          </div>

          <!-- Edit mode -->
          <template v-else>
            <div class="sd__mail-field">
              <label class="sd__mail-field-label">Asunto</label>
              <input
                v-model="mailForm.asunto"
                class="sd__mail-input"
                placeholder="Asunto del mensaje…"
                maxlength="200"
                :disabled="!s?.email"
              />
            </div>
            <div class="sd__mail-field">
              <label class="sd__mail-field-label">Mensaje</label>
              <textarea
                v-model="mailForm.cuerpo"
                class="sd__mail-textarea"
                placeholder="Escribí el mensaje…"
                rows="7"
                maxlength="3000"
                :disabled="!s?.email"
              ></textarea>
              <div class="sd__mail-charcount">{{ mailForm.cuerpo.length }} / 3000</div>
            </div>
          </template>

          <!-- Actions -->
          <div class="sd__mail-actions">
            <button
              class="sd__mail-preview-btn"
              @click="mailPreview = !mailPreview"
              :disabled="!mailForm.asunto && !mailForm.cuerpo"
            >
              {{ mailPreview ? 'Editar' : 'Vista previa' }}
            </button>
            <button
              class="sd__mail-send-btn"
              :disabled="!s?.email || mailSending || !mailForm.asunto.trim() || !mailForm.cuerpo.trim()"
              @click="submitMail"
            >
              <DsSpinner v-if="mailSending" :size="16" />
              <Mail v-else :size="15" />
              {{ mailSending ? 'Enviando…' : 'Enviar mail' }}
            </button>
          </div>
        </div>

        <!-- Historial -->
        <div class="sd__mail-history-wrap">
          <div class="sd__mail-history-title">Historial de mails enviados</div>

          <div v-if="mailLoading" class="sd__loading-sm"><DsSpinner :size="40" /></div>

          <div v-else-if="!mailHistory.length" class="sd__empty sd__empty--sm">
            <div class="sd__empty-icon"><Mail :size="24" /></div>
            <div class="sd__empty-title">Todavía no se envió ningún mail</div>
          </div>

          <div v-else class="sd__mail-history">
            <div v-for="m in mailHistory" :key="m.id" class="sd__mail-item">
              <div class="sd__mail-item-ico">
                <Mail :size="14" />
              </div>
              <div class="sd__mail-item-body">
                <div class="sd__mail-item-subject">{{ m.asunto }}</div>
                <div class="sd__mail-item-meta">
                  {{ formatDateTime(m.enviado_at) }} · {{ m.remitente }} → {{ m.email_destino }}
                </div>
              </div>
              <div class="sd__mail-item-tipo">
                <span class="sd__mail-tipo-badge">{{ MAIL_TEMPLATES.find(t => t.key === m.tipo)?.icon || '📧' }} {{ m.tipo }}</span>
              </div>
            </div>
          </div>
        </div>

      </div>

    </template>
  </div>

  <!-- ── Inline edit modal ── -->
  <Teleport to="body">
    <Transition name="sd-modal">
      <div v-if="editOpen" class="sd-modal-overlay" @click.self="editOpen = false">
        <div class="sd-modal">
          <div class="sd-modal__header">
            <h2 class="sd-modal__title">Editar paciente</h2>
            <button class="sd-modal__close" @click="editOpen = false"><X :size="18" /></button>
          </div>
          <div class="sd-modal__body">
            <div class="sd-modal__grid">
              <div class="sd-modal__field">
                <label class="sd-modal__label">Nombre</label>
                <input v-model="editForm.nombre" class="sd-modal__input" type="text" />
              </div>
              <div class="sd-modal__field">
                <label class="sd-modal__label">Apellido</label>
                <input v-model="editForm.apellido" class="sd-modal__input" type="text" />
              </div>
              <div class="sd-modal__field">
                <label class="sd-modal__label">DNI</label>
                <input v-model="editForm.dni" class="sd-modal__input" type="text" />
              </div>
              <div class="sd-modal__field">
                <label class="sd-modal__label">Fecha de nacimiento</label>
                <input v-model="editForm.fecha_nacimiento" class="sd-modal__input" type="date" />
              </div>
              <div class="sd-modal__field">
                <label class="sd-modal__label">Email</label>
                <input v-model="editForm.email" class="sd-modal__input" type="email" />
              </div>
              <div class="sd-modal__field">
                <label class="sd-modal__label">Teléfono</label>
                <input v-model="editForm.telefono" class="sd-modal__input" type="tel" />
              </div>
              <div class="sd-modal__field">
                <label class="sd-modal__label">N° REPROCANN</label>
                <input v-model="editForm.reprocann_numero" class="sd-modal__input" type="text" />
              </div>
              <div class="sd-modal__field">
                <label class="sd-modal__label">Vencimiento REPROCANN</label>
                <input v-model="editForm.reprocann_vencimiento" class="sd-modal__input" type="date" />
              </div>
              <div class="sd-modal__field sd-modal__field--full">
                <label class="sd-modal__label" style="margin-bottom:.4rem">Estado REPROCANN</label>
                <div class="sd-modal__repro-estados">
                  <button
                    v-for="opt in REPROCANN_ESTADOS" :key="opt.value"
                    type="button"
                    class="sd-modal__repro-btn"
                    :style="editForm.reprocann_estado === opt.value ? { background: opt.bg, borderColor: opt.color, color: opt.color } : {}"
                    @click="editForm.reprocann_estado = opt.value"
                  >{{ opt.label }}</button>
                </div>
              </div>
              <div class="sd-modal__field sd-modal__field--full">
                <label class="sd-modal__label" style="margin-bottom:.4rem">
                  Límite de dispensación mensual
                  <span class="sd-modal__opt">opcional — en gramos</span>
                </label>
                <div class="sd-modal__limit-wrap">
                  <input
                    v-model.number="editForm.limite_dispensacion_mensual_g"
                    class="sd-modal__input sd-modal__input--limit"
                    type="number" step="0.5" min="0" max="9999"
                    placeholder="Sin límite"
                  />
                  <span class="sd-modal__limit-unit">g / mes</span>
                  <button
                    v-if="editForm.limite_dispensacion_mensual_g"
                    type="button"
                    class="sd-modal__limit-clear"
                    @click="editForm.limite_dispensacion_mensual_g = ''"
                    title="Quitar límite"
                  ><X :size="13" /></button>
                </div>
                <span class="sd-modal__hint">Dejá vacío para no aplicar ningún límite a este paciente.</span>
              </div>
              <div class="sd-modal__field sd-modal__field--full">
                <label class="sd-modal__label">
                  <input v-model="editForm.es_paciente" type="checkbox" class="sd-modal__check" />
                  En tratamiento activo
                </label>
              </div>
            </div>
            <div v-if="editError" class="sd-modal__error">{{ editError }}</div>
          </div>
          <div class="sd-modal__footer">
            <button class="sd__btn-ghost" @click="editOpen = false">Cancelar</button>
            <button class="sd__btn-primary" :disabled="editSaving" @click="saveEdit">
              <Save :size="13" :stroke-width="2" />
              {{ editSaving ? 'Guardando…' : 'Guardar cambios' }}
            </button>
          </div>
        </div>
      </div>
    </Transition>
  </Teleport>
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

/* Historia clínica */
.sd__historia-body { padding: 1rem 1.25rem 1.25rem; display: flex; flex-direction: column; gap: 1.25rem; }
.sd__textarea--historia { min-height: 280px; }
.sd__historia-foot { display: flex; justify-content: space-between; align-items: center; margin-top: .5rem; }
.sd__save-ok { font-size: .75rem; color: #15803d; display: flex; align-items: center; gap: .3rem; }
.sd__save-pending { font-size: .75rem; color: #94a3b8; }
.sd__hc-section { display: flex; flex-direction: column; gap: .75rem; padding-bottom: 1rem; border-bottom: 1px solid #f0f4f0; }
.sd__hc-section:last-of-type { border-bottom: none; }
.sd__hc-section-title { font-size: .7rem; font-weight: 700; text-transform: uppercase; letter-spacing: .08em; color: #8a9a8a; }

/* Notas */
.sd__nota-form { padding: 1.25rem; border-bottom: 1px solid #f1f5f9; }
.sd__textarea { width: 100%; background: #f8fafc; border: 1.5px solid #e2e8f0; border-radius: 10px; padding: .75rem 1rem; font-size: .875rem; color: #0f172a; outline: none; resize: vertical; min-height: 80px; transition: border-color .15s; box-sizing: border-box; }
.sd__textarea:focus { border-color: #1b5e20; background: #fff; }
.sd__nota-form-foot { display: flex; justify-content: space-between; align-items: center; margin-top: .65rem; }
.sd__char-count { font-size: .72rem; color: #94a3b8; }
.sd__notas { display: flex; flex-direction: column; }
.sd__nota { padding: .875rem 1.25rem; border-bottom: 1px solid #f8fafc; }
.sd__nota:last-child { border-bottom: none; }
.sd__nota-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: .4rem; }
.sd__nota-meta { font-size: .72rem; color: #94a3b8; }
.sd__nota-text { font-size: .85rem; color: #374151; margin: 0; line-height: 1.6; border-left: 2px solid #d4e6d4; padding-left: .75rem; }

/* Timeline */
.sd__timeline { padding: 1.25rem; display: flex; flex-direction: column; gap: 0; }
.sd__tl-item { display: flex; gap: 1rem; padding: .875rem 0; border-bottom: 1px solid #f1f5f9; }
.sd__tl-item:last-child { border-bottom: none; }
.sd__tl-dot { width: 10px; height: 10px; border-radius: 50%; flex-shrink: 0; margin-top: .35rem; }
.sd__tl-tipo { font-size: .7rem; font-weight: 700; text-transform: uppercase; letter-spacing: .04em; margin-bottom: .2rem; }
.sd__tl-desc { font-size: .875rem; color: #374151; margin-bottom: .25rem; }
.sd__tl-fecha { font-size: .72rem; color: #94a3b8; }

/* Empty / loading */
.sd__loading-sm { display: flex; justify-content: center; padding: 2rem; }
.sd__empty { text-align: center; padding: 3rem 1rem; color: #94a3b8; }
.sd__empty-icon { display: flex; justify-content: center; margin-bottom: .5rem; opacity: .4; }
.sd__empty-title { font-size: .875rem; font-weight: 600; color: #64748b; }

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
.sd__btn-icon-danger { background: none; border: none; color: #94a3b8; cursor: pointer; padding: .2rem .4rem; border-radius: 5px; display: flex; align-items: center; }
.sd__btn-icon-danger:hover { background: #fef2f2; color: #dc2626; }

/* Modal */
.sd-modal-overlay { position: fixed; inset: 0; background: rgba(15,23,42,.45); display: flex; align-items: center; justify-content: center; z-index: 800; padding: 1rem; }
.sd-modal { background: #fff; border-radius: 16px; width: 100%; max-width: 600px; max-height: 90vh; display: flex; flex-direction: column; box-shadow: 0 20px 60px rgba(0,0,0,.2); }
.sd-modal__header { display: flex; align-items: center; justify-content: space-between; padding: 1.25rem 1.5rem; border-bottom: 1px solid #f1f5f9; }
.sd-modal__title { font-size: 1rem; font-weight: 700; margin: 0; }
.sd-modal__close { background: none; border: none; color: #94a3b8; cursor: pointer; padding: .25rem; border-radius: 6px; display: flex; }
.sd-modal__close:hover { background: #f1f5f9; color: #0f172a; }
.sd-modal__body { padding: 1.5rem; overflow-y: auto; flex: 1; }
.sd-modal__grid { display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; }
.sd-modal__field { display: flex; flex-direction: column; gap: .4rem; }
.sd-modal__field--full { grid-column: 1 / -1; }
.sd-modal__label { font-size: .75rem; font-weight: 600; color: #64748b; display: flex; align-items: center; gap: .4rem; }
.sd-modal__input { padding: .55rem .75rem; border: 1.5px solid #e2e8f0; border-radius: 8px; font-size: .875rem; color: #0f172a; outline: none; transition: border-color .15s; }
.sd-modal__input:focus { border-color: #1b5e20; }
.sd-modal__check { width: 15px; height: 15px; accent-color: #1b5e20; }
.sd-modal__error { margin-top: .875rem; padding: .75rem 1rem; background: #fef2f2; border: 1px solid #fecaca; border-radius: 8px; font-size: .8rem; color: #dc2626; }
.sd-modal__footer { display: flex; justify-content: flex-end; gap: .75rem; padding: 1.25rem 1.5rem; border-top: 1px solid #f1f5f9; }

/* Transitions */
.sd-modal-enter-active, .sd-modal-leave-active { transition: opacity .2s; }
.sd-modal-enter-from, .sd-modal-leave-to { opacity: 0; pointer-events: none; }
.sd-modal-enter-active .sd-modal, .sd-modal-leave-active .sd-modal { transition: transform .2s; }
.sd-modal-enter-from .sd-modal, .sd-modal-leave-to .sd-modal { transform: translateY(-12px); }

/* ── Cuenta Corriente ── */
.sd__cc-loading { display: flex; align-items: center; justify-content: center; padding: 2rem; }

.sd__cc-header { display: flex; align-items: stretch; gap: 1rem; margin-bottom: 1rem; }
.sd__cc-saldo-block, .sd__cc-margen-block, .sd__cc-limite-block { flex: 1; background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 12px; padding: 1rem 1.25rem; display: flex; flex-direction: column; gap: .2rem; }
.sd__cc-saldo-block { background: #f0fdf4; border-color: #bbf7d0; }
.sd__cc-saldo-block--deuda { background: #fef2f2; border-color: #fecaca; }
.sd__cc-margen-block { background: #eff6ff; border-color: #bfdbfe; }
.sd__cc-margen-block--agotado { background: #fef2f2; border-color: #fecaca; }
.sd__cc-saldo-label, .sd__cc-limite-label { font-size: .72rem; font-weight: 600; color: #64748b; text-transform: uppercase; letter-spacing: .04em; }
.sd__cc-saldo-hint { font-size: .7rem; color: #94a3b8; margin-top: .1rem; }
.sd__cc-saldo-valor { font-family: monospace; font-size: 1.6rem; font-weight: 800; color: #0f172a; }
.sd__cc-saldo--ok   { color: #15803d; }
.sd__cc-saldo--zero { color: #94a3b8; }
.sd__cc-saldo--deuda { color: #dc2626; }
.sd__cc-margen-valor { font-family: monospace; font-size: 1.6rem; font-weight: 800; }
.sd__cc-margen--ok      { color: #2563eb; }
.sd__cc-margen--bajo    { color: #d97706; }
.sd__cc-margen--agotado { color: #dc2626; }
.sd__cc-margen--zero    { color: #94a3b8; }
.sd__cc-limite-valor { font-family: monospace; font-size: 1.3rem; font-weight: 700; color: #475569; }
.sd__cc-limite-valor-row { display: flex; align-items: center; gap: .35rem; }
.sd__cc-limite-edit-btn { background: none; border: none; cursor: pointer; color: #94a3b8; padding: .1rem .2rem; border-radius: 4px; display: inline-flex; align-items: center; transition: color .15s; flex-shrink: 0; }
.sd__cc-limite-edit-btn:hover { color: #475569; }
.sd__cc-limite-form { display: flex; align-items: center; gap: .4rem; margin-top: .25rem; flex-wrap: wrap; }
.sd__cc-limite-input { font-family: monospace; font-size: 1rem; font-weight: 600; border: 1.5px solid #6366f1; border-radius: 8px; padding: .35rem .6rem; width: 8rem; color: #1e293b; background: #fff; outline: none; }
.sd__cc-limite-input:focus { border-color: #4f46e5; box-shadow: 0 0 0 3px rgba(99,102,241,.15); }
.sd__cc-btn--sm { padding: .3rem .7rem; font-size: .78rem; }

/* Crédito en gramos */
.sd__cc-gramos-section { border: 1.5px solid #e2e8f0; border-radius: 12px; padding: .9rem 1rem; margin-bottom: 1rem; }
.sd__cc-gramos-header { display: flex; align-items: center; justify-content: space-between; margin-bottom: .5rem; }
.sd__cc-gramos-title { font-size: .78rem; font-weight: 700; color: #374151; display: flex; align-items: center; gap: .4rem; }
.sd__cc-gramos-hint { font-size: .75rem; color: #94a3b8; margin: .25rem 0 0; }
.sd__cc-gramos-stats { display: flex; gap: 1.5rem; margin-bottom: .75rem; }
.sd__cc-gramos-stat { display: flex; flex-direction: column; gap: .15rem; }
.sd__cc-gramos-stat-label { font-size: .68rem; color: #94a3b8; text-transform: uppercase; letter-spacing: .05em; }
.sd__cc-gramos-stat-val { font-size: 1.1rem; font-weight: 800; font-family: monospace; color: #0f172a; }
.sd__cc-gramos--ok { color: #15803d; }
.sd__cc-gramos--agotado { color: #dc2626; }
.sd__cc-gramos-actions { display: flex; align-items: center; gap: .5rem; flex-wrap: wrap; }
.sd__cc-gramos-form { display: flex; align-items: center; gap: .4rem; }
.sd__cc-gramos-unit { font-size: .8rem; font-weight: 700; color: #64748b; }
/* Toggle switch */
.sd__cc-toggle { position: relative; width: 36px; height: 20px; border-radius: 999px; border: none; cursor: pointer; transition: background .2s; padding: 0; flex-shrink: 0; }
.sd__cc-toggle--off { background: #cbd5e1; }
.sd__cc-toggle--on  { background: #15803d; }
.sd__cc-toggle:disabled { opacity: .6; cursor: not-allowed; }
.sd__cc-toggle-knob { position: absolute; top: 2px; width: 16px; height: 16px; background: #fff; border-radius: 50%; transition: left .2s; box-shadow: 0 1px 3px rgba(0,0,0,.2); }
.sd__cc-toggle--off .sd__cc-toggle-knob { left: 2px; }
.sd__cc-toggle--on  .sd__cc-toggle-knob { left: 18px; }

.sd__cc-bar-wrap { display: flex; align-items: center; gap: .75rem; margin-bottom: 1rem; }
.sd__cc-bar { flex: 1; height: 8px; background: #e2e8f0; border-radius: 999px; overflow: hidden; }
.sd__cc-bar-fill { height: 100%; background: #15803d; border-radius: 999px; transition: width .4s; }
.sd__cc-bar-fill--warn { background: #d97706; }
.sd__cc-bar-fill--danger { background: #dc2626; }
.sd__cc-bar-pct { font-size: .72rem; color: #94a3b8; white-space: nowrap; font-family: monospace; }

.sd__cc-actions { display: flex; gap: .5rem; margin-bottom: 1rem; flex-wrap: wrap; }
.sd__cc-btn { display: inline-flex; align-items: center; gap: .4rem; padding: .5rem 1rem; border-radius: 8px; font-size: .8rem; font-weight: 600; cursor: pointer; border: none; transition: all .15s; }
.sd__cc-btn--primary { background: #15803d; color: #fff; }
.sd__cc-btn--primary:hover { background: #166534; }
.sd__cc-btn--primary:disabled { opacity: .5; cursor: not-allowed; }
.sd__cc-btn--ghost { background: #f1f5f9; color: #475569; border: 1px solid #e2e8f0; }
.sd__cc-btn--ghost:hover { background: #e2e8f0; }
.sd__cc-btn--danger { background: #fef2f2; color: #dc2626; border: 1px solid #fecaca; }
.sd__cc-btn--danger:hover:not(:disabled) { background: #fee2e2; }
.sd__cc-btn--danger:disabled { opacity: .5; cursor: not-allowed; }

.sd__cc-signo-wrap { display: flex; gap: .4rem; }
.sd__cc-signo-btn { flex: 1; padding: .55rem; border-radius: 8px; border: 1.5px solid #e2e8f0; background: #f8fafc; font-size: .82rem; font-weight: 600; cursor: pointer; transition: all .15s; color: #64748b; }
.sd__cc-signo-btn--active-pos { background: #f0fdf4; border-color: #15803d; color: #15803d; }
.sd__cc-signo-btn--active-neg { background: #fef2f2; border-color: #dc2626; color: #dc2626; }

.sd__cc-form { background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 12px; padding: 1.25rem; margin-bottom: 1rem; display: flex; flex-direction: column; gap: .75rem; }
.sd__cc-form--ajuste { border-color: #fcd34d; background: #fffbeb; }
.sd__cc-form-title { font-size: .9rem; font-weight: 700; color: #0f172a; margin: 0; }
.sd__cc-form-hint { font-size: .75rem; color: #64748b; margin: -.25rem 0 .1rem; line-height: 1.5; }
.sd__cc-form-sub { font-size: .78rem; color: #64748b; margin: -.25rem 0 .25rem; }

.sd-modal__repro-estados { display: flex; gap: .4rem; flex-wrap: wrap; }
.sd-modal__repro-btn { padding: .4rem .8rem; border-radius: 7px; border: 1.5px solid #e2e8f0; background: #f8fafc; color: #64748b; font-size: .75rem; font-weight: 600; cursor: pointer; transition: all .15s; }
.sd-modal__repro-btn:hover { border-color: #94a3b8; }
.sd-modal__opt  { font-size: .68rem; font-weight: 400; color: #94a3b8; text-transform: none; letter-spacing: 0; margin-left: .35rem; }
.sd-modal__hint { font-size: .72rem; color: #94a3b8; margin-top: .2rem; display: block; }
.sd-modal__limit-wrap { display: flex; align-items: center; gap: .4rem; }
.sd-modal__input--limit { max-width: 140px; }
.sd-modal__limit-unit { font-size: .8rem; font-weight: 600; color: #64748b; white-space: nowrap; }
.sd-modal__limit-clear { background: none; border: none; color: #94a3b8; cursor: pointer; padding: 2px; display: flex; align-items: center; border-radius: 4px; transition: color .15s; }
.sd-modal__limit-clear:hover { color: #dc2626; }
.sd__cc-form-row { display: flex; flex-direction: column; gap: .3rem; }
.sd__cc-form-row label { font-size: .75rem; font-weight: 600; color: #64748b; }
.sd__cc-input { padding: .5rem .75rem; border: 1.5px solid #e2e8f0; border-radius: 8px; font-size: .875rem; outline: none; transition: border-color .15s; }
.sd__cc-input:focus { border-color: #15803d; }
.sd__cc-form-footer { display: flex; justify-content: flex-end; gap: .5rem; margin-top: .25rem; }

/* Documento REPROCANN */
.sd__repro-doc-body { padding: 1rem 1.25rem; }
.sd__repro-doc-row { display: flex; align-items: center; gap: .75rem; }
.sd__repro-doc-link { display: inline-flex; align-items: center; gap: .4rem; font-size: .875rem; font-weight: 600; color: #0369a1; text-decoration: none; padding: .45rem .9rem; border: 1.5px solid #bae6fd; border-radius: 8px; background: #f0f9ff; transition: all .15s; }
.sd__repro-doc-link:hover { background: #e0f2fe; border-color: #0369a1; }
.sd__repro-upload-row { display: flex; align-items: center; gap: .75rem; flex-wrap: wrap; }
.sd__repro-hint { font-size: .72rem; color: #94a3b8; }

.sd__cc-historial { margin-top: 1.25rem; }
.sd__cc-historial-title { font-size: .75rem; font-weight: 700; color: #94a3b8; text-transform: uppercase; letter-spacing: .06em; margin-bottom: .75rem; }
.sd__cc-empty { text-align: center; color: #94a3b8; font-size: .875rem; padding: 1.5rem; }
.sd__cc-movs { display: flex; flex-direction: column; gap: 0; border: 1px solid #e2e8f0; border-radius: 12px; overflow: hidden; }
.sd__cc-mov { display: grid; grid-template-columns: auto 1fr auto; grid-template-rows: auto auto; gap: .1rem .75rem; padding: .8rem 1rem; border-bottom: 1px solid #f1f5f9; font-size: .82rem; }
.sd__cc-mov:last-child { border-bottom: none; }
.sd__cc-mov-tipo { grid-column: 1; grid-row: 1; font-size: .7rem; font-weight: 700; padding: .15rem .5rem; border-radius: 999px; white-space: nowrap; align-self: center; }
.sd__cc-mov-tipo--carga  { background: #f0fdf4; color: #15803d; }
.sd__cc-mov-tipo--debito { background: #fef2f2; color: #dc2626; }
.sd__cc-mov-tipo--ajuste { background: #fffbeb; color: #b45309; }
.sd__cc-mov-tipo--pago   { background: #eff6ff; color: #2563eb; }
.sd__cc-mov-desc { grid-column: 2; grid-row: 1; color: #475569; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.sd__cc-mov-monto { grid-column: 3; grid-row: 1; font-family: monospace; font-weight: 700; text-align: right; white-space: nowrap; }
.sd__cc-mov--pos { color: #15803d; }
.sd__cc-mov--neg { color: #dc2626; }
.sd__cc-mov-saldo { grid-column: 2; grid-row: 2; font-family: monospace; font-size: .72rem; color: #94a3b8; }
.sd__cc-mov-meta  { grid-column: 3; grid-row: 2; font-size: .7rem; color: #94a3b8; text-align: right; }

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

/* ── Correo tab ─────────────────────────────────────────── */
.sd__mail-noemail {
  display: flex; align-items: flex-start; gap: .75rem;
  background: #fffbeb; border: 1px solid #fde68a; border-radius: 10px;
  padding: .875rem 1rem; margin-bottom: 1rem; font-size: .875rem; color: #92400e; flex-wrap: wrap;
}
.sd__mail-noemail-ico { color: #d97706; flex-shrink: 0; margin-top: .1rem; }
.sd__mail-edit-link {
  background: none; border: none; color: #1b5e20; font-weight: 700; font-size: .875rem;
  cursor: pointer; margin-left: auto; white-space: nowrap; padding: 0;
}
.sd__mail-edit-link:hover { text-decoration: underline; }

.sd__mail-compose { display: flex; flex-direction: column; gap: .875rem; }
.sd__mail-compose--disabled { opacity: .6; pointer-events: none; }

.sd__mail-to {
  display: flex; align-items: center; gap: .4rem; flex-wrap: wrap;
  padding: .6rem .875rem; background: #f8fafc; border-radius: 8px;
  font-size: .84rem; border: 1px solid #e8f0eb;
}
.sd__mail-to-ico { color: #1b5e20; flex-shrink: 0; }
.sd__mail-to-label { font-weight: 700; color: #6b7280; }
.sd__mail-to-name { font-weight: 600; color: #0f172a; }
.sd__mail-to-email { color: #64748b; }
.sd__mail-to-missing { color: #dc2626; font-style: italic; }

.sd__mail-templates {
  display: flex; gap: .4rem; flex-wrap: wrap;
}
.sd__mail-tpl-chip {
  display: inline-flex; align-items: center; gap: .3rem;
  background: #f1f5f9; border: 1.5px solid #e2e8f0; border-radius: 20px;
  padding: .35rem .8rem; font-size: .8rem; font-weight: 600; color: #475569;
  cursor: pointer; transition: all .15s;
}
.sd__mail-tpl-chip:hover { border-color: #1b5e20; color: #1b5e20; background: #f0fdf4; }
.sd__mail-tpl-chip--active { background: #e8f5e9; border-color: #1b5e20; color: #1b5e20; }

.sd__mail-field { display: flex; flex-direction: column; gap: .3rem; }
.sd__mail-field-label { font-size: .72rem; font-weight: 700; color: #374151; text-transform: uppercase; letter-spacing: .05em; }
.sd__mail-input {
  background: #f8fafc; border: 1.5px solid #e2e8f0; border-radius: 8px;
  padding: .65rem .875rem; font-size: .875rem; color: #0f172a;
  width: 100%; box-sizing: border-box; transition: border .15s;
}
.sd__mail-input:focus { outline: none; border-color: #1b5e20; box-shadow: 0 0 0 3px rgba(27,94,32,.1); background: #fff; }
.sd__mail-textarea {
  background: #f8fafc; border: 1.5px solid #e2e8f0; border-radius: 8px;
  padding: .7rem .875rem; font-size: .875rem; color: #0f172a; line-height: 1.6;
  width: 100%; box-sizing: border-box; resize: vertical; min-height: 140px;
  transition: border .15s; font-family: inherit;
}
.sd__mail-textarea:focus { outline: none; border-color: #1b5e20; box-shadow: 0 0 0 3px rgba(27,94,32,.1); background: #fff; }
.sd__mail-charcount { font-size: .7rem; color: #94a3b8; text-align: right; margin-top: .2rem; }

.sd__mail-preview {
  background: #f8fafc; border: 1.5px solid #e2e8f0; border-radius: 8px;
  padding: 1.25rem 1rem; min-height: 180px;
}
.sd__mail-preview-subject { font-weight: 700; color: #0f172a; font-size: .95rem; margin-bottom: .75rem; border-bottom: 1px solid #e2e8f0; padding-bottom: .6rem; }
.sd__mail-preview-body { font-size: .875rem; color: #334155; line-height: 1.7; white-space: pre-wrap; }

.sd__mail-actions {
  display: flex; align-items: center; justify-content: flex-end; gap: .5rem; flex-wrap: wrap;
}
.sd__mail-preview-btn {
  background: transparent; border: 1.5px solid #e2e8f0; color: #475569;
  padding: .6rem 1rem; border-radius: 8px; font-size: .84rem; font-weight: 600;
  cursor: pointer; transition: all .15s;
}
.sd__mail-preview-btn:hover:not(:disabled) { border-color: #1b5e20; color: #1b5e20; }
.sd__mail-preview-btn:disabled { opacity: .4; cursor: not-allowed; }
.sd__mail-send-btn {
  display: inline-flex; align-items: center; gap: .4rem;
  background: #1b5e20; color: #fff; border: none;
  padding: .65rem 1.25rem; border-radius: 8px; font-size: .875rem; font-weight: 700;
  cursor: pointer; transition: background .15s;
}
.sd__mail-send-btn:hover:not(:disabled) { background: #144a18; }
.sd__mail-send-btn:disabled { opacity: .55; cursor: not-allowed; }

/* Historial */
.sd__mail-history-wrap { margin-top: 1.5rem; }
.sd__mail-history-title { font-size: .72rem; font-weight: 700; text-transform: uppercase; letter-spacing: .06em; color: #94a3b8; margin-bottom: .75rem; }
.sd__mail-history { display: flex; flex-direction: column; gap: 0; background: #fff; border: 1px solid #e5e7eb; border-radius: 10px; overflow: hidden; }
.sd__mail-item {
  display: flex; align-items: flex-start; gap: .75rem;
  padding: .875rem 1rem; border-bottom: 1px solid #f1f5f9;
}
.sd__mail-item:last-child { border-bottom: none; }
.sd__mail-item-ico {
  width: 32px; height: 32px; flex-shrink: 0; border-radius: 8px;
  background: #e8f5e9; color: #1b5e20;
  display: flex; align-items: center; justify-content: center;
}
.sd__mail-item-body { flex: 1; min-width: 0; }
.sd__mail-item-subject { font-size: .875rem; font-weight: 600; color: #0f172a; margin-bottom: .15rem; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.sd__mail-item-meta { font-size: .75rem; color: #94a3b8; }
.sd__mail-item-tipo { flex-shrink: 0; }
.sd__mail-tipo-badge { font-size: .7rem; font-weight: 600; background: #f1f5f9; color: #475569; padding: .15rem .5rem; border-radius: 5px; }

.sd__empty--sm { padding: 1.5rem; }
</style>
