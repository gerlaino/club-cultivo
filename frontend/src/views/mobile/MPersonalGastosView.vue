<template>
  <div class="mpg">
    <header class="mpg__header">
      <div>
        <h1 class="mpg__title">Gastos</h1>
        <p class="mpg__sub">{{ mesLabel }}</p>
      </div>
      <button type="button" class="mpg__nuevo" @click="abrirNuevo"><i class="bi bi-plus-lg"></i> Gasto</button>
    </header>

    <!-- El número del mes, y el del año para tener contra qué mirarlo. -->
    <div class="mpg__kpis">
      <div class="mpg__kpi">
        <span class="mpg__kpi-num">{{ ars(totalMes) }}</span>
        <span class="mpg__kpi-lbl">este mes</span>
      </div>
      <div class="mpg__kpi">
        <span class="mpg__kpi-num">{{ ars(totalAnio) }}</span>
        <span class="mpg__kpi-lbl">en el año</span>
      </div>
    </div>

    <div class="mpg__meses">
      <button type="button" class="mpg__mes-btn" @click="moverMes(-1)" aria-label="Mes anterior"><i class="bi bi-chevron-left"></i></button>
      <span class="mpg__mes-txt">{{ mesLabel }}</span>
      <button type="button" class="mpg__mes-btn" :disabled="esMesActual" @click="moverMes(1)" aria-label="Mes siguiente"><i class="bi bi-chevron-right"></i></button>
    </div>

    <div v-if="cargando" class="mpg__loading"><i class="bi bi-arrow-repeat mpg__spin"></i> Cargando…</div>
    <div v-else-if="!gastos.length" class="mpg__empty">
      <i class="bi bi-receipt"></i>
      <p class="mpg__empty-title">Sin gastos este mes</p>
      <p class="mpg__empty-hint">Sustrato, fertilizante, luz, una lámpara: anotalo y el costo por gramo sale solo.</p>
    </div>
    <ul v-else class="mpg__list">
      <li v-for="g in gastos" :key="g.id" class="mpg__item">
        <span class="mpg__item-ico" :style="{ background: (g.categoria_color || '#5A8A72') + '22', color: g.categoria_color || '#5A8A72' }"><i class="bi bi-receipt"></i></span>
        <span class="mpg__item-txt">
          <span class="mpg__item-desc">{{ g.descripcion }}</span>
          <span class="mpg__item-sub">{{ g.categoria_label || g.categoria }} · {{ fechaCorta(g.fecha) }}<template v-if="g.lote?.codigo"> · {{ g.lote.codigo }}</template></span>
        </span>
        <span class="mpg__item-monto">{{ ars(g.monto_ars) }}</span>
      </li>
    </ul>

    <p class="mpg__pie">
      El detalle completo —categorías, cuotas, costo por lote— está en
      <RouterLink to="/contabilidad">Contabilidad</RouterLink>.
    </p>

    <!-- Nuevo gasto: tres campos y una oración que dice qué va a pasar. -->
    <MobileSheet v-model="sheet" title="Nuevo gasto">
      <form class="mpg__form" @submit.prevent="guardar">
        <label class="mpg__field">
          <span class="mpg__label">Qué compraste</span>
          <input v-model.trim="form.descripcion" type="text" class="mpg__input" placeholder="Sustrato 50 L" maxlength="120" required />
        </label>
        <label class="mpg__field">
          <span class="mpg__label">Cuánto</span>
          <span class="mpg__input-row">
            <span class="mpg__input-u">$</span>
            <input v-model.number="form.monto_ars" type="number" inputmode="decimal" step="0.01" min="0.01" class="mpg__input mpg__input--num" placeholder="0" required />
          </span>
        </label>
        <label class="mpg__field">
          <span class="mpg__label">De qué tipo</span>
          <select v-model="form.categoria_contable_id" class="mpg__input" required>
            <option value="" disabled>Elegí…</option>
            <option v-for="c in categorias" :key="c.id" :value="c.id">{{ c.nombre }}</option>
          </select>
        </label>
        <div class="mpg__row-2">
          <label class="mpg__field">
            <span class="mpg__label">Cuándo</span>
            <input v-model="form.fecha" type="date" class="mpg__input" :max="hoy" required />
          </label>
          <label class="mpg__field">
            <span class="mpg__label">Cómo pagaste</span>
            <select v-model="form.medio_pago" class="mpg__input">
              <option value="efectivo">Efectivo</option>
              <option value="transferencia">Transferencia</option>
              <option value="mercado_pago">Mercado Pago</option>
            </select>
          </label>
        </div>
        <label class="mpg__field">
          <span class="mpg__label">Para un lote <span class="mpg__opt">(opcional)</span></span>
          <select v-model="form.lote_id" class="mpg__input">
            <option :value="null">Del cultivo en general</option>
            <option v-for="l in lotesEnCurso" :key="l.id" :value="l.id">{{ l.codigo }} · {{ l.genetica?.nombre || l.strain || '' }}</option>
          </select>
        </label>
        <p v-if="error" class="mpg__error">{{ error }}</p>
        <p v-if="form.monto_ars > 0 && form.descripcion" class="mpg__resumen">
          Salen <b>{{ ars(form.monto_ars) }}</b> por {{ form.descripcion }}<template v-if="loteElegido">, a cuenta del lote {{ loteElegido.codigo }}</template>.
        </p>
        <div class="mpg__form-actions">
          <button type="button" class="mpg__btn mpg__btn--ghost" @click="sheet = false">Cancelar</button>
          <button type="submit" class="mpg__btn mpg__btn--primary" :disabled="guardando || !form.categoria_contable_id">{{ guardando ? 'Guardando…' : 'Anotar' }}</button>
        </div>
      </form>
    </MobileSheet>
  </div>
</template>

<script setup>
// Los gastos del cultivador de casa, desde el teléfono: lo que compró, cuánto, de qué tipo.
// Es el mismo `MovimientoContable` que usa una organización —por eso el costo por lote y el
// informe de costo salen solos— con la pantalla reducida a lo que él necesita: por acá SÓLO
// SALE PLATA (misma regla que «Nuevo movimiento» del escritorio), sin sectores, cajas ni cuotas.
import { ref, computed, reactive, onMounted } from 'vue'
import { listMovimientos, createMovimiento, listCategoriasContables, listLotes } from '../../lib/api'
import { useToast } from '../../composables/useToast.js'
import { hoyISO, toISO } from '../../utils/dates.js'
import MobileSheet from '../../components/mobile/MobileSheet.vue'

const toast = useToast()
const hoy   = hoyISO()

// ── Mes ──
const mes = ref(new Date(new Date().getFullYear(), new Date().getMonth(), 1))
const esMesActual = computed(() => {
  const n = new Date()
  return mes.value.getFullYear() === n.getFullYear() && mes.value.getMonth() === n.getMonth()
})
const mesLabel = computed(() => {
  const s = mes.value.toLocaleDateString('es-AR', { month: 'long', year: 'numeric' })
  return s.charAt(0).toUpperCase() + s.slice(1)
})
function moverMes(d) {
  mes.value = new Date(mes.value.getFullYear(), mes.value.getMonth() + d, 1)
  cargar()
}
function rangoMes() {
  const desde = mes.value
  const hasta = new Date(mes.value.getFullYear(), mes.value.getMonth() + 1, 0)
  return { desde: toISO(desde), hasta: toISO(hasta) }
}

// ── Datos ──
const cargando  = ref(true)
const gastos    = ref([])
const totalMes  = ref(0)
const totalAnio = ref(0)
const categorias = ref([])
const lotes      = ref([])
const lotesEnCurso = computed(() => lotes.value.filter(l => ['enraizado', 'vegetativo', 'floracion', 'cosecha', 'en_manicura', 'curado'].includes(l.estado)))

async function cargar() {
  cargando.value = true
  try {
    const { data } = await listMovimientos({ tipo: 'egreso', ...rangoMes(), per_page: 200 })
    gastos.value   = data?.movimientos || []
    totalMes.value = Number(data?.totales?.egresos ?? gastos.value.reduce((t, g) => t + Number(g.monto_ars || 0), 0))
  } catch { gastos.value = [] } finally { cargando.value = false }
}

async function cargarAnio() {
  try {
    const n = new Date()
    const { data } = await listMovimientos({ tipo: 'egreso', desde: toISO(new Date(n.getFullYear(), 0, 1)), hasta: hoy, per_page: 1 })
    totalAnio.value = Number(data?.totales?.egresos || 0)
  } catch { /* el del año es contexto: sin él la pantalla sirve igual */ }
}

function ars(n) { return '$' + Number(n || 0).toLocaleString('es-AR', { maximumFractionDigits: 0 }) }
function fechaCorta(f) { return f ? new Date(f + 'T00:00:00').toLocaleDateString('es-AR', { day: 'numeric', month: 'short' }) : '' }

// ── Nuevo ──
const sheet     = ref(false)
const guardando = ref(false)
const error     = ref(null)
const form = reactive({ descripcion: '', monto_ars: null, categoria_contable_id: '', fecha: hoy, medio_pago: 'efectivo', lote_id: null })
const loteElegido = computed(() => lotes.value.find(l => l.id === form.lote_id))

function abrirNuevo() {
  Object.assign(form, { descripcion: '', monto_ars: null, categoria_contable_id: categorias.value[0]?.id || '', fecha: hoy, medio_pago: 'efectivo', lote_id: null })
  error.value = null
  sheet.value = true
}

async function guardar() {
  guardando.value = true
  error.value = null
  try {
    await createMovimiento({
      tipo: 'egreso',
      descripcion: form.descripcion,
      monto_ars: form.monto_ars,
      categoria_contable_id: form.categoria_contable_id,
      fecha: form.fecha,
      medio_pago: form.medio_pago,
      lote_id: form.lote_id || undefined,
      pagado: true,
    })
    sheet.value = false
    toast.success('Gasto anotado')
    await Promise.all([cargar(), cargarAnio()])
  } catch (e) {
    error.value = e?.response?.data?.error || e?.response?.data?.errors?.join(', ') || 'No se pudo guardar'
  } finally { guardando.value = false }
}

onMounted(async () => {
  cargar()
  cargarAnio()
  try {
    const [cats, lts] = await Promise.allSettled([listCategoriasContables({ activas: 'true', tipo: 'egreso' }), listLotes()])
    // Sin sectores de dispensario ni buffet: al cultivador de casa sólo le aplican Cultivo y
    // General. Con las demás la lista se llenaba de cosas que nunca va a comprar.
    if (cats.status === 'fulfilled') {
      categorias.value = (cats.value.data || []).filter(c => !c.unidad_negocio || ['cultivo', 'general', 'administracion', 'otro'].includes(c.unidad_negocio.tipo))
    }
    if (lts.status === 'fulfilled') lotes.value = lts.value.data || []
  } catch { /* sin categorías el formulario avisa al guardar */ }
})
</script>

<style scoped>
.mpg { padding: 0 0 1.5rem; }
.mpg__header { display: flex; align-items: flex-start; justify-content: space-between; gap: .75rem; padding: 1rem 1rem .5rem; }
.mpg__title { font-size: 1.15rem; font-weight: 800; color: var(--c-slate-900); margin: 0; }
.mpg__sub { margin: .15rem 0 0; font-size: .8rem; color: var(--c-slate-500); }
.mpg__nuevo {
  display: inline-flex; align-items: center; gap: .35rem; padding: .55rem .85rem; border-radius: 12px; border: none;
  background: var(--c-leaf-800, #1A3D2E); color: #fff; font-size: .85rem; font-weight: 700; flex-shrink: 0;
}
.mpg__nuevo:active { transform: scale(.96); }

.mpg__kpis { display: grid; grid-template-columns: 1fr 1fr; gap: .6rem; padding: .5rem 1rem 0; }
.mpg__kpi { display: flex; flex-direction: column; gap: .1rem; padding: .85rem .9rem; background: #fff; border: 1px solid var(--c-leaf-100, #e8f0eb); border-radius: 14px; }
.mpg__kpi-num { font-family: var(--font-display, sans-serif); font-size: 1.35rem; font-weight: 700; color: var(--c-ink-900, #1a1d1f); line-height: 1.1; }
.mpg__kpi-lbl { font-size: .72rem; font-weight: 600; color: var(--c-ink-500, #6b7280); }

.mpg__meses { display: flex; align-items: center; justify-content: space-between; padding: .9rem 1rem .5rem; }
.mpg__mes-btn { width: 34px; height: 34px; border-radius: 50%; border: 1px solid var(--c-slate-200); background: #fff; color: var(--c-slate-700); }
.mpg__mes-btn:disabled { opacity: .35; }
.mpg__mes-txt { font-size: .85rem; font-weight: 700; color: var(--c-slate-800); }

.mpg__loading { display: flex; align-items: center; gap: .5rem; justify-content: center; padding: 2.5rem; color: var(--c-slate-400); font-size: .875rem; }
.mpg__spin { animation: mpg-spin .8s linear infinite; }
@keyframes mpg-spin { to { transform: rotate(360deg); } }
.mpg__empty { margin: 0 1rem; display: flex; flex-direction: column; align-items: center; gap: .3rem; padding: 2.2rem 1rem; text-align: center; color: var(--c-slate-500); background: #fff; border: 1px dashed var(--c-leaf-200, #cfe0d6); border-radius: 14px; }
.mpg__empty i { font-size: 2rem; color: var(--c-leaf-500, #5A8A72); }
.mpg__empty-title { margin: .3rem 0 0; font-size: .92rem; font-weight: 700; color: var(--c-slate-900); }
.mpg__empty-hint { margin: 0; font-size: .8rem; }

.mpg__list { list-style: none; margin: 0; padding: 0 1rem; display: flex; flex-direction: column; gap: .45rem; }
.mpg__item { display: flex; align-items: center; gap: .7rem; padding: .7rem .8rem; background: #fff; border: 1px solid var(--c-leaf-100, #e8f0eb); border-radius: 14px; }
.mpg__item-ico { width: 36px; height: 36px; border-radius: 10px; display: grid; place-items: center; font-size: 1rem; flex-shrink: 0; }
.mpg__item-txt { display: flex; flex-direction: column; gap: .1rem; min-width: 0; flex: 1; }
.mpg__item-desc { font-size: .9rem; font-weight: 600; color: var(--c-ink-900, #1a1d1f); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.mpg__item-sub { font-size: .74rem; color: var(--c-ink-500, #6b7280); }
.mpg__item-monto { font-weight: 700; font-size: .95rem; color: var(--c-ink-900, #1a1d1f); white-space: nowrap; }
.mpg__pie { margin: 1rem 1rem 0; font-size: .76rem; color: var(--c-slate-500); text-align: center; }
.mpg__pie a { color: var(--c-leaf-700, #2D7D46); font-weight: 600; }

/* Sheet */
.mpg__form { display: flex; flex-direction: column; gap: .8rem; padding-bottom: .5rem; }
.mpg__field { display: flex; flex-direction: column; gap: .3rem; min-width: 0; }
.mpg__row-2 { display: grid; grid-template-columns: 1fr 1fr; gap: .6rem; }
.mpg__label { font-size: .76rem; font-weight: 700; color: var(--c-slate-600); text-transform: uppercase; letter-spacing: .04em; }
.mpg__opt { font-weight: 500; text-transform: none; letter-spacing: 0; color: var(--c-slate-400); }
.mpg__input { width: 100%; padding: .7rem .8rem; border: 1.5px solid var(--c-slate-200); border-radius: 10px; font: inherit; font-size: 1rem; background: #fff; min-width: 0; }
.mpg__input:focus { outline: none; border-color: var(--c-leaf-500, #5A8A72); }
.mpg__input-row { display: flex; align-items: center; gap: .5rem; }
.mpg__input--num { font-size: 1.5rem; font-weight: 700; }
.mpg__input-u { font-size: 1.1rem; font-weight: 700; color: var(--c-slate-500); }
.mpg__error { margin: 0; font-size: .82rem; color: #b91c1c; }
.mpg__resumen { margin: 0; font-size: .85rem; color: var(--c-slate-700); }
.mpg__form-actions { display: flex; gap: .5rem; }
.mpg__btn { flex: 1; padding: .8rem; border-radius: 12px; font-size: .95rem; font-weight: 700; border: none; }
.mpg__btn--ghost { background: var(--c-slate-100); color: var(--c-slate-700); }
.mpg__btn--primary { background: var(--c-leaf-800, #1A3D2E); color: #fff; }
.mpg__btn--primary:disabled { opacity: .5; }
</style>
