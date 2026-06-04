<template>
  <div class="md">
    <div class="md__hero">
      <div class="md__greeting">Hola, {{ auth.user?.first_name || 'Dispensador' }} 💊</div>
      <div class="md__date">{{ fechaHoy }}</div>
    </div>

    <!-- KPIs -->
    <div class="md__kpis">
      <div class="md__kpi">
        <div class="md__kpi-val">{{ dispensacionesHoy }}</div>
        <div class="md__kpi-lbl">Hoy</div>
      </div>
      <div class="md__kpi">
        <div class="md__kpi-val">{{ stockDisponible }}</div>
        <div class="md__kpi-lbl">Stock (g)</div>
      </div>
      <div class="md__kpi">
        <div class="md__kpi-val">{{ dispensacionesMes }}</div>
        <div class="md__kpi-lbl">Este mes</div>
      </div>
    </div>

    <!-- Acción principal -->
    <div class="md__section-title">Acción principal</div>
    <RouterLink to="/dispensar" class="md__dispensar-card">
      <i class="bi bi-bag-heart-fill md__dispensar-icon"></i>
      <div class="md__dispensar-info">
        <div class="md__dispensar-title">Nueva dispensación</div>
        <div class="md__dispensar-sub">Registrar entrega de producto a un socio</div>
      </div>
      <i class="bi bi-chevron-right" style="color:#fff;opacity:.6"></i>
    </RouterLink>

    <!-- Accesos rápidos -->
    <div class="md__section-title">Accesos rápidos</div>
    <div class="md__actions">
      <RouterLink to="/historial" class="md__action-card">
        <i class="bi bi-clock-history"></i>
        <span>Historial</span>
      </RouterLink>
      <RouterLink to="/stock-dispensador" class="md__action-card">
        <i class="bi bi-box-seam"></i>
        <span>Ver stock</span>
      </RouterLink>
    </div>

    <!-- Últimas dispensaciones -->
    <div class="md__section-title">Últimas dispensaciones</div>
    <div v-if="loadingDisp" class="md__empty">Cargando…</div>
    <div v-else-if="!ultimasDisp.length" class="md__empty">Sin dispensaciones registradas</div>
    <div v-else class="md__list">
      <div
        v-for="d in ultimasDisp"
        :key="d.id"
        class="md__disp-card"
      >
        <div class="md__disp-ico">💊</div>
        <div class="md__disp-info">
          <div class="md__disp-socio">{{ d.socio_nombre || `Socio #${d.socio_id}` }}</div>
          <div class="md__disp-sub">{{ d.gramos_entregados }}g · {{ formatTs(d.created_at) }}</div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useAuthStore } from '../../stores/auth'
import axios from 'axios'

const auth = useAuthStore()

const fechaHoy         = new Date().toLocaleDateString('es-AR', { weekday: 'long', day: 'numeric', month: 'long' })
const ultimasDisp      = ref([])
const loadingDisp      = ref(false)
const dispensacionesHoy = ref(0)
const dispensacionesMes = ref(0)
const stockDisponible  = ref('—')

function formatTs(ts) {
  if (!ts) return ''
  return new Date(ts).toLocaleDateString('es-AR', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' })
}

onMounted(async () => {
  loadingDisp.value = true
  try {
    const { data } = await axios.get('/api/dispensaciones?limite=10')
    ultimasDisp.value = data?.dispensaciones || data || []
    const hoy = new Date().toISOString().slice(0, 10)
    dispensacionesHoy.value = ultimasDisp.value.filter(d => d.created_at?.startsWith(hoy)).length
    dispensacionesMes.value = ultimasDisp.value.length
  } catch {} finally {
    loadingDisp.value = false
  }
})
</script>

<style scoped>
.md { padding: 0 0 1rem; }
.md__hero {
  background: linear-gradient(135deg, #0c1a33 0%, #1d4ed8 100%);
  padding: 1.25rem 1.25rem 1.5rem;
}
.md__greeting { font-size: 1.1rem; font-weight: 700; color: #fff; }
.md__date { font-size: .78rem; color: rgba(255,255,255,.6); margin-top: .15rem; text-transform: capitalize; }

.md__kpis { display: grid; grid-template-columns: repeat(3, 1fr); gap: .75rem; padding: 1rem 1rem 0; margin-top: -1rem; }
.md__kpi { background: #fff; border-radius: 12px; padding: .875rem .5rem; text-align: center; box-shadow: 0 2px 8px rgba(0,0,0,.06); }
.md__kpi-val { font-size: 1.5rem; font-weight: 800; color: #1d4ed8; line-height: 1; }
.md__kpi-lbl { font-size: .65rem; color: #94a3b8; font-weight: 600; margin-top: .2rem; text-transform: uppercase; letter-spacing: .04em; }

.md__section-title { font-size: .7rem; font-weight: 700; color: #94a3b8; text-transform: uppercase; letter-spacing: .06em; padding: 1.25rem 1.25rem .5rem; }

.md__dispensar-card {
  margin: 0 1rem; background: linear-gradient(135deg, #1d4ed8, #2563eb);
  border-radius: 16px; padding: 1.25rem; display: flex; align-items: center; gap: 1rem;
  text-decoration: none;
}
.md__dispensar-icon { font-size: 2.2rem; color: #fff; flex-shrink: 0; }
.md__dispensar-title { font-size: .95rem; font-weight: 800; color: #fff; }
.md__dispensar-sub { font-size: .75rem; color: rgba(255,255,255,.7); margin-top: .15rem; }
.md__dispensar-info { flex: 1; }

.md__actions { display: grid; grid-template-columns: repeat(2, 1fr); gap: .75rem; padding: 0 1rem; }
.md__action-card {
  display: flex; flex-direction: column; align-items: center; justify-content: center;
  gap: .4rem; padding: 1rem; border-radius: 14px; background: #eff6ff; color: #1d4ed8;
  text-decoration: none; font-size: .8rem; font-weight: 700;
}
.md__action-card i { font-size: 1.6rem; }

.md__list { display: flex; flex-direction: column; gap: .5rem; padding: 0 1rem; }
.md__empty { padding: .75rem 1.25rem; color: #94a3b8; font-size: .82rem; }
.md__disp-card { background: #fff; border-radius: 12px; padding: .875rem 1rem; display: flex; align-items: center; gap: .75rem; box-shadow: 0 1px 4px rgba(0,0,0,.05); }
.md__disp-ico { font-size: 1.2rem; flex-shrink: 0; }
.md__disp-socio { font-size: .88rem; font-weight: 700; color: #1a1a1a; }
.md__disp-sub { font-size: .72rem; color: #94a3b8; margin-top: .1rem; }
</style>
