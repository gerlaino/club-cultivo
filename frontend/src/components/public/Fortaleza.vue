<template>
  <!-- UNA FORTALEZA, una fila: el texto de un lado y la pantalla de la app del otro, enmarcada
       como ficha. `invertida` cambia el lado (las filas se alternan). La pantalla va en el slot. -->
  <article class="fz" :class="{ 'fz--inv': invertida }">
    <div class="fz__txt hb-rev">
      <p class="hb__ceja">{{ ceja }}</p>
      <h3 class="fz__t">{{ titulo }} <em v-if="enfasis">{{ enfasis }}</em></h3>
      <p class="fz__d">{{ texto }}</p>
      <ul v-if="puntos.length" class="hb__lista fz__puntos">
        <li v-for="p in puntos" :key="p">{{ p }}</li>
      </ul>
    </div>
    <div ref="marco" class="fz__marco">
      <!-- Se vuelve a montar la primera vez que se ve: así la animación de la muestra se ve. -->
      <div :key="vuelta"><slot /></div>
      <p class="fz__pie">Ejemplo · datos ficticios</p>
    </div>
  </article>
</template>

<script setup>
import { ref, onMounted, onBeforeUnmount } from 'vue'

defineProps({
  ceja:      { type: String, required: true },
  titulo:    { type: String, required: true },
  enfasis:   { type: String, default: '' },   // la segunda mitad del título, en itálica verde
  texto:     { type: String, required: true },
  puntos:    { type: Array, default: () => [] },
  invertida: { type: Boolean, default: false },
})

const marco = ref(null)
const vuelta = ref(0)
let observador = null
onMounted(() => {
  if (!('IntersectionObserver' in window) || window.matchMedia?.('(prefers-reduced-motion: reduce)').matches) return
  observador = new IntersectionObserver((entradas) => {
    if (entradas.some(e => e.isIntersecting)) { vuelta.value++; observador.disconnect() }
  }, { threshold: 0.35 })
  observador.observe(marco.value)
})
onBeforeUnmount(() => observador?.disconnect())
</script>

<style scoped>
.fz { display: grid; grid-template-columns: minmax(0, .9fr) minmax(0, 1.1fr); gap: clamp(28px, 5vw, 80px); align-items: center; padding-block: clamp(40px, 6vw, 72px); border-top: 1px solid var(--hb-regla); }
.fz--inv .fz__txt { order: 2; }
@media (max-width: 900px) { .fz { grid-template-columns: minmax(0, 1fr); } .fz--inv .fz__txt { order: 0; } }
.fz__txt { min-width: 0; }
.fz__txt .hb__ceja { margin-bottom: 14px; }
.fz__t { margin: 0; font: 600 clamp(1.7rem, 3vw, 2.35rem)/1.08 var(--hb-serif); letter-spacing: -.015em; text-wrap: balance; }
.fz__t em { font-style: italic; font-weight: 400; color: var(--hb-verde); }
.fz__d { margin: 16px 0 0; color: var(--hb-tinta-2); font-size: 1.05rem; max-width: 32em; }
.fz__puntos { margin-top: 20px; }
.fz__marco { min-width: 0; margin-right: 6px; background: var(--hb-papel-claro); border: 1.5px solid var(--hb-verde); box-shadow: 6px 6px 0 var(--hb-salvia); padding: clamp(16px, 2.4vw, 26px); }
.fz__pie { margin: 18px 0 0; padding-top: 10px; border-top: 1px dashed var(--hb-regla); font: 11px var(--hb-mono); letter-spacing: .08em; text-transform: uppercase; color: var(--hb-tinta-2); }
</style>
