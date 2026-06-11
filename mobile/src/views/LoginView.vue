<template>
  <div class="login">
    <div class="login__brand">
      <div class="login__logo">🌿</div>
      <h1 class="login__name">Cultivo Espacial</h1>
      <p class="login__sub">Plataforma de gestión de cultivo</p>
    </div>

    <form class="login__form" @submit.prevent="handleLogin">
      <div class="field">
        <label>Email</label>
        <input
          v-model.trim="email"
          type="email"
          placeholder="tu@email.com"
          autocomplete="email"
          inputmode="email"
          :disabled="loading"
        />
      </div>
      <div class="field">
        <label>Contraseña</label>
        <input
          v-model="password"
          type="password"
          placeholder="••••••••"
          autocomplete="current-password"
          :disabled="loading"
        />
      </div>

      <div v-if="error" class="login__error">{{ error }}</div>

      <button type="submit" class="btn btn-primary btn-full" :disabled="loading || !email || !password">
        <span v-if="loading" class="spinner" />
        <span v-else>Ingresar</span>
      </button>
    </form>
  </div>
</template>

<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { login, getMe } from '@/lib/api'

const router   = useRouter()
const auth     = useAuthStore()
const email    = ref('')
const password = ref('')
const loading  = ref(false)
const error    = ref('')

async function handleLogin() {
  loading.value = true
  error.value   = ''
  try {
    await login(email.value, password.value)
    const { data } = await getMe()
    auth.setUser(data)
    router.replace('/cultivador/tareas')
  } catch (e) {
    error.value = e?.response?.status === 401
      ? 'Email o contraseña incorrectos'
      : 'Error al conectar con el servidor'
  } finally {
    loading.value = false
  }
}
</script>

<style scoped>
.login {
  min-height: 100vh;
  min-height: 100dvh;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 2rem 1.5rem;
  padding-top: calc(env(safe-area-inset-top) + 2rem);
  background: var(--bg);
}
.login__brand { text-align: center; margin-bottom: 2.5rem; }
.login__logo  { font-size: 3rem; margin-bottom: .5rem; }
.login__name  { font-size: 1.75rem; font-weight: 800; color: var(--green); letter-spacing: -.03em; }
.login__sub   { font-size: .85rem; color: var(--text-2); margin-top: .25rem; }
.login__form  { width: 100%; max-width: 360px; }
.login__error {
  background: var(--red-bg);
  border: 1px solid #fecaca;
  color: var(--red);
  padding: .65rem .9rem;
  border-radius: 10px;
  font-size: .85rem;
  margin-bottom: .875rem;
}
</style>
