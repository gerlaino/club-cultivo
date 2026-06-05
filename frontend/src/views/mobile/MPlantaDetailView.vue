<template>
  <div class="mpd" v-if="planta">

    <!-- Hero -->
    <div class="mpd__hero">
      <div class="mpd__hero-estado" :style="{ background: estadoColor(planta.state) }">
        {{ estadoEmoji(planta.state) }} {{ estadoLabel(planta.state) }}
      </div>
      <h2 class="mpd__hero-nombre">{{ planta.nombre || planta.codigo_qr }}</h2>
      <div class="mpd__hero-meta">
        <span v-if="planta.lote?.codigo">📦 {{ planta.lote.codigo }}</span>
        <span v-if="planta.genetica?.nombre" class="mpd__sep">·</span>
        <span v-if="planta.genetica?.nombre">{{ planta.genetica.nombre }}</span>
      </div>
    </div>

    <!-- Acción principal -->
    <div class="mpd__actions">
      <button class="mpd__btn-registrar" @click="showRegistrar = true">
        <i class="bi bi-pencil-square"></i>
        Registrar actividad
      </button>

      <!-- Mic IA (solo si feature habilitada) -->
      <!-- Menú acciones secundarias -->
      <div class="mpd__acciones-wrap" v-click-outside="() => showAcciones = false">
        <button class="mpd__btn-acciones" @click="showAcciones = !showAcciones">
          <i class="bi bi-three-dots-vertical"></i>
          Acciones
        </button>
        <div v-if="showAcciones" class="mpd__menu">
          <button class="mpd__menu-item" @click="accion('foto')">
            <i class="bi bi-camera"></i> Agregar foto
          </button>
          <button class="mpd__menu-item mpd__menu-item--danger" @click="accion('descartar')">
            <i class="bi bi-trash"></i> Descartar planta
          </button>
        </div>
      </div>
    </div>

    <!-- Info básica -->
    <div class="mpd__card">
      <div class="mpd__card-title">Información</div>
      <div class="mpd__info-grid">
        <div class="mpd__info-item">
          <span class="mpd__info-label">Código QR</span>
          <span class="mpd__info-val mpd__mono">{{ planta.codigo_qr || '—' }}</span>
        </div>
        <div class="mpd__info-item" v-if="planta.altura_actual">
          <span class="mpd__info-label">Altura</span>
          <span class="mpd__info-val">{{ planta.altura_actual }} cm</span>
        </div>
        <div class="mpd__info-item" v-if="planta.lote?.sala?.nombre">
          <span class="mpd__info-label">Sala</span>
          <span class="mpd__info-val">{{ planta.lote.sala.nombre }}</span>
        </div>
        <div class="mpd__info-item" v-if="planta.es_seleccion">
          <span class="mpd__info-label">Selección</span>
          <span class="mpd__info-val" style="color:#f59e0b">⭐ Planta madre</span>
        </div>
      </div>
    </div>

    <!-- Último registro -->
    <div v-if="ultimoRegistro" class="mpd__card">
      <div class="mpd__card-title">Último registro</div>
      <div class="mpd__ultimo">
        <div class="mpd__ultimo-fecha">{{ formatFecha(ultimoRegistro.created_at) }}</div>
        <div v-if="ultimoRegistro.metadata?.estado_salud" class="mpd__ultimo-item">
          Salud: <strong>{{ saludLabel(ultimoRegistro.metadata.estado_salud) }}</strong>
        </div>
        <div v-if="ultimoRegistro.metadata?.altura_cm" class="mpd__ultimo-item">
          Altura: <strong>{{ ultimoRegistro.metadata.altura_cm }} cm</strong>
        </div>
        <div v-if="ultimoRegistro.description" class="mpd__ultimo-notas">{{ ultimoRegistro.description }}</div>
      </div>
    </div>

    <!-- Historial reciente -->
    <div class="mpd__card">
      <div class="mpd__card-title">Historial reciente</div>
      <div v-if="!activities.length" class="mpd__hist-empty">Sin actividades registradas</div>
      <div v-else class="mpd__hist-list">
        <div v-for="a in activities.slice(0, 8)" :key="a.id" class="mpd__hist-item">
          <div class="mpd__hist-dot" :style="{ background: actColor(a.activity_type) }"></div>
          <div class="mpd__hist-info">
            <div class="mpd__hist-tipo">{{ actLabel(a.activity_type) }}</div>
            <div class="mpd__hist-fecha">{{ formatFecha(a.created_at) }}</div>
          </div>
          <div v-if="a.description" class="mpd__hist-desc">{{ a.description }}</div>
        </div>
      </div>
    </div>

    <!-- Modal registro planta (reutiliza el de la web) -->
    <RegistroPlantaModal
      v-model="showRegistrar"
      :planta="planta"
      :registros-hoy="registrosHoy"
      @saved="recargarActividades"
    />

  </div>
  <div v-else-if="loading" class="mpd mpd--loading">
    <i class="bi bi-arrow-repeat mpd__spin"></i>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { getPlant, getPlantActivities } from '../../lib/api'
import { useToast }          from '../../composables/useToast'
import RegistroPlantaModal   from '../../components/plants/RegistroPlantaModal.vue'

const route = useRoute()
const toast = useToast()
const id    = Number(route.params.id)

const planta     = ref(null)
const activities = ref([])
const loading    = ref(true)
const showRegistrar = ref(false)
const showAcciones  = ref(false)

const EC = { semilla:'#64748b', esqueje:'#0891b2', vegetativo:'#16a34a', floracion:'#9333ea', cosecha:'#dc2626', en_manicura:'#d97706', secado:'#d97706', curado:'#2563eb' }
const EL = { semilla:'Semilla', esqueje:'Esqueje', vegetativo:'Vegetativo', floracion:'Floración', cosecha:'Cosecha', en_manicura:'Manicura', secado:'Secado', curado:'Curado' }
const EE = { semilla:'🌱', esqueje:'🪴', vegetativo:'🍃', floracion:'🌸', cosecha:'✂️', en_manicura:'✂️', secado:'💨', curado:'🫙' }
const estadoColor = e => EC[e] || '#64748b'
const estadoLabel = e => EL[e] || e || '—'
const estadoEmoji = e => EE[e] || '🌿'

const AC = { registro_planta:'#0891b2', measurement:'#16a34a', transplant:'#d97706' }
const AL = { registro_planta:'Registro', measurement:'Medición', transplant:'Trasplante' }
const actColor = t => AC[t] || '#94a3b8'
const actLabel = t => AL[t] || t || '—'

const registrosHoy = computed(() => {
  const hoy = new Date().toDateString()
  return activities.value
    .filter(a => new Date(a.created_at).toDateString() === hoy)
    .map(a => a.activity_type)
})

const ultimoRegistro = computed(() =>
  activities.value.find(a => a.activity_type === 'registro_planta')
)

async function recargarActividades() {
  const { data } = await getPlantActivities(id)
  activities.value = data || []
}

function formatFecha(ts) {
  if (!ts) return ''
  return new Date(ts).toLocaleDateString('es-AR', { day:'numeric', month:'short', hour:'2-digit', minute:'2-digit' })
}

function accion(tipo) {
  showAcciones.value = false
  if (tipo === 'descartar') { toast.warning('Usá la web para descartar plantas'); return }
  toast.info('Usá la web para esta acción avanzada')
}

onMounted(async () => {
  try {
    const [pr, ar] = await Promise.all([getPlant(id), getPlantActivities(id)])
    planta.value     = pr.data
    activities.value = ar.data || []
  } catch {} finally { loading.value = false }
})
</script>

<style scoped>
.mpd { padding: 0 0 2rem; }
.mpd--loading { display: flex; align-items: center; justify-content: center; min-height: 40vh; }
.mpd__spin { font-size: 2rem; color: #94a3b8; animation: spin .8s linear infinite; }
@keyframes spin { to { transform: rotate(360deg); } }

/* Hero */
.mpd__hero { padding: 1.25rem 1rem 1rem; background: linear-gradient(135deg, #0f2417 0%, #1b5e20 100%); }
.mpd__hero-estado { display: inline-flex; align-items: center; gap: .35rem; font-size: .72rem; font-weight: 700; color: #fff; padding: .3em .8em; border-radius: 999px; opacity: .9; margin-bottom: .5rem; }
.mpd__hero-nombre { font-size: 1.25rem; font-weight: 800; color: #fff; margin: 0 0 .35rem; letter-spacing: -.01em; }
.mpd__hero-meta { font-size: .78rem; color: rgba(255,255,255,.65); display: flex; align-items: center; gap: .4rem; flex-wrap: wrap; }
.mpd__sep { opacity: .4; }

/* Botones de acción */
.mpd__actions { display: flex; gap: .75rem; padding: 1rem; }
.mpd__btn-registrar {
  flex: 1; display: flex; align-items: center; justify-content: center; gap: .5rem;
  background: #1b5e20; color: #fff; border: none;
  padding: .875rem; border-radius: 12px; font-size: .95rem; font-weight: 700;
  cursor: pointer; -webkit-tap-highlight-color: transparent;
}
.mpd__acciones-wrap { position: relative; }
.mpd__btn-acciones {
  display: flex; align-items: center; gap: .4rem;
  background: #fff; color: #374151; border: 1.5px solid #e2e8f0;
  padding: .875rem 1rem; border-radius: 12px; font-size: .875rem; font-weight: 600;
  cursor: pointer; white-space: nowrap; -webkit-tap-highlight-color: transparent;
}
.mpd__menu {
  position: absolute; top: calc(100% + 6px); right: 0; z-index: 50;
  background: #fff; border: 1px solid #e2e8f0; border-radius: 12px;
  box-shadow: 0 8px 24px rgba(0,0,0,.12); overflow: hidden; min-width: 200px;
}
.mpd__menu-item {
  width: 100%; display: flex; align-items: center; gap: .6rem;
  padding: .85rem 1rem; border: none; background: none; text-align: left;
  font-size: .875rem; color: #374151; cursor: pointer;
  border-bottom: 1px solid #f8fafc;
}
.mpd__menu-item:last-child { border-bottom: none; }
.mpd__menu-item:hover { background: #f8fafc; }
.mpd__menu-item--danger { color: #dc2626; }

/* Cards */
.mpd__card { background: #fff; border-radius: 14px; margin: 0 1rem .75rem; padding: 1rem; box-shadow: 0 1px 4px rgba(0,0,0,.06); }
.mpd__card-title { font-size: .7rem; font-weight: 700; color: #94a3b8; text-transform: uppercase; letter-spacing: .06em; margin-bottom: .75rem; }

.mpd__info-grid { display: grid; grid-template-columns: 1fr 1fr; gap: .625rem; }
.mpd__info-item { display: flex; flex-direction: column; gap: .15rem; }
.mpd__info-label { font-size: .68rem; color: #94a3b8; text-transform: uppercase; letter-spacing: .04em; }
.mpd__info-val { font-size: .875rem; font-weight: 600; color: #0f172a; }
.mpd__mono { font-family: monospace; }

/* Último registro */
.mpd__ultimo { display: flex; flex-direction: column; gap: .35rem; }
.mpd__ultimo-fecha { font-size: .7rem; color: #94a3b8; }
.mpd__ultimo-item { font-size: .82rem; color: #374151; }
.mpd__ultimo-notas { font-size: .78rem; color: #64748b; font-style: italic; }

/* Historial */
.mpd__hist-empty { font-size: .8rem; color: #94a3b8; text-align: center; padding: .5rem 0; }
.mpd__hist-list { display: flex; flex-direction: column; gap: .625rem; }
.mpd__hist-item { display: flex; align-items: center; gap: .75rem; }
.mpd__hist-dot { width: 8px; height: 8px; border-radius: 50%; flex-shrink: 0; }
.mpd__hist-info { flex: 1; min-width: 0; }
.mpd__hist-tipo { font-size: .82rem; font-weight: 600; color: #0f172a; }
.mpd__hist-fecha { font-size: .68rem; color: #94a3b8; margin-top: .1rem; }
.mpd__hist-desc { font-size: .72rem; color: #64748b; max-width: 120px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }

/* Sheet registrar */
.mpd__overlay { position: fixed; inset: 0; z-index: 200; background: rgba(0,0,0,.5); display: flex; align-items: flex-end; }
.mpd__sheet { width: 100%; background: #fff; border-radius: 20px 20px 0 0; max-height: 92vh; overflow-y: auto; }
.mpd__sheet-handle { width: 40px; height: 4px; background: #e2e8f0; border-radius: 999px; margin: .75rem auto .25rem; }
.mpd__sheet-header { display: flex; align-items: center; justify-content: space-between; padding: .5rem 1.25rem 1rem; }
.mpd__sheet-title { font-size: 1rem; font-weight: 700; margin: 0; color: #0f172a; }
.mpd__sheet-close { background: none; border: none; color: #94a3b8; font-size: 1rem; cursor: pointer; }
.mpd__sheet-body { padding: 0 1.25rem 2.5rem; display: flex; flex-direction: column; gap: .875rem; }

.mpd__field { display: flex; flex-direction: column; gap: .35rem; }
.mpd__label { font-size: .72rem; font-weight: 700; color: #374151; text-transform: uppercase; letter-spacing: .04em; }
.mpd__input { background: #f8fafc; border: 1.5px solid #e2e8f0; border-radius: 9px; padding: .65rem .875rem; font-size: .9rem; color: #0f172a; outline: none; width: 100%; box-sizing: border-box; }
.mpd__input:focus { border-color: #1b5e20; }
.mpd__textarea { resize: none; font-family: inherit; }
.mpd__row2 { display: grid; grid-template-columns: 1fr 1fr; gap: .75rem; }

.mpd__chips { display: flex; gap: .5rem; flex-wrap: wrap; }
.mpd__chip { padding: .45rem .9rem; border-radius: 8px; border: 1.5px solid #e2e8f0; background: #f8fafc; color: #64748b; font-size: .78rem; font-weight: 600; cursor: pointer; transition: all .15s; }
.mpd__chip--on { font-weight: 700; }

.mpd__error { background: #fef2f2; color: #dc2626; border: 1px solid #fecaca; border-radius: 8px; padding: .5rem .75rem; font-size: .8rem; }
.mpd__btn-confirmar { width: 100%; display: flex; align-items: center; justify-content: center; gap: .5rem; background: #1b5e20; color: #fff; border: none; padding: .9rem; border-radius: 12px; font-size: .95rem; font-weight: 700; cursor: pointer; margin-top: .25rem; }
.mpd__btn-confirmar:disabled { opacity: .6; }
</style>
