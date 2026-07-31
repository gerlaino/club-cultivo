<template>
  <div v-if="loading" class="mlot--loading"><i class="bi bi-arrow-repeat mlot__spin"></i></div>

  <div v-else-if="!lote" class="mlot--empty">
    <div class="mlot__empty-ico"><i class="bi bi-box-seam"></i></div>
    <div class="mlot__empty-title">Lote no encontrado</div>
    <button class="mlot__empty-back" @click="router.back()">← Volver</button>
  </div>

  <div class="mlot" v-else>

    <!-- Hero -->
    <div class="mlot__hero" :style="{ background: estadoGradient(lote.estado) }">
      <button class="mlot__hero-more" @click="showAcciones = true" aria-label="Más"><i class="bi bi-three-dots"></i></button>
      <div class="mlot__hero-estado">{{ estadoEmoji(lote.estado) }} {{ estadoLabel(lote.estado) }}</div>
      <h2 class="mlot__hero-codigo">{{ lote.codigo }}</h2>
      <div class="mlot__hero-gen">{{ lote.genetica?.nombre || 'Sin genética' }}</div>

      <div class="mlot__stats">
        <div class="mlot__stat">
          <span class="mlot__stat-num">{{ lote.plants_count || 0 }}</span>
          <span class="mlot__stat-lbl">Plantas</span>
        </div>
        <div class="mlot__stat" v-if="lote.dias_en_estado != null">
          <span class="mlot__stat-num">{{ lote.dias_en_estado }}</span>
          <span class="mlot__stat-lbl">Días en fase</span>
        </div>
        <div class="mlot__stat" v-if="lote.sala?.nombre">
          <span class="mlot__stat-num mlot__stat-num--sm">{{ lote.sala.nombre }}</span>
          <span class="mlot__stat-lbl">Sala</span>
        </div>
        <div class="mlot__stat" v-else-if="lote.tamanio_maceta">
          <span class="mlot__stat-num">{{ lote.tamanio_maceta }}L</span>
          <span class="mlot__stat-lbl">Maceta</span>
        </div>
      </div>
    </div>

    <!-- CTA principal: diario del lote -->
    <div class="mlot__cta-wrap">
      <button class="mlot__cta" @click="showRegistrar = true">
        <i class="bi bi-journal-plus"></i>
        <div class="mlot__cta-txt">
          <span class="mlot__cta-title">Registrar en el diario</span>
          <span class="mlot__cta-sub">Riego, pH/EC, ambiente, plagas, foto</span>
        </div>
        <i class="bi bi-chevron-right mlot__cta-arr"></i>
      </button>
    </div>

    <!-- Acciones de campo -->
    <div class="mlot__quick">
      <button class="mlot__qa" @click="abrirFoto">
        <span class="mlot__qa-ico" style="background:#ede9fe;color:#7c3aed"><i class="bi bi-camera"></i></span>
        <span class="mlot__qa-lbl">Foto</span>
      </button>
      <button class="mlot__qa" v-if="fasesSiguientes.length" @click="abrirAvanzarFase">
        <span class="mlot__qa-ico" style="background:var(--c-leaf-100);color:var(--c-leaf-700)"><i class="bi bi-arrow-up-circle"></i></span>
        <span class="mlot__qa-lbl">Avanzar fase</span>
      </button>
      <button class="mlot__qa" @click="abrirNuevaPlanta">
        <span class="mlot__qa-ico" style="background:#dcfce7;color:#16a34a"><i class="bi bi-flower1"></i></span>
        <span class="mlot__qa-lbl">+ Planta</span>
      </button>
      <button class="mlot__qa" @click="router.push('/m/scan')">
        <span class="mlot__qa-ico" style="background:#e0f2fe;color:var(--c-sky-600)"><i class="bi bi-qr-code-scan"></i></span>
        <span class="mlot__qa-lbl">Escanear</span>
      </button>
    </div>

    <!-- Plantas -->
    <div class="mlot__section-title">
      Plantas <span class="mlot__count">{{ plantas.length }}</span>
    </div>
    <div v-if="loadingPlantas" class="mlot__muted">Cargando…</div>
    <div v-else-if="!plantas.length" class="mlot__muted">Sin plantas registradas</div>
    <div v-else class="mlot__list">
      <RouterLink
        v-for="p in plantasPagina" :key="p.id"
        :to="`/m/planta/${p.id}`" class="mlot__card"
      >
        <span class="mlot__card-dot" :style="{ background: plantaColor(p.state) }"></span>
        <div class="mlot__card-info">
          <div class="mlot__card-nombre">{{ p.nombre || p.codigo_qr || `Planta #${p.id}` }}</div>
          <div v-if="p.codigo_qr" class="mlot__card-qr">{{ p.codigo_qr }}</div>
        </div>
        <span class="mlot__planta-estado" :style="{ background: plantaColor(p.state)+'1f', color: plantaColor(p.state) }">
          {{ plantaLabel(p.state) }}
        </span>
        <i class="bi bi-chevron-right mlot__chevron"></i>
      </RouterLink>
    </div>

    <div v-if="totalPaginas > 1" class="mlot__pager">
      <button :disabled="pagina <= 1" @click="pagina--" class="mlot__pager-btn"><i class="bi bi-chevron-left"></i></button>
      <span class="mlot__pager-info">{{ pagina }} / {{ totalPaginas }}</span>
      <button :disabled="pagina >= totalPaginas" @click="pagina++" class="mlot__pager-btn"><i class="bi bi-chevron-right"></i></button>
    </div>

    <!-- Modal registro lote (reutiliza el de la web) -->
    <RegistroLoteModal v-model="showRegistrar" :lote="lote" :plants="plantas" @saved="recargarLote" />

    <!-- Sheet: Más (editar / eliminar) -->
    <SheetBottom v-model="showAcciones" title="Más acciones">
      <div class="mlot__accion-list">
        <button class="mlot__accion-item" @click="abrirEditarLote">
          <span class="mlot__accion-ico"><i class="bi bi-pencil"></i></span>
          <span class="mlot__accion-lbl">Editar lote</span>
          <i class="bi bi-chevron-right mlot__accion-arr"></i>
        </button>
        <button class="mlot__accion-item mlot__accion-item--danger" @click="abrirEliminar">
          <span class="mlot__accion-ico"><i class="bi bi-trash"></i></span>
          <span class="mlot__accion-lbl">Eliminar lote</span>
          <i class="bi bi-chevron-right mlot__accion-arr"></i>
        </button>
      </div>
    </SheetBottom>

    <!-- Sheet: Avanzar fase -->
    <SheetBottom v-model="showAvanzarFase" title="Avanzar fase">
      <div class="mlot__sheet-body">
        <p class="mlot__sheet-desc">Fase actual: <strong>{{ estadoLabel(lote.estado) }}</strong></p>
        <div class="mlot__field">
          <label class="mlot__label">Nueva fase</label>
          <select v-model="nuevaFase" class="mlot__input">
            <option v-for="f in fasesSiguientes" :key="f.value" :value="f.value">{{ f.emoji }} {{ f.label }}</option>
          </select>
        </div>
        <!-- El esqueje que prendió va a maceta: sin ese dato el lote no puede pasar a vegetativo. -->
        <div v-if="lote.estado === 'enraizado'" class="mlot__field">
          <label class="mlot__label">Maceta a la que va *</label>
          <select v-model="faseMaceta" class="mlot__input">
            <option value="">— Elegí el tamaño —</option>
            <option v-for="m in MACETAS" :key="m.v" :value="m.v">{{ m.l }}</option>
          </select>
        </div>
        <div v-if="faseError" class="mlot__error">{{ faseError }}</div>
        <button class="mlot__btn-confirmar" :disabled="savingFase || !nuevaFase || faltaMaceta" @click="guardarAvanzarFase">
          {{ savingFase ? 'Avanzando…' : 'Confirmar cambio' }}
        </button>
      </div>
    </SheetBottom>

    <!-- Sheet: Nueva planta -->
    <SheetBottom v-model="showNuevaPlanta" title="Nueva planta">
      <div class="mlot__sheet-body">
        <div class="mlot__info-box" v-if="lote">
          Nombre: <strong>{{ lote.codigo }}-P{{ String(plantas.length + 1).padStart(3, '0') }}</strong>
        </div>
        <div class="mlot__field">
          <label class="mlot__label">Estado inicial</label>
          <select v-model="plantaForm.state" class="mlot__input">
            <option value="enraizado">🌱 Enraizado</option>
            <option value="vegetativo">🍃 Vegetativo</option>
            <option value="floracion">🌸 Floración</option>
          </select>
        </div>
        <div class="mlot__field">
          <label class="mlot__label">Origen</label>
          <select v-model="plantaForm.origen" class="mlot__input">
            <option value="enraizado">🌱 Enraizado</option>
            <option value="division">🪴 División</option>
          </select>
        </div>
        <div v-if="plantaError" class="mlot__error">{{ plantaError }}</div>
        <button class="mlot__btn-confirmar" :disabled="savingPlanta" @click="guardarNuevaPlanta">
          {{ savingPlanta ? 'Creando…' : 'Crear planta' }}
        </button>
      </div>
    </SheetBottom>

    <!-- Sheet: Editar lote -->
    <SheetBottom v-model="showEditarLote" title="Editar lote">
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
          {{ savingEdit ? 'Guardando…' : 'Guardar cambios' }}
        </button>
      </div>
    </SheetBottom>

    <!-- Sheet: Eliminar -->
    <SheetBottom v-model="showEliminar" title="Eliminar lote">
      <div class="mlot__sheet-body">
        <p class="mlot__confirm-text">¿Eliminar el lote <strong>{{ lote.codigo }}</strong>? Esta acción no se puede deshacer.</p>
        <div v-if="eliminarError" class="mlot__error">{{ eliminarError }}</div>
        <div class="mlot__confirm-btns">
          <button class="mlot__btn-ghost" @click="showEliminar = false">Cancelar</button>
          <button class="mlot__btn-danger" :disabled="eliminando" @click="confirmarEliminar">
            {{ eliminando ? 'Eliminando…' : 'Eliminar' }}
          </button>
        </div>
      </div>
    </SheetBottom>

    <input ref="fotoInput" type="file" accept="image/*" capture="environment" style="display:none" @change="subirFoto" />
  </div>
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
// Maceta del trasplante al prender (enraizado → vegetativo). Ver LoteDetailView: misma regla.
const faseMaceta      = ref('')
const MACETAS = [
  { v: '0.5', l: 'Vaso (0.5 L)' }, { v: '1', l: '1 litro' },   { v: '3', l: '3 litros' },
  { v: '5',   l: '5 litros' },     { v: '7', l: '7 litros' },   { v: '10', l: '10 litros' },
  { v: '12',  l: '12 litros' },    { v: '15', l: '15 litros' }, { v: '20', l: '20 litros' },
]
const faltaMaceta = computed(() => lote.value?.estado === 'enraizado' && !faseMaceta.value)

const STATE_FROM_LOTE = { germinacion:'enraizado', esqueje:'esqueje', vegetativo:'vegetativo', floracion:'floracion', cosecha:'cosecha' }
const plantaForm = ref({ state: 'vegetativo', origen: 'semilla' })
const editForm   = ref({ codigo: '', descripcion: '' })

const EG = {
  vegetativo: 'linear-gradient(150deg,#0f2417,#1b5e20)',
  floracion:  'linear-gradient(150deg,#1c1028,#4a1d96)',
  cosecha:    'linear-gradient(150deg,#1c0000,#7f1d1d)',
  en_manicura:'linear-gradient(150deg,#1c1000,#78350f)',
  curado:     'linear-gradient(150deg,#0c1a33,#1d4ed8)',
}
const EE = { germinacion:'🌱', esqueje:'🪴', vegetativo:'🍃', floracion:'🌸', cosecha:'✂️', en_manicura:'✂️', curado:'🫙' }
const EL = { enraizado: 'Enraizado', vegetativo:'Vegetativo', floracion:'Floración', cosecha:'Cosecha', en_manicura:'Manicura', curado:'Curado' }
const PC = { germinacion:'#64748b', esqueje:'#0891b2', vegetativo:'#16a34a', floracion:'#9333ea', cosecha:'#dc2626', en_manicura:'#d97706', curado:'#2563eb', cosechado:'#dc2626', descartada:'#94a3b8' }
const PL = { enraizado:'Enraiz.', vegetativo:'Veget.', floracion:'Florac.', cosecha:'Cosecha', en_manicura:'Manicura', curado:'Curado', cosechado:'Cosechado', descartada:'Descartada' }

const FASES_ORDEN = ['enraizado', 'vegetativo', 'floracion', 'cosecha', 'en_manicura', 'curado']
const FASES_META  = [
  { value:'vegetativo',  label:'Vegetativo',  emoji:'🍃' },
  { value:'floracion',   label:'Floración',   emoji:'🌸' },
  { value:'cosecha',     label:'Cosecha',     emoji:'✂️' },
  { value:'en_manicura', label:'Manicura',    emoji:'✂️' },
    { value:'curado',      label:'Curado',      emoji:'🫙' },
]

const fasesSiguientes = computed(() => {
  if (!lote.value) return []
  const idx = FASES_ORDEN.indexOf(lote.value.estado)
  return FASES_META.filter(f => FASES_ORDEN.indexOf(f.value) > idx)
})

const estadoGradient = e => EG[e] || 'linear-gradient(150deg,#0f172a,#1e293b)'
const estadoEmoji    = e => EE[e] || '📦'
const estadoLabel    = e => EL[e] || e || '—'
const plantaColor    = e => PC[e] || '#64748b'
const plantaLabel    = e => PL[e] || e || '—'

const totalPaginas = computed(() => Math.max(1, Math.ceil(plantas.value.length / POR_PAG)))
const plantasPagina = computed(() => {
  const start = (pagina.value - 1) * POR_PAG
  return plantas.value.slice(start, start + POR_PAG)
})

async function recargarLote() {
  try { const { data } = await getLote(id); lote.value = data } catch {}
}

function abrirAvanzarFase() {
  nuevaFase.value  = fasesSiguientes.value[0]?.value || ''
  faseMaceta.value = ''
  faseError.value  = null
  showAcciones.value = false
  showAvanzarFase.value = true
}
async function guardarAvanzarFase() {
  if (!nuevaFase.value) return
  savingFase.value = true; faseError.value = null
  try {
    const payload = { estado: nuevaFase.value }
    if (faseMaceta.value) payload.tamanio_maceta = faseMaceta.value
    const { data } = await avanzarFaseLote(id, payload)
    lote.value = { ...lote.value, estado: data.estado || nuevaFase.value, dias_en_estado: 0 }
    toast.success('Fase actualizada')
    showAvanzarFase.value = false
  } catch (e) {
    faseError.value = e?.response?.data?.error || 'Error al avanzar fase'
  } finally { savingFase.value = false }
}

function abrirNuevaPlanta() {
  plantaForm.value  = { state: STATE_FROM_LOTE[lote.value?.estado] || 'vegetativo', origen: 'semilla' }
  plantaError.value = null
  showAcciones.value = false
  showNuevaPlanta.value = true
}
async function guardarNuevaPlanta() {
  savingPlanta.value = true; plantaError.value = null
  try {
    const count  = plantas.value.length + 1
    const nombre = `${lote.value.codigo}-P${String(count).padStart(3, '0')}`
    const { data } = await createPlant({ lote_id: id, nombre, state: plantaForm.value.state, origen: plantaForm.value.origen })
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
  showAcciones.value = false
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

function abrirFoto() { fotoInput.value?.click() }
async function subirFoto(e) {
  const file = e.target.files?.[0]
  if (!file) return
  try {
    const fd = new FormData(); fd.append('foto', file)
    await uploadFotoLote(id, fd)
    toast.success('Foto subida')
  } catch { toast.error('Error al subir la foto') }
  e.target.value = ''
}

onMounted(async () => {
  try {
    const [loteRes, plantasRes] = await Promise.all([getLote(id), listPlants({ lote_id: id })])
    lote.value    = loteRes.data
    plantas.value = plantasRes.data?.data || plantasRes.data || []
  } catch {} finally { loading.value = false }
})
</script>

<style scoped>
.mlot { padding: 0 0 2rem; }
.mlot--loading { display: flex; align-items: center; justify-content: center; min-height: 40vh; }
.mlot__spin { font-size: 2rem; color: var(--c-leaf-300, #a8c9b5); animation: spin .8s linear infinite; }
@keyframes spin { to { transform: rotate(360deg); } }
.mlot--empty { display: flex; flex-direction: column; align-items: center; justify-content: center; min-height: 50vh; padding: 2rem; text-align: center; gap: .75rem; }
.mlot__empty-ico { font-size: 2.6rem; color: var(--c-leaf-300, #a8c9b5); }
.mlot__empty-title { font-size: 1.05rem; font-weight: 700; color: var(--c-ink-900, #1a1d1f); }
.mlot__empty-back { margin-top: .5rem; background: none; border: 1.5px solid var(--c-ink-300, #e2e8f0); border-radius: 10px; padding: .5rem 1.25rem; font-size: .9rem; color: var(--c-ink-700, #475569); cursor: pointer; }

/* Hero */
.mlot__hero { position: relative; padding: 1.4rem 1.1rem 1.3rem; color: #fff; border-radius: 0 0 22px 22px; }
.mlot__hero-more {
  position: absolute; top: 1rem; right: 1rem;
  width: 36px; height: 36px; border-radius: 10px;
  background: rgba(255,255,255,.15); border: none; color: #fff;
  display: flex; align-items: center; justify-content: center; font-size: 1.1rem; cursor: pointer;
  -webkit-tap-highlight-color: transparent;
}
.mlot__hero-estado { font-size: .68rem; font-weight: 700; color: rgba(255,255,255,.72); text-transform: uppercase; letter-spacing: .06em; }
.mlot__hero-codigo { font-family: var(--font-display, sans-serif); font-size: 1.7rem; font-weight: 700; margin: .15rem 0 .1rem; }
.mlot__hero-gen { font-size: .85rem; color: rgba(255,255,255,.7); }

.mlot__stats { display: flex; gap: .5rem; margin-top: 1.1rem; }
.mlot__stat {
  flex: 1; background: rgba(255,255,255,.12); border-radius: 13px;
  padding: .6rem .5rem; text-align: center; min-width: 0;
}
.mlot__stat-num { display: block; font-family: var(--font-display, sans-serif); font-size: 1.25rem; font-weight: 700; line-height: 1.1; }
.mlot__stat-num--sm { font-size: .8rem; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.mlot__stat-lbl { display: block; font-size: .62rem; color: rgba(255,255,255,.65); margin-top: .2rem; }

/* CTA diario */
.mlot__cta-wrap { padding: 1rem 1.1rem .4rem; }
.mlot__cta {
  width: 100%; display: flex; align-items: center; gap: .8rem;
  background: var(--c-leaf-800, #1a3d2e); color: #fff; border: none;
  padding: .9rem 1rem; border-radius: var(--r-xl, 14px); cursor: pointer; text-align: left;
  -webkit-tap-highlight-color: transparent; transition: transform .12s;
}
.mlot__cta:active { transform: scale(.985); }
.mlot__cta > .bi:first-child { font-size: 1.4rem; flex-shrink: 0; }
.mlot__cta-txt { flex: 1; min-width: 0; }
.mlot__cta-title { display: block; font-size: .95rem; font-weight: 700; }
.mlot__cta-sub { display: block; font-size: .72rem; color: rgba(255,255,255,.7); margin-top: .1rem; }
.mlot__cta-arr { opacity: .6; }

/* Acciones rápidas */
.mlot__quick { display: grid; grid-template-columns: repeat(4, 1fr); gap: .5rem; padding: .6rem 1.1rem .4rem; }
.mlot__qa {
  display: flex; flex-direction: column; align-items: center; gap: .4rem;
  background: #fff; border: 1px solid var(--c-leaf-100, #e8f0eb); border-radius: var(--r-xl, 14px);
  padding: .7rem .25rem; cursor: pointer; -webkit-tap-highlight-color: transparent;
  transition: transform .12s, box-shadow .15s;
}
.mlot__qa:active { transform: scale(.95); }
.mlot__qa-ico { width: 40px; height: 40px; border-radius: 12px; display: flex; align-items: center; justify-content: center; font-size: 1.15rem; }
.mlot__qa-lbl { font-size: .68rem; font-weight: 600; color: var(--c-ink-900, #1a1d1f); text-align: center; }

/* Plantas */
.mlot__section-title { font-size: .72rem; font-weight: 700; color: var(--c-ink-500, #6b7280); text-transform: uppercase; letter-spacing: .06em; padding: 1.1rem 1.1rem .6rem; display: flex; align-items: center; gap: .5rem; }
.mlot__count { background: var(--c-leaf-100, #e8f0eb); color: var(--c-leaf-700, #2d4a3e); border-radius: 999px; padding: .05rem .5rem; font-size: .7rem; }
.mlot__muted { padding: .75rem 1.1rem; color: var(--c-ink-500, #6b7280); font-size: .82rem; text-align: center; }
.mlot__list { display: flex; flex-direction: column; gap: .45rem; padding: 0 1.1rem; }
.mlot__card {
  display: flex; align-items: center; gap: .75rem; background: #fff;
  border: 1px solid var(--c-leaf-100, #e8f0eb); border-radius: var(--r-lg, 12px); padding: .75rem .85rem;
  text-decoration: none; -webkit-tap-highlight-color: transparent; transition: border-color .15s, box-shadow .15s;
}
.mlot__card:active { transform: scale(.99); }
.mlot__card:hover { border-color: var(--c-leaf-300, #a8c9b5); box-shadow: var(--sh-1); }
.mlot__card-dot { width: 9px; height: 9px; border-radius: 50%; flex-shrink: 0; }
.mlot__card-info { flex: 1; min-width: 0; }
.mlot__card-nombre { font-size: .875rem; font-weight: 600; color: var(--c-ink-900, #1a1d1f); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.mlot__card-qr { font-family: var(--font-mono, monospace); font-size: .64rem; color: var(--c-ink-500, #6b7280); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.mlot__planta-estado { font-size: .65rem; font-weight: 700; white-space: nowrap; flex-shrink: 0; padding: .15rem .5rem; border-radius: 999px; }
.mlot__chevron { color: var(--c-ink-300, #d1d5db); font-size: .75rem; flex-shrink: 0; }

.mlot__pager { display: flex; align-items: center; justify-content: center; gap: .75rem; padding: .9rem; }
.mlot__pager-btn { background: #fff; border: 1px solid var(--c-leaf-100, #e8f0eb); border-radius: 10px; width: 38px; height: 38px; display: flex; align-items: center; justify-content: center; color: var(--c-ink-700, #374151); cursor: pointer; }
.mlot__pager-btn:disabled { opacity: .4; }
.mlot__pager-info { font-size: .8rem; color: var(--c-ink-500, #6b7280); font-weight: 600; min-width: 44px; text-align: center; }

/* Sheet acciones */
.mlot__accion-list { display: flex; flex-direction: column; gap: 2px; }
.mlot__accion-item { display: flex; align-items: center; gap: .85rem; height: 54px; padding: 0 .5rem; border-radius: 10px; border: none; background: none; font-size: .95rem; font-weight: 500; color: var(--c-ink-900, #1a1d1f); cursor: pointer; text-align: left; width: 100%; -webkit-tap-highlight-color: transparent; }
.mlot__accion-item:active { background: var(--c-leaf-50, #f4f8f5); }
.mlot__accion-item--danger { color: #dc2626; }
.mlot__accion-ico { font-size: 1.1rem; width: 28px; text-align: center; flex-shrink: 0; }
.mlot__accion-lbl { flex: 1; }
.mlot__accion-arr { color: var(--c-ink-300, #d1d5db); font-size: .8rem; }

/* Sheet contenido */
.mlot__sheet-body { display: flex; flex-direction: column; gap: .85rem; }
.mlot__sheet-desc { font-size: .875rem; color: var(--c-ink-700, #374151); margin: 0; }
.mlot__field { display: flex; flex-direction: column; gap: .3rem; }
.mlot__label { font-size: .72rem; font-weight: 700; color: var(--c-ink-700, #374151); text-transform: uppercase; letter-spacing: .04em; display: flex; gap: .4rem; }
.mlot__opt { font-weight: 400; text-transform: none; color: var(--c-ink-500, #94a3b8); }
.mlot__input { background: var(--c-leaf-50, #f8fafc); border: 1.5px solid var(--c-leaf-100, #e2e8f0); border-radius: 10px; padding: .65rem .875rem; font-size: .9rem; color: var(--c-ink-900, #0f172a); outline: none; width: 100%; box-sizing: border-box; }
.mlot__input:focus { border-color: var(--c-leaf-500, #1b5e20); }
.mlot__textarea { resize: none; font-family: inherit; }
.mlot__error { background: #fef2f2; color: #dc2626; border: 1px solid #fecaca; border-radius: 8px; padding: .5rem .75rem; font-size: .8rem; }
.mlot__btn-confirmar { width: 100%; background: var(--c-leaf-800, #1a3d2e); color: #fff; border: none; padding: .9rem; border-radius: 12px; font-size: .95rem; font-weight: 700; cursor: pointer; }
.mlot__btn-confirmar:disabled { opacity: .6; }
.mlot__confirm-text { font-size: .875rem; color: var(--c-ink-700, #374151); margin: 0; line-height: 1.5; }
.mlot__confirm-btns { display: flex; gap: .75rem; }
.mlot__btn-ghost { flex: 1; background: #fff; border: 1.5px solid var(--c-ink-300, #e2e8f0); color: var(--c-ink-500, #64748b); padding: .75rem; border-radius: 10px; font-size: .875rem; font-weight: 600; cursor: pointer; }
.mlot__btn-danger { flex: 1; background: #dc2626; color: #fff; border: none; padding: .75rem; border-radius: 10px; font-size: .875rem; font-weight: 700; cursor: pointer; }
.mlot__btn-danger:disabled { opacity: .6; }
.mlot__info-box { background: var(--c-leaf-50, #f0fdf4); border: 1px solid var(--c-leaf-100, #bbf7d0); border-radius: 10px; padding: .6rem .875rem; font-size: .8rem; color: var(--c-leaf-700, #15803d); }
</style>
