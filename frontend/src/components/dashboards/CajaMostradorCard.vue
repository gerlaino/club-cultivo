<template>
  <!-- ── Caja del turno ──────────────────────────────────────────────────────
       Lo primero de la jornada: sin caja abierta, el mostrador no arrancó. El admin la abre
       declarando el fondo y quien atiende confirma que ese fondo está — los dos pasos existen
       para que ninguno quede solo respondiendo por una diferencia de arqueo. -->
  <section v-if="sede" class="cjm" :class="`cjm--${estadoCaja}`">
    <div v-if="!colapsada" class="cjm-hd">
      <span class="cjm-title"><i class="bi bi-cash-stack"></i> Caja del turno</span>
      <span class="cjm-sede">{{ sede.nombre }}</span>
    </div>

    <!-- Renglón compacto: la caja está andando y no pide nada. Se toca para ver el arqueo. -->
    <button v-if="colapsada" type="button" class="cjm-mini" @click="expandido = true">
      <span class="cjm-mini-ok"><i class="bi bi-check-circle-fill"></i> En turno</span>
      <span class="cjm-mini-num">{{ fmtARS(caja.efectivo_esperado_ars) }} esperados</span>
      <i class="bi bi-chevron-down"></i>
    </button>

    <template v-else>
    <div v-if="cargandoCaja" class="cjm-msg">Cargando…</div>

    <!-- Sin caja: el mostrador no abrió -->
    <template v-else-if="!caja">
      <p class="cjm-msg">La caja todavía no se abrió.</p>
      <div v-if="puedeGestionarCaja" class="cjm-abrir">
        <label class="cjm-label">Fondo inicial</label>
        <div class="cjm-input-wrap">
          <span class="cjm-prefix">$</span>
          <input v-model.number="fondoInicial" type="number" min="0" step="1" class="cjm-input" placeholder="0" />
        </div>
        <button class="cjm-btn" :disabled="guardandoCaja" @click="abrirCaja">Abrir caja</button>
      </div>
      <p v-else class="cjm-hint">La abre administración con el fondo del día.</p>
    </template>

    <!-- Abierta y sin confirmar: le toca a quien atiende -->
    <template v-else-if="caja.estado === 'abierta' && !caja.apertura_confirmada">
      <p class="cjm-msg">
        {{ caja.abierta_por }} abrió con <strong>{{ fmtARS(caja.monto_inicial_ars) }}</strong> de fondo.
      </p>
      <button class="cjm-btn" :disabled="guardandoCaja" @click="confirmarApertura">
        Confirmo que está el fondo
      </button>
      <!-- Se abrió por error: mal monto, la sede que no era. Anular NO es cerrar — cerrar con $0
           contado generaría un faltante por todo el fondo, un egreso inventado en el libro. -->
      <button v-if="puedeGestionarCaja && caja.anulable" type="button" class="cjm-link" @click="anular">
        Se abrió por error, anularla
      </button>
    </template>

    <!-- En marcha -->
    <template v-else-if="caja.estado === 'abierta'">
      <div class="cjm-nums">
        <div><span class="cjm-n">{{ fmtARS(caja.monto_inicial_ars) }}</span><span class="cjm-l">fondo</span></div>
        <div><span class="cjm-n">{{ fmtARS(caja.total_efectivo_ars) }}</span><span class="cjm-l">efectivo cobrado</span></div>
        <div><span class="cjm-n">{{ fmtARS(caja.total_digital_ars) }}</span><span class="cjm-l">transferencias</span></div>
        <div><span class="cjm-n cjm-n--fuerte">{{ fmtARS(caja.efectivo_esperado_ars) }}</span><span class="cjm-l">esperado en caja</span></div>
      </div>
      <div v-if="caja.salidas?.length" class="cjm-salidas">
        <span class="cjm-salidas-t">Salidas del turno</span>
        <span v-for="sa in caja.salidas" :key="sa.id" class="cjm-salida">
          <span class="cjm-salida-tag" :class="`cjm-salida-tag--${sa.clase}`">{{ sa.clase }}</span>
          −{{ fmtARS(sa.monto_ars) }} · {{ sa.descripcion }}
          <template v-if="sa.quien"> · {{ sa.quien }}</template>
        </span>
      </div>

      <div class="cjm-cerrar">
        <label class="cjm-label">Efectivo contado</label>
        <div class="cjm-input-wrap">
          <span class="cjm-prefix">$</span>
          <input v-model.number="efectivoContado" type="number" min="0" step="1" class="cjm-input" placeholder="0" />
        </div>
        <button class="cjm-btn" :disabled="guardandoCaja || efectivoContado == null" @click="enviarCierre">
          Cerrar turno
        </button>
      </div>
      <!-- Con qué turno se corresponde y qué pasó. Va al cierre y queda en el historial: dentro
           de un mes, "faltaban $500" sin contexto no se puede revisar. -->
      <input v-model.trim="observaciones" type="text" class="cjm-input cjm-obs"
             placeholder="Observaciones — ej: turno mañana" />

      <button v-if="puedeGestionarCaja" type="button" class="cjm-link" @click="mostrarSalida = !mostrarSalida">
        {{ mostrarSalida ? 'Cancelar' : 'Sacar efectivo de la caja' }}
      </button>
      <div v-if="mostrarSalida && puedeGestionarCaja" class="cjm-salida-form">
        <!-- La distinción NO es cosmética: un retiro asentado como gasto infla los gastos y baja
             el resultado por plata que el club todavía tiene. -->
        <div class="cjm-clases">
          <label class="cjm-clase" :class="{ 'cjm-clase--on': salidaClase === 'retiro' }">
            <input type="radio" value="retiro" v-model="salidaClase" />
            <span><strong>Retiro</strong><small>Sale del cajón pero sigue siendo del club</small></span>
          </label>
          <label class="cjm-clase" :class="{ 'cjm-clase--on': salidaClase === 'gasto' }">
            <input type="radio" value="gasto" v-model="salidaClase" />
            <span><strong>Gasto</strong><small>Se gastó: baja el resultado</small></span>
          </label>
        </div>
        <div class="cjm-cerrar">
          <div class="cjm-input-wrap">
            <span class="cjm-prefix">$</span>
            <input v-model.number="salidaMonto" type="number" min="0" step="1" class="cjm-input" placeholder="0" />
          </div>
          <input v-model.trim="salidaMotivo" type="text" class="cjm-input"
                 :placeholder="salidaClase === 'retiro' ? 'Quién se la lleva' : 'En qué se gastó'" />
          <button class="cjm-btn" :disabled="guardandoCaja" @click="sacarEfectivo">Registrar</button>
        </div>
      </div>
    </template>

    <!-- Cierre enviado, esperando confirmación -->
    <template v-else>
      <p class="cjm-msg">
        {{ caja.cierre_solicitado_por }} envió el cierre con <strong>{{ fmtARS(caja.efectivo_declarado_ars) }}</strong>.
        <span v-if="caja.diferencia_ars" :class="caja.diferencia_ars < 0 ? 'cjm-falta' : 'cjm-sobra'">
          {{ caja.diferencia_ars < 0 ? 'Faltan' : 'Sobran' }} {{ fmtARS(Math.abs(caja.diferencia_ars)) }}.
        </span>
        <span v-else>Cuadra exacto.</span>
      </p>
      <template v-if="puedeGestionarCaja">
        <!-- El motivo de la diferencia va al ASIENTO contable, no sólo al historial. -->
        <input v-model.trim="observaciones" type="text" class="cjm-input cjm-obs"
               :placeholder="caja.diferencia_ars ? 'A qué se debió la diferencia' : 'Observaciones (opcional)'" />
        <button class="cjm-btn" :disabled="guardandoCaja" @click="confirmarCierre">Confirmar cierre</button>
      </template>
      <p v-else class="cjm-hint">Esperando que administración lo confirme.</p>
    </template>

    <p v-if="errorCaja" class="cjm-error">{{ errorCaja }}</p>
    </template>
  </section>
</template>

<script setup>
// La caja de turno del mostrador, como tarjeta.
//
// Vive en un componente y no copiada en dos dashboards a propósito: la usan el admin (que la
// ABRE con el fondo y confirma el cierre) y el dispensador (que confirma el fondo y envía el
// cierre), y son dos vistas del MISMO objeto. Duplicarla es la forma más segura de que dentro de
// dos meses una diga una cosa y la otra diga otra.
//
// El backend valida los permisos igual; `puedeGestionar` es sólo para no ofrecer un botón que va
// a rebotar.
import { ref, computed, watch, onMounted } from 'vue'
import {
  getCajaMostrador, abrirCajaMostrador, confirmarAperturaMostrador,
  solicitarCierreMostrador, confirmarCierreMostrador, anularCajaMostrador, salidaCajaMostrador,
} from '../../lib/api.js'
import { useToast } from '../../composables/useToast.js'

const props = defineProps({
  sede: { type: Object, default: null },          // { id, nombre }
  puedeGestionar: { type: Boolean, default: false },
  // En la pantalla de dispensar, con la caja YA andando, la tarjeta entera empuja el buscador
  // fuera de la vista — y buscar es lo primero que hace quien está de pie con alguien enfrente.
  // Andando se colapsa a un renglón; cuando pide acción (abrir, confirmar, cerrar) se abre sola.
  compacto: { type: Boolean, default: false },
})

const expandido = ref(false)
// El historial de turnos vive afuera (en la ficha de la sede) y tiene que enterarse cuando esta
// tarjeta cierra o anula: si no, el turno recién cerrado no aparece hasta recargar la página.
const emit = defineEmits(['cambio'])

const toast = useToast()
const caja            = ref(null)
const cargandoCaja    = ref(true)
const guardandoCaja   = ref(false)
const errorCaja       = ref(null)
const fondoInicial    = ref(null)
const efectivoContado = ref(null)
const observaciones   = ref('')
const mostrarSalida   = ref(false)
const salidaMonto     = ref(null)
const salidaMotivo    = ref('')
// Por defecto RETIRO: es el caso frecuente ("dame plata de la caja") y el que no debe tocar el
// resultado. Si el default fuera gasto, cada retiro mal marcado bajaría la ganancia del mes.
const salidaClase     = ref('retiro')

const sede = computed(() => props.sede)
const puedeGestionarCaja = computed(() => props.puedeGestionar)

// Sólo se colapsa si NO hay nada que hacer. Abrir, confirmar el fondo y confirmar el cierre son
// acciones: esas se muestran siempre, aunque la tarjeta esté en modo compacto.
const colapsada = computed(() =>
  props.compacto && !expandido.value && estadoCaja.value === 'andando')

const estadoCaja = computed(() => {
  if (!caja.value) return 'sin-abrir'
  if (caja.value.estado === 'pendiente_cierre') return 'pendiente'
  return caja.value.apertura_confirmada ? 'andando' : 'sin-confirmar'
})

async function cargarCaja() {
  if (!sede.value) { cargandoCaja.value = false; caja.value = null; return }
  cargandoCaja.value = true
  try {
    const { data } = await getCajaMostrador(sede.value.id)
    caja.value = data.caja
  } catch { caja.value = null }
  finally { cargandoCaja.value = false }
}

async function conCaja(fn, ok) {
  guardandoCaja.value = true
  errorCaja.value = null
  try {
    await fn()
    await cargarCaja()
    emit('cambio')
    toast.success(ok)
  } catch (e) {
    errorCaja.value = e?.response?.data?.error || e?.response?.data?.errors?.[0] || 'No se pudo'
  } finally { guardandoCaja.value = false }
}

const abrirCaja = () => conCaja(
  () => abrirCajaMostrador(sede.value.id, { monto_inicial_ars: Number(fondoInicial.value) || 0 }),
  'Caja abierta')

const confirmarApertura = () => conCaja(
  () => confirmarAperturaMostrador(sede.value.id, caja.value.id), 'Fondo confirmado')

const enviarCierre = () => conCaja(
  () => solicitarCierreMostrador(sede.value.id, caja.value.id, {
    efectivo_declarado_ars: Number(efectivoContado.value) || 0,
    notas: observaciones.value || undefined,
  }),
  'Cierre enviado')

const confirmarCierre = () => conCaja(
  () => confirmarCierreMostrador(sede.value.id, caja.value.id, { notas: observaciones.value || undefined }),
  'Caja cerrada')

const anular = () => conCaja(
  () => anularCajaMostrador(sede.value.id, caja.value.id, { motivo: observaciones.value || undefined }),
  'Caja anulada')

const sacarEfectivo = () => conCaja(
  () => salidaCajaMostrador(sede.value.id, caja.value.id, {
    monto_ars: Number(salidaMonto.value) || 0, motivo: salidaMotivo.value, clase: salidaClase.value,
  }),
  'Salida registrada').then(() => { mostrarSalida.value = false; salidaMonto.value = null; salidaMotivo.value = '' })

function fmtARS(n) { return '$' + (Number(n) || 0).toLocaleString('es-AR') }

// Cambiar de sede recarga: si no, el admin veía la caja de la sede anterior.
watch(() => props.sede?.id, cargarCaja)
onMounted(cargarCaja)

defineExpose({ caja, cargarCaja })
</script>

<style scoped>
/* ── Caja del turno ────────────────────────────────────────────────────────────
   Lo primero de la jornada, así que va arriba y con color de estado: sin abrir es neutro,
   esperando confirmación llama, en marcha se calla. */
.cjm { border: 1.5px solid var(--c-ink-200); border-radius: 14px; padding: var(--sp-4); background: #fff; margin-bottom: var(--sp-4); display: flex; flex-direction: column; gap: var(--sp-3); }
.cjm--sin-abrir    { border-color: var(--c-ink-300); }
.cjm--sin-confirmar { border-color: #f59e0b; background: #fffbeb; }
.cjm--pendiente    { border-color: #f59e0b; background: #fffbeb; }
.cjm--andando      { border-color: #86efac; }
.cjm-obs { width: 100%; }
.cjm-salida-form { display: flex; flex-direction: column; gap: var(--sp-2); border-top: 1px solid var(--c-ink-100); padding-top: var(--sp-2); }
.cjm-clases { display: flex; gap: var(--sp-2); flex-wrap: wrap; }
.cjm-clase { flex: 1 1 160px; display: flex; align-items: flex-start; gap: .4rem; border: 1.5px solid var(--c-ink-200); border-radius: 9px; padding: .4rem .6rem; cursor: pointer; }
.cjm-clase--on { border-color: #1b5e20; background: #f0fdf4; }
.cjm-clase span { display: flex; flex-direction: column; }
.cjm-clase strong { font-size: var(--fs-13); }
.cjm-clase small { font-size: var(--fs-11); color: var(--c-ink-500); line-height: 1.3; }
.cjm-salida-tag { font-size: 9.5px; font-weight: 700; text-transform: uppercase; letter-spacing: .04em; padding: 0 .3rem; border-radius: 4px; margin-right: .2rem; }
.cjm-salida-tag--retiro { background: #e0e7ff; color: #4338ca; }
.cjm-salida-tag--gasto { background: #fee2e2; color: #b91c1c; }
.cjm-link { background: none; border: none; padding: 0; cursor: pointer; font-size: var(--fs-12); color: var(--c-ink-500); text-decoration: underline; align-self: flex-start; }
.cjm-link:hover { color: #b91c1c; }
.cjm-salidas { display: flex; flex-direction: column; gap: .15rem; border-top: 1px solid var(--c-ink-100); padding-top: var(--sp-2); }
.cjm-salidas-t { font-size: var(--fs-11); font-weight: 700; text-transform: uppercase; letter-spacing: .04em; color: var(--c-ink-500); }
.cjm-salida { font-size: var(--fs-12); color: var(--c-ink-600); font-variant-numeric: tabular-nums; }
.cjm-mini { width: 100%; display: flex; align-items: center; gap: .5rem; background: none; border: none; padding: 0; cursor: pointer; font: inherit; color: var(--c-ink-600); }
.cjm-mini-ok { font-weight: 700; font-size: var(--fs-13); color: #15803d; display: flex; align-items: center; gap: .3rem; }
.cjm-mini-num { margin-left: auto; font-size: var(--fs-13); font-variant-numeric: tabular-nums; }
.cjm-hd { display: flex; align-items: center; justify-content: space-between; gap: var(--sp-2); }
.cjm-title { font-weight: 800; font-size: var(--fs-14); color: var(--c-ink-900); display: flex; align-items: center; gap: .4rem; }
.cjm-sede { font-size: var(--fs-12); color: var(--c-ink-500); }
.cjm-msg { margin: 0; font-size: var(--fs-13); color: var(--c-ink-700); }
.cjm-hint { margin: 0; font-size: var(--fs-12); color: var(--c-ink-500); }
.cjm-error { margin: 0; font-size: var(--fs-12); color: #b91c1c; }
.cjm-abrir, .cjm-cerrar { display: flex; align-items: flex-end; gap: var(--sp-2); flex-wrap: wrap; }
.cjm-label { font-size: var(--fs-12); font-weight: 700; color: var(--c-ink-600); display: block; margin-bottom: .2rem; }
.cjm-input-wrap { position: relative; display: flex; align-items: center; }
.cjm-prefix { position: absolute; left: .5rem; color: var(--c-ink-400); font-size: var(--fs-13); }
.cjm-input { padding: .4rem .6rem .4rem 1.3rem; border: 1.5px solid var(--c-ink-300); border-radius: 8px; font-size: var(--fs-14); width: 130px; font-variant-numeric: tabular-nums; }
.cjm-input:focus { outline: none; border-color: #1b5e20; }
.cjm-btn { background: #1b5e20; color: #fff; border: none; border-radius: 8px; padding: .45rem .9rem; font-size: var(--fs-13); font-weight: 700; cursor: pointer; }
.cjm-btn:disabled { opacity: .5; cursor: not-allowed; }
.cjm-nums { display: grid; grid-template-columns: repeat(auto-fit, minmax(130px, 1fr)); gap: var(--sp-3); }
.cjm-nums > div { display: flex; flex-direction: column; }
.cjm-n { font-size: var(--fs-16); font-weight: 700; color: var(--c-ink-800); font-variant-numeric: tabular-nums; }
.cjm-n--fuerte { color: #1b5e20; }
.cjm-l { font-size: var(--fs-11); color: var(--c-ink-500); }
.cjm-falta { color: #b91c1c; font-weight: 700; }
.cjm-sobra { color: #b45309; font-weight: 700; }
</style>
