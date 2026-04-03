<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useSociosStore } from '../stores/socios'
import { useAuthStore } from '../stores/auth'

const store  = useSociosStore()
const auth   = useAuthStore()
const route  = useRoute()
const router = useRouter()

const canEdit = computed(() => ['admin', 'medico'].includes(auth.role))

const search       = ref('')
const searchTimer  = ref(null)
const showModal    = ref(false)
const showDelete   = ref(false)
const editing      = ref(false)
const deleteTarget = ref(null)
const formError    = ref(null)
const filterEstado = ref('todos')

function emptyForm() {
  return {
    id: null, nombre: '', apellido: '', dni: '',
    email: '', telefono: '', fecha_nacimiento: '',
    reprocann_numero: '', reprocann_vencimiento: '',
    es_paciente: true,
  }
}
const form       = ref(emptyForm())
const formErrors = ref({})

function validate() {
  const e = {}
  if (!form.value.nombre.trim())   e.nombre           = 'El nombre es obligatorio'
  if (!form.value.apellido.trim())  e.apellido          = 'El apellido es obligatorio'
  if (!form.value.dni.trim())       e.dni               = 'El DNI es obligatorio'
  if (!form.value.fecha_nacimiento) e.fecha_nacimiento  = 'La fecha de nacimiento es obligatoria'
  if (form.value.email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(form.value.email))
    e.email = 'Email inválido'
  formErrors.value = e
  return !Object.keys(e).length
}

function openEdit(s) {
  editing.value = true
  form.value = {
    id:                    s.id,
    nombre:                s.nombre     || '',
    apellido:              s.apellido   || '',
    dni:                   s.dni        || '',
    email:                 s.email      || '',
    telefono:              s.telefono   || '',
    fecha_nacimiento:      s.fecha_nacimiento?.toString().slice(0, 10) || '',
    reprocann_numero:      s.reprocann_numero      || '',
    reprocann_vencimiento: s.reprocann_vencimiento?.toString().slice(0, 10) || '',
    es_paciente:           s.es_paciente ?? true,
  }
  formErrors.value = {}
  formError.value  = null
  showModal.value  = true
}

function openDelete(s) {
  deleteTarget.value = s
  showDelete.value   = true
}

async function doSearch() {
  await store.fetch({ query: search.value.trim() })
}

function onSearchInput() {
  clearTimeout(searchTimer.value)
  searchTimer.value = setTimeout(doSearch, 400)
}

async function save() {
  if (!validate()) return
  formError.value = null
  try {
    const payload = { ...form.value }
    delete payload.id
    Object.keys(payload).forEach(k => { if (payload[k] === '') delete payload[k] })
    await store.update(form.value.id, payload)
    showModal.value = false
  } catch (e) {
    formError.value = store.error || 'Error al guardar'
  }
}

async function doDelete() {
  try {
    await store.remove(deleteTarget.value.id)
    showDelete.value = false
  } catch {
    showDelete.value = false
  }
}

function reprocannDias(s) {
  if (!s.reprocann_vencimiento) return null
  return Math.floor((new Date(s.reprocann_vencimiento) - new Date()) / 86400000)
}

function reprocannStatus(s) {
  const days = reprocannDias(s)
  if (days === null) return null
  if (days < 0)   return { label: 'Vencido',   level: 'danger',  days }
  if (days <= 30) return { label: `${days}d`,   level: 'warning', days }
  if (days <= 90) return { label: `${days}d`,   level: 'caution', days }
  return { label: 'Vigente', level: 'ok', days }
}

function formatDate(d) {
  if (!d) return '—'
  return new Date(d).toLocaleDateString('es-AR', { day: 'numeric', month: 'short', year: 'numeric' })
}

function edad(fn) {
  if (!fn) return null
  return Math.floor((Date.now() - new Date(fn).getTime()) / (1000 * 60 * 60 * 24 * 365.25))
}

function iniciales(s) {
  return ((s.nombre?.[0] || '') + (s.apellido?.[0] || '')).toUpperCase()
}

const kpis = computed(() => {
  const items = store.items
  const hoy   = new Date()
  const en30  = new Date(hoy.getTime() + 30 * 86400000)
  return {
    total:    items.length,
    activos:  items.filter(s => s.es_paciente).length,
    vencidos: items.filter(s => s.reprocann_vencimiento && new Date(s.reprocann_vencimiento) < hoy).length,
    proximos: items.filter(s => {
      if (!s.reprocann_vencimiento) return false
      const v = new Date(s.reprocann_vencimiento)
      return v >= hoy && v <= en30
    }).length,
  }
})

const filtrados = computed(() => {
  let list = store.items
  if (filterEstado.value === 'activos')  list = list.filter(s => s.es_paciente)
  if (filterEstado.value === 'vencidos') list = list.filter(s => reprocannDias(s) !== null && reprocannDias(s) < 0)
  if (filterEstado.value === 'proximos') list = list.filter(s => { const d = reprocannDias(s); return d !== null && d >= 0 && d <= 30 })
  if (filterEstado.value === 'sin_rep')  list = list.filter(s => !s.reprocann_vencimiento)
  return list
})

onMounted(async () => {
  await store.fetch()
  if (route.query.editar) {
    const s = store.items.find(x => String(x.id) === String(route.query.editar))
    if (s) openEdit(s)
  }
})
</script>

<template>
  <div class="sv">

    <!-- Header -->
    <div class="sv__header">
      <div>
        <h1 class="sv__title">Pacientes</h1>
        <p class="sv__sub">Trazabilidad clínica y gestión REPROCANN</p>
      </div>
      <button v-if="canEdit" class="sv__btn-primary" @click="router.push({ name: 'socio-nuevo' })">
        <i class="bi bi-person-plus"></i>
        Nuevo paciente
      </button>
    </div>

    <!-- KPIs como filtros -->
    <div class="sv__kpis">
      <button class="sv__kpi" :class="{ 'sv__kpi--active': filterEstado === 'todos' }" @click="filterEstado = 'todos'">
        <div class="sv__kpi-val">{{ kpis.total }}</div>
        <div class="sv__kpi-lbl">Total</div>
      </button>
      <button class="sv__kpi sv__kpi--ok" :class="{ 'sv__kpi--active': filterEstado === 'activos' }" @click="filterEstado = 'activos'">
        <div class="sv__kpi-val">{{ kpis.activos }}</div>
        <div class="sv__kpi-lbl">En tratamiento</div>
      </button>
      <button class="sv__kpi sv__kpi--warn" :class="{ 'sv__kpi--active': filterEstado === 'proximos' }" @click="filterEstado = 'proximos'">
        <div class="sv__kpi-val">{{ kpis.proximos }}</div>
        <div class="sv__kpi-lbl">Vencen en 30d</div>
      </button>
      <button class="sv__kpi sv__kpi--danger" :class="{ 'sv__kpi--active': filterEstado === 'vencidos' }" @click="filterEstado = 'vencidos'">
        <div class="sv__kpi-val">{{ kpis.vencidos }}</div>
        <div class="sv__kpi-lbl">REPROCANN vencido</div>
      </button>
    </div>

    <!-- Búsqueda -->
    <div class="sv__toolbar">
      <div class="sv__search-wrap">
        <i class="bi bi-search sv__search-icon"></i>
        <input
          v-model="search"
          @input="onSearchInput"
          class="sv__search"
          placeholder="Buscar por nombre, apellido, DNI…"
        />
        <span v-if="search" class="sv__search-count">{{ filtrados.length }}</span>
      </div>
    </div>

    <!-- Loading -->
    <div v-if="store.loading" class="sv__loading">
      <div class="sv__ring"></div>
      <span>Cargando pacientes…</span>
    </div>

    <!-- Empty -->
    <div v-else-if="!filtrados.length" class="sv__empty">
      <i class="bi bi-people sv__empty-icon"></i>
      <p class="sv__empty-title">{{ search || filterEstado !== 'todos' ? 'Sin resultados' : 'Sin pacientes registrados' }}</p>
      <p class="sv__empty-sub">{{ search ? 'Probá con otro término' : filterEstado !== 'todos' ? 'No hay pacientes en este filtro' : 'Registrá el primer paciente del club' }}</p>
      <button v-if="!search && canEdit && filterEstado === 'todos'" class="sv__btn-primary" @click="router.push({ name: 'socio-nuevo' })">
        <i class="bi bi-person-plus"></i> Nuevo paciente
      </button>
    </div>

    <!-- Lista -->
    <div v-else class="sv__list">
      <RouterLink
        v-for="s in filtrados"
        :key="s.id"
        :to="`/socios/${s.id}`"
        class="sv__row"
        :class="{
          'sv__row--danger':  reprocannStatus(s)?.level === 'danger',
          'sv__row--warning': reprocannStatus(s)?.level === 'warning',
        }"
      >
        <div class="sv__row-indicator"
             :class="{
            'sv__ind--danger':  reprocannStatus(s)?.level === 'danger',
            'sv__ind--warning': reprocannStatus(s)?.level === 'warning',
            'sv__ind--caution': reprocannStatus(s)?.level === 'caution',
            'sv__ind--ok':      reprocannStatus(s)?.level === 'ok',
            'sv__ind--none':    !reprocannStatus(s),
          }"
        ></div>

        <div class="sv__avatar" :class="{ 'sv__avatar--inactive': !s.es_paciente }">
          {{ iniciales(s) }}
        </div>

        <div class="sv__info">
          <div class="sv__nombre">{{ s.nombre }} {{ s.apellido }}</div>
          <div class="sv__meta">
            <span class="sv__dni">{{ s.dni }}</span>
            <span v-if="edad(s.fecha_nacimiento)" class="sv__edad">{{ edad(s.fecha_nacimiento) }} años</span>
            <span v-if="s.email" class="sv__email">{{ s.email }}</span>
          </div>
          <span v-if="!s.es_paciente" class="sv__inactivo">Inactivo</span>
        </div>

        <div class="sv__reprocann">
          <template v-if="s.reprocann_vencimiento">
            <div class="sv__rep-badge"
                 :class="{
                'sv__rep-badge--danger':  reprocannStatus(s)?.level === 'danger',
                'sv__rep-badge--warning': reprocannStatus(s)?.level === 'warning',
                'sv__rep-badge--caution': reprocannStatus(s)?.level === 'caution',
                'sv__rep-badge--ok':      reprocannStatus(s)?.level === 'ok',
              }"
            >{{ reprocannStatus(s)?.label }}</div>
            <div class="sv__rep-fecha">{{ formatDate(s.reprocann_vencimiento) }}</div>
            <div v-if="s.reprocann_numero" class="sv__rep-num">{{ s.reprocann_numero }}</div>
          </template>
          <div v-else class="sv__rep-none">Sin REPROCANN</div>
        </div>

        <div class="sv__actions" @click.prevent>
          <button v-if="canEdit" class="sv__action-btn" title="Editar" @click.prevent="openEdit(s)">
            <i class="bi bi-pencil"></i>
          </button>
          <button v-if="canEdit" class="sv__action-btn sv__action-btn--danger" title="Eliminar" @click.prevent="openDelete(s)">
            <i class="bi bi-trash"></i>
          </button>
          <div class="sv__action-arrow"><i class="bi bi-arrow-right"></i></div>
        </div>
      </RouterLink>
    </div>

    <div v-if="filtrados.length" class="sv__footer">
      {{ filtrados.length }} paciente{{ filtrados.length !== 1 ? 's' : '' }}
      <span v-if="filterEstado !== 'todos'"> · filtro activo</span>
    </div>

    <!-- Modal Editar -->
    <Teleport to="body">
      <div v-if="showModal" class="sp-overlay" @click.self="showModal=false">
        <div class="sp-modal">
          <div class="sp-modal__header">
            <div>
              <h2 class="sp-modal__title">Editar paciente</h2>
              <p class="sp-modal__sub">Actualizá los datos del paciente</p>
            </div>
            <button class="sp-modal__close" @click="showModal=false"><i class="bi bi-x-lg"></i></button>
          </div>
          <div class="sp-modal__body">
            <div v-if="formError" class="sp-alert"><i class="bi bi-exclamation-triangle-fill"></i> {{ formError }}</div>
            <div class="sp-section-title"><i class="bi bi-person-vcard"></i> Datos personales</div>
            <div class="sp-grid">
              <div class="sp-field">
                <label class="sp-label">Nombre <span class="sp-req">*</span></label>
                <input v-model.trim="form.nombre" class="sp-input" :class="{ 'sp-input--err': formErrors.nombre }" />
                <span v-if="formErrors.nombre" class="sp-err">{{ formErrors.nombre }}</span>
              </div>
              <div class="sp-field">
                <label class="sp-label">Apellido <span class="sp-req">*</span></label>
                <input v-model.trim="form.apellido" class="sp-input" :class="{ 'sp-input--err': formErrors.apellido }" />
                <span v-if="formErrors.apellido" class="sp-err">{{ formErrors.apellido }}</span>
              </div>
              <div class="sp-field">
                <label class="sp-label">DNI <span class="sp-req">*</span></label>
                <input v-model.trim="form.dni" class="sp-input" :class="{ 'sp-input--err': formErrors.dni }" />
                <span v-if="formErrors.dni" class="sp-err">{{ formErrors.dni }}</span>
              </div>
              <div class="sp-field">
                <label class="sp-label">Fecha de nacimiento <span class="sp-req">*</span></label>
                <input v-model="form.fecha_nacimiento" type="date" class="sp-input" :class="{ 'sp-input--err': formErrors.fecha_nacimiento }" />
                <span v-if="formErrors.fecha_nacimiento" class="sp-err">{{ formErrors.fecha_nacimiento }}</span>
              </div>
              <div class="sp-field">
                <label class="sp-label">Teléfono</label>
                <input v-model.trim="form.telefono" class="sp-input" placeholder="+54 9 11 1234-5678" />
              </div>
              <div class="sp-field">
                <label class="sp-label">Email</label>
                <input v-model.trim="form.email" type="email" class="sp-input" :class="{ 'sp-input--err': formErrors.email }" />
                <span v-if="formErrors.email" class="sp-err">{{ formErrors.email }}</span>
              </div>
            </div>
            <div class="sp-section-title sp-section-title--mt">
              <i class="bi bi-patch-check-fill" style="color:#15803d"></i> Autorización REPROCANN
            </div>
            <div class="sp-grid">
              <div class="sp-field">
                <label class="sp-label">Número de certificado</label>
                <input v-model.trim="form.reprocann_numero" class="sp-input" />
              </div>
              <div class="sp-field">
                <label class="sp-label">Fecha de vencimiento</label>
                <input v-model="form.reprocann_vencimiento" type="date" class="sp-input" />
              </div>
            </div>
            <div class="sp-section-title sp-section-title--mt">
              <i class="bi bi-heart-pulse" style="color:#0369a1"></i> Estado clínico
            </div>
            <label class="sp-toggle">
              <input v-model="form.es_paciente" type="checkbox" class="sp-toggle__input" />
              <div class="sp-toggle__track"><div class="sp-toggle__thumb"></div></div>
              <div>
                <div class="sp-toggle__label">Paciente activo en tratamiento</div>
                <div class="sp-toggle__hint">Los pacientes inactivos no aparecen en la lista principal</div>
              </div>
            </label>
          </div>
          <div class="sp-modal__footer">
            <button class="sp-btn-ghost" :disabled="store.saving" @click="showModal=false">Cancelar</button>
            <button class="sp-btn-primary" :disabled="store.saving" @click="save">
              <span v-if="store.saving" class="sp-spinner"></span>
              <i v-else class="bi bi-check-lg"></i>
              Guardar cambios
            </button>
          </div>
        </div>
      </div>
    </Teleport>

    <!-- Modal Eliminar -->
    <Teleport to="body">
      <div v-if="showDelete" class="sp-overlay" @click.self="showDelete=false">
        <div class="sp-modal sp-modal--sm">
          <div class="sp-modal__header">
            <h2 class="sp-modal__title sp-modal__title--danger">Eliminar paciente</h2>
            <button class="sp-modal__close" @click="showDelete=false"><i class="bi bi-x-lg"></i></button>
          </div>
          <div class="sp-modal__body">
            <p style="margin:0 0 .5rem">¿Eliminar a <strong>{{ deleteTarget?.nombre }} {{ deleteTarget?.apellido }}</strong>?</p>
            <p style="font-size:.85rem;color:#64748b;margin:0">Se eliminará su historial de notas, indicaciones y dispensaciones. Esta acción no se puede deshacer.</p>
          </div>
          <div class="sp-modal__footer">
            <button class="sp-btn-ghost" :disabled="store.removing" @click="showDelete=false">Cancelar</button>
            <button class="sp-btn-danger" :disabled="store.removing" @click="doDelete">
              <span v-if="store.removing" class="sp-spinner"></span>
              <i v-else class="bi bi-trash"></i> Eliminar
            </button>
          </div>
        </div>
      </div>
    </Teleport>

  </div>
</template>

<style scoped>
.sv { padding: 2rem 1.5rem; max-width: 1000px; margin: 0 auto; }
@media (max-width: 768px) { .sv { padding: 1.25rem 1rem; } }

.sv__header { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; margin-bottom: 1.75rem; flex-wrap: wrap; }
.sv__title { font-size: 2rem; font-weight: 800; color: #0f172a; margin: 0 0 .2rem; letter-spacing: -.04em; line-height: 1; }
.sv__sub { font-size: .83rem; color: #94a3b8; margin: 0; }

.sv__kpis { display: grid; grid-template-columns: repeat(4,1fr); gap: .75rem; margin-bottom: 1.5rem; }
@media (max-width: 640px) { .sv__kpis { grid-template-columns: repeat(2,1fr); } }
.sv__kpi { background: #fff; border: 1.5px solid #e2e8f0; border-radius: 12px; padding: 1rem; text-align: left; cursor: pointer; transition: all .15s; }
.sv__kpi:hover { border-color: #94a3b8; }
.sv__kpi--active { border-color: #0f172a !important; box-shadow: 0 0 0 1px #0f172a; }
.sv__kpi--ok.sv__kpi--active     { border-color: #15803d !important; box-shadow: 0 0 0 1px #15803d; }
.sv__kpi--warn.sv__kpi--active   { border-color: #b45309 !important; box-shadow: 0 0 0 1px #b45309; }
.sv__kpi--danger.sv__kpi--active { border-color: #dc2626 !important; box-shadow: 0 0 0 1px #dc2626; }
.sv__kpi-val { font-size: 1.8rem; font-weight: 800; color: #0f172a; line-height: 1; letter-spacing: -.04em; margin-bottom: .2rem; }
.sv__kpi--ok     .sv__kpi-val { color: #15803d; }
.sv__kpi--warn   .sv__kpi-val { color: #b45309; }
.sv__kpi--danger .sv__kpi-val { color: #dc2626; }
.sv__kpi-lbl { font-size: .72rem; font-weight: 600; text-transform: uppercase; letter-spacing: .04em; color: #94a3b8; }

.sv__toolbar { margin-bottom: 1.25rem; }
.sv__search-wrap { position: relative; display: flex; align-items: center; }
.sv__search-icon { position: absolute; left: .875rem; color: #94a3b8; font-size: .9rem; pointer-events: none; }
.sv__search { width: 100%; background: #fff; border: 1.5px solid #e2e8f0; border-radius: 10px; padding: .65rem .875rem .65rem 2.5rem; font-size: .9rem; color: #0f172a; transition: border .15s, box-shadow .15s; box-sizing: border-box; }
.sv__search:focus { outline: none; border-color: #1b5e20; box-shadow: 0 0 0 3px rgba(27,94,32,.1); }
.sv__search-count { position: absolute; right: .875rem; font-size: .72rem; font-weight: 600; color: #94a3b8; }

.sv__loading { display: flex; align-items: center; justify-content: center; gap: .75rem; padding: 4rem; color: #94a3b8; font-size: .875rem; }
.sv__ring { width: 22px; height: 22px; border: 2px solid #e2e8f0; border-top-color: #1b5e20; border-radius: 50%; animation: sv-spin .7s linear infinite; }
@keyframes sv-spin { to { transform: rotate(360deg); } }

.sv__empty { text-align: center; padding: 4rem 1rem; background: #fafbfc; border: 1.5px dashed #e2e8f0; border-radius: 14px; }
.sv__empty-icon { font-size: 2.5rem; color: #cbd5e1; display: block; margin-bottom: .875rem; }
.sv__empty-title { font-size: 1rem; font-weight: 700; color: #0f172a; margin: 0 0 .35rem; }
.sv__empty-sub { font-size: .82rem; color: #94a3b8; margin: 0 0 1.25rem; }

.sv__list { background: #fff; border: 1px solid #e2e8f0; border-radius: 14px; overflow: hidden; }

.sv__row { display: flex; align-items: center; gap: .875rem; padding: .875rem 1.1rem; border-bottom: 1px solid #f8fafc; text-decoration: none; color: inherit; transition: background .12s; }
.sv__row:last-child { border-bottom: none; }
.sv__row:hover { background: #fafbfc; }
.sv__row--danger  { background: rgba(220,38,38,.02); }
.sv__row--warning { background: rgba(180,83,9,.02); }

.sv__row-indicator { width: 3px; height: 38px; border-radius: 999px; flex-shrink: 0; align-self: center; }
.sv__ind--danger  { background: #dc2626; }
.sv__ind--warning { background: #f59e0b; }
.sv__ind--caution { background: #93c5fd; }
.sv__ind--ok      { background: #86efac; }
.sv__ind--none    { background: #e2e8f0; }

.sv__avatar { width: 38px; height: 38px; border-radius: 50%; background: linear-gradient(135deg, rgba(27,94,32,.15), rgba(3,105,161,.15)); color: #1b5e20; font-size: .8rem; font-weight: 800; display: flex; align-items: center; justify-content: center; flex-shrink: 0; letter-spacing: .02em; }
.sv__avatar--inactive { background: #f1f5f9; color: #94a3b8; }

.sv__info { flex: 1; min-width: 0; }
.sv__nombre { font-size: .9rem; font-weight: 700; color: #0f172a; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.sv__meta { display: flex; align-items: center; gap: .5rem; flex-wrap: wrap; margin-top: .1rem; }
.sv__dni   { font-size: .72rem; color: #64748b; font-family: monospace; }
.sv__edad  { font-size: .72rem; color: #94a3b8; }
.sv__email { font-size: .72rem; color: #94a3b8; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; max-width: 160px; }
.sv__inactivo { display: inline-block; font-size: .65rem; font-weight: 700; text-transform: uppercase; letter-spacing: .05em; background: #f1f5f9; color: #64748b; padding: .1em .45em; border-radius: 4px; margin-top: .25rem; }

.sv__reprocann { flex-shrink: 0; text-align: right; min-width: 100px; }
.sv__rep-badge { display: inline-block; font-size: .72rem; font-weight: 800; padding: .2em .6em; border-radius: 6px; margin-bottom: .2rem; }
.sv__rep-badge--danger  { background: #fef2f2; color: #dc2626; }
.sv__rep-badge--warning { background: #fffbeb; color: #b45309; }
.sv__rep-badge--caution { background: #eff6ff; color: #0369a1; }
.sv__rep-badge--ok      { background: #f0fdf4; color: #15803d; }
.sv__rep-fecha { font-size: .7rem; color: #94a3b8; }
.sv__rep-num   { font-size: .65rem; color: #cbd5e1; font-family: monospace; margin-top: .1rem; }
.sv__rep-none  { font-size: .75rem; color: #cbd5e1; }

.sv__actions { display: flex; align-items: center; gap: .35rem; flex-shrink: 0; }
.sv__action-btn { width: 30px; height: 30px; border-radius: 7px; border: 1px solid #e2e8f0; background: #f8fafc; color: #64748b; display: flex; align-items: center; justify-content: center; cursor: pointer; font-size: .8rem; opacity: 0; transition: opacity .15s, background .15s; }
.sv__row:hover .sv__action-btn { opacity: 1; }
.sv__action-btn:hover { background: #e2e8f0; color: #0f172a; }
.sv__action-btn--danger:hover { background: #fef2f2; color: #dc2626; border-color: #fecaca; }
.sv__action-arrow { color: #cbd5e1; font-size: .8rem; transition: color .15s, transform .15s; }
.sv__row:hover .sv__action-arrow { color: #0f172a; transform: translateX(2px); }

.sv__footer { text-align: right; font-size: .75rem; color: #94a3b8; margin-top: .75rem; padding-right: .25rem; }

.sv__btn-primary { display: inline-flex; align-items: center; gap: .4rem; background: var(--brand-primary, #1b5e20); color: #fff; border: none; padding: .65rem 1.25rem; border-radius: 9px; font-size: .875rem; font-weight: 700; cursor: pointer; transition: background .15s, transform .1s; text-decoration: none; white-space: nowrap; }
.sv__btn-primary:hover { background: #144a18; transform: translateY(-1px); }

.sp-overlay { position: fixed; inset: 0; background: rgba(0,0,0,.45); display: flex; align-items: center; justify-content: center; z-index: 1055; padding: 1rem; backdrop-filter: blur(3px); }
.sp-modal { background: #fff; border-radius: 18px; width: 100%; max-width: 620px; max-height: 92vh; overflow-y: auto; display: flex; flex-direction: column; box-shadow: 0 24px 64px rgba(0,0,0,.15); }
.sp-modal--sm { max-width: 440px; }
.sp-modal__header { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; padding: 1.5rem 1.5rem 1.1rem; border-bottom: 1px solid #f1f5f9; position: sticky; top: 0; background: #fff; z-index: 1; }
.sp-modal__title { font-size: 1.2rem; font-weight: 800; color: #0f172a; margin: 0 0 .2rem; letter-spacing: -.02em; }
.sp-modal__title--danger { color: #dc2626; }
.sp-modal__sub { font-size: .8rem; color: #64748b; margin: 0; }
.sp-modal__close { background: #f1f5f9; border: none; width: 32px; height: 32px; border-radius: 8px; cursor: pointer; display: flex; align-items: center; justify-content: center; color: #64748b; flex-shrink: 0; transition: all .15s; }
.sp-modal__close:hover { background: #e2e8f0; color: #0f172a; }
.sp-modal__body { padding: 1.4rem 1.5rem; flex: 1; }
.sp-modal__footer { display: flex; justify-content: flex-end; gap: .75rem; padding: 1rem 1.5rem; border-top: 1px solid #f1f5f9; position: sticky; bottom: 0; background: #fff; }
.sp-section-title { display: flex; align-items: center; gap: .5rem; font-size: .72rem; font-weight: 800; text-transform: uppercase; letter-spacing: .08em; color: #475569; padding-bottom: .6rem; border-bottom: 1px solid #f1f5f9; margin-bottom: 1rem; }
.sp-section-title--mt { margin-top: 1.5rem; }
.sp-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; }
@media (max-width: 520px) { .sp-grid { grid-template-columns: 1fr; } }
.sp-field { display: flex; flex-direction: column; gap: .35rem; }
.sp-label { font-size: .78rem; font-weight: 700; color: #374151; text-transform: uppercase; letter-spacing: .04em; }
.sp-req { color: #dc2626; }
.sp-input { background: #f8fafc; border: 1.5px solid #e2e8f0; border-radius: 9px; padding: .65rem .9rem; font-size: .875rem; color: #0f172a; width: 100%; box-sizing: border-box; transition: border .15s, box-shadow .15s; }
.sp-input:focus { outline: none; border-color: #1b5e20; box-shadow: 0 0 0 3px rgba(27,94,32,.1); background: #fff; }
.sp-input--err { border-color: #dc2626; }
.sp-err { font-size: .72rem; color: #dc2626; font-weight: 600; }
.sp-alert { background: #fef2f2; border: 1px solid #fecaca; color: #dc2626; padding: .75rem 1rem; border-radius: 9px; font-size: .85rem; margin-bottom: 1.25rem; display: flex; gap: .5rem; align-items: flex-start; }
.sp-toggle { display: flex; align-items: flex-start; gap: .875rem; cursor: pointer; padding: 1rem 1.1rem; background: #f8fafc; border: 1.5px solid #e2e8f0; border-radius: 10px; transition: border .15s; }
.sp-toggle:hover { border-color: #1b5e20; }
.sp-toggle__input { display: none; }
.sp-toggle__track { width: 44px; height: 24px; background: #cbd5e1; border-radius: 999px; position: relative; transition: background .2s; flex-shrink: 0; margin-top: .15rem; }
.sp-toggle__input:checked + .sp-toggle__track { background: #1b5e20; }
.sp-toggle__thumb { position: absolute; width: 18px; height: 18px; background: #fff; border-radius: 50%; top: 3px; left: 3px; transition: left .2s; box-shadow: 0 1px 3px rgba(0,0,0,.2); }
.sp-toggle__input:checked + .sp-toggle__track .sp-toggle__thumb { left: 22px; }
.sp-toggle__label { font-size: .9rem; font-weight: 700; color: #0f172a; margin-bottom: .3rem; }
.sp-toggle__hint  { font-size: .78rem; color: #64748b; line-height: 1.5; }
.sp-btn-primary { display: inline-flex; align-items: center; gap: .4rem; background: var(--brand-primary, #1b5e20); color: #fff; border: none; padding: .65rem 1.4rem; border-radius: 9px; font-size: .875rem; font-weight: 700; cursor: pointer; transition: background .15s, transform .1s; }
.sp-btn-primary:hover:not(:disabled) { background: #144a18; transform: translateY(-1px); }
.sp-btn-primary:disabled { opacity: .6; cursor: not-allowed; }
.sp-btn-ghost { background: transparent; color: #64748b; border: 1.5px solid #e2e8f0; padding: .65rem 1.2rem; border-radius: 9px; font-size: .875rem; font-weight: 600; cursor: pointer; transition: all .15s; }
.sp-btn-ghost:hover:not(:disabled) { background: #f8fafc; color: #0f172a; }
.sp-btn-ghost:disabled { opacity: .6; cursor: not-allowed; }
.sp-btn-danger { display: inline-flex; align-items: center; gap: .4rem; background: #dc2626; color: #fff; border: none; padding: .65rem 1.4rem; border-radius: 9px; font-size: .875rem; font-weight: 700; cursor: pointer; transition: background .15s; }
.sp-btn-danger:hover:not(:disabled) { background: #b91c1c; }
.sp-btn-danger:disabled { opacity: .6; cursor: not-allowed; }
.sp-spinner { width: 14px; height: 14px; border: 2px solid rgba(255,255,255,.3); border-top-color: #fff; border-radius: 50%; animation: sv-spin .6s linear infinite; flex-shrink: 0; }
</style>
