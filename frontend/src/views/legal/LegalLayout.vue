<template>
  <div class="lg">
    <header class="lg__header">
      <div class="lg__wrap lg__header-in">
        <button type="button" class="lg__volver" @click="volver">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" aria-hidden="true"><path d="M19 12H5M11 18l-6-6 6-6"/></svg>
          Volver
        </button>
        <RouterLink to="/bienvenida" class="lg__brand">Cultivo Espacial</RouterLink>
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
import { useRouter } from 'vue-router'
import { TITULAR, VIGENCIA } from './titular.js'
import { cargarFuentesHerbario } from '../../lib/fuentesHerbario.js'

cargarFuentesHerbario()
const router = useRouter()

// Volver a donde estaba. Desde el registro estas páginas se abren en una pestaña nueva (para no
// perder lo que ya escribió): ahí «volver» es cerrar la pestaña. Si no hay de dónde volver, a la
// página de inicio.
function volver () {
  if (window.history.state?.back) return router.back()
  if (window.opener) { window.close(); return }
  router.push('/bienvenida')
}

defineProps({ titulo: { type: String, required: true } })
const yr = new Date().getFullYear()
</script>

<style scoped>
/* Misma dirección visual que la página pública («Herbario», en verdes suaves). */
.lg {
  --hb-papel: #EEF5EF; --hb-papel-claro: #F8FBF7; --hb-tinta: #15301F; --hb-tinta-2: #4E6858;
  --hb-regla: #CDE0D2; --hb-verde: #2E6B4A; --hb-salvia-suave: #DCEDE1; --hb-bosque: #173A2A; --hb-ambar: #B98532;
  position: relative; z-index: 0; min-height: 100vh;
  background: var(--hb-papel); color: var(--hb-tinta);
  font: 16px/1.7 'Public Sans', system-ui, sans-serif;
}
.lg__wrap { width: 100%; max-width: 760px; margin: 0 auto; padding: 0 16px; }
.lg__header { position: sticky; top: 0; z-index: 10; background: color-mix(in srgb, var(--hb-papel) 90%, transparent); backdrop-filter: blur(8px); border-bottom: 1px solid var(--hb-regla); }
.lg__header-in { display: flex; align-items: center; gap: 14px; height: 60px; }
.lg__volver {
  display: inline-flex; align-items: center; gap: 6px; min-height: 38px; padding: 0 14px;
  background: var(--hb-papel-claro); color: var(--hb-tinta); border: 1px solid var(--hb-regla); border-radius: 999px;
  font: 600 14px 'Public Sans', system-ui, sans-serif; cursor: pointer;
}
.lg__volver:hover { border-color: var(--hb-tinta); }
.lg__brand { color: var(--hb-tinta); text-decoration: none; font: 600 17px 'Fraunces', Georgia, serif; white-space: nowrap; }
.lg__nav { margin-left: auto; display: flex; gap: 16px; }
.lg__nav-a { color: var(--hb-tinta-2); text-decoration: none; font-size: .9rem; }
.lg__nav-a.router-link-active { color: var(--hb-verde); font-weight: 600; }
@media (max-width: 520px) { .lg__brand { display: none; } }
.lg__main { padding-top: 2.2rem; padding-bottom: 3rem; }
.lg__h1 { font: 600 clamp(1.8rem, 5vw, 2.6rem)/1.1 'Fraunces', Georgia, serif; letter-spacing: -.015em; margin: 0 0 .4rem; }
.lg__vigencia { margin: 0 0 1.6rem; color: var(--hb-tinta-2); font: 13px 'JetBrains Mono', ui-monospace, monospace; }

/* El contenido viene en el slot: estilos para sus etiquetas. */
.lg__main :deep(h2) { font: 600 1.3rem/1.25 'Fraunces', Georgia, serif; margin: 2.2rem 0 .6rem; }
.lg__main :deep(p), .lg__main :deep(li) { font-size: .97rem; line-height: 1.7; }
.lg__main :deep(p) { margin: 0 0 .8rem; }
.lg__main :deep(ul) { margin: 0 0 .8rem; padding-left: 1.2rem; }
.lg__main :deep(li) { margin-bottom: .4rem; }
.lg__main :deep(a) { color: var(--hb-verde); font-weight: 600; }
.lg__main :deep(.lg-resumen) { background: var(--hb-papel-claro); border: 1.5px solid var(--hb-verde); border-radius: 16px; padding: 1.1rem 1.2rem; margin-bottom: 1.6rem; }
.lg__main :deep(.lg-resumen p:last-child), .lg__main :deep(.lg-resumen ul:last-child) { margin-bottom: 0; }
.lg__main :deep(.lg-pendiente) { background: #F6E7C6; color: #6B4A00; border-radius: 4px; padding: 0 .3em; font-weight: 600; }
.lg__main :deep(.lg-legal) { font-size: .86rem; color: var(--hb-tinta-2); border-left: 3px solid var(--hb-regla); padding-left: .8rem; }

.lg__footer { border-top: 1px solid var(--hb-regla); padding: 1.25rem 0 2rem; }
.lg__footer-in { display: flex; flex-wrap: wrap; gap: .4rem 1.2rem; font-size: .85rem; color: var(--hb-tinta-2); }
.lg__footer-in a { color: var(--hb-verde); }
</style>
