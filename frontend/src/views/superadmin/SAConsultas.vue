<script setup>
// LA BANDEJA DE CONSULTAS: lo que dejaron en el formulario de cultivoespacial.com
// (`SolicitudContacto`). Cada una ya llegó por push y por mail; acá queda guardada aunque el aviso
// haya fallado. Pendientes arriba; «Atendida» la baja de la cola y se puede deshacer.
//
// Los pedidos de arrepentimiento/baja (Res. SCI 424/2020) van marcados: la ley pide procesarlos
// sin costo, y a quien escribió ya se le dio su código de trámite.
import { ref, computed, onMounted } from 'vue'
import DsSpinner from '../../design-system/components/Spinner.vue'
import { listConsultas, marcarConsulta } from '../../lib/api.js'
import { useToast } from '../../composables/useToast.js'
import { Inbox, Mail, Phone, Building2, CheckCircle2, RotateCcw } from 'lucide-vue-next'

const toast = useToast()
const datos = ref(null)
const cargando = ref(true)
const error = ref(null)
const guardando = ref(null)

const consultas = computed(() => datos.value?.consultas || [])

async function cargar () {
  try {
    datos.value = (await listConsultas()).data
    error.value = null
  } catch {
    error.value = 'No se pudieron cargar las consultas.'
  } finally {
    cargando.value = false
  }
}

async function marcar (c, atendida) {
  guardando.value = c.id
  try {
    const { data } = await marcarConsulta(c.id, atendida)
    Object.assign(c, data)
    datos.value.pendientes += atendida ? -1 : 1
    toast.success(atendida ? 'Marcada como atendida.' : 'Volvió a pendientes.')
  } catch {
    toast.error('No se pudo guardar.')
  } finally {
    guardando.value = null
  }
}

const cuando = (iso) => new Date(iso).toLocaleString('es-AR', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' })

onMounted(cargar)
</script>

<template>
  <div class="cq">
    <header class="cq__head">
      <h1 class="cq__title"><Inbox :size="22" /> Consultas</h1>
      <p class="cq__sub">
        Lo que dejaron en el formulario de la página.
        <template v-if="datos">{{ datos.pendientes }} {{ datos.pendientes === 1 ? 'pendiente' : 'pendientes' }}.</template>
      </p>
    </header>

    <div v-if="cargando" class="cq__vacio"><DsSpinner :size="20" /> Cargando…</div>
    <div v-else-if="error" class="cq__vacio cq__vacio--error">{{ error }}</div>
    <div v-else-if="!consultas.length" class="cq__vacio">Todavía no llegó ninguna consulta.</div>

    <ul v-else class="cq__lista">
      <li v-for="c in consultas" :key="c.id" class="cq__item" :class="{ 'cq__item--hecha': c.atendida_at, 'cq__item--baja': c.tipo === 'baja' }">
        <div class="cq__top">
          <span class="cq__tipo" :class="`cq__tipo--${c.tipo}`">{{ c.tipo_label }}</span>
          <strong class="cq__nombre">{{ c.nombre }}</strong>
          <span class="cq__cuando">{{ cuando(c.created_at) }} · {{ c.codigo }}</span>
        </div>
        <div class="cq__datos">
          <a :href="`mailto:${c.email}?subject=${encodeURIComponent('Cultivo Espacial — ' + c.codigo)}`"><Mail :size="14" /> {{ c.email }}</a>
          <a v-if="c.telefono" :href="`tel:${c.telefono}`"><Phone :size="14" /> {{ c.telefono }}</a>
          <span v-if="c.organizacion"><Building2 :size="14" /> {{ c.organizacion }}</span>
        </div>
        <p v-if="c.mensaje" class="cq__msg">{{ c.mensaje }}</p>
        <p v-if="c.tipo === 'baja' && !c.atendida_at" class="cq__nota">
          Arrepentimiento o baja: se procesa sin costo y sin pedir explicaciones.
        </p>
        <div class="cq__acc">
          <span v-if="c.atendida_at" class="cq__hecha"><CheckCircle2 :size="14" /> Atendida {{ cuando(c.atendida_at) }}<template v-if="c.atendida_por"> por {{ c.atendida_por }}</template></span>
          <button v-if="!c.atendida_at" class="cq__btn" :disabled="guardando === c.id" @click="marcar(c, true)">
            <CheckCircle2 :size="15" /> Marcar atendida
          </button>
          <button v-else class="cq__btn cq__btn--sec" :disabled="guardando === c.id" @click="marcar(c, false)">
            <RotateCcw :size="14" /> Volver a pendiente
          </button>
        </div>
      </li>
    </ul>
  </div>
</template>

<style scoped>
.cq { padding: var(--sp-6) var(--sp-4); }
.cq__head { margin-bottom: var(--sp-5); }
.cq__title { display: flex; align-items: center; gap: var(--sp-2); font-size: var(--fs-20); font-weight: 700; color: var(--c-ink-900); margin: 0; }
.cq__sub { margin: var(--sp-1) 0 0; font-size: var(--fs-14); color: var(--c-slate-500); }
.cq__vacio { display: flex; align-items: center; gap: var(--sp-2); justify-content: center; padding: var(--sp-8); color: var(--c-slate-500); }
.cq__vacio--error { color: var(--c-rust-600); }
.cq__lista { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: var(--sp-3); }
.cq__item { background: #fff; border: 1px solid var(--c-slate-200); border-radius: var(--r-lg); padding: var(--sp-4); display: flex; flex-direction: column; gap: var(--sp-2); }
.cq__item--baja { border-left: 4px solid var(--c-rust-600); }
.cq__item--hecha { opacity: .65; }
.cq__top { display: flex; flex-wrap: wrap; align-items: center; gap: var(--sp-2); }
.cq__tipo { font-size: var(--fs-12); font-weight: 700; border-radius: var(--r-pill); padding: 2px 10px; background: var(--c-leaf-100); color: var(--c-leaf-700); }
.cq__tipo--personal { background: var(--c-sky-100); color: var(--c-sky-600); }
.cq__tipo--baja { background: var(--c-rust-100); color: var(--c-rust-600); }
.cq__nombre { font-size: var(--fs-16); color: var(--c-ink-900); }
.cq__cuando { margin-left: auto; font-size: var(--fs-12); color: var(--c-slate-500); }
.cq__datos { display: flex; flex-wrap: wrap; gap: var(--sp-2) var(--sp-4); font-size: var(--fs-14); color: var(--c-slate-600); }
.cq__datos a, .cq__datos span { display: inline-flex; align-items: center; gap: .3rem; color: inherit; text-decoration: none; }
.cq__datos a:hover { color: var(--c-leaf-700); text-decoration: underline; }
.cq__msg { margin: 0; white-space: pre-line; font-size: var(--fs-14); color: var(--c-ink-900); background: var(--c-slate-50); border-radius: var(--r-md); padding: var(--sp-3); }
.cq__nota { margin: 0; font-size: var(--fs-13, 13px); color: var(--c-rust-600); font-weight: 600; }
.cq__acc { display: flex; align-items: center; gap: var(--sp-3); justify-content: flex-end; flex-wrap: wrap; }
.cq__hecha { display: inline-flex; align-items: center; gap: .3rem; font-size: var(--fs-13, 13px); color: var(--c-leaf-700); margin-right: auto; }
.cq__btn { display: inline-flex; align-items: center; gap: .35rem; min-height: 38px; background: var(--c-leaf-700); color: #fff; border: none; border-radius: var(--r-md); padding: 6px 14px; font-size: var(--fs-14); font-weight: 600; cursor: pointer; }
.cq__btn--sec { background: #fff; color: var(--c-leaf-700); border: 1.5px solid var(--c-ink-300); }
.cq__btn:disabled { opacity: .55; cursor: default; }
</style>
