<template>
  <div class="ia">
    <div class="ia__modos">
      <button v-for="m in modos" :key="m.value" type="button" class="ia__modo"
              :class="{ 'ia__modo--on': modo === m.value }" @click="setModo(m.value)">{{ m.label }}</button>
    </div>

    <template v-if="modo === 'receta'">
      <div class="ia__grid">
        <label class="ia__field ia__field--full">
          <span class="ia__label">Receta de {{ usoLabel.toLowerCase() }}</span>
          <select class="ia__input" :value="modelValue.receta_id || ''" @change="patch({ receta_id: $event.target.value ? Number($event.target.value) : null, items: [] })">
            <option value="" disabled>{{ recetas.length ? 'Elegí una receta' : `Todavía no armaste recetas de ${usoLabel.toLowerCase()}` }}</option>
            <option v-for="r in recetas" :key="r.id" :value="r.id">{{ r.nombre }}</option>
          </select>
          <span v-if="!recetas.length" class="ia__hint">Se arman en {{ esPersonal ? 'Cultivo → Nutrientes y recetas' : 'Depósito → Recetas' }}, eligiendo «{{ usoLabel }}».</span>
        </label>
        <label class="ia__field">
          <span class="ia__label">{{ baseTitulo }} <span class="ia__unit">{{ baseUnidad }}</span></span>
          <input type="number" step="0.01" min="0" class="ia__input" :value="base ?? ''" :placeholder="baseDefault ?? ''"
                 @input="patch({ base: $event.target.value === '' ? null : Number($event.target.value), items: [] })" />
          <span v-if="baseAyuda" class="ia__hint">{{ baseAyuda }}</span>
        </label>
      </div>
    </template>

    <template v-else-if="modo === 'sueltos'">
      <label class="ia__field ia__field--full">
        <span class="ia__label">{{ esPersonal ? 'Producto' : 'Producto del depósito' }}</span>
        <select class="ia__input" value="" @change="agregar($event.target.value); $event.target.value = ''">
          <option value="" disabled>{{ insumos.length ? 'Agregar…' : (esPersonal ? 'Todavía no cargaste productos' : 'No hay insumos de cultivo en el depósito') }}</option>
          <option v-for="i in insumosLibres" :key="i.id" :value="i.id">{{ i.nombre }} · quedan {{ fmtNum(i.stock_actual) }} {{ unidadCorta(i.unidad_medida) }}</option>
        </select>
      </label>
    </template>

    <div v-if="modo !== 'ninguno' && lineas.length" class="ia__lineas">
      <div v-for="l in lineas" :key="l.insumo_id" class="ia__linea" :class="{ 'ia__linea--falta': l.faltante > 0 }">
        <div class="ia__linea-main">
          <span class="ia__linea-nombre">{{ l.nombre }}<span v-if="l.dosis" class="ia__linea-dosis"> · {{ fmtNum(l.dosis) }} {{ l.unidad_label }}</span></span>
          <span class="ia__linea-stock">quedan {{ fmtNum(l.stock_actual, 3) }} {{ unidadCorta(l.unidad_insumo) }}</span>
        </div>
        <div class="ia__linea-cant">
          <input type="number" step="0.001" min="0" class="ia__input ia__input--sm" :value="l.cantidad" :aria-label="`Cantidad de ${l.nombre}`"
                 @input="setCantidad(l.insumo_id, $event.target.value)" />
          <span class="ia__linea-unidad">{{ unidadCorta(l.unidad_insumo) }}</span>
          <button v-if="modo === 'sueltos'" type="button" class="ia__quitar" :aria-label="`Quitar ${l.nombre}`" @click="quitar(l.insumo_id)"><i class="bi bi-x"></i></button>
        </div>
        <div v-if="l.faltante > 0" class="ia__falta">
          Faltan {{ fmtNum(l.faltante, 3) }} {{ unidadCorta(l.unidad_insumo) }} en el {{ esPersonal ? 'stock' : 'depósito' }}.
          <div class="ia__falta-ops">
            <button type="button" class="ia__modo ia__modo--xs" :class="{ 'ia__modo--on': l.modo_faltante !== 'no_descontar' }" @click="setFaltante(l.insumo_id, 'descontar_disponible')">Descontar lo que hay</button>
            <button type="button" class="ia__modo ia__modo--xs" :class="{ 'ia__modo--on': l.modo_faltante === 'no_descontar' }" @click="setFaltante(l.insumo_id, 'no_descontar')">No descontar este</button>
          </div>
          <span class="ia__hint">Se registra igual: si la bolsa está en el galpón, cargá la compra después.</span>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
// Qué productos se usaron en algo que se le hace a la cama (top dress, mezcla, té, cobertura…).
// Con una receta del uso que corresponde, o productos sueltos, o nada del depósito. Descuenta y
// cuesta el BACKEND (`Nutricion::Aplicar`); acá se muestra la cuenta para poder corregirla. La
// conversión de unidades (g → kg) viene del backend en cada ítem (`factor`).
import { computed, ref, watch, onMounted } from 'vue'
import { listRecetas, listInsumos } from '../../lib/api.js'
import { lineasDeReceta, reglasSueloVivo, fmtNum, unidadCorta } from '../../lib/camas.js'
import { useUsoPersonal } from '../../composables/useUsoPersonal.js'

const props = defineProps({
  modelValue:  { type: Object, default: () => ({}) },
  // 'riego' (té) · 'top_dress' · 'mezcla' · null (sólo productos sueltos: cobertura, mulch…)
  uso:         { type: String, default: null },
  baseDefault: { type: Number, default: null },
  baseAyuda:   { type: String, default: null },
})
const emit = defineEmits(['update:modelValue', 'nutricion'])
const { esPersonal } = useUsoPersonal()
const reglas = reglasSueloVivo()

const usoLabel   = computed(() => reglas.usos_receta_labels[props.uso] || 'receta')
const baseUnidad = computed(() => reglas.base_unidad[props.uso] || '')
const baseTitulo = computed(() => ({ top_dress: 'Superficie alimentada', mezcla: 'Suelo de la cama', riego: 'Litros preparados' }[props.uso] || 'Cantidad'))

const modos = computed(() => [
  ...(props.uso ? [{ value: 'receta', label: '📋 Con receta' }] : []),
  { value: 'sueltos', label: '🧪 Productos sueltos' },
  { value: 'ninguno', label: 'Nada del depósito' },
])

const recetas = ref([])
const insumos = ref([])
onMounted(async () => {
  try {
    const [r, i] = await Promise.all([
      props.uso ? listRecetas(props.uso) : Promise.resolve({ data: [] }),
      listInsumos({ tipo: 'cultivo', activos: 'true' }),
    ])
    recetas.value = (r.data || []).filter(x => x.activa !== false)
    insumos.value = i.data?.insumos || i.data || []
  } catch { recetas.value = []; insumos.value = [] }
  if (!props.modelValue.modo) patch({ modo: recetas.value.length ? 'receta' : 'ninguno' })
})

function patch(c) { emit('update:modelValue', { ...props.modelValue, ...c }) }
const modo   = computed(() => props.modelValue.modo || 'ninguno')
const receta = computed(() => recetas.value.find(r => r.id === props.modelValue.receta_id) || null)
const base   = computed(() => props.modelValue.base ?? props.baseDefault)
const insumosLibres = computed(() => insumos.value.filter(i => !(props.modelValue.items || []).some(x => x.insumo_id === i.id)))

const lineas = computed(() => {
  if (modo.value === 'ninguno') return []
  return lineasDeReceta(modo.value === 'receta' ? receta.value : null, base.value, props.modelValue.items, insumos.value)
})

function setModo(m) { patch({ modo: m, items: [], receta_id: m === 'receta' ? props.modelValue.receta_id : null }) }
function agregar(id) {
  if (!id) return
  patch({ items: [...(props.modelValue.items || []), { insumo_id: Number(id), cantidad: null, modo_faltante: 'descontar_disponible' }] })
}
function quitar(id) { patch({ items: (props.modelValue.items || []).filter(x => x.insumo_id !== id) }) }
function upsert(id, cambios) {
  const items = [...(props.modelValue.items || [])]
  const i = items.findIndex(x => x.insumo_id === id)
  if (i === -1) items.push({ insumo_id: id, ...cambios })
  else items[i] = { ...items[i], ...cambios }
  patch({ items })
}
function setCantidad(id, v) { upsert(id, { cantidad: v === '' ? null : Number(v) }) }
function setFaltante(id, m) { upsert(id, { modo_faltante: m }) }

// Lo que viaja al backend como `nutricion` (null = nada del depósito).
watch([lineas, modo, base, () => props.modelValue.receta_id], () => {
  if (modo.value === 'ninguno' || !lineas.value.length) return emit('nutricion', null)
  emit('nutricion', {
    receta_id: modo.value === 'receta' ? props.modelValue.receta_id : null,
    base: base.value,
    litros: props.uso === 'riego' ? base.value : undefined,
    items: lineas.value.filter(l => l.cantidad != null && Number(l.cantidad) > 0)
                       .map(l => ({ insumo_id: l.insumo_id, cantidad: l.cantidad, modo_faltante: l.modo_faltante })),
  })
}, { deep: true, immediate: true })
</script>

<style scoped>
.ia { display: flex; flex-direction: column; gap: .75rem; }
.ia__modos { display: flex; flex-wrap: wrap; gap: .4rem; }
.ia__modo {
  padding: .4rem .8rem; border: 1.5px solid var(--c-slate-200); border-radius: var(--r-md);
  background: var(--c-slate-50); font-size: var(--fs-13); font-weight: 600; color: var(--c-slate-600); cursor: pointer;
}
.ia__modo--on { border-color: var(--c-leaf-700); background: var(--c-leaf-50); color: var(--c-leaf-800); }
.ia__modo--xs { padding: .25rem .55rem; font-size: var(--fs-12); }
.ia__grid { display: grid; grid-template-columns: 1fr 1fr; gap: .75rem; }
@media (max-width: 480px) { .ia__grid { grid-template-columns: 1fr; } }
.ia__field { display: flex; flex-direction: column; gap: .3rem; min-width: 0; }
.ia__field--full { grid-column: 1 / -1; }
.ia__label { font-size: var(--fs-12); font-weight: 700; color: var(--c-slate-700); text-transform: uppercase; letter-spacing: .04em; }
.ia__unit { text-transform: none; font-weight: 500; color: var(--c-slate-400); }
.ia__input {
  background: var(--c-slate-50); border: 1.5px solid var(--c-slate-200); border-radius: var(--r-md);
  padding: .55rem .75rem; font-size: var(--fs-14); color: var(--c-slate-900); width: 100%; box-sizing: border-box;
}
.ia__input:focus { outline: none; border-color: var(--c-leaf-700); background: var(--c-paper); }
.ia__input--sm { width: 90px; padding: .35rem .5rem; }
.ia__hint { font-size: var(--fs-12); color: var(--c-slate-500); }
.ia__lineas { display: flex; flex-direction: column; gap: .5rem; }
.ia__linea { border: 1px solid var(--c-slate-200); border-radius: var(--r-md); padding: .55rem .7rem; display: flex; flex-direction: column; gap: .4rem; }
.ia__linea--falta { border-color: var(--c-amber-500); background: var(--c-amber-100); }
.ia__linea-main { display: flex; justify-content: space-between; gap: .5rem; flex-wrap: wrap; }
.ia__linea-nombre { font-weight: 700; font-size: var(--fs-14); color: var(--c-slate-900); }
.ia__linea-dosis { font-weight: 500; color: var(--c-slate-500); }
.ia__linea-stock { font-size: var(--fs-12); color: var(--c-slate-500); }
.ia__linea-cant { display: flex; align-items: center; gap: .4rem; }
.ia__linea-unidad { font-size: var(--fs-13); color: var(--c-slate-600); }
.ia__quitar { background: none; border: none; color: var(--c-slate-500); cursor: pointer; font-size: 1.1rem; }
.ia__falta { font-size: var(--fs-13); color: var(--c-slate-700); display: flex; flex-direction: column; gap: .35rem; }
.ia__falta-ops { display: flex; flex-wrap: wrap; gap: .35rem; }
</style>
