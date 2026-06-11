<template>
  <div class="pf__wrap">
    <div class="pf__field">
      <label class="pf__label">Tipo de poda</label>
      <div class="pf__chips">
        <button v-for="t in TIPOS_PODA" :key="t" type="button"
                class="pf__chip" :class="{ 'pf__chip--sel': f.tipos?.includes(t) }"
                @click="toggleTipo(t)">{{ t }}</button>
      </div>
    </div>

    <div class="pf__field">
      <label class="pf__label">Intensidad</label>
      <div class="pf__radios">
        <button v-for="i in INTENSIDADES" :key="i.value" type="button"
                class="pf__radio-btn" :class="{ 'pf__radio-btn--sel': f.intensidad === i.value }"
                @click="f.intensidad = i.value">
          <span>{{ i.emoji }}</span> {{ i.label }}
        </button>
      </div>
    </div>

    <div class="pf__grid">
      <div class="pf__field">
        <label class="pf__label">Plantas intervenidas</label>
        <input type="number" step="1" min="0" class="pf__input" v-model.number="f.plantas_intervenidas" :placeholder="totalPlantas || '0'" />
      </div>
    </div>

    <div class="pf__field pf__field--full">
      <label class="pf__label">Observaciones <span class="pf__optional">opcional</span></label>
      <textarea class="pf__textarea" rows="2" v-model.trim="f.observaciones" placeholder="Defoliación agresiva día 21 de floración…"></textarea>
    </div>
  </div>
</template>

<script setup>
import { computed } from 'vue'

const props = defineProps({
  modelValue:  { type: Object, default: () => ({}) },
  totalPlantas:{ type: Number, default: null },
})
const emit = defineEmits(['update:modelValue'])
const f = computed({
  get: () => props.modelValue,
  set: v => emit('update:modelValue', v),
})

const TIPOS_PODA = ['Apical/Topping', 'Defoliación', 'Lollipopping', 'Schwazzing', 'LST', 'SCROG', 'Pinzado']
const INTENSIDADES = [
  { value: 'leve',    label: 'Leve',     emoji: '🟢' },
  { value: 'moderada',label: 'Moderada', emoji: '🟡' },
  { value: 'agresiva',label: 'Agresiva', emoji: '🔴' },
]

function toggleTipo(t) {
  const cur = f.value.tipos || []
  const idx = cur.indexOf(t)
  emit('update:modelValue', { ...f.value, tipos: idx === -1 ? [...cur, t] : cur.filter(x => x !== t) })
}
</script>

<style scoped>
.pf__wrap { display: flex; flex-direction: column; gap: var(--sp-3); }
.pf__field { display: flex; flex-direction: column; gap: .3rem; }
.pf__field--full { grid-column: 1 / -1; }
.pf__grid { display: grid; grid-template-columns: 1fr 1fr; gap: var(--sp-3); }
.pf__label { font-size: .72rem; font-weight: 700; color: var(--c-ink-700); text-transform: uppercase; letter-spacing: .04em; }
.pf__optional { font-size: .65rem; font-weight: 500; color: var(--c-ink-500); text-transform: none; letter-spacing: 0; }
.pf__input { background: var(--c-ink-100); border: 1.5px solid var(--c-ink-300); border-radius: var(--r-md); padding: .5rem .75rem; font-size: var(--fs-14); color: var(--c-ink-900); width: 100%; box-sizing: border-box; }
.pf__input:focus { outline: none; border-color: var(--brand-primary); background: #fff; }
.pf__textarea { background: var(--c-ink-100); border: 1.5px solid var(--c-ink-300); border-radius: var(--r-md); padding: .5rem .75rem; font-size: var(--fs-14); color: var(--c-ink-900); width: 100%; box-sizing: border-box; resize: vertical; }
.pf__textarea:focus { outline: none; border-color: var(--brand-primary); background: #fff; }
.pf__chips { display: flex; flex-wrap: wrap; gap: var(--sp-2); }
.pf__chip { padding: .35rem .75rem; border: 1.5px solid var(--c-ink-300); border-radius: var(--r-pill); font-size: var(--fs-13); color: var(--c-ink-700); background: #fff; cursor: pointer; transition: all .12s; font-weight: 500; }
.pf__chip:hover { border-color: var(--brand-primary); color: var(--brand-primary); }
.pf__chip--sel { background: var(--c-leaf-50); border-color: var(--brand-primary); color: var(--brand-primary); font-weight: 700; }
.pf__radios { display: flex; gap: var(--sp-2); flex-wrap: wrap; }
.pf__radio-btn { display: inline-flex; align-items: center; gap: var(--sp-2); padding: .4rem .85rem; border: 1.5px solid var(--c-ink-300); border-radius: var(--r-lg); font-size: var(--fs-13); color: var(--c-ink-700); background: #fff; cursor: pointer; transition: all .12s; font-weight: 500; }
.pf__radio-btn:hover { border-color: var(--brand-primary); }
.pf__radio-btn--sel { background: var(--c-leaf-50); border-color: var(--brand-primary); color: var(--brand-primary); font-weight: 700; }
</style>
