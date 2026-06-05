<template>
  <div class="maa">

    <!-- Header -->
    <div class="maa__header">
      <h1 class="maa__title">Aprobaciones</h1>
      <span v-if="lotes.length" class="maa__count">{{ lotes.length }}</span>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="maa__loading">
      <i class="bi bi-arrow-repeat maa__spin"></i>
    </div>

    <!-- Vacío -->
    <div v-else-if="!lotes.length" class="maa__empty">
      <i class="bi bi-check2-circle maa__empty-icon"></i>
      <p class="maa__empty-title">Sin aprobaciones pendientes</p>
      <p class="maa__empty-sub">Cuando manicura complete un lote aparecerá aquí.</p>
    </div>

    <!-- Lista -->
    <div v-else class="maa__list">
      <div v-for="lote in lotes" :key="lote.id" class="maa__card">

        <div class="maa__card-top">
          <span class="maa__codigo">{{ lote.codigo }}</span>
          <span class="maa__badge">⏳ Pendiente</span>
        </div>

        <div class="maa__card-meta">
          <span v-if="lote.genetica?.nombre">🌿 {{ lote.genetica.nombre }}</span>
          <span v-if="lote.sala?.nombre">📍 {{ lote.sala.nombre }}</span>
          <span>🪴 {{ lote.plants_count }} plantas</span>
        </div>

        <div v-if="lote.ultima_pesada_manicura" class="maa__pesada">
          <i class="bi bi-bar-chart-fill"></i>
          <strong>{{ lote.ultima_pesada_manicura.peso_seco_g }}g</strong>
          <span v-if="lote.ultima_pesada_manicura.registrado_por">
            · {{ lote.ultima_pesada_manicura.registrado_por }}
          </span>
        </div>

        <div v-if="lote.manicurador" class="maa__manicurador">
          ✂️ {{ lote.manicurador.nombre }}
        </div>

        <div class="maa__card-actions">
          <button class="maa__btn-rechazar" @click="abrirRechazo(lote)">
            <i class="bi bi-x-circle"></i> Rechazar
          </button>
          <button class="maa__btn-aprobar" @click="abrirAprobacion(lote)">
            <i class="bi bi-check-circle"></i>
            {{ lote.manicurador_id ? 'Aprobar y finalizar' : 'Aprobar' }}
          </button>
        </div>

      </div>
    </div>

    <!-- Sheet: Rechazar -->
    <Transition name="maa-sheet">
      <div v-if="sheetRechazo" class="maa__overlay" @click.self="cerrarRechazo">
        <div class="maa__sheet">
          <div class="maa__sheet-handle"></div>
          <div class="maa__sheet-header">
            <h3 class="maa__sheet-title">Rechazar manicura</h3>
            <button class="maa__sheet-close" @click="cerrarRechazo">
              <i class="bi bi-x-lg"></i>
            </button>
          </div>
          <div class="maa__sheet-body">
            <p class="maa__sheet-lote">Lote <strong>{{ loteActivo?.codigo }}</strong></p>
            <div class="maa__field">
              <label class="maa__label">Motivo del rechazo <span class="maa__req">*</span></label>
              <textarea
                v-model="motivoRechazo"
                class="maa__textarea"
                rows="3"
                placeholder="Explicá por qué se rechaza la manicura…"
                autofocus
              ></textarea>
            </div>
            <div v-if="errorMsg" class="maa__error">{{ errorMsg }}</div>
            <button
              class="maa__btn-confirmar maa__btn-confirmar--danger"
              :disabled="rechazando || !motivoRechazo.trim()"
              @click="confirmarRechazo"
            >
              <i v-if="!rechazando" class="bi bi-x-circle-fill"></i>
              <i v-else class="bi bi-arrow-repeat maa__spin"></i>
              Confirmar rechazo
            </button>
          </div>
        </div>
      </div>
    </Transition>

    <!-- Sheet: Aprobar -->
    <Transition name="maa-sheet">
      <div v-if="sheetAprobacion" class="maa__overlay" @click.self="cerrarAprobacion">
        <div class="maa__sheet">
          <div class="maa__sheet-handle"></div>
          <div class="maa__sheet-header">
            <h3 class="maa__sheet-title">Aprobar y generar stock</h3>
            <button class="maa__sheet-close" @click="cerrarAprobacion">
              <i class="bi bi-x-lg"></i>
            </button>
          </div>
          <div class="maa__sheet-body">
            <p class="maa__sheet-lote">Lote <strong>{{ loteActivo?.codigo }}</strong></p>
            <div class="maa__field">
              <label class="maa__label">Peso seco confirmado (g) <span class="maa__req">*</span></label>
              <input
                v-model.number="pesoAprobacion"
                type="number" min="0.1" step="0.1"
                class="maa__input"
                placeholder="0.0"
              />
              <span v-if="loteActivo?.ultima_pesada_manicura" class="maa__hint">
                Registrado por manicura: {{ loteActivo.ultima_pesada_manicura.peso_seco_g }}g
              </span>
            </div>
            <div v-if="loteActivo?.manicurador_id" class="maa__field">
              <label class="maa__label">Precio sugerido (ARS/g)</label>
              <input
                v-model.number="precioAprobacion"
                type="number" min="0" step="0.01"
                class="maa__input"
                placeholder="0.00"
              />
              <span class="maa__hint">Opcional — se usará al crear dispensaciones</span>
            </div>
            <div v-if="loteActivo?.manicurador_id && sedes.length" class="maa__field">
              <label class="maa__label">Asignar a sede</label>
              <select v-model="sedeAprobacion" class="maa__input maa__select">
                <option :value="null">— Sin asignar (pendiente) —</option>
                <option v-for="s in sedes" :key="s.id" :value="s.id">{{ s.nombre }}</option>
              </select>
              <span class="maa__hint">Solo sedes sociales o mixtas</span>
            </div>
            <div v-if="errorMsg" class="maa__error">{{ errorMsg }}</div>
            <button
              class="maa__btn-confirmar maa__btn-confirmar--green"
              :disabled="aprobando || !pesoAprobacion || pesoAprobacion <= 0"
              @click="confirmarAprobacion"
            >
              <i v-if="!aprobando" class="bi bi-check-circle-fill"></i>
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
import { listLotes, listSedes, aprobarManicura, rechazarManicura } from '../../lib/api.js'
import { useToast } from '../../composables/useToast.js'

const toast   = useToast()
const lotes   = ref([])
const sedes   = ref([])
const loading = ref(true)

const sheetRechazo    = ref(false)
const sheetAprobacion = ref(false)
const loteActivo      = ref(null)
const motivoRechazo   = ref('')
const pesoAprobacion  = ref(null)
const sedeAprobacion  = ref(null)
const precioAprobacion = ref(null)
const rechazando      = ref(false)
const aprobando       = ref(false)
const errorMsg        = ref('')

async function cargar() {
  loading.value = true
  try {
    const [lotesRes, sedesRes] = await Promise.allSettled([
      listLotes({ estado: 'manicura_pendiente' }),
      listSedes(),
    ])
    lotes.value = lotesRes.status === 'fulfilled' ? (lotesRes.value.data || []) : []
    sedes.value = sedesRes.status === 'fulfilled'
      ? (sedesRes.value.data || []).filter(s => ['social', 'mixta'].includes(s.tipo))
      : []
  } finally { loading.value = false }
}

function abrirRechazo(lote) {
  loteActivo.value   = lote
  motivoRechazo.value = ''
  errorMsg.value      = ''
  sheetRechazo.value  = true
}

function cerrarRechazo() {
  sheetRechazo.value = false
  loteActivo.value   = null
}

function abrirAprobacion(lote) {
  loteActivo.value      = lote
  pesoAprobacion.value  = lote.ultima_pesada_manicura?.peso_seco_g ?? null
  sedeAprobacion.value  = null
  precioAprobacion.value = null
  errorMsg.value        = ''
  sheetAprobacion.value = true
}

function cerrarAprobacion() {
  sheetAprobacion.value = false
  loteActivo.value      = null
}

async function confirmarRechazo() {
  if (!loteActivo.value || !motivoRechazo.value.trim()) return
  rechazando.value = true
  errorMsg.value   = ''
  try {
    await rechazarManicura(loteActivo.value.id, motivoRechazo.value.trim())
    const destino = loteActivo.value.manicurador_id ? 'vuelve a cosecha' : 'vuelve a secado'
    toast.success(`Lote ${loteActivo.value.codigo} rechazado — ${destino}`)
    cerrarRechazo()
    cargar()
  } catch (e) {
    errorMsg.value = e.response?.data?.error || 'Error al rechazar'
  } finally { rechazando.value = false }
}

async function confirmarAprobacion() {
  if (!pesoAprobacion.value || pesoAprobacion.value <= 0) {
    errorMsg.value = 'El peso debe ser mayor a 0'; return
  }
  aprobando.value = true
  errorMsg.value  = ''
  try {
    if (loteActivo.value.manicurador_id) {
      const payload = { peso_seco_g: pesoAprobacion.value }
      if (sedeAprobacion.value) payload.sede_id = sedeAprobacion.value
      if (precioAprobacion.value) payload.precio_sugerido_ars = precioAprobacion.value
      await aprobarManicura(loteActivo.value.id, payload)
      const dest = sedeAprobacion.value
        ? `asignado a ${sedes.value.find(s => s.id === sedeAprobacion.value)?.nombre}`
        : 'pendiente de asignación'
      toast.success(`Lote ${loteActivo.value.codigo} finalizado — ${dest}`)
    } else {
      await aprobarManicura(loteActivo.value.id)
      toast.success(`Lote ${loteActivo.value.codigo} aprobado — pasa a curado`)
    }
    cerrarAprobacion()
    cargar()
  } catch (e) {
    errorMsg.value = e.response?.data?.error || 'Error al aprobar'
  } finally { aprobando.value = false }
}

onMounted(cargar)
</script>

<style scoped>
.maa { padding: 0 0 2rem; }

.maa__header {
  display: flex; align-items: center; gap: .6rem;
  padding: 1rem 1rem .75rem;
}
.maa__title { font-size: 1.15rem; font-weight: 800; color: #0f172a; margin: 0; }
.maa__count {
  background: #fef3c7; color: #b45309; border: 1px solid #fde68a;
  font-size: .68rem; font-weight: 700; padding: .15em .6em;
  border-radius: 999px;
}

.maa__loading { display: flex; align-items: center; justify-content: center; padding: 3rem; color: #94a3b8; }
.maa__spin { animation: maa-spin .8s linear infinite; display: inline-block; font-size: 1.4rem; }
@keyframes maa-spin { to { transform: rotate(360deg); } }

.maa__empty { display: flex; flex-direction: column; align-items: center; gap: .4rem; padding: 3.5rem 1rem; text-align: center; }
.maa__empty-icon { font-size: 2.8rem; color: #22c55e; }
.maa__empty-title { font-size: .95rem; font-weight: 700; color: #0f172a; margin: 0; }
.maa__empty-sub { font-size: .78rem; color: #94a3b8; margin: 0; }

/* Cards */
.maa__list { display: flex; flex-direction: column; gap: .625rem; padding: 0 1rem; }
.maa__card {
  background: #fff; border-radius: 14px; padding: .875rem;
  border: 1.5px solid #fde68a;
  box-shadow: 0 1px 4px rgba(0,0,0,.05);
  display: flex; flex-direction: column; gap: .45rem;
}

.maa__card-top { display: flex; align-items: center; gap: .5rem; }
.maa__codigo { font-size: .95rem; font-weight: 800; color: #0f172a; font-family: monospace; }
.maa__badge {
  font-size: .62rem; font-weight: 700; padding: .2em .6em;
  border-radius: 999px; background: #fef3c7; color: #b45309;
}

.maa__card-meta {
  display: flex; flex-wrap: wrap; gap: .25rem .75rem;
  font-size: .75rem; color: #64748b;
}

.maa__pesada {
  display: inline-flex; align-items: center; gap: .35rem;
  font-size: .78rem; color: #374151;
  background: #f1f5f9; border-radius: 7px; padding: .3rem .6rem;
  align-self: flex-start;
}

.maa__manicurador { font-size: .72rem; color: #15803d; font-weight: 600; }

.maa__card-actions { display: flex; gap: .5rem; margin-top: .25rem; }
.maa__btn-rechazar {
  flex: 1; display: flex; align-items: center; justify-content: center; gap: .35rem;
  background: #fff; color: #dc2626; border: 1.5px solid #fca5a5;
  padding: .65rem; border-radius: 10px; font-size: .82rem; font-weight: 600;
  cursor: pointer; -webkit-tap-highlight-color: transparent;
}
.maa__btn-rechazar:active { background: #fef2f2; }
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
  width: 40px; height: 4px; background: #e2e8f0;
  border-radius: 999px; margin: .75rem auto .25rem;
}
.maa__sheet-header {
  display: flex; align-items: center; justify-content: space-between;
  padding: .5rem 1.25rem 1rem;
}
.maa__sheet-title { font-size: 1rem; font-weight: 700; color: #0f172a; margin: 0; }
.maa__sheet-close {
  background: none; border: none; color: #94a3b8;
  font-size: 1rem; cursor: pointer; padding: .25rem;
}
.maa__sheet-body { padding: 0 1.25rem 1.5rem; display: flex; flex-direction: column; gap: .875rem; }
.maa__sheet-lote { font-size: .85rem; color: #64748b; margin: 0; }

.maa__info-box {
  background: #eff6ff; border: 1px solid #bfdbfe; border-radius: 9px;
  padding: .65rem .875rem; font-size: .8rem; color: #1e40af; line-height: 1.45;
}

.maa__field { display: flex; flex-direction: column; gap: .35rem; }
.maa__label { font-size: .72rem; font-weight: 700; color: #374151; text-transform: uppercase; letter-spacing: .04em; }
.maa__req { color: #ef4444; }
.maa__input {
  background: #f8fafc; border: 1.5px solid #e2e8f0; border-radius: 9px;
  padding: .7rem .875rem; font-size: .95rem; color: #0f172a;
  width: 100%; box-sizing: border-box; outline: none;
}
.maa__input:focus { border-color: #15803d; background: #fff; }
.maa__select { appearance: none; -webkit-appearance: none; cursor: pointer; }
.maa__textarea {
  background: #f8fafc; border: 1.5px solid #e2e8f0; border-radius: 9px;
  padding: .7rem .875rem; font-size: .875rem; color: #0f172a;
  width: 100%; box-sizing: border-box; outline: none;
  resize: none; font-family: inherit; min-height: 90px;
}
.maa__textarea:focus { border-color: #dc2626; background: #fff; }
.maa__hint { font-size: .7rem; color: #94a3b8; }

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
.maa__btn-confirmar--danger { background: #dc2626; color: #fff; }
.maa__btn-confirmar--green  { background: #15803d; color: #fff; }

/* Sheet transition */
.maa-sheet-enter-active, .maa-sheet-leave-active { transition: opacity .2s; }
.maa-sheet-enter-active .maa__sheet, .maa-sheet-leave-active .maa__sheet { transition: transform .25s ease; }
.maa-sheet-enter-from, .maa-sheet-leave-to { opacity: 0; }
.maa-sheet-enter-from .maa__sheet, .maa-sheet-leave-to .maa__sheet { transform: translateY(100%); }
</style>
