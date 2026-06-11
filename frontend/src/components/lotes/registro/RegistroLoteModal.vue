<template>
  <Teleport to="body">
    <div v-if="modelValue" class="rls__overlay">
      <div class="rls__modal">

        <!-- Header -->
        <div class="rls__header">
          <div class="rls__header-left">
            <h2 class="rls__title">📋 Registro del lote</h2>
            <span class="rls__subtitle">{{ lote?.codigo }} · {{ fechaHoy }}</span>
          </div>
          <div class="rls__header-right">
            <AsistenteVoz
              v-if="voiceEnabled && contextoAsistente"
              :contexto="contextoAsistente"
              :mini="true"
              @registrado="$emit('update:modelValue', false)"
            />
            <button class="rls__close" @click="$emit('update:modelValue', false)">✕</button>
          </div>
        </div>

        <!-- Barra "ya registraste hoy" -->
        <div v-if="registrosHoy.length" class="rls__today-bar">
          Hoy ya registraste:
          <span v-for="r in registrosHoy" :key="r" class="rls__today-chip">{{ getAccion(r)?.emoji }} {{ getAccion(r)?.label }}</span>
        </div>

        <!-- Body -->
        <div class="rls__body">
          <transition name="rls__paso">

            <!-- PASO 1: Selección -->
            <div v-if="paso === 1" key="paso1" class="rls__paso rls__paso--sel">
              <p class="rls__paso-hint">¿Qué realizaste hoy? Seleccioná una o más acciones</p>

              <div class="rls__acciones-grid">
                <button
                  v-for="accion in ACCIONES"
                  :key="accion.id"
                  type="button"
                  class="rls__accion-card"
                  :class="{ 'rls__accion-card--sel': seleccionadas.includes(accion.id) }"
                  @click="toggleAccion(accion.id)"
                >
                  <span class="rls__accion-icon">{{ accion.emoji }}</span>
                  <span class="rls__accion-label">{{ accion.label }}</span>
                </button>
              </div>

              <!-- Estado general (siempre en paso 1) -->
              <div class="rls__seccion-titulo" style="margin-top: var(--sp-5)">Estado general</div>
              <div class="rls__radio-group">
                <button v-for="(meta, key) in ESTADO_SALUD" :key="key" type="button"
                        class="rls__radio-btn"
                        :class="{ 'rls__radio-btn--sel': formData.estado_general === key }"
                        :style="formData.estado_general === key ? { borderColor: meta.color, background: meta.color + '18', color: meta.color } : {}"
                        @click="formData.estado_general = key">
                  {{ meta.emoji }} {{ key }}
                </button>
              </div>

              <!-- Plagas general -->
              <div class="rls__seccion-titulo" style="margin-top: var(--sp-4)">Plagas observadas</div>
              <div class="rls__radio-group">
                <button v-for="(meta, key) in PLAGAS_META" :key="key" type="button"
                        class="rls__radio-btn"
                        :class="{ 'rls__radio-btn--sel': formData.plagas_observadas === key }"
                        :style="formData.plagas_observadas === key ? { borderColor: meta.color, background: meta.color + '18', color: meta.color } : {}"
                        @click="formData.plagas_observadas = key">
                  {{ meta.emoji }} {{ key }}
                </button>
              </div>
            </div>

            <!-- PASO 2: Formularios por acción -->
            <div v-else key="paso2" class="rls__paso rls__paso--detalle">
              <button class="rls__back-btn" type="button" @click="paso = 1">
                ← Cambiar acciones
              </button>

              <div v-for="accionId in seleccionadas" :key="accionId" class="rls__seccion">
                <div class="rls__seccion-header">
                  <span>{{ getAccion(accionId)?.emoji }} {{ getAccion(accionId)?.label }}</span>
                </div>
                <div class="rls__seccion-body">
                  <RiegoForm      v-if="accionId === 'riego'"     v-model="formData.riego" />
                  <PodaForm       v-if="accionId === 'poda'"      v-model="formData.poda" :total-plantas="lote?.plants_count" />
                  <PlagasForm     v-if="accionId === 'plagas'"    v-model="formData.plagas" />
                  <AmbientalForm  v-if="accionId === 'ambiental'" v-model="formData.ambiental" />
                  <LuzForm        v-if="accionId === 'luz'"       v-model="formData.luz" />
                  <LimpiezaForm   v-if="accionId === 'limpieza'"  v-model="formData.limpieza" />
                  <TrasplanteForm v-if="accionId === 'trasplante'" v-model="formData.trasplante" :total-plantas="lote?.plants_count" :plants="plants" />
                </div>
              </div>

              <!-- Observaciones generales siempre visibles -->
              <div class="rls__field" style="margin-top: var(--sp-4)">
                <label class="rls__label">Observaciones generales <span class="rls__optional">opcional</span></label>
                <textarea class="rls__textarea" rows="3" v-model.trim="formData.observaciones"
                          placeholder="Cualquier observación relevante del día…"></textarea>
              </div>
            </div>

          </transition>
        </div>

        <!-- Error -->
        <div v-if="error" class="rls__error">{{ error }}</div>

        <!-- Footer -->
        <div class="rls__footer">
          <button type="button" class="rls__btn-cancel" @click="$emit('update:modelValue', false)">Cancelar</button>
          <button v-if="paso === 1" type="button" class="rls__btn-next"
                  :disabled="!seleccionadas.length"
                  @click="irPaso2">
            Continuar → ({{ seleccionadas.length }})
          </button>
          <button v-if="paso === 2" type="button" class="rls__btn-save"
                  :disabled="saving"
                  @click="guardar">
            <DsSpinner v-if="saving" :size="14" />
            <i v-else class="bi bi-check-lg"></i>
            Guardar registro
          </button>
        </div>

      </div>
    </div>
  </Teleport>
</template>

<script setup>
import { ref, computed, watch } from 'vue'
import { updateLote, createPlantActivity, createRegistroAmbiental } from '../../../lib/api'
import { registrarLecturaOffline } from '../../../lib/offlineApi.js'
import { useToast }   from '../../../composables/useToast.js'
import { useClubStore } from '../../../stores/club'
import DsSpinner      from '../../../design-system/components/Spinner.vue'
import AsistenteVoz   from '../../AsistenteVoz.vue'
import RiegoForm      from './RiegoForm.vue'
import PodaForm       from './PodaForm.vue'
import PlagasForm     from './PlagasForm.vue'
import AmbientalForm  from './AmbientalForm.vue'
import LuzForm        from './LuzForm.vue'
import LimpiezaForm   from './LimpiezaForm.vue'
import TrasplanteForm from './TrasplanteForm.vue'

const props = defineProps({
  modelValue:  { type: Boolean, default: false },
  lote:        { type: Object,  default: null },
  registrosHoy:{ type: Array,   default: () => [] },
  plants:      { type: Array,   default: () => [] },
})
const emit = defineEmits(['update:modelValue', 'saved'])

const toast = useToast()
const club  = useClubStore()

// ── Acciones ─────────────────────────────────────────────────────────────────
const ACCIONES = [
  { id: 'riego',      emoji: '💧', label: 'Riego' },
  { id: 'poda',       emoji: '✂️', label: 'Poda' },
  { id: 'plagas',     emoji: '🔍', label: 'Rev. Plagas' },
  { id: 'ambiental',  emoji: '🌡️', label: 'Ambiental' },
  { id: 'luz',        emoji: '💡', label: 'Luz' },
  { id: 'limpieza',   emoji: '🧹', label: 'Limpieza' },
  { id: 'trasplante', emoji: '🪴', label: 'Trasplante' },
]

const ESTADO_SALUD = {
  excelente: { color: '#15803d', emoji: '🟢' },
  bueno:     { color: '#65a30d', emoji: '🟡' },
  regular:   { color: '#d97706', emoji: '🟠' },
  malo:      { color: '#dc2626', emoji: '🔴' },
  critico:   { color: '#7f1d1d', emoji: '🚨' },
}
const PLAGAS_META = {
  ninguna:  { color: '#15803d', emoji: '✅' },
  leve:     { color: '#d97706', emoji: '⚠️' },
  moderada: { color: '#ea580c', emoji: '🐛' },
  severa:   { color: '#dc2626', emoji: '🚨' },
}

function getAccion(id) { return ACCIONES.find(a => a.id === id) }

// ── State ─────────────────────────────────────────────────────────────────────
const paso        = ref(1)
const seleccionadas = ref([])
const saving      = ref(false)
const error       = ref(null)

function emptyFormData() {
  return {
    estado_general:   'bueno',
    plagas_observadas:'ninguna',
    observaciones:    '',
    riego:      { ph: null, ph_runoff: null, ec: null, volumen: null, fertilizo: false, producto: '', dosis: null, semana_nutricion: null, metodo_nutricion: '', observaciones: '' },
    poda:       { tipos: [], intensidad: '', plantas_intervenidas: null, observaciones: '' },
    plagas:     { resultado: 'ninguna', tipos_detectados: [], accion_tomada: '', plantas_afectadas: null, producto_usado: '' },
    ambiental:  { temperatura: null, temperatura_sustrato: null, humedad: null, co2: null, csvFile: null },
    luz:        { horas_luz: null, espectro: '', intensidad: null, cambio_altura: false, distancia: null },
    limpieza:   { tipo: 'rutinaria', producto_usado: '' },
    trasplante: { maceta_origen_l: null, maceta_destino_l: null, sustrato: 'mismo', sustrato_descripcion: '', todas_plantas: true, plantas_seleccionadas: [], estado_raices: '', observaciones: '' },
  }
}

const formData = ref(emptyFormData())

// Pre-cargar maceta_origen_l del lote al abrir
watch(() => props.modelValue, (open) => {
  if (!open) return
  paso.value = 1
  seleccionadas.value = []
  error.value = null
  formData.value = emptyFormData()
  if (props.lote?.tamanio_maceta) {
    formData.value.trasplante.maceta_origen_l = props.lote.tamanio_maceta
  }
})

const fechaHoy = new Date().toLocaleDateString('es-AR', { day: 'numeric', month: 'long' })

const voiceEnabled = computed(() => club.data?.features?.ia_voz)
const contextoAsistente = computed(() => {
  if (!props.lote) return null
  return {
    tipo:         'lote',
    lote_id:      props.lote.id,
    lote_codigo:  props.lote.codigo,
    sala_nombre:  props.lote.sala?.nombre,
    plantas_count:props.lote.plants_count,
  }
})

function toggleAccion(id) {
  const idx = seleccionadas.value.indexOf(id)
  if (idx === -1) seleccionadas.value.push(id)
  else seleccionadas.value.splice(idx, 1)
}

function irPaso2() {
  if (!seleccionadas.value.length) return
  paso.value = 2
}

// ── Build API payload ─────────────────────────────────────────────────────────
function buildPayload() {
  const fd = formData.value
  const sel = seleccionadas.value
  const payload = {
    estado_general:    fd.estado_general,
    plagas_observadas: fd.plagas_observadas,
    observaciones:     fd.observaciones,
    tareas_realizadas: [],
  }
  const extra = []

  if (sel.includes('riego')) {
    const r = fd.riego
    payload.tareas_realizadas.push('riego')
    if (r.ph)       payload.ph       = r.ph
    if (r.ph_runoff)payload.ph_runoff = r.ph_runoff
    if (r.ec)       payload.ec       = r.ec
    if (r.fertilizo) {
      payload.tareas_realizadas.push('nutricion')
      payload.fertilizacion = true
      const parts = [r.producto, r.dosis ? `${r.dosis}ml/L` : null, r.semana_nutricion ? `sem.${r.semana_nutricion}` : null, r.metodo_nutricion || null].filter(Boolean)
      payload.notas_fertilizacion = parts.join(' · ')
    }
    if (r.volumen)       extra.push(`Riego: ${r.volumen}L`)
    if (r.observaciones) extra.push(r.observaciones)
  }

  if (sel.includes('poda')) {
    const p = fd.poda
    payload.tareas_realizadas.push('poda')
    const info = [
      p.tipos?.length ? p.tipos.join(', ') : null,
      p.intensidad || null,
      p.plantas_intervenidas ? `${p.plantas_intervenidas} plantas` : null,
    ].filter(Boolean)
    if (info.length) extra.push(`Poda: ${info.join(' · ')}`)
    if (p.observaciones) extra.push(p.observaciones)
  }

  if (sel.includes('plagas')) {
    const pl = fd.plagas
    payload.tareas_realizadas.push('revision_plagas')
    if (pl.resultado) payload.plagas_observadas = pl.resultado
    const info = [
      pl.tipos_detectados?.length ? pl.tipos_detectados.join(', ') : null,
      pl.accion_tomada || null,
      pl.producto_usado || null,
      pl.plantas_afectadas ? `${pl.plantas_afectadas} plantas afectadas` : null,
    ].filter(Boolean)
    if (info.length) extra.push(`Plagas: ${info.join(' · ')}`)
  }

  if (sel.includes('ambiental')) {
    const a = fd.ambiental
    payload.tareas_realizadas.push('registro_ambiental')
    if (a.temperatura)          payload.temperatura          = a.temperatura
    if (a.temperatura_sustrato) payload.temperatura_sustrato = a.temperatura_sustrato
    if (a.humedad)              payload.humedad              = a.humedad
    if (a.co2)                  payload.co2                  = a.co2
  }

  if (sel.includes('luz')) {
    const l = fd.luz
    payload.tareas_realizadas.push('ajuste_luz')
    if (l.horas_luz) payload.horas_luz  = l.horas_luz
    if (l.espectro)  payload.espectro_luz = l.espectro
    const info = [
      l.intensidad ? `${l.intensidad} PPFD` : null,
      l.cambio_altura && l.distancia ? `Distancia: ${l.distancia}cm` : null,
    ].filter(Boolean)
    if (info.length) extra.push(`Luz: ${info.join(' · ')}`)
  }

  if (sel.includes('limpieza')) {
    const li = fd.limpieza
    payload.tareas_realizadas.push('limpieza_sala')
    extra.push(`Limpieza: ${li.tipo}${li.producto_usado ? ` (${li.producto_usado})` : ''}`)
  }

  if (extra.length) {
    payload.observaciones = [payload.observaciones, ...extra].filter(Boolean).join('\n')
  }

  return payload
}

async function guardar() {
  saving.value = true
  error.value  = null
  try {
    const fd = formData.value
    const sel = seleccionadas.value

    // Trasplante: API separada
    if (sel.includes('trasplante')) {
      const t = fd.trasplante
      if (!t.maceta_destino_l) { error.value = 'Ingresá el tamaño de maceta destino'; saving.value = false; return }
      if (!t.todas_plantas && !t.plantas_seleccionadas.length) { error.value = 'Seleccioná al menos una planta para trasplantar'; saving.value = false; return }
      await updateLote(props.lote.id, { tamanio_maceta: parseFloat(t.maceta_destino_l) })
      if (!t.todas_plantas && t.plantas_seleccionadas.length) {
        for (const plantId of t.plantas_seleccionadas) {
          await createPlantActivity(plantId, { tipo: 'trasplante', descripcion: `Trasplante a maceta ${t.maceta_destino_l}L` })
        }
      }
    }

    // Registro ambiental
    const restAcciones = sel.filter(s => s !== 'trasplante')
    const payload = buildPayload()

    // CSV del formulario ambiental
    const csvFile = fd.ambiental?.csvFile
    if (csvFile) {
      const form = new FormData()
      Object.entries(payload).forEach(([k, v]) => {
        if (k === 'tareas_realizadas') {
          v.forEach(t => form.append('registro_ambiental[tareas_realizadas][]', t))
        } else if (v !== null && v !== undefined && v !== '') {
          form.append(`registro_ambiental[${k}]`, v)
        }
      })
      form.append('archivo_csv', csvFile)
      await createRegistroAmbiental(props.lote.id, form, true)
    } else {
      if (restAcciones.length > 0 || payload.observaciones) {
        await registrarLecturaOffline({ loteId: props.lote.id, payload })
      }
    }

    const n = seleccionadas.value.length
    toast.success(`Registro guardado · ${n} acción${n !== 1 ? 'es' : ''}`)
    emit('update:modelValue', false)
    emit('saved')
  } catch (e) {
    error.value = e?.response?.data?.errors?.join(', ') || e?.response?.data?.error || 'Error al guardar'
  } finally {
    saving.value = false
  }
}
</script>

<style scoped>
/* ── Overlay + Modal ───────────────────────────────────────────────────────── */
.rls__overlay {
  position: fixed; inset: 0; background: rgba(0,0,0,.45); backdrop-filter: blur(3px);
  display: flex; align-items: center; justify-content: center;
  z-index: 1050; padding: var(--sp-4);
}
.rls__modal {
  background: #fff; border-radius: 20px; width: 100%; max-width: 640px;
  max-height: 92vh; display: flex; flex-direction: column;
  box-shadow: 0 32px 80px rgba(0,0,0,.18);
  overflow: hidden;
}

/* ── Header ────────────────────────────────────────────────────────────────── */
.rls__header {
  display: flex; align-items: center; justify-content: space-between; gap: var(--sp-3);
  padding: var(--sp-5) var(--sp-6) var(--sp-4);
  border-bottom: 1px solid var(--c-ink-100);
  position: sticky; top: 0; background: #fff; z-index: 2; flex-shrink: 0;
}
.rls__header-left { display: flex; flex-direction: column; gap: 2px; }
.rls__title  { font-family: var(--font-display); font-size: var(--fs-18); font-weight: 700; color: var(--c-ink-900); margin: 0; }
.rls__subtitle { font-size: var(--fs-13); color: var(--c-ink-500); }
.rls__header-right { display: flex; align-items: center; gap: var(--sp-2); flex-shrink: 0; }
.rls__close {
  background: var(--c-ink-100); border: none; width: 32px; height: 32px;
  border-radius: var(--r-lg); cursor: pointer; display: flex; align-items: center;
  justify-content: center; font-size: var(--fs-14); color: var(--c-ink-500);
  transition: all var(--t-fast); flex-shrink: 0;
}
.rls__close:hover { background: var(--c-ink-300); color: var(--c-ink-900); }

/* ── Today bar ─────────────────────────────────────────────────────────────── */
.rls__today-bar {
  display: flex; align-items: center; flex-wrap: wrap; gap: var(--sp-2);
  padding: var(--sp-3) var(--sp-6);
  background: var(--c-amber-100, #FEF3C7); border-bottom: 1px solid #fde68a;
  font-size: var(--fs-13); color: var(--c-gold-500, #B45309); flex-shrink: 0;
}
.rls__today-chip {
  background: #fff; border: 1px solid #fcd34d; border-radius: var(--r-pill);
  padding: .15rem .55rem; font-size: .72rem; font-weight: 600; color: #92400e;
}

/* ── Body ──────────────────────────────────────────────────────────────────── */
.rls__body { flex: 1; overflow-y: auto; padding: var(--sp-5) var(--sp-6); }

/* ── Error bar ─────────────────────────────────────────────────────────────── */
.rls__error {
  padding: var(--sp-3) var(--sp-6);
  background: var(--c-rust-100); color: var(--c-rust-600);
  font-size: var(--fs-13); font-weight: 500; flex-shrink: 0;
}

/* ── Footer ────────────────────────────────────────────────────────────────── */
.rls__footer {
  display: flex; justify-content: flex-end; gap: var(--sp-3);
  padding: var(--sp-4) var(--sp-6);
  border-top: 1px solid var(--c-ink-100);
  position: sticky; bottom: 0; background: #fff; z-index: 2; flex-shrink: 0;
}
.rls__btn-cancel {
  background: transparent; color: var(--c-ink-500); border: 1.5px solid var(--c-ink-300);
  padding: .55rem 1.1rem; border-radius: var(--r-lg); font-size: var(--fs-14);
  font-weight: 500; cursor: pointer; transition: all var(--t-fast);
}
.rls__btn-cancel:hover { background: var(--c-ink-100); }
.rls__btn-next {
  display: inline-flex; align-items: center; gap: var(--sp-2);
  background: var(--c-leaf-100, #E8F0EB); color: var(--brand-primary);
  border: 1.5px solid var(--c-leaf-300, #A8C9B5);
  padding: .55rem 1.25rem; border-radius: var(--r-lg);
  font-size: var(--fs-14); font-weight: 700; cursor: pointer; transition: all var(--t-fast);
}
.rls__btn-next:hover:not(:disabled) { background: var(--c-leaf-300); }
.rls__btn-next:disabled { opacity: .45; cursor: not-allowed; }
.rls__btn-save {
  display: inline-flex; align-items: center; gap: var(--sp-2);
  background: var(--brand-primary, #1b5e20); color: #fff; border: none;
  padding: .55rem 1.4rem; border-radius: var(--r-lg);
  font-size: var(--fs-14); font-weight: 700; cursor: pointer; transition: background var(--t-fast);
}
.rls__btn-save:hover:not(:disabled) { background: var(--brand-primary-600, #104417); }
.rls__btn-save:disabled { opacity: .55; cursor: not-allowed; }

/* ── Paso hint ─────────────────────────────────────────────────────────────── */
.rls__paso-hint { font-size: var(--fs-14); color: var(--c-ink-500); margin: 0 0 var(--sp-4); }

/* ── Grilla de acciones ────────────────────────────────────────────────────── */
.rls__acciones-grid {
  display: grid; grid-template-columns: repeat(4, 1fr); gap: var(--sp-3);
  margin-bottom: var(--sp-4);
}
.rls__accion-card {
  display: flex; flex-direction: column; align-items: center; gap: var(--sp-2);
  padding: var(--sp-4) var(--sp-3);
  background: #fff; border: 2px solid var(--c-ink-200, #E5E7EB);
  border-radius: var(--r-xl); cursor: pointer; transition: all var(--t-fast);
  text-align: center;
}
.rls__accion-card:hover {
  border-color: var(--brand-primary); background: var(--c-leaf-50);
}
.rls__accion-card--sel {
  border-color: var(--brand-primary); background: var(--c-leaf-50);
  box-shadow: 0 0 0 3px rgba(27,94,32,.1);
}
.rls__accion-icon { font-size: 1.6rem; line-height: 1; }
.rls__accion-label { font-size: .72rem; font-weight: 700; color: var(--c-ink-700); text-align: center; white-space: nowrap; }
.rls__accion-card--sel .rls__accion-label { color: var(--brand-primary); }

/* ── Estado general / Plagas radios ────────────────────────────────────────── */
.rls__seccion-titulo {
  font-size: .72rem; font-weight: 800; color: var(--c-leaf-600, #3F6452);
  text-transform: uppercase; letter-spacing: .06em;
  margin-bottom: var(--sp-2); padding-bottom: var(--sp-2);
  border-bottom: 1px solid var(--c-leaf-100);
}
.rls__radio-group { display: flex; flex-wrap: wrap; gap: var(--sp-2); }
.rls__radio-btn {
  display: inline-flex; align-items: center; gap: var(--sp-2);
  padding: .4rem .9rem; border: 1.5px solid var(--c-ink-300);
  border-radius: var(--r-lg); font-size: var(--fs-13); color: var(--c-ink-700);
  background: #fff; cursor: pointer; transition: all var(--t-fast); font-weight: 500;
}
.rls__radio-btn:hover { border-color: var(--brand-primary); }
.rls__radio-btn--sel { font-weight: 700; }

/* ── Back button ───────────────────────────────────────────────────────────── */
.rls__back-btn {
  background: none; border: none; padding: 0; color: var(--brand-primary);
  font-size: var(--fs-13); font-weight: 600; cursor: pointer;
  margin-bottom: var(--sp-4); display: inline-flex; align-items: center; gap: var(--sp-1);
}
.rls__back-btn:hover { text-decoration: underline; }

/* ── Sección por acción ────────────────────────────────────────────────────── */
.rls__seccion { border: 1.5px solid var(--c-ink-200, #E5E7EB); border-radius: var(--r-xl); overflow: hidden; margin-bottom: var(--sp-4); }
.rls__seccion-header {
  display: flex; align-items: center; gap: var(--sp-2);
  padding: var(--sp-3) var(--sp-4);
  background: var(--c-leaf-50); border-bottom: 1px solid var(--c-leaf-100);
  font-size: var(--fs-14); font-weight: 700; color: var(--c-leaf-700);
}
.rls__seccion-body { padding: var(--sp-4); }

/* ── Global field / textarea ───────────────────────────────────────────────── */
.rls__field { display: flex; flex-direction: column; gap: .35rem; }
.rls__label { font-size: .72rem; font-weight: 700; color: var(--c-ink-700); text-transform: uppercase; letter-spacing: .04em; display: flex; gap: 6px; }
.rls__optional { font-size: .65rem; font-weight: 500; color: var(--c-ink-500); text-transform: none; letter-spacing: 0; }
.rls__textarea { background: var(--c-ink-100); border: 1.5px solid var(--c-ink-300); border-radius: var(--r-lg); padding: .6rem .85rem; font-size: var(--fs-14); color: var(--c-ink-900); width: 100%; box-sizing: border-box; resize: vertical; font-family: var(--font-ui); }
.rls__textarea:focus { outline: none; border-color: var(--brand-primary); background: #fff; }

/* ── Transición entre pasos ────────────────────────────────────────────────── */
.rls__paso-enter-active, .rls__paso-leave-active { transition: all var(--t-base, .2s); }
.rls__paso-enter-from { opacity: 0; transform: translateX(20px); }
.rls__paso-leave-to   { opacity: 0; transform: translateX(-20px); position: absolute; width: 100%; }

/* ── Mobile ────────────────────────────────────────────────────────────────── */
@media (max-width: 639px) {
  .rls__overlay { align-items: flex-end; padding: 0; }
  .rls__modal { border-radius: 20px 20px 0 0; max-height: 92vh; }
  .rls__acciones-grid { grid-template-columns: repeat(2, 1fr); }
  .rls__body { padding: var(--sp-4); }
  .rls__header { padding: var(--sp-4); }
  .rls__footer { padding: var(--sp-4); }
}
</style>
