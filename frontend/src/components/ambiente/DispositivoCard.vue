<script setup>
import { ref } from 'vue'
import { useAmbienteStore } from '../../stores/ambiente.js'
import { useToast } from '../../composables/useToast.js'
import { useConfirm } from '../../composables/useConfirm.js'

const props = defineProps({
  dispositivo: { type: Object, required: true },
})

const emit = defineEmits(['deleted'])
const store = useToast()
const toast = useToast()
const confirm = useConfirm()
const ambienteStore = useAmbienteStore()

const showToken  = ref(false)
const regenerando = ref(false)

async function regenerar() {
  const ok = await confirm('¿Regenerar token? El token anterior dejará de funcionar.')
  if (!ok) return
  regenerando.value = true
  try {
    await ambienteStore.regenerarToken(props.dispositivo.id)
    toast.success('Token regenerado')
    showToken.value = true
  } catch {
    toast.error('Error al regenerar token')
  } finally {
    regenerando.value = false
  }
}

async function eliminar() {
  const ok = await confirm(`¿Eliminar "${props.dispositivo.nombre}"? Esta acción no se puede deshacer.`)
  if (!ok) return
  try {
    await ambienteStore.deleteDispositivo(props.dispositivo.id)
    emit('deleted', props.dispositivo.id)
    toast.success('Dispositivo eliminado')
  } catch {
    toast.error('Error al eliminar')
  }
}

function copyToken() {
  const token = props.dispositivo.token_plain || props.dispositivo.token
  if (token) navigator.clipboard?.writeText(token).then(() => toast.success('Token copiado'))
}

const PROTOCOL_LABEL = { http: 'HTTP webhook', mqtt: 'MQTT' }
</script>

<template>
  <div class="dc">
    <div class="dc__header">
      <div class="dc__icon">📡</div>
      <div class="dc__info">
        <div class="dc__nombre">{{ dispositivo.nombre }}</div>
        <div class="dc__meta">
          <span class="dc__badge">{{ PROTOCOL_LABEL[dispositivo.protocolo] || dispositivo.protocolo }}</span>
          <span v-if="dispositivo.sala_nombre" class="dc__sala">{{ dispositivo.sala_nombre }}</span>
          <span :class="dispositivo.activo ? 'dc__online' : 'dc__offline'">
            {{ dispositivo.activo ? '● activo' : '○ inactivo' }}
          </span>
        </div>
      </div>
      <div class="dc__actions">
        <button class="dc__btn" @click="regenerar" :disabled="regenerando" title="Regenerar token">
          <i class="bi bi-arrow-clockwise"></i>
        </button>
        <button class="dc__btn dc__btn--danger" @click="eliminar" title="Eliminar">
          <i class="bi bi-trash"></i>
        </button>
      </div>
    </div>

    <div v-if="dispositivo.token_plain || showToken" class="dc__token-row">
      <code class="dc__token">{{ showToken && dispositivo.token_plain ? dispositivo.token_plain : '••••••••••••' }}</code>
      <button class="dc__btn-sm" @click="showToken = !showToken">
        <i :class="showToken ? 'bi bi-eye-slash' : 'bi bi-eye'"></i>
      </button>
      <button v-if="showToken" class="dc__btn-sm" @click="copyToken" title="Copiar">
        <i class="bi bi-clipboard"></i>
      </button>
    </div>

    <div v-if="dispositivo.ultima_lectura_at" class="dc__last">
      Última lectura: {{ new Date(dispositivo.ultima_lectura_at).toLocaleString('es-AR') }}
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
.dc__sala { font-size: .75rem; color: #64748b; }
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

.dc__token-row {
  display: flex; align-items: center; gap: .4rem;
  background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 7px;
  padding: .4rem .7rem;
}
.dc__token { font-family: monospace; font-size: .78rem; color: #1a1a1a; flex: 1; word-break: break-all; }
.dc__btn-sm {
  width: 24px; height: 24px; border-radius: 5px; border: none;
  background: transparent; color: #64748b; cursor: pointer;
  display: flex; align-items: center; justify-content: center; font-size: .8rem;
}
.dc__btn-sm:hover { background: #e2e8f0; }
.dc__last { font-size: .72rem; color: #94a3b8; }
</style>
