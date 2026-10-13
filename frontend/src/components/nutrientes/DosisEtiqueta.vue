<template>
  <fieldset class="de">
    <legend class="de__titulo">Etiqueta y medida casera <span class="de__opt">opcional</span></legend>
    <p class="de__ayuda">
      Con esto, cuando dictás «le puse {{ nombre || 'este producto' }}» se calcula solo cuánto usaste.
      La dosis la copiás de la etiqueta de tu producto.
    </p>

    <div class="de__fila">
      <label class="de__campo">
        <span class="de__label">Medida casera</span>
        <input :value="modelValue.medida_casera || ''" class="de__input" placeholder="pulso, tapita, cucharita"
               maxlength="30" @input="set('medida_casera', $event.target.value)" />
      </label>
      <label class="de__campo">
        <span class="de__label">1 {{ medida || 'medida' }} son ({{ chica }})</span>
        <input :value="modelValue.medida_casera_cantidad ?? ''" type="number" min="0" step="0.1" class="de__input"
               placeholder="1" @input="setNum('medida_casera_cantidad', $event.target.value)" />
      </label>
    </div>

    <label class="de__campo">
      <span class="de__label">La etiqueta dice</span>
      <select :value="modelValue.dosis_unidad || ''" class="de__input" @change="set('dosis_unidad', $event.target.value)">
        <option value="">— sin dosis cargada —</option>
        <option v-for="o in opciones" :key="o.value" :value="o.value">{{ o.label }}</option>
      </select>
    </label>

    <div v-if="modelValue.dosis_unidad" class="de__fila de__fila--3">
      <label v-for="f in FASES" :key="f.key" class="de__campo">
        <span class="de__label">{{ f.label }}</span>
        <input :value="modelValue[`dosis_${f.key}`] ?? ''" type="number" min="0" step="0.1" class="de__input"
               :aria-label="`Dosis en ${f.label}`" @input="setNum(`dosis_${f.key}`, $event.target.value)" />
      </label>
    </div>
    <span v-if="modelValue.dosis_unidad?.startsWith('medida_') && !modelValue.medida_casera_cantidad" class="de__aviso">
      Para dosificar en {{ medida ? plural(medida) : 'medidas caseras' }}, cargá cuánto es 1 {{ medida || 'medida' }}.
    </span>
  </fieldset>
</template>

<script setup>
// La dosis de la ETIQUETA y la medida casera de un nutriente (13-oct-2026). La cuenta la hace el
// backend (`Nutricion::Dosis`); acá sólo se cargan los datos. Las unidades son las de
// `Insumo::DOSIS_UNIDADES`: «qué» (ml, g o la medida casera) por «cada qué» (litro o planta).
import { computed } from 'vue'

const props = defineProps({
  modelValue:   { type: Object, required: true },
  // 'mililitro' | 'litro' | 'gramo' | 'kilogramo': de eso sale si se dosifica en ml o en g.
  unidadMedida: { type: String, default: 'mililitro' },
  nombre:       { type: String, default: '' },
})
const emit = defineEmits(['update:modelValue'])

const FASES = [
  { key: 'enraizado',  label: 'Enraizado' },
  { key: 'vegetativo', label: 'Vegetativo' },
  { key: 'floracion',  label: 'Floración' },
]

const solido = computed(() => ['gramo', 'kilogramo'].includes(props.unidadMedida))
const chica  = computed(() => (solido.value ? 'g' : 'ml'))
const medida = computed(() => (props.modelValue.medida_casera || '').trim())
const plural = (m) => (m.endsWith('s') ? m : `${m}s`)

const opciones = computed(() => {
  const base = solido.value
    ? [{ value: 'g_litro', label: 'gramos por litro de agua' }, { value: 'g_planta', label: 'gramos por planta' }]
    : [{ value: 'ml_litro', label: 'ml por litro de agua' }, { value: 'ml_planta', label: 'ml por planta' }]
  const m = medida.value
  if (!m) return base
  return [...base,
    { value: 'medida_litro', label: `${plural(m)} por litro de agua` },
    { value: 'medida_planta', label: `${plural(m)} por planta` }]
})

function set (k, v) { emit('update:modelValue', { ...props.modelValue, [k]: v }) }
function setNum (k, v) { set(k, v === '' ? null : Number(v)) }
</script>

<style scoped>
.de { border: 1px solid var(--c-slate-200); border-radius: var(--r-md, 10px); padding: .75rem .9rem; margin: .25rem 0 0; display: flex; flex-direction: column; gap: .6rem; }
.de__titulo { padding: 0 .3rem; font-size: var(--fs-13); font-weight: 700; color: var(--c-ink-900); }
.de__opt { font-weight: 500; color: var(--c-ink-500); }
.de__ayuda { margin: 0; font-size: var(--fs-12); color: var(--c-ink-500); }
.de__fila { display: grid; grid-template-columns: 1fr 1fr; gap: .6rem; }
.de__fila--3 { grid-template-columns: repeat(3, 1fr); }
.de__campo { display: flex; flex-direction: column; gap: .25rem; min-width: 0; }
.de__label { font-size: var(--fs-12); font-weight: 600; color: var(--c-ink-700); }
.de__input { padding: .45rem .6rem; border: 1px solid var(--c-slate-200); border-radius: 8px; font: inherit; font-size: var(--fs-14); min-width: 0; }
.de__aviso { font-size: var(--fs-12); color: var(--c-amber-500); }
@media (max-width: 480px) { .de__fila--3 { grid-template-columns: 1fr 1fr; } }
</style>
