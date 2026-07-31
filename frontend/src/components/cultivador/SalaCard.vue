<template>
  <div
    class="sc"
    :class="[
      faseClase,
      {
        'sc--alerta-critica':    alertaMax === 'critica',
        'sc--alerta-advertencia': alertaMax === 'advertencia',
      }
    ]"
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
      <div v-if="club.data?.features?.ia_voz" class="sc__av-wrap" title="Registrar por voz (IA)">
        <AsistenteVoz :mini="true" :contexto="contextoSala" />
      </div>
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
import AsistenteVoz from '../AsistenteVoz.vue'
import { useClubStore } from '../../stores/club'

const club = useClubStore()

const props = defineProps({
  sala:    { type: Object, required: true },
  alertas: { type: Array,  default: () => [] },
  lotes:   { type: Array,  default: () => [] },
})
defineEmits(['registrar-lectura'])

const contextoSala = computed(() => ({
  tipo:       'sala',
  sala_id:    props.sala.id,
  sala_nombre: props.sala.nombre,
  plantas_count: props.sala.plantas_totales || 0,
}))

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
  enraizado:   { variant: 'sky',  label: 'Enraizado' },
  vegetativo:   { variant: 'leaf', label: 'Vegetativo' },
  floracion:    { variant: 'gold', label: 'Floración' },
  cosecha:      { variant: 'ink',  label: 'Cosecha' },
  en_manicura:  { variant: 'ink',  label: 'En manicura' },
  curado:       { variant: 'ink',  label: 'Curado' },
  finalizado:   { variant: 'ink',  label: 'Finalizado' },
}
const FASE_PRIORIDAD = ['floracion', 'vegetativo', 'enraizado', 'cosecha', 'en_manicura', 'curado', 'finalizado']

const faseDominante = computed(() => {
  if (!props.lotes.length) return null
  for (const fase of FASE_PRIORIDAD) {
    if (props.lotes.some(l => l.estado === fase)) return fase
  }
  return props.lotes[0]?.estado || null
})

const faseBadgeVariant = computed(() => faseDominante.value ? (FASE_BADGE[faseDominante.value]?.variant || 'ink') : (props.sala.state === 'activa' ? 'leaf' : 'ink'))
const faseBadgeLabel   = computed(() => faseDominante.value ? (FASE_BADGE[faseDominante.value]?.label || faseDominante.value) : (props.sala.state === 'activa' ? 'Activa' : props.sala.state || '—'))

const FASE_CLASE = { floracion: 'sc--floracion', vegetativo: 'sc--vegetativo', enraizado: 'sc--germinacion', cosecha: 'sc--cosecha' }
const faseClase = computed(() => FASE_CLASE[faseDominante.value] || 'sc--default')

// Última lectura placeholder — el dato real vendrá del store cuando esté disponible
const ultimaLecturaLabel = computed(() => '—')
const ultimaLectura      = computed(() => null)
</script>

<style scoped>
.sc {
  background: #fff;
  border: 1px solid #e5e7eb;
  border-left-width: 4px;
  border-radius: 12px;
  overflow: hidden;
  box-shadow: 0 1px 4px rgba(0,0,0,.06);
  transition: box-shadow .15s, transform .15s;
  display: flex;
  flex-direction: column;
}
@media (hover: hover) {
  .sc:hover {
    box-shadow: 0 6px 20px rgba(0,0,0,.08);
    transform: translateY(-2px);
  }
}

.sc--floracion   { border-left-color: #f59e0b; }
.sc--vegetativo  { border-left-color: #3b82f6; }
.sc--germinacion { border-left-color: #10b981; }
.sc--cosecha     { border-left-color: #ef4444; }
.sc--default     { border-left-color: #6b7280; }

.sc--alerta-critica    { border-top: 3px solid #dc2626; }
.sc--alerta-advertencia { border-top: 3px solid #f59e0b; }

/* Header */
.sc__header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: .75rem;
  padding: .875rem 1rem;
  background: transparent;
  border-bottom: 1px solid #e5e7eb;
}
.sc__header-left { flex: 1; min-width: 0; }
.sc__nombre-row { display: flex; align-items: center; gap: .4rem; margin-bottom: 2px; }
.sc__nombre {
  font-size: 1rem;
  font-weight: 700;
  color: #0f2611;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.sc__alerta-ico { flex-shrink: 0; }
.sc__alerta-ico--critica    { color: #dc2626; }
.sc__alerta-ico--advertencia { color: #f59e0b; }
.sc__meta { font-size: .75rem; color: #60725d; }

/* Body */
.sc__body { padding: .875rem 1rem; flex: 1; }

.sc__stats {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: .5rem 1rem;
  margin-bottom: .75rem;
}
.sc__stat { display: flex; flex-direction: column; gap: 2px; }
.sc__stat-val {
  font-size: 1.25rem;
  font-weight: 700;
  color: #0f2611;
  line-height: 1;
  font-variant-numeric: tabular-nums;
}
.sc__stat-lbl {
  font-size: .68rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: .05em;
  color: #60725d;
}

.sc__lectura {
  display: flex;
  align-items: center;
  gap: .35rem;
  font-size: .72rem;
  color: #0f2611;
  background: #f0f4f0;
  border-radius: 6px;
  padding: .2rem .5rem;
}
.sc__lectura-ico { color: #60725d; flex-shrink: 0; }

/* Footer */
.sc__footer {
  display: flex;
  gap: .4rem;
  padding: .65rem 1rem;
  border-top: 1px solid #f0f4f0;
}
.sc__btn {
  display: inline-flex;
  align-items: center;
  gap: .35rem;
  height: 36px;
  padding: 0 .75rem;
  border-radius: 8px;
  font-size: .8rem;
  font-weight: 600;
  cursor: pointer;
  text-decoration: none;
  transition: background .15s, color .15s;
  white-space: nowrap;
}
.sc__btn--ghost {
  flex: 1;
  justify-content: center;
  background: transparent;
  border: 1px solid #e8f0e9;
  color: #60725d;
}
.sc__btn--ghost:hover { background: #f0f4f0; color: #0f2611; }

.sc__btn--secondary {
  background: #fff;
  border: 1px solid #16a34a;
  color: #16a34a;
}
.sc__btn--secondary:hover { background: #16a34a; color: #fff; }

.sc__av-wrap { display: flex; align-items: center; }
.sc__av-wrap :deep(.av__trigger--mini) {
  width: 36px;
  height: 36px;
  box-shadow: 0 2px 6px rgba(27,94,32,.3);
}
</style>
