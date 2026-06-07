<template>
  <div class="page">
    <div class="page-header">
      <button class="back-btn" @click="router.back()">‹</button>
      <h1>{{ lote?.codigo || 'Lote' }}</h1>
      <span v-if="lote" class="pill" :style="estadoStyle(lote.estado)">{{ lote.estado }}</span>
    </div>

    <div class="page-content">
      <div v-if="loading" class="empty-state"><div class="spinner spinner--dark" /></div>
      <template v-else>
        <div class="lote-meta card" style="margin-bottom:1rem">
          <div class="lote-meta__row"><span>Cepa</span><strong>{{ lote.cepa?.nombre || '—' }}</strong></div>
          <div class="lote-meta__row"><span>Sala</span><strong>{{ lote.sala?.nombre || '—' }}</strong></div>
          <div class="lote-meta__row"><span>Día</span><strong>{{ diasEnCiclo }}</strong></div>
        </div>

        <p class="section-title">Plantas ({{ plantas.length }})</p>
        <div v-if="!plantas.length" class="empty-state">
          <div class="icon">🌱</div>
          <p>Sin plantas en este lote</p>
        </div>
        <div v-else class="plantas-grid">
          <button
            v-for="planta in plantas"
            :key="planta.id"
            class="planta-chip"
            :class="{ 'planta-chip--warn': planta.estado_salud === 'malo' || planta.estado_salud === 'critico' }"
            @click="router.push({ name: 'planta-detail', params: { id: planta.id } })"
          >
            <span class="planta-chip__emoji">{{ estadoEmoji(planta.state) }}</span>
            <span class="planta-chip__nombre">{{ planta.nombre || `#${planta.id}` }}</span>
            <span v-if="planta.estado_salud" class="planta-chip__salud" :style="{ color: saludColor(planta.estado_salud) }">●</span>
          </button>
        </div>
      </template>
    </div>

    <!-- Action bar -->
    <div v-if="!loading" class="action-bar">
      <button class="btn btn-secondary" style="flex:1" @click="showRegistro = true">
        📋 Registrar lote
      </button>
      <button class="btn btn-ghost" style="flex:1" @click="showAcciones = true">
        ⚡ Más
      </button>
    </div>

    <!-- BS: Registrar lote -->
    <BottomSheet v-model="showRegistro" title="Registrar lote" :tall="true">
      <p style="font-size:.82rem;color:var(--text-2);margin-bottom:1rem">¿Qué realizaste hoy?</p>
      <div class="chip-group" style="margin-bottom:1rem">
        <button
          v-for="accion in ACCIONES"
          :key="accion.id"
          class="chip"
          :class="{ 'chip--active': regForm.tareas.includes(accion.id) }"
          @click="toggleTarea(accion.id)"
        >{{ accion.emoji }} {{ accion.label }}</button>
      </div>
      <div class="field">
        <label>Temperatura (°C) <span style="font-weight:400;text-transform:none">opcional</span></label>
        <input v-model.number="regForm.temperatura" type="number" step="0.1" placeholder="22.0" />
      </div>
      <div class="field">
        <label>Humedad (%) <span style="font-weight:400;text-transform:none">opcional</span></label>
        <input v-model.number="regForm.humedad" type="number" step="1" placeholder="60" />
      </div>
      <div class="field">
        <label>Observaciones <span style="font-weight:400;text-transform:none">opcional</span></label>
        <textarea v-model.trim="regForm.notas" placeholder="Notas del registro…" />
      </div>
      <div v-if="regError" class="bs-error">{{ regError }}</div>
      <template #footer>
        <button class="btn btn-primary btn-full" :disabled="guardandoReg" @click="guardarRegistro">
          <span v-if="guardandoReg" class="spinner" />
          <span v-else>Guardar registro</span>
        </button>
      </template>
    </BottomSheet>

    <!-- BS: Más acciones -->
    <BottomSheet v-model="showAcciones" title="Acciones">
      <div class="accion-list">
        <button class="accion-item" @click="abrirNuevaPlanta">
          <span>➕</span><span>Nueva planta</span>
        </button>
        <button class="accion-item" @click="abrirAvanzarFase">
          <span>🔄</span><span>Avanzar fase</span>
        </button>
        <button class="accion-item" @click="abrirEditar">
          <span>✏️</span><span>Editar lote</span>
        </button>
        <button class="accion-item" @click="abrirFoto">
          <span>📷</span><span>Tomar foto</span>
        </button>
        <button class="accion-item accion-item--danger" @click="confirmarEliminar">
          <span>🗑️</span><span>Eliminar lote</span>
        </button>
      </div>
    </BottomSheet>

    <!-- BS: Avanzar fase -->
    <BottomSheet v-model="showAvanzar" title="Avanzar de fase">
      <div class="avanzar-current">
        Estado actual: <strong>{{ ESTADO_META[lote?.estado]?.emoji }} {{ lote?.estado }}</strong>
      </div>
      <div class="field" style="margin-top:1rem">
        <label>Sala destino <span style="font-weight:400;text-transform:none">opcional</span></label>
        <select v-model="avanzarForm.sala_destino_id">
          <option value="">Sin cambio de sala</option>
          <option v-for="s in salasDisponibles" :key="s.id" :value="s.id">{{ s.nombre }}</option>
        </select>
      </div>
      <div v-if="avanzarError" class="bs-error">{{ avanzarError }}</div>
      <template #footer>
        <button class="btn btn-primary btn-full" :disabled="avanzando" @click="guardarAvanzar">
          <span v-if="avanzando" class="spinner" />
          <span v-else>🔄 Avanzar fase</span>
        </button>
      </template>
    </BottomSheet>

    <!-- BS: Editar lote -->
    <BottomSheet v-model="showEditar" title="Editar lote">
      <div class="field">
        <label>Código</label>
        <input v-model.trim="editForm.codigo" type="text" />
      </div>
      <div class="field">
        <label>Descripción <span style="font-weight:400;text-transform:none">opcional</span></label>
        <textarea v-model.trim="editForm.descripcion" />
      </div>
      <div v-if="editError" class="bs-error">{{ editError }}</div>
      <template #footer>
        <button class="btn btn-primary btn-full" :disabled="guardandoEdit" @click="guardarEdicion">
          <span v-if="guardandoEdit" class="spinner" />
          <span v-else>Guardar</span>
        </button>
      </template>
    </BottomSheet>

    <!-- BS: Nueva planta -->
    <BottomSheet v-model="showNuevaPlanta" title="Nueva planta">
      <div class="field">
        <label>Nombre <span style="font-weight:400;text-transform:none">opcional</span></label>
        <input v-model.trim="plantaForm.nombre" type="text" placeholder="ej: G1" />
      </div>
      <div class="field">
        <label>Origen</label>
        <select v-model="plantaForm.origen">
          <option value="semilla">Semilla</option>
          <option value="esqueje">Esqueje</option>
          <option value="clonacion">Clonación</option>
        </select>
      </div>
      <div v-if="plantaError" class="bs-error">{{ plantaError }}</div>
      <template #footer>
        <button class="btn btn-primary btn-full" :disabled="guardandoPlanta" @click="guardarNuevaPlanta">
          <span v-if="guardandoPlanta" class="spinner" />
          <span v-else>Crear planta</span>
        </button>
      </template>
    </BottomSheet>

    <!-- BS: Confirmar eliminar -->
    <BottomSheet v-model="showEliminar" title="Eliminar lote">
      <p style="font-size:.9rem;color:var(--text);margin-bottom:1rem">
        ¿Seguro que querés eliminar el lote <strong>{{ lote?.codigo }}</strong>? Esta acción no se puede deshacer.
      </p>
      <template #footer>
        <button class="btn btn-danger btn-full" :disabled="eliminando" @click="eliminarLote">
          <span v-if="eliminando" class="spinner spinner--dark" />
          <span v-else>🗑️ Eliminar</span>
        </button>
        <button class="btn btn-ghost btn-full" @click="showEliminar = false">Cancelar</button>
      </template>
    </BottomSheet>

    <input ref="fotoInput" type="file" accept="image/*" capture="environment" style="display:none" @change="subirFoto" />
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { getLote, createRegistro, updateLote, deleteLote, avanzarFase, createPlanta, uploadFotoLote } from '@/lib/api'
import BottomSheet from '@/components/BottomSheet.vue'

const route  = useRoute()
const router = useRouter()
const lote   = ref(null)
const plantas = ref([])
const loading  = ref(true)
const fotoInput = ref(null)

const showRegistro   = ref(false)
const showAcciones   = ref(false)
const showAvanzar    = ref(false)
const showEditar     = ref(false)
const showNuevaPlanta= ref(false)
const showEliminar   = ref(false)

const guardandoReg   = ref(false)
const avanzando      = ref(false)
const guardandoEdit  = ref(false)
const guardandoPlanta= ref(false)
const eliminando     = ref(false)

const regError    = ref('')
const avanzarError= ref('')
const editError   = ref('')
const plantaError = ref('')

const ACCIONES = [
  { id: 'riego',           emoji: '💧', label: 'Riego' },
  { id: 'nutricion',       emoji: '🧪', label: 'Nutrición' },
  { id: 'poda',            emoji: '✂️',  label: 'Poda' },
  { id: 'defoliacion',     emoji: '🍃', label: 'Defoliación' },
  { id: 'scrog_lst',       emoji: '🪢', label: 'SCROG/LST' },
  { id: 'revision_plagas', emoji: '🔍', label: 'Plagas' },
  { id: 'limpieza_sala',   emoji: '🧹', label: 'Limpieza' },
  { id: 'ajuste_luz',      emoji: '💡', label: 'Luz' },
]

const ESTADO_META = {
  germinacion:{ emoji:'🌱' }, esqueje:{ emoji:'🪴' },
  vegetativo: { emoji:'🍃' }, floracion: { emoji:'🌸' },
  cosechado:  { emoji:'✂️'  }, secado:   { emoji:'🌬️' },
  descartada: { emoji:'🗑️' },
}

const ESTADO_STYLE = {
  vegetativo: { background: '#dcfce7', color: '#16a34a' },
  floracion:  { background: '#fef3c7', color: '#d97706' },
  cosechado:  { background: '#fff7ed', color: '#ea580c' },
  secado:     { background: '#ede9fe', color: '#7c3aed' },
  finalizado: { background: '#f1f5f9', color: '#64748b' },
}
const SALUD_COLOR = { excelente:'#16a34a', bueno:'#65a30d', regular:'#d97706', malo:'#dc2626', critico:'#991b1b' }

function estadoStyle(e)  { return ESTADO_STYLE[e] || { background: '#f1f5f9', color: '#64748b' } }
function estadoEmoji(s)  { return ESTADO_META[s]?.emoji || '🌿' }
function saludColor(s)   { return SALUD_COLOR[s] || '#94a3b8' }

const diasEnCiclo = computed(() => {
  if (!lote.value?.created_at) return 0
  return Math.floor((Date.now() - new Date(lote.value.created_at)) / 86400000)
})

const salasDisponibles = ref([])

const regForm    = ref({ tareas: [], temperatura: null, humedad: null, notas: '' })
const avanzarForm= ref({ sala_destino_id: '' })
const editForm   = ref({ codigo: '', descripcion: '' })
const plantaForm = ref({ nombre: '', origen: 'semilla' })

function toggleTarea(id) {
  const idx = regForm.value.tareas.indexOf(id)
  if (idx === -1) regForm.value.tareas.push(id)
  else regForm.value.tareas.splice(idx, 1)
}

async function guardarRegistro() {
  guardandoReg.value = true; regError.value = ''
  const f = regForm.value
  const payload = { tareas_realizadas: f.tareas }
  if (f.temperatura) payload.temperatura = f.temperatura
  if (f.humedad)     payload.humedad     = f.humedad
  if (f.notas)       payload.notas       = f.notas
  try {
    await createRegistro(lote.value.id, payload)
    showRegistro.value = false
    regForm.value = { tareas: [], temperatura: null, humedad: null, notas: '' }
  } catch (e) { regError.value = e?.response?.data?.error || 'Error al guardar' }
  finally { guardandoReg.value = false }
}

function abrirAvanzar() {
  avanzarForm.value = { sala_destino_id: '' }
  avanzarError.value = ''
  showAcciones.value = false
  // Cargar salas de la sede del lote
  salasDisponibles.value = lote.value?.sala?.sede?.salas || []
  showAvanzar.value = true
}
function abrirAvanzarFase() { abrirAvanzar() }

async function guardarAvanzar() {
  avanzando.value = true; avanzarError.value = ''
  try {
    const payload = {}
    if (avanzarForm.value.sala_destino_id) payload.sala_id = avanzarForm.value.sala_destino_id
    const { data } = await avanzarFase(lote.value.id, payload)
    lote.value = { ...lote.value, ...data }
    showAvanzar.value = false
  } catch (e) { avanzarError.value = e?.response?.data?.error || 'Error al avanzar fase' }
  finally { avanzando.value = false }
}

function abrirEditar() {
  editForm.value = { codigo: lote.value?.codigo || '', descripcion: lote.value?.descripcion || '' }
  editError.value = ''
  showAcciones.value = false
  showEditar.value = true
}
async function guardarEdicion() {
  guardandoEdit.value = true; editError.value = ''
  try {
    const { data } = await updateLote(lote.value.id, editForm.value)
    lote.value = { ...lote.value, ...data }
    showEditar.value = false
  } catch (e) { editError.value = e?.response?.data?.error || 'Error al guardar' }
  finally { guardandoEdit.value = false }
}

function abrirNuevaPlanta() {
  plantaForm.value = { nombre: '', origen: 'semilla' }
  plantaError.value = ''
  showAcciones.value = false
  showNuevaPlanta.value = true
}
async function guardarNuevaPlanta() {
  guardandoPlanta.value = true; plantaError.value = ''
  try {
    const { data } = await createPlanta(lote.value.id, plantaForm.value)
    plantas.value.unshift(data)
    showNuevaPlanta.value = false
  } catch (e) { plantaError.value = e?.response?.data?.error || 'Error al crear planta' }
  finally { guardandoPlanta.value = false }
}

function confirmarEliminar() { showAcciones.value = false; showEliminar.value = true }
async function eliminarLote() {
  eliminando.value = true
  try {
    await deleteLote(lote.value.id)
    router.back()
  } catch { eliminando.value = false }
}

function abrirFoto() { showAcciones.value = false; fotoInput.value?.click() }
async function subirFoto(e) {
  const file = e.target.files?.[0]
  if (!file) return
  const fd = new FormData()
  fd.append('foto', file)
  try { await uploadFotoLote(lote.value.id, fd) } catch {}
  e.target.value = ''
}

onMounted(async () => {
  try {
    const { data } = await getLote(route.params.id)
    lote.value   = data
    plantas.value = data.plants || data.plantas || []
  } catch { plantas.value = [] }
  loading.value = false
})
</script>

<style scoped>
.lote-meta__row {
  display: flex; justify-content: space-between; align-items: center;
  font-size: .85rem; padding: .3rem 0; border-bottom: 1px solid var(--border);
}
.lote-meta__row:last-child { border-bottom: none; }
.lote-meta__row span  { color: var(--text-2); }
.lote-meta__row strong{ color: var(--text); font-weight: 600; }

.plantas-grid {
  display: grid; grid-template-columns: repeat(3, 1fr); gap: .5rem;
}
.planta-chip {
  display: flex; flex-direction: column; align-items: center; gap: .2rem;
  background: var(--surface); border: 1.5px solid var(--border);
  border-radius: 12px; padding: .75rem .5rem;
  transition: all .1s;
}
.planta-chip:active { transform: scale(.95); }
.planta-chip--warn  { border-color: #fca5a5; background: #fef2f2; }
.planta-chip__emoji { font-size: 1.3rem; }
.planta-chip__nombre{ font-size: .65rem; font-weight: 600; color: var(--text); text-align: center; }
.planta-chip__salud { font-size: .7rem; line-height: 1; }

.action-bar {
  display: flex; gap: .5rem;
  padding: .75rem 1rem;
  padding-bottom: calc(.75rem + env(safe-area-inset-bottom, 0px));
  background: var(--surface); border-top: 1px solid var(--border);
  flex-shrink: 0;
}

.accion-list { display: flex; flex-direction: column; }
.accion-item {
  display: flex; align-items: center; gap: .75rem;
  padding: .9rem .5rem; font-size: .95rem; font-weight: 600;
  color: var(--text); width: 100%; text-align: left;
  border-bottom: 1px solid var(--border);
}
.accion-item:last-child { border-bottom: none; }
.accion-item:active { background: var(--bg); }
.accion-item--danger { color: var(--red); }

.avanzar-current { font-size: .875rem; color: var(--text-2); background: var(--bg); padding: .75rem; border-radius: 10px; }

.bs-error {
  background: var(--red-bg); border: 1px solid #fecaca;
  color: var(--red); padding: .6rem .875rem; border-radius: 10px;
  font-size: .82rem; margin: .5rem 0;
}
</style>
