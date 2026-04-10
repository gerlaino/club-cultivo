<template>
  <div class="ndv" v-if="noticia">

    <div class="ndv__breadcrumb">
      <div class="ndv__container">
        <RouterLink to="/noticias" class="ndv__back">
          <i class="bi bi-arrow-left"></i> Volver a noticias
        </RouterLink>
      </div>
    </div>

    <section class="ndv__hero">
      <div class="ndv__container">
        <div class="ndv__fecha">{{ formatFecha(noticia.publicada_at) }}</div>
        <h1 class="ndv__titulo">{{ noticia.titulo }}</h1>
      </div>
    </section>

    <section class="ndv__body">
      <div class="ndv__container ndv__layout">
        <article class="ndv__article">
          <div v-if="noticia.cover_url" class="ndv__cover">
            <img :src="noticia.cover_url" :alt="noticia.titulo" />
          </div>
          <div class="ndv__contenido">{{ noticia.contenido }}</div>
        </article>
        <aside class="ndv__aside">
          <div class="ndv__aside-card">
            <div class="ndv__aside-title">¿Querés saber más?</div>
            <p class="ndv__aside-text">Asociate al club y accedé a cannabis medicinal de calidad.</p>
            <RouterLink to="/contacto" class="ndv__aside-btn">Contactanos</RouterLink>
          </div>
        </aside>
      </div>
    </section>

  </div>

  <div v-else-if="loading" class="ndv__loading">
    <div class="ndv__spinner"></div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import publicApi from '../api/publicApi.js'

const route   = useRoute()
const noticia = ref(null)
const loading = ref(true)

function formatFecha(fecha) {
  if (!fecha) return ''
  return new Date(fecha).toLocaleDateString('es-AR', { day: 'numeric', month: 'long', year: 'numeric' })
}

onMounted(async () => {
  try { noticia.value = await publicApi.getNoticia(route.params.id) }
  catch (e) { console.error(e) }
  finally { loading.value = false }
})
</script>

<style scoped>
.ndv { min-height: 100vh; background: #f0fdf4; }
.ndv__container { max-width: 1200px; margin: 0 auto; padding: 0 2rem; }

.ndv__breadcrumb { background: #060f07; padding: .75rem 0; border-bottom: 1px solid #1b5e2022; }
.ndv__back {
  display: inline-flex; align-items: center; gap: 8px;
  color: #66bb6a; font-size: 14px; text-decoration: none; transition: opacity .2s;
}
.ndv__back:hover { opacity: .8; color: #66bb6a; }

.ndv__hero { background: #060f07; padding: 3rem 0 4rem; }
.ndv__fecha { font-size: 13px; color: #66bb6a; margin-bottom: .75rem; }
.ndv__titulo { color: #f0fdf4; font-size: 36px; font-weight: 600; line-height: 1.2; max-width: 800px; margin: 0; }

.ndv__body { padding: 3rem 0 4rem; }
.ndv__layout { display: grid; grid-template-columns: 1fr 280px; gap: 3rem; align-items: start; }

.ndv__cover {
  border-radius: 16px; overflow: hidden; margin-bottom: 2rem; max-height: 420px;
}
.ndv__cover img { width: 100%; height: 100%; object-fit: cover; }
.ndv__contenido {
  font-size: 16px; color: #2d4a30; line-height: 1.8;
  white-space: pre-wrap;
}

.ndv__aside { position: sticky; top: 80px; }
.ndv__aside-card {
  background: #060f07; border-radius: 16px; padding: 1.75rem;
  border: 1px solid #1b5e2033;
}
.ndv__aside-title { color: #f0fdf4; font-size: 16px; font-weight: 600; margin-bottom: .75rem; }
.ndv__aside-text { color: #81c784; font-size: 13px; line-height: 1.6; margin-bottom: 1.25rem; opacity: .8; }
.ndv__aside-btn {
  display: block; text-align: center;
  background: linear-gradient(135deg, #1b5e20, #2e7d32);
  color: #e8f5e9; padding: 11px; border-radius: 10px;
  font-size: 14px; text-decoration: none; transition: opacity .2s;
}
.ndv__aside-btn:hover { opacity: .88; color: #e8f5e9; }

.ndv__loading {
  min-height: 60vh; display: flex; align-items: center; justify-content: center;
}
.ndv__spinner {
  width: 36px; height: 36px; border: 2px solid #d4edda; border-top-color: #1b5e20;
  border-radius: 50%; animation: spin .7s linear infinite;
}
@keyframes spin { to { transform: rotate(360deg); } }

@media (max-width: 900px) {
  .ndv__layout { grid-template-columns: 1fr; }
  .ndv__aside { position: static; }
  .ndv__titulo { font-size: 26px; }
}
</style>