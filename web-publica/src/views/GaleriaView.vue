<template>
  <div class="galeria-view">
    <div class="container py-5">
      <h1 class="mb-4">Galería de Genéticas</h1>
      <p class="lead text-muted mb-5">
        Explorá nuestra colección fotográfica de las mejores variedades.
      </p>

      <div v-if="loading" class="loading">
        <div class="spinner-border text-success" role="status">
          <span class="visually-hidden">Cargando...</span>
        </div>
      </div>

      <div v-else-if="error" class="alert alert-danger">
        {{ error }}
      </div>

      <div v-else>
        <!-- Galería en grid -->
        <div class="gallery-grid">
          <div
              v-for="foto in fotos"
              :key="foto.id"
              class="gallery-item"
              @click="abrirLightbox(foto)"
          >
            <img :src="foto.url" :alt="foto.genetica.nombre" class="img-fluid">
            <div class="overlay">
              <div class="overlay-content">
                <h6 class="text-white mb-0">{{ foto.genetica.nombre }}</h6>
                <small class="text-white-50">Click para ampliar</small>
              </div>
            </div>
          </div>
        </div>

        <div v-if="!loading && fotos.length === 0" class="text-center py-5">
          <i class="bi bi-images display-1 text-muted"></i>
          <p class="text-muted mt-3">No hay fotos en la galería en este momento.</p>
        </div>
      </div>
    </div>

    <!-- Lightbox Modal -->
    <div
        v-if="lightboxFoto"
        class="lightbox"
        @click="cerrarLightbox"
    >
      <div class="lightbox-content">
        <button class="lightbox-close" @click="cerrarLightbox">
          <i class="bi bi-x-lg"></i>
        </button>

        <button
            v-if="lightboxIndex > 0"
            class="lightbox-nav lightbox-prev"
            @click.stop="navegarLightbox(-1)"
        >
          <i class="bi bi-chevron-left"></i>
        </button>

        <div class="lightbox-image-wrapper" @click.stop>
          <img :src="lightboxFoto.url" :alt="lightboxFoto.genetica.nombre" class="lightbox-image">
          <div class="lightbox-caption">
            <h5 class="text-white mb-1">{{ lightboxFoto.genetica.nombre }}</h5>
            <small class="text-white-50">{{ lightboxIndex + 1 }} / {{ fotos.length }}</small>
          </div>
        </div>

        <button
            v-if="lightboxIndex < fotos.length - 1"
            class="lightbox-nav lightbox-next"
            @click.stop="navegarLightbox(1)"
        >
          <i class="bi bi-chevron-right"></i>
        </button>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import publicApi from '@/api/publicApi'

const fotos = ref([])
const loading = ref(true)
const error = ref(null)
const lightboxFoto = ref(null)
const lightboxIndex = ref(-1)

function abrirLightbox(foto) {
  lightboxIndex.value = fotos.value.findIndex(f => f.id === foto.id)
  lightboxFoto.value = foto
  document.body.style.overflow = 'hidden'
}

function cerrarLightbox() {
  lightboxFoto.value = null
  lightboxIndex.value = -1
  document.body.style.overflow = 'auto'
}

function navegarLightbox(direccion) {
  const nuevoIndex = lightboxIndex.value + direccion
  if (nuevoIndex >= 0 && nuevoIndex < fotos.value.length) {
    lightboxIndex.value = nuevoIndex
    lightboxFoto.value = fotos.value[nuevoIndex]
  }
}

// Navegación con teclado
function handleKeydown(e) {
  if (!lightboxFoto.value) return

  if (e.key === 'Escape') {
    cerrarLightbox()
  } else if (e.key === 'ArrowLeft') {
    navegarLightbox(-1)
  } else if (e.key === 'ArrowRight') {
    navegarLightbox(1)
  }
}

onMounted(async () => {
  try {
    fotos.value = await publicApi.getGaleria()
  } catch (err) {
    console.error('Error cargando galería:', err)
    error.value = 'Error al cargar la galería. Por favor, intenta de nuevo.'
  } finally {
    loading.value = false
  }

  // Event listener para teclado
  window.addEventListener('keydown', handleKeydown)
})
</script>

<style scoped>
.gallery-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
  gap: 1rem;
}

.gallery-item {
  position: relative;
  aspect-ratio: 1;
  overflow: hidden;
  border-radius: 8px;
  cursor: pointer;
  transition: transform 0.2s;
}

.gallery-item:hover {
  transform: scale(1.02);
}

.gallery-item img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.gallery-item .overlay {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: linear-gradient(to bottom, rgba(0,0,0,0) 0%, rgba(0,0,0,0.7) 100%);
  display: flex;
  align-items: flex-end;
  padding: 1rem;
  opacity: 0;
  transition: opacity 0.2s;
}

.gallery-item:hover .overlay {
  opacity: 1;
}

.overlay-content {
  width: 100%;
}

/* Lightbox */
.lightbox {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(0, 0, 0, 0.95);
  z-index: 9999;
  display: flex;
  align-items: center;
  justify-content: center;
  animation: fadeIn 0.2s;
}

@keyframes fadeIn {
  from { opacity: 0; }
  to { opacity: 1; }
}

.lightbox-content {
  position: relative;
  width: 100%;
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
}

.lightbox-image-wrapper {
  max-width: 90%;
  max-height: 90%;
  display: flex;
  flex-direction: column;
  align-items: center;
}

.lightbox-image {
  max-width: 100%;
  max-height: calc(100vh - 150px);
  object-fit: contain;
  border-radius: 8px;
}

.lightbox-caption {
  margin-top: 1rem;
  text-align: center;
}

.lightbox-close {
  position: absolute;
  top: 20px;
  right: 20px;
  background: rgba(255, 255, 255, 0.1);
  border: none;
  color: white;
  font-size: 2rem;
  width: 50px;
  height: 50px;
  border-radius: 50%;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: background 0.2s;
  z-index: 10000;
}

.lightbox-close:hover {
  background: rgba(255, 255, 255, 0.2);
}

.lightbox-nav {
  position: absolute;
  top: 50%;
  transform: translateY(-50%);
  background: rgba(255, 255, 255, 0.1);
  border: none;
  color: white;
  font-size: 2rem;
  width: 50px;
  height: 50px;
  border-radius: 50%;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: background 0.2s;
}

.lightbox-nav:hover {
  background: rgba(255, 255, 255, 0.2);
}

.lightbox-prev {
  left: 20px;
}

.lightbox-next {
  right: 20px;
}

@media (max-width: 768px) {
  .gallery-grid {
    grid-template-columns: repeat(auto-fill, minmax(150px, 1fr));
    gap: 0.5rem;
  }

  .lightbox-nav,
  .lightbox-close {
    width: 40px;
    height: 40px;
    font-size: 1.5rem;
  }
}
</style>