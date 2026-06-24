<template>
  <div class="et-lbl" :class="`et-lbl--${tamano}`">
    <!-- Header: club (remitente) -->
    <div class="et-lbl__header">
      <img v-if="club.logoUrl" :src="club.logoUrl" alt="logo" class="et-lbl__logo" crossorigin="anonymous" />
      <span class="et-lbl__club">{{ club.name }}</span>
    </div>

    <!-- Destinatario -->
    <div class="et-lbl__para-lbl">Para</div>
    <div class="et-lbl__para">{{ despacho.contacto_nombre || despacho.paciente_nombre || '—' }}</div>

    <div v-if="despacho.direccion_envio" class="et-lbl__dir">{{ despacho.direccion_envio }}</div>
    <div v-if="despacho.contacto_telefono" class="et-lbl__tel">Tel: {{ despacho.contacto_telefono }}</div>

    <!-- Cobrar al entregar (contra-entrega) -->
    <div v-if="cobrarAlEntregar" class="et-lbl__cobrar">
      💵 COBRAR AL ENTREGAR<span v-if="montoCobrar"> · {{ montoCobrar }}</span>
    </div>

    <!-- Footer: código de paquete -->
    <div class="et-lbl__footer">
      <span class="et-lbl__cod-lbl">Paquete</span>
      <span class="et-lbl__cod">{{ despacho.codigo_paquete || `#${despacho.id}` }}</span>
    </div>
  </div>
</template>

<script setup>
import { computed } from 'vue'
import { useClubStore } from '../../stores/club.js'

const props = defineProps({
  despacho: { type: Object, required: true },
  tamano:   { type: String, default: '100x70' },
})

const club = useClubStore()

const cobrarAlEntregar = computed(() => props.despacho?.cobrar_en_entrega || (props.despacho?.saldo_pendiente || 0) > 0)
const montoCobrar = computed(() => {
  const m = props.despacho?.saldo_pendiente || 0
  return m > 0 ? '$' + Number(m).toLocaleString('es-AR') : ''
})
</script>

<style scoped>
.et-lbl {
  background: white; border: 2px solid #1b5e20; border-radius: 6px;
  display: flex; flex-direction: column; padding: 4mm 5mm;
  font-family: system-ui, -apple-system, sans-serif; color: #1a1a1a;
  box-shadow: 0 4px 20px rgba(0,0,0,.15);
}
.et-lbl--100x70  { width: 100mm; min-height: 70mm;  font-size: 10pt; }
.et-lbl--100x150 { width: 100mm; min-height: 150mm; font-size: 12pt; }

.et-lbl__header { display: flex; align-items: center; gap: 2mm; border-bottom: .5pt solid #cbd5e1; padding-bottom: 2mm; margin-bottom: 3mm; }
.et-lbl__logo { height: 8mm; width: auto; object-fit: contain; }
.et-lbl__club { font-weight: 800; color: #1b5e20; font-size: 1.25em; line-height: 1.1; }

.et-lbl__para-lbl { font-size: .7em; font-weight: 700; text-transform: uppercase; letter-spacing: .08em; color: #94a3b8; }
.et-lbl__para { font-weight: 800; font-size: 1.6em; line-height: 1.15; color: #0f172a; margin-bottom: 2mm; }
.et-lbl__dir { font-size: 1em; line-height: 1.3; color: #334155; }
.et-lbl__tel { font-size: .95em; color: #475569; margin-top: 1mm; }
.et-lbl__cobrar { margin-top: 2mm; padding: 1.5mm 2mm; border: 1pt solid #166534; border-radius: 1.5mm; background: #f0fdf4; color: #166534; font-weight: 800; font-size: .95em; text-align: center; letter-spacing: .02em; }

.et-lbl__footer { display: flex; align-items: center; gap: 2mm; border-top: .5pt solid #cbd5e1; padding-top: 2mm; margin-top: auto; }
.et-lbl__cod-lbl { font-size: .7em; font-weight: 700; text-transform: uppercase; letter-spacing: .06em; color: #94a3b8; }
.et-lbl__cod { font-family: monospace; font-weight: 800; font-size: 1.1em; color: #1b5e20; }

@media print {
  .et-lbl { box-shadow: none; border-color: #000; page-break-inside: avoid; }
}
</style>
