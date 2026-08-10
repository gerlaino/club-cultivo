<template>
  <div class="sus">
    <div class="sus__header">
      <h1 class="sus__title">Suscripción</h1>
      <p class="sus__subtitle">Estado y detalle de tu plan en Club Cultivo.</p>
    </div>

    <div class="sus__plan-card">
      <div class="sus__plan-badge">Plan activo</div>
      <h2 class="sus__plan-nombre">{{ planNombre }}</h2>
      <p class="sus__plan-desc">Acceso completo a todas las funcionalidades del sistema de gestión de cultivos.</p>

      <dl class="sus__specs">
        <div class="sus__spec-row">
          <dt class="sus__spec-key">Estado</dt>
          <dd class="sus__spec-val sus__spec-val--green">Activo</dd>
        </div>
        <div class="sus__spec-row">
          <dt class="sus__spec-key">Club</dt>
          <dd class="sus__spec-val">{{ club.name }}</dd>
        </div>
      </dl>
    </div>

    <div class="sus__contact">
      <span class="sus__contact-ico">💬</span>
      <div>
        <p class="sus__contact-title">¿Necesitás cambiar tu plan?</p>
        <p class="sus__contact-desc">Contactá al equipo de Club Cultivo para actualizar, ajustar o cancelar tu suscripción.</p>
      </div>
    </div>
  </div>
</template>

<script setup>
import { computed } from 'vue'
import { useClubStore } from '../stores/club.js'

const club = useClubStore()
const planNombre = computed(() => {
  const f = club.features
  if (!f) return 'Standard'
  if (f.ia) return 'Premium IA'
  if (f.benchmark) return 'Pro'
  return 'Standard'
})
</script>

<style scoped>
.sus { max-width: 600px; margin: 0 auto; padding: 1.5rem 1.25rem; display: flex; flex-direction: column; gap: 1.5rem; }
@media (max-width: 640px) { .sus { padding: 1rem .75rem 80px; } }

.sus__header {}
.sus__title    { font-size: 1.4rem; font-weight: 700; color: #0f2611; margin: 0 0 .25rem; letter-spacing: -.025em; }
.sus__subtitle { font-size: .875rem; color: #60725d; margin: 0; }

.sus__plan-card { background: #fff; border: 1px solid #e8f0e9; border-radius: 14px; padding: 1.5rem; display: flex; flex-direction: column; gap: 1rem; }
.sus__plan-badge { display: inline-flex; align-items: center; background: #dcfce7; color: #15803d; font-size: .72rem; font-weight: 700; padding: .25em .75em; border-radius: 999px; width: fit-content; }
.sus__plan-nombre { font-size: 1.5rem; font-weight: 800; color: #0f2611; margin: 0; letter-spacing: -.03em; }
.sus__plan-desc { font-size: .875rem; color: #60725d; margin: 0; line-height: 1.6; }

.sus__specs { margin: 0; display: flex; flex-direction: column; border: 1px solid var(--c-slate-100); border-radius: 10px; overflow: hidden; }
.sus__spec-row { display: flex; justify-content: space-between; align-items: center; padding: .65rem 1rem; border-bottom: 1px solid var(--c-slate-50); font-size: .82rem; }
.sus__spec-row:last-child { border-bottom: none; }
.sus__spec-key { color: var(--c-slate-400); font-size: .72rem; font-weight: 500; text-transform: uppercase; letter-spacing: .04em; }
.sus__spec-val { color: #0f2611; font-weight: 600; }
.sus__spec-val--green { color: #15803d; }

.sus__contact { display: flex; align-items: flex-start; gap: 1rem; background: #f6faf6; border: 1px solid #e8f0e9; border-radius: 12px; padding: 1.25rem; }
.sus__contact-ico { font-size: 1.5rem; flex-shrink: 0; line-height: 1; }
.sus__contact-title { font-size: .875rem; font-weight: 700; color: #0f2611; margin: 0 0 .25rem; }
.sus__contact-desc  { font-size: .82rem; color: #60725d; margin: 0; line-height: 1.5; }
</style>
