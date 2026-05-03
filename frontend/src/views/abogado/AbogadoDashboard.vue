<template>
  <div class="abg-home">
    <h1 class="abg-home__title">Portal Legal</h1>
    <p class="abg-home__sub">Gestión de documentación legal del club.</p>
    <div class="abg-home__cards">
      <RouterLink to="/abogado/documentos" class="abg-card">
        <Files :size="28" :stroke-width="1.5" />
        <span class="abg-card__label">Mis Documentos</span>
        <span class="abg-card__desc">Documentos legales subidos por mí</span>
      </RouterLink>
    </div>
  </div>
</template>

<script setup>
import { Files } from 'lucide-vue-next'
</script>

<style scoped>
.abg-home { padding: var(--sp-6); max-width: 600px; }
.abg-home__title { font-size: var(--fs-24); font-weight: 800; color: var(--c-ink-900); margin: 0 0 var(--sp-1); }
.abg-home__sub { color: var(--c-ink-500); font-size: var(--fs-14); margin: 0 0 var(--sp-6); }
.abg-home__cards { display: grid; grid-template-columns: repeat(auto-fill, minmax(200px, 1fr)); gap: var(--sp-4); }
.abg-card {
  display: flex; flex-direction: column; align-items: flex-start; gap: var(--sp-2);
  background: var(--c-paper); border: 1px solid var(--c-ink-100); border-radius: var(--r-lg);
  padding: var(--sp-5); text-decoration: none; color: var(--c-ink-700);
  transition: border-color .15s, box-shadow .15s;
}
.abg-card:hover { border-color: #5B6473; box-shadow: 0 2px 8px rgba(91,100,115,.1); color: #5B6473; }
.abg-card__label { font-size: var(--fs-15); font-weight: 700; color: var(--c-ink-900); }
.abg-card__desc { font-size: var(--fs-12); color: var(--c-ink-500); }
</style>
