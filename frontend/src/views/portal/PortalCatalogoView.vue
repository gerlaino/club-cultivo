<template>
  <div class="pcv">
    <PortalCabecera titulo="Catálogo" bajada="Lo que hay hoy en el mostrador." />

    <div v-if="cargando" class="pcv__cargando"><DsSpinner :size="32" /></div>
    <PortalVacio v-else-if="!sedes.length" titulo="Hoy no hay nada publicado"
                 texto="Cuando tu organización tenga productos en el mostrador, los vas a ver acá." />

    <template v-else>
      <div v-if="sedes.length > 1" class="pcv__sedes" role="tablist" aria-label="Sede">
        <button v-for="s in sedes" :key="s.sede_id" type="button" role="tab" class="pcv__chip"
                :class="{ 'pcv__chip--on': s.sede_id === sedeId }" :aria-selected="s.sede_id === sedeId" @click="sedeId = s.sede_id">
          {{ s.sede }}
        </button>
      </div>
      <div v-if="formas.length > 1" class="pcv__formas" aria-label="Filtrar">
        <button v-for="f in ['Todo', ...formas]" :key="f" type="button" class="pcv__chip pcv__chip--chico"
                :class="{ 'pcv__chip--on': forma === f }" @click="forma = f">{{ f }}</button>
      </div>

      <ul class="pcv__grilla">
        <li v-for="p in productos" :key="p.stock_id" class="pcv__card" :class="{ 'pcv__card--no': p.disponibilidad === 'no_hay' }" data-testid="producto">
          <div class="pcv__foto" :style="p.foto_url ? { backgroundImage: `url(${p.foto_url})` } : null" aria-hidden="true"></div>
          <div class="pcv__cuerpo">
            <div class="pcv__fila">
              <b class="pcv__nombre">{{ p.nombre }}</b>
              <span class="pcv__disp" :class="`pcv__disp--${p.disponibilidad}`">{{ DISP[p.disponibilidad] }}</span>
            </div>
            <span class="pcv__det">{{ detalle(p) }}</span>
            <div class="pcv__fila pcv__fila--pie">
              <b v-if="p.precio">{{ pesos(p.precio) }} <span class="pcv__u">{{ p.unidad === 'g' ? 'el gramo' : 'c/u' }}</span></b>
              <RouterLink v-if="p.genetica?.id" :to="{ name: 'portal-genetica', params: { id: p.genetica.id } }" class="pcv__link">Ver la genética</RouterLink>
            </div>
          </div>
        </li>
      </ul>
      <p class="pcv__nota">Lo que hay puede cambiar durante el día. Se paga al retirar.</p>
    </template>
  </div>
</template>

<script setup>
// El catálogo del portal (27-oct-2026): lo que hay HOY sobre la mesa de cada sede, con su precio y
// si hay (nunca la cantidad). Lo publica la organización con las genéticas que marca «La ve el
// paciente». Cada producto lleva a la ficha de su genética.
import { computed, onMounted, ref } from 'vue'
import { getPortalCatalogo } from '@/lib/portalApi'
import PortalCabecera from '@/components/portal/PortalCabecera.vue'
import PortalVacio from '@/components/portal/PortalVacio.vue'
import DsSpinner from '@/design-system/components/Spinner.vue'

const DISP = { hay: 'Hay', pocos: 'Quedan pocos', no_hay: 'No hay hoy' }
const TIPOS = { indica: 'Índica', sativa: 'Sativa', hibrida: 'Híbrida', cbd: 'Rica en CBD' }

const sedes = ref([])
const cargando = ref(true)
const sedeId = ref(null)
const forma = ref('Todo')

const sede = computed(() => sedes.value.find((s) => s.sede_id === sedeId.value) || sedes.value[0])
const formas = computed(() => [...new Set((sede.value?.productos || []).map((p) => p.forma))])
const productos = computed(() => (sede.value?.productos || []).filter((p) => forma.value === 'Todo' || p.forma === forma.value))

const pct = (n) => `${String(Number(n).toFixed(1)).replace('.', ',').replace(',0', '')}%`
const pesos = (n) => new Intl.NumberFormat('es-AR', { style: 'currency', currency: 'ARS', maximumFractionDigits: 0 }).format(n)
function detalle(p) {
  const g = p.genetica
  return [p.forma, g?.tipo && (TIPOS[g.tipo] || g.tipo), g?.thc ? `THC ${pct(g.thc)}` : null, g?.cbd ? `CBD ${pct(g.cbd)}` : null]
    .filter(Boolean).join(' · ')
}

onMounted(async () => {
  try {
    sedes.value = await getPortalCatalogo()
    sedeId.value = sedes.value[0]?.sede_id ?? null
  } catch { sedes.value = [] } finally { cargando.value = false }
})
</script>

<style scoped>
.pcv { max-width: var(--p-ancho, 680px); margin: 0 auto; padding: 1.5rem 1.25rem 3rem; }
@media (min-width: 900px) { .pcv { max-width: 1000px; } }
.pcv__cargando { display: flex; justify-content: center; padding: 3rem; }
.pcv__sedes, .pcv__formas { display: flex; gap: .45rem; flex-wrap: wrap; margin-bottom: .8rem; }
.pcv__chip { min-height: 38px; padding: 0 1rem; border-radius: 999px; border: 1px solid var(--p-linea); background: var(--p-papel); color: var(--p-tinta); font: inherit; font-weight: 600; cursor: pointer; }
.pcv__chip--chico { min-height: 34px; font-size: .88rem; }
.pcv__chip--on { background: var(--p-marca); border-color: var(--p-marca); color: var(--p-papel); }
.pcv__grilla { list-style: none; margin: 0; padding: 0; display: grid; grid-template-columns: repeat(auto-fill, minmax(230px, 1fr)); gap: 1rem; }
.pcv__card { background: var(--p-papel); border: 1px solid var(--p-linea); border-radius: var(--p-radio-sm); overflow: hidden; display: flex; flex-direction: column; }
.pcv__card--no { opacity: .7; }
.pcv__foto { height: 120px; background: linear-gradient(135deg, var(--p-marca-linea), var(--p-marca)); background-size: cover; background-position: center; }
.pcv__cuerpo { padding: .8rem .9rem .9rem; display: flex; flex-direction: column; gap: .35rem; flex: 1; }
.pcv__fila { display: flex; justify-content: space-between; align-items: baseline; gap: .5rem; }
.pcv__fila--pie { margin-top: auto; }
.pcv__nombre { color: var(--p-tinta); }
.pcv__det { font-size: .85rem; color: var(--p-suave); }
.pcv__u { font-weight: 400; font-size: .8rem; color: var(--p-suave); }
.pcv__disp { font-size: .75rem; font-weight: 700; white-space: nowrap; }
.pcv__disp--hay { color: var(--p-ok); }
.pcv__disp--pocos { color: var(--p-atencion); }
.pcv__disp--no_hay { color: var(--p-urgente); }
.pcv__link { font-size: .85rem; font-weight: 700; color: var(--p-marca); text-decoration: none; }
.pcv__nota { margin-top: 1rem; font-size: .82rem; color: var(--p-suave); }
</style>
