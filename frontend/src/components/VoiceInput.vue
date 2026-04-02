<template>
  <div class="voice-input">
    <!-- Botón principal -->
    <button
      type="button"
      class="btn-voice"
      :class="{
        'btn-voice--recording': estado === 'grabando',
        'btn-voice--processing': estado === 'procesando',
        'btn-voice--error': estado === 'error'
      }"
      @click="toggleGrabacion"
      :disabled="estado === 'procesando' || !soportado"
      :title="tooltipTexto"
    >
      <span v-if="estado === 'idle'">
        <i class="bi bi-mic-fill"></i>
      </span>
      <span v-else-if="estado === 'grabando'" class="d-flex align-items-center gap-2">
        <span class="pulse-dot"></span>
        <span class="small">Escuchando...</span>
        <i class="bi bi-stop-fill"></i>
      </span>
      <span v-else-if="estado === 'procesando'" class="d-flex align-items-center gap-2">
        <span class="spinner-border spinner-border-sm"></span>
        <span class="small">Procesando...</span>
      </span>
      <span v-else-if="estado === 'error'">
        <i class="bi bi-mic-mute-fill"></i>
      </span>
    </button>

    <!-- Texto transcripto (preview) -->
    <div v-if="transcripcion" class="voice-preview">
      <i class="bi bi-quote me-1 text-muted"></i>
      <span class="small text-muted fst-italic">{{ transcripcion }}</span>
      <button type="button" class="btn btn-sm btn-link p-0 ms-2 text-danger" @click="limpiar">
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
import { ref, computed, onUnmounted } from 'vue'

const props = defineProps({
  // Contexto que se le pasa a Claude para entender qué campos llenar
  // Ej: "formulario de planta: nombre, genética, estado, notas"
  contexto: { type: String, required: true },
  // Idioma (es-AR por defecto)
  idioma: { type: String, default: 'es-AR' }
})

const emit = defineEmits([
  'campos-detectados',  // { nombre, genetica, estado, etc. } — campos parseados por IA
  'transcripcion'       // texto crudo transcripto
])

// ── State ──────────────────────────────────────────────
const estado       = ref('idle') // idle | grabando | procesando | error
const transcripcion = ref('')
const errorMsg     = ref('')
let recognition    = null

// ── Support check ──────────────────────────────────────
const soportado = computed(() =>
  'webkitSpeechRecognition' in window || 'SpeechRecognition' in window
)

const tooltipTexto = computed(() => {
  if (!soportado.value) return 'Voz no soportada en este navegador'
  if (estado.value === 'idle') return 'Dictar con voz'
  if (estado.value === 'grabando') return 'Click para detener'
  return ''
})

// ── Grabación ──────────────────────────────────────────
function toggleGrabacion() {
  if (estado.value === 'grabando') {
    detener()
  } else {
    iniciar()
  }
}

function iniciar() {
  errorMsg.value    = ''
  transcripcion.value = ''

  const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition
  recognition = new SpeechRecognition()
  recognition.lang           = props.idioma
  recognition.continuous     = false
  recognition.interimResults = true
  recognition.maxAlternatives = 1

  recognition.onstart = () => { estado.value = 'grabando' }

  recognition.onresult = (event) => {
    const result = event.results[event.results.length - 1]
    transcripcion.value = result[0].transcript
  }

  recognition.onend = () => {
    if (estado.value === 'grabando') {
      // Terminó por silencio natural
      if (transcripcion.value) {
        procesarConIA(transcripcion.value)
      } else {
        estado.value = 'idle'
      }
    }
  }

  recognition.onerror = (event) => {
    estado.value = 'error'
    errorMsg.value = event.error === 'not-allowed'
      ? 'Permiso de micrófono denegado'
      : event.error === 'no-speech'
        ? 'No se detectó voz, intentá de nuevo'
        : `Error: ${event.error}`
    setTimeout(() => { estado.value = 'idle'; errorMsg.value = '' }, 3000)
  }

  recognition.start()
}

function detener() {
  if (recognition) {
    recognition.stop()
    estado.value = 'procesando'
    if (transcripcion.value) {
      procesarConIA(transcripcion.value)
    } else {
      estado.value = 'idle'
    }
  }
}

// ── Parseo con Claude API ──────────────────────────────
async function procesarConIA(texto) {
  estado.value = 'procesando'
  emit('transcripcion', texto)

  try {
    const response = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model: 'claude-sonnet-4-20250514',
        max_tokens: 1000,
        messages: [{
          role: 'user',
          content: `Sos un asistente que extrae datos de texto hablado para un formulario de gestión de clubes cannábicos medicinales en Argentina.

CONTEXTO DEL FORMULARIO: ${props.contexto}

TEXTO DICTADO POR EL USUARIO: "${texto}"

Extraé los datos mencionados y devolvé SOLO un objeto JSON válido con los campos que puedas identificar del contexto. Si un campo no se menciona, no lo incluyas. Usa null solo si el usuario explícitamente dice que no tiene ese dato.

Ejemplos de interpretación:
- "planta uno, genética OG Kush, está en vegetativo" → {"nombre": "Planta 1", "genetica": "OG Kush", "state": "vegetativo"}
- "riego hoy, usé dos litros de agua, ph siete punto dos" → {"tipo": "riego", "descripcion": "2 litros, pH 7.2", "fecha": "hoy"}
- "nueva tarea, poda de la sala norte, para mañana, alta prioridad" → {"titulo": "Poda sala norte", "tipo": "poda", "prioridad": "alta"}

Responde SOLO con el JSON, sin texto adicional, sin backticks.`
        }]
      })
    })

    const data = await response.json()
    const textoRespuesta = data.content?.[0]?.text?.trim() || '{}'

    let campos = {}
    try {
      campos = JSON.parse(textoRespuesta)
    } catch {
      // Si no puede parsear, al menos devuelve la transcripción
      campos = { _transcripcion: texto }
    }

    emit('campos-detectados', campos)
    estado.value = 'idle'

  } catch (e) {
    console.error('Error procesando voz con IA:', e)
    // Aunque falle la IA, emitir la transcripción cruda
    emit('campos-detectados', { _transcripcion: texto })
    estado.value = 'idle'
  }
}

function limpiar() {
  transcripcion.value = ''
  errorMsg.value = ''
  estado.value = 'idle'
}

onUnmounted(() => {
  if (recognition) recognition.abort()
})
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

.btn-voice--processing {
  border-color: #fd7e14;
  color: #fd7e14;
  background: rgba(253,126,20,0.08);
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

.voice-error {
  padding: 4px 8px;
}
</style>
