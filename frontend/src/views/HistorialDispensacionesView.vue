<template>
  <div class="hd">
    <div class="hd__toolbar">
      <h1 class="hd__title">Historial de dispensaciones</h1>
      <div class="hd__filters">
        <input
          v-model="fecha"
          type="date"
          class="hd__date-input"
          :max="hoy"
        />
      </div>
    </div>

    <div v-if="loading" class="hd__skel-list">
      <div class="hd__skel" v-for="n in 8" :key="n" />
    </div>

    <div v-else-if="!dispensaciones.length" class="hd__empty">
      Sin dispensaciones para la fecha seleccionada.
    </div>

    <div v-else class="hd__table-wrap">
      <table class="hd__table">
        <thead>
          <tr>
            <th>Hora</th>
            <th>Paciente</th>
            <th>Producto</th>
            <th class="hd__th-num">Cantidad</th>
            <th class="hd__th-num">P. unitario</th>
            <th class="hd__th-num">Total</th>
            <th>Pago</th>
            <th>Dispensador</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="d in dispensaciones" :key="d.id">
            <td class="hd__td-mono">{{ formatHora(d.created_at) }}</td>
            <td>{{ d.paciente_nombre }}</td>
            <td>{{ formaLabel(d.stock?.forma_producto) }}</td>
            <td class="hd__td-num">{{ d.cantidad }}{{ d.stock?.unidad ?? '' }}</td>
            <td class="hd__td-num">{{ formatARS(d.precio_unitario_ars) }}</td>
            <td class="hd__td-num hd__td-monto">{{ formatARS(d.aporte_socio_ars) }}</td>
            <td>{{ medioPagoLabel(d.medio_pago) }}</td>
            <td class="hd__td-user">{{ d.usuario?.nombre ?? '—' }}</td>
          </tr>
        </tbody>
      </table>

      <div class="hd__summary">
        <span>{{ dispensaciones.length }} dispensaciones</span>
        <span>Total recaudado: <strong>{{ formatARS(totalRecaudado) }}</strong></span>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, watch, computed } from 'vue'
import { listDispensacionesFecha } from '../lib/api.js'

const hoy   = new Date().toISOString().slice(0, 10)
const fecha  = ref(hoy)
const loading = ref(false)
const dispensaciones = ref([])

const totalRecaudado = computed(() =>
  dispensaciones.value.reduce((s, d) => s + (d.aporte_socio_ars ?? 0), 0)
)

async function cargar() {
  loading.value = true
  try {
    const { data } = await listDispensacionesFecha({ fecha: fecha.value })
    dispensaciones.value = data.dispensaciones ?? []
  } catch {
    dispensaciones.value = []
  } finally {
    loading.value = false
  }
}

watch(fecha, cargar, { immediate: true })

function formatHora(ts) {
  if (!ts) return '—'
  return new Date(ts).toLocaleTimeString('es-AR', { hour: '2-digit', minute: '2-digit' })
}

function formatARS(n) {
  if (n == null) return '—'
  return new Intl.NumberFormat('es-AR', { style: 'currency', currency: 'ARS', maximumFractionDigits: 0 }).format(n)
}

function formaLabel(f) {
  const L = { flor_seca: 'Flor seca', aceite: 'Aceite', tintura: 'Tintura', crema: 'Crema', capsulas: 'Cápsulas', otro: 'Otro' }
  return L[f] || f || '—'
}

function medioPagoLabel(m) {
  const L = { efectivo: 'Efectivo', transferencia: 'Transferencia', debito: 'Débito', credito: 'Crédito' }
  return L[m] || m || '—'
}
</script>

<style scoped>
.hd { padding: var(--sp-6) var(--sp-8); }

.hd__toolbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--sp-4);
  margin-bottom: var(--sp-6);
  flex-wrap: wrap;
}
.hd__title {
  font-family: var(--font-display);
  font-size: var(--fs-20);
  font-weight: 700;
  color: var(--c-ink-900);
  margin: 0;
}
.hd__date-input {
  padding: .5rem var(--sp-3);
  border: 1px solid var(--c-ink-300);
  border-radius: var(--r-md);
  font-size: var(--fs-14);
  color: var(--c-ink-900);
  background: #fff;
  cursor: pointer;
}
.hd__date-input:focus { outline: none; border-color: var(--c-role-dispensador); }

.hd__table-wrap { overflow-x: auto; }
.hd__table {
  width: 100%;
  border-collapse: collapse;
  font-size: var(--fs-14);
  background: #fff;
  border: 1px solid var(--c-ink-300);
  border-radius: var(--r-lg);
  overflow: hidden;
}
.hd__table th {
  text-align: left;
  font-size: var(--fs-12);
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: .04em;
  color: var(--c-ink-500);
  padding: var(--sp-3);
  background: var(--c-ink-100);
  border-bottom: 2px solid var(--c-ink-300);
}
.hd__table td {
  padding: var(--sp-3);
  border-bottom: 1px solid var(--c-ink-100);
  color: var(--c-ink-900);
}
.hd__table tr:last-child td { border-bottom: none; }
.hd__table tr:hover td { background: var(--c-leaf-50); }
.hd__th-num, .hd__td-num { text-align: right; }
.hd__td-mono { font-family: var(--font-mono); font-size: var(--fs-13); }
.hd__td-monto { font-weight: 600; color: var(--c-role-dispensador); }
.hd__td-user { font-size: var(--fs-13); color: var(--c-ink-500); }

.hd__summary {
  display: flex;
  justify-content: space-between;
  padding: var(--sp-3) var(--sp-4);
  background: var(--c-ink-100);
  font-size: var(--fs-13);
  color: var(--c-ink-700);
  border-top: 1px solid var(--c-ink-300);
}

.hd__empty { font-size: var(--fs-14); color: var(--c-ink-500); padding: var(--sp-4) 0; }

.hd__skel-list { display: flex; flex-direction: column; gap: var(--sp-2); }
.hd__skel { height: 44px; background: var(--c-ink-100); border-radius: var(--r-md); animation: pulse 1.4s ease-in-out infinite; }
@keyframes pulse { 0%,100%{opacity:1} 50%{opacity:.5} }

@media (max-width: 767px) {
  .hd { padding: var(--sp-4); }
}
</style>
