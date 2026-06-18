<template>
  <Teleport to="body">
    <div v-if="modelValue && reserva" class="mer__overlay">
      <div class="mer__modal">
        <div class="mer__header">
          <h3 class="mer__title">Entregar reserva</h3>
          <button class="mer__close" @click="cerrar"><i class="bi bi-x-lg"></i></button>
        </div>

        <div class="mer__body">
          <div v-if="error" class="mer__error"><i class="bi bi-exclamation-triangle-fill"></i> {{ error }}</div>

          <!-- Resumen -->
          <div class="mer__resumen">
            <div><span class="mer__lbl">Socio</span> {{ reserva.paciente?.nombre }}</div>
            <div><span class="mer__lbl">Producto</span> {{ reserva.stock?.forma_producto }}</div>
            <div v-if="reserva.sena_ars > 0"><span class="mer__lbl">Seña pagada</span> {{ fmt(reserva.sena_ars) }}</div>
          </div>

          <!-- Cantidad (ajustable al entregar) -->
          <div class="mer__field">
            <label class="mer__label">Cantidad a entregar</label>
            <div class="mer__qty">
              <input v-model.number="cantidad" type="number" min="0.01" step="0.01" class="mer__input" />
              <span class="mer__unit">{{ reserva.stock?.unidad || 'g' }}</span>
            </div>
            <span v-if="cantidad !== reserva.cantidad" class="mer__hint">Reservado: {{ reserva.cantidad }}{{ reserva.stock?.unidad || 'g' }}</span>
          </div>

          <!-- Resto a cobrar (editable) -->
          <div class="mer__field">
            <label class="mer__label">Resto a cobrar ahora</label>
            <div class="mer__qty">
              <span class="mer__unit">$</span>
              <input v-model.number="montoCobrar" type="number" min="0" step="1" class="mer__input" />
            </div>
            <span class="mer__hint">Sugerido {{ fmt(restoSugerido) }} (se recalcula con la cantidad). Podés ajustarlo.</span>
          </div>

          <!-- Medio de pago -->
          <div class="mer__field">
            <label class="mer__label">Medio de pago</label>
            <select v-model="medioPago" class="mer__input">
              <option value="efectivo">Efectivo</option>
              <option value="transferencia">Transferencia</option>
              <option value="debito">Débito</option>
              <option value="credito">Crédito</option>
              <option value="cuenta_corriente" :disabled="!tieneCc">Cuenta corriente{{ !tieneCc ? ' (sin crédito)' : '' }}</option>
            </select>
          </div>

          <!-- Panel crédito -->
          <div v-if="esCuentaCorriente && tieneCc" class="mer__cc">
            <div class="mer__cc-row"><span>Crédito disponible</span><strong>{{ fmt(ccMargen) }}</strong></div>
            <div class="mer__cc-row"><span>Se carga al crédito</span><strong>{{ fmt(montoACredito) }}</strong></div>
            <div v-if="restoACobrar > 0" class="mer__cc-warn">
              <i class="bi bi-cash-coin"></i> El crédito no alcanza — a cobrar ahora: <strong>{{ fmt(restoACobrar) }}</strong>
            </div>
          </div>

          <!-- Envío -->
          <div class="mer__toggle" @click="conEnvio = !conEnvio">
            <div>
              <div class="mer__toggle-title"><i class="bi bi-bicycle"></i> Con envío a domicilio</div>
              <div class="mer__toggle-sub">Asignar delivery y dirección de entrega</div>
            </div>
            <div class="mer__switch" :class="{ 'mer__switch--on': conEnvio }"><div class="mer__knob"></div></div>
          </div>

          <div v-if="conEnvio" class="mer__envio">
            <div class="mer__field">
              <label class="mer__label">Delivery <span class="mer__req">*</span></label>
              <div v-if="loadingDelivery" class="mer__hint">Cargando…</div>
              <div v-else-if="!deliveryUsers.length" class="mer__warn">No hay usuarios delivery.</div>
              <select v-else v-model.number="deliveryId" class="mer__input">
                <option :value="null" disabled>Seleccioná un delivery…</option>
                <option v-for="u in deliveryUsers" :key="u.id" :value="u.id">{{ u.first_name || u.nombre || u.email }}</option>
              </select>
            </div>

            <div class="mer__field">
              <label class="mer__label">Dirección</label>
              <div class="mer__seg">
                <button type="button" class="mer__seg-btn" :class="{ 'mer__seg-btn--on': usarDomicilio }"
                        :disabled="!reserva.paciente?.tiene_domicilio" @click="usarDomicilio = true">
                  <i class="bi bi-house"></i> Domicilio del socio
                </button>
                <button type="button" class="mer__seg-btn" :class="{ 'mer__seg-btn--on': !usarDomicilio }" @click="usarDomicilio = false">
                  <i class="bi bi-geo-alt"></i> Otra
                </button>
              </div>
              <p v-if="usarDomicilio && !reserva.paciente?.tiene_domicilio" class="mer__warn">
                El socio no tiene domicilio cargado. Elegí "Otra".
              </p>
            </div>

            <template v-if="!usarDomicilio">
              <div class="mer__row">
                <div class="mer__field" style="flex:2"><label class="mer__label">Calle <span class="mer__req">*</span></label><input v-model.trim="envio.calle" class="mer__input" /></div>
                <div class="mer__field"><label class="mer__label">Altura <span class="mer__req">*</span></label><input v-model.trim="envio.altura" class="mer__input" /></div>
              </div>
              <div class="mer__row">
                <div class="mer__field"><label class="mer__label">Piso</label><input v-model.trim="envio.piso" class="mer__input" /></div>
                <div class="mer__field"><label class="mer__label">Depto</label><input v-model.trim="envio.depto" class="mer__input" /></div>
              </div>
              <div class="mer__row">
                <div class="mer__field"><label class="mer__label">Barrio</label><input v-model.trim="envio.barrio" class="mer__input" /></div>
                <div class="mer__field"><label class="mer__label">Ciudad <span class="mer__req">*</span></label><input v-model.trim="envio.ciudad" class="mer__input" /></div>
              </div>
            </template>

            <div class="mer__field">
              <label class="mer__label">Contacto</label>
              <input v-model.trim="contactoNombre" class="mer__input" :placeholder="reserva.paciente?.nombre" />
            </div>
          </div>
        </div>

        <div class="mer__footer">
          <button class="mer__btn-ghost" :disabled="saving" @click="cerrar">Cancelar</button>
          <button class="mer__btn-primary" :disabled="saving" @click="confirmar">
            <DsSpinner v-if="saving" :size="14" />
            <i v-else class="bi bi-check-lg"></i> Entregar
          </button>
        </div>
      </div>
    </div>
  </Teleport>
</template>

<script setup>
import { ref, computed, watch } from 'vue'
import DsSpinner from '../../design-system/components/Spinner.vue'
import { entregarReserva, listEntregadores } from '../../lib/api.js'
import { useToast } from '../../composables/useToast.js'

const props = defineProps({
  modelValue: { type: Boolean, default: false },
  reserva:    { type: Object,  default: null },
})
const emit = defineEmits(['update:modelValue', 'entregada'])
const toast = useToast()

const medioPago      = ref('efectivo')
const cantidad       = ref(null)
const montoCobrar    = ref(0)
const conEnvio       = ref(false)
const deliveryId     = ref(null)
const usarDomicilio  = ref(true)
const envio          = ref({ calle: '', altura: '', piso: '', depto: '', barrio: '', ciudad: '' })
const contactoNombre = ref('')
const saving         = ref(false)
const error          = ref(null)
const deliveryUsers  = ref([])
const loadingDelivery = ref(false)

const fmt = n => n == null ? '—' : new Intl.NumberFormat('es-AR', { style: 'currency', currency: 'ARS', minimumFractionDigits: 0 }).format(n)

// Precio unitario estimado (del estimado de la reserva) para recalcular al cambiar la cantidad.
const precioUnit = computed(() => {
  const est = Number(props.reserva?.aporte_estimado_ars) || 0
  const cant = Number(props.reserva?.cantidad) || 0
  return cant > 0 ? est / cant : 0
})
const sena = computed(() => Number(props.reserva?.sena_ars) || 0)
// Resto sugerido = total por la cantidad actual − seña ya pagada.
const restoSugerido = computed(() => Math.max(0, precioUnit.value * (Number(cantidad.value) || 0) - sena.value))
// Lo que efectivamente se cobra (editable, default el sugerido).
const resto = computed(() => Number(montoCobrar.value) || 0)
// Si cambia la cantidad, re-sugerir el monto (sin pisar un override manual reciente del sugerido).
watch(restoSugerido, (v) => { montoCobrar.value = Math.round(v) })

const tieneCc  = computed(() => (props.reserva?.paciente?.limite_cc ?? 0) > 0)
const ccMargen = computed(() => (props.reserva?.paciente?.saldo_cc ?? 0) + (props.reserva?.paciente?.limite_cc ?? 0))
const esCuentaCorriente = computed(() => medioPago.value === 'cuenta_corriente')
const margenPos = computed(() => Math.max(0, ccMargen.value))
const montoACredito = computed(() => Math.min(resto.value, margenPos.value))
const restoACobrar  = computed(() => Math.max(0, resto.value - margenPos.value))

watch(() => props.modelValue, (open) => {
  if (!open) return
  medioPago.value = props.reserva?.medio_pago || 'efectivo'
  cantidad.value = Number(props.reserva?.cantidad) || null
  montoCobrar.value = Math.round(Number(props.reserva?.aporte_restante_ars) || 0)
  conEnvio.value = false
  deliveryId.value = null
  usarDomicilio.value = !!props.reserva?.paciente?.tiene_domicilio
  envio.value = { calle: '', altura: '', piso: '', depto: '', barrio: '', ciudad: '' }
  contactoNombre.value = ''
  error.value = null
})
watch(conEnvio, async (v) => {
  if (v && !deliveryUsers.value.length) {
    loadingDelivery.value = true
    try { const { data } = await listEntregadores(); deliveryUsers.value = data.data || data.usuarios || data || [] }
    catch { deliveryUsers.value = [] } finally { loadingDelivery.value = false }
  }
})

function cerrar() { emit('update:modelValue', false) }

async function confirmar() {
  error.value = null
  if (conEnvio.value) {
    if (!deliveryId.value) { error.value = 'Seleccioná un delivery'; return }
    if (!usarDomicilio.value && (!envio.value.calle || !envio.value.altura || !envio.value.ciudad)) {
      error.value = 'Completá calle, altura y ciudad'; return
    }
  }
  if (!(Number(cantidad.value) > 0)) { error.value = 'La cantidad debe ser mayor a 0'; return }
  saving.value = true
  try {
    const payload = {
      medio_pago: medioPago.value,
      con_envio: conEnvio.value,
      cantidad: cantidad.value,
      aporte_socio_ars: montoCobrar.value,
    }
    if (conEnvio.value) {
      payload.delivery_id = deliveryId.value
      payload.usar_domicilio_paciente = usarDomicilio.value
      if (!usarDomicilio.value) {
        payload.envio_calle = envio.value.calle; payload.envio_altura = envio.value.altura
        payload.envio_piso = envio.value.piso; payload.envio_depto = envio.value.depto
        payload.envio_barrio = envio.value.barrio; payload.envio_ciudad = envio.value.ciudad
      }
      if (contactoNombre.value) payload.contacto_nombre = contactoNombre.value
    }
    await entregarReserva(props.reserva.id, payload)
    toast.success('Reserva entregada')
    emit('entregada')
    cerrar()
  } catch (e) {
    error.value = e.response?.data?.errors?.[0] || e.response?.data?.error || 'No se pudo entregar'
  } finally { saving.value = false }
}
</script>

<style scoped>
.mer__overlay { position: fixed; inset: 0; background: rgba(0,0,0,.45); display: flex; align-items: center; justify-content: center; z-index: 1060; padding: 1rem; backdrop-filter: blur(3px); }
.mer__modal { background: #fff; border-radius: 16px; width: 100%; max-width: 480px; max-height: 92vh; overflow-y: auto; display: flex; flex-direction: column; box-shadow: 0 24px 64px rgba(0,0,0,.18); }
.mer__header { display: flex; align-items: center; justify-content: space-between; padding: 1rem 1.25rem; border-bottom: 1px solid #f1f5f9; }
.mer__title { font-size: 1rem; font-weight: 800; color: #0f172a; margin: 0; }
.mer__close { background: #f1f5f9; border: none; width: 28px; height: 28px; border-radius: 7px; cursor: pointer; color: #64748b; }
.mer__body { padding: 1.1rem 1.25rem; display: flex; flex-direction: column; gap: .85rem; }
.mer__error { background: #fef2f2; color: #dc2626; border: 1px solid #fecaca; border-radius: 9px; padding: .55rem .8rem; font-size: .82rem; }
.mer__resumen { background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 9px; padding: .6rem .8rem; font-size: .82rem; color: #374151; display: flex; flex-direction: column; gap: .2rem; }
.mer__lbl { color: #94a3b8; font-size: .7rem; text-transform: uppercase; letter-spacing: .04em; margin-right: .4rem; }
.mer__total { display: flex; justify-content: space-between; align-items: center; background: #f0fdf4; border: 1px solid #bbf7d0; border-radius: 9px; padding: .65rem .9rem; font-size: .85rem; color: #15803d; }
.mer__total strong { font-size: 1.05rem; }
.mer__field { display: flex; flex-direction: column; gap: .3rem; }
.mer__label { font-size: .72rem; font-weight: 700; color: #374151; text-transform: uppercase; letter-spacing: .04em; }
.mer__req { color: #ef4444; }
.mer__qty { display: flex; align-items: center; gap: .4rem; }
.mer__unit { font-size: .82rem; color: #64748b; font-weight: 600; }
.mer__input { background: #f8fafc; border: 1.5px solid #e2e8f0; border-radius: 9px; padding: .55rem .8rem; font-size: .85rem; color: #0f172a; width: 100%; box-sizing: border-box; outline: none; }
.mer__input:focus { border-color: #1b5e20; background: #fff; }
.mer__row { display: grid; grid-template-columns: 1fr 1fr; gap: .6rem; }
.mer__hint { font-size: .78rem; color: #94a3b8; }
.mer__warn { font-size: .75rem; color: #b45309; }
.mer__cc { background: #fffbeb; border: 1px solid #fde68a; border-radius: 9px; padding: .6rem .85rem; display: flex; flex-direction: column; gap: .25rem; font-size: .8rem; color: #92400e; }
.mer__cc-row { display: flex; justify-content: space-between; }
.mer__cc-warn { font-weight: 700; color: #b45309; }
.mer__toggle { display: flex; align-items: center; justify-content: space-between; padding: .7rem .85rem; border: 1.5px solid #e2e8f0; border-radius: 10px; cursor: pointer; gap: .6rem; }
.mer__toggle:hover { border-color: #86efac; background: #f0fdf4; }
.mer__toggle-title { font-size: .82rem; font-weight: 700; color: #0f172a; }
.mer__toggle-sub { font-size: .72rem; color: #94a3b8; }
.mer__switch { width: 36px; height: 20px; background: #e2e8f0; border-radius: 10px; position: relative; flex-shrink: 0; transition: background .2s; }
.mer__switch--on { background: #1b5e20; }
.mer__knob { position: absolute; top: 2px; left: 2px; width: 16px; height: 16px; background: #fff; border-radius: 50%; transition: transform .2s; }
.mer__switch--on .mer__knob { transform: translateX(16px); }
.mer__envio { display: flex; flex-direction: column; gap: .6rem; padding: .75rem; background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 10px; }
.mer__seg { display: flex; gap: .35rem; background: #f1f5f9; padding: .2rem; border-radius: 9px; }
.mer__seg-btn { flex: 1; border: none; background: transparent; color: #64748b; font-size: .78rem; font-weight: 700; padding: .4rem; border-radius: 7px; cursor: pointer; }
.mer__seg-btn--on { background: #fff; color: #15803d; box-shadow: 0 1px 3px rgba(0,0,0,.08); }
.mer__seg-btn:disabled { opacity: .45; cursor: not-allowed; }
.mer__footer { display: flex; justify-content: flex-end; gap: .6rem; padding: .85rem 1.25rem; border-top: 1px solid #f1f5f9; }
.mer__btn-primary { display: inline-flex; align-items: center; gap: .4rem; background: #15803d; color: #fff; border: none; padding: .6rem 1.2rem; border-radius: 9px; font-size: .85rem; font-weight: 700; cursor: pointer; }
.mer__btn-primary:disabled { opacity: .5; cursor: not-allowed; }
.mer__btn-ghost { background: #fff; color: #64748b; border: 1.5px solid #e2e8f0; padding: .6rem 1.1rem; border-radius: 9px; font-size: .85rem; font-weight: 600; cursor: pointer; }
</style>
