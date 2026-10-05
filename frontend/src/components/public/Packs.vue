<template>
  <!-- Sin packs cargados no se muestra nada: nunca una sección «próximamente» en la página. -->
  <section v-if="packs.length" class="hb__sec" id="packs">
    <div class="hb__wrap">
      <header class="hb__sec-h">
        <p class="hb__ceja">Packs</p>
        <h2 class="hb__h2">{{ titulo }}</h2>
      </header>
      <div class="pk">
        <article v-for="p in packs" :key="p.nombre" class="pk__pack hb-rev" :class="{ 'pk__pack--dest': p.destacado }">
          <p class="pk__nombre">{{ p.nombre }}</p>
          <p class="pk__precio"><b>{{ p.precio }}</b><span v-if="p.periodo">{{ p.periodo }}</span></p>
          <p v-if="p.para" class="pk__para">{{ p.para }}</p>
          <ul class="hb__lista">
            <li v-for="x in p.incluye" :key="x">{{ x }}</li>
          </ul>
          <!-- Un ancla de la misma página va con <a>: el router de la app no hace scroll a los `#`. -->
          <a v-if="esAncla(p.accion?.to || accion.to)" :href="p.accion?.to || accion.to" class="hb__btn" :class="{ 'hb__btn--linea': !p.destacado }">
            {{ p.accion?.label || accion.label }}
          </a>
          <RouterLink v-else :to="p.accion?.to || accion.to" class="hb__btn" :class="{ 'hb__btn--linea': !p.destacado }">
            {{ p.accion?.label || accion.label }}
          </RouterLink>
        </article>
      </div>
    </div>
  </section>
</template>

<script setup>
// LOS PACKS CON PRECIO de cada página pública (Germán, 5-oct-2026: «ahí deberían estar los packs
// con los precios»). Los datos van en `contenido.js` (PACKS_AUTOCULTIVO / PACKS_PROYECTOS); mientras estén
// vacíos la sección no aparece. Cada pack: { nombre, precio, periodo?, para?, incluye[], destacado?,
// accion? }.
defineProps({
  titulo: { type: String, default: 'Elegí el tuyo' },
  packs:  { type: Array, required: true },
  // El botón de cada pack, si el pack no trae el suyo.
  accion: { type: Object, default: () => ({ label: 'Empezar', to: '/registro' }) },
})

const esAncla = (to) => typeof to === 'string' && to.startsWith('#')
</script>

<style scoped>
.pk { display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 280px), 1fr)); gap: 24px; align-items: stretch; }
.pk__pack { display: flex; flex-direction: column; gap: 14px; padding: 26px 24px; background: var(--hb-papel-claro); border: 1px solid var(--hb-regla); }
.pk__pack--dest { border: 1.5px solid var(--hb-verde); box-shadow: 6px 6px 0 var(--hb-salvia); }
.pk__nombre { margin: 0; font: 500 12px var(--hb-mono); letter-spacing: .12em; text-transform: uppercase; color: var(--hb-verde); }
.pk__precio { margin: 0; display: flex; align-items: baseline; gap: 6px; }
.pk__precio b { font: 600 2.2rem/1 var(--hb-serif); color: var(--hb-tinta); }
.pk__precio span { font: 13px var(--hb-mono); color: var(--hb-tinta-2); }
.pk__para { margin: 0; color: var(--hb-tinta-2); }
.pk__pack .hb__lista { flex: 1; }
.pk__pack .hb__btn { align-self: flex-start; }
</style>
