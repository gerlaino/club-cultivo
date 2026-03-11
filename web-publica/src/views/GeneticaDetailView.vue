<template>
  <div class="genetica-detail">
    <div v-if="loading" class="loading">
      <div class="spinner-border text-success" role="status">
        <span class="visually-hidden">Cargando...</span>
      </div>
    </div>

    <div v-else-if="error" class="container py-5">
      <div class="alert alert-danger">{{ error }}</div>
      <RouterLink to="/geneticas" class="btn btn-success">
        <i class="bi bi-arrow-left"></i> Volver a Genéticas
      </RouterLink>
    </div>

    <div v-else class="container py-5">
      <nav aria-label="breadcrumb" class="mb-4">
        <ol class="breadcrumb">
          <li class="breadcrumb-item"><RouterLink to="/">Inicio</RouterLink></li>
          <li class="breadcrumb-item"><RouterLink to="/geneticas">Genéticas</RouterLink></li>
          <li class="breadcrumb-item active">{{ genetica.nombre }}</li>
        </ol>
      </nav>

      <div class="row">
        <!-- Galería de fotos -->
        <div class="col-lg-6 mb-4">
          <div v-if="genetica.fotos_urls.length > 0" class="foto-principal mb-3">
            <img :src="currentPhoto" :alt="genetica.nombre" class="img-fluid rounded shadow">
          </div>
          <div v-else class="foto-principal bg-light d-flex align-items-center justify-content-center rounded shadow">
            <i class="bi bi-image text-muted" style="font-size: 5rem;"></i>
          </div>

          <!-- Miniaturas -->
          <div v-if="genetica.fotos_urls.length > 1" class="d-flex gap-2 mt-3">
            <div
                v-for="(foto, index) in genetica.fotos_urls"
                :key="index"
                class="thumbnail"
                :class="{ active: currentPhoto === foto }"
                @click="currentPhoto = foto"
            >
              <img :src="foto" :alt="`${genetica.nombre} ${index + 1}`" class="img-fluid rounded">
            </div>
          </div>
        </div>

        <!-- Información -->
        <div class="col-lg-6">
          <h1 class="mb-3">{{ genetica.nombre }}</h1>

          <div class="mb-4">
            <span class="badge bg-secondary fs-6 me-2">{{ formatTipo(genetica.tipo) }}</span>
            <span v-if="genetica.disponible" class="badge bg-success fs-6">
              <i class="bi bi-check-circle"></i> Disponible
            </span>
            <span v-else class="badge bg-warning text-dark fs-6">
              <i class="bi bi-x-circle"></i> No disponible
            </span>
          </div>

          <!-- Cannabinoides -->
          <div class="cannabinoides mb-4">
            <h5 class="text-success mb-3">Perfil de Cannabinoides</h5>
            <div class="row g-3">
              <div class="col-6">
                <div class="card border-success">
                  <div class="card-body text-center">
                    <div class="text-muted small mb-1">THC</div>
                    <div class="display-6 text-success fw-bold">{{ genetica.thc }}%</div>
                  </div>
                </div>
              </div>
              <div class="col-6">
                <div class="card border-success">
                  <div class="card-body text-center">
                    <div class="text-muted small mb-1">CBD</div>
                    <div class="display-6 text-success fw-bold">{{ genetica.cbd }}%</div>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <!-- Descripción -->
          <div v-if="genetica.descripcion" class="mb-4">
            <h5 class="text-success mb-3">Descripción</h5>
            <p class="text-muted">{{ genetica.descripcion }}</p>
          </div>

          <div v-if="!genetica.disponible" class="alert alert-warning mt-3">
            <i class="bi bi-info-circle"></i>
            Esta genética no está disponible en este momento. Contactanos para más información.
          </div>
        </div>
      </div>

      <!-- Información adicional -->
      <div class="row mt-5">
        <div class="col-12">
          <h3 class="mb-4">Información Adicional</h3>

          <div class="accordion" id="accordionInfo">
            <div class="accordion-item">
              <h2 class="accordion-header">
                <button class="accordion-button" type="button" data-bs-toggle="collapse" data-bs-target="#collapseUso">
                  Uso Recomendado
                </button>
              </h2>
              <div id="collapseUso" class="accordion-collapse collapse show" data-bs-parent="#accordionInfo">
                <div class="accordion-body">
                  <p v-if="genetica.tipo === 'indica'">
                    Las variedades Indica son ideales para uso nocturno. Proporcionan relajación profunda, ayudan con el insomnio y alivian el dolor crónico.
                  </p>
                  <p v-else-if="genetica.tipo === 'sativa'">
                    Las variedades Sativa son perfectas para uso diurno. Proporcionan energía, estimulan la creatividad y mejoran el estado de ánimo.
                  </p>
                  <p v-else>
                    Las variedades Híbridas combinan lo mejor de Indica y Sativa, proporcionando un balance entre relajación y energía. Versátiles para uso diurno o nocturno.
                  </p>
                </div>
              </div>
            </div>

            <div class="accordion-item">
              <h2 class="accordion-header">
                <button class="accordion-button collapsed" type="button" data-bs-toggle="collapse" data-bs-target="#collapseCultivo">
                  Información de Cultivo
                </button>
              </h2>
              <div id="collapseCultivo" class="accordion-collapse collapse" data-bs-parent="#accordionInfo">
                <div class="accordion-body">
                  Cultivado de forma orgánica, sin pesticidas ni fertilizantes químicos.
                  Cada lote pasa por análisis de laboratorio para garantizar su calidad y pureza.
                </div>
              </div>
            </div>

            <div class="accordion-item">
              <h2 class="accordion-header">
                <button class="accordion-button collapsed" type="button" data-bs-toggle="collapse" data-bs-target="#collapseAviso">
                  Aviso Legal
                </button>
              </h2>
              <div id="collapseAviso" class="accordion-collapse collapse" data-bs-parent="#accordionInfo">
                <div class="accordion-body">
                  <strong>Solo para socios del club.</strong> El cannabis medicinal solo está disponible para personas con autorización REPROCANN vigente.
                  Uso exclusivamente medicinal. Prohibida su venta.
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Botón volver -->
      <div class="mt-5">
        <RouterLink to="/geneticas" class="btn btn-outline-success">
          <i class="bi bi-arrow-left"></i> Volver a Genéticas
        </RouterLink>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import publicApi from '@/api/publicApi'

const route = useRoute()
const genetica = ref({})
const currentPhoto = ref(null)
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
    genetica.value = await publicApi.getGenetica(route.params.id)
    if (genetica.value.fotos_urls.length > 0) {
      currentPhoto.value = genetica.value.fotos_urls[0]
    }
  } catch (err) {
    console.error('Error cargando genética:', err)
    error.value = 'No se pudo cargar la genética. Por favor, intenta de nuevo.'
  } finally {
    loading.value = false
  }
})
</script>

<style scoped>
.foto-principal {
  height: 500px;
  overflow: hidden;
  display: flex;
  align-items: center;
  justify-content: center;
}

.foto-principal img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.thumbnail {
  width: 80px;
  height: 80px;
  cursor: pointer;
  opacity: 0.6;
  transition: opacity 0.2s;
  border: 2px solid transparent;
}

.thumbnail:hover {
  opacity: 1;
}

.thumbnail.active {
  opacity: 1;
  border-color: #198754;
}

.thumbnail img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.cannabinoides .card {
  transition: transform 0.2s;
}

.cannabinoides .card:hover {
  transform: translateY(-5px);
}
</style>