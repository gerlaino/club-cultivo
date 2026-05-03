<script setup>
import { ref, computed, watch, onMounted } from 'vue'
import { logger } from '../../utils/logger.js'
import { useAuthStore } from '../../stores/auth'
import { useConfirm } from '../../composables/useConfirm.js'
import { useToast } from '../../composables/useToast.js'
import {
  listDispensaciones, createDispensacion, deleteDispensacion,
  listStocks,
} from '../../lib/api.js'

const props = defineProps({
  socioId:        { type: Number,  required: true },
  limiteMensualG: { type: Number,  default: null },
  dispensadoMesG: { type: Number,  default: null },
  saldoCc:        { type: Number,  default: null },
  limiteCc:       { type: Number,  default: null },
})

const auth         = useAuthStore()
const { confirm }  = useConfirm()
const toast        = useToast()

const dispensaciones = ref([])
const stocks         = ref([])
const loading        = ref(true)
const loadingStocks  = ref(false)
const showModal      = ref(false)
const saving         = ref(false)
const formError      = ref(null)

const canCreate = computed(() => ['admin', 'cultivador', 'dispensador', 'medico'].includes(auth.user?.role))
const canDelete = computed(() => ['admin', 'dispensador'].includes(auth.user?.role))

const today = new Date().toISOString().split('T')[0]

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

const stocksRegulatorios = computed(() => stocks.value.filter(s => s.regulatorio && s.cantidad > 0))

// ── Límite mensual ────────────────────────────────────────────────────────────
const mesActual = new Date().toISOString().substring(0, 7)

const consumidoEsteMes = computed(() => {
  if (props.dispensadoMesG !== null) return props.dispensadoMesG
  return dispensaciones.value
    .filter(d => d.fecha_dispensacion?.startsWith(mesActual))
    .reduce((s, d) => s + (parseFloat(d.cantidad) || 0), 0)
})

const tieneLimite = computed(() => props.limiteMensualG != null && props.limiteMensualG > 0)

const pctConsumo = computed(() => {
  if (!tieneLimite.value) return 0
  return Math.min(100, (consumidoEsteMes.value / props.limiteMensualG) * 100)
})

const disponibleMes = computed(() => {
  if (!tieneLimite.value) return null
  return Math.max(0, props.limiteMensualG - consumidoEsteMes.value)
})

const excederiaLimite = computed(() => {
  if (!tieneLimite.value || !form.value.cantidad) return false
  return (consumidoEsteMes.value + parseFloat(form.value.cantidad)) > props.limiteMensualG
})

const excederiaStock = computed(() => {
  if (!stockSeleccionado.value || !form.value.cantidad) return false
  return parseFloat(form.value.cantidad) > stockSeleccionado.value.cantidad
})

const estadoLimite = computed(() => {
  if (!tieneLimite.value) return null
  const pct = pctConsumo.value
  if (pct >= 100)  return 'agotado'
  if (pct >= 80)   return 'critico'
  if (pct >= 50)   return 'advertencia'
  return 'ok'
})

// ── Cuenta corriente ──────────────────────────────────────────────────────────
// margen = cuánto puede gastar aún antes de ser bloqueado (saldo + limite)
const tieneCc   = computed(() => props.limiteCc !== null && props.limiteCc > 0)
const ccMargen  = computed(() => (props.saldoCc ?? 0) + (props.limiteCc ?? 0))
const ccDeuda   = computed(() => Math.max(0, -(props.saldoCc ?? 0)))

const ccInsuficiente = computed(() => {
  if (!tieneCc.value || form.value.aporte_socio_ars == null) return false
  return Number(form.value.aporte_socio_ars) > ccMargen.value
})

const estadoCc = computed(() => {
  if (!tieneCc.value) return null
  if (ccMargen.value <= 0)     return 'agotado'
  if (ccInsuficiente.value)    return 'insuficiente'
  if (ccMargen.value < (props.limiteCc ?? 0) * 0.2) return 'critico'
  return 'ok'
})

async function cargarStocks() {
  loadingStocks.value = true
  try {
    const { data } = await listStocks({ canal: 'regulatorio' })
    stocks.value = data || []
  } catch { stocks.value = [] }
  finally { loadingStocks.value = false }
}

// ── Formulario ────────────────────────────────────────────────────────────────
function emptyForm() {
  return {
    stock_id:           null,
    cantidad:           null,
    descuento_pct:      0,
    aporte_socio_ars:   null,
    fecha_dispensacion: today,
    observaciones:      '',
    medio_pago:         'efectivo',
  }
}
const form = ref(emptyForm())

const stockSeleccionado = computed(() => stocks.value.find(s => s.id === form.value.stock_id) || null)

const precioBase = computed(() => {
  const s   = stockSeleccionado.value
  const cnt = parseFloat(form.value.cantidad) || 0
  if (!s?.precio_sugerido_ars || cnt <= 0) return null
  return parseFloat(s.precio_sugerido_ars) * cnt
})

const precioFinal = computed(() => {
  if (precioBase.value == null) return null
  const desc = Math.max(0, Math.min(100, Number(form.value.descuento_pct) || 0))
  return precioBase.value * (1 - desc / 100)
})

// Auto-rellena el aporte cuando cambia el precio calculado, pero deja al admin editarlo
watch(precioFinal, (val) => {
  if (val != null) form.value.aporte_socio_ars = Math.round(val)
})

function openCreate() {
  form.value = emptyForm()
  formError.value = null
  showModal.value = true
  cargarStocks()
}

async function handleSubmit() {
  if (!form.value.stock_id)               { formError.value = 'Seleccioná un stock'; return }
  if (!form.value.cantidad || form.value.cantidad <= 0) { formError.value = 'La cantidad debe ser > 0'; return }
  if (excederiaStock.value) {
    const disp = stockSeleccionado.value.cantidad
    const uni  = stockSeleccionado.value.unidad || 'g'
    formError.value = `Stock insuficiente: solo hay ${disp}${uni} disponibles`
    return
  }

  if (excederiaLimite.value) {
    const ya   = consumidoEsteMes.value.toFixed(1)
    const esta = parseFloat(form.value.cantidad).toFixed(1)
    const lim  = props.limiteMensualG.toFixed(1)
    const ok = await confirm({
      title:       'Límite mensual superado',
      message:     `Este socio consumió ${ya}g este mes (límite: ${lim}g). Esta dispensación de ${esta}g excede el cupo. ¿Confirmás de todas formas?`,
      confirmText: 'Dispensar igualmente',
      variant:     'danger',
    })
    if (!ok) return
  }

  if (ccInsuficiente.value && form.value.medio_pago === 'cuenta_corriente') {
    formError.value = `Crédito insuficiente. Disponible: ${fmt(ccMargen.value)} — requerido: ${fmt(form.value.aporte_socio_ars)}`
    return
  }

  saving.value = true; formError.value = null
  try {
    const payload = {
      stock_id:           form.value.stock_id,
      cantidad:           form.value.cantidad,
      fecha_dispensacion: form.value.fecha_dispensacion,
      observaciones:      form.value.observaciones || undefined,
      medio_pago:         form.value.medio_pago,
    }
    if (form.value.aporte_socio_ars != null && form.value.aporte_socio_ars !== '') {
      payload.aporte_socio_ars = Number(form.value.aporte_socio_ars).toFixed(2)
    }
    await createDispensacion(props.socioId, payload)
    await loadDispensaciones()
    showModal.value = false
    toast.success('Dispensación registrada')
  } catch (e) {
    formError.value = e.response?.data?.errors?.[0] || e.response?.data?.error || 'Error al guardar'
  } finally { saving.value = false }
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

async function loadDispensaciones() {
  loading.value = true
  try {
    const { data } = await listDispensaciones(props.socioId)
    dispensaciones.value = data.dispensaciones || data || []
  } catch (e) { logger.error(e) }
  finally { loading.value = false }
}

const totalCantidad = computed(() => dispensaciones.value.reduce((s, d) => s + (parseFloat(d.cantidad) || 0), 0))

onMounted(loadDispensaciones)
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

    <!-- Loading -->
    <div v-if="loading" class="dv__loading"><div class="dv__ring"></div><span>Cargando…</span></div>

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
            <span v-if="d.stock?.lote?.codigo" class="dv__lote-ref">
              <i class="bi bi-box-seam"></i> {{ d.stock.lote.codigo }}
            </span>
          </div>
          <div v-if="d.observaciones" class="dv__item-obs">{{ d.observaciones }}</div>
        </div>
        <div class="dv__item-right">
          <div class="dv__item-cantidad">{{ d.cantidad }}{{ d.stock?.unidad || 'g' }}</div>
          <div v-if="d.aporte_socio_ars" class="dv__item-aporte">{{ fmt(d.aporte_socio_ars) }}</div>
          <div v-if="d.usuario?.nombre" class="dv__item-usuario">{{ d.usuario.nombre }}</div>
        </div>
        <button v-if="canDelete" class="dv__icon-btn dv__icon-btn--danger" @click="handleDelete(d)" title="Eliminar">
          <i class="bi bi-trash"></i>
        </button>
      </div>
    </div>

    <!-- ══ Modal nueva dispensación ══ -->
    <Teleport to="body">
      <div v-if="showModal" class="dv__overlay" @click.self="showModal=false">
        <div class="dv__modal">

          <div class="dv__modal-header">
            <div>
              <h3 class="dv__modal-title">Nueva dispensación</h3>
            </div>
            <button class="dv__modal-close" @click="showModal=false"><i class="bi bi-x-lg"></i></button>
          </div>

          <div class="dv__modal-body">
            <div v-if="formError" class="dv__error"><i class="bi bi-exclamation-triangle-fill"></i> {{ formError }}</div>

            <!-- ── Consumo mensual ── -->
            <div v-if="tieneLimite" class="dv__limite-box" :class="`dv__limite-box--${estadoLimite}`">
              <div class="dv__limite-header">
                <span class="dv__limite-label">
                  <i class="bi bi-calendar-month"></i>
                  Cupo mensual
                </span>
                <span class="dv__limite-nums">
                  <strong>{{ consumidoEsteMes.toFixed(1) }}g</strong>
                  <span class="dv__limite-sep">de</span>
                  {{ props.limiteMensualG }}g
                </span>
              </div>
              <div class="dv__limite-bar-track">
                <div
                  class="dv__limite-bar-fill"
                  :style="{ width: pctConsumo + '%' }"
                ></div>
              </div>
              <div class="dv__limite-footer">
                <span v-if="estadoLimite === 'agotado'" class="dv__limite-msg dv__limite-msg--danger">
                  <i class="bi bi-x-circle-fill"></i> Cupo agotado este mes
                </span>
                <span v-else-if="estadoLimite === 'critico'" class="dv__limite-msg dv__limite-msg--warning">
                  <i class="bi bi-exclamation-triangle-fill"></i> Quedan solo {{ disponibleMes.toFixed(1) }}g disponibles
                </span>
                <span v-else class="dv__limite-msg dv__limite-msg--ok">
                  Disponibles: {{ disponibleMes.toFixed(1) }}g
                </span>
                <span v-if="excederiaLimite" class="dv__limite-excede">
                  ⚠ Esta dispensación excede el cupo
                </span>
              </div>
            </div>

            <!-- ── Selector de stock ── -->
            <div class="dv__section-label">Stock a dispensar <span class="dv__req">*</span></div>
            <div v-if="loadingStocks" class="dv__loading-inline"><div class="dv__ring dv__ring--sm"></div> Cargando stocks…</div>
            <div v-else-if="!stocksRegulatorios.length" class="dv__warn-box">
              <i class="bi bi-exclamation-triangle"></i> Sin stock regulatorio disponible
            </div>
            <div v-else class="dv__stock-list">
              <button
                v-for="s in stocksRegulatorios" :key="s.id"
                type="button"
                class="dv__stock-row"
                :class="{ 'dv__stock-row--active': form.stock_id === s.id }"
                @click="form.stock_id = s.id"
              >
                <span class="dv__stock-emoji">{{ FORMA_EMOJI[s.forma_producto] || '📦' }}</span>
                <span class="dv__stock-info">
                  <span class="dv__stock-nombre">{{ FORMA_LABEL[s.forma_producto] || s.forma_producto }}</span>
                  <span v-if="s.lote?.genetica?.nombre" class="dv__stock-gen">{{ s.lote.genetica.nombre }}</span>
                </span>
                <span class="dv__stock-right">
                  <span class="dv__stock-disp">{{ s.cantidad }}{{ s.unidad }}</span>
                  <span v-if="s.precio_sugerido_ars" class="dv__stock-precio">
                    {{ fmt(s.precio_sugerido_ars) }}/{{ s.unidad || 'g' }}
                  </span>
                </span>
                <span class="dv__stock-check" v-if="form.stock_id === s.id"><i class="bi bi-check-circle-fill"></i></span>
              </button>
            </div>

            <div class="dv__divider"></div>

            <!-- ── Cantidad y descuento ── -->
            <div class="dv__form-row">
              <div class="dv__field">
                <label class="dv__label">Cantidad <span class="dv__req">*</span></label>
                <div class="dv__input-suffix-wrap">
                  <input v-model.number="form.cantidad" type="number" step="0.01" min="0.01"
                         class="dv__input dv__input--with-suffix"
                         :class="{ 'dv__input--error': excederiaStock }"
                         placeholder="0" />
                  <span class="dv__input-suffix">{{ stockSeleccionado?.unidad || 'g' }}</span>
                </div>
                <span v-if="excederiaStock" class="dv__field-error">
                  Máximo {{ stockSeleccionado.cantidad }}{{ stockSeleccionado.unidad || 'g' }} disponibles
                </span>
                <span v-else-if="stockSeleccionado && form.cantidad" class="dv__field-hint">
                  Disponible: {{ stockSeleccionado.cantidad }}{{ stockSeleccionado.unidad || 'g' }}
                </span>
              </div>
              <div class="dv__field">
                <label class="dv__label">Descuento</label>
                <div class="dv__input-suffix-wrap">
                  <input v-model.number="form.descuento_pct" type="number" step="1" min="0" max="100"
                         class="dv__input dv__input--with-suffix" placeholder="0" />
                  <span class="dv__input-suffix">%</span>
                </div>
              </div>
            </div>

            <!-- Resumen de precio + aporte editable -->
            <div class="dv__aporte-wrap">
              <div v-if="precioBase != null" class="dv__precio-box">
                <div class="dv__precio-row">
                  <span>Precio base</span>
                  <span>{{ fmt(precioBase) }}</span>
                </div>
                <div v-if="form.descuento_pct > 0" class="dv__precio-row dv__precio-row--desc">
                  <span>Descuento {{ form.descuento_pct }}%</span>
                  <span>- {{ fmt(precioBase - precioFinal) }}</span>
                </div>
                <div class="dv__precio-row dv__precio-row--total">
                  <span>Total sugerido</span>
                  <span>{{ fmt(precioFinal) }}</span>
                </div>
              </div>
              <div class="dv__field">
                <label class="dv__label">
                  Aporte del socio
                  <span class="dv__opt">ARS — editable</span>
                </label>
                <div class="dv__input-suffix-wrap">
                  <span class="dv__input-prefix">$</span>
                  <input
                    v-model.number="form.aporte_socio_ars"
                    type="number" min="0" step="1"
                    class="dv__input dv__input--with-prefix"
                    placeholder="0"
                  />
                </div>
              </div>
            </div>

            <!-- ── Estado cuenta corriente ── -->
            <div v-if="tieneCc" class="dv__cc-panel" :class="`dv__cc-panel--${estadoCc || 'ok'}`">
              <div class="dv__cc-row">
                <span class="dv__cc-label"><i class="bi bi-wallet2"></i> Crédito disponible</span>
                <span class="dv__cc-saldo" :class="{ 'dv__cc-saldo--bajo': ccMargen <= 0 }">
                  {{ fmt(ccMargen) }}
                </span>
              </div>
              <div v-if="form.aporte_socio_ars > 0 && !ccInsuficiente" class="dv__cc-tras">
                Luego de esta dispensación: <strong>{{ fmt(ccMargen - Number(form.aporte_socio_ars)) }}</strong>
              </div>
              <div v-if="ccInsuficiente" class="dv__cc-warn">
                <i class="bi bi-exclamation-triangle-fill"></i>
                El aporte supera el crédito disponible ({{ fmt(ccMargen) }})
              </div>
            </div>

            <!-- ── Fecha y pago ── -->
            <div class="dv__form-row">
              <div class="dv__field">
                <label class="dv__label">Fecha</label>
                <input v-model="form.fecha_dispensacion" type="date" class="dv__input" :max="today" />
              </div>
              <div class="dv__field">
                <label class="dv__label">Medio de pago</label>
                <select v-model="form.medio_pago" class="dv__input">
                  <option value="efectivo">Efectivo</option>
                  <option value="transferencia">Transferencia</option>
                  <option value="debito">Débito</option>
                  <option value="credito">Crédito</option>
                  <option value="cuenta_corriente">Cuenta corriente</option>
                  <option value="otro">Otro</option>
                </select>
              </div>
            </div>

            <!-- Observaciones -->
            <div class="dv__field">
              <label class="dv__label">Observaciones <span class="dv__opt">opcional</span></label>
              <textarea v-model.trim="form.observaciones" class="dv__input dv__textarea" rows="2"
                        placeholder="Notas adicionales…"></textarea>
            </div>

          </div>

          <div class="dv__modal-footer">
            <button class="dv__btn-ghost" :disabled="saving" @click="showModal=false">Cancelar</button>
            <button class="dv__btn-primary" :disabled="saving || !form.stock_id" @click="handleSubmit">
              <div v-if="saving" class="dv__spinner"></div>
              <i v-else class="bi bi-check-lg"></i>
              Registrar dispensación
            </button>
          </div>
        </div>
      </div>
    </Teleport>
  </div>
</template>

<style scoped>
.dv { font-family: system-ui, -apple-system, sans-serif; color: #0f172a; }
.dv__header { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; padding: 1.1rem 1.25rem; border-bottom: 1px solid #f1f5f9; flex-wrap: wrap; }
.dv__header-title { font-size: .9rem; font-weight: 700; color: #0f172a; margin-bottom: .2rem; }
.dv__header-sub { font-size: .75rem; color: #64748b; }
.dv__loading { display: flex; align-items: center; justify-content: center; gap: .65rem; padding: 3rem; color: #94a3b8; font-size: .875rem; }
.dv__ring { width: 18px; height: 18px; border: 2px solid #e2e8f0; border-top-color: #1b5e20; border-radius: 50%; animation: dv-spin .7s linear infinite; }
.dv__ring--sm { width: 13px; height: 13px; }
.dv__loading-inline { display: flex; align-items: center; gap: .5rem; font-size: .8rem; color: #94a3b8; padding: .5rem 0; }
@keyframes dv-spin { to { transform: rotate(360deg); } }
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
.dv__item-obs { font-size: .73rem; color: #94a3b8; font-style: italic; }
.dv__item-right { text-align: right; flex-shrink: 0; min-width: 80px; }
.dv__item-cantidad { font-size: 1.05rem; font-weight: 800; color: #1b5e20; letter-spacing: -.03em; }
.dv__item-aporte { font-size: .72rem; color: #64748b; margin-top: .1rem; }
.dv__item-usuario { font-size: .7rem; color: #94a3b8; }
.dv__icon-btn { width: 28px; height: 28px; border-radius: 7px; border: 1px solid #e2e8f0; background: #f8fafc; color: #64748b; display: flex; align-items: center; justify-content: center; cursor: pointer; font-size: .75rem; transition: all .15s; flex-shrink: 0; }
.dv__icon-btn--danger:hover { background: #fef2f2; border-color: #fecaca; color: #dc2626; }

/* Buttons */
.dv__btn-primary { display: inline-flex; align-items: center; gap: .4rem; background: #1b5e20; color: #fff; border: none; padding: .6rem 1.1rem; border-radius: 9px; font-size: .82rem; font-weight: 600; cursor: pointer; transition: background .15s; white-space: nowrap; }
.dv__btn-primary:hover:not(:disabled) { background: #144a18; }
.dv__btn-primary:disabled { opacity: .5; cursor: not-allowed; }
.dv__btn-ghost { background: #fff; color: #64748b; border: 1.5px solid #e2e8f0; padding: .6rem 1.1rem; border-radius: 9px; font-size: .875rem; font-weight: 500; cursor: pointer; }
.dv__btn-ghost:hover { background: #f8fafc; }
.dv__spinner { width: 14px; height: 14px; border: 2px solid rgba(255,255,255,.3); border-top-color: #fff; border-radius: 50%; animation: dv-spin .6s linear infinite; }

/* Modal */
.dv__overlay { position: fixed; inset: 0; background: rgba(0,0,0,.45); display: flex; align-items: center; justify-content: center; z-index: 1050; padding: 1rem; backdrop-filter: blur(3px); }
.dv__modal { background: #fff; border-radius: 18px; width: 100%; max-width: 640px; max-height: 92vh; overflow-y: auto; box-shadow: 0 24px 64px rgba(0,0,0,.18); display: flex; flex-direction: column; }
.dv__modal-header { display: flex; align-items: center; justify-content: space-between; gap: 1rem; padding: 1.1rem 1.25rem .9rem; border-bottom: 1px solid #f1f5f9; position: sticky; top: 0; background: #fff; z-index: 1; }
.dv__modal-title { font-size: .95rem; font-weight: 800; color: #0f172a; margin: 0; }
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
