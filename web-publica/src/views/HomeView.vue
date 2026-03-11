<template>
  <div class="home">
    <!-- Hero -->
    <section class="hero bg-success text-white py-5">
      <div class="container py-5">
        <div class="row align-items-center">
          <div class="col-lg-6">
            <h1 class="display-4 fw-bold mb-4">Bienvenido a {{ club?.name }}</h1>
            <p class="lead mb-4">
              Cannabis medicinal de calidad, cultivado con dedicación para nuestros socios.
            </p>
            <RouterLink to="/geneticas" class="btn btn-light btn-lg me-3">
              Ver Genéticas
            </RouterLink>
            <RouterLink to="/contacto" class="btn btn-outline-light btn-lg">
              Contacto
            </RouterLink>
          </div>
          <div class="col-lg-6 text-center">
            <img v-if="club?.logo_url" :src="club.logo_url" alt="Logo" class="img-fluid rounded shadow" style="max-width: 400px">
          </div>
        </div>
      </div>
    </section>

    <!-- Genéticas destacadas -->
    <section class="py-5">
      <div class="container">
        <h2 class="text-center mb-5">Genéticas Disponibles</h2>

        <div v-if="loading" class="loading">
          <div class="spinner-border text-success" role="status">
            <span class="visually-hidden">Cargando...</span>
          </div>
        </div>

        <div v-else class="row g-4">
          <div v-for="genetica in geneticas.slice(0, 3)" :key="genetica.id" class="col-md-4">
            <div class="card h-100 shadow-sm">
              <div class="card-body">
                <h5 class="card-title text-success">{{ genetica.nombre }}</h5>
                <span class="badge bg-secondary mb-3">{{ genetica.tipo }}</span>
                <div class="d-flex justify-content-between mb-3">
                  <small><strong>THC:</strong> {{ genetica.thc }}%</small>
                  <small><strong>CBD:</strong> {{ genetica.cbd }}%</small>
                </div>
                <RouterLink :to="`/geneticas/${genetica.id}`" class="btn btn-outline-success btn-sm">
                  Ver más
                </RouterLink>
              </div>
            </div>
          </div>
        </div>

        <div class="text-center mt-4">
          <RouterLink to="/geneticas" class="btn btn-success">
            Ver todas las genéticas
          </RouterLink>
        </div>
      </div>
    </section>

    <!-- Últimas noticias -->
    <section class="bg-light py-5">
      <div class="container">
        <h2 class="text-center mb-5">Últimas Noticias</h2>

        <div class="row g-4">
          <div v-for="noticia in noticias.slice(0, 2)" :key="noticia.id" class="col-md-6">
            <div class="card h-100 shadow-sm">
              <img v-if="noticia.cover_url" :src="noticia.cover_url" class="card-img-top" :alt="noticia.titulo">
              <div class="card-body">
                <h5 class="card-title">{{ noticia.titulo }}</h5>
                <p class="text-muted small">
                  <i class="bi bi-calendar3"></i>
                  {{ new Date(noticia.publicada_at).toLocaleDateString() }}
                </p>
                <p class="card-text">{{ noticia.preview }}</p>
                <RouterLink :to="`/noticias/${noticia.id}`" class="btn btn-outline-success btn-sm">
                  Leer más
                </RouterLink>
              </div>
            </div>
          </div>
        </div>

        <div class="text-center mt-4">
          <RouterLink to="/noticias" class="btn btn-success">
            Ver todas las noticias
          </RouterLink>
        </div>
      </div>
    </section>

    <!-- Próximos eventos -->
    <section class="py-5">
      <div class="container">
        <h2 class="text-center mb-5">Próximos Eventos</h2>

        <div class="row g-4">
          <div v-for="evento in eventos.slice(0, 3)" :key="evento.id" class="col-md-4">
            <div class="card h-100 shadow-sm">
              <div class="card-body">
                <h5 class="card-title text-success">{{ evento.titulo }}</h5>
                <p class="mb-2">
                  <i class="bi bi-calendar-event text-success"></i>
                  {{ new Date(evento.fecha_inicio).toLocaleDateString() }}
                </p>
                <p class="mb-2">
                  <i class="bi bi-clock text-success"></i>
                  {{ new Date(evento.fecha_inicio).toLocaleTimeString('es-AR', { hour: '2-digit', minute: '2-digit' }) }}
                </p>
                <p class="mb-3">
                  <i class="bi bi-geo-alt text-success"></i>
                  {{ evento.lugar }}
                </p>
              </div>
            </div>
          </div>
        </div>

        <div class="text-center mt-4">
          <RouterLink to="/eventos" class="btn btn-success">
            Ver todos los eventos
          </RouterLink>
        </div>
      </div>
    </section>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import publicApi from '@/api/publicApi'

const club = ref(null)
const geneticas = ref([])
const noticias = ref([])
const eventos = ref([])
const loading = ref(true)

onMounted(async () => {
  try {
    const [clubData, geneticasData, noticiasData, eventosData] = await Promise.all([
      publicApi.getClub(),
      publicApi.getGeneticas(),
      publicApi.getNoticias(),
      publicApi.getEventos()
    ])

    club.value = clubData
    geneticas.value = geneticasData
    noticias.value = noticiasData
    eventos.value = eventosData
  } catch (error) {
    console.error('Error cargando datos:', error)
  } finally {
    loading.value = false
  }
})
</script>

<style scoped>
.hero {
  min-height: 500px;
  display: flex;
  align-items: center;
}
</style>