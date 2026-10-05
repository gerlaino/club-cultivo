<template>
  <section class="qh" id="que-hace">
    <div class="qh__wrap">
      <header class="qh__cab">
        <p class="qh__ceja">{{ ceja }}</p>
        <h2 class="qh__h2">{{ titulo }}</h2>
      </header>

      <!-- Solapas. Todos los paneles están en la página (v-show): quien busca en Google encuentra
           también lo que está en la solapa que no se ve. La muestra se monta sólo en la activa y
           cuando la lámina ya está en pantalla, así su animación se ve entera cada vez que se abre
           (en el teléfono la lámina queda debajo del texto). -->
      <div class="qh__solapas" role="tablist" :aria-label="titulo" @keydown="moverConTeclas">
        <button v-for="t in temas" :key="t.id" :id="`qh-tab-${t.id}`" ref="botones" type="button" role="tab"
                class="qh__solapa" :class="{ 'qh__solapa--on': activa === t.id }"
                :aria-selected="activa === t.id" :aria-controls="`qh-panel-${t.id}`"
                :tabindex="activa === t.id ? 0 : -1" @click="activa = t.id">
          {{ t.label }}
        </button>
      </div>

      <div v-for="t in temas" v-show="activa === t.id" :key="t.id" :id="`qh-panel-${t.id}`"
           class="qh__panel" role="tabpanel" :aria-labelledby="`qh-tab-${t.id}`">
        <div>
          <p v-if="t.addon" class="qh__para"><span class="qh__addon">Se suma aparte</span></p>
          <h3 class="qh__h3">{{ t.titulo }}</h3>
          <p class="qh__d">{{ t.texto }}</p>
          <ul class="qh__lista">
            <li v-for="p in t.puntos" :key="p">{{ p }}</li>
          </ul>
        </div>
        <figure ref="laminas" class="qh__lamina">
          <component :is="t.muestra" v-if="activa === t.id && vista" v-bind="t.muestraProps || {}" />
          <figcaption class="qh__pie">Ejemplo · datos ficticios</figcaption>
        </figure>
      </div>
    </div>
  </section>
</template>

<script setup>
// «QUÉ HACE» de las páginas públicas (Germán, 5-oct-2026: la portada era linda pero vacía; quien
// la miraba tenía que escribir para enterarse de qué ofrecemos). Una solapa por tema, cada una con
// una muestra dibujada en el estilo de la página — no capturas: la app de adentro tiene otro
// estilo y una captura envejece con cada cambio de pantalla. Los temas de cada público (casa y
// proyectos) viven en `contenido.js`.
import { ref, nextTick, onMounted, onBeforeUnmount } from 'vue'

const props = defineProps({
  ceja:   { type: String, default: 'Qué hace' },
  titulo: { type: String, required: true },
  // [{ id, label, titulo, texto, puntos[], muestra, muestraProps?, addon? }] — ver `contenido.js`.
  temas:  { type: Array, required: true },
})

const activa = ref(props.temas[0].id)
const botones = ref([])
const laminas = ref([])

// La primera vez que una lámina entra en pantalla se montan las muestras; después, cada solapa
// que se abre arranca la suya en el momento.
const vista = ref(false)
let observador = null
onMounted(() => {
  if (!('IntersectionObserver' in window)) { vista.value = true; return }
  observador = new IntersectionObserver((entradas) => {
    if (entradas.some(e => e.isIntersecting)) { vista.value = true; observador.disconnect() }
  }, { threshold: 0.35 })
  laminas.value.forEach(el => observador.observe(el))
})
onBeforeUnmount(() => observador?.disconnect())

// Flechas, Inicio y Fin entre solapas (el patrón de pestañas de WAI-ARIA).
async function moverConTeclas (e) {
  const temas = props.temas
  const i = temas.findIndex(t => t.id === activa.value)
  const destino = { ArrowRight: i + 1, ArrowLeft: i - 1, Home: 0, End: temas.length - 1 }[e.key]
  if (destino === undefined) return
  e.preventDefault()
  const j = (destino + temas.length) % temas.length
  activa.value = temas[j].id
  await nextTick()
  botones.value[j]?.focus()
}
</script>

<style scoped>
.qh { padding: clamp(56px, 8vw, 104px) 0; background: var(--hb-papel-claro); border-block: 1px solid var(--hb-regla); scroll-margin-top: 64px; }
.qh__wrap { width: 100%; max-width: var(--hb-ancho, 1320px); margin: 0 auto; padding: 0 var(--hb-relleno, 16px); }
.qh__cab { margin-bottom: clamp(22px, 3vw, 32px); }
.qh__ceja { margin: 0 0 12px; font: 500 12px var(--hb-mono); letter-spacing: .14em; text-transform: uppercase; color: var(--hb-tinta-2); }
.qh__h2 { margin: 0; max-width: 22em; font: 600 clamp(1.7rem, 3.6vw, 2.5rem)/1.1 var(--hb-serif); letter-spacing: -.015em; text-wrap: balance; }

/* Solapas: en el teléfono, una fila que se desliza de costado. */
.qh__solapas {
  display: flex; gap: 6px; overflow-x: auto; scrollbar-width: none;
  margin: 0 calc(-1 * var(--hb-relleno, 16px)); padding: 2px var(--hb-relleno, 16px) 14px;
  border-bottom: 1px solid var(--hb-regla);
}
.qh__solapas::-webkit-scrollbar { display: none; }
.qh__solapa {
  flex-shrink: 0; min-height: 40px; padding: .45rem 1rem; border-radius: 999px; cursor: pointer;
  background: transparent; border: 1px solid var(--hb-regla); color: var(--hb-tinta-2);
  font: 500 14px var(--hb-sans); white-space: nowrap; transition: background .2s, color .2s, border-color .2s;
}
.qh__solapa:hover { border-color: var(--hb-tinta-2); color: var(--hb-tinta); }
.qh__solapa--on, .qh__solapa--on:hover { background: var(--hb-tinta); border-color: var(--hb-tinta); color: var(--hb-papel-claro); }
.qh__solapa:focus-visible { outline: 2px solid var(--hb-verde); outline-offset: 2px; }

.qh__panel {
  display: grid; grid-template-columns: minmax(0, .85fr) minmax(0, 1fr); gap: clamp(28px, 5vw, 64px);
  align-items: center; padding-top: clamp(28px, 4vw, 44px);
}
@media (max-width: 900px) { .qh__panel { grid-template-columns: minmax(0, 1fr); } }

.qh__para { display: flex; flex-wrap: wrap; align-items: center; gap: 8px; margin: 0 0 12px; font: 500 12px var(--hb-mono); letter-spacing: .1em; text-transform: uppercase; color: var(--hb-verde); }
.qh__addon { border: 1px solid var(--hb-ambar); color: var(--hb-tierra); border-radius: 999px; padding: 2px 9px; letter-spacing: .06em; }
.qh__h3 { margin: 0; font: 600 clamp(1.5rem, 2.6vw, 2rem)/1.15 var(--hb-serif); letter-spacing: -.01em; }
.qh__d { margin: 14px 0 0; color: var(--hb-tinta-2); font-size: 1.05rem; max-width: 32em; }
.qh__lista { list-style: none; margin: 20px 0 0; padding: 0; display: grid; gap: 10px; }
.qh__lista li { position: relative; padding-left: 26px; }
.qh__lista li::before {
  content: ''; position: absolute; left: 2px; top: .45em; width: 12px; height: 12px; background: var(--hb-verde);
  -webkit-mask: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 12 12'%3E%3Cpath d='M1 11C1 5 5 1 11 1c0 6-4 10-10 10z'/%3E%3C/svg%3E") center / contain no-repeat;
          mask: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 12 12'%3E%3Cpath d='M1 11C1 5 5 1 11 1c0 6-4 10-10 10z'/%3E%3C/svg%3E") center / contain no-repeat;
}

/* La lámina: donde va la muestra. Misma ficha de la página (borde verde, sombra salvia). */
.qh__lamina {
  margin: 0 6px 6px 0; min-height: 360px; display: flex; flex-direction: column;
  background: var(--hb-papel); border: 1.5px solid var(--hb-verde); box-shadow: 6px 6px 0 var(--hb-salvia);
  padding: clamp(18px, 3vw, 28px);
}
.qh__lamina > :first-child { flex: 1; }
.qh__pie { margin-top: 16px; padding-top: 10px; border-top: 1px dashed var(--hb-regla); font: 11px var(--hb-mono); letter-spacing: .08em; text-transform: uppercase; color: var(--hb-tinta-2); }
</style>
