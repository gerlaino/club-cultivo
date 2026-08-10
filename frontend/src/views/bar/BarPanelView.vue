<script setup>
// Panel del salón — centro de mando: resultado del mes, caja de hoy, ventas por hora, top,
// "Lecturas del salón" (insights accionables) y rendimiento de productos. Paleta slate + verde
// marca con acento cobre propio del salón. Datos: Bar::Pulso (backend).
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useBarStore } from '../../stores/bar.js'
import { useAuthStore } from '../../stores/auth.js'
import { useToast } from '../../composables/useToast.js'
import BarNav from './BarNav.vue'
import CajaSheet from './CajaSheet.vue'

const store = useBarStore()
const auth  = useAuthStore()
const route = useRoute()
const router = useRouter()
const toast = useToast()
const barId = route.params.barId

const esAdmin = computed(() => auth.user?.role === 'admin')
// Resumen liviano (B4): lo glanceable siempre a la vista; el análisis (ventas por hora, top,
// lecturas) va plegado y se abre bajo demanda.
const showAnalisis = ref(false)
const fmt = (n) => `$${Math.round(n || 0).toLocaleString('es-AR')}`
const fmtK = (n) => {
  const v = Math.abs(n || 0)
  if (v >= 1000) return `$${(n / 1000).toFixed(v >= 100000 ? 0 : 1).replace('.0', '')}K`
  return fmt(n)
}

onMounted(async () => {
  await store.fetchDashboard(barId)
  // Si el salón no cargó (fue borrado / no accesible), no dejamos al usuario en un bar fantasma:
  // lo mandamos al listado, que re-consulta los bares reales.
  if (!store.barActual) {
    toast.error('Ese salón ya no existe o no está disponible.')
    router.push('/bar')
    return
  }
})

const d = computed(() => store.dashboard)
const rm = computed(() => d.value?.resultado_mes || {})
const hoy = computed(() => d.value?.hoy || {})
const caja = computed(() => d.value?.caja || null)
const esOperador = computed(() => ['admin', 'supervisor', 'dispensador'].includes(auth.user?.role))

// ── Caja de turno: toda la operación (abrir/confirmar/cerrar según rol) vive en CajaSheet ──
const showCaja = ref(false)
// El estado que muestra el card: la caja del Pulso ahora trae estado + apertura_confirmada.
const cajaBadge = computed(() => {
  const c = caja.value
  if (!c) return null
  if (c.estado === 'pendiente_cierre') return { txt: 'Cierre pendiente', cls: 'pend' }
  if (c.estado === 'abierta' && !c.apertura_confirmada) return { txt: 'Falta confirmar', cls: 'warn' }
  return { txt: 'Abierta', cls: 'open' }
})

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

const insigniaClase = (t) => ({ good: 'good', bad: 'bad', warn: 'warn' }[t] || 'warn')
const insigniaIcono = (t) => ({ good: '★', bad: '!', warn: '↓' }[t] || '•')
</script>

<template>
  <div class="sp">
    <BarNav :bar-id="barId" active="resumen" />

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
          <div class="sp__caja-head">
            <span class="sp__lbl">Caja del turno</span>
            <span v-if="cajaBadge" class="sp__caja-open" :class="`sp__caja-open--${cajaBadge.cls}`">● {{ cajaBadge.txt }}</span>
          </div>
          <template v-if="caja">
            <span class="sp__caja-val num">{{ fmt(caja.total_ventas_ars) }}</span>
            <div class="sp__caja-split">
              <span>Efectivo <b class="num">{{ fmt(caja.total_efectivo_ars) }}</b></span>
              <span>Digital <b class="num">{{ fmt(caja.total_digital_ars) }}</b></span>
            </div>
            <div class="sp__caja-foot">Fondo {{ fmt(caja.monto_inicial_ars) }} · {{ caja.tickets }} tickets</div>
            <button v-if="esOperador" class="sp__btn sp__btn--brand sp__caja-btn" @click="showCaja = true">Gestionar caja</button>
          </template>
          <template v-else>
            <span class="sp__caja-val sp__caja-muted">Sin caja abierta</span>
            <div class="sp__caja-foot">Ventas de hoy: {{ fmt(hoy.total) }} · {{ hoy.tickets || 0 }} tickets</div>
            <button v-if="esOperador" class="sp__btn sp__btn--brand sp__caja-btn" @click="showCaja = true">Abrir caja</button>
          </template>
        </div>

        <div class="sp__card sp__mini">
          <div class="sp__k"><span class="sp__kl">🧾 Ventas de hoy</span><span class="sp__kv num">{{ fmt(hoy.total) }}</span></div>
          <div class="sp__k"><span class="sp__kl">🍺 Tickets</span><span class="sp__kv num">{{ hoy.tickets || 0 }}</span></div>
          <div class="sp__k"><span class="sp__kl">◆ Margen bruto hoy</span><span class="sp__kv num" :class="{ 'sp__kv--green': hoy.margen_bruto_pct != null }">{{ hoy.margen_bruto_pct != null ? hoy.margen_bruto_pct + '%' : '—' }}</span></div>
        </div>
      </div>

      <!-- Vendido fuera del catálogo: el mostrador hizo lo correcto (cobrar y dejar registro),
           pero son productos que nadie cargó — no entran al inventario ni tienen margen. -->
      <div v-if="d.sueltas_mes?.cantidad" class="sp__card sp__sueltas">
        <div class="sp__ch">
          <b>Vendido fuera del catálogo</b>
          <span class="sp__mut">este mes</span>
        </div>
        <div class="sp__sueltas-nums">
          <span class="sp__sueltas-n num">{{ d.sueltas_mes.cantidad }}</span>
          <span class="sp__sueltas-lbl">venta{{ d.sueltas_mes.cantidad === 1 ? '' : 's' }} · {{ fmt(d.sueltas_mes.total_ars) }}</span>
        </div>
        <ul class="sp__sueltas-top">
          <li v-for="t in d.sueltas_mes.top" :key="t.nombre">
            <span class="sp__rn">{{ t.nombre }}</span>
            <span class="sp__rq num">{{ fmt(t.total_ars) }}</span>
          </li>
        </ul>
        <p class="sp__sueltas-hint">Cargalos al catálogo para que entren al inventario y tengan margen.</p>
      </div>

      <!-- Reponer: glanceable y accionable, siempre a la vista -->
      <div class="sp__card sp__repo-card">
        <div class="sp__ch"><b>Reponer pronto</b><span class="sp__mut">bajo mínimo</span></div>
        <div v-if="!d.reponer?.length" class="sp__empty">Todo con stock suficiente. 👌</div>
        <ul v-else class="sp__repo">
          <li v-for="r in d.reponer" :key="r.id">
            <span class="sp__rn">{{ r.nombre }}</span>
            <span class="sp__meter"><i :class="{ mid: r.pct >= 30 }" :style="{ width: Math.max(6, r.pct) + '%' }"></i></span>
            <span class="sp__rq num">{{ r.stock }} u</span>
            <RouterLink v-if="esAdmin" :to="`/bar/${barId}/stock`" class="sp__rbtn">Reponer</RouterLink>
          </li>
        </ul>
      </div>

      <!-- Análisis del salón: plegado por defecto (ventas por hora, top, lecturas) -->
      <button class="sp__fold" :class="{ 'is-open': showAnalisis }" @click="showAnalisis = !showAnalisis">
        <span>Análisis del salón</span>
        <span class="sp__fold-sub">ventas por hora · top de hoy · lecturas</span>
        <span class="sp__fold-caret">{{ showAnalisis ? '▴' : '▾' }}</span>
      </button>

      <template v-if="showAnalisis">
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

        <div class="sp__card">
          <div class="sp__ai-head"><span class="sp__ai-badge">Lecturas del salón</span></div>
          <div v-if="!d.lecturas?.length" class="sp__empty">Sin lecturas por ahora. Cargá ventas y volvé.</div>
          <div v-for="(l, i) in d.lecturas" :key="i" class="sp__insight" :class="insigniaClase(l.tono)">
            <span class="sp__ic">{{ insigniaIcono(l.tono) }}</span>
            <p>{{ l.texto }}</p>
          </div>
        </div>
      </template>
    </template>
    <div v-else class="sp__empty" style="padding:3rem 0;">Cargando el salón…</div>

    <!-- Caja del turno: apertura / confirmación / cierre según rol y estado -->
    <CajaSheet v-if="showCaja" :bar-id="barId" @close="showCaja = false" />

  </div>
</template>

<style scoped>
.sp { padding: 2rem 1.75rem 3rem; max-width: 1120px; margin: 0 auto; color: var(--c-slate-900); }
.num { font-variant-numeric: tabular-nums; letter-spacing: -.01em; }

/* Header */
.sp__head { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; flex-wrap: wrap; margin-bottom: 1.4rem; }
.sp__title { font-size: 1.7rem; font-weight: 800; margin: 0 0 .15rem; letter-spacing: -.035em; }
.sp__loc { font-size: .82rem; color: var(--c-slate-400); margin: 0; text-transform: capitalize; }
.sp__actions { display: flex; gap: .5rem; flex-wrap: wrap; }
.sp__btn { display: inline-flex; align-items: center; gap: .35rem; background: #fff; color: var(--c-slate-600); border: 1.5px solid var(--c-slate-200); padding: .58rem 1rem; border-radius: 10px; font-size: .85rem; font-weight: 600; cursor: pointer; text-decoration: none; }
.sp__btn:hover { border-color: var(--c-slate-300); color: var(--c-slate-700); }
.sp__btn--brand { background: #1b5e20; border-color: #1b5e20; color: #fff; }
.sp__btn--brand:hover { background: #144a18; color: #fff; }
.sp__btn--copper { background: #9a5b34; border-color: #9a5b34; color: #fff; }
.sp__btn--copper:hover { background: #824b2c; color: #fff; }
.sp__btn--sm { padding: .45rem .85rem; font-size: .8rem; }
.sp__btn:disabled { opacity: .55; cursor: default; }

/* Cards base */
.sp__card { background: #fff; border: 1px solid #e6ebf1; border-radius: 14px; padding: 1.15rem 1.25rem; box-shadow: 0 1px 2px rgb(15 23 42 / .04); }
.sp__lbl { font-size: .7rem; text-transform: uppercase; letter-spacing: .07em; color: var(--c-slate-400); font-weight: 700; }
.sp__empty { color: var(--c-slate-400); font-size: .82rem; text-align: center; padding: 1.2rem 0; }
.sp__mut { font-size: .74rem; color: var(--c-slate-400); font-weight: 500; }

/* Row 1 */
.sp__row1 { display: grid; grid-template-columns: 1.15fr 1fr 1fr; gap: .9rem; margin-bottom: .9rem; }
@media (max-width: 760px) { .sp__row1 { grid-template-columns: 1fr; } }
.sp__hero { position: relative; overflow: hidden; }
.sp__big { font-size: 2.4rem; font-weight: 820; letter-spacing: -.04em; margin: .3rem 0 .1rem; color: #15803d; }
.sp__big.neg { color: #dc2626; }
.sp__hero-sub { font-size: .8rem; color: var(--c-slate-600); }
.sp__trend { display: inline-flex; align-items: center; gap: .3rem; font-size: .76rem; font-weight: 650; color: #15803d; background: #effaf1; padding: 2px 9px; border-radius: 999px; margin-top: .7rem; }
.sp__trend.down { color: #b45309; background: #fef3c7; }
.sp__caja { display: flex; flex-direction: column; }
.sp__caja-val { font-size: 1.7rem; font-weight: 800; letter-spacing: -.03em; margin: .25rem 0; }
.sp__caja-split { display: flex; gap: 1rem; font-size: .78rem; color: var(--c-slate-600); margin-bottom: .5rem; }
.sp__caja-split b { color: var(--c-slate-900); font-weight: 700; }
.sp__caja-foot { font-size: .74rem; color: var(--c-slate-400); margin-top: auto; }
.sp__mini { display: flex; flex-direction: column; justify-content: center; gap: .8rem; }
.sp__k { display: flex; align-items: baseline; justify-content: space-between; gap: .5rem; }
.sp__k + .sp__k { border-top: 1px solid var(--c-slate-100); padding-top: .8rem; }
.sp__kl { font-size: .78rem; color: var(--c-slate-600); }
.sp__kv { font-size: 1.1rem; font-weight: 750; letter-spacing: -.02em; }
.sp__kv--green { color: #15803d; }

/* Row 2 */
.sp__row2 { display: grid; grid-template-columns: 1.5fr 1fr; gap: .9rem; margin-bottom: .9rem; }
@media (max-width: 760px) { .sp__row2 { grid-template-columns: 1fr; } }
.sp__ch { display: flex; align-items: center; justify-content: space-between; margin-bottom: .9rem; }
.sp__ch b { font-size: .92rem; font-weight: 700; }
.sp__ch--flex { align-items: center; }
.sp__chart { width: 100%; height: 128px; display: block; }
.sp__legend { display: flex; justify-content: space-between; font-size: .72rem; color: var(--c-slate-400); margin-top: .3rem; }
.sp__rank { list-style: none; margin: 0; padding: 0; }
.sp__rank li { display: grid; grid-template-columns: 22px 1fr auto; align-items: center; gap: .6rem; padding: .5rem 0; border-bottom: 1px solid var(--c-slate-100); font-size: .86rem; }
.sp__rank li:last-child { border-bottom: none; }
.sp__n { width: 22px; height: 22px; border-radius: 7px; background: #f1f4f8; color: var(--c-slate-600); font-size: .72rem; font-weight: 750; display: grid; place-items: center; }
.sp__nm { color: var(--c-slate-900); font-weight: 550; }
.sp__nm small { display: block; color: var(--c-slate-400); font-weight: 400; font-size: .72rem; text-transform: capitalize; }
.sp__q { text-align: right; font-weight: 750; }
.sp__q small { display: block; color: #15803d; font-weight: 600; font-size: .7rem; }

/* Reponer glanceable + toggle de análisis (B4) */
.sp__sueltas-nums { display: flex; align-items: baseline; gap: 8px; margin: 6px 0; }
.sp__sueltas-n { font-size: 22px; font-weight: 800; color: var(--c-amber-500, #D97706); }
.sp__sueltas-lbl { font-size: 13px; color: var(--c-slate-500); }
.sp__sueltas-top { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: 4px; }
.sp__sueltas-top li { display: flex; justify-content: space-between; font-size: 13px; }
.sp__sueltas-hint { margin: 8px 0 0; font-size: 12px; color: var(--c-slate-400); }
.sp__repo-card { margin-bottom: .9rem; }
.sp__fold { display: flex; align-items: center; gap: .6rem; width: 100%; background: #fff; border: 1px solid #e6ebf1; border-radius: 12px; padding: .9rem 1.1rem; cursor: pointer; margin-bottom: .9rem; font-weight: 700; color: var(--c-slate-700); font-size: .9rem; }
.sp__fold:hover { border-color: var(--c-slate-300); }
.sp__fold.is-open { border-color: #9a5b34; }
.sp__fold-sub { font-size: .74rem; font-weight: 500; color: var(--c-slate-400); }
.sp__fold-caret { margin-left: auto; color: #9a5b34; font-size: .9rem; }

/* Row 3 */
.sp__row3 { display: grid; grid-template-columns: 1fr 1fr; gap: .9rem; margin-bottom: .9rem; }
@media (max-width: 760px) { .sp__row3 { grid-template-columns: 1fr; } }
.sp__ai-head { display: flex; align-items: center; gap: .5rem; margin-bottom: .8rem; }
.sp__ai-badge { font-size: .62rem; font-weight: 800; letter-spacing: .08em; text-transform: uppercase; color: #9a5b34; background: #f6ece4; padding: 3px 8px; border-radius: 6px; }
.sp__insight { display: flex; gap: .7rem; align-items: flex-start; padding: .7rem 0; border-top: 1px solid var(--c-slate-100); }
.sp__insight:first-of-type { border-top: none; }
.sp__ic { width: 26px; height: 26px; border-radius: 8px; display: grid; place-items: center; flex-shrink: 0; font-size: .85rem; font-weight: 700; }
.sp__insight.good .sp__ic { background: #effaf1; color: #15803d; }
.sp__insight.warn .sp__ic { background: #fef3c7; color: #b45309; }
.sp__insight.bad .sp__ic { background: #fdecec; color: #dc2626; }
.sp__insight p { margin: 0; font-size: .84rem; color: var(--c-slate-600); line-height: 1.45; }
.sp__repo { list-style: none; margin: 0; padding: 0; }
.sp__repo li { display: flex; align-items: center; gap: .6rem; padding: .55rem 0; border-bottom: 1px solid var(--c-slate-100); font-size: .85rem; }
.sp__repo li:last-child { border-bottom: none; }
.sp__rn { flex: 1; color: var(--c-slate-900); }
.sp__meter { width: 78px; height: 6px; background: #f1f4f8; border-radius: 4px; overflow: hidden; }
.sp__meter i { display: block; height: 100%; border-radius: 4px; background: #dc2626; }
.sp__meter i.mid { background: #b45309; }
.sp__rq { width: 58px; text-align: right; color: #dc2626; font-weight: 650; }
.sp__rbtn { border: 1px solid var(--c-slate-200); background: #fff; border-radius: 7px; padding: .25rem .6rem; font-size: .72rem; font-weight: 650; color: var(--c-slate-600); cursor: pointer; }
.sp__rbtn:hover { border-color: var(--c-slate-300); }

/* Productos */
.sp__prod { padding: 1.15rem 1.25rem .4rem; }
.sp__form { display: flex; gap: .5rem; flex-wrap: wrap; align-items: center; padding: .9rem 0 1rem; border-bottom: 1px solid var(--c-slate-100); margin-bottom: .3rem; }
.sp__form-act { display: flex; gap: .5rem; margin-left: auto; }
.sp__inp { background: #fff; border: 1.5px solid var(--c-slate-200); border-radius: 9px; padding: .5rem .75rem; font-size: .82rem; color: var(--c-slate-900); }
.sp__inp:focus { border-color: #9a5b34; outline: none; }
.sp__inp--sm { width: 90px; }
.sp__table-wrap { overflow-x: auto; }
.sp__table { width: 100%; border-collapse: collapse; font-size: .83rem; }
.sp__table th { text-align: left; font-size: .68rem; text-transform: uppercase; letter-spacing: .05em; color: var(--c-slate-400); font-weight: 700; padding: .6rem .7rem; border-bottom: 1px solid var(--c-slate-100); }
.sp__table td { padding: .65rem .7rem; border-bottom: 1px solid var(--c-slate-50); color: var(--c-slate-600); }
.sp__table tbody tr:hover td { background: #fafbfc; }
.sp__off td { opacity: .5; }
.sp__table .r { text-align: right; }
.sp__strong { color: var(--c-slate-900); font-weight: 600; }
.sp__muted { color: var(--c-slate-400); }
.sp__red { color: #dc2626; font-weight: 600; }
.sp__mg { display: inline-block; padding: 2px 8px; border-radius: 999px; font-size: .72rem; font-weight: 700; }
.sp__mg.hi { background: #effaf1; color: #15803d; }
.sp__mg.mid { background: #fef3c7; color: #b45309; }
.sp__mg.lo { background: #fdecec; color: #dc2626; }
.sp__acts { white-space: nowrap; }
.sp__link { background: none; border: none; color: var(--c-slate-500); font-size: .8rem; font-weight: 500; cursor: pointer; padding: .1rem .35rem; }
.sp__link:hover { color: var(--c-slate-900); }
.sp__link--danger:hover { color: #dc2626; }

/* Caja del turno */
.sp__caja-head { display: flex; align-items: center; justify-content: space-between; }
.sp__caja-open { font-size: .68rem; font-weight: 700; color: #15803d; background: #effaf1; padding: 2px 8px; border-radius: 999px; }
.sp__caja-open--warn { color: #b45309; background: #fef3c7; }
.sp__caja-open--pend { color: #1d4ed8; background: #eff6ff; }
.sp__caja-muted { color: var(--c-slate-400); font-size: 1.1rem; }
.sp__caja-btn { margin-top: auto; justify-content: center; width: 100%; }

/* Modales caja */
.sp__ov { position: fixed; inset: 0; background: rgb(15 23 42 / .5); backdrop-filter: blur(2px); display: grid; place-items: center; z-index: 1000; padding: 1rem; }
.sp__modal { background: #fff; border-radius: 16px; padding: 1.5rem; width: 100%; max-width: 400px; box-shadow: 0 20px 50px rgb(15 23 42 / .25); }
.sp__modal-title { margin: 0 0 .3rem; font-size: 1.1rem; font-weight: 750; letter-spacing: -.02em; color: var(--c-slate-900); }
.sp__modal-hint { color: var(--c-slate-500); font-size: .82rem; margin: 0 0 1.1rem; line-height: 1.45; }
.sp__modal-act { display: flex; gap: .5rem; justify-content: flex-end; margin-top: .5rem; }
.sp__fld { display: flex; flex-direction: column; gap: .35rem; font-size: .82rem; color: var(--c-slate-600); margin-bottom: .9rem; font-weight: 600; }
.sp__inp { background: #fff; border: 1.5px solid var(--c-slate-200); border-radius: 9px; padding: .55rem .75rem; font-size: .9rem; color: var(--c-slate-900); outline: none; }
.sp__inp:focus { border-color: #9a5b34; }
.sp__arqueo { background: var(--c-slate-50); border: 1px solid var(--c-slate-100); border-radius: 10px; padding: .7rem .9rem; margin-bottom: 1rem; }
.sp__arqueo-row { display: flex; justify-content: space-between; font-size: .84rem; color: var(--c-slate-600); padding: .25rem 0; }
.sp__arqueo-row b { color: var(--c-slate-900); }
.sp__arqueo-row--tot { border-top: 1px solid var(--c-slate-200); margin-top: .25rem; padding-top: .5rem; font-weight: 700; }
.sp__dif { text-align: center; font-size: .85rem; font-weight: 700; padding: .55rem; border-radius: 9px; margin-bottom: .9rem; }
.sp__dif.ok { background: #effaf1; color: #15803d; }
.sp__dif.sobra { background: #eff6ff; color: #1d4ed8; }
.sp__dif.falta { background: #fdecec; color: #dc2626; }

/* Modal de gestión de categorías (NO usar .modal: choca con Bootstrap) */
.sp__ovl { position: fixed; inset: 0; background: rgb(15 23 42 / .5); backdrop-filter: blur(2px); display: grid; place-items: center; z-index: 1000; padding: 1rem; }
.sp__dlg { position: relative; display: block; background: #fff; border-radius: 16px; padding: 1.4rem; width: 100%; max-width: 420px; box-shadow: 0 20px 50px rgb(15 23 42 / .25); max-height: 88vh; overflow-y: auto; }
.sp__catlist { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: .4rem; }
.sp__catrow { display: flex; align-items: center; justify-content: space-between; gap: .75rem; padding: .5rem .7rem; background: var(--c-slate-50); border: 1px solid #eef2f6; border-radius: 9px; font-size: .88rem; }
.sp__catacts { display: inline-flex; gap: .35rem; flex-shrink: 0; }
.sp__btn--danger { color: #dc2626; border-color: #f4c9c9; }
.sp__btn--danger:hover { background: #fef2f2; border-color: #dc2626; }
</style>
