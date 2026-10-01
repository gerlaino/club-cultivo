<template>
  <div class="lns">
    <div v-if="cargando && !data" class="lns__vacio">Cargando…</div>
    <div v-else-if="error" class="lns__vacio">{{ error }}</div>
    <!-- Vacío sólo si no hay NADA: un lote regado con agua sola igual tiene qué mostrar. -->
    <div v-else-if="!data?.aplicaciones?.length && data?.totales?.agua_l == null" class="lns__vacio">
      Todavía no se registró ningún riego con volumen ni fertilización. Se carga al regar: «Registrar lote» → Riego.
    </div>
    <template v-else>
      <!-- El resumen: qué recibió en todo el ciclo -->
      <div class="lns__stats">
        <div class="lns__stat"><span class="lns__stat-n">{{ t.aplicaciones }}</span><span class="lns__stat-l">{{ t.aplicaciones === 1 ? 'fertilización' : 'fertilizaciones' }}</span></div>
        <div v-if="t.aplicaciones" class="lns__stat">
          <span class="lns__stat-n">{{ num(t.litros) }} L</span>
          <span class="lns__stat-l">de solución<template v-if="t.litros_por_planta != null"> · {{ num(t.litros_por_planta) }} L/planta</template></span>
        </div>
        <div v-if="t.agua_l != null" class="lns__stat">
          <span class="lns__stat-n">{{ num(t.agua_l) }} L</span>
          <span class="lns__stat-l">de agua<template v-if="t.agua_por_planta != null"> · {{ num(t.agua_por_planta) }} L/planta</template></span>
        </div>
        <div v-if="t.ec != null" class="lns__stat"><span class="lns__stat-n">{{ num(t.ec) }}</span><span class="lns__stat-l">EC promedio</span></div>
        <div v-if="t.ph != null" class="lns__stat"><span class="lns__stat-n">{{ num(t.ph) }}</span><span class="lns__stat-l">pH promedio</span></div>
        <div v-if="data.con_costo && t.aplicaciones" class="lns__stat">
          <span class="lns__stat-n">{{ formatARS(t.costo_ars) }}</span>
          <span class="lns__stat-l">en nutrientes<template v-if="t.costo_por_planta != null"> · {{ formatARS(t.costo_por_planta) }}/planta</template><template v-if="t.costo_por_gramo != null"> · {{ formatARS(t.costo_por_gramo) }}/g</template></span>
        </div>
      </div>

      <div v-if="t.productos.length" class="lns__bloque">
        <div class="lns__sub">Total por producto</div>
        <div class="lns__tabla-wrap">
          <table class="lns__tabla">
            <thead><tr><th>Producto</th><th class="r">Total</th><th class="r">Por planta</th><th class="r">Veces</th></tr></thead>
            <tbody>
              <tr v-for="p in t.productos" :key="p.nombre + p.unidad">
                <td>{{ p.nombre }}<span v-if="p.sin_descontar > 0" class="lns__salvedad" :title="`${num(p.sin_descontar)} ${u(p.unidad)} no salieron del depósito`"> · {{ num(p.sin_descontar) }} {{ u(p.unidad) }} sin descontar</span></td>
                <td class="r">{{ num(p.cantidad) }} {{ u(p.unidad) }}</td>
                <td class="r">{{ p.por_planta != null ? `${num(p.por_planta)} ${u(p.unidad)}` : '—' }}</td>
                <td class="r">{{ p.veces }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <div v-if="fases.length > 1" class="lns__bloque">
        <div class="lns__sub">Por fase</div>
        <div class="lns__tabla-wrap">
          <table class="lns__tabla">
            <thead><tr><th>Fase</th><th class="r">Aplic.</th><th class="r">Agua</th><th class="r">Solución</th><th class="r">EC</th><th class="r">pH</th><th v-if="data.con_costo" class="r">$</th></tr></thead>
            <tbody>
              <tr v-for="f in fases" :key="f.fase">
                <td>{{ FASE_LABEL[f.fase] || f.fase }}</td>
                <td class="r">{{ f.aplicaciones }}</td>
                <td class="r">{{ f.agua_l != null ? `${num(f.agua_l)} L` : '—' }}</td>
                <td class="r">{{ num(f.litros) }} L</td>
                <td class="r">{{ f.ec != null ? num(f.ec) : '—' }}</td>
                <td class="r">{{ f.ph != null ? num(f.ph) : '—' }}</td>
                <td v-if="data.con_costo" class="r">{{ formatARS(f.costo_ars) }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <p v-if="t.aplicaciones || t.riegos_con_volumen < t.riegos" class="lns__nota">
        Agua: todo lo regado, con o sin nutrientes<template v-if="t.riegos_con_volumen < t.riegos"> ({{ t.riegos_con_volumen }} de {{ t.riegos }} riegos tienen el volumen cargado)</template>.
        Solución: lo preparado con receta o productos sueltos.
        Lo compartido (la sala regada entera, la cama) cuenta la parte de este lote.
        <template v-if="t.sin_cantidades"> {{ t.sin_cantidades }} {{ t.sin_cantidades === 1 ? 'fertilización quedó' : 'fertilizaciones quedaron' }} como texto, sin cantidades.</template>
      </p>

      <!-- Aplicación por aplicación, plegado -->
      <button v-if="data.aplicaciones.length" type="button" class="lns__toggle" @click="abierto = !abierto">
        <i :class="abierto ? 'bi bi-chevron-down' : 'bi bi-chevron-right'"></i>
        Ver las {{ data.aplicaciones.length }} aplicaciones una por una
      </button>
      <div v-if="abierto" class="lns__lista">
        <div v-for="a in data.aplicaciones" :key="a.fuente + a.id" class="lns__app">
          <div class="lns__app-head">
            <span class="lns__sem">{{ a.semana_label }}</span>
            <span class="lns__app-tit">{{ a.titulo }}</span>
            <span v-if="a.litros" class="lns__app-meta">{{ num(a.litros) }} L<template v-if="a.parte < 1"> (su parte)</template></span>
            <span class="lns__app-fecha">{{ formatDate(a.fecha) }}</span>
          </div>
          <div v-if="a.productos.length" class="lns__app-prods">
            <span v-for="p in a.productos" :key="p.nombre" class="lns__prod" :class="{ 'lns__prod--sin': p.motivo }">
              {{ p.nombre }} {{ num(p.cantidad) }} {{ u(p.unidad) }}<template v-if="p.motivo"> · sin descontar: {{ p.motivo_label }}</template>
            </span>
          </div>
          <div v-else-if="a.texto" class="lns__app-texto">{{ a.texto }} <span class="lns__app-meta">(sin cantidades)</span></div>
          <div v-if="a.ec != null || a.ph != null" class="lns__app-meta">
            <template v-if="a.ec != null">EC {{ num(a.ec) }}<template v-if="a.ec_objetivo"> (objetivo {{ num(a.ec_objetivo) }})</template></template>
            <template v-if="a.ph != null"> · pH {{ num(a.ph) }}<template v-if="a.ph_objetivo"> (objetivo {{ num(a.ph_objetivo) }})</template></template>
          </div>
        </div>
      </div>

      <!-- La analítica es de administración (el backend la cierra al resto): no se ofrece. -->
      <RouterLink v-if="veAnalitica && conComparar" :to="{ path: '/analitica', query: { tab: 'nutricion', lotes: String(loteId) } }" class="lns__comparar">
        Comparar con otros lotes <i class="bi bi-arrow-right"></i>
      </RouterLink>
    </template>
  </div>
</template>

<script setup>
// «¿Qué recibió este lote?»: cada aplicación de nutrientes y los totales. Todo lo calcula el
// backend (`Lotes::Nutricion`): la parte de lo compartido, la semana de la fase, la salvedad de
// lo que no se descontó y si se ve la plata. Acá sólo se muestra.
import { ref, computed, watch, onMounted } from 'vue'
import { getLoteNutricion } from '../../lib/api.js'
import { formatARS } from '../../lib/formatters.js'
import { useRecargaEnCambios } from '../../composables/useRecargaEnCambios.js'
import { useAuthStore } from '../../stores/auth'

const props = defineProps({
  loteId:  { type: [Number, String], required: true },
  // Cambia cuando se recarga el historial (se registró algo): se vuelve a pedir.
  version: { type: [Array, Number, String, Object], default: null },
  // En el teléfono no se ofrece: la Analítica es una pantalla de escritorio.
  conComparar: { type: Boolean, default: true },
})

const data = ref(null)
const cargando = ref(false)
const error = ref(null)
const abierto = ref(false)
const auth = useAuthStore()
const veAnalitica = computed(() => ['admin', 'supervisor'].includes(auth.user?.role))

async function cargar() {
  cargando.value = true
  try {
    const { data: d } = await getLoteNutricion(props.loteId)
    data.value = d
    error.value = null
  } catch { error.value = 'No se pudo cargar la nutrición del lote' }
  finally { cargando.value = false }
}
onMounted(cargar)
watch(() => props.version, cargar)
useRecargaEnCambios(['ambiente', 'camas'], cargar)

const t = computed(() => data.value?.totales || {})
const ORDEN = ['enraizado', 'vegetativo', 'floracion', 'cosecha', 'en_manicura', 'curado']
const FASE_LABEL = { enraizado: 'Enraizado', vegetativo: 'Vegetativo', floracion: 'Floración', cosecha: 'Secado', en_manicura: 'Manicura', curado: 'Curado' }
const fases = computed(() => Object.entries(data.value?.por_fase || {})
  .map(([fase, v]) => ({ fase, ...v }))
  .sort((a, b) => ORDEN.indexOf(a.fase) - ORDEN.indexOf(b.fase)))

const U = { mililitro: 'ml', gramo: 'g', litro: 'L', kilogramo: 'kg', unidad: 'u' }
const u = x => U[x] || x || ''
const num = v => (v == null ? '—' : Number(v).toLocaleString('es-AR', { maximumFractionDigits: 2 }))
const formatDate = d => (d ? new Date(d).toLocaleDateString('es-AR', { day: 'numeric', month: 'short' }) : '')
</script>

<style scoped>
.lns { padding: .25rem 0; }
.lns__vacio { color: var(--c-slate-500); font-size: .85rem; padding: .5rem 0; }
.lns__stats { display: grid; grid-template-columns: repeat(auto-fit, minmax(130px, 1fr)); gap: .5rem; margin-bottom: 1rem; }
.lns__stat { background: var(--c-leaf-50); border: 1px solid var(--c-leaf-100); border-radius: 10px; padding: .55rem .7rem; display: flex; flex-direction: column; }
.lns__stat-n { font-size: 1.05rem; font-weight: 700; color: var(--c-leaf-800); }
.lns__stat-l { font-size: .72rem; color: var(--c-slate-500); }
.lns__bloque { margin-bottom: 1rem; }
.lns__sub { font-size: .75rem; font-weight: 700; text-transform: uppercase; letter-spacing: .04em; color: var(--c-slate-500); margin-bottom: .35rem; }
.lns__tabla-wrap { overflow-x: auto; }
.lns__tabla { width: 100%; border-collapse: collapse; font-size: .82rem; }
.lns__tabla th { text-align: left; font-weight: 600; color: var(--c-slate-500); font-size: .72rem; padding: .3rem .4rem; border-bottom: 1px solid var(--c-slate-200); }
.lns__tabla td { padding: .35rem .4rem; border-bottom: 1px solid var(--c-slate-100); color: var(--c-ink-900); }
.lns__tabla .r { text-align: right; white-space: nowrap; }
.lns__salvedad { color: var(--c-amber-500); font-size: .75rem; }
.lns__nota { font-size: .74rem; color: var(--c-slate-500); margin: 0 0 .75rem; }
.lns__toggle { display: flex; align-items: center; gap: .35rem; background: none; border: none; color: var(--c-leaf-700); font-weight: 600; font-size: .82rem; cursor: pointer; padding: .25rem 0; }
.lns__lista { display: flex; flex-direction: column; gap: .5rem; margin: .5rem 0 .75rem; }
.lns__app { border: 1px solid var(--c-slate-200); border-radius: 10px; padding: .5rem .65rem; }
.lns__app-head { display: flex; align-items: baseline; gap: .5rem; flex-wrap: wrap; }
.lns__sem { font-size: .7rem; font-weight: 700; color: var(--c-leaf-700); background: var(--c-leaf-100); border-radius: 6px; padding: .05rem .4rem; }
.lns__app-tit { font-weight: 600; font-size: .85rem; color: var(--c-ink-900); }
.lns__app-fecha { margin-left: auto; font-size: .72rem; color: var(--c-slate-400); }
.lns__app-meta { font-size: .75rem; color: var(--c-slate-500); }
.lns__app-prods { display: flex; flex-wrap: wrap; gap: .3rem; margin-top: .35rem; }
.lns__prod { font-size: .75rem; background: var(--c-slate-50); border: 1px solid var(--c-slate-200); border-radius: 999px; padding: .1rem .5rem; color: var(--c-ink-700); }
.lns__prod--sin { background: var(--c-amber-100); border-color: var(--c-amber-100); color: var(--c-gold-500); }
.lns__app-texto { font-size: .8rem; color: var(--c-ink-700); margin-top: .3rem; }
.lns__comparar { display: flex; width: fit-content; margin-top: .6rem; align-items: center; gap: .35rem; font-size: .82rem; font-weight: 600; color: var(--c-leaf-700); text-decoration: none; }
</style>
