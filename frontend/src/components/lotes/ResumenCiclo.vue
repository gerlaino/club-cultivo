<template>
  <!-- «Cómo salió»: el cierre del ciclo en una tarjeta. Aparece cuando el lote ya está en curado
       o cerrado; antes no hay nada que resumir. Todo lo manda el backend (`Lotes::ResumenCiclo`):
       acá se le pone forma y, si hay ciclos anteriores de la misma genética, la diferencia. -->
  <div v-if="r && r.cerrado" class="rc">
    <div class="rc__head">
      <div>
        <div class="rc__title">Cómo salió</div>
        <div class="rc__sub">{{ r.estado === 'finalizado' ? 'Ciclo cerrado' : 'Curando · el ciclo terminó' }}<template v-if="r.anterior"> · vs. {{ r.anterior.lotes === 1 ? 'tu ciclo anterior' : `tus ${r.anterior.lotes} ciclos anteriores` }}{{ r.anterior.misma_genetica ? ' con esta genética' : ' (otras genéticas)' }}</template></div>
      </div>
      <!-- Bootstrap Icons, no emoji: el emoji depende de la fuente del teléfono. -->
      <span class="rc__ico"><i class="bi bi-flag-fill"></i></span>
    </div>

    <div class="rc__nums">
      <div class="rc__num">
        <span class="rc__num-v">{{ r.gramos != null ? fmt(r.gramos) : '—' }}<small>g</small></span>
        <span class="rc__num-l">secos</span>
      </div>
      <div class="rc__num">
        <span class="rc__num-v">{{ r.g_por_planta != null ? fmt(r.g_por_planta) : '—' }}<small>g</small></span>
        <span class="rc__num-l">por planta</span>
        <span v-if="delta(r.g_por_planta, r.anterior?.g_por_planta)" class="rc__delta" :class="deltaClase(r.g_por_planta, r.anterior?.g_por_planta, true)">{{ delta(r.g_por_planta, r.anterior?.g_por_planta) }}</span>
      </div>
      <div class="rc__num">
        <span class="rc__num-v">{{ r.dias?.total != null ? Math.round(r.dias.total) : '—' }}<small>días</small></span>
        <span class="rc__num-l">de ciclo</span>
        <span v-if="delta(r.dias?.total, r.anterior?.dias_total)" class="rc__delta" :class="deltaClase(r.dias?.total, r.anterior?.dias_total, false)">{{ delta(r.dias?.total, r.anterior?.dias_total) }}</span>
      </div>
      <!-- El número que el cultivador compara con la ficha del banco. Sin los metros del
           espacio no se inventa: se dice que faltan. -->
      <div class="rc__num">
        <span class="rc__num-v">{{ r.g_m2 != null ? fmt(r.g_m2) : '—' }}<small v-if="r.g_m2 != null">g/m²</small></span>
        <span class="rc__num-l">{{ r.g_m2 != null ? `en ${fmt(r.m2)} m²` : 'sin m² cargados' }}</span>
      </div>
      <div v-if="r.costo" class="rc__num">
        <span class="rc__num-v">{{ r.costo.por_gramo != null ? formatARS(r.costo.por_gramo) : '—' }}</span>
        <span class="rc__num-l">por gramo</span>
        <span v-if="delta(r.costo.por_gramo, r.anterior?.costo_por_gramo)" class="rc__delta" :class="deltaClase(r.costo.por_gramo, r.anterior?.costo_por_gramo, false)">{{ delta(r.costo.por_gramo, r.anterior?.costo_por_gramo) }}</span>
      </div>
    </div>

    <!-- Los días por fase, como barra: se ve de un vistazo dónde se fue el tiempo. -->
    <div v-if="fases.length" class="rc__fases">
      <div class="rc__barra">
        <span v-for="f in fases" :key="f.clave" class="rc__seg" :style="{ flex: f.dias, background: f.color }" :title="`${f.label}: ${f.dias} días`"></span>
      </div>
      <div class="rc__leyenda">
        <span v-for="f in fases" :key="f.clave" class="rc__ley"><i :style="{ background: f.color }"></i>{{ f.label }} {{ Math.round(f.dias) }}d</span>
      </div>
    </div>

    <div class="rc__detalle">
      <span>{{ r.plantas.cosechadas }} {{ r.plantas.cosechadas === 1 ? 'planta cosechada' : 'plantas cosechadas' }}<template v-if="r.plantas.no_prendieron"> · {{ r.plantas.no_prendieron }} no {{ r.plantas.no_prendieron === 1 ? 'prendió' : 'prendieron' }}</template></span>
      <span v-if="r.registros.total">{{ r.registros.riegos }} {{ r.registros.riegos === 1 ? 'riego' : 'riegos' }} · {{ r.registros.total }} {{ r.registros.total === 1 ? 'registro' : 'registros' }}</span>
      <span v-if="r.costo">{{ formatARS(r.costo.total) }} en total<template v-if="r.costo.nutricion"> · {{ formatARS(r.costo.nutricion) }} en nutrientes</template></span>
    </div>

    <!-- De dónde salió y a dónde llegó. -->
    <div v-if="r.fotos?.primera" class="rc__fotos">
      <figure class="rc__foto">
        <img :src="r.fotos.primera.url" :alt="`Día ${r.fotos.primera.dia}`" loading="lazy" />
        <figcaption>Día {{ r.fotos.primera.dia }}</figcaption>
      </figure>
      <figure v-if="r.fotos.ultima" class="rc__foto">
        <img :src="r.fotos.ultima.url" :alt="`Día ${r.fotos.ultima.dia}`" loading="lazy" />
        <figcaption>Día {{ r.fotos.ultima.dia }}</figcaption>
      </figure>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { getLoteResumenCiclo } from '../../lib/api.js'
import { formatARS } from '../../lib/formatters.js'

const props = defineProps({
  loteId: { type: Number, required: true },
  // El estado del lote, para no pedir el resumen mientras está en cultivo.
  estado: { type: String, default: '' },
})

const r = ref(null)
const CERRADOS = ['curado', 'finalizado']
async function cargar() {
  if (!CERRADOS.includes(props.estado)) { r.value = null; return }
  try { r.value = (await getLoteResumenCiclo(props.loteId)).data } catch { r.value = null }
}
onMounted(cargar)
watch(() => props.estado, cargar)

const fmt = (n) => Number(n).toLocaleString('es-AR', { maximumFractionDigits: 1 })

const FASES = [
  { clave: 'enraizado',   label: 'Enraizado', color: '#0891b2' },
  { clave: 'vegetativo',  label: 'Vege',      color: '#16a34a' },
  { clave: 'floracion',   label: 'Flora',     color: '#9333ea' },
  { clave: 'cosecha',     label: 'Secado',    color: '#d97706' },
  { clave: 'en_manicura', label: 'Manicura',  color: '#78350f' },
]
const fases = computed(() => {
  const d = r.value?.dias || {}
  const lista = FASES.filter(f => d[f.clave] > 0).map(f => ({ ...f, dias: d[f.clave] }))
  if (!r.value?.automatica) return lista
  // Automática: vege y flora (si la anotó) son un solo ciclo en pie; se muestran juntos.
  const enPie = lista.filter(f => ['vegetativo', 'floracion'].includes(f.clave))
  const resto = lista.filter(f => !['enraizado', 'vegetativo', 'floracion'].includes(f.clave))
  const enraiz = lista.filter(f => f.clave === 'enraizado')
  const ciclo = enPie.length ? [{ clave: 'ciclo', label: 'Ciclo', color: '#16a34a', dias: enPie.reduce((t, f) => t + f.dias, 0) }] : []
  return [...enraiz, ...ciclo, ...resto]
})

// «+12 %» contra el promedio anterior. `masEsMejor` decide el color: más gramos es bueno, más
// días o más pesos no.
function delta(ahora, antes) {
  if (ahora == null || !antes) return null
  const p = Math.round(((ahora - antes) / antes) * 100)
  if (p === 0) return 'igual'
  return `${p > 0 ? '+' : ''}${p} %`
}
function deltaClase(ahora, antes, masEsMejor) {
  if (ahora == null || !antes || ahora === antes) return ''
  const mejor = masEsMejor ? ahora > antes : ahora < antes
  return mejor ? 'rc__delta--bien' : 'rc__delta--mal'
}
</script>

<style scoped>
.rc { background: linear-gradient(160deg, #f0fdf4, #fff); border: 1px solid var(--c-leaf-100, #e8f0eb); border-radius: 16px; padding: 1rem; display: grid; gap: .85rem; }
.rc__head { display: flex; align-items: flex-start; justify-content: space-between; gap: .5rem; }
.rc__title { font-family: var(--font-display); font-weight: 800; font-size: 1.05rem; color: var(--c-ink-900, #1a1d1f); }
.rc__sub { font-size: .76rem; color: var(--c-ink-500, #6b7280); }
.rc__ico { width: 34px; height: 34px; border-radius: 10px; background: var(--c-leaf-100, #e8f0eb); color: var(--c-leaf-700, #2d4a3e); display: flex; align-items: center; justify-content: center; font-size: 1rem; flex-shrink: 0; }
.rc__nums { display: grid; grid-template-columns: repeat(auto-fit, minmax(110px, 1fr)); gap: .5rem; }
.rc__num { background: #fff; border: 1px solid var(--c-leaf-100, #e8f0eb); border-radius: 12px; padding: .6rem .5rem; display: flex; flex-direction: column; align-items: center; gap: .1rem; }
.rc__num-v { font-family: var(--font-display); font-weight: 800; font-size: 1.35rem; color: var(--c-leaf-800, #1b4332); font-variant-numeric: tabular-nums; }
.rc__num-v small { font-size: .7rem; font-weight: 600; margin-left: .15rem; color: var(--c-ink-500, #6b7280); }
.rc__num-l { font-size: .7rem; color: var(--c-ink-500, #6b7280); }
.rc__delta { font-size: .7rem; font-weight: 700; color: var(--c-ink-500, #6b7280); }
.rc__delta--bien { color: #15803d; }
.rc__delta--mal  { color: #b45309; }
.rc__fases { display: grid; gap: .35rem; }
.rc__barra { display: flex; height: 10px; border-radius: 999px; overflow: hidden; background: #e5e7eb; }
.rc__seg { display: block; min-width: 3px; }
.rc__leyenda { display: flex; flex-wrap: wrap; gap: .25rem .7rem; font-size: .7rem; color: var(--c-ink-500, #6b7280); }
.rc__ley i { display: inline-block; width: 8px; height: 8px; border-radius: 2px; margin-right: .3rem; vertical-align: middle; }
.rc__detalle { display: flex; flex-wrap: wrap; gap: .25rem .9rem; font-size: .78rem; color: var(--c-ink-700, #374151); }
.rc__fotos { display: grid; grid-template-columns: 1fr 1fr; gap: .5rem; }
.rc__foto { margin: 0; }
.rc__foto img { width: 100%; aspect-ratio: 1; object-fit: cover; border-radius: 10px; display: block; }
.rc__foto figcaption { font-size: .7rem; color: var(--c-ink-500, #6b7280); text-align: center; margin-top: .2rem; }
</style>
