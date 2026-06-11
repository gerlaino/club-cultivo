<template>
  <aside class="mdc-sb">
    <!-- Brand -->
    <div class="mdc-sb__brand">
      <img src="/logo-ce-icono.png" class="mdc-sb__logo" alt="" />
      <div class="mdc-sb__brand-text">
        <span class="mdc-sb__brand-name">Cultivo Espacial</span>
        <span class="mdc-sb__brand-role">Panel Médico</span>
      </div>
    </div>

    <!-- Nav -->
    <nav class="mdc-sb__nav">
      <RouterLink
        to="/medico"
        class="mdc-sb__link"
        :class="{ 'mdc-sb__link--active': $route.path === '/medico' }"
      >
        <LayoutDashboard :size="16" :stroke-width="1.75" />
        <span>Inicio</span>
      </RouterLink>

      <RouterLink to="/medico/turnos" class="mdc-sb__link" active-class="mdc-sb__link--active">
        <CalendarDays :size="16" :stroke-width="1.75" />
        <span>Turnera</span>
        <span v-if="turnosHoy > 0" class="mdc-sb__badge">{{ turnosHoy }}</span>
      </RouterLink>

      <RouterLink to="/medico/pacientes" class="mdc-sb__link" active-class="mdc-sb__link--active">
        <Users :size="16" :stroke-width="1.75" />
        <span>Mis Pacientes</span>
      </RouterLink>

      <RouterLink to="/medico/indicaciones" class="mdc-sb__link" active-class="mdc-sb__link--active">
        <FileHeart :size="16" :stroke-width="1.75" />
        <span>Indicaciones</span>
      </RouterLink>

      <RouterLink to="/medico/documentos" class="mdc-sb__link" active-class="mdc-sb__link--active">
        <FolderOpen :size="16" :stroke-width="1.75" />
        <span>Documentos</span>
      </RouterLink>

      <div class="mdc-sb__divider"></div>

      <RouterLink to="/medico/disponibilidad" class="mdc-sb__link" active-class="mdc-sb__link--active">
        <Settings2 :size="16" :stroke-width="1.75" />
        <span>Mi disponibilidad</span>
      </RouterLink>
    </nav>
  </aside>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { LayoutDashboard, CalendarDays, Users, FileHeart, FolderOpen, Settings2 } from 'lucide-vue-next'
import { getMedicoTurnos } from '../../lib/api.js'

const turnosHoy = ref(0)

onMounted(async () => {
  try {
    const { data } = await getMedicoTurnos()
    const hoy = new Date().toDateString()
    turnosHoy.value = (data || []).filter(t =>
      new Date(t.fecha_hora).toDateString() === hoy &&
      t.estado !== 'cancelado' && t.estado !== 'realizado'
    ).length
  } catch { /* silent */ }
})
</script>

<style scoped>
.mdc-sb {
  width: 220px;
  min-width: 220px;
  flex-shrink: 0;
  background: var(--c-role-admin);
  display: flex;
  flex-direction: column;
  height: 100vh;
  position: sticky;
  top: 0;
  overflow-y: auto;
  overflow-x: hidden;
  scrollbar-width: thin;
  scrollbar-color: var(--c-leaf-600) transparent;
}
.mdc-sb::-webkit-scrollbar { width: 4px; }
.mdc-sb::-webkit-scrollbar-track { background: transparent; }
.mdc-sb::-webkit-scrollbar-thumb { background: var(--c-leaf-600); border-radius: 4px; }

/* Brand */
.mdc-sb__brand {
  display: flex;
  align-items: center;
  gap: var(--sp-3);
  padding: var(--sp-5) var(--sp-5) var(--sp-4);
  border-bottom: 1px solid rgba(168,201,181,0.15);
  flex-shrink: 0;
}
.mdc-sb__logo {
  width: 30px; height: 30px; border-radius: 50%;
  object-fit: cover; flex-shrink: 0;
}
.mdc-sb__brand-text { display: flex; flex-direction: column; gap: 1px; min-width: 0; }
.mdc-sb__brand-name {
  font-size: var(--fs-14);
  font-weight: 600;
  color: var(--c-paper);
  letter-spacing: -.01em;
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
}
.mdc-sb__brand-role {
  font-size: var(--fs-11);
  font-weight: 600;
  color: var(--c-leaf-300);
  text-transform: uppercase;
  letter-spacing: .06em;
}

/* Nav */
.mdc-sb__nav {
  flex: 1;
  padding: var(--sp-3) var(--sp-2);
  display: flex;
  flex-direction: column;
  gap: 1px;
}

.mdc-sb__link {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 9px 14px;
  border-radius: var(--r-md);
  font-size: var(--fs-13);
  font-weight: 400;
  color: var(--c-leaf-300);
  text-decoration: none;
  transition: background var(--t-fast), color var(--t-fast);
  border-left: 3px solid transparent;
}
.mdc-sb__link:hover {
  background: rgba(255,255,255,0.06);
  color: var(--c-paper);
}
.mdc-sb__link--active {
  background: var(--c-leaf-700);
  color: var(--c-paper);
  border-left-color: var(--c-leaf-300);
  font-weight: 500;
}

.mdc-sb__badge {
  margin-left: auto;
  background: #d97706;
  color: #fff;
  font-size: .62rem;
  font-weight: 800;
  min-width: 18px;
  height: 18px;
  border-radius: 999px;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 0 .3rem;
}

.mdc-sb__divider {
  height: 1px;
  background: rgba(168,201,181,0.15);
  margin: var(--sp-2) var(--sp-2);
}

@media (max-width: 1023px) {
  .mdc-sb { display: none; }
}
</style>
