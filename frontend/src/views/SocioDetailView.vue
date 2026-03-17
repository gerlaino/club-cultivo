<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useSociosStore } from '../stores/socios'
import { useAuthStore } from '../stores/auth'
import IndicacionesMedicas from '../components/socios/IndicacionesMedicas.vue'
import Dispensaciones from '../components/socios/Dispensaciones.vue'

const route  = useRoute()
const router = useRouter()
const store  = useSociosStore()
const auth   = useAuthStore()

const socioId = Number(route.params.id)
const loading = ref(true)
const error   = ref(null)
const activeTab = ref('info')

const canEdit = computed(() => ['admin', 'medico'].includes(auth.role))
const s       = computed(() => store.current)

// ── Nota ──────────────────────────────────────────────────────────────
const notaTexto = ref('')

async function agregarNota() {
  const txt = notaTexto.value.trim()
  if (!txt) return
  try {
    await store.addNota(socioId, txt)
    notaTexto.value = ''
  } catch {}
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
  if (days < 0)   return { label: 'Vencido',                    color: 'danger',  days, icon: '❌' }
  if (days <= 30) return { label: `Vence en ${days} días`,       color: 'warning', days, icon: '⚠️' }
  return               { label: `Vigente — ${days} días restantes`, color: 'success', days, icon: '✅' }
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
  <div class="container-fluid py-4 px-3 px-md-4">

    <!-- Loading -->
    <div v-if="loading" class="text-center py-5">
      <div class="spinner-border text-success"></div>
    </div>
    <div v-else-if="error" class="alert alert-danger">{{ error }}</div>
    <div v-else-if="!s" class="alert alert-warning">Paciente no encontrado.</div>

    <template v-else>

      <!-- Breadcrumb -->
      <nav aria-label="breadcrumb" class="mb-3">
        <ol class="breadcrumb small">
          <li class="breadcrumb-item"><RouterLink to="/socios">Pacientes</RouterLink></li>
          <li class="breadcrumb-item active">{{ s.nombre }} {{ s.apellido }}</li>
        </ol>
      </nav>

      <!-- Header -->
      <div class="d-flex flex-wrap align-items-start justify-content-between gap-3 mb-4">
        <div class="d-flex align-items-center gap-3">
          <!-- Avatar inicial -->
          <div class="patient-avatar">
            {{ (s.nombre?.[0] || '') + (s.apellido?.[0] || '') }}
          </div>
          <div>
            <h1 class="h3 fw-bold mb-0">{{ s.nombre }} {{ s.apellido }}</h1>
            <p class="text-muted small mb-1">
              DNI {{ s.dni || '—' }}
              <span v-if="edad(s.fecha_nacimiento)"> · {{ edad(s.fecha_nacimiento) }} años</span>
            </p>
            <!-- Badge Reprocann -->
            <span v-if="reprocannStatus" class="badge rounded-pill" :class="`text-bg-${reprocannStatus.color}`">
              {{ reprocannStatus.icon }} {{ reprocannStatus.label }}
            </span>
            <span v-else class="badge text-bg-secondary rounded-pill">Sin Reprocann</span>
          </div>
        </div>
        <div class="d-flex gap-2" v-if="canEdit">
          <RouterLink :to="`/socios/${s.id}/editar`" class="btn btn-sm btn-outline-primary">
            <i class="bi bi-pencil me-1"></i>Editar
          </RouterLink>
        </div>
      </div>

      <!-- Alerta Reprocann vencido -->
      <div v-if="reprocannStatus?.color === 'danger'" class="alert alert-danger d-flex align-items-center gap-2 mb-4">
        <i class="bi bi-exclamation-triangle-fill"></i>
        <div>
          <strong>Reprocann vencido</strong> — El certificado de este paciente venció el {{ formatDate(s.reprocann_vencimiento) }}.
          Es necesario renovarlo para continuar el tratamiento legalmente.
        </div>
      </div>
      <div v-else-if="reprocannStatus?.color === 'warning'" class="alert alert-warning d-flex align-items-center gap-2 mb-4">
        <i class="bi bi-exclamation-triangle-fill"></i>
        <div>
          <strong>Reprocann por vencer</strong> — El certificado vence el {{ formatDate(s.reprocann_vencimiento) }}.
          Iniciá el trámite de renovación a la brevedad.
        </div>
      </div>

      <!-- Tabs -->
      <ul class="nav nav-tabs mb-4">
        <li class="nav-item">
          <button class="nav-link" :class="{ active: activeTab === 'info' }" @click="activeTab='info'">
            <i class="bi bi-person me-1"></i>Información
          </button>
        </li>
        <li class="nav-item">
          <button class="nav-link" :class="{ active: activeTab === 'indicaciones' }" @click="activeTab='indicaciones'">
            <i class="bi bi-file-medical me-1"></i>Indicaciones
          </button>
        </li>
        <li class="nav-item">
          <button class="nav-link" :class="{ active: activeTab === 'dispensaciones' }" @click="activeTab='dispensaciones'">
            <i class="bi bi-capsule me-1"></i>Dispensaciones
          </button>
        </li>
        <li class="nav-item">
          <button class="nav-link" :class="{ active: activeTab === 'notas' }" @click="activeTab='notas'">
            <i class="bi bi-journal-text me-1"></i>Notas
            <span v-if="store.notas.length" class="badge text-bg-secondary ms-1">{{ store.notas.length }}</span>
          </button>
        </li>
        <li class="nav-item">
          <button class="nav-link" :class="{ active: activeTab === 'documentos' }" @click="activeTab='documentos'">
            <i class="bi bi-file-earmark-text me-1"></i>Documentos
          </button>
        </li>
      </ul>

      <!-- ── Tab: Información ── -->
      <div v-show="activeTab === 'info'">
        <div class="row g-4">

          <!-- Datos personales -->
          <div class="col-12 col-lg-6">
            <div class="card border-0 shadow-sm h-100">
              <div class="card-header bg-transparent border-0 pt-3 pb-0">
                <strong>👤 Datos personales</strong>
              </div>
              <div class="card-body small">
                <dl class="row mb-0 g-1">
                  <dt class="col-5 fw-normal text-muted">Nombre completo</dt>
                  <dd class="col-7 fw-semibold">{{ s.nombre }} {{ s.apellido }}</dd>

                  <dt class="col-5 fw-normal text-muted">DNI</dt>
                  <dd class="col-7 font-monospace">{{ s.dni || '—' }}</dd>

                  <dt class="col-5 fw-normal text-muted">Fecha de nac.</dt>
                  <dd class="col-7">{{ formatDate(s.fecha_nacimiento) }}</dd>

                  <dt class="col-5 fw-normal text-muted">Edad</dt>
                  <dd class="col-7">{{ edad(s.fecha_nacimiento) ? edad(s.fecha_nacimiento) + ' años' : '—' }}</dd>

                  <dt class="col-5 fw-normal text-muted">Email</dt>
                  <dd class="col-7">{{ s.email || '—' }}</dd>

                  <dt class="col-5 fw-normal text-muted">Teléfono</dt>
                  <dd class="col-7 mb-0">{{ s.telefono || '—' }}</dd>
                </dl>
              </div>
            </div>
          </div>

          <!-- Datos Reprocann -->
          <div class="col-12 col-lg-6">
            <div class="card border-0 shadow-sm h-100" :class="reprocannStatus ? `border-${reprocannStatus.color}` : ''">
              <div class="card-header bg-transparent border-0 pt-3 pb-0">
                <strong>🪪 Datos Reprocann</strong>
              </div>
              <div class="card-body small">
                <dl class="row mb-0 g-1">
                  <dt class="col-5 fw-normal text-muted">Número</dt>
                  <dd class="col-7 font-monospace">{{ s.reprocann_numero || '—' }}</dd>

                  <dt class="col-5 fw-normal text-muted">Vencimiento</dt>
                  <dd class="col-7">
                    <span v-if="s.reprocann_vencimiento">
                      {{ formatDate(s.reprocann_vencimiento) }}
                      <span v-if="reprocannStatus" class="ms-1 badge" :class="`text-bg-${reprocannStatus.color}`">
                        {{ reprocannStatus.label }}
                      </span>
                    </span>
                    <span v-else class="text-muted">Sin datos</span>
                  </dd>

                  <dt class="col-5 fw-normal text-muted">Estado</dt>
                  <dd class="col-7 mb-0">
                    <span v-if="s.es_paciente" class="text-success fw-semibold">En tratamiento</span>
                    <span v-else class="text-muted">Inactivo</span>
                  </dd>
                </dl>

                <div class="mt-3 pt-3 border-top small text-muted">
                  <i class="bi bi-info-circle me-1"></i>
                  Vigencia del certificado: 3 años (Res. 1780/2025).
                  Las ONG deben renovar anualmente.
                </div>
              </div>
            </div>
          </div>

          <!-- Info del sistema -->
          <div class="col-12">
            <div class="card border-0 bg-body-secondary">
              <div class="card-body small">
                <dl class="row mb-0">
                  <dt class="col-md-2 fw-normal text-muted">ID sistema</dt>
                  <dd class="col-md-2 font-monospace">#{{ s.id }}</dd>
                  <dt class="col-md-2 fw-normal text-muted">Registrado</dt>
                  <dd class="col-md-2">{{ formatDate(s.created_at) }}</dd>
                  <dt class="col-md-2 fw-normal text-muted">Actualizado</dt>
                  <dd class="col-md-2 mb-0">{{ formatDate(s.updated_at) }}</dd>
                </dl>
              </div>
            </div>
          </div>

        </div>
      </div>

      <!-- ── Tab: Indicaciones ── -->
      <div v-show="activeTab === 'indicaciones'">
        <div class="card border-0 shadow-sm">
          <div class="card-body">
            <IndicacionesMedicas :socio-id="socioId" />
          </div>
        </div>
      </div>

      <!-- ── Tab: Dispensaciones ── -->
      <div v-show="activeTab === 'dispensaciones'">
        <div class="card border-0 shadow-sm">
          <div class="card-body">
            <Dispensaciones :socio-id="socioId" />
          </div>
        </div>
      </div>

      <!-- ── Tab: Notas ── -->
      <div v-show="activeTab === 'notas'">
        <div class="card border-0 shadow-sm">
          <div class="card-header bg-transparent border-0 pt-3 pb-0">
            <strong>📝 Notas clínicas</strong>
            <p class="text-muted small mb-0">Registros internos del equipo — no visibles para el paciente</p>
          </div>
          <div class="card-body">

            <!-- Nueva nota -->
            <div v-if="canEdit" class="mb-4">
              <textarea
                v-model.trim="notaTexto"
                class="form-control mb-2"
                rows="3"
                placeholder="Agregar nota clínica, observación o seguimiento…"
              ></textarea>
              <div class="d-flex justify-content-between align-items-center">
                <span class="text-muted small">{{ notaTexto.length }} caracteres</span>
                <button
                  class="btn btn-success btn-sm px-3"
                  :disabled="store.creandoNota || !notaTexto"
                  @click="agregarNota"
                >
                  <span v-if="store.creandoNota" class="spinner-border spinner-border-sm me-1"></span>
                  <i v-else class="bi bi-plus-circle me-1"></i>
                  Agregar nota
                </button>
              </div>
              <div v-if="store.notasError" class="text-danger small mt-1">{{ store.notasError }}</div>
            </div>

            <!-- Lista de notas -->
            <div v-if="store.notasLoading" class="text-center py-3">
              <div class="spinner-border spinner-border-sm text-success"></div>
            </div>
            <div v-else-if="!store.notas.length" class="text-center py-4 text-muted">
              <div class="fs-2 mb-2">📝</div>
              <div class="small">Sin notas registradas</div>
            </div>
            <div v-else class="nota-list">
              <div v-for="n in store.notas" :key="n.id" class="nota-item">
                <div class="d-flex justify-content-between align-items-start mb-1">
                  <div class="small text-muted">
                    <i class="bi bi-clock me-1"></i>
                    {{ formatDate(n.created_at) }}
                    <span v-if="n.created_by?.nombre" class="ms-2">
                      <i class="bi bi-person me-1"></i>{{ n.created_by.nombre }}
                    </span>
                  </div>
                  <button v-if="canEdit" class="btn btn-sm btn-link text-danger p-0" @click="borrarNota(n)">
                    <i class="bi bi-trash"></i>
                  </button>
                </div>
                <p class="mb-0 small">{{ n.contenido }}</p>
              </div>
            </div>

          </div>
        </div>
      </div>

      <!-- ── Tab: Documentos ── -->
      <div v-show="activeTab === 'documentos'">
        <div class="card border-0 shadow-sm">
          <div class="card-header bg-transparent border-0 pt-3 pb-0 d-flex align-items-center justify-content-between">
            <div>
              <strong>📄 Documentos del paciente</strong>
              <p class="text-muted small mb-0">Consentimientos, indicaciones, declaraciones juradas y adjuntos</p>
            </div>
          </div>
          <div class="card-body">
            <div class="text-center py-5 text-muted">
              <div class="fs-1 mb-3">📄</div>
              <h5>Módulo de documentos</h5>
              <p class="small mb-0">
                Próximamente: generación de Consentimiento Informado Bilateral,
                Indicación Médica con firma digital, Declaración Jurada y más
                según Resolución 1780/2025.
              </p>
            </div>
          </div>
        </div>
      </div>

    </template>
  </div>
</template>

<style scoped>
.patient-avatar {
  width: 60px;
  height: 60px;
  border-radius: 50%;
  background: color-mix(in srgb, var(--brand-primary, #1b5e20) 15%, white);
  color: var(--brand-primary, #1b5e20);
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 1.4rem;
  font-weight: 700;
  flex-shrink: 0;
}

.nota-list {
  display: flex;
  flex-direction: column;
  gap: .75rem;
}
.nota-item {
  background: #f8f9fa;
  border-radius: 8px;
  padding: .75rem 1rem;
  border-left: 3px solid var(--brand-primary, #1b5e20);
}
</style>
