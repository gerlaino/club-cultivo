<template>
  <div class="pcv-c">
    <div class="pcv-c__barra no-print">
      <RouterLink to="/configuracion/portal" class="pcv-c__volver">← Volver al portal</RouterLink>
      <button type="button" class="pcv-c__imprimir" :disabled="!qr" @click="imprimir">Imprimir</button>
    </div>

    <!-- Una hoja A4: lo que se pega en el mostrador. -->
    <article class="pcv-c__hoja" data-testid="cartel-portal">
      <header class="pcv-c__hd">
        <img v-if="club.logoUrl" :src="club.logoUrl" alt="" class="pcv-c__logo" />
        <p class="pcv-c__org">{{ club.data?.name }}</p>
      </header>
      <h1 class="pcv-c__t">Tu portal de paciente</h1>
      <p class="pcv-c__s">Tu REPROCANN, tus dispensas y reservar para retirar, desde tu teléfono.</p>

      <div class="pcv-c__qr">
        <img v-if="qr" :src="qr" alt="Código QR para entrar al portal" />
        <DsSpinner v-else :size="48" />
      </div>

      <ol class="pcv-c__pasos">
        <li><span><strong>Escaneá</strong> el código con la cámara del teléfono.</span></li>
        <li><span><strong>Poné tu DNI</strong> y tocá «Es mi primera vez».</span></li>
        <li><span><strong>Abrí el mail</strong> que te llega, elegí tu clave y listo.</span></li>
      </ol>
      <p class="pcv-c__pie">¿No tenés mail cargado? Pedí tu link acá en el mostrador.<br />{{ linkCorto }}</p>
    </article>
  </div>
</template>

<script setup>
// El cartel del portal para el mostrador (Germán, 28-oct-2026: «tener un acceso fácil, mismo para
// los pacientes»). El QR lleva a la puerta del portal; ahí el paciente pone su DNI y, si es la
// primera vez, le llega el link a su mail (`portal_acceso#recuperar`). Nadie tiene que invitarlo.
import { computed, onMounted, ref } from 'vue'
import { RouterLink } from 'vue-router'
import { useQRCode } from '@/composables/useQRCode'
import { useClubStore } from '@/stores/club'
import DsSpinner from '@/design-system/components/Spinner.vue'

const club = useClubStore()
const { generatePNG } = useQRCode()
const qr = ref(null)

// La puerta de ESTA organización (28-oct-2026): el que escanea el cartel de Club Modelo entra a
// Club Modelo aunque también sea paciente en otra. La general (`/paciente`) le mandaba un link de
// cada una y quien es paciente en dos abría el que no era.
const link = computed(() => {
  const slug = club.data?.slug
  return `${window.location.origin}/paciente${slug ? `/${encodeURIComponent(slug)}` : ''}`
})
const linkCorto = computed(() => link.value.replace(/^https?:\/\//, ''))

onMounted(async () => {
  if (!club.data) await club.fetch?.()
  qr.value = await generatePNG(link.value, { width: 640, margin: 2 })
})

function imprimir() { window.print() }
</script>

<style scoped>
.pcv-c { min-height: 100vh; background: var(--c-slate-100); padding: 1.5rem 1rem 3rem; font-family: var(--font-ui); color: var(--c-ink-900); }
.pcv-c__barra { max-width: 210mm; margin: 0 auto 1rem; display: flex; justify-content: space-between; align-items: center; gap: 1rem; }
.pcv-c__volver { color: var(--c-leaf-800); font-weight: 600; text-decoration: none; min-height: 44px; display: inline-flex; align-items: center; }
.pcv-c__imprimir { min-height: 44px; padding: 0 1.5rem; border: none; border-radius: 10px; background: var(--c-leaf-800); color: #fff; font: inherit; font-weight: 700; cursor: pointer; }
.pcv-c__imprimir:disabled { opacity: .5; }

.pcv-c__hoja {
  box-sizing: border-box; width: 100%; max-width: 210mm; min-height: 297mm; margin: 0 auto; padding: 18mm 16mm;
  background: #fff; box-shadow: 0 2px 16px rgb(0 0 0 / .08); display: flex; flex-direction: column; align-items: center; text-align: center;
}
.pcv-c__hd { display: flex; flex-direction: column; align-items: center; gap: .5rem; }
.pcv-c__logo { max-height: 22mm; max-width: 60mm; object-fit: contain; }
.pcv-c__org { margin: 0; font-size: 18pt; font-weight: 700; color: var(--c-leaf-800); }
.pcv-c__t { margin: 10mm 0 3mm; font-size: 34pt; font-weight: 800; letter-spacing: -.01em; line-height: 1.05; }
.pcv-c__s { margin: 0; font-size: 15pt; color: var(--c-slate-600); max-width: 150mm; }
.pcv-c__qr { margin: 10mm 0; width: 95mm; height: 95mm; display: flex; align-items: center; justify-content: center; }
.pcv-c__qr img { width: 100%; height: 100%; image-rendering: pixelated; }
.pcv-c__pasos { margin: 0; padding: 0; list-style: none; counter-reset: paso; display: flex; flex-direction: column; gap: 4mm; text-align: left; font-size: 15pt; max-width: 150mm; }
.pcv-c__pasos li { counter-increment: paso; display: flex; gap: 4mm; align-items: baseline; }
.pcv-c__pasos li::before { content: counter(paso); flex: 0 0 10mm; height: 10mm; border-radius: 50%; background: var(--c-leaf-800); color: #fff; font-weight: 700; display: inline-flex; align-items: center; justify-content: center; font-size: 13pt; }
.pcv-c__pie { margin: auto 0 0; padding-top: 10mm; font-size: 12pt; color: var(--c-slate-600); line-height: 1.5; }

@media print {
  .no-print { display: none !important; }
  .pcv-c { background: #fff; padding: 0; }
  .pcv-c__hoja { box-shadow: none; max-width: none; min-height: auto; height: 100vh; }
  @page { size: A4; margin: 0; }
}
</style>
