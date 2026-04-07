<template>
  <div class="hv">

    <!-- Hero -->
    <section class="hv__hero">
      <div class="hv__hero-bg"></div>
      <div class="hv__hero-inner">
        <div class="hv__hero-content">
          <div class="hv__hero-badge">
            <span class="hv__hero-badge-dot"></span>
            Registrado REPROCANN · Res. 1780/2025
          </div>
          <h1 class="hv__hero-title">
            Cannabis medicinal<br>
            de <span class="hv__hero-title-accent">calidad certificada</span>
          </h1>
          <p class="hv__hero-sub">
            Asociación civil sin fines de lucro dedicada al cultivo responsable y acceso legal para pacientes con autorización REPROCANN.
          </p>
          <div class="hv__hero-actions">
            <RouterLink to="/contacto" class="hv__btn-primary">Quiero asociarme</RouterLink>
            <RouterLink to="/geneticas" class="hv__btn-outline">Ver variedades</RouterLink>
          </div>
        </div>
      </div>
    </section>

    <!-- Variedades -->
    <section class="hv__section hv__section--light">
      <div class="hv__container">
        <div class="hv__section-header">
          <div>
            <h2 class="hv__section-title">Variedades disponibles</h2>
            <p class="hv__section-sub">Cultivadas con protocolo medicinal certificado</p>
          </div>
          <RouterLink to="/geneticas" class="hv__link-more">Ver todas →</RouterLink>
        </div>

        <div v-if="loadingGeneticas" class="hv__loading">
          <div class="hv__spinner"></div>
        </div>

        <div v-else class="hv__geneticas-grid">
          <div
              v-for="g in geneticas.slice(0, 3)"
              :key="g.id"
              class="hv__genetica-card"
          >
            <div class="hv__genetica-img">
              <img v-if="g.fotos_urls?.length" :src="g.fotos_urls[0]" :alt="g.nombre">
              <span v-else class="hv__genetica-placeholder">🌿</span>
            </div>
            <div class="hv__genetica-body">
              <div class="hv__genetica-header">
                <span class="hv__genetica-name">{{ g.nombre }}</span>
                <span v-if="g.registrada_inase" class="hv__inase-badge">INASE</span>
              </div>
              <span class="hv__genetica-tipo">{{ formatTipo(g.tipo) }}</span>
              <div class="hv__genetica-stats">
                <div class="hv__genetica-stat">
                  <span class="hv__genetica-stat-label">THC</span>
                  <span class="hv__genetica-stat-val">{{ g.thc }}%</span>
                </div>
                <div class="hv__genetica-stat">
                  <span class="hv__genetica-stat-label">CBD</span>
                  <span class="hv__genetica-stat-val">{{ g.cbd }}%</span>
                </div>
              </div>
              <RouterLink :to="`/geneticas/${g.id}`" class="hv__genetica-link">
                Ver detalles →
              </RouterLink>
            </div>
          </div>
        </div>
      </div>
    </section>

    <!-- Cómo asociarse -->
    <section class="hv__section">
      <div class="hv__container">
        <h2 class="hv__section-title hv__text-center">¿Cómo asociarse?</h2>
        <p class="hv__section-sub hv__text-center">Proceso simple, 100% legal</p>
        <div class="hv__pasos-grid">
          <div class="hv__paso" v-for="(paso, i) in pasos" :key="i">
            <div class="hv__paso-num">{{ i + 1 }}</div>
            <div class="hv__paso-title">{{ paso.titulo }}</div>
            <div class="hv__paso-desc">{{ paso.desc }}</div>
          </div>
        </div>
        <div class="hv__text-center" style="margin-top: 2.5rem;">
          <RouterLink to="/contacto" class="hv__btn-primary">Iniciar el proceso</RouterLink>
        </div>
      </div>
    </section>

    <!-- Noticias -->
    <section class="hv__section hv__section--light">
      <div class="hv__container">
        <div class="hv__section-header">
          <div>
            <h2 class="hv__section-title">Últimas noticias</h2>
            <p class="hv__section-sub">Novedades del club y del ecosistema cannábico</p>
          </div>
          <RouterLink to="/noticias" class="hv__link-more">Ver todas →</RouterLink>
        </div>

        <div v-if="loadingNoticias" class="hv__loading">
          <div class="hv__spinner"></div>
        </div>

        <div v-else class="hv__noticias-grid">
          <RouterLink
              v-for="n in noticias.slice(0, 4)"
              :key="n.id"
              :to="`/noticias/${n.id}`"
              class="hv__noticia-card"
          >
            <div class="hv__noticia-date">{{ formatFecha(n.publicada_at) }}</div>
            <div class="hv__noticia-title">{{ n.titulo }}</div>
            <div class="hv__noticia-preview">{{ n.preview }}</div>
            <span class="hv__noticia-link">Leer más →</span>
          </RouterLink>
        </div>
      </div>
    </section>

    <!-- Próximos eventos -->
    <section class="hv__section">
      <div class="hv__container">
        <div class="hv__section-header">
          <div>
            <h2 class="hv__section-title">Próximos eventos</h2>
            <p class="hv__section-sub">Talleres, charlas y actividades del club</p>
          </div>
          <RouterLink to="/eventos" class="hv__link-more">Ver todos →</RouterLink>
        </div>

        <div v-if="loadingEventos" class="hv__loading">
          <div class="hv__spinner"></div>
        </div>

        <div v-else-if="eventos.length === 0" class="hv__empty">
          No hay eventos próximos por el momento.
        </div>

        <div v-else class="hv__eventos-grid">
          <div v-for="e in eventos.slice(0, 3)" :key="e.id" class="hv__evento-card">
            <div class="hv__evento-fecha-col">
              <div class="hv__evento-dia">{{ formatDia(e.fecha_inicio) }}</div>
              <div class="hv__evento-mes">{{ formatMes(e.fecha_inicio) }}</div>
            </div>
            <div class="hv__evento-body">
              <div class="hv__evento-title">{{ e.titulo }}</div>
              <div class="hv__evento-meta">
                <span>🕐 {{ formatHora(e.fecha_inicio) }}</span>
                <span v-if="e.lugar">📍 {{ e.lugar }}</span>
              </div>
              <div class="hv__evento-desc">{{ e.descripcion }}</div>
            </div>
          </div>
        </div>
      </div>
    </section>

    <!-- CTA Final -->
    <section class="hv__cta">
      <div class="hv__cta-bg"></div>
      <div class="hv__cta-inner">
        <h2 class="hv__cta-title">¿Tenés autorización REPROCANN?</h2>
        <p class="hv__cta-sub">Accedé a cannabis medicinal de calidad certificada de forma legal y segura.</p>
        <RouterLink to="/contacto" class="hv__btn-primary">Contactanos hoy</RouterLink>
      </div>
    </section>

  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import publicApi from '../api/publicApi.js'

const geneticas = ref([])
const noticias = ref([])
const eventos = ref([])
const loadingGeneticas = ref(true)
const loadingNoticias = ref(true)
const loadingEventos = ref(true)

const pasos = [
  { titulo: 'Obtené tu REPROCANN', desc: 'Consultá con un médico habilitado para tramitar tu autorización en el Ministerio de Salud.' },
  { titulo: 'Contactanos', desc: 'Escribinos con tu número de REPROCANN para iniciar el proceso de vinculación al club.' },
  { titulo: 'Firmá la declaración', desc: 'Autorizás al club a abastecerte. Podés seguir cultivando de forma complementaria.' },
  { titulo: 'Recibí tu medicina', desc: 'Coordinás las dispensaciones según tu necesidad, sin límite de pedidos.' },
]

function formatTipo(tipo) {
  return { indica: 'Índica', sativa: 'Sativa', hibrida: 'Híbrida' }[tipo] || tipo
}

function formatFecha(fecha) {
  if (!fecha) return ''
  return new Date(fecha).toLocaleDateString('es-AR', { day: 'numeric', month: 'long', year: 'numeric' })
}

function formatDia(fecha) {
  return new Date(fecha).getDate()
}

function formatMes(fecha) {
  return new Date(fecha).toLocaleDateString('es-AR', { month: 'short' }).toUpperCase()
}

function formatHora(fecha) {
  return new Date(fecha).toLocaleTimeString('es-AR', { hour: '2-digit', minute: '2-digit' })
}

onMounted(async () => {
  try {
    geneticas.value = await publicApi.getGeneticas()
  } catch (e) { console.error(e) }
  finally { loadingGeneticas.value = false }

  try {
    noticias.value = await publicApi.getNoticias()
  } catch (e) { console.error(e) }
  finally { loadingNoticias.value = false }

  try {
    eventos.value = await publicApi.getEventos()
  } catch (e) { console.error(e) }
  finally { loadingEventos.value = false }
})
</script>

<style scoped>
.hv {
  min-height: 100vh;
}

/* Hero */
.hv__hero {
  background: #060f07;
  min-height: 520px;
  display: flex;
  align-items: center;
  position: relative;
  overflow: hidden;
}

.hv__hero-bg {
  position: absolute;
  inset: 0;
  background:
      radial-gradient(ellipse at 75% 50%, #1b5e2018 0%, transparent 65%),
      radial-gradient(ellipse at 20% 80%, #2e7d3210 0%, transparent 50%);
}

.hv__hero-inner {
  max-width: 1200px;
  margin: 0 auto;
  padding: 5rem 2rem 4rem;
  position: relative;
  z-index: 1;
  width: 100%;
}

.hv__hero-content {
  max-width: 560px;
}

.hv__hero-badge {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  background: #1b5e2020;
  border: 1px solid #1b5e2044;
  color: #66bb6a;
  font-size: 12px;
  padding: 5px 14px;
  border-radius: 20px;
  margin-bottom: 1.75rem;
}

.hv__hero-badge-dot {
  width: 6px;
  height: 6px;
  background: #66bb6a;
  border-radius: 50%;
  flex-shrink: 0;
}

.hv__hero-title {
  color: #f0fdf4;
  font-size: 44px;
  font-weight: 500;
  line-height: 1.15;
  margin-bottom: 1.25rem;
}

.hv__hero-title-accent {
  color: #66bb6a;
}

.hv__hero-sub {
  color: #81c784;
  font-size: 16px;
  line-height: 1.65;
  margin-bottom: 2rem;
  opacity: 0.8;
  max-width: 480px;
}

.hv__hero-actions {
  display: flex;
  gap: 12px;
  flex-wrap: wrap;
}

/* Botones */
.hv__btn-primary {
  background: linear-gradient(135deg, #1b5e20, #2e7d32);
  color: #e8f5e9;
  padding: 13px 28px;
  border-radius: 10px;
  font-size: 14px;
  text-decoration: none;
  transition: opacity 0.2s;
  display: inline-block;
}

.hv__btn-primary:hover {
  opacity: 0.88;
}

.hv__btn-outline {
  background: transparent;
  color: #66bb6a;
  border: 1px solid #1b5e20;
  padding: 13px 28px;
  border-radius: 10px;
  font-size: 14px;
  text-decoration: none;
  transition: background 0.2s;
  display: inline-block;
}

.hv__btn-outline:hover {
  background: #1b5e2015;
}

/* Secciones */
.hv__section {
  padding: 4rem 0;
}

.hv__section--light {
  background: #f0fdf4;
}

.hv__container {
  max-width: 1200px;
  margin: 0 auto;
  padding: 0 2rem;
}

.hv__section-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-end;
  margin-bottom: 2rem;
}

.hv__section-title {
  font-size: 22px;
  font-weight: 500;
  color: #1a2e1b;
  margin-bottom: 4px;
}

.hv__section--light .hv__section-title {
  color: #1a2e1b;
}

.hv__section:not(.hv__section--light) .hv__section-title {
  color: #1a2e1b;
}

.hv__section-sub {
  font-size: 14px;
  color: #4a7c59;
  margin: 0;
}

.hv__link-more {
  color: #1b5e20;
  font-size: 13px;
  text-decoration: none;
  white-space: nowrap;
}

.hv__link-more:hover {
  text-decoration: underline;
}

.hv__text-center { text-align: center; }

/* Loading */
.hv__loading {
  display: flex;
  justify-content: center;
  padding: 3rem;
}

.hv__spinner {
  width: 28px;
  height: 28px;
  border: 2px solid #e8f5e9;
  border-top-color: #1b5e20;
  border-radius: 50%;
  animation: spin 0.7s linear infinite;
}

@keyframes spin { to { transform: rotate(360deg); } }

.hv__empty {
  text-align: center;
  color: #4a7c59;
  padding: 3rem;
  font-size: 14px;
}

/* Genéticas */
.hv__geneticas-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 20px;
}

.hv__genetica-card {
  background: #fff;
  border: 1px solid #d4edda;
  border-radius: 14px;
  overflow: hidden;
  transition: transform 0.2s, box-shadow 0.2s;
}

.hv__genetica-card:hover {
  transform: translateY(-4px);
  box-shadow: 0 8px 24px #1b5e2012;
}

.hv__genetica-img {
  height: 160px;
  background: linear-gradient(135deg, #e8f5e9, #c8e6c9);
  display: flex;
  align-items: center;
  justify-content: center;
  overflow: hidden;
}

.hv__genetica-img img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.hv__genetica-placeholder {
  font-size: 48px;
}

.hv__genetica-body {
  padding: 16px;
}

.hv__genetica-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  margin-bottom: 6px;
}

.hv__genetica-name {
  font-size: 15px;
  font-weight: 500;
  color: #1a2e1b;
}

.hv__inase-badge {
  background: #fff3e0;
  color: #e65100;
  font-size: 10px;
  padding: 2px 8px;
  border-radius: 4px;
  font-weight: 500;
  flex-shrink: 0;
}

.hv__genetica-tipo {
  display: inline-block;
  background: #e8f5e9;
  color: #1b5e20;
  font-size: 11px;
  padding: 2px 10px;
  border-radius: 4px;
  margin-bottom: 12px;
}

.hv__genetica-stats {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 8px;
  margin-bottom: 14px;
}

.hv__genetica-stat {
  background: #f8fafc;
  border-radius: 8px;
  padding: 8px 10px;
}

.hv__genetica-stat-label {
  display: block;
  font-size: 10px;
  color: #6b8f71;
  text-transform: uppercase;
  letter-spacing: 0.05em;
}

.hv__genetica-stat-val {
  display: block;
  font-size: 16px;
  font-weight: 500;
  color: #1b5e20;
}

.hv__genetica-link {
  color: #1b5e20;
  font-size: 13px;
  text-decoration: none;
}

.hv__genetica-link:hover {
  text-decoration: underline;
}

/* Pasos */
.hv__pasos-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 24px;
  margin-top: 2rem;
}

.hv__paso {
  text-align: center;
  padding: 1.5rem 1rem;
  background: #f8fdf8;
  border: 1px solid #e8f5e9;
  border-radius: 14px;
}

.hv__paso-num {
  width: 44px;
  height: 44px;
  background: linear-gradient(135deg, #1b5e20, #2e7d32);
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  color: #e8f5e9;
  font-size: 17px;
  font-weight: 500;
  margin: 0 auto 14px;
}

.hv__paso-title {
  font-size: 14px;
  font-weight: 500;
  color: #1a2e1b;
  margin-bottom: 8px;
}

.hv__paso-desc {
  font-size: 13px;
  color: #4a7c59;
  line-height: 1.55;
}

/* Noticias */
.hv__noticias-grid {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 20px;
}

.hv__noticia-card {
  background: #fff;
  border: 1px solid #d4edda;
  border-radius: 14px;
  padding: 20px;
  text-decoration: none;
  display: block;
  transition: transform 0.2s, box-shadow 0.2s;
}

.hv__noticia-card:hover {
  transform: translateY(-3px);
  box-shadow: 0 6px 20px #1b5e2010;
}

.hv__noticia-date {
  font-size: 12px;
  color: #1b5e20;
  margin-bottom: 8px;
}

.hv__noticia-title {
  font-size: 16px;
  font-weight: 500;
  color: #1a2e1b;
  margin-bottom: 8px;
  line-height: 1.3;
}

.hv__noticia-preview {
  font-size: 13px;
  color: #4a7c59;
  line-height: 1.55;
  margin-bottom: 14px;
}

.hv__noticia-link {
  font-size: 13px;
  color: #1b5e20;
}

/* Eventos */
.hv__eventos-grid {
  display: flex;
  flex-direction: column;
  gap: 14px;
}

.hv__evento-card {
  background: #fff;
  border: 1px solid #d4edda;
  border-radius: 14px;
  padding: 20px;
  display: flex;
  gap: 20px;
  align-items: flex-start;
  transition: box-shadow 0.2s;
}

.hv__evento-card:hover {
  box-shadow: 0 4px 16px #1b5e2010;
}

.hv__evento-fecha-col {
  background: linear-gradient(135deg, #1b5e20, #2e7d32);
  border-radius: 10px;
  padding: 12px 16px;
  text-align: center;
  flex-shrink: 0;
  min-width: 60px;
}

.hv__evento-dia {
  color: #e8f5e9;
  font-size: 22px;
  font-weight: 500;
  line-height: 1;
}

.hv__evento-mes {
  color: #a5d6a7;
  font-size: 11px;
  margin-top: 4px;
}

.hv__evento-body {
  flex: 1;
}

.hv__evento-title {
  font-size: 15px;
  font-weight: 500;
  color: #1a2e1b;
  margin-bottom: 6px;
}

.hv__evento-meta {
  display: flex;
  gap: 16px;
  font-size: 12px;
  color: #4a7c59;
  margin-bottom: 8px;
}

.hv__evento-desc {
  font-size: 13px;
  color: #4a7c59;
  line-height: 1.5;
}

/* CTA Final */
.hv__cta {
  background: #060f07;
  padding: 5rem 2rem;
  text-align: center;
  position: relative;
  overflow: hidden;
}

.hv__cta-bg {
  position: absolute;
  inset: 0;
  background: radial-gradient(ellipse at 50% 50%, #1b5e2025 0%, transparent 70%);
}

.hv__cta-inner {
  position: relative;
  z-index: 1;
  max-width: 500px;
  margin: 0 auto;
}

.hv__cta-title {
  color: #f0fdf4;
  font-size: 26px;
  font-weight: 500;
  margin-bottom: 12px;
}

.hv__cta-sub {
  color: #81c784;
  font-size: 15px;
  line-height: 1.6;
  margin-bottom: 2rem;
  opacity: 0.8;
}

/* Responsive */
@media (max-width: 900px) {
  .hv__pasos-grid {
    grid-template-columns: repeat(2, 1fr);
  }
}

@media (max-width: 768px) {
  .hv__hero-title { font-size: 30px; }
  .hv__geneticas-grid { grid-template-columns: 1fr; }
  .hv__noticias-grid { grid-template-columns: 1fr; }
  .hv__pasos-grid { grid-template-columns: 1fr; }
  .hv__section-header { flex-direction: column; align-items: flex-start; gap: 8px; }
}
</style>