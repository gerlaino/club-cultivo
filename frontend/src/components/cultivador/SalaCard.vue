<template>
  <div
    class="sc"
    :class="{
      'sc--alerta-critica':    alertaMax === 'critica',
      'sc--alerta-advertencia': alertaMax === 'advertencia',
    }"
  >
    <!-- Header -->
    <div class="sc__header">
      <div class="sc__header-left">
        <div class="sc__nombre-row">
          <span class="sc__nombre">{{ sala.nombre }}</span>
          <AlertTriangle
            v-if="alertaMax"
            :size="14"
            :stroke-width="1.75"
            class="sc__alerta-ico"
            :class="`sc__alerta-ico--${alertaMax}`"
          />
        </div>
        <div class="sc__meta">{{ sala.sede?.nombre || '—' }} · <span class="sc__ultima">Última lect.: {{ ultimaLecturaLabel }}</span></div>
      </div>
      <DsBadge :variant="faseBadgeVariant" size="sm">{{ faseBadgeLabel }}</DsBadge>
    </div>

    <!-- Body -->
    <div class="sc__body">
      <!-- Stats -->
      <div class="sc__stats">
        <div class="sc__stat">
          <span class="sc__stat-val">{{ sala.lotes_activos || 0 }}</span>
          <span class="sc__stat-lbl">LOTES</span>
        </div>
        <div class="sc__stat">
          <span class="sc__stat-val">{{ sala.plantas_totales || 0 }}</span>
          <span class="sc__stat-lbl">PLANTAS</span>
        </div>
      </div>

      <!-- Última lectura ambiental -->
      <div v-if="ultimaLectura" class="sc__lectura">
        <Thermometer :size="12" :stroke-width="1.75" class="sc__lectura-ico" />
        <span>{{ ultimaLectura }}</span>
      </div>
    </div>

    <!-- Footer -->
    <div class="sc__footer">
      <RouterLink :to="{ name: 'sala-detail', params: { id: sala.id } }" class="sc__btn sc__btn--ghost">
        Ver detalle
        <ChevronRight :size="14" :stroke-width="1.75" />
      </RouterLink>
      <button class="sc__btn sc__btn--secondary" @click.prevent="$emit('registrar-lectura', sala)">
        <Gauge :size="14" :stroke-width="1.75" />
        Registrar
      </button>
    </div>
  </div>
</template>

<script setup>
import { computed } from 'vue'
import { AlertTriangle, ChevronRight, Gauge, Thermometer } from 'lucide-vue-next'
import DsBadge from '../../design-system/components/Badge.vue'

const props = defineProps({
  sala:    { type: Object, required: true },
  alertas: { type: Array,  default: () => [] }, // alertas activas de esta sala
  lotes:   { type: Array,  default: () => [] }, // lotes de esta sala
})
defineEmits(['registrar-lectura'])

// Mayor severidad de alerta activa de esta sala
const alertaMax = computed(() => {
  if (!props.alertas.length) return null
  const activas = props.alertas.filter(a => a.estado === 'activa' && a.sala_id === props.sala.id)
  if (!activas.length) return null
  const critica = ['temperatura', 'co2'].some(t => activas.find(a => a.tipo === t))
  return critica ? 'critica' : 'advertencia'
})

// Fase dominante según lotes
const FASE_BADGE = {
  vegetativo:   { variant: 'leaf', label: 'Vegetativo' },
  floracion:    { variant: 'gold', label: 'Floración' },
  secado:       { variant: 'sky',  label: 'Secado' },
  cosechado:    { variant: 'ink',  label: 'Cosechado' },
  planificacion:{ variant: 'ink',  label: 'Planificación' },
  finalizado:   { variant: 'ink',  label: 'Finalizado' },
}
const FASE_PRIORIDAD = ['floracion', 'vegetativo', 'secado', 'cosechado', 'planificacion', 'finalizado']

const faseDominante = computed(() => {
  if (!props.lotes.length) return null
  for (const fase of FASE_PRIORIDAD) {
    if (props.lotes.some(l => l.estado === fase)) return fase
  }
  return props.lotes[0]?.estado || null
})

const faseBadgeVariant = computed(() => faseDominante.value ? (FASE_BADGE[faseDominante.value]?.variant || 'ink') : (props.sala.state === 'activa' ? 'leaf' : 'ink'))
const faseBadgeLabel   = computed(() => faseDominante.value ? (FASE_BADGE[faseDominante.value]?.label || faseDominante.value) : (props.sala.state === 'activa' ? 'Activa' : props.sala.state || '—'))

// Última lectura placeholder — el dato real vendrá del store cuando esté disponible
const ultimaLecturaLabel = computed(() => '—')
const ultimaLectura      = computed(() => null)
</script>

<style scoped>
.sc {
  background: var(--c-paper);
  border: 1px solid var(--c-ink-300);
  border-radius: var(--r-xl);
  overflow: hidden;
  box-shadow: var(--sh-1);
  transition: box-shadow var(--t-base), transform var(--t-base);
  display: flex;
  flex-direction: column;
}
@media (hover: hover) {
  .sc:hover {
    box-shadow: var(--sh-3);
    transform: translateY(-2px);
  }
}

/* Borde superior según alerta */
.sc--alerta-critica    { border-top: 3px solid var(--c-rust-600); }
.sc--alerta-advertencia { border-top: 3px solid var(--c-amber-500); }

/* Header */
.sc__header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: var(--sp-3);
  padding: var(--sp-4) var(--sp-5);
  background: var(--c-leaf-50);
  border-bottom: 1px solid var(--c-ink-300);
}
.sc__header-left { flex: 1; min-width: 0; }
.sc__nombre-row {
  display: flex;
  align-items: center;
  gap: var(--sp-2);
  margin-bottom: 2px;
}
.sc__nombre {
  font-family: var(--font-display);
  font-size: var(--fs-16);
  font-weight: 500;
  color: var(--c-ink-900);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.sc__alerta-ico { flex-shrink: 0; }
.sc__alerta-ico--critica    { color: var(--c-rust-600); }
.sc__alerta-ico--advertencia { color: var(--c-amber-500); }
.sc__meta {
  font-size: var(--fs-12);
  color: var(--c-ink-500);
}
.sc__ultima { font-family: var(--font-mono); }

/* Body */
.sc__body { padding: var(--sp-4) var(--sp-5); flex: 1; }

.sc__stats {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: var(--sp-3) var(--sp-4);
  margin-bottom: var(--sp-3);
}
.sc__stat { display: flex; flex-direction: column; gap: 2px; }
.sc__stat-val {
  font-family: var(--font-mono);
  font-size: var(--fs-20);
  font-weight: 600;
  color: var(--c-ink-900);
  line-height: 1;
}
.sc__stat-lbl {
  font-size: 11px;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  color: var(--c-ink-500);
}

.sc__lectura {
  display: flex;
  align-items: center;
  gap: var(--sp-2);
  font-family: var(--font-mono);
  font-size: 11px;
  color: var(--c-ink-700);
  background: var(--c-ink-100);
  border-radius: var(--r-sm);
  padding: var(--sp-1) var(--sp-2);
}
.sc__lectura-ico { color: var(--c-ink-500); flex-shrink: 0; }

/* Footer */
.sc__footer {
  display: flex;
  gap: var(--sp-2);
  padding: var(--sp-3) var(--sp-5);
  border-top: 1px solid var(--c-ink-100);
}
.sc__btn {
  display: inline-flex;
  align-items: center;
  gap: var(--sp-1);
  height: 48px;
  padding: 0 var(--sp-3);
  border-radius: var(--r-md);
  font-size: var(--fs-13);
  font-weight: 500;
  cursor: pointer;
  text-decoration: none;
  transition: background var(--t-fast), color var(--t-fast);
  white-space: nowrap;
}
.sc__btn--ghost {
  flex: 1;
  justify-content: center;
  background: transparent;
  border: 1px solid var(--c-ink-300);
  color: var(--c-ink-700);
}
.sc__btn--ghost:hover { background: var(--c-ink-100); color: var(--c-ink-900); }

.sc__btn--secondary {
  background: var(--c-leaf-50);
  border: 1.5px solid var(--c-role-cultivador);
  color: var(--c-role-cultivador);
  font-weight: 600;
}
.sc__btn--secondary:hover { background: var(--c-role-cultivador); color: #fff; }
</style>
