<template>
  <div class="mag">
    <component
      :is="a.to ? 'RouterLink' : 'button'"
      v-for="a in actions"
      :key="a.key"
      :to="a.to"
      class="mag__item"
      @click="onTap(a)"
    >
      <span class="mag__icon" :style="{ background: a.tint || 'var(--c-leaf-100)', color: a.color || 'var(--c-leaf-700)' }">
        <i class="bi" :class="a.icon"></i>
      </span>
      <span class="mag__label">{{ a.label }}</span>
    </component>
  </div>
</template>

<script setup>
defineProps({
  // [{ key, label, icon, to?, color?, tint?, onClick? }]
  actions: { type: Array, required: true },
})
function onTap(a) { if (typeof a.onClick === 'function') a.onClick() }
</script>

<style scoped>
.mag {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: .6rem;
}
.mag__item {
  display: flex; flex-direction: column; align-items: center; gap: .5rem;
  padding: .9rem .35rem;
  background: #fff;
  border: 1px solid var(--c-leaf-100, #e8f0eb);
  border-radius: var(--r-xl, 14px);
  text-decoration: none;
  cursor: pointer;
  -webkit-tap-highlight-color: transparent;
  transition: transform .12s ease, box-shadow .15s ease, border-color .15s;
  font: inherit;
}
.mag__item:active { transform: scale(.96); }
.mag__item:hover { border-color: var(--c-leaf-300, #a8c9b5); box-shadow: var(--sh-2); }
.mag__icon {
  width: 46px; height: 46px; border-radius: 13px;
  display: flex; align-items: center; justify-content: center;
  font-size: 1.3rem;
}
.mag__label {
  font-size: .72rem; font-weight: 600; text-align: center;
  color: var(--c-ink-900, #1a1d1f); line-height: 1.2;
}
</style>
