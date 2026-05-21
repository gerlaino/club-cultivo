<script setup>
import { computed } from 'vue'
import { useRouter } from 'vue-router'
import { useAmbienteStore } from '../../stores/ambiente.js'
import { useAlertasBell } from '../../composables/useAlertasBell.js'
import { useAlertasInternas } from '../../composables/useAlertasInternas.js'

const router = useRouter()
const store  = useAmbienteStore()

useAlertasBell()
const internas = useAlertasInternas()

const countSensor   = computed(() => store.alertasCount)
const countInternas = computed(() => internas.count.value)
const totalCount    = computed(() => countSensor.value + countInternas.value)

const alertasSensor   = computed(() => store.alertasActivas.slice(0, 3))
const alertasInternas = computed(() => internas.noLeidas.value.slice(0, 5))

const SENSOR_ICON   = { temperatura: '🌡️', humedad: '💧', vpd: '🌫️', co2: '🌬️', ec: '⚡', ph: '🧪' }
const INTERNA_ICON  = {
  sin_registro_ambiental: '📋', cosecha_pendiente: '🌿', tarea_vencida_cultivo: '📌',
  saldo_cc_bajo: '💳', saldo_gramos_bajo: '⚖️', documento_vencido: '📄',
  reprocann_vencido: '📄', reprocann_por_vencer: '⏰', manicura_aprobacion_pendiente: '✂️',
  stock_bajo: '📦',
}
const SEV_CLASS = { error: 'nb__dot--error', warning: 'nb__dot--warning', info: 'nb__dot--info' }

function formatTime(ts) {
  if (!ts) return ''
  return new Date(ts).toLocaleString('es-AR', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' })
}
</script>

<template>
  <div class="nb dropdown">
    <button
      class="nb__trigger"
      type="button"
      data-bs-toggle="dropdown"
      data-bs-auto-close="outside"
      :class="{ 'nb__trigger--active': totalCount > 0 }"
    >
      <i class="bi bi-bell nb__icon"></i>
      <span v-if="totalCount > 0" class="nb__count">{{ totalCount > 9 ? '9+' : totalCount }}</span>
    </button>

    <div class="dropdown-menu dropdown-menu-end nb__menu shadow border-0">
      <div class="nb__menu-header">
        <span class="nb__menu-title">Notificaciones</span>
        <span v-if="totalCount > 0" class="nb__menu-count">{{ totalCount }} sin leer</span>
      </div>

      <div v-if="!totalCount" class="nb__empty">
        <i class="bi bi-check-circle text-success"></i> Sin notificaciones pendientes
      </div>

      <!-- Alertas internas del sistema -->
      <template v-if="alertasInternas.length">
        <div class="nb__section-label">Sistema</div>
        <div class="nb__list">
          <div
            v-for="a in alertasInternas"
            :key="`int-${a.id}`"
            class="nb__item"
            @click="internas.marcarLeida(a.id)"
          >
            <span class="nb__item-icon">{{ INTERNA_ICON[a.tipo] || '⚠️' }}</span>
            <div class="nb__item-body">
              <div class="nb__item-nombre">{{ a.mensaje }}</div>
              <div class="nb__item-time">{{ formatTime(a.created_at) }}</div>
            </div>
            <span class="nb__dot" :class="SEV_CLASS[a.severidad]"></span>
          </div>
        </div>
        <div v-if="internas.noLeidas.value.length > 5" class="nb__more">
          +{{ internas.noLeidas.value.length - 5 }} más
          <button class="nb__mark-all" @click.stop="internas.marcarTodas()">Marcar todas leídas</button>
        </div>
      </template>

      <!-- Alertas ambientales del sensor (live) -->
      <template v-if="alertasSensor.length">
        <div class="nb__section-label">Sensores</div>
        <div class="nb__list">
          <div v-for="a in alertasSensor" :key="`sen-${a.id}`" class="nb__item">
            <span class="nb__item-icon">{{ SENSOR_ICON[a.tipo] || '📡' }}</span>
            <div class="nb__item-body">
              <div class="nb__item-nombre">{{ a.regla_nombre || a.tipo }}</div>
              <div class="nb__item-time">{{ formatTime(a.generada_at) }}</div>
            </div>
            <RouterLink
              v-if="a.sala_id"
              :to="{ name: 'sala-ambiente', params: { id: a.sala_id } }"
              class="nb__item-link"
              title="Ver sala"
            >
              <i class="bi bi-arrow-right"></i>
            </RouterLink>
          </div>
        </div>
      </template>
    </div>
  </div>
</template>

<style scoped>
.nb { position: relative; }

.nb__trigger {
  position: relative;
  width: 36px; height: 36px;
  border-radius: 9px; border: 1px solid #e2e8f0;
  background: #f8fafc; color: #64748b;
  display: flex; align-items: center; justify-content: center;
  cursor: pointer; transition: all .15s; font-size: 1rem;
}
.nb__trigger:hover  { background: #f0fdf4; border-color: #d4e6d4; color: #1b5e20; }
.nb__trigger--active { border-color: #fca5a5; background: #fef2f2; color: #dc2626; }
.nb__trigger--active .nb__icon { animation: nb-ring .6s ease infinite; }

@keyframes nb-ring {
  0%, 100% { transform: rotate(0);     }
  20%       { transform: rotate(-15deg); }
  40%       { transform: rotate(10deg);  }
  60%       { transform: rotate(-8deg);  }
  80%       { transform: rotate(4deg);   }
}

.nb__count {
  position: absolute; top: -5px; right: -5px;
  min-width: 18px; height: 18px;
  background: #dc2626; color: #fff;
  font-size: .6rem; font-weight: 800;
  border-radius: 999px; display: flex;
  align-items: center; justify-content: center;
  padding: 0 3px; border: 2px solid #fff;
}

.nb__menu {
  min-width: 300px; border-radius: 12px !important;
  padding: 0 !important; overflow: hidden;
  margin-top: 6px !important;
}

.nb__menu-header {
  display: flex; justify-content: space-between; align-items: center;
  padding: .75rem 1rem; border-bottom: 1px solid #f1f5f9;
  background: #f8fafc;
}
.nb__menu-title { font-size: .8rem; font-weight: 700; color: #1a1a1a; }
.nb__menu-count { font-size: .72rem; font-weight: 700; color: #dc2626; }

.nb__empty { padding: 1rem 1rem; font-size: .82rem; color: #64748b; display: flex; align-items: center; gap: .5rem; }

.nb__list { max-height: 280px; overflow-y: auto; }
.nb__item {
  display: flex; align-items: center; gap: .65rem;
  padding: .65rem 1rem; border-bottom: 1px solid #f1f5f9;
  transition: background .12s;
}
.nb__item:hover { background: #fef2f2; }
.nb__item:last-child { border-bottom: none; }
.nb__item-icon { font-size: 1.1rem; flex-shrink: 0; }
.nb__item-body { flex: 1; min-width: 0; }
.nb__item-nombre { font-size: .82rem; font-weight: 600; color: #1a1a1a; }
.nb__item-time { font-size: .7rem; color: #94a3b8; }
.nb__item-link {
  width: 26px; height: 26px; border-radius: 6px;
  background: #f1f5f9; color: #64748b;
  display: flex; align-items: center; justify-content: center;
  font-size: .75rem; text-decoration: none; flex-shrink: 0;
  transition: all .12s;
}
.nb__item-link:hover { background: #e8f5e9; color: #1b5e20; }

.nb__more {
  padding: .5rem 1rem; font-size: .75rem; color: #94a3b8;
  text-align: center; border-top: 1px solid #f1f5f9;
  display: flex; align-items: center; justify-content: space-between; gap: .5rem;
}

.nb__section-label {
  padding: .35rem 1rem; font-size: .68rem; font-weight: 700;
  color: #94a3b8; text-transform: uppercase; letter-spacing: .05em;
  background: #f8fafc; border-bottom: 1px solid #f1f5f9;
}

.nb__dot {
  width: 8px; height: 8px; border-radius: 50%; flex-shrink: 0;
}
.nb__dot--error   { background: #dc2626; }
.nb__dot--warning { background: #f59e0b; }
.nb__dot--info    { background: #3b82f6; }

.nb__mark-all {
  font-size: .68rem; color: #3b82f6; background: none; border: none;
  cursor: pointer; padding: 0; white-space: nowrap;
}
.nb__mark-all:hover { text-decoration: underline; }
</style>
