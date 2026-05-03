<script setup>
import { ref, computed, onMounted } from "vue"
import { useRoute, useRouter } from "vue-router"
import { useAuthStore } from "../stores/auth"
import { getSede, listSalas, listLotes,
         getSedeStocks, createStock, deleteSede } from "../lib/api"
import ModalCrearSala from '../components/salas/ModalCrearSala.vue'
import Breadcrumb from '../components/ui/Breadcrumb.vue'
import EmptyState from '../components/ui/EmptyState.vue'
import { useToast } from '../composables/useToast.js'
import { useConfirm } from '../composables/useConfirm.js'

const route  = useRoute()
const router = useRouter()
const auth   = useAuthStore()
const toast  = useToast()
const { confirm } = useConfirm()

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
const isAdmin       = computed(() => auth.user?.role === 'admin')
const canAddStock   = computed(() => ["admin", "cultivador", "manicura"].includes(auth.user?.role))
const esManicurador = computed(() => auth.user?.role === 'manicura')

const tieneInv   = computed(() => ['social', 'mixta'].includes(sede.value?.tipo))
const tieneSalas = computed(() => ['produccion', 'mixta'].includes(sede.value?.tipo))
const stockTotal = computed(() => tiendaStocks.value.reduce((a, s) => a + Number(s.cantidad || 0), 0))
const itemsBajos = computed(() => tiendaStocks.value.filter(s => Number(s.cantidad) < 5).length)


// ── Tienda social (nuevo modelo stocks) ─────────────────────────
const tiendaStocks       = ref([])
const loadingTienda      = ref(false)
const showNuevoStockModal = ref(false)
const savingNuevoStock   = ref(false)
const nuevoStockError    = ref(null)
const nuevoStockForm     = ref({ origen: 'derivado_lote', lote_id: null, lote_origen_consumido_g: null, forma_producto: 'flor_seca', unidad: 'g', cantidad: null, costo_unitario_ars: null, proveedor: '', descripcion: '' })

const FORMA_LABELS = { flor_seca: '🌿 Flor seca', hash: '🟤 Hash', aceite: '🫙 Aceite', tintura: '💧 Tintura', topico: '🧴 Tópico', otro: '📦 Otro' }
const KIND_LABELS = { germinacion: 'Germinación', vegetativo: 'Vegetativo', floracion: 'Floración', cosecha: 'Cosecha', secado: 'Secado', curado: 'Curado', manicura: 'Manicura', mixta: 'Mixta', madre: 'Madre', madres: 'Madres' }
function kindLabel(k) { return KIND_LABELS[k] || k || '' }
const lotesParaStock = ref([])
const loadingLotesStock = ref(false)

async function loadTiendaStocks() {
  loadingTienda.value = true
  try { const { data } = await getSedeStocks(sedeId, { canal: 'regulatorio' }); tiendaStocks.value = data || [] }
  catch { tiendaStocks.value = [] }
  finally { loadingTienda.value = false }
}

async function abrirNuevoStockModal() {
  nuevoStockForm.value = { origen: 'derivado_lote', lote_id: null, lote_origen_consumido_g: null, forma_producto: 'flor_seca', unidad: 'g', cantidad: null, costo_unitario_ars: null, proveedor: '', descripcion: '' }
  nuevoStockError.value = null
  showNuevoStockModal.value = true
  if (!lotesParaStock.value.length) {
    loadingLotesStock.value = true
    try { const { data } = await listLotes({ estado: 'finalizado' }); lotesParaStock.value = data || [] }
    catch { lotesParaStock.value = [] }
    finally { loadingLotesStock.value = false }
  }
}

async function confirmarNuevoStock() {
  savingNuevoStock.value = true; nuevoStockError.value = null
  try {
    const f = nuevoStockForm.value
    const payload = { origen: f.origen, sede_id: sedeId, forma_producto: f.forma_producto, unidad: f.unidad, cantidad: f.cantidad, costo_unitario_ars: f.costo_unitario_ars || undefined }
    if (f.origen === 'derivado_lote') { payload.lote_id = f.lote_id; payload.lote_origen_consumido_g = f.lote_origen_consumido_g }
    else { payload.proveedor = f.proveedor; if (f.descripcion) payload.descripcion = f.descripcion }
    await createStock(payload)
    showNuevoStockModal.value = false
    await loadTiendaStocks()
    toast.success('Stock agregado correctamente')
  } catch (e) {
    nuevoStockError.value = e?.response?.data?.errors?.join(', ') || e?.response?.data?.error || 'Error al agregar stock'
  } finally { savingNuevoStock.value = false }
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
  capacidad: salas.value.reduce((a, s) => a + Number(s.pots_count || s.plants_max || 0), 0),
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

onMounted(async () => {
  try {
    const [sedeRes, salasRes] = await Promise.all([getSede(sedeId), listSalas()])
    sede.value  = sedeRes.data
    salas.value = (salasRes.data || []).filter(s => s.sede?.id === sedeId)
    if (tieneInv.value) await loadTiendaStocks()
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
      <div class="sdv__ring"></div>
      <span>Cargando sede…</span>
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
            <i class="bi bi-plus-lg"></i> Nueva sala aquí
          </button>
          <button v-if="canAddStock && tieneInv" class="sdv__btn-inv" @click="abrirNuevoStockModal">
            <i class="bi bi-plus-lg"></i> Agregar stock
          </button>
          <button v-if="isAdmin" class="sdv__btn-danger" :disabled="deleting" @click="eliminarSede">
            <i class="bi bi-trash3"></i> Eliminar sede
          </button>
          <button class="sdv__btn-ghost" @click="router.back()">
            <i class="bi bi-arrow-left"></i> Volver
          </button>
        </div>
      </div>

      <div v-if="tieneSalas" class="sdv__kpis">
        <div class="sdv__kpi"><div class="sdv__kpi-val">{{ kpis.total }}</div><div class="sdv__kpi-lbl">Salas totales</div></div>
        <div class="sdv__kpi"><div class="sdv__kpi-val" style="color:#15803d">{{ kpis.activas }}</div><div class="sdv__kpi-lbl">Activas</div></div>
        <div class="sdv__kpi"><div class="sdv__kpi-val">{{ kpis.plantas }}</div><div class="sdv__kpi-lbl">Plantas totales</div></div>
        <div class="sdv__kpi"><div class="sdv__kpi-val">{{ kpis.capacidad }}</div><div class="sdv__kpi-lbl">Capacidad total</div></div>
      </div>

      <div v-if="tieneInv" class="sdv__kpis">
        <div class="sdv__kpi"><div class="sdv__kpi-val">{{ tiendaStocks.length }}</div><div class="sdv__kpi-lbl">Productos en stock</div></div>
        <div class="sdv__kpi"><div class="sdv__kpi-val" style="color:#0369a1">{{ stockTotal.toLocaleString('es-AR', { maximumFractionDigits: 1 }) }}g</div><div class="sdv__kpi-lbl">Gramos totales</div></div>
        <div class="sdv__kpi"><div class="sdv__kpi-val" :style="{ color: itemsBajos > 0 ? '#dc2626' : '#15803d' }">{{ itemsBajos }}</div><div class="sdv__kpi-lbl">Stock bajo (&lt;5g)</div></div>
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
              <button v-if="canEdit" class="sdv__card-btn-green" @click="abrirNuevoStockModal">
                <i class="bi bi-plus-lg"></i> Agregar stock
              </button>
            </div>
            <div v-if="loadingTienda" class="sdv__tienda-loading"><div class="sdv__ring sdv__ring--sm"></div> Cargando…</div>
            <EmptyState v-else-if="!tiendaStocks.length" icon="bi-shop" title="Sin stocks" message="No hay stocks disponibles para dispensación." compact>
              <template #actions>
                <button v-if="canEdit" class="sdv__btn-sm-green" @click="abrirNuevoStockModal"><i class="bi bi-plus-lg"></i> Agregar primer stock</button>
              </template>
            </EmptyState>
            <div v-else class="sdv__tienda-grid">
              <div v-for="s in tiendaStocks" :key="s.id" class="sdv__tienda-card">
                <div class="sdv__tienda-forma">{{ FORMA_LABELS[s.forma_producto] || s.forma_producto }}</div>
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
                    <span v-if="s.pots_count || s.plants_max"><i class="bi bi-box-seam"></i> cap. {{ s.pots_count ?? s.plants_max }}</span>
                    <span v-if="s.lotes_count !== undefined"><i class="bi bi-collection"></i> {{ s.lotes_count }} lotes</span>
                  </div>
                </div>
                <div v-if="s.pots_count || s.plants_max" class="sdv__sala-ocupacion">
                  <div class="sdv__ocu-pct" :style="{ color: ocupacionColor(s.porcentaje_ocupacion || 0) }">{{ (s.porcentaje_ocupacion || 0).toFixed(0) }}%</div>
                  <div class="sdv__ocu-bar"><div class="sdv__ocu-fill" :style="{ width: Math.min(s.porcentaje_ocupacion || 0, 100) + '%', background: ocupacionColor(s.porcentaje_ocupacion || 0) }"></div></div>
                  <div class="sdv__ocu-label">ocupación</div>
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

    <!-- MODAL NUEVO STOCK (nuevo modelo) -->
    <Teleport to="body">
      <div v-if="showNuevoStockModal" class="sdv__modal-overlay" @click.self="showNuevoStockModal = false">
        <div class="sdv__modal">
          <div class="sdv__modal-header">
            <div class="sdv__modal-header-icon" style="background:rgba(27,94,32,.1);color:#1b5e20"><i class="bi bi-shop"></i></div>
            <div>
              <h3 class="sdv__modal-title">Agregar stock</h3>
              <p class="sdv__modal-sub">{{ sede?.nombre }}</p>
            </div>
            <button class="sdv__modal-close" @click="showNuevoStockModal = false"><i class="bi bi-x-lg"></i></button>
          </div>
          <div class="sdv__modal-body">
            <div v-if="nuevoStockError" class="sdv__alert-err">{{ nuevoStockError }}</div>

            <!-- Modo origen -->
            <div class="sdv__field" style="margin-bottom:1.25rem">
              <label class="sdv__label">Origen del stock</label>
              <div class="sdv__origen-selector">
                <button type="button" class="sdv__origen-btn" :class="{ 'sdv__origen-btn--active': nuevoStockForm.origen === 'derivado_lote' }" @click="nuevoStockForm.origen = 'derivado_lote'">
                  <i class="bi bi-flower1"></i>
                  <div><strong>Derivado de lote</strong><span>Stock generado desde un lote propio</span></div>
                </button>
                <button type="button" class="sdv__origen-btn" :class="{ 'sdv__origen-btn--active': nuevoStockForm.origen === 'compra_externa' }" @click="nuevoStockForm.origen = 'compra_externa'">
                  <i class="bi bi-bag"></i>
                  <div><strong>Compra externa</strong><span>Stock adquirido de proveedor externo</span></div>
                </button>
              </div>
            </div>

            <!-- Lote selector (derivado_lote) -->
            <div v-if="nuevoStockForm.origen === 'derivado_lote'" class="sdv__field" style="margin-bottom:1rem">
              <label class="sdv__label">Lote origen</label>
              <div v-if="loadingLotesStock" class="sdv__tienda-loading"><div class="sdv__ring sdv__ring--sm"></div> Cargando lotes…</div>
              <select v-else class="sdv__input" v-model="nuevoStockForm.lote_id">
                <option :value="null" disabled>Seleccioná un lote…</option>
                <option v-for="l in lotesParaStock" :key="l.id" :value="l.id">{{ l.codigo }} — {{ l.genetica?.nombre || 'Sin genética' }}</option>
              </select>
              <div class="sdv__field" style="margin-top:.75rem">
                <label class="sdv__label">Gramos consumidos del lote <span class="sdv__optional">opcional</span></label>
                <input type="number" step="0.1" min="0" class="sdv__input" v-model.number="nuevoStockForm.lote_origen_consumido_g" placeholder="ej: 320.0" />
              </div>
            </div>

            <!-- Proveedor/desc (compra_externa) -->
            <template v-if="nuevoStockForm.origen === 'compra_externa'">
              <div class="sdv__field" style="margin-bottom:.75rem">
                <label class="sdv__label">Proveedor <span style="color:#dc2626">*</span></label>
                <input type="text" class="sdv__input" v-model.trim="nuevoStockForm.proveedor" placeholder="Nombre del proveedor" />
              </div>
              <div class="sdv__field" style="margin-bottom:1rem">
                <label class="sdv__label">Descripción <span class="sdv__optional">opcional</span></label>
                <input type="text" class="sdv__input" v-model.trim="nuevoStockForm.descripcion" placeholder="Ej: Aceite CBD 10mg/ml" />
              </div>
            </template>

            <!-- Forma producto -->
            <div class="sdv__field" style="margin-bottom:1rem">
              <label class="sdv__label">Forma de producto</label>
              <div class="sdv__forma-grid">
                <button v-for="(label, key) in FORMA_LABELS" :key="key" type="button" class="sdv__forma-btn"
                        :class="{ 'sdv__forma-btn--active': nuevoStockForm.forma_producto === key }"
                        @click="nuevoStockForm.forma_producto = key">{{ label }}</button>
              </div>
            </div>

            <!-- Cantidad + precios -->
            <div class="sdv__grid-2" style="margin-bottom:.75rem">
              <div class="sdv__field">
                <label class="sdv__label">Cantidad <span style="color:#dc2626">*</span></label>
                <div class="sdv__cant-wrap">
                  <input type="number" step="0.1" min="0" class="sdv__input sdv__input--big" v-model.number="nuevoStockForm.cantidad" placeholder="0" />
                  <span class="sdv__cant-suffix">{{ nuevoStockForm.unidad }}</span>
                </div>
              </div>
              <div class="sdv__field">
                <label class="sdv__label">Unidad</label>
                <select class="sdv__input" v-model="nuevoStockForm.unidad">
                  <option value="g">g (gramos)</option>
                  <option value="ml">ml (mililitros)</option>
                  <option value="u">u (unidades)</option>
                </select>
              </div>
            </div>
            <div class="sdv__grid-2">
              <div class="sdv__field">
                <label class="sdv__label">Costo unitario (ARS) <span class="sdv__optional">opcional</span></label>
                <input type="number" step="0.01" min="0" class="sdv__input" v-model.number="nuevoStockForm.costo_unitario_ars" placeholder="ej: 1200" />
              </div>
            </div>
          </div>
          <div class="sdv__modal-footer">
            <button class="sdv__btn-ghost" :disabled="savingNuevoStock" @click="showNuevoStockModal = false">Cancelar</button>
            <button class="sdv__btn-primary" :disabled="savingNuevoStock || !nuevoStockForm.cantidad" @click="confirmarNuevoStock">
              <span v-if="savingNuevoStock" class="sdv__ring sdv__ring--sm sdv__ring--white"></span>
              <i v-else class="bi bi-check-lg"></i>
              Guardar stock
            </button>
          </div>
        </div>
      </div>
    </Teleport>

  </div>
</template>

<style scoped>
/* ══ ORIGINALES ══════════════════════════════════════════════════ */
.sdv { padding: 1.75rem 1.75rem 3rem; max-width: 1200px; margin: 0 auto; }
@media (max-width: 768px) { .sdv { padding: 1.25rem 1rem 2rem; } }
.sdv__loading { display: flex; align-items: center; justify-content: center; gap: .75rem; padding: 5rem; color: #94a3b8; }
.sdv__ring { width: 22px; height: 22px; border: 2px solid #e2e8f0; border-top-color: #1b5e20; border-radius: 50%; animation: sdv-spin .7s linear infinite; }
.sdv__ring--sm { width: 14px; height: 14px; border-width: 1.5px; }
.sdv__ring--white { border-color: rgba(255,255,255,.3); border-top-color: white; }
@keyframes sdv-spin { to { transform: rotate(360deg); } }
.sdv__error { background: #fef2f2; border: 1px solid #fecaca; color: #dc2626; padding: 1rem; border-radius: 10px; display: flex; gap: .5rem; align-items: center; }
.sdv__header { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; margin-bottom: 1.75rem; flex-wrap: wrap; }
.sdv__header-left { display: flex; align-items: flex-start; gap: 1rem; }
.sdv__tipo-icon { width: 52px; height: 52px; border-radius: 14px; display: flex; align-items: center; justify-content: center; font-size: 1.3rem; flex-shrink: 0; }
.sdv__title-row { display: flex; align-items: center; gap: .6rem; flex-wrap: wrap; margin-bottom: .25rem; }
.sdv__title { font-size: 1.75rem; font-weight: 800; color: #0f172a; margin: 0; letter-spacing: -.03em; }
.sdv__tipo-badge { font-size: .72rem; font-weight: 700; padding: .2em .65em; border-radius: 6px; }
.sdv__tipo-badge--sm { font-size: .72rem; font-weight: 700; padding: .2em .55em; border-radius: 5px; }
.sdv__reprocann-badge { display: inline-flex; align-items: center; gap: .3rem; font-size: .72rem; font-weight: 700; background: #dcfce7; color: #15803d; padding: .2em .6em; border-radius: 6px; }
.sdv__subtitle { font-size: .83rem; color: #64748b; margin: 0; display: flex; align-items: center; gap: .35rem; }
.sdv__header-actions { display: flex; gap: .6rem; flex-wrap: wrap; align-items: center; }
.sdv__kpis { display: grid; grid-template-columns: repeat(4, 1fr); gap: 1rem; margin-bottom: 1.75rem; }
@media (max-width: 640px) { .sdv__kpis { grid-template-columns: repeat(2, 1fr); } }
.sdv__kpi { background: #fff; border: 1px solid #e2e8f0; border-radius: 12px; padding: 1.1rem 1rem; text-align: center; }
.sdv__kpi-val { font-size: 2rem; font-weight: 800; color: #0f172a; line-height: 1; letter-spacing: -.04em; }
.sdv__kpi-lbl { font-size: .72rem; font-weight: 600; color: #94a3b8; text-transform: uppercase; letter-spacing: .04em; margin-top: .35rem; }
.sdv__layout { display: grid; grid-template-columns: 1fr 280px; gap: 1.25rem; align-items: start; }
@media (max-width: 900px) { .sdv__layout { grid-template-columns: 1fr; } }
.sdv__col-side { display: flex; flex-direction: column; position: sticky; top: 1.5rem; }
.sdv__card--mt { margin-top: 1.25rem; }
.sdv__card--mb { margin-bottom: 1.25rem; }
.sdv__card { background: #fff; border: 1px solid #e2e8f0; border-radius: 14px; overflow: hidden; }
.sdv__card-header { display: flex; align-items: center; justify-content: space-between; padding: .875rem 1.1rem; border-bottom: 1px solid #f1f5f9; background: #fafbfc; }
.sdv__card-title-wrap { display: flex; align-items: center; gap: .6rem; }
.sdv__card-icon { width: 30px; height: 30px; border-radius: 7px; display: flex; align-items: center; justify-content: center; font-size: .8rem; flex-shrink: 0; }
.sdv__card-title { font-size: .875rem; font-weight: 700; color: #0f172a; }
.sdv__card-btn { font-size: .78rem; font-weight: 600; color: #0369a1; background: none; border: none; cursor: pointer; padding: 0; text-decoration: none; }
.sdv__card-btn:hover { text-decoration: underline; }
.sdv__card-btn-green { display: inline-flex; align-items: center; gap: 5px; font-size: .78rem; font-weight: 600; color: #15803d; background: rgba(21,128,61,.08); border: 1px solid rgba(21,128,61,.2); padding: .25rem .7rem; border-radius: 6px; cursor: pointer; transition: background .15s; }
.sdv__card-btn-green:hover { background: rgba(21,128,61,.14); }
.sdv__pill { font-size: .65rem; font-weight: 800; background: #f1f5f9; color: #475569; padding: .15em .5em; border-radius: 999px; }
.sdv__salas { display: flex; flex-direction: column; }
.sdv__sala { display: flex; align-items: center; gap: .875rem; padding: .875rem 1.1rem; border-bottom: 1px solid #f8fafc; text-decoration: none; color: inherit; transition: background .12s; }
.sdv__sala:last-child { border-bottom: none; }
.sdv__sala:hover { background: #fafbfc; }
.sdv__sala-state { width: 3px; height: 40px; border-radius: 999px; flex-shrink: 0; }
.sdv__sala-body { flex: 1; min-width: 0; }
.sdv__sala-header { display: flex; align-items: center; gap: .5rem; flex-wrap: wrap; margin-bottom: .25rem; }
.sdv__sala-nombre { font-size: .9rem; font-weight: 700; color: #0f172a; }
.sdv__sala-badges { display: flex; gap: .35rem; }
.sdv__state-badge { font-size: .68rem; font-weight: 700; padding: .2em .5em; border-radius: 5px; }
.sdv__kind-badge { font-size: .68rem; font-weight: 600; background: #f1f5f9; color: #64748b; padding: .2em .5em; border-radius: 5px; text-transform: capitalize; }
.sdv__sala-meta { display: flex; gap: .75rem; font-size: .75rem; color: #94a3b8; flex-wrap: wrap; }
.sdv__sala-meta i { margin-right: .2rem; }
.sdv__sala-ocupacion { display: flex; flex-direction: column; align-items: flex-end; gap: .2rem; min-width: 70px; flex-shrink: 0; }
.sdv__ocu-pct { font-size: .78rem; font-weight: 700; }
.sdv__ocu-bar { width: 70px; height: 4px; background: #f1f5f9; border-radius: 999px; overflow: hidden; }
.sdv__ocu-fill { height: 100%; border-radius: 999px; transition: width .4s; }
.sdv__ocu-label { font-size: .62rem; color: #94a3b8; }
.sdv__sala-arrow { color: #cbd5e1; font-size: .85rem; flex-shrink: 0; transition: color .15s, transform .15s; }
.sdv__sala:hover .sdv__sala-arrow { color: #0f172a; transform: translateX(2px); }
.sdv__dl { display: grid; grid-template-columns: 100px 1fr; gap: .4rem .5rem; padding: 1rem 1.1rem; margin: 0; }
.sdv__dl dt { font-size: .75rem; color: #94a3b8; font-weight: 500; display: flex; align-items: center; }
.sdv__dl dd { font-size: .82rem; color: #0f172a; font-weight: 500; margin: 0; display: flex; align-items: center; }
.sdv__notas { padding: .875rem 1.1rem; font-size: .85rem; color: #475569; margin: 0; line-height: 1.6; }
.sdv__btn-primary { display: inline-flex; align-items: center; gap: .4rem; background: var(--brand-primary, #1b5e20); color: #fff; border: none; padding: .6rem 1.1rem; border-radius: 8px; font-size: .875rem; font-weight: 700; cursor: pointer; text-decoration: none; transition: background .15s, transform .1s; white-space: nowrap; }
.sdv__btn-primary:hover { background: #144a18; transform: translateY(-1px); }
.sdv__btn-primary:disabled { opacity: .55; cursor: not-allowed; transform: none; }
.sdv__btn-ghost { display: inline-flex; align-items: center; gap: .4rem; background: #fff; color: #64748b; border: 1.5px solid #e2e8f0; padding: .6rem 1rem; border-radius: 8px; font-size: .875rem; font-weight: 600; cursor: pointer; transition: all .15s; white-space: nowrap; }
.sdv__btn-ghost:hover { background: #f8fafc; color: #0f172a; }
.sdv__btn-sm-green { display: inline-flex; align-items: center; gap: .35rem; background: rgba(27,94,32,.08); color: #1b5e20; border: 1.5px solid rgba(27,94,32,.2); padding: .45rem .875rem; border-radius: 7px; font-size: .8rem; font-weight: 600; cursor: pointer; transition: all .15s; }
.sdv__btn-sm-green:hover { background: rgba(27,94,32,.14); }

/* ══ NUEVO ═══════════════════════════════════════════════════════ */
.sdv__btn-inv { display: inline-flex; align-items: center; gap: .4rem; background: rgba(3,105,161,.08); color: #0369a1; border: 1.5px solid rgba(3,105,161,.2); padding: .6rem 1rem; border-radius: 8px; font-size: .875rem; font-weight: 600; cursor: pointer; transition: all .15s; white-space: nowrap; }
.sdv__btn-inv:hover { background: rgba(3,105,161,.14); }

.sdv__inv-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(190px, 1fr)); gap: 12px; padding: 16px; }
.sdv__inv-card { background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 12px; padding: 14px; display: flex; flex-direction: column; gap: 6px; transition: box-shadow .15s; }
.sdv__inv-card:hover { box-shadow: 0 2px 12px rgba(0,0,0,.08); }
.sdv__inv-card--low { border-color: #fecaca; background: #fff5f5; }
.sdv__inv-card__top { display: flex; justify-content: space-between; align-items: center; }
.sdv__inv-icon { width: 30px; height: 30px; border-radius: 7px; background: rgba(3,105,161,.08); color: #0369a1; display: flex; align-items: center; justify-content: center; font-size: 14px; flex-shrink: 0; }
.sdv__inv-badge { font-size: 10px; padding: 2px 7px; border-radius: 4px; font-weight: 600; display: inline-flex; align-items: center; gap: 3px; }
.sdv__inv-badge--ok { background: #dcfce7; color: #15803d; }
.sdv__inv-badge--warn { background: #fef2f2; color: #dc2626; }
.sdv__inv-producto { font-size: 13px; font-weight: 600; color: #1e293b; }
.sdv__inv-stock { font-size: 22px; font-weight: 800; color: #0369a1; line-height: 1; letter-spacing: -.02em; }
.sdv__inv-unit { font-size: 13px; font-weight: 400; color: #94a3b8; }
.sdv__inv-lote { background: rgba(3,105,161,.04); border: 1px solid rgba(3,105,161,.12); border-radius: 7px; padding: 7px 9px; }
.sdv__inv-lote--ext { display: flex; align-items: center; gap: 5px; color: #94a3b8; font-size: 11px; background: #f8fafc; border-color: #e2e8f0; }
.sdv__inv-lote-header { display: flex; align-items: center; gap: 4px; font-size: 10px; color: #0369a1; font-weight: 700; text-transform: uppercase; letter-spacing: .05em; margin-bottom: 3px; }
.sdv__inv-lote-codigo { font-size: 12px; font-weight: 700; color: #0f172a; }
.sdv__inv-lote-meta { font-size: 11px; color: #64748b; margin-bottom: 4px; }
.sdv__inv-lote-estado { display: inline-block; font-size: 10px; padding: 1px 7px; border-radius: 4px; font-weight: 600; }
.sdv__inv-bar-wrap { height: 4px; background: #e2e8f0; border-radius: 2px; overflow: hidden; }
.sdv__inv-bar { height: 100%; border-radius: 2px; transition: width .3s; }
.sdv__inv-bar--ok { background: #15803d; }
.sdv__inv-bar--low { background: #dc2626; }
.sdv__inv-meta { display: flex; justify-content: space-between; font-size: 11px; color: #94a3b8; }

.sdv__modal-overlay { position: fixed; inset: 0; background: rgba(0,0,0,.5); backdrop-filter: blur(8px); display: flex; align-items: center; justify-content: center; z-index: 1000; padding: 1rem; }
.sdv__modal { background: white; border-radius: 20px; width: 100%; max-width: 560px; max-height: 92vh; overflow-y: auto; box-shadow: 0 24px 80px rgba(0,0,0,.2); }
.sdv__modal-header { display: flex; align-items: center; gap: 12px; padding: 20px 24px 18px; border-bottom: 1px solid #f1f5f9; position: sticky; top: 0; background: white; z-index: 1; border-radius: 20px 20px 0 0; }
.sdv__modal-header-icon { width: 40px; height: 40px; border-radius: 10px; background: rgba(3,105,161,.1); color: #0369a1; display: flex; align-items: center; justify-content: center; font-size: 17px; flex-shrink: 0; }
.sdv__modal-title { font-size: 17px; font-weight: 700; color: #0f172a; margin: 0 0 2px; }
.sdv__modal-sub { font-size: 13px; color: #64748b; margin: 0; }
.sdv__modal-close { margin-left: auto; background: #f1f5f9; border: none; width: 32px; height: 32px; border-radius: 8px; cursor: pointer; color: #64748b; display: flex; align-items: center; justify-content: center; font-size: 13px; transition: all .15s; flex-shrink: 0; }
.sdv__modal-close:hover { background: #e2e8f0; color: #0f172a; }
.sdv__modal-body { padding: 20px 24px; display: flex; flex-direction: column; gap: 20px; }
.sdv__modal-footer { padding: 14px 24px; border-top: 1px solid #f1f5f9; display: flex; justify-content: flex-end; gap: 10px; position: sticky; bottom: 0; background: white; border-radius: 0 0 20px 20px; }

.sdv__field { display: flex; flex-direction: column; gap: 8px; }
.sdv__label { font-size: 13px; font-weight: 600; color: #374151; display: flex; align-items: center; gap: 7px; flex-wrap: wrap; }
.sdv__label-num { width: 20px; height: 20px; border-radius: 50%; background: #0f172a; color: white; font-size: 11px; font-weight: 700; display: inline-flex; align-items: center; justify-content: center; flex-shrink: 0; }
.sdv__optional { font-weight: 400; color: #9ca3af; font-size: 12px; }
.sdv__unidad-pill { background: #f0fdf4; border: 1px solid #bbf7d0; color: #15803d; font-size: 11px; padding: 1px 8px; border-radius: 4px; font-weight: 500; }

.sdv__producto-grid { display: grid; grid-template-columns: repeat(5, 1fr); gap: 8px; }
.sdv__producto-btn { display: flex; flex-direction: column; align-items: center; gap: 4px; padding: 10px 4px; border: 1.5px solid #e2e8f0; border-radius: 10px; background: #f8fafc; cursor: pointer; font-size: 11px; color: #64748b; transition: all .15s; }
.sdv__producto-btn i { font-size: 18px; }
.sdv__producto-btn:hover { border-color: #0369a1; color: #0369a1; background: rgba(3,105,161,.05); }
.sdv__producto-btn--active { border-color: #0369a1; background: rgba(3,105,161,.08); color: #0369a1; font-weight: 600; }
.sdv__prod-unidad { font-size: 10px; color: #9ca3af; }
.sdv__producto-btn--active .sdv__prod-unidad { color: #0369a1; }

.sdv__origen-tabs { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; }
.sdv__origen-tab { display: flex; align-items: center; justify-content: center; gap: 7px; padding: 10px 14px; border: 1.5px solid #e2e8f0; border-radius: 10px; background: #f8fafc; cursor: pointer; font-size: 13px; color: #64748b; transition: all .15s; font-weight: 500; }
.sdv__origen-tab:hover { border-color: #94a3b8; color: #0f172a; }
.sdv__origen-tab--active { border-color: #0369a1; background: rgba(3,105,161,.06); color: #0369a1; }

.sdv__lotes-loading { display: flex; align-items: center; gap: 8px; color: #94a3b8; font-size: 13px; }
.sdv__lote-search-wrap { position: relative; }
.sdv__lote-search-icon { position: absolute; left: 12px; top: 50%; transform: translateY(-50%); color: #94a3b8; font-size: 13px; pointer-events: none; }
.sdv__input--search { padding-left: 34px; padding-right: 36px; }
.sdv__lote-clear { position: absolute; right: 10px; top: 50%; transform: translateY(-50%); background: #f1f5f9; border: none; width: 22px; height: 22px; border-radius: 50%; cursor: pointer; color: #64748b; display: flex; align-items: center; justify-content: center; font-size: 11px; }

.sdv__lotes-list { border: 1.5px solid #e2e8f0; border-radius: 10px; overflow: hidden; max-height: 200px; overflow-y: auto; }
.sdv__lotes-empty { padding: 1rem; text-align: center; color: #94a3b8; font-size: 13px; }
.sdv__lote-item { width: 100%; display: flex; align-items: center; justify-content: space-between; gap: 12px; padding: 10px 14px; border: none; border-bottom: 1px solid #f8fafc; background: white; cursor: pointer; text-align: left; transition: background .12s; }
.sdv__lote-item:last-child { border-bottom: none; }
.sdv__lote-item:hover { background: #f8fafc; }
.sdv__lote-item--active { background: rgba(21,128,61,.04); }
.sdv__lote-item-left { flex: 1; min-width: 0; }
.sdv__lote-codigo { font-size: 13px; font-weight: 700; color: #0f172a; }
.sdv__lote-info { font-size: 11px; color: #94a3b8; margin-top: 2px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.sdv__lote-item-right { display: flex; align-items: center; gap: 8px; flex-shrink: 0; }
.sdv__lote-estado { font-size: 10px; padding: 2px 8px; border-radius: 4px; font-weight: 600; white-space: nowrap; }

.sdv__lote-selected { background: rgba(21,128,61,.05); border: 1.5px solid rgba(21,128,61,.2); border-radius: 10px; padding: 10px 14px; }
.sdv__lote-selected-header { display: flex; align-items: center; gap: 6px; font-size: 11px; font-weight: 700; color: #15803d; text-transform: uppercase; letter-spacing: .05em; margin-bottom: 5px; }
.sdv__lote-selected-remove { margin-left: auto; background: none; border: none; cursor: pointer; color: #94a3b8; font-size: 11px; display: flex; align-items: center; gap: 3px; transition: color .15s; }
.sdv__lote-selected-remove:hover { color: #dc2626; }
.sdv__lote-selected-body { font-size: 13px; color: #0f172a; }

.sdv__cant-wrap { position: relative; }
.sdv__input { width: 100%; padding: 10px 13px; border: 1.5px solid #e2e8f0; border-radius: 9px; font-size: 14px; color: #0f172a; background: #f8fafc; outline: none; transition: border-color .15s, box-shadow .15s; font-family: inherit; }
.sdv__input:focus { border-color: #0369a1; box-shadow: 0 0 0 3px rgba(3,105,161,.1); }
.sdv__input--big { font-size: 20px; font-weight: 700; padding-right: 52px; letter-spacing: -.02em; }
.sdv__input--mid { padding-left: 2rem; padding-right: 3.5rem; }
.sdv__cant-prefix { position: absolute; left: 12px; top: 50%; transform: translateY(-50%); font-size: 14px; color: #1b5e20; font-weight: 700; pointer-events: none; }
.sdv__cant-suffix { position: absolute; right: 14px; top: 50%; transform: translateY(-50%); font-size: 14px; color: #94a3b8; font-weight: 500; pointer-events: none; }

.sdv__trace-preview { background: #f0fdf4; border: 1.5px solid #bbf7d0; border-radius: 12px; padding: 14px 16px; }
.sdv__trace-preview-header { display: flex; align-items: center; gap: 7px; font-size: 11px; font-weight: 700; color: #15803d; text-transform: uppercase; letter-spacing: .06em; margin-bottom: 10px; }
.sdv__trace-row { display: flex; justify-content: space-between; align-items: flex-start; gap: 12px; padding: 5px 0; border-bottom: 1px solid rgba(21,128,61,.1); }
.sdv__trace-row:last-child { border-bottom: none; }
.sdv__trace-lbl { font-size: 12px; color: #15803d; opacity: .7; white-space: nowrap; }
.sdv__trace-val { font-size: 12px; color: #0f172a; font-weight: 500; text-align: right; }

/* Modal manicura */
.sdv__manicura-empty { font-size: .82rem; color: #94a3b8; background: #f8fafc; border: 1.5px dashed #e2e8f0; border-radius: 10px; padding: 1.25rem; text-align: center; display: flex; flex-direction: column; align-items: center; gap: .5rem; }
.sdv__manicura-lotes { display: grid; grid-template-columns: repeat(auto-fill, minmax(180px, 1fr)); gap: .75rem; }
.sdv__manicura-lote { background: #f8fafc; border: 2px solid #e2e8f0; border-radius: 12px; padding: .875rem; text-align: left; cursor: pointer; transition: all .15s; }
.sdv__manicura-lote:hover { border-color: #86efac; background: #f0fdf4; }
.sdv__manicura-lote--active { border-color: #1b5e20; background: #f0fdf4; box-shadow: 0 0 0 3px rgba(27,94,32,.1); }
.sdv__manicura-lote-top { display: flex; align-items: center; justify-content: space-between; gap: .5rem; margin-bottom: .4rem; }
.sdv__manicura-codigo { font-size: .8rem; font-weight: 800; color: #0f172a; font-family: monospace; }
.sdv__manicura-estado { font-size: .65rem; font-weight: 700; padding: .15em .5em; border-radius: 5px; }
.sdv__manicura-genetica { font-size: .82rem; font-weight: 600; color: #1b5e20; margin-bottom: .25rem; }
.sdv__manicura-sala { font-size: .72rem; color: #94a3b8; display: flex; align-items: center; gap: .3rem; }
.sdv__manicura-confirm { display: flex; align-items: flex-start; gap: .5rem; background: #f0fdf4; border: 1.5px solid #bbf7d0; border-radius: 9px; padding: .75rem; font-size: .8rem; color: #374151; margin-top: .5rem; }

/* Pendientes de aprobación */
.sdv__pending { border: 2px solid #fde68a; border-radius: 14px; background: #fffbeb; margin-bottom: 1.25rem; overflow: hidden; }
.sdv__pending-header { display: flex; align-items: center; gap: .6rem; padding: .875rem 1.1rem; font-size: .82rem; font-weight: 700; color: #92400e; background: #fef3c7; border-bottom: 1px solid #fde68a; }
.sdv__pending-badge { background: #d97706; color: #fff; font-size: .68rem; font-weight: 800; padding: .15em .55em; border-radius: 10px; margin-left: auto; }
.sdv__pending-loading { display: flex; align-items: center; gap: .5rem; padding: 1rem; font-size: .8rem; color: #94a3b8; }
.sdv__pending-list { display: flex; flex-direction: column; }
.sdv__pending-item { display: flex; align-items: center; gap: 1rem; padding: .875rem 1.1rem; border-bottom: 1px solid #fde68a; }
.sdv__pending-item:last-child { border-bottom: none; }
.sdv__pending-info { flex: 1; min-width: 0; }
.sdv__pending-producto { font-size: .875rem; font-weight: 700; color: #0f172a; display: flex; align-items: center; gap: .5rem; }
.sdv__pending-qty { font-size: .8rem; font-weight: 800; color: #15803d; background: rgba(21,128,61,.1); padding: .15em .5em; border-radius: 6px; }
.sdv__pending-meta { font-size: .72rem; color: #92400e; margin-top: .2rem; }
.sdv__pending-motivo { font-size: .72rem; color: #64748b; font-style: italic; margin-top: .15rem; }
.sdv__pending-actions { display: flex; gap: .4rem; flex-shrink: 0; }
.sdv__btn-aprobar { display: inline-flex; align-items: center; gap: .35rem; background: #1b5e20; color: #fff; border: none; padding: .45rem .9rem; border-radius: 8px; font-size: .78rem; font-weight: 700; cursor: pointer; transition: background .15s; white-space: nowrap; }
.sdv__btn-aprobar:hover:not(:disabled) { background: #144a18; }
.sdv__btn-aprobar:disabled { opacity: .5; cursor: not-allowed; }
.sdv__btn-rechazar { width: 32px; height: 32px; border-radius: 8px; border: 1.5px solid #fca5a5; background: #fef2f2; color: #dc2626; display: flex; align-items: center; justify-content: center; cursor: pointer; font-size: .8rem; transition: all .15s; }
.sdv__btn-rechazar:hover:not(:disabled) { background: #dc2626; color: #fff; }
.sdv__btn-rechazar:disabled { opacity: .5; cursor: not-allowed; }

/* Inventory cards — genética y precio */
.sdv__inv-genetica { display: flex; gap: .35rem; flex-wrap: wrap; font-size: .7rem; color: #64748b; margin: .15rem 0; }
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
.sdv__tienda-loading { display: flex; align-items: center; gap: .5rem; padding: 1rem 1.1rem; font-size: .82rem; color: #94a3b8; }
.sdv__tienda-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(160px, 1fr)); gap: .75rem; padding: .875rem 1.1rem; }
.sdv__tienda-card { background: #f8fafc; border: 1.5px solid #e2e8f0; border-radius: 12px; padding: .875rem; display: flex; flex-direction: column; gap: .3rem; }
.sdv__tienda-forma { font-size: .82rem; font-weight: 700; color: #0f172a; }
.sdv__tienda-gen { font-size: .72rem; color: #64748b; }
.sdv__tienda-lote { font-size: .68rem; color: #94a3b8; font-family: monospace; }
.sdv__tienda-qty { font-size: 1.5rem; font-weight: 800; color: #0f172a; letter-spacing: -.04em; line-height: 1; margin-top: .25rem; }
.sdv__tienda-unit { font-size: .75rem; font-weight: 500; color: #94a3b8; margin-left: .15rem; }
.sdv__tienda-precio { font-size: .75rem; color: #1b5e20; font-weight: 600; }
.sdv__tienda-status { font-size: .68rem; font-weight: 700; padding: .2em .55em; border-radius: 6px; width: fit-content; margin-top: .2rem; }
.sdv__tienda-status--ok { background: #dcfce7; color: #15803d; }
.sdv__tienda-status--empty { background: #fef2f2; color: #dc2626; }

/* ── Nuevo Stock Modal ────────────────────────────────────────── */
.sdv__alert-err { background: #fef2f2; border: 1px solid #fecaca; color: #dc2626; padding: .75rem 1rem; border-radius: 8px; font-size: .85rem; }
.sdv__origen-selector { display: grid; grid-template-columns: 1fr 1fr; gap: .6rem; }
@media (max-width: 480px) { .sdv__origen-selector { grid-template-columns: 1fr; } }
.sdv__origen-btn { display: flex; align-items: center; gap: .75rem; padding: .875rem 1rem; border: 2px solid #e2e8f0; border-radius: 12px; background: #f8fafc; cursor: pointer; text-align: left; transition: all .15s; }
.sdv__origen-btn i { font-size: 1.3rem; color: #94a3b8; flex-shrink: 0; }
.sdv__origen-btn div { display: flex; flex-direction: column; gap: .15rem; }
.sdv__origen-btn strong { font-size: .82rem; font-weight: 700; color: #0f172a; }
.sdv__origen-btn span { font-size: .72rem; color: #94a3b8; }
.sdv__origen-btn:hover { border-color: #1b5e20; }
.sdv__origen-btn--active { border-color: #1b5e20; background: #f0fdf4; }
.sdv__origen-btn--active i { color: #1b5e20; }
.sdv__origen-btn--active strong { color: #1b5e20; }
.sdv__forma-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: .4rem; }
.sdv__forma-btn { padding: .45rem .5rem; border: 1.5px solid #e2e8f0; border-radius: 8px; background: #f8fafc; font-size: .72rem; font-weight: 600; cursor: pointer; transition: all .15s; white-space: nowrap; }
.sdv__forma-btn:hover { border-color: #1b5e20; }
.sdv__forma-btn--active { border-color: #1b5e20; background: #f0fdf4; color: #1b5e20; }
.sdv__grid-2 { display: grid; grid-template-columns: 1fr 1fr; gap: .75rem; }
@media (max-width: 480px) { .sdv__grid-2 { grid-template-columns: 1fr; } }
</style>
