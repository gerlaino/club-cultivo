<template>
  <div class="gp">

    <!-- Loading -->
    <div v-if="estado === 'cargando'" class="gp__loading">
      <div class="gp__brand">
        <span class="gp__brand-dot"></span>
        <span class="gp__brand-name">{{ clubNombre }}</span>
      </div>
      <DsSpinner :size="36" />
    </div>

    <!-- No encontrada / no publicada -->
    <div v-else-if="estado === 'no_encontrada'" class="gp__error">
      <div class="gp__brand gp__brand--top">
        <span class="gp__brand-dot"></span>
        <span class="gp__brand-name">{{ clubNombre }}</span>
      </div>
      <div class="gp__error-icon">🌿</div>
      <h2 class="gp__error-title">Variedad no disponible</h2>
      <p class="gp__error-desc">Esta variedad no está publicada por el club o no existe.</p>
    </div>

    <!-- Contenido -->
    <div v-else-if="gen" class="gp__page">

      <!-- Header sticky -->
      <header class="gp__header">
        <span class="gp__brand-dot"></span>
        <span class="gp__brand-name">{{ clubNombre }}</span>
      </header>

      <!-- Hero -->
      <div class="gp__hero" :style="{ '--tipo-color': tipoColor }">
        <div class="gp__hero-inner">
          <div class="gp__badges">
            <span class="gp__badge gp__badge--tipo">{{ tipoLabel }}</span>
            <span v-if="gen.registrada_inase" class="gp__badge gp__badge--inase">🏛️ INASE</span>
          </div>
          <h1 class="gp__nombre">{{ gen.nombre }}</h1>
          <div v-if="gen.criador" class="gp__criador">
            <i class="bi bi-person-fill"></i> {{ gen.criador }}
            <span v-if="gen.origen" class="gp__origen"> · {{ gen.origen }}</span>
          </div>
        </div>
      </div>

      <!-- Fotos carousel -->
      <div v-if="gen.fotos_urls?.length" class="gp__carousel">
        <div class="gp__carousel-track">
          <div
            v-for="(foto, i) in gen.fotos_urls"
            :key="i"
            class="gp__carousel-slide"
          >
            <img :src="foto" :alt="`${gen.nombre} foto ${i + 1}`" class="gp__carousel-img" loading="lazy" />
          </div>
        </div>
        <div v-if="gen.fotos_urls.length > 1" class="gp__carousel-dots">
          <span v-for="(_, i) in gen.fotos_urls" :key="i" class="gp__carousel-dot"></span>
        </div>
      </div>

      <!-- THC / CBD -->
      <div class="gp__section">
        <div class="gp__cannabinoids">
          <div class="gp__cannabinoid">
            <div class="gp__cannabinoid-label">THC</div>
            <div class="gp__cannabinoid-value">
              {{ gen.thc != null ? gen.thc + '%' : '—' }}
            </div>
            <div v-if="gen.thc != null" class="gp__cannabinoid-bar">
              <div class="gp__cannabinoid-fill" :style="{ width: Math.min(gen.thc, 30) / 30 * 100 + '%', background: '#e53935' }"></div>
            </div>
          </div>
          <div class="gp__cannabinoid">
            <div class="gp__cannabinoid-label">CBD</div>
            <div class="gp__cannabinoid-value">
              {{ gen.cbd != null ? gen.cbd + '%' : '—' }}
            </div>
            <div v-if="gen.cbd != null" class="gp__cannabinoid-bar">
              <div class="gp__cannabinoid-fill" :style="{ width: Math.min(gen.cbd, 30) / 30 * 100 + '%', background: '#1b5e20' }"></div>
            </div>
          </div>
        </div>
      </div>

      <!-- Perfil terpénico -->
      <div v-if="terpenos.length" class="gp__section">
        <h3 class="gp__section-title">Perfil terpénico</h3>
        <div class="gp__chips">
          <span v-for="t in terpenos" :key="t" class="gp__chip">{{ t }}</span>
        </div>
      </div>

      <!-- Descripción -->
      <div v-if="gen.descripcion" class="gp__section">
        <h3 class="gp__section-title">Descripción</h3>
        <p class="gp__descripcion">{{ gen.descripcion }}</p>
      </div>

      <!-- Datos de cultivo -->
      <div class="gp__section">
        <h3 class="gp__section-title">Datos de cultivo</h3>
        <div class="gp__datos">
          <div v-if="gen.tiempo_floracion" class="gp__dato">
            <span class="gp__dato-icon">🌸</span>
            <div>
              <div class="gp__dato-label">Floración</div>
              <div class="gp__dato-val">{{ gen.tiempo_floracion }} días</div>
            </div>
          </div>
          <div v-if="gen.dificultad" class="gp__dato">
            <span class="gp__dato-icon">{{ difIcon }}</span>
            <div>
              <div class="gp__dato-label">Dificultad</div>
              <div class="gp__dato-val">{{ difLabel }}</div>
            </div>
          </div>
          <div v-if="gen.origen" class="gp__dato">
            <span class="gp__dato-icon">🌍</span>
            <div>
              <div class="gp__dato-label">Origen</div>
              <div class="gp__dato-val">{{ gen.origen }}</div>
            </div>
          </div>
        </div>
      </div>

      <!-- Footer -->
      <footer class="gp__footer">
        <p class="gp__footer-text">Información proporcionada por <strong>{{ clubNombre }}</strong></p>
        <a href="/" class="gp__footer-link">Conocé más sobre el club →</a>
      </footer>

    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import api from '../lib/api'
import DsSpinner from '../design-system/components/Spinner.vue'

const route = useRoute()
const slug  = route.params.slug

const estado     = ref('cargando')
const gen        = ref(null)
const clubNombre = ref('Cultivo Espacial')

const TIPO_META = {
  indica:    { label: 'Índica',    color: '#6f42c1' },
  sativa:    { label: 'Sativa',    color: '#198754' },
  hibrida:   { label: 'Híbrida',   color: '#fd7e14' },
  ruderalis: { label: 'Ruderalis', color: '#0dcaf0' },
}
const DIFICULTAD = {
  facil:   { label: 'Fácil',   icon: '🟢' },
  media:   { label: 'Media',   icon: '🟡' },
  dificil: { label: 'Difícil', icon: '🔴' },
}

const tipoLabel  = computed(() => TIPO_META[gen.value?.tipo]?.label || gen.value?.tipo || '—')
const tipoColor  = computed(() => TIPO_META[gen.value?.tipo]?.color || '#6c757d')
const difLabel   = computed(() => DIFICULTAD[gen.value?.dificultad]?.label || gen.value?.dificultad || '—')
const difIcon    = computed(() => DIFICULTAD[gen.value?.dificultad]?.icon || '⚪')
const terpenos   = computed(() =>
  gen.value?.terpenos
    ? gen.value.terpenos.split(',').map(t => t.trim()).filter(Boolean)
    : []
)

onMounted(async () => {
  try {
    const { data: clubData } = await api.get('/public/club')
    if (clubData?.name) clubNombre.value = clubData.name
  } catch {}

  try {
    const { data } = await api.get(`/public/geneticas/${slug}`)
    gen.value  = data.data
    estado.value = 'ok'
  } catch {
    estado.value = 'no_encontrada'
  }
})
</script>

<style scoped>
.gp {
  min-height: 100vh;
  background: #f8faf8;
  font-family: system-ui, -apple-system, sans-serif;
  font-size: 16px;
}

/* Loading */
.gp__loading {
  min-height: 100vh;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 2rem;
}
/* Brand */
.gp__brand, .gp__brand--top {
  display: flex; align-items: center; gap: .5rem;
}
.gp__brand-dot {
  width: .75rem; height: .75rem;
  border-radius: 50%;
  background: #1b5e20;
  flex-shrink: 0;
  box-shadow: 0 0 0 3px rgba(27,94,32,.2);
}
.gp__brand-name { font-weight: 600; font-size: .9rem; color: #1b5e20; }

/* Error */
.gp__error {
  min-height: 100vh;
  display: flex; flex-direction: column; align-items: center; justify-content: center;
  gap: 1rem; padding: 2rem; text-align: center;
}
.gp__error-icon { font-size: 3rem; }
.gp__error-title { font-size: 1.25rem; font-weight: 700; color: #1a2e1a; margin: 0; }
.gp__error-desc { color: #6c757d; margin: 0; max-width: 280px; }

/* Header sticky */
.gp__header {
  position: sticky; top: 0; z-index: 10;
  display: flex; align-items: center; gap: .5rem;
  padding: .75rem 1rem;
  background: rgba(248,250,248,.95);
  backdrop-filter: blur(8px);
  border-bottom: 1px solid rgba(0,0,0,.06);
}

/* Hero */
.gp__hero {
  background: linear-gradient(160deg, #1b5e20 0%, #2e7d32 60%, color-mix(in srgb, var(--tipo-color, #2e7d32) 30%, #1b5e20) 100%);
  padding: 2rem 1.25rem 2.5rem;
}
.gp__hero-inner { max-width: 600px; }
.gp__badges { display: flex; flex-wrap: wrap; gap: .5rem; margin-bottom: .75rem; }
.gp__badge {
  display: inline-flex; align-items: center; gap: .25rem;
  padding: .25rem .65rem; border-radius: 999px; font-size: .75rem; font-weight: 700;
}
.gp__badge--tipo {
  background: rgba(255,255,255,.2); color: #fff; border: 1px solid rgba(255,255,255,.3);
}
.gp__badge--inase {
  background: #ffd600; color: #1a2e1a; border: none;
}
.gp__nombre {
  font-size: clamp(1.75rem, 6vw, 2.5rem);
  font-weight: 800; color: #fff; margin: 0 0 .5rem; line-height: 1.15;
  letter-spacing: -.02em;
}
.gp__criador { color: rgba(255,255,255,.75); font-size: .875rem; }
.gp__origen { color: rgba(255,255,255,.6); }

/* Carousel */
.gp__carousel {
  background: #000;
  overflow: hidden;
}
.gp__carousel-track {
  display: flex;
  overflow-x: auto;
  scroll-snap-type: x mandatory;
  -webkit-overflow-scrolling: touch;
  scrollbar-width: none;
}
.gp__carousel-track::-webkit-scrollbar { display: none; }
.gp__carousel-slide {
  flex: 0 0 100%;
  scroll-snap-align: start;
  aspect-ratio: 4/3;
  max-height: 320px;
}
.gp__carousel-img {
  width: 100%; height: 100%; object-fit: cover;
}
.gp__carousel-dots {
  display: flex; justify-content: center; gap: .4rem;
  padding: .5rem; background: #000;
}
.gp__carousel-dot {
  width: 6px; height: 6px; border-radius: 50%; background: rgba(255,255,255,.4);
}

/* Sections */
.gp__section {
  padding: 1.25rem 1rem;
  border-bottom: 1px solid rgba(0,0,0,.06);
}
.gp__section-title {
  font-size: .7rem; font-weight: 700; letter-spacing: .08em;
  text-transform: uppercase; color: #6c757d; margin: 0 0 .875rem;
}

/* Cannabinoids */
.gp__cannabinoids { display: flex; gap: 1.5rem; }
.gp__cannabinoid { flex: 1; }
.gp__cannabinoid-label {
  font-size: .7rem; font-weight: 700; text-transform: uppercase;
  letter-spacing: .06em; color: #6c757d; margin-bottom: .25rem;
}
.gp__cannabinoid-value {
  font-size: 1.75rem; font-weight: 800; color: #1a2e1a; line-height: 1;
  margin-bottom: .5rem;
}
.gp__cannabinoid-bar {
  height: 6px; background: rgba(0,0,0,.08); border-radius: 3px; overflow: hidden;
}
.gp__cannabinoid-fill {
  height: 100%; border-radius: 3px; transition: width .5s ease;
}

/* Terpenos */
.gp__chips { display: flex; flex-wrap: wrap; gap: .5rem; }
.gp__chip {
  padding: .3rem .75rem; background: rgba(27,94,32,.1);
  color: #1b5e20; border-radius: 999px; font-size: .8rem; font-weight: 600;
  border: 1px solid rgba(27,94,32,.2);
}

/* Descripción */
.gp__descripcion {
  color: #3a3a3a; line-height: 1.65; margin: 0; font-size: .95rem;
}

/* Datos cultivo */
.gp__datos { display: flex; flex-wrap: wrap; gap: .75rem; }
.gp__dato {
  display: flex; align-items: center; gap: .75rem;
  background: #fff; border: 1px solid rgba(0,0,0,.06);
  border-radius: .75rem; padding: .75rem 1rem;
  flex: 1; min-width: 140px;
}
.gp__dato-icon { font-size: 1.5rem; flex-shrink: 0; }
.gp__dato-label { font-size: .7rem; text-transform: uppercase; letter-spacing: .06em; color: #6c757d; }
.gp__dato-val { font-size: .95rem; font-weight: 600; color: #1a2e1a; }

/* Footer */
.gp__footer {
  padding: 2rem 1rem;
  text-align: center;
  background: #f0f4f0;
}
.gp__footer-text { color: #6c757d; font-size: .85rem; margin: 0 0 .5rem; }
.gp__footer-link {
  color: #1b5e20; font-weight: 600; font-size: .9rem; text-decoration: none;
}
.gp__footer-link:hover { text-decoration: underline; }

/* Desktop */
@media (min-width: 600px) {
  .gp__page { max-width: 600px; margin: 0 auto; box-shadow: 0 0 40px rgba(0,0,0,.08); }
  .gp__hero { padding: 2.5rem 2rem 3rem; }
  .gp__section { padding: 1.5rem 2rem; }
  .gp__footer { padding: 2.5rem 2rem; }
}
</style>
