<template>
  <div class="rnv">
    <header class="rnv__hd">
      <div>
        <h1 class="rnv__title">Rendiciones</h1>
        <p class="rnv__sub">
          Lo que cada repartidor cobró en la calle y lo que entregó al volver. Lo que falta no es una
          pérdida: queda a su nombre y se ve acumulado en su ficha.
        </p>
      </div>
      <div class="rnv__mes">
        <button type="button" class="rnv__mes-btn" aria-label="Mes anterior" @click="moverMes(-1)">‹</button>
        <span class="rnv__mes-nombre">{{ nombreMes }}</span>
        <button type="button" class="rnv__mes-btn" aria-label="Mes siguiente" :disabled="esMesActual" @click="moverMes(1)">›</button>
      </div>
    </header>

    <!-- Si una rendición está dirigida a QUIEN MIRA (por ejemplo, porque se la reasignó a sí
         mismo), la cuenta y la recibe acá mismo. Sin nada para recibir, la tarjeta no ocupa lugar. -->
    <RendicionCajaCard :key="`accion-${version}`" @recibida="version++" />

    <!-- El historial del mes, con las pendientes SIEMPRE arriba aunque sean de otro mes: el panel
         del admin avisa «rendición entregada sin recibir» y manda acá, así que acá tiene que estar. -->
    <RendicionCajaCard :key="`hist-${version}`" historial :mes="mesISO" :nombre-mes="nombreMes"
                       @reasignada="version++" />
  </div>
</template>

<script setup>
// EL HISTORIAL DE RENDICIONES, en Comercial y no en el mostrador (sep-2026, acordado con Germán).
//
// Vivía como cuarta solapa del mostrador porque la plata del repartidor cae en esa caja, pero no
// es del mostrador: es del delivery. En el mostrador queda lo que le pasa a SU caja: la tarjeta
// del repartidor que está rindiendo ahora, y el «entró la rendición» en el arqueo.
//
// 13-oct-2026: mostraba sólo las RECIBIDAS, así que una pendiente —la que el panel avisa— no
// aparecía en ningún lado. Ahora es el mes entero con las pendientes arriba, y una pendiente que
// nadie recibe se reasigna (`Rendiciones::Reasignar`).
import { ref, computed } from 'vue'
import RendicionCajaCard from '../../components/RendicionCajaCard.vue'

const MESES = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto',
               'septiembre', 'octubre', 'noviembre', 'diciembre']

const hoy = new Date()
const mes = ref(new Date(hoy.getFullYear(), hoy.getMonth(), 1))
// Recibir o reasignar cambia las dos tarjetas: se vuelven a montar y piden de nuevo.
const version = ref(0)

const mesISO      = computed(() => `${mes.value.getFullYear()}-${String(mes.value.getMonth() + 1).padStart(2, '0')}`)
const nombreMes   = computed(() => `${MESES[mes.value.getMonth()]} ${mes.value.getFullYear()}`)
const esMesActual = computed(() => mes.value.getFullYear() === hoy.getFullYear() && mes.value.getMonth() === hoy.getMonth())

function moverMes (d) {
  mes.value = new Date(mes.value.getFullYear(), mes.value.getMonth() + d, 1)
}
</script>

<style scoped>
.rnv { padding: var(--sp-6) var(--sp-8); max-width: 1100px; margin: 0 auto; }
.rnv__hd {
  display: flex; justify-content: space-between; align-items: flex-end; gap: var(--sp-4);
  flex-wrap: wrap; margin-bottom: var(--sp-5);
}
.rnv__title { margin: 0; font-family: var(--font-display); font-size: var(--fs-24); font-weight: 800; color: var(--c-ink-900); letter-spacing: -.02em; }
.rnv__sub { margin: 4px 0 0; font-size: var(--fs-13); color: var(--c-ink-500); max-width: 70ch; }
.rnv__mes { display: flex; align-items: center; gap: 6px; }
.rnv__mes-nombre { min-width: 130px; text-align: center; font-weight: 700; color: var(--c-ink-900); text-transform: capitalize; }
.rnv__mes-btn {
  border: 1px solid var(--c-slate-200); background: #fff; border-radius: 8px; width: 30px; height: 30px;
  font: inherit; cursor: pointer; color: var(--c-ink-700);
}
.rnv__mes-btn:disabled { opacity: .4; cursor: default; }
@media (max-width: 640px) { .rnv { padding: var(--sp-4); } }
</style>
