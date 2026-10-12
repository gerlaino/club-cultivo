<template>
  <!-- Lo que administración tocó mientras la caja estaba abierta. Quien atiende lo tiene que ver o
       cierra con un faltante que no es suyo y encima no lo puede explicar.

       PLEGADO SIEMPRE Y DE A 10 (Germán, 12-oct-2026): con la mesa cargada de una vez eran 25
       renglones y la pantalla del mostrador se volvía un scroll larguísimo antes de llegar a la
       mesa. Plegado dice lo que importa —cuántos productos, quién y cuándo—; desplegado muestra
       los últimos 10 y «Ver 10 más». Los cierres de otros días están en el calendario de abajo. -->
  <section class="mdt">
    <button type="button" class="mdt__hd" :aria-expanded="String(abierto)" @click="alternar">
      <span class="mdt__lbl">Mientras la caja estuvo abierta</span>
      <span class="mdt__resumen">{{ resumen }}</span>
      <i class="bi mdt__chev" :class="abierto ? 'bi-chevron-up' : 'bi-chevron-down'" aria-hidden="true"></i>
    </button>

    <template v-if="abierto">
      <p v-for="m in visibles" :key="m.stock_id" class="mdt__mov">
        <b>{{ m.usuarios.join(' y ') }}</b> {{ m.cantidad > 0 ? 'subió' : 'bajó' }}
        <b class="mdt__num">{{ fmt(Math.abs(m.cantidad)) }} {{ m.unidad }}</b>
        de {{ producto(m) }}<span v-if="m.numero" class="mdt__num"> · {{ m.numero }}</span>:
        de {{ fmt(m.antes) }} a <b class="mdt__num">{{ fmt(m.ahora) }} {{ m.unidad }}</b>{{
          m.motivos.length ? ` — ${m.motivos.join(' · ')}` : '' }}
        <span class="mdt__hora">{{ m.veces > 1 ? `${m.veces} cargas, última ` : '' }}{{ hora(m.cuando) }}</span>
      </p>
      <div v-if="movimientos.length > POR_PAGINA" class="mdt__pie">
        <span class="mdt__cuenta">{{ visibles.length }} de {{ movimientos.length }}</span>
        <button v-if="visibles.length < movimientos.length" type="button" class="mdt__mas" @click="mostrar += POR_PAGINA">
          Ver {{ Math.min(POR_PAGINA, movimientos.length - visibles.length) }} más
        </button>
      </div>
    </template>
  </section>
</template>

<script setup>
import { computed, ref, watch } from 'vue'
import { formaLabel } from '../../lib/formatters.js'

const props = defineProps({
  // Una fila por producto, ya armada por `useMostrador` (`movimientosDelTurno`), lo último primero.
  movimientos: { type: Array, required: true },
})

const POR_PAGINA = 10
const abierto = ref(false)
const mostrar = ref(POR_PAGINA)

// Al plegar vuelve a los primeros 10: desplegar de nuevo no arranca en la página 3.
function alternar () {
  abierto.value = !abierto.value
  if (!abierto.value) mostrar.value = POR_PAGINA
}
// Otra caja (u otra sede): empieza plegado.
watch(() => props.movimientos.length === 0, (vacio) => { if (vacio) { abierto.value = false; mostrar.value = POR_PAGINA } })

const visibles = computed(() => props.movimientos.slice(0, mostrar.value))

const fmt  = (n) => Number(n ?? 0).toLocaleString('es-AR', { maximumFractionDigits: 1 })
const hora = (iso) => (iso ? new Date(iso).toLocaleTimeString('es-AR', { hour: '2-digit', minute: '2-digit', hourCycle: 'h23' }) : '')
// «Flor seca Vita Mac», con su espacio: el template pegaba la forma con la genética y el número.
const producto = (m) => [formaLabel(m.forma), m.genetica].filter(Boolean).join(' ')

const resumen = computed(() => {
  const n = props.movimientos.length
  const quienes = [...new Set(props.movimientos.flatMap(m => m.usuarios))]
  const ultima = props.movimientos[0]?.cuando   // vienen ordenados: lo último primero
  return [
    `${n} ${n === 1 ? 'producto movido' : 'productos movidos'}`,
    quienes.length ? `por ${quienes.join(' y ')}` : null,
    ultima ? `último a las ${hora(ultima)}` : null,
  ].filter(Boolean).join(' · ')
})
</script>

<style scoped>
.mdt {
  background: var(--c-sky-100); border-radius: 11px; padding: 10px 16px;
  display: flex; flex-direction: column; gap: 4px;
}
.mdt__hd {
  display: flex; align-items: center; gap: 10px; flex-wrap: wrap;
  background: none; border: 0; padding: 2px 0; text-align: left; cursor: pointer; width: 100%;
}
.mdt__lbl { font-size: var(--fs-12); font-weight: 700; color: var(--c-sky-600); text-transform: uppercase; letter-spacing: .04em; }
.mdt__resumen { font-size: var(--fs-13); color: var(--c-ink-700); flex: 1; min-width: 0; }
.mdt__chev { color: var(--c-sky-600); margin-left: auto; }
/* En el teléfono el resumen baja a su propio renglón: al lado del rótulo quedaba en una columna
   de una palabra por línea. */
@media (max-width: 640px) {
  .mdt__resumen { order: 3; flex-basis: 100%; }
}
.mdt__mov { margin: 0; font-size: var(--fs-13); color: var(--c-ink-700); }
.mdt__num  { font-family: var(--font-mono); color: var(--c-ink-900); }
.mdt__hora { color: var(--c-ink-500); font-size: var(--fs-12); margin-left: 4px; white-space: nowrap; }
.mdt__pie { display: flex; align-items: center; gap: 12px; margin-top: 4px; }
.mdt__cuenta { font-size: var(--fs-12); color: var(--c-ink-500); }
.mdt__mas {
  background: none; border: 1px solid var(--c-sky-600); color: var(--c-sky-600); border-radius: 8px;
  padding: 3px 10px; font-size: var(--fs-12); font-weight: 600; cursor: pointer;
}
</style>
