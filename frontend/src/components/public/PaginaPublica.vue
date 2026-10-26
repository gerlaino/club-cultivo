<template>
  <div class="herbario hb-sitio" :class="{ 'hb-trigo': tono === 'trigo' }">
    <header class="pp__top">
      <div class="hb__wrap pp__top-in">
        <RouterLink to="/bienvenida" class="pp__marca">Cultivo Espacial</RouterLink>
        <nav class="pp__nav" aria-label="Secciones">
          <!-- Marca por dónde empieza la dirección: la demo de cada puerta también es «su» página. -->
          <RouterLink to="/bienvenida/organizaciones" :class="{ 'is-aca': aca('/bienvenida/organizaciones') }">Organizaciones</RouterLink>
          <RouterLink to="/bienvenida/autocultivo" :class="{ 'is-aca': aca('/bienvenida/autocultivo') }">Autocultivo</RouterLink>
          <RouterLink to="/contacto" :class="{ 'is-aca': aca('/contacto') }">Contacto</RouterLink>
        </nav>
        <!-- El paciente no viene a informarse: viene a entrar a su portal (23-oct-2026). Queda a la
             vista también en el teléfono, donde el menú de secciones se esconde. -->
        <RouterLink to="/paciente" class="pp__paciente">Soy paciente</RouterLink>
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

    <!-- EL PIE (23-oct-2026): quiénes somos, la plataforma, contacto y legales, sobre un degradé que
         sale del papel del cuerpo y termina en el verde claro de la barra de arriba. Sin nombre, CUIT
         ni domicilio del titular (Germán, 6-oct): a una organización le llegan en el acuerdo. -->
    <footer class="pp__pie">
      <div class="hb__wrap">
        <div class="pp__pie-cols">
          <div class="pp__pie-marca">
            <span class="pp__pie-nombre">Cultivo Espacial</span>
            <p>Software de gestión y trazabilidad para proyectos cannábicos de dispensa, investigación y autocultivo.</p>
            <span class="pp__pie-hecho">Hecho en la Argentina</span>
          </div>
          <nav aria-label="Plataforma">
            <p class="pp__pie-t">Plataforma</p>
            <RouterLink to="/bienvenida/organizaciones">Organizaciones</RouterLink>
            <RouterLink to="/bienvenida/autocultivo">Autocultivo</RouterLink>
            <RouterLink to="/paciente">Portal del paciente</RouterLink>
            <RouterLink :to="{ path: '/bienvenida/organizaciones', hash: '#precios' }">Precios</RouterLink>
          </nav>
          <nav aria-label="Contacto">
            <p class="pp__pie-t">Contacto</p>
            <RouterLink to="/contacto">Hablemos</RouterLink>
            <span class="pp__pie-mail">{{ TITULAR.mail }}</span>
          </nav>
          <nav aria-label="Legales">
            <p class="pp__pie-t">Legales</p>
            <RouterLink to="/terminos">Términos y condiciones</RouterLink>
            <RouterLink to="/privacidad">Política de privacidad</RouterLink>
            <!-- Res. SCI 424/2020: el botón de arrepentimiento, a la vista en TODAS las páginas. -->
            <RouterLink :to="{ path: '/contacto', query: { tipo: 'baja' } }" class="pp__arrep">Botón de arrepentimiento</RouterLink>
          </nav>
        </div>
        <div class="pp__pie-base">
          <span>© {{ yr }} Cultivo Espacial. Todos los derechos reservados.</span>
          <span>Cultivo Espacial es un software de gestión: no vende ni entrega cannabis ni sus derivados.</span>
        </div>
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
  // 'trigo' para lo de autocultivo (su página y su demo): el color de su cuarto de la portada.
  tono: { type: String, default: 'verde' },
})
import { useRoute } from 'vue-router'
import { cargarFuentesHerbario } from '../../lib/fuentesHerbario.js'
import { TITULAR } from '../../views/legal/titular.js'
import '../../assets/herbario.css'

cargarFuentesHerbario()
const route = useRoute()
const aca = (base) => { const p = route.path || ''; return p === base || p.startsWith(base + '/') }
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
/* Dónde estás, con el color de esa página (en autocultivo el acento es ámbar: `hb-trigo`). */
.pp__nav a { padding-block: 4px; border-bottom: 2px solid transparent; }
.pp__nav a.is-aca { color: var(--hb-tinta); font-weight: 600; border-bottom-color: var(--hb-verde); }
.pp__ingresar { display: inline-flex; align-items: center; min-height: 38px; color: var(--hb-tinta); text-decoration: none; font-weight: 600; font-size: 15px; }
@media (max-width: 760px) {
  .pp__nav { display: none; }
  .pp__ingresar { margin-left: auto; }
  .pp__top-in { gap: 12px; }
  .pp__marca { font-size: 17px; }
}
/* En un teléfono angosto no entran marca, «Soy paciente», «Ingresar» y el botón: el botón se cortaba
   (26-oct-2026). Se va el botón, que está grande en la primera pantalla de cada página. */
@media (max-width: 480px) { .pp__top-in > .hb__btn { display: none; } }

.pp__paciente {
  display: inline-flex; align-items: center; gap: 7px; min-height: 36px; padding: 0 14px; border-radius: 999px;
  border: 1px solid var(--hb-regla); background: var(--hb-papel-claro); color: var(--hb-tinta);
  font-weight: 600; font-size: 14px; text-decoration: none; white-space: nowrap;
}
.pp__paciente::before { content: ""; width: 7px; height: 7px; border-radius: 50%; background: var(--hb-verde); }
.pp__paciente:hover { border-color: var(--hb-verde); }
@media (max-width: 760px) {
  .pp__paciente { margin-left: auto; padding: 0 11px; font-size: 13px; }
  .pp__paciente + .pp__ingresar { margin-left: 0; }
}

.pp__pie { background: linear-gradient(180deg, var(--hb-papel) 0%, var(--hb-salvia-suave) 55%, color-mix(in srgb, var(--hb-salvia) 55%, var(--hb-salvia-suave)) 100%); padding: 48px 0 24px; color: var(--hb-tinta-2); }
.pp__pie-cols { display: grid; grid-template-columns: minmax(0, 1.6fr) repeat(3, minmax(0, 1fr)); gap: 28px; }
@media (max-width: 860px) { .pp__pie-cols { grid-template-columns: minmax(0, 1fr) minmax(0, 1fr); } .pp__pie-marca { grid-column: 1 / -1; } }
@media (max-width: 420px) { .pp__pie-cols { grid-template-columns: minmax(0, 1fr); } }
.pp__pie-marca p { margin: 8px 0 0; max-width: 34ch; font-size: 14px; line-height: 1.5; }
.pp__pie-nombre { font: 600 20px var(--hb-serif); color: var(--hb-tinta); }
.pp__pie-hecho { display: block; margin-top: 12px; font: 500 11px var(--hb-mono); letter-spacing: .12em; text-transform: uppercase; color: var(--hb-verde); }
.pp__pie-cols nav { display: flex; flex-direction: column; align-items: flex-start; gap: 8px; font-size: 14px; }
.pp__pie-t { margin: 0 0 4px; font: 500 11px var(--hb-mono); letter-spacing: .14em; text-transform: uppercase; color: var(--hb-tinta-2); }
.pp__pie-cols nav a { color: var(--hb-tinta); text-decoration: none; }
.pp__pie-cols nav a:hover { text-decoration: underline; }
.pp__pie-mail { color: var(--hb-tinta); overflow-wrap: anywhere; user-select: all; }
.pp__pie-cols nav a.pp__arrep { margin-top: 2px; padding: 5px 12px; border: 1.5px solid var(--hb-verde); border-radius: 999px; background: var(--hb-papel-claro); color: var(--hb-verde); font-weight: 600; }
.pp__pie-cols nav a.pp__arrep:hover { text-decoration: none; background: var(--hb-salvia-suave); }
.pp__pie-base { margin-top: 32px; padding-top: 14px; border-top: 1px solid color-mix(in srgb, var(--hb-tinta) 14%, transparent); display: flex; flex-wrap: wrap; justify-content: space-between; gap: 6px 20px; font-size: 13px; }
</style>
