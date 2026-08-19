<template>
  <div class="pco">
    <PortalCabecera titulo="Contacto" bajada="Cómo comunicarte con tu organización." />

    <div v-if="cargando" class="pco__cargando"><DsSpinner :size="32" /></div>

    <template v-else>
      <ul class="pco__lista">
        <li v-for="d in datos" :key="d.txt" class="pco__i">
          <span class="pco__ico"><component :is="d.icono" :size="16" :stroke-width="1.75" /></span>
          <span class="pco__c">
            <span class="pco__l">{{ d.label }}</span>
            <a v-if="d.href" :href="d.href" class="pco__v" target="_blank" rel="noopener">{{ d.txt }}</a>
            <span v-else class="pco__v">{{ d.txt }}</span>
          </span>
        </li>
      </ul>

      <PortalVacio v-if="!datos.length"
                   titulo="Sin datos de contacto cargados"
                   texto="Tu organización todavía no cargó cómo comunicarse con ella." />

      <p v-if="club?.horarios_atencion" class="pco__horarios">
        <span class="pco__l">Horarios</span>
        {{ club.horarios_atencion }}
      </p>
    </template>
  </div>
</template>

<script setup>
// Los datos de contacto que carga el admin. Sólo aparece lo que cargó: una fila "Teléfono —" vacía
// es peor que no tener la fila.
import { computed, ref, onMounted } from 'vue'
import { storeToRefs } from 'pinia'
import { Phone, Mail, MapPin, Globe, Instagram, Facebook, MessageCircle } from 'lucide-vue-next'
import { usePortalClubStore } from '@/stores/portalClub'
import PortalCabecera from '@/components/portal/PortalCabecera.vue'
import PortalVacio from '@/components/portal/PortalVacio.vue'
import DsSpinner from '@/design-system/components/Spinner.vue'

const store = usePortalClubStore()
const { club } = storeToRefs(store)
const cargando = ref(true)

const datos = computed(() => {
  const c = club.value || {}
  const direccion = [c.address, c.city, c.state].filter(Boolean).join(', ')
  const wa = c.whatsapp && String(c.whatsapp).replace(/\D/g, '')

  return [
    c.phone   && { label: 'Teléfono',  txt: c.phone,   href: `tel:${c.phone}`,     icono: Phone },
    wa        && { label: 'WhatsApp',  txt: c.whatsapp, href: `https://wa.me/${wa}`, icono: MessageCircle },
    c.email   && { label: 'Correo',    txt: c.email,   href: `mailto:${c.email}`,  icono: Mail },
    direccion && { label: 'Dirección', txt: direccion, href: null,                 icono: MapPin },
    c.website && { label: 'Sitio',     txt: c.website, href: c.website,            icono: Globe },
    c.instagram_url && { label: 'Instagram', txt: 'Ver perfil', href: c.instagram_url, icono: Instagram },
    c.facebook_url  && { label: 'Facebook',  txt: 'Ver página', href: c.facebook_url,  icono: Facebook },
  ].filter(Boolean)
})

onMounted(async () => {
  await store.fetchClub()
  cargando.value = false
})
</script>

<style scoped>
.pco { max-width: var(--p-ancho); margin: 0 auto; padding: var(--sp-6) var(--sp-4) var(--sp-12); }
.pco__cargando { display: flex; justify-content: center; padding: var(--sp-12); }

.pco__lista { list-style: none; margin: 0; padding: 0; }
.pco__i {
  display: flex; gap: var(--sp-4); align-items: center;
  padding: var(--sp-4) 0; border-bottom: 1px solid var(--p-linea);
}
.pco__lista li:last-child { border-bottom: 0; }
.pco__ico {
  width: 34px; height: 34px; flex: 0 0 auto;
  display: flex; align-items: center; justify-content: center;
  background: var(--p-marca-suave); color: var(--p-marca); border-radius: var(--r-pill);
}
.pco__c { display: flex; flex-direction: column; min-width: 0; }
.pco__l { font-size: var(--fs-12); text-transform: uppercase; letter-spacing: .08em; color: var(--p-tenue); }
.pco__v { font-weight: 500; color: var(--p-tinta); text-decoration: none; word-break: break-word; }
a.pco__v:hover { color: var(--p-marca); text-decoration: underline; }

.pco__horarios {
  margin: var(--sp-6) 0 0; padding: var(--sp-4);
  background: var(--p-hundido); border-radius: var(--p-radio);
  white-space: pre-line; line-height: var(--lh-base);
}
.pco__horarios .pco__l { display: block; margin-bottom: var(--sp-1); }
</style>
