<template>
  <svg
    :width="size"
    :height="size"
    viewBox="0 0 24 24"
    xmlns="http://www.w3.org/2000/svg"
    :style="tone !== 'currentColor' ? { color: tone } : {}"
    aria-hidden="true"
  >
    <!-- ── Contornos de foliolos (stroke, fill none) ── -->

    <!-- Foliolo central -->
    <path
      d="M 12,14 C 10.4,10 10.4,5 12,1.5 C 13.6,5 13.6,10 12,14 Z"
      fill="none"
      stroke="currentColor"
      stroke-width="1.5"
      stroke-linejoin="round"
    />
    <!-- Foliolo superior izquierdo -->
    <path
      d="M 12,14 C 10.45,11.5 6.7,7 4.5,5 C 6.05,7.5 9.8,12 12,14 Z"
      fill="none"
      stroke="currentColor"
      stroke-width="1.5"
      stroke-linejoin="round"
    />
    <!-- Foliolo superior derecho -->
    <path
      d="M 12,14 C 13.55,11.5 17.3,7 19.5,5 C 17.95,7.5 14.2,12 12,14 Z"
      fill="none"
      stroke="currentColor"
      stroke-width="1.5"
      stroke-linejoin="round"
    />
    <!-- Foliolo inferior izquierdo -->
    <path
      d="M 12,14 C 9.8,13 5.3,11.5 3,11 C 5.2,12 9.7,13.5 12,14 Z"
      fill="none"
      stroke="currentColor"
      stroke-width="1.5"
      stroke-linejoin="round"
    />
    <!-- Foliolo inferior derecho -->
    <path
      d="M 12,14 C 14.2,13 18.7,11.5 21,11 C 18.8,12 14.3,13.5 12,14 Z"
      fill="none"
      stroke="currentColor"
      stroke-width="1.5"
      stroke-linejoin="round"
    />
    <!-- Pecíolo -->
    <path
      d="M 12,14 L 12,18"
      fill="none"
      stroke="currentColor"
      stroke-width="1.5"
      stroke-linecap="round"
    />

    <!-- ── Nervaduras centrales (stroke 1, opacity 0.6) ── -->

    <!-- Nervadura central -->
    <path
      d="M 12,13.5 L 12,3"
      fill="none"
      stroke="currentColor"
      stroke-width="1"
      stroke-linecap="round"
      opacity="0.6"
    />
    <!-- Nervadura superior izquierda -->
    <path
      d="M 12,13.5 L 5.5,6"
      fill="none"
      stroke="currentColor"
      stroke-width="1"
      stroke-linecap="round"
      opacity="0.6"
    />
    <!-- Nervadura superior derecha -->
    <path
      d="M 12,13.5 L 18.5,6"
      fill="none"
      stroke="currentColor"
      stroke-width="1"
      stroke-linecap="round"
      opacity="0.6"
    />
    <!-- Nervadura inferior izquierda -->
    <path
      d="M 12,13.5 L 4.5,11.5"
      fill="none"
      stroke="currentColor"
      stroke-width="1"
      stroke-linecap="round"
      opacity="0.6"
    />
    <!-- Nervadura inferior derecha -->
    <path
      d="M 12,13.5 L 19.5,11.5"
      fill="none"
      stroke="currentColor"
      stroke-width="1"
      stroke-linecap="round"
      opacity="0.6"
    />
  </svg>
</template>

<script setup>
defineProps({
  size: { type: [Number, String], default: 24 },
  tone: { type: String, default: 'currentColor' },
})
</script>
