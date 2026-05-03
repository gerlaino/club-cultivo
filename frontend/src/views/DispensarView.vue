<template>
  <div class="dv">
    <!-- Left: Patient search -->
    <aside class="dv__left">
      <h2 class="dv__panel-title">Paciente</h2>

      <div class="dv__search-wrap">
        <Search :size="16" :stroke-width="1.75" class="dv__search-ico" />
        <input
          v-model="query"
          class="dv__search-input"
          type="search"
          placeholder="Buscar por nombre o DNI…"
          autocomplete="off"
        />
      </div>

      <div v-if="loadingPacientes" class="dv__skel-list">
        <div class="dv__skel" v-for="n in 4" :key="n" />
      </div>

      <div v-else-if="!pacientes.length && query" class="dv__empty">Sin resultados.</div>

      <ul v-else class="dv__paciente-list">
        <li
          v-for="p in pacientes"
          :key="p.id"
          class="dv__paciente-item"
          :class="{ 'dv__paciente-item--selected': selectedPaciente?.id === p.id }"
          @click="selectPaciente(p)"
        >
          <div class="dv__paciente-name">{{ p.nombre }} {{ p.apellido }}</div>
          <div class="dv__paciente-meta">
            <span class="dv__paciente-dni">{{ p.dni ?? p.numero_documento ?? '—' }}</span>
            <span
              class="dv__reprocann-badge"
              :class="reprocannClass(p)"
            >{{ reprocannLabel(p) }}</span>
          </div>
        </li>
      </ul>
    </aside>

    <!-- Right: Stock + Cart -->
    <div class="dv__right">
      <!-- No patient selected -->
      <div v-if="!selectedPaciente" class="dv__placeholder">
        <Users :size="40" :stroke-width="1.25" class="dv__placeholder-ico" />
        <p>Seleccioná un paciente para ver el stock disponible.</p>
      </div>

      <template v-else>
        <!-- Stock grid -->
        <div class="dv__stock-section">
          <h2 class="dv__panel-title">Stock disponible</h2>

          <div v-if="loadingStocks" class="dv__skel-grid">
            <div class="dv__skel dv__skel--card" v-for="n in 6" :key="n" />
          </div>

          <div v-else-if="!stocksDisponibles.length" class="dv__empty">
            Sin stock disponible.
          </div>

          <div v-else class="dv__stock-grid">
            <div
              v-for="s in stocksDisponibles"
              :key="s.id"
              class="dv__stock-card"
            >
              <div class="dv__stock-header">{{ formaLabel(s.forma_producto) }}</div>
              <div class="dv__stock-lote">{{ s.lote?.codigo ?? '—' }}</div>
              <div class="dv__stock-disponible">{{ s.cantidad }}{{ s.unidad }} disponibles</div>
              <div class="dv__stock-precio">{{ formatARS(s.precio_sugerido_ars) }}/{{ s.unidad }}</div>
              <div class="dv__stock-add">
                <input
                  v-model.number="cantidades[s.id]"
                  type="number"
                  min="0.01"
                  :max="s.cantidad"
                  step="0.01"
                  class="dv__qty-input"
                  placeholder="0"
                />
                <button class="dv__add-btn" @click="addToCart(s)">
                  <Plus :size="14" :stroke-width="2" /> Agregar
                </button>
              </div>
            </div>
          </div>
        </div>

        <!-- Cart -->
        <div v-if="cart.length" class="dv__cart">
          <h2 class="dv__panel-title">Carrito</h2>
          <div class="dv__cart-items">
            <div v-for="(item, i) in cart" :key="i" class="dv__cart-item">
              <div class="dv__cart-desc">
                <span class="dv__cart-forma">{{ formaLabel(item.stock.forma_producto) }}</span>
                <span class="dv__cart-qty">{{ item.cantidad }}{{ item.stock.unidad }}</span>
              </div>
              <div class="dv__cart-total">{{ formatARS(item.total) }}</div>
              <button class="dv__cart-remove" @click="removeFromCart(i)">
                <X :size="14" :stroke-width="2" />
              </button>
            </div>
          </div>
          <div class="dv__cart-footer">
            <div class="dv__cart-sum">
              Total: <strong>{{ formatARS(cartTotal) }}</strong>
            </div>
            <button class="dv__confirm-btn" @click="confirmOpen = true">
              Confirmar dispensación
            </button>
          </div>
        </div>
      </template>
    </div>

    <!-- Confirm modal -->
    <Teleport to="body">
      <Transition name="modal-fade">
        <div v-if="confirmOpen" class="dv__modal-overlay" @click.self="confirmOpen = false">
          <div class="dv__modal">
            <div class="dv__modal-header">
              <h3 class="dv__modal-title">Confirmar dispensación</h3>
              <button class="dv__modal-close" @click="confirmOpen = false">
                <X :size="18" :stroke-width="1.75" />
              </button>
            </div>

            <div class="dv__modal-body">
              <div class="dv__modal-paciente">
                <Users :size="16" :stroke-width="1.75" />
                <strong>{{ selectedPaciente?.nombre }} {{ selectedPaciente?.apellido }}</strong>
              </div>

              <div class="dv__modal-items">
                <div v-for="(item, i) in cart" :key="i" class="dv__modal-item">
                  <span>{{ item.cantidad }}{{ item.stock.unidad }} {{ formaLabel(item.stock.forma_producto) }}</span>
                  <span>{{ formatARS(item.total) }}</span>
                </div>
              </div>

              <div class="dv__modal-field">
                <label class="dv__label">Medio de pago</label>
                <select v-model="medioPago" class="dv__select">
                  <option value="efectivo">Efectivo</option>
                  <option value="transferencia">Transferencia</option>
                  <option value="debito">Débito</option>
                  <option value="credito">Crédito</option>
                </select>
              </div>

              <div class="dv__modal-total">
                Total: <strong>{{ formatARS(cartTotal) }}</strong>
              </div>
            </div>

            <div class="dv__modal-footer">
              <button class="dv__modal-cancel" @click="confirmOpen = false" :disabled="submitting">
                Cancelar
              </button>
              <button class="dv__modal-submit" @click="submitDispensacion" :disabled="submitting">
                <div v-if="submitting" class="dv__spinner" />
                <template v-else>Confirmar</template>
              </button>
            </div>
          </div>
        </div>
      </Transition>
    </Teleport>
  </div>
</template>

<script setup>
import { ref, computed, watch } from 'vue'
import { listPacientes, listStocks, createDispensacion } from '../lib/api.js'
import { useToast } from '../composables/useToast.js'
import { Search, Users, Plus, X } from 'lucide-vue-next'

const toast = useToast()

const query           = ref('')
const pacientes       = ref([])
const loadingPacientes = ref(false)
const selectedPaciente = ref(null)

const stocks         = ref([])
const loadingStocks  = ref(false)
const cantidades     = ref({})

const cart       = ref([])
const confirmOpen = ref(false)
const medioPago  = ref('efectivo')
const submitting  = ref(false)

let searchTimeout = null

watch(query, (val) => {
  clearTimeout(searchTimeout)
  if (!val.trim()) { pacientes.value = []; return }
  searchTimeout = setTimeout(() => buscarPacientes(val.trim()), 300)
})

async function buscarPacientes(q) {
  loadingPacientes.value = true
  try {
    const { data } = await listPacientes({ query: q, limite: 20 })
    pacientes.value = data.data ?? []
  } catch {
    pacientes.value = []
  } finally {
    loadingPacientes.value = false
  }
}

async function selectPaciente(p) {
  selectedPaciente.value = p
  cart.value = []
  cantidades.value = {}
  loadingStocks.value = true
  try {
    const { data } = await listStocks()
    stocks.value = data.stocks ?? data ?? []
  } catch {
    stocks.value = []
  } finally {
    loadingStocks.value = false
  }
}

const stocksDisponibles = computed(() =>
  stocks.value.filter(s => s.cantidad > 0)
)

const cartTotal = computed(() =>
  cart.value.reduce((s, i) => s + i.total, 0)
)

function addToCart(s) {
  const qty = cantidades.value[s.id]
  if (!qty || qty <= 0) { toast.warning('Ingresá una cantidad'); return }
  if (qty > s.cantidad) { toast.warning(`Máximo disponible: ${s.cantidad}${s.unidad}`); return }
  const precio = s.precio_sugerido_ars ?? 0
  cart.value.push({ stock: s, cantidad: qty, total: qty * precio })
  cantidades.value[s.id] = null
}

function removeFromCart(i) {
  cart.value.splice(i, 1)
}

async function submitDispensacion() {
  if (!selectedPaciente.value || !cart.value.length) return
  submitting.value = true
  try {
    const today = new Date().toISOString().slice(0, 10)
    await Promise.all(cart.value.map(item =>
      createDispensacion(selectedPaciente.value.id, {
        stock_id:           item.stock.id,
        cantidad:           item.cantidad,
        precio_unitario_ars: item.stock.precio_sugerido_ars,
        aporte_socio_ars:   item.total,
        fecha_dispensacion: today,
        medio_pago:         medioPago.value,
      })
    ))
    toast.success(`Dispensación registrada para ${selectedPaciente.value.nombre}`)
    cart.value = []
    confirmOpen.value = false
  } catch (e) {
    const msg = e?.response?.data?.errors?.[0] || e?.response?.data?.error || 'Error al registrar'
    toast.error(msg)
  } finally {
    submitting.value = false
  }
}

function reprocannStatus(p) {
  if (!p?.reprocann_vencimiento) return 'sin'
  return new Date(p.reprocann_vencimiento) >= new Date() ? 'vigente' : 'vencido'
}
function reprocannClass(p) {
  const s = reprocannStatus(p)
  if (s === 'vigente') return 'dv__reprocann-badge--green'
  if (s === 'vencido') return 'dv__reprocann-badge--amber'
  return 'dv__reprocann-badge--gray'
}
function reprocannLabel(p) {
  const s = reprocannStatus(p)
  if (s === 'vigente') return 'REPROCANN ✓'
  if (s === 'vencido') return 'REPROCANN venc.'
  return 'Sin REPROCANN'
}

function formaLabel(f) {
  const LABELS = { flor_seca: 'Flor seca', aceite: 'Aceite', tintura: 'Tintura', crema: 'Crema', capsulas: 'Cápsulas', otro: 'Otro' }
  return LABELS[f] || f || '—'
}

function formatARS(n) {
  if (n == null) return '—'
  return new Intl.NumberFormat('es-AR', { style: 'currency', currency: 'ARS', maximumFractionDigits: 0 }).format(n)
}
</script>

<style scoped>
.dv {
  display: flex;
  gap: 0;
  min-height: calc(100vh - 60px);
}

/* Left panel */
.dv__left {
  width: 38%;
  flex-shrink: 0;
  border-right: 1px solid var(--c-ink-300);
  padding: var(--sp-6);
  display: flex;
  flex-direction: column;
  gap: var(--sp-4);
  background: #fff;
}

/* Right panel */
.dv__right {
  flex: 1;
  padding: var(--sp-6);
  display: flex;
  flex-direction: column;
  gap: var(--sp-6);
  overflow-y: auto;
}

.dv__panel-title {
  font-size: var(--fs-15);
  font-weight: 700;
  color: var(--c-ink-900);
  margin: 0 0 var(--sp-4);
}

/* Search */
.dv__search-wrap {
  position: relative;
  display: flex;
  align-items: center;
}
.dv__search-ico {
  position: absolute;
  left: var(--sp-3);
  color: var(--c-ink-500);
  pointer-events: none;
}
.dv__search-input {
  width: 100%;
  padding: .6rem var(--sp-3) .6rem 2.2rem;
  border: 1px solid var(--c-ink-300);
  border-radius: var(--r-md);
  font-size: var(--fs-14);
  color: var(--c-ink-900);
  background: #fff;
  outline: none;
  transition: border-color var(--t-fast);
}
.dv__search-input:focus { border-color: var(--c-role-dispensador); }

/* Paciente list */
.dv__paciente-list { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: 2px; overflow-y: auto; }
.dv__paciente-item {
  padding: var(--sp-3) var(--sp-4);
  border-radius: var(--r-md);
  cursor: pointer;
  transition: background var(--t-fast);
  border: 1px solid transparent;
}
.dv__paciente-item:hover { background: var(--c-leaf-50); }
.dv__paciente-item--selected {
  background: var(--c-leaf-100);
  border-color: var(--c-role-dispensador);
}
.dv__paciente-name { font-size: var(--fs-14); font-weight: 600; color: var(--c-ink-900); }
.dv__paciente-meta { display: flex; align-items: center; gap: var(--sp-2); margin-top: 2px; }
.dv__paciente-dni { font-family: var(--font-mono); font-size: var(--fs-12); color: var(--c-ink-500); }

/* REPROCANN badge */
.dv__reprocann-badge {
  font-size: 10px;
  font-weight: 700;
  padding: 1px 6px;
  border-radius: var(--r-pill);
  text-transform: uppercase;
  letter-spacing: .03em;
}
.dv__reprocann-badge--green { background: #d1fae5; color: #065f46; }
.dv__reprocann-badge--amber { background: var(--c-amber-100); color: var(--c-amber-500); }
.dv__reprocann-badge--gray  { background: var(--c-ink-100); color: var(--c-ink-500); }

/* Placeholder */
.dv__placeholder {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: var(--sp-3);
  color: var(--c-ink-500);
  font-size: var(--fs-14);
  text-align: center;
}
.dv__placeholder-ico { color: var(--c-ink-300); }

/* Stock grid */
.dv__stock-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
  gap: var(--sp-3);
}
.dv__stock-card {
  background: #fff;
  border: 1px solid var(--c-ink-300);
  border-radius: var(--r-lg);
  padding: var(--sp-4);
  display: flex;
  flex-direction: column;
  gap: var(--sp-2);
}
.dv__stock-header { font-weight: 700; font-size: var(--fs-14); color: var(--c-ink-900); }
.dv__stock-lote   { font-family: var(--font-mono); font-size: var(--fs-12); color: var(--c-ink-500); }
.dv__stock-disponible { font-size: var(--fs-13); color: var(--c-leaf-600); }
.dv__stock-precio     { font-size: var(--fs-13); color: var(--c-role-dispensador); font-weight: 600; }
.dv__stock-add { display: flex; gap: var(--sp-2); align-items: center; margin-top: var(--sp-1); }
.dv__qty-input {
  width: 70px;
  padding: .35rem .5rem;
  border: 1px solid var(--c-ink-300);
  border-radius: var(--r-sm);
  font-size: var(--fs-13);
  text-align: right;
}
.dv__add-btn {
  display: flex; align-items: center; gap: 4px;
  padding: .35rem .6rem;
  background: var(--c-role-dispensador);
  color: #fff;
  border: none;
  border-radius: var(--r-sm);
  font-size: var(--fs-12);
  font-weight: 600;
  cursor: pointer;
  transition: opacity .15s;
  white-space: nowrap;
}
.dv__add-btn:hover { opacity: .88; }

/* Cart */
.dv__cart {
  background: #fff;
  border: 1px solid var(--c-ink-300);
  border-radius: var(--r-lg);
  padding: var(--sp-5);
}
.dv__cart-items { display: flex; flex-direction: column; gap: var(--sp-2); margin-bottom: var(--sp-4); }
.dv__cart-item {
  display: flex; align-items: center; gap: var(--sp-3);
  padding: var(--sp-2) var(--sp-3);
  background: var(--c-ink-100);
  border-radius: var(--r-md);
}
.dv__cart-desc { flex: 1; display: flex; gap: var(--sp-3); }
.dv__cart-forma { font-weight: 600; font-size: var(--fs-14); }
.dv__cart-qty   { font-family: var(--font-mono); font-size: var(--fs-13); color: var(--c-ink-500); }
.dv__cart-total { font-size: var(--fs-14); font-weight: 600; color: var(--c-role-dispensador); white-space: nowrap; }
.dv__cart-remove {
  background: none; border: none; cursor: pointer; color: var(--c-ink-500);
  display: flex; padding: 2px;
  transition: color var(--t-fast);
}
.dv__cart-remove:hover { color: var(--c-rust-600); }
.dv__cart-footer { display: flex; align-items: center; justify-content: space-between; gap: var(--sp-4); }
.dv__cart-sum { font-size: var(--fs-15); color: var(--c-ink-700); }
.dv__confirm-btn {
  padding: .6rem 1.4rem;
  background: var(--c-role-dispensador);
  color: #fff;
  border: none;
  border-radius: var(--r-md);
  font-size: var(--fs-14);
  font-weight: 700;
  cursor: pointer;
  transition: opacity .15s;
}
.dv__confirm-btn:hover { opacity: .88; }

/* Modal */
.dv__modal-overlay {
  position: fixed; inset: 0;
  background: rgba(0,0,0,.45);
  display: flex; align-items: center; justify-content: center;
  z-index: 600;
  padding: var(--sp-4);
}
.dv__modal {
  background: #fff;
  border-radius: var(--r-xl);
  width: 100%;
  max-width: 460px;
  box-shadow: 0 20px 60px rgba(0,0,0,.2);
}
.dv__modal-header {
  display: flex; align-items: center; justify-content: space-between;
  padding: var(--sp-5) var(--sp-6) var(--sp-4);
  border-bottom: 1px solid var(--c-ink-100);
}
.dv__modal-title { font-size: var(--fs-16); font-weight: 700; color: var(--c-ink-900); margin: 0; }
.dv__modal-close {
  background: none; border: none; cursor: pointer; color: var(--c-ink-500);
  display: flex; padding: 4px;
  border-radius: var(--r-sm);
  transition: color var(--t-fast), background var(--t-fast);
}
.dv__modal-close:hover { color: var(--c-ink-900); background: var(--c-ink-100); }
.dv__modal-body { padding: var(--sp-5) var(--sp-6); display: flex; flex-direction: column; gap: var(--sp-4); }
.dv__modal-paciente { display: flex; align-items: center; gap: var(--sp-2); font-size: var(--fs-14); color: var(--c-ink-700); }
.dv__modal-items { display: flex; flex-direction: column; gap: var(--sp-2); }
.dv__modal-item {
  display: flex; justify-content: space-between;
  font-size: var(--fs-14);
  padding: var(--sp-2) var(--sp-3);
  background: var(--c-ink-100);
  border-radius: var(--r-md);
}
.dv__modal-total {
  font-size: var(--fs-16);
  text-align: right;
  color: var(--c-ink-900);
  border-top: 1px solid var(--c-ink-100);
  padding-top: var(--sp-3);
}
.dv__label { font-size: var(--fs-13); font-weight: 600; color: var(--c-ink-700); display: block; margin-bottom: var(--sp-1); }
.dv__select {
  width: 100%;
  padding: .5rem var(--sp-3);
  border: 1px solid var(--c-ink-300);
  border-radius: var(--r-md);
  font-size: var(--fs-14);
  background: #fff;
  color: var(--c-ink-900);
}
.dv__modal-footer {
  display: flex; gap: var(--sp-3); justify-content: flex-end;
  padding: var(--sp-4) var(--sp-6);
  border-top: 1px solid var(--c-ink-100);
}
.dv__modal-cancel {
  padding: .55rem 1.1rem;
  border: 1px solid var(--c-ink-300);
  border-radius: var(--r-md);
  background: #fff;
  font-size: var(--fs-14);
  cursor: pointer;
  color: var(--c-ink-700);
  transition: background var(--t-fast);
}
.dv__modal-cancel:hover { background: var(--c-ink-100); }
.dv__modal-submit {
  padding: .55rem 1.4rem;
  background: var(--c-role-dispensador);
  color: #fff;
  border: none;
  border-radius: var(--r-md);
  font-size: var(--fs-14);
  font-weight: 700;
  cursor: pointer;
  transition: opacity .15s;
  display: flex; align-items: center; gap: var(--sp-2);
}
.dv__modal-submit:hover:not(:disabled) { opacity: .88; }
.dv__modal-submit:disabled { opacity: .6; cursor: not-allowed; }

/* Spinner */
.dv__spinner {
  width: 16px; height: 16px;
  border: 2px solid rgba(255,255,255,.4);
  border-top-color: #fff;
  border-radius: 50%;
  animation: spin .7s linear infinite;
}
@keyframes spin { to { transform: rotate(360deg); } }

/* Skeletons */
.dv__skel-list { display: flex; flex-direction: column; gap: var(--sp-2); }
.dv__skel { height: 52px; background: var(--c-ink-100); border-radius: var(--r-md); animation: pulse 1.4s ease-in-out infinite; }
.dv__skel--card { height: 140px; }
.dv__skel-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(200px, 1fr)); gap: var(--sp-3); }
@keyframes pulse { 0%,100%{opacity:1} 50%{opacity:.5} }

.dv__empty { font-size: var(--fs-14); color: var(--c-ink-500); padding: var(--sp-3) 0; }

/* Modal transition */
.modal-fade-enter-active, .modal-fade-leave-active { transition: opacity .2s; }
.modal-fade-enter-from, .modal-fade-leave-to { opacity: 0; }

/* Responsive */
@media (max-width: 767px) {
  .dv { flex-direction: column; }
  .dv__left { width: 100%; border-right: none; border-bottom: 1px solid var(--c-ink-300); }
}
</style>
