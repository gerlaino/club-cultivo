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
          <p class="mnl__eyebrow"><Scissors :size="13" :stroke-width="2" /> Manicura</p>
          <h1 class="mnl__title">{{ lote.codigo }}</h1>
          <p class="mnl__sub">{{ lote.genetica?.nombre }}<span v-if="lote.sala"> · {{ lote.sala.nombre }}</span></p>
        </div>
        <div class="mnl__header-right">
          <span class="mnl__estado-badge" :class="estadoBadgeClass">{{ estadoLabel }}</span>
          <button class="mnl__btn-icon" @click="cargar" title="Actualizar">
            <RefreshCw :size="14" :stroke-width="2" />
          </button>
          <button v-if="['en_manicura','secado'].includes(lote.estado)" class="mnl__btn-primary" @click="abrirModal">
            <Scale :size="14" :stroke-width="2" /> Registrar por lote
          </button>
        </div>
      </div>

      <!-- Waiting banner -->
      <div v-if="lote.estado === 'manicura_pendiente'" class="mnl__waiting">
        <CheckCircle :size="14" :stroke-width="2" />
        <span>
          <strong>Enviado para aprobación</strong>
          <template v-if="lote.ultima_pesada_manicura">
            — {{ pesadasKpi }} plantas · {{ totalGramosKpi }}g
            <template v-if="lote.ultima_pesada_manicura.registrado_por"> · por {{ lote.ultima_pesada_manicura.registrado_por }}</template>
          </template>
        </span>
        <span class="mnl__waiting-note">El admin revisará y puede ajustar el peso al aprobar.</span>
      </div>

      <!-- KPIs — mismo patrón que SalaDetailView -->
      <div class="mnl__kpis">
        <div class="mnl__kpi">
          <div class="mnl__kpi-ico">✂️</div>
          <div class="mnl__kpi-body">
            <div class="mnl__kpi-val" :style="pesadasKpi === plantas.length && plantas.length > 0 ? 'color:#16a34a' : ''">
              {{ pesadasKpi }}<span class="mnl__kpi-den">/{{ plantas.length }}</span>
            </div>
            <div class="mnl__kpi-lbl">Pesadas</div>
            <div class="mnl__kpi-progress" v-if="plantas.length > 0">
              <div class="mnl__kpi-progress-fill" :style="{ width: kpiPorc + '%', background: kpiPorc === 100 ? '#16a34a' : '#5C7A4A' }"></div>
            </div>
          </div>
        </div>
        <div class="mnl__kpi">
          <div class="mnl__kpi-ico">⚖️</div>
          <div class="mnl__kpi-body">
            <div class="mnl__kpi-val">{{ totalGramosKpi }}<span class="mnl__kpi-den">g</span></div>
            <div class="mnl__kpi-lbl">Total registrado</div>
          </div>
        </div>
        <div class="mnl__kpi">
          <div class="mnl__kpi-ico">🌿</div>
          <div class="mnl__kpi-body">
            <div class="mnl__kpi-val" :style="sinPesar > 0 ? 'color:#d97706' : ''">{{ sinPesar }}</div>
            <div class="mnl__kpi-lbl">Sin pesar</div>
          </div>
        </div>
      </div>

      <!-- Plant table -->
      <div class="mnl__section">
        <div class="mnl__section-head">
          <h2 class="mnl__section-title"><Leaf :size="12" :stroke-width="2" /> Plantas del lote</h2>
          <span v-if="lote.estado === 'manicura_pendiente'" class="mnl__locked-tag">
            <Lock :size="11" /> Solo lectura
          </span>
        </div>

        <div class="mnl__table-wrap">
          <table class="mnl__table">
            <thead>
              <tr>
                <th class="mnl__th mnl__th--num">#</th>
                <th class="mnl__th">Nombre</th>
                <th class="mnl__th mnl__th--qr">QR</th>
                <th v-if="hasAnyHumedo" class="mnl__th mnl__th--peso">Peso húmedo (g)</th>
                <th class="mnl__th mnl__th--peso">Peso seco (g)</th>
                <th class="mnl__th mnl__th--estado">Estado</th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="(planta, i) in plantas"
                :key="planta.id"
                class="mnl__tr"
                :class="{ 'mnl__tr--clickable': ['en_manicura','secado'].includes(lote.estado) }"
                @click="['en_manicura','secado'].includes(lote.estado) ? irAPlanta(planta) : null"
              >
                <td class="mnl__td mnl__td--num">{{ i + 1 }}</td>
                <td class="mnl__td mnl__td--nombre">{{ planta.nombre || `Planta #${planta.id}` }}</td>
                <td class="mnl__td mnl__td--qr">{{ planta.codigo_qr }}</td>
                <td v-if="hasAnyHumedo" class="mnl__td mnl__td--peso">
                  <span :class="parseFloat(planta.peso_humedo) > 0 ? 'mnl__peso--humedo' : 'mnl__peso--none'">
                    {{ parseFloat(planta.peso_humedo) > 0 ? parseFloat(planta.peso_humedo).toFixed(1) : '—' }}
                  </span>
                </td>
                <td class="mnl__td mnl__td--peso">
                  <span :class="parseFloat(planta.peso_seco) > 0 ? 'mnl__peso--ok' : 'mnl__peso--none'">
                    {{ parseFloat(planta.peso_seco) > 0 ? parseFloat(planta.peso_seco).toFixed(1) : '—' }}
                  </span>
                </td>
                <td class="mnl__td mnl__td--estado">
                  <span class="mnl__chip" :class="parseFloat(planta.peso_seco) > 0 ? 'mnl__chip--done' : 'mnl__chip--pending'">
                    {{ parseFloat(planta.peso_seco) > 0 ? 'Pesada' : 'Sin pesar' }}
                  </span>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <!-- Footer: enviar a aprobación (solo flujo per-planta QR) -->
      <div v-if="['en_manicura','secado'].includes(lote.estado) && pesadasKpi > 0" class="mnl__footer">
        <p class="mnl__footer-txt">
          {{ pesadasKpi }}/{{ plantas.length }} plantas · {{ totalGramosKpi }}g total
        </p>
        <button class="mnl__btn-submit" :disabled="submitting" @click="enviarAprobacion">
          <div v-if="submitting" class="mnl__spinner mnl__spinner--sm"></div>
          <Send v-else :size="14" :stroke-width="2" />
          Enviar para aprobación
        </button>
      </div>

    </template>

    <!-- Modal batch pesaje -->
    <Teleport to="body">
      <Transition name="mnl-fade">
        <div v-if="modalOpen" class="mnl-overlay" @click.self="cerrarModal">
          <div class="mnl-modal">
            <div class="mnl-modal__hd">
              <div class="mnl-modal__ico"><Scale :size="18" :stroke-width="1.75" /></div>
              <div>
                <h2 class="mnl-modal__title">Registrar manicura del lote</h2>
                <p class="mnl-modal__sub">{{ lote?.codigo }}<span v-if="lote?.genetica"> · {{ lote.genetica.nombre }}</span></p>
              </div>
              <button class="mnl-modal__close" @click="cerrarModal"><X :size="16" /></button>
            </div>

            <form class="mnl-modal__body" @submit.prevent="submitBatch">
              <div class="mnl-field">
                <label class="mnl-label">Plantas manicuradas <span class="mnl-req">*</span></label>
                <div class="mnl-input-row">
                  <input v-model.number="batchForm.plantas_manicuradas" type="number" step="1" min="1"
                    :max="lote?.plants_count" class="mnl-input" placeholder="0" required autofocus />
                  <span class="mnl-suffix">de {{ lote?.plants_count }}</span>
                </div>
              </div>

              <div class="mnl-field">
                <label class="mnl-label">Peso neto post-manicura <span class="mnl-req">*</span></label>
                <div class="mnl-input-row">
                  <input v-model.number="batchForm.peso_seco_g" type="number" step="0.1" min="0.1"
                    class="mnl-input" placeholder="0.0" required />
                  <span class="mnl-suffix">g</span>
                </div>
              </div>

              <div class="mnl-field">
                <label class="mnl-label">Notas <span class="mnl-opt">opcional</span></label>
                <textarea v-model="batchForm.notas" class="mnl-textarea" rows="2" placeholder="Observaciones…"></textarea>
              </div>

              <div v-if="modalError" class="mnl-error">{{ modalError }}</div>

              <div class="mnl-actions">
                <button type="button" class="mnl-btn-cancel" @click="cerrarModal">Cancelar</button>
                <button type="submit" class="mnl-btn-ok" :disabled="savingBatch || !batchForm.plantas_manicuradas || !batchForm.peso_seco_g">
                  <div v-if="savingBatch" class="mnl__spinner mnl__spinner--sm mnl__spinner--white"></div>
                  <Send v-else :size="13" />
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
import { ref, computed, onMounted, onActivated } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ChevronLeft, Scissors, Leaf, CheckCircle, Scale, Send, X, Lock, RefreshCw } from 'lucide-vue-next'
import { getLote, listPlants, transicionarLote, finalizarPesajeManicura } from '../../lib/api.js'
import { useToast } from '../../composables/useToast.js'

const route  = useRoute()
const router = useRouter()
const toast  = useToast()

const id      = Number(route.params.id)
const loading = ref(true)
const lote    = ref(null)
const plantas = ref([])

const submitting  = ref(false)
const modalOpen   = ref(false)
const savingBatch = ref(false)
const modalError  = ref('')
const batchForm   = ref({ plantas_manicuradas: null, peso_seco_g: null, notas: '' })

// KPIs — per-plant flow sets plant.peso_seco individually.
// Batch flow (transicionarLote) creates a lote-level pesada but doesn't touch plant.peso_seco.
// We prefer plant-level counts; fall back to ultima_pesada_manicura for the batch case.
const pesadasKpi = computed(() => {
  const fromPlants = plantas.value.filter(p => parseFloat(p.peso_seco) > 0).length
  if (fromPlants > 0) return fromPlants
  return lote.value?.ultima_pesada_manicura?.plantas_manicuradas || 0
})

const totalGramosKpi = computed(() => {
  const fromPlants = plantas.value.reduce((s, p) => s + (parseFloat(p.peso_seco) || 0), 0)
  if (fromPlants > 0) return parseFloat(fromPlants.toFixed(1))
  const v = lote.value?.ultima_pesada_manicura?.peso_seco_g
  return v ? parseFloat(parseFloat(v).toFixed(1)) : 0
})

const sinPesar        = computed(() => Math.max(0, plantas.value.length - pesadasKpi.value))
const kpiPorc         = computed(() => plantas.value.length ? Math.min(100, Math.round(pesadasKpi.value / plantas.value.length * 100)) : 0)
const hasAnyHumedo    = computed(() => plantas.value.some(p => parseFloat(p.peso_humedo) > 0))

const estadoBadgeClass = computed(() => ({
  'mnl__estado-badge--asignado':   ['en_manicura', 'secado'].includes(lote.value?.estado),
  'mnl__estado-badge--pendiente':  lote.value?.estado === 'manicura_pendiente',
}))
const estadoLabel = computed(() =>
  lote.value?.estado === 'manicura_pendiente' ? 'Pdte. aprobación' : 'Asignado'
)

async function cargar() {
  loading.value = true
  try {
    const [lr, pr] = await Promise.all([getLote(id), listPlants({ lote_id: id })])
    lote.value    = lr.data
    plantas.value = pr.data || []
  } catch {
    toast.error('Error al cargar el lote')
    router.push('/mnc/pendientes')
  } finally {
    loading.value = false
  }
}

function irAPlanta(p) { router.push(`/p/${p.codigo_qr}`) }

function abrirModal() {
  batchForm.value  = { plantas_manicuradas: lote.value?.plants_count || null, peso_seco_g: null, notas: '' }
  modalError.value = ''
  modalOpen.value  = true
}
function cerrarModal() { modalOpen.value = false }

async function submitBatch() {
  if (!batchForm.value.plantas_manicuradas || !batchForm.value.peso_seco_g) return
  savingBatch.value = true
  modalError.value  = ''
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
    modalError.value = e.response?.data?.errors?.[0] || e.response?.data?.error || 'Error al registrar'
  } finally {
    savingBatch.value = false
  }
}

async function enviarAprobacion() {
  if (pesadasKpi.value === 0 || submitting.value) return
  submitting.value = true
  try {
    await finalizarPesajeManicura(id)
    toast.success(`Lote ${lote.value.codigo} enviado para aprobación`)
    await cargar()
  } catch (e) {
    toast.error(e.response?.data?.error || e.response?.data?.errors?.[0] || 'Error al enviar')
  } finally {
    submitting.value = false
  }
}

onMounted(cargar)
onActivated(cargar)
</script>

<style scoped>
.mnl { padding: 1.5rem 1.75rem 3rem; }
@media (max-width: 768px) { .mnl { padding: 1rem 1rem 2rem; } }

/* Back */
.mnl__back {
  display: inline-flex; align-items: center; gap: 4px;
  font-size: .8rem; color: #64748b; text-decoration: none;
  margin-bottom: 1.25rem; transition: color .15s;
}
.mnl__back:hover { color: #1e293b; }

/* Header */
.mnl__header {
  display: flex; align-items: flex-start; justify-content: space-between;
  gap: 1rem; margin-bottom: 1.5rem; flex-wrap: wrap;
}
.mnl__eyebrow {
  display: inline-flex; align-items: center; gap: 4px;
  font-size: .72rem; font-weight: 700; text-transform: uppercase; letter-spacing: .08em;
  color: #5C7A4A; margin: 0 0 .2rem;
}
.mnl__title { font-size: 1.6rem; font-weight: 800; color: #0f172a; letter-spacing: -.03em; margin: 0 0 .2rem; line-height: 1.1; }
.mnl__sub   { font-size: .85rem; color: #64748b; margin: 0; }
.mnl__header-right { display: flex; align-items: center; gap: .5rem; flex-wrap: wrap; padding-top: .2rem; }

.mnl__estado-badge {
  font-size: .7rem; font-weight: 700; padding: .25em .7em;
  border-radius: 999px; text-transform: uppercase; letter-spacing: .05em;
}
.mnl__estado-badge--asignado  { background: #fffbeb; color: #b45309; }
.mnl__estado-badge--pendiente { background: #ede9fe; color: #7c3aed; }

.mnl__btn-icon {
  width: 32px; height: 32px; border-radius: 6px;
  background: transparent; border: 1.5px solid #e2e8f0;
  display: flex; align-items: center; justify-content: center;
  color: #64748b; cursor: pointer; transition: all .15s;
}
.mnl__btn-icon:hover { border-color: #5C7A4A; color: #5C7A4A; background: #f6faf4; }

.mnl__btn-primary {
  display: inline-flex; align-items: center; gap: 6px;
  background: #5C7A4A; color: #fff; border: none; border-radius: 7px;
  padding: .45rem 1rem; font-size: .82rem; font-weight: 600;
  cursor: pointer; transition: background .15s;
}
.mnl__btn-primary:hover { background: #4a6239; }

/* Waiting banner */
.mnl__waiting {
  display: flex; align-items: center; gap: .6rem; flex-wrap: wrap;
  background: #ede9fe; border: 1px solid #c4b5fd; border-radius: 10px;
  padding: .75rem 1rem; margin-bottom: 1.5rem;
  font-size: .82rem; color: #7c3aed;
}
.mnl__waiting-note { margin-left: auto; font-size: .75rem; color: #6d28d9; }

/* KPIs — mismo patrón que SalaDetailView */
.mnl__kpis {
  display: grid; grid-template-columns: repeat(3, 1fr);
  gap: 1rem; margin-bottom: 1.75rem;
}
@media (max-width: 640px) { .mnl__kpis { grid-template-columns: repeat(1, 1fr); } }

.mnl__kpi {
  background: #fff; border: 1px solid #d4e6d4; border-radius: 14px;
  padding: 1.1rem; display: flex; align-items: flex-start; gap: .75rem;
  transition: box-shadow .15s;
}
.mnl__kpi:hover { box-shadow: 0 4px 16px rgba(27,94,32,.08); }
.mnl__kpi-ico { font-size: 1.4rem; flex-shrink: 0; margin-top: .1rem; }
.mnl__kpi-body { flex: 1; min-width: 0; }
.mnl__kpi-val {
  font-size: 1.75rem; font-weight: 800; line-height: 1;
  letter-spacing: -.04em; color: #1a1a1a; margin-bottom: .15rem;
}
.mnl__kpi-den  { font-size: 1rem; font-weight: 500; color: #94a3b8; margin-left: 2px; }
.mnl__kpi-lbl  { font-size: .7rem; color: #60725d; font-weight: 600; text-transform: uppercase; letter-spacing: .05em; }
.mnl__kpi-progress { height: 4px; background: #d4e6d4; border-radius: 999px; overflow: hidden; margin-top: .5rem; }
.mnl__kpi-progress-fill { height: 100%; border-radius: 999px; transition: width .5s ease; }

/* Section header */
.mnl__section-head {
  display: flex; align-items: center; justify-content: space-between;
  gap: .75rem; margin-bottom: .75rem;
}
.mnl__section-title {
  display: flex; align-items: center; gap: .35rem;
  font-size: .7rem; font-weight: 700; color: #60725d;
  text-transform: uppercase; letter-spacing: .07em; margin: 0;
}
.mnl__locked-tag {
  display: inline-flex; align-items: center; gap: .25rem;
  font-size: .72rem; color: #7c3aed; font-weight: 600;
}

/* Table */
.mnl__table-wrap {
  border: 1px solid #e2e8f0; border-radius: 10px;
  overflow: hidden; overflow-x: auto;
}
.mnl__table { width: 100%; border-collapse: collapse; }

.mnl__th {
  font-size: .68rem; font-weight: 700; color: #64748b;
  text-transform: uppercase; letter-spacing: .05em;
  padding: .55rem .85rem; background: #f8fafc;
  border-bottom: 1px solid #e2e8f0; text-align: left; white-space: nowrap;
}
.mnl__th--num    { width: 40px; text-align: center; }
.mnl__th--qr     { color: #94a3b8; }
.mnl__th--peso   { text-align: right; }
.mnl__th--estado { text-align: center; }

.mnl__tr { border-bottom: 1px solid #f1f5f9; }
.mnl__tr:last-child { border-bottom: none; }
.mnl__tr--clickable { cursor: pointer; transition: background .1s; }
.mnl__tr--clickable:hover { background: #f6faf4; }

.mnl__td {
  padding: .6rem .85rem; font-size: .82rem; color: #475569; vertical-align: middle;
}
.mnl__td--num    { text-align: center; font-size: .72rem; font-weight: 700; color: #94a3b8; }
.mnl__td--nombre { font-weight: 600; color: #0f172a; }
.mnl__td--qr     { font-size: .72rem; color: #94a3b8; }
.mnl__td--peso   { text-align: right; font-weight: 700; font-size: .85rem; }
.mnl__td--estado { text-align: center; }

.mnl__peso--ok     { color: #16a34a; }
.mnl__peso--humedo { color: #0284c7; }
.mnl__peso--none   { color: #cbd5e1; }

.mnl__chip {
  display: inline-block; font-size: .65rem; font-weight: 700;
  letter-spacing: .04em; padding: .2em .6em; border-radius: 999px; text-transform: uppercase;
}
.mnl__chip--done    { background: #dcfce7; color: #15803d; }
.mnl__chip--pending { background: #f1f5f9; color: #94a3b8; }

/* Footer */
.mnl__footer {
  display: flex; align-items: center; justify-content: space-between; gap: 1rem;
  background: #fff; border: 1px solid #e2e8f0; border-radius: 10px;
  padding: .875rem 1.25rem; flex-wrap: wrap; margin-top: 1rem;
}
.mnl__footer-txt { font-size: .82rem; color: #475569; margin: 0; font-weight: 500; }
.mnl__btn-submit {
  display: inline-flex; align-items: center; gap: .4rem;
  background: #5C7A4A; color: #fff; border: none; border-radius: 7px;
  padding: .5rem 1.1rem; font-size: .82rem; font-weight: 600;
  cursor: pointer; transition: background .15s;
}
.mnl__btn-submit:hover:not(:disabled) { background: #4a6239; }
.mnl__btn-submit:disabled { opacity: .45; cursor: not-allowed; }

/* Loading */
.mnl__loading { display: flex; align-items: center; justify-content: center; padding: 4rem 0; }
.mnl__spinner {
  width: 20px; height: 20px;
  border: 2px solid #e2e8f0; border-top-color: #5C7A4A;
  border-radius: 50%; animation: mnl-spin .7s linear infinite;
}
.mnl__spinner--sm    { width: 14px; height: 14px; }
.mnl__spinner--white { border-top-color: #fff; border-color: rgba(255,255,255,.3); }
@keyframes mnl-spin { to { transform: rotate(360deg); } }

/* Modal */
.mnl-overlay {
  position: fixed; inset: 0; background: rgba(0,0,0,.45);
  display: flex; align-items: center; justify-content: center;
  z-index: 1050; padding: 1rem; backdrop-filter: blur(3px);
}
.mnl-modal {
  background: #fff; border-radius: 14px;
  width: 100%; max-width: 420px; max-height: 92vh; overflow-y: auto;
  box-shadow: 0 24px 64px rgba(0,0,0,.18);
}
.mnl-modal__hd {
  display: flex; align-items: flex-start; gap: .75rem;
  padding: 1.25rem 1.25rem 1rem; border-bottom: 1px solid #f1f5f9;
}
.mnl-modal__ico {
  width: 38px; height: 38px; border-radius: 8px;
  background: rgba(92,122,74,.12); color: #5C7A4A;
  display: flex; align-items: center; justify-content: center; flex-shrink: 0;
}
.mnl-modal__title { font-size: .95rem; font-weight: 700; color: #0f172a; margin: 0 0 2px; }
.mnl-modal__sub   { font-size: .78rem; color: #64748b; margin: 0; }
.mnl-modal__close {
  margin-left: auto; background: #f8fafc; border: none;
  width: 28px; height: 28px; border-radius: 6px;
  cursor: pointer; display: flex; align-items: center; justify-content: center;
  color: #64748b; flex-shrink: 0; transition: background .15s;
}
.mnl-modal__close:hover { background: #e2e8f0; }

.mnl-modal__body { padding: 1.25rem; display: flex; flex-direction: column; gap: 1rem; }
.mnl-field  { display: flex; flex-direction: column; gap: .3rem; }
.mnl-label  { font-size: .72rem; font-weight: 700; color: #475569; text-transform: uppercase; letter-spacing: .05em; }
.mnl-req    { color: #ef4444; }
.mnl-opt    { font-size: .72rem; font-weight: 400; color: #94a3b8; text-transform: none; letter-spacing: 0; }
.mnl-input-row { display: flex; }
.mnl-input {
  flex: 1; background: #f8fafc; border: 1.5px solid #e2e8f0;
  border-radius: 6px 0 0 6px; padding: .55rem .75rem;
  font-size: .9rem; color: #0f172a; outline: none; transition: border-color .15s;
}
.mnl-input:focus { border-color: #5C7A4A; background: #fff; }
.mnl-suffix {
  background: #f1f5f9; border: 1.5px solid #e2e8f0; border-left: none;
  padding: .55rem .75rem; font-size: .82rem; font-weight: 600;
  color: #64748b; border-radius: 0 6px 6px 0; white-space: nowrap;
}
.mnl-textarea {
  background: #f8fafc; border: 1.5px solid #e2e8f0; border-radius: 6px;
  padding: .55rem .75rem; font-size: .9rem; color: #0f172a;
  outline: none; resize: vertical; min-height: 60px; transition: border-color .15s; font-family: inherit;
}
.mnl-textarea:focus { border-color: #5C7A4A; background: #fff; }
.mnl-error {
  background: #fef2f2; border: 1px solid #fecaca; color: #dc2626;
  padding: .5rem .75rem; border-radius: 6px; font-size: .82rem;
}
.mnl-actions { display: flex; justify-content: flex-end; gap: .5rem; }
.mnl-btn-cancel {
  background: transparent; color: #475569; border: 1.5px solid #e2e8f0;
  padding: .5rem 1rem; border-radius: 7px; font-size: .82rem; font-weight: 500; cursor: pointer;
}
.mnl-btn-cancel:hover { background: #f8fafc; }
.mnl-btn-ok {
  display: inline-flex; align-items: center; gap: .4rem;
  background: #5C7A4A; color: #fff; border: none; border-radius: 7px;
  padding: .5rem 1rem; font-size: .82rem; font-weight: 600; cursor: pointer; transition: background .15s;
}
.mnl-btn-ok:hover:not(:disabled) { background: #4a6239; }
.mnl-btn-ok:disabled { opacity: .45; cursor: not-allowed; }

.mnl-fade-enter-active, .mnl-fade-leave-active { transition: opacity .2s; }
.mnl-fade-enter-from,  .mnl-fade-leave-to      { opacity: 0; }
</style>
