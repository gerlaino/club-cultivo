<template>
  <div class="mnl">

    <div v-if="loading" class="mnl__loading">
      <DsSpinner />
    </div>

    <template v-else-if="lote">

      <!-- Back -->
      <RouterLink to="/mnc/pendientes" class="mnl__back">
        <ChevronLeft :size="15" :stroke-width="2" /> Cosechas pendientes
      </RouterLink>

      <!-- Header -->
      <div class="mnl__header">
        <div>
          <p class="mnl__eyebrow"><Scissors :size="13" :stroke-width="2" /> Manicura</p>
          <h1 class="mnl__title">{{ lote.codigo }}</h1>
          <p class="mnl__sub">{{ lote.genetica?.nombre }}<span v-if="lote.sala"> · {{ lote.sala.nombre }}</span></p>
        </div>
        <div class="mnl__header-right">
          <span class="mnl__estado-badge" :class="estadoBadgeClass">{{ estadoLabel }}</span>
          <button class="mnl__btn-icon" @click="cargar" title="Actualizar">
            <RefreshCw :size="14" :stroke-width="2" />
          </button>
          <button v-if="puedeDevolver" class="mnl__btn-ghost" @click="abrirDevolver" title="Devolver a cosecha">
            <Undo2 :size="14" :stroke-width="2" /> Devolver a cosecha
          </button>
          <button v-if="puedeRegistrar" class="mnl__btn-ghost" @click="reevaluar" :disabled="reevaluando"
                  title="Re-evaluar si el lote ya se puede finalizar (pasar a curado)">
            <RotateCw :size="14" :stroke-width="2" /> Re-evaluar
          </button>
          <button v-if="puedeRegistrar" class="mnl__btn-primary" @click="abrirModal"
                  :disabled="!plantasSinPesar.length"
                  :title="!plantasSinPesar.length ? 'Todas las plantas del lote ya fueron registradas' : ''">
            <Scale :size="14" :stroke-width="2" /> Registrar por lote
          </button>
        </div>
      </div>

      <!-- Lote finalizado: pasó a curado, ya no hay nada que manicurar -->
      <div v-if="loteFinalizado" class="mnl__done">
        <CheckCircle :size="18" :stroke-width="2" />
        <div>
          <strong>Lote finalizado — pasó a {{ lote.estado === 'finalizado' ? 'finalizado' : 'curado' }}.</strong>
          <template v-if="stocksResultantes.length"> El producto quedó en curado: <b>{{ stocksResultantes.join(', ') }}</b>.</template>
          <template v-else> El producto quedó en el stock de flor seca.</template>
        </div>
      </div>

      <!-- KPIs — mismo patrón que SalaDetailView -->
      <div class="mnl__kpis">
        <div class="mnl__kpi">
          <div class="mnl__kpi-ico">✂️</div>
          <div class="mnl__kpi-body">
            <div class="mnl__kpi-val" :style="pesadasKpi === plantasActivas.length && plantasActivas.length > 0 ? 'color:#16a34a' : ''">
              {{ pesadasKpi }}<span class="mnl__kpi-den">/{{ plantasActivas.length }}</span>
            </div>
            <div class="mnl__kpi-lbl">Pesadas</div>
            <div class="mnl__kpi-progress" v-if="plantasActivas.length > 0">
              <div class="mnl__kpi-progress-fill" :style="{ width: kpiPorc + '%', background: kpiPorc === 100 ? '#16a34a' : '#5C7A4A' }"></div>
            </div>
          </div>
        </div>
        <div class="mnl__kpi">
          <div class="mnl__kpi-ico">⚖️</div>
          <div class="mnl__kpi-body">
            <div class="mnl__kpi-val">{{ totalGramosKpi }}<span class="mnl__kpi-den">g</span></div>
            <div class="mnl__kpi-lbl">Total registrado</div>
          </div>
        </div>
        <div class="mnl__kpi">
          <div class="mnl__kpi-ico">🌿</div>
          <div class="mnl__kpi-body">
            <div class="mnl__kpi-val" :style="sinPesar > 0 ? 'color:#d97706' : ''">{{ sinPesar }}</div>
            <div class="mnl__kpi-lbl">Sin pesar</div>
          </div>
        </div>
      </div>

      <!-- Plant table -->
      <div class="mnl__section">
        <div class="mnl__section-head">
          <h2 class="mnl__section-title"><Leaf :size="12" :stroke-width="2" /> Plantas del lote</h2>
        </div>

        <div class="mnl__table-wrap">
          <table class="mnl__table">
            <thead>
              <tr>
                <th class="mnl__th mnl__th--num">#</th>
                <th class="mnl__th">Nombre</th>
                <th class="mnl__th mnl__th--qr">QR</th>
                <th v-if="hasAnyHumedo" class="mnl__th mnl__th--peso">Peso bruto al corte (g)</th>
                <th class="mnl__th mnl__th--peso">Peso seco (g)</th>
                <th class="mnl__th mnl__th--estado">Estado</th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="(planta, i) in plantas"
                :key="planta.id"
                class="mnl__tr"
                :class="{ 'mnl__tr--clickable': ['en_manicura'].includes(lote.estado) }"
                @click="['en_manicura'].includes(lote.estado) ? irAPlanta(planta) : null"
              >
                <td class="mnl__td mnl__td--num">{{ i + 1 }}</td>
                <td class="mnl__td mnl__td--nombre">{{ planta.nombre || `Planta #${planta.id}` }}</td>
                <td class="mnl__td mnl__td--qr">{{ planta.codigo_qr }}</td>
                <td v-if="hasAnyHumedo" class="mnl__td mnl__td--peso">
                  <span :class="parseFloat(planta.peso_humedo) > 0 ? 'mnl__peso--humedo' : 'mnl__peso--none'">
                    {{ parseFloat(planta.peso_humedo) > 0 ? parseFloat(planta.peso_humedo).toFixed(1) : '—' }}
                  </span>
                </td>
                <td class="mnl__td mnl__td--peso">
                  <span :class="parseFloat(planta.peso_seco) > 0 ? 'mnl__peso--ok' : 'mnl__peso--none'">
                    {{ parseFloat(planta.peso_seco) > 0 ? parseFloat(planta.peso_seco).toFixed(1) : '—' }}
                    <span v-if="planta.peso_es_promedio" class="mnl__prom">(prom)</span>
                  </span>
                </td>
                <td class="mnl__td mnl__td--estado">
                  <span class="mnl__chip" :class="plantaChip(planta).cls">{{ plantaChip(planta).label }}</span>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <!-- Pesajes del lote (jornadas) -->
      <div v-if="['en_manicura'].includes(lote.estado)" class="mnl__section">
        <div class="mnl__section-head">
          <h2 class="mnl__section-title"><Scale :size="12" :stroke-width="2" /> Pesajes</h2>
        </div>

        <!-- Jornada en curso (borrador) -->
        <div v-if="pesajeBorrador" class="mnl__jornada">
          <div class="mnl__jornada-info">
            <span class="mnl__jornada-lbl">Jornada en curso</span>
            <span class="mnl__jornada-kpi">{{ pesajeBorrador.plantas_registradas || 0 }} plantas · {{ (pesajeBorrador.peso_calculado_g || 0).toFixed(1) }}g</span>
          </div>
          <div class="mnl__jornada-acts">
            <button class="mnl__pj-del" :disabled="borrando === pesajeBorrador.id" title="Descartar jornada" @click="borrarPesaje(pesajeBorrador)">
              <Trash2 :size="14" />
            </button>
            <button class="mnl__btn-submit" :disabled="enviando || (pesajeBorrador.plantas_registradas || 0) === 0" @click="cerrarYEnviar">
              <Send :size="14" :stroke-width="2" /> Cerrar y enviar
            </button>
          </div>
        </div>
        <p v-else class="mnl__pj-hint">
          <template v-if="plantasSinPesar.length">
            <strong class="mnl__pj-faltan">Faltan {{ plantasSinPesar.length }} de {{ plantasActivas.length }} plantas.</strong>
            Escaneá el QR de cada una, o usá "Registrar por lote" arriba.
          </template>
          <template v-else>✅ Todas las plantas del lote están pesadas.</template>
        </p>

        <!-- Historial de pesajes -->
        <div v-if="pesajesHistorial.length" class="mnl__hist">
          <div v-for="p in pesajesHistorial" :key="p.id" class="mnl__hist-row">
            <span class="mnl__hist-date">{{ fmtDate(p.fecha_pesaje) }}</span>
            <span class="mnl__hist-info">{{ p.plantas_count || p.plantas_registradas || 0 }} plantas · {{ (p.peso_total_g || p.peso_calculado_g || 0).toFixed(1) }}g</span>
            <span class="mnl__badge" :class="badgeClass(p.estado)">{{ pesajeEstadoLabel(p.estado) }}</span>
            <button v-if="p.estado === 'enviado'" class="mnl__hist-act" :disabled="reabriendo === p.id" title="Reabrir para corregir" @click="reabrirPesaje(p)">
              <Undo2 :size="13" />
            </button>
          </div>
        </div>
      </div>

    </template>

    <!-- Modal batch pesaje -->
    <Teleport to="body">
      <Transition name="mnl-fade">
        <div v-if="modalOpen" class="mnl-overlay" @click.self="cerrarModal">
          <div class="mnl-modal" :class="{ 'mnl-modal--wide': esAdmin }">
            <div class="mnl-modal__hd">
              <div class="mnl-modal__ico"><Scale :size="18" :stroke-width="1.75" /></div>
              <div>
                <h2 class="mnl-modal__title">{{ esAdmin ? 'Pesar y confirmar manicura' : 'Registrar manicura del lote' }}</h2>
                <p class="mnl-modal__sub">{{ lote?.codigo }}<span v-if="lote?.genetica"> · {{ lote.genetica.nombre }}</span></p>
              </div>
              <button class="mnl-modal__close" @click="cerrarModal"><X :size="16" /></button>
            </div>

            <!-- ADMIN: pesa + confirma + genera stock en un paso -->
            <form v-if="esAdmin" class="mnl-modal__body" @submit.prevent="submitDirecto">
              <div v-if="plantasSinPesar.length" class="mnl-field">
                <label class="mnl-label">Peso individual <span class="mnl-opt">opcional · {{ plantasSinPesar.length }} sin pesar</span></label>
                <div class="mnl-plist">
                  <div v-for="p in plantasSinPesar" :key="p.id" class="mnl-prow">
                    <span class="mnl-prow__code">{{ p.codigo_qr || `#${p.id}` }}</span>
                    <div class="mnl-input-row mnl-prow__input">
                      <input v-model.number="adminForm.pesos[p.id]" type="number" step="0.1" min="0" class="mnl-input" placeholder="—" />
                      <span class="mnl-suffix">g</span>
                    </div>
                  </div>
                </div>
              </div>

              <div v-if="restoCount > 0" class="mnl-field">
                <label class="mnl-label">Peso conjunto del resto <span class="mnl-opt">{{ restoCount }} plantas sin peso individual</span></label>
                <div class="mnl-input-row">
                  <input v-model.number="adminForm.restoPeso" type="number" step="0.1" min="0" class="mnl-input" placeholder="0.0" />
                  <span class="mnl-suffix">g</span>
                </div>
              </div>

              <div class="mnl-field">
                <label class="mnl-label">Contenedor <span class="mnl-opt">solo flor seca</span></label>
                <div v-if="loadingDirecto" class="mnl-hint">Cargando contenedores…</div>
                <div v-else class="mnl-cont-list">
                  <button type="button" class="mnl-cont" :class="{ 'mnl-cont--sel': adminForm.stock_id === null }" @click="adminForm.stock_id = null">
                    <span class="mnl-cont__radio"><span v-if="adminForm.stock_id === null" class="mnl-cont__dot" /></span>
                    <Plus :size="15" :stroke-width="2" />
                    <span class="mnl-cont__txt">Crear nuevo contenedor</span>
                  </button>
                  <button v-for="s in contenedores" :key="s.id" type="button" class="mnl-cont" :class="{ 'mnl-cont--sel': adminForm.stock_id === s.id }" @click="adminForm.stock_id = s.id">
                    <span class="mnl-cont__radio"><span v-if="adminForm.stock_id === s.id" class="mnl-cont__dot" /></span>
                    <Package :size="15" :stroke-width="2" />
                    <span class="mnl-cont__txt">{{ s.numero_lote_producto || `Contenedor #${s.id}` }} · {{ (s.cantidad || 0).toFixed(0) }}g · {{ s.sede?.nombre || 'Sin asignar' }}</span>
                  </button>
                </div>
              </div>

              <div class="mnl-field">
                <label class="mnl-label">Sede destino <span class="mnl-opt">opcional</span></label>
                <select v-model="adminForm.sede_id" class="mnl-input mnl-select">
                  <option :value="null">— Sin asignar (queda pendiente) —</option>
                  <option v-for="se in sedes" :key="se.id" :value="se.id">{{ se.nombre }}</option>
                </select>
              </div>

              <div v-if="modalError" class="mnl-error">{{ modalError }}</div>

              <div class="mnl-actions">
                <button type="button" class="mnl-btn-cancel" @click="cerrarModal">Cancelar</button>
                <button type="submit" class="mnl-btn-ok" :disabled="savingBatch || !hayPesoDirecto">
                  <DsSpinner v-if="savingBatch" :size="14" />
                  <CheckCircle v-else :size="13" :stroke-width="2" />
                  Registrar y generar stock
                </button>
              </div>
            </form>

            <!-- MANICURA: carga conjunta → a aprobación -->
            <form v-else class="mnl-modal__body" @submit.prevent="submitBatch">
              <div class="mnl-field">
                <label class="mnl-label">Plantas manicuradas <span class="mnl-req">*</span></label>
                <div v-if="!plantasSinPesar.length" class="mnl-hint">No quedan plantas pendientes de pesar.</div>
                <template v-else>
                  <div class="mnl-sel-head">
                    <label class="mnl-check mnl-check--all">
                      <input type="checkbox" :checked="todasBatch" @change="toggleBatchTodas" /> Seleccionar todas
                    </label>
                    <span class="mnl-sel-count">{{ batchSelIds.length }} / {{ plantasSinPesar.length }}</span>
                  </div>
                  <div class="mnl-sel-list">
                    <label v-for="p in plantasSinPesar" :key="p.id" class="mnl-check">
                      <input type="checkbox" :value="p.id" v-model="batchSelIds" />
                      <span class="mnl-check-nombre">{{ p.nombre || `Planta #${p.id}` }}</span>
                    </label>
                  </div>
                </template>
              </div>

              <div class="mnl-field">
                <label class="mnl-label">Peso neto post-manicura <span class="mnl-req">*</span></label>
                <div class="mnl-input-row">
                  <input v-model.number="batchForm.peso_seco_g" type="number" step="0.1" min="0.1"
                    class="mnl-input" placeholder="0.0" required />
                  <span class="mnl-suffix">g</span>
                </div>
              </div>

              <div class="mnl-field">
                <label class="mnl-label">Notas <span class="mnl-opt">opcional</span></label>
                <textarea v-model="batchForm.notas" class="mnl-textarea" rows="2" placeholder="Observaciones…"></textarea>
              </div>

              <div v-if="modalError" class="mnl-error">{{ modalError }}</div>

              <div class="mnl-actions">
                <button type="button" class="mnl-btn-cancel" @click="cerrarModal">Cancelar</button>
                <button type="submit" class="mnl-btn-ok" :disabled="savingBatch || !batchSelIds.length || !batchForm.peso_seco_g">
                  <DsSpinner v-if="savingBatch" :size="14" />
                  <Send v-else :size="13" />
                  Enviar a aprobación
                </button>
              </div>
            </form>
          </div>
        </div>
      </Transition>
    </Teleport>

    <!-- Modal devolver a cosecha -->
    <Teleport to="body">
      <Transition name="mnl-fade">
        <div v-if="devolverOpen" class="mnl-overlay" @click.self="devolverOpen = false">
          <div class="mnl-modal">
            <div class="mnl-modal__hd">
              <div class="mnl-modal__ico mnl-modal__ico--warn"><Undo2 :size="18" :stroke-width="1.75" /></div>
              <div>
                <h2 class="mnl-modal__title">Devolver a cosecha</h2>
                <p class="mnl-modal__sub">{{ lote?.codigo }}<span v-if="lote?.genetica"> · {{ lote.genetica.nombre }}</span></p>
              </div>
              <button class="mnl-modal__close" @click="devolverOpen = false"><X :size="16" /></button>
            </div>
            <form class="mnl-modal__body" @submit.prevent="confirmarDevolver">
              <p class="mnl-devolver-hint">
                El lote vuelve a <strong>cosecha</strong> y queda sin manicura asignada. El admin recibe un aviso con el motivo y lo reasigna cuando esté pronto.
              </p>
              <div class="mnl-field">
                <label class="mnl-label">¿Por qué no se puede manicurar? <span class="mnl-req">*</span></label>
                <textarea v-model="devolverMotivo" class="mnl-textarea" rows="3"
                  placeholder="Ej: la flor sigue húmeda, necesita más días de secado" required></textarea>
              </div>
              <div v-if="devolverError" class="mnl-error">{{ devolverError }}</div>
              <div class="mnl-actions">
                <button type="button" class="mnl-btn-cancel" @click="devolverOpen = false">Cancelar</button>
                <button type="submit" class="mnl-btn-warn" :disabled="devolviendo || !devolverMotivo.trim()">
                  <DsSpinner v-if="devolviendo" :size="14" />
                  <Undo2 v-else :size="13" :stroke-width="2" />
                  Devolver a cosecha
                </button>
              </div>
            </form>
          </div>
        </div>
      </Transition>
    </Teleport>

  </div>
</template>

<script setup>
import { ref, computed, onMounted, onActivated } from 'vue'
import { RouterLink, useRoute, useRouter } from 'vue-router'
import DsSpinner from '../../design-system/components/Spinner.vue'
import { ChevronLeft, Scissors, Leaf, Scale, Send, X, RefreshCw, RotateCw, Package, Plus, CheckCircle, Undo2, Trash2 } from 'lucide-vue-next'
import {
  getLote, listPlants, createPesajeManicura, registrarDirectoManicura, listStocks, listSedes,
  listPesajesManicura, enviarPesajeManicura, deletePesajeManicura, reabrirPesajeManicura,
  devolverManicura, reevaluarManicura,
} from '../../lib/api.js'
import { useToast } from '../../composables/useToast.js'
import { useManicuraJornada } from '../../composables/useManicuraJornada.js'
import { useConfirm } from '../../composables/useConfirm.js'
import { useAuthStore } from '../../stores/auth'

const route  = useRoute()
const router = useRouter()
const toast  = useToast()
const auth   = useAuthStore()
const { confirm } = useConfirm()
const { registrarConJornada } = useManicuraJornada()

// ── Pesajes del lote (jornadas) — antes vivía en "Mis pesajes" ──
const pesajes    = ref([])
const enviando   = ref(false)
const reabriendo = ref(null)
const borrando   = ref(null)

const pesajeBorrador   = computed(() => pesajes.value.find(p => p.estado === 'borrador'))
const pesajesHistorial = computed(() => pesajes.value.filter(p => p.estado !== 'borrador'))
const pesajesConfirmadosCount = computed(() =>
  pesajes.value.filter(p => p.estado === 'confirmado')
    .reduce((s, p) => s + (p.plantas_count || p.plantas_registradas || 0), 0)
)

async function cerrarYEnviar() {
  const p = pesajeBorrador.value
  if (!p || enviando.value) return
  // Aviso si quedan plantas sin pesar (no cerrar parcial sin querer).
  const total = lote.value?.plants_count
  const cubiertas = pesajesConfirmadosCount.value + (p.plantas_registradas || 0)
  if (total && cubiertas < total) {
    const ok = await confirm({
      title: 'Cerrar pesaje incompleto',
      message: `Vas a enviar ${cubiertas} de ${total} plantas. Las ${total - cubiertas} restantes quedarán para otro pesaje. ¿Cerrar igual?`,
      confirmText: 'Cerrar y enviar',
    })
    if (!ok) return
  }
  enviando.value = true
  try {
    await enviarPesajeManicura(id, p.id)
    toast.success('Pesaje cerrado y enviado a confirmar')
    await cargar()
  } catch (e) {
    toast.error(e.response?.data?.error || 'Error al enviar el pesaje')
  } finally { enviando.value = false }
}

async function reabrirPesaje(p) {
  if (p.estado !== 'enviado') return
  reabriendo.value = p.id
  try {
    await reabrirPesajeManicura(id, p.id)
    toast.success('Pesaje reabierto — corregilo y volvé a enviar')
    await cargar()
  } catch (e) {
    toast.error(e.response?.data?.error || 'No se pudo reabrir')
  } finally { reabriendo.value = null }
}

async function borrarPesaje(p) {
  if (p.estado === 'confirmado') return
  const ok = await confirm({
    title: 'Borrar pesaje',
    message: `¿Borrar este pesaje del ${fmtDate(p.fecha_pesaje)}? Esta acción no se puede deshacer.`,
    confirmText: 'Borrar', variant: 'danger',
  })
  if (!ok) return
  borrando.value = p.id
  try {
    await deletePesajeManicura(id, p.id)
    toast.success('Pesaje borrado')
    await cargar()
  } catch (e) {
    toast.error(e.response?.data?.error || 'No se pudo borrar')
  } finally { borrando.value = null }
}

function fmtDate(d) {
  if (!d) return '—'
  return new Date(d).toLocaleDateString('es-AR', { weekday: 'short', day: 'numeric', month: 'short' })
}
function pesajeEstadoLabel(estado) {
  return { borrador: 'En progreso', enviado: 'Enviado', confirmado: 'Confirmado' }[estado] || estado
}
function badgeClass(estado) {
  return {
    'mnl__badge--borrador':   estado === 'borrador',
    'mnl__badge--enviado':    estado === 'enviado',
    'mnl__badge--confirmado': estado === 'confirmado',
  }
}

const id      = Number(route.params.id)
const loading = ref(true)
const lote    = ref(null)
const plantas = ref([])

const modalOpen   = ref(false)
const savingBatch = ref(false)
const modalError  = ref('')
const batchForm   = ref({ peso_seco_g: null, notas: '' })
// Selección de plantas para el batch (el peso se reparte como promedio entre las elegidas).
const batchSelIds = ref([])
const todasBatch  = computed(() => plantasSinPesar.value.length > 0 && batchSelIds.value.length === plantasSinPesar.value.length)
function toggleBatchTodas() {
  batchSelIds.value = todasBatch.value ? [] : plantasSinPesar.value.map(p => p.id)
}

// Flujo directo del admin: pesa (individual y/o resto) + confirma + genera stock en un paso.
const adminForm      = ref({ pesos: {}, restoPeso: null, stock_id: null, sede_id: null })
const contenedores   = ref([])
const sedes          = ref([])
const loadingDirecto = ref(false)
const esAdmin = computed(() => ['admin', 'supervisor'].includes(auth.user?.role))

// KPIs — el flujo por QR setea plant.peso_seco por planta.
// La carga manual no toca plant.peso_seco; en ese caso caemos a ultima_pesada_manicura.
const pesadasKpi = computed(() => {
  const fromPlants = plantas.value.filter(p => parseFloat(p.peso_seco) > 0).length
  if (fromPlants > 0) return fromPlants
  return lote.value?.ultima_pesada_manicura?.plantas_manicuradas || 0
})

const totalGramosKpi = computed(() => {
  const fromPlants = plantas.value.reduce((s, p) => s + (parseFloat(p.peso_seco) || 0), 0)
  if (fromPlants > 0) return parseFloat(fromPlants.toFixed(1))
  const v = lote.value?.ultima_pesada_manicura?.peso_seco_g
  return v ? parseFloat(parseFloat(v).toFixed(1)) : 0
})

const sinPesar        = computed(() => Math.max(0, plantasActivas.value.length - pesadasKpi.value))

// Cualquier usuario con rol manicura/admin/supervisor puede registrar en un lote en
// manicura (trabajo de equipo; espejo del backend). El "responsable" no bloquea al resto.
const puedeRegistrar = computed(() =>
  lote.value?.estado === 'en_manicura' &&
  ['manicura', 'admin', 'supervisor'].includes(auth.role)
)

// Red de seguridad: re-evaluar si el lote ya se puede finalizar (todo pesado o descartado).
const reevaluando = ref(false)
async function reevaluar() {
  if (reevaluando.value) return
  reevaluando.value = true
  try {
    const { data } = await reevaluarManicura(id)
    toast[data.estado === 'curado' ? 'success' : 'info'](data.mensaje)
    if (data.estado === 'curado') router.push('/mnc/pendientes')
    else await cargar()
  } catch (e) {
    toast.error(e?.response?.data?.error || 'No se pudo re-evaluar')
  } finally { reevaluando.value = false }
}

// Devolver a cosecha: solo mientras no haya un pesaje confirmado (un confirmado ya generó
// stock → no se puede volver atrás). El backend valida lo mismo; esto es solo la UI.
const hayConfirmado = computed(() => pesajes.value.some(p => p.estado === 'confirmado'))
const puedeDevolver = computed(() =>
  lote.value?.estado === 'en_manicura' && !hayConfirmado.value &&
  ['manicura', 'admin', 'supervisor'].includes(auth.role)
)

const devolverOpen   = ref(false)
const devolverMotivo = ref('')
const devolverError  = ref('')
const devolviendo    = ref(false)

function abrirDevolver() {
  devolverMotivo.value = ''
  devolverError.value  = ''
  devolverOpen.value   = true
}

async function confirmarDevolver() {
  const motivo = devolverMotivo.value.trim()
  if (!motivo || devolviendo.value) return
  devolviendo.value = true
  devolverError.value = ''
  try {
    await devolverManicura(id, motivo)
    toast.success(`Lote ${lote.value.codigo} devuelto a cosecha`)
    devolverOpen.value = false
    router.push('/mnc/pendientes')
  } catch (e) {
    devolverError.value = e.response?.data?.error || e.response?.data?.errors?.[0] || 'No se pudo devolver'
  } finally {
    devolviendo.value = false
  }
}

// Plantas "vivas" del lote (las descartadas no cuentan para pesar ni para los contadores).
const plantasActivas = computed(() => plantas.value.filter(p => p.state !== 'descartada'))
// Pendientes de pesar = ni descartadas ni ya registradas (peso_seco del flujo QR, o
// tiene_pesada del flujo manual/batch que no toca peso_seco).
const plantasSinPesar = computed(() => plantas.value.filter(p =>
  p.state !== 'descartada' && !(parseFloat(p.peso_seco) > 0) && !p.tiene_pesada
))

// Chip de estado de la planta en la tabla.
function plantaChip(p) {
  if (p.state === 'descartada') return { cls: 'mnl__chip--descartada', label: 'Descartada' }
  if (p.peso_es_promedio)       return { cls: 'mnl__chip--prom', label: 'Promedio' }
  if (parseFloat(p.peso_seco) > 0 || p.tiene_pesada) return { cls: 'mnl__chip--done', label: 'Pesada' }
  return { cls: 'mnl__chip--pending', label: 'Sin pesar' }
}
// Plantas que quedan para el "resto conjunto" = sin pesar y sin peso individual cargado.
const restoCount = computed(() =>
  plantasSinPesar.value.length -
  plantasSinPesar.value.filter(p => parseFloat(adminForm.value.pesos[p.id]) > 0).length
)
const hayPesoDirecto = computed(() =>
  plantasSinPesar.value.some(p => parseFloat(adminForm.value.pesos[p.id]) > 0) ||
  (parseFloat(adminForm.value.restoPeso) > 0 && restoCount.value > 0)
)
const kpiPorc         = computed(() => plantasActivas.value.length ? Math.min(100, Math.round(pesadasKpi.value / plantasActivas.value.length * 100)) : 0)
const hasAnyHumedo    = computed(() => plantas.value.some(p => parseFloat(p.peso_humedo) > 0))

const loteFinalizado = computed(() => lote.value && lote.value.estado !== 'en_manicura')
const stocksResultantes = computed(() =>
  [...new Set(pesajes.value.filter(p => p.estado === 'confirmado' && p.stock)
    .map(p => p.stock.numero_lote_producto).filter(Boolean))]
)
const ESTADO_LABEL = { en_manicura: 'Asignado', curado: 'Curado', finalizado: 'Finalizado' }
const estadoBadgeClass = computed(() => ({
  'mnl__estado-badge--asignado': lote.value?.estado === 'en_manicura',
  'mnl__estado-badge--done':     loteFinalizado.value,
}))
const estadoLabel = computed(() => ESTADO_LABEL[lote.value?.estado] || lote.value?.estado || '—')

async function cargar() {
  loading.value = true
  try {
    const [lr, pr, psj] = await Promise.all([getLote(id), listPlants({ lote_id: id }), listPesajesManicura(id)])
    lote.value    = lr.data
    plantas.value = pr.data || []
    pesajes.value = psj.data || []
  } catch {
    toast.error('Error al cargar el lote')
    router.push('/mnc/pendientes')
  } finally {
    loading.value = false
  }
}

function irAPlanta(p) { router.push(`/p/${p.codigo_qr}`) }

async function abrirModal() {
  modalError.value = ''
  if (esAdmin.value) {
    // El admin pesa + confirma en un paso: precargamos contenedores (flor seca del lote) y sedes.
    adminForm.value = {
      pesos: Object.fromEntries(plantasSinPesar.value.map(p => [p.id, null])),
      restoPeso: null, stock_id: null, sede_id: null,
    }
    modalOpen.value = true
    loadingDirecto.value = true
    try {
      const [cs, ss] = await Promise.all([listStocks({ lote_id: id }), listSedes()])
      contenedores.value = (cs.data || []).filter(s =>
        s.forma_producto === 'flor_seca' && ['pendiente_asignacion', 'asignado'].includes(s.estado)
      )
      sedes.value = ss.data || []
    } catch {
      contenedores.value = []; sedes.value = []
    } finally {
      loadingDirecto.value = false
    }
  } else {
    // El batch cubre las plantas restantes (las ya pesadas por QR no se vuelven a contar).
    batchForm.value = { peso_seco_g: null, notas: '' }
    batchSelIds.value = plantasSinPesar.value.map(p => p.id) // por defecto, todas las pendientes
    modalOpen.value = true
  }
}

async function submitDirecto() {
  if (!hayPesoDirecto.value || savingBatch.value) return
  savingBatch.value = true
  modalError.value  = ''
  try {
    const pesos = plantasSinPesar.value
      .filter(p => parseFloat(adminForm.value.pesos[p.id]) > 0)
      .map(p => ({ plant_id: p.id, peso_seco_g: parseFloat(adminForm.value.pesos[p.id]) }))
    const payload = {}
    if (pesos.length) payload.pesos = pesos
    if (parseFloat(adminForm.value.restoPeso) > 0 && restoCount.value > 0) {
      payload.resto = { plantas_count: restoCount.value, peso_total_g: parseFloat(adminForm.value.restoPeso) }
    }
    if (adminForm.value.stock_id) payload.stock_id = adminForm.value.stock_id
    if (adminForm.value.sede_id)  payload.sede_id  = adminForm.value.sede_id

    const { data } = await registrarDirectoManicura(id, payload)
    toast.success(data.lote_estado === 'curado'
      ? `Manicura completada — lote ${lote.value.codigo} en curado`
      : 'Pesaje registrado y stock generado')
    cerrarModal()
    await cargar()
  } catch (e) {
    modalError.value = e.response?.data?.error || e.response?.data?.errors?.[0] || 'Error al registrar'
  } finally {
    savingBatch.value = false
  }
}
function cerrarModal() { modalOpen.value = false }

// Carga manual sin QR: crea un PesajeManicura con el total declarado y lo manda a
// confirmar en un solo paso (mismo modelo que el flujo QR).
async function submitBatch() {
  if (!batchSelIds.value.length || !batchForm.value.peso_seco_g) return
  savingBatch.value = true
  modalError.value  = ''
  try {
    const res = await registrarConJornada(id, (extra) => createPesajeManicura(id, {
      plant_ids:    batchSelIds.value,
      peso_total_g: batchForm.value.peso_seco_g,
      notas:        batchForm.value.notas || undefined,
      enviar:       true,
      ...extra,
    }))
    if (!res) return // la manicura canceló → dejar el modal abierto
    toast.success(`Lote ${lote.value.codigo} — pesaje enviado a confirmar`)
    cerrarModal()
    await cargar()
  } catch (e) {
    modalError.value = e.response?.data?.errors?.[0] || e.response?.data?.error || 'Error al registrar'
  } finally {
    savingBatch.value = false
  }
}

onMounted(cargar)
onActivated(cargar)
</script>

<style scoped>
.mnl { padding: 1.5rem 1.75rem 3rem; max-width: 1000px; margin: 0 auto; }
@media (max-width: 768px) { .mnl { padding: 1rem 1rem 2rem; } }

/* Back */
.mnl__back {
  display: inline-flex; align-items: center; gap: 4px;
  font-size: .8rem; color: #64748b; text-decoration: none;
  margin-bottom: 1.25rem; transition: color .15s;
}
.mnl__back:hover { color: #1e293b; }

/* Header */
.mnl__header {
  display: flex; align-items: flex-start; justify-content: space-between;
  gap: 1rem; margin-bottom: 1.5rem; flex-wrap: wrap;
}
.mnl__eyebrow {
  display: inline-flex; align-items: center; gap: 4px;
  font-size: .72rem; font-weight: 700; text-transform: uppercase; letter-spacing: .08em;
  color: #5C7A4A; margin: 0 0 .2rem;
}
.mnl__title { font-size: 1.6rem; font-weight: 800; color: #0f172a; letter-spacing: -.03em; margin: 0 0 .2rem; line-height: 1.1; }
.mnl__sub   { font-size: .85rem; color: #64748b; margin: 0; }
.mnl__header-right { display: flex; align-items: center; gap: .5rem; flex-wrap: wrap; padding-top: .2rem; }

.mnl__estado-badge {
  font-size: .7rem; font-weight: 700; padding: .25em .7em;
  border-radius: 999px; text-transform: uppercase; letter-spacing: .05em;
}
.mnl__estado-badge--asignado  { background: #fffbeb; color: #b45309; }
.mnl__estado-badge--pendiente { background: var(--c-leaf-100); color: var(--c-leaf-700); }
.mnl__estado-badge--done      { background: #dcfce7; color: #15803d; }

.mnl__done {
  display: flex; align-items: center; gap: .6rem;
  background: #f0faf3; border: 1px solid #bbf7d0; border-radius: 12px;
  padding: .8rem 1rem; margin-bottom: 1.5rem; color: #15803d; font-size: .88rem; line-height: 1.45;
}
.mnl__done strong { color: #14532d; }

.mnl__btn-icon {
  width: 32px; height: 32px; border-radius: 6px;
  background: transparent; border: 1.5px solid #e2e8f0;
  display: flex; align-items: center; justify-content: center;
  color: #64748b; cursor: pointer; transition: all .15s;
}
.mnl__btn-icon:hover { border-color: #5C7A4A; color: #5C7A4A; background: #f6faf4; }

.mnl__btn-primary {
  display: inline-flex; align-items: center; gap: 6px;
  background: #5C7A4A; color: #fff; border: none; border-radius: 7px;
  padding: .45rem 1rem; font-size: .82rem; font-weight: 600;
  cursor: pointer; transition: background .15s;
}
.mnl__btn-primary:hover { background: #4a6239; }

.mnl__btn-ghost {
  display: inline-flex; align-items: center; gap: 6px;
  background: #fff; color: #b45309; border: 1.5px solid #fde68a; border-radius: 7px;
  padding: .45rem 1rem; font-size: .82rem; font-weight: 600;
  cursor: pointer; transition: all .15s;
}
.mnl__btn-ghost:hover { background: #fffbeb; border-color: #f59e0b; }

/* KPIs — mismo patrón que SalaDetailView */
.mnl__kpis {
  display: grid; grid-template-columns: repeat(3, 1fr);
  gap: 1rem; margin-bottom: 1.75rem;
}
@media (max-width: 640px) { .mnl__kpis { grid-template-columns: repeat(1, 1fr); } }

.mnl__kpi {
  background: #fff; border: 1px solid #d4e6d4; border-radius: 14px;
  padding: 1.1rem; display: flex; align-items: flex-start; gap: .75rem;
  transition: box-shadow .15s;
}
.mnl__kpi:hover { box-shadow: 0 4px 16px rgba(27,94,32,.08); }
.mnl__kpi-ico { font-size: 1.4rem; flex-shrink: 0; margin-top: .1rem; }
.mnl__kpi-body { flex: 1; min-width: 0; }
.mnl__kpi-val {
  font-size: 1.75rem; font-weight: 800; line-height: 1;
  letter-spacing: -.04em; color: #1a1a1a; margin-bottom: .15rem;
}
.mnl__kpi-den  { font-size: 1rem; font-weight: 500; color: #94a3b8; margin-left: 2px; }
.mnl__kpi-lbl  { font-size: .7rem; color: #60725d; font-weight: 600; text-transform: uppercase; letter-spacing: .05em; }
.mnl__kpi-progress { height: 4px; background: #d4e6d4; border-radius: 999px; overflow: hidden; margin-top: .5rem; }
.mnl__kpi-progress-fill { height: 100%; border-radius: 999px; transition: width .5s ease; }

/* Section header */
.mnl__section-head {
  display: flex; align-items: center; justify-content: space-between;
  gap: .75rem; margin-bottom: .75rem;
}
.mnl__section-title {
  display: flex; align-items: center; gap: .35rem;
  font-size: .7rem; font-weight: 700; color: #60725d;
  text-transform: uppercase; letter-spacing: .07em; margin: 0;
}

/* Table */
.mnl__table-wrap {
  border: 1px solid #e2e8f0; border-radius: 10px;
  overflow: hidden; overflow-x: auto;
}
.mnl__table { width: 100%; border-collapse: collapse; }

.mnl__th {
  font-size: .68rem; font-weight: 700; color: #64748b;
  text-transform: uppercase; letter-spacing: .05em;
  padding: .55rem .85rem; background: #f8fafc;
  border-bottom: 1px solid #e2e8f0; text-align: left; white-space: nowrap;
}
.mnl__th--num    { width: 40px; text-align: center; }
.mnl__th--qr     { color: #94a3b8; }
.mnl__th--peso   { text-align: right; }
.mnl__th--estado { text-align: center; }

.mnl__tr { border-bottom: 1px solid #f1f5f9; }
.mnl__tr:last-child { border-bottom: none; }
.mnl__tr--clickable { cursor: pointer; transition: background .1s; }
.mnl__tr--clickable:hover { background: #f6faf4; }

.mnl__td {
  padding: .6rem .85rem; font-size: .82rem; color: #475569; vertical-align: middle;
}
.mnl__td--num    { text-align: center; font-size: .72rem; font-weight: 700; color: #94a3b8; }
.mnl__td--nombre { font-weight: 600; color: #0f172a; }
.mnl__td--qr     { font-size: .72rem; color: #94a3b8; }
.mnl__td--peso   { text-align: right; font-weight: 700; font-size: .85rem; }
.mnl__td--estado { text-align: center; }

.mnl__peso--ok     { color: #16a34a; }
.mnl__peso--humedo { color: #0284c7; }
.mnl__peso--none   { color: #cbd5e1; }
.mnl__prom         { font-size: .68rem; font-weight: 600; color: #d97706; margin-left: 2px; }

.mnl__chip {
  display: inline-block; font-size: .65rem; font-weight: 700;
  letter-spacing: .04em; padding: .2em .6em; border-radius: 999px; text-transform: uppercase;
}
.mnl__chip--done    { background: #dcfce7; color: #15803d; }
.mnl__chip--pending { background: #f1f5f9; color: #94a3b8; }
.mnl__chip--descartada { background: #fef2f2; color: #b91c1c; }
.mnl__chip--prom    { background: #fef3c7; color: #b45309; }

/* Footer */
/* Pesajes (jornadas) */
.mnl__pj-hint { font-size: .8rem; color: #94a3b8; margin: .25rem 0 0; line-height: 1.5; }
.mnl__pj-faltan { color: #b45309; font-weight: 700; }

.mnl__jornada {
  display: flex; align-items: center; justify-content: space-between; gap: 1rem; flex-wrap: wrap;
  background: #f6faf4; border: 1px solid #d4e6d4; border-radius: 10px; padding: .75rem 1rem;
}
.mnl__jornada-info { display: flex; flex-direction: column; gap: .15rem; }
.mnl__jornada-lbl  { font-size: .72rem; font-weight: 700; text-transform: uppercase; letter-spacing: .04em; color: #5C7A4A; }
.mnl__jornada-kpi  { font-size: .85rem; font-weight: 700; color: #0f172a; }
.mnl__jornada-acts { display: flex; align-items: center; gap: .5rem; }
.mnl__pj-del {
  display: inline-flex; align-items: center; justify-content: center;
  width: 32px; height: 32px; border-radius: 7px; border: 1.5px solid #fecaca;
  background: #fff; color: #dc2626; cursor: pointer;
}
.mnl__pj-del:hover:not(:disabled) { background: #fef2f2; }
.mnl__pj-del:disabled { opacity: .5; cursor: not-allowed; }

.mnl__hist { display: flex; flex-direction: column; gap: .35rem; margin-top: .75rem; }
.mnl__hist-row {
  display: flex; align-items: center; gap: .65rem;
  background: #fff; border: 1px solid #f1f5f9; border-radius: 8px; padding: .5rem .8rem;
}
.mnl__hist-date { font-size: .76rem; font-weight: 600; color: #64748b; width: 96px; flex-shrink: 0; text-transform: capitalize; }
.mnl__hist-info { font-size: .8rem; color: #334155; flex: 1; min-width: 0; }
.mnl__hist-act {
  display: inline-flex; align-items: center; justify-content: center;
  width: 28px; height: 28px; border-radius: 6px; border: 1.5px solid #e2e8f0;
  background: #fff; color: #64748b; cursor: pointer; flex-shrink: 0;
}
.mnl__hist-act:hover:not(:disabled) { background: #f8fafc; }
.mnl__hist-act:disabled { opacity: .5; }

.mnl__badge {
  font-size: .65rem; font-weight: 700; padding: .2em .6em; border-radius: 999px;
  text-transform: uppercase; letter-spacing: .04em; flex-shrink: 0;
}
.mnl__badge--borrador   { background: #f1f5f9; color: #64748b; }
.mnl__badge--enviado    { background: #fef3c7; color: #b45309; }
.mnl__badge--confirmado { background: #dcfce7; color: #15803d; }

.mnl__btn-submit {
  display: inline-flex; align-items: center; gap: .4rem;
  background: #5C7A4A; color: #fff; border: none; border-radius: 7px;
  padding: .5rem 1.1rem; font-size: .82rem; font-weight: 600;
  cursor: pointer; transition: background .15s;
}
.mnl__btn-submit:hover:not(:disabled) { background: #4a6239; }
.mnl__btn-submit:disabled { opacity: .45; cursor: not-allowed; }

/* Loading */
.mnl__loading { display: flex; align-items: center; justify-content: center; min-height: calc(100vh - 56px); }

/* Modal */
.mnl-overlay {
  position: fixed; inset: 0; background: rgba(0,0,0,.45);
  display: flex; align-items: center; justify-content: center;
  z-index: 1050; padding: 1rem; backdrop-filter: blur(3px);
}
.mnl-modal {
  background: #fff; border-radius: 14px;
  width: 100%; max-width: 420px; max-height: 92vh; overflow-y: auto;
  box-shadow: 0 24px 64px rgba(0,0,0,.18);
}
.mnl-modal--wide { max-width: 560px; }

/* Lista de plantas (peso individual) */
.mnl-plist { display: flex; flex-direction: column; gap: .35rem; max-height: 230px; overflow-y: auto; padding: 2px; }
.mnl-prow { display: flex; align-items: center; gap: .6rem; }
.mnl-prow__code { font-family: var(--font-mono, monospace); font-size: .78rem; font-weight: 700; color: #334155; flex: 1; min-width: 0; }
.mnl-prow__input { width: 130px; flex-shrink: 0; }
.mnl-hint { font-size: .74rem; color: #94a3b8; }
/* Selector de plantas (batch manicura) */
.mnl-sel-head { display: flex; align-items: center; justify-content: space-between; margin-bottom: .35rem; }
.mnl-sel-count { font-size: .78rem; font-weight: 700; color: #15803d; }
.mnl-sel-list { display: flex; flex-direction: column; max-height: 220px; overflow-y: auto; border: 1px solid #e2e8f0; border-radius: 10px; }
.mnl-check { display: flex; align-items: center; gap: .5rem; padding: .5rem .65rem; font-size: .85rem; color: #0f172a; cursor: pointer; }
.mnl-sel-list .mnl-check:not(:last-child) { border-bottom: 1px solid #f1f5f9; }
.mnl-check input { width: 16px; height: 16px; cursor: pointer; flex-shrink: 0; }
.mnl-check--all { font-weight: 600; color: #475569; font-size: .78rem; }
.mnl-check-nombre { font-weight: 600; }

/* Selector de sede */
.mnl-select { border-radius: 6px; cursor: pointer; appearance: none; -webkit-appearance: none; }

/* Selector de contenedores (tarjetas) */
.mnl-cont-list { display: flex; flex-direction: column; gap: .35rem; max-height: 180px; overflow-y: auto; padding: 2px; }
.mnl-cont {
  display: flex; align-items: center; gap: .55rem; width: 100%; text-align: left;
  background: #f8fafc; border: 1.5px solid #e2e8f0; border-radius: 8px;
  padding: .5rem .7rem; cursor: pointer; color: #334155; transition: border-color .15s, background .15s;
}
.mnl-cont:hover { border-color: #cbd5e1; background: #fff; }
.mnl-cont--sel { border-color: #5C7A4A; background: rgba(92,122,74,.07); }
.mnl-cont__radio {
  width: 15px; height: 15px; border-radius: 50%; border: 2px solid #cbd5e1; flex-shrink: 0;
  display: flex; align-items: center; justify-content: center;
}
.mnl-cont--sel .mnl-cont__radio { border-color: #5C7A4A; }
.mnl-cont__dot { width: 7px; height: 7px; border-radius: 50%; background: #5C7A4A; }
.mnl-cont__txt { font-size: .8rem; font-weight: 600; flex: 1; min-width: 0; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.mnl-modal__hd {
  display: flex; align-items: flex-start; gap: .75rem;
  padding: 1.25rem 1.25rem 1rem; border-bottom: 1px solid #f1f5f9;
}
.mnl-modal__ico {
  width: 38px; height: 38px; border-radius: 8px;
  background: rgba(92,122,74,.12); color: #5C7A4A;
  display: flex; align-items: center; justify-content: center; flex-shrink: 0;
}
.mnl-modal__ico--warn { background: #fffbeb; color: #b45309; }
.mnl-devolver-hint {
  font-size: .82rem; color: #64748b; line-height: 1.55; margin: 0;
  background: #fffbeb; border: 1px solid #fde68a; border-radius: 8px; padding: .6rem .75rem;
}
.mnl-devolver-hint strong { color: #b45309; }
.mnl-btn-warn {
  display: inline-flex; align-items: center; gap: .4rem;
  background: #d97706; color: #fff; border: none; border-radius: 7px;
  padding: .5rem 1rem; font-size: .82rem; font-weight: 600; cursor: pointer; transition: background .15s;
}
.mnl-btn-warn:hover:not(:disabled) { background: #b45309; }
.mnl-btn-warn:disabled { opacity: .45; cursor: not-allowed; }

.mnl-modal__title { font-size: .95rem; font-weight: 700; color: #0f172a; margin: 0 0 2px; }
.mnl-modal__sub   { font-size: .78rem; color: #64748b; margin: 0; }
.mnl-modal__close {
  margin-left: auto; background: #f8fafc; border: none;
  width: 28px; height: 28px; border-radius: 6px;
  cursor: pointer; display: flex; align-items: center; justify-content: center;
  color: #64748b; flex-shrink: 0; transition: background .15s;
}
.mnl-modal__close:hover { background: #e2e8f0; }

.mnl-modal__body { padding: 1.25rem; display: flex; flex-direction: column; gap: 1rem; }
.mnl-field  { display: flex; flex-direction: column; gap: .3rem; }
.mnl-label  { font-size: .72rem; font-weight: 700; color: #475569; text-transform: uppercase; letter-spacing: .05em; }
.mnl-req    { color: #ef4444; }
.mnl-opt    { font-size: .72rem; font-weight: 400; color: #94a3b8; text-transform: none; letter-spacing: 0; }
.mnl-input-row { display: flex; }
.mnl-input {
  flex: 1; background: #f8fafc; border: 1.5px solid #e2e8f0;
  border-radius: 6px 0 0 6px; padding: .55rem .75rem;
  font-size: .9rem; color: #0f172a; outline: none; transition: border-color .15s;
}
.mnl-input:focus { border-color: #5C7A4A; background: #fff; }
.mnl-suffix {
  background: #f1f5f9; border: 1.5px solid #e2e8f0; border-left: none;
  padding: .55rem .75rem; font-size: .82rem; font-weight: 600;
  color: #64748b; border-radius: 0 6px 6px 0; white-space: nowrap;
}
.mnl-textarea {
  background: #f8fafc; border: 1.5px solid #e2e8f0; border-radius: 6px;
  padding: .55rem .75rem; font-size: .9rem; color: #0f172a;
  outline: none; resize: vertical; min-height: 60px; transition: border-color .15s; font-family: inherit;
}
.mnl-textarea:focus { border-color: #5C7A4A; background: #fff; }
.mnl-error {
  background: #fef2f2; border: 1px solid #fecaca; color: #dc2626;
  padding: .5rem .75rem; border-radius: 6px; font-size: .82rem;
}
.mnl-actions { display: flex; justify-content: flex-end; gap: .5rem; }
.mnl-btn-cancel {
  background: transparent; color: #475569; border: 1.5px solid #e2e8f0;
  padding: .5rem 1rem; border-radius: 7px; font-size: .82rem; font-weight: 500; cursor: pointer;
}
.mnl-btn-cancel:hover { background: #f8fafc; }
.mnl-btn-ok {
  display: inline-flex; align-items: center; gap: .4rem;
  background: #5C7A4A; color: #fff; border: none; border-radius: 7px;
  padding: .5rem 1rem; font-size: .82rem; font-weight: 600; cursor: pointer; transition: background .15s;
}
.mnl-btn-ok:hover:not(:disabled) { background: #4a6239; }
.mnl-btn-ok:disabled { opacity: .45; cursor: not-allowed; }

.mnl-fade-enter-active, .mnl-fade-leave-active { transition: opacity .2s; }
.mnl-fade-enter-from,  .mnl-fade-leave-to      { opacity: 0; }
</style>
