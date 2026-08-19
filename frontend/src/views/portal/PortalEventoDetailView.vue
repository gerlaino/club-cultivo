<template>
  <article class="ped">
    <div v-if="cargando" class="ped__cargando"><DsSpinner :size="32" /></div>

    <PortalVacio v-else-if="!evento"
                 titulo="No encontramos este evento"
                 texto="Puede que ya no esté activo."
                 hacia-a="/portal/eventos" hacia-txt="Ver todos los eventos" />

    <template v-else>
      <PortalCabecera :titulo="evento.titulo" volver-a="/portal/eventos" volver-txt="Eventos" />

      <dl class="ped__datos">
        <div class="ped__dato">
          <dt><CalendarDays :size="14" :stroke-width="1.75" /> Cuándo</dt>
          <dd>{{ fechaLarga(evento.fecha_inicio) }} · {{ hora(evento.fecha_inicio) }}<template v-if="evento.fecha_fin"> a {{ hora(evento.fecha_fin) }}</template></dd>
        </div>
        <div v-if="evento.lugar" class="ped__dato">
          <dt><MapPin :size="14" :stroke-width="1.75" /> Dónde</dt>
          <dd>{{ evento.lugar }}</dd>
        </div>
      </dl>

      <div v-if="evento.imagenes_urls?.length" class="ped__fotos">
        <img v-for="(f, i) in evento.imagenes_urls" :key="i" :src="f" :alt="evento.titulo" loading="lazy" />
      </div>

      <div v-if="evento.descripcion" class="ped__cuerpo">{{ evento.descripcion }}</div>

      <!-- Anotarse no se hace por el portal: el cupo y la lista los maneja la organización. En
           vez de mandarlo a una pantalla de contacto se le da el link que marca o escribe. -->
      <p class="ped__anotarse">
        ¿Querés participar? Avisale a tu organización<template v-if="comoAvisar">
          por <a :href="comoAvisar.href">{{ comoAvisar.txt }}</a></template>.
      </p>
    </template>
  </article>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { storeToRefs } from 'pinia'
import { usePortalClubStore } from '@/stores/portalClub'
import { CalendarDays, MapPin } from 'lucide-vue-next'
import { getPortalEvento } from '@/lib/portalApi'
import PortalCabecera from '@/components/portal/PortalCabecera.vue'
import PortalVacio from '@/components/portal/PortalVacio.vue'
import DsSpinner from '@/design-system/components/Spinner.vue'

const route = useRoute()
const evento   = ref(null)
const cargando = ref(true)

// WhatsApp primero, después teléfono, después mail: es el orden en que la gente avisa. Si la
// organización no cargó ninguno, la frase sale igual sin el enlace.
const { club } = storeToRefs(usePortalClubStore())
const comoAvisar = computed(() => {
  const c = club.value || {}
  if (c.whatsapp) return { txt: 'WhatsApp', href: `https://wa.me/${String(c.whatsapp).replace(/\D/g, '')}` }
  if (c.phone)    return { txt: c.phone,    href: `tel:${c.phone}` }
  if (c.email)    return { txt: c.email,    href: `mailto:${c.email}` }
  return null
})

const fechaLarga = (f) => (f ? new Date(f).toLocaleDateString('es-AR', { weekday: 'long', day: 'numeric', month: 'long' }) : '')
const hora       = (f) => (f ? new Date(f).toLocaleTimeString('es-AR', { hour: '2-digit', minute: '2-digit' }) : '')

onMounted(async () => {
  try { evento.value = await getPortalEvento(route.params.id) } catch { /* queda el vacío */ }
  finally { cargando.value = false }
})
</script>

<style scoped>
.ped { max-width: 620px; margin: 0 auto; padding: var(--sp-6) var(--sp-4) var(--sp-12); }
.ped__cargando { display: flex; justify-content: center; padding: var(--sp-12); }

.ped__datos { margin: 0 0 var(--sp-6); display: flex; flex-direction: column; gap: var(--sp-3); }
.ped__dato { display: flex; flex-wrap: wrap; gap: var(--sp-2) var(--sp-4); align-items: baseline; }
.ped__dato dt {
  display: flex; align-items: center; gap: var(--sp-1);
  font-size: var(--fs-12); text-transform: uppercase; letter-spacing: .08em;
  color: var(--p-tenue); width: 96px; flex: 0 0 auto;
}
.ped__dato dd { margin: 0; font-weight: 500; }

.ped__fotos { display: grid; gap: var(--sp-2); margin-bottom: var(--sp-6); }
.ped__fotos img { width: 100%; border-radius: var(--p-radio); display: block; }

.ped__cuerpo { white-space: pre-line; font-size: var(--fs-16); line-height: var(--lh-loose); }

.ped__anotarse {
  margin: var(--sp-8) 0 0; padding: var(--sp-4);
  background: var(--p-marca-suave); border-radius: var(--p-radio);
  font-size: var(--fs-14); color: var(--p-suave);
}
.ped__anotarse a { color: var(--p-marca); font-weight: 600; }

@media (min-width: 640px) { .ped__fotos { grid-template-columns: 1fr 1fr; } }
</style>
