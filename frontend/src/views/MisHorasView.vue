<template>
  <div class="mh">
    <header class="mh__head">
      <div>
        <h1 class="mh__title">Mis horas</h1>
        <p class="mh__sub">Cargá tu entrada y salida de cada día</p>
      </div>
    </header>

    <!-- Nav de mes + total -->
    <div class="mh__monthbar">
      <button class="mh__nav" @click="cambiarMes(-1)" aria-label="Mes anterior"><i class="bi bi-chevron-left"></i></button>
      <span class="mh__month">{{ labelMes }}</span>
      <button class="mh__nav" @click="cambiarMes(1)" :disabled="esMesActual" aria-label="Mes siguiente"><i class="bi bi-chevron-right"></i></button>
      <span class="mh__total"><strong>{{ totalHoras }}</strong> hs</span>
    </div>

    <!-- Calendario -->
    <div class="mh__cal">
      <div v-for="d in ['L','M','M','J','V','S','D']" :key="d" class="mh__dow">{{ d }}</div>
      <div v-for="(cel, i) in celdas" :key="i"
           class="mh__cell"
           :class="{ 'mh__cell--empty': !cel, 'mh__cell--hoy': cel && cel.iso === hoyISO, 'mh__cell--con': cel && cel.jornada, 'mh__cell--futuro': cel && cel.iso > hoyISO }"
           @click="cel && !(cel.iso > hoyISO) && abrir(cel)">
        <template v-if="cel">
          <span class="mh__num">{{ cel.dia }}</span>
          <span v-if="cel.jornada" class="mh__hs">{{ cel.jornada.horas }}h</span>
        </template>
      </div>
    </div>

    <div v-if="loading" class="mh__loading"><i class="bi bi-arrow-repeat mh__spin"></i></div>

    <!-- Sheet de carga -->
    <MobileSheet v-model="sheetOpen" :title="sheetTitle">
      <div class="mh__form">
        <div class="mh__row">
          <label class="mh__lbl">Entrada</label>
          <input type="time" v-model="form.hora_entrada" class="mh__input" />
        </div>
        <div class="mh__row">
          <label class="mh__lbl">Salida</label>
          <input type="time" v-model="form.hora_salida" class="mh__input" />
        </div>
        <div class="mh__row">
          <label class="mh__lbl">Nota <span class="mh__opt">opcional</span></label>
          <input type="text" v-model.trim="form.nota" class="mh__input" placeholder="Ej: turno tarde" />
        </div>
        <p v-if="calcHoras !== null" class="mh__calc">Total: <strong>{{ calcHoras }} hs</strong></p>
        <p v-if="error" class="mh__err">{{ error }}</p>
        <div class="mh__actions">
          <button v-if="editando" class="mh__btn-del" :disabled="saving" @click="eliminar"><i class="bi bi-trash"></i></button>
          <button class="mh__btn" :disabled="saving || !form.hora_entrada || !form.hora_salida" @click="guardar">
            {{ saving ? 'Guardando…' : 'Guardar' }}
          </button>
        </div>
      </div>
    </MobileSheet>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { listJornadas, createJornada, updateJornada, deleteJornada } from '../lib/api.js'
import { useToast } from '../composables/useToast.js'
import MobileSheet from '../components/mobile/MobileSheet.vue'

const toast = useToast()
const hoy = new Date()
const hoyISO = toISO(hoy)

const anio = ref(hoy.getFullYear())
const mes  = ref(hoy.getMonth() + 1) // 1-12
const jornadas = ref([])
const totalHoras = ref(0)
const loading = ref(false)

const sheetOpen = ref(false)
const editando  = ref(null)
const diaSel    = ref(null)
const form = ref({ hora_entrada: '', hora_salida: '', nota: '' })
const error = ref('')
const saving = ref(false)

function toISO(d) { return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}` }

const MESES = ['Enero','Febrero','Marzo','Abril','Mayo','Junio','Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre']
const labelMes = computed(() => `${MESES[mes.value-1]} ${anio.value}`)
const esMesActual = computed(() => anio.value === hoy.getFullYear() && mes.value === hoy.getMonth()+1)

const jornadaPorDia = computed(() => {
  const map = {}
  jornadas.value.forEach(j => { map[j.fecha] = j })
  return map
})

const celdas = computed(() => {
  const primero = new Date(anio.value, mes.value-1, 1)
  const offset = (primero.getDay() + 6) % 7 // lunes=0
  const diasMes = new Date(anio.value, mes.value, 0).getDate()
  const out = []
  for (let i = 0; i < offset; i++) out.push(null)
  for (let d = 1; d <= diasMes; d++) {
    const iso = `${anio.value}-${String(mes.value).padStart(2,'0')}-${String(d).padStart(2,'0')}`
    out.push({ dia: d, iso, jornada: jornadaPorDia.value[iso] || null })
  }
  return out
})

const calcHoras = computed(() => {
  const { hora_entrada: e, hora_salida: s } = form.value
  if (!/^\d{2}:\d{2}$/.test(e || '') || !/^\d{2}:\d{2}$/.test(s || '')) return null
  const me = +e.slice(0,2)*60 + +e.slice(3,5)
  let diff = (+s.slice(0,2)*60 + +s.slice(3,5)) - me
  if (diff < 0) diff += 1440
  return Math.round(diff/60*100)/100
})

const sheetTitle = computed(() => diaSel.value ? `Día ${diaSel.value.dia}` : 'Cargar horas')

async function cargar() {
  loading.value = true
  try {
    const { data } = await listJornadas({ anio: anio.value, mes: mes.value })
    jornadas.value = data.jornadas || []
    totalHoras.value = data.total_horas || 0
  } catch {} finally { loading.value = false }
}

function cambiarMes(delta) {
  let m = mes.value + delta, a = anio.value
  if (m < 1) { m = 12; a-- } else if (m > 12) { m = 1; a++ }
  if (a > hoy.getFullYear() || (a === hoy.getFullYear() && m > hoy.getMonth()+1)) return
  mes.value = m; anio.value = a
  cargar()
}

function abrir(cel) {
  diaSel.value = cel
  error.value = ''
  if (cel.jornada) {
    editando.value = cel.jornada
    form.value = { hora_entrada: cel.jornada.hora_entrada, hora_salida: cel.jornada.hora_salida, nota: cel.jornada.nota || '' }
  } else {
    editando.value = null
    form.value = { hora_entrada: '09:00', hora_salida: '17:00', nota: '' }
  }
  sheetOpen.value = true
}

async function guardar() {
  saving.value = true; error.value = ''
  try {
    const payload = { fecha: diaSel.value.iso, ...form.value }
    if (editando.value) await updateJornada(editando.value.id, payload)
    else await createJornada(payload)
    sheetOpen.value = false
    toast.success('Horas guardadas')
    await cargar()
  } catch (e) {
    error.value = e?.response?.data?.errors?.join(', ') || 'No se pudo guardar'
  } finally { saving.value = false }
}

async function eliminar() {
  if (!editando.value) return
  saving.value = true
  try {
    await deleteJornada(editando.value.id)
    sheetOpen.value = false
    toast.success('Jornada eliminada')
    await cargar()
  } catch { error.value = 'No se pudo eliminar' } finally { saving.value = false }
}

onMounted(cargar)
</script>

<style scoped>
.mh { padding: 0 0 2rem; }
.mh__head { padding: 1.2rem 1.1rem .6rem; }
.mh__title { font-family: var(--font-display, sans-serif); font-size: 1.45rem; font-weight: 700; color: var(--c-ink-900, #1a1d1f); margin: 0; }
.mh__sub { margin: .2rem 0 0; font-size: .8rem; color: var(--c-ink-500, #6b7280); }

.mh__monthbar { display: flex; align-items: center; gap: .6rem; padding: .4rem 1.1rem 1rem; }
.mh__nav { width: 34px; height: 34px; border-radius: 10px; border: 1px solid var(--c-leaf-100, #e8f0eb); background: #fff; color: var(--c-leaf-700, #2d4a3e); cursor: pointer; display: flex; align-items: center; justify-content: center; }
.mh__nav:disabled { opacity: .4; }
.mh__month { font-weight: 700; color: var(--c-ink-900, #1a1d1f); font-size: .95rem; flex: 1; text-align: center; }
.mh__total { background: var(--c-leaf-100, #e8f0eb); color: var(--c-leaf-700, #2d4a3e); border-radius: 999px; padding: .3rem .7rem; font-size: .82rem; }

.mh__cal { display: grid; grid-template-columns: repeat(7, 1fr); gap: .3rem; padding: 0 1rem; }
.mh__dow { text-align: center; font-size: .65rem; font-weight: 700; color: var(--c-ink-500, #9aa39c); text-transform: uppercase; padding-bottom: .3rem; }
.mh__cell {
  aspect-ratio: 1; border-radius: 11px; border: 1px solid var(--c-leaf-100, #e8f0eb); background: #fff;
  display: flex; flex-direction: column; align-items: center; justify-content: center; gap: .1rem;
  cursor: pointer; -webkit-tap-highlight-color: transparent; transition: transform .1s, border-color .15s;
}
.mh__cell:active { transform: scale(.94); }
.mh__cell--empty { border: none; background: transparent; cursor: default; }
.mh__cell--futuro { opacity: .4; cursor: not-allowed; }
.mh__cell--hoy { border-color: var(--c-leaf-500, #5a8a72); }
.mh__cell--con { background: var(--c-leaf-800, #1a3d2e); border-color: var(--c-leaf-800, #1a3d2e); }
.mh__num { font-size: .85rem; font-weight: 600; color: var(--c-ink-900, #1a1d1f); }
.mh__cell--con .mh__num { color: #fff; }
.mh__hs { font-size: .6rem; font-weight: 700; color: var(--c-leaf-300, #a8c9b5); }

.mh__loading { display: flex; justify-content: center; padding: 1.5rem; }
.mh__spin { font-size: 1.4rem; color: var(--c-leaf-300, #a8c9b5); animation: spin .8s linear infinite; }
@keyframes spin { to { transform: rotate(360deg); } }

.mh__form { display: flex; flex-direction: column; gap: .9rem; }
.mh__row { display: flex; flex-direction: column; gap: .3rem; }
.mh__lbl { font-size: .72rem; font-weight: 700; color: var(--c-ink-700, #374151); text-transform: uppercase; letter-spacing: .04em; }
.mh__opt { font-weight: 400; text-transform: none; color: var(--c-ink-500, #9aa39c); }
.mh__input { background: var(--c-leaf-50, #f4f8f5); border: 1.5px solid var(--c-leaf-100, #e8f0eb); border-radius: 10px; padding: .65rem .85rem; font-size: 1rem; color: var(--c-ink-900, #1a1d1f); width: 100%; box-sizing: border-box; }
.mh__input:focus { outline: none; border-color: var(--c-leaf-500, #5a8a72); }
.mh__calc { font-size: .85rem; color: var(--c-ink-700, #374151); margin: 0; }
.mh__err { color: #dc2626; font-size: .8rem; margin: 0; }
.mh__actions { display: flex; gap: .6rem; }
.mh__btn { flex: 1; background: var(--c-leaf-800, #1a3d2e); color: #fff; border: none; padding: .85rem; border-radius: 12px; font-size: .95rem; font-weight: 700; cursor: pointer; }
.mh__btn:disabled { opacity: .6; }
.mh__btn-del { width: 50px; border-radius: 12px; border: 1.5px solid #fecaca; background: #fef2f2; color: #dc2626; cursor: pointer; font-size: 1rem; }
</style>
