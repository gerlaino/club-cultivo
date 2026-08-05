<script setup>
import { ref, computed, onMounted } from 'vue'
import { createLoteHeredado, listGeneticas, listPlants, getLoteProximoCodigo } from '../../lib/api.js'
import { useModalEscape } from '../../composables/useModalEscape.js'
import DsSpinner from '../../design-system/components/Spinner.vue'
import AppDatePicker from '../ui/AppDatePicker.vue'

const props = defineProps({
  sala: { type: Object, required: true },
})
const emit = defineEmits(['created', 'close'])
useModalEscape(() => emit('close'))

// ── Wizard state ───────────────────────────────────────────
const paso = ref(1)
const saving = ref(false)
const apiError = ref(null)
const proximoCodigo = ref('')
const loadingCodigo = ref(true)
const geneticas = ref([])

const form = ref({
  origen: 'semilla',
  planta_madre_id: null,
  plants_count: 0,
  genetica_id: '',
  dias: { semilla_esqueje: 0, vegetativo: 0, floracion: 0, cosecha: 0 },
  // Cultivo
  grow_type: 'sustrato',
  sustrato_especifico: '',
  sistema_hidro: '',
  // Luz
  light_type: '',
  // Fotoperiodos
  fotoperiodo_vegetativo: '',
  fotoperiodo: '',           // floración
  dias_floracion_objetivo: null,
  // Macetas
  tamanio_maceta_inicial: '',
  tamanio_maceta: '',        // final
  fecha_trasplante: '',
  // Riego y nutrición
  ph_riego: null,
  fertilizacion_descripcion: '',
  // Notas
  notes: '',
})
const errors = ref({})

// ── Planta madre (esqueje) ─────────────────────────────────
const plantasMadre   = ref([])
const loadingMadres  = ref(false)
const madreQuery     = ref('')
const madreFocused   = ref(false)

const plantaMadreSeleccionada = computed(() =>
  plantasMadre.value.find(p => p.id === form.value.planta_madre_id)
)
const madreDropdown = computed(() => {
  const q = madreQuery.value.trim().toLowerCase()
  if (!q) return []
  return plantasMadre.value.filter(p =>
    p.nombre?.toLowerCase().includes(q) ||
    p.lote?.codigo?.toLowerCase().includes(q) ||
    p.genetica?.nombre?.toLowerCase().includes(q)
  ).slice(0, 20)
})

async function setOrigen(valor) {
  form.value.origen = valor
  form.value.planta_madre_id = null
  madreQuery.value = ''
  if (valor === 'esqueje' && !plantasMadre.value.length) {
    loadingMadres.value = true
    try {
      const { data } = await listPlants({ lote_estado: 'vegetativo' })
      plantasMadre.value = data || []
    } catch { plantasMadre.value = [] }
    finally { loadingMadres.value = false }
  }
}

let _madreFocusTimer = null
function onMadreBlur() {
  _madreFocusTimer = setTimeout(() => { madreFocused.value = false }, 180)
}
function selectMadre(plant) {
  clearTimeout(_madreFocusTimer)
  form.value.planta_madre_id = plant.id
  madreQuery.value = ''
  madreFocused.value = false
  if (plant.genetica?.id) form.value.genetica_id = plant.genetica.id
}
function clearMadre() {
  form.value.planta_madre_id = null
  madreQuery.value = ''
}

// ── Fecha estimada de inicio ────────────────────────────────
const startDatePreview = computed(() => {
  const d = form.value.dias
  const total = (d.semilla_esqueje || 0) + (d.vegetativo || 0) + (d.floracion || 0) + (d.cosecha || 0)
  if (total <= 0) return null
  const date = new Date()
  date.setDate(date.getDate() - total)
  return date.toLocaleDateString('es-AR', { day: 'numeric', month: 'long', year: 'numeric' })
})

const totalDias = computed(() => {
  const d = form.value.dias
  return (d.semilla_esqueje || 0) + (d.vegetativo || 0) + (d.floracion || 0) + (d.cosecha || 0)
})

const hayTrasplante = computed(() => {
  const ini = form.value.tamanio_maceta_inicial
  const fin = form.value.tamanio_maceta
  return ini && fin && String(ini) !== String(fin)
})

// ── Lifecycle ──────────────────────────────────────────────
onMounted(async () => {
  try {
    const [{ data: g }, { data: c }] = await Promise.all([
      listGeneticas({ solo_club: 'true' }),
      getLoteProximoCodigo(),
    ])
    geneticas.value = g || []
    proximoCodigo.value = c?.codigo || ''
  } catch { /* no crítico */ }
  finally { loadingCodigo.value = false }
})

// ── Navegación ─────────────────────────────────────────────
function validarPaso1() {
  const e = {}
  const n = Number(form.value.plants_count)
  if (!Number.isInteger(n) || n < 0 || n > 5000) e.plants_count = 'Debe ser entre 0 y 5000'
  errors.value = e
  return !Object.keys(e).length
}

function siguiente() {
  apiError.value = null
  if (paso.value === 1 && !validarPaso1()) return
  paso.value++
}

function anterior() {
  apiError.value = null
  paso.value--
}

// ── Submit ─────────────────────────────────────────────────
async function crear() {
  apiError.value = null
  saving.value = true
  try {
    const lotePayload = {
      estado:     'cosecha',
      origen:     form.value.origen,
      plants_count: form.value.plants_count,
      grow_type:  form.value.grow_type || 'sustrato',
    }
    if (form.value.genetica_id)            lotePayload.genetica_id            = form.value.genetica_id
    if (form.value.planta_madre_id)        lotePayload.planta_madre_id        = form.value.planta_madre_id
    if (form.value.light_type)             lotePayload.light_type             = form.value.light_type
    if (form.value.tamanio_maceta)         lotePayload.tamanio_maceta         = form.value.tamanio_maceta
    if (form.value.tamanio_maceta_inicial) lotePayload.tamanio_maceta_inicial = form.value.tamanio_maceta_inicial
    if (hayTrasplante.value && form.value.fecha_trasplante) lotePayload.fecha_trasplante = form.value.fecha_trasplante
    if (form.value.fotoperiodo)            lotePayload.fotoperiodo            = form.value.fotoperiodo
    if (form.value.fotoperiodo_vegetativo) lotePayload.fotoperiodo_vegetativo = form.value.fotoperiodo_vegetativo
    if (form.value.dias_floracion_objetivo) lotePayload.dias_floracion_objetivo = form.value.dias_floracion_objetivo
    if (form.value.sustrato_especifico)    lotePayload.sustrato_especifico    = form.value.sustrato_especifico
    if (form.value.sistema_hidro)          lotePayload.sistema_hidro          = form.value.sistema_hidro
    if (form.value.ph_riego)               lotePayload.ph_riego               = form.value.ph_riego
    if (form.value.fertilizacion_descripcion?.trim()) lotePayload.fertilizacion_descripcion = form.value.fertilizacion_descripcion.trim()
    if (form.value.notes?.trim())          lotePayload.notes                  = form.value.notes.trim()

    await createLoteHeredado(props.sala.id, lotePayload, {
      dias_semilla_esqueje: form.value.dias.semilla_esqueje || 0,
      dias_vegetativo:      form.value.dias.vegetativo      || 0,
      dias_floracion:       form.value.dias.floracion        || 0,
      dias_cosecha:         form.value.dias.cosecha          || 0,
    })
    emit('created')
    emit('close')
  } catch (e) {
    apiError.value = e.response?.data?.errors?.[0] || e.response?.data?.error || 'Error al crear el lote'
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <Teleport to="body">
    <div class="clc__overlay">
      <div class="clc__panel">

        <!-- Header -->
        <div class="clc__header">
          <div class="clc__header-icon">✂️</div>
          <div class="clc__header-text">
            <h2 class="clc__title">Registrar lote cosechado</h2>
            <p class="clc__sub">{{ sala.nombre }}</p>
          </div>
          <button class="clc__close" @click="$emit('close')"><i class="bi bi-x-lg"></i></button>
        </div>

        <!-- Step indicator -->
        <div class="clc__steps">
          <div class="clc__step" :class="{ 'clc__step--active': paso === 1, 'clc__step--done': paso > 1 }">
            <div class="clc__step-circle">
              <i v-if="paso > 1" class="bi bi-check2"></i>
              <span v-else>1</span>
            </div>
            <span class="clc__step-label">Datos básicos</span>
          </div>
          <div class="clc__step-line" :class="{ 'clc__step-line--done': paso > 1 }"></div>
          <div class="clc__step" :class="{ 'clc__step--active': paso === 2, 'clc__step--done': paso > 2 }">
            <div class="clc__step-circle">
              <i v-if="paso > 2" class="bi bi-check2"></i>
              <span v-else>2</span>
            </div>
            <span class="clc__step-label">Historia del cultivo</span>
          </div>
          <div class="clc__step-line" :class="{ 'clc__step-line--done': paso > 2 }"></div>
          <div class="clc__step" :class="{ 'clc__step--active': paso === 3 }">
            <div class="clc__step-circle"><span>3</span></div>
            <span class="clc__step-label">Insumos <span class="clc__step-opt">(opcional)</span></span>
          </div>
        </div>

        <!-- Body -->
        <div class="clc__body">

          <!-- ── Paso 1: Datos básicos ── -->
          <template v-if="paso === 1">
            <div class="clc__paso-title">
              <i class="bi bi-seedling"></i> Datos del lote
            </div>

            <!-- Código -->
            <div class="clc__field">
              <label class="clc__label">Código asignado</label>
              <div class="clc__codigo-box">
                <span class="clc__codigo-value">
                  <DsSpinner v-if="loadingCodigo" :size="13" />
                  <template v-else>{{ proximoCodigo || '—' }}</template>
                </span>
                <span class="clc__codigo-hint">Asignado automáticamente al guardar</span>
              </div>
            </div>

            <!-- Cantidad de plantas -->
            <div class="clc__field">
              <label class="clc__label">Cantidad de plantas cosechadas</label>
              <input
                type="number"
                min="0"
                max="5000"
                step="1"
                class="clc__input"
                :class="{ 'clc__input--err': errors.plants_count }"
                v-model.number="form.plants_count"
              />
              <span v-if="errors.plants_count" class="clc__err-msg">{{ errors.plants_count }}</span>
            </div>

            <!-- Genética -->
            <div class="clc__field">
              <label class="clc__label">Genética / Variedad</label>
              <select class="clc__input" v-model="form.genetica_id" :disabled="!geneticas.length">
                <option value="">{{ geneticas.length ? 'Sin especificar' : 'Sin genéticas disponibles' }}</option>
                <option v-for="g in geneticas" :key="g.id" :value="g.id">
                  {{ g.nombre }}{{ g.registrada_inase ? ' 🏛️' : '' }} — {{ g.tipo }}
                </option>
              </select>
              <p v-if="!geneticas.length" class="clc__field-hint">
                <i class="bi bi-info-circle"></i>
                <a href="/geneticas" class="clc__link">Registrá una genética</a> antes de crear el lote.
              </p>
            </div>
          </template>

          <!-- ── Paso 2: Historia del cultivo ── -->
          <template v-else-if="paso === 2">
            <div class="clc__paso-title">
              <i class="bi bi-clock-history"></i> Historia del cultivo
            </div>

            <!-- Origen -->
            <div class="clc__field">
              <label class="clc__label">¿Cómo inició este lote?</label>
              <div class="clc__pills">
                <button type="button" class="clc__pill" :class="{ 'clc__pill--active': form.origen === 'semilla' }" @click="setOrigen('semilla')">🌱 Semilla</button>
                <button type="button" class="clc__pill" :class="{ 'clc__pill--active': form.origen === 'esqueje' }" @click="setOrigen('esqueje')">🪴 Esqueje</button>
              </div>
            </div>

            <!-- Planta madre (solo esqueje) -->
            <div v-if="form.origen === 'esqueje'" class="clc__field">
              <label class="clc__label">Planta madre <span class="clc__label-opt">(opcional)</span></label>
              <div v-if="loadingMadres" class="clc__input clc__input--disabled">Cargando plantas…</div>
              <div v-else class="clc__madre-picker">
                <div v-if="plantaMadreSeleccionada" class="clc__madre-chip">
                  <i class="bi bi-check-circle-fill"></i>
                  <strong>{{ plantaMadreSeleccionada.nombre }}</strong>
                  <span v-if="plantaMadreSeleccionada.lote?.codigo" class="clc__madre-chip-lote">{{ plantaMadreSeleccionada.lote.codigo }}</span>
                  <span v-if="plantaMadreSeleccionada.genetica" class="clc__madre-chip-gen">· {{ plantaMadreSeleccionada.genetica.nombre }}</span>
                  <button type="button" class="clc__madre-clear" @click="clearMadre">×</button>
                </div>
                <input v-model="madreQuery" type="text" class="clc__input"
                  :placeholder="plantaMadreSeleccionada ? 'Cambiar planta madre…' : 'Buscar por nombre, sala o lote…'"
                  @focus="madreFocused = true" @blur="onMadreBlur" autocomplete="off" />
                <div v-if="madreFocused && madreQuery.trim()" class="clc__madre-dropdown">
                  <div v-if="!madreDropdown.length" class="clc__madre-empty">Sin resultados para "{{ madreQuery }}"</div>
                  <div v-for="p in madreDropdown" :key="p.id" class="clc__madre-opt"
                    :class="{ 'clc__madre-opt--sel': form.planta_madre_id === p.id }"
                    @mousedown.prevent="selectMadre(p)">
                    <span class="clc__madre-opt-nombre">🌿 {{ p.nombre }}</span>
                    <span class="clc__madre-opt-meta">{{ p.lote?.codigo }}<span v-if="p.genetica"> · {{ p.genetica.nombre }}</span></span>
                  </div>
                </div>
              </div>
            </div>

            <p class="clc__paso-desc">
              Ingresá los días aproximados. No hace falta ser exacto — sirve para reconstruir la trazabilidad del cultivo.
            </p>

            <div class="clc__timeline">

              <div class="clc__timeline-item">
                <div class="clc__timeline-dot clc__timeline-dot--semilla"></div>
                <div class="clc__timeline-content">
                  <label class="clc__label">Días en {{ form.origen === 'esqueje' ? 'esqueje / arraigo' : 'semilla / germinación' }}</label>
                  <input type="number" min="0" max="999" step="1" class="clc__input clc__input--narrow"
                         v-model.number="form.dias.semilla_esqueje" />
                </div>
              </div>

              <div class="clc__timeline-connector"></div>

              <div class="clc__timeline-item">
                <div class="clc__timeline-dot clc__timeline-dot--veg"></div>
                <div class="clc__timeline-content">
                  <label class="clc__label">Días en vegetativo</label>
                  <input type="number" min="0" max="999" step="1" class="clc__input clc__input--narrow"
                         v-model.number="form.dias.vegetativo" />
                </div>
              </div>

              <div class="clc__timeline-connector"></div>

              <div class="clc__timeline-item">
                <div class="clc__timeline-dot clc__timeline-dot--flora"></div>
                <div class="clc__timeline-content">
                  <label class="clc__label">Días en floración</label>
                  <input type="number" min="0" max="999" step="1" class="clc__input clc__input--narrow"
                         v-model.number="form.dias.floracion" />
                </div>
              </div>

              <div class="clc__timeline-connector"></div>

              <div class="clc__timeline-item">
                <div class="clc__timeline-dot clc__timeline-dot--cosecha"></div>
                <div class="clc__timeline-content">
                  <label class="clc__label">Días en cosecha (proceso actual)</label>
                  <input type="number" min="0" max="999" step="1" class="clc__input clc__input--narrow"
                         v-model.number="form.dias.cosecha" />
                </div>
              </div>

            </div>

            <!-- Resumen fecha -->
            <div v-if="totalDias > 0" class="clc__date-summary">
              <div class="clc__date-summary-row">
                <span class="clc__date-label"><i class="bi bi-calendar-event"></i> Inicio estimado del cultivo</span>
                <span class="clc__date-value">{{ startDatePreview }}</span>
              </div>
              <div class="clc__date-summary-row">
                <span class="clc__date-label"><i class="bi bi-hourglass-split"></i> Total del cultivo</span>
                <span class="clc__date-value">{{ totalDias }} días</span>
              </div>
            </div>
            <div v-else class="clc__date-empty">
              <i class="bi bi-info-circle"></i>
              Podés dejar en cero y completar los días después desde el detalle del lote.
            </div>
          </template>

          <!-- ── Paso 3: Insumos y técnica ── -->
          <template v-else-if="paso === 3">
            <div class="clc__paso-title">
              <i class="bi bi-tools"></i> Insumos y técnica
            </div>
            <p class="clc__paso-desc">
              Todo opcional. Podés completar o ajustar desde el detalle del lote en cualquier momento.
            </p>

            <!-- ── Bloque 1: Cultivo ── -->
            <div class="clc__bloque">
              <div class="clc__bloque-title">🌱 Tipo de cultivo</div>

              <div class="clc__field clc__field--full">
                <label class="clc__label">Medio de cultivo</label>
                <div class="clc__pills">
                  <button type="button" class="clc__pill" :class="{ 'clc__pill--active': form.grow_type === 'sustrato' }"   @click="form.grow_type = 'sustrato'">🪨 Sustrato</button>
                  <button type="button" class="clc__pill" :class="{ 'clc__pill--active': form.grow_type === 'hidroponia' }" @click="form.grow_type = 'hidroponia'">💧 Hidroponia</button>
                </div>
              </div>

              <!-- Sustrato específico -->
              <div v-if="form.grow_type === 'sustrato'" class="clc__field clc__field--full">
                <label class="clc__label">Sustrato <span class="clc__label-opt">(opc.)</span></label>
                <select class="clc__input" v-model="form.sustrato_especifico">
                  <option value="">Sin especificar</option>
                  <option value="tierra">Tierra</option>
                  <option value="coco">Fibra de coco</option>
                  <option value="perlita">Perlita</option>
                  <option value="mezcla">Mezcla (tierra + coco + perlita)</option>
                  <option value="rockwool">Rockwool</option>
                  <option value="fibra_coco">Fibra de coco pura</option>
                </select>
              </div>

              <!-- Sistema hidropónico -->
              <div v-if="form.grow_type === 'hidroponia'" class="clc__field clc__field--full">
                <label class="clc__label">Sistema hidropónico <span class="clc__label-opt">(opc.)</span></label>
                <select class="clc__input" v-model="form.sistema_hidro">
                  <option value="">Sin especificar</option>
                  <option value="dwc">DWC (Deep Water Culture)</option>
                  <option value="nft">NFT (Nutrient Film Technique)</option>
                  <option value="ebb_flow">Ebb & Flow (marea)</option>
                  <option value="kratky">Kratky</option>
                  <option value="rdwc">RDWC (Recirculating DWC)</option>
                  <option value="otro">Otro</option>
                </select>
              </div>
            </div>

            <!-- ── Bloque 2: Iluminación y fotoperiodos ── -->
            <div class="clc__bloque">
              <div class="clc__bloque-title">💡 Iluminación</div>
              <div class="clc__grid">

                <div class="clc__field clc__field--full">
                  <label class="clc__label">Tipo de luz <span class="clc__label-opt">(opc.)</span></label>
                  <div class="clc__pills clc__pills--sm">
                    <button type="button" class="clc__pill clc__pill--sm" :class="{ 'clc__pill--active': form.light_type === 'led' }"     @click="form.light_type = form.light_type === 'led'     ? '' : 'led'">LED</button>
                    <button type="button" class="clc__pill clc__pill--sm" :class="{ 'clc__pill--active': form.light_type === 'hps' }"     @click="form.light_type = form.light_type === 'hps'     ? '' : 'hps'">HPS</button>
                    <button type="button" class="clc__pill clc__pill--sm" :class="{ 'clc__pill--active': form.light_type === 'cmh' }"     @click="form.light_type = form.light_type === 'cmh'     ? '' : 'cmh'">CMH</button>
                    <button type="button" class="clc__pill clc__pill--sm" :class="{ 'clc__pill--active': form.light_type === 'natural' }" @click="form.light_type = form.light_type === 'natural' ? '' : 'natural'">Natural</button>
                    <button type="button" class="clc__pill clc__pill--sm" :class="{ 'clc__pill--active': form.light_type === 'mixta' }"   @click="form.light_type = form.light_type === 'mixta'   ? '' : 'mixta'">Mixta</button>
                  </div>
                </div>

                <div class="clc__field">
                  <label class="clc__label">Fotoperiodo — vegetativo <span class="clc__label-opt">(opc.)</span></label>
                  <select class="clc__input" v-model="form.fotoperiodo_vegetativo">
                    <option value="">Sin especificar</option>
                    <option value="24/0">24/0 hs</option>
                    <option value="20/4">20/4 hs</option>
                    <option value="18/6">18/6 hs</option>
                    <option value="16/8">16/8 hs</option>
                    <option value="auto">Auto</option>
                  </select>
                </div>

                <div class="clc__field">
                  <label class="clc__label">Fotoperiodo — floración <span class="clc__label-opt">(opc.)</span></label>
                  <select class="clc__input" v-model="form.fotoperiodo">
                    <option value="">Sin especificar</option>
                    <option value="14/10">14/10 hs</option>
                    <option value="13/11">13/11 hs</option>
                    <option value="12/12">12/12 hs</option>
                    <option value="auto">Auto (autofloreciente)</option>
                  </select>
                </div>

                <div class="clc__field">
                  <label class="clc__label">Días de floración <span class="clc__label-opt">objetivo (opc.)</span></label>
                  <input type="number" min="1" max="365" step="1" class="clc__input" placeholder="Ej: 63" v-model.number="form.dias_floracion_objetivo" />
                </div>

              </div>
            </div>

            <!-- ── Bloque 3: Macetas y trasplante ── -->
            <div class="clc__bloque">
              <div class="clc__bloque-title">🪣 Macetas y trasplante</div>
              <div class="clc__grid">

                <div class="clc__field">
                  <label class="clc__label">Maceta inicial <span class="clc__label-opt">(opc.)</span></label>
                  <select class="clc__input" v-model="form.tamanio_maceta_inicial">
                    <option value="">Sin especificar</option>
                    <option value="0.5">0,5 L</option>
                    <option value="1">1 litro</option>
                    <option value="3">3 litros</option>
                    <option value="5">5 litros</option>
                    <option value="7">7 litros</option>
                    <option value="10">10 litros</option>
                    <option value="12">12 litros</option>
                    <option value="15">15 litros</option>
                    <option value="20">20 litros</option>
                  </select>
                </div>

                <div class="clc__field">
                  <label class="clc__label">Maceta final <span class="clc__label-opt">(opc.)</span></label>
                  <select class="clc__input" v-model="form.tamanio_maceta">
                    <option value="">Sin especificar</option>
                    <option value="0.5">0,5 L</option>
                    <option value="1">1 litro</option>
                    <option value="3">3 litros</option>
                    <option value="5">5 litros</option>
                    <option value="7">7 litros</option>
                    <option value="10">10 litros</option>
                    <option value="12">12 litros</option>
                    <option value="15">15 litros</option>
                    <option value="20">20 litros</option>
                  </select>
                </div>

                <!-- Fecha de trasplante: solo si inicial ≠ final -->
                <Transition name="clc-fade">
                  <div v-if="hayTrasplante" class="clc__field clc__field--full">
                    <label class="clc__label">
                      Fecha de trasplante
                      <span class="clc__label-opt">(opc.) — hubo cambio de maceta {{ form.tamanio_maceta_inicial }}L → {{ form.tamanio_maceta }}L</span>
                    </label>
                    <AppDatePicker v-model="form.fecha_trasplante" />
                  </div>
                </Transition>

              </div>
            </div>

            <!-- ── Bloque 4: Riego y nutrición ── -->
            <div class="clc__bloque">
              <div class="clc__bloque-title">💧 Riego y nutrición</div>
              <div class="clc__grid">

                <div class="clc__field">
                  <label class="clc__label">pH de riego <span class="clc__label-opt">(opc.)</span></label>
                  <div class="clc__input-with-unit">
                    <input type="number" min="4" max="8" step="0.1" class="clc__input" placeholder="Ej: 6.2" v-model.number="form.ph_riego" />
                    <span class="clc__unit">pH</span>
                  </div>
                  <span class="clc__field-hint">Rango típico en cannabis: 5.8 – 6.8</span>
                </div>

                <div class="clc__field clc__field--full">
                  <label class="clc__label">Fertilización utilizada <span class="clc__label-opt">(opc.)</span></label>
                  <textarea
                    class="clc__input clc__textarea"
                    rows="3"
                    v-model.trim="form.fertilizacion_descripcion"
                    placeholder="Ej: BioBizz Grow semanas 1-4, BioBizz Bloom semanas 5-9, Top Max semanas 7-9. EC 1.2-2.0 mS/cm."
                  ></textarea>
                </div>

                <div class="clc__field clc__field--full">
                  <div class="clc__fertilizacion-hint">
                    <i class="bi bi-paperclip"></i>
                    Para adjuntar un protocolo detallado de fertilización (PDF, planilla), podés hacerlo desde el <strong>detalle del lote</strong> una vez creado.
                  </div>
                </div>

              </div>
            </div>

            <!-- ── Bloque 5: Notas ── -->
            <div class="clc__bloque clc__bloque--last">
              <div class="clc__bloque-title">📝 Notas generales</div>
              <div class="clc__field clc__field--full">
                <textarea
                  class="clc__input clc__textarea"
                  rows="3"
                  v-model.trim="form.notes"
                  placeholder="Técnica de conducción (SCROG, SOG, LST, topping…), observaciones del cultivo, incidencias, etc."
                ></textarea>
              </div>
            </div>

            <div v-if="apiError" class="clc__error">
              <i class="bi bi-exclamation-triangle-fill"></i> {{ apiError }}
            </div>
          </template>

        </div>

        <!-- Footer -->
        <div class="clc__footer">
          <div class="clc__footer-left">
            <span class="clc__footer-step">Paso {{ paso }} de 3</span>
          </div>
          <div class="clc__footer-actions">
            <button class="clc__btn-ghost" :disabled="saving" @click="paso === 1 ? $emit('close') : anterior()">
              <i class="bi" :class="paso === 1 ? 'bi-x' : 'bi-arrow-left'"></i>
              {{ paso === 1 ? 'Cancelar' : 'Atrás' }}
            </button>
            <button v-if="paso < 3" class="clc__btn-primary" @click="siguiente()">
              Siguiente <i class="bi bi-arrow-right"></i>
            </button>
            <button v-else class="clc__btn-primary clc__btn-primary--green" :disabled="saving" @click="crear()">
              <DsSpinner v-if="saving" :size="14" />
              <i v-else class="bi bi-check2-circle"></i>
              {{ saving ? 'Guardando…' : 'Crear lote' }}
            </button>
          </div>
        </div>

      </div>
    </div>
  </Teleport>
</template>

<style scoped>
.clc__overlay {
  position: fixed; inset: 0;
  background: rgba(0,0,0,.45);
  display: flex; align-items: center; justify-content: center;
  z-index: 1060; padding: 1rem;
  backdrop-filter: blur(3px);
}
.clc__panel {
  background: #fff; border-radius: 18px;
  width: 100%; max-width: 560px; max-height: 92vh;
  display: flex; flex-direction: column;
  box-shadow: 0 24px 64px rgba(0,0,0,.18);
  overflow: hidden;
}

/* Header */
.clc__header {
  display: flex; align-items: center; gap: .875rem;
  padding: 1.25rem 1.4rem 1rem;
  border-bottom: 1px solid #f1f5f9;
  flex-shrink: 0;
}
.clc__header-icon { font-size: 1.5rem; flex-shrink: 0; }
.clc__header-text { flex: 1; }
.clc__title { font-size: 1rem; font-weight: 800; color: #0f172a; margin: 0 0 .1rem; }
.clc__sub   { font-size: .78rem; color: #64748b; margin: 0; }
.clc__close {
  background: #f1f5f9; border: none; width: 30px; height: 30px;
  border-radius: 8px; cursor: pointer; display: flex; align-items: center;
  justify-content: center; color: #64748b; flex-shrink: 0;
}
.clc__close:hover { background: #e2e8f0; }

/* Step indicator */
.clc__steps {
  display: flex; align-items: center;
  padding: .875rem 1.4rem;
  border-bottom: 1px solid #f1f5f9;
  flex-shrink: 0; gap: 0;
}
.clc__step {
  display: flex; align-items: center; gap: .45rem; flex-shrink: 0;
}
.clc__step-circle {
  width: 26px; height: 26px; border-radius: 50%;
  background: #f1f5f9; border: 2px solid #e2e8f0;
  display: flex; align-items: center; justify-content: center;
  font-size: .72rem; font-weight: 800; color: #94a3b8;
  transition: all .2s;
}
.clc__step--active .clc__step-circle {
  background: #1b5e20; border-color: #1b5e20; color: #fff;
}
.clc__step--done .clc__step-circle {
  background: #dcfce7; border-color: #86efac; color: #15803d;
}
.clc__step-label {
  font-size: .73rem; font-weight: 600; color: #94a3b8; white-space: nowrap;
}
.clc__step--active .clc__step-label { color: #1b5e20; }
.clc__step--done .clc__step-label   { color: #15803d; }
.clc__step-opt { font-weight: 400; color: #b0bec5; }
.clc__step-line {
  flex: 1; height: 2px; background: #e2e8f0; margin: 0 .5rem;
  transition: background .2s;
}
.clc__step-line--done { background: #86efac; }

/* Body */
.clc__body {
  flex: 1; overflow-y: auto;
  padding: 1.25rem 1.4rem;
}

.clc__paso-title {
  font-size: .85rem; font-weight: 700; color: #334155;
  margin-bottom: .875rem;
  display: flex; align-items: center; gap: .4rem;
}
.clc__paso-desc {
  font-size: .8rem; color: #64748b; margin: -.5rem 0 1rem;
  line-height: 1.5;
}

/* Fields */
.clc__grid { display: grid; grid-template-columns: 1fr 1fr; gap: .75rem 1rem; }
.clc__field { display: flex; flex-direction: column; gap: .35rem; margin-bottom: .875rem; }
.clc__field--full { grid-column: 1 / -1; }
.clc__label {
  font-size: .78rem; font-weight: 700; color: #475569;
  display: flex; align-items: center; gap: .4rem;
}
.clc__label-opt { font-weight: 400; color: #94a3b8; }
.clc__label-heredada {
  font-size: .68rem; font-weight: 700; color: #15803d;
  background: #dcfce7; padding: .15em .5em; border-radius: 4px;
}
.clc__input {
  width: 100%; padding: .55rem .75rem; border-radius: 8px;
  border: 1.5px solid #e2e8f0; font-size: .875rem; color: #0f172a;
  background: #fff; outline: none; box-sizing: border-box;
  transition: border-color .15s;
  font-family: inherit;
}
.clc__input:focus { border-color: #1b5e20; }
.clc__input--err  { border-color: #ef4444; }
.clc__input--narrow { max-width: 120px; }
.clc__input--disabled { background: #f8fafc; color: #94a3b8; }
.clc__textarea { resize: vertical; }
.clc__err-msg { font-size: .73rem; color: #dc2626; }
.clc__field-hint { font-size: .75rem; color: #94a3b8; margin: 0; }
.clc__link { color: #15803d; font-weight: 600; }

/* Código box */
.clc__codigo-box {
  display: flex; align-items: center; justify-content: space-between;
  padding: .55rem .875rem;
  background: #f8fafc; border: 1.5px solid #e2e8f0; border-radius: 8px;
}
.clc__codigo-value { font-family: monospace; font-size: .95rem; font-weight: 800; color: #0f172a; letter-spacing: .04em; display: flex; align-items: center; gap: .4rem; }
.clc__codigo-hint  { font-size: .7rem; color: #94a3b8; }

/* Origen pills */
.clc__pills { display: flex; gap: .5rem; }
.clc__pill {
  flex: 1; padding: .6rem .5rem; border-radius: 9px;
  border: 2px solid #e2e8f0; background: #f8fafc;
  font-size: .82rem; font-weight: 600; color: #64748b;
  cursor: pointer; transition: all .15s;
}
.clc__pill:hover { border-color: #94a3b8; }
.clc__pill--active {
  border-color: #1b5e20; background: #f0fdf4; color: #1b5e20;
  box-shadow: 0 0 0 3px rgba(27,94,32,.1);
}

/* Planta madre */
.clc__madre-picker { position: relative; }
.clc__madre-chip {
  display: flex; align-items: center; gap: .4rem;
  background: #f0fdf4; border: 1.5px solid #86efac; border-radius: 8px;
  padding: .4rem .65rem; margin-bottom: .35rem; font-size: .8rem;
}
.clc__madre-chip i { color: #15803d; }
.clc__madre-chip-lote, .clc__madre-chip-gen { color: #64748b; font-size: .73rem; }
.clc__madre-clear {
  margin-left: auto; background: none; border: none; color: #94a3b8;
  cursor: pointer; font-size: 1.1rem; line-height: 1; padding: 0 .2rem;
}
.clc__madre-clear:hover { color: #ef4444; }
.clc__madre-dropdown {
  position: absolute; top: calc(100% + 4px); left: 0; right: 0;
  background: #fff; border: 1.5px solid #e2e8f0; border-radius: 10px;
  box-shadow: 0 8px 24px rgba(0,0,0,.1); z-index: 50; max-height: 200px; overflow-y: auto;
}
.clc__madre-empty { padding: .75rem 1rem; color: #94a3b8; font-size: .8rem; }
.clc__madre-opt {
  padding: .55rem .875rem; cursor: pointer; display: flex;
  justify-content: space-between; align-items: center;
  font-size: .8rem; gap: .5rem; border-bottom: 1px solid #f8fafc;
}
.clc__madre-opt:hover { background: #f0fdf4; }
.clc__madre-opt--sel  { background: #f0fdf4; }
.clc__madre-opt-nombre { font-weight: 600; color: #0f172a; }
.clc__madre-opt-meta   { color: #94a3b8; font-size: .72rem; }

/* Timeline (paso 2) */
.clc__timeline { display: flex; flex-direction: column; gap: 0; }
.clc__timeline-item {
  display: flex; align-items: flex-start; gap: 1rem;
  padding: .5rem 0;
}
.clc__timeline-dot {
  width: 14px; height: 14px; border-radius: 50%; flex-shrink: 0;
  margin-top: .55rem; border: 2.5px solid;
}
.clc__timeline-dot--semilla { background: #f0fdf4; border-color: #86efac; }
.clc__timeline-dot--veg     { background: #fefce8; border-color: #fde047; }
.clc__timeline-dot--flora   { background: #fdf4ff; border-color: #e879f9; }
.clc__timeline-dot--cosecha { background: #fff7ed; border-color: #fb923c; }
.clc__timeline-content { flex: 1; }
.clc__timeline-connector {
  width: 2px; height: 18px; background: #e2e8f0;
  margin-left: 6px; flex-shrink: 0;
}

/* Date summary */
.clc__date-summary {
  background: #f0fdf4; border: 1.5px solid #bbf7d0; border-radius: 10px;
  padding: .875rem 1rem; margin-top: .875rem;
  display: flex; flex-direction: column; gap: .45rem;
}
.clc__date-summary-row {
  display: flex; justify-content: space-between; align-items: center;
  font-size: .8rem;
}
.clc__date-label { color: #15803d; display: flex; align-items: center; gap: .35rem; }
.clc__date-value { font-weight: 700; color: #14532d; }
.clc__date-empty {
  background: #f8fafc; border: 1.5px solid #e2e8f0; border-radius: 10px;
  padding: .75rem 1rem; margin-top: .875rem;
  font-size: .78rem; color: #94a3b8;
  display: flex; align-items: center; gap: .4rem;
}

/* Error */
.clc__error {
  display: flex; align-items: center; gap: .45rem;
  background: #fef2f2; border: 1px solid #fecaca; color: #dc2626;
  padding: .65rem .875rem; border-radius: 9px;
  font-size: .82rem; margin-top: .75rem;
}

/* Footer */
.clc__footer {
  display: flex; align-items: center; justify-content: space-between;
  padding: 1rem 1.4rem;
  border-top: 1px solid #f1f5f9;
  flex-shrink: 0;
}
.clc__footer-left { flex-shrink: 0; }
.clc__footer-step { font-size: .73rem; color: #94a3b8; font-weight: 600; }
.clc__footer-actions { display: flex; gap: .65rem; }

.clc__btn-primary {
  display: inline-flex; align-items: center; gap: .4rem;
  background: #334155; color: #fff;
  border: none; padding: .6rem 1.1rem; border-radius: 9px;
  font-size: .875rem; font-weight: 700; cursor: pointer; transition: background .15s;
}
.clc__btn-primary:hover:not(:disabled) { background: #1e293b; }
.clc__btn-primary--green { background: #1b5e20; }
.clc__btn-primary--green:hover:not(:disabled) { background: #14532d; }
.clc__btn-primary:disabled { opacity: .45; cursor: not-allowed; }

.clc__btn-ghost {
  display: inline-flex; align-items: center; gap: .4rem;
  background: transparent; color: #64748b;
  border: 1.5px solid #e2e8f0; padding: .6rem 1rem;
  border-radius: 9px; font-size: .875rem; font-weight: 600; cursor: pointer;
}
.clc__btn-ghost:hover:not(:disabled) { background: #f8fafc; }
.clc__btn-ghost:disabled { opacity: .45; cursor: not-allowed; }

/* Bloques del paso 3 */
.clc__bloque { border: 1.5px solid #f1f5f9; border-radius: 12px; padding: .875rem 1rem; margin-bottom: .875rem; }
.clc__bloque--last { margin-bottom: 0; }
.clc__bloque-title { font-size: .78rem; font-weight: 700; color: #475569; margin-bottom: .75rem; }

/* Pills pequeñas (para luz) */
.clc__pills--sm { flex-wrap: wrap; gap: .35rem; }
.clc__pill--sm { flex: none; font-size: .78rem; padding: .4rem .65rem; }

/* Input con unidad */
.clc__input-with-unit { display: flex; align-items: center; gap: .4rem; }
.clc__input-with-unit .clc__input { flex: 1; }
.clc__unit { font-size: .8rem; font-weight: 700; color: #64748b; white-space: nowrap; }

/* Hint fertilización */
.clc__fertilizacion-hint {
  background: #f8fafc; border: 1.5px solid #e2e8f0; border-radius: 9px;
  padding: .65rem .875rem; font-size: .78rem; color: #64748b;
  display: flex; align-items: flex-start; gap: .5rem; line-height: 1.5;
}
.clc__fertilizacion-hint i { color: #94a3b8; flex-shrink: 0; margin-top: .1rem; }
.clc__fertilizacion-hint strong { color: #334155; }

/* Transición suave fecha trasplante */
.clc-fade-enter-active, .clc-fade-leave-active { transition: opacity .2s, transform .2s; }
.clc-fade-enter-from, .clc-fade-leave-to { opacity: 0; transform: translateY(-6px); }

@media (max-width: 500px) {
  .clc__grid { grid-template-columns: 1fr; }
  .clc__step-label { display: none; }
}
</style>
