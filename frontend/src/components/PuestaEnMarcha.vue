<script setup>
// La lista de qué falta para que la organización esté operando. La calcula el backend
// (`Clubs::PuestaEnMarcha`) mirando los datos —es la misma que ve el super admin en la ficha—
// y acá sólo se muestra, hasta que esté completa. Se puede plegar por viewer (localStorage):
// el admin que ya sabe qué le falta no necesita la tarjeta abierta cada mañana.
import { ref, onMounted, inject } from 'vue'
import { getPuestaEnMarcha } from '../lib/api.js'
import { useRecargaEnCambios } from '../composables/useRecargaEnCambios.js'

const datos    = ref(null)
// Lo que el shell del teléfono sabe abrir (ver `MobileShell`); en escritorio no hay nada.
const acciones = inject('accionesMobile', null)
function accionDe(p) {
  if (!acciones) return null
  if (p.clave === 'salas') return acciones.abrirNuevaSala
  if (p.clave === 'lotes') return acciones.abrirNuevoLote
  return null
}
const plegada  = ref(false)
const CLAVE    = 'puesta_en_marcha_plegada'

// Se actualiza sola cuando aparece el espacio, el lote o la variedad (sin recargar).
useRecargaEnCambios(['salas', 'lotes', 'recetas', 'stocks'], cargar)

onMounted(cargar)
async function cargar() {
  try {
    const { data } = await getPuestaEnMarcha()
    datos.value = data
  } catch { /* sin permiso o sin red: la tarjeta simplemente no aparece */ }
  try { plegada.value = localStorage.getItem(CLAVE) === '1' } catch { /* sin storage: arranca abierta */ }
}

function plegar() {
  plegada.value = !plegada.value
  try { localStorage.setItem(CLAVE, plegada.value ? '1' : '0') } catch { /* sin storage: no se recuerda */ }
}
</script>

<template>
  <section v-if="datos && !datos.completa" class="pem">
    <button type="button" class="pem__hd" @click="plegar" :aria-expanded="!plegada">
      <span class="pem__title">Puesta en marcha</span>
      <span class="pem__prog">{{ datos.hechos }} de {{ datos.total }}</span>
      <span class="pem__bar"><span class="pem__bar-fill" :style="{ width: `${(datos.hechos / datos.total) * 100}%` }"></span></span>
      <span class="pem__chev">{{ plegada ? '▸' : '▾' }}</span>
    </button>
    <ul v-if="!plegada" class="pem__list">
      <li v-for="p in datos.pasos" :key="p.clave" class="pem__item" :class="{ 'pem__item--hecho': p.hecho }">
        <span class="pem__check" aria-hidden="true">{{ p.hecho ? '✓' : '' }}</span>
        <div class="pem__txt">
          <!-- En el teléfono, «crear un espacio» y «abrir el primer lote» abren el modal: la
               pantalla de escritorio a la que apunta `ruta` no vive bajo /m. -->
          <button v-if="!p.hecho && accionDe(p)" type="button" class="pem__label pem__label--btn" @click="accionDe(p)()">{{ p.label }} →</button>
          <RouterLink v-else-if="!p.hecho" :to="p.ruta" class="pem__label">{{ p.label }} →</RouterLink>
          <span v-else class="pem__label">{{ p.label }}</span>
          <span v-if="!p.hecho" class="pem__detalle">{{ p.detalle }}</span>
        </div>
      </li>
    </ul>
  </section>
</template>

<style scoped>
.pem { background: #fff; border: 1px solid var(--c-leaf-100, #E8F0EB); border-left: 3px solid var(--c-leaf-500, #5A8A72); border-radius: 12px; margin-bottom: 1.25rem; overflow: hidden; }
.pem__hd { display: flex; align-items: center; gap: .75rem; width: 100%; background: none; border: none; padding: .8rem 1rem; cursor: pointer; text-align: left; font: inherit; }
.pem__title { font-size: .82rem; font-weight: 800; color: var(--c-slate-900); }
.pem__prog { font-size: .74rem; color: var(--c-slate-500); white-space: nowrap; }
.pem__bar { flex: 1; height: 6px; background: var(--c-slate-100); border-radius: 3px; overflow: hidden; }
.pem__bar-fill { display: block; height: 100%; background: var(--c-leaf-500, #5A8A72); transition: width .3s; }
.pem__chev { color: var(--c-slate-400); font-size: .8rem; }
.pem__list { list-style: none; margin: 0; padding: 0 1rem .8rem; display: grid; gap: .45rem; }
.pem__item { display: flex; gap: .6rem; align-items: flex-start; }
.pem__check { width: 18px; height: 18px; border-radius: 50%; border: 1.5px solid var(--c-slate-300); display: grid; place-items: center; font-size: .7rem; font-weight: 800; color: #fff; flex-shrink: 0; margin-top: .1rem; }
.pem__item--hecho .pem__check { background: var(--c-leaf-500, #5A8A72); border-color: var(--c-leaf-500, #5A8A72); }
.pem__txt { display: flex; flex-direction: column; gap: .1rem; }
.pem__label { font-size: .82rem; font-weight: 700; color: var(--c-slate-800); text-decoration: none; }
a.pem__label:hover { color: var(--c-leaf-800, #1A3D2E); text-decoration: underline; }
.pem__item--hecho .pem__label { color: var(--c-slate-400); font-weight: 600; text-decoration: line-through; }
.pem__detalle { font-size: .74rem; color: var(--c-slate-500); }
.pem__label--btn { background: none; border: 0; padding: 0; font: inherit; color: inherit; text-align: left; cursor: pointer; }
</style>
