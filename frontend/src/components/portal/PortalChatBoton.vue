<template>
  <RouterLink v-if="visible" to="/portal/mensajes" class="pcb" :aria-label="sinLeer ? `Chat: ${sinLeer} sin leer` : 'Abrir el chat con tu organización'" data-testid="chat-flotante">
    <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M4 5h16v11H8l-4 4z"/></svg>
    <span class="pcb__txt">Chat</span>
    <span v-if="sinLeer" class="pcb__badge">{{ sinLeer }}</span>
  </RouterLink>
</template>

<script setup>
// El chat a mano desde cualquier pantalla del portal (27-oct-2026): abajo a la derecha, con los
// mensajes sin leer. En la pantalla del chat no se muestra (ya está ahí).
import { computed } from 'vue'
import { useRoute } from 'vue-router'
import { storeToRefs } from 'pinia'
import { usePortalChatStore } from '@/stores/portalChat'

const route = useRoute()
const { sinLeer } = storeToRefs(usePortalChatStore())
const visible = computed(() => !route.path.startsWith('/portal/mensajes'))
</script>

<style scoped>
.pcb {
  position: fixed; right: 20px; bottom: 20px; z-index: 40; height: 54px; padding: 0 1.1rem 0 .95rem;
  display: inline-flex; align-items: center; gap: .55rem; border-radius: 999px; text-decoration: none;
  background: var(--p-marca); color: var(--p-papel); font-weight: 700; box-shadow: 0 12px 26px -12px rgba(0,0,0,.45);
}
.pcb:hover { background: var(--p-marca-fuerte); }
.pcb__txt { font-size: .95rem; }
.pcb__badge {
  min-width: 22px; height: 22px; padding: 0 6px; border-radius: 999px; background: var(--p-urgente); color: var(--p-papel);
  font-size: .78rem; display: grid; place-items: center;
}
@media (max-width: 640px) {
  .pcb { right: 14px; bottom: 14px; }
}
</style>
