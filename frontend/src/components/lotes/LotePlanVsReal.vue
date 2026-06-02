<template>
  <div>
    <div class="pvr__header">
      <button v-if="canAdmin && !showForm" class="pvr__action" @click="openForm">
        <i class="bi bi-pencil"></i> {{ lote.plants_count_objetivo ? 'Editar' : 'Cargar objetivo' }}
      </button>
    </div>

    <!-- Form -->
    <div v-if="showForm" class="pvr__form">
      <div class="pvr__row">
        <label class="pvr__label">Plantas objetivo</label>
        <input type="number" min="0" step="1" class="pvr__input" v-model.number="form.plants_count_objetivo" placeholder="—" />
      </div>
      <div class="pvr__row">
        <label class="pvr__label">Rendimiento objetivo (g)</label>
        <input type="number" min="0" step="0.1" class="pvr__input" v-model.number="form.rendimiento_objetivo_g" placeholder="—" />
      </div>
      <div class="pvr__row">
        <label class="pvr__label">Fecha cosecha estimada</label>
        <input type="date" class="pvr__input" v-model="form.fecha_cosecha_estimada" />
      </div>
      <div v-if="lote.estado === 'finalizado'" class="pvr__row pvr__row--sep">
        <label class="pvr__label">Rendimiento real (g)</label>
        <input type="number" min="0" step="0.1" class="pvr__input" v-model.number="form.rendimiento_real_g" placeholder="—" />
      </div>
      <div class="pvr__actions">
        <button class="pvr__btn-ghost" @click="showForm = false">Cancelar</button>
        <button class="pvr__btn-primary" :disabled="saving" @click="saveForm">
          {{ saving ? 'Guardando…' : 'Guardar' }}
        </button>
      </div>
    </div>

    <!-- Display -->
    <template v-else-if="lote.plants_count_objetivo || lote.rendimiento_objetivo_g">
      <div class="pvr__data">
        <div v-if="lote.plants_count_objetivo" class="pvr__row-data">
          <span class="pvr__item-label">Plantas</span>
          <span class="pvr__objetivo">{{ lote.plants_count_objetivo }}</span>
          <span class="pvr__sep">vs</span>
          <span class="pvr__real" :class="plantasDevClass">{{ lote.plants_count ?? '—' }}</span>
          <span v-if="lote.plants_count && lote.plants_count_objetivo" class="pvr__dev" :class="plantasDevClass">
            {{ plantasDevPct > 0 ? '+' : '' }}{{ plantasDevPct }}%
          </span>
        </div>
        <div v-if="lote.rendimiento_objetivo_g" class="pvr__row-data">
          <span class="pvr__item-label">Rendimiento</span>
          <span class="pvr__objetivo">{{ lote.rendimiento_objetivo_g }}g</span>
          <span class="pvr__sep">vs</span>
          <span class="pvr__real" :class="rendDevClass">{{ lote.rendimiento_real_g ? lote.rendimiento_real_g + 'g' : '—' }}</span>
          <span v-if="lote.rendimiento_real_g && lote.rendimiento_objetivo_g" class="pvr__dev" :class="rendDevClass">
            {{ rendDevPct > 0 ? '+' : '' }}{{ rendDevPct }}%
          </span>
        </div>
        <div v-if="lote.fecha_cosecha_estimada" class="pvr__row-data">
          <span class="pvr__item-label">Cosecha est.</span>
          <span class="pvr__objetivo">{{ lote.fecha_cosecha_estimada }}</span>
        </div>
      </div>
    </template>

    <div v-else class="pvr__empty">
      <i class="bi bi-bullseye"></i>
      <span>Sin objetivos cargados</span>
    </div>
  </div>
</template>

<script setup>
import { ref, computed } from 'vue'
import { updateLote } from '../../lib/api'
import { useToast } from '../../composables/useToast.js'

const props = defineProps({
  lote:     { type: Object,  required: true },
  loteId:   { type: Number,  required: true },
  canAdmin: { type: Boolean, default: false },
})
const emit = defineEmits(['saved'])

const toast    = useToast()
const showForm = ref(false)
const saving   = ref(false)
const form     = ref({})

function openForm() {
  form.value = {
    plants_count_objetivo:  props.lote.plants_count_objetivo  ?? '',
    rendimiento_objetivo_g: props.lote.rendimiento_objetivo_g ?? '',
    fecha_cosecha_estimada: props.lote.fecha_cosecha_estimada ?? '',
    rendimiento_real_g:     props.lote.rendimiento_real_g     ?? '',
  }
  showForm.value = true
}

async function saveForm() {
  saving.value = true
  try {
    await updateLote(props.loteId, {
      plants_count_objetivo:  form.value.plants_count_objetivo  || null,
      rendimiento_objetivo_g: form.value.rendimiento_objetivo_g || null,
      fecha_cosecha_estimada: form.value.fecha_cosecha_estimada || null,
      rendimiento_real_g:     form.value.rendimiento_real_g     || null,
    })
    showForm.value = false
    emit('saved')
    toast.success('Objetivos guardados')
  } catch {
    toast.error('Error al guardar objetivos')
  } finally {
    saving.value = false
  }
}

const plantasDevPct = computed(() => {
  const obj = props.lote?.plants_count_objetivo
  const real = props.lote?.plants_count
  if (!obj || !real) return 0
  return Math.round((real - obj) / obj * 100)
})
const plantasDevClass = computed(() => {
  const p = plantasDevPct.value
  return p > 0 ? 'pvr__positive' : p < 0 ? 'pvr__negative' : ''
})
const rendDevPct = computed(() => {
  const obj = props.lote?.rendimiento_objetivo_g
  const real = props.lote?.rendimiento_real_g
  if (!obj || !real) return 0
  return Math.round((real - obj) / obj * 100)
})
const rendDevClass = computed(() => {
  const p = rendDevPct.value
  return p > 0 ? 'pvr__positive' : p < 0 ? 'pvr__negative' : ''
})
</script>

<style scoped>
.pvr__header   { display: flex; justify-content: flex-end; padding: 0 1rem .4rem; }
.pvr__action   { background: none; border: 1px solid #d4e6d4; color: #15803d; font-size: .75rem; font-weight: 600; padding: .25rem .65rem; border-radius: 6px; cursor: pointer; display: flex; align-items: center; gap: .3rem; }
.pvr__action:hover { background: #f0fdf4; }
.pvr__form     { padding: .5rem 1rem .8rem; display: flex; flex-direction: column; gap: .6rem; }
.pvr__row      { display: flex; align-items: center; justify-content: space-between; gap: .5rem; }
.pvr__row--sep { border-top: 1px solid #e8f0e9; padding-top: .6rem; margin-top: .2rem; }
.pvr__label    { font-size: .75rem; color: #60725d; font-weight: 500; flex-shrink: 0; }
.pvr__input    { width: 120px; padding: .3rem .5rem; border: 1px solid #d4e6d4; border-radius: 6px; font-size: .8rem; text-align: right; background: #f9fdfb; }
.pvr__input:focus { outline: none; border-color: #15803d; }
.pvr__actions  { display: flex; justify-content: flex-end; gap: .5rem; margin-top: .4rem; }
.pvr__btn-primary { display: inline-flex; align-items: center; gap: .4rem; background: #1b5e20; color: #fff; border: none; padding: .5rem 1rem; border-radius: 8px; font-size: .82rem; font-weight: 600; cursor: pointer; }
.pvr__btn-primary:disabled { opacity: .6; cursor: not-allowed; }
.pvr__btn-ghost   { background: transparent; color: #60725d; border: 1px solid #d4e6d4; padding: .5rem 1rem; border-radius: 8px; font-size: .82rem; cursor: pointer; }
.pvr__data     { padding: .5rem 1rem .8rem; display: flex; flex-direction: column; gap: .5rem; }
.pvr__row-data { display: flex; align-items: center; gap: .5rem; font-size: .85rem; flex-wrap: wrap; }
.pvr__item-label { font-size: .75rem; color: #64748b; min-width: 90px; }
.pvr__objetivo { color: #334155; font-weight: 600; }
.pvr__sep      { color: #94a3b8; font-size: .7rem; }
.pvr__real     { font-weight: 700; color: #1b5e20; }
.pvr__dev      { font-size: .75rem; font-weight: 700; padding: .1rem .4rem; border-radius: 4px; }
.pvr__positive { color: #15803d; background: #dcfce7; }
.pvr__negative { color: #dc2626; background: #fee2e2; }
.pvr__empty    { display: flex; flex-direction: column; align-items: center; gap: .4rem; padding: 1rem; color: #94a3b8; font-size: .8rem; }
.pvr__empty i  { font-size: 1.4rem; }
</style>
