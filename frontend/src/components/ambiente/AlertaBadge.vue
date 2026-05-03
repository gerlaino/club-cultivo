<script setup>
import { computed } from 'vue'

const props = defineProps({
  alerta: { type: Object, required: true },
})

const emit = defineEmits(['resolver', 'reconocer'])

const estadoClass = computed(() => ({
  activa:     'ab__badge--red',
  reconocida: 'ab__badge--yellow',
  resuelta:   'ab__badge--green',
}[props.alerta.estado] || 'ab__badge--gray'))

const TIPO_ICON = {
  temperatura: '🌡️', humedad: '💧', vpd: '🌫️', co2: '🌬️',
  ppfd: '💡', ec: '⚡', ph: '🧪',
}

function formatTime(ts) {
  if (!ts) return ''
  return new Date(ts).toLocaleString('es-AR', {
    day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit',
  })
}
</script>

<template>
  <div class="ab">
    <div class="ab__icon">{{ TIPO_ICON[alerta.tipo] || '⚠️' }}</div>
    <div class="ab__body">
      <div class="ab__top">
        <span class="ab__nombre">{{ alerta.regla_nombre || alerta.tipo }}</span>
        <span class="ab__badge" :class="estadoClass">{{ alerta.estado }}</span>
      </div>
      <div class="ab__meta">
        <span v-if="alerta.valor != null">
          Valor: <strong>{{ alerta.valor }}</strong>
        </span>
        <span v-if="alerta.generada_at" class="ab__time">{{ formatTime(alerta.generada_at) }}</span>
      </div>
    </div>
    <div class="ab__actions" v-if="alerta.estado === 'activa'">
      <button class="ab__btn ab__btn--outline" @click="emit('reconocer', alerta.id)" title="Reconocer">
        <i class="bi bi-eye"></i>
      </button>
      <button class="ab__btn ab__btn--primary" @click="emit('resolver', alerta.id)" title="Resolver">
        <i class="bi bi-check2"></i>
      </button>
    </div>
  </div>
</template>

<style scoped>
.ab {
  display: flex; align-items: flex-start; gap: .75rem;
  padding: .75rem 1rem; border-radius: 10px;
  background: #fff; border: 1px solid #fee2e2;
  transition: box-shadow .15s;
}
.ab:hover { box-shadow: 0 2px 8px rgba(220,38,38,.08); }

.ab__icon { font-size: 1.3rem; flex-shrink: 0; margin-top: .1rem; }
.ab__body { flex: 1; min-width: 0; }
.ab__top { display: flex; align-items: center; gap: .5rem; flex-wrap: wrap; margin-bottom: .2rem; }
.ab__nombre { font-size: .85rem; font-weight: 700; color: #1a1a1a; }
.ab__badge {
  font-size: .62rem; font-weight: 800; text-transform: uppercase;
  letter-spacing: .06em; padding: .15em .55em; border-radius: 6px;
}
.ab__badge--red    { background: #fef2f2; color: #dc2626; }
.ab__badge--yellow { background: #fffbeb; color: #b45309; }
.ab__badge--green  { background: #f0fdf4; color: #15803d; }
.ab__badge--gray   { background: #f1f5f9; color: #64748b; }
.ab__meta { display: flex; gap: .75rem; flex-wrap: wrap; font-size: .75rem; color: #64748b; }
.ab__time { margin-left: auto; }
.ab__actions { display: flex; gap: .4rem; flex-shrink: 0; }
.ab__btn {
  display: flex; align-items: center; justify-content: center;
  width: 30px; height: 30px; border-radius: 7px; border: none; cursor: pointer;
  font-size: .85rem; transition: all .15s;
}
.ab__btn--outline { background: #f1f5f9; color: #64748b; }
.ab__btn--outline:hover { background: #e2e8f0; }
.ab__btn--primary { background: #dcfce7; color: #15803d; }
.ab__btn--primary:hover { background: #bbf7d0; }
</style>
