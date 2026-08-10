<script setup>
import { useAuthStore } from '../../stores/auth.js'
const auth = useAuthStore()
</script>

<template>
  <div class="dd">
    <div class="dd__card">
      <div class="dd__icon">🌿</div>
      <h1 class="dd__title">Bienvenido, {{ auth.user?.first_name || 'usuario' }}</h1>
      <p class="dd__msg">Tu cuenta está activa. Contactá al administrador del club para que te asigne un rol y puedas acceder a las funciones del sistema.</p>
      <div class="dd__info">
        <div class="dd__info-row">
          <span class="dd__info-label">Email</span>
          <span class="dd__info-val">{{ auth.user?.email }}</span>
        </div>
        <div class="dd__info-row" v-if="auth.user?.role">
          <span class="dd__info-label">Rol actual</span>
          <span class="dd__info-val">{{ auth.user.role }}</span>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.dd {
  display: flex;
  align-items: center;
  justify-content: center;
  min-height: 60vh;
  padding: 2rem;
}
.dd__card {
  background: var(--surface-card, #fff);
  border: 1px solid var(--border-light, var(--c-slate-200));
  border-radius: 16px;
  padding: 2.5rem 2rem;
  max-width: 440px;
  width: 100%;
  text-align: center;
  box-shadow: 0 4px 24px rgba(0,0,0,.06);
}
.dd__icon { font-size: 2.5rem; margin-bottom: 1rem; }
.dd__title {
  font-size: 1.35rem; font-weight: 700;
  color: var(--text-primary, var(--c-slate-900)); margin: 0 0 .75rem;
}
.dd__msg {
  font-size: .9rem; color: var(--text-secondary, var(--c-slate-500));
  line-height: 1.6; margin: 0 0 1.5rem;
}
.dd__info {
  background: var(--surface-muted, var(--c-slate-50));
  border-radius: 10px; padding: .75rem 1rem;
  text-align: left; display: flex; flex-direction: column; gap: .5rem;
}
.dd__info-row {
  display: flex; justify-content: space-between;
  font-size: .85rem; gap: .5rem;
}
.dd__info-label { color: var(--text-secondary, var(--c-slate-500)); font-weight: 600; }
.dd__info-val   { color: var(--text-primary, var(--c-slate-900)); word-break: break-all; }
</style>
