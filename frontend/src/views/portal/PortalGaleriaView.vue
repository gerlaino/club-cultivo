<template>
  <div class="pgal">
    <PortalCabecera titulo="Galería" bajada="Fotos de lo que se cultiva." />

    <div v-if="cargando" class="pgal__cargando"><DsSpinner :size="32" /></div>

    <PortalVacio v-else-if="!fotos.length"
                 titulo="Todavía no hay fotos"
                 texto="Las fotos salen de las variedades del catálogo. Cuando tu organización cargue alguna, aparecen acá."
                 hacia-a="/portal/geneticas" hacia-txt="Ver el catálogo" />

    <template v-else>
      <ul class="pgal__grilla">
        <li v-for="f in fotos" :key="f.id">
          <button class="pgal__c" @click="abrir(f)">
            <img :src="f.url" :alt="f.genetica?.nombre || 'Foto'" loading="lazy" />
            <span class="pgal__pie">{{ f.genetica?.nombre }}</span>
          </button>
        </li>
      </ul>

      <!-- Visor. Se cierra con Escape o tocando fuera: en el teléfono es lo que todo el mundo
           intenta primero. -->
      <div v-if="abierta" class="pgal__visor" @click.self="abierta = null" role="dialog" aria-modal="true">
        <button class="pgal__cerrar" aria-label="Cerrar" @click="abierta = null">
          <X :size="22" :stroke-width="1.75" />
        </button>
        <img :src="abierta.url" :alt="abierta.genetica?.nombre || 'Foto'" class="pgal__grande" />
        <RouterLink v-if="abierta.genetica?.id" :to="`/portal/geneticas/${abierta.genetica.id}`" class="pgal__ir">
          Ver {{ abierta.genetica.nombre }}
        </RouterLink>
      </div>
    </template>
  </div>
</template>

<script setup>
import { ref, onMounted, onUnmounted } from 'vue'
import { X } from 'lucide-vue-next'
import { getPortalGaleria } from '@/lib/portalApi'
import PortalCabecera from '@/components/portal/PortalCabecera.vue'
import PortalVacio from '@/components/portal/PortalVacio.vue'
import DsSpinner from '@/design-system/components/Spinner.vue'

const fotos    = ref([])
const cargando = ref(true)
const abierta  = ref(null)

function abrir(f) { abierta.value = f }
function alTeclear(e) { if (e.key === 'Escape') abierta.value = null }

onMounted(async () => {
  window.addEventListener('keydown', alTeclear)
  try { fotos.value = await getPortalGaleria() } catch { /* queda el estado vacío */ }
  finally { cargando.value = false }
})
onUnmounted(() => window.removeEventListener('keydown', alTeclear))
</script>

<style scoped>
.pgal { max-width: var(--p-ancho); margin: 0 auto; padding: var(--sp-6) var(--sp-4) var(--sp-12); }
.pgal__cargando { display: flex; justify-content: center; padding: var(--sp-12); }

.pgal__grilla { list-style: none; margin: 0; padding: 0; display: grid; grid-template-columns: 1fr 1fr; gap: var(--sp-2); }
.pgal__c {
  display: block; width: 100%; padding: 0; border: 0; background: none; cursor: pointer;
  position: relative; border-radius: var(--p-radio-sm); overflow: hidden;
}
.pgal__c img { width: 100%; aspect-ratio: 1; object-fit: cover; display: block; }
.pgal__pie {
  position: absolute; left: 0; right: 0; bottom: 0;
  background: linear-gradient(transparent, rgb(0 0 0 / .6));
  color: #fff; font-size: var(--fs-12); font-weight: 600;
  padding: var(--sp-4) var(--sp-2) var(--sp-2); text-align: left;
}

.pgal__visor {
  position: fixed; inset: 0; z-index: 60;
  background: rgb(0 0 0 / .88);
  display: flex; flex-direction: column; align-items: center; justify-content: center;
  gap: var(--sp-4); padding: var(--sp-4);
}
.pgal__grande { max-width: 100%; max-height: 78vh; border-radius: var(--p-radio); }
.pgal__cerrar {
  position: absolute; top: var(--sp-4); right: var(--sp-4);
  background: none; border: 0; color: #fff; cursor: pointer; padding: var(--sp-1);
}
.pgal__ir {
  color: #fff; text-decoration: none; font-size: var(--fs-14); font-weight: 600;
  border: 1px solid rgb(255 255 255 / .4); border-radius: var(--r-pill);
  padding: var(--sp-2) var(--sp-5);
}

@media (min-width: 640px) { .pgal__grilla { grid-template-columns: repeat(3, 1fr); } }
</style>
