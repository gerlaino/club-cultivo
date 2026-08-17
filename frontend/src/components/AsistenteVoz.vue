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
              <button class="av__mute" @click="muteTTS = !muteTTS" :title="muteTTS ? 'Activar voz' : 'Silenciar'">
                <i :class="muteTTS ? 'bi bi-volume-mute-fill' : 'bi bi-volume-up-fill'"></i>
              </button>
              <button class="av__close" @click="cerrar"><i class="bi bi-x-lg"></i></button>
            </div>

            <!-- El medidor va acá, donde se gasta. En una pantalla de configuración no lo mira
                 nadie, y la idea es que se sepa cuánto queda ANTES de quedarse sin, no al
                 chocar. Sólo aparece si el backend contestó: si falla, se dicta igual. -->
            <div v-if="creditos" class="av__creditos" :class="{ 'av__creditos--aviso': creditos.avisar }">
              <div class="av__creditos-barra">
                <div class="av__creditos-usado" :style="{ width: `${creditos.porcentaje}%` }"></div>
              </div>
              <span class="av__creditos-texto">
                {{ creditos.restantes }} de {{ creditos.tope }} créditos ·
                {{ creditos.dias_restantes }} {{ creditos.dias_restantes === 1 ? 'día' : 'días' }} para que se renueven
              </span>
            </div>

            <div v-if="contexto" class="av__ctx-bar">
              <span v-if="contexto.lote_codigo"   class="av__ctx-chip av__ctx-chip--lote">🌿 {{ contexto.lote_codigo }}</span>
              <span v-if="contexto.sala_nombre"   class="av__ctx-chip av__ctx-chip--sala">📍 {{ contexto.sala_nombre }}</span>
              <span v-if="contexto.plantas_count" class="av__ctx-chip av__ctx-chip--plantas">🪴 {{ contexto.plantas_count }} plantas</span>
              <span v-if="contexto.planta_nombre" class="av__ctx-chip av__ctx-chip--planta">🌱 {{ contexto.planta_nombre }}</span>
            </div>

            <!-- Modo -->
            <div class="av__modo-tabs">
              <button :class="['av__modo-tab', { 'av__modo-tab--active': modo === 'registro' }]" @click="modo = 'registro'">
                <i class="bi bi-mic"></i> Registrar
              </button>
              <button :class="['av__modo-tab', { 'av__modo-tab--active': modo === 'consulta' }]" @click="modo = 'consulta'; errorVoz = null">
                <i class="bi bi-chat-dots"></i> Consultar IA
              </button>
            </div>

            <!-- PASO 1 -->
            <div v-if="modo === 'registro' && paso === 'escuchar'" class="av__body">
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
                <div class="av__rec-label">Escuchando… tocá el botón cuando termines</div>
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

              <!-- El dictado del navegador depende de un servicio remoto que puede fallar o
                   estar bloqueado. Que falle no puede dejar sin registrar: se escribe a mano y
                   la IA lo interpreta igual. El micrófono del teclado del teléfono es del
                   sistema operativo y anda incluso cuando el del navegador no. -->
              <div v-if="errorVoz && !escuchando" class="av__manual">
                <label class="av__manual-label" for="av-manual">Escribilo o dictalo con el teclado</label>
                <textarea id="av-manual" class="av__manual-input" v-model="transcripcion" rows="3"
                  placeholder="Regué con dos pulsos, EC 1.8, pH 6.2…"></textarea>
              </div>

              <div class="av__controles">
                <button v-if="!procesando"
                  class="av__btn-ptt"
                  :class="{ 'av__btn-ptt--rec': escuchando }"
                  @click="alternarMicrofono">
                  <i :class="escuchando ? 'bi bi-stop-circle-fill' : 'bi bi-mic-fill'"></i>
                  <span>{{ escuchando ? 'Tocá para terminar' : (transcripcion ? 'Volver a grabar' : 'Tocá y hablá') }}</span>
                </button>
                <div v-if="procesando" class="av__procesando">
                  <DsSpinner :size="28" />
                  <span>Analizando con IA…</span>
                </div>
              </div>

              <div v-if="transcripcion.trim() && !escuchando && !procesando" class="av__procesar-directo">
                <button class="av__btn-procesar" @click="parsearConIA">
                  <i class="bi bi-cpu"></i> Procesar
                </button>
              </div>
            </div>

            <!-- PASO 2 -->
            <div v-if="modo === 'registro' && paso === 'revisar'" class="av__body">
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
                    <span v-else-if="accion.tipo === 'registro_ambiental_sala'">🏠💧</span>
                    <span v-else-if="accion.tipo === 'registro_planta'">🌿</span>
                    <span v-else-if="accion.tipo === 'tarea'">📋</span>
                    <span v-else-if="accion.tipo === 'avance_ciclo'">🔄</span>
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
                      <template v-if="accion.tipo === 'registro_ambiental' || accion.tipo === 'registro_ambiental_sala'">
                        <div v-if="accion.tipo === 'registro_ambiental_sala'" class="av__sala-badge">
                          Se guardará en todos los lotes activos de la sala
                        </div>
                        <div class="av__editor-grid">
                          <div class="av__ef av__ef--full">
                            <label>Actividades realizadas</label>
                            <div class="av__tareas-chips">
                              <button v-for="t in TAREAS_OPCIONES" :key="t.key" type="button"
                                class="av__tarea-chip"
                                :class="{ 'av__tarea-chip--on': (accion.datos.tareas_realizadas||[]).includes(t.key) }"
                                @click="toggleTarea(accion, t.key)">
                                {{ t.emoji }} {{ t.label }}
                              </button>
                            </div>
                          </div>
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
                            <label><input type="checkbox" v-model="accion.datos.fertilizacion" /> Fertilización / nutrientes aplicados</label>
                          </div>
                          <div v-if="accion.datos.fertilizacion" class="av__ef av__ef--full">
                            <label>Notas nutrición</label>
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
            <div v-if="modo === 'registro' && paso === 'resultado'" class="av__body av__body--resultado">
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

            <!-- MODO CONSULTA -->
            <div v-if="modo === 'consulta'" class="av__body av__consulta-body">
              <div class="av__consulta-area">
                <textarea class="av__consulta-input" v-model="consultaTexto" :placeholder="consultaPlaceholder" rows="3"></textarea>
                <div class="av__consulta-btns">
                  <button v-if="!escuchando" class="av__consulta-voz" @click="iniciarGrabacionConsulta" :disabled="consultandoIA">
                    <i class="bi bi-mic"></i>
                  </button>
                  <button v-else class="av__consulta-voz av__consulta-voz--rec" @click="detenerGrabacionConsulta">
                    <i class="bi bi-stop-circle-fill"></i>
                  </button>
                  <button class="av__consulta-enviar" @click="enviarConsulta" :disabled="consultandoIA || !consultaTexto.trim()">
                    <DsSpinner v-if="consultandoIA" :size="12" />
                    <i v-else class="bi bi-send-fill"></i>
                    {{ consultandoIA ? 'Consultando…' : 'Preguntar' }}
                  </button>
                </div>
              </div>
              <div v-if="escuchando && modo === 'consulta'" class="av__consulta-escuchando">
                <div class="av__waves av__waves--sm">
                  <div v-for="i in 5" :key="i" class="av__wave" :style="{ animationDelay: `${i * 0.1}s` }"></div>
                </div>
                <span>Escuchando…</span>
              </div>
              <div v-if="errorVoz && modo === 'consulta'" class="av__error"><i class="bi bi-exclamation-triangle"></i> {{ errorVoz }}</div>
              <div v-if="consultaRespuesta" class="av__consulta-respuesta">
                <div class="av__consulta-resp-label"><i class="bi bi-robot"></i> Agrónomo IA</div>
                <div class="av__consulta-resp-body">{{ consultaRespuesta }}</div>
                <button class="av__consulta-nueva" @click="consultaTexto = ''; consultaRespuesta = ''">
                  <i class="bi bi-arrow-counterclockwise"></i> Nueva pregunta
                </button>
              </div>
              <div v-if="!consultaRespuesta && !consultandoIA && !errorVoz" class="av__consulta-idle">
                <div class="av__consulta-ej">💬 ¿Cómo viene el lote? ¿Debería ajustar el EC?</div>
                <div class="av__consulta-ej">🔬 ¿Hay señales de deficiencia en estas mediciones?</div>
                <div class="av__consulta-ej">📅 ¿Cuándo convendría pasar a floración?</div>
              </div>
            </div>

          </div>
        </div>
      </transition>
    </Teleport>
  </div>
</template>

<script setup>
import { ref, computed, watch, onMounted, onUnmounted } from 'vue'
import api, { consumoIA } from '../lib/api'
import DsSpinner from '../design-system/components/Spinner.vue'
import { useReconocimientoVoz } from '../composables/useReconocimientoVoz.js'

const props = defineProps({
  contexto: { type: Object, default: null },
  mini:     { type: Boolean, default: false }
})

const TAREAS_OPCIONES = [
  { key: 'riego',           label: 'Riego',        emoji: '💧' },
  { key: 'nutricion',       label: 'Nutrición',    emoji: '🧪' },
  { key: 'poda',            label: 'Poda',         emoji: '✂️' },
  { key: 'defoliacion',     label: 'Defoliación',  emoji: '🍃' },
  { key: 'scrog_lst',       label: 'SCROG/LST',    emoji: '🪢' },
  { key: 'revision_plagas', label: 'Rev. plagas',  emoji: '🔍' },
  { key: 'limpieza_sala',   label: 'Limpieza',     emoji: '🧹' },
  { key: 'ajuste_luz',      label: 'Luz',          emoji: '💡' },
]

function toggleTarea(accion, key) {
  if (!accion.datos.tareas_realizadas) accion.datos.tareas_realizadas = []
  const idx = accion.datos.tareas_realizadas.indexOf(key)
  if (idx === -1) accion.datos.tareas_realizadas.push(key)
  else accion.datos.tareas_realizadas.splice(idx, 1)
}
const emit = defineEmits(['registrado'])

const abierto               = ref(false)
const modo                  = ref('registro')
const paso                  = ref('escuchar')
const procesando            = ref(false)
const ejecutando            = ref(false)
const transcripcion         = ref('')
const editandoTranscripcion = ref(false)
const resumen               = ref('')
const acciones              = ref([])
const resultados            = ref([])
const erroresEjecucion      = ref([])
const errorVoz              = ref(null)
const muteTTS               = ref(false)

// Consulta mode
const consultaTexto     = ref('')
const consultaRespuesta = ref('')
const consultandoIA     = ref(false)

const consultaPlaceholder = computed(() => {
  if (!props.contexto) return '¿Qué querés saber del cultivo?'
  const t = props.contexto.tipo
  if (t === 'lote')   return `¿Cómo viene ${props.contexto.lote_codigo}? ¿Algo que deba revisar?`
  if (t === 'planta') return `¿Qué opinás del estado de ${props.contexto.planta_nombre}?`
  if (t === 'sala')   return `¿Cómo están los lotes en ${props.contexto.sala_nombre}?`
  return '¿Qué querés saber del cultivo?'
})

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

// Cuántos créditos de IA le quedan a la organización este mes. Null = no se pudo pedir, y
// entonces el medidor no se muestra: quedarse sin medidor no puede impedir registrar.
const creditos = ref(null)

async function refrescarCreditos() {
  try {
    creditos.value = (await consumoIA()).data
  } catch {
    creditos.value = null
  }
}

function abrir() {
  abierto.value = true
  refrescarCreditos()
}

// Instancias contextuales (sala, lote) ignoran el evento global — solo abren via su propio trigger.
// El check es runtime (no en onMounted) para evitar edge-cases de timing con computed props.
function abrirDesdeEvento() { if (!props.contexto) abrir() }

function avEscapeHandler(e) {
  if (e.key === 'Escape' && abierto.value) cerrar()
}

onMounted(() => {
  window.addEventListener('abrir-asistente-voz', abrirDesdeEvento)
  document.addEventListener('keydown', avEscapeHandler, true)
})
onUnmounted(() => {
  window.removeEventListener('abrir-asistente-voz', abrirDesdeEvento)
  document.removeEventListener('keydown', avEscapeHandler, true)
})

// Un solo dictado para todo el panel: registro y consulta comparten motor y comparten el
// mismo cartel de error. Antes eran dos copias del mismo setup que trataban distinto los
// mismos casos de borde.
const voz = useReconocimientoVoz({
  alTerminar: (dicho, porPedido) => {
    if (modo.value === 'consulta') {
      consultaTexto.value = dicho
      // La pregunta se manda sólo si la persona dio por terminado el dictado. Si el servicio
      // cortó solo en una pausa, se deja escrita: mandar media pregunta gasta una llamada de IA
      // (que se mide y se cobra) para una respuesta que no sirve.
      if (porPedido) enviarConsulta()
    } else {
      transcripcion.value = dicho
      // Mismo criterio que la consulta: sólo se procesa si la persona dio por terminado. Cuando
      // el motor se rinde solo (se quedó sin reintentos, o se cayó la red a mitad de frase) lo
      // dictado queda escrito y a la vista con el botón "Procesar" al lado. Mandarlo igual
      // gastaría una llamada de IA —que se mide y se cobra— para registrar media frase, y el
      // registro malo después hay que borrarlo a mano.
      if (porPedido) parsearConIA()
    }
  },
})
const escuchando           = voz.escuchando
const transcripcionInterim = voz.interim

// El motor avisa cuando termina, no cuando se le pide parar: `stop()` es asíncrono y el motivo
// real recién se conoce en `onend`. Leerlo justo después de cortar traía siempre null.
watch(voz.error, (e) => { if (e) errorVoz.value = e })

function cerrar() {
  voz.cancelar()
  window.speechSynthesis?.cancel()
  abierto.value = false
  resetear()
}

function resetear() {
  voz.cancelar(); voz.limpiar()
  paso.value = 'escuchar'; procesando.value = false
  ejecutando.value = false; transcripcion.value = ''
  editandoTranscripcion.value = false; resumen.value = ''; acciones.value = []
  resultados.value = []; erroresEjecucion.value = []; errorVoz.value = null
}

async function iniciarGrabacion() {
  errorVoz.value = null
  editandoTranscripcion.value = false
  if (modo.value === 'registro') transcripcion.value = ''
  voz.limpiar()
  await voz.iniciar()
}

function detenerGrabacion() { voz.detener() }

// Un toque para arrancar y otro para parar. Era "mantené presionado" con `pointerleave`: el
// dedo se corría unos píxeles mientras hablabas y la grabación se cortaba sola, y un toque
// corto soltaba antes de que el servicio llegara a escuchar. Las dos cosas terminaban en una
// transcripción vacía sin ninguna explicación.
function alternarMicrofono() {
  if (procesando.value) return
  if (escuchando.value) detenerGrabacion()
  else                  iniciarGrabacion()
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
    hablar((resumen.value || 'Listo') + '. ¿Confirmás?')
  } catch (e) {
    const status = e?.response?.status
    if (status === 403) {
      errorVoz.value = e?.response?.data?.error || 'El asistente de IA no está disponible en tu plan.'
    } else if (status === 429) {
      errorVoz.value = 'Límite de uso alcanzado. Volvé en unos minutos.'
    } else {
      errorVoz.value = e?.response?.data?.error || 'Error al procesar con IA'
    }
  } finally {
    procesando.value = false
    // Se refresca también cuando falló: una llamada rechazada por tope tiene que dejar el
    // medidor en cero, no en el número de antes.
    refrescarCreditos()
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

function hablar(texto) {
  if (muteTTS.value || !window.speechSynthesis) return
  window.speechSynthesis.cancel()
  const utt = new SpeechSynthesisUtterance(texto)
  utt.lang = 'es-AR'
  utt.rate = 1.0
  window.speechSynthesis.speak(utt)
}

function iniciarGrabacionConsulta() { iniciarGrabacion() }
function detenerGrabacionConsulta()  { detenerGrabacion() }

async function enviarConsulta() {
  if (!consultaTexto.value.trim()) return
  consultandoIA.value = true; errorVoz.value = null; consultaRespuesta.value = ''
  try {
    const payload = { texto: consultaTexto.value }
    if (props.contexto) payload.contexto = props.contexto
    const { data } = await api.post('/asistente/consultar', payload)
    consultaRespuesta.value = data.respuesta || ''
  } catch (e) {
    const status = e?.response?.status
    if (status === 403) errorVoz.value = e?.response?.data?.error || 'IA no disponible en tu plan.'
    else if (status === 429) errorVoz.value = 'Límite de uso alcanzado. Volvé en unos minutos.'
    else errorVoz.value = e?.response?.data?.error || 'Error al consultar IA'
  } finally {
    consultandoIA.value = false
    refrescarCreditos()
  }
}

function labelTipo(tipo) {
  return {
    registro_ambiental:      'Registro ambiental',
    registro_ambiental_sala: 'Registro ambiental · toda la sala',
    registro_planta:         'Registro de planta',
    tarea:                   'Nueva tarea',
    nota_sala:               'Nota de sala',
    nota_lote:               'Nota de lote',
    avance_ciclo:            'Avance de ciclo',
  }[tipo] || tipo
}

function descripcionAccion(accion) {
  const d = accion.datos || {}
  if (accion.tipo === 'registro_ambiental' || accion.tipo === 'registro_ambiental_sala') {
    const p = []
    if (d.fertilizacion) p.push('Fertilización')
    if (d.ph)            p.push(`pH ${d.ph}`)
    if (d.ec)            p.push(`EC ${d.ec}`)
    if (d.temperatura)   p.push(`${d.temperatura}°C`)
    if (d.humedad)       p.push(`${d.humedad}% HR`)
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
  if (accion.tipo === 'avance_ciclo') return d.estado_nuevo ? `→ ${d.estado_nuevo}` : 'Avance de estado'
  return d.observaciones || ''
}

function metaAccion(accion) {
  const d = accion.datos || {}
  if (accion.tipo === 'tarea') return `Prioridad ${d.prioridad || 'media'} · en ${d.dias_desde_hoy || 7} días`
  if ((accion.tipo === 'registro_ambiental' || accion.tipo === 'registro_ambiental_sala') && d.notas_fertilizacion) return d.notas_fertilizacion
  if (accion.tipo === 'registro_planta' && d.color_hojas) return `Color: ${d.color_hojas} · Plagas: ${d.plagas || 'ninguna'}`
  return ''
}
</script>

<style scoped>
/* ── Modo tabs ─────────────────────────────────────────────────────── */
.av__modo-tabs { display:flex; gap:.25rem; padding:.5rem 1.25rem .25rem; }
.av__modo-tab { display:flex; align-items:center; gap:.35rem; padding:.35rem .875rem; border-radius:7px; border:none; background:none; font-size:.8rem; font-weight:600; color:#60725d; cursor:pointer; transition:all .12s; }
.av__modo-tab--active { background:#1b5e20; color:#fff; }
.av__modo-tab:not(.av__modo-tab--active):hover { background:#f0fdf4; color:#1b5e20; }

/* ── Consulta body ─────────────────────────────────────────────────── */
.av__consulta-body { display:flex; flex-direction:column; gap:1rem; }
.av__consulta-area { display:flex; flex-direction:column; gap:.5rem; }
.av__consulta-input { width:100%; border:1.5px solid var(--c-slate-200); border-radius:10px; padding:.7rem .9rem; font-size:.875rem; font-family:inherit; resize:vertical; box-sizing:border-box; background:var(--c-slate-50); color:#0f2611; }
.av__consulta-input:focus { outline:none; border-color:#1b5e20; background:#fff; }
.av__consulta-btns { display:flex; gap:.5rem; justify-content:flex-end; }
.av__consulta-voz { width:36px; height:36px; border:1.5px solid var(--c-slate-200); border-radius:8px; background:var(--c-slate-50); color:#60725d; cursor:pointer; display:flex; align-items:center; justify-content:center; font-size:.9rem; transition:all .12s; flex-shrink:0; }
.av__consulta-voz:hover { border-color:#1b5e20; color:#1b5e20; }
.av__consulta-voz--rec { background:#fef2f2; border-color:#fecaca; color:#dc2626; animation:av-pulse 1s infinite; }
.av__consulta-enviar { display:flex; align-items:center; gap:.4rem; background:#1b5e20; color:#fff; border:none; padding:.5rem 1rem; border-radius:8px; font-size:.82rem; font-weight:700; cursor:pointer; transition:opacity .15s; }
.av__consulta-enviar:disabled { opacity:.5; cursor:not-allowed; }
.av__consulta-escuchando { display:flex; align-items:center; gap:.75rem; padding:.5rem .75rem; background:#f0fdf4; border-radius:8px; font-size:.8rem; color:#1b5e20; font-weight:600; }
.av__waves--sm { display:flex; align-items:center; gap:2px; height:18px; }
.av__consulta-respuesta { background:#f6faf6; border:1px solid #c8e6c9; border-radius:10px; padding:1rem 1.1rem; display:flex; flex-direction:column; gap:.75rem; }
.av__consulta-resp-label { font-size:.72rem; font-weight:700; color:#1b5e20; text-transform:uppercase; letter-spacing:.05em; display:flex; align-items:center; gap:.35rem; }
.av__consulta-resp-body { font-size:.875rem; color:#1a2e1a; line-height:1.65; white-space:pre-wrap; }
.av__consulta-nueva { align-self:flex-start; display:flex; align-items:center; gap:.35rem; background:transparent; color:#1b5e20; border:1.5px solid #a5d6a7; padding:.35rem .75rem; border-radius:7px; font-size:.78rem; font-weight:600; cursor:pointer; }
.av__consulta-nueva:hover { background:#f0fdf4; }
.av__consulta-idle { display:flex; flex-direction:column; gap:.4rem; }
.av__consulta-ej { font-size:.8rem; color:var(--c-slate-400); font-style:italic; padding:.15rem 0; }

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
.av__close { background:var(--c-slate-100); border:none; width:32px; height:32px; border-radius:8px; cursor:pointer; color:var(--c-slate-500); display:flex; align-items:center; justify-content:center; }
.av__close:hover { background:var(--c-slate-200); }

.av__ctx-bar { display:flex; flex-wrap:wrap; gap:6px; padding:8px 24px; background:#f8fdf8; border-bottom:1px solid #e8f5e9; }
.av__ctx-chip { display:inline-flex; align-items:center; gap:4px; font-size:11px; font-weight:600; padding:3px 10px; border-radius:999px; }
.av__ctx-chip--lote    { background:#dcfce7; color:#1b5e20; }
.av__ctx-chip--sala    { background:#dbeafe; color:#1e40af; }
.av__ctx-chip--plantas { background:#fef3c7; color:#92400e; }
.av__ctx-chip--planta  { background:#fce7f3; color:#9d174d; }

/* ── Medidor de créditos ───────────────────────────────────────────
   Discreto a propósito: un número que sólo baja y grita da miedo, y termina en que nadie usa el
   asistente. Se vuelve ámbar recién en el 80%, que es cuando enterarse sirve de algo. */
.av__creditos { display:flex; flex-direction:column; gap:5px; padding:8px 24px 10px; border-bottom:1px solid #e8f5e9; }
.av__creditos-barra { height:4px; border-radius:2px; background:#e8f5e9; overflow:hidden; }
.av__creditos-usado { height:100%; border-radius:2px; background:#1b5e20; transition:width .3s ease; }
.av__creditos-texto { font-size:11px; color:#6b8f71; }
.av__creditos--aviso .av__creditos-barra { background:#fef3c7; }
.av__creditos--aviso .av__creditos-usado { background:#b45309; }
.av__creditos--aviso .av__creditos-texto { color:#92400e; font-weight:600; }

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
.av__interim   { font-size:13px; color:var(--c-slate-400); font-style:italic; margin-top:.5rem; }

.av__transcript-box { background:#f8fdf8; border:1px solid #c8e6c9; border-radius:12px; padding:14px 16px; margin-bottom:1rem; }
.av__transcript-label { font-size:11px; color:#4a7c59; text-transform:uppercase; letter-spacing:.07em; margin-bottom:6px; }
.av__transcript-text  { font-size:14px; color:#1a2e1b; line-height:1.6; font-style:italic; }
.av__transcript-textarea { width:100%; margin-top:8px; border:1.5px solid #c8e6c9; border-radius:8px; padding:8px; font-size:13px; background:white; resize:vertical; box-sizing:border-box; font-family:inherit; }
.av__transcript-textarea:focus { outline:none; border-color:#1b5e20; }
.av__transcript-edit { display:inline-flex; align-items:center; gap:4px; margin-top:8px; background:none; border:none; font-size:12px; color:#4a7c59; cursor:pointer; padding:0; }
.av__transcript-edit:hover { color:#1b5e20; text-decoration:underline; }

.av__manual { display:flex; flex-direction:column; gap:.35rem; margin-bottom:1rem; }
.av__manual-label { font-size:11px; font-weight:700; color:#60725d; text-transform:uppercase; letter-spacing:.05em; }
.av__manual-input { width:100%; box-sizing:border-box; border:1.5px solid #c8e6c9; border-radius:10px; padding:.6rem .75rem; font-size:13px; font-family:inherit; resize:vertical; background:#f8fdf8; color:#1a2e1b; }
.av__manual-input:focus { outline:none; border-color:#1b5e20; background:#fff; }
.av__error { background:#fef2f2; color:#dc2626; border-radius:8px; padding:10px 14px; font-size:13px; margin-bottom:1rem; display:flex; align-items:center; gap:7px; }
.av__controles { display:flex; justify-content:center; margin-top:1rem; }
.av__btn-grabar { display:flex; align-items:center; gap:9px; background:linear-gradient(135deg,#1b5e20,#2e7d32); color:#e8f5e9; border:none; padding:14px 36px; border-radius:12px; font-size:15px; font-weight:500; cursor:pointer; box-shadow:0 4px 14px #1b5e2035; }
.av__btn-grabar:hover { opacity:.88; }
.av__btn-detener { display:flex; align-items:center; gap:9px; background:#dc2626; color:white; border:none; padding:14px 36px; border-radius:12px; font-size:15px; font-weight:500; cursor:pointer; animation:av-pulse 1.5s infinite; }
.av__btn-ptt { display:flex; flex-direction:column; align-items:center; justify-content:center; gap:8px; background:linear-gradient(135deg,#1b5e20,#2e7d32); color:#e8f5e9; border:none; padding:22px 52px; border-radius:16px; font-size:15px; font-weight:600; cursor:pointer; box-shadow:0 4px 14px #1b5e2035; touch-action:manipulation; user-select:none; -webkit-user-select:none; transition:all .12s; min-width:220px; }
.av__btn-ptt i { font-size:28px; }
.av__btn-ptt:hover:not(:disabled) { opacity:.88; }
.av__btn-ptt--rec { background:#dc2626; color:white; animation:av-pulse 1.5s infinite; }
.av__btn-ptt:disabled { opacity:.5; cursor:not-allowed; }
.av__mute { background:none; border:none; width:32px; height:32px; border-radius:8px; cursor:pointer; color:var(--c-slate-400); display:flex; align-items:center; justify-content:center; font-size:14px; transition:all .15s; flex-shrink:0; }
.av__mute:hover { background:var(--c-slate-100); color:var(--c-slate-500); }
.av__procesando { display:flex; align-items:center; gap:12px; color:#4a7c59; font-size:14px; }
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
.av__accion--registro_ambiental_sala { border-color:#bae6fd; background:#f0f9ff; }
.av__accion--nota_sala,.av__accion--nota_lote { border-color:#e0e7ff; }
.av__accion--avance_ciclo { border-color:#d1fae5; background:#f0fdf4; }
.av__accion-icono { font-size:20px; flex-shrink:0; margin-top:1px; }
.av__accion-body  { flex:1; min-width:0; }
.av__accion-tipo  { font-size:10px; font-weight:600; text-transform:uppercase; letter-spacing:.07em; color:#6b8f71; margin-bottom:4px; }
.av__accion--tarea .av__accion-tipo { color:#e65100; }
.av__accion--registro_planta .av__accion-tipo { color:#c2185b; }
.av__accion--registro_ambiental_sala .av__accion-tipo { color:#0369a1; }
.av__accion--nota_sala .av__accion-tipo,.av__accion--nota_lote .av__accion-tipo { color:#3730a3; }
.av__sala-badge { font-size:11px; color:#0369a1; background:#e0f2fe; border-radius:6px; padding:4px 10px; margin-bottom:10px; display:inline-block; }
.av__accion-titulo { font-size:14px; color:#1a2e1b; line-height:1.4; margin-bottom:3px; }
.av__accion-ref { display:inline-block; background:#f0fdf4; color:#1b5e20; font-size:11px; font-weight:600; padding:1px 7px; border-radius:4px; margin-right:6px; }
.av__accion-meta { font-size:12px; color:var(--c-slate-400); }
.av__accion-btns { display:flex; flex-direction:column; gap:4px; flex-shrink:0; }
.av__accion-edit-btn,.av__accion-remove-btn { background:none; border:none; cursor:pointer; font-size:13px; padding:3px 5px; border-radius:5px; transition:all .15s; }
.av__accion-edit-btn   { color:var(--c-slate-400); }
.av__accion-edit-btn:hover   { color:#1b5e20; background:#e8f5e9; }
.av__accion-remove-btn { color:var(--c-slate-300); }
.av__accion-remove-btn:hover { color:#dc2626; background:#fef2f2; }

.av__editor { margin-top:12px; padding-top:12px; border-top:1px solid #d4e6d4; }
.av__editor-grid { display:grid; grid-template-columns:1fr 1fr; gap:8px; }
.av__ef { display:flex; flex-direction:column; gap:3px; }
.av__ef--full { grid-column:1/-1; }
.av__ef label { font-size:10px; font-weight:700; color:#60725d; text-transform:uppercase; letter-spacing:.05em; }
.av__ef input,.av__ef select,.av__ef textarea { background:white; border:1.5px solid #d4e6d4; border-radius:7px; padding:5px 8px; font-size:13px; color:#1a1a1a; width:100%; box-sizing:border-box; font-family:inherit; }
.av__tareas-chips { display:flex; flex-wrap:wrap; gap:5px; margin-top:3px; }
.av__tarea-chip { display:inline-flex; align-items:center; gap:4px; padding:4px 9px; border:1.5px solid #d4e6d4; border-radius:999px; background:#f8fdf8; font-size:12px; cursor:pointer; transition:all .15s; color:#4a7c59; }
.av__tarea-chip:hover { border-color:#1b5e20; }
.av__tarea-chip--on { background:#dcfce7; border-color:#1b5e20; color:#14532d; font-weight:600; }
.av__ef textarea { resize:vertical; min-height:52px; }
.av__ef input:focus,.av__ef select:focus,.av__ef textarea:focus { outline:none; border-color:#1b5e20; }

.av__vacio { text-align:center; color:var(--c-slate-400); padding:2rem; font-size:14px; }
.av__revisar-footer { display:flex; justify-content:space-between; align-items:center; padding-top:1rem; border-top:1px solid #f0fdf4; }
.av__btn-volver { display:flex; align-items:center; gap:7px; background:var(--c-slate-100); color:var(--c-slate-500); border:none; padding:10px 18px; border-radius:9px; font-size:13px; cursor:pointer; }
.av__btn-volver:hover { background:var(--c-slate-200); }
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
