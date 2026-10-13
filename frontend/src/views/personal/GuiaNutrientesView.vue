<template>
  <div class="gnv">
    <!-- Guía de nutrientes del autocultivo (compu y teléfono). La lógica vive en el componente. -->
    <header>
      <h1 class="gnv__t">Guía de nutrientes</h1>
      <p class="gnv__p">Qué usa la planta en cada fase y en qué rangos moverse. Una referencia, no una receta.</p>
    </header>
    <GuiaNutrientes />
  </div>
</template>

<script setup>
import GuiaNutrientes from '../../components/personal/GuiaNutrientes.vue'
</script>

<style scoped>
/* Centrada y con las medidas de «Nutrientes y recetas», que está al lado en el menú. */
.gnv { padding: var(--sp-6) var(--sp-8); display: flex; flex-direction: column; gap: var(--sp-5); max-width: 880px; width: 100%; margin: 0 auto; box-sizing: border-box; }
.gnv__t { margin: 0 0 .2rem; font-size: var(--fs-24); font-weight: 800; letter-spacing: -.03em; color: var(--c-ink-900); }
.gnv__p { margin: 0; color: var(--c-ink-500); font-size: var(--fs-14); line-height: 1.5; max-width: 60ch; }
@media (max-width: 640px) { .gnv { padding: 16px 16px 32px; } .gnv__t { font-size: var(--fs-20); } }
</style>
