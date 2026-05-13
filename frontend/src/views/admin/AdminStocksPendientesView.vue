<template>
  <div class="asp">
    <div class="asp__header">
      <div>
        <h1 class="asp__title">Stocks</h1>
        <p class="asp__sub">Pendientes de asignación · Stock externo</p>
      </div>
      <div class="asp__header-actions">
        <button class="asp__btn asp__btn--outline" @click="openCrear">
          <i class="bi bi-plus-lg"></i> Nuevo stock externo
        </button>
        <RouterLink to="/" class="asp__back"><i class="bi bi-arrow-left"></i> Dashboard</RouterLink>
      </div>
    </div>

    <div v-if="loading" class="asp__loading">
      <div class="asp__ring"></div> Cargando stocks…
    </div>

    <template v-else>
      <!-- Pendientes de producción -->
      <h2 class="asp__section-title">Pendientes de asignación (producción)</h2>

      <div v-if="!stocks.length" class="asp__empty">
        <i class="bi bi-check-circle-fill asp__empty-ico"></i>
        <div class="asp__empty-title">Sin stocks pendientes</div>
        <div class="asp__empty-sub">Todo el stock cosechado ya fue asignado a una sede.</div>
      </div>

      <div v-else class="asp__list">
        <div v-for="s in stocks" :key="s.id" class="asp__item">
          <div class="asp__item-info">
            <div class="asp__item-name">{{ formaLabel(s.forma_producto) }}</div>
            <div class="asp__item-meta">
              <span class="asp__chip">{{ s.cantidad }} g</span>
              <span class="asp__chip asp__chip--lote">
                <i class="bi bi-box me-1"></i>{{ s.lote?.codigo || `Lote #${s.lote_id}` }}
              </span>
              <span v-if="s.lote?.genetica" class="asp__chip asp__chip--gen">{{ s.lote.genetica.nombre }}</span>
            </div>
          </div>

          <div class="asp__item-action">
            <select v-model="asignaciones[s.id]" class="asp__select">
              <option value="">Pool del club (delivery)</option>
              <option v-for="sede in sedes" :key="sede.id" :value="sede.id">{{ sede.nombre }}</option>
            </select>
            <button
              class="asp__btn"
              :disabled="asignando === s.id"
              @click="asignar(s)"
            >
              <span v-if="asignando === s.id" class="asp__spinner"></span>
              <i v-else class="bi bi-check-lg"></i>
              Asignar
            </button>
          </div>
        </div>
      </div>
    </template>

    <!-- Modal: crear stock externo -->
    <Teleport to="body">
      <div v-if="showCrear" class="asp__overlay" @click.self="closeCrear">
        <div class="asp__modal">
          <div class="asp__modal-header">
            <div>
              <h2 class="asp__modal-title">Nuevo stock externo</h2>
              <p class="asp__modal-sub">Stock adquirido fuera del proceso de cultivo propio</p>
            </div>
            <button class="asp__modal-close" @click="closeCrear"><i class="bi bi-x-lg"></i></button>
          </div>

          <div class="asp__modal-body">
            <div v-if="crearError" class="asp__alert">{{ crearError }}</div>

            <div class="asp__grid">
              <div class="asp__field asp__field--full">
                <label class="asp__label">Forma del producto</label>
                <select class="asp__input" v-model="crearForm.forma_producto">
                  <option value="flor_seca">Flor seca</option>
                  <option value="pre_roll">Pre-roll</option>
                  <option value="extracto">Extracto</option>
                  <option value="tintura">Tintura</option>
                  <option value="comestible">Comestible</option>
                  <option value="topico">Tópico</option>
                  <option value="otro">Otro</option>
                </select>
              </div>

              <div class="asp__field">
                <label class="asp__label">Cantidad (g)</label>
                <input type="number" min="0.1" step="0.1" class="asp__input" v-model="crearForm.cantidad" placeholder="0.0" />
              </div>

              <div class="asp__field">
                <label class="asp__label">Sede destino <span class="asp__label-opt">(opcional)</span></label>
                <select class="asp__input" v-model="crearForm.sede_id">
                  <option value="">Pool del club</option>
                  <option v-for="s in sedes" :key="s.id" :value="s.id">{{ s.nombre }}</option>
                </select>
              </div>

              <div class="asp__field">
                <label class="asp__label">Genética <span class="asp__label-opt">(opcional)</span></label>
                <select class="asp__input" v-model="crearForm.genetica_id">
                  <option value="">Sin especificar</option>
                  <option v-for="g in geneticas" :key="g.id" :value="g.id">{{ g.nombre }} — {{ g.tipo }}</option>
                </select>
              </div>

              <div class="asp__field">
                <label class="asp__label">Precio sugerido (ARS/g) <span class="asp__label-opt">(opcional)</span></label>
                <input type="number" min="0" step="0.01" class="asp__input" v-model="crearForm.precio_sugerido_ars" placeholder="0.00" />
              </div>

              <div class="asp__field">
                <label class="asp__label">Costo unitario (ARS/g) <span class="asp__label-opt">(opcional)</span></label>
                <input type="number" min="0" step="0.01" class="asp__input" v-model="crearForm.costo_unitario_ars" placeholder="0.00" />
              </div>

              <div class="asp__field asp__field--full">
                <label class="asp__label">Proveedor <span class="asp__label-opt">(opcional)</span></label>
                <input type="text" class="asp__input" v-model="crearForm.proveedor" placeholder="Nombre del proveedor o productor" />
              </div>

              <div class="asp__field asp__field--full">
                <label class="asp__label">Descripción / Notas <span class="asp__label-opt">(opcional)</span></label>
                <textarea class="asp__input asp__textarea" rows="2" v-model="crearForm.descripcion" placeholder="Observaciones sobre el stock…"></textarea>
              </div>
            </div>
          </div>

          <div class="asp__modal-footer">
            <button class="asp__btn asp__btn--ghost" :disabled="creando" @click="closeCrear">Cancelar</button>
            <button class="asp__btn" :disabled="creando || !crearForm.cantidad" @click="guardarStock">
              <span v-if="creando" class="asp__spinner"></span>
              <i v-else class="bi bi-plus-lg"></i>
              Crear stock
            </button>
          </div>
        </div>
      </div>
    </Teleport>

  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { listStocksPendientes, asignarStock, listSedes, createStock, listGeneticas } from '../../lib/api.js'
import { useToast } from '../../composables/useToast.js'

const toast  = useToast()
const stocks = ref([])
const sedes  = ref([])
const geneticas = ref([])
const loading   = ref(true)
const asignando = ref(null)
const asignaciones = ref({})

const FORMA_LABELS = {
  flor_seca:  'Flor seca',
  pre_roll:   'Pre-roll',
  extracto:   'Extracto',
  tintura:    'Tintura',
  comestible: 'Comestible',
  topico:     'Tópico',
  otro:       'Otro',
}
function formaLabel(f) { return FORMA_LABELS[f] || f || 'Stock' }

onMounted(async () => {
  try {
    const [resStocks, resSedes, resGen] = await Promise.all([
      listStocksPendientes(),
      listSedes(),
      listGeneticas(),
    ])
    stocks.value    = resStocks.data || []
    sedes.value     = resSedes.data  || []
    geneticas.value = resGen.data    || []
    stocks.value.forEach(s => { asignaciones.value[s.id] = '' })
  } catch (e) {
    toast.error('Error al cargar stocks')
  } finally {
    loading.value = false
  }
})

async function asignar(stock) {
  asignando.value = stock.id
  try {
    const sede_id = asignaciones.value[stock.id] || null
    await asignarStock(stock.id, { sede_id })
    stocks.value = stocks.value.filter(s => s.id !== stock.id)
    toast.success(`Stock asignado correctamente`)
  } catch (e) {
    toast.error(e.response?.data?.error || 'Error al asignar')
  } finally {
    asignando.value = null
  }
}

// Crear stock externo
const showCrear = ref(false)
const creando   = ref(false)
const crearError = ref(null)

function emptyCrearForm() {
  return {
    forma_producto:       'flor_seca',
    cantidad:             '',
    sede_id:              '',
    genetica_id:          '',
    precio_sugerido_ars:  '',
    costo_unitario_ars:   '',
    proveedor:            '',
    descripcion:          '',
  }
}
const crearForm = ref(emptyCrearForm())

function openCrear() {
  crearForm.value = emptyCrearForm()
  crearError.value = null
  showCrear.value = true
}
function closeCrear() {
  showCrear.value = false
}

async function guardarStock() {
  crearError.value = null
  if (!crearForm.value.cantidad || Number(crearForm.value.cantidad) <= 0) {
    crearError.value = 'La cantidad debe ser mayor a 0'
    return
  }
  creando.value = true
  try {
    const payload = {
      origen:        'externo',
      forma_producto: crearForm.value.forma_producto,
      cantidad:      Number(crearForm.value.cantidad),
      unidad:        'g',
      estado:        'asignado',
    }
    if (crearForm.value.sede_id)             payload.sede_id             = Number(crearForm.value.sede_id)
    if (crearForm.value.genetica_id)         payload.genetica_id         = Number(crearForm.value.genetica_id)
    if (crearForm.value.precio_sugerido_ars) payload.precio_sugerido_ars = Number(crearForm.value.precio_sugerido_ars)
    if (crearForm.value.costo_unitario_ars)  payload.costo_unitario_ars  = Number(crearForm.value.costo_unitario_ars)
    if (crearForm.value.proveedor)           payload.proveedor           = crearForm.value.proveedor
    if (crearForm.value.descripcion)         payload.descripcion         = crearForm.value.descripcion

    await createStock(payload)
    toast.success('Stock externo creado correctamente')
    closeCrear()
  } catch (e) {
    crearError.value = e?.response?.data?.errors?.[0] || e?.response?.data?.error || 'Error al crear el stock'
  } finally {
    creando.value = false
  }
}
</script>

<style scoped>
.asp { padding: 2rem 1.75rem 3rem; max-width: 900px; margin: 0 auto; font-family: system-ui, -apple-system, sans-serif; color: #0f172a; }
@media (max-width: 640px) { .asp { padding: 1.25rem 1rem 2rem; } }

.asp__header { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; margin-bottom: 2rem; flex-wrap: wrap; }
.asp__header-actions { display: flex; align-items: center; gap: .6rem; flex-wrap: wrap; }
.asp__title { font-size: 1.5rem; font-weight: 800; letter-spacing: -.04em; margin: 0 0 .2rem; }
.asp__sub { font-size: .83rem; color: #64748b; margin: 0; }
.asp__back { display: inline-flex; align-items: center; gap: .4rem; color: #64748b; font-size: .82rem; font-weight: 500; text-decoration: none; padding: .45rem .875rem; border: 1.5px solid #e2e8f0; border-radius: 8px; transition: all .15s; }
.asp__back:hover { color: #0f172a; border-color: #cbd5e1; background: #f8fafc; }

.asp__section-title { font-size: .95rem; font-weight: 700; color: #374151; margin: 0 0 1rem; }

.asp__loading { display: flex; align-items: center; gap: .75rem; padding: 4rem; color: #94a3b8; justify-content: center; }
.asp__ring { width: 22px; height: 22px; border: 2px solid #e2e8f0; border-top-color: #1b5e20; border-radius: 50%; animation: asp-spin .7s linear infinite; flex-shrink: 0; }
@keyframes asp-spin { to { transform: rotate(360deg); } }

.asp__empty { text-align: center; padding: 3rem 1rem; }
.asp__empty-ico { font-size: 3rem; color: #15803d; display: block; margin-bottom: 1rem; }
.asp__empty-title { font-size: 1.1rem; font-weight: 700; color: #0f172a; margin-bottom: .35rem; }
.asp__empty-sub { font-size: .85rem; color: #64748b; }

.asp__list { display: flex; flex-direction: column; gap: .875rem; }
.asp__item {
  background: #fff; border: 1px solid #e2e8f0; border-radius: 12px;
  padding: 1.125rem 1.25rem;
  display: flex; align-items: center; justify-content: space-between;
  gap: 1.25rem; flex-wrap: wrap;
}
.asp__item-info { flex: 1; min-width: 0; }
.asp__item-name { font-size: .95rem; font-weight: 700; color: #0f172a; margin-bottom: .4rem; }
.asp__item-meta { display: flex; flex-wrap: wrap; gap: .4rem; }
.asp__chip { font-size: .72rem; font-weight: 600; padding: .2em .65em; border-radius: 5px; background: #f1f5f9; color: #475569; border: 1px solid #e2e8f0; }
.asp__chip--lote { background: rgba(8,145,178,.08); color: #0369a1; border-color: rgba(8,145,178,.2); }
.asp__chip--gen  { background: rgba(21,128,61,.08); color: #15803d; border-color: rgba(21,128,61,.2); }

.asp__item-action { display: flex; align-items: center; gap: .6rem; flex-shrink: 0; }
.asp__select {
  padding: .45rem .75rem; border: 1.5px solid #e2e8f0; border-radius: 8px;
  font-size: .82rem; color: #0f172a; background: #fff; cursor: pointer; min-width: 180px;
}
.asp__select:focus { outline: none; border-color: #1b5e20; }

.asp__btn {
  display: inline-flex; align-items: center; gap: .35rem;
  background: #1b5e20; color: #fff; border: none;
  padding: .5rem 1rem; border-radius: 8px;
  font-size: .82rem; font-weight: 600; cursor: pointer;
  transition: background .15s; white-space: nowrap;
}
.asp__btn:hover:not(:disabled) { background: #144a18; }
.asp__btn:disabled { opacity: .55; cursor: not-allowed; }
.asp__btn--outline {
  background: transparent; color: #1b5e20;
  border: 1.5px solid #a5d6a7;
}
.asp__btn--outline:hover:not(:disabled) { background: #f0fdf4; }
.asp__btn--ghost {
  background: transparent; color: #64748b;
  border: 1.5px solid #e2e8f0;
}
.asp__btn--ghost:hover:not(:disabled) { background: #f8fafc; color: #0f172a; }
.asp__spinner { width: 14px; height: 14px; border: 2px solid rgba(255,255,255,.3); border-top-color: #fff; border-radius: 50%; animation: asp-spin .6s linear infinite; }

/* Modal */
.asp__overlay {
  position: fixed; inset: 0; background: rgba(0,0,0,.45);
  display: flex; align-items: flex-end; justify-content: center;
  z-index: 200; padding: 1rem;
}
@media (min-width: 640px) { .asp__overlay { align-items: center; } }

.asp__modal {
  background: #fff; border-radius: 16px;
  width: 100%; max-width: 560px; max-height: 90vh;
  display: flex; flex-direction: column;
  box-shadow: 0 20px 60px rgba(0,0,0,.2);
}
.asp__modal-header {
  display: flex; align-items: flex-start; justify-content: space-between;
  padding: 1.25rem 1.5rem; border-bottom: 1px solid #f1f5f9;
}
.asp__modal-title { font-size: 1.1rem; font-weight: 800; margin: 0 0 .15rem; }
.asp__modal-sub { font-size: .78rem; color: #64748b; margin: 0; }
.asp__modal-close { background: none; border: none; cursor: pointer; color: #94a3b8; font-size: 1.1rem; padding: .2rem; }
.asp__modal-close:hover { color: #0f172a; }
.asp__modal-body { padding: 1.25rem 1.5rem; overflow-y: auto; flex: 1; }
.asp__modal-footer {
  display: flex; justify-content: flex-end; gap: .75rem;
  padding: 1rem 1.5rem; border-top: 1px solid #f1f5f9;
}

.asp__grid { display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; }
@media (max-width: 500px) { .asp__grid { grid-template-columns: 1fr; } }
.asp__field { display: flex; flex-direction: column; gap: .3rem; }
.asp__field--full { grid-column: 1 / -1; }
.asp__label { font-size: .78rem; font-weight: 600; color: #374151; }
.asp__label-opt { font-weight: 400; color: #94a3b8; }
.asp__input {
  background: #f8fafc; border: 1.5px solid #e2e8f0;
  border-radius: 8px; padding: .55rem .85rem;
  font-size: .875rem; color: #0f172a; width: 100%;
  box-sizing: border-box; font-family: inherit; transition: border .15s;
}
.asp__input:focus { outline: none; border-color: #1b5e20; background: #fff; }
.asp__textarea { resize: vertical; min-height: 64px; }
.asp__alert { background: #fef2f2; border: 1px solid #fecaca; color: #dc2626; border-radius: 8px; padding: .65rem 1rem; font-size: .82rem; margin-bottom: 1rem; }
</style>
