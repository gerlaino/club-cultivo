<template>
  <div class="pn">
    <PortalCabecera titulo="Novedades" bajada="Lo que la organización quiere contarte." />

    <div v-if="cargando" class="pn__cargando"><DsSpinner :size="32" /></div>

    <PortalVacio v-else-if="!noticias.length"
                 titulo="Todavía no hay novedades"
                 texto="Cuando tu organización publique algo, lo vas a ver acá." />

    <ul v-else class="pn__lista">
      <li v-for="n in noticias" :key="n.id">
        <RouterLink :to="`/portal/noticias/${n.id}`" class="pn__i">
          <div v-if="n.cover_url" class="pn__foto" :style="`background-image:url(${n.cover_url})`"></div>
          <div class="pn__txt">
            <span class="pn__f">{{ fecha(n.publicada_at) }}</span>
            <h2 class="pn__t">{{ n.titulo }}</h2>
            <p v-if="n.preview" class="pn__p">{{ n.preview }}</p>
          </div>
        </RouterLink>
      </li>
    </ul>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { getPortalNoticias } from '@/lib/portalApi'
import PortalCabecera from '@/components/portal/PortalCabecera.vue'
import PortalVacio from '@/components/portal/PortalVacio.vue'
import DsSpinner from '@/design-system/components/Spinner.vue'

const noticias = ref([])
const cargando = ref(true)

const fecha = (f) => (f ? new Date(f).toLocaleDateString('es-AR', { day: 'numeric', month: 'long', year: 'numeric' }) : '')

onMounted(async () => {
  try { noticias.value = await getPortalNoticias() } catch { /* queda el estado vacío */ }
  finally { cargando.value = false }
})
</script>

<style scoped>
.pn { max-width: var(--p-ancho); margin: 0 auto; padding: var(--sp-6) var(--sp-4) var(--sp-12); }
.pn__cargando { display: flex; justify-content: center; padding: var(--sp-12); }

.pn__lista { list-style: none; margin: 0; padding: 0; }
.pn__i {
  display: block; text-decoration: none; color: inherit;
  padding: var(--sp-5) 0; border-bottom: 1px solid var(--p-linea);
}
.pn__lista li:last-child .pn__i { border-bottom: 0; }
.pn__foto {
  aspect-ratio: 16 / 9; background: var(--p-marca-suave) center/cover no-repeat;
  border-radius: var(--p-radio-sm); margin-bottom: var(--sp-3);
}
.pn__txt { min-width: 0; }
.pn__f { font-size: var(--fs-12); letter-spacing: .1em; text-transform: uppercase; color: var(--p-tenue); }
.pn__t {
  font-family: var(--p-display);
  font-size: var(--fs-20); font-weight: 600; line-height: var(--lh-tight);
  letter-spacing: -.015em; margin: var(--sp-1) 0 var(--sp-2); text-wrap: balance;
}
.pn__p { color: var(--p-suave); margin: 0; line-height: var(--lh-base); }
.pn__i:hover .pn__t { text-decoration: underline; text-underline-offset: 3px; }

@media (min-width: 640px) {
  .pn__i { display: grid; grid-template-columns: 220px 1fr; gap: var(--sp-5); align-items: start; }
  .pn__foto { margin-bottom: 0; }
}
</style>
