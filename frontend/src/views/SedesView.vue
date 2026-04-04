<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { listSedes, createSede, updateSede, deleteSede,
  getSedeInventario, agregarStock } from '../lib/api.js'
import { useAuthStore } from '../stores/auth.js'
import { usePermissions } from '../composables/usePermissions.js'
import { usePlan } from '../composables/usePlan.js'

const router   = useRouter()
const auth     = useAuthStore()
const { isAgricultor, isAdmin } = usePermissions()
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
const PRODUCTOS = [
  { value: "flores",  label: "Flores",   unidad: "g",  step: 0.1,  placeholder: "100" },
  { value: "preroll", label: "Pre-roll", unidad: "u",  step: 1,    placeholder: "10" },
  { value: "aceite",  label: "Aceite",   unidad: "ml", step: 0.1,  placeholder: "50" },
  { value: "extracto",label: "Extracto", unidad: "ml", step: 0.1,  placeholder: "30" },
  { value: "capsula", label: "Cápsula",  unidad: "u",  step: 1,    placeholder: "30" },
  { value: "crema",   label: "Crema",    unidad: "g",  step: 1,    placeholder: "100" },
  { value: "otro",    label: "Otro",     unidad: "g",  step: 0.1,  placeholder: "100" },
]
const productoActual = computed(() => PRODUCTOS.find(p => p.value === stockForm.value.producto) || PRODUCTOS[0])

const CICLO_META = {
  semilla:    { label: 'Semilla',    color: '#a16207', bg: 'rgba(161,98,7,.12)',    dot: '#ca8a04' },
  vegetativo: { label: 'Vegetativo', color: '#15803d', bg: 'rgba(21,128,61,.12)',   dot: '#16a34a' },
  floracion:  { label: 'Floración',  color: '#7e22ce', bg: 'rgba(126,34,206,.12)',  dot: '#9333ea' },
  cosecha:    { label: 'Cosecha',    color: '#b45309', bg: 'rgba(180,83,9,.12)',     dot: '#d97706' },
  curado:     { label: 'Curado',     color: '#0369a1', bg: 'rgba(3,105,161,.12)',    dot: '#0284c7' },
  finalizado: { label: 'Finalizado', color: '#4b5563', bg: 'rgba(75,85,99,.12)',    dot: '#6b7280' },
}

const TIPO_META = {
  produccion: { label: 'Producción',  icon: 'bi-flower2',      color: '#15803d', bg: 'rgba(21,128,61,.1)'   },
  social:     { label: 'Dispensario', icon: 'bi-shop',          color: '#1d4ed8', bg: 'rgba(29,78,216,.1)'   },
  mixta:      { label: 'Mixta',       icon: 'bi-arrow-left-right', color: '#7c3aed', bg: 'rgba(124,58,237,.1)' },
}
function tipoMeta(tipo) { return TIPO_META[tipo] || TIPO_META.produccion }
function cicloMeta(ciclo) { return CICLO_META[ciclo] || CICLO_META.vegetativo }

function emptyForm() {
  return { nombre: '', tipo: 'produccion', direccion: '', ciudad: '',
    provincia: '', declarada_reprocann: false, notas: '' }
}
const form       = ref(emptyForm())
const formErrors = ref({})

const kpis = computed(() => ({
  total:          sedes.value.length,
  produccion:     sedes.value.filter(s => ['produccion','mixta'].includes(s.tipo)).length,
  social:         sedes.value.filter(s => ['social','mixta'].includes(s.tipo)).length,
  reprocann:      sedes.value.filter(s => s.declarada_reprocann).length,
  plantas_total:  sedes.value.reduce((acc, s) => acc + (s.ops?.plantas_activas || 0), 0),
  lotes_total:    sedes.value.reduce((acc, s) => acc + (s.ops?.lotes_activos || 0), 0),
  tareas_urgentes: sedes.value.reduce((acc, s) => acc + (s.ops?.tareas_urgentes || 0), 0),
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

function tieneActividad(sede) {
  return (sede.ops?.plantas_activas || 0) > 0 || (sede.ops?.lotes_activos || 0) > 0
}
</script>

<template>
  <div class="sedes-page">

    <!-- ── VISTA AGRICULTOR ─────────────────────────────────── -->
    <template v-if="isAgricultor">

      <!-- Header agricultor -->
      <div class="agri-header">
        <div class="agri-header__left">
          <div class="agri-header__eyebrow">
            <span class="agri-header__dot"></span>
            Panel de cultivo
          </div>
          <h1 class="agri-header__title">Mis Sedes</h1>
        </div>
        <div class="agri-header__meta" v-if="!loading">
          <span class="agri-meta-pill agri-meta-pill--green">
            <i class="bi bi-flower2"></i>
            {{ kpis.plantas_total }} plantas activas
          </span>
          <span v-if="kpis.tareas_urgentes > 0" class="agri-meta-pill agri-meta-pill--amber">
            <i class="bi bi-exclamation-triangle-fill"></i>
            {{ kpis.tareas_urgentes }} tareas urgentes
          </span>
        </div>
      </div>

      <!-- Loading -->
      <div v-if="loading" class="agri-loading">
        <div class="agri-loading__ring"></div>
        <span>Cargando datos operativos…</span>
      </div>

      <!-- Empty -->
      <div v-else-if="!sedes.length" class="agri-empty">
        <i class="bi bi-building-slash agri-empty__icon"></i>
        <p>No tenés sedes asignadas. Contactá al administrador del club.</p>
      </div>

      <!-- Sedes cockpit -->
      <div v-else class="agri-sedes">
        <div
          v-for="sede in sedes"
          :key="sede.id"
          class="agri-sede"
          :class="{ 'agri-sede--activa': tieneActividad(sede), 'agri-sede--inactiva': !tieneActividad(sede) }"
        >
          <!-- Barra lateral de tipo -->
          <div class="agri-sede__stripe" :style="{ background: tipoMeta(sede.tipo).color }"></div>

          <div class="agri-sede__body">

            <!-- Cabecera de sede -->
            <div class="agri-sede__head">
              <div class="agri-sede__icon" :style="{ background: tipoMeta(sede.tipo).bg, color: tipoMeta(sede.tipo).color }">
                <i :class="['bi', tipoMeta(sede.tipo).icon]"></i>
              </div>
              <div class="agri-sede__title-block">
                <h2 class="agri-sede__nombre">{{ sede.nombre }}</h2>
                <div class="agri-sede__meta">
                  <span class="agri-sede__tipo">{{ tipoMeta(sede.tipo).label }}</span>
                  <span v-if="sede.declarada_reprocann" class="agri-sede__reprocann">
                    <i class="bi bi-patch-check-fill"></i> REPROCANN
                  </span>
                  <span v-if="sede.ciudad" class="agri-sede__ciudad">
                    <i class="bi bi-geo-alt"></i> {{ sede.ciudad }}
                  </span>
                </div>
              </div>

              <!-- KPIs compactos -->
              <div class="agri-sede__kpis" v-if="sede.ops">
                <div class="agri-kpi">
                  <span class="agri-kpi__val">{{ sede.ops.plantas_activas }}</span>
                  <span class="agri-kpi__lbl">plantas</span>
                </div>
                <div class="agri-kpi">
                  <span class="agri-kpi__val">{{ sede.ops.lotes_activos }}</span>
                  <span class="agri-kpi__lbl">lotes</span>
                </div>
                <div class="agri-kpi" :class="{ 'agri-kpi--warn': sede.ops.tareas_urgentes > 0 }">
                  <span class="agri-kpi__val">{{ sede.ops.tareas_pendientes }}</span>
                  <span class="agri-kpi__lbl">tareas</span>
                </div>
                <div v-if="sede.ops.dias_para_cosecha" class="agri-kpi agri-kpi--harvest">
                  <span class="agri-kpi__val">{{ sede.ops.dias_para_cosecha }}d</span>
                  <span class="agri-kpi__lbl">cosecha</span>
                </div>
              </div>
            </div>

            <!-- Sin actividad -->
            <div v-if="!tieneActividad(sede)" class="agri-sede__sin-actividad">
              <i class="bi bi-moon-stars"></i>
              Sin producción activa en esta sede
            </div>

            <!-- Ciclo predominante badge -->
            <div v-else-if="sede.ops?.ciclo_predominante" class="agri-sede__ciclo-banner"
                 :style="{ background: cicloMeta(sede.ops.ciclo_predominante).bg, borderColor: cicloMeta(sede.ops.ciclo_predominante).dot }">
              <span class="agri-sede__ciclo-dot" :style="{ background: cicloMeta(sede.ops.ciclo_predominante).dot }"></span>
              Ciclo predominante: <strong>{{ cicloMeta(sede.ops.ciclo_predominante).label }}</strong>
              <span v-if="sede.ops.dias_para_cosecha" class="agri-sede__cosecha-hint">
                — cosecha estimada en {{ sede.ops.dias_para_cosecha }} días
              </span>
            </div>

            <!-- Salas -->
            <div v-if="sede.ops?.salas?.length" class="agri-salas">
              <RouterLink
                v-for="sala in sede.ops.salas"
                :key="sala.id"
                :to="{ name: 'sala-detail', params: { id: sala.id } }"
                class="agri-sala"
                :class="{ 'agri-sala--con-lotes': sala.lotes_count > 0 }"
              >
                <div class="agri-sala__head">
                  <div class="agri-sala__name-wrap">
                    <span class="agri-sala__indicator" :class="sala.state === 'activa' ? 'agri-sala__indicator--on' : 'agri-sala__indicator--off'"></span>
                    <span class="agri-sala__nombre">{{ sala.nombre }}</span>
                    <span v-if="sala.kind" class="agri-sala__kind">{{ sala.kind }}</span>
                  </div>
                  <div class="agri-sala__stats">
                    <span class="agri-sala__stat">
                      <i class="bi bi-flower1"></i> {{ sala.plantas_count }}
                    </span>
                    <span class="agri-sala__stat">
                      <i class="bi bi-boxes"></i> {{ sala.lotes_count }}
                    </span>
                    <span v-if="sala.plants_max" class="agri-sala__cap">
                      / {{ sala.plants_max }} cap.
                    </span>
                  </div>
                </div>

                <!-- Mini lotes -->
                <div v-if="sala.lotes?.length" class="agri-sala__lotes">
                  <span
                    v-for="lote in sala.lotes"
                    :key="lote.id"
                    class="agri-lote-chip"
                    :style="{ background: cicloMeta(lote.estado).bg, color: cicloMeta(lote.estado).color, borderColor: cicloMeta(lote.estado).dot + '40' }"
                  >
                    <span class="agri-lote-chip__dot" :style="{ background: cicloMeta(lote.estado).dot }"></span>
                    {{ lote.codigo }}
                    <span class="agri-lote-chip__strain" v-if="lote.strain">· {{ lote.strain }}</span>
                    <span class="agri-lote-chip__plants">{{ lote.plants_count }}pl</span>
                  </span>
                </div>
                <div v-else class="agri-sala__empty">Sin lotes activos</div>

                <div class="agri-sala__arrow">
                  <i class="bi bi-arrow-right"></i>
                </div>
              </RouterLink>
            </div>

            <!-- Acción principal -->
            <div class="agri-sede__footer">
              <RouterLink
                :to="{ name: 'sede-detail', params: { id: sede.id } }"
                class="agri-btn-ver"
              >
                Ver detalle completo <i class="bi bi-arrow-up-right"></i>
              </RouterLink>
            </div>

          </div>
        </div>
      </div>
    </template>

    <!-- ── VISTA ADMIN / RESTO ──────────────────────────────── -->
    <template v-else>

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

      <!-- Grid de sedes admin -->
      <div v-else class="sedes-grid">
        <div
          v-for="sede in sedes"
          :key="sede.id"
          class="sede-card"
          :style="{ '--tipo-color': tipoMeta(sede.tipo).color, '--tipo-bg': tipoMeta(sede.tipo).bg }"
          @click="router.push({ name: 'sede-detail', params: { id: sede.id } })"
        >
          <div class="sede-card__accent"></div>
          <div class="sede-card__content">
            <div class="sede-card__header">
              <div class="sede-card__tipo-icon">
                <i :class="['bi', tipoMeta(sede.tipo).icon]"></i>
              </div>
              <div class="sede-card__info">
                <h3 class="sede-card__nombre">{{ sede.nombre }}</h3>
                <span class="sede-card__tipo-label" :style="{ color: tipoMeta(sede.tipo).color }">
                  {{ tipoMeta(sede.tipo).label }}
                </span>
              </div>
              <span v-if="sede.declarada_reprocann" class="reprocann-badge">REPROCANN</span>
            </div>
            <p v-if="sede.direccion_completa" class="sede-card__direccion">
              <i class="bi bi-geo-alt-fill"></i>
              {{ sede.direccion_completa }}
            </p>
            <div class="sede-card__stats">
              <div class="sede-card__stat">
                <span class="sede-card__stat-value">{{ sede.salas_count || 0 }}</span>
                <span class="sede-card__stat-label">salas</span>
              </div>
            </div>
            <div class="sede-card__actions" @click.stop>
              <button
                v-if="['social','mixta'].includes(sede.tipo)"
                class="sede-card__btn sede-card__btn--secondary"
                @click="verInventario(sede)"
              >
                <i class="bi bi-box-seam"></i> Inventario
              </button>
              <button v-if="canEdit && ['social','mixta'].includes(sede.tipo)" class="sede-card__btn sede-card__btn--ghost" @click="abrirAgregarStock(sede)">
                <i class="bi bi-plus-circle"></i>
              </button>
              <button v-if="canEdit" class="sede-card__btn sede-card__btn--ghost" @click="openEdit(sede)">
                <i class="bi bi-pencil"></i>
              </button>
              <button v-if="canEdit" class="sede-card__btn sede-card__btn--danger" @click="deleteTarget = sede; showDelete = true">
                <i class="bi bi-trash"></i>
              </button>
              <RouterLink :to="{ name: 'sede-detail', params: { id: sede.id } }" class="sede-card__btn sede-card__btn--primary">
                Ver sede <i class="bi bi-arrow-right"></i>
              </RouterLink>
            </div>
          </div>
        </div>
      </div>

    </template>

    <!-- ═══════ MODALES (compartidos) ═══════ -->

    <Teleport to="body">
      <div v-if="showModal" class="modal-overlay" @click.self="showModal=false">
        <div class="modal-panel modal-panel--lg">
          <div class="modal-panel__header">
            <h2 class="modal-panel__title">{{ editingId ? 'Editar sede' : 'Nueva sede' }}</h2>
            <button class="modal-panel__close" @click="showModal=false"><i class="bi bi-x-lg"></i></button>
          </div>
          <div class="modal-panel__body">
            <div v-if="formError" class="form-alert"><i class="bi bi-exclamation-triangle-fill"></i> {{ formError }}</div>
            <div class="form-grid">
              <div class="form-group form-group--full">
                <label class="form-label">Nombre <span class="required">*</span></label>
                <input v-model.trim="form.nombre" class="form-input" :class="{ 'form-input--error': formErrors.nombre }" placeholder="Ej: Sede Norte" />
                <span v-if="formErrors.nombre" class="form-error">{{ formErrors.nombre }}</span>
              </div>
              <div class="form-group form-group--full">
                <label class="form-label">Tipo de sede</label>
                <div class="tipo-selector">
                  <button v-for="(meta, key) in TIPO_META" :key="key" type="button" class="tipo-btn"
                          :class="{ 'tipo-btn--active': form.tipo === key }"
                          :style="form.tipo === key ? { background: meta.color, borderColor: meta.color, color: '#fff' } : {}"
                          @click="form.tipo = key">
                    <i :class="['bi', meta.icon]"></i> {{ meta.label }}
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
              <div class="form-group form-group--full">
                <label class="form-label">Notas</label>
                <textarea v-model.trim="form.notas" class="form-input form-textarea" rows="2" placeholder="Observaciones, horarios, responsable…"></textarea>
              </div>
              <div class="form-group form-group--full">
                <label class="form-toggle">
                  <input v-model="form.declarada_reprocann" type="checkbox" class="form-toggle__input" />
                  <div class="form-toggle__track"><div class="form-toggle__thumb"></div></div>
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

    <Teleport to="body">
      <div v-if="showDelete" class="modal-overlay" @click.self="showDelete=false">
        <div class="modal-panel modal-panel--sm">
          <div class="modal-panel__header">
            <h2 class="modal-panel__title modal-panel__title--danger">Eliminar sede</h2>
            <button class="modal-panel__close" @click="showDelete=false"><i class="bi bi-x-lg"></i></button>
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
              <button class="modal-panel__close" @click="showInventario=false"><i class="bi bi-x-lg"></i></button>
            </div>
          </div>
          <div class="modal-panel__body">
            <div v-if="loadingInv" class="loading-state"><div class="spinner"></div></div>
            <div v-else-if="!inventarioData.length" class="empty-state empty-state--sm">
              <div class="empty-state__icon">📦</div>
              <p class="empty-state__desc">Sin stock en esta sede</p>
            </div>
            <div v-else class="inv-grid">
              <div v-for="item in inventarioData" :key="item.id" class="inv-card" :class="{ 'inv-card--low': item.stock_bajo, 'inv-card--ok': !item.stock_bajo }">
                <div class="inv-card__header">
                  <div class="inv-card__producto-icon">
                    <i class="bi" :class="item.producto === 'flores' ? 'bi-flower2' : item.producto === 'aceite' ? 'bi-droplet' : item.producto === 'extracto' ? 'bi-eyedropper' : 'bi-box-seam'"></i>
                  </div>
                  <span v-if="item.stock_bajo" class="inv-card__badge inv-card__badge--warn">
        <i class="bi bi-exclamation-triangle-fill"></i> Stock bajo
      </span>
                  <span v-else class="inv-card__badge inv-card__badge--ok">
        <i class="bi bi-check-circle-fill"></i> OK
      </span>
                </div>
                <div class="inv-card__producto">{{ item.producto_label }}</div>
                <div class="inv-card__stock">
                  {{ Number(item.stock_gramos).toLocaleString('es-AR', { maximumFractionDigits: 1 }) }}
                  <span class="inv-card__unit">g</span>
                </div>
                <div v-if="item.stock_minimo" class="inv-card__bar-wrap">
                  <div class="inv-card__bar"
                       :style="{ width: `${Math.min(100, (item.stock_gramos / item.stock_minimo) * 50)}%` }"
                       :class="item.stock_bajo ? 'inv-card__bar--low' : 'inv-card__bar--ok'">
                  </div>
                </div>
                <div class="inv-card__meta">
                  <span v-if="item.stock_minimo">Mínimo: {{ item.stock_minimo }}g</span>
                  <span>{{ new Date(item.updated_at).toLocaleDateString('es-AR', { day:'numeric', month:'short' }) }}</span>
                </div>
              </div>
            </div>
          </div>
          <div class="modal-panel__footer">
            <button class="btn-ghost" @click="showInventario=false">Cerrar</button>
          </div>
        </div>
      </div>
    </Teleport>

    <Teleport to="body">
      <div v-if="showStock" class="modal-overlay modal-overlay--top" @click.self="showStock=false">
        <div class="modal-panel modal-panel--sm">
          <div class="modal-panel__header">
            <h2 class="modal-panel__title">Agregar stock — {{ sedeActiva?.nombre }}</h2>
            <button class="modal-panel__close" @click="showStock=false"><i class="bi bi-x-lg"></i></button>
          </div>
          <div class="modal-panel__body">
            <div class="form-grid">
              <div class="form-group form-group--full">
                <label class="form-label">Producto</label>
                <div class="stock-productos">
                  <button
                    v-for="p in PRODUCTOS" :key="p.value" type="button"
                    class="stock-producto-btn"
                    :class="{ 'stock-producto-btn--active': stockForm.producto === p.value }"
                    @click="stockForm.producto = p.value; stockForm.cantidad = null"
                  >
                    <i class="bi" :class="p.value === 'flores' ? 'bi-flower2' : p.value === 'preroll' ? 'bi-cannabis' : p.value === 'aceite' || p.value === 'extracto' ? 'bi-droplet' : p.value === 'capsula' ? 'bi-capsule' : p.value === 'crema' ? 'bi-jar' : 'bi-box-seam'"></i>
                    {{ p.label }}
                  </button>
                </div>
              </div>
              <div class="form-group form-group--full">
                <label class="form-label">
                  Cantidad
                  <span class="stock-unidad-badge">{{ productoActual.unidad }}</span>
                </label>
                <div class="stock-cantidad-wrap">
                  <input
                    v-model.number="stockForm.cantidad"
                    type="number"
                    :step="productoActual.step"
                    min="0.1"
                    class="form-input stock-cantidad-input"
                    :placeholder="productoActual.placeholder"
                  />
                  <span class="stock-cantidad-suffix">{{ productoActual.unidad }}</span>
                </div>
                <span class="form-hint">{{ productoActual.label }} se mide en {{ productoActual.unidad === 'g' ? 'gramos' : productoActual.unidad === 'ml' ? 'mililitros' : 'unidades' }}</span>
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

    <Teleport to="body">
      <div v-if="showUpgrade" class="modal-overlay" @click.self="showUpgrade=false">
        <div class="modal-panel modal-panel--sm modal-panel--center">
          <button class="modal-panel__close modal-panel__close--abs" @click="showUpgrade=false"><i class="bi bi-x-lg"></i></button>
          <div class="upgrade-body">
            <div class="upgrade-icon">🚀</div>
            <h3 class="upgrade-title">Límite del plan alcanzado</h3>
            <p class="upgrade-desc">Tu plan <strong>{{ planLabel }}</strong> permite <strong>{{ limites?.sedes }} sede{{ limites?.sedes !== 1 ? 's' : '' }}</strong>. Contactá al equipo para actualizar.</p>
            <a href="mailto:hola@cultivoespacial.com" class="btn-primary-action"><i class="bi bi-envelope me-1"></i>Contactar</a>
          </div>
        </div>
      </div>
    </Teleport>

  </div>
</template>

<style scoped>
/* ── Reset base ─────────────────────────────────────────────── */
.sedes-page {
  padding: 2rem 1.5rem;
  max-width: 1100px;
  margin: 0 auto;
}
@media (max-width: 768px) { .sedes-page { padding: 1.25rem 1rem; } }

/* ══════════════════════════════════════════════════════════════
   VISTA AGRICULTOR
══════════════════════════════════════════════════════════════ */

/* Header agricultor */
.agri-header {
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  gap: 1rem;
  margin-bottom: 2rem;
  flex-wrap: wrap;
}
.agri-header__eyebrow {
  display: flex;
  align-items: center;
  gap: .4rem;
  font-size: .72rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: .1em;
  color: var(--brand-accent, #66bb6a);
  margin-bottom: .35rem;
}
.agri-header__dot {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: var(--brand-accent, #66bb6a);
  animation: pulse-dot 2s ease-in-out infinite;
}
@keyframes pulse-dot {
  0%, 100% { opacity: 1; transform: scale(1); }
  50%       { opacity: .5; transform: scale(.7); }
}
.agri-header__title {
  font-size: 2rem;
  font-weight: 800;
  color: #0f172a;
  margin: 0;
  letter-spacing: -.04em;
  line-height: 1;
}
.agri-header__meta {
  display: flex;
  gap: .5rem;
  flex-wrap: wrap;
  align-items: center;
}
.agri-meta-pill {
  display: inline-flex;
  align-items: center;
  gap: .35rem;
  padding: .35rem .75rem;
  border-radius: 999px;
  font-size: .78rem;
  font-weight: 600;
}
.agri-meta-pill--green {
  background: rgba(21,128,61,.1);
  color: #15803d;
  border: 1px solid rgba(21,128,61,.2);
}
.agri-meta-pill--amber {
  background: rgba(180,83,9,.1);
  color: #b45309;
  border: 1px solid rgba(180,83,9,.25);
}

/* Loading */
.agri-loading {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: .75rem;
  padding: 5rem;
  color: #94a3b8;
  font-size: .875rem;
}
.agri-loading__ring {
  width: 24px;
  height: 24px;
  border: 2px solid #e2e8f0;
  border-top-color: var(--brand-primary, #1b5e20);
  border-radius: 50%;
  animation: spin .7s linear infinite;
}

/* Empty */
.agri-empty {
  text-align: center;
  padding: 5rem 1rem;
  color: #94a3b8;
}
.agri-empty__icon {
  font-size: 3rem;
  display: block;
  margin-bottom: 1rem;
  opacity: .4;
}

/* Sedes list */
.agri-sedes {
  display: flex;
  flex-direction: column;
  gap: 1.25rem;
}

/* Sede card cockpit */
.agri-sede {
  background: #fff;
  border: 1px solid #e2e8f0;
  border-radius: 16px;
  overflow: hidden;
  display: flex;
  transition: box-shadow .2s, transform .15s;
}
.agri-sede:hover {
  box-shadow: 0 8px 32px rgba(0,0,0,.08);
  transform: translateY(-1px);
}
.agri-sede--inactiva {
  opacity: .75;
}
.agri-sede__stripe {
  width: 4px;
  flex-shrink: 0;
}
.agri-sede__body {
  flex: 1;
  padding: 1.5rem;
  min-width: 0;
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

/* Head de sede */
.agri-sede__head {
  display: flex;
  align-items: flex-start;
  gap: 1rem;
  flex-wrap: wrap;
}
.agri-sede__icon {
  width: 46px;
  height: 46px;
  border-radius: 12px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 1.2rem;
  flex-shrink: 0;
}
.agri-sede__title-block {
  flex: 1;
  min-width: 0;
}
.agri-sede__nombre {
  font-size: 1.2rem;
  font-weight: 750;
  color: #0f172a;
  margin: 0 0 .25rem;
  letter-spacing: -.02em;
}
.agri-sede__meta {
  display: flex;
  align-items: center;
  gap: .6rem;
  flex-wrap: wrap;
}
.agri-sede__tipo {
  font-size: .72rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: .06em;
  color: #64748b;
}
.agri-sede__reprocann {
  font-size: .7rem;
  font-weight: 700;
  color: #15803d;
  background: #dcfce7;
  padding: .15em .5em;
  border-radius: 5px;
  display: inline-flex;
  align-items: center;
  gap: .25rem;
}
.agri-sede__ciudad {
  font-size: .75rem;
  color: #94a3b8;
  display: inline-flex;
  align-items: center;
  gap: .25rem;
}

/* KPIs inline */
.agri-sede__kpis {
  display: flex;
  gap: .75rem;
  margin-left: auto;
  flex-wrap: wrap;
  align-items: flex-start;
}
.agri-kpi {
  display: flex;
  flex-direction: column;
  align-items: center;
  background: #f8fafc;
  border: 1px solid #e2e8f0;
  border-radius: 10px;
  padding: .5rem .75rem;
  min-width: 52px;
}
.agri-kpi--warn {
  background: rgba(180,83,9,.06);
  border-color: rgba(180,83,9,.2);
}
.agri-kpi--harvest {
  background: rgba(126,34,206,.06);
  border-color: rgba(126,34,206,.2);
}
.agri-kpi__val {
  font-size: 1.25rem;
  font-weight: 800;
  color: #0f172a;
  line-height: 1;
  letter-spacing: -.03em;
}
.agri-kpi--warn .agri-kpi__val { color: #b45309; }
.agri-kpi--harvest .agri-kpi__val { color: #7e22ce; }
.agri-kpi__lbl {
  font-size: .62rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: .05em;
  color: #94a3b8;
  margin-top: .15rem;
}

/* Sin actividad */
.agri-sede__sin-actividad {
  display: flex;
  align-items: center;
  gap: .5rem;
  font-size: .83rem;
  color: #94a3b8;
  padding: .5rem .75rem;
  background: #f8fafc;
  border-radius: 8px;
  border: 1px dashed #e2e8f0;
}

/* Banner ciclo predominante */
.agri-sede__ciclo-banner {
  display: flex;
  align-items: center;
  gap: .5rem;
  font-size: .8rem;
  color: #374151;
  padding: .5rem .875rem;
  border-radius: 8px;
  border: 1px solid;
  flex-wrap: wrap;
}
.agri-sede__ciclo-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  flex-shrink: 0;
}
.agri-sede__cosecha-hint {
  color: #7e22ce;
  font-weight: 600;
}

/* Salas */
.agri-salas {
  display: flex;
  flex-direction: column;
  gap: .5rem;
}
.agri-sala {
  display: flex;
  flex-direction: column;
  gap: .5rem;
  padding: .875rem 1rem;
  background: #f8fafc;
  border: 1px solid #e9ecef;
  border-radius: 10px;
  text-decoration: none;
  color: inherit;
  transition: all .15s;
  position: relative;
  cursor: pointer;
}
.agri-sala:hover {
  background: #f1f5f9;
  border-color: var(--brand-accent, #66bb6a);
  box-shadow: 0 2px 8px rgba(0,0,0,.05);
}
.agri-sala--con-lotes {
  border-left: 3px solid var(--brand-accent, #66bb6a);
}
.agri-sala__head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: .75rem;
}
.agri-sala__name-wrap {
  display: flex;
  align-items: center;
  gap: .5rem;
  flex: 1;
  min-width: 0;
}
.agri-sala__indicator {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  flex-shrink: 0;
}
.agri-sala__indicator--on  { background: #16a34a; box-shadow: 0 0 0 2px rgba(22,163,74,.2); }
.agri-sala__indicator--off { background: #94a3b8; }
.agri-sala__nombre {
  font-size: .9rem;
  font-weight: 700;
  color: #0f172a;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.agri-sala__kind {
  font-size: .68rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: .05em;
  color: #94a3b8;
  background: #e2e8f0;
  padding: .1em .45em;
  border-radius: 4px;
}
.agri-sala__stats {
  display: flex;
  align-items: center;
  gap: .5rem;
  flex-shrink: 0;
}
.agri-sala__stat {
  display: inline-flex;
  align-items: center;
  gap: .25rem;
  font-size: .78rem;
  font-weight: 600;
  color: #475569;
}
.agri-sala__cap {
  font-size: .72rem;
  color: #94a3b8;
}
.agri-sala__empty {
  font-size: .75rem;
  color: #94a3b8;
  font-style: italic;
}
.agri-sala__arrow {
  position: absolute;
  right: 1rem;
  top: 50%;
  transform: translateY(-50%);
  color: #cbd5e1;
  font-size: .85rem;
  transition: color .15s, transform .15s;
}
.agri-sala:hover .agri-sala__arrow {
  color: var(--brand-primary, #1b5e20);
  transform: translateY(-50%) translateX(2px);
}

/* Lote chips */
.agri-sala__lotes {
  display: flex;
  gap: .4rem;
  flex-wrap: wrap;
}
.agri-lote-chip {
  display: inline-flex;
  align-items: center;
  gap: .3rem;
  padding: .25em .6em;
  border-radius: 6px;
  font-size: .72rem;
  font-weight: 600;
  border: 1px solid;
}
.agri-lote-chip__dot {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  flex-shrink: 0;
}
.agri-lote-chip__strain {
  font-weight: 400;
  opacity: .8;
}
.agri-lote-chip__plants {
  opacity: .7;
  font-weight: 500;
}

/* Footer de sede */
.agri-sede__footer {
  display: flex;
  justify-content: flex-end;
  padding-top: .25rem;
  border-top: 1px solid #f1f5f9;
}
.agri-btn-ver {
  display: inline-flex;
  align-items: center;
  gap: .4rem;
  font-size: .8rem;
  font-weight: 600;
  color: var(--brand-primary, #1b5e20);
  text-decoration: none;
  padding: .35rem .6rem;
  border-radius: 6px;
  transition: background .15s;
}
.agri-btn-ver:hover {
  background: rgba(27,94,32,.06);
}

/* ══════════════════════════════════════════════════════════════
   VISTA ADMIN (sin cambios)
══════════════════════════════════════════════════════════════ */
.page-header { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; margin-bottom: 1.75rem; flex-wrap: wrap; }
.page-title  { font-size: 1.75rem; font-weight: 700; color: #0f172a; margin: 0 0 .25rem; letter-spacing: -.03em; }
.page-subtitle { font-size: .875rem; color: #64748b; margin: 0; display: flex; align-items: center; gap: .5rem; flex-wrap: wrap; }
.plan-badge { font-size: .7rem; font-weight: 600; padding: .2em .6em; border-radius: 999px; text-transform: uppercase; letter-spacing: .04em; }

.btn-primary-action { display: inline-flex; align-items: center; gap: .4rem; background: var(--brand-primary, #1b5e20); color: #fff; border: none; padding: .6rem 1.25rem; border-radius: 8px; font-size: .875rem; font-weight: 600; cursor: pointer; transition: background .15s, transform .1s; text-decoration: none; white-space: nowrap; }
.btn-primary-action:hover { background: #144a18; transform: translateY(-1px); }
.btn-primary-action--sm { padding: .45rem .9rem; font-size: .8rem; }
.btn-ghost { background: transparent; color: #64748b; border: 1px solid #e2e8f0; padding: .6rem 1.25rem; border-radius: 8px; font-size: .875rem; font-weight: 500; cursor: pointer; transition: all .15s; }
.btn-ghost:hover { background: #f8fafc; color: #0f172a; }
.btn-danger { background: #dc2626; color: #fff; border: none; padding: .6rem 1.25rem; border-radius: 8px; font-size: .875rem; font-weight: 600; cursor: pointer; transition: background .15s; }
.btn-danger:hover { background: #b91c1c; }

.plan-usage { background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 10px; padding: .75rem 1rem; margin-bottom: 1.5rem; }
.plan-usage__info { display: flex; justify-content: space-between; margin-bottom: .4rem; font-size: .8rem; }
.plan-usage__label { color: #64748b; }
.plan-usage__count { font-weight: 600; color: #0f172a; }
.plan-usage__bar { height: 4px; background: #e2e8f0; border-radius: 999px; overflow: hidden; }
.plan-usage__fill { height: 100%; background: #16a34a; border-radius: 999px; transition: width .4s ease; }
.plan-usage__fill--danger { background: #dc2626; }

.kpi-grid { display: grid; grid-template-columns: repeat(4,1fr); gap: 1rem; margin-bottom: 2rem; }
@media (max-width: 768px) { .kpi-grid { grid-template-columns: repeat(2,1fr); } }
.kpi-card { background: #fff; border: 1px solid #e2e8f0; border-radius: 12px; padding: 1.25rem; display: flex; align-items: center; gap: 1rem; }
.kpi-card__icon { width: 44px; height: 44px; border-radius: 10px; display: flex; align-items: center; justify-content: center; font-size: 1.25rem; flex-shrink: 0; }
.kpi-card__value { font-size: 1.75rem; font-weight: 700; color: #0f172a; line-height: 1; letter-spacing: -.03em; }
.kpi-card__label { font-size: .75rem; color: #94a3b8; margin-top: .2rem; font-weight: 500; text-transform: uppercase; letter-spacing: .04em; }

.loading-state { display: flex; align-items: center; justify-content: center; gap: .75rem; padding: 4rem; color: #94a3b8; font-size: .875rem; }
.empty-state { text-align: center; padding: 5rem 1rem; }
.empty-state--sm { padding: 2rem 1rem; }
.empty-state__icon { font-size: 3rem; margin-bottom: 1rem; }
.empty-state__title { font-size: 1.25rem; font-weight: 600; color: #0f172a; margin-bottom: .5rem; }
.empty-state__desc { color: #64748b; font-size: .875rem; margin-bottom: 1.5rem; }

.spinner { width: 20px; height: 20px; border: 2px solid rgba(255,255,255,.3); border-top-color: #fff; border-radius: 50%; animation: spin .6s linear infinite; flex-shrink: 0; }
.spinner--sm { width: 14px; height: 14px; }
@keyframes spin { to { transform: rotate(360deg); } }

.sedes-grid { display: grid; grid-template-columns: repeat(3,1fr); gap: 1.25rem; }
@media (max-width: 1024px) { .sedes-grid { grid-template-columns: repeat(2,1fr); } }
@media (max-width: 640px)  { .sedes-grid { grid-template-columns: 1fr; } }

.sede-card { background: #fff; border: 1px solid #e2e8f0; border-radius: 14px; overflow: hidden; cursor: pointer; transition: box-shadow .2s, transform .15s; position: relative; display: flex; flex-direction: column; }
.sede-card:hover { box-shadow: 0 8px 32px rgba(0,0,0,.1); transform: translateY(-2px); }
.sede-card__accent { height: 3px; background: var(--tipo-color); }
.sede-card__content { padding: 1.25rem; flex: 1; display: flex; flex-direction: column; gap: .75rem; }
.sede-card__header { display: flex; align-items: flex-start; gap: .75rem; }
.sede-card__tipo-icon { width: 40px; height: 40px; border-radius: 10px; background: var(--tipo-bg); display: flex; align-items: center; justify-content: center; font-size: 1.1rem; flex-shrink: 0; color: var(--tipo-color); }
.sede-card__info { flex: 1; min-width: 0; }
.sede-card__nombre { font-size: 1rem; font-weight: 700; color: #0f172a; margin: 0 0 .15rem; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.sede-card__tipo-label { font-size: .72rem; font-weight: 600; text-transform: uppercase; letter-spacing: .05em; }
.reprocann-badge { background: #dcfce7; color: #15803d; font-size: .65rem; font-weight: 700; padding: .2em .55em; border-radius: 6px; text-transform: uppercase; letter-spacing: .05em; white-space: nowrap; flex-shrink: 0; }
.sede-card__direccion { font-size: .8rem; color: #64748b; margin: 0; display: flex; align-items: flex-start; gap: .3rem; line-height: 1.4; }
.sede-card__stats { display: flex; gap: 1.25rem; padding: .6rem .75rem; background: #f8fafc; border-radius: 8px; }
.sede-card__stat { display: flex; align-items: baseline; gap: .3rem; }
.sede-card__stat-value { font-size: 1.1rem; font-weight: 700; color: #0f172a; }
.sede-card__stat-label { font-size: .72rem; color: #94a3b8; font-weight: 500; }
.sede-card__actions { display: flex; gap: .5rem; align-items: center; flex-wrap: wrap; margin-top: auto; }
.sede-card__btn { display: inline-flex; align-items: center; gap: .35rem; padding: .45rem .8rem; border-radius: 7px; font-size: .78rem; font-weight: 600; cursor: pointer; border: none; transition: all .15s; text-decoration: none; white-space: nowrap; }
.sede-card__btn--primary { background: var(--brand-primary, #1b5e20); color: #fff; margin-left: auto; }
.sede-card__btn--primary:hover { background: #144a18; }
.sede-card__btn--secondary { background: #eff6ff; color: #1d4ed8; }
.sede-card__btn--secondary:hover { background: #dbeafe; }
.sede-card__btn--ghost { background: #f1f5f9; color: #475569; }
.sede-card__btn--ghost:hover { background: #e2e8f0; color: #0f172a; }
.sede-card__btn--danger { background: #fef2f2; color: #dc2626; }
.sede-card__btn--danger:hover { background: #fee2e2; }

/* Modals */
.modal-overlay { position: fixed; inset: 0; background: rgba(0,0,0,.45); display: flex; align-items: center; justify-content: center; z-index: 1050; padding: 1rem; backdrop-filter: blur(2px); }
.modal-overlay--top { z-index: 1060; }
.modal-panel { background: #fff; border-radius: 16px; width: 100%; max-height: 90vh; overflow-y: auto; display: flex; flex-direction: column; box-shadow: 0 24px 64px rgba(0,0,0,.15); }
.modal-panel--sm { max-width: 440px; }
.modal-panel--lg { max-width: 680px; }
.modal-panel--center { align-items: center; padding: 2rem; }
.modal-panel__header { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; padding: 1.5rem 1.5rem 1rem; border-bottom: 1px solid #f1f5f9; }
.modal-panel__title { font-size: 1.15rem; font-weight: 700; color: #0f172a; margin: 0; }
.modal-panel__title--danger { color: #dc2626; }
.modal-panel__subtitle { font-size: .8rem; color: #64748b; margin: .2rem 0 0; }
.modal-panel__close { background: #f1f5f9; border: none; width: 32px; height: 32px; border-radius: 8px; cursor: pointer; display: flex; align-items: center; justify-content: center; color: #64748b; flex-shrink: 0; transition: all .15s; }
.modal-panel__close:hover { background: #e2e8f0; color: #0f172a; }
.modal-panel__close--abs { position: absolute; top: 1rem; right: 1rem; }
.modal-panel__body { padding: 1.25rem 1.5rem; flex: 1; }
.modal-panel__footer { display: flex; justify-content: flex-end; gap: .75rem; padding: 1rem 1.5rem; border-top: 1px solid #f1f5f9; }

.form-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; }
@media (max-width: 540px) { .form-grid { grid-template-columns: 1fr; } }
.form-group { display: flex; flex-direction: column; gap: .4rem; }
.form-group--full { grid-column: 1 / -1; }
.form-label { font-size: .8rem; font-weight: 600; color: #374151; }
.required { color: #dc2626; }
.form-input { background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 8px; padding: .6rem .85rem; font-size: .875rem; color: #0f172a; transition: border .15s, box-shadow .15s; width: 100%; box-sizing: border-box; }
.form-input:focus { outline: none; border-color: #1b5e20; box-shadow: 0 0 0 3px rgba(27,94,32,.1); background: #fff; }
.form-input--error { border-color: #dc2626; }
.form-textarea { resize: vertical; min-height: 70px; }
.form-error { font-size: .75rem; color: #dc2626; }
.form-alert { background: #fef2f2; border: 1px solid #fecaca; color: #dc2626; padding: .75rem 1rem; border-radius: 8px; font-size: .85rem; margin-bottom: 1rem; display: flex; gap: .5rem; align-items: flex-start; }
.tipo-selector { display: flex; gap: .5rem; flex-wrap: wrap; }
.tipo-btn { flex: 1; min-width: 100px; padding: .55rem .75rem; border-radius: 8px; border: 1.5px solid #e2e8f0; background: #f8fafc; color: #475569; font-size: .8rem; font-weight: 600; cursor: pointer; transition: all .15s; display: inline-flex; align-items: center; gap: .35rem; justify-content: center; }
.tipo-btn:hover { border-color: #94a3b8; background: #f1f5f9; }
.form-toggle { display: flex; align-items: center; gap: .75rem; cursor: pointer; }
.form-toggle__input { display: none; }
.form-toggle__track { width: 40px; height: 22px; background: #e2e8f0; border-radius: 999px; position: relative; transition: background .2s; flex-shrink: 0; }
.form-toggle__input:checked + .form-toggle__track { background: var(--brand-primary, #1b5e20); }
.form-toggle__thumb { position: absolute; width: 16px; height: 16px; background: #fff; border-radius: 50%; top: 3px; left: 3px; transition: left .2s; box-shadow: 0 1px 3px rgba(0,0,0,.2); }
.form-toggle__input:checked + .form-toggle__track .form-toggle__thumb { left: 21px; }
.form-toggle__label { font-size: .875rem; font-weight: 600; color: #0f172a; }
.form-toggle__hint { font-size: .75rem; color: #94a3b8; }

.inv-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(180px, 1fr)); gap: 1rem; }
.inv-card { background: #fff; border: 1.5px solid #e2e8f0; border-radius: 12px; padding: 1.1rem; display: flex; flex-direction: column; gap: .5rem; transition: box-shadow .15s; }
.inv-card:hover { box-shadow: 0 4px 16px rgba(0,0,0,.07); }
.inv-card--low { border-color: #fca5a5; background: #fff5f5; }
.inv-card--ok  { border-color: #bbf7d0; }
.inv-card__header { display: flex; align-items: center; justify-content: space-between; margin-bottom: .25rem; }
.inv-card__producto-icon { width: 32px; height: 32px; border-radius: 8px; background: #f1f5f9; display: flex; align-items: center; justify-content: center; color: #475569; font-size: .9rem; }
.inv-card--low .inv-card__producto-icon { background: #fef2f2; color: #dc2626; }
.inv-card--ok  .inv-card__producto-icon { background: #f0fdf4; color: #15803d; }
.inv-card__badge { display: inline-flex; align-items: center; gap: .25rem; font-size: .65rem; font-weight: 700; padding: .2em .5em; border-radius: 5px; }
.inv-card__badge--warn { background: #fef2f2; color: #dc2626; }
.inv-card__badge--ok   { background: #f0fdf4; color: #15803d; }
.inv-card__producto { font-size: .72rem; color: #64748b; font-weight: 700; text-transform: uppercase; letter-spacing: .05em; }
.inv-card__stock { font-size: 2rem; font-weight: 800; color: #0f172a; line-height: 1; letter-spacing: -.04em; }
.inv-card__unit { font-size: 1rem; font-weight: 500; color: #94a3b8; }
.inv-card__bar-wrap { height: 4px; background: #f1f5f9; border-radius: 999px; overflow: hidden; }
.inv-card__bar { height: 100%; border-radius: 999px; transition: width .4s; }
.inv-card__bar--ok  { background: #15803d; }
.inv-card__bar--low { background: #dc2626; }
.inv-card__meta { display: flex; justify-content: space-between; font-size: .68rem; color: #94a3b8; margin-top: .1rem; }

.upgrade-body { text-align: center; padding: 1rem; }
.upgrade-icon { font-size: 3rem; margin-bottom: 1rem; }
.upgrade-title { font-size: 1.25rem; font-weight: 700; color: #0f172a; margin-bottom: .5rem; }
.upgrade-desc { color: #64748b; font-size: .875rem; margin-bottom: 1.5rem; }
.text-muted-sm { font-size: .85rem; color: #64748b; margin-top: .25rem; }

.stock-productos { display: flex; flex-wrap: wrap; gap: .4rem; }
.stock-producto-btn { display: inline-flex; align-items: center; gap: .35rem; padding: .45rem .8rem; border: 1.5px solid #e2e8f0; border-radius: 8px; background: #f8fafc; color: #475569; font-size: .78rem; font-weight: 600; cursor: pointer; transition: all .15s; }
.stock-producto-btn:hover { border-color: #94a3b8; background: #f1f5f9; }
.stock-producto-btn--active { border-color: var(--brand-primary, #1b5e20); background: rgba(27,94,32,.08); color: var(--brand-primary, #1b5e20); }
.stock-unidad-badge { display: inline-block; background: #f1f5f9; color: #475569; font-size: .68rem; font-weight: 700; padding: .15em .5em; border-radius: 5px; margin-left: .4rem; text-transform: uppercase; }
.stock-cantidad-wrap { display: flex; align-items: center; gap: 0; }
.stock-cantidad-input { border-radius: 9px 0 0 9px !important; }
.stock-cantidad-suffix { background: #f1f5f9; border: 1.5px solid #e2e8f0; border-left: none; border-radius: 0 9px 9px 0; padding: .65rem .875rem; font-size: .875rem; font-weight: 700; color: #475569; white-space: nowrap; }
.form-hint { font-size: .72rem; color: #94a3b8; margin-top: .1rem; }
</style>
