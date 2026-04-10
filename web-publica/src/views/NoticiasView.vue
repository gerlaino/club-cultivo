<template>
  <div class="nv">

    <section class="nv__hero">
      <div class="nv__hero-inner">
        <h1 class="nv__hero-title">Noticias <span class="nv__hero-accent">del club</span></h1>
        <p class="nv__hero-sub">Novedades, anuncios y actualizaciones del ecosistema cannábico medicinal.</p>
      </div>
    </section>

    <section class="nv__section">
      <div class="nv__container">

        <div v-if="loading" class="nv__loading"><div class="nv__spinner"></div></div>

        <div v-else-if="noticias.length === 0" class="nv__empty">
          No hay noticias publicadas todavía.
        </div>

        <div v-else>
          <!-- Noticia destacada (primera) -->
          <RouterLink :to="`/noticias/${noticias[0].id}`" class="nv__destacada">
            <div class="nv__destacada-img">
              <img v-if="noticias[0].cover_url" :src="noticias[0].cover_url" :alt="noticias[0].titulo" />
              <div v-else class="nv__destacada-img-placeholder">📰</div>
            </div>
            <div class="nv__destacada-body">
              <div class="nv__destacada-badge">Última novedad</div>
              <h2 class="nv__destacada-titulo">{{ noticias[0].titulo }}</h2>
              <p class="nv__destacada-preview">{{ truncate(noticias[0].preview || noticias[0].contenido, 200) }}</p>
              <div class="nv__destacada-footer">
                <span class="nv__fecha">{{ formatFecha(noticias[0].publicada_at) }}</span>
                <span class="nv__leer-mas">Leer más <i class="bi bi-arrow-right"></i></span>
              </div>
            </div>
          </RouterLink>

          <!-- Resto de noticias -->
          <div v-if="noticias.length > 1" class="nv__grid">
            <RouterLink
                v-for="n in noticias.slice(1)" :key="n.id"
                :to="`/noticias/${n.id}`"
                class="nv__card"
            >
              <div class="nv__card-img">
                <img v-if="n.cover_url" :src="n.cover_url" :alt="n.titulo" />
                <div v-else class="nv__card-img-placeholder">📰</div>
              </div>
              <div class="nv__card-body">
                <div class="nv__fecha">{{ formatFecha(n.publicada_at) }}</div>
                <div class="nv__card-titulo">{{ n.titulo }}</div>
                <div class="nv__card-preview">{{ truncate(n.preview || n.contenido, 100) }}</div>
              </div>
              <div class="nv__card-footer">
                Leer más <i class="bi bi-arrow-right"></i>
              </div>
            </RouterLink>
          </div>
        </div>

      </div>
    </section>

  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import publicApi from '../api/publicApi.js'

const noticias = ref([])
const loading  = ref(true)

function formatFecha(fecha) {
  if (!fecha) return ''
  return new Date(fecha).toLocaleDateString('es-AR', { day: 'numeric', month: 'long', year: 'numeric' })
}
function truncate(text, len) {
  return text && text.length > len ? text.slice(0, len) + '...' : text
}

onMounted(async () => {
  try { noticias.value = await publicApi.getNoticias() }
  catch (e) { console.error(e) }
  finally { loading.value = false }
})
</script>

<style scoped>
.nv { min-height: 100vh; background: #f0fdf4; }

.nv__hero { background: #060f07; padding: 5rem 2rem 4rem; position: relative; overflow: hidden; }
.nv__hero::before {
  content: ''; position: absolute; inset: 0;
  background: radial-gradient(ellipse at 40% 50%, #1b5e2018 0%, transparent 65%);
}
.nv__hero-inner { max-width: 1200px; margin: 0 auto; position: relative; z-index: 1; }
.nv__hero-title { color: #f0fdf4; font-size: 40px; font-weight: 500; margin-bottom: 1rem; }
.nv__hero-accent { color: #66bb6a; }
.nv__hero-sub { color: #81c784; font-size: 16px; opacity: .8; margin: 0; max-width: 500px; }

.nv__section { padding: 3.5rem 0; }
.nv__container { max-width: 1200px; margin: 0 auto; padding: 0 2rem; }

.nv__loading { display: flex; justify-content: center; padding: 4rem; }
.nv__spinner {
  width: 32px; height: 32px; border: 2px solid #d4edda; border-top-color: #1b5e20;
  border-radius: 50%; animation: spin .7s linear infinite;
}
@keyframes spin { to { transform: rotate(360deg); } }
.nv__empty { text-align: center; color: #4a7c59; padding: 4rem; font-size: 15px; }

/* Destacada */
.nv__destacada {
  display: grid; grid-template-columns: 1fr 1fr; gap: 0;
  background: white; border: 1px solid #d4edda; border-radius: 20px;
  overflow: hidden; text-decoration: none; margin-bottom: 2.5rem;
  transition: box-shadow .2s;
}
.nv__destacada:hover { box-shadow: 0 12px 40px #1b5e2015; }
.nv__destacada-img {
  min-height: 380px; background: linear-gradient(135deg, #e8f5e9, #c8e6c9);
  display: flex; align-items: center; justify-content: center; overflow: hidden;
}
.nv__destacada-img img { width: 100%; height: 100%; object-fit: cover; }
.nv__destacada-img-placeholder { font-size: 5rem; }
.nv__destacada-body {
  padding: 2.5rem; display: flex; flex-direction: column; justify-content: center;
}
.nv__destacada-badge {
  display: inline-block; background: #e8f5e9; color: #1b5e20;
  font-size: 11px; font-weight: 600; padding: 4px 12px;
  border-radius: 12px; margin-bottom: 1rem; text-transform: uppercase; letter-spacing: .06em;
}
.nv__destacada-titulo { font-size: 24px; font-weight: 600; color: #1a2e1b; margin-bottom: 1rem; line-height: 1.3; }
.nv__destacada-preview { font-size: 15px; color: #4a7c59; line-height: 1.7; margin-bottom: 1.5rem; flex: 1; }
.nv__destacada-footer { display: flex; justify-content: space-between; align-items: center; }

/* Cards */
.nv__grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 20px; }
.nv__card {
  background: white; border: 1px solid #d4edda; border-radius: 16px; overflow: hidden;
  text-decoration: none; display: flex; flex-direction: column;
  transition: transform .2s, box-shadow .2s;
}
.nv__card:hover { transform: translateY(-4px); box-shadow: 0 8px 28px #1b5e2012; }
.nv__card-img {
  height: 180px; background: linear-gradient(135deg, #e8f5e9, #c8e6c9);
  display: flex; align-items: center; justify-content: center; overflow: hidden;
}
.nv__card-img img { width: 100%; height: 100%; object-fit: cover; }
.nv__card-img-placeholder { font-size: 3rem; }
.nv__card-body { padding: 16px; flex: 1; }
.nv__card-titulo { font-size: 15px; font-weight: 600; color: #1a2e1b; margin: 6px 0 8px; line-height: 1.3; }
.nv__card-preview { font-size: 13px; color: #4a7c59; line-height: 1.55; }
.nv__card-footer {
  padding: 12px 16px; border-top: 1px solid #f0fdf4;
  font-size: 13px; color: #1b5e20; font-weight: 500;
  display: flex; align-items: center; justify-content: flex-end; gap: 6px;
}
.nv__fecha { font-size: 12px; color: #1b5e20; }
.nv__leer-mas { font-size: 13px; color: #1b5e20; font-weight: 500; display: flex; align-items: center; gap: 5px; }

@media (max-width: 900px) {
  .nv__destacada { grid-template-columns: 1fr; }
  .nv__destacada-img { min-height: 240px; }
  .nv__grid { grid-template-columns: repeat(2, 1fr); }
}
@media (max-width: 600px) {
  .nv__grid { grid-template-columns: 1fr; }
  .nv__hero-title { font-size: 28px; }
}
</style>