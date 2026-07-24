<script setup>
// Ficha de un evento (Capa 2): el centro de mando. P&L, break-even, presupuesto vs real,
// costos/proveedores y tareas. Todo editable/borrable (y recuperable desde la papelera).
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useEventosBarStore } from '../../stores/eventosBar.js'
import { useToast } from '../../composables/useToast.js'
import { useConfirm } from '../../composables/useConfirm.js'
import EventoProvision from './EventoProvision.vue'

const store  = useEventosBarStore()
const route  = useRoute()
const router = useRouter()
const toast  = useToast()
const { confirm } = useConfirm()
const barId  = route.params.barId
const evId   = route.params.eventoId

const ESTADOS = [
  { v: 'planificado', l: 'Planificado' }, { v: 'en_venta', l: 'En venta' },
  { v: 'en_curso', l: 'En curso' }, { v: 'finalizado', l: 'Cerrado' }, { v: 'cancelado', l: 'Cancelado' },
]
const fmt = (n) => `$${Math.round(n || 0).toLocaleString('es-AR')}`
const e = computed(() => store.actual)

onMounted(() => store.fetchDetalle(barId, evId))

// Break-even en $: los ingresos necesarios = costos comprometidos.
const beMeta   = computed(() => e.value?.costos_comprometidos || 0)
const beActual = computed(() => e.value?.resultado?.ingresos || 0)
const bePct    = computed(() => beMeta.value > 0 ? Math.min(100, Math.round(beActual.value / beMeta.value * 100)) : (beActual.value > 0 ? 100 : 0))

// ── Fase del evento: la pantalla se adapta al momento del ciclo ──
// planificando (plan/en_venta) → prep · en curso → operativo · cerrado → P&L.
const FASE = { planificado: 'plan', en_venta: 'plan', en_curso: 'curso', finalizado: 'cerrado', cancelado: 'cancelado' }
const fase = computed(() => FASE[e.value?.estado] || 'plan')
const esCerrado  = computed(() => fase.value === 'cerrado')
const estadoLabel = computed(() => ESTADOS.find(s => s.v === e.value?.estado)?.l || e.value?.estado)
const resultadoMostrar = computed(() => esCerrado.value ? (e.value?.resultado?.resultado || 0) : (e.value?.resultado_proyectado || 0))
// Los números "se prenden" solo cuando hay algo real: no mostramos un tablero en $0.
const tieneNumeros = computed(() => {
  const r = e.value?.resultado || {}
  return (r.ingresos || 0) + (r.egresos || 0) + (e.value?.presupuesto_ingresos || 0) + (e.value?.costos_comprometidos || 0) > 0
})
const ocupacion = computed(() => {
  const a = e.value?.aforo, v = e.value?.entradas_vendidas || 0
  return a > 0 ? Math.min(100, Math.round(v / a * 100)) : null
})
const fechaInfo = computed(() => {
  const f = e.value?.fecha
  if (!f) return { fecha: 'Sin fecha', rel: '' }
  const hoy = new Date(); hoy.setHours(0, 0, 0, 0)
  const [y, m, d] = f.slice(0, 10).split('-').map(Number)
  const fe = new Date(y, m - 1, d)
  const diff = Math.round((fe - hoy) / 86400000)
  const fecha = fe.toLocaleDateString('es-AR', { day: 'numeric', month: 'long', year: 'numeric' })
  let rel = ''
  if (diff === 0) rel = 'Hoy'
  else if (diff === 1) rel = 'Mañana'
  else if (diff > 1) rel = `En ${diff} días`
  else if (diff === -1) rel = 'Ayer'
  else if (diff < -1) rel = `Hace ${-diff} días`
  return { fecha, rel }
})

async function cambiarEstado(v) {
  try { await store.actualizar(barId, evId, { estado: v }); toast.success('Estado actualizado') }
  catch { toast.error(store.saveError) }
}
async function borrarEvento() {
  if (!(await confirm({ title: 'Eliminar evento', message: '¿Eliminar el evento? Se recupera desde la papelera.', variant: 'danger' }))) return
  try { await store.eliminar(barId, evId); toast.success('Evento eliminado'); router.push(`/bar/${barId}/eventos`) }
  catch { toast.error('No se pudo eliminar') }
}

// ── Entradas ──────────────────────────────────────────────────
const tipoForm = ref(null)
function nuevoTipo() { tipoForm.value = { nombre: '', precio_ars: null, cupo: null } }
async function guardarTipo() {
  const f = tipoForm.value
  if (!f.nombre?.trim() || !(f.precio_ars >= 0)) { toast.warning('Poné nombre y precio'); return }
  try { await store.crearTipo(barId, evId, { nombre: f.nombre.trim(), precio_ars: f.precio_ars, cupo: f.cupo || null }); tipoForm.value = null; toast.success('Tipo de entrada creado') }
  catch { toast.error(store.saveError) }
}
async function borrarTipo(t) {
  if (!(await confirm({ title: 'Eliminar tipo de entrada', message: `¿Eliminar "${t.nombre}"?`, variant: 'danger' }))) return
  try { await store.eliminarTipo(barId, evId, t.id) } catch { toast.error('No se pudo eliminar') }
}
const venderPara = ref(null)
const venderCant = ref(1)
const venderComprador = ref('')
function abrirVender(t) { venderPara.value = t; venderCant.value = 1; venderComprador.value = '' }
async function confirmarVender() {
  if (!(venderCant.value > 0)) { toast.warning('Cantidad inválida'); return }
  try { await store.vender(barId, evId, venderPara.value.id, { cantidad: venderCant.value, comprador: venderComprador.value || null }); venderPara.value = null; toast.success('Entradas vendidas') }
  catch { toast.error(store.saveError) }
}
function cupoPct(t) { return t.cupo ? Math.min(100, Math.round(t.vendidas / t.cupo * 100)) : (t.vendidas > 0 ? 100 : 0) }

// ── Costos ────────────────────────────────────────────────────
const costoForm = ref(null)
function nuevoCosto() { costoForm.value = { concepto: '', proveedor: '', monto_ars: null, pagado: false } }
async function guardarCosto() {
  const f = costoForm.value
  if (!f.concepto?.trim() || !(f.monto_ars > 0)) { toast.warning('Concepto y monto son obligatorios'); return }
  try { await store.crearCosto(barId, evId, { ...f, concepto: f.concepto.trim() }); costoForm.value = null; toast.success('Costo agregado') }
  catch { toast.error(store.saveError) }
}
async function togglePagado(c) {
  try { await store.actualizarCosto(barId, evId, c.id, { pagado: !c.pagado }) }
  catch { toast.error(store.saveError) }
}
async function borrarCosto(c) {
  if (!(await confirm({ title: 'Eliminar costo', message: `¿Eliminar "${c.concepto}"?`, variant: 'danger' }))) return
  try { await store.eliminarCosto(barId, evId, c.id) } catch { toast.error('No se pudo eliminar') }
}

// ── Tareas ────────────────────────────────────────────────────
const tareaForm = ref('')
async function agregarTarea() {
  if (!tareaForm.value.trim()) return
  try { await store.crearTarea(barId, evId, { titulo: tareaForm.value.trim() }); tareaForm.value = '' }
  catch { toast.error(store.saveError) }
}
async function toggleTarea(t) {
  try { await store.actualizarTarea(barId, evId, t.id, { hecha: !t.hecha }) } catch { toast.error(store.saveError) }
}
async function borrarTarea(t) {
  try { await store.eliminarTarea(barId, evId, t.id) } catch { toast.error('No se pudo eliminar') }
}
const tareasPendientes = computed(() => (e.value?.tareas || []).filter(t => !t.hecha).length)
</script>

<template>
  <div class="ed" v-if="e">
    <header class="ed__head">
      <div class="ed__head-l">
        <RouterLink :to="`/bar/${barId}/eventos`" class="ed__back">← Eventos</RouterLink>
        <div class="ed__title-row">
          <h1>{{ e.nombre }}</h1>
          <span class="ed__estado" :class="`ed__estado--${fase}`">{{ estadoLabel }}</span>
        </div>
        <p class="ed__sub">
          <span>📅 {{ fechaInfo.fecha }}<b v-if="fechaInfo.rel"> · {{ fechaInfo.rel }}</b></span>
          <span v-if="e.aforo" class="ed__sep">·</span>
          <span v-if="e.aforo">👥 {{ e.entradas_vendidas }} / {{ e.aforo }} lugares</span>
        </p>
        <div v-if="ocupacion != null" class="ed__ocup" :title="`${ocupacion}% del aforo`">
          <i :style="{ width: ocupacion + '%' }" :class="{ full: ocupacion >= 100 }"></i>
        </div>
      </div>
      <div class="ed__head-actions">
        <RouterLink :to="`/bar/${barId}/eventos/${evId}/entradas`" class="lnk lnk--btn">🎟️ Entradas</RouterLink>
        <RouterLink :to="`/bar/${barId}/eventos/${evId}/puerta`" class="lnk lnk--btn">🚪 Puerta</RouterLink>
        <select :value="e.estado" class="inp" @change="cambiarEstado($event.target.value)">
          <option v-for="s in ESTADOS" :key="s.v" :value="s.v">{{ s.l }}</option>
        </select>
        <button class="lnk lnk--danger" @click="borrarEvento">Eliminar</button>
      </div>
    </header>

    <!-- Cerrado → P&L completo (resultado real grande + KPIs + break-even) -->
    <template v-if="esCerrado">
      <div class="ed__result" :class="resultadoMostrar >= 0 ? 'is-pos' : 'is-neg'">
        <span>Resultado real</span>
        <strong>{{ fmt(resultadoMostrar) }}</strong>
        <small>ingresos {{ fmt(e.resultado.ingresos) }} − costos {{ fmt(e.resultado.egresos) }} − mercadería {{ fmt(e.resultado.cogs) }}</small>
      </div>
      <div class="ed__kpis">
        <div class="kpi"><span>Ingreso real</span><strong>{{ fmt(e.resultado.ingresos) }}</strong></div>
        <div class="kpi"><span>Costos (DJ, etc.)</span><strong>{{ fmt(e.resultado.egresos) }}</strong></div>
        <div class="kpi"><span>Costo mercadería</span><strong>{{ fmt(e.resultado.cogs) }}</strong></div>
        <div class="kpi"><span>Pagado</span><strong>{{ fmt(e.costos_pagados) }}</strong></div>
      </div>
    </template>

    <!-- Planificando / en curso → resumen de plata COMPACTO (sin tablero en $0) -->
    <div v-else class="ed__money">
      <div class="ed__money-strip">
        <div class="ed__money-item"><span>Ingresos estimados</span><b>{{ fmt(e.presupuesto_ingresos) }}</b></div>
        <div class="ed__money-item"><span>Costos</span><b>{{ fmt(e.costos_comprometidos) }}</b></div>
        <div class="ed__money-item"><span>Recaudado</span><b>{{ fmt(e.resultado.ingresos) }}</b></div>
        <div class="ed__money-item ed__money-item--res">
          <span>Proyectado</span>
          <b :class="resultadoMostrar >= 0 ? 'pos' : 'neg'">{{ fmt(resultadoMostrar) }}</b>
        </div>
      </div>
      <p v-if="!tieneNumeros" class="ed__money-hint">
        Todavía sin números — se completan solos a medida que cargás entradas y costos. Abajo tenés lo que hace falta para dejar el evento listo. 👇
      </p>
    </div>

    <!-- Break-even: solo cuando hay algo real que medir -->
    <div v-if="tieneNumeros && beMeta > 0" class="be">
      <div class="be__head"><b>Punto de equilibrio</b><span>necesitás <b>{{ fmt(beMeta) }}</b> de ingresos para cubrir costos</span></div>
      <div class="be__track"><i :class="{ over: beActual >= beMeta && beMeta > 0 }" :style="{ width: bePct + '%' }"></i></div>
      <div class="be__legend">
        <span>Recaudado <b>{{ fmt(beActual) }}</b></span>
        <span v-if="e.break_even_entradas">≈ <b>{{ e.break_even_entradas }}</b> entradas · vendidas <b>{{ e.entradas_vendidas }}</b></span>
        <span>{{ bePct }}%</span>
      </div>
    </div>

    <!-- Provisión de mercadería -->
    <EventoProvision :bar-id="barId" :ev-id="evId" :finalizado="e.estado === 'finalizado'" @cambio="store.fetchDetalle(barId, evId)" />

    <!-- Entradas -->
    <section class="card ed__entradas">
      <div class="card__head">
        <h2>Entradas <span class="mut">· {{ e.entradas_vendidas }} vendidas · {{ fmt(e.recaudacion_entradas) }}</span></h2>
        <button class="btn btn--sm btn--primary" @click="nuevoTipo">+ Tipo</button>
      </div>
      <form v-if="tipoForm" class="cform" @submit.prevent="guardarTipo">
        <input v-model.trim="tipoForm.nombre" class="inp" placeholder="Nombre (ej: General)" maxlength="50" />
        <input v-model.number="tipoForm.precio_ars" type="number" min="0" step="any" class="inp inp--sm" placeholder="Precio" />
        <input v-model.number="tipoForm.cupo" type="number" min="1" class="inp inp--sm" placeholder="Cupo" />
        <div class="cform__actions"><button type="button" class="btn btn--sm" @click="tipoForm = null">Cancelar</button><button type="submit" class="btn btn--sm btn--primary" :disabled="store.saving">Guardar</button></div>
      </form>
      <div v-if="!e.tipos_entrada?.length" class="empty">Sin tipos de entrada. Creá el primero.</div>
      <ul class="tt" v-else>
        <li v-for="t in e.tipos_entrada" :key="t.id" class="ttrow" :class="{ sold: t.agotado }">
          <div class="ttrow__main">
            <div class="ttrow__top"><span class="ttrow__n">{{ t.nombre }}</span><span class="ttrow__p">{{ fmt(t.precio_ars) }}</span></div>
            <div class="ttbar"><i :style="{ width: cupoPct(t) + '%' }"></i></div>
          </div>
          <span class="ttrow__q">{{ t.vendidas }}<span v-if="t.cupo">/{{ t.cupo }}</span></span>
          <button class="btn btn--sm btn--primary" :disabled="t.agotado" @click="abrirVender(t)">{{ t.agotado ? 'Agotado' : 'Vender' }}</button>
          <button class="lnk lnk--danger" @click="borrarTipo(t)">✕</button>
        </li>
      </ul>
    </section>

    <!-- Modal vender -->
    <div v-if="venderPara" class="ov" @click.self="venderPara = null">
      <div class="modal">
        <h3>Vender — {{ venderPara.nombre }}</h3>
        <p class="modal__hint">{{ fmt(venderPara.precio_ars) }} c/u<span v-if="venderPara.disponibles != null"> · quedan {{ venderPara.disponibles }}</span></p>
        <label class="fld2">Cantidad<input v-model.number="venderCant" type="number" min="1" class="inp" /></label>
        <label class="fld2">Comprador (opcional)<input v-model.trim="venderComprador" class="inp" maxlength="60" /></label>
        <div class="modal__total">Total <strong>{{ fmt((venderCant || 0) * venderPara.precio_ars) }}</strong></div>
        <div class="cform__actions"><button class="btn" @click="venderPara = null">Cancelar</button><button class="btn btn--primary" :disabled="store.saving" @click="confirmarVender">Confirmar venta</button></div>
      </div>
    </div>

    <div class="ed__cols">
      <!-- Costos -->
      <section class="card">
        <div class="card__head"><h2>Costos / proveedores</h2><button class="btn btn--sm btn--primary" @click="nuevoCosto">+ Costo</button></div>
        <form v-if="costoForm" class="cform" @submit.prevent="guardarCosto">
          <input v-model.trim="costoForm.concepto" class="inp" placeholder="Concepto (ej: DJ)" maxlength="60" />
          <input v-model.trim="costoForm.proveedor" class="inp" placeholder="Proveedor (opcional)" maxlength="60" />
          <input v-model.number="costoForm.monto_ars" type="number" min="0" step="any" class="inp inp--sm" placeholder="Monto" />
          <label class="chk"><input type="checkbox" v-model="costoForm.pagado" /> Pagado</label>
          <div class="cform__actions"><button type="button" class="btn btn--sm" @click="costoForm = null">Cancelar</button><button type="submit" class="btn btn--sm btn--primary" :disabled="store.saving">Guardar</button></div>
        </form>
        <ul class="clist">
          <li v-for="c in e.costos" :key="c.id">
            <div class="clist__main"><span class="clist__c">{{ c.concepto }}</span><small v-if="c.proveedor">{{ c.proveedor }}</small></div>
            <span class="clist__m">{{ fmt(c.monto_ars) }}</span>
            <button class="st-pill" :class="c.pagado ? 'pag' : 'pend'" @click="togglePagado(c)">{{ c.pagado ? 'pagado' : 'pendiente' }}</button>
            <button class="lnk lnk--danger" @click="borrarCosto(c)">✕</button>
          </li>
          <li v-if="!e.costos?.length" class="empty">Sin costos cargados.</li>
        </ul>
      </section>

      <!-- Tareas -->
      <section class="card">
        <div class="card__head"><h2>Cuenta regresiva</h2><span class="mut">{{ tareasPendientes }} pendientes</span></div>
        <form class="tform" @submit.prevent="agregarTarea">
          <input v-model="tareaForm" class="inp" placeholder="Agregar tarea…" maxlength="100" />
          <button type="submit" class="btn btn--sm btn--primary">+</button>
        </form>
        <ul class="tlist">
          <li v-for="t in e.tareas" :key="t.id" :class="{ done: t.hecha }">
            <button class="box" :class="{ on: t.hecha }" @click="toggleTarea(t)">{{ t.hecha ? '✓' : '' }}</button>
            <span class="tlist__t">{{ t.titulo }}</span>
            <small v-if="t.vence_el" class="tlist__v">{{ t.vence_el }}</small>
            <button class="lnk lnk--danger" @click="borrarTarea(t)">✕</button>
          </li>
          <li v-if="!e.tareas?.length" class="empty">Sin tareas.</li>
        </ul>
      </section>
    </div>

    <div class="callout">
      <span>🔗</span>
      <p>Cada costo pagado y cada venta atribuida a este evento es un movimiento del libro. El resultado se arma solo, y también aparece en la contabilidad del club (unidad Bar, en la sede del bar).</p>
    </div>
  </div>
  <div v-else class="ed__loading">Cargando evento…</div>
</template>

<style scoped>
.ed { padding: var(--sp-6, 24px); max-width: 900px; margin: 0 auto; }
.ed__loading { padding: var(--sp-8, 32px); text-align: center; color: #64748b; }
.ed__head { display: flex; align-items: flex-start; justify-content: space-between; gap: 12px; flex-wrap: wrap; }
.ed__back { font-size: var(--fs-13, 13px); color: #1b5e20; text-decoration: none; font-weight: 600; }
.ed__head h1 { font-size: var(--fs-24, 24px); font-weight: 700; color: #0f172a; margin: 6px 0 0; }
.ed__head p { color: #64748b; margin: 3px 0 0; font-size: var(--fs-14, 14px); }
.ed__head-actions { display: flex; align-items: center; gap: 12px; }
.ed__head-l { min-width: 0; flex: 1; }
.ed__title-row { display: flex; align-items: center; gap: 10px; flex-wrap: wrap; margin-top: 6px; }
.ed__title-row h1 { margin: 0; }
.ed__estado { font-size: var(--fs-12, 12px); font-weight: 700; padding: 3px 10px; border-radius: 999px; text-transform: uppercase; letter-spacing: .03em; }
.ed__estado--plan      { background: #eff6ff; color: #1d4ed8; }
.ed__estado--curso     { background: #fef3c7; color: #b45309; }
.ed__estado--cerrado   { background: #f0fdf4; color: #15803d; }
.ed__estado--cancelado { background: #f1f5f9; color: #94a3b8; }
.ed__sub { display: flex; align-items: center; gap: 6px; flex-wrap: wrap; color: #64748b; margin: 6px 0 0; font-size: var(--fs-14, 14px); }
.ed__sub b { color: #334155; }
.ed__sep { color: #cbd5e1; }
.ed__ocup { height: 6px; background: #f1f5f9; border-radius: 4px; overflow: hidden; margin-top: 8px; max-width: 340px; }
.ed__ocup i { display: block; height: 100%; background: #1b5e20; border-radius: 4px; transition: width .3s; }
.ed__ocup i.full { background: #b45309; }

.ed__money { margin: var(--sp-5, 20px) 0; }
.ed__money-strip { display: grid; grid-template-columns: repeat(4, 1fr); gap: 10px; }
@media (max-width: 640px) { .ed__money-strip { grid-template-columns: 1fr 1fr; } }
.ed__money-item { background: var(--c-paper, #fff); border: 1px solid #f1f5f9; border-radius: var(--r-md, 10px); padding: 11px 14px; }
.ed__money-item span { font-size: var(--fs-11, 11px); color: #94a3b8; text-transform: uppercase; letter-spacing: .04em; }
.ed__money-item b { display: block; font-size: var(--fs-18, 18px); font-weight: 700; color: #0f172a; margin-top: 3px; font-variant-numeric: tabular-nums; }
.ed__money-item--res { background: #f8fafc; }
.ed__money-item--res b.pos { color: #15803d; }
.ed__money-item--res b.neg { color: #dc2626; }
.ed__money-hint { font-size: var(--fs-13, 13px); color: #64748b; margin: 10px 2px 0; line-height: 1.5; }

.ed__result { display: flex; flex-direction: column; gap: 2px; padding: var(--sp-4, 16px) var(--sp-5, 20px); border-radius: var(--r-lg, 14px); margin: var(--sp-5, 20px) 0; border: 1px solid #f1f5f9; }
.ed__result.is-pos { background: #f0fdf4; }
.ed__result.is-neg { background: #fee2e2; }
.ed__result span { font-size: var(--fs-12, 12px); text-transform: uppercase; letter-spacing: .05em; color: #64748b; }
.ed__result strong { font-size: 2.4rem; font-weight: 720; letter-spacing: -.03em; }
.ed__result.is-pos strong { color: #1b5e20; }
.ed__result.is-neg strong { color: #dc2626; }
.ed__result small { color: #64748b; font-size: var(--fs-13, 13px); }

.ed__kpis { display: grid; grid-template-columns: repeat(4, 1fr); gap: 10px; }
@media (max-width: 640px) { .ed__kpis { grid-template-columns: 1fr 1fr; } }
.kpi { background: var(--c-paper, #fff); border: 1px solid #f1f5f9; border-radius: var(--r-md, 10px); padding: 12px 14px; }
.kpi span { font-size: var(--fs-11, 11px); color: #94a3b8; text-transform: uppercase; letter-spacing: .04em; }
.kpi strong { display: block; font-size: var(--fs-18, 18px); font-weight: 700; color: #0f172a; margin-top: 4px; font-variant-numeric: tabular-nums; }

.be { background: var(--c-paper, #fff); border: 1px solid #f1f5f9; border-radius: var(--r-lg, 14px); padding: var(--sp-4, 16px); margin: var(--sp-4, 16px) 0; }
.be__head { display: flex; justify-content: space-between; align-items: baseline; margin-bottom: 10px; font-size: var(--fs-13, 13px); color: #64748b; }
.be__head b { color: #0f172a; }
.be__track { height: 30px; background: #f8fafc; border: 1px solid #f1f5f9; border-radius: 8px; overflow: hidden; }
.be__track i { display: block; height: 100%; background: #15803d; border-radius: 8px; transition: width .3s; }
.be__track i.over { background: #1b5e20; }
.be__legend { display: flex; justify-content: space-between; margin-top: 8px; font-size: var(--fs-13, 13px); color: #64748b; }
.be__legend b { color: #0f172a; }

.ed__cols { display: grid; grid-template-columns: 1.3fr 1fr; gap: 12px; }
@media (max-width: 720px) { .ed__cols { grid-template-columns: 1fr; } }
.card { background: var(--c-paper, #fff); border: 1px solid #f1f5f9; border-radius: var(--r-lg, 14px); padding: var(--sp-4, 16px); }
.card__head { display: flex; align-items: center; justify-content: space-between; margin-bottom: var(--sp-3, 12px); }
.card__head h2 { font-size: var(--fs-16, 16px); font-weight: 650; color: #0f172a; margin: 0; }
.mut { font-size: var(--fs-12, 12px); color: #94a3b8; }
.empty { color: #94a3b8; font-size: var(--fs-13, 13px); text-align: center; padding: 8px 0; }

.cform, .tform { display: flex; gap: 6px; flex-wrap: wrap; align-items: center; background: #f8fafc; border: 1px solid #f1f5f9; border-radius: var(--r-sm, 8px); padding: 10px; margin-bottom: 10px; }
.cform__actions { display: flex; gap: 6px; margin-left: auto; }
.chk { display: flex; align-items: center; gap: 5px; font-size: var(--fs-13, 13px); color: #475569; }
.tform { flex-wrap: nowrap; }
.tform .inp { flex: 1; }

.clist, .tlist { list-style: none; margin: 0; padding: 0; }
.clist li { display: flex; align-items: center; gap: 10px; padding: 9px 0; border-bottom: 1px solid #f1f5f9; font-size: var(--fs-14, 14px); }
.clist li:last-child, .tlist li:last-child { border-bottom: none; }
.clist__main { flex: 1; display: flex; flex-direction: column; }
.clist__c { color: #1e293b; font-weight: 550; }
.clist__main small { color: #94a3b8; font-size: var(--fs-12, 12px); }
.clist__m { font-variant-numeric: tabular-nums; font-weight: 600; color: #0f172a; }
.st-pill { font-size: .66rem; font-weight: 640; padding: 3px 9px; border-radius: 999px; border: none; cursor: pointer; }
.st-pill.pag { background: #f0fdf4; color: #1b5e20; }
.st-pill.pend { background: #fee2e2; color: #dc2626; }

.tlist li { display: flex; align-items: center; gap: 10px; padding: 8px 0; border-bottom: 1px solid #f1f5f9; font-size: var(--fs-14, 14px); }
.tlist li.done .tlist__t { text-decoration: line-through; color: #94a3b8; }
.box { width: 20px; height: 20px; border-radius: 6px; border: 1.5px solid #e2e8f0; background: var(--c-paper, #fff); cursor: pointer; font-size: .7rem; color: #fff; flex-shrink: 0; }
.box.on { background: #1b5e20; border-color: #1b5e20; }
.tlist__t { flex: 1; color: #1e293b; }
.tlist__v { color: #94a3b8; font-size: var(--fs-12, 12px); }

.ed__entradas { margin: var(--sp-4, 16px) 0; }
.tt { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: 8px; }
.ttrow { display: grid; grid-template-columns: 1fr auto auto auto; gap: 12px; align-items: center; padding: 10px 12px; background: #f8fafc; border: 1px solid #f1f5f9; border-radius: var(--r-sm, 8px); }
.ttrow.sold { opacity: .7; }
.ttrow__top { display: flex; justify-content: space-between; gap: 10px; }
.ttrow__n { font-weight: 600; color: #0f172a; font-size: var(--fs-14, 14px); }
.ttrow__p { font-family: inherit; font-size: var(--fs-13, 13px); color: #1b5e20; font-weight: 600; }
.ttbar { height: 6px; background: var(--c-paper, #fff); border-radius: 4px; overflow: hidden; margin-top: 6px; }
.ttbar i { display: block; height: 100%; background: #15803d; border-radius: 4px; }
.ttrow.sold .ttbar i { background: #1b5e20; }
.ttrow__q { font-size: var(--fs-13, 13px); color: #475569; font-variant-numeric: tabular-nums; white-space: nowrap; }

.ov { position: fixed; inset: 0; background: rgba(20,20,20,.45); display: grid; place-items: center; z-index: 1000; padding: 16px; }
.modal { background: var(--c-paper, #fff); border-radius: var(--r-lg, 14px); padding: var(--sp-5, 20px); width: 100%; max-width: 360px; box-shadow: var(--sh-3, 0 20px 50px rgba(0,0,0,.25)); }
.modal h3 { margin: 0 0 4px; font-size: var(--fs-18, 18px); color: #0f172a; }
.modal__hint { color: #64748b; font-size: var(--fs-13, 13px); margin: 0 0 var(--sp-3, 12px); }
.fld2 { display: flex; flex-direction: column; gap: 4px; font-size: var(--fs-13, 13px); color: #475569; margin-bottom: var(--sp-3, 12px); }
.modal__total { display: flex; justify-content: space-between; align-items: baseline; padding: 10px 0; border-top: 1px solid #f1f5f9; margin-bottom: var(--sp-3, 12px); }
.modal__total strong { font-size: var(--fs-20, 20px); color: #0f172a; }

.callout { display: flex; gap: 12px; align-items: flex-start; background: #f0fdf4; border: 1px solid #f1f5f9; border-radius: var(--r-md, 10px); padding: 14px 16px; margin-top: var(--sp-4, 16px); }
.callout p { font-size: var(--fs-13, 13px); color: #475569; margin: 0; }

.inp { padding: 7px 10px; border: 1px solid #e2e8f0; border-radius: var(--r-sm, 8px); font-size: var(--fs-14, 14px); background: var(--c-paper, #fff); color: #0f172a; }
.inp--sm { width: 100px; }
.btn { border: 1px solid #e2e8f0; background: var(--c-paper, #fff); color: #1e293b; border-radius: var(--r-sm, 8px); padding: 8px 14px; font-size: var(--fs-13, 13px); font-weight: 600; cursor: pointer; }
.btn--sm { padding: 6px 11px; font-size: var(--fs-12, 12px); }
.btn--primary { background: #1b5e20; border-color: #1b5e20; color: #fff; }
.btn:disabled { opacity: .5; cursor: default; }
.lnk { background: none; border: none; color: #94a3b8; font-size: var(--fs-13, 13px); cursor: pointer; padding: 2px 5px; text-decoration: none; }
.lnk--btn { border: 1px solid #e2e8f0; border-radius: var(--r-sm, 8px); padding: 6px 11px; color: #334155; font-weight: 600; }
.lnk--btn:hover { border-color: #1b5e20; color: #1b5e20; }
.lnk--danger:hover { color: #dc2626; }
</style>
