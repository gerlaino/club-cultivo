<template>
  <div class="medico-dashboard">
    <!-- Métricas médicas -->
    <div class="row g-3 mb-4">
      <div class="col-md-4">
        <div class="stat-card bg-primary text-white">
          <div class="stat-icon">
            <i class="bi bi-people-fill"></i>
          </div>
          <div class="stat-content">
            <div class="stat-value">{{ stats.socios_count || 0 }}</div>
            <div class="stat-label">Pacientes Activos</div>
          </div>
        </div>
      </div>

      <div class="col-md-4">
        <div class="stat-card bg-warning text-white">
          <div class="stat-icon">
            <i class="bi bi-exclamation-triangle-fill"></i>
          </div>
          <div class="stat-content">
            <div class="stat-value">{{ stats.reprocann_por_vencer || 0 }}</div>
            <div class="stat-label">Vencen este mes</div>
          </div>
        </div>
      </div>

      <div class="col-md-4">
        <div class="stat-card bg-success text-white">
          <div class="stat-icon">
            <i class="bi bi-file-text-fill"></i>
          </div>
          <div class="stat-content">
            <div class="stat-value">{{ indicacionesEsteMes }}</div>
            <div class="stat-label">Indicaciones este mes</div>
          </div>
        </div>
      </div>
    </div>

    <!-- Accesos rápidos -->
    <div class="row g-3 mb-4">
      <div class="col-12">
        <h4 class="mb-3">Accesos Rápidos</h4>
      </div>

      <div class="col-md-6">
        <button @click="$router.push('/socios')" class="quick-action-card w-100 border-0">
          <i class="bi bi-person-plus-fill"></i>
          <span>Nuevo Paciente</span>
          <small class="text-muted">Ir a pacientes y crear uno nuevo</small>
        </button>
      </div>

      <div class="col-md-6">
        <button @click="$router.push('/socios')" class="quick-action-card w-100 border-0">
          <i class="bi bi-file-earmark-medical"></i>
          <span>Nueva Indicación</span>
          <small class="text-muted">Ir a un paciente para emitir</small>
        </button>
      </div>
    </div>

    <!-- Indicaciones por vencer -->
    <div v-if="indicacionesPorVencer.length > 0" class="row mb-4">
      <div class="col-12">
        <div class="card border-info">
          <div class="card-header bg-info bg-opacity-10">
            <h5 class="mb-0">
              <i class="bi bi-clock-history text-info"></i>
              Indicaciones por Vencer
            </h5>
          </div>
          <div class="card-body">
            <div class="alert-list">
              <div v-for="ind in indicacionesPorVencer" :key="ind.id" class="alert-item">
                <div class="alert-icon text-info">
                  <i class="bi bi-file-medical-fill"></i>
                </div>
                <div class="alert-content">
                  <div class="alert-text">
                    <strong>{{ ind.socio_nombre }}</strong> - {{ ind.patologia }}
                  </div>
                  <div class="text-muted small">
                    Vence: {{ formatDate(ind.fecha_vencimiento) }} ({{ ind.dias_hasta_vencimiento }} días)
                  </div>
                </div>
                <RouterLink :to="`/socios/${ind.socio_id}`" class="btn btn-sm btn-outline-primary">
                  Ver
                </RouterLink>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Alertas REPROCANN -->
    <div class="row">
      <div class="col-12">
        <div class="card border-warning">
          <div class="card-header bg-warning bg-opacity-10">
            <h5 class="mb-0">
              <i class="bi bi-exclamation-triangle text-warning"></i>
              Autorizaciones REPROCANN por Vencer
            </h5>
          </div>
          <div class="card-body">
            <div v-if="loading" class="text-center py-4">
              <div class="spinner-border spinner-border-sm text-warning"></div>
            </div>
            <div v-else-if="sociosPorVencer.length === 0" class="text-center py-4 text-muted">
              <i class="bi bi-check-circle display-6 text-success"></i>
              <p class="mt-2 mb-0">No hay autorizaciones próximas a vencer</p>
            </div>
            <div v-else class="alert-list">
              <div v-for="socio in sociosPorVencer" :key="socio.id" class="alert-item">
                <div class="alert-icon text-warning">
                  <i class="bi bi-clock-fill"></i>
                </div>
                <div class="alert-content">
                  <div class="alert-text">
                    <strong>{{ socio.nombre }} {{ socio.apellido }}</strong> - Vence en {{ diasHastaVencimiento(socio.reprocann_vencimiento) }} días
                  </div>
                  <div class="text-muted small">REPROCANN #{{ socio.reprocann_numero }}</div>
                </div>
                <RouterLink :to="`/socios/${socio.id}`" class="btn btn-sm btn-outline-primary">
                  Ver
                </RouterLink>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, computed } from 'vue'
import { listSocios, listIndicaciones } from '../../lib/api.js'

const stats = ref({})
const loading = ref(true)
const socios = ref([])
const todasIndicaciones = ref([])

const sociosPorVencer = computed(() => {
  return socios.value.filter(s => {
    if (!s.reprocann_vencimiento) return false
    const dias = diasHastaVencimiento(s.reprocann_vencimiento)
    return dias >= 0 && dias <= 30
  }).sort((a, b) => {
    const diasA = diasHastaVencimiento(a.reprocann_vencimiento)
    const diasB = diasHastaVencimiento(b.reprocann_vencimiento)
    return diasA - diasB
  })
})

const indicacionesPorVencer = computed(() => {
  return todasIndicaciones.value
    .filter(ind => ind.por_vencer && ind.activa)
    .sort((a, b) => a.dias_hasta_vencimiento - b.dias_hasta_vencimiento)
    .slice(0, 5)
})

const indicacionesEsteMes = computed(() => {
  const hoy = new Date()
  const inicioMes = new Date(hoy.getFullYear(), hoy.getMonth(), 1)
  return todasIndicaciones.value.filter(ind => {
    const fecha = new Date(ind.fecha_emision)
    return fecha >= inicioMes
  }).length
})

const formatDate = (date) => {
  if (!date) return '-'
  return new Date(date).toLocaleDateString('es-AR', {
    year: 'numeric',
    month: 'long',
    day: 'numeric'
  })
}

const diasHastaVencimiento = (fecha) => {
  if (!fecha) return null
  const hoy = new Date()
  const vencimiento = new Date(fecha)
  const diff = vencimiento - hoy
  return Math.ceil(diff / (1000 * 60 * 60 * 24))
}

const cargarIndicaciones = async () => {
  try {
    const promises = socios.value.map(async (socio) => {
      try {
        const { data } = await listIndicaciones(socio.id)
        return data.map(ind => ({
          ...ind,
          socio_id: socio.id,
          socio_nombre: `${socio.nombre} ${socio.apellido}`
        }))
      } catch (error) {
        return []
      }
    })
    const results = await Promise.all(promises)
    todasIndicaciones.value = results.flat()
  } catch (error) {
    console.error('Error cargando indicaciones:', error)
  }
}

onMounted(async () => {
  try {
    loading.value = true

    // Cargar stats y socios en paralelo
    const [statsRes, sociosRes] = await Promise.all([
      fetch('http://localhost:3001/stats', {
        headers: {
          'Authorization': `Bearer ${localStorage.getItem('jwt_token')}`,
          'Content-Type': 'application/json'
        }
      }).then(r => r.json()),
      listSocios()
    ])

    console.log('sociosRes completo:', sociosRes)
    console.log('sociosRes.data:', sociosRes.data)

    stats.value = statsRes
    socios.value = Array.isArray(sociosRes.data) ? sociosRes.data : []

    console.log('socios.value después de asignar:', socios.value)

    // Cargar indicaciones después de tener los socios
    if (socios.value.length > 0) {
      await cargarIndicaciones()
    }
  } catch (error) {
    console.error('Error cargando datos:', error)
  } finally {
    loading.value = false
  }
})
</script>

<style scoped>
.stat-card {
  border-radius: 12px;
  padding: 1.5rem;
  display: flex;
  align-items: center;
  gap: 1rem;
  box-shadow: 0 2px 8px rgba(0,0,0,0.1);
}

.stat-icon {
  font-size: 2.5rem;
  opacity: 0.9;
}

.stat-value {
  font-size: 2rem;
  font-weight: 700;
  line-height: 1;
  margin-bottom: 0.25rem;
}

.stat-label {
  font-size: 0.875rem;
  opacity: 0.9;
}

.quick-action-card {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 2rem;
  background: white;
  border: 2px solid #e9ecef;
  border-radius: 12px;
  text-decoration: none;
  color: #495057;
  transition: all 0.2s;
  gap: 0.75rem;
  cursor: pointer;
}

.quick-action-card:hover {
  border-color: #198754;
  color: #198754;
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(25, 135, 84, 0.15);
}

.quick-action-card i {
  font-size: 2.5rem;
}

.quick-action-card span {
  font-weight: 600;
}

.alert-list {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.alert-item {
  display: flex;
  align-items: center;
  gap: 1rem;
  padding: 1rem;
  border-radius: 8px;
  background: #f8f9fa;
}

.alert-icon {
  font-size: 1.5rem;
}

.alert-content {
  flex: 1;
}
</style>
