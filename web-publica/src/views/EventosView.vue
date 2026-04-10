<template>
  <div class="ev">

    <section class="ev__hero">
      <div class="ev__hero-inner">
        <h1 class="ev__hero-title">Eventos <span class="ev__hero-accent">del club</span></h1>
        <p class="ev__hero-sub">Talleres, charlas y actividades. Participá de nuestra comunidad.</p>
      </div>
    </section>

    <section class="ev__section">
      <div class="ev__container">

        <div v-if="loading" class="ev__loading"><div class="ev__spinner"></div></div>

        <div v-else-if="eventos.length === 0" class="ev__empty">
          <i class="bi bi-calendar-x" style="font-size:3rem;opacity:.3;display:block;margin-bottom:1rem"></i>
          No hay eventos próximos por el momento.
        </div>

        <div v-else class="ev__lista">
          <div v-for="e in eventos" :key="e.id" class="ev__card">

            <div class="ev__card-fecha">
              <div class="ev__dia">{{ getDia(e.fecha_inicio) }}</div>
              <div class="ev__mes">{{ getMes(e.fecha_inicio) }}</div>
              <div class="ev__anio">{{ getAnio(e.fecha_inicio) }}</div>
            </div>

            <div class="ev__card-img" v-if="e.imagen_url">
              <img :src="e.imagen_url" :alt="e.titulo" />
            </div>
            <div class="ev__card-img ev__card-img--placeholder" v-else>
              <i class="bi bi-calendar-event"></i>
            </div>

            <div class="ev__card-body">
              <h2 class="ev__card-titulo">{{ e.titulo }}</h2>
              <div class="ev__card-meta">
                <span v-if="e.lugar"><i class="bi bi-geo-alt"></i> {{ e.lugar }}</span>
                <span><i class="bi bi-clock"></i> {{ getHora(e.fecha_inicio) }}</span>
                <span v-if="e.fecha_fin"><i class="bi bi-arrow-right"></i> {{ getHora(e.fecha_fin) }}</span>
              </div>
              <p v-if="e.descripcion" class="ev__card-desc">{{ e.descripcion }}</p>
            </div>

            <div class="ev__card-cta">
              <RouterLink to="/contacto" class="ev__inscribirse-btn">
                Anotarme <i class="bi bi-arrow-right"></i>
              </RouterLink>
            </div>

          </div>
        </div>

      </div>
    </section>

  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import publicApi from '../api/publicApi.js'

const eventos = ref([])
const loading = ref(true)

function getDia(f)  { return f ? new Date(f).getDate() : '' }
function getMes(f)  { return f ? new Date(f).toLocaleDateString('es-AR', { month: 'short' }).toUpperCase() : '' }
function getAnio(f) { return f ? new Date(f).getFullYear() : '' }
function getHora(f) { return f ? new Date(f).toLocaleTimeString('es-AR', { hour: '2-digit', minute: '2-digit' }) : '' }

onMounted(async () => {
  try { eventos.value = await publicApi.getEventos() }
  catch (e) { console.error(e) }
  finally { loading.value = false }
})
</script>

<style scoped>
.ev { min-height: 100vh; background: #f0fdf4; }

.ev__hero { background: #060f07; padding: 5rem 2rem 4rem; position: relative; overflow: hidden; }
.ev__hero::before {
  content: ''; position: absolute; inset: 0;
  background: radial-gradient(ellipse at 50% 50%, #1b5e2018 0%, transparent 65%);
}
.ev__hero-inner { max-width: 1200px; margin: 0 auto; position: relative; z-index: 1; }
.ev__hero-title { color: #f0fdf4; font-size: 40px; font-weight: 500; margin-bottom: 1rem; }
.ev__hero-accent { color: #66bb6a; }
.ev__hero-sub { color: #81c784; font-size: 16px; opacity: .8; margin: 0; }

.ev__section { padding: 3.5rem 0; }
.ev__container { max-width: 1200px; margin: 0 auto; padding: 0 2rem; }

.ev__loading { display: flex; justify-content: center; padding: 4rem; }
.ev__spinner {
  width: 32px; height: 32px; border: 2px solid #d4edda; border-top-color: #1b5e20;
  border-radius: 50%; animation: spin .7s linear infinite;
}
@keyframes spin { to { transform: rotate(360deg); } }
.ev__empty { text-align: center; color: #4a7c59; padding: 4rem; font-size: 15px; }

.ev__lista { display: flex; flex-direction: column; gap: 16px; }
.ev__card {
  background: white; border: 1px solid #d4edda; border-radius: 18px;
  display: flex; gap: 0; overflow: hidden;
  transition: box-shadow .2s;
}
.ev__card:hover { box-shadow: 0 8px 32px #1b5e2012; }

.ev__card-fecha {
  background: linear-gradient(180deg, #1b5e20, #2e7d32);
  padding: 1.5rem 1.25rem; text-align: center; min-width: 90px;
  display: flex; flex-direction: column; align-items: center; justify-content: center;
  flex-shrink: 0;
}
.ev__dia { color: #e8f5e9; font-size: 36px; font-weight: 700; line-height: 1; }
.ev__mes { color: #a5d6a7; font-size: 12px; text-transform: uppercase; letter-spacing: .08em; margin-top: 4px; }
.ev__anio { color: #4a7c59; font-size: 11px; margin-top: 2px; }

.ev__card-img {
  width: 180px; flex-shrink: 0; overflow: hidden;
  background: linear-gradient(135deg, #e8f5e9, #c8e6c9);
}
.ev__card-img img { width: 100%; height: 100%; object-fit: cover; }
.ev__card-img--placeholder {
  display: flex; align-items: center; justify-content: center; font-size: 2.5rem; opacity: .3;
}

.ev__card-body { padding: 1.5rem 1.75rem; flex: 1; }
.ev__card-titulo { font-size: 20px; font-weight: 600; color: #1a2e1b; margin-bottom: .75rem; line-height: 1.3; }
.ev__card-meta {
  display: flex; gap: 16px; font-size: 13px; color: #4a7c59;
  margin-bottom: 1rem; flex-wrap: wrap;
}
.ev__card-meta span { display: flex; align-items: center; gap: 5px; }
.ev__card-desc { font-size: 14px; color: #4a7c59; line-height: 1.65; margin: 0; }

.ev__card-cta {
  padding: 1.5rem; display: flex; align-items: center; flex-shrink: 0;
}
.ev__inscribirse-btn {
  display: flex; align-items: center; gap: 7px;
  background: linear-gradient(135deg, #1b5e20, #2e7d32);
  color: #e8f5e9; padding: 11px 20px; border-radius: 10px;
  font-size: 13px; text-decoration: none; white-space: nowrap;
  transition: opacity .2s; box-shadow: 0 2px 8px #1b5e2030;
}
.ev__inscribirse-btn:hover { opacity: .88; color: #e8f5e9; }

@media (max-width: 768px) {
  .ev__card { flex-direction: column; }
  .ev__card-fecha { flex-direction: row; gap: 10px; padding: 1rem 1.5rem; min-width: unset; }
  .ev__dia { font-size: 26px; }
  .ev__card-img { width: 100%; height: 180px; }
  .ev__card-cta { padding: 0 1.5rem 1.5rem; }
  .ev__hero-title { font-size: 28px; }
}
</style>