<template>
  <div class="plc">
    <!-- Header -->
    <div class="plc__header">
      <span class="plc__title">P&L del lote</span>
      <button class="plc__btn-edit" @click="openCostoForm">
        <Pencil :size="13" :stroke-width="2" />
        {{ costoLote ? 'Editar costos' : 'Cargar costos' }}
      </button>
    </div>

    <!-- Formulario de costos (collapsible) -->
    <div v-if="showCostoForm" class="plc__form">
      <div class="plc__form-row">
        <label class="plc__form-label">Insumos (ARS)</label>
        <input type="number" min="0" step="0.01" class="plc__form-input" v-model.number="costoForm.costo_insumos" placeholder="0" />
      </div>
      <div class="plc__form-row">
        <label class="plc__form-label">Energía (ARS)</label>
        <input type="number" min="0" step="0.01" class="plc__form-input" v-model.number="costoForm.costo_energia" placeholder="0" />
      </div>
      <div class="plc__form-row">
        <label class="plc__form-label">Mano de obra (ARS)</label>
        <input type="number" min="0" step="0.01" class="plc__form-input" v-model.number="costoForm.costo_mano_obra" placeholder="0" />
      </div>
      <div class="plc__form-row">
        <label class="plc__form-label">Prorrateado (ARS)</label>
        <input type="number" min="0" step="0.01" class="plc__form-input" v-model.number="costoForm.costo_prorrateado" placeholder="0" />
      </div>
      <div class="plc__form-total">Total costos: <strong>{{ formatARS(costoTotal) }}</strong></div>

      <!-- Gramos producidos — solo lectura desde pesadas aprobadas -->
      <div class="plc__gramos-block">
        <span class="plc__form-label">Gramos producidos</span>
        <div v-if="estadoGramos === 'aprobado'" class="plc__gramos-ok">
          {{ gramosAprobados }}g — {{ pesadasAprobadas.length }} pesada{{ pesadasAprobadas.length !== 1 ? 's' : '' }} aprobada{{ pesadasAprobadas.length !== 1 ? 's' : '' }}
        </div>
        <div v-else-if="estadoGramos === 'pendiente'" class="plc__gramos-pendiente">
          {{ gramosPendientes }}g — pendiente de aprobación
        </div>
        <div v-else class="plc__gramos-vacio">Sin pesadas registradas</div>
      </div>

      <div class="plc__form-row">
        <label class="plc__form-label">Notas</label>
        <input type="text" class="plc__form-input" v-model="costoForm.notas" placeholder="Opcional" />
      </div>
      <div class="plc__form-actions">
        <button class="plc__btn-ghost" @click="showCostoForm = false">Cancelar</button>
        <button class="plc__btn-primary" :disabled="savingCosto" @click="handleSave">
          {{ savingCosto ? 'Guardando…' : 'Guardar' }}
        </button>
      </div>
    </div>

    <!-- P&L display -->
    <template v-else>
      <div v-if="loadingPL" class="plc__skel-wrap">
        <div class="plc__skel" />
        <div class="plc__skel plc__skel--sm" />
      </div>

      <template v-else-if="pl">
        <!-- Margen banner -->
        <div class="plc__margen-banner" :class="pl.margen >= 0 ? 'plc__margen-banner--pos' : 'plc__margen-banner--neg'">
          <div class="plc__margen-main">
            <span class="plc__margen-label">Margen bruto</span>
            <span class="plc__margen-val">{{ formatARS(pl.margen) }}</span>
          </div>
          <span v-if="pl.margen_pct !== null" class="plc__margen-pct">
            {{ pl.margen_pct >= 0 ? '+' : '' }}{{ pl.margen_pct }}%
          </span>
        </div>

        <!-- Costos vs Ingresos -->
        <div class="plc__split">
          <div class="plc__col">
            <span class="plc__col-label">Costos</span>
            <span class="plc__col-val">{{ formatARS(pl.costo_total) }}</span>
            <div v-if="pl.tiene_costos" class="plc__col-detail">
              <span v-if="pl.costo_insumos">Insumos {{ formatARS(pl.costo_insumos) }}</span>
              <span v-if="pl.costo_energia">Energía {{ formatARS(pl.costo_energia) }}</span>
              <span v-if="pl.costo_mano_obra">M.O. {{ formatARS(pl.costo_mano_obra) }}</span>
              <span v-if="pl.costo_prorrateado">Prorr. {{ formatARS(pl.costo_prorrateado) }}</span>
            </div>
            <span v-else class="plc__col-none">Sin costos cargados</span>
          </div>
          <div class="plc__divider" />
          <div class="plc__col">
            <span class="plc__col-label">Ingresos</span>
            <span class="plc__col-val plc__col-val--green">{{ formatARS(pl.ingresos) }}</span>
            <div v-if="pl.tiene_ingresos" class="plc__col-detail">
              <span>{{ pl.gramos_dispensados.toFixed(1) }}g dispensados</span>
            </div>
            <span v-else class="plc__col-none">Sin dispensaciones con precio</span>
          </div>
        </div>

        <!-- Métricas por gramo -->
        <div v-if="pl.costo_por_gramo || pl.ingreso_por_gramo" class="plc__gpg">
          <div v-if="pl.costo_por_gramo" class="plc__gpg-item">
            <span class="plc__gpg-label">Costo/g</span>
            <span class="plc__gpg-val">{{ formatARS(pl.costo_por_gramo) }}</span>
          </div>
          <div v-if="pl.ingreso_por_gramo" class="plc__gpg-item plc__gpg-item--green">
            <span class="plc__gpg-label">Ingreso/g</span>
            <span class="plc__gpg-val">{{ formatARS(pl.ingreso_por_gramo) }}</span>
          </div>
          <div v-if="pl.gramos_en_stock > 0" class="plc__gpg-item">
            <span class="plc__gpg-label">En stock</span>
            <span class="plc__gpg-val">{{ pl.gramos_en_stock.toFixed(1) }}g</span>
          </div>
        </div>

        <!-- Advertencias -->
        <div v-if="!pl.tiene_costos || !pl.tiene_ingresos" class="plc__hints">
          <span v-if="!pl.tiene_costos" class="plc__hint">Cargá los costos para ver el P&L completo</span>
          <span v-if="!pl.tiene_ingresos" class="plc__hint">El margen mejorará cuando se registren dispensaciones con precio</span>
        </div>
      </template>

      <div v-else class="plc__empty">
        <span>Cargá los costos para calcular el P&L</span>
      </div>
    </template>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { Pencil } from 'lucide-vue-next'
import { useLoteCostos } from '../../composables/useLoteCostos.js'
import { getLotePL } from '../../lib/api.js'
import { formatARS } from '../../lib/formatters.js'

const props = defineProps({
  loteId: { type: Number, required: true },
})

const {
  costoLote, showCostoForm, savingCosto, costoForm,
  costoTotal, gramosAprobados, gramosPendientes, estadoGramos,
  pesadasAprobadas, openCostoForm, saveCosto, cargarCostos,
} = useLoteCostos(props.loteId)

const pl        = ref(null)
const loadingPL = ref(false)

async function cargarPL() {
  loadingPL.value = true
  try {
    const { data } = await getLotePL(props.loteId)
    pl.value = data
  } catch {
    pl.value = null
  } finally {
    loadingPL.value = false
  }
}

async function handleSave() {
  await saveCosto()
  // Recalcular P&L después de guardar costos
  if (!showCostoForm.value) await cargarPL()
}

onMounted(async () => {
  await cargarCostos()
  await cargarPL()
})
</script>

<style scoped>
.plc {
  background: #fff;
  border: 1px solid #d4e6d4;
  border-radius: 14px;
  overflow: hidden;
}

.plc__header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: .8rem 1rem;
  border-bottom: 1px solid #e8f0e9;
}
.plc__title { font-size: .85rem; font-weight: 700; color: #1a1a1a; }
.plc__btn-edit {
  display: flex; align-items: center; gap: .3rem;
  background: none; border: 1px solid #d4e6d4; color: #15803d;
  font-size: .75rem; font-weight: 600; padding: .25rem .65rem; border-radius: 6px;
  cursor: pointer; transition: background .15s;
}
.plc__btn-edit:hover { background: #f0fdf4; }

/* Formulario */
.plc__form { padding: .9rem 1rem; display: flex; flex-direction: column; gap: .6rem; }
.plc__form-row { display: flex; align-items: center; justify-content: space-between; gap: .5rem; }
.plc__form-label { font-size: .75rem; color: #60725d; font-weight: 500; flex-shrink: 0; }
.plc__form-input { width: 120px; padding: .3rem .5rem; border: 1px solid #d4e6d4; border-radius: 6px; font-size: .8rem; text-align: right; background: #f9fdfb; }
.plc__form-input:focus { outline: none; border-color: #15803d; }
.plc__form-total { font-size: .8rem; font-weight: 700; color: #1a3d2e; text-align: right; padding: .4rem .5rem; background: #f0fdf4; border-radius: 6px; }
.plc__gramos-block { display: flex; flex-direction: column; gap: .25rem; border-top: 1px solid #e8f0e9; padding-top: .5rem; }
.plc__gramos-ok       { font-size: .75rem; color: #15803d; font-weight: 600; }
.plc__gramos-pendiente { font-size: .75rem; color: #92400e; }
.plc__gramos-vacio    { font-size: .75rem; color: var(--c-slate-400); }
.plc__form-actions { display: flex; justify-content: flex-end; gap: .5rem; margin-top: .2rem; }
.plc__btn-primary { background: #1b5e20; color: #fff; border: none; padding: .45rem .9rem; border-radius: 8px; font-size: .82rem; font-weight: 600; cursor: pointer; }
.plc__btn-primary:disabled { opacity: .6; cursor: not-allowed; }
.plc__btn-ghost { background: transparent; color: #60725d; border: 1px solid #d4e6d4; padding: .45rem .9rem; border-radius: 8px; font-size: .82rem; cursor: pointer; }

/* Skeleton */
.plc__skel-wrap { padding: 1rem; display: flex; flex-direction: column; gap: .5rem; }
.plc__skel { height: 40px; background: var(--c-slate-100); border-radius: 8px; animation: plcPulse 1.4s ease-in-out infinite; }
.plc__skel--sm { height: 24px; width: 60%; }
@keyframes plcPulse { 0%,100%{opacity:1} 50%{opacity:.5} }

/* Margen banner */
.plc__margen-banner {
  display: flex; align-items: center; justify-content: space-between;
  padding: .75rem 1rem;
  border-bottom: 1px solid transparent;
}
.plc__margen-banner--pos { background: linear-gradient(135deg, #f0fdf4, #dcfce7); border-color: #bbf7d0; }
.plc__margen-banner--neg { background: linear-gradient(135deg, #fff5f5, #fee2e2); border-color: #fecaca; }
.plc__margen-main { display: flex; flex-direction: column; gap: .1rem; }
.plc__margen-label { font-size: .7rem; font-weight: 600; text-transform: uppercase; letter-spacing: .04em; color: var(--c-slate-500); }
.plc__margen-val { font-size: 1.25rem; font-weight: 800; color: var(--c-slate-900); letter-spacing: -.03em; }
.plc__margen-pct {
  font-size: 1.1rem; font-weight: 800; padding: .3rem .7rem; border-radius: 8px;
}
.plc__margen-banner--pos .plc__margen-pct { color: #15803d; background: rgba(21,128,61,.1); }
.plc__margen-banner--neg .plc__margen-pct { color: #dc2626; background: rgba(220,38,38,.1); }

/* Split costos/ingresos */
.plc__split { display: flex; padding: .75rem 1rem; gap: .75rem; border-bottom: 1px solid var(--c-slate-100); }
.plc__col { flex: 1; display: flex; flex-direction: column; gap: .25rem; }
.plc__col-label { font-size: .65rem; font-weight: 700; text-transform: uppercase; letter-spacing: .05em; color: var(--c-slate-400); }
.plc__col-val { font-size: 1rem; font-weight: 800; color: var(--c-slate-900); }
.plc__col-val--green { color: #15803d; }
.plc__col-detail { display: flex; flex-direction: column; gap: .1rem; margin-top: .15rem; }
.plc__col-detail span { font-size: .7rem; color: var(--c-slate-500); }
.plc__col-none { font-size: .72rem; color: var(--c-slate-300); font-style: italic; }
.plc__divider { width: 1px; background: var(--c-slate-200); flex-shrink: 0; }

/* Gramos por gramo */
.plc__gpg { display: flex; gap: .5rem; padding: .6rem 1rem; flex-wrap: wrap; }
.plc__gpg-item { display: flex; flex-direction: column; gap: .1rem; padding: .4rem .65rem; background: var(--c-slate-50); border-radius: 8px; flex: 1; min-width: 70px; }
.plc__gpg-item--green { background: #f0fdf4; }
.plc__gpg-label { font-size: .65rem; font-weight: 600; text-transform: uppercase; letter-spacing: .04em; color: var(--c-slate-400); }
.plc__gpg-val { font-size: .88rem; font-weight: 700; color: var(--c-slate-900); font-family: monospace; }
.plc__gpg-item--green .plc__gpg-val { color: #15803d; }

/* Hints */
.plc__hints { padding: .5rem 1rem .75rem; display: flex; flex-direction: column; gap: .2rem; }
.plc__hint { font-size: .72rem; color: var(--c-slate-400); }

/* Empty */
.plc__empty { padding: 1.2rem 1rem; text-align: center; font-size: .8rem; color: var(--c-slate-400); }
</style>
