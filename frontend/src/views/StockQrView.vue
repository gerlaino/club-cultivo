<template>
  <div class="sqr">

    <div v-if="estado === 'cargando'" class="sqr__loading">
      <DsSpinner :size="60" />
    </div>

    <div v-else-if="estado === 'no_encontrado'" class="sqr__screen">
      <div class="sqr__icon">📦</div>
      <h2 class="sqr__title">Producto no encontrado</h2>
      <p class="sqr__desc">El código QR escaneado no corresponde a ningún producto registrado.</p>
      <div class="sqr__code-badge">{{ codigoQr }}</div>
    </div>

    <div v-else-if="stock" class="sqr__screen">
      <!-- Club header -->
      <div class="sqr__club-header">
        <img v-if="stock.club?.logo" :src="stock.club.logo" :alt="stock.club.nombre" class="sqr__club-logo" />
        <span class="sqr__club-nombre">{{ stock.club?.nombre }}</span>
      </div>

      <!-- Main card -->
      <div class="sqr__card">
        <div class="sqr__card-icon">🌿</div>
        <div class="sqr__card-content">
          <div class="sqr__lote-numero">{{ stock.numero_lote_producto || stock.codigo_qr }}</div>
          <div class="sqr__genetica" v-if="stock.lote?.genetica">
            {{ stock.lote.genetica.nombre }}
          </div>
        </div>
      </div>

      <!-- Info grid -->
      <div class="sqr__info">
        <div class="sqr__info-item">
          <span class="sqr__info-label">Forma</span>
          <span class="sqr__info-val">{{ formaLabel(stock.forma_producto) }}</span>
        </div>
        <div class="sqr__info-item">
          <span class="sqr__info-label">Cantidad</span>
          <span class="sqr__info-val">{{ stock.cantidad }}{{ stock.unidad }}</span>
        </div>
        <div class="sqr__info-item" v-if="stock.fecha_elaboracion">
          <span class="sqr__info-label">Elaboración</span>
          <span class="sqr__info-val">{{ formatDate(stock.fecha_elaboracion) }}</span>
        </div>
        <div class="sqr__info-item" v-if="stock.fecha_vencimiento">
          <span class="sqr__info-label">Vto. estimado</span>
          <span class="sqr__info-val">{{ formatDate(stock.fecha_vencimiento) }}</span>
        </div>
        <div class="sqr__info-item" v-if="stock.lote?.genetica?.numero_registro_inase">
          <span class="sqr__info-label">INASE</span>
          <span class="sqr__info-val">{{ stock.lote.genetica.numero_registro_inase }}</span>
        </div>
        <div class="sqr__info-item" v-if="stock.sede">
          <span class="sqr__info-label">Sede</span>
          <span class="sqr__info-val">{{ stock.sede.nombre }}</span>
        </div>
      </div>

      <div class="sqr__verified">
        <span class="sqr__verified-dot"></span>
        Producto registrado · Club Cultivo
      </div>
    </div>

  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import axios from 'axios'
import DsSpinner from '../design-system/components/Spinner.vue'

const route    = useRoute()
const codigoQr = route.params.codigo_qr

const estado = ref('cargando')
const stock  = ref(null)

const FORMA_LABELS = {
  flor_seca:    'Flor seca',
  concentrado:  'Concentrado',
  tintura:      'Tintura',
  aceite:       'Aceite',
  comestible:   'Comestible',
  topico:       'Tópico',
}
function formaLabel(f) { return FORMA_LABELS[f] || f || '—' }

function formatDate(d) {
  if (!d) return '—'
  const [y, m, day] = d.split('-')
  return `${day}/${m}/${y}`
}

onMounted(async () => {
  try {
    const baseUrl = import.meta.env.VITE_API_URL?.replace('/api', '') || 'http://localhost:3001'
    const { data } = await axios.get(`${baseUrl}/s/${codigoQr}`)
    stock.value  = data
    estado.value = 'ok'
  } catch {
    estado.value = 'no_encontrado'
  }
})
</script>

<style scoped>
.sqr {
  min-height: 100vh;
  display: flex; align-items: center; justify-content: center;
  background: linear-gradient(160deg, #f0fdf4 0%, #e8f5e9 50%, #f0fdf4 100%);
  padding: 1.5rem;
  font-family: system-ui, -apple-system, sans-serif;
}
.sqr__loading { display: flex; align-items: center; justify-content: center; min-height: 100vh; }

.sqr__screen {
  background: white; border-radius: 20px; padding: 2rem 1.75rem;
  max-width: 380px; width: 100%; box-shadow: 0 20px 60px rgba(27,94,32,.12);
  display: flex; flex-direction: column; align-items: center; gap: 1.2rem;
}
.sqr__icon { font-size: 3rem; }
.sqr__title { font-size: 1.25rem; font-weight: 800; color: #1a1a1a; margin: 0; }
.sqr__desc { font-size: .875rem; color: #6b7280; text-align: center; margin: 0; }
.sqr__code-badge { font-family: monospace; font-size: .75rem; color: #94a3b8; background: #f8fafc; border: 1px solid #e2e8f0; padding: .4rem .8rem; border-radius: 6px; }

.sqr__club-header { display: flex; align-items: center; gap: .6rem; padding: .4rem .9rem; background: #f0fdf4; border-radius: 999px; }
.sqr__club-logo { width: 24px; height: 24px; border-radius: 50%; object-fit: cover; }
.sqr__club-nombre { font-size: .82rem; font-weight: 600; color: #1b5e20; }

.sqr__card { display: flex; align-items: center; gap: 1rem; background: linear-gradient(135deg, #f0fdf4, #dcfce7); border: 1px solid #bbf7d0; border-radius: 14px; padding: 1rem 1.25rem; width: 100%; }
.sqr__card-icon { font-size: 2rem; flex-shrink: 0; }
.sqr__lote-numero { font-family: monospace; font-size: .95rem; font-weight: 800; color: #1b5e20; }
.sqr__genetica { font-size: .8rem; color: #4a7c59; margin-top: .15rem; font-weight: 600; }

.sqr__info { width: 100%; display: grid; grid-template-columns: 1fr 1fr; gap: .6rem; }
.sqr__info-item { display: flex; flex-direction: column; gap: .15rem; padding: .6rem .75rem; background: #f8fafc; border-radius: 8px; }
.sqr__info-label { font-size: .68rem; font-weight: 700; color: #94a3b8; text-transform: uppercase; letter-spacing: .05em; }
.sqr__info-val { font-size: .875rem; font-weight: 600; color: #334155; }

.sqr__verified { display: flex; align-items: center; gap: .5rem; font-size: .73rem; color: #64748b; }
.sqr__verified-dot { width: 7px; height: 7px; border-radius: 50%; background: #22c55e; flex-shrink: 0; }
</style>
