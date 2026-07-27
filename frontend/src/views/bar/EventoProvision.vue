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
})
const emit = defineEmits(['cambio'])
const toast = useToast()
const { confirm } = useConfirm()

const items   = ref([]) // provisiones
const loading = ref(false)
const saving  = ref(false)

const fmt = (n) => `$${Math.round(n || 0).toLocaleString('es-AR')}`
const totalComprar = computed(() => items.value.reduce((a, p) => a + (p.faltante || 0) * (p.costo_ars || 0), 0))
const hayFaltante  = computed(() => items.value.some(p => p.faltante > 0))
const hayReservado = computed(() => items.value.some(p => p.cantidad_reservada > p.cantidad_consumida))

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

// ── Cerrar / reconciliar ──────────────────────────────────────
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
      dispensada: p.cantidad_consumida || 0,
      consumida: p.cantidad_consumida || 0,
      consumoInterno: 0,
    }))
}
// Lo que vuelve al depósito / se libera: lo reservado menos lo que ya salió.
function sobranteFila(f) {
  const salido = f.apartado
    ? f.dispensada + (Number(f.consumoInterno) || 0)
    : (Number(f.consumida) || 0)
  return Math.max(0, f.reservada - salido)
}
async function confirmarCierre(finalizar) {
  saving.value = true
  try {
    const consumos = cierreForm.value.map(f => ({
      id: f.id,
      cantidad_consumida: Number(f.consumida) || 0,
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
        <h3 class="pv__title">¿Qué necesitás para el evento?</h3>
        <p class="pv__sub">Buscá entre los depósitos (salón, cultivo, general y dispensario). El sistema compara con el stock y te dice qué falta comprar; después lo reservás y al cerrar el sobrante vuelve. Lo del dispensario no se descuenta: queda <b>apartado</b> hasta que se dispensa.</p>
      </div>
      <button v-if="!finalizado" class="btn btn--sm btn--primary" @click="abrirAdd">+ Producto</button>
    </div>

    <div v-if="loading" class="pv__empty">Cargando…</div>
    <div v-else-if="!items.length" class="pv__empty pv__empty--box">
      Todavía no cargaste nada. Tocá <b>+ Producto</b> y buscá en cualquiera de los tres depósitos.
    </div>

    <template v-else>
      <div class="pv__table-wrap">
        <table class="pv__table">
          <thead><tr><th>Producto</th><th>Depósito</th><th class="r">Necesitás</th><th class="r">En depósito</th><th class="r">A comprar</th><th class="r">Reservado</th><th></th></tr></thead>
          <tbody>
            <tr v-for="p in items" :key="p.id">
              <td class="strong">
                {{ p.nombre }}
                <span v-if="p.apartado" class="pv__tag" title="Se bloquea la cantidad para el evento, pero no sale del inventario: el stock del dispensario sale recién al dispensarse.">apartado</span>
              </td>
              <td><span class="pv__dep" :class="`pv__dep--${p.deposito}`">{{ depLabel(p.deposito) }}</span></td>
              <td class="r">
                <input v-if="!finalizado" type="number" min="0" class="pv__inp-sm" :value="p.cantidad_prevista" @change="editarPrevista(p, $event.target.value)" />
                <span v-else>{{ p.cantidad_prevista }}</span>
                <small class="pv__u">{{ p.unidad }}</small>
              </td>
              <td class="r num">{{ p.en_deposito }} <small class="pv__u">{{ p.unidad }}</small></td>
              <td class="r">
                <span v-if="p.faltante > 0" class="pv__falta">{{ p.faltante }}</span>
                <span v-else class="pv__ok">✓</span>
              </td>
              <td class="r num">
                {{ p.cantidad_reservada || '—' }}
                <small v-if="p.apartado && p.cantidad_consumida > 0" class="pv__disp" title="Ya dispensado a socios desde lo apartado">−{{ p.cantidad_consumida }} disp.</small>
              </td>
              <td class="r acts">
                <template v-if="!finalizado && p.faltante > 0">
                  <button v-if="p.deposito === 'salon'" class="lnk" @click="abrirCompra(p)">Comprar</button>
                  <RouterLink v-else-if="p.deposito === 'dispensacion' || p.deposito === 'externo'" :to="{ name: 'admin-stock' }" class="lnk" title="El stock del dispensario se repone desde el inventario">Ver stock</RouterLink>
                  <RouterLink v-else :to="{ name: 'contabilidad' }" class="lnk" title="El stock de insumos entra al registrar la compra como movimiento">Registrar</RouterLink>
                </template>
                <button v-if="!finalizado && p.cantidad_reservada <= p.cantidad_consumida" class="lnk lnk--danger" @click="quitar(p)">Quitar</button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <ul v-if="advertencias.length" class="pv__warn">
        <li v-for="(a, i) in advertencias" :key="i">{{ a }}</li>
      </ul>

      <div class="pv__foot">
        <div class="pv__summary">
          <template v-if="hayFaltante">Faltante a comprar: <b>{{ fmt(totalComprar) }}</b> estimado</template>
          <template v-else-if="hayReservado">Stock reservado y apartado de los depósitos.</template>
          <template v-else>Todo lo necesario está en depósito. Podés reservar.</template>
        </div>
        <div class="pv__actions" v-if="!finalizado">
          <button class="btn btn--sm" :disabled="saving" @click="reservar"
                  :title="hayFaltante ? 'Aparta lo que hay ahora; el faltante lo reservás después de comprarlo' : ''">
            {{ hayFaltante ? 'Reservar lo disponible' : 'Reservar' }}
          </button>
          <button class="btn btn--sm btn--primary" :disabled="saving || !hayReservado" @click="abrirCierre">Cerrar / devolver sobrante</button>
        </div>
      </div>
    </template>

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
    <div v-if="cierreForm" class="ov" @click.self="cierreForm = null">
      <div class="modal modal--wide">
        <h3 class="modal__title">Cerrar provisión — reconciliar</h3>
        <p class="modal__hint">¿Cuánto se usó de lo reservado? El sobrante vuelve a su depósito.</p>
        <div class="pv__rec">
          <div v-for="f in cierreForm" :key="f.id" class="pv__rec-row" :class="{ 'pv__rec-row--ap': f.apartado }">
            <span class="pv__rec-name">{{ f.nombre }}</span>
            <span class="pv__rec-res">reservado {{ f.reservada }} {{ f.unidad }}</span>
            <!-- Apartado: lo dispensado ya salió por su canal; acá solo se declara lo consumido
                 sin dispensar (degustación, muestra), que descuenta al cerrar. -->
            <template v-if="f.apartado">
              <span class="pv__rec-disp" title="Ya dispensado a socios durante el evento">dispensado {{ f.dispensada }}</span>
              <input v-model.number="f.consumoInterno" type="number" min="0" :max="f.reservada - f.dispensada" class="pv__inp-sm" placeholder="0" />
            </template>
            <template v-else>
              <span></span>
              <input v-model.number="f.consumida" type="number" min="0" :max="f.reservada" class="pv__inp-sm" />
            </template>
            <span class="pv__rec-sob">{{ f.apartado ? 'libera' : 'sobra' }} <b>{{ sobranteFila(f) }}</b></span>
          </div>
        </div>
        <p v-if="cierreForm.some(f => f.apartado)" class="pv__rec-nota">
          En lo del <b>dispensario</b>, el campo editable es lo que se <b>consumió sin dispensar</b> (degustación,
          muestra): eso descuenta del inventario al cerrar y es costo del evento. Lo dispensado a socios ya salió
          por su canal, con su trazabilidad.
        </p>
        <div class="modal__actions">
          <button class="btn" @click="cierreForm = null">Cancelar</button>
          <button class="btn" :disabled="saving" @click="confirmarCierre(false)">Solo devolver</button>
          <button class="btn btn--primary" :disabled="saving" @click="confirmarCierre(true)">Devolver y finalizar</button>
        </div>
      </div>
    </div>
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

.pv__rec { display: flex; flex-direction: column; gap: .5rem; margin-bottom: .5rem; }
.pv__rec-row { display: grid; grid-template-columns: 1fr auto auto 70px auto; gap: .6rem; align-items: center; font-size: .84rem; }
.pv__rec-disp { font-size: .72rem; color: #6d28d9; background: #ede9fe; border-radius: 999px; padding: 1px 8px; white-space: nowrap; font-weight: 600; }
.pv__rec-nota { font-size: .74rem; color: #64748b; line-height: 1.5; background: #faf5ff; border: 1px solid #e9d5ff; border-radius: 9px; padding: .55rem .7rem; margin: .2rem 0 0; }
.pv__rec-name { font-weight: 600; color: #0f172a; }
.pv__rec-res { color: #94a3b8; font-size: .76rem; }
.pv__rec-sob { color: #15803d; font-size: .78rem; text-align: right; }

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
