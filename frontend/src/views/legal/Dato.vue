<template>
  <span v-if="v">{{ v }}</span>
  <span v-else class="lg-pendiente">[a completar]</span>
</template>

<script setup>
// Un dato del titular (ver `titular.js`): si todavía no está definido, se ve marcado y no se inventa.
defineProps({ v: { type: String, default: null } })
</script>
