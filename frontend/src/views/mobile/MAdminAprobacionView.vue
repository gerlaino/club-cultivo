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
          <span>🪴 {{ p.plantas_count }} {{ p.plantas_count === 1 ? 'planta' : 'plantas' }}</span>
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
      <div v-modal="cerrarConfirmacion" v-if="sheetConfirmar" class="maa__overlay" @click.self="cerrarConfirmacion">
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
            <!-- A DÓNDE VA EL PESO: a un frasco nuevo o a uno que ya existe de este lote. La manicura
                 pesa todos los días y el escritorio ya lo ofrecía; acá se creaba SIEMPRE uno
                 nuevo, así que cada jornada terminaba en un stock distinto del mismo lote. -->
            <div class="maa__field">
              <label class="maa__label">A dónde va</label>
              <div v-if="cargandoContenedores" class="maa__hint">Buscando frascos de este lote…</div>
              <!-- Repartido en varios frascos: copones en uno, bajos en otro (todo del mismo lote). -->
              <template v-else-if="repartir">
                <RepartoFrascos v-model="reparto" :contenedores="contenedores" :peso-total="Number(pesoConfirmado) || 0" />
                <button type="button" class="maa__link" @click="repartir = false">Mandar todo a un solo frasco</button>
              </template>
              <div v-else class="maa__cont-list">
                <button type="button" class="maa__cont" :class="{ 'maa__cont--sel': stockDestino === null }" @click="stockDestino = null">
                  <span class="maa__cont-radio"><span v-if="stockDestino === null" class="maa__cont-dot"></span></span>
                  <span class="maa__cont-body">
                    <span class="maa__cont-title">Frasco nuevo</span>
                    <span class="maa__cont-meta">Sin sede: se asigna después en Depósito</span>
                  </span>
                </button>
                <button v-for="s in contenedores" :key="s.id" type="button" class="maa__cont"
                        :class="{ 'maa__cont--sel': stockDestino === s.id }" @click="stockDestino = s.id">
                  <span class="maa__cont-radio"><span v-if="stockDestino === s.id" class="maa__cont-dot"></span></span>
                  <span class="maa__cont-body">
                    <span class="maa__cont-title">{{ s.numero_lote_producto || `Frasco #${s.id}` }} <b>{{ Number(s.cantidad || 0).toFixed(0) }} g</b></span>
                    <span class="maa__cont-meta">{{ s.sede?.nombre || (s.estado === 'pendiente_asignacion' ? 'Sin asignar' : 'Sin sede') }}<span v-if="s.fecha_elaboracion"> · del {{ fecha(s.fecha_elaboracion) }}</span><span v-if="s.estado === 'agotado'" class="maa__cont-vacio"> · vacío, se vuelve a usar</span></span>
                  </span>
                </button>
              </div>
              <template v-if="!repartir && !cargandoContenedores">
                <span class="maa__hint">{{ stockDestino ? 'El peso se suma al frasco elegido.' : 'Se crea un frasco nuevo de flor seca para este lote.' }}</span>
                <button type="button" class="maa__link" @click="empezarReparto">Repartir en varios frascos (copones, bajos…)</button>
              </template>
            </div>
            <div v-if="errorMsg" class="maa__error">{{ errorMsg }}</div>
            <button
              class="maa__btn-confirmar maa__btn-confirmar--green"
              :disabled="confirmando || !pesoConfirmado || pesoConfirmado <= 0 || (repartir && !repartoCuadra)"
              @click="confirmar"
            >
              <i v-if="!confirmando" class="bi bi-check-circle-fill"></i>
              <i v-else class="bi bi-arrow-repeat maa__spin"></i>
              {{ repartir ? `Confirmar en ${reparto.length} frascos` : (stockDestino ? 'Confirmar y sumar al frasco' : 'Confirmar y generar stock') }}
            </button>
          </div>
        </div>
      </div>
    </Transition>

  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { listPesajesManicuraAdmin, confirmarPesajeManicura, reabrirPesajeManicura, listStocks } from '../../lib/api.js'
import { useToast } from '../../composables/useToast.js'
import RepartoFrascos from '../../components/manicura/RepartoFrascos.vue'
import { useRecargaEnCambios } from '../../composables/useRecargaEnCambios.js'

const toast   = useToast()
const pesajes = ref([])
const loading = ref(true)

const sheetConfirmar = ref(false)
const pesajeActivo   = ref(null)
const pesoConfirmado = ref(null)
const confirmando    = ref(false)
const reabriendo     = ref(null)
const errorMsg       = ref('')
// Frascos de flor seca del lote a los que se puede sumar el peso (misma lista que el escritorio).
const contenedores        = ref([])
const cargandoContenedores = ref(false)
const stockDestino        = ref(null)   // null = frasco nuevo
// Reparto en varios frascos (copones, bajos…): filas { stock_id | null = nuevo, descripcion, gramos }.
const repartir = ref(false)
const reparto  = ref([])
const repartoCuadra = computed(() => {
  const suma = reparto.value.reduce((s, f) => s + (Number(f.gramos) || 0), 0)
  return reparto.value.length > 1 && reparto.value.every(f => Number(f.gramos) > 0) && Math.abs(suma - Number(pesoConfirmado.value || 0)) < 0.01
})
function empezarReparto() {
  repartir.value = true
  reparto.value = [
    { stock_id: null, descripcion: 'Copones', gramos: null },
    { stock_id: null, descripcion: 'Bajos', gramos: null },
  ]
}

const fecha = (f) => (f ? new Date(f).toLocaleDateString('es-AR', { day: '2-digit', month: '2-digit' }) : '')

async function cargarContenedores(loteId) {
  cargandoContenedores.value = true
  stockDestino.value = null
  repartir.value = false
  reparto.value = []
  try {
    // También los frascos que ya se vaciaron: se vuelven a usar y se reabren al recibir el peso.
    const { data } = await listStocks({ lote_id: loteId, incluir_vacios: 1 })
    contenedores.value = (data || []).filter(s => s.forma_producto === 'flor_seca')
  } catch {
    contenedores.value = []
  } finally { cargandoContenedores.value = false }
}

// `silencioso`: la recarga por un aviso de cambios no muestra el spinner (sería un parpadeo
// encima de la lista) y, si falla, deja lo que había.
async function cargar({ silencioso = false } = {}) {
  if (!silencioso) loading.value = true
  try {
    const { data } = await listPesajesManicuraAdmin()
    pesajes.value = data || []
  } catch {
    if (!silencioso) pesajes.value = []
  } finally { loading.value = false }
}
// Lo que manda la manicura aparece solo, y lo que confirma otro admin desaparece solo.
useRecargaEnCambios('pesajes', () => cargar({ silencioso: true }))

function abrirConfirmacion(p) {
  pesajeActivo.value   = p
  pesoConfirmado.value = p.peso_total_g || p.peso_calculado_g || null
  errorMsg.value       = ''
  sheetConfirmar.value = true
  cargarContenedores(p.lote_id)
}

function cerrarConfirmacion() {
  sheetConfirmar.value = false
  pesajeActivo.value   = null
}

async function confirmar() {
  if (!pesajeActivo.value || !pesoConfirmado.value || pesoConfirmado.value <= 0) {
    errorMsg.value = 'El peso debe ser mayor a 0'; return
  }
  if (confirmando.value) return
  confirmando.value = true
  errorMsg.value    = ''
  try {
    await confirmarPesajeManicura(pesajeActivo.value.lote_id, pesajeActivo.value.id, {
      peso_confirmado_g: pesoConfirmado.value,
      ...(repartir.value
        ? { destinos: reparto.value.map(f => ({ stock_id: f.stock_id || undefined, gramos: f.gramos, descripcion: f.stock_id ? undefined : (f.descripcion || undefined) })) }
        : { stock_id: stockDestino.value || undefined }),
    })
    const destino = repartir.value
      ? `repartido en ${reparto.value.length} frascos`
      : stockDestino.value
        ? `sumado a ${contenedores.value.find(s => s.id === stockDestino.value)?.numero_lote_producto || 'el frasco'}`
        : 'frasco nuevo'
    toast.success(`Pesaje de ${pesajeActivo.value.lote_codigo} confirmado — ${pesoConfirmado.value}g · ${destino}`)
    cerrarConfirmacion()
    cargar()
  } catch (e) {
    // Ya lo confirmó otra persona: no es un error de quien está acá, se saca de la lista.
    if (e.response?.data?.ya_confirmado) {
      toast.info(e.response.data.error)
      cerrarConfirmacion()
      cargar()
      return
    }
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
.maa__cont-list { display: flex; flex-direction: column; gap: .4rem; }
.maa__cont {
  display: flex; align-items: center; gap: .6rem; width: 100%; text-align: left;
  background: #fff; border: 1.5px solid var(--c-slate-200); border-radius: 10px; padding: .6rem .75rem;
  font: inherit; color: inherit; cursor: pointer;
}
.maa__cont--sel { border-color: #1b5e20; background: var(--c-green-50, #f0fdf4); }
.maa__cont-radio {
  width: 16px; height: 16px; border-radius: 50%; border: 1.5px solid var(--c-slate-300);
  display: inline-flex; align-items: center; justify-content: center; flex-shrink: 0;
}
.maa__cont--sel .maa__cont-radio { border-color: #1b5e20; }
.maa__cont-dot { width: 8px; height: 8px; border-radius: 50%; background: #1b5e20; }
.maa__cont-body { display: flex; flex-direction: column; gap: .1rem; min-width: 0; }
.maa__cont-title { font-size: .875rem; font-weight: 600; color: var(--c-slate-900); }
.maa__cont-title b { font-weight: 700; color: #1b5e20; margin-left: .3rem; }
.maa__cont-meta { font-size: .72rem; color: var(--c-slate-500); }
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
.maa__cont-vacio { color: var(--c-amber-500); font-weight: 600; }
.maa__link { display: inline-block; margin-top: .45rem; background: none; border: 0; padding: 0; color: var(--brand-primary); font-size: .82rem; font-weight: 600; cursor: pointer; text-decoration: underline; }
</style>
