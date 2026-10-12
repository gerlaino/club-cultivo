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
.gnv { padding: var(--sp-6) var(--sp-8); display: flex; flex-direction: column; gap: var(--sp-5); max-width: 960px; }
.gnv__t { margin: 0; font-size: var(--fs-32); font-weight: 800; letter-spacing: -.02em; color: var(--c-ink-900); }
.gnv__p { margin: 2px 0 0; color: var(--c-ink-700); }
@media (max-width: 640px) { .gnv { padding: 16px 16px 32px; } .gnv__t { font-size: 1.6rem; } }
</style>
