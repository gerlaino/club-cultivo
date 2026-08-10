<script setup>
// Lista de eventos de un bar (Capa 2). Próximos y pasados, con su resultado.
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useEventosBarStore } from '../../stores/eventosBar.js'
import { useToast } from '../../composables/useToast.js'
import AppDatePicker from '../../components/ui/AppDatePicker.vue'
import BarNav from './BarNav.vue'

const store  = useEventosBarStore()
const route  = useRoute()
const router = useRouter()
const toast  = useToast()
const barId  = route.params.barId

const ESTADOS = {
  planificado: { label: 'Planificado', cls: 'plan' },
  en_venta:    { label: 'En venta',    cls: 'live' },
  en_curso:    { label: 'En curso',    cls: 'live' },
  finalizado:  { label: 'Cerrado',     cls: 'done' },
  cancelado:   { label: 'Cancelado',   cls: 'off' },
}
const form = ref(null)

const fmt = (n) => `$${Math.round(n || 0).toLocaleString('es-AR')}`
const esBarInexistente = (msg) => /no encontrado|not found/i.test(msg || '')
function irAlListado() { toast.error('Ese salón ya no existe. Elegí uno de la lista.'); router.push('/bar') }

onMounted(async () => {
  await store.fetchLista(barId)
  if (esBarInexistente(store.error)) irAlListado()
})

function nuevo() { form.value = { nombre: '', fecha: '', horario: '', aforo: null, presupuesto_ingresos: 0 } }
async function guardar() {
  if (!form.value.nombre?.trim()) { toast.warning('Poné un nombre'); return }
  try {
    const ev = await store.crear(barId, { ...form.value, nombre: form.value.nombre.trim() })
    form.value = null
    router.push(`/bar/${barId}/eventos/${ev.id}`)
  } catch {
    if (esBarInexistente(store.saveError)) irAlListado()
    else toast.error(store.saveError)
  }
}
function abrir(ev) { router.push(`/bar/${barId}/eventos/${ev.id}`) }
function fechaTxt(f) {
  if (!f) return { d: '—', m: '' }
  const dt = new Date(f + 'T00:00:00')
  return { d: dt.getDate(), m: dt.toLocaleDateString('es-AR', { month: 'short' }) }
}
</script>

<template>
  <div class="ev">
    <BarNav :bar-id="barId" active="eventos" />
    <header class="ev__head">
      <div>
        <h1>Eventos</h1>
        <p>Cada evento, un proyecto con su resultado.</p>
      </div>
      <div class="ev__nav">
        <button class="btn btn--primary" @click="nuevo">+ Nuevo evento</button>
      </div>
    </header>

    <!-- Alta mínima por modal: lo esencial para crear el evento; el resto se completa adentro. -->
    <div v-if="form" class="ev__ov" @click.self="form = null">
      <form class="ev__modal" @submit.prevent="guardar">
        <h3 class="ev__modal-title">Nuevo evento</h3>
        <p class="ev__modal-hint">Con esto alcanza para arrancar. Entradas, costos y provisión se cargan dentro del evento.</p>
        <label class="fld ev__fld">Nombre
          <input v-model.trim="form.nombre" class="inp" placeholder="Ej: Fiesta de apertura" maxlength="80" autofocus />
        </label>
        <div class="ev__grid2">
          <label class="fld">Fecha<AppDatePicker v-model="form.fecha" /></label>
          <label class="fld">Horario (opcional)<input v-model.trim="form.horario" class="inp" placeholder="Ej: 22:00 a 05:00" maxlength="40" /></label>
        </div>
        <div class="ev__grid2">
          <label class="fld">Aforo (opcional)<input v-model.number="form.aforo" type="number" min="0" class="inp" placeholder="—" /></label>
          <label class="fld">Ingresos estimados (opcional)<input v-model.number="form.presupuesto_ingresos" type="number" min="0" step="any" class="inp" placeholder="$0" /></label>
        </div>
        <div class="ev__modal-actions">
          <button type="button" class="btn" @click="form = null">Cancelar</button>
          <button type="submit" class="btn btn--primary" :disabled="store.saving">Crear evento</button>
        </div>
      </form>
    </div>

    <div v-if="store.loading" class="ev__loading">Cargando…</div>
    <div v-else-if="!store.eventos.length" class="ev__empty">Todavía no hay eventos. Creá el primero.</div>

    <div v-else class="ev__list">
      <div v-for="e in store.eventos" :key="e.id" class="evrow" @click="abrir(e)">
        <div class="evdate"><div class="d">{{ fechaTxt(e.fecha).d }}</div><div class="m">{{ fechaTxt(e.fecha).m }}</div></div>
        <div class="evrow__main">
          <div class="evrow__name">{{ e.nombre }} <span class="chip" :class="ESTADOS[e.estado]?.cls">{{ ESTADOS[e.estado]?.label }}</span></div>
          <div class="evrow__meta">
            <span v-if="e.horario">🕒 {{ e.horario }}</span>
            <span v-if="e.aforo">aforo {{ e.aforo }}</span>
            <span>comprometido {{ fmt(e.costos_comprometidos) }}</span>
          </div>
        </div>
        <div class="evrow__res">
          <b :class="(e.estado === 'finalizado' ? e.resultado.resultado : e.resultado_proyectado) >= 0 ? 'pos' : 'neg'">
            {{ fmt(e.estado === 'finalizado' ? e.resultado.resultado : e.resultado_proyectado) }}
          </b>
          <small>{{ e.estado === 'finalizado' ? 'real' : 'proyectado' }}</small>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.ev { padding: var(--sp-6, 24px); max-width: 880px; margin: 0 auto; }
.ev__head { display: flex; align-items: flex-start; justify-content: space-between; gap: 12px; flex-wrap: wrap; }
.ev__head h1 { font-size: var(--fs-24, 24px); font-weight: 700; color: var(--c-slate-900); margin: 0; }
.ev__head p { color: var(--c-slate-500); margin: 4px 0 0; font-size: var(--fs-14, 14px); }
.ev__nav { display: flex; gap: 10px; }
.fld { display: flex; flex-direction: column; gap: 3px; font-size: var(--fs-12, 12px); color: var(--c-slate-500); }

/* Modal de alta mínima */
.ev__ov { position: fixed; inset: 0; background: rgb(15 23 42 / .5); backdrop-filter: blur(2px); display: grid; place-items: center; z-index: 1000; padding: 16px; }
.ev__modal { background: var(--c-paper, #fff); border-radius: var(--r-lg, 14px); padding: var(--sp-5, 20px); width: 100%; max-width: 420px; box-shadow: 0 20px 50px rgb(15 23 42 / .25); }
.ev__modal-title { margin: 0 0 4px; font-size: var(--fs-18, 18px); font-weight: 700; color: var(--c-slate-900); }
.ev__modal-hint { margin: 0 0 var(--sp-4, 16px); font-size: var(--fs-13, 13px); color: var(--c-slate-500); line-height: 1.45; }
.ev__fld { margin-bottom: var(--sp-3, 12px); }
.ev__grid2 { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; margin-bottom: var(--sp-3, 12px); }
.ev__modal .inp { width: 100%; }
.ev__modal-actions { display: flex; gap: 8px; justify-content: flex-end; margin-top: var(--sp-4, 16px); }
.ev__loading, .ev__empty { color: var(--c-slate-500); padding: var(--sp-8, 32px); text-align: center; }

.ev__list { display: flex; flex-direction: column; gap: 10px; margin-top: var(--sp-5, 20px); }
.evrow { display: grid; grid-template-columns: 52px 1fr auto; gap: 14px; align-items: center; background: var(--c-paper, #fff); border: 1px solid var(--c-slate-100); border-radius: var(--r-lg, 14px); padding: 14px 16px; cursor: pointer; }
.evrow:hover { border-color: #1b5e20; }
.evdate { text-align: center; background: var(--c-slate-50); border: 1px solid var(--c-slate-100); border-radius: 9px; padding: 5px 0; }
.evdate .d { font-size: 1.15rem; font-weight: 700; line-height: 1; color: var(--c-slate-900); }
.evdate .m { font-size: .62rem; text-transform: uppercase; letter-spacing: .06em; color: var(--c-slate-400); }
.evrow__name { font-weight: 640; color: var(--c-slate-900); }
.evrow__meta { display: flex; gap: 12px; font-size: .78rem; color: var(--c-slate-400); margin-top: 3px; }
.evrow__res { text-align: right; }
.evrow__res b { font-size: 1.05rem; font-weight: 700; }
.evrow__res b.pos { color: #1b5e20; } .evrow__res b.neg { color: #dc2626; }
.evrow__res small { display: block; font-size: .66rem; color: var(--c-slate-400); }
.chip { font-size: .64rem; font-weight: 640; text-transform: uppercase; letter-spacing: .05em; padding: 2px 8px; border-radius: 999px; }
.chip.plan { background: #fef3c7; color: #b45309; }
.chip.live { background: #f0fdf4; color: #1b5e20; }
.chip.done { background: var(--c-slate-100); color: var(--c-slate-500); }
.chip.off  { background: #fee2e2; color: #dc2626; }

.inp { padding: 8px 10px; border: 1px solid var(--c-slate-200); border-radius: var(--r-sm, 8px); font-size: var(--fs-14, 14px); background: var(--c-paper, #fff); color: var(--c-slate-900); }
.inp--sm { width: 84px; }
.btn { border: 1px solid var(--c-slate-200); background: var(--c-paper, #fff); color: #1e293b; border-radius: var(--r-sm, 8px); padding: 8px 14px; font-size: var(--fs-13, 13px); font-weight: 600; cursor: pointer; text-decoration: none; }
.btn--primary { background: #1b5e20; border-color: #1b5e20; color: #fff; }
.btn:disabled { opacity: .5; cursor: default; }
</style>
