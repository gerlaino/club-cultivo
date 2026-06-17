<template>
  <div class="mpv">

    <!-- Header -->
    <div class="mpv__header">
      <p class="mpv__eyebrow"><Scale :size="13" :stroke-width="2" /> Manicura</p>
      <h1 class="mpv__title">Mis pesajes</h1>
      <p class="mpv__sub">Registrá el peso diario de manicura. Cada jornada es un pesaje independiente.</p>
    </div>

    <!-- Lote activo selector -->
    <div class="mpv__lote-wrap">
      <div class="mpv__lote-label">Lote activo</div>
      <div v-if="loadingLotes" class="mpv__hint">Cargando lotes…</div>
      <div v-else-if="!lotes.length" class="mpv__empty-lotes">
        <Wind :size="20" :stroke-width="1.5" />
        <span>Sin lotes asignados en manicura</span>
      </div>
      <div v-else class="mpv__lote-pills">
        <button
          v-for="l in lotes" :key="l.id"
          class="mpv__lote-pill"
          :class="{ 'mpv__lote-pill--active': loteSeleccionado?.id === l.id }"
          @click="seleccionarLote(l)"
        >
          <span class="mpv__lote-codigo">{{ l.codigo }}</span>
          <span class="mpv__lote-cepa">{{ l.genetica?.nombre }}</span>
        </button>
      </div>
    </div>

    <template v-if="loteSeleccionado">

      <!-- Loading pesajes -->
      <div v-if="loadingPesajes" class="mpv__loading"><DsSpinner /></div>

      <template v-else>

        <!-- CTA crear pesaje del día -->
        <div class="mpv__cta" v-if="!pesajeBorrador">
          <div class="mpv__cta-ico"><CalendarPlus :size="22" :stroke-width="1.5" /></div>
          <div class="mpv__cta-body">
            <p class="mpv__cta-title">Iniciar jornada de hoy</p>
            <p class="mpv__cta-sub">Creá un pesaje para registrar las plantas que manicurés hoy.</p>
          </div>
          <button class="mpv__btn-new" :disabled="creando" @click="crearPesaje">
            <DsSpinner v-if="creando" :size="14" />
            <Plus v-else :size="14" :stroke-width="2" />
            Nuevo pesaje
          </button>
        </div>

        <!-- Pesaje en borrador (activo hoy) -->
        <div v-if="pesajeBorrador" class="mpv__active-card">
          <div class="mpv__active-head">
            <div class="mpv__active-ico"><Scale :size="16" :stroke-width="1.75" /></div>
            <div>
              <p class="mpv__active-title">Jornada de hoy</p>
              <p class="mpv__active-date">{{ fmtDate(pesajeBorrador.fecha_pesaje) }}</p>
            </div>
            <span class="mpv__badge mpv__badge--borrador">En progreso</span>
          </div>

          <div class="mpv__active-kpis">
            <div class="mpv__akpi">
              <span class="mpv__akpi-val">{{ pesajeBorrador.plantas_registradas || 0 }}</span>
              <span class="mpv__akpi-lbl">Plantas</span>
            </div>
            <div class="mpv__akpi">
              <span class="mpv__akpi-val">{{ (pesajeBorrador.peso_calculado_g || 0).toFixed(1) }}<span class="mpv__akpi-unit">g</span></span>
              <span class="mpv__akpi-lbl">Peso acumulado</span>
            </div>
            <div v-if="loteSeleccionado.plants_count" class="mpv__akpi">
              <span class="mpv__akpi-val">{{ Math.max(0, loteSeleccionado.plants_count - (pesajesConfirmadosCount)) }}</span>
              <span class="mpv__akpi-lbl">Restantes</span>
            </div>
          </div>

          <!-- Notas -->
          <div class="mpv__active-notas">
            <label class="mpv__active-notas-lbl">Notas del día <span class="mpv__opt">opcional</span></label>
            <textarea
              v-model="notasBorrador"
              class="mpv__textarea"
              rows="2"
              placeholder="Observaciones de la jornada…"
            ></textarea>
          </div>

          <div class="mpv__active-actions">
            <button
              class="mpv__btn-enviar"
              :disabled="enviando || (pesajeBorrador.plantas_registradas || 0) === 0"
              @click="cerrarDia"
            >
              <DsSpinner v-if="enviando" :size="14" />
              <Send v-else :size="14" :stroke-width="2" />
              Cerrar día y enviar
            </button>
          </div>

          <p v-if="(pesajeBorrador.plantas_registradas || 0) === 0" class="mpv__hint mpv__hint--warn">
            ⚠️ Registrá al menos una planta antes de cerrar el día.
            Usá el QR de cada planta para registrar el peso individual.
          </p>
        </div>

        <!-- Historial de pesajes enviados/confirmados -->
        <div v-if="pesajesHistorial.length" class="mpv__historial">
          <h2 class="mpv__section-title"><List :size="12" :stroke-width="2" /> Historial de jornadas</h2>
          <div class="mpv__hist-list">
            <div v-for="p in pesajesHistorial" :key="p.id" class="mpv__hist-row">
              <div class="mpv__hist-date">{{ fmtDate(p.fecha_pesaje) }}</div>
              <div class="mpv__hist-info">
                <span>{{ p.plantas_registradas || 0 }} plantas</span>
                <span>{{ (p.peso_total_g || p.peso_calculado_g || 0).toFixed(1) }}g</span>
              </div>
              <span class="mpv__badge" :class="badgeClass(p.estado)">
                {{ estadoLabel(p.estado) }}
              </span>
              <div v-if="p.estado === 'confirmado'" class="mpv__hist-confirmado">
                <CheckCircle :size="12" :stroke-width="2" />
                {{ (p.peso_confirmado_g || 0).toFixed(1) }}g confirmados
              </div>
              <button
                v-if="p.estado === 'enviado'"
                class="mpv__hist-act"
                :disabled="reabriendo === p.id"
                title="Reabrir para corregir"
                @click="reabrirPesaje(p)"
              >
                <Undo2 :size="14" :stroke-width="2" />
              </button>
              <button
                v-if="p.estado !== 'confirmado'"
                class="mpv__hist-del"
                :disabled="borrando === p.id"
                title="Borrar jornada"
                @click="borrarPesaje(p)"
              >
                <Trash2 :size="14" :stroke-width="2" />
              </button>
            </div>
          </div>
        </div>

        <!-- Vacío historial -->
        <div v-else-if="!pesajeBorrador" class="mpv__empty">
          <Scale :size="28" :stroke-width="1.25" />
          <p>Todavía no hay pesajes para este lote.</p>
          <span>Iniciá la primera jornada para comenzar a registrar.</span>
        </div>

      </template>
    </template>

  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import DsSpinner from '../../design-system/components/Spinner.vue'
import { Scale, Wind, Plus, Send, List, CheckCircle, CalendarPlus, Trash2, Undo2 } from 'lucide-vue-next'
import {
  listLotes,
  listPesajesManicura,
  createPesajeManicura,
  enviarPesajeManicura,
  deletePesajeManicura,
  reabrirPesajeManicura,
} from '../../lib/api.js'
import { useToast } from '../../composables/useToast.js'
import { useConfirm } from '../../composables/useConfirm.js'
import { useAuthStore } from '../../stores/auth.js'

const toast = useToast()
const { confirm } = useConfirm()
const auth  = useAuthStore()

const loadingLotes  = ref(true)
const lotes         = ref([])
const loteSeleccionado = ref(null)
const loadingPesajes = ref(false)
const pesajes        = ref([])
const creando        = ref(false)
const enviando       = ref(false)
const notasBorrador  = ref('')

const pesajeBorrador = computed(() =>
  pesajes.value.find(p => p.estado === 'borrador')
)
const pesajesHistorial = computed(() =>
  pesajes.value.filter(p => p.estado !== 'borrador')
)
const pesajesConfirmadosCount = computed(() =>
  pesajes.value
    .filter(p => p.estado === 'confirmado')
    .reduce((s, p) => s + (p.plantas_registradas || 0), 0)
)

async function cargarLotes() {
  loadingLotes.value = true
  try {
    const { data } = await listLotes({ estado: 'en_manicura' })
    lotes.value = (data || []).filter(l =>
      !l.manicurador_id || l.manicurador_id === auth.user?.id
    )
    if (lotes.value.length === 1 && !loteSeleccionado.value) {
      await seleccionarLote(lotes.value[0])
    }
  } catch {
    lotes.value = []
  } finally {
    loadingLotes.value = false
  }
}

async function seleccionarLote(lote) {
  loteSeleccionado.value = lote
  await cargarPesajes()
}

async function cargarPesajes() {
  if (!loteSeleccionado.value) return
  loadingPesajes.value = true
  try {
    const { data } = await listPesajesManicura(loteSeleccionado.value.id)
    pesajes.value = data || []
    const borrador = pesajes.value.find(p => p.estado === 'borrador')
    notasBorrador.value = borrador?.notas || ''
  } catch {
    pesajes.value = []
  } finally {
    loadingPesajes.value = false
  }
}

async function crearPesaje() {
  if (creando.value || !loteSeleccionado.value) return
  creando.value = true
  try {
    const { data } = await createPesajeManicura(loteSeleccionado.value.id)
    pesajes.value.unshift(data)
    toast.success('Jornada iniciada — podés empezar a pesar plantas con el QR')
  } catch (e) {
    toast.error(e.response?.data?.error || 'Error al crear el pesaje')
  } finally {
    creando.value = false
  }
}

async function cerrarDia() {
  const p = pesajeBorrador.value
  if (!p || enviando.value) return
  enviando.value = true
  try {
    await enviarPesajeManicura(loteSeleccionado.value.id, p.id)
    toast.success('Jornada enviada para aprobación del admin')
    await cargarPesajes()
  } catch (e) {
    toast.error(e.response?.data?.error || 'Error al enviar el pesaje')
  } finally {
    enviando.value = false
  }
}

const reabriendo = ref(null)
async function reabrirPesaje(p) {
  if (p.estado !== 'enviado') return
  reabriendo.value = p.id
  try {
    await reabrirPesajeManicura(loteSeleccionado.value.id, p.id)
    toast.success('Jornada reabierta — podés corregirla y volver a enviar')
    await cargarPesajes()
  } catch (e) {
    toast.error(e.response?.data?.error || 'No se pudo reabrir')
  } finally {
    reabriendo.value = null
  }
}

const borrando = ref(null)
async function borrarPesaje(p) {
  if (p.estado === 'confirmado') return
  const ok = await confirm({
    title: 'Borrar jornada',
    message: `¿Borrar esta jornada del ${fmtDate(p.fecha_pesaje)}? Esta acción no se puede deshacer.`,
    confirmText: 'Borrar', danger: true,
  })
  if (!ok) return
  borrando.value = p.id
  try {
    await deletePesajeManicura(loteSeleccionado.value.id, p.id)
    toast.success('Jornada borrada')
    await cargarPesajes()
  } catch (e) {
    toast.error(e.response?.data?.error || 'No se pudo borrar')
  } finally {
    borrando.value = null
  }
}

function fmtDate(d) {
  if (!d) return '—'
  const dt = new Date(d)
  return dt.toLocaleDateString('es-AR', { weekday: 'short', day: 'numeric', month: 'short' })
}

function estadoLabel(estado) {
  return { borrador: 'En progreso', enviado: 'Enviado', confirmado: 'Confirmado' }[estado] || estado
}

function badgeClass(estado) {
  return {
    'mpv__badge--borrador':   estado === 'borrador',
    'mpv__badge--enviado':    estado === 'enviado',
    'mpv__badge--confirmado': estado === 'confirmado',
  }
}

onMounted(cargarLotes)
</script>

<style scoped>
.mpv { padding: var(--sp-6); max-width: 700px; margin: 0 auto; }

/* Header */
.mpv__eyebrow {
  display: inline-flex; align-items: center; gap: var(--sp-1);
  font-size: var(--fs-11); font-weight: 700; text-transform: uppercase;
  letter-spacing: .08em; color: #5C7A4A; margin: 0 0 var(--sp-2);
}
.mpv__title { font-size: var(--fs-24); font-weight: 800; color: var(--c-ink-900); margin: 0 0 var(--sp-1); }
.mpv__sub   { font-size: var(--fs-14); color: var(--c-ink-500); margin: 0 0 var(--sp-5); }

/* Lote selector */
.mpv__lote-wrap { margin-bottom: var(--sp-5); }
.mpv__lote-label {
  font-size: var(--fs-11); font-weight: 700; text-transform: uppercase;
  letter-spacing: .07em; color: var(--c-ink-400); margin-bottom: var(--sp-2);
}
.mpv__empty-lotes {
  display: flex; align-items: center; gap: var(--sp-2);
  font-size: var(--fs-13); color: var(--c-ink-400); padding: var(--sp-3) 0;
}
.mpv__lote-pills { display: flex; flex-wrap: wrap; gap: var(--sp-2); }
.mpv__lote-pill {
  display: flex; flex-direction: column; align-items: flex-start;
  background: var(--c-paper); border: 1.5px solid var(--c-ink-200);
  border-radius: var(--r-md); padding: var(--sp-2) var(--sp-4);
  cursor: pointer; transition: all .15s;
}
.mpv__lote-pill:hover { border-color: #5C7A4A; }
.mpv__lote-pill--active { border-color: #5C7A4A; background: #f6faf4; }
.mpv__lote-codigo { font-size: var(--fs-13); font-weight: 700; color: var(--c-ink-900); font-family: var(--font-mono, monospace); }
.mpv__lote-cepa   { font-size: var(--fs-12); color: var(--c-ink-500); }

/* Loading */
.mpv__loading { display: flex; justify-content: center; padding: 2rem; }

/* CTA new pesaje */
.mpv__cta {
  display: flex; align-items: center; gap: var(--sp-4);
  background: var(--c-paper); border: 1.5px dashed #d4e6d4;
  border-radius: var(--r-lg); padding: var(--sp-4) var(--sp-5);
  margin-bottom: var(--sp-4);
}
.mpv__cta-ico { color: #5C7A4A; flex-shrink: 0; opacity: .7; }
.mpv__cta-body { flex: 1; min-width: 0; }
.mpv__cta-title { font-size: var(--fs-14); font-weight: 700; color: var(--c-ink-900); margin: 0 0 2px; }
.mpv__cta-sub   { font-size: var(--fs-12); color: var(--c-ink-500); margin: 0; }
.mpv__btn-new {
  display: inline-flex; align-items: center; gap: var(--sp-2);
  background: #5C7A4A; color: #fff; border: none;
  padding: .5rem 1rem; border-radius: var(--r-sm);
  font-size: var(--fs-13); font-weight: 600; cursor: pointer;
  white-space: nowrap; transition: background .15s;
}
.mpv__btn-new:hover:not(:disabled) { background: #4a6239; }
.mpv__btn-new:disabled { opacity: .5; cursor: not-allowed; }

/* Active pesaje card */
.mpv__active-card {
  background: #f6faf4; border: 1.5px solid #cfe3c8;
  border-radius: var(--r-lg); padding: var(--sp-5);
  margin-bottom: var(--sp-4);
}
.mpv__active-head {
  display: flex; align-items: center; gap: var(--sp-3);
  margin-bottom: var(--sp-4);
}
.mpv__active-ico {
  width: 36px; height: 36px; border-radius: var(--r-sm);
  background: #dcfce7; color: #5C7A4A;
  display: flex; align-items: center; justify-content: center; flex-shrink: 0;
}
.mpv__active-title { font-size: var(--fs-14); font-weight: 700; color: #14532d; margin: 0 0 1px; }
.mpv__active-date  { font-size: var(--fs-12); color: #5C7A4A; margin: 0; }

.mpv__active-kpis {
  display: flex; gap: var(--sp-6); margin-bottom: var(--sp-4);
  background: rgba(255,255,255,.6); border-radius: var(--r-sm); padding: var(--sp-3) var(--sp-4);
}
.mpv__akpi { display: flex; flex-direction: column; gap: 2px; }
.mpv__akpi-val {
  font-size: var(--fs-22); font-weight: 800; color: #14532d; line-height: 1;
}
.mpv__akpi-unit { font-size: var(--fs-13); font-weight: 500; color: #5C7A4A; }
.mpv__akpi-lbl  { font-size: var(--fs-11); font-weight: 600; text-transform: uppercase; letter-spacing: .06em; color: #5C7A4A; }

.mpv__active-notas { margin-bottom: var(--sp-4); }
.mpv__active-notas-lbl {
  display: block; font-size: var(--fs-11); font-weight: 700; text-transform: uppercase;
  letter-spacing: .06em; color: #4a6239; margin-bottom: var(--sp-1);
}
.mpv__textarea {
  width: 100%; box-sizing: border-box;
  background: rgba(255,255,255,.7); border: 1.5px solid #cfe3c8;
  border-radius: var(--r-sm); padding: var(--sp-2) var(--sp-3);
  font-size: var(--fs-13); color: #1e1b4b; outline: none;
  resize: vertical; min-height: 56px; font-family: inherit;
  transition: border-color .15s;
}
.mpv__textarea:focus { border-color: #5C7A4A; background: #fff; }

.mpv__active-actions { display: flex; justify-content: flex-end; }
.mpv__btn-enviar {
  display: inline-flex; align-items: center; gap: var(--sp-2);
  background: #5C7A4A; color: #fff; border: none;
  padding: .6rem 1.25rem; border-radius: var(--r-sm);
  font-size: var(--fs-13); font-weight: 700; cursor: pointer;
  transition: background .15s;
}
.mpv__btn-enviar:hover:not(:disabled) { background: #4a6239; }
.mpv__btn-enviar:disabled { opacity: .5; cursor: not-allowed; }

.mpv__hint { font-size: var(--fs-12); color: var(--c-ink-400); margin-top: var(--sp-3); }
.mpv__hint--warn { color: #b45309; }
.mpv__opt { font-size: var(--fs-11); font-weight: 400; color: var(--c-ink-400); text-transform: none; letter-spacing: 0; }

/* Historial */
.mpv__section-title {
  display: flex; align-items: center; gap: var(--sp-2);
  font-size: var(--fs-11); font-weight: 700; text-transform: uppercase; letter-spacing: .07em;
  color: var(--c-ink-500); margin: 0 0 var(--sp-3);
}
.mpv__hist-list {
  display: flex; flex-direction: column;
  border: 1px solid #e2e8f0; border-radius: var(--r-md); overflow: hidden;
}
.mpv__hist-row {
  display: flex; align-items: center; gap: var(--sp-4);
  background: var(--c-paper); border-bottom: 1px solid #e2e8f0;
  padding: var(--sp-3) var(--sp-4);
}
.mpv__hist-row:nth-child(even) { background: #fafcf9; }
.mpv__hist-row:last-child { border-bottom: none; }
.mpv__hist-date { font-size: var(--fs-12); color: var(--c-ink-600); font-weight: 600; min-width: 90px; }
.mpv__hist-info {
  flex: 1; display: flex; gap: var(--sp-4);
  font-size: var(--fs-13); color: var(--c-ink-700);
}
.mpv__hist-info span { font-weight: 500; }
.mpv__hist-confirmado {
  display: inline-flex; align-items: center; gap: 4px;
  font-size: var(--fs-12); color: #16a34a; font-weight: 600;
}
.mpv__hist-del, .mpv__hist-act {
  display: inline-flex; align-items: center; justify-content: center;
  background: transparent; border: none; cursor: pointer;
  color: var(--c-ink-300, #cbd5e1); padding: 4px; border-radius: 6px;
  transition: all .15s;
}
.mpv__hist-del:hover:not(:disabled) { background: #fef2f2; color: #dc2626; }
.mpv__hist-act:hover:not(:disabled) { background: #eef5ea; color: #5C7A4A; }
.mpv__hist-del:disabled, .mpv__hist-act:disabled { opacity: .4; cursor: not-allowed; }

/* Badges */
.mpv__badge {
  font-size: var(--fs-11); font-weight: 700; padding: .2em .65em;
  border-radius: 999px; text-transform: uppercase; letter-spacing: .04em; flex-shrink: 0;
}
.mpv__badge--borrador   { background: #fffbeb; color: #b45309; }
.mpv__badge--enviado    { background: #e0f2fe; color: #0369a1; }
.mpv__badge--confirmado { background: #dcfce7; color: #15803d; }

/* Empty */
.mpv__empty {
  display: flex; flex-direction: column; align-items: center; gap: var(--sp-2);
  padding: var(--sp-10) var(--sp-6); color: var(--c-ink-300); text-align: center;
}
.mpv__empty p    { font-size: var(--fs-14); font-weight: 600; color: var(--c-ink-600); margin: 0; }
.mpv__empty span { font-size: var(--fs-13); color: var(--c-ink-400); }
</style>
