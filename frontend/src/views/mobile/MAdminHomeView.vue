<template>
  <div class="mah">
    <header class="mah__hero">
      <p class="mah__greet">{{ saludo }}</p>
      <h1 class="mah__name">{{ nombre }}</h1>
      <p class="mah__date">{{ fechaLarga }}</p>
    </header>

    <!-- Banner de atención (solo si hay algo urgente) -->
    <RouterLink v-if="aprobaciones > 0" to="/m/admin/aprobar" class="mah__banner mah__banner--amber">
      <i class="bi bi-patch-exclamation"></i>
      <span><strong>{{ aprobaciones }}</strong> {{ aprobaciones === 1 ? 'aprobación pendiente' : 'aprobaciones pendientes' }}</span>
      <i class="bi bi-chevron-right mah__banner-go"></i>
    </RouterLink>
    <div v-if="reprocannVencidos > 0" class="mah__banner mah__banner--red">
      <i class="bi bi-exclamation-octagon"></i>
      <span><strong>{{ reprocannVencidos }}</strong> REPROCANN {{ reprocannVencidos === 1 ? 'vencido' : 'vencidos' }}</span>
    </div>

    <!-- Pulso del club -->
    <section class="mah__section">
      <h2 class="mah__section-title">Pulso del club</h2>
      <div class="mah__pulse">
        <RouterLink to="/m/admin/tareas" class="mah__stat">
          <span class="mah__stat-ico" style="background:#e0f2fe;color:var(--c-sky-600)"><i class="bi bi-check2-square"></i></span>
          <span class="mah__stat-num">{{ loading ? '·' : tareasHoy }}</span>
          <span class="mah__stat-lbl">Tareas hoy</span>
        </RouterLink>
        <RouterLink to="/m/admin/aprobar" class="mah__stat">
          <span class="mah__stat-ico" style="background:#fef3c7;color:var(--c-amber-500)"><i class="bi bi-patch-check"></i></span>
          <span class="mah__stat-num">{{ loading ? '·' : aprobaciones }}</span>
          <span class="mah__stat-lbl">Aprobaciones</span>
        </RouterLink>
        <RouterLink to="/m/admin/sedes" class="mah__stat">
          <span class="mah__stat-ico" style="background:var(--c-leaf-100);color:var(--c-leaf-700)"><i class="bi bi-flower1"></i></span>
          <span class="mah__stat-num">{{ plantasActivas }}</span>
          <span class="mah__stat-lbl">Plantas activas</span>
        </RouterLink>
        <div class="mah__stat" :class="{ 'mah__stat--warn': reprocannPorVencer > 0 }">
          <span class="mah__stat-ico" :style="reprocannPorVencer > 0 ? 'background:#fef3c7;color:var(--c-amber-500)' : 'background:var(--c-ink-100);color:var(--c-ink-500)'">
            <i class="bi bi-file-earmark-medical"></i>
          </span>
          <span class="mah__stat-num">{{ reprocannPorVencer }}</span>
          <span class="mah__stat-lbl">REPROCANN x vencer</span>
        </div>
      </div>
    </section>

  </div>
</template>

<script setup>
import { computed, ref, onMounted } from 'vue'
import { useAuthStore } from '../../stores/auth'
import { useStatsStore } from '../../stores/stats.js'
import { getTareasDashboard, listPesajesManicuraAdmin, listStocksPendientes } from '../../lib/api.js'

const auth  = useAuthStore()
const stats = useStatsStore()

const nombre = computed(() => auth.user?.first_name || 'Hola')
const saludo = computed(() => {
  const h = new Date().getHours()
  if (h < 12) return 'Buenos días,'
  if (h < 19) return 'Buenas tardes,'
  return 'Buenas noches,'
})
const fechaLarga = computed(() => {
  const s = new Date().toLocaleDateString('es-AR', { weekday: 'long', day: 'numeric', month: 'long' })
  return s.charAt(0).toUpperCase() + s.slice(1)
})

// Del stats store (se comparte con el dashboard desktop)
const plantasActivas     = computed(() => stats.plantasActivas)
const reprocannVencidos  = computed(() => stats.reprocannVencidos)
const reprocannPorVencer = computed(() => stats.reprocannPorVencer)

// Pulso propio
const loading      = ref(true)
const tareasHoy    = ref(0)
const aprobaciones = ref(0)

onMounted(async () => {
  if (!stats.data) stats.fetchAll()
  const [tareasRes, manicuraRes, stockRes] = await Promise.allSettled([
    getTareasDashboard(),
    listPesajesManicuraAdmin(),
    listStocksPendientes(),
  ])
  if (tareasRes.status === 'fulfilled') tareasHoy.value = tareasRes.value.data?.stats?.pendientes || 0
  const manicura = manicuraRes.status === 'fulfilled' ? (manicuraRes.value.data?.length || 0) : 0
  const stockP   = stockRes.status === 'fulfilled' ? (stockRes.value.data?.length || 0) : 0
  aprobaciones.value = manicura + stockP
  loading.value = false
})
</script>

<style scoped>
.mah { min-height: 100%; }

.mah__hero {
  background: linear-gradient(160deg, #0F2A1E 0%, #1A3D2E 100%);
  color: #fff;
  padding: 1.4rem 1.2rem 1.6rem;
  border-radius: 0 0 24px 24px;
}
.mah__greet { margin: 0; font-size: .9rem; color: rgba(255,255,255,.7); }
.mah__name {
  margin: .1rem 0 .35rem;
  font-family: var(--font-display, sans-serif);
  font-size: 1.7rem; font-weight: 700; line-height: 1.1;
}
.mah__date { margin: 0; font-size: .78rem; color: rgba(255,255,255,.55); }

/* Banners */
.mah__banner {
  display: flex; align-items: center; gap: .6rem;
  margin: .9rem 1.1rem 0;
  padding: .75rem .9rem;
  border-radius: var(--r-xl, 14px);
  font-size: .85rem; font-weight: 600; text-decoration: none;
}
.mah__banner i:first-child { font-size: 1.1rem; flex-shrink: 0; }
.mah__banner span { flex: 1; }
.mah__banner-go { font-size: .9rem; opacity: .6; }
.mah__banner--amber { background: #fef3c7; color: #92400e; }
.mah__banner--red   { background: #fee2e2; color: #991b1b; }

.mah__section { padding: 1.2rem 1.1rem 0; }
.mah__section:last-child { padding-bottom: 1.4rem; }
.mah__section-title {
  margin: 0 0 .7rem;
  font-size: .72rem; font-weight: 700; letter-spacing: .06em; text-transform: uppercase;
  color: var(--c-ink-500, #6b7280);
}

/* Pulso */
.mah__pulse { display: grid; grid-template-columns: 1fr 1fr; gap: .6rem; }
.mah__stat {
  display: flex; flex-direction: column; gap: .15rem;
  padding: .85rem .9rem;
  background: #fff; border: 1px solid var(--c-leaf-100, #e8f0eb);
  border-radius: var(--r-xl, 14px);
  text-decoration: none;
  transition: transform .12s, box-shadow .15s, border-color .15s;
}
.mah__stat:active { transform: scale(.97); }
a.mah__stat:hover { border-color: var(--c-leaf-300, #a8c9b5); box-shadow: var(--sh-2); }
.mah__stat--warn { border-color: #fde68a; background: #fffdf5; }
.mah__stat-ico {
  width: 38px; height: 38px; border-radius: 11px;
  display: flex; align-items: center; justify-content: center;
  font-size: 1.1rem; margin-bottom: .35rem;
}
.mah__stat-num {
  font-family: var(--font-display, sans-serif);
  font-size: 1.55rem; font-weight: 700; line-height: 1;
  color: var(--c-ink-900, #1a1d1f);
}
.mah__stat-lbl { font-size: .72rem; font-weight: 600; color: var(--c-ink-500, #6b7280); }
</style>
