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
            <span v-if="!p.es_paciente" class="dv__badge--inactivo">Dado de baja</span>
            <span v-else class="dv__reprocann-badge" :class="reprocannClass(p)">{{ reprocannLabel(p) }}</span>
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
          <div v-if="pacienteDetalle" class="dv__ultima-dispensa">
            <template v-if="pacienteDetalle.ultima_dispensacion">
              Última dispensa:
              <strong>{{ pacienteDetalle.ultima_dispensacion.cantidad }}g de {{ formaLabel(pacienteDetalle.ultima_dispensacion.forma_producto) }}</strong>
              — {{ formatFecha(pacienteDetalle.ultima_dispensacion.fecha) }}
            </template>
            <template v-else>Sin dispensaciones previas</template>
          </div>
          <div v-else-if="loadingDetalle" class="dv__limite-loading">Cargando…</div>
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
              <div class="dv__stock-lote">{{ s.lote?.codigo ?? '—' }}<span v-if="s.sede?.nombre" class="dv__stock-sede"> · {{ s.sede.nombre }}</span></div>
              <div v-if="s.genetica?.nombre ?? s.lote?.genetica?.nombre" class="dv__stock-cepa">{{ s.genetica?.nombre ?? s.lote?.genetica?.nombre }}</div>
              <div class="dv__stock-disponible">{{ s.cantidad }}{{ s.unidad }} disponibles</div>
              <div class="dv__stock-precio">
                <template v-if="descuentoPaciente > 0 && s.precio_sugerido_ars">
                  <span class="dv__precio-original">{{ formatARS(s.precio_sugerido_ars) }}</span>
                  {{ formatARS(precioConDescuento(s.precio_sugerido_ars)) }}/{{ s.unidad }}
                  <span class="dv__descuento-badge">-{{ descuentoPaciente }}%</span>
                </template>
                <template v-else>{{ formatARS(s.precio_sugerido_ars) }}/{{ s.unidad }}</template>
              </div>
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
                <span class="dv__reprocann-badge" :class="reprocannClass(selectedPaciente)">{{ reprocannLabel(selectedPaciente) }}</span>
              </div>

              <!-- Bloqueo: paciente dado de baja -->
              <div v-if="!pacienteActivo" class="dv__modal-aviso dv__modal-aviso--error">
                <strong>Socio dado de baja.</strong> No se puede realizar una dispensación. Reactivá el socio desde la sección Socios antes de continuar.
              </div>

              <!-- Aviso REPROCANN -->
              <div v-if="reprocannVigente === false && pacienteActivo" class="dv__modal-aviso dv__modal-aviso--warn">
                <strong>Atención:</strong> el paciente {{ reprocannStatus(selectedPaciente) === 'vencido' ? 'tiene el REPROCANN vencido' : 'no tiene REPROCANN registrado' }}. Verificar habilitación antes de continuar.
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
                <div class="dv__medio-pago">
                  <button type="button" class="dv__mp-btn" :class="{ 'dv__mp-btn--active': medioPago === 'efectivo' }" @click="medioPago = 'efectivo'">
                    Efectivo
                  </button>
                  <button type="button" class="dv__mp-btn" :class="{ 'dv__mp-btn--active': medioPago === 'transferencia' }" @click="medioPago = 'transferencia'">
                    Transferencia
                  </button>
                  <button type="button" class="dv__mp-btn" :class="{ 'dv__mp-btn--active': medioPago === 'cuenta_corriente' }" :disabled="!tieneCc" :title="!tieneCc ? 'El paciente no tiene cuenta corriente configurada' : ''" @click="medioPago = 'cuenta_corriente'">
                    Cta. corriente
                  </button>
                  <button type="button" class="dv__mp-btn" :class="{ 'dv__mp-btn--active': medioPago === 'no_abona' }" :disabled="!tieneCc" :title="!tieneCc ? 'El paciente no tiene crédito configurado' : ''" @click="medioPago = 'no_abona'">
                    No abona
                  </button>
                </div>
              </div>

              <!-- Saldo CC — siempre visible cuando el paciente tiene crédito configurado -->
              <div v-if="tieneCc && ccBalance !== null" class="dv__balance-info" :class="{ 'dv__balance-info--alerta': ccBalance < cartTotal }">
                <span>Crédito disponible:</span>
                <strong>{{ formatARS(ccBalance) }}</strong>
                <span v-if="ccBalance < cartTotal" class="dv__balance-error">— crédito insuficiente</span>
              </div>


              <!-- Envío a domicilio -->
              <div class="dv__modal-field">
                <label class="dv__label-check">
                  <input type="checkbox" v-model="conEnvio" class="dv__checkbox" />
                  Envío a domicilio
                </label>
              </div>

              <div v-if="sinEntregadores" class="dv__aviso-delivery">
                <AlertTriangle :size="15" :stroke-width="2" class="dv__aviso-delivery-ico" />
                <div>
                  <strong>Sin repartidores configurados.</strong>
                  El paquete quedará pendiente de asignación. Podés crear un repartidor
                  desde <strong>Configuración → Equipo</strong> y asignarlo después en
                  <strong>Operaciones → Despachos</strong>.
                </div>
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
              <button class="dv__modal-submit" @click="submitDispensacion" :disabled="submitting || pagoExcedido || !pacienteActivo">
                <DsSpinner v-if="submitting" :size="16" />
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
import { ref, computed, watch, onMounted } from 'vue'
import { listPacientes, getPaciente, listStocks, listEntregadores } from '../lib/api.js'
import { dispensarOffline, cacheStock, getCachedStock, cacheSocios, getCachedSocios } from '../lib/offlineApi.js'
import { useNetwork } from '../composables/useNetwork.js'
import { formaLabel, formatARS, formatG, formatFecha } from '../lib/formatters.js'
import { useToast } from '../composables/useToast.js'
import { Search, Users, Plus, X, AlertTriangle } from 'lucide-vue-next'
import DsSpinner from '../design-system/components/Spinner.vue'

const { isOnline } = useNetwork()

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
const submitting      = ref(false)
const entregadores    = ref([])

const sinEntregadores = computed(() => conEnvio.value && entregadores.value.length === 0)

onMounted(async () => {
  try {
    const [entRes, pacRes] = await Promise.all([
      listEntregadores(),
      listPacientes({ limite: 50 }),
    ])
    entregadores.value = entRes.data.data ?? []
    pacientes.value    = pacRes.data.data ?? []
    cacheSocios(pacientes.value)
  } catch {}
})

let searchTimeout = null

watch(query, (val) => {
  clearTimeout(searchTimeout)
  if (!val.trim()) {
    // sin query → volver a mostrar lista inicial
    searchTimeout = setTimeout(() => buscarPacientes(''), 150)
    return
  }
  searchTimeout = setTimeout(() => buscarPacientes(val.trim()), 300)
})

async function buscarPacientes(q) {
  loadingPacientes.value = true
  try {
    const params = q ? { query: q, limite: 20 } : { limite: 50 }
    const { data } = await listPacientes(params)
    pacientes.value = data.data ?? []
    cacheSocios(pacientes.value)
  } catch {
    // Offline: usar caché
    const cached = getCachedSocios()
    if (cached) {
      const qLow = q.toLowerCase()
      pacientes.value = cached.filter(p =>
        p.nombre?.toLowerCase().includes(qLow) ||
        p.apellido?.toLowerCase().includes(qLow) ||
        p.dni?.includes(q)
      )
    } else {
      pacientes.value = []
    }
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
    const stockData = stockRes.data.stocks ?? stockRes.data ?? []
    stocks.value = stockData
    cacheStock(stockData)
  } catch {
    // Offline: servir desde caché
    const cached = getCachedStock()
    stocks.value = cached ?? []
    if (cached) toast.warning('Sin conexión — mostrando stock guardado localmente')
  } finally {
    loadingDetalle.value = false
    loadingStocks.value  = false
  }
}

const stocksDisponibles = computed(() =>
  stocks.value.filter(s => s.cantidad > 0 && s.estado !== 'pendiente_asignacion')
)

const cartTotal = computed(() => cart.value.reduce((s, i) => s + i.total, 0))

const tieneCc       = computed(() => (pacienteDetalle.value?.limite_cc ?? 0) > 0)

const ccBalance      = computed(() => {
  const saldo  = pacienteDetalle.value?.saldo_cc   ?? null
  const limite = pacienteDetalle.value?.limite_cc  ?? 0
  if (saldo === null) return null
  return saldo + limite
})
const ccExcedido     = computed(() =>
  tieneCc.value && ccBalance.value !== null && cartTotal.value > ccBalance.value
)
const pagoExcedido   = computed(() => ccExcedido.value)

const cartTotalG = computed(() => cart.value.filter(i => i.stock.unidad === 'g').reduce((s, i) => s + i.cantidad, 0))

// Estado del paciente
const pacienteActivo  = computed(() => pacienteDetalle.value?.es_paciente !== false)

// REPROCANN
const reprocannVigente = computed(() => reprocannStatus(selectedPaciente.value) === 'vigente')

const descuentoPaciente = computed(() => {
  const d = pacienteDetalle.value?.descuento_porcentaje
  return d != null && d > 0 ? Number(d) : 0
})

function precioConDescuento(precioBase) {
  if (!descuentoPaciente.value) return precioBase
  return precioBase * (1 - descuentoPaciente.value / 100)
}

function addToCart(s) {
  const qty = cantidades.value[s.id]
  if (!qty || qty <= 0) { toast.warning('Ingresá una cantidad'); return }

  const existente   = cart.value.find(i => i.stock.id === s.id)
  const yaEnCarrito = existente?.cantidad ?? 0

  if (qty + yaEnCarrito > s.cantidad) {
    const disponible = s.cantidad - yaEnCarrito
    toast.warning(`Stock insuficiente: ${disponible}${s.unidad} disponibles`)
    return
  }

  const precio = precioConDescuento(s.precio_sugerido_ars ?? 0)
  if (existente) {
    existente.cantidad += qty
    existente.total = existente.cantidad * precio
  } else {
    cart.value.push({ stock: s, cantidad: qty, total: qty * precio })
  }
  cantidades.value[s.id] = null
}

function removeFromCart(i) {
  cart.value.splice(i, 1)
}

function resetModal() {
  medioPago.value      = 'efectivo'
  conEnvio.value       = false
  direccionEnvio.value = ''
  contactoNombre.value = ''
  contactoTel.value    = ''
  observaciones.value  = ''
}

async function submitDispensacion() {
  if (!selectedPaciente.value || !cart.value.length) return

  // Bloquear si algún item del carrito tiene total = 0 (stock sin precio configurado)
  const sinPrecio = cart.value.filter(i => !(i.total > 0))
  if (sinPrecio.length) {
    toast.error(`Hay ítems sin precio configurado: ${sinPrecio.map(i => i.stock.nombre || i.stock.id).join(', ')}. Configurá el precio antes de dispensar.`)
    return
  }

  if (conEnvio.value) {
    if (!direccionEnvio.value.trim()) { toast.warning('Ingresá la dirección de entrega'); return }
    if (!contactoNombre.value.trim()) { toast.warning('Ingresá el nombre de contacto'); return }
  }
  submitting.value = true

  const today  = new Date().toISOString().slice(0, 10)
  const items  = [...cart.value]
  const results = await Promise.allSettled(
    items.map(item =>
      dispensarOffline(selectedPaciente.value.id, {
        stock_id:            item.stock.id,
        cantidad:            item.cantidad,
        precio_unitario_ars: precioConDescuento(item.stock.precio_sugerido_ars ?? 0),
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
        .then(res => ({ ok: true, item, _queued: res?.queued === true }))
        .catch(e => ({
          ok:  false,
          item,
          msg: e?.response?.data?.errors?.[0] || e?.response?.data?.error || 'Error al registrar',
        }))
    )
  )

  submitting.value = false

  const ok     = results.map(r => r.value).filter(v => v.ok).map(v => v.item)
  const errors = results.map(r => r.value).filter(v => !v.ok)

  if (ok.length > 0) {
    cart.value = cart.value.filter(i => !ok.includes(i))
    Promise.all([getPaciente(selectedPaciente.value.id), listStocks()])
      .then(([detRes, stockRes]) => {
        pacienteDetalle.value = detRes.data?.data ?? detRes.data ?? null
        stocks.value = stockRes.data.stocks ?? stockRes.data ?? []
      }).catch(() => {})
  }

  // Detectar items que fueron encolados (offline)
  const queued   = ok.filter(i => i._queued)
  const enviados = ok.filter(i => !i._queued)

  // Actualizar stock local inmediatamente para los items encolados
  if (queued.length) {
    queued.forEach(({ item }) => {
      const s = stocks.value.find(x => x.id === item.stock.id)
      if (s) s.cantidad = Math.max(0, (s.cantidad || 0) - item.cantidad)
    })
  }

  if (errors.length === 0) {
    if (queued.length > 0 && enviados.length === 0) {
      toast.warning(`Dispensación guardada localmente. Se enviará cuando haya conexión.`)
    } else if (queued.length > 0) {
      toast.warning(`${enviados.length} enviados, ${queued.length} guardados offline — se sincronizarán al reconectarse.`)
    } else {
      toast.success(`Dispensación registrada para ${selectedPaciente.value.nombre}`)
    }
    confirmOpen.value = false
    resetModal()
  } else if (ok.length === 0) {
    toast.error(errors[0].msg)
  } else {
    toast.warning(`${ok.length} de ${items.length} ítems registrados. ${errors[0].msg}`)
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
.dv__badge--inactivo {
  font-size: 10px; font-weight: 700; padding: 1px 6px;
  border-radius: var(--r-pill); text-transform: uppercase; letter-spacing: .03em;
  background: #fef2f2; color: #b91c1c;
}

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
/* Última dispensación (patient bar) */
.dv__ultima-dispensa {
  font-size: var(--fs-13);
  color: var(--c-ink-500);
  line-height: 1.4;
}
.dv__ultima-dispensa strong { color: var(--c-ink-800); }
.dv__limite-loading { font-size: var(--fs-12); color: var(--c-ink-400); }

/* Medio de pago buttons */
.dv__medio-pago { display: flex; gap: var(--sp-2); flex-wrap: wrap; }
.dv__mp-btn {
  flex: 1;
  min-width: 90px;
  padding: .55rem .875rem;
  border: 1.5px solid var(--c-ink-300);
  border-radius: var(--r-md);
  background: #fff;
  font-size: var(--fs-14);
  font-weight: 500;
  color: var(--c-ink-700);
  cursor: pointer;
  transition: all .15s;
  text-align: center;
}
.dv__mp-btn:hover:not(:disabled) { border-color: var(--c-role-dispensador); color: var(--c-role-dispensador); }
.dv__mp-btn--active {
  background: var(--c-role-dispensador);
  border-color: var(--c-role-dispensador);
  color: #fff;
  font-weight: 700;
}
.dv__mp-btn:disabled { opacity: .4; cursor: not-allowed; }

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
.dv__stock-precio     { font-size: var(--fs-13); color: var(--c-role-dispensador); font-weight: 600; display: flex; align-items: center; gap: .35rem; flex-wrap: wrap; }
.dv__precio-original  { text-decoration: line-through; color: #94a3b8; font-weight: 400; }
.dv__descuento-badge  { font-size: .65rem; font-weight: 800; background: #dcfce7; color: #15803d; padding: .1em .45em; border-radius: 5px; }
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

/* Límite mensual */
.dv__limite-mensual {
  background: var(--c-ink-50);
  border: 1px solid var(--c-ink-200);
  border-radius: var(--r-md);
  padding: var(--sp-3);
  display: flex;
  flex-direction: column;
  gap: var(--sp-2);
}
.dv__limite-mensual--alerta {
  background: #fff5f5;
  border-color: #fca5a5;
}
.dv__limite-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
}
.dv__limite-label {
  font-size: var(--fs-12);
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: .05em;
  color: var(--c-ink-500);
}
.dv__limite-nums {
  font-size: var(--fs-13);
  font-weight: 600;
  color: var(--c-ink-700);
  font-family: var(--font-mono);
}
.dv__limite-bar-track {
  height: 6px;
  background: var(--c-ink-200);
  border-radius: 99px;
  overflow: hidden;
}
.dv__limite-bar-fill {
  height: 100%;
  background: #16a34a;
  border-radius: 99px;
  transition: width .3s ease;
}
.dv__limite-mensual--alerta .dv__limite-bar-fill { background: #dc2626; }
.dv__limite-error {
  font-size: var(--fs-12);
  font-weight: 600;
  color: #dc2626;
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

/* Skeletons */
.dv__skel-list { display: flex; flex-direction: column; gap: var(--sp-2); }
.dv__skel { height: 52px; background: var(--c-ink-100); border-radius: var(--r-md); animation: pulse 1.4s ease-in-out infinite; }
.dv__skel--card { height: 140px; }
.dv__skel-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(200px, 1fr)); gap: var(--sp-3); }
@keyframes pulse { 0%,100%{opacity:1} 50%{opacity:.5} }

.dv__empty { font-size: var(--fs-14); color: var(--c-ink-500); padding: var(--sp-3) 0; }

/* Sede label en stock card */
.dv__stock-sede { color: var(--c-ink-400); font-size: var(--fs-11); }
.dv__stock-cepa { font-size: var(--fs-12); color: var(--c-ink-600); font-style: italic; }

/* CC / gramos balance info */
.dv__balance-info {
  display: flex; align-items: center; gap: var(--sp-2); flex-wrap: wrap;
  padding: var(--sp-2) var(--sp-3);
  background: var(--c-ink-50);
  border: 1px solid var(--c-ink-200);
  border-radius: var(--r-md);
  font-size: var(--fs-13); color: var(--c-ink-700);
}
.dv__balance-info--alerta { background: #fff5f5; border-color: #fca5a5; color: #991b1b; }
.dv__balance-error { font-weight: 700; color: #dc2626; }

/* Avisos en modal */
.dv__modal-aviso {
  border-radius: var(--r-md);
  padding: var(--sp-3) var(--sp-4);
  font-size: var(--fs-13);
  line-height: 1.45;
}
.dv__modal-aviso--warn  { background: #fffbeb; border: 1px solid #fde68a; color: #92400e; }
.dv__modal-aviso--error { background: #fef2f2; border: 1px solid #fecaca; color: #991b1b; }

.dv__aviso-delivery {
  display: flex;
  gap: var(--sp-3);
  align-items: flex-start;
  background: #eff6ff;
  border: 1px solid #bfdbfe;
  color: #1e40af;
  border-radius: var(--r-md);
  padding: var(--sp-3) var(--sp-4);
  font-size: var(--fs-13);
  line-height: 1.5;
}
.dv__aviso-delivery-ico { flex-shrink: 0; margin-top: 1px; }

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
