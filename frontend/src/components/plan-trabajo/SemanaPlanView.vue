<template>
  <div class="spv">
    <!-- Week nav -->
    <div class="spv__nav">
      <button class="spv__nav-btn" @click="semAnterior" :disabled="!puedoRetroceder"><i class="bi bi-chevron-left"></i></button>
      <span class="spv__nav-label">{{ labelSemana }}</span>
      <button class="spv__nav-btn" @click="semSiguiente" :disabled="!puedoAvanzar"><i class="bi bi-chevron-right"></i></button>
    </div>

    <!-- Grid -->
    <div class="spv__grid-wrap">
      <div class="spv__grid" :style="`grid-template-columns: 140px repeat(${weekDays.length}, 1fr)`">

        <!-- Header row -->
        <div class="spv__grid-corner"></div>
        <div v-for="d in weekDays" :key="d.iso" class="spv__day-hdr" :class="{ 'spv__day-hdr--hoy': d.esHoy }">
          <span class="spv__day-name">{{ d.nombre }}</span>
          <span class="spv__day-num" :class="{ 'spv__day-num--hoy': d.esHoy }">{{ d.num }}</span>
          <button class="spv__add-btn" @click="$emit('add-tarea', { fecha: d.iso })" title="Agregar tarea">+</button>
        </div>

        <!-- Person rows -->
        <template v-for="persona in filas" :key="persona.id || 'sin-asignar'">
          <!-- Person header -->
          <div class="spv__person-hdr">
            <div class="spv__person-avatar" :style="avatarStyle(persona.nombre)">{{ initials(persona.nombre) }}</div>
            <span class="spv__person-name">{{ persona.nombre }}</span>
          </div>

          <!-- Cells -->
          <div v-for="d in weekDays" :key="d.iso" class="spv__cell" :class="{ 'spv__cell--hoy': d.esHoy }">
            <div
              v-for="tarea in tareasEnCelda(persona.id, d)"
              :key="tarea.id"
              class="spv__card"
              :class="`spv__card--${tarea.prioridad}`"
              @click="$emit('edit-tarea', tarea)"
            >
              <span class="spv__card-tipo">{{ tipoEmoji(tarea.tipo) }}</span>
              <span class="spv__card-titulo">{{ tarea.titulo_display || tarea.tipo }}</span>
              <span v-if="tarea.hora" class="spv__card-hora">{{ tarea.hora.slice(0,5) }}</span>
            </div>
            <button class="spv__cell-add" @click="$emit('add-tarea', { fecha: d.iso, responsable_id: persona.id })">+</button>
          </div>
        </template>
      </div>
    </div>

    <div v-if="sinTareas" class="spv__empty">
      <p>No hay tareas en esta semana.</p>
      <button class="spv__btn-add" @click="$emit('add-tarea', {})">+ Agregar tarea</button>
    </div>
  </div>
</template>

<script setup>
import { ref, computed } from 'vue'

const props = defineProps({
  plan:       { type: Object, required: true },
  planTareas: { type: Array, default: () => [] },
  usuarios:   { type: Array, default: () => [] },
})
const emit = defineEmits(['add-tarea', 'edit-tarea'])

const DIAS_LABELS = ['Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb']
const MESES = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic']
const DIAS_MAP = { lun: 1, mar: 2, mie: 3, jue: 4, vie: 5, sab: 6, dom: 0 }
const TIPO_EMOJI = { riego: '💧', poda: '✂️', medicion: '📏', limpieza: '🧹', cosecha: '🌿', transplante: '🪴', inspeccion: '🔍', otro: '📋' }

function parseDate(iso) {
  const [y, m, d] = iso.split('-').map(Number)
  return new Date(y, m - 1, d)
}
function isoDate(d) {
  return d.toISOString().slice(0, 10)
}
function isoLunes(from) {
  const d = from ? parseDate(from) : new Date()
  const day = d.getDay()
  const diff = day === 0 ? -6 : 1 - day
  d.setDate(d.getDate() + diff)
  return isoDate(d)
}

function initialSemana() {
  const hoy = isoDate(new Date())
  if (hoy >= props.plan.fecha_inicio && hoy <= props.plan.fecha_fin) return isoLunes(hoy)
  if (hoy > props.plan.fecha_fin) return isoLunes(props.plan.fecha_fin)
  return isoLunes(props.plan.fecha_inicio)
}
const semanaStart = ref(initialSemana())

const weekDays = computed(() => {
  const hoy = isoDate(new Date())
  const days = []
  const start = parseDate(semanaStart.value)
  for (let i = 0; i < 7; i++) {
    const d = new Date(start)
    d.setDate(d.getDate() + i)
    const iso = isoDate(d)
    days.push({
      iso,
      nombre: DIAS_LABELS[d.getDay()],
      num: d.getDate() + ' ' + MESES[d.getMonth()],
      esHoy: iso === hoy,
      wday: d.getDay(),
    })
  }
  return days
})

const semanaEnd = computed(() => {
  const d = parseDate(semanaStart.value)
  d.setDate(d.getDate() + 6)
  return isoDate(d)
})

const labelSemana = computed(() => {
  const d1 = parseDate(semanaStart.value)
  const d2 = parseDate(semanaEnd.value)
  return `${d1.getDate()} ${MESES[d1.getMonth()]} — ${d2.getDate()} ${MESES[d2.getMonth()]}`
})

const puedoRetroceder = computed(() => semanaStart.value > props.plan.fecha_inicio)
const puedoAvanzar    = computed(() => semanaEnd.value < props.plan.fecha_fin)

function semAnterior() {
  const d = parseDate(semanaStart.value)
  d.setDate(d.getDate() - 7)
  const clamped = isoDate(d) < props.plan.fecha_inicio ? isoLunes(props.plan.fecha_inicio) : isoDate(d)
  semanaStart.value = clamped
}
function semSiguiente() {
  const d = parseDate(semanaStart.value)
  d.setDate(d.getDate() + 7)
  semanaStart.value = isoDate(d)
}

function tareasEnCelda(personaId, dia) {
  return props.planTareas.filter(t => {
    const mismaPersona = personaId === null
      ? !t.responsable
      : t.responsable?.id === personaId
    if (!mismaPersona) return false

    if (t.es_recurrente) {
      const diasArr = t.dias_semana ? t.dias_semana.split(',').map(s => s.trim()) : []
      return diasArr.some(d => DIAS_MAP[d] === dia.wday)
    } else {
      return t.fecha_especifica === dia.iso
    }
  })
}

const filas = computed(() => {
  const mapa = new Map()
  mapa.set(null, { id: null, nombre: 'Sin asignar' })
  props.planTareas.forEach(t => {
    if (t.responsable) {
      mapa.set(t.responsable.id, { id: t.responsable.id, nombre: t.responsable.nombre_completo || t.responsable.nombre })
    }
  })
  // Agregar usuarios asignados al club aunque no tengan tareas aún
  props.usuarios.slice(0, 6).forEach(u => {
    if (!mapa.has(u.id)) mapa.set(u.id, { id: u.id, nombre: u.nombre_completo || u.nombre })
  })
  return Array.from(mapa.values())
})

const sinTareas = computed(() => props.planTareas.length === 0)

function tipoEmoji(tipo) { return TIPO_EMOJI[tipo] || '📋' }

function initials(name) {
  if (!name) return '?'
  return name.split(' ').map(w => w[0]).slice(0, 2).join('').toUpperCase()
}

const AVATAR_COLORS = ['#1b5e20', '#1565c0', '#6a1b9a', '#c62828', '#e65100', '#00695c']
function avatarStyle(name) {
  const idx = (name || '').charCodeAt(0) % AVATAR_COLORS.length
  return { background: AVATAR_COLORS[idx] }
}
</script>

<style scoped>
.spv { display: flex; flex-direction: column; gap: 1rem; min-height: 0; }

.spv__nav { display: flex; align-items: center; gap: .75rem; }
.spv__nav-btn { width: 30px; height: 30px; border: 1.5px solid #e2e8f0; border-radius: 7px; background: #fff; color: #374151; cursor: pointer; display: flex; align-items: center; justify-content: center; font-size: .85rem; }
.spv__nav-btn:disabled { opacity: .35; cursor: not-allowed; }
.spv__nav-label { font-size: .875rem; font-weight: 600; color: #0f2611; }

.spv__grid-wrap { overflow-x: auto; border-radius: 12px; border: 1px solid #e8f0e9; background: #fff; }
.spv__grid { display: grid; min-width: 700px; }

.spv__grid-corner { background: #f6faf6; border-bottom: 1px solid #e8f0e9; border-right: 1px solid #e8f0e9; padding: .75rem; }

.spv__day-hdr { background: #f6faf6; border-bottom: 1px solid #e8f0e9; border-right: 1px solid #e8f0e9; padding: .6rem .75rem; display: flex; align-items: center; gap: .4rem; min-width: 0; }
.spv__day-hdr--hoy { background: #f0fdf4; }
.spv__day-name { font-size: .72rem; font-weight: 700; color: #60725d; text-transform: uppercase; letter-spacing: .04em; }
.spv__day-num  { font-size: .75rem; color: #374151; flex: 1; }
.spv__day-num--hoy { color: #1b5e20; font-weight: 700; }
.spv__add-btn  { width: 20px; height: 20px; border-radius: 5px; border: none; background: #e8f0e9; color: #1b5e20; font-size: .9rem; cursor: pointer; display: flex; align-items: center; justify-content: center; line-height: 1; flex-shrink: 0; }
.spv__add-btn:hover { background: #1b5e20; color: #fff; }

.spv__person-hdr { display: flex; align-items: center; gap: .5rem; padding: .6rem .75rem; border-bottom: 1px solid #e8f0e9; border-right: 1px solid #e8f0e9; background: #fafcfa; }
.spv__person-avatar { width: 26px; height: 26px; border-radius: 50%; color: #fff; font-size: .68rem; font-weight: 700; display: flex; align-items: center; justify-content: center; flex-shrink: 0; }
.spv__person-name { font-size: .78rem; font-weight: 600; color: #374151; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }

.spv__cell { border-bottom: 1px solid #e8f0e9; border-right: 1px solid #e8f0e9; padding: .4rem; display: flex; flex-direction: column; gap: .25rem; min-height: 60px; position: relative; }
.spv__cell--hoy { background: #fafff5; }
.spv__cell:hover .spv__cell-add { opacity: 1; }

.spv__card { background: #f0fdf4; border: 1px solid #c8e6c9; border-radius: 6px; padding: .25rem .4rem; cursor: pointer; display: flex; align-items: center; gap: .3rem; transition: box-shadow .12s; }
.spv__card:hover { box-shadow: 0 2px 6px rgba(0,0,0,.1); }
.spv__card--alta    { background: #fff7ed; border-color: #fed7aa; }
.spv__card--urgente { background: #fef2f2; border-color: #fecaca; }
.spv__card--baja    { background: #f8fafc; border-color: #e2e8f0; }
.spv__card-tipo  { font-size: .8rem; flex-shrink: 0; }
.spv__card-titulo { font-size: .72rem; font-weight: 600; color: #0f2611; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; flex: 1; min-width: 0; }
.spv__card-hora  { font-size: .65rem; color: #60725d; flex-shrink: 0; }

.spv__cell-add { position: absolute; bottom: 3px; right: 3px; width: 18px; height: 18px; border-radius: 4px; border: none; background: #e8f0e9; color: #1b5e20; font-size: .85rem; cursor: pointer; display: flex; align-items: center; justify-content: center; opacity: 0; transition: opacity .12s; }

.spv__empty { text-align: center; padding: 3rem 1rem; color: #60725d; font-size: .875rem; }
.spv__btn-add { margin-top: .5rem; background: #1b5e20; color: #fff; border: none; padding: .6rem 1.25rem; border-radius: 9px; font-size: .875rem; font-weight: 600; cursor: pointer; }
</style>
