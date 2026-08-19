<template>
  <div class="portal">
    <PortalNavBar />
    <main class="portal__main">
      <RouterView />
    </main>
    <PortalFooter />
  </div>
</template>

<script setup>
import { onMounted } from 'vue'
import { RouterView } from 'vue-router'
import PortalNavBar from '@/components/portal/PortalNavBar.vue'
import PortalFooter from '@/components/portal/PortalFooter.vue'
import { usePortalClubStore } from '@/stores/portalClub'

// El nombre, el logo y el color los pide el shell una sola vez: la barra y el pie los muestran
// en todas las pantallas y cada vista pidiéndolos por su cuenta era una llamada por navegación.
onMounted(() => usePortalClubStore().fetchClub())
</script>

<style scoped>
.portal {
  min-height: 100vh;
  display: flex;
  flex-direction: column;
  background: #fff;
}

.portal__main {
  flex: 1;
  padding-top: 76px; /* la barra es fija */
}
</style>
