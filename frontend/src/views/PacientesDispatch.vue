<template>
  <PacientesDispensadorView v-if="isDispensador" />
  <PacientesView v-else />
</template>

<script setup>
import { usePermissions } from '../composables/usePermissions.js'
import PacientesView from './SociosView.vue'
import PacientesDispensadorView from './PacientesDispensadorView.vue'

const { isDispensador } = usePermissions()
</script>
