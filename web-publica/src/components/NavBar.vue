<template>
  <nav class="wp-nav">
    <div class="wp-nav-inner">

      <RouterLink to="/" class="wp-nav-brand">
        <img v-if="club?.logo_url" :src="club.logo_url" alt="Logo" class="wp-nav-logo-img">
        <div v-else class="wp-nav-logo-placeholder">🌿</div>
        <span class="wp-nav-name">{{ club?.name || 'Club Cannábico' }}</span>
      </RouterLink>

      <div class="wp-nav-links">
        <RouterLink to="/" class="wp-nav-link">Inicio</RouterLink>
        <RouterLink to="/geneticas" class="wp-nav-link">Variedades</RouterLink>
        <RouterLink to="/noticias" class="wp-nav-link">Noticias</RouterLink>
        <RouterLink to="/eventos" class="wp-nav-link">Eventos</RouterLink>
        <RouterLink to="/contacto" class="wp-nav-link">Contacto</RouterLink>
      </div>

      <RouterLink to="/ingresar" class="wp-nav-cta">
        Iniciar sesión
      </RouterLink>

      <button class="wp-nav-hamburger" @click="menuAbierto = !menuAbierto">
        <span></span><span></span><span></span>
      </button>

    </div>

    <div class="wp-nav-mobile" :class="{ 'wp-nav-mobile--open': menuAbierto }">
      <RouterLink to="/" class="wp-nav-mobile-link" @click="menuAbierto = false">Inicio</RouterLink>
      <RouterLink to="/geneticas" class="wp-nav-mobile-link" @click="menuAbierto = false">Variedades</RouterLink>
      <RouterLink to="/noticias" class="wp-nav-mobile-link" @click="menuAbierto = false">Noticias</RouterLink>
      <RouterLink to="/eventos" class="wp-nav-mobile-link" @click="menuAbierto = false">Eventos</RouterLink>
      <RouterLink to="/contacto" class="wp-nav-mobile-link" @click="menuAbierto = false">Contacto</RouterLink>
      <RouterLink to="/ingresar" class="wp-nav-mobile-cta" @click="menuAbierto = false">Iniciar sesión</RouterLink>
    </div>
  </nav>
</template>

<script setup>
import { ref } from 'vue'
import { useClubStore } from '../stores/club.js'
import { storeToRefs } from 'pinia'

const store = useClubStore()
store.fetchClub()
const { club } = storeToRefs(store)

const menuAbierto = ref(false)
</script>

<style scoped>
.wp-nav {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  z-index: 100;
  background: #050d06ee;
  backdrop-filter: blur(12px);
  border-bottom: 1px solid #1b5e2033;
}

.wp-nav-inner {
  max-width: 1200px;
  margin: 0 auto;
  padding: 0 2rem;
  height: 64px;
  display: flex;
  align-items: center;
  gap: 2rem;
}

.wp-nav-brand {
  display: flex;
  align-items: center;
  gap: 10px;
  text-decoration: none;
  flex-shrink: 0;
}

.wp-nav-logo-img {
  width: 36px;
  height: 36px;
  border-radius: 8px;
  object-fit: cover;
}

.wp-nav-logo-placeholder {
  width: 36px;
  height: 36px;
  background: #1b5e20;
  border-radius: 8px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 18px;
}

.wp-nav-name {
  color: #a5d6a7;
  font-size: 15px;
  font-weight: 500;
}

.wp-nav-links {
  display: flex;
  gap: 8px;
  flex: 1;
  justify-content: center;
}

.wp-nav-link {
  color: #81c784;
  font-size: 14px;
  text-decoration: none;
  padding: 6px 12px;
  border-radius: 8px;
  transition: background 0.2s, color 0.2s;
  opacity: 0.75;
}

.wp-nav-link:hover,
.wp-nav-link.router-link-active {
  opacity: 1;
  color: #a5d6a7;
  background: #1b5e2022;
}

.wp-nav-cta {
  background: linear-gradient(135deg, #1b5e20, #2e7d32);
  color: #e8f5e9;
  padding: 9px 20px;
  border-radius: 9px;
  font-size: 13px;
  text-decoration: none;
  flex-shrink: 0;
  transition: opacity 0.2s;
}

.wp-nav-cta:hover {
  opacity: 0.85;
}

.wp-nav-hamburger {
  display: none;
  flex-direction: column;
  gap: 5px;
  background: none;
  border: none;
  cursor: pointer;
  padding: 4px;
  margin-left: auto;
}

.wp-nav-hamburger span {
  display: block;
  width: 22px;
  height: 2px;
  background: #81c784;
  border-radius: 2px;
}

.wp-nav-mobile {
  display: none;
  flex-direction: column;
  padding: 0 1.5rem 1rem;
  border-top: 1px solid #1b5e2022;
  background: #050d06;
  max-height: 0;
  overflow: hidden;
  transition: max-height 0.3s ease;
}

.wp-nav-mobile--open {
  max-height: 400px;
}

.wp-nav-mobile-link {
  color: #81c784;
  font-size: 15px;
  text-decoration: none;
  padding: 12px 0;
  border-bottom: 1px solid #1b5e2011;
  opacity: 0.8;
}

.wp-nav-mobile-cta {
  margin-top: 12px;
  background: linear-gradient(135deg, #1b5e20, #2e7d32);
  color: #e8f5e9;
  padding: 12px;
  border-radius: 9px;
  font-size: 14px;
  text-decoration: none;
  text-align: center;
}

@media (max-width: 768px) {
  .wp-nav-links,
  .wp-nav-cta {
    display: none;
  }
  .wp-nav-hamburger {
    display: flex;
  }
  .wp-nav-mobile {
    display: flex;
  }
}
</style>