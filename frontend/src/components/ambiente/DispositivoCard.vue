<script setup>
import { ref, computed } from 'vue'
import { useAmbienteStore } from '../../stores/ambiente.js'
import { useToast } from '../../composables/useToast.js'
import { useConfirm } from '../../composables/useConfirm.js'

const props = defineProps({
  dispositivo: { type: Object, required: true },
})

const emit = defineEmits(['deleted'])
const toast        = useToast()
const { confirm }  = useConfirm()
const ambienteStore = useAmbienteStore()

const showToken   = ref(false)
const regenerando = ref(false)
const showGuide   = ref(false)
const tokenPlain  = ref(null)

const TIPO_LABEL = {
  sonoff_th:  'Sonoff TH Elite',
  pulse:      'Bluelab Pulse',
  bluelab:    'Bluelab',
  tuya_plug:  'Tuya / Smart Life',
  shelly_plug:'Shelly',
  melcloud_ac:'Mitsubishi MelCloud',
  daikin:     'Daikin AC',
  generic:    'Genérico (HTTP)',
}

const webhookUrl = computed(() => {
  const base = window.location.origin
  return `${base}/webhooks/lecturas?dispositivo_id=${props.dispositivo.id}`
})

const hasGuide = computed(() => ['sonoff_th', 'generic', 'shelly_plug', 'tuya_plug'].includes(props.dispositivo.tipo))

async function regenerar() {
  const ok = await confirm({ title: '¿Regenerar token?', message: 'El token anterior dejará de funcionar de inmediato.', confirmText: 'Regenerar', variant: 'danger' })
  if (!ok) return
  regenerando.value = true
  try {
    const res = await ambienteStore.regenerarToken(props.dispositivo.id)
    tokenPlain.value = res?.token || null
    showToken.value = true
    toast.success('Token regenerado. Copialo ahora — no se mostrará de nuevo.')
  } catch {
    toast.error('Error al regenerar token')
  } finally {
    regenerando.value = false
  }
}

async function eliminar() {
  const ok = await confirm({ title: `¿Eliminar "${props.dispositivo.nombre_amigable}"?`, message: 'Las lecturas existentes se conservan.', confirmText: 'Eliminar', variant: 'danger' })
  if (!ok) return
  try {
    await ambienteStore.deleteDispositivo(props.dispositivo.id)
    emit('deleted', props.dispositivo.id)
    toast.success('Dispositivo eliminado')
  } catch {
    toast.error('Error al eliminar')
  }
}

function copyText(text) {
  navigator.clipboard?.writeText(text).then(() => toast.success('Copiado'))
}
</script>

<template>
  <div class="dc">
    <!-- Header -->
    <div class="dc__header">
      <div class="dc__icon">📡</div>
      <div class="dc__info">
        <div class="dc__nombre">{{ dispositivo.nombre_amigable }}</div>
        <div class="dc__meta">
          <span class="dc__badge">{{ TIPO_LABEL[dispositivo.tipo] || dispositivo.tipo }}</span>
          <span v-if="dispositivo.sala_nombre" class="dc__sala">
            <i class="bi bi-grid-3x3-gap"></i> {{ dispositivo.sala_nombre }}
          </span>
          <span :class="dispositivo.estado === 'activo' ? 'dc__online' : 'dc__offline'">
            {{ dispositivo.estado === 'activo' ? '● activo' : `○ ${dispositivo.estado}` }}
          </span>
        </div>
      </div>
      <div class="dc__actions">
        <button v-if="hasGuide" class="dc__btn" @click="showGuide = !showGuide" title="Instrucciones de conexión">
          <i class="bi bi-question-circle"></i>
        </button>
        <button class="dc__btn" @click="regenerar" :disabled="regenerando" title="Generar / regenerar token">
          <i class="bi bi-key"></i>
        </button>
        <button class="dc__btn dc__btn--danger" @click="eliminar" title="Eliminar">
          <i class="bi bi-trash"></i>
        </button>
      </div>
    </div>

    <!-- Token -->
    <div v-if="tokenPlain || showToken" class="dc__section-label">Token de autenticación</div>
    <div v-if="tokenPlain" class="dc__token-row dc__token-row--new">
      <i class="bi bi-exclamation-triangle-fill dc__warn-icon"></i>
      <code class="dc__token">{{ showToken ? tokenPlain : '••••••••••••' }}</code>
      <button class="dc__btn-sm" @click="showToken = !showToken">
        <i :class="showToken ? 'bi bi-eye-slash' : 'bi bi-eye'"></i>
      </button>
      <button v-if="showToken" class="dc__btn-sm" @click="copyText(tokenPlain)" title="Copiar token">
        <i class="bi bi-clipboard"></i>
      </button>
    </div>
    <div v-else-if="dispositivo.token_pendiente_confirmacion" class="dc__token-pending">
      <i class="bi bi-hourglass-split"></i> Token generado, esperando primera lectura
    </div>

    <!-- Webhook URL -->
    <div class="dc__section-label">URL del webhook</div>
    <div class="dc__token-row">
      <code class="dc__token dc__token--url">{{ webhookUrl }}</code>
      <button class="dc__btn-sm" @click="copyText(webhookUrl)" title="Copiar URL">
        <i class="bi bi-clipboard"></i>
      </button>
    </div>
    <div class="dc__url-hint">Header: <code>X-Webhook-Token: &lt;token&gt;</code></div>

    <!-- Guía de configuración -->
    <div v-if="showGuide" class="dc__guide">
      <!-- Sonoff TH Elite -->
      <template v-if="dispositivo.tipo === 'sonoff_th'">
        <div class="dc__guide-title">Configuración Sonoff TH Elite (eWeLink)</div>
        <ol class="dc__guide-steps">
          <li>Abrí la app <strong>eWeLink</strong> → seleccioná el dispositivo.</li>
          <li>Entrá a <strong>Ajustes → Webhook</strong>.</li>
          <li>Pegá la URL del webhook (arriba) en el campo URL.</li>
          <li>En Headers, agregá: <code>X-Webhook-Token</code> con el valor de tu token.</li>
          <li>Seleccioná los eventos de cambio de temperatura/humedad.</li>
          <li>Guardá y verificá con una lectura de prueba.</li>
        </ol>
        <div class="dc__guide-note">
          El Sonoff envía <code>data.currentTemperature</code> y <code>data.currentHumidity</code> — el driver los mapea automáticamente.
        </div>
      </template>

      <!-- Shelly -->
      <template v-else-if="dispositivo.tipo === 'shelly_plug'">
        <div class="dc__guide-title">Configuración Shelly</div>
        <ol class="dc__guide-steps">
          <li>Accedé a la interfaz web del Shelly.</li>
          <li>En <strong>Settings → Actions → URL Actions</strong>, agregá la URL del webhook.</li>
          <li>Usá un reverse proxy o script para agregar el header <code>X-Webhook-Token</code>.</li>
        </ol>
      </template>

      <!-- Genérico -->
      <template v-else>
        <div class="dc__guide-title">Formato de payload (HTTP POST)</div>
        <pre class="dc__guide-code">POST {{ webhookUrl }}
X-Webhook-Token: &lt;token&gt;
Content-Type: application/json

{
  "temperatura": 24.5,
  "humedad": 62,
  "co2": 1200,
  "timestamp": 1693000000
}</pre>
        <div class="dc__guide-note">Campos opcionales: <code>ppfd</code>, <code>ec</code>, <code>ph</code>, <code>presion</code>, <code>voc</code>.</div>
      </template>
    </div>

    <!-- Última lectura -->
    <div v-if="dispositivo.ultima_lectura_at" class="dc__last">
      <i class="bi bi-reception-4"></i>
      Última lectura: {{ new Date(dispositivo.ultima_lectura_at).toLocaleString('es-AR', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' }) }}
    </div>
    <div v-else class="dc__last dc__last--none">
      <i class="bi bi-reception-0"></i> Sin lecturas todavía
    </div>
  </div>
</template>

<style scoped>
.dc {
  background: #fff; border: 1px solid #d4e6d4; border-radius: 12px;
  padding: 1rem; display: flex; flex-direction: column; gap: .6rem;
}
.dc__header { display: flex; align-items: flex-start; gap: .75rem; }
.dc__icon { font-size: 1.4rem; flex-shrink: 0; }
.dc__info { flex: 1; min-width: 0; }
.dc__nombre { font-size: .9rem; font-weight: 700; color: #1a1a1a; }
.dc__meta { display: flex; align-items: center; gap: .5rem; flex-wrap: wrap; margin-top: .2rem; }
.dc__badge {
  font-size: .65rem; font-weight: 700; text-transform: uppercase;
  letter-spacing: .05em; background: #e8f5e9; color: #1b5e20;
  padding: .15em .5em; border-radius: 5px;
}
.dc__sala { font-size: .72rem; color: #64748b; display: flex; align-items: center; gap: .2rem; }
.dc__online  { font-size: .72rem; color: #16a34a; font-weight: 600; }
.dc__offline { font-size: .72rem; color: #94a3b8; font-weight: 600; }

.dc__actions { display: flex; gap: .35rem; flex-shrink: 0; }
.dc__btn {
  width: 30px; height: 30px; border-radius: 7px; border: 1px solid #e2e8f0;
  background: #f8fafc; color: #64748b; cursor: pointer; display: flex;
  align-items: center; justify-content: center; font-size: .85rem; transition: all .15s;
}
.dc__btn:hover:not(:disabled) { background: #e8f5e9; border-color: #d4e6d4; color: #1b5e20; }
.dc__btn:disabled { opacity: .4; cursor: not-allowed; }
.dc__btn--danger:hover:not(:disabled) { background: #fef2f2; border-color: #fca5a5; color: #dc2626; }

.dc__section-label {
  font-size: .65rem; font-weight: 700; color: #94a3b8;
  text-transform: uppercase; letter-spacing: .05em;
}
.dc__token-row {
  display: flex; align-items: center; gap: .4rem;
  background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 7px;
  padding: .4rem .7rem;
}
.dc__token-row--new { border-color: #fde68a; background: #fffbeb; }
.dc__warn-icon { color: #d97706; font-size: .8rem; flex-shrink: 0; }
.dc__token { font-family: monospace; font-size: .75rem; color: #1a1a1a; flex: 1; word-break: break-all; }
.dc__token--url { font-size: .68rem; color: #374151; }
.dc__btn-sm {
  width: 24px; height: 24px; border-radius: 5px; border: none;
  background: transparent; color: #64748b; cursor: pointer; flex-shrink: 0;
  display: flex; align-items: center; justify-content: center; font-size: .8rem;
}
.dc__btn-sm:hover { background: #e2e8f0; }
.dc__url-hint { font-size: .68rem; color: #94a3b8; font-family: monospace; }
.dc__token-pending {
  font-size: .75rem; color: #b45309; background: #fffbeb; border: 1px solid #fde68a;
  border-radius: 7px; padding: .4rem .7rem; display: flex; align-items: center; gap: .35rem;
}

/* Guía */
.dc__guide {
  background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 9px;
  padding: .85rem; display: flex; flex-direction: column; gap: .5rem;
}
.dc__guide-title { font-size: .78rem; font-weight: 700; color: #1a1a1a; }
.dc__guide-steps { margin: 0; padding-left: 1.2rem; display: flex; flex-direction: column; gap: .3rem; }
.dc__guide-steps li { font-size: .75rem; color: #374151; line-height: 1.45; }
.dc__guide-steps code { background: #e2e8f0; padding: .1em .35em; border-radius: 4px; font-size: .72rem; }
.dc__guide-note { font-size: .72rem; color: #64748b; background: #f1f5f9; border-radius: 7px; padding: .4rem .6rem; }
.dc__guide-note code { font-size: .7rem; }
.dc__guide-code {
  font-family: monospace; font-size: .69rem; color: #1a1a1a;
  background: #1e293b; color: #e2e8f0; border-radius: 7px;
  padding: .65rem .8rem; overflow-x: auto; margin: 0;
  white-space: pre; line-height: 1.5;
}

/* Última lectura */
.dc__last { font-size: .72rem; color: #94a3b8; display: flex; align-items: center; gap: .3rem; }
.dc__last--none { color: #cbd5e1; }
</style>
