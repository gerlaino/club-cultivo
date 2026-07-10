<script setup>
// Lista de eventos de un bar (Capa 2). Próximos y pasados, con su resultado.
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useEventosBarStore } from '../../stores/eventosBar.js'
import { useToast } from '../../composables/useToast.js'
import AppDatePicker from '../../components/ui/AppDatePicker.vue'

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

function nuevo() { form.value = { nombre: '', fecha: '', aforo: null, presupuesto_ingresos: 0 } }
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
    <header class="ev__head">
      <div>
        <h1>Eventos</h1>
        <p>{{ store.actual?.bar?.nombre }} Cada evento, un proyecto con su resultado.</p>
      </div>
      <div class="ev__nav">
        <RouterLink :to="`/bar/${barId}/panel`" class="btn">← Panel</RouterLink>
        <button class="btn btn--primary" @click="nuevo">+ Nuevo evento</button>
      </div>
    </header>

    <form v-if="form" class="ev__form" @submit.prevent="guardar">
      <input v-model.trim="form.nombre" class="inp" placeholder="Nombre del evento" maxlength="80" />
      <label class="fld">Fecha<AppDatePicker v-model="form.fecha" /></label>
      <label class="fld">Aforo<input v-model.number="form.aforo" type="number" min="0" class="inp inp--sm" /></label>
      <label class="fld">Ingresos estimados<input v-model.number="form.presupuesto_ingresos" type="number" min="0" step="any" class="inp" /></label>
      <div class="ev__form-actions">
        <button type="button" class="btn" @click="form = null">Cancelar</button>
        <button type="submit" class="btn btn--primary" :disabled="store.saving">Crear</button>
      </div>
    </form>

    <div v-if="store.loading" class="ev__loading">Cargando…</div>
    <div v-else-if="!store.eventos.length" class="ev__empty">Todavía no hay eventos. Creá el primero.</div>

    <div v-else class="ev__list">
      <div v-for="e in store.eventos" :key="e.id" class="evrow" @click="abrir(e)">
        <div class="evdate"><div class="d">{{ fechaTxt(e.fecha).d }}</div><div class="m">{{ fechaTxt(e.fecha).m }}</div></div>
        <div class="evrow__main">
          <div class="evrow__name">{{ e.nombre }} <span class="chip" :class="ESTADOS[e.estado]?.cls">{{ ESTADOS[e.estado]?.label }}</span></div>
          <div class="evrow__meta">
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
.ev__head h1 { font-size: var(--fs-24, 24px); font-weight: 700; color: #0f172a; margin: 0; }
.ev__head p { color: #64748b; margin: 4px 0 0; font-size: var(--fs-14, 14px); }
.ev__nav { display: flex; gap: 10px; }
.ev__form { display: flex; gap: 10px; flex-wrap: wrap; align-items: flex-end; background: #f8fafc; border: 1px solid #f1f5f9; border-radius: var(--r-md, 10px); padding: var(--sp-3, 12px); margin-top: var(--sp-4, 16px); }
.fld { display: flex; flex-direction: column; gap: 3px; font-size: var(--fs-12, 12px); color: #64748b; }
.ev__form-actions { display: flex; gap: 8px; margin-left: auto; }
.ev__loading, .ev__empty { color: #64748b; padding: var(--sp-8, 32px); text-align: center; }

.ev__list { display: flex; flex-direction: column; gap: 10px; margin-top: var(--sp-5, 20px); }
.evrow { display: grid; grid-template-columns: 52px 1fr auto; gap: 14px; align-items: center; background: var(--c-paper, #fff); border: 1px solid #f1f5f9; border-radius: var(--r-lg, 14px); padding: 14px 16px; cursor: pointer; }
.evrow:hover { border-color: #1b5e20; }
.evdate { text-align: center; background: #f8fafc; border: 1px solid #f1f5f9; border-radius: 9px; padding: 5px 0; }
.evdate .d { font-size: 1.15rem; font-weight: 700; line-height: 1; color: #0f172a; }
.evdate .m { font-size: .62rem; text-transform: uppercase; letter-spacing: .06em; color: #94a3b8; }
.evrow__name { font-weight: 640; color: #0f172a; }
.evrow__meta { display: flex; gap: 12px; font-size: .78rem; color: #94a3b8; margin-top: 3px; }
.evrow__res { text-align: right; }
.evrow__res b { font-size: 1.05rem; font-weight: 700; }
.evrow__res b.pos { color: #1b5e20; } .evrow__res b.neg { color: #dc2626; }
.evrow__res small { display: block; font-size: .66rem; color: #94a3b8; }
.chip { font-size: .64rem; font-weight: 640; text-transform: uppercase; letter-spacing: .05em; padding: 2px 8px; border-radius: 999px; }
.chip.plan { background: #fef3c7; color: #b45309; }
.chip.live { background: #f0fdf4; color: #1b5e20; }
.chip.done { background: #f1f5f9; color: #64748b; }
.chip.off  { background: #fee2e2; color: #dc2626; }

.inp { padding: 8px 10px; border: 1px solid #e2e8f0; border-radius: var(--r-sm, 8px); font-size: var(--fs-14, 14px); background: var(--c-paper, #fff); color: #0f172a; }
.inp--sm { width: 84px; }
.btn { border: 1px solid #e2e8f0; background: var(--c-paper, #fff); color: #1e293b; border-radius: var(--r-sm, 8px); padding: 8px 14px; font-size: var(--fs-13, 13px); font-weight: 600; cursor: pointer; text-decoration: none; }
.btn--primary { background: #1b5e20; border-color: #1b5e20; color: #fff; }
.btn:disabled { opacity: .5; cursor: default; }
</style>
