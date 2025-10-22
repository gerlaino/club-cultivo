<!-- src/components/BrandLogo.vue -->
<template>
  <div class="d-flex align-items-center gap-2 user-select-none">
    <template v-if="logoToShow">
      <img
        :src="logoToShow"
        :alt="name"
        class="brand-logo"
        @error="onImgError"
      />
    </template>
    <template v-else>
      <span class="logo-dot"></span>
    </template>

    <strong class="brand-name">{{ name }}</strong>
  </div>
</template>

<script setup>
import { ref, computed } from "vue"
import { useClubStore } from "../stores/club"

const club = useClubStore()

// Si el logo falla, ocultamos imagen y usamos el fallback
const broken = ref(false)
const logoToShow = computed(() => (broken.value ? "" : (club.logoUrl || "")))

function onImgError() {
  broken.value = true
}

// Nombre visible del club (o genérico)
const name = computed(() => club.name || "Cultivo Espacial")
</script>

<style scoped>
/* Tamaño y estilo del logo circular */
.brand-logo {
  width: 1.25rem;
  height: 1.25rem;
  border-radius: 50%;
  object-fit: cover;
  box-shadow: 0 0 0 3px color-mix(in srgb, var(--brand-primary, #2e7d32) 25%, transparent);
}

/* Puntito verde (fallback si no hay logo) */
.logo-dot {
  width: 0.75rem;
  height: 0.75rem;
  display: inline-block;
  border-radius: 50%;
  background: var(--brand-primary, #2e7d32);
  box-shadow: 0 0 0 3px color-mix(in srgb, var(--brand-primary, #2e7d32) 25%, transparent);
}

/* Nombre del club */
.brand-name {
  font-size: 1.05rem;
}
</style>
