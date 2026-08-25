<template>
  <Teleport to="body">
    <div v-modal="() => $emit('update:modelValue', false)" v-if="modelValue" class="rps__overlay">
      <div class="rps__modal">

        <!-- Header -->
        <div class="rps__header">
          <div class="rps__header-left">
            <h2 class="rps__title">📋 Registro de planta</h2>
            <span class="rps__subtitle">{{ planta?.nombre || planta?.codigo_qr }} · {{ fechaHoy }}</span>
          </div>
          <div class="rps__header-right">
            <AsistenteVoz
              v-if="voiceEnabled && contextoAsistente"
              :contexto="contextoAsistente"
              :mini="true"
              @registrado="$emit('update:modelValue', false)"
            />
            <button class="rps__close" @click="$emit('update:modelValue', false)">✕</button>
          </div>
        </div>

        <!-- Barra "ya registraste hoy" -->
        <div v-if="registrosHoy.length" class="rps__today-bar">
          Hoy ya registraste:
          <span v-for="r in registrosHoy" :key="r" class="rps__today-chip">{{ getAccion(r)?.emoji }} {{ getAccion(r)?.label }}</span>
        </div>

        <!-- Body -->
        <div class="rps__body">
          <transition name="rps__paso">

            <!-- PASO 1: Selección -->
            <div v-if="paso === 1" key="paso1" class="rps__paso rps__paso--sel">
              <p class="rps__paso-hint">¿Qué realizaste hoy? Seleccioná una o más acciones</p>

              <div class="rps__acciones-grid">
                <button
                  v-for="accion in ACCIONES"
                  :key="accion.id"
                  type="button"
                  class="rps__accion-card"
                  :class="{ 'rps__accion-card--sel': seleccionadas.includes(accion.id) }"
                  @click="toggleAccion(accion.id)"
                >
                  <span class="rps__accion-icon">{{ accion.emoji }}</span>
                  <span class="rps__accion-label">{{ accion.label }}</span>
                </button>
              </div>

              <!-- Estado general -->
              <div class="rps__seccion-titulo" style="margin-top:1.25rem">Estado general</div>
              <div class="rps__radio-group">
                <button v-for="(meta, key) in ESTADO_SALUD" :key="key" type="button"
                        class="rps__radio-btn"
                        :class="{ 'rps__radio-btn--sel': formData.estado_general === key }"
                        :style="formData.estado_general === key ? { borderColor: meta.color, background: meta.color + '18', color: meta.color } : {}"
                        @click="formData.estado_general = key">
                  {{ meta.emoji }} {{ key }}
                </button>
              </div>

              <!-- Plagas -->
              <div class="rps__seccion-titulo" style="margin-top:1rem">Plagas observadas</div>
              <div class="rps__radio-group">
                <button v-for="(meta, key) in PLAGAS_META" :key="key" type="button"
                        class="rps__radio-btn"
                        :class="{ 'rps__radio-btn--sel': formData.plagas_observadas === key }"
                        :style="formData.plagas_observadas === key ? { borderColor: meta.color, background: meta.color + '18', color: meta.color } : {}"
                        @click="formData.plagas_observadas = key">
                  {{ meta.emoji }} {{ key }}
                </button>
              </div>
            </div>

            <!-- PASO 2: Detalles -->
            <div v-else key="paso2" class="rps__paso rps__paso--detalle">
              <button class="rps__back-btn" type="button" @click="paso = 1">← Cambiar acciones</button>

              <div v-for="accionId in seleccionadas" :key="accionId" class="rps__seccion">
                <div class="rps__seccion-header">
                  <span>{{ getAccion(accionId)?.emoji }} {{ getAccion(accionId)?.label }}</span>
                </div>
                <div class="rps__seccion-body">
                  <RiegoForm     v-if="accionId === 'riego'"     v-model="formData.riego" />
                  <PlagasForm    v-if="accionId === 'plagas'"    v-model="formData.plagas" />
                  <MedicionForm  v-if="accionId === 'medicion'"  v-model="formData.medicion" />
                  <!-- Poda: simple para planta individual -->
                  <div v-if="accionId === 'poda'" class="rps__simple-form">
                    <div class="rps__field">
                      <label class="rps__label">Tipo de poda</label>
                      <select v-model="formData.poda.tipo" class="rps__input">
                        <option value="defoliacion">Defoliación</option>
                        <option value="topping">Topping</option>
                        <option value="lst">LST</option>
                        <option value="scrog">SCROG / Tutoreo</option>
                        <option value="lollipopping">Lollipopping</option>
                        <option value="otro">Otro</option>
                      </select>
                    </div>
                    <div class="rps__field">
                      <label class="rps__label">Observaciones</label>
                      <textarea v-model="formData.poda.observaciones" class="rps__textarea" rows="2" placeholder="Detalles de la poda…"></textarea>
                    </div>
                  </div>
                  <!-- Trasplante: simple para planta individual -->
                  <div v-if="accionId === 'trasplante'" class="rps__simple-form">
                    <div class="rps__row2">
                      <div class="rps__field">
                        <label class="rps__label">Maceta origen (L)</label>
                        <input v-model.number="formData.trasplante.maceta_origen_l" type="number" step="0.5" min="0" class="rps__input" placeholder="—" />
                      </div>
                      <div class="rps__field">
                        <label class="rps__label">Maceta destino (L)</label>
                        <input v-model.number="formData.trasplante.maceta_destino_l" type="number" step="0.5" min="0" class="rps__input" placeholder="—" />
                      </div>
                    </div>
                    <div class="rps__field">
                      <label class="rps__label">Sustrato</label>
                      <select v-model="formData.trasplante.sustrato" class="rps__input">
                        <option value="mismo">Mismo sustrato</option>
                        <option value="nuevo">Sustrato nuevo</option>
                        <option value="mezcla">Mezcla</option>
                      </select>
                    </div>
                  </div>
                </div>
              </div>

              <div class="rps__field" style="margin-top:1rem">
                <label class="rps__label">Observaciones generales <span class="rps__optional">opcional</span></label>
                <textarea class="rps__textarea" rows="3" v-model.trim="formData.observaciones"
                          placeholder="Cualquier observación relevante…"></textarea>
              </div>
            </div>

          </transition>
        </div>

        <div v-if="error" class="rps__error">{{ error }}</div>

        <div class="rps__footer">
          <button type="button" class="rps__btn-cancel" @click="$emit('update:modelValue', false)">Cancelar</button>
          <button v-if="paso === 1" type="button" class="rps__btn-next"
                  :disabled="!seleccionadas.length"
                  @click="paso = 2">
            Continuar → ({{ seleccionadas.length }})
          </button>
          <button v-if="paso === 2" type="button" class="rps__btn-save"
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
import { createPlantActivity, updatePlant } from '../../lib/api'
import { useToast }    from '../../composables/useToast.js'
import { useClubStore } from '../../stores/club'
import DsSpinner       from '../../design-system/components/Spinner.vue'
import AsistenteVoz    from '../AsistenteVoz.vue'
import RiegoForm       from '../lotes/registro/RiegoForm.vue'
import PlagasForm      from '../lotes/registro/PlagasForm.vue'

// Medición inline (EC/pH/temperatura) — simple, no existe como sub-form separado
const MedicionForm = {
  props: { modelValue: { type: Object, default: () => ({}) } },
  emits: ['update:modelValue'],
  setup(props, { emit }) {
    const f = computed({ get: () => props.modelValue, set: v => emit('update:modelValue', v) })
    return { f }
  },
  template: `
    <div style="display:grid;grid-template-columns:1fr 1fr;gap:.75rem">
      <div style="display:flex;flex-direction:column;gap:.3rem">
        <label style="font-size:.72rem;font-weight:700;color:#374151;text-transform:uppercase;letter-spacing:.04em">pH</label>
        <input type="number" step="0.1" min="0" max="14" v-model.number="f.ph" placeholder="6.2" style="background:#f8fafc;border:1.5px solid #e2e8f0;border-radius:9px;padding:.6rem .8rem;font-size:.9rem;outline:none" />
      </div>
      <div style="display:flex;flex-direction:column;gap:.3rem">
        <label style="font-size:.72rem;font-weight:700;color:#374151;text-transform:uppercase;letter-spacing:.04em">EC</label>
        <input type="number" step="0.1" min="0" v-model.number="f.ec" placeholder="1.8" style="background:#f8fafc;border:1.5px solid #e2e8f0;border-radius:9px;padding:.6rem .8rem;font-size:.9rem;outline:none" />
      </div>
      <div style="display:flex;flex-direction:column;gap:.3rem">
        <label style="font-size:.72rem;font-weight:700;color:#374151;text-transform:uppercase;letter-spacing:.04em">Temp. sustrato (°C)</label>
        <input type="number" step="0.5" v-model.number="f.temperatura_sustrato" placeholder="22" style="background:#f8fafc;border:1.5px solid #e2e8f0;border-radius:9px;padding:.6rem .8rem;font-size:.9rem;outline:none" />
      </div>
      <div style="display:flex;flex-direction:column;gap:.3rem">
        <label style="font-size:.72rem;font-weight:700;color:#374151;text-transform:uppercase;letter-spacing:.04em">pH runoff</label>
        <input type="number" step="0.1" min="0" max="14" v-model.number="f.ph_runoff" placeholder="—" style="background:#f8fafc;border:1.5px solid #e2e8f0;border-radius:9px;padding:.6rem .8rem;font-size:.9rem;outline:none" />
      </div>
    </div>
  `,
}

const props = defineProps({
  modelValue:   { type: Boolean, default: false },
  planta:       { type: Object,  default: null },
  registrosHoy: { type: Array,   default: () => [] },
})
const emit = defineEmits(['update:modelValue', 'saved'])

const toast = useToast()
const club  = useClubStore()

const ACCIONES = [
  { id: 'riego',     emoji: '💧', label: 'Riego' },
  { id: 'poda',      emoji: '✂️', label: 'Poda' },
  { id: 'plagas',    emoji: '🔍', label: 'Rev. Plagas' },
  { id: 'medicion',  emoji: '🌡️', label: 'Medición' },
  { id: 'trasplante',emoji: '🪴', label: 'Trasplante' },
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

const paso          = ref(1)
const seleccionadas = ref([])
const saving        = ref(false)
const error         = ref(null)

function emptyFormData() {
  return {
    estado_general:    'bueno',
    plagas_observadas: 'ninguna',
    observaciones:     '',
    riego:     { ph: null, ph_runoff: null, ec: null, volumen: null, fertilizo: false, producto: '', dosis: null },
    plagas:    { resultado: 'ninguna', tipos_detectados: [], accion_tomada: '', plantas_afectadas: null, producto_usado: '' },
    medicion:  { ph: null, ph_runoff: null, ec: null, temperatura_sustrato: null },
    poda:      { tipo: 'defoliacion', observaciones: '' },
    trasplante:{ maceta_origen_l: null, maceta_destino_l: null, sustrato: 'mismo' },
  }
}

const formData = ref(emptyFormData())

watch(() => props.modelValue, (open) => {
  if (!open) return
  paso.value = 1
  seleccionadas.value = []
  error.value = null
  formData.value = emptyFormData()
})

const fechaHoy = new Date().toLocaleDateString('es-AR', { day: 'numeric', month: 'long' })
const voiceEnabled = computed(() => club.data?.features?.ia)
const contextoAsistente = computed(() => props.planta ? {
  tipo: 'planta', planta_id: props.planta.id,
  planta_nombre: props.planta.nombre || props.planta.codigo_qr,
  lote_id: props.planta.lote?.id, lote_codigo: props.planta.lote?.codigo,
} : null)

function toggleAccion(id) {
  const idx = seleccionadas.value.indexOf(id)
  if (idx === -1) seleccionadas.value.push(id)
  else seleccionadas.value.splice(idx, 1)
}

async function guardar() {
  saving.value = true; error.value = null
  const plantId = props.planta?.id
  if (!plantId) { error.value = 'Planta no encontrada'; saving.value = false; return }

  try {
    const fd  = formData.value
    const sel = seleccionadas.value

    // Actividad principal: registro_planta
    const metadata = {
      estado_salud:       fd.estado_general,
      plagas:             fd.plagas_observadas,
      altura_cm:          undefined,
    }

    await createPlantActivity(plantId, {
      activity_type: 'registro_planta',
      metadata,
      description: fd.observaciones || undefined,
    })

    // Medición (EC/pH) → activity_type: 'measurement'
    if (sel.includes('medicion')) {
      const m = fd.medicion
      if (m.ph || m.ec || m.temperatura_sustrato) {
        await createPlantActivity(plantId, {
          activity_type: 'measurement',
          metadata: {
            ph: m.ph || undefined, ec: m.ec || undefined,
            ph_runoff: m.ph_runoff || undefined,
            temperatura_sustrato: m.temperatura_sustrato || undefined,
          },
        })
      }
    }

    // Trasplante → activity_type: 'transplant'
    if (sel.includes('trasplante')) {
      const t = fd.trasplante
      if (t.maceta_destino_l) {
        await createPlantActivity(plantId, {
          activity_type: 'transplant',
          metadata: {
            maceta_origen_l:  t.maceta_origen_l  || undefined,
            maceta_destino_l: t.maceta_destino_l,
            sustrato:         t.sustrato,
          },
        })
        await updatePlant(plantId, { tamanio_maceta: parseFloat(t.maceta_destino_l) })
      }
    }

    // Riego, Poda, Plagas → actividades con descripción
    const actividadesExtra = []
    if (sel.includes('riego')) {
      const r = fd.riego
      const desc = [
        r.volumen ? `${r.volumen}L` : null,
        r.ph ? `pH ${r.ph}` : null,
        r.ec ? `EC ${r.ec}` : null,
        r.fertilizo ? `Nutrición: ${r.producto || ''}` : null,
      ].filter(Boolean).join(' · ')
      actividadesExtra.push({ activity_type: 'riego', description: desc || 'Riego' })
    }
    if (sel.includes('poda')) {
      actividadesExtra.push({
        activity_type: 'poda',
        description: [fd.poda.tipo, fd.poda.observaciones].filter(Boolean).join(' · '),
      })
    }
    if (sel.includes('plagas')) {
      const pl = fd.plagas
      actividadesExtra.push({
        activity_type: 'revision_plagas',
        description: [pl.resultado, pl.accion_tomada].filter(Boolean).join(' · '),
      })
    }

    for (const act of actividadesExtra) {
      await createPlantActivity(plantId, act)
    }

    const n = seleccionadas.value.length
    toast.success(`Registro guardado · ${n} acción${n !== 1 ? 'es' : ''}`)
    emit('update:modelValue', false)
    emit('saved')
  } catch (e) {
    error.value = e?.response?.data?.errors?.join(', ') || e?.response?.data?.error || 'Error al guardar'
  } finally { saving.value = false }
}
</script>

<style scoped>
/* Mismo estilo que RegistroLoteModal */
.rps__overlay {
  position: fixed; inset: 0; background: rgba(0,0,0,.45); backdrop-filter: blur(3px);
  display: flex; align-items: center; justify-content: center;
  z-index: 1050; padding: 1rem;
}
.rps__modal {
  background: #fff; border-radius: 20px; width: 100%; max-width: 620px;
  max-height: 92vh; display: flex; flex-direction: column;
  box-shadow: 0 32px 80px rgba(0,0,0,.18);
}
.rps__header {
  display: flex; align-items: center; justify-content: space-between;
  padding: 1.25rem 1.5rem 1rem; border-bottom: 1px solid #f0f4f0; flex-shrink: 0;
}
.rps__header-left  { display: flex; flex-direction: column; gap: .15rem; }
.rps__header-right { display: flex; align-items: center; gap: .5rem; }
.rps__title    { font-size: 1.05rem; font-weight: 800; color: #0f2611; margin: 0; }
.rps__subtitle { font-size: .78rem; color: #60725d; }
.rps__close {
  width: 32px; height: 32px; border-radius: 8px; border: none;
  background: #f0f4f0; color: #374151; cursor: pointer;
  display: flex; align-items: center; justify-content: center; font-size: .9rem;
}
.rps__close:hover { background: var(--c-slate-200); }

.rps__today-bar {
  background: #f0fdf4; border-bottom: 1px solid #dcfce7;
  padding: .6rem 1.5rem; font-size: .78rem; color: #15803d;
  display: flex; align-items: center; gap: .5rem; flex-wrap: wrap; flex-shrink: 0;
}
.rps__today-chip { background: #dcfce7; padding: .15em .5em; border-radius: 6px; font-weight: 600; }

.rps__body { flex: 1; overflow-y: auto; padding: 1.25rem 1.5rem; }

.rps__paso--sel {}
.rps__paso-hint { font-size: .82rem; color: #60725d; margin: 0 0 1rem; }
.rps__acciones-grid { display: grid; grid-template-columns: repeat(5, 1fr); gap: .6rem; }
@media (max-width: 480px) { .rps__acciones-grid { grid-template-columns: repeat(3, 1fr); } }

.rps__accion-card {
  display: flex; flex-direction: column; align-items: center; gap: .3rem;
  padding: .75rem .5rem; border: 2px solid #e8f0e9; border-radius: 12px;
  background: #fafcfa; cursor: pointer; transition: all .12s;
}
.rps__accion-card:hover { border-color: #4ade80; background: #f0fdf4; }
.rps__accion-card--sel  { border-color: #16a34a; background: #f0fdf4; box-shadow: 0 0 0 3px rgba(22,163,74,.12); }
.rps__accion-icon  { font-size: 1.4rem; line-height: 1; }
.rps__accion-label { font-size: .68rem; font-weight: 600; color: #374151; text-align: center; }

.rps__seccion-titulo { font-size: .72rem; font-weight: 700; color: #60725d; text-transform: uppercase; letter-spacing: .06em; margin-bottom: .5rem; }
.rps__radio-group    { display: flex; gap: .5rem; flex-wrap: wrap; }
.rps__radio-btn {
  padding: .35rem .75rem; border: 1.5px solid #e8f0e9; border-radius: 8px;
  background: #fafcfa; color: #374151; font-size: .78rem; font-weight: 600; cursor: pointer; transition: all .12s;
}
.rps__radio-btn:hover  { border-color: #86efac; }
.rps__radio-btn--sel   { font-weight: 700; }

.rps__back-btn {
  display: inline-flex; align-items: center; gap: .3rem;
  background: none; border: none; color: #60725d; font-size: .82rem; cursor: pointer;
  padding: 0; margin-bottom: .875rem; font-weight: 600;
}
.rps__back-btn:hover { color: #1b5e20; }

.rps__seccion { margin-bottom: 1rem; }
.rps__seccion-header {
  font-size: .8rem; font-weight: 700; color: #1b5e20;
  padding: .35rem 0; border-bottom: 1px solid #e8f0e9; margin-bottom: .75rem;
}
.rps__seccion-body {}

.rps__simple-form { display: flex; flex-direction: column; gap: .75rem; }
.rps__field { display: flex; flex-direction: column; gap: .3rem; }
.rps__label { font-size: .72rem; font-weight: 700; color: #374151; text-transform: uppercase; letter-spacing: .04em; }
.rps__input { background: var(--c-slate-50); border: 1.5px solid var(--c-slate-200); border-radius: 9px; padding: .6rem .8rem; font-size: .9rem; color: var(--c-slate-900); outline: none; width: 100%; box-sizing: border-box; }
.rps__input:focus { border-color: #1b5e20; }
.rps__textarea { background: var(--c-slate-50); border: 1.5px solid var(--c-slate-200); border-radius: 9px; padding: .6rem .8rem; font-size: .875rem; color: var(--c-slate-900); outline: none; width: 100%; box-sizing: border-box; resize: none; font-family: inherit; }
.rps__textarea:focus { border-color: #1b5e20; }
.rps__row2 { display: grid; grid-template-columns: 1fr 1fr; gap: .75rem; }
.rps__optional { font-size: .68rem; font-weight: 400; color: var(--c-slate-400); text-transform: none; letter-spacing: 0; margin-left: .25rem; }

.rps__error { margin: 0 1.5rem .5rem; background: #fef2f2; border: 1px solid #fecaca; color: #dc2626; padding: .6rem .875rem; border-radius: 8px; font-size: .82rem; flex-shrink: 0; }

.rps__footer {
  display: flex; align-items: center; justify-content: flex-end; gap: .75rem;
  padding: .875rem 1.5rem; border-top: 1px solid #f0f4f0; flex-shrink: 0;
}
.rps__btn-cancel { background: transparent; color: #60725d; border: 1.5px solid #d4e6d4; padding: .55rem 1.1rem; border-radius: 9px; font-size: .875rem; font-weight: 600; cursor: pointer; }
.rps__btn-cancel:hover { background: #f0fdf4; }
.rps__btn-next  { background: #1b5e20; color: #fff; border: none; padding: .55rem 1.25rem; border-radius: 9px; font-size: .875rem; font-weight: 700; cursor: pointer; }
.rps__btn-next:disabled  { opacity: .45; cursor: not-allowed; }
.rps__btn-save  { display: inline-flex; align-items: center; gap: .4rem; background: #1b5e20; color: #fff; border: none; padding: .55rem 1.25rem; border-radius: 9px; font-size: .875rem; font-weight: 700; cursor: pointer; }
.rps__btn-save:disabled  { opacity: .45; cursor: not-allowed; }

/* Transición pasos */
.rps__paso-enter-active, .rps__paso-leave-active { transition: opacity .18s, transform .18s; }
.rps__paso-enter-from { opacity: 0; transform: translateX(16px); }
.rps__paso-leave-to   { opacity: 0; transform: translateX(-16px); position: absolute; width: 100%; }
</style>
