<template>
  <div class="lg">
    <!-- Cabecera: cuántas, sacar/subir, comparar -->
    <div class="lg__head">
      <div class="lg__head-left">
        <span class="lg__emoji">📷</span>
        <span class="lg__title">Fotos</span>
        <span v-if="fotos.length" class="lg__pill">{{ fotos.length }}</span>
        <span v-if="diaActual" class="lg__dia">día {{ diaActual }} del lote</span>
      </div>
      <div class="lg__head-right">
        <button v-if="fotos.length >= 2" class="lg__btn-ghost" :class="{ 'lg__btn-ghost--on': comparando }" @click="toggleComparar">
          <i class="bi bi-layout-split"></i> {{ comparando ? 'Salir de comparar' : 'Comparar' }}
        </button>
        <button v-if="canEdit" class="lg__btn-primary" :disabled="subiendo" @click="abrirCamara">
          <DsSpinner v-if="subiendo" :size="12" />
          <i v-else class="bi bi-camera-fill"></i> Sacar foto
        </button>
        <button v-if="canEdit" class="lg__btn-ghost" :disabled="subiendo" @click="abrirArchivo" title="Elegir de la galería del dispositivo">
          <i class="bi bi-upload"></i>
        </button>
      </div>
    </div>

    <!-- Dos inputs: `capture` abre la cámara en el teléfono; el otro, la galería del dispositivo. -->
    <input ref="inputCamara"  type="file" accept="image/*" capture="environment" style="display:none" @change="onArchivo" />
    <input ref="inputArchivo" type="file" accept="image/*" style="display:none" @change="onArchivo" />

    <!-- Filtro por etiqueta -->
    <div v-if="etiquetasEnUso.length > 1" class="lg__chips">
      <button class="lg__chip" :class="{ 'lg__chip--on': !filtro }" @click="filtro = null">Todas</button>
      <button v-for="e in etiquetasEnUso" :key="e" class="lg__chip" :class="{ 'lg__chip--on': filtro === e }" @click="filtro = filtro === e ? null : e">
        {{ labelEtiqueta(e) }}
      </button>
    </div>

    <div v-if="comparando" class="lg__comparar-hint">
      Elegí dos fotos para verlas lado a lado{{ seleccion.length ? ` · ${seleccion.length} de 2` : '' }}.
    </div>

    <!-- Vacío -->
    <EmptyState v-if="cargado && !fotos.length" icon="📷" title="Sin fotos todavía" compact>
      <template #actions>
        <button v-if="canEdit" class="lg__btn-outline" @click="abrirCamara"><i class="bi bi-camera-fill"></i> Sacar la primera</button>
      </template>
    </EmptyState>
    <DsSpinner v-else-if="!cargado" :size="18" />

    <!-- Por semana de vida del lote -->
    <div v-for="g in grupos" :key="g.clave" class="lg__semana">
      <div class="lg__semana-head">
        <span class="lg__semana-title">{{ g.titulo }}</span>
        <span v-if="g.sub" class="lg__semana-sub">{{ g.sub }}</span>
      </div>
      <div class="lg__grid">
        <div v-for="f in g.fotos" :key="f.id" class="lg__foto"
             :class="{ 'lg__foto--sel': seleccion.includes(f.id) }" @click="tocar(f)">
          <img :src="f.thumb_url" :alt="f.nota || f.filename" class="lg__img" loading="lazy" />
          <div class="lg__foto-cap">
            <span class="lg__foto-dia">{{ f.dia ? `Día ${f.dia}` : fechaCorta(f.tomada_el) }}</span>
            <span v-if="f.plant" class="lg__foto-plant">{{ f.plant.nombre || f.plant.codigo }}</span>
          </div>
          <span v-if="f.es_portada" class="lg__badge" title="Portada en el plano de la sala">⭐</span>
          <span v-if="f.etiquetas?.some(e => e === 'problema')" class="lg__badge lg__badge--warn" title="Problema">!</span>
          <span v-if="comparando" class="lg__check"><i v-if="seleccion.includes(f.id)" class="bi bi-check-lg"></i></span>
        </div>
      </div>
    </div>

    <!-- Lightbox con ficha de la foto -->
    <Lightbox :open="lightbox" :images="imagenes" :index="indice" @close="lightbox = false" @update:index="indice = $event" />
    <Teleport to="body">
      <div v-if="lightbox && actual" class="lg__ficha" @click.stop>
        <div class="lg__ficha-main">
          <strong>{{ actual.dia ? `Día ${actual.dia}` : fechaCorta(actual.tomada_el) }}</strong>
          <span v-if="actual.semana"> · semana {{ actual.semana }}</span>
          <span v-if="actual.fase"> · {{ faseLabel(actual.fase) }}</span>
          <span> · {{ fechaCorta(actual.tomada_el) }}</span>
          <span v-if="actual.plant"> · {{ actual.plant.nombre || actual.plant.codigo }}</span>
        </div>
        <div class="lg__ficha-tags">
          <span v-for="e in actual.etiquetas" :key="e" class="lg__tag">{{ labelEtiqueta(e) }}</span>
        </div>
        <div v-if="actual.nota" class="lg__ficha-nota">{{ actual.nota }}</div>
        <div v-if="canEdit" class="lg__ficha-acts">
          <button class="lg__mini" @click="editar(actual)"><i class="bi bi-pencil"></i> Editar</button>
          <button v-if="!actual.es_portada" class="lg__mini" @click="portada(actual)"><i class="bi bi-star"></i> Portada</button>
          <button class="lg__mini lg__mini--danger" @click="eliminar(actual)"><i class="bi bi-trash"></i> Eliminar</button>
        </div>
      </div>
    </Teleport>

    <!-- Comparar: dos fotos lado a lado -->
    <Teleport to="body">
      <div v-modal="() => comparacion = null" v-if="comparacion" class="lg__overlay" @click.self="comparacion = null">
        <div class="lg__cmp">
          <div class="lg__cmp-head">
            <strong>Comparar</strong>
            <button class="lg__x" @click="comparacion = null"><i class="bi bi-x-lg"></i></button>
          </div>
          <div class="lg__cmp-body">
            <figure v-for="f in comparacion" :key="f.id" class="lg__cmp-fig">
              <img :src="f.url" :alt="f.nota || ''" />
              <figcaption>
                <strong>{{ f.dia ? `Día ${f.dia}` : fechaCorta(f.tomada_el) }}</strong>
                <span v-if="f.fase"> · {{ faseLabel(f.fase) }}</span>
                <span v-if="f.nota" class="lg__cmp-nota">{{ f.nota }}</span>
              </figcaption>
            </figure>
          </div>
          <div v-if="diferenciaDias" class="lg__cmp-foot">{{ diferenciaDias }} días de diferencia</div>
        </div>
      </div>
    </Teleport>

    <!-- Subir / editar -->
    <Teleport to="body">
      <div v-modal="cerrarForm" v-if="form" class="lg__overlay">
        <div class="lg__modal">
          <div class="lg__modal-head">
            <div>
              <h3 class="lg__modal-title">{{ form.id ? 'Editar foto' : 'Nueva foto' }}</h3>
              <p v-if="form.archivo" class="lg__modal-sub">{{ form.archivo.name }}</p>
            </div>
            <button class="lg__x" @click="cerrarForm"><i class="bi bi-x-lg"></i></button>
          </div>
          <div class="lg__modal-body">
            <img v-if="form.preview" :src="form.preview" class="lg__preview" alt="" />
            <div class="lg__row">
              <div class="lg__field">
                <label class="lg__label">Sacada el</label>
                <AppDatePicker v-model="form.tomada_el" />
              </div>
              <div v-if="plantas.length" class="lg__field">
                <label class="lg__label">Planta <span class="lg__opt">opcional</span></label>
                <select v-model="form.plant_id" class="lg__input">
                  <option value="">Todo el lote</option>
                  <option v-for="p in plantas" :key="p.id" :value="p.id">{{ p.nombre || p.codigo_qr || `#${p.id}` }}</option>
                </select>
              </div>
            </div>
            <div class="lg__field">
              <label class="lg__label">Etiquetas</label>
              <div class="lg__chips">
                <button v-for="e in etiquetasOfrecidas" :key="e.clave" type="button" class="lg__chip"
                        :class="{ 'lg__chip--on': form.etiquetas.includes(e.clave) }" @click="toggleEtiqueta(e.clave)">
                  {{ e.label }}
                </button>
                <input v-model.trim="nuevaEtiqueta" class="lg__chip-input" placeholder="+ otra" maxlength="20" @keydown.enter.prevent="agregarEtiqueta" @blur="agregarEtiqueta" />
              </div>
            </div>
            <div class="lg__field">
              <label class="lg__label">Nota <span class="lg__opt">opcional · entra a la línea de tiempo</span></label>
              <input v-model.trim="form.nota" class="lg__input" maxlength="300" placeholder="Ej: primeras hojas verdaderas, puntas quemadas…" />
            </div>
          </div>
          <div class="lg__modal-foot">
            <button class="lg__btn-ghost" @click="cerrarForm">Cancelar</button>
            <button class="lg__btn-primary" :disabled="subiendo" @click="guardar">
              <DsSpinner v-if="subiendo" :size="14" />
              <i v-else class="bi" :class="form.id ? 'bi-check2' : 'bi-cloud-upload'"></i>
              {{ form.id ? 'Guardar' : 'Subir foto' }}
            </button>
          </div>
        </div>
      </div>
    </Teleport>
  </div>
</template>

<script setup>
// Ver crecer la planta. La galería del lote agrupa por semana de vida, filtra por etiqueta,
// abre grande con su ficha y compara dos fotos lado a lado. Días, semanas y fases los manda el
// backend (`FotosLoteController`); acá sólo se agrupa y se muestra.
import { ref, computed, onMounted, watch } from 'vue'
import DsSpinner from '../../design-system/components/Spinner.vue'
import EmptyState from '../ui/EmptyState.vue'
import Lightbox   from '../ui/Lightbox.vue'
import AppDatePicker from '../ui/AppDatePicker.vue'
import { useToast } from '../../composables/useToast.js'
import { useConfirm } from '../../composables/useConfirm.js'
import { useRecargaEnCambios } from '../../composables/useRecargaEnCambios.js'
import { getLoteFotos, uploadFotoLote, updateFotoLote, deleteFotoLote, setFotoPortadaLote } from '../../lib/api.js'
import { hoyISO } from '../../utils/dates.js'

const props = defineProps({
  loteId:  { type: [Number, String], required: true },
  canEdit: { type: Boolean, default: false },
  plantas: { type: Array, default: () => [] },
})

const toast = useToast()
const { confirm } = useConfirm()

const fotos     = ref([])
const cargado   = ref(false)
const diaActual = ref(null)
const etiquetasCatalogo = ref([])
const etiquetasUsadas   = ref([])
const filtro    = ref(null)
const subiendo  = ref(false)
const inputCamara  = ref(null)
const inputArchivo = ref(null)

async function cargar() {
  try {
    const { data } = await getLoteFotos(props.loteId)
    fotos.value = data.fotos || []
    diaActual.value = data.dia_actual
    etiquetasCatalogo.value = data.etiquetas || []
    etiquetasUsadas.value   = data.etiquetas_usadas || []
  } catch { fotos.value = [] } finally { cargado.value = true }
}
onMounted(cargar)
watch(() => props.loteId, cargar)
// Otra pestaña o el teléfono sacó una foto: aparece sola.
useRecargaEnCambios('fotos', cargar, { filtro: ev => true })

const FASES = { enraizado: 'Enraizando', vegetativo: 'Vegetativo', floracion: 'Floración', cosecha: 'Cosecha', secado: 'Secado', curado: 'Curado', en_manicura: 'Manicura', finalizado: 'Finalizado' }
const faseLabel = f => FASES[f] || f
const labelEtiqueta = e => etiquetasCatalogo.value.find(x => x.clave === e)?.label || e.replace(/_/g, ' ')
const fechaCorta = iso => iso ? new Date(iso + 'T00:00:00').toLocaleDateString('es-AR', { day: 'numeric', month: 'short' }) : ''

const etiquetasEnUso = computed(() => [...new Set(fotos.value.flatMap(f => f.etiquetas || []))])
const visibles = computed(() => filtro.value ? fotos.value.filter(f => f.etiquetas?.includes(filtro.value)) : fotos.value)

// Grupos por semana de vida, de la más reciente a la primera. Sin fecha de inicio, por mes.
const grupos = computed(() => {
  const map = new Map()
  for (const f of visibles.value) {
    const clave = f.semana ? `s${f.semana}` : (f.tomada_el || '').slice(0, 7)
    if (!map.has(clave)) {
      const fases = new Set()
      map.set(clave, { clave, semana: f.semana, mes: (f.tomada_el || '').slice(0, 7), fotos: [], fases })
    }
    const g = map.get(clave); g.fotos.push(f); if (f.fase) g.fases.add(f.fase)
  }
  return [...map.values()]
    .sort((a, b) => (b.semana || 0) - (a.semana || 0) || (b.mes > a.mes ? 1 : -1))
    .map(g => ({
      ...g,
      titulo: g.semana ? `Semana ${g.semana}` : new Date(g.mes + '-01T00:00:00').toLocaleDateString('es-AR', { month: 'long', year: 'numeric' }),
      sub: g.semana ? `días ${(g.semana - 1) * 7 + 1}–${g.semana * 7}${g.fases.size ? ' · ' + [...g.fases].map(faseLabel).join(' / ') : ''}` : null,
      fotos: [...g.fotos].sort((a, b) => (a.tomada_el > b.tomada_el ? 1 : -1)),
    }))
})

// ── Ver grande ──
const lightbox = ref(false)
const indice   = ref(0)
const lista    = computed(() => grupos.value.flatMap(g => g.fotos))
const imagenes = computed(() => lista.value.map(f => ({ src: f.url, alt: f.nota || (f.dia ? `Día ${f.dia}` : ''), nombre: f.filename })))
const actual   = computed(() => lista.value[indice.value])

// ── Comparar ──
const comparando  = ref(false)
const seleccion   = ref([])
const comparacion = ref(null)
function toggleComparar() { comparando.value = !comparando.value; seleccion.value = [] }
function tocar(f) {
  if (!comparando.value) { indice.value = lista.value.findIndex(x => x.id === f.id); lightbox.value = true; return }
  const i = seleccion.value.indexOf(f.id)
  if (i >= 0) seleccion.value.splice(i, 1)
  else seleccion.value.push(f.id)
  if (seleccion.value.length === 2) {
    comparacion.value = seleccion.value.map(id => fotos.value.find(x => x.id === id)).sort((a, b) => (a.tomada_el > b.tomada_el ? 1 : -1))
    seleccion.value = []
  }
}
// Cerrar la comparación es salir del modo: si no, el siguiente toque «selecciona» en vez de
// abrir la foto y parece que la galería no responde.
watch(comparacion, (v) => { if (!v) { comparando.value = false; seleccion.value = [] } })
const diferenciaDias = computed(() => {
  if (!comparacion.value) return null
  const [a, b] = comparacion.value
  return Math.round((new Date(b.tomada_el) - new Date(a.tomada_el)) / 86400000)
})

// ── Subir / editar ──
const form = ref(null)
const nuevaEtiqueta = ref('')
const etiquetasOfrecidas = computed(() => [
  ...etiquetasCatalogo.value,
  ...etiquetasUsadas.value.map(e => ({ clave: e, label: e.replace(/_/g, ' ') })),
  ...(form.value?.etiquetas || []).filter(e => !etiquetasCatalogo.value.some(c => c.clave === e) && !etiquetasUsadas.value.includes(e)).map(e => ({ clave: e, label: e.replace(/_/g, ' ') })),
])
function abrirCamara()  { inputCamara.value?.click() }
defineExpose({ abrirCamara })
function abrirArchivo() { inputArchivo.value?.click() }
function onArchivo(e) {
  const archivo = e.target.files?.[0]
  e.target.value = ''
  if (!archivo) return
  form.value = { id: null, archivo, preview: URL.createObjectURL(archivo), tomada_el: hoyISO(), plant_id: '', etiquetas: ['general'], nota: '' }
}
function editar(f) {
  lightbox.value = false
  form.value = { id: f.id, archivo: null, preview: f.url, tomada_el: f.tomada_el, plant_id: f.plant?.id || '', etiquetas: [...(f.etiquetas || [])], nota: f.nota || '' }
}
function toggleEtiqueta(e) {
  const i = form.value.etiquetas.indexOf(e)
  if (i >= 0) form.value.etiquetas.splice(i, 1); else form.value.etiquetas.push(e)
}
function agregarEtiqueta() {
  const e = nuevaEtiqueta.value.toLowerCase().replace(/\s+/g, '_')
  if (e && !form.value.etiquetas.includes(e)) form.value.etiquetas.push(e)
  nuevaEtiqueta.value = ''
}
function cerrarForm() { if (form.value?.archivo) URL.revokeObjectURL(form.value.preview); form.value = null }
async function guardar() {
  subiendo.value = true
  try {
    if (form.value.id) {
      const { data } = await updateFotoLote(props.loteId, form.value.id, { tomada_el: form.value.tomada_el, plant_id: form.value.plant_id || null, etiquetas: form.value.etiquetas, nota: form.value.nota })
      fotos.value = fotos.value.map(f => (f.id === data.id ? data : f))
      toast.success('Foto actualizada')
    } else {
      const fd = new FormData()
      fd.append('imagen', form.value.archivo)
      fd.append('tomada_el', form.value.tomada_el)
      if (form.value.plant_id) fd.append('plant_id', form.value.plant_id)
      form.value.etiquetas.forEach(e => fd.append('etiquetas[]', e))
      if (form.value.nota) fd.append('nota', form.value.nota)
      const { data } = await uploadFotoLote(props.loteId, fd)
      fotos.value.push(data)
      toast.success('Foto guardada')
    }
    cerrarForm()
  } catch (e) {
    toast.error(e?.response?.data?.errors?.[0] || e?.response?.data?.error || 'No se pudo guardar la foto')
  } finally { subiendo.value = false }
}
async function eliminar(f) {
  const ok = await confirm({ title: 'Eliminar foto', message: 'No se puede deshacer.', confirmText: 'Eliminar', variant: 'danger' })
  if (!ok) return
  try {
    await deleteFotoLote(props.loteId, f.id)
    lightbox.value = false
    fotos.value = fotos.value.filter(x => x.id !== f.id)
    toast.success('Foto eliminada')
  } catch { toast.error('No se pudo eliminar') }
}
async function portada(f) {
  try {
    await setFotoPortadaLote(props.loteId, f.id)
    fotos.value = fotos.value.map(x => ({ ...x, es_portada: x.id === f.id }))
    toast.success('Es la portada del lote en el plano de la sala')
  } catch { toast.error('No se pudo marcar la portada') }
}
</script>

<style scoped>
.lg { display: flex; flex-direction: column; gap: .85rem; }
.lg__head { display: flex; align-items: center; justify-content: space-between; gap: .75rem; flex-wrap: wrap; }
.lg__head-left { display: flex; align-items: center; gap: .5rem; }
.lg__head-right { display: flex; align-items: center; gap: .4rem; }
.lg__emoji { font-size: 1.1rem; }
.lg__title { font-weight: 700; font-size: .95rem; color: var(--c-ink-900); }
.lg__pill { background: var(--c-leaf-100, #E5EFE9); color: var(--c-leaf-800, #1A3D2E); border-radius: 999px; padding: .05rem .5rem; font-size: .72rem; font-weight: 700; }
.lg__dia { font-size: .78rem; color: var(--c-ink-500); }
.lg__btn-primary { display: inline-flex; align-items: center; gap: .4rem; background: var(--c-leaf-800, #1A3D2E); color: #fff; border: 0; border-radius: 10px; padding: .5rem .85rem; font-size: .82rem; font-weight: 700; cursor: pointer; }
.lg__btn-ghost { display: inline-flex; align-items: center; gap: .4rem; background: #fff; color: var(--c-ink-700); border: 1.5px solid var(--c-ink-300); border-radius: 10px; padding: .45rem .7rem; font-size: .82rem; font-weight: 600; cursor: pointer; }
.lg__btn-ghost--on { border-color: var(--c-leaf-600); color: var(--c-leaf-800); background: var(--c-leaf-50, #F4F8F5); }
.lg__btn-outline { display: inline-flex; align-items: center; gap: .4rem; background: #fff; color: var(--c-leaf-800); border: 1.5px solid var(--c-leaf-600); border-radius: 10px; padding: .5rem .85rem; font-size: .82rem; font-weight: 700; cursor: pointer; }
.lg__btn-primary:disabled, .lg__btn-ghost:disabled { opacity: .6; cursor: wait; }
.lg__chips { display: flex; flex-wrap: wrap; gap: .35rem; align-items: center; }
.lg__chip { border: 1.5px solid var(--c-ink-300); background: #fff; border-radius: 999px; padding: .28rem .7rem; font-size: .76rem; font-weight: 600; color: var(--c-ink-700); cursor: pointer; text-transform: capitalize; }
.lg__chip--on { border-color: var(--c-leaf-600); background: var(--c-leaf-50, #F4F8F5); color: var(--c-leaf-800); }
.lg__chip-input { border: 1.5px dashed var(--c-ink-300); border-radius: 999px; padding: .28rem .7rem; font-size: .76rem; width: 6.5rem; outline: none; }
.lg__comparar-hint { font-size: .8rem; color: var(--c-leaf-800); background: var(--c-leaf-50, #F4F8F5); border-radius: 8px; padding: .5rem .75rem; }
.lg__semana { display: flex; flex-direction: column; }
.lg__semana-head { display: flex; align-items: baseline; gap: .5rem; margin: .25rem 0 .45rem; }
.lg__semana-title { font-weight: 700; font-size: .86rem; color: var(--c-ink-900); }
.lg__semana-sub { font-size: .74rem; color: var(--c-ink-500); }
.lg__grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(140px, 1fr)); gap: .5rem; }
@media (max-width: 640px) { .lg__grid { grid-template-columns: repeat(3, 1fr); gap: .3rem; } }
.lg__foto { position: relative; aspect-ratio: 1; border-radius: 10px; overflow: hidden; background: var(--c-ink-100); cursor: pointer; border: 2px solid transparent; }
.lg__foto--sel { border-color: var(--c-leaf-600); }
.lg__img { width: 100%; height: 100%; object-fit: cover; display: block; }
.lg__foto-cap { position: absolute; left: 0; right: 0; bottom: 0; padding: .35rem .5rem; background: linear-gradient(transparent, rgba(0,0,0,.6)); color: #fff; font-size: .7rem; display: flex; justify-content: space-between; gap: .3rem; }
.lg__foto-dia { font-weight: 700; }
.lg__foto-plant { opacity: .9; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.lg__badge { position: absolute; top: .3rem; right: .3rem; background: rgba(255,255,255,.9); border-radius: 999px; font-size: .7rem; padding: .05rem .35rem; }
.lg__badge--warn { right: auto; left: .3rem; background: #dc2626; color: #fff; font-weight: 800; }
.lg__check { position: absolute; top: .3rem; left: .3rem; width: 22px; height: 22px; border-radius: 50%; background: #fff; border: 2px solid var(--c-leaf-600); display: flex; align-items: center; justify-content: center; color: var(--c-leaf-800); font-size: .8rem; }
/* Ficha bajo el lightbox */
.lg__ficha { position: fixed; left: 50%; bottom: 1.25rem; transform: translateX(-50%); z-index: 10001; background: rgba(20,24,22,.92); color: #fff; border-radius: 12px; padding: .7rem .9rem; max-width: min(92vw, 560px); display: flex; flex-direction: column; gap: .35rem; font-size: .82rem; }
.lg__ficha-main { line-height: 1.35; }
.lg__ficha-tags { display: flex; gap: .3rem; flex-wrap: wrap; }
.lg__tag { background: rgba(255,255,255,.15); border-radius: 999px; padding: .1rem .5rem; font-size: .72rem; text-transform: capitalize; }
.lg__ficha-nota { font-size: .86rem; }
.lg__ficha-acts { display: flex; gap: .4rem; margin-top: .2rem; }
.lg__mini { background: rgba(255,255,255,.12); color: #fff; border: 0; border-radius: 8px; padding: .3rem .6rem; font-size: .76rem; cursor: pointer; }
.lg__mini--danger { color: #fca5a5; }
/* Comparar + modal */
.lg__overlay { position: fixed; inset: 0; background: rgba(0,0,0,.5); z-index: 9500; display: flex; align-items: center; justify-content: center; padding: 1rem; }
.lg__cmp { background: #fff; border-radius: 14px; width: min(96vw, 1100px); max-height: 92vh; display: flex; flex-direction: column; }
.lg__cmp-head, .lg__modal-head { display: flex; justify-content: space-between; align-items: center; padding: .85rem 1rem; border-bottom: 1px solid var(--c-ink-100); }
.lg__cmp-body { display: grid; grid-template-columns: 1fr 1fr; gap: .5rem; padding: .75rem; overflow: auto; }
@media (max-width: 640px) { .lg__cmp-body { grid-template-columns: 1fr; } }
.lg__cmp-fig { margin: 0; }
.lg__cmp-fig img { width: 100%; max-height: 60vh; object-fit: contain; background: var(--c-ink-100); border-radius: 10px; }
.lg__cmp-fig figcaption { padding: .4rem .2rem; font-size: .82rem; color: var(--c-ink-700); display: flex; flex-direction: column; }
.lg__cmp-nota { color: var(--c-ink-500); }
.lg__cmp-foot { padding: .5rem 1rem .85rem; font-size: .8rem; color: var(--c-ink-500); text-align: center; }
.lg__x { background: none; border: 0; font-size: 1rem; cursor: pointer; color: var(--c-ink-500); }
.lg__modal { background: #fff; border-radius: 14px; width: min(96vw, 520px); max-height: 92vh; display: flex; flex-direction: column; overflow: hidden; }
.lg__modal-title { margin: 0; font-size: 1rem; }
.lg__modal-sub { margin: 0; font-size: .74rem; color: var(--c-ink-500); }
.lg__modal-body { padding: .9rem 1rem; display: flex; flex-direction: column; gap: .8rem; overflow: auto; }
.lg__modal-foot { display: flex; justify-content: flex-end; gap: .5rem; padding: .75rem 1rem; border-top: 1px solid var(--c-ink-100); }
.lg__preview { width: 100%; max-height: 38vh; object-fit: contain; border-radius: 10px; background: var(--c-ink-100); }
.lg__row { display: grid; grid-template-columns: 1fr 1fr; gap: .6rem; }
@media (max-width: 480px) { .lg__row { grid-template-columns: 1fr; } }
.lg__field { display: flex; flex-direction: column; gap: .3rem; }
.lg__label { font-size: .7rem; font-weight: 700; text-transform: uppercase; letter-spacing: .04em; color: var(--c-ink-700); }
.lg__opt { font-weight: 500; text-transform: none; letter-spacing: 0; color: var(--c-ink-500); }
.lg__input { border: 1.5px solid var(--c-ink-300); border-radius: 10px; padding: .5rem .7rem; font-size: .88rem; }
</style>
