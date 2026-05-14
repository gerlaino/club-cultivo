<template>
  <div class="stk">

    <!-- Header -->
    <div class="stk__header">
      <div>
        <h1 class="stk__title">Stock</h1>
        <p class="stk__sub">Inventario del club · asignación de sedes · stock externo</p>
      </div>
      <button class="stk__btn-primary" @click="openCrear">
        <i class="bi bi-plus-lg"></i> Agregar stock externo
      </button>
    </div>

    <div v-if="loading" class="stk__loading">
      <div class="stk__ring"></div> Cargando…
    </div>

    <template v-else>

      <!-- KPIs -->
      <div class="stk__kpis">
        <div class="stk__kpi">
          <div class="stk__kpi-ico">📦</div>
          <div class="stk__kpi-body">
            <div class="stk__kpi-val">{{ totalG }}<span class="stk__kpi-unit">g</span></div>
            <div class="stk__kpi-lbl">Total disponible</div>
          </div>
        </div>
        <div class="stk__kpi" :class="{ 'stk__kpi--warn': pendientes.length > 0 }">
          <div class="stk__kpi-ico">⏳</div>
          <div class="stk__kpi-body">
            <div class="stk__kpi-val">{{ pendientes.length }}</div>
            <div class="stk__kpi-lbl">Pendientes asignación</div>
          </div>
        </div>
        <div class="stk__kpi">
          <div class="stk__kpi-ico">🏪</div>
          <div class="stk__kpi-body">
            <div class="stk__kpi-val">{{ sedesConStock.length }}</div>
            <div class="stk__kpi-lbl">Sedes con stock</div>
          </div>
        </div>
        <div class="stk__kpi">
          <div class="stk__kpi-ico">🌿</div>
          <div class="stk__kpi-body">
            <div class="stk__kpi-val">{{ stockPropio }}<span class="stk__kpi-unit">g</span></div>
            <div class="stk__kpi-lbl">Producción propia</div>
          </div>
        </div>
      </div>

      <!-- Tabs -->
      <div class="stk__tabs">
        <button
          v-for="tab in TABS" :key="tab.key"
          class="stk__tab"
          :class="{ 'stk__tab--active': tabActiva === tab.key }"
          @click="tabActiva = tab.key"
        >
          {{ tab.label }}
          <span v-if="tab.count > 0" class="stk__tab-count"
            :class="tab.key === 'pendientes' && tab.count > 0 ? 'stk__tab-count--warn' : ''">
            {{ tab.count }}
          </span>
        </button>
      </div>

      <!-- Tab: Pendientes -->
      <div v-if="tabActiva === 'pendientes'">
        <div v-if="!pendientes.length" class="stk__empty">
          <span class="stk__empty-ico">✅</span>
          <p class="stk__empty-title">Todo asignado</p>
          <span class="stk__empty-sub">No hay stock pendiente de asignación a sede.</span>
        </div>
        <div v-else class="stk__list">
          <div v-for="s in pendientes" :key="s.id" class="stk__item">
            <div class="stk__item-left">
              <div class="stk__item-forma">{{ formaLabel(s.forma_producto) }}</div>
              <div class="stk__item-chips">
                <span class="stk__chip stk__chip--g">{{ s.cantidad }}g</span>
                <span v-if="s.lote" class="stk__chip stk__chip--lote">{{ s.lote.codigo }}</span>
                <span v-if="s.lote?.genetica" class="stk__chip stk__chip--gen">{{ s.lote.genetica.nombre }}</span>
                <span v-if="s.origen === 'compra_externa'" class="stk__chip stk__chip--ext">Externo</span>
              </div>
            </div>
            <div class="stk__item-right">
              <select v-model="asignaciones[s.id]" class="stk__select">
                <option value="">Pool del club</option>
                <option v-for="sede in sedes" :key="sede.id" :value="sede.id">{{ sede.nombre }}</option>
              </select>
              <button class="stk__btn-primary stk__btn-sm" :disabled="asignando === s.id" @click="asignar(s)">
                <div v-if="asignando === s.id" class="stk__spinner stk__spinner--sm"></div>
                <i v-else class="bi bi-check-lg"></i>
                Asignar
              </button>
            </div>
          </div>
        </div>
      </div>

      <!-- Tab: Inventario -->
      <div v-if="tabActiva === 'inventario'">
        <div v-if="!inventario.length" class="stk__empty">
          <span class="stk__empty-ico">📭</span>
          <p class="stk__empty-title">Sin stock asignado</p>
          <span class="stk__empty-sub">
            Cuando se apruebe una cosecha o cargues stock externo aparecerá aquí.
          </span>
          <button class="stk__btn-outline stk__empty-cta" @click="openCrear">
            <i class="bi bi-plus-lg"></i> Agregar stock externo
          </button>
        </div>
        <template v-else>
          <!-- Filtro forma -->
          <div class="stk__filters">
            <button
              v-for="f in filtrosForma" :key="f.value"
              class="stk__chip-btn"
              :class="{ 'stk__chip-btn--active': filtroForma === f.value }"
              @click="filtroForma = f.value"
            >{{ f.label }}</button>
          </div>

          <!-- Agrupado por sede -->
          <div v-for="grupo in inventarioAgrupado" :key="grupo.sede_nombre" class="stk__grupo">
            <div class="stk__grupo-header">
              <span class="stk__grupo-nombre">🏪 {{ grupo.sede_nombre }}</span>
              <span class="stk__grupo-total">{{ grupo.total }}g</span>
            </div>
            <div class="stk__inv-list">
              <div v-for="s in grupo.items" :key="s.id" class="stk__inv-item">
                <div class="stk__inv-left">
                  <span class="stk__inv-forma">{{ formaLabel(s.forma_producto) }}</span>
                  <div class="stk__inv-chips">
                    <span v-if="s.lote" class="stk__chip stk__chip--lote">{{ s.lote.codigo }}</span>
                    <span v-if="s.lote?.genetica" class="stk__chip stk__chip--gen">{{ s.lote.genetica.nombre }}</span>
                    <span v-if="s.origen === 'compra_externa'" class="stk__chip stk__chip--ext">Externo</span>
                    <span v-if="s.proveedor" class="stk__chip">{{ s.proveedor }}</span>
                  </div>
                </div>
                <div class="stk__inv-right">
                  <span class="stk__inv-g">{{ s.cantidad }}g</span>
                  <RouterLink
                    v-if="s.codigo_qr"
                    :to="`/s/${s.codigo_qr}`"
                    class="stk__icon-btn"
                    title="Ver QR"
                  ><i class="bi bi-qr-code"></i></RouterLink>
                </div>
              </div>
            </div>
          </div>
        </template>
      </div>

    </template>

    <!-- Modal crear stock externo -->
    <Teleport to="body">
      <Transition name="stk-fade">
        <div v-if="showCrear" class="stk__overlay" @click.self="closeCrear">
          <div class="stk__modal">
            <div class="stk__modal-hd">
              <div class="stk__modal-ico"><i class="bi bi-box-seam"></i></div>
              <div>
                <h2 class="stk__modal-title">Nuevo stock externo</h2>
                <p class="stk__modal-sub">Stock adquirido fuera del ciclo de cultivo propio</p>
              </div>
              <button class="stk__modal-close" @click="closeCrear"><i class="bi bi-x-lg"></i></button>
            </div>

            <form class="stk__modal-body" @submit.prevent="guardarStock">
              <div v-if="crearError" class="stk__alert">{{ crearError }}</div>

              <div class="stk__form-grid">
                <div class="stk__field stk__field--full">
                  <label class="stk__label">Forma del producto <span class="stk__req">*</span></label>
                  <select class="stk__input" v-model="crearForm.forma_producto" required>
                    <option v-for="f in FORMAS" :key="f.value" :value="f.value">{{ f.label }}</option>
                  </select>
                </div>

                <div class="stk__field">
                  <label class="stk__label">Cantidad (g) <span class="stk__req">*</span></label>
                  <div class="stk__input-row">
                    <input type="number" min="0.1" step="0.1" class="stk__input" v-model="crearForm.cantidad" placeholder="0.0" required />
                    <span class="stk__input-suf">g</span>
                  </div>
                </div>

                <div class="stk__field">
                  <label class="stk__label">Sede destino <span class="stk__opt">opcional</span></label>
                  <select class="stk__input" v-model="crearForm.sede_id">
                    <option value="">Pool del club</option>
                    <option v-for="s in sedes" :key="s.id" :value="s.id">{{ s.nombre }}</option>
                  </select>
                </div>

                <div class="stk__field">
                  <label class="stk__label">Genética <span class="stk__opt">opcional</span></label>
                  <select class="stk__input" v-model="crearForm.genetica_id">
                    <option value="">Sin especificar</option>
                    <option v-for="g in geneticas" :key="g.id" :value="g.id">{{ g.nombre }}</option>
                  </select>
                </div>

                <div class="stk__field">
                  <label class="stk__label">Precio sugerido (ARS/g) <span class="stk__opt">opcional</span></label>
                  <input type="number" min="0" step="0.01" class="stk__input" v-model="crearForm.precio_sugerido_ars" placeholder="0.00" />
                </div>

                <div class="stk__field">
                  <label class="stk__label">Costo unitario (ARS/g) <span class="stk__opt">opcional</span></label>
                  <input type="number" min="0" step="0.01" class="stk__input" v-model="crearForm.costo_unitario_ars" placeholder="0.00" />
                </div>

                <div class="stk__field stk__field--full">
                  <label class="stk__label">Proveedor <span class="stk__req">*</span></label>
                  <input type="text" class="stk__input" v-model="crearForm.proveedor" placeholder="Nombre del proveedor o productor" required />
                </div>

                <div class="stk__field stk__field--full">
                  <label class="stk__label">Notas <span class="stk__opt">opcional</span></label>
                  <textarea class="stk__input stk__textarea" rows="2" v-model="crearForm.descripcion" placeholder="Observaciones…"></textarea>
                </div>
              </div>
            </form>

            <div class="stk__modal-ft">
              <button type="button" class="stk__btn-ghost" @click="closeCrear">Cancelar</button>
              <button class="stk__btn-primary" :disabled="creando || !crearForm.cantidad" @click="guardarStock">
                <div v-if="creando" class="stk__spinner stk__spinner--sm stk__spinner--white"></div>
                <i v-else class="bi bi-plus-lg"></i>
                Crear stock
              </button>
            </div>
          </div>
        </div>
      </Transition>
    </Teleport>

  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { listStocksPendientes, listStocks, asignarStock, listSedes, createStock, listGeneticas } from '../../lib/api.js'
import { useToast } from '../../composables/useToast.js'

const toast = useToast()

// ── Data ─────────────────────────────────────────────────────────────────────
const loading   = ref(true)
const pendientes = ref([])
const inventario = ref([])
const sedes      = ref([])
const geneticas  = ref([])

// ── Tabs ─────────────────────────────────────────────────────────────────────
const tabActiva = ref('pendientes')
const TABS = computed(() => [
  { key: 'pendientes', label: '⏳ Pendientes', count: pendientes.value.length },
  { key: 'inventario', label: '📦 Inventario',  count: inventario.value.length },
])

// ── KPIs ─────────────────────────────────────────────────────────────────────
const totalG = computed(() =>
  parseFloat((inventario.value.reduce((s, x) => s + x.cantidad, 0)).toFixed(1))
)
const stockPropio = computed(() =>
  parseFloat((inventario.value.filter(x => x.origen !== 'compra_externa').reduce((s, x) => s + x.cantidad, 0)).toFixed(1))
)
const sedesConStock = computed(() => [...new Set(inventario.value.map(x => x.sede_id).filter(Boolean))])

// ── Inventario filtros ────────────────────────────────────────────────────────
const filtroForma = ref('todos')
const filtrosForma = computed(() => {
  const formas = [...new Set(inventario.value.map(x => x.forma_producto))]
  return [
    { value: 'todos', label: 'Todos' },
    ...formas.map(f => ({ value: f, label: formaLabel(f) })),
  ]
})
const inventarioFiltrado = computed(() =>
  filtroForma.value === 'todos'
    ? inventario.value
    : inventario.value.filter(x => x.forma_producto === filtroForma.value)
)
const inventarioAgrupado = computed(() => {
  const grupos = {}
  for (const s of inventarioFiltrado.value) {
    const key = s.sede?.nombre || 'Pool del club'
    if (!grupos[key]) grupos[key] = { sede_nombre: key, items: [], total: 0 }
    grupos[key].items.push(s)
    grupos[key].total = parseFloat((grupos[key].total + s.cantidad).toFixed(1))
  }
  return Object.values(grupos).sort((a, b) => b.total - a.total)
})

// ── Load ──────────────────────────────────────────────────────────────────────
onMounted(async () => {
  try {
    const [rPend, rInv, rSedes, rGen] = await Promise.all([
      listStocksPendientes(),
      listStocks(),
      listSedes(),
      listGeneticas(),
    ])
    pendientes.value = rPend.data || []
    inventario.value = rInv.data  || []
    sedes.value      = rSedes.data || []
    geneticas.value  = rGen.data  || []

    pendientes.value.forEach(s => { asignaciones.value[s.id] = '' })

    // Si no hay pendientes, abrir directamente inventario
    if (!pendientes.value.length) tabActiva.value = 'inventario'
  } catch {
    toast.error('Error al cargar stocks')
  } finally {
    loading.value = false
  }
})

// ── Asignar ───────────────────────────────────────────────────────────────────
const asignando    = ref(null)
const asignaciones = ref({})

async function asignar(stock) {
  asignando.value = stock.id
  try {
    const sede_id = asignaciones.value[stock.id] || null
    await asignarStock(stock.id, { sede_id })
    pendientes.value = pendientes.value.filter(s => s.id !== stock.id)
    // Refrescar inventario
    const { data } = await listStocks()
    inventario.value = data || []
    toast.success('Stock asignado')
    if (!pendientes.value.length) tabActiva.value = 'inventario'
  } catch (e) {
    toast.error(e.response?.data?.error || 'Error al asignar')
  } finally {
    asignando.value = null
  }
}

// ── Crear stock externo ───────────────────────────────────────────────────────
const showCrear  = ref(false)
const creando    = ref(false)
const crearError = ref(null)

const emptyForm = () => ({
  forma_producto: 'flor_seca', cantidad: '', sede_id: '',
  genetica_id: '', precio_sugerido_ars: '', costo_unitario_ars: '',
  proveedor: '', descripcion: '',
})
const crearForm = ref(emptyForm())

function openCrear()  { crearForm.value = emptyForm(); crearError.value = null; showCrear.value = true }
function closeCrear() { showCrear.value = false }

async function guardarStock() {
  crearError.value = null
  if (!crearForm.value.cantidad || Number(crearForm.value.cantidad) <= 0) {
    crearError.value = 'La cantidad debe ser mayor a 0'
    return
  }
  if (!crearForm.value.proveedor?.trim()) {
    crearError.value = 'El proveedor es obligatorio'
    return
  }
  creando.value = true
  try {
    const p = {
      origen: 'compra_externa', forma_producto: crearForm.value.forma_producto,
      cantidad: Number(crearForm.value.cantidad), unidad: 'g', estado: 'asignado',
    }
    if (crearForm.value.sede_id)             p.sede_id             = Number(crearForm.value.sede_id)
    if (crearForm.value.genetica_id)         p.genetica_id         = Number(crearForm.value.genetica_id)
    if (crearForm.value.precio_sugerido_ars) p.precio_sugerido_ars = Number(crearForm.value.precio_sugerido_ars)
    if (crearForm.value.costo_unitario_ars)  p.costo_unitario_ars  = Number(crearForm.value.costo_unitario_ars)
    p.proveedor = crearForm.value.proveedor
    if (crearForm.value.descripcion)         p.descripcion         = crearForm.value.descripcion

    await createStock(p)
    toast.success('Stock externo creado')
    closeCrear()
    const [rPend, rInv] = await Promise.all([listStocksPendientes(), listStocks()])
    pendientes.value = rPend.data || []
    inventario.value = rInv.data  || []
    tabActiva.value  = 'inventario'
  } catch (e) {
    crearError.value = e?.response?.data?.errors?.[0] || e?.response?.data?.error || 'Error al crear el stock'
  } finally {
    creando.value = false
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────
const FORMAS = [
  { value: 'flor_seca',  label: 'Flor seca' },
  { value: 'hash',       label: 'Hash' },
  { value: 'aceite',     label: 'Aceite' },
  { value: 'tintura',    label: 'Tintura' },
  { value: 'crema',      label: 'Crema' },
  { value: 'capsula',    label: 'Cápsula' },
  { value: 'comestible', label: 'Comestible' },
  { value: 'prensado',   label: 'Prensado' },
  { value: 'externo',    label: 'Externo (merch/insumo)' },
  { value: 'otro',       label: 'Otro' },
]
const FORMA_MAP = Object.fromEntries(FORMAS.map(f => [f.value, f.label]))
function formaLabel(f) { return FORMA_MAP[f] || f || 'Stock' }
</script>

<style scoped>
.stk { padding: 1.5rem 1.75rem 3rem; }
@media (max-width: 640px) { .stk { padding: 1rem 1rem 2rem; } }

/* Header */
.stk__header {
  display: flex; align-items: center; justify-content: space-between;
  gap: 1rem; margin-bottom: 1.75rem; flex-wrap: wrap;
}
.stk__title { font-size: 1.6rem; font-weight: 800; color: #0f172a; letter-spacing: -.04em; margin: 0 0 .2rem; }
.stk__sub   { font-size: .82rem; color: #64748b; margin: 0; }

/* Buttons */
.stk__btn-primary {
  display: inline-flex; align-items: center; gap: .4rem;
  background: #1b5e20; color: #fff; border: none; border-radius: 8px;
  padding: .55rem 1.1rem; font-size: .82rem; font-weight: 600;
  cursor: pointer; transition: background .15s; white-space: nowrap;
}
.stk__btn-primary:hover:not(:disabled) { background: #144a18; }
.stk__btn-primary:disabled { opacity: .5; cursor: not-allowed; }
.stk__btn-sm { padding: .4rem .85rem; font-size: .78rem; }
.stk__btn-ghost {
  display: inline-flex; align-items: center; gap: .4rem;
  background: transparent; color: #475569; border: 1.5px solid #e2e8f0;
  padding: .5rem 1rem; border-radius: 8px; font-size: .82rem; font-weight: 500;
  cursor: pointer; transition: all .15s;
}
.stk__btn-ghost:hover { background: #f8fafc; }
.stk__btn-outline {
  display: inline-flex; align-items: center; gap: .4rem;
  background: transparent; color: #1b5e20; border: 1.5px solid #a5d6a7;
  padding: .5rem 1.1rem; border-radius: 8px; font-size: .82rem; font-weight: 600;
  cursor: pointer; transition: all .15s;
}
.stk__btn-outline:hover { background: #f0fdf4; }

/* KPIs */
.stk__kpis {
  display: grid; grid-template-columns: repeat(4, 1fr);
  gap: .875rem; margin-bottom: 1.75rem;
}
@media (max-width: 700px) { .stk__kpis { grid-template-columns: repeat(2, 1fr); } }
@media (max-width: 400px) { .stk__kpis { grid-template-columns: 1fr; } }

.stk__kpi {
  background: #fff; border: 1px solid #e2e8f0; border-radius: 12px;
  padding: 1rem 1.1rem; display: flex; align-items: flex-start; gap: .65rem;
  transition: box-shadow .15s;
}
.stk__kpi:hover { box-shadow: 0 2px 12px rgba(0,0,0,.06); }
.stk__kpi--warn { border-color: #fcd34d; background: #fffbeb; }
.stk__kpi-ico  { font-size: 1.35rem; flex-shrink: 0; margin-top: .05rem; }
.stk__kpi-val  { font-size: 1.75rem; font-weight: 800; line-height: 1; letter-spacing: -.04em; color: #0f172a; margin-bottom: .1rem; }
.stk__kpi-unit { font-size: 1rem; font-weight: 500; color: #94a3b8; margin-left: 2px; }
.stk__kpi-lbl  { font-size: .68rem; font-weight: 600; color: #64748b; text-transform: uppercase; letter-spacing: .05em; }

/* Tabs */
.stk__tabs { display: flex; gap: .35rem; margin-bottom: 1.25rem; flex-wrap: wrap; }
.stk__tab {
  display: inline-flex; align-items: center; gap: .4rem;
  padding: .5rem 1rem; border-radius: 8px; border: 1.5px solid #e2e8f0;
  background: #fff; color: #475569; font-size: .82rem; font-weight: 600;
  cursor: pointer; transition: all .15s;
}
.stk__tab:hover { border-color: #a5d6a7; background: #f0fdf4; }
.stk__tab--active { background: #0f172a; color: #fff; border-color: #0f172a; }
.stk__tab-count {
  min-width: 18px; height: 18px; background: #e2e8f0; color: #475569;
  border-radius: 999px; font-size: .62rem; font-weight: 800;
  display: inline-flex; align-items: center; justify-content: center; padding: 0 4px;
}
.stk__tab--active .stk__tab-count { background: rgba(255,255,255,.2); color: #fff; }
.stk__tab-count--warn { background: #fcd34d; color: #92400e; }

/* Loading */
.stk__loading { display: flex; align-items: center; gap: .75rem; padding: 4rem; color: #94a3b8; justify-content: center; font-size: .9rem; }
.stk__ring    { width: 20px; height: 20px; border: 2px solid #e2e8f0; border-top-color: #1b5e20; border-radius: 50%; animation: stk-spin .7s linear infinite; }
@keyframes stk-spin { to { transform: rotate(360deg); } }

/* Spinners */
.stk__spinner { width: 14px; height: 14px; border: 2px solid rgba(27,94,32,.2); border-top-color: #1b5e20; border-radius: 50%; animation: stk-spin .6s linear infinite; }
.stk__spinner--sm    { width: 12px; height: 12px; }
.stk__spinner--white { border-color: rgba(255,255,255,.3); border-top-color: #fff; }

/* Empty */
.stk__empty { display: flex; flex-direction: column; align-items: center; gap: .5rem; padding: 3.5rem 1rem; text-align: center; }
.stk__empty-ico   { font-size: 2.5rem; }
.stk__empty-title { font-size: 1rem; font-weight: 700; color: #0f172a; margin: 0; }
.stk__empty-sub   { font-size: .82rem; color: #64748b; margin: 0; }
.stk__empty-cta   { margin-top: .75rem; }

/* Pending list */
.stk__list { display: flex; flex-direction: column; gap: .75rem; }
.stk__item {
  background: #fff; border: 1px solid #e2e8f0; border-radius: 12px;
  padding: 1rem 1.25rem; display: flex; align-items: center;
  justify-content: space-between; gap: 1rem; flex-wrap: wrap;
}
.stk__item-left  { flex: 1; min-width: 0; }
.stk__item-forma { font-size: .95rem; font-weight: 700; color: #0f172a; margin-bottom: .35rem; }
.stk__item-chips { display: flex; flex-wrap: wrap; gap: .3rem; }
.stk__item-right { display: flex; align-items: center; gap: .5rem; flex-shrink: 0; flex-wrap: wrap; }

.stk__select {
  padding: .42rem .75rem; border: 1.5px solid #e2e8f0; border-radius: 8px;
  font-size: .82rem; color: #0f172a; background: #fff; cursor: pointer; min-width: 160px;
}
.stk__select:focus { outline: none; border-color: #1b5e20; }

/* Chips */
.stk__chip {
  font-size: .68rem; font-weight: 600; padding: .2em .6em; border-radius: 5px;
  background: #f1f5f9; color: #475569; border: 1px solid #e2e8f0;
}
.stk__chip--g    { background: #f0fdf4; color: #15803d; border-color: #bbf7d0; }
.stk__chip--lote { background: #eff6ff; color: #1d4ed8; border-color: #bfdbfe; }
.stk__chip--gen  { background: #f0fdf4; color: #166534; border-color: #bbf7d0; }
.stk__chip--ext  { background: #fef3c7; color: #92400e; border-color: #fde68a; }

/* Filter chips */
.stk__filters { display: flex; gap: .4rem; flex-wrap: wrap; margin-bottom: 1rem; }
.stk__chip-btn {
  background: #f1f5f9; color: #475569; border: 1px solid #e2e8f0;
  border-radius: 999px; padding: .3rem .85rem; font-size: .75rem; font-weight: 600;
  cursor: pointer; transition: all .15s;
}
.stk__chip-btn:hover { border-color: #1b5e20; color: #1b5e20; }
.stk__chip-btn--active { background: #1b5e20; color: #fff; border-color: #1b5e20; }

/* Inventory groups */
.stk__grupo { margin-bottom: 1.25rem; }
.stk__grupo-header {
  display: flex; align-items: center; justify-content: space-between;
  padding: .5rem .75rem; background: #f8fafc; border: 1px solid #e2e8f0;
  border-radius: 8px 8px 0 0; border-bottom: none;
}
.stk__grupo-nombre { font-size: .8rem; font-weight: 700; color: #374151; }
.stk__grupo-total  { font-size: .8rem; font-weight: 700; color: #15803d; }

.stk__inv-list { border: 1px solid #e2e8f0; border-radius: 0 0 8px 8px; overflow: hidden; }
.stk__inv-item {
  display: flex; align-items: center; justify-content: space-between;
  gap: 1rem; padding: .75rem 1rem; background: #fff;
  border-bottom: 1px solid #f1f5f9;
}
.stk__inv-item:last-child { border-bottom: none; }
.stk__inv-left  { flex: 1; min-width: 0; }
.stk__inv-right { display: flex; align-items: center; gap: .5rem; flex-shrink: 0; }
.stk__inv-forma { font-size: .88rem; font-weight: 600; color: #0f172a; margin-bottom: .25rem; }
.stk__inv-chips { display: flex; flex-wrap: wrap; gap: .25rem; }
.stk__inv-g     { font-size: .95rem; font-weight: 800; color: #15803d; }
.stk__icon-btn  {
  width: 28px; height: 28px; border-radius: 6px; border: 1px solid #e2e8f0;
  display: flex; align-items: center; justify-content: center;
  color: #64748b; font-size: .8rem; text-decoration: none; transition: all .15s;
}
.stk__icon-btn:hover { border-color: #1b5e20; color: #1b5e20; background: #f0fdf4; }

/* Modal */
.stk__overlay {
  position: fixed; inset: 0; background: rgba(0,0,0,.45); backdrop-filter: blur(3px);
  display: flex; align-items: flex-end; justify-content: center;
  z-index: 200; padding: 1rem;
}
@media (min-width: 640px) { .stk__overlay { align-items: center; } }

.stk__modal {
  background: #fff; border-radius: 16px;
  width: 100%; max-width: 540px; max-height: 92vh;
  display: flex; flex-direction: column;
  box-shadow: 0 20px 60px rgba(0,0,0,.2);
}
.stk__modal-hd {
  display: flex; align-items: flex-start; gap: .75rem;
  padding: 1.25rem 1.25rem 1rem; border-bottom: 1px solid #f1f5f9;
}
.stk__modal-ico {
  width: 36px; height: 36px; background: #f0fdf4; color: #1b5e20;
  border-radius: 8px; display: flex; align-items: center; justify-content: center;
  font-size: 1rem; flex-shrink: 0;
}
.stk__modal-title { font-size: .95rem; font-weight: 800; color: #0f172a; margin: 0 0 2px; }
.stk__modal-sub   { font-size: .75rem; color: #64748b; margin: 0; }
.stk__modal-close {
  margin-left: auto; background: #f8fafc; border: none; width: 28px; height: 28px;
  border-radius: 6px; cursor: pointer; display: flex; align-items: center;
  justify-content: center; color: #64748b; flex-shrink: 0;
}
.stk__modal-close:hover { background: #e2e8f0; }
.stk__modal-body { padding: 1.25rem; overflow-y: auto; flex: 1; }
.stk__modal-ft   { display: flex; justify-content: flex-end; gap: .5rem; padding: 1rem 1.25rem; border-top: 1px solid #f1f5f9; }

.stk__form-grid  { display: grid; grid-template-columns: 1fr 1fr; gap: .875rem; }
@media (max-width: 480px) { .stk__form-grid { grid-template-columns: 1fr; } }
.stk__field      { display: flex; flex-direction: column; gap: .3rem; }
.stk__field--full { grid-column: 1 / -1; }
.stk__label      { font-size: .72rem; font-weight: 700; color: #374151; text-transform: uppercase; letter-spacing: .04em; }
.stk__req        { color: #ef4444; }
.stk__opt        { font-weight: 400; color: #94a3b8; text-transform: none; letter-spacing: 0; }
.stk__input      { background: #f8fafc; border: 1.5px solid #e2e8f0; border-radius: 7px; padding: .5rem .75rem; font-size: .875rem; color: #0f172a; width: 100%; box-sizing: border-box; font-family: inherit; transition: border .15s; }
.stk__input:focus { outline: none; border-color: #1b5e20; background: #fff; }
.stk__textarea   { resize: vertical; min-height: 60px; }
.stk__input-row  { display: flex; }
.stk__input-row .stk__input { border-radius: 7px 0 0 7px; }
.stk__input-suf  { background: #f1f5f9; border: 1.5px solid #e2e8f0; border-left: none; border-radius: 0 7px 7px 0; padding: .5rem .75rem; font-size: .82rem; font-weight: 600; color: #64748b; }
.stk__alert      { background: #fef2f2; border: 1px solid #fecaca; color: #dc2626; border-radius: 7px; padding: .55rem .75rem; font-size: .82rem; margin-bottom: 1rem; }

.stk-fade-enter-active, .stk-fade-leave-active { transition: opacity .2s; }
.stk-fade-enter-from,  .stk-fade-leave-to      { opacity: 0; }
</style>
