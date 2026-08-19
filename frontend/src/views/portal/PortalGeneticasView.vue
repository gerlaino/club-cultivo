<template>
  <div class="pg">
    <PortalCabecera titulo="Variedades" bajada="Lo que se cultiva y está en el catálogo de la organización." />

    <div v-if="cargando" class="pg__cargando"><DsSpinner :size="32" /></div>

    <PortalVacio v-else-if="!geneticas.length"
                 titulo="Todavía no hay variedades publicadas"
                 texto="Cuando tu organización publique su catálogo, lo vas a ver acá." />

    <template v-else>
      <!-- Filtrar por tipo tiene sentido con muchas; con cuatro, es ruido. -->
      <div v-if="tipos.length > 1" class="pg__filtros" role="tablist">
        <button v-for="t in tipos" :key="t.clave" class="pg__filtro"
                :class="{ 'pg__filtro--on': filtro === t.clave }"
                role="tab" :aria-selected="filtro === t.clave" @click="filtro = t.clave">
          {{ t.txt }}
        </button>
      </div>

      <ul class="pg__grilla">
        <li v-for="g in filtradas" :key="g.id">
          <RouterLink :to="`/portal/geneticas/${g.id}`" class="pg__c">
            <span class="pg__foto">
              <img v-if="g.fotos_urls?.length" :src="g.fotos_urls[0]" :alt="g.nombre" loading="lazy" />
              <LeafHerbarium v-else :size="30" class="pg__sinfoto" />
              <span v-if="g.registrada_inase" class="pg__inase">INASE</span>
            </span>
            <span class="pg__n">{{ g.nombre }}</span>
            <span class="pg__d">
              <template v-if="g.tipo">{{ TIPOS[g.tipo] || g.tipo }}</template>
              <template v-if="g.thc != null"> · THC {{ g.thc }}%</template>
              <template v-if="g.cbd != null"> · CBD {{ g.cbd }}%</template>
            </span>
          </RouterLink>
        </li>
      </ul>
    </template>
  </div>
</template>

<script setup>
// El catálogo. Es lo que más se mira del portal: alguien que va a retirar entra a ver qué hay.
import { ref, computed, onMounted } from 'vue'
import { getPortalGeneticas } from '@/lib/portalApi'
import PortalCabecera from '@/components/portal/PortalCabecera.vue'
import PortalVacio from '@/components/portal/PortalVacio.vue'
import LeafHerbarium from '@/design-system/icons/LeafHerbarium.vue'
import DsSpinner from '@/design-system/components/Spinner.vue'

const TIPOS = { indica: 'Índica', sativa: 'Sativa', hibrida: 'Híbrida', ruderalis: 'Ruderalis' }

const geneticas = ref([])
const cargando  = ref(true)
const filtro    = ref('todas')

// Los filtros salen de lo que HAY, no de una lista fija: ofrecer "Ruderalis" en un club que no
// tiene ninguna es un botón que devuelve vacío.
const tipos = computed(() => {
  const presentes = [...new Set(geneticas.value.map(g => g.tipo).filter(Boolean))]
  if (!presentes.length) return []
  return [{ clave: 'todas', txt: 'Todas' },
          ...presentes.map(t => ({ clave: t, txt: TIPOS[t] || t }))]
})

const filtradas = computed(() =>
  filtro.value === 'todas' ? geneticas.value : geneticas.value.filter(g => g.tipo === filtro.value)
)

onMounted(async () => {
  try { geneticas.value = await getPortalGeneticas() } catch { /* queda el estado vacío */ }
  finally { cargando.value = false }
})
</script>

<style scoped>
.pg { max-width: var(--p-ancho); margin: 0 auto; padding: var(--sp-6) var(--sp-4) var(--sp-12); }
.pg__cargando { display: flex; justify-content: center; padding: var(--sp-12); }

.pg__filtros { display: flex; flex-wrap: wrap; gap: var(--sp-2); margin-bottom: var(--sp-5); }
.pg__filtro {
  border: 1px solid var(--p-linea); background: none; color: var(--p-suave);
  font-size: var(--fs-13); padding: var(--sp-1) var(--sp-4);
  border-radius: var(--r-pill); cursor: pointer; transition: all var(--t-fast);
}
.pg__filtro:hover { border-color: var(--p-marca-linea); }
.pg__filtro--on { background: var(--p-marca); border-color: var(--p-marca); color: #fff; }

.pg__grilla { list-style: none; margin: 0; padding: 0; display: grid; grid-template-columns: 1fr 1fr; gap: var(--sp-4); }
.pg__c { display: block; text-decoration: none; color: inherit; }
.pg__foto {
  position: relative; display: flex; align-items: center; justify-content: center;
  aspect-ratio: 4 / 3; background: var(--p-marca-suave);
  border-radius: var(--p-radio-sm); overflow: hidden; margin-bottom: var(--sp-2);
}
.pg__foto img { width: 100%; height: 100%; object-fit: cover; }
.pg__sinfoto { color: var(--p-marca-linea); }
.pg__inase {
  position: absolute; top: var(--sp-2); left: var(--sp-2);
  background: var(--p-marca-fuerte); color: #fff;
  font-size: 10px; font-weight: 700; letter-spacing: .06em;
  padding: 2px var(--sp-2); border-radius: var(--r-pill);
}
.pg__n { display: block; font-weight: 600; font-size: var(--fs-14); }
.pg__d { display: block; font-size: var(--fs-12); color: var(--p-tenue); }
.pg__c:hover .pg__n { text-decoration: underline; text-underline-offset: 3px; }

@media (min-width: 640px) { .pg__grilla { grid-template-columns: repeat(3, 1fr); } }
</style>
