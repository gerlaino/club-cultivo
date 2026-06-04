<template>
  <div class="ma">
    <div class="ma__hero">
      <div class="ma__greeting">Hola, {{ auth.user?.first_name || 'Admin' }} 🌿</div>
      <div class="ma__date">{{ fechaHoy }}</div>
    </div>

    <!-- KPIs -->
    <div class="ma__kpis">
      <div class="ma__kpi">
        <div class="ma__kpi-val">{{ pendientesCount }}</div>
        <div class="ma__kpi-lbl">Por aprobar</div>
      </div>
      <div class="ma__kpi">
        <div class="ma__kpi-val">{{ alertasCount }}</div>
        <div class="ma__kpi-lbl">Alertas</div>
      </div>
      <div class="ma__kpi">
        <div class="ma__kpi-val">{{ lotesActivos }}</div>
        <div class="ma__kpi-lbl">Lotes activos</div>
      </div>
    </div>

    <!-- Acciones -->
    <div class="ma__section-title">Acciones rápidas</div>
    <div class="ma__actions">
      <RouterLink to="/m/admin/aprobar" class="ma__action-card ma__action-card--green">
        <i class="bi bi-check-circle"></i>
        <span>Aprobar stocks</span>
        <span v-if="pendientesCount" class="ma__badge">{{ pendientesCount }}</span>
      </RouterLink>
      <RouterLink to="/m/admin/alertas" class="ma__action-card ma__action-card--amber">
        <i class="bi bi-bell"></i>
        <span>Alertas</span>
        <span v-if="alertasCount" class="ma__badge ma__badge--amber">{{ alertasCount }}</span>
      </RouterLink>
      <RouterLink to="/dispensar" class="ma__action-card ma__action-card--blue">
        <i class="bi bi-bag-heart"></i>
        <span>Dispensar</span>
      </RouterLink>
    </div>

    <!-- Alertas recientes -->
    <div class="ma__section-title">Alertas recientes</div>
    <div v-if="loadingAlertas" class="ma__empty">Cargando…</div>
    <div v-else-if="!alertas.length" class="ma__empty">Sin alertas pendientes 🎉</div>
    <div v-else class="ma__list">
      <div
        v-for="alerta in alertas.slice(0, 5)"
        :key="alerta.id"
        class="ma__alerta-card"
        :class="`ma__alerta-card--${alerta.severidad}`"
      >
        <div class="ma__alerta-ico">
          {{ alerta.severidad === 'critica' ? '🚨' : alerta.severidad === 'advertencia' ? '⚠️' : 'ℹ️' }}
        </div>
        <div class="ma__alerta-info">
          <div class="ma__alerta-msg">{{ alerta.mensaje }}</div>
          <div class="ma__alerta-ts">{{ formatTs(alerta.created_at) }}</div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useAuthStore }  from '../../stores/auth'
import { useLotesStore } from '../../stores/lotes'
import axios from 'axios'
import { getApiBase } from '../../lib/api'

const auth  = useAuthStore()
const lotes = useLotesStore()

const fechaHoy      = new Date().toLocaleDateString('es-AR', { weekday: 'long', day: 'numeric', month: 'long' })
const alertas       = ref([])
const loadingAlertas = ref(false)
const pendientesCount = ref(0)

const alertasCount  = computed(() => alertas.value.filter(a => !a.leida).length)
const lotesActivos  = computed(() => lotes.items.filter(l => l.estado !== 'finalizado').length)

function formatTs(ts) {
  if (!ts) return ''
  const d = new Date(ts)
  return d.toLocaleDateString('es-AR', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' })
}

onMounted(async () => {
  loadingAlertas.value = true
  await lotes.fetchAll?.()
  try {
    const [alertasRes, stocksRes] = await Promise.all([
      axios.get('/api/alertas_internas?limite=20'),
      axios.get('/api/stocks?estado=pendiente&limite=1'),
    ])
    alertas.value         = alertasRes.data?.alertas || alertasRes.data || []
    pendientesCount.value = stocksRes.data?.total || stocksRes.data?.length || 0
  } catch {} finally {
    loadingAlertas.value = false
  }
})
</script>

<style scoped>
.ma { padding: 0 0 1rem; }
.ma__hero {
  background: linear-gradient(135deg, #0f2417 0%, #1b5e20 100%);
  padding: 1.25rem 1.25rem 1.5rem;
}
.ma__greeting { font-size: 1.1rem; font-weight: 700; color: #fff; }
.ma__date { font-size: .78rem; color: rgba(255,255,255,.6); margin-top: .15rem; text-transform: capitalize; }

.ma__kpis { display: grid; grid-template-columns: repeat(3, 1fr); gap: .75rem; padding: 1rem 1rem 0; margin-top: -1rem; }
.ma__kpi { background: #fff; border-radius: 12px; padding: .875rem .5rem; text-align: center; box-shadow: 0 2px 8px rgba(0,0,0,.06); }
.ma__kpi-val { font-size: 1.5rem; font-weight: 800; color: #1b5e20; line-height: 1; }
.ma__kpi-lbl { font-size: .65rem; color: #94a3b8; font-weight: 600; margin-top: .2rem; text-transform: uppercase; letter-spacing: .04em; }

.ma__section-title { font-size: .7rem; font-weight: 700; color: #94a3b8; text-transform: uppercase; letter-spacing: .06em; padding: 1.25rem 1.25rem .5rem; }

.ma__actions { display: grid; grid-template-columns: repeat(3, 1fr); gap: .75rem; padding: 0 1rem; }
.ma__action-card {
  position: relative; display: flex; flex-direction: column; align-items: center;
  justify-content: center; gap: .4rem; padding: 1rem .5rem; border-radius: 14px;
  text-decoration: none; font-size: .75rem; font-weight: 700; text-align: center;
}
.ma__action-card i { font-size: 1.6rem; }
.ma__action-card--green { background: #f0fdf4; color: #15803d; }
.ma__action-card--amber { background: #fffbeb; color: #b45309; }
.ma__action-card--blue  { background: #eff6ff; color: #1d4ed8; }
.ma__badge {
  position: absolute; top: .4rem; right: .4rem;
  background: #dc2626; color: #fff; font-size: .6rem; font-weight: 800;
  padding: .1em .4em; border-radius: 999px; line-height: 1.4;
}
.ma__badge--amber { background: #d97706; }

.ma__list { display: flex; flex-direction: column; gap: .5rem; padding: 0 1rem; }
.ma__empty { padding: .75rem 1.25rem; color: #94a3b8; font-size: .82rem; }
.ma__alerta-card { background: #fff; border-radius: 12px; padding: .875rem 1rem; display: flex; align-items: flex-start; gap: .75rem; box-shadow: 0 1px 4px rgba(0,0,0,.05); border-left: 3px solid #e2e8f0; }
.ma__alerta-card--critica    { border-left-color: #dc2626; }
.ma__alerta-card--advertencia { border-left-color: #d97706; }
.ma__alerta-card--info       { border-left-color: #3b82f6; }
.ma__alerta-ico { font-size: 1.2rem; flex-shrink: 0; }
.ma__alerta-msg { font-size: .82rem; font-weight: 600; color: #1a1a1a; line-height: 1.4; }
.ma__alerta-ts  { font-size: .68rem; color: #94a3b8; margin-top: .2rem; }
</style>
