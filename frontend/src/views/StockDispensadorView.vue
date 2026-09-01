<template>
  <div class="sdv">
    <div class="sdv__toolbar">
      <div class="sdv__toolbar-left">
        <h1 class="sdv__title">Stock</h1>
        <div v-if="liveConectado" class="sdv__live-dot" title="Actualización en tiempo real activa">● en vivo</div>
      </div>
      <div class="sdv__filters">
        <select v-model="filtroForma" class="sdv__select">
          <option value="">Todos los productos</option>
          <option v-for="f in FORMAS" :key="f.value" :value="f.value">{{ f.label }}</option>
        </select>
      </div>
    </div>

    <div v-if="loading" class="sdv__skel-list">
      <div class="sdv__skel" v-for="n in 6" :key="n" />
    </div>

    <div v-else-if="!stocksFiltrados.length" class="sdv__empty">Sin stock disponible.</div>

    <div v-else class="sdv__table-wrap">
      <table class="sdv__table tabla-cards">
        <thead>
          <tr>
            <th>Producto</th>
            <th>Genética</th>
            <th>Lote</th>
            <th>Sede</th>
            <th class="sdv__th-ing">Ingresó</th>
            <th class="sdv__th-num">Disponible</th>
            <th class="sdv__th-num">Comprometido</th>
            <th class="sdv__th-num">P. sugerido</th>
            <th>Vencimiento</th>
            <!-- Lo que se escribió al ingresar el producto. El alta ya lo llama "observaciones"
                 (se guarda en `descripcion`) y la API siempre lo mandó: se cargaba y no se leía
                 en ningún lado. -->
            <th class="sdv__th-obs">Observaciones</th>
            <th></th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="s in stocksFiltrados" :key="s.id" :class="{ 'sdv__tr--flash': flashIds.has(s.id) }">
            <td class="sdv__td-forma" data-col="Producto">
              <div class="sdv__forma-main">
                {{ formaLabel(s.forma_producto) }}
                <span class="sdv__chip" :class="s.regulatorio ? 'sdv__chip--propio' : 'sdv__chip--externo'">
                  {{ s.regulatorio ? 'Propio' : 'Externo' }}
                </span>
              </div>
              <span v-if="s.numero_lote_producto" class="sdv__codigo">{{ s.numero_lote_producto }}</span>
            </td>
            <td class="sdv__td-cepa" data-col="Genética">{{ s.genetica?.nombre ?? s.lote?.genetica?.nombre ?? '—' }}</td>
            <td class="sdv__td-mono" data-col="Lote">{{ s.lote_codigo ?? s.lote?.codigo ?? '—' }}</td>
            <td data-col="Sede">{{ s.sede?.nombre ?? '—' }}</td>
            <td class="sdv__td-ing" data-col="Ingresó">{{ fmtIngreso(s.created_at) }}</td>
            <td class="sdv__td-num" data-col="Disponible" :class="{ 'sdv__td-bajo': s.cantidad_disponible_real < 5 }">
              <div class="sdv__cant">{{ fmtCant(s.cantidad_disponible_real ?? s.cantidad) }}<span class="sdv__unidad">{{ s.unidad }}</span></div>
              <span v-if="mostrarInicial(s)" class="sdv__td-inicial">de {{ fmtCant(s.cantidad_inicial) }}{{ s.unidad }}</span>
            </td>
            <td class="sdv__td-num" data-col="Comprometido">
              <span v-if="s.gramos_reservados > 0" class="sdv__badge-reservado" :title="`${s.gramos_reservados}g comprometidos en delivery`">
                −{{ fmtCant(s.gramos_reservados) }}g
              </span>
              <span v-else class="sdv__none">—</span>
            </td>
            <td class="sdv__td-num" data-col="P. sugerido">{{ formatARS(s.precio_sugerido_ars) }}/{{ s.unidad }}</td>
            <td data-col="Vencimiento">
              <span v-if="s.estado_vencimiento && s.estado_vencimiento !== 'ok'" class="sdv__badge-venc" :class="`sdv__badge-venc--${s.estado_vencimiento}`">
                {{ badgeVencimiento(s) }}
              </span>
              <span v-else-if="s.fecha_vencimiento_est" class="sdv__none">{{ fmtFecha(s.fecha_vencimiento_est) }}</span>
              <span v-else class="sdv__none">—</span>
            </td>
            <td class="sdv__td-obs" data-col="Observaciones">
              <span v-if="s.descripcion" :title="s.descripcion">{{ s.descripcion }}</span>
              <span v-else class="sdv__none">—</span>
            </td>
            <td class="sdv__td-etiqueta" data-col="Etiqueta">
              <RouterLink :to="{ name: 'stock-etiqueta', params: { id: s.id } }" class="sdv__etiqueta-link" title="Ver etiqueta">🏷️</RouterLink>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { RouterLink } from 'vue-router'
import { listStocks } from '../lib/api.js'
import { formaLabel, formatARS } from '../lib/formatters.js'
import { useStockChannel } from '../composables/useStockChannel.js'

const FORMAS = [
  { value: 'flor_seca',  label: 'Flor seca' },
  { value: 'hash',       label: 'Hash' },
  { value: 'aceite',     label: 'Aceite' },
  { value: 'tintura',    label: 'Tintura' },
  { value: 'crema',      label: 'Crema' },
  { value: 'capsula',    label: 'Cápsula' },
  { value: 'comestible', label: 'Comestible' },
  { value: 'prensado',   label: 'Prensado' },
  { value: 'preroll',    label: 'Preroll' },
  { value: 'externo',    label: 'Externo' },
  { value: 'otro',       label: 'Otro' },
]

const loading      = ref(true)
const stocks       = ref([])
const filtroForma  = ref('')
const liveConectado = ref(false)
const flashIds     = ref(new Set())

const stocksFiltrados = computed(() => {
  let s = stocks.value.filter(x => x.cantidad > 0 && x.estado !== 'pendiente_asignacion')
  if (filtroForma.value) s = s.filter(x => x.forma_producto === filtroForma.value)
  return s
})

function onStockActualizado(data) {
  liveConectado.value = true
  const idx = stocks.value.findIndex(s => s.id === data.stock_id)
  if (idx === -1) return

  stocks.value[idx] = {
    ...stocks.value[idx],
    cantidad:                 data.cantidad,
    gramos_reservados:        data.gramos_reservados,
    cantidad_disponible_real: data.cantidad_disponible_real,
  }

  // flash visual
  const newSet = new Set(flashIds.value)
  newSet.add(data.stock_id)
  flashIds.value = newSet
  setTimeout(() => {
    const s = new Set(flashIds.value)
    s.delete(data.stock_id)
    flashIds.value = s
  }, 1200)
}

useStockChannel(onStockActualizado)

onMounted(async () => {
  liveConectado.value = true
  try {
    const { data } = await listStocks()
    stocks.value = data.stocks ?? data ?? []
  } catch {
    stocks.value = []
  } finally {
    loading.value = false
  }
})

function badgeVencimiento(s) {
  if (!s.dias_para_vencimiento === null) return ''
  const dias = s.dias_para_vencimiento
  if (dias < 0)  return `Vencido hace ${Math.abs(dias)}d`
  if (dias === 0) return 'Vence hoy'
  return `Vence en ${dias}d`
}

const fmtFecha = (d) => d
  ? new Date(d + 'T00:00:00').toLocaleDateString('es-AR', { day: '2-digit', month: '2-digit', year: '2-digit' })
  : '—'

// Fecha de ingreso del stock (created_at = cuándo se aprobó/generó). Es timestamp ISO.
const fmtIngreso = (d) => d
  ? new Date(d).toLocaleDateString('es-AR', { day: '2-digit', month: '2-digit', year: '2-digit' })
  : '—'

// Mostramos "de Xg" solo si ya se consumió algo (inicial > disponible real).
// 200 en vez de 200.0, pero 82.5 conserva su decimal: el ".0" colgando de cada número era la
// mitad de la sensación de planilla vieja.
function fmtCant(n) {
  if (n == null) return '—'
  const v = Number(n)
  return Number.isInteger(v) ? v.toLocaleString('es-AR') : v.toLocaleString('es-AR', { minimumFractionDigits: 1, maximumFractionDigits: 1 })
}

function mostrarInicial(s) {
  const ini = s.cantidad_inicial
  if (ini == null) return false
  const disp = s.cantidad_disponible_real ?? s.cantidad ?? 0
  return ini - disp > 0.05
}
</script>

<style scoped>
.sdv { padding: var(--sp-6) var(--sp-8); }

.sdv__toolbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--sp-4);
  margin-bottom: var(--sp-5);
  flex-wrap: wrap;
}
.sdv__toolbar-left { display: flex; align-items: center; gap: var(--sp-3); }
.sdv__title { font-family: var(--font-display); font-size: var(--fs-20); font-weight: 700; color: var(--c-ink-900); margin: 0; }
.sdv__live-dot { font-size: .68rem; font-weight: 700; color: #15803d; background: #dcfce7; padding: .15rem .5rem; border-radius: 99px; }

.sdv__select {
  padding: .5rem var(--sp-3);
  border: 1px solid var(--c-ink-300);
  border-radius: var(--r-md);
  font-size: var(--fs-14);
  color: var(--c-ink-900);
  background: #fff;
  cursor: pointer;
}
.sdv__select:focus { outline: none; border-color: var(--c-role-dispensador); }

.sdv__table-wrap { overflow-x: auto; }
.sdv__table {
  width: 100%;
  border-collapse: collapse;
  font-size: var(--fs-14);
  background: #fff;
  border: 1px solid var(--c-ink-300);
  border-radius: var(--r-lg);
  overflow: hidden;
}
.sdv__table th {
  text-align: left;
  font-size: var(--fs-12);
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: .04em;
  color: var(--c-ink-500);
  padding: var(--sp-3);
  background: transparent;
  border-bottom: 1px solid var(--c-ink-200);
}
.sdv__table td { padding: var(--sp-3); border-bottom: 1px solid var(--c-ink-100); color: var(--c-ink-900); vertical-align: middle; }
.sdv__table tr:last-child td { border-bottom: none; }
.sdv__table tr:hover td { background: var(--c-leaf-50); }
.sdv__th-num, .sdv__td-num { text-align: right; font-variant-numeric: tabular-nums; }
.sdv__cant { font-weight: 600; font-size: var(--fs-15); color: var(--c-ink-900); }
.sdv__unidad { font-size: var(--fs-12); font-weight: 500; color: var(--c-ink-500); margin-left: 1px; }
.sdv__td-forma { font-weight: 600; }
.sdv__forma-main { display: flex; align-items: center; gap: var(--sp-2); }
.sdv__codigo { display: inline-block; margin-top: .2rem; font-family: var(--font-mono); font-size: 10.5px; letter-spacing: .02em; color: var(--c-ink-500); background: var(--c-ink-100); padding: .05rem .35rem; border-radius: 4px; }
.sdv__chip { font-size: .62rem; font-weight: 700; padding: .1rem .4rem; border-radius: 99px; text-transform: uppercase; letter-spacing: .03em; }
.sdv__chip--propio  { background: #dcfce7; color: #15803d; }
.sdv__chip--externo { background: #e0e7ff; color: #4338ca; }
.sdv__th-ing, .sdv__td-ing { font-size: var(--fs-13); color: var(--c-ink-500); white-space: nowrap; }
.sdv__td-inicial { display: block; font-size: var(--fs-11); color: var(--c-ink-400); font-weight: 400; }
.sdv__td-cepa  { font-size: var(--fs-13); color: var(--c-ink-800); font-weight: 500; }
.sdv__td-mono  { font-size: var(--fs-13); color: var(--c-ink-600); }
.sdv__td-bajo  { color: var(--c-rust-600); font-weight: 700; }
.sdv__none     { color: var(--c-ink-300); font-size: var(--fs-13); }
/* Observaciones: texto libre, así que se acota y el resto se lee en el tooltip. Sin tope, un
   comentario largo empuja las columnas de cantidad fuera de la pantalla. */
.sdv__th-obs, .sdv__td-obs {
  font-size: var(--fs-13); color: var(--c-ink-600);
  max-width: 220px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
}

/* Badges */
.sdv__badge-reservado {
  font-size: .7rem; font-weight: 700; color: #d97706;
  background: #fef3c7; padding: .15rem .45rem; border-radius: 99px;
  white-space: nowrap;
}
.sdv__badge-venc {
  font-size: .7rem; font-weight: 700; padding: .15rem .45rem; border-radius: 99px; white-space: nowrap;
}
.sdv__badge-venc--vencido  { background: #fee2e2; color: #dc2626; }
.sdv__badge-venc--critico  { background: #ffedd5; color: #ea580c; }
.sdv__badge-venc--proximo  { background: #fef9c3; color: #a16207; }

/* Live flash */
.sdv__tr--flash td { animation: stockFlash .6s ease-out; }
@keyframes stockFlash {
  0%  { background: #dcfce7; }
  100% { background: transparent; }
}

.sdv__empty { font-size: var(--fs-14); color: var(--c-ink-500); padding: var(--sp-4) 0; }

.sdv__skel-list { display: flex; flex-direction: column; gap: var(--sp-2); }
.sdv__skel { height: 44px; background: var(--c-ink-100); border-radius: var(--r-md); animation: pulse 1.4s ease-in-out infinite; }
@keyframes pulse { 0%,100%{opacity:1} 50%{opacity:.5} }

@media (max-width: 767px) {
  .sdv { padding: var(--sp-4); }
  /* En mobile, info secundaria oculta para no saturar */
  .sdv__th-ing, .sdv__td-ing { display: none; }
  .sdv__forma-sub { display: none; }
  /* En la tarjeta de mobile el texto largo entra completo: no hay columnas que empujar. */
  .sdv__td-obs { max-width: none; white-space: normal; }
}
.sdv__td-etiqueta { width: 36px; text-align: center; }
.sdv__etiqueta-link { font-size: 1rem; text-decoration: none; cursor: pointer; }
</style>
