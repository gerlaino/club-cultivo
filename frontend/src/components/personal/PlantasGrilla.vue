<template>
  <!-- Las plantas de un espacio, en tarjetas: nombre, auto/foto, en qué día va y qué le toca.
       La usan «Mi cultivo» y la ficha del espacio en el autocultivo: una sola manera de mostrar
       una planta, para que las dos pantallas no digan distinto. -->
  <div class="pgr">
    <RouterLink v-for="p in tarjetas" :key="p.id" :to="`/plantas/${p.id}`" class="pgr__planta">
      <span class="pgr__top">
        <strong>{{ p.nombre }}</strong>
        <span class="pgr__chip" :class="p.auto ? 'pgr__chip--auto' : 'pgr__chip--foto'">{{ p.auto ? 'Auto' : 'Foto' }}</span>
      </span>
      <span class="pgr__l">{{ p.genetica }} · {{ p.dia }}</span>
      <span v-if="p.pct != null" class="pgr__barra"><span :style="{ width: `${p.pct}%` }"></span></span>
      <span v-if="p.toca" class="pgr__toca">{{ p.toca }}</span>
    </RouterLink>
  </div>
</template>

<script setup>
import { computed } from 'vue'
import { textoProximoPasoCorto, estadoPlantaLabel } from '../../lib/loteHelpers.js'

const props = defineProps({
  // Las plantas tal como vienen de `listPlants` (con `lote.id`).
  plantas: { type: Array, required: true },
  // Los lotes de esas plantas (de `listLotes`): de ahí salen el reloj de las autos y el próximo paso.
  lotes:   { type: Array, default: () => [] },
})

const lotePorId = computed(() => Object.fromEntries(props.lotes.map(l => [l.id, l])))

function tarjeta(p) {
  const l = lotePorId.value[p.lote?.id] || {}
  const auto = !!l.automatica
  const obj = l.dias_ciclo_objetivo
  const dia = auto && l.dias_ciclo != null
    ? `día ${l.dias_ciclo}${obj ? ` de ${obj}` : ''}`
    : `${estadoPlantaLabel(p).toLowerCase()}${p.dias_en_fase != null ? ` · día ${p.dias_en_fase}` : ''}`
  const pct = auto && l.dias_ciclo != null && obj ? Math.min(100, Math.round(l.dias_ciclo / obj * 100)) : null
  return { id: p.id, nombre: p.nombre, genetica: p.genetica?.nombre || l.genetica?.nombre || 'Sin genética', auto, dia, pct, toca: textoProximoPasoCorto(l) }
}
const tarjetas = computed(() => props.plantas.map(tarjeta))
</script>

<style scoped>
.pgr { display: grid; grid-template-columns: repeat(auto-fill, minmax(190px, 1fr)); gap: var(--sp-2); }
.pgr__planta { border: 1px solid var(--c-leaf-100); border-radius: 12px; padding: var(--sp-3); display: flex; flex-direction: column; gap: 5px; text-decoration: none; color: var(--c-ink-900); background: var(--c-paper); }
.pgr__planta:hover { border-color: var(--c-leaf-300); }
.pgr__top { display: flex; align-items: center; justify-content: space-between; gap: 6px; }
.pgr__l { font-size: var(--fs-12); color: var(--c-ink-700); }
.pgr__toca { font-size: var(--fs-12); font-weight: 600; color: var(--c-gold-500); }
.pgr__barra { height: 6px; border-radius: 3px; background: var(--c-leaf-100); overflow: hidden; }
.pgr__barra span { display: block; height: 100%; background: var(--c-leaf-700); }
.pgr__chip { font-size: 11px; font-weight: 700; padding: 2px 8px; border-radius: 999px; }
.pgr__chip--auto { background: var(--c-amber-100); color: var(--c-gold-500); }
.pgr__chip--foto { background: var(--c-leaf-100); color: var(--c-leaf-800); }
</style>
