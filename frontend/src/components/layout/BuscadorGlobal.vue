<template>
  <!-- Una sola raíz (el botón) para que la clase de la barra que lo usa le llegue con su estilo
       scoped. El panel se teletransporta al body: sus clicks no burbujean al botón. -->
  <button type="button" aria-label="Buscar" :title="`Buscar (${atajo})`" @click="abrir">
    <Search :size="20" :stroke-width="1.75" />
  <Teleport to="body">
    <div v-modal="{ cerrar, descartable: true }" v-if="abierto" class="bg__ov" @click.self="cerrar">
      <div class="bg__panel" role="dialog" aria-label="Buscar" data-testid="buscador-global">
        <div class="bg__campo">
          <Search :size="18" :stroke-width="1.75" class="bg__lupa" />
          <input ref="input" v-model="q" class="bg__input" :placeholder="placeholder"
                 autocomplete="off" spellcheck="false"
                 @keydown.down.prevent="mover(1)" @keydown.up.prevent="mover(-1)"
                 @keydown.enter.prevent="irA(planos[activo])" />
          <kbd class="bg__kbd">Esc</kbd>
        </div>

        <div class="bg__cuerpo">
          <p v-if="q.trim().length < 2" class="bg__vacio">{{ ayuda }}</p>
          <p v-else-if="cargando && !planos.length" class="bg__vacio">Buscando…</p>
          <p v-else-if="error" class="bg__vacio">No se pudo buscar. Probá de nuevo.</p>
          <p v-else-if="!planos.length" class="bg__vacio">Nada con «{{ q.trim() }}».</p>
          <template v-for="s in secciones" :key="s.clave">
            <div class="bg__seccion">{{ s.titulo }}</div>
            <button v-for="r in s.items" :key="`${s.clave}-${r.id}`" type="button" class="bg__item"
                    :class="{ 'is-on': planos[activo] === r }"
                    @mouseenter="activo = planos.indexOf(r)" @click="irA(r)">
              <span class="bg__item-tit">{{ r.titulo }}</span>
              <span v-if="r.detalle" class="bg__item-det">{{ r.detalle }}</span>
            </button>
          </template>
        </div>
      </div>
    </div>
  </Teleport>
  </button>
</template>

<script setup>
// Buscador general de la barra de arriba (12-oct-2026): reemplaza a la lista de todas las plantas.
// Se abre con la lupa o con Ctrl+K / ⌘K. Lo que trae lo decide el backend según el rol (`/buscar`):
// acá sólo se dibujan las secciones que llegan, en este orden.
import { ref, computed, watch, nextTick, onMounted, onUnmounted } from 'vue'
import { useRouter } from 'vue-router'
import { Search } from 'lucide-vue-next'
import { buscarGeneral } from '../../lib/api.js'
import { useClubStore } from '../../stores/club.js'

const router = useRouter()
const club = useClubStore()
const abierto = ref(false)
const q = ref('')
const input = ref(null)
const resultados = ref({})
const cargando = ref(false)
const error = ref(false)
const activo = ref(0)

const esMac = typeof navigator !== 'undefined' && /Mac|iPhone|iPad/.test(navigator.platform || '')
const atajo = esMac ? '⌘K' : 'Ctrl+K'
const personal = computed(() => !!club.data?.personal)
const placeholder = computed(() => (personal.value ? 'Buscar una planta, un espacio o una genética…' : 'Buscar planta, lote, sala, genética o paciente…'))
const ayuda = computed(() => (personal.value
  ? 'Escribí el nombre de una planta, un espacio o una genética.'
  : 'Escribí el nombre o el código: una planta, un lote, una sala, una genética o un paciente.'))

const ORDEN = computed(() => [
  ['plantas', 'Plantas'], ['lotes', 'Lotes'], ['salas', personal.value ? 'Espacios' : 'Salas'],
  ['geneticas', 'Genéticas'], ['pacientes', 'Pacientes'],
])
const secciones = computed(() => ORDEN.value
  .map(([clave, titulo]) => ({ clave, titulo, items: resultados.value[clave] || [] }))
  .filter(s => s.items.length))
const planos = computed(() => secciones.value.flatMap(s => s.items))

let timer = null
let pedido = 0
watch(q, (v) => {
  clearTimeout(timer)
  activo.value = 0
  if (v.trim().length < 2) { resultados.value = {}; cargando.value = false; return }
  cargando.value = true
  timer = setTimeout(async () => {
    const mio = ++pedido
    try {
      const { data } = await buscarGeneral(v.trim())
      if (mio !== pedido) return // llegó tarde: ya se tipeó otra cosa
      resultados.value = data.resultados || {}
      error.value = false
    } catch { if (mio === pedido) error.value = true }
    finally { if (mio === pedido) cargando.value = false }
  }, 220)
})

function mover(d) {
  const n = planos.value.length
  if (n) activo.value = (activo.value + d + n) % n
}
async function abrir() {
  abierto.value = true
  await nextTick()
  input.value?.focus()
}
function cerrar() {
  abierto.value = false
  q.value = ''
  resultados.value = {}
}
function irA(r) {
  if (!r) return
  cerrar()
  router.push(r.ruta)
}
function onKey(e) {
  if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'k') {
    e.preventDefault()
    abierto.value ? cerrar() : abrir()
  }
}
onMounted(() => window.addEventListener('keydown', onKey))
onUnmounted(() => { window.removeEventListener('keydown', onKey); clearTimeout(timer) })
</script>

<style scoped>
.bg__ov {
  position: fixed; inset: 0; z-index: 1500; background: rgb(15 23 42 / .35);
  display: flex; justify-content: center; align-items: flex-start; padding: 12vh 16px 16px;
}
.bg__panel {
  width: 100%; max-width: 560px; background: #fff; border-radius: 14px;
  box-shadow: 0 20px 50px rgb(15 23 42 / .25); overflow: hidden; display: flex; flex-direction: column;
  max-height: 70vh;
}
.bg__campo { display: flex; align-items: center; gap: .6rem; padding: .8rem 1rem; border-bottom: 1px solid var(--c-ink-300); }
.bg__lupa { color: var(--c-ink-500); flex-shrink: 0; }
.bg__input { flex: 1; border: 0; outline: 0; font-size: 1rem; color: var(--c-ink-900); background: transparent; min-width: 0; }
.bg__kbd { font-size: .7rem; color: var(--c-ink-500); border: 1px solid var(--c-ink-300); border-radius: var(--r-md); padding: .1rem .35rem; }
.bg__cuerpo { overflow-y: auto; padding: .4rem 0 .6rem; }
.bg__vacio { margin: 0; padding: 1rem 1.1rem; color: var(--c-ink-500); font-size: .88rem; }
.bg__seccion { padding: .6rem 1.1rem .25rem; font-size: .7rem; font-weight: 700; letter-spacing: .06em; text-transform: uppercase; color: var(--c-ink-500); }
.bg__item {
  display: flex; flex-direction: column; align-items: flex-start; gap: .1rem; width: 100%;
  border: 0; background: transparent; text-align: left; padding: .5rem 1.1rem; cursor: pointer;
}
.bg__item.is-on { background: var(--c-leaf-50); box-shadow: inset 3px 0 0 var(--c-leaf-600); }
.bg__item-tit { font-size: .92rem; color: var(--c-ink-900); font-weight: 600; }
.bg__item-det { font-size: .78rem; color: var(--c-ink-500); }
@media (max-width: 600px) { .bg__ov { padding-top: 8vh; } .bg__kbd { display: none; } }
</style>
