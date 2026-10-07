<script setup>
// EL PLAN, VISTO POR SEMANA (7-oct-2026, rediseño de tareas aprobado por Germán).
//
// Una fila por tipo de tarea y una columna por semana del ciclo; cada casilla dice qué toca esa
// semana. Es la misma grilla en la biblioteca de planes y en el modal de armar un plan, así lo que
// se arma es lo que después se ve. Las semanas salen de `dia_relativo` (día 0 = el día que arranca).
import { computed } from 'vue'

const props = defineProps({
  tareas:  { type: Array, default: () => [] },
  // Al tocar una casilla con tareas: { tipo, semana, tareas }.
  clickable: { type: Boolean, default: false },
})
const emit = defineEmits(['elegir'])

const TIPO_LABEL = {
  riego: 'Riego', nutricion: 'Nutrición', poda: 'Poda', defoliacion: 'Defoliación', scrog_lst: 'SCROG/LST',
  revision_plagas: 'Plagas', inspeccion: 'Inspección', medicion: 'Medición', ajuste_luz: 'Luz',
  limpieza: 'Limpieza', trasplante: 'Trasplante', cosecha: 'Cosecha', otro: 'Otro',
}
// El color va por FAMILIA: agua y comida, manos sobre la planta, sanidad, registro.
const FAMILIA = {
  riego: 'agua', nutricion: 'agua',
  poda: 'manos', defoliacion: 'manos', scrog_lst: 'manos', trasplante: 'manos', cosecha: 'manos',
  revision_plagas: 'sanidad', inspeccion: 'sanidad', limpieza: 'sanidad',
  medicion: 'registro', ajuste_luz: 'registro', otro: 'registro',
}
const ORDEN = Object.keys(TIPO_LABEL)

const vivas = computed(() => props.tareas.filter(t => !t._deleted))
const semanas = computed(() => {
  const max = Math.max(0, ...vivas.value.map(t => Number(t.dia_relativo) || 0))
  return Math.max(1, Math.floor(max / 7) + 1)
})
const filas = computed(() => {
  const tipos = [...new Set(vivas.value.map(t => t.tipo || 'otro'))]
    .sort((a, b) => ORDEN.indexOf(a) - ORDEN.indexOf(b))
  return tipos.map(tipo => ({
    tipo,
    label: TIPO_LABEL[tipo] || tipo,
    familia: FAMILIA[tipo] || 'registro',
    celdas: Array.from({ length: semanas.value }, (_, s) => {
      const ts = vivas.value.filter(t => (t.tipo || 'otro') === tipo && Math.floor((Number(t.dia_relativo) || 0) / 7) === s)
      return {
        semana: s + 1,
        tareas: ts,
        texto: !ts.length ? '' : ts.length === 1 ? (ts[0].titulo || TIPO_LABEL[tipo]) : `${ts.length} veces`,
      }
    }),
  }))
})
</script>

<template>
  <div class="pcal">
    <p v-if="!filas.length" class="pcal__vacio">Todavía no hay tareas: el calendario se arma solo a medida que las agregás.</p>
    <div v-else class="pcal__scroll">
      <table class="pcal__tabla" aria-label="Calendario del plan por semana">
        <thead>
          <tr>
            <th scope="col"><span class="pcal__sr">Tipo</span></th>
            <th v-for="n in semanas" :key="n" scope="col">Sem {{ n }}</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="f in filas" :key="f.tipo">
            <th scope="row"><span class="pcal__punto" :class="`pcal--${f.familia}`"></span>{{ f.label }}</th>
            <td v-for="c in f.celdas" :key="c.semana">
              <button v-if="c.tareas.length && clickable" type="button" class="pcal__celda pcal__celda--llena" :class="`pcal--${f.familia}`"
                      :title="c.tareas.map(t => t.titulo || f.label).join(' · ')"
                      @click="emit('elegir', { tipo: f.tipo, semana: c.semana, tareas: c.tareas })">{{ c.texto }}</button>
              <span v-else-if="c.tareas.length" class="pcal__celda pcal__celda--llena" :class="`pcal--${f.familia}`"
                    :title="c.tareas.map(t => t.titulo || f.label).join(' · ')">{{ c.texto }}</span>
              <span v-else class="pcal__celda"></span>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>

<style scoped>
.pcal__vacio { font-size: .85rem; color: var(--c-slate-500); margin: 0; padding: .5rem 0; }
.pcal__scroll { overflow-x: auto; }
.pcal__tabla { border-collapse: separate; border-spacing: 4px; min-width: 100%; }
.pcal__tabla thead th { font-size: .68rem; font-weight: 700; color: var(--c-slate-500); text-align: center; padding: 2px 0; white-space: nowrap; }
.pcal__tabla tbody th { text-align: left; font-size: .78rem; font-weight: 700; color: var(--c-slate-700); white-space: nowrap; padding-right: .5rem; }
.pcal__tabla td { min-width: 72px; }
.pcal__punto { display: inline-block; width: 9px; height: 9px; border-radius: 9px; margin-right: .4rem; vertical-align: middle; }
.pcal__celda { display: flex; align-items: center; justify-content: center; min-height: 36px; border-radius: 8px; background: var(--c-slate-50); font-size: .72rem; font-weight: 600; color: var(--c-slate-900); text-align: center; padding: 3px 4px; width: 100%; box-sizing: border-box; border: 0; line-height: 1.2; }
button.pcal__celda { cursor: pointer; }
button.pcal__celda:hover { outline: 2px solid var(--c-leaf-500); }
.pcal__punto.pcal--agua { background: var(--c-leaf-600); }
.pcal__punto.pcal--manos { background: var(--c-gold-500); }
.pcal__punto.pcal--sanidad { background: var(--c-sky-600); }
.pcal__punto.pcal--registro { background: var(--c-slate-500); }
.pcal__celda--llena.pcal--agua { background: var(--c-leaf-100); }
.pcal__celda--llena.pcal--manos { background: var(--c-amber-100); }
.pcal__celda--llena.pcal--sanidad { background: var(--c-sky-100); }
.pcal__celda--llena.pcal--registro { background: var(--c-slate-100); }
.pcal__sr { position: absolute; width: 1px; height: 1px; overflow: hidden; clip: rect(0 0 0 0); }
</style>
