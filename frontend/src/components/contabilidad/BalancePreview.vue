<script setup>
import { computed, ref, watch } from 'vue'

const props = defineProps({
  balanceActual: { type: Number, default: 0 },
  monto: { type: Number, default: null },
  tipo: { type: String, default: 'egreso' },
  mobile: { type: Boolean, default: false },
})

const fmt = (n) => new Intl.NumberFormat('es-AR', {
  style: 'currency', currency: 'ARS',
  minimumFractionDigits: 0, maximumFractionDigits: 0,
}).format(n || 0)

const balanceProyectado = computed(() => {
  if (!props.monto || props.monto <= 0) return null
  if (props.tipo === 'ingreso' || props.tipo === 'recupero_costo') {
    return props.balanceActual + props.monto
  }
  if (props.tipo === 'egreso') {
    return props.balanceActual - props.monto
  }
  return props.balanceActual // ajuste no cambia el total
})

const delta = computed(() => {
  if (balanceProyectado.value === null) return null
  return balanceProyectado.value - props.balanceActual
})

const colorActual = computed(() =>
  props.balanceActual >= 0 ? '#15803d' : '#dc2626'
)
const colorProyectado = computed(() => {
  if (balanceProyectado.value === null) return colorActual.value
  return balanceProyectado.value >= 0 ? '#15803d' : '#dc2626'
})
const bgProyectado = computed(() => {
  if (balanceProyectado.value === null) return props.balanceActual >= 0 ? 'rgba(21,128,61,.06)' : 'rgba(220,38,38,.06)'
  return balanceProyectado.value >= 0 ? 'rgba(21,128,61,.06)' : 'rgba(220,38,38,.06)'
})

// Animar cuando cambia el balance proyectado
const animKey = ref(0)
watch(() => balanceProyectado.value, () => { animKey.value++ })
</script>

<template>
  <!-- Version pill para mobile -->
  <div v-if="mobile" class="bp-pill">
    <span class="bp-pill-label">Balance mes:</span>
    <span class="bp-pill-val" :style="{ color: colorActual }">{{ fmt(balanceActual) }}</span>
    <template v-if="balanceProyectado !== null">
      <i class="bi bi-arrow-right bp-arrow"></i>
      <span class="bp-pill-val" :style="{ color: colorProyectado }">{{ fmt(balanceProyectado) }}</span>
    </template>
  </div>

  <!-- Version completa para desktop -->
  <div v-else class="bp-wrap" :style="{ background: bgProyectado }">
    <div class="bp-header">
      <i class="bi bi-graph-up-arrow bp-chart-icon" :style="{ color: colorActual }"></i>
      <span class="bp-header-label">Balance del mes</span>
    </div>

    <div class="bp-body">
      <!-- Balance actual -->
      <div class="bp-row">
        <span class="bp-row-label">Actual</span>
        <span class="bp-row-val" :style="{ color: colorActual }">{{ fmt(balanceActual) }}</span>
      </div>

      <!-- Proyección con animación fade -->
      <Transition name="bp-fade" mode="out-in">
        <div v-if="balanceProyectado !== null" :key="animKey" class="bp-projected">
          <div class="bp-divider">
            <i class="bi bi-arrow-down-short bp-div-icon" :style="{ color: tipo === 'egreso' ? '#dc2626' : '#15803d' }"></i>
            <span class="bp-div-label">
              <span v-if="tipo === 'egreso'" style="color:#dc2626">- {{ fmt(monto) }}</span>
              <span v-else-if="tipo === 'ingreso' || tipo === 'recupero_costo'" style="color:#15803d">+ {{ fmt(monto) }}</span>
              <span v-else style="color:#64748b">ajuste</span>
            </span>
          </div>
          <div class="bp-row bp-row--new">
            <span class="bp-row-label">Proyectado</span>
            <span class="bp-row-val bp-row-val--big" :style="{ color: colorProyectado }">
              {{ fmt(balanceProyectado) }}
            </span>
          </div>
          <div class="bp-delta" :style="{ color: delta >= 0 ? '#15803d' : '#dc2626' }">
            {{ delta >= 0 ? '+' : '' }}{{ fmt(delta) }}
          </div>
        </div>
        <div v-else class="bp-hint">
          Ingresá un monto para ver la proyección
        </div>
      </Transition>
    </div>
  </div>
</template>

<style scoped>
/* Pill (mobile) */
.bp-pill {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 6px 12px;
  background: var(--c-slate-50);
  border: 1px solid var(--c-slate-200);
  border-radius: 999px;
  font-size: 0.78rem;
  white-space: nowrap;
}
.bp-pill-label { color: var(--c-slate-400); font-weight: 500; }
.bp-pill-val { font-weight: 700; font-family: var(--font-mono, monospace); }
.bp-arrow { color: var(--c-slate-400); font-size: 0.9rem; }

/* Panel completo */
.bp-wrap {
  border-radius: 12px;
  border: 1px solid rgba(0,0,0,.06);
  padding: 1rem 1.1rem;
  transition: background 300ms ease;
}

.bp-header {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  margin-bottom: 0.75rem;
}
.bp-chart-icon { font-size: 0.9rem; }
.bp-header-label {
  font-size: 0.72rem;
  font-weight: 700;
  color: var(--c-slate-500);
  text-transform: uppercase;
  letter-spacing: 0.05em;
}

.bp-body { display: flex; flex-direction: column; gap: 0.5rem; }

.bp-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
}
.bp-row-label { font-size: 0.78rem; color: var(--c-slate-400); }
.bp-row-val {
  font-size: 1rem;
  font-weight: 700;
  font-family: var(--font-mono, monospace);
  letter-spacing: -0.02em;
}
.bp-row-val--big { font-size: 1.15rem; }
.bp-row--new { }

.bp-projected { display: flex; flex-direction: column; gap: 0.4rem; }

.bp-divider {
  display: flex;
  align-items: center;
  gap: 0.4rem;
  padding: 0.25rem 0;
  border-top: 1px dashed var(--c-slate-200);
  border-bottom: 1px dashed var(--c-slate-200);
  margin: 0.1rem 0;
}
.bp-div-icon { font-size: 1rem; }
.bp-div-label { font-size: 0.78rem; font-weight: 600; }

.bp-delta {
  font-size: 0.72rem;
  font-weight: 700;
  text-align: right;
  font-family: var(--font-mono, monospace);
}

.bp-hint {
  font-size: 0.75rem;
  color: var(--c-slate-300);
  font-style: italic;
  text-align: center;
  padding: 0.5rem 0;
}

/* Animación fade */
.bp-fade-enter-active { transition: opacity 200ms ease, transform 200ms ease; }
.bp-fade-leave-active { transition: opacity 150ms ease; }
.bp-fade-enter-from  { opacity: 0; transform: translateY(4px); }
.bp-fade-leave-to    { opacity: 0; }
</style>
