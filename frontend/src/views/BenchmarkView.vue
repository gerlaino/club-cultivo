<script setup>
import { ref, onMounted, computed } from 'vue'
import { getBenchmark, updatePreferences } from '../lib/api'
import DsSpinner from '../design-system/components/Spinner.vue'

const data    = ref(null)
const loading = ref(true)
const saving  = ref(false)
const error   = ref(null)
const toast   = ref(null)
let toastTimer = null

onMounted(load)

async function load() {
  loading.value = true
  error.value   = null
  try {
    const r = await getBenchmark()
    data.value = r.data
  } catch (e) {
    error.value = e.response?.data?.error || 'Error al cargar benchmark'
  } finally {
    loading.value = false
  }
}

async function toggleOptIn() {
  saving.value = true
  try {
    const nuevo = !data.value.opt_in
    await updatePreferences({ benchmark_opt_in: nuevo })
    data.value.opt_in = nuevo
    showToast('success', nuevo
      ? 'Tu club ya contribuye al benchmark de la plataforma.'
      : 'Tu club ya no comparte datos con el benchmark.')
    await load()
  } catch {
    showToast('danger', 'No se pudo actualizar la preferencia')
  } finally {
    saving.value = false
  }
}

function showToast(type, msg) {
  clearTimeout(toastTimer)
  toast.value = { type, msg }
  toastTimer = setTimeout(() => { toast.value = null }, 5000)
}

const miClub = computed(() => data.value?.mi_club)
const plat   = computed(() => data.value?.plataforma)
const optIn  = computed(() => data.value?.opt_in)

function delta(mio, prom) {
  if (mio == null || prom == null || prom === 0) return null
  return ((mio - prom) / prom * 100).toFixed(1)
}
function deltaClass(d) {
  if (d == null) return ''
  return parseFloat(d) >= 0 ? 'bv__delta--pos' : 'bv__delta--neg'
}
function deltaLabel(d) {
  if (d == null) return '—'
  return (parseFloat(d) >= 0 ? '+' : '') + d + '%'
}

const metricas = computed(() => {
  if (!miClub.value) return []
  const p = plat.value
  return [
    {
      key:     'pacientes',
      label:   'Pacientes activos',
      miVal:   miClub.value.pacientes_activos,
      platVal: p?.avg_pacientes_activos,
      d:       delta(miClub.value.pacientes_activos, p?.avg_pacientes_activos),
    },
    {
      key:     'rendimiento',
      label:   'Rendimiento promedio (g/lote)',
      miVal:   miClub.value.rendimiento_promedio_g != null ? miClub.value.rendimiento_promedio_g + ' g' : null,
      platVal: p?.avg_rendimiento_g != null ? p.avg_rendimiento_g + ' g' : null,
      d:       delta(miClub.value.rendimiento_promedio_g, p?.avg_rendimiento_g),
    },
    {
      key:     'gramos_mes',
      label:   'Gramos dispensados este mes',
      miVal:   miClub.value.gramos_dispensados_mes != null ? miClub.value.gramos_dispensados_mes + ' g' : null,
      platVal: p?.avg_gramos_mes != null ? p.avg_gramos_mes + ' g' : null,
      d:       delta(miClub.value.gramos_dispensados_mes, p?.avg_gramos_mes),
    },
    {
      key:     'dispens_pac',
      label:   'Dispensaciones por paciente (mes)',
      miVal:   miClub.value.dispens_por_paciente_mes,
      platVal: p?.avg_dispens_por_paciente,
      d:       delta(miClub.value.dispens_por_paciente_mes, p?.avg_dispens_por_paciente),
    },
    {
      key:     'lotes',
      label:   'Lotes activos',
      miVal:   miClub.value.lotes_totales,
      platVal: null,
      d:       null,
    },
    {
      key:     'geneticas',
      label:   'Genéticas en cultivo',
      miVal:   miClub.value.geneticas_activas,
      platVal: null,
      d:       null,
    },
  ]
})
</script>

<template>
  <div class="bv">
    <div class="bv__header">
      <div>
        <h1 class="bv__title">Benchmark de la plataforma</h1>
        <p class="bv__sub">Compará las métricas de tu club con el promedio de clubes que optaron por compartir datos</p>
      </div>

      <button
        class="bv__btn-toggle"
        :class="optIn ? 'bv__btn-toggle--on' : 'bv__btn-toggle--off'"
        :disabled="saving || loading"
        @click="toggleOptIn"
      >
        <span class="bv__toggle-dot"></span>
        {{ optIn ? 'Participando' : 'No participando' }}
      </button>
    </div>

    <Transition name="bv-toast">
      <div v-if="toast" class="bv__toast" :class="`bv__toast--${toast.type}`">
        <i :class="toast.type === 'success' ? 'bi bi-check-circle-fill' : 'bi bi-exclamation-triangle-fill'"></i>
        <span>{{ toast.msg }}</span>
        <button class="bv__toast-close" @click="toast = null"><i class="bi bi-x"></i></button>
      </div>
    </Transition>

    <div v-if="loading" class="bv__loading">
      <DsSpinner :size="22" />
      <span>Cargando datos…</span>
    </div>

    <div v-else-if="error" class="bv__error">
      <i class="bi bi-exclamation-triangle"></i> {{ error }}
    </div>

    <template v-else-if="data">

      <div v-if="!optIn" class="bv__banner">
        <i class="bi bi-info-circle-fill"></i>
        <div>
          <strong>Tu club no está participando en el benchmark.</strong>
          Los datos de la plataforma son visibles pero tus datos no contribuyen al promedio.
          Activá la participación para contribuir y mejorar la precisión del benchmark.
        </div>
      </div>

      <div v-if="plat" class="bv__plat-info">
        <i class="bi bi-building-check"></i>
        <span><strong>{{ plat.clubes_participantes }}</strong> club{{ plat.clubes_participantes !== 1 ? 'es' : '' }} compartiendo datos actualmente</span>
      </div>
      <div v-else class="bv__plat-info bv__plat-info--empty">
        <i class="bi bi-hourglass-split"></i>
        <span>Aún no hay clubes participando en el benchmark. Sé el primero en activarlo.</span>
      </div>

      <div class="bv__grid" v-if="miClub">
        <div class="bv__card" v-for="m in metricas" :key="m.key">
          <div class="bv__card-label">{{ m.label }}</div>
          <div class="bv__card-row">
            <div class="bv__card-mi">
              <div class="bv__card-val">{{ m.miVal ?? '—' }}</div>
              <div class="bv__card-sub">Tu club</div>
            </div>
            <div class="bv__card-sep"></div>
            <div class="bv__card-plat">
              <div class="bv__card-val bv__card-val--gray">{{ m.platVal ?? '—' }}</div>
              <div class="bv__card-sub">Promedio</div>
            </div>
          </div>
          <div
            v-if="m.d != null"
            class="bv__delta"
            :class="deltaClass(m.d)"
          >
            {{ deltaLabel(m.d) }} vs promedio
          </div>
        </div>
      </div>

    </template>
  </div>
</template>

<style scoped>
.bv {
  padding: 1.5rem;
  max-width: 960px;
}
.bv__header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 1rem;
  margin-bottom: 1.5rem;
  flex-wrap: wrap;
}
.bv__title {
  font-size: 1.35rem;
  font-weight: 700;
  color: var(--text-primary);
  margin: 0 0 .25rem;
}
.bv__sub {
  font-size: .85rem;
  color: var(--text-secondary);
  margin: 0;
}
.bv__btn-toggle {
  display: flex;
  align-items: center;
  gap: .5rem;
  padding: .5rem 1.1rem;
  border-radius: 999px;
  border: none;
  font-size: .85rem;
  font-weight: 600;
  cursor: pointer;
  transition: background .2s;
}
.bv__btn-toggle--on  { background: #1b5e20; color: #fff; }
.bv__btn-toggle--off { background: #475569; color: #fff; }
.bv__btn-toggle:disabled { opacity: .6; cursor: default; }
.bv__toggle-dot {
  width: 10px; height: 10px; border-radius: 50%; background: rgba(255,255,255,.7);
}
.bv__btn-toggle--on .bv__toggle-dot { background: #a5d6a7; }
.bv__toast {
  display: flex; align-items: center; gap: .6rem;
  padding: .75rem 1rem; border-radius: 8px;
  font-size: .85rem; margin-bottom: 1rem;
}
.bv__toast--success { background: #e8f5e9; color: #1b5e20; border: 1px solid #a5d6a7; }
.bv__toast--danger  { background: #fef2f2; color: #991b1b; border: 1px solid #fca5a5; }
.bv__toast-close { background: none; border: none; cursor: pointer; opacity: .6; margin-left: auto; }
.bv-toast-enter-active, .bv-toast-leave-active { transition: all .25s; }
.bv-toast-enter-from, .bv-toast-leave-to { opacity: 0; transform: translateY(-8px); }
.bv__banner {
  display: flex; gap: .75rem; align-items: flex-start;
  background: #fffbeb; border: 1px solid #fcd34d; border-radius: 10px;
  padding: .9rem 1rem; margin-bottom: 1.25rem;
  font-size: .85rem; color: #92400e;
}
.bv__banner i { font-size: 1rem; margin-top: .1rem; flex-shrink: 0; }
.bv__plat-info {
  display: flex; align-items: center; gap: .5rem;
  font-size: .85rem; color: var(--text-secondary);
  margin-bottom: 1.25rem;
}
.bv__plat-info i { color: #1b5e20; }
.bv__plat-info--empty i { color: #94a3b8; }
.bv__grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(260px, 1fr));
  gap: 1rem;
}
.bv__card {
  background: var(--surface-card, #fff);
  border: 1px solid var(--border-light, #e2e8f0);
  border-radius: 12px;
  padding: 1rem 1.2rem;
}
.bv__card-label {
  font-size: .78rem;
  font-weight: 600;
  color: var(--text-secondary);
  text-transform: uppercase;
  letter-spacing: .04em;
  margin-bottom: .6rem;
}
.bv__card-row {
  display: flex;
  align-items: center;
  gap: .75rem;
}
.bv__card-mi, .bv__card-plat { flex: 1; }
.bv__card-val {
  font-size: 1.5rem;
  font-weight: 700;
  color: var(--text-primary);
  line-height: 1.1;
}
.bv__card-val--gray { color: var(--text-secondary); font-size: 1.2rem; }
.bv__card-sub {
  font-size: .72rem;
  color: var(--text-secondary);
  margin-top: .15rem;
}
.bv__card-sep {
  width: 1px; height: 36px;
  background: var(--border-light, #e2e8f0);
}
.bv__delta {
  font-size: .78rem;
  font-weight: 600;
  margin-top: .5rem;
  padding: .2rem .5rem;
  border-radius: 999px;
  display: inline-block;
}
.bv__delta--pos { background: #e8f5e9; color: #1b5e20; }
.bv__delta--neg { background: #fef2f2; color: #991b1b; }
.bv__loading {
  display: flex; align-items: center; gap: .75rem;
  padding: 3rem 1rem; color: var(--text-secondary);
}
.bv__error {
  padding: 2rem 1rem;
  color: #991b1b;
  background: #fef2f2;
  border-radius: 10px;
  font-size: .9rem;
}
</style>
