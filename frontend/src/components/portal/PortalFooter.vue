<template>
  <footer class="pfo">
    <div class="pfo__inner">
      <div class="pfo__marca">
        <span class="pfo__nombre">{{ club?.name }}</span>
        <span v-if="club?.legal_name" class="pfo__legal">{{ club.legal_name }}</span>
      </div>

      <!-- Cómo se comunica con su organización. Esto era una SECCIÓN entera de la barra con un
           formulario de contacto que no mandaba nada a ningún lado; son cuatro datos y viven acá. -->
      <ul v-if="contacto.length" class="pfo__contacto">
        <li v-for="c in contacto" :key="c.txt">
          <a v-if="c.href" :href="c.href" class="pfo__dato" :target="c.fuera ? '_blank' : null" rel="noopener">
            <component :is="c.icono" :size="15" :stroke-width="1.75" />{{ c.txt }}
          </a>
          <span v-else class="pfo__dato"><component :is="c.icono" :size="15" :stroke-width="1.75" />{{ c.txt }}</span>
        </li>
      </ul>

      <p v-if="club?.horarios_atencion" class="pfo__horarios">{{ club.horarios_atencion }}</p>

      <nav class="pfo__nav" aria-label="Mi organización">
        <RouterLink to="/portal/organizacion" class="pfo__link">Mi organización</RouterLink>
        <RouterLink to="/portal/geneticas" class="pfo__link">Variedades</RouterLink>
        <RouterLink to="/portal/noticias" class="pfo__link">Novedades</RouterLink>
        <RouterLink to="/portal/eventos" class="pfo__link">Eventos</RouterLink>
        <RouterLink to="/portal/galeria" class="pfo__link">Galería</RouterLink>
      </nav>

      <div v-if="redes.length" class="pfo__redes">
        <a v-for="r in redes" :key="r.url" :href="r.url" class="pfo__red" target="_blank" rel="noopener">
          <component :is="r.icono" :size="16" :stroke-width="1.75" />
          <span class="pfo__red-txt">{{ r.txt }}</span>
        </a>
      </div>

      <!-- Sus datos y la salida. En el teléfono están en el menú; en escritorio NO estaban en
           ningún lado —el paciente no tenía cómo cerrar sesión sin achicar la ventana—. -->
      <div class="pfo__cuenta">
        <RouterLink to="/portal/cuenta" class="pfo__link">Mis datos y contraseña</RouterLink>
        <button type="button" class="pfo__salir" @click="salir">Cerrar sesión</button>
      </div>
    </div>
  </footer>
</template>

<script setup>
// El pie cierra el portal y no compite con nada. Venía de la web vieja: oscuro, con columnas y
// pensado para un sitio de marketing con visitantes que había que convencer. Acá el que lee ya es
// miembro.
//
// Se quedó además con los datos de contacto, que tenían una sección propia con un formulario de
// "Envianos un mensaje". Son cuatro datos: no justifican una entrada en la barra, y un formulario
// que promete respuesta cuando nadie lee esa bandeja es peor que no tenerlo.
import { computed } from 'vue'
import { useRouter } from 'vue-router'
import { storeToRefs } from 'pinia'
import { Instagram, Facebook, MessageCircle, Phone, Mail, MapPin, Globe } from 'lucide-vue-next'
import { usePortalClubStore } from '@/stores/portalClub'
import { useAuthStore } from '@/stores/auth'

const router = useRouter()
const { club } = storeToRefs(usePortalClubStore())

// Sólo lo que la organización cargó. Una línea "Teléfono —" vacía es peor que no tener la línea.
const contacto = computed(() => {
  const c = club.value || {}
  const direccion = [c.address, c.city, c.state].filter(Boolean).join(', ')

  return [
    c.phone   && { txt: c.phone,   href: `tel:${c.phone}`,    icono: Phone },
    c.email   && { txt: c.email,   href: `mailto:${c.email}`, icono: Mail },
    direccion && { txt: direccion, href: null,                icono: MapPin },
    c.website && { txt: c.website, href: c.website, fuera: true, icono: Globe },
  ].filter(Boolean)
})

const redes = computed(() => {
  const c = club.value || {}
  return [
    c.instagram_url && { url: c.instagram_url, icono: Instagram, txt: 'Instagram' },
    c.facebook_url  && { url: c.facebook_url,  icono: Facebook,  txt: 'Facebook' },
    c.whatsapp      && { url: `https://wa.me/${String(c.whatsapp).replace(/\D/g, '')}`, icono: MessageCircle, txt: 'WhatsApp' },
  ].filter(Boolean)
})

async function salir() {
  await useAuthStore().logOut()
  router.push('/login')
}
</script>

<style scoped>
.pfo { border-top: 1px solid var(--p-linea); background: var(--p-hundido); margin-top: auto; }

.pfo__inner {
  max-width: var(--p-ancho);
  margin: 0 auto;
  padding: var(--sp-8) var(--sp-4);
  display: flex;
  flex-direction: column;
  gap: var(--sp-4);
}

.pfo__marca { display: flex; flex-direction: column; }
.pfo__nombre { font-family: var(--p-display); font-weight: 600; font-size: var(--fs-16); }
.pfo__legal { font-size: var(--fs-12); color: var(--p-tenue); }

.pfo__contacto { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: var(--sp-2); }
.pfo__dato {
  display: inline-flex; align-items: center; gap: var(--sp-2);
  font-size: var(--fs-14); color: var(--p-suave); text-decoration: none;
}
a.pfo__dato:hover { color: var(--p-marca); text-decoration: underline; }

.pfo__nav { display: flex; flex-wrap: wrap; gap: var(--sp-2) var(--sp-4); }
.pfo__link { font-size: var(--fs-13); color: var(--p-suave); text-decoration: none; }
.pfo__link:hover { color: var(--p-marca); text-decoration: underline; }

.pfo__horarios { font-size: var(--fs-13); color: var(--p-tenue); margin: 0; white-space: pre-line; }

.pfo__redes { display: flex; flex-wrap: wrap; gap: var(--sp-4); }
.pfo__red {
  display: inline-flex; align-items: center; gap: var(--sp-1);
  font-size: var(--fs-13); color: var(--p-suave); text-decoration: none;
}
.pfo__red:hover { color: var(--p-marca); }
.pfo__red-txt { font-weight: 500; }

.pfo__cuenta {
  display: flex; flex-wrap: wrap; gap: var(--sp-2) var(--sp-4);
  padding-top: var(--sp-4); border-top: 1px solid var(--p-linea);
}
.pfo__salir {
  background: none; border: 0; padding: 0; cursor: pointer;
  font-family: inherit; font-size: var(--fs-13); color: var(--p-tenue);
}
.pfo__salir:hover { color: var(--p-urgente); text-decoration: underline; }
</style>
