import { defineStore } from 'pinia'
import { ref, computed } from 'vue'

const JWT_KEY = 'cc_jwt'

export const useAuthStore = defineStore('auth', () => {
  const jwt  = ref(localStorage.getItem(JWT_KEY) || null)
  const user = ref(null)

  const isLoggedIn = computed(() => !!jwt.value)

  function setJwt(token) {
    jwt.value = token
    if (token) localStorage.setItem(JWT_KEY, token)
    else localStorage.removeItem(JWT_KEY)
  }

  function setUser(u) { user.value = u }

  function logout() {
    setJwt(null)
    user.value = null
  }

  return { jwt, user, isLoggedIn, setJwt, setUser, logout }
})
