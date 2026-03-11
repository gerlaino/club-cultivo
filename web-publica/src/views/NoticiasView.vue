<template>
  <div class="noticias-view">
    <div class="container py-5">
      <h1 class="mb-4">Noticias del Club</h1>
      <p class="lead text-muted mb-5">
        Mantente al día con las últimas novedades, eventos y anuncios.
      </p>

      <div v-if="loading" class="loading">
        <div class="spinner-border text-success" role="status">
          <span class="visually-hidden">Cargando...</span>
        </div>
      </div>

      <div v-else-if="error" class="alert alert-danger">
        {{ error }}
      </div>

      <div v-else class="row g-4">
        <div v-for="noticia in noticias" :key="noticia.id" class="col-md-6 col-lg-4">
          <article class="card h-100 shadow-sm hover-card">
            <img
                v-if="noticia.cover_url"
                :src="noticia.cover_url"
                class="card-img-top"
                :alt="noticia.titulo"
            >
            <div v-else class="card-img-top bg-light d-flex align-items-center justify-content-center" style="height: 200px;">
              <i class="bi bi-newspaper text-muted" style="font-size: 3rem;"></i>
            </div>

            <div class="card-body d-flex flex-column">
              <div class="mb-2">
                <small class="text-muted">
                  <i class="bi bi-calendar3"></i>
                  {{ formatDate(noticia.publicada_at) }}
                </small>
              </div>

              <h5 class="card-title text-success mb-3">{{ noticia.titulo }}</h5>

              <p class="card-text text-muted flex-grow-1">{{ noticia.preview }}</p>

              <RouterLink :to="`/noticias/${noticia.id}`" class="btn btn-outline-success mt-auto">
                Leer más <i class="bi bi-arrow-right"></i>
              </RouterLink>
            </div>
          </article>
        </div>
      </div>

      <div v-if="!loading && noticias.length === 0" class="text-center py-5">
        <i class="bi bi-inbox display-1 text-muted"></i>
        <p class="text-muted mt-3">No hay noticias publicadas en este momento.</p>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import publicApi from '@/api/publicApi'

const noticias = ref([])
const loading = ref(true)
const error = ref(null)

function formatDate(dateString) {
  const date = new Date(dateString)
  return date.toLocaleDateString('es-AR', {
    year: 'numeric',
    month: 'long',
    day: 'numeric'
  })
}

onMounted(async () => {
  try {
    noticias.value = await publicApi.getNoticias()
  } catch (err) {
    console.error('Error cargando noticias:', err)
    error.value = 'Error al cargar las noticias. Por favor, intenta de nuevo.'
  } finally {
    loading.value = false
  }
})
</script>

<style scoped>
.card-img-top {
  height: 200px;
  object-fit: cover;
}

.hover-card {
  transition: transform 0.2s, box-shadow 0.2s;
}

.hover-card:hover {
  transform: translateY(-5px);
  box-shadow: 0 0.5rem 1rem rgba(0, 0, 0, 0.15) !important;
}
</style>