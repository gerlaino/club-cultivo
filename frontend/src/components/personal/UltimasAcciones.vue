<template>
  <section class="ua" data-testid="ultimas-acciones">
    <div class="ua__hd">
      <h2 class="ua__titulo">Últimas acciones</h2>
      <button v-if="acciones.length >= limite && !todas" type="button" class="ua__mas" @click="verMas">Ver más</button>
    </div>
    <p v-if="cargando && !acciones.length" class="ua__vacio">Cargando…</p>
    <p v-else-if="!acciones.length" class="ua__vacio">Todavía no registraste nada. Lo que hagas (riegos, fotos, trasplantes) va a aparecer acá.</p>
    <ul v-else class="ua__lista">
      <li v-for="(a, i) in acciones" :key="i">
        <RouterLink :to="ruta(a.ruta)" class="ua__item">
          <span class="ua__punto" :class="`ua__punto--${a.tipo}`" aria-hidden="true"></span>
          <span class="ua__cuerpo">
            <span class="ua__linea">
              <strong class="ua__que">{{ a.titulo }}</strong>
              <span v-if="a.donde" class="ua__donde">· {{ a.donde }}</span>
            </span>
            <span v-if="a.detalle" class="ua__detalle">{{ a.detalle }}</span>
          </span>
          <span class="ua__cuando">{{ cuando(a.fecha) }}</span>
        </RouterLink>
      </li>
    </ul>
  </section>
</template>

<script setup>
// «Últimas acciones» del inicio del autocultivo (12-oct-2026): lo último que se hizo, para ver de
// un vistazo si algo ya se cargó y entrar a la ficha. La lista la arma el backend
// (`Autocultivo::UltimasAcciones`): acá sólo se dibuja.
import { ref, onMounted } from 'vue'
import { getUltimasAcciones } from '../../lib/api.js'
import { rutaMovil } from '../../lib/rutaMovil.js'
import { useRecargaEnCambios } from '../../composables/useRecargaEnCambios.js'

// `movil`: en el teléfono las fichas viven bajo /m (el guard de la PWA rebota lo que no).
const props = defineProps({ movil: { type: Boolean, default: false } })

const acciones = ref([])
const cargando = ref(true)
const limite   = ref(6)
const todas    = ref(false)

async function cargar() {
  try { acciones.value = (await getUltimasAcciones(limite.value)).data?.acciones || [] }
  catch { /* el inicio se ve igual sin esto */ }
  finally { cargando.value = false }
}
function verMas() { limite.value = 20; todas.value = true; cargar() }
onMounted(cargar)
useRecargaEnCambios(['lotes', 'plantas', 'fotos', 'tareas'], cargar)

function ruta(r) {
  if (!r) return '/'
  return props.movil ? rutaMovil(r) : r
}

// «hace 5 min», «hoy 10:32», «ayer 18:05», «lun 6/10».
function cuando(iso) {
  const d = new Date(iso)
  const ahora = new Date()
  const min = Math.round((ahora - d) / 60000)
  const hhmm = d.toLocaleTimeString('es-AR', { hour: '2-digit', minute: '2-digit' })
  if (min < 1) return 'recién'
  if (min < 60) return `hace ${min} min`
  const ayer = new Date(ahora); ayer.setDate(ahora.getDate() - 1)
  if (d.toDateString() === ahora.toDateString()) return `hoy ${hhmm}`
  if (d.toDateString() === ayer.toDateString()) return `ayer ${hhmm}`
  return d.toLocaleDateString('es-AR', { weekday: 'short', day: 'numeric', month: 'numeric' })
}
</script>

<style scoped>
.ua { background: #fff; border: 1px solid var(--c-slate-200); border-radius: 14px; padding: 14px 16px; }
.ua__hd { display: flex; align-items: center; justify-content: space-between; margin-bottom: 6px; }
.ua__titulo { margin: 0; font-size: 1rem; font-weight: 700; color: var(--c-ink-900); }
.ua__mas { background: none; border: 0; padding: 0; font-size: .84rem; font-weight: 600; color: var(--c-leaf-700); cursor: pointer; }
.ua__vacio { margin: 6px 0 2px; font-size: .86rem; color: var(--c-ink-500); }
.ua__lista { list-style: none; margin: 0; padding: 0; }
.ua__lista li + li { border-top: 1px solid var(--c-slate-100); }
.ua__item { display: grid; grid-template-columns: 10px minmax(0, 1fr) auto; gap: 10px; align-items: start; padding: 9px 0; text-decoration: none; color: inherit; }
.ua__punto { width: 9px; height: 9px; border-radius: 50%; margin-top: 6px; background: var(--c-leaf-500); }
.ua__punto--planta { background: var(--c-sky-600); }
.ua__punto--evento { background: var(--c-amber-500); }
.ua__punto--tarea { background: var(--c-ink-300); }
.ua__cuerpo { display: flex; flex-direction: column; gap: 2px; min-width: 0; }
.ua__linea { font-size: .9rem; color: var(--c-ink-900); }
.ua__que { font-weight: 600; }
.ua__donde { color: var(--c-ink-500); margin-left: .3em; }
.ua__detalle { font-size: .8rem; color: var(--c-ink-700); overflow-wrap: anywhere; }
.ua__cuando { font-size: .76rem; color: var(--c-ink-500); white-space: nowrap; margin-top: 2px; }
</style>
