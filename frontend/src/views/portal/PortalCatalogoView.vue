<template>
  <div class="pcv">
    <PortalCabecera titulo="Reservar" bajada="Lo que hay hoy en el mostrador. Elegí qué querés retirar hoy o mañana y tu organización te lo confirma." />

    <!-- Sus pedidos: lo primero que busca después de pedir es si se lo confirmaron. -->
    <section v-if="pedidos.length" class="pcv__pedidos" aria-label="Mis pedidos">
      <h2 class="pcv__titulo">Mis pedidos</h2>
      <article v-for="r in pedidos" :key="r.id" class="pcv__pedido" :class="`pcv__pedido--${r.estado}`" data-testid="pedido">
        <div class="pcv__fila">
          <b>{{ ESTADO[r.estado] || r.estado }}</b>
          <span class="pcv__det">{{ cuando(r.fecha) }}{{ r.sede ? ` · ${r.sede}` : '' }}</span>
        </div>
        <span class="pcv__det">{{ r.items.map(i => `${fmtCant(i.cantidad)} ${i.unidad} de ${i.nombre}`).join(' · ') }}</span>
        <span v-if="r.total_estimado" class="pcv__det">Total estimado {{ pesos(r.total_estimado) }} · se paga al retirar</span>
        <p v-if="r.estado === 'rechazada' && r.motivo_rechazo" class="pcv__motivo">«{{ r.motivo_rechazo }}»</p>
        <button v-if="r.estado === 'solicitada'" type="button" class="pcv__link pcv__link--btn" :disabled="cancelando === r.id" @click="cancelar(r)">
          Cancelar el pedido
        </button>
      </article>
    </section>

    <div v-if="cargando" class="pcv__cargando"><DsSpinner :size="32" /></div>
    <PortalVacio v-else-if="!sedes.length" titulo="Hoy no hay nada publicado"
                 texto="Cuando tu organización tenga productos en el mostrador, los vas a ver acá." />

    <template v-else>
      <p v-if="repetidoDe" class="pcv__aviso pcv__aviso--ok" role="status" data-testid="repetir-aviso">{{ repetidoDe }}</p>

      <!-- Primero cuándo y dónde: es lo que decide qué puede pedir (28-oct-2026). -->
      <div v-if="puedePedir" class="pcv__paso">
        <span class="pcv__paso-t">¿Cuándo pasás?</span>
        <div class="pcv__retiro" role="radiogroup" aria-label="Cuándo lo retirás">
          <button v-for="f in fechasRetiro" :key="f.fecha" type="button" role="radio" class="pcv__seg"
                  :class="{ 'pcv__seg--on': fecha === f.fecha }" :aria-checked="fecha === f.fecha" :disabled="!f.libre"
                  :title="f.libre ? null : `Ya tenés una reserva para ${f.etiqueta.toLowerCase()}`" @click="fecha = f.fecha">{{ f.etiqueta }}</button>
        </div>
        <p v-if="diaOcupado" class="pcv__det">Para {{ diaOcupado.etiqueta.toLowerCase() }} ya tenés una reserva: es una por día.</p>
      </div>

      <div class="pcv__paso">
        <span class="pcv__paso-t">{{ sedes.length > 1 ? '¿Dónde?' : `En ${sede?.sede}` }}</span>
        <div v-if="sedes.length > 1" class="pcv__sedes" role="tablist" aria-label="Sede">
          <button v-for="s in sedes" :key="s.sede_id" type="button" role="tab" class="pcv__seg"
                  :class="{ 'pcv__seg--on': s.sede_id === sede?.sede_id }" :aria-selected="s.sede_id === sede?.sede_id" @click="elegirSede(s.sede_id)">{{ s.sede }}</button>
        </div>
      </div>

      <div v-if="formas.length > 1" class="pcv__formas" aria-label="Filtrar">
        <button v-for="f in ['Todo', ...formas]" :key="f" type="button" class="pcv__chip pcv__chip--chico"
                :class="{ 'pcv__chip--on': forma === f }" @click="forma = f">{{ f }}</button>
      </div>

      <p v-if="club?.reservar === false" class="pcv__aviso" data-testid="reservar-apagado">
        Tu organización no toma reservas desde el portal por ahora. Esto es lo que hay hoy: pasá por el mostrador.
      </p>
      <p v-else-if="!puedePedir" class="pcv__aviso" data-testid="sin-dias">
        Ya tenés una reserva para hoy y otra para mañana. Si cancelás una que todavía no confirmaron, podés pedir de nuevo para ese día.
      </p>

      <ul class="pcv__grilla">
        <li v-for="p in productos" :key="p.stock_id" class="pcv__card" :class="{ 'pcv__card--no': p.disponibilidad === 'no_hay', 'pcv__card--elegido': Number(carrito[p.stock_id]) > 0 }" data-testid="producto">
          <div class="pcv__cuerpo">
            <div class="pcv__fila">
              <b class="pcv__nombre">{{ p.nombre }}</b>
              <span class="pcv__disp" :class="`pcv__disp--${p.disponibilidad}`">{{ DISP[p.disponibilidad] }}</span>
            </div>
            <span class="pcv__det">{{ detalle(p) }}</span>
            <div class="pcv__fila pcv__fila--pie">
              <b v-if="p.precio">{{ pesos(p.precio) }} <span class="pcv__u">{{ p.unidad === 'g' ? 'el gramo' : 'c/u' }}</span></b>
              <RouterLink v-if="p.genetica?.id" :to="{ name: 'portal-genetica', params: { id: p.genetica.id } }" class="pcv__link">Ver la genética</RouterLink>
            </div>
            <div v-if="p.disponibilidad !== 'no_hay' && puedePedir" class="pcv__cant">
              <button type="button" class="pcv__mm" :aria-label="`Menos ${p.nombre}`" :disabled="!(Number(carrito[p.stock_id]) > 0)" @click="sumar(p, -1)">−</button>
              <label class="pcv__cant-in">
                <input type="number" inputmode="decimal" min="0" step="1" :value="carrito[p.stock_id] || ''"
                       :aria-label="`Cuánto de ${p.nombre}`" data-testid="cantidad" placeholder="0"
                       @input="poner(p.stock_id, $event.target.value)" />
                <span>{{ p.unidad === 'g' ? 'g' : 'u.' }}</span>
              </label>
              <button type="button" class="pcv__mm" :aria-label="`Más ${p.nombre}`" @click="sumar(p, 1)">+</button>
            </div>
          </div>
        </li>
      </ul>
      <p class="pcv__nota">Lo que hay puede cambiar durante el día. Se paga al retirar.</p>

      <!-- El pedido: de UNA sede, para hoy o mañana, una reserva por día (los días y cuál está libre
           los manda el backend). Fijo abajo, con un solo botón. -->
      <section v-if="puedePedir && lineas.length" class="pcv__resumen" aria-label="Tu pedido">
        <div class="pcv__fila">
          <span class="pcv__det">{{ diaElegido ? `${diaElegido.etiqueta} en ${sede.sede}` : sede.sede }} · {{ lineas.length }} producto{{ lineas.length === 1 ? '' : 's' }}</span>
          <b v-if="total" class="pcv__total">{{ pesos(total) }}</b>
        </div>
        <details class="pcv__mas">
          <summary>Agregar una nota</summary>
          <textarea v-model="notas" class="pcv__notas" rows="2" maxlength="500" placeholder="¿Algo que tengan que saber? (opcional)"></textarea>
        </details>
        <p v-if="error" class="pcv__error" role="alert">{{ error }}</p>
        <button type="button" class="pcv__pedir" :disabled="enviando || !fecha" data-testid="pedir" @click="pedir">
          {{ enviando ? 'Mandando…' : 'Pedir la reserva' }}
        </button>
      </section>
    </template>
  </div>
</template>

<script setup>
// «Reservar» del portal (28-oct-2026, Germán: el catálogo ES Reservar). Lo que hay HOY sobre la mesa
// de cada sede, con su precio y si hay (nunca la cantidad), y de ahí se pide: de UNA sede, para
// retirar hoy o mañana. El pedido queda esperando que administración lo confirme; no aparta nada
// hasta entonces. Una reserva por día (Germán, 28-oct-2026): los días que se ofrecen y cuál le
// queda libre los decide el backend.
import { computed, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { storeToRefs } from 'pinia'
import { getPortalCatalogo, getPortalReservas, pedirPortalReserva, cancelarPortalReserva, getPortalDispensa } from '@/lib/portalApi'
import { usePortalClubStore } from '@/stores/portalClub'
import { useRecargaEnCambios } from '@/composables/useRecargaEnCambios'
import { useConfirm } from '@/composables/useConfirm'
import { useToast } from '@/composables/useToast'
import PortalCabecera from '@/components/portal/PortalCabecera.vue'
import PortalVacio from '@/components/portal/PortalVacio.vue'
import DsSpinner from '@/design-system/components/Spinner.vue'

const DISP = { hay: 'Hay', pocos: 'Quedan pocos', no_hay: 'No hay hoy' }
const TIPOS = { indica: 'Índica', sativa: 'Sativa', hibrida: 'Híbrida', cbd: 'Rica en CBD' }
const ESTADO = {
  solicitada: 'Esperando confirmación', pendiente: 'Confirmada', entregada: 'Retirada',
  rechazada: 'No se pudo confirmar', cancelada: 'Cancelada', vencida: 'Venció sin confirmar',
}

const { confirm } = useConfirm()
const toast = useToast()
const route = useRoute()
const router = useRouter()
const { club } = storeToRefs(usePortalClubStore())

const sedes = ref([])
const cargando = ref(true)
const sedeId = ref(null)
const forma = ref('Todo')
const pedidos = ref([])
const fechasRetiro = ref([])
const carrito = ref({})
const fecha = ref(null)
const notas = ref('')
const enviando = ref(false)
const error = ref('')
const cancelando = ref(null)

const sede = computed(() => sedes.value.find((s) => s.sede_id === sedeId.value) || sedes.value[0])
const formas = computed(() => [...new Set((sede.value?.productos || []).map((p) => p.forma))])
const productos = computed(() => (sede.value?.productos || []).filter((p) => forma.value === 'Todo' || p.forma === forma.value))
const lineas = computed(() => (sede.value?.productos || [])
  .filter((p) => Number(carrito.value[p.stock_id]) > 0)
  .map((p) => ({ producto: p, cantidad: Number(carrito.value[p.stock_id]) })))
const diasLibres = computed(() => fechasRetiro.value.filter((f) => f.libre))
// Pide si la organización atiende Reservar y le queda un día libre.
const puedePedir = computed(() => club.value?.reservar !== false && diasLibres.value.length > 0)
const diaElegido = computed(() => fechasRetiro.value.find((f) => f.fecha === fecha.value) || null)
const repetidoDe = ref('')
const diaOcupado = computed(() => fechasRetiro.value.find((f) => !f.libre) || null)
const total = computed(() => lineas.value.reduce((s, l) => s + (l.producto.precio || 0) * l.cantidad, 0))

const pct = (n) => `${String(Number(n).toFixed(1)).replace('.', ',').replace(',0', '')}%`
const pesos = (n) => new Intl.NumberFormat('es-AR', { style: 'currency', currency: 'ARS', maximumFractionDigits: 0 }).format(n)
const fmtCant = (n) => String(n).replace('.', ',')
function detalle(p) {
  const g = p.genetica
  return [p.forma, g?.tipo && (TIPOS[g.tipo] || g.tipo), g?.thc ? `THC ${pct(g.thc)}` : null, g?.cbd ? `CBD ${pct(g.cbd)}` : null]
    .filter(Boolean).join(' · ')
}
function cuando(f) {
  const d = fechasRetiro.value.find((x) => x.fecha === f)
  if (d) return `Para ${d.etiqueta.toLowerCase()}`
  const [, m, dd] = String(f).split('-')
  return `Para el ${dd}/${m}`
}

function poner(stockId, valor) {
  const n = Number(String(valor).replace(',', '.'))
  carrito.value = { ...carrito.value, [stockId]: n > 0 ? n : 0 }
  error.value = ''
}
// Los botones − y +: de a 1 (gramos o unidades).
function sumar(p, paso) {
  const actual = Number(carrito.value[p.stock_id]) || 0
  poner(p.stock_id, Math.max(0, actual + paso))
}
// El pedido es de UNA sede: al cambiar de sede se empieza de cero.
function elegirSede(id) {
  if (id === sede.value?.sede_id) return
  sedeId.value = id
  carrito.value = {}
  error.value = ''
}

async function cargarPedidos() {
  try {
    const r = await getPortalReservas()
    pedidos.value = r.data || []
    fechasRetiro.value = r.fechas_retiro || []
    if (!diasLibres.value.some((f) => f.fecha === fecha.value)) fecha.value = diasLibres.value[0]?.fecha ?? null
  } catch { pedidos.value = []; fechasRetiro.value = [] }
}
async function cargarCatalogo() {
  try {
    sedes.value = await getPortalCatalogo()
    if (!sedes.value.some((s) => s.sede_id === sedeId.value)) sedeId.value = sedes.value[0]?.sede_id ?? null
  } catch { sedes.value = [] }
}

async function pedir() {
  if (!lineas.value.length || !fecha.value) return
  enviando.value = true
  error.value = ''
  try {
    await pedirPortalReserva({
      sede_id: sede.value.sede_id, fecha: fecha.value, notas: notas.value || undefined,
      items: lineas.value.map((l) => ({ stock_id: l.producto.stock_id, cantidad: l.cantidad })),
    })
    carrito.value = {}
    notas.value = ''
    toast.success('Listo: tu organización lo confirma y te avisamos por acá.')
    await Promise.all([cargarPedidos(), cargarCatalogo()])
  } catch (e) {
    error.value = e?.response?.data?.error || 'No se pudo mandar el pedido. Probá de nuevo.'
  } finally {
    enviando.value = false
  }
}

async function cancelar(r) {
  const ok = await confirm({ title: 'Cancelar el pedido', message: '¿Cancelás este pedido? Después podés hacer otro.', confirmText: 'Cancelar el pedido', cancelText: 'Volver' })
  if (!ok) return
  cancelando.value = r.id
  try {
    await cancelarPortalReserva(r.id)
    await cargarPedidos()
  } catch (e) {
    toast.error(e?.response?.data?.error || 'No se pudo cancelar.')
    await cargarPedidos()
  } finally {
    cancelando.value = null
  }
}

// Cuando administración confirma o rechaza, se entera sin recargar (llega por su canal).
useRecargaEnCambios('reservas', () => Promise.all([cargarPedidos(), cargarCatalogo()]))

// «Volver a pedir lo mismo» (28-oct-2026): desde una dispensa llega con `?repetir=<id>` y se
// precarga lo que se llevó, si hoy está en la mesa de alguna sede. Lo que no está, se dice.
async function repetir(id) {
  try {
    const d = await getPortalDispensa(id)
    const items = d?.items || []
    const sedeCon = (it) => sedes.value.find((s) => s.productos.some((p) => p.stock_id === it.stock_id && p.disponibilidad !== 'no_hay'))
      || sedes.value.find((s) => s.productos.some((p) => p.nombre === it.nombre && p.disponibilidad !== 'no_hay'))
    const destino = items.map(sedeCon).find(Boolean)
    if (!destino) { repetidoDe.value = 'Lo de esa dispensa hoy no está en el mostrador. Elegí de lo que hay.'; return }
    sedeId.value = destino.sede_id
    const nuevo = {}
    let faltan = 0
    for (const it of items) {
      const p = destino.productos.find((x) => x.stock_id === it.stock_id && x.disponibilidad !== 'no_hay')
        || destino.productos.find((x) => x.nombre === it.nombre && x.disponibilidad !== 'no_hay')
      if (p) nuevo[p.stock_id] = it.cantidad
      else faltan++
    }
    carrito.value = nuevo
    repetidoDe.value = faltan
      ? `Cargamos lo que hay hoy de tu dispensa (${faltan === 1 ? '1 cosa no está' : `${faltan} cosas no están`}). Revisá y pedí.`
      : 'Cargamos lo mismo que te llevaste. Revisá el día y pedí.'
  } catch {
    repetidoDe.value = ''
  } finally {
    router.replace({ query: { ...route.query, repetir: undefined } })
  }
}

onMounted(async () => {
  await Promise.all([cargarCatalogo(), cargarPedidos()])
  if (route.query.repetir) await repetir(route.query.repetir)
  cargando.value = false
})
</script>

<style scoped>
.pcv { max-width: var(--p-ancho, 680px); margin: 0 auto; padding: 1.5rem 1.25rem 3rem; }
@media (min-width: 900px) { .pcv { max-width: 1000px; } }
.pcv__cargando { display: flex; justify-content: center; padding: 3rem; }
.pcv__titulo { font-size: 1rem; margin: 0 0 .6rem; color: var(--p-tinta); }
.pcv__pedidos { margin-bottom: 1.4rem; display: flex; flex-direction: column; gap: .6rem; }
.pcv__pedido { background: var(--p-papel); border: 1px solid var(--p-linea); border-radius: var(--p-radio-sm); padding: .8rem .95rem; display: flex; flex-direction: column; gap: .3rem; }
.pcv__pedido--solicitada { background: color-mix(in srgb, var(--p-atencion-bg) 55%, var(--p-papel)); border-color: var(--p-atencion-bg); }
.pcv__pedido--pendiente { background: var(--p-hundido); border-color: var(--p-marca-linea); }
.pcv__pedido--rechazada, .pcv__pedido--vencida { background: var(--p-urgente-bg); border-color: var(--p-urgente-bg); }
.pcv__motivo { margin: 0; font-size: .9rem; color: var(--p-tinta); }

.pcv__paso { display: flex; flex-direction: column; gap: .45rem; margin-bottom: 1rem; }
.pcv__paso-t { font-size: .85rem; font-weight: 700; color: var(--p-suave); }
.pcv__retiro, .pcv__sedes { display: flex; gap: .5rem; flex-wrap: wrap; }
.pcv__seg { flex: 1 1 0; min-width: 110px; min-height: 48px; padding: 0 1rem; border-radius: 12px; border: 1.5px solid var(--p-marca-linea);
  background: var(--p-papel); color: var(--p-tinta); font: inherit; font-size: .98rem; font-weight: 600; cursor: pointer; }
.pcv__seg--on { background: var(--p-marca-fuerte); border-color: var(--p-marca-fuerte); color: var(--p-papel); }
.pcv__seg:disabled { background: var(--p-hundido); border-color: var(--p-hundido); color: var(--p-tenue); cursor: not-allowed; text-decoration: line-through; }

.pcv__formas { display: flex; gap: .45rem; flex-wrap: wrap; margin-bottom: .8rem; }
.pcv__chip { min-height: 38px; padding: 0 1rem; border-radius: 999px; border: 1px solid var(--p-linea); background: var(--p-papel); color: var(--p-tinta); font: inherit; font-weight: 600; cursor: pointer; }
.pcv__chip--chico { min-height: 34px; font-size: .88rem; }
.pcv__chip--on { background: var(--p-marca); border-color: var(--p-marca); color: var(--p-papel); }

.pcv__grilla { list-style: none; margin: 0; padding: 0; display: grid; grid-template-columns: repeat(auto-fill, minmax(260px, 1fr)); gap: .75rem; }
.pcv__card { background: var(--p-papel); border: 1.5px solid var(--p-linea); border-radius: var(--p-radio-sm); display: flex; flex-direction: column; }
.pcv__card--no { opacity: .65; }
.pcv__card--elegido { border-color: var(--p-marca); }
.pcv__cuerpo { padding: .9rem 1rem; display: flex; flex-direction: column; gap: .35rem; flex: 1; }
.pcv__fila { display: flex; justify-content: space-between; align-items: baseline; gap: .5rem; }
.pcv__fila--pie { margin-top: auto; }
.pcv__nombre { color: var(--p-tinta); font-size: 1.02rem; }
.pcv__det { font-size: .85rem; color: var(--p-suave); }
.pcv__u { font-weight: 400; font-size: .8rem; color: var(--p-suave); }
.pcv__disp { font-size: .75rem; font-weight: 700; white-space: nowrap; }
.pcv__disp--hay { color: var(--p-ok); }
.pcv__disp--pocos { color: var(--p-atencion); }
.pcv__disp--no_hay { color: var(--p-urgente); }
.pcv__link { font-size: .85rem; font-weight: 700; color: var(--p-marca); text-decoration: none; }
.pcv__link--btn { align-self: flex-start; background: none; border: 0; padding: 0; cursor: pointer; font: inherit; font-size: .85rem; font-weight: 700; min-height: 32px; }

.pcv__cant { display: flex; align-items: center; justify-content: flex-end; gap: .4rem; margin-top: .5rem; }
.pcv__mm { width: 44px; height: 44px; border-radius: 12px; border: 1.5px solid var(--p-marca-linea); background: var(--p-papel); color: var(--p-marca-fuerte);
  font: inherit; font-size: 1.35rem; line-height: 1; cursor: pointer; }
.pcv__mm:disabled { opacity: .4; cursor: default; }
.pcv__cant-in { display: inline-flex; align-items: center; gap: .25rem; font-size: .9rem; color: var(--p-suave); }
.pcv__cant-in input { width: 64px; min-height: 44px; padding: 0 .4rem; border: 1.5px solid var(--p-linea); border-radius: 12px; background: var(--p-papel);
  color: var(--p-tinta); font: inherit; font-size: 1.05rem; font-weight: 700; text-align: center; -moz-appearance: textfield; }
.pcv__cant-in input::-webkit-outer-spin-button, .pcv__cant-in input::-webkit-inner-spin-button { -webkit-appearance: none; margin: 0; }

.pcv__nota { margin-top: 1rem; font-size: .82rem; color: var(--p-suave); }
.pcv__aviso { margin: 0 0 1rem; padding: .8rem .9rem; border-radius: var(--p-radio-sm); border: 1px solid var(--p-linea); background: var(--p-papel); color: var(--p-tinta); font-size: .9rem; }
.pcv__aviso--ok { background: var(--p-hundido); border-color: var(--p-marca-linea); }

/* Pegado abajo: por encima de la barra del teléfono, y en la compu por encima del botón del chat. */
.pcv__resumen { position: sticky; bottom: 4.75rem; margin-top: 1rem; padding: .9rem 1rem; background: var(--p-papel); border: 1px solid var(--p-marca-linea);
  border-radius: var(--p-radio-sm); display: flex; flex-direction: column; gap: .6rem; box-shadow: 0 10px 30px -18px rgb(0 0 0 / .45); }
@media (max-width: 859px) { .pcv__resumen { bottom: calc(76px + env(safe-area-inset-bottom)); } }
.pcv__total { font-size: 1.15rem; }
.pcv__mas summary { cursor: pointer; font-size: .85rem; color: var(--p-marca); font-weight: 600; min-height: 28px; }
.pcv__notas { width: 100%; margin-top: .4rem; padding: .55rem .7rem; border: 1px solid var(--p-linea); border-radius: var(--p-radio-sm); background: var(--p-papel); color: var(--p-tinta); font: inherit; resize: vertical; box-sizing: border-box; }
.pcv__error { margin: 0; color: var(--p-urgente); font-size: .9rem; }
.pcv__pedir { min-height: 52px; border: 0; border-radius: 14px; background: var(--p-marca-fuerte); color: var(--p-papel); font: inherit; font-size: 1.02rem; font-weight: 700; cursor: pointer; }
.pcv__pedir:disabled { opacity: .6; cursor: default; }
</style>
