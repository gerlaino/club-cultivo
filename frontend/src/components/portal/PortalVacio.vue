<template>
  <div class="pva">
    <LeafHerbarium :size="38" class="pva__ico" />
    <h2 class="pva__t">{{ titulo }}</h2>
    <p class="pva__b">{{ texto }}</p>
    <RouterLink v-if="haciaA" :to="haciaA" class="pva__bt">{{ haciaTxt }}</RouterLink>
  </div>
</template>

<script setup>
// El estado vacío del portal, que es el riesgo real de una portada editorial: una organización
// nueva no tiene nada publicado, y el portal es lo PRIMERO que su gente va a ver. Un hueco con
// "no hay nada" es peor que no tener la sección.
import LeafHerbarium from '@/design-system/icons/LeafHerbarium.vue'

defineProps({
  titulo:   { type: String, required: true },
  texto:    { type: String, default: '' },
  haciaA:   { type: String, default: '' },
  haciaTxt: { type: String, default: '' },
})
</script>

<style scoped>
.pva { text-align: center; padding: var(--sp-12) var(--sp-4); }
.pva__ico { color: var(--p-marca-linea); margin-bottom: var(--sp-3); }
.pva__t { font-family: var(--p-display); font-size: var(--fs-18); font-weight: 600; margin: 0 0 var(--sp-2); }
.pva__b { color: var(--p-suave); margin: 0 auto; max-width: 42ch; line-height: var(--lh-base); }
.pva__bt {
  display: inline-block; margin-top: var(--sp-5);
  background: var(--p-marca); color: #fff; text-decoration: none;
  font-size: var(--fs-14); font-weight: 600;
  padding: var(--sp-2) var(--sp-5); border-radius: var(--r-pill);
}
</style>
