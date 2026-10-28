<template>
  <div class="srs" data-testid="ficha-resumen">
    <section class="srs__card srs__card--ancha">
      <header class="srs__hd">
        <h2 class="srs__t">Últimas dispensas</h2>
        <button type="button" class="srs__link" @click="$emit('ir', 'dispensaciones')">Ver todas</button>
      </header>
      <div v-if="cargando" class="srs__cargando"><DsSpinner :size="20" /></div>
      <p v-else-if="!ultimas.length" class="srs__vacio">Todavía no retiró nada.</p>
      <ul v-else class="srs__lista">
        <li v-for="d in ultimas" :key="d.id" class="srs__fila" :class="{ 'srs__fila--anulada': d.anulada }">
          <span><strong>{{ fechaCorta(d.fecha_dispensacion) }}</strong> · {{ queLlevo(d) }}</span>
          <span class="srs__mut">{{ d.anulada ? 'anulada' : plata(d.aporte_socio_ars) }}</span>
        </li>
      </ul>
    </section>

    <section v-if="verCuenta" class="srs__card">
      <h2 class="srs__t">Cuenta</h2>
      <p class="srs__big" :class="saldoClase">{{ plata(Math.abs(saldo)) }}</p>
      <p class="srs__mut srs__sub">{{ saldoTexto }}</p>
      <button type="button" class="srs__link" @click="$emit('ir', 'cuenta_corriente')">Movimientos</button>
    </section>

    <section v-if="verReprocann" class="srs__card">
      <h2 class="srs__t">REPROCANN</h2>
      <p class="srs__dato">{{ reprocann }}</p>
      <p v-if="s.renovacion_portal" class="srs__mut srs__sub">Mandó la renovación por el portal</p>
      <button type="button" class="srs__link" @click="$emit('ir', 'reprocann')">{{ s.renovacion_portal ? 'Revisar la renovación' : 'Ver' }}</button>
    </section>

    <section v-if="verTurnos" class="srs__card">
      <h2 class="srs__t">Próximo turno</h2>
      <template v-if="proximoTurno">
        <p class="srs__dato">{{ fechaTurno(proximoTurno.fecha_hora) }}</p>
        <p class="srs__mut srs__sub">{{ proximoTurno.medico_nombre || 'Sin médico asignado' }}</p>
      </template>
      <p v-else class="srs__vacio">No tiene turnos por delante.</p>
      <button type="button" class="srs__link" @click="$emit('ir', 'turnos')">{{ proximoTurno ? 'Ver turnos' : 'Dar un turno' }}</button>
    </section>

    <section class="srs__card">
      <h2 class="srs__t">Contacto</h2>
      <p class="srs__dato srs__dato--chico">{{ s.telefono || 'Sin teléfono' }}</p>
      <p class="srs__dato srs__dato--chico">{{ s.email || 'Sin mail' }}</p>
      <button type="button" class="srs__link" @click="$emit('ir', 'info')">Datos y contacto</button>
    </section>

    <section v-if="verNotas" class="srs__card srs__card--ancha">
      <header class="srs__hd">
        <h2 class="srs__t">Nota del equipo</h2>
        <button type="button" class="srs__link" @click="$emit('ir', 'notas')">{{ ultimaNota ? 'Ver notas' : 'Agregar una nota' }}</button>
      </header>
      <template v-if="ultimaNota">
        <p class="srs__nota">{{ ultimaNota.contenido }}</p>
        <p class="srs__mut srs__sub">{{ fechaCorta(ultimaNota.created_at) }}</p>
      </template>
      <p v-else class="srs__vacio">Sin notas.</p>
    </section>
  </div>
</template>

<script setup>
// El Resumen de la ficha (Germán, 28-oct-2026: «siento que tiene mil solapas»). Lo que el admin
// necesita ver al abrir a un paciente, sin entrar a ninguna sección: qué retiró, cuánto debe o
// tiene a favor, su REPROCANN, su próximo turno, cómo contactarlo y la última nota. Cada recuadro
// lleva a su sección. Sólo muestra lo que el rol puede ver (las mismas solapas que la ficha).
import { computed, onMounted, ref } from 'vue'
import { listDispensaciones, getPacienteTurnos } from '@/lib/api'
import { usePacientesStore } from '@/stores/pacientes'
import { reprocannSit } from '@/composables/useSituacionPaciente.js'
import DsSpinner from '@/design-system/components/Spinner.vue'
import { fechaLocal } from '@/utils/dates.js'

const props = defineProps({
  s:        { type: Object, required: true },
  // Las solapas que este rol tiene: el Resumen no muestra lo que no podría abrir.
  tabs:     { type: Array, required: true },
  refrescar: { type: Number, default: 0 },
})
defineEmits(['ir'])

const store = usePacientesStore()
const tiene = (k) => props.tabs.includes(k)
const verCuenta    = computed(() => tiene('cuenta_corriente'))
const verReprocann = computed(() => tiene('reprocann'))
const verTurnos    = computed(() => tiene('turnos'))
const verNotas     = computed(() => tiene('notas'))

const ultimas = ref([])
const cargando = ref(true)
const turnos = ref([])

async function cargar() {
  cargando.value = true
  try {
    const { data } = await listDispensaciones(props.s.id, { pagina: 1, limite: 3 })
    ultimas.value = (data.dispensaciones || data || []).slice(0, 3)
  } catch { ultimas.value = [] } finally { cargando.value = false }
  if (verTurnos.value) {
    try { const { data } = await getPacienteTurnos(props.s.id); turnos.value = data || [] } catch { turnos.value = [] }
  }
}
onMounted(cargar)
defineExpose({ recargar: cargar })

const proximoTurno = computed(() => turnos.value
  .filter(t => !['cancelado', 'realizado', 'ausente'].includes(t.estado) && new Date(t.fecha_hora) >= new Date())
  .sort((a, b) => new Date(a.fecha_hora) - new Date(b.fecha_hora))[0] || null)

const ultimaNota = computed(() => [...(store.notas || [])].sort((a, b) => new Date(b.created_at) - new Date(a.created_at))[0] || null)

// El saldo que manda el backend: negativo = debe, positivo = a favor.
const saldo = computed(() => Number(props.s.saldo_cc || 0))
const saldoClase = computed(() => saldo.value < 0 ? 'srs__big--debe' : saldo.value > 0 ? 'srs__big--favor' : '')
const saldoTexto = computed(() => saldo.value < 0 ? 'debe' : saldo.value > 0 ? 'a favor · se descuenta sola en la próxima' : 'al día')

const reprocann = computed(() => {
  const r = reprocannSit(props.s.situacion)
  if (!r) return 'Sin dato'
  const venc = props.s.reprocann_vencimiento ? ` · vence ${fechaCorta(props.s.reprocann_vencimiento)}` : ''
  return `${r.label}${venc}`
})

const FORMAS = { flor_seca: 'Flor seca', hash: 'Hash', aceite: 'Aceite', preroll: 'Preroll', crema: 'Crema', otro: 'Otro' }
function linea(nombre, forma, cantidad, unidad) {
  return `${nombre || FORMAS[forma] || 'Producto'} ${Number(cantidad || 0).toLocaleString('es-AR')} ${unidad || 'g'}`
}
function queLlevo(d) {
  if (d.multi_stock && d.items?.length) {
    return d.items.map(it => linea(it.genetica_nombre || it.stock?.genetica?.nombre, it.stock?.forma_producto, it.cantidad, it.stock?.unidad)).join(' + ')
  }
  return linea(d.genetica_nombre, d.stock?.forma_producto, d.cantidad, d.stock?.unidad)
}

const plata = (n) => n == null ? '—' : new Intl.NumberFormat('es-AR', { style: 'currency', currency: 'ARS', maximumFractionDigits: 0 }).format(n)
function fechaCorta(d) {
  if (!d) return ''
  return fechaLocal(/^\d{4}-\d{2}-\d{2}$/.test(d) ? new Date(`${d}T00:00:00`) : new Date(d), { day: 'numeric', month: 'short' })
}
function fechaTurno(d) {
  const f = new Date(d)
  return `${fechaLocal(f, { weekday: 'short', day: 'numeric', month: 'short' })} · ${f.toLocaleTimeString('es-AR', { hour: '2-digit', minute: '2-digit' })}`
}
</script>

<style scoped>
.srs { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 1rem; }
@media (max-width: 720px) { .srs { grid-template-columns: minmax(0, 1fr); } }
.srs__card { background: var(--c-surface, #fff); border: 1px solid var(--c-slate-200); border-radius: 14px; padding: 1.1rem 1.25rem; display: flex; flex-direction: column; align-items: flex-start; }
.srs__card--ancha { grid-column: 1 / -1; align-items: stretch; }
.srs__hd { display: flex; justify-content: space-between; align-items: baseline; gap: .75rem; margin-bottom: .25rem; }
.srs__t { margin: 0 0 .6rem; font-size: .78rem; font-weight: 700; letter-spacing: .04em; text-transform: uppercase; color: var(--c-slate-600); }
.srs__hd .srs__t { margin: 0; }
.srs__link { margin-top: auto; padding: .5rem 0 0; background: none; border: none; color: var(--c-leaf-800); font: inherit; font-size: .875rem; font-weight: 600; cursor: pointer; min-height: 36px; }
.srs__hd .srs__link { margin-top: 0; padding: 0; }
.srs__link:hover { text-decoration: underline; }
.srs__lista { list-style: none; margin: 0; padding: 0; }
.srs__fila { display: flex; justify-content: space-between; gap: 1rem; padding: .7rem 0; border-top: 1px solid var(--c-slate-100); font-size: .93rem; }
.srs__fila--anulada { opacity: .55; text-decoration: line-through; }
.srs__mut { color: var(--c-slate-600); white-space: nowrap; }
.srs__sub { margin: .2rem 0 0; font-size: .85rem; white-space: normal; }
.srs__big { margin: 0; font-size: 1.75rem; font-weight: 700; color: var(--c-ink-900); line-height: 1.1; }
.srs__big--favor { color: var(--c-leaf-700); }
.srs__big--debe { color: var(--c-rust-600); }
.srs__dato { margin: 0; font-size: 1.02rem; font-weight: 600; color: var(--c-ink-900); }
.srs__dato--chico { font-size: .93rem; font-weight: 500; margin-bottom: .15rem; word-break: break-word; }
.srs__nota { margin: .25rem 0 0; font-size: .95rem; line-height: 1.5; white-space: pre-line; }
.srs__vacio { margin: 0; font-size: .9rem; color: var(--c-slate-500); }
.srs__cargando { padding: .75rem 0; }
</style>
