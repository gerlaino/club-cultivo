<script setup>
// Depósito del salón (deposito_bar) de una sede — VISTA READ-ONLY dentro de Insumos.
// Muestra los productos del bar como stock valorizado (costo, mínimo, alertas) + su historial de
// movimientos, pero NO se gestiona acá: la compra/reconteo/alta viven en un solo lugar,
// "Stock del salón" (BarStockView). Antes esto duplicaba esa gestión (rediseño del Salón, B2).
import { ref, computed, watch, onMounted } from 'vue'
import { listBares, listBarProductos, getBarProductoMovimientos } from '../../lib/api.js'

const props = defineProps({ sedeId: { type: [Number, null], default: null } })

const bar       = ref(null)
const productos  = ref([])
const loading    = ref(false)

const fmt = (n) => `$${Math.round(n || 0).toLocaleString('es-AR')}`
const valorizadoTotal = computed(() => productos.value.reduce((a, p) => a + (p.valorizado_ars || 0), 0))

async function cargar() {
  if (props.sedeId == null) { bar.value = null; productos.value = []; return }
  loading.value = true
  try {
    const { data } = await listBares()
    bar.value = (data || []).find(b => b.sede?.id === props.sedeId) || null
    productos.value = bar.value ? ((await listBarProductos(bar.value.id)).data || []) : []
  } catch { bar.value = null; productos.value = [] }
  finally { loading.value = false }
}
onMounted(cargar)
watch(() => props.sedeId, cargar)

function stockPct(p) {
  if (!p.stock_minimo) return p.stock > 0 ? 100 : 0
  return Math.min(100, Math.round((p.stock / (p.stock_minimo * 2)) * 100))
}

// ── Historial de movimientos (solo lectura) ───────────────────
const movsForm = ref(null)
const movs = ref([])
async function abrirMovs(p) {
  movsForm.value = p; movs.value = []
  try { movs.value = (await getBarProductoMovimientos(bar.value.id, p.id)).data || [] } catch {}
}
const TIPO_MOV = {
  compra: 'Compra', venta: 'Venta', reserva_evento: 'Reserva evento',
  devolucion_evento: 'Devolución evento', ajuste: 'Ajuste', merma: 'Merma',
}
</script>

<template>
  <div class="ds">
    <div v-if="sedeId == null" class="ds__empty ds__empty--box">
      Elegí una sede <b>social o mixta</b> arriba para ver el depósito de su salón.
    </div>
    <div v-else-if="loading" class="ds__empty">Cargando depósito del salón…</div>
    <div v-else-if="!bar" class="ds__empty ds__empty--box">
      Esta sede todavía no tiene buffet. Creá el buffet desde la sección <b>Buffet</b>.
    </div>

    <template v-else>
      <div class="ds__bar-head">
        <div><span class="ds__bar-name">{{ bar.nombre }}</span> <span class="ds__bar-sede">· {{ bar.sede?.nombre }}</span></div>
        <div class="ds__head-right">
          <div class="ds__stat"><span class="ds__stat-lbl">Valorizado</span><span class="ds__stat-val">{{ fmt(valorizadoTotal) }}</span></div>
          <RouterLink :to="`/bar/${bar.id}/stock`" class="btn btn--primary">Gestionar en Stock del salón →</RouterLink>
        </div>
      </div>

      <p class="ds__ro">👁️ Vista de solo lectura. El stock del salón (comprar, recontar, crear productos) se gestiona en <RouterLink :to="`/bar/${bar.id}/stock`" class="ds__link">Stock del salón</RouterLink>.</p>

      <div v-if="!productos.length" class="ds__empty ds__empty--box">
        Este salón todavía no tiene productos. Cargalos desde <RouterLink :to="`/bar/${bar.id}/stock`" class="ds__link">Stock del salón</RouterLink>.
      </div>

      <ul v-else class="ds__list">
        <li v-for="p in productos" :key="p.id" class="ds__item" :class="{ 'ds__item--low': p.stock_bajo }">
          <div class="ds__main">
            <div class="ds__top">
              <span class="ds__name">{{ p.nombre }}</span>
              <span class="ds__cat">{{ p.categoria_producto_nombre || p.categoria }}</span>
              <span v-if="p.stock_bajo" class="ds__pill">Reponer</span>
            </div>
            <div class="ds__meter"><i :style="{ width: stockPct(p) + '%' }" :class="p.stock_bajo ? 'is-low' : 'is-ok'"></i></div>
          </div>
          <div class="ds__stats">
            <span class="ds__stock" :class="{ low: p.stock_bajo }">{{ p.stock }} <small>u</small></span>
            <span class="ds__meta">{{ fmt(p.costo_ars) }}/u · {{ fmt(p.valorizado_ars) }}</span>
          </div>
          <div class="ds__actions">
            <button class="btn btn--sm" @click="abrirMovs(p)">Historial</button>
          </div>
        </li>
      </ul>
    </template>

    <!-- Modal movimientos (solo lectura) -->
    <div v-if="movsForm" class="ov" @click.self="movsForm = null">
      <div class="dpdlg dpdlg--wide">
        <h3 class="modal__title">Movimientos — {{ movsForm.nombre }}</h3>
        <div v-if="!movs.length" class="ds__empty">Sin movimientos todavía.</div>
        <ul v-else class="ds__movs">
          <li v-for="m in movs" :key="m.id" class="ds__mov">
            <span class="ds__mov-tipo" :class="m.entrada ? 'in' : 'out'">{{ m.entrada ? '+' : '−' }}{{ m.cantidad }}</span>
            <span class="ds__mov-lbl">{{ TIPO_MOV[m.tipo] || m.tipo }}<small v-if="m.motivo"> · {{ m.motivo }}</small></span>
            <span class="ds__mov-saldo">{{ m.stock_anterior }} → {{ m.stock_nuevo }}</span>
          </li>
        </ul>
        <div class="modal__actions"><button class="btn" @click="movsForm = null">Cerrar</button></div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.ds { color: var(--c-slate-900); }
.ds__empty { color: var(--c-slate-400); padding: 2rem; text-align: center; font-size: .88rem; }
.ds__empty--box { background: #fbfcfd; border: 1px dashed var(--c-slate-200); border-radius: 14px; }
.ds__bar-head { display: flex; align-items: center; justify-content: space-between; gap: 1rem; margin-bottom: 1rem; flex-wrap: wrap; }
.ds__head-right { display: flex; align-items: center; gap: 1.25rem; }
.ds__link { color: #1b5e20; font-weight: 600; text-decoration: none; }
.ds__link:hover { text-decoration: underline; }
.ds__ro { font-size: .82rem; color: var(--c-slate-500); background: var(--c-slate-50); border: 1px solid #eef2f6; border-radius: 10px; padding: .6rem .85rem; margin: 0 0 1rem; }
.ds__bar-name { font-weight: 700; font-size: 1.05rem; }
.ds__bar-sede { color: var(--c-slate-400); font-size: .84rem; }
.ds__stat { text-align: right; }
.ds__stat-lbl { display: block; font-size: .66rem; text-transform: uppercase; letter-spacing: .08em; color: var(--c-slate-400); font-weight: 600; }
.ds__stat-val { display: block; font-size: 1.3rem; font-weight: 800; letter-spacing: -.03em; }

.ds__list { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: .6rem; }
.ds__item { display: grid; grid-template-columns: 1fr auto auto; gap: 1.25rem; align-items: center; background: #fff; border: 1px solid #e8edf2; border-radius: 13px; padding: 1rem 1.25rem; }
.ds__item--low { border-color: #f4d9b8; }
.ds__main { min-width: 0; }
.ds__top { display: flex; align-items: center; gap: .6rem; }
.ds__name { font-weight: 650; font-size: .96rem; }
.ds__cat { font-size: .66rem; font-weight: 600; color: var(--c-slate-500); background: var(--c-slate-100); padding: 2px 8px; border-radius: 999px; text-transform: capitalize; }
.ds__pill { font-size: .64rem; font-weight: 700; text-transform: uppercase; letter-spacing: .05em; color: #b45309; background: #fef3c7; padding: 2px 8px; border-radius: 999px; }
.ds__meter { height: 6px; background: var(--c-slate-100); border-radius: 5px; overflow: hidden; margin-top: .55rem; }
.ds__meter i { display: block; height: 100%; border-radius: 5px; }
.ds__meter i.is-ok { background: linear-gradient(90deg, #1b5e20, #2e7d32); }
.ds__meter i.is-low { background: linear-gradient(90deg, #dc2626, #ef4444); }
.ds__stats { text-align: right; }
.ds__stock { font-weight: 700; font-size: 1.05rem; font-variant-numeric: tabular-nums; }
.ds__stock small { font-weight: 500; color: var(--c-slate-400); font-size: .78rem; }
.ds__stock.low { color: #dc2626; }
.ds__meta { display: block; color: var(--c-slate-400); font-size: .76rem; margin-top: .1rem; }
.ds__actions { display: flex; gap: .4rem; }

.ds__movs { list-style: none; margin: 0; padding: 0; max-height: 340px; overflow-y: auto; }
.ds__mov { display: grid; grid-template-columns: 60px 1fr auto; gap: .6rem; align-items: center; padding: .5rem 0; border-bottom: 1px solid var(--c-slate-100); font-size: .84rem; }
.ds__mov:last-child { border-bottom: none; }
.ds__mov-tipo { font-weight: 700; font-variant-numeric: tabular-nums; }
.ds__mov-tipo.in { color: #15803d; } .ds__mov-tipo.out { color: #dc2626; }
.ds__mov-lbl { color: var(--c-slate-700); }
.ds__mov-lbl small { color: var(--c-slate-400); }
.ds__mov-saldo { color: var(--c-slate-400); font-variant-numeric: tabular-nums; font-size: .78rem; }

.ov { position: fixed; inset: 0; background: rgb(15 23 42 / .5); backdrop-filter: blur(2px); display: grid; place-items: center; z-index: 1000; padding: 1rem; }
/* .dpdlg — NO usar `.modal`: choca con Bootstrap (display:none) y no se ve. */
.dpdlg { position: relative; display: block; background: #fff; border-radius: 16px; padding: 1.5rem; width: 100%; max-width: 380px; box-shadow: 0 20px 50px rgb(15 23 42 / .25); }
.dpdlg--wide { max-width: 460px; }
.modal__title { margin: 0 0 .25rem; font-size: 1.1rem; font-weight: 750; letter-spacing: -.02em; }
.modal__actions { display: flex; gap: .5rem; justify-content: flex-end; margin-top: .5rem; }
.btn { border: 1.5px solid var(--c-slate-200); background: #fff; color: var(--c-slate-700); border-radius: 9px; padding: .55rem .95rem; font-size: .83rem; font-weight: 600; cursor: pointer; text-decoration: none; }
.btn:hover { border-color: var(--c-slate-300); }
.btn--sm { padding: .45rem .8rem; font-size: .8rem; }
.btn--primary { background: #1b5e20; border-color: #1b5e20; color: #fff; }
.btn--primary:hover { background: #144a18; color: #fff; }
.btn:disabled { opacity: .5; cursor: default; }
</style>
