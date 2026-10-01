<template>
  <div class="rpf">
    <div v-for="(f, i) in modelValue" :key="i" class="rpf__fila">
      <select class="rpf__select" :value="f.stock_id ?? ''" :aria-label="`Frasco ${i + 1}`" @change="cambiar(i, { stock_id: $event.target.value ? Number($event.target.value) : null })">
        <option value="">Frasco nuevo</option>
        <option v-for="c in disponiblesPara(i)" :key="c.id" :value="c.id">
          {{ c.numero_lote_producto || `Frasco #${c.id}` }}{{ c.descripcion ? ` · ${c.descripcion}` : '' }} · {{ num(c.cantidad) }} g{{ c.estado === 'agotado' || Number(c.cantidad) <= 0 ? ' (vacío)' : '' }}
        </option>
      </select>
      <input v-if="!f.stock_id" class="rpf__input rpf__input--nombre" type="text" maxlength="40" placeholder="Nombre: copones, bajos…"
             :value="f.descripcion || ''" :aria-label="`Nombre del frasco ${i + 1}`" @input="cambiar(i, { descripcion: $event.target.value })" />
      <div class="rpf__gramos">
        <input class="rpf__input rpf__input--g" type="number" min="0" step="0.1" placeholder="0"
               :value="f.gramos ?? ''" :aria-label="`Gramos del frasco ${i + 1}`"
               @input="cambiar(i, { gramos: $event.target.value === '' ? null : Number($event.target.value) })" />
        <span class="rpf__unidad">g</span>
      </div>
      <button v-if="modelValue.length > 2" type="button" class="rpf__quitar" :aria-label="`Quitar frasco ${i + 1}`" @click="quitar(i)">×</button>
    </div>

    <button v-if="modelValue.length < 10" type="button" class="rpf__link" @click="agregar">+ Otro frasco</button>

    <div class="rpf__total" :class="{ 'rpf__total--ok': cuadra, 'rpf__total--mal': !cuadra && repartido > 0 }">
      Repartido {{ num(repartido) }} de {{ num(pesoTotal) }} g
      <template v-if="!cuadra && falta > 0"> · faltan {{ num(falta) }} g</template>
      <template v-else-if="!cuadra && falta < 0"> · sobran {{ num(-falta) }} g</template>
    </div>
  </div>
</template>

<script setup>
// REPARTIR UN PESAJE EN VARIOS FRASCOS (Germán, 1-oct-2026): «el admin confirma y crea dos frascos,
// uno de bajos y uno de copones, y pone la cantidad de cada uno». Cada fila es un frasco —nuevo
// (con nombre) o uno del lote— y sus gramos; la suma tiene que dar el peso confirmado. El backend
// valida lo mismo (`PesajeManicura#normalizar_destinos`); acá sólo se arma y se muestra la cuenta.
import { computed } from 'vue'

const props = defineProps({
  // [{ stock_id: null | id, descripcion, gramos }]
  modelValue:   { type: Array, required: true },
  contenedores: { type: Array, default: () => [] },
  pesoTotal:    { type: Number, default: 0 },
})
const emit = defineEmits(['update:modelValue'])

const num = v => Number(v || 0).toLocaleString('es-AR', { maximumFractionDigits: 2 })
const repartido = computed(() => +props.modelValue.reduce((s, f) => s + (Number(f.gramos) || 0), 0).toFixed(2))
const falta     = computed(() => +(Number(props.pesoTotal || 0) - repartido.value).toFixed(2))
const cuadra    = computed(() => Math.abs(falta.value) < 0.01 && props.modelValue.every(f => Number(f.gramos) > 0))

// Un frasco existente no se elige dos veces.
function disponiblesPara(i) {
  const usados = new Set(props.modelValue.filter((f, j) => j !== i && f.stock_id).map(f => f.stock_id))
  return props.contenedores.filter(c => !usados.has(c.id))
}
function cambiar(i, cambios) { emit('update:modelValue', props.modelValue.map((f, j) => (j === i ? { ...f, ...cambios } : f))) }
function agregar() { emit('update:modelValue', [...props.modelValue, { stock_id: null, descripcion: '', gramos: null }]) }
function quitar(i) { emit('update:modelValue', props.modelValue.filter((_, j) => j !== i)) }

defineExpose({ cuadra })
</script>

<style scoped>
.rpf { display: flex; flex-direction: column; gap: .5rem; }
.rpf__fila { display: flex; flex-wrap: wrap; align-items: center; gap: .4rem; padding: .5rem; border: 1px solid var(--c-ink-100); border-radius: var(--r-md); background: #fff; }
.rpf__select, .rpf__input { background: var(--c-ink-100); border: 1.5px solid var(--c-ink-300); border-radius: var(--r-md); padding: .45rem .6rem; font-size: var(--fs-14); color: var(--c-ink-900); box-sizing: border-box; }
.rpf__select { flex: 1 1 180px; min-width: 0; }
.rpf__input--nombre { flex: 1 1 140px; min-width: 0; }
.rpf__gramos { display: flex; align-items: center; gap: .3rem; }
.rpf__input--g { width: 84px; text-align: right; }
.rpf__unidad { font-size: .8rem; color: var(--c-ink-500); }
.rpf__quitar { background: none; border: 0; color: var(--c-ink-500); font-size: 1.1rem; cursor: pointer; padding: 0 .3rem; }
.rpf__link { align-self: flex-start; background: none; border: 0; padding: 0; color: var(--brand-primary); font-size: .82rem; font-weight: 600; cursor: pointer; text-decoration: underline; }
.rpf__total { font-size: .82rem; font-weight: 600; color: var(--c-ink-700); }
.rpf__total--ok { color: var(--c-leaf-700); }
.rpf__total--mal { color: var(--c-amber-500); }
</style>
