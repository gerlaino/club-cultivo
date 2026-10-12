<script setup>
// EL RESUMEN DE CONTABILIDAD (12-oct-2026, rediseño aprobado en el lienzo). Responde, en este
// orden: cómo viene el mes (contra el mes pasado A LA MISMA FECHA), dónde está la plata ahora,
// cuánto nos deben y desde cuándo, en qué se gana y en qué se gasta, los últimos doce meses, los
// últimos 20 movimientos (cada uno abre su detalle), cada sede y el cierre del período.
//
// No calcula nada que el servidor no mande: todo sale de `/movimientos_contables/dashboard`
// (`Contabilidad::Posicion` es la misma cuenta que usa el panel de conducción).
import { ref, computed, watch, onMounted } from 'vue'
import { listMovimientos, listMovimientosRecurrentes } from '../../lib/api'

const props = defineProps({
  dashboard:       { type: Object, required: true },
  sedes:           { type: Array, default: () => [] },
  sedeId:          { type: [Number, String], default: null },
  canEdit:         { type: Boolean, default: false },
  puedeCerrar:     { type: Boolean, default: false },
  cerrando:        { type: Boolean, default: false },
  finMesAnterior:  { type: Date, required: true },
  editable:        { type: Function, default: () => false },
})
const emit = defineEmits(['cambiar-sede', 'detalle', 'editar', 'eliminar', 'ir-libro', 'ir-deudores', 'ir-recurrentes', 'cerrar-mes', 'reabrir'])

const MESES = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre']
const hoy = new Date()
const mesActual = MESES[hoy.getMonth()]
const mesAnterior = MESES[(hoy.getMonth() + 11) % 12]

const pesos = (n) => '$ ' + Math.round(Math.abs(Number(n) || 0)).toLocaleString('es-AR')
const conSigno = (n) => (Number(n) < 0 ? '− ' : '') + pesos(n)
const fechaCorta = (iso) => { if (!iso) return ''; const [y, m, d] = String(iso).slice(0, 10).split('-'); return `${d}/${m}/${y}` }

// ── Resultado del mes ─────────────────────────────────────────────────────────
const mes = computed(() => props.dashboard.mes_actual || {})
const variacion = computed(() => {
  const ant = Number(props.dashboard.mes_anterior_a_la_fecha?.balance)
  if (!ant) return null
  return Math.round(((Number(mes.value.balance) - ant) / Math.abs(ant)) * 100)
})
const margen = computed(() => {
  const ing = Number(mes.value.ingresos)
  return ing > 0 ? Math.round((Number(mes.value.balance) / ing) * 100) : null
})

// ── Dónde está la plata ───────────────────────────────────────────────────────
const pos = computed(() => props.dashboard.posicion || {})
const tramos = computed(() => {
  const a = pos.value.antiguedad || {}
  const total = Number(pos.value.por_cobrar_ars) || 0
  return [
    { k: 'hasta_30', label: 'Hasta 30 días', v: Number(a.hasta_30) || 0 },
    { k: 'de_30_a_60', label: '31 a 60 días', v: Number(a.de_30_a_60) || 0 },
    { k: 'mas_de_60', label: 'Más de 60 días', v: Number(a.mas_de_60) || 0 },
  ].map(t => ({ ...t, pct: total > 0 ? (t.v / total) * 100 : 0 }))
})

// ── Ingresos y egresos por categoría ──────────────────────────────────────────
const porCategoria = computed(() => mes.value.por_categoria || [])
const ingresosPorConcepto = computed(() => porCategoria.value.filter(c => ['ingreso', 'recupero_costo'].includes(c.tipo)))
const egresosPorCategoria = computed(() => porCategoria.value.filter(c => c.tipo === 'egreso'))
const barra = (lista, v) => { const max = Math.max(...lista.map(c => c.total), 1); return `${(v / max) * 100}%` }

// Gastos fijos que se cargaron otros meses y éste todavía no (`/recurrentes`).
const fijosSinCargar = ref(0)
async function cargarFijos () {
  try {
    const m = `${hoy.getFullYear()}-${String(hoy.getMonth() + 1).padStart(2, '0')}`
    const { data } = await listMovimientosRecurrentes({ mes: m })
    fijosSinCargar.value = (data?.fijos || []).filter(f => !f.ya_cargado && f.tipo !== 'ingreso').length
  } catch { fijosSinCargar.value = 0 }
}

// ── Últimos doce meses ───────────────────────────────────────────────────────
const serie = computed(() => props.dashboard.ultimos_12_meses || [])
const total12 = computed(() => serie.value.reduce((a, m) => a + Number(m.balance || 0), 0))
const escala = computed(() => Math.max(...serie.value.map(m => Math.abs(Number(m.balance) || 0)), 1))
const altoBarra = (m) => `${(Math.abs(Number(m.balance) || 0) / escala.value) * 100}%`
const hayNegativos = computed(() => serie.value.some(m => Number(m.balance) < 0))

// ── Últimos movimientos ──────────────────────────────────────────────────────
// «Todos» son los del tablero; Ingresos/Egresos se piden al libro, para que sean 20 de ese tipo
// y no lo que queda de filtrar los 20 mezclados.
const TIPOS = [['todos', 'Todos'], ['ingreso', 'Ingresos'], ['egreso', 'Egresos']]
const tipo = ref('todos')
const porTipo = ref([])
const cargandoTipo = ref(false)
const movimientos = computed(() => tipo.value === 'todos' ? (props.dashboard.ultimos_movimientos || []) : porTipo.value)
watch(tipo, async (t) => {
  if (t === 'todos') return
  cargandoTipo.value = true
  try {
    const params = { per_page: 20, tipo: t }
    if (props.sedeId) params.sede_id = props.sedeId
    const { data } = await listMovimientos(params)
    porTipo.value = data?.movimientos || []
  } catch { porTipo.value = [] } finally { cargandoTipo.value = false }
})
watch(() => props.dashboard, () => { tipo.value = 'todos' })

const MEDIOS = { efectivo: 'Efectivo', transferencia: 'Transferencia', mercado_pago: 'Mercado Pago', cuenta_corriente: 'Cuenta corriente', saldo_a_favor: 'Saldo a favor', no_abona: 'No abona' }
const signo = (m) => m.tipo === 'egreso' ? -1 : (['ingreso', 'recupero_costo'].includes(m.tipo) ? 1 : 0)
function cuando (m) {
  const f = fechaCorta(m.fecha).slice(0, 5)
  if (!m.created_at) return f
  const c = new Date(m.created_at)
  const mismoDia = c.toLocaleDateString('en-CA', { timeZone: 'America/Argentina/Buenos_Aires' }) === String(m.fecha).slice(0, 10)
  return mismoDia ? `${f} ${c.toLocaleTimeString('es-AR', { hour: '2-digit', minute: '2-digit', hour12: false, timeZone: 'America/Argentina/Buenos_Aires' })}` : f
}
const categoria = (m) => m.categoria_madre || m.categoria_label || '—'

// ── Por sede y por sector ────────────────────────────────────────────────────
const porSede = computed(() => props.dashboard.por_sede || [])
const sectores = computed(() => (props.dashboard.por_unidad || []).filter(u => u.ingresos || u.egresos || u.a_cobrar))
const sectoresComparables = computed(() => sectores.value.filter(u => u.id != null).length >= 2)

// ── Cierre ───────────────────────────────────────────────────────────────────
const cerradoHasta = computed(() => props.dashboard.contabilidad_cerrada_hasta)
const enLaCalle = computed(() => Number(props.dashboard.envios_en_la_calle_al_cierre) || 0)
const sinRevisar = computed(() => Number(props.dashboard.cierres_sin_revisar_al_cierre) || 0)

onMounted(cargarFijos)
</script>

<template>
  <div class="rc">
    <!-- Alcance -->
    <div class="rc__seg" role="group" aria-label="Alcance">
      <button class="rc__seg-btn" :class="{ 'is-on': !sedeId }" @click="emit('cambiar-sede', null)">Toda la organización</button>
      <button v-for="s in sedes" :key="s.id" class="rc__seg-btn" :class="{ 'is-on': sedeId === s.id }" @click="emit('cambiar-sede', s.id)">{{ s.nombre }}</button>
    </div>

    <!-- Fila 1: resultado, disponibilidades, por cobrar -->
    <div class="rc__fila rc__fila--3">
      <section class="rc__card rc__card--oscura">
        <h2 class="rc__h2 rc__h2--claro">Resultado operativo de {{ mesActual }}</h2>
        <div class="rc__grande num" :class="{ 'rc__grande--neg': mes.balance < 0 }">{{ conSigno(mes.balance) }}</div>
        <p v-if="variacion != null" class="rc__var">
          {{ variacion > 0 ? '+' : '' }}{{ variacion }} % vs. {{ mesAnterior }} a la misma fecha
        </p>
        <p v-else class="rc__var">Sin resultado en {{ mesAnterior }} a la misma fecha para comparar</p>
        <dl class="rc__dl rc__dl--claro">
          <div><dt>Ingresos</dt><dd class="num">{{ pesos(mes.ingresos) }}</dd></div>
          <div><dt>Egresos</dt><dd class="num">{{ pesos(mes.egresos) }}</dd></div>
          <div v-if="margen != null"><dt>Margen</dt><dd class="num">{{ margen }} %</dd></div>
        </dl>
      </section>

      <section class="rc__card">
        <h2 class="rc__h2">Disponibilidades</h2>
        <div class="rc__grande num">{{ pesos(pos.disponible_ars) }}</div>
        <dl class="rc__dl">
          <div><dt>Efectivo en cajas abiertas ({{ pos.cajas_abiertas || 0 }})</dt><dd class="num">{{ pesos(pos.efectivo_en_cajas_ars) }}</dd></div>
          <div v-if="!sedeId"><dt>Efectivo de delivery sin rendir</dt><dd class="num">{{ pesos(pos.delivery_sin_rendir_ars) }}</dd></div>
        </dl>
        <p class="rc__nota">Efectivo que el arqueo espera encontrar. El saldo bancario no se registra en el sistema.</p>
      </section>

      <section class="rc__card">
        <div class="rc__card-hd">
          <h2 class="rc__h2">Cuentas por cobrar</h2>
          <button class="rc__link" @click="emit('ir-deudores')">Ver deudores</button>
        </div>
        <div class="rc__grande num">{{ pesos(pos.por_cobrar_ars) }}</div>
        <p class="rc__sub">{{ pos.deudores || 0 }} {{ pos.deudores === 1 ? 'paciente' : 'pacientes' }} · antigüedad de la deuda</p>
        <ul class="rc__tramos">
          <li v-for="t in tramos" :key="t.k">
            <span class="rc__tramo-lbl">{{ t.label }}</span>
            <span class="rc__tramo-bar"><span :class="['rc__tramo-fill', `rc__tramo-fill--${t.k}`]" :style="{ width: t.pct + '%' }"></span></span>
            <span class="num">{{ pesos(t.v) }}</span>
          </li>
        </ul>
      </section>
    </div>

    <!-- Fila 2: por concepto / por categoría -->
    <div class="rc__fila rc__fila--2">
      <section class="rc__card">
        <div class="rc__card-hd"><h2 class="rc__h2">Ingresos por concepto</h2><span class="rc__sub">{{ mesActual }}</span></div>
        <p v-if="!ingresosPorConcepto.length" class="rc__vacio">Sin ingresos cobrados este mes.</p>
        <ul v-else class="rc__barras">
          <li v-for="c in ingresosPorConcepto" :key="c.categoria + c.tipo">
            <span class="rc__barra-lbl">{{ c.categoria }}</span>
            <span class="rc__barra"><span class="rc__barra-fill rc__barra-fill--in" :style="{ width: barra(ingresosPorConcepto, c.total) }"></span></span>
            <span class="num">{{ pesos(c.total) }}</span>
          </li>
        </ul>
      </section>
      <section class="rc__card">
        <div class="rc__card-hd">
          <h2 class="rc__h2">Egresos por categoría</h2>
          <button v-if="fijosSinCargar" class="rc__aviso" @click="emit('ir-recurrentes')">
            {{ fijosSinCargar }} {{ fijosSinCargar === 1 ? 'gasto fijo del mes sin registrar' : 'gastos fijos del mes sin registrar' }}
          </button>
        </div>
        <p v-if="!egresosPorCategoria.length" class="rc__vacio">Sin egresos este mes.</p>
        <ul v-else class="rc__barras">
          <li v-for="c in egresosPorCategoria" :key="c.categoria + c.tipo">
            <span class="rc__barra-lbl">{{ c.categoria }}</span>
            <span class="rc__barra"><span class="rc__barra-fill rc__barra-fill--out" :style="{ width: barra(egresosPorCategoria, c.total) }"></span></span>
            <span class="num">{{ pesos(c.total) }}</span>
          </li>
        </ul>
      </section>
    </div>

    <!-- Últimos doce meses -->
    <section class="rc__card">
      <div class="rc__card-hd">
        <h2 class="rc__h2">Resultado de los últimos 12 meses</h2>
        <span class="rc__sub">Acumulado <b class="num" :class="total12 < 0 ? 'is-neg' : 'is-pos'">{{ conSigno(total12) }}</b></span>
      </div>
      <div class="rc__chart" :class="{ 'rc__chart--neg': hayNegativos }">
        <div v-for="m in serie" :key="m.mes" class="rc__col" :title="`${m.mes_label} · ingresos ${pesos(m.ingresos)} · egresos ${pesos(m.egresos)} · resultado ${conSigno(m.balance)}`">
          <div class="rc__col-pos"><span v-if="m.balance > 0" class="rc__col-bar" :style="{ height: altoBarra(m) }"></span></div>
          <div v-if="hayNegativos" class="rc__col-neg"><span v-if="m.balance < 0" class="rc__col-bar rc__col-bar--neg" :style="{ height: altoBarra(m) }"></span></div>
          <span class="rc__col-lbl">{{ m.mes_label }}</span>
        </div>
      </div>
    </section>

    <!-- Últimos movimientos -->
    <section class="rc__card">
      <div class="rc__card-hd">
        <h2 class="rc__h2">Últimos movimientos</h2>
        <div class="rc__hd-der">
          <div class="rc__seg rc__seg--chico" role="group" aria-label="Tipo de movimiento">
            <button v-for="[id, nombre] in TIPOS" :key="id" class="rc__seg-btn" :class="{ 'is-on': tipo === id }" @click="tipo = id">{{ nombre }}</button>
          </div>
          <button class="rc__link" @click="emit('ir-libro')">Ver el libro diario completo</button>
        </div>
      </div>
      <p v-if="cargandoTipo" class="rc__vacio">Cargando…</p>
      <p v-else-if="!movimientos.length" class="rc__vacio">Sin movimientos todavía.</p>
      <div v-else class="rc__tabla-wrap">
        <table class="rc__tabla">
          <thead>
            <tr>
              <th>Fecha</th><th>Concepto</th><th>Categoría</th><th>Sede</th><th>Medio</th><th>Registró</th>
              <th class="der">Importe</th><th v-if="canEdit"><span class="visually-hidden">Acciones</span></th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="m in movimientos" :key="m.id" class="rc__mov" tabindex="0" @click="emit('detalle', m)" @keydown.enter="emit('detalle', m)">
              <td class="num rc__nowrap">{{ cuando(m) }}</td>
              <td class="rc__concepto">
                {{ m.descripcion }}
                <span v-if="['ingreso','recupero_costo'].includes(m.tipo) && m.pagado === false" class="rc__pill">a cobrar</span>
              </td>
              <td class="rc__muted">{{ categoria(m) }}</td>
              <td class="rc__muted">{{ m.sede?.nombre || '—' }}</td>
              <td class="rc__muted">{{ MEDIOS[m.medio_pago] || m.medio_pago || '—' }}</td>
              <td class="rc__muted">{{ m.created_by || '—' }}</td>
              <td class="der num rc__nowrap" :class="{ 'is-neg': signo(m) < 0, 'is-pos': signo(m) > 0 }">
                {{ signo(m) < 0 ? '− ' : signo(m) > 0 ? '+ ' : '' }}{{ pesos(m.monto_ars) }}
              </td>
              <td v-if="canEdit" class="rc__acc" @click.stop>
                <template v-if="editable(m)">
                  <button class="rc__icon" title="Editar" aria-label="Editar" @click="emit('editar', m)"><i class="bi bi-pencil"></i></button>
                  <button class="rc__icon rc__icon--peligro" title="Eliminar" aria-label="Eliminar" @click="emit('eliminar', m)"><i class="bi bi-trash"></i></button>
                </template>
                <i v-else-if="m.cerrado" class="bi bi-lock-fill rc__muted" title="Período cerrado: no se modifica"></i>
                <i v-else class="bi bi-link-45deg rc__muted" title="Generado por una dispensa: se corrige desde la dispensa"></i>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
      <p class="rc__pie">Los 20 más recientes{{ sedeId ? ' de esta sede' : ', de cualquier sede' }}. Tocá una fila para ver el detalle.</p>
    </section>

    <!-- Por sede / por sector / cierre -->
    <div class="rc__fila rc__fila--2">
      <section v-if="!sedeId && porSede.length > 1" class="rc__card">
        <div class="rc__card-hd"><h2 class="rc__h2">Por sede</h2><span class="rc__sub">{{ mesActual }}</span></div>
        <div class="rc__tabla-wrap">
          <table class="rc__tabla">
            <thead><tr><th>Sede</th><th class="der">Ingresos</th><th class="der">Egresos</th><th class="der">Resultado</th></tr></thead>
            <tbody>
              <tr v-for="s in porSede" :key="s.id ?? 'sin-sede'" :class="{ 'rc__mov': s.id }" @click="s.id && emit('cambiar-sede', s.id)">
                <td>{{ s.nombre }}</td>
                <td class="der num">{{ pesos(s.ingresos) }}</td>
                <td class="der num">{{ pesos(s.egresos) }}</td>
                <td class="der num" :class="s.balance < 0 ? 'is-neg' : 'is-pos'">{{ conSigno(s.balance) }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>

      <section v-if="sectoresComparables" class="rc__card">
        <div class="rc__card-hd"><h2 class="rc__h2">Por sector</h2><span class="rc__sub">{{ mesActual }}</span></div>
        <div class="rc__tabla-wrap">
          <table class="rc__tabla">
            <thead><tr><th>Sector</th><th class="der">Ingresos</th><th class="der">A cobrar</th><th class="der">Egresos</th><th class="der">Resultado</th></tr></thead>
            <tbody>
              <tr v-for="u in sectores" :key="u.id ?? 'sin'">
                <td>{{ u.id == null ? 'Sin sector' : u.nombre }}</td>
                <td class="der num">{{ pesos(u.ingresos) }}</td>
                <td class="der num rc__muted">{{ u.a_cobrar ? pesos(u.a_cobrar) : '—' }}</td>
                <td class="der num">{{ pesos(u.egresos) }}</td>
                <td class="der num" :class="u.balance < 0 ? 'is-neg' : 'is-pos'">{{ conSigno(u.balance) }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>

      <section v-if="canEdit" class="rc__card rc__pad">
        <h2 class="rc__h2">Cierre de período</h2>
        <p class="rc__texto">
          <template v-if="cerradoHasta">Libro cerrado hasta el <b>{{ fechaCorta(cerradoHasta) }}</b>: los movimientos anteriores no se modifican.</template>
          <template v-else>No hay períodos cerrados: todos los movimientos se pueden modificar.</template>
          <template v-if="puedeCerrar"> Cerrar {{ mesAnterior }} lo congela para los informes y la auditoría.</template>
        </p>
        <ul v-if="puedeCerrar && (enLaCalle || sinRevisar)" class="rc__pendientes">
          <li v-if="enLaCalle">{{ enLaCalle }} {{ enLaCalle === 1 ? `envío de ${mesAnterior} sigue` : `envíos de ${mesAnterior} siguen` }} en la calle</li>
          <li v-if="sinRevisar">
            <RouterLink to="/mostrador?solapa=cierres">{{ sinRevisar }} {{ sinRevisar === 1 ? `cierre de caja de ${mesAnterior} sin revisar` : `cierres de caja de ${mesAnterior} sin revisar` }}</RouterLink>
          </li>
        </ul>
        <div class="rc__acciones">
          <button v-if="puedeCerrar" class="rc__btn" :disabled="cerrando" @click="emit('cerrar-mes')">
            Cerrar hasta el {{ finMesAnterior.toLocaleDateString('es-AR', { day: '2-digit', month: '2-digit', year: 'numeric' }) }}
          </button>
          <button v-if="cerradoHasta" class="rc__btn rc__btn--ghost" @click="emit('reabrir')">Reabrir</button>
        </div>
      </section>
    </div>
  </div>
</template>

<style scoped>
.rc { display: flex; flex-direction: column; gap: 20px; }
.num { font-family: var(--font-mono); font-variant-numeric: tabular-nums; }
.der { text-align: right; }
.is-neg { color: var(--c-rust-600); }
.is-pos { color: var(--c-leaf-600); }

.rc__seg { display: flex; flex-wrap: wrap; gap: 2px; background: white; border: 1px solid var(--c-leaf-100); border-radius: 10px; padding: 3px; align-self: flex-start; max-width: 100%; }
.rc__seg--chico { align-self: auto; }
.rc__seg-btn { border: 0; background: transparent; border-radius: 8px; padding: 7px 12px; min-height: 34px; font: 600 var(--fs-13) var(--font-ui); color: var(--c-ink-700); cursor: pointer; }
.rc__seg-btn.is-on { background: var(--c-leaf-800); color: white; }

.rc__fila { display: grid; gap: 20px; }
.rc__fila--3 { grid-template-columns: minmax(0, 1.3fr) minmax(0, 1fr) minmax(0, 1fr); }
.rc__fila--2 { grid-template-columns: repeat(auto-fit, minmax(320px, 1fr)); }
@media (max-width: 980px) { .rc__fila--3 { grid-template-columns: 1fr; } }
@media (max-width: 520px) { .rc__fila--2 { grid-template-columns: 1fr; } }

.rc__card { background: white; border: 1px solid var(--c-leaf-100); border-radius: 16px; padding: 18px 22px; min-width: 0; display: flex; flex-direction: column; gap: 10px; }
.rc__card--oscura { background: var(--c-leaf-800); border-color: var(--c-leaf-800); color: white; }
.rc__card-hd { display: flex; flex-wrap: wrap; align-items: baseline; justify-content: space-between; gap: 6px 16px; }
.rc__hd-der { display: flex; flex-wrap: wrap; align-items: center; gap: 12px; }
.rc__h2 { margin: 0; font-family: var(--font-display); font-size: 17px; font-weight: 600; color: var(--c-ink-900); }
.rc__h2--claro { color: var(--c-leaf-100); font-size: var(--fs-14); font-weight: 600; }
.rc__grande { font-family: var(--font-mono); font-size: 30px; font-weight: 600; line-height: 1.1; color: var(--c-ink-900); }
.rc__card--oscura .rc__grande { color: white; font-size: 36px; }
.rc__grande--neg { color: var(--c-rust-100) !important; }
.rc__var { margin: 0; font-size: var(--fs-13); color: var(--c-leaf-300); }
.rc__sub { font-size: var(--fs-12); color: var(--c-ink-500); }
.rc__nota, .rc__pie { margin: 0; font-size: var(--fs-12); color: var(--c-ink-500); }
.rc__vacio { margin: 0; font-size: var(--fs-13); color: var(--c-ink-500); }
.rc__texto { margin: 0; font-size: var(--fs-13); color: var(--c-ink-700); line-height: 1.5; }
.rc__muted { color: var(--c-ink-500); }

.rc__dl { margin: 4px 0 0; display: flex; flex-direction: column; gap: 6px; }
.rc__dl > div { display: flex; justify-content: space-between; gap: 12px; font-size: var(--fs-13); }
.rc__dl dt { font-weight: 400; color: var(--c-ink-700); }
.rc__dl dd { margin: 0; font-weight: 600; color: var(--c-ink-900); }
.rc__dl--claro { border-top: 1px solid rgb(255 255 255 / .15); padding-top: 10px; }
.rc__dl--claro dt { color: var(--c-leaf-100); }
.rc__dl--claro dd { color: white; }

.rc__tramos, .rc__barras, .rc__pendientes { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: 8px; }
.rc__tramos li, .rc__barras li { display: grid; grid-template-columns: minmax(112px, auto) minmax(60px, 1fr) auto; gap: 10px; align-items: center; font-size: var(--fs-13); }
.rc__tramo-lbl, .rc__barra-lbl { color: var(--c-ink-700); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.rc__tramo-bar, .rc__barra { height: 8px; background: var(--c-leaf-50); border-radius: 999px; overflow: hidden; }
.rc__tramo-fill, .rc__barra-fill { display: block; height: 100%; border-radius: 999px; }
.rc__tramo-fill--hasta_30 { background: var(--c-leaf-500); }
.rc__tramo-fill--de_30_a_60 { background: var(--c-amber-500); }
.rc__tramo-fill--mas_de_60 { background: var(--c-rust-600); }
.rc__barra-fill--in { background: var(--c-leaf-500); }
.rc__barra-fill--out { background: var(--c-ink-500); }

.rc__link { border: 0; background: none; padding: 0; font: 600 var(--fs-13) var(--font-ui); color: var(--c-leaf-700); cursor: pointer; text-decoration: underline; text-underline-offset: 3px; }
.rc__aviso { border: 0; background: var(--c-amber-100); color: var(--c-gold-500); border-radius: 999px; padding: 4px 10px; font: 600 var(--fs-12) var(--font-ui); cursor: pointer; }
.rc__pill { display: inline-block; margin-left: 6px; padding: 1px 7px; border-radius: 999px; background: var(--c-amber-100); color: var(--c-gold-500); font-size: 11px; font-weight: 600; }

/* Gráfico de doce meses: barras de resultado, verdes arriba y rojas abajo del cero. */
.rc__chart { display: grid; grid-template-columns: repeat(12, minmax(0, 1fr)); gap: 8px; align-items: end; padding-top: 6px; }
.rc__col { display: grid; grid-template-rows: 140px auto auto; gap: 0; min-width: 0; }
.rc__chart--neg .rc__col { grid-template-rows: 110px 60px auto; }
.rc__col-pos { display: flex; align-items: flex-end; justify-content: center; border-bottom: 1px solid var(--c-ink-300); }
.rc__col-neg { display: flex; align-items: flex-start; justify-content: center; }
.rc__col-bar { display: block; width: 70%; max-width: 34px; min-height: 2px; background: var(--c-leaf-500); border-radius: 4px 4px 0 0; }
.rc__col-bar--neg { background: var(--c-rust-600); border-radius: 0 0 4px 4px; }
.rc__col-lbl { margin-top: 6px; text-align: center; font-size: 11px; color: var(--c-ink-500); text-transform: lowercase; }

.rc__tabla-wrap { overflow-x: auto; margin: 0 -22px; }
.rc__tabla { width: 100%; border-collapse: collapse; font-size: var(--fs-13); }
.rc__tabla th { text-align: left; padding: 8px 12px; font-weight: 600; font-size: var(--fs-12); color: var(--c-ink-500); border-bottom: 1px solid var(--c-leaf-100); white-space: nowrap; }
.rc__tabla th.der { text-align: right; }
.rc__tabla td { padding: 10px 12px; border-bottom: 1px solid var(--c-leaf-50); color: var(--c-ink-900); vertical-align: middle; }
.rc__tabla th:first-child, .rc__tabla td:first-child { padding-left: 22px; }
.rc__tabla th:last-child, .rc__tabla td:last-child { padding-right: 22px; }
.rc__mov { cursor: pointer; }
.rc__mov:hover, .rc__mov:focus-visible { background: var(--c-leaf-50); outline: none; }
.rc__nowrap { white-space: nowrap; }
.rc__concepto { min-width: 220px; }
.rc__acc { white-space: nowrap; text-align: right; }
.rc__icon { border: 0; background: none; padding: 4px 6px; color: var(--c-ink-500); cursor: pointer; border-radius: 6px; }
.rc__icon:hover { background: var(--c-leaf-50); color: var(--c-ink-900); }
.rc__icon--peligro:hover { color: var(--c-rust-600); }

.rc__pendientes li { font-size: var(--fs-13); color: var(--c-gold-500); padding-left: 14px; position: relative; }
.rc__pendientes li::before { content: ''; position: absolute; left: 0; top: 7px; width: 6px; height: 6px; border-radius: 50%; background: var(--c-amber-500); }
.rc__pendientes a { color: inherit; }
.rc__acciones { display: flex; flex-wrap: wrap; gap: 8px; margin-top: 4px; }
.rc__btn { border: 0; background: var(--c-leaf-800); color: white; border-radius: 8px; padding: 9px 14px; min-height: 38px; font: 600 var(--fs-13) var(--font-ui); cursor: pointer; }
.rc__btn:disabled { opacity: .6; cursor: default; }
.rc__btn--ghost { background: white; color: var(--c-ink-700); border: 1px solid var(--c-ink-300); }
.rc__pad { padding: 18px 22px; }
</style>
