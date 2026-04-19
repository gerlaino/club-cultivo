<template>
  <div class="hv">
    <canvas ref="leafCanvas" class="hv__canvas"></canvas>

    <!-- Hero -->
    <section class="hv__hero">
      <div class="hv__hero-inner">
        <div class="hv__hero-content">
          <div class="hv__badge">
            <span class="hv__badge-dot"></span>
            Registrado REPROCANN · Res. 1780/2025
          </div>
          <h1 class="hv__title">
            Cannabis medicinal<br>
            de <span class="hv__title-accent">calidad certificada</span>
          </h1>
          <p class="hv__subtitle">
            Asociación civil sin fines de lucro dedicada al cultivo responsable
            y acceso legal para pacientes con autorización REPROCANN.
          </p>
          <div class="hv__actions">
            <RouterLink to="/contacto" class="hv__btn-primary">Quiero asociarme</RouterLink>
            <RouterLink to="/geneticas" class="hv__btn-ghost">Ver variedades →</RouterLink>
          </div>
        </div>
      </div>
    </section>

    <!-- Stats strip -->
    <div class="hv__stats">
      <div class="hv__stat">
        <div class="hv__stat-val">100<span>%</span></div>
        <div class="hv__stat-lbl">Legal REPROCANN</div>
      </div>
      <div class="hv__stat">
        <div class="hv__stat-val">{{ geneticas.length || '—' }}<span v-if="geneticas.length">+</span></div>
        <div class="hv__stat-lbl">Variedades</div>
      </div>
      <div class="hv__stat">
        <div class="hv__stat-val">Seed<span>-to-sale</span></div>
        <div class="hv__stat-lbl">Trazabilidad completa</div>
      </div>
    </div>

    <!-- Variedades -->
    <section class="hv__section">
      <div class="hv__container">
        <div class="hv__section-head">
          <div>
            <h2 class="hv__section-title">Variedades disponibles</h2>
            <p class="hv__section-sub">Cultivadas con protocolo medicinal certificado</p>
          </div>
          <RouterLink to="/geneticas" class="hv__link-more">Ver todas →</RouterLink>
        </div>

        <div v-if="loadingGeneticas" class="hv__loading"><div class="hv__spinner"></div></div>
        <div v-else class="hv__geneticas">
          <RouterLink
              v-for="g in geneticas.slice(0, 3)"
              :key="g.id"
              :to="`/geneticas/${g.id}`"
              class="hv__genetica-card"
          >
            <div class="hv__genetica-img">
              <img v-if="g.fotos_urls?.length" :src="g.fotos_urls[0]" :alt="g.nombre">
              <div v-else class="hv__genetica-placeholder">
                <svg viewBox="0 0 48 48" fill="none"><path d="M24 4C18 4 8 9 8 20c0 6 3.5 11 8.5 13.5 1.2-6 4.2-11 7.5-13.5-3.5 3.5-4.5 8.5-4.5 13.5 1.4.7 3 1 4.5 1s3.1-.3 4.5-1c0-5-1-10-4.5-13.5 3.3 2.5 6.3 7.5 7.5 13.5C36.5 31 40 26 40 20 40 9 30 4 24 4z" fill="currentColor"/></svg>
              </div>
              <div class="hv__genetica-badges">
                <span v-if="g.registrada_inase" class="hv__inase">INASE</span>
                <span class="hv__tipo" :class="`hv__tipo--${g.tipo}`">{{ formatTipo(g.tipo) }}</span>
              </div>
            </div>
            <div class="hv__genetica-body">
              <div class="hv__genetica-nombre">{{ g.nombre }}</div>
              <div class="hv__genetica-stats">
                <div class="hv__gs">
                  <span class="hv__gs-lbl">THC</span>
                  <span class="hv__gs-val">{{ g.thc }}%</span>
                </div>
                <div class="hv__gs">
                  <span class="hv__gs-lbl">CBD</span>
                  <span class="hv__gs-val">{{ g.cbd }}%</span>
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
        <p class="hv__section-sub hv__text-center" style="margin-bottom:2.5rem">Proceso simple, 100% legal</p>
        <div class="hv__pasos">
          <div v-for="(paso, i) in pasos" :key="i" class="hv__paso">
            <div class="hv__paso-num">{{ i + 1 }}</div>
            <div class="hv__paso-title">{{ paso.titulo }}</div>
            <div class="hv__paso-desc">{{ paso.desc }}</div>
          </div>
        </div>
        <div class="hv__text-center" style="margin-top:2.5rem">
          <RouterLink to="/contacto" class="hv__btn-primary">Iniciar el proceso</RouterLink>
        </div>
      </div>
    </section>

    <!-- Noticias -->
    <section class="hv__section">
      <div class="hv__container">
        <div class="hv__section-head">
          <div>
            <h2 class="hv__section-title">Últimas noticias</h2>
            <p class="hv__section-sub">Novedades del club y del ecosistema cannábico</p>
          </div>
          <RouterLink to="/noticias" class="hv__link-more">Ver todas →</RouterLink>
        </div>
        <div v-if="loadingNoticias" class="hv__loading"><div class="hv__spinner"></div></div>
        <div v-else-if="noticias.length" class="hv__noticias">
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
        <div v-else class="hv__empty">No hay noticias publicadas todavía.</div>
      </div>
    </section>

    <!-- Eventos -->
    <section class="hv__section hv__section--alt">
      <div class="hv__container">
        <div class="hv__section-head">
          <div>
            <h2 class="hv__section-title">Próximos eventos</h2>
            <p class="hv__section-sub">Talleres, charlas y actividades del club</p>
          </div>
          <RouterLink to="/eventos" class="hv__link-more">Ver todos →</RouterLink>
        </div>
        <div v-if="loadingEventos" class="hv__loading"><div class="hv__spinner"></div></div>
        <div v-else-if="!eventos.length" class="hv__empty">No hay eventos próximos por el momento.</div>
        <div v-else class="hv__eventos">
          <div v-for="e in eventos.slice(0, 3)" :key="e.id" class="hv__evento-card">
            <div class="hv__evento-fecha">
              <div class="hv__evento-dia">{{ formatDia(e.fecha_inicio) }}</div>
              <div class="hv__evento-mes">{{ formatMes(e.fecha_inicio) }}</div>
            </div>
            <div class="hv__evento-body">
              <div class="hv__evento-title">{{ e.titulo }}</div>
              <div class="hv__evento-meta">
                <span v-if="e.lugar">
                  <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"/><circle cx="12" cy="10" r="3"/></svg>
                  {{ e.lugar }}
                </span>
                <span>
                  <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>
                  {{ formatHora(e.fecha_inicio) }}
                </span>
              </div>
              <div v-if="e.descripcion" class="hv__evento-desc">{{ truncate(e.descripcion, 90) }}</div>
            </div>
          </div>
        </div>
      </div>
    </section>

    <!-- CTA final -->
    <section class="hv__cta">
      <div class="hv__cta-inner">
        <div class="hv__cta-tag">REPROCANN</div>
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

const geneticas      = ref([])
const noticias       = ref([])
const eventos        = ref([])
const loadingGeneticas = ref(true)
const loadingNoticias  = ref(true)
const loadingEventos   = ref(true)
const leafCanvas     = ref(null)
let   animFrame      = null

const pasos = [
  { titulo: 'Obtené tu REPROCANN', desc: 'Consultá con un médico habilitado para tramitar tu autorización en el Ministerio de Salud.' },
  { titulo: 'Contactanos',         desc: 'Escribinos con tu número de REPROCANN para iniciar el proceso de vinculación al club.' },
  { titulo: 'Firmá la declaración', desc: 'Autorizás al club a abastecerte. Podés seguir cultivando de forma complementaria.' },
  { titulo: 'Recibí tu medicina',  desc: 'Coordinás las dispensaciones según tu necesidad, sin límite de pedidos.' },
]

function formatTipo(tipo) { return { indica:'Índica', sativa:'Sativa', hibrida:'Híbrida' }[tipo] || tipo }
function formatFecha(f) { return f ? new Date(f).toLocaleDateString('es-AR', { day:'numeric', month:'long', year:'numeric' }) : '' }
function formatDia(f)   { return new Date(f).getDate() }
function formatMes(f)   { return new Date(f).toLocaleDateString('es-AR', { month:'short' }).toUpperCase() }
function formatHora(f)  { return new Date(f).toLocaleTimeString('es-AR', { hour:'2-digit', minute:'2-digit' }) }
function truncate(t, n) { return t?.length > n ? t.slice(0, n) + '…' : t }

// ── Hojas animadas ───────────────────────────────────────────────
function drawLeaf(ctx, x, y, size, angle, opacity) {
  ctx.save()
  ctx.translate(x, y)
  ctx.rotate(angle)
  ctx.globalAlpha = opacity
  ctx.strokeStyle = '#6dbe8a'
  ctx.lineWidth = 0.6
  for (let i = 0; i < 7; i++) {
    const a = (i / 7) * Math.PI * 2 - Math.PI / 2
    ctx.save()
    ctx.translate(Math.cos(a) * size * 0.25, Math.sin(a) * size * 0.25)
    ctx.rotate(a + Math.PI / 2)
    ctx.beginPath()
    ctx.moveTo(0, 0)
    ctx.bezierCurveTo(size*.12, -size*.35, size*.08, -size*.65, 0, -size*.75)
    ctx.bezierCurveTo(-size*.08, -size*.65, -size*.12, -size*.35, 0, 0)
    ctx.stroke()
    ctx.restore()
  }
  ctx.beginPath(); ctx.moveTo(0, size*.1); ctx.lineTo(0, -size*.15); ctx.stroke()
  ctx.restore()
}

function startLeaves() {
  const canvas = leafCanvas.value
  if (!canvas) return
  const ctx = canvas.getContext('2d')

  function resize() {
    canvas.width  = window.innerWidth
    canvas.height = document.querySelector('.hv__hero')?.offsetHeight || 600
  }
  resize()
  window.addEventListener('resize', resize)

  const leaves = Array.from({ length: 16 }, () => ({
    x:        Math.random() * window.innerWidth,
    y:        Math.random() * 600,
    size:     14 + Math.random() * 36,
    angle:    Math.random() * Math.PI * 2,
    rotSpeed: (Math.random() > .5 ? 1 : -1) * (.0002 + Math.random() * .0004),
    vy:       .05 + Math.random() * .1,
    t:        Math.random() * Math.PI * 2,
    drift:    (Math.random() - .5) * .1,
    opacity:  .025 + Math.random() * .04,
  }))

  function animate() {
    ctx.clearRect(0, 0, canvas.width, canvas.height)
    leaves.forEach(l => {
      l.t += .007; l.angle += l.rotSpeed; l.y += l.vy
      l.x += Math.sin(l.t) * l.drift
      if (l.y > canvas.height + 60) { l.y = -60; l.x = Math.random() * canvas.width }
      drawLeaf(ctx, l.x, l.y, l.size, l.angle, l.opacity)
    })
    animFrame = requestAnimationFrame(animate)
  }
  animate()
}

onMounted(async () => {
  startLeaves()
  try { geneticas.value = await publicApi.getGeneticas() } catch(e){} finally { loadingGeneticas.value = false }
  try { noticias.value  = await publicApi.getNoticias()  } catch(e){} finally { loadingNoticias.value  = false }
  try { eventos.value   = await publicApi.getEventos()   } catch(e){} finally { loadingEventos.value   = false }
})
onUnmounted(() => { if (animFrame) cancelAnimationFrame(animFrame) })
</script>

<style scoped>
.hv { min-height: 100vh; background: #080c08; }

.hv__canvas {
  position: absolute; top: 76px; left: 0; right: 0;
  pointer-events: none; z-index: 1;
}

/* ── Hero ── */
.hv__hero {
  background: #080c08; min-height: 580px;
  display: flex; align-items: center; position: relative; overflow: hidden;
}
.hv__hero::before {
  content: ''; position: absolute; inset: 0; pointer-events: none;
  background:
      radial-gradient(ellipse at 68% 45%, rgba(109,190,138,.055) 0%, transparent 58%),
      radial-gradient(ellipse at 12% 85%, rgba(109,190,138,.035) 0%, transparent 48%);
}
.hv__hero-inner {
  max-width: 1200px; margin: 0 auto; padding: 5.5rem 2rem 5rem;
  position: relative; z-index: 2; width: 100%;
}
.hv__hero-content { max-width: 600px; }

.hv__badge {
  display: inline-flex; align-items: center; gap: 8px;
  background: rgba(109,190,138,.06); border: 1px solid rgba(109,190,138,.15);
  color: #6dbe8a; font-size: 11px; padding: 5px 14px; border-radius: 20px;
  margin-bottom: 2rem; letter-spacing: .04em;
}
.hv__badge-dot {
  width: 5px; height: 5px; background: #6dbe8a; border-radius: 50%; flex-shrink: 0;
  animation: pulse 2.5s ease-in-out infinite;
}
@keyframes pulse { 0%,100%{opacity:1;transform:scale(1)} 50%{opacity:.3;transform:scale(.7)} }

.hv__title {
  color: #e8f0e8; font-size: 52px; font-weight: 300; line-height: 1.08;
  margin-bottom: 1.25rem; letter-spacing: -0.03em;
}
.hv__title-accent { color: #6dbe8a; font-weight: 500; }
.hv__subtitle {
  color: rgba(180,200,183,.55); font-size: 16px; line-height: 1.72;
  margin-bottom: 2.25rem; max-width: 480px;
}
.hv__actions { display: flex; gap: 12px; flex-wrap: wrap; }

.hv__btn-primary {
  background: #6dbe8a; color: #080c08; padding: 13px 28px; border-radius: 9px;
  font-size: 14px; font-weight: 600; text-decoration: none; transition: opacity .2s;
  display: inline-block; letter-spacing: -0.01em;
}
.hv__btn-primary:hover { opacity: .88; }
.hv__btn-ghost {
  background: transparent; color: rgba(180,200,183,.7);
  border: 1px solid rgba(109,190,138,.2); padding: 13px 28px; border-radius: 9px;
  font-size: 14px; text-decoration: none; transition: all .2s; display: inline-block;
}
.hv__btn-ghost:hover { color: #6dbe8a; border-color: rgba(109,190,138,.4); background: rgba(109,190,138,.05); }

/* ── Stats ── */
.hv__stats {
  display: flex; position: relative; z-index: 2;
  border-top: 1px solid rgba(109,190,138,.08);
  border-bottom: 1px solid rgba(109,190,138,.08);
  background: rgba(109,190,138,.02);
}
.hv__stat { flex: 1; padding: 22px 32px; text-align: center; border-right: 1px solid rgba(109,190,138,.08); }
.hv__stat:last-child { border-right: none; }
.hv__stat-val { color: #e8f0e8; font-size: 20px; font-weight: 500; margin-bottom: 4px; letter-spacing: -0.02em; }
.hv__stat-val span { color: #6dbe8a; font-weight: 400; }
.hv__stat-lbl { color: rgba(180,200,183,.35); font-size: 11px; letter-spacing: .06em; text-transform: uppercase; }

/* ── Secciones ── */
.hv__section { padding: 5rem 0; background: #080c08; }
.hv__section--alt { background: #0d120e; border-top: 1px solid rgba(109,190,138,.07); border-bottom: 1px solid rgba(109,190,138,.07); }
.hv__container { max-width: 1200px; margin: 0 auto; padding: 0 2rem; }
.hv__section-head { display: flex; justify-content: space-between; align-items: flex-end; margin-bottom: 2rem; }
.hv__section-title { font-size: 22px; font-weight: 400; color: #e8f0e8; margin-bottom: 5px; letter-spacing: -0.02em; }
.hv__section-sub { font-size: 13px; color: rgba(180,200,183,.4); margin: 0; }
.hv__link-more { color: rgba(109,190,138,.6); font-size: 13px; text-decoration: none; white-space: nowrap; transition: color .2s; }
.hv__link-more:hover { color: #6dbe8a; }
.hv__text-center { text-align: center; }

.hv__loading { display: flex; justify-content: center; padding: 3rem; }
.hv__spinner { width: 24px; height: 24px; border: 1.5px solid rgba(109,190,138,.15); border-top-color: #6dbe8a; border-radius: 50%; animation: spin .7s linear infinite; }
@keyframes spin { to { transform: rotate(360deg); } }
.hv__empty { text-align: center; color: rgba(180,200,183,.35); padding: 3rem; font-size: 14px; }

/* ── Genéticas ── */
.hv__geneticas { display: grid; grid-template-columns: repeat(3, 1fr); gap: 16px; }
.hv__genetica-card {
  background: #0d120e; border: 1px solid rgba(109,190,138,.09);
  border-radius: 14px; overflow: hidden; text-decoration: none; display: block;
  transition: border-color .2s, transform .2s;
}
.hv__genetica-card:hover { border-color: rgba(109,190,138,.22); transform: translateY(-3px); }
.hv__genetica-img {
  height: 160px; background: linear-gradient(135deg, #111710, #0d120e);
  display: flex; align-items: center; justify-content: center; overflow: hidden; position: relative;
}
.hv__genetica-img img { width: 100%; height: 100%; object-fit: cover; }
.hv__genetica-placeholder { color: rgba(109,190,138,.15); }
.hv__genetica-placeholder svg { width: 52px; height: 52px; }
.hv__genetica-badges { position: absolute; top: 10px; left: 10px; display: flex; gap: 5px; }
.hv__inase { background: rgba(240,192,96,.1); border: 1px solid rgba(240,192,96,.2); color: rgba(240,192,96,.8); font-size: 10px; padding: 2px 8px; border-radius: 4px; font-weight: 500; letter-spacing: .04em; }
.hv__tipo { font-size: 10px; padding: 2px 8px; border-radius: 4px; font-weight: 400; }
.hv__tipo--indica  { background: rgba(99,102,241,.12); border: 1px solid rgba(99,102,241,.2); color: rgba(165,180,252,.8); }
.hv__tipo--sativa  { background: rgba(245,158,11,.1);  border: 1px solid rgba(245,158,11,.2); color: rgba(252,211,77,.8); }
.hv__tipo--hibrida { background: rgba(109,190,138,.08); border: 1px solid rgba(109,190,138,.18); color: #6dbe8a; }
.hv__genetica-body { padding: 14px 16px; }
.hv__genetica-nombre { font-size: 15px; font-weight: 500; color: #e8f0e8; margin-bottom: 12px; letter-spacing: -0.01em; }
.hv__genetica-stats { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; }
.hv__gs { background: rgba(109,190,138,.04); border: 1px solid rgba(109,190,138,.08); border-radius: 7px; padding: 8px 10px; }
.hv__gs-lbl { display: block; font-size: 10px; color: rgba(180,200,183,.35); text-transform: uppercase; letter-spacing: .07em; margin-bottom: 2px; }
.hv__gs-val { display: block; font-size: 16px; font-weight: 500; color: #6dbe8a; letter-spacing: -0.01em; }

/* ── Pasos ── */
.hv__pasos { display: grid; grid-template-columns: repeat(4, 1fr); gap: 16px; }
.hv__paso { padding: 1.5rem 1.25rem; background: rgba(109,190,138,.03); border: 1px solid rgba(109,190,138,.09); border-radius: 14px; }
.hv__paso-num { width: 36px; height: 36px; background: rgba(109,190,138,.1); border: 1px solid rgba(109,190,138,.2); border-radius: 9px; display: flex; align-items: center; justify-content: center; color: #6dbe8a; font-size: 15px; font-weight: 500; margin-bottom: 14px; }
.hv__paso-title { font-size: 14px; font-weight: 500; color: #e8f0e8; margin-bottom: 8px; letter-spacing: -0.01em; }
.hv__paso-desc { font-size: 13px; color: rgba(180,200,183,.45); line-height: 1.6; }

/* ── Noticias ── */
.hv__noticias { display: grid; grid-template-columns: repeat(2, 1fr); gap: 16px; }
.hv__noticia-card {
  background: #0d120e; border: 1px solid rgba(109,190,138,.09);
  border-radius: 14px; text-decoration: none; display: flex; flex-direction: column; overflow: hidden;
  transition: border-color .2s, transform .2s;
}
.hv__noticia-card:hover { border-color: rgba(109,190,138,.2); transform: translateY(-2px); }
.hv__noticia-cover { height: 140px; background-size: cover; background-position: center; }
.hv__noticia-body { padding: 18px 20px; flex: 1; display: flex; flex-direction: column; }
.hv__noticia-date { font-size: 11px; color: rgba(109,190,138,.6); margin-bottom: 8px; letter-spacing: .03em; }
.hv__noticia-title { font-size: 16px; font-weight: 500; color: #e8f0e8; margin-bottom: 8px; line-height: 1.35; letter-spacing: -0.01em; }
.hv__noticia-preview { font-size: 13px; color: rgba(180,200,183,.45); line-height: 1.6; flex: 1; margin-bottom: 14px; }
.hv__noticia-link { font-size: 13px; color: rgba(109,190,138,.6); transition: color .2s; }
.hv__noticia-card:hover .hv__noticia-link { color: #6dbe8a; }

/* ── Eventos ── */
.hv__eventos { display: flex; flex-direction: column; gap: 12px; }
.hv__evento-card {
  background: rgba(109,190,138,.03); border: 1px solid rgba(109,190,138,.09);
  border-radius: 14px; padding: 18px 20px; display: flex; gap: 18px; align-items: flex-start;
  transition: border-color .2s;
}
.hv__evento-card:hover { border-color: rgba(109,190,138,.18); }
.hv__evento-fecha { background: rgba(109,190,138,.08); border: 1px solid rgba(109,190,138,.15); border-radius: 10px; padding: 10px 14px; text-align: center; flex-shrink: 0; min-width: 56px; }
.hv__evento-dia { color: #e8f0e8; font-size: 22px; font-weight: 500; line-height: 1; letter-spacing: -0.02em; }
.hv__evento-mes { color: #6dbe8a; font-size: 10px; margin-top: 4px; letter-spacing: .08em; }
.hv__evento-body { flex: 1; }
.hv__evento-title { font-size: 15px; font-weight: 500; color: #e8f0e8; margin-bottom: 7px; letter-spacing: -0.01em; }
.hv__evento-meta { display: flex; gap: 16px; font-size: 12px; color: rgba(180,200,183,.4); margin-bottom: 8px; align-items: center; }
.hv__evento-meta span { display: flex; align-items: center; gap: 5px; }
.hv__evento-desc { font-size: 13px; color: rgba(180,200,183,.4); line-height: 1.55; }

/* ── CTA ── */
.hv__cta {
  background: #080c08; padding: 6rem 2rem; text-align: center;
  border-top: 1px solid rgba(109,190,138,.08); position: relative; overflow: hidden;
}
.hv__cta::before {
  content: ''; position: absolute; inset: 0; pointer-events: none;
  background: radial-gradient(ellipse at 50% 50%, rgba(109,190,138,.05) 0%, transparent 65%);
}
.hv__cta-inner { position: relative; z-index: 1; max-width: 500px; margin: 0 auto; }
.hv__cta-tag {
  display: inline-block; background: rgba(109,190,138,.07); border: 1px solid rgba(109,190,138,.15);
  color: rgba(109,190,138,.7); font-size: 10px; letter-spacing: .1em; padding: 4px 14px;
  border-radius: 20px; margin-bottom: 1.25rem;
}
.hv__cta-title { color: #e8f0e8; font-size: 30px; font-weight: 300; margin-bottom: 14px; letter-spacing: -0.02em; line-height: 1.2; }
.hv__cta-sub { color: rgba(180,200,183,.45); font-size: 15px; line-height: 1.65; margin-bottom: 2rem; }

/* ── Responsive ── */
@media (max-width: 900px) { .hv__pasos { grid-template-columns: repeat(2, 1fr); } }
@media (max-width: 768px) {
  .hv__title { font-size: 34px; }
  .hv__geneticas { grid-template-columns: 1fr; }
  .hv__noticias { grid-template-columns: 1fr; }
  .hv__pasos { grid-template-columns: 1fr; }
  .hv__section-head { flex-direction: column; align-items: flex-start; gap: 8px; }
  .hv__stats { flex-direction: column; }
  .hv__stat { border-right: none; border-bottom: 1px solid rgba(109,190,138,.08); }
  .hv__stat:last-child { border-bottom: none; }
}
</style>