<template>
  <div class="int">
    <div class="int__head">
      <h1 class="int__title">WhatsApp</h1>
      <p class="int__sub">Avisos de entrega a tus pacientes por WhatsApp, desde el número de tu organización.</p>
    </div>

    <div v-if="loading" class="int__loading"><DsSpinner :size="28" /></div>
    <IntegracionWhatsappSimple v-else :data="prefData" @updated="cargar" />
  </div>
</template>

<script setup>
// Era "Integraciones" y tenía dos cosas: WhatsApp y **Webhooks salientes**.
//
// Los webhooks se sacaron de la vista del admin del club. No están rotos —andan de verdad:
// `Dispensacion`, `Paciente` y `Lote` disparan vía `WebhookDispatcher`, con jobs y registro de
// entregas— pero para configurar uno hace falta una URL de destino que sólo existe si el club ya
// tiene otro programa corriendo, y el que la consigue es un desarrollador. Un admin de club lee
// "webhook" y no sabe qué es ni para qué sirve; ofrecérselo es ocupar lugar en el menú de todos
// para algo que nadie pidió nunca.
//
// Lo que se sacó es la PANTALLA, no el módulo: los modelos, los jobs, el endpoint y los tres
// puntos de disparo quedan intactos. El día que un cliente pida "mandame las dispensaciones a mi
// sistema contable", el código está y anda; se configura desde consola hasta que alguien lo pida
// dos veces y justifique una pantalla.
//
// Lo que queda es WhatsApp, que sí es un add-on que se vende y que el admin puede configurar solo
// (número + credenciales de Twilio). La ruta se gatea por ese add-on en el router.
import { ref, onMounted } from 'vue'
import DsSpinner from '../design-system/components/Spinner.vue'
import { getPreferences } from '../lib/api.js'
import IntegracionWhatsappSimple from '../components/integraciones/IntegracionWhatsappSimple.vue'

const prefData = ref({})
const loading  = ref(true)

async function cargar() {
  try {
    const { data } = await getPreferences()
    prefData.value = data || {}
  } catch { /* la pantalla se dibuja igual: el componente muestra "sin configurar" */ }
  finally { loading.value = false }
}

onMounted(cargar)
</script>

<style scoped>
.int { max-width: 760px; margin: 0 auto; padding: 1.5rem 1.25rem; }
.int__head { margin-bottom: 1.25rem; }
.int__title { font-size: 1.4rem; font-weight: 700; color: var(--c-slate-900); margin: 0 0 .25rem; letter-spacing: -.025em; }
.int__sub { font-size: .875rem; color: var(--c-slate-500); margin: 0; line-height: 1.5; }
.int__loading { display: flex; justify-content: center; padding: 3rem; }
</style>
