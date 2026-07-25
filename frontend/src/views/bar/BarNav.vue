<script setup>
// Esqueleto de navegación del bar (B1 del rediseño del Salón): identidad del bar + sub-nav fija
// (Resumen · Vender · Stock · Eventos) + chip de caja. Compartido por todas las pantallas del bar.
// Gating por rol: el dispensador solo ve Vender + Stock (sin plata, sin eventos).
import { computed, onMounted } from 'vue'
import { useBarStore } from '../../stores/bar.js'
import { useAuthStore } from '../../stores/auth.js'

const props = defineProps({
  barId:  { type: [String, Number], required: true },
  active: { type: String, required: true }, // 'resumen' | 'vender' | 'stock' | 'eventos'
})

const store = useBarStore()
const auth  = useAuthStore()

const esGestion = computed(() => ['admin', 'supervisor'].includes(auth.user?.role))
const mismoBar  = (b) => b && String(b.id) === String(props.barId)
// Nombre del bar: del barActual si coincide, si no lo busca en la lista (así el nav funciona en
// cualquier pantalla sin que cada una cargue el bar).
const bar = computed(() => mismoBar(store.barActual) ? store.barActual : store.bares.find(b => String(b.id) === String(props.barId)) || null)
// Chip de caja: solo cuando el dashboard de ESTE bar ya está cargado (evita estados falsos).
const dashOk = computed(() => mismoBar(store.dashboard?.bar))
const caja   = computed(() => dashOk.value ? (store.dashboard?.caja || null) : null)

onMounted(() => { if (!bar.value && !store.bares.length) store.fetchBares() })

// Tabs visibles según rol. El dispensador solo opera: Vender + Stock.
const TABS = computed(() => {
  const all = [
    { key: 'resumen', label: 'Resumen', to: `/bar/${props.barId}/panel`,   gestion: true },
    { key: 'vender',  label: 'Vender',  to: `/bar/${props.barId}/vender`,   gestion: false },
    { key: 'stock',   label: 'Stock',   to: `/bar/${props.barId}/stock`,    gestion: false },
    { key: 'eventos', label: 'Eventos', to: `/bar/${props.barId}/eventos`,  gestion: true },
  ]
  return all.filter(t => !t.gestion || esGestion.value)
})
</script>

<template>
  <div class="bn">
    <div class="bn__top">
      <div class="bn__id">
        <h1 class="bn__name"><span class="bn__glass">🍸</span> {{ bar?.nombre || 'Salón' }}</h1>
        <p class="bn__sede" v-if="bar?.sede">{{ bar.sede.nombre }} · {{ bar.sede.tipo }}</p>
      </div>
      <div class="bn__right">
        <RouterLink to="/bar" class="bn__bares">Bares</RouterLink>
        <span v-if="dashOk" class="bn__caja" :class="{ 'is-closed': !caja }">
          <span class="bn__pulse"></span>{{ caja ? 'Caja abierta' : 'Sin caja' }}
        </span>
      </div>
    </div>
    <nav class="bn__nav">
      <RouterLink v-for="t in TABS" :key="t.key" :to="t.to" class="bn__tab" :class="{ 'is-on': active === t.key }">
        {{ t.label }}
      </RouterLink>
    </nav>
  </div>
</template>

<style scoped>
.bn { margin-bottom: 1.25rem; }
.bn__top { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; flex-wrap: wrap;
  padding: 1.15rem 1.35rem; border: 1px solid #e6ebf1; border-radius: 14px 14px 0 0;
  background: linear-gradient(180deg, #f4ebe3, transparent 160%); }
.bn__name { font-size: 1.35rem; font-weight: 800; letter-spacing: -.03em; margin: 0; display: flex; align-items: center; gap: .55rem; color: #0f172a; }
.bn__glass { color: #9a5b34; }
.bn__sede { font-size: .8rem; color: #94a3b8; margin: .1rem 0 0; text-transform: capitalize; }
.bn__right { display: flex; align-items: center; gap: .6rem; }
.bn__bares { font-size: .82rem; font-weight: 600; color: #64748b; text-decoration: none; border: 1px solid #e2e8f0; background: #fff; padding: .45rem .8rem; border-radius: 9px; }
.bn__bares:hover { border-color: #cbd5e1; color: #334155; }
.bn__caja { display: inline-flex; align-items: center; gap: .5rem; font-size: .8rem; font-weight: 650; color: #334155; background: #fff; border: 1px solid #e2e8f0; padding: .45rem .8rem; border-radius: 999px; }
.bn__pulse { width: 8px; height: 8px; border-radius: 50%; background: #15803d; box-shadow: 0 0 0 3px #e8f6ec; }
.bn__caja.is-closed .bn__pulse { background: #94a3b8; box-shadow: 0 0 0 3px #f1f5f9; }

.bn__nav { display: flex; gap: 2px; padding: 0 .6rem; border: 1px solid #e6ebf1; border-top: none; border-radius: 0 0 14px 14px; background: #fff; overflow-x: auto; }
.bn__tab { position: relative; font-size: .9rem; font-weight: 600; color: #64748b; text-decoration: none; padding: .85rem 1rem .75rem; white-space: nowrap; }
.bn__tab:hover { color: #334155; }
.bn__tab.is-on { color: #9a5b34; }
.bn__tab.is-on::after { content: ""; position: absolute; left: .8rem; right: .8rem; bottom: 0; height: 2.5px; border-radius: 3px 3px 0 0; background: #9a5b34; }
</style>
