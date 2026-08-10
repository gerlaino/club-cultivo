<template>
  <div class="pdv">
    <div class="pdv__toolbar">
      <h1 class="pdv__title">
        Pacientes de la organización
        <span v-if="total" class="pdv__count">{{ total }}</span>
      </h1>
      <div class="pdv__search-wrap">
        <Search :size="16" :stroke-width="1.75" class="pdv__search-ico" />
        <input
          v-model="query"
          class="pdv__search-input"
          type="search"
          placeholder="Buscar por nombre o DNI…"
          autocomplete="off"
        />
      </div>
    </div>

    <div v-if="loading" class="pdv__skel-list">
      <div class="pdv__skel" v-for="n in 6" :key="n" />
    </div>

    <div v-else-if="!pacientes.length && query" class="pdv__empty">
      Ningún paciente coincide con «{{ query }}».
    </div>
    <div v-else-if="!pacientes.length" class="pdv__empty">
      Todavía no hay pacientes cargados.
    </div>

    <ul v-else class="pdv__list">
      <li
        v-for="p in pacientes"
        :key="p.id"
        class="pdv__item"
        @click="abrirDrawer(p)"
      >
        <div class="pdv__item-main">
          <div class="pdv__item-name">{{ p.nombre }} {{ p.apellido }}</div>
          <div class="pdv__item-meta">
            <span class="pdv__dni">{{ p.dni ?? p.numero_documento ?? '—' }}</span>
            <span v-if="p.ultima_dispensacion" class="pdv__ultima">
              última: {{ formatFecha(p.ultima_dispensacion) }}
            </span>
          </div>
        </div>
        <ChevronRight :size="16" :stroke-width="1.75" class="pdv__item-arrow" />
      </li>
    </ul>

    <!-- Drawer -->
    <Teleport to="body">
      <Transition name="drawer-slide">
        <div v-if="drawerOpen" class="pdv__drawer-overlay" @click.self="drawerOpen = false">
          <div class="pdv__drawer">
            <div class="pdv__drawer-header">
              <h2 class="pdv__drawer-name">{{ selected?.nombre }} {{ selected?.apellido }}</h2>
              <button class="pdv__drawer-close" @click="drawerOpen = false">
                <X :size="20" :stroke-width="1.75" />
              </button>
            </div>

            <!-- Datos básicos -->
            <div class="pdv__drawer-section">
              <div class="pdv__drawer-row">
                <span class="pdv__drawer-label">DNI</span>
                <span class="pdv__drawer-value">{{ selected?.dni ?? selected?.numero_documento ?? '—' }}</span>
              </div>
              <div class="pdv__drawer-row">
                <span class="pdv__drawer-label">Teléfono</span>
                <span class="pdv__drawer-value">{{ selected?.telefono || '—' }}</span>
              </div>
              <div class="pdv__drawer-row">
                <span class="pdv__drawer-label">Email</span>
                <span class="pdv__drawer-value">{{ selected?.email || '—' }}</span>
              </div>
            </div>

            <!-- Historial dispensaciones -->
            <div class="pdv__drawer-section">
              <h3 class="pdv__drawer-subtitle">Historial de dispensaciones</h3>
              <div v-if="loadingHistorial" class="pdv__skel-list">
                <div class="pdv__skel" v-for="n in 3" :key="n" />
              </div>
              <div v-else-if="!historial.length" class="pdv__empty pdv__empty--sm">Sin dispensaciones registradas.</div>
              <div v-else class="pdv__historial">
                <div v-for="d in historial" :key="d.id" class="pdv__hist-item">
                  <div class="pdv__hist-fecha">{{ formatFecha(d.fecha_dispensacion) }}</div>
                  <div class="pdv__hist-desc">
                    {{ d.cantidad }}{{ d.stock?.unidad ?? '' }} {{ formaLabel(d.stock?.forma_producto) }}
                  </div>
                  <div class="pdv__hist-monto">{{ formatARS(d.aporte_socio_ars) }}</div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </Transition>
    </Teleport>
  </div>
</template>

<script setup>
import { ref, watch, onMounted } from 'vue'
import { listPacientes, listDispensaciones } from '../lib/api.js'
import { Search, ChevronRight, X } from 'lucide-vue-next'

const query   = ref('')
const loading  = ref(false)
const pacientes = ref([])
const total     = ref(0)

const drawerOpen      = ref(false)
const selected        = ref(null)
const historial       = ref([])
const loadingHistorial = ref(false)

// El listado se carga SOLO, sin pedir que busques primero. El dispensador no siempre sabe cómo se
// escribe el apellido, y una pantalla que arranca vacía lo obliga a adivinar antes de ver nada.
let searchTimeout = null
watch(query, (val) => {
  clearTimeout(searchTimeout)
  searchTimeout = setTimeout(() => buscar(val.trim()), 300)
})

onMounted(() => buscar(''))

async function buscar(q) {
  loading.value = true
  try {
    const params = { limite: 100, orden: 'apellido', dir: 'asc' }
    if (q) params.query = q
    const { data } = await listPacientes(params)
    pacientes.value = data.data ?? []
    total.value     = data.meta?.total ?? pacientes.value.length
  } catch {
    pacientes.value = []
  } finally {
    loading.value = false
  }
}

async function abrirDrawer(p) {
  selected.value = p
  drawerOpen.value = true
  historial.value = []
  loadingHistorial.value = true
  try {
    const { data } = await listDispensaciones(p.id)
    historial.value = data.dispensaciones ?? []
  } catch {
    historial.value = []
  } finally {
    loadingHistorial.value = false
  }
}

function parseDate(d) {
  if (!d) return null
  return typeof d === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(d) ? new Date(d + 'T00:00:00') : new Date(d)
}
function formatFecha(f) {
  if (!f) return '—'
  return parseDate(f).toLocaleDateString('es-AR', { day: '2-digit', month: 'short', year: 'numeric' })
}
function formatARS(n) {
  if (n == null) return '—'
  return new Intl.NumberFormat('es-AR', { style: 'currency', currency: 'ARS', maximumFractionDigits: 0 }).format(n)
}
function formaLabel(f) {
  const L = { flor_seca: 'Flor seca', aceite: 'Aceite', tintura: 'Tintura', crema: 'Crema', capsulas: 'Cápsulas', otro: 'Otro' }
  return L[f] || f || '—'
}
</script>

<style scoped>
.pdv { padding: var(--sp-6) var(--sp-8); }

.pdv__toolbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--sp-4);
  margin-bottom: var(--sp-5);
  flex-wrap: wrap;
}
.pdv__title { font-family: var(--font-display); font-size: var(--fs-20); font-weight: 700; color: var(--c-ink-900); margin: 0; }

.pdv__search-wrap { position: relative; display: flex; align-items: center; }
.pdv__search-ico { position: absolute; left: var(--sp-3); color: var(--c-ink-500); pointer-events: none; }
.pdv__search-input {
  width: 280px;
  padding: .55rem var(--sp-3) .55rem 2.2rem;
  border: 1px solid var(--c-ink-300);
  border-radius: var(--r-md);
  font-size: var(--fs-14);
  color: var(--c-ink-900);
  background: #fff;
  outline: none;
  transition: border-color var(--t-fast);
}
.pdv__search-input:focus { border-color: var(--c-role-dispensador); }

.pdv__list { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: 2px; }
.pdv__item {
  display: flex; align-items: center; gap: var(--sp-3);
  padding: var(--sp-3) var(--sp-4);
  background: #fff;
  border: 1px solid var(--c-ink-300);
  border-radius: var(--r-md);
  cursor: pointer;
  transition: background var(--t-fast), border-color var(--t-fast);
}
.pdv__item:hover { background: var(--c-leaf-50); border-color: var(--c-role-dispensador); }
.pdv__item-main { flex: 1; }
.pdv__item-name { font-size: var(--fs-14); font-weight: 600; color: var(--c-ink-900); }
.pdv__item-meta { display: flex; align-items: center; gap: var(--sp-2); margin-top: 2px; }
.pdv__ultima { font-size: .72rem; color: var(--c-slate-400); }
.pdv__count {
  font-size: .78rem; font-weight: 600; color: var(--c-slate-500);
  background: var(--c-slate-100); padding: .1em .5em; border-radius: 999px; margin-left: .4em;
}
.pdv__dni { font-family: var(--font-mono); font-size: var(--fs-12); color: var(--c-ink-500); }
.pdv__item-arrow { color: var(--c-ink-300); flex-shrink: 0; }

/* REPROCANN badges */
.pdv__reprocann--gray  { background: var(--c-ink-100); color: var(--c-ink-500); }

/* Drawer */
.pdv__drawer-overlay {
  position: fixed; inset: 0;
  background: rgba(0,0,0,.4);
  z-index: 500;
  display: flex; justify-content: flex-end;
}
.pdv__drawer {
  width: 420px;
  max-width: 100%;
  height: 100%;
  background: #fff;
  overflow-y: auto;
  display: flex; flex-direction: column;
  box-shadow: -8px 0 32px rgba(0,0,0,.15);
}
.pdv__drawer-header {
  display: flex; align-items: center; justify-content: space-between;
  padding: var(--sp-5) var(--sp-6);
  border-bottom: 1px solid var(--c-ink-100);
  position: sticky; top: 0; background: #fff; z-index: 1;
}
.pdv__drawer-name { font-size: var(--fs-18); font-weight: 700; color: var(--c-ink-900); margin: 0; }
.pdv__drawer-close {
  background: none; border: none; cursor: pointer; color: var(--c-ink-500);
  display: flex; padding: 4px; border-radius: var(--r-sm);
  transition: color var(--t-fast), background var(--t-fast);
}
.pdv__drawer-close:hover { color: var(--c-ink-900); background: var(--c-ink-100); }

.pdv__drawer-section { padding: var(--sp-5) var(--sp-6); border-bottom: 1px solid var(--c-ink-100); }
.pdv__drawer-subtitle { font-size: var(--fs-13); font-weight: 700; color: var(--c-ink-700); margin: 0 0 var(--sp-3); text-transform: uppercase; letter-spacing: .04em; }
.pdv__drawer-row { display: flex; align-items: center; justify-content: space-between; padding: var(--sp-2) 0; border-bottom: 1px solid var(--c-ink-100); }
.pdv__drawer-row:last-child { border-bottom: none; }
.pdv__drawer-label { font-size: var(--fs-13); color: var(--c-ink-500); }
.pdv__drawer-value { font-size: var(--fs-14); font-weight: 500; color: var(--c-ink-900); }

/* Historial */
.pdv__historial { display: flex; flex-direction: column; gap: var(--sp-2); }
.pdv__hist-item { display: flex; align-items: center; gap: var(--sp-3); padding: var(--sp-2) var(--sp-3); background: var(--c-ink-100); border-radius: var(--r-md); }
.pdv__hist-fecha { font-family: var(--font-mono); font-size: var(--fs-12); color: var(--c-ink-500); flex-shrink: 0; }
.pdv__hist-desc { flex: 1; font-size: var(--fs-13); color: var(--c-ink-900); }
.pdv__hist-monto { font-size: var(--fs-13); font-weight: 600; color: var(--c-role-dispensador); white-space: nowrap; }

.pdv__empty { font-size: var(--fs-14); color: var(--c-ink-500); padding: var(--sp-4) 0; }
.pdv__empty--sm { padding: var(--sp-2) 0; }

.pdv__skel-list { display: flex; flex-direction: column; gap: var(--sp-2); }
.pdv__skel { height: 60px; background: var(--c-ink-100); border-radius: var(--r-md); animation: pulse 1.4s ease-in-out infinite; }
@keyframes pulse { 0%,100%{opacity:1} 50%{opacity:.5} }

/* Drawer transition */
.drawer-slide-enter-active, .drawer-slide-leave-active { transition: opacity .25s, transform .25s; }
.drawer-slide-enter-from, .drawer-slide-leave-to { opacity: 0; }
.drawer-slide-enter-from .pdv__drawer,
.drawer-slide-leave-to  .pdv__drawer { transform: translateX(100%); }

@media (max-width: 767px) {
  .pdv { padding: var(--sp-4); }
  .pdv__search-input { width: 100%; }
}
</style>
