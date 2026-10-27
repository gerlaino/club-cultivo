<template>
  <div class="pmv">
    <section class="pmv__chat" aria-label="Chat con tu organización">
      <header class="pmv__hd">
        <img v-if="club?.logo_url" :src="club.logo_url" alt="" class="pmv__logo" />
        <span v-else class="pmv__logo pmv__logo--ini" aria-hidden="true">{{ inicial }}</span>
        <div class="pmv__quien">
          <b>{{ club?.name || 'Tu organización' }}</b>
          <span :class="{ 'pmv__escribe': chat.escribiendo }">{{ chat.escribiendo || estado }}</span>
        </div>
      </header>

      <div v-if="chat.error" class="pmv__error">{{ chat.error }}</div>
      <ChatHilo v-else class="pmv__hilo" lado="paciente" :mensajes="chat.mensajes"
                :leido-hasta="chat.conversacion.leida_org_at" :escribiendo="chat.escribiendo"
                :cita="cita" :enviando="chat.enviando" :cargando="chat.cargando && !chat.cargado"
                vacio="Escribile a tu organización: te contestan en el horario de atención."
                @enviar="enviar" @escribiendo="chat.avisarQueEscribo()" @quitar-cita="quitarCita" />
    </section>
    <p class="pmv__nota">Lo lee el equipo de la organización y queda en tu ficha. Para una urgencia médica, llamá a tu médica.</p>
  </div>
</template>

<script setup>
// El chat con la organización, del lado del paciente (27-oct-2026). «Consultar por esta
// dispensa» llega con `?dispensa=<id>`: el mensaje sale citándola, para que quien contesta
// sepa de qué le habla sin preguntar.
import { computed, onMounted, onUnmounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { storeToRefs } from 'pinia'
import ChatHilo from '@/components/chat/ChatHilo.vue'
import { usePortalChatStore } from '@/stores/portalChat'
import { usePortalClubStore } from '@/stores/portalClub'
import { getPortalDispensa } from '@/lib/portalApi'
import { useToast } from '@/composables/useToast'

const route = useRoute()
const router = useRouter()
const toast = useToast()
const chat = usePortalChatStore()
const { club } = storeToRefs(usePortalClubStore())

const cita = ref(null)
const dispensacionId = ref(null)

const inicial = computed(() => (club.value?.name || '?').trim().charAt(0).toUpperCase())
const estado = computed(() => club.value?.horarios_atencion
  ? `Te contestan en el horario de atención: ${club.value.horarios_atencion}`
  : 'Te contestan en el horario de atención')

onMounted(async () => {
  chat.abierto = true
  chat.escuchar()
  await chat.cargar()
  await chat.marcarLeidos()
  const id = route.query.dispensa
  if (id) {
    try {
      const d = await getPortalDispensa(id)
      dispensacionId.value = d.id
      cita.value = { titulo: `Dispensa Nº ${d.numero}`, detalle: (d.items || []).map((i) => `${i.nombre} ${i.cantidad} ${i.unidad}`).join(' + ') }
    } catch { /* si no es suya o no existe, se escribe sin cita */ }
  }
})
onUnmounted(() => { chat.abierto = false })

function quitarCita() {
  cita.value = null
  dispensacionId.value = null
  if (route.query.dispensa) router.replace({ query: {} })
}

async function enviar({ texto, archivo }) {
  try {
    await chat.enviar({ texto, archivo, dispensacionId: dispensacionId.value })
    if (cita.value) quitarCita()
  } catch (e) {
    toast.error(e?.response?.data?.error || 'No se pudo mandar el mensaje. Probá de nuevo.')
  }
}
</script>

<style scoped>
.pmv { max-width: 860px; margin: 0 auto; padding: 1.25rem 1rem 2rem; }
.pmv__chat {
  background: var(--p-papel); border: 1px solid var(--p-linea); border-radius: 18px; overflow: hidden;
  display: flex; flex-direction: column; height: min(72vh, 760px); min-height: 460px;
}
.pmv__hd { display: flex; align-items: center; gap: .75rem; padding: .7rem 1rem; border-bottom: 1px solid var(--p-linea); }
.pmv__logo { width: 42px; height: 42px; border-radius: 50%; object-fit: cover; flex: none; }
.pmv__logo--ini { display: grid; place-items: center; background: var(--p-marca); color: var(--p-papel); font-weight: 800; }
.pmv__quien { display: flex; flex-direction: column; min-width: 0; line-height: 1.25; }
.pmv__quien span { font-size: .82rem; color: var(--p-suave); }
.pmv__quien .pmv__escribe { color: var(--p-marca); font-weight: 600; }
.pmv__hilo { flex: 1; min-height: 0; }
.pmv__error { padding: 2rem 1rem; color: var(--p-atencion); text-align: center; }
.pmv__nota { font-size: .8rem; color: var(--p-suave); margin: .6rem .25rem 0; }

@media (max-width: 640px) {
  .pmv { padding: 0; }
  .pmv__chat { border-radius: 0; border-left: 0; border-right: 0; height: calc(100dvh - 64px); min-height: 0; }
  .pmv__nota { padding: 0 1rem; }
}
</style>
