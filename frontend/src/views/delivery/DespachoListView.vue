<script setup>
import { ref, computed, onMounted } from 'vue'
import {
  PackageCheck, Truck, CheckCircle2, XCircle, User, MapPin,
  Phone, FileText, RefreshCw, ChevronDown, ChevronUp, AlertCircle
} from 'lucide-vue-next'
import { listDespachos, listDeliveryUsers, reasignarDelivery, reprogramarPaquete } from '../../lib/api.js'
import { useToast } from '../../composables/useToast.js'

const toast = useToast()

const despachos      = ref([])
const deliveryUsers  = ref([])
const loading        = ref(true)
const saving         = ref(false)
const reprogramando  = ref(false)

const filtroEstado   = ref('')
const filtroDelivery = ref('')
const filtroDesde    = ref('')
const filtroHasta    = ref('')
const filtroBusca    = ref('')

const expandedId     = ref(null)
const reasignandoId  = ref(null)
const nuevoDelivery  = ref('')

const kpis = computed(() => ({
  pendientes: despachos.value.filter(d => d.estado_envio === 'pendiente').length,
  en_viaje:   despachos.value.filter(d => d.estado_envio === 'en_viaje').length,
  entregados: despachos.value.filter(d => d.estado_envio === 'entregado').length,
  fallidos:   despachos.value.filter(d => d.estado_envio === 'fallido').length,
}))

const despachosFiltered = computed(() => {
  if (!filtroBusca.value.trim()) return despachos.value
  const q = filtroBusca.value.toLowerCase()
  return despachos.value.filter(d =>
    d.codigo_paquete?.toLowerCase().includes(q) ||
    d.paciente_nombre?.toLowerCase().includes(q) ||
    d.direccion_envio?.toLowerCase().includes(q) ||
    d.delivery_nombre?.toLowerCase().includes(q)
  )
})

const ESTADO_META = {
  pendiente: { label: 'Pendiente', bg: '#dbeafe', color: '#1d4ed8' },
  en_viaje:  { label: 'En camino', bg: '#fef3c7', color: '#d97706' },
  entregado: { label: 'Entregado', bg: '#dcfce7', color: '#15803d' },
  fallido:   { label: 'Fallido',   bg: '#fee2e2', color: '#dc2626' },
}

function estadoBadgeStyle(estado) {
  const m = ESTADO_META[estado] || {}
  return { background: m.bg || '#f1f5f9', color: m.color || '#475569' }
}

const fmtFecha = (d) => d
  ? new Date(d + 'T00:00:00').toLocaleDateString('es-AR', { day: 'numeric', month: 'short', year: 'numeric' })
  : '—'

async function load() {
  loading.value = true
  try {
    const params = {}
    if (filtroEstado.value)   params.estado_envio = filtroEstado.value
    if (filtroDelivery.value) params.delivery_id  = filtroDelivery.value
    if (filtroDesde.value)    params.desde        = filtroDesde.value
    if (filtroHasta.value)    params.hasta        = filtroHasta.value
    const { data } = await listDespachos(params)
    despachos.value = data.dispensaciones || []
  } catch { toast.error('Error al cargar despachos') }
  finally { loading.value = false }
}

async function loadDeliveryUsers() {
  try {
    const { data } = await listDeliveryUsers()
    deliveryUsers.value = data.users || []
  } catch {}
}

function toggleExpand(id) {
  expandedId.value = expandedId.value === id ? null : id
}

function iniciarReasignacion(d) {
  reasignandoId.value = d.id
  nuevoDelivery.value = d.delivery_id ? String(d.delivery_id) : ''
  expandedId.value    = d.id
}

function cancelarReasignacion() {
  reasignandoId.value = null
  nuevoDelivery.value = ''
}

async function confirmarReasignacion(id) {
  saving.value = true
  try {
    await reasignarDelivery(id, nuevoDelivery.value || null)
    reasignandoId.value = null
    await load()
    toast.success('Delivery reasignado')
  } catch { toast.error('Error al reasignar') }
  finally { saving.value = false }
}

function deliveryNombre(d) {
  if (d.delivery_nombre) return d.delivery_nombre
  const u = deliveryUsers.value.find(u => u.id === d.delivery_id)
  return u ? (u.first_name || u.email) : '—'
}

async function reprogramar(id) {
  reprogramando.value = true
  try {
    await reprogramarPaquete(id)
    expandedId.value = null
    await load()
    toast.success('Paquete reprogramado — volvió a Pendiente')
  } catch { toast.error('Error al reprogramar') }
  finally { reprogramando.value = false }
}

onMounted(() => Promise.all([load(), loadDeliveryUsers()]))
</script>

<template>
  <div class="dsp">

    <!-- Header -->
    <div class="dsp__header">
      <div class="dsp__header-left">
        <PackageCheck :size="22" :stroke-width="1.75" />
        <div>
          <div class="dsp__title">Despachos con envío</div>
          <div class="dsp__sub">{{ despachos.length }} despacho{{ despachos.length !== 1 ? 's' : '' }} totales</div>
        </div>
      </div>
      <button class="dsp__btn-refresh" :disabled="loading" @click="load">
        <RefreshCw :size="15" :stroke-width="2" :class="{ 'dsp__spin': loading }" />
        Actualizar
      </button>
    </div>

    <!-- KPI strip -->
    <div class="dsp__kpis">
      <div class="dsp__kpi dsp__kpi--blue" @click="filtroEstado = filtroEstado === 'pendiente' ? '' : 'pendiente'; load()">
        <span class="dsp__kpi-n">{{ kpis.pendientes }}</span>
        <span class="dsp__kpi-l">Pendientes</span>
      </div>
      <div class="dsp__kpi dsp__kpi--amber" @click="filtroEstado = filtroEstado === 'en_viaje' ? '' : 'en_viaje'; load()">
        <Truck :size="18" :stroke-width="1.75" class="dsp__kpi-icon" />
        <span class="dsp__kpi-n">{{ kpis.en_viaje }}</span>
        <span class="dsp__kpi-l">En camino</span>
      </div>
      <div class="dsp__kpi dsp__kpi--green" @click="filtroEstado = filtroEstado === 'entregado' ? '' : 'entregado'; load()">
        <CheckCircle2 :size="18" :stroke-width="1.75" class="dsp__kpi-icon" />
        <span class="dsp__kpi-n">{{ kpis.entregados }}</span>
        <span class="dsp__kpi-l">Entregados</span>
      </div>
      <div class="dsp__kpi dsp__kpi--red" @click="filtroEstado = filtroEstado === 'fallido' ? '' : 'fallido'; load()">
        <XCircle :size="18" :stroke-width="1.75" class="dsp__kpi-icon" />
        <span class="dsp__kpi-n">{{ kpis.fallidos }}</span>
        <span class="dsp__kpi-l">Fallidos</span>
      </div>
    </div>

    <!-- Filtros -->
    <div class="dsp__filters">
      <input
        v-model="filtroBusca"
        class="dsp__search"
        type="text"
        placeholder="Buscar código, socio, dirección, repartidor…"
      />
      <select v-model="filtroEstado" class="dsp__select" @change="load">
        <option value="">Todos los estados</option>
        <option value="pendiente">Pendiente</option>
        <option value="en_viaje">En camino</option>
        <option value="entregado">Entregado</option>
        <option value="fallido">Fallido</option>
      </select>
      <select v-model="filtroDelivery" class="dsp__select" @change="load">
        <option value="">Todos los repartidores</option>
        <option v-for="u in deliveryUsers" :key="u.id" :value="String(u.id)">
          {{ u.first_name || u.email }}
        </option>
      </select>
      <input v-model="filtroDesde" class="dsp__input-date" type="date" title="Desde" @change="load" />
      <input v-model="filtroHasta" class="dsp__input-date" type="date" title="Hasta" @change="load" />
      <button
        v-if="filtroEstado || filtroDelivery || filtroDesde || filtroHasta || filtroBusca"
        class="dsp__btn-clear"
        @click="filtroEstado=''; filtroDelivery=''; filtroDesde=''; filtroHasta=''; filtroBusca=''; load()"
      >
        Limpiar
      </button>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="dsp__loading">
      <div class="dsp__ring"></div>
      Cargando despachos…
    </div>

    <!-- Empty -->
    <div v-else-if="!despachosFiltered.length" class="dsp__empty">
      <PackageCheck :size="44" :stroke-width="1.25" />
      <div class="dsp__empty-title">Sin despachos</div>
      <div class="dsp__empty-sub">No hay despachos con los filtros actuales</div>
    </div>

    <!-- Lista -->
    <div v-else class="dsp__list">
      <div
        v-for="d in despachosFiltered"
        :key="d.id"
        class="dsp__row"
        :class="`dsp__row--${d.estado_envio}`"
      >

        <!-- Fila principal (clickable) -->
        <div class="dsp__row-main" @click="toggleExpand(d.id)">

          <div class="dsp__row-left">
            <span class="dsp__code">{{ d.codigo_paquete || `#${d.id}` }}</span>
            <span class="dsp__estado-badge" :style="estadoBadgeStyle(d.estado_envio)">
              {{ ESTADO_META[d.estado_envio]?.label || d.estado_envio }}
            </span>
          </div>

          <div class="dsp__row-mid">
            <div class="dsp__row-nombre">
              <User :size="12" :stroke-width="2" />
              {{ d.paciente_nombre }}
            </div>
            <div class="dsp__row-dir">
              <MapPin :size="12" :stroke-width="2" />
              {{ d.direccion_envio || '(sin dirección)' }}
            </div>
          </div>

          <div class="dsp__row-right">
            <div class="dsp__row-delivery">
              <Truck :size="12" :stroke-width="2" />
              {{ d.delivery_nombre || deliveryNombre(d) || 'Sin asignar' }}
            </div>
            <div class="dsp__row-fecha">{{ fmtFecha(d.fecha_dispensacion) }}</div>
          </div>

          <div class="dsp__row-toggle">
            <ChevronDown v-if="expandedId !== d.id" :size="16" :stroke-width="2" />
            <ChevronUp   v-else                     :size="16" :stroke-width="2" />
          </div>

        </div>

        <!-- Panel expandido -->
        <div v-if="expandedId === d.id" class="dsp__detail">

          <div class="dsp__detail-grid">

            <div class="dsp__detail-col">
              <div class="dsp__detail-label">Socio</div>
              <div class="dsp__detail-val"><User :size="13" :stroke-width="2" /> {{ d.paciente_nombre }}</div>

              <div class="dsp__detail-label">Dirección de envío</div>
              <div class="dsp__detail-val"><MapPin :size="13" :stroke-width="2" /> {{ d.direccion_envio || '—' }}</div>

              <div v-if="d.contacto_nombre" class="dsp__detail-label">Contacto</div>
              <div v-if="d.contacto_nombre" class="dsp__detail-val">{{ d.contacto_nombre }}</div>

              <div v-if="d.contacto_telefono" class="dsp__detail-label">Teléfono</div>
              <div v-if="d.contacto_telefono" class="dsp__detail-val"><Phone :size="13" :stroke-width="2" /> {{ d.contacto_telefono }}</div>

              <div v-if="d.notas_envio" class="dsp__detail-label">Notas envío</div>
              <div v-if="d.notas_envio" class="dsp__detail-val dsp__detail-val--italic">
                <FileText :size="13" :stroke-width="2" /> {{ d.notas_envio }}
              </div>
            </div>

            <div class="dsp__detail-col">
              <div class="dsp__detail-label">Código paquete</div>
              <div class="dsp__detail-val"><code class="dsp__code-sm">{{ d.codigo_paquete || '—' }}</code></div>

              <div class="dsp__detail-label">Producto</div>
              <div class="dsp__detail-val">
                {{ d.stock?.forma_producto || '—' }}
                <span v-if="d.cantidad">· {{ d.cantidad }}{{ d.stock?.unidad || 'g' }}</span>
              </div>

              <div class="dsp__detail-label">Fecha dispensación</div>
              <div class="dsp__detail-val">{{ fmtFecha(d.fecha_dispensacion) }}</div>

              <template v-if="d.estado_envio === 'fallido' && d.motivo_fallo">
                <div class="dsp__detail-label dsp__detail-label--red">Motivo fallo</div>
                <div class="dsp__detail-val dsp__detail-val--red">
                  <AlertCircle :size="13" :stroke-width="2" /> {{ d.motivo_fallo }}
                </div>
              </template>

              <template v-if="d.estado_envio === 'entregado' && d.notas_entrega">
                <div class="dsp__detail-label dsp__detail-label--green">Notas entrega</div>
                <div class="dsp__detail-val dsp__detail-val--green">
                  <CheckCircle2 :size="13" :stroke-width="2" /> {{ d.notas_entrega }}
                </div>
              </template>
            </div>

          </div>

          <!-- Reasignación -->
          <div class="dsp__reasign-bar">
            <template v-if="reasignandoId === d.id">
              <span class="dsp__reasign-label">Reasignar a:</span>
              <select v-model="nuevoDelivery" class="dsp__reasign-select">
                <option value="">Sin asignar</option>
                <option v-for="u in deliveryUsers" :key="u.id" :value="String(u.id)">
                  {{ u.first_name || u.email }}
                </option>
              </select>
              <button class="dsp__btn-confirm" :disabled="saving" @click="confirmarReasignacion(d.id)">
                <div v-if="saving" class="dsp__spinner"></div>
                Guardar
              </button>
              <button class="dsp__btn-ghost" :disabled="saving" @click="cancelarReasignacion">
                Cancelar
              </button>
            </template>
            <template v-else>
              <span class="dsp__reasign-info">
                <Truck :size="14" :stroke-width="2" />
                Repartidor: <strong>{{ d.delivery_nombre || deliveryNombre(d) || 'Sin asignar' }}</strong>
              </span>
              <button
                v-if="d.estado_envio === 'fallido'"
                class="dsp__btn-reprogramar"
                :disabled="reprogramando"
                @click.stop="reprogramar(d.id)"
              >
                <div v-if="reprogramando" class="dsp__spinner"></div>
                <RefreshCw v-else :size="13" :stroke-width="2" />
                Reprogramar
              </button>
              <button
                v-if="d.estado_envio !== 'entregado'"
                class="dsp__btn-outline"
                @click.stop="iniciarReasignacion(d)"
              >
                Reasignar
              </button>
            </template>
          </div>

        </div>
      </div>
    </div>

  </div>
</template>

<style scoped>
.dsp {
  padding: var(--sp-6);
  max-width: 1100px;
  margin: 0 auto;
}

/* Header */
.dsp__header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: var(--sp-5);
  gap: var(--sp-3);
}
.dsp__header-left {
  display: flex;
  align-items: center;
  gap: var(--sp-3);
  color: var(--c-ink-700);
}
.dsp__title {
  font-size: var(--fs-18);
  font-weight: 700;
  color: var(--c-ink-900);
  line-height: 1;
}
.dsp__sub {
  font-size: var(--fs-13);
  color: var(--c-ink-400);
  margin-top: 2px;
}
.dsp__btn-refresh {
  display: inline-flex;
  align-items: center;
  gap: var(--sp-2);
  background: var(--c-paper);
  border: 1.5px solid var(--c-ink-200);
  color: var(--c-ink-600);
  padding: .45rem .9rem;
  border-radius: var(--r-md);
  font-size: var(--fs-13);
  font-weight: 500;
  cursor: pointer;
  transition: border-color .15s;
}
.dsp__btn-refresh:hover:not(:disabled) { border-color: var(--c-ink-400); }
.dsp__btn-refresh:disabled { opacity: .5; cursor: not-allowed; }
.dsp__spin { animation: dsp-spin .7s linear infinite; }
@keyframes dsp-spin { to { transform: rotate(360deg); } }

/* KPI strip */
.dsp__kpis {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: var(--sp-3);
  margin-bottom: var(--sp-5);
}
.dsp__kpi {
  background: var(--c-paper);
  border: 1.5px solid var(--c-ink-100);
  border-radius: var(--r-lg);
  padding: var(--sp-4) var(--sp-3);
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 4px;
  cursor: pointer;
  transition: border-color .15s, box-shadow .15s;
  position: relative;
}
.dsp__kpi:hover { box-shadow: var(--sh-2); }
.dsp__kpi--blue:hover  { border-color: #93c5fd; }
.dsp__kpi--amber:hover { border-color: #fcd34d; }
.dsp__kpi--green:hover { border-color: var(--c-leaf-300); }
.dsp__kpi--red:hover   { border-color: #fca5a5; }
.dsp__kpi-icon { position: absolute; top: var(--sp-3); right: var(--sp-3); opacity: .35; }
.dsp__kpi-n {
  font-size: 1.875rem;
  font-weight: 800;
  line-height: 1;
}
.dsp__kpi--blue  .dsp__kpi-n { color: #1d4ed8; }
.dsp__kpi--amber .dsp__kpi-n { color: #d97706; }
.dsp__kpi--green .dsp__kpi-n { color: var(--c-leaf-700); }
.dsp__kpi--red   .dsp__kpi-n { color: #dc2626; }
.dsp__kpi-l {
  font-size: 11px;
  font-weight: 600;
  color: var(--c-ink-500);
  text-transform: uppercase;
  letter-spacing: .05em;
}

/* Filtros */
.dsp__filters {
  display: flex;
  flex-wrap: wrap;
  gap: var(--sp-2);
  margin-bottom: var(--sp-5);
  align-items: center;
}
.dsp__search {
  flex: 1;
  min-width: 220px;
  background: var(--c-paper);
  border: 1.5px solid var(--c-ink-200);
  border-radius: var(--r-md);
  padding: .45rem .8rem;
  font-size: var(--fs-13);
  color: var(--c-ink-900);
}
.dsp__search:focus { outline: none; border-color: var(--c-leaf-600); }
.dsp__select,
.dsp__input-date {
  background: var(--c-paper);
  border: 1.5px solid var(--c-ink-200);
  border-radius: var(--r-md);
  padding: .42rem .7rem;
  font-size: var(--fs-13);
  color: var(--c-ink-700);
  cursor: pointer;
}
.dsp__select:focus,
.dsp__input-date:focus { outline: none; border-color: var(--c-leaf-600); }
.dsp__btn-clear {
  background: none;
  border: 1.5px solid var(--c-ink-200);
  border-radius: var(--r-md);
  padding: .42rem .75rem;
  font-size: var(--fs-13);
  color: var(--c-ink-500);
  cursor: pointer;
  white-space: nowrap;
}
.dsp__btn-clear:hover { border-color: var(--c-ink-400); color: var(--c-ink-700); }

/* Loading / Empty */
.dsp__loading {
  display: flex;
  align-items: center;
  gap: var(--sp-3);
  justify-content: center;
  padding: var(--sp-10);
  color: var(--c-ink-400);
  font-size: var(--fs-14);
}
.dsp__ring {
  width: 18px;
  height: 18px;
  border: 2px solid var(--c-ink-100);
  border-top-color: var(--c-ink-500);
  border-radius: 50%;
  animation: dsp-spin .7s linear infinite;
}
.dsp__empty {
  text-align: center;
  padding: var(--sp-12) var(--sp-4);
  color: var(--c-ink-300);
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: var(--sp-2);
}
.dsp__empty-title { font-size: var(--fs-16); font-weight: 700; color: var(--c-ink-600); }
.dsp__empty-sub { font-size: var(--fs-13); color: var(--c-ink-400); }

/* Lista */
.dsp__list {
  display: flex;
  flex-direction: column;
  gap: var(--sp-2);
}
.dsp__row {
  background: var(--c-paper);
  border: 1.5px solid var(--c-ink-100);
  border-radius: var(--r-lg);
  overflow: hidden;
  transition: border-color .15s, box-shadow .15s;
}
.dsp__row--pendiente { border-left: 3px solid #60a5fa; }
.dsp__row--en_viaje  { border-left: 3px solid #fbbf24; }
.dsp__row--entregado { border-left: 3px solid var(--c-leaf-400); }
.dsp__row--fallido   { border-left: 3px solid #f87171; }
.dsp__row:hover { box-shadow: var(--sh-2); border-color: var(--c-ink-200); }

/* Fila principal */
.dsp__row-main {
  display: flex;
  align-items: center;
  gap: var(--sp-3);
  padding: var(--sp-4) var(--sp-4);
  cursor: pointer;
  user-select: none;
}
.dsp__row-left {
  display: flex;
  align-items: center;
  gap: var(--sp-2);
  flex-shrink: 0;
  min-width: 200px;
}
.dsp__code {
  font-family: monospace;
  font-size: var(--fs-13);
  font-weight: 700;
  color: var(--c-ink-800);
  background: var(--c-ink-50, #f1f5f9);
  padding: .2em .55em;
  border-radius: 5px;
  white-space: nowrap;
}
.dsp__estado-badge {
  font-size: 11px;
  font-weight: 700;
  padding: .2em .6em;
  border-radius: 5px;
  white-space: nowrap;
}
.dsp__row-mid {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
  gap: 3px;
}
.dsp__row-nombre,
.dsp__row-dir {
  display: flex;
  align-items: center;
  gap: var(--sp-1);
  font-size: var(--fs-13);
  color: var(--c-ink-700);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.dsp__row-nombre { font-weight: 600; }
.dsp__row-dir { color: var(--c-ink-500); }
.dsp__row-right {
  display: flex;
  flex-direction: column;
  align-items: flex-end;
  gap: 3px;
  flex-shrink: 0;
  min-width: 160px;
}
.dsp__row-delivery {
  display: flex;
  align-items: center;
  gap: var(--sp-1);
  font-size: var(--fs-13);
  color: var(--c-ink-600);
  font-weight: 500;
}
.dsp__row-fecha {
  font-size: 12px;
  color: var(--c-ink-400);
}
.dsp__row-toggle {
  color: var(--c-ink-300);
  flex-shrink: 0;
}

/* Panel detalle */
.dsp__detail {
  border-top: 1px solid var(--c-ink-100);
  padding: var(--sp-4) var(--sp-5) var(--sp-3);
  background: var(--c-ink-50, #f8fafc);
}
.dsp__detail-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: var(--sp-4) var(--sp-6);
  margin-bottom: var(--sp-4);
}
.dsp__detail-col {
  display: flex;
  flex-direction: column;
  gap: 4px;
}
.dsp__detail-label {
  font-size: 10px;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: .06em;
  color: var(--c-ink-400);
  margin-top: var(--sp-2);
}
.dsp__detail-label--red   { color: #dc2626; }
.dsp__detail-label--green { color: var(--c-leaf-700); }
.dsp__detail-val {
  display: flex;
  align-items: flex-start;
  gap: var(--sp-1);
  font-size: var(--fs-13);
  color: var(--c-ink-800);
  line-height: 1.4;
}
.dsp__detail-val--italic { font-style: italic; color: var(--c-ink-500); }
.dsp__detail-val--red    { color: #dc2626; }
.dsp__detail-val--green  { color: var(--c-leaf-700); }
.dsp__code-sm {
  font-family: monospace;
  font-size: var(--fs-13);
  background: var(--c-paper);
  border: 1px solid var(--c-ink-200);
  padding: .1em .45em;
  border-radius: 4px;
  color: var(--c-ink-800);
}

/* Reasignación */
.dsp__reasign-bar {
  display: flex;
  align-items: center;
  gap: var(--sp-3);
  padding-top: var(--sp-3);
  border-top: 1px dashed var(--c-ink-200);
  flex-wrap: wrap;
}
.dsp__reasign-label {
  font-size: var(--fs-13);
  font-weight: 600;
  color: var(--c-ink-700);
  white-space: nowrap;
}
.dsp__reasign-info {
  display: flex;
  align-items: center;
  gap: var(--sp-1);
  font-size: var(--fs-13);
  color: var(--c-ink-600);
  flex: 1;
}
.dsp__reasign-select {
  background: var(--c-paper);
  border: 1.5px solid var(--c-ink-200);
  border-radius: var(--r-md);
  padding: .4rem .7rem;
  font-size: var(--fs-13);
  color: var(--c-ink-800);
  flex: 1;
  min-width: 160px;
}
.dsp__reasign-select:focus { outline: none; border-color: var(--c-leaf-600); }

/* Botones */
.dsp__btn-confirm {
  display: inline-flex;
  align-items: center;
  gap: var(--sp-2);
  background: var(--c-leaf-700);
  color: #fff;
  border: none;
  padding: .42rem .9rem;
  border-radius: var(--r-md);
  font-size: var(--fs-13);
  font-weight: 600;
  cursor: pointer;
  white-space: nowrap;
}
.dsp__btn-confirm:hover:not(:disabled) { background: var(--c-leaf-800); }
.dsp__btn-confirm:disabled { opacity: .5; cursor: not-allowed; }
.dsp__btn-ghost {
  background: var(--c-paper);
  color: var(--c-ink-500);
  border: 1.5px solid var(--c-ink-200);
  padding: .42rem .8rem;
  border-radius: var(--r-md);
  font-size: var(--fs-13);
  font-weight: 500;
  cursor: pointer;
}
.dsp__btn-ghost:hover { border-color: var(--c-ink-400); }
.dsp__btn-outline {
  background: none;
  color: var(--c-leaf-700);
  border: 1.5px solid var(--c-leaf-300);
  padding: .38rem .8rem;
  border-radius: var(--r-md);
  font-size: var(--fs-13);
  font-weight: 600;
  cursor: pointer;
  white-space: nowrap;
  transition: background .15s, border-color .15s;
}
.dsp__btn-outline:hover { background: var(--c-leaf-50); border-color: var(--c-leaf-600); }
.dsp__btn-reprogramar {
  display: inline-flex;
  align-items: center;
  gap: var(--sp-2);
  background: #fff7ed;
  color: #c2410c;
  border: 1.5px solid #fed7aa;
  padding: .38rem .8rem;
  border-radius: var(--r-md);
  font-size: var(--fs-13);
  font-weight: 600;
  cursor: pointer;
  white-space: nowrap;
  transition: background .15s, border-color .15s;
}
.dsp__btn-reprogramar:hover:not(:disabled) { background: #ffedd5; border-color: #fb923c; }
.dsp__btn-reprogramar:disabled { opacity: .5; cursor: not-allowed; }

.dsp__spinner {
  width: 12px;
  height: 12px;
  border: 2px solid rgba(255,255,255,.3);
  border-top-color: #fff;
  border-radius: 50%;
  animation: dsp-spin .6s linear infinite;
}

@media (max-width: 768px) {
  .dsp { padding: var(--sp-4); }
  .dsp__kpis { grid-template-columns: repeat(2, 1fr); }
  .dsp__row-main { flex-wrap: wrap; }
  .dsp__row-left { min-width: unset; }
  .dsp__row-right { align-items: flex-start; }
  .dsp__detail-grid { grid-template-columns: 1fr; }
}
</style>
