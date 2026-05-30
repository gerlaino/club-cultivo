<template>
  <div class="tf__wrap">
    <div class="tf__grid">
      <div class="tf__field">
        <label class="tf__label">Maceta origen <span class="tf__unit">L</span></label>
        <div v-if="f.maceta_origen_l" class="tf__current">
          {{ f.maceta_origen_l }}L
        </div>
        <input v-else type="number" step="0.5" min="0" class="tf__input" v-model.number="f.maceta_origen_l" placeholder="7" />
      </div>
      <div class="tf__field">
        <label class="tf__label">Maceta destino <span class="tf__unit">L</span> <span class="tf__req">*</span></label>
        <input type="number" step="0.5" min="0.5" class="tf__input" v-model.number="f.maceta_destino_l" placeholder="11" />
      </div>
    </div>

    <div v-if="f.maceta_origen_l && f.maceta_destino_l" class="tf__preview">
      <span class="tf__prev-val">{{ f.maceta_origen_l }}L</span>
      <i class="bi bi-arrow-right tf__prev-arrow"></i>
      <span class="tf__prev-val tf__prev-val--dest">{{ f.maceta_destino_l }}L</span>
    </div>

    <div class="tf__field">
      <label class="tf__label">Sustrato</label>
      <div class="tf__radios">
        <button v-for="s in SUSTRATOS" :key="s.value" type="button"
                class="tf__radio-btn" :class="{ 'tf__radio-btn--sel': f.sustrato === s.value }"
                @click="f.sustrato = s.value">
          {{ s.label }}
        </button>
      </div>
    </div>

    <div v-if="f.sustrato === 'diferente'" class="tf__field">
      <label class="tf__label">¿Cuál sustrato?</label>
      <input type="text" class="tf__input" v-model.trim="f.sustrato_descripcion" placeholder="Ej: coco + perlita 70/30" />
    </div>

    <div class="tf__field">
      <label class="tf__label">¿Cuántas plantas?</label>
      <div class="tf__radios">
        <button type="button" class="tf__radio-btn" :class="{ 'tf__radio-btn--sel': f.todas_plantas }"
                @click="f.todas_plantas = true">
          🪴 Todas ({{ totalPlantas || 'N' }})
        </button>
        <button type="button" class="tf__radio-btn" :class="{ 'tf__radio-btn--sel': f.todas_plantas === false }"
                @click="f.todas_plantas = false">
          Selección manual
        </button>
      </div>
    </div>

    <div v-if="f.todas_plantas === false" class="tf__field">
      <label class="tf__label">Cantidad de plantas</label>
      <input type="number" step="1" min="1" class="tf__input" v-model.number="f.cantidad_plantas" :placeholder="totalPlantas || ''" />
    </div>

    <div class="tf__field">
      <label class="tf__label">Estado de raíces observado</label>
      <div class="tf__radios tf__radios--wrap">
        <button v-for="r in RAICES" :key="r.value" type="button"
                class="tf__radio-btn" :class="{ 'tf__radio-btn--sel': f.estado_raices === r.value }"
                :style="f.estado_raices === r.value ? { borderColor: r.color, background: r.color + '18', color: r.color } : {}"
                @click="f.estado_raices = r.value">
          {{ r.emoji }} {{ r.label }}
        </button>
      </div>
    </div>

    <div class="tf__field tf__field--full">
      <label class="tf__label">Observaciones <span class="tf__optional">opcional</span></label>
      <textarea class="tf__textarea" rows="2" v-model.trim="f.observaciones" placeholder="Raíces bien desarrolladas, trasplante a sustrato definitivo…"></textarea>
    </div>
  </div>
</template>

<script setup>
import { computed } from 'vue'

const props = defineProps({
  modelValue:  { type: Object,  default: () => ({}) },
  totalPlantas:{ type: Number,  default: null },
})
const emit = defineEmits(['update:modelValue'])
const f = computed({
  get: () => props.modelValue,
  set: v => emit('update:modelValue', v),
})

const SUSTRATOS = [
  { value: 'mismo',     label: '🪱 Mismo sustrato' },
  { value: 'diferente', label: '🔄 Diferente sustrato' },
]
const RAICES = [
  { value: 'excelente', label: 'Excelente', emoji: '🟢', color: '#15803d' },
  { value: 'buena',     label: 'Buena',     emoji: '🟡', color: '#ca8a04' },
  { value: 'regular',   label: 'Regular',   emoji: '🟠', color: '#ea580c' },
  { value: 'rootbound', label: 'Rootbound', emoji: '🔴', color: '#dc2626' },
]
</script>

<style scoped>
.tf__wrap { display: flex; flex-direction: column; gap: var(--sp-3); }
.tf__grid { display: grid; grid-template-columns: 1fr 1fr; gap: var(--sp-3); }
.tf__field { display: flex; flex-direction: column; gap: .3rem; }
.tf__field--full { grid-column: 1 / -1; }
.tf__label { font-size: .72rem; font-weight: 700; color: var(--c-ink-700); text-transform: uppercase; letter-spacing: .04em; display: flex; align-items: baseline; gap: 4px; }
.tf__unit { font-size: .65rem; color: var(--c-ink-500); font-weight: 400; text-transform: none; letter-spacing: 0; }
.tf__req { color: var(--c-rust-600); font-weight: 700; }
.tf__optional { font-size: .65rem; font-weight: 500; color: var(--c-ink-500); text-transform: none; letter-spacing: 0; }
.tf__input { background: var(--c-ink-100); border: 1.5px solid var(--c-ink-300); border-radius: var(--r-md); padding: .5rem .75rem; font-size: var(--fs-14); color: var(--c-ink-900); width: 100%; box-sizing: border-box; }
.tf__input:focus { outline: none; border-color: var(--brand-primary); background: #fff; }
.tf__textarea { background: var(--c-ink-100); border: 1.5px solid var(--c-ink-300); border-radius: var(--r-md); padding: .5rem .75rem; font-size: var(--fs-14); color: var(--c-ink-900); width: 100%; box-sizing: border-box; resize: vertical; }
.tf__textarea:focus { outline: none; border-color: var(--brand-primary); background: #fff; }
.tf__current { background: var(--c-ink-100); border: 1.5px solid var(--c-ink-300); border-radius: var(--r-md); padding: .5rem .75rem; font-size: var(--fs-14); font-weight: 700; color: var(--c-ink-700); }
.tf__preview { display: flex; align-items: center; justify-content: center; gap: var(--sp-3); background: #fffbeb; border: 1.5px solid #fde68a; border-radius: var(--r-lg); padding: .75rem 1rem; }
.tf__prev-val { font-size: 1.3rem; font-weight: 800; color: #92400e; }
.tf__prev-val--dest { color: var(--brand-primary); }
.tf__prev-arrow { color: #d97706; font-size: 1rem; }
.tf__radios { display: flex; gap: var(--sp-2); flex-wrap: wrap; }
.tf__radios--wrap { flex-wrap: wrap; }
.tf__radio-btn { display: inline-flex; align-items: center; gap: var(--sp-2); padding: .4rem .85rem; border: 1.5px solid var(--c-ink-300); border-radius: var(--r-lg); font-size: var(--fs-13); color: var(--c-ink-700); background: #fff; cursor: pointer; transition: all .12s; font-weight: 500; }
.tf__radio-btn--sel { background: var(--c-leaf-50); border-color: var(--brand-primary); color: var(--brand-primary); font-weight: 700; }
</style>
