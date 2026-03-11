<template>
  <nav class="navbar navbar-expand-lg navbar-dark bg-success fixed-top shadow">
    <div class="container">
      <RouterLink to="/" class="navbar-brand d-flex align-items-center">
        <img v-if="club?.logo_url" :src="club.logo_url" alt="Logo" height="40" class="me-2">
        <span class="fw-bold">{{ club?.name || 'Club Cannábico' }}</span>
      </RouterLink>

      <button class="navbar-toggler" type="button" data-bs-toggle="collapse" data-bs-target="#navbarNav">
        <span class="navbar-toggler-icon"></span>
      </button>

      <div class="collapse navbar-collapse" id="navbarNav">
        <ul class="navbar-nav ms-auto">
          <li class="nav-item">
            <RouterLink to="/" class="nav-link">Inicio</RouterLink>
          </li>
          <li class="nav-item">
            <RouterLink to="/geneticas" class="nav-link">Genéticas</RouterLink>
          </li>
          <li class="nav-item">
            <RouterLink to="/noticias" class="nav-link">Noticias</RouterLink>
          </li>
          <li class="nav-item">
            <RouterLink to="/eventos" class="nav-link">Eventos</RouterLink>
          </li>
          <li class="nav-item">
            <RouterLink to="/galeria" class="nav-link">Galería</RouterLink>
          </li>
          <li class="nav-item">
            <RouterLink to="/contacto" class="nav-link">Contacto</RouterLink>
          </li>
        </ul>
      </div>
    </div>
  </nav>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import publicApi from '@/api/publicApi'

const club = ref(null)

onMounted(async () => {
  try {
    club.value = await publicApi.getClub()
  } catch (error) {
    console.error('Error cargando info del club:', error)
  }
})
</script>

<style scoped>
.navbar-brand img {
  border-radius: 4px;
}

.nav-link {
  font-weight: 500;
  transition: opacity 0.2s;
}

.nav-link:hover {
  opacity: 0.8;
}

.router-link-active {
  font-weight: 700;
}
</style>