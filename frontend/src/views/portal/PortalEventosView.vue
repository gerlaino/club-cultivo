<template>
  <div class="pe">
    <PortalCabecera titulo="Eventos" bajada="Talleres, charlas y actividades de la organización." />

    <div v-if="cargando" class="pe__cargando"><DsSpinner :size="32" /></div>

    <template v-else>
      <div class="pe__tabs" role="tablist">
        <button class="pe__tab" :class="{ 'pe__tab--on': !pasados }" role="tab"
                :aria-selected="!pasados" @click="ver(false)">Próximos</button>
        <button class="pe__tab" :class="{ 'pe__tab--on': pasados }" role="tab"
                :aria-selected="pasados" @click="ver(true)">Anteriores</button>
      </div>

      <PortalVacio v-if="!eventos.length"
                   :titulo="pasados ? 'No hay eventos anteriores' : 'No hay eventos próximos'"
                   :texto="pasados ? 'Todavía no pasó ninguno.' : 'Cuando tu organización programe algo, lo vas a ver acá.'" />

      <ul v-else class="pe__lista">
        <li v-for="e in eventos" :key="e.id">
          <RouterLink :to="`/portal/eventos/${e.id}`" class="pe__i">
            <span class="pe__f">
              <span class="pe__f-d">{{ dia(e.fecha_inicio) }}</span>
              <span class="pe__f-m">{{ mes(e.fecha_inicio) }}</span>
            </span>
            <span class="pe__c">
              <span class="pe__t">{{ e.titulo }}</span>
              <span class="pe__m">
                <Clock :size="12" :stroke-width="1.75" /> {{ hora(e.fecha_inicio) }}
                <template v-if="e.lugar">
                  <MapPin :size="12" :stroke-width="1.75" /> {{ e.lugar }}
                </template>
              </span>
            </span>
            <img v-if="e.imagenes_urls?.length" :src="e.imagenes_urls[0]" :alt="e.titulo" class="pe__foto" loading="lazy" />
          </RouterLink>
        </li>
      </ul>
    </template>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { Clock, MapPin } from 'lucide-vue-next'
import { getPortalEventos } from '@/lib/portalApi'
import PortalCabecera from '@/components/portal/PortalCabecera.vue'
import PortalVacio from '@/components/portal/PortalVacio.vue'
import DsSpinner from '@/design-system/components/Spinner.vue'

const MESES = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic']

const eventos  = ref([])
const cargando = ref(true)
const pasados  = ref(false)

const dia  = (f) => (f ? new Date(f).getDate() : '')
const mes  = (f) => (f ? MESES[new Date(f).getMonth()] : '')
const hora = (f) => (f ? new Date(f).toLocaleTimeString('es-AR', { hour: '2-digit', minute: '2-digit' }) : '')

async function ver(anteriores) {
  pasados.value = anteriores
  cargando.value = true
  try { eventos.value = await getPortalEventos(anteriores) } catch { eventos.value = [] }
  finally { cargando.value = false }
}

onMounted(() => ver(false))
</script>

<style scoped>
.pe { max-width: var(--p-ancho); margin: 0 auto; padding: var(--sp-6) var(--sp-4) var(--sp-12); }
.pe__cargando { display: flex; justify-content: center; padding: var(--sp-12); }

.pe__tabs { display: flex; gap: var(--sp-2); margin-bottom: var(--sp-5); }
.pe__tab {
  border: 1px solid var(--p-linea); background: none; color: var(--p-suave);
  font-size: var(--fs-13); padding: var(--sp-1) var(--sp-4);
  border-radius: var(--r-pill); cursor: pointer; transition: all var(--t-fast);
}
.pe__tab--on { background: var(--p-marca); border-color: var(--p-marca); color: #fff; }

.pe__lista { list-style: none; margin: 0; padding: 0; }
.pe__i {
  display: flex; gap: var(--sp-4); align-items: center;
  padding: var(--sp-4) 0; text-decoration: none; color: inherit;
  border-bottom: 1px solid var(--p-linea);
}
.pe__lista li:last-child .pe__i { border-bottom: 0; }
.pe__f {
  display: flex; flex-direction: column; align-items: center; justify-content: center;
  width: 52px; flex: 0 0 auto; background: var(--p-marca-suave);
  border-radius: var(--p-radio-sm); padding: var(--sp-2) 0;
}
.pe__f-d { font-family: var(--p-display); font-size: var(--fs-18); font-weight: 700; color: var(--p-marca-fuerte); line-height: 1; }
.pe__f-m { font-size: var(--fs-12); text-transform: uppercase; letter-spacing: .06em; color: var(--p-tenue); }
.pe__c { display: flex; flex-direction: column; min-width: 0; flex: 1; }
.pe__t { font-weight: 600; }
.pe__m { display: flex; align-items: center; gap: var(--sp-1); flex-wrap: wrap; font-size: var(--fs-13); color: var(--p-tenue); }
.pe__foto { width: 68px; height: 52px; object-fit: cover; border-radius: var(--p-radio-sm); flex: 0 0 auto; }
.pe__i:hover .pe__t { text-decoration: underline; text-underline-offset: 3px; }
</style>
