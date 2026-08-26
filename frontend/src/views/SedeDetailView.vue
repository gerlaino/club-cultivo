<script setup>
import { ref, computed, onMounted, onUnmounted } from "vue"
import { useRoute, useRouter } from "vue-router"
import { useAuthStore } from "../stores/auth"
import { useClubStore } from "../stores/club"
import { getSede, listSalas, getSedeStocks, deleteSede, listCajasMostrador } from "../lib/api"
import ModalCrearSala    from '../components/salas/ModalCrearSala.vue'
import CajaMostradorCard from '../components/dashboards/CajaMostradorCard.vue'
import Breadcrumb         from '../components/ui/Breadcrumb.vue'
import EmptyState         from '../components/ui/EmptyState.vue'
import ActionsDropdown    from '../components/ui/ActionsDropdown.vue'
import { useToast }   from '../composables/useToast.js'
import { useConfirm } from '../composables/useConfirm.js'
import DsSpinner from '../design-system/components/Spinner.vue'

const route  = useRoute()
const router = useRouter()
const auth   = useAuthStore()
const club   = useClubStore()
const toast  = useToast()
const { confirm } = useConfirm()

// Umbral de stock bajo configurable (Stock → "Alerta stock bajo"), no hardcodeado.
const umbralStockBajo = computed(() => Number(club.data?.umbral_stock_g ?? 50))

const deleting = ref(false)
async function eliminarSede() {
  const ok = await confirm({
    title: 'Eliminar sede',
    message: `¿Seguro que querés eliminar "${sede.value?.nombre}"? Esta acción no se puede deshacer.`,
    confirmText: 'Eliminar',
    variant: 'danger',
  })
  if (!ok) return
  deleting.value = true
  try {
    await deleteSede(sedeId)
    toast.success('Sede eliminada')
    router.push({ name: 'sedes' })
  } catch (e) {
    toast.error(e?.response?.data?.error || 'Error al eliminar la sede')
  } finally {
    deleting.value = false
  }
}

const sedeId        = Number(route.params.id)
const sede          = ref(null)
const salas         = ref([])
const loading       = ref(true)
const error         = ref(null)
const showCrearSala = ref(false)

const canEdit        = computed(() => ["admin", "cultivador"].includes(auth.role))
const puedeCrearSala = computed(() => ["admin", "supervisor"].includes(auth.role))
const isAdmin        = computed(() => auth.user?.role === 'admin')

const tieneInv   = computed(() => ['social', 'mixta'].includes(sede.value?.tipo))
const tieneSalas = computed(() => ['produccion', 'mixta'].includes(sede.value?.tipo))

// Sólo las sedes que dispensan tienen mostrador y, por lo tanto, caja. Es la misma regla que ya
// decide qué tipo de sede se puede crear según lo contratado (`Sede::SUITES_POR_TIPO`).
const sedeDispensa = computed(() => ['social', 'mixta'].includes(sede.value?.tipo))

// Historial de turnos. Cerrados y anulados: el que se anuló también dice quién y por qué.
const historialCaja    = ref([])
const verHistorialCaja = ref(false)
const cajaRef          = ref(null)

// El backend devuelve SÓLO los cierres, paginados. Una caja anulada no operó y no tiene nada que
// contar: el rastro de quién la anuló vive en el audit log, no en esta pantalla.
const PAGINA_CAJAS = 10
const paginaCaja   = ref(1)
const totalCajas   = ref(0)
const hayMasCajas  = computed(() => historialCaja.value.length < totalCajas.value)

async function cargarHistorialCaja({ acumular = false } = {}) {
  if (!sedeDispensa.value || !sede.value?.id) return
  try {
    const { data } = await listCajasMostrador(sede.value.id, {
      pagina: acumular ? paginaCaja.value : 1, limite: PAGINA_CAJAS,
    })
    const cajas = data?.cajas || []
    historialCaja.value = acumular ? [...historialCaja.value, ...cajas] : cajas
    totalCajas.value = data?.meta?.total ?? cajas.length
    if (!acumular) paginaCaja.value = 1
  } catch { if (!acumular) historialCaja.value = [] }
}

async function verMasCajas() {
  paginaCaja.value += 1
  await cargarHistorialCaja({ acumular: true })
}

function fmtFechaCaja(iso) {
  if (!iso) return '—'
  return new Date(iso).toLocaleString('es-AR', { day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit' })
}
// Gramos y "stock bajo" = solo flor seca (los derivados son inventario con otra unidad).
const florSeca   = computed(() => tiendaStocks.value.filter(s => s.forma_producto === 'flor_seca'))
const stockTotal = computed(() => florSeca.value.reduce((a, s) => a + Number(s.cantidad || 0), 0))
const itemsBajos = computed(() => florSeca.value.filter(s => Number(s.cantidad) < umbralStockBajo.value).length)


// ── Tienda social (stocks asignados a esta sede) ─────────────────
const tiendaStocks  = ref([])
const loadingTienda = ref(false)

const FORMA_LABELS = { flor_seca: '🌿 Flor seca', hash: '🟤 Hash', aceite: '🫙 Aceite', tintura: '💧 Tintura', topico: '🧴 Tópico', otro: '📦 Otro' }
const KIND_LABELS = { enraizado: 'Enraizado', vegetativo: 'Vegetativo', floracion: 'Floración', cosecha: 'Cosecha', curado: 'Curado', manicura: 'Manicura', mixta: 'Mixta', madre: 'Madre', madres: 'Madres' }
function kindLabel(k) { return KIND_LABELS[k] || k || '' }

// El stock de la sede es SOLO LECTURA acá; la gestión (editar cantidad, precio, ajustes) vive en
// la vista de Stock. La card lleva ahí de un click (solo admin).
function irAlStock() { router.push('/admin/stock') }

async function loadTiendaStocks() {
  loadingTienda.value = true
  try { const { data } = await getSedeStocks(sedeId); tiendaStocks.value = data || [] }
  catch { tiendaStocks.value = [] }
  finally { loadingTienda.value = false }
}


// ── Original ────────────────────────────────────────────────────
const TIPO_META = {
  produccion: { label: "Producción",  icon: "bi-flower2",         color: "#15803d", bg: "rgba(21,128,61,.1)"  },
  social:     { label: "Dispensario", icon: "bi-shop",             color: "#0369a1", bg: "rgba(3,105,161,.1)"  },
  mixta:      { label: "Mixta",       icon: "bi-arrow-left-right", color: "#7c3aed", bg: "rgba(124,58,237,.1)" },
}
function tipoMeta(tipo) { return TIPO_META[tipo] || TIPO_META.produccion }

const kpis = computed(() => ({
  total:     salas.value.length,
  activas:   salas.value.filter(s => s.state === "activa").length,
  plantas:   salas.value.reduce((a, s) => a + Number(s.plantas_totales || 0), 0),
}))

function ocupacionColor(pct) {
  if (pct >= 100) return "#b91c1c"
  if (pct >= 90) return "#dc2626"
  if (pct >= 70) return "#f59e0b"
  return "#15803d"
}

function formatDate(d) {
  if (!d) return "—"
  return new Date(d).toLocaleDateString("es-AR", { day: "numeric", month: "short", year: "numeric" })
}

async function recargarSalas() {
  const r = await listSalas()
  salas.value = (r.data || []).filter(s => s.sede?.id === sedeId)
}

function onSalaCreada() {
  showCrearSala.value = false
  recargarSalas()
}

const sedeAcciones = computed(() => {
  const items = []
  if (tieneInv.value) {
    items.push({ emoji: '📊', label: 'Gestionar stock', onClick: () => router.push('/admin/stock') })
  }
  if (isAdmin.value) {
    items.push({ divider: true })
    items.push({ emoji: '🗑️', label: 'Eliminar sede', danger: true, onClick: eliminarSede, disabled: deleting.value })
  }
  return items
})

function escapeHandler(e) {
  if (e.key !== 'Escape') return
  if (showCrearSala.value) showCrearSala.value = false
}
onUnmounted(() => document.removeEventListener('keydown', escapeHandler, true))
onMounted(async () => {
  document.addEventListener('keydown', escapeHandler, true)
  try {
    const [sedeRes, salasRes] = await Promise.all([getSede(sedeId), listSalas()])
    sede.value  = sedeRes.data
    salas.value = (salasRes.data || []).filter(s => s.sede?.id === sedeId)
    if (tieneInv.value) await loadTiendaStocks()
    // Después de tener la sede: el historial depende de saber si dispensa.
    cargarHistorialCaja()
  } catch (e) {
    error.value = "No se pudo cargar la sede."
  } finally {
    loading.value = false
  }
})
</script>

<template>
  <div class="sdv">

    <div v-if="loading" class="sdv__loading">
      <DsSpinner />
    </div>

    <div v-else-if="error" class="sdv__error">
      <i class="bi bi-exclamation-triangle-fill"></i> {{ error }}
    </div>

    <template v-else-if="sede">

      <Breadcrumb :items="[{ label: 'Sedes', to: { name: 'sedes' } }, { label: sede.nombre }]" />

      <div class="sdv__header">
        <div class="sdv__header-left">
          <div class="sdv__tipo-icon" :style="{ background: tipoMeta(sede.tipo).bg, color: tipoMeta(sede.tipo).color }">
            <i :class="['bi', tipoMeta(sede.tipo).icon]"></i>
          </div>
          <div>
            <div class="sdv__title-row">
              <h1 class="sdv__title">{{ sede.nombre }}</h1>
              <span class="sdv__tipo-badge" :style="{ background: tipoMeta(sede.tipo).bg, color: tipoMeta(sede.tipo).color }">
                {{ tipoMeta(sede.tipo).label }}
              </span>
              <span v-if="sede.declarada_reprocann" class="sdv__reprocann-badge">
                <i class="bi bi-patch-check-fill"></i> REPROCANN
              </span>
            </div>
            <p v-if="sede.direccion_completa" class="sdv__subtitle">
              <i class="bi bi-geo-alt"></i> {{ sede.direccion_completa }}
            </p>
          </div>
        </div>
        <div class="sdv__header-actions">
          <button v-if="puedeCrearSala && tieneSalas" class="sdv__btn-primary" @click="showCrearSala = true">
            <i class="bi bi-plus-lg"></i> Nueva sala
          </button>
          <ActionsDropdown v-if="isAdmin && sedeAcciones.length" :items="sedeAcciones" />
        </div>
      </div>

      <!-- La caja del mostrador. Va acá y no en el tablero: se abre POR SEDE, y desde la sede no
           hay forma de confundirse de cuál. Sólo en las que dispensan — en una de producción no
           hay mostrador, y `Sede::SUITES_POR_TIPO` ya define cuáles son. -->
      <CajaMostradorCard v-if="sedeDispensa" ref="cajaRef" :sede="{ id: sede.id, nombre: sede.nombre }"
                         :puede-gestionar="isAdmin" @cambio="cargarHistorialCaja" />

      <!-- Historial de turnos: quién abrió, quién confirmó el fondo, quién contó y quién cerró.
           Una diferencia de arqueo sin nombres al lado no se puede revisar tres semanas después. -->
      <div v-if="sedeDispensa && historialCaja.length" class="sdv__cajas">
        <button type="button" class="sdv__cajas-hd" @click="verHistorialCaja = !verHistorialCaja">
          <i :class="['bi', verHistorialCaja ? 'bi-caret-down-fill' : 'bi-caret-right-fill']"></i>
          Turnos anteriores
          <span class="sdv__cajas-n">{{ totalCajas }}</span>
        </button>
        <div v-if="verHistorialCaja" class="sdv__cajas-list">
          <div v-for="c in historialCaja" :key="c.id" class="sdv__caja-item">
            <div class="sdv__caja-l1">
              <span class="sdv__caja-fecha">{{ fmtFechaCaja(c.abierta_at) }}</span>
              <span v-if="c.diferencia_ars" class="sdv__caja-dif"
                    :class="{ 'sdv__caja-dif--mal': c.diferencia_ars < 0 }">
                {{ c.diferencia_ars < 0 ? 'faltaron' : 'sobraron' }} ${{ Math.abs(c.diferencia_ars).toLocaleString('es-AR') }}
              </span>
              <span v-else class="sdv__caja-ok">cuadró</span>
            </div>
            <div class="sdv__caja-l2">
              Abrió <strong>{{ c.abierta_por || '—' }}</strong>
              <template v-if="c.apertura_confirmada_por"> · confirmó <strong>{{ c.apertura_confirmada_por }}</strong></template>
              <template v-if="c.cierre_solicitado_por"> · contó <strong>{{ c.cierre_solicitado_por }}</strong></template>
              <template v-if="c.cerrada_por">
                · cerró <strong>{{ c.cerrada_por }}</strong>
              </template>
            </div>
            <div v-if="c.notas" class="sdv__caja-notas">{{ c.notas }}</div>
          </div>
          <button v-if="hayMasCajas" type="button" class="sdv__cajas-mas" @click="verMasCajas">
            Ver turnos anteriores ({{ totalCajas - historialCaja.length }} más)
          </button>
        </div>
      </div>

      <div v-if="tieneSalas" class="sdv__kpis sdv__kpis--3">
        <div class="sdv__kpi"><div class="sdv__kpi-val">{{ kpis.total }}</div><div class="sdv__kpi-lbl">Salas totales</div></div>
        <div class="sdv__kpi"><div class="sdv__kpi-val" style="color:#15803d">{{ kpis.activas }}</div><div class="sdv__kpi-lbl">Activas</div></div>
        <div class="sdv__kpi"><div class="sdv__kpi-val">{{ kpis.plantas }}</div><div class="sdv__kpi-lbl">Plantas totales</div></div>
      </div>

      <div v-if="tieneInv" class="sdv__kpis">
        <div class="sdv__kpi"><div class="sdv__kpi-val">{{ tiendaStocks.length }}</div><div class="sdv__kpi-lbl">Productos en stock</div></div>
        <div class="sdv__kpi"><div class="sdv__kpi-val" style="color:#0369a1">{{ stockTotal.toLocaleString('es-AR', { maximumFractionDigits: 1 }) }}g</div><div class="sdv__kpi-lbl">Gramos de flor seca</div></div>
        <div class="sdv__kpi"><div class="sdv__kpi-val" :style="{ color: itemsBajos > 0 ? '#dc2626' : '#15803d' }">{{ itemsBajos }}</div><div class="sdv__kpi-lbl">Stock bajo (&lt;{{ umbralStockBajo }}g)</div></div>
      </div>

      <div class="sdv__layout">
        <div class="sdv__col-main">

          <!-- STOCK / TIENDA SOCIAL -->
          <div v-if="tieneInv" class="sdv__card" :class="{ 'sdv__card--mb': tieneSalas }">
            <div class="sdv__card-header">
              <div class="sdv__card-title-wrap">
                <span class="sdv__card-icon" style="background:rgba(27,94,32,.1);color:#1b5e20"><i class="bi bi-shop"></i></span>
                <span class="sdv__card-title">Stock disponible</span>
                <span class="sdv__pill">{{ tiendaStocks.length }}</span>
              </div>
              <RouterLink v-if="isAdmin" to="/admin/stock" class="sdv__card-btn">Gestionar →</RouterLink>
            </div>
            <div v-if="loadingTienda" class="sdv__tienda-loading"><DsSpinner :size="40" /></div>
            <EmptyState v-else-if="!tiendaStocks.length" icon="bi-shop" title="Sin stock asignado" message="Esta sede no tiene stock. Asigná desde el gestor de stock." compact>
              <template #actions>
                <RouterLink v-if="isAdmin" to="/admin/stock" class="sdv__btn-sm-green"><i class="bi bi-boxes"></i> Ir al stock</RouterLink>
              </template>
            </EmptyState>
            <div v-else class="sdv__tienda-grid">
              <div v-for="s in tiendaStocks" :key="s.id" class="sdv__tienda-card"
                   :class="{ 'sdv__tienda-card--link': isAdmin }"
                   :title="isAdmin ? 'Ver y editar en Stock' : ''"
                   @click="isAdmin && irAlStock()">
                <div class="sdv__tienda-card-top">
                  <div class="sdv__tienda-forma">{{ FORMA_LABELS[s.forma_producto] || s.forma_producto }}</div>
                  <i v-if="isAdmin" class="bi bi-box-arrow-up-right sdv__tienda-link-ico"></i>
                </div>
                <div v-if="s.genetica" class="sdv__tienda-gen">🧬 {{ s.genetica.nombre }}</div>
                <div v-if="s.lote_codigo" class="sdv__tienda-lote">📋 {{ s.lote_codigo }}</div>
                <div class="sdv__tienda-qty">
                  <strong>{{ parseFloat(s.cantidad).toLocaleString('es-AR', { maximumFractionDigits: 1 }) }}</strong>
                  <span class="sdv__tienda-unit">{{ s.unidad || 'g' }}</span>
                </div>
                <div v-if="s.precio_sugerido_ars" class="sdv__tienda-precio">$ {{ parseFloat(s.precio_sugerido_ars).toLocaleString('es-AR', { maximumFractionDigits: 2 }) }}/{{ s.unidad || 'g' }}</div>
                <div class="sdv__tienda-status" :class="parseFloat(s.cantidad) > 0 ? 'sdv__tienda-status--ok' : 'sdv__tienda-status--empty'">
                  {{ parseFloat(s.cantidad) > 0 ? '✓ Disponible' : '✗ Agotado' }}
                </div>
              </div>
            </div>
          </div>

          <!-- SALAS -->
          <div v-if="tieneSalas" class="sdv__card">
            <div class="sdv__card-header">
              <div class="sdv__card-title-wrap">
                <span class="sdv__card-icon" style="background:rgba(27,94,32,.1);color:#1b5e20"><i class="bi bi-grid-3x3-gap"></i></span>
                <span class="sdv__card-title">Salas de esta sede</span>
                <span class="sdv__pill">{{ salas.length }}</span>
              </div>
              <RouterLink :to="{ name: 'salas' }" class="sdv__card-btn">Ver todas →</RouterLink>
            </div>
            <EmptyState v-if="!salas.length" icon="bi-building-slash" title="Sin salas" message="Esta sede no tiene salas asignadas todavía." compact>
              <template #actions>
                <button v-if="puedeCrearSala" class="sdv__btn-sm-green" @click="showCrearSala = true">Crear primera sala</button>
              </template>
            </EmptyState>
            <div v-else class="sdv__salas">
              <RouterLink v-for="s in salas" :key="s.id" :to="{ name: 'sala-detail', params: { id: s.id } }" class="sdv__sala">
                <div class="sdv__sala-state" :style="{ background: s.state === 'activa' ? '#15803d' : s.state === 'mantenimiento' ? '#f59e0b' : '#94a3b8' }"></div>
                <div class="sdv__sala-body">
                  <div class="sdv__sala-header">
                    <span class="sdv__sala-nombre">{{ s.nombre }}</span>
                    <div class="sdv__sala-badges">
                      <span class="sdv__state-badge" :style="s.state === 'activa' ? 'background:#dcfce7;color:#15803d' : s.state === 'mantenimiento' ? 'background:#fffbeb;color:#b45309' : 'background:#f1f5f9;color:#64748b'">{{ s.state }}</span>
                      <span v-if="s.kind" class="sdv__kind-badge">{{ kindLabel(s.kind) }}</span>
                    </div>
                  </div>
                  <div class="sdv__sala-meta">
                    <span><i class="bi bi-flower1"></i> {{ s.plantas_totales ?? 0 }} plantas</span>
                    <span v-if="s.lotes_count !== undefined"><i class="bi bi-collection"></i> {{ s.lotes_count }} lotes</span>
                  </div>
                </div>
                <i class="bi bi-arrow-right sdv__sala-arrow"></i>
              </RouterLink>
            </div>
          </div>

        </div>

        <!-- Sidebar -->
        <div class="sdv__col-side">
          <div class="sdv__card">
            <div class="sdv__card-header">
              <div class="sdv__card-title-wrap">
                <span class="sdv__card-icon" style="background:rgba(3,105,161,.1);color:#0369a1"><i class="bi bi-info-circle"></i></span>
                <span class="sdv__card-title">Información</span>
              </div>
            </div>
            <dl class="sdv__dl">
              <dt>Tipo</dt>
              <dd><span class="sdv__tipo-badge sdv__tipo-badge--sm" :style="{ background: tipoMeta(sede.tipo).bg, color: tipoMeta(sede.tipo).color }">{{ tipoMeta(sede.tipo).label }}</span></dd>
              <dt>Estado</dt>
              <dd><span class="sdv__state-badge" :style="sede.activa ? 'background:#dcfce7;color:#15803d' : 'background:#fffbeb;color:#b45309'">{{ sede.activa ? "Activa" : "Inactiva" }}</span></dd>
              <dt>REPROCANN</dt>
              <dd><span class="sdv__state-badge" :style="sede.declarada_reprocann ? 'background:#dcfce7;color:#15803d' : 'background:#f1f5f9;color:#64748b'">{{ sede.declarada_reprocann ? "Declarada ✓" : "No declarada" }}</span></dd>
              <template v-if="sede.direccion"><dt>Dirección</dt><dd>{{ sede.direccion }}</dd></template>
              <template v-if="sede.ciudad"><dt>Ciudad</dt><dd>{{ sede.ciudad }}</dd></template>
              <template v-if="sede.provincia"><dt>Provincia</dt><dd>{{ sede.provincia }}</dd></template>
              <dt>Registrada</dt><dd>{{ formatDate(sede.created_at) }}</dd>
            </dl>
          </div>
          <div v-if="sede.notas" class="sdv__card sdv__card--mt">
            <div class="sdv__card-header">
              <div class="sdv__card-title-wrap">
                <span class="sdv__card-icon" style="background:rgba(180,83,9,.1);color:#b45309"><i class="bi bi-journal-text"></i></span>
                <span class="sdv__card-title">Notas</span>
              </div>
            </div>
            <p class="sdv__notas">{{ sede.notas }}</p>
          </div>
        </div>
      </div>

    </template>

    <ModalCrearSala v-if="showCrearSala" :sede-id-fija="sedeId" @close="showCrearSala = false" @created="onSalaCreada" />

  </div>
</template>

<style scoped>

/* ── Historial de turnos de caja ────────────────────────────────────────────── */
.sdv__cajas { border: 1px solid var(--c-ink-200); border-radius: 12px; background: #fff; margin-bottom: var(--sp-4); overflow: hidden; }
.sdv__cajas-hd { width: 100%; display: flex; align-items: center; gap: var(--sp-2); background: none; border: none; padding: var(--sp-3); cursor: pointer; font: inherit; font-weight: 700; font-size: var(--fs-13); color: var(--c-ink-700); }
.sdv__cajas-n { margin-left: auto; font-size: var(--fs-11); color: var(--c-ink-400); }
.sdv__cajas-list { border-top: 1px solid var(--c-ink-100); }
.sdv__caja-item { padding: var(--sp-3); border-bottom: 1px solid var(--c-ink-100); display: flex; flex-direction: column; gap: .15rem; }
.sdv__caja-item:last-child { border-bottom: none; }
.sdv__caja-l1 { display: flex; align-items: baseline; gap: var(--sp-2); }
.sdv__caja-fecha { font-weight: 700; font-size: var(--fs-13); color: var(--c-ink-900); }
.sdv__caja-ok { font-size: var(--fs-12); color: #15803d; }
.sdv__caja-dif { font-size: var(--fs-12); color: #b45309; font-weight: 700; font-variant-numeric: tabular-nums; }
.sdv__caja-dif--mal { color: #b91c1c; }
.sdv__cajas-mas { width: 100%; background: none; border: none; border-top: 1px solid var(--c-ink-100); padding: var(--sp-3); cursor: pointer; font: inherit; font-size: var(--fs-12); font-weight: 700; color: #1b5e20; }
.sdv__cajas-mas:hover { background: var(--c-leaf-50); }
.sdv__caja-l2 { font-size: var(--fs-12); color: var(--c-ink-500); }
.sdv__caja-l2 strong { color: var(--c-ink-700); font-weight: 600; }
.sdv__caja-notas { font-size: var(--fs-12); color: var(--c-ink-600); font-style: italic; }
/* ══ ORIGINALES ══════════════════════════════════════════════════ */
.sdv { padding: 1.75rem 1.75rem 3rem; max-width: 1200px; margin: 0 auto; }
@media (max-width: 768px) { .sdv { padding: 1.25rem 1rem 2rem; } }
.sdv__loading { display: flex; align-items: center; justify-content: center; min-height: calc(100vh - 56px); }
.sdv__error { background: #fef2f2; border: 1px solid #fecaca; color: #dc2626; padding: 1rem; border-radius: 10px; display: flex; gap: .5rem; align-items: center; }
.sdv__header { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; margin-bottom: 1.75rem; flex-wrap: wrap; }
.sdv__header-left { display: flex; align-items: flex-start; gap: 1rem; }
.sdv__tipo-icon { width: 52px; height: 52px; border-radius: 14px; display: flex; align-items: center; justify-content: center; font-size: 1.3rem; flex-shrink: 0; }
.sdv__title-row { display: flex; align-items: center; gap: .6rem; flex-wrap: wrap; margin-bottom: .25rem; }
.sdv__title { font-size: 1.75rem; font-weight: 800; color: var(--c-slate-900); margin: 0; letter-spacing: -.03em; }
.sdv__tipo-badge { font-size: .72rem; font-weight: 700; padding: .2em .65em; border-radius: 6px; }
.sdv__tipo-badge--sm { font-size: .72rem; font-weight: 700; padding: .2em .55em; border-radius: 5px; }
.sdv__reprocann-badge { display: inline-flex; align-items: center; gap: .3rem; font-size: .72rem; font-weight: 700; background: #dcfce7; color: #15803d; padding: .2em .6em; border-radius: 6px; }
.sdv__subtitle { font-size: .83rem; color: var(--c-slate-500); margin: 0; display: flex; align-items: center; gap: .35rem; }
.sdv__header-actions { display: flex; gap: .6rem; flex-wrap: wrap; align-items: center; }
.sdv__kpis { display: grid; grid-template-columns: repeat(4, 1fr); gap: 1rem; margin-bottom: 1.75rem; }
.sdv__kpis--3 { grid-template-columns: repeat(3, 1fr); }
@media (max-width: 640px) { .sdv__kpis { grid-template-columns: repeat(2, 1fr); } }
.sdv__kpi { background: #fff; border: 1px solid var(--c-slate-200); border-radius: 12px; padding: 1.1rem 1rem; text-align: center; }
.sdv__kpi-val { font-size: 2rem; font-weight: 800; color: var(--c-slate-900); line-height: 1; letter-spacing: -.04em; }
.sdv__kpi-lbl { font-size: .72rem; font-weight: 600; color: var(--c-slate-400); text-transform: uppercase; letter-spacing: .04em; margin-top: .35rem; }
.sdv__layout { display: grid; grid-template-columns: 1fr 280px; gap: 1.25rem; align-items: start; }
@media (max-width: 900px) { .sdv__layout { grid-template-columns: 1fr; } }
.sdv__col-side { display: flex; flex-direction: column; position: sticky; top: 1.5rem; }
.sdv__card--mt { margin-top: 1.25rem; }
.sdv__card--mb { margin-bottom: 1.25rem; }
.sdv__card { background: #fff; border: 1px solid var(--c-slate-200); border-radius: 14px; overflow: hidden; }
.sdv__card-header { display: flex; align-items: center; justify-content: space-between; padding: .875rem 1.1rem; border-bottom: 1px solid var(--c-slate-100); background: #fafbfc; }
.sdv__card-title-wrap { display: flex; align-items: center; gap: .6rem; }
.sdv__card-icon { width: 30px; height: 30px; border-radius: 7px; display: flex; align-items: center; justify-content: center; font-size: .8rem; flex-shrink: 0; }
.sdv__card-title { font-size: .875rem; font-weight: 700; color: var(--c-slate-900); }
.sdv__card-btn { font-size: .78rem; font-weight: 600; color: #0369a1; background: none; border: none; cursor: pointer; padding: 0; text-decoration: none; }
.sdv__card-btn:hover { text-decoration: underline; }
.sdv__card-btn-green { display: inline-flex; align-items: center; gap: 5px; font-size: .78rem; font-weight: 600; color: #15803d; background: rgba(21,128,61,.08); border: 1px solid rgba(21,128,61,.2); padding: .25rem .7rem; border-radius: 6px; cursor: pointer; transition: background .15s; }
.sdv__card-btn-green:hover { background: rgba(21,128,61,.14); }
.sdv__pill { font-size: .65rem; font-weight: 800; background: var(--c-slate-100); color: var(--c-slate-600); padding: .15em .5em; border-radius: 999px; }
.sdv__salas { display: flex; flex-direction: column; }
.sdv__sala { display: flex; align-items: center; gap: .875rem; padding: .875rem 1.1rem; border-bottom: 1px solid var(--c-slate-50); text-decoration: none; color: inherit; transition: background .12s; }
.sdv__sala:last-child { border-bottom: none; }
.sdv__sala:hover { background: #fafbfc; }
.sdv__sala-state { width: 3px; height: 40px; border-radius: 999px; flex-shrink: 0; }
.sdv__sala-body { flex: 1; min-width: 0; }
.sdv__sala-header { display: flex; align-items: center; gap: .5rem; flex-wrap: wrap; margin-bottom: .25rem; }
.sdv__sala-nombre { font-size: .9rem; font-weight: 700; color: var(--c-slate-900); }
.sdv__sala-badges { display: flex; gap: .35rem; }
.sdv__state-badge { font-size: .68rem; font-weight: 700; padding: .2em .5em; border-radius: 5px; }
.sdv__kind-badge { font-size: .68rem; font-weight: 600; background: var(--c-slate-100); color: var(--c-slate-500); padding: .2em .5em; border-radius: 5px; text-transform: capitalize; }
.sdv__sala-meta { display: flex; gap: .75rem; font-size: .75rem; color: var(--c-slate-400); flex-wrap: wrap; }
.sdv__sala-meta i { margin-right: .2rem; }
.sdv__sala-ocupacion { display: flex; flex-direction: column; align-items: flex-end; gap: .2rem; min-width: 70px; flex-shrink: 0; }
.sdv__ocu-pct { font-size: .78rem; font-weight: 700; }
.sdv__ocu-bar { width: 70px; height: 4px; background: var(--c-slate-100); border-radius: 999px; overflow: hidden; }
.sdv__ocu-fill { height: 100%; border-radius: 999px; transition: width .4s; }
.sdv__ocu-label { font-size: .62rem; color: var(--c-slate-400); }
.sdv__sala-arrow { color: var(--c-slate-300); font-size: .85rem; flex-shrink: 0; transition: color .15s, transform .15s; }
.sdv__sala:hover .sdv__sala-arrow { color: var(--c-slate-900); transform: translateX(2px); }
.sdv__dl { display: grid; grid-template-columns: 100px 1fr; gap: .4rem .5rem; padding: 1rem 1.1rem; margin: 0; }
.sdv__dl dt { font-size: .75rem; color: var(--c-slate-400); font-weight: 500; display: flex; align-items: center; }
.sdv__dl dd { font-size: .82rem; color: var(--c-slate-900); font-weight: 500; margin: 0; display: flex; align-items: center; }
.sdv__notas { padding: .875rem 1.1rem; font-size: .85rem; color: var(--c-slate-600); margin: 0; line-height: 1.6; }
.sdv__btn-primary { display: inline-flex; align-items: center; gap: .4rem; background: var(--brand-primary, #1b5e20); color: #fff; border: none; padding: .6rem 1.1rem; border-radius: 8px; font-size: .875rem; font-weight: 700; cursor: pointer; text-decoration: none; transition: background .15s, transform .1s; white-space: nowrap; }
.sdv__btn-primary:hover { background: #144a18; transform: translateY(-1px); }
.sdv__btn-primary:disabled { opacity: .55; cursor: not-allowed; transform: none; }
.sdv__btn-ghost { display: inline-flex; align-items: center; gap: .4rem; background: #fff; color: var(--c-slate-500); border: 1.5px solid var(--c-slate-200); padding: .6rem 1rem; border-radius: 8px; font-size: .875rem; font-weight: 600; cursor: pointer; transition: all .15s; white-space: nowrap; }
.sdv__btn-ghost:hover { background: var(--c-slate-50); color: var(--c-slate-900); }
.sdv__btn-sm-green { display: inline-flex; align-items: center; gap: .35rem; background: rgba(27,94,32,.08); color: #1b5e20; border: 1.5px solid rgba(27,94,32,.2); padding: .45rem .875rem; border-radius: 7px; font-size: .8rem; font-weight: 600; cursor: pointer; transition: all .15s; }
.sdv__btn-sm-green:hover { background: rgba(27,94,32,.14); }

/* ══ NUEVO ═══════════════════════════════════════════════════════ */
.sdv__btn-inv { display: inline-flex; align-items: center; gap: .4rem; background: rgba(3,105,161,.08); color: #0369a1; border: 1.5px solid rgba(3,105,161,.2); padding: .6rem 1rem; border-radius: 8px; font-size: .875rem; font-weight: 600; cursor: pointer; transition: all .15s; white-space: nowrap; }
.sdv__btn-inv:hover { background: rgba(3,105,161,.14); }

.sdv__inv-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(190px, 1fr)); gap: 12px; padding: 16px; }
.sdv__inv-card { background: var(--c-slate-50); border: 1px solid var(--c-slate-200); border-radius: 12px; padding: 14px; display: flex; flex-direction: column; gap: 6px; transition: box-shadow .15s; }
.sdv__inv-card:hover { box-shadow: 0 2px 12px rgba(0,0,0,.08); }
.sdv__inv-card--low { border-color: #fecaca; background: #fff5f5; }
.sdv__inv-card__top { display: flex; justify-content: space-between; align-items: center; }
.sdv__inv-icon { width: 30px; height: 30px; border-radius: 7px; background: rgba(3,105,161,.08); color: #0369a1; display: flex; align-items: center; justify-content: center; font-size: 14px; flex-shrink: 0; }
.sdv__inv-badge { font-size: 10px; padding: 2px 7px; border-radius: 4px; font-weight: 600; display: inline-flex; align-items: center; gap: 3px; }
.sdv__inv-badge--ok { background: #dcfce7; color: #15803d; }
.sdv__inv-badge--warn { background: #fef2f2; color: #dc2626; }
.sdv__inv-producto { font-size: 13px; font-weight: 600; color: #1e293b; }
.sdv__inv-stock { font-size: 22px; font-weight: 800; color: #0369a1; line-height: 1; letter-spacing: -.02em; }
.sdv__inv-unit { font-size: 13px; font-weight: 400; color: var(--c-slate-400); }
.sdv__inv-lote { background: rgba(3,105,161,.04); border: 1px solid rgba(3,105,161,.12); border-radius: 7px; padding: 7px 9px; }
.sdv__inv-lote--ext { display: flex; align-items: center; gap: 5px; color: var(--c-slate-400); font-size: 11px; background: var(--c-slate-50); border-color: var(--c-slate-200); }
.sdv__inv-lote-header { display: flex; align-items: center; gap: 4px; font-size: 10px; color: #0369a1; font-weight: 700; text-transform: uppercase; letter-spacing: .05em; margin-bottom: 3px; }
.sdv__inv-lote-codigo { font-size: 12px; font-weight: 700; color: var(--c-slate-900); }
.sdv__inv-lote-meta { font-size: 11px; color: var(--c-slate-500); margin-bottom: 4px; }
.sdv__inv-lote-estado { display: inline-block; font-size: 10px; padding: 1px 7px; border-radius: 4px; font-weight: 600; }
.sdv__inv-bar-wrap { height: 4px; background: var(--c-slate-200); border-radius: 2px; overflow: hidden; }
.sdv__inv-bar { height: 100%; border-radius: 2px; transition: width .3s; }
.sdv__inv-bar--ok { background: #15803d; }
.sdv__inv-bar--low { background: #dc2626; }
.sdv__inv-meta { display: flex; justify-content: space-between; font-size: 11px; color: var(--c-slate-400); }

.sdv__modal-overlay { position: fixed; inset: 0; background: rgba(0,0,0,.5); backdrop-filter: blur(8px); display: flex; align-items: center; justify-content: center; z-index: 1000; padding: 1rem; }
.sdv__modal { background: white; border-radius: 20px; width: 100%; max-width: 560px; max-height: 92vh; overflow-y: auto; box-shadow: 0 24px 80px rgba(0,0,0,.2); }
.sdv__modal-header { display: flex; align-items: center; gap: 12px; padding: 20px 24px 18px; border-bottom: 1px solid var(--c-slate-100); position: sticky; top: 0; background: white; z-index: 1; border-radius: 20px 20px 0 0; }
.sdv__modal-header-icon { width: 40px; height: 40px; border-radius: 10px; background: rgba(3,105,161,.1); color: #0369a1; display: flex; align-items: center; justify-content: center; font-size: 17px; flex-shrink: 0; }
.sdv__modal-title { font-size: 17px; font-weight: 700; color: var(--c-slate-900); margin: 0 0 2px; }
.sdv__modal-sub { font-size: 13px; color: var(--c-slate-500); margin: 0; }
.sdv__modal-close { margin-left: auto; background: var(--c-slate-100); border: none; width: 32px; height: 32px; border-radius: 8px; cursor: pointer; color: var(--c-slate-500); display: flex; align-items: center; justify-content: center; font-size: 13px; transition: all .15s; flex-shrink: 0; }
.sdv__modal-close:hover { background: var(--c-slate-200); color: var(--c-slate-900); }
.sdv__modal-body { padding: 20px 24px; display: flex; flex-direction: column; gap: 20px; }
.sdv__modal-footer { padding: 14px 24px; border-top: 1px solid var(--c-slate-100); display: flex; justify-content: flex-end; gap: 10px; position: sticky; bottom: 0; background: white; border-radius: 0 0 20px 20px; }

.sdv__field { display: flex; flex-direction: column; gap: 8px; }
.sdv__label { font-size: 13px; font-weight: 600; color: #374151; display: flex; align-items: center; gap: 7px; flex-wrap: wrap; }
.sdv__label-num { width: 20px; height: 20px; border-radius: 50%; background: var(--c-slate-900); color: white; font-size: 11px; font-weight: 700; display: inline-flex; align-items: center; justify-content: center; flex-shrink: 0; }
.sdv__optional { font-weight: 400; color: #9ca3af; font-size: 12px; }
.sdv__unidad-pill { background: #f0fdf4; border: 1px solid #bbf7d0; color: #15803d; font-size: 11px; padding: 1px 8px; border-radius: 4px; font-weight: 500; }

.sdv__producto-grid { display: grid; grid-template-columns: repeat(5, 1fr); gap: 8px; }
.sdv__producto-btn { display: flex; flex-direction: column; align-items: center; gap: 4px; padding: 10px 4px; border: 1.5px solid var(--c-slate-200); border-radius: 10px; background: var(--c-slate-50); cursor: pointer; font-size: 11px; color: var(--c-slate-500); transition: all .15s; }
.sdv__producto-btn i { font-size: 18px; }
.sdv__producto-btn:hover { border-color: #0369a1; color: #0369a1; background: rgba(3,105,161,.05); }
.sdv__producto-btn--active { border-color: #0369a1; background: rgba(3,105,161,.08); color: #0369a1; font-weight: 600; }
.sdv__prod-unidad { font-size: 10px; color: #9ca3af; }
.sdv__producto-btn--active .sdv__prod-unidad { color: #0369a1; }

.sdv__origen-tabs { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; }
.sdv__origen-tab { display: flex; align-items: center; justify-content: center; gap: 7px; padding: 10px 14px; border: 1.5px solid var(--c-slate-200); border-radius: 10px; background: var(--c-slate-50); cursor: pointer; font-size: 13px; color: var(--c-slate-500); transition: all .15s; font-weight: 500; }
.sdv__origen-tab:hover { border-color: var(--c-slate-400); color: var(--c-slate-900); }
.sdv__origen-tab--active { border-color: #0369a1; background: rgba(3,105,161,.06); color: #0369a1; }

.sdv__lotes-loading { display: flex; align-items: center; gap: 8px; color: var(--c-slate-400); font-size: 13px; }
.sdv__lote-search-wrap { position: relative; }
.sdv__lote-search-icon { position: absolute; left: 12px; top: 50%; transform: translateY(-50%); color: var(--c-slate-400); font-size: 13px; pointer-events: none; }
.sdv__input--search { padding-left: 34px; padding-right: 36px; }
.sdv__lote-clear { position: absolute; right: 10px; top: 50%; transform: translateY(-50%); background: var(--c-slate-100); border: none; width: 22px; height: 22px; border-radius: 50%; cursor: pointer; color: var(--c-slate-500); display: flex; align-items: center; justify-content: center; font-size: 11px; }

.sdv__lotes-list { border: 1.5px solid var(--c-slate-200); border-radius: 10px; overflow: hidden; max-height: 200px; overflow-y: auto; }
.sdv__lotes-empty { padding: 1rem; text-align: center; color: var(--c-slate-400); font-size: 13px; }
.sdv__lote-item { width: 100%; display: flex; align-items: center; justify-content: space-between; gap: 12px; padding: 10px 14px; border: none; border-bottom: 1px solid var(--c-slate-50); background: white; cursor: pointer; text-align: left; transition: background .12s; }
.sdv__lote-item:last-child { border-bottom: none; }
.sdv__lote-item:hover { background: var(--c-slate-50); }
.sdv__lote-item--active { background: rgba(21,128,61,.04); }
.sdv__lote-item-left { flex: 1; min-width: 0; }
.sdv__lote-codigo { font-size: 13px; font-weight: 700; color: var(--c-slate-900); }
.sdv__lote-info { font-size: 11px; color: var(--c-slate-400); margin-top: 2px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.sdv__lote-item-right { display: flex; align-items: center; gap: 8px; flex-shrink: 0; }
.sdv__lote-estado { font-size: 10px; padding: 2px 8px; border-radius: 4px; font-weight: 600; white-space: nowrap; }

.sdv__lote-selected { background: rgba(21,128,61,.05); border: 1.5px solid rgba(21,128,61,.2); border-radius: 10px; padding: 10px 14px; }
.sdv__lote-selected-header { display: flex; align-items: center; gap: 6px; font-size: 11px; font-weight: 700; color: #15803d; text-transform: uppercase; letter-spacing: .05em; margin-bottom: 5px; }
.sdv__lote-selected-remove { margin-left: auto; background: none; border: none; cursor: pointer; color: var(--c-slate-400); font-size: 11px; display: flex; align-items: center; gap: 3px; transition: color .15s; }
.sdv__lote-selected-remove:hover { color: #dc2626; }
.sdv__lote-selected-body { font-size: 13px; color: var(--c-slate-900); }

.sdv__cant-wrap { position: relative; }
.sdv__input { width: 100%; padding: 10px 13px; border: 1.5px solid var(--c-slate-200); border-radius: 9px; font-size: 14px; color: var(--c-slate-900); background: var(--c-slate-50); outline: none; transition: border-color .15s, box-shadow .15s; font-family: inherit; }
.sdv__input:focus { border-color: #0369a1; box-shadow: 0 0 0 3px rgba(3,105,161,.1); }
.sdv__input--big { font-size: 20px; font-weight: 700; padding-right: 52px; letter-spacing: -.02em; }
.sdv__input--mid { padding-left: 2rem; padding-right: 3.5rem; }
.sdv__cant-prefix { position: absolute; left: 12px; top: 50%; transform: translateY(-50%); font-size: 14px; color: #1b5e20; font-weight: 700; pointer-events: none; }
.sdv__cant-suffix { position: absolute; right: 14px; top: 50%; transform: translateY(-50%); font-size: 14px; color: var(--c-slate-400); font-weight: 500; pointer-events: none; }

.sdv__trace-preview { background: #f0fdf4; border: 1.5px solid #bbf7d0; border-radius: 12px; padding: 14px 16px; }
.sdv__trace-preview-header { display: flex; align-items: center; gap: 7px; font-size: 11px; font-weight: 700; color: #15803d; text-transform: uppercase; letter-spacing: .06em; margin-bottom: 10px; }
.sdv__trace-row { display: flex; justify-content: space-between; align-items: flex-start; gap: 12px; padding: 5px 0; border-bottom: 1px solid rgba(21,128,61,.1); }
.sdv__trace-row:last-child { border-bottom: none; }
.sdv__trace-lbl { font-size: 12px; color: #15803d; opacity: .7; white-space: nowrap; }
.sdv__trace-val { font-size: 12px; color: var(--c-slate-900); font-weight: 500; text-align: right; }

/* Modal manicura */
.sdv__manicura-empty { font-size: .82rem; color: var(--c-slate-400); background: var(--c-slate-50); border: 1.5px dashed var(--c-slate-200); border-radius: 10px; padding: 1.25rem; text-align: center; display: flex; flex-direction: column; align-items: center; gap: .5rem; }
.sdv__manicura-lotes { display: grid; grid-template-columns: repeat(auto-fill, minmax(180px, 1fr)); gap: .75rem; }
.sdv__manicura-lote { background: var(--c-slate-50); border: 2px solid var(--c-slate-200); border-radius: 12px; padding: .875rem; text-align: left; cursor: pointer; transition: all .15s; }
.sdv__manicura-lote:hover { border-color: #86efac; background: #f0fdf4; }
.sdv__manicura-lote--active { border-color: #1b5e20; background: #f0fdf4; box-shadow: 0 0 0 3px rgba(27,94,32,.1); }
.sdv__manicura-lote-top { display: flex; align-items: center; justify-content: space-between; gap: .5rem; margin-bottom: .4rem; }
.sdv__manicura-codigo { font-size: .8rem; font-weight: 800; color: var(--c-slate-900); font-family: monospace; }
.sdv__manicura-estado { font-size: .65rem; font-weight: 700; padding: .15em .5em; border-radius: 5px; }
.sdv__manicura-genetica { font-size: .82rem; font-weight: 600; color: #1b5e20; margin-bottom: .25rem; }
.sdv__manicura-sala { font-size: .72rem; color: var(--c-slate-400); display: flex; align-items: center; gap: .3rem; }
.sdv__manicura-confirm { display: flex; align-items: flex-start; gap: .5rem; background: #f0fdf4; border: 1.5px solid #bbf7d0; border-radius: 9px; padding: .75rem; font-size: .8rem; color: #374151; margin-top: .5rem; }

/* Pendientes de aprobación */
.sdv__pending { border: 2px solid #fde68a; border-radius: 14px; background: #fffbeb; margin-bottom: 1.25rem; overflow: hidden; }
.sdv__pending-header { display: flex; align-items: center; gap: .6rem; padding: .875rem 1.1rem; font-size: .82rem; font-weight: 700; color: #92400e; background: #fef3c7; border-bottom: 1px solid #fde68a; }
.sdv__pending-badge { background: #d97706; color: #fff; font-size: .68rem; font-weight: 800; padding: .15em .55em; border-radius: 10px; margin-left: auto; }
.sdv__pending-loading { display: flex; align-items: center; gap: .5rem; padding: 1rem; font-size: .8rem; color: var(--c-slate-400); }
.sdv__pending-list { display: flex; flex-direction: column; }
.sdv__pending-item { display: flex; align-items: center; gap: 1rem; padding: .875rem 1.1rem; border-bottom: 1px solid #fde68a; }
.sdv__pending-item:last-child { border-bottom: none; }
.sdv__pending-info { flex: 1; min-width: 0; }
.sdv__pending-producto { font-size: .875rem; font-weight: 700; color: var(--c-slate-900); display: flex; align-items: center; gap: .5rem; }
.sdv__pending-qty { font-size: .8rem; font-weight: 800; color: #15803d; background: rgba(21,128,61,.1); padding: .15em .5em; border-radius: 6px; }
.sdv__pending-meta { font-size: .72rem; color: #92400e; margin-top: .2rem; }
.sdv__pending-motivo { font-size: .72rem; color: var(--c-slate-500); font-style: italic; margin-top: .15rem; }
.sdv__pending-actions { display: flex; gap: .4rem; flex-shrink: 0; }
.sdv__btn-aprobar { display: inline-flex; align-items: center; gap: .35rem; background: #1b5e20; color: #fff; border: none; padding: .45rem .9rem; border-radius: 8px; font-size: .78rem; font-weight: 700; cursor: pointer; transition: background .15s; white-space: nowrap; }
.sdv__btn-aprobar:hover:not(:disabled) { background: #144a18; }
.sdv__btn-aprobar:disabled { opacity: .5; cursor: not-allowed; }
.sdv__btn-rechazar { width: 32px; height: 32px; border-radius: 8px; border: 1.5px solid #fca5a5; background: #fef2f2; color: #dc2626; display: flex; align-items: center; justify-content: center; cursor: pointer; font-size: .8rem; transition: all .15s; }
.sdv__btn-rechazar:hover:not(:disabled) { background: #dc2626; color: #fff; }
.sdv__btn-rechazar:disabled { opacity: .5; cursor: not-allowed; }

/* Inventory cards — genética y precio */
.sdv__inv-genetica { display: flex; gap: .35rem; flex-wrap: wrap; font-size: .7rem; color: var(--c-slate-500); margin: .15rem 0; }
.sdv__inv-gen-tipo { background: rgba(124,58,237,.1); color: #7c3aed; padding: .1em .4em; border-radius: 4px; text-transform: capitalize; font-size: .65rem; font-weight: 700; }
.sdv__inv-precio { font-size: .75rem; color: #1b5e20; font-weight: 600; margin-top: .15rem; }

/* Modal danger */
.sdv__btn-danger { display: inline-flex; align-items: center; gap: .4rem; background: #b91c1c; color: #fff; border: none; padding: .6rem 1.1rem; border-radius: 9px; font-size: .82rem; font-weight: 600; cursor: pointer; transition: background .15s; }
.sdv__btn-danger:hover:not(:disabled) { background: #991b1b; }
.sdv__btn-danger:disabled { opacity: .5; cursor: not-allowed; }
.sdv__modal--sm { max-width: 420px; }

/* ── Tienda social ───────────────────────────────────────────── */
.sdv__card-title-wrap--btn { background: none; border: none; cursor: pointer; padding: 0; transition: opacity .15s; }
.sdv__card-title-wrap--btn:hover { opacity: .8; }
.sdv__tienda-loading { display: flex; align-items: center; gap: .5rem; padding: 1rem 1.1rem; font-size: .82rem; color: var(--c-slate-400); }
.sdv__tienda-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(160px, 1fr)); gap: .75rem; padding: .875rem 1.1rem; }
.sdv__tienda-card { background: var(--c-slate-50); border: 1.5px solid var(--c-slate-200); border-radius: 12px; padding: .875rem; display: flex; flex-direction: column; gap: .3rem; }
.sdv__tienda-card--link { cursor: pointer; transition: border-color .12s, box-shadow .12s; }
.sdv__tienda-card--link:hover { border-color: #1b5e20; box-shadow: 0 2px 8px rgb(15 23 42 / .06); }
.sdv__tienda-link-ico { color: var(--c-slate-400); font-size: .8rem; }
.sdv__tienda-forma { font-size: .82rem; font-weight: 700; color: var(--c-slate-900); }
.sdv__tienda-gen { font-size: .72rem; color: var(--c-slate-500); }
.sdv__tienda-lote { font-size: .68rem; color: var(--c-slate-400); font-family: monospace; }
.sdv__tienda-qty { font-size: 1.5rem; font-weight: 800; color: var(--c-slate-900); letter-spacing: -.04em; line-height: 1; margin-top: .25rem; }
.sdv__tienda-unit { font-size: .75rem; font-weight: 500; color: var(--c-slate-400); margin-left: .15rem; }
.sdv__tienda-precio { font-size: .75rem; color: #1b5e20; font-weight: 600; }
.sdv__tienda-status { font-size: .68rem; font-weight: 700; padding: .2em .55em; border-radius: 6px; width: fit-content; margin-top: .2rem; }
.sdv__tienda-status--ok { background: #dcfce7; color: #15803d; }
.sdv__tienda-status--empty { background: #fef2f2; color: #dc2626; }
.sdv__tienda-card-top { display: flex; align-items: center; justify-content: space-between; gap: .5rem; }
.sdv__tienda-edit-btn { background: none; border: 1px solid var(--c-slate-200); border-radius: 6px; width: 24px; height: 24px; display: flex; align-items: center; justify-content: center; cursor: pointer; color: var(--c-slate-400); font-size: .72rem; flex-shrink: 0; transition: all .15s; }
.sdv__tienda-edit-btn:hover { border-color: #1b5e20; color: #1b5e20; background: rgba(27,94,32,.05); }

/* ── Nuevo Stock Modal ────────────────────────────────────────── */
.sdv__alert-err { background: #fef2f2; border: 1px solid #fecaca; color: #dc2626; padding: .75rem 1rem; border-radius: 8px; font-size: .85rem; }
.sdv__origen-selector { display: grid; grid-template-columns: 1fr 1fr; gap: .6rem; }
@media (max-width: 480px) { .sdv__origen-selector { grid-template-columns: 1fr; } }
.sdv__origen-btn { display: flex; align-items: center; gap: .75rem; padding: .875rem 1rem; border: 2px solid var(--c-slate-200); border-radius: 12px; background: var(--c-slate-50); cursor: pointer; text-align: left; transition: all .15s; }
.sdv__origen-btn i { font-size: 1.3rem; color: var(--c-slate-400); flex-shrink: 0; }
.sdv__origen-btn div { display: flex; flex-direction: column; gap: .15rem; }
.sdv__origen-btn strong { font-size: .82rem; font-weight: 700; color: var(--c-slate-900); }
.sdv__origen-btn span { font-size: .72rem; color: var(--c-slate-400); }
.sdv__origen-btn:hover { border-color: #1b5e20; }
.sdv__origen-btn--active { border-color: #1b5e20; background: #f0fdf4; }
.sdv__origen-btn--active i { color: #1b5e20; }
.sdv__origen-btn--active strong { color: #1b5e20; }
.sdv__forma-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: .4rem; }
.sdv__forma-btn { padding: .45rem .5rem; border: 1.5px solid var(--c-slate-200); border-radius: 8px; background: var(--c-slate-50); font-size: .72rem; font-weight: 600; cursor: pointer; transition: all .15s; white-space: nowrap; }
.sdv__forma-btn:hover { border-color: #1b5e20; }
.sdv__forma-btn--active { border-color: #1b5e20; background: #f0fdf4; color: #1b5e20; }
.sdv__grid-2 { display: grid; grid-template-columns: 1fr 1fr; gap: .75rem; }
@media (max-width: 480px) { .sdv__grid-2 { grid-template-columns: 1fr; } }
</style>
