<template>
  <!-- Identidad del club (tenant) para el topbar. La marca de plataforma vive en el sidebar. -->
  <div class="club-brand" :title="club.name">
    <img v-if="club.logoUrl" :src="club.logoUrl" class="club-brand__logo" :alt="club.name" />
    <DsAvatar v-else :name="club.name" :tone="tone" size="md" />
    <span class="club-brand__name">{{ club.name }}</span>
    <span class="club-brand__sep" aria-hidden="true"></span>
  </div>
</template>

<script setup>
import { useClubStore } from '../../stores/club.js'
import DsAvatar from '../../design-system/components/Avatar.vue'

defineProps({
  // tono del avatar fallback cuando el club no tiene logo cargado
  tone: { type: String, default: 'ink-500' },
})

const club = useClubStore()
</script>

<style scoped>
.club-brand {
  display: flex;
  align-items: center;
  gap: var(--sp-2);
  flex-shrink: 0;
  min-width: 0;
}
.club-brand__logo {
  width: 40px;
  height: 40px;
  border-radius: var(--r-md);
  object-fit: contain;
  padding: 2px;
  border: 1px solid var(--c-ink-100);
  background: #fff;
  flex-shrink: 0;
  box-sizing: border-box;
}
.club-brand__name {
  font-size: var(--fs-14);
  font-weight: 700;
  color: var(--c-ink-900);
  white-space: nowrap;
  max-width: 220px;
  overflow: hidden;
  text-overflow: ellipsis;
  letter-spacing: -.01em;
}
.club-brand__sep {
  width: 1px;
  height: 26px;
  background: var(--c-ink-300);
  flex-shrink: 0;
}
@media (max-width: 640px) {
  .club-brand__name, .club-brand__sep { display: none; }
}
</style>
