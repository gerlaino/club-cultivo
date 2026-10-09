<template>
  <!-- «Mis informes» en el teléfono: una tarjeta por informe, con PDF y Excel. -->
  <div class="mpi">
    <h1 class="mpi__t">Mis informes</h1>
    <MisInformes variante="telefono" />
  </div>
</template>

<script setup>
import MisInformes from '../../components/personal/MisInformes.vue'
</script>

<style scoped>
.mpi { padding: 16px 16px 32px; display: flex; flex-direction: column; gap: 14px; }
.mpi__t { margin: 0; font-size: 1.6rem; font-weight: 800; letter-spacing: -.02em; color: var(--c-ink-900); }
</style>
