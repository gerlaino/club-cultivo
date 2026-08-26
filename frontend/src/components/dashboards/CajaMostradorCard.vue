<template>
  <!-- ── Caja del turno ──────────────────────────────────────────────────────
       Lo primero de la jornada: sin caja abierta, el mostrador no arrancó. El admin la abre
       declarando el fondo y quien atiende confirma que ese fondo está — los dos pasos existen
       para que ninguno quede solo respondiendo por una diferencia de arqueo. -->
  <section v-if="sede" class="cjm" :class="`cjm--${estadoCaja}`">
    <div class="cjm-hd">
      <span class="cjm-title"><i class="bi bi-cash-stack"></i> Caja del turno</span>
      <span class="cjm-sede">{{ sede.nombre }}</span>
    </div>

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
    </template>

    <!-- En marcha -->
    <template v-else-if="caja.estado === 'abierta'">
      <div class="cjm-nums">
        <div><span class="cjm-n">{{ fmtARS(caja.monto_inicial_ars) }}</span><span class="cjm-l">fondo</span></div>
        <div><span class="cjm-n">{{ fmtARS(caja.total_efectivo_ars) }}</span><span class="cjm-l">efectivo cobrado</span></div>
        <div><span class="cjm-n">{{ fmtARS(caja.total_digital_ars) }}</span><span class="cjm-l">transferencias</span></div>
        <div><span class="cjm-n cjm-n--fuerte">{{ fmtARS(caja.efectivo_esperado_ars) }}</span><span class="cjm-l">esperado en caja</span></div>
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
      <button v-if="puedeGestionarCaja" class="cjm-btn" :disabled="guardandoCaja" @click="confirmarCierre">
        Confirmar cierre
      </button>
      <p v-else class="cjm-hint">Esperando que administración lo confirme.</p>
    </template>

    <p v-if="errorCaja" class="cjm-error">{{ errorCaja }}</p>
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
  solicitarCierreMostrador, confirmarCierreMostrador,
} from '../../lib/api.js'
import { useToast } from '../../composables/useToast.js'

const props = defineProps({
  sede: { type: Object, default: null },          // { id, nombre }
  puedeGestionar: { type: Boolean, default: false },
})

const toast = useToast()
const caja            = ref(null)
const cargandoCaja    = ref(true)
const guardandoCaja   = ref(false)
const errorCaja       = ref(null)
const fondoInicial    = ref(null)
const efectivoContado = ref(null)

const sede = computed(() => props.sede)
const puedeGestionarCaja = computed(() => props.puedeGestionar)

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
  () => solicitarCierreMostrador(sede.value.id, caja.value.id, { efectivo_declarado_ars: Number(efectivoContado.value) || 0 }),
  'Cierre enviado')

const confirmarCierre = () => conCaja(
  () => confirmarCierreMostrador(sede.value.id, caja.value.id), 'Caja cerrada')

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
