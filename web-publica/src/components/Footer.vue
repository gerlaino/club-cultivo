<template>
  <footer class="footer">
    <div class="footer__inner">

      <div class="footer__brand">
        <div class="footer__name">{{ club?.name || 'Club Cannábico' }}</div>
        <div v-if="club?.legal_name" class="footer__legal">{{ club.legal_name }}</div>
        <p class="footer__desc">
          Asociación civil sin fines de lucro dedicada al cultivo responsable
          y acceso legal para pacientes REPROCANN.
        </p>
        <div v-if="club?.numero_resolucion_reprocann" class="footer__badge">
          {{ club.numero_resolucion_reprocann }}
        </div>
        <div class="footer__socials">
          <a v-if="club?.instagram_url" :href="club.instagram_url" target="_blank" class="footer__social" aria-label="Instagram">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
              <rect x="2" y="2" width="20" height="20" rx="5"/>
              <circle cx="12" cy="12" r="4"/>
              <circle cx="17.5" cy="6.5" r="0.5" fill="currentColor" stroke="none"/>
            </svg>
          </a>
          <a v-if="club?.facebook_url" :href="club.facebook_url" target="_blank" class="footer__social" aria-label="Facebook">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
              <path d="M18 2h-3a5 5 0 0 0-5 5v3H7v4h3v8h4v-8h3l1-4h-4V7a1 1 0 0 1 1-1h3z"/>
            </svg>
          </a>
          <a v-if="club?.whatsapp" :href="`https://wa.me/${club.whatsapp.replace(/\D/g,'')}`" target="_blank" class="footer__social" aria-label="WhatsApp">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
              <path d="M21 11.5a8.38 8.38 0 0 1-.9 3.8 8.5 8.5 0 0 1-7.6 4.7 8.38 8.38 0 0 1-3.8-.9L3 21l1.9-5.7a8.38 8.38 0 0 1-.9-3.8 8.5 8.5 0 0 1 4.7-7.6 8.38 8.38 0 0 1 3.8-.9h.5a8.48 8.48 0 0 1 8 8v.5z"/>
            </svg>
          </a>
        </div>
      </div>

      <div class="footer__col">
        <div class="footer__col-title">Navegación</div>
        <RouterLink to="/geneticas" class="footer__link">Variedades</RouterLink>
        <RouterLink to="/noticias" class="footer__link">Noticias</RouterLink>
        <RouterLink to="/eventos" class="footer__link">Eventos</RouterLink>
        <RouterLink to="/galeria" class="footer__link">Galería</RouterLink>
        <RouterLink to="/contacto" class="footer__link">Contacto</RouterLink>
      </div>

      <div class="footer__col">
        <div class="footer__col-title">Contacto</div>
        <div v-if="club?.address" class="footer__contact">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
            <path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"/><circle cx="12" cy="10" r="3"/>
          </svg>
          {{ club.address }}<span v-if="club.city">, {{ club.city }}</span>
        </div>
        <div v-if="club?.phone" class="footer__contact">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
            <path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07A19.5 19.5 0 0 1 4.69 13 19.79 19.79 0 0 1 1.62 4.36 2 2 0 0 1 3.59 2h3a2 2 0 0 1 2 1.72c.127.96.361 1.903.7 2.81a2 2 0 0 1-.45 2.11L7.91 9.91a16 16 0 0 0 6.16 6.16l.92-.92a2 2 0 0 1 2.11-.45c.907.339 1.85.573 2.81.7A2 2 0 0 1 22 16.92z"/>
          </svg>
          {{ club.phone }}
        </div>
        <div v-if="club?.email" class="footer__contact">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
            <path d="M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z"/><polyline points="22,6 12,13 2,6"/>
          </svg>
          {{ club.email }}
        </div>
      </div>

    </div>

    <div class="footer__bottom">
      <div class="footer__copy">© {{ new Date().getFullYear() }} {{ club?.name }}. Todos los derechos reservados.</div>
      <div class="footer__powered">Potenciado por <strong>Cultivo Espacial</strong></div>
    </div>
  </footer>
</template>

<script setup>
import { useClubStore } from '../stores/club.js'
import { storeToRefs } from 'pinia'
const store = useClubStore()
store.fetchClub()
const { club } = storeToRefs(store)
</script>

<style scoped>
.footer { background: #080c08; border-top: 1px solid rgba(109,190,138,0.1); margin-top: auto; }

.footer__inner {
  max-width: 1200px; margin: 0 auto;
  padding: 3.5rem 2rem 2.5rem;
  display: grid; grid-template-columns: 2fr 1fr 1fr; gap: 3rem;
}

.footer__name { color: #e8f0e8; font-size: 16px; font-weight: 500; margin-bottom: 4px; letter-spacing: -0.01em; }
.footer__legal { color: rgba(180,200,183,0.3); font-size: 12px; margin-bottom: 14px; }
.footer__desc { color: rgba(180,200,183,0.45); font-size: 13px; line-height: 1.65; margin-bottom: 16px; max-width: 300px; }

.footer__badge {
  display: inline-block;
  background: rgba(109,190,138,0.07); border: 1px solid rgba(109,190,138,0.15);
  color: #6dbe8a; font-size: 11px; padding: 4px 12px; border-radius: 20px;
  margin-bottom: 20px; letter-spacing: 0.02em;
}

.footer__socials { display: flex; gap: 8px; }
.footer__social {
  width: 34px; height: 34px; border-radius: 8px;
  border: 1px solid rgba(109,190,138,0.12);
  background: rgba(109,190,138,0.04);
  display: flex; align-items: center; justify-content: center;
  color: rgba(180,200,183,0.45); transition: all .2s;
}
.footer__social:hover { border-color: rgba(109,190,138,0.3); color: #6dbe8a; background: rgba(109,190,138,0.09); }
.footer__social svg { width: 15px; height: 15px; }

.footer__col-title {
  color: rgba(180,200,183,0.3); font-size: 11px; font-weight: 500;
  text-transform: uppercase; letter-spacing: 0.1em; margin-bottom: 18px;
}
.footer__link {
  display: block; color: rgba(180,200,183,0.5); font-size: 13px;
  text-decoration: none; margin-bottom: 11px; transition: color .2s; letter-spacing: -0.01em;
}
.footer__link:hover { color: #e8f0e8; }

.footer__contact {
  display: flex; align-items: flex-start; gap: 9px;
  color: rgba(180,200,183,0.5); font-size: 13px; margin-bottom: 11px; line-height: 1.5;
}
.footer__contact svg { width: 14px; height: 14px; flex-shrink: 0; margin-top: 2px; color: rgba(109,190,138,0.5); }

.footer__bottom {
  max-width: 1200px; margin: 0 auto; padding: 1.5rem 2rem;
  border-top: 1px solid rgba(109,190,138,0.07);
  display: flex; justify-content: space-between; align-items: center;
}
.footer__copy { color: rgba(180,200,183,0.25); font-size: 12px; }
.footer__powered { color: rgba(180,200,183,0.25); font-size: 11px; }
.footer__powered strong { font-weight: 500; color: rgba(109,190,138,0.4); }

@media (max-width: 768px) {
  .footer__inner { grid-template-columns: 1fr; gap: 2rem; }
  .footer__bottom { flex-direction: column; gap: 8px; text-align: center; }
}
</style>