<template>
  <Teleport to="body">
    <transition name="cba-fade">
      <div v-if="modelValue" class="cba-backdrop" @click="cerrar"></div>
    </transition>

    <transition name="cba-slide">
      <aside v-if="modelValue" class="cba-panel" role="dialog" aria-label="Preguntale a tu organización">

        <header class="cba-header">
          <div>
            <div class="cba-title">Preguntale a tu organización</div>
            <div class="cba-sub">Contesta con tus datos, no de memoria</div>
          </div>
          <button class="cba-close" @click="cerrar" aria-label="Cerrar">
            <X :size="18" :stroke-width="1.75" />
          </button>
        </header>

        <!-- El medidor, igual que en el dictado: donde se gasta. -->
        <div v-if="creditos" class="cba-creditos" :class="{ 'cba-creditos--aviso': creditos.avisar }">
          {{ creditos.restantes }} de {{ creditos.tope }} créditos ·
          {{ creditos.dias_restantes }} {{ creditos.dias_restantes === 1 ? 'día' : 'días' }} para que se renueven
        </div>

        <div ref="hilo" class="cba-hilo">
          <!-- Vacío: en vez de un campo en blanco que no dice qué sabe contestar, las preguntas
               que sí puede responder. El problema de estas herramientas no es que contesten mal,
               es que no se sabe qué saben. -->
          <div v-if="!turnos.length" class="cba-vacio">
            <div class="cba-vacio-titulo">¿Qué querés saber?</div>
            <button v-for="s in SUGERENCIAS" :key="s" class="cba-sugerencia" @click="preguntar(s)">
              {{ s }}
            </button>
          </div>

          <div v-for="(t, i) in turnos" :key="i" class="cba-turno" :class="`cba-turno--${t.rol}`">
            <div class="cba-burbuja">{{ t.texto }}</div>

            <!-- De dónde salió el dato. Una respuesta que no se puede auditar no se puede discutir. -->
            <div v-if="t.consultas?.length" class="cba-fuentes">
              <Database :size="11" :stroke-width="2" />
              {{ t.consultas.join(', ').replaceAll('_', ' ') }}
            </div>
          </div>

          <div v-if="cargando" class="cba-turno cba-turno--assistant">
            <div class="cba-burbuja cba-burbuja--cargando">Buscando en tus datos…</div>
          </div>

          <div v-if="error" class="cba-error">{{ error }}</div>
        </div>

        <!-- Repreguntas: cada botón cae en algo que el sistema efectivamente puede contestar. -->
        <div v-if="repreguntas.length && !cargando" class="cba-repreguntas">
          <button v-for="r in repreguntas" :key="r" class="cba-repregunta" @click="preguntar(r)">
            {{ r }}
          </button>
        </div>

        <form class="cba-input" @submit.prevent="preguntar(texto)">
          <input v-model="texto" class="cba-campo" :disabled="cargando"
                 placeholder="Preguntá sobre tu cultivo, tu producción…" />
          <button class="cba-enviar" :disabled="cargando || !texto.trim()" aria-label="Preguntar">
            <SendHorizontal :size="16" :stroke-width="2" />
          </button>
        </form>
      </aside>
    </transition>
  </Teleport>
</template>

<script setup>
// El chatbot del admin, en cajón lateral y no en modal.
//
// El modal del dictado está bien hecho para el cultivador: pantalla chica, una cosa a la vez,
// dedo. Para el admin en la compu es el formato equivocado — tapa justo los datos contra los que
// querés contrastar la respuesta, y te obliga a cerrarlo para ir a mirar lo que te contestó.
//
// Acá podés navegar con el cajón abierto: preguntás, te contesta, y vas a la sala mientras la
// respuesta sigue al costado. Mismo ancho y misma geometría que NotificationDrawer, que es el
// patrón que la barra del admin ya usa.
import { ref, watch, nextTick } from 'vue'
import { X, Database, SendHorizontal } from 'lucide-vue-next'
import { chatAsistente, consumoIA } from '../lib/api'

const props = defineProps({ modelValue: { type: Boolean, default: false } })
const emit  = defineEmits(['update:modelValue'])

const SUGERENCIAS = [
  '¿Voy a tener producto el mes que viene?',
  '¿Qué genética me rinde mejor?',
  '¿Cuál me ocupa menos la sala?',
]

const texto       = ref('')
const turnos      = ref([])
const repreguntas = ref([])
const creditos    = ref(null)
const cargando    = ref(false)
const error       = ref(null)
const hilo        = ref(null)

watch(() => props.modelValue, (abierto) => { if (abierto) refrescarCreditos() })

async function refrescarCreditos() {
  try { creditos.value = (await consumoIA()).data } catch { creditos.value = null }
}

async function preguntar(pregunta) {
  const q = (pregunta || '').trim()
  if (!q || cargando.value) return

  texto.value = ''
  error.value = null
  repreguntas.value = []
  turnos.value.push({ rol: 'user', texto: q })
  cargando.value = true
  await bajar()

  try {
    // Se manda el hilo previo para poder repreguntar ("¿y en la sala 3?"). El recorte lo hace el
    // backend: cuánta memoria se paga es una decisión de costo, no de pantalla.
    const historial = turnos.value.slice(0, -1).map(t => ({ rol: t.rol, texto: t.texto }))
    const { data } = await chatAsistente(q, historial)

    turnos.value.push({ rol: 'assistant', texto: data.texto, consultas: data.consultas })
    repreguntas.value = data.repreguntas || []
  } catch (e) {
    const status = e?.response?.status
    if (status === 429)      error.value = e?.response?.data?.error || 'Se acabaron los créditos de IA de este mes.'
    else if (status === 403) error.value = e?.response?.data?.error || 'No tenés acceso al asistente.'
    else                     error.value = e?.response?.data?.error || 'No se pudo consultar ahora mismo.'
  } finally {
    cargando.value = false
    refrescarCreditos()
    bajar()
  }
}

async function bajar() {
  await nextTick()
  if (hilo.value) hilo.value.scrollTop = hilo.value.scrollHeight
}

// La charla se descarta al cerrar: alcanza para repreguntar en el momento y no acumula historia
// que después nadie relee ni quiere pagar.
function cerrar() {
  turnos.value = []
  repreguntas.value = []
  error.value = null
  texto.value = ''
  emit('update:modelValue', false)
}
</script>

<style scoped>
.cba-backdrop { position: fixed; inset: 0; background: rgba(0,0,0,.35); z-index: 990; cursor: pointer; }

.cba-panel {
  position: fixed; top: 0; right: 0; bottom: 0;
  width: 460px; max-width: 100vw;
  background: var(--c-paper, #fff);
  z-index: 1000;
  display: flex; flex-direction: column;
  box-shadow: -8px 0 40px rgba(0,0,0,.12), -2px 0 8px rgba(0,0,0,.06);
  overflow: hidden;
}

.cba-header { display: flex; align-items: flex-start; justify-content: space-between; gap: 12px; padding: 18px 20px 14px; border-bottom: 1px solid var(--c-slate-200, #e2e8f0); }
.cba-title  { font-size: 15px; font-weight: 650; color: #1a2e1b; }
.cba-sub    { font-size: 12px; color: var(--c-slate-400, #94a3b8); margin-top: 2px; }
.cba-close  { background: var(--c-slate-100, #f1f5f9); border: none; width: 30px; height: 30px; border-radius: 8px; cursor: pointer; color: var(--c-slate-500, #64748b); display: flex; align-items: center; justify-content: center; flex-shrink: 0; }
.cba-close:hover { background: var(--c-slate-200, #e2e8f0); }

.cba-creditos { padding: 7px 20px; font-size: 11px; color: #6b8f71; background: #f8fdf8; border-bottom: 1px solid #e8f5e9; }
.cba-creditos--aviso { color: #92400e; background: #fef3c7; border-color: #fde68a; font-weight: 600; }

.cba-hilo { flex: 1; overflow-y: auto; padding: 16px 20px; display: flex; flex-direction: column; gap: 14px; }

.cba-vacio { display: flex; flex-direction: column; gap: 8px; }
.cba-vacio-titulo { font-size: 13px; color: var(--c-slate-400, #94a3b8); margin-bottom: 2px; }
.cba-sugerencia { text-align: left; background: #f8fdf8; border: 1px solid #d4e6d4; border-radius: 10px; padding: 10px 12px; font-size: 13px; color: #1b5e20; cursor: pointer; transition: background .15s; }
.cba-sugerencia:hover { background: #e8f5e9; }

.cba-turno { display: flex; flex-direction: column; gap: 4px; }
.cba-turno--user { align-items: flex-end; }
.cba-burbuja { max-width: 90%; padding: 10px 13px; border-radius: 12px; font-size: 13.5px; line-height: 1.55; white-space: pre-wrap; }
.cba-turno--user .cba-burbuja { background: #1b5e20; color: #e8f5e9; border-bottom-right-radius: 4px; }
.cba-turno--assistant .cba-burbuja { background: var(--c-slate-100, #f1f5f9); color: #1a2e1b; border-bottom-left-radius: 4px; }
.cba-burbuja--cargando { color: var(--c-slate-400, #94a3b8); font-style: italic; }

.cba-fuentes { display: flex; align-items: center; gap: 4px; font-size: 10.5px; color: var(--c-slate-400, #94a3b8); }
.cba-error { background: #fef2f2; color: #dc2626; border-radius: 8px; padding: 9px 12px; font-size: 12.5px; }

.cba-repreguntas { display: flex; flex-wrap: wrap; gap: 6px; padding: 0 20px 12px; }
.cba-repregunta { background: #fff; border: 1px solid #c8e6c9; color: #1b5e20; border-radius: 999px; padding: 5px 12px; font-size: 12px; cursor: pointer; }
.cba-repregunta:hover { background: #f0fdf4; }

.cba-input { display: flex; gap: 8px; padding: 12px 20px 16px; border-top: 1px solid var(--c-slate-200, #e2e8f0); }
.cba-campo { flex: 1; min-width: 0; border: 1.5px solid var(--c-slate-200, #e2e8f0); border-radius: 10px; padding: 9px 12px; font-size: 13px; font-family: inherit; background: var(--c-slate-50, #f8fafc); color: #0f2611; }
.cba-campo:focus { outline: none; border-color: #1b5e20; background: #fff; }
.cba-enviar { background: #1b5e20; color: #fff; border: none; width: 38px; border-radius: 10px; cursor: pointer; display: flex; align-items: center; justify-content: center; flex-shrink: 0; }
.cba-enviar:disabled { opacity: .45; cursor: not-allowed; }

.cba-fade-enter-active, .cba-fade-leave-active { transition: opacity .2s ease; }
.cba-fade-enter-from, .cba-fade-leave-to { opacity: 0; }
.cba-slide-enter-active, .cba-slide-leave-active { transition: transform .25s ease; }
.cba-slide-enter-from, .cba-slide-leave-to { transform: translateX(100%); }

@media (max-width: 520px) { .cba-panel { width: 100vw; } }
</style>
