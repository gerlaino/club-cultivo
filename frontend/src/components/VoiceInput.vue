<template>
  <div class="voice-input">
    <!-- Botón principal -->
    <button
      type="button"
      class="btn-voice"
      :class="{
        'btn-voice--recording': estado === 'grabando',
        'btn-voice--error': estado === 'error'
      }"
      @click="toggleGrabacion"
      :disabled="!soportado"
      :title="tooltipTexto"
    >
      <span v-if="estado === 'idle'">
        <i class="bi bi-mic-fill"></i>
      </span>
      <span v-else-if="estado === 'grabando'" class="d-flex align-items-center gap-2">
        <span class="pulse-dot"></span>
        <span class="small">Tocá para terminar</span>
        <i class="bi bi-stop-fill"></i>
      </span>
      <span v-else-if="estado === 'error'">
        <i class="bi bi-mic-mute-fill"></i>
      </span>
    </button>

    <!-- Lo dictado, en vivo. Mientras grabás se muestra también el tramo que el servicio todavía
         está corrigiendo: sin eso el botón dice "Tocá para terminar" y en pantalla no pasa nada,
         que es justo la sensación de "no me escucha" que hubo que sacar. -->
    <div v-if="transcripcion || interim" class="voice-preview">
      <i class="bi bi-quote me-1 text-muted"></i>
      <span class="small text-muted fst-italic">{{ transcripcion }}</span>
      <span v-if="interim" class="small fst-italic voice-preview__interim">{{ interim }}</span>
      <!-- Borrar a mitad de la grabación no tiene sentido: lo que se dicte después vuelve a
           llenarlo igual. -->
      <button v-if="!escuchando" type="button" class="btn btn-sm btn-link p-0 ms-2 text-danger" @click="limpiar">
        <i class="bi bi-x"></i>
      </button>
    </div>

    <!-- Error -->
    <div v-if="errorMsg" class="voice-error small text-danger mt-1">
      <i class="bi bi-exclamation-circle me-1"></i>{{ errorMsg }}
    </div>

    <!-- No soportado -->
    <div v-if="!soportado" class="small text-muted mt-1">
      <i class="bi bi-info-circle me-1"></i>Tu navegador no soporta entrada por voz
    </div>
  </div>
</template>

<script setup>
// Dictado para el campo de notas de una actividad. NO llama a la IA.
//
// Llamaba a `https://api.anthropic.com/v1/messages` derecho desde el navegador, sin ninguna
// credencial: la respuesta era un 401 que caía en el `catch`, y de ahí salía la transcripción
// cruda. O sea que el parseo "con IA" nunca corrió una sola vez — lo único que este botón hizo
// siempre fue pasar el texto dictado al campo de notas, que es exactamente lo que hace ahora.
//
// Aparte de no funcionar, esa llamada esquivaba la medición: toda consulta a la IA tiene que
// quedar en `ia_llamadas` con su costo, y para eso pasa por el backend. Si algún día este botón
// necesita interpretar lo dictado, va por `/asistente/parsear`, no por el navegador.
import { computed, onUnmounted } from 'vue'
import { useReconocimientoVoz } from '../composables/useReconocimientoVoz.js'

const props = defineProps({
  idioma: { type: String, default: 'es-AR' },
})

const emit = defineEmits([
  'campos-detectados',  // { _transcripcion } — lo dictado, para que el formulario lo ubique
  'transcripcion',      // texto crudo
])

const voz = useReconocimientoVoz({
  idioma: props.idioma,
  alTerminar: (dicho) => {
    emit('transcripcion', dicho)
    emit('campos-detectados', { _transcripcion: dicho })
  },
})

const { escuchando, texto: transcripcion, interim, error: errorMsg, soportado } = voz

const estado = computed(() => {
  if (escuchando.value) return 'grabando'
  if (errorMsg.value)   return 'error'
  return 'idle'
})

const tooltipTexto = computed(() => {
  if (!soportado.value)          return 'Voz no soportada en este navegador'
  if (estado.value === 'grabando') return 'Tocá para terminar'
  return 'Dictar con voz'
})

function toggleGrabacion() {
  if (escuchando.value) voz.detener()
  else                  voz.iniciar()
}

function limpiar() { voz.limpiar() }

onUnmounted(() => voz.cancelar())
</script>

<style scoped>
.voice-input {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.btn-voice {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  padding: 8px 14px;
  border-radius: 20px;
  border: 2px solid var(--bs-border-color);
  background: var(--bs-body-bg);
  color: var(--bs-secondary-color);
  cursor: pointer;
  font-size: 0.875rem;
  transition: all 0.2s;
  white-space: nowrap;
}

.btn-voice:hover:not(:disabled) {
  border-color: #0d6efd;
  color: #0d6efd;
  background: rgba(13,110,253,0.06);
}

.btn-voice--recording {
  border-color: #dc3545 !important;
  color: #dc3545 !important;
  background: rgba(220,53,69,0.08) !important;
  animation: pulse-border 1.5s ease-in-out infinite;
}

.btn-voice--error {
  border-color: #dc3545;
  color: #dc3545;
}

@keyframes pulse-border {
  0%, 100% { box-shadow: 0 0 0 0 rgba(220,53,69,0.4); }
  50%       { box-shadow: 0 0 0 6px rgba(220,53,69,0); }
}

.pulse-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background: #dc3545;
  animation: pulse-dot 1s ease-in-out infinite;
}

@keyframes pulse-dot {
  0%, 100% { opacity: 1; transform: scale(1); }
  50%       { opacity: 0.4; transform: scale(0.7); }
}

.voice-preview {
  display: flex;
  align-items: flex-start;
  gap: 4px;
  padding: 8px 12px;
  background: rgba(13,110,253,0.06);
  border: 1px solid rgba(13,110,253,0.2);
  border-radius: 8px;
  max-width: 100%;
}

/* Lo que el servicio todavía está corrigiendo: se ve, pero más apagado que lo ya confirmado. */
.voice-preview__interim {
  color: var(--bs-secondary-color);
  opacity: 0.55;
  margin-left: 4px;
}

.voice-error {
  padding: 4px 8px;
}
</style>
