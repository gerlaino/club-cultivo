<template>
  <div class="svd">

    <!-- ── BIENVENIDA ──────────────────────────────────────────── -->
    <div class="svd__header">
      <div class="svd__header-text">
        <h1 class="svd__saludo">{{ saludo }}, {{ auth.user?.first_name }}</h1>
        <span class="svd__sub">Supervisando {{ sedes.length }} sede{{ sedes.length !== 1 ? 's' : '' }}</span>
      </div>
    </div>

    <!-- ── LOADING ─────────────────────────────────────────────── -->
    <div v-if="loading" class="svd__loading">
      <div class="svd__spinner"></div>
      <span>Cargando datos…</span>
    </div>

    <!-- ── ERROR ───────────────────────────────────────────────── -->
    <div v-else-if="error" class="svd__error">
      <span>{{ error }}</span>
    </div>

    <template v-else>

      <!-- ── SEDES GRID ───────────────────────────────────────── -->
      <section class="svd__section">
        <h2 class="svd__section-title">Mis sedes</h2>
        <div v-if="!sedes.length" class="svd__empty svd__empty--warn">
          <i class="bi bi-exclamation-triangle-fill svd__warn-icon"></i>
          <div>
            <strong>No tenés sedes asignadas.</strong>
            <span> Contactá al administrador del club para que te asigne una sede.</span>
          </div>
        </div>
        <div v-else class="svd__sedes-grid">
          <div
            v-for="sede in sedes"
            :key="sede.id"
            class="svd__sede-card"
          >
            <div class="svd__sede-header">
              <span class="svd__sede-name">{{ sede.nombre }}</span>
              <span
                v-if="tareasPorSede(sede.id) > 0"
                class="svd__sede-badge"
              >{{ tareasPorSede(sede.id) }} tarea{{ tareasPorSede(sede.id) !== 1 ? 's' : '' }}</span>
            </div>
            <div class="svd__sede-meta">
              <span class="svd__sede-stat">
                <strong>{{ sede.salas_count ?? '—' }}</strong> sala{{ (sede.salas_count ?? 0) !== 1 ? 's' : '' }}
              </span>
              <span class="svd__sede-dot" aria-hidden="true">·</span>
              <span class="svd__sede-stat">
                <strong>{{ sede.lotes_activos_count ?? '—' }}</strong> lote{{ (sede.lotes_activos_count ?? 0) !== 1 ? 's' : '' }} activo{{ (sede.lotes_activos_count ?? 0) !== 1 ? 's' : '' }}
              </span>
            </div>
          </div>
        </div>
      </section>

      <!-- ── TAREAS ACTIVAS ──────────────────────────────────── -->
      <section class="svd__section">
        <h2 class="svd__section-title">Tareas activas</h2>
        <div v-if="!tareas.length" class="svd__empty">No tenés tareas pendientes.</div>
        <div v-else class="svd__tareas-list">
          <div
            v-for="tarea in tareas"
            :key="tarea.id"
            class="svd__tarea-item"
          >
            <div class="svd__tarea-info">
              <span class="svd__tarea-titulo">{{ tarea.titulo || tarea.descripcion || `Tarea #${tarea.id}` }}</span>
              <span v-if="tarea.sede_nombre || tarea.sala_nombre" class="svd__tarea-ubicacion">
                {{ tarea.sede_nombre }}{{ tarea.sala_nombre ? ` · ${tarea.sala_nombre}` : '' }}
              </span>
            </div>
            <span
              class="svd__tarea-estado"
              :class="`svd__tarea-estado--${tarea.estado || 'pendiente'}`"
            >{{ tarea.estado || 'pendiente' }}</span>
          </div>
        </div>
      </section>

    </template>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useAuthStore } from '../../stores/auth.js'
import api from '../../lib/api.js'

const auth = useAuthStore()

const hora   = new Date().getHours()
const saludo = hora < 12 ? 'Buenos días' : hora < 19 ? 'Buenas tardes' : 'Buenas noches'

const loading = ref(true)
const error   = ref(null)
const sedes   = ref([])
const tareas  = ref([])

function tareasPorSede(sedeId) {
  return tareas.value.filter(t => t.sala?.sede_id === sedeId).length
}

onMounted(async () => {
  loading.value = true
  error.value   = null

  const [sedesResult, tareasResult] = await Promise.allSettled([
    api.get('/sedes'),
    api.get('/tareas', { params: { scope: 'mias' } }),
  ])

  if (sedesResult.status === 'fulfilled') {
    sedes.value = sedesResult.value.data ?? []
  } else {
    error.value = 'No se pudieron cargar las sedes.'
  }

  if (tareasResult.status === 'fulfilled') {
    tareas.value = tareasResult.value.data ?? []
  }
  // tareas failing is non-fatal — just show empty list

  loading.value = false
})
</script>

<style scoped>
.svd {
  padding: var(--sp-6);
  max-width: 960px;
  display: flex;
  flex-direction: column;
  gap: var(--sp-8);
}

/* Header */
.svd__header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: var(--sp-4);
}
.svd__saludo {
  font-family: var(--font-display);
  font-size: var(--fs-24);
  font-weight: 600;
  color: var(--c-ink-900);
  margin: 0;
}
.svd__sub {
  font-size: var(--fs-14);
  color: var(--c-ink-500);
  margin-top: var(--sp-1);
  display: block;
}

/* Loading */
.svd__loading {
  display: flex;
  align-items: center;
  gap: var(--sp-3);
  color: var(--c-ink-500);
  font-size: var(--fs-14);
  padding: var(--sp-8) 0;
}
.svd__spinner {
  width: 20px;
  height: 20px;
  border: 2px solid var(--c-ink-200);
  border-top-color: #0f766e;
  border-radius: 50%;
  animation: svd-spin 0.7s linear infinite;
}
@keyframes svd-spin { to { transform: rotate(360deg); } }

/* Error */
.svd__error {
  padding: var(--sp-4) var(--sp-5);
  background: var(--c-rust-100);
  color: var(--c-rust-600);
  border-radius: var(--r-md);
  font-size: var(--fs-14);
}

/* Section */
.svd__section { display: flex; flex-direction: column; gap: var(--sp-4); }
.svd__section-title {
  font-size: var(--fs-16);
  font-weight: 700;
  color: var(--c-ink-900);
  margin: 0;
}
.svd__empty {
  font-size: var(--fs-14);
  color: var(--c-ink-400);
  padding: var(--sp-4) 0;
}
.svd__empty--warn {
  display: flex;
  align-items: flex-start;
  gap: var(--sp-3);
  background: #fffbeb;
  border: 1px solid #fde68a;
  border-radius: var(--r-md);
  padding: var(--sp-4) var(--sp-5);
  color: #92400e;
}
.svd__warn-icon {
  font-size: var(--fs-16);
  flex-shrink: 0;
  margin-top: 1px;
  color: #d97706;
}

/* Sedes grid */
.svd__sedes-grid {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: var(--sp-4);
}
@media (max-width: 639px) {
  .svd__sedes-grid { grid-template-columns: 1fr; }
}

.svd__sede-card {
  background: var(--c-paper);
  border: 1px solid var(--c-ink-200);
  border-radius: var(--r-lg);
  padding: var(--sp-4) var(--sp-5);
  display: flex;
  flex-direction: column;
  gap: var(--sp-2);
  transition: box-shadow var(--t-fast), border-color var(--t-fast);
}
.svd__sede-card:hover {
  border-color: #0f766e;
  box-shadow: 0 2px 8px rgba(15, 118, 110, 0.12);
}

.svd__sede-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--sp-2);
}
.svd__sede-name {
  font-size: var(--fs-15);
  font-weight: 600;
  color: var(--c-ink-900);
}
.svd__sede-badge {
  font-size: var(--fs-11);
  font-weight: 700;
  background: #0f766e;
  color: #fff;
  padding: 2px 8px;
  border-radius: var(--r-pill);
  white-space: nowrap;
  flex-shrink: 0;
}
.svd__sede-meta {
  display: flex;
  align-items: center;
  gap: var(--sp-2);
  font-size: var(--fs-13);
  color: var(--c-ink-500);
}
.svd__sede-stat strong { color: var(--c-ink-900); font-weight: 600; }
.svd__sede-dot { color: var(--c-ink-300); }

/* Tareas list */
.svd__tareas-list {
  display: flex;
  flex-direction: column;
  border: 1px solid var(--c-ink-200);
  border-radius: var(--r-lg);
  overflow: hidden;
}
.svd__tarea-item {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--sp-4);
  padding: var(--sp-3) var(--sp-5);
  border-bottom: 1px solid var(--c-ink-100);
  background: var(--c-paper);
  transition: background var(--t-fast);
}
.svd__tarea-item:last-child { border-bottom: none; }
.svd__tarea-item:hover { background: var(--c-ink-50, #f8fafc); }

.svd__tarea-info {
  display: flex;
  flex-direction: column;
  gap: 2px;
  min-width: 0;
}
.svd__tarea-titulo {
  font-size: var(--fs-14);
  font-weight: 500;
  color: var(--c-ink-900);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.svd__tarea-ubicacion {
  font-size: var(--fs-12);
  color: var(--c-ink-500);
  font-family: var(--font-mono);
}

.svd__tarea-estado {
  font-size: var(--fs-11);
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  padding: 3px 8px;
  border-radius: var(--r-pill);
  flex-shrink: 0;
}
.svd__tarea-estado--pendiente { background: var(--c-amber-100, #fef9c3); color: #92400e; }
.svd__tarea-estado--en_progreso { background: #ccfbf1; color: #0f766e; }
.svd__tarea-estado--completada { background: var(--c-leaf-100, #dcfce7); color: var(--c-leaf-700, #15803d); }
</style>
