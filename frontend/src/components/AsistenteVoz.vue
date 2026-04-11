<template>
  <div class="av">

    <!-- Botón en navbar -->
    <button class="av__trigger" :class="{ 'av__trigger--activo': abierto }" @click="abrir">
      <span class="av__trigger-dot" :class="{ 'av__trigger-dot--pulse': escuchando }"></span>
      Registrar sesión
    </button>

    <!-- Panel modal -->
    <Teleport to="body">
      <transition name="av-modal">
        <div v-if="abierto" class="av__backdrop" @click.self="cerrar">
          <div class="av__panel">

            <!-- Header -->
            <div class="av__header">
              <div class="av__header-left">
                <div class="av__header-icon" :class="{ 'av__header-icon--rec': escuchando }">
                  <i :class="escuchando ? 'bi bi-mic-fill' : 'bi bi-mic'"></i>
                </div>
                <div>
                  <div class="av__header-title">Asistente de cultivo</div>
                  <div class="av__header-sub">Hablá libremente — la IA distribuye todo automáticamente</div>
                </div>
              </div>
              <button class="av__close" @click="cerrar"><i class="bi bi-x-lg"></i></button>
            </div>

            <!-- PASO 1: Escuchar -->
            <div v-if="paso === 'escuchar'" class="av__body">

              <div v-if="!escuchando && !transcripcion" class="av__idle">
                <div class="av__idle-icon">🎙️</div>
                <div class="av__idle-title">¿Qué pasó hoy en el cultivo?</div>
                <div class="av__idle-ejemplos">
                  <div class="av__ejemplo">
                    <span class="av__ejemplo-icono">💧</span>
                    "Regué el lote L-26-003 con EC 1.4 pH 6.2"
                  </div>
                  <div class="av__ejemplo">
                    <span class="av__ejemplo-icono">🌿</span>
                    "La planta P012 tiene déficit de nitrógeno, hojas amarillas"
                  </div>
                  <div class="av__ejemplo">
                    <span class="av__ejemplo-icono">📋</span>
                    "Hay que revisar plagas en sala de floración la semana que viene"
                  </div>
                </div>
              </div>

              <div v-if="escuchando" class="av__recording">
                <div class="av__waves">
                  <div v-for="i in 9" :key="i" class="av__wave" :style="{ animationDelay: `${i * 0.09}s` }"></div>
                </div>
                <div class="av__rec-label">Escuchando... hablá con libertad</div>
              </div>

              <div v-if="transcripcion && !escuchando" class="av__transcript-box">
                <div class="av__transcript-label">Escuché esto:</div>
                <div class="av__transcript-text">"{{ transcripcion }}"</div>
              </div>

              <div v-if="errorVoz" class="av__error">
                <i class="bi bi-exclamation-triangle"></i> {{ errorVoz }}
              </div>

              <div class="av__controles">
                <button v-if="!escuchando && !procesando" class="av__btn-grabar" @click="iniciarGrabacion">
                  <i class="bi bi-mic-fill"></i>
                  {{ transcripcion ? 'Volver a hablar' : 'Empezar a hablar' }}
                </button>
                <button v-if="escuchando" class="av__btn-detener" @click="detenerGrabacion">
                  <i class="bi bi-stop-circle-fill"></i>
                  Listo, procesar
                </button>
                <div v-if="procesando" class="av__procesando">
                  <div class="av__procesando-spinner"></div>
                  <span>Analizando con IA...</span>
                </div>
              </div>
            </div>

            <!-- PASO 2: Revisar acciones -->
            <div v-if="paso === 'revisar'" class="av__body">

              <div class="av__resumen-header">
                <div class="av__resumen-badge">
                  <i class="bi bi-check-circle-fill"></i>
                  {{ acciones.length }} {{ acciones.length === 1 ? 'acción identificada' : 'acciones identificadas' }}
                </div>
                <div class="av__resumen-texto">{{ resumen }}</div>
              </div>

              <div class="av__acciones-lista">
                <div
                  v-for="(accion, i) in acciones"
                  :key="i"
                  class="av__accion"
                  :class="`av__accion--${accion.tipo}`"
                >
                  <div class="av__accion-icono">
                    <span v-if="accion.tipo === 'registro_ambiental'">💧</span>
                    <span v-else-if="accion.tipo === 'registro_planta'">🌿</span>
                    <span v-else-if="accion.tipo === 'tarea'">📋</span>
                    <span v-else>📝</span>
                  </div>
                  <div class="av__accion-body">
                    <div class="av__accion-tipo">{{ labelTipo(accion.tipo) }}</div>
                    <div class="av__accion-titulo">
                      <span v-if="accion.lote_codigo" class="av__accion-ref">{{ accion.lote_codigo }}</span>
                      <span v-if="accion.planta_nombre" class="av__accion-ref">{{ accion.planta_nombre }}</span>
                      {{ descripcionAccion(accion) }}
                    </div>
                    <div class="av__accion-meta">{{ metaAccion(accion) }}</div>
                  </div>
                  <button class="av__accion-remove" @click="quitarAccion(i)" title="Quitar esta acción">
                    <i class="bi bi-x"></i>
                  </button>
                </div>
              </div>

              <div v-if="acciones.length === 0" class="av__vacio">
                No hay acciones para ejecutar.
              </div>

              <div class="av__revisar-footer">
                <button class="av__btn-volver" @click="volverEscuchar">
                  <i class="bi bi-arrow-counterclockwise"></i> Volver a hablar
                </button>
                <button
                  v-if="acciones.length > 0"
                  class="av__btn-ejecutar"
                  @click="ejecutarAcciones"
                  :disabled="ejecutando"
                >
                  <span v-if="ejecutando">
                    <i class="bi bi-hourglass-split"></i> Guardando...
                  </span>
                  <span v-else>
                    <i class="bi bi-check-lg"></i> Guardar todo ({{ acciones.length }})
                  </span>
                </button>
              </div>
            </div>

            <!-- PASO 3: Resultado -->
            <div v-if="paso === 'resultado'" class="av__body av__body--resultado">
              <div class="av__resultado-icon">✅</div>
              <div class="av__resultado-titulo">¡Sesión registrada!</div>
              <div class="av__resultado-lista">
                <div v-for="(r, i) in resultados" :key="i" class="av__resultado-item av__resultado-item--ok">
                  <i class="bi bi-check-circle-fill"></i> {{ r.mensaje }}
                </div>
                <div v-for="(e, i) in erroresEjecucion" :key="'e'+i" class="av__resultado-item av__resultado-item--err">
                  <i class="bi bi-exclamation-circle-fill"></i> {{ e.error }}
                </div>
              </div>
              <button class="av__btn-nueva-sesion" @click="nuevaSesion">
                <i class="bi bi-mic"></i> Nueva sesión
              </button>
            </div>

          </div>
        </div>
      </transition>
    </Teleport>
  </div>
</template>

<script setup>
import { ref, onMounted, onUnmounted } from 'vue'

import api from '../lib/api'

const abierto             = ref(false)
const paso                = ref('escuchar')
const escuchando          = ref(false)
const procesando          = ref(false)
const ejecutando          = ref(false)
const transcripcion       = ref('')
const resumen             = ref('')
const acciones            = ref([])
const resultados          = ref([])
const erroresEjecucion    = ref([])
const errorVoz            = ref(null)

let recognition = null

function abrir() { abierto.value = true }

// Permite que los dashboards abran el asistente via evento global
onMounted(() => {
  window.addEventListener('abrir-asistente-voz', abrir)
})
onUnmounted(() => {
  window.removeEventListener('abrir-asistente-voz', abrir)
})

function cerrar() {
  if (recognition) recognition.stop()
  abierto.value = false
  resetear()
}

function resetear() {
  paso.value          = 'escuchar'
  escuchando.value    = false
  procesando.value    = false
  ejecutando.value    = false
  transcripcion.value = ''
  resumen.value       = ''
  acciones.value      = []
  resultados.value    = []
  erroresEjecucion.value = []
  errorVoz.value      = null
}

function iniciarGrabacion() {
  errorVoz.value    = null
  transcripcion.value = ''

  const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition
  if (!SpeechRecognition) {
    errorVoz.value = 'Tu browser no soporta reconocimiento de voz. Usá Chrome.'
    return
  }

  recognition = new SpeechRecognition()
  recognition.lang            = 'es-AR'
  recognition.continuous      = true
  recognition.interimResults  = true

  recognition.onstart  = () => { escuchando.value = true }
  recognition.onresult = (e) => {
    let txt = ''
    for (let i = 0; i < e.results.length; i++) txt += e.results[i][0].transcript
    transcripcion.value = txt
  }
  recognition.onerror  = (e) => {
    if (e.error === 'no-speech') return
    errorVoz.value  = `Error de micrófono: ${e.error}`
    escuchando.value = false
  }
  recognition.onend    = () => { escuchando.value = false }
  recognition.start()
}

function detenerGrabacion() {
  if (recognition) recognition.stop()
  escuchando.value = false

  if (!transcripcion.value.trim()) {
    errorVoz.value = 'No escuché nada. Intentá de nuevo.'
    return
  }
  parsearConIA()
}

async function parsearConIA() {
  procesando.value = true
  errorVoz.value   = null
  try {
    const { data } = await api.post('/asistente/parsear', { texto: transcripcion.value })
    resumen.value  = data.resumen || ''
    acciones.value = data.acciones || []
    paso.value     = 'revisar'
  } catch (e) {
    errorVoz.value = e?.response?.data?.error || 'Error al procesar con IA'
  } finally {
    procesando.value = false
  }
}

function quitarAccion(i) {
  acciones.value.splice(i, 1)
}

function volverEscuchar() {
  paso.value = 'escuchar'
}

async function ejecutarAcciones() {
  ejecutando.value = true
  try {
    const { data } = await api.post('/asistente/ejecutar', { acciones: acciones.value })
    resultados.value       = data.resultados || []
    erroresEjecucion.value = data.errores_detalle || []
    paso.value             = 'resultado'
  } catch (e) {
    errorVoz.value = e?.response?.data?.error || 'Error al guardar'
  } finally {
    ejecutando.value = false
  }
}

function nuevaSesion() {
  resetear()
}

function labelTipo(tipo) {
  return {
    registro_ambiental: 'Registro ambiental',
    registro_planta:    'Registro de planta',
    tarea:              'Nueva tarea',
    nota_lote:          'Nota de lote',
  }[tipo] || tipo
}

function descripcionAccion(accion) {
  const d = accion.datos || {}
  if (accion.tipo === 'registro_ambiental') {
    const partes = []
    if (d.fertilizacion) partes.push('Fertilización')
    if (d.ph) partes.push(`pH ${d.ph}`)
    if (d.ec) partes.push(`EC ${d.ec}`)
    if (d.observaciones) partes.push(d.observaciones)
    return partes.join(' · ') || 'Registro ambiental'
  }
  if (accion.tipo === 'registro_planta') {
    const partes = []
    if (d.estado_salud) partes.push(d.estado_salud)
    if (d.deficiencias) partes.push(d.deficiencias)
    return partes.join(' · ') || 'Observación de planta'
  }
  if (accion.tipo === 'tarea') return d.titulo || 'Tarea sin título'
  return d.observaciones || ''
}

function metaAccion(accion) {
  const d = accion.datos || {}
  if (accion.tipo === 'tarea') {
    const dias = d.dias_desde_hoy || 7
    return `Prioridad ${d.prioridad || 'media'} · en ${dias} días`
  }
  if (accion.tipo === 'registro_planta' && d.color_hojas) {
    return `Color hojas: ${d.color_hojas} · Plagas: ${d.plagas || 'ninguna'}`
  }
  return ''
}
</script>

<style scoped>
.av { display: inline-block; }

.av__trigger {
  display: flex; align-items: center; gap: 8px;
  background: linear-gradient(135deg, #1b5e20, #2e7d32);
  color: #e8f5e9; border: none; padding: 8px 16px;
  border-radius: 9px; font-size: 13px; font-weight: 500;
  cursor: pointer; transition: opacity .2s;
  box-shadow: 0 2px 8px #1b5e2030;
}
.av__trigger:hover { opacity: .88; }
.av__trigger--activo { opacity: .88; }

.av__trigger-dot {
  width: 7px; height: 7px; border-radius: 50%;
  background: #a5d6a7; flex-shrink: 0; transition: background .3s;
}
.av__trigger-dot--pulse {
  background: #ff5252;
  animation: av-pulse 1s infinite;
}
@keyframes av-pulse {
  0%,100% { box-shadow: 0 0 0 0 rgba(255,82,82,.4); }
  50%      { box-shadow: 0 0 0 5px rgba(255,82,82,0); }
}

.av__backdrop {
  position: fixed; inset: 0; background: rgba(0,0,0,.5);
  backdrop-filter: blur(6px); display: flex; align-items: center;
  justify-content: center; z-index: 2000; padding: 1rem;
}
.av__panel {
  background: white; border-radius: 20px; width: 100%;
  max-width: 580px; overflow: hidden;
  box-shadow: 0 32px 80px rgba(0,0,0,.2);
}

.av__header {
  display: flex; align-items: center; gap: 14px;
  padding: 20px 24px 18px; border-bottom: 1px solid #f0fdf4;
}
.av__header-left { display: flex; align-items: center; gap: 14px; flex: 1; }
.av__header-icon {
  width: 46px; height: 46px; border-radius: 13px;
  background: #e8f5e9; display: flex; align-items: center;
  justify-content: center; font-size: 20px; color: #1b5e20;
  transition: all .3s; flex-shrink: 0;
}
.av__header-icon--rec {
  background: #fef2f2; color: #dc2626;
  animation: av-pulse-bg 1s infinite;
}
@keyframes av-pulse-bg {
  0%,100% { box-shadow: 0 0 0 0 rgba(220,38,38,.2); }
  50%      { box-shadow: 0 0 0 6px rgba(220,38,38,0); }
}
.av__header-title { font-size: 16px; font-weight: 600; color: #1a2e1b; margin-bottom: 3px; }
.av__header-sub { font-size: 12px; color: #6b8f71; }
.av__close {
  background: #f1f5f9; border: none; width: 32px; height: 32px;
  border-radius: 8px; cursor: pointer; color: #64748b; font-size: 13px;
  display: flex; align-items: center; justify-content: center;
  transition: background .15s;
}
.av__close:hover { background: #e2e8f0; }

.av__body { padding: 20px 24px 24px; }

.av__idle { text-align: center; padding: 1rem 0 .5rem; }
.av__idle-icon { font-size: 3rem; margin-bottom: 1rem; opacity: .35; }
.av__idle-title { font-size: 16px; font-weight: 500; color: #1a2e1b; margin-bottom: 1.25rem; }
.av__idle-ejemplos { display: flex; flex-direction: column; gap: 8px; text-align: left; }
.av__ejemplo {
  display: flex; align-items: flex-start; gap: 10px;
  background: #f8fdf8; border: 1px solid #e8f5e9; border-radius: 10px;
  padding: 10px 14px; font-size: 13px; color: #4a7c59; font-style: italic;
}
.av__ejemplo-icono { font-size: 14px; flex-shrink: 0; margin-top: 1px; }

.av__recording { text-align: center; padding: 1.5rem 0; }
.av__waves { display: flex; align-items: center; justify-content: center; gap: 4px; height: 52px; margin-bottom: 1rem; }
.av__wave {
  width: 4px; border-radius: 2px; background: #dc2626;
  animation: av-wave .7s ease-in-out infinite alternate;
}
.av__wave:nth-child(1) { height: 12px; }
.av__wave:nth-child(2) { height: 22px; }
.av__wave:nth-child(3) { height: 34px; }
.av__wave:nth-child(4) { height: 44px; }
.av__wave:nth-child(5) { height: 52px; }
.av__wave:nth-child(6) { height: 44px; }
.av__wave:nth-child(7) { height: 34px; }
.av__wave:nth-child(8) { height: 22px; }
.av__wave:nth-child(9) { height: 12px; }
@keyframes av-wave {
  from { transform: scaleY(.3); opacity: .5; }
  to   { transform: scaleY(1);  opacity: 1; }
}
.av__rec-label { font-size: 14px; color: #dc2626; font-weight: 500; }

.av__transcript-box {
  background: #f8fdf8; border: 1px solid #c8e6c9; border-radius: 12px;
  padding: 14px 16px; margin-bottom: 1rem;
}
.av__transcript-label { font-size: 11px; color: #4a7c59; text-transform: uppercase; letter-spacing: .07em; margin-bottom: 6px; }
.av__transcript-text { font-size: 14px; color: #1a2e1b; line-height: 1.6; font-style: italic; }

.av__error {
  background: #fef2f2; color: #dc2626; border-radius: 8px;
  padding: 10px 14px; font-size: 13px; margin-bottom: 1rem;
  display: flex; align-items: center; gap: 7px;
}

.av__controles { display: flex; justify-content: center; margin-top: 1rem; }
.av__btn-grabar {
  display: flex; align-items: center; gap: 9px;
  background: linear-gradient(135deg, #1b5e20, #2e7d32);
  color: #e8f5e9; border: none; padding: 14px 36px;
  border-radius: 12px; font-size: 15px; font-weight: 500;
  cursor: pointer; transition: opacity .2s;
  box-shadow: 0 4px 14px #1b5e2035;
}
.av__btn-grabar:hover { opacity: .88; }
.av__btn-detener {
  display: flex; align-items: center; gap: 9px;
  background: #dc2626; color: white; border: none;
  padding: 14px 36px; border-radius: 12px; font-size: 15px;
  font-weight: 500; cursor: pointer;
  box-shadow: 0 4px 14px rgba(220,38,38,.25);
  animation: av-pulse 1.5s infinite;
}
.av__procesando {
  display: flex; align-items: center; gap: 12px;
  color: #4a7c59; font-size: 14px;
}
.av__procesando-spinner {
  width: 28px; height: 28px; border: 2px solid #e8f5e9;
  border-top-color: #1b5e20; border-radius: 50%;
  animation: spin .7s linear infinite;
}
@keyframes spin { to { transform: rotate(360deg); } }

/* Acciones */
.av__resumen-header { margin-bottom: 1.25rem; }
.av__resumen-badge {
  display: inline-flex; align-items: center; gap: 7px;
  background: #e8f5e9; color: #1b5e20; border-radius: 20px;
  font-size: 12px; font-weight: 600; padding: 5px 14px; margin-bottom: 8px;
}
.av__resumen-texto { font-size: 14px; color: #4a7c59; line-height: 1.5; font-style: italic; }

.av__acciones-lista { display: flex; flex-direction: column; gap: 10px; margin-bottom: 1.5rem; }
.av__accion {
  display: flex; align-items: flex-start; gap: 12px;
  border: 1px solid #e8f5e9; border-radius: 12px;
  padding: 13px 14px; transition: background .15s;
}
.av__accion:hover { background: #f8fdf8; }
.av__accion--tarea { border-color: #ffe0b2; }
.av__accion--registro_planta { border-color: #fce4ec; }
.av__accion-icono { font-size: 20px; flex-shrink: 0; margin-top: 1px; }
.av__accion-body { flex: 1; min-width: 0; }
.av__accion-tipo {
  font-size: 10px; font-weight: 600; text-transform: uppercase;
  letter-spacing: .07em; color: #6b8f71; margin-bottom: 4px;
}
.av__accion--tarea .av__accion-tipo { color: #e65100; }
.av__accion--registro_planta .av__accion-tipo { color: #c2185b; }
.av__accion-titulo { font-size: 14px; color: #1a2e1b; line-height: 1.4; margin-bottom: 3px; }
.av__accion-ref {
  display: inline-block; background: #f0fdf4; color: #1b5e20;
  font-size: 11px; font-weight: 600; padding: 1px 7px;
  border-radius: 4px; margin-right: 6px;
}
.av__accion-meta { font-size: 12px; color: #94a3b8; }
.av__accion-remove {
  background: none; border: none; color: #cbd5e1; cursor: pointer;
  font-size: 14px; padding: 2px 4px; transition: color .15s; flex-shrink: 0;
}
.av__accion-remove:hover { color: #dc2626; }

.av__vacio { text-align: center; color: #94a3b8; padding: 2rem; font-size: 14px; }

.av__revisar-footer {
  display: flex; justify-content: space-between; align-items: center;
  padding-top: 1rem; border-top: 1px solid #f0fdf4;
}
.av__btn-volver {
  display: flex; align-items: center; gap: 7px;
  background: #f1f5f9; color: #64748b; border: none;
  padding: 10px 18px; border-radius: 9px; font-size: 13px; cursor: pointer;
  transition: background .15s;
}
.av__btn-volver:hover { background: #e2e8f0; }
.av__btn-ejecutar {
  display: flex; align-items: center; gap: 8px;
  background: linear-gradient(135deg, #1b5e20, #2e7d32);
  color: #e8f5e9; border: none; padding: 11px 24px;
  border-radius: 10px; font-size: 14px; font-weight: 500;
  cursor: pointer; transition: opacity .2s;
  box-shadow: 0 2px 8px #1b5e2030;
}
.av__btn-ejecutar:hover { opacity: .88; }
.av__btn-ejecutar:disabled { opacity: .5; cursor: not-allowed; }

/* Resultado */
.av__body--resultado { text-align: center; padding: 2.5rem 2rem; }
.av__resultado-icon { font-size: 3rem; margin-bottom: 1rem; }
.av__resultado-titulo { font-size: 20px; font-weight: 600; color: #1a2e1b; margin-bottom: 1.5rem; }
.av__resultado-lista { text-align: left; margin-bottom: 2rem; display: flex; flex-direction: column; gap: 8px; }
.av__resultado-item {
  display: flex; align-items: flex-start; gap: 9px;
  padding: 10px 14px; border-radius: 10px; font-size: 14px;
}
.av__resultado-item--ok { background: #e8f5e9; color: #1b5e20; }
.av__resultado-item--err { background: #fef2f2; color: #dc2626; }
.av__btn-nueva-sesion {
  display: inline-flex; align-items: center; gap: 8px;
  background: linear-gradient(135deg, #1b5e20, #2e7d32);
  color: #e8f5e9; border: none; padding: 12px 28px;
  border-radius: 10px; font-size: 14px; font-weight: 500;
  cursor: pointer; transition: opacity .2s;
}
.av__btn-nueva-sesion:hover { opacity: .88; }

/* Transiciones */
.av-modal-enter-active, .av-modal-leave-active { transition: all .25s ease; }
.av-modal-enter-from, .av-modal-leave-to { opacity: 0; transform: scale(.97) translateY(6px); }
</style>
