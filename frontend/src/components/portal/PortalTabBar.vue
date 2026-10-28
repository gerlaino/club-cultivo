<template>
  <nav class="ptb" aria-label="Secciones" data-testid="portal-tabbar">
    <RouterLink v-for="t in tabs" :key="t.to" :to="t.to" class="ptb__tab" :class="{ 'ptb__tab--on': activa(t) }"
                :aria-current="activa(t) ? 'page' : undefined">
      <span class="ptb__icono">
        <component :is="t.icono" :size="22" :stroke-width="1.9" aria-hidden="true" />
        <span v-if="t.chat && sinLeer" class="ptb__badge">{{ sinLeer }}</span>
      </span>
      {{ t.txt }}
    </RouterLink>
  </nav>
</template>

<script setup>
// La barra de abajo del portal en el teléfono (Germán, 28-oct-2026: el rediseño del paciente).
// Cuatro cosas, las que el paciente viene a hacer: ver si puede retirar (Inicio), reservar, ver lo
// que retiró y escribirle a su organización. Reservar y Mensajes aparecen sólo si la organización
// los atiende (`/portal/club`); lo demás (Mi salud, Mi organización, Mis datos) vive en el menú de
// arriba.
import { computed } from 'vue'
import { RouterLink, useRoute } from 'vue-router'
import { storeToRefs } from 'pinia'
import { Home, CalendarCheck, ClipboardList, MessageCircle } from 'lucide-vue-next'
import { usePortalClubStore } from '@/stores/portalClub'
import { usePortalChatStore } from '@/stores/portalChat'

const route = useRoute()
const { club } = storeToRefs(usePortalClubStore())
const { sinLeer } = storeToRefs(usePortalChatStore())

const tabs = computed(() => [
  { to: '/portal', txt: 'Inicio', icono: Home, exacta: true },
  ...(club.value?.reservar === false ? [] : [{ to: '/portal/reservar', txt: 'Reservar', icono: CalendarCheck }]),
  { to: '/portal/historial', txt: 'Dispensas', icono: ClipboardList, tambien: ['/portal/dispensas'] },
  ...(club.value?.mensajes === false ? [] : [{ to: '/portal/mensajes', txt: 'Mensajes', icono: MessageCircle, chat: true }]),
])

function activa(t) {
  if (t.exacta) return route.path === t.to || route.path === `${t.to}/`
  return [t.to, ...(t.tambien || [])].some(p => route.path.startsWith(p))
}
</script>

<style scoped>
.ptb {
  position: fixed; left: 0; right: 0; bottom: 0; z-index: 45;
  display: flex; justify-content: space-around; align-items: stretch;
  padding: 4px 4px calc(4px + env(safe-area-inset-bottom));
  background: var(--p-papel); border-top: 1px solid var(--p-linea);
  box-shadow: 0 -6px 18px -14px rgb(0 0 0 / .35);
}
.ptb__tab {
  flex: 1 1 0; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 3px;
  min-height: 56px; border-radius: 12px; text-decoration: none;
  font-size: .74rem; font-weight: 600; color: var(--p-suave);
}
.ptb__tab--on { color: var(--p-marca-fuerte); }
.ptb__tab--on .ptb__icono { background: var(--p-marca-suave); }
.ptb__icono { position: relative; display: inline-flex; align-items: center; justify-content: center; width: 52px; height: 30px; border-radius: 999px; }
.ptb__badge {
  position: absolute; top: -3px; right: 6px; min-width: 18px; height: 18px; padding: 0 5px; border-radius: 999px;
  background: var(--p-urgente); color: var(--p-papel); font-size: .68rem; font-weight: 700; display: grid; place-items: center;
}
@media (min-width: 860px) { .ptb { display: none; } }
</style>
