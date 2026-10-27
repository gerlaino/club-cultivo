<template>
  <section class="ccp" :aria-label="`Chat con ${nombre}`">
    <header class="ccp__hd">
      <button v-if="conVolver" type="button" class="ccp__volver" aria-label="Volver a la lista" @click="$emit('volver')">‹</button>
      <span class="ccp__avatar" aria-hidden="true">{{ iniciales }}</span>
      <div class="ccp__quien">
        <b>{{ nombre }}</b>
        <span :class="{ 'ccp__escribe': escribiendo }">{{ escribiendo ? 'está escribiendo…' : subtitulo }}</span>
      </div>
      <slot name="acciones" />
      <button type="button" class="ccp__resolver" :disabled="!mensajes.length" data-testid="chat-resolver" @click="resolver">
        {{ conversacion.resuelta_at ? 'Resuelta ✓' : 'Marcar como resuelta' }}
      </button>
    </header>

    <ChatHilo class="ccp__hilo" lado="organizacion" :mensajes="mensajes" :leido-hasta="conversacion.leida_paciente_at"
              :escribiendo="escribiendo ? `${nombre} está escribiendo…` : null" :enviando="enviando" :cargando="cargando"
              :link-dispensa="linkDispensa" vacio="Todavía no se escribieron. Lo que le mandes le llega a su portal."
              placeholder="Escribí una respuesta" @enviar="enviar" @escribiendo="avisarQueEscribo">
      <template #sobre-barra>
        <div class="ccp__rapidas">
          <button v-for="r in RAPIDAS" :key="r" type="button" class="ccp__rapida" @click="enviar({ texto: r })">{{ r }}</button>
        </div>
      </template>
    </ChatHilo>
  </section>
</template>

<script setup>
// La conversación con UN paciente, del lado de la organización (27-oct-2026). La usan la solapa
// «Chat» de su ficha y la bandeja «Chat con pacientes» (compu y teléfono): una sola pieza, para
// que se vea y se comporte igual en los tres lados.
//
// Abrirla la marca leída (el backend lo hace al pedirla): el paciente ve los ✓✓ en azul.
import { computed, onMounted, onUnmounted, ref, watch } from 'vue'
import ChatHilo from './ChatHilo.vue'
import { getChatPaciente, enviarChatPaciente, resolverChatPaciente } from '../../lib/api'
import { avisarAlCanal } from '../../lib/cambios.js'
import { useChatPacientesStore } from '../../stores/chatPacientes'
import { useToast } from '../../composables/useToast'

const props = defineProps({
  pacienteId: { type: [Number, String], required: true },
  nombre:     { type: String, default: 'Paciente' },
  subtitulo:  { type: String, default: 'Le llega a su portal' },
  conVolver:  { type: Boolean, default: false },
})
const emit = defineEmits(['volver', 'cargado'])

// Lo que más se repite. Un toque y sale: la persona no tipea lo mismo veinte veces por día.
const RAPIDAS = ['La vimos y está bien.', 'La revisamos hoy y te avisamos.', '¿La podés subir de nuevo? No se lee bien.']

const toast = useToast()
const chat = useChatPacientesStore()
const mensajes = ref([])
const conversacion = ref({})
const cargando = ref(true)
const enviando = ref(false)

const id = computed(() => Number(props.pacienteId))
const escribiendo = computed(() => !!chat.escribiendo[id.value])
const iniciales = computed(() => props.nombre.split(/\s+/).slice(0, 2).map((p) => p[0] || '').join('').toUpperCase())
const linkDispensa = (d) => ({ path: `/dispensaciones/${d.id}` })

async function cargar() {
  try {
    const { data } = await getChatPaciente(id.value)
    mensajes.value = data.data || []
    conversacion.value = data.conversacion || {}
    emit('cargado', data.paciente)
  } catch {
    toast.error('No se pudo abrir la conversación')
  } finally {
    cargando.value = false
  }
}

async function enviar({ texto, archivo }) {
  enviando.value = true
  try {
    const { data } = await enviarChatPaciente(id.value, { texto, archivo })
    if (!mensajes.value.some((m) => m.id === data.data.id)) mensajes.value.push(data.data)
  } catch (e) {
    toast.error(e?.response?.data?.error || 'No se pudo mandar la respuesta')
  } finally {
    enviando.value = false
  }
}

async function resolver() {
  try {
    const { data } = await resolverChatPaciente(id.value)
    conversacion.value = { ...conversacion.value, ...data.conversacion }
    if (data.conversacion.resuelta_at) toast.success('Conversación resuelta')
  } catch {
    toast.error('No se pudo marcar como resuelta')
  }
}

function avisarQueEscribo() { avisarAlCanal('escribiendo', { paciente_id: id.value }) }

// Algo cambió en el chat de ESTE paciente (mensaje nuevo, leyó, reabrió): se re-pide.
watch(() => chat.version, () => { if (chat.ultimoEvento?.id === id.value) cargar() })
watch(id, () => { cargando.value = true; chat.abiertoPacienteId = id.value; cargar() })

onMounted(() => {
  chat.escuchar()
  chat.abiertoPacienteId = id.value
  if (chat.alerta?.pacienteId === id.value) chat.cerrarAlerta()
  cargar()
})
onUnmounted(() => { if (chat.abiertoPacienteId === id.value) chat.abiertoPacienteId = null })
</script>

<style scoped>
.ccp { display: flex; flex-direction: column; min-height: 0; height: 100%; background: #fff; }
.ccp__hd { display: flex; align-items: center; gap: .65rem; padding: .6rem .9rem; border-bottom: 1px solid var(--c-ink-100); flex-wrap: wrap; }
.ccp__volver { width: 40px; height: 40px; border: 0; background: transparent; font-size: 1.6rem; line-height: 1; cursor: pointer; color: var(--c-ink-900); }
.ccp__avatar { width: 40px; height: 40px; border-radius: 50%; background: var(--c-leaf-100); color: var(--c-leaf-800); display: grid; place-items: center; font-weight: 700; font-size: .85rem; flex: none; }
.ccp__quien { flex: 1; min-width: 140px; display: flex; flex-direction: column; line-height: 1.25; }
.ccp__quien span { font-size: .8rem; color: var(--c-ink-500); }
.ccp__quien .ccp__escribe { color: var(--c-leaf-700); font-weight: 600; }
.ccp__resolver { min-height: 36px; padding: 0 .8rem; border-radius: 9px; border: 1px solid var(--c-ink-300); background: #fff; color: var(--c-ink-900); font-weight: 600; font-size: .82rem; cursor: pointer; }
.ccp__resolver:disabled { opacity: .5; cursor: default; }
.ccp__hilo { flex: 1; min-height: 0; }
.ccp__rapidas { display: flex; gap: .4rem; overflow-x: auto; padding: .45rem .65rem .55rem; border-top: 1px solid var(--c-ink-100); background: #fff; }
.ccp__rapida { flex: none; min-height: 32px; padding: 0 .75rem; border-radius: 999px; border: 1px solid var(--c-ink-300); background: var(--c-paper); color: var(--c-ink-900); font-size: .8rem; font-weight: 600; cursor: pointer; }
</style>
