<template>
  <div>
    <!-- Acciones: registrar actividad / ver historial completo -->
    <div class="lhs__top">
      <button v-if="canAdmin && !formAbierto" class="lhs__add-btn" @click="abrirForm">
        <i class="bi bi-plus-circle me-1"></i>Registrar actividad
      </button>
      <button v-if="historial.length" class="lhs__ver-btn" @click="$emit('ver')">
        <i class="bi bi-list-ul me-1"></i>Ver historial ({{ historial.length }})
      </button>
    </div>

    <!-- Form: registrar actividad (incluye trasplante) -->
    <div v-if="canAdmin && formAbierto" class="lhs__form">
      <div class="lhs__form-row">
        <select v-model="form.categoria" class="lhs__form-sel">
          <option v-for="t in CATEGORIAS" :key="t.value" :value="t.value">{{ t.emoji }} {{ t.label }}</option>
        </select>
        <AppDatePicker v-model="form.fecha" :max="hoy" class="lhs__form-date" />
      </div>

      <!-- Campos según categoría -->
      <div v-if="form.categoria === 'trasplante'" class="lhs__form-row">
        <input v-model.number="form.macetaOrigen" type="number" step="0.5" min="0" class="lhs__form-num" placeholder="Maceta origen (L)" />
        <span class="lhs__arrow">→</span>
        <input v-model.number="form.macetaDestino" type="number" step="0.5" min="0.1" class="lhs__form-num" placeholder="Maceta destino (L) *" />
      </div>
      <div v-else-if="form.categoria === 'fertilizacion'" class="lhs__form-row">
        <input v-model="form.producto" type="text" class="lhs__form-input" maxlength="120" placeholder="Producto / fórmula" />
        <input v-model.number="form.ec" type="number" step="0.1" min="0" class="lhs__form-num" placeholder="EC" />
      </div>
      <div v-else-if="form.categoria === 'riego'" class="lhs__form-row">
        <input v-model.number="form.volumen" type="number" step="0.1" min="0" class="lhs__form-num" placeholder="Volumen (L)" />
        <input v-model.number="form.ec" type="number" step="0.1" min="0" class="lhs__form-num" placeholder="EC" />
      </div>

      <input v-if="form.categoria !== 'trasplante'" v-model="form.descripcion" type="text"
             class="lhs__form-input" maxlength="200" :placeholder="placeholderDescripcion" @keyup.enter="guardar" />
      <div class="lhs__form-actions">
        <button class="lhs__form-cancel" @click="cerrarForm">Cancelar</button>
        <button class="lhs__form-save" :disabled="!formValido" @click="guardar">Registrar</button>
      </div>
    </div>

    <!-- Inline: vista corta de lectura -->
    <div v-if="loadingHistorial" class="lhs__placeholder">Cargando historial…</div>
    <EmptyState v-else-if="!historial.length" icon="📜" title="Sin eventos" message="Todavía no hay actividad registrada." compact />
    <div v-else class="lhs__lista">
      <div v-for="it in historialCorto" :key="it.source + it.id" class="lhs__row">
        <div class="lhs__dot" :style="{ background: dotColor(it) }"></div>
        <div class="lhs__row-body">
          <div class="lhs__row-head">
            <span class="lhs__row-titulo">{{ it.emoji }} {{ it.titulo }}<span v-if="metaDetalle(it)" class="lhs__row-detalle"> · {{ metaDetalle(it) }}</span></span>
            <span class="lhs__row-fecha">{{ formatDateTime(it.fecha) }}</span>
          </div>
          <div v-if="it.detalle" class="lhs__row-desc">{{ it.detalle }}</div>
          <div v-if="it.usuario" class="lhs__row-meta">{{ it.usuario }}</div>
        </div>
      </div>
      <button v-if="historial.length > CORTO" class="lhs__mas" @click="$emit('ver')">
        + {{ historial.length - CORTO }} más — ver historial completo
      </button>
    </div>
  </div>
</template>

<script setup>
import { ref, computed } from 'vue'
import { formatDateTime } from '../../lib/loteHelpers.js'
import EmptyState from '../ui/EmptyState.vue'
import AppDatePicker from '../ui/AppDatePicker.vue'
import { CATEGORIAS, dotColor, metaDetalle, placeholderFor } from '../../lib/historialHelpers.js'

const props = defineProps({
  historial:        { type: Array,   default: () => [] },
  loadingHistorial: { type: Boolean, default: false },
  canAdmin:         { type: Boolean, default: false },
})
const emit = defineEmits(['crear', 'trasplante', 'ver'])

const CORTO = 6
const historialCorto = computed(() => props.historial.slice(0, CORTO))

const hoy = new Date().toISOString().split('T')[0]
const formAbierto = ref(false)
const form = ref({ categoria: 'riego', fecha: hoy, descripcion: '', producto: '', ec: null, volumen: null, macetaOrigen: null, macetaDestino: null })

const placeholderDescripcion = computed(() => placeholderFor(form.value.categoria))
const formValido = computed(() => {
  if (form.value.categoria === 'trasplante') return form.value.macetaDestino > 0
  if (['nota', 'otro'].includes(form.value.categoria)) return form.value.descripcion.trim().length > 0
  return true
})

function abrirForm() {
  form.value = { categoria: 'riego', fecha: hoy, descripcion: '', producto: '', ec: null, volumen: null, macetaOrigen: null, macetaDestino: null }
  formAbierto.value = true
}
function cerrarForm() { formAbierto.value = false }

function guardar() {
  if (!formValido.value) return
  const f = form.value
  if (f.categoria === 'trasplante') {
    emit('trasplante', { fecha: f.fecha, maceta_origen_l: f.macetaOrigen || undefined, maceta_destino_l: f.macetaDestino })
    formAbierto.value = false
    return
  }
  const metadata = {}
  if (f.ec != null && f.ec !== '')          metadata.ec = Number(f.ec)
  if (f.volumen != null && f.volumen !== '') metadata.volumen_l = Number(f.volumen)
  if (f.categoria === 'fertilizacion' && f.producto.trim()) metadata.producto = f.producto.trim()
  emit('crear', {
    tipo: 'actividad', categoria: f.categoria,
    descripcion: f.descripcion.trim() || null, metadata,
    registrado_en: `${f.fecha}T12:00:00`,
  })
  formAbierto.value = false
}
</script>

<style scoped>
.lhs__top { display: flex; gap: .5rem; flex-wrap: wrap; padding: .75rem 1.1rem; border-bottom: 1px solid #f0fdf4; }
.lhs__add-btn { flex: 1; min-width: 140px; background: #f0fdf4; border: 1px dashed #86c98a; color: #15803d; border-radius: 8px; padding: .5rem .85rem; font-size: .8rem; font-weight: 600; cursor: pointer; transition: all .15s; }
.lhs__add-btn:hover { background: #dcfce7; border-style: solid; }
.lhs__ver-btn { background: #fff; border: 1.5px solid #cbd5e1; color: #334155; border-radius: 8px; padding: .5rem .85rem; font-size: .8rem; font-weight: 600; cursor: pointer; }
.lhs__ver-btn:hover { border-color: #1b5e20; color: #1b5e20; }

.lhs__form { display: flex; flex-direction: column; gap: .5rem; padding: .75rem 1.1rem; border-bottom: 1px solid #f0fdf4; }
.lhs__form-row { display: flex; gap: .5rem; align-items: center; }
.lhs__form-sel { flex: 1; min-width: 0; border: 1.5px solid #cbd5e1; border-radius: 8px; padding: .45rem .55rem; font-size: .82rem; color: #0f172a; background: #fff; }
.lhs__form-date { flex: 1; min-width: 0; }
.lhs__form-input { width: 100%; box-sizing: border-box; border: 1.5px solid #cbd5e1; border-radius: 8px; padding: .5rem .65rem; font-size: .85rem; color: #0f172a; outline: none; }
.lhs__form-input:focus { border-color: #16a34a; }
.lhs__form-num { width: 100%; min-width: 0; flex: 1; border: 1.5px solid #cbd5e1; border-radius: 8px; padding: .5rem .55rem; font-size: .85rem; color: #0f172a; outline: none; }
.lhs__form-num:focus { border-color: #16a34a; }
.lhs__arrow { color: #94a3b8; font-weight: 800; flex-shrink: 0; }
.lhs__form-actions { display: flex; justify-content: flex-end; gap: .5rem; }
.lhs__form-cancel { background: #fff; border: 1.5px solid #cbd5e1; color: #334155; border-radius: 8px; padding: .4rem .85rem; font-size: .8rem; font-weight: 600; cursor: pointer; }
.lhs__form-save { background: #1b5e20; border: none; color: #fff; border-radius: 8px; padding: .4rem 1rem; font-size: .8rem; font-weight: 700; cursor: pointer; }
.lhs__form-save:disabled { opacity: .5; cursor: not-allowed; }

.lhs__placeholder { padding: 1rem 1.1rem; color: #94a3b8; font-size: .875rem; }
.lhs__lista { display: flex; flex-direction: column; }
.lhs__row { display: flex; gap: .85rem; padding: .7rem 1.1rem; border-bottom: 1px solid #f0fdf4; }
.lhs__row:last-of-type { border-bottom: none; }
.lhs__dot { width: 10px; height: 10px; border-radius: 50%; flex-shrink: 0; margin-top: .35rem; }
.lhs__row-body { flex: 1; min-width: 0; }
.lhs__row-head { display: flex; align-items: flex-start; justify-content: space-between; gap: .5rem; }
.lhs__row-titulo { font-size: .82rem; font-weight: 600; color: #1a1a1a; }
.lhs__row-detalle { color: #64748b; font-weight: 600; }
.lhs__row-fecha { font-size: .7rem; color: #94a3b8; white-space: nowrap; flex-shrink: 0; }
.lhs__row-desc { font-size: .78rem; color: #475569; margin-top: .2rem; }
.lhs__row-meta { font-size: .72rem; color: #94a3b8; margin-top: .15rem; }
.lhs__mas { width: 100%; background: none; border: none; border-top: 1px dashed #e8f0e9; color: #1b5e20; font-size: .78rem; font-weight: 600; padding: .6rem; cursor: pointer; }
.lhs__mas:hover { background: #f0fdf4; }
</style>
