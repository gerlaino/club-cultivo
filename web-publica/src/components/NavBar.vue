<template>
  <nav class="wp-nav">
    <div class="wp-nav-inner">

      <RouterLink to="/" class="wp-nav-brand">
        <img v-if="club?.logo_url" :src="club.logo_url" alt="Logo" class="wp-nav-logo-img">
        <div v-else class="wp-nav-logo-placeholder">
          <svg viewBox="0 0 20 20" fill="none" xmlns="http://www.w3.org/2000/svg">
            <path d="M10 2C7 2 3 4.5 3 9c0 2.5 1.5 4.5 3.5 5.5.5-2.5 1.8-4.5 3.5-5.5-1.5 1.5-2 3.5-2 5.5.6.3 1.3.5 2 .5s1.4-.2 2-.5c0-2-.5-4-2-5.5 1.7 1 3 3 3.5 5.5C15.5 13.5 17 11.5 17 9c0-4.5-4-7-7-7z" fill="currentColor"/>
          </svg>
        </div>
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

      <button class="wp-nav-hamburger" @click="menuAbierto = !menuAbierto" :class="{ 'wp-nav-hamburger--open': menuAbierto }">
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
  background: rgba(8, 12, 8, 0.92);
  backdrop-filter: blur(16px);
  -webkit-backdrop-filter: blur(16px);
  border-bottom: 1px solid rgba(109, 190, 138, 0.1);
}

.wp-nav-inner {
  max-width: 1200px;
  margin: 0 auto;
  padding: 0 2rem;
  height: 68px;
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
  width: 34px;
  height: 34px;
  border-radius: 8px;
  object-fit: cover;
}

.wp-nav-logo-placeholder {
  width: 34px;
  height: 34px;
  background: rgba(109, 190, 138, 0.12);
  border: 1px solid rgba(109, 190, 138, 0.2);
  border-radius: 8px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: #6dbe8a;
}

.wp-nav-logo-placeholder svg {
  width: 18px;
  height: 18px;
}

.wp-nav-name {
  color: #e8f0e8;
  font-size: 15px;
  font-weight: 500;
  letter-spacing: -0.01em;
}

.wp-nav-links {
  display: flex;
  gap: 2px;
  flex: 1;
  justify-content: center;
}

.wp-nav-link {
  color: rgba(180, 200, 183, 0.5);
  font-size: 14px;
  text-decoration: none;
  padding: 7px 13px;
  border-radius: 8px;
  transition: all 0.2s;
  letter-spacing: -0.01em;
}

.wp-nav-link:hover {
  color: #e8f0e8;
  background: rgba(109, 190, 138, 0.07);
}

.wp-nav-link.router-link-active {
  color: #6dbe8a;
  background: rgba(109, 190, 138, 0.08);
}

.wp-nav-cta {
  background: rgba(109, 190, 138, 0.1);
  border: 1px solid rgba(109, 190, 138, 0.22);
  color: #6dbe8a;
  padding: 8px 20px;
  border-radius: 8px;
  font-size: 13px;
  text-decoration: none;
  flex-shrink: 0;
  transition: all 0.2s;
  letter-spacing: -0.01em;
}

.wp-nav-cta:hover {
  background: rgba(109, 190, 138, 0.16);
  border-color: rgba(109, 190, 138, 0.35);
  color: #6dbe8a;
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
  height: 1.5px;
  background: rgba(180, 200, 183, 0.6);
  border-radius: 2px;
  transition: all 0.25s;
}

.wp-nav-hamburger--open span:nth-child(1) {
  transform: translateY(6.5px) rotate(45deg);
}
.wp-nav-hamburger--open span:nth-child(2) {
  opacity: 0;
}
.wp-nav-hamburger--open span:nth-child(3) {
  transform: translateY(-6.5px) rotate(-45deg);
}

.wp-nav-mobile {
  display: none;
  flex-direction: column;
  padding: 0 1.5rem;
  border-top: 1px solid rgba(109, 190, 138, 0.08);
  background: rgba(8, 12, 8, 0.98);
  max-height: 0;
  overflow: hidden;
  transition: max-height 0.3s ease, padding 0.3s ease;
}

.wp-nav-mobile--open {
  max-height: 420px;
  padding: 0.75rem 1.5rem 1.25rem;
}

.wp-nav-mobile-link {
  color: rgba(180, 200, 183, 0.6);
  font-size: 15px;
  text-decoration: none;
  padding: 13px 0;
  border-bottom: 1px solid rgba(109, 190, 138, 0.07);
  transition: color 0.2s;
}

.wp-nav-mobile-link:hover,
.wp-nav-mobile-link.router-link-active {
  color: #6dbe8a;
}

.wp-nav-mobile-cta {
  margin-top: 14px;
  background: rgba(109, 190, 138, 0.1);
  border: 1px solid rgba(109, 190, 138, 0.2);
  color: #6dbe8a;
  padding: 13px;
  border-radius: 9px;
  font-size: 14px;
  text-decoration: none;
  text-align: center;
  transition: background 0.2s;
}

.wp-nav-mobile-cta:hover {
  background: rgba(109, 190, 138, 0.16);
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