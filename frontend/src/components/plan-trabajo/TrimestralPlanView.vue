<template>
  <div class="tpv">
    <div class="tpv__meses">
      <div v-for="mes in meses" :key="mes.label" class="tpv__mes">
        <div class="tpv__mes-hdr">
          <span class="tpv__mes-label">{{ mes.label }}</span>
          <span class="tpv__mes-count">{{ mes.totalTareas }} tareas</span>
        </div>
        <div class="tpv__semanas">
          <div v-for="sem in mes.semanas" :key="sem.label" class="tpv__semana">
            <div class="tpv__sem-hdr">
              <span class="tpv__sem-label">{{ sem.label }}</span>
              <span class="tpv__sem-count" v-if="sem.tareas.length">{{ sem.tareas.length }}</span>
            </div>
            <div v-if="sem.tareas.length" class="tpv__sem-tareas">
              <div v-for="t in sem.tareas.slice(0, 4)" :key="t.id" class="tpv__tarea" @click="$emit('edit-tarea', t)">
                <span class="tpv__tarea-ico">{{ tipoEmoji(t.tipo) }}</span>
                <span class="tpv__tarea-txt">{{ t.titulo_display || t.tipo }}</span>
                <span v-if="t.responsable" class="tpv__tarea-resp">{{ initials(t.responsable.nombre_completo || t.responsable.nombre) }}</span>
              </div>
              <div v-if="sem.tareas.length > 4" class="tpv__tarea tpv__tarea--mas">+{{ sem.tareas.length - 4 }} más</div>
            </div>
            <div v-else class="tpv__sem-vacia">–</div>
          </div>
        </div>
      </div>
    </div>

    <div v-if="sinTareas" class="tpv__empty">
      <p>No hay tareas en el plan.</p>
      <button class="tpv__btn-add" @click="$emit('add-tarea', {})">+ Agregar tarea</button>
    </div>
  </div>
</template>

<script setup>
import { computed } from 'vue'

const props = defineProps({
  plan:       { type: Object, required: true },
  planTareas: { type: Array, default: () => [] },
})
const emit = defineEmits(['add-tarea', 'edit-tarea'])

const MESES_LABEL = ['Enero','Febrero','Marzo','Abril','Mayo','Junio','Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre']
const DIAS_MAP = { lun: 1, mar: 2, mie: 3, jue: 4, vie: 5, sab: 6, dom: 0 }
const TIPO_EMOJI = { riego: '💧', poda: '✂️', medicion: '📏', limpieza: '🧹', cosecha: '🌿', trasplante: '🪴', inspeccion: '🔍', otro: '📋' }

function parseDate(iso) {
  const [y, m, d] = iso.split('-').map(Number)
  return new Date(y, m - 1, d)
}
function isoDate(d) { return d.toISOString().slice(0, 10) }
function addDays(d, n) { const r = new Date(d); r.setDate(r.getDate() + n); return r }

function tareasEnRango(desde, hasta) {
  return props.planTareas.filter(t => {
    if (t.es_recurrente) {
      // Has at least one day in range
      const diasArr = t.dias_semana ? t.dias_semana.split(',').map(s => s.trim()) : []
      let d = parseDate(desde)
      const fin = parseDate(hasta)
      while (d <= fin) {
        if (diasArr.some(dia => DIAS_MAP[dia] === d.getDay())) return true
        d = addDays(d, 1)
      }
      return false
    }
    return t.fecha_especifica >= desde && t.fecha_especifica <= hasta
  })
}

const meses = computed(() => {
  const ini = parseDate(props.plan.fecha_inicio)
  const fin = parseDate(props.plan.fecha_fin)
  const result = []

  let cur = new Date(ini.getFullYear(), ini.getMonth(), 1)
  while (cur <= fin) {
    const mesNum = cur.getMonth()
    const anio = cur.getFullYear()
    const primerDia = new Date(anio, mesNum, 1)
    const ultimoDia = new Date(anio, mesNum + 1, 0)

    const desdeEfectivo = primerDia < ini ? ini : primerDia
    const hastaEfectivo = ultimoDia > fin ? fin : ultimoDia

    // Build weeks (Mon–Sun)
    const semanas = []
    let semIni = new Date(desdeEfectivo)
    // Align to Monday
    const wd = semIni.getDay()
    if (wd !== 1) semIni.setDate(semIni.getDate() - (wd === 0 ? 6 : wd - 1))

    while (semIni <= hastaEfectivo) {
      const semFin = addDays(semIni, 5) // Sat
      const desdeStr = isoDate(semIni > desdeEfectivo ? semIni : desdeEfectivo)
      const hastaStr = isoDate(semFin < hastaEfectivo ? semFin : hastaEfectivo)
      semanas.push({
        label: `${parseDate(desdeStr).getDate()}–${parseDate(hastaStr).getDate()}`,
        tareas: tareasEnRango(desdeStr, hastaStr),
      })
      semIni = addDays(semIni, 7)
    }

    const tareas = tareasEnRango(isoDate(desdeEfectivo), isoDate(hastaEfectivo))
    result.push({
      label: `${MESES_LABEL[mesNum]} ${anio}`,
      totalTareas: tareas.length,
      semanas,
    })

    cur = new Date(anio, mesNum + 1, 1)
  }
  return result
})

const sinTareas = computed(() => props.planTareas.length === 0)
function tipoEmoji(tipo) { return TIPO_EMOJI[tipo] || '📋' }
function initials(name) {
  if (!name) return '?'
  return name.split(' ').map(w => w[0]).slice(0, 2).join('').toUpperCase()
}
</script>

<style scoped>
.tpv { display: flex; flex-direction: column; gap: 1.25rem; }
.tpv__meses { display: grid; grid-template-columns: repeat(auto-fill, minmax(280px, 1fr)); gap: 1rem; }

.tpv__mes { background: #fff; border: 1px solid #e8f0e9; border-radius: 12px; overflow: hidden; }
.tpv__mes-hdr { display: flex; align-items: center; justify-content: space-between; padding: .75rem 1rem; background: #f6faf6; border-bottom: 1px solid #e8f0e9; }
.tpv__mes-label { font-size: .875rem; font-weight: 700; color: #0f2611; }
.tpv__mes-count { font-size: .72rem; background: #e8f0e9; color: #60725d; padding: .15em .5em; border-radius: 4px; font-weight: 600; }

.tpv__semanas { display: flex; flex-direction: column; }
.tpv__semana { border-bottom: 1px solid #f1f5f9; padding: .5rem .875rem; }
.tpv__semana:last-child { border-bottom: none; }
.tpv__sem-hdr { display: flex; align-items: center; gap: .5rem; margin-bottom: .25rem; }
.tpv__sem-label { font-size: .72rem; font-weight: 600; color: #60725d; min-width: 36px; }
.tpv__sem-count { font-size: .65rem; background: #1b5e20; color: #fff; padding: .1em .45em; border-radius: 3px; font-weight: 700; }

.tpv__sem-tareas { display: flex; flex-direction: column; gap: 2px; }
.tpv__tarea { display: flex; align-items: center; gap: .3rem; padding: .2rem .3rem; border-radius: 5px; cursor: pointer; font-size: .73rem; }
.tpv__tarea:hover { background: #f0fdf4; }
.tpv__tarea-ico  { flex-shrink: 0; }
.tpv__tarea-txt  { flex: 1; color: #0f2611; font-weight: 500; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.tpv__tarea-resp { background: #e8f0e9; color: #374151; padding: .1em .35em; border-radius: 3px; font-size: .65rem; font-weight: 700; flex-shrink: 0; }
.tpv__tarea--mas { color: #64748b; cursor: default; font-size: .7rem; }
.tpv__sem-vacia  { font-size: .72rem; color: #94a3b8; padding: .1rem 0; }

.tpv__empty { text-align: center; padding: 3rem 1rem; color: #60725d; font-size: .875rem; }
.tpv__btn-add { margin-top: .5rem; background: #1b5e20; color: #fff; border: none; padding: .6rem 1.25rem; border-radius: 9px; font-size: .875rem; font-weight: 600; cursor: pointer; }
</style>
