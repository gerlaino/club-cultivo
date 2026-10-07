<script setup>
// La plataforma con barra lateral (7-oct-2026, rediseño aprobado por Germán): navegación fija a la
// izquierda, contenido a lo ancho. En pantallas angostas la barra pasa a ser una franja arriba.
// Los estilos comunes de las pantallas (tarjetas, tablas, etiquetas) viven en `sa.css`.
import SuperAdminSidebar from '../../components/layout/SuperAdminSidebar.vue'
import './sa.css'
</script>

<template>
  <div class="sa-shell">
    <SuperAdminSidebar />
    <main class="sa-main">
      <router-view />
    </main>
  </div>
</template>

<style scoped>
.sa-shell { min-height: 100vh; background: var(--c-slate-50); display: flex; }
/* El ancho y el centrado viven ACÁ, no en cada vista: así el contenido no salta al cambiar de
   sección. */
.sa-main { flex: 1; min-width: 0; padding: 2rem 2.5rem 3rem; box-sizing: border-box; }
.sa-main > :deep(*) { max-width: 1240px; margin-left: auto; margin-right: auto; }
@media (max-width: 900px) {
  .sa-shell { flex-direction: column; }
  .sa-main { padding: 1.25rem 1rem 2.5rem; }
}
</style>
