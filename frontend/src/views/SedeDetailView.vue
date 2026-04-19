<script setup>
import { ref, computed, onMounted } from "vue"
import { useRoute, useRouter } from "vue-router"
import { useAuthStore } from "../stores/auth"
import { getSede, listSalas, getSedeInventario, agregarStock, listLotes } from "../lib/api"
import ModalCrearSala from '../components/salas/ModalCrearSala.vue'

const route  = useRoute()
const router = useRouter()
const auth   = useAuthStore()

const sedeId        = Number(route.params.id)
const sede          = ref(null)
const salas         = ref([])
const loading       = ref(true)
const error         = ref(null)
const showCrearSala = ref(false)

const canEdit = computed(() => ["admin", "agricultor"].includes(auth.role))

// ── Inventario ──────────────────────────────────────────────────
const inventario     = ref([])
const loadingInv     = ref(false)
const showStockModal = ref(false)
const savingStock    = ref(false)
const lotes          = ref([])
const loadingLotes   = ref(false)
const loteSearch     = ref('')

const stockForm = ref({
  producto: 'flores',
  cantidad: null,
  lote_id:  null,
  origen:   'lote',
  motivo:   '',
})

const PRODUCTOS = [
  { value: 'flores',   label: 'Flores',   unidad: 'g',  step: 0.1, icon: 'bi-flower2'    },
  { value: 'aceite',   label: 'Aceite',   unidad: 'ml', step: 0.1, icon: 'bi-droplet'    },
  { value: 'extracto', label: 'Extracto', unidad: 'ml', step: 0.1, icon: 'bi-eyedropper' },
  { value: 'crema',    label: 'Crema',    unidad: 'g',  step: 1,   icon: 'bi-jar'        },
  { value: 'otro',     label: 'Otro',     unidad: 'g',  step: 0.1, icon: 'bi-box-seam'   },
]

const ESTADOS_LOTE = {
  semilla:    { label: 'Semilla',    color: '#92400e', bg: 'rgba(146,64,14,.1)'  },
  vegetativo: { label: 'Vegetativo', color: '#15803d', bg: 'rgba(21,128,61,.1)'  },
  floracion:  { label: 'Floración',  color: '#7c3aed', bg: 'rgba(124,58,237,.1)' },
  cosecha:    { label: 'Cosecha',    color: '#b45309', bg: 'rgba(180,83,9,.1)'   },
  curado:     { label: 'Curado',     color: '#0369a1', bg: 'rgba(3,105,161,.1)'  },
  finalizado: { label: 'Finalizado', color: '#475569', bg: 'rgba(71,85,105,.1)'  },
}

const productoActual  = computed(() => PRODUCTOS.find(p => p.value === stockForm.value.producto) || PRODUCTOS[0])
const loteSeleccionado = computed(() => lotes.value.find(l => l.id === stockForm.value.lote_id) || null)
const tieneInv        = computed(() => ['social', 'mixta'].includes(sede.value?.tipo))
const tieneSalas      = computed(() => ['produccion', 'mixta'].includes(sede.value?.tipo))
const stockTotal      = computed(() => inventario.value.reduce((a, i) => a + Number(i.stock_gramos || 0), 0))
const itemsBajos      = computed(() => inventario.value.filter(i => i.stock_bajo).length)

const lotesFiltrados = computed(() => {
  const q = loteSearch.value.toLowerCase().trim()
  const lista = q
    ? lotes.value.filter(l =>
      l.codigo?.toLowerCase().includes(q) ||
      l.strain?.toLowerCase().includes(q) ||
      l.genetica?.nombre?.toLowerCase().includes(q) ||
      l.sala?.nombre?.toLowerCase().includes(q)
    )
    : lotes.value
  return lista.slice(0, 8)
})

function estadoLote(estado) { return ESTADOS_LOTE[estado] || ESTADOS_LOTE.finalizado }
function productoIcon(producto) { return PRODUCTOS.find(p => p.value === producto)?.icon || 'bi-box-seam' }

async function cargarInventario() {
  loadingInv.value = true
  try {
    const { data } = await getSedeInventario(sedeId)
    inventario.value = data
  } catch (e) { console.error(e) }
  finally { loadingInv.value = false }
}

async function abrirStock() {
  stockForm.value = { producto: 'flores', cantidad: null, lote_id: null, origen: 'lote', motivo: '' }
  loteSearch.value = ''
  showStockModal.value = true
  loadingLotes.value = true
  try {
    const { data } = await listLotes()
    const order = { cosecha: 0, curado: 1, finalizado: 2, floracion: 3, vegetativo: 4, semilla: 5 }
    lotes.value = data.sort((a, b) => (order[a.estado] ?? 9) - (order[b.estado] ?? 9))
  } catch (e) { console.error(e) }
  finally { loadingLotes.value = false }
}

async function confirmarStock() {
  if (!stockForm.value.cantidad || stockForm.value.cantidad <= 0) return
  savingStock.value = true
  try {
    const payload = {
      producto: stockForm.value.producto,
      cantidad: stockForm.value.cantidad,
      motivo: stockForm.value.origen === 'lote' && loteSeleccionado.value
        ? `Cosecha lote ${loteSeleccionado.value.codigo}`
        : (stockForm.value.motivo || 'Ingreso externo'),
    }
    if (stockForm.value.origen === 'lote' && stockForm.value.lote_id) {
      payload.lote_id = stockForm.value.lote_id
    }
    await agregarStock(sedeId, payload)
    showStockModal.value = false
    await cargarInventario()
  } catch (e) { console.error(e) }
  finally { savingStock.value = false }
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
    if (tieneInv.value) await cargarInventario()
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

      <div class="sdv__breadcrumb">
        <RouterLink :to="{ name: 'sedes' }" class="sdv__breadcrumb-link">Sedes</RouterLink>
        <i class="bi bi-chevron-right sdv__breadcrumb-sep"></i>
        <span>{{ sede.nombre }}</span>
      </div>

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
          <button v-if="canEdit && tieneSalas" class="sdv__btn-primary" @click="showCrearSala = true">
            <i class="bi bi-plus-lg"></i> Nueva sala aquí
          </button>
          <button v-if="canEdit && tieneInv" class="sdv__btn-inv" @click="abrirStock">
            <i class="bi bi-plus-lg"></i> Agregar stock
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
        <div class="sdv__kpi"><div class="sdv__kpi-val">{{ inventario.length }}</div><div class="sdv__kpi-lbl">Productos en stock</div></div>
        <div class="sdv__kpi"><div class="sdv__kpi-val" style="color:#0369a1">{{ stockTotal.toLocaleString('es-AR', { maximumFractionDigits: 1 }) }}g</div><div class="sdv__kpi-lbl">Gramos totales</div></div>
        <div class="sdv__kpi"><div class="sdv__kpi-val" :style="{ color: itemsBajos > 0 ? '#dc2626' : '#15803d' }">{{ itemsBajos }}</div><div class="sdv__kpi-lbl">Stock bajo</div></div>
      </div>

      <div class="sdv__layout">
        <div class="sdv__col-main">

          <!-- INVENTARIO -->
          <div v-if="tieneInv" class="sdv__card" :class="{ 'sdv__card--mb': tieneSalas }">
            <div class="sdv__card-header">
              <div class="sdv__card-title-wrap">
                <span class="sdv__card-icon" style="background:rgba(3,105,161,.1);color:#0369a1"><i class="bi bi-box-seam"></i></span>
                <span class="sdv__card-title">Inventario de stock</span>
                <span class="sdv__pill">{{ inventario.length }}</span>
              </div>
              <button v-if="canEdit" class="sdv__card-btn-green" @click="abrirStock">
                <i class="bi bi-plus-lg"></i> Agregar
              </button>
            </div>

            <div v-if="loadingInv" class="sdv__empty"><div class="sdv__ring"></div></div>

            <div v-else-if="!inventario.length" class="sdv__empty">
              <i class="bi bi-box-seam sdv__empty-icon"></i>
              <p>Sin stock registrado en esta sede.</p>
              <button v-if="canEdit" class="sdv__btn-sm-green" @click="abrirStock">
                <i class="bi bi-plus-lg"></i> Registrar primer ingreso
              </button>
            </div>

            <div v-else class="sdv__inv-grid">
              <div v-for="item in inventario" :key="item.id" class="sdv__inv-card" :class="{ 'sdv__inv-card--low': item.stock_bajo }">
                <div class="sdv__inv-card__top">
                  <div class="sdv__inv-icon"><i :class="['bi', productoIcon(item.producto)]"></i></div>
                  <span class="sdv__inv-badge" :class="item.stock_bajo ? 'sdv__inv-badge--warn' : 'sdv__inv-badge--ok'">
                    <i :class="item.stock_bajo ? 'bi bi-exclamation-triangle-fill' : 'bi bi-check-circle-fill'"></i>
                    {{ item.stock_bajo ? 'Stock bajo' : 'OK' }}
                  </span>
                </div>
                <div class="sdv__inv-producto">{{ item.producto_label }}</div>
                <div class="sdv__inv-stock">
                  {{ Number(item.stock_gramos).toLocaleString('es-AR', { maximumFractionDigits: 1 }) }}
                  <span class="sdv__inv-unit">g</span>
                </div>
                <!-- Trazabilidad -->
                <div v-if="item.lote" class="sdv__inv-lote">
                  <div class="sdv__inv-lote-header"><i class="bi bi-diagram-3"></i> Origen</div>
                  <div class="sdv__inv-lote-codigo">{{ item.lote.codigo }}</div>
                  <div class="sdv__inv-lote-meta">
                    <span v-if="item.lote.genetica">{{ item.lote.genetica }}</span>
                    <span v-if="item.lote.sala"> · {{ item.lote.sala }}</span>
                  </div>
                  <span class="sdv__inv-lote-estado" :style="{ background: estadoLote(item.lote.estado).bg, color: estadoLote(item.lote.estado).color }">
                    {{ estadoLote(item.lote.estado).label }}
                  </span>
                </div>
                <div v-else class="sdv__inv-lote sdv__inv-lote--ext">
                  <i class="bi bi-box-arrow-in-down"></i> Ingreso externo
                </div>
                <div v-if="item.stock_minimo" class="sdv__inv-bar-wrap">
                  <div class="sdv__inv-bar" :class="item.stock_bajo ? 'sdv__inv-bar--low' : 'sdv__inv-bar--ok'" :style="{ width: `${Math.min(100, (item.stock_gramos / item.stock_minimo) * 50)}%` }"></div>
                </div>
                <div class="sdv__inv-meta">
                  <span v-if="item.stock_minimo">Mín: {{ item.stock_minimo }}g</span>
                  <span>{{ new Date(item.updated_at).toLocaleDateString('es-AR', { day:'numeric', month:'short' }) }}</span>
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
            <div v-if="!salas.length" class="sdv__empty">
              <i class="bi bi-building-slash sdv__empty-icon"></i>
              <p>Esta sede no tiene salas asignadas todavía.</p>
              <button v-if="canEdit" class="sdv__btn-sm-green" @click="showCrearSala = true">Crear primera sala</button>
            </div>
            <div v-else class="sdv__salas">
              <RouterLink v-for="s in salas" :key="s.id" :to="{ name: 'sala-detail', params: { id: s.id } }" class="sdv__sala">
                <div class="sdv__sala-state" :style="{ background: s.state === 'activa' ? '#15803d' : s.state === 'mantenimiento' ? '#f59e0b' : '#94a3b8' }"></div>
                <div class="sdv__sala-body">
                  <div class="sdv__sala-header">
                    <span class="sdv__sala-nombre">{{ s.nombre }}</span>
                    <div class="sdv__sala-badges">
                      <span class="sdv__state-badge" :style="s.state === 'activa' ? 'background:#dcfce7;color:#15803d' : s.state === 'mantenimiento' ? 'background:#fffbeb;color:#b45309' : 'background:#f1f5f9;color:#64748b'">{{ s.state }}</span>
                      <span v-if="s.kind" class="sdv__kind-badge">{{ s.kind }}</span>
                    </div>
                  </div>
                  <div class="sdv__sala-meta">
                    <span><i class="bi bi-flower1"></i> {{ s.plantas_totales ?? 0 }} plantas</span>
                    <span><i class="bi bi-box-seam"></i> cap. {{ s.pots_count ?? s.plants_max ?? 0 }}</span>
                    <span v-if="s.lotes_count !== undefined"><i class="bi bi-collection"></i> {{ s.lotes_count }} lotes</span>
                  </div>
                </div>
                <div class="sdv__sala-ocupacion">
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

    <!-- MODAL STOCK -->
    <Teleport to="body">
      <div v-if="showStockModal" class="sdv__modal-overlay" @click.self="showStockModal = false">
        <div class="sdv__modal">

          <div class="sdv__modal-header">
            <div class="sdv__modal-header-icon"><i class="bi bi-box-seam"></i></div>
            <div>
              <h3 class="sdv__modal-title">Agregar stock</h3>
              <p class="sdv__modal-sub">{{ sede?.nombre }}</p>
            </div>
            <button class="sdv__modal-close" @click="showStockModal = false"><i class="bi bi-x-lg"></i></button>
          </div>

          <div class="sdv__modal-body">

            <!-- 1. Producto -->
            <div class="sdv__field">
              <label class="sdv__label"><span class="sdv__label-num">1</span> Tipo de producto</label>
              <div class="sdv__producto-grid">
                <button v-for="p in PRODUCTOS" :key="p.value" type="button" class="sdv__producto-btn"
                        :class="{ 'sdv__producto-btn--active': stockForm.producto === p.value }"
                        @click="stockForm.producto = p.value; stockForm.cantidad = null">
                  <i :class="['bi', p.icon]"></i>
                  <span>{{ p.label }}</span>
                  <span class="sdv__prod-unidad">{{ p.unidad }}</span>
                </button>
              </div>
            </div>

            <!-- 2. Origen -->
            <div class="sdv__field">
              <label class="sdv__label"><span class="sdv__label-num">2</span> Origen del stock</label>
              <div class="sdv__origen-tabs">
                <button class="sdv__origen-tab" :class="{ 'sdv__origen-tab--active': stockForm.origen === 'lote' }"
                        @click="stockForm.origen = 'lote'; stockForm.lote_id = null">
                  <i class="bi bi-diagram-3"></i> Desde lote propio
                </button>
                <button class="sdv__origen-tab" :class="{ 'sdv__origen-tab--active': stockForm.origen === 'externo' }"
                        @click="stockForm.origen = 'externo'; stockForm.lote_id = null">
                  <i class="bi bi-box-arrow-in-down"></i> Ingreso externo
                </button>
              </div>
            </div>

            <!-- 3a. Selector lote -->
            <div v-if="stockForm.origen === 'lote'" class="sdv__field">
              <label class="sdv__label">
                <span class="sdv__label-num">3</span> Seleccionar lote
                <span class="sdv__optional">(opcional — mejora trazabilidad)</span>
              </label>
              <div v-if="loadingLotes" class="sdv__lotes-loading">
                <div class="sdv__ring sdv__ring--sm"></div><span>Cargando lotes…</span>
              </div>
              <template v-else>
                <div class="sdv__lote-search-wrap">
                  <i class="bi bi-search sdv__lote-search-icon"></i>
                  <input v-model="loteSearch" class="sdv__input sdv__input--search" placeholder="Buscar por código, genética, sala…" />
                  <button v-if="stockForm.lote_id" class="sdv__lote-clear" @click="stockForm.lote_id = null; loteSearch = ''">
                    <i class="bi bi-x"></i>
                  </button>
                </div>
                <div class="sdv__lotes-list">
                  <div v-if="!lotesFiltrados.length" class="sdv__lotes-empty">Sin resultados</div>
                  <button v-for="lote in lotesFiltrados" :key="lote.id" type="button"
                          class="sdv__lote-item" :class="{ 'sdv__lote-item--active': stockForm.lote_id === lote.id }"
                          @click="stockForm.lote_id = lote.id; loteSearch = ''">
                    <div class="sdv__lote-item-left">
                      <div class="sdv__lote-codigo">{{ lote.codigo }}</div>
                      <div class="sdv__lote-info">
                        <span v-if="lote.genetica">{{ lote.genetica.nombre }}</span>
                        <span v-if="lote.sala"> · {{ lote.sala.nombre }}</span>
                        <span v-if="lote.plants_count"> · {{ lote.plants_count }} plantas</span>
                      </div>
                    </div>
                    <div class="sdv__lote-item-right">
                      <span class="sdv__lote-estado" :style="{ background: estadoLote(lote.estado).bg, color: estadoLote(lote.estado).color }">
                        {{ estadoLote(lote.estado).label }}
                      </span>
                      <i v-if="stockForm.lote_id === lote.id" class="bi bi-check-circle-fill" style="color:#15803d;font-size:14px"></i>
                    </div>
                  </button>
                </div>
                <div v-if="loteSeleccionado" class="sdv__lote-selected">
                  <div class="sdv__lote-selected-header">
                    <i class="bi bi-link-45deg"></i> Lote vinculado
                    <button class="sdv__lote-selected-remove" @click="stockForm.lote_id = null">
                      <i class="bi bi-x"></i> Quitar
                    </button>
                  </div>
                  <div class="sdv__lote-selected-body">
                    <strong>{{ loteSeleccionado.codigo }}</strong>
                    <span v-if="loteSeleccionado.genetica"> · {{ loteSeleccionado.genetica.nombre }}</span>
                    <span v-if="loteSeleccionado.sala"> · {{ loteSeleccionado.sala.nombre }}</span>
                  </div>
                </div>
              </template>
            </div>

            <!-- 3b. Motivo externo -->
            <div v-else class="sdv__field">
              <label class="sdv__label"><span class="sdv__label-num">3</span> Descripción del origen</label>
              <input v-model.trim="stockForm.motivo" class="sdv__input" placeholder="Ej: Compra a proveedor, donación, transferencia…" />
            </div>

            <!-- 4. Cantidad -->
            <div class="sdv__field">
              <label class="sdv__label">
                <span class="sdv__label-num">4</span> Cantidad a ingresar
                <span class="sdv__unidad-pill">{{ productoActual.unidad }}</span>
              </label>
              <div class="sdv__cant-wrap">
                <input v-model.number="stockForm.cantidad" type="number" :step="productoActual.step" min="0.1"
                       class="sdv__input sdv__input--big" placeholder="0" />
                <span class="sdv__cant-suffix">{{ productoActual.unidad }}</span>
              </div>
            </div>

            <!-- Preview trazabilidad -->
            <div v-if="stockForm.cantidad > 0" class="sdv__trace-preview">
              <div class="sdv__trace-preview-header">
                <i class="bi bi-check-circle-fill"></i> Resumen del ingreso
              </div>
              <div class="sdv__trace-row">
                <span class="sdv__trace-lbl">Producto</span>
                <span class="sdv__trace-val">{{ productoActual.label }}</span>
              </div>
              <div class="sdv__trace-row">
                <span class="sdv__trace-lbl">Cantidad</span>
                <span class="sdv__trace-val" style="color:#0369a1;font-weight:700">{{ stockForm.cantidad }} {{ productoActual.unidad }}</span>
              </div>
              <div class="sdv__trace-row">
                <span class="sdv__trace-lbl">Destino</span>
                <span class="sdv__trace-val">{{ sede?.nombre }}</span>
              </div>
              <div class="sdv__trace-row">
                <span class="sdv__trace-lbl">Origen</span>
                <span class="sdv__trace-val">
                  <template v-if="stockForm.origen === 'lote' && loteSeleccionado">
                    Lote <strong>{{ loteSeleccionado.codigo }}</strong>
                    <span v-if="loteSeleccionado.genetica"> · {{ loteSeleccionado.genetica.nombre }}</span>
                  </template>
                  <template v-else-if="stockForm.origen === 'lote'">Lote propio (sin vincular)</template>
                  <template v-else>{{ stockForm.motivo || 'Ingreso externo' }}</template>
                </span>
              </div>
            </div>

          </div>

          <div class="sdv__modal-footer">
            <button class="sdv__btn-ghost" :disabled="savingStock" @click="showStockModal = false">Cancelar</button>
            <button class="sdv__btn-primary" :disabled="savingStock || !stockForm.cantidad || stockForm.cantidad <= 0" @click="confirmarStock">
              <span v-if="savingStock" class="sdv__ring sdv__ring--sm sdv__ring--white"></span>
              <i v-else class="bi bi-check-lg"></i>
              Confirmar ingreso
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
.sdv__breadcrumb { display: flex; align-items: center; gap: .4rem; font-size: .8rem; color: #94a3b8; margin-bottom: 1.25rem; }
.sdv__breadcrumb-link { color: #0369a1; text-decoration: none; font-weight: 600; }
.sdv__breadcrumb-link:hover { text-decoration: underline; }
.sdv__breadcrumb-sep { font-size: .65rem; }
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
.sdv__empty { text-align: center; padding: 3rem 1rem; color: #94a3b8; }
.sdv__empty-icon { font-size: 2.5rem; display: block; margin-bottom: .75rem; opacity: .4; }
.sdv__empty p { font-size: .875rem; margin: 0 0 .75rem; }
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
.sdv__cant-suffix { position: absolute; right: 14px; top: 50%; transform: translateY(-50%); font-size: 14px; color: #94a3b8; font-weight: 500; pointer-events: none; }

.sdv__trace-preview { background: #f0fdf4; border: 1.5px solid #bbf7d0; border-radius: 12px; padding: 14px 16px; }
.sdv__trace-preview-header { display: flex; align-items: center; gap: 7px; font-size: 11px; font-weight: 700; color: #15803d; text-transform: uppercase; letter-spacing: .06em; margin-bottom: 10px; }
.sdv__trace-row { display: flex; justify-content: space-between; align-items: flex-start; gap: 12px; padding: 5px 0; border-bottom: 1px solid rgba(21,128,61,.1); }
.sdv__trace-row:last-child { border-bottom: none; }
.sdv__trace-lbl { font-size: 12px; color: #15803d; opacity: .7; white-space: nowrap; }
.sdv__trace-val { font-size: 12px; color: #0f172a; font-weight: 500; text-align: right; }
</style>
