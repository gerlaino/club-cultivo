<template>
  <div class="evento-detail">
    <div v-if="loading" class="loading">
      <div class="spinner-border text-success" role="status">
        <span class="visually-hidden">Cargando...</span>
      </div>
    </div>

    <div v-else-if="error" class="container py-5">
      <div class="alert alert-danger">{{ error }}</div>
      <RouterLink to="/eventos" class="btn btn-success">
        <i class="bi bi-arrow-left"></i> Volver a Eventos
      </RouterLink>
    </div>

    <div v-else class="container py-5">
      <nav aria-label="breadcrumb" class="mb-4">
        <ol class="breadcrumb">
          <li class="breadcrumb-item"><RouterLink to="/">Inicio</RouterLink></li>
          <li class="breadcrumb-item"><RouterLink to="/eventos">Eventos</RouterLink></li>
          <li class="breadcrumb-item active">{{ evento.titulo }}</li>
        </ol>
      </nav>

      <div class="row">
        <!-- Imágenes -->
        <div class="col-lg-6 mb-4">
          <div v-if="evento.imagenes_urls.length > 0">
            <div class="imagen-principal mb-3">
              <img :src="currentImage" :alt="evento.titulo" class="img-fluid rounded shadow">
            </div>

            <!-- Miniaturas -->
            <div v-if="evento.imagenes_urls.length > 1" class="d-flex gap-2 mt-3">
              <div
                  v-for="(imagen, index) in evento.imagenes_urls"
                  :key="index"
                  class="thumbnail"
                  :class="{ active: currentImage === imagen }"
                  @click="currentImage = imagen"
              >
                <img :src="imagen" :alt="`${evento.titulo} ${index + 1}`" class="img-fluid rounded">
              </div>
            </div>
          </div>
          <div v-else class="imagen-principal bg-light d-flex align-items-center justify-content-center rounded shadow">
            <i class="bi bi-calendar-event text-muted" style="font-size: 5rem;"></i>
          </div>
        </div>

        <!-- Información -->
        <div class="col-lg-6">
          <h1 class="mb-4">{{ evento.titulo }}</h1>

          <!-- Fecha y hora -->
          <div class="card border-success mb-4">
            <div class="card-body">
              <h5 class="text-success mb-3">
                <i class="bi bi-calendar-check"></i> Fecha y Hora
              </h5>

              <div class="mb-3">
                <strong>Fecha:</strong>
                <p class="mb-0">{{ formatFecha(evento.fecha_inicio) }}</p>
              </div>

              <div class="mb-3">
                <strong>Horario:</strong>
                <p class="mb-0">
                  {{ formatHora(evento.fecha_inicio) }}
                  <span v-if="evento.fecha_fin">
                    - {{ formatHora(evento.fecha_fin) }}
                  </span>
                </p>
              </div>

              <div v-if="evento.lugar">
                <strong>Lugar:</strong>
                <p class="mb-0">
                  <i class="bi bi-geo-alt-fill text-success"></i>
                  {{ evento.lugar }}
                </p>
              </div>
            </div>
          </div>

          <!-- Descripción -->
          <div v-if="evento.descripcion" class="mb-4">
            <h5 class="text-success mb-3">Descripción</h5>
            <div class="evento-descripcion">
              <p v-for="(parrafo, index) in formatDescripcion(evento.descripcion)" :key="index">
                {{ parrafo }}
              </p>
            </div>
          </div>

          <!-- Estado -->
          <div class="alert mb-4" :class="esPasado(evento.fecha_inicio) ? 'alert-secondary' : 'alert-info'">
            <i class="bi" :class="esPasado(evento.fecha_inicio) ? 'bi-clock-history' : 'bi-info-circle'"></i>
            {{ esPasado(evento.fecha_inicio) ? 'Este evento ya finalizó' : 'Evento próximo - Anotá la fecha' }}
          </div>

          <!-- Compartir -->
          <div class="mb-4">
            <h6 class="mb-3">Compartir evento</h6>
            <div class="d-flex gap-2">
              <button class="btn btn-sm btn-outline-primary" @click="compartir('facebook')">
                <i class="bi bi-facebook"></i>
              </button>
              <button class="btn btn-sm btn-outline-info" @click="compartir('twitter')">
                <i class="bi bi-twitter"></i>
              </button>
              <button class="btn btn-sm btn-outline-success" @click="compartir('whatsapp')">
                <i class="bi bi-whatsapp"></i>
              </button>
              <button class="btn btn-sm btn-outline-secondary" @click="copiarLink">
                <i class="bi bi-link-45deg"></i>
              </button>
            </div>
          </div>
        </div>
      </div>

      <!-- Botón volver -->
      <div class="mt-5">
        <RouterLink to="/eventos" class="btn btn-outline-success">
          <i class="bi bi-arrow-left"></i> Volver a Eventos
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
const evento = ref({})
const currentImage = ref(null)
const loading = ref(true)
const error = ref(null)

function formatFecha(dateString) {
  const date = new Date(dateString)
  return date.toLocaleDateString('es-AR', {
    weekday: 'long',
    year: 'numeric',
    month: 'long',
    day: 'numeric'
  })
}

function formatHora(dateString) {
  const date = new Date(dateString)
  return date.toLocaleTimeString('es-AR', {
    hour: '2-digit',
    minute: '2-digit'
  })
}

function formatDescripcion(descripcion) {
  if (!descripcion) return []
  return descripcion.split('\n').filter(p => p.trim().length > 0)
}

function esPasado(fechaInicio) {
  return new Date(fechaInicio) < new Date()
}

function compartir(red) {
  const url = window.location.href
  const titulo = evento.value.titulo

  const urls = {
    facebook: `https://www.facebook.com/sharer/sharer.php?u=${encodeURIComponent(url)}`,
    twitter: `https://twitter.com/intent/tweet?url=${encodeURIComponent(url)}&text=${encodeURIComponent(titulo)}`,
    whatsapp: `https://wa.me/?text=${encodeURIComponent(titulo + ' ' + url)}`
  }

  if (urls[red]) {
    window.open(urls[red], '_blank', 'width=600,height=400')
  }
}

function copiarLink() {
  navigator.clipboard.writeText(window.location.href).then(() => {
    alert('Link copiado al portapapeles')
  })
}

onMounted(async () => {
  try {
    evento.value = await publicApi.getEvento(route.params.id)
    if (evento.value.imagenes_urls.length > 0) {
      currentImage.value = evento.value.imagenes_urls[0]
    }
  } catch (err) {
    console.error('Error cargando evento:', err)
    error.value = 'No se pudo cargar el evento. Por favor, intenta de nuevo.'
  } finally {
    loading.value = false
  }
})
</script>

<style scoped>
.imagen-principal {
  height: 400px;
  overflow: hidden;
  display: flex;
  align-items: center;
  justify-content: center;
}

.imagen-principal img {
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

.evento-descripcion p {
  line-height: 1.8;
  margin-bottom: 1rem;
}
</style>