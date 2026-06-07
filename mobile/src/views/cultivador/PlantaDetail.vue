<template>
  <div class="page">
    <div class="page-header">
      <button class="back-btn" @click="router.back()">‹</button>
      <h1>{{ planta?.nombre || `Planta #${route.params.id}` }}</h1>
      <span v-if="planta" class="pill" :style="estadoStyle(planta.state)">
        {{ ESTADO_META[planta.state]?.emoji }} {{ planta.state }}
      </span>
    </div>

    <div class="page-content">
      <div v-if="loading" class="empty-state"><div class="spinner spinner--dark" /></div>
      <template v-else>

        <!-- Ciclo strip -->
        <div class="ciclo-strip">
          <div
            v-for="(etapa, i) in cicloFases"
            :key="etapa"
            class="ciclo-step"
            :class="{
              'ciclo-step--done':    i < cicloIndex,
              'ciclo-step--current': i === cicloIndex,
              'ciclo-step--pending': i > cicloIndex,
            }"
          >
            <div class="ciclo-dot">{{ ESTADO_META[etapa]?.emoji }}</div>
            <div class="ciclo-label">{{ ESTADO_META[etapa]?.label }}</div>
            <div v-if="i < cicloFases.length - 1" class="ciclo-line" :class="{ 'ciclo-line--done': i < cicloIndex }" />
          </div>
        </div>

        <!-- Último estado -->
        <div v-if="ultimoRegistro" class="card" style="margin-bottom:.75rem">
          <div class="lote-meta__row">
            <span>Salud</span>
            <strong :style="{ color: SALUD_META[ultimoRegistro.metadata?.estado_salud]?.color }">
              {{ SALUD_META[ultimoRegistro.metadata?.estado_salud]?.emoji }}
              {{ SALUD_META[ultimoRegistro.metadata?.estado_salud]?.label || '—' }}
            </strong>
          </div>
          <div class="lote-meta__row">
            <span>Hojas</span>
            <strong>{{ HOJAS_META[ultimoRegistro.metadata?.color_hojas]?.label || '—' }}</strong>
          </div>
          <div class="lote-meta__row">
            <span>Plagas</span>
            <strong :style="{ color: PLAGAS_META[ultimoRegistro.metadata?.plagas]?.color }">
              {{ PLAGAS_META[ultimoRegistro.metadata?.plagas]?.label || '—' }}
            </strong>
          </div>
          <div v-if="ultimoRegistro.metadata?.altura_cm" class="lote-meta__row">
            <span>Altura</span><strong>{{ ultimoRegistro.metadata.altura_cm }} cm</strong>
          </div>
          <p class="registro-fecha">Actualizado {{ formatDT(ultimoRegistro.occurred_at) }}</p>
        </div>

        <!-- Meta técnica -->
        <div class="card">
          <div class="lote-meta__row"><span>Genética</span><strong>{{ planta.genetica?.nombre || '—' }}</strong></div>
          <div class="lote-meta__row"><span>Origen</span><strong>{{ planta.origen || '—' }}</strong></div>
          <div class="lote-meta__row"><span>Maceta</span><strong>{{ macetaActual ? macetaActual + 'L' : '—' }}</strong></div>
          <div class="lote-meta__row"><span>Día</span><strong>{{ diasEnCiclo }}</strong></div>
        </div>
      </template>
    </div>

    <!-- Action bar -->
    <div v-if="!loading" class="action-bar">
      <button class="btn btn-secondary" style="flex:1" @click="showRegistro = true">
        📋 Registrar
      </button>
      <button class="btn btn-ghost" style="flex:1" @click="showAcciones = true">
        ⚡ Más
      </button>
    </div>

    <!-- BS: Registrar planta -->
    <BottomSheet v-model="showRegistro" title="Registrar planta" :tall="true">
      <div class="section-label">Estado de salud</div>
      <div class="chip-group" style="margin-bottom:1rem">
        <button
          v-for="(m, k) in SALUD_META" :key="k"
          class="chip" :class="{ 'chip--active': regForm.estado_salud === k }"
          :style="regForm.estado_salud === k ? { borderColor: m.color, color: m.color, background: m.color+'18' } : {}"
          @click="regForm.estado_salud = k"
        >{{ m.emoji }} {{ m.label }}</button>
      </div>

      <div class="section-label">Plagas</div>
      <div class="chip-group" style="margin-bottom:1rem">
        <button
          v-for="(m, k) in PLAGAS_META" :key="k"
          class="chip" :class="{ 'chip--active': regForm.plagas === k }"
          :style="regForm.plagas === k ? { borderColor: m.color, color: m.color, background: m.color+'18' } : {}"
          @click="regForm.plagas = k"
        >{{ m.label }}</button>
      </div>

      <div class="section-label">Color de hojas</div>
      <div class="chip-group" style="margin-bottom:1rem">
        <button
          v-for="(m, k) in HOJAS_META" :key="k"
          class="chip" :class="{ 'chip--active': regForm.color_hojas === k }"
          @click="regForm.color_hojas = k"
        >{{ m.emoji }} {{ m.label }}</button>
      </div>

      <div class="row2">
        <div class="field">
          <label>Altura (cm)</label>
          <input v-model.number="regForm.altura_cm" type="number" step="0.5" placeholder="45" />
        </div>
        <div class="field">
          <label>Copas</label>
          <input v-model.number="regForm.num_colas" type="number" step="1" placeholder="4" />
        </div>
      </div>

      <div class="field">
        <label>Notas <span style="font-weight:400;text-transform:none">opcional</span></label>
        <textarea v-model.trim="regForm.notas" placeholder="Observaciones…" />
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
          <span>➕</span><span>Nueva planta hermana</span>
        </button>
        <button class="accion-item" @click="abrirEditar">
          <span>✏️</span><span>Editar planta</span>
        </button>
        <button class="accion-item" @click="abrirFoto">
          <span>📷</span><span>Tomar foto</span>
        </button>
        <button class="accion-item accion-item--danger" @click="confirmarEliminar">
          <span>🗑️</span><span>Eliminar planta</span>
        </button>
      </div>
    </BottomSheet>

    <!-- BS: Editar planta -->
    <BottomSheet v-model="showEditar" title="Editar planta">
      <div class="field">
        <label>Nombre</label>
        <input v-model.trim="editForm.nombre" type="text" placeholder="ej: G1" />
      </div>
      <div class="section-label" style="margin-top:.5rem">Estado</div>
      <div class="chip-group">
        <button
          v-for="(m, k) in ESTADO_META" :key="k"
          class="chip" :class="{ 'chip--active': editForm.state === k }"
          :style="editForm.state === k ? { borderColor: m.color, background: m.bg, color: m.color } : {}"
          @click="editForm.state = k"
        >{{ m.emoji }} {{ m.label }}</button>
      </div>
      <template #footer>
        <button class="btn btn-primary btn-full" :disabled="guardandoEdit" @click="guardarEdicion">
          <span v-if="guardandoEdit" class="spinner" />
          <span v-else>Guardar</span>
        </button>
      </template>
    </BottomSheet>

    <!-- BS: Nueva planta hermana -->
    <BottomSheet v-model="showNuevaPlanta" title="Nueva planta">
      <div class="field">
        <label>Nombre <span style="font-weight:400;text-transform:none">opcional</span></label>
        <input v-model.trim="plantaForm.nombre" type="text" placeholder="ej: G2" />
      </div>
      <div class="field">
        <label>Origen</label>
        <select v-model="plantaForm.origen">
          <option value="semilla">Semilla</option>
          <option value="esqueje">Esqueje</option>
          <option value="clonacion">Clonación</option>
        </select>
      </div>
      <template #footer>
        <button class="btn btn-primary btn-full" :disabled="guardandoPlanta" @click="guardarNuevaPlanta">
          <span v-if="guardandoPlanta" class="spinner" />
          <span v-else>Crear planta</span>
        </button>
      </template>
    </BottomSheet>

    <!-- BS: Confirmar eliminar -->
    <BottomSheet v-model="showEliminar" title="Eliminar planta">
      <p style="font-size:.9rem;color:var(--text)">
        ¿Seguro que querés eliminar <strong>{{ planta?.nombre || `planta #${planta?.id}` }}</strong>?
        Esta acción no se puede deshacer.
      </p>
      <template #footer>
        <button class="btn btn-danger btn-full" :disabled="eliminando" @click="eliminarPlanta">
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
import { getPlanta, createPlantActivity, updatePlanta, deletePlanta, createPlanta, uploadFotoPlanta } from '@/lib/api'
import BottomSheet from '@/components/BottomSheet.vue'

const route  = useRoute()
const router = useRouter()
const planta = ref(null)
const actividades = ref([])
const loading = ref(true)
const fotoInput = ref(null)

const showRegistro    = ref(false)
const showAcciones    = ref(false)
const showEditar      = ref(false)
const showNuevaPlanta = ref(false)
const showEliminar    = ref(false)

const guardandoReg   = ref(false)
const guardandoEdit  = ref(false)
const guardandoPlanta= ref(false)
const eliminando     = ref(false)
const regError       = ref('')

const ESTADO_META = {
  germinacion:{ label:'Germinación', emoji:'🌱', color:'#64748b', bg:'#f1f5f9' },
  esqueje:    { label:'Esqueje',     emoji:'🪴', color:'#0891b2', bg:'#e0f2fe' },
  vegetativo: { label:'Vegetativo',  emoji:'🍃', color:'#16a34a', bg:'#dcfce7' },
  floracion:  { label:'Floración',   emoji:'🌸', color:'#d97706', bg:'#fef3c7' },
  cosechado:  { label:'Cosechada',   emoji:'✂️',  color:'#92400e', bg:'#fff7ed' },
  secado:     { label:'Secado',      emoji:'🌬️', color:'#7c3aed', bg:'#ede9fe' },
  descartada: { label:'Descartada',  emoji:'🗑️', color:'#dc2626', bg:'#fef2f2' },
}
const SALUD_META = {
  excelente:{ color:'#16a34a', emoji:'🟢', label:'Excelente' },
  bueno:    { color:'#65a30d', emoji:'🟡', label:'Bueno'     },
  regular:  { color:'#d97706', emoji:'🟠', label:'Regular'   },
  malo:     { color:'#dc2626', emoji:'🔴', label:'Malo'      },
  critico:  { color:'#991b1b', emoji:'🚨', label:'Crítico'   },
}
const HOJAS_META = {
  verde_oscuro:{ emoji:'🟢', label:'Verde oscuro' },
  verde_claro: { emoji:'🟩', label:'Verde claro'  },
  amarillo:    { emoji:'🟡', label:'Amarillo'     },
  marron:      { emoji:'🟤', label:'Marrón'       },
}
const PLAGAS_META = {
  ninguna: { color:'#16a34a', label:'Ninguna'  },
  leve:    { color:'#d97706', label:'Leve'     },
  moderada:{ color:'#ea580c', label:'Moderada' },
  severa:  { color:'#dc2626', label:'Severa'   },
}
const ESTADO_ESTILO = {
  vegetativo: { background: '#dcfce7', color: '#16a34a' },
  floracion:  { background: '#fef3c7', color: '#d97706' },
  cosechado:  { background: '#fff7ed', color: '#ea580c' },
  descartada: { background: '#fef2f2', color: '#dc2626' },
}
function estadoStyle(e) { return ESTADO_ESTILO[e] || { background: '#f1f5f9', color: '#64748b' } }

const cicloFases = computed(() => {
  const origen = planta.value?.origen
  return origen === 'esqueje'
    ? ['esqueje', 'vegetativo', 'floracion', 'cosechado']
    : ['germinacion', 'vegetativo', 'floracion', 'cosechado']
})
const cicloIndex = computed(() => cicloFases.value.indexOf(planta.value?.state))
const diasEnCiclo = computed(() => {
  if (!planta.value?.created_at) return 0
  return Math.floor((Date.now() - new Date(planta.value.created_at)) / 86400000)
})
const ultimoRegistro = computed(() =>
  actividades.value.find(a => a.activity_type === 'registro_planta') || null
)
const macetaActual = computed(() => {
  const t = actividades.value.find(a => a.activity_type === 'transplant')
  return t?.metadata?.maceta_destino_l || planta.value?.lote?.tamanio_maceta || null
})

function formatDT(s) {
  if (!s) return '—'
  return new Date(s).toLocaleString('es-AR', { day:'numeric', month:'short', hour:'2-digit', minute:'2-digit' })
}

// Forms
const regForm  = ref({ estado_salud:'bueno', plagas:'ninguna', color_hojas:'verde_oscuro', altura_cm: null, num_colas: null, notas:'' })
const editForm = ref({ nombre:'', state:'' })
const plantaForm = ref({ nombre:'', origen:'semilla' })

async function guardarRegistro() {
  guardandoReg.value = true; regError.value = ''
  const f = regForm.value
  try {
    const { data } = await createPlantActivity(planta.value.id, {
      activity_type: 'registro_planta',
      description:   f.notas || undefined,
      metadata: {
        estado_salud: f.estado_salud,
        plagas:       f.plagas,
        color_hojas:  f.color_hojas,
        altura_cm:    f.altura_cm || undefined,
        num_colas:    f.num_colas || undefined,
      },
    })
    actividades.value.unshift(data)
    if (planta.value) planta.value.estado_salud = f.estado_salud
    showRegistro.value = false
  } catch (e) { regError.value = e?.response?.data?.error || 'Error al guardar' }
  finally { guardandoReg.value = false }
}

function abrirEditar() {
  editForm.value = { nombre: planta.value?.nombre || '', state: planta.value?.state || '' }
  showAcciones.value = false; showEditar.value = true
}
async function guardarEdicion() {
  guardandoEdit.value = true
  try {
    const { data } = await updatePlanta(planta.value.id, editForm.value)
    planta.value = { ...planta.value, ...data }
    showEditar.value = false
  } catch {} finally { guardandoEdit.value = false }
}

function abrirNuevaPlanta() {
  plantaForm.value = { nombre:'', origen:'semilla' }
  showAcciones.value = false; showNuevaPlanta.value = true
}
async function guardarNuevaPlanta() {
  guardandoPlanta.value = true
  try {
    await createPlanta(planta.value.lote?.id, plantaForm.value)
    showNuevaPlanta.value = false
  } catch {} finally { guardandoPlanta.value = false }
}

function confirmarEliminar() { showAcciones.value = false; showEliminar.value = true }
async function eliminarPlanta() {
  eliminando.value = true
  try { await deletePlanta(planta.value.id); router.back() }
  catch { eliminando.value = false }
}

function abrirFoto() { showAcciones.value = false; fotoInput.value?.click() }
async function subirFoto(e) {
  const file = e.target.files?.[0]; if (!file) return
  const fd = new FormData(); fd.append('foto', file)
  try { await uploadFotoPlanta(planta.value.id, fd) } catch {}
  e.target.value = ''
}

onMounted(async () => {
  try {
    const { data } = await getPlanta(route.params.id)
    planta.value    = data
    actividades.value = data.activities || []
  } catch {}
  loading.value = false
})
</script>

<style scoped>
.ciclo-strip {
  display: flex; align-items: flex-start;
  background: var(--surface); border: 1px solid var(--border);
  border-radius: var(--r-card); padding: .875rem 1rem;
  margin-bottom: .75rem; overflow-x: auto;
}
.ciclo-step {
  display: flex; flex-direction: column; align-items: center;
  flex: 1; position: relative; min-width: 56px;
}
.ciclo-dot {
  width: 32px; height: 32px; border-radius: 50%;
  background: #f1f5f9; border: 2px solid var(--border);
  display: flex; align-items: center; justify-content: center;
  font-size: .8rem; position: relative; z-index: 1; margin-bottom: .3rem;
}
.ciclo-label {
  font-size: .52rem; font-weight: 600; color: var(--text-3);
  text-transform: uppercase; letter-spacing: .04em; text-align: center;
}
.ciclo-step--done .ciclo-dot   { background: #dcfce7; border-color: #16a34a; }
.ciclo-step--done .ciclo-label { color: #16a34a; }
.ciclo-step--current .ciclo-dot{ background: var(--green); border-color: var(--green); box-shadow: 0 0 0 3px rgba(27,94,32,.2); }
.ciclo-step--current .ciclo-label{ color: var(--green); font-weight: 800; }
.ciclo-step--pending { opacity: .4; }
.ciclo-line {
  position: absolute; top: 15px; left: 50%; width: 100%; height: 2px;
  background: var(--border);
}
.ciclo-line--done { background: #16a34a; }

.lote-meta__row {
  display: flex; justify-content: space-between; align-items: center;
  font-size: .85rem; padding: .3rem 0; border-bottom: 1px solid var(--border);
}
.lote-meta__row:last-child { border-bottom: none; }
.lote-meta__row span   { color: var(--text-2); }
.lote-meta__row strong { color: var(--text); font-weight: 600; }
.registro-fecha { font-size: .7rem; color: var(--text-3); margin-top: .4rem; text-align: right; }

.action-bar {
  display: flex; gap: .5rem;
  padding: .75rem 1rem;
  padding-bottom: calc(.75rem + env(safe-area-inset-bottom, 0px));
  background: var(--surface); border-top: 1px solid var(--border);
  flex-shrink: 0;
}

.section-label {
  font-size: .7rem; font-weight: 700; color: var(--text-2);
  text-transform: uppercase; letter-spacing: .06em; margin-bottom: .5rem;
}
.row2 { display: grid; grid-template-columns: 1fr 1fr; gap: .75rem; }

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

.bs-error {
  background: var(--red-bg); border: 1px solid #fecaca;
  color: var(--red); padding: .6rem .875rem; border-radius: 10px;
  font-size: .82rem; margin: .5rem 0;
}
</style>
