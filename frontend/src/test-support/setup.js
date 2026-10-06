// Setup común de vitest.
//
// LA CONFIRMACIÓN FINAL DE LA DISPENSA (6-oct-2026): antes de crear, el modal muestra un resumen
// y espera «Confirmar». Los tests de la dispensa prueban QUÉ se manda (payloads, cobros, envío),
// no el resumen: acá el resumen confirma solo apenas se abre. El que prueba el resumen de verdad
// lo des-stubea (`global: { stubs: { ResumenDispensaModal: false } }`).
import { config } from '@vue/test-utils'
import { defineComponent, watch, nextTick } from 'vue'

config.global.stubs = {
  ...config.global.stubs,
  ResumenDispensaModal: defineComponent({
    name: 'ResumenDispensaModalAutoConfirma',
    props: { abierto: Boolean, resumen: Object },
    emits: ['elegir'],
    setup(props, { emit }) {
      watch(() => props.abierto, async (a) => { if (a) { await nextTick(); emit('elegir', 'confirmar') } })
      return () => null
    },
  }),
}
