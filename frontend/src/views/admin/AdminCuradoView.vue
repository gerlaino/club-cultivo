<template>
  <div class="cv">

    <div class="cv__header">
      <div class="cv__eyebrow">
        <Container :size="14" :stroke-width="2" />
        Administración
      </div>
      <h1 class="cv__title">Lotes en Curado</h1>
      <p class="cv__sub">Registrá pesadas de curado y cerrá los lotes para generar stock en sede.</p>
    </div>

    <div v-if="loading" class="cv__loading">
      <DsSpinner />
    </div>

    <div v-else-if="!lotes.length" class="cv__empty">
      <div class="cv__empty-ico"><Container :size="40" :stroke-width="1.25" /></div>
      <p class="cv__empty-title">Sin lotes en curado</p>
      <p class="cv__empty-sub">Los lotes aprobados tras la manicura aparecerán aquí.</p>
    </div>

    <div v-else class="cv__cards">
      <div v-for="lote in lotes" :key="lote.id" class="cv__card">
        <div class="cv__card-stripe"></div>
        <div class="cv__card-body">
          <div class="cv__card-head">
            <span class="cv__card-codigo">{{ lote.codigo }}</span>
            <span class="cv__badge">Curado</span>
          </div>
          <div class="cv__card-meta">
            <span v-if="lote.genetica"><Leaf :size="13" :stroke-width="2" /> {{ lote.genetica.nombre }}</span>
            <span><MapPin :size="13" :stroke-width="2" /> {{ lote.sala?.nombre }}</span>
            <span><Package :size="13" :stroke-width="2" /> {{ lote.plants_count }} plantas</span>
          </div>
        </div>
        <div class="cv__card-actions">
          <RouterLink :to="`/lotes/${lote.id}`" class="cv__btn-secondary">
            <Eye :size="14" :stroke-width="2" /> Ver lote
          </RouterLink>
          <button class="cv__btn-accent" @click="abrirPesada(lote)">
            <Scale :size="14" :stroke-width="2" /> Pesada
          </button>
          <button class="cv__btn-primary" @click="abrirCerrar(lote)">
            <PackagePlus :size="14" :stroke-width="2" /> Cerrar curado
          </button>
        </div>
      </div>
    </div>

    <!-- Modal pesada curado -->
    <ModalPesada
      v-model="showPesada"
      :lote="loteSeleccionado"
      @saved="onPesadaGuardada"
    />

    <!-- Modal asignación de sede post-cierre -->
    <ModalAsignacionStock
      v-if="showAsignacion"
      :stocks="stocksPendientes"
      @asignado="onAsignado"
      @close="onAsignacionCerrada"
    />

    <!-- Wizard cerrar curado -->
    <Teleport to="body">
      <Transition name="cc-fade">
        <div v-if="showWizard" class="cc-overlay" @click.self="showWizard = false">
          <div class="cc-modal">

            <div class="cc-header">
              <div class="cc-header-ico"><PackagePlus :size="20" :stroke-width="1.75" /></div>
              <div>
                <h2 class="cc-title">Cerrar curado</h2>
                <p class="cc-subtitle">Lote <strong>{{ loteSeleccionado?.codigo }}</strong></p>
              </div>
              <button class="cc-close" @click="showWizard = false">
                <X :size="18" :stroke-width="2" />
              </button>
            </div>

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

            <!-- Step 1 -->
            <div v-if="step === 1" class="cc-body">
              <div class="cc-field">
                <label class="cc-label">Peso curado final (g) <span class="cc-req">*</span></label>
                <input v-model.number="wizard.peso_curado_g" type="number" step="0.1" min="0.1" class="cc-input" placeholder="0.0" autofocus />
              </div>
              <div v-if="wizard.peso_curado_g > 0" class="cc-neto">
                <span>Disponible para stocks</span>
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

            <!-- Step 2 -->
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
                  <DsSpinner v-if="ccSaving" :size="14" />
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
import { listLotes, cerrarCurado } from '../../lib/api.js'
import ModalPesada from '../../components/manicura/ModalPesada.vue'
import ModalAsignacionStock from '../../components/stocks/ModalAsignacionStock.vue'
import { useToast } from '../../composables/useToast.js'

const toast = useToast()
const lotes = ref([])
const loading = ref(true)
const showPesada = ref(false)
const showWizard = ref(false)
const showAsignacion = ref(false)
const stocksPendientes = ref([])
const loteSeleccionado = ref(null)
const step = ref(1)
const ccSaving = ref(false)
const ccError = ref('')

const wizard = ref({
  peso_curado_g: null,
  notas: '',
  stocks: [{ forma_producto: 'flor_seca', cantidad: null }],
})

const disponible = computed(() => wizard.value.peso_curado_g || 0)
const totalStocks = computed(() => wizard.value.stocks.reduce((s, st) => s + (st.cantidad || 0), 0))
const disponibleRestante = computed(() => disponible.value - totalStocks.value)
const stocksValidos = computed(() => wizard.value.stocks.every(s => s.forma_producto && s.cantidad > 0))

function addStock() { wizard.value.stocks.push({ forma_producto: '', cantidad: null }) }
function removeStock(i) { wizard.value.stocks.splice(i, 1) }

async function cargar() {
  loading.value = true
  try {
    const { data } = await listLotes({ estado: 'curado' })
    lotes.value = data
  } catch {
    lotes.value = []
  } finally {
    loading.value = false
  }
}

function abrirPesada(lote) {
  loteSeleccionado.value = lote
  showPesada.value = true
}

function abrirCerrar(lote) {
  loteSeleccionado.value = lote
  step.value = 1
  ccError.value = ''
  wizard.value = {
    peso_curado_g: null,
    notas: '',
    stocks: [{ forma_producto: 'flor_seca', cantidad: null }],
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
    const { data } = await cerrarCurado(loteSeleccionado.value.id, {
      pesada: {
        fase_origen:   'curado',
        fase_destino:  'finalizado',
        peso_curado_g: wizard.value.peso_curado_g,
        notas:         wizard.value.notas || undefined,
      },
      stocks: wizard.value.stocks.map(s => ({
        forma_producto: s.forma_producto,
        cantidad:      s.cantidad,
        unidad:        'g',
      })),
    })
    showWizard.value = false
    cargar()
    // Abrir modal de asignación de sede
    stocksPendientes.value = data.stocks || []
    if (stocksPendientes.value.length) {
      showAsignacion.value = true
    } else {
      toast.success(`Lote ${loteSeleccionado.value.codigo} cerrado. Stock generado.`)
    }
  } catch (e) {
    ccError.value = e.response?.data?.error || e.response?.data?.errors?.[0] || 'Error al cerrar curado'
  } finally {
    ccSaving.value = false
  }
}

function onAsignado(stocks) {
  showAsignacion.value = false
  toast.success(`Stock asignado correctamente (${stocks.length} item${stocks.length !== 1 ? 's' : ''})`)
}

function onAsignacionCerrada() {
  showAsignacion.value = false
  toast.success('Stock creado como pendiente de asignación')
}

onMounted(cargar)
</script>

<style scoped>
.cv { padding: 2rem 1.75rem 3rem; max-width: 1000px; margin: 0 auto; }
@media (max-width: 768px) { .cv { padding: 1.25rem 1rem 2rem; } }

.cv__header { margin-bottom: 2rem; }
.cv__eyebrow {
  display: inline-flex; align-items: center; gap: .4rem;
  font-size: var(--fs-12); font-weight: 700; text-transform: uppercase; letter-spacing: .08em;
  color: var(--c-role-admin); margin-bottom: .4rem;
}
.cv__title { font-size: 1.75rem; font-weight: 800; color: var(--c-ink-900); margin: 0 0 .2rem; letter-spacing: -.03em; }
.cv__sub { font-size: var(--fs-14); color: var(--c-ink-500); margin: 0; }

.cv__loading { display: flex; align-items: center; justify-content: center; min-height: calc(100vh - 56px); }

.cv__empty { text-align: center; padding: 4rem 2rem; }
.cv__empty-ico { color: var(--c-ink-300); margin-bottom: 1rem; display: flex; justify-content: center; }
.cv__empty-title { font-size: var(--fs-16); font-weight: 700; color: var(--c-ink-700); margin: 0 0 .4rem; }
.cv__empty-sub { font-size: var(--fs-14); color: var(--c-ink-500); margin: 0; }

.cv__cards { display: flex; flex-direction: column; gap: .75rem; }
.cv__card {
  display: flex; align-items: stretch;
  background: var(--c-paper); border: 1px solid var(--c-ink-200);
  border-radius: var(--r-xl); overflow: hidden; transition: box-shadow var(--t-fast);
}
.cv__card:hover { box-shadow: 0 4px 20px rgba(0,0,0,.07); }
.cv__card-stripe { width: 4px; flex-shrink: 0; background: var(--c-leaf-500); }
.cv__card-body { flex: 1; padding: 1rem 1.25rem; min-width: 0; }
.cv__card-head { display: flex; align-items: center; gap: .75rem; margin-bottom: .5rem; }
.cv__card-codigo { font-size: var(--fs-16); font-weight: 800; color: var(--c-ink-900); font-family: var(--font-mono); }
.cv__badge { font-size: 11px; font-weight: 700; padding: 2px 10px; border-radius: 999px; text-transform: uppercase; letter-spacing: .04em; background: var(--c-leaf-100); color: var(--c-leaf-700); border: 1px solid #c6ddc8; }
.cv__card-meta { display: flex; flex-wrap: wrap; gap: .5rem 1.25rem; font-size: var(--fs-13); color: var(--c-ink-500); }
.cv__card-meta span { display: inline-flex; align-items: center; gap: .3rem; }
.cv__card-actions {
  display: flex; flex-direction: column; gap: .5rem;
  justify-content: center; padding: 1rem 1.25rem;
  border-left: 1px solid var(--c-ink-100); flex-shrink: 0;
}
@media (max-width: 600px) {
  .cv__card { flex-direction: column; }
  .cv__card-stripe { width: 100%; height: 4px; }
  .cv__card-actions { border-left: none; border-top: 1px solid var(--c-ink-100); flex-direction: row; flex-wrap: wrap; }
}

.cv__btn-secondary {
  display: inline-flex; align-items: center; gap: .35rem;
  background: transparent; color: var(--c-ink-600);
  border: 1.5px solid var(--c-ink-200); padding: .5rem .875rem;
  border-radius: var(--r-md); font-size: var(--fs-13); font-weight: 500;
  cursor: pointer; white-space: nowrap; transition: all var(--t-fast); text-decoration: none;
}
.cv__btn-secondary:hover { background: var(--c-ink-100); border-color: var(--c-ink-300); color: var(--c-ink-900); }
.cv__btn-accent {
  display: inline-flex; align-items: center; gap: .35rem;
  background: transparent; color: var(--c-leaf-700);
  border: 1.5px solid var(--c-leaf-300); padding: .5rem .875rem;
  border-radius: var(--r-md); font-size: var(--fs-13); font-weight: 600;
  cursor: pointer; white-space: nowrap; transition: all var(--t-fast);
}
.cv__btn-accent:hover { background: var(--c-leaf-100); }
.cv__btn-primary {
  display: inline-flex; align-items: center; gap: .35rem;
  background: var(--c-leaf-600); color: #fff;
  border: none; padding: .5rem .875rem;
  border-radius: var(--r-md); font-size: var(--fs-13); font-weight: 600;
  cursor: pointer; white-space: nowrap; transition: opacity var(--t-fast);
}
.cv__btn-primary:hover { opacity: .88; }

/* Wizard */
.cc-overlay {
  position: fixed; inset: 0; background: rgba(0,0,0,.45); z-index: 1050;
  display: flex; align-items: center; justify-content: center;
  padding: var(--sp-4); backdrop-filter: blur(3px);
}
.cc-modal {
  background: var(--c-paper); border-radius: var(--r-xl);
  width: 100%; max-width: 520px;
  box-shadow: 0 24px 64px rgba(0,0,0,.18); overflow: hidden;
}
.cc-header {
  display: flex; align-items: center; gap: var(--sp-3);
  padding: var(--sp-5) var(--sp-6); border-bottom: 1px solid var(--c-ink-200);
}
.cc-header-ico {
  width: 40px; height: 40px; border-radius: var(--r-lg);
  background: var(--c-leaf-100); color: var(--c-leaf-700);
  display: flex; align-items: center; justify-content: center; flex-shrink: 0;
}
.cc-title { font-size: var(--fs-16); font-weight: 700; color: var(--c-ink-900); margin: 0; }
.cc-subtitle { font-size: var(--fs-13); color: var(--c-ink-500); margin: 2px 0 0; }
.cc-close {
  margin-left: auto; background: none; border: none;
  color: var(--c-ink-400); cursor: pointer; padding: var(--sp-1);
  border-radius: var(--r-sm); display: flex; align-items: center;
  transition: color var(--t-fast), background var(--t-fast); flex-shrink: 0;
}
.cc-close:hover { color: var(--c-ink-900); background: var(--c-ink-100); }

.cc-steps {
  display: flex; align-items: center; gap: var(--sp-3);
  padding: var(--sp-4) var(--sp-6); border-bottom: 1px solid var(--c-ink-100);
}
.cc-step { display: flex; align-items: center; gap: var(--sp-2); font-size: var(--fs-13); color: var(--c-ink-400); }
.cc-step-num {
  width: 24px; height: 24px; border-radius: 50%; background: var(--c-ink-200);
  display: flex; align-items: center; justify-content: center;
  font-size: 11px; font-weight: 700; color: var(--c-ink-600);
}
.cc-step--active .cc-step-num { background: var(--c-leaf-600); color: #fff; }
.cc-step--active { color: var(--c-ink-900); font-weight: 600; }
.cc-step--done .cc-step-num { background: var(--c-leaf-600); color: #fff; }
.cc-step-line { flex: 1; height: 1px; background: var(--c-ink-200); }

.cc-body { padding: var(--sp-5) var(--sp-6) var(--sp-6); display: flex; flex-direction: column; gap: var(--sp-4); }
.cc-field { display: flex; flex-direction: column; gap: var(--sp-1); }
.cc-label { font-size: var(--fs-13); font-weight: 600; color: var(--c-ink-700); }
.cc-req { color: var(--c-rust-600); }
.cc-opt { font-weight: 400; color: var(--c-ink-500); }
.cc-input, .cc-textarea {
  width: 100%; box-sizing: border-box;
  background: var(--c-ink-100); border: 1.5px solid var(--c-ink-200);
  border-radius: var(--r-md); padding: 9px 12px;
  font-size: var(--fs-14); color: var(--c-ink-900); transition: border-color var(--t-fast); font-family: inherit;
}
.cc-input:focus, .cc-textarea:focus { outline: none; border-color: var(--c-leaf-600); background: var(--c-paper); }
.cc-textarea { resize: vertical; min-height: 60px; }
.cc-neto {
  display: flex; align-items: center; justify-content: space-between;
  background: var(--c-leaf-100); border: 1px solid var(--c-leaf-300);
  border-radius: var(--r-md); padding: var(--sp-3) var(--sp-4);
  font-size: var(--fs-13); color: var(--c-leaf-700);
}
.cc-neto strong { font-size: var(--fs-16); }

.cc-disponible-bar {
  display: flex; align-items: center; gap: var(--sp-2);
  background: var(--c-ink-100); border-radius: var(--r-md); padding: var(--sp-3) var(--sp-4);
  font-size: var(--fs-13);
}
.cc-disponible-label { color: var(--c-ink-500); flex: 1; }
.cc-disponible-val { font-size: var(--fs-16); font-weight: 800; color: var(--c-leaf-700); }
.cc-disponible-used { font-size: var(--fs-12); color: var(--c-ink-400); }
.cc-disponible-used--over { color: var(--c-rust-600); font-weight: 600; }

.cc-stock-row { display: flex; align-items: center; gap: var(--sp-2); }
.cc-stock-fields { display: flex; flex: 1; gap: var(--sp-2); flex-wrap: wrap; }
.cc-select, .cc-input-sm {
  background: var(--c-ink-100); border: 1.5px solid var(--c-ink-200);
  border-radius: var(--r-md); padding: 7px 10px;
  font-size: var(--fs-13); color: var(--c-ink-900); transition: border-color var(--t-fast); font-family: inherit;
}
.cc-select { flex: 1; min-width: 100px; cursor: pointer; }
.cc-input-sm { width: 90px; flex-shrink: 0; }
.cc-select:focus, .cc-input-sm:focus { outline: none; border-color: var(--c-leaf-600); background: var(--c-paper); }
.cc-btn-remove {
  background: none; border: none; color: var(--c-ink-400); cursor: pointer; padding: var(--sp-2);
  border-radius: var(--r-sm); display: flex; align-items: center; transition: color var(--t-fast), background var(--t-fast);
}
.cc-btn-remove:hover:not(:disabled) { color: var(--c-rust-600); background: var(--c-rust-100); }
.cc-btn-remove:disabled { opacity: .3; cursor: not-allowed; }
.cc-btn-add {
  display: inline-flex; align-items: center; gap: var(--sp-1);
  background: none; border: 1.5px dashed var(--c-ink-300);
  color: var(--c-ink-500); padding: var(--sp-2) var(--sp-4);
  border-radius: var(--r-md); font-size: var(--fs-13); font-weight: 500;
  cursor: pointer; transition: all var(--t-fast); width: 100%;
}
.cc-btn-add:hover { border-color: var(--c-leaf-500); color: var(--c-leaf-700); background: var(--c-leaf-100); }

.cc-error {
  display: flex; align-items: center; gap: var(--sp-2);
  background: var(--c-rust-100); border: 1px solid #fca5a5;
  border-radius: var(--r-md); padding: var(--sp-3) var(--sp-4);
  font-size: var(--fs-13); color: var(--c-rust-600);
}
.cc-actions {
  display: flex; gap: var(--sp-3); justify-content: flex-end;
  padding-top: var(--sp-2); border-top: 1px solid var(--c-ink-100);
}
.cc-btn-cancel {
  background: transparent; border: 1.5px solid var(--c-ink-200);
  color: var(--c-ink-600); padding: var(--sp-2) var(--sp-5);
  border-radius: var(--r-md); font-size: var(--fs-14); font-weight: 500; cursor: pointer; transition: all var(--t-fast);
}
.cc-btn-cancel:hover { background: var(--c-ink-100); }
.cc-btn-next, .cc-btn-submit {
  display: flex; align-items: center; gap: var(--sp-2);
  background: var(--c-leaf-600); color: #fff;
  border: none; padding: var(--sp-2) var(--sp-5);
  border-radius: var(--r-md); font-size: var(--fs-14); font-weight: 600;
  cursor: pointer; transition: opacity var(--t-fast);
}
.cc-btn-next:hover:not(:disabled), .cc-btn-submit:hover:not(:disabled) { opacity: .88; }
.cc-btn-next:disabled, .cc-btn-submit:disabled { opacity: .5; cursor: not-allowed; }

.cc-fade-enter-active, .cc-fade-leave-active { transition: opacity .2s; }
.cc-fade-enter-from, .cc-fade-leave-to { opacity: 0; }
</style>
