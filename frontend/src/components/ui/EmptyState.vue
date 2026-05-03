<script setup>
defineProps({
  icon:    { type: String, default: '🌿' },
  title:   { type: String, required: true },
  message: { type: String, default: '' },
  compact: { type: Boolean, default: false },
})
</script>

<template>
  <div class="empty-state" :class="{ 'empty-state--compact': compact }">
    <i v-if="icon.startsWith('bi-')" :class="[`bi ${icon}`, compact ? 'empty-state__icon-sm' : 'empty-state__icon']" aria-hidden="true"></i>
    <span v-else :class="compact ? 'empty-state__icon-sm' : 'empty-state__icon'" aria-hidden="true">{{ icon }}</span>
    <p class="empty-state__title">{{ title }}</p>
    <p v-if="message" class="empty-state__msg">{{ message }}</p>
    <div v-if="$slots.actions" class="empty-state__actions">
      <slot name="actions" />
    </div>
  </div>
</template>

<style scoped>
.empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 3rem 1.5rem;
  text-align: center;
  color: #6c757d;
}
.empty-state__icon     { font-size: 2.5rem; margin-bottom: .75rem; }
.empty-state__icon-sm  { font-size: 1.25rem; margin-bottom: .35rem; }
.empty-state__title    { font-size: .925rem; font-weight: 600; margin: 0 0 .35rem; color: #4b5563; }
.empty-state__msg      { font-size: .825rem; margin: 0 0 1rem; max-width: 280px; line-height: 1.5; }
.empty-state__actions  { display: flex; flex-wrap: wrap; gap: .5rem; justify-content: center; }

.empty-state--compact  { padding: 1.25rem .75rem; }
.empty-state--compact .empty-state__title { font-size: .8rem; }
</style>
