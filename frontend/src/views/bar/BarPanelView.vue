<script setup>
// Panel del salón — centro de mando: resultado del mes, caja de hoy, ventas por hora, top,
// "Lecturas del salón" (insights accionables) y rendimiento de productos. Paleta slate + verde
// marca con acento cobre propio del salón. Datos: Bar::Pulso (backend).
import { ref, computed, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { useBarStore } from '../../stores/bar.js'
import { useAuthStore } from '../../stores/auth.js'
import { useToast } from '../../composables/useToast.js'
import { useConfirm } from '../../composables/useConfirm.js'

const store = useBarStore()
const auth  = useAuthStore()
const route = useRoute()
const toast = useToast()
const { confirm } = useConfirm()
const barId = route.params.barId

const CATS = ['bebida', 'cocina', 'merch', 'otro']
const esAdmin = computed(() => auth.user?.role === 'admin')
const fmt = (n) => `$${Math.round(n || 0).toLocaleString('es-AR')}`
const fmtK = (n) => {
  const v = Math.abs(n || 0)
  if (v >= 1000) return `$${(n / 1000).toFixed(v >= 100000 ? 0 : 1).replace('.0', '')}K`
  return fmt(n)
}

onMounted(() => { store.fetchDashboard(barId); store.fetchProductos(barId) })

const d = computed(() => store.dashboard)
const rm = computed(() => d.value?.resultado_mes || {})
const hoy = computed(() => d.value?.hoy || {})

// ── Gráfico de ventas por hora (SVG area) ──────────────────────
const W = 520, H = 128, PAD = 10
const chart = computed(() => {
  const arr = d.value?.ventas_por_hora || []
  const conVentas = arr.filter(h => h.total > 0)
  if (!conVentas.length) return null
  const minH = Math.min(...conVentas.map(h => h.hora))
  const maxH = Math.max(...conVentas.map(h => h.hora))
  const win = arr.filter(h => h.hora >= minH && h.hora <= maxH)
  const max = Math.max(...win.map(h => h.total), 1)
  const n = win.length
  const pts = win.map((h, i) => {
    const x = n === 1 ? W / 2 : (i / (n - 1)) * W
    const y = H - (h.total / max) * (H - PAD)
    return { x: +x.toFixed(1), y: +y.toFixed(1), ...h }
  })
  const line = pts.map(p => `${p.x},${p.y}`).join(' ')
  const area = `${pts[0].x},${H} ${line} ${pts[n - 1].x},${H}`
  const pico = pts.reduce((a, b) => (b.total > a.total ? b : a))
  return { line, area, pico, minH, maxH }
})

// ── Productos (admin) ──────────────────────────────────────────
const prodForm = ref(null)
function nuevoProducto() { prodForm.value = { nombre: '', categoria: 'bebida', precio_ars: null, costo_ars: null, stock: 0, stock_minimo: 0 } }
function editarProducto(p) { prodForm.value = { id: p.id, nombre: p.nombre, categoria: p.categoria, precio_ars: p.precio_ars, costo_ars: p.costo_ars, stock: p.stock, stock_minimo: p.stock_minimo } }
async function guardarProducto() {
  const f = prodForm.value
  if (!f.nombre?.trim() || !(f.precio_ars > 0)) { toast.warning('Nombre y precio son obligatorios'); return }
  const payload = { nombre: f.nombre.trim(), categoria: f.categoria, precio_ars: f.precio_ars, costo_ars: f.costo_ars || null, stock: f.stock || 0, stock_minimo: f.stock_minimo || 0 }
  try {
    if (f.id) await store.actualizarProducto(barId, f.id, payload)
    else      await store.crearProducto(barId, payload)
    toast.success('Producto guardado'); prodForm.value = null
    store.fetchDashboard(barId)
  } catch { toast.error(store.saveError) }
}
async function reponer(p) {
  const cant = Number(prompt(`¿Cuántas unidades de "${p.nombre}" ingresan?`, '1'))
  if (!cant || cant <= 0) return
  try { await store.reponer(barId, p.id, cant); toast.success('Stock repuesto'); store.fetchDashboard(barId) }
  catch { toast.error(store.saveError) }
}
async function borrarProducto(p) {
  if (!(await confirm({ title: 'Eliminar producto', message: `¿Eliminar "${p.nombre}"? Se recupera desde la papelera.`, variant: 'danger' }))) return
  try { await store.eliminarProducto(barId, p.id); toast.success('Producto eliminado') }
  catch { toast.error('No se pudo eliminar') }
}

const margenClase = (m) => (m == null ? '' : m >= 60 ? 'hi' : m >= 50 ? 'mid' : 'lo')
const insigniaClase = (t) => ({ good: 'good', bad: 'bad', warn: 'warn' }[t] || 'warn')
const insigniaIcono = (t) => ({ good: '★', bad: '!', warn: '↓' }[t] || '•')
</script>

<template>
  <div class="sp">
    <!-- Header -->
    <div class="sp__head">
      <div>
        <h1 class="sp__title">{{ store.barActual?.nombre || 'Salón' }}</h1>
        <p class="sp__loc">
          <span v-if="store.barActual?.sede">{{ store.barActual.sede.nombre }} · {{ store.barActual.sede.tipo }}</span>
          <span v-else>Salón del club</span>
        </p>
      </div>
      <div class="sp__actions">
        <RouterLink to="/bar" class="sp__btn">Bares</RouterLink>
        <RouterLink :to="`/bar/${barId}/eventos`" class="sp__btn">🎉 Eventos</RouterLink>
        <RouterLink :to="`/bar/${barId}/vender`" class="sp__btn sp__btn--copper">Vender →</RouterLink>
      </div>
    </div>

    <template v-if="d">
      <!-- Row 1: resultado + caja + miniK -->
      <div class="sp__row1">
        <div class="sp__card sp__hero">
          <span class="sp__lbl">Resultado del mes</span>
          <div class="sp__big num" :class="{ neg: rm.resultado < 0 }">{{ fmt(rm.resultado) }}</div>
          <div class="sp__hero-sub">
            Ingresos {{ fmtK(rm.ingresos) }} · Costos {{ fmtK(rm.egresos) }}
            <span v-if="rm.margen_pct != null"> · Margen {{ rm.margen_pct }}%</span>
          </div>
          <span v-if="rm.delta_pct != null" class="sp__trend" :class="{ down: rm.delta_pct < 0 }">
            {{ rm.delta_pct >= 0 ? '▲' : '▼' }} {{ Math.abs(rm.delta_pct) }}% vs. mes pasado
          </span>
        </div>

        <div class="sp__card sp__caja">
          <span class="sp__lbl">Caja de hoy</span>
          <span class="sp__caja-val num">{{ fmt(hoy.total) }}</span>
          <div class="sp__caja-split">
            <span>Efectivo <b class="num">{{ fmt(hoy.efectivo) }}</b></span>
            <span>Digital <b class="num">{{ fmt(hoy.digital) }}</b></span>
          </div>
          <div class="sp__caja-foot">{{ hoy.tickets || 0 }} tickets · prom. {{ fmt(hoy.ticket_promedio) }}</div>
        </div>

        <div class="sp__card sp__mini">
          <div class="sp__k"><span class="sp__kl">🧾 Ventas de hoy</span><span class="sp__kv num">{{ fmt(hoy.total) }}</span></div>
          <div class="sp__k"><span class="sp__kl">🍺 Tickets</span><span class="sp__kv num">{{ hoy.tickets || 0 }}</span></div>
          <div class="sp__k"><span class="sp__kl">◆ Margen bruto hoy</span><span class="sp__kv num" :class="{ 'sp__kv--green': hoy.margen_bruto_pct != null }">{{ hoy.margen_bruto_pct != null ? hoy.margen_bruto_pct + '%' : '—' }}</span></div>
        </div>
      </div>

      <!-- Row 2: ventas por hora + top -->
      <div class="sp__row2">
        <div class="sp__card">
          <div class="sp__ch"><b>Ventas por hora</b><span class="sp__mut" v-if="chart">pico {{ chart.pico.hora }}h</span></div>
          <svg v-if="chart" class="sp__chart" :viewBox="`0 0 ${W} ${H}`" preserveAspectRatio="none" aria-hidden="true">
            <defs><linearGradient id="spg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#9a5b34" stop-opacity=".26" /><stop offset="1" stop-color="#9a5b34" stop-opacity="0" /></linearGradient></defs>
            <line :x1="0" :y1="H - 2" :x2="W" :y2="H - 2" stroke="#e6ebf1" />
            <polygon :points="chart.area" fill="url(#spg)" />
            <polyline :points="chart.line" fill="none" stroke="#9a5b34" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" />
            <circle :cx="chart.pico.x" :cy="chart.pico.y" r="4" fill="#9a5b34" />
          </svg>
          <div v-if="chart" class="sp__legend"><span>{{ chart.minH }}h apertura</span><span>{{ chart.maxH }}h</span></div>
          <div v-else class="sp__empty">Sin ventas hoy todavía.</div>
        </div>

        <div class="sp__card">
          <div class="sp__ch"><b>Top de hoy</b><span class="sp__mut">unidades · margen</span></div>
          <div v-if="!d.top_productos?.length" class="sp__empty">Todavía no hubo ventas hoy.</div>
          <ul v-else class="sp__rank">
            <li v-for="(t, i) in d.top_productos" :key="t.nombre + i">
              <span class="sp__n">{{ i + 1 }}</span>
              <span class="sp__nm">{{ t.nombre }}<small>{{ t.categoria || '—' }}</small></span>
              <span class="sp__q num">{{ Math.round(t.cantidad) }}<small v-if="t.margen_pct != null">{{ t.margen_pct }}%</small></span>
            </li>
          </ul>
        </div>
      </div>

      <!-- Row 3: lecturas + reponer -->
      <div class="sp__row3">
        <div class="sp__card">
          <div class="sp__ai-head"><span class="sp__ai-badge">Lecturas del salón</span></div>
          <div v-if="!d.lecturas?.length" class="sp__empty">Sin lecturas por ahora. Cargá ventas y volvé.</div>
          <div v-for="(l, i) in d.lecturas" :key="i" class="sp__insight" :class="insigniaClase(l.tono)">
            <span class="sp__ic">{{ insigniaIcono(l.tono) }}</span>
            <p>{{ l.texto }}</p>
          </div>
        </div>

        <div class="sp__card">
          <div class="sp__ch"><b>Reponer pronto</b><span class="sp__mut">bajo mínimo</span></div>
          <div v-if="!d.reponer?.length" class="sp__empty">Todo con stock suficiente.</div>
          <ul v-else class="sp__repo">
            <li v-for="r in d.reponer" :key="r.id">
              <span class="sp__rn">{{ r.nombre }}</span>
              <span class="sp__meter"><i :class="{ mid: r.pct >= 30 }" :style="{ width: Math.max(6, r.pct) + '%' }"></i></span>
              <span class="sp__rq num">{{ r.stock }} u</span>
              <button v-if="esAdmin" class="sp__rbtn" @click="reponer(r)">Reponer</button>
            </li>
          </ul>
        </div>
      </div>
    </template>
    <div v-else class="sp__empty" style="padding:3rem 0;">Cargando el salón…</div>

    <!-- Productos (admin) -->
    <div v-if="esAdmin" class="sp__card sp__prod">
      <div class="sp__ch sp__ch--flex">
        <b>Productos <span class="sp__mut">rendimiento</span></b>
        <button class="sp__btn sp__btn--brand sp__btn--sm" @click="nuevoProducto">+ Producto</button>
      </div>

      <div v-if="prodForm" class="sp__form">
        <input v-model.trim="prodForm.nombre" class="sp__inp" placeholder="Nombre" maxlength="50" />
        <select v-model="prodForm.categoria" class="sp__inp"><option v-for="c in CATS" :key="c" :value="c">{{ c }}</option></select>
        <input v-model.number="prodForm.precio_ars" type="number" min="0" step="any" class="sp__inp sp__inp--sm" placeholder="Precio" />
        <input v-model.number="prodForm.costo_ars" type="number" min="0" step="any" class="sp__inp sp__inp--sm" placeholder="Costo" />
        <input v-model.number="prodForm.stock" type="number" min="0" step="any" class="sp__inp sp__inp--sm" placeholder="Stock" />
        <input v-model.number="prodForm.stock_minimo" type="number" min="0" step="any" class="sp__inp sp__inp--sm" placeholder="Mín" />
        <div class="sp__form-act">
          <button class="sp__btn" @click="prodForm = null">Cancelar</button>
          <button class="sp__btn sp__btn--brand" :disabled="store.saving" @click="guardarProducto">Guardar</button>
        </div>
      </div>

      <div class="sp__table-wrap">
        <table class="sp__table">
          <thead><tr><th>Producto</th><th>Cat.</th><th class="r">Precio</th><th class="r">Costo</th><th class="r">Margen</th><th class="r">Vend. mes</th><th class="r">Stock</th><th></th></tr></thead>
          <tbody>
            <tr v-for="p in store.productos" :key="p.id" :class="{ 'sp__off': !p.activo }">
              <td class="sp__strong">{{ p.nombre }}</td>
              <td class="sp__muted">{{ p.categoria }}</td>
              <td class="r num">{{ fmt(p.precio_ars) }}</td>
              <td class="r num sp__muted">{{ p.costo_ars != null ? fmt(p.costo_ars) : '—' }}</td>
              <td class="r"><span v-if="p.margen_pct != null" class="sp__mg" :class="margenClase(p.margen_pct)">{{ p.margen_pct }}%</span><span v-else class="sp__muted">—</span></td>
              <td class="r num">{{ p.vendidos_mes ? Math.round(p.vendidos_mes) : 0 }}</td>
              <td class="r num" :class="{ 'sp__red': p.stock_bajo }">{{ p.stock }}</td>
              <td class="r sp__acts">
                <button class="sp__link" @click="reponer(p)">Reponer</button>
                <button class="sp__link" @click="editarProducto(p)">Editar</button>
                <button class="sp__link sp__link--danger" @click="borrarProducto(p)">Borrar</button>
              </td>
            </tr>
            <tr v-if="!store.productos.length"><td colspan="8" class="sp__empty">Sin productos. Creá el primero.</td></tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</template>

<style scoped>
.sp { padding: 2rem 1.75rem 3rem; max-width: 1120px; margin: 0 auto; color: #0f172a; }
.num { font-variant-numeric: tabular-nums; letter-spacing: -.01em; }

/* Header */
.sp__head { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; flex-wrap: wrap; margin-bottom: 1.4rem; }
.sp__title { font-size: 1.7rem; font-weight: 800; margin: 0 0 .15rem; letter-spacing: -.035em; }
.sp__loc { font-size: .82rem; color: #94a3b8; margin: 0; text-transform: capitalize; }
.sp__actions { display: flex; gap: .5rem; flex-wrap: wrap; }
.sp__btn { display: inline-flex; align-items: center; gap: .35rem; background: #fff; color: #475569; border: 1.5px solid #e2e8f0; padding: .58rem 1rem; border-radius: 10px; font-size: .85rem; font-weight: 600; cursor: pointer; text-decoration: none; }
.sp__btn:hover { border-color: #cbd5e1; color: #334155; }
.sp__btn--brand { background: #1b5e20; border-color: #1b5e20; color: #fff; }
.sp__btn--brand:hover { background: #144a18; color: #fff; }
.sp__btn--copper { background: #9a5b34; border-color: #9a5b34; color: #fff; }
.sp__btn--copper:hover { background: #824b2c; color: #fff; }
.sp__btn--sm { padding: .45rem .85rem; font-size: .8rem; }
.sp__btn:disabled { opacity: .55; cursor: default; }

/* Cards base */
.sp__card { background: #fff; border: 1px solid #e6ebf1; border-radius: 14px; padding: 1.15rem 1.25rem; box-shadow: 0 1px 2px rgb(15 23 42 / .04); }
.sp__lbl { font-size: .7rem; text-transform: uppercase; letter-spacing: .07em; color: #94a3b8; font-weight: 700; }
.sp__empty { color: #94a3b8; font-size: .82rem; text-align: center; padding: 1.2rem 0; }
.sp__mut { font-size: .74rem; color: #94a3b8; font-weight: 500; }

/* Row 1 */
.sp__row1 { display: grid; grid-template-columns: 1.15fr 1fr 1fr; gap: .9rem; margin-bottom: .9rem; }
@media (max-width: 760px) { .sp__row1 { grid-template-columns: 1fr; } }
.sp__hero { position: relative; overflow: hidden; }
.sp__big { font-size: 2.4rem; font-weight: 820; letter-spacing: -.04em; margin: .3rem 0 .1rem; color: #15803d; }
.sp__big.neg { color: #dc2626; }
.sp__hero-sub { font-size: .8rem; color: #475569; }
.sp__trend { display: inline-flex; align-items: center; gap: .3rem; font-size: .76rem; font-weight: 650; color: #15803d; background: #effaf1; padding: 2px 9px; border-radius: 999px; margin-top: .7rem; }
.sp__trend.down { color: #b45309; background: #fef3c7; }
.sp__caja { display: flex; flex-direction: column; }
.sp__caja-val { font-size: 1.7rem; font-weight: 800; letter-spacing: -.03em; margin: .25rem 0; }
.sp__caja-split { display: flex; gap: 1rem; font-size: .78rem; color: #475569; margin-bottom: .5rem; }
.sp__caja-split b { color: #0f172a; font-weight: 700; }
.sp__caja-foot { font-size: .74rem; color: #94a3b8; margin-top: auto; }
.sp__mini { display: flex; flex-direction: column; justify-content: center; gap: .8rem; }
.sp__k { display: flex; align-items: baseline; justify-content: space-between; gap: .5rem; }
.sp__k + .sp__k { border-top: 1px solid #f1f5f9; padding-top: .8rem; }
.sp__kl { font-size: .78rem; color: #475569; }
.sp__kv { font-size: 1.1rem; font-weight: 750; letter-spacing: -.02em; }
.sp__kv--green { color: #15803d; }

/* Row 2 */
.sp__row2 { display: grid; grid-template-columns: 1.5fr 1fr; gap: .9rem; margin-bottom: .9rem; }
@media (max-width: 760px) { .sp__row2 { grid-template-columns: 1fr; } }
.sp__ch { display: flex; align-items: center; justify-content: space-between; margin-bottom: .9rem; }
.sp__ch b { font-size: .92rem; font-weight: 700; }
.sp__ch--flex { align-items: center; }
.sp__chart { width: 100%; height: 128px; display: block; }
.sp__legend { display: flex; justify-content: space-between; font-size: .72rem; color: #94a3b8; margin-top: .3rem; }
.sp__rank { list-style: none; margin: 0; padding: 0; }
.sp__rank li { display: grid; grid-template-columns: 22px 1fr auto; align-items: center; gap: .6rem; padding: .5rem 0; border-bottom: 1px solid #f1f5f9; font-size: .86rem; }
.sp__rank li:last-child { border-bottom: none; }
.sp__n { width: 22px; height: 22px; border-radius: 7px; background: #f1f4f8; color: #475569; font-size: .72rem; font-weight: 750; display: grid; place-items: center; }
.sp__nm { color: #0f172a; font-weight: 550; }
.sp__nm small { display: block; color: #94a3b8; font-weight: 400; font-size: .72rem; text-transform: capitalize; }
.sp__q { text-align: right; font-weight: 750; }
.sp__q small { display: block; color: #15803d; font-weight: 600; font-size: .7rem; }

/* Row 3 */
.sp__row3 { display: grid; grid-template-columns: 1fr 1fr; gap: .9rem; margin-bottom: .9rem; }
@media (max-width: 760px) { .sp__row3 { grid-template-columns: 1fr; } }
.sp__ai-head { display: flex; align-items: center; gap: .5rem; margin-bottom: .8rem; }
.sp__ai-badge { font-size: .62rem; font-weight: 800; letter-spacing: .08em; text-transform: uppercase; color: #9a5b34; background: #f6ece4; padding: 3px 8px; border-radius: 6px; }
.sp__insight { display: flex; gap: .7rem; align-items: flex-start; padding: .7rem 0; border-top: 1px solid #f1f5f9; }
.sp__insight:first-of-type { border-top: none; }
.sp__ic { width: 26px; height: 26px; border-radius: 8px; display: grid; place-items: center; flex-shrink: 0; font-size: .85rem; font-weight: 700; }
.sp__insight.good .sp__ic { background: #effaf1; color: #15803d; }
.sp__insight.warn .sp__ic { background: #fef3c7; color: #b45309; }
.sp__insight.bad .sp__ic { background: #fdecec; color: #dc2626; }
.sp__insight p { margin: 0; font-size: .84rem; color: #475569; line-height: 1.45; }
.sp__repo { list-style: none; margin: 0; padding: 0; }
.sp__repo li { display: flex; align-items: center; gap: .6rem; padding: .55rem 0; border-bottom: 1px solid #f1f5f9; font-size: .85rem; }
.sp__repo li:last-child { border-bottom: none; }
.sp__rn { flex: 1; color: #0f172a; }
.sp__meter { width: 78px; height: 6px; background: #f1f4f8; border-radius: 4px; overflow: hidden; }
.sp__meter i { display: block; height: 100%; border-radius: 4px; background: #dc2626; }
.sp__meter i.mid { background: #b45309; }
.sp__rq { width: 58px; text-align: right; color: #dc2626; font-weight: 650; }
.sp__rbtn { border: 1px solid #e2e8f0; background: #fff; border-radius: 7px; padding: .25rem .6rem; font-size: .72rem; font-weight: 650; color: #475569; cursor: pointer; }
.sp__rbtn:hover { border-color: #cbd5e1; }

/* Productos */
.sp__prod { padding: 1.15rem 1.25rem .4rem; }
.sp__form { display: flex; gap: .5rem; flex-wrap: wrap; align-items: center; padding: .9rem 0 1rem; border-bottom: 1px solid #f1f5f9; margin-bottom: .3rem; }
.sp__form-act { display: flex; gap: .5rem; margin-left: auto; }
.sp__inp { background: #fff; border: 1.5px solid #e2e8f0; border-radius: 9px; padding: .5rem .75rem; font-size: .82rem; color: #0f172a; }
.sp__inp:focus { border-color: #9a5b34; outline: none; }
.sp__inp--sm { width: 90px; }
.sp__table-wrap { overflow-x: auto; }
.sp__table { width: 100%; border-collapse: collapse; font-size: .83rem; }
.sp__table th { text-align: left; font-size: .68rem; text-transform: uppercase; letter-spacing: .05em; color: #94a3b8; font-weight: 700; padding: .6rem .7rem; border-bottom: 1px solid #f1f5f9; }
.sp__table td { padding: .65rem .7rem; border-bottom: 1px solid #f8fafc; color: #475569; }
.sp__table tbody tr:hover td { background: #fafbfc; }
.sp__off td { opacity: .5; }
.sp__table .r { text-align: right; }
.sp__strong { color: #0f172a; font-weight: 600; }
.sp__muted { color: #94a3b8; }
.sp__red { color: #dc2626; font-weight: 600; }
.sp__mg { display: inline-block; padding: 2px 8px; border-radius: 999px; font-size: .72rem; font-weight: 700; }
.sp__mg.hi { background: #effaf1; color: #15803d; }
.sp__mg.mid { background: #fef3c7; color: #b45309; }
.sp__mg.lo { background: #fdecec; color: #dc2626; }
.sp__acts { white-space: nowrap; }
.sp__link { background: none; border: none; color: #64748b; font-size: .8rem; font-weight: 500; cursor: pointer; padding: .1rem .35rem; }
.sp__link:hover { color: #0f172a; }
.sp__link--danger:hover { color: #dc2626; }
</style>
