<script setup>
import { ref, watch } from 'vue'
import { useRouter } from 'vue-router'
import { updateMedicoTurno } from '../lib/api.js'
import { useToast } from '../composables/useToast.js'
import DsSpinner from '../design-system/components/Spinner.vue'
import { X, CheckCircle2, XCircle, AlertCircle, Pencil } from 'lucide-vue-next'

const props = defineProps({ turno: { type: Object, required: true } })
const emit  = defineEmits(['close', 'updated'])

const router = useRouter()
const toast  = useToast()

const TIPO_CFG = {
  primera_vez: { label: 'Primera vez', color: '#7c3aed', bg: '#f5f3ff' },
  seguimiento: { label: 'Seguimiento', color: '#1b5e20', bg: '#f0fdf4' },
  revision:    { label: 'Revisión',    color: '#1d4ed8', bg: '#eff6ff' },
  urgencia:    { label: 'Urgencia',    color: '#dc2626', bg: '#fff5f5' },
}
const ESTADO_CFG = {
  programado: { label: 'Programado', cls: 'est--prog' },
  confirmado: { label: 'Confirmado', cls: 'est--conf' },
  realizado:  { label: 'Realizado',  cls: 'est--real' },
  cancelado:  { label: 'Cancelado',  cls: 'est--canc' },
  ausente:    { label: 'Ausente',    cls: 'est--aus'  },
}

const editingNotas    = ref(false)
const notasForm       = ref(props.turno.notas_post || '')
const editingFecha    = ref(false)
const reprogramForm   = ref({ fecha: '', hora: '', duracion_minutos: 30 })
const reprogramSaving = ref(false)

watch(() => props.turno, t => {
  notasForm.value    = t.notas_post || ''
  editingNotas.value = false
  editingFecha.value = false
})

async function cambiarEstado(estado) {
  try {
    const { data } = await updateMedicoTurno(props.turno.id, { estado })
    emit('updated', data)
    toast.success(ESTADO_CFG[estado]?.label)
  } catch { toast.error('No se pudo actualizar') }
}

async function guardarNotas() {
  try {
    const { data } = await updateMedicoTurno(props.turno.id, { notas_post: notasForm.value })
    emit('updated', data)
    editingNotas.value = false
    toast.success('Notas guardadas')
  } catch { toast.error('Error al guardar') }
}

function abrirReprogramar() {
  const d   = new Date(props.turno.fecha_hora)
  const pad = n => String(n).padStart(2, '0')
  reprogramForm.value = {
    fecha:            `${d.getFullYear()}-${pad(d.getMonth()+1)}-${pad(d.getDate())}`,
    hora:             `${pad(d.getHours())}:${pad(d.getMinutes())}`,
    duracion_minutos: props.turno.duracion_minutos,
  }
  editingFecha.value = true
}

async function guardarReprogramacion() {
  reprogramSaving.value = true
  try {
    const fecha_hora = new Date(`${reprogramForm.value.fecha}T${reprogramForm.value.hora}:00`).toISOString()
    const { data } = await updateMedicoTurno(props.turno.id, {
      fecha_hora,
      duracion_minutos: Number(reprogramForm.value.duracion_minutos),
    })
    emit('updated', data)
    editingFecha.value = false
    toast.success('Turno reprogramado')
  } catch { toast.error('No se pudo reprogramar') }
  finally { reprogramSaving.value = false }
}

function fmtHora(fh) {
  return new Date(fh).toLocaleTimeString('es-AR', { hour: '2-digit', minute: '2-digit' })
}
function fmtFechaCompleta(fh) {
  return new Date(fh).toLocaleDateString('es-AR', {
    weekday: 'long', day: 'numeric', month: 'long', year: 'numeric',
  })
}
function fmtHoraFin(fh, mins) {
  const d = new Date(fh)
  d.setMinutes(d.getMinutes() + mins)
  return d.toLocaleTimeString('es-AR', { hour: '2-digit', minute: '2-digit' })
}

function irFicha() {
  emit('close')
  router.push(`/medico/pacientes/${props.turno.paciente_id}/ficha`)
}
</script>

<template>
  <Teleport to="body">
    <div class="tdp__overlay" @click.self="emit('close')">
      <div class="tdp__panel">

        <!-- Header -->
        <div class="tdp__header">
          <div class="tdp__tipo-badge"
            :style="{ background: TIPO_CFG[turno.tipo]?.bg, color: TIPO_CFG[turno.tipo]?.color }">
            {{ TIPO_CFG[turno.tipo]?.label }}
          </div>
          <button class="tdp__close" @click="emit('close')"><X :size="18" /></button>
        </div>

        <!-- Paciente -->
        <div class="tdp__pac">
          <div class="tdp__av">
            {{ (turno.paciente_nombre?.split(' ').map(w => w[0]).join('').slice(0,2) || 'P').toUpperCase() }}
          </div>
          <div class="tdp__pac-info">
            <div class="tdp__pac-nombre">{{ turno.paciente_nombre }}</div>
            <button class="tdp__ficha-link" @click="irFicha">Ver ficha clínica →</button>
          </div>
        </div>

        <!-- Info -->
        <div class="tdp__info-grid">
          <div class="tdp__item">
            <span class="tdp__lbl">Fecha</span>
            <span class="tdp__val">{{ fmtFechaCompleta(turno.fecha_hora) }}</span>
          </div>
          <div class="tdp__item">
            <span class="tdp__lbl">Horario</span>
            <span class="tdp__val">
              {{ fmtHora(turno.fecha_hora) }} – {{ fmtHoraFin(turno.fecha_hora, turno.duracion_minutos) }}
              <span class="tdp__dur">({{ turno.duracion_minutos }} min)</span>
            </span>
          </div>
          <div class="tdp__item">
            <span class="tdp__lbl">Estado</span>
            <span class="tdp__estado-badge" :class="ESTADO_CFG[turno.estado]?.cls">
              {{ ESTADO_CFG[turno.estado]?.label }}
            </span>
          </div>
          <div v-if="turno.motivo" class="tdp__item tdp__item--full">
            <span class="tdp__lbl">Motivo</span>
            <span class="tdp__val tdp__val--text">{{ turno.motivo }}</span>
          </div>
        </div>

        <!-- Acciones de estado -->
        <div class="tdp__acciones">
          <button v-if="turno.estado === 'programado'" class="tdp__accion tdp__accion--ok"
            @click="cambiarEstado('confirmado')">
            <CheckCircle2 :size="14" /> Confirmar
          </button>
          <button v-if="['programado','confirmado'].includes(turno.estado)" class="tdp__accion tdp__accion--primary"
            @click="cambiarEstado('realizado')">
            <CheckCircle2 :size="14" /> Marcar realizado
          </button>
          <button v-if="['programado','confirmado'].includes(turno.estado)" class="tdp__accion tdp__accion--warn"
            @click="cambiarEstado('ausente')">
            <AlertCircle :size="14" /> Ausente
          </button>
          <button v-if="!['cancelado','realizado'].includes(turno.estado)" class="tdp__accion tdp__accion--reprog"
            @click="abrirReprogramar">
            <Pencil :size="14" /> Reprogramar
          </button>
          <button v-if="!['cancelado','realizado'].includes(turno.estado)" class="tdp__accion tdp__accion--danger"
            @click="cambiarEstado('cancelado')">
            <XCircle :size="14" /> Cancelar
          </button>
        </div>

        <!-- Form reprogramar -->
        <div v-if="editingFecha" class="tdp__reprog-form">
          <div class="tdp__reprog-title">Reprogramar turno</div>
          <div class="tdp__reprog-fields">
            <div class="tdp__reprog-field">
              <label class="tdp__lbl">Fecha</label>
              <input v-model="reprogramForm.fecha" type="date" class="tdp__input"
                :min="new Date().toISOString().split('T')[0]" />
            </div>
            <div class="tdp__reprog-field">
              <label class="tdp__lbl">Hora</label>
              <input v-model="reprogramForm.hora" type="time" class="tdp__input" step="900" />
            </div>
            <div class="tdp__reprog-field">
              <label class="tdp__lbl">Duración</label>
              <select v-model.number="reprogramForm.duracion_minutos" class="tdp__input">
                <option :value="15">15 min</option>
                <option :value="30">30 min</option>
                <option :value="45">45 min</option>
                <option :value="60">1 hora</option>
                <option :value="90">1:30 h</option>
              </select>
            </div>
          </div>
          <div class="tdp__row-btns">
            <button class="tdp__btn-ghost tdp__btn-xs" @click="editingFecha = false">Cancelar</button>
            <button class="tdp__btn-primary tdp__btn-xs" :disabled="reprogramSaving" @click="guardarReprogramacion">
              <DsSpinner v-if="reprogramSaving" :size="12" /> Confirmar
            </button>
          </div>
        </div>

        <!-- Notas post-consulta -->
        <div class="tdp__notas">
          <div class="tdp__notas-header">
            <span class="tdp__lbl">Notas de la consulta</span>
            <button v-if="!editingNotas" class="tdp__notas-edit" @click="editingNotas = true">
              <Pencil :size="13" /> Editar
            </button>
          </div>
          <template v-if="editingNotas">
            <textarea v-model="notasForm" class="tdp__input tdp__textarea" rows="4"
              placeholder="Observaciones, diagnóstico, indicaciones…"></textarea>
            <div class="tdp__row-btns">
              <button class="tdp__btn-ghost tdp__btn-xs" @click="editingNotas = false">Cancelar</button>
              <button class="tdp__btn-primary tdp__btn-xs" @click="guardarNotas">Guardar</button>
            </div>
          </template>
          <p v-else-if="turno.notas_post" class="tdp__notas-text">{{ turno.notas_post }}</p>
          <p v-else class="tdp__notas-empty">Sin notas. Hacé click en Editar para agregar.</p>
        </div>

      </div>
    </div>
  </Teleport>
</template>

<style scoped>
.tdp__overlay {
  position: fixed; inset: 0; background: rgba(0,0,0,.3); z-index: 900;
  display: flex; justify-content: flex-end;
  animation: tdp-fade-in .18s ease;
}
@keyframes tdp-fade-in { from { opacity: 0 } to { opacity: 1 } }

.tdp__panel {
  width: 380px; max-width: 95vw; height: 100%; background: #fff;
  box-shadow: -4px 0 24px rgba(0,0,0,.15);
  overflow-y: auto; display: flex; flex-direction: column;
  animation: tdp-slide-in .22s cubic-bezier(.4,0,.2,1);
}
@keyframes tdp-slide-in { from { transform: translateX(100%) } to { transform: translateX(0) } }

.tdp__header {
  display: flex; align-items: center; justify-content: space-between;
  padding: .9rem 1.1rem; border-bottom: 1px solid #f1f5f9;
  position: sticky; top: 0; background: #fff; z-index: 2;
}
.tdp__tipo-badge {
  font-size: .72rem; font-weight: 800; padding: .25em .75em;
  border-radius: 999px; text-transform: uppercase; letter-spacing: .05em;
}
.tdp__close {
  background: none; border: none; cursor: pointer; color: #94a3b8;
  display: flex; align-items: center; padding: .25rem; border-radius: 6px;
  transition: color .12s;
}
.tdp__close:hover { color: #1e293b; }

.tdp__pac {
  display: flex; align-items: center; gap: .75rem;
  padding: 1rem 1.1rem; border-bottom: 1px solid #f1f5f9;
}
.tdp__av {
  width: 44px; height: 44px; border-radius: 50%; flex-shrink: 0;
  background: linear-gradient(135deg, #1b5e20, #2e7d32);
  color: #fff; font-size: .8rem; font-weight: 800;
  display: flex; align-items: center; justify-content: center;
}
.tdp__pac-info { display: flex; flex-direction: column; gap: .15rem; }
.tdp__pac-nombre { font-size: .9rem; font-weight: 800; color: #0f172a; }
.tdp__ficha-link {
  font-size: .75rem; font-weight: 600; color: #1b5e20; background: none; border: none;
  cursor: pointer; padding: 0; text-decoration: underline; text-underline-offset: 2px;
}
.tdp__ficha-link:hover { color: #14532d; }

.tdp__info-grid {
  display: flex; flex-direction: column; gap: .65rem;
  padding: 1rem 1.1rem; border-bottom: 1px solid #f1f5f9;
}
.tdp__item { display: flex; flex-direction: column; gap: .15rem; }
.tdp__lbl { font-size: .65rem; font-weight: 800; color: #94a3b8; text-transform: uppercase; letter-spacing: .05em; }
.tdp__val { font-size: .82rem; color: #1e293b; font-weight: 500; }
.tdp__val--text { white-space: pre-wrap; color: #475569; font-weight: 400; line-height: 1.5; }
.tdp__dur { font-size: .72rem; color: #94a3b8; margin-left: .25rem; }

.tdp__estado-badge {
  display: inline-block; font-size: .7rem; font-weight: 700;
  padding: .2em .7em; border-radius: 999px; text-transform: uppercase; letter-spacing: .04em;
}
.est--prog { background: #f1f5f9; color: #475569; }
.est--conf { background: #dcfce7; color: #166534; }
.est--real { background: #d1fae5; color: #065f46; }
.est--canc { background: #fee2e2; color: #991b1b; }
.est--aus  { background: #fef3c7; color: #92400e; }

.tdp__acciones {
  display: flex; flex-wrap: wrap; gap: .5rem;
  padding: .9rem 1.1rem; border-bottom: 1px solid #f1f5f9;
}
.tdp__accion {
  display: inline-flex; align-items: center; gap: .35rem;
  padding: .4rem .8rem; border-radius: 8px; font-size: .78rem; font-weight: 700;
  cursor: pointer; border: 1.5px solid; transition: all .15s;
}
.tdp__accion--ok      { background: #f0fdf4; color: #166534; border-color: #bbf7d0; }
.tdp__accion--ok:hover { background: #dcfce7; }
.tdp__accion--primary { background: #f0fdf4; color: #1b5e20; border-color: #1b5e20; }
.tdp__accion--primary:hover { background: #1b5e20; color: #fff; }
.tdp__accion--warn    { background: #fefce8; color: #92400e; border-color: #fde68a; }
.tdp__accion--warn:hover { background: #fef3c7; }
.tdp__accion--danger  { background: #fff5f5; color: #dc2626; border-color: #fecaca; }
.tdp__accion--danger:hover { background: #fee2e2; }
.tdp__accion--reprog  { background: #eff6ff; color: #1d4ed8; border-color: #bfdbfe; }
.tdp__accion--reprog:hover { background: #dbeafe; }

.tdp__reprog-form {
  margin: 0 .9rem .9rem;
  background: #f0f9ff; border: 1.5px solid #bae6fd; border-radius: 10px;
  padding: .8rem .9rem; display: flex; flex-direction: column; gap: .6rem;
}
.tdp__reprog-title { font-size: .75rem; font-weight: 700; color: #0369a1; }
.tdp__reprog-fields { display: flex; flex-direction: column; gap: .4rem; }
.tdp__reprog-field { display: flex; flex-direction: column; gap: .2rem; }

.tdp__notas { padding: .9rem 1.1rem; flex: 1; }
.tdp__notas-header { display: flex; align-items: center; justify-content: space-between; margin-bottom: .5rem; }
.tdp__notas-edit {
  display: flex; align-items: center; gap: .3rem; font-size: .72rem; font-weight: 600;
  color: #64748b; background: none; border: 1px solid #e2e8f0; border-radius: 6px;
  padding: .15rem .5rem; cursor: pointer; transition: all .12s;
}
.tdp__notas-edit:hover { color: #1b5e20; border-color: #1b5e20; }
.tdp__row-btns { display: flex; gap: .5rem; margin-top: .5rem; }
.tdp__notas-text  { font-size: .82rem; color: #475569; white-space: pre-wrap; line-height: 1.6; margin: 0; }
.tdp__notas-empty { font-size: .8rem; color: #94a3b8; font-style: italic; margin: 0; }

.tdp__input {
  width: 100%; padding: .45rem .7rem; border: 1.5px solid #e2e8f0; border-radius: 8px;
  font-size: .82rem; color: #1e293b; background: #fff; outline: none;
  transition: border-color .15s;
}
.tdp__input:focus { border-color: #1b5e20; }
.tdp__textarea { resize: vertical; min-height: 80px; font-family: inherit; line-height: 1.5; }

.tdp__btn-primary {
  display: inline-flex; align-items: center; gap: .3rem;
  background: #1b5e20; color: #fff; border: none; border-radius: 7px;
  padding: .35rem .85rem; font-size: .78rem; font-weight: 700; cursor: pointer;
  transition: background .15s;
}
.tdp__btn-primary:hover:not(:disabled) { background: #14532d; }
.tdp__btn-primary:disabled { opacity: .6; cursor: not-allowed; }
.tdp__btn-ghost {
  background: none; border: 1px solid #e2e8f0; color: #64748b; border-radius: 7px;
  padding: .35rem .85rem; font-size: .78rem; font-weight: 600; cursor: pointer;
  transition: all .12s;
}
.tdp__btn-ghost:hover { background: #f8fafc; }
.tdp__btn-xs { padding: .3rem .7rem !important; font-size: .73rem !important; }
</style>
