<template>
  <div class="geneticas-view">
    <div class="container py-5">
      <h1 class="mb-4">Nuestras Genéticas</h1>
      <p class="lead text-muted mb-5">
        Cultivamos con dedicación las mejores variedades para uso medicinal.
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
        <div v-for="genetica in geneticas" :key="genetica.id" class="col-md-6 col-lg-4">
          <div class="card h-100 shadow-sm hover-card">
            <div v-if="genetica.fotos_urls.length > 0" class="card-img-top-wrapper">
              <img :src="genetica.fotos_urls[0]" class="card-img-top" :alt="genetica.nombre">
            </div>
            <div v-else class="card-img-top-wrapper bg-light d-flex align-items-center justify-content-center">
              <i class="bi bi-image text-muted" style="font-size: 3rem;"></i>
            </div>

            <div class="card-body">
              <h5 class="card-title text-success">{{ genetica.nombre }}</h5>

              <div class="mb-3">
                <span class="badge bg-secondary">{{ formatTipo(genetica.tipo) }}</span>
                <span v-if="!genetica.disponible" class="badge bg-warning text-dark ms-2">
                  No disponible
                </span>
              </div>

              <div class="d-flex justify-content-between mb-3">
                <div>
                  <small class="text-muted">THC</small>
                  <div class="fw-bold text-success">{{ genetica.thc }}%</div>
                </div>
                <div>
                  <small class="text-muted">CBD</small>
                  <div class="fw-bold text-success">{{ genetica.cbd }}%</div>
                </div>
              </div>

              <RouterLink :to="`/geneticas/${genetica.id}`" class="btn btn-outline-success w-100">
                Ver detalles
              </RouterLink>
            </div>
          </div>
        </div>
      </div>

      <div v-if="!loading && geneticas.length === 0" class="text-center py-5">
        <i class="bi bi-inbox display-1 text-muted"></i>
        <p class="text-muted mt-3">No hay genéticas disponibles en este momento.</p>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import publicApi from '@/api/publicApi'

const geneticas = ref([])
const loading = ref(true)
const error = ref(null)

function formatTipo(tipo) {
  const tipos = {
    'indica': 'Indica',
    'sativa': 'Sativa',
    'hibrida': 'Híbrida'
  }
  return tipos[tipo] || tipo
}

onMounted(async () => {
  try {
    geneticas.value = await publicApi.getGeneticas()
  } catch (err) {
    console.error('Error cargando genéticas:', err)
    error.value = 'Error al cargar las genéticas. Por favor, intenta de nuevo.'
  } finally {
    loading.value = false
  }
})
</script>

<style scoped>
.card-img-top-wrapper {
  height: 250px;
  overflow: hidden;
}

.card-img-top {
  width: 100%;
  height: 100%;
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