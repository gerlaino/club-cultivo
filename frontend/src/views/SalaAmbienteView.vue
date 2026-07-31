<script setup>
import { ref, computed, watch, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { useAmbienteStore } from '../stores/ambiente.js'
import { useAmbiente } from '../composables/useAmbiente.js'
import { useSetpoints } from '../composables/useSetpoints.js'
import { useAuthStore } from '../stores/auth.js'
import { formatValor } from '../composables/useLecturaFormat.js'
import { useAmbienteChannel } from '../composables/useAmbienteChannel.js'
import SemaforoAmbiente from '../components/ambiente/SemaforoAmbiente.vue'
import AmbienteChart from '../components/ambiente/AmbienteChart.vue'
import LecturaManualForm from '../components/ambiente/LecturaManualForm.vue'
import AlertaBadge from '../components/ambiente/AlertaBadge.vue'
import Breadcrumb from '../components/ui/Breadcrumb.vue'
import { getSala, listLotes, getSalaAmbienteHistorico } from '../lib/api.js'
import DsSpinner from '../design-system/components/Spinner.vue'

const route  = useRoute()
const auth   = useAuthStore()
const store  = useAmbienteStore()
const { getSetpoint } = useSetpoints()

const salaId  = Number(route.params.id)
const sala    = ref(null)
const lotes   = ref([])
const loading = ref(true)

// Parámetros del chart
const bucket    = ref('raw')
const tipoChart = ref('temperatura')
const desde     = ref(new Date(Date.now() - 7 * 24 * 3600_000).toISOString().slice(0, 16))
const hasta     = ref(new Date().toISOString().slice(0, 16))

// Activa sección
const seccionActiva = ref('semaforo') // 'semaforo' | 'chart' | 'tendencia' | 'manual' | 'alertas'

// Live updates
const liveConectado = ref(false)

// Histórico (tendencia)
const tipoHistorico  = ref('temperatura')
const semanasHistorico = ref(4)
const histData       = ref([])
const loadingHist    = ref(false)

const TIPOS_HISTORICO = [
  { value: 'temperatura', label: 'Temperatura' },
  { value: 'humedad',     label: 'Humedad' },
  { value: 'vpd',         label: 'VPD' },
  { value: 'co2',         label: 'CO₂' },
]

const isCultivador = computed(() => auth.user?.role === 'cultivador')

const ESTADO_LABEL = { enraizado: 'Enraizado', vegetativo: 'Vegetativo', floracion: 'Floración', cosecha: 'Cosecha', en_manicura: 'En manicura', curado: 'Curado', finalizado: 'Finalizado' }
function estadoLabel(e) { return ESTADO_LABEL[e] || e || '' }

const loteActivo = computed(() =>
  lotes.value.find(l => ['vegetativo', 'floracion'].includes(l.estado)) || lotes.value[0] || null
)

onMounted(async () => {
  try {
    await Promise.all([
      getSala(salaId).then(r  => { sala.value  = r.data }),
      listLotes(salaId).then(r => { lotes.value = Array.isArray(r.data) ? r.data : (r.data?.items || []) }),
      store.cargarSetpoints(),
    ])
  } catch {
    // silent
  } finally {
    loading.value = false
  }
})

// Composable de polling (BUG4: ISO 8601 sin replace)
const { refrescar } = useAmbiente(
  salaId,
  computed(() => ({
    desde: desde.value,
    hasta: hasta.value,
  }))
)

// Semáforo items — últimas lecturas por tipo
const TIPOS_SEMAFORO = ['temperatura', 'humedad', 'vpd', 'co2']
const semaforoItems = computed(() => {
  const fase        = loteActivo.value?.estado || 'vegetativo'
  const geneticaId  = loteActivo.value?.genetica_id || null

  return TIPOS_SEMAFORO.map(tipo => {
    const ultima = store.ultimaLectura(tipo)
    const sp     = getSetpoint(tipo, fase, geneticaId)
    return {
      tipo,
      valor:   ultima != null ? parseFloat(ultima.valor) : null,
      unidad:  ultima?.unidad || sp?.unidad || '',
      min:     sp?.valor_min ?? null,
      max:     sp?.valor_max ?? null,
      ideal:   sp?.valor_ideal ?? null,
    }
  })
})

const setpointChart = computed(() => {
  const fase       = loteActivo.value?.estado || 'vegetativo'
  const geneticaId = loteActivo.value?.genetica_id || null
  return getSetpoint(tipoChart.value, fase, geneticaId)
})

// Breadcrumbs
const breadcrumbs = computed(() => {
  const items = [{ label: 'Sedes', to: { name: 'sedes' } }]
  if (sala.value?.sede) {
    items.push({ label: sala.value.sede.nombre, to: { name: 'sede-detail', params: { id: sala.value.sede.id } } })
  }
  if (sala.value) {
    items.push({ label: sala.value.nombre, to: { name: 'sala-detail', params: { id: salaId } } })
  }
  return items
})

const TIPOS_CHART = [
  { value: 'temperatura', label: 'Temperatura' },
  { value: 'humedad',     label: 'Humedad' },
  { value: 'vpd',         label: 'VPD' },
  { value: 'co2',         label: 'CO₂' },
  { value: 'ppfd',        label: 'PPFD' },
  { value: 'ec',          label: 'EC' },
  { value: 'ph',          label: 'pH' },
]

async function onRegistroGuardado() {
  await refrescar()
}

// Reload chart when range changes (BUG4: ISO 8601 sin replace)
watch([desde, hasta, bucket], async () => {
  await store.cargarAmbiente(salaId, {
    desde:  desde.value,
    hasta:  hasta.value,
    bucket: bucket.value,
  })
})

// ActionCable — live readings
function onLecturaEnVivo(data) {
  liveConectado.value = true
  // Agregar al store si cae dentro del rango visible
  const ts = new Date(data.medido_at)
  const desdeTs = new Date(desde.value)
  const hastaTs = new Date(hasta.value)
  if (ts >= desdeTs && ts <= hastaTs) {
    store.lecturas.push({ ...data, valor: data.valor })
  } else {
    // Actualizar ultima lectura aunque no esté en rango (semáforo)
    store.lecturas.push({ ...data, valor: data.valor })
  }
}

useAmbienteChannel(salaId, onLecturaEnVivo)

// Histórico
async function cargarHistorico() {
  loadingHist.value = true
  try {
    const { data } = await getSalaAmbienteHistorico(salaId, {
      tipo:    tipoHistorico.value,
      semanas: semanasHistorico.value,
    })
    // Convertir a formato que AmbienteChart entiende
    histData.value = (data.historico || []).map(d => ({
      tipo:      d.tipo,
      valor:     d.valor,
      unidad:    '',
      medido_at: d.fecha + 'T12:00:00Z',
      n:         d.n,
    }))
  } catch {
    histData.value = []
  } finally {
    loadingHist.value = false
  }
}

watch([tipoHistorico, semanasHistorico], () => {
  if (seccionActiva.value === 'tendencia') cargarHistorico()
})

watch(seccionActiva, (val) => {
  if (val === 'tendencia' && !histData.value.length) cargarHistorico()
})

</script>

<template>
  <div class="sav">
    <Breadcrumb
      v-if="!isCultivador && breadcrumbs.length"
      :items="[...breadcrumbs, { label: 'Ambiente' }]"
    />

    <div v-if="loading" class="sav__loading">
      <DsSpinner />
    </div>

    <template v-else>
      <!-- Header -->
      <div class="sav__hero">
        <div class="sav__hero-left">
          <div class="sav__title-row">
            <h1 class="sav__title">🌿 {{ sala?.nombre || 'Sala' }} — Ambiente</h1>
            <span v-if="liveConectado" class="sav__live-dot" title="Actualizaciones en tiempo real activas">● en vivo</span>
          </div>
          <p class="sav__subtitle" v-if="loteActivo">
            Lote activo: <strong>{{ loteActivo.codigo }}</strong>
            <span v-if="loteActivo.estado"> · {{ estadoLabel(loteActivo.estado) }}</span>
          </p>
        </div>
        <div class="sav__hero-actions">
          <button class="sav__btn-icon" :disabled="store.loadingLecturas" @click="refrescar" title="Actualizar">
            <i class="bi bi-arrow-clockwise" :class="{ 'sav__spin': store.loadingLecturas }"></i>
          </button>
          <RouterLink :to="{ name: 'sala-detail', params: { id: salaId } }" class="sav__btn-ghost">
            <i class="bi bi-arrow-left"></i> Sala
          </RouterLink>
        </div>
      </div>

      <!-- Tabs -->
      <div class="sav__tabs">
        <button class="sav__tab" :class="{ 'sav__tab--active': seccionActiva === 'semaforo' }" @click="seccionActiva = 'semaforo'">🚦 Estado</button>
        <button class="sav__tab" :class="{ 'sav__tab--active': seccionActiva === 'chart' }" @click="seccionActiva = 'chart'">📈 Gráfico</button>
        <button class="sav__tab" :class="{ 'sav__tab--active': seccionActiva === 'tendencia' }" @click="seccionActiva = 'tendencia'">📊 Tendencia</button>
        <button class="sav__tab" :class="{ 'sav__tab--active': seccionActiva === 'manual' }" @click="seccionActiva = 'manual'">✏️ Registrar</button>
        <button class="sav__tab" :class="{ 'sav__tab--active': seccionActiva === 'alertas' }" @click="seccionActiva = 'alertas'">
          🔔 Alertas
          <span v-if="store.alertasCount > 0" class="sav__tab-badge">{{ store.alertasCount }}</span>
        </button>
      </div>

      <!-- Semáforo -->
      <div v-if="seccionActiva === 'semaforo'" class="sav__section">
        <SemaforoAmbiente :items="semaforoItems" />

        <div class="sav__card sav__card--mt">
          <div class="sav__card-header">📊 Lecturas recientes</div>
          <div class="sav__card-body">
            <div class="sav__lecturas-grid">
              <template v-for="tipo in TIPOS_CHART" :key="tipo.value">
                <div v-if="store.ultimaLectura(tipo.value)" class="sav__lectura-item">
                  <div class="sav__lectura-tipo">{{ tipo.label }}</div>
                  <div class="sav__lectura-valor">
                    {{ formatValor(store.ultimaLectura(tipo.value)?.valor, 2) }}
                    <span class="sav__lectura-unit">{{ store.ultimaLectura(tipo.value)?.unidad }}</span>
                  </div>
                  <div class="sav__lectura-time">
                    {{ new Date(store.ultimaLectura(tipo.value)?.medido_at).toLocaleString('es-AR', { day:'numeric', month:'short', hour:'2-digit', minute:'2-digit' }) }}
                  </div>
                </div>
              </template>
              <div v-if="!store.lecturas.length" class="sav__empty">Sin lecturas en el período seleccionado.</div>
            </div>
          </div>
        </div>
      </div>

      <!-- Chart -->
      <div v-if="seccionActiva === 'chart'" class="sav__section">
        <!-- Controles -->
        <div class="sav__chart-controls">
          <div class="sav__field">
            <label class="sav__label">Parámetro</label>
            <select class="sav__input" v-model="tipoChart">
              <option v-for="t in TIPOS_CHART" :key="t.value" :value="t.value">{{ t.label }}</option>
            </select>
          </div>
          <div class="sav__field">
            <label class="sav__label">Agrupación</label>
            <select class="sav__input" v-model="bucket">
              <option value="raw">Lecturas brutas</option>
              <option value="daily">Promedio diario</option>
            </select>
          </div>
          <div class="sav__field">
            <label class="sav__label">Desde</label>
            <input type="datetime-local" class="sav__input" v-model="desde" />
          </div>
          <div class="sav__field">
            <label class="sav__label">Hasta</label>
            <input type="datetime-local" class="sav__input" v-model="hasta" />
          </div>
        </div>

        <div class="sav__chart-wrap">
          <AmbienteChart
            :lecturas="store.lecturas"
            :tipo="tipoChart"
            :bucket="bucket"
            :setpoint="setpointChart"
            :height="320"
          />
        </div>
      </div>

      <!-- Tendencia histórica -->
      <div v-if="seccionActiva === 'tendencia'" class="sav__section">
        <div class="sav__chart-controls">
          <div class="sav__field">
            <label class="sav__label">Parámetro</label>
            <select class="sav__input" v-model="tipoHistorico">
              <option v-for="t in TIPOS_HISTORICO" :key="t.value" :value="t.value">{{ t.label }}</option>
            </select>
          </div>
          <div class="sav__field">
            <label class="sav__label">Período</label>
            <select class="sav__input" v-model.number="semanasHistorico">
              <option :value="1">Última semana</option>
              <option :value="2">Últimas 2 semanas</option>
              <option :value="4">Últimas 4 semanas</option>
              <option :value="8">Últimas 8 semanas</option>
              <option :value="12">Últimas 12 semanas</option>
            </select>
          </div>
        </div>

        <div v-if="loadingHist" class="sav__hist-loading">Cargando histórico…</div>
        <div v-else-if="!histData.length" class="sav__empty sav__empty--center">
          Sin datos históricos para {{ tipoHistorico }} en este período.
        </div>
        <template v-else>
          <div class="sav__chart-wrap">
            <AmbienteChart
              :lecturas="histData"
              :tipo="tipoHistorico"
              bucket="daily"
              :setpoint="setpointChart"
              :height="320"
            />
          </div>
          <div class="sav__hist-info">
            Promedio diario — {{ histData.length }} día{{ histData.length !== 1 ? 's' : '' }} con datos
            · {{ histData.reduce((s, d) => s + d.n, 0) }} lecturas totales
          </div>
        </template>
      </div>

      <!-- Registro manual -->
      <div v-if="seccionActiva === 'manual'" class="sav__section">
        <div v-if="!loteActivo" class="sav__info-msg">
          <i class="bi bi-info-circle"></i>
          Esta sala no tiene lotes activos. Asigná un lote para registrar lecturas.
        </div>
        <template v-else>
          <p class="sav__manual-help">
            Las lecturas se asociarán al lote <strong>{{ loteActivo.codigo }}</strong>.
          </p>
          <LecturaManualForm :lote-id="loteActivo.id" @guardado="onRegistroGuardado" />
        </template>
      </div>

      <!-- Alertas -->
      <div v-if="seccionActiva === 'alertas'" class="sav__section">
        <div v-if="!store.alertasActivas.length" class="sav__ok-msg">
          <i class="bi bi-check-circle-fill"></i> Sin alertas activas en esta sala.
        </div>
        <div v-else class="sav__alertas-list">
          <AlertaBadge
            v-for="a in store.alertasActivas"
            :key="a.id"
            :alerta="a"
            @resolver="store.resolverAlerta($event)"
            @reconocer="store.reconocerAlerta($event)"
          />
        </div>
      </div>
    </template>
  </div>
</template>

<style scoped>
.sav { padding: 1.75rem 1.5rem; max-width: 1100px; margin: 0 auto; font-family: system-ui, -apple-system, sans-serif; color: #1a1a1a; }
@media (max-width: 640px) { .sav { padding: 1rem; } }

.sav__loading { display: flex; align-items: center; justify-content: center; min-height: calc(100vh - 56px); }
.sav__spin { animation: sav-spin .6s linear infinite; }

.sav__hero { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; margin-bottom: 1.5rem; flex-wrap: wrap; }
.sav__title { font-size: 1.6rem; font-weight: 800; margin: 0; letter-spacing: -.04em; }
.sav__subtitle { font-size: .82rem; color: #60725d; margin: .25rem 0 0; }
.sav__hero-actions { display: flex; gap: .5rem; align-items: center; }

.sav__btn-icon {
  width: 36px; height: 36px; border-radius: 8px; border: 1px solid #d4e6d4;
  background: #f0fdf4; color: #60725d; cursor: pointer; display: flex;
  align-items: center; justify-content: center; font-size: .95rem; transition: all .15s;
}
.sav__btn-icon:hover:not(:disabled) { background: #dcfce7; color: #1b5e20; }
.sav__btn-icon:disabled { opacity: .5; }
.sav__btn-ghost {
  display: inline-flex; align-items: center; gap: .35rem;
  background: transparent; color: #60725d; border: 1px solid #d4e6d4;
  padding: .5rem 1rem; border-radius: 8px; font-size: .82rem;
  font-weight: 500; text-decoration: none; transition: all .15s;
}
.sav__btn-ghost:hover { background: #f0fdf4; color: #1b5e20; }

.sav__tabs { display: flex; gap: .35rem; margin-bottom: 1.25rem; flex-wrap: wrap; }
.sav__tab {
  display: inline-flex; align-items: center; gap: .35rem;
  padding: .5rem 1rem; border-radius: 8px; border: 1.5px solid #d4e6d4;
  background: #fff; color: #60725d; font-size: .82rem; font-weight: 600;
  cursor: pointer; transition: all .15s;
}
.sav__tab:hover { border-color: #a7d7a9; background: #f0fdf4; }
.sav__tab--active { background: #1b5e20; color: #fff; border-color: #1b5e20; }
.sav__tab-badge {
  min-width: 18px; height: 18px; background: #dc2626; color: #fff;
  border-radius: 999px; font-size: .62rem; font-weight: 800;
  display: flex; align-items: center; justify-content: center; padding: 0 3px;
}
.sav__tab--active .sav__tab-badge { background: #fff; color: #dc2626; }

.sav__section { animation: sav-fadein .15s ease; }
@keyframes sav-fadein { from { opacity: 0; transform: translateY(4px); } to { opacity: 1; transform: none; } }

.sav__card { background: #fff; border: 1px solid #d4e6d4; border-radius: 14px; overflow: hidden; }
.sav__card--mt { margin-top: 1.25rem; }
.sav__card-header { padding: .8rem 1rem; border-bottom: 1px solid #e8f0e9; font-size: .85rem; font-weight: 700; }
.sav__card-body { padding: 1rem; }

.sav__lecturas-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(160px, 1fr)); gap: .75rem; }
.sav__lectura-item { background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 10px; padding: .7rem; }
.sav__lectura-tipo { font-size: .7rem; font-weight: 700; color: #64748b; text-transform: uppercase; letter-spacing: .04em; margin-bottom: .25rem; }
.sav__lectura-valor { font-size: 1.3rem; font-weight: 800; letter-spacing: -.03em; color: #1a1a1a; }
.sav__lectura-unit { font-size: .72rem; font-weight: 500; color: #94a3b8; margin-left: .1rem; }
.sav__lectura-time { font-size: .65rem; color: #94a3b8; margin-top: .2rem; }

.sav__chart-controls {
  display: grid; grid-template-columns: repeat(auto-fill, minmax(180px, 1fr));
  gap: .75rem; margin-bottom: 1.25rem;
}
.sav__chart-wrap { background: #fff; border: 1px solid #d4e6d4; border-radius: 14px; padding: 1rem; }
.sav__field { display: flex; flex-direction: column; gap: .3rem; }
.sav__label { font-size: .72rem; font-weight: 600; color: #374151; }
.sav__input {
  background: #f4f8f4; border: 1.5px solid #d4e6d4; border-radius: 8px;
  padding: .5rem .75rem; font-size: .82rem; color: #1a1a1a; width: 100%; box-sizing: border-box;
}
.sav__input:focus { outline: none; border-color: #1b5e20; background: #fff; }

.sav__manual-help { font-size: .85rem; color: #60725d; margin-bottom: 1rem; }
.sav__info-msg, .sav__ok-msg {
  display: flex; align-items: center; gap: .6rem;
  padding: 1rem 1.25rem; border-radius: 10px; font-size: .875rem;
}
.sav__info-msg { background: #eff6ff; border: 1px solid #bfdbfe; color: #1d4ed8; }
.sav__ok-msg { background: #f0fdf4; border: 1px solid #d4e6d4; color: #15803d; }

.sav__alertas-list { display: flex; flex-direction: column; gap: .6rem; }
.sav__empty { color: #94a3b8; font-size: .82rem; grid-column: 1/-1; }
.sav__empty--center { text-align: center; padding: 2rem 1rem; background: #f8fafc; border-radius: 10px; grid-column: unset; }

/* Live dot */
.sav__title-row { display: flex; align-items: center; gap: .6rem; flex-wrap: wrap; }
.sav__live-dot {
  font-size: .68rem; font-weight: 700; color: #15803d; background: #dcfce7;
  padding: .15rem .5rem; border-radius: 99px;
}

/* Tendencia */
.sav__hist-loading { color: #94a3b8; font-size: .82rem; padding: 2rem; text-align: center; }
.sav__hist-info { font-size: .72rem; color: #94a3b8; margin-top: .6rem; text-align: center; }
</style>
