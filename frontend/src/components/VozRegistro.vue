<template>
  <div class="vr">

    <!-- Botón principal -->
    <button
        class="vr__btn"
        :class="{
        'vr__btn--escuchando': estado === 'escuchando',
        'vr__btn--procesando': estado === 'procesando',
      }"
        @click="toggleVoz"
        :disabled="estado === 'procesando'"
        :title="estadoLabel"
    >
      <span class="vr__btn-icon">
        <span v-if="estado === 'idle'">🎤</span>
        <span v-else-if="estado === 'escuchando'" class="vr__pulse">🎙️</span>
        <span v-else-if="estado === 'procesando'" class="vr__spin">⚙️</span>
      </span>
      <span class="vr__btn-label">{{ estadoLabel }}</span>
    </button>

    <!-- Panel de transcripción -->
    <Teleport to="body">
      <transition name="vr-slide">
        <div v-if="mostrarPanel" class="vr__panel-backdrop" @click.self="cerrar">
          <div class="vr__panel">

            <!-- Header -->
            <div class="vr__panel-header">
              <div class="vr__panel-header-left">
                <div class="vr__panel-icon" :class="{ 'vr__panel-icon--active': estado === 'escuchando' }">
                  🎙️
                </div>
                <div>
                  <div class="vr__panel-title">Registro por voz</div>
                  <div class="vr__panel-sub">{{ planta?.nombre || 'Planta' }} · {{ new Date().toLocaleDateString('es-AR') }}</div>
                </div>
              </div>
              <button class="vr__close" @click="cerrar"><i class="bi bi-x-lg"></i></button>
            </div>

            <!-- Área de escucha -->
            <div class="vr__listen-area" :class="{ 'vr__listen-area--active': estado === 'escuchando' }">

              <div v-if="estado === 'idle' && !transcripcion" class="vr__hint">
                <div class="vr__hint-icon">🎤</div>
                <div class="vr__hint-title">Hablá naturalmente</div>
                <div class="vr__hint-ejemplos">
                  <div class="vr__ejemplo">"La planta está en 52cm, salud buena, sin plagas, 6 colas"</div>
                  <div class="vr__ejemplo">"Observo déficit de nitrógeno en hojas bajas, color amarillento"</div>
                  <div class="vr__ejemplo">"Todo bien, altura 38cm, verde oscuro, sin problemas"</div>
                </div>
              </div>

              <div v-if="estado === 'escuchando'" class="vr__waves">
                <div class="vr__wave-bar" v-for="i in 7" :key="i" :style="{ animationDelay: `${i * 0.1}s` }"></div>
              </div>

              <div v-if="transcripcion" class="vr__transcript">
                <div class="vr__transcript-label">Escuché:</div>
                <div class="vr__transcript-text">"{{ transcripcion }}"</div>
              </div>

              <div v-if="estado === 'procesando'" class="vr__procesando">
                <div class="vr__procesando-spinner"></div>
                <span>Analizando con IA...</span>
              </div>

              <div v-if="errorVoz" class="vr__error">
                <i class="bi bi-exclamation-triangle"></i> {{ errorVoz }}
              </div>

            </div>

            <!-- Controles de grabación -->
            <div class="vr__controles" v-if="!resultado">
              <button
                  v-if="estado === 'idle'"
                  class="vr__grabar-btn"
                  @click="iniciarGrabacion"
              >
                <i class="bi bi-mic-fill"></i> Empezar a hablar
              </button>
              <button
                  v-if="estado === 'escuchando'"
                  class="vr__detener-btn"
                  @click="detenerGrabacion"
              >
                <i class="bi bi-stop-circle-fill"></i> Listo, procesar
              </button>
            </div>

            <!-- Resultado parseado -->
            <div v-if="resultado" class="vr__resultado">
              <div class="vr__resultado-titulo">
                <i class="bi bi-check-circle-fill" style="color:#1b5e20"></i>
                Esto registré — revisá y confirmá
              </div>

              <div class="vr__resultado-grid">
                <div class="vr__resultado-item" v-if="resultado.altura_cm">
                  <span class="vr__resultado-label">Altura</span>
                  <span class="vr__resultado-val">{{ resultado.altura_cm }} cm</span>
                </div>
                <div class="vr__resultado-item" v-if="resultado.num_colas">
                  <span class="vr__resultado-label">Colas</span>
                  <span class="vr__resultado-val">{{ resultado.num_colas }}</span>
                </div>
                <div class="vr__resultado-item" v-if="resultado.estado_salud">
                  <span class="vr__resultado-label">Salud</span>
                  <span class="vr__resultado-val">{{ SALUD_LABELS[resultado.estado_salud] || resultado.estado_salud }}</span>
                </div>
                <div class="vr__resultado-item" v-if="resultado.color_hojas">
                  <span class="vr__resultado-label">Hojas</span>
                  <span class="vr__resultado-val">{{ COLOR_LABELS[resultado.color_hojas] || resultado.color_hojas }}</span>
                </div>
                <div class="vr__resultado-item" v-if="resultado.plagas">
                  <span class="vr__resultado-label">Plagas</span>
                  <span class="vr__resultado-val">{{ PLAGAS_LABELS[resultado.plagas] || resultado.plagas }}</span>
                </div>
                <div class="vr__resultado-item vr__resultado-item--full" v-if="resultado.deficiencias">
                  <span class="vr__resultado-label">Deficiencias</span>
                  <span class="vr__resultado-val">{{ resultado.deficiencias }}</span>
                </div>
                <div class="vr__resultado-item vr__resultado-item--full" v-if="resultado.notas">
                  <span class="vr__resultado-label">Notas</span>
                  <span class="vr__resultado-val">{{ resultado.notas }}</span>
                </div>
              </div>

              <div class="vr__resultado-acciones">
                <button class="vr__reintentar-btn" @click="reintentar">
                  <i class="bi bi-arrow-counterclockwise"></i> Intentar de nuevo
                </button>
                <button class="vr__aplicar-btn" @click="aplicar">
                  <i class="bi bi-check-lg"></i> Aplicar al formulario
                </button>
              </div>
            </div>

          </div>
        </div>
      </transition>
    </Teleport>

  </div>
</template>

<script setup>
import { ref, computed } from 'vue'

const props = defineProps({
  planta: { type: Object, default: null }
})

const emit = defineEmits(['aplicar'])

// Estado
const estado        = ref('idle') // idle | escuchando | procesando
const mostrarPanel  = ref(false)
const transcripcion = ref('')
const resultado     = ref(null)
const errorVoz      = ref(null)

// Web Speech API
let recognition = null

const SALUD_LABELS = {
  excelente: '🟢 Excelente',
  bueno:     '🟡 Bueno',
  regular:   '🟠 Regular',
  malo:      '🔴 Malo',
  critico:   '🚨 Crítico',
}
const COLOR_LABELS = {
  verde_oscuro: '🟢 Verde oscuro',
  verde_claro:  '🟩 Verde claro',
  amarillo:     '🟡 Amarillo',
  marron:       '🟤 Marrón',
}
const PLAGAS_LABELS = {
  ninguna:  '✅ Ninguna',
  leve:     '⚠️ Leve',
  moderada: '🐛 Moderada',
  severa:   '🚨 Severa',
}

const estadoLabel = computed(() => {
  if (estado.value === 'escuchando') return 'Escuchando...'
  if (estado.value === 'procesando') return 'Procesando...'
  return 'Registro por voz'
})

function toggleVoz() {
  if (estado.value === 'escuchando') {
    detenerGrabacion()
  } else {
    mostrarPanel.value = true
  }
}

function iniciarGrabacion() {
  errorVoz.value = null
  transcripcion.value = ''
  resultado.value = null

  const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition
  if (!SpeechRecognition) {
    errorVoz.value = 'Tu navegador no soporta reconocimiento de voz. Usá Chrome.'
    return
  }

  recognition = new SpeechRecognition()
  recognition.lang = 'es-AR'
  recognition.continuous = true
  recognition.interimResults = true

  recognition.onstart = () => {
    estado.value = 'escuchando'
  }

  recognition.onresult = (event) => {
    let texto = ''
    for (let i = 0; i < event.results.length; i++) {
      texto += event.results[i][0].transcript
    }
    transcripcion.value = texto
  }

  recognition.onerror = (event) => {
    if (event.error === 'no-speech') return
    errorVoz.value = `Error de micrófono: ${event.error}`
    estado.value = 'idle'
  }

  recognition.onend = () => {
    if (estado.value === 'escuchando') {
      estado.value = 'idle'
    }
  }

  recognition.start()
}

function detenerGrabacion() {
  if (recognition) recognition.stop()
  estado.value = 'procesando'
  if (transcripcion.value.trim()) {
    parsearConIA(transcripcion.value)
  } else {
    estado.value = 'idle'
    errorVoz.value = 'No escuché nada. Intentá de nuevo.'
  }
}

async function parsearConIA(texto) {
  try {
    const response = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model: 'claude-sonnet-4-20250514',
        max_tokens: 500,
        system: `Sos un asistente de cultivo de cannabis medicinal. Tu única función es extraer datos de observación de una planta a partir de texto libre en español y devolver un JSON.

Los campos posibles son:
- altura_cm: número (altura de la planta en centímetros)
- num_colas: número entero (cantidad de colas o ramas principales)
- estado_salud: uno de [excelente, bueno, regular, malo, critico]
- color_hojas: uno de [verde_oscuro, verde_claro, amarillo, marron]
- plagas: uno de [ninguna, leve, moderada, severa]
- deficiencias: string libre (descripción de deficiencias observadas)
- notas: string libre (otras observaciones)

Reglas:
- Devolvé SOLO el JSON, sin texto adicional, sin markdown, sin explicaciones
- Incluí solo los campos que puedas inferir del texto
- Si el texto dice "todo bien" o "sin problemas" asumí estado_salud: bueno, plagas: ninguna
- Si menciona "verde" sin especificar, usá verde_oscuro
- Si dice "sano" o "saludable" usá excelente
- Si dice "regular" o "así así" usá regular`,
        messages: [
          { role: 'user', content: `Texto del cultivador: "${texto}"\n\nDevolvé el JSON con los datos extraídos.` }
        ]
      })
    })

    const data = await response.json()
    const content = data.content?.[0]?.text || '{}'

    let parsed
    try {
      parsed = JSON.parse(content.trim())
    } catch {
      const match = content.match(/\{[\s\S]*\}/)
      parsed = match ? JSON.parse(match[0]) : {}
    }

    resultado.value = parsed
    estado.value = 'idle'

  } catch (e) {
    console.error('Error IA:', e)
    errorVoz.value = 'Error al procesar con IA. Revisá la conexión.'
    estado.value = 'idle'
  }
}

function aplicar() {
  emit('aplicar', { ...resultado.value })
  cerrar()
}

function reintentar() {
  resultado.value = null
  transcripcion.value = ''
  errorVoz.value = null
  estado.value = 'idle'
}

function cerrar() {
  if (recognition) recognition.stop()
  mostrarPanel.value = false
  estado.value = 'idle'
  transcripcion.value = ''
  resultado.value = null
  errorVoz.value = null
}
</script>

<style scoped>
.vr { display: inline-block; }

.vr__btn {
  display: flex; align-items: center; gap: 8px;
  background: #f0fdf4; border: 1.5px solid #c8e6c9;
  color: #1b5e20; padding: 9px 16px; border-radius: 10px;
  font-size: 13px; font-weight: 500; cursor: pointer;
  transition: all .2s;
}
.vr__btn:hover { background: #e8f5e9; border-color: #1b5e20; }
.vr__btn--escuchando {
  background: #fef2f2; border-color: #fca5a5; color: #dc2626;
  animation: vr-pulse-btn 1.5s infinite;
}
.vr__btn--procesando { opacity: .7; cursor: not-allowed; }
.vr__btn-icon { font-size: 16px; }
.vr__btn-label { white-space: nowrap; }

@keyframes vr-pulse-btn {
  0%, 100% { box-shadow: 0 0 0 0 rgba(220,38,38,.2); }
  50% { box-shadow: 0 0 0 6px rgba(220,38,38,0); }
}

.vr__pulse { animation: blink .8s infinite; display: inline-block; }
@keyframes blink { 0%,100%{opacity:1} 50%{opacity:.4} }
.vr__spin { animation: spin .8s linear infinite; display: inline-block; }
@keyframes spin { to { transform: rotate(360deg); } }

/* Panel */
.vr__panel-backdrop {
  position: fixed; inset: 0; background: rgba(0,0,0,.5);
  backdrop-filter: blur(6px); display: flex; align-items: center;
  justify-content: center; z-index: 2000; padding: 1rem;
}
.vr__panel {
  background: white; border-radius: 20px; width: 100%;
  max-width: 520px; overflow: hidden;
  box-shadow: 0 24px 64px rgba(0,0,0,.18);
}

.vr__panel-header {
  display: flex; justify-content: space-between; align-items: center;
  padding: 20px 24px; border-bottom: 1px solid #f0fdf4;
}
.vr__panel-header-left { display: flex; align-items: center; gap: 14px; }
.vr__panel-icon {
  width: 44px; height: 44px; border-radius: 12px;
  background: #e8f5e9; display: flex; align-items: center;
  justify-content: center; font-size: 20px; transition: all .3s;
}
.vr__panel-icon--active {
  background: #fef2f2;
  animation: vr-pulse-btn 1s infinite;
}
.vr__panel-title { font-size: 16px; font-weight: 600; color: #1a2e1b; }
.vr__panel-sub { font-size: 12px; color: #6b8f71; margin-top: 2px; }
.vr__close {
  background: #f1f5f9; border: none; width: 32px; height: 32px;
  border-radius: 8px; cursor: pointer; color: #64748b;
  display: flex; align-items: center; justify-content: center;
  font-size: 13px; transition: all .15s;
}
.vr__close:hover { background: #e2e8f0; }

/* Área de escucha */
.vr__listen-area {
  min-height: 160px; padding: 2rem 1.5rem;
  display: flex; flex-direction: column; align-items: center;
  justify-content: center; gap: 1rem; transition: background .3s;
}
.vr__listen-area--active { background: #fef2f2; }

.vr__hint { text-align: center; }
.vr__hint-icon { font-size: 2.5rem; margin-bottom: .75rem; opacity: .4; }
.vr__hint-title { font-size: 15px; font-weight: 500; color: #1a2e1b; margin-bottom: 1rem; }
.vr__hint-ejemplos { display: flex; flex-direction: column; gap: 6px; }
.vr__ejemplo {
  background: #f8fdf8; border: 1px solid #e8f5e9; border-radius: 8px;
  padding: 8px 14px; font-size: 12px; color: #4a7c59; font-style: italic;
}

.vr__waves {
  display: flex; align-items: center; gap: 5px; height: 48px;
}
.vr__wave-bar {
  width: 4px; border-radius: 2px; background: #dc2626;
  animation: wave .8s ease-in-out infinite alternate;
}
.vr__wave-bar:nth-child(1) { height: 16px; }
.vr__wave-bar:nth-child(2) { height: 28px; }
.vr__wave-bar:nth-child(3) { height: 40px; }
.vr__wave-bar:nth-child(4) { height: 48px; }
.vr__wave-bar:nth-child(5) { height: 40px; }
.vr__wave-bar:nth-child(6) { height: 28px; }
.vr__wave-bar:nth-child(7) { height: 16px; }
@keyframes wave {
  from { transform: scaleY(0.4); opacity: .6; }
  to   { transform: scaleY(1);   opacity: 1; }
}

.vr__transcript { text-align: center; }
.vr__transcript-label { font-size: 11px; color: #6b8f71; text-transform: uppercase; letter-spacing: .07em; margin-bottom: 6px; }
.vr__transcript-text { font-size: 15px; color: #1a2e1b; font-style: italic; line-height: 1.5; }

.vr__procesando {
  display: flex; flex-direction: column; align-items: center; gap: 12px;
  color: #4a7c59; font-size: 14px;
}
.vr__procesando-spinner {
  width: 32px; height: 32px; border: 2px solid #e8f5e9; border-top-color: #1b5e20;
  border-radius: 50%; animation: spin .7s linear infinite;
}

.vr__error {
  background: #fef2f2; color: #dc2626; border-radius: 8px;
  padding: 10px 14px; font-size: 13px; display: flex;
  align-items: center; gap: 7px;
}

/* Controles */
.vr__controles {
  padding: 0 1.5rem 1.5rem; display: flex; justify-content: center;
}
.vr__grabar-btn {
  display: flex; align-items: center; gap: 8px;
  background: linear-gradient(135deg, #1b5e20, #2e7d32);
  color: #e8f5e9; border: none; padding: 13px 32px; border-radius: 12px;
  font-size: 15px; font-weight: 500; cursor: pointer; transition: opacity .2s;
  box-shadow: 0 4px 12px #1b5e2030;
}
.vr__grabar-btn:hover { opacity: .88; }
.vr__detener-btn {
  display: flex; align-items: center; gap: 8px;
  background: #dc2626; color: white; border: none;
  padding: 13px 32px; border-radius: 12px; font-size: 15px;
  font-weight: 500; cursor: pointer; transition: opacity .2s;
  box-shadow: 0 4px 12px rgba(220,38,38,.25);
  animation: vr-pulse-btn 1.5s infinite;
}
.vr__detener-btn:hover { opacity: .88; }

/* Resultado */
.vr__resultado {
  border-top: 1px solid #f0fdf4; padding: 1.25rem 1.5rem 1.5rem;
}
.vr__resultado-titulo {
  display: flex; align-items: center; gap: 8px;
  font-size: 14px; font-weight: 600; color: #1a2e1b; margin-bottom: 1rem;
}
.vr__resultado-grid {
  display: grid; grid-template-columns: 1fr 1fr; gap: 8px; margin-bottom: 1.25rem;
}
.vr__resultado-item {
  background: #f8fdf8; border: 1px solid #e8f5e9; border-radius: 10px;
  padding: 10px 14px; display: flex; flex-direction: column; gap: 3px;
}
.vr__resultado-item--full { grid-column: 1 / -1; }
.vr__resultado-label { font-size: 10px; color: #6b8f71; text-transform: uppercase; letter-spacing: .07em; }
.vr__resultado-val { font-size: 14px; font-weight: 500; color: #1a2e1b; }

.vr__resultado-acciones { display: flex; gap: 10px; justify-content: flex-end; }
.vr__reintentar-btn {
  display: flex; align-items: center; gap: 6px;
  background: #f1f5f9; color: #64748b; border: none;
  padding: 10px 18px; border-radius: 9px; font-size: 13px; cursor: pointer;
  transition: background .15s;
}
.vr__reintentar-btn:hover { background: #e2e8f0; }
.vr__aplicar-btn {
  display: flex; align-items: center; gap: 6px;
  background: linear-gradient(135deg, #1b5e20, #2e7d32);
  color: #e8f5e9; border: none; padding: 10px 22px;
  border-radius: 9px; font-size: 13px; font-weight: 500; cursor: pointer;
  transition: opacity .2s; box-shadow: 0 2px 8px #1b5e2030;
}
.vr__aplicar-btn:hover { opacity: .88; }

/* Transitions */
.vr-slide-enter-active, .vr-slide-leave-active { transition: all .25s ease; }
.vr-slide-enter-from, .vr-slide-leave-to { opacity: 0; transform: scale(.96) translateY(8px); }
</style>