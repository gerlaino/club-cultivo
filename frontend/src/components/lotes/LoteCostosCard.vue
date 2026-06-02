<template>
  <div class="lcc__card">
    <div class="lcc__header">
      <span class="lcc__title">💰 Costos de producción</span>
      <button class="lcc__action" @click="openCostoForm">
        <i :class="costoLote ? 'bi bi-pencil' : 'bi bi-plus-lg'"></i>
        {{ costoLote ? 'Editar' : 'Cargar' }}
      </button>
    </div>

    <div v-if="showCostoForm" class="lcc__form">
      <div class="lcc__row">
        <label class="lcc__label">Insumos (ARS)</label>
        <input type="number" min="0" step="0.01" class="lcc__input" v-model.number="costoForm.costo_insumos" placeholder="0" />
      </div>
      <div class="lcc__row">
        <label class="lcc__label">Energía (ARS)</label>
        <input type="number" min="0" step="0.01" class="lcc__input" v-model.number="costoForm.costo_energia" placeholder="0" />
      </div>
      <div class="lcc__row">
        <label class="lcc__label">Mano de obra (ARS)</label>
        <input type="number" min="0" step="0.01" class="lcc__input" v-model.number="costoForm.costo_mano_obra" placeholder="0" />
      </div>
      <div class="lcc__row">
        <label class="lcc__label">Prorrateado (ARS)</label>
        <input type="number" min="0" step="0.01" class="lcc__input" v-model.number="costoForm.costo_prorrateado" placeholder="0" />
      </div>
      <div class="lcc__total">
        Total: <strong>{{ formatARS(costoTotal) }}</strong>
      </div>
      <div class="lcc__row lcc__row--sep">
        <label class="lcc__label">Gramos producidos</label>
        <input type="number" min="0" step="0.1" class="lcc__input" v-model.number="costoForm.gramos_producidos" placeholder="g" />
      </div>
      <div v-if="costoPorGramo" class="lcc__cpg-inline">
        Costo/g: <strong>{{ formatARS(costoPorGramo) }}</strong>
      </div>
      <div class="lcc__row">
        <label class="lcc__label">Notas</label>
        <input type="text" class="lcc__input" v-model="costoForm.notas" placeholder="Opcional" />
      </div>
      <div class="lcc__actions">
        <button class="lcc__btn-ghost" @click="showCostoForm = false">Cancelar</button>
        <button class="lcc__btn-primary" :disabled="savingCosto" @click="saveCosto">
          {{ savingCosto ? 'Guardando…' : 'Guardar costos' }}
        </button>
      </div>
    </div>

    <template v-else-if="costoLote">
      <dl class="lcc__dl">
        <dt>Insumos</dt><dd>{{ formatARS(costoLote.costo_insumos || 0) }}</dd>
        <dt>Energía</dt><dd>{{ formatARS(costoLote.costo_energia || 0) }}</dd>
        <dt>Mano de obra</dt><dd>{{ formatARS(costoLote.costo_mano_obra || 0) }}</dd>
        <dt v-if="costoLote.costo_prorrateado">Prorrateado</dt>
        <dd v-if="costoLote.costo_prorrateado">{{ formatARS(costoLote.costo_prorrateado || 0) }}</dd>
        <dt class="lcc__dl-total">Total</dt>
        <dd class="lcc__dl-total">{{ formatARS(costoLote.costo_total || 0) }}</dd>
        <dt v-if="costoLote.gramos_producidos">Rendimiento</dt>
        <dd v-if="costoLote.gramos_producidos">{{ costoLote.gramos_producidos }}g</dd>
      </dl>
      <div v-if="costoLote.costo_por_gramo" class="lcc__cpg-badge">
        <span class="lcc__cpg-label">Costo/gramo</span>
        <span class="lcc__cpg-value">{{ formatARS(costoLote.costo_por_gramo) }}</span>
      </div>
    </template>

    <div v-else class="lcc__empty">
      <i class="bi bi-calculator"></i>
      <span>Sin costos cargados</span>
    </div>
  </div>
</template>

<script setup>
import { onMounted } from 'vue'
import { useLoteCostos } from '../../composables/useLoteCostos.js'
import { formatARS } from '../../lib/formatters.js'

const props = defineProps({
  loteId: { type: Number, required: true },
})

const {
  costoLote, showCostoForm, savingCosto, costoForm,
  costoTotal, costoPorGramo,
  openCostoForm, saveCosto, cargarCostos,
} = useLoteCostos(props.loteId)

onMounted(() => cargarCostos())
</script>

<style scoped>
.lcc__card { background: #fff; border: 1px solid #d4e6d4; border-radius: 14px; overflow: hidden; }
.lcc__header { display: flex; align-items: center; justify-content: space-between; padding: .8rem 1rem; border-bottom: 1px solid #e8f0e9; }
.lcc__title { font-size: .85rem; font-weight: 700; color: #1a1a1a; }
.lcc__action { background: none; border: 1px solid #d4e6d4; color: #15803d; font-size: .75rem; font-weight: 600; padding: .25rem .65rem; border-radius: 6px; cursor: pointer; display: flex; align-items: center; gap: .3rem; transition: background .15s; }
.lcc__action:hover { background: #f0fdf4; }
.lcc__form { padding: .9rem 1rem; display: flex; flex-direction: column; gap: .6rem; }
.lcc__row { display: flex; align-items: center; justify-content: space-between; gap: .5rem; }
.lcc__row--sep { border-top: 1px solid #e8f0e9; padding-top: .6rem; margin-top: .2rem; }
.lcc__label { font-size: .75rem; color: #60725d; font-weight: 500; flex-shrink: 0; }
.lcc__input { width: 120px; padding: .3rem .5rem; border: 1px solid #d4e6d4; border-radius: 6px; font-size: .8rem; text-align: right; background: #f9fdfb; }
.lcc__input:focus { outline: none; border-color: #15803d; }
.lcc__total { font-size: .8rem; font-weight: 700; color: #1a3d2e; text-align: right; padding: .4rem .5rem; background: #f0fdf4; border-radius: 6px; }
.lcc__cpg-inline { font-size: .8rem; color: #0369a1; text-align: right; font-weight: 600; }
.lcc__actions { display: flex; justify-content: flex-end; gap: .5rem; margin-top: .4rem; }
.lcc__dl { display: grid; grid-template-columns: auto 1fr; gap: .4rem .75rem; padding: .9rem 1rem; margin: 0; }
.lcc__dl dt { font-size: .75rem; color: #60725d; font-weight: 500; white-space: nowrap; }
.lcc__dl dd { font-size: .8rem; color: #1a1a1a; font-weight: 500; margin: 0; }
.lcc__dl-total { font-weight: 700 !important; color: #1a3d2e !important; border-top: 1px solid #e8f0e9; padding-top: .3rem; }
.lcc__cpg-badge { display: flex; justify-content: space-between; align-items: center; margin: 0 1rem .9rem; padding: .5rem .75rem; background: linear-gradient(135deg, #f0fdf4, #dcfce7); border-radius: 8px; border: 1px solid #bbf7d0; }
.lcc__cpg-label { font-size: .75rem; font-weight: 600; color: #15803d; }
.lcc__cpg-value { font-family: monospace; font-size: .95rem; font-weight: 800; color: #15803d; }
.lcc__empty { display: flex; flex-direction: column; align-items: center; gap: .4rem; padding: 1.2rem 1rem; color: #94a3b8; font-size: .8rem; }
.lcc__empty i { font-size: 1.4rem; }
.lcc__btn-primary { display: inline-flex; align-items: center; gap: .4rem; background: #1b5e20; color: #fff; border: none; padding: .5rem 1rem; border-radius: 8px; font-size: .82rem; font-weight: 600; cursor: pointer; transition: background .15s; }
.lcc__btn-primary:hover { background: #104417; }
.lcc__btn-primary:disabled { opacity: .6; cursor: not-allowed; }
.lcc__btn-ghost { background: transparent; color: #60725d; border: 1px solid #d4e6d4; padding: .5rem .9rem; border-radius: 8px; font-size: .82rem; cursor: pointer; transition: all .15s; }
.lcc__btn-ghost:hover { background: #f0fdf4; }
</style>
