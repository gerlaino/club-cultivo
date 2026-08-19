<template>
  <footer class="pfo">
    <div class="pfo__inner">
      <div class="pfo__marca">
        <span class="pfo__nombre">{{ club?.name }}</span>
        <span v-if="club?.legal_name" class="pfo__legal">{{ club.legal_name }}</span>
      </div>

      <nav class="pfo__nav" aria-label="Secciones">
        <RouterLink to="/portal/geneticas" class="pfo__link">Variedades</RouterLink>
        <RouterLink to="/portal/noticias" class="pfo__link">Novedades</RouterLink>
        <RouterLink to="/portal/eventos" class="pfo__link">Eventos</RouterLink>
        <RouterLink to="/portal/galeria" class="pfo__link">Galería</RouterLink>
        <RouterLink to="/portal/contacto" class="pfo__link">Contacto</RouterLink>
      </nav>

      <p v-if="club?.horarios_atencion" class="pfo__horarios">{{ club.horarios_atencion }}</p>

      <div v-if="redes.length" class="pfo__redes">
        <a v-for="r in redes" :key="r.url" :href="r.url" class="pfo__red" target="_blank" rel="noopener">
          <component :is="r.icono" :size="16" :stroke-width="1.75" />
          <span class="pfo__red-txt">{{ r.txt }}</span>
        </a>
      </div>
    </div>
  </footer>
</template>

<script setup>
// El pie cierra el portal y no compite con nada. Venía de la web vieja: oscuro, con columnas y
// pensado para un sitio de marketing con visitantes que había que convencer. Acá el que lee ya es
// miembro.
import { computed } from 'vue'
import { storeToRefs } from 'pinia'
import { Instagram, Facebook, MessageCircle } from 'lucide-vue-next'
import { usePortalClubStore } from '@/stores/portalClub'

const { club } = storeToRefs(usePortalClubStore())

const redes = computed(() => {
  const c = club.value || {}
  return [
    c.instagram_url && { url: c.instagram_url, icono: Instagram, txt: 'Instagram' },
    c.facebook_url  && { url: c.facebook_url,  icono: Facebook,  txt: 'Facebook' },
    c.whatsapp      && { url: `https://wa.me/${String(c.whatsapp).replace(/\D/g, '')}`, icono: MessageCircle, txt: 'WhatsApp' },
  ].filter(Boolean)
})
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
</style>
