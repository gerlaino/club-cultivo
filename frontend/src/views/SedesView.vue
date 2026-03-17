<script setup>
import { ref, computed, onMounted } from 'vue'
import { listSedes, createSede, updateSede, deleteSede,
  getSedeInventario, agregarStock } from '../lib/api.js'
import { useAuthStore } from '../stores/auth.js'
import { usePlan } from '../composables/usePlan.js'

const auth = useAuthStore()
const { fetchPlan, puedeCrear, planLabel, planColor, esTrial, limites, uso } = usePlan()

const canEdit = computed(() => ['admin'].includes(auth.role))

const sedes      = ref([])
const loading    = ref(true)
const saving     = ref(false)
const formError  = ref(null)

const showModal      = ref(false)
const showDelete     = ref(false)
const showInventario = ref(false)
const showStock      = ref(false)
const showUpgrade    = ref(false)

const editingId      = ref(null)
const deleteTarget   = ref(null)
const sedeActiva     = ref(null)
const inventarioData = ref([])
const loadingInv     = ref(false)

const stockForm = ref({ producto: 'flores', cantidad: null, motivo: '' })

const TIPO_META = {
  produccion: { label: 'Producción',           icon: '🌱', color: '#198754' },
  social:     { label: 'Social / Dispensario', icon: '🏪', color: '#0d6efd' },
  mixta:      { label: 'Mixta',                icon: '🔄', color: '#6f42c1' },
}
function tipoMeta(tipo) { return TIPO_META[tipo] || TIPO_META.produccion }

function emptyForm() {
  return { nombre: '', tipo: 'produccion', direccion: '', ciudad: '',
    provincia: '', pais: 'Argentina', declarada_reprocann: false, notas: '' }
}
const form       = ref(emptyForm())
const formErrors = ref({})

const kpis = computed(() => ({
  total:      sedes.value.length,
  produccion: sedes.value.filter(s => ['produccion','mixta'].includes(s.tipo)).length,
  social:     sedes.value.filter(s => ['social','mixta'].includes(s.tipo)).length,
  reprocann:  sedes.value.filter(s => s.declarada_reprocann).length,
}))

async function load() {
  loading.value = true
  try {
    const [sedesRes] = await Promise.allSettled([listSedes(), fetchPlan()])
    if (sedesRes.status === 'fulfilled') sedes.value = sedesRes.value.data || []
  } finally {
    loading.value = false
  }
}

function openCreate() {
  if (!puedeCrear('sedes')) { showUpgrade.value = true; return }
  editingId.value  = null
  form.value       = emptyForm()
  formErrors.value = {}
  formError.value  = null
  showModal.value  = true
}

function openEdit(s) {
  editingId.value = s.id
  form.value = {
    nombre: s.nombre, tipo: s.tipo,
    direccion: s.direccion || '', ciudad: s.ciudad || '',
    provincia: s.provincia || '', pais: s.pais || 'Argentina',
    declarada_reprocann: s.declarada_reprocann, notas: s.notas || '',
  }
  formErrors.value = {}
  formError.value  = null
  showModal.value  = true
}

function validate() {
  const e = {}
  if (!form.value.nombre.trim()) e.nombre = 'El nombre es obligatorio'
  formErrors.value = e
  return !Object.keys(e).length
}

async function handleSubmit() {
  if (!validate()) return
  saving.value    = true
  formError.value = null
  try {
    if (editingId.value) {
      const { data } = await updateSede(editingId.value, form.value)
      const idx = sedes.value.findIndex(s => s.id === editingId.value)
      if (idx !== -1) sedes.value[idx] = data
    } else {
      const { data } = await createSede(form.value)
      sedes.value.unshift(data)
      await fetchPlan()
    }
    showModal.value = false
  } catch (e) {
    if (e.response?.status === 402) {
      showModal.value   = false
      showUpgrade.value = true
    } else {
      formError.value = e.response?.data?.errors?.join(', ') || 'Error al guardar'
    }
  } finally {
    saving.value = false
  }
}

async function handleDelete() {
  try {
    await deleteSede(deleteTarget.value.id)
    sedes.value      = sedes.value.filter(s => s.id !== deleteTarget.value.id)
    showDelete.value = false
    await fetchPlan()
  } catch (e) {
    showDelete.value = false
  }
}

async function verInventario(sede) {
  sedeActiva.value     = sede
  loadingInv.value     = true
  showInventario.value = true
  try {
    const { data } = await getSedeInventario(sede.id)
    inventarioData.value = data
  } finally {
    loadingInv.value = false
  }
}

function abrirAgregarStock(sede) {
  sedeActiva.value = sede
  stockForm.value  = { producto: 'flores', cantidad: null, motivo: '' }
  showStock.value  = true
}

async function confirmarStock() {
  if (!stockForm.value.cantidad || stockForm.value.cantidad <= 0) return
  saving.value = true
  try {
    await agregarStock(sedeActiva.value.id, {
      producto: stockForm.value.producto,
      cantidad: stockForm.value.cantidad,
      motivo:   stockForm.value.motivo || 'Ingreso manual',
    })
    showStock.value = false
    if (showInventario.value) await verInventario(sedeActiva.value)
  } finally {
    saving.value = false
  }
}

onMounted(load)
</script>

<template>
  <div class="container-fluid py-4 px-3 px-md-4">

    <!-- Header -->
    <div class="d-flex flex-wrap align-items-start justify-content-between gap-3 mb-4">
      <div>
        <h1 class="h3 fw-bold mb-0">Sedes</h1>
        <p class="text-muted small mb-0">
          Domicilios de producción y dispensarios del club
          <span class="ms-2 badge rounded-pill"
                :style="{ background: planColor.bg, color: planColor.text, border: `1px solid ${planColor.border}` }">
            Plan {{ planLabel }}
          </span>
        </p>
      </div>
      <button v-if="canEdit" class="btn btn-success" @click="openCreate">
        <i class="bi bi-plus-circle me-1"></i> Nueva sede
      </button>
    </div>

    <!-- Barra de uso del plan -->
    <div v-if="limites.sedes" class="card border-0 bg-body-secondary mb-4">
      <div class="card-body py-2 px-3 small">
        <div class="d-flex justify-content-between mb-1">
          <span class="text-muted">Sedes utilizadas</span>
          <span class="fw-semibold">{{ uso.sedes || 0 }} / {{ limites.sedes }}</span>
        </div>
        <div class="progress" style="height:5px">
          <div class="progress-bar"
               :class="(uso.sedes||0) >= limites.sedes ? 'bg-danger' : 'bg-success'"
               :style="{ width: `${Math.min(100, ((uso.sedes||0)/limites.sedes)*100)}%` }">
          </div>
        </div>
      </div>
    </div>

    <!-- KPIs -->
    <div class="row g-3 mb-4">
      <div class="col-6 col-md-3">
        <div class="kpi card border-0 h-100"><div class="card-body">
          <div class="kpi-icon mb-2" style="background:rgba(27,94,32,.1)">🏢</div>
          <div class="kpi-value">{{ kpis.total }}</div>
          <div class="kpi-label">Total sedes</div>
        </div></div>
      </div>
      <div class="col-6 col-md-3">
        <div class="kpi card border-0 h-100"><div class="card-body">
          <div class="kpi-icon mb-2" style="background:rgba(25,135,84,.1)">🌱</div>
          <div class="kpi-value">{{ kpis.produccion }}</div>
          <div class="kpi-label">Producción</div>
        </div></div>
      </div>
      <div class="col-6 col-md-3">
        <div class="kpi card border-0 h-100"><div class="card-body">
          <div class="kpi-icon mb-2" style="background:rgba(13,110,253,.1)">🏪</div>
          <div class="kpi-value">{{ kpis.social }}</div>
          <div class="kpi-label">Dispensarios</div>
        </div></div>
      </div>
      <div class="col-6 col-md-3">
        <div class="kpi card border-0 h-100"><div class="card-body">
          <div class="kpi-icon mb-2" style="background:rgba(255,193,7,.12)">✅</div>
          <div class="kpi-value">{{ kpis.reprocann }}</div>
          <div class="kpi-label">Declaradas REPROCANN</div>
        </div></div>
      </div>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="text-center py-5">
      <div class="spinner-border text-success"></div>
    </div>

    <!-- Empty -->
    <div v-else-if="!sedes.length" class="text-center py-5 text-muted">
      <div class="fs-1 mb-3">🏢</div>
      <h5>No hay sedes registradas</h5>
      <p class="small mb-3">Registrá la primera sede del club</p>
      <button v-if="canEdit" class="btn btn-success btn-sm" @click="openCreate">Nueva sede</button>
    </div>

    <!-- Grid -->
    <div v-else class="row g-3">
      <div v-for="sede in sedes" :key="sede.id" class="col-12 col-md-6 col-xl-4">
        <div class="sede-card" :style="{ '--tipo-color': tipoMeta(sede.tipo).color }">
          <div class="sede-card__bar"></div>
          <div class="sede-card__body">
            <div class="d-flex align-items-start justify-content-between gap-2 mb-2">
              <div>
                <div class="d-flex align-items-center gap-2">
                  <span class="fs-5">{{ tipoMeta(sede.tipo).icon }}</span>
                  <h6 class="fw-bold mb-0">{{ sede.nombre }}</h6>
                </div>
                <span class="small fw-semibold" :style="{ color: tipoMeta(sede.tipo).color }">
                  {{ tipoMeta(sede.tipo).label }}
                </span>
              </div>
              <span v-if="sede.declarada_reprocann" class="badge text-bg-success flex-shrink-0" style="font-size:.68rem">
                ✓ REPROCANN
              </span>
            </div>

            <p v-if="sede.direccion_completa" class="small text-muted mb-2">
              <i class="bi bi-geo-alt me-1"></i>{{ sede.direccion_completa }}
            </p>

            <div class="d-flex gap-3 small text-muted mb-3">
              <span><i class="bi bi-building me-1"></i>{{ sede.salas_count }} salas</span>
            </div>

            <div class="d-flex gap-2 pt-2 border-top">
              <button v-if="['social','mixta'].includes(sede.tipo)"
                      class="btn btn-sm btn-outline-primary flex-fill" @click="verInventario(sede)">
                <i class="bi bi-box-seam me-1"></i>Inventario
              </button>
              <button v-if="canEdit && ['social','mixta'].includes(sede.tipo)"
                      class="btn btn-sm btn-outline-success" @click="abrirAgregarStock(sede)" title="Agregar stock">
                <i class="bi bi-plus-circle"></i>
              </button>
              <button v-if="canEdit" class="btn btn-sm btn-outline-secondary flex-fill" @click="openEdit(sede)">
                <i class="bi bi-pencil me-1"></i>Editar
              </button>
              <button v-if="canEdit" class="btn btn-sm btn-outline-danger" @click="deleteTarget=sede; showDelete=true">
                <i class="bi bi-trash"></i>
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- MODAL CREAR/EDITAR -->
    <div v-if="showModal" class="modal fade show d-block" tabindex="-1" aria-modal="true">
      <div class="modal-dialog modal-dialog-centered modal-lg">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">{{ editingId ? 'Editar sede' : 'Nueva sede' }}</h5>
            <button class="btn-close" @click="showModal=false"></button>
          </div>
          <div class="modal-body">
            <div v-if="formError" class="alert alert-danger d-flex align-items-center gap-2 mb-3">
              <i class="bi bi-exclamation-triangle-fill"></i><span>{{ formError }}</span>
            </div>
            <div class="row g-3">
              <div class="col-12">
                <label class="form-label small fw-semibold">Nombre <span class="text-danger">*</span></label>
                <input v-model.trim="form.nombre" class="form-control"
                       :class="{'is-invalid':formErrors.nombre}" placeholder="Ej: Sede Norte, Dispensario Central" />
                <div class="invalid-feedback">{{ formErrors.nombre }}</div>
              </div>
              <div class="col-12">
                <label class="form-label small fw-semibold">Tipo</label>
                <div class="d-flex gap-2">
                  <button v-for="(meta, key) in TIPO_META" :key="key"
                          type="button" class="btn btn-sm flex-fill"
                          :class="form.tipo === key ? 'btn-dark' : 'btn-outline-secondary'"
                          :style="form.tipo === key ? { background: meta.color, borderColor: meta.color } : {}"
                          @click="form.tipo = key">
                    {{ meta.icon }} {{ meta.label }}
                  </button>
                </div>
              </div>
              <div class="col-12">
                <label class="form-label small fw-semibold">Dirección</label>
                <input v-model.trim="form.direccion" class="form-control" placeholder="Av. Corrientes 1234" />
              </div>
              <div class="col-md-5">
                <label class="form-label small fw-semibold">Ciudad</label>
                <input v-model.trim="form.ciudad" class="form-control" placeholder="Buenos Aires" />
              </div>
              <div class="col-md-4">
                <label class="form-label small fw-semibold">Provincia</label>
                <input v-model.trim="form.provincia" class="form-control" placeholder="CABA" />
              </div>
              <div class="col-md-3">
                <label class="form-label small fw-semibold">País</label>
                <input v-model.trim="form.pais" class="form-control" />
              </div>
              <div class="col-12">
                <div class="form-check form-switch">
                  <input v-model="form.declarada_reprocann" class="form-check-input" type="checkbox" id="chkReprocann" role="switch" />
                  <label class="form-check-label small" for="chkReprocann">
                    Declarada ante REPROCANN como domicilio de cultivo
                  </label>
                </div>
                <div class="form-text">Res. 1780/2025 — máximo 3 domicilios por ONG</div>
              </div>
              <div class="col-12">
                <label class="form-label small fw-semibold">Notas</label>
                <textarea v-model.trim="form.notas" class="form-control" rows="2"
                          placeholder="Observaciones, horarios, responsable…"></textarea>
              </div>
            </div>
          </div>
          <div class="modal-footer">
            <button class="btn btn-outline-secondary" :disabled="saving" @click="showModal=false">Cancelar</button>
            <button class="btn btn-success px-4" :disabled="saving" @click="handleSubmit">
              <span v-if="saving" class="spinner-border spinner-border-sm me-2"></span>
              {{ editingId ? 'Guardar cambios' : 'Crear sede' }}
            </button>
          </div>
        </div>
      </div>
    </div>
    <div v-if="showModal" class="modal-backdrop fade show" @click="showModal=false"></div>

    <!-- MODAL ELIMINAR -->
    <div v-if="showDelete" class="modal fade show d-block" tabindex="-1" aria-modal="true">
      <div class="modal-dialog modal-dialog-centered">
        <div class="modal-content">
          <div class="modal-header border-0">
            <h5 class="modal-title text-danger">⚠️ Eliminar sede</h5>
            <button class="btn-close" @click="showDelete=false"></button>
          </div>
          <div class="modal-body">
            <p>¿Desactivar <strong>{{ deleteTarget?.nombre }}</strong>?</p>
            <p class="text-muted small mb-0">Las salas e inventario se mantendrán.</p>
          </div>
          <div class="modal-footer border-0">
            <button class="btn btn-outline-secondary" @click="showDelete=false">Cancelar</button>
            <button class="btn btn-danger" @click="handleDelete">Eliminar</button>
          </div>
        </div>
      </div>
    </div>
    <div v-if="showDelete" class="modal-backdrop fade show" @click="showDelete=false"></div>

    <!-- MODAL INVENTARIO -->
    <div v-if="showInventario && sedeActiva" class="modal fade show d-block" tabindex="-1" aria-modal="true">
      <div class="modal-dialog modal-dialog-centered modal-lg">
        <div class="modal-content">
          <div class="modal-header">
            <div>
              <h5 class="modal-title mb-0">📦 Inventario — {{ sedeActiva.nombre }}</h5>
              <p class="text-muted small mb-0">Stock disponible para dispensar</p>
            </div>
            <div class="d-flex gap-2 ms-3">
              <button class="btn btn-sm btn-success" @click="abrirAgregarStock(sedeActiva)">
                <i class="bi bi-plus-circle me-1"></i>Agregar stock
              </button>
              <button class="btn-close" @click="showInventario=false"></button>
            </div>
          </div>
          <div class="modal-body">
            <div v-if="loadingInv" class="text-center py-4">
              <div class="spinner-border spinner-border-sm text-success"></div>
            </div>
            <div v-else-if="!inventarioData.length" class="text-center py-4 text-muted">
              <div class="fs-2 mb-2">📦</div>
              <div class="small">Sin stock en esta sede</div>
            </div>
            <div v-else class="row g-3">
              <div v-for="item in inventarioData" :key="item.id" class="col-6 col-md-4">
                <div class="inv-card" :class="{ 'inv-card--bajo': item.stock_bajo }">
                  <div class="inv-card__producto">{{ item.producto_label }}</div>
                  <div class="inv-card__stock">{{ item.stock_gramos }}g</div>
                  <div v-if="item.stock_bajo" class="inv-card__alerta">⚠️ Stock bajo</div>
                  <div v-if="item.lote" class="small text-muted mt-1">{{ item.lote.codigo }}</div>
                </div>
              </div>
            </div>
          </div>
          <div class="modal-footer">
            <button class="btn btn-outline-secondary" @click="showInventario=false">Cerrar</button>
          </div>
        </div>
      </div>
    </div>
    <div v-if="showInventario" class="modal-backdrop fade show" @click="showInventario=false"></div>

    <!-- MODAL AGREGAR STOCK -->
    <div v-if="showStock" class="modal fade show d-block" tabindex="-1" aria-modal="true" style="z-index:1060">
      <div class="modal-dialog modal-dialog-centered">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">📥 Agregar stock — {{ sedeActiva?.nombre }}</h5>
            <button class="btn-close" @click="showStock=false"></button>
          </div>
          <div class="modal-body">
            <div class="row g-3">
              <div class="col-md-6">
                <label class="form-label small fw-semibold">Producto</label>
                <select v-model="stockForm.producto" class="form-select">
                  <option value="flores">Flores</option>
                  <option value="aceite">Aceite</option>
                  <option value="extracto">Extracto</option>
                  <option value="crema">Crema</option>
                  <option value="otro">Otro</option>
                </select>
              </div>
              <div class="col-md-6">
                <label class="form-label small fw-semibold">Cantidad (gramos)</label>
                <input v-model.number="stockForm.cantidad" type="number" step="0.1" min="0.1"
                       class="form-control" placeholder="Ej: 100" />
              </div>
              <div class="col-12">
                <label class="form-label small fw-semibold">Motivo</label>
                <input v-model.trim="stockForm.motivo" class="form-control"
                       placeholder="Ej: Cosecha lote L-001…" />
              </div>
            </div>
          </div>
          <div class="modal-footer">
            <button class="btn btn-outline-secondary" :disabled="saving" @click="showStock=false">Cancelar</button>
            <button class="btn btn-success" :disabled="saving" @click="confirmarStock">
              <span v-if="saving" class="spinner-border spinner-border-sm me-2"></span>
              Confirmar ingreso
            </button>
          </div>
        </div>
      </div>
    </div>
    <div v-if="showStock" class="modal-backdrop fade show" style="z-index:1055" @click="showStock=false"></div>

    <!-- MODAL UPGRADE -->
    <div v-if="showUpgrade" class="modal fade show d-block" tabindex="-1" aria-modal="true">
      <div class="modal-dialog modal-dialog-centered">
        <div class="modal-content">
          <div class="modal-header border-0 pb-0">
            <button class="btn-close ms-auto" @click="showUpgrade=false"></button>
          </div>
          <div class="modal-body text-center py-4">
            <div class="fs-1 mb-3">🚀</div>
            <h5 class="fw-bold">Límite del plan alcanzado</h5>
            <p class="text-muted small mb-4">
              Tu plan <strong>{{ planLabel }}</strong> permite
              <strong>{{ limites.sedes }} sede{{ limites.sedes !== 1 ? 's' : '' }}</strong>.
              Contactá al equipo para actualizar.
            </p>
            <a href="mailto:hola@cultivoespacial.com" class="btn btn-success px-4">
              <i class="bi bi-envelope me-1"></i>Contactar
            </a>
          </div>
        </div>
      </div>
    </div>
    <div v-if="showUpgrade" class="modal-backdrop fade show" @click="showUpgrade=false"></div>

  </div>
</template>

<style scoped>
.kpi .card-body { padding: 1.25rem 1.5rem; }
.kpi-icon { width:40px; height:40px; border-radius:10px; display:flex; align-items:center; justify-content:center; font-size:1.1rem; }
.kpi-value { font-size:1.8rem; font-weight:700; line-height:1; color:#1f2937; }
.kpi-label { font-size:.82rem; color:#6b7280; margin-top:.2rem; }

.sede-card { background:white; border-radius:14px; border:1.5px solid rgba(0,0,0,.06); overflow:hidden; height:100%; display:flex; flex-direction:column; transition:all .15s; }
.sede-card:hover { transform:translateY(-2px); box-shadow:0 8px 24px rgba(0,0,0,.09); border-color:var(--tipo-color); }
.sede-card__bar { height:5px; background:var(--tipo-color); }
.sede-card__body { padding:1rem; flex:1; display:flex; flex-direction:column; }

.inv-card { background:#f8f9fa; border-radius:10px; padding:1rem; text-align:center; border:1.5px solid rgba(0,0,0,.06); }
.inv-card--bajo { border-color:#ffc107; background:#fff8e1; }
.inv-card__producto { font-size:.8rem; font-weight:600; text-transform:uppercase; color:#6c757d; margin-bottom:.25rem; }
.inv-card__stock { font-size:1.6rem; font-weight:700; color:#1f2937; }
.inv-card__alerta { font-size:.72rem; color:#856404; margin-top:.25rem; }
</style>
