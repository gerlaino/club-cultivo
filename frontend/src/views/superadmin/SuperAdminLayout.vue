<script setup>
// Mismo patrón de shell que el resto de la app: TopBar arriba, contenido abajo. Antes era un
// sidebar propio con los colores escritos a mano y un botón de logout suelto al pie — sin menú
// de usuario y sin ninguna pantalla donde el super admin se administrara a sí mismo.
//
// Lo único que cambia respecto de los otros roles es el acento (--c-role-superadmin): que se
// note que acá se administra la plataforma y no un club.
import SuperAdminTopBar from '../../components/layout/SuperAdminTopBar.vue'
</script>

<template>
  <div class="sa-shell">
    <SuperAdminTopBar />
    <div class="sa-accent-bar"></div>
    <main class="sa-main">
      <router-view />
    </main>
  </div>
</template>

<style scoped>
.sa-shell {
  min-height: 100vh;
  background: var(--c-paper);
  display: flex;
  flex-direction: column;
}

/* Franja de rol: el mismo recurso que usa el shell de admin para teñir la pantalla sin
   repintar todo. */
.sa-accent-bar {
  height: 3px;
  background: linear-gradient(90deg, var(--c-role-superadmin), transparent);
  flex-shrink: 0;
}

/* El ancho y el centrado viven ACÁ, no en cada vista. Cuando cada pantalla se lo ponía sola,
   dos se olvidaron el `margin: 0 auto` (quedaban con el ancho limitado pero pegadas a la
   izquierda) y otras cuatro no declaraban ancho, así que el contenido saltaba de lugar al
   cambiar de pestaña. Una vista que necesite ser más angosta se lo pone encima. */
.sa-main { flex: 1; min-width: 0; width: 100%; max-width: 1180px; margin: 0 auto; }
</style>
