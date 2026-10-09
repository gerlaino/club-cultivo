<template>
  <!-- «Mis informes» del autocultivo en la compu. La lógica vive en el componente: el teléfono
       usa el mismo, en tarjetas. -->
  <div class="mie">
    <header>
      <h1 class="mie__t">Mis informes</h1>
      <p class="mie__p">Lo que ves es lo que se descarga: mismo período, mismos números.</p>
    </header>
    <MisInformes variante="escritorio" />
  </div>
</template>

<script setup>
import MisInformes from '../../components/personal/MisInformes.vue'
</script>

<style scoped>
.mie { padding: var(--sp-6) var(--sp-8); display: flex; flex-direction: column; gap: var(--sp-5); max-width: 1280px; }
.mie__t { margin: 0; font-size: var(--fs-32); font-weight: 800; letter-spacing: -.02em; color: var(--c-ink-900); }
.mie__p { margin: 2px 0 0; color: var(--c-ink-700); }
</style>
