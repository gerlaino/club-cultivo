<template>
  <div class="mnl">

    <div v-if="loading" class="mnl__loading">
      <div class="mnl__spinner"></div>
    </div>

    <template v-else-if="lote">

      <!-- Back -->
      <RouterLink to="/mnc/pendientes" class="mnl__back">
        <ChevronLeft :size="15" :stroke-width="2" /> Cosechas pendientes
      </RouterLink>

      <!-- Header -->
      <div class="mnl__header">
        <div>
          <h1 class="mnl__title">{{ lote.codigo }}</h1>
          <p class="mnl__sub">{{ lote.genetica?.nombre }} · {{ lote.sala?.nombre }}</p>
        </div>
        <div class="mnl__header-actions">
          <span class="mnl__badge" :class="lote.estado === 'secado' ? 'mnl__badge--secado' : 'mnl__badge--pendiente'">
            {{ lote.estado === 'secado' ? 'Secado' : 'Pdte. aprobación' }}
          </span>
          <button v-if="lote.estado === 'secado'" class="mnl__btn-primary" @click="abrirModal">
            <Scale :size="14" :stroke-width="2" /> Registrar por lote
          </button>
        </div>
      </div>

      <!-- Waiting banner -->
      <div v-if="lote.estado === 'manicura_pendiente'" class="mnl__waiting">
        <CheckCircle :size="15" :stroke-width="1.75" />
        Enviado para aprobación — el admin revisará este lote antes de pasar a curado.
      </div>

      <!-- KPIs -->
      <div class="mnl__kpis">
        <div class="mnl__kpi">
          <div class="mnl__kpi-icon mnl__kpi-icon--green"><Scale :size="18" :stroke-width="1.5" /></div>
          <div>
            <div class="mnl__kpi-val">{{ pesadas }}<span class="mnl__kpi-of">/{{ plantas.length }}</span></div>
            <div class="mnl__kpi-lbl">Pesadas</div>
          </div>
        </div>
        <div class="mnl__kpi">
          <div class="mnl__kpi-icon mnl__kpi-icon--blue"><Package :size="18" :stroke-width="1.5" /></div>
          <div>
            <div class="mnl__kpi-val">{{ totalGramos }}<span class="mnl__kpi-of">g</span></div>
            <div class="mnl__kpi-lbl">Total registrado</div>
          </div>
        </div>
        <div class="mnl__kpi">
          <div class="mnl__kpi-icon" :class="plantas.length - pesadas > 0 ? 'mnl__kpi-icon--orange' : 'mnl__kpi-icon--gray'">
            <Leaf :size="18" :stroke-width="1.5" />
          </div>
          <div>
            <div class="mnl__kpi-val" :class="{ 'mnl__kpi-val--warn': plantas.length - pesadas > 0 }">{{ plantas.length - pesadas }}</div>
            <div class="mnl__kpi-lbl">Sin pesar</div>
          </div>
        </div>
      </div>

      <!-- Plant list -->
      <div class="mnl__section">
        <h2 class="mnl__section-title">
          <Leaf :size="13" :stroke-width="2" /> Plantas del lote
        </h2>
        <div class="mnl__list">
          <RouterLink
            v-for="(planta, i) in plantas"
            :key="planta.id"
            :to="`/plantas/${planta.id}`"
            class="mnl__row"
          >
            <div class="mnl__row-dot" :class="plantWeights[planta.id] > 0 ? 'mnl__dot--done' : 'mnl__dot--empty'"></div>
            <div class="mnl__row-num">{{ String(i + 1).padStart(2, '0') }}</div>
            <div class="mnl__row-info">
              <span class="mnl__row-nombre">{{ planta.nombre || `Planta #${planta.id}` }}</span>
              <span class="mnl__row-sep">·</span>
              <span class="mnl__row-qr">{{ planta.codigo_qr }}</span>
            </div>
            <span class="mnl__peso" :class="plantWeights[planta.id] > 0 ? 'mnl__peso--done' : 'mnl__peso--empty'">
              {{ plantWeights[planta.id] > 0 ? `${plantWeights[planta.id]}g` : '—' }}
            </span>
            <ChevronRight :size="14" class="mnl__row-arrow" />
          </RouterLink>
        </div>
      </div>

      <!-- Submit footer (per-plant flow) -->
      <div v-if="lote.estado === 'secado' && pesadas > 0" class="mnl__footer">
        <p class="mnl__footer-hint">
          {{ pesadas }} planta{{ pesadas !== 1 ? 's' : '' }} con peso registrado · {{ totalGramos }}g total
        </p>
        <button class="mnl__btn-submit" :disabled="submitting" @click="enviarAprobacion">
          <div v-if="submitting" class="mnl__spinner mnl__spinner--sm"></div>
          <Send v-else :size="14" :stroke-width="2" />
          Enviar para aprobación
        </button>
      </div>

    </template>

    <!-- Modal batch -->
    <Teleport to="body">
      <Transition name="mnl-fade">
        <div v-if="modalOpen" class="mnl-overlay" @click.self="cerrarModal">
          <div class="mnl-modal">

            <div class="mnl-modal__header">
              <div class="mnl-modal__ico"><Scale :size="18" :stroke-width="1.75" /></div>
              <div>
                <h2 class="mnl-modal__title">Registrar manicura del lote</h2>
                <p class="mnl-modal__sub">{{ lote?.codigo }}<span v-if="lote?.genetica"> · {{ lote.genetica.nombre }}</span></p>
              </div>
              <button class="mnl-modal__close" @click="cerrarModal"><X :size="16" :stroke-width="2" /></button>
            </div>

            <form class="mnl-modal__body" @submit.prevent="submitBatch">

              <div class="mnl-field">
                <label class="mnl-label">Plantas manicuradas <span class="mnl-req">*</span></label>
                <div class="mnl-input-grp">
                  <input
                    v-model.number="batchForm.plantas_manicuradas"
                    type="number" step="1" min="1" :max="lote?.plants_count"
                    class="mnl-input" placeholder="0" required autofocus
                  />
                  <span class="mnl-input-sfx">de {{ lote?.plants_count }}</span>
                </div>
              </div>

              <div class="mnl-field">
                <label class="mnl-label">Peso neto post-manicura <span class="mnl-req">*</span></label>
                <div class="mnl-input-grp">
                  <input
                    v-model.number="batchForm.peso_seco_g"
                    type="number" step="0.1" min="0.1"
                    class="mnl-input" placeholder="0.0" required
                  />
                  <span class="mnl-input-sfx">g</span>
                </div>
              </div>

              <div class="mnl-field">
                <label class="mnl-label">Notas <span class="mnl-opt">opcional</span></label>
                <textarea v-model="batchForm.notas" class="mnl-textarea" rows="2" placeholder="Observaciones del proceso…"></textarea>
              </div>

              <div v-if="modalError" class="mnl-error">{{ modalError }}</div>

              <div class="mnl-actions">
                <button type="button" class="mnl-btn-cancel" @click="cerrarModal">Cancelar</button>
                <button type="submit" class="mnl-btn-submit" :disabled="savingBatch || !batchForm.plantas_manicuradas || !batchForm.peso_seco_g">
                  <div v-if="savingBatch" class="mnl__spinner mnl__spinner--sm mnl__spinner--white"></div>
                  <Send v-else :size="13" :stroke-width="2" />
                  Enviar a aprobación
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
import { ref, reactive, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ChevronLeft, ChevronRight, Leaf, CheckCircle, Scale, Package, Send, X } from 'lucide-vue-next'
import { getLote, listPlants, transicionarLote } from '../../lib/api.js'
import { useToast } from '../../composables/useToast.js'

const route  = useRoute()
const router = useRouter()
const toast  = useToast()

const id      = Number(route.params.id)
const loading = ref(true)
const lote    = ref(null)
const plantas = ref([])

const plantWeights = reactive({})

const submitting = ref(false)
const modalOpen  = ref(false)
const savingBatch = ref(false)
const modalError  = ref('')
const batchForm   = ref({ plantas_manicuradas: null, peso_seco_g: null, notas: '' })

const pesadas = computed(() =>
  plantas.value.filter(p => plantWeights[p.id] > 0).length
)

const totalGramos = computed(() => {
  const sum = plantas.value.reduce((acc, p) => acc + (parseFloat(plantWeights[p.id]) || 0), 0)
  return parseFloat(sum.toFixed(1))
})

async function cargar() {
  loading.value = true
  try {
    const [loteRes, plantasRes] = await Promise.all([
      getLote(id),
      listPlants({ lote_id: id }),
    ])
    lote.value    = loteRes.data
    plantas.value = plantasRes.data || []
    for (const p of plantas.value) {
      plantWeights[p.id] = p.peso_seco ? parseFloat(p.peso_seco) : null
    }
  } catch {
    toast.error('Error al cargar el lote')
    router.push('/mnc/pendientes')
  } finally {
    loading.value = false
  }
}

function abrirModal() {
  batchForm.value = { plantas_manicuradas: lote.value?.plants_count || null, peso_seco_g: null, notas: '' }
  modalError.value = ''
  modalOpen.value = true
}

function cerrarModal() {
  modalOpen.value = false
}

async function submitBatch() {
  if (!batchForm.value.plantas_manicuradas || !batchForm.value.peso_seco_g) return
  savingBatch.value = true
  modalError.value = ''
  try {
    await transicionarLote(id, {
      pesada: {
        manicurado:          true,
        peso_seco_g:         batchForm.value.peso_seco_g,
        plantas_manicuradas: batchForm.value.plantas_manicuradas,
        notas:               batchForm.value.notas || undefined,
      },
    })
    toast.success(`Lote ${lote.value.codigo} enviado para aprobación`)
    cerrarModal()
    await cargar()
  } catch (e) {
    modalError.value = e.response?.data?.errors?.[0] || e.response?.data?.error || 'Error al registrar manicura'
  } finally {
    savingBatch.value = false
  }
}

async function enviarAprobacion() {
  if (pesadas.value === 0 || submitting.value) return
  submitting.value = true
  try {
    await transicionarLote(id, {
      pesada: {
        manicurado:          true,
        peso_seco_g:         totalGramos.value,
        plantas_manicuradas: pesadas.value,
      },
    })
    toast.success(`Lote ${lote.value.codigo} enviado para aprobación`)
    await cargar()
  } catch (e) {
    toast.error(e.response?.data?.errors?.[0] || e.response?.data?.error || 'Error al enviar')
  } finally {
    submitting.value = false
  }
}

onMounted(cargar)
</script>

<style scoped>
.mnl { padding: var(--sp-6); max-width: 860px; }

/* Back */
.mnl__back {
  display: inline-flex; align-items: center; gap: var(--sp-1);
  font-size: var(--fs-13); color: var(--c-ink-500); text-decoration: none;
  margin-bottom: var(--sp-5); transition: color .15s;
}
.mnl__back:hover { color: var(--c-ink-800); }

/* Header */
.mnl__header {
  display: flex; align-items: flex-start; justify-content: space-between;
  gap: var(--sp-4); margin-bottom: var(--sp-5); flex-wrap: wrap;
}
.mnl__title { font-size: var(--fs-22); font-weight: 800; color: var(--c-ink-900); letter-spacing: -.02em; margin: 0 0 var(--sp-1); font-family: var(--font-mono, monospace); }
.mnl__sub   { font-size: var(--fs-14); color: var(--c-ink-500); margin: 0; }
.mnl__header-actions { display: flex; align-items: center; gap: var(--sp-2); flex-wrap: wrap; }

/* Badges */
.mnl__badge {
  font-size: 12px; font-weight: 600; padding: .2em .65em;
  border-radius: 999px; text-transform: uppercase; letter-spacing: .04em; flex-shrink: 0;
}
.mnl__badge--secado    { background: #fffbeb; color: #b45309; }
.mnl__badge--pendiente { background: #ede9fe; color: #7c3aed; }

/* Primary button */
.mnl__btn-primary {
  display: inline-flex; align-items: center; gap: var(--sp-2);
  background: #5C7A4A; color: #fff; border: none; border-radius: var(--r-md);
  padding: var(--sp-2) var(--sp-4); font-size: var(--fs-13); font-weight: 600;
  cursor: pointer; transition: background .15s;
}
.mnl__btn-primary:hover { background: #4a6239; }

/* Waiting banner */
.mnl__waiting {
  display: flex; align-items: center; gap: var(--sp-2);
  background: #ede9fe; border: 1px solid #c4b5fd; border-radius: var(--r-md);
  color: #7c3aed; padding: var(--sp-3) var(--sp-4);
  font-size: var(--fs-13); font-weight: 500; margin-bottom: var(--sp-5);
}

/* KPIs */
.mnl__kpis {
  display: grid; grid-template-columns: repeat(auto-fill, minmax(180px, 1fr));
  gap: var(--sp-3); margin-bottom: var(--sp-6);
}
.mnl__kpi {
  display: flex; align-items: center; gap: var(--sp-3);
  background: var(--c-paper); border: 1px solid var(--c-ink-100); border-radius: var(--r-lg);
  padding: var(--sp-4) var(--sp-4);
}
.mnl__kpi-icon {
  width: 38px; height: 38px; border-radius: var(--r-md);
  display: flex; align-items: center; justify-content: center; flex-shrink: 0;
}
.mnl__kpi-icon--green  { background: rgba(92,122,74,.12);  color: #5C7A4A; }
.mnl__kpi-icon--blue   { background: rgba(3,105,161,.10);  color: #0369a1; }
.mnl__kpi-icon--orange { background: rgba(217,119,6,.10);  color: #d97706; }
.mnl__kpi-icon--gray   { background: var(--c-ink-50);      color: var(--c-ink-400); }
.mnl__kpi-val {
  font-size: var(--fs-22); font-weight: 800; color: var(--c-ink-900); line-height: 1;
}
.mnl__kpi-val--warn { color: #d97706; }
.mnl__kpi-of  { font-size: var(--fs-13); font-weight: 500; color: var(--c-ink-400); }
.mnl__kpi-lbl { font-size: var(--fs-12); color: var(--c-ink-500); margin-top: 2px; }

/* Section */
.mnl__section { margin-bottom: var(--sp-5); }
.mnl__section-title {
  font-size: var(--fs-11); font-weight: 700; color: var(--c-ink-500);
  text-transform: uppercase; letter-spacing: .06em;
  display: flex; align-items: center; gap: var(--sp-2);
  margin: 0 0 var(--sp-3);
}

/* Plant rows */
.mnl__list { display: flex; flex-direction: column; gap: 2px; }
.mnl__row {
  display: flex; align-items: center; gap: var(--sp-2);
  background: var(--c-paper); border: 1px solid var(--c-ink-100); border-radius: var(--r-md);
  padding: var(--sp-2) var(--sp-3); text-decoration: none; color: inherit;
  transition: border-color .15s;
}
.mnl__row:hover { border-color: #5C7A4A; }

.mnl__row-dot {
  width: 8px; height: 8px; border-radius: 50%; flex-shrink: 0;
}
.mnl__dot--done  { background: #16a34a; }
.mnl__dot--empty { background: var(--c-ink-200); }

.mnl__row-num {
  font-size: var(--fs-11); font-weight: 700; color: var(--c-ink-400);
  font-family: var(--font-mono, monospace); min-width: 20px; flex-shrink: 0;
}
.mnl__row-info {
  flex: 1; min-width: 0;
  display: flex; align-items: baseline; gap: var(--sp-1); overflow: hidden;
}
.mnl__row-nombre { font-size: var(--fs-13); font-weight: 600; color: var(--c-ink-800); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.mnl__row-sep    { font-size: var(--fs-11); color: var(--c-ink-300); flex-shrink: 0; }
.mnl__row-qr     { font-size: var(--fs-11); color: var(--c-ink-400); font-family: var(--font-mono, monospace); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }

.mnl__peso {
  font-size: 12px; font-weight: 600; flex-shrink: 0;
}
.mnl__peso--done  { color: #16a34a; }
.mnl__peso--empty { color: var(--c-ink-300); }

.mnl__row-arrow { color: var(--c-ink-300); flex-shrink: 0; }

/* Submit footer */
.mnl__footer {
  display: flex; align-items: center; justify-content: space-between; gap: var(--sp-4);
  background: var(--c-paper); border: 1px solid var(--c-ink-100); border-radius: var(--r-lg);
  padding: var(--sp-4) var(--sp-5); flex-wrap: wrap;
}
.mnl__footer-hint { font-size: var(--fs-13); color: var(--c-ink-500); margin: 0; }
.mnl__btn-submit {
  display: inline-flex; align-items: center; gap: var(--sp-2);
  background: #5C7A4A; color: #fff; border: none; border-radius: var(--r-md);
  padding: var(--sp-2) var(--sp-4); font-size: var(--fs-13); font-weight: 600;
  cursor: pointer; transition: background .15s; flex-shrink: 0;
}
.mnl__btn-submit:hover:not(:disabled) { background: #4a6239; }
.mnl__btn-submit:disabled { opacity: .45; cursor: not-allowed; }

/* Loading */
.mnl__loading {
  display: flex; align-items: center; justify-content: center;
  padding: var(--sp-12) 0; color: var(--c-ink-400);
}
.mnl__spinner {
  width: 20px; height: 20px;
  border: 2px solid var(--c-ink-200); border-top-color: #5C7A4A;
  border-radius: 50%; animation: mnl-spin .7s linear infinite;
}
.mnl__spinner--sm { width: 14px; height: 14px; }
.mnl__spinner--white { border-top-color: #fff; border-color: rgba(255,255,255,.3); }
@keyframes mnl-spin { to { transform: rotate(360deg); } }

/* ── Modal ─────────────────────────────────────── */
.mnl-overlay {
  position: fixed; inset: 0; background: rgba(0,0,0,.45);
  display: flex; align-items: center; justify-content: center;
  z-index: 1050; padding: var(--sp-4); backdrop-filter: blur(3px);
}
.mnl-modal {
  background: var(--c-paper); border-radius: var(--r-xl);
  width: 100%; max-width: 440px; max-height: 92vh; overflow-y: auto;
  box-shadow: 0 20px 60px rgba(0,0,0,.18);
}
.mnl-modal__header {
  display: flex; align-items: flex-start; gap: var(--sp-3);
  padding: var(--sp-5) var(--sp-5) var(--sp-4);
  border-bottom: 1px solid var(--c-ink-100);
}
.mnl-modal__ico {
  width: 38px; height: 38px; border-radius: var(--r-md);
  background: rgba(92,122,74,.12); color: #5C7A4A;
  display: flex; align-items: center; justify-content: center; flex-shrink: 0;
}
.mnl-modal__title { font-size: var(--fs-15); font-weight: 700; color: var(--c-ink-900); margin: 0 0 2px; }
.mnl-modal__sub   { font-size: var(--fs-12); color: var(--c-ink-500); margin: 0; }
.mnl-modal__close {
  margin-left: auto; background: var(--c-ink-50); border: none;
  width: 28px; height: 28px; border-radius: var(--r-sm);
  cursor: pointer; display: flex; align-items: center; justify-content: center;
  color: var(--c-ink-500); flex-shrink: 0; transition: background .15s;
}
.mnl-modal__close:hover { background: var(--c-ink-100); }

.mnl-modal__body { padding: var(--sp-5); display: flex; flex-direction: column; gap: var(--sp-4); }

.mnl-field  { display: flex; flex-direction: column; gap: var(--sp-1); }
.mnl-label  { font-size: var(--fs-11); font-weight: 700; color: var(--c-ink-600); text-transform: uppercase; letter-spacing: .05em; }
.mnl-req    { color: #ef4444; }
.mnl-opt    { font-size: var(--fs-11); font-weight: 400; color: var(--c-ink-400); text-transform: none; letter-spacing: 0; }

.mnl-input-grp { display: flex; }
.mnl-input {
  flex: 1; background: var(--c-ink-50); border: 1.5px solid var(--c-ink-200);
  border-radius: var(--r-sm) 0 0 var(--r-sm); padding: var(--sp-2) var(--sp-3);
  font-size: var(--fs-14); color: var(--c-ink-900); outline: none; transition: border-color .15s;
}
.mnl-input:focus { border-color: #5C7A4A; background: #fff; }
.mnl-input-sfx {
  background: var(--c-ink-50); border: 1.5px solid var(--c-ink-200); border-left: none;
  padding: var(--sp-2) var(--sp-3); font-size: var(--fs-13); font-weight: 600;
  color: var(--c-ink-500); border-radius: 0 var(--r-sm) var(--r-sm) 0; white-space: nowrap;
}
.mnl-textarea {
  background: var(--c-ink-50); border: 1.5px solid var(--c-ink-200); border-radius: var(--r-sm);
  padding: var(--sp-2) var(--sp-3); font-size: var(--fs-14); color: var(--c-ink-900);
  outline: none; resize: vertical; min-height: 60px; transition: border-color .15s; font-family: inherit;
}
.mnl-textarea:focus { border-color: #5C7A4A; background: #fff; }
.mnl-error {
  background: #fef2f2; border: 1px solid #fecaca; color: #dc2626;
  padding: var(--sp-2) var(--sp-3); border-radius: var(--r-sm); font-size: var(--fs-13);
}
.mnl-actions { display: flex; justify-content: flex-end; gap: var(--sp-2); }
.mnl-btn-cancel {
  background: var(--c-paper); color: var(--c-ink-600); border: 1.5px solid var(--c-ink-200);
  padding: var(--sp-2) var(--sp-4); border-radius: var(--r-md); font-size: var(--fs-13); font-weight: 500; cursor: pointer;
}
.mnl-btn-cancel:hover { background: var(--c-ink-50); }
.mnl-btn-submit {
  display: inline-flex; align-items: center; gap: var(--sp-2);
  background: #5C7A4A; color: #fff; border: none; border-radius: var(--r-md);
  padding: var(--sp-2) var(--sp-4); font-size: var(--fs-13); font-weight: 600; cursor: pointer; transition: background .15s;
}
.mnl-btn-submit:hover:not(:disabled) { background: #4a6239; }
.mnl-btn-submit:disabled { opacity: .45; cursor: not-allowed; }

.mnl-fade-enter-active, .mnl-fade-leave-active { transition: opacity .2s; }
.mnl-fade-enter-from,  .mnl-fade-leave-to      { opacity: 0; }
</style>
