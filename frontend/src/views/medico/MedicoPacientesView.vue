<template>
  <div class="mpv">

    <!-- Header -->
    <div class="mpv__header">
      <div>
        <h1 class="mpv__title">Mis Pacientes</h1>
        <p class="mpv__sub">Pacientes con seguimiento médico asignado</p>
      </div>
      <button class="mpv__btn-primary" @click="openNew">
        <UserPlus :size="15" :stroke-width="1.75" /> Nuevo Paciente
      </button>
    </div>

    <!-- KPI filtros -->
    <div class="mpv__kpis">
      <button class="mpv__kpi" :class="{ 'mpv__kpi--active': filtro === 'todos' }" @click="cambiarFiltro('todos')">
        <div class="mpv__kpi-val">{{ kpis.total }}</div>
        <div class="mpv__kpi-lbl">Total</div>
      </button>
      <button class="mpv__kpi mpv__kpi--ok" :class="{ 'mpv__kpi--active': filtro === 'activos' }" @click="cambiarFiltro('activos')">
        <div class="mpv__kpi-val">{{ kpis.activos }}</div>
        <div class="mpv__kpi-lbl">En tratamiento</div>
      </button>
      <button class="mpv__kpi mpv__kpi--warn" :class="{ 'mpv__kpi--active': filtro === 'proximos' }" @click="cambiarFiltro('proximos')">
        <div class="mpv__kpi-val">{{ kpis.proximos }}</div>
        <div class="mpv__kpi-lbl">REPROCANN ≤30d</div>
      </button>
      <button class="mpv__kpi mpv__kpi--danger" :class="{ 'mpv__kpi--active': filtro === 'vencidos' }" @click="cambiarFiltro('vencidos')">
        <div class="mpv__kpi-val">{{ kpis.vencidos }}</div>
        <div class="mpv__kpi-lbl">REPROCANN vencido</div>
      </button>
      <button class="mpv__kpi mpv__kpi--gray" :class="{ 'mpv__kpi--active': filtro === 'sin_rep' }" @click="cambiarFiltro('sin_rep')">
        <div class="mpv__kpi-val">{{ kpis.sin_rep }}</div>
        <div class="mpv__kpi-lbl">Sin REPROCANN</div>
      </button>
    </div>

    <!-- Toolbar búsqueda -->
    <div class="mpv__toolbar">
      <div class="mpv__search-wrap">
        <Search :size="16" class="mpv__search-icon" />
        <input
          v-model="search"
          @input="onSearch"
          class="mpv__search"
          placeholder="Buscar por nombre, apellido o DNI…"
        />
        <span v-if="meta" class="mpv__search-count">{{ meta.total }}</span>
      </div>
    </div>

    <!-- Loading -->
    <div v-if="loading && !pacientes.length" class="mpv__loading">
      <DsSpinner :size="20" /> Cargando pacientes…
    </div>

    <!-- Empty -->
    <div v-else-if="!pacientes.length" class="mpv__empty">
      <Users :size="40" :stroke-width="1" />
      <p>{{ search ? 'Sin resultados para tu búsqueda' : filtro !== 'todos' ? 'No hay pacientes en este filtro' : 'No tenés pacientes cargados todavía' }}</p>
      <button v-if="!search && filtro === 'todos'" class="mpv__btn-primary" @click="openNew">
        <UserPlus :size="15" /> Agregar primer paciente
      </button>
    </div>

    <!-- Lista -->
    <div v-else class="mpv__list">
      <RouterLink
        v-for="p in pacientes"
        :key="p.id"
        :to="`/medico/pacientes/${p.id}`"
        class="mpv__row"
        :class="{
          'mpv__row--danger':  reproStatus(p)?.level === 'danger',
          'mpv__row--warning': reproStatus(p)?.level === 'warning',
        }"
      >
        <div class="mpv__ind"
          :class="{
            'mpv__ind--danger':  reproStatus(p)?.level === 'danger',
            'mpv__ind--warning': reproStatus(p)?.level === 'warning',
            'mpv__ind--caution': reproStatus(p)?.level === 'caution',
            'mpv__ind--ok':      reproStatus(p)?.level === 'ok',
          }"
        ></div>

        <div class="mpv__avatar" :class="{ 'mpv__avatar--inactive': p.es_paciente === false }">
          {{ iniciales(p) }}
        </div>

        <div class="mpv__info">
          <div class="mpv__nombre">{{ p.nombre }} {{ p.apellido }}</div>
          <div class="mpv__meta">
            <span class="mpv__dni">{{ p.dni }}</span>
            <span v-if="edad(p.fecha_nacimiento)" class="mpv__edad">{{ edad(p.fecha_nacimiento) }} años</span>
            <span v-if="p.email" class="mpv__email">{{ p.email }}</span>
          </div>
          <div v-if="motivo(p)" class="mpv__motivo" :class="`mpv__motivo--${motivo(p).tipo}`">
            {{ motivo(p).texto }}
          </div>
        </div>

        <div class="mpv__repro">
          <template v-if="reproStatus(p)">
            <div class="mpv__rep-badge"
              :class="{
                'mpv__rep-badge--danger':  reproStatus(p)?.level === 'danger',
                'mpv__rep-badge--warning': reproStatus(p)?.level === 'warning',
                'mpv__rep-badge--caution': reproStatus(p)?.level === 'caution',
                'mpv__rep-badge--ok':      reproStatus(p)?.level === 'ok',
              }"
            >{{ reproStatus(p)?.label }}</div>
            <div class="mpv__rep-fecha">{{ formatDate(p.reprocann_vencimiento) }}</div>
          </template>
          <span v-else class="mpv__rep-none">Sin REPROCANN</span>
        </div>

        <!-- La fila entera ya abre la ficha: no hace falta un botón que lleve al mismo lado. -->
        <div class="mpv__actions" @click.prevent>
          <button
            class="mpv__action-btn mpv__action-btn--danger"
            @click.prevent="openDelete(p)"
            title="Eliminar paciente"
          >
            <Trash2 :size="14" />
          </button>
        </div>
      </RouterLink>

      <div v-if="hayMas" class="mpv__mas">
        <button class="mpv__btn-mas" :disabled="loading" @click="cargarMas">
          <DsSpinner v-if="loading" :size="14" />
          <template v-else>Cargar más ({{ pacientes.length }} de {{ meta.total }})</template>
        </button>
      </div>
    </div>

    <!-- Modal: Nuevo Paciente -->
    <Teleport to="body">
      <div v-if="showModal" class="mpv__overlay" @click.self="showModal = false">
        <div class="mpv__modal">
          <div class="mpv__modal-header">
            <h2 class="mpv__modal-title">Nuevo Paciente</h2>
            <button class="mpv__modal-close" @click="showModal = false"><X :size="18" /></button>
          </div>
          <div class="mpv__modal-body">
            <div v-if="formError" class="mpv__form-error">{{ formError }}</div>
            <div class="mpv__form-grid">
              <div class="mpv__form-field" :class="{ 'mpv__form-field--error': formErrors.nombre }">
                <label>Nombre <span class="mpv__req">*</span></label>
                <input v-model="form.nombre" type="text" placeholder="Juan" />
                <span v-if="formErrors.nombre" class="mpv__field-err">{{ formErrors.nombre }}</span>
              </div>
              <div class="mpv__form-field" :class="{ 'mpv__form-field--error': formErrors.apellido }">
                <label>Apellido <span class="mpv__req">*</span></label>
                <input v-model="form.apellido" type="text" placeholder="García" />
                <span v-if="formErrors.apellido" class="mpv__field-err">{{ formErrors.apellido }}</span>
              </div>
              <div class="mpv__form-field" :class="{ 'mpv__form-field--error': formErrors.dni }">
                <label>DNI <span class="mpv__req">*</span></label>
                <input v-model="form.dni" type="text" placeholder="12345678" />
                <span v-if="formErrors.dni" class="mpv__field-err">{{ formErrors.dni }}</span>
              </div>
              <div class="mpv__form-field" :class="{ 'mpv__form-field--error': formErrors.fecha_nacimiento }">
                <label>Fecha de nacimiento <span class="mpv__req">*</span></label>
                <AppDatePicker v-model="form.fecha_nacimiento" />
                <span v-if="formErrors.fecha_nacimiento" class="mpv__field-err">{{ formErrors.fecha_nacimiento }}</span>
              </div>
              <div class="mpv__form-field">
                <label>Email</label>
                <input v-model="form.email" type="email" placeholder="juan@email.com" />
              </div>
              <div class="mpv__form-field">
                <label>Teléfono</label>
                <input v-model="form.telefono" type="text" placeholder="+54 9 11 ..." />
              </div>
              <div class="mpv__form-field">
                <label>Nº REPROCANN</label>
                <input v-model="form.reprocann_numero" type="text" placeholder="Número de registro" />
              </div>
              <div class="mpv__form-field">
                <label>Vencimiento REPROCANN</label>
                <AppDatePicker v-model="form.reprocann_vencimiento" />
              </div>
              <div class="mpv__form-field mpv__form-field--full">
                <label>Estado REPROCANN</label>
                <select v-model="form.reprocann_estado">
                  <option value="sin_registro">Sin registro</option>
                  <option value="pendiente">Pendiente aprobación</option>
                  <option value="activo">Activo</option>
                  <option value="inactivo">Inactivo</option>
                </select>
              </div>
            </div>
          </div>
          <div class="mpv__modal-footer">
            <button class="mpv__btn-ghost" @click="showModal = false">Cancelar</button>
            <button class="mpv__btn-primary" @click="save" :disabled="store.saving">
              {{ store.saving ? 'Guardando…' : 'Guardar paciente' }}
            </button>
          </div>
        </div>
      </div>
    </Teleport>

  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import AppDatePicker from '../../components/ui/AppDatePicker.vue'
import { useRouter } from 'vue-router'
import { Search, UserPlus, Users, Trash2, X } from 'lucide-vue-next'
import { usePacientesStore } from '../../stores/pacientes.js'
import { useConfirm } from '../../composables/useConfirm.js'
import { useToast } from '../../composables/useToast.js'
import { getMedicoPacientes } from '../../lib/api.js'
import { logger } from '../../utils/logger.js'
import DsSpinner from '../../design-system/components/Spinner.vue'

const LIMITE = 30

const store  = usePacientesStore()
const router = useRouter()
const { confirm } = useConfirm()
const { success: toastOk, error: toastErr } = useToast()

const pacientes = ref([])
const meta      = ref(null)
const pagina    = ref(1)
const loading   = ref(false)
const search    = ref('')
const filtro    = ref('todos')
const showModal = ref(false)
const formError  = ref(null)
const formErrors = ref({})

function emptyForm() {
  return {
    nombre: '', apellido: '', dni: '', fecha_nacimiento: '',
    email: '', telefono: '', reprocann_numero: '',
    reprocann_vencimiento: '', reprocann_estado: 'sin_registro',
    con_seguimiento_medico: true, es_paciente: true,
  }
}
const form = ref(emptyForm())

function openNew() {
  form.value      = emptyForm()
  formErrors.value = {}
  formError.value  = null
  showModal.value  = true
}

function validate() {
  const e = {}
  if (!form.value.nombre.trim())    e.nombre = 'Obligatorio'
  if (!form.value.apellido.trim())  e.apellido = 'Obligatorio'
  if (!form.value.dni.trim())       e.dni = 'Obligatorio'
  if (!form.value.fecha_nacimiento) e.fecha_nacimiento = 'Obligatorio'
  formErrors.value = e
  return !Object.keys(e).length
}

async function save() {
  if (!validate()) return
  formError.value = null
  const payload = { ...form.value }
  Object.keys(payload).forEach(k => { if (payload[k] === '') delete payload[k] })
  try {
    await store.create(payload)
    await cargar({ reset: true })
    showModal.value = false
    toastOk('Paciente creado correctamente')
  } catch {
    formError.value = store.error || 'Error al guardar. Verificá los datos.'
  }
}

async function openDelete(p) {
  const ok = await confirm({
    title: 'Eliminar paciente',
    message: `¿Eliminar a ${p.nombre} ${p.apellido}? Se eliminará su historial. Esta acción no se puede deshacer.`,
    confirmText: 'Eliminar',
    variant: 'danger',
  })
  if (!ok) return
  try {
    await store.remove(p.id)
    await cargar({ reset: true })
    toastOk('Paciente eliminado')
  } catch {
    toastErr('No se pudo eliminar el paciente')
  }
}

let searchTimer = null
function onSearch() {
  clearTimeout(searchTimer)
  searchTimer = setTimeout(() => cargar({ reset: true }), 400)
}

// Una sola fuente de verdad: el backend filtra, ordena, cuenta y pagina. Antes la lista se
// filtraba dos veces (server-side con ?query y otra vez en el cliente) sobre un JSON que traía
// TODOS los pacientes del club.
async function cargar({ reset = false } = {}) {
  if (reset) pagina.value = 1
  loading.value = true
  try {
    const { data } = await getMedicoPacientes({
      pagina: pagina.value,
      limite: LIMITE,
      query:  search.value.trim() || undefined,
      filtro: filtro.value,
    })
    const nuevos = data.data || []
    pacientes.value = reset ? nuevos : [...pacientes.value, ...nuevos]
    meta.value = data.meta || null
  } catch (e) {
    logger.error('MedicoPacientes:', e)
    toastErr('No se pudieron cargar los pacientes')
  } finally {
    loading.value = false
  }
}

function cambiarFiltro(f) {
  filtro.value = f
  cargar({ reset: true })
}

function cargarMas() {
  pagina.value += 1
  cargar()
}

function safeDate(d) {
  if (!d) return null
  return /^\d{4}-\d{2}-\d{2}$/.test(d) ? new Date(d + 'T00:00:00') : new Date(d)
}
function reproDias(p) {
  if (!p.reprocann_vencimiento) return null
  return Math.floor((safeDate(p.reprocann_vencimiento) - new Date()) / 86400000)
}
function reproStatus(p) {
  const d = reproDias(p)
  if (d === null) return null
  if (d < 0)   return { label: 'Vencido',  level: 'danger'  }
  if (d <= 30) return { label: `${d}d`,    level: 'warning' }
  if (d <= 90) return { label: `${d}d`,    level: 'caution' }
  return               { label: 'Vigente', level: 'ok'      }
}
function formatDate(d) {
  if (!d) return '—'
  return safeDate(d).toLocaleDateString('es-AR', { day: 'numeric', month: 'short', year: 'numeric' })
}
function edad(fn) {
  if (!fn) return null
  return Math.floor((Date.now() - safeDate(fn).getTime()) / (1000 * 60 * 60 * 24 * 365.25))
}
function iniciales(p) {
  return ((p.nombre?.[0] || '') + (p.apellido?.[0] || '')).toUpperCase()
}

const kpis = computed(() => meta.value?.kpis || { total: 0, activos: 0, proximos: 0, vencidos: 0, sin_rep: 0 })
const hayMas = computed(() => !!meta.value && pacientes.value.length < meta.value.total)

// Lo que puso a este paciente arriba en la lista, dicho en la fila.
function motivo(p) {
  if (p.proximo_turno_at) {
    return { texto: `Turno ${formatDate(p.proximo_turno_at)}`, tipo: 'turno' }
  }
  if (p.indicacion_vence_at) {
    const d = Math.floor((safeDate(p.indicacion_vence_at) - new Date()) / 86400000)
    if (d <= 30) return { texto: `Indicación vence en ${d}d`, tipo: 'indicacion' }
  }
  return null
}

onMounted(() => cargar({ reset: true }))
</script>

<style scoped>
.mpv { padding: var(--sp-6); max-width: 900px; }

/* Header */
.mpv__header {
  display: flex; align-items: flex-start; justify-content: space-between;
  gap: var(--sp-4); margin-bottom: var(--sp-5); flex-wrap: wrap;
}
.mpv__title { font-size: var(--fs-24); font-weight: 800; color: var(--c-ink-900); margin: 0 0 var(--sp-1); }
.mpv__sub   { color: var(--c-ink-500); font-size: var(--fs-14); margin: 0; }

/* Botones */
.mpv__btn-primary {
  display: inline-flex; align-items: center; gap: var(--sp-2);
  background: #2D8A6B; color: #fff; border: none; border-radius: var(--r-md);
  padding: var(--sp-2) var(--sp-4); font-size: var(--fs-13); font-weight: 600;
  cursor: pointer; transition: background .15s; text-decoration: none;
}
.mpv__btn-primary:hover { background: #236e55; }
.mpv__btn-primary:disabled { opacity: .6; cursor: default; }
.mpv__btn-ghost {
  background: none; border: 1px solid var(--c-ink-200); color: var(--c-ink-600);
  border-radius: var(--r-md); padding: var(--sp-2) var(--sp-4); font-size: var(--fs-13);
  cursor: pointer; transition: all .15s;
}
.mpv__btn-ghost:hover { background: var(--c-ink-50); }

/* KPIs */
.mpv__kpis {
  display: flex; gap: var(--sp-3); flex-wrap: wrap; margin-bottom: var(--sp-5);
}
.mpv__kpi {
  display: flex; flex-direction: column; align-items: center;
  background: var(--c-paper); border: 1px solid var(--c-ink-100); border-radius: var(--r-lg);
  padding: var(--sp-3) var(--sp-5); cursor: pointer; transition: all .15s;
  min-width: 90px; text-align: center;
}
.mpv__kpi:hover   { border-color: var(--c-ink-300); }
.mpv__kpi--active { border-color: #2D8A6B; background: rgba(45,138,107,.06); }
.mpv__kpi--ok.mpv__kpi--active     { border-color: #15803d; background: rgba(21,128,61,.06); }
.mpv__kpi--warn.mpv__kpi--active   { border-color: #d97706; background: rgba(217,119,6,.06); }
.mpv__kpi--danger.mpv__kpi--active { border-color: #dc2626; background: rgba(220,38,38,.06); }
.mpv__kpi--gray.mpv__kpi--active   { border-color: var(--c-ink-400); background: var(--c-ink-50); }
.mpv__kpi-val { font-size: var(--fs-20); font-weight: 800; color: var(--c-ink-900); line-height: 1; }
.mpv__kpi-lbl { font-size: var(--fs-11); color: var(--c-ink-500); margin-top: 2px; }
.mpv__kpi--ok     .mpv__kpi-val { color: #15803d; }
.mpv__kpi--warn   .mpv__kpi-val { color: #d97706; }
.mpv__kpi--danger .mpv__kpi-val { color: #dc2626; }
.mpv__kpi--gray   .mpv__kpi-val { color: var(--c-ink-500); }

/* Toolbar */
.mpv__toolbar { margin-bottom: var(--sp-4); }
.mpv__search-wrap {
  position: relative; display: flex; align-items: center; max-width: 420px;
}
.mpv__search-icon { position: absolute; left: var(--sp-3); color: var(--c-ink-400); pointer-events: none; }
.mpv__search {
  width: 100%; padding: var(--sp-2) var(--sp-3) var(--sp-2) calc(var(--sp-3) + 20px + var(--sp-2));
  background: var(--c-paper); border: 1px solid var(--c-ink-200); border-radius: var(--r-md);
  font-size: var(--fs-14); color: var(--c-ink-800); outline: none;
  transition: border-color .15s;
}
.mpv__search:focus { border-color: #2D8A6B; }
.mpv__search-count {
  position: absolute; right: var(--sp-3); font-size: var(--fs-12);
  color: var(--c-ink-400); pointer-events: none;
}

/* Loading */
.mpv__loading {
  display: flex; align-items: center; gap: var(--sp-3);
  color: var(--c-ink-500); padding: var(--sp-8); font-size: var(--fs-14);
}

/* Empty */
.mpv__empty {
  display: flex; flex-direction: column; align-items: center; gap: var(--sp-3);
  padding: var(--sp-12) var(--sp-6); color: var(--c-ink-300); text-align: center;
}
.mpv__empty p { font-size: var(--fs-14); color: var(--c-ink-500); margin: 0; }

/* Lista */
.mpv__list { display: flex; flex-direction: column; gap: 2px; }
.mpv__row {
  display: flex; align-items: center; gap: var(--sp-3);
  background: var(--c-paper); border: 1px solid var(--c-ink-100); border-radius: var(--r-lg);
  padding: var(--sp-3) var(--sp-4); text-decoration: none; color: inherit;
  transition: border-color .15s, box-shadow .15s; cursor: pointer;
  position: relative; overflow: hidden;
}
.mpv__row:hover { border-color: #2D8A6B; box-shadow: 0 1px 4px rgba(45,138,107,.08); }
.mpv__row--danger  { background: rgba(220,38,38,.02); }
.mpv__row--warning { background: rgba(217,119,6,.02);  }

.mpv__ind {
  width: 4px; height: 40px; border-radius: 2px; flex-shrink: 0;
  background: var(--c-ink-100);
}
.mpv__ind--ok      { background: #15803d; }
.mpv__ind--caution { background: #65a30d; }
.mpv__ind--warning { background: #d97706; }
.mpv__ind--danger  { background: #dc2626; }

.mpv__avatar {
  width: 40px; height: 40px; border-radius: 50%; background: var(--c-leaf-800); color: #fff;
  display: flex; align-items: center; justify-content: center;
  font-size: var(--fs-13); font-weight: 700; flex-shrink: 0;
}
.mpv__avatar--inactive { background: var(--c-ink-300); }

.mpv__info { flex: 1; min-width: 0; }
.mpv__nombre { font-size: var(--fs-14); font-weight: 600; color: var(--c-ink-900); }
.mpv__meta   { display: flex; gap: var(--sp-3); margin-top: 1px; flex-wrap: wrap; }
.mpv__dni    { font-size: var(--fs-12); color: var(--c-ink-500); font-variant-numeric: tabular-nums; }
.mpv__edad   { font-size: var(--fs-12); color: var(--c-ink-400); }
.mpv__email  { font-size: var(--fs-12); color: var(--c-ink-400); }

/* Por qué este paciente está arriba en la lista */
.mpv__motivo {
  display: inline-block; margin-top: var(--sp-1);
  font-size: var(--fs-12); font-weight: 600;
  padding: .1em .6em; border-radius: var(--r-pill);
}
.mpv__motivo--turno      { background: var(--c-sky-100);  color: var(--c-sky-600); }
.mpv__motivo--indicacion { background: var(--c-amber-100); color: var(--c-amber-500); }

/* Paginación */
.mpv__mas { display: flex; justify-content: center; padding: var(--sp-5) 0 var(--sp-2); }
.mpv__btn-mas {
  display: inline-flex; align-items: center; gap: var(--sp-2);
  padding: var(--sp-2) var(--sp-5);
  background: #fff; border: 1px solid var(--c-ink-300); border-radius: var(--r-lg);
  font-family: var(--font-ui); font-size: var(--fs-13); font-weight: 600; color: var(--c-ink-700);
  cursor: pointer; transition: all var(--t-base);
}
.mpv__btn-mas:hover:not(:disabled) { border-color: var(--c-leaf-500); color: var(--c-leaf-800); background: var(--c-leaf-50); }
.mpv__btn-mas:disabled { opacity: .55; cursor: not-allowed; }

.mpv__repro { text-align: right; flex-shrink: 0; min-width: 90px; }
.mpv__rep-badge {
  display: inline-block; padding: 2px 8px; border-radius: 999px;
  font-size: var(--fs-11); font-weight: 600;
}
.mpv__rep-badge--ok      { background: rgba(21,128,61,.1);   color: #15803d; }
.mpv__rep-badge--caution { background: rgba(101,163,13,.1);  color: #4d7c0f; }
.mpv__rep-badge--warning { background: rgba(217,119,6,.1);   color: #d97706; }
.mpv__rep-badge--danger  { background: rgba(220,38,38,.1);   color: #dc2626; }
.mpv__rep-fecha { font-size: var(--fs-11); color: var(--c-ink-400); margin-top: 2px; }
.mpv__rep-none  { font-size: var(--fs-12); color: var(--c-ink-300); }

.mpv__actions { display: flex; gap: var(--sp-1); align-items: center; flex-shrink: 0; opacity: 0; transition: opacity .15s; }
.mpv__row:hover .mpv__actions { opacity: 1; }
.mpv__action-btn {
  width: 30px; height: 30px; border-radius: var(--r-sm); border: none;
  display: flex; align-items: center; justify-content: center; cursor: pointer; transition: all .15s;
  background: transparent; color: var(--c-ink-400);
}
.mpv__action-btn:hover            { background: var(--c-ink-50); color: var(--c-ink-700); }
.mpv__action-btn--danger:hover    { background: rgba(220,38,38,.1); color: #dc2626; }

/* Modal */
.mpv__overlay {
  position: fixed; inset: 0; background: rgba(0,0,0,.4); z-index: 1000;
  display: flex; align-items: center; justify-content: center; padding: var(--sp-4);
}
.mpv__modal {
  background: var(--c-paper); border-radius: var(--r-xl); width: 100%; max-width: 560px;
  box-shadow: 0 20px 60px rgba(0,0,0,.2); display: flex; flex-direction: column;
  max-height: 90vh; overflow: hidden;
}
.mpv__modal-header {
  display: flex; align-items: center; justify-content: space-between;
  padding: var(--sp-5) var(--sp-6); border-bottom: 1px solid var(--c-ink-100);
}
.mpv__modal-title { font-size: var(--fs-16); font-weight: 700; color: var(--c-ink-900); margin: 0; }
.mpv__modal-close {
  background: none; border: none; color: var(--c-ink-400); cursor: pointer;
  display: flex; align-items: center; padding: var(--sp-1); border-radius: var(--r-sm);
}
.mpv__modal-close:hover { background: var(--c-ink-50); color: var(--c-ink-700); }
.mpv__modal-body { padding: var(--sp-5) var(--sp-6); overflow-y: auto; flex: 1; }
.mpv__modal-footer {
  display: flex; justify-content: flex-end; gap: var(--sp-3);
  padding: var(--sp-4) var(--sp-6); border-top: 1px solid var(--c-ink-100);
}

/* Formulario */
.mpv__form-error {
  background: rgba(220,38,38,.08); border: 1px solid rgba(220,38,38,.2);
  color: #dc2626; border-radius: var(--r-md); padding: var(--sp-3) var(--sp-4);
  font-size: var(--fs-13); margin-bottom: var(--sp-4);
}
.mpv__form-grid { display: grid; grid-template-columns: 1fr 1fr; gap: var(--sp-4); }
.mpv__form-field { display: flex; flex-direction: column; gap: var(--sp-1); }
.mpv__form-field--full { grid-column: 1 / -1; }
.mpv__form-field label { font-size: var(--fs-12); font-weight: 600; color: var(--c-ink-600); }
.mpv__req { color: #dc2626; }
.mpv__form-field input,
.mpv__form-field select {
  padding: var(--sp-2) var(--sp-3); background: var(--c-bg);
  border: 1px solid var(--c-ink-200); border-radius: var(--r-md);
  font-size: var(--fs-14); color: var(--c-ink-800); outline: none;
  transition: border-color .15s;
}
.mpv__form-field input:focus,
.mpv__form-field select:focus { border-color: #2D8A6B; }
.mpv__form-field--error input,
.mpv__form-field--error select { border-color: #dc2626; }
.mpv__field-err { font-size: var(--fs-11); color: #dc2626; }
</style>
