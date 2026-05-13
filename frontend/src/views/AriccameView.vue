<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { listAriccameRegistros } from '../lib/api.js'

const registros  = ref([])
const meta       = ref({ total: 0, pagina: 1, limite: 30, pendientes: 0, con_error: 0 })
const loading    = ref(true)
const detalle    = ref(null)
const infoAbierto = ref(false)

const filtros = ref({ estado: '', tipo: '', pagina: 1 })

const ESTADOS = [
  { value: '',           label: 'Todos' },
  { value: 'pendiente',  label: 'Pendiente' },
  { value: 'enviado',    label: 'Enviado' },
  { value: 'confirmado', label: 'Confirmado' },
  { value: 'error',      label: 'Error' },
  { value: 'omitido',    label: 'Omitido' },
]
const TIPOS = [
  { value: '',                  label: 'Todos los tipos' },
  { value: 'entrada_producto',  label: 'Entrada de producto' },
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

function setEstado(val) {
  filtros.value = { ...filtros.value, estado: val, pagina: 1 }
}

function setTipo(val) {
  filtros.value = { ...filtros.value, tipo: val, pagina: 1 }
}

function irPagina(p) {
  filtros.value = { ...filtros.value, pagina: p }
}

const totalPaginas = computed(() => Math.ceil(meta.value.total / 30))
const enviados = computed(() => Math.max(0, meta.value.total - meta.value.pendientes - meta.value.con_error))

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

const hayFiltros = computed(() => filtros.value.estado || filtros.value.tipo)
</script>

<template>
  <div class="ar">

    <!-- Header -->
    <div class="ar__header">
      <div class="ar__header-left">
        <div class="ar__title-row">
          <h1 class="ar__title">ARICCAME</h1>
          <span class="ar__title-badge">Registro regulatorio</span>
        </div>
        <p class="ar__sub">Trazabilidad de ingresos y dispensaciones reportados al sistema nacional</p>
      </div>
      <button class="ar__info-toggle" @click="infoAbierto = !infoAbierto">
        <i class="bi" :class="infoAbierto ? 'bi-chevron-up' : 'bi-info-circle'"></i>
        {{ infoAbierto ? 'Ocultar' : '¿Cómo funciona?' }}
      </button>
    </div>

    <!-- Panel info colapsable -->
    <Transition name="ar-info">
      <div v-if="infoAbierto" class="ar__info-panel">
        <div class="ar__info-title"><i class="bi bi-shield-check"></i> ¿Qué es ARICCAME?</div>
        <p class="ar__info-desc">
          ARICCAME es el sistema regulatorio nacional al que los clubes deben reportar automáticamente cada ingreso de producto al stock y cada dispensación realizada a socios. Este módulo muestra el estado de cada registro enviado al sistema.
        </p>
        <div class="ar__info-steps">
          <div class="ar__info-step">
            <span class="ar__info-step-num">1</span>
            <div>
              <strong>Se genera un evento</strong>
              <span>Un lote pasa a stock o se realiza una dispensación</span>
            </div>
          </div>
          <div class="ar__info-step">
            <span class="ar__info-step-num">2</span>
            <div>
              <strong>Se crea el registro</strong>
              <span>El sistema genera automáticamente un registro ARICCAME en estado <em>pendiente</em></span>
            </div>
          </div>
          <div class="ar__info-step">
            <span class="ar__info-step-num">3</span>
            <div>
              <strong>Se envía al organismo</strong>
              <span>Un proceso de fondo lo envía a la API regulatoria → pasa a <em>enviado</em></span>
            </div>
          </div>
          <div class="ar__info-step">
            <span class="ar__info-step-num">4</span>
            <div>
              <strong>Confirmación o error</strong>
              <span>Si el organismo acepta, queda <em>confirmado</em>. Si rechaza, queda en <em>error</em> y se reintenta</span>
            </div>
          </div>
        </div>
      </div>
    </Transition>

    <!-- KPIs -->
    <div class="ar__kpis">
      <div class="ar__kpi" :class="{ 'ar__kpi--active': !filtros.estado }" @click="setEstado('')">
        <div class="ar__kpi-icon">📋</div>
        <div class="ar__kpi-val">{{ meta.total }}</div>
        <div class="ar__kpi-label">Total registros</div>
      </div>
      <div class="ar__kpi ar__kpi--success" :class="{ 'ar__kpi--active': filtros.estado === 'confirmado' }" @click="setEstado('confirmado')">
        <div class="ar__kpi-icon">✅</div>
        <div class="ar__kpi-val">{{ enviados }}</div>
        <div class="ar__kpi-label">Enviados</div>
      </div>
      <div class="ar__kpi ar__kpi--warning" :class="{ 'ar__kpi--active': filtros.estado === 'pendiente' }" @click="setEstado('pendiente')">
        <div class="ar__kpi-icon">⏳</div>
        <div class="ar__kpi-val">{{ meta.pendientes }}</div>
        <div class="ar__kpi-label">Pendientes</div>
      </div>
      <div class="ar__kpi ar__kpi--danger" :class="{ 'ar__kpi--active': filtros.estado === 'error' }" @click="setEstado('error')">
        <div class="ar__kpi-icon">❌</div>
        <div class="ar__kpi-val">{{ meta.con_error }}</div>
        <div class="ar__kpi-label">Con error</div>
      </div>
    </div>

    <!-- Filtros pill -->
    <div class="ar__filters">
      <!-- Pills de estado -->
      <div class="ar__filter-group">
        <span class="ar__filter-group-label">Estado</span>
        <div class="ar__pills">
          <button
            v-for="e in ESTADOS"
            :key="e.value"
            class="ar__pill"
            :class="{ 'ar__pill--active': filtros.estado === e.value }"
            @click="setEstado(e.value)"
          >{{ e.label }}</button>
        </div>
      </div>
      <!-- Pills de tipo -->
      <div class="ar__filter-group">
        <span class="ar__filter-group-label">Tipo</span>
        <div class="ar__pills">
          <button
            v-for="t in TIPOS"
            :key="t.value"
            class="ar__pill"
            :class="{ 'ar__pill--active': filtros.tipo === t.value }"
            @click="setTipo(t.value)"
          >{{ t.label }}</button>
        </div>
      </div>
      <button v-if="hayFiltros" class="ar__btn-clear" @click="resetFiltros">
        <i class="bi bi-x-circle"></i> Limpiar
      </button>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="ar__loading">
      <div class="ar__spinner"></div>
      <span>Cargando registros ARICCAME…</span>
    </div>

    <!-- Empty state -->
    <div v-else-if="!registros.length" class="ar__empty">
      <div class="ar__empty-icon">
        <i class="bi bi-shield-check"></i>
      </div>
      <h2 class="ar__empty-title">
        {{ hayFiltros ? 'Sin registros para este filtro' : 'Sin registros ARICCAME aún' }}
      </h2>
      <p class="ar__empty-desc">
        <template v-if="hayFiltros">
          No hay registros que coincidan con los filtros seleccionados. Probá limpiar los filtros.
        </template>
        <template v-else>
          Los registros aparecen automáticamente cuando se genera stock de un lote o se realiza una dispensación.
          Hasta que eso suceda, esta sección estará vacía.
        </template>
      </p>
      <button v-if="hayFiltros" class="ar__empty-btn" @click="resetFiltros">
        <i class="bi bi-x-circle"></i> Limpiar filtros
      </button>
    </div>

    <!-- Tabla -->
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
            <th></th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="r in registros" :key="r.id" :class="{ 'ar__tr--error': r.estado === 'error' }">
            <td class="ar__td-mono ar__td-muted">{{ r.id }}</td>
            <td class="ar__td-tipo">{{ tipoLabel(r.tipo) }}</td>
            <td>
              <span class="ar__badge" :class="estadoClass(r.estado)">{{ r.estado }}</span>
            </td>
            <td class="ar__td-mono">{{ r.codigo_ariccame ?? '—' }}</td>
            <td class="ar__td-center ar__td-muted">{{ r.intentos }}</td>
            <td class="ar__td-fecha">{{ formatFecha(r.created_at) }}</td>
            <td class="ar__td-fecha">{{ formatFecha(r.enviado_at) }}</td>
            <td class="ar__td-fecha">{{ formatFecha(r.confirmado_at) }}</td>
            <td>
              <button class="ar__btn-detail" @click="detalle = r" title="Ver detalle">
                <i class="bi bi-eye"></i>
              </button>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Paginación -->
    <div v-if="totalPaginas > 1" class="ar__pagination">
      <button class="ar__pg-btn" :disabled="filtros.pagina <= 1" @click="irPagina(filtros.pagina - 1)">
        <i class="bi bi-chevron-left"></i>
      </button>
      <span class="ar__pg-info">Página {{ filtros.pagina }} de {{ totalPaginas }}</span>
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
              <div class="ar__modal-head-left">
                <span class="ar__modal-title">Registro #{{ detalle.id }}</span>
                <span class="ar__badge" :class="estadoClass(detalle.estado)">{{ detalle.estado }}</span>
              </div>
              <button class="ar__modal-close" @click="detalle = null"><i class="bi bi-x-lg"></i></button>
            </div>

            <div class="ar__modal-body">
              <div class="ar__modal-grid">
                <div class="ar__modal-field">
                  <label>Tipo</label><span>{{ tipoLabel(detalle.tipo) }}</span>
                </div>
                <div class="ar__modal-field">
                  <label>Código ARICCAME</label>
                  <span class="ar__modal-mono">{{ detalle.codigo_ariccame ?? '—' }}</span>
                </div>
                <div class="ar__modal-field">
                  <label>Intentos</label><span>{{ detalle.intentos }}</span>
                </div>
                <div v-if="detalle.stock_id" class="ar__modal-field">
                  <label>Stock ID</label><span>{{ detalle.stock_id }}</span>
                </div>
                <div v-if="detalle.dispensacion_id" class="ar__modal-field">
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
                <div class="ar__modal-error-label">
                  <i class="bi bi-exclamation-triangle-fill"></i> Error del sistema
                </div>
                <div class="ar__modal-error-msg">{{ detalle.error_mensaje }}</div>
              </div>

              <div v-if="detalle.payload" class="ar__modal-json">
                <div class="ar__modal-json-label">Payload enviado</div>
                <pre class="ar__modal-pre">{{ JSON.stringify(detalle.payload, null, 2) }}</pre>
              </div>

              <div v-if="detalle.respuesta && Object.keys(detalle.respuesta).length" class="ar__modal-json">
                <div class="ar__modal-json-label">Respuesta recibida</div>
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
.ar { padding: var(--sp-6, 1.5rem); }

/* Header */
.ar__header {
  display: flex; align-items: flex-start; justify-content: space-between;
  margin-bottom: 1.5rem; flex-wrap: wrap; gap: 1rem;
}
.ar__header-left { display: flex; flex-direction: column; gap: .35rem; }
.ar__title-row { display: flex; align-items: center; gap: .75rem; }
.ar__title { font-size: 1.45rem; font-weight: 800; color: var(--c-ink-900, #0f172a); margin: 0; letter-spacing: -.02em; }
.ar__title-badge {
  font-size: .68rem; font-weight: 700; text-transform: uppercase; letter-spacing: .05em;
  background: #dbeafe; color: #1e40af; padding: .25em .65em; border-radius: 999px;
}
.ar__sub { font-size: .82rem; color: var(--c-ink-500, #64748b); margin: 0; }
.ar__info-toggle {
  display: inline-flex; align-items: center; gap: .4rem;
  background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 8px;
  padding: .5rem .875rem; font-size: .82rem; font-weight: 500; color: #475569;
  cursor: pointer; transition: all .15s; white-space: nowrap; flex-shrink: 0;
}
.ar__info-toggle:hover { background: #f1f5f9; border-color: #cbd5e1; }

/* Info panel */
.ar__info-panel {
  background: #eff6ff; border: 1.5px solid #bfdbfe; border-radius: 12px;
  padding: 1.25rem 1.5rem; margin-bottom: 1.5rem;
  display: flex; flex-direction: column; gap: .875rem;
}
.ar__info-title {
  font-size: .9rem; font-weight: 700; color: #1e40af;
  display: flex; align-items: center; gap: .4rem;
}
.ar__info-desc { font-size: .82rem; color: #1e3a8a; line-height: 1.6; margin: 0; }
.ar__info-steps { display: flex; flex-direction: column; gap: .5rem; }
.ar__info-step {
  display: flex; align-items: flex-start; gap: .75rem;
  background: rgba(255,255,255,.65); border-radius: 8px; padding: .65rem .875rem;
}
.ar__info-step-num {
  width: 22px; height: 22px; border-radius: 50%; background: #1d4ed8; color: #fff;
  font-size: .72rem; font-weight: 700; display: flex; align-items: center; justify-content: center;
  flex-shrink: 0;
}
.ar__info-step > div { display: flex; flex-direction: column; gap: .1rem; }
.ar__info-step strong { font-size: .82rem; color: #1e3a8a; }
.ar__info-step span { font-size: .75rem; color: #3b82f6; }
.ar__info-step em { font-style: normal; font-weight: 600; }

/* KPIs */
.ar__kpis {
  display: grid; grid-template-columns: repeat(4, 1fr); gap: .75rem; margin-bottom: 1.25rem;
}
@media (max-width: 640px) { .ar__kpis { grid-template-columns: repeat(2, 1fr); } }
.ar__kpi {
  background: #fff; border: 1.5px solid #e2e8f0; border-radius: 12px;
  padding: .875rem 1rem; cursor: pointer; transition: all .15s;
  display: flex; flex-direction: column; gap: .2rem;
}
.ar__kpi:hover { box-shadow: 0 2px 12px rgba(0,0,0,.07); border-color: #cbd5e1; }
.ar__kpi--active { box-shadow: 0 0 0 2px #0f172a; border-color: #0f172a; }
.ar__kpi--success { border-left: 4px solid #22c55e; }
.ar__kpi--success.ar__kpi--active { box-shadow: 0 0 0 2px #15803d; border-color: #15803d; }
.ar__kpi--warning { border-left: 4px solid #f59e0b; }
.ar__kpi--warning.ar__kpi--active { box-shadow: 0 0 0 2px #d97706; border-color: #d97706; }
.ar__kpi--danger  { border-left: 4px solid #ef4444; }
.ar__kpi--danger.ar__kpi--active  { box-shadow: 0 0 0 2px #dc2626; border-color: #dc2626; }
.ar__kpi-icon { font-size: 1.1rem; }
.ar__kpi-val  { font-size: 1.75rem; font-weight: 800; color: #0f172a; letter-spacing: -.04em; line-height: 1.1; }
.ar__kpi--success .ar__kpi-val { color: #15803d; }
.ar__kpi--warning .ar__kpi-val { color: #d97706; }
.ar__kpi--danger  .ar__kpi-val { color: #dc2626; }
.ar__kpi-label { font-size: .72rem; font-weight: 600; color: #94a3b8; text-transform: uppercase; letter-spacing: .03em; }

/* Filters */
.ar__filters {
  display: flex; align-items: flex-start; flex-wrap: wrap; gap: .875rem;
  margin-bottom: 1.25rem;
}
.ar__filter-group { display: flex; align-items: center; gap: .5rem; flex-wrap: wrap; }
.ar__filter-group-label {
  font-size: .68rem; font-weight: 700; text-transform: uppercase;
  letter-spacing: .05em; color: #94a3b8; white-space: nowrap;
}
.ar__pills { display: flex; flex-wrap: wrap; gap: .3rem; }
.ar__pill {
  background: #f1f5f9; border: 1.5px solid transparent; border-radius: 999px;
  padding: .3rem .8rem; font-size: .78rem; font-weight: 500; color: #475569;
  cursor: pointer; transition: all .12s; white-space: nowrap;
}
.ar__pill:hover { background: #e2e8f0; color: #0f172a; }
.ar__pill--active {
  background: #0f172a; color: #fff; border-color: #0f172a;
}
.ar__btn-clear {
  display: inline-flex; align-items: center; gap: .35rem;
  background: none; border: 1px solid #e2e8f0; border-radius: 999px;
  padding: .3rem .8rem; font-size: .78rem; cursor: pointer; color: #64748b;
  transition: all .12s;
}
.ar__btn-clear:hover { background: #fef2f2; color: #dc2626; border-color: #fca5a5; }

/* Table */
.ar__table-wrap { overflow-x: auto; border: 1px solid #e2e8f0; border-radius: 12px; }
.ar__table { width: 100%; border-collapse: collapse; font-size: .84rem; background: #fff; }
.ar__table th {
  text-align: left; font-size: .65rem; font-weight: 700;
  text-transform: uppercase; letter-spacing: .05em; color: #94a3b8;
  background: #f8fafc; padding: .6rem .875rem;
  border-bottom: 1px solid #e2e8f0; white-space: nowrap;
}
.ar__table td { padding: .55rem .875rem; border-bottom: 1px solid #f1f5f9; color: #0f172a; }
.ar__table tbody tr:last-child td { border-bottom: none; }
.ar__table tbody tr:hover { background: #f8fafc; }
.ar__tr--error { background: #fef2f2 !important; }
.ar__td-mono   { font-family: monospace; font-size: .78rem; }
.ar__td-muted  { color: #94a3b8; }
.ar__td-tipo   { font-weight: 500; }
.ar__td-center { text-align: center; }
.ar__td-fecha  { color: #64748b; font-size: .78rem; white-space: nowrap; }

/* Badges */
.ar__badge {
  display: inline-block; padding: .2rem .55rem;
  border-radius: 999px; font-size: .68rem; font-weight: 700;
}
.ar__badge--warning { background: #fef3c7; color: #92400e; }
.ar__badge--info    { background: #dbeafe; color: #1e40af; }
.ar__badge--success { background: #dcfce7; color: #166534; }
.ar__badge--danger  { background: #fee2e2; color: #991b1b; }
.ar__badge--muted   { background: #f1f5f9; color: #64748b; }

/* Action btn */
.ar__btn-detail {
  background: none; border: 1px solid #e2e8f0; border-radius: 6px;
  padding: .2rem .45rem; cursor: pointer; color: #64748b; font-size: .85rem;
  transition: all .12s;
}
.ar__btn-detail:hover { background: #f0fdf4; border-color: #bbf7d0; color: #15803d; }

/* Pagination */
.ar__pagination {
  display: flex; align-items: center; justify-content: center;
  gap: .75rem; margin-top: 1.25rem;
}
.ar__pg-btn {
  background: #fff; border: 1px solid #e2e8f0;
  border-radius: 8px; padding: .4rem .7rem; cursor: pointer; transition: all .12s;
}
.ar__pg-btn:hover:not(:disabled) { background: #f8fafc; border-color: #cbd5e1; }
.ar__pg-btn:disabled { opacity: .35; cursor: default; }
.ar__pg-info { font-size: .82rem; color: #64748b; }

/* Loading */
.ar__loading {
  display: flex; align-items: center; gap: .75rem;
  padding: 3.5rem 1rem; color: #94a3b8; font-size: .875rem;
}
.ar__spinner {
  width: 22px; height: 22px; border-radius: 50%;
  border: 3px solid #e2e8f0; border-top-color: #1b5e20;
  animation: ar-spin .8s linear infinite; flex-shrink: 0;
}
@keyframes ar-spin { to { transform: rotate(360deg); } }

/* Empty state */
.ar__empty {
  display: flex; flex-direction: column; align-items: center; text-align: center;
  padding: 4rem 1rem; gap: 1rem;
}
.ar__empty-icon {
  width: 72px; height: 72px; background: #eff6ff; border-radius: 20px;
  display: flex; align-items: center; justify-content: center;
  font-size: 2rem; color: #3b82f6;
}
.ar__empty-title { font-size: 1.1rem; font-weight: 700; color: #0f172a; margin: 0; }
.ar__empty-desc { font-size: .875rem; color: #64748b; max-width: 400px; line-height: 1.6; margin: 0; }
.ar__empty-btn {
  display: inline-flex; align-items: center; gap: .4rem;
  background: #fff; border: 1px solid #e2e8f0; border-radius: 8px;
  padding: .55rem 1.1rem; font-size: .85rem; cursor: pointer; color: #475569;
  transition: all .12s;
}
.ar__empty-btn:hover { background: #fef2f2; color: #dc2626; border-color: #fca5a5; }

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
.ar__modal-head-left { display: flex; align-items: center; gap: .65rem; }
.ar__modal-title { font-weight: 700; font-size: .95rem; color: #0f172a; }
.ar__modal-close {
  background: none; border: none; cursor: pointer; font-size: 1rem;
  color: #94a3b8; padding: .25rem; border-radius: 6px; transition: all .12s;
}
.ar__modal-close:hover { background: #f1f5f9; color: #0f172a; }
.ar__modal-body {
  overflow-y: auto; padding: 1.25rem; display: flex; flex-direction: column; gap: 1rem;
}
.ar__modal-grid {
  display: grid; grid-template-columns: 1fr 1fr; gap: .5rem .875rem;
}
.ar__modal-field { display: flex; flex-direction: column; gap: .2rem; }
.ar__modal-field label {
  font-size: .65rem; font-weight: 700; text-transform: uppercase;
  letter-spacing: .05em; color: #94a3b8;
}
.ar__modal-field span { font-size: .875rem; color: #0f172a; }
.ar__modal-mono { font-family: monospace; font-size: .82rem !important; }
.ar__modal-error {
  background: #fef2f2; border: 1px solid #fca5a5; border-radius: 8px; padding: .75rem 1rem;
}
.ar__modal-error-label {
  font-size: .78rem; font-weight: 700; color: #991b1b; margin-bottom: .35rem;
  display: flex; align-items: center; gap: .35rem;
}
.ar__modal-error-msg { font-size: .82rem; color: #7f1d1d; line-height: 1.5; }
.ar__modal-json-label {
  font-size: .65rem; font-weight: 700; text-transform: uppercase;
  letter-spacing: .05em; color: #94a3b8; margin-bottom: .35rem;
}
.ar__modal-pre {
  background: #0f172a; color: #e2e8f0; border-radius: 8px;
  padding: .75rem 1rem; font-size: .72rem; overflow-x: auto;
  white-space: pre; max-height: 200px; margin: 0;
}

/* Transitions */
.ar-info-enter-active, .ar-info-leave-active { transition: all .2s ease; }
.ar-info-enter-from, .ar-info-leave-to { opacity: 0; transform: translateY(-6px); }
.ar-modal-enter-active, .ar-modal-leave-active { transition: all .2s; }
.ar-modal-enter-from, .ar-modal-leave-to { opacity: 0; }
.ar-modal-enter-from .ar__modal, .ar-modal-leave-to .ar__modal { transform: scale(.96); }
</style>
