<script setup>
import { ref, watch, computed } from 'vue'
import { listDispensacionesFecha, exportDispensacionesCSV } from '../lib/api.js'
import { formaLabel, formatARS, formatFecha } from '../lib/formatters.js'
import { RouterLink } from 'vue-router'
import { Download, RefreshCw, Truck, Search } from 'lucide-vue-next'

const hoy = new Date().toISOString().slice(0, 10)

// Rango de fechas — por defecto últimos 7 días
const desdeDefault = () => {
  const d = new Date()
  d.setDate(d.getDate() - 6)
  return d.toISOString().slice(0, 10)
}
const desde = ref(desdeDefault())
const hasta = ref(hoy)
const busca = ref('')

const loading    = ref(false)
const exporting  = ref(false)
const allDisps   = ref([])

const dispensaciones = computed(() => {
  if (!busca.value.trim()) return allDisps.value
  const q = busca.value.toLowerCase()
  return allDisps.value.filter(d =>
    d.paciente_nombre?.toLowerCase().includes(q) ||
    d.usuario?.nombre?.toLowerCase().includes(q) ||
    d.stock?.forma_producto?.toLowerCase().includes(q)
  )
})

// KPIs — calculados siempre sobre el período completo, no sobre el filtro de búsqueda
const totalRecaudado = computed(() =>
  allDisps.value.reduce((s, d) => s + (d.aporte_socio_ars ?? 0), 0)
)
const totalGramos = computed(() =>
  allDisps.value.reduce((s, d) => s + (d.cantidad ?? 0), 0)
)
const totalConEnvio = computed(() =>
  allDisps.value.filter(d => d.con_envio).length
)

// Resumen por medio de pago
const resumenPago = computed(() => {
  const map = {}
  for (const d of dispensaciones.value) {
    const k = d.medio_pago || 'otro'
    if (!map[k]) map[k] = { count: 0, total: 0 }
    map[k].count++
    map[k].total += d.aporte_socio_ars ?? 0
  }
  return Object.entries(map).map(([medio, v]) => ({ medio, ...v })).sort((a, b) => b.total - a.total)
})

async function cargar() {
  if (!desde.value && !hasta.value) return
  loading.value = true
  try {
    const params = {}
    if (desde.value) params.desde = desde.value
    if (hasta.value) params.hasta = hasta.value
    const { data } = await listDispensacionesFecha(params)
    allDisps.value = data.dispensaciones ?? []
  } catch {
    allDisps.value = []
  } finally {
    loading.value = false
  }
}

watch([desde, hasta], () => {
  if (desde.value && hasta.value && desde.value <= hasta.value) cargar()
}, { immediate: true })

async function exportar() {
  exporting.value = true
  try {
    const params = {}
    if (desde.value) params.desde = desde.value
    if (hasta.value) params.hasta = hasta.value
    const { data } = await exportDispensacionesCSV(params)
    const url = URL.createObjectURL(new Blob([data], { type: 'text/csv' }))
    const a   = document.createElement('a')
    a.href    = url
    a.download = `dispensaciones_${desde.value}_${hasta.value}.csv`
    a.click()
    URL.revokeObjectURL(url)
  } catch {} finally {
    exporting.value = false
  }
}

function setRango(dias) {
  const d = new Date()
  d.setDate(d.getDate() - (dias - 1))
  desde.value = d.toISOString().slice(0, 10)
  hasta.value = hoy
}

function formatHora(ts) {
  if (!ts) return '—'
  return new Date(ts).toLocaleTimeString('es-AR', { hour: '2-digit', minute: '2-digit' })
}
function medioPagoLabel(m) {
  const L = { efectivo: 'Efectivo', transferencia: 'Transf.', debito: 'Débito', credito: 'Crédito', cuenta_corriente: 'Cta. cte.', credito_gramos: 'Cred. g', no_abona: 'No abona' }
  return L[m] || m || '—'
}
</script>

<template>
  <div class="hd">

    <!-- Header -->
    <div class="hd__top">
      <div>
        <h1 class="hd__title">Historial de dispensaciones</h1>
        <p class="hd__sub">Consultá y exportá el historial del período seleccionado</p>
      </div>
      <div class="hd__top-actions">
        <button class="hd__btn-refresh" :disabled="loading" @click="cargar">
          <RefreshCw :size="14" :stroke-width="2" :class="{ 'hd__spin': loading }" />
        </button>
        <button class="hd__btn-export" :disabled="exporting || !dispensaciones.length" @click="exportar">
          <Download :size="14" :stroke-width="2" />
          {{ exporting ? 'Exportando…' : 'CSV' }}
        </button>
      </div>
    </div>

    <!-- Filtros -->
    <div class="hd__filters">
      <!-- Accesos rápidos -->
      <div class="hd__quick">
        <button class="hd__quick-btn" @click="setRango(1)">Hoy</button>
        <button class="hd__quick-btn" @click="setRango(7)">7 días</button>
        <button class="hd__quick-btn" @click="setRango(30)">30 días</button>
        <button class="hd__quick-btn" @click="setRango(90)">3 meses</button>
      </div>
      <!-- Rango fechas -->
      <div class="hd__dates">
        <div class="hd__date-group">
          <label class="hd__date-label">Desde</label>
          <input v-model="desde" type="date" class="hd__date-input" :max="hasta || hoy" />
        </div>
        <span class="hd__date-sep">→</span>
        <div class="hd__date-group">
          <label class="hd__date-label">Hasta</label>
          <input v-model="hasta" type="date" class="hd__date-input" :max="hoy" :min="desde" />
        </div>
      </div>
      <!-- Búsqueda -->
      <div class="hd__search-wrap">
        <Search :size="14" :stroke-width="2" class="hd__search-ico" />
        <input
          v-model="busca"
          type="search"
          class="hd__search"
          placeholder="Buscar paciente, producto…"
        />
      </div>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="hd__skel-list">
      <div class="hd__skel" v-for="n in 6" :key="n" />
    </div>

    <template v-else-if="allDisps.length">

      <!-- KPIs -->
      <div class="hd__kpis">
        <div class="hd__kpi">
          <span class="hd__kpi-val">{{ allDisps.length }}</span>
          <span class="hd__kpi-lbl">Dispensaciones</span>
        </div>
        <div class="hd__kpi">
          <span class="hd__kpi-val">{{ totalGramos.toFixed(1) }}<span class="hd__kpi-unit">g</span></span>
          <span class="hd__kpi-lbl">Total gramos</span>
        </div>
        <div class="hd__kpi hd__kpi--green">
          <span class="hd__kpi-val">{{ formatARS(totalRecaudado) }}</span>
          <span class="hd__kpi-lbl">Total recaudado</span>
        </div>
        <div v-if="totalConEnvio" class="hd__kpi hd__kpi--blue">
          <span class="hd__kpi-val">{{ totalConEnvio }}</span>
          <span class="hd__kpi-lbl">Con envío</span>
        </div>
      </div>

      <!-- Resumen por medio de pago -->
      <div class="hd__pago-strip">
        <span
          v-for="r in resumenPago"
          :key="r.medio"
          class="hd__pago-chip"
        >
          {{ medioPagoLabel(r.medio) }}: <strong>{{ r.count }}</strong>
          <span class="hd__pago-monto">({{ formatARS(r.total) }})</span>
        </span>
      </div>

      <!-- Tabla -->
      <div v-if="!dispensaciones.length" class="hd__empty">
        Sin resultados para la búsqueda "{{ busca }}".
      </div>
      <div v-else class="hd__table-wrap">
        <table class="hd__table">
          <thead>
            <tr>
              <th>Fecha / Hora</th>
              <th>Paciente</th>
              <th>Producto</th>
              <th class="hd__th-num">Cantidad</th>
              <th class="hd__th-num">P. unitario</th>
              <th class="hd__th-num">Total</th>
              <th>Pago</th>
              <th>Dispensador</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="d in dispensaciones" :key="d.id">
              <td class="hd__td-fecha">
                <span class="hd__fecha-day">{{ formatFecha(d.fecha_dispensacion, false) }}</span>
                <span class="hd__fecha-hora">{{ formatHora(d.created_at) }}</span>
              </td>
              <td class="hd__td-paciente">
                <RouterLink :to="{ name: 'paciente-detail', params: { id: d.paciente_id } }" class="hd__link-paciente">{{ d.paciente_nombre }}</RouterLink>
              </td>
              <td class="hd__td-producto">{{ formaLabel(d.stock?.forma_producto) }}</td>
              <td class="hd__td-num">{{ d.cantidad }}{{ d.stock?.unidad ?? 'g' }}</td>
              <td class="hd__td-num">{{ formatARS(d.precio_unitario_ars) }}</td>
              <td class="hd__td-num hd__td-monto">{{ formatARS(d.aporte_socio_ars) }}</td>
              <td class="hd__td-pago">{{ medioPagoLabel(d.medio_pago) }}</td>
              <td class="hd__td-user">{{ d.usuario?.nombre ?? '—' }}</td>
              <td class="hd__td-envio">
                <span v-if="d.con_envio" class="hd__envio-badge" :title="d.estado_envio">
                  <Truck :size="12" :stroke-width="2" />
                </span>
              </td>
            </tr>
          </tbody>
        </table>

        <div class="hd__summary">
          <span class="hd__summary-count">{{ dispensaciones.length }} dispensaciones</span>
          <span class="hd__summary-total">
            {{ totalGramos.toFixed(1) }}g · <strong>{{ formatARS(totalRecaudado) }}</strong>
          </span>
        </div>
      </div>

    </template>

    <!-- Empty total -->
    <div v-else class="hd__empty-full">
      Sin dispensaciones en el período seleccionado.
    </div>

  </div>
</template>

<style scoped>
.hd {
  padding: var(--sp-6) var(--sp-8);
  max-width: 1200px;
}
@media (max-width: 767px) { .hd { padding: var(--sp-4); } }

/* Header */
.hd__top {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: var(--sp-4);
  margin-bottom: var(--sp-5);
  flex-wrap: wrap;
}
.hd__title {
  font-size: var(--fs-20);
  font-weight: 700;
  color: var(--c-ink-900);
  margin: 0 0 2px;
}
.hd__sub { font-size: var(--fs-13); color: var(--c-ink-400); margin: 0; }
.hd__top-actions { display: flex; align-items: center; gap: var(--sp-2); }
.hd__btn-refresh {
  background: var(--c-paper);
  border: 1.5px solid var(--c-ink-200);
  border-radius: var(--r-md);
  padding: .45rem .6rem;
  color: var(--c-ink-500);
  cursor: pointer;
  display: flex;
  align-items: center;
  transition: border-color .15s;
}
.hd__btn-refresh:hover:not(:disabled) { border-color: var(--c-ink-400); color: var(--c-ink-700); }
.hd__btn-refresh:disabled { opacity: .5; cursor: not-allowed; }
.hd__spin { animation: hd-spin .7s linear infinite; }
@keyframes hd-spin { to { transform: rotate(360deg); } }
.hd__btn-export {
  display: flex;
  align-items: center;
  gap: var(--sp-2);
  padding: .5rem .9rem;
  background: #1b5e20;
  color: #fff;
  border: none;
  border-radius: var(--r-md);
  font-size: var(--fs-13);
  font-weight: 600;
  cursor: pointer;
  transition: background .15s;
}
.hd__btn-export:hover:not(:disabled) { background: #145218; }
.hd__btn-export:disabled { opacity: .55; cursor: default; }

/* Filtros */
.hd__filters {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: var(--sp-3);
  margin-bottom: var(--sp-5);
  padding: var(--sp-3) var(--sp-4);
  background: var(--c-paper);
  border: 1.5px solid var(--c-ink-100);
  border-radius: var(--r-lg);
}
.hd__quick { display: flex; gap: var(--sp-1); }
.hd__quick-btn {
  background: none;
  border: 1.5px solid var(--c-ink-200);
  border-radius: var(--r-md);
  padding: .3rem .65rem;
  font-size: var(--fs-12);
  font-weight: 600;
  color: var(--c-ink-600);
  cursor: pointer;
  transition: border-color .15s, background .15s;
}
.hd__quick-btn:hover { border-color: #1b5e20; background: #f0fdf4; color: #1b5e20; }
.hd__dates { display: flex; align-items: center; gap: var(--sp-2); }
.hd__date-group { display: flex; flex-direction: column; gap: 2px; }
.hd__date-label { font-size: 10px; font-weight: 700; text-transform: uppercase; letter-spacing: .06em; color: var(--c-ink-400); }
.hd__date-input {
  padding: .38rem var(--sp-3);
  border: 1.5px solid var(--c-ink-200);
  border-radius: var(--r-md);
  font-size: var(--fs-13);
  color: var(--c-ink-900);
  background: var(--c-paper);
  cursor: pointer;
}
.hd__date-input:focus { outline: none; border-color: #1b5e20; }
.hd__date-sep { color: var(--c-ink-300); font-size: var(--fs-14); }
.hd__search-wrap {
  display: flex;
  align-items: center;
  gap: var(--sp-2);
  flex: 1;
  min-width: 180px;
  background: var(--c-ink-50, #f8fafc);
  border: 1.5px solid var(--c-ink-200);
  border-radius: var(--r-md);
  padding: .38rem .7rem;
}
.hd__search-ico { color: var(--c-ink-400); flex-shrink: 0; }
.hd__search {
  flex: 1;
  background: none;
  border: none;
  font-size: var(--fs-13);
  color: var(--c-ink-900);
  outline: none;
}

/* KPIs */
.hd__kpis {
  display: flex;
  flex-wrap: wrap;
  gap: var(--sp-3);
  margin-bottom: var(--sp-4);
}
.hd__kpi {
  background: var(--c-paper);
  border: 1.5px solid var(--c-ink-100);
  border-radius: var(--r-lg);
  padding: var(--sp-3) var(--sp-4);
  display: flex;
  flex-direction: column;
  gap: 3px;
  min-width: 140px;
}
.hd__kpi--green { border-color: #bbf7d0; background: #f0fdf4; }
.hd__kpi--blue  { border-color: #bfdbfe; background: #eff6ff; }
.hd__kpi-val {
  font-size: var(--fs-22);
  font-weight: 800;
  color: var(--c-ink-900);
  line-height: 1;
}
.hd__kpi--green .hd__kpi-val { color: #15803d; }
.hd__kpi--blue  .hd__kpi-val { color: #1d4ed8; }
.hd__kpi-unit { font-size: var(--fs-14); font-weight: 600; }
.hd__kpi-lbl { font-size: 11px; font-weight: 600; color: var(--c-ink-500); text-transform: uppercase; letter-spacing: .05em; }

/* Pago strip */
.hd__pago-strip {
  display: flex;
  flex-wrap: wrap;
  gap: var(--sp-2);
  margin-bottom: var(--sp-4);
}
.hd__pago-chip {
  background: var(--c-ink-50, #f8fafc);
  border: 1px solid var(--c-ink-200);
  border-radius: 999px;
  padding: .2em .75em;
  font-size: var(--fs-12);
  color: var(--c-ink-600);
}
.hd__pago-monto { color: var(--c-ink-400); margin-left: .2em; }

/* Tabla */
.hd__table-wrap { overflow-x: auto; }
.hd__table {
  width: 100%;
  border-collapse: collapse;
  font-size: var(--fs-13);
  background: var(--c-paper);
  border: 1.5px solid var(--c-ink-100);
  border-radius: var(--r-lg);
  overflow: hidden;
}
.hd__table th {
  text-align: left;
  font-size: 11px;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: .04em;
  color: var(--c-ink-500);
  padding: var(--sp-3);
  background: var(--c-ink-50, #f8fafc);
  border-bottom: 1.5px solid var(--c-ink-100);
  white-space: nowrap;
}
.hd__table td {
  padding: var(--sp-2) var(--sp-3);
  border-bottom: 1px solid var(--c-ink-50, #f8fafc);
  color: var(--c-ink-800);
  vertical-align: middle;
}
.hd__table tr:last-child td { border-bottom: none; }
.hd__table tr:hover td { background: var(--c-leaf-50); }
.hd__th-num, .hd__td-num { text-align: right; }
.hd__td-fecha { white-space: nowrap; }
.hd__fecha-day { display: block; font-weight: 600; font-size: var(--fs-13); }
.hd__fecha-hora { display: block; font-size: 11px; color: var(--c-ink-400); font-family: monospace; }
.hd__td-paciente { font-weight: 500; }
.hd__link-paciente { color: inherit; text-decoration: none; }
.hd__link-paciente:hover { color: #1b5e20; text-decoration: underline; }
.hd__td-producto { color: var(--c-ink-500); }
.hd__td-monto { font-weight: 700; color: #15803d; }
.hd__td-pago { font-size: var(--fs-12); }
.hd__td-user { font-size: var(--fs-12); color: var(--c-ink-400); }
.hd__td-envio { width: 32px; }
.hd__envio-badge {
  display: inline-flex;
  align-items: center;
  background: #dbeafe;
  color: #1d4ed8;
  padding: 2px 5px;
  border-radius: 4px;
}

/* Summary row */
.hd__summary {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: var(--sp-3) var(--sp-4);
  background: var(--c-ink-50, #f8fafc);
  border-top: 1.5px solid var(--c-ink-100);
  font-size: var(--fs-13);
  color: var(--c-ink-600);
}
.hd__summary-count { }
.hd__summary-total { }

/* Empty / loading */
.hd__empty { color: var(--c-ink-500); font-size: var(--fs-14); padding: var(--sp-4) 0; }
.hd__empty-full { color: var(--c-ink-400); font-size: var(--fs-14); padding: var(--sp-10) 0; text-align: center; }
.hd__skel-list { display: flex; flex-direction: column; gap: var(--sp-2); margin-bottom: var(--sp-4); }
.hd__skel { height: 44px; background: var(--c-ink-100); border-radius: var(--r-md); animation: hd-pulse 1.4s ease-in-out infinite; }
@keyframes hd-pulse { 0%,100%{opacity:1} 50%{opacity:.5} }
</style>
