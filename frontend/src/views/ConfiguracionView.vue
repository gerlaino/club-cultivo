<template>
  <div class="cfg">
    <RouterView />
  </div>
</template>

<script setup>
// Layout fino de Configuración. Las pestañas (Club/General, Suscripción, Equipo, Sedes,
// Alertas, Sitio web, Integraciones, Papelera) viven ahora en el topbar (useNavContext),
// así que acá solo renderizamos la sección activa.
</script>

<style scoped>
.cfg { display: flex; flex-direction: column; min-height: 100%; }
</style>
