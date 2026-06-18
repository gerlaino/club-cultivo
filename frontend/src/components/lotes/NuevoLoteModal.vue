<template>
  <Teleport to="body">
    <div v-if="show" class="nlm__overlay" @click.self="$emit('close')">
      <div class="nlm__modal">
        <div class="nlm__header">
          <div>
            <h3 class="nlm__title">Nuevo lote</h3>
            <p v-if="effectiveSala" class="nlm__sub">{{ effectiveSala.nombre }}</p>
          </div>
          <button class="nlm__close" @click="$emit('close')"><i class="bi bi-x-lg"></i></button>
        </div>

        <div class="nlm__body">
          <div v-if="apiError" class="nlm__alert">{{ apiError }}</div>

          <!-- Bifurcación nuevo / existente -->
          <div class="nlm__tabs">
            <button type="button" class="nlm__tab" :class="{ 'nlm__tab--active': tipoCreacion === 'nuevo' }" @click="tipoCreacion = 'nuevo'">
              <i class="bi bi-plus-circle"></i> Lote nuevo
            </button>
            <button type="button" class="nlm__tab" :class="{ 'nlm__tab--active': tipoCreacion === 'existente' }" @click="tipoCreacion = 'existente'">
              <i class="bi bi-clock-history"></i> Cargar lote existente
            </button>
          </div>

          <!-- Lote cosechado: no va a una sala de cultivo, se ubica por sede y se ve en Cosecha -->
          <div v-if="esCosechado" class="nlm__field">
            <label class="nlm__label">Sede <span class="nlm__req">*</span></label>
            <select class="nlm__input" :class="{ 'nlm__input--err': errors.sede_id }" v-model="sedeId">
              <option value="" disabled>Seleccioná una sede…</option>
              <option v-for="s in sedes" :key="s.id" :value="s.id">{{ s.nombre }}</option>
            </select>
            <span v-if="errors.sede_id" class="nlm__err">{{ errors.sede_id }}</span>
            <span class="nlm__hint">El lote cosechado se verá en la sección Cosecha, pendiente de manicura.</span>
          </div>

          <!-- Selector de sala (solo cuando no viene fija y no es cosechado) -->
          <div v-else-if="!sala" class="nlm__field">
            <label class="nlm__label">Sala <span class="nlm__req">*</span></label>
            <select class="nlm__input" :class="{ 'nlm__input--err': errors.sala_id }" v-model="salaId">
              <option value="" disabled>Seleccioná una sala…</option>
              <option v-for="s in (salas || [])" :key="s.id" :value="s.id">{{ s.nombre }}</option>
            </select>
            <span v-if="errors.sala_id" class="nlm__err">{{ errors.sala_id }}</span>
          </div>

          <!-- Código (readonly) -->
          <div class="nlm__field">
            <label class="nlm__label">Código</label>
            <input type="text" class="nlm__input nlm__input--ro" :value="loadingCodigo ? 'Calculando…' : (proximoCodigo || '—')" readonly />
            <span class="nlm__hint">Asignado automáticamente al guardar</span>
          </div>

          <div class="nlm__grid">
            <!-- ── LOTE EXISTENTE (heredado) ── -->
            <template v-if="tipoCreacion === 'existente'">
              <div class="nlm__field nlm__field--full">
                <label class="nlm__label">¿Cómo inició este lote?</label>
                <div class="nlm__pills">
                  <button type="button" class="nlm__pill" :class="{ 'nlm__pill--active': form.origen === 'semilla' }" @click="setOrigen('semilla')">🌱 Semilla</button>
                  <button type="button" class="nlm__pill" :class="{ 'nlm__pill--active': form.origen === 'esqueje' }" @click="setOrigen('esqueje')">🪴 Esqueje</button>
                </div>
              </div>

              <div class="nlm__field nlm__field--full">
                <label class="nlm__label">Estado actual del lote</label>
                <select class="nlm__input" v-model="heredadoEstado">
                  <option v-for="e in estadosHeredadoPermitidos" :key="e.value" :value="e.value">{{ e.label }}</option>
                </select>
              </div>

              <div class="nlm__field">
                <label class="nlm__label">
                  Días en {{ form.origen === 'esqueje' ? 'esqueje' : 'semilla' }}
                  <span v-if="['vegetativo','floracion','cosecha'].includes(heredadoEstado)" class="nlm__label-opt">(completados)</span>
                </label>
                <input type="number" min="0" max="999" step="1" class="nlm__input" v-model.number="heredadoDias.semilla_esqueje" />
              </div>
              <div v-if="['vegetativo','floracion','cosecha'].includes(heredadoEstado)" class="nlm__field">
                <label class="nlm__label">Días en vegetativo <span v-if="['floracion','cosecha'].includes(heredadoEstado)" class="nlm__label-opt">(completados)</span></label>
                <input type="number" min="0" max="999" step="1" class="nlm__input" v-model.number="heredadoDias.vegetativo" />
              </div>
              <div v-if="['floracion','cosecha'].includes(heredadoEstado)" class="nlm__field">
                <label class="nlm__label">Días en floración <span v-if="heredadoEstado === 'cosecha'" class="nlm__label-opt">(completados)</span></label>
                <input type="number" min="0" max="999" step="1" class="nlm__input" v-model.number="heredadoDias.floracion" />
              </div>
              <div v-if="heredadoEstado === 'cosecha'" class="nlm__field">
                <label class="nlm__label">Días en cosecha <span class="nlm__label-opt">(actual)</span></label>
                <input type="number" min="0" max="999" step="1" class="nlm__input" v-model.number="heredadoDias.cosecha" />
              </div>
              <div v-if="heredadoStartDatePreview" class="nlm__field nlm__field--full">
                <label class="nlm__label">Fecha de inicio estimada</label>
                <input type="text" class="nlm__input nlm__input--ro" :value="heredadoStartDatePreview" readonly />
                <span class="nlm__hint">Calculada a partir de los días ingresados</span>
              </div>
            </template>

            <!-- ── LOTE NUEVO ── -->
            <template v-else>
              <div v-if="mostrarOrigenSelector" class="nlm__field nlm__field--full">
                <label class="nlm__label">¿Cómo inicia este lote?</label>
                <div class="nlm__pills">
                  <button type="button" class="nlm__pill" :class="{ 'nlm__pill--active': form.origen === 'semilla' }" @click="setOrigen('semilla')">🌱 Semilla</button>
                  <button type="button" class="nlm__pill" :class="{ 'nlm__pill--active': form.origen === 'esqueje' }" @click="setOrigen('esqueje')">🪴 Esqueje</button>
                </div>
              </div>
              <div class="nlm__field">
                <label class="nlm__label">Fecha de inicio</label>
                <AppDatePicker v-model="form.start_date" />
              </div>
            </template>

            <!-- Planta madre (solo esqueje) -->
            <div v-if="form.origen === 'esqueje'" class="nlm__field nlm__field--full">
              <label class="nlm__label">Planta madre <span class="nlm__label-opt">(opcional)</span></label>
              <div v-if="loadingMadres" class="nlm__input nlm__input--ro">Cargando plantas…</div>
              <div v-else class="nlm__madre">
                <div v-if="plantaMadreSeleccionada" class="nlm__madre-chip">
                  <i class="bi bi-check-circle-fill"></i>
                  <strong>{{ plantaMadreSeleccionada.nombre }}</strong>
                  <span v-if="plantaMadreSeleccionada.lote?.codigo">{{ plantaMadreSeleccionada.lote.codigo }}</span>
                  <button type="button" class="nlm__madre-clear" @click="clearMadre" title="Quitar">×</button>
                </div>
                <input v-model="madreQuery" type="text" class="nlm__input"
                       :placeholder="plantaMadreSeleccionada ? 'Cambiar planta madre…' : 'Buscar por nombre, sala, lote o genética…'"
                       @focus="madreFocused = true" @blur="onMadreBlur" autocomplete="off" />
                <div v-if="madreFocused" class="nlm__madre-drop">
                  <template v-if="madreQuery.trim()">
                    <div v-if="!madreDropdown.length" class="nlm__madre-empty">Sin resultados para "{{ madreQuery }}"</div>
                    <div v-for="p in madreDropdown" :key="p.id" class="nlm__madre-opt"
                         :class="{ 'nlm__madre-opt--sel': form.planta_madre_id === p.id }" @mousedown.prevent="selectMadre(p)">
                      <span class="nlm__madre-opt-nombre">{{ p.nombre }}</span>
                      <span class="nlm__madre-opt-meta">{{ p.lote?.sala?.nombre }} · {{ p.lote?.codigo }}<span v-if="p.genetica"> · {{ p.genetica.nombre }}</span></span>
                    </div>
                  </template>
                  <template v-else>
                    <div v-if="!madreAgrupado.length" class="nlm__madre-empty">No hay plantas disponibles</div>
                    <template v-for="grp in madreAgrupado" :key="grp.sala_id">
                      <div class="nlm__madre-sala-hd"><i class="bi bi-geo-alt-fill"></i> {{ grp.sala_nombre }}</div>
                      <template v-for="lote in grp.lotes" :key="lote.lote_id">
                        <button type="button" class="nlm__madre-lote-hd nlm__madre-lote-hd--btn" @mousedown.prevent="toggleLoteColapso(lote.lote_id)">
                          <i class="bi" :class="madreColapsados.has(lote.lote_id) ? 'bi-chevron-right' : 'bi-chevron-down'"></i>
                          <i class="bi bi-box-seam"></i> {{ lote.lote_codigo }}
                          <span v-if="lote.genetica" class="nlm__madre-lote-gen">{{ lote.genetica }}</span>
                          <span class="nlm__madre-lote-count">{{ lote.plants.length }}</span>
                        </button>
                        <template v-if="!madreColapsados.has(lote.lote_id)">
                          <div v-for="p in lote.plants" :key="p.id" class="nlm__madre-opt nlm__madre-opt--plant"
                               :class="{ 'nlm__madre-opt--sel': form.planta_madre_id === p.id }" @mousedown.prevent="selectMadre(p)">
                            <span class="nlm__madre-opt-nombre">🌿 {{ p.nombre }}</span>
                            <span class="nlm__madre-opt-meta">{{ p.state }}</span>
                          </div>
                        </template>
                      </template>
                    </template>
                  </template>
                </div>
              </div>
            </div>

            <div class="nlm__field">
              <label class="nlm__label">Cantidad de plantas <span class="nlm__req">*</span></label>
              <input type="number" min="1" max="5000" step="1" class="nlm__input" :class="{ 'nlm__input--err': errors.plants_count }" v-model.number="form.plants_count" />
              <span v-if="errors.plants_count" class="nlm__err">{{ errors.plants_count }}</span>
            </div>

            <div class="nlm__field">
              <label class="nlm__label">Genética / Variedad
                <span v-if="form.planta_madre_id" class="nlm__label-heredada">Heredada de madre</span>
              </label>
              <select class="nlm__input" v-model="form.genetica_id" :disabled="!geneticas.length || !!form.planta_madre_id">
                <option value="">{{ geneticas.length ? 'Sin especificar' : 'Sin genéticas disponibles' }}</option>
                <option v-for="g in geneticas" :key="g.id" :value="g.id">{{ g.nombre }}{{ g.registrada_inase ? ' 🏛️' : '' }} — {{ g.tipo }}</option>
              </select>
              <p v-if="form.planta_madre_id" class="nlm__hint"><i class="bi bi-link-45deg"></i> La genética se hereda de la planta madre.</p>
              <p v-else-if="!geneticas.length" class="nlm__hint"><i class="bi bi-info-circle"></i> No tenés genéticas marcadas como disponibles. <a href="/geneticas" class="nlm__link">Activá o registrá una</a> para asignarla.</p>
            </div>

            <div class="nlm__field">
              <label class="nlm__label">Tipo de cultivo</label>
              <select class="nlm__input" v-model="form.grow_type">
                <option value="sustrato">Sustrato</option>
                <option value="hidroponia">Hidroponia</option>
                <option value="aeroponia">Aeroponia</option>
              </select>
            </div>
            <div class="nlm__field">
              <label class="nlm__label">Tamaño de maceta</label>
              <select class="nlm__input" v-model="form.tamanio_maceta">
                <option value="">Sin especificar</option>
                <option value="0.5">Vaso (0.5L)</option>
                <option value="1">1 litro</option><option value="3">3 litros</option>
                <option value="5">5 litros</option><option value="7">7 litros</option>
                <option value="10">10 litros</option><option value="12">12 litros</option>
                <option value="15">15 litros</option>
              </select>
            </div>
            <div class="nlm__field">
              <label class="nlm__label">Tipo de luz</label>
              <select class="nlm__input" v-model="form.light_type">
                <option value="">Sin especificar</option>
                <option value="led">LED</option><option value="hps">HPS</option>
                <option value="cmh">CMH</option><option value="natural">Natural</option><option value="mixta">Mixta</option>
              </select>
            </div>
            <div class="nlm__field nlm__field--full">
              <label class="nlm__label">Notas</label>
              <textarea class="nlm__input nlm__textarea" rows="2" v-model.trim="form.notes" placeholder="Observaciones…"></textarea>
            </div>
          </div>
        </div>

        <div class="nlm__footer">
          <button class="nlm__btn-ghost" :disabled="saving" @click="$emit('close')">Cancelar</button>
          <button class="nlm__btn-primary" :disabled="saving" @click="crear">
            <DsSpinner v-if="saving" :size="14" />
            <template v-else><i class="bi bi-plus-lg"></i> Crear lote</template>
          </button>
        </div>
      </div>
    </div>
  </Teleport>
</template>

<script setup>
import { ref, computed, watch } from 'vue'
import { useLotesStore } from '../../stores/lotes'
import { getLoteProximoCodigo, listGeneticas, listPlants, createLoteHeredado, createLoteCosechadoEnSede, listSedes } from '../../lib/api.js'
import DsSpinner from '../../design-system/components/Spinner.vue'
import AppDatePicker from '../ui/AppDatePicker.vue'

// Fecha local en ISO (yyyy-mm-dd) SIN pasar por UTC — toISOString() convierte a
// UTC y de tarde/noche en Argentina (UTC-3) devolvía el día siguiente.
function localISO(date = new Date()) {
  const y = date.getFullYear()
  const m = String(date.getMonth() + 1).padStart(2, '0')
  const d = String(date.getDate()).padStart(2, '0')
  return `${y}-${m}-${d}`
}

const props = defineProps({
  show:  { type: Boolean, default: false },
  sala:  { type: Object,  default: null },   // sala fija (desde SalaDetail)
  salas: { type: Array,   default: null },   // lista para el selector (desde /lotes)
})
const emit = defineEmits(['close', 'created'])

const lotes = useLotesStore()

const ESTADOS_LOTE     = ['semilla','esqueje','vegetativo','floracion','cosecha','curado','finalizado']
const KINDS_CON_ORIGEN = ['vegetativo','madre','clon','mixta']
const KIND_TO_ESTADO   = { floracion: 'floracion', secado: 'secado', manicura: 'curado' }
const ESTADOS_HEREDADO = [
  { value: 'semilla',    label: 'Germinación / Plántula' },
  { value: 'vegetativo', label: 'Vegetativo' },
  { value: 'floracion',  label: 'Floración' },
  { value: 'cosecha',    label: 'Cosechado' },
]

const salaId = ref('')
const sedeId = ref('')
const sedes  = ref([])
const effectiveSala = computed(() => props.sala || (props.salas || []).find(s => s.id === salaId.value) || null)
// Lote cosechado heredado: no va a sala de cultivo, se ubica por sede.
const esCosechado = computed(() => tipoCreacion.value === 'existente' && heredadoEstado.value === 'cosecha')

const form          = ref(emptyForm())
const errors        = ref({})
const apiError      = ref(null)
const saving        = ref(false)
const tipoCreacion  = ref('nuevo')
const proximoCodigo = ref('')
const loadingCodigo = ref(false)
const heredadoEstado = ref('semilla')
const heredadoDias   = ref({ semilla_esqueje: 0, vegetativo: 0, floracion: 0, cosecha: 0 })
const geneticas      = ref([])
const plantasMadre   = ref([])
const loadingMadres  = ref(false)
const madreQuery     = ref('')
const madreFocused   = ref(false)
const madreColapsados = ref(new Set())   // lote_id colapsados en el dropdown de planta madre

function toggleLoteColapso(loteId) {
  const s = new Set(madreColapsados.value)
  s.has(loteId) ? s.delete(loteId) : s.add(loteId)
  madreColapsados.value = s
}

// Los estados creables son los del ciclo previo a stock: germinación/plántula
// (o esqueje según el origen), vegetativo, floración y cosechado (un lote ya
// cosechado se carga y queda pendiente de manicura). Nunca secado/finalizado.
const estadosHeredadoPermitidos = computed(() =>
  ESTADOS_HEREDADO.map(e =>
    e.value === 'semilla'
      ? { ...e, label: form.value.origen === 'esqueje' ? 'Esqueje' : 'Germinación / Plántula' }
      : e
  )
)
const mostrarOrigenSelector = computed(() => {
  const k = effectiveSala.value?.kind
  return !k || KINDS_CON_ORIGEN.includes(k)
})
const plantaMadreSeleccionada = computed(() => plantasMadre.value.find(p => p.id === form.value.planta_madre_id))
const madreDropdown = computed(() => {
  const q = madreQuery.value.trim().toLowerCase()
  if (!q) return []
  return plantasMadre.value.filter(p =>
    p.nombre?.toLowerCase().includes(q) || p.lote?.codigo?.toLowerCase().includes(q) ||
    p.lote?.sala?.nombre?.toLowerCase().includes(q) || p.genetica?.nombre?.toLowerCase().includes(q)
  ).slice(0, 40)
})
const madreAgrupado = computed(() => {
  const salasMap = {}
  for (const p of plantasMadre.value) {
    const salaIdK = p.lote?.sala?.id ?? 0
    if (!salasMap[salaIdK]) salasMap[salaIdK] = { sala_id: salaIdK, sala_nombre: p.lote?.sala?.nombre ?? 'Sin sala', lotes: {} }
    const loteId = p.lote?.id ?? 0
    if (!salasMap[salaIdK].lotes[loteId]) salasMap[salaIdK].lotes[loteId] = { lote_id: loteId, lote_codigo: p.lote?.codigo ?? '–', genetica: p.genetica?.nombre ?? '', plants: [] }
    salasMap[salaIdK].lotes[loteId].plants.push(p)
  }
  return Object.values(salasMap).map(s => ({ ...s, lotes: Object.values(s.lotes) }))
})
const heredadoStartDatePreview = computed(() => {
  const e = heredadoEstado.value, d = heredadoDias.value
  let total = d.semilla_esqueje
  if (['vegetativo','floracion','cosecha'].includes(e)) total += d.vegetativo
  if (['floracion','cosecha'].includes(e))              total += d.floracion
  if (e === 'cosecha')                                  total += d.cosecha
  if (total <= 0) return null
  const date = new Date(); date.setDate(date.getDate() - total)
  return localISO(date)
})

function emptyForm() {
  const kind = effectiveSala.value?.kind
  const conOrigen = !kind || KINDS_CON_ORIGEN.includes(kind)
  return {
    estado: conOrigen ? 'semilla' : (KIND_TO_ESTADO[kind] || 'vegetativo'),
    origen: conOrigen ? 'semilla' : null,
    planta_madre_id: null, plants_count: 1,
    start_date: localISO(),
    genetica_id: '', grow_type: 'sustrato', light_type: '', tamanio_maceta: '', notes: '',
  }
}

async function setOrigen(valor) {
  form.value.origen = valor
  form.value.estado = valor
  form.value.planta_madre_id = null
  madreQuery.value = ''
  if (valor === 'esqueje') {
    loadingMadres.value = true
    try { const { data } = await listPlants({ lote_estado: 'vegetativo' }); plantasMadre.value = data || [] }
    catch { plantasMadre.value = [] } finally { loadingMadres.value = false }
  }
}
let _madreTimer = null
function onMadreBlur() { _madreTimer = setTimeout(() => { madreFocused.value = false }, 180) }
function selectMadre(p) {
  clearTimeout(_madreTimer)
  form.value.planta_madre_id = p.id
  madreQuery.value = ''; madreFocused.value = false
  if (p.genetica?.id) form.value.genetica_id = p.genetica.id
}
function clearMadre() { form.value.planta_madre_id = null; madreQuery.value = '' }

function validate() {
  const e = {}
  if (esCosechado.value) {
    if (!sedeId.value) e.sede_id = 'Seleccioná una sede'
  } else if (!props.sala && !salaId.value) {
    e.sala_id = 'Seleccioná una sala'
  }
  if (!ESTADOS_LOTE.includes(form.value.estado)) e.estado = 'Estado inválido'
  const n = Number(form.value.plants_count)
  if (!Number.isInteger(n) || n < 1 || n > 5000) e.plants_count = 'Debe ser 1–5000'
  return e
}

async function crear() {
  if (tipoCreacion.value === 'existente') {
    form.value.estado = (heredadoEstado.value === 'semilla' && form.value.origen === 'esqueje') ? 'esqueje' : heredadoEstado.value
  }
  const e = validate()
  errors.value = e; apiError.value = null
  if (Object.keys(e).length) return

  const targetSala = effectiveSala.value
  if (!esCosechado.value && !targetSala) { errors.value.sala_id = 'Seleccioná una sala'; return }

  saving.value = true
  try {
    const payload = { ...form.value }
    if (!payload.genetica_id)     delete payload.genetica_id
    if (!payload.light_type)      delete payload.light_type
    if (!payload.tamanio_maceta)  delete payload.tamanio_maceta
    if (!payload.planta_madre_id) delete payload.planta_madre_id

    const dias = {
      dias_semilla_esqueje: heredadoDias.value.semilla_esqueje || 0,
      dias_vegetativo:      heredadoDias.value.vegetativo      || 0,
      dias_floracion:       heredadoDias.value.floracion       || 0,
      dias_cosecha:         heredadoDias.value.cosecha          || 0,
    }

    if (esCosechado.value) {
      // Sin sala de cultivo: el backend ubica el lote en la sala de proceso "Cosecha · sede".
      delete payload.start_date
      if (!payload.origen) payload.origen = 'semilla'
      await createLoteCosechadoEnSede(sedeId.value, payload, dias)
    } else if (tipoCreacion.value === 'existente') {
      delete payload.start_date
      if (!payload.origen) payload.origen = 'semilla'
      await createLoteHeredado(targetSala.id, payload, dias)
    } else {
      if (!payload.origen) delete payload.origen
      await lotes.createInSala(targetSala.id, payload)
    }
    emit('created', targetSala?.id)
    emit('close')
  } catch (err) {
    apiError.value = err.response?.data?.errors?.[0] || err.response?.data?.error || 'Error al crear el lote'
  } finally {
    saving.value = false
  }
}

// Al abrir: reset + cargar código y genéticas
watch(() => props.show, async (open) => {
  if (!open) return
  salaId.value        = props.sala ? props.sala.id : ''
  sedeId.value        = ''
  form.value          = emptyForm()
  errors.value        = {}
  apiError.value      = null
  tipoCreacion.value  = 'nuevo'
  listSedes().then(({ data }) => {
    sedes.value = (data || []).filter(s => ['produccion', 'mixta'].includes(s.tipo))
    if (sedes.value.length === 1) sedeId.value = sedes.value[0].id
  }).catch(() => { sedes.value = [] })
  heredadoEstado.value = estadosHeredadoPermitidos.value[0]?.value ?? 'semilla'
  heredadoDias.value  = { semilla_esqueje: 0, vegetativo: 0, floracion: 0, cosecha: 0 }
  plantasMadre.value  = []
  proximoCodigo.value = ''
  loadingCodigo.value = true
  try {
    const [cod, gen] = await Promise.all([getLoteProximoCodigo(), listGeneticas({ activa: true, disponible: true, per_page: 200 })])
    proximoCodigo.value = cod.data.codigo
    geneticas.value = Array.isArray(gen.data) ? gen.data : (gen.data.geneticas ?? gen.data.data ?? [])
  } catch { proximoCodigo.value = 'Auto' } finally { loadingCodigo.value = false }
})

// Si cambia la sala elegida, recomputar estado inicial del form nuevo
watch(salaId, () => {
  if (tipoCreacion.value === 'nuevo' && !form.value.planta_madre_id) {
    const f = emptyForm()
    form.value.estado = f.estado
    form.value.origen = f.origen
  }
  heredadoEstado.value = estadosHeredadoPermitidos.value[0]?.value ?? 'semilla'
})
</script>

<style scoped>
.nlm__overlay { position: fixed; inset: 0; background: rgba(15,23,42,.45); z-index: 800; display: flex; align-items: center; justify-content: center; padding: 1rem; }
.nlm__modal { background: #fff; border-radius: 16px; width: 100%; max-width: 620px; max-height: 92vh; display: flex; flex-direction: column; box-shadow: 0 20px 60px rgba(0,0,0,.2); }
.nlm__header { display: flex; align-items: flex-start; justify-content: space-between; padding: 1.1rem 1.4rem; border-bottom: 1px solid #f1f5f9; }
.nlm__title { font-size: 1.05rem; font-weight: 800; color: #0f172a; margin: 0; }
.nlm__sub { font-size: .8rem; color: #64748b; margin: .2rem 0 0; }
.nlm__close { background: none; border: none; color: #94a3b8; cursor: pointer; font-size: 1rem; }
.nlm__body { padding: 1.2rem 1.4rem; overflow-y: auto; }
.nlm__alert { background: #fef2f2; border: 1px solid #fecaca; color: #b91c1c; border-radius: 8px; padding: .55rem .8rem; font-size: .82rem; margin-bottom: .9rem; }
.nlm__tabs { display: flex; gap: .5rem; margin-bottom: 1rem; }
.nlm__tab { flex: 1; display: inline-flex; align-items: center; justify-content: center; gap: .4rem; padding: .55rem; border: 1.5px solid #e2e8f0; background: #f8fafc; border-radius: 9px; font-size: .82rem; font-weight: 700; color: #64748b; cursor: pointer; transition: all .15s; }
.nlm__tab--active { border-color: #15803d; background: #f0fdf4; color: #15803d; }
.nlm__grid { display: grid; grid-template-columns: 1fr 1fr; gap: .85rem; }
@media (max-width: 520px) { .nlm__grid { grid-template-columns: 1fr; } }
.nlm__field { display: flex; flex-direction: column; gap: .3rem; }
.nlm__field--full { grid-column: 1 / -1; }
.nlm__label { font-size: .74rem; font-weight: 700; color: #64748b; }
.nlm__label-opt { font-weight: 400; color: #94a3b8; }
.nlm__label-heredada { font-weight: 600; color: #15803d; margin-left: .3rem; }
.nlm__req { color: #dc2626; }
.nlm__input { padding: .5rem .7rem; border: 1.5px solid #e2e8f0; border-radius: 8px; font-size: .85rem; color: #0f172a; outline: none; width: 100%; box-sizing: border-box; }
.nlm__input:focus { border-color: #15803d; }
.nlm__input--err { border-color: #dc2626; }
.nlm__input--ro { opacity: .75; cursor: default; background: #f8fafc; }
.nlm__textarea { resize: vertical; }
.nlm__hint { font-size: .72rem; color: #94a3b8; }
.nlm__link { color: #15803d; font-weight: 600; }
.nlm__err { font-size: .72rem; color: #dc2626; }
.nlm__pills { display: flex; gap: .5rem; }
.nlm__pill { flex: 1; padding: .5rem; border: 1.5px solid #e2e8f0; background: #f8fafc; border-radius: 9px; font-size: .82rem; font-weight: 700; color: #475569; cursor: pointer; transition: all .15s; }
.nlm__pill--active { border-color: #15803d; background: #f0fdf4; color: #15803d; }
.nlm__madre { position: relative; }
.nlm__madre-chip { display: inline-flex; align-items: center; gap: .35rem; background: #f0fdf4; border: 1px solid #bbf7d0; color: #15803d; border-radius: 7px; padding: .25rem .55rem; font-size: .78rem; margin-bottom: .35rem; }
.nlm__madre-clear { background: none; border: none; color: #15803d; cursor: pointer; font-size: 1rem; line-height: 1; }
.nlm__madre-drop { position: absolute; z-index: 10; top: 100%; left: 0; right: 0; max-height: 240px; overflow-y: auto; background: #fff; border: 1.5px solid #e2e8f0; border-radius: 9px; box-shadow: 0 8px 24px rgba(0,0,0,.12); margin-top: 3px; }
.nlm__madre-empty { padding: .6rem .8rem; font-size: .8rem; color: #94a3b8; }
.nlm__madre-sala-hd { padding: .4rem .7rem; background: #f1f5f9; font-size: .72rem; font-weight: 700; color: #475569; }
.nlm__madre-lote-hd { padding: .3rem .7rem .3rem 1rem; font-size: .72rem; font-weight: 600; color: #64748b; display: flex; gap: .35rem; align-items: center; }
.nlm__madre-lote-hd--btn { width: 100%; background: none; border: none; cursor: pointer; text-align: left; }
.nlm__madre-lote-hd--btn:hover { background: #f8fafc; }
.nlm__madre-lote-gen { color: #94a3b8; }
.nlm__madre-lote-count { margin-left: auto; background: #e2e8f0; color: #64748b; border-radius: 999px; padding: .05rem .4rem; font-size: .65rem; }
.nlm__madre-opt { display: flex; justify-content: space-between; align-items: center; padding: .45rem .8rem; cursor: pointer; font-size: .82rem; }
.nlm__madre-opt--plant { padding-left: 1.3rem; }
.nlm__madre-opt:hover { background: #f0fdf4; }
.nlm__madre-opt--sel { background: #dcfce7; }
.nlm__madre-opt-meta { font-size: .72rem; color: #94a3b8; }
.nlm__footer { display: flex; justify-content: flex-end; gap: .6rem; padding: 1rem 1.4rem; border-top: 1px solid #f1f5f9; }
.nlm__btn-ghost { background: none; border: 1.5px solid #cbd5e1; color: #64748b; border-radius: 9px; padding: .5rem 1rem; font-size: .85rem; font-weight: 700; cursor: pointer; }
.nlm__btn-primary { display: inline-flex; align-items: center; gap: .4rem; background: #15803d; color: #fff; border: none; border-radius: 9px; padding: .5rem 1.2rem; font-size: .85rem; font-weight: 700; cursor: pointer; }
.nlm__btn-primary:disabled, .nlm__btn-ghost:disabled { opacity: .6; cursor: wait; }
</style>
