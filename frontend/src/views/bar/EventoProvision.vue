<script setup>
// Provisión de mercadería de un evento (Fase 3). Armás qué necesitás, el sistema te dice qué
// comprar (vs el depósito del salón), reservás (sale del depósito) y al cerrar el sobrante vuelve.
import { ref, computed, onMounted } from 'vue'
import { listBarProductos, listProvisiones, upsertProvision, updateProvision, deleteProvision,
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

const items     = ref([])   // provisiones
const productos = ref([])   // productos del bar (para el selector)
const loading   = ref(false)
const saving    = ref(false)

const fmt = (n) => `$${Math.round(n || 0).toLocaleString('es-AR')}`
const totalComprar = computed(() => items.value.reduce((a, p) => a + (p.faltante || 0) * (p.costo_ars || 0), 0))
const hayFaltante  = computed(() => items.value.some(p => p.faltante > 0))
const hayReservado = computed(() => items.value.some(p => p.cantidad_reservada > p.cantidad_consumida))
const disponibles  = computed(() => {
  const usados = new Set(items.value.map(p => p.bar_producto_id))
  return productos.value.filter(p => !usados.has(p.id))
})

async function cargar() {
  loading.value = true
  try {
    const [prov, prods] = await Promise.all([listProvisiones(props.barId, props.evId), listBarProductos(props.barId, { activos: 'true' })])
    items.value = prov.data?.provisiones || []
    productos.value = prods.data || []
  } catch { /* sin bar */ }
  finally { loading.value = false }
}
onMounted(cargar)

// ── Agregar producto a la lista ───────────────────────────────
const addForm = ref(null)
function abrirAdd() { addForm.value = { bar_producto_id: disponibles.value[0]?.id ?? null, cantidad_prevista: null } }
async function confirmarAdd() {
  const f = addForm.value
  if (!f.bar_producto_id || !(f.cantidad_prevista > 0)) { toast.warning('Elegí producto y cantidad'); return }
  saving.value = true
  try {
    await upsertProvision(props.barId, props.evId, { bar_producto_id: f.bar_producto_id, cantidad_prevista: f.cantidad_prevista })
    addForm.value = null; await cargar()
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

// ── Comprar faltante (por fila) ───────────────────────────────
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
async function reservar() {
  saving.value = true
  try {
    const { data } = await reservarProvision(props.barId, props.evId)
    items.value = data.provisiones || items.value
    toast.success('Stock reservado para el evento'); emit('cambio')
  } catch (e) { toast.error(e?.response?.data?.error || 'No se pudo reservar') }
  finally { saving.value = false }
}

// ── Cerrar / reconciliar ──────────────────────────────────────
const cierreForm = ref(null) // [{ id, nombre, reservada, consumida }]
function abrirCierre() {
  cierreForm.value = items.value
    .filter(p => p.cantidad_reservada > 0)
    .map(p => ({ id: p.id, nombre: p.nombre, reservada: p.cantidad_reservada, consumida: p.cantidad_reservada }))
}
function sobranteFila(f) { return Math.max(0, f.reservada - (Number(f.consumida) || 0)) }
async function confirmarCierre(finalizar) {
  saving.value = true
  try {
    const consumos = cierreForm.value.map(f => ({ id: f.id, cantidad_consumida: Number(f.consumida) || 0 }))
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
        <h3 class="pv__title">Provisión de mercadería</h3>
        <p class="pv__sub">Qué necesitás para el evento. El sistema compara con el depósito y te dice qué comprar.</p>
      </div>
      <button v-if="!finalizado" class="btn btn--sm" :disabled="!disponibles.length" @click="abrirAdd">+ Producto</button>
    </div>

    <div v-if="loading" class="pv__empty">Cargando…</div>
    <div v-else-if="!items.length" class="pv__empty pv__empty--box">Todavía no cargaste productos para este evento.</div>

    <template v-else>
      <div class="pv__table-wrap">
        <table class="pv__table">
          <thead><tr><th>Producto</th><th class="r">Necesitás</th><th class="r">En depósito</th><th class="r">A comprar</th><th class="r">Reservado</th><th></th></tr></thead>
          <tbody>
            <tr v-for="p in items" :key="p.id">
              <td class="strong">{{ p.nombre }}</td>
              <td class="r">
                <input v-if="!finalizado" type="number" min="0" class="pv__inp-sm" :value="p.cantidad_prevista" @change="editarPrevista(p, $event.target.value)" />
                <span v-else>{{ p.cantidad_prevista }}</span>
              </td>
              <td class="r num">{{ p.en_deposito }}</td>
              <td class="r">
                <span v-if="p.faltante > 0" class="pv__falta">{{ p.faltante }}</span>
                <span v-else class="pv__ok">✓</span>
              </td>
              <td class="r num">{{ p.cantidad_reservada || '—' }}</td>
              <td class="r acts">
                <button v-if="!finalizado && p.faltante > 0" class="lnk" @click="abrirCompra(p)">Comprar</button>
                <button v-if="!finalizado && p.cantidad_reservada <= p.cantidad_consumida" class="lnk lnk--danger" @click="quitar(p)">Quitar</button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <div class="pv__foot">
        <div class="pv__summary">
          <template v-if="hayFaltante">Faltante a comprar: <b>{{ fmt(totalComprar) }}</b> estimado</template>
          <template v-else-if="hayReservado">Stock reservado y apartado del depósito.</template>
          <template v-else>Todo lo necesario está en el depósito. Podés reservar.</template>
        </div>
        <div class="pv__actions" v-if="!finalizado">
          <button class="btn btn--sm" :disabled="saving || hayFaltante" @click="reservar" :title="hayFaltante ? 'Comprá el faltante primero' : ''">Reservar</button>
          <button class="btn btn--sm btn--primary" :disabled="saving || !hayReservado" @click="abrirCierre">Cerrar / devolver sobrante</button>
        </div>
      </div>
    </template>

    <!-- Modal agregar -->
    <div v-if="addForm" class="ov" @click.self="addForm = null">
      <div class="modal">
        <h3 class="modal__title">Agregar a la provisión</h3>
        <label class="fld">Producto
          <select v-model="addForm.bar_producto_id" class="inp"><option v-for="p in disponibles" :key="p.id" :value="p.id">{{ p.nombre }}</option></select>
        </label>
        <label class="fld">Cantidad necesaria<input v-model.number="addForm.cantidad_prevista" type="number" min="0" step="any" class="inp" /></label>
        <div class="modal__actions"><button class="btn" @click="addForm = null">Cancelar</button><button class="btn btn--primary" :disabled="saving" @click="confirmarAdd">Agregar</button></div>
      </div>
    </div>

    <!-- Modal comprar faltante -->
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
        <p class="modal__hint">¿Cuánto se usó de lo reservado? El sobrante vuelve al depósito del salón.</p>
        <div class="pv__rec">
          <div v-for="f in cierreForm" :key="f.id" class="pv__rec-row">
            <span class="pv__rec-name">{{ f.nombre }}</span>
            <span class="pv__rec-res">reservado {{ f.reservada }}</span>
            <input v-model.number="f.consumida" type="number" min="0" :max="f.reservada" class="pv__inp-sm" />
            <span class="pv__rec-sob">sobra <b>{{ sobranteFila(f) }}</b></span>
          </div>
        </div>
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
.pv__sub { font-size: .78rem; color: #64748b; margin: .2rem 0 0; max-width: 60ch; }
.pv__empty { color: #94a3b8; font-size: .84rem; text-align: center; padding: 1.2rem; }
.pv__empty--box { background: #fbfcfd; border: 1px dashed #e2e8f0; border-radius: 10px; }
.pv__table-wrap { overflow-x: auto; }
.pv__table { width: 100%; border-collapse: collapse; font-size: .84rem; }
.pv__table th { text-align: left; font-size: .66rem; text-transform: uppercase; letter-spacing: .05em; color: #94a3b8; font-weight: 700; padding: .5rem .6rem; border-bottom: 1px solid #f1f5f9; }
.pv__table td { padding: .55rem .6rem; border-bottom: 1px solid #f8fafc; color: #475569; }
.pv__table .r { text-align: right; }
.num { font-variant-numeric: tabular-nums; }
.strong { color: #0f172a; font-weight: 600; }
.pv__falta { color: #b45309; font-weight: 700; background: #fef3c7; padding: 1px 8px; border-radius: 999px; }
.pv__ok { color: #15803d; font-weight: 700; }
.acts { white-space: nowrap; }
.pv__inp-sm { width: 66px; padding: .3rem .45rem; border: 1.5px solid #e2e8f0; border-radius: 7px; font-size: .82rem; text-align: right; }
.pv__inp-sm:focus { border-color: #1b5e20; outline: none; }
.pv__foot { display: flex; align-items: center; justify-content: space-between; gap: 1rem; flex-wrap: wrap; margin-top: .9rem; padding-top: .8rem; border-top: 1px solid #f1f5f9; }
.pv__summary { font-size: .82rem; color: #475569; }
.pv__actions { display: flex; gap: .5rem; }

.pv__rec { display: flex; flex-direction: column; gap: .5rem; margin-bottom: .5rem; }
.pv__rec-row { display: grid; grid-template-columns: 1fr auto 70px auto; gap: .6rem; align-items: center; font-size: .84rem; }
.pv__rec-name { font-weight: 600; color: #0f172a; }
.pv__rec-res { color: #94a3b8; font-size: .76rem; }
.pv__rec-sob { color: #15803d; font-size: .78rem; text-align: right; }

.ov { position: fixed; inset: 0; background: rgb(15 23 42 / .5); backdrop-filter: blur(2px); display: grid; place-items: center; z-index: 1000; padding: 1rem; }
.modal { background: #fff; border-radius: 16px; padding: 1.5rem; width: 100%; max-width: 380px; box-shadow: 0 20px 50px rgb(15 23 42 / .25); }
.modal--wide { max-width: 460px; }
.modal__title { margin: 0 0 .25rem; font-size: 1.05rem; font-weight: 750; }
.modal__hint { color: #64748b; font-size: .82rem; margin: 0 0 1.1rem; }
.modal__actions { display: flex; gap: .5rem; justify-content: flex-end; margin-top: .5rem; flex-wrap: wrap; }
.fld { display: flex; flex-direction: column; gap: .35rem; font-size: .82rem; color: #475569; margin-bottom: .9rem; }
.inp { padding: .55rem .7rem; border: 1.5px solid #e2e8f0; border-radius: 9px; font-size: .86rem; background: #fff; color: #0f172a; }
.inp:focus { border-color: #1b5e20; outline: none; }
.btn { border: 1.5px solid #e2e8f0; background: #fff; color: #334155; border-radius: 9px; padding: .5rem .85rem; font-size: .82rem; font-weight: 600; cursor: pointer; }
.btn:hover:not(:disabled) { border-color: #cbd5e1; }
.btn--sm { padding: .4rem .8rem; font-size: .8rem; }
.btn--primary { background: #1b5e20; border-color: #1b5e20; color: #fff; }
.btn--primary:hover:not(:disabled) { background: #144a18; }
.btn:disabled { opacity: .5; cursor: default; }
.lnk { background: none; border: none; color: #64748b; font-size: .8rem; font-weight: 600; cursor: pointer; padding: .1rem .35rem; }
.lnk:hover { color: #0f172a; }
.lnk--danger:hover { color: #dc2626; }
</style>
