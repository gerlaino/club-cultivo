<script setup>
import { computed } from 'vue'
import { useRouter, useLink } from 'vue-router'

const props = defineProps({
  // Array of { label, to? } — last item is current (no link)
  items: { type: Array, required: true },
})

// On mobile collapse middle items if > 3
const isMobile = () => window.innerWidth < 576
const visible  = computed(() => {
  if (props.items.length <= 3 || !isMobile()) return props.items
  return [props.items[0], { label: '…', ellipsis: true }, props.items[props.items.length - 1]]
})
</script>

<template>
  <nav aria-label="breadcrumb" class="bc">
    <ol class="bc__list">
      <template v-for="(item, i) in visible" :key="i">
        <li v-if="item.ellipsis" class="bc__item bc__item--ellipsis" aria-hidden="true">…</li>
        <li v-else class="bc__item" :class="{ 'bc__item--current': i === items.length - 1 }">
          <RouterLink
            v-if="item.to && i < items.length - 1"
            class="bc__link"
            :to="item.to"
          >{{ item.label }}</RouterLink>
          <span v-else class="bc__current" :aria-current="i === items.length - 1 ? 'page' : undefined">
            {{ item.label }}
          </span>
        </li>
        <li v-if="i < visible.length - 1 && !visible[i + 1]?.ellipsis" class="bc__sep" aria-hidden="true">›</li>
        <li v-else-if="item.ellipsis" class="bc__sep" aria-hidden="true">›</li>
      </template>
    </ol>
  </nav>
</template>

<style scoped>
.bc { margin-bottom: 1.25rem; }
.bc__list {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: .2rem;
  list-style: none;
  margin: 0;
  padding: 0;
  font-size: .78rem;
}
.bc__link         { color: var(--c-slate-400); text-decoration: none; transition: color .12s; }
.bc__link:hover   { color: #1b5e20; }
.bc__current      { color: #1a2e1a; font-weight: 600; }
.bc__sep          { color: var(--c-slate-300); font-size: .7rem; }
.bc__item--ellipsis { color: var(--c-slate-400); }
</style>
