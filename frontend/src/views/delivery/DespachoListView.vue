<template>
  <div class="dlv-list">
    <div class="dlv-list__header">
      <h1 class="dlv-list__title"><PackageCheck :size="20" :stroke-width="1.75" /> Despachos</h1>
    </div>

    <div class="dlv-list__empty">
      <PackageCheck :size="40" :stroke-width="1.25" />
      <p>Módulo de despachos próximamente.</p>
    </div>
  </div>
</template>

<script setup>
import { PackageCheck } from 'lucide-vue-next'
</script>

<style scoped>
.dlv-list { padding: var(--sp-6); max-width: 900px; }
.dlv-list__header { margin-bottom: var(--sp-5); }
.dlv-list__title { font-size: var(--fs-20); font-weight: 700; color: var(--c-ink-900); display: flex; align-items: center; gap: var(--sp-2); margin: 0; }
.dlv-list__empty { display: flex; flex-direction: column; align-items: center; gap: var(--sp-3); padding: var(--sp-10); color: var(--c-ink-400); text-align: center; }
.dlv-list__empty p { font-size: var(--fs-15); margin: 0; }
</style>
