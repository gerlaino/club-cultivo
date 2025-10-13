<script setup>
import { computed } from "vue"

const props = defineProps({
  src: { type: String, default: "" },
  name: { type: String, default: "" },   // para iniciales
  size: { type: Number, default: 28 },   // px
})

const initials = computed(() => {
  if (!props.name) return "?"
  const parts = props.name.trim().split(/\s+/)
  const first = parts[0]?.[0] || ""
  const last  = parts[1]?.[0] || ""
  return (first + last || first).toUpperCase()
})

const style = computed(() => ({
  width: `${props.size}px`,
  height: `${props.size}px`,
  lineHeight: `${props.size - 2}px`,
  fontSize: `${Math.round(props.size * 0.42)}px`,
}))
</script>

<template>
  <span class="cc-avatar rounded-circle d-inline-flex align-items-center justify-content-center overflow-hidden bg-secondary-subtle text-dark-emphasis border" :style="style">
    <img v-if="src" :src="src" alt="avatar" class="w-100 h-100 object-fit-cover" />
    <span v-else>{{ initials }}</span>
  </span>
</template>

<style scoped>
.object-fit-cover { object-fit: cover; }
</style>
