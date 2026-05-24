<template>
  <div class="aud-home">
    <h1 class="aud-home__title">Panel de Auditoría</h1>
    <p class="aud-home__sub">Acceso de solo lectura a los informes del club.</p>

    <OnboardingChecklist />

    <div class="aud-home__cards">
      <RouterLink to="/auditor/reprocann" class="aud-card">
        <FileCheck :size="28" :stroke-width="1.5" />
        <span class="aud-card__label">REPROCANN</span>
        <span class="aud-card__desc">Estado de habilitaciones médicas</span>
      </RouterLink>
      <RouterLink to="/auditor/produccion" class="aud-card">
        <Sprout :size="28" :stroke-width="1.5" />
        <span class="aud-card__label">Producción</span>
        <span class="aud-card__desc">Lotes, plantas y rendimiento</span>
      </RouterLink>
      <RouterLink to="/auditor/dispensaciones" class="aud-card">
        <Package :size="28" :stroke-width="1.5" />
        <span class="aud-card__label">Dispensaciones</span>
        <span class="aud-card__desc">Entregas a pacientes</span>
      </RouterLink>
      <RouterLink to="/auditor/sedes" class="aud-card">
        <Building2 :size="28" :stroke-width="1.5" />
        <span class="aud-card__label">Sedes</span>
        <span class="aud-card__desc">Instalaciones y stock</span>
      </RouterLink>
      <RouterLink to="/auditor/cumplimiento" class="aud-card">
        <ShieldAlert :size="28" :stroke-width="1.5" />
        <span class="aud-card__label">Cumplimiento</span>
        <span class="aud-card__desc">Alertas y tasas regulatorias</span>
      </RouterLink>
    </div>
  </div>
</template>

<script setup>
import { FileCheck, Sprout, Package, Building2, ShieldAlert } from 'lucide-vue-next'
import OnboardingChecklist from '../../components/dashboards/OnboardingChecklist.vue'
</script>

<style scoped>
.aud-home { padding: var(--sp-6); max-width: 800px; }
.aud-home__title { font-size: var(--fs-24); font-weight: 800; color: var(--c-ink-900); margin: 0 0 var(--sp-1); }
.aud-home__sub { color: var(--c-ink-500); font-size: var(--fs-14); margin: 0 0 var(--sp-6); }
.aud-home__cards { display: grid; grid-template-columns: repeat(auto-fill, minmax(180px, 1fr)); gap: var(--sp-4); }
.aud-card {
  display: flex; flex-direction: column; align-items: flex-start; gap: var(--sp-2);
  background: var(--c-paper); border: 1px solid var(--c-ink-100); border-radius: var(--r-lg);
  padding: var(--sp-5); text-decoration: none; color: var(--c-ink-700);
  transition: border-color .15s, box-shadow .15s;
}
.aud-card:hover { border-color: #8B5A2B; box-shadow: 0 2px 8px rgba(139,90,43,.1); color: #8B5A2B; }
.aud-card__label { font-size: var(--fs-15); font-weight: 700; color: var(--c-ink-900); }
.aud-card__desc { font-size: var(--fs-12); color: var(--c-ink-500); }
</style>
