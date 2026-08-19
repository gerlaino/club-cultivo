<template>
  <article class="pnd">
    <div v-if="cargando" class="pnd__cargando"><DsSpinner :size="32" /></div>

    <PortalVacio v-else-if="!noticia"
                 titulo="No encontramos esta novedad"
                 texto="Puede que ya no esté publicada."
                 hacia-a="/portal/noticias" hacia-txt="Ver todas las novedades" />

    <template v-else>
      <PortalCabecera :titulo="noticia.titulo" volver-a="/portal/noticias" volver-txt="Novedades" />
      <p class="pnd__f">{{ fecha(noticia.publicada_at) }}</p>

      <img v-if="noticia.cover_url" :src="noticia.cover_url" :alt="noticia.titulo" class="pnd__foto" />

      <div class="pnd__cuerpo">{{ noticia.contenido }}</div>
    </template>
  </article>
</template>

<script setup>
// El cuerpo va con `white-space: pre-line` y no como HTML: lo escribe el admin en un textarea y
// renderizarlo como HTML sería inyección desde un campo que edita un usuario.
import { ref, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { getPortalNoticia } from '@/lib/portalApi'
import PortalCabecera from '@/components/portal/PortalCabecera.vue'
import PortalVacio from '@/components/portal/PortalVacio.vue'
import DsSpinner from '@/design-system/components/Spinner.vue'

const route = useRoute()
const noticia  = ref(null)
const cargando = ref(true)

const fecha = (f) => (f ? new Date(f).toLocaleDateString('es-AR', { day: 'numeric', month: 'long', year: 'numeric' }) : '')

onMounted(async () => {
  try { noticia.value = await getPortalNoticia(route.params.id) } catch { /* queda el vacío */ }
  finally { cargando.value = false }
})
</script>

<style scoped>
.pnd { max-width: 620px; margin: 0 auto; padding: var(--sp-6) var(--sp-4) var(--sp-12); }
.pnd__cargando { display: flex; justify-content: center; padding: var(--sp-12); }
.pnd__f {
  font-size: var(--fs-12); letter-spacing: .1em; text-transform: uppercase;
  color: var(--p-tenue); margin: calc(var(--sp-6) * -1 + var(--sp-2)) 0 var(--sp-5);
}
.pnd__foto { width: 100%; border-radius: var(--p-radio); margin-bottom: var(--sp-6); display: block; }
.pnd__cuerpo {
  white-space: pre-line;
  font-size: var(--fs-16); line-height: var(--lh-loose); color: var(--p-tinta);
}
</style>
