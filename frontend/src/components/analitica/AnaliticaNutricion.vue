<template>
  <div class="anu">
    <!-- Qué lotes comparar -->
    <div class="an__card anu__selector">
      <div class="anu__elegidos">
        <span v-for="l in elegidos" :key="l.id" class="anu__chip" :style="{ borderColor: color(l.id) }">
          <span class="anu__dot" :style="{ background: color(l.id) }"></span>
          {{ l.codigo }}<small v-if="l.genetica"> · {{ l.genetica }}</small>
          <button type="button" class="anu__quitar" :aria-label="`Quitar ${l.codigo}`" @click="quitar(l.id)"><i class="bi bi-x"></i></button>
        </span>
        <select v-if="ids.length < MAXIMO" class="anu__agregar" value="" aria-label="Agregar un lote" @change="agregar($event.target.value); $event.target.value = ''">
          <option value="" disabled>{{ disponibles.length ? '＋ Agregar un lote…' : 'No hay más lotes con riegos o fertilizaciones' }}</option>
          <option v-for="l in disponibles" :key="l.id" :value="l.id">{{ l.codigo }} · {{ l.genetica || 'sin genética' }} · {{ l.estado_label }}</option>
        </select>
        <button v-if="mismaGenetica.length" type="button" class="anu__link" @click="sumarMismaGenetica">
          ＋ los de la misma genética ({{ mismaGenetica.length }})
        </button>
      </div>
      <p class="anu__hint">De 2 a {{ MAXIMO }} lotes con riegos o fertilizaciones registrados. Uno en curso entra igual, sin rendimiento.</p>
    </div>

    <div v-if="cargando && !data" class="an__empty">Cargando…</div>
    <div v-else-if="error" class="an__empty">{{ error }}</div>
    <div v-else-if="!ids.length" class="an__empty">
      Elegí los lotes a comparar. También se llega desde la ficha de un lote: Nutrición → «Comparar con otros lotes».
    </div>
    <template v-else-if="data">
      <div class="an__card">
        <div class="an__card-header">
          <span class="an__card-title">Lado a lado</span>
          <span class="an__card-hint">cantidades por planta; el total, abajo en gris. Lo compartido cuenta la parte de cada lote.</span>
        </div>
        <div class="an__table-wrap">
          <table class="an__table anu__tabla">
            <thead>
              <tr>
                <th></th>
                <th v-for="l in data.lotes" :key="l.id" class="an__th-r">
                  <RouterLink :to="`/lotes/${l.id}`" class="anu__lote"><span class="anu__dot" :style="{ background: color(l.id) }"></span>{{ l.codigo }}</RouterLink>
                </th>
              </tr>
            </thead>
            <tbody>
              <tr class="anu__grupo"><td :colspan="cols">El lote</td></tr>
              <tr><td>Genética</td><td v-for="l in data.lotes" :key="l.id" class="an__td-r">{{ l.genetica || '—' }}<small v-if="l.automatica"> · auto</small></td></tr>
              <tr><td>Dónde</td><td v-for="l in data.lotes" :key="l.id" class="an__td-r">{{ [l.sede, l.sala].filter(Boolean).join(' · ') || '—' }}</td></tr>
              <tr><td>Estado</td><td v-for="l in data.lotes" :key="l.id" class="an__td-r">{{ l.estado_label }}</td></tr>
              <tr><td>Plantas</td><td v-for="l in data.lotes" :key="l.id" class="an__td-r">{{ l.plantas }}</td></tr>
              <tr><td>Vegetativo</td><td v-for="l in data.lotes" :key="l.id" class="an__td-r">{{ dias(l.dias?.vegetativo) }}</td></tr>
              <tr><td>Floración</td><td v-for="l in data.lotes" :key="l.id" class="an__td-r">{{ dias(l.dias?.floracion) }}</td></tr>

              <tr class="anu__grupo"><td :colspan="cols">Lo que recibió</td></tr>
              <tr><td>Aplicaciones</td><td v-for="l in data.lotes" :key="l.id" class="an__td-r">{{ l.totales.aplicaciones }}<small v-if="l.totales.sin_cantidades" class="anu__gris" title="Cargadas como texto: no entran en las cantidades"> ({{ l.totales.sin_cantidades }} sin cantidades)</small></td></tr>
              <tr><td>Agua</td><td v-for="l in data.lotes" :key="l.id" class="an__td-r">
                <template v-if="l.totales.agua_l != null">{{ fmt(l.totales.agua_por_planta, 1) }} L/planta<small class="anu__total">{{ fmt(l.totales.agua_l, 1) }} L · {{ l.totales.riegos_con_volumen }} de {{ l.totales.riegos }} riegos con volumen</small></template>
                <span v-else class="anu__gris">sin volumen cargado</span>
              </td></tr>
              <tr><td>Solución</td><td v-for="l in data.lotes" :key="l.id" class="an__td-r">{{ fmt(l.totales.litros_por_planta, 2) }} L/planta<small class="anu__total">{{ fmt(l.totales.litros, 1) }} L</small></td></tr>
              <tr v-for="p in data.productos" :key="p.clave">
                <td>{{ p.nombre }}</td>
                <td v-for="l in data.lotes" :key="l.id" class="an__td-r">
                  <template v-if="l.por_producto[p.clave]">
                    {{ fmt(l.por_producto[p.clave].por_planta, 2) }} {{ u(p.unidad) }}
                    <small class="anu__total">{{ fmt(l.por_producto[p.clave].cantidad, 1) }} {{ u(p.unidad) }} · {{ l.por_producto[p.clave].veces }}×</small>
                  </template>
                  <span v-else class="anu__gris">—</span>
                </td>
              </tr>
              <tr><td>EC en vege</td><td v-for="l in data.lotes" :key="l.id" class="an__td-r">{{ fmt(l.por_fase?.vegetativo?.ec, 2) }}</td></tr>
              <tr><td>EC en floración</td><td v-for="l in data.lotes" :key="l.id" class="an__td-r">{{ fmt(l.por_fase?.floracion?.ec, 2) }}</td></tr>
              <tr><td>pH promedio</td><td v-for="l in data.lotes" :key="l.id" class="an__td-r">{{ fmt(l.totales.ph, 2) }}</td></tr>

              <template v-if="data.con_costo">
                <tr class="anu__grupo"><td :colspan="cols">Lo que costó</td></tr>
                <tr><td>Nutrientes</td><td v-for="l in data.lotes" :key="l.id" class="an__td-r">{{ ars(l.totales.costo_ars) }}</td></tr>
                <tr><td>Por planta</td><td v-for="l in data.lotes" :key="l.id" class="an__td-r">{{ ars(l.totales.costo_por_planta) }}</td></tr>
                <tr><td>Por gramo</td><td v-for="l in data.lotes" :key="l.id" class="an__td-r">{{ l.totales.costo_por_gramo != null ? ars(l.totales.costo_por_gramo) : '—' }}</td></tr>
              </template>

              <tr class="anu__grupo"><td :colspan="cols">Cómo rindió</td></tr>
              <tr><td>Flor seca</td><td v-for="l in data.lotes" :key="l.id" class="an__td-r">{{ l.rendimiento_g != null ? `${fmt(l.rendimiento_g)} g` : 'en curso' }}</td></tr>
              <tr><td>g/planta</td><td v-for="l in data.lotes" :key="l.id" class="an__td-r anu__fuerte">{{ fmt(l.g_por_planta) }}</td></tr>
              <tr><td>g/m²</td><td v-for="l in data.lotes" :key="l.id" class="an__td-r">{{ fmt(l.g_m2) }}</td></tr>
            </tbody>
          </table>
        </div>
      </div>

      <div class="an__card">
        <div class="an__card-header">
          <span class="an__card-title">Por semana
            <span class="anu__curvas">
              <button v-for="c in CURVAS" :key="c.id" type="button" class="anu__curva" :class="{ 'anu__curva--on': curva === c.id }" @click="curva = c.id">{{ c.label }}</button>
            </span>
          </span>
          <span class="an__card-hint">semana de la fase: V3 = tercera de vege, F2 = segunda de floración. Alineadas al arranque de la floración.</span>
        </div>
        <div v-if="!data.semanas.length" class="an__empty">Ninguno de estos lotes tiene EC ni volumen de agua cargados.</div>
        <div v-else class="anu__chart"><canvas ref="canvas" /></div>
      </div>
    </template>
  </div>
</template>

<script setup>
// ¿QUÉ RECIBIÓ CADA LOTE Y CÓMO RINDIÓ? (29-sep-2026). Todo lo calcula el backend
// (`Analitica::Nutricion`, que lee `Lotes::Nutricion` de cada lote); acá se elige qué lotes y se
// presenta. Los lotes elegidos viajan en la URL (`?lotes=12,15`): la ficha del lote llega así.
import { ref, computed, watch, onMounted, onBeforeUnmount, nextTick } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import Chart from 'chart.js/auto'
import { getAnaliticaNutricion, getAnaliticaNutricionLotes } from '../../lib/api.js'

const MAXIMO = 4
// Qué se dibuja por semana: la EC medida o el agua por planta (`por_semana` del backend).
const CURVAS = [{ id: 'ec', label: 'EC', campo: 'ec', eje: 'EC' }, { id: 'agua', label: 'Agua', campo: 'agua_por_planta', eje: 'L/planta' }]
const curva = ref('ec')
const route = useRoute()
const router = useRouter()

const candidatos = ref([])
const ids = ref(String(route.query.lotes || '').split(',').map(Number).filter(Boolean).slice(0, MAXIMO))
const data = ref(null)
const cargando = ref(false)
const error = ref(null)
const canvas = ref(null)
let chart = null

const elegidos = computed(() => ids.value.map(id => candidatos.value.find(l => l.id === id) || data.value?.lotes?.find(l => l.id === id) || { id, codigo: `#${id}` }))
const disponibles = computed(() => candidatos.value.filter(l => !ids.value.includes(l.id)))
const mismaGenetica = computed(() => {
  const gens = new Set(elegidos.value.map(l => l.genetica_id ?? candidatos.value.find(c => c.id === l.id)?.genetica_id).filter(Boolean))
  return disponibles.value.filter(l => gens.has(l.genetica_id)).slice(0, MAXIMO - ids.value.length)
})
const cols = computed(() => (data.value?.lotes?.length || 0) + 1)

function agregar(id) { if (id && ids.value.length < MAXIMO) ids.value = [...ids.value, Number(id)] }
function quitar(id) { ids.value = ids.value.filter(x => x !== id) }
function sumarMismaGenetica() { ids.value = [...ids.value, ...mismaGenetica.value.map(l => l.id)].slice(0, MAXIMO) }

async function cargar() {
  router.replace({ query: { ...route.query, lotes: ids.value.join(',') || undefined } })
  if (!ids.value.length) { data.value = null; return }
  cargando.value = true
  try {
    const { data: d } = await getAnaliticaNutricion({ lote_ids: ids.value })
    data.value = d
    error.value = null
    await nextTick()
    dibujar()
  } catch { error.value = 'No se pudo cargar la comparación.' }
  finally { cargando.value = false }
}
watch(ids, cargar)
watch(curva, dibujar)
onMounted(async () => {
  try { candidatos.value = (await getAnaliticaNutricionLotes()).data?.lotes || [] } catch { candidatos.value = [] }
  cargar()
})
onBeforeUnmount(() => chart?.destroy())

// Colores de la paleta (tokens), uno por lote, en el orden elegido.
const TOKENS = ['--c-leaf-600', '--c-sky-600', '--c-amber-500', '--c-rust-600']
function color(id) {
  const i = Math.max(0, ids.value.indexOf(id))
  if (typeof window === 'undefined') return ''
  return getComputedStyle(document.documentElement).getPropertyValue(TOKENS[i % TOKENS.length]).trim() || `var(${TOKENS[i % TOKENS.length]})`
}

function dibujar() {
  chart?.destroy(); chart = null
  if (!canvas.value || !data.value?.semanas?.length) return
  const labels = data.value.semanas
  const c = CURVAS.find(x => x.id === curva.value)
  chart = new Chart(canvas.value, {
    type: 'line',
    data: {
      labels,
      datasets: data.value.lotes.map(l => {
        const porSemana = Object.fromEntries(l.por_semana.map(w => [w.semana_label, w[c.campo]]))
        return { label: l.codigo, data: labels.map(s => porSemana[s] ?? null), borderColor: color(l.id), backgroundColor: color(l.id),
                 borderWidth: 2, pointRadius: 3, tension: 0.3, spanGaps: true }
      }),
    },
    options: { responsive: true, maintainAspectRatio: false, plugins: { legend: { position: 'bottom' } },
               scales: { y: { title: { display: true, text: c.eje } } } },
  })
}

// El CSV de la solapa (lo pide AnaliticaView): una fila por dato, una columna por lote.
function csv() {
  const d = data.value
  if (!d) return { headers: [], rows: [] }
  const L = d.lotes
  const fila = (nombre, f) => [nombre, ...L.map(f)]
  const rows = [
    fila('Genética', l => l.genetica), fila('Plantas', l => l.plantas),
    fila('Días vegetativo', l => l.dias?.vegetativo), fila('Días floración', l => l.dias?.floracion),
    fila('Aplicaciones', l => l.totales.aplicaciones), fila('Agua (L)', l => l.totales.agua_l), fila('Agua L/planta', l => l.totales.agua_por_planta),
    fila('Litros de solución', l => l.totales.litros),
    fila('L/planta', l => l.totales.litros_por_planta),
    ...d.productos.map(p => fila(`${p.nombre} (${u(p.unidad)} total)`, l => l.por_producto[p.clave]?.cantidad)),
    fila('EC vege', l => l.por_fase?.vegetativo?.ec), fila('EC floración', l => l.por_fase?.floracion?.ec), fila('pH', l => l.totales.ph),
    ...(d.con_costo ? [fila('$ nutrientes', l => l.totales.costo_ars), fila('$/planta', l => l.totales.costo_por_planta), fila('$/g', l => l.totales.costo_por_gramo)] : []),
    fila('Flor seca (g)', l => l.rendimiento_g), fila('g/planta', l => l.g_por_planta), fila('g/m²', l => l.g_m2),
  ]
  return { headers: ['', ...L.map(l => l.codigo)], rows }
}
defineExpose({ csv })

const U = { mililitro: 'ml', gramo: 'g', litro: 'L', kilogramo: 'kg', unidad: 'u' }
const u = x => U[x] || x || ''
const fmt = (n, d = 1) => (n == null ? '—' : Number(n).toLocaleString('es-AR', { maximumFractionDigits: d }))
const ars = n => (n == null ? '—' : `$ ${Math.round(Number(n)).toLocaleString('es-AR')}`)
const dias = n => (n == null ? '—' : `${Math.round(n)} d`)
</script>

<style scoped>
/* Las de la analítica (AnaliticaView las tiene `scoped`: no llegan a este componente). */
.an__empty { color: var(--c-slate-500); font-size: .875rem; background: var(--c-slate-50); padding: 2rem; text-align: center; border-radius: 10px; }
.an__card { background: #fff; border: 1px solid var(--c-slate-200); border-radius: 14px; overflow: hidden; }
.an__card-header { display: flex; align-items: baseline; justify-content: space-between; gap: 1rem; flex-wrap: wrap; padding: .875rem 1.1rem; border-bottom: 1px solid var(--c-slate-100); background: var(--c-slate-50); }
.an__card-title { font-size: .875rem; font-weight: 700; color: var(--c-slate-900); }
.an__card-hint { font-size: .74rem; color: var(--c-slate-500); }
.an__table-wrap { overflow-x: auto; }
.an__table { width: 100%; border-collapse: collapse; font-size: .82rem; }
.an__table th { text-align: left; padding: .65rem 1rem; background: var(--c-slate-50); font-weight: 600; color: var(--c-slate-500); font-size: .7rem; text-transform: uppercase; letter-spacing: .04em; border-bottom: 1.5px solid var(--c-slate-100); white-space: nowrap; }
.an__th-r, .an__td-r { text-align: right; font-variant-numeric: tabular-nums; white-space: nowrap; }
.an__table td { padding: .7rem 1rem; border-bottom: 1px solid var(--c-slate-50); color: var(--c-slate-900); vertical-align: top; }
.an__table tbody tr:last-child td { border-bottom: none; }
.an__table--compact td, .an__table--compact th { padding: .5rem .75rem; }
.anu > * + * { margin-top: 1rem; }
.anu__selector { padding: .85rem 1rem; }
.anu__elegidos { display: flex; flex-wrap: wrap; gap: .5rem; align-items: center; }
.anu__chip { display: inline-flex; align-items: center; gap: .35rem; border: 1.5px solid var(--c-slate-300); border-radius: 999px; padding: .2rem .35rem .2rem .6rem; font-size: .82rem; font-weight: 600; background: var(--c-leaf-50); }
.anu__chip small { font-weight: 400; color: var(--c-slate-500); }
.anu__dot { width: 9px; height: 9px; border-radius: 50%; display: inline-block; flex-shrink: 0; }
.anu__quitar { background: none; border: none; color: var(--c-slate-500); cursor: pointer; padding: 0 .1rem; }
.anu__agregar { border: 1.5px dashed var(--c-slate-300); border-radius: 999px; padding: .25rem .6rem; font-size: .82rem; background: var(--c-slate-50); color: var(--c-ink-700); max-width: 100%; }
.anu__link { background: none; border: none; color: var(--c-leaf-700); font-weight: 600; font-size: .8rem; cursor: pointer; }
.anu__hint { margin: .5rem 0 0; font-size: .75rem; color: var(--c-slate-500); }
.anu__tabla td:first-child { color: var(--c-slate-600); white-space: nowrap; }
.anu__grupo td { background: var(--c-leaf-50); font-size: .7rem; font-weight: 700; text-transform: uppercase; letter-spacing: .04em; color: var(--c-leaf-700) !important; }
.anu__lote { display: inline-flex; align-items: center; gap: .35rem; color: var(--c-ink-900); text-decoration: none; font-weight: 700; }
.anu__total { display: block; font-size: .7rem; color: var(--c-slate-400); }
.anu__gris { color: var(--c-slate-400); }
.anu__fuerte { font-weight: 700; }
.anu__curvas { display: inline-flex; gap: .25rem; margin-left: .6rem; }
.anu__curva { border: 1px solid var(--c-slate-200); background: var(--c-slate-50); border-radius: 999px; padding: .05rem .55rem; font-size: .72rem; font-weight: 600; color: var(--c-slate-500); cursor: pointer; }
.anu__curva--on { background: var(--c-leaf-700); border-color: var(--c-leaf-700); color: var(--c-leaf-50); }
.anu__chart { position: relative; height: 280px; padding: .5rem 1rem 1rem; }
</style>
