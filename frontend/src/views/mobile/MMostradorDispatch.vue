<template>
  <MMostradorView v-if="!gestiona" />
  <MostradorView v-else />
</template>

<script setup>
// QUIÉN VE QUÉ MOSTRADOR EN EL TELÉFONO.
//
// Son dos pantallas porque son dos trabajos distintos sobre la misma mesa, no dos versiones de
// lo mismo:
//   · QUIEN ATIENDE consulta y arquea, de pie y con alguien enfrente → `MMostradorView`, que es
//     lista de tarjetas: qué hay de cada cosa, buscarlo, contarlo, abrir y cerrar.
//   · ADMINISTRACIÓN gobierna la mesa: escribe cuánto tiene que haber de cada producto, mira la
//     merma y las rendiciones → la de escritorio, que es una tabla y entra al shell como está.
//     Al teléfono se asoma de vez en cuando; el dispensador vive ahí.
//
// El criterio sale de `gestionaMostrador`, el MISMO que usa la pantalla para decidir qué mostrar
// adentro: escrito dos veces, un día el dispatch manda a una y la otra se dibuja para el otro
// rol. Esto es sólo presentación — el permiso lo siguen decidiendo el guard de la ruta y el
// backend.
import { computed } from 'vue'
import { useAuthStore } from '../../stores/auth.js'
import { gestionaMostrador } from '../../composables/useMostrador.js'
import MMostradorView from './MMostradorView.vue'
import MostradorView from '../MostradorView.vue'

const auth = useAuthStore()
const gestiona = computed(() => gestionaMostrador(auth.user?.role))
</script>
