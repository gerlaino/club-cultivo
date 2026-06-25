<template>
  <Teleport to="body">
    <div v-if="modelValue" class="rtm__overlay" @click.self="cerrar">
      <div class="rtm__modal">
        <div class="rtm__head">
          <h3>🪴 Registrar trasplante</h3>
          <button class="rtm__close" @click="cerrar"><i class="bi bi-x-lg"></i></button>
        </div>
        <div class="rtm__body">
          <p class="rtm__hint">Podés cargar un trasplante de hoy o uno que ya pasó. Queda en la timeline del lote.</p>
          <div v-if="error" class="rtm__err">{{ error }}</div>

          <label class="rtm__label">Fecha del trasplante</label>
          <AppDatePicker v-model="fecha" :max="hoy" />

          <div class="rtm__row">
            <div class="rtm__field">
              <label class="rtm__label">Maceta origen <span class="rtm__opt">(L)</span></label>
              <input v-model.number="macetaOrigen" type="number" min="0" step="0.5" class="rtm__input" placeholder="ej: 1" />
            </div>
            <div class="rtm__arrow">→</div>
            <div class="rtm__field">
              <label class="rtm__label">Maceta destino <span class="rtm__req">*</span> <span class="rtm__opt">(L)</span></label>
              <input v-model.number="macetaDestino" type="number" min="0.1" step="0.5" class="rtm__input" placeholder="ej: 3" />
            </div>
          </div>
        </div>
        <div class="rtm__foot">
          <button class="rtm__btn-ghost" @click="cerrar">Cancelar</button>
          <button class="rtm__btn-primary" :disabled="saving || !(macetaDestino > 0)" @click="guardar">
            <span v-if="saving">Guardando…</span>
            <span v-else>Registrar</span>
          </button>
        </div>
      </div>
    </div>
  </Teleport>
</template>

<script setup>
import { ref, watch } from 'vue'
import AppDatePicker from '../ui/AppDatePicker.vue'
import { registrarTrasplante } from '../../lib/api.js'
import { useToast } from '../../composables/useToast.js'

const props = defineProps({
  modelValue:    { type: Boolean, default: false },
  loteId:        { type: Number,  required: true },
  macetaActual:  { type: Number,  default: null },
})
const emit = defineEmits(['update:modelValue', 'saved'])
const toast = useToast()

const hoy = new Date().toISOString().split('T')[0]
const fecha = ref(hoy)
const macetaOrigen = ref(null)
const macetaDestino = ref(null)
const saving = ref(false)
const error = ref(null)

watch(() => props.modelValue, (open) => {
  if (!open) return
  fecha.value = hoy
  macetaOrigen.value = props.macetaActual || null   // pre-carga la maceta actual del lote
  macetaDestino.value = null
  error.value = null
})

function cerrar() { emit('update:modelValue', false) }

async function guardar() {
  if (!(macetaDestino.value > 0)) return
  saving.value = true
  error.value = null
  try {
    await registrarTrasplante(props.loteId, {
      fecha: fecha.value,
      maceta_origen_l: macetaOrigen.value || undefined,
      maceta_destino_l: macetaDestino.value,
    })
    toast.success('Trasplante registrado')
    emit('saved')
    cerrar()
  } catch (e) {
    error.value = e.response?.data?.error || 'No se pudo registrar el trasplante'
  } finally { saving.value = false }
}
</script>

<style scoped>
.rtm__overlay { position: fixed; inset: 0; background: rgba(0,0,0,.45); display: flex; align-items: center; justify-content: center; z-index: 1060; padding: 1rem; }
.rtm__modal { background: #fff; border-radius: 14px; width: 100%; max-width: 420px; box-shadow: 0 20px 60px rgba(0,0,0,.3); }
.rtm__head { display: flex; align-items: center; justify-content: space-between; padding: 1rem 1.25rem; border-bottom: 1px solid #f1f5f9; }
.rtm__head h3 { margin: 0; font-size: 1rem; font-weight: 800; color: #0f172a; }
.rtm__close { background: none; border: none; cursor: pointer; color: #94a3b8; font-size: 1rem; }
.rtm__body { padding: 1.25rem; }
.rtm__hint { font-size: .8rem; color: #64748b; margin: 0 0 .75rem; }
.rtm__err { background: #fef2f2; border: 1px solid #fecaca; color: #dc2626; padding: .5rem .75rem; border-radius: 8px; font-size: .82rem; margin-bottom: .75rem; }
.rtm__label { display: block; font-size: .75rem; font-weight: 700; color: #374151; margin: .6rem 0 .3rem; }
.rtm__opt { font-weight: 400; color: #94a3b8; }
.rtm__req { color: #dc2626; }
.rtm__input { width: 100%; box-sizing: border-box; border: 1.5px solid #cbd5e1; border-radius: 8px; padding: .55rem .7rem; font-size: .95rem; font-weight: 700; color: #0f172a; outline: none; }
.rtm__input:focus { border-color: #16a34a; }
.rtm__row { display: flex; align-items: flex-end; gap: .5rem; }
.rtm__field { flex: 1; min-width: 0; }
.rtm__arrow { padding-bottom: .55rem; color: #94a3b8; font-weight: 800; }
.rtm__foot { display: flex; justify-content: flex-end; gap: .5rem; padding: 1rem 1.25rem; border-top: 1px solid #f1f5f9; }
.rtm__btn-ghost { background: #fff; border: 1.5px solid #cbd5e1; color: #334155; border-radius: 8px; padding: .5rem 1rem; font-size: .85rem; font-weight: 600; cursor: pointer; }
.rtm__btn-primary { background: #1b5e20; color: #fff; border: none; border-radius: 8px; padding: .5rem 1.1rem; font-size: .85rem; font-weight: 700; cursor: pointer; }
.rtm__btn-primary:disabled { opacity: .5; cursor: not-allowed; }
</style>
