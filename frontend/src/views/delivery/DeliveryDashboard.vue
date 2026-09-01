<script setup>
import { ref, computed, onMounted, nextTick, watch } from 'vue'
import DsSpinner from '../../design-system/components/Spinner.vue'
import { Package, Bike, CheckCircle2, XCircle, MapPin, Phone, User, FileText, ChevronRight, ChevronDown, Send, Route, Navigation, PenLine, Trash2, Lock, Check } from 'lucide-vue-next'
import { getMisPaquetes, iniciarViaje, ordenarRuta } from '../../lib/api.js'
import RendicionCajaCard from '../../components/RendicionCajaCard.vue'
import { useEntregasOffline } from '../../composables/useEntregasOffline.js'
import { useToast } from '../../composables/useToast.js'
import { useAuthStore } from '../../stores/auth.js'

const toast    = useToast()
// Cola offline: la entrega se guarda en el dispositivo si no hay señal y se manda sola después.
const { pendientes: entregasPendientes, entregarConReintento, fallaConReintento } = useEntregasOffline()
const auth     = useAuthStore()
const paquetes = ref([])
const loading  = ref(true)

// multi-select para iniciar viaje
const selected = ref(new Set())

// modals
const modalEntregar = ref(null)  // dispensacion object
const modalFallo    = ref(null)  // dispensacion object
const notasEntrega  = ref('')
const motivoFallo   = ref('')
const saving        = ref(false)

// cobro en la entrega
const cobroEfectivo   = ref(null)
const cobroTransf     = ref(null)
const comprobanteFile = ref(null)         // comprobante de pago
const comprobantePreview = ref(null)
const comprobanteEntregaFile = ref(null)  // comprobante de entrega
const comprobanteEntregaPreview = ref(null)

function setComprobante(e) {
  const f = e.target.files?.[0] || null
  if (comprobantePreview.value) URL.revokeObjectURL(comprobantePreview.value)
  comprobanteFile.value = f
  comprobantePreview.value = f ? URL.createObjectURL(f) : null
}
function clearComprobante() {
  if (comprobantePreview.value) URL.revokeObjectURL(comprobantePreview.value)
  comprobanteFile.value = null
  comprobantePreview.value = null
}
function setComprobanteEntrega(e) {
  const f = e.target.files?.[0] || null
  if (comprobanteEntregaPreview.value) URL.revokeObjectURL(comprobanteEntregaPreview.value)
  comprobanteEntregaFile.value = f
  comprobanteEntregaPreview.value = f ? URL.createObjectURL(f) : null
}
function clearComprobanteEntrega() {
  if (comprobanteEntregaPreview.value) URL.revokeObjectURL(comprobanteEntregaPreview.value)
  comprobanteEntregaFile.value = null
  comprobanteEntregaPreview.value = null
}

// firma digital
const canvasRef      = ref(null)
const firmaActiva    = ref(false)
const firmaData      = ref(null)
let   ctx            = null
let   dibujando      = false

watch(modalEntregar, async (val) => {
  if (val) {
    firmaActiva.value = false
    firmaData.value   = null
    await nextTick()
  }
})

function iniciarCanvas() {
  firmaActiva.value = true
  nextTick(() => {
    const canvas = canvasRef.value
    if (!canvas) return
    // Igualar la resolución interna al tamaño REAL mostrado (× devicePixelRatio).
    // Si no, en mobile la firma queda corrida/escalada (el bug que tenías).
    const rect = canvas.getBoundingClientRect()
    const dpr  = window.devicePixelRatio || 1
    canvas.width  = Math.round(rect.width  * dpr)
    canvas.height = Math.round(rect.height * dpr)
    ctx = canvas.getContext('2d')
    ctx.scale(dpr, dpr)  // dibujamos en coordenadas CSS, mapea 1:1 con el dedo
    ctx.strokeStyle = '#111827'
    ctx.lineWidth   = 2.5
    ctx.lineCap     = 'round'
    ctx.lineJoin    = 'round'
    canvas.addEventListener('mousedown',  startDraw)
    canvas.addEventListener('mousemove',  draw)
    canvas.addEventListener('mouseup',    endDraw)
    canvas.addEventListener('mouseleave', endDraw)
    canvas.addEventListener('touchstart', startDrawT, { passive: false })
    canvas.addEventListener('touchmove',  drawT,      { passive: false })
    canvas.addEventListener('touchend',   endDraw)
  })
}

function startDraw(e)  { dibujando = true; ctx.beginPath(); ctx.moveTo(e.offsetX, e.offsetY) }
function draw(e)       { if (!dibujando) return; ctx.lineTo(e.offsetX, e.offsetY); ctx.stroke() }
function endDraw()     { dibujando = false; firmaData.value = canvasRef.value?.toDataURL('image/png') }

function startDrawT(e) { e.preventDefault(); const t = e.touches[0]; const r = canvasRef.value.getBoundingClientRect(); startDraw({ offsetX: t.clientX - r.left, offsetY: t.clientY - r.top }) }
function drawT(e)      { e.preventDefault(); const t = e.touches[0]; const r = canvasRef.value.getBoundingClientRect(); draw({ offsetX: t.clientX - r.left, offsetY: t.clientY - r.top }) }

function borrarFirma() {
  if (!ctx || !canvasRef.value) return
  ctx.save()
  ctx.setTransform(1, 0, 0, 1, 0, 0)  // limpiar en coordenadas del canvas, no escaladas
  ctx.clearRect(0, 0, canvasRef.value.width, canvasRef.value.height)
  ctx.restore()
  firmaData.value = null
}

// Google Maps route — abre Maps con todas las direcciones en viaje como waypoints
function verRutaEnMaps() {
  const dirs = enViaje.value.map(p => p.direccion_envio).filter(Boolean)
  if (!dirs.length) return
  const base     = 'https://www.google.com/maps/dir/'
  const waypoints = dirs.map(d => encodeURIComponent(d)).join('/')
  window.open(base + waypoints, '_blank', 'noopener')
}

const rutaBloqueada = computed(() => paquetes.value.some(p => p.ruta_bloqueada))
const pendientes = computed(() => paquetes.value.filter(p => p.estado_envio === 'pendiente'))
const enViaje    = computed(() => paquetes.value.filter(p => p.estado_envio === 'en_viaje'))
const fallidos   = computed(() => paquetes.value.filter(p => p.estado_envio === 'fallido'))
const activos    = computed(() => [...pendientes.value, ...enViaje.value])

// La próxima parada: el primero de los que ya está llevando, respetando el orden de la ruta.
// Es lo único que el repartidor necesita ver mientras maneja.
const siguienteParada = computed(() =>
  [...enViaje.value].sort((a, b) => (a.orden_entrega ?? 999) - (b.orden_entrega ?? 999))[0] || null)

const todosSeleccionados = computed(() =>
  pendientes.value.length > 0 && pendientes.value.every(p => selected.value.has(p.id))
)

// ── Secciones plegables ────────────────────────────────────────────────────
// Con 15 paquetes las tres listas encadenadas son un scroll de varias pantallas, y el
// delivery trabaja siempre desde el celular, con una mano y a veces en la calle. Cada
// sección se pliega y la elección se recuerda: si siempre cierra "No entregados", no tiene
// que volver a cerrarla en cada viaje.
//
// Las tres arrancan ABIERTAS. Los fallidos los había dejado cerrados por defecto —el
// repartidor no puede resolverlos, los reprograma el admin— pero esconder algo que acaba de
// pasar se lee como que no se registró: reportás un fallo, volvés a la pantalla y no lo ves.
// Que se pliegue es una decisión del que mira, no un default.
const PLEGADAS_KEY = 'dlv_secciones_plegadas'
const abiertas = ref({ pendientes: true, enviaje: true, fallidos: true })

try {
  const guardado = JSON.parse(localStorage.getItem(PLEGADAS_KEY) || 'null')
  if (guardado && typeof guardado === 'object') abiertas.value = { ...abiertas.value, ...guardado }
} catch {}

function toggleSeccion(clave) {
  abiertas.value[clave] = !abiertas.value[clave]
  try { localStorage.setItem(PLEGADAS_KEY, JSON.stringify(abiertas.value)) } catch {}
}

function toggleSelect(id) {
  const s = new Set(selected.value)
  s.has(id) ? s.delete(id) : s.add(id)
  selected.value = s
}

function toggleTodos() {
  if (todosSeleccionados.value) {
    selected.value = new Set()
  } else {
    selected.value = new Set(pendientes.value.map(p => p.id))
  }
}

// ── Reordenar (solo si la ruta NO está fijada por la organización) ──────────────────
const guardandoOrden = ref(false)
async function persistirOrdenDelivery(lista) {
  guardandoOrden.value = true
  try {
    const { data } = await ordenarRuta({
      delivery_id: auth.user?.id,
      fecha:       new Date().toISOString().slice(0, 10),
      orden:       lista.map(p => p.id),
    })
    lista.forEach((p, i) => { p.orden_entrega = i + 1 })
    if (data?.bloqueada !== undefined) lista.forEach(p => { p.ruta_bloqueada = data.bloqueada })
    // reordenar el array fuente para reflejar el nuevo orden
    paquetes.value = [...paquetes.value].sort((a, b) =>
      (a.orden_entrega ?? Infinity) - (b.orden_entrega ?? Infinity))
  } catch (e) {
    toast.error(e?.response?.data?.error || 'No se pudo guardar el orden')
  } finally { guardandoOrden.value = false }
}
function moverArriba(p) {
  if (rutaBloqueada.value) return
  const lista = [...pendientes.value]
  const i = lista.findIndex(x => x.id === p.id)
  if (i <= 0) return
  ;[lista[i - 1], lista[i]] = [lista[i], lista[i - 1]]
  persistirOrdenDelivery(lista)
}
function moverAbajo(p) {
  if (rutaBloqueada.value) return
  const lista = [...pendientes.value]
  const i = lista.findIndex(x => x.id === p.id)
  if (i === -1 || i >= lista.length - 1) return
  ;[lista[i + 1], lista[i]] = [lista[i], lista[i + 1]]
  persistirOrdenDelivery(lista)
}

// Navegar a UNA parada (Maps con un solo destino).
function irAParada(p) {
  if (!p.direccion_envio) { toast.error('Sin dirección'); return }
  const url = `https://www.google.com/maps/dir/?api=1&travelmode=driving&destination=${encodeURIComponent(p.direccion_envio)}`
  window.open(url, '_blank', 'noopener')
}

// ── Ruta en Google Maps (según seleccionados, o todos los pendientes en orden) ──
function abrirEnMaps() {
  const base = selected.value.size
    ? pendientes.value.filter(p => selected.value.has(p.id))
    : pendientes.value
  const dirs = base.map(p => p.direccion_envio).filter(Boolean)
  if (!dirs.length) { toast.error('No hay direcciones para armar la ruta'); return }
  // origin = ubicación actual (se omite); waypoints intermedios + destino final.
  const destino   = encodeURIComponent(dirs[dirs.length - 1])
  const waypoints = dirs.slice(0, -1).map(encodeURIComponent).join('|')
  let url = `https://www.google.com/maps/dir/?api=1&travelmode=driving&destination=${destino}`
  if (waypoints) url += `&waypoints=${waypoints}`
  window.open(url, '_blank', 'noopener')
}

async function load() {
  loading.value = true
  try {
    const { data } = await getMisPaquetes()
    paquetes.value = data.dispensaciones || []
  } catch { toast.error('Error al cargar paquetes') }
  finally { loading.value = false }
}

async function handleIniciarViaje() {
  if (!selected.value.size) return
  saving.value = true
  try {
    await iniciarViaje([...selected.value])
    selected.value = new Set()
    await load()
    toast.success('Paquetes marcados como en camino')
  } catch { toast.error('Error al iniciar viaje') }
  finally { saving.value = false }
}

function abrirEntregar(p) {
  modalEntregar.value = p
  notasEntrega.value  = ''
  cobroEfectivo.value = null
  cobroTransf.value   = null
  clearComprobante()
  clearComprobanteEntrega()
}

const r2 = (n) => Math.round((Number(n) || 0) * 100) / 100
const fmtMoneda = (n) => '$' + (Number(n) || 0).toLocaleString('es-AR', { minimumFractionDigits: 0, maximumFractionDigits: 2 })
const saldoACobrar = computed(() => r2(modalEntregar.value?.saldo_pendiente || 0))
const cobradoEntrega = computed(() => r2((Number(cobroEfectivo.value) || 0) + (Number(cobroTransf.value) || 0)))
const restoEntregaCuenta = computed(() => r2(Math.max(0, saldoACobrar.value - cobradoEntrega.value)))
const excedenteEntrega = computed(() => r2(Math.max(0, cobradoEntrega.value - saldoACobrar.value)))
// El sobrepago no se bloquea: si el socio tiene cuenta, queda a favor; si no, el
// backend lo rechaza con un mensaje claro (el delivery no es quien lo determina).
const entregaCobroValido = computed(() => true)

function lineasCobroEntrega() {
  const ls = []
  if ((Number(cobroEfectivo.value) || 0) > 0) ls.push({ medio: 'efectivo', monto: r2(cobroEfectivo.value) })
  if ((Number(cobroTransf.value) || 0) > 0)   ls.push({ medio: 'transferencia', monto: r2(cobroTransf.value) })
  return ls
}

function abrirFallo(p) {
  modalFallo.value = p
  motivoFallo.value = ''
}

let entregaEncolada = false
async function confirmarEntrega() {
  saving.value = true
  entregaEncolada = false
  try {
    // Con reintento: el repartidor entrega en sótanos y ascensores. Si el POST falla por red, la
    // entrega —con su firma— queda guardada en el dispositivo y se manda sola al volver la señal.
    // Volver a pedir la firma no es opción: la persona ya se fue.
    const res = await entregarConReintento(modalEntregar.value.id, {
      notasEntrega:       notasEntrega.value,
      firmaData:          firmaData.value,
      cobros:             lineasCobroEntrega(),
      comprobante:        comprobanteFile.value,
      comprobanteEntrega: comprobanteEntregaFile.value,
    })
    entregaEncolada = res.encolado
    modalEntregar.value = null
    firmaData.value     = null
    firmaActiva.value   = false
    clearComprobante()
    clearComprobanteEntrega()
    await load()
    if (entregaEncolada) toast.warning('Entrega guardada sin señal — se envía sola al recuperar conexión')
    else                 toast.success('Entrega registrada')
  } catch (e) {
    toast.error(e?.response?.data?.error || e?.response?.data?.errors?.[0] || 'Error al registrar entrega')
  }
  finally { saving.value = false }
}

async function confirmarFallo() {
  if (!motivoFallo.value.trim()) {
    toast.error('El motivo es requerido')
    return
  }
  saving.value = true
  try {
    const res = await fallaConReintento(modalFallo.value.id, motivoFallo.value.trim())
    modalFallo.value = null
    await load()
    if (res.encolado) toast.warning('Guardado sin señal — se envía solo al recuperar conexión')
    else              toast.success('Problema reportado')
  } catch { toast.error('Error al reportar') }
  finally { saving.value = false }
}

const fmtFecha = (d) => d
  ? new Date(d + 'T00:00:00').toLocaleDateString('es-AR', { weekday: 'short', day: 'numeric', month: 'short' })
  : '—'

onMounted(load)
</script>

<template>
  <div class="dlv">

    <!-- La entrega de lo que cobró: la arranca él y elige a quién. -->
    <RendicionCajaCard />

    <!-- Entregas guardadas sin señal. Se muestra para que el repartidor SEPA que algo todavía no
         llegó al servidor: en silencio parecería que se perdió. -->
    <div v-if="entregasPendientes.length" class="dlv__offline">
      <i class="bi bi-cloud-arrow-up"></i>
      <span>
        {{ entregasPendientes.length }}
        {{ entregasPendientes.length === 1 ? 'entrega guardada' : 'entregas guardadas' }}
        sin señal · se envían solas
      </span>
    </div>

    <!-- Header -->
    <div class="dlv__header">
      <div class="dlv__header-left">
        <Bike :size="22" :stroke-width="1.75" />
        <div>
          <div class="dlv__title">Mis paquetes</div>
          <div class="dlv__sub">{{ activos.length }} activos</div>
        </div>
      </div>
      <button v-if="enViaje.length" class="dlv__btn-ruta" @click="verRutaEnMaps">
        <Route :size="15" :stroke-width="2" /> Ver ruta en Maps ({{ enViaje.length }})
      </button>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="dlv__loading">
      <DsSpinner />
    </div>

    <template v-else>

      <!-- LO QUE HAY QUE HACER AHORA.
           Un repartidor mira esto parado en la vereda con una caja en la mano: necesita saber
           a dónde va, no leer tres secciones con checkboxes. El resto de la pantalla queda
           abajo para consultar; acá arriba hay UNA cosa a la vez. -->
      <div v-if="siguienteParada" class="dlv__foco">
        <div class="dlv__foco-tag">Tu próxima entrega</div>
        <div class="dlv__foco-nombre">{{ siguienteParada.paciente?.nombre || 'Paciente' }}</div>
        <div class="dlv__foco-dir">{{ siguienteParada.direccion_envio || 'Sin dirección cargada' }}</div>
        <div class="dlv__foco-acts">
          <button class="dlv__foco-btn dlv__foco-btn--nav" @click="irAParada(siguienteParada)">
            <Route :size="16" :stroke-width="2" /> Cómo llegar
          </button>
          <button class="dlv__foco-btn dlv__foco-btn--ok" @click="abrirEntregar(siguienteParada)">
            <Check :size="16" :stroke-width="2.5" /> Entregué
          </button>
          <button class="dlv__foco-btn dlv__foco-btn--no" @click="abrirFallo(siguienteParada)">
            No pude
          </button>
        </div>
        <p v-if="enViaje.length > 1" class="dlv__foco-resto">
          Te quedan {{ enViaje.length - 1 }} más en este viaje.
        </p>
      </div>

      <!-- Todavía no salió: lo único que importa es arrancar. -->
      <div v-else-if="pendientes.length" class="dlv__foco dlv__foco--salir">
        <div class="dlv__foco-tag">Listo para salir</div>
        <div class="dlv__foco-nombre">
          {{ pendientes.length }} paquete{{ pendientes.length === 1 ? '' : 's' }} para llevar
        </div>
        <div class="dlv__foco-dir">Elegí cuáles cargás y arrancá. Los que dejes quedan para después.</div>
        <div class="dlv__foco-acts">
          <button class="dlv__foco-btn dlv__foco-btn--ok" :disabled="!selected.size || saving" @click="handleIniciarViaje">
            <Bike :size="16" :stroke-width="2" />
            Salir a repartir{{ selected.size ? ` (${selected.size})` : '' }}
          </button>
        </div>
        <p v-if="!selected.size" class="dlv__foco-resto">Marcá abajo los que llevás.</p>
      </div>

      <!-- Nada que hacer: que se note, en vez de dejar una pantalla con listas vacías. -->
      <div v-else class="dlv__foco dlv__foco--vacio">
        <div class="dlv__foco-nombre">No tenés entregas pendientes</div>
        <div class="dlv__foco-dir">Cuando la organización te asigne un paquete, aparece acá.</div>
      </div>


      <!-- Stats rápidos -->
      <div class="dlv__stats">
        <div class="dlv__stat">
          <span class="dlv__stat-n dlv__stat-n--blue">{{ pendientes.length }}</span>
          <span class="dlv__stat-l">Pendientes</span>
        </div>
        <div class="dlv__stat">
          <span class="dlv__stat-n dlv__stat-n--orange">{{ enViaje.length }}</span>
          <span class="dlv__stat-l">En camino</span>
        </div>
        <div class="dlv__stat">
          <span class="dlv__stat-n dlv__stat-n--green">{{ paquetes.filter(p => p.estado_envio === 'entregado').length }}</span>
          <span class="dlv__stat-l">Entregados</span>
        </div>
        <div v-if="fallidos.length" class="dlv__stat dlv__stat--alert">
          <span class="dlv__stat-n dlv__stat-n--red">{{ fallidos.length }}</span>
          <span class="dlv__stat-l">Fallidos</span>
        </div>
      </div>

      <!-- Barra "iniciar viaje" -->
      <div v-if="pendientes.length" class="dlv__toolbar">
        <label class="dlv__check-all">
          <input type="checkbox" :checked="todosSeleccionados" @change="toggleTodos" />
          <span>{{ todosSeleccionados ? 'Deseleccionar todos' : 'Seleccionar pendientes' }}</span>
        </label>
        <button
          class="dlv__btn-maps"
          :disabled="!pendientes.length"
          :title="selected.size ? 'Ruta en Maps con los seleccionados' : 'Ruta en Maps con todos los pendientes'"
          @click="abrirEnMaps"
        >
          <Route :size="14" :stroke-width="2" />
          Ruta en Maps
        </button>
        <button
          class="dlv__btn-viaje"
          :disabled="!selected.size || saving"
          @click="handleIniciarViaje"
        >
          <Send :size="14" :stroke-width="2" />
          Iniciar viaje ({{ selected.size }})
        </button>
      </div>

      <!-- Sin activos -->
      <div v-if="!activos.length" class="dlv__empty">
        <Package :size="40" :stroke-width="1.25" />
        <div class="dlv__empty-title">Sin paquetes activos</div>
        <div class="dlv__empty-sub">Cuando te asignen dispensaciones aparecerán acá</div>
      </div>

      <!-- Aviso de orden fijado por la organización -->
      <div v-if="rutaBloqueada" class="dlv__ruta-fija">
        <i class="bi bi-lock-fill"></i>
        La organización fijó el <strong>orden de entrega</strong> — respetá la secuencia (número a la izquierda de cada paquete).
      </div>

      <!-- Pendientes -->
      <div v-if="pendientes.length" class="dlv__section">
        <button
          class="dlv__section-head"
          :aria-expanded="abiertas.pendientes"
          @click="toggleSeccion('pendientes')"
        >
          <ChevronDown class="dlv__section-caret" :class="{ 'dlv__section-caret--cerrado': !abiertas.pendientes }" :size="14" :stroke-width="2.5" />
          <span class="dlv__section-title">Pendientes de retirar</span>
          <span class="dlv__section-count">{{ pendientes.length }}</span>
        </button>
        <div v-show="abiertas.pendientes" class="dlv__list">
          <div
            v-for="(p, i) in pendientes" :key="p.id"
            class="dlv__row dlv__row--pendiente"
            :class="{ 'dlv__row--selected': selected.has(p.id), 'dlv__row--siguiente': i === 0 }"
          >
            <input
              type="checkbox"
              class="dlv__check"
              :checked="selected.has(p.id)"
              @change="toggleSelect(p.id)"
            />
            <!-- Reordenar (solo si la organización no fijó el orden) -->
            <div v-if="!rutaBloqueada && pendientes.length > 1" class="dlv__orden-ctrl" @click.stop>
              <button class="dlv__orden-btn" :disabled="guardandoOrden" title="Subir" @click.stop="moverArriba(p)"><i class="bi bi-chevron-up"></i></button>
              <button class="dlv__orden-btn" :disabled="guardandoOrden" title="Bajar" @click.stop="moverAbajo(p)"><i class="bi bi-chevron-down"></i></button>
            </div>
            <div class="dlv__row-body" @click="toggleSelect(p.id)">
              <div class="dlv__row-top">
                <span v-if="p.orden_entrega" class="dlv__orden-n" title="Orden de entrega">{{ p.orden_entrega }}</span>
                <span v-if="i === 0" class="dlv__chip-sig">▶ Siguiente</span>
                <span class="dlv__pkg-code">{{ p.codigo_paquete }}</span>
                <span class="dlv__badge dlv__badge--pendiente">Pendiente</span>
              </div>
              <div class="dlv__row-nombre">
                <User :size="12" :stroke-width="2" /> {{ p.paciente?.nombre }}
              </div>
              <div class="dlv__row-dir">
                <MapPin :size="12" :stroke-width="2" /> {{ p.direccion_envio }}
              </div>
              <div v-if="p.contacto_telefono" class="dlv__row-tel">
                <Phone :size="12" :stroke-width="2" /> {{ p.contacto_telefono }}
              </div>
              <div v-if="p.notas_envio" class="dlv__row-notas">
                <FileText :size="12" :stroke-width="2" /> {{ p.notas_envio }}
              </div>
              <div class="dlv__row-meta">
                {{ fmtFecha(p.fecha_dispensacion) }}
              </div>
              <div class="dlv__stop-actions" @click.stop>
                <a v-if="p.contacto_telefono" :href="`tel:${p.contacto_telefono}`" class="dlv__stop-btn">
                  <Phone :size="13" :stroke-width="2" /> Llamar
                </a>
                <button v-if="p.direccion_envio" class="dlv__stop-btn" @click.stop="irAParada(p)">
                  <Navigation :size="13" :stroke-width="2" /> Ir
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- En viaje -->
      <div v-if="enViaje.length" class="dlv__section">
        <button
          class="dlv__section-head"
          :aria-expanded="abiertas.enviaje"
          @click="toggleSeccion('enviaje')"
        >
          <ChevronDown class="dlv__section-caret" :class="{ 'dlv__section-caret--cerrado': !abiertas.enviaje }" :size="14" :stroke-width="2.5" />
          <span class="dlv__section-title">En camino</span>
          <span class="dlv__section-count">{{ enViaje.length }}</span>
        </button>
        <div v-show="abiertas.enviaje" class="dlv__list">
          <div v-for="(p, i) in enViaje" :key="p.id"
               class="dlv__row dlv__row--enviaje"
               :class="{ 'dlv__row--siguiente': i === 0, 'dlv__row--bloqueada': i !== 0 }">
            <div class="dlv__row-body">
              <div class="dlv__row-top">
                <span class="dlv__pkg-code">{{ p.codigo_paquete }}</span>
                <span v-if="i === 0" class="dlv__chip-sig">▶ Siguiente</span>
                <span v-else class="dlv__badge dlv__badge--enviaje">En camino</span>
              </div>
              <div class="dlv__row-nombre">
                <User :size="12" :stroke-width="2" /> {{ p.paciente?.nombre }}
              </div>
              <div class="dlv__row-dir">
                <MapPin :size="12" :stroke-width="2" /> {{ p.direccion_envio }}
              </div>
              <div v-if="p.contacto_telefono" class="dlv__row-tel">
                <Phone :size="12" :stroke-width="2" /> {{ p.contacto_telefono }}
              </div>
              <div v-if="p.notas_envio" class="dlv__row-notas">
                <FileText :size="12" :stroke-width="2" /> {{ p.notas_envio }}
              </div>
            </div>
            <div class="dlv__row-actions">
              <div class="dlv__stop-actions">
                <a v-if="p.contacto_telefono" :href="`tel:${p.contacto_telefono}`" class="dlv__stop-btn">
                  <Phone :size="13" :stroke-width="2" /> Llamar
                </a>
                <button v-if="p.direccion_envio" class="dlv__stop-btn" @click.stop="irAParada(p)">
                  <Navigation :size="13" :stroke-width="2" /> Ir
                </button>
              </div>
              <div v-if="i === 0" class="dlv__row-actions-main">
                <button class="dlv__btn-entregar" @click.stop="abrirEntregar(p)">
                  <CheckCircle2 :size="14" :stroke-width="2" /> Entregado
                </button>
                <button class="dlv__btn-fallo" @click.stop="abrirFallo(p)">
                  <XCircle :size="14" :stroke-width="2" /> Problema
                </button>
              </div>
              <div v-else class="dlv__row-locked" title="Cerrá primero las paradas anteriores de la ruta">
                <Lock :size="13" :stroke-width="2" /> Cerrá primero la parada anterior
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Fallidos -->
      <div v-if="fallidos.length" class="dlv__section dlv__section--fallidos">
        <button
          class="dlv__section-head"
          :aria-expanded="abiertas.fallidos"
          @click="toggleSeccion('fallidos')"
        >
          <ChevronDown class="dlv__section-caret dlv__section-caret--red" :class="{ 'dlv__section-caret--cerrado': !abiertas.fallidos }" :size="14" :stroke-width="2.5" />
          <span class="dlv__section-title dlv__section-title--red">
            <XCircle :size="13" :stroke-width="2" /> No entregados — los reprograma el admin
          </span>
          <span class="dlv__section-count dlv__section-count--red">{{ fallidos.length }}</span>
        </button>
        <div v-show="abiertas.fallidos" class="dlv__list">
          <div v-for="p in fallidos" :key="p.id" class="dlv__row dlv__row--fallido">
            <div class="dlv__row-body">
              <div class="dlv__row-top">
                <span class="dlv__pkg-code">{{ p.codigo_paquete }}</span>
                <span class="dlv__badge dlv__badge--fallido">No entregado</span>
              </div>
              <div class="dlv__row-nombre"><User :size="12" :stroke-width="2" /> {{ p.paciente?.nombre }}</div>
              <div class="dlv__row-dir"><MapPin :size="12" :stroke-width="2" /> {{ p.direccion_envio }}</div>
              <div v-if="p.motivo_fallo" class="dlv__row-motivo">
                <XCircle :size="12" :stroke-width="2" /> {{ p.motivo_fallo }}
              </div>
            </div>
          </div>
        </div>
      </div>

    </template>

    <!-- ── Modal Entrega ── -->
    <Teleport to="body">
      <!-- `sucio` explícito: la FIRMA se dibuja en un canvas y eso no dispara `input`, así que el
           chequeo genérico de la directiva no la ve y ESC cerraría el modal en silencio. La firma
           no se puede volver a pedir: para cuando alguien se da cuenta, la persona ya se fue. -->
      <!-- Y SIN `@click.self`: cerrar al tocar afuera es la otra puerta, y por ahí la directiva
           no pasa. Los modales pesados del proyecto (dispensar, editar) tampoco lo tienen, por
           esto mismo. Se cierra con la ✕ o con ESC, que sí pregunta. -->
      <div v-modal="{ cerrar: () => modalEntregar = null, sucio: () => !!firmaData || Number(cobroEfectivo) > 0 || Number(cobroTransf) > 0 }"
           v-if="modalEntregar" class="dlv__overlay">
        <div class="dlv__modal">
          <div class="dlv__modal-header">
            <CheckCircle2 :size="18" :stroke-width="2" style="color:#15803d" />
            <span class="dlv__modal-title">Registrar entrega</span>
            <button class="dlv__modal-close" @click="modalEntregar = null">✕</button>
          </div>
          <div class="dlv__modal-body">
            <div class="dlv__modal-pkg">{{ modalEntregar.codigo_paquete }} — {{ modalEntregar.paciente?.nombre }}</div>

            <!-- Cobro (solo si hay saldo pendiente) -->
            <div v-if="saldoACobrar > 0" class="dlv__cobro">
              <div class="dlv__cobro-head">
                <span>A cobrar</span>
                <strong>{{ fmtMoneda(saldoACobrar) }}</strong>
              </div>
              <div class="dlv__cobro-grid">
                <label class="dlv__cobro-cell">
                  <span>Efectivo</span>
                  <input type="number" min="0" step="any" v-model.number="cobroEfectivo" placeholder="0" />
                </label>
                <label class="dlv__cobro-cell">
                  <span>Transferencia</span>
                  <input type="number" min="0" step="any" v-model.number="cobroTransf" placeholder="0" />
                </label>
              </div>
              <!-- Comprobante de pago (foto, opcional) -->
              <div class="dlv__foto">
                <div class="dlv__foto-label"><FileText :size="13" :stroke-width="2" /> Comprobante de pago <span class="dlv__opt">opcional</span></div>
                <div v-if="comprobantePreview" class="dlv__foto-preview">
                  <img :src="comprobantePreview" alt="comprobante de pago" />
                  <button type="button" class="dlv__foto-del" @click="clearComprobante"><Trash2 :size="13" :stroke-width="2" /></button>
                </div>
                <label v-else class="dlv__foto-btn">
                  <FileText :size="14" :stroke-width="2" /> Subir / tomar foto
                  <input type="file" accept="image/*" capture="environment" @change="setComprobante" hidden />
                </label>
              </div>
              <div class="dlv__cobro-resto" :class="{ 'dlv__cobro-resto--info': excedenteEntrega > 0 }">
                <template v-if="excedenteEntrega > 0">Paga de más: <strong>{{ fmtMoneda(excedenteEntrega) }}</strong> → queda a favor en su cuenta</template>
                <template v-else-if="restoEntregaCuenta > 0">Resto a cuenta corriente: <strong>{{ fmtMoneda(restoEntregaCuenta) }}</strong></template>
                <template v-else>

      <!-- LO QUE HAY QUE HACER AHORA.
           Un repartidor mira esto parado en la vereda con una caja en la mano: necesita saber
           a dónde va, no leer tres secciones con checkboxes. El resto de la pantalla queda
           abajo para consultar; acá arriba hay UNA cosa a la vez. -->
      <div v-if="siguienteParada" class="dlv__foco">
        <div class="dlv__foco-tag">Tu próxima entrega</div>
        <div class="dlv__foco-nombre">{{ siguienteParada.paciente?.nombre || 'Paciente' }}</div>
        <div class="dlv__foco-dir">{{ siguienteParada.direccion_envio || 'Sin dirección cargada' }}</div>
        <div class="dlv__foco-acts">
          <button class="dlv__foco-btn dlv__foco-btn--nav" @click="irAParada(siguienteParada)">
            <Route :size="16" :stroke-width="2" /> Cómo llegar
          </button>
          <button class="dlv__foco-btn dlv__foco-btn--ok" @click="abrirEntregar(siguienteParada)">
            <Check :size="16" :stroke-width="2.5" /> Entregué
          </button>
          <button class="dlv__foco-btn dlv__foco-btn--no" @click="abrirFallo(siguienteParada)">
            No pude
          </button>
        </div>
        <p v-if="enViaje.length > 1" class="dlv__foco-resto">
          Te quedan {{ enViaje.length - 1 }} más en este viaje.
        </p>
      </div>

      <!-- Todavía no salió: lo único que importa es arrancar. -->
      <div v-else-if="pendientes.length" class="dlv__foco dlv__foco--salir">
        <div class="dlv__foco-tag">Listo para salir</div>
        <div class="dlv__foco-nombre">
          {{ pendientes.length }} paquete{{ pendientes.length === 1 ? '' : 's' }} para llevar
        </div>
        <div class="dlv__foco-dir">Elegí cuáles cargás y arrancá. Los que dejes quedan para después.</div>
        <div class="dlv__foco-acts">
          <button class="dlv__foco-btn dlv__foco-btn--ok" :disabled="!selected.size || saving" @click="handleIniciarViaje">
            <Bike :size="16" :stroke-width="2" />
            Salir a repartir{{ selected.size ? ` (${selected.size})` : '' }}
          </button>
        </div>
        <p v-if="!selected.size" class="dlv__foco-resto">Marcá abajo los que llevás.</p>
      </div>

      <!-- Nada que hacer: que se note, en vez de dejar una pantalla con listas vacías. -->
      <div v-else class="dlv__foco dlv__foco--vacio">
        <div class="dlv__foco-nombre">No tenés entregas pendientes</div>
        <div class="dlv__foco-dir">Cuando la organización te asigne un paquete, aparece acá.</div>
      </div>
Cubierto ✓</template>
              </div>
            </div>

            <!-- Firma digital -->
            <div class="dlv__firma-section">
              <div class="dlv__firma-label">
                <PenLine :size="13" :stroke-width="2" />
                Firma del receptor
                <span class="dlv__opt">opcional</span>
              </div>
              <div v-if="!firmaActiva" class="dlv__firma-placeholder" @click="iniciarCanvas">
                <PenLine :size="20" :stroke-width="1.5" style="color:#9ca3af" />
                <span>Tocar para capturar firma</span>
              </div>
              <div v-else class="dlv__firma-canvas-wrap">
                <canvas
                  ref="canvasRef"
                  class="dlv__firma-canvas"
                  width="400"
                  height="170"
                ></canvas>
                <button class="dlv__firma-borrar" @click="borrarFirma" title="Borrar firma">
                  <Trash2 :size="13" :stroke-width="2" /> Borrar
                </button>
              </div>
              <p v-if="firmaData" class="dlv__firma-ok">✓ Firma capturada</p>
            </div>

            <!-- Comprobante de entrega (foto, opcional) -->
            <div class="dlv__foto">
              <div class="dlv__foto-label"><FileText :size="13" :stroke-width="2" /> Comprobante de entrega <span class="dlv__opt">opcional</span></div>
              <div v-if="comprobanteEntregaPreview" class="dlv__foto-preview">
                <img :src="comprobanteEntregaPreview" alt="comprobante de entrega" />
                <button type="button" class="dlv__foto-del" @click="clearComprobanteEntrega"><Trash2 :size="13" :stroke-width="2" /></button>
              </div>
              <label v-else class="dlv__foto-btn">
                <FileText :size="14" :stroke-width="2" /> Subir / tomar foto
                <input type="file" accept="image/*" capture="environment" @change="setComprobanteEntrega" hidden />
              </label>
            </div>

            <label class="dlv__modal-label">Notas de entrega <span class="dlv__opt">opcional</span></label>
            <textarea
              v-model.trim="notasEntrega"
              class="dlv__modal-input"
              rows="2"
              placeholder="Firmó el receptor, dejé con vecino…"
            ></textarea>
          </div>
          <div class="dlv__modal-footer">
            <button class="dlv__btn-ghost" :disabled="saving" @click="modalEntregar = null">Cancelar</button>
            <button class="dlv__btn-confirm" :disabled="saving || !entregaCobroValido" @click="confirmarEntrega">
              <DsSpinner v-if="saving" :size="13" />
              <CheckCircle2 v-else :size="14" :stroke-width="2" />
              Confirmar entrega
            </button>
          </div>
        </div>
      </div>
    </Teleport>

    <!-- ── Modal Fallo ── -->
    <Teleport to="body">
      <div v-modal="() => modalFallo = null" v-if="modalFallo" class="dlv__overlay" @click.self="modalFallo = null">
        <div class="dlv__modal">
          <div class="dlv__modal-header">
            <XCircle :size="18" :stroke-width="2" style="color:#dc2626" />
            <span class="dlv__modal-title">Reportar problema</span>
            <button class="dlv__modal-close" @click="modalFallo = null">✕</button>
          </div>
          <div class="dlv__modal-body">
            <div class="dlv__modal-pkg">{{ modalFallo.codigo_paquete }} — {{ modalFallo.paciente?.nombre }}</div>
            <label class="dlv__modal-label">Motivo <span style="color:#ef4444">*</span></label>
            <textarea
              v-model.trim="motivoFallo"
              class="dlv__modal-input"
              rows="3"
              placeholder="Nadie en el domicilio, dirección incorrecta, destinatario rechazó…"
            ></textarea>
          </div>
          <div class="dlv__modal-footer">
            <button class="dlv__btn-ghost" :disabled="saving" @click="modalFallo = null">Cancelar</button>
            <button class="dlv__btn-danger" :disabled="saving || !motivoFallo.trim()" @click="confirmarFallo">
              <DsSpinner v-if="saving" :size="13" />
              <XCircle v-else :size="14" :stroke-width="2" />
              Reportar
            </button>
          </div>
        </div>
      </div>
    </Teleport>

  </div>
</template>

<style scoped>
.dlv { padding: var(--sp-5); max-width: 700px; margin: 0 auto; }

/* Header */
.dlv__header { display: flex; align-items: center; justify-content: space-between; margin-bottom: var(--sp-5); }
.dlv__header-left { display: flex; align-items: center; gap: var(--sp-3); color: var(--c-ink-700); }
.dlv__title { font-size: var(--fs-18); font-weight: 700; color: var(--c-ink-900); }
.dlv__sub { font-size: var(--fs-13); color: var(--c-ink-400); }

/* Loading */
.dlv__loading { display: flex; align-items: center; justify-content: center; padding: 2rem; }

/* Stats */
.dlv__stats { display: flex; gap: var(--sp-3); margin-bottom: var(--sp-5); }
.dlv__stat { flex: 1; background: var(--c-paper); border: 1px solid var(--c-ink-300); border-radius: var(--r-lg); padding: var(--sp-4); text-align: center; }
.dlv__stat-n { display: block; font-size: 1.75rem; font-weight: 800; }
.dlv__stat-n--blue   { color: var(--c-sky-600); }
.dlv__stat-n--orange { color: var(--c-amber-500); }
.dlv__stat-n--green  { color: var(--c-leaf-600); }
.dlv__stat-l { font-size: 12px; color: var(--c-ink-500); font-weight: 500; }

/* Toolbar */
.dlv__toolbar { display: flex; align-items: center; justify-content: space-between; gap: var(--sp-3); margin-bottom: var(--sp-4); padding: var(--sp-3) var(--sp-4); background: var(--c-leaf-50); border-radius: var(--r-md); border: 1px solid var(--c-leaf-100); }
.dlv__check-all { display: flex; align-items: center; gap: var(--sp-2); font-size: var(--fs-13); color: var(--c-ink-700); cursor: pointer; user-select: none; }
.dlv__check-all input { cursor: pointer; }
.dlv__btn-viaje { display: inline-flex; align-items: center; gap: var(--sp-2); background: var(--c-leaf-700); color: #fff; border: none; padding: .45rem .875rem; border-radius: var(--r-md); font-size: var(--fs-13); font-weight: 600; cursor: pointer; transition: background .15s; }
.dlv__btn-viaje:hover:not(:disabled) { background: var(--c-leaf-800); }
.dlv__btn-viaje:disabled { opacity: .45; cursor: not-allowed; }
.dlv__btn-maps { display: inline-flex; align-items: center; gap: var(--sp-2); background: #fff; color: var(--c-leaf-700); border: 1.5px solid var(--c-leaf-300, #86efac); padding: .45rem .875rem; border-radius: var(--r-md); font-size: var(--fs-13); font-weight: 600; cursor: pointer; transition: all .15s; }
.dlv__btn-maps:hover:not(:disabled) { background: #f0fdf4; border-color: var(--c-leaf-600, #16a34a); }
.dlv__btn-maps:disabled { opacity: .45; cursor: not-allowed; }
.dlv__orden-ctrl { display: flex; flex-direction: column; gap: 2px; flex-shrink: 0; }
.dlv__orden-btn { display: flex; align-items: center; justify-content: center; width: 26px; height: 20px; border: 1px solid var(--c-slate-200); background: #fff; border-radius: 5px; cursor: pointer; color: var(--c-slate-600); font-size: .75rem; padding: 0; }
.dlv__orden-btn:hover:not(:disabled) { background: #f0fdf4; border-color: var(--c-leaf-300, #86efac); color: var(--c-leaf-700, #15803d); }
.dlv__orden-btn:disabled { opacity: .4; cursor: not-allowed; }

/* Empty */
.dlv__empty { text-align: center; padding: var(--sp-10) var(--sp-4); color: var(--c-ink-300); }
.dlv__empty-title { font-size: var(--fs-16); font-weight: 700; color: var(--c-ink-700); margin-top: var(--sp-3); }
.dlv__empty-sub { font-size: var(--fs-13); color: var(--c-ink-400); margin-top: var(--sp-1); }

/* Section */
.dlv__section { margin-bottom: var(--sp-6); }
/* Lo que hay que hacer AHORA. Se lee de un vistazo, con el pulgar y sin frenar. */
.dlv__foco {
  background: #fff; border: 2px solid var(--c-leaf-500, #5A8A72); border-radius: 16px;
  padding: var(--sp-5, 1.25rem); margin-bottom: var(--sp-5, 1.25rem);
  box-shadow: 0 4px 16px rgba(15,23,42,.06);
}
.dlv__foco--salir { border-color: var(--c-sky-600, #0284C7); }
.dlv__foco--vacio { border-color: var(--c-ink-300, #D1D5DB); border-style: dashed; text-align: center; }
.dlv__foco-tag {
  font-size: 11px; font-weight: 800; text-transform: uppercase; letter-spacing: .08em;
  color: var(--c-leaf-600, #3F6452); margin-bottom: var(--sp-2, .5rem);
}
.dlv__foco--salir .dlv__foco-tag { color: var(--c-sky-600, #0284C7); }
.dlv__foco-nombre { font-size: 20px; font-weight: 800; color: var(--c-ink-900, #1A1D1F); line-height: 1.2; }
.dlv__foco-dir { font-size: 15px; color: var(--c-ink-700, #3A3F44); margin-top: 2px; line-height: 1.4; }
.dlv__foco-acts { display: flex; gap: .5rem; margin-top: var(--sp-4, 1rem); flex-wrap: wrap; }
.dlv__foco-btn {
  flex: 1; min-width: 120px; display: inline-flex; align-items: center; justify-content: center;
  gap: .4rem; padding: .85rem 1rem; border-radius: 12px; border: 1.5px solid transparent;
  font-size: 15px; font-weight: 700; cursor: pointer; transition: opacity .15s;
}
.dlv__foco-btn:disabled { opacity: .45; cursor: not-allowed; }
.dlv__foco-btn--nav { background: var(--c-ink-100, #F3F4F6); color: var(--c-ink-900, #1A1D1F); }
.dlv__foco-btn--ok  { background: var(--c-leaf-600, #3F6452); color: #fff; }
.dlv__foco-btn--no  { background: #fff; border-color: var(--c-ink-300, #D1D5DB); color: var(--c-ink-500, #6B7280); flex: 0 0 auto; min-width: 100px; }
.dlv__foco-resto { font-size: 13px; color: var(--c-ink-500, #6B7280); margin: var(--sp-3, .75rem) 0 0; }

/* Cabecera plegable. Es el control que más se toca desde la calle, así que ocupa todo el
   ancho y tiene 44px de alto: el mínimo para acertarle con el pulgar sin frenar la moto. */
.dlv__section-head {
  display: flex; align-items: center; gap: var(--sp-2);
  width: 100%; min-height: 44px;
  background: none; border: none; cursor: pointer;
  padding: 0 var(--sp-1); margin-bottom: var(--sp-2);
  text-align: left; -webkit-tap-highlight-color: transparent;
}
.dlv__section-head:hover .dlv__section-title { color: var(--c-ink-600); }
.dlv__section-caret { color: var(--c-ink-400); flex-shrink: 0; transition: transform .18s ease; }
.dlv__section-caret--cerrado { transform: rotate(-90deg); }
.dlv__section-caret--red { color: #dc2626; }
.dlv__section-count {
  margin-left: auto; flex-shrink: 0;
  font-size: 11px; font-weight: 700; color: var(--c-ink-500);
  background: var(--c-ink-100); border-radius: 999px; padding: 2px 8px; min-width: 22px; text-align: center;
}
.dlv__section-count--red { color: #dc2626; background: #fee2e2; }
.dlv__section-title { font-size: 11px; font-weight: 700; text-transform: uppercase; letter-spacing: .06em; color: var(--c-ink-400); padding: 0 var(--sp-1); }

/* List rows */
.dlv__list { display: flex; flex-direction: column; gap: var(--sp-2); }
.dlv__row { display: flex; align-items: flex-start; gap: var(--sp-3); background: var(--c-paper); border: 1.5px solid var(--c-ink-100); border-radius: var(--r-lg); padding: var(--sp-4); transition: border-color .15s, box-shadow .15s; }
.dlv__row--pendiente:hover { border-color: var(--c-leaf-300); box-shadow: var(--sh-2); }
.dlv__row--enviaje { border-color: var(--c-amber-100); }
.dlv__row--enviaje:hover { border-color: var(--c-amber-500); box-shadow: var(--sh-2); }
.dlv__row--selected { border-color: var(--c-leaf-600); background: var(--c-leaf-50); }
.dlv__row--siguiente { border-color: var(--c-leaf-600, #16a34a); box-shadow: 0 0 0 2px var(--c-leaf-100, #dcfce7); }
.dlv__row--bloqueada { opacity: .62; }
.dlv__row-locked { display: inline-flex; align-items: center; gap: .35rem; color: var(--c-text-muted, var(--c-slate-400)); font-size: .72rem; font-weight: 600; padding: .35rem .2rem; }
.dlv__chip-sig { display: inline-flex; align-items: center; gap: .2rem; background: var(--c-leaf-700, #15803d); color: #fff; font-size: .62rem; font-weight: 800; text-transform: uppercase; letter-spacing: .04em; padding: .2em .55em; border-radius: 999px; }
.dlv__check { margin-top: 3px; cursor: pointer; flex-shrink: 0; }
.dlv__row-body { flex: 1; min-width: 0; cursor: pointer; }
.dlv__row-top { display: flex; align-items: center; gap: var(--sp-2); margin-bottom: var(--sp-2); flex-wrap: wrap; }
.dlv__pkg-code { font-family: monospace; font-size: var(--fs-13); font-weight: 700; color: var(--c-ink-800); background: var(--c-slate-100); padding: .15em .5em; border-radius: 5px; }
.dlv__orden-n { display: inline-flex; align-items: center; justify-content: center; min-width: 22px; height: 22px; background: #1b5e20; color: #fff; font-size: .8rem; font-weight: 800; border-radius: 6px; padding: 0 .3em; }
.dlv__ruta-fija { display: flex; align-items: center; gap: .5rem; background: #fef3c7; border: 1.5px solid #fcd34d; color: #b45309; border-radius: 10px; padding: .7rem .9rem; font-size: .82rem; margin-bottom: var(--sp-4); }
.dlv__badge { font-size: 12px; font-weight: 600; padding: .15em .55em; border-radius: 5px; }
.dlv__badge--pendiente { background: var(--c-sky-100); color: var(--c-sky-600); }
.dlv__badge--enviaje   { background: var(--c-amber-100); color: var(--c-amber-500); }
.dlv__row-nombre, .dlv__row-dir, .dlv__row-tel, .dlv__row-notas {
  display: flex; align-items: flex-start; gap: var(--sp-1); font-size: var(--fs-13); color: var(--c-ink-700);
  margin-bottom: .2rem; line-height: 1.35;
}
.dlv__row-notas { color: var(--c-ink-400); font-style: italic; }
.dlv__row-meta { font-size: 12px; color: var(--c-ink-400); margin-top: var(--sp-2); }
.dlv__row-actions { display: flex; flex-direction: column; gap: var(--sp-2); flex-shrink: 0; }
.dlv__row-actions-main { display: flex; flex-direction: column; gap: var(--sp-2); }
.dlv__stop-actions { display: flex; gap: var(--sp-2); margin-top: var(--sp-2); }
.dlv__stop-btn {
  display: inline-flex; align-items: center; gap: .35rem; text-decoration: none;
  background: #fff; color: var(--c-slate-600); border: 1.5px solid var(--c-slate-200); border-radius: var(--r-md);
  padding: .4rem .7rem; font-size: var(--fs-12); font-weight: 700; cursor: pointer; white-space: nowrap;
}
.dlv__stop-btn:hover { background: var(--c-slate-50); border-color: var(--c-leaf-300, #86efac); color: var(--c-leaf-700, #15803d); }
.dlv__btn-entregar { display: inline-flex; align-items: center; gap: var(--sp-1); background: var(--c-leaf-100); color: var(--c-leaf-700); border: none; padding: .45rem .75rem; border-radius: var(--r-md); font-size: var(--fs-13); font-weight: 600; cursor: pointer; white-space: nowrap; transition: background var(--t-fast); }
.dlv__btn-entregar:hover { background: var(--c-leaf-300); }
.dlv__btn-fallo { display: inline-flex; align-items: center; gap: var(--sp-1); background: var(--c-rust-100); color: var(--c-rust-600); border: none; padding: .45rem .75rem; border-radius: var(--r-md); font-size: var(--fs-13); font-weight: 600; cursor: pointer; white-space: nowrap; transition: background var(--t-fast); }
.dlv__btn-fallo:hover { background: #fecaca; }
.dlv__stat--alert { border-color: #fecaca; background: #fff5f5; }
.dlv__stat-n--red { color: #dc2626; }
.dlv__section--fallidos { opacity: .85; }
.dlv__section-title--red { color: #dc2626; display: flex; align-items: center; gap: .3rem; }
.dlv__row--fallido { border-color: #fecaca; background: #fff5f5; opacity: .9; }
.dlv__badge--fallido { background: #fee2e2; color: #dc2626; }
.dlv__row-motivo { display: flex; align-items: flex-start; gap: var(--sp-1); font-size: var(--fs-13); color: #dc2626; margin-bottom: .2rem; font-style: italic; }

/* Modal */
.dlv__overlay { position: fixed; inset: 0; background: rgba(0,0,0,.45); display: flex; align-items: center; justify-content: center; z-index: 1050; padding: 1rem; backdrop-filter: blur(3px); }
.dlv__modal { background: var(--c-paper); border-radius: 16px; width: 100%; max-width: 440px; max-height: calc(100dvh - 2rem); box-shadow: 0 20px 60px rgba(0,0,0,.2); display: flex; flex-direction: column; }
.dlv__modal-header { display: flex; align-items: center; gap: var(--sp-2); padding: var(--sp-4) var(--sp-5); border-bottom: 1px solid var(--c-ink-100); flex-shrink: 0; }
.dlv__modal-title { flex: 1; font-size: var(--fs-15); font-weight: 700; color: var(--c-ink-900); }
.dlv__modal-close { background: none; border: none; cursor: pointer; font-size: 1rem; color: var(--c-ink-400); padding: 0; }
.dlv__modal-body { padding: var(--sp-5); display: flex; flex-direction: column; gap: var(--sp-3); flex: 1 1 auto; min-height: 0; overflow-y: auto; overscroll-behavior: contain; -webkit-overflow-scrolling: touch; }
.dlv__modal-pkg { font-size: var(--fs-13); font-weight: 700; color: var(--c-ink-800); background: var(--c-slate-100); padding: var(--sp-2) var(--sp-3); border-radius: var(--r-md); }
.dlv__modal-label { font-size: 11px; font-weight: 700; text-transform: uppercase; letter-spacing: .05em; color: var(--c-ink-600); }
.dlv__modal-input { background: var(--c-slate-50); border: 1.5px solid var(--c-ink-200); border-radius: var(--r-md); padding: .6rem .8rem; font-size: var(--fs-14); color: var(--c-ink-900); width: 100%; box-sizing: border-box; resize: vertical; }
.dlv__modal-input:focus { outline: none; border-color: #1d4ed8; }
.dlv__modal-footer { display: flex; justify-content: flex-end; gap: var(--sp-2); padding: var(--sp-4) var(--sp-5); border-top: 1px solid var(--c-ink-100); flex-shrink: 0; background: var(--c-paper); }
.dlv__btn-ghost { background: #fff; color: var(--c-ink-500); border: 1.5px solid var(--c-ink-200); padding: .5rem 1rem; border-radius: var(--r-md); font-size: var(--fs-14); font-weight: 500; cursor: pointer; }
.dlv__btn-confirm { display: inline-flex; align-items: center; gap: var(--sp-1); background: var(--c-leaf-700); color: #fff; border: none; padding: .5rem 1.1rem; border-radius: var(--r-md); font-size: var(--fs-14); font-weight: 600; cursor: pointer; }
.dlv__btn-confirm:hover:not(:disabled) { background: var(--c-leaf-800); }
.dlv__btn-confirm:disabled { opacity: .5; cursor: not-allowed; }

/* Cobro en la entrega */
.dlv__cobro { border: 1.5px solid var(--c-slate-200); border-radius: 12px; padding: .75rem; margin-bottom: 1rem; }
.dlv__cobro-head { display: flex; justify-content: space-between; align-items: baseline; margin-bottom: .6rem; font-size: .82rem; color: var(--c-slate-600); }
.dlv__cobro-head strong { font-size: 1.1rem; font-weight: 800; color: var(--c-slate-900); font-variant-numeric: tabular-nums; }
.dlv__cobro-grid { display: grid; grid-template-columns: 1fr 1fr; gap: .5rem; }
.dlv__cobro-cell { display: flex; flex-direction: column; gap: 3px; min-width: 0; font-size: .72rem; font-weight: 600; color: var(--c-slate-500); }
.dlv__cobro-cell input { width: 100%; box-sizing: border-box; min-width: 0; border: 1.5px solid var(--c-slate-300); border-radius: 8px; padding: .5rem .6rem; font-size: .95rem; font-weight: 700; color: var(--c-slate-900); outline: none; font-variant-numeric: tabular-nums; }
.dlv__cobro-cell input:focus { border-color: #16a34a; }

/* Foto (comprobante de pago / entrega) */
.dlv__foto { margin-top: .6rem; }
.dlv__foto-label { display: flex; align-items: center; gap: .35rem; font-size: .75rem; font-weight: 600; color: var(--c-slate-600); margin-bottom: .35rem; }
.dlv__foto-btn { display: inline-flex; align-items: center; justify-content: center; gap: .4rem; width: 100%; box-sizing: border-box; background: #f0fdf4; border: 1.5px dashed #86efac; color: #15803d; border-radius: 8px; padding: .65rem .75rem; font-size: .82rem; font-weight: 600; cursor: pointer; }
.dlv__foto-preview { position: relative; display: inline-block; }
.dlv__foto-preview img { max-width: 100%; max-height: 160px; border-radius: 8px; border: 1px solid var(--c-slate-200); display: block; }
.dlv__foto-del { position: absolute; top: .35rem; right: .35rem; display: inline-flex; align-items: center; justify-content: center; width: 28px; height: 28px; background: rgba(255,255,255,.92); border: 1px solid #fca5a5; color: #dc2626; border-radius: 7px; cursor: pointer; }
.dlv__cobro-resto { margin-top: .5rem; padding: .45rem .65rem; border-radius: 8px; background: #f0fdf4; border: 1px solid #bbf7d0; font-size: .8rem; color: #15803d; }
.dlv__cobro-resto--err { background: #fff5f5; border-color: #fca5a5; color: #991b1b; }
.dlv__cobro-resto--info { background: #eff6ff; border-color: #bfdbfe; color: #1d4ed8; }
.dlv__btn-danger { display: inline-flex; align-items: center; gap: var(--sp-1); background: var(--c-rust-600); color: #fff; border: none; padding: .5rem 1.1rem; border-radius: var(--r-md); font-size: var(--fs-14); font-weight: 600; cursor: pointer; }
.dlv__btn-danger:disabled { opacity: .5; cursor: not-allowed; }
.dlv__opt { font-size: var(--fs-11); font-weight: 400; color: var(--c-ink-400); text-transform: none; letter-spacing: 0; }

/* Botón Ver ruta */
.dlv__btn-ruta {
  display: inline-flex; align-items: center; gap: var(--sp-2);
  background: #fff; color: #1d4ed8; border: 1.5px solid #bfdbfe;
  padding: .45rem .9rem; border-radius: var(--r-md); font-size: var(--fs-13); font-weight: 600; cursor: pointer;
}
.dlv__btn-ruta:hover { background: #eff6ff; }

/* Firma digital */
.dlv__firma-section { display: flex; flex-direction: column; gap: .35rem; }
.dlv__firma-label {
  display: flex; align-items: center; gap: .3rem;
  font-size: 11px; font-weight: 700; text-transform: uppercase; letter-spacing: .05em; color: var(--c-ink-600);
}
.dlv__firma-placeholder {
  display: flex; flex-direction: column; align-items: center; justify-content: center; gap: .4rem;
  border: 2px dashed #d1d5db; border-radius: var(--r-md); padding: 1.25rem;
  cursor: pointer; color: #9ca3af; font-size: var(--fs-13);
  transition: border-color .15s, background .15s;
}
.dlv__firma-placeholder:hover { border-color: #9ca3af; background: #f9fafb; }
.dlv__firma-canvas-wrap { position: relative; }
.dlv__firma-canvas {
  display: block; width: 100%; height: 200px; border: 1.5px solid #d1d5db; border-radius: var(--r-md);
  background: #fff; touch-action: none; cursor: crosshair;
}
.dlv__firma-borrar {
  position: absolute; top: .4rem; right: .4rem;
  display: inline-flex; align-items: center; gap: .25rem;
  background: rgba(255,255,255,.9); border: 1px solid #e5e7eb; border-radius: 6px;
  padding: .2rem .5rem; font-size: .72rem; color: #6b7280; cursor: pointer;
}
.dlv__firma-borrar:hover { color: #dc2626; border-color: #fca5a5; }
.dlv__firma-ok { font-size: .72rem; color: #15803d; margin: 0; }

/* ── Mobile ──────────────────────────────────────────────────────── */
@media (max-width: 1023px) {
  .dlv { padding: 1rem; }

  .dlv__stats {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: .5rem;
  }
  .dlv__stat { padding: .75rem .5rem; }
  .dlv__stat-n { font-size: 1.5rem; }

  .dlv__toolbar { flex-wrap: wrap; }
  .dlv__check-all { flex: 1 1 100%; }
  .dlv__btn-viaje, .dlv__btn-maps { flex: 1; justify-content: center; }

  /* En rows "en viaje", bajar los botones de acción debajo del cuerpo */
  .dlv__row--enviaje { flex-wrap: wrap; }
  .dlv__row--enviaje .dlv__row-body { width: 100%; }
  .dlv__row-actions { flex-direction: column; width: 100%; margin-top: .5rem; }
  .dlv__row-actions-main { flex-direction: row; }

  /* Touch targets más grandes y texto legible en la calle */
  .dlv__row-nombre { font-size: var(--fs-15, 15px); }
  .dlv__row-dir    { font-size: var(--fs-14, 14px); }
  .dlv__btn-viaje, .dlv__btn-maps,
  .dlv__btn-entregar, .dlv__btn-fallo { min-height: 46px; font-size: var(--fs-14, 14px); }
  .dlv__btn-entregar, .dlv__btn-fallo { flex: 1; justify-content: center; }
  .dlv__stop-actions { gap: .5rem; }
  .dlv__stop-btn { flex: 1; justify-content: center; min-height: 42px; font-size: var(--fs-13, 13px); }
  .dlv__orden-btn { width: 34px; height: 28px; }
  .dlv__check { width: 22px; height: 22px; }
}
</style>

<style scoped>
.dlv__offline {
  display: flex; align-items: center; gap: .5rem;
  background: #fef3c7; color: #92400e; border: 1px solid #fde68a;
  border-radius: 10px; padding: .55rem .8rem; margin-bottom: .6rem; font-size: .82rem;
}
</style>
