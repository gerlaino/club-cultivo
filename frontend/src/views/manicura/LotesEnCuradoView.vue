<template>
  <div class="lv">

    <div class="lv__header">
      <h1 class="lv__title">
        <span class="lv__eyebrow"><Container :size="14" :stroke-width="2" /> Post-cosecha</span>
        Lotes en Curado
      </h1>
      <p class="lv__sub">Registrá la pesada final y cerrá el curado para generar el stock de sede.</p>
    </div>

    <div v-if="loading" class="lv__loading">
      <DsSpinner />
    </div>

    <div v-else-if="!lotes.length" class="lv__empty">
      <div class="lv__empty-ico"><Container :size="40" :stroke-width="1.25" /></div>
      <p class="lv__empty-title">Sin lotes en curado</p>
      <p class="lv__empty-sub">Los lotes que completen la manicura aparecerán aquí.</p>
    </div>

    <div v-else class="lv__cards">
      <div v-for="lote in paginados" :key="lote.id" class="lv__card">
        <div class="lv__card-stripe lv__card-stripe--curado"></div>
        <div class="lv__card-body">
          <div class="lv__card-head">
            <span class="lv__card-codigo">{{ lote.codigo }}</span>
            <span class="lv__badge lv__badge--curado">Curado</span>
          </div>
          <div class="lv__card-meta">
            <span v-if="lote.genetica"><Leaf :size="13" :stroke-width="2" /> {{ lote.genetica.nombre }}</span>
            <span><MapPin :size="13" :stroke-width="2" /> {{ lote.sala?.nombre }}</span>
            <span><Package :size="13" :stroke-width="2" /> {{ lote.plants_count }} plantas</span>
          </div>
        </div>
        <div class="lv__card-actions">
          <RouterLink :to="`/lotes/${lote.id}`" class="lv__btn-secondary">
            <Eye :size="14" :stroke-width="2" /> Ver lote
          </RouterLink>
          <button class="lv__btn-accent" @click="abrirPesada(lote)">
            <Scale :size="14" :stroke-width="2" /> Registrar pesada
          </button>
          <button class="lv__btn-primary" @click="abrirCerrarCurado(lote)">
            <PackagePlus :size="14" :stroke-width="2" /> Cerrar curado
          </button>
        </div>
      </div>
    </div>

    <div v-if="totalPages > 1" class="lv__pager">
      <button class="lv__pager-btn" :disabled="page <= 1" @click="page--">«</button>
      <span class="lv__pager-info">{{ page }} / {{ totalPages }}</span>
      <button class="lv__pager-btn" :disabled="page >= totalPages" @click="page++">»</button>
    </div>

    <!-- Modal pesada -->
    <ModalPesada
      v-model="showPesada"
      :lote="loteSeleccionado"
      tipo-inicial="curado_final"
      @saved="onPesadaGuardada"
    />

    <!-- Wizard cerrar curado -->
    <Teleport to="body">
      <Transition name="cc-fade">
        <div v-if="showWizard" class="cc-overlay" @click.self="showWizard = false">
          <div class="cc-modal">

            <!-- Header -->
            <div class="cc-header">
              <div class="cc-header-ico"><PackagePlus :size="20" :stroke-width="1.75" /></div>
              <div>
                <h2 class="cc-title">Cerrar curado</h2>
                <p class="cc-subtitle">Lote <strong>{{ loteSeleccionado?.codigo }}</strong></p>
              </div>
              <button class="cc-close" @click="showWizard = false"><X :size="18" :stroke-width="2" /></button>
            </div>

            <!-- Steps indicator -->
            <div class="cc-steps">
              <div class="cc-step" :class="{ 'cc-step--active': step === 1, 'cc-step--done': step > 1 }">
                <div class="cc-step-num">{{ step > 1 ? '✓' : '1' }}</div>
                <span>Pesada final</span>
              </div>
              <div class="cc-step-line"></div>
              <div class="cc-step" :class="{ 'cc-step--active': step === 2 }">
                <div class="cc-step-num">2</div>
                <span>Generar stocks</span>
              </div>
            </div>

            <!-- Step 1: Pesada curado final -->
            <div v-if="step === 1" class="cc-body">
              <div class="cc-field">
                <label class="cc-label">Peso curado final (g) <span class="cc-req">*</span></label>
                <input v-model.number="wizard.peso_curado_g" type="number" step="0.1" min="0.1" class="cc-input" placeholder="0.0" autofocus />
              </div>
              <div v-if="wizard.peso_curado_g > 0" class="cc-neto">
                <span>Disponible para distribuir en stocks</span>
                <strong>{{ disponible.toFixed(1) }} g</strong>
              </div>
              <div class="cc-field">
                <label class="cc-label">Notas <span class="cc-opt">opcional</span></label>
                <textarea v-model="wizard.notas" class="cc-textarea" rows="2" placeholder="Observaciones del curado…"></textarea>
              </div>
              <div class="cc-actions">
                <button class="cc-btn-cancel" @click="showWizard = false">Cancelar</button>
                <button class="cc-btn-next" :disabled="!wizard.peso_curado_g" @click="step = 2">
                  Siguiente <ArrowRight :size="15" :stroke-width="2" />
                </button>
              </div>
            </div>

            <!-- Step 2: Stocks -->
            <div v-if="step === 2" class="cc-body">
              <div class="cc-disponible-bar">
                <span class="cc-disponible-label">Disponible</span>
                <span class="cc-disponible-val">{{ disponibleRestante.toFixed(1) }} g</span>
                <span class="cc-disponible-used" :class="{ 'cc-disponible-used--over': totalStocks > disponible }">
                  (usando {{ totalStocks.toFixed(1) }}g)
                </span>
              </div>

              <div v-for="(stock, i) in wizard.stocks" :key="i" class="cc-stock-row">
                <div class="cc-stock-fields">
                  <select v-model="stock.sede_id" class="cc-select">
                    <option value="" disabled>Sede…</option>
                    <option v-for="sede in sedes" :key="sede.id" :value="sede.id">{{ sede.nombre }}</option>
                  </select>
                  <select v-model="stock.forma_producto" class="cc-select">
                    <option value="" disabled>Forma…</option>
                    <option value="flor_seca">Flor seca</option>
                    <option value="hash">Hash</option>
                    <option value="aceite">Aceite</option>
                    <option value="tintura">Tintura</option>
                    <option value="crema">Crema</option>
                    <option value="capsula">Cápsula</option>
                    <option value="prensado">Prensado</option>
                    <option value="otro">Otro</option>
                  </select>
                  <input v-model.number="stock.cantidad" type="number" step="0.1" min="0.1" class="cc-input-sm" placeholder="Cant. (g)" />
                </div>
                <button class="cc-btn-remove" @click="removeStock(i)" :disabled="wizard.stocks.length === 1">
                  <X :size="14" :stroke-width="2" />
                </button>
              </div>

              <button class="cc-btn-add" @click="addStock">
                <Plus :size="14" :stroke-width="2" /> Agregar stock
              </button>

              <div v-if="ccError" class="cc-error">
                <AlertCircle :size="15" :stroke-width="2" /> {{ ccError }}
              </div>

              <div class="cc-actions">
                <button class="cc-btn-cancel" @click="step = 1">Atrás</button>
                <button
                  class="cc-btn-submit"
                  :disabled="!stocksValidos || totalStocks > disponible || !wizard.peso_curado_g || ccSaving"
                  @click="confirmarCierre"
                >
                  <DsSpinner v-if="ccSaving" :size="13" />
                  <PackagePlus v-else :size="14" :stroke-width="2" />
                  Confirmar cierre
                </button>
              </div>
            </div>

          </div>
        </div>
      </Transition>
    </Teleport>

  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import DsSpinner from '../../design-system/components/Spinner.vue'
import { Container, Leaf, MapPin, Package, Scale, Eye, PackagePlus, X, Plus, ArrowRight, AlertCircle } from 'lucide-vue-next'
import { listLotes, listSedes, cerrarCurado } from '../../lib/api.js'
import ModalPesada from '../../components/manicura/ModalPesada.vue'
import { useToast } from '../../composables/useToast.js'

const toast = useToast()
const lotes = ref([])
const sedes = ref([])
const loading = ref(true)

const PER_PAGE   = 10
const page       = ref(1)
const paginados  = computed(() => lotes.value.slice((page.value - 1) * PER_PAGE, page.value * PER_PAGE))
const totalPages = computed(() => Math.max(1, Math.ceil(lotes.value.length / PER_PAGE)))
watch(lotes, () => { page.value = 1 })
const showPesada = ref(false)
const showWizard = ref(false)
const loteSeleccionado = ref(null)
const step = ref(1)
const ccSaving = ref(false)
const ccError = ref('')

const wizard = ref({
  peso_curado_g: null,
  notas: '',
  stocks: [{ sede_id: '', forma_producto: '', cantidad: null }],
})

const disponible = computed(() => wizard.value.peso_curado_g || 0)

const totalStocks = computed(() =>
  wizard.value.stocks.reduce((sum, s) => sum + (s.cantidad || 0), 0)
)

const disponibleRestante = computed(() => disponible.value - totalStocks.value)

const stocksValidos = computed(() =>
  wizard.value.stocks.every(s => s.sede_id && s.forma_producto && s.cantidad > 0)
)

function addStock() {
  wizard.value.stocks.push({ sede_id: '', forma_producto: '', cantidad: null })
}
function removeStock(i) {
  wizard.value.stocks.splice(i, 1)
}

async function cargar() {
  loading.value = true
  try {
    const [lotesRes] = await Promise.all([
      listLotes({ estado: 'curado' }),
    ])
    lotes.value = lotesRes.data
  } catch {
    lotes.value = []
  } finally {
    loading.value = false
  }
}

async function cargarSedes() {
  try {
    const { data } = await listSedes()
    sedes.value = data
  } catch { sedes.value = [] }
}

function abrirPesada(lote) {
  loteSeleccionado.value = lote
  showPesada.value = true
}

function abrirCerrarCurado(lote) {
  loteSeleccionado.value = lote
  step.value = 1
  ccError.value = ''
  wizard.value = {
    peso_curado_g: null,
    notas: '',
    stocks: [{ sede_id: sedes.value[0]?.id || '', forma_producto: 'flor_seca', cantidad: null }],
  }
  showWizard.value = true
}

function onPesadaGuardada() {
  toast.success('Pesada registrada correctamente')
  cargar()
}

async function confirmarCierre() {
  if (!loteSeleccionado.value) return
  ccSaving.value = true
  ccError.value = ''
  try {
    await cerrarCurado(loteSeleccionado.value.id, {
      pesada: {
        fase_origen:  'curado',
        fase_destino: 'finalizado',
        peso_curado_g: wizard.value.peso_curado_g,
        notas: wizard.value.notas || undefined,
      },
      stocks: wizard.value.stocks.map(s => ({
        sede_id: s.sede_id,
        forma_producto: s.forma_producto,
        cantidad: s.cantidad,
        unidad: 'g',
      })),
    })
    toast.success(`Lote ${loteSeleccionado.value.codigo} cerrado. Stock generado.`)
    showWizard.value = false
    cargar()
  } catch (e) {
    ccError.value = e.response?.data?.error || e.response?.data?.errors?.[0] || 'Error al cerrar curado'
  } finally {
    ccSaving.value = false
  }
}

onMounted(() => {
  cargar()
  cargarSedes()
})
</script>

<style scoped>
.lv { padding: 2rem 1.75rem 3rem; max-width: 1000px; margin: 0 auto; }
@media (max-width: 768px) { .lv { padding: 1.25rem 1rem 2rem; } }

.lv__header { margin-bottom: 2rem; }
.lv__eyebrow {
  display: inline-flex; align-items: center; gap: .4rem;
  font-size: var(--fs-12); font-weight: 700; text-transform: uppercase; letter-spacing: .08em;
  color: #6B4FBE; margin-bottom: .25rem;
}
.lv__title { font-size: 1.75rem; font-weight: 800; color: var(--c-ink-900); margin: 0 0 .2rem; letter-spacing: -.03em; display: flex; flex-direction: column; }
.lv__sub { font-size: var(--fs-14); color: var(--c-ink-500); margin: 0; }

.lv__loading { display: flex; align-items: center; justify-content: center; min-height: calc(100vh - 56px); }

.lv__empty { text-align: center; padding: 4rem 2rem; }
.lv__empty-ico { color: var(--c-ink-300); margin-bottom: 1rem; display: flex; justify-content: center; }
.lv__empty-title { font-size: var(--fs-16); font-weight: 700; color: var(--c-ink-700); margin: 0 0 .4rem; }
.lv__empty-sub { font-size: var(--fs-14); color: var(--c-ink-400); margin: 0; }

.lv__cards { display: flex; flex-direction: column; gap: .75rem; }
.lv__card {
  display: flex; align-items: stretch;
  background: var(--c-paper);
  border: 1px solid var(--c-ink-200);
  border-radius: var(--r-xl);
  overflow: hidden;
  transition: box-shadow var(--t-fast);
}
.lv__card:hover { box-shadow: 0 4px 20px rgba(0,0,0,.07); }
.lv__card-stripe { width: 4px; flex-shrink: 0; }
.lv__card-stripe--curado { background: #6B4FBE; }
.lv__card-body { flex: 1; padding: 1rem 1.25rem; min-width: 0; }
.lv__card-head { display: flex; align-items: center; gap: .75rem; margin-bottom: .5rem; }
.lv__card-codigo { font-size: var(--fs-16); font-weight: 800; color: var(--c-ink-900); font-family: var(--font-mono); }
.lv__badge { font-size: 11px; font-weight: 700; padding: 2px 10px; border-radius: 999px; text-transform: uppercase; letter-spacing: .04em; }
.lv__badge--curado { background: rgba(107,79,190,.1); color: #6B4FBE; border: 1px solid rgba(107,79,190,.25); }
.lv__card-meta { display: flex; flex-wrap: wrap; gap: .5rem 1.25rem; font-size: var(--fs-13); color: var(--c-ink-500); }
.lv__card-meta span { display: inline-flex; align-items: center; gap: .3rem; }

.lv__card-actions {
  display: flex; flex-direction: column; gap: .5rem;
  justify-content: center; padding: 1rem 1.25rem;
  border-left: 1px solid var(--c-ink-100); flex-shrink: 0;
}
@media (max-width: 640px) {
  .lv__card { flex-direction: column; }
  .lv__card-stripe { width: 100%; height: 4px; }
  .lv__card-actions { border-left: none; border-top: 1px solid var(--c-ink-100); flex-direction: row; flex-wrap: wrap; }
}

.lv__btn-primary {
  display: inline-flex; align-items: center; gap: .35rem;
  background: #6B4FBE; color: #fff;
  border: none; padding: .5rem .875rem;
  border-radius: var(--r-md); font-size: var(--fs-13); font-weight: 600;
  cursor: pointer; white-space: nowrap; transition: opacity var(--t-fast);
}
.lv__btn-primary:hover { opacity: .88; }
.lv__btn-accent {
  display: inline-flex; align-items: center; gap: .35rem;
  background: rgba(107,79,190,.12); color: #6B4FBE;
  border: 1.5px solid rgba(107,79,190,.3);
  padding: .5rem .875rem;
  border-radius: var(--r-md); font-size: var(--fs-13); font-weight: 600;
  cursor: pointer; white-space: nowrap; transition: all var(--t-fast);
}
.lv__btn-accent:hover { background: rgba(107,79,190,.2); }
.lv__btn-secondary {
  display: inline-flex; align-items: center; gap: .35rem;
  background: transparent; color: var(--c-ink-600);
  border: 1.5px solid var(--c-ink-200);
  padding: .5rem .875rem;
  border-radius: var(--r-md); font-size: var(--fs-13); font-weight: 500;
  cursor: pointer; white-space: nowrap; transition: all var(--t-fast);
  text-decoration: none;
}
.lv__btn-secondary:hover { background: var(--c-ink-50); border-color: var(--c-ink-300); color: var(--c-ink-900); }

/* ── Wizard ── */
.cc-overlay {
  position: fixed; inset: 0;
  background: rgba(0,0,0,.45);
  z-index: 1050;
  display: flex; align-items: center; justify-content: center;
  padding: var(--sp-4);
  backdrop-filter: blur(3px);
}
.cc-modal {
  background: var(--c-paper);
  border-radius: var(--r-xl);
  width: 100%; max-width: 540px;
  box-shadow: 0 24px 64px rgba(0,0,0,.18);
  overflow: hidden;
}
.cc-header {
  display: flex; align-items: center; gap: var(--sp-3);
  padding: var(--sp-5) var(--sp-6);
  border-bottom: 1px solid var(--c-ink-200);
}
.cc-header-ico {
  width: 40px; height: 40px; border-radius: var(--r-lg);
  background: rgba(107,79,190,.1); color: #6B4FBE;
  display: flex; align-items: center; justify-content: center; flex-shrink: 0;
}
.cc-title { font-size: var(--fs-16); font-weight: 700; color: var(--c-ink-900); margin: 0; }
.cc-subtitle { font-size: var(--fs-13); color: var(--c-ink-500); margin: 2px 0 0; }
.cc-close {
  margin-left: auto; background: none; border: none;
  color: var(--c-ink-400); cursor: pointer; padding: var(--sp-1);
  border-radius: var(--r-sm); display: flex; align-items: center;
  transition: color var(--t-fast), background var(--t-fast);
}
.cc-close:hover { color: var(--c-ink-900); background: var(--c-ink-100); }

.cc-steps {
  display: flex; align-items: center;
  padding: var(--sp-4) var(--sp-6);
  background: var(--c-ink-50);
  border-bottom: 1px solid var(--c-ink-100);
  gap: var(--sp-3);
}
.cc-step { display: flex; align-items: center; gap: var(--sp-2); }
.cc-step-num {
  width: 24px; height: 24px; border-radius: 50%;
  background: var(--c-ink-200); color: var(--c-ink-600);
  font-size: var(--fs-12); font-weight: 700;
  display: flex; align-items: center; justify-content: center; flex-shrink: 0;
}
.cc-step--active .cc-step-num { background: #6B4FBE; color: #fff; }
.cc-step--done .cc-step-num { background: #15803d; color: #fff; }
.cc-step span { font-size: var(--fs-13); color: var(--c-ink-500); }
.cc-step--active span { color: var(--c-ink-900); font-weight: 600; }
.cc-step-line { flex: 1; height: 1px; background: var(--c-ink-200); }

.cc-body { padding: var(--sp-5) var(--sp-6) var(--sp-6); display: flex; flex-direction: column; gap: var(--sp-4); }
.cc-row { display: grid; grid-template-columns: 1fr 1fr; gap: var(--sp-4); }
@media (max-width: 480px) { .cc-row { grid-template-columns: 1fr; } }

.cc-field { display: flex; flex-direction: column; gap: var(--sp-1); }
.cc-label { font-size: var(--fs-13); font-weight: 600; color: var(--c-ink-700); }
.cc-opt { font-weight: 400; color: var(--c-ink-400); }
.cc-req { color: var(--c-rust-500); }
.cc-input, .cc-select, .cc-textarea {
  width: 100%; box-sizing: border-box;
  background: var(--c-ink-50); border: 1.5px solid var(--c-ink-200);
  border-radius: var(--r-md); padding: 9px 12px;
  font-size: var(--fs-14); color: var(--c-ink-900);
  transition: border-color var(--t-fast); font-family: inherit;
}
.cc-input:focus, .cc-select:focus { outline: none; border-color: #6B4FBE; background: var(--c-paper); }

.cc-neto {
  display: flex; align-items: center; justify-content: space-between;
  background: rgba(107,79,190,.07);
  border: 1px dashed rgba(107,79,190,.3);
  border-radius: var(--r-md); padding: var(--sp-3) var(--sp-4);
  font-size: var(--fs-14); color: var(--c-ink-600);
}
.cc-neto strong { font-size: var(--fs-18); font-weight: 800; color: #6B4FBE; font-variant-numeric: tabular-nums; }

.cc-disponible-bar {
  display: flex; align-items: center; gap: var(--sp-2);
  background: var(--c-ink-50); border-radius: var(--r-md); padding: var(--sp-3) var(--sp-4);
  font-size: var(--fs-14);
}
.cc-disponible-label { color: var(--c-ink-600); }
.cc-disponible-val { font-weight: 800; color: #6B4FBE; margin-left: auto; font-variant-numeric: tabular-nums; }
.cc-disponible-used { font-size: var(--fs-12); color: var(--c-ink-400); }
.cc-disponible-used--over { color: var(--c-rust-600); font-weight: 700; }

.cc-stock-row {
  display: flex; align-items: center; gap: var(--sp-2);
  background: var(--c-ink-50); border-radius: var(--r-md); padding: var(--sp-3);
}
.cc-stock-fields { display: flex; flex: 1; gap: var(--sp-2); flex-wrap: wrap; }
.cc-select { min-width: 120px; flex: 1; }
.cc-input-sm {
  width: 100px; flex-shrink: 0;
  background: var(--c-paper); border: 1.5px solid var(--c-ink-200);
  border-radius: var(--r-md); padding: 8px 10px;
  font-size: var(--fs-14); color: var(--c-ink-900); font-family: inherit;
}
.cc-input-sm:focus { outline: none; border-color: #6B4FBE; }
.cc-btn-remove {
  background: none; border: none; color: var(--c-ink-400);
  cursor: pointer; padding: var(--sp-1); border-radius: var(--r-sm);
  display: flex; align-items: center; transition: color var(--t-fast);
  flex-shrink: 0;
}
.cc-btn-remove:hover:not(:disabled) { color: var(--c-rust-600); }
.cc-btn-remove:disabled { opacity: .4; cursor: not-allowed; }

.cc-btn-add {
  display: inline-flex; align-items: center; gap: var(--sp-2);
  background: none; border: 1.5px dashed var(--c-ink-200);
  color: var(--c-ink-500); padding: var(--sp-2) var(--sp-4);
  border-radius: var(--r-md); font-size: var(--fs-13);
  cursor: pointer; transition: all var(--t-fast); width: 100%; justify-content: center;
}
.cc-btn-add:hover { border-color: #6B4FBE; color: #6B4FBE; }

.cc-error {
  display: flex; align-items: center; gap: var(--sp-2);
  background: var(--c-rust-50); border: 1px solid var(--c-rust-200);
  border-radius: var(--r-md); padding: var(--sp-3) var(--sp-4);
  font-size: var(--fs-13); color: var(--c-rust-700);
}

.cc-actions {
  display: flex; gap: var(--sp-3); justify-content: flex-end;
  padding-top: var(--sp-2); border-top: 1px solid var(--c-ink-100);
}
.cc-btn-cancel {
  background: transparent; border: 1.5px solid var(--c-ink-200);
  color: var(--c-ink-600); padding: var(--sp-2) var(--sp-5);
  border-radius: var(--r-md); font-size: var(--fs-14); font-weight: 500;
  cursor: pointer; transition: all var(--t-fast);
}
.cc-btn-cancel:hover { background: var(--c-ink-50); border-color: var(--c-ink-300); }
.cc-btn-next {
  display: inline-flex; align-items: center; gap: var(--sp-2);
  background: var(--c-ink-800); color: #fff;
  border: none; padding: var(--sp-2) var(--sp-5);
  border-radius: var(--r-md); font-size: var(--fs-14); font-weight: 600;
  cursor: pointer; transition: opacity var(--t-fast);
}
.cc-btn-next:hover:not(:disabled) { opacity: .88; }
.cc-btn-next:disabled { opacity: .4; cursor: not-allowed; }
.cc-btn-submit {
  display: inline-flex; align-items: center; gap: var(--sp-2);
  background: #6B4FBE; color: #fff;
  border: none; padding: var(--sp-2) var(--sp-5);
  border-radius: var(--r-md); font-size: var(--fs-14); font-weight: 600;
  cursor: pointer; transition: opacity var(--t-fast);
}
.cc-btn-submit:hover:not(:disabled) { opacity: .88; }
.cc-btn-submit:disabled { opacity: .4; cursor: not-allowed; }


.cc-fade-enter-active, .cc-fade-leave-active { transition: opacity .2s; }
.cc-fade-enter-from, .cc-fade-leave-to { opacity: 0; }

.lv__pager { display: flex; align-items: center; justify-content: center; gap: .75rem; padding: 1.25rem 0 .5rem; }
.lv__pager-btn { background: #fff; border: 1.5px solid var(--c-ink-200); color: var(--c-ink-700); padding: .35rem .75rem; border-radius: 7px; font-size: .82rem; font-weight: 600; cursor: pointer; transition: all .15s; }
.lv__pager-btn:hover:not(:disabled) { border-color: #6B4FBE; color: #6B4FBE; }
.lv__pager-btn:disabled { opacity: .4; cursor: not-allowed; }
.lv__pager-info { font-size: .82rem; color: var(--c-ink-500); font-weight: 600; min-width: 50px; text-align: center; }
</style>
