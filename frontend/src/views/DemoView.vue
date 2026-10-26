<template>
  <PaginaPublica :accion="d.accion" :tono="lado === 'autocultivo' ? 'trigo' : 'verde'">
    <!-- La demo es la página: va sobre el color de su puerta, con la vuelta arriba. -->
    <div class="dv__banda">
      <div class="hb__wrap"><RouterLink :to="d.volver.to" class="dv__volver">← {{ d.volver.label }}</RouterLink></div>
      <ComoSeHace class="dv__demo" encabezado="h1" tema="claro" ancla="demo"
                  :ceja="d.ceja" :titulo="d.titulo" :intro="d.intro" :flujos="d.flujos" />
    </div>

    <!-- El paso siguiente: la demo termina donde termina la página de su puerta. -->
    <section class="hb__sec">
      <div class="hb__wrap dv__cierre-in">
        <div>
          <h2 class="hb__h2">{{ d.cierre.titulo }}</h2>
          <p class="dv__cierre-p">{{ d.cierre.texto }}</p>
        </div>
        <div class="dv__cierre-acc">
          <RouterLink :to="d.cierre.to" class="hb__btn">
            {{ d.cierre.boton }}
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" aria-hidden="true"><path d="M5 12h14M13 6l6 6-6 6"/></svg>
          </RouterLink>
          <RouterLink :to="d.volver.to" class="hb__btn hb__btn--linea">Ver todo lo que hace</RouterLink>
        </div>
      </div>
    </section>
  </PaginaPublica>
</template>

<script setup>
// LAS DEMOS (/bienvenida/organizaciones/demo y /bienvenida/autocultivo/demo, 26-oct-2026): la app de
// verdad, grabada (`ComoSeHace`, los videos de `public/demos/`). Germán: «no debería estar en dos
// lugares, sólo en la demo». Las páginas de cada puerta llevan acá con «Ver la demo» (`FranjaDemo`).
// La planta que crece por fase (`RecorridoFases`) NO es una grabación y se queda en la página de
// autocultivo: cuenta qué te da, no cómo se usa.
import { computed } from 'vue'
import PaginaPublica from '../components/public/PaginaPublica.vue'
import ComoSeHace from '../components/public/ComoSeHace.vue'
import { FLUJOS_ORGANIZACIONES, FLUJOS_AUTOCULTIVO } from '../components/public/contenido.js'

const props = defineProps({
  lado: { type: String, required: true, validator: (v) => ['organizaciones', 'autocultivo'].includes(v) },
})

const DEMOS = {
  organizaciones: {
    accion: { label: 'Hablemos', to: '/bienvenida/organizaciones#contacto' },
    volver: { label: 'Organizaciones', to: '/bienvenida/organizaciones' },
    ceja:   'Demo · organizaciones',
    titulo: 'Así se trabaja desde administración',
    intro:  'Cargar una genética, armar un lote, dar de alta un paciente y dispensarle. Es la app real, grabada con datos de ejemplo: elegí una tarea y mirala en la compu o en el teléfono.',
    flujos: FLUJOS_ORGANIZACIONES,
    cierre: {
      titulo: '¿La vemos con tus datos?',
      texto:  'Armamos la cuenta con ustedes y cargamos tu padrón, genéticas y stock.',
      boton:  'Contanos de tu organización',
      to:     '/bienvenida/organizaciones#contacto',
    },
  },
  autocultivo: {
    accion: { label: 'Probar gratis', to: '/registro' },
    volver: { label: 'Autocultivo', to: '/bienvenida/autocultivo' },
    ceja:   'Demo · autocultivo',
    titulo: 'Así se usa, en el teléfono',
    intro:  'Grabado en la app con datos de ejemplo. Tocá cada paso y miralo.',
    flujos: FLUJOS_AUTOCULTIVO,
    cierre: {
      titulo: 'Probala con tus plantas',
      texto:  'Sin tarjeta y entrás en el momento.',
      boton:  'Crear mi cuenta gratis',
      to:     '/registro',
    },
  },
}
const d = computed(() => DEMOS[props.lado])
</script>

<style scoped>
.dv__banda { background: var(--hb-salvia-suave); border-bottom: 1px solid var(--hb-regla); }
.dv__volver { display: inline-block; padding-top: 22px; color: var(--hb-tinta-2); font-size: 14px; font-weight: 600; text-decoration: none; }
.dv__volver:hover { color: var(--hb-tinta); }
.dv__banda > .dv__demo { background: transparent; border-block: 0; padding-top: clamp(18px, 3vw, 32px); }
.dv__cierre-in { display: flex; flex-wrap: wrap; gap: 20px 40px; align-items: center; justify-content: space-between; }
.dv__cierre-p { margin: 10px 0 0; color: var(--hb-tinta-2); max-width: 34em; }
.dv__cierre-acc { display: flex; flex-wrap: wrap; gap: 12px; }
</style>
