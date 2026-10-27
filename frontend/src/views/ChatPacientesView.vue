<template>
  <div class="cpv" :class="{ 'cpv--con-chat': seleccion }">
    <section class="cpv__lista" aria-label="Conversaciones">
      <header class="cpv__lista-hd">
        <h1 class="cpv__title">Chat con pacientes</h1>
        <label for="cpv-buscar" class="cpv__sr">Buscar paciente</label>
        <input id="cpv-buscar" v-model="buscar" type="search" class="cpv__buscar" placeholder="Buscar paciente" />
        <div class="cpv__filtros" role="tablist">
          <button type="button" role="tab" class="cpv__filtro" :class="{ 'cpv__filtro--on': filtro === 'sin_responder' }" :aria-selected="filtro === 'sin_responder'" @click="filtro = 'sin_responder'">
            Sin responder<span v-if="chat.sinResponder"> · {{ chat.sinResponder }}</span>
          </button>
          <button type="button" role="tab" class="cpv__filtro" :class="{ 'cpv__filtro--on': filtro === 'todas' }" :aria-selected="filtro === 'todas'" @click="filtro = 'todas'">Todas</button>
        </div>
      </header>

      <p v-if="chat.cargado && !filas.length" class="cpv__vacio">
        {{ filtro === 'sin_responder' ? 'No hay mensajes esperando respuesta.' : 'Todavía ningún paciente escribió por el portal.' }}
      </p>
      <button v-for="c in filas" :key="c.paciente.id" type="button" class="cpv__fila" :class="{ 'cpv__fila--sel': seleccion?.id === c.paciente.id }"
              :data-testid="`conv-${c.paciente.id}`" @click="abrir(c)">
        <span class="cpv__avatar" aria-hidden="true">{{ iniciales(c.paciente) }}</span>
        <span class="cpv__fila-txt">
          <b>{{ c.paciente.nombre }} {{ c.paciente.apellido }}</b>
          <span class="cpv__ultimo">
            <template v-if="chat.escribiendo[c.paciente.id]"><i>está escribiendo…</i></template>
            <template v-else>{{ c.ultimo?.autor === 'organizacion' ? `${c.ultimo.quien || 'Vos'}: ` : '' }}{{ c.ultimo?.texto }}</template>
          </span>
        </span>
        <span class="cpv__fila-lado">
          <span class="cpv__hora" :class="{ 'cpv__hora--nuevo': c.sin_leer }">{{ cuando(c.ultimo?.at) }}</span>
          <span v-if="c.sin_leer" class="cpv__nuevos">{{ c.sin_leer }}</span>
          <span v-else-if="c.resuelta" class="cpv__resuelta">Resuelta</span>
        </span>
      </button>
    </section>

    <section class="cpv__chat">
      <ChatConPaciente v-if="seleccion" :key="seleccion.id" :paciente-id="seleccion.id" :nombre="seleccion.nombre"
                       :con-volver="true" @volver="seleccion = null" @cargado="ficha = $event">
        <template #acciones>
          <RouterLink :to="`/pacientes/${seleccion.id}`" class="cpv__ficha-link">Ver la ficha</RouterLink>
        </template>
      </ChatConPaciente>
      <div v-else class="cpv__nada">Elegí una conversación de la lista.</div>
    </section>

    <aside v-if="seleccion && ficha" class="cpv__lado" aria-label="El paciente">
      <b class="cpv__lado-nombre">{{ ficha.nombre }} {{ ficha.apellido }}</b>
      <span v-if="ficha.reprocann_vencimiento" class="cpv__pill" :class="{ 'cpv__pill--warn': venceProntito }">REPROCANN vence {{ fecha(ficha.reprocann_vencimiento) }}</span>
      <span v-if="ficha.saldo_cc != null" class="cpv__dato"><b>{{ pesos(ficha.saldo_cc) }}</b> {{ ficha.saldo_cc >= 0 ? 'a favor' : 'de deuda' }}</span>
      <span v-if="ficha.ultima_dispensa" class="cpv__dato">Última dispensa: {{ fecha(ficha.ultima_dispensa.fecha) }} · {{ ficha.ultima_dispensa.resumen }}</span>
      <RouterLink v-if="ficha.renovacion_pendiente" :to="`/pacientes/${seleccion.id}?tab=reprocann`" class="cpv__renov">
        Subió la renovación del REPROCANN · <b>revisarla</b>
      </RouterLink>
      <RouterLink :to="`/pacientes/${seleccion.id}`" class="cpv__boton">Abrir la ficha</RouterLink>
    </aside>
  </div>
</template>

<script setup>
// La bandeja del chat con los pacientes (27-oct-2026): a la izquierda las conversaciones —primero
// las que esperan respuesta—, al medio el chat, y al costado lo clave del paciente para contestar
// sin salir. En el teléfono se ve la lista y, al tocar una, el chat entero (con «‹» para volver).
import { computed, onMounted, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import ChatConPaciente from '../components/chat/ChatConPaciente.vue'
import { useChatPacientesStore } from '../stores/chatPacientes'

const route = useRoute()
const router = useRouter()
const chat = useChatPacientesStore()

const filtro = ref('sin_responder')
const buscar = ref('')
const seleccion = ref(null)   // { id, nombre }
const ficha = ref(null)

const filas = computed(() => {
  const q = buscar.value.trim().toLowerCase()
  return chat.bandeja
    .filter((c) => filtro.value === 'todas' || c.sin_responder || c.paciente.id === seleccion.value?.id)
    .filter((c) => !q || `${c.paciente.nombre} ${c.paciente.apellido}`.toLowerCase().includes(q))
})

function abrir(c) {
  ficha.value = null
  seleccion.value = { id: c.paciente.id, nombre: `${c.paciente.nombre} ${c.paciente.apellido || ''}`.trim() }
  router.replace({ query: { paciente: c.paciente.id } })
}

const iniciales = (p) => `${p.nombre?.[0] || ''}${p.apellido?.[0] || ''}`.toUpperCase()
const pesos = (n) => new Intl.NumberFormat('es-AR', { style: 'currency', currency: 'ARS', maximumFractionDigits: 0 }).format(Math.abs(n || 0))
const fecha = (f) => { const d = new Date(`${String(f).slice(0, 10)}T00:00:00`); return `${d.getDate()}/${d.getMonth() + 1}` }
const venceProntito = computed(() => {
  const f = ficha.value?.reprocann_vencimiento
  return f && (new Date(`${f}T00:00:00`) - new Date()) / 86400000 <= 30
})
function cuando(at) {
  if (!at) return ''
  const d = new Date(at)
  const hoy = new Date()
  if (d.toDateString() === hoy.toDateString()) return d.toLocaleTimeString('es-AR', { hour: '2-digit', minute: '2-digit' })
  const ayer = new Date(hoy); ayer.setDate(hoy.getDate() - 1)
  if (d.toDateString() === ayer.toDateString()) return 'ayer'
  return `${d.getDate()}/${d.getMonth() + 1}`
}

onMounted(async () => {
  chat.escuchar()
  await chat.cargar()
  // Desde la alerta o un push: `?paciente=<id>` abre esa conversación.
  const id = Number(route.query.paciente)
  if (id) {
    const c = chat.bandeja.find((x) => x.paciente.id === id)
    if (c) { filtro.value = c.sin_responder ? filtro.value : 'todas'; abrir(c) }
  }
})
watch(() => route.query.paciente, (id) => {
  if (!id) return
  const c = chat.bandeja.find((x) => x.paciente.id === Number(id))
  if (c && seleccion.value?.id !== c.paciente.id) abrir(c)
})
</script>

<style scoped>
.cpv { display: flex; height: calc(100dvh - 120px); min-height: 520px; background: #fff; border: 1px solid var(--c-slate-200); border-radius: 14px; overflow: hidden; margin: 1rem; }
.cpv__lista { flex: 0 0 320px; border-right: 1px solid var(--c-slate-200); display: flex; flex-direction: column; overflow-y: auto; }
.cpv__lista-hd { padding: .9rem .9rem .6rem; display: flex; flex-direction: column; gap: .55rem; position: sticky; top: 0; background: #fff; z-index: 1; }
.cpv__title { font-size: 1.15rem; font-weight: 800; margin: 0; color: var(--c-slate-900); }
.cpv__sr { position: absolute; width: 1px; height: 1px; overflow: hidden; clip: rect(0 0 0 0); }
.cpv__buscar { min-height: 38px; border: 0; border-radius: 9px; padding: 0 .75rem; background: var(--c-slate-100); font: inherit; font-size: .9rem; }
.cpv__filtros { display: flex; gap: .35rem; }
.cpv__filtro { min-height: 32px; padding: 0 .75rem; border-radius: 999px; border: 0; background: var(--c-slate-100); color: var(--c-slate-700); font-weight: 600; font-size: .82rem; cursor: pointer; }
.cpv__filtro--on { background: var(--c-leaf-800); color: #fff; }
.cpv__vacio { padding: 1.5rem 1rem; color: var(--c-slate-500); font-size: .9rem; text-align: center; }
.cpv__fila { display: grid; grid-template-columns: 42px minmax(0, 1fr) auto; gap: .65rem; align-items: center; padding: .7rem .9rem; border: 0; border-top: 1px solid var(--c-slate-100); background: #fff; text-align: left; cursor: pointer; font: inherit; color: var(--c-slate-900); }
.cpv__fila:hover { background: var(--c-slate-50); }
.cpv__fila--sel { background: var(--c-leaf-50); }
.cpv__avatar { width: 42px; height: 42px; border-radius: 50%; background: var(--c-leaf-100); color: var(--c-leaf-800); display: grid; place-items: center; font-weight: 700; font-size: .85rem; }
.cpv__fila-txt { min-width: 0; display: flex; flex-direction: column; }
.cpv__fila-txt b { font-size: .92rem; }
.cpv__ultimo { font-size: .82rem; color: var(--c-slate-500); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.cpv__fila-lado { display: flex; flex-direction: column; align-items: flex-end; gap: .25rem; }
.cpv__hora { font-size: .72rem; color: var(--c-slate-500); }
.cpv__hora--nuevo { color: var(--c-leaf-600); font-weight: 700; }
.cpv__nuevos { min-width: 20px; height: 20px; padding: 0 6px; border-radius: 999px; background: var(--c-leaf-600); color: #fff; font-size: .72rem; font-weight: 700; display: grid; place-items: center; }
.cpv__resuelta { font-size: .7rem; color: var(--c-slate-500); }

.cpv__chat { flex: 1; min-width: 0; display: flex; flex-direction: column; }
.cpv__nada { margin: auto; color: var(--c-slate-500); }
.cpv__ficha-link { font-size: .82rem; font-weight: 600; color: var(--c-leaf-700); text-decoration: none; }

.cpv__lado { flex: 0 0 250px; border-left: 1px solid var(--c-slate-200); padding: 1rem; display: flex; flex-direction: column; gap: .6rem; background: var(--c-slate-50); }
.cpv__lado-nombre { font-size: 1rem; }
.cpv__pill { align-self: flex-start; font-size: .75rem; font-weight: 700; padding: .2rem .55rem; border-radius: 999px; background: var(--c-slate-100); color: var(--c-slate-700); }
.cpv__pill--warn { background: var(--c-amber-100); color: var(--c-gold-500); }
.cpv__dato { font-size: .85rem; color: var(--c-slate-700); }
.cpv__renov { font-size: .85rem; padding: .55rem .7rem; border-radius: 9px; background: var(--c-sky-100); color: var(--c-slate-900); text-decoration: none; }
.cpv__boton { margin-top: .3rem; min-height: 38px; display: grid; place-items: center; border-radius: 9px; border: 1px solid var(--c-slate-300); background: #fff; color: var(--c-slate-900); font-weight: 600; font-size: .85rem; text-decoration: none; }

@media (max-width: 1100px) { .cpv__lado { display: none; } }
@media (min-width: 761px) { .cpv :deep(.ccp__volver) { display: none; } }
@media (max-width: 760px) {
  .cpv { margin: 0; border-radius: 0; border: 0; height: calc(100dvh - 64px); }
  .cpv__lista { flex: 1 1 auto; border-right: 0; }
  .cpv__chat { display: none; }
  .cpv--con-chat .cpv__lista { display: none; }
  .cpv--con-chat .cpv__chat { display: flex; }
}
</style>
