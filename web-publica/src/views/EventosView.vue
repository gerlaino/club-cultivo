<template>
  <div class="eventos-view">
    <div class="container py-5">
      <h1 class="mb-4">Eventos del Club</h1>
      <p class="lead text-muted mb-4">
        Participá de nuestros talleres, charlas y actividades.
      </p>

      <!-- Toggle próximos/pasados -->
      <div class="mb-4">
        <div class="btn-group" role="group">
          <button
              type="button"
              class="btn"
              :class="!mostrarPasados ? 'btn-success' : 'btn-outline-success'"
              @click="mostrarPasados = false; cargarEventos()"
          >
            Próximos eventos
          </button>
          <button
              type="button"
              class="btn"
              :class="mostrarPasados ? 'btn-success' : 'btn-outline-success'"
              @click="mostrarPasados = true; cargarEventos()"
          >
            Eventos pasados
          </button>
        </div>
      </div>

      <div v-if="loading" class="loading">
        <div class="spinner-border text-success" role="status">
          <span class="visually-hidden">Cargando...</span>
        </div>
      </div>

      <div v-else-if="error" class="alert alert-danger">
        {{ error }}
      </div>

      <div v-else class="row g-4">
        <div v-for="evento in eventos" :key="evento.id" class="col-md-6 col-lg-4">
          <div class="card h-100 shadow-sm hover-card">
            <div v-if="evento.imagenes_urls.length > 0" class="card-img-top-wrapper">
              <img :src="evento.imagenes_urls[0]" class="card-img-top" :alt="evento.titulo">
            </div>
            <div v-else class="card-img-top-wrapper bg-light d-flex align-items-center justify-content-center">
              <i class="bi bi-calendar-event text-muted" style="font-size: 3rem;"></i>
            </div>

            <div class="card-body">
              <h5 class="card-title text-success">{{ evento.titulo }}</h5>

              <div class="evento-info mb-3">
                <p class="mb-2">
                  <i class="bi bi-calendar-event text-success"></i>
                  <strong>{{ formatFecha(evento.fecha_inicio) }}</strong>
                </p>
                <p class="mb-2">
                  <i class="bi bi-clock text-success"></i>
                  {{ formatHora(evento.fecha_inicio) }}
                  <span v-if="evento.fecha_fin">
                    - {{ formatHora(evento.fecha_fin) }}
                  </span>
                </p>
                <p class="mb-0">
                  <i class="bi bi-geo-alt text-success"></i>
                  {{ evento.lugar }}
                </p>
              </div>

              <RouterLink :to="`/eventos/${evento.id}`" class="btn btn-outline-success w-100">
                Ver detalles
              </RouterLink>
            </div>
          </div>
        </div>
      </div>

      <div v-if="!loading && eventos.length === 0" class="text-center py-5">
        <i class="bi bi-calendar-x display-1 text-muted"></i>
        <p class="text-muted mt-3">
          {{ mostrarPasados ? 'No hay eventos pasados.' : 'No hay eventos próximos programados.' }}
        </p>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import publicApi from '@/api/publicApi'

const eventos = ref([])
const loading = ref(true)
const error = ref(null)
const mostrarPasados = ref(false)

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

async function cargarEventos() {
  loading.value = true
  error.value = null

  try {
    eventos.value = await publicApi.getEventos(mostrarPasados.value)
  } catch (err) {
    console.error('Error cargando eventos:', err)
    error.value = 'Error al cargar los eventos. Por favor, intenta de nuevo.'
  } finally {
    loading.value = false
  }
}

onMounted(() => {
  cargarEventos()
})
</script>

<style scoped>
.card-img-top-wrapper {
  height: 200px;
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

.evento-info {
  font-size: 0.95rem;
}

.evento-info i {
  width: 20px;
  margin-right: 8px;
}
</style>