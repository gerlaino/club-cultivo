<template>
  <div class="portal pt" :style="estiloDeMarca">
    <PortalNavBar />
    <PortalAvisos />
    <main class="pt__main">
      <RouterView />
    </main>
    <PortalFooter />
    <PortalChatBoton v-if="club?.mensajes !== false" class="pt__chat" />
    <PortalTabBar />
  </div>
</template>

<script setup>
// El envoltorio del portal. Hace tres cosas y ninguna más:
//
//   1. Pide UNA vez la ficha de la organización: la barra y el pie la muestran en todas las
//      pantallas, y cada vista pidiéndola por su cuenta era una llamada por navegación.
//   2. **Pinta el portal con el color de la organización.** `theme_primary` se guarda desde hace
//      meses, el admin lo edita, viaja en el endpoint — y no lo leía ninguna pantalla de la app.
//      Acá sí: es la diferencia entre "una app donde está mi club" y "el portal de mi club".
//   3. Monta la franja de avisos, que se dibuja sola sólo si hay algo que decir.
//   4. En el teléfono, la barra de abajo con lo que el paciente viene a hacer (28-oct-2026); el
//      botón flotante del chat queda para la compu, donde no hay barra.
import { computed, onMounted } from 'vue'
import { RouterView } from 'vue-router'
import PortalNavBar from '@/components/portal/PortalNavBar.vue'
import PortalFooter from '@/components/portal/PortalFooter.vue'
import PortalAvisos from '@/components/portal/PortalAvisos.vue'
import PortalChatBoton from '@/components/portal/PortalChatBoton.vue'
import PortalTabBar from '@/components/portal/PortalTabBar.vue'
import { usePortalChatStore } from '@/stores/portalChat'
import { usePortalClubStore } from '@/stores/portalClub'
import { storeToRefs } from 'pinia'
import { recordarPuerta, usarManifestDe } from '@/lib/puertaPortal'

const store = usePortalClubStore()
const { club } = storeToRefs(store)
// Y deja recordada SU puerta en este teléfono, con el manifest de su organización: si lo instala,
// el ícono se llama como ella y abre en su puerta (28-oct-2026).
onMounted(async () => {
  await store.fetchClub()
  if (club.value?.slug) {
    recordarPuerta(club.value.slug)
    usarManifestDe(club.value.slug, club.value.name)
  }
})

// El chat con la organización: se escucha desde que entra (los «sin leer» del botón flotante y
// de la barra se ven en cualquier pantalla del portal).
const chat = usePortalChatStore()
onMounted(() => { chat.escuchar(); chat.cargar({ silencioso: true }) })

// Sólo se pisan las variables de marca, no la paleta entera: el fondo, la tinta y los semánticos
// siguen saliendo del DS. Una organización puede elegir un color feo; no puede romper la
// legibilidad de su portal.
const estiloDeMarca = computed(() => {
  const color = club.value?.theme_primary
  if (!esHex(color)) return {}

  return {
    '--p-marca':        color,
    '--p-marca-fuerte': oscurecer(color, 0.22),
    '--p-marca-suave':  mezclarConBlanco(color, 0.92),
    '--p-marca-linea':  mezclarConBlanco(color, 0.62),
  }
})

function esHex(c) { return typeof c === 'string' && /^#[0-9a-f]{6}$/i.test(c.trim()) }

function partes(hex) {
  const h = hex.trim().slice(1)
  return [0, 2, 4].map(i => parseInt(h.slice(i, i + 2), 16))
}
const aHex = (rgb) => '#' + rgb.map(v => Math.round(Math.min(255, Math.max(0, v))).toString(16).padStart(2, '0')).join('')

function oscurecer(hex, cuanto)        { return aHex(partes(hex).map(v => v * (1 - cuanto))) }
function mezclarConBlanco(hex, cuanto) { return aHex(partes(hex).map(v => v + (255 - v) * cuanto)) }
</script>

<style scoped>
.pt {
  min-height: 100vh;
  display: flex;
  flex-direction: column;
  background: var(--p-fondo);
  color: var(--p-tinta);
  font-family: var(--p-ui);
}

.pt__main { flex: 1; }
/* Lugar para la barra de abajo: el pie y el último botón no quedan tapados. */
@media (max-width: 859px) {
  .pt { padding-bottom: calc(68px + env(safe-area-inset-bottom)); }
  .pt__chat { display: none; }
}
</style>
