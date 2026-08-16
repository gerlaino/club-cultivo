<script setup>
// Los gastos que se repiten, definidos una vez y elegidos después al cargar un movimiento.
//
// Es un CATÁLOGO, no un generador: nada se asienta solo. Con inflación, un movimiento automático
// sería un dato falso — el monto de acá es una referencia que viene puesta y se corrige en cada
// carga. Por eso "Luz $85.000" no significa que la luz cueste eso: significa que la última vez
// salió eso y sirve para no arrancar de cero.
import { ref, computed, onMounted } from 'vue'
import {
  listGastosRecurrentes, createGastoRecurrente, updateGastoRecurrente, deleteGastoRecurrente,
  listCategoriasContables, listSedes,
} from '../../lib/api.js'
import { useToast } from '../../composables/useToast.js'
import { useConfirm } from '../../composables/useConfirm.js'
import { UNIDADES, fmtARS } from '../../components/contabilidad/movimientoFlows.js'

const toast = useToast()
const { confirm } = useConfirm()

const items      = ref([])
const categorias = ref([])
const sedes      = ref([])
const cargando   = ref(true)
const guardando  = ref(false)
const form       = ref(null)
const error      = ref('')

const MEDIOS = [
  { value: '',              label: '— Sin definir —' },
  { value: 'efectivo',      label: 'Efectivo' },
  { value: 'transferencia', label: 'Transferencia' },
  { value: 'mercado_pago',  label: 'Mercado Pago' },
]

// Sólo las de EGRESO: un gasto recurrente es un gasto. Los ingresos no se cargan a mano.
const categoriasEgreso = computed(() =>
  categorias.value.filter(c => c.tipo === 'egreso')
)

const multiSede = computed(() => sedes.value.length > 1)

async function cargar() {
  cargando.value = true
  try {
    const [g, c, s] = await Promise.all([
      listGastosRecurrentes(), listCategoriasContables(), listSedes(),
    ])
    items.value      = g.data || []
    categorias.value = c.data || []
    sedes.value      = s.data || []
  } catch { toast.error('No se pudieron cargar los gastos recurrentes') } finally { cargando.value = false }
}
onMounted(cargar)

const vacio = () => ({
  nombre: '', descripcion: '', categoria_contable_id: null, sede_id: null,
  monto_ars: null, cantidad: null, unidad: 'unidad', medio_pago: '', proveedor: '', activo: true,
})
function nuevo()      { error.value = ''; form.value = vacio() }
function editar(g)    { error.value = ''; form.value = { ...g } }
function cancelar()   { form.value = null; error.value = '' }

async function guardar() {
  const f = form.value
  if (!f.nombre?.trim()) { error.value = 'Poné un nombre'; return }
  guardando.value = true
  error.value = ''
  try {
    const payload = { ...f, nombre: f.nombre.trim() }
    if (f.id) await updateGastoRecurrente(f.id, payload)
    else      await createGastoRecurrente(payload)
    form.value = null
    await cargar()
    toast.success('Gasto recurrente guardado')
  } catch (e) {
    error.value = e?.response?.data?.errors?.join(' · ') || 'No se pudo guardar'
  } finally { guardando.value = false }
}

async function borrar(g) {
  const ok = await confirm({
    title:   `Eliminar "${g.nombre}"`,
    message: 'Se borra el molde. Los movimientos que ya cargaste con él no se tocan.',
    confirmText: 'Eliminar', variant: 'danger',
  })
  if (!ok) return
  try { await deleteGastoRecurrente(g.id); await cargar() } catch { toast.error('No se pudo eliminar') }
}
</script>

<template>
  <div class="gr">
    <header class="gr__head">
      <div>
        <h3 class="gr__title">Gastos recurrentes</h3>
        <p class="gr__sub">
          Los que se repiten: la luz, el alquiler, el contador. Se definen acá y al cargar un
          movimiento se eligen del buscador, ya completos.
        </p>
      </div>
      <button v-if="!form" class="gr__btn" @click="nuevo">
        <i class="bi bi-plus-lg"></i> Nuevo
      </button>
    </header>

    <!-- El monto es una referencia, no una promesa: conviene decirlo donde se carga. -->
    <p class="gr__nota">
      El monto que pongas es de referencia: viene puesto al cargar el gasto y se corrige ahí.
      Nada se asienta solo.
    </p>

    <form v-if="form" class="gr__form" @submit.prevent="guardar">
      <div class="gr__row">
        <label class="gr__fld gr__fld--grow">
          <span class="gr__lbl">Nombre <span class="gr__req">*</span></span>
          <input v-model.trim="form.nombre" class="gr__inp" placeholder="Ej: Luz" maxlength="60" />
        </label>
        <label class="gr__fld gr__fld--grow">
          <span class="gr__lbl">Detalle <span class="gr__opt">(opcional)</span></span>
          <input v-model.trim="form.descripcion" class="gr__inp" placeholder="Lo que va en “¿Qué fue?”" />
        </label>
      </div>

      <div class="gr__row">
        <label class="gr__fld gr__fld--grow">
          <span class="gr__lbl">Categoría</span>
          <select v-model="form.categoria_contable_id" class="gr__inp">
            <option :value="null">— Sin categoría —</option>
            <option v-for="c in categoriasEgreso" :key="c.id" :value="c.id">{{ c.nombre }}</option>
          </select>
        </label>
        <label v-if="multiSede" class="gr__fld">
          <span class="gr__lbl">Sede</span>
          <select v-model="form.sede_id" class="gr__inp">
            <option :value="null">— Todas —</option>
            <option v-for="s in sedes" :key="s.id" :value="s.id">{{ s.nombre }}</option>
          </select>
        </label>
      </div>

      <div class="gr__row">
        <label class="gr__fld">
          <span class="gr__lbl">Monto de referencia</span>
          <input v-model.number="form.monto_ars" type="number" min="0" step="0.01" class="gr__inp" placeholder="0" />
        </label>
        <label class="gr__fld gr__fld--sm">
          <span class="gr__lbl">Cantidad</span>
          <input v-model.number="form.cantidad" type="number" min="0" step="0.001" class="gr__inp" placeholder="0" />
        </label>
        <label class="gr__fld gr__fld--sm">
          <span class="gr__lbl">Unidad</span>
          <select v-model="form.unidad" class="gr__inp">
            <option v-for="u in UNIDADES" :key="u" :value="u">{{ u }}</option>
          </select>
        </label>
      </div>

      <div class="gr__row">
        <label class="gr__fld">
          <span class="gr__lbl">Cómo se paga</span>
          <select v-model="form.medio_pago" class="gr__inp">
            <option v-for="m in MEDIOS" :key="m.value" :value="m.value">{{ m.label }}</option>
          </select>
        </label>
        <label class="gr__fld gr__fld--grow">
          <span class="gr__lbl">Proveedor</span>
          <input v-model.trim="form.proveedor" class="gr__inp" placeholder="Edenor, Aysa…" />
        </label>
      </div>

      <p v-if="error" class="gr__err">{{ error }}</p>
      <div class="gr__acts">
        <button type="button" class="gr__btn-ghost" @click="cancelar">Cancelar</button>
        <button type="submit" class="gr__btn" :disabled="guardando">
          {{ guardando ? 'Guardando…' : 'Guardar' }}
        </button>
      </div>
    </form>

    <p v-if="cargando" class="gr__vacio">Cargando…</p>
    <p v-else-if="!items.length && !form" class="gr__vacio">
      Todavía no hay ninguno. Creá los que pagues todos los meses y cargarlos va a ser elegir.
    </p>

    <ul v-else class="gr__lista">
      <li v-for="g in items" :key="g.id" class="gr__item" :class="{ 'gr__item--off': !g.activo }">
        <div class="gr__item-main">
          <span class="gr__item-nombre">{{ g.nombre }}</span>
          <span class="gr__item-meta">
            <span v-if="g.categoria_label">{{ g.categoria_label }}</span>
            <span v-if="g.sede_nombre">· {{ g.sede_nombre }}</span>
            <span v-if="g.proveedor">· {{ g.proveedor }}</span>
          </span>
        </div>
        <span v-if="g.monto_ars" class="gr__item-monto">{{ fmtARS(g.monto_ars) }}</span>
        <div class="gr__item-acts">
          <button class="gr__icon" title="Editar" @click="editar(g)"><i class="bi bi-pencil"></i></button>
          <button class="gr__icon gr__icon--danger" title="Eliminar" @click="borrar(g)"><i class="bi bi-trash"></i></button>
        </div>
      </li>
    </ul>
  </div>
</template>

<style scoped>
.gr { display: flex; flex-direction: column; gap: .7rem; }
.gr__head { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; }
.gr__title { margin: 0; font-size: 1rem; font-weight: 800; color: var(--c-slate-900); }
.gr__sub { margin: .2rem 0 0; font-size: .8rem; color: var(--c-slate-500); max-width: 60ch; line-height: 1.4; }
.gr__nota { margin: 0; font-size: .76rem; color: var(--c-slate-500); background: var(--c-slate-50); border-radius: 9px; padding: .5rem .7rem; }
.gr__form { display: flex; flex-direction: column; gap: .6rem; background: var(--c-slate-50); border: 1px solid var(--c-slate-200); border-radius: 10px; padding: .9rem; }
.gr__row { display: flex; gap: .6rem; flex-wrap: wrap; }
.gr__fld { display: flex; flex-direction: column; gap: .25rem; flex: 0 1 180px; }
.gr__fld--grow { flex: 1 1 220px; }
.gr__fld--sm { flex: 0 1 120px; }
.gr__lbl { font-size: .74rem; font-weight: 700; color: var(--c-slate-500); }
.gr__opt { font-weight: 400; color: var(--c-slate-400); }
.gr__req { color: #ef4444; }
.gr__inp { width: 100%; box-sizing: border-box; background: #fff; border: 1.5px solid var(--c-slate-200); border-radius: 8px; padding: .45rem .6rem; font-size: .82rem; color: var(--c-slate-900); font-family: inherit; }
.gr__inp:focus { outline: none; border-color: #15803d; }
.gr__err { margin: 0; font-size: .76rem; color: #dc2626; }
.gr__acts { display: flex; justify-content: flex-end; gap: .5rem; }
.gr__btn { display: inline-flex; align-items: center; gap: .35rem; background: #15803d; color: #fff; border: none; border-radius: 9px; padding: .45rem .9rem; font-size: .82rem; font-weight: 700; cursor: pointer; }
.gr__btn:disabled { opacity: .55; cursor: not-allowed; }
.gr__btn-ghost { background: none; border: 1.5px solid var(--c-slate-300); color: var(--c-slate-500); border-radius: 9px; padding: .45rem .9rem; font-size: .82rem; font-weight: 700; cursor: pointer; }
.gr__vacio { margin: 0; font-size: .82rem; color: var(--c-slate-400); padding: .8rem 0; }
.gr__lista { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: .3rem; }
.gr__item { display: flex; align-items: center; gap: .7rem; padding: .55rem .7rem; border: 1px solid var(--c-slate-200); border-radius: 9px; background: #fff; }
.gr__item--off { opacity: .5; }
.gr__item-main { display: flex; flex-direction: column; gap: .1rem; flex: 1 1 auto; min-width: 0; }
.gr__item-nombre { font-size: .86rem; font-weight: 700; color: var(--c-slate-900); }
.gr__item-meta { font-size: .74rem; color: var(--c-slate-500); }
.gr__item-monto { font-size: .86rem; font-weight: 700; color: var(--c-slate-700); font-variant-numeric: tabular-nums; }
.gr__item-acts { display: flex; gap: .2rem; }
.gr__icon { background: none; border: none; color: var(--c-slate-400); cursor: pointer; padding: .2rem .3rem; border-radius: 6px; }
.gr__icon:hover { background: var(--c-slate-100); color: var(--c-slate-700); }
.gr__icon--danger:hover { color: #dc2626; }
</style>
