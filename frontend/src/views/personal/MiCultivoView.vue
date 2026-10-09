<template>
  <!-- MI CULTIVO, en la compu (autocultivo, 9-oct-2026): la misma idea que en el teléfono —los
       espacios con sus PLANTAS— con lugar para ver todo junto. El lote vive por debajo y no se
       nombra. Todo lo que hay (genéticas, nutrientes, frascos, gastos, informes) sigue en el menú:
       no son menos funciones, es una forma más simple de llegar. -->
  <div class="mic">
    <header class="mic__cab">
      <div>
        <h1 class="mic__titulo">Mi cultivo</h1>
        <p class="mic__sub">{{ fechaHoy }} · {{ resumen }}</p>
      </div>
      <div class="mic__cab-acc">
        <RouterLink to="/mis-informes" class="mic__btn mic__btn--linea">Mis informes</RouterLink>
        <button type="button" class="mic__btn" :disabled="!salas.length" @click="abrirNueva()">+ Nueva planta</button>
      </div>
    </header>

    <div class="mic__kpis">
      <div class="mic__kpi">
        <!-- Lo que se cuenta es el cupo, no «en floración»: las automáticas ocupan lugar todo su
             ciclo aunque estén en vege. El desglose lo manda el backend (`PlanEnforcer`). -->
        <span class="mic__kpi-l">Cupo de plantas</span>
        <strong class="mic__kpi-v">{{ cupoTexto }}</strong>
        <span class="mic__kpi-s">{{ cupoDesglose }}</span>
      </div>
      <div class="mic__kpi">
        <span class="mic__kpi-l">Próxima cosecha</span>
        <strong class="mic__kpi-v">{{ proximaCosecha ? `${proximaCosecha.dias} días` : '—' }}</strong>
        <span class="mic__kpi-s">{{ proximaCosecha?.quien || 'sin fecha estimada' }}</span>
      </div>
      <div class="mic__kpi">
        <span class="mic__kpi-l">Plantas</span>
        <strong class="mic__kpi-v">{{ plantas.length }}</strong>
        <span class="mic__kpi-s">en {{ salas.length }} {{ salas.length === 1 ? 'espacio' : 'espacios' }}</span>
      </div>
    </div>

    <div v-if="!cargando && !salas.length" class="mic__vacio">
      <p class="mic__vacio-t">Primero, tu espacio</p>
      <p>Una carpa, un balcón, una cama de suelo vivo: donde viven tus plantas.</p>
      <RouterLink to="/salas" class="mic__btn">Crear mi primer espacio</RouterLink>
    </div>

    <div class="mic__cuerpo">
      <div class="mic__espacios">
        <section v-for="s in salasConPlantas" :key="s.id" class="mic__espacio">
          <div class="mic__espacio-cab">
            <RouterLink :to="`/salas/${s.id}`" class="mic__espacio-nombre">
              <strong>{{ s.nombre }}</strong>
              <span>{{ luz(s) }}</span>
            </RouterLink>
            <div class="mic__espacio-acc">
              <button type="button" class="mic__btn mic__btn--chico" @click="regar(s)">Regar</button>
              <button v-if="['vegetativo', 'floracion'].includes(s.kind)" type="button" class="mic__btn mic__btn--chico mic__btn--linea"
                      :disabled="cambiandoLuz === s.id" @click="cambiarLuz(s)">
                Pasar a {{ s.kind === 'vegetativo' ? '12/12' : '18/6' }}
              </button>
            </div>
          </div>
          <div v-if="s.plantas.length" class="mic__grilla">
            <RouterLink v-for="p in s.plantas" :key="p.id" :to="`/plantas/${p.id}`" class="mic__planta">
              <span class="mic__planta-top">
                <strong>{{ p.nombre }}</strong>
                <span class="mic__chip" :class="p.auto ? 'mic__chip--auto' : 'mic__chip--foto'">{{ p.auto ? 'Auto' : 'Foto' }}</span>
              </span>
              <span class="mic__planta-l">{{ p.genetica }} · {{ p.dia }}</span>
              <span v-if="p.pct != null" class="mic__barra"><span :style="{ width: `${p.pct}%` }"></span></span>
              <span v-if="p.toca" class="mic__planta-toca">{{ p.toca }}</span>
            </RouterLink>
          </div>
          <button v-else type="button" class="mic__sin" @click="abrirNueva(s.id)">Sin plantas · <strong>agregar</strong></button>
        </section>
      </div>

      <aside v-if="salas.length" class="mic__lado">
        <section class="mic__panel">
          <h2 class="mic__panel-t">Lo que viene</h2>
          <p v-if="!loQueViene.length" class="mic__panel-vacio">Nada en los próximos días.</p>
          <div v-for="v in loQueViene" :key="v.id" class="mic__viene">
            <div><strong>{{ v.que }}</strong><span>{{ v.quien }}</span></div>
            <span class="mic__viene-cuando">{{ v.cuando }}</span>
          </div>
        </section>
        <section v-if="fotos.length" class="mic__panel">
          <h2 class="mic__panel-t">Últimas fotos</h2>
          <div class="mic__fotos">
            <a v-for="f in fotos.slice(0, 6)" :key="f.id || f.url" :href="f.url" target="_blank" rel="noopener" class="mic__foto">
              <img :src="f.url" alt="" loading="lazy" />
            </a>
          </div>
        </section>
      </aside>
    </div>

    <NuevaPlantaSheet v-model="showNueva" :salas="salas" :sala-id="salaElegida" @creada="cargar" />
    <RegistroSalaModal v-if="salaRegar" v-model="showRegar" :sala="salaRegar" accion-inicial="riego" />
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { listSalas, listLotes, listPlants, cambiarFaseSala, getFotosRecientes } from '../../lib/api'
import { textoProximoPasoCorto, estadoPlantaLabel } from '../../lib/loteHelpers.js'
import { textoCambioDeFase } from '../../lib/textoCambioDeFase.js'
import { useRecargaEnCambios } from '../../composables/useRecargaEnCambios.js'
import { useConfirm } from '../../composables/useConfirm.js'
import { useToast } from '../../composables/useToast'
import { usePlan } from '../../composables/usePlan.js'
import NuevaPlantaSheet from '../../components/personal/NuevaPlantaSheet.vue'
import RegistroSalaModal from '../../components/salas/RegistroSalaModal.vue'

const EN_CULTIVO = ['enraizado', 'vegetativo', 'floracion']
const { confirm } = useConfirm()
const toast = useToast()
const { planData, limites, uso } = usePlan()

const salas    = ref([])
const lotes    = ref([])
const plantas  = ref([])
const fotos    = ref([])
const cargando = ref(true)
const showNueva   = ref(false)
const salaElegida = ref(null)

async function cargar() {
  try {
    const [s, l, p] = await Promise.all([listSalas(), listLotes({ estado: EN_CULTIVO }), listPlants()])
    salas.value   = (s.data || []).filter(x => x.state !== 'cerrada' && ['vegetativo', 'floracion', 'mixta', 'clon', 'madre'].includes(x.kind))
    lotes.value   = l.data || []
    plantas.value = (p.data || []).filter(x => EN_CULTIVO.includes(x.state))
  } catch { /* queda lo que había */ } finally { cargando.value = false }
  try { fotos.value = (await getFotosRecientes()).data || [] } catch { fotos.value = [] }
  // El cupo cambia al plantar o al cambiar la luz: se vuelve a pedir.
  planData.value = null
  try { await usePlan().fetchPlan() } catch { /* el KPI queda sin número */ }
}
onMounted(cargar)
useRecargaEnCambios(['lotes', 'plantas', 'salas'], cargar)

function abrirNueva(salaId = null) { salaElegida.value = salaId; showNueva.value = true }

const fechaHoy = new Date().toLocaleDateString('es-AR', { weekday: 'long', day: 'numeric', month: 'long' })
const resumen = computed(() => `${plantas.value.length} ${plantas.value.length === 1 ? 'planta' : 'plantas'} en ${salas.value.length} ${salas.value.length === 1 ? 'espacio' : 'espacios'}`)
const cupoTexto = computed(() => {
  const tope = limites.value?.plantas
  const hay = uso.value?.plantas
  if (hay == null) return '—'
  return tope ? `${hay} de ${tope}` : `${hay}`
})

const cupoDesglose = computed(() => {
  const d = planData.value?.plantas_desglose
  if (!d) return 'en floración y automáticas'
  const partes = []
  if (d.en_floracion) partes.push(`${d.en_floracion} en floración`)
  if (d.automaticas) partes.push(`${d.automaticas} ${d.automaticas === 1 ? 'automática' : 'automáticas'}`)
  return partes.length ? partes.join(' + ') : 'ninguna en floración'
})

const LUZ = { vegetativo: '18/6 · vegetativo', floracion: '12/12 · floración', mixta: 'Mixto', clon: 'Esquejes', madre: 'Madres' }
const luz = (s) => LUZ[s.kind] || s.kind

const lotePorId = computed(() => Object.fromEntries(lotes.value.map(l => [l.id, l])))
function tarjeta(p) {
  const l = lotePorId.value[p.lote?.id] || {}
  const auto = !!l.automatica
  const obj = l.dias_ciclo_objetivo
  const dia = auto && l.dias_ciclo != null
    ? `día ${l.dias_ciclo}${obj ? ` de ${obj}` : ''}`
    : `${estadoPlantaLabel(p).toLowerCase()}${p.dias_en_fase != null ? ` · día ${p.dias_en_fase}` : ''}`
  const pct = auto && l.dias_ciclo != null && obj ? Math.min(100, Math.round(l.dias_ciclo / obj * 100)) : null
  return { id: p.id, nombre: p.nombre, genetica: p.genetica?.nombre || l.genetica?.nombre || 'Sin genética', auto, dia, pct, toca: textoProximoPasoCorto(l) }
}
const salasConPlantas = computed(() => salas.value.map(s => ({
  ...s, plantas: plantas.value.filter(p => p.lote?.sala?.id === s.id).map(tarjeta),
})))

// Lo que viene: los próximos pasos que calcula el backend (`proximo_paso` de cada lote), con las
// plantas que comparten ese paso nombradas juntas.
const loQueViene = computed(() => lotes.value
  .filter(l => l.proximo_paso?.fase && l.proximo_paso.faltan_dias != null)
  .map(l => {
    const nombres = plantas.value.filter(p => p.lote?.id === l.id).map(p => p.nombre)
    const n = l.proximo_paso.faltan_dias
    return { id: l.id, que: (textoProximoPasoCorto(l) || '').replace(/ (en \d+ d|hoy|· tocaba hace \d+ d)$/, ''), quien: nombres.join(', ') || l.genetica?.nombre,
             cuando: n > 0 ? `en ${n} d` : n === 0 ? 'hoy' : `hace ${-n} d`, orden: n }
  })
  .sort((a, b) => a.orden - b.orden)
  .slice(0, 6))

const proximaCosecha = computed(() => {
  const c = lotes.value.filter(l => l.proximo_paso?.fase === 'cosecha' && l.proximo_paso.faltan_dias != null)
                       .sort((a, b) => a.proximo_paso.faltan_dias - b.proximo_paso.faltan_dias)[0]
  if (!c) return null
  const nombres = plantas.value.filter(p => p.lote?.id === c.id).map(p => p.nombre)
  return { dias: Math.max(0, c.proximo_paso.faltan_dias), quien: nombres.join(', ') }
})

// ── Regar la carpa: el registro de siempre, abierto en Riego (cuánto y con qué) ─────────────
const salaRegar = ref(null)
const showRegar = ref(false)
function regar(s) { salaRegar.value = s; showRegar.value = true }

// ── Cambiar la luz: mueve las fotos; las autos siguen su reloj (`Salas::CambiarFase`) ───────
const cambiandoLuz = ref(null)
async function cambiarLuz(s, confirmado = false) {
  cambiandoLuz.value = s.id
  try {
    const { data } = await cambiarFaseSala(s.id, confirmado ? { confirmar_cambio_fase: true } : {})
    toast.success(`${s.nombre} en ${data.nueva_fase === 'floracion' ? '12/12' : '18/6'}`)
    await cargar()
  } catch (e) {
    const d = e?.response?.data
    if (d?.requiere_confirmacion) {
      cambiandoLuz.value = null
      if (await confirm({ ...textoCambioDeFase(d), variant: 'danger' })) return cambiarLuz(s, true)
      return
    }
    toast.error(d?.error || d?.errors?.[0] || 'No se pudo cambiar la luz')
  } finally {
    cambiandoLuz.value = null
  }
}
</script>

<style scoped>
.mic { padding: var(--sp-6) var(--sp-8); display: flex; flex-direction: column; gap: var(--sp-6); max-width: 1280px; }
.mic__cab { display: flex; align-items: flex-end; justify-content: space-between; gap: var(--sp-4); flex-wrap: wrap; }
.mic__titulo { margin: 0; font-size: var(--fs-32); font-weight: 800; letter-spacing: -.02em; color: var(--c-ink-900); }
.mic__sub { margin: 2px 0 0; color: var(--c-ink-700); }
.mic__sub::first-letter { text-transform: uppercase; }
.mic__cab-acc { display: flex; gap: var(--sp-2); flex-wrap: wrap; }
.mic__btn {
  min-height: 44px; padding: 0 18px; border-radius: var(--r-xl); border: 0; background: var(--c-leaf-700); color: var(--c-slate-50);
  font: inherit; font-weight: 700; display: inline-flex; align-items: center; text-decoration: none; cursor: pointer;
}
.mic__btn:disabled { opacity: .5; }
.mic__btn--linea { background: var(--c-slate-50); color: var(--c-ink-900); border: 1px solid var(--c-ink-300); }
.mic__btn--chico { min-height: 38px; padding: 0 14px; font-size: var(--fs-13); }
.mic__kpis { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: var(--sp-3); }
.mic__kpi { background: var(--c-slate-50); border: 1px solid var(--c-leaf-100); border-radius: 14px; padding: var(--sp-3) var(--sp-4); display: flex; flex-direction: column; gap: 2px; }
.mic__kpi-l { font-size: var(--fs-12); font-weight: 600; color: var(--c-ink-700); }
.mic__kpi-v { font-size: var(--fs-24); color: var(--c-ink-900); }
.mic__kpi-s { font-size: var(--fs-12); color: var(--c-ink-700); }
.mic__vacio { padding: var(--sp-10); text-align: center; display: flex; flex-direction: column; align-items: center; gap: var(--sp-2); color: var(--c-ink-700); }
.mic__vacio p { margin: 0; }
.mic__vacio-t { font-weight: 800; font-size: var(--fs-18); color: var(--c-ink-900); }
.mic__cuerpo { display: flex; flex-wrap: wrap; gap: var(--sp-6); align-items: flex-start; }
.mic__espacios { flex: 999 1 560px; min-width: 0; display: flex; flex-direction: column; gap: var(--sp-5); }
.mic__lado { flex: 1 1 280px; min-width: 0; display: flex; flex-direction: column; gap: var(--sp-4); }
.mic__espacio { background: var(--c-slate-50); border: 1px solid var(--c-leaf-100); border-radius: 16px; padding: var(--sp-4); display: flex; flex-direction: column; gap: var(--sp-3); }
.mic__espacio-cab { display: flex; align-items: center; justify-content: space-between; gap: var(--sp-3); flex-wrap: wrap; }
.mic__espacio-nombre { display: flex; flex-direction: column; text-decoration: none; color: var(--c-ink-900); }
.mic__espacio-nombre strong { font-size: var(--fs-18); }
.mic__espacio-nombre span { font-size: var(--fs-13); color: var(--c-ink-700); }
.mic__espacio-acc { display: flex; gap: var(--sp-2); flex-wrap: wrap; }
.mic__grilla { display: grid; grid-template-columns: repeat(auto-fill, minmax(190px, 1fr)); gap: var(--sp-2); }
.mic__planta { border: 1px solid var(--c-leaf-100); border-radius: 12px; padding: var(--sp-3); display: flex; flex-direction: column; gap: 5px; text-decoration: none; color: var(--c-ink-900); background: var(--c-paper); }
.mic__planta:hover { border-color: var(--c-leaf-300); }
.mic__planta-top { display: flex; align-items: center; justify-content: space-between; gap: 6px; }
.mic__planta-l { font-size: var(--fs-12); color: var(--c-ink-700); }
.mic__planta-toca { font-size: var(--fs-12); font-weight: 600; color: var(--c-gold-500); }
.mic__barra { height: 6px; border-radius: 3px; background: var(--c-leaf-100); overflow: hidden; }
.mic__barra span { display: block; height: 100%; background: var(--c-leaf-700); }
.mic__chip { font-size: 11px; font-weight: 700; padding: 2px 8px; border-radius: 999px; }
.mic__chip--auto { background: var(--c-amber-100); color: var(--c-gold-500); }
.mic__chip--foto { background: var(--c-leaf-100); color: var(--c-leaf-800); }
.mic__sin { min-height: 48px; border-radius: 12px; border: 1px dashed var(--c-leaf-300); background: transparent; font: inherit; color: var(--c-ink-700); cursor: pointer; }
.mic__sin strong { color: var(--c-leaf-700); }
.mic__panel { background: var(--c-slate-50); border: 1px solid var(--c-leaf-100); border-radius: 16px; padding: var(--sp-4); display: flex; flex-direction: column; gap: var(--sp-2); }
.mic__panel-t { margin: 0 0 4px; font-size: var(--fs-14); font-weight: 700; color: var(--c-ink-900); }
.mic__panel-vacio { margin: 0; font-size: var(--fs-13); color: var(--c-ink-700); }
.mic__viene { display: flex; justify-content: space-between; gap: var(--sp-2); padding: 8px 0; border-top: 1px solid var(--c-ink-100); }
.mic__viene > div { display: flex; flex-direction: column; }
.mic__viene strong { font-size: var(--fs-14); }
.mic__viene span { font-size: var(--fs-12); color: var(--c-ink-700); }
.mic__viene .mic__viene-cuando { font-weight: 700; color: var(--c-gold-500); white-space: nowrap; }
.mic__fotos { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 6px; }
.mic__foto { aspect-ratio: 1; border-radius: 8px; overflow: hidden; background: var(--c-leaf-100); }
.mic__foto img { width: 100%; height: 100%; object-fit: cover; display: block; }
</style>
