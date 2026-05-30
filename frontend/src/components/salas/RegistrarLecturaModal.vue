<template>
  <Teleport to="body">
    <Transition name="rlm-fade">
      <div v-if="modelValue" class="rlm__overlay">
        <div class="rlm__modal" role="dialog" aria-modal="true">

          <div class="rlm__header">
            <div class="rlm__title-wrap">
              <Gauge :size="18" :stroke-width="1.75" class="rlm__title-ico" />
              <h3 class="rlm__title">Registrar lecturas ambientales</h3>
            </div>
            <button class="rlm__close" @click="close"><X :size="18" :stroke-width="1.75" /></button>
          </div>

          <div class="rlm__body">
            <div v-if="errorMsg" class="rlm__error">{{ errorMsg }}</div>

            <!-- Selector de lote (si hay varios activos) -->
            <div v-if="lotesActivos.length > 1" class="rlm__field">
              <label class="rlm__label">Lote <span class="rlm__req">*</span></label>
              <select class="rlm__select" v-model="loteSeleccionado">
                <option value="" disabled>Seleccioná un lote…</option>
                <option v-for="l in lotesActivos" :key="l.id" :value="l.id">
                  {{ l.codigo }} — {{ l.estado }}
                </option>
              </select>
            </div>
            <div v-else-if="lotesActivos.length === 1" class="rlm__lote-badge">
              <Leaf :size="13" :stroke-width="2" />
              {{ lotesActivos[0].codigo }} — {{ lotesActivos[0].estado }}
            </div>

            <!-- Ambiente -->
            <div class="rlm__section-title">Ambiente</div>
            <div class="rlm__grid">
              <div class="rlm__field">
                <label class="rlm__label">Temperatura <span class="rlm__unit">°C</span></label>
                <input type="number" step="0.1" class="rlm__input" v-model.number="form.temperatura" placeholder="25.0" @input="calcVpd" />
              </div>
              <div class="rlm__field">
                <label class="rlm__label">Humedad <span class="rlm__unit">%</span></label>
                <input type="number" step="0.1" min="0" max="100" class="rlm__input" v-model.number="form.humedad" placeholder="60.0" @input="calcVpd" />
              </div>
              <div class="rlm__field">
                <label class="rlm__label">CO₂ <span class="rlm__unit">ppm</span></label>
                <input type="number" step="1" class="rlm__input" v-model.number="form.co2" placeholder="800" />
              </div>
              <div class="rlm__field">
                <label class="rlm__label">VPD <span class="rlm__unit">kPa</span></label>
                <div class="rlm__input rlm__input--calc rlm__vpd-display">{{ vpdDisplay || '—' }}</div>
              </div>
            </div>

            <!-- Solución nutritiva -->
            <div class="rlm__section-title">Solución nutritiva</div>
            <div class="rlm__grid">
              <div class="rlm__field">
                <label class="rlm__label">pH <span class="rlm__unit">entrada</span></label>
                <input type="number" step="0.1" min="0" max="14" class="rlm__input" v-model.number="form.ph" placeholder="6.2" />
              </div>
              <div class="rlm__field">
                <label class="rlm__label">EC <span class="rlm__unit">mS/cm</span></label>
                <input type="number" step="0.01" class="rlm__input" v-model.number="form.ec" placeholder="1.8" />
              </div>
              <div class="rlm__field">
                <label class="rlm__label">pH runoff</label>
                <input type="number" step="0.1" min="0" max="14" class="rlm__input" v-model.number="form.ph_runoff" placeholder="6.0" />
              </div>
              <div class="rlm__field">
                <label class="rlm__label">EC runoff <span class="rlm__unit">mS/cm</span></label>
                <input type="number" step="0.01" class="rlm__input" v-model.number="form.ec_runoff" placeholder="2.0" />
              </div>
            </div>

            <!-- Luz -->
            <div class="rlm__section-title">Luz</div>
            <div class="rlm__grid">
              <div class="rlm__field">
                <label class="rlm__label">PPFD <span class="rlm__unit">µmol/m²s</span></label>
                <input type="number" step="1" class="rlm__input" v-model.number="form.ppfd" placeholder="600" />
              </div>
              <div class="rlm__field">
                <label class="rlm__label">Horas luz <span class="rlm__unit">h</span></label>
                <input type="number" step="0.5" min="0" max="24" class="rlm__input" v-model.number="form.horas_luz" placeholder="18" />
              </div>
            </div>

            <!-- Sustrato -->
            <div class="rlm__section-title">Sustrato</div>
            <div class="rlm__grid rlm__grid--half">
              <div class="rlm__field">
                <label class="rlm__label">Temperatura sustrato <span class="rlm__unit">°C</span></label>
                <input type="number" step="0.1" class="rlm__input" v-model.number="form.temperatura_sustrato" placeholder="22.0" />
              </div>
            </div>

            <!-- Observaciones -->
            <div class="rlm__field">
              <label class="rlm__label">Observaciones</label>
              <textarea class="rlm__textarea" v-model="form.observaciones" rows="2" placeholder="Estado general, notas de riego, plagas observadas…"></textarea>
            </div>

            <!-- Fecha y hora -->
            <div class="rlm__field">
              <label class="rlm__label">Fecha y hora</label>
              <input type="datetime-local" class="rlm__input" v-model="form.medido_at" />
            </div>
          </div>

          <div class="rlm__footer">
            <button class="rlm__btn-ghost" :disabled="saving" @click="close">Cancelar</button>
            <button class="rlm__btn-primary" :disabled="saving || !canSubmit" @click="submit">
              <DsSpinner v-if="saving" :size="16" />
              <span v-else>Registrar</span>
            </button>
          </div>

        </div>
      </div>
    </Transition>
  </Teleport>
</template>

<script setup>
import { ref, computed, watch } from 'vue'
import { Gauge, X, Leaf } from 'lucide-vue-next'
import { createLecturaAmbiental, createRegistroAmbiental } from '../../lib/api.js'
import { useToast } from '../../composables/useToast.js'
import DsSpinner from '../../design-system/components/Spinner.vue'

const props = defineProps({
  modelValue: { type: Boolean, required: true },
  salaId:     { type: Number,  required: true },
  lotes:      { type: Array,   default: () => [] }, // todos los lotes de la sala
})
const emit = defineEmits(['update:modelValue', 'registrada'])

const toast    = useToast()
const saving   = ref(false)
const errorMsg = ref(null)

const ESTADOS_ACTIVOS = ['semilla', 'vegetativo', 'floracion', 'cosecha', 'secado']
const lotesActivos = computed(() =>
  props.lotes.filter(l => ESTADOS_ACTIVOS.includes(l.estado))
)

const loteSeleccionado = ref(null)

const loteId = computed(() => {
  if (lotesActivos.value.length === 1) return lotesActivos.value[0].id
  return loteSeleccionado.value || null
})

function nowLocal() {
  const d = new Date(); d.setSeconds(0, 0)
  // datetime-local expects local time — subtract timezone offset so user sees their clock
  return new Date(d.getTime() - d.getTimezoneOffset() * 60000).toISOString().slice(0, 16)
}

const form = ref(emptyForm())
function emptyForm() {
  return {
    temperatura: null, humedad: null, co2: null,
    ph: null, ec: null, ph_runoff: null, ec_runoff: null,
    ppfd: null, horas_luz: null, temperatura_sustrato: null,
    observaciones: '', medido_at: nowLocal(),
  }
}

// VPD auto-calculado
const vpd = ref(null)
const vpdDisplay = computed(() => vpd.value != null ? vpd.value.toFixed(2) : '')
function calcVpd() {
  const t = form.value.temperatura
  const h = form.value.humedad
  if (t == null || h == null || Number.isNaN(t) || Number.isNaN(h)) { vpd.value = null; return }
  const svp = 0.6108 * Math.exp(17.27 * t / (t + 237.3))
  vpd.value = Math.round(svp * (1 - h / 100) * 1000) / 1000
}

watch(() => props.modelValue, (open) => {
  if (open) {
    form.value = emptyForm()
    errorMsg.value = null
    vpd.value = null
    if (lotesActivos.value.length === 1) loteSeleccionado.value = lotesActivos.value[0].id
    else loteSeleccionado.value = null
  }
})

const tieneDatos = computed(() => {
  const f = form.value
  return [f.temperatura, f.humedad, f.co2, f.ph, f.ec, f.ph_runoff, f.ec_runoff, f.ppfd, f.horas_luz, f.temperatura_sustrato]
    .some(v => v != null && !Number.isNaN(v))
})

const canSubmit = computed(() => {
  if (!tieneDatos.value) return false
  if (lotesActivos.value.length > 1 && !loteSeleccionado.value) return false
  return true
})

function close() {
  if (!saving.value) emit('update:modelValue', false)
}

async function submit() {
  if (!canSubmit.value) return
  saving.value   = true
  errorMsg.value = null

  try {
    if (loteId.value) {
      // Registro completo asociado al lote (propaga automáticamente a LecturaAmbiental via callback)
      const payload = {}
      const campos = ['temperatura','humedad','co2','ph','ec','ph_runoff','ec_runoff','ppfd','horas_luz','temperatura_sustrato']
      campos.forEach(c => { const v = form.value[c]; if (v != null && !Number.isNaN(v)) payload[c] = v })
      if (form.value.observaciones) payload.observaciones = form.value.observaciones
      payload.fuente = 'manual'
      await createRegistroAmbiental(loteId.value, payload)
    } else {
      // Sin lote activo: lecturas individuales por sala
      const promises = []
      const UNIDADES = { temperatura:'°C', humedad:'%', co2:'ppm', ph:'pH', ec:'mS/cm', ppfd:'µmol/m²s' }
      Object.entries(UNIDADES).forEach(([tipo, unidad]) => {
        const valor = form.value[tipo]
        if (valor != null && !Number.isNaN(valor)) {
          // Convert local datetime-local string back to UTC for storage
          const medido_at = new Date(form.value.medido_at).toISOString()
          promises.push(createLecturaAmbiental(props.salaId, {
            tipo, valor, unidad, medido_at, fuente: 'manual',
          }))
        }
      })
      await Promise.all(promises)
    }

    toast.success('Lectura registrada')
    emit('registrada')
    emit('update:modelValue', false)
  } catch (e) {
    errorMsg.value = e?.response?.data?.errors?.join(', ')
      || e?.response?.data?.error
      || 'Error al registrar la lectura'
  } finally {
    saving.value = false
  }
}
</script>

<style scoped>
.rlm__overlay {
  position: fixed; inset: 0; background: rgba(0,0,0,.45);
  display: flex; align-items: center; justify-content: center;
  z-index: 1050; padding: var(--sp-4); backdrop-filter: blur(3px);
}
.rlm__modal {
  background: var(--c-paper); border-radius: var(--r-xl);
  box-shadow: var(--sh-3); width: 100%; max-width: 560px;
  display: flex; flex-direction: column; overflow: hidden;
  max-height: 92vh;
}
.rlm__header {
  display: flex; align-items: center; justify-content: space-between;
  padding: var(--sp-4) var(--sp-5); border-bottom: 1px solid var(--c-ink-100);
  flex-shrink: 0;
}
.rlm__title-wrap { display: flex; align-items: center; gap: var(--sp-2); }
.rlm__title-ico  { color: var(--c-role-cultivador); flex-shrink: 0; }
.rlm__title { font-family: var(--font-display); font-size: var(--fs-16); font-weight: 600; color: var(--c-ink-900); margin: 0; }
.rlm__close {
  width: 32px; height: 32px; border-radius: var(--r-md); border: none;
  background: transparent; color: var(--c-ink-400);
  display: flex; align-items: center; justify-content: center;
  cursor: pointer; transition: background var(--t-fast), color var(--t-fast);
}
.rlm__close:hover { background: var(--c-ink-100); color: var(--c-ink-900); }

.rlm__body {
  padding: var(--sp-4) var(--sp-5); display: flex; flex-direction: column;
  gap: var(--sp-3); overflow-y: auto; flex: 1;
}
.rlm__error {
  background: var(--c-rust-100); border: 1px solid #fecaca;
  color: var(--c-rust-600); border-radius: var(--r-md);
  padding: var(--sp-3) var(--sp-4); font-size: var(--fs-14);
}
.rlm__section-title {
  font-size: 11px; font-weight: 700; text-transform: uppercase;
  letter-spacing: .06em; color: var(--c-ink-400);
  border-bottom: 1px solid var(--c-ink-100); padding-bottom: var(--sp-1);
  margin-top: var(--sp-1);
}
.rlm__grid {
  display: grid; grid-template-columns: 1fr 1fr; gap: var(--sp-3);
}
.rlm__grid--half { grid-template-columns: 1fr; }
@media (max-width: 480px) { .rlm__grid { grid-template-columns: 1fr; } }

.rlm__lote-badge {
  display: inline-flex; align-items: center; gap: .4rem;
  font-size: var(--fs-13); font-weight: 600;
  color: var(--c-role-cultivador);
  background: var(--c-leaf-50); border: 1px solid #d4e6d4;
  border-radius: var(--r-pill); padding: .3rem .75rem;
  align-self: flex-start;
}

.rlm__field { display: flex; flex-direction: column; gap: var(--sp-1); }
.rlm__label {
  font-size: var(--fs-13); font-weight: 600; color: var(--c-ink-700);
  display: flex; align-items: center; gap: .3rem;
}
.rlm__unit { font-weight: 400; font-size: 11px; color: var(--c-ink-400); font-family: var(--font-mono); }
.rlm__req  { color: var(--c-rust-600); }

.rlm__input, .rlm__select {
  height: 42px; padding: 0 var(--sp-3);
  border: 1.5px solid var(--c-ink-300); border-radius: var(--r-md);
  font-size: var(--fs-14); color: var(--c-ink-900);
  background: var(--c-paper); width: 100%;
  transition: border-color var(--t-fast); font-family: var(--font-mono);
  box-sizing: border-box;
}
.rlm__input:focus, .rlm__select:focus {
  outline: none; border-color: var(--c-role-cultivador);
  box-shadow: 0 0 0 3px rgba(92,122,74,.12);
}
.rlm__input--calc { background: var(--c-ink-50); color: var(--c-ink-500); cursor: default; }
.rlm__vpd-display { display: flex; align-items: center; font-family: var(--font-mono); }
.rlm__textarea {
  padding: var(--sp-2) var(--sp-3); border: 1.5px solid var(--c-ink-300);
  border-radius: var(--r-md); font-size: var(--fs-14); color: var(--c-ink-900);
  background: var(--c-paper); resize: vertical; font-family: var(--font-ui);
  transition: border-color var(--t-fast); width: 100%; box-sizing: border-box;
}
.rlm__textarea:focus { outline: none; border-color: var(--c-role-cultivador); box-shadow: 0 0 0 3px rgba(92,122,74,.12); }

.rlm__footer {
  display: flex; align-items: center; justify-content: flex-end; gap: var(--sp-3);
  padding: var(--sp-4) var(--sp-5); border-top: 1px solid var(--c-ink-100);
  flex-shrink: 0;
}
.rlm__btn-ghost {
  display: inline-flex; align-items: center; height: 40px;
  padding: 0 var(--sp-4); border: 1px solid var(--c-ink-300);
  border-radius: var(--r-md); background: transparent; color: var(--c-ink-600);
  font-size: var(--fs-14); font-weight: 500; cursor: pointer; transition: background var(--t-fast);
}
.rlm__btn-ghost:hover:not(:disabled) { background: var(--c-ink-100); }
.rlm__btn-ghost:disabled { opacity: .5; cursor: not-allowed; }
.rlm__btn-primary {
  display: inline-flex; align-items: center; justify-content: center; gap: var(--sp-2);
  height: 40px; padding: 0 var(--sp-5); border: none; border-radius: var(--r-md);
  background: var(--c-role-cultivador); color: #fff;
  font-size: var(--fs-14); font-weight: 600; cursor: pointer;
  transition: opacity var(--t-fast); min-width: 110px;
}
.rlm__btn-primary:hover:not(:disabled) { opacity: .88; }
.rlm__btn-primary:disabled { opacity: .5; cursor: not-allowed; }
.rlm-fade-enter-active { animation: rlm-appear .2s ease; }
.rlm-fade-leave-active { animation: rlm-appear .15s ease reverse; }
@keyframes rlm-appear {
  from { opacity: 0; transform: scale(.96) translateY(8px); }
  to   { opacity: 1; transform: scale(1) translateY(0); }
}
</style>
