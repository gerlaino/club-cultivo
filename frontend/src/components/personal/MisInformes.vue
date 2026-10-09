<template>
  <!-- «MIS INFORMES» (autocultivo, 9-oct-2026): Mi cosecha, De dónde salió, Mis gastos. Lo que se ve
       es lo que se descarga: la pantalla dibuja la MISMA definición (números y tablas) con la que el
       servidor arma el PDF y el Excel (`InformesController#responder_informe`, `vista: true`). -->
  <div class="minf" :class="`minf--${variante}`">
    <div class="minf__periodos" role="group" aria-label="Período">
      <button v-for="p in PERIODOS" :key="p.key" type="button" class="minf__periodo" :class="{ 'is-on': periodo === p.key }"
              @click="periodo = p.key">{{ p.label }}</button>
    </div>

    <!-- Teléfono: una tarjeta por informe, con su resumen y las descargas. -->
    <template v-if="variante === 'telefono'">
      <article v-for="i in INFORMES" :key="i.key" class="minf__tarjeta">
        <div class="minf__tarjeta-cab">
          <span class="minf__ini" :class="`minf__ini--${i.key}`" aria-hidden="true"><i class="bi" :class="i.icono"></i></span>
          <div>
            <h2 class="minf__tarjeta-t">{{ i.titulo }}</h2>
            <p class="minf__tarjeta-p">{{ i.pregunta }}</p>
          </div>
        </div>
        <p class="minf__resumen">{{ resumen(i.key) }}</p>
        <div class="minf__descargas">
          <button type="button" class="minf__btn" :disabled="exportando" @click="bajar(i.key, 'pdf')">PDF</button>
          <button type="button" class="minf__btn minf__btn--linea" :disabled="exportando" @click="bajar(i.key, 'xlsx')">Excel</button>
        </div>
      </article>
    </template>

    <!-- Compu: solapas, y el informe a la vista tal como se descarga. -->
    <template v-else>
      <div class="minf__solapas" role="tablist" aria-label="Informes">
        <button v-for="i in INFORMES" :key="i.key" type="button" role="tab" :aria-selected="activo === i.key"
                class="minf__solapa" :class="{ 'is-on': activo === i.key }" @click="activo = i.key">
          <strong>{{ i.titulo }}</strong><span>{{ i.pregunta }}</span>
        </button>
      </div>

      <section class="minf__hoja">
        <div class="minf__hoja-cab">
          <div>
            <h2 class="minf__hoja-t">{{ vista?.titulo || tituloActivo }}</h2>
            <p class="minf__hoja-p">{{ vista?.periodo }}</p>
          </div>
          <div class="minf__descargas">
            <button type="button" class="minf__btn" :disabled="exportando" @click="bajar(activo, 'pdf')">Descargar PDF</button>
            <button type="button" class="minf__btn minf__btn--linea" :disabled="exportando" @click="bajar(activo, 'xlsx')">Excel</button>
          </div>
        </div>
        <p v-if="datos[activo]?.resena" class="minf__resena">{{ datos[activo].resena }}</p>
        <div v-if="vista" class="minf__kpis">
          <div v-for="k in vista.kpis" :key="k.label" class="minf__kpi"><span>{{ k.label }}</span><strong>{{ k.valor }}</strong></div>
        </div>
        <div v-for="sec in vista?.secciones || []" :key="sec.titulo" class="minf__seccion">
          <h3 class="minf__seccion-t">{{ sec.titulo }}</h3>
          <p v-if="!sec.rows.length" class="minf__vacio">{{ sec.vacio }}</p>
          <div v-else class="minf__tabla-box">
            <table class="minf__tabla">
              <thead><tr><th v-for="(h, i) in sec.headers" :key="i">{{ h }}</th></tr></thead>
              <tbody><tr v-for="(r, i) in sec.rows" :key="i"><td v-for="(c, j) in r" :key="j">{{ c }}</td></tr></tbody>
            </table>
          </div>
        </div>
        <p v-if="cargando" class="minf__vacio">Cargando…</p>
      </section>
    </template>
  </div>
</template>

<script setup>
import { ref, computed, watch } from 'vue'
import api from '../../lib/api'
import { descargarArchivo } from '../../lib/descargas.js'
import { useToast } from '../../composables/useToast.js'
import { hoyISO } from '../../utils/dates.js'

const props = defineProps({ variante: { type: String, default: 'escritorio' } }) // 'telefono' | 'escritorio'

const INFORMES = [
  { key: 'mi_cosecha',     titulo: 'Mi cosecha',     pregunta: '¿Cuánto rindió cada planta y cada genética?', icono: 'bi-flower1' },
  { key: 'de_donde_salio', titulo: 'De dónde salió', pregunta: 'Cada frasco con su planta, su genética y su QR.', icono: 'bi-qr-code' },
  { key: 'mis_gastos',     titulo: 'Mis gastos',     pregunta: '¿Cuánto puse y cuánto me costó cada gramo?', icono: 'bi-cash-coin' },
]
// Los mismos períodos que entiende el backend (`InformesController::PERIODO_RANGOS`); «Todo» va por fechas.
const PERIODOS = [
  { key: 'mes_actual',   label: 'Este mes' },
  { key: 'mes_anterior', label: 'Mes anterior' },
  { key: 'trimestre',    label: '3 meses' },
  { key: 'anio',         label: 'Este año' },
  { key: 'todo',         label: 'Todo' },
]

const toast = useToast()
const periodo = ref('anio')
const activo  = ref('mi_cosecha')
const datos   = ref({})
const cargando = ref(false)
const exportando = ref(false)

const params = computed(() => (periodo.value === 'todo' ? { desde: '2000-01-01', hasta: hoyISO() } : { periodo: periodo.value }))
const vista = computed(() => datos.value[activo.value]?.vista)
const tituloActivo = computed(() => INFORMES.find(i => i.key === activo.value)?.titulo)

async function cargar() {
  cargando.value = true
  const claves = props.variante === 'telefono' ? INFORMES.map(i => i.key) : [activo.value]
  try {
    const res = await Promise.all(claves.map(k => api.get(`/informes/${k}`, { params: params.value }).then(r => [k, r.data]).catch(() => [k, null])))
    datos.value = { ...datos.value, ...Object.fromEntries(res) }
  } finally { cargando.value = false }
}
watch([periodo, activo], cargar, { immediate: true })

// El resumen de cada tarjeta: los números destacados del mismo informe, en una línea.
function resumen(key) {
  const v = datos.value[key]?.vista
  if (!v) return cargando.value ? 'Cargando…' : 'Sin datos en el período.'
  return v.kpis.map(k => `${k.label}: ${k.valor}`).join(' · ')
}

async function bajar(key, formato) {
  exportando.value = true
  try {
    await descargarArchivo(`/informes/${key}.${formato}`, { params: params.value, filename: `${key}_${hoyISO()}.${formato}` })
  } catch (e) {
    toast.error(e.message || 'No se pudo descargar')
  } finally { exportando.value = false }
}
</script>

<style scoped>
.minf { display: flex; flex-direction: column; gap: var(--sp-4); }
.minf__periodos { display: flex; flex-wrap: wrap; gap: 6px; }
.minf__periodo { min-height: 38px; padding: 0 14px; border-radius: 999px; border: 1px solid var(--c-ink-300); background: var(--c-slate-50); font: inherit; font-size: var(--fs-13); font-weight: 600; color: var(--c-ink-900); cursor: pointer; }
.minf__periodo.is-on { background: var(--c-leaf-800); border-color: var(--c-leaf-800); color: var(--c-slate-50); }
.minf__tarjeta { background: var(--c-slate-50); border: 1px solid var(--c-leaf-100); border-radius: 16px; padding: var(--sp-4); display: flex; flex-direction: column; gap: var(--sp-3); }
.minf__tarjeta-cab { display: flex; gap: var(--sp-3); align-items: flex-start; }
.minf__ini { width: 40px; height: 40px; border-radius: 12px; display: grid; place-items: center; flex-shrink: 0; font-size: 1.1rem; color: var(--c-leaf-800); }
.minf__ini--mi_cosecha { background: var(--c-leaf-100); }
.minf__ini--de_donde_salio { background: var(--c-sky-100); color: var(--c-sky-600); }
.minf__ini--mis_gastos { background: var(--c-amber-100); color: var(--c-gold-500); }
.minf__tarjeta-t { margin: 0; font-size: var(--fs-16); font-weight: 700; color: var(--c-ink-900); }
.minf__tarjeta-p { margin: 2px 0 0; font-size: var(--fs-13); color: var(--c-ink-700); }
.minf__resumen { margin: 0; padding: 10px 12px; border-radius: 10px; background: var(--c-paper); font-size: var(--fs-13); line-height: 1.45; color: var(--c-ink-900); }
.minf__descargas { display: flex; gap: var(--sp-2); }
.minf--telefono .minf__descargas { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); }
.minf__btn { min-height: 44px; padding: 0 18px; border-radius: var(--r-xl); border: 0; background: var(--c-leaf-700); color: var(--c-slate-50); font: inherit; font-weight: 700; cursor: pointer; }
.minf__btn:disabled { opacity: .5; }
.minf__btn--linea { background: var(--c-slate-50); color: var(--c-ink-900); border: 1px solid var(--c-ink-300); }
.minf__solapas { display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: var(--sp-2); }
.minf__solapa { text-align: left; padding: 14px 16px; border-radius: 14px; border: 1px solid var(--c-leaf-100); background: var(--c-slate-50); display: flex; flex-direction: column; gap: 4px; font: inherit; color: var(--c-ink-900); cursor: pointer; }
.minf__solapa span { font-size: var(--fs-13); color: var(--c-ink-700); }
.minf__solapa.is-on { border: 2px solid var(--c-leaf-700); }
.minf__hoja { background: var(--c-slate-50); border: 1px solid var(--c-leaf-100); border-radius: 16px; padding: var(--sp-6); display: flex; flex-direction: column; gap: var(--sp-4); }
.minf__hoja-cab { display: flex; justify-content: space-between; align-items: flex-start; gap: var(--sp-3); flex-wrap: wrap; }
.minf__hoja-t { margin: 0; font-size: var(--fs-20); font-weight: 800; color: var(--c-ink-900); }
.minf__hoja-p { margin: 2px 0 0; font-size: var(--fs-13); color: var(--c-ink-700); }
.minf__resena { margin: 0; font-size: var(--fs-14); color: var(--c-ink-700); line-height: 1.5; }
.minf__kpis { display: grid; grid-template-columns: repeat(auto-fit, minmax(160px, 1fr)); gap: var(--sp-2); }
.minf__kpi { background: var(--c-paper); border-radius: 12px; padding: 12px 14px; display: flex; flex-direction: column; gap: 2px; }
.minf__kpi span { font-size: var(--fs-12); font-weight: 600; color: var(--c-ink-700); }
.minf__kpi strong { font-size: var(--fs-20); color: var(--c-ink-900); }
.minf__seccion { display: flex; flex-direction: column; }
.minf__seccion-t { margin: 0 0 8px; font-size: var(--fs-14); font-weight: 700; color: var(--c-ink-900); }
.minf__vacio { margin: 0; font-size: var(--fs-13); color: var(--c-ink-700); }
.minf__tabla-box { overflow-x: auto; border: 1px solid var(--c-leaf-100); border-radius: 12px; }
.minf__tabla { width: 100%; border-collapse: collapse; font-size: var(--fs-14); }
.minf__tabla th { background: var(--c-paper); text-align: left; font-size: var(--fs-12); font-weight: 700; color: var(--c-ink-700); padding: 10px 12px; white-space: nowrap; }
.minf__tabla td { padding: 10px 12px; border-top: 1px solid var(--c-ink-100); color: var(--c-ink-900); }
</style>
