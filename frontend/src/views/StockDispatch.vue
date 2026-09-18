<template>
  <!-- La misma ruta, dos pantallas: el stock de una organización (sedes, mostrador, externo) y
       los frascos del cultivador de casa. -->
  <FrascosView v-if="esPersonal" />
  <AdminStocksPendientesView v-else />
</template>

<script setup>
import { useUsoPersonal } from '../composables/useUsoPersonal.js'
import AdminStocksPendientesView from './admin/AdminStocksPendientesView.vue'
import FrascosView from './personal/FrascosView.vue'

const { esPersonal } = useUsoPersonal()
</script>
