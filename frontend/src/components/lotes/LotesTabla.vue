<script setup>
// La tabla de lotes: la misma en /lotes y adentro de una sala. Antes la sala tenía su propia
// lista de tarjetas con otra información y otros nombres para lo mismo.
import { ref, computed } from 'vue'
import { useRouter } from 'vue-router'
import { useSalasStore } from '../../stores/salas'
import { textoProximoPasoCorto, textoProximoPaso } from '../../lib/loteHelpers.js'

const props = defineProps({
  lotes:      { type: Array, required: true },
  // Adentro de una sala la columna Sala repite lo mismo en todas las filas.
  mostrarSala: { type: Boolean, default: true },
  // { esta(l), alternar(l), puede(l), todo, algo, alternarTodo(), deshabilitada, tituloTodo } o null.
  seleccion:  { type: Object, default: null },
  // Sin `sortBy` los encabezados no ordenan: la sala tiene su propio orden.
  sortBy:     { type: String, default: null },
  puedeEditar: { type: Boolean, default: false },
})
const emit = defineEmits(['update:sortBy', 'editar', 'eliminar'])

const router = useRouter()
const salas  = useSalasStore()

const ESTADO_META = {
  enraizado:   { label: 'Enraizado',   bg: '#e0f2fe', text: '#0369a1', bar: '#0891b2', icon: '🌱' },
  vegetativo:  { label: 'Vegetativo',  bg: '#E8F0EB', text: '#2D4A3E', bar: '#5A8A72', icon: '🍃' },
  floracion:   { label: 'Floración',   bg: '#FEF3C7', text: '#92400e', bar: '#D97706', icon: '🌸' },
  cosecha:     { label: 'Cosecha',     bg: '#F4F8F5', text: '#1A3D2E', bar: '#3F6452', icon: '✂️' },
  en_manicura: { label: 'En manicura', bg: '#ede9fe', text: '#5b21b6', bar: '#7c3aed', icon: '✂️' },
  curado:      { label: 'Curado',      bg: '#dbeafe', text: '#1e40af', bar: '#2563eb', icon: '🫙' },
  finalizado:  { label: 'Finalizado',  bg: '#E8F0EB', text: '#0F2A1E', bar: '#1A3D2E', icon: '✅' },
}
function em(e) { return ESTADO_META[e] || { label: e || '—', bg: '#f1f5f9', text: '#64748b', bar: '#94a3b8', icon: '•' } }
function tipoLabel(t) { return { sativa: 'Sativa', indica: 'Índica', hibrida: 'Híbrida' }[t] || t }

// Semáforo de los días EN FASE contra el objetivo de la genética para esa fase.
const FASE_OBJ = { vegetativo: 'dias_vegetativo_objetivo', floracion: 'dias_floracion_objetivo', cosecha: 'dias_cosecha_objetivo' }
const FASE_LBL = { vegetativo: 'vegetativo', floracion: 'floración', cosecha: 'cosecha' }
function objetivoFase(l) { return FASE_OBJ[l.estado] ? l[FASE_OBJ[l.estado]] : null }
function diasNivel(l) {
  const obj = objetivoFase(l), d = l.dias_en_estado
  if (!obj || obj <= 0 || d == null) return null
  const r = d / obj
  return r > 1.1 ? 'rojo' : (r >= 0.9 ? 'amarillo' : 'verde')
}
function diasTitle(l) {
  const obj = objetivoFase(l)
  return obj ? `${l.dias_en_estado} de ${obj} días en ${FASE_LBL[l.estado] || l.estado} (objetivo de la genética)` : ''
}

const SALA_POST = { cosecha: 'Cosechado', en_manicura: 'En manicura', curado: 'Curado', finalizado: 'Finalizado' }
function salaCelda(l) {
  if (!l.sala_id) return SALA_POST[l.estado] || '—'
  return salas.items.find(s => String(s.id) === String(l.sala_id))?.nombre || `Sala #${l.sala_id}`
}
function diasDesdeInicio(d) { return d ? Math.floor((Date.now() - new Date(d)) / 86_400_000) : null }

// dd/mm/aa. `T00:00:00` fuerza hora local: un `2026-08-11` parseado como UTC se ve un día antes.
function fechaCorta(d) {
  if (!d) return '—'
  const f = /^\d{4}-\d{2}-\d{2}$/.test(d) ? new Date(`${d}T00:00:00`) : new Date(d)
  return f.toLocaleDateString('es-AR', { day: '2-digit', month: '2-digit', year: '2-digit' })
}

// Los días de cada fase los manda el backend (`fases`): acá sólo se muestran.
function fasesPasadas(l) { return (l.fases || []).filter(f => !f.actual) }

const abiertos = ref(new Set())
function alternarDetalle(id) {
  const s = new Set(abiertos.value)
  s.has(id) ? s.delete(id) : s.add(id)
  abiertos.value = s
}

const nCols = computed(() =>
  9 + (props.seleccion ? 1 : 0) + (props.mostrarSala ? 1 : 0) + (props.puedeEditar ? 1 : 0))

function ordenar(clave, alterna = 'fecha_desc') {
  emit('update:sortBy', props.sortBy === clave ? alterna : clave)
}
const ordena = computed(() => props.sortBy !== null)

function abrir(l) { router.push({ name: 'lote-detail', params: { id: l.id } }) }
</script>

<template>
  <table class="lt">
    <thead>
      <tr>
        <th v-if="seleccion" class="lt-th--cb">
          <input
            type="checkbox" class="lt-cb"
            :checked="seleccion.todo"
            :indeterminate.prop="seleccion.algo"
            :disabled="seleccion.deshabilitada"
            :title="seleccion.tituloTodo"
            @change="seleccion.alternarTodo()"
          />
        </th>
        <th class="lt-th--chev"><span class="visually-hidden">Fases</span></th>
        <th>Estado</th>
        <th :class="{ 'lt-th--sort': ordena }" @click="ordena && ordenar('codigo_asc')">
          Código <span v-if="ordena" class="lt-sort">{{ sortBy === 'codigo_asc' ? '↑' : '↕' }}</span>
        </th>
        <th>🌿 Genética</th>
        <th v-if="mostrarSala">📍 Sala</th>
        <th :class="{ 'lt-th--sort': ordena }" @click="ordena && ordenar('plantas_desc')">
          🪴 Plantas <span v-if="ordena" class="lt-sort">{{ sortBy === 'plantas_desc' ? '↓' : '↕' }}</span>
        </th>
        <th>🪣 Maceta</th>
        <th title="Días en la fase actual">⏱️ En fase</th>
        <th title="Fecha en que entró a la fase actual">📅 Desde</th>
        <th :class="{ 'lt-th--sort': ordena }" title="Días totales desde el inicio del lote"
            @click="ordena && ordenar(sortBy === 'fecha_asc' ? 'fecha_desc' : 'fecha_asc', 'fecha_asc')">
          Total <span v-if="ordena" class="lt-sort">{{ sortBy?.startsWith('fecha') ? (sortBy === 'fecha_asc' ? '↑' : '↓') : '↕' }}</span>
        </th>
        <th v-if="puedeEditar"></th>
      </tr>
    </thead>
    <tbody>
      <template v-for="l in lotes" :key="l.id">
        <tr class="lt-row" :class="{ 'lt-row--abierta': abiertos.has(l.id) }" @click="abrir(l)">
          <td v-if="seleccion" class="lt-td--cb" @click.stop>
            <input
              v-if="!seleccion.puede || seleccion.puede(l)"
              type="checkbox" class="lt-cb"
              :checked="seleccion.esta(l)"
              :disabled="seleccion.deshabilitada"
              :aria-label="`Seleccionar ${l.codigo}`"
              @change="seleccion.alternar(l)"
            />
          </td>
          <td class="lt-td--chev" @click.stop>
            <button type="button" class="lt-chev" :aria-expanded="abiertos.has(l.id)"
                    :title="abiertos.has(l.id) ? 'Ocultar días por fase' : 'Ver días por fase'"
                    @click="alternarDetalle(l.id)">
              <i class="bi" :class="abiertos.has(l.id) ? 'bi-chevron-down' : 'bi-chevron-right'"></i>
              <span class="lt-chev-txt">{{ abiertos.has(l.id) ? 'Ocultar fases' : 'Ver días por fase' }}</span>
            </button>
          </td>
          <td data-label="Estado">
            <span class="lt-estado">
              <span class="lt-badge" :style="{ background: em(l.estado).bg, color: em(l.estado).text }">
                {{ em(l.estado).icon }} {{ em(l.estado).label }}
              </span>
              <!-- Al pasar el mouse: los días de las fases que ya pasaron. -->
              <span class="lt-pop" role="tooltip">
                <template v-if="fasesPasadas(l).length">
                  <span class="lt-pop__tit">Fases anteriores</span>
                  <span v-for="(f, i) in fasesPasadas(l)" :key="i" class="lt-pop__fila">
                    <span>{{ em(f.estado).icon }} {{ em(f.estado).label }}</span>
                    <strong>{{ f.dias }} d</strong>
                  </span>
                </template>
                <span v-else class="lt-pop__vacio">Sin fases anteriores registradas</span>
              </span>
            </span>
          </td>
          <td data-label="Código">
            <span class="lt-codigo">{{ l.codigo }}</span>
          </td>
          <td data-label="Genética">
            <span v-if="l.genetica?.nombre" class="lt-genetica">{{ l.genetica.nombre }}<span v-if="l.automatica" class="chip-auto">Auto</span></span>
            <span v-else-if="l.strain" class="lt-strain">{{ l.strain }}</span>
            <span v-else class="lt-empty">—</span>
            <span v-if="l.genetica?.tipo" class="lt-tipo" :class="`lt-tipo--${l.genetica.tipo}`">{{ tipoLabel(l.genetica.tipo) }}</span>
          </td>
          <td v-if="mostrarSala" data-label="Sala">
            <span class="lt-sala">{{ salaCelda(l) }}</span>
          </td>
          <td data-label="Plantas">
            <span class="lt-num">{{ l.plants_count ?? 0 }}</span>
            <span v-if="l.estado === 'floracion' && l.plantas_cosechadas_count > 0" class="lt-sub">
              ✅ {{ l.plantas_cosechadas_count }} cosechadas
            </span>
          </td>
          <td data-label="Maceta">
            <span v-if="l.tamanio_maceta" class="lt-num">{{ l.tamanio_maceta }}L</span>
            <span v-else class="lt-empty">—</span>
          </td>
          <td data-label="En fase">
            <span v-if="l.dias_en_estado != null" class="lt-num">
              <span v-if="diasNivel(l)" class="lt-dot" :class="`lt-dot--${diasNivel(l)}`" :title="diasTitle(l)"></span>
              {{ l.dias_en_estado }}d
            </span>
            <span v-else class="lt-empty">—</span>
            <span v-if="textoProximoPasoCorto(l)" class="lt-prox" :class="{ 'lt-prox--ya': l.proximo_paso.faltan_dias <= 0 }" :title="textoProximoPaso(l)">{{ textoProximoPasoCorto(l) }}</span>
          </td>
          <td data-label="Desde">
            <span v-if="l.fecha_estado_actual" class="lt-num lt-num--muted">{{ fechaCorta(l.fecha_estado_actual) }}</span>
            <span v-else class="lt-empty">—</span>
          </td>
          <td data-label="Total">
            <span v-if="diasDesdeInicio(l.start_date) !== null" class="lt-num lt-num--muted">{{ diasDesdeInicio(l.start_date) }}d</span>
            <span v-else class="lt-empty">—</span>
          </td>
          <td v-if="puedeEditar" class="lt-td--acciones" @click.stop>
            <div class="lt-actions">
              <button class="lt-action" title="Editar" @click="emit('editar', l)"><i class="bi bi-pencil"></i></button>
              <button class="lt-action lt-action--danger" title="Eliminar" @click="emit('eliminar', l)"><i class="bi bi-trash"></i></button>
            </div>
          </td>
        </tr>

        <!-- Abierta: la línea de tiempo del lote, fase por fase, con sus días. -->
        <tr v-if="abiertos.has(l.id)" class="lt-detalle">
          <td :colspan="nCols">
            <div v-if="(l.fases || []).length" class="lt-fases">
              <div v-for="(f, i) in l.fases" :key="i" class="lt-fase" :class="{ 'lt-fase--actual': f.actual }"
                   :style="{ '--fase': em(f.estado).bar, flexGrow: Math.max(f.dias, 1) }">
                <span class="lt-fase__nom">{{ em(f.estado).icon }} {{ em(f.estado).label }}</span>
                <span class="lt-fase__dias">{{ f.dias }} d<template v-if="f.actual"> · ahora</template></span>
                <span class="lt-fase__fechas">{{ fechaCorta(f.desde) }} → {{ f.actual ? 'hoy' : fechaCorta(f.hasta) }}</span>
              </div>
            </div>
            <p v-else class="lt-fases-vacio">
              Sin cambios de fase registrados desde que se cargó el lote.
            </p>
          </td>
        </tr>
      </template>
    </tbody>
  </table>
</template>

<style scoped>
.lt { width: 100%; border-collapse: collapse; font-size: .875rem; }
.lt thead th { padding: 10px 12px; text-align: left; font-weight: 600; color: #6b7280; border-bottom: 2px solid #e5e7eb; white-space: nowrap; background: #fafafa; }
.lt-th--sort { cursor: pointer; user-select: none; }
.lt-th--sort:hover { color: #1b5e20; }
.lt-sort { font-size: .75rem; color: var(--c-slate-300); margin-left: .2rem; }
.lt-th--cb, .lt-td--cb { width: 34px; padding-right: 0 !important; }
.lt-th--chev, .lt-td--chev { width: 28px; padding-left: 0 !important; padding-right: 0 !important; }
.lt-cb { width: 15px; height: 15px; accent-color: #1b5e20; cursor: pointer; margin: 0; }
.lt-cb:disabled { cursor: default; opacity: .5; }

.lt-row { border-bottom: 1px solid #f3f4f6; transition: background .1s; cursor: pointer; }
.lt-row:hover { background: var(--c-slate-50); }
.lt-row--abierta { background: var(--c-slate-50); border-bottom-color: transparent; }
.lt td { padding: 10px 12px; vertical-align: middle; }

.lt-chev { background: none; border: none; padding: 4px; border-radius: 6px; color: var(--c-slate-400); cursor: pointer; line-height: 1; }
.lt-chev:hover { background: var(--c-slate-100); color: var(--c-slate-900); }
.lt-chev-txt { display: none; }

.lt-estado { position: relative; display: inline-block; }
.lt-badge { display: inline-flex; align-items: center; gap: .25rem; padding: 3px 8px; border-radius: 5px; font-size: .75rem; font-weight: 700; white-space: nowrap; }
.lt-pop {
  display: none; position: absolute; left: 0; top: calc(100% + 6px); z-index: 30;
  min-width: 190px; padding: .55rem .7rem; border-radius: 8px;
  background: var(--c-slate-900); color: #fff; font-size: .75rem; font-weight: 500;
  box-shadow: 0 6px 18px rgba(0, 0, 0, .18); flex-direction: column; gap: .2rem; cursor: default;
}
@media (hover: hover) {
  .lt-estado:hover .lt-pop { display: flex; }
}
.lt-pop__tit { font-size: .65rem; text-transform: uppercase; letter-spacing: .05em; color: var(--c-slate-400); margin-bottom: .1rem; }
.lt-pop__fila { display: flex; justify-content: space-between; gap: 1rem; white-space: nowrap; }
.lt-pop__vacio { color: var(--c-slate-300); white-space: nowrap; }

.lt-codigo { font-weight: 700; color: var(--c-slate-900); font-family: monospace; font-size: .85rem; }
.lt-genetica { font-weight: 600; color: #3F6452; }
.lt-strain { font-style: italic; color: var(--c-slate-500); }
.lt-tipo { display: inline-block; margin-left: .4rem; font-size: .62rem; font-weight: 700; text-transform: uppercase; letter-spacing: .04em; padding: .1em .45em; border-radius: 999px; vertical-align: middle; }
.lt-tipo--sativa { background: #fef3c7; color: #b45309; }
.lt-tipo--indica { background: #ede9fe; color: #6d28d9; }
.lt-tipo--hibrida { background: #dcfce7; color: #15803d; }
.lt-sala { color: var(--c-slate-500); font-size: .82rem; white-space: nowrap; }
.lt-num { font-weight: 600; color: #374151; white-space: nowrap; }
.lt-num--muted { color: var(--c-slate-500); }
.lt-sub { display: block; font-size: .7rem; color: var(--c-slate-500); white-space: nowrap; }
.lt-dot { display: inline-block; width: 7px; height: 7px; border-radius: 50%; margin-right: 5px; vertical-align: middle; }
.lt-dot--verde { background: #16a34a; }
.lt-dot--amarillo { background: #f59e0b; }
.lt-dot--rojo { background: #dc2626; }
.lt-prox { display: block; font-size: .7rem; font-weight: 600; color: var(--c-leaf-700, #2d4a3e); white-space: nowrap; }
.lt-prox--ya { color: var(--c-amber-700, #b45309); }
.lt-empty { color: var(--c-slate-300); }

.lt-actions { display: flex; align-items: center; gap: .25rem; opacity: 0; transition: opacity .15s; }
.lt-row:hover .lt-actions { opacity: 1; }
.lt-action { background: none; border: none; cursor: pointer; padding: 5px 7px; border-radius: 6px; color: #6b7280; font-size: .875rem; }
.lt-action:hover { background: var(--c-slate-100); color: var(--c-slate-900); }
.lt-action--danger:hover { background: #fef2f2; color: #dc2626; }

.lt-detalle { background: var(--c-slate-50); border-bottom: 1px solid #e5e7eb; }
.lt-detalle td { padding: 0 12px 12px 62px; }
.lt-fases { display: flex; gap: 4px; }
.lt-fase {
  flex-basis: 0; min-width: 104px; display: flex; flex-direction: column; gap: 1px;
  padding: .45rem .6rem; border-radius: 6px; background: #fff;
  border: 1px solid var(--c-slate-200); border-top: 3px solid var(--fase);
}
.lt-fase--actual { border-style: dashed; border-top-style: solid; }
.lt-fase__nom { font-size: .75rem; font-weight: 700; color: var(--c-slate-700); white-space: nowrap; }
.lt-fase__dias { font-size: .95rem; font-weight: 700; color: var(--c-slate-900); }
.lt-fase__fechas { font-size: .68rem; color: var(--c-slate-500); white-space: nowrap; }
.lt-fases-vacio { margin: 0; padding: .4rem 0; font-size: .8rem; color: var(--c-slate-500); }

/* Teléfono: cada lote es una tarjeta con sus datos rotulados. */
@media (max-width: 640px) {
  .lt { display: block; }
  .lt thead { display: none; }
  .lt tbody { display: flex; flex-direction: column; gap: .6rem; }
  .lt-row {
    display: flex; flex-direction: column; position: relative;
    background: #fff; border: 1px solid #e5e7eb; border-radius: 12px; padding: .875rem 1rem;
  }
  .lt-row--abierta { border-radius: 12px 12px 0 0; border-bottom: none; background: #fff; }
  .lt-row:hover { background: #fff; box-shadow: 0 2px 12px rgba(0,0,0,.07); }
  .lt td { display: flex; align-items: center; gap: .4rem; padding: .18rem 0; border: none; font-size: .84rem; min-width: 0; width: 100%; flex-wrap: wrap; }
  .lt td[data-label]::before {
    content: attr(data-label); font-size: .65rem; font-weight: 700; color: var(--c-slate-400);
    text-transform: uppercase; letter-spacing: .04em; min-width: 68px; flex-shrink: 0;
  }
  .lt td[data-label="Estado"], .lt td[data-label="Código"] { padding-right: 5rem; }
  .lt td[data-label="Estado"] { padding-bottom: .45rem; margin-bottom: .1rem; border-bottom: 1px solid var(--c-slate-100); }
  .lt td[data-label="Estado"]::before, .lt td[data-label="Código"]::before { content: none; }
  .lt-codigo { font-size: .95rem; }
  .lt-sub, .lt-prox { display: inline; }
  .lt-td--cb { position: absolute; top: .95rem; right: 5.4rem; width: auto !important; padding: 0 !important; }
  .lt-td--acciones { position: absolute; top: .75rem; right: .75rem; width: auto !important; padding: 0 !important; }
  .lt-actions { opacity: 1; }
  .lt-td--chev { order: 99; width: 100% !important; padding-top: .45rem !important; margin-top: .25rem; border-top: 1px solid var(--c-slate-100) !important; }
  .lt-chev { display: inline-flex; align-items: center; gap: .35rem; font-size: .78rem; font-weight: 600; color: var(--c-leaf-700, #2d4a3e); padding: .2rem 0; }
  .lt-chev-txt { display: inline; }
  .lt-detalle { display: block; background: #fff; border: 1px solid #e5e7eb; border-top: none; border-radius: 0 0 12px 12px; margin-top: -.6rem; }
  .lt-detalle td { display: block; padding: 0 1rem .875rem; }
  .lt-fases { flex-direction: column; }
  .lt-fase { flex-direction: row; align-items: baseline; flex-wrap: wrap; gap: .5rem; min-width: 0; flex-grow: 0 !important; }
}
</style>
