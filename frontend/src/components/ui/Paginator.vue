<script setup>
import { computed } from 'vue'

const props = defineProps({
  page:      { type: Number, required: true },
  perPage:   { type: Number, required: true },
  total:     { type: Number, required: true },
  pageSizes: { type: Array, default: () => [10, 25, 50] },
})
const emit = defineEmits(['update:page', 'update:perPage'])

const totalPages = computed(() => Math.max(1, Math.ceil(props.total / props.perPage)))
const from       = computed(() => props.total === 0 ? 0 : (props.page - 1) * props.perPage + 1)
const to         = computed(() => Math.min(props.page * props.perPage, props.total))

// Show at most 5 page buttons, centered around current
const pageButtons = computed(() => {
  const total = totalPages.value
  if (total <= 7) return Array.from({ length: total }, (_, i) => i + 1)
  const cur = props.page
  const pages = new Set([1, total])
  for (let i = Math.max(2, cur - 1); i <= Math.min(total - 1, cur + 1); i++) pages.add(i)
  const sorted = [...pages].sort((a, b) => a - b)
  // Insert ellipsis markers
  const result = []
  for (let i = 0; i < sorted.length; i++) {
    if (i > 0 && sorted[i] - sorted[i - 1] > 1) result.push('…')
    result.push(sorted[i])
  }
  return result
})

function goTo(p) {
  if (typeof p !== 'number') return
  if (p < 1 || p > totalPages.value || p === props.page) return
  emit('update:page', p)
}

function onPerPageChange(e) {
  emit('update:perPage', Number(e.target.value))
  emit('update:page', 1)
}
</script>

<template>
  <div v-if="total > perPage || pageSizes.length > 1" class="paginator">
    <!-- Counter -->
    <span class="paginator__info">
      {{ from }}–{{ to }} de {{ total }}
    </span>

    <!-- Page buttons -->
    <nav aria-label="Paginación" class="paginator__nav">
      <button
        class="paginator__btn"
        :disabled="page <= 1"
        aria-label="Página anterior"
        @click="goTo(page - 1)"
      >
        <i class="bi bi-chevron-left"></i>
      </button>

      <template v-for="p in pageButtons" :key="p">
        <span v-if="p === '…'" class="paginator__ellipsis">…</span>
        <button
          v-else
          class="paginator__btn"
          :class="{ 'paginator__btn--active': p === page }"
          :aria-current="p === page ? 'page' : undefined"
          @click="goTo(p)"
        >{{ p }}</button>
      </template>

      <button
        class="paginator__btn"
        :disabled="page >= totalPages"
        aria-label="Página siguiente"
        @click="goTo(page + 1)"
      >
        <i class="bi bi-chevron-right"></i>
      </button>
    </nav>

    <!-- Per page selector -->
    <select
      v-if="pageSizes.length > 1"
      class="paginator__size"
      :value="perPage"
      aria-label="Ítems por página"
      @change="onPerPageChange"
    >
      <option v-for="s in pageSizes" :key="s" :value="s">{{ s }} / pág.</option>
    </select>
  </div>
</template>

<style scoped>
.paginator {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: .5rem;
  padding-top: .75rem;
}
.paginator__info {
  font-size: .75rem;
  color: #94a3b8;
  margin-right: auto;
}
.paginator__nav {
  display: flex;
  align-items: center;
  gap: .2rem;
}
.paginator__btn {
  min-width: 30px;
  height: 30px;
  padding: 0 .35rem;
  border: 1.5px solid #e2e8f0;
  background: #fff;
  border-radius: 7px;
  color: #64748b;
  font-size: .78rem;
  font-weight: 600;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all .12s;
}
.paginator__btn:hover:not(:disabled) { border-color: #1b5e20; color: #1b5e20; }
.paginator__btn--active { background: #1b5e20; border-color: #1b5e20; color: #fff; }
.paginator__btn:disabled { opacity: .35; cursor: not-allowed; }
.paginator__ellipsis { font-size: .78rem; color: #94a3b8; padding: 0 .2rem; }
.paginator__size {
  font-size: .75rem;
  color: #64748b;
  border: 1.5px solid #e2e8f0;
  border-radius: 7px;
  padding: .15rem .4rem;
  background: #fff;
  cursor: pointer;
}
</style>
