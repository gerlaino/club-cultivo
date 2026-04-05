<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useSociosStore } from '../stores/socios'
import { useAuthStore } from '../stores/auth'
import IndicacionesMedicas from '../components/socios/IndicacionesMedicas.vue'
import Dispensaciones from '../components/socios/Dispensaciones.vue'
import PatientDocuments from '../components/socios/PacienteDocumentos.vue'

const route   = useRoute()
const router  = useRouter()
const store   = useSociosStore()
const auth    = useAuthStore()

const socioId   = Number(route.params.id)
const loading   = ref(true)
const error     = ref(null)
const activeTab = ref('info')

const canEdit = computed(() => ['admin', 'medico'].includes(auth.role))
const s       = computed(() => store.current)

function openEdit() {
  router.push({ name: 'socios', query: { editar: socioId } })
}

// ── Notas ─────────────────────────────────────────────────────────────
const notaTexto = ref('')
async function agregarNota() {
  const txt = notaTexto.value.trim()
  if (!txt) return
  try { await store.addNota(socioId, txt); notaTexto.value = '' } catch {}
}
async function borrarNota(n) {
  if (!confirm('¿Eliminar esta nota?')) return
  try { await store.removeNota(n.id) } catch {}
}

// ── Helpers ───────────────────────────────────────────────────────────
function formatDate(d) {
  if (!d) return '—'
  return new Date(d).toLocaleDateString('es-AR', { day: 'numeric', month: 'long', year: 'numeric' })
}
function edad(fn) {
  if (!fn) return null
  return Math.floor((Date.now() - new Date(fn).getTime()) / (1000 * 60 * 60 * 24 * 365.25))
}

const reprocannStatus = computed(() => {
  if (!s.value?.reprocann_vencimiento) return null
  const days = Math.floor((new Date(s.value.reprocann_vencimiento) - new Date()) / 86400000)
  if (days < 0)   return { label: 'Vencido',                        color: '#dc2626', bg: 'rgba(220,38,38,.1)',   icon: '❌', key: 'danger'  }
  if (days <= 30) return { label: `Vence en ${days} días`,           color: '#d97706', bg: 'rgba(217,119,6,.1)',  icon: '⚠️', key: 'warning' }
  return               { label: `Vigente — ${days} días restantes`, color: '#15803d', bg: 'rgba(21,128,61,.1)',  icon: '✅', key: 'success' }
})

const AVATAR_COLORS = ['#1b5e20','#0369a1','#7c3aed','#b45309','#0891b2','#dc2626','#15803d']
function avatarColor(id) { return AVATAR_COLORS[(id || 0) % AVATAR_COLORS.length] }

const TABS = [
  { key: 'info',          label: 'Información',   icon: 'bi-person' },
  { key: 'indicaciones',  label: 'Indicaciones',  icon: 'bi-file-medical' },
  { key: 'dispensaciones',label: 'Dispensaciones',icon: 'bi-capsule' },
  { key: 'notas',         label: 'Notas',         icon: 'bi-journal-text' },
  { key: 'documentos',    label: 'Documentos',    icon: 'bi-file-earmark-text' },
]

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
      <nav class="sd__breadcrumb">
        <RouterLink to="/socios" class="sd__breadcrumb-link">Pacientes</RouterLink>
        <span class="sd__breadcrumb-sep">›</span>
        <span class="sd__breadcrumb-current">{{ s.nombre }} {{ s.apellido }}</span>
      </nav>

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
                {{ reprocannStatus.icon }} {{ reprocannStatus.label }}
              </span>
              <span v-else class="sd__repro-badge sd__repro-badge--none">
                Sin REPROCANN
              </span>
              <span v-if="s.es_paciente" class="sd__status-badge sd__status-badge--active">
                En tratamiento
              </span>
              <span v-else class="sd__status-badge">Inactivo</span>
            </div>
          </div>
        </div>
        <div v-if="canEdit" class="sd__hero-actions">
          <button class="sd__btn-edit" @click="openEdit">
            <i class="bi bi-pencil"></i> Editar
          </button>
        </div>
      </div>

      <!-- Alerta REPROCANN -->
      <div v-if="reprocannStatus?.key === 'danger'" class="sd__alerta sd__alerta--danger">
        <i class="bi bi-exclamation-triangle-fill"></i>
        <div>
          <strong>REPROCANN vencido</strong> — El certificado venció el {{ formatDate(s.reprocann_vencimiento) }}.
          Es necesario renovarlo para continuar el tratamiento legalmente.
        </div>
      </div>
      <div v-else-if="reprocannStatus?.key === 'warning'" class="sd__alerta sd__alerta--warning">
        <i class="bi bi-exclamation-triangle-fill"></i>
        <div>
          <strong>REPROCANN por vencer</strong> — El certificado vence el {{ formatDate(s.reprocann_vencimiento) }}.
          Iniciá el trámite de renovación a la brevedad.
        </div>
      </div>

      <!-- Tabs -->
      <div class="sd__tabs">
        <button
          v-for="tab in TABS" :key="tab.key"
          class="sd__tab"
          :class="{ 'sd__tab--active': activeTab === tab.key }"
          @click="activeTab = tab.key"
        >
          <i :class="['bi', tab.icon]"></i>
          {{ tab.label }}
          <span v-if="tab.key === 'notas' && store.notas.length" class="sd__tab-badge">
            {{ store.notas.length }}
          </span>
        </button>
      </div>

      <!-- ── Tab: Información ── -->
      <div v-show="activeTab === 'info'" class="sd__tab-content">
        <div class="sd__cards">

          <!-- Datos personales -->
          <div class="sd__card">
            <div class="sd__card-header">
              <div class="sd__card-icon sd__card-icon--blue"><i class="bi bi-person"></i></div>
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

          <!-- Datos REPROCANN -->
          <div class="sd__card" :class="reprocannStatus?.key === 'danger' ? 'sd__card--danger' : reprocannStatus?.key === 'warning' ? 'sd__card--warning' : ''">
            <div class="sd__card-header">
              <div class="sd__card-icon sd__card-icon--green"><i class="bi bi-patch-check"></i></div>
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
                      {{ reprocannStatus.icon }} {{ reprocannStatus.label }}
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
              <i class="bi bi-info-circle"></i>
              Vigencia del certificado: 3 años (Res. 1780/2025). Las ONG deben renovar anualmente.
            </div>
          </div>

        </div>

        <!-- Info sistema -->
        <div class="sd__sys-info">
          <span>ID sistema: <strong>#{{ s.id }}</strong></span>
          <span>Registrado: <strong>{{ formatDate(s.created_at) }}</strong></span>
          <span>Actualizado: <strong>{{ formatDate(s.updated_at) }}</strong></span>
        </div>
      </div>

      <!-- ── Tab: Indicaciones ── -->
      <div v-show="activeTab === 'indicaciones'" class="sd__tab-content">
        <div class="sd__card sd__card--full">
          <IndicacionesMedicas :socio-id="socioId" />
        </div>
      </div>

      <!-- ── Tab: Dispensaciones ── -->
      <div v-show="activeTab === 'dispensaciones'" class="sd__tab-content">
        <div class="sd__card sd__card--full">
          <Dispensaciones :socio-id="socioId" />
        </div>
      </div>

      <!-- ── Tab: Notas ── -->
      <div v-show="activeTab === 'notas'" class="sd__tab-content">
        <div class="sd__card sd__card--full">
          <div class="sd__card-header">
            <div class="sd__card-icon sd__card-icon--amber"><i class="bi bi-journal-text"></i></div>
            <div>
              <div class="sd__card-title">Notas clínicas</div>
              <div class="sd__card-subtitle">Registros internos del equipo — no visibles para el paciente</div>
            </div>
          </div>

          <!-- Nueva nota -->
          <div v-if="canEdit" class="sd__nota-form">
            <textarea
              v-model.trim="notaTexto"
              class="sd__textarea"
              rows="3"
              placeholder="Agregar nota clínica, observación o seguimiento…"
            ></textarea>
            <div class="sd__nota-form-foot">
              <span class="sd__char-count">{{ notaTexto.length }} caracteres</span>
              <button class="sd__btn-primary" :disabled="store.creandoNota || !notaTexto" @click="agregarNota">
                <span v-if="store.creandoNota" class="sd__spinner"></span>
                <i v-else class="bi bi-plus-lg"></i>
                Agregar nota
              </button>
            </div>
            <div v-if="store.notasError" class="sd__form-error">{{ store.notasError }}</div>
          </div>

          <!-- Lista de notas -->
          <div v-if="store.notasLoading" class="sd__loading-sm">
            <div class="sd__ring sd__ring--sm"></div>
          </div>
          <div v-else-if="!store.notas.length" class="sd__empty">
            <div class="sd__empty-icon"><i class="bi bi-journal-text"></i></div>
            <div class="sd__empty-title">Sin notas registradas</div>
          </div>
          <div v-else class="sd__notas">
            <div v-for="n in store.notas" :key="n.id" class="sd__nota">
              <div class="sd__nota-header">
                <div class="sd__nota-meta">
                  <i class="bi bi-clock"></i>
                  {{ formatDate(n.created_at) }}
                  <span v-if="n.created_by?.nombre">
                    <i class="bi bi-person ms-2"></i>{{ n.created_by.nombre }}
                  </span>
                </div>
                <button v-if="canEdit" class="sd__btn-delete" @click="borrarNota(n)">
                  <i class="bi bi-trash"></i>
                </button>
              </div>
              <p class="sd__nota-text">{{ n.contenido }}</p>
            </div>
          </div>
        </div>
      </div>

      <!-- ── Tab: Documentos ── -->
      <div v-show="activeTab === 'documentos'" class="sd__tab-content">
        <div class="sd__card sd__card--full">
          <PatientDocuments :socio-id="socioId" :socio-nombre="`${s.nombre} ${s.apellido}`" />
        </div>
      </div>

    </template>
  </div>
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

/* Breadcrumb */
.sd__breadcrumb { display: flex; align-items: center; gap: .4rem; font-size: .78rem; margin-bottom: 1.5rem; }
.sd__breadcrumb-link { color: #94a3b8; text-decoration: none; font-weight: 600; }
.sd__breadcrumb-link:hover { color: #1b5e20; }
.sd__breadcrumb-sep { color: #cbd5e1; }
.sd__breadcrumb-current { color: #0f172a; font-weight: 600; }

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
.sd__alerta--danger i { color: #dc2626; margin-top: .1rem; }
.sd__alerta--warning { background: #fffbeb; border: 1px solid #fde68a; color: #78350f; }
.sd__alerta--warning i { color: #d97706; margin-top: .1rem; }

/* Tabs */
.sd__tabs { display: flex; gap: .25rem; border-bottom: 2px solid #e2e8f0; margin-bottom: 1.5rem; flex-wrap: wrap; }
.sd__tab { display: flex; align-items: center; gap: .4rem; padding: .65rem 1rem; border-radius: 8px 8px 0 0; border: none; border-bottom: 2px solid transparent; margin-bottom: -2px; background: none; font-size: .82rem; font-weight: 600; color: #64748b; cursor: pointer; transition: all .15s; }
.sd__tab:hover { color: #0f172a; background: #f8fafc; }
.sd__tab--active { color: #1b5e20; border-bottom-color: #1b5e20; }
.sd__tab-badge { background: #e8f5e9; color: #1b5e20; font-size: .65rem; font-weight: 700; padding: .1em .5em; border-radius: 999px; }

/* Tab content */
.sd__tab-content { }

/* Cards */
.sd__cards { display: grid; grid-template-columns: 1fr 1fr; gap: 1.1rem; margin-bottom: 1rem; }
@media (max-width: 768px) { .sd__cards { grid-template-columns: 1fr; } }
.sd__card { background: #fff; border: 1px solid #e2e8f0; border-radius: 14px; overflow: hidden; }
.sd__card--full { width: 100%; }
.sd__card--danger { border-color: #fecaca; border-left: 3px solid #dc2626; }
.sd__card--warning { border-color: #fde68a; border-left: 3px solid #d97706; }
.sd__card-header { display: flex; align-items: flex-start; gap: .65rem; padding: 1rem 1.25rem; border-bottom: 1px solid #f1f5f9; background: #fafbfc; }
.sd__card-icon { width: 32px; height: 32px; border-radius: 9px; display: flex; align-items: center; justify-content: center; font-size: .85rem; flex-shrink: 0; }
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

/* Notas */
.sd__nota-form { padding: 1.25rem; border-bottom: 1px solid #f1f5f9; }
.sd__textarea { width: 100%; background: #f8fafc; border: 1.5px solid #e2e8f0; border-radius: 10px; padding: .75rem 1rem; font-size: .875rem; color: #0f172a; outline: none; resize: vertical; min-height: 80px; transition: border-color .15s; }
.sd__textarea:focus { border-color: #1b5e20; background: #fff; }
.sd__nota-form-foot { display: flex; justify-content: space-between; align-items: center; margin-top: .65rem; }
.sd__char-count { font-size: .72rem; color: #94a3b8; }
.sd__form-error { font-size: .75rem; color: #dc2626; margin-top: .4rem; }
.sd__notas { display: flex; flex-direction: column; gap: 0; }
.sd__nota { padding: .875rem 1.25rem; border-bottom: 1px solid #f8fafc; }
.sd__nota:last-child { border-bottom: none; }
.sd__nota-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: .4rem; }
.sd__nota-meta { font-size: .72rem; color: #94a3b8; display: flex; align-items: center; gap: .3rem; }
.sd__nota-text { font-size: .85rem; color: #374151; margin: 0; line-height: 1.6; border-left: 2px solid #d4e6d4; padding-left: .75rem; }
.sd__btn-delete { background: none; border: none; color: #94a3b8; cursor: pointer; padding: .2rem .4rem; border-radius: 5px; font-size: .8rem; }
.sd__btn-delete:hover { background: #fef2f2; color: #dc2626; }

/* Loading sm / Empty */
.sd__loading-sm { display: flex; justify-content: center; padding: 2rem; }
.sd__empty { text-align: center; padding: 3rem 1rem; color: #94a3b8; }
.sd__empty-icon { font-size: 2rem; margin-bottom: .5rem; opacity: .4; }
.sd__empty-title { font-size: .875rem; font-weight: 600; color: #64748b; }

/* Buttons */
.sd__btn-edit { display: inline-flex; align-items: center; gap: .4rem; background: #fff; color: #475569; border: 1.5px solid #e2e8f0; padding: .55rem 1rem; border-radius: 9px; font-size: .82rem; font-weight: 600; cursor: pointer; transition: all .15s; }
.sd__btn-edit:hover { border-color: #1b5e20; color: #1b5e20; background: #f0fdf4; }
.sd__btn-primary { display: inline-flex; align-items: center; gap: .4rem; background: #1b5e20; color: #fff; border: none; padding: .6rem 1.1rem; border-radius: 9px; font-size: .82rem; font-weight: 600; cursor: pointer; transition: background .15s; }
.sd__btn-primary:hover:not(:disabled) { background: #144a18; }
.sd__btn-primary:disabled { opacity: .5; cursor: not-allowed; }
.sd__spinner { width: 13px; height: 13px; border: 2px solid rgba(255,255,255,.3); border-top-color: #fff; border-radius: 50%; animation: spin .6s linear infinite; }
</style>
