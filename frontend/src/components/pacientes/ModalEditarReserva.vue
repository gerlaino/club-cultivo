<template>
  <Teleport to="body">
    <div v-if="modelValue && reserva" class="mre__overlay">
      <div class="mre__modal">
        <div class="mre__head">
          <h3>Editar reserva</h3>
          <button class="mre__close" @click="cerrar"><i class="bi bi-x-lg"></i></button>
        </div>
        <div class="mre__body">
          <div v-if="error" class="mre__err">{{ error }}</div>
          <label class="mre__label">Cantidad ({{ reserva.stock?.unidad || 'g' }})</label>
          <input v-model.number="form.cantidad" type="number" min="0.01" step="0.01" class="mre__input" />
          <label class="mre__label">Fecha de entrega estimada</label>
          <AppDatePicker v-model="form.fecha_entrega_estimada" :min="hoy" />
          <!-- El medio de pago solo aplica si se dejó seña (es el medio con que se pagó). -->
          <template v-if="tieneSena">
            <label class="mre__label">Medio de pago de la seña</label>
            <select v-model="form.medio_pago" class="mre__input">
              <option value="efectivo">Efectivo</option>
              <option value="transferencia">Transferencia</option>
            </select>
          </template>
        </div>
        <div class="mre__foot">
          <button class="mre__btn-ghost" @click="cerrar">Cancelar</button>
          <button class="mre__btn-primary" :disabled="saving" @click="guardar">Guardar</button>
        </div>
      </div>
    </div>
  </Teleport>
</template>

<script setup>
import { ref, computed, watch } from 'vue'
import AppDatePicker from '../ui/AppDatePicker.vue'
import { updateReserva } from '../../lib/api.js'
import { useToast } from '../../composables/useToast.js'

const props = defineProps({
  modelValue: { type: Boolean, default: false },
  reserva:    { type: Object,  default: null },
})
const emit = defineEmits(['update:modelValue', 'saved'])
const toast = useToast()

const hoy    = new Date().toISOString().split('T')[0]
const tieneSena = computed(() => Number(props.reserva?.sena_ars) > 0)
const saving = ref(false)
const error  = ref(null)
const form   = ref({ cantidad: null, fecha_entrega_estimada: '', medio_pago: 'efectivo' })

watch(() => props.modelValue, (open) => {
  if (!open || !props.reserva) return
  form.value = {
    cantidad: props.reserva.cantidad,
    fecha_entrega_estimada: props.reserva.fecha_entrega_estimada,
    medio_pago: props.reserva.medio_pago || 'efectivo',
  }
  error.value = null
})

function cerrar() { emit('update:modelValue', false) }

async function guardar() {
  saving.value = true
  error.value = null
  try {
    await updateReserva(props.reserva.id, { ...form.value })
    toast.success('Reserva actualizada')
    emit('saved')
    cerrar()
  } catch (e) {
    error.value = e.response?.data?.errors?.[0] || e.response?.data?.error || 'No se pudo guardar'
  } finally { saving.value = false }
}
</script>

<style scoped>
.mre__overlay { position: fixed; inset: 0; background: rgba(0,0,0,.45); display: flex; align-items: center; justify-content: center; z-index: 1060; padding: 1rem; backdrop-filter: blur(3px); }
.mre__modal { background: #fff; border-radius: 14px; width: 100%; max-width: 400px; box-shadow: 0 24px 64px rgba(0,0,0,.18); }
.mre__head { display: flex; align-items: center; justify-content: space-between; padding: 1rem 1.25rem; border-bottom: 1px solid #f1f5f9; }
.mre__head h3 { font-size: 1rem; font-weight: 800; margin: 0; color: #0f172a; }
.mre__close { background: #f1f5f9; border: none; width: 28px; height: 28px; border-radius: 7px; cursor: pointer; color: #64748b; }
.mre__body { padding: 1rem 1.25rem; display: flex; flex-direction: column; gap: .5rem; }
.mre__err { background: #fef2f2; color: #dc2626; border: 1px solid #fecaca; border-radius: 8px; padding: .5rem .7rem; font-size: .8rem; }
.mre__label { font-size: .72rem; font-weight: 700; color: #374151; text-transform: uppercase; letter-spacing: .04em; margin-top: .3rem; }
.mre__input { background: #f8fafc; border: 1.5px solid #e2e8f0; border-radius: 9px; padding: .55rem .8rem; font-size: .85rem; color: #0f172a; width: 100%; box-sizing: border-box; outline: none; }
.mre__foot { display: flex; justify-content: flex-end; gap: .6rem; padding: .85rem 1.25rem; border-top: 1px solid #f1f5f9; }
.mre__btn-primary { background: #15803d; color: #fff; border: none; padding: .55rem 1.1rem; border-radius: 9px; font-size: .85rem; font-weight: 700; cursor: pointer; }
.mre__btn-primary:disabled { opacity: .5; }
.mre__btn-ghost { background: #fff; color: #64748b; border: 1.5px solid #e2e8f0; padding: .55rem 1.1rem; border-radius: 9px; font-size: .85rem; font-weight: 600; cursor: pointer; }
</style>
