<template>
  <div class="mres">
    <div class="mres__tabs">
      <button class="mres__tab" :class="{ 'mres__tab--on': filtro === 'hoy' }" @click="filtro = 'hoy'">
        Para hoy <span v-if="cuentaHoy" class="mres__badge">{{ cuentaHoy }}</span>
      </button>
      <button class="mres__tab" :class="{ 'mres__tab--on': filtro === 'todas' }" @click="filtro = 'todas'">
        Todas
      </button>
    </div>

    <div v-if="loading" class="mres__muted">Cargando…</div>

    <div v-else-if="!visibles.length" class="mres__empty">
      <span class="mres__empty-ico">📦</span>
      <p>{{ filtro === 'hoy' ? 'No hay reservas para preparar hoy.' : 'No hay reservas pendientes.' }}</p>
    </div>

    <div v-else class="mres__list">
      <div v-for="r in visibles" :key="r.id" class="mres__card" :class="{ 'mres__card--vencida': esVencida(r) }">
        <div class="mres__card-head">
          <span class="mres__paciente">{{ r.paciente?.nombre || '—' }}</span>
          <span class="mres__fecha" :class="{ 'mres__fecha--vencida': esVencida(r) }">
            {{ esVencida(r) ? 'Venció ' : '' }}{{ fechaCorta(r.fecha_entrega_estimada) }}
          </span>
        </div>
        <div class="mres__prod">
          {{ r.cantidad }}{{ r.stock?.unidad || 'g' }} · {{ formaLabel(r.stock?.forma_producto) }}
        </div>
        <div class="mres__pie">
          <span v-if="Number(r.aporte_restante_ars) > 0" class="mres__resta">Resta {{ formatARS(r.aporte_restante_ars) }}</span>
          <span v-else class="mres__senada">Señada ✓</span>
          <button class="mres__btn" :disabled="entregando === r.id" @click="entregar(r)">
            {{ entregando === r.id ? 'Entregando…' : 'Entregar' }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { listReservas, entregarReserva } from '../../lib/api.js'
import { formaLabel, formatARS } from '../../lib/formatters.js'
import { useToast } from '../../composables/useToast.js'

const toast = useToast()

const filtro     = ref('hoy')
const loading    = ref(false)
const reservas   = ref([])
const entregando = ref(null)

const hoyISO = new Date().toISOString().slice(0, 10)

// "Para hoy" incluye las VENCIDAS: una reserva que quedó de ayer sigue esperando a alguien, y
// esconderla es la forma de que se olvide.
const visibles = computed(() =>
  filtro.value === 'todas'
    ? reservas.value
    : reservas.value.filter(r => (r.fecha_entrega_estimada || '') <= hoyISO))

const cuentaHoy = computed(() => reservas.value.filter(r => (r.fecha_entrega_estimada || '') <= hoyISO).length)

onMounted(cargar)

async function cargar() {
  loading.value = true
  try {
    const { data } = await listReservas({ estado: 'pendiente' })
    // El endpoint devuelve { reservas: [...] }. El `?? data` de antes dejaba pasar el objeto entero
    // cuando la forma no coincidía, y la vista reventaba al filtrar algo que no era un array.
    reservas.value = Array.isArray(data?.reservas) ? data.reservas : []
  } catch { reservas.value = [] } finally { loading.value = false }
}

function esVencida(r) { return (r.fecha_entrega_estimada || '') < hoyISO }

async function entregar(r) {
  entregando.value = r.id
  try {
    await entregarReserva(r.id)
    toast.success('Reserva entregada')
    await cargar()
  } catch (e) {
    toast.error(e?.response?.data?.error || 'No se pudo entregar')
  } finally { entregando.value = null }
}

function fechaCorta(f) {
  if (!f) return ''
  const d = new Date(`${f}T12:00:00`)
  return `${String(d.getDate()).padStart(2, '0')}/${String(d.getMonth() + 1).padStart(2, '0')}`
}
</script>

<style scoped>
.mres { padding: .75rem; display: flex; flex-direction: column; gap: .75rem; }

.mres__tabs { display: flex; gap: .4rem; }
.mres__tab {
  flex: 1; border: 1px solid var(--c-slate-200); background: #fff; border-radius: 10px;
  padding: .55rem; font-size: .85rem; color: var(--c-slate-500); cursor: pointer;
}
.mres__tab--on {
  border-color: var(--c-leaf-600, #16a34a); background: #f0fdf4;
  color: var(--c-leaf-700, #15803d); font-weight: 600;
}
.mres__badge {
  background: var(--c-leaf-600, #16a34a); color: #fff; border-radius: 999px;
  padding: 0 .4em; font-size: .72rem; margin-left: .25em;
}

.mres__muted { text-align: center; color: var(--c-slate-400); padding: 1rem; font-size: .85rem; }
.mres__empty { text-align: center; padding: 2rem 1rem; color: var(--c-slate-500); }
.mres__empty-ico { font-size: 2rem; display: block; margin-bottom: .5rem; }

.mres__list { display: flex; flex-direction: column; gap: .5rem; }
.mres__card {
  background: #fff; border: 1px solid var(--c-slate-100); border-radius: 12px;
  padding: .8rem .9rem; display: flex; flex-direction: column; gap: .4rem;
}
.mres__card--vencida { border-color: #fecaca; background: #fef2f2; }
.mres__card-head { display: flex; justify-content: space-between; align-items: center; gap: .5rem; }
.mres__paciente { font-weight: 600; color: var(--c-ink-800, #1e293b); }
.mres__fecha { font-size: .75rem; color: var(--c-slate-400); white-space: nowrap; }
.mres__fecha--vencida { color: #dc2626; font-weight: 600; }
.mres__prod { font-size: .85rem; color: var(--c-slate-600); }
.mres__pie { display: flex; align-items: center; justify-content: space-between; gap: .5rem; }
.mres__resta { font-size: .8rem; color: #b45309; font-weight: 600; }
.mres__senada { font-size: .8rem; color: #15803d; }
.mres__btn {
  border: none; border-radius: 10px; padding: .5rem 1rem; cursor: pointer;
  background: var(--c-leaf-600, #16a34a); color: #fff; font-size: .85rem; font-weight: 600;
}
.mres__btn:disabled { opacity: .5; }
</style>
