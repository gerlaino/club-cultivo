<template>
  <div class="mpv">
    <!-- Month nav -->
    <div class="mpv__nav">
      <button class="mpv__nav-btn" @click="mesAnterior" :disabled="!puedoRetroceder"><i class="bi bi-chevron-left"></i></button>
      <span class="mpv__nav-label">{{ labelMes }}</span>
      <button class="mpv__nav-btn" @click="mesSiguiente" :disabled="!puedoAvanzar"><i class="bi bi-chevron-right"></i></button>
    </div>

    <!-- Calendar -->
    <div class="mpv__cal">
      <div class="mpv__cal-hdr" v-for="d in ['Lun','Mar','Mié','Jue','Vie','Sáb']" :key="d">{{ d }}</div>

      <template v-for="(semana, si) in calendario" :key="si">
        <div v-for="dia in semana" :key="dia.iso || 'blank-' + si + '-' + dia.n" class="mpv__dia" :class="{ 'mpv__dia--vacio': !dia.iso, 'mpv__dia--hoy': dia.esHoy, 'mpv__dia--fuera': dia.fueraPlan }">
          <span v-if="dia.iso" class="mpv__dia-num">{{ dia.num }}</span>
          <div v-if="dia.iso" class="mpv__dia-tareas">
            <div v-for="t in tareasEnDia(dia)" :key="t.id" class="mpv__pill" :class="`mpv__pill--${t.tipo}`" @click="$emit('edit-tarea', t)" :title="t.titulo_display || t.tipo">
              {{ tipoEmoji(t.tipo) }} {{ t.titulo_display || t.tipo }}
            </div>
            <div v-if="tareasEnDia(dia).length > 3" class="mpv__pill mpv__pill--mas">+{{ tareasEnDia(dia).length - 3 }} más</div>
          </div>
          <button v-if="dia.iso && !dia.fueraPlan" class="mpv__dia-add" @click="$emit('add-tarea', { fecha: dia.iso })">+</button>
        </div>
      </template>
    </div>

    <div v-if="sinTareas" class="mpv__empty">
      <p>No hay tareas en este mes. <button class="mpv__link" @click="$emit('add-tarea', {})">Agregar tarea</button></p>
    </div>
  </div>
</template>

<script setup>
import { ref, computed } from 'vue'

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

function mesInicial() {
  const hoy = isoDate(new Date())
  let iso = props.plan.fecha_inicio
  if (hoy >= props.plan.fecha_inicio && hoy <= props.plan.fecha_fin) iso = hoy
  else if (hoy > props.plan.fecha_fin) iso = props.plan.fecha_fin
  const d = parseDate(iso)
  return { anio: d.getFullYear(), mes: d.getMonth() }
}
const mesRef = ref(mesInicial())

const labelMes = computed(() => `${MESES_LABEL[mesRef.value.mes]} ${mesRef.value.anio}`)

const puedoRetroceder = computed(() => {
  const ini = parseDate(props.plan.fecha_inicio)
  return mesRef.value.anio > ini.getFullYear() || mesRef.value.mes > ini.getMonth()
})
const puedoAvanzar = computed(() => {
  const fin = parseDate(props.plan.fecha_fin)
  return mesRef.value.anio < fin.getFullYear() || mesRef.value.mes < fin.getMonth()
})

function mesAnterior() {
  if (mesRef.value.mes === 0) { mesRef.value = { anio: mesRef.value.anio - 1, mes: 11 } }
  else { mesRef.value = { ...mesRef.value, mes: mesRef.value.mes - 1 } }
}
function mesSiguiente() {
  if (mesRef.value.mes === 11) { mesRef.value = { anio: mesRef.value.anio + 1, mes: 0 } }
  else { mesRef.value = { ...mesRef.value, mes: mesRef.value.mes + 1 } }
}

const calendario = computed(() => {
  const { anio, mes } = mesRef.value
  const hoy = isoDate(new Date())
  const primerDia = new Date(anio, mes, 1)
  const ultimoDia = new Date(anio, mes + 1, 0)

  // Start from Monday
  let startWday = primerDia.getDay() // 0=Dom
  let offset = startWday === 0 ? 6 : startWday - 1

  const semanas = []
  let semana = []

  // Blank cells before month start
  for (let i = 0; i < offset; i++) semana.push({ iso: null })

  for (let d = 1; d <= ultimoDia.getDate(); d++) {
    const date = new Date(anio, mes, d)
    const iso = isoDate(date)
    semana.push({
      iso, num: d, esHoy: iso === hoy,
      wday: date.getDay(),
      fueraPlan: iso < props.plan.fecha_inicio || iso > props.plan.fecha_fin,
    })
    if (semana.length === 6) { semanas.push(semana); semana = [] }
  }
  // Don't include Sunday column (we show Mon-Sat)
  if (semana.length > 0) {
    while (semana.length < 6) semana.push({ iso: null })
    semanas.push(semana)
  }
  return semanas
})

function tareasEnDia(dia) {
  if (!dia.iso) return []
  const dObj = parseDate(dia.iso)
  return props.planTareas.filter(t => {
    if (t.es_recurrente) {
      const diasArr = t.dias_semana ? t.dias_semana.split(',').map(s => s.trim()) : []
      return diasArr.some(d => DIAS_MAP[d] === dObj.getDay())
    }
    return t.fecha_especifica === dia.iso
  }).slice(0, 4)
}

const sinTareas = computed(() => props.planTareas.length === 0)
function tipoEmoji(tipo) { return TIPO_EMOJI[tipo] || '📋' }
</script>

<style scoped>
.mpv { display: flex; flex-direction: column; gap: 1rem; }

.mpv__nav { display: flex; align-items: center; gap: .75rem; }
.mpv__nav-btn { width: 30px; height: 30px; border: 1.5px solid var(--c-slate-200); border-radius: 7px; background: #fff; color: #374151; cursor: pointer; display: flex; align-items: center; justify-content: center; }
.mpv__nav-btn:disabled { opacity: .35; cursor: not-allowed; }
.mpv__nav-label { font-size: .875rem; font-weight: 700; color: #0f2611; }

.mpv__cal { display: grid; grid-template-columns: repeat(6, 1fr); gap: 1px; background: #e8f0e9; border: 1px solid #e8f0e9; border-radius: 12px; overflow: hidden; }
.mpv__cal-hdr { background: #f6faf6; padding: .5rem .75rem; font-size: .72rem; font-weight: 700; color: #60725d; text-transform: uppercase; letter-spacing: .04em; text-align: center; }

.mpv__dia { background: #fff; min-height: 90px; padding: .4rem .5rem; position: relative; display: flex; flex-direction: column; gap: .2rem; }
.mpv__dia--vacio { background: var(--c-slate-50); }
.mpv__dia--hoy { background: #fafff5; }
.mpv__dia--fuera { background: #fafafa; opacity: .55; }
.mpv__dia:hover:not(.mpv__dia--vacio) .mpv__dia-add { opacity: 1; }

.mpv__dia-num { font-size: .75rem; font-weight: 700; color: #374151; }
.mpv__dia--hoy .mpv__dia-num { color: #1b5e20; }

.mpv__dia-tareas { display: flex; flex-direction: column; gap: 2px; flex: 1; }
.mpv__pill { font-size: .65rem; padding: .15rem .4rem; border-radius: 4px; background: #e8f5e9; color: #1b5e20; font-weight: 600; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; cursor: pointer; }
.mpv__pill:hover { background: #c8e6c9; }
.mpv__pill--riego     { background: #e3f2fd; color: #1565c0; }
.mpv__pill--poda      { background: #fce4ec; color: #c62828; }
.mpv__pill--limpieza  { background: #fff8e1; color: #e65100; }
.mpv__pill--mas       { background: var(--c-slate-100); color: var(--c-slate-500); cursor: default; }
.mpv__dia-add { position: absolute; bottom: 4px; right: 4px; width: 18px; height: 18px; border-radius: 4px; border: none; background: #e8f0e9; color: #1b5e20; font-size: .85rem; cursor: pointer; display: flex; align-items: center; justify-content: center; opacity: 0; transition: opacity .12s; }

.mpv__empty { text-align: center; padding: 2rem; color: #60725d; font-size: .875rem; }
.mpv__link { background: none; border: none; color: #1b5e20; font-weight: 600; cursor: pointer; text-decoration: underline; }
</style>
