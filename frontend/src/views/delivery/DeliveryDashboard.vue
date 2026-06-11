<script setup>
import { ref, computed, onMounted, nextTick, watch } from 'vue'
import DsSpinner from '../../design-system/components/Spinner.vue'
import { Package, Bike, CheckCircle2, XCircle, MapPin, Phone, User, FileText, ChevronRight, Send, Route, PenLine, Trash2 } from 'lucide-vue-next'
import { getMisPaquetes, iniciarViaje, entregarPaquete, reportarFallo } from '../../lib/api.js'
import { useToast } from '../../composables/useToast.js'

const toast    = useToast()
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
    ctx = canvas.getContext('2d')
    ctx.strokeStyle = '#111827'
    ctx.lineWidth   = 2
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
  if (!ctx) return
  ctx.clearRect(0, 0, canvasRef.value.width, canvasRef.value.height)
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

const pendientes = computed(() => paquetes.value.filter(p => p.estado_envio === 'pendiente'))
const enViaje    = computed(() => paquetes.value.filter(p => p.estado_envio === 'en_viaje'))
const fallidos   = computed(() => paquetes.value.filter(p => p.estado_envio === 'fallido'))
const activos    = computed(() => [...pendientes.value, ...enViaje.value])

const todosSeleccionados = computed(() =>
  pendientes.value.length > 0 && pendientes.value.every(p => selected.value.has(p.id))
)

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
}

function abrirFallo(p) {
  modalFallo.value = p
  motivoFallo.value = ''
}

async function confirmarEntrega() {
  saving.value = true
  try {
    await entregarPaquete(modalEntregar.value.id, notasEntrega.value, firmaData.value)
    modalEntregar.value = null
    firmaData.value     = null
    firmaActiva.value   = false
    await load()
    toast.success('Entrega registrada')
  } catch { toast.error('Error al registrar entrega') }
  finally { saving.value = false }
}

async function confirmarFallo() {
  if (!motivoFallo.value.trim()) {
    toast.error('El motivo es requerido')
    return
  }
  saving.value = true
  try {
    await reportarFallo(modalFallo.value.id, motivoFallo.value.trim())
    modalFallo.value = null
    await load()
    toast.success('Problema reportado')
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

      <!-- Pendientes -->
      <div v-if="pendientes.length" class="dlv__section">
        <div class="dlv__section-title">Pendientes de retirar</div>
        <div class="dlv__list">
          <div
            v-for="p in pendientes" :key="p.id"
            class="dlv__row dlv__row--pendiente"
            :class="{ 'dlv__row--selected': selected.has(p.id) }"
          >
            <input
              type="checkbox"
              class="dlv__check"
              :checked="selected.has(p.id)"
              @change="toggleSelect(p.id)"
            />
            <div class="dlv__row-body" @click="toggleSelect(p.id)">
              <div class="dlv__row-top">
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
                {{ p.cantidad }}{{ p.stock?.unidad || 'g' }} {{ p.stock?.forma_producto || '' }}
                · {{ fmtFecha(p.fecha_dispensacion) }}
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- En viaje -->
      <div v-if="enViaje.length" class="dlv__section">
        <div class="dlv__section-title">En camino</div>
        <div class="dlv__list">
          <div v-for="p in enViaje" :key="p.id" class="dlv__row dlv__row--enviaje">
            <div class="dlv__row-body">
              <div class="dlv__row-top">
                <span class="dlv__pkg-code">{{ p.codigo_paquete }}</span>
                <span class="dlv__badge dlv__badge--enviaje">En camino</span>
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
              <button class="dlv__btn-entregar" @click.stop="abrirEntregar(p)">
                <CheckCircle2 :size="14" :stroke-width="2" /> Entregado
              </button>
              <button class="dlv__btn-fallo" @click.stop="abrirFallo(p)">
                <XCircle :size="14" :stroke-width="2" /> Problema
              </button>
            </div>
          </div>
        </div>
      </div>

      <!-- Fallidos -->
      <div v-if="fallidos.length" class="dlv__section dlv__section--fallidos">
        <div class="dlv__section-title dlv__section-title--red">
          <XCircle :size="13" :stroke-width="2" /> No entregados — pendientes de reprogramación por el admin
        </div>
        <div class="dlv__list">
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
      <div v-if="modalEntregar" class="dlv__overlay" @click.self="modalEntregar = null">
        <div class="dlv__modal">
          <div class="dlv__modal-header">
            <CheckCircle2 :size="18" :stroke-width="2" style="color:#15803d" />
            <span class="dlv__modal-title">Registrar entrega</span>
            <button class="dlv__modal-close" @click="modalEntregar = null">✕</button>
          </div>
          <div class="dlv__modal-body">
            <div class="dlv__modal-pkg">{{ modalEntregar.codigo_paquete }} — {{ modalEntregar.paciente?.nombre }}</div>

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
                  height="120"
                ></canvas>
                <button class="dlv__firma-borrar" @click="borrarFirma" title="Borrar firma">
                  <Trash2 :size="13" :stroke-width="2" /> Borrar
                </button>
              </div>
              <p v-if="firmaData" class="dlv__firma-ok">✓ Firma capturada</p>
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
            <button class="dlv__btn-confirm" :disabled="saving" @click="confirmarEntrega">
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
      <div v-if="modalFallo" class="dlv__overlay" @click.self="modalFallo = null">
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

/* Empty */
.dlv__empty { text-align: center; padding: var(--sp-10) var(--sp-4); color: var(--c-ink-300); }
.dlv__empty-title { font-size: var(--fs-16); font-weight: 700; color: var(--c-ink-700); margin-top: var(--sp-3); }
.dlv__empty-sub { font-size: var(--fs-13); color: var(--c-ink-400); margin-top: var(--sp-1); }

/* Section */
.dlv__section { margin-bottom: var(--sp-6); }
.dlv__section-title { font-size: 11px; font-weight: 700; text-transform: uppercase; letter-spacing: .06em; color: var(--c-ink-400); margin-bottom: var(--sp-3); padding: 0 var(--sp-1); }

/* List rows */
.dlv__list { display: flex; flex-direction: column; gap: var(--sp-2); }
.dlv__row { display: flex; align-items: flex-start; gap: var(--sp-3); background: var(--c-paper); border: 1.5px solid var(--c-ink-100); border-radius: var(--r-lg); padding: var(--sp-4); transition: border-color .15s, box-shadow .15s; }
.dlv__row--pendiente:hover { border-color: var(--c-leaf-300); box-shadow: var(--sh-2); }
.dlv__row--enviaje { border-color: var(--c-amber-100); }
.dlv__row--enviaje:hover { border-color: var(--c-amber-500); box-shadow: var(--sh-2); }
.dlv__row--selected { border-color: var(--c-leaf-600); background: var(--c-leaf-50); }
.dlv__check { margin-top: 3px; cursor: pointer; flex-shrink: 0; }
.dlv__row-body { flex: 1; min-width: 0; cursor: pointer; }
.dlv__row-top { display: flex; align-items: center; gap: var(--sp-2); margin-bottom: var(--sp-2); flex-wrap: wrap; }
.dlv__pkg-code { font-family: monospace; font-size: var(--fs-13); font-weight: 700; color: var(--c-ink-800); background: var(--c-ink-50, #f1f5f9); padding: .15em .5em; border-radius: 5px; }
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
.dlv__modal { background: var(--c-paper); border-radius: 16px; width: 100%; max-width: 440px; box-shadow: 0 20px 60px rgba(0,0,0,.2); display: flex; flex-direction: column; }
.dlv__modal-header { display: flex; align-items: center; gap: var(--sp-2); padding: var(--sp-4) var(--sp-5); border-bottom: 1px solid var(--c-ink-100); }
.dlv__modal-title { flex: 1; font-size: var(--fs-15); font-weight: 700; color: var(--c-ink-900); }
.dlv__modal-close { background: none; border: none; cursor: pointer; font-size: 1rem; color: var(--c-ink-400); padding: 0; }
.dlv__modal-body { padding: var(--sp-5); display: flex; flex-direction: column; gap: var(--sp-3); }
.dlv__modal-pkg { font-size: var(--fs-13); font-weight: 700; color: var(--c-ink-800); background: var(--c-ink-50, #f1f5f9); padding: var(--sp-2) var(--sp-3); border-radius: var(--r-md); }
.dlv__modal-label { font-size: 11px; font-weight: 700; text-transform: uppercase; letter-spacing: .05em; color: var(--c-ink-600); }
.dlv__modal-input { background: var(--c-ink-50, #f8fafc); border: 1.5px solid var(--c-ink-200); border-radius: var(--r-md); padding: .6rem .8rem; font-size: var(--fs-14); color: var(--c-ink-900); width: 100%; box-sizing: border-box; resize: vertical; }
.dlv__modal-input:focus { outline: none; border-color: #1d4ed8; }
.dlv__modal-footer { display: flex; justify-content: flex-end; gap: var(--sp-2); padding: var(--sp-4) var(--sp-5); border-top: 1px solid var(--c-ink-100); }
.dlv__btn-ghost { background: #fff; color: var(--c-ink-500); border: 1.5px solid var(--c-ink-200); padding: .5rem 1rem; border-radius: var(--r-md); font-size: var(--fs-14); font-weight: 500; cursor: pointer; }
.dlv__btn-confirm { display: inline-flex; align-items: center; gap: var(--sp-1); background: var(--c-leaf-700); color: #fff; border: none; padding: .5rem 1.1rem; border-radius: var(--r-md); font-size: var(--fs-14); font-weight: 600; cursor: pointer; }
.dlv__btn-confirm:hover:not(:disabled) { background: var(--c-leaf-800); }
.dlv__btn-confirm:disabled { opacity: .5; cursor: not-allowed; }
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
  display: block; width: 100%; height: 120px; border: 1.5px solid #d1d5db; border-radius: var(--r-md);
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
  .dlv__btn-viaje { flex: 1; justify-content: center; }

  /* En rows "en viaje", bajar los botones de acción debajo del cuerpo */
  .dlv__row--enviaje { flex-wrap: wrap; }
  .dlv__row--enviaje .dlv__row-body { width: 100%; }
  .dlv__row-actions { flex-direction: row; width: 100%; margin-top: .5rem; }
  .dlv__btn-entregar,
  .dlv__btn-fallo { flex: 1; justify-content: center; }
}
</style>
