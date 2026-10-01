<template>
  <div class="rpp">
    <div v-for="(t, i) in tandas" :key="i" class="rpp__tanda">
      <div class="rpp__tanda-head">
        <span class="rpp__tanda-titulo">Tanda {{ i + 1 }}</span>
        <button v-if="tandas.length > 1" type="button" class="rpp__quitar" :aria-label="`Quitar tanda ${i + 1}`" @click="quitarTanda(i)"><i class="bi bi-x"></i></button>
      </div>

      <div class="rpp__plantas">
        <label v-for="p in disponiblesPara(i)" :key="p.id" class="rpp__planta" :class="{ 'rpp__planta--sel': t.plant_ids.includes(p.id) }">
          <input type="checkbox" class="rpp__check" :checked="t.plant_ids.includes(p.id)" @change="togglePlanta(i, p.id)" />
          {{ etiqueta(p) }}
        </label>
        <p v-if="!disponiblesPara(i).length" class="rpp__hint">No quedan plantas sin tanda.</p>
      </div>
      <button v-if="disponiblesPara(i).length > 1" type="button" class="rpp__link" @click="todasLasQuedan(i)">Elegir las que quedan</button>

      <div class="rpp__cantidad">
        <input type="number" step="0.5" min="0" class="rpp__input" :value="t.cantidad ?? ''" :aria-label="`Cantidad de la tanda ${i + 1}`"
               placeholder="1" @input="setTanda(i, { cantidad: $event.target.value === '' ? null : Number($event.target.value) })" />
        <div class="rpp__unidades">
          <button v-for="u in UNIDADES" :key="u.value" type="button" class="rpp__unidad" :class="{ 'rpp__unidad--sel': t.unidad === u.value }"
                  @click="setTanda(i, { unidad: u.value })">{{ u.label }}</button>
        </div>
        <span class="rpp__por-planta">por planta</span>
      </div>
    </div>

    <button v-if="quedanSinTanda" type="button" class="rpp__link" @click="agregarTanda">+ Otra tanda</button>

    <div v-if="usaPulsos" class="rpp__pulso">
      <label class="rpp__label" for="rpp-lpp">1 pulso =</label>
      <input id="rpp-lpp" type="number" step="0.05" min="0" class="rpp__input rpp__input--sm" :value="modelValue.litros_por_pulso ?? ''"
             @input="emitir({ litros_por_pulso: $event.target.value === '' ? null : Number($event.target.value) })" />
      <span class="rpp__unidad-txt">L</span>
    </div>

    <div class="rpp__total">
      {{ regadas }} de {{ plantas.length }} plantas<template v-if="total != null"> · {{ num(total) }} L en total</template>
    </div>
  </div>
</template>

<script setup>
// EL RIEGO POR PLANTA (Germán, 30-sep-2026): «elegir qué planta del lote fue regada, como en la
// cosecha o el pesaje de la manicura; en ciertas plantas 1 pulso, en ciertas otras 2». Tandas:
// un grupo de plantas y cuánto recibió CADA una, en litros o en pulsos (con cuántos litros es
// un pulso). Cada planta en una sola tanda. El backend (`Riegos::PorPlanta`) guarda una fila por
// planta y el volumen del lote es la suma; este componente sólo arma las tandas y muestra el total.
import { computed, watch } from 'vue'

const props = defineProps({
  // { tandas: [{ plant_ids, cantidad, unidad }], litros_por_pulso }
  modelValue: { type: Object, required: true },
  // Las plantas en pie del lote.
  plantas:    { type: Array,  default: () => [] },
})
const emit = defineEmits(['update:modelValue'])

const UNIDADES = [
  { value: 'pulsos', label: 'pulsos' },
  { value: 'litros', label: 'L' },
]

const tandas = computed(() => props.modelValue.tandas || [])
const num = v => Number(v).toLocaleString('es-AR', { maximumFractionDigits: 2 })
const etiqueta = p => p.nombre || p.codigo_qr || `Planta #${p.id}`

function emitir(cambios) { emit('update:modelValue', { ...props.modelValue, ...cambios }) }
function setTandas(ts) { emitir({ tandas: ts }) }
function setTanda(i, cambios) { setTandas(tandas.value.map((t, j) => (j === i ? { ...t, ...cambios } : t))) }

const enOtra = (i) => new Set(tandas.value.flatMap((t, j) => (j === i ? [] : t.plant_ids)))
function disponiblesPara(i) { const otras = enOtra(i); return props.plantas.filter(p => !otras.has(p.id)) }
function togglePlanta(i, id) {
  const ids = tandas.value[i].plant_ids
  setTanda(i, { plant_ids: ids.includes(id) ? ids.filter(x => x !== id) : [...ids, id] })
}
function todasLasQuedan(i) { setTanda(i, { plant_ids: disponiblesPara(i).map(p => p.id) }) }
function agregarTanda() {
  const ultima = tandas.value.at(-1)
  setTandas([...tandas.value, { plant_ids: [], cantidad: null, unidad: ultima?.unidad || 'pulsos' }])
}
function quitarTanda(i) { setTandas(tandas.value.filter((_, j) => j !== i)) }

const regadas = computed(() => tandas.value.reduce((n, t) => n + t.plant_ids.length, 0))
const quedanSinTanda = computed(() => regadas.value < props.plantas.length && tandas.value.every(t => t.plant_ids.length))
const usaPulsos = computed(() => tandas.value.some(t => t.unidad === 'pulsos'))

// Litros por planta de una tanda; null si todavía no se puede saber.
function litrosPorPlanta(t) {
  if (!(Number(t.cantidad) > 0)) return null
  if (t.unidad === 'litros') return Number(t.cantidad)
  const lpp = Number(props.modelValue.litros_por_pulso)
  return lpp > 0 ? Number(t.cantidad) * lpp : null
}
const total = computed(() => {
  const conPlantas = tandas.value.filter(t => t.plant_ids.length)
  if (!conPlantas.length) return null
  const partes = conPlantas.map(t => litrosPorPlanta(t))
  if (partes.some(x => x == null)) return null
  return +conPlantas.reduce((s, t, k) => s + partes[k] * t.plant_ids.length, 0).toFixed(2)
})
// El total viaja en el modelo (`total_l`): es el volumen del riego que ve el resto del formulario.
watch(total, (v) => { if (props.modelValue.total_l !== v) emitir({ total_l: v }) }, { immediate: true })
</script>

<style scoped>
.rpp { display: flex; flex-direction: column; gap: var(--sp-2); }
.rpp__tanda { background: #fff; border: 1px solid var(--c-ink-100); border-radius: var(--r-md); padding: .6rem .7rem; display: flex; flex-direction: column; gap: .45rem; }
.rpp__tanda-head { display: flex; align-items: center; justify-content: space-between; }
.rpp__tanda-titulo { font-size: .72rem; font-weight: 700; color: var(--c-ink-700); text-transform: uppercase; letter-spacing: .04em; }
.rpp__quitar { background: none; border: 0; color: var(--c-ink-500); cursor: pointer; font-size: 1rem; }
.rpp__plantas { display: flex; flex-wrap: wrap; gap: .35rem; }
.rpp__planta { display: inline-flex; align-items: center; gap: .3rem; padding: .3rem .55rem; border: 1.5px solid var(--c-ink-300); border-radius: 99px; font-size: .8rem; color: var(--c-ink-700); cursor: pointer; }
.rpp__planta--sel { background: var(--brand-primary); border-color: var(--brand-primary); color: #fff; font-weight: 600; }
.rpp__check { position: absolute; opacity: 0; width: 0; height: 0; }
.rpp__cantidad { display: flex; align-items: center; flex-wrap: wrap; gap: .45rem; }
.rpp__input { background: var(--c-ink-100); border: 1.5px solid var(--c-ink-300); border-radius: var(--r-md); padding: .4rem .6rem; font-size: var(--fs-14); color: var(--c-ink-900); width: 84px; box-sizing: border-box; }
.rpp__input:focus { outline: none; border-color: var(--brand-primary); background: #fff; }
.rpp__input--sm { width: 72px; }
.rpp__unidades { display: inline-flex; gap: .25rem; }
.rpp__unidad { padding: .3rem .6rem; border: 1.5px solid var(--c-ink-300); border-radius: var(--r-md); background: #fff; font-size: .78rem; color: var(--c-ink-700); cursor: pointer; }
.rpp__unidad--sel { background: var(--brand-primary); border-color: var(--brand-primary); color: #fff; font-weight: 600; }
.rpp__por-planta, .rpp__unidad-txt { font-size: .76rem; color: var(--c-ink-500); }
.rpp__pulso { display: flex; align-items: center; gap: .45rem; }
.rpp__label { font-size: .78rem; font-weight: 600; color: var(--c-ink-700); }
.rpp__link { align-self: flex-start; background: none; border: 0; padding: 0; color: var(--brand-primary); font-size: .78rem; font-weight: 600; cursor: pointer; text-decoration: underline; }
.rpp__hint { font-size: .74rem; color: var(--c-ink-500); margin: 0; }
.rpp__total { font-size: .78rem; color: var(--c-ink-700); font-weight: 600; text-align: right; }
</style>
