<template>
  <div class="gv">

    <!-- Hero -->
    <section class="gv__hero">
      <div class="gv__hero-inner">
        <div class="gv__hero-badge">
          <span class="gv__hero-badge-dot"></span>
          Variedades certificadas · Cultivo medicinal
        </div>
        <h1 class="gv__hero-title">Nuestras <span class="gv__hero-accent">variedades</span></h1>
        <p class="gv__hero-sub">Cultivamos con dedicación las mejores genéticas para uso medicinal, bajo protocolo REPROCANN.</p>
      </div>
    </section>

    <!-- Filtros -->
    <section class="gv__filtros">
      <div class="gv__container">
        <div class="gv__filtros-inner">
          <button
              v-for="f in filtros" :key="f.key"
              class="gv__filtro-btn"
              :class="{ 'gv__filtro-btn--active': filtroActivo === f.key }"
              @click="filtroActivo = f.key"
          >
            {{ f.label }}
            <span class="gv__filtro-count">{{ contarPorFiltro(f.key) }}</span>
          </button>
        </div>
      </div>
    </section>

    <!-- Grid genéticas -->
    <section class="gv__section">
      <div class="gv__container">

        <div v-if="loading" class="gv__loading">
          <div class="gv__spinner"></div>
        </div>

        <div v-else-if="geneticasFiltradas.length === 0" class="gv__empty">
          No hay variedades disponibles en este momento.
        </div>

        <div v-else class="gv__grid">
          <RouterLink
              v-for="g in geneticasFiltradas" :key="g.id"
              :to="`/geneticas/${g.id}`"
              class="gv__card"
          >
            <div class="gv__card-img">
              <img v-if="g.fotos_urls?.length" :src="g.fotos_urls[0]" :alt="g.nombre" />
              <span v-else class="gv__card-img-placeholder">🌿</span>
              <div class="gv__card-badges">
                <span v-if="g.registrada_inase" class="gv__inase-badge">INASE</span>
              </div>
            </div>
            <div class="gv__card-body">
              <div class="gv__card-header">
                <span class="gv__card-nombre">{{ g.nombre }}</span>
                <span class="gv__tipo-badge" :class="`gv__tipo-badge--${g.tipo}`">{{ formatTipo(g.tipo) }}</span>
              </div>
              <div class="gv__card-stats">
                <div class="gv__stat">
                  <span class="gv__stat-label">THC</span>
                  <span class="gv__stat-val">{{ g.thc }}%</span>
                </div>
                <div class="gv__stat">
                  <span class="gv__stat-label">CBD</span>
                  <span class="gv__stat-val gv__stat-val--cbd">{{ g.cbd }}%</span>
                </div>
                <div v-if="g.tiempo_floracion" class="gv__stat">
                  <span class="gv__stat-label">Floración</span>
                  <span class="gv__stat-val">{{ g.tiempo_floracion }}d</span>
                </div>
              </div>
              <div v-if="g.terpenos" class="gv__terpenos">
                <span v-for="t in g.terpenos.split(',').slice(0,2)" :key="t" class="gv__terpeno-pill">
                  {{ t.trim() }}
                </span>
              </div>
            </div>
            <div class="gv__card-footer">
              Ver detalles <i class="bi bi-arrow-right"></i>
            </div>
          </RouterLink>
        </div>

      </div>
    </section>

  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import publicApi from '../api/publicApi.js'

const geneticas    = ref([])
const loading      = ref(true)
const filtroActivo = ref('todas')

const filtros = [
  { key: 'todas',  label: 'Todas'   },
  { key: 'hibrida', label: 'Híbridas' },
  { key: 'indica',  label: 'Índicas'  },
  { key: 'sativa',  label: 'Sativas'  },
]

function formatTipo(tipo) {
  return { indica: 'Índica', sativa: 'Sativa', hibrida: 'Híbrida' }[tipo] || tipo
}

function contarPorFiltro(key) {
  if (key === 'todas') return geneticas.value.length
  return geneticas.value.filter(g => g.tipo === key).length
}

const geneticasFiltradas = computed(() => {
  if (filtroActivo.value === 'todas') return geneticas.value
  return geneticas.value.filter(g => g.tipo === filtroActivo.value)
})

onMounted(async () => {
  try {
    geneticas.value = await publicApi.getGeneticas()
  } catch (e) { console.error(e) }
  finally { loading.value = false }
})
</script>

<style scoped>
.gv { min-height: 100vh; }

.gv__hero {
  background: #060f07;
  padding: 5rem 2rem 4rem;
  position: relative;
  overflow: hidden;
}
.gv__hero::before {
  content: '';
  position: absolute; inset: 0;
  background: radial-gradient(ellipse at 60% 50%, #1b5e2018 0%, transparent 65%);
}
.gv__hero-inner {
  max-width: 1200px; margin: 0 auto;
  position: relative; z-index: 1;
}
.gv__hero-badge {
  display: inline-flex; align-items: center; gap: 8px;
  background: #1b5e2020; border: 1px solid #1b5e2044;
  color: #66bb6a; font-size: 12px; padding: 5px 14px;
  border-radius: 20px; margin-bottom: 1.5rem;
}
.gv__hero-badge-dot {
  width: 6px; height: 6px; background: #66bb6a;
  border-radius: 50%; flex-shrink: 0;
}
.gv__hero-title {
  color: #f0fdf4; font-size: 40px; font-weight: 500;
  line-height: 1.15; margin-bottom: 1rem;
}
.gv__hero-accent { color: #66bb6a; }
.gv__hero-sub {
  color: #81c784; font-size: 16px; line-height: 1.65;
  opacity: .8; max-width: 520px; margin: 0;
}

.gv__filtros {
  background: #f0fdf4;
  border-bottom: 1px solid #d4edda;
  padding: .75rem 0;
  position: sticky; top: 64px; z-index: 10;
}
.gv__filtros-inner {
  display: flex; gap: 8px; flex-wrap: wrap;
}
.gv__filtro-btn {
  display: flex; align-items: center; gap: 6px;
  background: white; border: 1px solid #d4edda;
  color: #4a7c59; font-size: 13px; padding: 7px 16px;
  border-radius: 20px; cursor: pointer; transition: all .2s;
}
.gv__filtro-btn:hover { border-color: #1b5e20; color: #1b5e20; }
.gv__filtro-btn--active {
  background: #1b5e20; border-color: #1b5e20;
  color: #e8f5e9;
}
.gv__filtro-count {
  background: rgba(255,255,255,.2); font-size: 11px;
  padding: 1px 7px; border-radius: 10px;
}
.gv__filtro-btn:not(.gv__filtro-btn--active) .gv__filtro-count {
  background: #e8f5e9; color: #1b5e20;
}

.gv__section { padding: 3.5rem 0; background: #f0fdf4; }
.gv__container { max-width: 1200px; margin: 0 auto; padding: 0 2rem; }

.gv__loading { display: flex; justify-content: center; padding: 4rem; }
.gv__spinner {
  width: 32px; height: 32px; border: 2px solid #d4edda;
  border-top-color: #1b5e20; border-radius: 50%;
  animation: spin .7s linear infinite;
}
@keyframes spin { to { transform: rotate(360deg); } }
.gv__empty {
  text-align: center; color: #4a7c59; padding: 4rem;
  font-size: 15px; background: white; border-radius: 16px;
  border: 1px dashed #c8e6c9;
}

.gv__grid {
  display: grid; grid-template-columns: repeat(3, 1fr); gap: 24px;
}
.gv__card {
  background: white; border: 1px solid #d4edda; border-radius: 16px;
  overflow: hidden; text-decoration: none; display: flex; flex-direction: column;
  transition: transform .2s, box-shadow .2s;
}
.gv__card:hover { transform: translateY(-5px); box-shadow: 0 12px 32px #1b5e2015; }

.gv__card-img {
  height: 200px; background: linear-gradient(135deg, #e8f5e9, #c8e6c9);
  display: flex; align-items: center; justify-content: center;
  overflow: hidden; position: relative;
}
.gv__card-img img { width: 100%; height: 100%; object-fit: cover; }
.gv__card-img-placeholder { font-size: 4rem; }
.gv__card-badges { position: absolute; top: 12px; right: 12px; }
.gv__inase-badge {
  background: #fff3e0; color: #bf360c;
  font-size: 10px; padding: 3px 9px; border-radius: 5px; font-weight: 600;
}

.gv__card-body { padding: 18px; flex: 1; }
.gv__card-header {
  display: flex; justify-content: space-between; align-items: flex-start;
  gap: 8px; margin-bottom: 14px;
}
.gv__card-nombre { font-size: 16px; font-weight: 600; color: #1a2e1b; line-height: 1.2; }
.gv__tipo-badge { display: inline-block; font-size: 11px; padding: 3px 10px; border-radius: 5px; flex-shrink: 0; }
.gv__tipo-badge--indica  { background: #e8eaf6; color: #3949ab; }
.gv__tipo-badge--sativa  { background: #fff8e1; color: #f57f17; }
.gv__tipo-badge--hibrida { background: #e8f5e9; color: #2e7d32; }

.gv__card-stats {
  display: grid; grid-template-columns: repeat(3, 1fr); gap: 8px; margin-bottom: 14px;
}
.gv__stat {
  background: #f8fdf8; border-radius: 8px; padding: 8px 10px;
}
.gv__stat-label { display: block; font-size: 10px; color: #6b8f71; text-transform: uppercase; letter-spacing: .05em; margin-bottom: 2px; }
.gv__stat-val { display: block; font-size: 16px; font-weight: 600; color: #1b5e20; }
.gv__stat-val--cbd { color: #0277bd; }

.gv__terpenos { display: flex; gap: 6px; flex-wrap: wrap; }
.gv__terpeno-pill {
  background: #f0fdf4; border: 1px solid #c8e6c9;
  color: #4a7c59; font-size: 11px; padding: 3px 10px; border-radius: 12px;
}

.gv__card-footer {
  padding: 14px 18px; border-top: 1px solid #f0fdf4;
  font-size: 13px; color: #1b5e20; font-weight: 500;
  display: flex; align-items: center; justify-content: space-between;
}

@media (max-width: 900px) { .gv__grid { grid-template-columns: repeat(2, 1fr); } }
@media (max-width: 600px) { .gv__grid { grid-template-columns: 1fr; } .gv__hero-title { font-size: 28px; } }
</style>