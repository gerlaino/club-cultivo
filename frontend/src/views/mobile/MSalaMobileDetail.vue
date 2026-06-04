<template>
  <div class="msal" v-if="sala">

    <!-- Hero -->
    <div class="msal__hero" :style="{ background: kindGradient(sala.kind) }">
      <div class="msal__hero-kind">{{ kindEmoji(sala.kind) }} {{ kindLabel(sala.kind) }}</div>
      <h2 class="msal__hero-nombre">{{ sala.nombre }}</h2>
      <div class="msal__hero-meta">
        <span>{{ sala.sede?.nombre }}</span>
        <span v-if="lotes.length" class="msal__sep">·</span>
        <span v-if="lotes.length">{{ lotes.length }} lote{{ lotes.length !== 1 ? 's' : '' }}</span>
      </div>
    </div>

    <!-- Botón registrar lectura ambiental -->
    <div class="msal__actions">
      <button class="msal__btn-registrar" @click="showLectura = true">
        <i class="bi bi-thermometer-half"></i>
        Registrar lectura
      </button>
      <div class="msal__acciones-wrap" v-click-outside="() => showAcciones = false">
        <button class="msal__btn-acciones" @click="showAcciones = !showAcciones">
          <i class="bi bi-three-dots-vertical"></i>
          Acciones
        </button>
        <div v-if="showAcciones" class="msal__menu">
          <button class="msal__menu-item" @click="showNota = true; showAcciones = false">
            <i class="bi bi-journal-text"></i> Agregar nota
          </button>
        </div>
      </div>
    </div>

    <!-- Lotes de esta sala -->
    <div class="msal__section-title">Lotes activos</div>
    <div v-if="!lotes.length" class="msal__empty">Sin lotes activos</div>
    <div v-else class="msal__list">
      <RouterLink
        v-for="lote in lotes"
        :key="lote.id"
        :to="`/m/lote-m/${lote.id}`"
        class="msal__card"
      >
        <div class="msal__card-stripe" :style="{ background: estadoColor(lote.estado) }"></div>
        <div class="msal__card-body">
          <div class="msal__card-top">
            <span class="msal__codigo">{{ lote.codigo }}</span>
            <span class="msal__badge" :style="{ background: estadoColor(lote.estado)+'20', color: estadoColor(lote.estado) }">
              {{ estadoLabel(lote.estado) }}
            </span>
          </div>
          <div class="msal__card-meta">
            <span>{{ lote.genetica?.nombre || '—' }}</span>
            <span class="msal__dot">·</span>
            <span>{{ lote.plants_count || 0 }} plantas</span>
          </div>
        </div>
        <i class="bi bi-chevron-right msal__chevron"></i>
      </RouterLink>
    </div>

    <!-- Sheet lectura ambiental -->
    <Teleport to="body">
      <div v-if="showLectura" class="msal__overlay" @click.self="showLectura = false">
        <div class="msal__sheet">
          <div class="msal__sheet-handle"></div>
          <div class="msal__sheet-header">
            <h3 class="msal__sheet-title">🌡️ Lectura ambiental</h3>
            <button class="msal__sheet-close" @click="showLectura = false"><i class="bi bi-x-lg"></i></button>
          </div>
          <div class="msal__sheet-body">
            <div class="msal__row2">
              <div class="msal__field">
                <label class="msal__label">Temperatura (°C)</label>
                <input v-model.number="lecturaForm.temperatura" type="number" step="0.1" class="msal__input" placeholder="—" />
              </div>
              <div class="msal__field">
                <label class="msal__label">Humedad (%)</label>
                <input v-model.number="lecturaForm.humedad" type="number" step="0.1" min="0" max="100" class="msal__input" placeholder="—" />
              </div>
            </div>
            <div class="msal__row2">
              <div class="msal__field">
                <label class="msal__label">CO₂ (ppm)</label>
                <input v-model.number="lecturaForm.co2" type="number" step="1" class="msal__input" placeholder="—" />
              </div>
              <div class="msal__field">
                <label class="msal__label">VPD (kPa)</label>
                <input v-model.number="lecturaForm.vpd" type="number" step="0.01" class="msal__input" placeholder="—" />
              </div>
            </div>
            <div class="msal__field">
              <label class="msal__label">Notas</label>
              <textarea v-model="lecturaForm.notas" class="msal__input msal__textarea" rows="2" placeholder="Observaciones…"></textarea>
            </div>
            <div v-if="lecturaError" class="msal__error">{{ lecturaError }}</div>
            <button class="msal__btn-confirmar" :disabled="savingLectura" @click="guardarLectura">
              <i v-if="!savingLectura" class="bi bi-check2-circle"></i>
              {{ savingLectura ? 'Guardando…' : 'Guardar lectura' }}
            </button>
          </div>
        </div>
      </div>

      <!-- Sheet nota -->
      <div v-if="showNota" class="msal__overlay" @click.self="showNota = false">
        <div class="msal__sheet">
          <div class="msal__sheet-handle"></div>
          <div class="msal__sheet-header">
            <h3 class="msal__sheet-title">📝 Nota de sala</h3>
            <button class="msal__sheet-close" @click="showNota = false"><i class="bi bi-x-lg"></i></button>
          </div>
          <div class="msal__sheet-body">
            <div class="msal__field">
              <label class="msal__label">Nota</label>
              <textarea v-model="notaContenido" class="msal__input msal__textarea" rows="4" placeholder="Escribí tu observación…" autofocus></textarea>
            </div>
            <div v-if="notaError" class="msal__error">{{ notaError }}</div>
            <button class="msal__btn-confirmar" :disabled="savingNota" @click="guardarNota">
              <i v-if="!savingNota" class="bi bi-check2-circle"></i>
              {{ savingNota ? 'Guardando…' : 'Guardar nota' }}
            </button>
          </div>
        </div>
      </div>
    </Teleport>
  </div>
  <div v-else-if="loading" class="msal msal--loading"><i class="bi bi-arrow-repeat msal__spin"></i></div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { getSala, listLotes, createLecturaAmbiental, createSalaNota } from '../../lib/api'
import { useToast } from '../../composables/useToast'

const route = useRoute()
const toast = useToast()
const id    = Number(route.params.id)

const sala    = ref(null)
const lotes   = ref([])
const loading = ref(true)

const showLectura   = ref(false)
const showNota      = ref(false)
const showAcciones  = ref(false)
const savingLectura = ref(false)
const savingNota    = ref(false)
const lecturaError  = ref(null)
const notaError     = ref(null)
const notaContenido = ref('')
const lecturaForm   = ref({ temperatura: null, humedad: null, co2: null, vpd: null, notas: '' })

const KIND_GRADIENT = {
  vegetativo: 'linear-gradient(135deg,#0f2417,#1b5e20)',
  floracion:  'linear-gradient(135deg,#1c1028,#4a1d96)',
  cosecha:    'linear-gradient(135deg,#1c0000,#7f1d1d)',
  manicura:   'linear-gradient(135deg,#1c1500,#78350f)',
}
const KIND_EMOJI = { vegetativo:'🍃', floracion:'🌸', cosecha:'🌾', manicura:'✂️' }
const KIND_LABEL = { vegetativo:'Vegetativo', floracion:'Floración', cosecha:'Cosecha', manicura:'Manicura' }
const EC = { semilla:'#64748b', esqueje:'#0891b2', vegetativo:'#16a34a', floracion:'#9333ea', cosecha:'#dc2626', en_manicura:'#d97706', secado:'#d97706', curado:'#2563eb' }
const EL = { semilla:'Semilla', esqueje:'Esqueje', vegetativo:'Vegetativo', floracion:'Floración', cosecha:'Cosecha', en_manicura:'Manicura', secado:'Secado', curado:'Curado' }

const kindGradient = k => KIND_GRADIENT[k] || 'linear-gradient(135deg,#0f172a,#1e293b)'
const kindEmoji    = k => KIND_EMOJI[k] || '🏠'
const kindLabel    = k => KIND_LABEL[k] || k || '—'
const estadoColor  = e => EC[e] || '#64748b'
const estadoLabel  = e => EL[e] || e || '—'

async function guardarLectura() {
  savingLectura.value = true; lecturaError.value = null
  try {
    await createLecturaAmbiental(id, {
      temperatura: lecturaForm.value.temperatura || undefined,
      humedad:     lecturaForm.value.humedad     || undefined,
      co2:         lecturaForm.value.co2         || undefined,
      vpd:         lecturaForm.value.vpd         || undefined,
      notas:       lecturaForm.value.notas       || undefined,
    })
    toast.success('Lectura registrada')
    showLectura.value = false
    lecturaForm.value = { temperatura: null, humedad: null, co2: null, vpd: null, notas: '' }
  } catch (e) {
    lecturaError.value = e?.response?.data?.error || 'Error al guardar'
  } finally { savingLectura.value = false }
}

async function guardarNota() {
  if (!notaContenido.value.trim()) { notaError.value = 'Escribí algo antes de guardar'; return }
  savingNota.value = true; notaError.value = null
  try {
    await createSalaNota(id, { nota: { contenido: notaContenido.value } })
    toast.success('Nota guardada')
    showNota.value = false
    notaContenido.value = ''
  } catch { notaError.value = 'Error al guardar' } finally { savingNota.value = false }
}

onMounted(async () => {
  try {
    const [salaRes, lotesRes] = await Promise.all([getSala(id), listLotes()])
    sala.value  = salaRes.data
    lotes.value = (lotesRes.data || []).filter(l => l.sala_id === id && l.estado !== 'finalizado')
  } catch {} finally { loading.value = false }
})
</script>

<style scoped>
.msal { padding: 0 0 2rem; }
.msal--loading { display: flex; align-items: center; justify-content: center; min-height: 40vh; }
.msal__spin { font-size: 2rem; color: #94a3b8; animation: spin .8s linear infinite; }
@keyframes spin { to { transform: rotate(360deg); } }

.msal__hero { padding: 1.25rem 1rem 1.1rem; }
.msal__hero-kind   { font-size: .72rem; font-weight: 700; color: rgba(255,255,255,.7); margin-bottom: .4rem; text-transform: uppercase; letter-spacing: .06em; }
.msal__hero-nombre { font-size: 1.25rem; font-weight: 800; color: #fff; margin: 0 0 .3rem; }
.msal__hero-meta   { font-size: .78rem; color: rgba(255,255,255,.6); display: flex; gap: .4rem; }
.msal__sep { opacity: .4; }

.msal__actions { display: flex; gap: .75rem; padding: 1rem; }
.msal__btn-registrar {
  flex: 1; display: flex; align-items: center; justify-content: center; gap: .5rem;
  background: #1b5e20; color: #fff; border: none; padding: .875rem;
  border-radius: 12px; font-size: .95rem; font-weight: 700; cursor: pointer;
}
.msal__acciones-wrap { position: relative; }
.msal__btn-acciones { display: flex; align-items: center; gap: .4rem; background: #fff; color: #374151; border: 1.5px solid #e2e8f0; padding: .875rem 1rem; border-radius: 12px; font-size: .875rem; font-weight: 600; cursor: pointer; white-space: nowrap; }
.msal__menu { position: absolute; top: calc(100% + 6px); right: 0; z-index: 50; background: #fff; border: 1px solid #e2e8f0; border-radius: 12px; box-shadow: 0 8px 24px rgba(0,0,0,.12); overflow: hidden; min-width: 180px; }
.msal__menu-item { width: 100%; display: flex; align-items: center; gap: .6rem; padding: .85rem 1rem; border: none; background: none; text-align: left; font-size: .875rem; color: #374151; cursor: pointer; }
.msal__menu-item:hover { background: #f8fafc; }

.msal__section-title { font-size: .7rem; font-weight: 700; color: #94a3b8; text-transform: uppercase; letter-spacing: .06em; padding: .75rem 1rem .5rem; }
.msal__empty { padding: .75rem 1rem; color: #94a3b8; font-size: .82rem; text-align: center; }
.msal__list { display: flex; flex-direction: column; gap: .5rem; padding: 0 1rem; }
.msal__card { display: flex; align-items: center; background: #fff; border-radius: 14px; box-shadow: 0 1px 4px rgba(0,0,0,.07); text-decoration: none; overflow: hidden; -webkit-tap-highlight-color: transparent; }
.msal__card-stripe { width: 4px; align-self: stretch; flex-shrink: 0; }
.msal__card-body { flex: 1; padding: .875rem .75rem; min-width: 0; }
.msal__card-top { display: flex; align-items: center; gap: .5rem; margin-bottom: .25rem; }
.msal__codigo { font-size: .92rem; font-weight: 800; color: #0f172a; font-family: monospace; }
.msal__badge { font-size: .62rem; font-weight: 700; padding: .2em .55em; border-radius: 999px; }
.msal__card-meta { font-size: .72rem; color: #64748b; display: flex; gap: .3rem; }
.msal__dot { color: #d1d5db; }
.msal__chevron { color: #d1d5db; font-size: .8rem; padding-right: .875rem; flex-shrink: 0; }

.msal__overlay { position: fixed; inset: 0; z-index: 200; background: rgba(0,0,0,.5); display: flex; align-items: flex-end; }
.msal__sheet { width: 100%; background: #fff; border-radius: 20px 20px 0 0; max-height: 90vh; overflow-y: auto; }
.msal__sheet-handle { width: 40px; height: 4px; background: #e2e8f0; border-radius: 999px; margin: .75rem auto .25rem; }
.msal__sheet-header { display: flex; align-items: center; justify-content: space-between; padding: .5rem 1.25rem 1rem; }
.msal__sheet-title { font-size: 1rem; font-weight: 700; margin: 0; }
.msal__sheet-close { background: none; border: none; color: #94a3b8; font-size: 1rem; cursor: pointer; }
.msal__sheet-body { padding: 0 1.25rem 2.5rem; display: flex; flex-direction: column; gap: .875rem; }
.msal__field { display: flex; flex-direction: column; gap: .3rem; }
.msal__label { font-size: .72rem; font-weight: 700; color: #374151; text-transform: uppercase; letter-spacing: .04em; }
.msal__input { background: #f8fafc; border: 1.5px solid #e2e8f0; border-radius: 9px; padding: .65rem .875rem; font-size: .9rem; color: #0f172a; outline: none; width: 100%; box-sizing: border-box; }
.msal__input:focus { border-color: #1b5e20; }
.msal__textarea { resize: none; font-family: inherit; }
.msal__row2 { display: grid; grid-template-columns: 1fr 1fr; gap: .75rem; }
.msal__error { background: #fef2f2; color: #dc2626; border: 1px solid #fecaca; border-radius: 8px; padding: .5rem .75rem; font-size: .8rem; }
.msal__btn-confirmar { width: 100%; display: flex; align-items: center; justify-content: center; gap: .5rem; background: #1b5e20; color: #fff; border: none; padding: .9rem; border-radius: 12px; font-size: .95rem; font-weight: 700; cursor: pointer; }
.msal__btn-confirmar:disabled { opacity: .6; }
</style>
