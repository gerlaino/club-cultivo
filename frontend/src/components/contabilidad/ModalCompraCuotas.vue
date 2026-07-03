<script setup>
import { ref, computed, watch } from 'vue'
import AppDatePicker from '../ui/AppDatePicker.vue'
import DsSpinner from '../../design-system/components/Spinner.vue'
import { createCompraCuotas } from '../../lib/api.js'
import { useToast } from '../../composables/useToast.js'

const props = defineProps({
  modelValue: { type: Boolean, required: true },
  sedes:      { type: Array,   default: () => [] },
})
const emit = defineEmits(['update:modelValue', 'guardado'])

const toast   = useToast()
const saving  = ref(false)
const error   = ref(null)

const CATEGORIAS = [
  { value: 'insumo',        label: 'Insumo / Materia prima' },
  { value: 'mantenimiento', label: 'Mantenimiento / Equipamiento' },
  { value: 'electricidad',  label: 'Electricidad' },
  { value: 'agua',          label: 'Agua' },
  { value: 'alquiler',      label: 'Alquiler' },
  { value: 'sueldo',        label: 'Sueldo / Honorarios staff' },
  { value: 'honorario',     label: 'Honorario profesional' },
  { value: 'seguro',        label: 'Seguro' },
  { value: 'admin',         label: 'Gasto administrativo' },
]
const MEDIOS = [
  { value: '',              label: '— Sin especificar —' },
  { value: 'transferencia', label: 'Transferencia' },
  { value: 'cheque',        label: 'Cheque' },
  { value: 'efectivo',      label: 'Efectivo' },
  { value: 'mercado_pago',  label: 'Mercado Pago' },
]

const hoyISO = new Date().toISOString().split('T')[0]

const form = ref({})
function reset() {
  form.value = {
    descripcion: '', categoria: 'mantenimiento', monto_total_ars: null,
    cuotas_total: 6, fecha_primera_cuota: hoyISO, medio_pago: '',
    responsable: '', proveedor: '', notas: '',
    sede_id: props.sedes[0]?.id ?? null,
  }
  error.value = null
}
watch(() => props.modelValue, (open) => { if (open) reset() }, { immediate: true })

const fmt = n => n == null ? '—' :
  new Intl.NumberFormat('es-AR', { style: 'currency', currency: 'ARS', minimumFractionDigits: 0 }).format(n)

const montoPorCuota = computed(() => {
  const t = Number(form.value.monto_total_ars) || 0
  const n = Number(form.value.cuotas_total) || 0
  return n > 0 ? Math.round((t / n) * 100) / 100 : 0
})

// Rango de meses (primera → última cuota) para el preview.
const rangoMeses = computed(() => {
  const n = Number(form.value.cuotas_total) || 0
  if (!form.value.fecha_primera_cuota || n < 1) return '—'
  const d = new Date(form.value.fecha_primera_cuota + 'T00:00:00')
  const fin = new Date(d); fin.setMonth(fin.getMonth() + (n - 1))
  const f = x => x.toLocaleDateString('es-AR', { month: 'short', year: 'numeric' })
  return n === 1 ? f(d) : `${f(d)} → ${f(fin)}`
})

const canSubmit = computed(() =>
  form.value.descripcion?.trim() &&
  Number(form.value.monto_total_ars) > 0 &&
  Number(form.value.cuotas_total) >= 1 &&
  form.value.fecha_primera_cuota &&
  form.value.sede_id
)

function close() { emit('update:modelValue', false) }

async function submit() {
  if (!canSubmit.value || saving.value) return
  saving.value = true; error.value = null
  try {
    await createCompraCuotas({
      sede_id:             form.value.sede_id,
      descripcion:         form.value.descripcion.trim(),
      categoria:           form.value.categoria,
      monto_total_ars:     form.value.monto_total_ars,
      cuotas_total:        form.value.cuotas_total,
      fecha_primera_cuota: form.value.fecha_primera_cuota,
      medio_pago:          form.value.medio_pago || null,
      responsable:         form.value.responsable || null,
      proveedor:           form.value.proveedor || null,
      notas:               form.value.notas || null,
    })
    toast.success(`Compra en ${form.value.cuotas_total} cuotas registrada`)
    emit('guardado')
    close()
  } catch (e) {
    error.value = e.response?.data?.errors?.[0] || e.response?.data?.error || 'Error al registrar la compra'
  } finally { saving.value = false }
}
</script>

<template>
  <Teleport to="body">
    <div v-if="modelValue" class="mcc__overlay" @mousedown.self="close">
      <div class="mcc__modal">
        <div class="mcc__header">
          <h3 class="mcc__title"><i class="bi bi-credit-card-2-front"></i> Compra en cuotas</h3>
          <button class="mcc__close" @click="close"><i class="bi bi-x-lg"></i></button>
        </div>

        <div class="mcc__body">
          <div v-if="error" class="mcc__error"><i class="bi bi-exclamation-triangle-fill"></i> {{ error }}</div>

          <div class="mcc__field">
            <label class="mcc__label">Descripción <span class="mcc__req">*</span></label>
            <input v-model="form.descripcion" class="mcc__input" placeholder="Ej: Aire acondicionado 3000 frigorías" />
          </div>

          <div class="mcc__row">
            <div class="mcc__field">
              <label class="mcc__label">Categoría</label>
              <select v-model="form.categoria" class="mcc__input">
                <option v-for="c in CATEGORIAS" :key="c.value" :value="c.value">{{ c.label }}</option>
              </select>
            </div>
            <div class="mcc__field">
              <label class="mcc__label">Sede <span class="mcc__req">*</span></label>
              <select v-model="form.sede_id" class="mcc__input">
                <option v-for="s in sedes" :key="s.id" :value="s.id">{{ s.nombre }}</option>
              </select>
            </div>
          </div>

          <div class="mcc__row">
            <div class="mcc__field">
              <label class="mcc__label">Monto total <span class="mcc__req">*</span></label>
              <div class="mcc__input-prefix-wrap">
                <span class="mcc__prefix">$</span>
                <input v-model.number="form.monto_total_ars" type="number" min="1" step="1" class="mcc__input mcc__input--prefix" placeholder="0" />
              </div>
            </div>
            <div class="mcc__field mcc__field--sm">
              <label class="mcc__label">Cuotas <span class="mcc__req">*</span></label>
              <input v-model.number="form.cuotas_total" type="number" min="1" max="120" step="1" class="mcc__input" />
            </div>
          </div>

          <div class="mcc__field">
            <label class="mcc__label">Primera cuota (mes) <span class="mcc__req">*</span></label>
            <AppDatePicker v-model="form.fecha_primera_cuota" />
            <span class="mcc__hint">Podés poner un mes anterior para que las cuotas ya vencidas cuadren con el balance.</span>
          </div>

          <!-- Preview -->
          <div class="mcc__preview">
            <div class="mcc__preview-row">
              <span>{{ form.cuotas_total || 0 }} cuota{{ Number(form.cuotas_total) === 1 ? '' : 's' }} de</span>
              <strong>{{ fmt(montoPorCuota) }}</strong>
            </div>
            <div class="mcc__preview-row mcc__preview-row--muted">
              <span>{{ rangoMeses }}</span>
              <span>Total {{ fmt(Number(form.monto_total_ars) || 0) }}</span>
            </div>
          </div>

          <div class="mcc__row">
            <div class="mcc__field">
              <label class="mcc__label">Tarjeta / responsable <span class="mcc__opt">opcional</span></label>
              <input v-model="form.responsable" class="mcc__input" placeholder="Ej: Tarjeta del club / Germán" />
            </div>
            <div class="mcc__field">
              <label class="mcc__label">Medio de pago <span class="mcc__opt">opcional</span></label>
              <select v-model="form.medio_pago" class="mcc__input">
                <option v-for="m in MEDIOS" :key="m.value" :value="m.value">{{ m.label }}</option>
              </select>
            </div>
          </div>

          <div class="mcc__field">
            <label class="mcc__label">Proveedor / notas <span class="mcc__opt">opcional</span></label>
            <input v-model="form.proveedor" class="mcc__input" placeholder="Proveedor" style="margin-bottom:.4rem" />
            <textarea v-model="form.notas" class="mcc__input mcc__textarea" rows="2" placeholder="Notas…"></textarea>
          </div>
        </div>

        <div class="mcc__footer">
          <button class="mcc__btn-ghost" :disabled="saving" @click="close">Cancelar</button>
          <button class="mcc__btn-primary" :disabled="saving || !canSubmit" @click="submit">
            <DsSpinner v-if="saving" :size="14" />
            <i v-else class="bi bi-check-lg"></i>
            Registrar {{ form.cuotas_total || '' }} cuotas
          </button>
        </div>
      </div>
    </div>
  </Teleport>
</template>

<style scoped>
.mcc__overlay { position: fixed; inset: 0; background: rgba(0,0,0,.45); display: flex; align-items: center; justify-content: center; z-index: 1055; padding: 1rem; backdrop-filter: blur(3px); }
.mcc__modal { background: #fff; border-radius: 18px; width: 100%; max-width: 520px; max-height: 92vh; overflow-y: auto; box-shadow: 0 24px 64px rgba(0,0,0,.18); display: flex; flex-direction: column; }
.mcc__header { display: flex; align-items: center; justify-content: space-between; padding: 1.1rem 1.25rem .9rem; border-bottom: 1px solid #f1f5f9; position: sticky; top: 0; background: #fff; }
.mcc__title { font-size: 1rem; font-weight: 800; color: #0f172a; margin: 0; display: flex; align-items: center; gap: .5rem; }
.mcc__close { background: none; border: none; color: #94a3b8; cursor: pointer; font-size: 1rem; }
.mcc__body { padding: 1rem 1.25rem; display: flex; flex-direction: column; gap: .8rem; }
.mcc__error { background: #fef2f2; color: #b91c1c; border-radius: 8px; padding: .5rem .75rem; font-size: .82rem; display: flex; align-items: center; gap: .4rem; }
.mcc__field { display: flex; flex-direction: column; gap: .3rem; flex: 1; }
.mcc__field--sm { max-width: 110px; }
.mcc__row { display: flex; gap: .75rem; }
.mcc__label { font-size: 11px; font-weight: 700; text-transform: uppercase; letter-spacing: .05em; color: #475569; }
.mcc__req { color: #dc2626; }
.mcc__opt { color: #94a3b8; font-weight: 500; text-transform: none; letter-spacing: 0; }
.mcc__input { background: #f8fafc; border: 1.5px solid #e2e8f0; border-radius: 9px; padding: .55rem .7rem; font-size: .88rem; color: #0f172a; outline: none; width: 100%; box-sizing: border-box; }
.mcc__input:focus { border-color: #16a34a; }
.mcc__textarea { resize: vertical; }
.mcc__input-prefix-wrap { position: relative; display: flex; align-items: center; }
.mcc__prefix { position: absolute; left: .7rem; color: #64748b; font-weight: 600; font-size: .85rem; }
.mcc__input--prefix { padding-left: 1.5rem; }
.mcc__hint { font-size: .72rem; color: #94a3b8; }
.mcc__preview { background: #f0fdf4; border: 1px solid #bbf7d0; border-radius: 10px; padding: .6rem .8rem; display: flex; flex-direction: column; gap: .2rem; }
.mcc__preview-row { display: flex; align-items: baseline; justify-content: space-between; font-size: .9rem; color: #166534; }
.mcc__preview-row strong { font-size: 1.05rem; font-weight: 800; }
.mcc__preview-row--muted { font-size: .76rem; color: #15803d; opacity: .8; }
.mcc__footer { display: flex; justify-content: flex-end; gap: .6rem; padding: .9rem 1.25rem 1.1rem; border-top: 1px solid #f1f5f9; position: sticky; bottom: 0; background: #fff; }
.mcc__btn-ghost { background: none; border: 1.5px solid #e2e8f0; border-radius: 9px; padding: .55rem 1rem; font-weight: 600; color: #64748b; cursor: pointer; }
.mcc__btn-primary { background: #16a34a; border: none; border-radius: 9px; padding: .55rem 1.1rem; font-weight: 700; color: #fff; cursor: pointer; display: flex; align-items: center; gap: .4rem; }
.mcc__btn-primary:disabled { opacity: .55; cursor: not-allowed; }
</style>
