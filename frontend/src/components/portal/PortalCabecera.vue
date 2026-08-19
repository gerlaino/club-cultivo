<template>
  <header class="pca">
    <RouterLink v-if="volverA" :to="volverA" class="pca__volver">
      <ArrowLeft :size="14" :stroke-width="1.75" /> {{ volverTxt }}
    </RouterLink>
    <h1 class="pca__t">{{ titulo }}</h1>
    <p v-if="bajada" class="pca__b">{{ bajada }}</p>
  </header>
</template>

<script setup>
// La cabecera de una sección del portal. Existe para que las ocho pantallas arranquen igual: sin
// esto, cada una elegía su tamaño de título y su color, que es exactamente cómo el portal terminó
// con ocho verdes distintos.
import { ArrowLeft } from 'lucide-vue-next'

defineProps({
  titulo:    { type: String, required: true },
  bajada:    { type: String, default: '' },
  volverA:   { type: String, default: '' },
  volverTxt: { type: String, default: 'Volver' },
})
</script>

<style scoped>
.pca { margin-bottom: var(--sp-6); }
.pca__volver {
  display: inline-flex; align-items: center; gap: var(--sp-1);
  font-size: var(--fs-13); font-weight: 600; color: var(--p-marca);
  text-decoration: none; margin-bottom: var(--sp-3);
}
.pca__volver:hover { text-decoration: underline; }
.pca__t {
  font-family: var(--p-display);
  font-size: var(--fs-24); font-weight: 600; letter-spacing: -.02em;
  margin: 0 0 var(--sp-1); text-wrap: balance;
}
.pca__b { color: var(--p-suave); margin: 0; line-height: var(--lh-base); }

@media (min-width: 640px) { .pca__t { font-size: var(--fs-32); } }
</style>
