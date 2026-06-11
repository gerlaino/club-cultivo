<template>
  <div class="page">
    <div class="page-header">
      <button class="back-btn" @click="router.back()">‹</button>
      <h1>{{ sala?.nombre || 'Sala' }}</h1>
    </div>

    <div class="page-content">
      <div v-if="loading" class="empty-state"><div class="spinner spinner--dark" /></div>
      <template v-else>
        <!-- Lotes -->
        <p class="section-title">Lotes activos ({{ lotes.length }})</p>
        <div v-if="!lotes.length" class="empty-state">
          <div class="icon">📦</div>
          <p>Sin lotes en esta sala</p>
        </div>
        <button
          v-for="lote in lotes"
          :key="lote.id"
          class="lote-card"
          @click="router.push({ name: 'lote-detail', params: { id: lote.id } })"
        >
          <div class="lote-card__body">
            <div class="lote-card__codigo">{{ lote.codigo }}</div>
            <div class="lote-card__meta">
              <span>{{ lote.cepa?.nombre || '—' }}</span>
              <span v-if="lote.plants_count"> · {{ lote.plants_count }} plantas</span>
            </div>
          </div>
          <div class="lote-card__right">
            <span class="pill" :style="estadoStyle(lote.estado)">{{ lote.estado }}</span>
            <span class="lote-card__arrow">›</span>
          </div>
        </button>
      </template>
    </div>

    <!-- Action bar -->
    <div v-if="!loading" class="action-bar">
      <button class="btn btn-secondary" style="flex:1" @click="showRegistro = true">
        📋 Registrar sala
      </button>
      <button class="btn btn-ghost" style="flex:1" @click="showAcciones = true">
        ⚡ Más
      </button>
    </div>

    <!-- BS: Registrar sala (ambiental) -->
    <BottomSheet v-model="showRegistro" title="Registrar sala" :tall="true">
      <div class="field">
        <label>Temperatura (°C)</label>
        <input v-model.number="regForm.temperatura" type="number" step="0.1" placeholder="22.0" />
      </div>
      <div class="field">
        <label>Humedad (%)</label>
        <input v-model.number="regForm.humedad" type="number" step="1" placeholder="60" />
      </div>
      <div class="field">
        <label>CO₂ (ppm) <span style="font-weight:400;text-transform:none">opcional</span></label>
        <input v-model.number="regForm.co2" type="number" step="10" placeholder="800" />
      </div>
      <div class="field">
        <label>pH <span style="font-weight:400;text-transform:none">opcional</span></label>
        <input v-model.number="regForm.ph" type="number" step="0.1" placeholder="6.2" />
      </div>
      <div class="field">
        <label>Notas <span style="font-weight:400;text-transform:none">opcional</span></label>
        <textarea v-model.trim="regForm.notas" placeholder="Observaciones…" />
      </div>
      <div v-if="regError" class="bs-error">{{ regError }}</div>
      <template #footer>
        <button class="btn btn-primary btn-full" :disabled="guardandoReg" @click="guardarRegistro">
          <span v-if="guardandoReg" class="spinner" />
          <span v-else>Guardar</span>
        </button>
      </template>
    </BottomSheet>

    <!-- BS: Más acciones -->
    <BottomSheet v-model="showAcciones" title="Acciones">
      <div class="accion-list">
        <button class="accion-item" @click="abrirNuevoLote">
          <span>➕</span><span>Nuevo lote</span>
        </button>
        <button class="accion-item" @click="abrirFoto">
          <span>📷</span><span>Tomar foto del sala</span>
        </button>
      </div>
    </BottomSheet>

    <!-- BS: Nuevo lote -->
    <BottomSheet v-model="showNuevoLote" title="Nuevo lote" :tall="true">
      <div class="field">
        <label>Código del lote *</label>
        <input v-model.trim="loteForm.codigo" type="text" placeholder="ej: GSC-05" />
      </div>
      <div class="field">
        <label>Descripción <span style="font-weight:400;text-transform:none">opcional</span></label>
        <textarea v-model.trim="loteForm.descripcion" placeholder="Notas sobre el lote…" />
      </div>
      <div v-if="loteError" class="bs-error">{{ loteError }}</div>
      <template #footer>
        <button class="btn btn-primary btn-full" :disabled="guardandoLote || !loteForm.codigo" @click="guardarNuevoLote">
          <span v-if="guardandoLote" class="spinner" />
          <span v-else>Crear lote</span>
        </button>
      </template>
    </BottomSheet>

    <!-- Input foto oculto -->
    <input ref="fotoInput" type="file" accept="image/*" capture="environment" style="display:none" @change="subirFoto" />
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { getSala, createRegistro, createLote } from '@/lib/api'
import BottomSheet from '@/components/BottomSheet.vue'

const route  = useRoute()
const router = useRouter()
const sala   = ref(null)
const lotes  = ref([])
const loading = ref(true)

const showRegistro   = ref(false)
const showAcciones   = ref(false)
const showNuevoLote  = ref(false)
const guardandoReg   = ref(false)
const guardandoLote  = ref(false)
const regError       = ref('')
const loteError      = ref('')
const fotoInput      = ref(null)

const regForm  = ref({ temperatura: null, humedad: null, co2: null, ph: null, notas: '' })
const loteForm = ref({ codigo: '', descripcion: '' })

const ESTADO_STYLE = {
  vegetativo: { background: '#dcfce7', color: '#16a34a' },
  floracion:  { background: '#fef3c7', color: '#d97706' },
  cosechado:  { background: '#fff7ed', color: '#ea580c' },
  secado:     { background: '#ede9fe', color: '#7c3aed' },
  finalizado: { background: '#f1f5f9', color: '#64748b' },
}
function estadoStyle(e) { return ESTADO_STYLE[e] || { background: '#f1f5f9', color: '#64748b' } }

async function guardarRegistro() {
  guardandoReg.value = true; regError.value = ''
  const f = regForm.value
  const payload = {}
  if (f.temperatura) payload.temperatura = f.temperatura
  if (f.humedad)     payload.humedad     = f.humedad
  if (f.co2)         payload.co2         = f.co2
  if (f.ph)          payload.ph          = f.ph
  if (f.notas)       payload.notas       = f.notas

  // Registrar en todos los lotes activos de la sala
  try {
    for (const lote of lotes.value.filter(l => l.estado !== 'finalizado')) {
      await createRegistro(lote.id, payload)
    }
    showRegistro.value = false
    regForm.value = { temperatura: null, humedad: null, co2: null, ph: null, notas: '' }
  } catch (e) {
    regError.value = e?.response?.data?.error || 'Error al guardar'
  } finally { guardandoReg.value = false }
}

function abrirNuevoLote() {
  loteForm.value = { codigo: '', descripcion: '' }
  loteError.value = ''
  showAcciones.value = false
  showNuevoLote.value = true
}

async function guardarNuevoLote() {
  guardandoLote.value = true; loteError.value = ''
  try {
    const { data } = await createLote(sala.value.id, loteForm.value)
    lotes.value.unshift(data)
    showNuevoLote.value = false
  } catch (e) {
    loteError.value = e?.response?.data?.error || 'Error al crear lote'
  } finally { guardandoLote.value = false }
}

function abrirFoto() { showAcciones.value = false; fotoInput.value?.click() }

async function subirFoto(e) {
  const file = e.target.files?.[0]
  if (!file) return
  // Subir foto a todos los lotes de la sala o solo al primero activo
  // Por ahora solo notificamos — se puede extender
  e.target.value = ''
}

onMounted(async () => {
  try {
    const { data } = await getSala(route.params.id)
    sala.value  = data
    lotes.value = (data.lotes || []).filter(l => l.estado !== 'finalizado')
  } catch { lotes.value = [] }
  loading.value = false
})
</script>

<style scoped>
.lote-card {
  display: flex; align-items: center; justify-content: space-between;
  background: var(--surface); border: 1px solid var(--border);
  border-radius: var(--r-card); padding: .9rem 1rem;
  width: 100%; text-align: left; margin-bottom: .75rem;
  box-shadow: var(--shadow); transition: all .1s;
}
.lote-card:active { transform: scale(.98); }
.lote-card__body  { flex: 1; }
.lote-card__codigo{ font-size: .95rem; font-weight: 700; color: var(--text); }
.lote-card__meta  { font-size: .75rem; color: var(--text-2); margin-top: .2rem; }
.lote-card__right { display: flex; align-items: center; gap: .5rem; }
.lote-card__arrow { font-size: 1.4rem; color: var(--green-border); }

.action-bar {
  display: flex; gap: .5rem;
  padding: .75rem 1rem;
  padding-bottom: calc(.75rem + env(safe-area-inset-bottom, 0px));
  background: var(--surface); border-top: 1px solid var(--border);
  flex-shrink: 0;
}

.accion-list { display: flex; flex-direction: column; gap: .25rem; }
.accion-item {
  display: flex; align-items: center; gap: .75rem;
  padding: .9rem .5rem; font-size: .95rem; font-weight: 600;
  color: var(--text); border-radius: 10px; width: 100%;
  text-align: left; border-bottom: 1px solid var(--border);
}
.accion-item:last-child { border-bottom: none; }
.accion-item:active { background: var(--bg); }

.bs-error {
  background: var(--red-bg); border: 1px solid #fecaca;
  color: var(--red); padding: .6rem .875rem; border-radius: 10px;
  font-size: .82rem; margin-bottom: .5rem;
}
</style>
