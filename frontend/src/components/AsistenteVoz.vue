<template>
  <div class="av">
    <button class="av__trigger" :class="{ 'av__trigger--activo': abierto, 'av__trigger--mini': mini }" @click="abrir">
      <span v-if="!mini" class="av__trigger-dot" :class="{ 'av__trigger-dot--pulse': escuchando }"></span>
      <i v-if="mini" class="bi bi-mic-fill"></i>
      <span v-if="!mini">{{ triggerLabel }}</span>
    </button>

    <Teleport to="body">
      <transition name="av-modal">
        <div v-if="abierto" class="av__backdrop" @click.self="cerrar">
          <div class="av__panel">

            <div class="av__header">
              <div class="av__header-left">
                <div class="av__header-icon" :class="{ 'av__header-icon--rec': escuchando }">
                  <i :class="escuchando ? 'bi bi-mic-fill' : 'bi bi-mic'"></i>
                </div>
                <div>
                  <div class="av__header-title">Asistente de cultivo</div>
                  <div class="av__header-sub">{{ subtituloContexto }}</div>
                </div>
              </div>
              <button class="av__close" @click="cerrar"><i class="bi bi-x-lg"></i></button>
            </div>

            <div v-if="contexto" class="av__ctx-bar">
              <span v-if="contexto.lote_codigo"   class="av__ctx-chip av__ctx-chip--lote">🌿 {{ contexto.lote_codigo }}</span>
              <span v-if="contexto.sala_nombre"   class="av__ctx-chip av__ctx-chip--sala">📍 {{ contexto.sala_nombre }}</span>
              <span v-if="contexto.plantas_count" class="av__ctx-chip av__ctx-chip--plantas">🪴 {{ contexto.plantas_count }} plantas</span>
              <span v-if="contexto.planta_nombre" class="av__ctx-chip av__ctx-chip--planta">🌱 {{ contexto.planta_nombre }}</span>
            </div>

            <!-- PASO 1 -->
            <div v-if="paso === 'escuchar'" class="av__body">
              <div v-if="!escuchando && !transcripcion" class="av__idle">
                <div class="av__idle-icon">🎙️</div>
                <div class="av__idle-title">{{ idleTitle }}</div>
                <div class="av__idle-ejemplos">
                  <div v-for="ej in ejemplosContexto" :key="ej.texto" class="av__ejemplo">
                    <span class="av__ejemplo-icono">{{ ej.icono }}</span>"{{ ej.texto }}"
                  </div>
                </div>
              </div>

              <div v-if="escuchando" class="av__recording">
                <div class="av__waves">
                  <div v-for="i in 9" :key="i" class="av__wave" :style="{ animationDelay: `${i * 0.09}s` }"></div>
                </div>
                <div class="av__rec-label">Escuchando… hablá con libertad</div>
                <div v-if="transcripcionInterim" class="av__interim">"{{ transcripcionInterim }}"</div>
              </div>

              <div v-if="transcripcion && !escuchando" class="av__transcript-box">
                <div class="av__transcript-label">Escuché esto:</div>
                <div v-if="!editandoTranscripcion" class="av__transcript-text">"{{ transcripcion }}"</div>
                <textarea v-else class="av__transcript-textarea" v-model="transcripcion" rows="3"></textarea>
                <button class="av__transcript-edit" @click="editandoTranscripcion = !editandoTranscripcion">
                  <i :class="editandoTranscripcion ? 'bi bi-check' : 'bi bi-pencil'"></i>
                  {{ editandoTranscripcion ? 'Listo' : 'Editar' }}
                </button>
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
                  <i class="bi bi-stop-circle-fill"></i> Listo, procesar
                </button>
                <div v-if="procesando" class="av__procesando">
                  <div class="av__procesando-spinner"></div>
                  <span>Analizando con IA…</span>
                </div>
              </div>

              <div v-if="transcripcion && !escuchando && !procesando" class="av__procesar-directo">
                <button class="av__btn-procesar" @click="parsearConIA">
                  <i class="bi bi-cpu"></i> Procesar
                </button>
              </div>
            </div>

            <!-- PASO 2 -->
            <div v-if="paso === 'revisar'" class="av__body">
              <div class="av__resumen-header">
                <div class="av__resumen-badge">
                  <i class="bi bi-check-circle-fill"></i>
                  {{ acciones.length }} {{ acciones.length === 1 ? 'acción identificada' : 'acciones identificadas' }}
                </div>
                <div class="av__resumen-texto">{{ resumen }}</div>
              </div>

              <div class="av__acciones-lista">
                <div v-for="(accion, i) in acciones" :key="i"
                     class="av__accion"
                     :class="[`av__accion--${accion.tipo}`, accion._expandido ? 'av__accion--expandido' : '']">
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

                    <!-- Editor inline -->
                    <div v-if="accion._expandido" class="av__editor">
                      <template v-if="accion.tipo === 'registro_ambiental'">
                        <div class="av__editor-grid">
                          <div class="av__ef"><label>pH</label><input type="number" step="0.1" v-model.number="accion.datos.ph" placeholder="6.2" /></div>
                          <div class="av__ef"><label>EC</label><input type="number" step="0.1" v-model.number="accion.datos.ec" placeholder="1.8" /></div>
                          <div class="av__ef"><label>Temperatura °C</label><input type="number" step="0.1" v-model.number="accion.datos.temperatura" placeholder="24" /></div>
                          <div class="av__ef"><label>Humedad %</label><input type="number" step="1" v-model.number="accion.datos.humedad" placeholder="60" /></div>
                          <div class="av__ef av__ef--full">
                            <label>Estado general</label>
                            <select v-model="accion.datos.estado_general">
                              <option value="excelente">Excelente</option><option value="bueno">Bueno</option>
                              <option value="regular">Regular</option><option value="malo">Malo</option><option value="critico">Crítico</option>
                            </select>
                          </div>
                          <div class="av__ef av__ef--full">
                            <label><input type="checkbox" v-model="accion.datos.fertilizacion" /> Fertilización realizada</label>
                          </div>
                          <div v-if="accion.datos.fertilizacion" class="av__ef av__ef--full">
                            <label>Notas fertilización</label>
                            <input type="text" v-model="accion.datos.notas_fertilizacion" placeholder="Base A + Bloom 2 pulsos..." />
                          </div>
                          <div class="av__ef av__ef--full">
                            <label>Observaciones</label>
                            <textarea v-model="accion.datos.observaciones" rows="2" placeholder="Notas adicionales..."></textarea>
                          </div>
                        </div>
                      </template>

                      <template v-else-if="accion.tipo === 'registro_planta'">
                        <div class="av__editor-grid">
                          <div class="av__ef av__ef--full">
                            <label>Estado de salud</label>
                            <select v-model="accion.datos.estado_salud">
                              <option value="excelente">Excelente</option><option value="bueno">Bueno</option>
                              <option value="regular">Regular</option><option value="malo">Malo</option><option value="critico">Crítico</option>
                            </select>
                          </div>
                          <div class="av__ef av__ef--full">
                            <label>Color hojas</label>
                            <select v-model="accion.datos.color_hojas">
                              <option value="verde_oscuro">Verde oscuro</option><option value="verde_claro">Verde claro</option>
                              <option value="amarillo">Amarillo</option><option value="marron">Marrón</option>
                            </select>
                          </div>
                          <div class="av__ef av__ef--full">
                            <label>Plagas</label>
                            <select v-model="accion.datos.plagas">
                              <option value="ninguna">Ninguna</option><option value="leve">Leve</option>
                              <option value="moderada">Moderada</option><option value="severa">Severa</option>
                            </select>
                          </div>
                          <div class="av__ef"><label>Altura (cm)</label><input type="number" step="0.5" v-model.number="accion.datos.altura_cm" placeholder="45" /></div>
                          <div class="av__ef"><label>Colas</label><input type="number" step="1" v-model.number="accion.datos.num_colas" placeholder="4" /></div>
                          <div class="av__ef av__ef--full">
                            <label>Deficiencias</label>
                            <input type="text" v-model="accion.datos.deficiencias" placeholder="Déficit de nitrógeno..." />
                          </div>
                          <div class="av__ef av__ef--full">
                            <label>Notas</label>
                            <textarea v-model="accion.datos.notas" rows="2"></textarea>
                          </div>
                        </div>
                      </template>

                      <template v-else-if="accion.tipo === 'nota_sala' || accion.tipo === 'nota_lote'">
                        <div class="av__editor-grid">
                          <div class="av__ef av__ef--full">
                            <label>Contenido</label>
                            <textarea v-model="accion.datos.contenido" rows="3"></textarea>
                          </div>
                        </div>
                      </template>

                      <template v-else-if="accion.tipo === 'tarea'">
                        <div class="av__editor-grid">
                          <div class="av__ef av__ef--full"><label>Título</label><input type="text" v-model="accion.datos.titulo" /></div>
                          <div class="av__ef av__ef--full"><label>Descripción</label><textarea v-model="accion.datos.descripcion" rows="2"></textarea></div>
                          <div class="av__ef">
                            <label>Prioridad</label>
                            <select v-model="accion.datos.prioridad">
                              <option value="baja">Baja</option><option value="normal">Normal</option>
                              <option value="media">Media</option><option value="alta">Alta</option><option value="urgente">Urgente</option>
                            </select>
                          </div>
                          <div class="av__ef"><label>Días desde hoy</label><input type="number" step="1" min="0" v-model.number="accion.datos.dias_desde_hoy" /></div>
                        </div>
                      </template>
                    </div>
                  </div>

                  <div class="av__accion-btns">
                    <button class="av__accion-edit-btn" @click="toggleEditor(i)" :title="accion._expandido ? 'Cerrar' : 'Editar'">
                      <i :class="accion._expandido ? 'bi bi-chevron-up' : 'bi bi-pencil'"></i>
                    </button>
                    <button class="av__accion-remove-btn" @click="quitarAccion(i)" title="Quitar">
                      <i class="bi bi-x"></i>
                    </button>
                  </div>
                </div>
              </div>

              <div v-if="acciones.length === 0" class="av__vacio">No hay acciones para ejecutar.</div>

              <div class="av__revisar-footer">
                <button class="av__btn-volver" @click="volverEscuchar">
                  <i class="bi bi-arrow-counterclockwise"></i> Volver a hablar
                </button>
                <button v-if="acciones.length > 0" class="av__btn-ejecutar" @click="ejecutarAcciones" :disabled="ejecutando">
                  <span v-if="ejecutando"><i class="bi bi-hourglass-split"></i> Guardando…</span>
                  <span v-else><i class="bi bi-check-lg"></i> Guardar todo ({{ acciones.length }})</span>
                </button>
              </div>
            </div>

            <!-- PASO 3 -->
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
import { ref, computed, onMounted, onUnmounted } from 'vue'
import api from '../lib/api'

const props = defineProps({
  contexto: { type: Object, default: null },
  mini:     { type: Boolean, default: false }
})
const emit = defineEmits(['registrado'])

const abierto               = ref(false)
const paso                  = ref('escuchar')
const escuchando            = ref(false)
const procesando            = ref(false)
const ejecutando            = ref(false)
const transcripcion         = ref('')
const transcripcionInterim  = ref('')
const editandoTranscripcion = ref(false)
const resumen               = ref('')
const acciones              = ref([])
const resultados            = ref([])
const erroresEjecucion      = ref([])
const errorVoz              = ref(null)
let recognition = null

const triggerLabel = computed(() => {
  if (!props.contexto) return 'Registrar sesión'
  const t = props.contexto.tipo
  if (t === 'lote')   return '🎙️ Registrar por voz'
  if (t === 'planta') return '🎙️ Observación por voz'
  if (t === 'sala')   return '🎙️ Sesión de hoy'
  return '🎙️ Registrar'
})

const subtituloContexto = computed(() => {
  if (!props.contexto) return 'Hablá libremente — la IA distribuye todo automáticamente'
  const t = props.contexto.tipo
  if (t === 'lote')   return `Registrando en ${props.contexto.lote_codigo} · ${props.contexto.sala_nombre || ''}`
  if (t === 'planta') return `Observación para ${props.contexto.planta_nombre}`
  if (t === 'sala')   return `Sesión en ${props.contexto.sala_nombre}`
  return 'Hablá libremente'
})

const idleTitle = computed(() => {
  if (!props.contexto) return '¿Qué pasó hoy en el cultivo?'
  const t = props.contexto.tipo
  if (t === 'lote')   return `¿Qué pasó hoy en ${props.contexto.lote_codigo}?`
  if (t === 'planta') return `¿Cómo está ${props.contexto.planta_nombre}?`
  if (t === 'sala')   return `¿Qué pasó hoy en ${props.contexto.sala_nombre}?`
  return '¿Qué pasó hoy en el cultivo?'
})

const ejemplosContexto = computed(() => {
  if (!props.contexto) return [
    { icono: '💧', texto: 'Regué el lote L-26-003 con EC 1.4 pH 6.2' },
    { icono: '🌿', texto: 'La planta P012 tiene déficit de nitrógeno' },
  ]
  const t = props.contexto.tipo
  if (t === 'lote') return [
    { icono: '💧', texto: 'Regué con dos pulsos, base bloom, EC 1.8, pH 6.2' },
    { icono: '🌿', texto: 'Todas bien, un poco de amarillo en las hojas bajas' },
    { icono: '📝', texto: 'Aplicamos nutrientes de floración por primera vez' },
  ]
  if (t === 'planta') return [
    { icono: '🌿', texto: 'Hojas verdes, sin plagas, crecimiento normal' },
    { icono: '⚠️', texto: 'Amarillo en hojas bajas, posible déficit de nitrógeno' },
    { icono: '📏', texto: 'Mide 45 cm, tiene 4 colas bien formadas' },
  ]
  if (t === 'sala') return [
    { icono: '📝', texto: 'Hoy regamos todos los lotes de la sala' },
    { icono: '🌡️', texto: 'Temperatura 24 grados, humedad 60%' },
    { icono: '🌿', texto: 'Revisamos todas las plantas, sin novedades' },
  ]
  return [{ icono: '💧', texto: 'Regué el lote con EC 1.4 pH 6.2' }]
})

function abrir() { abierto.value = true }
onMounted(() => window.addEventListener('abrir-asistente-voz', abrir))
onUnmounted(() => window.removeEventListener('abrir-asistente-voz', abrir))

function cerrar() {
  if (recognition) recognition.stop()
  abierto.value = false
  resetear()
}

function resetear() {
  paso.value = 'escuchar'; escuchando.value = false; procesando.value = false
  ejecutando.value = false; transcripcion.value = ''; transcripcionInterim.value = ''
  editandoTranscripcion.value = false; resumen.value = ''; acciones.value = []
  resultados.value = []; erroresEjecucion.value = []; errorVoz.value = null
}

function iniciarGrabacion() {
  errorVoz.value = null; transcripcion.value = ''; transcripcionInterim.value = ''; editandoTranscripcion.value = false
  const SR = window.SpeechRecognition || window.webkitSpeechRecognition
  if (!SR) { errorVoz.value = 'Tu browser no soporta reconocimiento de voz. Usá Chrome.'; return }
  recognition = new SR()
  recognition.lang = 'es-AR'; recognition.continuous = true; recognition.interimResults = true
  recognition.onstart  = () => { escuchando.value = true }
  recognition.onresult = (e) => {
    let final = '', interim = ''
    for (let i = 0; i < e.results.length; i++) {
      if (e.results[i].isFinal) final += e.results[i][0].transcript
      else interim += e.results[i][0].transcript
    }
    if (final) transcripcion.value = final
    transcripcionInterim.value = interim
  }
  recognition.onerror = (e) => {
    if (e.error === 'no-speech') return
    errorVoz.value = `Error de micrófono: ${e.error}`; escuchando.value = false
  }
  recognition.onend = () => { escuchando.value = false; transcripcionInterim.value = '' }
  recognition.start()
}

function detenerGrabacion() {
  if (recognition) recognition.stop()
  escuchando.value = false; transcripcionInterim.value = ''
  if (!transcripcion.value.trim()) { errorVoz.value = 'No escuché nada. Intentá de nuevo.'; return }
  parsearConIA()
}

async function parsearConIA() {
  procesando.value = true; errorVoz.value = null; editandoTranscripcion.value = false
  try {
    const payload = { texto: transcripcion.value }
    if (props.contexto) payload.contexto = props.contexto
    const { data } = await api.post('/asistente/parsear', payload)
    resumen.value  = data.resumen || ''
    acciones.value = (data.acciones || []).map(a => ({ ...a, _expandido: false }))
    paso.value     = 'revisar'
  } catch (e) {
    errorVoz.value = e?.response?.data?.error || 'Error al procesar con IA'
  } finally {
    procesando.value = false
  }
}

function toggleEditor(i) { acciones.value[i]._expandido = !acciones.value[i]._expandido }
function quitarAccion(i) { acciones.value.splice(i, 1) }
function volverEscuchar() { paso.value = 'escuchar' }

async function ejecutarAcciones() {
  ejecutando.value = true
  try {
    const accionesLimpias = acciones.value.map(({ _expandido, ...a }) => a)
    const payload = { acciones: accionesLimpias }
    if (props.contexto) payload.contexto = props.contexto
    const { data } = await api.post('/asistente/ejecutar', payload)
    resultados.value       = data.resultados       || []
    erroresEjecucion.value = data.errores_detalle   || []
    paso.value             = 'resultado'
    emit('registrado', data)
    // Auto-cerrar después de 2.5s si todo OK
    if (!erroresEjecucion.value.length) {
      setTimeout(() => cerrar(), 2500)
    }
  } catch (e) {
    errorVoz.value = e?.response?.data?.error || 'Error al guardar'
  } finally {
    ejecutando.value = false
  }
}

function nuevaSesion() { resetear() }

function labelTipo(tipo) {
  return { registro_ambiental:'Registro ambiental', registro_planta:'Registro de planta',
    tarea:'Nueva tarea', nota_sala:'Nota de sala', nota_lote:'Nota de lote' }[tipo] || tipo
}

function descripcionAccion(accion) {
  const d = accion.datos || {}
  if (accion.tipo === 'registro_ambiental') {
    const p = []
    if (d.fertilizacion) p.push('Fertilización')
    if (d.ph)            p.push(`pH ${d.ph}`)
    if (d.ec)            p.push(`EC ${d.ec}`)
    if (d.temperatura)   p.push(`${d.temperatura}°C`)
    if (d.observaciones) p.push(d.observaciones)
    return p.join(' · ') || 'Registro ambiental'
  }
  if (accion.tipo === 'registro_planta') {
    const p = []
    if (d.estado_salud) p.push(d.estado_salud)
    if (d.deficiencias) p.push(d.deficiencias)
    if (d.plagas && d.plagas !== 'ninguna') p.push(`plagas: ${d.plagas}`)
    return p.join(' · ') || 'Observación de planta'
  }
  if (accion.tipo === 'tarea') return d.titulo || 'Tarea sin título'
  if (accion.tipo === 'nota_sala' || accion.tipo === 'nota_lote') return d.contenido || 'Nota'
  return d.observaciones || ''
}

function metaAccion(accion) {
  const d = accion.datos || {}
  if (accion.tipo === 'tarea') return `Prioridad ${d.prioridad || 'media'} · en ${d.dias_desde_hoy || 7} días`
  if (accion.tipo === 'registro_ambiental' && d.notas_fertilizacion) return d.notas_fertilizacion
  if (accion.tipo === 'registro_planta' && d.color_hojas) return `Color: ${d.color_hojas} · Plagas: ${d.plagas || 'ninguna'}`
  return ''
}
</script>

<style scoped>
.av { display: inline-block; }
.av__trigger { display:flex; align-items:center; gap:8px; background:linear-gradient(135deg,#1b5e20,#2e7d32); color:#e8f5e9; border:none; padding:8px 16px; border-radius:9px; font-size:13px; font-weight:500; cursor:pointer; transition:opacity .2s; box-shadow:0 2px 8px #1b5e2030; }
.av__trigger:hover,.av__trigger--activo { opacity:.88; }
.av__trigger--mini { width:38px; height:38px; padding:0; justify-content:center; border-radius:50%; font-size:15px; }
.av__trigger-dot { width:7px; height:7px; border-radius:50%; background:#a5d6a7; flex-shrink:0; }
.av__trigger-dot--pulse { background:#ff5252; animation:av-pulse 1s infinite; }
@keyframes av-pulse { 0%,100%{box-shadow:0 0 0 0 rgba(255,82,82,.4)} 50%{box-shadow:0 0 0 5px rgba(255,82,82,0)} }

.av__backdrop { position:fixed; inset:0; background:rgba(0,0,0,.5); backdrop-filter:blur(6px); display:flex; align-items:center; justify-content:center; z-index:2000; padding:1rem; }
.av__panel { background:white; border-radius:20px; width:100%; max-width:580px; max-height:90vh; overflow-y:auto; box-shadow:0 32px 80px rgba(0,0,0,.2); }

.av__header { display:flex; align-items:center; gap:14px; padding:20px 24px 18px; border-bottom:1px solid #f0fdf4; position:sticky; top:0; background:white; z-index:1; }
.av__header-left { display:flex; align-items:center; gap:14px; flex:1; }
.av__header-icon { width:46px; height:46px; border-radius:13px; background:#e8f5e9; display:flex; align-items:center; justify-content:center; font-size:20px; color:#1b5e20; flex-shrink:0; }
.av__header-icon--rec { background:#fef2f2; color:#dc2626; animation:av-pulse-bg 1s infinite; }
@keyframes av-pulse-bg { 0%,100%{box-shadow:0 0 0 0 rgba(220,38,38,.2)} 50%{box-shadow:0 0 0 6px rgba(220,38,38,0)} }
.av__header-title { font-size:16px; font-weight:600; color:#1a2e1b; margin-bottom:3px; }
.av__header-sub   { font-size:12px; color:#6b8f71; }
.av__close { background:#f1f5f9; border:none; width:32px; height:32px; border-radius:8px; cursor:pointer; color:#64748b; display:flex; align-items:center; justify-content:center; }
.av__close:hover { background:#e2e8f0; }

.av__ctx-bar { display:flex; flex-wrap:wrap; gap:6px; padding:8px 24px; background:#f8fdf8; border-bottom:1px solid #e8f5e9; }
.av__ctx-chip { display:inline-flex; align-items:center; gap:4px; font-size:11px; font-weight:600; padding:3px 10px; border-radius:999px; }
.av__ctx-chip--lote    { background:#dcfce7; color:#1b5e20; }
.av__ctx-chip--sala    { background:#dbeafe; color:#1e40af; }
.av__ctx-chip--plantas { background:#fef3c7; color:#92400e; }
.av__ctx-chip--planta  { background:#fce7f3; color:#9d174d; }

.av__body { padding:20px 24px 24px; }
.av__idle { text-align:center; padding:1rem 0 .5rem; }
.av__idle-icon  { font-size:3rem; margin-bottom:1rem; opacity:.35; }
.av__idle-title { font-size:16px; font-weight:500; color:#1a2e1b; margin-bottom:1.25rem; }
.av__idle-ejemplos { display:flex; flex-direction:column; gap:8px; text-align:left; }
.av__ejemplo { display:flex; align-items:flex-start; gap:10px; background:#f8fdf8; border:1px solid #e8f5e9; border-radius:10px; padding:10px 14px; font-size:13px; color:#4a7c59; font-style:italic; }
.av__ejemplo-icono { font-size:14px; flex-shrink:0; }

.av__recording { text-align:center; padding:1.5rem 0; }
.av__waves { display:flex; align-items:center; justify-content:center; gap:4px; height:52px; margin-bottom:1rem; }
.av__wave { width:4px; border-radius:2px; background:#dc2626; animation:av-wave .7s ease-in-out infinite alternate; }
.av__wave:nth-child(1){height:12px}.av__wave:nth-child(2){height:22px}.av__wave:nth-child(3){height:34px}
.av__wave:nth-child(4){height:44px}.av__wave:nth-child(5){height:52px}.av__wave:nth-child(6){height:44px}
.av__wave:nth-child(7){height:34px}.av__wave:nth-child(8){height:22px}.av__wave:nth-child(9){height:12px}
@keyframes av-wave { from{transform:scaleY(.3);opacity:.5} to{transform:scaleY(1);opacity:1} }
.av__rec-label { font-size:14px; color:#dc2626; font-weight:500; }
.av__interim   { font-size:13px; color:#94a3b8; font-style:italic; margin-top:.5rem; }

.av__transcript-box { background:#f8fdf8; border:1px solid #c8e6c9; border-radius:12px; padding:14px 16px; margin-bottom:1rem; }
.av__transcript-label { font-size:11px; color:#4a7c59; text-transform:uppercase; letter-spacing:.07em; margin-bottom:6px; }
.av__transcript-text  { font-size:14px; color:#1a2e1b; line-height:1.6; font-style:italic; }
.av__transcript-textarea { width:100%; margin-top:8px; border:1.5px solid #c8e6c9; border-radius:8px; padding:8px; font-size:13px; background:white; resize:vertical; box-sizing:border-box; font-family:inherit; }
.av__transcript-textarea:focus { outline:none; border-color:#1b5e20; }
.av__transcript-edit { display:inline-flex; align-items:center; gap:4px; margin-top:8px; background:none; border:none; font-size:12px; color:#4a7c59; cursor:pointer; padding:0; }
.av__transcript-edit:hover { color:#1b5e20; text-decoration:underline; }

.av__error { background:#fef2f2; color:#dc2626; border-radius:8px; padding:10px 14px; font-size:13px; margin-bottom:1rem; display:flex; align-items:center; gap:7px; }
.av__controles { display:flex; justify-content:center; margin-top:1rem; }
.av__btn-grabar { display:flex; align-items:center; gap:9px; background:linear-gradient(135deg,#1b5e20,#2e7d32); color:#e8f5e9; border:none; padding:14px 36px; border-radius:12px; font-size:15px; font-weight:500; cursor:pointer; box-shadow:0 4px 14px #1b5e2035; }
.av__btn-grabar:hover { opacity:.88; }
.av__btn-detener { display:flex; align-items:center; gap:9px; background:#dc2626; color:white; border:none; padding:14px 36px; border-radius:12px; font-size:15px; font-weight:500; cursor:pointer; animation:av-pulse 1.5s infinite; }
.av__procesando { display:flex; align-items:center; gap:12px; color:#4a7c59; font-size:14px; }
.av__procesando-spinner { width:28px; height:28px; border:2px solid #e8f5e9; border-top-color:#1b5e20; border-radius:50%; animation:spin .7s linear infinite; }
@keyframes spin { to{transform:rotate(360deg)} }
.av__procesar-directo { display:flex; justify-content:center; margin-top:.75rem; }
.av__btn-procesar { display:flex; align-items:center; gap:7px; background:#f0fdf4; color:#1b5e20; border:1.5px solid #c8e6c9; padding:10px 20px; border-radius:10px; font-size:13px; font-weight:500; cursor:pointer; }
.av__btn-procesar:hover { background:#dcfce7; border-color:#1b5e20; }

.av__resumen-header { margin-bottom:1.25rem; }
.av__resumen-badge { display:inline-flex; align-items:center; gap:7px; background:#e8f5e9; color:#1b5e20; border-radius:20px; font-size:12px; font-weight:600; padding:5px 14px; margin-bottom:8px; }
.av__resumen-texto { font-size:14px; color:#4a7c59; line-height:1.5; font-style:italic; }

.av__acciones-lista { display:flex; flex-direction:column; gap:10px; margin-bottom:1.5rem; }
.av__accion { display:flex; align-items:flex-start; gap:12px; border:1px solid #e8f5e9; border-radius:12px; padding:13px 14px; transition:background .15s; }
.av__accion:hover { background:#f8fdf8; }
.av__accion--expandido { border-color:#a7d7a9; background:#f0fdf4; }
.av__accion--tarea { border-color:#ffe0b2; }
.av__accion--registro_planta { border-color:#fce4ec; }
.av__accion--nota_sala,.av__accion--nota_lote { border-color:#e0e7ff; }
.av__accion-icono { font-size:20px; flex-shrink:0; margin-top:1px; }
.av__accion-body  { flex:1; min-width:0; }
.av__accion-tipo  { font-size:10px; font-weight:600; text-transform:uppercase; letter-spacing:.07em; color:#6b8f71; margin-bottom:4px; }
.av__accion--tarea .av__accion-tipo { color:#e65100; }
.av__accion--registro_planta .av__accion-tipo { color:#c2185b; }
.av__accion--nota_sala .av__accion-tipo,.av__accion--nota_lote .av__accion-tipo { color:#3730a3; }
.av__accion-titulo { font-size:14px; color:#1a2e1b; line-height:1.4; margin-bottom:3px; }
.av__accion-ref { display:inline-block; background:#f0fdf4; color:#1b5e20; font-size:11px; font-weight:600; padding:1px 7px; border-radius:4px; margin-right:6px; }
.av__accion-meta { font-size:12px; color:#94a3b8; }
.av__accion-btns { display:flex; flex-direction:column; gap:4px; flex-shrink:0; }
.av__accion-edit-btn,.av__accion-remove-btn { background:none; border:none; cursor:pointer; font-size:13px; padding:3px 5px; border-radius:5px; transition:all .15s; }
.av__accion-edit-btn   { color:#94a3b8; }
.av__accion-edit-btn:hover   { color:#1b5e20; background:#e8f5e9; }
.av__accion-remove-btn { color:#cbd5e1; }
.av__accion-remove-btn:hover { color:#dc2626; background:#fef2f2; }

.av__editor { margin-top:12px; padding-top:12px; border-top:1px solid #d4e6d4; }
.av__editor-grid { display:grid; grid-template-columns:1fr 1fr; gap:8px; }
.av__ef { display:flex; flex-direction:column; gap:3px; }
.av__ef--full { grid-column:1/-1; }
.av__ef label { font-size:10px; font-weight:700; color:#60725d; text-transform:uppercase; letter-spacing:.05em; }
.av__ef input,.av__ef select,.av__ef textarea { background:white; border:1.5px solid #d4e6d4; border-radius:7px; padding:5px 8px; font-size:13px; color:#1a1a1a; width:100%; box-sizing:border-box; font-family:inherit; }
.av__ef textarea { resize:vertical; min-height:52px; }
.av__ef input:focus,.av__ef select:focus,.av__ef textarea:focus { outline:none; border-color:#1b5e20; }

.av__vacio { text-align:center; color:#94a3b8; padding:2rem; font-size:14px; }
.av__revisar-footer { display:flex; justify-content:space-between; align-items:center; padding-top:1rem; border-top:1px solid #f0fdf4; }
.av__btn-volver { display:flex; align-items:center; gap:7px; background:#f1f5f9; color:#64748b; border:none; padding:10px 18px; border-radius:9px; font-size:13px; cursor:pointer; }
.av__btn-volver:hover { background:#e2e8f0; }
.av__btn-ejecutar { display:flex; align-items:center; gap:8px; background:linear-gradient(135deg,#1b5e20,#2e7d32); color:#e8f5e9; border:none; padding:11px 24px; border-radius:10px; font-size:14px; font-weight:500; cursor:pointer; box-shadow:0 2px 8px #1b5e2030; }
.av__btn-ejecutar:hover { opacity:.88; }
.av__btn-ejecutar:disabled { opacity:.5; cursor:not-allowed; }

.av__body--resultado { text-align:center; padding:2.5rem 2rem; }
.av__resultado-icon   { font-size:3rem; margin-bottom:1rem; }
.av__resultado-titulo { font-size:20px; font-weight:600; color:#1a2e1b; margin-bottom:1.5rem; }
.av__resultado-lista  { text-align:left; margin-bottom:2rem; display:flex; flex-direction:column; gap:8px; }
.av__resultado-item { display:flex; align-items:flex-start; gap:9px; padding:10px 14px; border-radius:10px; font-size:14px; }
.av__resultado-item--ok  { background:#e8f5e9; color:#1b5e20; }
.av__resultado-item--err { background:#fef2f2; color:#dc2626; }
.av__btn-nueva-sesion { display:inline-flex; align-items:center; gap:8px; background:linear-gradient(135deg,#1b5e20,#2e7d32); color:#e8f5e9; border:none; padding:12px 28px; border-radius:10px; font-size:14px; font-weight:500; cursor:pointer; }
.av__btn-nueva-sesion:hover { opacity:.88; }

.av-modal-enter-active,.av-modal-leave-active { transition:all .25s ease; }
.av-modal-enter-from,.av-modal-leave-to { opacity:0; transform:scale(.97) translateY(6px); }
</style>
