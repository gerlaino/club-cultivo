<script setup>
// Ficha de un evento (Capa 2): el centro de mando. P&L, break-even, presupuesto vs real,
// costos/proveedores y tareas. Todo editable/borrable (y recuperable desde la papelera).
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useEventosBarStore } from '../../stores/eventosBar.js'
import { useToast } from '../../composables/useToast.js'
import { useConfirm } from '../../composables/useConfirm.js'

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

async function cambiarEstado(v) {
  try { await store.actualizar(barId, evId, { estado: v }); toast.success('Estado actualizado') }
  catch { toast.error(store.saveError) }
}
async function borrarEvento() {
  if (!(await confirm({ title: 'Eliminar evento', message: '¿Eliminar el evento? Se recupera desde la papelera.', variant: 'danger' }))) return
  try { await store.eliminar(barId, evId); toast.success('Evento eliminado'); router.push(`/bar/${barId}/eventos`) }
  catch { toast.error('No se pudo eliminar') }
}

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
      <div>
        <RouterLink :to="`/bar/${barId}/eventos`" class="ed__back">← Eventos</RouterLink>
        <h1>{{ e.nombre }}</h1>
        <p>{{ e.fecha || 'sin fecha' }}<span v-if="e.aforo"> · aforo {{ e.aforo }}</span></p>
      </div>
      <div class="ed__head-actions">
        <select :value="e.estado" class="inp" @change="cambiarEstado($event.target.value)">
          <option v-for="s in ESTADOS" :key="s.v" :value="s.v">{{ s.l }}</option>
        </select>
        <button class="lnk lnk--danger" @click="borrarEvento">Eliminar</button>
      </div>
    </header>

    <!-- Resultado grande -->
    <div class="ed__result" :class="(e.estado === 'finalizado' ? e.resultado.resultado : e.resultado_proyectado) >= 0 ? 'is-pos' : 'is-neg'">
      <span>{{ e.estado === 'finalizado' ? 'Resultado real' : 'Resultado proyectado' }}</span>
      <strong>{{ fmt(e.estado === 'finalizado' ? e.resultado.resultado : e.resultado_proyectado) }}</strong>
      <small>ingresos {{ fmt(e.resultado.ingresos) }} · egresos {{ fmt(e.resultado.egresos) }}</small>
    </div>

    <div class="ed__kpis">
      <div class="kpi"><span>Ingresos estimados</span><strong>{{ fmt(e.presupuesto_ingresos) }}</strong></div>
      <div class="kpi"><span>Comprometido</span><strong>{{ fmt(e.costos_comprometidos) }}</strong></div>
      <div class="kpi"><span>Pagado</span><strong>{{ fmt(e.costos_pagados) }}</strong></div>
      <div class="kpi"><span>Ingreso real</span><strong>{{ fmt(e.resultado.ingresos) }}</strong></div>
    </div>

    <!-- Break-even -->
    <div class="be">
      <div class="be__head"><b>Punto de equilibrio</b><span>necesitás <b>{{ fmt(beMeta) }}</b> de ingresos para cubrir costos</span></div>
      <div class="be__track"><i :class="{ over: beActual >= beMeta && beMeta > 0 }" :style="{ width: bePct + '%' }"></i></div>
      <div class="be__legend"><span>Ingreso <b>{{ fmt(beActual) }}</b></span><span>{{ bePct }}%</span></div>
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
.ed__loading { padding: var(--sp-8, 32px); text-align: center; color: var(--c-ink-500); }
.ed__head { display: flex; align-items: flex-start; justify-content: space-between; gap: 12px; flex-wrap: wrap; }
.ed__back { font-size: var(--fs-13, 13px); color: var(--c-leaf-700, #2f6b3d); text-decoration: none; font-weight: 600; }
.ed__head h1 { font-size: var(--fs-24, 24px); font-weight: 700; color: var(--c-ink-900); margin: 6px 0 0; }
.ed__head p { color: var(--c-ink-500); margin: 3px 0 0; font-size: var(--fs-14, 14px); }
.ed__head-actions { display: flex; align-items: center; gap: 12px; }

.ed__result { display: flex; flex-direction: column; gap: 2px; padding: var(--sp-4, 16px) var(--sp-5, 20px); border-radius: var(--r-lg, 14px); margin: var(--sp-5, 20px) 0; border: 1px solid var(--c-ink-100); }
.ed__result.is-pos { background: var(--c-leaf-50, #e7f0e5); }
.ed__result.is-neg { background: var(--c-rust-100, #f6e5e2); }
.ed__result span { font-size: var(--fs-12, 12px); text-transform: uppercase; letter-spacing: .05em; color: var(--c-ink-500); }
.ed__result strong { font-size: 2.4rem; font-weight: 720; letter-spacing: -.03em; }
.ed__result.is-pos strong { color: var(--c-leaf-700, #2f6b3d); }
.ed__result.is-neg strong { color: var(--c-rust-600, #b23b2e); }
.ed__result small { color: var(--c-ink-500); font-size: var(--fs-13, 13px); }

.ed__kpis { display: grid; grid-template-columns: repeat(4, 1fr); gap: 10px; }
@media (max-width: 640px) { .ed__kpis { grid-template-columns: 1fr 1fr; } }
.kpi { background: var(--c-paper, #fff); border: 1px solid var(--c-ink-100); border-radius: var(--r-md, 10px); padding: 12px 14px; }
.kpi span { font-size: var(--fs-11, 11px); color: var(--c-ink-400); text-transform: uppercase; letter-spacing: .04em; }
.kpi strong { display: block; font-size: var(--fs-18, 18px); font-weight: 700; color: var(--c-ink-900); margin-top: 4px; font-variant-numeric: tabular-nums; }

.be { background: var(--c-paper, #fff); border: 1px solid var(--c-ink-100); border-radius: var(--r-lg, 14px); padding: var(--sp-4, 16px); margin: var(--sp-4, 16px) 0; }
.be__head { display: flex; justify-content: space-between; align-items: baseline; margin-bottom: 10px; font-size: var(--fs-13, 13px); color: var(--c-ink-500); }
.be__head b { color: var(--c-ink-900); }
.be__track { height: 30px; background: var(--c-ink-50, #f6f7f5); border: 1px solid var(--c-ink-100); border-radius: 8px; overflow: hidden; }
.be__track i { display: block; height: 100%; background: var(--c-leaf-500, #40915a); border-radius: 8px; transition: width .3s; }
.be__track i.over { background: var(--c-leaf-700, #2f6b3d); }
.be__legend { display: flex; justify-content: space-between; margin-top: 8px; font-size: var(--fs-13, 13px); color: var(--c-ink-500); }
.be__legend b { color: var(--c-ink-900); }

.ed__cols { display: grid; grid-template-columns: 1.3fr 1fr; gap: 12px; }
@media (max-width: 720px) { .ed__cols { grid-template-columns: 1fr; } }
.card { background: var(--c-paper, #fff); border: 1px solid var(--c-ink-100); border-radius: var(--r-lg, 14px); padding: var(--sp-4, 16px); }
.card__head { display: flex; align-items: center; justify-content: space-between; margin-bottom: var(--sp-3, 12px); }
.card__head h2 { font-size: var(--fs-16, 16px); font-weight: 650; color: var(--c-ink-900); margin: 0; }
.mut { font-size: var(--fs-12, 12px); color: var(--c-ink-400); }
.empty { color: var(--c-ink-400); font-size: var(--fs-13, 13px); text-align: center; padding: 8px 0; }

.cform, .tform { display: flex; gap: 6px; flex-wrap: wrap; align-items: center; background: var(--c-ink-50, #f6f7f5); border: 1px solid var(--c-ink-100); border-radius: var(--r-sm, 8px); padding: 10px; margin-bottom: 10px; }
.cform__actions { display: flex; gap: 6px; margin-left: auto; }
.chk { display: flex; align-items: center; gap: 5px; font-size: var(--fs-13, 13px); color: var(--c-ink-600); }
.tform { flex-wrap: nowrap; }
.tform .inp { flex: 1; }

.clist, .tlist { list-style: none; margin: 0; padding: 0; }
.clist li { display: flex; align-items: center; gap: 10px; padding: 9px 0; border-bottom: 1px solid var(--c-ink-100); font-size: var(--fs-14, 14px); }
.clist li:last-child, .tlist li:last-child { border-bottom: none; }
.clist__main { flex: 1; display: flex; flex-direction: column; }
.clist__c { color: var(--c-ink-800); font-weight: 550; }
.clist__main small { color: var(--c-ink-400); font-size: var(--fs-12, 12px); }
.clist__m { font-variant-numeric: tabular-nums; font-weight: 600; color: var(--c-ink-900); }
.st-pill { font-size: .66rem; font-weight: 640; padding: 3px 9px; border-radius: 999px; border: none; cursor: pointer; }
.st-pill.pag { background: var(--c-leaf-50, #e7f0e5); color: var(--c-leaf-700, #2f6b3d); }
.st-pill.pend { background: var(--c-rust-100, #f6e5e2); color: var(--c-rust-600, #b23b2e); }

.tlist li { display: flex; align-items: center; gap: 10px; padding: 8px 0; border-bottom: 1px solid var(--c-ink-100); font-size: var(--fs-14, 14px); }
.tlist li.done .tlist__t { text-decoration: line-through; color: var(--c-ink-400); }
.box { width: 20px; height: 20px; border-radius: 6px; border: 1.5px solid var(--c-ink-200); background: var(--c-paper, #fff); cursor: pointer; font-size: .7rem; color: #fff; flex-shrink: 0; }
.box.on { background: var(--c-leaf-700, #2f6b3d); border-color: var(--c-leaf-700, #2f6b3d); }
.tlist__t { flex: 1; color: var(--c-ink-800); }
.tlist__v { color: var(--c-ink-400); font-size: var(--fs-12, 12px); }

.callout { display: flex; gap: 12px; align-items: flex-start; background: var(--c-leaf-50, #e7f0e5); border: 1px solid var(--c-ink-100); border-radius: var(--r-md, 10px); padding: 14px 16px; margin-top: var(--sp-4, 16px); }
.callout p { font-size: var(--fs-13, 13px); color: var(--c-ink-600); margin: 0; }

.inp { padding: 7px 10px; border: 1px solid var(--c-ink-200); border-radius: var(--r-sm, 8px); font-size: var(--fs-14, 14px); background: var(--c-paper, #fff); color: var(--c-ink-900); }
.inp--sm { width: 100px; }
.btn { border: 1px solid var(--c-ink-200); background: var(--c-paper, #fff); color: var(--c-ink-800); border-radius: var(--r-sm, 8px); padding: 8px 14px; font-size: var(--fs-13, 13px); font-weight: 600; cursor: pointer; }
.btn--sm { padding: 6px 11px; font-size: var(--fs-12, 12px); }
.btn--primary { background: var(--c-leaf-700, #2f6b3d); border-color: var(--c-leaf-700, #2f6b3d); color: #fff; }
.btn:disabled { opacity: .5; cursor: default; }
.lnk { background: none; border: none; color: var(--c-ink-400); font-size: var(--fs-13, 13px); cursor: pointer; padding: 2px 5px; }
.lnk--danger:hover { color: var(--c-rust-600, #b23b2e); }
</style>
