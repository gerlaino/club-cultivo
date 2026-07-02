<template>
  <div class="dqr">
    <div class="dqr__card">

      <!-- Header club -->
      <header class="dqr__head">
        <img v-if="club?.logo" :src="club.logo" class="dqr__logo" alt="" />
        <div v-else class="dqr__logo dqr__logo--ph"><i class="bi bi-flower1"></i></div>
        <div class="dqr__head-txt">
          <span class="dqr__club">{{ club?.nombre || 'Club Cultivo' }}</span>
          <span class="dqr__head-sub">Pasaporte de producto</span>
        </div>
      </header>

      <!-- Cargando preview -->
      <div v-if="estado === 'cargando'" class="dqr__center">
        <i class="bi bi-arrow-repeat dqr__spin"></i>
      </div>

      <!-- No encontrado -->
      <div v-else-if="estado === 'no_encontrada'" class="dqr__center">
        <i class="bi bi-x-circle dqr__big-ico"></i>
        <p class="dqr__msg">Este código no corresponde a ninguna dispensa.</p>
      </div>

      <!-- Gate DNI -->
      <form v-else-if="estado === 'gate'" class="dqr__gate" @submit.prevent="verificar">
        <i class="bi bi-shield-lock dqr__gate-ico"></i>
        <p class="dqr__gate-txt">Ingresá tu DNI para ver los datos de tu producto.</p>
        <input
          v-model.trim="dni" inputmode="numeric" autocomplete="off"
          class="dqr__input" placeholder="DNI (sin puntos)"
          :class="{ 'dqr__input--err': gateError }"
        />
        <p v-if="gateError" class="dqr__gate-err">{{ gateError }}</p>
        <button class="dqr__btn" type="submit" :disabled="verificando || !dni">
          <i v-if="verificando" class="bi bi-arrow-repeat dqr__spin-sm"></i>
          <span v-else>Ver mi producto</span>
        </button>
      </form>

      <!-- Pasaporte -->
      <div v-else-if="estado === 'ok'" class="dqr__pass">

        <!-- Multi-stock: una tarjeta por producto del paquete -->
        <template v-if="data.multi && data.items?.length">
          <div class="dqr__multi-head">Tu paquete · {{ data.items.length }} productos</div>
          <div v-for="(it, i) in data.items" :key="i" class="dqr__prod-card">
            <div class="dqr__prod-head">
              <span class="dqr__hero-tipo" v-if="it.genetica?.tipo">{{ it.genetica.tipo }}</span>
              <h2 class="dqr__prod-nombre">{{ it.genetica?.nombre || formaLabel(it.forma) }}</h2>
              <p class="dqr__prod-forma">{{ formaLabel(it.forma) }} · {{ it.cantidad }}{{ it.unidad }}</p>
            </div>
            <div v-if="it.genetica?.thc_pct != null || it.genetica?.cbd_pct != null" class="dqr__cannab dqr__cannab--sm">
              <div class="dqr__cannab-item">
                <span class="dqr__cannab-val">{{ fmtPct(it.genetica?.thc_pct) }}</span>
                <span class="dqr__cannab-lbl">THC</span>
              </div>
              <div class="dqr__cannab-item">
                <span class="dqr__cannab-val">{{ fmtPct(it.genetica?.cbd_pct) }}</span>
                <span class="dqr__cannab-lbl">CBD</span>
              </div>
            </div>
            <div v-if="it.genetica?.terpenos" class="dqr__terp">
              <span class="dqr__terp-lbl">Terpenos</span>
              <span class="dqr__terp-val">{{ it.genetica.terpenos }}</span>
            </div>
            <div v-if="it.lote" class="dqr__prod-lote"><span>Lote</span> <span class="dqr__mono">{{ it.lote }}</span></div>
          </div>
          <div v-if="data.genetica?.consejos_club" class="dqr__consejos">
            <span class="dqr__consejos-lbl">💡 Consejos del club</span>
            <p class="dqr__consejos-txt">{{ data.genetica.consejos_club }}</p>
          </div>
          <dl class="dqr__rows">
            <div class="dqr__row"><dt>Fecha de dispensa</dt><dd>{{ fmtFecha(data.fecha) }}</dd></div>
            <div class="dqr__row" v-if="data.socio_numero"><dt>Socio</dt><dd>#{{ data.socio_numero }}</dd></div>
          </dl>
        </template>

        <!-- Single-stock -->
        <template v-else>
          <div class="dqr__hero">
            <span class="dqr__hero-tipo" v-if="data.genetica?.tipo">{{ data.genetica.tipo }}</span>
            <h1 class="dqr__hero-nombre">{{ data.genetica?.nombre || 'Producto' }}</h1>
            <p class="dqr__hero-forma">{{ formaLabel(data.forma) }} · {{ data.cantidad }}{{ data.unidad }}</p>
          </div>

          <!-- Cannabinoides -->
          <div v-if="data.genetica?.thc_pct != null || data.genetica?.cbd_pct != null" class="dqr__cannab">
            <div class="dqr__cannab-item">
              <span class="dqr__cannab-val">{{ fmtPct(data.genetica?.thc_pct) }}</span>
              <span class="dqr__cannab-lbl">THC</span>
            </div>
            <div class="dqr__cannab-item">
              <span class="dqr__cannab-val">{{ fmtPct(data.genetica?.cbd_pct) }}</span>
              <span class="dqr__cannab-lbl">CBD</span>
            </div>
          </div>

          <div v-if="data.genetica?.terpenos" class="dqr__terp">
            <span class="dqr__terp-lbl">Terpenos</span>
            <span class="dqr__terp-val">{{ data.genetica.terpenos }}</span>
          </div>

          <!-- Consejos del club -->
          <div v-if="data.genetica?.consejos_club" class="dqr__consejos">
            <span class="dqr__consejos-lbl">💡 Consejos del club</span>
            <p class="dqr__consejos-txt">{{ data.genetica.consejos_club }}</p>
          </div>

          <!-- Datos -->
          <dl class="dqr__rows">
            <div class="dqr__row"><dt>Fecha de dispensa</dt><dd>{{ fmtFecha(data.fecha) }}</dd></div>
            <div class="dqr__row" v-if="data.lote"><dt>Lote</dt><dd class="dqr__mono">{{ data.lote }}</dd></div>
            <div class="dqr__row" v-if="data.vencimiento"><dt>Vencimiento est.</dt><dd>{{ fmtFecha(data.vencimiento) }}</dd></div>
            <div class="dqr__row" v-if="data.socio_numero"><dt>Socio</dt><dd>#{{ data.socio_numero }}</dd></div>
            <div class="dqr__row" v-if="data.genetica?.registrada_inase"><dt>INASE</dt><dd>{{ data.genetica.numero_registro_inase || 'Registrada' }}</dd></div>
          </dl>
        </template>

        <p class="dqr__foot">{{ club?.nombre }} · Trazabilidad verificada</p>
      </div>

    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import axios from 'axios'

const route = useRoute()
const token = route.params.token

// Base CON /api: los datos del pasaporte viven bajo /api (la página /d/:token es la SPA).
const base = import.meta.env.VITE_API_URL || 'http://localhost:3001/api'

const estado      = ref('cargando') // cargando | gate | ok | no_encontrada
const club        = ref(null)
const data        = ref({})
const dni         = ref('')
const gateError   = ref('')
const verificando = ref(false)

const FORMAS = { flor_seca: 'Flor seca', flor: 'Flor', aceite: 'Aceite', hash: 'Hash', extracto: 'Extracto', comestible: 'Comestible' }
const formaLabel = f => FORMAS[f] || f || 'Producto'
const fmtPct = v => (v == null ? '—' : `${Number(v).toFixed(1)}%`)
const fmtFecha = (f) => {
  if (!f) return '—'
  const [y, m, d] = String(f).slice(0, 10).split('-')
  return `${d}/${m}/${y}`
}

async function verificar() {
  verificando.value = true
  gateError.value = ''
  try {
    const { data: res } = await axios.post(`${base}/d/${token}/ver`, { dni: dni.value }, { timeout: 12000 })
    data.value = res
    estado.value = 'ok'
  } catch (e) {
    if (e?.response?.status === 401) gateError.value = 'DNI incorrecto. Probá de nuevo.'
    else if (e?.response?.status === 429) gateError.value = 'Demasiados intentos. Esperá un minuto.'
    else gateError.value = 'No se pudo verificar. Intentá más tarde.'
  } finally {
    verificando.value = false
  }
}

onMounted(async () => {
  try {
    const { data: res } = await axios.get(`${base}/d/${token}`, { timeout: 12000 })
    club.value = res.club
    estado.value = 'gate'
  } catch {
    estado.value = 'no_encontrada'
  }
})
</script>

<style scoped>
.dqr {
  min-height: 100dvh;
  background: linear-gradient(165deg, #0F2A1E 0%, #1A3D2E 55%, #0F2A1E 100%);
  display: flex; align-items: center; justify-content: center;
  padding: 1.2rem;
  font-family: var(--font-ui, system-ui, sans-serif);
}
.dqr__card {
  width: 100%; max-width: 420px;
  background: var(--c-paper, #f4f8f5);
  border-radius: 22px; overflow: hidden;
  box-shadow: 0 24px 60px rgba(0,0,0,.35);
}

.dqr__head {
  display: flex; align-items: center; gap: .7rem;
  padding: 1rem 1.2rem;
  background: #0F2A1E; color: #fff;
}
.dqr__logo { width: 42px; height: 42px; border-radius: 11px; object-fit: cover; flex-shrink: 0; background: #fff; }
.dqr__logo--ph { display: flex; align-items: center; justify-content: center; background: rgba(255,255,255,.15); font-size: 1.2rem; }
.dqr__head-txt { display: flex; flex-direction: column; min-width: 0; }
.dqr__club { font-family: var(--font-display, sans-serif); font-weight: 700; font-size: 1rem; }
.dqr__head-sub { font-size: .7rem; color: rgba(255,255,255,.6); }

.dqr__center { display: flex; flex-direction: column; align-items: center; gap: .8rem; padding: 3.5rem 1.5rem; color: var(--c-ink-500, #6b7280); }
.dqr__spin { font-size: 1.8rem; color: var(--c-leaf-500, #5a8a72); animation: spin .8s linear infinite; }
.dqr__spin-sm { animation: spin .8s linear infinite; }
@keyframes spin { to { transform: rotate(360deg); } }
.dqr__big-ico { font-size: 2.6rem; color: var(--c-ink-300, #d1d5db); }
.dqr__msg { font-size: .9rem; text-align: center; margin: 0; }

/* Gate */
.dqr__gate { display: flex; flex-direction: column; align-items: center; gap: .8rem; padding: 2.2rem 1.5rem; }
.dqr__gate-ico { font-size: 2.2rem; color: var(--c-leaf-500, #5a8a72); }
.dqr__gate-txt { font-size: .9rem; color: var(--c-ink-700, #374151); text-align: center; margin: 0; }
.dqr__input {
  width: 100%; padding: .8rem 1rem; border-radius: 12px;
  border: 1.5px solid var(--c-leaf-300, #a8c9b5); background: #fff;
  font-size: 1.05rem; text-align: center; color: var(--c-ink-900, #1a1d1f);
  outline: none; box-sizing: border-box;
}
.dqr__input:focus { border-color: var(--c-leaf-600, #3f6452); }
.dqr__input--err { border-color: #dc2626; }
.dqr__gate-err { color: #dc2626; font-size: .8rem; margin: -.3rem 0 0; }
.dqr__btn {
  width: 100%; padding: .85rem; border-radius: 12px; border: none;
  background: var(--c-leaf-800, #1a3d2e); color: #fff;
  font-size: .95rem; font-weight: 700; cursor: pointer;
  display: flex; align-items: center; justify-content: center;
}
.dqr__btn:disabled { opacity: .6; }

/* Pasaporte */
.dqr__pass { padding: 1.4rem 1.3rem 1.2rem; }
.dqr__hero { text-align: center; margin-bottom: 1.2rem; }
.dqr__hero-tipo { display: inline-block; font-size: .66rem; font-weight: 700; text-transform: uppercase; letter-spacing: .06em; color: var(--c-leaf-700, #2d4a3e); background: var(--c-leaf-100, #e8f0eb); padding: .2em .7em; border-radius: 999px; }
.dqr__hero-nombre { font-family: var(--font-display, sans-serif); font-size: 1.5rem; font-weight: 700; color: var(--c-ink-900, #1a1d1f); margin: .4rem 0 .15rem; }
.dqr__hero-forma { font-size: .85rem; color: var(--c-ink-500, #6b7280); margin: 0; }

/* Multi-stock */
.dqr__multi-head { font-size: .72rem; font-weight: 700; text-transform: uppercase; letter-spacing: .06em; color: var(--c-ink-500, #6b7280); margin-bottom: .8rem; }
.dqr__prod-card { background: #fff; border: 1px solid var(--c-leaf-100, #e8f0eb); border-radius: 16px; padding: 1rem; margin-bottom: .8rem; }
.dqr__prod-head { text-align: center; margin-bottom: .7rem; }
.dqr__prod-nombre { font-family: var(--font-display, sans-serif); font-size: 1.2rem; font-weight: 700; color: var(--c-ink-900, #1a1d1f); margin: .35rem 0 .1rem; }
.dqr__prod-forma { font-size: .8rem; color: var(--c-ink-500, #6b7280); margin: 0; }
.dqr__cannab--sm .dqr__cannab-val { font-size: 1.2rem; }
.dqr__prod-lote { display: flex; align-items: center; justify-content: space-between; margin-top: .7rem; padding-top: .6rem; border-top: 1px solid var(--c-leaf-100, #e8f0eb); font-size: .8rem; color: var(--c-ink-500, #6b7280); }
.dqr__prod-lote .dqr__mono { font-weight: 600; color: var(--c-ink-900, #1a1d1f); }

.dqr__cannab { display: flex; gap: .7rem; margin-bottom: .9rem; }
.dqr__cannab-item { flex: 1; background: #fff; border: 1px solid var(--c-leaf-100, #e8f0eb); border-radius: 14px; padding: .8rem; text-align: center; }
.dqr__cannab-val { display: block; font-family: var(--font-display, sans-serif); font-size: 1.5rem; font-weight: 700; color: var(--c-leaf-700, #2d4a3e); line-height: 1; }
.dqr__cannab-lbl { display: block; font-size: .66rem; font-weight: 700; color: var(--c-ink-500, #6b7280); letter-spacing: .08em; margin-top: .3rem; }

.dqr__terp { background: #fff; border: 1px solid var(--c-leaf-100, #e8f0eb); border-radius: 12px; padding: .65rem .85rem; margin-bottom: .9rem; }
.dqr__terp-lbl { display: block; font-size: .62rem; font-weight: 700; text-transform: uppercase; letter-spacing: .06em; color: var(--c-ink-500, #6b7280); }
.dqr__terp-val { font-size: .85rem; color: var(--c-ink-900, #1a1d1f); }

.dqr__consejos { background: #fff; border: 1px solid var(--c-leaf-100, #e8f0eb); border-left: 3px solid var(--c-leaf-500, #5a8a72); border-radius: 12px; padding: .75rem .9rem; margin-bottom: .9rem; }
.dqr__consejos-lbl { display: block; font-size: .68rem; font-weight: 700; text-transform: uppercase; letter-spacing: .05em; color: var(--c-leaf-700, #2d4a3e); margin-bottom: .3rem; }
.dqr__consejos-txt { font-size: .85rem; line-height: 1.45; color: var(--c-ink-700, #374151); margin: 0; white-space: pre-line; }

.dqr__rows { margin: 0; display: flex; flex-direction: column; gap: 0; }
.dqr__row { display: flex; align-items: center; justify-content: space-between; padding: .6rem 0; border-bottom: 1px solid var(--c-leaf-100, #e8f0eb); }
.dqr__row:last-child { border-bottom: none; }
.dqr__row dt { font-size: .8rem; color: var(--c-ink-500, #6b7280); margin: 0; }
.dqr__row dd { font-size: .85rem; font-weight: 600; color: var(--c-ink-900, #1a1d1f); margin: 0; }
.dqr__mono { font-family: var(--font-mono, monospace); }
.dqr__foot { text-align: center; font-size: .68rem; color: var(--c-ink-500, #9aa39c); margin: 1.1rem 0 0; }
</style>
