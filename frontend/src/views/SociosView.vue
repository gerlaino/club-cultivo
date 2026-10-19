<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import AppDatePicker from '../components/ui/AppDatePicker.vue'
import { useRoute, useRouter } from 'vue-router'
import { usePacientesStore } from '../stores/pacientes'
import { useAuthStore } from '../stores/auth'
import { useConfirm } from '../composables/useConfirm.js'
import { descargarListado } from '../lib/descargas.js'
import { useToast } from '../composables/useToast.js'
import BotonesDescarga from '../components/ui/BotonesDescarga.vue'
import EmptyState from '../components/ui/EmptyState.vue'
import DsSpinner from '../design-system/components/Spinner.vue'
import SocioEditarModal from '../components/pacientes/SocioEditarModal.vue'
import { hoyISO } from '../utils/dates.js'
import { reprocannSit, pacienteSit, vinculoSit, datosChicos, FILTROS } from '../composables/useSituacionPaciente.js'
import '../components/pacientes/formulario/formulario.css'
import { useRecargaEnCambios } from '../composables/useRecargaEnCambios.js'

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
  pendientes: 'pendientes',
  // ?reprocann=entrevista abre la lista filtrada.
  entrevista: 'entrevista',
  // Los links viejos a «sin REPROCANN» caen en pendientes de entrevista (19-oct-2026).
  sin_reprocann: 'entrevista',
  faltaron: 'falto',
  adherentes: 'adherentes',
  suspendidos: 'inactivos',
  sin_aprobar: 'pend_aprobacion',
  no_indicados: 'cerrados',
  baja: 'baja',
  todos: 'todos',
}
const REPRO_URL_REVERSE = Object.fromEntries(Object.entries(REPRO_URL).filter(([k]) => k !== 'sin_reprocann').map(([k,v]) => [v,k]))

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

// "Apellido, Nombre" — el orden con que se busca en una lista alfabética. Si falta alguno de
// los dos no se deja la coma colgando: hay pacientes cargados con un solo campo.
function nombreListado(s) {
  const ap = (s?.apellido || '').trim()
  const no = (s?.nombre   || '').trim()
  if (!ap) return no || '—'
  if (!no) return ap
  return `${ap}, ${no}`
}

// Numérico y no "20 de mar de 2029": son dos columnas de fechas una al lado de la otra, y en
// columna se comparan mejor alineadas y cortas. La fecha en prosa queda para la ficha.
function formatDate(d) {
  if (!d) return '—'
  return safeDate(d).toLocaleDateString('es-AR', { day: '2-digit', month: '2-digit', year: 'numeric' })
}

function edad(fn) {
  if (!fn) return null
  return Math.floor((Date.now() - safeDate(fn).getTime()) / (1000 * 60 * 60 * 24 * 365.25))
}

function iniciales(s) {
  return ((s.nombre?.[0] || '') + (s.apellido?.[0] || '')).toUpperCase()
}

// ── El estado del padrón ─────────────────────────────────────────────────────────
// Los conteos se hacen sobre LA NÓMINA (los activos en la organización), no sobre todas las
// fichas: alguien dado de baja no cuenta como paciente de la organización.
//
// Cada tarjeta es además el filtro que aísla a esos pacientes, y las dos cuentas son UNA: el backend
// manda `meta.kpis` y la `situacion` de cada fila con la misma regla (`Pacientes::Situacion`).
const nomina = computed(() => store.items.filter(s => s.es_paciente))
const kpis = computed(() => store.kpis || {})

// Cuántas fichas quedaron fuera de lo cargado. Las tarjetas siguen diciendo la verdad (las
// cuenta el servidor), pero la LISTA y sus filtros trabajan sobre lo que hay en memoria, así
// que si el padrón no entra hay que decirlo en vez de mostrar un subconjunto en silencio.
const sinCargar = computed(() => Math.max(0, (store.total || 0) - store.items.length))

// Las tarjetas, en el orden en que se trabaja: lo que espera una acción primero.
const TARJETAS = computed(() => [
  { key: 'todos',      val: kpis.value.total,                 lbl: 'En la nómina',              tono: '',       siempre: true },
  { key: 'entrevista', val: kpis.value.entrevista_pendiente,  lbl: 'Pendientes de entrevista',  tono: 'warn',   siempre: true },
  { key: 'pendientes', val: kpis.value.pendientes,            lbl: 'Pendientes de aprobación',  tono: 'info' },
  { key: 'proximos',   val: kpis.value.proximos,              lbl: 'Vencen en 30 días',         tono: 'warn',   siempre: true },
  { key: 'vencidos',   val: kpis.value.vencidos,              lbl: 'REPROCANN vencido',         tono: 'danger', siempre: true },
  { key: 'falto',      val: kpis.value.falto_turno,           lbl: 'Faltaron al turno',         tono: 'gray' },
  { key: 'adherentes', val: kpis.value.adherentes,            lbl: 'Adherentes',                tono: 'gray' },
  { key: 'inactivos',  val: kpis.value.inactivos,             lbl: 'Suspendidos · +90 días',    tono: 'warn' },
  { key: 'pend_aprobacion', val: kpis.value.pendientes_aprobacion, lbl: 'Altas sin aprobar',    tono: 'warn' },
  { key: 'cerrados',   val: kpis.value.cerrados,              lbl: 'No indicados / rechazados', tono: 'gray' },
  { key: 'baja',       val: kpis.value.baja,                  lbl: 'Dados de baja',             tono: 'gray' },
].filter(t => t.siempre || t.val))

const filtrados = computed(() => {
  // Por defecto se ve LA NÓMINA. Los dados de baja (y los «No indicado» / «Rechazado», que quedan
  // inactivos) tienen su propio filtro: están, pero no ensucian el día a día ni los conteos.
  let list
  if (filterEstado.value === 'baja') list = store.items.filter(s => !s.es_paciente)
  else if (filterEstado.value === 'cerrados') list = store.items.filter(FILTROS.cerrados)
  else list = nomina.value
  const f = FILTROS[filterEstado.value]
  if (f && filterEstado.value !== 'cerrados') list = list.filter(f)
  if (search.value.trim()) {
    const q = search.value.toLowerCase()
    // El DNI se compara sin puntos ni espacios de los dos lados: se escribe "90.000.027" y se
    // guarda "90000027".
    const qDni = q.replace(/[^\d]/g, '')
    list = list.filter(s =>
      (s.nombre + ' ' + s.apellido).toLowerCase().includes(q) ||
      (s.apodo || '').toLowerCase().includes(q) ||
      (qDni && String(s.dni || '').replace(/[^\d]/g, '').includes(qDni)) ||
      s.email?.toLowerCase().includes(q)
    )
  }
  return list
})

// El color de la fila sale del REPROCANN: es lo que más cambia lo que se hace con esa persona.
const nivelFila = (s) => reprocannSit(s.situacion)?.nivel || 'off'
const dniLegible = (dni) => String(dni || '').replace(/\D/g, '').replace(/\B(?=(\d{3})+(?!\d))/g, '.')

const totalPagesSv  = computed(() => Math.max(1, Math.ceil(filtrados.value.length / perPage)))
const paginadosSv   = computed(() => filtrados.value.slice((page.value-1)*perPage, page.value*perPage))
watch(filtrados, () => { page.value = 1 })

// «Que se replique»: si otra pantalla cambia un paciente o un turno, la lista se pone al día sola.
useRecargaEnCambios(['pacientes', 'turnos'], () => store.refrescar({ limite: LIMITE_PADRON }))

onMounted(async () => {
  await cargar()
  if (route.query.editar) {
    const s = store.items.find(x => String(x.id) === String(route.query.editar))
    if (s) openEdit(s)
  }
})

// Lo mismo que la lista, en PDF o Excel (`DescargaProfesional`).
const toast = useToast()
const generando = ref(null)
async function descargar(formato) {
  generando.value = formato
  try {
    const params = {}
    if (['proximos', 'vencidos'].includes(filterEstado.value)) params.reprocann = filterEstado.value
    if (search.value.trim()) params.query = search.value.trim()
    await descargarListado('/pacientes/export_csv', formato, { params, nombre: `pacientes_${hoyISO()}` })
  } catch (e) {
    toast.error(e.message)
  } finally {
    generando.value = null
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
      <button v-for="t in TARJETAS" :key="t.key" class="sv__kpi" :class="[t.tono && `sv__kpi--${t.tono}`, { 'sv__kpi--active': filterEstado === t.key }]"
              @click="filterEstado = t.key">
        <div class="sv__kpi-val">{{ t.val ?? 0 }}</div>
        <div class="sv__kpi-lbl">{{ t.lbl }}</div>
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
      el listado en PDF o Excel.
    </p>

    <!-- Búsqueda -->
    <div class="sv__toolbar">
      <div class="sv__search-wrap">
        <i class="bi bi-search sv__search-icon"></i>
        <input
          v-model="search"
          @input="onSearchInput"
          class="sv__search"
          placeholder="Buscar por nombre, apellido, apodo, DNI…"
        />
        <span v-if="search" class="sv__search-count">{{ filtrados.length }}</span>
      </div>
      <BotonesDescarga v-if="canEdit" :disabled="!filtrados.length" :generando="generando" @descargar="descargar" />
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

    <!-- Tabla (compu) y tarjetas (teléfono): los mismos datos, los tres estados con sus datos chicos. -->
    <div v-else class="sv__table-wrap">
      <table class="sv-table">
        <colgroup>
          <col class="sv-col--ind" />
          <col />
          <col class="sv-col--estado" />
          <col class="sv-col--rep" />
          <col class="sv-col--ultima" />
          <col v-if="canEdit" class="sv-col--acc" />
        </colgroup>
        <thead>
          <tr>
            <th></th>
            <th>Paciente</th>
            <th>Estado</th>
            <th>REPROCANN</th>
            <th>Última dispensa</th>
            <th v-if="canEdit"></th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="s in paginadosSv" :key="s.id" class="sv-table__row" :class="`sv-table__row--${nivelFila(s)}`"
              @click="router.push(`/pacientes/${s.id}`)">
            <td class="sv-td-ind"><div class="sv-indicator" :class="`sv-ind--${nivelFila(s)}`"></div></td>
            <td>
              <!-- "Apellido, Nombre": la lista se ordena por apellido. -->
              <div class="sv-pac-nombre">{{ nombreListado(s) }}<span v-if="s.apodo" class="sv-pac-apodo"> «{{ s.apodo }}»</span></div>
              <div class="sv-pac-sec">
                <span class="sv-mono">DNI {{ dniLegible(s.dni) }}</span>
                <span v-if="edad(s.fecha_nacimiento)"> · {{ edad(s.fecha_nacimiento) }} años</span>
              </div>
            </td>
            <td>
              <span v-if="pacienteSit(s.situacion)" class="pf-pill" :class="`pf-pill--${pacienteSit(s.situacion).nivel}`"
                    :title="pacienteSit(s.situacion).ayuda">{{ pacienteSit(s.situacion).label }}</span>
              <div v-if="vinculoSit(s.situacion)" class="sv-vinculo" :title="vinculoSit(s.situacion).ayuda">{{ vinculoSit(s.situacion).label }}</div>
            </td>
            <td>
              <span v-if="reprocannSit(s.situacion)" class="pf-pill" :class="`pf-pill--${reprocannSit(s.situacion).nivel}`"
                    :title="reprocannSit(s.situacion).ayuda">{{ reprocannSit(s.situacion).label }}</span>
              <div v-for="d in datosChicos(s.situacion)" :key="d.texto" class="sv-dato" :class="`sv-dato--${d.nivel}`">
                <i v-if="d.icono" class="bi" :class="d.icono"></i>{{ d.texto }}
              </div>
            </td>
            <td>
              <span v-if="s.ultima_dispensacion" class="sv-ultima">{{ formatDate(s.ultima_dispensacion) }}</span>
              <span v-else class="sv-empty">Nunca</span>
            </td>
            <td v-if="canEdit" @click.stop>
              <div class="sv-actions">
                <button class="sv-action-btn" title="Editar" aria-label="Editar" @click="openEdit(s)"><i class="bi bi-pencil"></i></button>
                <button class="sv-action-btn sv-action-btn--danger" title="Eliminar" aria-label="Eliminar" @click="openDelete(s)"><i class="bi bi-trash"></i></button>
              </div>
            </td>
          </tr>
        </tbody>
      </table>

      <ul class="sv-cards">
        <li v-for="s in paginadosSv" :key="s.id" class="sv-card" :class="`sv-card--${nivelFila(s)}`" @click="router.push(`/pacientes/${s.id}`)">
          <div class="sv-card__top">
            <div class="sv-card__quien">
              <div class="sv-pac-nombre">{{ nombreListado(s) }}<span v-if="s.apodo" class="sv-pac-apodo"> «{{ s.apodo }}»</span></div>
              <div class="sv-pac-sec"><span class="sv-mono">DNI {{ dniLegible(s.dni) }}</span>
                <span v-if="s.ultima_dispensacion"> · retiró {{ formatDate(s.ultima_dispensacion) }}</span></div>
            </div>
            <button v-if="canEdit" class="sv-action-btn" aria-label="Editar" @click.stop="openEdit(s)"><i class="bi bi-pencil"></i></button>
          </div>
          <div class="sv-card__pills">
            <span v-if="reprocannSit(s.situacion)" class="pf-pill" :class="`pf-pill--${reprocannSit(s.situacion).nivel}`">{{ reprocannSit(s.situacion).label }}</span>
            <span v-if="pacienteSit(s.situacion) && s.situacion.paciente !== 'activo'" class="pf-pill" :class="`pf-pill--${pacienteSit(s.situacion).nivel}`">{{ pacienteSit(s.situacion).label }}</span>
            <span v-if="s.situacion?.vinculo === 'adherente'" class="pf-pill pf-pill--off">Adherente</span>
          </div>
          <div v-if="datosChicos(s.situacion).length" class="sv-card__datos">
            <span v-for="d in datosChicos(s.situacion)" :key="d.texto" class="sv-dato" :class="`sv-dato--${d.nivel}`">
              <i v-if="d.icono" class="bi" :class="d.icono"></i>{{ d.texto }}
            </span>
          </div>
        </li>
      </ul>

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
/* 1200 es el ancho de las otras vistas de listado (Plantas, Genéticas, Sedes). Pacientes
   había quedado en 1000 y por eso las columnas se pisaban teniendo pantalla de sobra. */
.sv { padding: 2rem 1.5rem; max-width: 1200px; margin: 0 auto; }
@media (max-width: 768px) { .sv { padding: 1.25rem 1rem; } }

.sv__header { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; margin-bottom: 1.75rem; flex-wrap: wrap; }
.sv__title { font-size: 2rem; font-weight: 800; color: var(--c-slate-900); margin: 0 0 .2rem; letter-spacing: -.04em; line-height: 1; }
.sv__sub { font-size: .83rem; color: var(--c-slate-400); margin: 0; }

.sv__resena { margin: -.4rem 0 1rem; font-size: .78rem; color: var(--c-slate-500); line-height: 1.5; max-width: 78ch; }
.sv__resena--aviso { color: var(--c-amber-700, #b45309); font-weight: 500; }
.sv__kpis { display: grid; grid-template-columns: repeat(5,1fr); gap: .75rem; margin-bottom: 1.5rem; }
@media (max-width: 900px) { .sv__kpis { grid-template-columns: repeat(3,1fr); } }
/* En el teléfono, una fila que se desliza: once tarjetas apiladas tapaban la lista. */
@media (max-width: 640px) {
  .sv__kpis { display: flex; overflow-x: auto; scroll-snap-type: x proximity; scroll-padding-inline: 1rem; margin: 0 -1rem 1.25rem; padding: 0 1rem .25rem; scrollbar-width: none; }
  .sv__kpis::-webkit-scrollbar { display: none; }
  .sv__kpi { flex: 0 0 132px; scroll-snap-align: start; padding: .75rem; }
  .sv__kpi-val { font-size: 1.5rem; }
}
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
.sv-table { width: 100%; border-collapse: collapse; font-size: .875rem; table-layout: fixed; }
/* Los anchos van acá y no en el markup. Paciente NO tiene ancho a propósito: con
   `table-layout: fixed` es la única que se queda con lo que sobra. */
.sv-col--ind    { width: 8px; }
.sv-col--estado { width: 130px; }
.sv-col--rep    { width: 250px; }
.sv-col--ultima { width: 130px; }
.sv-col--acc    { width: 80px; }
.sv-table thead th { padding: 10px 12px; text-align: left; font-weight: 600; color: #6b7280; border-bottom: 2px solid #e5e7eb; white-space: nowrap; background: #fafafa; }
.sv-table tbody tr { border-bottom: 1px solid #f3f4f6; transition: background .1s; cursor: pointer; }
.sv-table tbody tr:last-child { border-bottom: none; }
.sv-table tbody tr:hover { background: var(--c-slate-50); }
.sv-table td { padding: 10px 12px; vertical-align: middle; }

.sv-table__row--danger  { background: color-mix(in srgb, var(--c-rust-100) 35%, transparent); }
.sv-table__row--warn    { background: color-mix(in srgb, var(--c-amber-100) 30%, transparent); }

.sv-td-ind { width: 8px; padding-right: 0 !important; }
.sv-indicator { width: 3px; height: 36px; border-radius: 999px; }
.sv-ind--danger { background: var(--c-rust-600); }
.sv-ind--warn   { background: var(--c-amber-500); }
.sv-ind--info   { background: var(--c-sky-600); }
.sv-ind--ok     { background: var(--c-leaf-500); }
.sv-ind--off    { background: var(--c-slate-200); }

.sv-pac-nombre { font-weight: 700; color: var(--c-slate-900); font-size: .9rem; }
.sv-pac-apodo { font-weight: 500; font-size: .8rem; color: var(--c-slate-500); }
.sv-pac-sec { font-size: .76rem; color: var(--c-slate-500); margin-top: .1rem; }
.sv-vinculo { margin-top: 4px; font-size: .72rem; font-weight: 600; color: var(--c-slate-500); }
.sv-dato { display: flex; align-items: center; gap: .3rem; margin-top: 4px; font-size: .74rem; font-weight: 600; color: var(--c-slate-600); }
.sv-dato i { font-size: .78rem; }
.sv-dato--warn   { color: var(--c-slate-900); }
.sv-dato--warn i { color: var(--c-amber-500); }
.sv-dato--info   { color: var(--c-sky-600); }
.sv-dato--off    { color: var(--c-slate-500); }
.sv-mono  { font-family: var(--font-mono); font-size: .76rem; }
.sv-empty { color: var(--c-slate-300); font-size: .82rem; }
.sv-ultima { font-size: .82rem; color: var(--c-slate-600); }

/* ── Teléfono: tarjetas en vez de tabla ── */
.sv-cards { display: none; list-style: none; margin: 0; padding: 0; }
@media (max-width: 760px) {
  .sv-table { display: none; }
  .sv-cards { display: flex; flex-direction: column; }
  .sv__table-wrap { background: transparent; border: 0; }
}
.sv-card { background: var(--c-paper, #fff); border: 1px solid var(--c-slate-200); border-left: 4px solid var(--c-slate-200); border-radius: var(--r-lg);
  padding: .85rem .9rem; margin-bottom: .6rem; cursor: pointer; }
.sv-card--danger { border-left-color: var(--c-rust-600); }
.sv-card--warn   { border-left-color: var(--c-amber-500); }
.sv-card--info   { border-left-color: var(--c-sky-600); }
.sv-card--ok     { border-left-color: var(--c-leaf-500); }
.sv-card__top { display: flex; justify-content: space-between; gap: .5rem; align-items: flex-start; }
.sv-card__quien { min-width: 0; }
.sv-card__pills { display: flex; flex-wrap: wrap; gap: .35rem; margin-top: .55rem; }
.sv-card__datos { display: flex; flex-wrap: wrap; gap: .25rem .85rem; margin-top: .2rem; }

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
