<template>
  <div class="sqr">

    <!-- Cargando -->
    <div v-if="estado === 'cargando'" class="sqr__full-center">
      <div class="sqr__loading-logo">🌿</div>
      <DsSpinner :size="32" />
    </div>

    <!-- No encontrado -->
    <div v-else-if="estado === 'no_encontrado'" class="sqr__card">
      <div class="sqr__header">
        <div class="sqr__header-logo-wrap">🌿</div>
        <div class="sqr__header-text">
          <div class="sqr__header-club">Cultivo Espacial</div>
          <div class="sqr__header-sub">Verificación de producto</div>
        </div>
      </div>
      <div class="sqr__body sqr__body--center">
        <div class="sqr__error-ico">⚠️</div>
        <div class="sqr__error-title">Producto no encontrado</div>
        <div class="sqr__error-desc">El código QR escaneado no corresponde a ningún producto registrado en el sistema.</div>
        <div class="sqr__code-badge">{{ codigoQr }}</div>
      </div>
      <div class="sqr__footer">No verificado</div>
    </div>

    <!-- Producto encontrado -->
    <div v-else-if="stock" class="sqr__card">

      <!-- Header del club -->
      <div class="sqr__header">
        <div class="sqr__header-logo-wrap">
          <img v-if="stock.club?.logo_url" :src="stock.club.logo_url" :alt="stock.club?.nombre" class="sqr__header-logo" />
          <span v-else class="sqr__header-logo-fallback">🌿</span>
        </div>
        <div class="sqr__header-text">
          <div class="sqr__header-club">{{ stock.club?.nombre }}</div>
          <div class="sqr__header-sub">Certificado de producto</div>
        </div>
      </div>

      <!-- Cuerpo -->
      <div class="sqr__body">

        <!-- Producto principal -->
        <div class="sqr__producto-wrap">
          <div class="sqr__producto-tipo">{{ formaLabel(stock.forma_producto) }}</div>
          <div v-if="stock.lote?.genetica?.nombre || stock.genetica?.nombre" class="sqr__producto-genetica">
            {{ stock.lote?.genetica?.nombre || stock.genetica?.nombre }}
            <span v-if="stock.lote?.genetica?.numero_registro_inase" class="sqr__inase-badge">
              🏛️ INASE {{ stock.lote.genetica.numero_registro_inase }}
            </span>
          </div>
        </div>

        <!-- Número de lote -->
        <div class="sqr__lote-wrap">
          <div class="sqr__lote-label">N.° de lote</div>
          <div class="sqr__lote-num">{{ stock.numero_lote_producto || stock.codigo_qr }}</div>
        </div>

        <!-- Grid de datos -->
        <div class="sqr__data-grid">
          <div class="sqr__data-item">
            <span class="sqr__data-icon">⚖️</span>
            <div>
              <div class="sqr__data-val">{{ stock.cantidad }}{{ stock.unidad }}</div>
              <div class="sqr__data-label">Cantidad</div>
            </div>
          </div>
          <div v-if="stock.fecha_elaboracion" class="sqr__data-item">
            <span class="sqr__data-icon">📅</span>
            <div>
              <div class="sqr__data-val">{{ formatDate(stock.fecha_elaboracion) }}</div>
              <div class="sqr__data-label">Elaboración</div>
            </div>
          </div>
          <div v-if="stock.fecha_vencimiento_est" class="sqr__data-item">
            <span class="sqr__data-icon">⏳</span>
            <div>
              <div class="sqr__data-val">{{ formatDate(stock.fecha_vencimiento_est) }}</div>
              <div class="sqr__data-label">Vto. estimado</div>
            </div>
          </div>
          <div v-if="stock.sede?.nombre" class="sqr__data-item">
            <span class="sqr__data-icon">📍</span>
            <div>
              <div class="sqr__data-val">{{ stock.sede.nombre }}</div>
              <div class="sqr__data-label">Sede</div>
            </div>
          </div>
        </div>

      </div>

      <!-- Footer verificado -->
      <div class="sqr__footer">
        <span class="sqr__footer-dot"></span>
        Registrado y verificado · {{ stock.club?.nombre }}
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
const estado   = ref('cargando')
const stock    = ref(null)

const FORMA_LABELS = {
  flor_seca: 'Flor seca', hash: 'Hash', aceite: 'Aceite',
  tintura: 'Tintura', crema: 'Crema', capsula: 'Cápsula',
  comestible: 'Comestible', prensado: 'Prensado', otro: 'Otro',
}
function formaLabel(f) { return FORMA_LABELS[f] || f || '—' }
function formatDate(d) {
  if (!d) return '—'
  return new Date(d + 'T00:00:00').toLocaleDateString('es-AR', { day: '2-digit', month: 'short', year: 'numeric' })
}

onMounted(async () => {
  try {
    const base = (import.meta.env.VITE_API_URL || 'http://localhost:3001/api').replace(/\/api\/?$/, '')
    const { data } = await axios.get(`${base}/s/${codigoQr}`)
    stock.value  = data
    estado.value = 'ok'
  } catch {
    estado.value = 'no_encontrado'
  }
})
</script>

<style scoped>
* { box-sizing: border-box; }

.sqr {
  min-height: 100dvh;
  display: flex; align-items: center; justify-content: center;
  background: linear-gradient(160deg, #0f2417 0%, #1a3d2e 50%, #0f2417 100%);
  padding: 1.25rem;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, sans-serif;
}

.sqr__full-center {
  display: flex; flex-direction: column; align-items: center;
  justify-content: center; gap: 1.5rem; color: #a7f3d0;
}
.sqr__loading-logo { font-size: 3rem; animation: sqr-pulse 2s ease-in-out infinite; }
@keyframes sqr-pulse { 0%,100% { opacity: .7; } 50% { opacity: 1; } }

/* Card */
.sqr__card {
  width: 100%; max-width: 400px;
  background: #fff; border-radius: 20px;
  overflow: hidden;
  box-shadow: 0 24px 64px rgba(0,0,0,.4), 0 4px 16px rgba(0,0,0,.2);
}

/* Header */
.sqr__header {
  background: linear-gradient(135deg, #0f2417 0%, #1b5e20 60%, #2e7d32 100%);
  padding: 1.25rem 1.5rem;
  display: flex; align-items: center; gap: 1rem;
}
.sqr__header-logo-wrap {
  width: 48px; height: 48px; border-radius: 12px;
  background: rgba(255,255,255,.12); backdrop-filter: blur(4px);
  display: flex; align-items: center; justify-content: center;
  flex-shrink: 0; overflow: hidden;
}
.sqr__header-logo { width: 100%; height: 100%; object-fit: contain; }
.sqr__header-logo-fallback { font-size: 1.5rem; }
.sqr__header-club { font-size: 1rem; font-weight: 800; color: #fff; letter-spacing: -.01em; }
.sqr__header-sub  { font-size: .72rem; color: rgba(255,255,255,.65); margin-top: .15rem; text-transform: uppercase; letter-spacing: .05em; }

/* Body */
.sqr__body { padding: 1.5rem; display: flex; flex-direction: column; gap: 1.25rem; }
.sqr__body--center { align-items: center; text-align: center; }

/* Producto */
.sqr__producto-wrap { text-align: center; }
.sqr__producto-tipo {
  font-size: 1.6rem; font-weight: 900; color: #0f172a;
  letter-spacing: -.03em; line-height: 1.1;
}
.sqr__producto-genetica {
  font-size: .9rem; color: #1b5e20; font-weight: 600;
  margin-top: .35rem; display: flex; align-items: center; justify-content: center; gap: .5rem; flex-wrap: wrap;
}
.sqr__inase-badge {
  font-size: .72rem; background: #f0fdf4; border: 1px solid #bbf7d0;
  color: #15803d; padding: .15em .55em; border-radius: 5px;
}

/* Lote */
.sqr__lote-wrap {
  background: #f8fafc; border: 1.5px solid #e2e8f0; border-radius: 12px;
  padding: 1rem 1.25rem; text-align: center;
}
.sqr__lote-label { font-size: .68rem; font-weight: 700; text-transform: uppercase; letter-spacing: .08em; color: #94a3b8; margin-bottom: .3rem; }
.sqr__lote-num   { font-family: 'Courier New', monospace; font-size: 1.3rem; font-weight: 900; color: #0f172a; letter-spacing: .04em; }

/* Data grid */
.sqr__data-grid {
  display: grid; grid-template-columns: 1fr 1fr; gap: .6rem;
}
.sqr__data-item {
  display: flex; align-items: center; gap: .65rem;
  background: #f8fafc; border-radius: 10px; padding: .75rem .875rem;
}
.sqr__data-icon { font-size: 1.1rem; flex-shrink: 0; }
.sqr__data-val   { font-size: .9rem; font-weight: 700; color: #0f172a; }
.sqr__data-label { font-size: .66rem; color: #94a3b8; margin-top: .1rem; text-transform: uppercase; letter-spacing: .04em; }

/* Error */
.sqr__error-ico   { font-size: 3rem; margin-bottom: .5rem; }
.sqr__error-title { font-size: 1.1rem; font-weight: 800; color: #0f172a; margin-bottom: .4rem; }
.sqr__error-desc  { font-size: .82rem; color: #64748b; line-height: 1.5; margin-bottom: .75rem; }
.sqr__code-badge  { font-family: monospace; font-size: .72rem; color: #94a3b8; background: #f1f5f9; border: 1px solid #e2e8f0; padding: .35rem .75rem; border-radius: 6px; }

/* Footer */
.sqr__footer {
  background: #f8fafc; border-top: 1px solid #f1f5f9;
  padding: .75rem 1.5rem;
  display: flex; align-items: center; gap: .5rem;
  font-size: .73rem; color: #64748b; font-weight: 500;
}
.sqr__footer-dot { width: 7px; height: 7px; border-radius: 50%; background: #22c55e; flex-shrink: 0; }
</style>
