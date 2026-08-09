<template>
  <div class="maa">

    <!-- Header -->
    <div class="maa__header">
      <h1 class="maa__title">Confirmar pesajes</h1>
      <span v-if="pesajes.length" class="maa__count">{{ pesajes.length }}</span>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="maa__loading">
      <i class="bi bi-arrow-repeat maa__spin"></i>
    </div>

    <!-- Vacío -->
    <div v-else-if="!pesajes.length" class="maa__empty">
      <i class="bi bi-check2-circle maa__empty-icon"></i>
      <p class="maa__empty-title">Sin pesajes para confirmar</p>
      <p class="maa__empty-sub">Cuando manicura cierre un pesaje aparecerá acá.</p>
    </div>

    <!-- Lista -->
    <div v-else class="maa__list">
      <div v-for="p in pesajes" :key="p.id" class="maa__card">

        <div class="maa__card-top">
          <span class="maa__codigo">{{ p.lote_codigo }}</span>
          <span class="maa__badge">⏳ Enviado</span>
        </div>

        <div class="maa__card-meta">
          <span v-if="p.lote_genetica">🌿 {{ p.lote_genetica }}</span>
          <span>🪴 {{ p.plantas_count }} plantas</span>
        </div>

        <div class="maa__pesada">
          <i class="bi bi-bar-chart-fill"></i>
          <strong>{{ (p.peso_total_g || p.peso_calculado_g || 0).toFixed(1) }}g</strong>
          <span v-if="p.manicurador_nombre">· ✂️ {{ p.manicurador_nombre }}</span>
        </div>

        <div class="maa__card-actions">
          <button class="maa__btn-rechazar" :disabled="reabriendo === p.id" @click="reabrir(p)">
            <i class="bi bi-arrow-counterclockwise"></i> Reabrir
          </button>
          <button class="maa__btn-aprobar" @click="abrirConfirmacion(p)">
            <i class="bi bi-check-circle"></i> Confirmar
          </button>
        </div>

      </div>
    </div>

    <!-- Sheet: Confirmar -->
    <Transition name="maa-sheet">
      <div v-if="sheetConfirmar" class="maa__overlay" @click.self="cerrarConfirmacion">
        <div class="maa__sheet">
          <div class="maa__sheet-handle"></div>
          <div class="maa__sheet-header">
            <h3 class="maa__sheet-title">Confirmar y generar stock</h3>
            <button class="maa__sheet-close" @click="cerrarConfirmacion">
              <i class="bi bi-x-lg"></i>
            </button>
          </div>
          <div class="maa__sheet-body">
            <p class="maa__sheet-lote">Lote <strong>{{ pesajeActivo?.lote_codigo }}</strong></p>
            <div class="maa__field">
              <label class="maa__label">Peso confirmado (g) <span class="maa__req">*</span></label>
              <input
                v-model.number="pesoConfirmado"
                type="number" min="0.1" step="0.1"
                class="maa__input"
                :class="{ 'maa__input--warn': !pesoConfirmado || pesoConfirmado <= 0 }"
                placeholder="Ingresá el peso en gramos"
              />
              <span class="maa__hint">Pre-completado desde el pesaje. Ajustalo si hace falta.</span>
            </div>
            <div class="maa__info-box">
              El stock se crea sin sede (pendiente de asignación). La sede se asigna después en Stock.
            </div>
            <div v-if="errorMsg" class="maa__error">{{ errorMsg }}</div>
            <button
              class="maa__btn-confirmar maa__btn-confirmar--green"
              :disabled="confirmando || !pesoConfirmado || pesoConfirmado <= 0"
              @click="confirmar"
            >
              <i v-if="!confirmando" class="bi bi-check-circle-fill"></i>
              <i v-else class="bi bi-arrow-repeat maa__spin"></i>
              Confirmar y generar stock
            </button>
          </div>
        </div>
      </div>
    </Transition>

  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { listPesajesManicuraAdmin, confirmarPesajeManicura, reabrirPesajeManicura } from '../../lib/api.js'
import { useToast } from '../../composables/useToast.js'

const toast   = useToast()
const pesajes = ref([])
const loading = ref(true)

const sheetConfirmar = ref(false)
const pesajeActivo   = ref(null)
const pesoConfirmado = ref(null)
const confirmando    = ref(false)
const reabriendo     = ref(null)
const errorMsg       = ref('')

async function cargar() {
  loading.value = true
  try {
    const { data } = await listPesajesManicuraAdmin()
    pesajes.value = data || []
  } catch {
    pesajes.value = []
  } finally { loading.value = false }
}

function abrirConfirmacion(p) {
  pesajeActivo.value   = p
  pesoConfirmado.value = p.peso_total_g || p.peso_calculado_g || null
  errorMsg.value       = ''
  sheetConfirmar.value = true
}

function cerrarConfirmacion() {
  sheetConfirmar.value = false
  pesajeActivo.value   = null
}

async function confirmar() {
  if (!pesajeActivo.value || !pesoConfirmado.value || pesoConfirmado.value <= 0) {
    errorMsg.value = 'El peso debe ser mayor a 0'; return
  }
  confirmando.value = true
  errorMsg.value    = ''
  try {
    await confirmarPesajeManicura(pesajeActivo.value.lote_id, pesajeActivo.value.id, {
      peso_confirmado_g: pesoConfirmado.value,
    })
    toast.success(`Pesaje de ${pesajeActivo.value.lote_codigo} confirmado — ${pesoConfirmado.value}g`)
    cerrarConfirmacion()
    cargar()
  } catch (e) {
    errorMsg.value = e.response?.data?.error || e.response?.data?.errors?.[0] || 'Error al confirmar'
  } finally { confirmando.value = false }
}

async function reabrir(p) {
  reabriendo.value = p.id
  try {
    await reabrirPesajeManicura(p.lote_id, p.id)
    toast.success(`Pesaje de ${p.lote_codigo} reabierto — vuelve a manicura para corregir`)
    cargar()
  } catch (e) {
    toast.error(e.response?.data?.error || 'No se pudo reabrir')
  } finally { reabriendo.value = null }
}

onMounted(cargar)
</script>

<style scoped>
.maa { padding: 0 0 2rem; }

.maa__header {
  display: flex; align-items: center; gap: .6rem;
  padding: 1rem 1rem .75rem;
}
.maa__title { font-size: 1.15rem; font-weight: 800; color: var(--c-slate-900); margin: 0; }
.maa__count {
  background: #fef3c7; color: #b45309; border: 1px solid #fde68a;
  font-size: .68rem; font-weight: 700; padding: .15em .6em;
  border-radius: 999px;
}

.maa__loading { display: flex; align-items: center; justify-content: center; padding: 3rem; color: var(--c-slate-400); }
.maa__spin { animation: maa-spin .8s linear infinite; display: inline-block; font-size: 1.4rem; }
@keyframes maa-spin { to { transform: rotate(360deg); } }

.maa__empty { display: flex; flex-direction: column; align-items: center; gap: .4rem; padding: 3.5rem 1rem; text-align: center; }
.maa__empty-icon { font-size: 2.8rem; color: #22c55e; }
.maa__empty-title { font-size: .95rem; font-weight: 700; color: var(--c-slate-900); margin: 0; }
.maa__empty-sub { font-size: .78rem; color: var(--c-slate-400); margin: 0; }

/* Cards */
.maa__list { display: flex; flex-direction: column; gap: .625rem; padding: 0 1rem; }
.maa__card {
  background: #fff; border-radius: 14px; padding: .875rem;
  border: 1.5px solid #fde68a;
  box-shadow: 0 1px 4px rgba(0,0,0,.05);
  display: flex; flex-direction: column; gap: .45rem;
}

.maa__card-top { display: flex; align-items: center; gap: .5rem; }
.maa__codigo { font-size: .95rem; font-weight: 800; color: var(--c-slate-900); font-family: monospace; }
.maa__badge {
  font-size: .62rem; font-weight: 700; padding: .2em .6em;
  border-radius: 999px; background: #fef3c7; color: #b45309;
}

.maa__card-meta {
  display: flex; flex-wrap: wrap; gap: .25rem .75rem;
  font-size: .75rem; color: var(--c-slate-500);
}

.maa__pesada {
  display: inline-flex; align-items: center; gap: .35rem;
  font-size: .78rem; color: #374151;
  background: var(--c-slate-100); border-radius: 7px; padding: .3rem .6rem;
  align-self: flex-start;
}

.maa__card-actions { display: flex; gap: .5rem; margin-top: .25rem; }
.maa__btn-rechazar {
  flex: 1; display: flex; align-items: center; justify-content: center; gap: .35rem;
  background: #fff; color: #b45309; border: 1.5px solid #fcd34d;
  padding: .65rem; border-radius: 10px; font-size: .82rem; font-weight: 600;
  cursor: pointer; -webkit-tap-highlight-color: transparent;
}
.maa__btn-rechazar:active { background: #fffbeb; }
.maa__btn-rechazar:disabled { opacity: .5; }
.maa__btn-aprobar {
  flex: 2; display: flex; align-items: center; justify-content: center; gap: .35rem;
  background: #15803d; color: #fff; border: none;
  padding: .65rem; border-radius: 10px; font-size: .82rem; font-weight: 700;
  cursor: pointer; -webkit-tap-highlight-color: transparent;
}
.maa__btn-aprobar:active { opacity: .85; }

/* Sheet overlay */
.maa__overlay {
  position: fixed; inset: 0; z-index: 200;
  background: rgba(0,0,0,.5);
  display: flex; align-items: flex-end;
}
.maa__sheet {
  width: 100%; background: #fff;
  border-radius: 20px 20px 0 0;
  max-height: 85vh; overflow-y: auto;
  padding-bottom: env(safe-area-inset-bottom, 1rem);
}
.maa__sheet-handle {
  width: 40px; height: 4px; background: var(--c-slate-200);
  border-radius: 999px; margin: .75rem auto .25rem;
}
.maa__sheet-header {
  display: flex; align-items: center; justify-content: space-between;
  padding: .5rem 1.25rem 1rem;
}
.maa__sheet-title { font-size: 1rem; font-weight: 700; color: var(--c-slate-900); margin: 0; }
.maa__sheet-close {
  background: none; border: none; color: var(--c-slate-400);
  font-size: 1rem; cursor: pointer; padding: .25rem;
}
.maa__sheet-body { padding: 0 1.25rem 1.5rem; display: flex; flex-direction: column; gap: .875rem; }
.maa__sheet-lote { font-size: .85rem; color: var(--c-slate-500); margin: 0; }

.maa__info-box {
  background: #eff6ff; border: 1px solid #bfdbfe; border-radius: 9px;
  padding: .65rem .875rem; font-size: .8rem; color: #1e40af; line-height: 1.45;
}

.maa__field { display: flex; flex-direction: column; gap: .35rem; }
.maa__label { font-size: .72rem; font-weight: 700; color: #374151; text-transform: uppercase; letter-spacing: .04em; }
.maa__req { color: #ef4444; }
.maa__input {
  background: var(--c-slate-50); border: 1.5px solid var(--c-slate-200); border-radius: 9px;
  padding: .7rem .875rem; font-size: .95rem; color: var(--c-slate-900);
  width: 100%; box-sizing: border-box; outline: none;
}
.maa__input:focus { border-color: #15803d; background: #fff; }
.maa__hint { font-size: .7rem; color: var(--c-slate-400); }
.maa__input--warn { border-color: #f59e0b; background: #fffbeb; }

.maa__error {
  background: #fef2f2; border: 1px solid #fecaca; border-radius: 8px;
  padding: .5rem .75rem; font-size: .8rem; color: #dc2626;
}

.maa__btn-confirmar {
  width: 100%; display: flex; align-items: center; justify-content: center; gap: .5rem;
  border: none; padding: .9rem; border-radius: 12px;
  font-size: .95rem; font-weight: 700; cursor: pointer;
  -webkit-tap-highlight-color: transparent;
}
.maa__btn-confirmar:disabled { opacity: .5; cursor: not-allowed; }
.maa__btn-confirmar--green  { background: #15803d; color: #fff; }

/* Sheet transition */
.maa-sheet-enter-active, .maa-sheet-leave-active { transition: opacity .2s; }
.maa-sheet-enter-active .maa__sheet, .maa-sheet-leave-active .maa__sheet { transition: transform .25s ease; }
.maa-sheet-enter-from, .maa-sheet-leave-to { opacity: 0; }
.maa-sheet-enter-from .maa__sheet, .maa-sheet-leave-to .maa__sheet { transform: translateY(100%); }
</style>
