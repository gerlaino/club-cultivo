<template>
  <Teleport to="body">
    <div v-if="modelValue" class="ren__overlay" @click.self="cerrar">
      <div class="ren__modal">
        <div class="ren__head">
          <div>
            <h3 class="ren__title">🌱 Ambiente del enraizado</h3>
            <p class="ren__sub">
              {{ lotesCount }} lote{{ lotesCount === 1 ? '' : 's' }} enraizando en {{ salaNombre }}
            </p>
          </div>
          <button class="ren__close" @click="cerrar"><i class="bi bi-x-lg"></i></button>
        </div>

        <div class="ren__body">
          <p class="ren__nota">
            El propagador tiene su propio clima: el cuarto puede estar al 60% de humedad y adentro
            del domo al 90%. Este registro va solo a los lotes que están enraizando.
          </p>
          <div v-if="error" class="ren__alert">{{ error }}</div>

          <!-- Cuatro campos y nada más: adentro de un propagador no hay riego, ni EC, ni pH. Un
               esqueje sin raíz no absorbe, así que pedir esos datos sería inventarlos. -->
          <div class="ren__grid">
            <div class="ren__field">
              <label class="ren__label">Temperatura (°C)</label>
              <input v-model.number="form.temperatura" type="number" step="0.1" class="ren__input" placeholder="24" />
            </div>
            <div class="ren__field">
              <label class="ren__label">Humedad (%)</label>
              <input v-model.number="form.humedad" type="number" step="1" class="ren__input" placeholder="90" />
            </div>
            <div class="ren__field">
              <label class="ren__label">Temp. de sustrato (°C)</label>
              <input v-model.number="form.temperatura_sustrato" type="number" step="0.1" class="ren__input" placeholder="25" />
              <span class="ren__hint">Decide el prendimiento más que la del aire.</span>
            </div>
            <div class="ren__field">
              <label class="ren__label">Enraizante</label>
              <select v-model="form.producto_enraizante" class="ren__input">
                <option value="">— Sin especificar —</option>
                <option v-for="e in ENRAIZANTES" :key="e.v" :value="e.v">{{ e.l }}</option>
              </select>
            </div>
          </div>

          <div class="ren__field">
            <label class="ren__label">Notas <span class="ren__opt">(opcional)</span></label>
            <textarea v-model="form.notas" rows="2" class="ren__input" placeholder="Observaciones del domo…"></textarea>
          </div>
        </div>

        <div class="ren__foot">
          <button class="ren__btn ren__btn--ghost" @click="cerrar">Cancelar</button>
          <button class="ren__btn" :disabled="saving || sinDatos" @click="guardar">
            {{ saving ? 'Guardando…' : 'Registrar' }}
          </button>
        </div>
      </div>
    </div>
  </Teleport>
</template>

<script setup>
import { ref, computed, watch } from 'vue'
import { registrarEnraizado } from '../../lib/api.js'
import { useToast } from '../../composables/useToast.js'

const props = defineProps({
  modelValue: { type: Boolean, default: false },
  salaId:     { type: [Number, String], required: true },
  salaNombre: { type: String, default: '' },
  lotesCount: { type: Number, default: 0 },
})
const emit = defineEmits(['update:modelValue', 'registrado'])

const toast = useToast()

// Estructurado, no texto libre: distintos geles/polvos prenden distinto, y así se puede cruzar con
// el % de prendimiento. Espeja RegistroAmbiental::ENRAIZANTES.
const ENRAIZANTES = [
  { v: 'gel',         l: 'Gel' },
  { v: 'polvo',       l: 'Polvo' },
  { v: 'liquido',     l: 'Líquido' },
  { v: 'miel_canela', l: 'Miel / canela' },
  { v: 'ninguno',     l: 'Ninguno' },
  { v: 'otro',        l: 'Otro' },
]

const vacio = () => ({ temperatura: null, humedad: null, temperatura_sustrato: null,
                       producto_enraizante: '', notas: '' })
const form   = ref(vacio())
const saving = ref(false)
const error  = ref(null)

// Un registro sin una sola medición no dice nada: mejor no guardarlo que ensuciar la serie.
const sinDatos = computed(() =>
  form.value.temperatura == null && form.value.humedad == null && form.value.temperatura_sustrato == null)

watch(() => props.modelValue, (v) => { if (v) { form.value = vacio(); error.value = null } })

function cerrar() { emit('update:modelValue', false) }

async function guardar() {
  saving.value = true; error.value = null
  try {
    const payload = { ...form.value }
    Object.keys(payload).forEach(k => { if (payload[k] === null || payload[k] === '') delete payload[k] })
    const { data } = await registrarEnraizado(props.salaId, payload)
    toast.success(`Ambiente registrado en ${data.lotes_afectados} lote${data.lotes_afectados === 1 ? '' : 's'}`)
    emit('registrado')
    cerrar()
  } catch (e) {
    error.value = e?.response?.data?.errors?.join(', ') || e?.response?.data?.error || 'No se pudo registrar'
  } finally { saving.value = false }
}
</script>

<style scoped>
.ren__overlay {
  position: fixed; inset: 0; background: rgba(15,23,42,.45); z-index: 1200;
  display: flex; align-items: center; justify-content: center; padding: 1rem;
}
.ren__modal { background: #fff; border-radius: 14px; width: 100%; max-width: 460px; overflow: hidden; }
.ren__head {
  display: flex; align-items: flex-start; justify-content: space-between;
  padding: .9rem 1rem; border-bottom: 1px solid #f1f5f9;
}
.ren__title { margin: 0; font-size: .95rem; color: #1e293b; }
.ren__sub   { margin: .15rem 0 0; font-size: .75rem; color: #94a3b8; }
.ren__close { border: none; background: none; cursor: pointer; color: #94a3b8; font-size: .85rem; }
.ren__body  { padding: 1rem; display: flex; flex-direction: column; gap: .75rem; }
.ren__nota  { margin: 0; font-size: .75rem; color: #64748b; line-height: 1.45; background: #f0fdf4;
              border-left: 3px solid #86efac; padding: .5rem .65rem; border-radius: 0 6px 6px 0; }
.ren__foot  { display: flex; justify-content: flex-end; gap: .5rem; padding: .8rem 1rem; border-top: 1px solid #f1f5f9; }

.ren__grid  { display: grid; grid-template-columns: 1fr 1fr; gap: .75rem; }
@media (max-width: 480px) { .ren__grid { grid-template-columns: 1fr; } }

.ren__field { display: flex; flex-direction: column; gap: .25rem; }
.ren__label { font-size: .75rem; font-weight: 600; color: #475569; }
.ren__opt   { font-weight: 400; color: #94a3b8; }
.ren__input {
  border: 1px solid #e2e8f0; border-radius: 8px; padding: .5rem .65rem; font-size: .85rem;
  width: 100%; box-sizing: border-box; font-family: inherit;
}
.ren__input:focus { outline: none; border-color: #16a34a; }
.ren__hint  { font-size: .7rem; color: #94a3b8; }
.ren__alert { background: #fee2e2; color: #b91c1c; padding: .5rem .7rem; border-radius: 8px; font-size: .78rem; }

.ren__btn {
  border: none; border-radius: 8px; padding: .5rem .9rem; cursor: pointer;
  background: #16a34a; color: #fff; font-size: .82rem; font-weight: 600;
}
.ren__btn:disabled { opacity: .5; cursor: not-allowed; }
.ren__btn--ghost { background: none; color: #64748b; border: 1px solid #e2e8f0; }
</style>
