<template>
  <div class="mnd">

    <!-- Header -->
    <div class="mnd__header">
      <div>
        <h1 class="mnd__greeting">{{ saludo }}, {{ auth.user?.first_name }}</h1>
        <p class="mnd__date">{{ hoy }}</p>
      </div>
      <div v-if="sala" class="mnd__sala-badge">
        <i class="bi bi-grid-3x3-gap"></i>
        {{ sala.nombre }}
        <span class="mnd__sala-sede">· {{ sala.sede?.nombre || '' }}</span>
      </div>
    </div>

    <div v-if="loading" class="mnd__loading">
      <div class="mnd__spinner"></div>
      <span>Cargando…</span>
    </div>

    <template v-else>

      <!-- Sin sala asignada -->
      <div v-if="!sala" class="mnd__empty-sala">
        <div class="mnd__empty-icon"><i class="bi bi-house-slash"></i></div>
        <h3>Sin sala asignada</h3>
        <p>Contactá al administrador para que te asigne una sala.</p>
      </div>

      <div v-else class="mnd__layout">

        <!-- ── COLUMNA PRINCIPAL ── -->
        <div class="mnd__col-main">

          <!-- Registrar cosecha -->
          <section class="mnd__card mnd__card--accent">
            <div class="mnd__card-header">
              <div class="mnd__card-icon mnd__card-icon--purple"><i class="bi bi-scissors"></i></div>
              <h2 class="mnd__card-title">Registrar cosecha</h2>
            </div>

            <div v-if="lotesDisponibles.length === 0" class="mnd__empty-lotes">
              <i class="bi bi-box-seam"></i>
              No hay lotes en cosecha o curado en tu sala.
            </div>

            <template v-else>
              <!-- Paso 1: elegir lote -->
              <div class="mnd__step">
                <div class="mnd__step-label"><span class="mnd__step-num">1</span> Elegí el lote</div>
                <div class="mnd__lotes-grid">
                  <button
                    v-for="lote in lotesDisponibles" :key="lote.id"
                    class="mnd__lote-card"
                    :class="{ 'mnd__lote-card--active': form.lote_id === lote.id }"
                    type="button"
                    @click="seleccionarLote(lote)"
                  >
                    <div class="mnd__lote-top">
                      <span class="mnd__lote-codigo">{{ lote.codigo }}</span>
                      <span class="mnd__lote-estado" :style="estadoStyle(lote.estado)">
                        {{ ESTADOS[lote.estado]?.label || lote.estado }}
                      </span>
                    </div>
                    <div class="mnd__lote-gen">{{ lote.genetica?.nombre || 'Sin genética' }}</div>
                    <div class="mnd__lote-dias">{{ lote.dias_desde_inicio ?? '—' }} días desde inicio</div>
                  </button>
                </div>
              </div>

              <!-- Paso 2: cantidad -->
              <div v-if="form.lote_id" class="mnd__step">
                <div class="mnd__step-label"><span class="mnd__step-num">2</span> Cantidad manicurada (g)</div>
                <div class="mnd__cant-row">
                  <div class="mnd__cant-wrap">
                    <input
                      v-model.number="form.cantidad"
                      type="number" step="0.1" min="0.1"
                      class="mnd__cant-input"
                      placeholder="0.0"
                      @keyup.enter="enviar"
                    />
                    <span class="mnd__cant-suffix">g</span>
                  </div>
                  <button
                    class="mnd__btn-primary"
                    :disabled="!form.cantidad || form.cantidad <= 0 || enviando"
                    @click="enviar"
                  >
                    <span v-if="enviando" class="mnd__spinner mnd__spinner--sm"></span>
                    <i v-else class="bi bi-send-fill"></i>
                    Enviar para aprobación
                  </button>
                </div>

                <div v-if="loteActivo" class="mnd__preview">
                  <i class="bi bi-info-circle" style="color:#7c3aed"></i>
                  Se registrará <strong>{{ form.cantidad || 0 }}g</strong> de
                  <strong>{{ loteActivo.genetica?.nombre || loteActivo.codigo }}</strong>
                  — quedará pendiente hasta que el admin lo apruebe.
                </div>
              </div>

              <!-- Toast inline -->
              <Transition name="mnd-ok">
                <div v-if="okMsg" class="mnd__ok">
                  <i class="bi bi-check-circle-fill"></i> {{ okMsg }}
                </div>
              </Transition>
              <div v-if="errMsg" class="mnd__err">
                <i class="bi bi-exclamation-triangle-fill"></i> {{ errMsg }}
              </div>
            </template>
          </section>

        </div>

        <!-- ── COLUMNA LATERAL: historial ── -->
        <div class="mnd__col-aside">
          <section class="mnd__card">
            <div class="mnd__card-header">
              <div class="mnd__card-icon"><i class="bi bi-clock-history"></i></div>
              <h2 class="mnd__card-title">Mis registros</h2>
              <button class="mnd__refresh" @click="cargarMovimientos" title="Actualizar">
                <i class="bi bi-arrow-clockwise"></i>
              </button>
            </div>

            <div v-if="loadingMovs" class="mnd__loading mnd__loading--sm">
              <div class="mnd__spinner"></div>
            </div>
            <div v-else-if="movimientos.length === 0" class="mnd__empty-movs">
              Sin registros todavía.
            </div>
            <div v-else class="mnd__movs">
              <div v-for="m in movimientos" :key="m.id" class="mnd__mov">
                <div class="mnd__mov-top">
                  <span class="mnd__mov-gen">{{ m.genetica_nombre || '—' }}</span>
                  <span class="mnd__mov-estado" :class="`mnd__mov-estado--${m.estado}`">
                    {{ ESTADOS_MOV[m.estado] || m.estado }}
                  </span>
                </div>
                <div class="mnd__mov-meta">
                  <strong>{{ m.cantidad }}g</strong>
                  <span v-if="m.lote_codigo"> · {{ m.lote_codigo }}</span>
                  <span class="mnd__mov-fecha"> · {{ formatFecha(m.created_at) }}</span>
                </div>
                <div v-if="m.nota_rechazo" class="mnd__mov-rechazo">
                  <i class="bi bi-x-circle-fill"></i> {{ m.nota_rechazo }}
                </div>
              </div>
            </div>
          </section>
        </div>

      </div>
    </template>

  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useAuthStore } from '../../stores/auth'
import { listLotes, listSalas, agregarStock, getMisMovimientos } from '../../lib/api'

const auth = useAuthStore()

const loading     = ref(true)
const loadingMovs = ref(false)
const enviando    = ref(false)
const sala        = ref(null)
const lotes       = ref([])
const movimientos = ref([])
const okMsg       = ref('')
const errMsg      = ref('')

const form = ref({ lote_id: null, cantidad: null })

const hora   = new Date().getHours()
const saludo = hora < 12 ? 'Buenos días' : hora < 19 ? 'Buenas tardes' : 'Buenas noches'
const hoy    = new Date().toLocaleDateString('es-AR', {
  weekday: 'long', day: 'numeric', month: 'long', year: 'numeric'
}).replace(/^\w/, c => c.toUpperCase())

const ESTADOS = {
  semilla:    { label: 'Semilla',    color: '#92400e', bg: 'rgba(146,64,14,.12)'  },
  vegetativo: { label: 'Vegetativo', color: '#15803d', bg: 'rgba(21,128,61,.12)'  },
  floracion:  { label: 'Floración',  color: '#7c3aed', bg: 'rgba(124,58,237,.12)' },
  cosecha:    { label: 'Cosecha',    color: '#b45309', bg: 'rgba(180,83,9,.12)'   },
  curado:     { label: 'Curado',     color: '#0369a1', bg: 'rgba(3,105,161,.12)'  },
  finalizado: { label: 'Finalizado', color: '#475569', bg: 'rgba(71,85,105,.12)'  },
}
const ESTADOS_MOV = {
  pendiente: 'Pendiente',
  aprobado:  'Aprobado',
  rechazado: 'Rechazado',
}

const lotesDisponibles = computed(() => lotes.value)
const loteActivo       = computed(() => lotes.value.find(l => l.id === form.value.lote_id) || null)

function estadoStyle(estado) {
  const e = ESTADOS[estado] || ESTADOS.finalizado
  return { background: e.bg, color: e.color }
}
function formatFecha(d) {
  if (!d) return '—'
  return new Date(d).toLocaleDateString('es-AR', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' })
}

function seleccionarLote(lote) {
  form.value.lote_id  = lote.id
  form.value.cantidad = null
}

async function cargarMovimientos() {
  loadingMovs.value = true
  try {
    const { data } = await getMisMovimientos()
    movimientos.value = data || []
  } catch { movimientos.value = [] }
  finally { loadingMovs.value = false }
}

async function enviar() {
  if (!form.value.lote_id || !form.value.cantidad || form.value.cantidad <= 0) return
  enviando.value = true
  errMsg.value   = ''
  okMsg.value    = ''
  try {
    const lote = loteActivo.value
    const sedeId = sala.value?.sede?.id
    if (!sedeId) throw new Error('Sin sede')

    await agregarStock(sedeId, {
      producto:    'flores',
      cantidad:    form.value.cantidad,
      lote_id:     lote.id,
      genetica_id: lote.genetica?.id || undefined,
      motivo:      `Manicura — lote ${lote.codigo}`,
    })

    okMsg.value      = `${form.value.cantidad}g registrados. Pendiente de aprobación.`
    form.value       = { lote_id: null, cantidad: null }
    setTimeout(() => okMsg.value = '', 4000)
    await cargarMovimientos()
  } catch (e) {
    errMsg.value = e.response?.data?.errors?.[0] || 'Error al registrar'
  } finally { enviando.value = false }
}

onMounted(async () => {
  try {
    const [salasRes, lotesRes] = await Promise.all([
      listSalas(),
      listLotes(),
    ])
    sala.value  = (salasRes.data || [])[0] || null
    lotes.value = lotesRes.data || []
    await cargarMovimientos()
  } catch {}
  finally { loading.value = false }
})
</script>

<style scoped>
.mnd {
  padding: 2rem 1.75rem 3rem;
  max-width: 1100px;
  margin: 0 auto;
  font-family: system-ui, -apple-system, sans-serif;
  color: #0f172a;
}
@media (max-width: 640px) { .mnd { padding: 1.25rem 1rem 2rem; } }

/* Header */
.mnd__header {
  display: flex; align-items: flex-start; justify-content: space-between;
  gap: 1rem; margin-bottom: 2rem; flex-wrap: wrap;
}
.mnd__greeting { font-size: 1.65rem; font-weight: 800; margin: 0 0 .2rem; letter-spacing: -.04em; color: #0f172a; }
.mnd__date { font-size: .82rem; color: #64748b; margin: 0; }
.mnd__sala-badge {
  display: flex; align-items: center; gap: .4rem;
  background: rgba(124,58,237,.08); border: 1px solid rgba(124,58,237,.2);
  color: #7c3aed; padding: .55rem 1rem; border-radius: 10px;
  font-size: .85rem; font-weight: 600;
}
.mnd__sala-sede { color: #a78bfa; font-weight: 400; }

/* Loading */
.mnd__loading { display: flex; align-items: center; justify-content: center; gap: .75rem; padding: 5rem; color: #94a3b8; }
.mnd__loading--sm { padding: 1.5rem; }
.mnd__spinner { width: 22px; height: 22px; border: 2.5px solid #e2e8f0; border-top-color: #7c3aed; border-radius: 50%; animation: mnd-spin .6s linear infinite; flex-shrink: 0; }
.mnd__spinner--sm { width: 14px; height: 14px; border-width: 2px; border-top-color: #fff; border-color: rgba(255,255,255,.3); }
@keyframes mnd-spin { to { transform: rotate(360deg); } }

/* Empty states */
.mnd__empty-sala { text-align: center; padding: 5rem 1rem; }
.mnd__empty-icon { font-size: 3rem; color: #94a3b8; margin-bottom: 1rem; }
.mnd__empty-sala h3 { font-size: 1.1rem; font-weight: 700; margin: 0 0 .5rem; }
.mnd__empty-sala p { font-size: .875rem; color: #64748b; margin: 0; }
.mnd__empty-lotes { display: flex; align-items: center; gap: .6rem; padding: 1.25rem; background: #f8fafc; border: 1px dashed #e2e8f0; border-radius: 10px; color: #64748b; font-size: .875rem; }
.mnd__empty-movs { padding: 1.25rem; text-align: center; color: #94a3b8; font-size: .82rem; }

/* Layout */
.mnd__layout { display: grid; grid-template-columns: 1fr 320px; gap: 1.5rem; align-items: start; }
@media (max-width: 900px) { .mnd__layout { grid-template-columns: 1fr; } }

/* Cards */
.mnd__card {
  background: #fff; border: 1px solid #e2e8f0; border-radius: 16px;
  padding: 1.5rem; margin-bottom: 1.25rem;
}
.mnd__card--accent { border-color: rgba(124,58,237,.2); }
.mnd__card:last-child { margin-bottom: 0; }
.mnd__col-aside .mnd__card { margin-bottom: 0; }

.mnd__card-header {
  display: flex; align-items: center; gap: .75rem; margin-bottom: 1.25rem;
}
.mnd__card-icon {
  width: 36px; height: 36px; border-radius: 10px; flex-shrink: 0;
  display: flex; align-items: center; justify-content: center;
  background: #f8fafc; color: #64748b; font-size: 1rem;
}
.mnd__card-icon--purple { background: rgba(124,58,237,.1); color: #7c3aed; }
.mnd__card-title { font-size: 1rem; font-weight: 700; color: #0f172a; margin: 0; flex: 1; }
.mnd__refresh { background: none; border: none; color: #94a3b8; cursor: pointer; padding: .25rem; border-radius: 6px; transition: color .15s; }
.mnd__refresh:hover { color: #7c3aed; }

/* Steps */
.mnd__step { margin-bottom: 1.25rem; }
.mnd__step-label { display: flex; align-items: center; gap: .5rem; font-size: .82rem; font-weight: 600; color: #475569; margin-bottom: .75rem; text-transform: uppercase; letter-spacing: .05em; }
.mnd__step-num { width: 20px; height: 20px; border-radius: 50%; background: #7c3aed; color: #fff; font-size: .65rem; font-weight: 800; display: flex; align-items: center; justify-content: center; }

/* Lotes grid */
.mnd__lotes-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(200px, 1fr)); gap: .75rem; }
.mnd__lote-card {
  background: #f8fafc; border: 1.5px solid #e2e8f0; border-radius: 12px;
  padding: .875rem 1rem; text-align: left; cursor: pointer;
  transition: all .15s;
}
.mnd__lote-card:hover { border-color: #a78bfa; background: rgba(124,58,237,.03); }
.mnd__lote-card--active { border-color: #7c3aed; background: rgba(124,58,237,.06); box-shadow: 0 0 0 3px rgba(124,58,237,.12); }
.mnd__lote-top { display: flex; align-items: center; justify-content: space-between; gap: .4rem; margin-bottom: .35rem; }
.mnd__lote-codigo { font-size: .875rem; font-weight: 700; color: #0f172a; }
.mnd__lote-estado { font-size: .65rem; font-weight: 700; padding: .2em .55em; border-radius: 999px; white-space: nowrap; }
.mnd__lote-gen { font-size: .82rem; color: #475569; font-weight: 600; margin-bottom: .2rem; }
.mnd__lote-dias { font-size: .72rem; color: #94a3b8; }

/* Cantidad row */
.mnd__cant-row { display: flex; align-items: center; gap: .75rem; flex-wrap: wrap; }
.mnd__cant-wrap { display: flex; align-items: center; }
.mnd__cant-input {
  width: 120px; background: #f8fafc; border: 1.5px solid #e2e8f0;
  border-radius: 10px 0 0 10px; padding: .65rem .875rem;
  font-size: 1.1rem; font-weight: 700; color: #0f172a;
  outline: none; transition: border .15s;
}
.mnd__cant-input:focus { border-color: #7c3aed; background: #fff; }
.mnd__cant-suffix {
  background: #ede9fe; border: 1.5px solid #e2e8f0; border-left: none;
  border-radius: 0 10px 10px 0; padding: .65rem .875rem;
  font-size: .875rem; font-weight: 700; color: #7c3aed;
}

.mnd__btn-primary {
  display: inline-flex; align-items: center; gap: .4rem;
  background: #7c3aed; color: #fff; border: none;
  padding: .65rem 1.25rem; border-radius: 10px;
  font-size: .875rem; font-weight: 600; cursor: pointer;
  transition: background .15s; white-space: nowrap;
}
.mnd__btn-primary:hover:not(:disabled) { background: #6d28d9; }
.mnd__btn-primary:disabled { opacity: .5; cursor: not-allowed; }

.mnd__preview {
  display: flex; align-items: flex-start; gap: .5rem;
  margin-top: .75rem; padding: .75rem 1rem;
  background: rgba(124,58,237,.05); border: 1px solid rgba(124,58,237,.15);
  border-radius: 10px; font-size: .82rem; color: #475569;
  line-height: 1.5;
}

/* Feedback */
.mnd__ok {
  display: flex; align-items: center; gap: .5rem;
  margin-top: .75rem; padding: .75rem 1rem;
  background: #f0fdf4; border: 1px solid #bbf7d0;
  border-radius: 10px; font-size: .875rem; color: #15803d; font-weight: 500;
}
.mnd__err {
  display: flex; align-items: center; gap: .5rem;
  margin-top: .75rem; padding: .75rem 1rem;
  background: #fef2f2; border: 1px solid #fecaca;
  border-radius: 10px; font-size: .875rem; color: #dc2626; font-weight: 500;
}
.mnd-ok-enter-active, .mnd-ok-leave-active { transition: all .25s ease; }
.mnd-ok-enter-from, .mnd-ok-leave-to { opacity: 0; transform: translateY(-6px); }

/* Historial */
.mnd__movs { display: flex; flex-direction: column; gap: .6rem; }
.mnd__mov {
  padding: .75rem .875rem; background: #f8fafc;
  border: 1px solid #e2e8f0; border-radius: 10px;
}
.mnd__mov-top { display: flex; align-items: center; justify-content: space-between; gap: .4rem; margin-bottom: .25rem; }
.mnd__mov-gen { font-size: .82rem; font-weight: 700; color: #0f172a; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.mnd__mov-estado { font-size: .65rem; font-weight: 700; padding: .2em .55em; border-radius: 999px; flex-shrink: 0; }
.mnd__mov-estado--pendiente { background: #fef3c7; color: #b45309; }
.mnd__mov-estado--aprobado  { background: #dcfce7; color: #15803d; }
.mnd__mov-estado--rechazado { background: #fee2e2; color: #dc2626; }
.mnd__mov-meta { font-size: .78rem; color: #64748b; }
.mnd__mov-fecha { color: #94a3b8; }
.mnd__mov-rechazo {
  display: flex; align-items: flex-start; gap: .35rem;
  margin-top: .35rem; font-size: .72rem; color: #dc2626;
}
</style>
