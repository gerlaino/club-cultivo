<template>
  <div class="gp">
    <header class="gp__header">
      <div>
        <h1 class="gp__title">Gastos</h1>
        <p class="gp__sub">Lo que ponés en el cultivo, y cuánto termina costando cada gramo.</p>
      </div>
      <button type="button" class="gp__nuevo" @click="abrirNuevo"><i class="bi bi-plus-lg"></i> Nuevo gasto</button>
    </header>

    <div class="gp__tabs">
      <button class="gp__tab" :class="{ 'gp__tab--on': tab === 'gastos' }" @click="tab = 'gastos'"><i class="bi bi-receipt"></i> Gastos</button>
      <button class="gp__tab" :class="{ 'gp__tab--on': tab === 'lotes' }" @click="tab = 'lotes'"><i class="bi bi-box-seam"></i> Costo por lote</button>
      <button class="gp__tab" :class="{ 'gp__tab--on': tab === 'tipos' }" @click="tab = 'tipos'"><i class="bi bi-tags"></i> Tipos de gasto</button>
    </div>

    <!-- ── Gastos ── -->
    <template v-if="tab === 'gastos'">
      <div class="gp__kpis">
        <div class="gp__kpi">
          <span class="gp__kpi-lbl">{{ g.mesLabel.value }}</span>
          <span class="gp__kpi-num">{{ g.ars(g.totalMes.value) }}</span>
        </div>
        <div class="gp__kpi">
          <span class="gp__kpi-lbl">En el año</span>
          <span class="gp__kpi-num">{{ g.ars(g.totalAnio.value) }}</span>
        </div>
        <div class="gp__meses">
          <button type="button" class="gp__mes-btn" @click="g.moverMes(-1)" aria-label="Mes anterior"><i class="bi bi-chevron-left"></i></button>
          <span class="gp__mes-txt">{{ g.mesLabel.value }}</span>
          <button type="button" class="gp__mes-btn" :disabled="g.esMesActual.value" @click="g.moverMes(1)" aria-label="Mes siguiente"><i class="bi bi-chevron-right"></i></button>
        </div>
      </div>

      <div v-if="g.cargando.value" class="gp__loading"><DsSpinner :size="18" /> Cargando…</div>
      <DsEmpty v-else-if="!g.gastos.value.length" title="Sin gastos este mes"
               description="Sustrato, fertilizante, luz, una lámpara: anotalo y el costo por gramo sale solo." />
      <table v-else class="gp__table">
        <thead>
          <tr><th>Cuándo</th><th>Qué</th><th>Tipo</th><th>Lote</th><th>Cómo</th><th class="gp__num">Monto</th><th></th></tr>
        </thead>
        <tbody>
          <tr v-for="x in g.gastos.value" :key="x.id">
            <td class="gp__mono">{{ g.fechaCorta(x.fecha) }}</td>
            <td class="gp__desc">{{ x.descripcion }}</td>
            <td>{{ x.categoria_label || x.categoria }}</td>
            <td>{{ x.lote?.codigo || '—' }}</td>
            <td>{{ MEDIOS[x.medio_pago] || x.medio_pago || '—' }}</td>
            <td class="gp__num gp__monto">{{ g.ars(x.monto_ars) }}</td>
            <td class="gp__acciones">
              <button type="button" class="gp__icon" title="Corregir" @click="abrirEditar(x)"><i class="bi bi-pencil"></i></button>
              <button type="button" class="gp__icon gp__icon--danger" title="Borrar" @click="borrar(x)"><i class="bi bi-trash"></i></button>
            </td>
          </tr>
        </tbody>
      </table>
    </template>

    <!-- ── Tipos de gasto ──
         Las categorías de siempre, con nombre propio: «Nutrientes», «Luz», «Carpa». Se crean, se
         renombran y se apagan; no se borran, porque los gastos viejos las siguen nombrando. -->
    <template v-if="tab === 'tipos'">
      <div class="gp__tipos-head">
        <p class="gp__nota" style="margin:0">Cada gasto lleva un tipo. Poneles el nombre con el que vos pensás: después se filtra y se compara por acá.</p>
        <form class="gp__tipo-nuevo" @submit.prevent="crearTipo">
          <input v-model.trim="tipoNuevo" type="text" class="gp__input" placeholder="Nuevo tipo: Nutrientes, Luz, Carpa…" maxlength="60" />
          <button type="submit" class="gp__nuevo" :disabled="!tipoNuevo || creandoTipo">{{ creandoTipo ? 'Creando…' : 'Agregar' }}</button>
        </form>
      </div>
      <table class="gp__table">
        <thead><tr><th>Tipo</th><th>Sector</th><th></th></tr></thead>
        <tbody>
          <tr v-for="c in g.categorias.value" :key="c.id">
            <td class="gp__desc">
              <template v-if="editandoTipo === c.id">
                <input v-model.trim="tipoNombre" type="text" class="gp__input gp__input--inline" maxlength="60" @keydown.enter.prevent="guardarTipo(c)" @keydown.esc="editandoTipo = null" />
              </template>
              <template v-else>{{ c.nombre }}</template>
            </td>
            <td>{{ c.unidad_negocio?.nombre || '—' }}</td>
            <td class="gp__acciones">
              <template v-if="editandoTipo === c.id">
                <button type="button" class="gp__btn-sec" @click="editandoTipo = null">Cancelar</button>
                <button type="button" class="gp__btn-sec gp__btn-sec--ok" @click="guardarTipo(c)">Guardar</button>
              </template>
              <template v-else>
                <button type="button" class="gp__icon" title="Renombrar" @click="editandoTipo = c.id; tipoNombre = c.nombre"><i class="bi bi-pencil"></i></button>
                <button type="button" class="gp__icon" title="Dejar de usar" @click="apagarTipo(c)"><i class="bi bi-eye-slash"></i></button>
              </template>
            </td>
          </tr>
        </tbody>
      </table>
      <p v-if="!g.categorias.value.length" class="gp__nota">Sin tipos todavía: agregá el primero arriba.</p>
    </template>

    <!-- ── Costo por lote ──
         Sin ingresos ni margen: el cultivador de casa no vende. La pregunta es una sola —cuánto
         me costó este lote y cuánto cada gramo— y sale de los gastos que ató a cada lote. -->
    <template v-if="tab === 'lotes'">
      <div v-if="cargandoLotes" class="gp__loading"><DsSpinner :size="18" /> Cargando…</div>
      <DsEmpty v-else-if="!lotesCosto.length" title="Todavía no hay costos por lote"
               description="Cuando anotes un gasto «para un lote» y ese lote se pese, acá aparece cuánto costó cada gramo." />
      <table v-else class="gp__table">
        <thead>
          <tr><th>Lote</th><th>Genética</th><th>Estado</th><th class="gp__num">Gastos</th><th class="gp__num">Producido</th><th class="gp__num">Costo por gramo</th></tr>
        </thead>
        <tbody>
          <tr v-for="l in lotesCosto" :key="l.id">
            <td class="gp__mono"><RouterLink :to="`/lotes/${l.id}`" class="gp__link">{{ l.codigo }}</RouterLink></td>
            <td>{{ l.genetica || '—' }}</td>
            <td>{{ ESTADO_META[l.estado]?.label || l.estado }}</td>
            <td class="gp__num">{{ g.ars(l.costo_total) }}</td>
            <td class="gp__num">{{ l.gramos_producidos != null ? `${fmt(l.gramos_producidos)} g` : '—' }}</td>
            <td class="gp__num gp__monto">{{ l.costo_por_gramo != null ? g.ars(l.costo_por_gramo) : 'sin pesar' }}</td>
          </tr>
        </tbody>
      </table>
      <p class="gp__nota">Los gastos sin lote («del cultivo en general») no se reparten: son el costo de tener el cultivo, no de un lote.</p>
    </template>

    <!-- Modal alta/edición -->
    <Teleport to="body">
      <div v-if="modal" v-modal="() => modal = false" class="gp__overlay">
        <div class="gp__modal" role="dialog" aria-modal="true">
          <div class="gp__modal-head">
            <h2 class="gp__modal-title">{{ g.form.id ? 'Corregir gasto' : 'Nuevo gasto' }}</h2>
            <button type="button" class="gp__icon" aria-label="Cerrar" @click="modal = false"><i class="bi bi-x-lg"></i></button>
          </div>
          <GastoForm :form="g.form" :categorias="g.categorias.value" :lotes="g.lotesAbiertos.value" :insumos="g.insumos.value" :hoy="g.hoy"
                     :error="g.error.value" :guardando="g.guardando.value" :crear-tipo="g.crearTipo"
                     @guardar="guardar" @cancelar="modal = false" />
        </div>
      </div>
    </Teleport>
  </div>
</template>

<script setup>
// Gastos del cultivador de casa, en el escritorio. Reemplaza a Contabilidad entera: sin libro
// diario, ingresos, recurrentes, retiros, deudores ni cajas — nada de eso existe cuando no hay
// nadie a quien cobrarle. Mismo estado que la solapa del teléfono (`useGastosPersonal`).
import { ref, onMounted, watch } from 'vue'
import { useGastosPersonal } from '../../composables/useGastosPersonal.js'
import { useToast } from '../../composables/useToast.js'
import { useConfirm } from '../../composables/useConfirm.js'
import { getAnalyticsPL, listLotes } from '../../lib/api'
import { ESTADO_META } from '../../lib/loteHelpers.js'
import GastoForm from '../../components/personal/GastoForm.vue'
import DsSpinner from '../../design-system/components/Spinner.vue'
import DsEmpty from '../../design-system/components/EmptyState.vue'

const g     = useGastosPersonal()
const toast = useToast()
const { confirm } = useConfirm()

const MEDIOS = { efectivo: 'Efectivo', transferencia: 'Transferencia', mercado_pago: 'Mercado Pago' }
const tab   = ref('gastos')
const modal = ref(false)

function abrirNuevo()   { g.nuevo();   modal.value = true }
function abrirEditar(x) { g.editar(x); modal.value = true }

async function guardar() {
  const editaba = !!g.form.id
  if (await g.guardar()) {
    modal.value = false
    toast.success(editaba ? 'Gasto corregido' : 'Gasto anotado')
    lotesCargados = false
  }
}

async function borrar(x) {
  const ok = await confirm({ title: '¿Borrar este gasto?', message: `${x.descripcion} · ${g.ars(x.monto_ars)}. Sale del mes y del costo del lote, si tenía uno.`, confirmText: 'Borrar' })
  if (!ok) return
  try {
    await g.borrar(x)
    toast.success('Gasto borrado')
    lotesCargados = false
  } catch (e) {
    toast.error(e?.response?.data?.error || 'No se pudo borrar')
  }
}

// ── Tipos de gasto ──
const tipoNuevo    = ref('')
const creandoTipo  = ref(false)
const editandoTipo = ref(null)
const tipoNombre   = ref('')
async function crearTipo() {
  if (!tipoNuevo.value) return
  creandoTipo.value = true
  try { await g.crearTipo(tipoNuevo.value); tipoNuevo.value = ''; toast.success('Tipo agregado') }
  catch (e) { toast.error(e?.response?.data?.errors?.join(', ') || e?.response?.data?.error || 'No se pudo crear') }
  finally { creandoTipo.value = false }
}
async function guardarTipo(c) {
  if (!tipoNombre.value) return
  try { await g.renombrarTipo(c, tipoNombre.value); editandoTipo.value = null }
  catch (e) { toast.error(e?.response?.data?.errors?.join(', ') || 'No se pudo renombrar') }
}
async function apagarTipo(c) {
  const ok = await confirm({ title: `¿Dejar de usar «${c.nombre}»?`, message: 'Los gastos que ya lo tienen lo conservan; sólo deja de ofrecerse al anotar uno nuevo.', confirmText: 'Dejar de usar', variant: 'warning' })
  if (!ok) return
  try { await g.activarTipo(c, false) } catch { toast.error('No se pudo') }
}

// ── Costo por lote ──
const cargandoLotes = ref(false)
const lotesCosto    = ref([])
let lotesCargados   = false
function fmt(n) { const v = Number(n || 0); return Number.isInteger(v) ? String(v) : v.toFixed(1) }

async function cargarLotes() {
  cargandoLotes.value = true
  try {
    const [pl, lts] = await Promise.all([getAnalyticsPL(), listLotes()])
    // `pl_lotes` trae el costo; el rendimiento real viene del lote. Se cruzan por id.
    const porId = Object.fromEntries((lts.data || []).map(l => [l.id, l]))
    lotesCosto.value = (pl.data?.lotes || [])
      .filter(l => l.tiene_costos)
      .map(l => ({ ...l, gramos_producidos: porId[l.id]?.rendimiento_real_g ?? null }))
    lotesCargados = true
  } catch { lotesCosto.value = [] } finally { cargandoLotes.value = false }
}
watch(tab, (t) => { if (t === 'lotes' && !lotesCargados) cargarLotes() })

onMounted(() => g.cargarTodo())
</script>

<style scoped>
.gp { max-width: 1100px; margin: 0 auto; padding: 1.5rem 1.25rem 3rem; }
.gp__header { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; margin-bottom: 1.25rem; }
.gp__title { margin: 0; font-size: 1.6rem; font-weight: 800; color: var(--c-slate-900); letter-spacing: -.02em; }
.gp__sub { margin: .25rem 0 0; font-size: .88rem; color: var(--c-slate-500); }
.gp__nuevo {
  display: inline-flex; align-items: center; gap: .4rem; padding: .65rem 1rem; border-radius: 10px; border: none;
  background: var(--c-leaf-800, #1A3D2E); color: #fff; font-size: .9rem; font-weight: 700; cursor: pointer; white-space: nowrap;
}
.gp__tabs { display: flex; gap: .25rem; border-bottom: 1px solid var(--c-slate-200); margin-bottom: 1.25rem; }
.gp__tab { display: inline-flex; align-items: center; gap: .4rem; padding: .6rem .9rem; border: none; background: none; font: inherit; font-size: .9rem; font-weight: 600; color: var(--c-slate-500); border-bottom: 2px solid transparent; margin-bottom: -1px; cursor: pointer; }
.gp__tab--on { color: var(--c-leaf-800, #1A3D2E); border-bottom-color: var(--c-leaf-700, #2D7D46); }

.gp__kpis { display: grid; grid-template-columns: 1fr 1fr auto; gap: .75rem; align-items: stretch; margin-bottom: 1.25rem; }
.gp__kpi { display: flex; flex-direction: column; gap: .15rem; padding: 1rem 1.1rem; background: #fff; border: 1px solid var(--c-leaf-100, #e8f0eb); border-radius: 14px; }
.gp__kpi-lbl { font-size: .72rem; font-weight: 700; letter-spacing: .05em; text-transform: uppercase; color: var(--c-slate-500); }
.gp__kpi-num { font-family: var(--font-display, sans-serif); font-size: 1.6rem; font-weight: 700; color: var(--c-slate-900); }
.gp__meses { display: flex; align-items: center; gap: .6rem; padding: 0 .5rem; }
.gp__mes-btn { width: 34px; height: 34px; border-radius: 50%; border: 1px solid var(--c-slate-200); background: #fff; color: var(--c-slate-700); cursor: pointer; }
.gp__mes-btn:disabled { opacity: .35; cursor: default; }
.gp__mes-txt { font-size: .88rem; font-weight: 700; color: var(--c-slate-800); min-width: 10ch; text-align: center; }

.gp__loading { display: flex; align-items: center; gap: .5rem; padding: 2rem; color: var(--c-slate-400); font-size: .875rem; }
.gp__table { width: 100%; border-collapse: collapse; background: #fff; border: 1px solid var(--c-slate-200); border-radius: 12px; overflow: hidden; }
.gp__table th { text-align: left; font-size: .72rem; font-weight: 700; letter-spacing: .05em; text-transform: uppercase; color: var(--c-slate-500); padding: .7rem .9rem; background: var(--c-slate-50, #f8fafc); border-bottom: 1px solid var(--c-slate-200); }
.gp__table td { padding: .7rem .9rem; font-size: .88rem; color: var(--c-slate-700); border-bottom: 1px solid var(--c-slate-100); }
.gp__table tr:last-child td { border-bottom: none; }
.gp__num { text-align: right; }
.gp__monto { font-weight: 700; color: var(--c-slate-900); }
.gp__mono { font-family: ui-monospace, monospace; font-size: .82rem; color: var(--c-slate-500); }
.gp__desc { font-weight: 600; color: var(--c-slate-900); }
.gp__link { color: var(--c-leaf-800, #1A3D2E); font-weight: 700; text-decoration: none; }
.gp__acciones { text-align: right; white-space: nowrap; }
.gp__icon { width: 32px; height: 32px; border-radius: 8px; border: 1px solid var(--c-slate-200); background: #fff; color: var(--c-slate-600); cursor: pointer; }
.gp__icon--danger:hover { color: #b91c1c; border-color: #fecaca; }
.gp__nota { margin: .9rem 0 0; font-size: .8rem; color: var(--c-slate-500); }
.gp__tipos-head { display: flex; align-items: center; justify-content: space-between; gap: 1rem; margin-bottom: 1rem; flex-wrap: wrap; }
.gp__tipo-nuevo { display: flex; gap: .5rem; }
.gp__input { padding: .6rem .8rem; border: 1.5px solid var(--c-slate-200); border-radius: 10px; font: inherit; font-size: .9rem; min-width: 18rem; }
.gp__input--inline { min-width: 12rem; padding: .4rem .6rem; }
.gp__btn-sec { padding: .4rem .7rem; border-radius: 8px; border: 1px solid var(--c-slate-200); background: #fff; color: var(--c-slate-700); font-size: .8rem; font-weight: 600; cursor: pointer; }
.gp__btn-sec--ok { background: var(--c-leaf-800, #1A3D2E); color: #fff; border-color: transparent; }

/* Modal */
.gp__overlay { position: fixed; inset: 0; background: rgba(15, 23, 42, .45); display: flex; align-items: center; justify-content: center; padding: 1rem; z-index: 1000; }
.gp__modal { width: 100%; max-width: 520px; background: #fff; border-radius: 16px; padding: 1.25rem 1.25rem 1rem; box-shadow: 0 20px 60px rgba(0,0,0,.25); max-height: 92vh; overflow: auto; }
.gp__modal-head { display: flex; align-items: center; justify-content: space-between; margin-bottom: 1rem; }
.gp__modal-title { margin: 0; font-size: 1.1rem; font-weight: 800; color: var(--c-slate-900); }
@media (max-width: 720px) {
  .gp__kpis { grid-template-columns: 1fr 1fr; }
  .gp__meses { grid-column: 1 / -1; justify-content: center; }
}
</style>
