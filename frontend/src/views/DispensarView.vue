<template>
  <div class="dv">

    <!-- Left: Patient search -->
    <aside class="dv__left">
      <div class="dv__search-wrap">
        <Search :size="16" :stroke-width="1.75" class="dv__search-ico" />
        <input
          v-model="query"
          type="search"
          class="dv__search-input"
          placeholder="Buscar paciente…"
          autocomplete="off"
        />
      </div>

      <div v-if="loadingPacientes" class="dv__skel-list">
        <div class="dv__skel" v-for="n in 5" :key="n" />
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
            <span class="dv__reprocann-badge" :class="reprocannClass(p)">{{ reprocannLabel(p) }}</span>
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

        <!-- Patient info bar -->
        <div class="dv__paciente-bar">
          <div class="dv__paciente-bar-left">
            <span class="dv__paciente-bar-name">{{ selectedPaciente.nombre }} {{ selectedPaciente.apellido }}</span>
            <span class="dv__reprocann-badge" :class="reprocannClass(selectedPaciente)">{{ reprocannLabel(selectedPaciente) }}</span>
          </div>
          <div v-if="pacienteDetalle" class="dv__limite-wrap">
            <div class="dv__limite-row">
              <span class="dv__limite-label">Límite mensual</span>
              <span class="dv__limite-nums" :class="{ 'dv__limite-nums--warn': limiteExcedidoConCarrito }">
                {{ formatG(limiteUsadoConCarrito) }} / {{ formatG(pacienteDetalle.limite_dispensacion_mensual_g) }}
              </span>
            </div>
            <div class="dv__limite-bar-track">
              <div class="dv__limite-bar-usado" :style="{ width: `${Math.min(100, pctUsado)}%` }" />
              <div
                v-if="cartGramos > 0"
                class="dv__limite-bar-carrito"
                :class="{ 'dv__limite-bar-carrito--warn': limiteExcedidoConCarrito }"
                :style="{ width: `${Math.min(100 - Math.min(100, pctUsado), pctCarrito)}%` }"
              />
            </div>
            <div v-if="limiteExcedidoConCarrito" class="dv__limite-alerta">
              <AlertTriangle :size="13" :stroke-width="2" /> El carrito supera el límite mensual disponible
            </div>
          </div>
          <div v-else-if="loadingDetalle" class="dv__limite-loading">Cargando límites…</div>
        </div>

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
            <div v-for="s in stocksDisponibles" :key="s.id" class="dv__stock-card">
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

              <!-- Medio de pago -->
              <div class="dv__modal-field">
                <label class="dv__label">Medio de pago</label>
                <select v-model="medioPago" class="dv__select">
                  <option value="efectivo">Efectivo</option>
                  <option value="transferencia">Transferencia</option>
                  <option value="debito">Débito</option>
                  <option value="credito">Crédito</option>
                </select>
              </div>

              <!-- Envío a domicilio -->
              <div class="dv__modal-field">
                <label class="dv__label-check">
                  <input type="checkbox" v-model="conEnvio" class="dv__checkbox" />
                  Envío a domicilio
                </label>
              </div>

              <template v-if="conEnvio">
                <div class="dv__modal-field">
                  <label class="dv__label">Dirección de entrega</label>
                  <input v-model="direccionEnvio" type="text" class="dv__input" placeholder="Av. Corrientes 1234, CABA" />
                </div>
                <div class="dv__modal-row">
                  <div class="dv__modal-field">
                    <label class="dv__label">Nombre de contacto</label>
                    <input v-model="contactoNombre" type="text" class="dv__input" placeholder="Nombre" />
                  </div>
                  <div class="dv__modal-field">
                    <label class="dv__label">Teléfono</label>
                    <input v-model="contactoTel" type="tel" class="dv__input" placeholder="+54 11 …" />
                  </div>
                </div>
              </template>

              <!-- Observaciones -->
              <div class="dv__modal-field">
                <label class="dv__label">Observaciones <span class="dv__label-opt">(opcional)</span></label>
                <textarea v-model="observaciones" class="dv__textarea" rows="2" placeholder="Notas internas…" />
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
import { listPacientes, getPaciente, listStocks, createDispensacion } from '../lib/api.js'
import { useToast } from '../composables/useToast.js'
import { Search, Users, Plus, X, AlertTriangle } from 'lucide-vue-next'

const toast = useToast()

const query            = ref('')
const pacientes        = ref([])
const loadingPacientes = ref(false)
const selectedPaciente = ref(null)
const pacienteDetalle  = ref(null)
const loadingDetalle   = ref(false)

const stocks       = ref([])
const loadingStocks = ref(false)
const cantidades   = ref({})

const cart       = ref([])
const confirmOpen = ref(false)
const medioPago  = ref('efectivo')
const conEnvio   = ref(false)
const direccionEnvio = ref('')
const contactoNombre = ref('')
const contactoTel    = ref('')
const observaciones  = ref('')
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
  pacienteDetalle.value  = null
  cart.value    = []
  cantidades.value = {}

  // Cargar detalle completo (límites, dispensado_mes_actual_g)
  loadingDetalle.value = true
  loadingStocks.value  = true
  try {
    const [detRes, stockRes] = await Promise.all([
      getPaciente(p.id),
      listStocks(),
    ])
    pacienteDetalle.value = detRes.data?.data ?? detRes.data ?? null
    stocks.value = stockRes.data.stocks ?? stockRes.data ?? []
  } catch {
    stocks.value = []
  } finally {
    loadingDetalle.value = false
    loadingStocks.value  = false
  }
}

const stocksDisponibles = computed(() => stocks.value.filter(s => s.cantidad > 0))

const cartTotal = computed(() => cart.value.reduce((s, i) => s + i.total, 0))

const cartGramos = computed(() =>
  cart.value.filter(i => i.stock.unidad === 'g').reduce((s, i) => s + i.cantidad, 0)
)

const limiteUsadoConCarrito = computed(() => {
  const base = Number(pacienteDetalle.value?.dispensado_mes_actual_g ?? 0)
  return base + cartGramos.value
})

const pctUsado = computed(() => {
  const limite = Number(pacienteDetalle.value?.limite_dispensacion_mensual_g)
  if (!limite) return 0
  return (Number(pacienteDetalle.value?.dispensado_mes_actual_g ?? 0) / limite) * 100
})

const pctCarrito = computed(() => {
  const limite = Number(pacienteDetalle.value?.limite_dispensacion_mensual_g)
  if (!limite || !cartGramos.value) return 0
  return (cartGramos.value / limite) * 100
})

const limiteExcedidoConCarrito = computed(() => {
  const limite = Number(pacienteDetalle.value?.limite_dispensacion_mensual_g)
  if (!limite) return false
  return limiteUsadoConCarrito.value > limite
})

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
        stock_id:            item.stock.id,
        cantidad:            item.cantidad,
        precio_unitario_ars: item.stock.precio_sugerido_ars,
        aporte_socio_ars:    item.total,
        fecha_dispensacion:  today,
        medio_pago:          medioPago.value,
        con_envio:           conEnvio.value,
        ...(conEnvio.value ? {
          direccion_envio:   direccionEnvio.value,
          contacto_nombre:   contactoNombre.value,
          contacto_telefono: contactoTel.value,
        } : {}),
        ...(observaciones.value.trim() ? { observaciones: observaciones.value.trim() } : {}),
      })
    ))
    toast.success(`Dispensación registrada para ${selectedPaciente.value.nombre}`)
    cart.value      = []
    confirmOpen.value = false
    conEnvio.value    = false
    direccionEnvio.value = ''
    contactoNombre.value = ''
    contactoTel.value    = ''
    observaciones.value  = ''
    // Refrescar detalle del paciente para actualizar la barra
    if (selectedPaciente.value) {
      getPaciente(selectedPaciente.value.id)
        .then(r => { pacienteDetalle.value = r.data?.data ?? r.data ?? null })
        .catch(() => {})
    }
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
function formatG(g) {
  if (g == null) return '—'
  return `${Number(g).toLocaleString('es-AR', { maximumFractionDigits: 1 })} g`
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
  gap: var(--sp-5);
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

/* Patient info bar */
.dv__paciente-bar {
  background: #fff;
  border: 1px solid var(--c-ink-200);
  border-radius: var(--r-lg);
  padding: var(--sp-4) var(--sp-5);
  display: flex;
  flex-direction: column;
  gap: var(--sp-3);
}
.dv__paciente-bar-left {
  display: flex;
  align-items: center;
  gap: var(--sp-2);
  flex-wrap: wrap;
}
.dv__paciente-bar-name {
  font-size: var(--fs-15);
  font-weight: 700;
  color: var(--c-ink-900);
}
.dv__limite-wrap { display: flex; flex-direction: column; gap: var(--sp-1); }
.dv__limite-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
}
.dv__limite-label { font-size: var(--fs-12); font-weight: 600; color: var(--c-ink-500); text-transform: uppercase; letter-spacing: .04em; }
.dv__limite-nums { font-family: var(--font-mono); font-size: var(--fs-13); font-weight: 600; color: var(--c-ink-700); }
.dv__limite-nums--warn { color: var(--c-rust-600); }

.dv__limite-bar-track {
  height: 8px;
  background: var(--c-ink-100);
  border-radius: 999px;
  overflow: hidden;
  display: flex;
}
.dv__limite-bar-usado {
  height: 100%;
  background: var(--c-role-dispensador);
  border-radius: 999px;
  transition: width .3s ease;
}
.dv__limite-bar-carrito {
  height: 100%;
  background: rgba(74, 142, 166, 0.5);
  transition: width .3s ease;
}
.dv__limite-bar-carrito--warn { background: rgba(220, 38, 38, 0.5); }
.dv__limite-alerta {
  display: flex;
  align-items: center;
  gap: var(--sp-1);
  font-size: var(--fs-12);
  font-weight: 600;
  color: var(--c-rust-600);
}
.dv__limite-loading { font-size: var(--fs-12); color: var(--c-ink-400); }

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
  max-width: 500px;
  max-height: 90vh;
  overflow-y: auto;
  box-shadow: 0 20px 60px rgba(0,0,0,.2);
}
.dv__modal-header {
  display: flex; align-items: center; justify-content: space-between;
  padding: var(--sp-5) var(--sp-6) var(--sp-4);
  border-bottom: 1px solid var(--c-ink-100);
  position: sticky; top: 0; background: #fff; z-index: 1;
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
.dv__modal-row { display: grid; grid-template-columns: 1fr 1fr; gap: var(--sp-3); }
.dv__modal-field { display: flex; flex-direction: column; gap: var(--sp-1); }
.dv__label { font-size: var(--fs-13); font-weight: 600; color: var(--c-ink-700); }
.dv__label-opt { font-weight: 400; color: var(--c-ink-400); }
.dv__label-check { display: flex; align-items: center; gap: var(--sp-2); font-size: var(--fs-14); font-weight: 500; color: var(--c-ink-800); cursor: pointer; }
.dv__checkbox { width: 16px; height: 16px; accent-color: var(--c-role-dispensador); cursor: pointer; }
.dv__select, .dv__input {
  width: 100%;
  padding: .5rem var(--sp-3);
  border: 1px solid var(--c-ink-300);
  border-radius: var(--r-md);
  font-size: var(--fs-14);
  background: #fff;
  color: var(--c-ink-900);
  box-sizing: border-box;
}
.dv__select:focus, .dv__input:focus { outline: none; border-color: var(--c-role-dispensador); }
.dv__textarea {
  width: 100%;
  padding: .5rem var(--sp-3);
  border: 1px solid var(--c-ink-300);
  border-radius: var(--r-md);
  font-size: var(--fs-14);
  background: #fff;
  color: var(--c-ink-900);
  resize: vertical;
  min-height: 60px;
  font-family: inherit;
  box-sizing: border-box;
}
.dv__textarea:focus { outline: none; border-color: var(--c-role-dispensador); }
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
  .dv__modal-row { grid-template-columns: 1fr; }
}
</style>
