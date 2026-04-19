<template>
  <nav class="nav" :class="{ 'nav--scrolled': scrolled }">
    <div class="nav__inner">

      <RouterLink to="/" class="nav__brand">
        <img v-if="club?.logo_url" :src="club.logo_url" alt="Logo" class="nav__logo">
        <div v-else class="nav__logo-placeholder">
          <svg viewBox="0 0 20 20" fill="none">
            <path d="M10 2C7 2 3 4.5 3 9c0 2.5 1.5 4.5 3.5 5.5.5-2.5 1.8-4.5 3.5-5.5-1.5 1.5-2 3.5-2 5.5.6.3 1.3.5 2 .5s1.4-.2 2-.5c0-2-.5-4-2-5.5 1.7 1 3 3 3.5 5.5C15.5 13.5 17 11.5 17 9c0-4.5-4-7-7-7z" fill="currentColor"/>
          </svg>
        </div>
        <span class="nav__name">{{ club?.name || 'Club' }}</span>
      </RouterLink>

      <div class="nav__links">
        <RouterLink to="/" class="nav__link">Inicio</RouterLink>
        <RouterLink to="/geneticas" class="nav__link">Variedades</RouterLink>
        <RouterLink to="/noticias" class="nav__link">Noticias</RouterLink>
        <RouterLink to="/eventos" class="nav__link">Eventos</RouterLink>
        <RouterLink to="/contacto" class="nav__link">Contacto</RouterLink>
      </div>

      <RouterLink to="/ingresar" class="nav__cta">Iniciar sesión</RouterLink>

      <button class="nav__burger" @click="open = !open" :class="{ 'nav__burger--open': open }">
        <span></span><span></span><span></span>
      </button>
    </div>

    <div class="nav__mobile" :class="{ 'nav__mobile--open': open }">
      <RouterLink to="/" class="nav__mobile-link" @click="open = false">Inicio</RouterLink>
      <RouterLink to="/geneticas" class="nav__mobile-link" @click="open = false">Variedades</RouterLink>
      <RouterLink to="/noticias" class="nav__mobile-link" @click="open = false">Noticias</RouterLink>
      <RouterLink to="/eventos" class="nav__mobile-link" @click="open = false">Eventos</RouterLink>
      <RouterLink to="/contacto" class="nav__mobile-link" @click="open = false">Contacto</RouterLink>
      <RouterLink to="/ingresar" class="nav__mobile-cta" @click="open = false">Iniciar sesión</RouterLink>
    </div>
  </nav>
</template>

<script setup>
import { ref, onMounted, onUnmounted } from 'vue'
import { useClubStore } from '../stores/club.js'
import { storeToRefs } from 'pinia'

const store = useClubStore()
store.fetchClub()
const { club } = storeToRefs(store)

const open    = ref(false)
const scrolled = ref(false)

function onScroll() { scrolled.value = window.scrollY > 40 }
onMounted(() => window.addEventListener('scroll', onScroll))
onUnmounted(() => window.removeEventListener('scroll', onScroll))
</script>

<style scoped>
.nav {
  position: fixed; top: 0; left: 0; right: 0; z-index: 100;
  background: rgba(8,12,8,0.7);
  backdrop-filter: blur(20px);
  -webkit-backdrop-filter: blur(20px);
  border-bottom: 1px solid rgba(109,190,138,0.08);
  transition: background .3s;
}
.nav--scrolled { background: rgba(8,12,8,0.95); }

.nav__inner {
  max-width: 1200px; margin: 0 auto; padding: 0 2rem;
  height: 68px; display: flex; align-items: center; gap: 2rem;
}

.nav__brand { display: flex; align-items: center; gap: 10px; text-decoration: none; flex-shrink: 0; }

.nav__logo { width: 34px; height: 34px; border-radius: 8px; object-fit: cover; }

.nav__logo-placeholder {
  width: 34px; height: 34px;
  background: rgba(109,190,138,0.1);
  border: 1px solid rgba(109,190,138,0.2);
  border-radius: 8px;
  display: flex; align-items: center; justify-content: center;
  color: #6dbe8a;
}
.nav__logo-placeholder svg { width: 18px; height: 18px; }

.nav__name { color: #e8f0e8; font-size: 15px; font-weight: 500; letter-spacing: -0.01em; }

.nav__links { display: flex; gap: 2px; flex: 1; justify-content: center; }

.nav__link {
  color: rgba(180,200,183,0.5); font-size: 14px; text-decoration: none;
  padding: 7px 13px; border-radius: 8px; transition: all .2s; letter-spacing: -0.01em;
}
.nav__link:hover { color: #e8f0e8; background: rgba(109,190,138,0.07); }
.nav__link.router-link-active { color: #6dbe8a; background: rgba(109,190,138,0.08); }

.nav__cta {
  background: rgba(109,190,138,0.1); border: 1px solid rgba(109,190,138,0.22);
  color: #6dbe8a; padding: 8px 20px; border-radius: 8px;
  font-size: 13px; text-decoration: none; flex-shrink: 0; transition: all .2s;
}
.nav__cta:hover { background: rgba(109,190,138,0.16); border-color: rgba(109,190,138,0.35); }

.nav__burger {
  display: none; flex-direction: column; gap: 5px;
  background: none; border: none; cursor: pointer; padding: 4px; margin-left: auto;
}
.nav__burger span {
  display: block; width: 22px; height: 1.5px;
  background: rgba(180,200,183,0.6); border-radius: 2px; transition: all .25s;
}
.nav__burger--open span:nth-child(1) { transform: translateY(6.5px) rotate(45deg); }
.nav__burger--open span:nth-child(2) { opacity: 0; }
.nav__burger--open span:nth-child(3) { transform: translateY(-6.5px) rotate(-45deg); }

.nav__mobile {
  display: none; flex-direction: column;
  background: rgba(8,12,8,0.98); border-top: 1px solid rgba(109,190,138,0.08);
  max-height: 0; overflow: hidden; transition: max-height .3s ease, padding .3s;
}
.nav__mobile--open { max-height: 420px; padding: .75rem 1.5rem 1.25rem; }

.nav__mobile-link {
  color: rgba(180,200,183,0.6); font-size: 15px; text-decoration: none;
  padding: 13px 0; border-bottom: 1px solid rgba(109,190,138,0.07); transition: color .2s;
}
.nav__mobile-link:hover, .nav__mobile-link.router-link-active { color: #6dbe8a; }

.nav__mobile-cta {
  margin-top: 14px; background: rgba(109,190,138,0.1);
  border: 1px solid rgba(109,190,138,0.2); color: #6dbe8a;
  padding: 13px; border-radius: 9px; font-size: 14px; text-decoration: none; text-align: center;
}

@media (max-width: 768px) {
  .nav__links, .nav__cta { display: none; }
  .nav__burger { display: flex; }
  .nav__mobile { display: flex; }
}
</style>