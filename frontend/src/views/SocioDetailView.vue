<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { useRoute } from 'vue-router'
import { usePacientesStore } from '../stores/pacientes'
import { useAuthStore } from '../stores/auth'
import Breadcrumb from '../components/ui/Breadcrumb.vue'
import { useConfirm } from '../composables/useConfirm.js'
import { useToast } from '../composables/useToast.js'
import IndicacionesMedicas from '../components/pacientes/IndicacionesMedicas.vue'
import Dispensaciones from '../components/pacientes/Dispensaciones.vue'
import PatientDocuments from '../components/pacientes/PacienteDocumentos.vue'
import { getPacienteTimeline, updatePaciente } from '../lib/api.js'
import {
  User, ShieldCheck, Pill, BookOpen, FileText, ClipboardList, Clock,
  Pencil, Plus, Trash2, AlertTriangle, CheckCircle, Info, X, Save
} from 'lucide-vue-next'

const route  = useRoute()
const store  = usePacientesStore()
const auth   = useAuthStore()
const { confirm } = useConfirm()
const { success: toastOk, error: toastErr } = useToast()

const socioId   = Number(route.params.id)
const loading   = ref(true)
const error     = ref(null)
const activeTab = ref('info')

const canEdit      = computed(() => ['admin', 'medico'].includes(auth.user?.role))
const canClinica   = computed(() => ['admin', 'medico'].includes(auth.user?.role))
const s            = computed(() => store.current)

// ── Inline edit modal ────────────────────────────────────────────────────────
const editOpen  = ref(false)
const editForm  = ref({})
const editSaving = ref(false)
const editError  = ref(null)

function openEdit() {
  editForm.value = {
    nombre:               s.value?.nombre || '',
    apellido:             s.value?.apellido || '',
    dni:                  s.value?.dni || '',
    fecha_nacimiento:     s.value?.fecha_nacimiento || '',
    email:                s.value?.email || '',
    telefono:             s.value?.telefono || '',
    reprocann_numero:     s.value?.reprocann_numero || '',
    reprocann_vencimiento: s.value?.reprocann_vencimiento || '',
    es_paciente:          s.value?.es_paciente ?? true,
  }
  editError.value = null
  editOpen.value  = true
}

async function saveEdit() {
  editSaving.value = true
  editError.value  = null
  try {
    await updatePaciente(socioId, editForm.value)
    await store.fetchOne(socioId)
    editOpen.value = false
    toastOk('Paciente actualizado')
  } catch (e) {
    const msgs = e?.response?.data?.errors
    editError.value = Array.isArray(msgs) ? msgs.join(', ') : 'Error al guardar'
  } finally {
    editSaving.value = false
  }
}

// ── Historia clínica (notas_clinicas) ────────────────────────────────────────
const notasClinicas      = ref('')
const notasClinicasSaved = ref(true)
const notasClinicasSaving = ref(false)

watch(() => s.value?.notas_clinicas, (val) => {
  notasClinicas.value = val || ''
}, { immediate: true })

watch(notasClinicas, () => { notasClinicasSaved.value = false })

async function saveNotasClinicas() {
  notasClinicasSaving.value = true
  try {
    await updatePaciente(socioId, { notas_clinicas: notasClinicas.value })
    notasClinicasSaved.value = true
    toastOk('Historia clínica guardada')
  } catch {
    toastErr('Error al guardar historia clínica')
  } finally {
    notasClinicasSaving.value = false
  }
}

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

watch(activeTab, (tab) => { if (tab === 'timeline') loadTimeline() })

// ── Helpers ───────────────────────────────────────────────────────────────────
function formatDate(d) {
  if (!d) return '—'
  return new Date(d).toLocaleDateString('es-AR', { day: 'numeric', month: 'long', year: 'numeric' })
}
function formatDateTime(d) {
  if (!d) return '—'
  return new Date(d).toLocaleString('es-AR', { day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' })
}
function edad(fn) {
  if (!fn) return null
  return Math.floor((Date.now() - new Date(fn).getTime()) / (1000 * 60 * 60 * 24 * 365.25))
}

const reprocannStatus = computed(() => {
  if (!s.value?.reprocann_vencimiento) return null
  const days = Math.floor((new Date(s.value.reprocann_vencimiento) - new Date()) / 86400000)
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
  { key: 'info',           label: 'Datos',           icon: User },
  { key: 'reprocann',      label: 'REPROCANN',        icon: ShieldCheck },
  { key: 'dispensaciones', label: 'Dispensaciones',   icon: Pill },
  { key: 'historia',       label: 'Historia clínica', icon: ClipboardList, roles: ['admin', 'medico'] },
  { key: 'notas',          label: 'Notas',            icon: BookOpen,      roles: ['admin', 'medico'] },
  { key: 'documentos',     label: 'Documentos',       icon: FileText,      roles: ['admin', 'medico', 'auditor', 'abogado'] },
  { key: 'timeline',       label: 'Timeline',         icon: Clock,         roles: ['admin', 'medico', 'cultivador'] },
]

const TABS = computed(() => {
  const role = auth.user?.role
  return ALL_TABS.filter(t => !t.roles || t.roles.includes(role))
})

onMounted(async () => {
  try {
    await store.fetchOne(socioId)
    await store.fetchNotas(socioId)
  } catch (e) {
    error.value = store.error || 'No se pudo cargar el paciente'
  } finally {
    loading.value = false
  }
})
</script>

<template>
  <div class="sd">

    <!-- Loading -->
    <div v-if="loading" class="sd__loading">
      <div class="sd__ring"></div><span>Cargando paciente…</span>
    </div>
    <div v-else-if="error" class="sd__error">{{ error }}</div>
    <div v-else-if="!s" class="sd__error">Paciente no encontrado.</div>

    <template v-else>

      <!-- Breadcrumb -->
      <Breadcrumb :items="[{ label: 'Pacientes', to: '/pacientes' }, { label: `${s.nombre} ${s.apellido}` }]" />

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
        <div v-if="canEdit" class="sd__hero-actions">
          <button class="sd__btn-edit" @click="openEdit">
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
            <div class="sd__info-item sd__info-item--full">
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
          <Dispensaciones :socio-id="socioId" />
        </div>
      </div>

      <!-- ── Tab: Historia clínica ── -->
      <div v-show="activeTab === 'historia'" class="sd__tab-content">
        <div class="sd__card">
          <div class="sd__card-header">
            <div class="sd__card-icon sd__card-icon--amber"><ClipboardList :size="15" /></div>
            <div>
              <div class="sd__card-title">Historia clínica</div>
              <div class="sd__card-subtitle">Solo visible para admin y médico</div>
            </div>
          </div>
          <div class="sd__historia-body" v-if="canClinica">
            <textarea
              v-model="notasClinicas"
              class="sd__textarea sd__textarea--historia"
              rows="14"
              placeholder="Escribí aquí las notas clínicas del paciente: diagnóstico, tratamientos previos, observaciones, contraindicaciones…"
            ></textarea>
            <div class="sd__historia-foot">
              <span v-if="notasClinicasSaved" class="sd__save-ok">
                <CheckCircle :size="13" /> Guardado
              </span>
              <span v-else class="sd__save-pending">Sin guardar</span>
              <button class="sd__btn-primary" :disabled="notasClinicasSaving || notasClinicasSaved" @click="saveNotasClinicas">
                <Save :size="13" :stroke-width="2" />
                {{ notasClinicasSaving ? 'Guardando…' : 'Guardar' }}
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
          <div v-if="store.notasLoading" class="sd__loading-sm"><div class="sd__ring sd__ring--sm"></div></div>
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
          <div v-if="timelineLoading" class="sd__loading-sm"><div class="sd__ring sd__ring--sm"></div></div>
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
.sd__loading { display: flex; align-items: center; justify-content: center; gap: .75rem; padding: 5rem; color: #94a3b8; }
.sd__ring { width: 22px; height: 22px; border: 2px solid #e2e8f0; border-top-color: #1b5e20; border-radius: 50%; animation: spin .7s linear infinite; }
.sd__ring--sm { width: 16px; height: 16px; }
@keyframes spin { to { transform: rotate(360deg); } }
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
.sd__historia-body { padding: 1.25rem; }
.sd__textarea--historia { min-height: 280px; }
.sd__historia-foot { display: flex; justify-content: space-between; align-items: center; margin-top: .75rem; }
.sd__save-ok { font-size: .75rem; color: #15803d; display: flex; align-items: center; gap: .3rem; }
.sd__save-pending { font-size: .75rem; color: #94a3b8; }

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
.sd-modal-enter-from, .sd-modal-leave-to { opacity: 0; }
.sd-modal-enter-active .sd-modal, .sd-modal-leave-active .sd-modal { transition: transform .2s; }
.sd-modal-enter-from .sd-modal, .sd-modal-leave-to .sd-modal { transform: translateY(-12px); }
</style>
