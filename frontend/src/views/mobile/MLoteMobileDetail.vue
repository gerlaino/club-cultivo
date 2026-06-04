<template>
  <div class="mlot" v-if="lote">

    <!-- Hero -->
    <div class="mlot__hero" :style="{ background: estadoGradient(lote.estado) }">
      <div class="mlot__hero-estado">{{ estadoEmoji(lote.estado) }} {{ estadoLabel(lote.estado) }}</div>
      <h2 class="mlot__hero-codigo">{{ lote.codigo }}</h2>
      <div class="mlot__hero-meta">
        <span>{{ lote.genetica?.nombre || '—' }}</span>
        <span class="mlot__sep">·</span>
        <span>{{ lote.plants_count || 0 }} plantas</span>
        <template v-if="lote.sala?.nombre">
          <span class="mlot__sep">·</span>
          <span>{{ lote.sala.nombre }}</span>
        </template>
      </div>
    </div>

    <!-- Acciones -->
    <div class="mlot__actions">
      <button class="mlot__btn-registrar" @click="showRegistrar = true">
        <i class="bi bi-pencil-square"></i>
        Registrar actividad
      </button>
      <div class="mlot__acciones-wrap" v-click-outside="() => showAcciones = false">
        <button class="mlot__btn-acciones" @click="showAcciones = !showAcciones">
          <i class="bi bi-three-dots-vertical"></i>
          Acciones
        </button>
        <div v-if="showAcciones" class="mlot__menu">
          <button class="mlot__menu-item" @click="showNota = true; showAcciones = false">
            <i class="bi bi-journal-text"></i> Agregar nota
          </button>
        </div>
      </div>
    </div>

    <!-- Plantas -->
    <div class="mlot__section-title">Plantas del lote</div>
    <div v-if="loadingPlantas" class="mlot__loading-plantas">Cargando…</div>
    <div v-else-if="!plantas.length" class="mlot__empty">Sin plantas registradas</div>
    <div v-else class="mlot__list">
      <RouterLink
        v-for="p in plantas"
        :key="p.id"
        :to="`/m/planta/${p.id}`"
        class="mlot__card"
      >
        <div class="mlot__card-dot" :style="{ background: plantaColor(p.state) }"></div>
        <div class="mlot__card-info">
          <div class="mlot__card-nombre">{{ p.nombre || p.codigo_qr || `Planta #${p.id}` }}</div>
        </div>
        <span class="mlot__planta-estado" :style="{ color: plantaColor(p.state) }">
          {{ plantaLabel(p.state) }}
        </span>
        <i class="bi bi-chevron-right mlot__chevron"></i>
      </RouterLink>
    </div>

    <!-- Paginador plantas -->
    <div v-if="totalPaginas > 1" class="mlot__pager">
      <button :disabled="pagina <= 1" @click="pagina--" class="mlot__pager-btn"><i class="bi bi-chevron-left"></i></button>
      <span class="mlot__pager-info">{{ pagina }} / {{ totalPaginas }}</span>
      <button :disabled="pagina >= totalPaginas" @click="pagina++" class="mlot__pager-btn"><i class="bi bi-chevron-right"></i></button>
    </div>

    <!-- Sheet registrar actividad en lote -->
    <Teleport to="body">
      <div v-if="showRegistrar" class="mlot__overlay" @click.self="showRegistrar = false">
        <div class="mlot__sheet">
          <div class="mlot__sheet-handle"></div>
          <div class="mlot__sheet-header">
            <h3 class="mlot__sheet-title">📦 Registrar actividad</h3>
            <button class="mlot__sheet-close" @click="showRegistrar = false"><i class="bi bi-x-lg"></i></button>
          </div>
          <div class="mlot__sheet-body">
            <div class="mlot__field">
              <label class="mlot__label">Tipo de actividad</label>
              <select v-model="actForm.tipo" class="mlot__input">
                <option value="observacion">Observación general</option>
                <option value="nutricion">Nutrición</option>
                <option value="riego">Riego</option>
                <option value="control_plagas">Control de plagas</option>
                <option value="defoliacion">Defoliación / Poda</option>
                <option value="otro">Otro</option>
              </select>
            </div>
            <div class="mlot__field">
              <label class="mlot__label">Descripción</label>
              <textarea v-model="actForm.descripcion" class="mlot__input mlot__textarea" rows="3" placeholder="Detallá la actividad realizada…"></textarea>
            </div>
            <div v-if="actError" class="mlot__error">{{ actError }}</div>
            <button class="mlot__btn-confirmar" :disabled="savingAct" @click="guardarActividad">
              <i v-if="!savingAct" class="bi bi-check2-circle"></i>
              {{ savingAct ? 'Guardando…' : 'Guardar' }}
            </button>
          </div>
        </div>
      </div>

      <!-- Sheet nota -->
      <div v-if="showNota" class="mlot__overlay" @click.self="showNota = false">
        <div class="mlot__sheet">
          <div class="mlot__sheet-handle"></div>
          <div class="mlot__sheet-header">
            <h3 class="mlot__sheet-title">📝 Nota del lote</h3>
            <button class="mlot__sheet-close" @click="showNota = false"><i class="bi bi-x-lg"></i></button>
          </div>
          <div class="mlot__sheet-body">
            <div class="mlot__field">
              <label class="mlot__label">Nota</label>
              <textarea v-model="notaContenido" class="mlot__input mlot__textarea" rows="4" placeholder="Escribí tu observación…"></textarea>
            </div>
            <div v-if="notaError" class="mlot__error">{{ notaError }}</div>
            <button class="mlot__btn-confirmar" :disabled="savingNota" @click="guardarNota">
              <i v-if="!savingNota" class="bi bi-check2-circle"></i>
              {{ savingNota ? 'Guardando…' : 'Guardar nota' }}
            </button>
          </div>
        </div>
      </div>
    </Teleport>
  </div>
  <div v-else-if="loading" class="mlot mlot--loading"><i class="bi bi-arrow-repeat mlot__spin"></i></div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { getLote, listPlants, createLoteEvento, createLoteNota } from '../../lib/api'
import { useToast } from '../../composables/useToast'

const route = useRoute()
const toast = useToast()
const id    = Number(route.params.id)

const lote    = ref(null)
const plantas = ref([])
const loading         = ref(true)
const loadingPlantas  = ref(false)
const showRegistrar   = ref(false)
const showNota        = ref(false)
const showAcciones    = ref(false)
const savingAct       = ref(false)
const savingNota      = ref(false)
const actError        = ref(null)
const notaError       = ref(null)
const notaContenido   = ref('')
const pagina          = ref(1)
const POR_PAG         = 12

const actForm = ref({ tipo: 'observacion', descripcion: '' })

const EG = { vegetativo:'linear-gradient(135deg,#0f2417,#1b5e20)', floracion:'linear-gradient(135deg,#1c1028,#4a1d96)', cosecha:'linear-gradient(135deg,#1c0000,#7f1d1d)', en_manicura:'linear-gradient(135deg,#1c1000,#78350f)', curado:'linear-gradient(135deg,#0c1a33,#1d4ed8)' }
const EE = { semilla:'🌱', esqueje:'🪴', vegetativo:'🍃', floracion:'🌸', cosecha:'✂️', en_manicura:'✂️', secado:'💨', curado:'🫙' }
const EL = { semilla:'Semilla', esqueje:'Esqueje', vegetativo:'Vegetativo', floracion:'Floración', cosecha:'Cosecha', en_manicura:'Manicura', secado:'Secado', curado:'Curado' }
const PC = { semilla:'#64748b', esqueje:'#0891b2', vegetativo:'#16a34a', floracion:'#9333ea', cosecha:'#dc2626', en_manicura:'#d97706', secado:'#d97706', curado:'#2563eb' }
const PL = { semilla:'Semilla', esqueje:'Esqueje', vegetativo:'Veget.', floracion:'Florac.', cosecha:'Cosecha', en_manicura:'Manicura', secado:'Secado', curado:'Curado', cosechado:'Cosechado' }

const estadoGradient = e => EG[e] || 'linear-gradient(135deg,#0f172a,#1e293b)'
const estadoEmoji    = e => EE[e] || '📦'
const estadoLabel    = e => EL[e] || e || '—'
const plantaColor    = e => PC[e] || '#64748b'
const plantaLabel    = e => PL[e] || e || '—'

const totalPaginas   = computed(() => Math.max(1, Math.ceil(plantas.value.length / POR_PAG)))
const plantasPagina  = computed(() => {
  const s = (pagina.value - 1) * POR_PAG
  return plantas.value.slice(s, s + POR_PAG)
})

async function guardarActividad() {
  savingAct.value = true; actError.value = null
  try {
    await createLoteEvento(id, {
      tipo:        actForm.value.tipo,
      descripcion: actForm.value.descripcion,
    })
    toast.success('Actividad registrada')
    showRegistrar.value = false
    actForm.value = { tipo: 'observacion', descripcion: '' }
  } catch (e) {
    actError.value = e?.response?.data?.error || 'Error al guardar'
  } finally { savingAct.value = false }
}

async function guardarNota() {
  if (!notaContenido.value.trim()) { notaError.value = 'Escribí algo'; return }
  savingNota.value = true; notaError.value = null
  try {
    await createLoteNota(id, { nota: { contenido: notaContenido.value } })
    toast.success('Nota guardada')
    showNota.value = false
    notaContenido.value = ''
  } catch { notaError.value = 'Error al guardar' } finally { savingNota.value = false }
}

onMounted(async () => {
  try {
    const [loteRes, plantasRes] = await Promise.all([
      getLote(id),
      listPlants({ lote_id: id }),
    ])
    lote.value    = loteRes.data
    plantas.value = plantasRes.data?.data || plantasRes.data || []
  } catch {} finally { loading.value = false }
})
</script>

<style scoped>
.mlot { padding: 0 0 2rem; }
.mlot--loading { display: flex; align-items: center; justify-content: center; min-height: 40vh; }
.mlot__spin { font-size: 2rem; color: #94a3b8; animation: spin .8s linear infinite; }
@keyframes spin { to { transform: rotate(360deg); } }
.mlot__hero { padding: 1.25rem 1rem 1.1rem; }
.mlot__hero-estado { font-size: .72rem; font-weight: 700; color: rgba(255,255,255,.7); margin-bottom: .4rem; text-transform: uppercase; letter-spacing: .06em; }
.mlot__hero-codigo { font-size: 1.3rem; font-weight: 800; color: #fff; margin: 0 0 .3rem; font-family: monospace; }
.mlot__hero-meta   { font-size: .78rem; color: rgba(255,255,255,.6); display: flex; gap: .4rem; flex-wrap: wrap; }
.mlot__sep { opacity: .4; }
.mlot__actions { display: flex; gap: .75rem; padding: 1rem; }
.mlot__btn-registrar { flex: 1; display: flex; align-items: center; justify-content: center; gap: .5rem; background: #1b5e20; color: #fff; border: none; padding: .875rem; border-radius: 12px; font-size: .95rem; font-weight: 700; cursor: pointer; }
.mlot__acciones-wrap { position: relative; }
.mlot__btn-acciones { display: flex; align-items: center; gap: .4rem; background: #fff; color: #374151; border: 1.5px solid #e2e8f0; padding: .875rem 1rem; border-radius: 12px; font-size: .875rem; font-weight: 600; cursor: pointer; white-space: nowrap; }
.mlot__menu { position: absolute; top: calc(100% + 6px); right: 0; z-index: 50; background: #fff; border: 1px solid #e2e8f0; border-radius: 12px; box-shadow: 0 8px 24px rgba(0,0,0,.12); overflow: hidden; min-width: 170px; }
.mlot__menu-item { width: 100%; display: flex; align-items: center; gap: .6rem; padding: .85rem 1rem; border: none; background: none; text-align: left; font-size: .875rem; color: #374151; cursor: pointer; }
.mlot__menu-item:hover { background: #f8fafc; }
.mlot__section-title { font-size: .7rem; font-weight: 700; color: #94a3b8; text-transform: uppercase; letter-spacing: .06em; padding: .75rem 1rem .5rem; }
.mlot__loading-plantas, .mlot__empty { padding: .75rem 1rem; color: #94a3b8; font-size: .82rem; text-align: center; }
.mlot__list { display: flex; flex-direction: column; gap: .4rem; padding: 0 1rem; }
.mlot__card { display: flex; align-items: center; gap: .75rem; background: #fff; border-radius: 12px; padding: .8rem; box-shadow: 0 1px 3px rgba(0,0,0,.06); text-decoration: none; -webkit-tap-highlight-color: transparent; }
.mlot__card-dot { width: 9px; height: 9px; border-radius: 50%; flex-shrink: 0; }
.mlot__card-info { flex: 1; min-width: 0; }
.mlot__card-nombre { font-size: .875rem; font-weight: 600; color: #0f172a; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.mlot__planta-estado { font-size: .68rem; font-weight: 700; white-space: nowrap; flex-shrink: 0; }
.mlot__chevron { color: #d1d5db; font-size: .75rem; flex-shrink: 0; }
.mlot__pager { display: flex; align-items: center; justify-content: center; gap: .75rem; padding: .875rem; }
.mlot__pager-btn { background: #fff; border: 1.5px solid #e2e8f0; border-radius: 9px; width: 36px; height: 36px; display: flex; align-items: center; justify-content: center; font-size: .875rem; color: #374151; cursor: pointer; }
.mlot__pager-btn:disabled { opacity: .4; cursor: not-allowed; }
.mlot__pager-info { font-size: .8rem; color: #64748b; font-weight: 600; min-width: 44px; text-align: center; }
.mlot__overlay { position: fixed; inset: 0; z-index: 200; background: rgba(0,0,0,.5); display: flex; align-items: flex-end; }
.mlot__sheet { width: 100%; background: #fff; border-radius: 20px 20px 0 0; max-height: 90vh; overflow-y: auto; }
.mlot__sheet-handle { width: 40px; height: 4px; background: #e2e8f0; border-radius: 999px; margin: .75rem auto .25rem; }
.mlot__sheet-header { display: flex; align-items: center; justify-content: space-between; padding: .5rem 1.25rem 1rem; }
.mlot__sheet-title { font-size: 1rem; font-weight: 700; margin: 0; }
.mlot__sheet-close { background: none; border: none; color: #94a3b8; font-size: 1rem; cursor: pointer; }
.mlot__sheet-body { padding: 0 1.25rem 2.5rem; display: flex; flex-direction: column; gap: .875rem; }
.mlot__field { display: flex; flex-direction: column; gap: .3rem; }
.mlot__label { font-size: .72rem; font-weight: 700; color: #374151; text-transform: uppercase; letter-spacing: .04em; }
.mlot__input { background: #f8fafc; border: 1.5px solid #e2e8f0; border-radius: 9px; padding: .65rem .875rem; font-size: .9rem; color: #0f172a; outline: none; width: 100%; box-sizing: border-box; }
.mlot__input:focus { border-color: #1b5e20; }
.mlot__textarea { resize: none; font-family: inherit; }
.mlot__error { background: #fef2f2; color: #dc2626; border: 1px solid #fecaca; border-radius: 8px; padding: .5rem .75rem; font-size: .8rem; }
.mlot__btn-confirmar { width: 100%; display: flex; align-items: center; justify-content: center; gap: .5rem; background: #1b5e20; color: #fff; border: none; padding: .9rem; border-radius: 12px; font-size: .95rem; font-weight: 700; cursor: pointer; }
.mlot__btn-confirmar:disabled { opacity: .6; }
</style>
