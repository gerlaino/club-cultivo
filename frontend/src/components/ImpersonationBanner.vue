<template>
  <div v-if="auth.impersonating" class="imp-banner">
    <div class="imp-banner__inner">
      <div class="imp-banner__left">
        <i class="bi bi-incognito"></i>
        <span>Estás viendo el panel de <strong>{{ auth.impersonatedClub?.name }}</strong> como super admin</span>
      </div>
      <button class="imp-banner__exit" @click="auth.stopImpersonating()">
        <i class="bi bi-box-arrow-left"></i>
        Salir y volver al super admin
      </button>
    </div>
  </div>
</template>

<script setup>
import { useAuthStore } from '../stores/auth.js'
const auth = useAuthStore()
</script>

<style scoped>
.imp-banner {
  position: fixed;
  top: 0; left: 0; right: 0;
  z-index: 9999;
  background: #7c3aed;
  color: #fff;
}
.imp-banner__inner {
  max-width: 1400px;
  margin: 0 auto;
  padding: 8px 1.5rem;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1rem;
}
.imp-banner__left {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 13px;
}
.imp-banner__left i { font-size: 16px; opacity: .85; }
.imp-banner__exit {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  background: rgba(255,255,255,.15);
  border: 1px solid rgba(255,255,255,.3);
  color: #fff;
  padding: 5px 14px;
  border-radius: 7px;
  font-size: 12px;
  font-weight: 600;
  cursor: pointer;
  transition: background .15s;
  white-space: nowrap;
}
.imp-banner__exit:hover { background: rgba(255,255,255,.25); }
</style>
