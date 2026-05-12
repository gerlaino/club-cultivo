<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { listAriccameRegistros } from '../lib/api.js'

const registros  = ref([])
const meta       = ref({ total: 0, pagina: 1, limite: 30, pendientes: 0, con_error: 0 })
const loading    = ref(true)
const detalle    = ref(null)

const filtros = ref({ estado: '', tipo: '', pagina: 1 })

const ESTADOS = [
  { value: '',           label: 'Todos los estados' },
  { value: 'pendiente',  label: 'Pendiente' },
  { value: 'enviado',    label: 'Enviado' },
  { value: 'confirmado', label: 'Confirmado' },
  { value: 'error',      label: 'Error' },
  { value: 'omitido',    label: 'Omitido' },
]
const TIPOS = [
  { value: '',                  label: 'Todos los tipos' },
  { value: 'entrada_producto',  label: 'Entrada producto' },
  { value: 'dispensacion',      label: 'Dispensación' },
  { value: 'ajuste',            label: 'Ajuste' },
]

onMounted(cargar)
watch(filtros, cargar, { deep: true })

async function cargar() {
  loading.value = true
  try {
    const params = {}
    if (filtros.value.estado) params.estado = filtros.value.estado
    if (filtros.value.tipo)   params.tipo   = filtros.value.tipo
    params.pagina = filtros.value.pagina
    params.limite = 30

    const { data } = await listAriccameRegistros(params)
    registros.value = data.data ?? []
    meta.value      = data.meta ?? meta.value
  } catch {
    registros.value = []
  } finally {
    loading.value = false
  }
}

function resetFiltros() {
  filtros.value = { estado: '', tipo: '', pagina: 1 }
}

function irPagina(p) {
  filtros.value = { ...filtros.value, pagina: p }
}

const totalPaginas = computed(() => Math.ceil(meta.value.total / 30))

// — Colores de estado
const ESTADO_CLASS = {
  pendiente:  'ar__badge--warning',
  enviado:    'ar__badge--info',
  confirmado: 'ar__badge--success',
  error:      'ar__badge--danger',
  omitido:    'ar__badge--muted',
}
function estadoClass(e) { return ESTADO_CLASS[e] || '' }

function formatFecha(ts) {
  if (!ts) return '—'
  return new Date(ts).toLocaleString('es-AR', { day: '2-digit', month: '2-digit', year: '2-digit', hour: '2-digit', minute: '2-digit' })
}
function tipoLabel(t) {
  return { entrada_producto: 'Entrada', dispensacion: 'Dispensación', ajuste: 'Ajuste' }[t] || t
}
</script>

<template>
  <div class="ar">
    <div class="ar__header">
      <div>
        <h1 class="ar__title">ARICCAME — Registros</h1>
        <p class="ar__sub">Trazabilidad regulatoria de ingresos y dispensaciones</p>
      </div>
    </div>

    <!-- KPIs -->
    <div class="ar__kpis">
      <div class="ar__kpi ar__kpi--warning" @click="filtros = { estado: 'pendiente', tipo: '', pagina: 1 }">
        <div class="ar__kpi-val">{{ meta.pendientes }}</div>
        <div class="ar__kpi-label">Pendientes de envío</div>
      </div>
      <div class="ar__kpi ar__kpi--danger" @click="filtros = { estado: 'error', tipo: '', pagina: 1 }">
        <div class="ar__kpi-val">{{ meta.con_error }}</div>
        <div class="ar__kpi-label">Con error</div>
      </div>
      <div class="ar__kpi">
        <div class="ar__kpi-val">{{ meta.total }}</div>
        <div class="ar__kpi-label">Total registros</div>
      </div>
    </div>

    <!-- Filtros -->
    <div class="ar__toolbar">
      <select class="ar__select" v-model="filtros.estado" @change="filtros.pagina = 1">
        <option v-for="e in ESTADOS" :key="e.value" :value="e.value">{{ e.label }}</option>
      </select>
      <select class="ar__select" v-model="filtros.tipo" @change="filtros.pagina = 1">
        <option v-for="t in TIPOS" :key="t.value" :value="t.value">{{ t.label }}</option>
      </select>
      <button v-if="filtros.estado || filtros.tipo" class="ar__btn-clear" @click="resetFiltros">
        <i class="bi bi-x-circle"></i> Limpiar filtros
      </button>
    </div>

    <!-- Tabla -->
    <div v-if="loading" class="ar__loading">
      <div class="ar__spinner"></div>
      <span>Cargando registros…</span>
    </div>

    <div v-else-if="!registros.length" class="ar__empty">
      Sin registros para los filtros seleccionados.
    </div>

    <div v-else class="ar__table-wrap">
      <table class="ar__table">
        <thead>
          <tr>
            <th>ID</th>
            <th>Tipo</th>
            <th>Estado</th>
            <th>Cód. ARICCAME</th>
            <th>Intentos</th>
            <th>Creado</th>
            <th>Enviado</th>
            <th>Confirmado</th>
            <th>Acciones</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="r in registros" :key="r.id" :class="{ 'ar__tr--error': r.estado === 'error' }">
            <td class="ar__td-mono">{{ r.id }}</td>
            <td>{{ tipoLabel(r.tipo) }}</td>
            <td>
              <span class="ar__badge" :class="estadoClass(r.estado)">{{ r.estado }}</span>
            </td>
            <td class="ar__td-mono">{{ r.codigo_ariccame ?? '—' }}</td>
            <td class="ar__td-center">{{ r.intentos }}</td>
            <td>{{ formatFecha(r.created_at) }}</td>
            <td>{{ formatFecha(r.enviado_at) }}</td>
            <td>{{ formatFecha(r.confirmado_at) }}</td>
            <td>
              <button class="ar__btn-detail" @click="detalle = r">
                <i class="bi bi-eye"></i>
              </button>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Paginacion -->
    <div v-if="totalPaginas > 1" class="ar__pagination">
      <button class="ar__pg-btn" :disabled="filtros.pagina <= 1" @click="irPagina(filtros.pagina - 1)">
        <i class="bi bi-chevron-left"></i>
      </button>
      <span class="ar__pg-info">{{ filtros.pagina }} / {{ totalPaginas }}</span>
      <button class="ar__pg-btn" :disabled="filtros.pagina >= totalPaginas" @click="irPagina(filtros.pagina + 1)">
        <i class="bi bi-chevron-right"></i>
      </button>
    </div>

    <!-- Modal detalle -->
    <Teleport to="body">
      <Transition name="ar-modal">
        <div v-if="detalle" class="ar__modal-overlay" @click.self="detalle = null">
          <div class="ar__modal">
            <div class="ar__modal-head">
              <span class="ar__modal-title">Registro #{{ detalle.id }}</span>
              <button class="ar__modal-close" @click="detalle = null"><i class="bi bi-x-lg"></i></button>
            </div>

            <div class="ar__modal-body">
              <div class="ar__modal-grid">
                <div class="ar__modal-field">
                  <label>Tipo</label><span>{{ tipoLabel(detalle.tipo) }}</span>
                </div>
                <div class="ar__modal-field">
                  <label>Estado</label>
                  <span class="ar__badge" :class="estadoClass(detalle.estado)">{{ detalle.estado }}</span>
                </div>
                <div class="ar__modal-field">
                  <label>Código ARICCAME</label><span>{{ detalle.codigo_ariccame ?? '—' }}</span>
                </div>
                <div class="ar__modal-field">
                  <label>Intentos</label><span>{{ detalle.intentos }}</span>
                </div>
                <div class="ar__modal-field" v-if="detalle.stock_id">
                  <label>Stock ID</label><span>{{ detalle.stock_id }}</span>
                </div>
                <div class="ar__modal-field" v-if="detalle.dispensacion_id">
                  <label>Dispensación ID</label><span>{{ detalle.dispensacion_id }}</span>
                </div>
                <div class="ar__modal-field">
                  <label>Creado</label><span>{{ formatFecha(detalle.created_at) }}</span>
                </div>
                <div class="ar__modal-field">
                  <label>Enviado</label><span>{{ formatFecha(detalle.enviado_at) }}</span>
                </div>
                <div class="ar__modal-field">
                  <label>Confirmado</label><span>{{ formatFecha(detalle.confirmado_at) }}</span>
                </div>
              </div>

              <div v-if="detalle.error_mensaje" class="ar__modal-error">
                <div class="ar__modal-error-label"><i class="bi bi-exclamation-triangle-fill"></i> Error</div>
                <div class="ar__modal-error-msg">{{ detalle.error_mensaje }}</div>
              </div>

              <div v-if="detalle.payload" class="ar__modal-json">
                <div class="ar__modal-json-label">Payload enviado</div>
                <pre class="ar__modal-pre">{{ JSON.stringify(detalle.payload, null, 2) }}</pre>
              </div>

              <div v-if="detalle.respuesta && Object.keys(detalle.respuesta).length" class="ar__modal-json">
                <div class="ar__modal-json-label">Respuesta</div>
                <pre class="ar__modal-pre">{{ JSON.stringify(detalle.respuesta, null, 2) }}</pre>
              </div>
            </div>
          </div>
        </div>
      </Transition>
    </Teleport>
  </div>
</template>

<style scoped>
.ar { padding: 1.5rem; }
.ar__header {
  display: flex; align-items: flex-start; justify-content: space-between;
  margin-bottom: 1.5rem; flex-wrap: wrap; gap: 1rem;
}
.ar__title { font-size: 1.35rem; font-weight: 700; color: var(--text-primary); margin: 0 0 .25rem; }
.ar__sub   { font-size: .85rem; color: var(--text-secondary); margin: 0; }

/* KPIs */
.ar__kpis {
  display: flex; gap: 1rem; margin-bottom: 1.25rem; flex-wrap: wrap;
}
.ar__kpi {
  flex: 1; min-width: 140px; padding: 1rem 1.2rem;
  background: var(--surface-card, #fff);
  border: 1px solid var(--border-light, #e2e8f0);
  border-radius: 12px; cursor: pointer; transition: box-shadow .15s;
}
.ar__kpi:hover { box-shadow: 0 2px 10px rgba(0,0,0,.08); }
.ar__kpi--warning { border-left: 4px solid #f59e0b; }
.ar__kpi--danger  { border-left: 4px solid #ef4444; }
.ar__kpi-val  { font-size: 1.75rem; font-weight: 700; color: var(--text-primary); }
.ar__kpi-label { font-size: .78rem; color: var(--text-secondary); margin-top: .15rem; }

/* Toolbar */
.ar__toolbar {
  display: flex; gap: .5rem; align-items: center;
  margin-bottom: 1rem; flex-wrap: wrap;
}
.ar__select {
  padding: .4rem .7rem; border: 1px solid var(--border-light, #e2e8f0);
  border-radius: 8px; font-size: .85rem; background: #fff; cursor: pointer;
}
.ar__btn-clear {
  background: none; border: 1px solid #e2e8f0; border-radius: 8px;
  padding: .4rem .75rem; font-size: .82rem; cursor: pointer; color: var(--text-secondary);
  display: flex; align-items: center; gap: .35rem;
}
.ar__btn-clear:hover { background: #f8fafc; }

/* Table */
.ar__table-wrap { overflow-x: auto; }
.ar__table {
  width: 100%; border-collapse: collapse; font-size: .84rem;
  background: var(--surface-card, #fff);
  border: 1px solid var(--border-light, #e2e8f0);
  border-radius: 10px; overflow: hidden;
}
.ar__table th {
  text-align: left; font-size: .72rem; font-weight: 700;
  text-transform: uppercase; letter-spacing: .04em;
  color: var(--text-secondary);
  background: var(--surface-muted, #f8fafc);
  padding: .6rem .9rem; border-bottom: 1px solid var(--border-light, #e2e8f0);
}
.ar__table td {
  padding: .55rem .9rem; border-bottom: 1px solid var(--border-light, #e2e8f0);
  color: var(--text-primary);
}
.ar__table tr:last-child td { border-bottom: none; }
.ar__tr--error { background: #fef2f2; }
.ar__td-mono   { font-family: monospace; font-size: .8rem; }
.ar__td-center { text-align: center; }

/* Badges */
.ar__badge {
  display: inline-block; padding: .2rem .5rem;
  border-radius: 999px; font-size: .72rem; font-weight: 600;
}
.ar__badge--warning { background: #fef3c7; color: #92400e; }
.ar__badge--info    { background: #dbeafe; color: #1e40af; }
.ar__badge--success { background: #dcfce7; color: #166534; }
.ar__badge--danger  { background: #fee2e2; color: #991b1b; }
.ar__badge--muted   { background: #f1f5f9; color: #64748b; }

/* Actions */
.ar__btn-detail {
  background: none; border: 1px solid var(--border-light, #e2e8f0);
  border-radius: 6px; padding: .25rem .5rem; cursor: pointer;
  color: var(--text-secondary); font-size: .85rem;
}
.ar__btn-detail:hover { background: #f8fafc; }

/* Pagination */
.ar__pagination {
  display: flex; align-items: center; justify-content: center;
  gap: .75rem; margin-top: 1rem;
}
.ar__pg-btn {
  background: none; border: 1px solid var(--border-light, #e2e8f0);
  border-radius: 8px; padding: .35rem .65rem; cursor: pointer;
}
.ar__pg-btn:disabled { opacity: .4; cursor: default; }
.ar__pg-info { font-size: .85rem; color: var(--text-secondary); }

/* Loading / empty */
.ar__loading {
  display: flex; align-items: center; gap: .75rem;
  padding: 3rem 1rem; color: var(--text-secondary);
}
.ar__spinner {
  width: 22px; height: 22px; border-radius: 50%;
  border: 3px solid #e2e8f0; border-top-color: #1b5e20;
  animation: ar-spin .8s linear infinite;
}
@keyframes ar-spin { to { transform: rotate(360deg); } }
.ar__empty {
  padding: 2.5rem 1rem; text-align: center; color: var(--text-secondary); font-size: .9rem;
}

/* Modal */
.ar__modal-overlay {
  position: fixed; inset: 0; background: rgba(0,0,0,.45);
  display: flex; align-items: center; justify-content: center;
  z-index: 1000; padding: 1rem;
}
.ar__modal {
  background: #fff; border-radius: 14px; width: 100%; max-width: 640px;
  max-height: 85vh; display: flex; flex-direction: column;
  box-shadow: 0 20px 60px rgba(0,0,0,.25);
}
.ar__modal-head {
  display: flex; align-items: center; justify-content: space-between;
  padding: 1rem 1.25rem; border-bottom: 1px solid #e2e8f0;
}
.ar__modal-title { font-weight: 700; font-size: 1rem; }
.ar__modal-close {
  background: none; border: none; cursor: pointer; font-size: 1rem;
  color: var(--text-secondary); padding: .25rem;
}
.ar__modal-body {
  overflow-y: auto; padding: 1.25rem; display: flex; flex-direction: column; gap: 1rem;
}
.ar__modal-grid {
  display: grid; grid-template-columns: 1fr 1fr; gap: .5rem .75rem;
}
.ar__modal-field {
  display: flex; flex-direction: column; gap: .2rem;
}
.ar__modal-field label {
  font-size: .72rem; font-weight: 600; text-transform: uppercase;
  letter-spacing: .04em; color: var(--text-secondary);
}
.ar__modal-field span { font-size: .88rem; color: var(--text-primary); }
.ar__modal-error {
  background: #fef2f2; border: 1px solid #fca5a5; border-radius: 8px; padding: .75rem 1rem;
}
.ar__modal-error-label {
  font-size: .8rem; font-weight: 700; color: #991b1b; margin-bottom: .35rem;
  display: flex; align-items: center; gap: .35rem;
}
.ar__modal-error-msg { font-size: .84rem; color: #7f1d1d; }
.ar__modal-json-label {
  font-size: .75rem; font-weight: 700; text-transform: uppercase;
  letter-spacing: .04em; color: var(--text-secondary); margin-bottom: .35rem;
}
.ar__modal-pre {
  background: #0f172a; color: #e2e8f0; border-radius: 8px;
  padding: .75rem 1rem; font-size: .75rem; overflow-x: auto;
  white-space: pre; max-height: 200px;
}

/* Transitions */
.ar-modal-enter-active, .ar-modal-leave-active { transition: all .2s; }
.ar-modal-enter-from, .ar-modal-leave-to { opacity: 0; }
.ar-modal-enter-from .ar__modal, .ar-modal-leave-to .ar__modal { transform: scale(.96); }
</style>
