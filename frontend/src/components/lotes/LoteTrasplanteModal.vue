<template>
  <Teleport to="body">
    <div v-if="modelValue" class="ltm__overlay">
      <div class="ltm__modal">
        <div class="ltm__header">
          <div>
            <h3 class="ltm__title">🪴 Trasplantar lote</h3>
            <p class="ltm__sub">{{ lote?.codigo }} · {{ lote?.plants_count }} plantas</p>
          </div>
          <button class="ltm__close" @click="$emit('update:modelValue', false)"><i class="bi bi-x-lg"></i></button>
        </div>

        <div class="ltm__body">
          <div v-if="error" class="ltm__alert">{{ error }}</div>

          <div class="ltm__grid">
            <div class="ltm__field">
              <label class="ltm__label">Maceta actual <span class="ltm__label-unit">litros</span></label>
              <div v-if="form.maceta_origen_l" class="ltm__current">
                <span class="ltm__current-val">{{ form.maceta_origen_l }}L</span>
              </div>
              <div v-else class="ltm__input-group">
                <input type="number" step="0.5" min="0" class="ltm__input"
                       v-model.number="form.maceta_origen_l" placeholder="Ej: 7" />
                <span class="ltm__input-suffix">L</span>
              </div>
            </div>
            <div class="ltm__field">
              <label class="ltm__label">Maceta destino <span class="ltm__label-unit">litros</span> <span class="ltm__req">*</span></label>
              <div class="ltm__input-group">
                <input type="number" step="0.5" min="0.5" class="ltm__input"
                       v-model.number="form.maceta_destino_l" placeholder="Ej: 11" />
                <span class="ltm__input-suffix">L</span>
              </div>
            </div>
          </div>

          <div v-if="form.maceta_origen_l && form.maceta_destino_l" class="ltm__preview">
            <span class="ltm__prev-val">{{ form.maceta_origen_l }}L</span>
            <i class="bi bi-arrow-right ltm__prev-arrow"></i>
            <span class="ltm__prev-val ltm__prev-val--dest">{{ form.maceta_destino_l }}L</span>
            <span class="ltm__prev-plants">× {{ seleccion.length }} planta{{ seleccion.length !== 1 ? 's' : '' }}</span>
          </div>

          <div class="ltm__section-title">Plantas a trasplantar</div>
          <div class="ltm__tp-header">
            <label class="ltm__checkbox-row ltm__tp-todas">
              <input type="checkbox" :checked="todasSeleccionadas" @change="toggleTodas" />
              <span>{{ todasSeleccionadas ? 'Quitar todas' : 'Seleccionar todas' }}</span>
            </label>
            <span class="ltm__tp-count">{{ seleccion.length }}/{{ plants.length }}</span>
          </div>
          <div class="ltm__tp-list">
            <label
              v-for="p in plants"
              :key="p.id"
              class="ltm__tp-item"
              :class="{ 'ltm__tp-item--sel': seleccion.includes(p.id) }"
            >
              <input type="checkbox" :checked="seleccion.includes(p.id)" @change="togglePlanta(p.id)" />
              <span class="ltm__tp-dot" :style="{ background: pm(p.state).color }"></span>
              <span class="ltm__tp-nombre">{{ p.nombre || p.codigo_qr || `Planta #${p.id}` }}</span>
              <span class="ltm__tp-estado">{{ pm(p.state).emoji }}</span>
            </label>
          </div>

          <div class="ltm__field" style="margin-top:.85rem">
            <label class="ltm__label">Notas <span class="ltm__optional">opcional</span></label>
            <input type="text" class="ltm__input" v-model.trim="form.notas"
                   placeholder="Ej: trasplante a sustrato definitivo, día 14 vegetativo…" />
          </div>
        </div>

        <div class="ltm__footer">
          <button class="ltm__btn-ghost" @click="$emit('update:modelValue', false)">Cancelar</button>
          <button class="ltm__btn-primary" :disabled="saving || !seleccion.length" @click="guardar">
            <DsSpinner v-if="saving" :size="14" />
            <i v-else class="bi bi-check-lg"></i>
            Trasplantar {{ seleccion.length }} planta{{ seleccion.length !== 1 ? 's' : '' }}
          </button>
        </div>
      </div>
    </div>
  </Teleport>
</template>

<script setup>
import { ref, computed, watch } from 'vue'
import { updateLote, createPlantActivity } from '../../lib/api'
import { useToast } from '../../composables/useToast.js'
import DsSpinner from '../../design-system/components/Spinner.vue'

const props = defineProps({
  modelValue: { type: Boolean, default: false },
  lote:       { type: Object, default: null },
  plants:     { type: Array,  default: () => [] },
})
const emit = defineEmits(['update:modelValue', 'saved'])

const toast = useToast()

const form     = ref({ maceta_origen_l: null, maceta_destino_l: null, notas: '' })
const seleccion = ref([])
const error    = ref(null)
const saving   = ref(false)

const PLANT_STATE_META = {
  semilla:     { label: 'Semilla',     color: '#64748b', emoji: '🌰' },
  germinacion: { label: 'Germinación', color: '#16a34a', emoji: '🌱' },
  esqueje:     { label: 'Esqueje',     color: '#0891b2', emoji: '🌿' },
  vegetativo:  { label: 'Vegetativo',  color: '#16a34a', emoji: '🍃' },
  floracion:   { label: 'Floración',   color: '#d97706', emoji: '🌸' },
  cosechado:   { label: 'Cosechada',   color: '#2563eb', emoji: '✅' },
  descartada:  { label: 'Descartada',  color: '#dc2626', emoji: '❌' },
}
function pm(s) { return PLANT_STATE_META[s] || { label: s || '—', color: '#64748b', emoji: '🌿' } }

const todasSeleccionadas = computed(() =>
  props.plants.length > 0 && seleccion.value.length === props.plants.length
)

function togglePlanta(plantId) {
  const idx = seleccion.value.indexOf(plantId)
  if (idx === -1) seleccion.value.push(plantId)
  else seleccion.value.splice(idx, 1)
}

function toggleTodas() {
  seleccion.value = todasSeleccionadas.value ? [] : props.plants.map(p => p.id)
}

watch(() => props.modelValue, (open) => {
  if (!open) return
  form.value     = { maceta_origen_l: props.lote?.tamanio_maceta || null, maceta_destino_l: null, notas: '' }
  error.value    = null
  seleccion.value = props.plants.map(p => p.id)
})

async function guardar() {
  const f = form.value
  if (!f.maceta_destino_l || f.maceta_destino_l <= 0) {
    error.value = 'Seleccioná o ingresá el tamaño de maceta destino'; return
  }
  if (!seleccion.value.length) {
    error.value = 'Seleccioná al menos una planta'; return
  }
  saving.value = true
  error.value  = null
  try {
    await updateLote(props.lote.id, { tamanio_maceta: parseFloat(f.maceta_destino_l) })
    await Promise.all(
      seleccion.value.map(plantId =>
        createPlantActivity(plantId, {
          activity_type: 'transplant',
          description: f.notas || undefined,
          metadata: { maceta_origen_l: f.maceta_origen_l, maceta_destino_l: parseFloat(f.maceta_destino_l) },
        })
      )
    )
    const n = seleccion.value.length
    emit('update:modelValue', false)
    emit('saved')
    toast.success(`${n} planta${n !== 1 ? 's' : ''} trasplantada${n !== 1 ? 's' : ''} a ${f.maceta_destino_l}L`)
  } catch (e) {
    error.value = e?.response?.data?.error || 'Error al guardar'
  } finally {
    saving.value = false
  }
}
</script>

<style scoped>
.ltm__overlay {
  position: fixed; inset: 0; background: rgba(0,0,0,.4);
  display: flex; align-items: center; justify-content: center;
  z-index: 1050; padding: 1rem; backdrop-filter: blur(3px);
}
.ltm__modal {
  background: #fff; border-radius: 16px; width: 100%; max-width: 500px;
  max-height: 92vh; overflow-y: auto; box-shadow: 0 24px 64px rgba(27,94,32,.15);
  display: flex; flex-direction: column;
}
.ltm__header {
  display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem;
  padding: 1.25rem 1.5rem 1rem; border-bottom: 1px solid #e8f0e9;
  position: sticky; top: 0; background: #fff; z-index: 1;
}
.ltm__title { font-size: 1.05rem; font-weight: 700; color: #1a1a1a; margin: 0; }
.ltm__sub   { font-size: .78rem; color: #60725d; margin: .2rem 0 0; }
.ltm__close {
  background: #e8f5e9; border: none; width: 30px; height: 30px;
  border-radius: 8px; cursor: pointer; display: flex; align-items: center;
  justify-content: center; color: #60725d; transition: all .15s; flex-shrink: 0;
}
.ltm__close:hover { background: #c8e6c9; }
.ltm__body   { padding: 1.25rem 1.5rem; flex: 1; }
.ltm__footer {
  display: flex; justify-content: flex-end; gap: .75rem;
  padding: 1rem 1.5rem; border-top: 1px solid #e8f0e9;
  position: sticky; bottom: 0; background: #fff;
}

.ltm__alert { background: #fef2f2; border: 1px solid #fecaca; color: #dc2626; padding: .75rem 1rem; border-radius: 8px; font-size: .85rem; margin-bottom: 1rem; }

.ltm__grid { display: grid; grid-template-columns: 1fr 1fr; gap: .85rem; margin-bottom: .75rem; }
.ltm__field { display: flex; flex-direction: column; gap: .35rem; }
.ltm__label { font-size: .78rem; font-weight: 700; color: #374151; text-transform: uppercase; letter-spacing: .04em; display: flex; align-items: baseline; gap: 6px; }
.ltm__label-unit { font-size: .65rem; color: #94a3b8; font-weight: 400; text-transform: none; letter-spacing: 0; margin-left: .2rem; }
.ltm__optional { font-size: .68rem; font-weight: 500; color: #94a3b8; text-transform: none; letter-spacing: 0; }
.ltm__req { color: #dc2626; font-weight: 700; }

.ltm__input { background: #f4f8f4; border: 1.5px solid #d4e6d4; border-radius: 8px; padding: .6rem .85rem; font-size: .875rem; color: #1a1a1a; width: 100%; box-sizing: border-box; transition: border .15s; }
.ltm__input:focus { outline: none; border-color: #1b5e20; background: #fff; }
.ltm__input-group { display: flex; }
.ltm__input-group .ltm__input { border-radius: 8px 0 0 8px; }
.ltm__input-suffix { background: #e8f5e9; border: 1.5px solid #d4e6d4; border-left: none; padding: .55rem .7rem; font-size: .8rem; font-weight: 600; color: #1b5e20; border-radius: 0 8px 8px 0; white-space: nowrap; }

.ltm__current { background: #f1f5f9; border: 1.5px solid #e2e8f0; border-radius: 8px; padding: .55rem .8rem; min-height: 38px; display: flex; align-items: center; }
.ltm__current-val { font-size: 1rem; font-weight: 700; color: #374151; }

.ltm__preview {
  display: flex; align-items: center; justify-content: center; gap: .85rem;
  background: #fffbeb; border: 1.5px solid #fde68a; border-radius: 10px;
  padding: .85rem 1rem; margin-bottom: .5rem;
}
.ltm__prev-val       { font-size: 1.4rem; font-weight: 800; color: #92400e; }
.ltm__prev-val--dest { color: #1b5e20; }
.ltm__prev-arrow     { color: #d97706; font-size: 1.1rem; }
.ltm__prev-plants    { font-size: .75rem; color: #60725d; font-weight: 600; margin-left: .25rem; }

.ltm__section-title { font-size: .72rem; font-weight: 800; color: #60725d; text-transform: uppercase; letter-spacing: .06em; margin: 1.1rem 0 .6rem; padding-bottom: .4rem; border-bottom: 1px solid #e8f0e9; }

.ltm__tp-header { display: flex; align-items: center; justify-content: space-between; margin-bottom: .4rem; }
.ltm__checkbox-row { display: flex; align-items: center; gap: .5rem; font-size: .82rem; color: #374151; cursor: pointer; user-select: none; }
.ltm__checkbox-row input[type="checkbox"] { width: 15px; height: 15px; accent-color: #1b5e20; cursor: pointer; flex-shrink: 0; }
.ltm__tp-todas { font-size: .82rem; color: #374151; gap: .4rem; }
.ltm__tp-count { font-size: .75rem; font-weight: 700; color: #1b5e20; background: #dcfce7; padding: .1em .5em; border-radius: 99px; }
.ltm__tp-list { display: flex; flex-direction: column; gap: 2px; max-height: 220px; overflow-y: auto; border: 1.5px solid #e2e8f0; border-radius: 8px; padding: .25rem; }
.ltm__tp-item { display: flex; align-items: center; gap: .5rem; padding: .35rem .5rem; border-radius: 6px; cursor: pointer; font-size: .82rem; transition: background .12s; }
.ltm__tp-item:hover { background: #f0fdf4; }
.ltm__tp-item--sel { background: #f0fdf4; }
.ltm__tp-dot   { width: 8px; height: 8px; border-radius: 50%; flex-shrink: 0; }
.ltm__tp-nombre { flex: 1; color: #1e293b; font-weight: 500; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.ltm__tp-estado { font-size: .85rem; flex-shrink: 0; }

.ltm__btn-primary { display: inline-flex; align-items: center; gap: .4rem; background: #1b5e20; color: #fff; border: none; padding: .6rem 1.25rem; border-radius: 8px; font-size: .875rem; font-weight: 600; cursor: pointer; transition: background .15s; white-space: nowrap; }
.ltm__btn-primary:hover { background: #104417; }
.ltm__btn-primary:disabled { opacity: .6; cursor: not-allowed; }
.ltm__btn-ghost { background: transparent; color: #60725d; border: 1px solid #d4e6d4; padding: .6rem 1.1rem; border-radius: 8px; font-size: .875rem; font-weight: 500; cursor: pointer; transition: all .15s; }
.ltm__btn-ghost:hover { background: #f0fdf4; }
</style>
