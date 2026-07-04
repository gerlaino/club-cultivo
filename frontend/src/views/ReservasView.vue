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

    <!-- Modal editar -->
    <Teleport to="body">
      <div v-if="showEdit" class="rsv__overlay">
        <div class="rsv__modal">
          <div class="rsv__modal-head">
            <h3>Editar reserva</h3>
            <button class="rsv__modal-close" @click="showEdit = false"><i class="bi bi-x-lg"></i></button>
          </div>
          <div class="rsv__modal-body">
            <div v-if="editError" class="rsv__modal-err">{{ editError }}</div>
            <label class="rsv__modal-label">Cantidad</label>
            <input v-model.number="editForm.cantidad" type="number" min="0.01" step="0.01" class="rsv__modal-input" />
            <label class="rsv__modal-label">Fecha de entrega estimada</label>
            <AppDatePicker v-model="editForm.fecha_entrega_estimada" :min="hoy" />
            <label class="rsv__modal-label">Seña</label>
            <input v-model.number="editForm.sena_ars" type="number" min="0" step="1" class="rsv__modal-input" placeholder="0" />
            <template v-if="editTieneSena">
              <label class="rsv__modal-label">Medio de pago de la seña</label>
              <select v-model="editForm.medio_pago" class="rsv__modal-input">
                <option value="efectivo">Efectivo</option>
                <option value="transferencia">Transferencia</option>
              </select>
            </template>
          </div>
          <div class="rsv__modal-foot">
            <button class="rsv__btn rsv__btn--ghost" @click="showEdit = false">Cancelar</button>
            <button class="rsv__btn rsv__btn--primary" :disabled="savingEdit" @click="guardarEdicion">Guardar</button>
          </div>
        </div>
      </div>
    </Teleport>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import DsSpinner from '../design-system/components/Spinner.vue'
import AppDatePicker from '../components/ui/AppDatePicker.vue'
import ModalNuevaDispensacion from '../components/pacientes/ModalNuevaDispensacion.vue'
import { listReservas, cancelarReserva, anularSenaReserva, updateReserva, deleteReserva } from '../lib/api.js'
import { useToast } from '../composables/useToast.js'
import { useConfirm } from '../composables/useConfirm.js'
import { useAuthStore } from '../stores/auth'

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

// ── Entrega (modal dedicado) ──
const showEntrega = ref(false)
const reservaSel  = ref(null)
function abrirEntrega(r) { reservaSel.value = r; showEntrega.value = true }

// ── Edición ──
const showEdit   = ref(false)
const savingEdit = ref(false)
const editError  = ref(null)
const editForm   = ref({ id: null, cantidad: null, fecha_entrega_estimada: '', medio_pago: 'efectivo', sena_ars: 0 })
// El medio de pago solo aplica si se dejó seña (es el medio con que se pagó esa seña).
const editTieneSena = computed(() => Number(editForm.value.sena_ars) > 0)

function abrirEdicion(r) {
  editForm.value = {
    id: r.id, cantidad: r.cantidad,
    fecha_entrega_estimada: r.fecha_entrega_estimada,
    medio_pago: r.medio_pago || 'efectivo',
    sena_ars: r.sena_ars || 0,
  }
  editError.value = null
  showEdit.value = true
}

async function guardarEdicion() {
  savingEdit.value = true
  editError.value = null
  try {
    const { id, ...payload } = editForm.value
    await updateReserva(id, payload)
    toast.success('Reserva actualizada')
    showEdit.value = false
    await cargar()
  } catch (e) {
    editError.value = e.response?.data?.errors?.[0] || e.response?.data?.error || 'No se pudo guardar'
  } finally { savingEdit.value = false }
}

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
.rsv__btn--danger { background: transparent; border: 1.5px solid #fecaca; color: #dc2626; }
.rsv__btn--danger:hover:not(:disabled) { background: #fef2f2; }
.rsv__btn:disabled { opacity: .5; cursor: not-allowed; }

/* Modal editar */
.rsv__overlay { position: fixed; inset: 0; background: rgba(0,0,0,.45); display: flex; align-items: center; justify-content: center; z-index: 1060; padding: 1rem; backdrop-filter: blur(3px); }
.rsv__modal { background: #fff; border-radius: 14px; width: 100%; max-width: 400px; box-shadow: 0 24px 64px rgba(0,0,0,.18); }
.rsv__modal-head { display: flex; align-items: center; justify-content: space-between; padding: 1rem 1.25rem; border-bottom: 1px solid #f1f5f9; }
.rsv__modal-head h3 { font-size: 1rem; font-weight: 800; margin: 0; color: #0f172a; }
.rsv__modal-close { background: #f1f5f9; border: none; width: 28px; height: 28px; border-radius: 7px; cursor: pointer; color: #64748b; }
.rsv__modal-body { padding: 1rem 1.25rem; display: flex; flex-direction: column; gap: .5rem; }
.rsv__modal-err { background: #fef2f2; color: #dc2626; border: 1px solid #fecaca; border-radius: 8px; padding: .5rem .7rem; font-size: .8rem; }
.rsv__modal-label { font-size: .72rem; font-weight: 700; color: #374151; text-transform: uppercase; letter-spacing: .04em; margin-top: .3rem; }
.rsv__modal-input { background: #f8fafc; border: 1.5px solid #e2e8f0; border-radius: 9px; padding: .55rem .8rem; font-size: .85rem; color: #0f172a; width: 100%; box-sizing: border-box; outline: none; }
.rsv__modal-foot { display: flex; justify-content: flex-end; gap: .6rem; padding: .85rem 1.25rem; border-top: 1px solid #f1f5f9; }
</style>
