<template>
  <div class="cd">
    <div v-if="cargando && !cama" class="cd__cargando"><span class="spinner-border spinner-border-sm"></span> Cargando la cama…</div>
    <div v-else-if="errorCarga" class="cd__error">{{ errorCarga }}</div>

    <template v-else-if="cama">
      <header class="cd__head">
        <RouterLink :to="rutaSala" class="cd__volver"><i class="bi bi-arrow-left"></i> {{ cama.sala_nombre }}</RouterLink>
        <div class="cd__titulo">
          <h1>{{ cama.nombre }}</h1>
          <span class="cd__estado" :class="`cd__estado--${estado.clase}`"><i :class="['bi', estado.icon]"></i> {{ estado.label }}</span>
        </div>
        <p class="cd__meta">
          <span v-if="cama.m2">{{ fmtNum(cama.largo_m) }} × {{ fmtNum(cama.ancho_m) }} m · {{ fmtNum(cama.m2) }} m²</span>
          <span v-if="cama.litros_suelo">{{ fmtNum(cama.litros_suelo, 0) }} L de tierra</span>
          <span v-if="cama.armada_el">Armada el {{ fechaLarga(cama.armada_el) }}<template v-if="cama.edad_dias"> ({{ edadCama(cama.edad_dias).replace('armada ', '') }})</template></span>
          <span>{{ cama.ciclos_count }} {{ cama.ciclos_count === 1 ? 'ciclo' : 'ciclos' }}</span>
        </p>
        <p v-if="paso" class="cd__paso" :class="{ 'cd__paso--alerta': paso.alerta }"><i class="bi bi-clock"></i> {{ paso.texto }}</p>

        <div v-if="puedeRegistrar && cama.estado !== 'retirada'" class="cd__acciones">
          <button type="button" class="cd__btn cd__btn--primary" @click="modal = 'alimentar'"><i class="bi bi-basket"></i> Alimentar</button>
          <button type="button" class="cd__btn" @click="modal = 'regar'"><i class="bi bi-droplet"></i> Regar</button>
          <button type="button" class="cd__btn" @click="abrirRegistro('cobertura')"><i class="bi bi-flower3"></i> Cobertura / mulch</button>
          <button v-if="cama.estado === 'cocinando'" type="button" class="cd__btn" @click="yaLista"><i class="bi bi-check2"></i> Ya está lista</button>
          <button v-if="cama.estado === 'descansando'" type="button" class="cd__btn" @click="terminarDescanso"><i class="bi bi-sunrise"></i> Terminar descanso</button>
          <button v-if="['descansando', 'lista'].includes(cama.estado)" type="button" class="cd__btn" @click="modal = 'descanso'"><i class="bi bi-moon-stars"></i> {{ cama.estado === 'descansando' ? 'Cambiar descanso' : 'Descansar' }}</button>
          <button type="button" class="cd__btn" @click="modal = 'analisis'"><i class="bi bi-clipboard2-pulse"></i> Análisis de suelo</button>
          <button type="button" class="cd__btn" @click="modal = 'editar'"><i class="bi bi-pencil"></i> Editar</button>
          <button v-if="cama.estado !== 'en_uso'" type="button" class="cd__btn cd__btn--ghost" @click="retirarOBorrar"><i class="bi bi-archive"></i> {{ cama.ciclos_count ? 'Retirar' : 'Borrar' }}</button>
        </div>
      </header>

      <section v-if="cama.con_costo || cama.gramos_cosechados" class="cd__kpis">
        <div class="cd__kpi"><span class="cd__kpi-n">{{ fmtNum(cama.gramos_cosechados, 1) }} g</span><span class="cd__kpi-l">cosechados en la cama</span></div>
        <div v-if="mejorGm2" class="cd__kpi"><span class="cd__kpi-n">{{ fmtNum(mejorGm2, 1) }} g/m²</span><span class="cd__kpi-l">el mejor ciclo</span></div>
        <template v-if="cama.con_costo">
          <div class="cd__kpi"><span class="cd__kpi-n">{{ formatARS(cama.invertido_ars) }}</span><span class="cd__kpi-l">puesto en la cama</span></div>
          <div class="cd__kpi"><span class="cd__kpi-n">{{ cama.costo_por_gramo != null ? formatARS(cama.costo_por_gramo) : '—' }}</span>
            <span class="cd__kpi-l">{{ cama.costo_por_gramo != null ? 'por gramo (baja cosecha tras cosecha)' : 'por gramo: falta la primera cosecha' }}</span></div>
        </template>
      </section>

      <section v-if="cama.lotes.length" class="cd__bloque">
        <h2>En la cama ahora</h2>
        <div class="cd__lotes">
          <RouterLink v-for="l in cama.lotes" :key="l.id" :to="rutaLote(l)" class="cd__lote">
            <strong>{{ l.codigo }}</strong><span>{{ l.genetica || 'Sin genética' }} · {{ l.plants_count }} plantas · {{ ESTADO_LOTE[l.estado] || l.estado }}</span>
            <span v-if="l.m2_ocupados" class="cd__lote-m2">{{ fmtNum(l.m2_ocupados) }} m²</span>
          </RouterLink>
        </div>
      </section>

      <section class="cd__bloque">
        <h2>Cosecha tras cosecha</h2>
        <p v-if="!cama.ciclos.length" class="cd__vacio">Todavía no pasó ningún lote por esta cama.</p>
        <div v-else class="cd__tabla-wrap">
          <table class="cd__tabla">
            <thead><tr><th>Ciclo</th><th>Fechas</th><th>Lotes</th><th class="num">Gramos</th><th class="num">g/m²</th><th v-if="cama.con_costo" class="num">Suelo</th></tr></thead>
            <tbody>
              <tr v-for="(ci, i) in cama.ciclos" :key="ci.id">
                <td><strong>{{ ci.numero }}</strong><span v-if="!ci.hasta" class="cd__abierto">en curso</span></td>
                <td>{{ fechaCorta(ci.desde) }} → {{ ci.hasta ? fechaCorta(ci.hasta) : 'hoy' }} <span class="cd__gris">({{ ci.dias }} d)</span></td>
                <td><RouterLink v-for="l in ci.lotes" :key="l.id" :to="rutaLote(l)" class="cd__chip">{{ l.genetica || l.codigo }}</RouterLink></td>
                <td class="num">{{ ci.gramos ? fmtNum(ci.gramos, 1) : '—' }}</td>
                <td class="num">{{ ci.g_m2 ? fmtNum(ci.g_m2, 1) : '—' }}
                  <span v-if="delta(i) != null" class="cd__delta" :class="delta(i) >= 0 ? 'cd__delta--up' : 'cd__delta--down'">{{ delta(i) >= 0 ? '+' : '' }}{{ delta(i) }} %</span></td>
                <td v-if="cama.con_costo" class="num">{{ formatARS(ci.costo_ars) }}</td>
              </tr>
            </tbody>
          </table>
        </div>
        <p v-if="cama.ciclos.length && !cama.m2" class="cd__gris">Sin medidas de la cama no hay g/m²: cargá el largo y el ancho.</p>
      </section>

      <section class="cd__bloque">
        <h2>Lo que se le puso al suelo</h2>
        <div v-if="cama.mezcla?.items?.length" class="cd__mezcla">
          <strong>Mezcla de armado:</strong>
          {{ cama.mezcla.items.map(i => `${i.nombre} ${fmtNum(i.cantidad, 3)} ${unidadCorta(i.unidad)}`).join(' · ') }}
        </div>
        <p v-if="!registros.length" class="cd__vacio">Sin registros todavía. «Alimentar» anota top dress, tés, cobertura, mulch o inoculación.</p>
        <ul v-else class="cd__registros">
          <li v-for="r in registros" :key="r.id" class="cd__registro">
            <i :class="['bi', ICONO_REGISTRO[r.tipo] || 'bi-dot']" class="cd__registro-icon"></i>
            <div class="cd__registro-body">
              <div class="cd__registro-top">
                <strong>{{ r.tipo === 'top_dress' && r.recarga ? 'Recarga (top dress)' : r.tipo_label }}</strong>
                <span class="cd__gris">{{ fechaCorta(r.registrado_en) }}<template v-if="r.ciclo_numero"> · ciclo {{ r.ciclo_numero }}</template><template v-else> · sin plantas</template></span>
              </div>
              <p v-if="descripcion(r)" class="cd__registro-desc">{{ descripcion(r) }}</p>
              <p v-if="r.observaciones" class="cd__registro-obs">{{ r.observaciones }}</p>
            </div>
            <span v-if="cama.con_costo && r.costo_ars" class="cd__registro-costo">{{ formatARS(r.costo_ars) }}</span>
            <button v-if="esAdmin" type="button" class="cd__borrar" :aria-label="`Borrar ${r.tipo_label}`" @click="borrarRegistro(r)"><i class="bi bi-trash"></i></button>
          </li>
        </ul>
      </section>

      <section class="cd__bloque">
        <h2>Análisis de suelo</h2>
        <p v-if="!cama.analisis.length" class="cd__vacio">Sin análisis. Un análisis por cosecha muestra cómo evoluciona la cama.</p>
        <div v-else class="cd__tabla-wrap">
          <table class="cd__tabla">
            <thead><tr><th>Fecha</th><th class="num">pH</th><th class="num">CE</th><th class="num">MO %</th><th class="num">N %</th><th class="num">P</th><th class="num">K</th><th>Metales</th><th></th></tr></thead>
            <tbody>
              <tr v-for="a in cama.analisis" :key="a.id">
                <td>{{ fechaCorta(a.fecha) }}<span v-if="a.laboratorio" class="cd__gris"> · {{ a.laboratorio }}</span></td>
                <td class="num">{{ v(a.ph) }}</td><td class="num">{{ v(a.ce) }}</td><td class="num">{{ v(a.materia_organica_pct) }}</td>
                <td class="num">{{ v(a.nitrogeno_pct) }}</td><td class="num">{{ v(a.fosforo_ppm) }}</td><td class="num">{{ v(a.potasio_ppm) }}</td>
                <td>{{ metales(a) }}</td>
                <td><a v-if="a.archivo_url" :href="a.archivo_url" target="_blank" rel="noopener">Informe</a></td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>
    </template>

    <RegistroCamaModal v-if="cama && modal === 'alimentar'" :camas="[cama]" :cama-id="cama.id" cama-fija :tipo-inicial="tipoInicial" @close="modal = null" @guardado="alGuardar" />
    <RegarCamaModal v-if="cama && modal === 'regar'" :camas="[cama]" :cama-id="cama.id" cama-fija @close="modal = null" @guardado="alGuardar" />
    <DescansoCamaModal v-if="cama && modal === 'descanso'" :cama="cama" @close="modal = null" @guardado="alGuardar" />
    <AnalisisSueloModal v-if="cama && modal === 'analisis'" :cama="cama" @close="modal = null" @guardado="alGuardar" />
    <CamaFormModal v-if="cama && modal === 'editar' && sala" :sala="sala" :cama="cama" @close="modal = null" @guardada="alGuardar" />
  </div>
</template>

<script setup>
// La ficha de una cama de suelo vivo. Es la misma pantalla en el escritorio (/camas/:id) y en el
// teléfono (/m/cama-m/:id): lo que se hace todos los días (alimentar, regar) tiene que estar en los
// dos. Lo que muestra lo calcula el backend (estado, qué viene, g/m² por ciclo, costo por gramo).
import { ref, computed, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import RegistroCamaModal from '../components/camas/RegistroCamaModal.vue'
import RegarCamaModal from '../components/camas/RegarCamaModal.vue'
import DescansoCamaModal from '../components/camas/DescansoCamaModal.vue'
import AnalisisSueloModal from '../components/camas/AnalisisSueloModal.vue'
import CamaFormModal from '../components/camas/CamaFormModal.vue'
import { getCama, getSala, listRegistrosCama, deleteRegistroCama, terminarCoccionCama, terminarDescansoCama, retirarCama, deleteCama } from '../lib/api.js'
import { estadoCama, textoProximoPaso, fmtNum, fechaCorta, ICONO_REGISTRO, unidadCorta, aguaLabel, edadCama } from '../lib/camas.js'
import { formatARS } from '../lib/formatters.js'
import { formatFechaLarga } from '../utils/dates.js'
import { useAuthStore } from '../stores/auth'
import { useToast } from '../composables/useToast.js'
import { useConfirm } from '../composables/useConfirm.js'
import { useRecargaEnCambios } from '../composables/useRecargaEnCambios.js'

const route = useRoute()
const router = useRouter()
const auth = useAuthStore()
const toast = useToast()
const { confirm } = useConfirm()

const ESTADO_LOTE = { enraizado: 'enraizando', vegetativo: 'vegetativo', floracion: 'floración' }
const id = computed(() => Number(route.params.id))
const enTelefono = computed(() => route.path.startsWith('/m/'))
const cama = ref(null)
const sala = ref(null)
const registros = ref([])
const cargando = ref(false)
const errorCarga = ref(null)
const modal = ref(route.query.accion === 'alimentar' ? 'alimentar' : route.query.accion === 'regar' ? 'regar' : null)
const tipoInicial = ref('top_dress')

const esAdmin = computed(() => auth.user?.role === 'admin')
const puedeRegistrar = computed(() => ['admin', 'supervisor', 'cultivador'].includes(auth.user?.role))
const estado = computed(() => estadoCama(cama.value?.estado))
const paso = computed(() => textoProximoPaso(cama.value?.proximo_paso))
const rutaSala = computed(() => (enTelefono.value ? `/m/sala-m/${cama.value?.sala_id}` : `/salas/${cama.value?.sala_id}`))
const rutaLote = (l) => (enTelefono.value ? `/m/lote-m/${l.id}` : `/lotes/${l.id}`)
const mejorGm2 = computed(() => Math.max(0, ...(cama.value?.ciclos || []).map(c => c.g_m2 || 0)) || null)
const fechaLarga = (d) => formatFechaLarga(`${d}T12:00:00`)
const v = (n) => (n == null ? '—' : fmtNum(n))

// El ciclo contra el anterior (la tabla viene del más nuevo al más viejo).
function delta(i) {
  const act = cama.value.ciclos[i]?.g_m2
  const ant = cama.value.ciclos[i + 1]?.g_m2
  if (!act || !ant) return null
  return Math.round(((act - ant) / ant) * 100)
}

function descripcion(r) {
  const partes = []
  if (r.detalle) partes.push(r.detalle)
  const items = r.nutricion?.items || []
  if (items.length) partes.push(items.map(i => `${i.nombre} ${fmtNum(i.descontado ?? i.cantidad, 3)} ${unidadCorta(i.unidad)}`).join(', '))
  if (r.nutricion?.receta_nombre) partes.push(`receta «${r.nutricion.receta_nombre}»`)
  if (r.litros) partes.push(`${fmtNum(r.litros)} L`)
  if (r.agua) partes.push(`agua ${aguaLabel(r.agua).toLowerCase()}`)
  if (r.humedad_suelo != null) partes.push(`humedad ${fmtNum(r.humedad_suelo)} %`)
  if (r.temperatura_suelo != null) partes.push(`${fmtNum(r.temperatura_suelo, 1)} °C`)
  return partes.join(' · ')
}

function metales(a) {
  const m = [['Pb', a.plomo_ppm], ['Cd', a.cadmio_ppm], ['As', a.arsenico_ppm], ['Hg', a.mercurio_ppm]].filter(([, x]) => x != null)
  return m.length ? m.map(([s, x]) => `${s} ${fmtNum(x, 3)}`).join(' · ') : '—'
}

async function cargar() {
  cargando.value = true
  errorCarga.value = null
  try {
    const [{ data }, regs] = await Promise.all([getCama(id.value), listRegistrosCama(id.value)])
    cama.value = data
    registros.value = regs.data || []
    // Llegó desde el «+» con una acción: el modal ya está abierto; se limpia la URL para que
    // volver o recargar no lo abra de nuevo.
    if (route.query.accion) router.replace({ path: route.path })
    getSala(data.sala_id).then(({ data: s }) => { sala.value = s }).catch(() => { sala.value = { id: data.sala_id, nombre: data.sala_nombre } })
  } catch (e) {
    errorCarga.value = e?.response?.status === 404 ? 'No encontramos esa cama (o no es de tus espacios).' : 'No se pudo cargar la cama.'
  } finally {
    cargando.value = false
  }
}
watch(id, cargar, { immediate: true })
useRecargaEnCambios(['camas', 'lotes'], cargar)

function abrirRegistro(tipo) { tipoInicial.value = tipo; modal.value = 'alimentar' }
function alGuardar() { modal.value = null; cargar() }

async function yaLista() {
  try { await terminarCoccionCama(cama.value.id); toast.success(`La ${cama.value.nombre} está lista`); cargar() }
  catch (e) { toast.error(e?.response?.data?.error || 'No se pudo actualizar') }
}
async function terminarDescanso() {
  try { await terminarDescansoCama(cama.value.id); toast.success(`La ${cama.value.nombre} terminó su descanso`); cargar() }
  catch (e) { toast.error(e?.response?.data?.error || 'No se pudo actualizar') }
}
async function retirarOBorrar() {
  const borrar = !cama.value.ciclos_count
  const ok = await confirm({
    title: borrar ? `¿Borrar la ${cama.value.nombre}?` : `¿Retirar la ${cama.value.nombre}?`,
    message: borrar
      ? 'Nunca tuvo lotes: se borra, y lo que se descontó al armarla vuelve al stock.'
      : 'Se desarmó: deja de ocupar el espacio, pero su historia queda (qué comieron las flores que salieron de ella).',
    confirmText: borrar ? 'Borrar' : 'Retirar', variant: 'warning',
  })
  if (!ok) return
  try {
    if (borrar) await deleteCama(cama.value.id)
    else await retirarCama(cama.value.id)
    toast.success(borrar ? 'Cama borrada' : 'Cama retirada')
    router.push(rutaSala.value)
  } catch (e) { toast.error(e?.response?.data?.error || e?.response?.data?.errors?.join(', ') || 'No se pudo') }
}
async function borrarRegistro(r) {
  const ok = await confirm({ title: `¿Borrar ${r.tipo_label.toLowerCase()} del ${fechaCorta(r.registrado_en)}?`, message: 'Lo que descontó vuelve al stock.', confirmText: 'Borrar' })
  if (!ok) return
  try { await deleteRegistroCama(cama.value.id, r.id); toast.success('Registro borrado'); cargar() }
  catch (e) { toast.error(e?.response?.data?.error || 'No se pudo borrar') }
}
</script>

<style scoped>
.cd { max-width: 1100px; margin: 0 auto; padding: 1.25rem 1rem 2rem; display: flex; flex-direction: column; gap: 1.1rem; }
.cd__cargando, .cd__error { padding: 2rem; text-align: center; color: var(--c-slate-500); }
.cd__head { display: flex; flex-direction: column; gap: .45rem; }
.cd__volver { color: var(--c-slate-500); text-decoration: none; font-size: var(--fs-13); display: inline-flex; gap: .35rem; align-items: center; }
.cd__titulo { display: flex; gap: .6rem; align-items: center; flex-wrap: wrap; }
.cd__titulo h1 { font-size: var(--fs-24); font-weight: 800; color: var(--c-slate-900); margin: 0; }
.cd__estado { font-size: var(--fs-13); font-weight: 700; border-radius: var(--r-pill); padding: 2px .65rem; display: inline-flex; gap: .3rem; align-items: center; }
.cd__estado--leaf  { background: var(--c-leaf-100); color: var(--c-leaf-800); }
.cd__estado--amber { background: var(--c-amber-100); color: var(--c-slate-900); }
.cd__estado--sky   { background: var(--c-sky-100); color: var(--c-sky-600); }
.cd__estado--ink   { background: var(--c-ink-100); color: var(--c-ink-700); }
.cd__meta { display: flex; flex-wrap: wrap; gap: .25rem 1rem; color: var(--c-slate-500); font-size: var(--fs-14); margin: 0; }
.cd__paso { margin: 0; font-size: var(--fs-14); color: var(--c-slate-700); display: flex; gap: .4rem; }
.cd__paso--alerta { color: var(--c-rust-600); font-weight: 700; }
.cd__acciones { display: flex; flex-wrap: wrap; gap: .4rem; margin-top: .25rem; }
.cd__btn {
  background: var(--c-paper); border: 1.5px solid var(--c-slate-200); border-radius: var(--r-md); padding: .5rem .8rem;
  font-size: var(--fs-13); font-weight: 700; color: var(--c-slate-700); cursor: pointer; display: inline-flex; gap: .35rem; align-items: center;
}
.cd__btn--primary { background: var(--c-leaf-700); border-color: var(--c-leaf-700); color: var(--c-paper); }
.cd__btn--ghost { color: var(--c-slate-500); }
.cd__kpis { display: grid; grid-template-columns: repeat(auto-fit, minmax(170px, 1fr)); gap: .6rem; }
.cd__kpi { background: var(--c-paper); border: 1px solid var(--c-slate-200); border-radius: var(--r-lg); padding: .75rem .9rem; display: flex; flex-direction: column; gap: .15rem; }
.cd__kpi-n { font-size: var(--fs-20); font-weight: 800; color: var(--c-slate-900); }
.cd__kpi-l { font-size: var(--fs-12); color: var(--c-slate-500); }
.cd__bloque { background: var(--c-paper); border: 1px solid var(--c-slate-200); border-radius: var(--r-lg); padding: .9rem 1rem; display: flex; flex-direction: column; gap: .6rem; min-width: 0; }
.cd__bloque h2 { font-size: var(--fs-16); font-weight: 800; color: var(--c-slate-900); margin: 0; }
.cd__vacio { margin: 0; color: var(--c-slate-500); font-size: var(--fs-14); }
.cd__gris { color: var(--c-slate-500); font-size: var(--fs-13); }
.cd__lotes { display: grid; grid-template-columns: repeat(auto-fill, minmax(220px, 1fr)); gap: .5rem; }
.cd__lote { border: 1px solid var(--c-slate-200); border-radius: var(--r-md); padding: .55rem .7rem; text-decoration: none; color: var(--c-slate-700); display: flex; flex-direction: column; gap: .1rem; font-size: var(--fs-13); }
.cd__lote strong { color: var(--c-slate-900); font-size: var(--fs-14); }
.cd__lote-m2 { color: var(--c-slate-500); }
.cd__tabla-wrap { overflow-x: auto; }
.cd__tabla { width: 100%; border-collapse: collapse; font-size: var(--fs-13); }
.cd__tabla th { text-align: left; font-size: var(--fs-12); text-transform: uppercase; letter-spacing: .04em; color: var(--c-slate-500); padding: .4rem .5rem; border-bottom: 1px solid var(--c-slate-200); white-space: nowrap; }
.cd__tabla td { padding: .5rem; border-bottom: 1px solid var(--c-slate-100); vertical-align: top; }
.cd__tabla .num { text-align: right; white-space: nowrap; }
.cd__abierto { margin-left: .35rem; font-size: var(--fs-12); color: var(--c-leaf-700); font-weight: 700; }
.cd__chip { display: inline-block; margin: 0 .25rem .2rem 0; font-size: var(--fs-12); background: var(--c-slate-100); color: var(--c-slate-700); border-radius: var(--r-pill); padding: 1px .5rem; text-decoration: none; }
.cd__delta { margin-left: .3rem; font-size: var(--fs-12); font-weight: 700; }
.cd__delta--up { color: var(--c-leaf-700); }
.cd__delta--down { color: var(--c-rust-600); }
.cd__mezcla { font-size: var(--fs-13); color: var(--c-slate-700); background: var(--c-slate-50); border-radius: var(--r-md); padding: .5rem .7rem; }
.cd__registros { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; }
.cd__registro { display: flex; gap: .6rem; align-items: flex-start; padding: .55rem 0; border-bottom: 1px solid var(--c-slate-100); }
.cd__registro-icon { color: var(--c-leaf-700); font-size: 1.05rem; margin-top: .1rem; }
.cd__registro-body { flex: 1; min-width: 0; }
.cd__registro-top { display: flex; gap: .5rem; flex-wrap: wrap; align-items: baseline; font-size: var(--fs-14); color: var(--c-slate-900); }
.cd__registro-desc, .cd__registro-obs { margin: .1rem 0 0; font-size: var(--fs-13); color: var(--c-slate-600); overflow-wrap: anywhere; }
.cd__registro-obs { font-style: italic; }
.cd__registro-costo { font-size: var(--fs-13); color: var(--c-slate-600); white-space: nowrap; }
.cd__borrar { background: none; border: none; color: var(--c-slate-400); cursor: pointer; }
@media (max-width: 600px) {
  .cd { padding: .9rem .9rem 6rem; }
  .cd__titulo h1 { font-size: var(--fs-20); }
  .cd__acciones .cd__btn { flex: 1 1 calc(50% - .4rem); justify-content: center; }
}
</style>
