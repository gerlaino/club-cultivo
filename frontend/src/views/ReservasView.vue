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
          <th>Paciente</th>
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
        <template v-for="g in gruposPorSede" :key="g.id ?? 'pool'">
          <tr v-if="agruparPorSede" class="rsv__sede-row">
            <td colspan="8">
              <i class="bi bi-geo-alt-fill"></i> {{ g.nombre }}
              <span class="rsv__sede-n">{{ g.reservas.length }}</span>
            </td>
          </tr>
        <tr v-for="r in g.reservas" :key="r.id" :class="{ 'rsv__row--vencida': esVencidaHoy(r) }">
          <td>{{ r.paciente?.nombre || '—' }}</td>
          <!-- Una fila por línea: con varios productos, cada uno con su cantidad al lado. -->
          <td>
            <div v-for="ln in lineasDe(r)" :key="ln.id ?? ln.stock_id" class="rsv__linea">
              {{ ln.genetica || formaLabel(ln.forma_producto) }}<span v-if="ln.lote" class="rsv__lote"> · {{ ln.lote }}</span>
            </div>
          </td>
          <td>
            <div v-for="ln in lineasDe(r)" :key="ln.id ?? ln.stock_id" class="rsv__linea">{{ ln.cantidad }}{{ ln.unidad || 'g' }}</div>
          </td>
          <td :class="{ 'rsv__fecha--hoy': esEntregaHoy(r) }">{{ fmtFecha(r.fecha_entrega_estimada) }}</td>
          <td>{{ r.sena_ars ? fmt(r.sena_ars) : '—' }}</td>
          <td>{{ r.aporte_restante_ars != null ? fmt(r.aporte_restante_ars) : '—' }}</td>
          <td><span class="rsv__pill" :class="`rsv__pill--${r.estado}`">{{ ESTADO_LABEL[r.estado] || r.estado }}</span></td>
          <td class="rsv__actions">
            <template v-if="r.estado === 'pendiente'">
              <button class="rsv__btn rsv__btn--primary" :disabled="busy === r.id" @click="abrirEntrega(r)">Entregar</button>
              <!-- Gestión de la reserva: solo admin/supervisor. -->
              <template v-if="canGestionarReservas">
                <button class="rsv__btn rsv__btn--ghost" :disabled="busy === r.id" @click="abrirEdicion(r)" title="Editar"><i class="bi bi-pencil"></i></button>
                <!-- Con seña: cancelar (preserva el asiento como ingreso) o anular seña (revierte el asiento + crédito de CC). Sin seña: eliminar (borrado limpio). -->
                <template v-if="r.sena_ars > 0">
                  <button class="rsv__btn rsv__btn--ghost" :disabled="busy === r.id" @click="cancelar(r)" title="Cancelar (libera stock; la seña queda como ingreso, no se reembolsa)">Cancelar</button>
                  <button class="rsv__btn rsv__btn--danger" :disabled="busy === r.id" @click="anularSena(r)" title="Anular seña: revierte el asiento contable y el crédito de cuenta corriente">Anular seña</button>
                </template>
                <button v-else class="rsv__btn rsv__btn--danger" :disabled="busy === r.id" @click="eliminar(r)" title="Eliminar (libera stock)"><i class="bi bi-trash3"></i></button>
              </template>
            </template>
          </td>
        </tr>
        </template>
      </tbody>
    </table>

    <!-- Modal entregar: reusa el modal de nueva dispensación en modo "entregar reserva" -->
    <ModalNuevaDispensacion
      v-if="reservaSel"
      v-model="showEntrega"
      :socio-id="reservaSel.paciente?.id"
      :paciente-nombre="reservaSel.paciente?.nombre"
      :saldo-cc="reservaSel.paciente?.saldo_cc ?? null"
      :limite-cc="reservaSel.paciente?.limite_cc ?? null"
      :reserva="reservaSel"
      @saved="cargar"
    />

    <!-- Editar: el mismo modal que la ficha del paciente. Estaba escrito dos veces. -->
    <ModalEditarReserva v-model="showEdit" :reserva="reservaEdit" @saved="cargar" />
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import DsSpinner from '../design-system/components/Spinner.vue'
import ModalNuevaDispensacion from '../components/pacientes/ModalNuevaDispensacion.vue'
import ModalEditarReserva from '../components/pacientes/ModalEditarReserva.vue'
import { lineasDe } from '../lib/reservaLineas.js'
import { formaLabel } from '../lib/formatters.js'
import { listReservas, cancelarReserva, anularSenaReserva, deleteReserva } from '../lib/api.js'
import { useToast } from '../composables/useToast.js'
import { useConfirm } from '../composables/useConfirm.js'
import { useAuthStore } from '../stores/auth'
import { hoyISO } from '../utils/dates.js'

const toast = useToast()
const { confirm } = useConfirm()
const auth = useAuthStore()

// El dispensador VE las reservas y las pasa a dispensa (Entregar), pero no las gestiona
// (editar/cancelar/eliminar) — eso es de admin/supervisor.
const canGestionarReservas = computed(() => ['admin', 'supervisor', 'super_admin'].includes(auth.user?.role))

const ESTADO_LABEL = {
  pendiente: 'Pendiente', entregada: 'Entregada', cancelada: 'Cancelada', vencida: 'Vencida',
}

const reservas = ref([])

// ── Agrupadas por sede ───────────────────────────────────────────────────────────
// Quien atiende más de una sede no puede leer una lista con las reservas de dos mostradores
// mezcladas: la de al lado no la va a entregar él. Con una sola sede no se agrupa nada — un
// encabezado que siempre dice lo mismo es ruido.
const gruposPorSede = computed(() => {
  const mapa = new Map()
  for (const r of reservas.value) {
    const id = r.stock?.sede?.id ?? null
    if (!mapa.has(id)) {
      mapa.set(id, { id, nombre: r.stock?.sede?.nombre || 'Sin sede (club)', reservas: [] })
    }
    mapa.get(id).reservas.push(r)
  }
  return [...mapa.values()]
    .sort((a, b) => (a.id === null) - (b.id === null) || a.nombre.localeCompare(b.nombre))
})
const agruparPorSede = computed(() => gruposPorSede.value.length > 1)
const loading  = ref(true)
const busy     = ref(null)
const estado   = ref('pendiente')

const hoy = hoyISO()

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

// ── Entrega (modal dedicado) ──
const showEntrega = ref(false)
const reservaSel  = ref(null)
function abrirEntrega(r) { reservaSel.value = r; showEntrega.value = true }

// ── Edición ──
const showEdit    = ref(false)
const reservaEdit = ref(null)
function abrirEdicion(r) { reservaEdit.value = r; showEdit.value = true }

async function eliminar(r) {
  const ok = await confirm({
    title: 'Eliminar reserva',
    message: `¿Eliminar la reserva de ${r.paciente?.nombre}? Se libera el stock apartado. Esta acción no se puede deshacer.`,
    confirmText: 'Eliminar', variant: 'danger',
  })
  if (!ok) return
  busy.value = r.id
  try {
    await deleteReserva(r.id)
    toast.success('Reserva eliminada')
    await cargar()
  } catch (e) {
    toast.error(e.response?.data?.error || 'No se pudo eliminar')
  } finally { busy.value = null }
}

async function cancelar(r) {
  const ok = await confirm({
    title: 'Cancelar reserva',
    message: `¿Cancelar la reserva de ${r.paciente?.nombre}? Se libera el stock apartado.`,
    confirmText: 'Cancelar reserva', variant: 'danger',
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

async function anularSena(r) {
  const ok = await confirm({
    title: 'Anular seña',
    message: `¿Anular la seña de ${fmt(r.sena_ars)} de ${r.paciente?.nombre}? Se revierte el ingreso del libro contable y el crédito en su cuenta corriente. La reserva queda sin seña (después podés eliminarla).`,
    confirmText: 'Anular seña', variant: 'danger',
  })
  if (!ok) return
  busy.value = r.id
  try {
    await anularSenaReserva(r.id)
    toast.success('Seña anulada (asiento y crédito revertidos)')
    await cargar()
  } catch (e) {
    toast.error(e.response?.data?.error || 'No se pudo anular la seña')
  } finally { busy.value = null }
}

onMounted(cargar)
</script>

<style scoped>
.rsv { padding: var(--sp-6, 1.5rem); max-width: 1100px; margin: 0 auto; }
.rsv__header { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; margin-bottom: 1.5rem; }
.rsv__title { font-size: 1.5rem; font-weight: 800; color: var(--c-slate-900); margin: 0 0 .2rem; }
.rsv__sub { font-size: .85rem; color: var(--c-slate-500); margin: 0; }
.rsv__select { border: 1.5px solid var(--c-slate-200); border-radius: 8px; padding: .45rem .7rem; font-size: .85rem; background: #fff; }
.rsv__loading { display: flex; justify-content: center; padding: 3rem; }
.rsv__empty { text-align: center; padding: 3rem; color: var(--c-slate-400); }
.rsv__empty i { font-size: 2rem; display: block; margin-bottom: .5rem; }

.rsv__table { width: 100%; border-collapse: collapse; background: #fff; border: 1.5px solid var(--c-slate-100); border-radius: 12px; overflow: hidden; font-size: .85rem; }
.rsv__table th { text-align: left; padding: 10px 14px; font-size: 11px; font-weight: 700; text-transform: uppercase; letter-spacing: .05em; color: var(--c-slate-400); background: var(--c-slate-50); border-bottom: 1.5px solid var(--c-slate-100); }
.rsv__table td { padding: 11px 14px; border-bottom: 1px solid var(--c-slate-100); vertical-align: middle; }
.rsv__sede-row td {
  background: var(--c-slate-100); font-size: .74rem; font-weight: 700; color: var(--c-slate-700);
  text-transform: uppercase; letter-spacing: .04em; padding: .45rem .75rem;
}
.rsv__sede-row .bi { color: var(--c-slate-500); margin-right: .25rem; }
.rsv__sede-n { margin-left: .4rem; font-weight: 600; color: var(--c-slate-500); text-transform: none; letter-spacing: 0; }
.rsv__row--vencida { background: #fff7ed; }
.rsv__lote { color: var(--c-slate-400); }
.rsv__fecha--hoy { font-weight: 800; color: #b45309; }

.rsv__pill { font-size: 11px; font-weight: 700; padding: 2px 9px; border-radius: 999px; }
.rsv__pill--pendiente { background: #fef9c3; color: #854d0e; }
.rsv__pill--entregada { background: #dcfce7; color: #14532d; }
.rsv__pill--cancelada { background: var(--c-slate-100); color: var(--c-slate-600); }
.rsv__pill--vencida   { background: #fee2e2; color: #991b1b; }

.rsv__actions { text-align: right; white-space: nowrap; }
.rsv__btn { border: none; border-radius: 7px; padding: .35rem .7rem; font-size: .78rem; font-weight: 700; cursor: pointer; margin-left: .35rem; }
.rsv__btn--primary { background: #15803d; color: #fff; }
.rsv__btn--primary:hover:not(:disabled) { background: #166534; }
.rsv__btn--ghost { background: transparent; border: 1.5px solid var(--c-slate-200); color: var(--c-slate-600); }
.rsv__btn--danger { background: transparent; border: 1.5px solid #fecaca; color: #dc2626; }
.rsv__btn--danger:hover:not(:disabled) { background: #fef2f2; }
.rsv__btn:disabled { opacity: .5; cursor: not-allowed; }

.rsv__linea + .rsv__linea { margin-top: .15rem; }
</style>
