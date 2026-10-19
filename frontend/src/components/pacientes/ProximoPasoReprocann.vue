<script setup>
// «QUÉ SIGUE» EN LA FICHA (19-oct-2026). Dice en qué paso del REPROCANN está el paciente y ofrece
// SÓLO las acciones que el backend acepta desde ahí (`situacion.acciones`): dar turno, «Inicié el
// trámite», «Llegó aprobado», «No indicado», «Rechazado», «Volver a entrevistar», «Se vinculó».
import { ref, computed, watch } from 'vue'
import AppDatePicker from '../ui/AppDatePicker.vue'
import DsSpinner from '../../design-system/components/Spinner.vue'
import { useToast } from '../../composables/useToast.js'
import { useConfirm } from '../../composables/useConfirm.js'
import {
  iniciarTramiteReprocann, reprocannAprobado, reprocannNoIndicado, reprocannRechazado,
  volverAEntrevistar, updatePaciente,
} from '../../lib/api.js'
import { REPROCANN_SITUACION, ACCIONES } from '../../composables/useSituacionPaciente.js'
import './formulario/formulario.css'

const props = defineProps({
  paciente: { type: Object, required: true },
  esAdmin:  { type: Boolean, default: false },
})
const emit = defineEmits(['cambio', 'dar-turno'])

const toast = useToast()
const { confirm } = useConfirm()

const sit = computed(() => props.paciente.situacion || {})
const acciones = computed(() => sit.value.acciones || [])
const adherente = computed(() => sit.value.vinculo === 'adherente')

const fecha = (d) => d ? new Date(String(d).length === 10 ? d + 'T00:00:00' : d)
  .toLocaleDateString('es-AR', { day: 'numeric', month: 'long', year: 'numeric' }) : ''

// Qué decir en cada paso. Lo que el paciente ES lo calcula el backend; acá sólo se cuenta.
const panel = computed(() => {
  const s = sit.value
  const p = props.paciente
  const venc = p.reprocann_vencimiento
  if (adherente.value) {
    if (s.reprocann === 'vencido') return { nivel: 'danger', icono: 'bi-calendar-x', titulo: 'REPROCANN vencido', texto: `Venció${venc ? ' el ' + fecha(venc) : ''}. Es adherente: lo renueva su organización.` }
    return { nivel: 'off', icono: 'bi-arrow-left-right', titulo: 'Adherente', texto: 'Su REPROCANN está con otra organización y puede retirar. Cuando se vincule con ustedes, marcalo y el sistema empieza a seguir su REPROCANN.' }
  }
  switch (s.reprocann) {
    case 'pendiente_entrevista':
      return { nivel: 'warn', icono: 'bi-person-badge', titulo: 'Pendiente de entrevista médica',
               texto: 'Todavía no tiene REPROCANN. La médica lo entrevista y, si corresponde, inicia el trámite.' }
    case 'pendiente_aprobacion':
      return { nivel: 'info', icono: 'bi-hourglass-split', titulo: 'Pendiente de aprobación',
               texto: `Trámite iniciado${s.tramite_iniciado_el ? ' el ' + fecha(s.tramite_iniciado_el) : ''}. Falta que lo apruebe el Ministerio: cuando llegue, cargá el número y el vencimiento.` }
    case 'vencido':
      return { nivel: 'danger', icono: 'bi-calendar-x', titulo: 'REPROCANN vencido · pendiente de entrevista',
               texto: `Venció${venc ? ' el ' + fecha(venc) : ''}. Hay que darle entrevista para renovarlo.` }
    case 'activo':
      if (s.vence_en_dias == null) return null
      return { nivel: 'warn', icono: 'bi-alarm', titulo: `Vence en ${s.vence_en_dias} ${s.vence_en_dias === 1 ? 'día' : 'días'} · pendiente de entrevista`,
               texto: `Vence el ${fecha(venc)}. Hay que darle entrevista para renovarlo a tiempo.` }
    case 'no_indicado':
    case 'rechazado':
      return { nivel: s.reprocann === 'rechazado' ? 'danger' : 'off', icono: s.reprocann === 'rechazado' ? 'bi-x-octagon' : 'bi-x-circle',
               titulo: `${REPROCANN_SITUACION[s.reprocann].label}${s.resultado_el ? ' el ' + fecha(s.resultado_el) : ''}`,
               texto: s.reprocann === 'rechazado' ? 'El Ministerio rechazó el trámite. El paciente quedó inactivo: no puede retirar.'
                                                  : 'La médica decidió no pedirlo. El paciente quedó inactivo: no puede retirar.',
               motivo: p.reprocann_resultado_motivo }
    default: return null
  }
})

const extras = computed(() => {
  const s = sit.value
  const out = []
  if (s.proximo_turno_at) {
    const d = new Date(s.proximo_turno_at)
    out.push({ icono: 'bi-calendar-event', texto: `Turno el ${d.toLocaleDateString('es-AR', { weekday: 'long', day: 'numeric', month: 'long' })} a las ${d.toLocaleTimeString('es-AR', { hour: '2-digit', minute: '2-digit', hourCycle: 'h23' })}` })
  }
  if (s.falto_turno_el) out.push({ icono: 'bi-calendar-x', texto: `Faltó al turno del ${fecha(s.falto_turno_el)}` })
  if (s.turno_sin_cerrar) out.push({ icono: 'bi-hourglass', texto: 'Tiene un turno que ya pasó y el médico no cerró' })
  return out
})

// ── Acciones ──
const trabajando = ref(null)
const modal = ref(null) // 'no_indicado' | 'rechazado' | 'cargar_aprobado'
const motivo = ref('')
const numero = ref('')
const vencimiento = ref('')
const errorModal = ref(null)
// Lo que se corrige borra el aviso: si no, queda «contá el motivo» con el motivo ya escrito.
watch([motivo, numero, vencimiento], () => { errorModal.value = null })

async function correr(clave, fn, ok) {
  trabajando.value = clave
  try {
    await fn()
    toast.success(ok)
    modal.value = null
    emit('cambio')
  } catch (e) {
    const msg = e?.response?.data?.error || e?.response?.data?.errors?.join(', ') || 'No se pudo hacer.'
    if (modal.value) errorModal.value = msg
    else toast.error(msg)
  } finally {
    trabajando.value = null
  }
}

async function accion(key) {
  const id = props.paciente.id
  errorModal.value = null
  switch (key) {
    case 'dar_turno': emit('dar-turno'); break
    case 'iniciar_tramite':
      await correr(key, () => iniciarTramiteReprocann(id),
                   props.esAdmin ? 'Trámite iniciado: queda pendiente de aprobación.' : 'Trámite iniciado: administración ya está avisada.')
      break
    case 'no_indicado':
    case 'rechazado':
      motivo.value = ''; modal.value = key; break
    case 'cargar_aprobado':
      numero.value = props.paciente.reprocann_numero || ''; vencimiento.value = ''; modal.value = key; break
    case 'volver_a_entrevistar': {
      const ok = await confirm({
        title: 'Volver a entrevistar', confirmText: 'Volver a entrevistar',
        message: `${props.paciente.nombre} vuelve a estar activo y pendiente de entrevista médica. El motivo anterior queda guardado.`,
      })
      if (ok) await correr(key, () => volverAEntrevistar(id), 'Vuelve a estar activo, pendiente de entrevista.')
      break
    }
    case 'vincular': {
      const ok = await confirm({
        title: 'Se vinculó con la organización', confirmText: 'Pasar a vinculado',
        message: 'Su REPROCANN pasa a estar con ustedes. Desde ahora el sistema sigue su vencimiento y avisa cuando hay que renovarlo.',
      })
      if (ok) await correr(key, () => updatePaciente(id, { reprocann_vinculo: 'organizacion' }), 'Ahora es vinculado.')
      break
    }
  }
}

async function confirmarModal() {
  const id = props.paciente.id
  if (modal.value === 'cargar_aprobado') {
    if (!numero.value.trim() || !vencimiento.value) { errorModal.value = 'Cargá el número y el vencimiento.'; return }
    await correr('cargar_aprobado', () => reprocannAprobado(id, { numero: numero.value.trim(), vencimiento: vencimiento.value }),
                 'REPROCANN aprobado: queda activo.')
    return
  }
  if (!motivo.value.trim()) { errorModal.value = 'Contá el motivo: es lo que se lee al volver a entrevistarlo.'; return }
  const llamada = modal.value === 'rechazado' ? reprocannRechazado : reprocannNoIndicado
  await correr(modal.value, () => llamada(id, motivo.value.trim()),
               modal.value === 'rechazado' ? 'Marcado como rechazado. Quedó inactivo.' : 'Marcado como no indicado. Quedó inactivo.')
}

const hoyISO = new Date().toLocaleDateString('en-CA')
</script>

<template>
  <section v-if="panel || acciones.length" class="pp" :class="`pp--${panel?.nivel || 'off'}`" aria-label="Qué sigue con su REPROCANN">
    <div class="pp__ico"><i class="bi" :class="panel?.icono || 'bi-signpost-2'"></i></div>
    <div class="pp__cuerpo">
      <div class="pp__titulo">{{ panel?.titulo || 'REPROCANN' }}</div>
      <p v-if="panel?.texto" class="pp__texto">{{ panel.texto }}</p>
      <p v-if="panel?.motivo" class="pp__motivo">«{{ panel.motivo }}»</p>
      <ul v-if="extras.length" class="pp__extras">
        <li v-for="x in extras" :key="x.texto"><i class="bi" :class="x.icono"></i> {{ x.texto }}</li>
      </ul>
      <div v-if="acciones.length" class="pp__acciones">
        <button v-for="a in acciones" :key="a" type="button" class="pp__btn" :class="{ 'pp__btn--quiet': ACCIONES[a]?.tono === 'quiet' }"
                :disabled="!!trabajando" @click="accion(a)">
          <DsSpinner v-if="trabajando === a" :size="13" />
          <i v-else class="bi" :class="ACCIONES[a]?.icono"></i>
          {{ ACCIONES[a]?.label || a }}
        </button>
      </div>
    </div>
  </section>

  <Teleport to="body">
    <div v-if="modal" v-modal="() => { if (!trabajando) modal = null }" class="pp-modal__overlay">
      <div class="pp-modal" role="dialog" aria-modal="true" aria-labelledby="pp-modal-t">
        <template v-if="modal === 'cargar_aprobado'">
          <h3 id="pp-modal-t" class="pp-modal__t">Llegó aprobado</h3>
          <p class="pp-modal__d">Con el número y el vencimiento del certificado, {{ paciente.nombre }} queda con el REPROCANN activo.</p>
          <div class="pf-seccion">
            <div class="pf-campo">
              <label class="pf-label" for="pp-num">Número de REPROCANN</label>
              <input id="pp-num" v-model.trim="numero" class="pf-input pf-input--mono" autocomplete="off" autofocus />
            </div>
            <div class="pf-campo">
              <label class="pf-label">Vencimiento</label>
              <AppDatePicker v-model="vencimiento" :min="hoyISO" input-class="pf-input" />
            </div>
          </div>
        </template>
        <template v-else>
          <h3 id="pp-modal-t" class="pp-modal__t">{{ modal === 'rechazado' ? 'El Ministerio lo rechazó' : 'No indicado' }}</h3>
          <p class="pp-modal__d">
            {{ paciente.nombre }} queda <strong>inactivo</strong> y no puede retirar. Para reactivarlo, administración
            lo vuelve a entrevistar.
          </p>
          <div class="pf-campo">
            <label class="pf-label" for="pp-motivo">Motivo</label>
            <textarea id="pp-motivo" v-model="motivo" class="pf-input" rows="3" maxlength="500" autofocus
                      :placeholder="modal === 'rechazado' ? 'Lo que respondió el Ministerio' : 'Por qué no corresponde pedirlo'"></textarea>
            <span class="pf-hint">Queda guardado: es lo que se lee al volver a entrevistarlo.</span>
          </div>
        </template>
        <div v-if="errorModal" class="pf-aviso pf-aviso--danger" style="margin-top:1rem"><i class="bi bi-exclamation-triangle"></i><div>{{ errorModal }}</div></div>
        <div class="pp-modal__acc">
          <button type="button" class="pp-modal__cancel" :disabled="!!trabajando" @click="modal = null">Cancelar</button>
          <button type="button" class="pp-modal__ok" :class="{ 'pp-modal__ok--danger': modal !== 'cargar_aprobado' }"
                  :disabled="!!trabajando" @click="confirmarModal">
            <DsSpinner v-if="trabajando" :size="13" />
            {{ modal === 'cargar_aprobado' ? 'Queda activo' : modal === 'rechazado' ? 'Marcar rechazado' : 'Marcar no indicado' }}
          </button>
        </div>
      </div>
    </div>
  </Teleport>
</template>

<style scoped>
.pp { display: flex; gap: .9rem; padding: 1rem 1.1rem; border-radius: var(--r-lg); border: 1px solid var(--c-slate-200); background: var(--c-paper, #fff); margin-bottom: 1rem; }
.pp--warn   { border-color: var(--c-amber-500); background: color-mix(in srgb, var(--c-amber-100) 45%, var(--c-paper, #fff)); }
.pp--danger { border-color: var(--c-rust-600); background: color-mix(in srgb, var(--c-rust-100) 45%, var(--c-paper, #fff)); }
.pp--info   { border-color: var(--c-sky-600); background: color-mix(in srgb, var(--c-sky-100) 45%, var(--c-paper, #fff)); }
.pp__ico { flex-shrink: 0; width: 38px; height: 38px; border-radius: var(--r-md); display: grid; place-items: center; font-size: 1.1rem; background: var(--c-slate-100); color: var(--c-slate-600); }
.pp--warn .pp__ico   { background: var(--c-amber-100); color: var(--c-slate-900); }
.pp--danger .pp__ico { background: var(--c-rust-100); color: var(--c-rust-600); }
.pp--info .pp__ico   { background: var(--c-sky-100); color: var(--c-sky-600); }
.pp__cuerpo { min-width: 0; flex: 1; }
.pp__titulo { font-weight: 700; color: var(--c-slate-900); font-size: .95rem; }
.pp__texto { margin: .2rem 0 0; font-size: .85rem; color: var(--c-slate-600); line-height: 1.5; }
.pp__motivo { margin: .4rem 0 0; font-size: .85rem; color: var(--c-slate-700); font-style: italic; }
.pp__extras { list-style: none; margin: .5rem 0 0; padding: 0; display: flex; flex-wrap: wrap; gap: .25rem 1rem; font-size: .8rem; font-weight: 600; color: var(--c-slate-700); }
.pp__acciones { display: flex; flex-wrap: wrap; gap: .5rem; margin-top: .8rem; }
.pp__btn { display: inline-flex; align-items: center; gap: .4rem; min-height: 40px; padding: 0 1rem; border-radius: var(--r-md); border: 0;
  background: var(--c-leaf-800); color: #fff; font: inherit; font-size: .85rem; font-weight: 700; cursor: pointer; }
.pp__btn:hover:not(:disabled) { background: var(--c-leaf-900); }
.pp__btn--quiet { background: var(--c-paper, #fff); color: var(--c-slate-700); border: 1px solid var(--c-slate-300); }
.pp__btn--quiet:hover:not(:disabled) { background: var(--c-slate-50); border-color: var(--c-slate-500); }
.pp__btn:disabled { opacity: .55; cursor: not-allowed; }
@media (max-width: 560px) { .pp__acciones .pp__btn { flex: 1 1 auto; justify-content: center; } }

.pp-modal__overlay { position: fixed; inset: 0; z-index: 900; background: rgba(15, 23, 42, .45); display: grid; place-items: center; padding: 1rem; }
.pp-modal { width: 100%; max-width: 420px; background: var(--c-paper, #fff); border-radius: var(--r-xl); padding: 1.5rem; box-shadow: var(--sh-3); }
.pp-modal__t { margin: 0; font-size: 1.1rem; font-weight: 700; color: var(--c-slate-900); }
.pp-modal__d { margin: .35rem 0 1.1rem; font-size: .86rem; color: var(--c-slate-600); line-height: 1.5; }
.pp-modal textarea.pf-input { resize: vertical; min-height: 88px; }
.pp-modal__acc { display: flex; justify-content: flex-end; gap: .6rem; margin-top: 1.25rem; }
.pp-modal__cancel, .pp-modal__ok { display: inline-flex; align-items: center; gap: .4rem; min-height: 44px; padding: 0 1.1rem; border-radius: var(--r-md); font: inherit; font-size: .88rem; font-weight: 700; cursor: pointer; }
.pp-modal__cancel { background: var(--c-paper, #fff); border: 1px solid var(--c-slate-300); color: var(--c-slate-700); }
.pp-modal__ok { background: var(--c-leaf-800); border: 0; color: #fff; }
.pp-modal__ok--danger { background: var(--c-rust-600); }
.pp-modal__ok:disabled, .pp-modal__cancel:disabled { opacity: .55; cursor: not-allowed; }
@media (max-width: 560px) {
  .pp-modal__overlay { align-items: end; padding: 0; }
  .pp-modal { border-radius: var(--r-xl) var(--r-xl) 0 0; padding-bottom: calc(1.5rem + env(safe-area-inset-bottom)); }
  .pp-modal__acc button { flex: 1; justify-content: center; }
}
</style>
