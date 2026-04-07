<template>
  <footer class="wp-footer">
    <div class="wp-footer-inner">

      <div class="wp-footer-brand-col">
        <div class="wp-footer-name">{{ club?.name || 'Club Cannábico' }}</div>
        <div class="wp-footer-legal">{{ club?.legal_name }}</div>
        <div class="wp-footer-desc">
          Asociación civil sin fines de lucro dedicada al cultivo responsable y acceso legal para pacientes REPROCANN.
        </div>
        <div v-if="club?.numero_resolucion_reprocann" class="wp-footer-reprocann">
          {{ club.numero_resolucion_reprocann }}
        </div>
      </div>

      <div class="wp-footer-col">
        <div class="wp-footer-col-title">Navegación</div>
        <RouterLink to="/geneticas" class="wp-footer-link">Variedades</RouterLink>
        <RouterLink to="/noticias" class="wp-footer-link">Noticias</RouterLink>
        <RouterLink to="/eventos" class="wp-footer-link">Eventos</RouterLink>
        <RouterLink to="/galeria" class="wp-footer-link">Galería</RouterLink>
        <RouterLink to="/contacto" class="wp-footer-link">Contacto</RouterLink>
      </div>

      <div class="wp-footer-col">
        <div class="wp-footer-col-title">Contacto</div>
        <div v-if="club?.address" class="wp-footer-contact-item">
          <span class="wp-footer-contact-icon">📍</span>
          {{ club.address }}, {{ club.city }}
        </div>
        <div v-if="club?.phone" class="wp-footer-contact-item">
          <span class="wp-footer-contact-icon">📞</span>
          {{ club.phone }}
        </div>
        <div v-if="club?.email" class="wp-footer-contact-item">
          <span class="wp-footer-contact-icon">✉️</span>
          {{ club.email }}
        </div>
      </div>

    </div>

    <div class="wp-footer-bottom">
      <div class="wp-footer-copy">
        © {{ new Date().getFullYear() }} {{ club?.name }}. Todos los derechos reservados.
      </div>
      <div class="wp-footer-powered">
        Potenciado por <strong>Cultivo Espacial</strong>
      </div>
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
.wp-footer {
  background: #050d06;
  border-top: 1px solid #1b5e2022;
  margin-top: auto;
}

.wp-footer-inner {
  max-width: 1200px;
  margin: 0 auto;
  padding: 3rem 2rem 2rem;
  display: grid;
  grid-template-columns: 2fr 1fr 1fr;
  gap: 3rem;
}

.wp-footer-name {
  color: #66bb6a;
  font-size: 17px;
  font-weight: 500;
  margin-bottom: 4px;
}

.wp-footer-legal {
  color: #81c784;
  font-size: 12px;
  opacity: 0.5;
  margin-bottom: 12px;
}

.wp-footer-desc {
  color: #81c784;
  font-size: 13px;
  line-height: 1.6;
  opacity: 0.6;
  margin-bottom: 12px;
}

.wp-footer-reprocann {
  display: inline-block;
  background: #1b5e2022;
  border: 1px solid #1b5e2044;
  color: #66bb6a;
  font-size: 11px;
  padding: 4px 12px;
  border-radius: 20px;
}

.wp-footer-col-title {
  color: #a5d6a7;
  font-size: 12px;
  font-weight: 500;
  text-transform: uppercase;
  letter-spacing: 0.08em;
  margin-bottom: 16px;
}

.wp-footer-link {
  display: block;
  color: #81c784;
  font-size: 13px;
  text-decoration: none;
  opacity: 0.6;
  margin-bottom: 10px;
  transition: opacity 0.2s;
}

.wp-footer-link:hover {
  opacity: 1;
}

.wp-footer-contact-item {
  display: flex;
  align-items: flex-start;
  gap: 8px;
  color: #81c784;
  font-size: 13px;
  opacity: 0.6;
  margin-bottom: 10px;
  line-height: 1.4;
}

.wp-footer-contact-icon {
  font-size: 13px;
  flex-shrink: 0;
  margin-top: 1px;
}

.wp-footer-bottom {
  max-width: 1200px;
  margin: 0 auto;
  padding: 1.5rem 2rem;
  border-top: 1px solid #1b5e2022;
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.wp-footer-copy {
  color: #81c784;
  font-size: 12px;
  opacity: 0.4;
}

.wp-footer-powered {
  color: #66bb6a;
  font-size: 11px;
  opacity: 0.5;
}

.wp-footer-powered strong {
  font-weight: 500;
}

@media (max-width: 768px) {
  .wp-footer-inner {
    grid-template-columns: 1fr;
    gap: 2rem;
  }
  .wp-footer-bottom {
    flex-direction: column;
    gap: 8px;
    text-align: center;
  }
}
</style>