<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import AppDatePicker from '../components/ui/AppDatePicker.vue'
import { useRoute, useRouter } from 'vue-router'
import { usePacientesStore } from '../stores/pacientes'
import { useAuthStore } from '../stores/auth'
import { useConfirm } from '../composables/useConfirm.js'
import { exportPacientesCSV } from '../lib/api.js'
import EmptyState from '../components/ui/EmptyState.vue'
import DsSpinner from '../design-system/components/Spinner.vue'
import SocioEditarModal from '../components/pacientes/SocioEditarModal.vue'
import { reprocannBadge, reprocannCategoria } from '../composables/useReprocann.js'

const store  = usePacientesStore()
const auth   = useAuthStore()
const route  = useRoute()
const router = useRouter()

const canEdit = computed(() => ['admin', 'medico'].includes(auth.role))
const { confirm } = useConfirm()

const search       = ref('')
const searchTimer  = ref(null)
const showModal    = ref(false)
const page         = ref(1)
const perPage      = 50

// El listado y sus filtros trabajan en memoria (cada tarjeta filtra la lista), así que hay que
// traer el padrón entero: con el default del backend —20 por página— clickear "Sin REPROCANN"
// filtraba sobre la primera página y no sobre la organización. El techo evita que una organización grande se
// traiga todo de una; pasado ese punto la lista avisa y hay que ir al CSV o buscar.
const LIMITE_PADRON = 500
const cargar = (extra = {}) => store.fetch({ limite: LIMITE_PADRON, ...extra })

const REPRO_URL = {
  vencen_pronto: 'proximos',
  vencidos: 'vencidos',
  sin_reprocann: 'sin_rep',
  pendientes: 'pendientes',
  todos: 'todos',
}
const REPRO_URL_REVERSE = Object.fromEntries(Object.entries(REPRO_URL).map(([k,v]) => [v,k]))

const filterEstado = ref(REPRO_URL[route.query.reprocann] || 'todos')

watch(filterEstado, (val) => {
  router.replace({ query: { ...route.query, reprocann: REPRO_URL_REVERSE[val] || 'todos' } })
})

const editandoId = ref(null)

function openEdit(s) {
  editandoId.value = s.id
  showModal.value  = true
}

async function openDelete(s) {
  const ok = await confirm({
    title: 'Eliminar paciente',
    message: `¿Eliminar a ${s.nombre} ${s.apellido}? Se eliminará su historial. Esta acción no se puede deshacer.`,
    confirmText: 'Eliminar',
    variant: 'danger',
  })
  if (!ok) return
  try {
    await store.remove(s.id)
  } catch {}
}

// Un DNI NO se manda al servidor: `dni_normalizado` va cifrado determinístico, así que la base
// sólo resuelve igualdad exacta. Tipeando "900000…" el servidor devolvía vacío en cada tecla y
// parecía que el buscador no encontraba nada — hasta escribir el último dígito.
//
// Como el padrón ya está cargado (ver LIMITE_PADRON), el filtro por DNI se hace en memoria, que
// además permite parciales. La búsqueda por nombre sí va al servidor: ahí LIKE funciona y cubre
// el caso de una organización con más pacientes de los que entran en una carga.
const esBusquedaPorDni = (q) => /^[\d.\s-]+$/.test(q)

async function doSearch() {
  const q = search.value.trim()
  // Con DNI se recarga sin `query` para tener el padrón completo sobre el cual filtrar.
  await cargar(q && !esBusquedaPorDni(q) ? { query: q } : {})
}

function onSearchInput() {
  clearTimeout(searchTimer.value)
  searchTimer.value = setTimeout(doSearch, 400)
}


function safeDate(d) {
  if (!d) return null
  return /^\d{4}-\d{2}-\d{2}$/.test(d) ? new Date(d + 'T00:00:00') : new Date(d)
}

const reprocannStatus = reprocannBadge

function formatDate(d) {
  if (!d) return '—'
  return safeDate(d).toLocaleDateString('es-AR', { day: 'numeric', month: 'short', year: 'numeric' })
}

function edad(fn) {
  if (!fn) return null
  return Math.floor((Date.now() - safeDate(fn).getTime()) / (1000 * 60 * 60 * 24 * 365.25))
}

function iniciales(s) {
  return ((s.nombre?.[0] || '') + (s.apellido?.[0] || '')).toUpperCase()
}

// ── El estado del padrón ─────────────────────────────────────────────────────────
// Los conteos se hacen sobre LA NÓMINA (los que están en tratamiento), no sobre todas las
// fichas: alguien dado de baja no cuenta como paciente de la organización. Antes "Total" los sumaba a
// todos, así que el número no coincidía con nada y quedaba inflado.
//
// Esto vive acá y no en Informes a propósito: es la pantalla desde la que después hay que
// ACTUAR sobre cada paciente, y cada KPI es además el filtro que lo aísla.
const DIAS_INACTIVO = 90

const nomina = computed(() => store.items.filter(s => s.es_paciente))

const diasDesdeUltima = (s) => {
  const f = s.ultima_dispensacion?.fecha || s.ultima_dispensacion
  if (!f) return null
  return Math.floor((Date.now() - new Date(f).getTime()) / 86400000)
}
// "No viene hace tiempo": tiene tratamiento abierto pero hace más de tres meses que no retira.
// El que nunca dispensó no entra: ese es un alta reciente, no un abandono.
const esInactivo = (s) => {
  const d = diasDesdeUltima(s)
  return d !== null && d > DIAS_INACTIVO
}

// Los números los cuenta el BACKEND sobre todo el padrón (`meta.kpis`). Contarlos acá sobre
// `store.items` era contar la página: con el listado paginado de a 20, una organización de 38 pacientes
// mostraba "20 en la nómina" y "0 REPROCANN vencido" teniendo vencidos más adelante.
// El cálculo local queda de respaldo por si `meta.kpis` no viene.
const kpisLocales = computed(() => {
  const enNomina = nomina.value
  return {
    total:      enNomina.length,                                   // la nómina, no las fichas
    baja:       store.items.length - enNomina.length,              // fuera de tratamiento
    vencidos:   enNomina.filter(s => reprocannCategoria(s) === 'vencido').length,
    proximos:   enNomina.filter(s => reprocannCategoria(s) === 'por_vencer').length,
    pendientes: enNomina.filter(s => reprocannCategoria(s) === 'pendiente').length,
    sin_rep:    enNomina.filter(s => reprocannCategoria(s) === 'sin_reprocann').length,
    inactivos:  enNomina.filter(esInactivo).length,
  }
})

const kpis = computed(() => store.kpis || kpisLocales.value)

// Cuántas fichas quedaron fuera de lo cargado. Las tarjetas siguen diciendo la verdad (las
// cuenta el servidor), pero la LISTA y sus filtros trabajan sobre lo que hay en memoria, así
// que si el padrón no entra hay que decirlo en vez de mostrar un subconjunto en silencio.
const sinCargar = computed(() => Math.max(0, (store.total || 0) - store.items.length))

const filtrados = computed(() => {
  // Por defecto se ve LA NÓMINA. Los dados de baja tienen su propio filtro: están, pero no
  // ensucian el día a día ni los conteos.
  let list = filterEstado.value === 'baja' ? store.items.filter(s => !s.es_paciente) : nomina.value
  if (filterEstado.value === 'inactivos') list = list.filter(esInactivo)
  if (filterEstado.value === 'vencidos')   list = list.filter(s => reprocannCategoria(s) === 'vencido')
  if (filterEstado.value === 'proximos')   list = list.filter(s => reprocannCategoria(s) === 'por_vencer')
  if (filterEstado.value === 'pendientes') list = list.filter(s => reprocannCategoria(s) === 'pendiente')
  if (filterEstado.value === 'sin_rep')    list = list.filter(s => reprocannCategoria(s) === 'sin_reprocann')
  if (search.value.trim()) {
    const q = search.value.toLowerCase()
    // El DNI se compara sin puntos ni espacios de los dos lados: se escribe "90.000.027" y se
    // guarda "90000027".
    const qDni = q.replace(/[^\d]/g, '')
    list = list.filter(s =>
      (s.nombre + ' ' + s.apellido).toLowerCase().includes(q) ||
      (qDni && String(s.dni || '').replace(/[^\d]/g, '').includes(qDni)) ||
      s.email?.toLowerCase().includes(q)
    )
  }
  return list
})

const totalPagesSv  = computed(() => Math.max(1, Math.ceil(filtrados.value.length / perPage)))
const paginadosSv   = computed(() => filtrados.value.slice((page.value-1)*perPage, page.value*perPage))
watch(filtrados, () => { page.value = 1 })

onMounted(async () => {
  await cargar()
  if (route.query.editar) {
    const s = store.items.find(x => String(x.id) === String(route.query.editar))
    if (s) openEdit(s)
  }
})

const exporting = ref(false)
async function exportarCSV() {
  exporting.value = true
  try {
    const params = {}
    if (filterEstado.value === 'proximos') params.reprocann = 'proximos'
    if (filterEstado.value === 'vencidos') params.reprocann = 'vencidos'
    if (filterEstado.value === 'sin_rep')  params.reprocann = 'sin_rep'
    if (search.value.trim())               params.query     = search.value.trim()
    const { data } = await exportPacientesCSV(params)
    const url = URL.createObjectURL(new Blob([data], { type: 'text/csv' }))
    const a = document.createElement('a')
    a.href = url
    a.download = `pacientes_${new Date().toISOString().slice(0,10)}.csv`
    a.click()
    URL.revokeObjectURL(url)
  } catch {
    // silencio
  } finally {
    exporting.value = false
  }
}
</script>

<template>
  <div class="sv">

    <!-- Header -->
    <div class="sv__header">
      <div>
        <h1 class="sv__title">Pacientes</h1>
        <p class="sv__sub">Trazabilidad clínica y gestión REPROCANN</p>
      </div>
      <button v-if="canEdit" class="sv__btn-primary" @click="router.push({ name: 'paciente-nuevo' })">
        <i class="bi bi-person-plus"></i>
        Nuevo paciente
      </button>
    </div>

    <!-- KPIs como filtros -->
    <div class="sv__kpis">
      <button class="sv__kpi" :class="{ 'sv__kpi--active': filterEstado === 'todos' }" @click="filterEstado = 'todos'">
        <div class="sv__kpi-val">{{ kpis.total }}</div>
        <div class="sv__kpi-lbl">En la nómina</div>
      </button>
      <!-- No viene hace más de tres meses: tiene tratamiento abierto pero dejó de retirar. Es
           lo único de esta pantalla sobre lo que hay que hacer algo hoy. -->
      <button v-if="kpis.inactivos" class="sv__kpi sv__kpi--warn" :class="{ 'sv__kpi--active': filterEstado === 'inactivos' }" @click="filterEstado = 'inactivos'">
        <div class="sv__kpi-val">{{ kpis.inactivos }}</div>
        <div class="sv__kpi-lbl">Sin retirar +90d</div>
      </button>
      <button class="sv__kpi sv__kpi--warn" :class="{ 'sv__kpi--active': filterEstado === 'proximos' }" @click="filterEstado = 'proximos'">
        <div class="sv__kpi-val">{{ kpis.proximos }}</div>
        <div class="sv__kpi-lbl">Vencen en 30d</div>
      </button>
      <button class="sv__kpi sv__kpi--danger" :class="{ 'sv__kpi--active': filterEstado === 'vencidos' }" @click="filterEstado = 'vencidos'">
        <div class="sv__kpi-val">{{ kpis.vencidos }}</div>
        <div class="sv__kpi-lbl">REPROCANN vencido</div>
      </button>
      <button v-if="kpis.pendientes" class="sv__kpi sv__kpi--warn" :class="{ 'sv__kpi--active': filterEstado === 'pendientes' }" @click="filterEstado = 'pendientes'">
        <div class="sv__kpi-val">{{ kpis.pendientes }}</div>
        <div class="sv__kpi-lbl">Trámite pendiente</div>
      </button>
      <button class="sv__kpi sv__kpi--gray" :class="{ 'sv__kpi--active': filterEstado === 'sin_rep' }" @click="filterEstado = 'sin_rep'">
        <div class="sv__kpi-val">{{ kpis.sin_rep }}</div>
        <div class="sv__kpi-lbl">Sin REPROCANN</div>
      </button>
      <!-- Fuera de tratamiento: no cuentan como pacientes de la organización, pero siguen estando. -->
      <button v-if="kpis.baja" class="sv__kpi sv__kpi--gray" :class="{ 'sv__kpi--active': filterEstado === 'baja' }" @click="filterEstado = 'baja'">
        <div class="sv__kpi-val">{{ kpis.baja }}</div>
        <div class="sv__kpi-lbl">Dados de baja</div>
      </button>
    </div>

    <p class="sv__resena">
      Los números cuentan <strong>la nómina</strong>: los pacientes en tratamiento. Los dados de
      baja quedan fuera del padrón y de los conteos. Cada tarjeta filtra la lista.
    </p>

    <!-- Las tarjetas cuentan todo el padrón; la lista trabaja con lo cargado. Si no entró
         entero hay que decirlo: mostrar un subconjunto en silencio es peor que el número mal. -->
    <p v-if="sinCargar" class="sv__resena sv__resena--aviso">
      La lista muestra los primeros {{ store.items.length }} de {{ store.total }}. Los números de
      arriba cuentan el padrón completo. Buscá por nombre o DNI para llegar al resto, o descargá
      el CSV.
    </p>

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
      <button v-if="canEdit" class="sv__btn-export" :disabled="exporting || !filtrados.length" @click="exportarCSV">
        <i class="bi bi-download"></i>
        {{ exporting ? 'Exportando…' : 'CSV' }}
      </button>
    </div>

    <!-- Loading -->
    <div v-if="store.loading" class="sv__loading">
      <DsSpinner />
    </div>

    <!-- Empty -->
    <EmptyState
      v-else-if="!filtrados.length"
      icon="bi-people"
      :title="search || filterEstado !== 'todos' ? 'Sin resultados' : 'Sin pacientes registrados'"
      :message="search ? 'Probá con otro término' : filterEstado !== 'todos' ? 'No hay pacientes en este filtro' : 'Registrá el primer paciente de la organización'"
    >
      <template #actions>
        <button v-if="!search && canEdit && filterEstado === 'todos'" class="sv__btn-primary" @click="router.push({ name: 'paciente-nuevo' })">
          <i class="bi bi-person-plus"></i> Nuevo paciente
        </button>
      </template>
    </EmptyState>

    <!-- Tabla -->
    <div v-else class="sv__table-wrap">
      <table class="sv-table">
        <thead>
          <tr>
            <th></th>
            <th>Paciente</th>
            <th>DNI</th>
            <th>Edad</th>
            <th>Estado</th>
            <th>REPROCANN</th>
            <th>Última dispensa</th>
            <th>Email</th>
            <th v-if="canEdit"></th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="s in paginadosSv"
            :key="s.id"
            class="sv-table__row"
            :class="{
              'sv-table__row--danger':  reprocannStatus(s)?.level === 'danger',
              'sv-table__row--warning': reprocannStatus(s)?.level === 'warning',
            }"
            @click="router.push(`/pacientes/${s.id}`)"
          >
            <td class="sv-td-ind">
              <div class="sv-indicator"
                :class="{
                  'sv-ind--danger':  reprocannStatus(s)?.level === 'danger',
                  'sv-ind--warning': reprocannStatus(s)?.level === 'warning',
                  'sv-ind--caution': reprocannStatus(s)?.level === 'caution',
                  'sv-ind--ok':      reprocannStatus(s)?.level === 'ok',
                  'sv-ind--none':    !reprocannStatus(s),
                }"
              ></div>
            </td>
            <td>
              <div class="sv-pac-nombre">{{ s.nombre }} {{ s.apellido }}</div>
            </td>
            <td><span class="sv-mono">{{ s.dni }}</span></td>
            <td>
              <span v-if="edad(s.fecha_nacimiento)" class="sv-edad">{{ edad(s.fecha_nacimiento) }}a</span>
              <span v-else class="sv-empty">—</span>
            </td>
            <td>
              <span class="sv-estado" :class="s.es_paciente ? 'sv-estado--on' : 'sv-estado--off'">
                {{ s.es_paciente ? 'Activo' : 'Inactivo' }}
              </span>
            </td>
            <td>
              <template v-if="s.reprocann_vencimiento">
                <span class="sv-rep-badge"
                  :class="{
                    'sv-rep--danger':  reprocannStatus(s)?.level === 'danger',
                    'sv-rep--warning': reprocannStatus(s)?.level === 'warning',
                    'sv-rep--caution': reprocannStatus(s)?.level === 'caution',
                    'sv-rep--ok':      reprocannStatus(s)?.level === 'ok',
                  }"
                >{{ reprocannStatus(s)?.label }}</span>
                <div class="sv-rep-fecha">{{ formatDate(s.reprocann_vencimiento) }}</div>
              </template>
              <span v-else class="sv-empty">Sin REPROCANN</span>
            </td>
            <td>
              <span v-if="s.ultima_dispensacion" class="sv-ultima">{{ formatDate(s.ultima_dispensacion) }}</span>
              <span v-else class="sv-empty">Nunca</span>
            </td>
            <td>
              <span class="sv-email-cell">{{ s.email || '—' }}</span>
            </td>
            <td v-if="canEdit" @click.stop>
              <div class="sv-actions">
                <button class="sv-action-btn" title="Editar" @click="openEdit(s)">
                  <i class="bi bi-pencil"></i>
                </button>
                <button class="sv-action-btn sv-action-btn--danger" title="Eliminar" @click="openDelete(s)">
                  <i class="bi bi-trash"></i>
                </button>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
      <div class="sv__table-footer">
        <div class="sv__pagination" v-if="totalPagesSv > 1">
          <button class="sv__page-btn" :disabled="page <= 1" @click="page--">«</button>
          <span class="sv__page-info">{{ page }} / {{ totalPagesSv }}</span>
          <button class="sv__page-btn" :disabled="page >= totalPagesSv" @click="page++">»</button>
        </div>
        <div class="sv__count">{{ filtrados.length }} paciente{{ filtrados.length !== 1 ? 's' : '' }}</div>
      </div>
    </div>

    <!-- Edición: el MISMO modal que se usa desde la ficha del paciente, para que los
         campos y las validaciones sean unos solos. -->
    <SocioEditarModal v-if="editandoId" v-model:open="showModal" :socio-id="editandoId" @saved="cargar()" />


  </div>
</template>

<style scoped>
.sv { padding: 2rem 1.5rem; max-width: 1000px; margin: 0 auto; }
@media (max-width: 768px) { .sv { padding: 1.25rem 1rem; } }

.sv__header { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; margin-bottom: 1.75rem; flex-wrap: wrap; }
.sv__title { font-size: 2rem; font-weight: 800; color: var(--c-slate-900); margin: 0 0 .2rem; letter-spacing: -.04em; line-height: 1; }
.sv__sub { font-size: .83rem; color: var(--c-slate-400); margin: 0; }

.sv__resena { margin: -.4rem 0 1rem; font-size: .78rem; color: var(--c-slate-500); line-height: 1.5; max-width: 78ch; }
.sv__resena--aviso { color: var(--c-amber-700, #b45309); font-weight: 500; }
.sv__kpis { display: grid; grid-template-columns: repeat(5,1fr); gap: .75rem; margin-bottom: 1.5rem; }
@media (max-width: 900px) { .sv__kpis { grid-template-columns: repeat(3,1fr); } }
@media (max-width: 640px) { .sv__kpis { grid-template-columns: repeat(2,1fr); } }
.sv__kpi { background: #fff; border: 1.5px solid var(--c-slate-200); border-radius: 12px; padding: 1rem; text-align: left; cursor: pointer; transition: all .15s; }
.sv__kpi:hover { border-color: var(--c-slate-400); }
.sv__kpi--active { border-color: var(--c-slate-900) !important; box-shadow: 0 0 0 1px var(--c-slate-900); }
.sv__kpi--ok.sv__kpi--active     { border-color: #15803d !important; box-shadow: 0 0 0 1px #15803d; }
.sv__kpi--warn.sv__kpi--active   { border-color: #b45309 !important; box-shadow: 0 0 0 1px #b45309; }
.sv__kpi--danger.sv__kpi--active { border-color: #dc2626 !important; box-shadow: 0 0 0 1px #dc2626; }
.sv__kpi-val { font-size: 1.8rem; font-weight: 800; color: var(--c-slate-900); line-height: 1; letter-spacing: -.04em; margin-bottom: .2rem; }
.sv__kpi--ok     .sv__kpi-val { color: #15803d; }
.sv__kpi--warn   .sv__kpi-val { color: #b45309; }
.sv__kpi--danger .sv__kpi-val { color: #dc2626; }
.sv__kpi--gray   .sv__kpi-val { color: var(--c-slate-500); }
.sv__kpi--gray.sv__kpi--active { border-color: var(--c-slate-500) !important; box-shadow: 0 0 0 1px var(--c-slate-500); }
.sv__kpi-lbl { font-size: .72rem; font-weight: 600; text-transform: uppercase; letter-spacing: .04em; color: var(--c-slate-400); }

.sv__toolbar { margin-bottom: 1.25rem; display: flex; align-items: center; gap: .75rem; }
.sv__search-wrap { flex: 1; }
.sv__btn-export {
  display: flex; align-items: center; gap: .35rem;
  padding: .55rem .9rem; background: #1b5e20; color: #fff;
  border: none; border-radius: 10px; font-size: .84rem; font-weight: 600;
  cursor: pointer; white-space: nowrap; transition: background .15s;
}
.sv__btn-export:hover:not(:disabled) { background: #145218; }
.sv__btn-export:disabled { opacity: .55; cursor: default; }
.sv__search-wrap { position: relative; display: flex; align-items: center; }
.sv__search-icon { position: absolute; left: .875rem; color: var(--c-slate-400); font-size: .9rem; pointer-events: none; }
.sv__search { width: 100%; background: #fff; border: 1.5px solid var(--c-slate-200); border-radius: 10px; padding: .65rem .875rem .65rem 2.5rem; font-size: .9rem; color: var(--c-slate-900); transition: border .15s, box-shadow .15s; box-sizing: border-box; }
.sv__search:focus { outline: none; border-color: #1b5e20; box-shadow: 0 0 0 3px rgba(27,94,32,.1); }
.sv__search-count { position: absolute; right: .875rem; font-size: .72rem; font-weight: 600; color: var(--c-slate-400); }

.sv__loading { display: flex; align-items: center; justify-content: center; min-height: calc(100vh - 56px); }


/* ── Tabla ───────────────────────────────────────── */
.sv__table-wrap { background: #fff; border: 1px solid #e5e7eb; border-radius: 12px; overflow: hidden; }
.sv-table { width: 100%; border-collapse: collapse; font-size: .875rem; }
.sv-table thead th { padding: 10px 12px; text-align: left; font-weight: 600; color: #6b7280; border-bottom: 2px solid #e5e7eb; white-space: nowrap; background: #fafafa; }
.sv-table tbody tr { border-bottom: 1px solid #f3f4f6; transition: background .1s; cursor: pointer; }
.sv-table tbody tr:last-child { border-bottom: none; }
.sv-table tbody tr:hover { background: var(--c-slate-50); }
.sv-table td { padding: 10px 12px; vertical-align: middle; }

.sv-table__row--danger  { background: rgba(220,38,38,.02); }
.sv-table__row--warning { background: rgba(180,83,9,.02); }

.sv-td-ind { width: 8px; padding-right: 0 !important; }
.sv-indicator { width: 3px; height: 32px; border-radius: 999px; }
.sv-ind--danger  { background: #dc2626; }
.sv-ind--warning { background: #f59e0b; }
.sv-ind--caution { background: #93c5fd; }
.sv-ind--ok      { background: #86efac; }
.sv-ind--none    { background: var(--c-slate-200); }

.sv-pac-nombre { font-weight: 700; color: var(--c-slate-900); font-size: .875rem; }
.sv-estado { display: inline-block; font-size: .7rem; font-weight: 700; padding: .15em .55em; border-radius: 999px; white-space: nowrap; }
.sv-estado--on  { background: #f0fdf4; color: #15803d; }
.sv-estado--off { background: var(--c-slate-100); color: var(--c-slate-500); }
.sv-mono  { font-family: monospace; font-size: .82rem; color: #374151; }
.sv-edad  { font-size: .82rem; color: var(--c-slate-500); }
.sv-empty { color: var(--c-slate-300); font-size: .82rem; }
.sv-email-cell { font-size: .82rem; color: var(--c-slate-500); }

.sv-rep-badge { display: inline-block; font-size: .72rem; font-weight: 800; padding: 2px 8px; border-radius: 5px; }
.sv-rep--danger  { background: #fef2f2; color: #dc2626; }
.sv-rep--warning { background: #fffbeb; color: #b45309; }
.sv-rep--caution { background: #eff6ff; color: #0369a1; }
.sv-rep--ok      { background: #f0fdf4; color: #15803d; }
.sv-rep-fecha { font-size: .7rem; color: var(--c-slate-400); margin-top: .15rem; }

.sv-actions { display: flex; align-items: center; gap: .25rem; opacity: 0; transition: opacity .15s; }
.sv-table tbody tr:hover .sv-actions { opacity: 1; }
.sv-action-btn { background: none; border: none; cursor: pointer; padding: 5px 7px; border-radius: 6px; color: #6b7280; font-size: .875rem; transition: all .15s; }
.sv-action-btn:hover { background: var(--c-slate-100); color: var(--c-slate-900); }
.sv-action-btn--danger:hover { background: #fef2f2; color: #dc2626; }

.sv__table-footer { display: flex; align-items: center; justify-content: space-between; padding: .6rem 1rem; border-top: 1px solid var(--c-slate-100); }
.sv__pagination { display: flex; align-items: center; gap: .5rem; }
.sv__page-btn { background: #fff; border: 1.5px solid var(--c-slate-200); border-radius: 7px; padding: .3rem .65rem; font-size: .82rem; color: #374151; cursor: pointer; transition: all .15s; }
.sv__page-btn:hover:not(:disabled) { border-color: #1b5e20; color: #1b5e20; }
.sv__page-btn:disabled { opacity: .4; cursor: not-allowed; }
.sv__page-info { font-size: .8rem; color: var(--c-slate-500); font-weight: 600; }
.sv__count { font-size: .75rem; color: var(--c-slate-400); }

.sv__btn-primary { display: inline-flex; align-items: center; gap: .4rem; background: var(--brand-primary, #1b5e20); color: #fff; border: none; padding: .65rem 1.25rem; border-radius: 9px; font-size: .875rem; font-weight: 700; cursor: pointer; transition: background .15s, transform .1s; text-decoration: none; white-space: nowrap; }
.sv__btn-primary:hover { background: #144a18; transform: translateY(-1px); }

</style>
