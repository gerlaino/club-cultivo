<template>

  <!-- ── Estado: sin permisos (dentro del shell normal) ──────────────────── -->
  <div v-if="estado === 'sin_permisos'" class="sqr-forbidden">
    <div class="sqr-forbidden__ico">
      <i class="bi bi-shield-lock"></i>
    </div>
    <h1 class="sqr-forbidden__title">Sin permisos</h1>
    <p class="sqr-forbidden__desc">
      Esta sección es exclusiva para administradores y supervisores.
      Si creés que es un error, contactá al administrador de la organización.
    </p>
    <RouterLink to="/" class="sqr-forbidden__btn">
      <i class="bi bi-arrow-left"></i> Ir al inicio
    </RouterLink>
  </div>

  <!-- ── Estados fullscreen (loading / no encontrado / card profesional) ── -->
  <Teleport v-else to="body">
    <div class="sqr-overlay">

      <!-- Cargando -->
      <div v-if="estado === 'cargando'" class="sqr-loading">
        <div class="sqr-loading__leaf">🌿</div>
        <DsSpinner :size="32" color="#a7f3d0" />
      </div>

      <!-- No encontrado -->
      <div v-else-if="estado === 'no_encontrado'" class="sqr-card sqr-card--error">
        <div class="sqr-card__header">
          <div class="sqr-card__header-logo-box">🌿</div>
          <div>
            <div class="sqr-card__header-club">Cultivo Espacial</div>
            <div class="sqr-card__header-sub">Verificación de producto</div>
          </div>
        </div>
        <div class="sqr-card__body sqr-card__body--center">
          <div class="sqr-notfound__ico">⚠️</div>
          <div class="sqr-notfound__title">Producto no encontrado</div>
          <div class="sqr-notfound__desc">
            El código QR escaneado no corresponde a ningún producto registrado.
          </div>
          <div class="sqr-notfound__code">{{ codigoQr }}</div>
        </div>
        <div class="sqr-card__footer sqr-card__footer--warn">
          No verificado
        </div>
      </div>

      <!-- Card profesional -->
      <div v-else-if="stock" class="sqr-card">

        <!-- Header de la organización -->
        <div class="sqr-card__header">
          <div class="sqr-card__header-logo-box">
            <img v-if="stock.club?.logo" :src="stock.club.logo" :alt="stock.club.nombre" class="sqr-card__header-logo" />
            <span v-else class="sqr-card__header-logo-fallback">🌿</span>
          </div>
          <div class="sqr-card__header-text">
            <div class="sqr-card__header-club">{{ stock.club?.nombre }}</div>
            <div class="sqr-card__header-sub">Verificación de stock</div>
          </div>
          <div class="sqr-card__header-seal">
            <i class="bi bi-patch-check-fill"></i>
          </div>
        </div>

        <!-- Producto -->
        <div class="sqr-card__body">

          <div class="sqr-producto">
            <div class="sqr-producto__forma-ico" :class="`sqr-producto__forma-ico--${stock.forma_producto}`">
              {{ formaIco(stock.forma_producto) }}
            </div>
            <div class="sqr-producto__info">
              <div class="sqr-producto__tipo">{{ formaLabel(stock.forma_producto) }}</div>
              <div v-if="stock.lote?.genetica?.nombre" class="sqr-producto__genetica">
                {{ stock.lote.genetica.nombre }}
                <span v-if="stock.lote.genetica.numero_registro_inase" class="sqr-inase">
                  <i class="bi bi-bank"></i> INASE {{ stock.lote.genetica.numero_registro_inase }}
                </span>
              </div>
            </div>
          </div>

          <!-- Lote origen -->
          <div v-if="stock.lote" class="sqr-lote">
            <div class="sqr-lote__label">Lote de origen</div>
            <div class="sqr-lote__codigo">{{ stock.lote.codigo }}</div>
          </div>

          <!-- KPI disponible + desglose -->
          <div class="sqr-kpi">
            <div class="sqr-kpi__header">
              <span class="sqr-kpi__label">Disponible real</span>
              <span class="sqr-kpi__badge">
                <i class="bi bi-lock-fill"></i> Admin
              </span>
            </div>
            <div class="sqr-kpi__valor">
              {{ fmtG(stock.cantidad_disponible_real) }}<span class="sqr-kpi__unit">g</span>
            </div>
            <div class="sqr-kpi__desglose">
              <div class="sqr-kpi__row">
                <span class="sqr-kpi__row-lbl">Stock físico</span>
                <span class="sqr-kpi__row-val">{{ fmtG(stock.cantidad_total) }} g</span>
              </div>
              <div v-if="stock.en_delivery_g > 0" class="sqr-kpi__row sqr-kpi__row--amber">
                <span class="sqr-kpi__row-lbl">
                  <i class="bi bi-truck"></i> En delivery
                </span>
                <span class="sqr-kpi__row-val">− {{ fmtG(stock.en_delivery_g) }} g</span>
              </div>
              <div class="sqr-kpi__sep"></div>
              <div class="sqr-kpi__row sqr-kpi__row--result">
                <span class="sqr-kpi__row-lbl">Disponible real</span>
                <span class="sqr-kpi__row-val">{{ fmtG(stock.cantidad_disponible_real) }} g</span>
              </div>
            </div>
          </div>

          <!-- Datos adicionales -->
          <div class="sqr-meta">
            <div v-if="stock.sede?.nombre" class="sqr-meta__item">
              <i class="bi bi-geo-alt-fill sqr-meta__ico"></i>
              <div>
                <div class="sqr-meta__lbl">Sede</div>
                <div class="sqr-meta__val">{{ stock.sede.nombre }}</div>
              </div>
            </div>
            <div v-if="stock.fecha_elaboracion" class="sqr-meta__item">
              <i class="bi bi-calendar3 sqr-meta__ico"></i>
              <div>
                <div class="sqr-meta__lbl">Elaboración</div>
                <div class="sqr-meta__val">{{ formatDate(stock.fecha_elaboracion) }}</div>
              </div>
            </div>
            <div v-if="stock.fecha_vencimiento_est" class="sqr-meta__item">
              <i class="bi bi-clock sqr-meta__ico"></i>
              <div>
                <div class="sqr-meta__lbl">Vto. estimado</div>
                <div class="sqr-meta__val">{{ formatDate(stock.fecha_vencimiento_est) }}</div>
              </div>
            </div>
          </div>

          <!-- Código QR -->
          <div class="sqr-codbadge">
            <i class="bi bi-qr-code"></i>
            <span>{{ stock.codigo_qr }}</span>
          </div>

        </div>

        <!-- Footer verificado -->
        <div class="sqr-card__footer">
          <span class="sqr-card__footer-dot"></span>
          Registrado y verificado · {{ stock.club?.nombre }}
        </div>

      </div>

    </div>
  </Teleport>

</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useRoute, useRouter, RouterLink } from 'vue-router'
import DsSpinner from '../design-system/components/Spinner.vue'
import { useAuthStore } from '../stores/auth'
import { getStockByQR } from '../lib/api.js'

const route    = useRoute()
const router   = useRouter()
const auth     = useAuthStore()
const codigoQr = route.params.codigo_qr

const estado = ref('cargando')
const stock  = ref(null)

const FORMA_LABELS = {
  flor_seca: 'Flor seca', hash: 'Hash', aceite: 'Aceite',
  tintura: 'Tintura', crema: 'Crema', capsula: 'Cápsula',
  comestible: 'Comestible', prensado: 'Prensado', otro: 'Otro',
}
const FORMA_ICO = {
  flor_seca: '🌿', hash: '🪨', aceite: '💧', tintura: '🧪',
  crema: '🫙', capsula: '💊', comestible: '🍬', prensado: '🟫', otro: '📦',
}

function formaLabel(f) { return FORMA_LABELS[f] || f || '—' }
function formaIco(f)   { return FORMA_ICO[f] || '📦' }
function fmtG(v)       { return v != null ? Number(v).toFixed(1) : '—' }
function formatDate(d) {
  if (!d) return '—'
  return new Date(d + 'T00:00:00').toLocaleDateString('es-AR', { day: '2-digit', month: 'short', year: 'numeric' })
}

onMounted(async () => {
  const role = auth.user?.role
  const esAdminOSupervisor = ['admin', 'supervisor'].includes(role)

  if (!esAdminOSupervisor) {
    estado.value = 'sin_permisos'
    return
  }

  try {
    const { data } = await getStockByQR(codigoQr)
    stock.value  = data
    estado.value = 'ok'
  } catch (e) {
    estado.value = e?.response?.status === 404 ? 'no_encontrado' : 'no_encontrado'
  }
})
</script>

<style scoped>
* { box-sizing: border-box; }

/* ── Sin permisos (dentro del shell) ────────────────────────────────────── */
.sqr-forbidden {
  display: flex; flex-direction: column; align-items: center; justify-content: center;
  text-align: center; padding: 4rem 2rem; gap: 1rem; min-height: 40vh;
}
.sqr-forbidden__ico {
  width: 72px; height: 72px; border-radius: 20px;
  background: #fef2f2; color: #dc2626;
  display: flex; align-items: center; justify-content: center;
  font-size: 2rem;
}
.sqr-forbidden__title {
  font-size: 1.5rem; font-weight: 800; color: var(--c-slate-900);
  margin: 0; letter-spacing: -.03em;
}
.sqr-forbidden__desc {
  font-size: .9rem; color: var(--c-slate-500); line-height: 1.6;
  max-width: 360px; margin: 0;
}
.sqr-forbidden__btn {
  display: inline-flex; align-items: center; gap: .4rem;
  background: var(--c-slate-100); color: #374151; border: 1.5px solid var(--c-slate-200);
  padding: .6rem 1.25rem; border-radius: 8px;
  font-size: .85rem; font-weight: 600; text-decoration: none;
  transition: all .15s;
}
.sqr-forbidden__btn:hover { background: var(--c-slate-200); color: var(--c-slate-900); }

/* ── Overlay fullscreen ─────────────────────────────────────────────────── */
.sqr-overlay {
  position: fixed; inset: 0; z-index: 9999;
  background: linear-gradient(160deg, #0a1a0e 0%, #0f2417 40%, #1a3d2e 70%, #0f2417 100%);
  display: flex; align-items: center; justify-content: center;
  padding: 1.25rem;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, sans-serif;
}

/* Loading */
.sqr-loading {
  display: flex; flex-direction: column; align-items: center;
  gap: 1.5rem; color: #a7f3d0;
}
.sqr-loading__leaf { font-size: 3rem; animation: sqr-pulse 2s ease-in-out infinite; }
@keyframes sqr-pulse { 0%,100% { opacity: .6; transform: scale(.97); } 50% { opacity: 1; transform: scale(1); } }

/* ── Card ───────────────────────────────────────────────────────────────── */
.sqr-card {
  width: 100%; max-width: 440px;
  background: #fff; border-radius: 24px;
  overflow: hidden;
  box-shadow:
    0 32px 80px rgba(0,0,0,.55),
    0 4px 16px rgba(0,0,0,.25),
    inset 0 1px 0 rgba(255,255,255,.1);
}
.sqr-card--error .sqr-card__body { align-items: center; text-align: center; }

/* Header */
.sqr-card__header {
  background: linear-gradient(135deg, #0a1a0e 0%, #1b5e20 55%, #2e7d32 100%);
  padding: 1.4rem 1.5rem;
  display: flex; align-items: center; gap: 1rem;
  position: relative;
}
.sqr-card__header-logo-box {
  width: 52px; height: 52px; border-radius: 14px;
  background: rgba(255,255,255,.1); backdrop-filter: blur(8px);
  border: 1px solid rgba(255,255,255,.15);
  display: flex; align-items: center; justify-content: center;
  flex-shrink: 0; overflow: hidden;
}
.sqr-card__header-logo { width: 100%; height: 100%; object-fit: contain; }
.sqr-card__header-logo-fallback { font-size: 1.6rem; }
.sqr-card__header-text { flex: 1; }
.sqr-card__header-club {
  font-size: 1.05rem; font-weight: 800; color: #fff;
  letter-spacing: -.02em; line-height: 1.2;
}
.sqr-card__header-sub {
  font-size: .7rem; color: rgba(255,255,255,.55);
  text-transform: uppercase; letter-spacing: .08em; margin-top: .2rem;
}
.sqr-card__header-seal {
  font-size: 1.3rem; color: #86efac; opacity: .9; flex-shrink: 0;
}

/* Body */
.sqr-card__body {
  padding: 1.5rem; display: flex; flex-direction: column; gap: 1.25rem;
}

/* Producto */
.sqr-producto {
  display: flex; align-items: center; gap: 1rem;
  padding-bottom: 1.25rem; border-bottom: 1px solid var(--c-slate-100);
}
.sqr-producto__forma-ico {
  width: 60px; height: 60px; border-radius: 16px; font-size: 1.8rem;
  display: flex; align-items: center; justify-content: center; flex-shrink: 0;
  background: #f0fdf4;
}
.sqr-producto__forma-ico--aceite,
.sqr-producto__forma-ico--tintura  { background: #eff6ff; }
.sqr-producto__forma-ico--hash,
.sqr-producto__forma-ico--prensado { background: #fef3c7; }
.sqr-producto__forma-ico--crema,
.sqr-producto__forma-ico--capsula  { background: #fdf4ff; }
.sqr-producto__tipo {
  font-size: 1.5rem; font-weight: 900; color: var(--c-slate-900);
  letter-spacing: -.04em; line-height: 1.1;
}
.sqr-producto__genetica {
  font-size: .88rem; font-weight: 600; color: #1b5e20;
  margin-top: .3rem; display: flex; align-items: center; gap: .4rem; flex-wrap: wrap;
}
.sqr-inase {
  display: inline-flex; align-items: center; gap: .25rem;
  font-size: .68rem; background: #f0fdf4; border: 1px solid #bbf7d0;
  color: #15803d; padding: .15em .55em; border-radius: 5px; font-weight: 700;
}

/* Lote */
.sqr-lote {
  background: var(--c-slate-50); border: 1.5px solid var(--c-slate-200); border-radius: 12px;
  padding: .875rem 1.125rem;
}
.sqr-lote__label {
  font-size: .65rem; font-weight: 700; text-transform: uppercase;
  letter-spacing: .08em; color: var(--c-slate-400); margin-bottom: .3rem;
}
.sqr-lote__codigo {
  font-family: 'SF Mono', 'Fira Code', 'Courier New', monospace;
  font-size: 1.15rem; font-weight: 800; color: var(--c-slate-900); letter-spacing: .04em;
}

/* KPI */
.sqr-kpi {
  background: linear-gradient(135deg, #f0fdf4 0%, #dcfce7 100%);
  border: 1.5px solid #86efac; border-radius: 14px; padding: 1.125rem 1.25rem;
}
.sqr-kpi__header {
  display: flex; align-items: center; justify-content: space-between; margin-bottom: .5rem;
}
.sqr-kpi__label {
  font-size: .67rem; font-weight: 700; text-transform: uppercase;
  letter-spacing: .08em; color: #166534;
}
.sqr-kpi__badge {
  display: inline-flex; align-items: center; gap: .25rem;
  font-size: .65rem; font-weight: 700; background: #166534; color: #fff;
  padding: .18em .6em; border-radius: 5px;
}
.sqr-kpi__valor {
  font-size: 2.4rem; font-weight: 900; color: #14532d;
  letter-spacing: -.05em; line-height: 1; margin-bottom: .875rem;
}
.sqr-kpi__unit { font-size: 1.2rem; font-weight: 600; color: #15803d; margin-left: 2px; }

.sqr-kpi__desglose {
  display: flex; flex-direction: column; gap: .3rem;
  background: rgba(255,255,255,.55); border-radius: 8px; padding: .75rem .875rem;
}
.sqr-kpi__row {
  display: flex; align-items: center; justify-content: space-between;
  font-size: .8rem;
}
.sqr-kpi__row-lbl { display: flex; align-items: center; gap: .3rem; color: #374151; font-weight: 500; }
.sqr-kpi__row-val { font-weight: 600; color: #374151; }
.sqr-kpi__row--neg .sqr-kpi__row-lbl { color: #dc2626; }
.sqr-kpi__row--neg .sqr-kpi__row-val { color: #dc2626; }
.sqr-kpi__row--amber .sqr-kpi__row-lbl { color: #d97706; }
.sqr-kpi__row--amber .sqr-kpi__row-val { color: #d97706; }
.sqr-kpi__row--result .sqr-kpi__row-lbl { color: #14532d; font-weight: 700; font-size: .82rem; }
.sqr-kpi__row--result .sqr-kpi__row-val { color: #14532d; font-weight: 800; font-size: .82rem; }
.sqr-kpi__sep {
  height: 1px; background: rgba(0,0,0,.08); margin: .2rem 0;
}

/* Meta */
.sqr-meta {
  display: grid; grid-template-columns: 1fr 1fr; gap: .6rem;
}
@media (max-width: 400px) { .sqr-meta { grid-template-columns: 1fr; } }
.sqr-meta__item {
  display: flex; align-items: center; gap: .6rem;
  background: var(--c-slate-50); border: 1px solid var(--c-slate-100); border-radius: 10px;
  padding: .7rem .875rem;
}
.sqr-meta__ico  { font-size: .9rem; color: var(--c-slate-400); flex-shrink: 0; }
.sqr-meta__lbl  { font-size: .62rem; color: var(--c-slate-400); text-transform: uppercase; letter-spacing: .05em; font-weight: 700; }
.sqr-meta__val  { font-size: .82rem; font-weight: 600; color: var(--c-slate-900); margin-top: .1rem; }

/* Código */
.sqr-codbadge {
  display: flex; align-items: center; gap: .5rem;
  font-family: 'SF Mono', 'Fira Code', monospace;
  font-size: .68rem; color: var(--c-slate-400);
  background: var(--c-slate-50); border: 1px solid var(--c-slate-100);
  border-radius: 7px; padding: .45rem .75rem;
  word-break: break-all;
}
.sqr-codbadge i { flex-shrink: 0; }

/* Footer */
.sqr-card__footer {
  background: var(--c-slate-50); border-top: 1px solid var(--c-slate-100);
  padding: .75rem 1.5rem;
  display: flex; align-items: center; gap: .5rem;
  font-size: .73rem; color: var(--c-slate-500); font-weight: 500;
}
.sqr-card__footer-dot {
  width: 8px; height: 8px; border-radius: 50%; background: #22c55e;
  flex-shrink: 0; box-shadow: 0 0 0 3px rgba(34,197,94,.2);
}
.sqr-card__footer--warn { color: #b45309; }
.sqr-card__footer--warn::before {
  content: ''; width: 8px; height: 8px; border-radius: 50%;
  background: #f59e0b; flex-shrink: 0; display: inline-block; margin-right: .15rem;
}

/* Error / no encontrado */
.sqr-notfound__ico   { font-size: 3rem; margin-bottom: .5rem; }
.sqr-notfound__title { font-size: 1.1rem; font-weight: 800; color: var(--c-slate-900); margin-bottom: .4rem; }
.sqr-notfound__desc  { font-size: .82rem; color: var(--c-slate-500); line-height: 1.5; margin-bottom: .75rem; max-width: 280px; }
.sqr-notfound__code  {
  font-family: monospace; font-size: .72rem; color: var(--c-slate-400);
  background: var(--c-slate-100); border: 1px solid var(--c-slate-200);
  padding: .35rem .75rem; border-radius: 6px;
}
</style>
