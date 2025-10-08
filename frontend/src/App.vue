<template>
  <div>
    <nav style="display:flex; gap:12px; padding:12px; border-bottom:1px solid #eee">
      <router-link to="/">Dashboard</router-link>
      <router-link to="/salas">Salas</router-link>
      <router-link to="/lotes">Lotes</router-link>
      <span style="margin-left:auto"><button @click="logout">Salir</button></span>
    </nav>
    <router-view />
  </div>
</template>

<script setup>
import { useAuthStore } from "./stores/auth"
const auth = useAuthStore()
const logout = async () => { try { await auth.logout() } finally { location.href = "/login" } }
</script>
