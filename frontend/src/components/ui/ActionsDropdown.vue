<template>
  <div class="act__wrap" ref="wrapRef">
    <button class="act__trigger" @click="open = !open" :class="{ 'act__trigger--open': open }">
      ⚡ {{ label }}
      <svg class="act__chevron" viewBox="0 0 10 6" fill="none">
        <path d="M1 1l4 4 4-4" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/>
      </svg>
    </button>

    <Teleport to="body">
      <div v-if="open" class="act__backdrop" @click="open = false" />
      <div v-if="open" class="act__panel" :style="panelStyle">
        <template v-for="(item, i) in items" :key="i">
          <div v-if="item.divider" class="act__divider" />
          <button
            v-else
            class="act__item"
            :class="{ 'act__item--danger': item.danger, 'act__item--disabled': item.disabled }"
            :disabled="item.disabled"
            @click="handleClick(item)"
          >
            <span class="act__item-emoji">{{ item.emoji }}</span>
            <span class="act__item-label">{{ item.label }}</span>
          </button>
        </template>
      </div>
    </Teleport>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted, nextTick, watch } from 'vue'

const props = defineProps({
  items: { type: Array, default: () => [] },
  label: { type: String, default: 'Acciones' },
})

const open    = ref(false)
const wrapRef = ref(null)
const panelStyle = ref({})

watch(open, async (val) => {
  if (!val) return
  await nextTick()
  if (!wrapRef.value) return
  const rect = wrapRef.value.getBoundingClientRect()
  const panelW = 220
  const rightOverflow = rect.right + panelW > window.innerWidth
  panelStyle.value = {
    position: 'fixed',
    top: rect.bottom + 6 + 'px',
    left: rightOverflow ? (rect.right - panelW) + 'px' : rect.left + 'px',
    zIndex: 1100,
    minWidth: panelW + 'px',
  }
})

function handleClick(item) {
  open.value = false
  item.onClick?.()
}

function onKeydown(e) {
  if (e.key === 'Escape') open.value = false
}

onMounted(() => document.addEventListener('keydown', onKeydown))
onUnmounted(() => document.removeEventListener('keydown', onKeydown))
</script>

<style scoped>
.act__wrap { position: relative; display: inline-block; }

.act__trigger {
  display: inline-flex; align-items: center; gap: var(--sp-2);
  background: #fff; color: var(--c-ink-700, #3A3F44);
  border: 1.5px solid var(--c-ink-300, #D1D5DB);
  padding: .55rem 1rem; border-radius: var(--r-lg, 8px);
  font-size: var(--fs-14, .875rem); font-weight: 600; cursor: pointer;
  transition: all var(--t-fast, .12s); white-space: nowrap;
  font-family: var(--font-ui, system-ui);
}
.act__trigger:hover, .act__trigger--open {
  background: var(--c-ink-100, #F3F4F6);
  border-color: var(--c-ink-500, #6B7280);
}

.act__chevron {
  width: 10px; height: 6px; flex-shrink: 0;
  transition: transform var(--t-fast);
}
.act__trigger--open .act__chevron { transform: rotate(180deg); }

.act__backdrop { position: fixed; inset: 0; z-index: 1099; }

.act__panel {
  background: #fff;
  border: 1.5px solid var(--c-ink-300, #D1D5DB);
  border-radius: var(--r-xl, 12px);
  box-shadow: var(--sh-3, 0 8px 24px rgba(0,0,0,.12));
  padding: var(--sp-2) 0;
  overflow: hidden;
}

.act__item {
  display: flex; align-items: center; gap: var(--sp-3);
  width: 100%; padding: .55rem 1rem; border: none; background: transparent;
  font-size: var(--fs-14, .875rem); color: var(--c-ink-700, #3A3F44);
  font-family: var(--font-ui, system-ui); cursor: pointer;
  text-align: left; transition: background var(--t-fast);
  white-space: nowrap;
}
.act__item:hover { background: var(--c-leaf-50, #F4F8F5); }
.act__item--danger { color: var(--c-rust-600, #DC2626); }
.act__item--danger:hover { background: #FEF2F2; }
.act__item--disabled { opacity: .45; cursor: not-allowed; }
.act__item-emoji { font-size: 1rem; width: 20px; text-align: center; flex-shrink: 0; }
.act__item-label { font-weight: 500; }

.act__divider { height: 1px; background: var(--c-ink-100, #F3F4F6); margin: var(--sp-2) 0; }
</style>
