<script setup>
// EL INICIO DEL ADMINISTRADOR (12-oct-2026): el panel de conducción.
//
// Eran doce bloques del mismo tamaño —cajas, KPIs repetidos, reservas, lotes, ambiente, actividad—
// que respondían «qué hay» y no «qué requiere atención». Ahora: el asistente si la organización
// todavía no tiene sede, lo que falta para estar operando (se apaga sola) y el panel
// (`PanelConduccion`, que calcula `Panel::Conduccion`). Lo operativo vive en su pantalla: los lotes
// en Cultivo, las reservas en Comercial, la caja en Mostrador.
import { onMounted, ref } from 'vue'
import { listSedes } from '../../lib/api.js'
import OnboardingWizard from '../OnboardingWizard.vue'
import PuestaEnMarcha   from '../PuestaEnMarcha.vue'
import PanelConduccion  from '../panel/PanelConduccion.vue'
import DsSpinner        from '../../design-system/components/Spinner.vue'

const cargando = ref(true)
const sinSede  = ref(false)

// Se decide primero (¿hace falta el asistente?) y se carga después: el asistente en modo
// «comprobando» pintaba la pantalla en cada visita.
async function comprobarSedes () {
  try {
    const { data } = await listSedes()
    sinSede.value = !(data || []).length
  } catch {
    sinSede.value = false
  } finally {
    cargando.value = false
  }
}

onMounted(comprobarSedes)
</script>

<template>
  <div class="ad">
    <div v-if="cargando" class="ad__loading"><DsSpinner /></div>
    <OnboardingWizard v-else-if="sinSede" @completado="comprobarSedes" />
    <template v-else>
      <PuestaEnMarcha />
      <PanelConduccion />
    </template>
  </div>
</template>

<style scoped>
.ad { display: flex; flex-direction: column; gap: 20px; padding: 28px 32px 56px; max-width: 1240px; margin: 0 auto; box-sizing: border-box; }
.ad__loading { display: flex; justify-content: center; padding: 80px 0; }
@media (max-width: 640px) { .ad { padding: 16px; } }
</style>
