<script setup>
import { ref, computed, watch } from 'vue'
import { updateCompraCuotas } from '../../lib/api'
import { useToast } from '../../composables/useToast.js'

const props = defineProps({
  modelValue: { type: Boolean, default: false },
  compra:     { type: Object,  default: null },   // la compra a editar (del serialize)
  sedes:      { type: Array,   default: () => [] },
})
const emit = defineEmits(['update:modelValue', 'saved'])

const toast = useToast()

const CATEGORIAS = [
  { value: 'insumo',        label: 'Insumos' },
  { value: 'electricidad',  label: 'Electricidad' },
  { value: 'agua',          label: 'Agua' },
  { value: 'alquiler',      label: 'Alquiler' },
  { value: 'sueldo',        label: 'Sueldos' },
  { value: 'mantenimiento', label: 'Mantenimiento' },
  { value: 'honorario',     label: 'Honorarios' },
  { value: 'seguro',        label: 'Seguros' },
  { value: 'admin',         label: 'Administrativo' },
  { value: 'otro',          label: 'Otros' },
]
const MEDIOS = [
  { value: 'efectivo',      label: 'Efectivo' },
  { value: 'transferencia', label: 'Transferencia' },
  { value: 'mercado_pago',  label: 'Mercado Pago' },
]

const form   = ref(emptyForm())
const errors = ref({})
const saving = ref(false)

function emptyForm() {
  return {
    descripcion: '', categoria: 'insumo', monto_total_ars: null, cuotas_total: 6,
    fecha_primera_cuota: '', medio_pago: 'transferencia', responsable: '', proveedor: '',
    sede_id: '', notas: '',
  }
}

watch(() => props.modelValue, (open) => {
  if (!open || !props.compra) return
  const c = props.compra
  form.value = {
    descripcion: c.descripcion || '',
    categoria:   c.categoria || 'insumo',
    monto_total_ars: c.monto_total_ars ?? null,
    cuotas_total: c.cuotas_total ?? 6,
    fecha_primera_cuota: (c.fecha_primera_cuota || '').slice(0, 10),
    medio_pago:  c.medio_pago || 'transferencia',
    responsable: c.responsable || '',
    proveedor:   c.proveedor || '',
    sede_id:     c.sede?.id || '',
    notas:       c.notas || '',
  }
  errors.value = {}
})

const valorCuota = computed(() => {
  const total = Number(form.value.monto_total_ars)
  const n     = Number(form.value.cuotas_total)
  if (!total || !n || n < 1) return null
  return total / n
})
const fmt = (n) => '$' + Number(n || 0).toLocaleString('es-AR', { maximumFractionDigits: 0 })

function validar() {
  const e = {}
  const f = form.value
  if (!f.descripcion?.trim())          e.descripcion = 'Requerida'
  if (!(Number(f.monto_total_ars) > 0)) e.monto_total_ars = 'Debe ser mayor a 0'
  if (!(Number(f.cuotas_total) >= 2))   e.cuotas_total = 'Mínimo 2 cuotas'
  if (!f.fecha_primera_cuota)          e.fecha_primera_cuota = 'Requerida'
  if (!f.sede_id)                      e.sede_id = 'Requerida'
  errors.value = e
  return Object.keys(e).length === 0
}

async function guardar() {
  if (!validar() || saving.value) return
  saving.value = true
  try {
    await updateCompraCuotas(props.compra.id, {
      descripcion: form.value.descripcion.trim(),
      categoria:   form.value.categoria,
      monto_total_ars: Number(form.value.monto_total_ars),
      cuotas_total: Number(form.value.cuotas_total),
      fecha_primera_cuota: form.value.fecha_primera_cuota,
      medio_pago:  form.value.medio_pago,
      responsable: form.value.responsable?.trim() || null,
      proveedor:   form.value.proveedor?.trim() || null,
      sede_id:     form.value.sede_id,
      notas:       form.value.notas?.trim() || null,
    })
    toast.success('Compra en cuotas actualizada')
    emit('saved')
    emit('update:modelValue', false)
  } catch (err) {
    toast.error(err.response?.data?.error || err.response?.data?.errors?.[0] || 'No se pudo actualizar')
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <Teleport to="body">
    <div v-if="modelValue" class="ecc__overlay" @click.self="emit('update:modelValue', false)">
      <div class="ecc__card">
        <div class="ecc__hd">
          <h3 class="ecc__title">Editar compra en cuotas</h3>
          <button class="ecc__close" @click="emit('update:modelValue', false)"><i class="bi bi-x-lg"></i></button>
        </div>

        <div class="ecc__body">
          <div class="ecc__field ecc__field--full">
            <label class="ecc__label">Descripción</label>
            <input v-model="form.descripcion" class="ecc__input" :class="{ 'ecc__input--err': errors.descripcion }" placeholder="Ej: Aire acondicionado sala B" />
            <span v-if="errors.descripcion" class="ecc__err">{{ errors.descripcion }}</span>
          </div>

          <div class="ecc__field">
            <label class="ecc__label">Precio del producto (total)</label>
            <input v-model.number="form.monto_total_ars" type="number" min="0" step="0.01" class="ecc__input" :class="{ 'ecc__input--err': errors.monto_total_ars }" placeholder="180000" />
            <span v-if="errors.monto_total_ars" class="ecc__err">{{ errors.monto_total_ars }}</span>
          </div>
          <div class="ecc__field">
            <label class="ecc__label">Cantidad de cuotas</label>
            <input v-model.number="form.cuotas_total" type="number" min="2" max="120" step="1" class="ecc__input" :class="{ 'ecc__input--err': errors.cuotas_total }" />
            <span v-if="errors.cuotas_total" class="ecc__err">{{ errors.cuotas_total }}</span>
          </div>

          <div v-if="valorCuota" class="ecc__calc ecc__field--full">
            {{ form.cuotas_total }} cuotas de <strong>{{ fmt(valorCuota) }}</strong>
          </div>

          <div class="ecc__field">
            <label class="ecc__label">Categoría</label>
            <select v-model="form.categoria" class="ecc__input">
              <option v-for="c in CATEGORIAS" :key="c.value" :value="c.value">{{ c.label }}</option>
            </select>
          </div>
          <div class="ecc__field">
            <label class="ecc__label">Fecha 1ª cuota</label>
            <input v-model="form.fecha_primera_cuota" type="date" class="ecc__input" :class="{ 'ecc__input--err': errors.fecha_primera_cuota }" />
            <span v-if="errors.fecha_primera_cuota" class="ecc__err">{{ errors.fecha_primera_cuota }}</span>
          </div>

          <div class="ecc__field">
            <label class="ecc__label">Sede</label>
            <select v-model="form.sede_id" class="ecc__input" :class="{ 'ecc__input--err': errors.sede_id }">
              <option value="" disabled>Elegí una sede…</option>
              <option v-for="s in sedes" :key="s.id" :value="s.id">{{ s.nombre }}</option>
            </select>
            <span v-if="errors.sede_id" class="ecc__err">{{ errors.sede_id }}</span>
          </div>
          <div class="ecc__field">
            <label class="ecc__label">Medio de pago</label>
            <select v-model="form.medio_pago" class="ecc__input">
              <option v-for="m in MEDIOS" :key="m.value" :value="m.value">{{ m.label }}</option>
            </select>
          </div>

          <div class="ecc__field">
            <label class="ecc__label">Responsable / tarjeta <span class="ecc__opt">opcional</span></label>
            <input v-model="form.responsable" class="ecc__input" placeholder="Ej: Tarjeta Visa club" />
          </div>
          <div class="ecc__field">
            <label class="ecc__label">Proveedor <span class="ecc__opt">opcional</span></label>
            <input v-model="form.proveedor" class="ecc__input" placeholder="Ej: Frío Norte SRL" />
          </div>

          <div class="ecc__field ecc__field--full">
            <label class="ecc__label">Notas <span class="ecc__opt">opcional</span></label>
            <textarea v-model="form.notas" class="ecc__input" rows="2"></textarea>
          </div>

          <p class="ecc__warn ecc__field--full">
            <i class="bi bi-info-circle"></i>
            Al guardar se recalculan y regeneran las {{ form.cuotas_total }} cuotas con el nuevo total.
          </p>
        </div>

        <div class="ecc__ft">
          <button class="ecc__btn-ghost" @click="emit('update:modelValue', false)">Cancelar</button>
          <button class="ecc__btn-primary" :disabled="saving" @click="guardar">
            {{ saving ? 'Guardando…' : 'Guardar cambios' }}
          </button>
        </div>
      </div>
    </div>
  </Teleport>
</template>

<style scoped>
.ecc__overlay { position: fixed; inset: 0; z-index: 9998; background: rgba(0,0,0,.45); display: flex; align-items: center; justify-content: center; padding: 1rem; }
.ecc__card { background: #fff; border-radius: 14px; width: 100%; max-width: 520px; max-height: 90vh; overflow-y: auto; box-shadow: 0 20px 60px rgba(0,0,0,.2); }
.ecc__hd { display: flex; align-items: center; justify-content: space-between; padding: 1rem 1.25rem; border-bottom: 1px solid #eef2ee; }
.ecc__title { font-size: 1rem; font-weight: 700; color: #1a2e1a; margin: 0; }
.ecc__close { background: none; border: none; color: var(--c-slate-400); cursor: pointer; font-size: 1rem; }
.ecc__body { padding: 1rem 1.25rem; display: grid; grid-template-columns: 1fr 1fr; gap: .75rem; }
.ecc__field { display: flex; flex-direction: column; gap: .25rem; }
.ecc__field--full { grid-column: 1 / -1; }
.ecc__label { font-size: .75rem; font-weight: 600; color: var(--c-slate-600); }
.ecc__opt { color: var(--c-slate-400); font-weight: 400; }
.ecc__input { border: 1.5px solid var(--c-slate-200); border-radius: 8px; padding: .5rem .65rem; font-size: .85rem; width: 100%; }
.ecc__input:focus { outline: none; border-color: #15803d; }
.ecc__input--err { border-color: #dc2626; }
.ecc__err { font-size: .7rem; color: #dc2626; }
.ecc__calc { background: #f0fdf4; border: 1px solid #d4e6d4; border-radius: 8px; padding: .5rem .75rem; font-size: .85rem; color: #166534; }
.ecc__calc strong { font-size: 1rem; }
.ecc__warn { font-size: .72rem; color: #92400e; background: #fef3c7; border-radius: 8px; padding: .5rem .65rem; margin: 0; }
.ecc__ft { display: flex; justify-content: flex-end; gap: .5rem; padding: 1rem 1.25rem; border-top: 1px solid #eef2ee; }
.ecc__btn-ghost { background: transparent; color: #60725d; border: 1px solid #d4e6d4; padding: .55rem 1.1rem; border-radius: 8px; font-size: .85rem; cursor: pointer; }
.ecc__btn-primary { background: #15803d; color: #fff; border: none; padding: .55rem 1.25rem; border-radius: 8px; font-size: .85rem; font-weight: 600; cursor: pointer; }
.ecc__btn-primary:disabled { opacity: .6; cursor: not-allowed; }
</style>
