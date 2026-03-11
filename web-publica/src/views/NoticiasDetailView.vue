<template>
  <div class="noticia-detail">
    <div v-if="loading" class="loading">
      <div class="spinner-border text-success" role="status">
        <span class="visually-hidden">Cargando...</span>
      </div>
    </div>

    <div v-else-if="error" class="container py-5">
      <div class="alert alert-danger">{{ error }}</div>
      <RouterLink to="/noticias" class="btn btn-success">
        <i class="bi bi-arrow-left"></i> Volver a Noticias
      </RouterLink>
    </div>

    <article v-else>
      <!-- Header con imagen -->
      <div v-if="noticia.cover_url" class="noticia-header">
        <img :src="noticia.cover_url" :alt="noticia.titulo" class="w-100">
        <div class="overlay"></div>
      </div>

      <div class="container py-5">
        <nav aria-label="breadcrumb" class="mb-4">
          <ol class="breadcrumb">
            <li class="breadcrumb-item"><RouterLink to="/">Inicio</RouterLink></li>
            <li class="breadcrumb-item"><RouterLink to="/noticias">Noticias</RouterLink></li>
            <li class="breadcrumb-item active">{{ noticia.titulo }}</li>
          </ol>
        </nav>

        <div class="row justify-content-center">
          <div class="col-lg-8">
            <!-- Metadata -->
            <div class="mb-4">
              <small class="text-muted">
                <i class="bi bi-calendar3"></i>
                {{ formatDate(noticia.publicada_at) }}
              </small>
            </div>

            <!-- Título -->
            <h1 class="display-5 fw-bold mb-4">{{ noticia.titulo }}</h1>

            <!-- Contenido -->
            <div class="noticia-content">
              <p v-for="(parrafo, index) in formatContenido(noticia.contenido)" :key="index" class="lead">
                {{ parrafo }}
              </p>
            </div>

            <!-- Compartir -->
            <div class="mt-5 pt-4 border-top">
              <h5 class="mb-3">Compartir</h5>
              <div class="d-flex gap-2">
                <button class="btn btn-outline-primary" @click="compartir('facebook')">
                  <i class="bi bi-facebook"></i> Facebook
                </button>
                <button class="btn btn-outline-info" @click="compartir('twitter')">
                  <i class="bi bi-twitter"></i> Twitter
                </button>
                <button class="btn btn-outline-success" @click="compartir('whatsapp')">
                  <i class="bi bi-whatsapp"></i> WhatsApp
                </button>
                <button class="btn btn-outline-secondary" @click="copiarLink">
                  <i class="bi bi-link-45deg"></i> Copiar link
                </button>
              </div>
            </div>

            <!-- Botón volver -->
            <div class="mt-5">
              <RouterLink to="/noticias" class="btn btn-outline-success">
                <i class="bi bi-arrow-left"></i> Volver a Noticias
              </RouterLink>
            </div>
          </div>
        </div>
      </div>
    </article>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import publicApi from '@/api/publicApi'

const route = useRoute()
const noticia = ref({})
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

function formatContenido(contenido) {
  if (!contenido) return []
  // Divide el contenido en párrafos por saltos de línea
  return contenido.split('\n').filter(p => p.trim().length > 0)
}

function compartir(red) {
  const url = window.location.href
  const titulo = noticia.value.titulo

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
    noticia.value = await publicApi.getNoticia(route.params.id)
  } catch (err) {
    console.error('Error cargando noticia:', err)
    error.value = 'No se pudo cargar la noticia. Por favor, intenta de nuevo.'
  } finally {
    loading.value = false
  }
})
</script>

<style scoped>
.noticia-header {
  position: relative;
  height: 400px;
  overflow: hidden;
}

.noticia-header img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.noticia-header .overlay {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: linear-gradient(to bottom, rgba(0,0,0,0) 0%, rgba(0,0,0,0.3) 100%);
}

.noticia-content p {
  line-height: 1.8;
  margin-bottom: 1.5rem;
}
</style>