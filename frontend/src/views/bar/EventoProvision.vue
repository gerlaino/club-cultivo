<script setup>
// Provisión de mercadería de un evento. Buscás entre todos los depósitos (salón, cultivo,
// general y dispensario), el sistema te dice qué falta comprar, reservás y al cerrar el sobrante
// vuelve. Lo del dispensario (flor, derivados y stock externo) NO se descuenta al reservarlo:
// queda APARTADO (nadie más lo puede dispensar) y sale del inventario recién al dispensarse.
import { ref, computed, onMounted } from 'vue'
import { RouterLink } from 'vue-router'
import { listProvisiones, buscarProvisiones, upsertProvision, updateProvision, deleteProvision,
  reservarProvision, cerrarProvision, comprarBarProducto } from '../../lib/api.js'
import { useToast } from '../../composables/useToast.js'
import { useConfirm } from '../../composables/useConfirm.js'

const props = defineProps({
  barId: { required: true },
  evId:  { required: true },
  finalizado: { type: Boolean, default: false },
  // Los SERVICIOS contratados (DJ, sonido, seguridad) viven en el padre porque asientan en el libro
  // contable al marcarse pagados. Se reciben acá para mostrarlos en la MISMA lista que la
  // mercadería: para quien arma el evento es una sola cosa —"lo que necesito"—, y tenerlos en dos
  // cajas separadas, con dos vocabularios, era el nudo del diseño viejo.
  costos: { type: Array, default: () => [] },
  fase:   { type: String, default: 'plan' },   // 'plan' | 'curso' | 'cerrado'
})
const emit = defineEmits(['cambio', 'crear-costo', 'toggle-pagado', 'borrar-costo'])
const toast = useToast()
const { confirm } = useConfirm()

const items   = ref([]) // provisiones
const loading = ref(false)
const saving  = ref(false)

const fmt = (n) => `$${Math.round(n || 0).toLocaleString('es-AR')}`
const totalComprar = computed(() => items.value.reduce((a, p) => a + (p.faltante || 0) * (p.costo_ars || 0), 0))
const hayFaltante  = computed(() => items.value.some(p => p.faltante > 0))
const hayReservado = computed(() => items.value.some(p => p.cantidad_reservada > p.cantidad_consumida))

// Una sola lista: primero lo que sale de un depósito, después los servicios contratados.
const filas = computed(() => [
  ...items.value.map(p => ({ ...p, clase: 'mercaderia', orden: 0 })),
  ...props.costos.map(c => ({ ...c, clase: 'servicio', orden: 1 })),
])
const hayAlgo    = computed(() => filas.value.length > 0)
const totalCostos = computed(() => props.costos.reduce((a, c) => a + Number(c.monto_ars || 0), 0))
const comprometido = computed(() => totalCostos.value + totalComprar.value)
const porComprar   = computed(() => items.value.filter(p => p.faltante > 0).length)
const pagosPendientes = computed(() => props.costos.filter(c => !c.pagado).length)

const DEP = { salon: 'Salón', cultivo: 'Cultivo', general: 'General', dispensacion: 'Dispensario', externo: 'Externo' }
const depLabel = (d) => DEP[d] || d
const advertencias = ref([])

async function cargar() {
  loading.value = true
  try {
    const { data } = await listProvisiones(props.barId, props.evId)
    items.value = data?.provisiones || []
  } catch { /* sin bar */ }
  finally { loading.value = false }
}
onMounted(cargar)

// ── Agregar: buscador unificado entre los 3 depósitos ─────────
const addOpen      = ref(false)
const buscarQ      = ref('')
const resultados   = ref([])
const buscando     = ref(false)
const seleccionado = ref(null)
const addCantidad  = ref(null)
let buscarTimer = null

function abrirAdd() {
  addOpen.value = true; buscarQ.value = ''; resultados.value = []
  seleccionado.value = null; addCantidad.value = null
  buscar()
}
function cerrarAdd() { addOpen.value = false }
function onBuscar() { clearTimeout(buscarTimer); buscarTimer = setTimeout(buscar, 250) }
const claveUsada = (r) => `${r.provisionable_type}-${r.provisionable_id}`
async function buscar() {
  buscando.value = true
  try {
    const { data } = await buscarProvisiones(props.barId, props.evId, buscarQ.value)
    const usados = new Set(items.value.map(claveUsada))
    resultados.value = (data.resultados || []).filter(r => !usados.has(claveUsada(r)))
  } catch { resultados.value = [] }
  finally { buscando.value = false }
}
function seleccionar(r) { seleccionado.value = r; addCantidad.value = null }
async function confirmarAdd() {
  if (!seleccionado.value || !(addCantidad.value > 0)) { toast.warning('Elegí un producto y la cantidad'); return }
  saving.value = true
  try {
    await upsertProvision(props.barId, props.evId, {
      provisionable_type: seleccionado.value.provisionable_type,
      provisionable_id:   seleccionado.value.provisionable_id,
      cantidad_prevista:  addCantidad.value,
    })
    addOpen.value = false; await cargar()
  } catch (e) { toast.error(e?.response?.data?.error || 'No se pudo agregar') }
  finally { saving.value = false }
}

async function editarPrevista(p, val) {
  const n = Number(val)
  if (!(n >= 0) || n === p.cantidad_prevista) return
  try { await updateProvision(props.barId, props.evId, p.id, { cantidad_prevista: n }); await cargar() }
  catch (e) { toast.error(e?.response?.data?.error || 'No se pudo actualizar') }
}
async function quitar(p) {
  if (!(await confirm({ title: 'Quitar de la provisión', message: `¿Quitar "${p.nombre}"?`, variant: 'danger' }))) return
  try { await deleteProvision(props.barId, props.evId, p.id); await cargar() }
  catch (e) { toast.error(e?.response?.data?.error || 'No se pudo quitar') }
}

// ── Comprar faltante del SALÓN (por fila). Los insumos entran por Nuevo movimiento. ──
const compraForm = ref(null)
function abrirCompra(p) { compraForm.value = { prov: p, cantidad: p.faltante, costo_total_ars: null } }
async function confirmarCompra() {
  const f = compraForm.value
  if (!(f.cantidad > 0) || !(f.costo_total_ars > 0)) { toast.warning('Completá cantidad y costo'); return }
  saving.value = true
  try {
    await comprarBarProducto(props.barId, f.prov.bar_producto_id, { cantidad: f.cantidad, costo_total_ars: f.costo_total_ars })
    compraForm.value = null; await cargar(); emit('cambio')
  } catch (e) { toast.error(e?.response?.data?.error || 'No se pudo comprar') }
  finally { saving.value = false }
}

// ── Reservar ──────────────────────────────────────────────────
// Reserva PARCIAL: aparta de cada ítem lo que haya. Lo que no alcanzó vuelve como advertencia
// (comprás el faltante y volvés a tocar Reservar; lo ya reservado no se duplica).
async function reservar() {
  saving.value = true
  try {
    const { data } = await reservarProvision(props.barId, props.evId)
    items.value = data.provisiones || items.value
    advertencias.value = data.advertencias || []
    if (advertencias.value.length) toast.warning('Se reservó lo disponible: quedó faltante')
    else toast.success('Stock reservado para el evento')
    emit('cambio')
  } catch (e) { toast.error(e?.response?.data?.error || 'No se pudo reservar') }
  finally { saving.value = false }
}

// ── Agregar: una sola puerta, que pregunta QUÉ estás sumando ──
// Antes había dos botones en dos secciones distintas ("+ Producto" acá, "+ Costo" más abajo).
const queAgrego  = ref(null)     // null | 'mercaderia' | 'servicio'
const costoForm  = ref(null)
function abrirAgregar() { queAgrego.value = null; costoForm.value = null; addOpen.value = false; queAgrego.value = 'elegir' }
function elegirMercaderia() { queAgrego.value = null; abrirAdd() }
function elegirServicio()   { queAgrego.value = null; costoForm.value = { concepto: '', proveedor: '', monto_ars: null, pagado: false } }
function guardarCosto() {
  const f = costoForm.value
  if (!f.concepto?.trim() || !(f.monto_ars > 0)) { toast.warning('Poné el concepto y el monto'); return }
  emit('crear-costo', { ...f, concepto: f.concepto.trim() })
  costoForm.value = null
}

// ── Rendición ─────────────────────────────────────────────────
// Los tres destinos conviven en un mismo evento: se vende, se consume y sobra. Pero el usuario
// declara UN SOLO número por fila —lo consumido sin vender—: lo vendido/dispensado lo acumula el
// sistema durante el evento y el sobrante se deriva (reservado − vendido − consumido).
const cierreForm = ref(null)
function abrirCierre() {
  cierreForm.value = items.value
    .filter(p => p.cantidad_reservada > 0)
    // Default = lo YA consumido (lo que registró el POS), no "consumí todo". Así el sobrante
    // real queda a la vista y no se te escapa devolverlo.
    // En lo APARTADO (dispensario) lo dispensado durante el evento ya vino imputado solo: acá
    // solo se declara lo que se consumió SIN dispensar (degustación, muestra).
    .map(p => ({
      id: p.id, nombre: p.nombre, apartado: p.apartado,
      reservada: p.cantidad_reservada, unidad: p.unidad,
      // Lo que ya salió por su canal durante el evento: vendido en el POS (mercadería del salón) o
      // dispensado a socios (dispensario). En los dos casos vive en `cantidad_consumida`.
      dispensada: p.cantidad_consumida || 0,
      consumoInterno: 0,
    }))
}
// Los tres destinos: vendido (lo sabe el sistema) + consumido sin vender (lo declara el usuario) +
// sobrante, que es el resto y vuelve al depósito.
function salidoDe(f) { return (f.dispensada || 0) + (Number(f.consumoInterno) || 0) }
function sobranteFila(f) { return Math.max(0, f.reservada - salidoDe(f)) }
function excedida(f)     { return salidoDe(f) > f.reservada }
const hayExcedida = computed(() => (cierreForm.value || []).some(excedida))

async function confirmarCierre(finalizar) {
  saving.value = true
  try {
    // Los dos caminos del back NO son simétricos y hay que respetarlos o el stock se rompe:
    //   • mercadería que descuenta → usa `cantidad_consumida` como TOTAL absoluto (reemplaza), así
    //     que va lo vendido + lo consumido sin vender, y devuelve el resto.
    //   • apartado (dispensario)   → usa `consumo_interno` y lo SUMA a lo ya dispensado; ahí va
    //     solo lo declarado, o estaríamos contando dos veces lo que ya salió por su canal.
    const consumos = cierreForm.value.map(f => ({
      id: f.id,
      cantidad_consumida: salidoDe(f),
      consumo_interno:    Number(f.consumoInterno) || 0,
    }))
    await cerrarProvision(props.barId, props.evId, { consumos, finalizar })
    cierreForm.value = null; await cargar(); emit('cambio')
    toast.success(finalizar ? 'Evento cerrado, sobrante devuelto al depósito' : 'Sobrante devuelto al depósito')
  } catch (e) { toast.error(e?.response?.data?.error || 'No se pudo cerrar') }
  finally { saving.value = false }
}
</script>

<template>
  <section class="pv">
    <div class="pv__head">
      <div>
        <h3 class="pv__title">Qué necesito</h3>
        <p class="pv__sub">Todo junto: la mercadería que sale de los depósitos y los servicios que contratás. De lo que sale de un depósito, el sistema te dice qué falta comprar; lo del dispensario no se descuenta, queda <b>apartado</b> hasta que se dispensa.</p>
      </div>
      <button v-if="!finalizado" class="btn btn--sm btn--primary" @click="abrirAgregar">+ Agregar</button>
    </div>

    <div v-if="loading" class="pv__empty">Cargando…</div>
    <div v-else-if="!hayAlgo" class="pv__empty pv__empty--box">
      Todavía no cargaste nada. Tocá <b>+ Agregar</b>: puede ser mercadería de un depósito o un servicio que contrates.
    </div>

    <template v-else>
      <div class="pv__table-wrap">
        <table class="pv__table">
          <thead><tr><th>Qué</th><th>De dónde</th><th class="r">Necesito</th><th class="r">Hay</th><th class="r">Estado</th><th></th></tr></thead>
          <tbody>
            <tr v-for="f in filas" :key="`${f.clase}-${f.id}`">
              <!-- Mercadería: sale de un depósito, se reserva y el sobrante vuelve -->
              <template v-if="f.clase === 'mercaderia'">
                <td class="strong">
                  {{ f.nombre }}
                  <span v-if="f.apartado" class="pv__tag" title="Se bloquea la cantidad para el evento, pero no sale del inventario: el stock del dispensario sale recién al dispensarse.">apartado</span>
                </td>
                <td><span class="pv__dep" :class="`pv__dep--${f.deposito}`">{{ depLabel(f.deposito) }}</span></td>
                <td class="r">
                  <input v-if="!finalizado" type="number" min="0" class="pv__inp-sm" :value="f.cantidad_prevista" @change="editarPrevista(f, $event.target.value)" />
                  <span v-else>{{ f.cantidad_prevista }}</span>
                  <small class="pv__u">{{ f.unidad }}</small>
                </td>
                <td class="r num">{{ f.en_deposito }} <small class="pv__u">{{ f.unidad }}</small></td>
                <td class="r">
                  <span v-if="f.faltante > 0" class="pv__falta">faltan {{ f.faltante }}</span>
                  <span v-else-if="f.cantidad_reservada > 0" class="pv__ok">{{ f.apartado ? 'apartado' : 'reservado' }}</span>
                  <span v-else class="pv__ok">listo</span>
                </td>
                <td class="r acts">
                  <template v-if="!finalizado && f.faltante > 0">
                    <button v-if="f.deposito === 'salon'" class="lnk" @click="abrirCompra(f)">Comprar</button>
                    <RouterLink v-else-if="f.deposito === 'dispensacion' || f.deposito === 'externo'" :to="{ name: 'admin-stock' }" class="lnk" title="El stock del dispensario se repone desde el inventario">Ver stock</RouterLink>
                    <RouterLink v-else :to="{ name: 'contabilidad' }" class="lnk" title="El stock de insumos entra al registrar la compra como movimiento">Registrar</RouterLink>
                  </template>
                  <button v-if="!finalizado && f.cantidad_reservada <= f.cantidad_consumida" class="lnk lnk--danger" @click="quitar(f)">Quitar</button>
                </td>
              </template>

              <!-- Servicio contratado: no sale de ningún depósito, se paga -->
              <template v-else>
                <td class="strong">
                  {{ f.concepto }}
                  <small v-if="f.proveedor" class="pv__prov">{{ f.proveedor }}</small>
                </td>
                <td><span class="pv__dep pv__dep--servicio">Servicio</span></td>
                <td class="r num">{{ fmt(f.monto_ars) }}</td>
                <td class="r"></td>
                <td class="r">
                  <button v-if="!finalizado" class="pv__pago" :class="f.pagado ? 'pv__pago--ok' : 'pv__pago--no'"
                          @click="emit('toggle-pagado', f)">
                    {{ f.pagado ? 'pagado' : 'sin pagar' }}
                  </button>
                  <span v-else class="pv__ok">{{ f.pagado ? 'pagado' : 'sin pagar' }}</span>
                </td>
                <td class="r acts">
                  <button v-if="!finalizado" class="lnk lnk--danger" @click="emit('borrar-costo', f)">Quitar</button>
                </td>
              </template>
            </tr>
          </tbody>
        </table>
      </div>

      <ul v-if="advertencias.length" class="pv__warn">
        <li v-for="(a, i) in advertencias" :key="i">{{ a }}</li>
      </ul>

      <div class="pv__foot">
        <!-- Una línea con lo que hay, en vez de cuatro tarjetas en $0 -->
        <div class="pv__summary">
          <template v-if="comprometido > 0">Comprometido <b>{{ fmt(comprometido) }}</b></template>
          <template v-else>Sin costos todavía</template>
          <template v-if="porComprar"> · {{ porComprar }} por comprar</template>
          <template v-if="pagosPendientes"> · {{ pagosPendientes }} {{ pagosPendientes === 1 ? 'pago pendiente' : 'pagos pendientes' }}</template>
        </div>
        <div class="pv__actions" v-if="!finalizado && items.length">
          <button class="btn btn--sm" :disabled="saving" @click="reservar"
                  :title="hayFaltante ? 'Aparta lo que hay ahora; el faltante lo reservás después de comprarlo' : ''">
            {{ hayFaltante ? 'Reservar lo disponible' : 'Reservar' }}
          </button>
          <button class="btn btn--sm btn--primary" :disabled="saving || !hayReservado" @click="abrirCierre">Rendición</button>
        </div>
      </div>
    </template>

    <!-- Los modales van teleportados a body, como el resto de la app: renderizados inline quedaban
         a merced del contexto de apilamiento del contenedor (velo visible, caja no). -->
    <Teleport to="body">

    <!-- Qué estoy agregando: una sola puerta para mercadería y servicios -->
    <div v-if="queAgrego === 'elegir'" class="ov" @click.self="queAgrego = null">
      <div class="modal">
        <h3 class="modal__title">¿Qué estás sumando?</h3>
        <div class="pv__pick">
          <button class="pv__pick-b" @click="elegirMercaderia">
            <b>Mercadería</b>
            <small>Sale de un depósito: salón, cultivo, general o dispensario. Se reserva y el sobrante vuelve.</small>
          </button>
          <button class="pv__pick-b" @click="elegirServicio">
            <b>Servicio contratado</b>
            <small>DJ, sonido, seguridad, fletes. Tiene proveedor y monto, y se paga.</small>
          </button>
        </div>
        <div class="modal__actions"><button class="btn" @click="queAgrego = null">Cancelar</button></div>
      </div>
    </div>

    <!-- Alta de servicio -->
    <div v-if="costoForm" class="ov" @click.self="costoForm = null">
      <div class="modal">
        <h3 class="modal__title">Servicio contratado</h3>
        <p class="modal__hint">Cuando lo marques pagado, se asienta como egreso del evento en el libro contable.</p>
        <label class="fld">Qué es<input v-model.trim="costoForm.concepto" class="inp" placeholder="Ej: DJ" maxlength="80" /></label>
        <label class="fld">Proveedor (opcional)<input v-model.trim="costoForm.proveedor" class="inp" placeholder="Ej: Sonido Norte" maxlength="80" /></label>
        <label class="fld">Monto<input v-model.number="costoForm.monto_ars" type="number" min="0" step="any" class="inp" placeholder="$" /></label>
        <label class="pv__chk"><input type="checkbox" v-model="costoForm.pagado" /> Ya está pagado</label>
        <div class="modal__actions">
          <button class="btn" @click="costoForm = null">Cancelar</button>
          <button class="btn btn--primary" @click="guardarCosto">Agregar</button>
        </div>
      </div>
    </div>

    <!-- Modal agregar: buscador unificado -->
    <div v-if="addOpen" class="ov" @click.self="cerrarAdd">
      <div class="modal">
        <h3 class="modal__title">Agregar a la provisión</h3>
        <p class="modal__hint">Buscá en todos los depósitos: salón, cultivo, general y dispensario.</p>
        <input v-model="buscarQ" @input="onBuscar" class="inp" placeholder="Buscar producto, insumo o stock…" />
        <div class="pv__res">
          <div v-if="buscando" class="pv__res-empty">Buscando…</div>
          <button
            v-for="r in resultados" :key="claveUsada(r)"
            class="pv__res-row" :class="{ sel: seleccionado && claveUsada(seleccionado) === claveUsada(r) }"
            @click="seleccionar(r)"
          >
            <span class="pv__res-name">
              {{ r.nombre }}
              <span v-if="r.apartado" class="pv__tag">apartado</span>
            </span>
            <span class="pv__dep" :class="`pv__dep--${r.deposito}`">{{ depLabel(r.deposito) }}</span>
            <span class="pv__res-stock">{{ r.en_deposito }} {{ r.unidad }}</span>
          </button>
          <div v-if="!buscando && !resultados.length" class="pv__res-empty">Sin resultados.</div>
        </div>
        <label v-if="seleccionado" class="fld">
          Cantidad necesaria de <b>{{ seleccionado.nombre }}</b> ({{ seleccionado.unidad }})
          <input v-model.number="addCantidad" type="number" min="0" step="any" class="inp" />
        </label>
        <div class="modal__actions">
          <button class="btn" @click="cerrarAdd">Cancelar</button>
          <button class="btn btn--primary" :disabled="saving || !seleccionado || !(addCantidad > 0)" @click="confirmarAdd">Agregar</button>
        </div>
      </div>
    </div>

    <!-- Modal comprar faltante (salón) -->
    <div v-if="compraForm" class="ov" @click.self="compraForm = null">
      <div class="modal">
        <h3 class="modal__title">Comprar — {{ compraForm.prov.nombre }}</h3>
        <p class="modal__hint">Entra al depósito del salón (con costo). Después podés reservarlo para el evento.</p>
        <label class="fld">Cantidad<input v-model.number="compraForm.cantidad" type="number" min="0" step="any" class="inp" /></label>
        <label class="fld">Costo total<input v-model.number="compraForm.costo_total_ars" type="number" min="0" step="any" class="inp" placeholder="$" /></label>
        <div class="modal__actions"><button class="btn" @click="compraForm = null">Cancelar</button><button class="btn btn--primary" :disabled="saving" @click="confirmarCompra">Comprar</button></div>
      </div>
    </div>

    <!-- Modal cierre / reconciliación -->
    <!-- Rendición: los tres destinos a la vista, pero un solo número para cargar -->
    <div v-if="cierreForm" class="ov" @click.self="cierreForm = null">
      <div class="modal modal--rend">
        <h3 class="modal__title">Rendición del evento</h3>
        <p class="modal__hint">
          Lo vendido y lo dispensado ya lo sabe el sistema. Cargá solo <b>lo que se consumió sin vender</b>
          (degustación, muestra, rotura) — el sobrante se calcula solo y vuelve a su depósito.
        </p>
        <div class="pv__rec-tbl">
          <div class="pv__rec-hdr">
            <span>Qué</span><span class="r">Reservado</span>
            <span class="r">{{ 'Vendido' }}</span><span class="r">Consumido</span><span class="r">Sobra</span>
          </div>
          <div v-for="f in cierreForm" :key="f.id" class="pv__rec-row">
            <span class="pv__rec-name">
              {{ f.nombre }}
              <small v-if="f.apartado" class="pv__rec-ap">dispensario</small>
            </span>
            <span class="r num">{{ f.reservada }} <small class="pv__u">{{ f.unidad }}</small></span>
            <span class="r num pv__rec-vend">{{ f.dispensada || 0 }}</span>
            <span class="r">
              <input v-model.number="f.consumoInterno" type="number" min="0"
                     :max="f.reservada - (f.dispensada || 0)" class="pv__inp-sm" placeholder="0" />
            </span>
            <span class="r num" :class="excedida(f) ? 'pv__rec-mal' : 'pv__rec-sob'">
              <b>{{ sobranteFila(f) }}</b>
            </span>
          </div>
        </div>
        <p v-if="hayExcedida" class="pv__rec-err">
          Hay filas donde lo consumido supera lo que quedaba reservado. Corregilas antes de cerrar.
        </p>
        <p class="pv__rec-nota">
          El sobrante vuelve a su depósito. Lo consumido sin vender es <b>costo del evento</b>; lo dispensado a
          socios ya tiene su costo y su ingreso en la dispensación, con su trazabilidad.
        </p>
        <div class="modal__actions">
          <button class="btn" @click="cierreForm = null">Cancelar</button>
          <button class="btn" :disabled="saving || hayExcedida" @click="confirmarCierre(false)">Solo devolver sobrante</button>
          <button class="btn btn--primary" :disabled="saving || hayExcedida" @click="confirmarCierre(true)">Cerrar el evento</button>
        </div>
      </div>
    </div>
    </Teleport>
  </section>
</template>

<style scoped>
.pv { background: #fff; border: 1px solid #f1f5f9; border-radius: 14px; padding: 1.15rem 1.25rem; margin-top: 1rem; color: #0f172a; }
.pv__head { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; margin-bottom: .8rem; }
.pv__title { font-size: .95rem; font-weight: 700; margin: 0; }
.pv__sub { font-size: .78rem; color: #64748b; margin: .2rem 0 0; max-width: 64ch; line-height: 1.5; }
.pv__empty { color: #94a3b8; font-size: .84rem; text-align: center; padding: 1.2rem; }
.pv__empty--box { background: #fbfcfd; border: 1px dashed #e2e8f0; border-radius: 10px; }
.pv__table-wrap { overflow-x: auto; }
.pv__table { width: 100%; border-collapse: collapse; font-size: .84rem; }
.pv__table th { text-align: left; font-size: .66rem; text-transform: uppercase; letter-spacing: .05em; color: #94a3b8; font-weight: 700; padding: .5rem .6rem; border-bottom: 1px solid #f1f5f9; }
.pv__table td { padding: .55rem .6rem; border-bottom: 1px solid #f8fafc; color: #475569; }
.pv__table .r { text-align: right; }
.num { font-variant-numeric: tabular-nums; }
.strong { color: #0f172a; font-weight: 600; }
.pv__u { color: #94a3b8; font-size: .72rem; margin-left: 2px; }
.pv__dep { font-size: .64rem; font-weight: 700; padding: 2px 8px; border-radius: 999px; white-space: nowrap; }
.pv__dep--salon   { background: #fce7f3; color: #be185d; }
.pv__dep--cultivo { background: #dcfce7; color: #15803d; }
.pv__dep--general { background: #dbeafe; color: #1d4ed8; }
.pv__dep--dispensacion { background: #ede9fe; color: #6d28d9; }
.pv__dep--externo { background: #f1f5f9; color: #475569; }
.pv__disp { display: block; font-size: .66rem; color: #6d28d9; font-weight: 600; }
.pv__tag { font-size: .62rem; font-weight: 700; text-transform: uppercase; letter-spacing: .04em; color: #6d28d9; background: #ede9fe; padding: 1px 7px; border-radius: 999px; margin-left: .4rem; cursor: help; }
.pv__warn { list-style: none; margin: .7rem 0 0; padding: .6rem .8rem; background: #fffbeb; border: 1px solid #fde68a; border-radius: 10px; color: #92400e; font-size: .78rem; display: flex; flex-direction: column; gap: .25rem; }
.pv__falta { color: #b45309; font-weight: 700; background: #fef3c7; padding: 1px 8px; border-radius: 999px; }
.pv__ok { color: #15803d; font-weight: 700; }
.acts { white-space: nowrap; }
.pv__inp-sm { width: 66px; padding: .3rem .45rem; border: 1.5px solid #e2e8f0; border-radius: 7px; font-size: .82rem; text-align: right; }
.pv__inp-sm:focus { border-color: #1b5e20; outline: none; }
.pv__foot { display: flex; align-items: center; justify-content: space-between; gap: 1rem; flex-wrap: wrap; margin-top: .9rem; padding-top: .8rem; border-top: 1px solid #f1f5f9; }
.pv__summary { font-size: .82rem; color: #475569; }
.pv__actions { display: flex; gap: .5rem; }

/* Buscador */
.pv__res { display: flex; flex-direction: column; gap: 2px; max-height: 240px; overflow-y: auto; margin: .6rem 0 .2rem; border: 1px solid #f1f5f9; border-radius: 10px; }
.pv__res-row { display: flex; align-items: center; gap: .6rem; width: 100%; text-align: left; background: none; border: none; border-bottom: 1px solid #f8fafc; padding: .55rem .7rem; cursor: pointer; font-size: .84rem; color: #0f172a; }
.pv__res-row:last-child { border-bottom: none; }
.pv__res-row:hover { background: #f8fafc; }
.pv__res-row.sel { background: #f0faf3; }
.pv__res-name { flex: 1; font-weight: 600; }
.pv__res-stock { color: #94a3b8; font-size: .76rem; white-space: nowrap; }
.pv__res-empty { padding: 1rem; text-align: center; color: #94a3b8; font-size: .82rem; }

/* Rendición */
.pv__rec-tbl { display: flex; flex-direction: column; gap: .1rem; margin-bottom: .6rem; }
.pv__rec-hdr, .pv__rec-row {
  display: grid; grid-template-columns: 1fr 84px 70px 78px 72px; gap: .5rem; align-items: center;
}
.pv__rec-hdr { font-size: .64rem; text-transform: uppercase; letter-spacing: .05em; color: #94a3b8; font-weight: 700; padding-bottom: .35rem; border-bottom: 1px solid #f1f5f9; }
.pv__rec-row { font-size: .84rem; padding: .4rem 0; border-bottom: 1px solid #f8fafc; }
.pv__rec-row .r, .pv__rec-hdr .r { text-align: right; }
.pv__rec-name { font-weight: 600; color: #0f172a; }
.pv__rec-ap { display: block; font-size: .66rem; color: #6d28d9; font-weight: 600; }
.pv__rec-vend { color: #6d28d9; font-weight: 600; }
.pv__rec-sob { color: #15803d; }
.pv__rec-mal { color: #dc2626; }
.pv__rec-err { font-size: .78rem; color: #b91c1c; background: #fef2f2; border: 1px solid #fecaca; border-radius: 9px; padding: .5rem .7rem; margin: .2rem 0; }
.pv__rec-nota { font-size: .74rem; color: #64748b; line-height: 1.5; background: #f8fafc; border: 1px solid #f1f5f9; border-radius: 9px; padding: .55rem .7rem; margin: .2rem 0 0; }
.modal--rend { max-width: 560px; }

/* Lista unificada: servicios y elección de qué agregar */
.pv__dep--servicio { background: #fef3c7; color: #92400e; }
.pv__prov { display: block; font-size: .7rem; color: #94a3b8; font-weight: 500; }
.pv__pago { border: none; border-radius: 999px; padding: 2px 9px; font-size: .66rem; font-weight: 700; cursor: pointer; }
.pv__pago--ok { background: #f0fdf4; color: #15803d; }
.pv__pago--no { background: #fef3c7; color: #b45309; }
.pv__pick { display: flex; flex-direction: column; gap: .5rem; margin: .6rem 0 .2rem; }
.pv__pick-b { display: flex; flex-direction: column; gap: .2rem; text-align: left; padding: .8rem .9rem; border: 1.5px solid #e2e8f0; border-radius: 11px; background: #fff; cursor: pointer; }
.pv__pick-b:hover { border-color: #1b5e20; background: #f8fdf9; }
.pv__pick-b b { font-size: .9rem; color: #0f172a; }
.pv__pick-b small { font-size: .76rem; color: #64748b; line-height: 1.45; }
.pv__chk { display: flex; align-items: center; gap: .45rem; font-size: .82rem; color: #475569; margin: .5rem 0 .2rem; cursor: pointer; }

.ov { position: fixed; inset: 0; background: rgb(15 23 42 / .5); backdrop-filter: blur(2px); display: grid; place-items: center; z-index: 1000; padding: 1rem; }
.modal { background: #fff; border-radius: 16px; padding: 1.5rem; width: 100%; max-width: 420px; box-shadow: 0 20px 50px rgb(15 23 42 / .25); }
.modal--wide { max-width: 460px; }
.modal__title { margin: 0 0 .25rem; font-size: 1.05rem; font-weight: 750; }
.modal__hint { color: #64748b; font-size: .82rem; margin: 0 0 .8rem; }
.modal__actions { display: flex; gap: .5rem; justify-content: flex-end; margin-top: .8rem; flex-wrap: wrap; }
.fld { display: flex; flex-direction: column; gap: .35rem; font-size: .82rem; color: #475569; margin: .6rem 0 .3rem; }
.inp { padding: .55rem .7rem; border: 1.5px solid #e2e8f0; border-radius: 9px; font-size: .86rem; background: #fff; color: #0f172a; width: 100%; box-sizing: border-box; }
.inp:focus { border-color: #1b5e20; outline: none; }
.btn { border: 1.5px solid #e2e8f0; background: #fff; color: #334155; border-radius: 9px; padding: .5rem .85rem; font-size: .82rem; font-weight: 600; cursor: pointer; }
.btn:hover:not(:disabled) { border-color: #cbd5e1; }
.btn--sm { padding: .4rem .8rem; font-size: .8rem; }
.btn--primary { background: #1b5e20; border-color: #1b5e20; color: #fff; }
.btn--primary:hover:not(:disabled) { background: #144a18; }
.btn:disabled { opacity: .5; cursor: default; }
.lnk { background: none; border: none; color: #64748b; font-size: .8rem; font-weight: 600; cursor: pointer; padding: .1rem .35rem; text-decoration: none; }
.lnk:hover { color: #0f172a; }
.lnk--danger:hover { color: #dc2626; }
</style>
