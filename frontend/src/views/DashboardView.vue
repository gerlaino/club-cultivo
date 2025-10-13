<template>
  <div class="dashboard">
    <div class="d-flex align-items-center justify-content-between mb-3">
      <div>
        <small class="text-muted">Bienvenido, {{ displayName }}</small>
        <h2 class="mb-0 fw-bold" style="color: var(--brand-primary)">Dashboard</h2>
        <div class="d-flex gap-2">
          <RouterLink class="btn btn-success btn-sm" to="/socios">+ Nuevo Socio</RouterLink>
          <RouterLink class="btn btn-outline-success btn-sm" to="/salas">+ Nueva Sala</RouterLink>
        </div>
      </div>
      <small class="text-muted">
        <i class="bi bi-clock me-1"></i>{{ now }}
      </small>
    </div>

    <!-- KPIs -->
    <div class="row g-3">
      <div class="col-6 col-lg-3" v-for="k in kpis" :key="k.key">
        <div class="kpi card shadow-sm border-0 h-100">
          <div class="card-body">
            <div class="kpi-icon"><i :class="k.icon"></i></div>
            <div class="kpi-label">{{ k.label }}</div>
            <div class="kpi-value">{{ k.value }}</div>
          </div>
        </div>
      </div>
    </div>

    <!-- Listas -->
    <div class="row g-3 mt-1">
      <div class="col-12 col-lg-6">
        <div class="card shadow-sm border-0 h-100">
          <div class="card-header bg-white d-flex justify-content-between align-items-center">
            <strong>Últimos socios</strong>
            <RouterLink class="btn btn-sm btn-outline-success" to="/socios">Ver todos</RouterLink>
          </div>
          <ul class="list-group list-group-flush">
            <li v-for="s in recientes.socios" :key="s.id" class="list-group-item d-flex justify-content-between">
              <span>{{ s.apellido }}, {{ s.nombre }}
                <small v-if="s.dni" class="text-muted ms-2">DNI {{ s.dni }}</small>
              </span>
              <small class="text-muted">{{ dt(s.created_at) }}</small>
            </li>
            <li v-if="!recientes.socios.length" class="list-group-item text-muted">Sin datos recientes.</li>
          </ul>
        </div>
      </div>

      <div class="col-12 col-lg-6">
        <div class="card shadow-sm border-0 h-100">
          <div class="card-header bg-white d-flex justify-content-between align-items-center">
            <strong>Salas</strong>
            <RouterLink class="btn btn-sm btn-outline-success" to="/salas">Gestionar</RouterLink>
          </div>
          <ul class="list-group list-group-flush">
            <li v-for="s in salasTop" :key="s.id" class="list-group-item d-flex justify-content-between">
              <span class="text-truncate">
                <b>{{ s.name }}</b>
                <span class="badge ms-2 text-capitalize" :class="`text-bg-${badge(s.state)}`">{{ s.state }}</span>
              </span>
              <small class="text-muted">{{ dt(s.updated_at || s.created_at) }}</small>
            </li>
            <li v-if="!salasTop.length" class="list-group-item text-muted">Sin datos.</li>
          </ul>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { onMounted, ref, computed } from "vue"
import { RouterLink } from "vue-router"
import { useAuthStore } from "../stores/auth"
import { getStats, listSalas, listSocios } from "../lib/api"

const auth = useAuthStore()
const displayName = computed(() =>
  [auth.user?.first_name, auth.user?.last_name].filter(Boolean).join(" ") || auth.email || "Usuario"
)

const stats = ref({ salas_count: 0, lotes_count: 0, socios_count: 0, users_count: 0 })
const recientes = ref({ socios: [] })
const salas = ref([])
const now = new Date().toLocaleString("es-AR")

function dt(s){ return s ? new Date(s).toLocaleString("es-AR") : "—" }
function badge(state){
  switch(state){
    case "activa": return "success"
    case "mantenimiento": return "warning"
    case "cerrada": return "secondary"
    default: return "secondary"
  }
}

const salasTop = computed(() => salas.value.slice(0,5))
const kpis = computed(() => ([
  { key: 'socios', label: 'Socios',    value: stats.value.socios_count ?? '—', icon: 'bi bi-people text-success' },
  { key: 'salas',  label: 'Salas',     value: stats.value.salas_count  ?? '—', icon: 'bi bi-building-gear text-primary' },
  { key: 'lotes',  label: 'Lotes',     value: stats.value.lotes_count  ?? '—', icon: 'bi bi-flower3 text-success' },
  { key: 'users',  label: 'Usuarios',  value: stats.value.users_count  ?? '—', icon: 'bi bi-person-badge text-secondary' },
]))

onMounted(async () => {
  try {
    const { data } = await getStats()
    stats.value = data || stats.value
  } catch(e) { console.warn("Stats no disponible", e) }

  try {
    const { data } = await listSocios()
    // acomoda según tu backend: data o data.data
    const arr = Array.isArray(data) ? data : (data?.data || [])
    recientes.value.socios = arr.slice(0,5)
  } catch(e) {}

  try {
    const { data } = await listSalas()
    salas.value = Array.isArray(data) ? data : (data?.data || [])
  } catch(e) {}
})
</script>

<style scoped>
.kpi { border-radius: 1rem; overflow: hidden; transition: transform .12s ease, box-shadow .12s ease; }
.kpi:hover { transform: translateY(-1px); box-shadow: 0 10px 24px rgba(0,0,0,.08); }
.kpi-icon{
  width: 40px; height: 40px; border-radius: 12px;
  display:flex; align-items:center; justify-content:center;
  background: color-mix(in srgb, var(--brand-accent, #81c784) 22%, transparent);
  color: var(--brand-primary, #2e7d32);
  margin-bottom: .5rem; font-size: 1.1rem;
}
.kpi-label{ font-size: .9rem; color: #6b7280; }
.kpi-value{ font-size: 1.8rem; font-weight: 800; color: #1f2937; }
</style>

