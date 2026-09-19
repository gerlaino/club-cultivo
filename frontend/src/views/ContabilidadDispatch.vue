<template>
  <!-- La misma ruta, dos pantallas: la contabilidad entera para una organización y sólo los
       gastos para el cultivador de casa. Se decide acá y no en el router porque el router no
       lee stores al armar la tabla de rutas. -->
  <GastosView v-if="esPersonal" />
  <ContabilidadView v-else />
</template>

<script setup>
import { useUsoPersonal } from '../composables/useUsoPersonal.js'
import ContabilidadView from './ContabilidadView.vue'
import GastosView from './personal/GastosView.vue'

const { esPersonal } = useUsoPersonal()
</script>
