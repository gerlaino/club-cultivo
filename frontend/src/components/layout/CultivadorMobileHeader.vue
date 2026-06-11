<template>
  <header class="cmh">
    <div class="cmh__inner">
      <!-- Brand -->
      <RouterLink to="/" class="cmh__brand">
        <img src="/logo-ce-icono.png" class="cmh__brand-logo" alt="Cultivo Espacial" />
        <span class="cmh__brand-name">Cultivo Espacial</span>
      </RouterLink>

      <!-- Bell -->
      <button
        class="cmh__bell"
        :class="{ 'cmh__bell--alerta': notifCount > 0 }"
        @click="bellOpen = true"
        aria-label="Notificaciones"
      >
        <Bell :size="20" :stroke-width="1.75" />
        <span v-if="notifCount > 0" class="cmh__badge">{{ notifCount > 9 ? '9+' : notifCount }}</span>
      </button>
    </div>
    <!-- Banda de rol -->
    <div class="cmh__accent" />
  </header>

  <!-- Sheet de notificaciones -->
  <SheetBottom v-model="bellOpen" title="Alertas ambientales">
    <div v-if="!notifCount" class="cmh__notif-empty">
      <DsEmpty title="Sin alertas activas." />
    </div>
    <div v-else class="cmh__notif-list">
      <RouterLink
        v-for="a in alertasActivas.slice(0, 8)"
        :key="a.id"
        :to="a.sala_id ? { name: 'sala-ambiente', params: { id: a.sala_id } } : '/'"
        class="cmh__notif-item"
        @click="bellOpen = false"
      >
        <span class="cmh__notif-ico" :class="`cmh__notif-ico--${alertaSeveridad(a)}`">{{ TIPO_ICON[a.tipo] || '⚠️' }}</span>
        <div class="cmh__notif-body">
          <div class="cmh__notif-msg">{{ a.regla_nombre || a.tipo }}</div>
          <div class="cmh__notif-time">{{ formatTime(a.generada_at) }}</div>
        </div>
      </RouterLink>
    </div>
  </SheetBottom>
</template>

<script setup>
import { ref, computed } from 'vue'
import { useAmbienteStore } from '../../stores/ambiente.js'
import { useAlertasBell } from '../../composables/useAlertasBell.js'
import DsEmpty    from '../../design-system/components/EmptyState.vue'
import SheetBottom from '../cultivador/SheetBottom.vue'
import { Bell } from 'lucide-vue-next'

const ambStore = useAmbienteStore()
useAlertasBell()

const bellOpen      = ref(false)
const notifCount    = computed(() => ambStore.alertasCount)
const alertasActivas = computed(() => ambStore.alertasActivas)

const TIPO_ICON    = { temperatura: '🌡️', humedad: '💧', vpd: '🌫️', co2: '🌬️', ec: '⚡', ph: '🧪', ppfd: '💡' }
const TIPO_CRITICO = new Set(['temperatura', 'co2'])

function alertaSeveridad(a) {
  if (TIPO_CRITICO.has(a.tipo)) return 'rust'
  if (['humedad', 'vpd'].includes(a.tipo)) return 'amber'
  return 'sky'
}

function formatTime(ts) {
  if (!ts) return ''
  const diff = Date.now() - new Date(ts).getTime()
  const mins = Math.floor(diff / 60000)
  if (mins < 60)  return `hace ${mins}m`
  const hrs = Math.floor(mins / 60)
  if (hrs < 24)   return `hace ${hrs}h`
  return `hace ${Math.floor(hrs / 24)}d`
}
</script>

<style scoped>
.cmh {
  position: sticky;
  top: 0;
  z-index: 100;
  background: var(--c-paper);
  border-bottom: 1px solid var(--c-ink-300);
  flex-shrink: 0;
}
.cmh__inner {
  height: 56px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 var(--sp-4);
}
.cmh__brand {
  display: flex;
  align-items: center;
  gap: var(--sp-2);
  text-decoration: none;
}
.cmh__brand-logo { width: 26px; height: 26px; border-radius: 50%; object-fit: cover; flex-shrink: 0; }
.cmh__brand-name {
  font-family: var(--font-display);
  font-size: var(--fs-14);
  font-weight: 500;
  color: var(--c-ink-900);
}
.cmh__bell {
  position: relative;
  width: 40px;
  height: 40px;
  border-radius: var(--r-md);
  border: 1px solid var(--c-ink-300);
  background: transparent;
  color: var(--c-ink-500);
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  transition: background var(--t-fast), color var(--t-fast);
}
.cmh__bell:hover { background: var(--c-ink-100); color: var(--c-ink-900); }
.cmh__bell--alerta { border-color: #fca5a5; background: var(--c-rust-100); color: var(--c-rust-600); }
.cmh__badge {
  position: absolute;
  top: -4px; right: -4px;
  min-width: 18px; height: 18px;
  background: var(--c-rust-600); color: #fff;
  font-size: 10px; font-weight: 800;
  border-radius: var(--r-pill);
  display: flex; align-items: center; justify-content: center;
  padding: 0 3px;
  border: 2px solid var(--c-paper);
}
.cmh__accent {
  height: 4px;
  background: var(--c-role-cultivador);
}

/* Notif list in sheet */
.cmh__notif-empty { padding: var(--sp-4) 0; }
.cmh__notif-list  { display: flex; flex-direction: column; gap: 1px; }
.cmh__notif-item {
  display: flex; align-items: center; gap: var(--sp-3);
  padding: var(--sp-3) var(--sp-2);
  border-radius: var(--r-md);
  text-decoration: none; color: inherit;
  transition: background var(--t-fast);
  min-height: 56px;
}
.cmh__notif-item:hover { background: var(--c-leaf-50); }
.cmh__notif-ico { font-size: 20px; flex-shrink: 0; border-radius: var(--r-sm); padding: 2px; }
.cmh__notif-ico--rust  { background: var(--c-rust-100); }
.cmh__notif-ico--amber { background: var(--c-amber-100); }
.cmh__notif-ico--sky   { background: var(--c-sky-100); }
.cmh__notif-body { flex: 1; min-width: 0; }
.cmh__notif-msg  { font-size: var(--fs-14); font-weight: 600; color: var(--c-ink-900); }
.cmh__notif-time { font-family: var(--font-mono); font-size: var(--fs-12); color: var(--c-ink-500); margin-top: 2px; }

/* Hidden on desktop */
@media (min-width: 768px) { .cmh { display: none; } }
</style>
