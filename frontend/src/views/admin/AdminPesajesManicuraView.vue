<template>
  <div class="apm">

    <div class="apm__header">
      <div class="apm__eyebrow">
        <Scale :size="14" :stroke-width="2" />
        Administración
      </div>
      <h1 class="apm__title">Manicura</h1>
      <p class="apm__sub">Pesajes diarios enviados por manicura. Confirmá el peso y asigná el contenedor de stock.</p>
    </div>

    <!-- Lotes del flujo anterior pendientes de aprobación -->
    <RouterLink v-if="lotesFlujoViejo > 0" to="/aprobaciones" class="apm__legacy-banner">
      <Clock :size="15" :stroke-width="2" />
      <span><strong>{{ lotesFlujoViejo }}</strong> lote{{ lotesFlujoViejo === 1 ? '' : 's' }} del flujo anterior esperando aprobación</span>
      <span class="apm__legacy-cta">Ir a aprobar →</span>
    </RouterLink>

    <div v-if="loading" class="apm__loading">
      <DsSpinner />
    </div>

    <div v-else-if="!pesajes.length" class="apm__empty">
      <div class="apm__empty-ico"><Scale :size="40" :stroke-width="1.25" /></div>
      <p class="apm__empty-title">Sin pesajes pendientes</p>
      <p class="apm__empty-sub">Cuando manicura cierre un día de trabajo aparecerá aquí para tu confirmación.</p>
    </div>

    <div v-else class="apm__cards">
      <div v-for="p in pesajes" :key="p.id" class="apm__card">
        <div class="apm__card-stripe"></div>
        <div class="apm__card-body">
          <div class="apm__card-head">
            <span class="apm__card-codigo">{{ p.lote_codigo }}</span>
            <span class="apm__badge">
              <Clock :size="11" :stroke-width="2.5" /> Esperando confirmación
            </span>
          </div>
          <div class="apm__card-meta">
            <span v-if="p.lote_genetica"><Leaf :size="13" :stroke-width="2" /> {{ p.lote_genetica }}</span>
            <span><Scissors :size="13" :stroke-width="2" /> {{ p.manicurador_nombre }}</span>
            <span><Calendar :size="13" :stroke-width="2" /> {{ fmtDate(p.fecha_pesaje) }}</span>
            <span v-if="p.plantas_registradas">
              <Package :size="13" :stroke-width="2" /> {{ p.plantas_registradas }} plantas
            </span>
          </div>

          <div class="apm__peso-box">
            <div class="apm__peso-item">
              <span class="apm__peso-lbl">Peso declarado</span>
              <span class="apm__peso-val">{{ (p.peso_total_g || p.peso_calculado_g || 0).toFixed(1) }}<span class="apm__peso-unit">g</span></span>
            </div>
            <div v-if="p.peso_calculado_g && p.peso_total_g && Math.abs(p.peso_calculado_g - p.peso_total_g) > 0.5" class="apm__peso-item">
              <span class="apm__peso-lbl">Suma por planta</span>
              <span class="apm__peso-val apm__peso-val--secondary">{{ p.peso_calculado_g.toFixed(1) }}<span class="apm__peso-unit">g</span></span>
            </div>
          </div>

          <div v-if="p.notas" class="apm__notas">
            <MessageCircle :size="12" :stroke-width="2" /> {{ p.notas }}
          </div>

          <!-- Plantas detalle si vienen -->
          <details v-if="p.plantas?.length" class="apm__plantas-toggle">
            <summary class="apm__plantas-summary">
              <List :size="12" :stroke-width="2" /> Ver plantas ({{ p.plantas.length }})
            </summary>
            <div class="apm__plantas-list">
              <div v-for="pp in p.plantas" :key="pp.id" class="apm__planta-row">
                <span class="apm__planta-nombre">{{ pp.plant_nombre || pp.plant_qr }}</span>
                <span class="apm__planta-peso">{{ pp.peso_seco_g?.toFixed(1) || '—' }}g</span>
              </div>
            </div>
          </details>
        </div>

        <div class="apm__card-actions">
          <button class="apm__btn-confirmar" @click="abrirConfirmacion(p)">
            <CheckCircle :size="14" :stroke-width="2" /> Confirmar
          </button>
        </div>
      </div>
    </div>

    <!-- Modal confirmar -->
    <Teleport to="body">
      <Transition name="apm-fade">
        <div v-if="modalOpen" class="apm-overlay" @click.self="cerrarModal">
          <div class="apm-modal">
            <div class="apm-modal__hd">
              <div class="apm-modal__ico"><CheckCircle :size="18" :stroke-width="1.75" /></div>
              <div>
                <h2 class="apm-modal__title">Confirmar pesaje</h2>
                <p class="apm-modal__sub">
                  {{ pesajeActivo?.lote_codigo }}
                  <span v-if="pesajeActivo?.lote_genetica"> · {{ pesajeActivo.lote_genetica }}</span>
                  <span v-if="pesajeActivo?.manicurador_nombre"> · {{ pesajeActivo.manicurador_nombre }}</span>
                </p>
              </div>
              <button class="apm-modal__close" @click="cerrarModal"><X :size="16" /></button>
            </div>

            <form class="apm-modal__body" @submit.prevent="confirmar">

              <div class="apm-field">
                <label class="apm-label">Peso confirmado (g) <span class="apm-req">*</span></label>
                <div class="apm-input-row">
                  <input
                    v-model.number="form.peso_confirmado_g"
                    type="number" step="0.1" min="0.1"
                    class="apm-input" required autofocus
                    placeholder="0.0"
                  />
                  <span class="apm-suffix">g</span>
                </div>
                <span class="apm-hint">
                  Manicura declaró {{ (pesajeActivo?.peso_total_g || pesajeActivo?.peso_calculado_g || 0).toFixed(1) }}g
                  — podés ajustarlo
                </span>
              </div>

              <div class="apm-field">
                <label class="apm-label">Contenedor de stock</label>
                <div v-if="loadingStocks" class="apm-hint">Cargando stocks disponibles…</div>
                <template v-else>
                  <select v-model="form.stock_id" class="apm-input apm-select">
                    <option :value="null">— Crear nuevo contenedor —</option>
                    <optgroup v-if="stocksMismaGenetica.length" label="Misma genética (recomendado)">
                      <option v-for="s in stocksMismaGenetica" :key="s.id" :value="s.id">
                        {{ s.numero_lote_producto || `Stock #${s.id}` }} · {{ s.cantidad?.toFixed(0) }}g disponibles · {{ s.sede_nombre || 'Sin sede' }}
                      </option>
                    </optgroup>
                    <optgroup v-if="stocksOtros.length" label="Otros contenedores">
                      <option v-for="s in stocksOtros" :key="s.id" :value="s.id">
                        {{ s.numero_lote_producto || `Stock #${s.id}` }} · {{ s.cantidad?.toFixed(0) }}g · {{ s.sede_nombre || 'Sin sede' }}
                      </option>
                    </optgroup>
                  </select>
                  <span class="apm-hint">
                    <template v-if="form.stock_id">Se sumará el peso al stock seleccionado.</template>
                    <template v-else>Se creará un nuevo contenedor para esta genética.</template>
                  </span>
                </template>
              </div>

              <div v-if="modalError" class="apm-error">{{ modalError }}</div>

              <div class="apm-actions">
                <button type="button" class="apm-btn-cancel" @click="cerrarModal">Cancelar</button>
                <button
                  type="submit"
                  class="apm-btn-ok"
                  :disabled="saving || !form.peso_confirmado_g || form.peso_confirmado_g <= 0"
                >
                  <DsSpinner v-if="saving" :size="14" />
                  <CheckCircle v-else :size="13" :stroke-width="2" />
                  Confirmar y generar stock
                </button>
              </div>
            </form>
          </div>
        </div>
      </Transition>
    </Teleport>

  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import DsSpinner from '../../design-system/components/Spinner.vue'
import { Scale, Scissors, Leaf, Calendar, Package, CheckCircle, Clock, X, MessageCircle, List } from 'lucide-vue-next'
import { listPesajesManicuraAdmin, confirmarPesajeManicura, listStocks, listLotes } from '../../lib/api.js'
import { useToast } from '../../composables/useToast.js'

const toast = useToast()

const loading      = ref(true)
const pesajes      = ref([])
// Lotes del flujo anterior (manicura_pendiente) que aún esperan aprobación.
// Cuando este contador llegue a 0 de forma permanente, /aprobaciones puede eliminarse.
const lotesFlujoViejo = ref(0)
const modalOpen    = ref(false)
const pesajeActivo = ref(null)
const loadingStocks = ref(false)
const stocks        = ref([])
const saving        = ref(false)
const modalError    = ref('')

const form = ref({ peso_confirmado_g: null, stock_id: null })

const stocksMismaGenetica = computed(() => {
  if (!pesajeActivo.value?.lote_genetica) return []
  return stocks.value.filter(s =>
    s.genetica_nombre === pesajeActivo.value.lote_genetica &&
    ['pendiente_asignacion', 'asignado'].includes(s.estado)
  )
})

const stocksOtros = computed(() => {
  const mismaIds = new Set(stocksMismaGenetica.value.map(s => s.id))
  return stocks.value.filter(s =>
    !mismaIds.has(s.id) && ['pendiente_asignacion', 'asignado'].includes(s.estado)
  )
})

async function cargar() {
  loading.value = true
  try {
    const { data } = await listPesajesManicuraAdmin()
    pesajes.value = data || []
  } catch {
    toast.error('Error al cargar los pesajes')
    pesajes.value = []
  } finally {
    loading.value = false
  }
  try {
    const { data } = await listLotes({ estado: 'manicura_pendiente' })
    lotesFlujoViejo.value = (data || []).length
  } catch { lotesFlujoViejo.value = 0 }
}

async function abrirConfirmacion(p) {
  pesajeActivo.value = p
  form.value = {
    peso_confirmado_g: p.peso_total_g || p.peso_calculado_g || null,
    stock_id: null,
  }
  modalError.value = ''
  modalOpen.value  = true
  loadingStocks.value = true
  try {
    const { data } = await listStocks({ lote_id: p.lote_id })
    stocks.value = data || []
  } catch {
    stocks.value = []
  } finally {
    loadingStocks.value = false
  }
}

function cerrarModal() {
  modalOpen.value    = false
  pesajeActivo.value = null
}

async function confirmar() {
  if (!form.value.peso_confirmado_g || form.value.peso_confirmado_g <= 0) return
  saving.value     = true
  modalError.value = ''
  try {
    await confirmarPesajeManicura(
      pesajeActivo.value.lote_id,
      pesajeActivo.value.id,
      {
        peso_confirmado_g: form.value.peso_confirmado_g,
        stock_id:          form.value.stock_id || undefined,
      }
    )
    const stockLabel = form.value.stock_id
      ? `sumado al stock existente`
      : `nuevo contenedor creado`
    toast.success(`Pesaje de ${pesajeActivo.value.lote_codigo} confirmado — ${form.value.peso_confirmado_g}g · ${stockLabel}`)
    cerrarModal()
    cargar()
  } catch (e) {
    modalError.value = e.response?.data?.error || e.response?.data?.errors?.[0] || 'Error al confirmar'
  } finally {
    saving.value = false
  }
}

function fmtDate(d) {
  if (!d) return '—'
  const dt = new Date(d)
  return dt.toLocaleDateString('es-AR', { day: 'numeric', month: 'short' })
}

onMounted(cargar)
</script>

<style scoped>
.apm { padding: var(--sp-6); max-width: 900px; margin: 0 auto; }
.apm__legacy-banner { display: flex; align-items: center; gap: var(--sp-2); background: #fffbeb; border: 1.5px solid #fcd34d; color: #92400e; border-radius: 10px; padding: .65rem 1rem; font-size: .82rem; text-decoration: none; margin-bottom: var(--sp-4); transition: background .15s; }
.apm__legacy-banner:hover { background: #fef3c7; }
.apm__legacy-cta { margin-left: auto; font-weight: 700; white-space: nowrap; }

/* Header */
.apm__header    { margin-bottom: var(--sp-6); }
.apm__eyebrow {
  display: inline-flex; align-items: center; gap: var(--sp-1);
  font-size: var(--fs-11); font-weight: 700; text-transform: uppercase;
  letter-spacing: .09em; color: var(--c-ink-400); margin-bottom: var(--sp-2);
}
.apm__title { font-size: var(--fs-24); font-weight: 800; color: var(--c-ink-900); margin: 0 0 var(--sp-1); }
.apm__sub   { font-size: var(--fs-14); color: var(--c-ink-500); margin: 0; }

/* Loading / empty */
.apm__loading { display: flex; align-items: center; justify-content: center; padding: 3rem; }
.apm__empty { display: flex; flex-direction: column; align-items: center; gap: var(--sp-3); padding: var(--sp-14) var(--sp-6); text-align: center; color: var(--c-ink-300); }
.apm__empty-ico { opacity: .4; }
.apm__empty-title { font-size: var(--fs-15); font-weight: 700; color: var(--c-ink-600); margin: 0; }
.apm__empty-sub   { font-size: var(--fs-13); color: var(--c-ink-400); margin: 0; max-width: 360px; }

/* Cards */
.apm__cards { display: flex; flex-direction: column; gap: var(--sp-3); }
.apm__card {
  background: var(--c-paper); border: 1px solid var(--c-ink-100);
  border-radius: var(--r-lg); overflow: hidden;
  display: flex; flex-direction: column;
  box-shadow: 0 1px 4px rgba(0,0,0,.04);
  transition: box-shadow .15s, border-color .15s;
}
.apm__card:hover { border-color: var(--c-leaf-300); box-shadow: 0 4px 16px rgba(26,61,46,.08); }

.apm__card-stripe {
  height: 3px;
  background: linear-gradient(90deg, var(--c-leaf-700), var(--c-leaf-500));
}

.apm__card-body { padding: var(--sp-4) var(--sp-5); flex: 1; }

.apm__card-head {
  display: flex; align-items: center; gap: var(--sp-3);
  margin-bottom: var(--sp-2);
}
.apm__card-codigo {
  font-size: var(--fs-15); font-weight: 800;
  color: var(--c-ink-900); font-family: var(--font-mono, monospace);
}
.apm__badge {
  display: inline-flex; align-items: center; gap: 4px;
  font-size: var(--fs-11); font-weight: 700; padding: .2em .65em;
  border-radius: 999px; background: var(--c-leaf-100); color: var(--c-leaf-700);
  text-transform: uppercase; letter-spacing: .04em;
}

.apm__card-meta {
  display: flex; flex-wrap: wrap; gap: var(--sp-1) var(--sp-4);
  font-size: var(--fs-13); color: var(--c-ink-500);
  margin-bottom: var(--sp-3);
}
.apm__card-meta span { display: inline-flex; align-items: center; gap: 4px; }

.apm__peso-box {
  display: flex; gap: var(--sp-6); margin-bottom: var(--sp-3);
  background: var(--c-leaf-50); border: 1px solid var(--c-leaf-100);
  border-radius: var(--r-sm); padding: var(--sp-3) var(--sp-4);
  align-self: flex-start;
}
.apm__peso-item { display: flex; flex-direction: column; gap: 2px; }
.apm__peso-lbl  { font-size: var(--fs-11); font-weight: 700; text-transform: uppercase; letter-spacing: .06em; color: var(--c-leaf-700); }
.apm__peso-val  { font-size: var(--fs-22); font-weight: 800; color: var(--c-leaf-900); line-height: 1; }
.apm__peso-val--secondary { color: var(--c-leaf-700); font-size: var(--fs-16); }
.apm__peso-unit { font-size: var(--fs-12); font-weight: 500; color: var(--c-leaf-500); margin-left: 2px; }

.apm__notas {
  display: inline-flex; align-items: center; gap: var(--sp-1);
  font-size: var(--fs-12); color: var(--c-ink-500);
  background: var(--c-ink-50, #f8fafc); border-radius: var(--r-sm);
  padding: var(--sp-1) var(--sp-3); margin-bottom: var(--sp-2);
}

.apm__plantas-toggle { margin-top: var(--sp-2); }
.apm__plantas-summary {
  display: inline-flex; align-items: center; gap: 4px;
  font-size: var(--fs-12); color: var(--c-ink-500); cursor: pointer;
  font-weight: 600; list-style: none;
}
.apm__plantas-summary:hover { color: var(--c-leaf-700); }
.apm__plantas-list {
  margin-top: var(--sp-2);
  border: 1px solid var(--c-ink-100); border-radius: var(--r-sm);
  overflow: hidden;
}
.apm__planta-row {
  display: flex; justify-content: space-between; align-items: center;
  padding: var(--sp-1) var(--sp-3);
  font-size: var(--fs-12); border-bottom: 1px solid var(--c-ink-50, #f8fafc);
}
.apm__planta-row:last-child { border-bottom: none; }
.apm__planta-nombre { color: var(--c-ink-700); font-weight: 500; }
.apm__planta-peso   { color: var(--c-leaf-700); font-weight: 700; font-size: var(--fs-13); }

.apm__card-actions {
  padding: var(--sp-3) var(--sp-5);
  border-top: 1px solid var(--c-ink-100);
  display: flex; justify-content: flex-end; gap: var(--sp-2);
  background: var(--c-leaf-50);
}
.apm__btn-confirmar {
  display: inline-flex; align-items: center; gap: var(--sp-2);
  background: var(--c-leaf-700); color: #fff; border: none;
  padding: .5rem 1.25rem; border-radius: var(--r-sm);
  font-size: var(--fs-13); font-weight: 700; cursor: pointer;
  transition: background .15s;
}
.apm__btn-confirmar:hover { background: var(--c-leaf-800); }

/* Modal */
.apm-overlay {
  position: fixed; inset: 0; background: rgba(0,0,0,.45);
  display: flex; align-items: center; justify-content: center;
  z-index: 1050; padding: 1rem; backdrop-filter: blur(3px);
}
.apm-modal {
  background: #fff; border-radius: 14px;
  width: 100%; max-width: 440px; max-height: 92vh; overflow-y: auto;
  box-shadow: 0 24px 64px rgba(0,0,0,.18);
}
.apm-modal__hd {
  display: flex; align-items: flex-start; gap: .75rem;
  padding: 1.25rem 1.25rem 1rem; border-bottom: 1px solid #f1f5f9;
}
.apm-modal__ico {
  width: 38px; height: 38px; border-radius: 8px;
  background: var(--c-leaf-100); color: var(--c-leaf-700);
  display: flex; align-items: center; justify-content: center; flex-shrink: 0;
}
.apm-modal__title { font-size: .95rem; font-weight: 700; color: #0f172a; margin: 0 0 2px; }
.apm-modal__sub   { font-size: .78rem; color: #64748b; margin: 0; }
.apm-modal__close {
  margin-left: auto; background: #f8fafc; border: none;
  width: 28px; height: 28px; border-radius: 6px;
  cursor: pointer; display: flex; align-items: center; justify-content: center;
  color: #64748b; flex-shrink: 0; transition: background .15s;
}
.apm-modal__close:hover { background: #e2e8f0; }

.apm-modal__body { padding: 1.25rem; display: flex; flex-direction: column; gap: 1rem; }
.apm-field  { display: flex; flex-direction: column; gap: .3rem; }
.apm-label  { font-size: .72rem; font-weight: 700; color: #475569; text-transform: uppercase; letter-spacing: .05em; }
.apm-req    { color: #ef4444; }
.apm-hint   { font-size: .72rem; color: #94a3b8; }
.apm-input-row { display: flex; }
.apm-input {
  flex: 1; background: #f8fafc; border: 1.5px solid #e2e8f0;
  border-radius: 6px 0 0 6px; padding: .55rem .75rem;
  font-size: .9rem; color: #0f172a; outline: none; transition: border-color .15s;
}
.apm-input:focus { border-color: var(--c-leaf-700); background: #fff; }
.apm-select { border-radius: 6px; appearance: none; -webkit-appearance: none; cursor: pointer; }
.apm-suffix {
  background: #f1f5f9; border: 1.5px solid #e2e8f0; border-left: none;
  padding: .55rem .75rem; font-size: .82rem; font-weight: 600;
  color: #64748b; border-radius: 0 6px 6px 0; white-space: nowrap;
}
.apm-error {
  background: #fef2f2; border: 1px solid #fecaca; color: #dc2626;
  padding: .5rem .75rem; border-radius: 6px; font-size: .82rem;
}
.apm-actions { display: flex; justify-content: flex-end; gap: .5rem; }
.apm-btn-cancel {
  background: transparent; color: #475569; border: 1.5px solid #e2e8f0;
  padding: .5rem 1rem; border-radius: 7px; font-size: .82rem; font-weight: 500; cursor: pointer;
}
.apm-btn-cancel:hover { background: #f8fafc; }
.apm-btn-ok {
  display: inline-flex; align-items: center; gap: .4rem;
  background: var(--c-leaf-700); color: #fff; border: none; border-radius: 7px;
  padding: .5rem 1.1rem; font-size: .82rem; font-weight: 600; cursor: pointer; transition: background .15s;
}
.apm-btn-ok:hover:not(:disabled) { background: var(--c-leaf-800); }
.apm-btn-ok:disabled { opacity: .45; cursor: not-allowed; }

/* Transition */
.apm-fade-enter-active, .apm-fade-leave-active { transition: opacity .2s; }
.apm-fade-enter-from,  .apm-fade-leave-to      { opacity: 0; }
</style>
