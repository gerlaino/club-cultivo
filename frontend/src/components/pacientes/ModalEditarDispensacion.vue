<script setup>
import { ref, computed, watch } from 'vue'
import AppDatePicker from '../ui/AppDatePicker.vue'
import { useToast } from '../../composables/useToast.js'
import DsSpinner from '../../design-system/components/Spinner.vue'
import { updateDispensacion } from '../../lib/api.js'

const props = defineProps({
  modelValue:     { type: Boolean, required: true },
  dispensacion:   { type: Object,  default: null },
  saldoCc:        { type: Number,  default: null },
  limiteCc:       { type: Number,  default: null },
})

const emit = defineEmits(['update:modelValue', 'saved'])

const toast      = useToast()
const saving     = ref(false)
const formError  = ref(null)

const FORMA_LABEL = {
  flor_seca: 'Flor seca', hash: 'Hash', aceite: 'Aceite',
  preroll: 'Preroll', crema: 'Crema', descarte: 'Descarte', otro: 'Otro',
}
const FORMA_EMOJI = {
  flor_seca: '🌿', hash: '🟤', aceite: '🫙',
  preroll: '🚬', crema: '💊', descarte: '🗑️', otro: '📦',
}

const fmt = n => n == null ? '—' :
  new Intl.NumberFormat('es-AR', { style: 'currency', currency: 'ARS', minimumFractionDigits: 0 }).format(n)

// ── Cuenta corriente ───────────────────────────────────────
const tieneCc  = computed(() => props.limiteCc !== null && props.limiteCc > 0)
const ccMargen = computed(() => (props.saldoCc ?? 0) + (props.limiteCc ?? 0))

const ccInsuficiente = computed(() => {
  if (!tieneCc.value || form.value.medio_pago !== 'cuenta_corriente') return false
  if (form.value.aporte_socio_ars == null) return false
  return Number(form.value.aporte_socio_ars) > ccMargen.value
})

const estadoCc = computed(() => {
  if (!tieneCc.value) return null
  if (ccMargen.value <= 0)  return 'agotado'
  if (ccInsuficiente.value) return 'insuficiente'
  if (ccMargen.value < (props.limiteCc ?? 0) * 0.2) return 'critico'
  return 'ok'
})

// ── Form ──────────────────────────────────────────────────
const form = ref({})

function buildForm(d) {
  if (!d) return {}
  return {
    cantidad:           d.cantidad ?? null,
    fecha_dispensacion: d.fecha_dispensacion || '',
    medio_pago:         d.medio_pago || 'efectivo',
    aporte_socio_ars:   d.aporte_socio_ars ?? null,
    observaciones:      d.observaciones || '',
  }
}

// Precio unitario original (para re-sugerir el aporte al cambiar la cantidad).
const precioUnitOrig = computed(() => {
  const a = Number(props.dispensacion?.aporte_socio_ars) || 0
  const c = Number(props.dispensacion?.cantidad) || 0
  return c > 0 ? a / c : 0
})
function onCantidadChange() {
  if (precioUnitOrig.value > 0 && Number(form.value.cantidad) > 0) {
    form.value.aporte_socio_ars = Math.round(precioUnitOrig.value * Number(form.value.cantidad))
  }
}

watch(() => props.modelValue, (open) => {
  if (open && props.dispensacion) {
    form.value  = buildForm(props.dispensacion)
    formError.value = null
  }
}, { immediate: true })

watch(() => props.dispensacion, (d) => {
  if (props.modelValue && d) form.value = buildForm(d)
})

function cerrar() { emit('update:modelValue', false) }

async function handleSubmit() {
  if (saving.value) return
  saving.value = true
  formError.value = null

  if (form.value.medio_pago === 'cuenta_corriente' && !(Number(form.value.aporte_socio_ars) > 0)) {
    formError.value = 'El aporte debe ser mayor a $0 cuando el medio de pago es cuenta corriente'
    saving.value = false; return
  }

  try {
    await updateDispensacion(props.dispensacion.id, {
      cantidad:           form.value.cantidad,
      fecha_dispensacion: form.value.fecha_dispensacion,
      medio_pago:         form.value.medio_pago,
      aporte_socio_ars:   form.value.aporte_socio_ars,
      observaciones:      form.value.observaciones || null,
    })
    cerrar()
    toast.success('Dispensación actualizada')
    emit('saved')
  } catch (e) {
    formError.value = e.response?.data?.errors?.[0] || e.response?.data?.error || 'Error al guardar'
  } finally { saving.value = false }
}

const stk = computed(() => props.dispensacion?.stock)
</script>

<template>
  <Teleport to="body">
    <div v-if="modelValue && dispensacion" class="med__overlay">
      <div class="med__modal">

        <div class="med__modal-header">
          <h3 class="med__modal-title">
            Editar dispensación
            <span v-if="dispensacion.paciente_nombre" class="med__modal-title-paciente">— {{ dispensacion.paciente_nombre }}</span>
          </h3>
          <button class="med__modal-close" @click="cerrar"><i class="bi bi-x-lg"></i></button>
        </div>

        <div class="med__modal-body">
          <div v-if="formError" class="med__error"><i class="bi bi-exclamation-triangle-fill"></i> {{ formError }}</div>

          <!-- Stock dispensado — solo lectura -->
          <div class="med__section-label">Producto dispensado</div>
          <div class="med__stock-info">
            <span class="med__stock-emoji">{{ FORMA_EMOJI[stk?.forma_producto] || '📦' }}</span>
            <div class="med__stock-detail">
              <span class="med__stock-nombre">{{ FORMA_LABEL[stk?.forma_producto] || stk?.forma_producto || '—' }}</span>
              <span v-if="stk?.lote?.genetica?.nombre" class="med__stock-gen">{{ stk.lote.genetica.nombre }}</span>
            </div>
            <div class="med__stock-cantidad">
              <div class="med__qty-edit">
                <input v-model.number="form.cantidad" type="number" min="0.01" step="0.01" class="med__qty-input" @input="onCantidadChange" />
                <span class="med__qty-unit">{{ stk?.unidad || 'g' }}</span>
              </div>
            </div>
          </div>

          <div class="med__divider"></div>

          <!-- Aporte -->
          <div class="med__field">
            <label class="med__label">Aporte del socio <span class="med__opt">ARS</span></label>
            <div class="med__input-suffix-wrap">
              <span class="med__input-prefix">$</span>
              <input v-model.number="form.aporte_socio_ars" type="number" min="0" step="1"
                     class="med__input med__input--with-prefix" placeholder="0" />
            </div>
          </div>

          <!-- CC info -->
          <div v-if="tieneCc" class="med__cc-panel" :class="`med__cc-panel--${estadoCc || 'ok'}`">
            <div class="med__cc-row">
              <span class="med__cc-label"><i class="bi bi-wallet2"></i> Crédito disponible</span>
              <span class="med__cc-saldo" :class="{ 'med__cc-saldo--bajo': ccMargen <= 0 }">{{ fmt(ccMargen) }}</span>
            </div>
            <div v-if="ccInsuficiente" class="med__cc-warn">
              <i class="bi bi-exclamation-triangle-fill"></i>
              Crédito insuficiente (disponible: {{ fmt(ccMargen) }})
            </div>
          </div>

          <!-- Fecha + pago -->
          <div class="med__form-row">
            <div class="med__field">
              <label class="med__label">Fecha</label>
              <AppDatePicker v-model="form.fecha_dispensacion" />
            </div>
            <div class="med__field">
              <label class="med__label">Medio de pago</label>
              <select v-model="form.medio_pago" class="med__input">
                <option value="efectivo">Efectivo</option>
                <option value="transferencia">Transferencia</option>
                <option value="cuenta_corriente" :disabled="!tieneCc">Cuenta corriente{{ !tieneCc ? ' (sin límite)' : '' }}</option>
                <option value="no_abona">No abona</option>
              </select>
            </div>
          </div>

          <!-- Observaciones -->
          <div class="med__field">
            <label class="med__label">Observaciones <span class="med__opt">opcional</span></label>
            <textarea v-model.trim="form.observaciones" class="med__input med__textarea" rows="2"
                      placeholder="Notas adicionales…"></textarea>
          </div>

        </div>

        <div class="med__modal-footer">
          <button class="med__btn-ghost" :disabled="saving" @click="cerrar">Cancelar</button>
          <button class="med__btn-primary" :disabled="saving" @click="handleSubmit">
            <DsSpinner v-if="saving" :size="14" />
            <i v-else class="bi bi-check-lg"></i>
            Guardar cambios
          </button>
        </div>

      </div>
    </div>
  </Teleport>
</template>

<style scoped>
.med__overlay { position: fixed; inset: 0; background: rgba(0,0,0,.45); display: flex; align-items: center; justify-content: center; z-index: 1050; padding: 1rem; backdrop-filter: blur(3px); }
.med__modal { background: #fff; border-radius: 18px; width: 100%; max-width: 540px; max-height: 92vh; overflow-y: auto; box-shadow: 0 24px 64px rgba(0,0,0,.18); display: flex; flex-direction: column; }

.med__modal-header { display: flex; align-items: center; justify-content: space-between; gap: 1rem; padding: 1.1rem 1.25rem .9rem; border-bottom: 1px solid #f1f5f9; position: sticky; top: 0; background: #fff; z-index: 1; }
.med__modal-title { font-size: .95rem; font-weight: 800; color: #0f172a; margin: 0; }
.med__modal-title-paciente { color: #15803d; font-weight: 600; }
.med__modal-close { background: #f1f5f9; border: none; width: 28px; height: 28px; border-radius: 7px; cursor: pointer; display: flex; align-items: center; justify-content: center; color: #64748b; }
.med__modal-close:hover { background: #e2e8f0; }

.med__modal-body { padding: 1.1rem 1.25rem; flex: 1; display: flex; flex-direction: column; gap: .9rem; background: #f8fafc; }
.med__modal-footer { display: flex; justify-content: flex-end; gap: .75rem; padding: .875rem 1.25rem; border-top: 1px solid #f1f5f9; position: sticky; bottom: 0; background: #fff; }

.med__error { background: #fef2f2; color: #dc2626; border: 1px solid #fecaca; border-radius: 9px; padding: .6rem .875rem; font-size: .82rem; display: flex; align-items: center; gap: .4rem; }

/* Stock info (readonly) */
.med__section-label { font-size: .72rem; font-weight: 700; color: #374151; text-transform: uppercase; letter-spacing: .05em; }
.med__stock-info { display: flex; align-items: center; gap: .75rem; padding: .7rem .875rem; border-radius: 10px; border: 1.5px solid #e2e8f0; background: #fff; }
.med__stock-emoji { font-size: 1.2rem; flex-shrink: 0; }
.med__stock-detail { flex: 1; min-width: 0; display: flex; flex-direction: column; gap: .1rem; }
.med__stock-nombre { font-size: .82rem; font-weight: 700; color: #0f172a; }
.med__stock-gen { font-size: .72rem; color: #64748b; font-style: italic; }
.med__stock-cantidad { display: flex; flex-direction: column; align-items: flex-end; gap: .2rem; flex-shrink: 0; }
.med__stock-qty { font-size: .95rem; font-weight: 800; color: #1b5e20; font-family: monospace; }
.med__stock-readonly-badge { font-size: .62rem; color: #94a3b8; background: #f1f5f9; border-radius: 4px; padding: .1em .4em; }
.med__qty-edit { display: flex; align-items: center; gap: .3rem; }
.med__qty-input { width: 72px; text-align: right; background: #f8fafc; border: 1.5px solid #e2e8f0; border-radius: 7px; padding: .35rem .5rem; font-size: .85rem; font-weight: 700; color: #0f172a; outline: none; }
.med__qty-unit { font-size: .78rem; color: #64748b; font-weight: 600; }

/* Form */
.med__divider { height: 1px; background: #e2e8f0; }
.med__form-row { display: grid; grid-template-columns: 1fr 1fr; gap: .75rem; }
@media (max-width: 400px) { .med__form-row { grid-template-columns: 1fr; } }
.med__field { display: flex; flex-direction: column; gap: .3rem; }
.med__label { font-size: .72rem; font-weight: 700; color: #374151; text-transform: uppercase; letter-spacing: .05em; }
.med__opt { font-size: .67rem; font-weight: 400; color: #94a3b8; text-transform: none; letter-spacing: 0; }
.med__input { background: #fff; border: 1.5px solid #cbd5e1; border-radius: 9px; padding: .6rem .8rem; font-size: .875rem; color: #0f172a; width: 100%; box-sizing: border-box; outline: none; transition: border-color .15s, box-shadow .15s; }
.med__input:focus { border-color: #2D8A6B; box-shadow: 0 0 0 3px rgba(45,138,107,.12); background: #fff; }
.med__textarea { resize: vertical; min-height: 58px; }
.med__input-suffix-wrap { display: flex; }
.med__input--with-prefix { border-radius: 0 9px 9px 0; flex: 1; }
.med__input-prefix { background: #f1f5f9; border: 1.5px solid #cbd5e1; border-right: none; border-radius: 9px 0 0 9px; padding: .6rem .7rem; font-size: .8rem; color: #64748b; display: flex; align-items: center; }

/* CC panel */
.med__cc-panel { border-radius: 10px; padding: .7rem .9rem; border: 1.5px solid #e2e8f0; display: flex; flex-direction: column; gap: .3rem; }
.med__cc-panel--ok           { background: #f0fdf4; border-color: #bbf7d0; }
.med__cc-panel--insuficiente { background: #fef2f2; border-color: #fecaca; }
.med__cc-panel--agotado      { background: #fef2f2; border-color: #fecaca; }
.med__cc-panel--critico      { background: #fffbeb; border-color: #fde68a; }
.med__cc-row { display: flex; align-items: center; justify-content: space-between; }
.med__cc-label { font-size: .75rem; font-weight: 700; color: #374151; display: flex; align-items: center; gap: .35rem; }
.med__cc-saldo { font-size: .9rem; font-weight: 800; color: #15803d; }
.med__cc-saldo--bajo { color: #dc2626; }
.med__cc-warn { font-size: .75rem; font-weight: 600; color: #dc2626; display: flex; align-items: center; gap: .3rem; }

/* Buttons */
.med__btn-primary { display: inline-flex; align-items: center; gap: .4rem; background: #1b5e20; color: #fff; border: none; padding: .6rem 1.1rem; border-radius: 9px; font-size: .82rem; font-weight: 600; cursor: pointer; transition: background .15s; white-space: nowrap; }
.med__btn-primary:hover:not(:disabled) { background: #144a18; }
.med__btn-primary:disabled { opacity: .5; cursor: not-allowed; }
.med__btn-ghost { background: #fff; color: #64748b; border: 1.5px solid #e2e8f0; padding: .6rem 1.1rem; border-radius: 9px; font-size: .875rem; font-weight: 500; cursor: pointer; }
.med__btn-ghost:hover { background: #f8fafc; }
</style>
