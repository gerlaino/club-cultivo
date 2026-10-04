<template>
  <div class="lg">
    <header class="lg__header">
      <div class="lg__wrap lg__header-in">
        <RouterLink to="/bienvenida" class="lg__brand">
          <img src="/logo-ce-redondo.png" alt="" class="lg__brand-img" />
          <span>Cultivo Espacial</span>
        </RouterLink>
        <nav class="lg__nav">
          <RouterLink to="/terminos" class="lg__nav-a">Términos</RouterLink>
          <RouterLink to="/privacidad" class="lg__nav-a">Privacidad</RouterLink>
        </nav>
      </div>
    </header>

    <main class="lg__wrap lg__main">
      <h1 class="lg__h1">{{ titulo }}</h1>
      <p class="lg__vigencia">Vigente desde el {{ VIGENCIA }}</p>
      <slot />
    </main>

    <footer class="lg__footer">
      <div class="lg__wrap lg__footer-in">
        <span>© {{ yr }} Cultivo Espacial</span>
        <RouterLink :to="{ path: '/bienvenida', hash: '#contacto', query: { tipo: 'baja' } }">Botón de arrepentimiento</RouterLink>
        <a :href="`mailto:${TITULAR.mail}`">{{ TITULAR.mail }}</a>
      </div>
    </footer>
  </div>
</template>

<script setup>
// El marco de las páginas legales: legibles (texto oscuro sobre claro, renglón angosto) y con el
// «botón de arrepentimiento» siempre a mano, como pide la Res. SCI 424/2020.
import { TITULAR, VIGENCIA } from './titular.js'

defineProps({ titulo: { type: String, required: true } })
const yr = new Date().getFullYear()
</script>

<style scoped>
.lg { min-height: 100vh; background: var(--c-paper); color: var(--c-slate-900); font-family: var(--font-ui, 'Inter', system-ui, sans-serif); }
.lg__wrap { width: 100%; max-width: 760px; margin: 0 auto; padding: 0 16px; }
.lg__header { position: sticky; top: 0; z-index: 10; background: var(--c-leaf-900); }
.lg__header-in { display: flex; align-items: center; gap: 1rem; height: 56px; }
.lg__brand { display: flex; align-items: center; gap: .5rem; color: #fff; text-decoration: none; font-weight: 700; }
.lg__brand-img { width: 28px; height: 28px; border-radius: 50%; }
.lg__nav { margin-left: auto; display: flex; gap: 1rem; }
.lg__nav-a { color: rgba(255,255,255,.7); text-decoration: none; font-size: .88rem; font-weight: 500; }
.lg__nav-a.router-link-active { color: #fff; }
.lg__main { padding-top: 2rem; padding-bottom: 3rem; }
.lg__h1 { font-size: clamp(1.5rem, 4vw, 2rem); font-weight: 800; letter-spacing: -.02em; margin: 0 0 .3rem; color: var(--c-slate-900); }
.lg__vigencia { margin: 0 0 1.5rem; color: var(--c-slate-500); font-size: .88rem; }

/* El contenido viene en el slot: estilos para sus etiquetas. */
.lg__main :deep(h2) { font-size: 1.12rem; font-weight: 700; margin: 2rem 0 .6rem; color: var(--c-slate-900); }
.lg__main :deep(p), .lg__main :deep(li) { font-size: .95rem; line-height: 1.7; }
.lg__main :deep(p) { margin: 0 0 .8rem; }
.lg__main :deep(ul) { margin: 0 0 .8rem; padding-left: 1.2rem; }
.lg__main :deep(li) { margin-bottom: .35rem; }
.lg__main :deep(a) { color: var(--c-leaf-700); font-weight: 600; }
.lg__main :deep(.lg-resumen) { background: var(--c-leaf-50); border: 1px solid var(--c-leaf-100); border-radius: 12px; padding: 1rem 1.1rem; margin-bottom: 1.5rem; }
.lg__main :deep(.lg-resumen p:last-child), .lg__main :deep(.lg-resumen ul:last-child) { margin-bottom: 0; }
.lg__main :deep(.lg-pendiente) { background: var(--c-amber-100); color: #6B4A00; border-radius: 4px; padding: 0 .3em; font-weight: 600; }
.lg__main :deep(.lg-legal) { font-size: .85rem; color: var(--c-slate-600); border-left: 3px solid var(--c-slate-200); padding-left: .8rem; }

.lg__footer { border-top: 1px solid var(--c-slate-200); padding: 1.25rem 0; }
.lg__footer-in { display: flex; flex-wrap: wrap; gap: .4rem 1.2rem; font-size: .82rem; color: var(--c-slate-500); }
.lg__footer-in a { color: var(--c-leaf-700); }

@media (prefers-color-scheme: dark) {
  .lg { background: #0f1512; color: #d6ddd8; }
  .lg__h1, .lg__main :deep(h2) { color: #f1f5f2; }
  .lg__main :deep(.lg-resumen) { background: rgba(90,138,114,.12); border-color: rgba(90,138,114,.25); }
  .lg__main :deep(a), .lg__footer-in a { color: var(--c-leaf-300); }
  .lg__main :deep(.lg-legal) { color: #a8b3ad; border-color: #2a3530; }
}
</style>
