<template>
  <div class="hv">

    <!-- Canvas hojas animadas -->
    <canvas ref="leafCanvas" class="hv__leaf-canvas"></canvas>

    <!-- Hero -->
    <section class="hv__hero">
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
            <RouterLink to="/geneticas" class="hv__btn-outline">Ver variedades →</RouterLink>
          </div>
        </div>
      </div>
    </section>

    <!-- Stats strip -->
    <div class="hv__stats">
      <div class="hv__stat">
        <div class="hv__stat-val">100<span>%</span></div>
        <div class="hv__stat-label">Legal REPROCANN</div>
      </div>
      <div class="hv__stat">
        <div class="hv__stat-val">{{ geneticas.length || '—' }}<span>+</span></div>
        <div class="hv__stat-label">Variedades</div>
      </div>
      <div class="hv__stat">
        <div class="hv__stat-val">Seed<span>-to-</span>Sale</div>
        <div class="hv__stat-label">Trazabilidad completa</div>
      </div>
    </div>

    <!-- Variedades -->
    <section class="hv__section">
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
          <RouterLink
              v-for="g in geneticas.slice(0, 3)"
              :key="g.id"
              :to="`/geneticas/${g.id}`"
              class="hv__genetica-card"
          >
            <div class="hv__genetica-img">
              <img v-if="g.fotos_urls?.length" :src="g.fotos_urls[0]" :alt="g.nombre">
              <div v-else class="hv__genetica-placeholder">
                <svg viewBox="0 0 40 40" fill="none" xmlns="http://www.w3.org/2000/svg">
                  <path d="M20 4C14 4 6 9 6 18c0 5 3 9 7 11 1-5 3.5-9 7-11-3 3-4 7-4 11 1.2.6 2.6 1 4 1s2.8-.4 4-1c0-4-1-8-4-11 3.5 2 6.5 6 7 11 4-2 7-6 7-11 0-9-8-14-14-14z" fill="currentColor"/>
                </svg>
              </div>
              <div class="hv__genetica-badges">
                <span v-if="g.registrada_inase" class="hv__inase-badge">INASE</span>
                <span class="hv__tipo-badge" :class="`hv__tipo-badge--${g.tipo}`">{{ formatTipo(g.tipo) }}</span>
              </div>
            </div>
            <div class="hv__genetica-body">
              <div class="hv__genetica-name">{{ g.nombre }}</div>
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
            </div>
          </RouterLink>
        </div>
      </div>
    </section>

    <!-- Cómo asociarse -->
    <section class="hv__section hv__section--alt">
      <div class="hv__container">
        <h2 class="hv__section-title hv__text-center">¿Cómo asociarse?</h2>
        <p class="hv__section-sub hv__text-center" style="margin-bottom: 2.5rem;">Proceso simple, 100% legal</p>
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
    <section class="hv__section">
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
            <div v-if="n.cover_url" class="hv__noticia-cover" :style="`background-image:url(${n.cover_url})`"></div>
            <div class="hv__noticia-body">
              <div class="hv__noticia-date">{{ formatFecha(n.publicada_at) }}</div>
              <div class="hv__noticia-title">{{ n.titulo }}</div>
              <div class="hv__noticia-preview">{{ n.preview }}</div>
              <span class="hv__noticia-link">Leer más →</span>
            </div>
          </RouterLink>
        </div>
      </div>
    </section>

    <!-- Próximos eventos -->
    <section class="hv__section hv__section--alt">
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
                <span v-if="e.lugar">
                  <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"/><circle cx="12" cy="10" r="3"/></svg>
                  {{ e.lugar }}
                </span>
                <span>
                  <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>
                  {{ formatHora(e.fecha_inicio) }}
                </span>
              </div>
              <div v-if="e.descripcion" class="hv__evento-desc">{{ truncate(e.descripcion, 90) }}</div>
            </div>
          </div>
        </div>
      </div>
    </section>

    <!-- CTA Final -->
    <section class="hv__cta">
      <div class="hv__cta-inner">
        <div class="hv__cta-badge">REPROCANN</div>
        <h2 class="hv__cta-title">¿Tenés autorización REPROCANN?</h2>
        <p class="hv__cta-sub">Accedé a cannabis medicinal de calidad certificada de forma legal y segura.</p>
        <RouterLink to="/contacto" class="hv__btn-primary">Contactanos hoy</RouterLink>
      </div>
    </section>

  </div>
</template>

<script setup>
import { ref, onMounted, onUnmounted } from 'vue'
import publicApi from '../api/publicApi.js'

const geneticas = ref([])
const noticias = ref([])
const eventos = ref([])
const loadingGeneticas = ref(true)
const loadingNoticias = ref(true)
const loadingEventos = ref(true)
const leafCanvas = ref(null)

let animFrame = null

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

function truncate(text, len) {
  return text && text.length > len ? text.slice(0, len) + '...' : text
}

// ── Animación hojas ──────────────────────────────────────────────
function drawLeaf(ctx, x, y, size, angle, opacity) {
  ctx.save()
  ctx.translate(x, y)
  ctx.rotate(angle)
  ctx.globalAlpha = opacity
  ctx.strokeStyle = '#6dbe8a'
  ctx.lineWidth = 0.7
  ctx.beginPath()
  const fingers = 7
  for (let i = 0; i < fingers; i++) {
    const a = (i / fingers) * Math.PI * 2 - Math.PI / 2
    ctx.save()
    ctx.translate(Math.cos(a) * size * 0.25, Math.sin(a) * size * 0.25)
    ctx.rotate(a + Math.PI / 2)
    ctx.beginPath()
    ctx.moveTo(0, 0)
    ctx.bezierCurveTo(size * 0.12, -size * 0.35, size * 0.08, -size * 0.65, 0, -size * 0.75)
    ctx.bezierCurveTo(-size * 0.08, -size * 0.65, -size * 0.12, -size * 0.35, 0, 0)
    ctx.stroke()
    ctx.restore()
  }
  // tallo
  ctx.beginPath()
  ctx.moveTo(0, size * 0.1)
  ctx.lineTo(0, -size * 0.15)
  ctx.stroke()
  ctx.restore()
}

function initLeaves(canvas) {
  const count = 14
  return Array.from({ length: count }, () => ({
    x: Math.random() * canvas.width,
    y: Math.random() * canvas.height,
    size: 16 + Math.random() * 38,
    angle: Math.random() * Math.PI * 2,
    rotSpeed: (Math.random() > 0.5 ? 1 : -1) * (0.0002 + Math.random() * 0.0004),
    vy: 0.06 + Math.random() * 0.1,
    t: Math.random() * Math.PI * 2,
    drift: (Math.random() - 0.5) * 0.12,
    opacity: 0.025 + Math.random() * 0.045,
  }))
}

function startLeafAnimation() {
  const canvas = leafCanvas.value
  if (!canvas) return
  const ctx = canvas.getContext('2d')

  function resize() {
    canvas.width = window.innerWidth
    canvas.height = document.querySelector('.hv__hero')?.offsetHeight || 600
  }
  resize()
  window.addEventListener('resize', resize)

  const leaves = initLeaves(canvas)

  function animate() {
    ctx.clearRect(0, 0, canvas.width, canvas.height)
    leaves.forEach(l => {
      l.t += 0.007
      l.angle += l.rotSpeed
      l.y += l.vy
      l.x += Math.sin(l.t) * l.drift
      if (l.y > canvas.height + 60) {
        l.y = -60
        l.x = Math.random() * canvas.width
      }
      drawLeaf(ctx, l.x, l.y, l.size, l.angle, l.opacity)
    })
    animFrame = requestAnimationFrame(animate)
  }
  animate()
}

onMounted(async () => {
  startLeafAnimation()

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

onUnmounted(() => {
  if (animFrame) cancelAnimationFrame(animFrame)
})
</script>

<style scoped>
.hv {
  min-height: 100vh;
  background: #080c08;
}

/* Canvas hojas — solo sobre el hero */
.hv__leaf-canvas {
  position: absolute;
  top: 76px; /* altura navbar */
  left: 0;
  right: 0;
  pointer-events: none;
  z-index: 1;
}

/* Hero */
.hv__hero {
  background: #080c08;
  min-height: 560px;
  display: flex;
  align-items: center;
  position: relative;
  overflow: hidden;
}

.hv__hero::before {
  content: '';
  position: absolute;
  inset: 0;
  background:
      radial-gradient(ellipse at 70% 40%, rgba(109,190,138,0.06) 0%, transparent 60%),
      radial-gradient(ellipse at 15% 85%, rgba(109,190,138,0.04) 0%, transparent 50%);
  pointer-events: none;
}

.hv__hero-inner {
  max-width: 1200px;
  margin: 0 auto;
  padding: 5rem 2rem 4.5rem;
  position: relative;
  z-index: 2;
  width: 100%;
}

.hv__hero-content {
  max-width: 580px;
}

.hv__hero-badge {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  background: rgba(109, 190, 138, 0.06);
  border: 1px solid rgba(109, 190, 138, 0.15);
  color: #6dbe8a;
  font-size: 11px;
  padding: 5px 14px;
  border-radius: 20px;
  margin-bottom: 2rem;
  letter-spacing: 0.04em;
}

.hv__hero-badge-dot {
  width: 5px;
  height: 5px;
  background: #6dbe8a;
  border-radius: 50%;
  flex-shrink: 0;
  animation: pulse 2.5s ease-in-out infinite;
}

@keyframes pulse {
  0%, 100% { opacity: 1; transform: scale(1); }
  50% { opacity: 0.35; transform: scale(0.75); }
}

.hv__hero-title {
  color: #e8f0e8;
  font-size: 48px;
  font-weight: 300;
  line-height: 1.1;
  margin-bottom: 1.25rem;
  letter-spacing: -0.03em;
}

.hv__hero-title-accent {
  color: #6dbe8a;
  font-weight: 500;
}

.hv__hero-sub {
  color: rgba(180, 200, 183, 0.55);
  font-size: 15px;
  line-height: 1.72;
  margin-bottom: 2.25rem;
  max-width: 460px;
}

.hv__hero-actions {
  display: flex;
  gap: 12px;
  flex-wrap: wrap;
}

/* Botones */
.hv__btn-primary {
  background: #6dbe8a;
  color: #080c08;
  padding: 13px 28px;
  border-radius: 9px;
  font-size: 14px;
  font-weight: 600;
  text-decoration: none;
  transition: opacity 0.2s;
  display: inline-block;
  letter-spacing: -0.01em;
}

.hv__btn-primary:hover {
  opacity: 0.88;
}

.hv__btn-outline {
  background: transparent;
  color: rgba(180, 200, 183, 0.7);
  border: 1px solid rgba(109, 190, 138, 0.2);
  padding: 13px 28px;
  border-radius: 9px;
  font-size: 14px;
  text-decoration: none;
  transition: all 0.2s;
  display: inline-block;
}

.hv__btn-outline:hover {
  color: #6dbe8a;
  border-color: rgba(109, 190, 138, 0.4);
  background: rgba(109, 190, 138, 0.05);
}

/* Stats strip */
.hv__stats {
  display: flex;
  border-top: 1px solid rgba(109, 190, 138, 0.08);
  border-bottom: 1px solid rgba(109, 190, 138, 0.08);
  background: rgba(109, 190, 138, 0.02);
  position: relative;
  z-index: 2;
}

.hv__stat {
  flex: 1;
  padding: 22px 32px;
  text-align: center;
  border-right: 1px solid rgba(109, 190, 138, 0.08);
}

.hv__stat:last-child {
  border-right: none;
}

.hv__stat-val {
  color: #e8f0e8;
  font-size: 20px;
  font-weight: 500;
  margin-bottom: 4px;
  letter-spacing: -0.02em;
}

.hv__stat-val span {
  color: #6dbe8a;
  font-weight: 400;
}

.hv__stat-label {
  color: rgba(180, 200, 183, 0.38);
  font-size: 11px;
  letter-spacing: 0.06em;
  text-transform: uppercase;
}

/* Secciones */
.hv__section {
  padding: 4.5rem 0;
  background: #080c08;
}

.hv__section--alt {
  background: #0d120e;
  border-top: 1px solid rgba(109, 190, 138, 0.07);
  border-bottom: 1px solid rgba(109, 190, 138, 0.07);
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
  font-weight: 400;
  color: #e8f0e8;
  margin-bottom: 5px;
  letter-spacing: -0.02em;
}

.hv__section-sub {
  font-size: 13px;
  color: rgba(180, 200, 183, 0.4);
  margin: 0;
}

.hv__link-more {
  color: rgba(109, 190, 138, 0.6);
  font-size: 13px;
  text-decoration: none;
  white-space: nowrap;
  transition: color 0.2s;
}

.hv__link-more:hover {
  color: #6dbe8a;
}

.hv__text-center { text-align: center; }

/* Loading */
.hv__loading {
  display: flex;
  justify-content: center;
  padding: 3rem;
}

.hv__spinner {
  width: 24px;
  height: 24px;
  border: 1.5px solid rgba(109, 190, 138, 0.15);
  border-top-color: #6dbe8a;
  border-radius: 50%;
  animation: spin 0.7s linear infinite;
}

@keyframes spin { to { transform: rotate(360deg); } }

.hv__empty {
  text-align: center;
  color: rgba(180, 200, 183, 0.4);
  padding: 3rem;
  font-size: 14px;
}

/* Genéticas */
.hv__geneticas-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 16px;
}

.hv__genetica-card {
  background: #0d120e;
  border: 1px solid rgba(109, 190, 138, 0.09);
  border-radius: 14px;
  overflow: hidden;
  transition: border-color 0.2s, transform 0.2s;
  text-decoration: none;
  display: block;
}

.hv__genetica-card:hover {
  border-color: rgba(109, 190, 138, 0.22);
  transform: translateY(-3px);
}

.hv__genetica-img {
  height: 150px;
  background: linear-gradient(135deg, #111710, #0d120e);
  display: flex;
  align-items: center;
  justify-content: center;
  overflow: hidden;
  position: relative;
}

.hv__genetica-img img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.hv__genetica-placeholder {
  color: rgba(109, 190, 138, 0.15);
}

.hv__genetica-placeholder svg {
  width: 48px;
  height: 48px;
}

.hv__genetica-badges {
  position: absolute;
  top: 10px;
  left: 10px;
  display: flex;
  gap: 5px;
}

.hv__inase-badge {
  background: rgba(240, 192, 96, 0.1);
  border: 1px solid rgba(240, 192, 96, 0.2);
  color: rgba(240, 192, 96, 0.8);
  font-size: 10px;
  padding: 2px 8px;
  border-radius: 4px;
  font-weight: 500;
  letter-spacing: 0.04em;
}

.hv__tipo-badge {
  font-size: 10px;
  padding: 2px 8px;
  border-radius: 4px;
  font-weight: 400;
  letter-spacing: 0.02em;
}

.hv__tipo-badge--indica  { background: rgba(99,102,241,0.12); border: 1px solid rgba(99,102,241,0.2); color: rgba(165,180,252,0.8); }
.hv__tipo-badge--sativa  { background: rgba(245,158,11,0.1);  border: 1px solid rgba(245,158,11,0.2); color: rgba(252,211,77,0.8); }
.hv__tipo-badge--hibrida { background: rgba(109,190,138,0.08); border: 1px solid rgba(109,190,138,0.18); color: #6dbe8a; }

.hv__genetica-body {
  padding: 14px 16px;
}

.hv__genetica-name {
  font-size: 15px;
  font-weight: 500;
  color: #e8f0e8;
  margin-bottom: 12px;
  letter-spacing: -0.01em;
}

.hv__genetica-stats {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 8px;
}

.hv__genetica-stat {
  background: rgba(109, 190, 138, 0.04);
  border: 1px solid rgba(109, 190, 138, 0.08);
  border-radius: 7px;
  padding: 8px 10px;
}

.hv__genetica-stat-label {
  display: block;
  font-size: 10px;
  color: rgba(180, 200, 183, 0.35);
  text-transform: uppercase;
  letter-spacing: 0.07em;
  margin-bottom: 2px;
}

.hv__genetica-stat-val {
  display: block;
  font-size: 16px;
  font-weight: 500;
  color: #6dbe8a;
  letter-spacing: -0.01em;
}

/* Pasos */
.hv__pasos-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 16px;
}

.hv__paso {
  padding: 1.5rem 1.25rem;
  background: rgba(109, 190, 138, 0.03);
  border: 1px solid rgba(109, 190, 138, 0.09);
  border-radius: 14px;
  position: relative;
}

.hv__paso-num {
  width: 36px;
  height: 36px;
  background: rgba(109, 190, 138, 0.1);
  border: 1px solid rgba(109, 190, 138, 0.2);
  border-radius: 9px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: #6dbe8a;
  font-size: 15px;
  font-weight: 500;
  margin-bottom: 14px;
}

.hv__paso-title {
  font-size: 14px;
  font-weight: 500;
  color: #e8f0e8;
  margin-bottom: 8px;
  letter-spacing: -0.01em;
}

.hv__paso-desc {
  font-size: 13px;
  color: rgba(180, 200, 183, 0.45);
  line-height: 1.6;
}

/* Noticias */
.hv__noticias-grid {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 16px;
}

.hv__noticia-card {
  background: #0d120e;
  border: 1px solid rgba(109, 190, 138, 0.09);
  border-radius: 14px;
  text-decoration: none;
  display: flex;
  flex-direction: column;
  overflow: hidden;
  transition: border-color 0.2s, transform 0.2s;
}

.hv__noticia-card:hover {
  border-color: rgba(109, 190, 138, 0.2);
  transform: translateY(-2px);
}

.hv__noticia-cover {
  height: 140px;
  background-size: cover;
  background-position: center;
}

.hv__noticia-body {
  padding: 18px 20px;
  flex: 1;
  display: flex;
  flex-direction: column;
}

.hv__noticia-date {
  font-size: 11px;
  color: rgba(109, 190, 138, 0.6);
  margin-bottom: 8px;
  letter-spacing: 0.03em;
}

.hv__noticia-title {
  font-size: 16px;
  font-weight: 500;
  color: #e8f0e8;
  margin-bottom: 8px;
  line-height: 1.35;
  letter-spacing: -0.01em;
}

.hv__noticia-preview {
  font-size: 13px;
  color: rgba(180, 200, 183, 0.45);
  line-height: 1.6;
  flex: 1;
  margin-bottom: 14px;
}

.hv__noticia-link {
  font-size: 13px;
  color: rgba(109, 190, 138, 0.6);
  transition: color 0.2s;
}

.hv__noticia-card:hover .hv__noticia-link {
  color: #6dbe8a;
}

/* Eventos */
.hv__eventos-grid {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.hv__evento-card {
  background: rgba(109, 190, 138, 0.03);
  border: 1px solid rgba(109, 190, 138, 0.09);
  border-radius: 14px;
  padding: 18px 20px;
  display: flex;
  gap: 18px;
  align-items: flex-start;
  transition: border-color 0.2s;
}

.hv__evento-card:hover {
  border-color: rgba(109, 190, 138, 0.18);
}

.hv__evento-fecha-col {
  background: rgba(109, 190, 138, 0.08);
  border: 1px solid rgba(109, 190, 138, 0.15);
  border-radius: 10px;
  padding: 10px 14px;
  text-align: center;
  flex-shrink: 0;
  min-width: 56px;
}

.hv__evento-dia {
  color: #e8f0e8;
  font-size: 22px;
  font-weight: 500;
  line-height: 1;
  letter-spacing: -0.02em;
}

.hv__evento-mes {
  color: #6dbe8a;
  font-size: 10px;
  margin-top: 4px;
  letter-spacing: 0.08em;
}

.hv__evento-body {
  flex: 1;
}

.hv__evento-title {
  font-size: 15px;
  font-weight: 500;
  color: #e8f0e8;
  margin-bottom: 7px;
  letter-spacing: -0.01em;
}

.hv__evento-meta {
  display: flex;
  gap: 16px;
  font-size: 12px;
  color: rgba(180, 200, 183, 0.4);
  margin-bottom: 8px;
  align-items: center;
}

.hv__evento-meta span {
  display: flex;
  align-items: center;
  gap: 5px;
}

.hv__evento-desc {
  font-size: 13px;
  color: rgba(180, 200, 183, 0.4);
  line-height: 1.55;
}

/* CTA Final */
.hv__cta {
  background: #080c08;
  padding: 5.5rem 2rem;
  text-align: center;
  position: relative;
  overflow: hidden;
  border-top: 1px solid rgba(109, 190, 138, 0.08);
}

.hv__cta::before {
  content: '';
  position: absolute;
  inset: 0;
  background: radial-gradient(ellipse at 50% 50%, rgba(109,190,138,0.05) 0%, transparent 65%);
  pointer-events: none;
}

.hv__cta-inner {
  position: relative;
  z-index: 1;
  max-width: 500px;
  margin: 0 auto;
}

.hv__cta-badge {
  display: inline-block;
  background: rgba(109, 190, 138, 0.07);
  border: 1px solid rgba(109, 190, 138, 0.15);
  color: rgba(109, 190, 138, 0.7);
  font-size: 10px;
  letter-spacing: 0.1em;
  padding: 4px 14px;
  border-radius: 20px;
  margin-bottom: 1.25rem;
}

.hv__cta-title {
  color: #e8f0e8;
  font-size: 28px;
  font-weight: 300;
  margin-bottom: 14px;
  letter-spacing: -0.02em;
  line-height: 1.2;
}

.hv__cta-sub {
  color: rgba(180, 200, 183, 0.45);
  font-size: 15px;
  line-height: 1.65;
  margin-bottom: 2rem;
}

/* Responsive */
@media (max-width: 900px) {
  .hv__pasos-grid {
    grid-template-columns: repeat(2, 1fr);
  }
}

@media (max-width: 768px) {
  .hv__hero-title { font-size: 32px; }
  .hv__geneticas-grid { grid-template-columns: 1fr; }
  .hv__noticias-grid { grid-template-columns: 1fr; }
  .hv__pasos-grid { grid-template-columns: 1fr; }
  .hv__section-header { flex-direction: column; align-items: flex-start; gap: 8px; }
  .hv__stats { flex-direction: column; }
  .hv__stat { border-right: none; border-bottom: 1px solid rgba(109,190,138,0.08); }
  .hv__stat:last-child { border-bottom: none; }
}
</style>