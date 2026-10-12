<template>
  <div class="mah">
    <!-- EL INICIO DEL ADMINISTRADOR EN EL TELÉFONO: el mismo panel de conducción que en la compu
         (12-oct-2026), en una columna y con los enlaces a las pantallas del teléfono. Arriba, la
         caja del mostrador: el admin la abre desde la tablet con el fondo del día y quien atiende
         la confirma desde su pantalla; es lo único operativo que se queda acá. -->
    <CajaMostradorCard v-if="sedeMostrador" :sede="sedeMostrador" :puede-gestionar="true" />
    <PanelConduccion compacto />
  </div>
</template>

<script setup>
import { onMounted, ref, watch } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '../../stores/auth'
import { useUsoPersonal } from '../../composables/useUsoPersonal.js'
import { getAnalyticsDispensador } from '../../lib/api.js'
import CajaMostradorCard from '../../components/dashboards/CajaMostradorCard.vue'
import PanelConduccion from '../../components/panel/PanelConduccion.vue'

const auth   = useAuthStore()
const router = useRouter()

// Uso personal: este inicio es el de una organización. El cultivador de casa tiene el suyo; el
// router ya lo manda ahí (`esUsoPersonal`, que sabe desde /me). Esto queda de red por si alguien
// entra con la URL escrita.
const { esPersonal } = useUsoPersonal()
watch(esPersonal, (p) => { if (p && auth.user?.role === 'admin') router.replace('/m/personal/hoy') }, { immediate: true })

// La sede del mostrador que el admin puede abrir desde acá (la misma que usaba este inicio).
const sedeMostrador = ref(null)
onMounted(async () => {
  try {
    const { data } = await getAnalyticsDispensador()
    sedeMostrador.value = data?.sede_mostrador ?? null
  } catch { /* sin mostrador: la tarjeta no aparece */ }
})
</script>

<style scoped>
.mah { display: flex; flex-direction: column; gap: 16px; padding: 16px 16px 96px; }
</style>
