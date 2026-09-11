<script setup>
// LA CAJA DEL REPARTIDOR: cuánto lleva encima y cómo la entrega.
//
// El monto de una rendición lo pone el sistema —pedirle que se acuerde de lo que cobró en doce
// puertas es pedirle un error— pero nunca se lo mostrábamos: rendía a ciegas, sin poder contar
// los billetes contra nada. Si el que recibía contaba distinto, se enteraba al día siguiente con
// la diferencia anotada a su nombre.
//
// Vive en su propia solapa y NO en el inicio: el inicio es a dónde va ahora. Acá entra cuando la
// pregunta es la plata, que es dos o tres veces por día.
import { computed, onMounted } from 'vue'
import { Wallet, Package } from 'lucide-vue-next'
import DsSpinner from '../../design-system/components/Spinner.vue'
import RendicionCajaCard from '../../components/RendicionCajaCard.vue'
import { useCajaDeliveryStore } from '../../stores/cajaDelivery.js'

// El MISMO dato que mira la barra de abajo para ponerle el punto a la solapa: si saliera de dos
// consultas, un día el punto y la pantalla dirían cosas distintas de la misma plata.
const store   = useCajaDeliveryStore()
const caja    = computed(() => store.caja)
const loading = computed(() => !store.caja && !store.error)
const error   = computed(() => store.error)

const fmt  = (n) => `$${Number(n ?? 0).toLocaleString('es-AR', { maximumFractionDigits: 0 })}`
const hora = (iso) => (iso ? new Date(iso).toLocaleTimeString('es-AR', { hour: '2-digit', minute: '2-digit' }) : '')

const cargar = () => store.cargar()

onMounted(cargar)
</script>

<template>
  <div class="cjd">
    <div v-if="loading" class="cjd__loading"><DsSpinner /></div>

    <!-- "Vacío" y "no se pudo cargar" no son lo mismo: decir tranquilamente que no lleva nada
         sobre un error es lo peor que le podemos contestar a alguien que tiene plata encima. -->
    <div v-else-if="error" class="cjd__error">
      <p>No se pudo cargar tu caja.</p>
      <button class="cjd__retry" @click="cargar">Reintentar</button>
    </div>

    <template v-else-if="caja">
      <!-- EL NÚMERO, primero y grande: es a lo que vino. -->
      <section class="cjd__total">
        <Wallet :size="20" :stroke-width="1.75" />
        <div>
          <div class="cjd__total-lbl">Llevás en efectivo</div>
          <div class="cjd__total-n">{{ fmt(caja.efectivo_ars) }}</div>
          <div class="cjd__total-sub">
            {{ caja.cobros.length }} {{ caja.cobros.length === 1 ? 'entrega cobrada' : 'entregas cobradas' }}
          </div>
        </div>
      </section>

      <!-- Rendir, el estado de la que rindió y lo que quedó a su nombre. Es el mismo componente
           que usa el que recibe: la regla de la rendición vive en un solo lugar. -->
      <RendicionCajaCard @recibida="cargar" @rendida="cargar" />

      <!-- El desglose es para CONTAR: entrega por entrega, con el nombre y la hora, así puede ir
           tachando mientras separa los billetes. -->
      <section v-if="caja.cobros.length" class="cjd__detalle">
        <h3 class="cjd__h3">De dónde salen</h3>
        <div v-for="c in caja.cobros" :key="c.id" class="cjd__fila">
          <div class="cjd__fila-quien">
            <span class="cjd__fila-nombre">{{ c.paciente || 'Sin nombre' }}</span>
            <span class="cjd__fila-hora">{{ hora(c.hora) }}</span>
          </div>
          <span class="cjd__fila-monto">{{ fmt(c.monto_ars) }}</span>
        </div>
      </section>

      <!-- LO DE TRANSFERENCIA NO LO LLEVA ENCIMA: esa plata ya entró a la cuenta de la
           organización. Sumarlo al total sería pedirle billetes que nunca tuvo. -->
      <p v-if="caja.transferencias_ars > 0" class="cjd__transf">
        Hoy cobraste <b>{{ fmt(caja.transferencias_ars) }}</b> por transferencia. Eso ya entró a la
        organización: no lo rendís.
      </p>

      <p v-if="caja.paquetes_sin_entregar > 0" class="cjd__paquetes">
        <Package :size="14" :stroke-width="2" />
        Volvés con {{ caja.paquetes_sin_entregar }}
        {{ caja.paquetes_sin_entregar === 1 ? 'paquete' : 'paquetes' }} sin entregar. Se entregan
        con la caja, en la misma vuelta.
      </p>
    </template>
  </div>
</template>

<style scoped>
.cjd { padding: 1rem; display: flex; flex-direction: column; gap: 1rem; }
.cjd__loading, .cjd__error { text-align: center; padding: 2rem 1rem; color: var(--c-slate-500); }
.cjd__retry {
  margin-top: .6rem; border: 1px solid var(--c-slate-300); background: #fff; border-radius: 8px;
  padding: .45rem .9rem; font-weight: 600; cursor: pointer;
}

.cjd__total {
  display: flex; align-items: center; gap: .9rem;
  background: #fff; border: 1px solid var(--c-slate-200); border-radius: 14px; padding: 1rem 1.1rem;
  color: #ea580c;
}
.cjd__total-lbl { font-size: .78rem; font-weight: 600; color: var(--c-slate-500); text-transform: uppercase; letter-spacing: .03em; }
.cjd__total-n   { font-size: 2rem; font-weight: 800; color: var(--c-slate-900); line-height: 1.1; }
.cjd__total-sub { font-size: .82rem; color: var(--c-slate-500); }

.cjd__detalle { background: #fff; border: 1px solid var(--c-slate-200); border-radius: 14px; padding: .8rem 1rem; }
.cjd__h3 { margin: 0 0 .5rem; font-size: .78rem; font-weight: 700; text-transform: uppercase;
           letter-spacing: .04em; color: var(--c-slate-500); }
.cjd__fila {
  display: flex; align-items: center; justify-content: space-between; gap: .8rem;
  padding: .5rem 0; border-bottom: 1px solid var(--c-slate-100);
}
.cjd__fila:last-child { border-bottom: none; }
.cjd__fila-quien  { display: flex; flex-direction: column; min-width: 0; }
.cjd__fila-nombre { font-weight: 600; color: var(--c-slate-800); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.cjd__fila-hora   { font-size: .75rem; color: var(--c-slate-400); }
.cjd__fila-monto  { font-weight: 700; color: var(--c-slate-900); white-space: nowrap; }

/* Una caja de texto con un dato adentro va en block: con flex, un <b> se parte en columnas. */
.cjd__transf, .cjd__paquetes {
  display: block; margin: 0; background: var(--c-slate-50); border: 1px solid var(--c-slate-200);
  border-radius: 12px; padding: .7rem .9rem; font-size: .84rem; color: var(--c-slate-600);
}
</style>
