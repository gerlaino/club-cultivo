<template>
  <Teleport to="body">
    <div v-if="modelValue" class="lhm__overlay" @click.self="cerrar">
      <div class="lhm__modal">
        <div class="lhm__head">
          <h3>📜 Historial del lote</h3>
          <div class="lhm__head-actions">
            <button v-if="canAdmin" class="lhm__edit-toggle" :class="{ 'lhm__edit-toggle--on': editMode }" @click="editMode = !editMode">
              <i class="bi" :class="editMode ? 'bi-check2' : 'bi-pencil'"></i>
              {{ editMode ? 'Listo' : 'Editar' }}
            </button>
            <button class="lhm__close" @click="cerrar"><i class="bi bi-x-lg"></i></button>
          </div>
        </div>

        <!-- Filtros -->
        <div class="lhm__filtros">
          <input v-model="busqueda" type="text" class="lhm__buscar" placeholder="🔎 Buscar por evento, detalle o persona…" />
          <select v-model="filtroKind" class="lhm__sel">
            <option value="">Todos los tipos</option>
            <option v-for="k in KINDS" :key="k.value" :value="k.value">{{ k.label }}</option>
          </select>
          <input v-model="desde" type="date" class="lhm__fecha" title="Desde" />
          <input v-model="hasta" type="date" class="lhm__fecha" title="Hasta" />
        </div>

        <div class="lhm__body">
          <div v-if="!filtrados.length" class="lhm__vacio">No hay eventos que coincidan con el filtro.</div>
          <div v-for="it in filtrados" :key="it.source + it.id" class="lhm__row">
            <div class="lhm__dot" :style="{ background: dotColor(it) }"></div>
            <div class="lhm__row-body">
              <!-- Edición inline (campos según la categoría de la actividad) -->
              <div v-if="editandoId === rowKey(it)" class="lhm__edit">
                <div class="lhm__edit-titulo">{{ it.emoji }} {{ it.titulo }}</div>

                <div v-if="it.categoria === 'fertilizacion'" class="lhm__edit-row">
                  <input v-model="editForm.producto" type="text" class="lhm__edit-input" maxlength="120" placeholder="Producto / fórmula" />
                  <input v-model.number="editForm.ec" type="number" step="0.1" min="0" class="lhm__edit-num" placeholder="EC" />
                </div>
                <div v-else-if="it.categoria === 'riego'" class="lhm__edit-row">
                  <input v-model.number="editForm.volumen" type="number" step="0.1" min="0" class="lhm__edit-num" placeholder="Volumen (L)" />
                  <input v-model.number="editForm.ec" type="number" step="0.1" min="0" class="lhm__edit-num" placeholder="EC" />
                </div>

                <input v-model="editForm.descripcion" type="text" class="lhm__edit-input" maxlength="200" placeholder="Descripción (opcional)" @keyup.enter="guardarEdicion(it)" />
                <div class="lhm__edit-row">
                  <input v-model="editForm.fecha" type="date" class="lhm__fecha" />
                  <div class="lhm__edit-actions">
                    <button class="lhm__btn-ghost" @click="editandoId = null">Cancelar</button>
                    <button class="lhm__btn-primary" @click="guardarEdicion(it)">Guardar</button>
                  </div>
                </div>
              </div>
              <!-- Lectura -->
              <template v-else>
                <div class="lhm__row-head">
                  <span class="lhm__row-titulo">{{ it.emoji }} {{ it.titulo }}<span v-if="metaDetalle(it)" class="lhm__row-detalle"> · {{ metaDetalle(it) }}</span></span>
                  <div class="lhm__row-right">
                    <span class="lhm__row-fecha">{{ formatDateTime(it.fecha) }}</span>
                    <template v-if="editMode">
                      <button v-if="it.editable" class="lhm__icon lhm__icon--edit" title="Editar" @click="empezarEdicion(it)"><i class="bi bi-pencil"></i></button>
                      <button v-if="it.deletable" class="lhm__icon lhm__icon--del" title="Borrar" @click="$emit('delete', it)"><i class="bi bi-trash"></i></button>
                    </template>
                  </div>
                </div>
                <div v-if="it.detalle" class="lhm__row-desc">{{ it.detalle }}</div>
                <div v-if="it.usuario" class="lhm__row-meta">{{ it.usuario }}</div>
              </template>
            </div>
          </div>
        </div>

        <div class="lhm__foot">
          <span class="lhm__count">{{ filtrados.length }} de {{ historial.length }} eventos</span>
        </div>
      </div>
    </div>
  </Teleport>
</template>

<script setup>
import { ref, computed, watch } from 'vue'
import { formatDateTime } from '../../lib/loteHelpers.js'
import { KINDS, dotColor, metaDetalle } from '../../lib/historialHelpers.js'

const props = defineProps({
  modelValue: { type: Boolean, default: false },
  historial:  { type: Array,   default: () => [] },
  canAdmin:   { type: Boolean, default: false },
})
const emit = defineEmits(['update:modelValue', 'editar', 'delete'])

const editMode   = ref(false)
const busqueda   = ref('')
const filtroKind = ref('')
const desde      = ref('')
const hasta      = ref('')

const rowKey = (it) => `${it.source}-${it.id}`

const filtrados = computed(() => {
  const q = busqueda.value.trim().toLowerCase()
  return props.historial.filter((it) => {
    if (filtroKind.value && it.kind !== filtroKind.value) return false
    if (desde.value && (it.fecha || '') < desde.value) return false
    if (hasta.value && (it.fecha || '').slice(0, 10) > hasta.value) return false
    if (q) {
      const hay = `${it.titulo} ${it.detalle || ''} ${it.usuario || ''} ${it.categoria || ''}`.toLowerCase()
      if (!hay.includes(q)) return false
    }
    return true
  })
})

// ── Edición inline ────────────────────────────────────────
const editandoId = ref(null)
const editForm   = ref({ descripcion: '', fecha: '', producto: '', ec: null, volumen: null })

function empezarEdicion(it) {
  editandoId.value = rowKey(it)
  const m = it.metadata || {}
  editForm.value = {
    descripcion: it.detalle || '',                 // it.detalle es la descripción real (no el título)
    fecha: (it.fecha || '').slice(0, 10),
    producto: m.producto || '',
    ec: m.ec ?? null,
    volumen: m.volumen_l ?? null,
  }
}
function guardarEdicion(it) {
  const f = editForm.value
  // Reconstruyo la metadata completa (el update REEMPLAZA el jsonb) preservando lo no editado.
  const metadata = { ...(it.metadata || {}) }
  if (it.categoria === 'fertilizacion') {
    if (f.producto.trim()) metadata.producto = f.producto.trim(); else delete metadata.producto
  }
  if (['fertilizacion', 'riego'].includes(it.categoria)) {
    if (f.ec != null && f.ec !== '') metadata.ec = Number(f.ec); else delete metadata.ec
  }
  if (it.categoria === 'riego') {
    if (f.volumen != null && f.volumen !== '') metadata.volumen_l = Number(f.volumen); else delete metadata.volumen_l
  }
  emit('editar', {
    id: it.id,
    descripcion: f.descripcion.trim() || null,
    registrado_en: `${f.fecha}T12:00:00`,
    metadata,
  })
  editandoId.value = null
}

function cerrar() { editMode.value = false; editandoId.value = null; emit('update:modelValue', false) }
watch(() => props.modelValue, (open) => { if (!open) { editMode.value = false; editandoId.value = null } })
</script>

<style scoped>
.lhm__overlay { position: fixed; inset: 0; background: rgba(0,0,0,.45); display: flex; align-items: center; justify-content: center; z-index: 1060; padding: 1rem; }
.lhm__modal { background: #fff; border-radius: 16px; width: 100%; max-width: 680px; max-height: 88vh; display: flex; flex-direction: column; box-shadow: 0 20px 60px rgba(0,0,0,.3); }
.lhm__head { display: flex; align-items: center; justify-content: space-between; padding: 1rem 1.25rem; border-bottom: 1px solid #f1f5f9; }
.lhm__head h3 { margin: 0; font-size: 1rem; font-weight: 800; color: #0f172a; }
.lhm__head-actions { display: flex; align-items: center; gap: .5rem; }
.lhm__edit-toggle { background: #fff; border: 1.5px solid #cbd5e1; color: #334155; border-radius: 8px; padding: .35rem .75rem; font-size: .8rem; font-weight: 700; cursor: pointer; }
.lhm__edit-toggle--on { background: #1b5e20; border-color: #1b5e20; color: #fff; }
.lhm__close { background: none; border: none; cursor: pointer; color: #94a3b8; font-size: 1rem; }

.lhm__filtros { display: flex; gap: .5rem; flex-wrap: wrap; padding: .75rem 1.25rem; border-bottom: 1px solid #f1f5f9; }
.lhm__buscar { flex: 1 1 220px; min-width: 0; border: 1.5px solid #cbd5e1; border-radius: 8px; padding: .5rem .65rem; font-size: .85rem; outline: none; }
.lhm__buscar:focus { border-color: #16a34a; }
.lhm__sel { border: 1.5px solid #cbd5e1; border-radius: 8px; padding: .5rem .55rem; font-size: .82rem; background: #fff; }
.lhm__fecha { border: 1.5px solid #cbd5e1; border-radius: 8px; padding: .45rem .5rem; font-size: .8rem; color: #334155; }

.lhm__body { overflow-y: auto; flex: 1; }
.lhm__vacio { padding: 2rem 1.25rem; text-align: center; color: #94a3b8; font-size: .85rem; }
.lhm__row { display: flex; gap: .85rem; padding: .7rem 1.25rem; border-bottom: 1px solid #f6f9f6; }
.lhm__dot { width: 10px; height: 10px; border-radius: 50%; flex-shrink: 0; margin-top: .35rem; }
.lhm__row-body { flex: 1; min-width: 0; }
.lhm__row-head { display: flex; align-items: flex-start; justify-content: space-between; gap: .5rem; }
.lhm__row-titulo { font-size: .84rem; font-weight: 600; color: #1a1a1a; }
.lhm__row-detalle { color: #64748b; font-weight: 600; }
.lhm__row-right { display: flex; align-items: center; gap: .35rem; flex-shrink: 0; }
.lhm__row-fecha { font-size: .7rem; color: #94a3b8; white-space: nowrap; }
.lhm__icon { background: none; border: none; cursor: pointer; color: #cbd5e1; padding: .1rem .25rem; font-size: .8rem; border-radius: 5px; }
.lhm__icon--edit:hover { color: #2563eb; background: #eff6ff; }
.lhm__icon--del:hover { color: #dc2626; background: #fef2f2; }
.lhm__row-desc { font-size: .8rem; color: #475569; margin-top: .2rem; }
.lhm__row-meta { font-size: .72rem; color: #94a3b8; margin-top: .15rem; }

.lhm__edit { display: flex; flex-direction: column; gap: .5rem; }
.lhm__edit-titulo { font-size: .82rem; font-weight: 700; color: #166534; }
.lhm__edit-input { width: 100%; box-sizing: border-box; border: 1.5px solid #cbd5e1; border-radius: 8px; padding: .5rem .65rem; font-size: .85rem; outline: none; }
.lhm__edit-input:focus { border-color: #16a34a; }
.lhm__edit-num { width: 100px; flex-shrink: 0; box-sizing: border-box; border: 1.5px solid #cbd5e1; border-radius: 8px; padding: .5rem .55rem; font-size: .85rem; outline: none; }
.lhm__edit-num:focus { border-color: #16a34a; }
.lhm__edit-row { display: flex; justify-content: space-between; gap: .5rem; }
.lhm__edit-actions { display: flex; gap: .5rem; }
.lhm__btn-ghost { background: #fff; border: 1.5px solid #cbd5e1; color: #334155; border-radius: 8px; padding: .4rem .85rem; font-size: .8rem; font-weight: 600; cursor: pointer; }
.lhm__btn-primary { background: #1b5e20; border: none; color: #fff; border-radius: 8px; padding: .4rem 1rem; font-size: .8rem; font-weight: 700; cursor: pointer; }

.lhm__foot { padding: .75rem 1.25rem; border-top: 1px solid #f1f5f9; }
.lhm__count { font-size: .75rem; color: #94a3b8; }
</style>
