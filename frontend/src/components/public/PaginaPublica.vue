<template>
  <div class="herbario hb-sitio">
    <header class="pp__top">
      <div class="hb__wrap pp__top-in">
        <RouterLink to="/bienvenida" class="pp__marca">Cultivo Espacial</RouterLink>
        <nav class="pp__nav" aria-label="Secciones">
          <RouterLink to="/bienvenida/organizaciones">Organizaciones</RouterLink>
          <RouterLink to="/bienvenida/autocultivo">Autocultivo</RouterLink>
          <RouterLink to="/contacto">Contacto</RouterLink>
        </nav>
        <RouterLink to="/login" class="pp__ingresar">Ingresar</RouterLink>
        <!-- El botón de arriba es el de ESA página: en proyectos manda al contacto, no al alta de
             autocultivo (antes una organización tocaba «Probar gratis» y caía en el registro personal). -->
        <template v-if="accion">
          <a v-if="accion.to.startsWith('#')" :href="accion.to" class="hb__btn hb__btn--chico">{{ accion.label }}</a>
          <RouterLink v-else :to="accion.to" class="hb__btn hb__btn--chico">{{ accion.label }}</RouterLink>
        </template>
      </div>
    </header>

    <main>
      <slot />
    </main>

    <footer class="pp__pie">
      <div class="hb__wrap pp__pie-in">
        <span class="pp__pie-marca">Cultivo Espacial</span>
        <nav class="pp__pie-nav" aria-label="Legales">
          <RouterLink to="/terminos">Términos y condiciones</RouterLink>
          <RouterLink to="/privacidad">Privacidad</RouterLink>
          <!-- Res. SCI 424/2020: el botón de arrepentimiento, a la vista en TODAS las páginas. -->
          <RouterLink :to="{ path: '/contacto', query: { tipo: 'baja' } }" class="pp__arrep">Botón de arrepentimiento</RouterLink>
          <RouterLink to="/login">Ingresar</RouterLink>
        </nav>
        <span class="pp__pie-copy">© {{ yr }}</span>
      </div>
    </footer>
  </div>
</template>

<script setup>
// EL ARMAZÓN DE LAS PÁGINAS PÚBLICAS (5-oct-2026): /bienvenida, /bienvenida/autocultivo,
// /bienvenida/organizaciones y /contacto. Encabezado, pie con el botón de arrepentimiento, las
// fuentes, los estilos compartidos (`assets/herbario.css`) y el «aparecer al hacer scroll».
//
// El router de la app no tiene `scrollBehavior` (cambiarlo tocaría las 150 rutas de adentro), así
// que al entrar a una de estas páginas se va arriba, o al ancla si vino con `#`.
import { onMounted, onBeforeUnmount, nextTick } from 'vue'

defineProps({
  // { label, to } del botón de arriba, o null para no mostrarlo (la portada ya tiene las dos puertas).
  accion: { type: Object, default: () => ({ label: 'Probar gratis', to: '/registro' }) },
})
import { useRoute } from 'vue-router'
import { cargarFuentesHerbario } from '../../lib/fuentesHerbario.js'
import '../../assets/herbario.css'

cargarFuentesHerbario()
const route = useRoute()
const yr = new Date().getFullYear()

let revelador = null
onMounted(async () => {
  await nextTick()
  // `instant`: la hoja global tiene `scroll-behavior: smooth`, y una página nueva que aparece
  // deslizándose desde donde estaba la anterior parece que no cambió.
  const ancla = route.hash && document.querySelector(route.hash)
  if (ancla) ancla.scrollIntoView({ behavior: 'instant' })
  else window.scrollTo({ top: 0, behavior: 'instant' })

  const quieto = window.matchMedia?.('(prefers-reduced-motion: reduce)').matches
  const elementos = document.querySelectorAll('.hb-sitio .hb-rev')
  if (quieto || !('IntersectionObserver' in window)) {
    elementos.forEach(el => el.classList.add('hb-rev--on'))
    return
  }
  revelador = new IntersectionObserver((entradas) => entradas.forEach(e => {
    if (e.isIntersecting) { e.target.classList.add('hb-rev--on'); revelador.unobserve(e.target) }
  }), { threshold: 0.15 })
  elementos.forEach(el => revelador.observe(el))
})
onBeforeUnmount(() => revelador?.disconnect())
</script>

<style scoped>
.pp__top { position: sticky; top: 0; z-index: 20; background: color-mix(in srgb, var(--hb-papel) 88%, transparent); backdrop-filter: blur(8px); border-bottom: 1px solid var(--hb-regla); }
.pp__top-in { display: flex; align-items: center; gap: 18px; height: 64px; }
.pp__marca { color: var(--hb-tinta); text-decoration: none; font: 600 19px var(--hb-serif); letter-spacing: -.01em; white-space: nowrap; }
.pp__nav { display: flex; gap: 22px; margin-left: auto; }
.pp__nav a { color: var(--hb-tinta-2); text-decoration: none; font-size: 15px; }
.pp__nav a:hover { color: var(--hb-tinta); }
.pp__nav a.router-link-active { color: var(--hb-verde); font-weight: 600; }
.pp__ingresar { display: inline-flex; align-items: center; min-height: 38px; color: var(--hb-tinta); text-decoration: none; font-weight: 600; font-size: 15px; }
@media (max-width: 760px) {
  .pp__nav { display: none; }
  .pp__ingresar { margin-left: auto; }
  .pp__top-in { gap: 12px; }
  .pp__marca { font-size: 17px; }
}

.pp__pie { border-top: 1px solid var(--hb-tinta); padding: 28px 0 36px; }
.pp__pie-in { display: flex; flex-wrap: wrap; align-items: center; gap: 12px 28px; font-size: 14px; color: var(--hb-tinta-2); }
.pp__pie-marca { font: 600 17px var(--hb-serif); color: var(--hb-tinta); }
.pp__pie-nav { display: flex; flex-wrap: wrap; gap: 8px 20px; }
.pp__pie-nav a { color: var(--hb-tinta-2); text-decoration: none; }
.pp__pie-nav a:hover { color: var(--hb-tinta); text-decoration: underline; }
.pp__pie-nav a.pp__arrep { color: var(--hb-verde); font-weight: 600; }
.pp__pie-copy { margin-left: auto; font: 13px var(--hb-mono); }
</style>
