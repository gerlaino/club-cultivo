<template>
  <div class="rnv">
    <header class="rnv__hd">
      <h1 class="rnv__title">Rendiciones</h1>
      <p class="rnv__sub">
        Lo que cada repartidor cobró en la calle y lo que entregó al volver. Lo que falta no es una
        pérdida: queda a su nombre y se ve acumulado en su ficha.
      </p>
    </header>
    <RendicionCajaCard historial />
  </div>
</template>

<script setup>
// EL HISTORIAL DE RENDICIONES, en Comercial y no en el mostrador (sep-2026, acordado con Germán).
//
// Vivía como cuarta solapa del mostrador porque la plata del repartidor cae en esa caja, pero no
// es del mostrador: es del delivery. Ahí era una solapa más entre tres que hablaban de merma, y
// el admin que buscaba «¿cuánto rindió el repartidor?» no la iba a buscar a la mesa del
// dispensario. En el mostrador queda lo que le pasa a SU caja: la tarjeta del repartidor que
// está rindiendo ahora, y el «entró la rendición» en el arqueo.
import RendicionCajaCard from '../../components/RendicionCajaCard.vue'
</script>

<style scoped>
.rnv { padding: var(--sp-6) var(--sp-8); max-width: 1100px; }
.rnv__hd { margin-bottom: var(--sp-5); }
.rnv__title { margin: 0; font-family: var(--font-display); font-size: var(--fs-24); font-weight: 800; color: var(--c-ink-900); letter-spacing: -.02em; }
.rnv__sub { margin: 4px 0 0; font-size: var(--fs-13); color: var(--c-ink-500); max-width: 70ch; }
</style>
