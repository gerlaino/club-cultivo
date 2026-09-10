<template>
  <div class="mres">
    <div class="mres__tabs">
      <button class="mres__tab" :class="{ 'mres__tab--on': filtro === 'hoy' }" @click="filtro = 'hoy'">
        Para hoy <span v-if="cuentaHoy" class="mres__badge">{{ cuentaHoy }}</span>
      </button>
      <button class="mres__tab" :class="{ 'mres__tab--on': filtro === 'todas' }" @click="filtro = 'todas'">
        Todas
      </button>
    </div>

    <!-- LA CAJA CERRADA SE AVISA ACÁ, NO AL APRETAR ENTREGAR.
         Entregar una reserva crea una dispensa, y sin caja abierta el backend la rechaza: lo
         cobrado en efectivo no tendría dónde caer. La lista se llena igual —las reservas están
         ahí— así que sin este cartel el botón se aprieta y rebota, con el paciente enfrente y un
         mensaje que parece culpa del usuario. -->
    <div v-if="cajaCerrada" class="mres__aviso">
      <b>La caja del mostrador está cerrada.</b>
      Abrila en <RouterLink to="/m/mostrador" class="mres__aviso-link">Mostrador</RouterLink>
      contando lo que hay sobre la mesa y la plata del cajón: hasta entonces no se puede entregar.
    </div>

    <div v-if="loading" class="mres__muted">Cargando…</div>

    <div v-else-if="!visibles.length" class="mres__empty">
      <span class="mres__empty-ico">📦</span>
      <p>{{ filtro === 'hoy' ? 'No hay reservas para preparar hoy.' : 'No hay reservas pendientes.' }}</p>
    </div>

    <div v-else class="mres__list">
      <div v-for="r in visibles" :key="r.id" class="mres__card" :class="{ 'mres__card--vencida': esVencida(r) }">
        <div class="mres__card-head">
          <span class="mres__paciente">{{ r.paciente?.nombre || '—' }}</span>
          <span class="mres__fecha" :class="{ 'mres__fecha--vencida': esVencida(r) }">
            {{ esVencida(r) ? 'Venció ' : '' }}{{ fechaCorta(r.fecha_entrega_estimada) }}
          </span>
        </div>
        <!-- QUÉ ES LO QUE ESTÁ APARTADO. «5g · Flor seca» no alcanza para ir a buscarlo: la
             variedad es lo que dice cuál de los quince frascos hay que agarrar, y es lo primero
             que nombra el paciente cuando lo viene a retirar. -->
        <div v-if="r.stock?.genetica" class="mres__prod">{{ r.stock.genetica }}</div>
        <div class="mres__meta">
          {{ r.cantidad }}{{ r.stock?.unidad || 'g' }} · {{ formaLabel(r.stock?.forma_producto) }}
          <template v-if="r.stock?.lote"> · {{ r.stock.lote }}</template>
        </div>
        <div class="mres__pie">
          <!-- SEÑADA NO ES PAGA. Decía «Señada ✓» apenas había seña, y una reserva puede estar
               señada con la mitad todavía por cobrar: el que atiende lo entregaba sin cobrar el
               resto.
               PRIMERO LO QUE HAY QUE COBRAR, la seña debajo y en segundo plano. En un renglón
               —«Señó $17.084 · resta $17.084»— son dos plata seguidas y no se sabe cuál es cuál:
               el número que se dice en voz alta es el que falta, y ése va solo y arriba. -->
          <span class="mres__cobro">
            <span class="mres__cobro-hay" :class="`mres__cobro-hay--${cobro(r).tono}`">{{ cobro(r).texto }}</span>
            <span v-if="cobro(r).sena" class="mres__cobro-sena">Seña {{ cobro(r).sena }}</span>
          </span>
          <button class="mres__btn" :disabled="cajaCerrada" @click="entregar(r)">Entregar</button>
        </div>
      </div>
    </div>

    <!-- ENTREGAR ABRE EL MISMO MODAL QUE EN EL ESCRITORIO, con todo precargado.
         Con un toque suelto la entrega salía a ciegas: sin ver la seña ni el resto a cobrar, sin
         poder elegir el medio de pago —salía con el de la reserva, y si era cuenta corriente y el
         paciente no la tiene habilitada, rebotaba— y sin poder ajustar la cantidad que se lleva
         de verdad. Es el mismo componente, así que la regla de cobro vive una sola vez. -->
    <ModalNuevaDispensacion
      v-if="entregando"
      v-model="modalAbierto"
      :socio-id="entregando.paciente?.id"
      :paciente-nombre="entregando.paciente?.nombre"
      :saldo-cc="entregando.paciente?.saldo_cc ?? null"
      :limite-cc="entregando.paciente?.limite_cc ?? null"
      :reserva="entregando"
      @saved="onEntregada"
    />
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { RouterLink } from 'vue-router'
import { listReservas, getMostrador } from '../../lib/api.js'
import { formaLabel, formatARS } from '../../lib/formatters.js'
import { useAuthStore } from '../../stores/auth.js'
import { useSedeStore } from '../../stores/sede.js'
import { sedeDeMostrador } from '../../composables/useMostrador.js'
import ModalNuevaDispensacion from '../../components/pacientes/ModalNuevaDispensacion.vue'
import { hoyISO } from '../../utils/dates.js'

const auth      = useAuthStore()
const sedeStore = useSedeStore()

const filtro     = ref('hoy')
const loading    = ref(false)
const reservas   = ref([])
const entregando   = ref(null)   // la reserva que se está entregando
// Cerrar el modal suelta la reserva: si no, el `v-if` la deja montada y el próximo toque abre la
// anterior por un instante.
const modalAbierto = computed({
  get: () => !!entregando.value,
  set: (v) => { if (!v) entregando.value = null },
})


// LO QUE HAY QUE COBRAR AL ENTREGAR. Son cuatro casos distintos y antes se mostraban como dos:
// si había seña decía «Señada ✓» aunque quedara la mitad por cobrar.
//
// Van en DOS renglones y en este orden: arriba lo que falta —el número que se le dice al paciente
// y el único que hace falta para entregar— y la seña abajo, como contexto de por qué es ése y no
// el total. Juntos en una línea eran dos importes seguidos sin forma de saber cuál era cuál.
function cobro (r) {
  const resta = Number(r.aporte_restante_ars) || 0
  const sena  = Number(r.sena_ars) || 0
  const conSena = sena > 0 ? formatARS(sena) : null

  if (resta > 0)  return { tono: 'resta', texto: `Resta ${formatARS(resta)}`, sena: conSena }
  if (sena > 0)   return { tono: 'ok',    texto: 'Paga ✓',                    sena: conSena }
  // Sin seña y sin resto no es que esté paga: es que no se estimó el aporte al reservarla.
  return { tono: 'muted', texto: 'Se cobra al entregar', sena: null }
}

// "Para hoy" incluye las VENCIDAS: una reserva que quedó de ayer sigue esperando a alguien, y
// esconderla es la forma de que se olvide.
const visibles = computed(() =>
  filtro.value === 'todas'
    ? reservas.value
    : reservas.value.filter(r => (r.fecha_entrega_estimada || '') <= hoyISO()))

const cuentaHoy = computed(() => reservas.value.filter(r => (r.fecha_entrega_estimada || '') <= hoyISO()).length)

const cajaCerrada = ref(false)

onMounted(() => { cargar(); cargarEstadoCaja() })

// Mirar el estado de la caja para no ofrecer un camino que termina en un 422. La regla vive
// entera en el backend (`Dispensacion#mostrador_abierto`); esto sólo la lee.
//
// Si la consulta falla NO se bloquea nada: trabar las entregas por un request que no salió es
// peor que dejar que el backend rechace, que es lo que sabe decidir.
async function cargarEstadoCaja () {
  cajaCerrada.value = false
  if (auth.user?.role !== 'dispensador') return

  // CUÁL ES SU MOSTRADOR LO DECIDE `sedeDeMostrador`, igual que el carrito y que la pantalla del
  // mostrador. Acá se leía `dispensario_sede` a secas y esa columna nace en null: sin sede
  // asignada cortaba antes de preguntar y no avisaba nada, así que la lista ofrecía "Entregar"
  // con la caja cerrada. Es el mismo bug que ya se arregló en el carrito, en otra pantalla.
  if (!sedeStore.loaded) await sedeStore.fetchSedes()
  const sedeId = sedeDeMostrador(auth.user, sedeStore.sedes)
  if (!sedeId) return

  try {
    const { data } = await getMostrador(sedeId)
    cajaCerrada.value = !data?.turno
  } catch { cajaCerrada.value = false }
}

async function cargar() {
  loading.value = true
  try {
    const { data } = await listReservas({ estado: 'pendiente' })
    // El endpoint devuelve { reservas: [...] }. El `?? data` de antes dejaba pasar el objeto entero
    // cuando la forma no coincidía, y la vista reventaba al filtrar algo que no era un array.
    reservas.value = Array.isArray(data?.reservas) ? data.reservas : []
  } catch { reservas.value = [] } finally { loading.value = false }
}

function esVencida(r) { return (r.fecha_entrega_estimada || '') < hoyISO() }

// Abrir el modal, no entregar de una: lo que se cobra —la seña ya paga, el resto, con qué medio—
// se decide con el paciente enfrente, no se adivina desde la lista.
function entregar(r) {
  entregando.value = r
}

async function onEntregada() {
  // SIN TOAST ACÁ: lo canta el modal, que es el que sabe si la entrega salió bien. Festejando en
  // los dos lados salía dos veces y se leía como que se registró dos veces — el susto es peor que
  // el bug, porque lo que está en juego es una dispensa.
  entregando.value = null
  await cargar()
  await cargarEstadoCaja()
}

function fechaCorta(f) {
  if (!f) return ''
  const d = new Date(`${f}T12:00:00`)
  return `${String(d.getDate()).padStart(2, '0')}/${String(d.getMonth() + 1).padStart(2, '0')}`
}
</script>

<style scoped>
.mres { padding: .75rem; display: flex; flex-direction: column; gap: .75rem; }
.mres__aviso {
  background: var(--c-amber-100); border: 1px solid var(--c-amber-300, #fcd34d);
  border-radius: 10px; padding: .6rem .75rem;
  font-size: .8rem; line-height: 1.45; color: var(--c-ink-700);
}
.mres__aviso-link { color: inherit; font-weight: 700; }

.mres__tabs { display: flex; gap: .4rem; }
.mres__tab {
  flex: 1; border: 1px solid var(--c-slate-200); background: #fff; border-radius: 10px;
  padding: .55rem; font-size: .85rem; color: var(--c-slate-500); cursor: pointer;
}
.mres__tab--on {
  border-color: var(--c-leaf-600, #16a34a); background: #f0fdf4;
  color: var(--c-leaf-700, #15803d); font-weight: 600;
}
.mres__badge {
  background: var(--c-leaf-600, #16a34a); color: #fff; border-radius: 999px;
  padding: 0 .4em; font-size: .72rem; margin-left: .25em;
}

.mres__muted { text-align: center; color: var(--c-slate-400); padding: 1rem; font-size: .85rem; }
.mres__empty { text-align: center; padding: 2rem 1rem; color: var(--c-slate-500); }
.mres__empty-ico { font-size: 2rem; display: block; margin-bottom: .5rem; }

.mres__list { display: flex; flex-direction: column; gap: .5rem; }
.mres__card {
  background: #fff; border: 1px solid var(--c-slate-100); border-radius: 12px;
  padding: .8rem .9rem; display: flex; flex-direction: column; gap: .4rem;
}
.mres__card--vencida { border-color: #fecaca; background: #fef2f2; }
.mres__card-head { display: flex; justify-content: space-between; align-items: center; gap: .5rem; }
.mres__paciente { font-weight: 600; color: var(--c-ink-800, #1e293b); }
.mres__fecha { font-size: .75rem; color: var(--c-slate-400); white-space: nowrap; }
.mres__fecha--vencida { color: #dc2626; font-weight: 600; }
/* La variedad primero y con peso: es el dato con el que se va a buscar el frasco. */
.mres__prod { font-size: .9rem; font-weight: 600; color: var(--c-ink-800, #1e293b); }
.mres__meta { font-size: .8rem; color: var(--c-slate-500); margin-top: -.25rem; }
.mres__pie { display: flex; align-items: center; justify-content: space-between; gap: .5rem; }
/* Lo que falta cobrar arriba y solo; la seña abajo y en segundo plano. Con el botón al lado, dos
   renglones cortos entran donde uno largo se parte — y el importe que se dice en voz alta no se
   puede cortar. */
.mres__cobro { display: flex; flex-direction: column; gap: .1rem; min-width: 0; }
.mres__cobro-hay { font-size: .8rem; font-weight: 600; }
.mres__cobro-hay--resta { color: #b45309; }
.mres__cobro-hay--ok    { color: #15803d; }
.mres__cobro-hay--muted { color: var(--c-slate-500); font-weight: 500; }
.mres__cobro-sena { font-size: .72rem; color: var(--c-slate-500); }
.mres__btn {
  border: none; border-radius: 10px; padding: .5rem 1rem; cursor: pointer;
  background: var(--c-leaf-600, #16a34a); color: #fff; font-size: .85rem; font-weight: 600;
}
.mres__btn:disabled { opacity: .5; }
</style>
