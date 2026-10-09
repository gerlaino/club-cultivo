<template>
  <!-- MI CULTIVO (autocultivo, 9-oct-2026): las carpas con sus PLANTAS. Quien cultiva en casa piensa
       en plantas, no en lotes (Martín López se perdía entre lote, espacio y plantas): el lote sigue
       existiendo por debajo y acá no se nombra. Cada espacio dice qué luz tiene y abre su pantalla;
       cada planta abre su ficha. -->
  <div class="mmc">
    <header class="mmc__cab">
      <div>
        <h1 class="mmc__titulo">Mi cultivo</h1>
        <p class="mmc__sub">{{ resumen }}</p>
      </div>
      <RouterLink to="/m/personal/informes" class="mmc__informes">
        <i class="bi bi-file-earmark-text" aria-hidden="true"></i> Mis informes
      </RouterLink>
    </header>

    <div v-if="cargando && !salas.length" class="mmc__vacio"><i class="bi bi-arrow-repeat mmc__spin"></i> Cargando…</div>

    <div v-else-if="!salas.length" class="mmc__vacio">
      <p class="mmc__vacio-t">Primero, tu espacio</p>
      <p>Una carpa, un balcón, una cama de suelo vivo: donde viven tus plantas.</p>
      <button v-if="acciones" type="button" class="mmc__btn" @click="acciones.abrirNuevaSala()">Crear mi primer espacio</button>
    </div>

    <section v-for="s in salasConPlantas" :key="s.id" class="mmc__espacio">
      <RouterLink :to="`/m/sala-m/${s.id}`" class="mmc__espacio-cab">
        <div>
          <span class="mmc__espacio-nombre">{{ s.nombre }}</span>
          <span class="mmc__espacio-luz">{{ luz(s) }}</span>
        </div>
        <span class="mmc__ver">Ver <i class="bi bi-chevron-right" aria-hidden="true"></i></span>
      </RouterLink>

      <div v-if="s.plantas.length" class="mmc__grilla">
        <RouterLink v-for="p in s.plantas" :key="p.id" :to="`/m/planta/${p.id}`" class="mmc__planta">
          <span class="mmc__planta-top">
            <span class="mmc__planta-nombre">{{ p.nombre }}</span>
            <span class="mmc__chip" :class="p.auto ? 'mmc__chip--auto' : 'mmc__chip--foto'">{{ p.auto ? 'Auto' : 'Foto' }}</span>
          </span>
          <span class="mmc__planta-gen">{{ p.genetica }}</span>
          <span class="mmc__planta-dia">{{ p.dia }}</span>
          <span v-if="p.toca" class="mmc__planta-toca">{{ p.toca }}</span>
        </RouterLink>
      </div>
      <button v-else type="button" class="mmc__sin" @click="abrirNueva(s.id)">Sin plantas · <strong>agregar</strong></button>
    </section>

    <!-- Dictar a la vista (no sólo dentro del «+»): «puse dos semillas de Ananda en la carpa chica»
         crea las plantas; «regué la carpa con 6 litros» registra el riego. Sólo con la IA prendida. -->
    <div v-if="salas.length" class="mmc__fabs">
      <button v-if="puedeDictar" type="button" class="mmc__fab mmc__fab--voz" aria-label="Dictar" @click="dictar">
        <i class="bi bi-mic-fill" aria-hidden="true"></i>
      </button>
      <button type="button" class="mmc__fab" @click="abrirNueva()">
        <i class="bi bi-plus-lg" aria-hidden="true"></i> Nueva planta
      </button>
    </div>

    <NuevaPlantaSheet v-model="showNueva" :salas="salas" :sala-id="salaElegida" @creada="cargar" />
  </div>
</template>

<script setup>
import { ref, computed, onMounted, inject } from 'vue'
import { listSalas, listLotes, listPlants } from '../../lib/api'
import { textoProximoPasoCorto, estadoPlantaLabel } from '../../lib/loteHelpers.js'
import { useRecargaEnCambios } from '../../composables/useRecargaEnCambios.js'
import NuevaPlantaSheet from '../../components/personal/NuevaPlantaSheet.vue'
import { useClubStore } from '../../stores/club'

// El asistente de voz lo monta el shell; acá sólo se abre (mismo evento que «Dictar» del «+»).
const club = useClubStore()
const puedeDictar = computed(() => club.data?.features?.ia === true)
function dictar() { window.dispatchEvent(new CustomEvent('abrir-asistente-voz')) }

const acciones = inject('accionesMobile', null)
const EN_CULTIVO = ['enraizado', 'vegetativo', 'floracion']

const salas    = ref([])
const lotes    = ref([])
const plantas  = ref([])
const cargando = ref(true)
const showNueva   = ref(false)
const salaElegida = ref(null)

async function cargar() {
  try {
    const [s, l, p] = await Promise.all([listSalas(), listLotes({ estado: EN_CULTIVO }), listPlants()])
    salas.value   = (s.data || []).filter(x => x.state !== 'cerrada' && ['vegetativo', 'floracion', 'mixta', 'clon', 'madre'].includes(x.kind))
    lotes.value   = l.data || []
    plantas.value = (p.data || []).filter(x => EN_CULTIVO.includes(x.state))
  } catch { /* queda lo que había: sin señal se ve lo último */ } finally {
    cargando.value = false
  }
}
onMounted(cargar)
useRecargaEnCambios(['lotes', 'plantas', 'salas'], cargar)

function abrirNueva(salaId = null) { salaElegida.value = salaId; showNueva.value = true }

const LUZ = { vegetativo: '18/6 · vegetativo', floracion: '12/12 · floración', mixta: 'Mixto', clon: 'Esquejes', madre: 'Madres' }
const luz = (s) => LUZ[s.kind] || s.kind

// Qué dice cada tarjeta. Una auto cuenta su ciclo entero («día 31 de 77»); una foto, los días de
// la fase en que está. Lo que toca lo calcula el backend (`proximo_paso` del lote).
const lotePorId = computed(() => Object.fromEntries(lotes.value.map(l => [l.id, l])))
function tarjeta(p) {
  const l = lotePorId.value[p.lote?.id] || {}
  const auto = !!l.automatica
  let dia
  if (auto && l.dias_ciclo != null) dia = `Día ${l.dias_ciclo}${l.dias_ciclo_objetivo ? ` de ${l.dias_ciclo_objetivo}` : ''}`
  else dia = `${estadoPlantaLabel(p)}${p.dias_en_fase != null ? ` · día ${p.dias_en_fase}` : ''}`
  return { id: p.id, nombre: p.nombre, genetica: p.genetica?.nombre || l.genetica?.nombre || 'Sin genética',
           auto, dia, toca: textoProximoPasoCorto(l) }
}

const salasConPlantas = computed(() => salas.value.map(s => ({
  ...s,
  plantas: plantas.value.filter(p => p.lote?.sala?.id === s.id).map(tarjeta),
})))

const resumen = computed(() => {
  const n = plantas.value.length
  const e = salas.value.length
  if (!e) return 'Tu cultivo, planta por planta'
  return `${n} ${n === 1 ? 'planta' : 'plantas'} en ${e} ${e === 1 ? 'espacio' : 'espacios'}`
})
</script>

<style scoped>
.mmc { padding: 16px 16px 96px; display: flex; flex-direction: column; gap: 20px; }
.mmc__cab { display: flex; align-items: flex-start; justify-content: space-between; gap: 12px; }
.mmc__titulo { margin: 0; font-size: 1.6rem; font-weight: 800; letter-spacing: -.02em; color: var(--c-ink-900); }
.mmc__sub { margin: 2px 0 0; font-size: .9rem; color: var(--c-ink-700); }
.mmc__informes {
  display: inline-flex; align-items: center; gap: 6px; min-height: 40px; padding: 0 12px; border-radius: 999px;
  border: 1px solid var(--c-leaf-300); color: var(--c-leaf-800); font-size: .84rem; font-weight: 600; text-decoration: none; white-space: nowrap;
}
.mmc__vacio { display: flex; flex-direction: column; align-items: center; gap: 6px; padding: 40px 12px; text-align: center; color: var(--c-ink-700); }
.mmc__vacio p { margin: 0; }
.mmc__vacio-t { font-weight: 800; font-size: 1.05rem; color: var(--c-ink-900); }
.mmc__spin { animation: mmc-spin .8s linear infinite; }
@keyframes mmc-spin { to { transform: rotate(360deg); } }
.mmc__btn { margin-top: 10px; min-height: 48px; padding: 0 20px; border-radius: 12px; border: 0; background: var(--c-leaf-700); color: var(--c-slate-50); font: inherit; font-weight: 700; }
.mmc__espacio { display: flex; flex-direction: column; gap: 10px; }
.mmc__espacio-cab { display: flex; align-items: center; justify-content: space-between; gap: 8px; text-decoration: none; color: inherit; min-height: 44px; }
.mmc__espacio-cab > div { display: flex; flex-direction: column; }
.mmc__espacio-nombre { font-size: 1.08rem; font-weight: 700; color: var(--c-ink-900); }
.mmc__espacio-luz { font-size: .84rem; color: var(--c-ink-700); }
.mmc__ver { font-size: .84rem; font-weight: 600; color: var(--c-leaf-700); }
.mmc__grilla { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 10px; }
.mmc__planta {
  display: flex; flex-direction: column; gap: 4px; padding: 12px; border-radius: 14px; text-decoration: none;
  background: var(--c-slate-50); border: 1px solid var(--c-leaf-100); color: var(--c-ink-900);
}
.mmc__planta-top { display: flex; align-items: center; justify-content: space-between; gap: 6px; }
.mmc__planta-nombre { font-weight: 700; font-size: .98rem; line-height: 1.2; overflow: hidden; text-overflow: ellipsis; }
.mmc__planta-gen { font-size: .78rem; color: var(--c-ink-700); }
.mmc__planta-dia { font-size: .8rem; font-weight: 600; }
.mmc__planta-toca { font-size: .78rem; font-weight: 600; color: var(--c-gold-500); }
.mmc__chip { font-size: .7rem; font-weight: 700; padding: 2px 8px; border-radius: 999px; flex-shrink: 0; }
.mmc__chip--auto { background: var(--c-amber-100); color: var(--c-gold-500); }
.mmc__chip--foto { background: var(--c-leaf-100); color: var(--c-leaf-800); }
.mmc__sin { min-height: 48px; border-radius: 14px; border: 1px dashed var(--c-leaf-300); background: transparent; font: inherit; color: var(--c-ink-700); }
.mmc__sin strong { color: var(--c-leaf-700); }
.mmc__fabs { position: fixed; right: 16px; bottom: calc(92px + env(safe-area-inset-bottom)); z-index: 40; display: flex; gap: 10px; align-items: center; }
.mmc__fab {
  min-height: 52px; padding: 0 20px; border-radius: 26px; border: 0; background: var(--c-leaf-700); color: var(--c-slate-50);
  font: inherit; font-weight: 700; display: inline-flex; align-items: center; gap: 8px; box-shadow: 0 8px 20px -8px rgba(15, 42, 30, .6);
}
.mmc__fab--voz { width: 52px; padding: 0; justify-content: center; background: var(--c-slate-50); color: var(--c-leaf-700); border: 2px solid var(--c-leaf-700); }
</style>
