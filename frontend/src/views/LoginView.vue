<template>
  <div style="max-width:360px;margin:48px auto;padding:24px;border:1px solid #eee;border-radius:8px">
    <h2>Ingresar</h2>
    <form @submit.prevent="submit">
      <div>
        <label>Email</label>
        <input v-model="email" type="email" required />
      </div>
      <div>
        <label>Password</label>
        <input v-model="password" type="password" required />
      </div>
      <button :disabled="auth.loading" style="margin-top:12px">Entrar</button>
      <p v-if="auth.error" style="color:#b00">{{ auth.error }}</p>
    </form>
  </div>
</template>

<script setup>
import { ref } from "vue"
import { useAuthStore } from "../stores/auth"
import { useRouter } from "vue-router"
const email = ref("super@demo.com")
const password = ref("123456")
const auth = useAuthStore()
const router = useRouter()
const submit = async () => {
  try { await auth.login(email.value, password.value); router.push("/") }
  catch (e) {}
}
</script>
