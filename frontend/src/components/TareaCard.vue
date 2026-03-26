<template>
  <div
    class="tarea-card"
    :class="[`prioridad-${tarea.prioridad}`, `estado-${tarea.estado}`, { vencida: tarea.vencida }]"
    @click="$emit('click', tarea)"
  >
    <!-- Header: prioridad + tipo + menú -->
    <div class="tarea-card__header">
      <div class="d-flex align-items-center gap-2">
        <span class="badge tipo-badge">{{ TIPO_LABELS[tarea.tipo] || tarea.tipo }}</span>
        <span v-if="tarea.vencida" class="badge bg-danger">Vencida</span>
      </div>
      <div class="tarea-card__acciones" @click.stop>
        <div class="dropdown">
          <button class="btn btn-sm btn-ghost" data-bs-toggle="dropdown">
            <i class="bi bi-three-dots-vertical"></i>
          </button>
          <ul class="dropdown-menu dropdown-menu-end shadow-sm">
            <li v-if="tarea.estado === 'pendiente'">
              <button class="dropdown-item" @click="$emit('iniciar', tarea)">
                <i class="bi bi-play-fill text-primary me-2"></i>Iniciar
              </button>
            </li>
            <li v-if="tarea.estado === 'pendiente' || tarea.estado === 'en_progreso'">
              <button class="dropdown-item" @click="$emit('completar', tarea)">
                <i class="bi bi-check-circle-fill text-success me-2"></i>Completar
              </button>
            </li>
            <li v-if="puedeEditar">
              <button class="dropdown-item" @click="$emit('editar', tarea)">
                <i class="bi bi-pencil me-2"></i>Editar
              </button>
            </li>
            <li v-if="tarea.estado !== 'completada' && puedeEditar">
              <hr class="dropdown-divider">
              <button class="dropdown-item text-danger" @click="$emit('cancelar', tarea)">
                <i class="bi bi-x-circle me-2"></i>Cancelar
              </button>
            </li>
          </ul>
        </div>
      </div>
    </div>

    <!-- Título -->
    <p class="tarea-card__titulo">{{ tarea.titulo }}</p>

    <!-- Contexto: sala / lote -->
    <div v-if="tarea.sala || tarea.lote" class="tarea-card__contexto">
      <span v-if="tarea.sala" class="text-muted small">
        <i class="bi bi-door-open me-1"></i>{{ tarea.sala.nombre }}
      </span>
      <span v-if="tarea.lote" class="text-muted small ms-2">
        <i class="bi bi-box me-1"></i>{{ tarea.lote.codigo }}
      </span>
    </div>

    <!-- Footer: fecha + horas + asignado -->
    <div class="tarea-card__footer">
      <div class="d-flex align-items-center gap-2">
        <!-- Fecha programada -->
        <span v-if="tarea.fecha_programada" class="small" :class="tarea.vencida ? 'text-danger fw-semibold' : 'text-muted'">
          <i class="bi bi-calendar3 me-1"></i>{{ formatFecha(tarea.fecha_programada) }}
        </span>
        <!-- Horas -->
        <span v-if="tarea.horas_estimadas" class="small text-muted">
          <i class="bi bi-clock me-1"></i>{{ tarea.horas_estimadas }}h
        </span>
      </div>
      <!-- Avatar asignado -->
      <div v-if="tarea.asignada_a" class="tarea-card__avatar" :title="tarea.asignada_a.nombre">
        {{ iniciales(tarea.asignada_a.nombre) }}
      </div>
    </div>

    <!-- Indicador de horas pendientes de aplicar al lote -->
    <div v-if="tarea.tiene_horas_para_lote" class="tarea-card__horas-badge" title="Horas reales disponibles para aplicar al lote">
      <i class="bi bi-clock-history"></i> {{ tarea.horas_reales }}h
    </div>
  </div>
</template>

<script setup>
import { computed } from 'vue'
import { useAuthStore } from '../stores/auth'

const props = defineProps({
  tarea: { type: Object, required: true }
})

defineEmits(['click', 'iniciar', 'completar', 'editar', 'cancelar'])

const authStore = useAuthStore()

const TIPO_LABELS = {
  riego: '💧 Riego',
  poda: '✂️ Poda',
  medicion: '📏 Medición',
  limpieza: '🧹 Limpieza',
  cosecha: '🌿 Cosecha',
  transplante: '🪴 Transplante',
  inspeccion: '🔍 Inspección',
  otro: '📋 Otro'
}

const puedeEditar = computed(() => {
  const user = authStore.user
  if (!user) return false
  return user.role === 'admin' || user.role === 'agricultor' ||
    (user.role === 'cultivador' && props.tarea.asignada_a?.id === user.id)
})

function formatFecha(fecha) {
  if (!fecha) return ''
  const d = new Date(fecha + 'T00:00:00')
  const hoy = new Date()
  hoy.setHours(0,0,0,0)
  const diff = Math.round((d - hoy) / 86400000)
  if (diff === 0) return 'Hoy'
  if (diff === -1) return 'Ayer'
  if (diff === 1) return 'Mañana'
  if (diff < 0) return `Hace ${Math.abs(diff)} días`
  return d.toLocaleDateString('es-AR', { day: 'numeric', month: 'short' })
}

function iniciales(nombre) {
  if (!nombre) return '?'
  return nombre.split(' ').map(n => n[0]).slice(0, 2).join('').toUpperCase()
}
</script>

<style scoped>
.tarea-card {
  position: relative;
  background: var(--bs-body-bg);
  border: 1px solid var(--bs-border-color);
  border-radius: 10px;
  padding: 12px 14px;
  cursor: pointer;
  transition: box-shadow 0.15s, transform 0.15s;
  border-left: 4px solid transparent;
}

.tarea-card:hover {
  box-shadow: 0 4px 12px rgba(0,0,0,0.1);
  transform: translateY(-1px);
}

/* Prioridades — borde izquierdo de color */
.prioridad-urgente { border-left-color: #dc3545; }
.prioridad-alta    { border-left-color: #fd7e14; }
.prioridad-normal  { border-left-color: #0d6efd; }
.prioridad-baja    { border-left-color: #6c757d; }

/* Estado completada: atenuado */
.estado-completada { opacity: 0.65; }

/* Vencida: fondo suave rojo */
.tarea-card.vencida { background: rgba(220, 53, 69, 0.04); }

.tarea-card__header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  margin-bottom: 8px;
}

.tipo-badge {
  background: rgba(var(--bs-primary-rgb), 0.12);
  color: var(--bs-primary);
  font-size: 0.7rem;
  font-weight: 600;
  padding: 2px 8px;
  border-radius: 20px;
}

.tarea-card__acciones .btn-ghost {
  background: transparent;
  border: none;
  color: var(--bs-secondary);
  padding: 2px 6px;
  line-height: 1;
}

.tarea-card__titulo {
  font-size: 0.88rem;
  font-weight: 600;
  color: var(--bs-body-color);
  margin: 0 0 6px;
  line-height: 1.35;
}

.tarea-card__contexto {
  margin-bottom: 8px;
}

.tarea-card__footer {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.tarea-card__avatar {
  width: 26px;
  height: 26px;
  border-radius: 50%;
  background: linear-gradient(135deg, var(--bs-primary), var(--bs-info));
  color: white;
  font-size: 0.65rem;
  font-weight: 700;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

/* Badge de horas pendientes */
.tarea-card__horas-badge {
  position: absolute;
  top: 10px;
  right: 36px;
  background: var(--bs-warning);
  color: var(--bs-dark);
  font-size: 0.65rem;
  font-weight: 700;
  padding: 2px 6px;
  border-radius: 10px;
}
</style>
