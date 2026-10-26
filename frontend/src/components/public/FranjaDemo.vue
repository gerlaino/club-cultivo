<template>
  <!-- «MIRÁ LA DEMO» (26-oct-2026): las grabaciones de cómo se usa viven sólo en su vista
       (/bienvenida/*/demo). En la página queda esta franja: dos cuadros de la grabación y el botón. -->
  <section class="fd" :class="`fd--${tema}`" aria-label="Demo">
    <RouterLink :to="to" class="hb__wrap fd__in">
      <span class="fd__cuadros" :class="{ 'fd__cuadros--tel': telefono }" aria-hidden="true">
        <img v-for="c in cuadros" :key="c" :src="`/demos/${c}.jpg`" alt="" loading="lazy">
      </span>
      <span class="fd__txt">
        <b>{{ titulo }}</b>
        <span>{{ texto }}</span>
      </span>
      <span class="hb__btn fd__btn">
        <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M7 4.5v15l13-7.5z"/></svg>
        Ver la demo
      </span>
    </RouterLink>
  </section>
</template>

<script setup>
defineProps({
  to:       { type: String, required: true },
  titulo:   { type: String, required: true },
  texto:    { type: String, required: true },
  // Los nombres de las portadas de `public/demos/` (sin .jpg).
  cuadros:  { type: Array, required: true },
  telefono: { type: Boolean, default: false },   // cuadros verticales (grabaciones del teléfono)
  tema:     { type: String, default: 'oscuro' },  // 'oscuro' (bosque) | 'claro'
})
</script>

<style scoped>
.fd--oscuro { background: var(--hb-bosque); color: var(--hb-papel-claro); }
.fd--claro { background: var(--hb-salvia-suave); color: var(--hb-tinta); border-block: 1px solid var(--hb-regla); }
.fd__in { display: flex; align-items: center; gap: clamp(16px, 3vw, 32px); flex-wrap: wrap; padding-block: clamp(22px, 3.5vw, 36px); color: inherit; text-decoration: none; }
.fd__cuadros { display: flex; gap: 8px; flex: none; }
.fd__cuadros img { width: 132px; height: 82px; object-fit: cover; object-position: top left; border-radius: 8px; border: 2px solid color-mix(in srgb, currentColor 22%, transparent); display: block; }
.fd__cuadros--tel img { width: 58px; height: 104px; object-position: top; border-radius: 10px; }
.fd__txt { flex: 1 1 240px; min-width: 0; display: grid; gap: 4px; }
.fd__txt b { font: 600 clamp(1.25rem, 2.2vw, 1.55rem)/1.15 var(--hb-serif); letter-spacing: -.01em; }
.fd__txt span { font-size: .98rem; opacity: .82; }
.fd--oscuro .fd__btn { background: var(--hb-menta); border-color: var(--hb-menta); color: var(--hb-bosque); }
.fd__in:hover .fd__btn { transform: translateY(-1px); }
.fd__in:focus-visible { outline: 2px solid var(--hb-verde); outline-offset: 4px; border-radius: 12px; }
@media (max-width: 560px) { .fd__cuadros img { width: 104px; height: 66px; } .fd__btn { width: 100%; } }
</style>
