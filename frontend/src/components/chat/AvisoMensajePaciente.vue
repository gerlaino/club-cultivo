<template>
  <Transition name="amp">
    <div v-if="chat.alerta" class="amp" role="status" data-testid="alerta-mensaje">
      <span class="amp__avatar" aria-hidden="true">{{ iniciales }}</span>
      <div class="amp__cuerpo">
        <b>{{ chat.alerta.nombre }}</b>
        <span class="amp__sub">Mensaje nuevo por el portal</span>
        <span v-if="chat.alerta.texto" class="amp__texto">{{ chat.alerta.texto }}</span>
        <div class="amp__acts">
          <button type="button" class="amp__btn amp__btn--lleno" @click="responder">Responder</button>
          <button type="button" class="amp__btn" @click="chat.cerrarAlerta()">Después</button>
        </div>
      </div>
    </div>
  </Transition>
</template>

<script setup>
// La alerta de «mensaje nuevo» de un paciente (27-oct-2026), en cualquier pantalla del equipo
// que atiende el chat: llega en vivo, dice quién y qué escribió, y lleva a la conversación. Si la
// conversación de ese paciente ya está abierta, no aparece (ver `chatPacientes.refrescar`).
//
// Es además quien arranca el chat del lado del equipo: carga la bandeja (el contador del menú) y
// escucha el canal.
import { computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { usePWA } from '../../composables/usePWA.js'
import { useChatPacientesStore } from '../../stores/chatPacientes'

const router = useRouter()
const chat = useChatPacientesStore()
const iniciales = computed(() => (chat.alerta?.nombre || '').split(/\s+/).slice(0, 2).map((p) => p[0] || '').join('').toUpperCase())

onMounted(() => { chat.escuchar(); chat.cargar() })

function responder() {
  const id = chat.alerta.pacienteId
  chat.cerrarAlerta()
  // En el teléfono, a la bandeja del teléfono; en la compu, a la ficha del paciente con su chat.
  if (usePWA().isPWA() || router.currentRoute.value.path.startsWith('/m')) router.push({ path: '/m/chat', query: { paciente: id } })
  else router.push({ path: '/chat-pacientes', query: { paciente: id } })
}
</script>

<style scoped>
.amp {
  position: fixed; top: 72px; right: 20px; z-index: 1300; width: 360px; max-width: calc(100vw - 32px);
  display: flex; gap: .7rem; padding: .85rem .95rem; background: #fff; border: 1px solid var(--c-slate-200);
  border-radius: 16px; box-shadow: 0 18px 36px -18px rgba(15, 42, 30, .45);
}
.amp__avatar { width: 40px; height: 40px; flex: none; border-radius: 50%; background: var(--c-leaf-100); color: var(--c-leaf-800); display: grid; place-items: center; font-weight: 700; font-size: .85rem; }
.amp__cuerpo { flex: 1; min-width: 0; display: flex; flex-direction: column; gap: .15rem; }
.amp__sub { font-size: .78rem; color: var(--c-slate-500); }
.amp__texto { font-size: .88rem; color: var(--c-slate-700); display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical; overflow: hidden; }
.amp__acts { display: flex; gap: .45rem; margin-top: .45rem; }
.amp__btn { min-height: 34px; padding: 0 .8rem; border-radius: 9px; border: 1px solid var(--c-slate-300); background: #fff; color: var(--c-slate-900); font-weight: 600; font-size: .82rem; cursor: pointer; }
.amp__btn--lleno { background: var(--c-leaf-800); border-color: var(--c-leaf-800); color: #fff; }
.amp-enter-active, .amp-leave-active { transition: all .25s ease; }
.amp-enter-from, .amp-leave-to { opacity: 0; transform: translateY(-8px); }
@media (max-width: 640px) { .amp { top: 12px; right: 16px; left: 16px; width: auto; } }
</style>
