<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { listSedes, createSede, updateSede, deleteSede,
  getSedeInventario, agregarStock } from '../lib/api.js'
import { useAuthStore } from '../stores/auth.js'
import { usePlan } from '../composables/usePlan.js'

const router = useRouter()
const auth = useAuthStore()
const { fetchPlan, planLabel, planColor, limites, uso } = usePlan()

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
  produccion: { label: 'Producción',  icon: '🌱', color: '#16a34a', bg: 'rgba(22,163,74,.08)'  },
  social:     { label: 'Dispensario', icon: '🏪', color: '#2563eb', bg: 'rgba(37,99,235,.08)'  },
  mixta:      { label: 'Mixta',       icon: '🔄', color: '#7c3aed', bg: 'rgba(124,58,237,.08)' },
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

onMounted(async () => {
  try {
    await fetchPlan()
    const { data } = await listSedes()
    sedes.value = data
  } finally { loading.value = false }
})

function openCreate() {
  editingId.value  = null
  form.value       = emptyForm()
  formErrors.value = {}
  formError.value  = null
  showModal.value  = true
}
function openEdit(sede) {
  editingId.value  = sede.id
  form.value       = { ...emptyForm(), ...sede }
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
  saving.value = true
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
  } finally { saving.value = false }
}
async function handleDelete() {
  try {
    await deleteSede(deleteTarget.value.id)
    sedes.value      = sedes.value.filter(s => s.id !== deleteTarget.value.id)
    showDelete.value = false
    await fetchPlan()
  } catch { showDelete.value = false }
}
async function verInventario(sede) {
  sedeActiva.value     = sede
  loadingInv.value     = true
  showInventario.value = true
  try {
    const { data } = await getSedeInventario(sede.id)
    inventarioData.value = data
  } finally { loadingInv.value = false }
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
  } finally { saving.value = false }
}
</script>

<template>
  <div class="sedes-page">

    <!-- Header -->
    <div class="page-header">
      <div class="page-header__left">
        <h1 class="page-title">Sedes</h1>
        <p class="page-subtitle">
          Domicilios de producción y dispensarios del club
          <span class="plan-badge" :style="{ background: planColor?.bg, color: planColor?.text }">
            {{ planLabel }}
          </span>
        </p>
      </div>
      <button v-if="canEdit" class="btn-primary-action" @click="openCreate">
        <i class="bi bi-plus-lg"></i>
        Nueva sede
      </button>
    </div>

    <!-- Barra de uso del plan -->
    <div v-if="limites?.sedes" class="plan-usage">
      <div class="plan-usage__info">
        <span class="plan-usage__label">Sedes utilizadas</span>
        <span class="plan-usage__count">{{ uso?.sedes || 0 }} / {{ limites.sedes }}</span>
      </div>
      <div class="plan-usage__bar">
        <div class="plan-usage__fill"
             :class="(uso?.sedes||0) >= limites.sedes ? 'plan-usage__fill--danger' : ''"
             :style="{ width: `${Math.min(100, ((uso?.sedes||0)/limites.sedes)*100)}%` }">
        </div>
      </div>
    </div>

    <!-- KPIs -->
    <div class="kpi-grid">
      <div class="kpi-card">
        <div class="kpi-card__icon" style="background:rgba(15,23,42,.06)">🏢</div>
        <div class="kpi-card__body">
          <div class="kpi-card__value">{{ kpis.total }}</div>
          <div class="kpi-card__label">Total sedes</div>
        </div>
      </div>
      <div class="kpi-card">
        <div class="kpi-card__icon" style="background:rgba(22,163,74,.1)">🌱</div>
        <div class="kpi-card__body">
          <div class="kpi-card__value" style="color:#16a34a">{{ kpis.produccion }}</div>
          <div class="kpi-card__label">Con producción</div>
        </div>
      </div>
      <div class="kpi-card">
        <div class="kpi-card__icon" style="background:rgba(37,99,235,.1)">🏪</div>
        <div class="kpi-card__body">
          <div class="kpi-card__value" style="color:#2563eb">{{ kpis.social }}</div>
          <div class="kpi-card__label">Dispensarios</div>
        </div>
      </div>
      <div class="kpi-card">
        <div class="kpi-card__icon" style="background:rgba(234,179,8,.1)">✅</div>
        <div class="kpi-card__body">
          <div class="kpi-card__value" style="color:#ca8a04">{{ kpis.reprocann }}</div>
          <div class="kpi-card__label">REPROCANN</div>
        </div>
      </div>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="loading-state">
      <div class="spinner"></div>
      <span>Cargando sedes…</span>
    </div>

    <!-- Empty -->
    <div v-else-if="!sedes.length" class="empty-state">
      <div class="empty-state__icon">🏢</div>
      <h3 class="empty-state__title">Sin sedes registradas</h3>
      <p class="empty-state__desc">Registrá la primera sede del club para comenzar a organizar la producción.</p>
      <button v-if="canEdit" class="btn-primary-action" @click="openCreate">
        <i class="bi bi-plus-lg"></i>Nueva sede
      </button>
    </div>

    <!-- Grid de sedes -->
    <div v-else class="sedes-grid">
      <div
        v-for="sede in sedes"
        :key="sede.id"
        class="sede-card"
        :style="{ '--tipo-color': tipoMeta(sede.tipo).color, '--tipo-bg': tipoMeta(sede.tipo).bg }"
        @click="router.push({ name: 'sede-detail', params: { id: sede.id } })"
      >
        <!-- Accent bar -->
        <div class="sede-card__accent"></div>

        <div class="sede-card__content">
          <!-- Header de la card -->
          <div class="sede-card__header">
            <div class="sede-card__tipo-icon">{{ tipoMeta(sede.tipo).icon }}</div>
            <div class="sede-card__info">
              <h3 class="sede-card__nombre">{{ sede.nombre }}</h3>
              <span class="sede-card__tipo-label" :style="{ color: tipoMeta(sede.tipo).color }">
                {{ tipoMeta(sede.tipo).label }}
              </span>
            </div>
            <span v-if="sede.declarada_reprocann" class="reprocann-badge">
              REPROCANN
            </span>
          </div>

          <!-- Dirección -->
          <p v-if="sede.direccion_completa" class="sede-card__direccion">
            <i class="bi bi-geo-alt-fill"></i>
            {{ sede.direccion_completa }}
          </p>

          <!-- Stats -->
          <div class="sede-card__stats">
            <div class="sede-card__stat">
              <span class="sede-card__stat-value">{{ sede.salas_count || 0 }}</span>
              <span class="sede-card__stat-label">salas</span>
            </div>
            <div v-if="sede.plantas_count !== undefined" class="sede-card__stat">
              <span class="sede-card__stat-value">{{ sede.plantas_count || 0 }}</span>
              <span class="sede-card__stat-label">plantas</span>
            </div>
          </div>

          <!-- Acciones -->
          <div class="sede-card__actions" @click.stop>
            <button
              v-if="['social','mixta'].includes(sede.tipo)"
              class="sede-card__btn sede-card__btn--secondary"
              @click="verInventario(sede)"
              title="Ver inventario"
            >
              <i class="bi bi-box-seam"></i>
              Inventario
            </button>
            <button
              v-if="canEdit && ['social','mixta'].includes(sede.tipo)"
              class="sede-card__btn sede-card__btn--ghost"
              @click="abrirAgregarStock(sede)"
              title="Agregar stock"
            >
              <i class="bi bi-plus-circle"></i>
            </button>
            <button
              v-if="canEdit"
              class="sede-card__btn sede-card__btn--ghost"
              @click="openEdit(sede)"
              title="Editar sede"
            >
              <i class="bi bi-pencil"></i>
            </button>
            <button
              v-if="canEdit"
              class="sede-card__btn sede-card__btn--danger"
              @click="deleteTarget = sede; showDelete = true"
              title="Eliminar"
            >
              <i class="bi bi-trash"></i>
            </button>
            <RouterLink
              :to="{ name: 'sede-detail', params: { id: sede.id } }"
              class="sede-card__btn sede-card__btn--primary"
            >
              Ver sede <i class="bi bi-arrow-right"></i>
            </RouterLink>
          </div>
        </div>
      </div>
    </div>

    <!-- ═══════ MODAL CREAR/EDITAR ═══════ -->
    <Teleport to="body">
      <div v-if="showModal" class="modal-overlay" @click.self="showModal=false">
        <div class="modal-panel modal-panel--lg">
          <div class="modal-panel__header">
            <h2 class="modal-panel__title">{{ editingId ? 'Editar sede' : 'Nueva sede' }}</h2>
            <button class="modal-panel__close" @click="showModal=false">
              <i class="bi bi-x-lg"></i>
            </button>
          </div>
          <div class="modal-panel__body">
            <div v-if="formError" class="form-alert">
              <i class="bi bi-exclamation-triangle-fill"></i> {{ formError }}
            </div>
            <div class="form-grid">
              <div class="form-group form-group--full">
                <label class="form-label">Nombre <span class="required">*</span></label>
                <input
                  v-model.trim="form.nombre"
                  class="form-input"
                  :class="{ 'form-input--error': formErrors.nombre }"
                  placeholder="Ej: Sede Norte, Dispensario Central"
                />
                <span v-if="formErrors.nombre" class="form-error">{{ formErrors.nombre }}</span>
              </div>

              <div class="form-group form-group--full">
                <label class="form-label">Tipo de sede</label>
                <div class="tipo-selector">
                  <button
                    v-for="(meta, key) in TIPO_META"
                    :key="key"
                    type="button"
                    class="tipo-btn"
                    :class="{ 'tipo-btn--active': form.tipo === key }"
                    :style="form.tipo === key ? { background: meta.color, borderColor: meta.color, color: '#fff' } : {}"
                    @click="form.tipo = key"
                  >
                    {{ meta.icon }} {{ meta.label }}
                  </button>
                </div>
              </div>

              <div class="form-group form-group--full">
                <label class="form-label">Dirección</label>
                <input v-model.trim="form.direccion" class="form-input" placeholder="Av. Corrientes 1234" />
              </div>

              <div class="form-group">
                <label class="form-label">Ciudad</label>
                <input v-model.trim="form.ciudad" class="form-input" placeholder="Buenos Aires" />
              </div>

              <div class="form-group">
                <label class="form-label">Provincia</label>
                <input v-model.trim="form.provincia" class="form-input" placeholder="CABA" />
              </div>

              <div class="form-group">
                <label class="form-label">País</label>
                <input v-model.trim="form.pais" class="form-input" />
              </div>

              <div class="form-group form-group--full">
                <label class="form-label">Notas</label>
                <textarea
                  v-model.trim="form.notas"
                  class="form-input form-textarea"
                  rows="2"
                  placeholder="Observaciones, horarios, responsable…"
                ></textarea>
              </div>

              <div class="form-group form-group--full">
                <label class="form-toggle">
                  <input v-model="form.declarada_reprocann" type="checkbox" class="form-toggle__input" />
                  <div class="form-toggle__track">
                    <div class="form-toggle__thumb"></div>
                  </div>
                  <div>
                    <div class="form-toggle__label">Declarada ante REPROCANN</div>
                    <div class="form-toggle__hint">Res. 1780/2025 — máx. 3 domicilios por ONG</div>
                  </div>
                </label>
              </div>
            </div>
          </div>
          <div class="modal-panel__footer">
            <button class="btn-ghost" :disabled="saving" @click="showModal=false">Cancelar</button>
            <button class="btn-primary-action" :disabled="saving" @click="handleSubmit">
              <span v-if="saving" class="spinner spinner--sm"></span>
              {{ editingId ? 'Guardar cambios' : 'Crear sede' }}
            </button>
          </div>
        </div>
      </div>
    </Teleport>

    <!-- ═══════ MODAL ELIMINAR ═══════ -->
    <Teleport to="body">
      <div v-if="showDelete" class="modal-overlay" @click.self="showDelete=false">
        <div class="modal-panel modal-panel--sm">
          <div class="modal-panel__header">
            <h2 class="modal-panel__title modal-panel__title--danger">Eliminar sede</h2>
            <button class="modal-panel__close" @click="showDelete=false">
              <i class="bi bi-x-lg"></i>
            </button>
          </div>
          <div class="modal-panel__body">
            <p>¿Eliminar <strong>{{ deleteTarget?.nombre }}</strong>?</p>
            <p class="text-muted-sm">Las salas e inventario se mantendrán en el sistema.</p>
          </div>
          <div class="modal-panel__footer">
            <button class="btn-ghost" @click="showDelete=false">Cancelar</button>
            <button class="btn-danger" @click="handleDelete">Eliminar</button>
          </div>
        </div>
      </div>
    </Teleport>

    <!-- ═══════ MODAL INVENTARIO ═══════ -->
    <Teleport to="body">
      <div v-if="showInventario && sedeActiva" class="modal-overlay" @click.self="showInventario=false">
        <div class="modal-panel modal-panel--lg">
          <div class="modal-panel__header">
            <div>
              <h2 class="modal-panel__title">Inventario — {{ sedeActiva.nombre }}</h2>
              <p class="modal-panel__subtitle">Stock disponible para dispensar</p>
            </div>
            <div style="display:flex;gap:8px;align-items:center">
              <button class="btn-primary-action btn-primary-action--sm" @click="abrirAgregarStock(sedeActiva)">
                <i class="bi bi-plus-lg"></i> Agregar stock
              </button>
              <button class="modal-panel__close" @click="showInventario=false">
                <i class="bi bi-x-lg"></i>
              </button>
            </div>
          </div>
          <div class="modal-panel__body">
            <div v-if="loadingInv" class="loading-state">
              <div class="spinner"></div>
            </div>
            <div v-else-if="!inventarioData.length" class="empty-state empty-state--sm">
              <div class="empty-state__icon">📦</div>
              <p class="empty-state__desc">Sin stock en esta sede</p>
            </div>
            <div v-else class="inv-grid">
              <div v-for="item in inventarioData" :key="item.id" class="inv-card" :class="{ 'inv-card--low': item.stock_bajo }">
                <div class="inv-card__producto">{{ item.producto_label }}</div>
                <div class="inv-card__stock">{{ item.stock_gramos }}g</div>
                <div v-if="item.stock_bajo" class="inv-card__alerta">⚠ Stock bajo</div>
                <div v-if="item.lote" class="inv-card__lote">{{ item.lote.codigo }}</div>
              </div>
            </div>
          </div>
          <div class="modal-panel__footer">
            <button class="btn-ghost" @click="showInventario=false">Cerrar</button>
          </div>
        </div>
      </div>
    </Teleport>

    <!-- ═══════ MODAL AGREGAR STOCK ═══════ -->
    <Teleport to="body">
      <div v-if="showStock" class="modal-overlay modal-overlay--top" @click.self="showStock=false">
        <div class="modal-panel modal-panel--sm">
          <div class="modal-panel__header">
            <h2 class="modal-panel__title">Agregar stock — {{ sedeActiva?.nombre }}</h2>
            <button class="modal-panel__close" @click="showStock=false">
              <i class="bi bi-x-lg"></i>
            </button>
          </div>
          <div class="modal-panel__body">
            <div class="form-grid">
              <div class="form-group">
                <label class="form-label">Producto</label>
                <select v-model="stockForm.producto" class="form-input">
                  <option value="flores">Flores</option>
                  <option value="aceite">Aceite</option>
                  <option value="extracto">Extracto</option>
                  <option value="crema">Crema</option>
                  <option value="otro">Otro</option>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Cantidad (gramos)</label>
                <input v-model.number="stockForm.cantidad" type="number" step="0.1" min="0.1"
                       class="form-input" placeholder="100" />
              </div>
              <div class="form-group form-group--full">
                <label class="form-label">Motivo</label>
                <input v-model.trim="stockForm.motivo" class="form-input" placeholder="Ej: Cosecha lote L-001…" />
              </div>
            </div>
          </div>
          <div class="modal-panel__footer">
            <button class="btn-ghost" :disabled="saving" @click="showStock=false">Cancelar</button>
            <button class="btn-primary-action" :disabled="saving" @click="confirmarStock">
              <span v-if="saving" class="spinner spinner--sm"></span>
              Confirmar ingreso
            </button>
          </div>
        </div>
      </div>
    </Teleport>

    <!-- ═══════ MODAL UPGRADE ═══════ -->
    <Teleport to="body">
      <div v-if="showUpgrade" class="modal-overlay" @click.self="showUpgrade=false">
        <div class="modal-panel modal-panel--sm modal-panel--center">
          <button class="modal-panel__close modal-panel__close--abs" @click="showUpgrade=false">
            <i class="bi bi-x-lg"></i>
          </button>
          <div class="upgrade-body">
            <div class="upgrade-icon">🚀</div>
            <h3 class="upgrade-title">Límite del plan alcanzado</h3>
            <p class="upgrade-desc">
              Tu plan <strong>{{ planLabel }}</strong> permite
              <strong>{{ limites?.sedes }} sede{{ limites?.sedes !== 1 ? 's' : '' }}</strong>.
              Contactá al equipo para actualizar tu plan.
            </p>
            <a href="mailto:hola@cultivoespacial.com" class="btn-primary-action">
              <i class="bi bi-envelope me-1"></i>Contactar
            </a>
          </div>
        </div>
      </div>
    </Teleport>

  </div>
</template>

<style scoped>
/* ── Base page ─────────────────────────────────────────────── */
.sedes-page {
  padding: 2rem 1.5rem;
  max-width: 1280px;
  margin: 0 auto;
}
@media (max-width: 768px) {
  .sedes-page { padding: 1.25rem 1rem; }
}

/* ── Header ─────────────────────────────────────────────────── */
.page-header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 1rem;
  margin-bottom: 1.75rem;
  flex-wrap: wrap;
}
.page-title {
  font-size: 1.75rem;
  font-weight: 700;
  color: #0f172a;
  margin: 0 0 .25rem;
  letter-spacing: -.03em;
}
.page-subtitle {
  font-size: .875rem;
  color: #64748b;
  margin: 0;
  display: flex;
  align-items: center;
  gap: .5rem;
  flex-wrap: wrap;
}
.plan-badge {
  font-size: .7rem;
  font-weight: 600;
  padding: .2em .6em;
  border-radius: 999px;
  text-transform: uppercase;
  letter-spacing: .04em;
}

/* ── Buttons ────────────────────────────────────────────────── */
.btn-primary-action {
  display: inline-flex;
  align-items: center;
  gap: .4rem;
  background: #0f172a;
  color: #fff;
  border: none;
  padding: .6rem 1.25rem;
  border-radius: 8px;
  font-size: .875rem;
  font-weight: 600;
  cursor: pointer;
  transition: background .15s, transform .1s;
  text-decoration: none;
  white-space: nowrap;
}
.btn-primary-action:hover { background: #1e293b; transform: translateY(-1px); }
.btn-primary-action:active { transform: translateY(0); }
.btn-primary-action--sm { padding: .45rem .9rem; font-size: .8rem; }
.btn-ghost {
  background: transparent;
  color: #64748b;
  border: 1px solid #e2e8f0;
  padding: .6rem 1.25rem;
  border-radius: 8px;
  font-size: .875rem;
  font-weight: 500;
  cursor: pointer;
  transition: all .15s;
}
.btn-ghost:hover { background: #f8fafc; color: #0f172a; }
.btn-danger {
  background: #dc2626;
  color: #fff;
  border: none;
  padding: .6rem 1.25rem;
  border-radius: 8px;
  font-size: .875rem;
  font-weight: 600;
  cursor: pointer;
  transition: background .15s;
}
.btn-danger:hover { background: #b91c1c; }

/* ── Plan usage ─────────────────────────────────────────────── */
.plan-usage {
  background: #f8fafc;
  border: 1px solid #e2e8f0;
  border-radius: 10px;
  padding: .75rem 1rem;
  margin-bottom: 1.5rem;
}
.plan-usage__info {
  display: flex;
  justify-content: space-between;
  margin-bottom: .4rem;
  font-size: .8rem;
}
.plan-usage__label { color: #64748b; }
.plan-usage__count { font-weight: 600; color: #0f172a; }
.plan-usage__bar {
  height: 4px;
  background: #e2e8f0;
  border-radius: 999px;
  overflow: hidden;
}
.plan-usage__fill {
  height: 100%;
  background: #16a34a;
  border-radius: 999px;
  transition: width .4s ease;
}
.plan-usage__fill--danger { background: #dc2626; }

/* ── KPI grid ───────────────────────────────────────────────── */
.kpi-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 1rem;
  margin-bottom: 2rem;
}
@media (max-width: 768px) {
  .kpi-grid { grid-template-columns: repeat(2, 1fr); }
}
.kpi-card {
  background: #fff;
  border: 1px solid #e2e8f0;
  border-radius: 12px;
  padding: 1.25rem;
  display: flex;
  align-items: center;
  gap: 1rem;
  transition: box-shadow .15s;
}
.kpi-card:hover { box-shadow: 0 4px 16px rgba(0,0,0,.06); }
.kpi-card__icon {
  width: 44px;
  height: 44px;
  border-radius: 10px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 1.25rem;
  flex-shrink: 0;
}
.kpi-card__value {
  font-size: 1.75rem;
  font-weight: 700;
  color: #0f172a;
  line-height: 1;
  letter-spacing: -.03em;
}
.kpi-card__label {
  font-size: .75rem;
  color: #94a3b8;
  margin-top: .2rem;
  font-weight: 500;
  text-transform: uppercase;
  letter-spacing: .04em;
}

/* ── Loading / Empty ────────────────────────────────────────── */
.loading-state {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: .75rem;
  padding: 4rem;
  color: #94a3b8;
  font-size: .875rem;
}
.empty-state {
  text-align: center;
  padding: 5rem 1rem;
}
.empty-state--sm { padding: 2rem 1rem; }
.empty-state__icon { font-size: 3rem; margin-bottom: 1rem; }
.empty-state__title { font-size: 1.25rem; font-weight: 600; color: #0f172a; margin-bottom: .5rem; }
.empty-state__desc { color: #64748b; font-size: .875rem; margin-bottom: 1.5rem; }

/* ── Spinner ────────────────────────────────────────────────── */
.spinner {
  width: 20px; height: 20px;
  border: 2px solid rgba(255,255,255,.3);
  border-top-color: #fff;
  border-radius: 50%;
  animation: spin .6s linear infinite;
  flex-shrink: 0;
}
.spinner--sm { width: 14px; height: 14px; }
@keyframes spin { to { transform: rotate(360deg); } }

/* ── Sedes grid ─────────────────────────────────────────────── */
.sedes-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 1.25rem;
}
@media (max-width: 1024px) { .sedes-grid { grid-template-columns: repeat(2, 1fr); } }
@media (max-width: 640px)  { .sedes-grid { grid-template-columns: 1fr; } }

/* ── Sede card ──────────────────────────────────────────────── */
.sede-card {
  background: #fff;
  border: 1px solid #e2e8f0;
  border-radius: 14px;
  overflow: hidden;
  cursor: pointer;
  transition: box-shadow .2s, transform .15s;
  position: relative;
  display: flex;
  flex-direction: column;
}
.sede-card:hover {
  box-shadow: 0 8px 32px rgba(0,0,0,.1);
  transform: translateY(-2px);
}
.sede-card__accent {
  height: 3px;
  background: var(--tipo-color);
}
.sede-card__content { padding: 1.25rem; flex: 1; display: flex; flex-direction: column; gap: .75rem; }

.sede-card__header {
  display: flex;
  align-items: flex-start;
  gap: .75rem;
}
.sede-card__tipo-icon {
  width: 40px; height: 40px;
  border-radius: 10px;
  background: var(--tipo-bg);
  display: flex; align-items: center; justify-content: center;
  font-size: 1.1rem;
  flex-shrink: 0;
}
.sede-card__info { flex: 1; min-width: 0; }
.sede-card__nombre {
  font-size: 1rem;
  font-weight: 700;
  color: #0f172a;
  margin: 0 0 .15rem;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.sede-card__tipo-label {
  font-size: .72rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: .05em;
}
.reprocann-badge {
  background: #dcfce7;
  color: #15803d;
  font-size: .65rem;
  font-weight: 700;
  padding: .2em .55em;
  border-radius: 6px;
  text-transform: uppercase;
  letter-spacing: .05em;
  white-space: nowrap;
  flex-shrink: 0;
}

.sede-card__direccion {
  font-size: .8rem;
  color: #64748b;
  margin: 0;
  display: flex;
  align-items: flex-start;
  gap: .3rem;
  line-height: 1.4;
}
.sede-card__direccion i { color: var(--tipo-color); flex-shrink: 0; margin-top: .1rem; }

.sede-card__stats {
  display: flex;
  gap: 1.25rem;
  padding: .6rem .75rem;
  background: #f8fafc;
  border-radius: 8px;
}
.sede-card__stat { display: flex; align-items: baseline; gap: .3rem; }
.sede-card__stat-value { font-size: 1.1rem; font-weight: 700; color: #0f172a; }
.sede-card__stat-label { font-size: .72rem; color: #94a3b8; font-weight: 500; }

.sede-card__actions {
  display: flex;
  gap: .5rem;
  align-items: center;
  flex-wrap: wrap;
  margin-top: auto;
}
.sede-card__btn {
  display: inline-flex;
  align-items: center;
  gap: .35rem;
  padding: .45rem .8rem;
  border-radius: 7px;
  font-size: .78rem;
  font-weight: 600;
  cursor: pointer;
  border: none;
  transition: all .15s;
  text-decoration: none;
  white-space: nowrap;
}
.sede-card__btn--primary {
  background: #0f172a;
  color: #fff;
  margin-left: auto;
}
.sede-card__btn--primary:hover { background: #1e293b; }
.sede-card__btn--secondary {
  background: #eff6ff;
  color: #1d4ed8;
}
.sede-card__btn--secondary:hover { background: #dbeafe; }
.sede-card__btn--ghost {
  background: #f1f5f9;
  color: #475569;
}
.sede-card__btn--ghost:hover { background: #e2e8f0; color: #0f172a; }
.sede-card__btn--danger {
  background: #fef2f2;
  color: #dc2626;
}
.sede-card__btn--danger:hover { background: #fee2e2; }

/* ── Inventario ─────────────────────────────────────────────── */
.inv-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(140px, 1fr));
  gap: .75rem;
}
.inv-card {
  background: #f8fafc;
  border: 1px solid #e2e8f0;
  border-radius: 10px;
  padding: 1rem;
  text-align: center;
}
.inv-card--low { border-color: #fca5a5; background: #fff5f5; }
.inv-card__producto { font-size: .75rem; color: #64748b; font-weight: 600; text-transform: uppercase; letter-spacing: .04em; margin-bottom: .4rem; }
.inv-card__stock { font-size: 1.5rem; font-weight: 700; color: #0f172a; }
.inv-card__alerta { font-size: .7rem; color: #dc2626; margin-top: .3rem; }
.inv-card__lote { font-size: .7rem; color: #94a3b8; margin-top: .3rem; font-family: monospace; }

/* ── Modals ─────────────────────────────────────────────────── */
.modal-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0,0,0,.45);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1050;
  padding: 1rem;
  backdrop-filter: blur(2px);
}
.modal-overlay--top { z-index: 1060; }
.modal-panel {
  background: #fff;
  border-radius: 16px;
  width: 100%;
  max-height: 90vh;
  overflow-y: auto;
  display: flex;
  flex-direction: column;
  box-shadow: 0 24px 64px rgba(0,0,0,.15);
}
.modal-panel--sm { max-width: 440px; }
.modal-panel--lg { max-width: 680px; }
.modal-panel--center { align-items: center; padding: 2rem; }
.modal-panel__header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 1rem;
  padding: 1.5rem 1.5rem 1rem;
  border-bottom: 1px solid #f1f5f9;
}
.modal-panel__title {
  font-size: 1.15rem;
  font-weight: 700;
  color: #0f172a;
  margin: 0;
}
.modal-panel__title--danger { color: #dc2626; }
.modal-panel__subtitle { font-size: .8rem; color: #64748b; margin: .2rem 0 0; }
.modal-panel__close {
  background: #f1f5f9;
  border: none;
  width: 32px; height: 32px;
  border-radius: 8px;
  cursor: pointer;
  display: flex; align-items: center; justify-content: center;
  color: #64748b;
  flex-shrink: 0;
  transition: all .15s;
}
.modal-panel__close:hover { background: #e2e8f0; color: #0f172a; }
.modal-panel__close--abs { position: absolute; top: 1rem; right: 1rem; }
.modal-panel__body { padding: 1.25rem 1.5rem; flex: 1; }
.modal-panel__footer {
  display: flex;
  justify-content: flex-end;
  gap: .75rem;
  padding: 1rem 1.5rem;
  border-top: 1px solid #f1f5f9;
}

/* ── Forms ──────────────────────────────────────────────────── */
.form-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 1rem;
}
@media (max-width: 540px) { .form-grid { grid-template-columns: 1fr; } }
.form-group { display: flex; flex-direction: column; gap: .4rem; }
.form-group--full { grid-column: 1 / -1; }
.form-label { font-size: .8rem; font-weight: 600; color: #374151; }
.required { color: #dc2626; }
.form-input {
  background: #f8fafc;
  border: 1px solid #e2e8f0;
  border-radius: 8px;
  padding: .6rem .85rem;
  font-size: .875rem;
  color: #0f172a;
  transition: border .15s, box-shadow .15s;
  width: 100%;
  box-sizing: border-box;
}
.form-input:focus {
  outline: none;
  border-color: #0f172a;
  box-shadow: 0 0 0 3px rgba(15,23,42,.08);
  background: #fff;
}
.form-input--error { border-color: #dc2626; }
.form-textarea { resize: vertical; min-height: 70px; }
.form-error { font-size: .75rem; color: #dc2626; }
.form-alert {
  background: #fef2f2;
  border: 1px solid #fecaca;
  color: #dc2626;
  padding: .75rem 1rem;
  border-radius: 8px;
  font-size: .85rem;
  margin-bottom: 1rem;
  display: flex;
  gap: .5rem;
  align-items: flex-start;
}

/* ── Tipo selector ──────────────────────────────────────────── */
.tipo-selector {
  display: flex;
  gap: .5rem;
  flex-wrap: wrap;
}
.tipo-btn {
  flex: 1;
  min-width: 100px;
  padding: .55rem .75rem;
  border-radius: 8px;
  border: 1.5px solid #e2e8f0;
  background: #f8fafc;
  color: #475569;
  font-size: .8rem;
  font-weight: 600;
  cursor: pointer;
  transition: all .15s;
  white-space: nowrap;
}
.tipo-btn:hover { border-color: #94a3b8; background: #f1f5f9; }
.tipo-btn--active { font-weight: 700; }

/* ── Toggle ─────────────────────────────────────────────────── */
.form-toggle {
  display: flex;
  align-items: center;
  gap: .75rem;
  cursor: pointer;
}
.form-toggle__input { display: none; }
.form-toggle__track {
  width: 40px; height: 22px;
  background: #e2e8f0;
  border-radius: 999px;
  position: relative;
  transition: background .2s;
  flex-shrink: 0;
}
.form-toggle__input:checked + .form-toggle__track { background: #0f172a; }
.form-toggle__thumb {
  position: absolute;
  width: 16px; height: 16px;
  background: #fff;
  border-radius: 50%;
  top: 3px; left: 3px;
  transition: left .2s;
  box-shadow: 0 1px 3px rgba(0,0,0,.2);
}
.form-toggle__input:checked + .form-toggle__track .form-toggle__thumb { left: 21px; }
.form-toggle__label { font-size: .875rem; font-weight: 600; color: #0f172a; }
.form-toggle__hint { font-size: .75rem; color: #94a3b8; }

/* ── Upgrade ────────────────────────────────────────────────── */
.upgrade-body { text-align: center; padding: 1rem; }
.upgrade-icon { font-size: 3rem; margin-bottom: 1rem; }
.upgrade-title { font-size: 1.25rem; font-weight: 700; color: #0f172a; margin-bottom: .5rem; }
.upgrade-desc { color: #64748b; font-size: .875rem; margin-bottom: 1.5rem; }

/* ── Misc ───────────────────────────────────────────────────── */
.text-muted-sm { font-size: .85rem; color: #64748b; margin-top: .25rem; }
</style>
