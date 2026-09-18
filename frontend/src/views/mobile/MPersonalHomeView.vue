<template>
  <div class="mph">
    <header class="mph__hero">
      <p class="mph__greet">{{ saludo }}</p>
      <h1 class="mph__name">{{ nombre }}</h1>
      <p class="mph__date">{{ fechaLarga }}</p>
    </header>

    <!-- Qué falta para arrancar: sala, lote. Lo calcula el backend y desaparece solo. -->
    <div class="mph__pem"><PuestaEnMarcha /></div>

    <!-- Alertas del ambiente: lo único que puede estar mal AHORA mismo. -->
    <RouterLink
      v-for="a in alertasCriticas.slice(0, 2)" :key="a.id"
      :to="a.sala_id ? `/m/sala-m/${a.sala_id}` : '/m/personal/cultivo'"
      class="mph__banner mph__banner--red"
    >
      <i class="bi bi-exclamation-triangle-fill"></i>
      <span><strong>{{ a.regla_nombre || a.tipo }}</strong> en {{ salaNombre(a.sala_id) }}</span>
      <i class="bi bi-chevron-right mph__banner-go"></i>
    </RouterLink>

    <!-- ── Qué toca hoy ── -->
    <section class="mph__section">
      <div class="mph__section-head">
        <h2 class="mph__section-title">Qué toca hoy</h2>
        <RouterLink to="/m/admin/tareas" class="mph__section-link">Todas →</RouterLink>
      </div>
      <div v-if="cargando" class="mph__skel"></div>
      <div v-else-if="!tareasHoy.length" class="mph__empty">
        <i class="bi bi-check2-circle"></i>
        <span>Nada pendiente. Regá si hace falta y disfrutá.</span>
      </div>
      <ul v-else class="mph__tareas">
        <li v-for="t in tareasHoy" :key="t.id" class="mph__tarea" :class="{ 'mph__tarea--vencida': t.vencida }">
          <button type="button" class="mph__tarea-check" :disabled="completando === t.id"
                  :aria-label="`Marcar hecha: ${t.titulo}`" @click="completar(t)">
            <i class="bi" :class="completando === t.id ? 'bi-hourglass-split' : 'bi-circle'"></i>
          </button>
          <div class="mph__tarea-txt">
            <span class="mph__tarea-titulo">{{ t.titulo }}</span>
            <span class="mph__tarea-sub">
              <template v-if="t.lote?.codigo">{{ t.lote.codigo }}</template>
              <template v-else-if="t.sala?.nombre">{{ t.sala.nombre }}</template>
              <template v-if="t.vencida"> · venció</template>
            </span>
          </div>
        </li>
      </ul>
    </section>

    <!-- ── Cómo viene el ambiente ── -->
    <section class="mph__section">
      <div class="mph__section-head">
        <h2 class="mph__section-title">Ambiente</h2>
        <RouterLink v-if="tieneIot" to="/dispositivos" class="mph__section-link">Sensores →</RouterLink>
      </div>
      <div v-if="cargando" class="mph__skel"></div>
      <div v-else-if="!ambiente.length" class="mph__empty">
        <i class="bi bi-thermometer-half"></i>
        <span>Sin lecturas todavía. Cargá una a mano desde la sala, o conectá un sensor.</span>
      </div>
      <div v-else class="mph__salas">
        <RouterLink v-for="s in ambiente" :key="s.sala_id" :to="`/m/sala-m/${s.sala_id}`" class="mph__sala">
          <span class="mph__sala-nombre">{{ s.sala }}</span>
          <span class="mph__sala-lecturas">
            <span v-if="s.temperatura != null" class="mph__lectura"><i class="bi bi-thermometer-half"></i>{{ s.temperatura.toFixed(1) }}°</span>
            <span v-if="s.humedad != null" class="mph__lectura"><i class="bi bi-droplet-half"></i>{{ Math.round(s.humedad) }}%</span>
            <span v-if="vpd(s) != null" class="mph__lectura mph__lectura--vpd" :class="`mph__lectura--${vpdEstado(vpd(s))}`">VPD {{ vpd(s).toFixed(2) }}</span>
          </span>
          <span class="mph__sala-hace">{{ hace(s.medido_at) }}</span>
        </RouterLink>
      </div>
    </section>

    <!-- ── Lotes en curso ── -->
    <section class="mph__section">
      <div class="mph__section-head">
        <h2 class="mph__section-title">En el cultivo</h2>
        <RouterLink to="/m/personal/cultivo" class="mph__section-link">Ver salas →</RouterLink>
      </div>
      <div v-if="cargando" class="mph__skel"></div>
      <div v-else-if="!lotesEnCurso.length" class="mph__empty">
        <i class="bi bi-box-seam"></i>
        <span>Ningún lote en curso. Creá uno con el botón <b>+</b>.</span>
      </div>
      <div v-else class="mph__lotes">
        <RouterLink v-for="l in lotesEnCurso" :key="l.id" :to="`/m/lote-m/${l.id}`" class="mph__lote">
          <span class="mph__lote-ico" :style="{ background: meta(l.estado).bg, color: meta(l.estado).color }"><i class="bi" :class="icono(l.estado)"></i></span>
          <span class="mph__lote-txt">
            <span class="mph__lote-nombre">{{ l.genetica?.nombre || l.strain || l.codigo }}</span>
            <span class="mph__lote-sub">{{ l.codigo }} · {{ l.plants_count || 0 }} {{ l.plants_count === 1 ? 'planta' : 'plantas' }}</span>
          </span>
          <span class="mph__lote-fase">
            <span class="mph__lote-estado" :style="{ color: meta(l.estado).color }">{{ meta(l.estado).label }}</span>
            <span v-if="l.dias_en_estado != null" class="mph__lote-dias">día {{ l.dias_en_estado + 1 }}</span>
          </span>
        </RouterLink>
      </div>
    </section>

    <!-- ── Después de cosechar ── -->
    <section v-if="lotesPostCosecha.length" class="mph__section">
      <div class="mph__section-head">
        <h2 class="mph__section-title">Secando y curando</h2>
        <RouterLink to="/m/personal/frascos" class="mph__section-link">Frascos →</RouterLink>
      </div>
      <div class="mph__lotes">
        <RouterLink v-for="l in lotesPostCosecha" :key="l.id"
                    :to="l.estado === 'en_manicura' ? `/m/mnc/lotes/${l.id}` : `/m/lote-m/${l.id}`" class="mph__lote">
          <span class="mph__lote-ico" :style="{ background: meta(l.estado).bg, color: meta(l.estado).color }"><i class="bi" :class="icono(l.estado)"></i></span>
          <span class="mph__lote-txt">
            <span class="mph__lote-nombre">{{ l.genetica?.nombre || l.strain || l.codigo }}</span>
            <span class="mph__lote-sub">{{ l.codigo }}<template v-if="l.estado === 'en_manicura'"> · por pesar</template></span>
          </span>
          <span class="mph__lote-fase">
            <span class="mph__lote-estado" :style="{ color: meta(l.estado).color }">{{ meta(l.estado).label }}</span>
            <span v-if="l.dias_en_estado != null" class="mph__lote-dias">día {{ l.dias_en_estado + 1 }}</span>
          </span>
        </RouterLink>
      </div>
    </section>
  </div>
</template>

<script setup>
// El inicio del cultivador de casa. No es el del admin de una organización —que mira cómo va
// el día de OTROS y desbloquea lo que traba— sino el de quien hace todo: qué le toca hoy,
// cómo viene la carpa, en qué día de fase va cada lote. Mismo estado que el resto de la app
// (stores de tareas, ambiente y lotes); lo que cambia es la presentación.
import { ref, computed, onMounted } from 'vue'
import { useAuthStore }     from '../../stores/auth'
import { useClubStore }     from '../../stores/club'
import { useTareasStore }   from '../../stores/tareas'
import { useLotesStore }    from '../../stores/lotes'
import { useSalasStore }    from '../../stores/salas'
import { useAmbienteStore } from '../../stores/ambiente'
import { useToast }         from '../../composables/useToast.js'
import { getAmbienteSalas } from '../../lib/api'
import { ESTADO_META }      from '../../lib/loteHelpers.js'
import PuestaEnMarcha       from '../../components/PuestaEnMarcha.vue'

const auth     = useAuthStore()
const club     = useClubStore()
const tareas   = useTareasStore()
const lotes    = useLotesStore()
const salas    = useSalasStore()
const ambienteStore = useAmbienteStore()
const toast    = useToast()

const nombre = computed(() => auth.user?.first_name || 'Hola')
const saludo = computed(() => {
  const h = new Date().getHours()
  return h < 12 ? 'Buen día' : h < 19 ? 'Buenas tardes' : 'Buenas noches'
})
const fechaLarga = computed(() => {
  const f = new Date().toLocaleDateString('es-AR', { weekday: 'long', day: 'numeric', month: 'long' })
  return f.charAt(0).toUpperCase() + f.slice(1)
})

const cargando = ref(true)
const ambiente = ref([])
const tieneIot = computed(() => club.data?.features?.iot === true)

// Hoy + lo vencido, que sigue siendo de hoy hasta que se haga.
const tareasHoy = computed(() => {
  const d = tareas.dashboard
  const vencidas = (d.vencidas || []).map(t => ({ ...t, vencida: true }))
  const hoy      = (d.hoy || []).filter(t => t.estado !== 'completada')
  return [...vencidas, ...hoy].slice(0, 8)
})

const completando = ref(null)
async function completar(t) {
  completando.value = t.id
  try {
    await tareas.completar(t.id, null, '')
    await tareas.fetchDashboard()
    toast.success('Hecha ✓')
  } catch (e) {
    toast.error(e?.response?.data?.error || 'No se pudo marcar')
  } finally { completando.value = null }
}

const alertasCriticas = computed(() => (ambienteStore.alertasActivas || []).slice(0, 2))
function salaNombre(id) { return salas.items?.find(s => s.id === id)?.nombre || 'una sala' }

const EN_CURSO = ['enraizado', 'vegetativo', 'floracion']
const POST     = ['cosecha', 'en_manicura', 'curado']
const lotesEnCurso     = computed(() => (lotes.items || []).filter(l => EN_CURSO.includes(l.estado)))
const lotesPostCosecha = computed(() => (lotes.items || []).filter(l => POST.includes(l.estado)))
function meta(estado) { return ESTADO_META[estado] || { label: estado, color: '#475569', bg: '#f1f5f9' } }
// Íconos por estado del lote (Bootstrap Icons, no emoji: el emoji depende de la fuente del
// teléfono y en algunos aparece como un cuadrado).
const ICONO_ESTADO = {
  enraizado: 'bi-droplet', vegetativo: 'bi-flower3', floracion: 'bi-flower1', cosecha: 'bi-scissors',
  en_manicura: 'bi-scissors', curado: 'bi-archive', finalizado: 'bi-check2-circle',
}
function icono(estado) { return ICONO_ESTADO[estado] || 'bi-box-seam' }


// VPD (kPa) a partir de temperatura y humedad del aire, sin offset de hoja: es la lectura
// orientativa que el cultivador de casa compara contra la tabla de su fase.
function vpd(s) {
  if (s.temperatura == null || s.humedad == null) return null
  const svp = 0.6108 * Math.exp((17.27 * s.temperatura) / (s.temperatura + 237.3))
  return svp * (1 - s.humedad / 100)
}
function vpdEstado(v) { return v < 0.4 || v > 1.6 ? 'mal' : (v < 0.8 || v > 1.4 ? 'regular' : 'bien') }

function hace(iso) {
  if (!iso) return ''
  const min = Math.round((Date.now() - new Date(iso).getTime()) / 60000)
  if (min < 2)  return 'recién'
  if (min < 60) return `hace ${min} min`
  const h = Math.round(min / 60)
  if (h < 24)   return `hace ${h} h`
  return `hace ${Math.round(h / 24)} d`
}

onMounted(async () => {
  try {
    await Promise.allSettled([
      tareas.fetchDashboard(),
      lotes.fetch(),
      salas.fetch(),
      ambienteStore.cargarAlertas(),
      getAmbienteSalas().then(r => { ambiente.value = r.data?.salas || [] }),
    ])
  } finally { cargando.value = false }
})
</script>

<style scoped>
.mph { min-height: 100%; padding-bottom: 1.5rem; }

.mph__hero {
  background: linear-gradient(160deg, #0F2A1E 0%, #1A3D2E 100%);
  color: #fff; padding: 1.4rem 1.2rem 1.6rem; border-radius: 0 0 24px 24px;
}
.mph__greet { margin: 0; font-size: .9rem; color: rgba(255,255,255,.7); }
.mph__name  { margin: .1rem 0 .35rem; font-family: var(--font-display, sans-serif); font-size: 1.7rem; font-weight: 700; line-height: 1.1; }
.mph__date  { margin: 0; font-size: .78rem; color: rgba(255,255,255,.55); }

.mph__pem { padding: .9rem 1.1rem 0; }
.mph__pem :deep(.pem) { margin-bottom: 0; }

.mph__banner {
  display: flex; align-items: center; gap: .6rem; margin: .9rem 1.1rem 0;
  padding: .75rem .9rem; border-radius: var(--r-xl, 14px);
  font-size: .85rem; font-weight: 600; text-decoration: none;
}
.mph__banner i:first-child { font-size: 1.1rem; flex-shrink: 0; }
.mph__banner span { flex: 1; }
.mph__banner-go { font-size: .9rem; opacity: .6; }
.mph__banner--red { background: #fee2e2; color: #991b1b; }

.mph__section { padding: 1.2rem 1.1rem 0; }
.mph__section-head { display: flex; align-items: baseline; justify-content: space-between; margin-bottom: .6rem; }
.mph__section-title { margin: 0; font-size: .72rem; font-weight: 700; letter-spacing: .06em; text-transform: uppercase; color: var(--c-ink-500, #6b7280); }
.mph__section-link  { font-size: .78rem; font-weight: 600; color: var(--c-leaf-700, #2D7D46); text-decoration: none; }

.mph__skel  { height: 64px; border-radius: 14px; background: linear-gradient(90deg, #eef2ef, #f7faf8, #eef2ef); background-size: 200% 100%; animation: mph-skel 1.2s infinite; }
@keyframes mph-skel { to { background-position: -200% 0; } }
.mph__empty {
  display: flex; align-items: center; gap: .6rem; padding: .9rem 1rem;
  background: #fff; border: 1px dashed var(--c-leaf-200, #cfe0d6); border-radius: 14px;
  color: var(--c-ink-500, #6b7280); font-size: .82rem;
}
.mph__empty i { font-size: 1.15rem; color: var(--c-leaf-500, #5A8A72); }

/* Tareas */
.mph__tareas { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: .45rem; }
.mph__tarea {
  display: flex; align-items: center; gap: .7rem; padding: .7rem .8rem;
  background: #fff; border: 1px solid var(--c-leaf-100, #e8f0eb); border-radius: 14px;
}
.mph__tarea--vencida { border-color: #fde68a; background: #fffdf5; }
.mph__tarea-check {
  width: 36px; height: 36px; border-radius: 50%; border: none; background: var(--c-leaf-50, #F4F8F5);
  color: var(--c-leaf-700, #2D7D46); font-size: 1.15rem; display: grid; place-items: center; flex-shrink: 0;
}
.mph__tarea-check:active { transform: scale(.94); }
.mph__tarea-txt { display: flex; flex-direction: column; gap: .1rem; min-width: 0; }
.mph__tarea-titulo { font-size: .9rem; font-weight: 600; color: var(--c-ink-900, #1a1d1f); }
.mph__tarea-sub { font-size: .74rem; color: var(--c-ink-500, #6b7280); }

/* Salas */
.mph__salas { display: flex; flex-direction: column; gap: .45rem; }
.mph__sala {
  display: grid; grid-template-columns: 1fr auto; gap: .15rem .6rem; align-items: center;
  padding: .75rem .9rem; background: #fff; border: 1px solid var(--c-leaf-100, #e8f0eb); border-radius: 14px; text-decoration: none;
}
.mph__sala-nombre { font-size: .9rem; font-weight: 700; color: var(--c-ink-900, #1a1d1f); }
.mph__sala-lecturas { display: flex; gap: .55rem; grid-column: 1; }
.mph__lectura { display: inline-flex; align-items: center; gap: .25rem; font-size: .82rem; color: var(--c-ink-700, #374151); font-weight: 600; }
.mph__lectura i { color: var(--c-ink-400, #9ca3af); }
.mph__lectura--vpd { padding: .05rem .4rem; border-radius: 6px; font-size: .74rem; }
.mph__lectura--bien    { background: #dcfce7; color: #166534; }
.mph__lectura--regular { background: #fef3c7; color: #92400e; }
.mph__lectura--mal     { background: #fee2e2; color: #991b1b; }
.mph__sala-hace { grid-column: 2; grid-row: 1 / span 2; font-size: .72rem; color: var(--c-ink-400, #9ca3af); white-space: nowrap; }

/* Lotes */
.mph__lotes { display: flex; flex-direction: column; gap: .45rem; }
.mph__lote {
  display: flex; align-items: center; gap: .7rem; padding: .7rem .8rem;
  background: #fff; border: 1px solid var(--c-leaf-100, #e8f0eb); border-radius: 14px; text-decoration: none;
}
.mph__lote:active { transform: scale(.985); }
.mph__lote-ico { width: 38px; height: 38px; border-radius: 11px; display: grid; place-items: center; font-size: 1.1rem; flex-shrink: 0; }
.mph__lote-txt { display: flex; flex-direction: column; gap: .1rem; min-width: 0; flex: 1; }
.mph__lote-nombre { font-size: .9rem; font-weight: 700; color: var(--c-ink-900, #1a1d1f); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.mph__lote-sub { font-size: .74rem; color: var(--c-ink-500, #6b7280); }
.mph__lote-fase { display: flex; flex-direction: column; align-items: flex-end; gap: .1rem; flex-shrink: 0; }
.mph__lote-estado { font-size: .74rem; font-weight: 700; }
.mph__lote-dias { font-size: .72rem; color: var(--c-ink-500, #6b7280); }
</style>
