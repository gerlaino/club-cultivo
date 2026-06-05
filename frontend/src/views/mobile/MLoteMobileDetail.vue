<template>
  <div class="mlot" v-if="lote">

    <!-- Hero -->
    <div class="mlot__hero" :style="{ background: estadoGradient(lote.estado) }">
      <div class="mlot__hero-estado">{{ estadoEmoji(lote.estado) }} {{ estadoLabel(lote.estado) }}</div>
      <h2 class="mlot__hero-codigo">{{ lote.codigo }}</h2>
      <div class="mlot__hero-meta">
        <span>{{ lote.genetica?.nombre || '—' }}</span>
        <span class="mlot__sep">·</span>
        <span>{{ lote.plants_count || 0 }} plantas</span>
        <template v-if="lote.sala?.nombre">
          <span class="mlot__sep">·</span>
          <span>{{ lote.sala.nombre }}</span>
        </template>
      </div>
    </div>

    <!-- Acciones -->
    <div class="mlot__actions">
      <button class="mlot__btn-registrar" @click="showRegistrar = true">
        <i class="bi bi-pencil-square"></i>
        Registrar actividad
      </button>
      <button class="mlot__btn-acciones" @click="showAcciones = true">
        <i class="bi bi-three-dots-vertical"></i>
        Más
      </button>
    </div>

    <!-- Plantas -->
    <div class="mlot__section-title">Plantas del lote</div>
    <div v-if="loadingPlantas" class="mlot__loading-plantas">Cargando…</div>
    <div v-else-if="!plantas.length" class="mlot__empty">Sin plantas registradas</div>
    <div v-else class="mlot__list">
      <RouterLink
        v-for="p in plantas"
        :key="p.id"
        :to="`/m/planta/${p.id}`"
        class="mlot__card"
      >
        <div class="mlot__card-dot" :style="{ background: plantaColor(p.state) }"></div>
        <div class="mlot__card-info">
          <div class="mlot__card-nombre">{{ p.nombre || p.codigo_qr || `Planta #${p.id}` }}</div>
        </div>
        <span class="mlot__planta-estado" :style="{ color: plantaColor(p.state) }">
          {{ plantaLabel(p.state) }}
        </span>
        <i class="bi bi-chevron-right mlot__chevron"></i>
      </RouterLink>
    </div>

    <!-- Paginador plantas -->
    <div v-if="totalPaginas > 1" class="mlot__pager">
      <button :disabled="pagina <= 1" @click="pagina--" class="mlot__pager-btn"><i class="bi bi-chevron-left"></i></button>
      <span class="mlot__pager-info">{{ pagina }} / {{ totalPaginas }}</span>
      <button :disabled="pagina >= totalPaginas" @click="pagina++" class="mlot__pager-btn"><i class="bi bi-chevron-right"></i></button>
    </div>

    <!-- Modal registro lote (reutiliza el de la web) -->
    <RegistroLoteModal
      v-model="showRegistrar"
      :lote="lote"
      :plants="plantas"
      @saved="recargarLote"
    />

    <!-- Sheet: Más acciones -->
    <SheetBottom v-model="showAcciones" title="Acciones del lote">
      <div class="mlot__accion-list">
        <button class="mlot__accion-item" @click="abrirAvanzarFase">
          <span class="mlot__accion-ico">🚀</span>
          <span class="mlot__accion-lbl">Avanzar fase</span>
          <i class="bi bi-chevron-right mlot__accion-arr"></i>
        </button>
        <button class="mlot__accion-item" @click="abrirNuevaPlanta">
          <span class="mlot__accion-ico">🌱</span>
          <span class="mlot__accion-lbl">Nueva planta</span>
          <i class="bi bi-chevron-right mlot__accion-arr"></i>
        </button>
        <button class="mlot__accion-item" @click="abrirEditarLote">
          <span class="mlot__accion-ico">✏️</span>
          <span class="mlot__accion-lbl">Editar lote</span>
          <i class="bi bi-chevron-right mlot__accion-arr"></i>
        </button>
        <button class="mlot__accion-item" @click="abrirFoto">
          <span class="mlot__accion-ico">📷</span>
          <span class="mlot__accion-lbl">Tomar foto</span>
          <i class="bi bi-chevron-right mlot__accion-arr"></i>
        </button>
        <button class="mlot__accion-item mlot__accion-item--danger" @click="abrirEliminar">
          <span class="mlot__accion-ico">🗑️</span>
          <span class="mlot__accion-lbl">Eliminar lote</span>
          <i class="bi bi-chevron-right mlot__accion-arr"></i>
        </button>
      </div>
    </SheetBottom>

    <!-- Sheet: Avanzar fase -->
    <SheetBottom v-model="showAvanzarFase" title="🚀 Avanzar fase">
      <div class="mlot__sheet-body">
        <p class="mlot__sheet-desc">
          Fase actual: <strong>{{ estadoLabel(lote.estado) }}</strong>
        </p>
        <div class="mlot__field">
          <label class="mlot__label">Nueva fase</label>
          <select v-model="nuevaFase" class="mlot__input">
            <option v-for="f in fasesSiguientes" :key="f.value" :value="f.value">
              {{ f.emoji }} {{ f.label }}
            </option>
          </select>
        </div>
        <div v-if="faseError" class="mlot__error">{{ faseError }}</div>
        <button class="mlot__btn-confirmar" :disabled="savingFase || !nuevaFase" @click="guardarAvanzarFase">
          <i v-if="!savingFase" class="bi bi-arrow-right-circle"></i>
          {{ savingFase ? 'Avanzando…' : 'Confirmar cambio' }}
        </button>
      </div>
    </SheetBottom>

    <!-- Sheet: Nueva planta -->
    <SheetBottom v-model="showNuevaPlanta" title="🌱 Nueva planta">
      <div class="mlot__sheet-body">
        <div class="mlot__info-box" v-if="lote">
          Nombre auto: <strong>{{ lote.codigo }}-P{{ String(plantas.length + 1).padStart(3, '0') }}</strong>
        </div>
        <div class="mlot__field">
          <label class="mlot__label">Estado inicial</label>
          <select v-model="plantaForm.state" class="mlot__input">
            <option value="germinacion">🌰 Semilla/Germinación</option>
            <option value="esqueje">✂️ Esqueje</option>
            <option value="vegetativo">🍃 Vegetativo</option>
            <option value="floracion">🌸 Floración</option>
          </select>
        </div>
        <div class="mlot__field">
          <label class="mlot__label">Origen</label>
          <select v-model="plantaForm.origen" class="mlot__input">
            <option value="semilla">🌰 Semilla</option>
            <option value="esqueje">✂️ Esqueje</option>
            <option value="division">🪴 División</option>
          </select>
        </div>
        <div v-if="plantaError" class="mlot__error">{{ plantaError }}</div>
        <button class="mlot__btn-confirmar" :disabled="savingPlanta" @click="guardarNuevaPlanta">
          <i v-if="!savingPlanta" class="bi bi-check2-circle"></i>
          {{ savingPlanta ? 'Creando…' : 'Crear planta' }}
        </button>
      </div>
    </SheetBottom>

    <!-- Sheet: Editar lote -->
    <SheetBottom v-model="showEditarLote" title="✏️ Editar lote">
      <div class="mlot__sheet-body">
        <div class="mlot__field">
          <label class="mlot__label">Código *</label>
          <input v-model.trim="editForm.codigo" class="mlot__input" />
        </div>
        <div class="mlot__field">
          <label class="mlot__label">Descripción <span class="mlot__opt">opcional</span></label>
          <textarea v-model.trim="editForm.descripcion" class="mlot__input mlot__textarea" rows="2"></textarea>
        </div>
        <div v-if="editError" class="mlot__error">{{ editError }}</div>
        <button class="mlot__btn-confirmar" :disabled="savingEdit || !editForm.codigo" @click="guardarEditarLote">
          <i v-if="!savingEdit" class="bi bi-check2-circle"></i>
          {{ savingEdit ? 'Guardando…' : 'Guardar cambios' }}
        </button>
      </div>
    </SheetBottom>

    <!-- Sheet: Confirmar eliminar -->
    <SheetBottom v-model="showEliminar" title="⚠️ Eliminar lote">
      <div class="mlot__sheet-body">
        <p class="mlot__confirm-text">
          ¿Seguro que querés eliminar el lote <strong>{{ lote.codigo }}</strong>?
          Esta acción no se puede deshacer.
        </p>
        <div v-if="eliminarError" class="mlot__error">{{ eliminarError }}</div>
        <div class="mlot__confirm-btns">
          <button class="mlot__btn-ghost" @click="showEliminar = false">Cancelar</button>
          <button class="mlot__btn-danger" :disabled="eliminando" @click="confirmarEliminar">
            {{ eliminando ? 'Eliminando…' : 'Eliminar' }}
          </button>
        </div>
      </div>
    </SheetBottom>

    <!-- Input foto oculto -->
    <input ref="fotoInput" type="file" accept="image/*" capture="environment" style="display:none" @change="subirFoto" />
  </div>
  <div v-else-if="loading" class="mlot mlot--loading"><i class="bi bi-arrow-repeat mlot__spin"></i></div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import {
  getLote, listPlants,
  avanzarFaseLote, updateLote, deleteLote, createPlant, uploadFotoLote,
} from '../../lib/api'
import { useToast }        from '../../composables/useToast'
import SheetBottom         from '../../components/cultivador/SheetBottom.vue'
import RegistroLoteModal   from '../../components/lotes/registro/RegistroLoteModal.vue'

const route  = useRoute()
const router = useRouter()
const toast  = useToast()
const id     = Number(route.params.id)

const lote    = ref(null)
const plantas = ref([])
const loading         = ref(true)
const loadingPlantas  = ref(false)
const showRegistrar   = ref(false)
const showAcciones    = ref(false)
const showAvanzarFase = ref(false)
const showNuevaPlanta = ref(false)
const showEditarLote  = ref(false)
const showEliminar    = ref(false)
const savingFase      = ref(false)
const savingPlanta    = ref(false)
const savingEdit      = ref(false)
const eliminando      = ref(false)
const faseError       = ref(null)
const plantaError     = ref(null)
const editError       = ref(null)
const eliminarError   = ref(null)
const pagina          = ref(1)
const POR_PAG         = 12
const fotoInput       = ref(null)
const nuevaFase       = ref('')

const STATE_FROM_LOTE = { semilla:'germinacion', esqueje:'esqueje', vegetativo:'vegetativo', floracion:'floracion', cosecha:'cosecha' }
const plantaForm = ref({ state: 'vegetativo', origen: 'semilla' })
const editForm   = ref({ codigo: '', descripcion: '' })

const EG = {
  vegetativo: 'linear-gradient(135deg,#0f2417,#1b5e20)',
  floracion:  'linear-gradient(135deg,#1c1028,#4a1d96)',
  cosecha:    'linear-gradient(135deg,#1c0000,#7f1d1d)',
  en_manicura:'linear-gradient(135deg,#1c1000,#78350f)',
  curado:     'linear-gradient(135deg,#0c1a33,#1d4ed8)',
}
const EE = { semilla:'🌱', esqueje:'🪴', vegetativo:'🍃', floracion:'🌸', cosecha:'✂️', en_manicura:'✂️', secado:'💨', curado:'🫙' }
const EL = { semilla:'Semilla', esqueje:'Esqueje', vegetativo:'Vegetativo', floracion:'Floración', cosecha:'Cosecha', en_manicura:'Manicura', secado:'Secado', curado:'Curado' }
const PC = { semilla:'#64748b', esqueje:'#0891b2', vegetativo:'#16a34a', floracion:'#9333ea', cosecha:'#dc2626', en_manicura:'#d97706', secado:'#d97706', curado:'#2563eb' }
const PL = { semilla:'Semilla', esqueje:'Esqueje', vegetativo:'Veget.', floracion:'Florac.', cosecha:'Cosecha', en_manicura:'Manicura', secado:'Secado', curado:'Curado', cosechado:'Cosechado' }

const FASES_ORDEN = ['semilla', 'esqueje', 'vegetativo', 'floracion', 'cosecha', 'en_manicura', 'secado', 'curado']
const FASES_META  = [
  { value:'vegetativo',  label:'Vegetativo',  emoji:'🍃' },
  { value:'floracion',   label:'Floración',   emoji:'🌸' },
  { value:'cosecha',     label:'Cosecha',     emoji:'✂️' },
  { value:'en_manicura', label:'Manicura',    emoji:'✂️' },
  { value:'secado',      label:'Secado',      emoji:'💨' },
  { value:'curado',      label:'Curado',      emoji:'🫙' },
]

const fasesSiguientes = computed(() => {
  if (!lote.value) return []
  const idx = FASES_ORDEN.indexOf(lote.value.estado)
  return FASES_META.filter(f => FASES_ORDEN.indexOf(f.value) > idx)
})

const estadoGradient = e => EG[e] || 'linear-gradient(135deg,#0f172a,#1e293b)'
const estadoEmoji    = e => EE[e] || '📦'
const estadoLabel    = e => EL[e] || e || '—'
const plantaColor    = e => PC[e] || '#64748b'
const plantaLabel    = e => PL[e] || e || '—'

const totalPaginas = computed(() => Math.max(1, Math.ceil(plantas.value.length / POR_PAG)))

async function recargarLote() {
  try {
    const { data } = await getLote(id)
    lote.value = data
  } catch {}
}

function abrirAvanzarFase() {
  nuevaFase.value   = fasesSiguientes.value[0]?.value || ''
  faseError.value   = null
  showAcciones.value    = false
  showAvanzarFase.value = true
}

async function guardarAvanzarFase() {
  if (!nuevaFase.value) return
  savingFase.value = true; faseError.value = null
  try {
    const { data } = await avanzarFaseLote(id, { estado: nuevaFase.value })
    lote.value = { ...lote.value, estado: data.estado || nuevaFase.value }
    toast.success('Fase actualizada')
    showAvanzarFase.value = false
  } catch (e) {
    faseError.value = e?.response?.data?.error || 'Error al avanzar fase'
  } finally { savingFase.value = false }
}

function abrirNuevaPlanta() {
  plantaForm.value  = { state: STATE_FROM_LOTE[lote.value?.estado] || 'vegetativo', origen: 'semilla' }
  plantaError.value = null
  showAcciones.value    = false
  showNuevaPlanta.value = true
}

async function guardarNuevaPlanta() {
  savingPlanta.value = true; plantaError.value = null
  try {
    const count  = plantas.value.length + 1
    const nombre = `${lote.value.codigo}-P${String(count).padStart(3, '0')}`
    const { data } = await createPlant({
      lote_id: id,
      nombre,
      state:   plantaForm.value.state,
      origen:  plantaForm.value.origen,
    })
    plantas.value.unshift(data)
    lote.value = { ...lote.value, plants_count: (lote.value.plants_count || 0) + 1 }
    toast.success('Planta creada')
    showNuevaPlanta.value = false
  } catch (e) {
    plantaError.value = e?.response?.data?.errors?.join(', ') || e?.response?.data?.error || 'Error al crear la planta'
  } finally { savingPlanta.value = false }
}

function abrirEditarLote() {
  editForm.value  = { codigo: lote.value.codigo, descripcion: lote.value.descripcion || '' }
  editError.value = null
  showAcciones.value  = false
  showEditarLote.value = true
}

async function guardarEditarLote() {
  if (!editForm.value.codigo) { editError.value = 'El código es obligatorio'; return }
  savingEdit.value = true; editError.value = null
  try {
    const { data } = await updateLote(id, editForm.value)
    lote.value = { ...lote.value, ...data }
    toast.success('Lote actualizado')
    showEditarLote.value = false
  } catch (e) {
    editError.value = e?.response?.data?.error || 'Error al guardar'
  } finally { savingEdit.value = false }
}

function abrirEliminar() {
  eliminarError.value = null
  showAcciones.value = false
  showEliminar.value = true
}

async function confirmarEliminar() {
  eliminando.value = true; eliminarError.value = null
  try {
    await deleteLote(id)
    toast.success('Lote eliminado')
    router.back()
  } catch (e) {
    eliminarError.value = e?.response?.data?.error || 'Error al eliminar'
    eliminando.value = false
  }
}

function abrirFoto() {
  showAcciones.value = false
  fotoInput.value?.click()
}

async function subirFoto(e) {
  const file = e.target.files?.[0]
  if (!file) return
  try {
    const fd = new FormData()
    fd.append('foto', file)
    await uploadFotoLote(id, fd)
    toast.success('Foto subida')
  } catch { toast.error('Error al subir la foto') }
  e.target.value = ''
}

onMounted(async () => {
  try {
    const [loteRes, plantasRes] = await Promise.all([
      getLote(id),
      listPlants({ lote_id: id }),
    ])
    lote.value    = loteRes.data
    plantas.value = plantasRes.data?.data || plantasRes.data || []
  } catch {} finally { loading.value = false }
})
</script>

<style scoped>
.mlot { padding: 0 0 2rem; }
.mlot--loading { display: flex; align-items: center; justify-content: center; min-height: 40vh; }
.mlot__spin { font-size: 2rem; color: #94a3b8; animation: spin .8s linear infinite; }
@keyframes spin { to { transform: rotate(360deg); } }

.mlot__hero { padding: 1.25rem 1rem 1.1rem; }
.mlot__hero-estado { font-size: .72rem; font-weight: 700; color: rgba(255,255,255,.7); margin-bottom: .4rem; text-transform: uppercase; letter-spacing: .06em; }
.mlot__hero-codigo { font-size: 1.3rem; font-weight: 800; color: #fff; margin: 0 0 .3rem; font-family: monospace; }
.mlot__hero-meta   { font-size: .78rem; color: rgba(255,255,255,.6); display: flex; gap: .4rem; flex-wrap: wrap; }
.mlot__sep { opacity: .4; }

.mlot__actions { display: flex; gap: .75rem; padding: 1rem; }
.mlot__btn-registrar {
  flex: 1; display: flex; align-items: center; justify-content: center; gap: .5rem;
  background: #1b5e20; color: #fff; border: none; padding: .875rem;
  border-radius: 12px; font-size: .95rem; font-weight: 700; cursor: pointer;
  -webkit-tap-highlight-color: transparent;
}
.mlot__btn-acciones {
  display: flex; align-items: center; gap: .4rem;
  background: #fff; color: #374151; border: 1.5px solid #e2e8f0;
  padding: .875rem 1rem; border-radius: 12px;
  font-size: .875rem; font-weight: 600; cursor: pointer; white-space: nowrap;
  -webkit-tap-highlight-color: transparent;
}

.mlot__section-title { font-size: .7rem; font-weight: 700; color: #94a3b8; text-transform: uppercase; letter-spacing: .06em; padding: .75rem 1rem .5rem; }
.mlot__loading-plantas, .mlot__empty { padding: .75rem 1rem; color: #94a3b8; font-size: .82rem; text-align: center; }
.mlot__list { display: flex; flex-direction: column; gap: .4rem; padding: 0 1rem; }
.mlot__card { display: flex; align-items: center; gap: .75rem; background: #fff; border-radius: 12px; padding: .8rem; box-shadow: 0 1px 3px rgba(0,0,0,.06); text-decoration: none; -webkit-tap-highlight-color: transparent; }
.mlot__card-dot { width: 9px; height: 9px; border-radius: 50%; flex-shrink: 0; }
.mlot__card-info { flex: 1; min-width: 0; }
.mlot__card-nombre { font-size: .875rem; font-weight: 600; color: #0f172a; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.mlot__planta-estado { font-size: .68rem; font-weight: 700; white-space: nowrap; flex-shrink: 0; }
.mlot__chevron { color: #d1d5db; font-size: .75rem; flex-shrink: 0; }

.mlot__pager { display: flex; align-items: center; justify-content: center; gap: .75rem; padding: .875rem; }
.mlot__pager-btn { background: #fff; border: 1.5px solid #e2e8f0; border-radius: 9px; width: 36px; height: 36px; display: flex; align-items: center; justify-content: center; font-size: .875rem; color: #374151; cursor: pointer; }
.mlot__pager-btn:disabled { opacity: .4; cursor: not-allowed; }
.mlot__pager-info { font-size: .8rem; color: #64748b; font-weight: 600; min-width: 44px; text-align: center; }

/* Acciones sheet */
.mlot__accion-list { display: flex; flex-direction: column; gap: 2px; }
.mlot__accion-item {
  display: flex; align-items: center; gap: .875rem;
  height: 56px; padding: 0 .5rem;
  border-radius: 10px; border: none; background: none;
  font-size: .95rem; font-weight: 500; color: #0f172a;
  cursor: pointer; text-align: left; width: 100%;
  -webkit-tap-highlight-color: transparent;
  transition: background .1s;
}
.mlot__accion-item:active { background: #f1f5f9; }
.mlot__accion-item--danger { color: #dc2626; }
.mlot__accion-ico { font-size: 1.2rem; width: 28px; text-align: center; flex-shrink: 0; }
.mlot__accion-lbl { flex: 1; }
.mlot__accion-arr { color: #d1d5db; font-size: .8rem; flex-shrink: 0; }

/* Sheet contenido */
.mlot__sheet-body { display: flex; flex-direction: column; gap: .875rem; }
.mlot__sheet-desc { font-size: .875rem; color: #374151; margin: 0; }
.mlot__field { display: flex; flex-direction: column; gap: .3rem; }
.mlot__label {
  font-size: .72rem; font-weight: 700; color: #374151;
  text-transform: uppercase; letter-spacing: .04em;
  display: flex; align-items: center; gap: .4rem;
}
.mlot__opt { font-weight: 400; text-transform: none; color: #94a3b8; font-size: .68rem; }
.mlot__input {
  background: #f8fafc; border: 1.5px solid #e2e8f0;
  border-radius: 9px; padding: .65rem .875rem;
  font-size: .9rem; color: #0f172a; outline: none;
  width: 100%; box-sizing: border-box;
}
.mlot__input:focus { border-color: #1b5e20; }
.mlot__textarea { resize: none; font-family: inherit; }
.mlot__error {
  background: #fef2f2; color: #dc2626;
  border: 1px solid #fecaca; border-radius: 8px;
  padding: .5rem .75rem; font-size: .8rem;
}
.mlot__btn-confirmar {
  width: 100%; display: flex; align-items: center; justify-content: center; gap: .5rem;
  background: #1b5e20; color: #fff; border: none;
  padding: .9rem; border-radius: 12px;
  font-size: .95rem; font-weight: 700; cursor: pointer;
}
.mlot__btn-confirmar:disabled { opacity: .6; }

/* Confirmar eliminar */
.mlot__confirm-text { font-size: .875rem; color: #374151; margin: 0; line-height: 1.5; }
.mlot__confirm-btns { display: flex; gap: .75rem; }
.mlot__btn-ghost {
  flex: 1; background: #fff; border: 1.5px solid #e2e8f0;
  color: #64748b; padding: .75rem; border-radius: 9px;
  font-size: .875rem; font-weight: 600; cursor: pointer;
}
.mlot__btn-danger {
  flex: 1; background: #dc2626; color: #fff; border: none;
  padding: .75rem; border-radius: 9px;
  font-size: .875rem; font-weight: 700; cursor: pointer;
}
.mlot__btn-danger:disabled { opacity: .6; }
.mlot__info-box { background: #f0fdf4; border: 1px solid #bbf7d0; border-radius: 9px; padding: .6rem .875rem; font-size: .8rem; color: #15803d; }
</style>
