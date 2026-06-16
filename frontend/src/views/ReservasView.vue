<template>
  <div class="rsv">
    <div class="rsv__header">
      <div>
        <h1 class="rsv__title">Reservas</h1>
        <p class="rsv__sub">Dispensas apartadas para entregar en una fecha futura.</p>
      </div>
      <div class="rsv__filters">
        <select v-model="estado" class="rsv__select" @change="cargar">
          <option value="pendiente">Pendientes</option>
          <option value="entregada">Entregadas</option>
          <option value="cancelada">Canceladas</option>
          <option value="vencida">Vencidas</option>
          <option value="">Todas</option>
        </select>
      </div>
    </div>

    <div v-if="loading" class="rsv__loading"><DsSpinner /></div>

    <div v-else-if="!reservas.length" class="rsv__empty">
      <i class="bi bi-bookmark-star"></i>
      <p>No hay reservas {{ estado ? ESTADO_LABEL[estado]?.toLowerCase() : '' }}.</p>
    </div>

    <table v-else class="rsv__table">
      <thead>
        <tr>
          <th>Socio</th>
          <th>Producto</th>
          <th>Cantidad</th>
          <th>Entrega</th>
          <th>Seña</th>
          <th>Resta</th>
          <th>Estado</th>
          <th></th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="r in reservas" :key="r.id" :class="{ 'rsv__row--vencida': esVencidaHoy(r) }">
          <td>{{ r.paciente?.nombre || '—' }}</td>
          <td>{{ r.stock?.forma_producto || '—' }}<span v-if="r.stock?.lote" class="rsv__lote"> · {{ r.stock.lote }}</span></td>
          <td>{{ r.cantidad }}{{ r.stock?.unidad || 'g' }}</td>
          <td :class="{ 'rsv__fecha--hoy': esEntregaHoy(r) }">{{ fmtFecha(r.fecha_entrega_estimada) }}</td>
          <td>{{ r.sena_ars ? fmt(r.sena_ars) : '—' }}</td>
          <td>{{ r.aporte_restante_ars != null ? fmt(r.aporte_restante_ars) : '—' }}</td>
          <td><span class="rsv__pill" :class="`rsv__pill--${r.estado}`">{{ ESTADO_LABEL[r.estado] || r.estado }}</span></td>
          <td class="rsv__actions">
            <template v-if="r.estado === 'pendiente'">
              <button class="rsv__btn rsv__btn--primary" :disabled="busy === r.id" @click="entregar(r)">Entregar</button>
              <button class="rsv__btn rsv__btn--ghost" :disabled="busy === r.id" @click="cancelar(r)">Cancelar</button>
            </template>
          </td>
        </tr>
      </tbody>
    </table>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import DsSpinner from '../design-system/components/Spinner.vue'
import { listReservas, entregarReserva, cancelarReserva } from '../lib/api.js'
import { useToast } from '../composables/useToast.js'
import { useConfirm } from '../composables/useConfirm.js'

const toast = useToast()
const { confirm } = useConfirm()

const ESTADO_LABEL = {
  pendiente: 'Pendiente', entregada: 'Entregada', cancelada: 'Cancelada', vencida: 'Vencida',
}

const reservas = ref([])
const loading  = ref(true)
const busy     = ref(null)
const estado   = ref('pendiente')

const hoy = new Date().toISOString().split('T')[0]

const fmt = n => n == null ? '—' :
  new Intl.NumberFormat('es-AR', { style: 'currency', currency: 'ARS', minimumFractionDigits: 0 }).format(n)
const fmtFecha = d => d ? new Date(d + 'T00:00:00').toLocaleDateString('es-AR', { day: 'numeric', month: 'short', year: 'numeric' }) : '—'
const esEntregaHoy = r => r.estado === 'pendiente' && r.fecha_entrega_estimada === hoy
const esVencidaHoy = r => r.estado === 'pendiente' && r.fecha_entrega_estimada < hoy

async function cargar() {
  loading.value = true
  try {
    const { data } = await listReservas(estado.value ? { estado: estado.value } : {})
    reservas.value = data.reservas || []
  } catch {
    reservas.value = []
  } finally {
    loading.value = false
  }
}

async function entregar(r) {
  const ok = await confirm({
    title: 'Entregar reserva',
    message: `Se creará la dispensación de ${r.cantidad}${r.stock?.unidad || 'g'} para ${r.paciente?.nombre}` +
             (r.aporte_restante_ars > 0 ? ` y se cobrará ${fmt(r.aporte_restante_ars)}.` : '.'),
    confirmText: 'Entregar',
  })
  if (!ok) return
  busy.value = r.id
  try {
    await entregarReserva(r.id)
    toast.success('Reserva entregada')
    await cargar()
  } catch (e) {
    toast.error(e.response?.data?.errors?.[0] || e.response?.data?.error || 'No se pudo entregar')
  } finally { busy.value = null }
}

async function cancelar(r) {
  const ok = await confirm({
    title: 'Cancelar reserva',
    message: `¿Cancelar la reserva de ${r.paciente?.nombre}? Se libera el stock apartado.`,
    confirmText: 'Cancelar reserva', danger: true,
  })
  if (!ok) return
  busy.value = r.id
  try {
    await cancelarReserva(r.id)
    toast.success('Reserva cancelada')
    await cargar()
  } catch (e) {
    toast.error(e.response?.data?.error || 'No se pudo cancelar')
  } finally { busy.value = null }
}

onMounted(cargar)
</script>

<style scoped>
.rsv { padding: var(--sp-6, 1.5rem); max-width: 1100px; margin: 0 auto; }
.rsv__header { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; margin-bottom: 1.5rem; }
.rsv__title { font-size: 1.5rem; font-weight: 800; color: var(--c-ink-900, #0f172a); margin: 0 0 .2rem; }
.rsv__sub { font-size: .85rem; color: var(--c-ink-500, #64748b); margin: 0; }
.rsv__select { border: 1.5px solid var(--c-ink-200, #e2e8f0); border-radius: 8px; padding: .45rem .7rem; font-size: .85rem; background: #fff; }
.rsv__loading { display: flex; justify-content: center; padding: 3rem; }
.rsv__empty { text-align: center; padding: 3rem; color: var(--c-ink-400, #94a3b8); }
.rsv__empty i { font-size: 2rem; display: block; margin-bottom: .5rem; }

.rsv__table { width: 100%; border-collapse: collapse; background: #fff; border: 1.5px solid var(--c-ink-100, #f1f5f9); border-radius: 12px; overflow: hidden; font-size: .85rem; }
.rsv__table th { text-align: left; padding: 10px 14px; font-size: 11px; font-weight: 700; text-transform: uppercase; letter-spacing: .05em; color: var(--c-ink-400, #94a3b8); background: #f8fafc; border-bottom: 1.5px solid var(--c-ink-100, #f1f5f9); }
.rsv__table td { padding: 11px 14px; border-bottom: 1px solid var(--c-ink-100, #f1f5f9); vertical-align: middle; }
.rsv__row--vencida { background: #fff7ed; }
.rsv__lote { color: var(--c-ink-400, #94a3b8); }
.rsv__fecha--hoy { font-weight: 800; color: #b45309; }

.rsv__pill { font-size: 11px; font-weight: 700; padding: 2px 9px; border-radius: 999px; }
.rsv__pill--pendiente { background: #fef9c3; color: #854d0e; }
.rsv__pill--entregada { background: #dcfce7; color: #14532d; }
.rsv__pill--cancelada { background: #f1f5f9; color: #475569; }
.rsv__pill--vencida   { background: #fee2e2; color: #991b1b; }

.rsv__actions { text-align: right; white-space: nowrap; }
.rsv__btn { border: none; border-radius: 7px; padding: .35rem .7rem; font-size: .78rem; font-weight: 700; cursor: pointer; margin-left: .35rem; }
.rsv__btn--primary { background: #15803d; color: #fff; }
.rsv__btn--primary:hover:not(:disabled) { background: #166534; }
.rsv__btn--ghost { background: transparent; border: 1.5px solid var(--c-ink-200, #e2e8f0); color: var(--c-ink-600, #475569); }
.rsv__btn:disabled { opacity: .5; cursor: not-allowed; }
</style>
