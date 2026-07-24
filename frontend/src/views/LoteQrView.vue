<script setup>
import { onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '../stores/auth'
import { useToast } from '../composables/useToast.js'
import { getLotePorQR } from '../lib/api.js'

const route  = useRoute()
const router = useRouter()
const auth   = useAuthStore()
const toast  = useToast()

const error = ref(null)

// Estados donde el cultivador todavía opera el lote
const ESTADOS_CULTIVADOR = ['germinacion', 'esqueje', 'vegetativo', 'floracion']
// Estados donde la manicura puede actuar
const ESTADOS_MANICURA   = ['en_manicura']

onMounted(async () => {
  try {
    const { data } = await getLotePorQR(route.params.codigo_qr)
    const { id, estado, codigo } = data
    const role = auth.role

    if (role === 'cultivador') {
      if (ESTADOS_CULTIVADOR.includes(estado)) {
        router.replace(`/lotes/${id}`)
      } else {
        error.value = {
          icon: '🌿',
          titulo: 'Lote ya cosechado',
          mensaje: `El lote ${codigo} salió de producción. Ya no está disponible para el cultivador.`,
        }
      }
      return
    }

    if (role === 'manicura') {
      if (ESTADOS_MANICURA.includes(estado)) {
        router.replace(`/lotes/${id}`)
      } else {
        error.value = {
          icon: '✂️',
          titulo: 'Lote no listo para manicura',
          mensaje: `El lote ${codigo} no está en etapa de manicura todavía (estado actual: ${estado}).`,
        }
      }
      return
    }

    // Admin, supervisor: acceso libre
    router.replace(`/lotes/${id}`)

  } catch (e) {
    if (e?.response?.status === 404) {
      error.value = {
        icon: '❓',
        titulo: 'QR no reconocido',
        mensaje: 'Este código QR no corresponde a ningún lote de tu club.',
      }
    } else {
      error.value = {
        icon: '⚠️',
        titulo: 'Error al leer el QR',
        mensaje: 'No se pudo resolver el código. Intentá de nuevo.',
      }
    }
  }
})
</script>

<template>
  <div class="qr-redirect">
    <!-- Resolviendo -->
    <template v-if="!error">
      <div class="qr-redirect__spinner">
        <div class="qr-redirect__ring"></div>
        <p class="qr-redirect__texto">Abriendo lote…</p>
      </div>
    </template>

    <!-- Error / estado inválido -->
    <template v-else>
      <div class="qr-redirect__card">
        <div class="qr-redirect__icon">{{ error.icon }}</div>
        <h2 class="qr-redirect__titulo">{{ error.titulo }}</h2>
        <p class="qr-redirect__mensaje">{{ error.mensaje }}</p>
        <button class="qr-redirect__btn" @click="router.replace('/')">
          <i class="bi bi-house"></i> Ir al inicio
        </button>
      </div>
    </template>
  </div>
</template>

<style scoped>
.qr-redirect {
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  background: #f0fdf4;
  padding: 2rem;
}

/* Spinner */
.qr-redirect__spinner { display: flex; flex-direction: column; align-items: center; gap: 1.25rem; }
.qr-redirect__ring {
  width: 48px; height: 48px;
  border: 4px solid #c8e6c9;
  border-top-color: #1b5e20;
  border-radius: 50%;
  animation: spin .8s linear infinite;
}
@keyframes spin { to { transform: rotate(360deg); } }
.qr-redirect__texto { font-size: .9rem; color: #60725d; font-weight: 600; }

/* Card de error */
.qr-redirect__card {
  background: #fff;
  border-radius: 20px;
  padding: 2.5rem 2rem;
  max-width: 360px;
  width: 100%;
  text-align: center;
  box-shadow: 0 8px 32px rgba(0,0,0,.08);
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 1rem;
}
.qr-redirect__icon   { font-size: 3rem; }
.qr-redirect__titulo { font-size: 1.15rem; font-weight: 800; color: #0f172a; margin: 0; }
.qr-redirect__mensaje { font-size: .875rem; color: #64748b; margin: 0; line-height: 1.5; }
.qr-redirect__btn {
  display: inline-flex; align-items: center; gap: .4rem;
  background: #1b5e20; color: #fff; border: none;
  padding: .65rem 1.4rem; border-radius: 10px;
  font-size: .875rem; font-weight: 700; cursor: pointer;
  margin-top: .5rem;
}
.qr-redirect__btn:hover { background: #144a18; }
</style>
