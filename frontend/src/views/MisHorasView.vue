<template>
  <div class="mh">
    <div class="mh__wrap">

      <header class="mh__head">
        <div>
          <h1 class="mh__title">Mis horas</h1>
          <p class="mh__sub">Cargá tu entrada y salida de cada día</p>
        </div>
        <div class="mh__total">
          <span class="mh__total-num">{{ totalHoras }}</span>
          <span class="mh__total-lbl">hs este mes</span>
        </div>
      </header>

      <!-- Calendario -->
      <div class="mh__cal-card">
        <div class="mh__monthbar">
          <button class="mh__nav" @click="cambiarMes(-1)" aria-label="Mes anterior"><i class="bi bi-chevron-left"></i></button>
          <span class="mh__month">{{ labelMes }}</span>
          <button class="mh__nav" @click="cambiarMes(1)" :disabled="esMesActual" aria-label="Mes siguiente"><i class="bi bi-chevron-right"></i></button>
        </div>

        <div class="mh__dows">
          <span v-for="(d, i) in ['Lun','Mar','Mié','Jue','Vie','Sáb','Dom']" :key="i" class="mh__dow">{{ d }}</span>
        </div>

        <div class="mh__grid">
          <div v-for="(cel, i) in celdas" :key="i"
               class="mh__cell"
               :class="{
                 'mh__cell--empty': !cel,
                 'mh__cell--hoy': cel && cel.iso === hoyISO,
                 'mh__cell--con': cel && cel.jornada,
                 'mh__cell--fut': cel && cel.iso > hoyISO,
               }"
               @click="cel && !(cel.iso > hoyISO) && abrir(cel)">
            <template v-if="cel">
              <span class="mh__num">{{ cel.dia }}</span>
              <span v-if="cel.jornada" class="mh__dot"></span>
            </template>
          </div>
        </div>

        <div v-if="loading" class="mh__loading"><i class="bi bi-arrow-repeat mh__spin"></i></div>
      </div>

      <!-- Detalle de días cargados -->
      <div v-if="jornadas.length" class="mh__list">
        <div v-for="j in jornadasOrden" :key="j.id" class="mh__item" @click="abrirJornada(j)">
          <div class="mh__item-fecha">
            <span class="mh__item-dia">{{ diaDe(j.fecha) }}</span>
            <span class="mh__item-mes">{{ mesCortoDe(j.fecha) }}</span>
          </div>
          <div class="mh__item-body">
            <span class="mh__item-horario">{{ j.hora_entrada }} – {{ j.hora_salida }}</span>
            <span v-if="j.nota" class="mh__item-nota">{{ j.nota }}</span>
          </div>
          <span class="mh__item-hs">{{ j.horas }}h</span>
          <span class="mh__estado" :class="j.estado === 'confirmada' ? 'mh__estado--ok' : 'mh__estado--pend'">
            {{ j.estado === 'confirmada' ? 'Confirmada' : 'Pendiente' }}
          </span>
          <i v-if="j.estado !== 'confirmada'" class="bi bi-chevron-right mh__item-arr"></i>
          <i v-else class="bi bi-lock mh__item-arr"></i>
        </div>
      </div>
      <p v-else-if="!loading" class="mh__empty">Tocá un día del calendario para cargar tus horas.</p>

    </div>

    <!-- Sheet de carga -->
    <MobileSheet v-model="sheetOpen" :title="sheetTitle">
      <div class="mh__form">
        <div class="mh__form-row">
          <label class="mh__lbl">Entrada</label>
          <input type="time" v-model="form.hora_entrada" class="mh__input" />
        </div>
        <div class="mh__form-row">
          <label class="mh__lbl">Salida</label>
          <input type="time" v-model="form.hora_salida" class="mh__input" />
        </div>
        <div class="mh__form-row">
          <label class="mh__lbl">Nota <span class="mh__opt">opcional</span></label>
          <input type="text" v-model.trim="form.nota" class="mh__input" placeholder="Ej: turno tarde" />
        </div>
        <p v-if="calcHoras !== null" class="mh__calc">Total del día: <strong>{{ calcHoras }} hs</strong></p>
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
const mes  = ref(hoy.getMonth() + 1)
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
const MESES_CORTO = ['ene','feb','mar','abr','may','jun','jul','ago','sep','oct','nov','dic']
const labelMes = computed(() => `${MESES[mes.value-1]} ${anio.value}`)
const esMesActual = computed(() => anio.value === hoy.getFullYear() && mes.value === hoy.getMonth()+1)

const jornadaPorDia = computed(() => {
  const map = {}
  jornadas.value.forEach(j => { map[j.fecha] = j })
  return map
})
const jornadasOrden = computed(() => [...jornadas.value].sort((a, b) => b.fecha.localeCompare(a.fecha)))

function diaDe(iso)      { return iso.slice(8, 10) }
function mesCortoDe(iso) { return MESES_CORTO[+iso.slice(5, 7) - 1] }

const celdas = computed(() => {
  const primero = new Date(anio.value, mes.value-1, 1)
  const offset = (primero.getDay() + 6) % 7
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

const sheetTitle = computed(() => diaSel.value ? `${diaSel.value.dia} de ${MESES[mes.value-1]}` : 'Cargar horas')

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
  if (cel.jornada?.estado === 'confirmada') {
    toast.info('Esta jornada ya fue confirmada por el admin — no se puede editar.')
    return
  }
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
function abrirJornada(j) {
  abrir({ dia: +diaDe(j.fecha), iso: j.fecha, jornada: j })
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
.mh { padding: 1.5rem 1rem 2.5rem; display: flex; justify-content: center; }
.mh__wrap { width: 100%; max-width: 620px; }

.mh__head { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; margin-bottom: 1rem; }
.mh__title { font-family: var(--font-display, sans-serif); font-size: 1.4rem; font-weight: 700; color: var(--c-ink-900, #1a1d1f); margin: 0; }
.mh__sub { margin: .2rem 0 0; font-size: .8rem; color: var(--c-ink-500, #6b7280); }
.mh__total { text-align: right; flex-shrink: 0; background: var(--c-leaf-800, #1a3d2e); color: #fff; border-radius: 14px; padding: .5rem .85rem; line-height: 1.1; }
.mh__total-num { display: block; font-family: var(--font-display, sans-serif); font-size: 1.5rem; font-weight: 700; }
.mh__total-lbl { display: block; font-size: .6rem; color: rgba(255,255,255,.7); margin-top: .1rem; }

/* Card del calendario */
.mh__cal-card { background: #fff; border: 1px solid var(--c-leaf-100, #e8f0eb); border-radius: 18px; padding: 1.25rem; box-shadow: var(--sh-1); }
.mh__monthbar { display: flex; align-items: center; justify-content: space-between; margin-bottom: .8rem; }
.mh__nav { width: 32px; height: 32px; border-radius: 9px; border: 1px solid var(--c-leaf-100, #e8f0eb); background: var(--c-leaf-50, #f4f8f5); color: var(--c-leaf-700, #2d4a3e); cursor: pointer; display: flex; align-items: center; justify-content: center; transition: background .15s; }
.mh__nav:hover:not(:disabled) { background: var(--c-leaf-100, #e8f0eb); }
.mh__nav:disabled { opacity: .35; cursor: not-allowed; }
.mh__month { font-family: var(--font-display, sans-serif); font-weight: 700; color: var(--c-ink-900, #1a1d1f); font-size: 1rem; }

.mh__dows { display: grid; grid-template-columns: repeat(7, 1fr); margin-bottom: .35rem; }
.mh__dow { text-align: center; font-size: .68rem; font-weight: 700; color: var(--c-ink-300, #b8c0b8); text-transform: uppercase; letter-spacing: .03em; padding-bottom: .15rem; }

.mh__grid { display: grid; grid-template-columns: repeat(7, 1fr); gap: 6px; }
.mh__cell {
  aspect-ratio: 1; max-height: 70px;
  border-radius: 12px; position: relative;
  display: flex; align-items: center; justify-content: center;
  background: var(--c-leaf-50, #f4f8f5);
  cursor: pointer; -webkit-tap-highlight-color: transparent;
  transition: transform .1s, background .15s, box-shadow .15s;
}
.mh__cell:hover:not(.mh__cell--empty):not(.mh__cell--fut) { box-shadow: inset 0 0 0 1.5px var(--c-leaf-300, #a8c9b5); }
.mh__cell:active:not(.mh__cell--empty) { transform: scale(.92); }
.mh__cell--empty { background: transparent; cursor: default; }
.mh__cell--fut { opacity: .35; cursor: not-allowed; }
.mh__cell--hoy { box-shadow: inset 0 0 0 1.5px var(--c-leaf-500, #5a8a72); }
.mh__cell--con { background: var(--c-leaf-800, #1a3d2e); }
.mh__num { font-size: .95rem; font-weight: 600; color: var(--c-ink-700, #3a3f44); }
.mh__cell--con .mh__num { color: #fff; }
.mh__dot { position: absolute; bottom: 7px; width: 5px; height: 5px; border-radius: 50%; background: var(--c-leaf-300, #a8c9b5); }

.mh__loading { display: flex; justify-content: center; padding: .8rem 0 0; }
.mh__spin { font-size: 1.2rem; color: var(--c-leaf-300, #a8c9b5); animation: spin .8s linear infinite; }
@keyframes spin { to { transform: rotate(360deg); } }

/* Lista de días cargados */
.mh__list { margin-top: 1rem; display: flex; flex-direction: column; gap: .45rem; }
.mh__item {
  display: flex; align-items: center; gap: .8rem;
  background: #fff; border: 1px solid var(--c-leaf-100, #e8f0eb); border-radius: 12px; padding: .6rem .8rem;
  cursor: pointer; -webkit-tap-highlight-color: transparent; transition: border-color .15s, box-shadow .15s;
}
.mh__item:hover { border-color: var(--c-leaf-300, #a8c9b5); box-shadow: var(--sh-1); }
.mh__item-fecha { width: 38px; text-align: center; flex-shrink: 0; line-height: 1; }
.mh__item-dia { display: block; font-family: var(--font-display, sans-serif); font-size: 1.15rem; font-weight: 700; color: var(--c-ink-900, #1a1d1f); }
.mh__item-mes { display: block; font-size: .6rem; font-weight: 700; color: var(--c-ink-300, #b8c0b8); text-transform: uppercase; }
.mh__item-body { flex: 1; min-width: 0; display: flex; flex-direction: column; }
.mh__item-horario { font-size: .85rem; font-weight: 600; color: var(--c-ink-900, #1a1d1f); }
.mh__item-nota { font-size: .72rem; color: var(--c-ink-500, #6b7280); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.mh__item-hs { font-size: .85rem; font-weight: 700; color: var(--c-leaf-700, #2d4a3e); background: var(--c-leaf-100, #e8f0eb); border-radius: 999px; padding: .15rem .55rem; flex-shrink: 0; }
.mh__item-arr { color: var(--c-ink-300, #d1d5db); font-size: .75rem; flex-shrink: 0; }
.mh__estado { font-size: .62rem; font-weight: 700; text-transform: uppercase; letter-spacing: .04em; padding: .12rem .5rem; border-radius: 999px; flex-shrink: 0; }
.mh__estado--ok   { background: #dcfce7; color: #15803d; }
.mh__estado--pend { background: #fef3c7; color: #b45309; }
.mh__empty { margin-top: 1rem; text-align: center; color: var(--c-ink-500, #9aa39c); font-size: .82rem; }

/* Form (sheet) */
.mh__form { display: flex; flex-direction: column; gap: .85rem; }
.mh__form-row { display: flex; flex-direction: column; gap: .3rem; }
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
