<script setup>
import { ref, computed } from 'vue'
import { solicitarWhatsapp, testTwilio } from '../../lib/api.js'
import { useToast } from '../../composables/useToast.js'
import DsSpinner from '../../design-system/components/Spinner.vue'

const props = defineProps({ data: { type: Object, default: () => ({}) } })
const emit  = defineEmits(['updated'])
const toast = useToast()

const estado = computed(() => props.data?.whatsapp_estado || 'sin_configurar')
const numero = ref(props.data?.whatsapp_numero || '')
const guardando = ref(false)
const probando  = ref(false)

async function solicitar() {
  const n = numero.value.trim()
  if (!n) { toast.error('Ingresá tu número de WhatsApp'); return }
  guardando.value = true
  try {
    const { data } = await solicitarWhatsapp(n)
    emit('updated', data)
    toast.success('Solicitud enviada — activamos tu WhatsApp en breve')
  } catch (e) {
    toast.error(e?.response?.data?.error || 'No se pudo enviar la solicitud')
  } finally {
    guardando.value = false
  }
}

async function probar() {
  probando.value = true
  try {
    const { data } = await testTwilio()
    toast.success(`Mensaje de prueba enviado a ${data.enviado_a}`)
  } catch (e) {
    toast.error(e?.response?.data?.error || 'No se pudo enviar el mensaje de prueba')
  } finally {
    probando.value = false
  }
}
</script>

<template>
  <div class="iws">
    <div class="iws__head">
      <div class="iws__ico"><i class="bi bi-whatsapp"></i></div>
      <div class="iws__head-txt">
        <div class="iws__title">WhatsApp</div>
        <div class="iws__sub">Avisos automáticos a los socios (despachos, recordatorios)</div>
      </div>
      <span class="iws__badge" :class="`iws__badge--${estado}`">
        <i :class="estado === 'conectado' ? 'bi bi-check-circle-fill' : estado === 'pendiente' ? 'bi bi-clock-fill' : 'bi bi-dash-circle'"></i>
        {{ estado === 'conectado' ? 'Conectado' : estado === 'pendiente' ? 'Pendiente' : 'Sin activar' }}
      </span>
    </div>

    <div class="iws__body">
      <!-- Conectado -->
      <template v-if="estado === 'conectado'">
        <div class="iws__info iws__info--ok">
          <i class="bi bi-check-circle-fill"></i>
          <span>Tu WhatsApp está activo. Los avisos salen desde <strong>{{ data.twilio_whatsapp_from }}</strong>.</span>
        </div>
        <button class="iws__btn-outline" :disabled="probando" @click="probar">
          <DsSpinner v-if="probando" :size="14" />
          <i v-else class="bi bi-send"></i>
          {{ probando ? 'Enviando…' : 'Enviar mensaje de prueba' }}
        </button>
      </template>

      <!-- Pendiente -->
      <template v-else-if="estado === 'pendiente'">
        <div class="iws__info iws__info--wait">
          <i class="bi bi-clock-fill"></i>
          <span>Pedido recibido para <strong>{{ data.whatsapp_numero }}</strong>. Nuestro equipo está activando tu WhatsApp — te avisamos cuando esté listo (suele tardar 1-2 días por la aprobación de WhatsApp Business).</span>
        </div>
        <div class="iws__field">
          <label class="iws__label">¿Cambiar el número?</label>
          <div class="iws__row">
            <input class="iws__input" v-model="numero" placeholder="+54 11 1234-5678" />
            <button class="iws__btn" :disabled="guardando" @click="solicitar">Actualizar</button>
          </div>
        </div>
      </template>

      <!-- Sin activar -->
      <template v-else>
        <div class="iws__info">
          <i class="bi bi-info-circle-fill"></i>
          <span>Ingresá tu número de WhatsApp y lo activamos por vos. No tenés que crear cuentas ni copiar credenciales.</span>
        </div>
        <div class="iws__field">
          <label class="iws__label">Tu número de WhatsApp</label>
          <div class="iws__row">
            <input class="iws__input" v-model="numero" placeholder="+54 11 1234-5678" />
            <button class="iws__btn" :disabled="guardando" @click="solicitar">
              <DsSpinner v-if="guardando" :size="14" />
              <span v-else>Solicitar activación</span>
            </button>
          </div>
        </div>
      </template>
    </div>
  </div>
</template>

<style scoped>
.iws { background: #fff; border: 1px solid var(--c-slate-200); border-radius: 14px; overflow: hidden; }
.iws__head { display: flex; align-items: center; gap: .875rem; padding: 1rem 1.25rem; border-bottom: 1px solid var(--c-slate-100); background: #fafbfc; }
.iws__ico { width: 38px; height: 38px; border-radius: 10px; background: #dcfce7; color: #16a34a; display: flex; align-items: center; justify-content: center; font-size: 1.1rem; flex-shrink: 0; }
.iws__title { font-size: .92rem; font-weight: 800; color: var(--c-slate-900); }
.iws__sub { font-size: .75rem; color: var(--c-slate-400); margin-top: .1rem; }
.iws__badge { margin-left: auto; display: inline-flex; align-items: center; gap: .35rem; font-size: .72rem; font-weight: 700; padding: .25rem .7rem; border-radius: 999px; }
.iws__badge--conectado { background: #dcfce7; color: #15803d; }
.iws__badge--pendiente { background: #fef9c3; color: #a16207; }
.iws__badge--sin_configurar { background: var(--c-slate-100); color: var(--c-slate-500); }
.iws__body { padding: 1.25rem; display: flex; flex-direction: column; gap: 1rem; }
.iws__info { display: flex; align-items: flex-start; gap: .6rem; background: #eff6ff; border: 1px solid #bfdbfe; border-radius: 9px; padding: .75rem 1rem; font-size: .82rem; color: #1e40af; line-height: 1.5; }
.iws__info i { flex-shrink: 0; margin-top: .1rem; }
.iws__info--ok { background: #f0fdf4; border-color: #bbf7d0; color: #15803d; }
.iws__info--wait { background: #fef9c3; border-color: #fde68a; color: #854d0e; }
.iws__field { display: flex; flex-direction: column; gap: .35rem; }
.iws__label { font-size: .75rem; font-weight: 700; color: #374151; }
.iws__row { display: flex; gap: .5rem; }
.iws__input { flex: 1; background: var(--c-slate-50); border: 1.5px solid var(--c-slate-200); border-radius: 9px; padding: .65rem .9rem; font-size: .875rem; }
.iws__input:focus { outline: none; border-color: #16a34a; background: #fff; }
.iws__btn { background: #16a34a; color: #fff; border: none; border-radius: 9px; padding: .65rem 1.1rem; font-size: .82rem; font-weight: 700; cursor: pointer; white-space: nowrap; }
.iws__btn:disabled { opacity: .5; cursor: default; }
.iws__btn-outline { display: inline-flex; align-items: center; gap: .4rem; background: #fff; border: 1.5px solid var(--c-slate-200); color: var(--c-slate-600); border-radius: 8px; padding: .5rem .9rem; font-size: .82rem; font-weight: 600; cursor: pointer; align-self: flex-start; }
.iws__btn-outline:hover { border-color: var(--c-slate-400); }
</style>
