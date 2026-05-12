<template>
  <div class="cp">
    <div v-if="estado === 'cargando'" class="cp__loading">
      <div class="cp__spinner"></div>
      <p>Verificando carnet…</p>
    </div>

    <div v-else-if="estado === 'no_encontrado'" class="cp__error">
      <span class="cp__error-ico">✕</span>
      <h2>Carnet no válido</h2>
      <p>El carnet no se encontró o fue revocado.</p>
    </div>

    <div v-else-if="data" class="cp__card">
      <!-- Club header -->
      <div class="cp__club-header">
        <img v-if="data.club?.logo" :src="data.club.logo" :alt="data.club.nombre" class="cp__club-logo" />
        <div class="cp__club-name">{{ data.club?.nombre }}</div>
        <div class="cp__card-title">Carnet de Socio</div>
      </div>

      <!-- Estado membresía -->
      <div class="cp__status" :class="`cp__status--${data.estado_membresia}`">
        <span class="cp__status-dot"></span>
        <span class="cp__status-label">{{ estadoLabel }}</span>
      </div>

      <!-- Datos del socio -->
      <div class="cp__body">
        <div class="cp__field">
          <span class="cp__field-label">Nombre</span>
          <span class="cp__field-val">{{ data.nombre }} {{ data.apellido_inicial }}</span>
        </div>
        <div class="cp__field">
          <span class="cp__field-label">N.° socio</span>
          <span class="cp__field-val">{{ String(data.numero_socio).padStart(6, '0') }}</span>
        </div>
        <div class="cp__field">
          <span class="cp__field-label">REPROCANN</span>
          <span class="cp__field-val cp__reprocann" :class="`cp__reprocann--${data.reprocann_estado}`">
            {{ reprocannLabel }}
          </span>
        </div>
        <div v-if="data.reprocann_vencimiento" class="cp__field">
          <span class="cp__field-label">Vto. REPROCANN</span>
          <span class="cp__field-val">{{ formatDate(data.reprocann_vencimiento) }}</span>
        </div>
      </div>

      <div class="cp__footer">
        <span>Emitido el {{ formatDate(data.emitido_at) }}</span>
        <span class="cp__verified">✓ Verificado</span>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import axios from 'axios'

const route = useRoute()
const estado = ref('cargando')
const data   = ref(null)

const BASE_URL = import.meta.env.VITE_API_URL?.replace('/api', '') || 'http://localhost:3001'

async function cargar() {
  try {
    const res = await axios.get(`${BASE_URL}/c/${route.params.token}`)
    data.value  = res.data
    estado.value = 'ok'
  } catch {
    estado.value = 'no_encontrado'
  }
}

const estadoLabel = computed(() => data.value?.estado_membresia === 'activo' ? 'Activo' : 'Baja')

const reprocannLabel = computed(() => ({
  vigente:       'Vigente',
  por_vencer:    'Por vencer',
  vencido:       'Vencido',
  sin_registro:  'Sin registro',
}[data.value?.reprocann_estado] ?? '—'))

const formatDate = (d) => d ? new Date(d).toLocaleDateString('es-AR', { day: '2-digit', month: '2-digit', year: 'numeric' }) : '—'

onMounted(cargar)
</script>

<style scoped>
.cp {
  min-height: 100dvh;
  display: flex;
  align-items: center;
  justify-content: center;
  background: #f0f4f0;
  padding: 1.5rem;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
}

/* Loading */
.cp__loading { text-align: center; color: #5b6473; }
.cp__spinner { width: 36px; height: 36px; border: 3px solid #d4e6d4; border-top-color: #1b5e20; border-radius: 50%; animation: spin .7s linear infinite; margin: 0 auto 1rem; }
@keyframes spin { to { transform: rotate(360deg); } }

/* Error */
.cp__error { text-align: center; background: #fff; border-radius: 20px; padding: 2.5rem 2rem; max-width: 340px; width: 100%; box-shadow: 0 8px 32px rgba(0,0,0,.08); }
.cp__error-ico { display: block; font-size: 3rem; margin-bottom: .75rem; color: #dc2626; }
.cp__error h2 { font-size: 1.2rem; font-weight: 700; color: #1a1a1a; margin: 0 0 .5rem; }
.cp__error p { font-size: .9rem; color: #5b6473; margin: 0; }

/* Card */
.cp__card {
  background: #fff;
  border-radius: 20px;
  width: 100%;
  max-width: 360px;
  box-shadow: 0 8px 32px rgba(27,94,32,.12), 0 2px 8px rgba(0,0,0,.06);
  overflow: hidden;
}

.cp__club-header {
  background: linear-gradient(135deg, #1b5e20 0%, #2e7d32 100%);
  padding: 1.5rem 1.5rem 1rem;
  text-align: center;
  color: #fff;
}
.cp__club-logo { height: 48px; width: auto; margin-bottom: .5rem; object-fit: contain; }
.cp__club-name { font-size: .85rem; font-weight: 600; opacity: .85; margin-bottom: .2rem; }
.cp__card-title { font-size: 1.15rem; font-weight: 800; letter-spacing: .03em; }

.cp__status {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: .5rem;
  padding: .6rem 1rem;
  font-size: .82rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: .07em;
}
.cp__status--activo { background: #e8f5e9; color: #1b5e20; }
.cp__status--baja   { background: #fff5f5; color: #dc2626; }
.cp__status-dot { width: 8px; height: 8px; border-radius: 50%; background: currentColor; }

.cp__body { padding: 1.25rem 1.5rem; display: flex; flex-direction: column; gap: .75rem; }
.cp__field { display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid #f0f0f0; padding-bottom: .6rem; }
.cp__field:last-child { border-bottom: none; }
.cp__field-label { font-size: .78rem; font-weight: 600; color: #8a9a8a; text-transform: uppercase; letter-spacing: .05em; }
.cp__field-val { font-size: .9rem; font-weight: 700; color: #1a1a1a; }
.cp__reprocann { padding: 2px 10px; border-radius: 999px; font-size: .8rem; }
.cp__reprocann--vigente    { background: #e8f5e9; color: #1b5e20; }
.cp__reprocann--por_vencer { background: #fffbeb; color: #b45309; }
.cp__reprocann--vencido    { background: #fff5f5; color: #dc2626; }
.cp__reprocann--sin_registro { background: #f1f5f9; color: #5b6473; }

.cp__footer {
  padding: .75rem 1.5rem;
  background: #f8faf8;
  border-top: 1px solid #e8f0e9;
  display: flex;
  justify-content: space-between;
  font-size: .75rem;
  color: #8a9a8a;
}
.cp__verified { color: #1b5e20; font-weight: 700; }
</style>
