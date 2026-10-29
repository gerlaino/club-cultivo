<template>
  <!-- «Tené tu portal en el teléfono» (28-oct-2026). Sólo en el teléfono y sólo si todavía no lo
       instaló: el link del mail sirve una vez, y sin el ícono el paciente no sabe cómo volver. -->
  <section v-if="mostrar" class="pin" data-testid="portal-instalar">
    <div class="pin__hd">
      <span class="pin__ico" aria-hidden="true"><Smartphone :size="22" :stroke-width="2" /></span>
      <div>
        <p class="pin__t">Tené tu portal en el teléfono</p>
        <p class="pin__s">Queda como una app: lo abrís con un toque y entrás con tu DNI, sin buscar el mail.</p>
      </div>
    </div>

    <!-- Android / Chrome: el teléfono lo instala solo -->
    <button v-if="avisoInstalar" type="button" class="pin__btn" data-testid="portal-instalar-btn" @click="instalar">
      Instalar el portal
    </button>

    <!-- iPhone: no hay botón posible, se le dice dónde tocar -->
    <ol v-else-if="esIOS" class="pin__pasos" data-testid="portal-instalar-ios">
      <li>Tocá <strong>Compartir</strong> <Share :size="16" :stroke-width="2.2" class="pin__inline" aria-label="(el cuadrado con la flecha)" /> abajo en Safari.</li>
      <li>Elegí <strong>Agregar a inicio</strong>.</li>
      <li>Tocá <strong>Agregar</strong>. Te queda el ícono de {{ nombre }}.</li>
    </ol>

    <!-- Otro Android (Samsung, Firefox) o ya lo descartó una vez: por el menú -->
    <ol v-else class="pin__pasos" data-testid="portal-instalar-menu">
      <li>Tocá el menú <strong>⋮</strong> del navegador, arriba a la derecha.</li>
      <li>Elegí <strong>Instalar app</strong> o <strong>Agregar a la pantalla principal</strong>.</li>
    </ol>

    <button type="button" class="pin__no" @click="ocultar">Ahora no</button>
  </section>
</template>

<script setup>
import { computed, ref } from 'vue'
import { Share, Smartphone } from 'lucide-vue-next'
import { avisoInstalar } from '@/lib/puertaPortal'
import { usePWA } from '@/composables/usePWA'

const props = defineProps({ nombre: { type: String, default: 'tu organización' } })

const CLAVE = 'ce_instalar_oculto'
const VOLVER_A_MOSTRAR = 14 * 24 * 60 * 60 * 1000 // a las dos semanas se le vuelve a ofrecer

const ua = typeof navigator !== 'undefined' ? navigator.userAgent : ''
const esIOS = /iphone|ipad|ipod/i.test(ua) || (/macintosh/i.test(ua) && typeof navigator !== 'undefined' && navigator.maxTouchPoints > 1)
const esTelefono = /android|iphone|ipad|ipod|mobile/i.test(ua) || esIOS

function ocultoHasta() {
  try { return Number(localStorage.getItem(CLAVE) || 0) } catch { return 0 }
}
const oculto = ref(ocultoHasta() > Date.now())

const mostrar = computed(() => esTelefono && !usePWA().isPWA() && !oculto.value)
const nombre = computed(() => props.nombre)

async function instalar() {
  const e = avisoInstalar.value
  if (!e) return
  e.prompt()
  try {
    const { outcome } = await e.userChoice
    if (outcome === 'accepted') oculto.value = true
  } catch { /* el navegador no dice qué eligió: queda el aviso */ }
  avisoInstalar.value = null // el evento sirve una sola vez; si no aceptó, quedan los pasos del menú
}

function ocultar() {
  oculto.value = true
  try { localStorage.setItem(CLAVE, String(Date.now() + VOLVER_A_MOSTRAR)) } catch { /* sin almacenamiento: se oculta por hoy */ }
}
</script>

<style scoped>
.pin {
  background: var(--p-marca-suave); border: 1px solid var(--p-marca-linea); border-radius: var(--p-radio);
  padding: 16px; display: flex; flex-direction: column; gap: 12px; margin-top: 12px;
}
.pin__hd { display: flex; gap: 12px; align-items: flex-start; }
.pin__ico { flex: none; width: 40px; height: 40px; border-radius: 12px; background: var(--p-marca); color: var(--p-papel); display: grid; place-items: center; }
.pin__t { margin: 0; font-weight: 700; color: var(--p-tinta); }
.pin__s { margin: 2px 0 0; font-size: .9rem; color: var(--p-suave); line-height: 1.45; }
.pin__btn {
  min-height: 48px; border: 0; border-radius: 12px; background: var(--p-marca); color: var(--p-papel);
  font: inherit; font-weight: 700; cursor: pointer;
}
.pin__pasos { margin: 0; padding-left: 1.3rem; display: flex; flex-direction: column; gap: 6px; font-size: .95rem; color: var(--p-tinta); line-height: 1.45; }
.pin__inline { display: inline-block; vertical-align: -2px; margin: 0 2px; }
.pin__no { align-self: center; min-height: 40px; background: none; border: 0; color: var(--p-suave); font: inherit; font-size: .9rem; cursor: pointer; }
</style>
