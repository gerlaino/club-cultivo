<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { logger } from '../../utils/logger.js'
import { useAuthStore } from '../../stores/auth'
import { useConfirm } from '../../composables/useConfirm.js'
import { useToast } from '../../composables/useToast.js'
import { useEtiquetaDispensa } from '../../composables/useEtiquetaDispensa.js'
import DsSpinner from '../../design-system/components/Spinner.vue'
import { listDispensaciones, deleteDispensacion, listReservasPaciente, deleteReserva, cancelarReserva } from '../../lib/api.js'
import ModalNuevaDispensacion from './ModalNuevaDispensacion.vue'
import ModalEditarDispensacion from './ModalEditarDispensacion.vue'
import ModalEntregarReserva from './ModalEntregarReserva.vue'
import ModalEditarReserva from './ModalEditarReserva.vue'

const props = defineProps({
  socioId:          { type: Number,  required: true },
  pacienteNombre:   { type: String,  default: '' },
  saldoCc:          { type: Number,  default: null },
  limiteCc:         { type: Number,  default: null },
  descuentoPorcentaje: { type: Number,  default: 0 },
})

const emit = defineEmits(['dispensacion-creada'])

const auth         = useAuthStore()
const { confirm }  = useConfirm()
const toast        = useToast()
const { imprimirEtiqueta } = useEtiquetaDispensa()

const dispensaciones = ref([])
const loading        = ref(true)
const showModal      = ref(false)

// Edit modal state
const editModal  = ref(false)
const editTarget = ref(null)

const canCreate = computed(() => ['admin', 'dispensador', 'super_admin'].includes(auth.user?.role))
const canDelete = computed(() => ['admin', 'dispensador', 'super_admin'].includes(auth.user?.role))
const canEdit   = computed(() => ['admin', 'supervisor', 'super_admin'].includes(auth.user?.role))

const fmt = n => n == null ? '—' :
  new Intl.NumberFormat('es-AR', { style: 'currency', currency: 'ARS', minimumFractionDigits: 0 }).format(n)
const fmtDate = d => d
  ? new Date(d + 'T00:00:00').toLocaleDateString('es-AR', { day: 'numeric', month: 'short', year: 'numeric' })
  : '—'

const FORMA_LABEL = {
  flor_seca: 'Flor seca', hash: 'Hash', aceite: 'Aceite',
  preroll: 'Preroll', crema: 'Crema', descarte: 'Descarte', otro: 'Otro',
}
const FORMA_EMOJI = {
  flor_seca: '🌿', hash: '🟤', aceite: '🫙',
  preroll: '🚬', crema: '💊', descarte: '🗑️', otro: '📦',
}

function openCreate() { showModal.value = true }

async function onDispensacionGuardada() {
  await loadDispensaciones()
  emit('dispensacion-creada')
}

async function handleDelete(d) {
  const stk   = d.stock
  const label = `${d.cantidad}${stk?.unidad || 'g'} de ${FORMA_LABEL[stk?.forma_producto] || stk?.forma_producto || '—'} · ${fmtDate(d.fecha_dispensacion)}`
  const ok    = await confirm({ title: '¿Eliminar dispensación?', message: label, confirmText: 'Eliminar', variant: 'danger' })
  if (!ok) return
  try {
    await deleteDispensacion(d.id)
    await loadDispensaciones()
    toast.success('Dispensación eliminada')
  } catch { toast.error('Error al eliminar') }
}

function openEdit(d) {
  editTarget.value = d
  editModal.value  = true
}

async function loadDispensaciones() {
  loading.value = true
  try {
    const { data } = await listDispensaciones(props.socioId)
    dispensaciones.value = data.dispensaciones || data || []
  } catch (e) { logger.error(e) }
  finally { loading.value = false }
}

const totalCantidad = computed(() => dispensaciones.value.reduce((s, d) => s + (parseFloat(d.cantidad) || 0), 0))

// ── Reservas pendientes del socio ──
const reservasPend  = ref([])
const showEntrega   = ref(false)
const reservaSel    = ref(null)
const hoyISO        = new Date().toISOString().split('T')[0]

async function loadReservas() {
  try {
    const { data } = await listReservasPaciente(props.socioId)
    reservasPend.value = (data.reservas || []).filter(r => r.estado === 'pendiente')
  } catch { reservasPend.value = [] }
}
function abrirEntregaReserva(r) { reservaSel.value = r; showEntrega.value = true }
const showEditarReserva = ref(false)
function abrirEditarReserva(r) { reservaSel.value = r; showEditarReserva.value = true }
async function onReservaEntregada() { await Promise.all([loadReservas(), loadDispensaciones()]) }
async function eliminarReserva(r) {
  const accion = r.sena_ars > 0 ? 'cancelar' : 'eliminar'
  const ok = await confirm({
    title: r.sena_ars > 0 ? 'Cancelar reserva' : 'Eliminar reserva',
    message: `Se libera el stock apartado de ${r.cantidad}${r.stock?.unidad || 'g'}.` + (r.sena_ars > 0 ? ' La seña no se reintegra.' : ''),
    confirmText: r.sena_ars > 0 ? 'Cancelar reserva' : 'Eliminar', variant: 'danger',
  })
  if (!ok) return
  try {
    r.sena_ars > 0 ? await cancelarReserva(r.id) : await deleteReserva(r.id)
    await loadReservas()
    toast.success(r.sena_ars > 0 ? 'Reserva cancelada' : 'Reserva eliminada')
  } catch (e) { toast.error(e.response?.data?.error || 'Error') }
}

function dvEscapeHandler(e) {
  if (e.key === 'Escape' && showModal.value) { showModal.value = false }
}
async function onDispensacionGuardadaConReservas() {
  await onDispensacionGuardada()
  await loadReservas()
}

onMounted(() => {
  loadDispensaciones()
  loadReservas()
  document.addEventListener('keydown', dvEscapeHandler, true)
})
onUnmounted(() => document.removeEventListener('keydown', dvEscapeHandler, true))
</script>

<template>
  <div class="dv">

    <!-- Header -->
    <div class="dv__header">
      <div>
        <div class="dv__header-title"><i class="bi bi-capsule"></i> Dispensaciones</div>
        <div class="dv__header-sub">
          Entregas regulatorias al socio
          <span v-if="dispensaciones.length"> · <strong>{{ totalCantidad.toFixed(1) }}g</strong> dispensados en total</span>
        </div>
      </div>
      <button v-if="canCreate" class="dv__btn-primary" @click="openCreate">
        <i class="bi bi-plus-lg"></i> Nueva
      </button>
    </div>

    <!-- Reservas pendientes -->
    <div v-if="reservasPend.length" class="dv__reservas">
      <div class="dv__reservas-title"><i class="bi bi-bookmark-star"></i> Reservas pendientes</div>
      <div v-for="r in reservasPend" :key="r.id" class="dv__reserva"
           :class="{ 'dv__reserva--vencida': r.fecha_entrega_estimada < hoyISO }">
        <div class="dv__reserva-info">
          <span class="dv__reserva-prod">{{ FORMA_LABEL[r.stock?.forma_producto] || r.stock?.forma_producto }} · {{ r.cantidad }}{{ r.stock?.unidad || 'g' }}</span>
          <span class="dv__reserva-meta">
            entrega {{ fmtDate(r.fecha_entrega_estimada) }}
            <template v-if="r.sena_ars > 0"> · seña {{ fmt(r.sena_ars) }}</template>
            <template v-if="r.aporte_restante_ars != null"> · resta {{ fmt(r.aporte_restante_ars) }}</template>
          </span>
        </div>
        <div v-if="canCreate" class="dv__reserva-acts">
          <button class="dv__reserva-btn dv__reserva-btn--primary" @click="abrirEntregaReserva(r)">Entregar</button>
          <button class="dv__reserva-btn" @click="abrirEditarReserva(r)">Editar</button>
          <button class="dv__reserva-btn" @click="eliminarReserva(r)">{{ r.sena_ars > 0 ? 'Cancelar' : 'Eliminar' }}</button>
        </div>
      </div>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="dv__loading"><DsSpinner /></div>

    <!-- Vacío -->
    <div v-else-if="!dispensaciones.length" class="dv__empty">
      <div class="dv__empty-icon"><i class="bi bi-capsule"></i></div>
      <div class="dv__empty-title">Sin dispensaciones registradas</div>
      <button v-if="canCreate" class="dv__btn-primary" @click="openCreate" style="margin-top:.75rem">
        <i class="bi bi-plus-lg"></i> Registrar primera
      </button>
    </div>

    <!-- Lista -->
    <div v-else class="dv__list">
      <div v-for="d in dispensaciones" :key="d.id" class="dv__item">
        <div class="dv__item-left">
          <div class="dv__item-fecha">{{ fmtDate(d.fecha_dispensacion) }}</div>
          <div class="dv__item-desc">
            <span class="dv__stock-pill">
              {{ FORMA_EMOJI[d.stock?.forma_producto] }} {{ FORMA_LABEL[d.stock?.forma_producto] || d.stock?.forma_producto || '—' }}
            </span>
            <span v-if="d.stock?.lote?.codigo || d.lote_codigo" class="dv__lote-ref">
              <i class="bi bi-box-seam"></i> {{ d.stock?.lote?.codigo || d.lote_codigo }}
              <span v-if="!d.stock" class="dv__lote-snap" title="Stock eliminado — dato preservado">(histórico)</span>
            </span>
          </div>
          <div v-if="Number(d.descuento_dispensa_pct) > 0 || Number(d.descuento_paciente_pct) > 0" class="dv__item-desc-info">
            <i class="bi bi-tag"></i>
            <span v-if="Number(d.descuento_paciente_pct) > 0">socio {{ Number(d.descuento_paciente_pct) }}%</span>
            <span v-if="Number(d.descuento_dispensa_pct) > 0">
              · dispensa {{ Number(d.descuento_dispensa_pct) }}%<template v-if="d.descuento_otorgado_por"> (otorgó {{ d.descuento_otorgado_por }})</template>
            </span>
          </div>
          <div v-if="d.observaciones" class="dv__item-obs">{{ d.observaciones }}</div>
          <div v-if="d.con_envio" class="dv__item-envio-badge"
               :class="`dv__item-envio-badge--${d.estado_envio || 'pendiente'}`">
            <i class="bi bi-bicycle"></i>
            {{ { pendiente: 'Pendiente envío', en_viaje: 'En camino', entregado: 'Entregado', fallido: 'Fallo de entrega' }[d.estado_envio] || 'Con envío' }}
          </div>
        </div>
        <div class="dv__item-right">
          <div class="dv__item-cantidad">{{ d.cantidad }}{{ d.stock?.unidad || 'g' }}</div>
          <div v-if="d.aporte_socio_ars" class="dv__item-aporte">{{ fmt(d.aporte_socio_ars) }}</div>
          <div v-if="d.usuario?.nombre" class="dv__item-usuario">{{ d.usuario.nombre }}</div>
        </div>
        <div v-if="canEdit || canDelete || d.token" class="dv__item-actions">
          <button v-if="d.token" class="dv__icon-btn" @click="imprimirEtiqueta(d)" title="Imprimir etiqueta">
            <i class="bi bi-upc-scan"></i>
          </button>
          <button v-if="canEdit" class="dv__icon-btn" @click="openEdit(d)" title="Editar">
            <i class="bi bi-pencil"></i>
          </button>
          <button v-if="canDelete" class="dv__icon-btn dv__icon-btn--danger" @click="handleDelete(d)" title="Eliminar">
            <i class="bi bi-trash"></i>
          </button>
        </div>
      </div>
    </div>

    <!-- Modal editar dispensación -->
    <ModalEditarDispensacion
      v-model="editModal"
      :dispensacion="editTarget"
      :saldo-cc="props.saldoCc"
      :limite-cc="props.limiteCc"
      @saved="loadDispensaciones"
    />

    <!-- Modal nueva dispensación -->
    <ModalNuevaDispensacion
      v-model="showModal"
      :socio-id="props.socioId"
      :paciente-nombre="props.pacienteNombre"
      :saldo-cc="props.saldoCc"
      :limite-cc="props.limiteCc"
      :descuento-porcentaje="props.descuentoPorcentaje"
      @saved="onDispensacionGuardadaConReservas"
    />

    <!-- Modal entregar reserva -->
    <ModalEntregarReserva v-model="showEntrega" :reserva="reservaSel" @entregada="onReservaEntregada" />

    <!-- Modal editar reserva -->
    <ModalEditarReserva v-model="showEditarReserva" :reserva="reservaSel" @saved="loadReservas" />
  </div>
</template>

<style scoped>
.dv { font-family: system-ui, -apple-system, sans-serif; color: #0f172a; }
.dv__header { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; padding: 1.1rem 1.25rem; border-bottom: 1px solid #f1f5f9; flex-wrap: wrap; }
.dv__header-title { font-size: .9rem; font-weight: 700; color: #0f172a; margin-bottom: .2rem; }
.dv__header-sub { font-size: .75rem; color: #64748b; }
.dv__loading { display: flex; align-items: center; justify-content: center; padding: 2rem; }
.dv__loading-inline { display: flex; align-items: center; gap: .5rem; font-size: .8rem; color: #94a3b8; padding: .5rem 0; }
.dv__empty { text-align: center; padding: 3rem 1rem; color: #94a3b8; }
.dv__empty-icon { font-size: 2.5rem; margin-bottom: .75rem; opacity: .4; }
.dv__empty-title { font-size: .9rem; font-weight: 700; color: #0f172a; margin-bottom: .4rem; }

/* Lista */
.dv__list { display: flex; flex-direction: column; }
.dv__item { display: flex; align-items: center; gap: 1rem; padding: .875rem 1.25rem; border-bottom: 1px solid #f8fafc; transition: background .1s; }
.dv__item:last-child { border-bottom: none; }
.dv__item:hover { background: #fafbfc; }
.dv__item-left { flex: 1; min-width: 0; }
.dv__item-fecha { font-size: .72rem; color: #94a3b8; font-family: monospace; margin-bottom: .25rem; }
.dv__item-desc { display: flex; align-items: center; gap: .5rem; flex-wrap: wrap; margin-bottom: .15rem; }
.dv__stock-pill { font-size: .7rem; font-weight: 700; background: rgba(21,128,61,.1); color: #15803d; padding: .2em .65em; border-radius: 6px; }
.dv__lote-ref { font-size: .7rem; color: #64748b; display: flex; align-items: center; gap: .25rem; }
.dv__lote-snap { color: #94a3b8; font-style: italic; }
.dv__item-obs { font-size: .73rem; color: #94a3b8; font-style: italic; }
.dv__item-desc-info { font-size: .72rem; color: #b45309; display: flex; align-items: center; gap: .3rem; flex-wrap: wrap; }
/* Reservas pendientes */
.dv__reservas { margin: .9rem 1.25rem; border: 1px solid #fde68a; background: #fffbeb; border-radius: 10px; padding: .6rem .8rem; }
.dv__reservas-title { font-size: .72rem; font-weight: 800; text-transform: uppercase; letter-spacing: .05em; color: #92400e; margin-bottom: .5rem; display: flex; align-items: center; gap: .35rem; }
.dv__reserva { display: flex; align-items: center; justify-content: space-between; gap: .75rem; padding: .5rem 0; border-top: 1px solid #fde68a; }
.dv__reserva:first-of-type { border-top: none; }
.dv__reserva--vencida { color: #b91c1c; }
.dv__reserva-prod { font-size: .82rem; font-weight: 700; color: #0f172a; display: block; }
.dv__reserva-meta { font-size: .72rem; color: #92400e; }
.dv__reserva-acts { display: flex; gap: .35rem; flex-shrink: 0; }
.dv__reserva-btn { border: 1.5px solid #e2e8f0; background: #fff; border-radius: 7px; padding: .3rem .6rem; font-size: .75rem; font-weight: 700; cursor: pointer; color: #475569; }
.dv__reserva-btn--primary { background: #15803d; color: #fff; border-color: #15803d; }
.dv__item-envio-badge { display: inline-flex; align-items: center; gap: .25rem; margin-top: .2rem; font-size: 12px; font-weight: 600; padding: .15em .55em; border-radius: 5px; }
.dv__item-envio-badge--pendiente { background: var(--c-sky-100);   color: var(--c-sky-600); }
.dv__item-envio-badge--en_viaje  { background: var(--c-amber-100); color: var(--c-amber-500); }
.dv__item-envio-badge--entregado { background: var(--c-leaf-100);  color: var(--c-leaf-700); }
.dv__item-envio-badge--fallido   { background: var(--c-rust-100);  color: var(--c-rust-600); }
.dv__item-right { text-align: right; flex-shrink: 0; min-width: 80px; }
.dv__item-cantidad { font-size: 1.05rem; font-weight: 800; color: #1b5e20; letter-spacing: -.03em; }
.dv__item-aporte { font-size: .72rem; color: #64748b; margin-top: .1rem; }
.dv__item-usuario { font-size: .7rem; color: #94a3b8; }
.dv__item-actions { display: flex; gap: .3rem; flex-shrink: 0; }
.dv__icon-btn { width: 28px; height: 28px; border-radius: 7px; border: 1px solid #e2e8f0; background: #f8fafc; color: #64748b; display: flex; align-items: center; justify-content: center; cursor: pointer; font-size: .75rem; transition: all .15s; flex-shrink: 0; }
.dv__icon-btn:hover { background: #f1f5f9; color: #334155; }
.dv__icon-btn--danger:hover { background: #fef2f2; border-color: #fecaca; color: #dc2626; }


/* Buttons */
.dv__btn-primary { display: inline-flex; align-items: center; gap: .4rem; background: #1b5e20; color: #fff; border: none; padding: .6rem 1.1rem; border-radius: 9px; font-size: .82rem; font-weight: 600; cursor: pointer; transition: background .15s; white-space: nowrap; }
.dv__btn-primary:hover:not(:disabled) { background: #144a18; }
.dv__btn-primary:disabled { opacity: .5; cursor: not-allowed; }
.dv__btn-ghost { background: #fff; color: #64748b; border: 1.5px solid #e2e8f0; padding: .6rem 1.1rem; border-radius: 9px; font-size: .875rem; font-weight: 500; cursor: pointer; }
.dv__btn-ghost:hover { background: #f8fafc; }

/* Modal */
.dv__overlay { position: fixed; inset: 0; background: rgba(0,0,0,.45); display: flex; align-items: center; justify-content: center; z-index: 1050; padding: 1rem; backdrop-filter: blur(3px); }
.dv__modal { background: #fff; border-radius: 18px; width: 100%; max-width: 640px; max-height: 92vh; overflow-y: auto; box-shadow: 0 24px 64px rgba(0,0,0,.18); display: flex; flex-direction: column; }
.dv__modal-header { display: flex; align-items: center; justify-content: space-between; gap: 1rem; padding: 1.1rem 1.25rem .9rem; border-bottom: 1px solid #f1f5f9; position: sticky; top: 0; background: #fff; z-index: 1; }
.dv__modal-title { font-size: .95rem; font-weight: 800; color: #0f172a; margin: 0; }
.dv__modal-title-paciente { color: var(--c-leaf-700); font-weight: 800; }
.dv__modal-close { background: #f1f5f9; border: none; width: 28px; height: 28px; border-radius: 7px; cursor: pointer; display: flex; align-items: center; justify-content: center; color: #64748b; }
.dv__modal-close:hover { background: #e2e8f0; }
.dv__modal-body { padding: 1.1rem 1.25rem; flex: 1; display: flex; flex-direction: column; gap: .9rem; }
.dv__modal-footer { display: flex; justify-content: flex-end; gap: .75rem; padding: .875rem 1.25rem; border-top: 1px solid #f1f5f9; position: sticky; bottom: 0; background: #fff; }

/* Section label */
.dv__section-label { font-size: .72rem; font-weight: 700; color: #374151; text-transform: uppercase; letter-spacing: .05em; }

/* Stock list */
.dv__stock-list { display: flex; flex-direction: column; gap: .35rem; max-height: 220px; overflow-y: auto; }
.dv__stock-row {
  display: flex;
  align-items: center;
  gap: .75rem;
  padding: .6rem .875rem;
  border-radius: 10px;
  border: 1.5px solid #e2e8f0;
  background: #fafbfc;
  cursor: pointer;
  text-align: left;
  transition: all .12s;
  width: 100%;
}
.dv__stock-row:hover { border-color: #86efac; background: #f0fdf4; }
.dv__stock-row--active { border-color: #1b5e20; background: #f0fdf4; }
.dv__stock-emoji { font-size: 1.1rem; flex-shrink: 0; }
.dv__stock-info { flex: 1; min-width: 0; display: flex; flex-direction: column; gap: .1rem; }
.dv__stock-nombre { font-size: .82rem; font-weight: 700; color: #0f172a; }
.dv__stock-gen { font-size: .72rem; color: #64748b; font-style: italic; }
.dv__stock-right { display: flex; flex-direction: column; align-items: flex-end; gap: .1rem; flex-shrink: 0; }
.dv__stock-disp  { font-size: .8rem; font-weight: 700; color: #1b5e20; font-family: monospace; }
.dv__stock-precio { font-size: .7rem; color: #64748b; font-family: monospace; white-space: nowrap; }
.dv__stock-check { color: #1b5e20; font-size: .9rem; flex-shrink: 0; }

/* Form */
.dv__divider { height: 1px; background: #f1f5f9; margin: .1rem 0; }
.dv__form-row { display: grid; grid-template-columns: 1fr 1fr; gap: .75rem; }
@media (max-width: 400px) { .dv__form-row { grid-template-columns: 1fr; } }
.dv__field { display: flex; flex-direction: column; gap: .3rem; }
.dv__label { font-size: .72rem; font-weight: 700; color: #374151; text-transform: uppercase; letter-spacing: .05em; }
.dv__req { color: #ef4444; }
.dv__opt { font-size: .67rem; font-weight: 400; color: #94a3b8; text-transform: none; letter-spacing: 0; }
.dv__input { background: #f8fafc; border: 1.5px solid #e2e8f0; border-radius: 9px; padding: .6rem .8rem; font-size: .875rem; color: #0f172a; width: 100%; box-sizing: border-box; outline: none; transition: border-color .15s; }
.dv__input:focus { border-color: #1b5e20; background: #fff; }
.dv__input--error { border-color: #ef4444 !important; background: #fef2f2; }
.dv__field-error { font-size: .72rem; color: #dc2626; font-weight: 600; }
.dv__field-hint  { font-size: .72rem; color: #94a3b8; }
.dv__textarea { resize: vertical; min-height: 58px; }
.dv__input-suffix-wrap { display: flex; }
.dv__input--with-suffix { border-radius: 9px 0 0 9px; }
.dv__input-suffix { background: #f1f5f9; border: 1.5px solid #e2e8f0; border-left: none; padding: .6rem .65rem; font-size: .8rem; font-weight: 700; color: #64748b; border-radius: 0 9px 9px 0; white-space: nowrap; }
.dv__input-prefix { background: #f1f5f9; border: 1.5px solid #e2e8f0; border-right: none; padding: .6rem .65rem; font-size: .8rem; font-weight: 700; color: #64748b; border-radius: 9px 0 0 9px; white-space: nowrap; }
.dv__input--with-prefix { border-radius: 0 9px 9px 0; }
.dv__aporte-wrap { display: flex; flex-direction: column; gap: .6rem; }

/* Precio */
.dv__precio-box { background: #f0fdf4; border: 1.5px solid #bbf7d0; border-radius: 10px; padding: .7rem .9rem; display: flex; flex-direction: column; gap: .3rem; }
.dv__precio-row { display: flex; justify-content: space-between; font-size: .82rem; color: #374151; }
.dv__precio-row--desc { color: #b45309; }
.dv__precio-row--total { font-weight: 800; color: #1b5e20; font-size: .9rem; padding-top: .3rem; border-top: 1px solid #bbf7d0; margin-top: .1rem; }

/* Misc */
.dv__error { display: flex; align-items: center; gap: .45rem; background: #fef2f2; border: 1px solid #fecaca; color: #dc2626; padding: .6rem .875rem; border-radius: 9px; font-size: .82rem; }
.dv__warn-box { font-size: .8rem; color: #b45309; padding: .5rem .75rem; background: #fffbeb; border-radius: 8px; border: 1.5px dashed #fde68a; display: flex; align-items: center; gap: .5rem; }

/* Límite mensual */
.dv__limite-box {
  border-radius: 10px;
  padding: .65rem .875rem;
  border: 1.5px solid;
  display: flex;
  flex-direction: column;
  gap: .4rem;
}
.dv__limite-box--ok          { background: #f0fdf4; border-color: #86efac; }
.dv__limite-box--advertencia { background: #fffbeb; border-color: #fde68a; }
.dv__limite-box--critico     { background: #fff7ed; border-color: #fdba74; }
.dv__limite-box--agotado     { background: #fef2f2; border-color: #fca5a5; }

.dv__limite-header { display: flex; align-items: center; justify-content: space-between; }
.dv__limite-label  { font-size: .72rem; font-weight: 700; color: #374151; text-transform: uppercase; letter-spacing: .05em; display: flex; align-items: center; gap: .3rem; }
.dv__limite-nums   { font-size: .82rem; color: #374151; }
.dv__limite-nums strong { color: #0f172a; }
.dv__limite-sep    { color: #94a3b8; margin: 0 .2rem; }

.dv__limite-bar-track { height: 6px; background: rgba(0,0,0,.08); border-radius: 999px; overflow: hidden; }
.dv__limite-bar-fill  {
  height: 100%; border-radius: 999px; transition: width .4s ease;
}
.dv__limite-box--ok          .dv__limite-bar-fill { background: #22c55e; }
.dv__limite-box--advertencia .dv__limite-bar-fill { background: #eab308; }
.dv__limite-box--critico     .dv__limite-box--critico .dv__limite-bar-fill { background: #f97316; }
.dv__limite-box--agotado     .dv__limite-bar-fill { background: #ef4444; }
.dv__limite-box--critico .dv__limite-bar-fill { background: #f97316; }

.dv__limite-footer  { display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; gap: .3rem; }
.dv__limite-msg     { font-size: .75rem; display: flex; align-items: center; gap: .3rem; }
.dv__limite-msg--ok      { color: #15803d; }
.dv__limite-msg--warning { color: #b45309; }
.dv__limite-msg--danger  { color: #dc2626; }
.dv__limite-excede { font-size: .72rem; font-weight: 700; color: #dc2626; background: #fef2f2; border: 1px solid #fecaca; border-radius: 6px; padding: .15rem .5rem; }

/* Delivery toggle */
.dv__delivery-toggle {
  display: flex; align-items: center; justify-content: space-between; gap: .75rem;
  padding: .7rem .875rem; background: #f8fafc; border: 1.5px solid #e2e8f0;
  border-radius: 10px; cursor: pointer; user-select: none; transition: border-color .15s;
}
.dv__delivery-toggle:hover { border-color: #86efac; background: #f0fdf4; }
.dv__delivery-toggle-left { display: flex; align-items: center; gap: .6rem; }
.dv__delivery-toggle-title { font-size: .82rem; font-weight: 700; color: #0f172a; }
.dv__delivery-toggle-sub { font-size: .72rem; color: #64748b; margin-top: .05rem; }
.dv__toggle-switch { width: 36px; height: 20px; background: var(--c-ink-300); border-radius: 999px; position: relative; transition: background .2s; flex-shrink: 0; }
.dv__toggle-switch--on { background: var(--c-leaf-600); }
.dv__toggle-knob { position: absolute; top: 2px; left: 2px; width: 16px; height: 16px; background: #fff; border-radius: 50%; transition: transform .2s; box-shadow: 0 1px 3px rgba(0,0,0,.2); }
.dv__toggle-switch--on .dv__toggle-knob { transform: translateX(16px); }
.dv__delivery-section { display: flex; flex-direction: column; gap: .75rem; background: var(--c-leaf-50); border: 1.5px solid var(--c-leaf-100); border-radius: 12px; padding: .9rem; margin-top: -.4rem; }

/* Cuenta corriente */
.dv__cc-panel { border-radius: 10px; padding: .6rem .875rem; border: 1.5px solid; display: flex; flex-direction: column; gap: .3rem; }
.dv__cc-panel--ok          { background: #f0fdf4; border-color: #86efac; }
.dv__cc-panel--critico     { background: #fff7ed; border-color: #fdba74; }
.dv__cc-panel--insuficiente,
.dv__cc-panel--agotado     { background: #fef2f2; border-color: #fca5a5; }
.dv__cc-row   { display: flex; align-items: center; justify-content: space-between; gap: .5rem; }
.dv__cc-label { font-size: .72rem; font-weight: 700; color: #374151; text-transform: uppercase; letter-spacing: .05em; display: flex; align-items: center; gap: .3rem; }
.dv__cc-saldo { font-size: .875rem; font-weight: 800; color: #15803d; font-family: monospace; }
.dv__cc-saldo--bajo { color: #dc2626; }
.dv__cc-tras  { font-size: .75rem; color: #475569; }
.dv__cc-tras strong { color: #0f172a; font-family: monospace; }
.dv__cc-warn  { font-size: .75rem; color: #dc2626; display: flex; align-items: center; gap: .3rem; }
</style>
