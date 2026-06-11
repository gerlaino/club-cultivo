<script setup>
import { ref, computed, watch } from 'vue'
import { useConfirm } from '../../composables/useConfirm.js'
import { useToast } from '../../composables/useToast.js'
import DsSpinner from '../../design-system/components/Spinner.vue'
import { createDispensacion, listStocks, listEntregadores } from '../../lib/api.js'

const props = defineProps({
  modelValue:     { type: Boolean, required: true },
  socioId:        { type: Number,  required: true },
  pacienteNombre: { type: String,  default: '' },
  saldoCc:        { type: Number,  default: null },
  limiteCc:       { type: Number,  default: null },
  descuentoPorcentaje: { type: Number,  default: 0 },
})

const emit = defineEmits(['update:modelValue', 'saved'])

const { confirm }     = useConfirm()
const toast           = useToast()

const stocks          = ref([])
const loadingStocks   = ref(false)
const saving          = ref(false)
const formError       = ref(null)
const deliveryUsers   = ref([])
const loadingDelivery = ref(false)

const today = new Date().toISOString().split('T')[0]

const FORMA_LABEL = {
  flor_seca: 'Flor seca', hash: 'Hash', aceite: 'Aceite',
  preroll: 'Preroll', crema: 'Crema', descarte: 'Descarte', otro: 'Otro',
}
const FORMA_EMOJI = {
  flor_seca: '🌿', hash: '🟤', aceite: '🫙',
  preroll: '🚬', crema: '💊', descarte: '🗑️', otro: '📦',
}

const stocksDisponibles = computed(() => stocks.value.filter(s => s.cantidad > 0))

// ── Cuenta corriente ARS ───────────────────────────────────────────────────────
const tieneCc  = computed(() => props.limiteCc !== null && props.limiteCc > 0)
const ccMargen = computed(() => (props.saldoCc ?? 0) + (props.limiteCc ?? 0))

const ccInsuficiente = computed(() => {
  if (!tieneCc.value || form.value.medio_pago !== 'cuenta_corriente') return false
  if (form.value.aporte_socio_ars == null) return false
  return Number(form.value.aporte_socio_ars) > ccMargen.value
})

const estadoCc = computed(() => {
  if (!tieneCc.value) return null
  if (ccMargen.value <= 0)   return 'agotado'
  if (ccInsuficiente.value)  return 'insuficiente'
  if (ccMargen.value < (props.limiteCc ?? 0) * 0.2) return 'critico'
  return 'ok'
})

const excederiaStock = computed(() => {
  if (!stockSeleccionado.value || !form.value.cantidad) return false
  return parseFloat(form.value.cantidad) > stockSeleccionado.value.cantidad
})

const fmt = n => n == null ? '—' :
  new Intl.NumberFormat('es-AR', { style: 'currency', currency: 'ARS', minimumFractionDigits: 0 }).format(n)

async function cargarStocks() {
  loadingStocks.value = true
  try {
    const { data } = await listStocks()
    stocks.value = data || []
  } catch { stocks.value = [] }
  finally { loadingStocks.value = false }
}

async function cargarDeliveryUsers() {
  if (deliveryUsers.value.length) return
  loadingDelivery.value = true
  try {
    const { data } = await listEntregadores()
    deliveryUsers.value = data.data || data.usuarios || data || []
  } catch { deliveryUsers.value = [] }
  finally { loadingDelivery.value = false }
}

function emptyForm() {
  return {
    stock_id: null, cantidad: null, descuento_pct: props.descuentoPorcentaje ?? 0, aporte_socio_ars: null,
    fecha_dispensacion: today, observaciones: '', medio_pago: 'efectivo',
    con_envio: false, delivery_id: null, direccion_envio: '',
    contacto_nombre: '', contacto_telefono: '', notas_envio: '',
  }
}

const form               = ref(emptyForm())
const precioUnitarioManual = ref(null)

watch(() => form.value.con_envio, (val) => { if (val) cargarDeliveryUsers() })
watch(() => form.value.stock_id,  ()    => { precioUnitarioManual.value = null })

const stockSeleccionado    = computed(() => stocks.value.find(s => s.id === form.value.stock_id) || null)
const necesitaPrecioManual = computed(() => stockSeleccionado.value != null && !stockSeleccionado.value.precio_sugerido_ars)

const precioBase = computed(() => {
  const s   = stockSeleccionado.value
  const cnt = parseFloat(form.value.cantidad) || 0
  if (!s || cnt <= 0) return null
  const ppu = s.precio_sugerido_ars
    ? parseFloat(s.precio_sugerido_ars)
    : (parseFloat(precioUnitarioManual.value) || 0)
  if (ppu <= 0) return null
  return ppu * cnt
})

const precioFinal = computed(() => {
  if (precioBase.value == null) return null
  const desc = Math.max(0, Math.min(100, Number(form.value.descuento_pct) || 0))
  return precioBase.value * (1 - desc / 100)
})

watch(precioFinal, (val) => { if (val != null) form.value.aporte_socio_ars = Math.round(val) })

watch(() => props.modelValue, (open) => {
  if (open) {
    form.value = emptyForm()
    precioUnitarioManual.value = null
    formError.value = null
    deliveryUsers.value = []
    cargarStocks()
  }
}, { immediate: true })

function cerrar() { emit('update:modelValue', false) }

async function handleSubmit() {
  if (saving.value) return
  saving.value = true
  formError.value = null

  if (!form.value.stock_id) { formError.value = 'Seleccioná un stock'; saving.value = false; return }
  if (!form.value.cantidad || form.value.cantidad <= 0) { formError.value = 'La cantidad debe ser > 0'; saving.value = false; return }
  if (excederiaStock.value) {
    formError.value = `Stock insuficiente: solo hay ${stockSeleccionado.value.cantidad}${stockSeleccionado.value.unidad || 'g'} disponibles`
    saving.value = false; return
  }
  if (form.value.medio_pago === 'cuenta_corriente' && !(Number(form.value.aporte_socio_ars) > 0)) {
    formError.value = 'El aporte del socio debe ser mayor a $0 para cobrar por cuenta corriente'
    saving.value = false; return
  }
  if (ccInsuficiente.value && form.value.medio_pago === 'cuenta_corriente') {
    formError.value = `Crédito insuficiente. Disponible: ${fmt(ccMargen.value)} — requerido: ${fmt(form.value.aporte_socio_ars)}`
    saving.value = false; return
  }


  if (form.value.con_envio) {
    if (!form.value.delivery_id) { formError.value = 'Seleccioná un delivery para asignar el envío'; saving.value = false; return }
    if (!form.value.direccion_envio?.trim()) { formError.value = 'La dirección de envío es requerida'; saving.value = false; return }
    if (!form.value.contacto_nombre?.trim()) { formError.value = 'El nombre de contacto es requerido'; saving.value = false; return }
  }

  try {
    const payload = {
      stock_id: form.value.stock_id, cantidad: form.value.cantidad,
      fecha_dispensacion: form.value.fecha_dispensacion,
      observaciones: form.value.observaciones || undefined,
      medio_pago: form.value.medio_pago, con_envio: form.value.con_envio,
    }
    if (form.value.aporte_socio_ars != null && form.value.aporte_socio_ars !== '')
      payload.aporte_socio_ars = Number(form.value.aporte_socio_ars).toFixed(2)
    const s = stockSeleccionado.value
    if (s) {
      const ppu = s.precio_sugerido_ars
        ? parseFloat(s.precio_sugerido_ars)
        : (parseFloat(precioUnitarioManual.value) || 0)
      if (ppu > 0) {
        const desc = Math.max(0, Math.min(100, Number(form.value.descuento_pct) || 0))
        payload.precio_unitario_ars = (ppu * (1 - desc / 100)).toFixed(2)
      }
    }
    if (form.value.con_envio) {
      payload.delivery_id       = form.value.delivery_id
      payload.direccion_envio   = form.value.direccion_envio
      payload.contacto_nombre   = form.value.contacto_nombre
      payload.contacto_telefono = form.value.contacto_telefono || undefined
      payload.notas_envio       = form.value.notas_envio || undefined
    }
    await createDispensacion(props.socioId, payload)
    cerrar()
    toast.success('Dispensación registrada')
    emit('saved')
  } catch (e) {
    formError.value = e.response?.data?.errors?.[0] || e.response?.data?.error || 'Error al guardar'
  } finally { saving.value = false }
}
</script>

<template>
  <Teleport to="body">
    <div v-if="modelValue" class="mnd__overlay">
      <div class="mnd__modal">

        <div class="mnd__modal-header">
          <h3 class="mnd__modal-title">
            Nueva dispensación<template v-if="props.pacienteNombre"> para <span class="mnd__modal-title-paciente">{{ props.pacienteNombre }}</span></template>
          </h3>
          <button class="mnd__modal-close" @click="cerrar"><i class="bi bi-x-lg"></i></button>
        </div>

        <div class="mnd__modal-body">
          <div v-if="formError" class="mnd__error"><i class="bi bi-exclamation-triangle-fill"></i> {{ formError }}</div>

          <!-- Stock -->
          <div class="mnd__section-label">Stock a dispensar <span class="mnd__req">*</span></div>
          <div v-if="loadingStocks" class="mnd__loading-inline"><DsSpinner :size="13" /> Cargando stocks…</div>
          <div v-else-if="!stocksDisponibles.length" class="mnd__warn-box">
            <i class="bi bi-exclamation-triangle"></i> Sin stock disponible
          </div>
          <div v-else class="mnd__stock-list">
            <button
              v-for="s in stocksDisponibles" :key="s.id"
              type="button"
              class="mnd__stock-row"
              :class="{ 'mnd__stock-row--active': form.stock_id === s.id }"
              @click="form.stock_id = s.id"
            >
              <span class="mnd__stock-emoji">{{ FORMA_EMOJI[s.forma_producto] || '📦' }}</span>
              <span class="mnd__stock-info">
                <span class="mnd__stock-nombre">{{ FORMA_LABEL[s.forma_producto] || s.forma_producto }}</span>
                <span v-if="s.lote?.genetica?.nombre" class="mnd__stock-gen">{{ s.lote.genetica.nombre }}</span>
              </span>
              <span class="mnd__stock-right">
                <span class="mnd__stock-disp">{{ s.cantidad }}{{ s.unidad }}</span>
                <span v-if="s.precio_sugerido_ars" class="mnd__stock-precio">
                  {{ fmt(s.precio_sugerido_ars) }}/{{ s.unidad || 'g' }}
                </span>
              </span>
              <span class="mnd__stock-check" v-if="form.stock_id === s.id"><i class="bi bi-check-circle-fill"></i></span>
            </button>
          </div>

          <!-- Precio manual -->
          <div v-if="necesitaPrecioManual" class="mnd__field">
            <label class="mnd__label">
              Precio por {{ stockSeleccionado?.unidad || 'g' }}
              <span class="mnd__opt">solo para el cálculo — no se guarda</span>
            </label>
            <div class="mnd__input-suffix-wrap">
              <span class="mnd__input-prefix">$</span>
              <input v-model.number="precioUnitarioManual" type="number" min="0" step="1"
                     class="mnd__input mnd__input--with-prefix" placeholder="0" />
            </div>
          </div>

          <div class="mnd__divider"></div>

          <!-- Cantidad + descuento -->
          <div class="mnd__form-row">
            <div class="mnd__field">
              <label class="mnd__label">Cantidad <span class="mnd__req">*</span></label>
              <div class="mnd__input-suffix-wrap">
                <input v-model.number="form.cantidad" type="number" step="0.01" min="0.01"
                       class="mnd__input mnd__input--with-suffix"
                       :class="{ 'mnd__input--error': excederiaStock }"
                       placeholder="0" />
                <span class="mnd__input-suffix">{{ stockSeleccionado?.unidad || 'g' }}</span>
              </div>
              <span v-if="excederiaStock" class="mnd__field-error">
                Máximo {{ stockSeleccionado.cantidad }}{{ stockSeleccionado.unidad || 'g' }} disponibles
              </span>
              <span v-else-if="stockSeleccionado && form.cantidad" class="mnd__field-hint">
                Disponible: {{ stockSeleccionado.cantidad }}{{ stockSeleccionado.unidad || 'g' }}
              </span>
            </div>
            <div class="mnd__field">
              <label class="mnd__label">Descuento</label>
              <div class="mnd__input-suffix-wrap">
                <input v-model.number="form.descuento_pct" type="number" step="1" min="0" max="100"
                       class="mnd__input mnd__input--with-suffix" placeholder="0" />
                <span class="mnd__input-suffix">%</span>
              </div>
            </div>
          </div>

          <!-- Precio + aporte -->
          <div class="mnd__aporte-wrap">
            <div v-if="precioBase != null" class="mnd__precio-box">
              <div class="mnd__precio-row"><span>Precio base</span><span>{{ fmt(precioBase) }}</span></div>
              <div v-if="form.descuento_pct > 0" class="mnd__precio-row mnd__precio-row--desc">
                <span>Descuento {{ form.descuento_pct }}%</span>
                <span>- {{ fmt(precioBase - precioFinal) }}</span>
              </div>
              <div class="mnd__precio-row mnd__precio-row--total"><span>Total sugerido</span><span>{{ fmt(precioFinal) }}</span></div>
            </div>
            <div class="mnd__field">
              <label class="mnd__label">Aporte del socio <span class="mnd__opt">ARS — editable</span></label>
              <div class="mnd__input-suffix-wrap">
                <span class="mnd__input-prefix">$</span>
                <input v-model.number="form.aporte_socio_ars" type="number" min="0" step="1"
                       class="mnd__input mnd__input--with-prefix" placeholder="0" />
              </div>
            </div>
          </div>

          <!-- CC ARS — siempre visible como info; advertencias solo cuando medio_pago=cuenta_corriente -->
          <div v-if="tieneCc" class="mnd__cc-panel" :class="`mnd__cc-panel--${estadoCc || 'ok'}`">
            <div class="mnd__cc-row">
              <span class="mnd__cc-label"><i class="bi bi-wallet2"></i> Crédito disponible</span>
              <span class="mnd__cc-saldo" :class="{ 'mnd__cc-saldo--bajo': ccMargen <= 0 }">{{ fmt(ccMargen) }}</span>
            </div>
            <div v-if="form.medio_pago === 'cuenta_corriente' && form.aporte_socio_ars > 0 && !ccInsuficiente" class="mnd__cc-tras">
              Luego de esta dispensación: <strong>{{ fmt(ccMargen - Number(form.aporte_socio_ars)) }}</strong>
            </div>
            <div v-if="ccInsuficiente" class="mnd__cc-warn">
              <i class="bi bi-exclamation-triangle-fill"></i>
              Crédito insuficiente para cargar en cuenta (disponible: {{ fmt(ccMargen) }})
            </div>
          </div>

          <!-- Fecha + pago -->
          <div class="mnd__form-row">
            <div class="mnd__field">
              <label class="mnd__label">Fecha</label>
              <input v-model="form.fecha_dispensacion" type="date" class="mnd__input" :max="today" />
            </div>
            <div class="mnd__field">
              <label class="mnd__label">Medio de pago</label>
              <select v-model="form.medio_pago" class="mnd__input">
                <option value="efectivo">Efectivo</option>
                <option value="transferencia">Transferencia</option>
                <option value="debito">Débito</option>
                <option value="credito">Crédito</option>
                <option value="cuenta_corriente" :disabled="!tieneCc">Cuenta corriente{{ !tieneCc ? ' (sin límite configurado)' : '' }}</option>
                <option value="otro">Otro</option>
              </select>
            </div>
          </div>

          <!-- Observaciones -->
          <div class="mnd__field">
            <label class="mnd__label">Observaciones <span class="mnd__opt">opcional</span></label>
            <textarea v-model.trim="form.observaciones" class="mnd__input mnd__textarea" rows="2"
                      placeholder="Notas adicionales…"></textarea>
          </div>

          <div class="mnd__divider"></div>

          <!-- Delivery -->
          <div class="mnd__delivery-toggle" @click="form.con_envio = !form.con_envio">
            <div class="mnd__delivery-toggle-left">
              <i class="bi bi-bicycle" style="font-size:1rem;color:#1b5e20"></i>
              <div>
                <div class="mnd__delivery-toggle-title">Con envío a domicilio</div>
                <div class="mnd__delivery-toggle-sub">Asignar un delivery y datos de entrega</div>
              </div>
            </div>
            <div class="mnd__toggle-switch" :class="{ 'mnd__toggle-switch--on': form.con_envio }">
              <div class="mnd__toggle-knob"></div>
            </div>
          </div>

          <div v-if="form.con_envio" class="mnd__delivery-section">
            <div class="mnd__field">
              <label class="mnd__label">Delivery asignado <span class="mnd__req">*</span></label>
              <div v-if="loadingDelivery" class="mnd__loading-inline"><DsSpinner :size="13" /> Cargando…</div>
              <div v-else-if="!deliveryUsers.length" class="mnd__warn-box">
                <i class="bi bi-exclamation-triangle"></i> No hay usuarios delivery disponibles
              </div>
              <select v-else v-model.number="form.delivery_id" class="mnd__input">
                <option :value="null" disabled>Seleccioná un delivery…</option>
                <option v-for="u in deliveryUsers" :key="u.id" :value="u.id">
                  {{ u.first_name || u.nombre || u.email }}
                </option>
              </select>
            </div>
            <div class="mnd__field">
              <label class="mnd__label">Dirección de entrega <span class="mnd__req">*</span></label>
              <input v-model.trim="form.direccion_envio" type="text" class="mnd__input"
                     placeholder="Calle, número, piso, depto…" />
            </div>
            <div class="mnd__form-row">
              <div class="mnd__field">
                <label class="mnd__label">Contacto <span class="mnd__req">*</span></label>
                <input v-model.trim="form.contacto_nombre" type="text" class="mnd__input"
                       placeholder="Nombre de quien recibe" />
              </div>
              <div class="mnd__field">
                <label class="mnd__label">Teléfono <span class="mnd__opt">opcional</span></label>
                <input v-model.trim="form.contacto_telefono" type="tel" class="mnd__input" placeholder="+54 11 …" />
              </div>
            </div>
            <div class="mnd__field">
              <label class="mnd__label">Notas de envío <span class="mnd__opt">opcional</span></label>
              <textarea v-model.trim="form.notas_envio" class="mnd__input mnd__textarea" rows="2"
                        placeholder="Instrucciones para el delivery…"></textarea>
            </div>
          </div>

        </div>

        <div class="mnd__modal-footer">
          <button class="mnd__btn-ghost" :disabled="saving" @click="cerrar">Cancelar</button>
          <button class="mnd__btn-primary" :disabled="saving || !form.stock_id" @click="handleSubmit">
            <DsSpinner v-if="saving" :size="14" />
            <i v-else class="bi bi-check-lg"></i>
            Registrar dispensación
          </button>
        </div>

      </div>
    </div>
  </Teleport>
</template>

<style scoped>
.mnd__overlay { position: fixed; inset: 0; background: rgba(0,0,0,.45); display: flex; align-items: center; justify-content: center; z-index: 1050; padding: 1rem; backdrop-filter: blur(3px); }
.mnd__modal { background: #fff; border-radius: 18px; width: 100%; max-width: 640px; max-height: 92vh; overflow-y: auto; box-shadow: 0 24px 64px rgba(0,0,0,.18); display: flex; flex-direction: column; }

.mnd__modal-header { display: flex; align-items: center; justify-content: space-between; gap: 1rem; padding: 1.1rem 1.25rem .9rem; border-bottom: 1px solid #f1f5f9; position: sticky; top: 0; background: #fff; z-index: 1; }
.mnd__modal-title { font-size: .95rem; font-weight: 800; color: #0f172a; margin: 0; }
.mnd__modal-title-paciente { color: #15803d; font-weight: 800; }
.mnd__modal-close { background: #f1f5f9; border: none; width: 28px; height: 28px; border-radius: 7px; cursor: pointer; display: flex; align-items: center; justify-content: center; color: #64748b; }
.mnd__modal-close:hover { background: #e2e8f0; }

.mnd__modal-body { padding: 1.1rem 1.25rem; flex: 1; display: flex; flex-direction: column; gap: .9rem; }
.mnd__modal-footer { display: flex; justify-content: flex-end; gap: .75rem; padding: .875rem 1.25rem; border-top: 1px solid #f1f5f9; position: sticky; bottom: 0; background: #fff; }

.mnd__error { background: #fef2f2; color: #dc2626; border: 1px solid #fecaca; border-radius: 9px; padding: .6rem .875rem; font-size: .82rem; display: flex; align-items: center; gap: .4rem; }


/* Stock */
.mnd__section-label { font-size: .72rem; font-weight: 700; color: #374151; text-transform: uppercase; letter-spacing: .05em; }
.mnd__stock-list { display: flex; flex-direction: column; gap: .35rem; max-height: 220px; overflow-y: auto; }
.mnd__stock-row { display: flex; align-items: center; gap: .75rem; padding: .6rem .875rem; border-radius: 10px; border: 1.5px solid #e2e8f0; background: #fafbfc; cursor: pointer; text-align: left; transition: all .12s; width: 100%; }
.mnd__stock-row:hover { border-color: #86efac; background: #f0fdf4; }
.mnd__stock-row--active { border-color: #1b5e20; background: #f0fdf4; }
.mnd__stock-emoji { font-size: 1.1rem; flex-shrink: 0; }
.mnd__stock-info { flex: 1; min-width: 0; display: flex; flex-direction: column; gap: .1rem; }
.mnd__stock-nombre { font-size: .82rem; font-weight: 700; color: #0f172a; }
.mnd__stock-gen { font-size: .72rem; color: #64748b; font-style: italic; }
.mnd__stock-right { display: flex; flex-direction: column; align-items: flex-end; gap: .1rem; flex-shrink: 0; }
.mnd__stock-disp  { font-size: .8rem; font-weight: 700; color: #1b5e20; font-family: monospace; }
.mnd__stock-precio { font-size: .7rem; color: #64748b; font-family: monospace; white-space: nowrap; }
.mnd__stock-check { color: #1b5e20; font-size: .9rem; flex-shrink: 0; }
.mnd__warn-box { background: #fffbeb; border: 1px solid #fde68a; border-radius: 8px; padding: .5rem .75rem; font-size: .8rem; color: #92400e; display: flex; align-items: center; gap: .4rem; }

/* Form */
.mnd__divider { height: 1px; background: #f1f5f9; }
.mnd__form-row { display: grid; grid-template-columns: 1fr 1fr; gap: .75rem; }
@media (max-width: 400px) { .mnd__form-row { grid-template-columns: 1fr; } }
.mnd__field { display: flex; flex-direction: column; gap: .3rem; }
.mnd__label { font-size: .72rem; font-weight: 700; color: #374151; text-transform: uppercase; letter-spacing: .05em; }
.mnd__req { color: #ef4444; }
.mnd__opt { font-size: .67rem; font-weight: 400; color: #94a3b8; text-transform: none; letter-spacing: 0; }
.mnd__input { background: #f8fafc; border: 1.5px solid #e2e8f0; border-radius: 9px; padding: .6rem .8rem; font-size: .875rem; color: #0f172a; width: 100%; box-sizing: border-box; outline: none; transition: border-color .15s; }
.mnd__input:focus { border-color: #1b5e20; background: #fff; }
.mnd__input--error { border-color: #ef4444 !important; background: #fef2f2; }
.mnd__field-error { font-size: .72rem; color: #dc2626; font-weight: 600; }
.mnd__field-hint  { font-size: .72rem; color: #94a3b8; }
.mnd__textarea { resize: vertical; min-height: 58px; }
.mnd__input-suffix-wrap { display: flex; }
.mnd__input--with-suffix { border-radius: 9px 0 0 9px; flex: 1; }
.mnd__input-suffix { background: #f1f5f9; border: 1.5px solid #e2e8f0; border-left: none; border-radius: 0 9px 9px 0; padding: .6rem .7rem; font-size: .8rem; color: #64748b; white-space: nowrap; display: flex; align-items: center; }
.mnd__input--with-prefix { border-radius: 0 9px 9px 0; flex: 1; }
.mnd__input-prefix { background: #f1f5f9; border: 1.5px solid #e2e8f0; border-right: none; border-radius: 9px 0 0 9px; padding: .6rem .7rem; font-size: .8rem; color: #64748b; display: flex; align-items: center; }
.mnd__loading-inline { display: flex; align-items: center; gap: .5rem; font-size: .8rem; color: #94a3b8; padding: .5rem 0; }

/* Precio */
.mnd__aporte-wrap { display: flex; flex-direction: column; gap: .75rem; }
.mnd__precio-box { background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 9px; padding: .6rem .875rem; display: flex; flex-direction: column; gap: .25rem; }
.mnd__precio-row { display: flex; justify-content: space-between; align-items: center; font-size: .8rem; color: #374151; }
.mnd__precio-row--desc { color: #64748b; }
.mnd__precio-row--total { font-weight: 700; font-size: .875rem; color: #0f172a; border-top: 1px solid #e2e8f0; padding-top: .25rem; margin-top: .1rem; }

/* CC panels */
.mnd__cc-panel { border-radius: 10px; padding: .7rem .9rem; border: 1.5px solid #e2e8f0; display: flex; flex-direction: column; gap: .3rem; }
.mnd__cc-panel--ok           { background: #f0fdf4; border-color: #bbf7d0; }
.mnd__cc-panel--insuficiente { background: #fef2f2; border-color: #fecaca; }
.mnd__cc-panel--agotado      { background: #fef2f2; border-color: #fecaca; }
.mnd__cc-panel--critico      { background: #fffbeb; border-color: #fde68a; }
.mnd__cc-row { display: flex; align-items: center; justify-content: space-between; }
.mnd__cc-label { font-size: .75rem; font-weight: 700; color: #374151; display: flex; align-items: center; gap: .35rem; }
.mnd__cc-saldo { font-size: .9rem; font-weight: 800; color: #15803d; }
.mnd__cc-saldo--bajo { color: #dc2626; }
.mnd__cc-tras { font-size: .72rem; color: #64748b; }
.mnd__cc-warn { font-size: .75rem; font-weight: 600; color: #dc2626; display: flex; align-items: center; gap: .3rem; }

/* Delivery */
.mnd__delivery-toggle { display: flex; align-items: center; justify-content: space-between; padding: .75rem; border: 1.5px solid #e2e8f0; border-radius: 10px; cursor: pointer; background: #fafbfc; transition: background .15s; gap: .75rem; }
.mnd__delivery-toggle:hover { background: #f0fdf4; border-color: #86efac; }
.mnd__delivery-toggle-left { display: flex; align-items: center; gap: .625rem; }
.mnd__delivery-toggle-title { font-size: .82rem; font-weight: 700; color: #0f172a; }
.mnd__delivery-toggle-sub { font-size: .72rem; color: #94a3b8; margin-top: 1px; }
.mnd__toggle-switch { width: 36px; height: 20px; background: #e2e8f0; border-radius: 10px; position: relative; flex-shrink: 0; transition: background .2s; }
.mnd__toggle-switch--on { background: #1b5e20; }
.mnd__toggle-knob { position: absolute; top: 2px; left: 2px; width: 16px; height: 16px; background: #fff; border-radius: 50%; transition: transform .2s; box-shadow: 0 1px 3px rgba(0,0,0,.2); }
.mnd__toggle-switch--on .mnd__toggle-knob { transform: translateX(16px); }
.mnd__delivery-section { display: flex; flex-direction: column; gap: .75rem; padding: .75rem; background: #f8fafc; border-radius: 10px; border: 1px solid #e2e8f0; }

/* Buttons */
.mnd__btn-primary { display: inline-flex; align-items: center; gap: .4rem; background: #1b5e20; color: #fff; border: none; padding: .6rem 1.1rem; border-radius: 9px; font-size: .82rem; font-weight: 600; cursor: pointer; transition: background .15s; white-space: nowrap; }
.mnd__btn-primary:hover:not(:disabled) { background: #144a18; }
.mnd__btn-primary:disabled { opacity: .5; cursor: not-allowed; }
.mnd__btn-ghost { background: #fff; color: #64748b; border: 1.5px solid #e2e8f0; padding: .6rem 1.1rem; border-radius: 9px; font-size: .875rem; font-weight: 500; cursor: pointer; }
.mnd__btn-ghost:hover { background: #f8fafc; }
</style>
