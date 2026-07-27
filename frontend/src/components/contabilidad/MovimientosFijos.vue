<script setup>
// Los movimientos que se repiten todos los meses (alquiler, impuestos, servicios, sueldos).
// No hay tabla de "gastos fijos": se detectan del historial (`movimientos_contables#recurrentes`) y
// se ofrecen prellenados para CONFIRMAR uno por uno. Con inflación el monto cambia casi siempre,
// así que generarlos solos sería cargar datos falsos — el admin ajusta el número y tilda.
import { ref, computed, onMounted } from 'vue'
import { listMovimientosRecurrentes } from '../../lib/api.js'
import { fmtARS, parseMonto, fmtMiles } from './movimientoFlows.js'
import DsSpinner from '../../design-system/components/Spinner.vue'
import EmptyState from '../ui/EmptyState.vue'

const props = defineProps({
  mes: { type: String, default: '' }, // YYYY-MM; vacío = mes en curso
})
const emit = defineEmits(['cargar', 'volver'])

const loading = ref(true)
const filas   = ref([])   // { ...fijo, sel, montoTexto, monto, estado }

onMounted(async () => {
  try {
    const { data } = await listMovimientosRecurrentes(props.mes ? { mes: props.mes } : {})
    filas.value = (data?.fijos || []).map(f => ({
      ...f,
      sel: !f.ya_cargado,                       // lo que falta viene tildado
      montoTexto: fmtMiles(f.monto_sugerido),
      monto: f.monto_sugerido,
      estado: null,                             // null | 'ok' | 'error'
    }))
  } catch {
    filas.value = []
  } finally {
    loading.value = false
  }
})

const pendientes   = computed(() => filas.value.filter(f => !f.ya_cargado))
const seleccionadas = computed(() => filas.value.filter(f => f.sel && !f.ya_cargado))
const totalSel = computed(() => seleccionadas.value.reduce((a, f) => {
  return a + (f.tipo === 'egreso' ? -(f.monto || 0) : (f.monto || 0))
}, 0))

function onMonto(fila, valor) {
  const { texto, monto } = parseMonto(valor)
  fila.montoTexto = texto
  fila.monto = monto
}

function variacion(f) {
  if (!f.monto || !f.monto_sugerido) return null
  const pct = ((f.monto - f.monto_sugerido) / f.monto_sugerido) * 100
  return Math.abs(pct) < 0.5 ? null : pct
}

function cargar() {
  emit('cargar', seleccionadas.value.map(f => ({
    fila: f,
    payload: {
      tipo: f.tipo,
      categoria: f.categoria,
      categoria_contable_id: f.categoria_contable_id,
      unidad_negocio_id: f.unidad_negocio_id,
      sede_id: f.sede_id,
      descripcion: f.descripcion,
      monto_ars: f.monto,
      fecha: f.fecha_sugerida,
      proveedor: f.proveedor,
      medio_pago: f.medio_pago || 'efectivo',
      comprobante_tipo: f.comprobante_tipo || 'sin_comprobante',
      pagado: true,
    },
  })))
}

/** El modal marca el resultado de cada fila (la carga es de a una, con feedback por fila). */
function marcar(id, estado) {
  const f = filas.value.find(x => x.id === id)
  if (!f) return
  f.estado = estado
  if (estado === 'ok') { f.ya_cargado = true; f.sel = false }
}
defineExpose({ marcar })
</script>

<template>
  <div class="fij">
    <div v-if="loading" class="fij__load"><DsSpinner :size="32" /></div>

    <EmptyState
      v-else-if="!filas.length"
      icon="bi-arrow-repeat"
      title="Todavía no hay fijos detectados"
      message="Cuando un mismo gasto se repita en dos meses (alquiler, impuestos, servicios), aparece acá para cargarlo de un toque."
      compact
    />

    <template v-else>
      <p class="fij__intro">
        Se repitieron en los últimos meses. Revisá el monto —con la inflación casi nunca es el mismo—
        y cargá los que correspondan.
      </p>

      <ul class="fij__list">
        <li v-for="f in filas" :key="f.id" class="fij__row" :class="{ 'fij__row--done': f.ya_cargado }">
          <input
            type="checkbox" class="fij__cb" v-model="f.sel"
            :disabled="f.ya_cargado" :aria-label="`Cargar ${f.descripcion}`"
          />

          <div class="fij__main">
            <div class="fij__desc">
              {{ f.descripcion }}
              <span v-if="f.ya_cargado" class="fij__badge fij__badge--ok">ya cargado</span>
              <span v-else-if="f.estado === 'error'" class="fij__badge fij__badge--err">no se pudo</span>
            </div>
            <div class="fij__meta">
              <span>{{ f.categoria_label }}</span>
              <span v-if="f.sede_nombre">· {{ f.sede_nombre }}</span>
              <span>· {{ f.veces }} meses</span>
              <span v-if="f.proveedor">· {{ f.proveedor }}</span>
            </div>
          </div>

          <div class="fij__monto">
            <span class="fij__signo" :class="f.tipo === 'egreso' ? 'fij__signo--out' : 'fij__signo--in'">
              {{ f.tipo === 'egreso' ? '−' : '+' }}$
            </span>
            <input
              type="text" inputmode="decimal" class="fij__inp"
              :value="f.montoTexto" :disabled="f.ya_cargado"
              @input="onMonto(f, $event.target.value)"
            />
          </div>

          <div class="fij__ref">
            <span class="fij__ref-prev">antes {{ fmtARS(f.monto_sugerido) }}</span>
            <span v-if="variacion(f) !== null" class="fij__ref-var"
                  :class="variacion(f) > 0 ? 'fij__ref-var--up' : 'fij__ref-var--down'">
              {{ variacion(f) > 0 ? '+' : '' }}{{ variacion(f).toFixed(0) }}%
            </span>
          </div>
        </li>
      </ul>

      <div v-if="!pendientes.length" class="fij__todo">
        <i class="bi bi-check2-circle"></i> Los fijos de este mes ya están cargados.
      </div>
    </template>

    <div class="fij__bar">
      <button type="button" class="fij__back" @click="emit('volver')">
        <i class="bi bi-arrow-left"></i> Volver
      </button>
      <span v-if="seleccionadas.length" class="fij__total">
        {{ seleccionadas.length }} seleccionado{{ seleccionadas.length === 1 ? '' : 's' }} ·
        impacto {{ fmtARS(totalSel) }}
      </span>
      <button type="button" class="fij__go" :disabled="!seleccionadas.length" @click="cargar">
        Cargar {{ seleccionadas.length || '' }}
      </button>
    </div>
  </div>
</template>

<style scoped>
.fij { display: flex; flex-direction: column; min-height: 0; }
.fij__load { display: flex; justify-content: center; padding: var(--sp-10); }
.fij__intro { margin: 0 0 var(--sp-3); font-size: var(--fs-13); color: var(--c-ink-500); line-height: var(--lh-base); }

.fij__list { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; }
.fij__row {
  display: grid; grid-template-columns: auto 1fr auto auto;
  align-items: center; gap: var(--sp-3);
  padding: var(--sp-3) var(--sp-1); border-bottom: 1px solid var(--c-ink-100);
}
.fij__row:last-child { border-bottom: none; }
.fij__row--done { opacity: .55; }
.fij__cb { width: 16px; height: 16px; accent-color: var(--c-leaf-800); cursor: pointer; }
.fij__main { min-width: 0; }
.fij__desc { font-size: var(--fs-14); font-weight: 600; color: var(--c-ink-900); display: flex; align-items: center; gap: var(--sp-2); flex-wrap: wrap; }
.fij__meta { font-size: var(--fs-12); color: var(--c-ink-500); margin-top: 2px; }
.fij__badge { font-size: var(--fs-12); font-weight: 600; padding: 1px 7px; border-radius: var(--r-pill); }
.fij__badge--ok  { background: var(--c-leaf-100); color: var(--c-leaf-800); }
.fij__badge--err { background: var(--c-rust-100); color: var(--c-rust-600); }

.fij__monto { display: flex; align-items: center; gap: 4px; }
.fij__signo { font-size: var(--fs-14); font-weight: 700; }
.fij__signo--out { color: var(--c-rust-600); }
.fij__signo--in  { color: var(--c-leaf-600); }
.fij__inp {
  width: 120px; height: 36px; padding: 0 8px; text-align: right;
  border: 1.5px solid var(--c-ink-300); border-radius: var(--r-md);
  font-family: var(--font-mono); font-size: var(--fs-14); color: var(--c-ink-900);
  outline: none; transition: border-color var(--t-fast);
}
.fij__inp:focus { border-color: var(--c-leaf-600); }
.fij__inp:disabled { background: var(--c-ink-100); color: var(--c-ink-500); }

.fij__ref { display: flex; flex-direction: column; align-items: flex-end; min-width: 92px; }
.fij__ref-prev { font-size: var(--fs-12); color: var(--c-ink-500); white-space: nowrap; }
.fij__ref-var { font-size: var(--fs-12); font-weight: 700; }
.fij__ref-var--up   { color: var(--c-rust-600); }
.fij__ref-var--down { color: var(--c-leaf-600); }

.fij__todo { margin-top: var(--sp-3); font-size: var(--fs-13); color: var(--c-leaf-700); display: flex; align-items: center; gap: 6px; }

.fij__bar { display: flex; align-items: center; gap: var(--sp-3); margin-top: var(--sp-5); }
.fij__back { background: none; border: none; color: var(--c-ink-500); font-size: var(--fs-13); font-weight: 600; cursor: pointer; display: inline-flex; align-items: center; gap: 4px; }
.fij__back:hover { color: var(--c-ink-900); }
.fij__total { margin-left: auto; font-size: var(--fs-13); color: var(--c-ink-500); }
.fij__go {
  background: var(--c-leaf-800); color: #fff; border: none;
  padding: 9px 18px; border-radius: var(--r-md);
  font-size: var(--fs-14); font-weight: 600; cursor: pointer; transition: background var(--t-fast);
}
.fij__go:hover:not(:disabled) { background: var(--c-leaf-900); }
.fij__go:disabled { background: var(--c-ink-300); cursor: default; }

@media (max-width: 620px) {
  .fij__row { grid-template-columns: auto 1fr; }
  .fij__monto, .fij__ref { grid-column: 2; align-items: flex-start; }
  .fij__ref { min-width: 0; flex-direction: row; gap: var(--sp-2); }
}
</style>
