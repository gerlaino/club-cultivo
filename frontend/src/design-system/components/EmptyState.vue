<template>
  <div class="ds-empty">
    <LeafHerbarium :size="80" class="ds-empty__watermark" />
    <p class="ds-empty__title">{{ title }}</p>
    <p v-if="description" class="ds-empty__desc">{{ description }}</p>
    <slot />
  </div>
</template>

<script setup>
import LeafHerbarium from '../icons/LeafHerbarium.vue'

defineProps({
  title:       { type: String, required: true },
  description: { type: String, default: '' },
})
</script>

<style scoped>
.ds-empty {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: var(--sp-3);
  padding: var(--sp-10) var(--sp-6);
  text-align: center;
}

.ds-empty__watermark {
  opacity: 0.15;
  color: var(--c-leaf-700);
}

.ds-empty__title {
  font-size: var(--fs-16);
  font-weight: 600;
  color: var(--c-ink-700);
  margin: 0;
}

.ds-empty__desc {
  font-size: var(--fs-14);
  color: var(--c-ink-500);
  margin: 0;
  max-width: 320px;
  line-height: var(--lh-loose);
}
</style>
