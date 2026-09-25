<template>
  <section class="cs" aria-label="Camas">
    <header class="cs__head">
      <div>
        <h3 class="cs__title"><i class="bi bi-bricks"></i> Camas</h3>
        <p v-if="resumenM2" class="cs__sub">{{ resumenM2 }}</p>
      </div>
      <button v-if="puedeEditar" type="button" class="cs__btn" @click="abrirNueva"><i class="bi bi-plus-lg"></i> Nueva cama</button>
    </header>

    <p v-if="!camas.length" class="cs__vacio">
      ¿Cultivás en suelo vivo? Cargá tus camas: cada una guarda con qué la armaste, qué le fuiste poniendo,
      cuánto rindió cada cosecha y cuándo descansa.
    </p>

    <div v-else class="cs__lista">
      <article v-for="c in camas" :key="c.id" class="cs__card" :class="`cs__card--${estadoCama(c.estado).clase}`">
        <div class="cs__card-top">
          <RouterLink :to="rutaCama(c)" class="cs__nombre">{{ c.nombre }}</RouterLink>
          <span class="cs__estado" :class="`cs__estado--${estadoCama(c.estado).clase}`"><i :class="['bi', estadoCama(c.estado).icon]"></i> {{ estadoCama(c.estado).label }}</span>
        </div>
        <p class="cs__meta">
          <span v-if="c.m2">{{ fmtNum(c.m2) }} m²</span>
          <span v-if="c.ciclo_actual">Ciclo {{ c.ciclo_actual.numero }} · día {{ c.ciclo_actual.dias }}</span>
          <span v-else-if="c.ciclos_count">{{ c.ciclos_count }} {{ c.ciclos_count === 1 ? 'cosecha' : 'cosechas' }}</span>
          <span v-if="c.edad_dias != null">{{ edad(c.edad_dias) }}</span>
        </p>
        <p v-if="paso(c)" class="cs__paso" :class="{ 'cs__paso--alerta': paso(c).alerta }"><i class="bi bi-clock"></i> {{ paso(c).texto }}</p>
        <div v-if="c.lotes.length" class="cs__lotes">
          <RouterLink v-for="l in c.lotes" :key="l.id" :to="rutaLote(l)" class="cs__lote">
            {{ esPersonal ? (l.genetica || l.codigo) : l.codigo }}<span v-if="!esPersonal && l.genetica"> · {{ l.genetica }}</span>
          </RouterLink>
        </div>
        <div v-if="puedeRegistrar" class="cs__acciones">
          <button type="button" class="cs__accion" @click="abrir('alimentar', c)"><i class="bi bi-basket"></i> Alimentar</button>
          <button type="button" class="cs__accion" @click="abrir('regar', c)"><i class="bi bi-droplet"></i> Regar</button>
          <button v-if="c.estado === 'cocinando'" type="button" class="cs__accion" @click="yaLista(c)"><i class="bi bi-check2"></i> Ya está lista</button>
          <button v-else-if="c.estado === 'descansando'" type="button" class="cs__accion" @click="abrir('descanso', c)"><i class="bi bi-moon-stars"></i> Descanso</button>
          <button v-else-if="c.estado === 'lista'" type="button" class="cs__accion" @click="abrir('descanso', c)"><i class="bi bi-moon"></i> Descansar</button>
        </div>
      </article>
    </div>

    <CamaFormModal v-if="modal === 'form'" :sala="sala" :cama="camaSel" @close="cerrar" @guardada="guardado" />
    <RegistroCamaModal v-if="modal === 'alimentar'" :camas="camas" :cama-id="camaSel?.id" @close="cerrar" @guardado="guardado" />
    <RegarCamaModal v-if="modal === 'regar'" :camas="camas" :cama-id="camaSel?.id" @close="cerrar" @guardado="guardado" />
    <DescansoCamaModal v-if="modal === 'descanso'" :cama="camaSel" @close="cerrar" @guardado="guardado" />
  </section>
</template>

<script setup>
// Las camas de suelo vivo de un espacio: la tarjeta de cada una (estado, qué viene, sus lotes) y
// lo de todos los días (alimentar, regar, descansar). Va en la ficha del espacio del escritorio y
// del teléfono: lo que se hace todos los días tiene que estar en el teléfono.
import { ref, computed } from 'vue'
import { useRoute } from 'vue-router'
import CamaFormModal from './CamaFormModal.vue'
import RegistroCamaModal from './RegistroCamaModal.vue'
import RegarCamaModal from './RegarCamaModal.vue'
import DescansoCamaModal from './DescansoCamaModal.vue'
import { terminarCoccionCama } from '../../lib/api.js'
import { estadoCama, textoProximoPaso, fmtNum, edadCama } from '../../lib/camas.js'
import { useUsoPersonal } from '../../composables/useUsoPersonal.js'
import { useAuthStore } from '../../stores/auth'
import { useToast } from '../../composables/useToast.js'

const props = defineProps({
  sala: { type: Object, required: true }, // el detalle de la sala: trae `camas` (resúmenes) y los m²
})
const emit = defineEmits(['cambio'])
const route = useRoute()
const auth = useAuthStore()
const toast = useToast()
const { esPersonal, sala: salaTxt } = useUsoPersonal()

const camas = computed(() => props.sala.camas || [])
const puedeRegistrar = computed(() => ['admin', 'supervisor', 'cultivador'].includes(auth.user?.role))
const puedeEditar = puedeRegistrar
const enTelefono = computed(() => route.path.startsWith('/m/'))
const rutaCama = (c) => (enTelefono.value ? `/m/cama-m/${c.id}` : `/camas/${c.id}`)
const rutaLote = (l) => (enTelefono.value ? `/m/lote-m/${l.id}` : `/lotes/${l.id}`)
const paso = (c) => textoProximoPaso(c.proximo_paso)
const edad = edadCama

const resumenM2 = computed(() => {
  const s = props.sala
  if (!camas.value.length) return null
  const total = camas.value.reduce((t, c) => t + (Number(c.m2) || 0), 0)
  if (s.m2 == null) return `${camas.value.length} ${camas.value.length === 1 ? 'cama' : 'camas'}${total ? ` · ${fmtNum(total)} m²` : ''} · sin medidas del ${salaTxt.value.corta}`
  return `${fmtNum(total)} de ${fmtNum(s.m2)} m² en camas · quedan ${fmtNum(s.m2_libres)} m² libres`
})

const modal = ref(null)
const camaSel = ref(null)
function abrirNueva() { camaSel.value = null; modal.value = 'form' }
function abrir(m, c) { camaSel.value = c; modal.value = m }
function cerrar() { modal.value = null; camaSel.value = null }
function guardado() { cerrar(); emit('cambio') }
async function yaLista(c) {
  try { await terminarCoccionCama(c.id); toast.success(`La ${c.nombre} está lista`); emit('cambio') }
  catch (e) { toast.error(e?.response?.data?.error || 'No se pudo actualizar la cama') }
}
defineExpose({ abrir })
</script>

<style scoped>
.cs { display: flex; flex-direction: column; gap: .75rem; }
.cs__head { display: flex; align-items: flex-start; justify-content: space-between; gap: .75rem; flex-wrap: wrap; }
.cs__title { font-size: var(--fs-16); font-weight: 800; color: var(--c-slate-900); margin: 0; display: flex; gap: .4rem; align-items: center; }
.cs__sub { font-size: var(--fs-13); color: var(--c-slate-500); margin: .15rem 0 0; }
.cs__btn {
  background: var(--c-leaf-700); color: var(--c-paper); border: none; border-radius: var(--r-md);
  padding: .5rem .9rem; font-weight: 700; font-size: var(--fs-13); cursor: pointer; display: inline-flex; gap: .35rem; align-items: center;
}
.cs__vacio { font-size: var(--fs-14); color: var(--c-slate-600); background: var(--c-slate-50); border: 1px dashed var(--c-slate-300); border-radius: var(--r-lg); padding: .9rem 1rem; margin: 0; }
.cs__lista { display: grid; grid-template-columns: repeat(auto-fill, minmax(260px, 1fr)); gap: .75rem; }
.cs__card { background: var(--c-paper); border: 1px solid var(--c-slate-200); border-left: 4px solid var(--c-slate-300); border-radius: var(--r-lg); padding: .8rem .9rem; display: flex; flex-direction: column; gap: .45rem; min-width: 0; }
.cs__card--leaf  { border-left-color: var(--c-leaf-600); }
.cs__card--amber { border-left-color: var(--c-amber-500); }
.cs__card--sky   { border-left-color: var(--c-sky-600); }
.cs__card-top { display: flex; justify-content: space-between; align-items: center; gap: .5rem; }
.cs__nombre { font-weight: 800; font-size: var(--fs-16); color: var(--c-slate-900); text-decoration: none; }
.cs__nombre:hover { text-decoration: underline; }
.cs__estado { font-size: var(--fs-12); font-weight: 700; border-radius: var(--r-pill); padding: 2px .55rem; display: inline-flex; gap: .25rem; align-items: center; white-space: nowrap; }
.cs__estado--leaf  { background: var(--c-leaf-100); color: var(--c-leaf-800); }
.cs__estado--amber { background: var(--c-amber-100); color: var(--c-slate-900); }
.cs__estado--sky   { background: var(--c-sky-100); color: var(--c-sky-600); }
.cs__estado--ink   { background: var(--c-ink-100); color: var(--c-ink-700); }
.cs__meta { display: flex; flex-wrap: wrap; gap: .25rem .75rem; font-size: var(--fs-13); color: var(--c-slate-500); margin: 0; }
.cs__paso { font-size: var(--fs-13); color: var(--c-slate-700); margin: 0; display: flex; gap: .35rem; }
.cs__paso--alerta { color: var(--c-rust-600); font-weight: 700; }
.cs__lotes { display: flex; flex-wrap: wrap; gap: .35rem; }
.cs__lote { font-size: var(--fs-12); background: var(--c-slate-100); color: var(--c-slate-700); border-radius: var(--r-pill); padding: 2px .6rem; text-decoration: none; }
.cs__acciones { display: flex; flex-wrap: wrap; gap: .35rem; margin-top: .15rem; }
.cs__accion {
  background: var(--c-slate-50); border: 1px solid var(--c-slate-200); border-radius: var(--r-md);
  padding: .4rem .65rem; font-size: var(--fs-13); font-weight: 600; color: var(--c-slate-700); cursor: pointer; display: inline-flex; gap: .3rem; align-items: center;
}
.cs__accion:hover { background: var(--c-slate-100); }
@media (max-width: 480px) { .cs__lista { grid-template-columns: 1fr; } .cs__accion { flex: 1; justify-content: center; } }
</style>
