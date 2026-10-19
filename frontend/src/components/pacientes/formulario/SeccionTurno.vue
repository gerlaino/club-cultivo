<script setup>
// El primer turno, opcional, en el mismo alta (19-oct-2026). Médico → día → horario, con los
// horarios que el médico tiene cargados y sin los que ya están dados. El backend vuelve a validar
// (no en el pasado, médico de la organización) y si el turno no entra, el alta no se hace a medias.
import { ref, computed, watch } from 'vue'
import { getAdminMedicos, getAdminMedicoDisponibilidad, getAdminMedicoTurnos } from '../../../lib/api.js'
import DsSpinner from '../../../design-system/components/Spinner.vue'

const props = defineProps({
  // `turno` del alta: null = sin turno; { medico_id, medico_nombre, fecha_hora } = elegido.
  modelValue: { type: Object, default: null },
})
const emit = defineEmits(['update:modelValue'])

const DURACION = 30
const DIAS_A_MOSTRAR = 14
// Sin horarios cargados se ofrece un día de consultorio común, y se dice.
const SIN_DISPONIBILIDAD = { desde: 9 * 60, hasta: 19 * 60 }

const quiere   = ref(!!props.modelValue)
const medicos  = ref(null)
const medicoId = ref(props.modelValue?.medico_id || null)
const disp     = ref([])
const ocupados = ref([])
const cargando = ref(false)
const error    = ref(null)
const dia      = ref(null) // 'yyyy-mm-dd'
const hora     = ref(null) // 'HH:MM'

const pad = (n) => String(n).padStart(2, '0')
const iso = (d) => `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`

async function cargarMedicos() {
  if (medicos.value) return
  try {
    const { data } = await getAdminMedicos()
    medicos.value = data || []
    if (!medicoId.value && medicos.value.length === 1) medicoId.value = medicos.value[0].id
  } catch {
    medicos.value = []
    error.value = 'No se pudo traer la lista de médicos.'
  }
}

watch(quiere, (v) => {
  if (v) cargarMedicos()
  else emit('update:modelValue', null)
}, { immediate: true })

watch(medicoId, async (id) => {
  dia.value = null; hora.value = null
  emit('update:modelValue', null)
  if (!id) return
  cargando.value = true
  try {
    const [d, t] = await Promise.all([getAdminMedicoDisponibilidad(id), getAdminMedicoTurnos(id)])
    disp.value = d.data || []
    ocupados.value = (t.data || []).filter(x => x.estado !== 'cancelado')
  } catch {
    error.value = 'No se pudo traer la agenda del médico.'
  } finally {
    cargando.value = false
  }
}, { immediate: true })

const sinHorarios = computed(() => medicoId.value && !cargando.value && disp.value.length === 0)

function franjas(d) {
  const dow = (d.getDay() + 6) % 7 // 0 = lunes, como la disponibilidad
  if (!disp.value.length) return dow < 6 ? [SIN_DISPONIBILIDAD] : []
  return disp.value.filter(s => s.dia_semana === dow).map(s => ({ desde: s.hora_inicio, hasta: s.hora_fin }))
}

function horariosDe(d) {
  const ahora = new Date()
  const out = []
  for (const f of franjas(d)) {
    for (let m = f.desde; m + DURACION <= f.hasta; m += DURACION) {
      const inicio = new Date(d); inicio.setHours(Math.floor(m / 60), m % 60, 0, 0)
      if (inicio <= ahora) continue
      const fin = new Date(inicio.getTime() + DURACION * 60000)
      const choca = ocupados.value.some(t => {
        const ti = new Date(t.fecha_hora); const tf = new Date(ti.getTime() + (t.duracion_minutos || 30) * 60000)
        return ti < fin && tf > inicio
      })
      out.push({ hora: `${pad(inicio.getHours())}:${pad(inicio.getMinutes())}`, libre: !choca })
    }
  }
  return out
}

const dias = computed(() => {
  if (!medicoId.value || cargando.value) return []
  const out = []
  const base = new Date(); base.setHours(0, 0, 0, 0)
  for (let i = 0; i < DIAS_A_MOSTRAR; i++) {
    const d = new Date(base); d.setDate(base.getDate() + i)
    const hs = horariosDe(d)
    out.push({
      iso: iso(d), libres: hs.filter(h => h.libre).length,
      sem: i === 0 ? 'Hoy' : i === 1 ? 'Mañana' : d.toLocaleDateString('es-AR', { weekday: 'short' }).replace('.', ''),
      num: d.getDate(), mes: d.toLocaleDateString('es-AR', { month: 'short' }).replace('.', ''),
    })
  }
  return out
})

const horarios = computed(() => {
  if (!dia.value) return []
  return horariosDe(new Date(dia.value + 'T00:00:00'))
})

function elegirDia(d) { if (d.libres) { dia.value = d.iso; hora.value = null; emit('update:modelValue', null) } }
function elegirHora(h) {
  if (!h.libre) return
  hora.value = h.hora
  const m = medicos.value?.find(x => x.id === medicoId.value)
  emit('update:modelValue', {
    medico_id: medicoId.value, medico_nombre: m?.nombre_completo,
    fecha_hora: `${dia.value}T${h.hora}:00`, duracion_minutos: DURACION, tipo: 'primera_vez',
  })
}
</script>

<template>
  <div class="pf-seccion">
    <label class="pf-switch">
      <input v-model="quiere" type="checkbox" />
      <span class="pf-switch__track"></span>
      <span>
        <span class="pf-switch__t">Darle ya el turno de la entrevista</span>
        <span class="pf-switch__d">Opcional. Queda agendado con el médico, que lo ve en su agenda y en su lista de pacientes.</span>
      </span>
    </label>

    <template v-if="quiere">
      <div v-if="medicos === null" class="st-cargando"><DsSpinner :size="16" /> Buscando médicos…</div>
      <div v-else-if="!medicos.length" class="pf-aviso pf-aviso--warn">
        <i class="bi bi-person-x"></i>
        <div>La organización no tiene médicos cargados. El turno se le da después, desde la ficha.</div>
      </div>
      <template v-else>
        <div class="pf-campo">
          <span class="pf-label">Médico</span>
          <div class="pf-chips" role="radiogroup" aria-label="Médico">
            <button v-for="m in medicos" :key="m.id" type="button" role="radio" :aria-checked="medicoId === m.id"
                    class="pf-chip" :class="{ 'pf-chip--on': medicoId === m.id }" @click="medicoId = m.id">
              {{ m.nombre_completo }}
            </button>
          </div>
        </div>

        <div v-if="cargando" class="st-cargando"><DsSpinner :size="16" /> Mirando su agenda…</div>
        <template v-else-if="medicoId">
          <div v-if="sinHorarios" class="pf-aviso pf-aviso--warn">
            <i class="bi bi-clock-history"></i>
            <div>No tiene horarios de atención cargados: se ofrecen de lunes a sábado de 9 a 19.</div>
          </div>
          <div class="pf-campo">
            <span class="pf-label">Día</span>
            <div class="st-dias" role="radiogroup" aria-label="Día del turno">
              <button v-for="d in dias" :key="d.iso" type="button" role="radio" :aria-checked="dia === d.iso"
                      class="st-dia" :class="{ 'st-dia--on': dia === d.iso }" :disabled="!d.libres" @click="elegirDia(d)">
                <span class="st-dia__sem">{{ d.sem }}</span>
                <span class="st-dia__num">{{ d.num }}</span>
                <span class="st-dia__mes">{{ d.mes }}</span>
              </button>
            </div>
          </div>
          <div v-if="dia" class="pf-campo">
            <span class="pf-label">Horario <span class="pf-opc">30 minutos · primera vez</span></span>
            <div v-if="horarios.length" class="pf-chips" role="radiogroup" aria-label="Horario del turno">
              <button v-for="h in horarios" :key="h.hora" type="button" role="radio" :aria-checked="hora === h.hora"
                      class="pf-chip" :class="{ 'pf-chip--on': hora === h.hora }" :disabled="!h.libre"
                      :title="h.libre ? '' : 'Ya está dado'" @click="elegirHora(h)">{{ h.hora }}</button>
            </div>
          </div>
        </template>
      </template>
      <span v-if="error" class="pf-err">{{ error }}</span>
    </template>
  </div>
</template>

<style scoped>
.st-cargando { display: flex; align-items: center; gap: .5rem; font-size: .85rem; color: var(--c-slate-500); }
.st-dias { display: flex; gap: .5rem; overflow-x: auto; padding-bottom: .35rem; scroll-snap-type: x proximity; }
.st-dia {
  flex: 0 0 auto; width: 64px; padding: .5rem 0; border-radius: var(--r-lg); border: 1px solid var(--c-slate-300);
  background: var(--c-paper, #fff); display: flex; flex-direction: column; align-items: center; gap: .05rem; cursor: pointer;
  font: inherit; color: var(--c-slate-700); scroll-snap-align: start; transition: all var(--t-fast);
}
.st-dia:hover:not(:disabled) { border-color: var(--c-slate-500); }
.st-dia:disabled { opacity: .35; cursor: not-allowed; }
.st-dia--on { background: var(--c-leaf-800); border-color: var(--c-leaf-800); color: #fff; }
.st-dia__sem { font-size: .68rem; font-weight: 700; text-transform: uppercase; letter-spacing: .04em; }
.st-dia__num { font-size: 1.25rem; font-weight: 800; line-height: 1.1; font-family: var(--font-display); }
.st-dia__mes { font-size: .68rem; text-transform: lowercase; opacity: .8; }
</style>
