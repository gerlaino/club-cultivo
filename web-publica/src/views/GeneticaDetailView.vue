<template>
  <div class="gdv" v-if="genetica">

    <!-- Breadcrumb -->
    <div class="gdv__breadcrumb">
      <div class="gdv__container">
        <RouterLink to="/geneticas" class="gdv__back">
          <i class="bi bi-arrow-left"></i> Volver a variedades
        </RouterLink>
      </div>
    </div>

    <!-- Hero de la genética -->
    <section class="gdv__hero">
      <div class="gdv__container gdv__hero-layout">

        <div class="gdv__hero-img">
          <img v-if="genetica.fotos_urls?.length" :src="genetica.fotos_urls[0]" :alt="genetica.nombre" />
          <div v-else class="gdv__hero-img-placeholder">🌿</div>
        </div>

        <div class="gdv__hero-info">
          <div class="gdv__hero-badges">
            <span class="gdv__tipo-badge" :class="`gdv__tipo-badge--${genetica.tipo}`">{{ formatTipo(genetica.tipo) }}</span>
            <span v-if="genetica.registrada_inase" class="gdv__inase-badge">★ Registrada INASE</span>
          </div>
          <h1 class="gdv__nombre">{{ genetica.nombre }}</h1>
          <p v-if="genetica.criador" class="gdv__criador">
            <i class="bi bi-person"></i> {{ genetica.criador }}
          </p>
          <p v-if="genetica.origen" class="gdv__origen">
            <i class="bi bi-geo-alt"></i> {{ genetica.origen }}
          </p>
          <p class="gdv__descripcion">{{ genetica.descripcion }}</p>

          <!-- Stats principales -->
          <div class="gdv__stats-grid">
            <div class="gdv__stat-card">
              <span class="gdv__stat-label">THC</span>
              <span class="gdv__stat-val">{{ genetica.thc }}%</span>
            </div>
            <div class="gdv__stat-card gdv__stat-card--cbd">
              <span class="gdv__stat-label">CBD</span>
              <span class="gdv__stat-val gdv__stat-val--cbd">{{ genetica.cbd }}%</span>
            </div>
            <div v-if="genetica.tiempo_floracion" class="gdv__stat-card">
              <span class="gdv__stat-label">Floración</span>
              <span class="gdv__stat-val">{{ genetica.tiempo_floracion }} días</span>
            </div>
            <div v-if="genetica.rendimiento" class="gdv__stat-card">
              <span class="gdv__stat-label">Rendimiento</span>
              <span class="gdv__stat-val">{{ genetica.rendimiento }}g/m²</span>
            </div>
            <div v-if="genetica.altura" class="gdv__stat-card">
              <span class="gdv__stat-label">Altura</span>
              <span class="gdv__stat-val">{{ genetica.altura }}cm</span>
            </div>
            <div v-if="genetica.dificultad" class="gdv__stat-card">
              <span class="gdv__stat-label">Dificultad</span>
              <span class="gdv__stat-val">{{ formatDificultad(genetica.dificultad) }}</span>
            </div>
          </div>

          <!-- Terpenos -->
          <div v-if="genetica.terpenos" class="gdv__terpenos">
            <div class="gdv__terpenos-label">Perfil de terpenos</div>
            <div class="gdv__terpenos-list">
              <span v-for="t in genetica.terpenos.split(',')" :key="t" class="gdv__terpeno-pill">
                {{ t.trim() }}
              </span>
            </div>
          </div>
        </div>

      </div>
    </section>

    <!-- CTA -->
    <section class="gdv__cta">
      <div class="gdv__container">
        <div class="gdv__cta-inner">
          <div>
            <h2 class="gdv__cta-title">¿Querés acceder a esta variedad?</h2>
            <p class="gdv__cta-sub">Asociate al club con tu autorización REPROCANN.</p>
          </div>
          <RouterLink to="/contacto" class="gdv__cta-btn">Contactanos</RouterLink>
        </div>
      </div>
    </section>

  </div>

  <div v-else-if="loading" class="gdv__loading-page">
    <div class="gdv__spinner"></div>
  </div>

  <div v-else class="gdv__not-found">
    <p>Variedad no encontrada.</p>
    <RouterLink to="/geneticas">Volver al catálogo</RouterLink>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import publicApi from '../api/publicApi.js'

const route    = useRoute()
const genetica = ref(null)
const loading  = ref(true)

function formatTipo(tipo) {
  return { indica: 'Índica', sativa: 'Sativa', hibrida: 'Híbrida' }[tipo] || tipo
}
function formatDificultad(d) {
  return { facil: 'Fácil', intermedia: 'Intermedia', dificil: 'Difícil' }[d] || d
}

onMounted(async () => {
  try {
    genetica.value = await publicApi.getGenetica(route.params.id)
  } catch (e) { console.error(e) }
  finally { loading.value = false }
})
</script>

<style scoped>
.gdv { min-height: 100vh; background: #f0fdf4; }

.gdv__breadcrumb { background: #060f07; padding: .75rem 0; border-bottom: 1px solid #1b5e2022; }
.gdv__container { max-width: 1200px; margin: 0 auto; padding: 0 2rem; }
.gdv__back {
  display: inline-flex; align-items: center; gap: 8px;
  color: #66bb6a; font-size: 14px; text-decoration: none; transition: opacity .2s;
}
.gdv__back:hover { opacity: .8; color: #66bb6a; }

.gdv__hero { background: #060f07; padding: 3rem 0 4rem; }
.gdv__hero-layout {
  display: grid; grid-template-columns: 400px 1fr; gap: 3rem; align-items: start;
}
.gdv__hero-img {
  border-radius: 20px; overflow: hidden; aspect-ratio: 1;
  background: linear-gradient(135deg, #1b5e2030, #2e7d3220);
  display: flex; align-items: center; justify-content: center;
}
.gdv__hero-img img { width: 100%; height: 100%; object-fit: cover; }
.gdv__hero-img-placeholder { font-size: 6rem; }

.gdv__hero-info { padding-top: .5rem; }
.gdv__hero-badges { display: flex; gap: 8px; margin-bottom: 1rem; flex-wrap: wrap; }
.gdv__tipo-badge { display: inline-block; font-size: 12px; padding: 4px 12px; border-radius: 6px; font-weight: 500; }
.gdv__tipo-badge--indica  { background: #e8eaf6; color: #3949ab; }
.gdv__tipo-badge--sativa  { background: #fff8e1; color: #f57f17; }
.gdv__tipo-badge--hibrida { background: #e8f5e9; color: #2e7d32; }
.gdv__inase-badge { background: #fff3e0; color: #bf360c; font-size: 12px; padding: 4px 12px; border-radius: 6px; font-weight: 600; }

.gdv__nombre { color: #f0fdf4; font-size: 36px; font-weight: 600; margin-bottom: .75rem; line-height: 1.1; }
.gdv__criador, .gdv__origen {
  color: #81c784; font-size: 14px; margin-bottom: .5rem; display: flex; align-items: center; gap: 7px; opacity: .8;
}
.gdv__descripcion { color: #a5d6a7; font-size: 15px; line-height: 1.7; margin: 1.25rem 0 1.75rem; opacity: .9; }

.gdv__stats-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 10px; margin-bottom: 1.5rem; }
.gdv__stat-card {
  background: #0d1f0e; border: 1px solid #1b5e2033; border-radius: 12px; padding: 14px 16px;
}
.gdv__stat-label { display: block; font-size: 10px; color: #4a7c59; text-transform: uppercase; letter-spacing: .08em; margin-bottom: 4px; }
.gdv__stat-val { display: block; font-size: 20px; font-weight: 600; color: #66bb6a; }
.gdv__stat-val--cbd { color: #4fc3f7; }

.gdv__terpenos { margin-top: .5rem; }
.gdv__terpenos-label { font-size: 12px; color: #4a7c59; text-transform: uppercase; letter-spacing: .08em; margin-bottom: 8px; }
.gdv__terpenos-list { display: flex; gap: 8px; flex-wrap: wrap; }
.gdv__terpeno-pill {
  background: #1b5e2022; border: 1px solid #1b5e2044;
  color: #81c784; font-size: 12px; padding: 4px 12px; border-radius: 12px;
}

.gdv__cta { background: #060f07; padding: 3rem 0; border-top: 1px solid #1b5e2022; }
.gdv__cta-inner {
  display: flex; justify-content: space-between; align-items: center;
  background: #0d1f0e; border: 1px solid #1b5e2033; border-radius: 16px; padding: 2rem 2.5rem;
}
.gdv__cta-title { color: #f0fdf4; font-size: 20px; font-weight: 500; margin-bottom: 6px; }
.gdv__cta-sub { color: #81c784; font-size: 14px; opacity: .8; margin: 0; }
.gdv__cta-btn {
  background: linear-gradient(135deg, #1b5e20, #2e7d32);
  color: #e8f5e9; padding: 13px 28px; border-radius: 10px;
  font-size: 14px; text-decoration: none; flex-shrink: 0; transition: opacity .2s;
}
.gdv__cta-btn:hover { opacity: .88; color: #e8f5e9; }

.gdv__loading-page, .gdv__not-found {
  min-height: 60vh; display: flex; flex-direction: column;
  align-items: center; justify-content: center; gap: 1rem;
}
.gdv__spinner {
  width: 36px; height: 36px; border: 2px solid #d4edda; border-top-color: #1b5e20;
  border-radius: 50%; animation: spin .7s linear infinite;
}
@keyframes spin { to { transform: rotate(360deg); } }

@media (max-width: 900px) {
  .gdv__hero-layout { grid-template-columns: 1fr; }
  .gdv__hero-img { max-width: 300px; margin: 0 auto; }
  .gdv__cta-inner { flex-direction: column; gap: 1.5rem; text-align: center; }
  .gdv__stats-grid { grid-template-columns: repeat(2, 1fr); }
}
@media (max-width: 600px) {
  .gdv__nombre { font-size: 26px; }
  .gdv__stats-grid { grid-template-columns: repeat(2, 1fr); }
}
</style>