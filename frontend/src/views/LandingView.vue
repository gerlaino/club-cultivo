<template>
  <PaginaPublica>
    <!-- ── Portada: el texto y la lámina ──────────────────── -->
    <!-- En pantallas anchas la planta es el fondo de la portada, de borde a borde, y el texto va
         encima a la izquierda. En el teléfono, el texto y debajo la planta. -->
    <section class="hb__portada" :class="{ 'hb__portada--ancha': ancha }">
      <PlantaCreciendo v-if="ancha" :key="'ancha'" portada />
      <div class="hb__wrap hb__portada-in">
        <div class="hb__portada-txt">
          <p class="hb__ceja">Cuaderno de cultivo · de la semilla a la cosecha</p>
          <h1 class="hb__h1">Cada planta tiene su historia. <em>Escribila mientras crece.</em></h1>
          <p class="hb__bajada">
            Riegos, nutrientes, fotos, fases y cosecha, anotados en el teléfono en el momento en que
            pasan. Para tu autocultivo y para los proyectos que cultivan y dispensan.
          </p>
          <div class="hb__acciones">
            <RouterLink to="/bienvenida/autocultivo" class="hb__btn">
              Autocultivo
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" aria-hidden="true"><path d="M5 12h14M13 6l6 6-6 6"/></svg>
            </RouterLink>
            <RouterLink to="/bienvenida/proyectos" class="hb__btn hb__btn--linea">Tengo un proyecto</RouterLink>
          </div>
          <p class="hb__nota">{{ diasPrueba }} días gratis en autocultivo · sin tarjeta · entrás en el momento</p>
        </div>
      </div>
      <div v-if="!ancha" class="hb__lamina">
        <PlantaCreciendo :key="'angosta'" />
      </div>
    </section>
  </PaginaPublica>
</template>

<script setup>
// LA PORTADA PÚBLICA (/bienvenida), en la dirección «Herbario»: la planta que crece y las dos
// opciones, nada más (Germán y Javi, 5-oct-2026).
//
// Cada público entra a SU página —/bienvenida/autocultivo (uso personal, se registra solo) y
// /bienvenida/proyectos (organizaciones: la cuenta se arma a mano desde el contacto)—, para que
// nadie lea lo del otro. Lo que antes vivía acá (qué hace, el teléfono, preguntas, contacto,
// principios) se repartió entre esas páginas y /contacto; los packs con precios van adentro de
// cada una. Los días de prueba los dice el backend.
import { ref, onMounted, onBeforeUnmount } from 'vue'
import PaginaPublica from '../components/public/PaginaPublica.vue'
import PlantaCreciendo from '../components/public/PlantaCreciendo.vue'
import { getRegistroInfo } from '../lib/api.js'

const diasPrueba = ref(30)

// Portada ancha (planta de fondo) o angosta (apilada). Se decide por el ancho y se re-arma si cambia.
const consultaAncha = typeof window !== 'undefined' ? window.matchMedia('(min-width: 960px)') : null
const ancha = ref(!!consultaAncha?.matches)
const alCambiarAncho = (e) => { ancha.value = e.matches }

onMounted(async () => {
  consultaAncha?.addEventListener('change', alCambiarAncho)
  try { diasPrueba.value = (await getRegistroInfo()).data.dias_prueba } catch {}
})
onBeforeUnmount(() => consultaAncha?.removeEventListener('change', alCambiarAncho))
</script>

<style scoped>
/* ── Portada ── */
.hb__portada {
  position: relative; overflow: hidden;
  padding: clamp(32px, 6vw, 72px) 0 8px;
  background:
    radial-gradient(60% 70% at 80% 30%, color-mix(in srgb, var(--hb-menta) 32%, transparent) 0%, transparent 70%),
    radial-gradient(50% 60% at 0% 100%, color-mix(in srgb, var(--hb-salvia) 38%, transparent) 0%, transparent 70%);
}
/* Ancha: ocupa la pantalla y la planta es el fondo; el texto, encima y a la izquierda. */
.hb__portada--ancha { min-height: max(660px, calc(100svh - 64px)); display: flex; align-items: center; padding: 0; }
.hb__portada--ancha .hb__portada-in { position: relative; z-index: 2; pointer-events: none; padding-bottom: 90px; }
.hb__portada--ancha .hb__portada-txt { pointer-events: auto; max-width: 540px; }
.hb__portada-txt { min-width: 0; }
/* Angosta: la planta debajo del texto, sin recuadro. */
.hb__lamina { max-width: 480px; margin: 18px auto 0; padding: 0 16px 24px; }
</style>
