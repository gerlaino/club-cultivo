<template>
  <div class="mst">
    <!-- ── Encabezado: qué es esto y en qué estado está ───────────────────────── -->
    <header class="mst__head">
      <div class="mst__head-left">
        <h1 class="mst__title">Mostrador</h1>
        <p class="mst__sub">Lo que hay sobre la mesa para dispensar hoy.</p>
      </div>

      <div class="mst__head-right">
        <select v-if="sedes.length > 1" v-model="sedeId" class="mst__select mst__select--sede">
          <option v-for="s in sedes" :key="s.id" :value="s.id">{{ s.nombre }}</option>
        </select>
        <span v-if="tab === 'hoy'" class="mst__estado" :class="`is-${estado}`">
          <span class="mst__estado-dot" />{{ ESTADO_LABEL[estado] }}
        </span>
      </div>
    </header>

    <!-- Un repartidor esperando que le reciban la caja: acá es donde está el cajón. Al recibirla
         entra plata Y puede subir producto a la mesa, así que la pantalla se recarga. -->
    <RendicionCajaCard @recibida="cargar" />

    <nav class="mst__tabs">
      <button class="mst__tab" :class="{ 'is-on': tab === 'hoy' }" @click="tab = 'hoy'">Hoy</button>
      <!-- Los turnos cerrados los ve TAMBIÉN el que atiende, con los suyos: cerraba y no tenía
           dónde mirarlo si al día siguiente le preguntaban por una diferencia. -->
      <button class="mst__tab" :class="{ 'is-on': tab === 'turnos' }" @click="tab = 'turnos'">
        Turnos
      </button>
      <template v-if="gestiona">
        <button class="mst__tab" :class="{ 'is-on': tab === 'merma' }" @click="tab = 'merma'">
          Merma
          <span v-if="sinRevisar" class="mst__tab-badge">{{ sinRevisar }}</span>
        </button>
        <button class="mst__tab" :class="{ 'is-on': tab === 'rendiciones' }" @click="tab = 'rendiciones'">
          Rendiciones
        </button>
      </template>
    </nav>

    <!-- ══ RENDICIONES: lo que ya rindieron los repartidores ══════════════════ -->
    <template v-if="tab === 'rendiciones'">
      <p class="mst__seccion-sub">
        Lo que cada repartidor cobró en la calle y lo que entregó al volver. Lo que falta no es
        una pérdida: queda a su nombre y se ve acumulado en su ficha.
      </p>
      <RendicionCajaCard historial />
    </template>

    <!-- ══ MERMA: dónde se le va el producto ══════════════════════════════════ -->
    <MostradorMerma v-else-if="tab === 'merma'" :sede-id="sedeId" :varias-sedes="sedes.length > 1"
                    @sin-revisar="sinRevisar = $event" />

    <!-- ══ TURNOS: los que ya cerraron ════════════════════════════════════════ -->
    <MostradorTurnos v-else-if="tab === 'turnos'" :sede-id="sedeId" />

    <template v-else>

    <div v-if="cargando" class="mst__skel-wrap">
      <div v-for="n in 4" :key="n" class="mst__skel" />
    </div>

    <p v-else-if="error" class="mst__aviso mst__aviso--error">{{ error }}</p>

    <template v-else>
      <!-- ══ LA CAJA: quién la abrió y cómo viene ═══════════════════════════════ -->
      <section class="mst__turno">
        <div class="mst__turno-info">
          <template v-if="turno">
            <span class="mst__turno-quien">{{ turno.abierto_por }}</span>
            <span class="mst__turno-desde">abrió a las {{ hora(turno.abierto_at) }}</span>
            <!-- LO ESPERADO SÓLO PARA ADMINISTRACIÓN, que monitorea. A quien va a CONTAR no se
                 le muestra: con el número a la vista se escribe ese, el conteo es teatro y toda
                 la merma que se mide da cero. El modal lo revela recién después de escribir. -->
            <span v-if="gestiona && turno.caja" class="mst__turno-desde">
              · en caja tendría que haber <b>${{ fmt(turno.caja.esperado_ars) }}</b>
            </span>
          </template>
          <span v-else class="mst__turno-desde">
            La caja está cerrada. {{ mesa.length ? 'Hay mercadería sobre la mesa.' : 'La mesa está vacía.' }}
          </span>
        </div>
        <div class="mst__turno-acc">
          <span v-if="gestiona && turno?.valor_mesa_ars" class="mst__valor-mesa">
            ${{ fmt(turno.valor_mesa_ars) }} sobre la mesa
          </span>
          <button v-if="turno" class="mst__btn mst__btn--primary" @click="conteo = 'cierre'">Cerrar caja</button>
          <button v-else class="mst__btn mst__btn--primary" @click="conteo = 'apertura'">Abrir caja</button>
        </div>
      </section>

      <p v-if="turno?.notas_apertura" class="mst__aviso mst__aviso--warn">
        Al abrir: {{ turno.notas_apertura }}
      </p>

      <!-- Lo que el admin tocó mientras la caja estaba abierta. Quien atiende lo tiene que ver o
           cierra con un faltante que no es suyo y encima no lo puede explicar. -->
      <div v-if="movimientosDelTurno.length" class="mst__movs">
        <span class="mst__movs-lbl">Mientras la caja estuvo abierta</span>
        <p v-for="(m, i) in movimientosDelTurno" :key="i" class="mst__mov">
          <b>{{ m.usuario }}</b> {{ m.cantidad > 0 ? 'subió' : 'bajó' }}
          {{ fmt(Math.abs(m.cantidad)) }} {{ m.unidad }} de {{ formaLabel(m.forma) }}
          a las {{ hora(m.cuando) }}<template v-if="m.motivo"> — {{ m.motivo }}</template>
        </p>
      </div>

      <!-- ══ LA MESA ═══════════════════════════════════════════════════════════
           Para administración es editable: escribe cuánto tiene que haber de cada producto y
           guarda con un motivo. Para quien atiende es de lectura — él nunca elige qué hay. -->
      <div v-if="gestiona" class="mst__mesa-hd">
        <h2 class="mst__seccion">Qué hay sobre la mesa</h2>
        <p class="mst__seccion-sub">
          Escribí cuánto de cada producto tiene que quedar disponible para dispensar. Podés subir
          y bajar cuando quieras, desde donde estés.
        </p>
      </div>

      <TablaMostrador v-model="cantidades" :stocks="tabla" :editable="gestiona"
                      :muestra-costo="gestiona"
                      :vacio-texto="gestiona ? 'No hay stock habilitado para dispensar en esta sede.'
                                             : 'La mesa está vacía. La carga administración.'" />

      <div v-if="gestiona && hayCambios" class="mst__guardar">
        <input v-model="motivo" type="text" class="mst__input"
               placeholder="Por qué se cambia la mesa — ej: reposición del mediodía" />
        <button class="mst__btn mst__btn--primary" :disabled="guardando || !motivo.trim()"
                @click="guardarMesa">
          {{ guardando ? 'Guardando…' : 'Guardar cambios' }}
        </button>
      </div>

      <div v-if="gestiona && turno?.caja" class="mst__caja-barra">
        <span class="mst__caja-barra-lbl">
          En la caja tendría que haber <b>${{ fmt(turno.caja.esperado_ars) }}</b>
        </span>
        <button class="mst__btn mst__btn--mini" @click="abrirPlata('ingreso')">Poner plata</button>
        <button class="mst__btn mst__btn--mini mst__btn--ghost" @click="abrirPlata('salida')">Sacar plata</button>
      </div>
    </template>
    </template>

    <ModalConteo v-if="conteo" :mesa="mesa" :es-cierre="conteo === 'cierre'"
                 :esperado-efectivo="esperadoEfectivo" :puede-retirar="gestiona"
                 :guardando="guardando"
                 @cerrar="conteo = null" @confirmar="confirmarConteo" />

    <!-- ── Poner o sacar plata del cajón, con la caja abierta ─────────────────── -->
    <div v-if="plata" class="mst__modal-back" @click.self="plata = null">
      <div class="mst__modal">
        <h3 class="mst__modal-title">{{ plata.tipo === 'ingreso' ? 'Poner plata en el cajón' : 'Sacar plata del cajón' }}</h3>
        <p class="mst__modal-sub">
          {{ plata.tipo === 'ingreso'
             ? 'Cambio, reponer el fondo, o lo que se cobró por fuera. No cuenta como ingreso del club: esa plata ya era suya.'
             : 'Un gasto pagado con la caja baja el resultado; un retiro no, pero queda a nombre de alguien.' }}
        </p>
        <input v-model.number="plata.monto" type="number" min="0" step="100" class="mst__input"
               placeholder="Monto" aria-label="Monto" />
        <input v-model="plata.motivo" type="text" class="mst__input"
               :placeholder="plata.tipo === 'ingreso' ? 'De dónde sale' : 'Para qué se saca'" />
        <select v-if="plata.tipo === 'salida'" v-model="plata.clase" class="mst__select">
          <option value="retiro">Retiro — sigue siendo del club</option>
          <option value="gasto">Gasto — el club gastó esa plata</option>
        </select>
        <div class="mst__modal-acc">
          <button class="mst__btn mst__btn--ghost" @click="plata = null">Cancelar</button>
          <button class="mst__btn mst__btn--primary" :disabled="guardando || !plata.monto || !plata.motivo"
                  @click="confirmarPlata">Confirmar</button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
// EL MOSTRADOR: qué hay sobre la mesa y cómo va la caja.
//
// Son DOS cosas separadas, de personas distintas:
//   · QUÉ HAY sobre la mesa → lo decide administración, cuando quiera y desde donde esté. Es un
//     estado permanente: sigue ahí con la caja cerrada, porque el producto está físicamente ahí.
//   · LA CAJA               → la abre y la cierra quien atiende, contando lo que encuentra.
//
// Atadas —abrir la caja ERA poner la mercadería— el admin no podía gobernar la mesa a distancia,
// que es el punto entero del módulo: que pueda delegar tranquilo y monitorear sin estar ahí.
//
// NADA DE ESTO ES PARA SEÑALAR A NADIE. La merma existe y es inevitable: contar sirve para que la
// organización sepa cuánta hay y dónde. Una diferencia es un dato que se anota, no una falta que
// alguien tiene que explicar.
import { ref, computed, watch, onMounted } from 'vue'
import RendicionCajaCard from '../components/RendicionCajaCard.vue'
import MostradorMerma from '../components/mostrador/MostradorMerma.vue'
import MostradorTurnos from '../components/mostrador/MostradorTurnos.vue'
import TablaMostrador from '../components/mostrador/TablaMostrador.vue'
import ModalConteo from '../components/mostrador/ModalConteo.vue'
import { getMostrador, cargarMostrador, abrirMostrador, cerrarMostrador,
         ingresoCajaMostrador, salidaCajaMostrador } from '../lib/api.js'
import { formaLabel } from '../lib/formatters.js'
import { useAuthStore } from '../stores/auth.js'
import { useSedeStore } from '../stores/sede.js'
import { useStockChannel } from '../composables/useStockChannel.js'
import { useToast } from '../composables/useToast.js'

const sedeStore = useSedeStore()
const auth      = useAuthStore()
const toast     = useToast()

// La merma y las rendiciones son información de GESTIÓN, y la mesa la gobierna administración.
// Quien atiende decide con lo que tiene sobre la mesa.
const gestiona = computed(() => ['admin', 'supervisor', 'super_admin'].includes(auth.user?.role))

const sedeId    = ref(null)
const cargando  = ref(true)
const cargado   = ref(false)
const guardando = ref(false)
const error     = ref('')
const turno     = ref(null)
const mesa      = ref([])
const disponibles = ref([])
const fondoSugerido = ref(null)
const conteo    = ref(null)      // 'apertura' | 'cierre'
const plata     = ref(null)
const tab       = ref('hoy')
const sinRevisar = ref(0)

// Lo que va a quedar sobre la mesa: { stock_id: cantidad }. Vive acá y no en la tabla para
// sobrevivir al buscador y al orden — si viviera adentro, filtrar borraría lo ya escrito.
const cantidades = ref({})
const motivo     = ref('')

const ESTADO_LABEL = { cerrado: 'Cerrado', abierto: 'Abierto' }

const sedes   = computed(() => (sedeStore.sedes || []).filter(s => s.tipo === 'social' || s.tipo === 'mixta'))
const estado  = computed(() => (turno.value ? 'abierto' : 'cerrado'))

// Administración ve TODO el stock apto de la sede, con lo que hay en el depósito y lo que hay
// sobre la mesa. Quien atiende ve sólo la mesa: él no elige qué hay.
const tabla = computed(() => {
  if (!gestiona.value) return mesa.value
  const enMesa = new Map(mesa.value.map(m => [m.stock_id, m.mostrador]))
  return disponibles.value.map(s => ({ ...s, mostrador: enMesa.get(s.stock_id) || 0 }))
})

const hayCambios = computed(() =>
  tabla.value.some(s => {
    const v = cantidades.value[s.stock_id]
    return v !== undefined && Number(v) !== Number(s.mostrador || 0)
  })
)

const esperadoEfectivo = computed(() =>
  turno.value?.caja?.esperado_ars ?? Number(fondoSugerido.value || 0)
)

// Lo que administración tocó mientras la caja estaba abierta. Sin esto, quien atiende cierra con
// un faltante que no es suyo y no lo puede explicar.
const movimientosDelTurno = computed(() =>
  mesa.value.flatMap(m => (m.movimientos_del_turno || [])
    .filter(mv => mv.tipo !== 'ajuste')
    .map(mv => ({ ...mv, forma: m.forma, unidad: m.unidad })))
)

const fmt  = (n) => Number(n ?? 0).toLocaleString('es-AR', { maximumFractionDigits: 1 })
const hora = (iso) => (iso ? new Date(iso).toLocaleTimeString('es-AR', { hour: '2-digit', minute: '2-digit' }) : '')

let cargaEnCurso = 0

async function cargar () {
  if (!sedeId.value) {
    // Todavía no sabemos con qué sede trabajar: el watcher corre con `immediate` ANTES de que
    // `onMounted` la fije. Si la pantalla se dibujara vacía y un instante después se rearmara,
    // lo que la persona haya empezado a escribir se pierde sin que haya tocado nada.
    cargando.value = !sedeStore.loaded || sedes.value.length > 0
    return
  }
  const mia = ++cargaEnCurso
  if (!cargado.value) cargando.value = true
  error.value = ''
  try {
    const { data } = await getMostrador(sedeId.value)
    if (mia !== cargaEnCurso) return // llegó tarde: ya hay una carga más nueva

    turno.value       = data.turno
    mesa.value        = data.mesa || []
    disponibles.value = data.disponibles || []
    fondoSugerido.value = data.fondo_sugerido ?? null
    sinRevisar.value  = data.sin_revisar ?? 0
    // La tabla arranca con lo que HAY: se corrige lo que haya que corregir, no se declara todo.
    cantidades.value  = Object.fromEntries(tabla.value.map(s => [s.stock_id, Number(s.mostrador || 0)]))
    motivo.value      = ''
  } catch (e) {
    if (mia === cargaEnCurso) error.value = e?.response?.data?.error || 'No se pudo cargar el mostrador.'
  } finally {
    if (mia === cargaEnCurso) { cargando.value = false; cargado.value = true }
  }
}

// Sólo lo que cambió: mandar la tabla entera haría que el backend evalúe productos que nadie tocó.
async function guardarMesa () {
  const cambios = tabla.value
    .filter(s => cantidades.value[s.stock_id] !== undefined &&
                 Number(cantidades.value[s.stock_id]) !== Number(s.mostrador || 0))
    .map(s => ({ stock_id: s.stock_id, cantidad: Number(cantidades.value[s.stock_id]) }))
  if (!cambios.length) return

  guardando.value = true
  try {
    await cargarMostrador(sedeId.value, { cambios, motivo: motivo.value })
    toast.success(cambios.length === 1 ? 'Mesa actualizada' : `${cambios.length} productos actualizados`)
    await cargar()
  } catch (e) {
    toast.error(e?.response?.data?.error || 'No se pudo actualizar la mesa.')
  } finally { guardando.value = false }
}

async function confirmarConteo (payload) {
  const esCierre = conteo.value === 'cierre'
  guardando.value = true
  try {
    if (esCierre) await cerrarMostrador(sedeId.value, payload)
    else          await abrirMostrador(sedeId.value, payload)
    conteo.value = null
    toast.success(esCierre ? 'Caja cerrada' : 'Caja abierta')
    await cargar()
  } catch (e) {
    toast.error(e?.response?.data?.error || 'No se pudo registrar el conteo.')
  } finally { guardando.value = false }
}

function abrirPlata (tipo) { plata.value = { tipo, monto: null, motivo: '', clase: 'retiro' } }

async function confirmarPlata () {
  const { tipo, monto, motivo: mot, clase } = plata.value
  const cajaId = turno.value?.caja?.id
  if (!cajaId) return
  guardando.value = true
  try {
    if (tipo === 'ingreso') await ingresoCajaMostrador(sedeId.value, cajaId, { monto_ars: monto, motivo: mot })
    else                    await salidaCajaMostrador(sedeId.value, cajaId, { monto_ars: monto, motivo: mot, clase })
    plata.value = null
    toast.success(tipo === 'ingreso' ? 'Plata puesta en el cajón' : 'Plata sacada del cajón')
    await cargar()
  } catch (e) {
    toast.error(e?.response?.data?.error || 'No se pudo mover la plata.')
  } finally { guardando.value = false }
}

onMounted(async () => {
  if (!sedeStore.loaded) await sedeStore.fetchSedes()
  // No se llama a `cargar()` acá: fijar la sede dispara el watcher, que carga. Hacer las dos
  // cosas mandaba DOS pedidos por cada apertura de la pantalla.
  sedeId.value = sedes.value[0]?.id ?? null
})

// La mesa se actualiza sola: si administración baja producto desde su oficina, quien atiende lo
// ve sin recargar — recargar es lo que nadie hace con alguien esperando enfrente. Y se agrupan:
// una tanda de cambios emite un aviso por producto.
let recargaPendiente = null
useStockChannel(null, (evento) => {
  if (evento?.tipo !== 'mostrador_actualizado') return
  if (evento.sede_id && evento.sede_id !== sedeId.value) return

  clearTimeout(recargaPendiente)
  recargaPendiente = setTimeout(cargar, 300)
})

watch(sedeId, () => { cargado.value = false; cantidades.value = {}; cargar() }, { immediate: true })
</script>

<style scoped>
/* Centrada: tenía `max-width` sin `margin auto`, así que en una pantalla ancha quedaba pegada a
   la izquierda con medio monitor vacío al lado. */
.mst { padding: 20px 24px 48px; max-width: 1180px; margin: 0 auto; }

/* ── La mesa ────────────────────────────────────────────────────────────────── */
.mst__mesa-hd { margin-top: 6px; }
.mst__seccion {
  font-family: var(--font-display); font-size: var(--fs-16); font-weight: 700;
  color: var(--c-leaf-900); margin: 0 0 2px;
}
.mst__guardar {
  display: flex; gap: 10px; align-items: center; flex-wrap: wrap;
  background: var(--c-amber-100); border-radius: 11px; padding: 12px 16px;
}
.mst__guardar .mst__input { flex: 1; min-width: 240px; }

/* Lo que administración tocó mientras la caja estaba abierta: quien atiende lo tiene que ver o
   cierra con un faltante que no es suyo. */
.mst__movs {
  background: var(--c-sky-100); border-radius: 11px; padding: 12px 16px;
  display: flex; flex-direction: column; gap: 4px;
}
.mst__movs-lbl { font-size: var(--fs-12); font-weight: 700; color: var(--c-sky-600); text-transform: uppercase; letter-spacing: .04em; }
.mst__mov { margin: 0; font-size: var(--fs-13); color: var(--c-ink-700); }

/* ── Solapas ────────────────────────────────────────────────────────────────── */
.mst__tabs { display: flex; gap: 4px; margin-bottom: 18px; border-bottom: 1px solid var(--c-slate-200); }
.mst__tab {
  border: 0; background: transparent; cursor: pointer;
  padding: 9px 15px; margin-bottom: -1px;
  font-size: var(--fs-14); font-weight: 600; color: var(--c-ink-500);
  border-bottom: 2px solid transparent;
  display: inline-flex; align-items: center; gap: 7px;
}
.mst__tab:hover  { color: var(--c-ink-900); }
.mst__tab.is-on  { color: var(--c-leaf-800); border-bottom-color: var(--c-leaf-800); }
.mst__tab-badge {
  background: var(--c-amber-100); color: var(--c-amber-500);
  border-radius: 999px; padding: 1px 7px; font-size: var(--fs-12);
}

/* ── Encabezado ─────────────────────────────────────────────────────────────── */
.mst__head {
  display: flex; align-items: flex-start; justify-content: space-between;
  gap: 16px; flex-wrap: wrap; margin-bottom: 20px;
}
.mst__title {
  font-family: var(--font-display); font-size: var(--fs-28, 28px); font-weight: 700;
  color: var(--c-leaf-900); margin: 0; letter-spacing: -.02em;
}
.mst__sub { margin: 4px 0 0; font-size: var(--fs-14); color: var(--c-ink-500); }
.mst__head-left  { min-width: 0; }
.mst__head-right { display: flex; align-items: center; gap: 10px; flex-shrink: 0; }

.mst__estado {
  display: inline-flex; align-items: center; gap: 7px;
  padding: 7px 14px; border-radius: 999px;
  font-size: var(--fs-13); font-weight: 600;
}
.mst__estado-dot { width: 8px; height: 8px; border-radius: 50%; background: currentColor; }
.mst__estado.is-abierto     { background: var(--c-leaf-100);  color: var(--c-leaf-700); }
.mst__estado.is-cerrado     { background: var(--c-ink-100);   color: var(--c-ink-500); }

/* ── Tarjeta de apertura ────────────────────────────────────────────────────── */
.mst__card {
  background: #fff; border: 1px solid var(--c-slate-200); border-radius: 14px;
  padding: 22px; display: flex; flex-direction: column; gap: 18px;
}
.mst__card-head { border-bottom: 1px solid var(--c-slate-100); padding-bottom: 14px; }
.mst__card-title {
  font-family: var(--font-display); font-size: var(--fs-18); font-weight: 700;
  color: var(--c-leaf-900); margin: 0;
}
.mst__card-sub { margin: 4px 0 0; font-size: var(--fs-13); color: var(--c-ink-500); }

.mst__fondo { display: flex; align-items: center; justify-content: space-between; gap: 12px; flex-wrap: wrap; }
.mst__fondo-lbl { font-size: var(--fs-14); font-weight: 600; color: var(--c-ink-900); }
.mst__fondo-input { display: inline-flex; align-items: center; gap: 6px; }
.mst__fondo-signo { font-size: var(--fs-16); color: var(--c-ink-500); }

.mst__input {
  border: 1px solid var(--c-slate-300); border-radius: 9px; padding: 9px 11px;
  font-size: var(--fs-14); font-family: var(--font-mono); width: 100%;
  background: #fff; color: var(--c-ink-900);
}
.mst__input:focus { outline: 2px solid var(--c-leaf-300); outline-offset: 1px; border-color: var(--c-leaf-500); }
.mst__input--fondo { width: 150px; text-align: right; }
.mst__input--cant  { width: 96px;  text-align: right; }

.mst__select {
  border: 1px solid var(--c-slate-300); border-radius: 9px; padding: 9px 11px;
  font-size: var(--fs-14); background: #fff; color: var(--c-ink-900); max-width: 100%;
}
.mst__select--sede { min-width: 160px; }

/* ── Borrador de apertura ───────────────────────────────────────────────────── */
.mst__draft { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; }
.mst__draft-row {
  display: flex; align-items: center; gap: 12px;
  padding: 12px 0; border-top: 1px solid var(--c-slate-100);
}
.mst__draft-prod { flex: 1; min-width: 0; }
.mst__draft-nombre { display: block; font-size: var(--fs-14); font-weight: 600; color: var(--c-ink-900); }
.mst__draft-meta   { display: block; font-size: var(--fs-12); color: var(--c-ink-500); margin-top: 2px; }
.mst__draft-cant   { display: inline-flex; align-items: baseline; gap: 6px; }
.mst__draft-unidad { font-size: var(--fs-13); color: var(--c-ink-500); width: 22px; }

.mst__icon-btn {
  border: 0; background: transparent; color: var(--c-ink-500); cursor: pointer;
  padding: 6px; border-radius: 7px; display: inline-flex;
}
.mst__icon-btn:hover { background: var(--c-ink-100); color: var(--c-rust-600); }

.mst__vacio { margin: 0; font-size: var(--fs-14); color: var(--c-ink-500); }
.mst__seccion-sub { margin: 0 0 12px; font-size: var(--fs-13); color: var(--c-ink-500); max-width: 60ch; }
.mst__pie   { margin: 0; font-size: var(--fs-12); color: var(--c-ink-500); }
/* El renglón que se va de la mesa: se ve tachado antes de confirmar, para poder arrepentirse. */
.mst__draft-row.is-quitado .mst__draft-nombre { text-decoration: line-through; color: var(--c-ink-500); }

/* ── Turno abierto ──────────────────────────────────────────────────────────── */
/* El turno y su acción, en una línea: el botón suelto debajo del nombre parecía de otra cosa. */
.mst__turno {
  display: flex; align-items: center; justify-content: space-between;
  gap: 12px; flex-wrap: wrap; margin-bottom: 14px;
}
.mst__turno-info { display: flex; align-items: baseline; gap: 8px; flex-wrap: wrap; }
.mst__turno-quien { font-size: var(--fs-14); font-weight: 600; color: var(--c-ink-900); }
.mst__turno-desde { font-size: var(--fs-13); color: var(--c-ink-500); }
.mst__turno-acc   { display: flex; align-items: center; gap: 12px; flex-wrap: wrap; }
/* En gramos no se compara con nada; en plata se ve de un vistazo cuánto hay ahí arriba. */
.mst__valor-mesa  { font-size: var(--fs-13); color: var(--c-ink-500); font-family: var(--font-mono); }

.mst__table-wrap {
  background: #fff; border: 1px solid var(--c-slate-200);
  border-radius: 14px; overflow-x: auto;
}
.mst__table { width: 100%; border-collapse: collapse; }
.mst__table th {
  text-align: left; font-size: var(--fs-12); font-weight: 600; text-transform: uppercase;
  letter-spacing: .04em; color: var(--c-ink-500);
  padding: 13px 16px; border-bottom: 1px solid var(--c-slate-200); white-space: nowrap;
}
.mst__table td { padding: 14px 16px; border-bottom: 1px solid var(--c-slate-100); vertical-align: middle; }
.mst__table tbody tr:last-child td { border-bottom: 0; }
.mst__table tbody tr.is-alerta { background: var(--c-rust-100); }

.mst__th-num, .mst__td-num { text-align: right; }
.mst__th-acc, .mst__td-acc { text-align: right; white-space: nowrap; }
.mst__td-mut { color: var(--c-ink-500); font-size: var(--fs-13); font-family: var(--font-mono); }

.mst__prod { font-size: var(--fs-14); font-weight: 600; color: var(--c-ink-900); }
.mst__prod-meta { display: flex; gap: 6px; flex-wrap: wrap; margin-top: 5px; }

/* El número que se lee de un vistazo: es la única pregunta del que atiende. */
.mst__mesa {
  font-family: var(--font-mono); font-size: var(--fs-18);
  font-weight: 700; color: var(--c-leaf-800);
}
.mst__unidad { font-size: var(--fs-12); color: var(--c-ink-500); margin-left: 3px; }

.mst__pill {
  display: inline-block; padding: 2px 8px; border-radius: 999px;
  font-size: var(--fs-12); font-weight: 600;
}
.mst__pill--warn   { background: var(--c-amber-100); color: var(--c-amber-500); }
.mst__pill--danger { background: var(--c-rust-100);  color: var(--c-rust-600); }
.mst__pill--info   { background: var(--c-sky-100);   color: var(--c-sky-600); }

/* ── Barra de caja del turno ────────────────────────────────────────────────── */
.mst__caja-barra {
  display: flex; align-items: center; gap: 10px; flex-wrap: wrap;
  margin-top: 14px; padding: 12px 16px;
  background: var(--c-leaf-50); border-radius: 11px;
}
.mst__caja-barra-lbl { flex: 1; font-size: var(--fs-13); color: var(--c-ink-700); }
.mst__caja-barra-lbl b { font-family: var(--font-mono); color: var(--c-ink-900); }

/* ── Botones ────────────────────────────────────────────────────────────────── */
.mst__acciones { display: flex; gap: 10px; justify-content: flex-end; flex-wrap: wrap; }
.mst__acciones--turno { margin-top: 14px; justify-content: space-between; }

.mst__btn {
  border-radius: 9px; padding: 10px 18px; font-size: var(--fs-14); font-weight: 600;
  cursor: pointer; border: 1px solid transparent; transition: background .12s, border-color .12s;
}
.mst__btn:disabled { opacity: .5; cursor: not-allowed; }
.mst__btn--primary { background: var(--c-leaf-800); color: #fff; }
.mst__btn--primary:not(:disabled):hover { background: var(--c-leaf-900); }
.mst__btn--ghost   { background: #fff; color: var(--c-ink-700); border-color: var(--c-slate-300); }
.mst__btn--ghost:not(:disabled):hover { background: var(--c-slate-50); }
/* La excepción, no la acción normal: corregir un conteo cerrado ajusta el inventario. */
.mst__btn--corregir { margin-left: 6px; }
.mst__btn--mini    { padding: 6px 12px; font-size: var(--fs-13); background: var(--c-leaf-100); color: var(--c-leaf-800); }
.mst__btn--mini.mst__btn--ghost { background: #fff; color: var(--c-ink-700); }

/* ── Avisos y esqueleto ─────────────────────────────────────────────────────── */
.mst__aviso { margin: 8px 0 0; padding: 10px 14px; border-radius: 9px; font-size: var(--fs-13); }
.mst__aviso--warn  { background: var(--c-amber-100); color: var(--c-amber-500); }
.mst__aviso--error { background: var(--c-rust-100);  color: var(--c-rust-600); }

.mst__skel-wrap { display: flex; flex-direction: column; gap: 10px; }
.mst__skel {
  height: 64px; border-radius: 12px;
  background: linear-gradient(90deg, var(--c-slate-100) 25%, var(--c-slate-50) 50%, var(--c-slate-100) 75%);
  background-size: 200% 100%; animation: mst-shimmer 1.4s infinite;
}
@keyframes mst-shimmer { from { background-position: 200% 0; } to { background-position: -200% 0; } }

/* ── Modal de reponer / devolver ────────────────────────────────────────────── */
.mst__modal-back {
  position: fixed; inset: 0; background: rgba(15, 42, 30, .45);
  display: flex; align-items: center; justify-content: center; padding: 20px; z-index: 1000;
}
.mst__modal {
  background: #fff; border-radius: 14px; padding: 24px;
  width: 100%; max-width: 400px; display: flex; flex-direction: column; gap: 14px;
}
.mst__modal-title {
  font-family: var(--font-display); font-size: var(--fs-16); font-weight: 700;
  color: var(--c-leaf-900); margin: 0;
}
.mst__modal-sub { margin: 0; font-size: var(--fs-13); color: var(--c-ink-500); }
.mst__modal-acc { display: flex; gap: 10px; justify-content: flex-end; }
.mst__modal--ancho { max-width: 560px; max-height: 88vh; overflow-y: auto; }

/* ── Conteo del cierre ──────────────────────────────────────────────────────── */
.mst__conteo { display: flex; flex-direction: column; }
.mst__conteo-row {
  display: flex; align-items: center; gap: 12px;
  padding: 11px 0; border-top: 1px solid var(--c-slate-100);
}
.mst__conteo-prod { flex: 1; min-width: 0; }
.mst__conteo-cant { display: inline-flex; align-items: baseline; gap: 6px; }

.mst__dif {
  font-family: var(--font-mono); font-size: var(--fs-13);
  min-width: 74px; text-align: right;
}
.mst__dif.is-ok  { color: var(--c-leaf-600); }
.mst__dif.is-dif { color: var(--c-amber-500); font-weight: 600; }

.mst__campo { display: flex; flex-direction: column; gap: 5px; }
.mst__campo-lbl { font-size: var(--fs-13); font-weight: 600; color: var(--c-ink-900); }
/* El monto es un número corto: a lo ancho de la tarjeta parece un campo de texto libre. */
.mst__campo--fila { flex-direction: row; align-items: center; justify-content: space-between; }
/* El motivo aparece sólo cuando hay diferencia. Se destaca porque hay que completarlo, no
   porque haya pasado algo malo. */
.mst__campo--motivo .mst__campo-lbl { color: var(--c-amber-500); }

/* ── El arqueo de plata, dentro del mismo cierre ────────────────────────────── */
.mst__caja {
  display: flex; flex-direction: column; gap: 11px;
  background: var(--c-leaf-50); border-radius: 11px; padding: 15px;
}
.mst__caja-fila {
  display: flex; justify-content: space-between; align-items: baseline;
  font-size: var(--fs-13); color: var(--c-ink-700);
}
.mst__caja-fila b { font-family: var(--font-mono); color: var(--c-ink-900); }
.mst__caja-fila--total {
  border-top: 1px solid var(--c-leaf-300); padding-top: 9px;
  font-weight: 600; color: var(--c-ink-900);
}
.mst__dif-caja { margin: 0; font-size: var(--fs-13); font-weight: 600; font-family: var(--font-mono); }
.mst__dif-caja.is-ok  { color: var(--c-leaf-600); }
.mst__dif-caja.is-mal { color: var(--c-amber-500); }
.mst__retiro { margin: 0; font-size: var(--fs-13); color: var(--c-ink-700); }

.mst__fondo-hint {
  display: block; font-style: normal; font-weight: 400;
  font-size: var(--fs-12); color: var(--c-ink-500); margin-top: 2px;
}

@media (max-width: 640px) {
  .mst { padding: 16px 14px 40px; }
  .mst__draft-row { flex-wrap: wrap; }
  .mst__acciones--turno { flex-direction: column; align-items: stretch; }
}
</style>
