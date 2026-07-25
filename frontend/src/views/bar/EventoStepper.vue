<script setup>
// Stepper de fases del evento (B6 del rediseño del Salón): reemplaza el <select> de estado por
// un carril visual planificado → en venta → en curso → cerrado. Se avanza (o se corrige un paso
// atrás) tocando la fase; "Cancelar" saca el evento del carril. Un evento terminal no se toca.
import { computed } from 'vue'

const props = defineProps({
  estado:       { type: String, required: true },
  transiciones: { type: Array, default: () => [] }, // estados válidos desde el back (defensa)
  saving:       { type: Boolean, default: false },
})
const emit = defineEmits(['cambiar', 'cancelar'])

const CARRIL = [
  { v: 'planificado', l: 'Planificado', hint: 'Armando el evento' },
  { v: 'en_venta',    l: 'En venta',    hint: 'Vendiendo entradas' },
  { v: 'en_curso',    l: 'En curso',    hint: 'Sucediendo ahora' },
  { v: 'finalizado',  l: 'Cerrado',     hint: 'P&L asentado' },
]

const cancelado = computed(() => props.estado === 'cancelado')
const idx = computed(() => CARRIL.findIndex(s => s.v === props.estado))
const terminal = computed(() => props.estado === 'finalizado' || cancelado.value)
const siguiente = computed(() => (terminal.value || idx.value < 0) ? null : CARRIL[idx.value + 1] || null)

function claseStep(i) {
  if (cancelado.value) return 'off'
  if (i < idx.value) return 'done'
  if (i === idx.value) return 'current'
  return 'todo'
}
// Se puede tocar el paso siguiente (avanzar) o el anterior (corregir), nunca desde un terminal.
function clickable(i) {
  if (terminal.value || idx.value < 0) return false
  return i === idx.value + 1 || i === idx.value - 1
}
function irA(i) {
  if (!clickable(i) || props.saving) return
  emit('cambiar', CARRIL[i].v)
}
</script>

<template>
  <div class="stp">
    <div v-if="cancelado" class="stp__cancel">Evento cancelado</div>

    <ol v-else class="stp__rail">
      <li v-for="(s, i) in CARRIL" :key="s.v" class="stp__step" :class="[claseStep(i), { clickable: clickable(i) }]">
        <button type="button" class="stp__dot" :disabled="!clickable(i)" @click="irA(i)" :title="clickable(i) ? `Pasar a ${s.l}` : s.hint">
          <span v-if="claseStep(i) === 'done'">✓</span>
          <span v-else>{{ i + 1 }}</span>
        </button>
        <div class="stp__meta">
          <span class="stp__l">{{ s.l }}</span>
          <span class="stp__h">{{ s.hint }}</span>
        </div>
        <span v-if="i < CARRIL.length - 1" class="stp__line" :class="{ filled: i < idx }"></span>
      </li>
    </ol>

    <div v-if="!terminal" class="stp__actions">
      <button v-if="siguiente" class="stp__cta" :disabled="saving" @click="emit('cambiar', siguiente.v)">
        {{ siguiente.v === 'finalizado' ? 'Cerrar evento' : `Pasar a ${siguiente.l}` }} →
      </button>
      <button class="stp__cancel-btn" :disabled="saving" @click="emit('cancelar')">Cancelar evento</button>
    </div>
  </div>
</template>

<style scoped>
.stp { background: var(--c-paper, #fff); border: 1px solid #f1f5f9; border-radius: var(--r-lg, 14px); padding: 16px 18px; }
.stp__rail { list-style: none; display: flex; margin: 0; padding: 0; }
.stp__step { position: relative; flex: 1; display: flex; flex-direction: column; align-items: center; gap: 6px; padding: 0 4px; min-width: 0; }
.stp__dot { width: 30px; height: 30px; border-radius: 50%; border: 2px solid #e2e8f0; background: #fff; color: #94a3b8; font-size: .8rem; font-weight: 700; display: grid; place-items: center; cursor: default; z-index: 1; }
.stp__step.done .stp__dot    { background: #1b5e20; border-color: #1b5e20; color: #fff; }
.stp__step.current .stp__dot { background: #fff; border-color: #1b5e20; color: #1b5e20; box-shadow: 0 0 0 4px #f0fdf4; }
.stp__step.clickable .stp__dot { cursor: pointer; }
.stp__step.clickable .stp__dot:hover { border-color: #1b5e20; color: #1b5e20; }
.stp__meta { display: flex; flex-direction: column; align-items: center; text-align: center; min-width: 0; }
.stp__l { font-size: var(--fs-13, 13px); font-weight: 640; color: #64748b; }
.stp__step.current .stp__l { color: #0f172a; }
.stp__step.done .stp__l { color: #1b5e20; }
.stp__h { font-size: var(--fs-11, 11px); color: #cbd5e1; }
.stp__step.current .stp__h { color: #94a3b8; }
.stp__line { position: absolute; top: 15px; left: 50%; width: 100%; height: 2px; background: #e2e8f0; z-index: 0; }
.stp__line.filled { background: #1b5e20; }

.stp__actions { display: flex; align-items: center; gap: 12px; margin-top: 16px; padding-top: 14px; border-top: 1px solid #f1f5f9; }
.stp__cta { background: #1b5e20; border: 1px solid #1b5e20; color: #fff; border-radius: var(--r-sm, 8px); padding: 8px 16px; font-size: var(--fs-13, 13px); font-weight: 650; cursor: pointer; }
.stp__cta:hover { background: #154a19; }
.stp__cta:disabled { opacity: .5; cursor: default; }
.stp__cancel-btn { margin-left: auto; background: none; border: none; color: #94a3b8; font-size: var(--fs-13, 13px); cursor: pointer; padding: 4px 8px; }
.stp__cancel-btn:hover { color: #dc2626; }
.stp__cancel { text-align: center; font-size: var(--fs-14, 14px); font-weight: 640; color: #94a3b8; background: #f8fafc; border-radius: var(--r-sm, 8px); padding: 12px; text-transform: uppercase; letter-spacing: .04em; }
</style>
