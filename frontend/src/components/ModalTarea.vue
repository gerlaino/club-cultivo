<template>
  <Teleport to="body">
    <div v-if="show" class="mt-overlay" @click.self="$emit('cerrar')">
      <div class="mt-panel">

        <!-- Header -->
        <div class="mt-header">
          <div class="mt-header-left">
            <div class="mt-header-icon" :style="{ background: tipoActual.bg }">
              <span>{{ tipoActual.emoji }}</span>
            </div>
            <div>
              <h2 class="mt-title">{{ editando ? 'Editar tarea' : 'Nueva tarea' }}</h2>
              <p class="mt-subtitle">
                <span v-if="sedeSeleccionada">{{ sedeSeleccionada.nombre }}</span>
                <span v-if="sedeSeleccionada && salaSeleccionada"> · {{ salaSeleccionada.nombre }}</span>
                <span v-if="!sedeSeleccionada">Completá los datos de la tarea</span>
              </p>
            </div>
          </div>
          <button class="mt-close" @click="$emit('cerrar')">
            <i class="bi bi-x-lg"></i>
          </button>
        </div>

        <div class="mt-body">

          <!-- ── Tipo ── -->
          <div class="mt-field">
            <label class="mt-label">Tipo de tarea</label>
            <div class="mt-tipos">
              <button v-for="t in TIPOS" :key="t.value" type="button"
                      class="mt-tipo" :class="{ 'mt-tipo--active': form.tipo === t.value }"
                      :style="form.tipo === t.value ? { background: t.bg, borderColor: '#1b5e20', color: '#1b5e20' } : {}"
                      @click="form.tipo = t.value">
                <span class="mt-tipo-emoji">{{ t.emoji }}</span>
                <span class="mt-tipo-label">{{ t.label }}</span>
              </button>
            </div>
          </div>

          <!-- ── Descripción ── -->
          <div class="mt-field">
            <label class="mt-label">Descripción <span class="mt-opt">opcional</span></label>
            <textarea v-model="form.descripcion" class="mt-input mt-textarea" rows="2"
                      placeholder="Instrucciones adicionales, observaciones…"></textarea>
          </div>

          <!-- ── Prioridad ── -->
          <div class="mt-field">
            <label class="mt-label">Prioridad</label>
            <div class="mt-prioridades">
              <button v-for="p in PRIORIDADES" :key="p.value" type="button"
                      class="mt-prioridad" :class="{ 'mt-prioridad--active': form.prioridad === p.value }"
                      :style="form.prioridad === p.value ? { background: p.bg, borderColor: p.color, color: p.color } : {}"
                      @click="form.prioridad = p.value">
                <span>{{ p.dot }}</span><span>{{ p.label }}</span>
              </button>
            </div>
          </div>

          <!-- ── Fecha y horas ── -->
          <div class="mt-row">
            <div class="mt-field">
              <label class="mt-label">Fecha</label>
              <input v-model="form.fecha_programada" type="date" class="mt-input" />
            </div>
            <div class="mt-field">
              <label class="mt-label">Horas estimadas</label>
              <div class="mt-input-group">
                <input v-model.number="form.horas_estimadas" type="number" class="mt-input"
                       min="0.25" max="24" step="0.25" placeholder="0.0" />
                <span class="mt-input-suffix">hs</span>
              </div>
            </div>
          </div>

          <!-- ── Repetición ── -->
          <div class="mt-field">
            <label class="mt-label">Repetición <span class="mt-opt">opcional</span></label>
            <label class="mt-toggle">
              <input type="checkbox" v-model="conRepeticion" class="mt-toggle-chk" />
              <div class="mt-toggle-track"><div class="mt-toggle-thumb"></div></div>
              <span class="mt-toggle-label">Repetir esta tarea</span>
            </label>
            <div v-if="conRepeticion" class="mt-repeticion">
              <div class="mt-row mt-row--3">
                <div class="mt-field">
                  <label class="mt-label-sm">Frecuencia</label>
                  <select v-model="repeticion.frecuencia" class="mt-input mt-input--sm">
                    <option value="diaria">Diaria</option>
                    <option value="semanal">Semanal</option>
                    <option value="quincenal">Quincenal</option>
                    <option value="mensual">Mensual</option>
                  </select>
                </div>
                <div class="mt-field">
                  <label class="mt-label-sm">Veces</label>
                  <input v-model.number="repeticion.veces" type="number" min="2" max="52"
                         class="mt-input mt-input--sm" placeholder="4" />
                </div>
                <div class="mt-field">
                  <label class="mt-label-sm">Hasta</label>
                  <input v-model="repeticion.hasta" type="date" class="mt-input mt-input--sm" />
                </div>
              </div>
              <div v-if="fechasGeneradas.length > 0" class="mt-fechas-preview">
                <span class="mt-fechas-label">Se crearán {{ fechasGeneradas.length }} tareas:</span>
                <div class="mt-fechas-chips">
                  <span v-for="(f, i) in fechasGeneradas.slice(0, 6)" :key="i" class="mt-fecha-chip">
                    {{ formatFechaCorta(f) }}
                  </span>
                  <span v-if="fechasGeneradas.length > 6" class="mt-fecha-chip mt-fecha-chip--more">
                    +{{ fechasGeneradas.length - 6 }} más
                  </span>
                </div>
              </div>
            </div>
          </div>

          <!-- ── Divider ── -->
          <div class="mt-divider">
            <span>Ubicación</span>
          </div>

          <!-- ── Sede ── -->
          <div class="mt-field">
            <label class="mt-label">Sede <span class="mt-opt">opcional</span></label>
            <select v-model="form.sede_id" class="mt-input" @change="onChangeSede">
              <option value="">Sin sede específica</option>
              <option v-for="s in sedes" :key="s.id" :value="s.id">
                {{ s.nombre }} — {{ s.tipo }}
              </option>
            </select>
          </div>

          <!-- ── Sala (solo si la sede tiene salas) ── -->
          <template v-if="form.sede_id && sedeSeleccionada && !esSedeSocial">
            <div class="mt-field">
              <label class="mt-label">Sala</label>
              <select v-model="form.sala_id" class="mt-input" @change="form.lote_id = ''">
                <option value="">Sin sala específica</option>
                <option v-for="s in salasDeLaSede" :key="s.id" :value="s.id">
                  {{ s.nombre }}
                </option>
              </select>
              <span v-if="salasDeLaSede.length === 0" class="mt-hint">
                Esta sede no tiene salas registradas todavía.
              </span>
            </div>

            <!-- ── Lote (solo si hay sala seleccionada) ── -->
            <div v-if="form.sala_id" class="mt-field">
              <label class="mt-label">Lote <span class="mt-opt">opcional</span></label>
              <select v-model="form.lote_id" class="mt-input">
                <option value="">Sin lote específico</option>
                <option v-for="l in lotesDeLaSala" :key="l.id" :value="l.id">
                  {{ l.codigo }} — {{ l.estado }}
                </option>
              </select>
              <span v-if="lotesDeLaSala.length === 0" class="mt-hint">
                Esta sala no tiene lotes activos.
              </span>
            </div>
          </template>

          <!-- Aviso sede social -->
          <div v-if="form.sede_id && esSedeSocial" class="mt-info-box">
            <i class="bi bi-info-circle-fill"></i>
            Sede de tipo social — no tiene salas ni lotes de cultivo.
          </div>

          <!-- ── Asignar a ── -->
          <div v-if="puedeAsignar" class="mt-field">
            <div class="mt-divider"><span>Asignación</span></div>
            <label class="mt-label" style="margin-top:.75rem">Asignar a</label>
            <div class="mt-usuarios">
              <div v-for="u in usuarios" :key="u.id"
                   class="mt-usuario"
                   :class="{ 'mt-usuario--active': String(form.asignada_a_id) === String(u.id) }"
                   @click="form.asignada_a_id = form.asignada_a_id == u.id ? '' : u.id">
                <div class="mt-usuario-avatar" :style="{ background: avatarColor(u.id) }">
                  {{ ((u.first_name?.[0] || '') + (u.last_name?.[0] || '')).toUpperCase() }}
                </div>
                <div class="mt-usuario-info">
                  <div class="mt-usuario-nombre">{{ `${u.first_name} ${u.last_name}`.trim() }}</div>
                  <div class="mt-usuario-rol">{{ u.role }}</div>
                </div>
                <div v-if="String(form.asignada_a_id) === String(u.id)" class="mt-usuario-check">
                  <i class="bi bi-check-lg"></i>
                </div>
              </div>
              <div v-if="!usuarios.length" class="mt-hint">Sin usuarios disponibles.</div>
            </div>
          </div>

          <!-- ── Error ── -->
          <div v-if="errorGlobal" class="mt-error">
            <i class="bi bi-exclamation-triangle-fill"></i> {{ errorGlobal }}
          </div>

        </div>

        <!-- Footer -->
        <div class="mt-footer">
          <button class="mt-btn-ghost" @click="$emit('cerrar')">Cancelar</button>
          <button class="mt-btn-primary" @click="guardar" :disabled="guardando">
            <span v-if="guardando" class="mt-spinner"></span>
            <i v-else class="bi bi-check-lg"></i>
            {{ editando ? 'Guardar cambios' : conRepeticion ? `Crear ${fechasGeneradas.length || 1} tareas` : 'Crear tarea' }}
          </button>
        </div>

      </div>
    </div>
  </Teleport>
</template>

<script setup>
import { ref, computed, watch } from 'vue'
import { useAuthStore } from '../stores/auth'
import { useTareasStore } from '../stores/tareas'

const props = defineProps({
  show:         { type: Boolean, default: false },
  tareaInicial: { type: Object,  default: null },
  salas:        { type: Array,   default: () => [] },
  sedes:        { type: Array,   default: () => [] },
  lotes:        { type: Array,   default: () => [] },
  usuarios:     { type: Array,   default: () => [] },
})
const emit = defineEmits(['guardada', 'cerrar'])

const authStore   = useAuthStore()
const tareasStore = useTareasStore()
const guardando   = ref(false)
const errorGlobal = ref('')
const conRepeticion = ref(false)
const repeticion  = ref({ frecuencia: 'semanal', veces: 4, hasta: '' })

const TIPOS = [
  { value: 'riego',       label: 'Riego',      emoji: '💧', bg: '#e8f5e9' },
  { value: 'poda',        label: 'Poda',       emoji: '✂️', bg: '#f3e5f5' },
  { value: 'medicion',    label: 'Medición',   emoji: '📏', bg: '#e0f7fa' },
  { value: 'limpieza',    label: 'Limpieza',   emoji: '🧹', bg: '#e8f5e9' },
  { value: 'cosecha',     label: 'Cosecha',    emoji: '🌿', bg: '#dcedc8' },
  { value: 'transplante', label: 'Trasplante', emoji: '🪴', bg: '#fff8e1' },
  { value: 'inspeccion',  label: 'Inspección', emoji: '🔍', bg: '#fff3e0' },
  { value: 'otro',        label: 'Otro',       emoji: '📋', bg: '#f1f8e9' },
]
const PRIORIDADES = [
  { value: 'baja',    label: 'Baja',    dot: '🟢', color: '#15803d', bg: '#f0fdf4' },
  { value: 'normal',  label: 'Normal',  dot: '🔵', color: '#0369a1', bg: '#eff6ff' },
  { value: 'alta',    label: 'Alta',    dot: '🟠', color: '#d97706', bg: '#fffbeb' },
  { value: 'urgente', label: 'Urgente', dot: '🔴', color: '#dc2626', bg: '#fef2f2' },
]
const AVATAR_COLORS = ['#1b5e20','#0369a1','#7c3aed','#b45309','#0891b2','#dc2626']
function avatarColor(id) { return AVATAR_COLORS[(id || 0) % AVATAR_COLORS.length] }

const editando     = computed(() => !!props.tareaInicial?.id)
const puedeAsignar = computed(() => ['admin', 'agricultor'].includes(authStore.user?.role))
const tipoActual   = computed(() => TIPOS.find(t => t.value === form.value.tipo) || TIPOS[0])

const sedeSeleccionada = computed(() =>
  props.sedes.find(s => String(s.id) === String(form.value.sede_id)) || null
)
const esSedeSocial = computed(() =>
  sedeSeleccionada.value?.tipo === 'social'
)
const salasDeLaSede = computed(() =>
  props.salas.filter(s => String(s.sede_id || s.sede?.id) === String(form.value.sede_id))
)
const lotesDeLaSala = computed(() =>
  props.lotes.filter(l => String(l.sala_id) === String(form.value.sala_id))
)
const salaSeleccionada = computed(() =>
  props.salas.find(s => String(s.id) === String(form.value.sala_id)) || null
)

function onChangeSede() {
  form.value.sala_id = ''
  form.value.lote_id = ''
}

const fechasGeneradas = computed(() => {
  if (!conRepeticion.value || !form.value.fecha_programada) return []
  const fechas = []
  const inicio = new Date(form.value.fecha_programada)
  const DIAS   = { diaria: 1, semanal: 7, quincenal: 15, mensual: 30 }
  const paso   = DIAS[repeticion.value.frecuencia] || 7
  const hasta  = repeticion.value.hasta ? new Date(repeticion.value.hasta) : null
  const maxV   = repeticion.value.veces || 4
  for (let i = 0; i < maxV; i++) {
    const f = new Date(inicio)
    f.setDate(f.getDate() + i * paso)
    if (hasta && f > hasta) break
    fechas.push(f.toISOString().split('T')[0])
  }
  return fechas
})

function formatFechaCorta(d) {
  return new Date(d).toLocaleDateString('es-AR', { day: 'numeric', month: 'short' })
}

function formVacio() {
  return {
    titulo: '', descripcion: '', tipo: 'riego', prioridad: 'normal',
    asignada_a_id: '', sede_id: '', sala_id: '', lote_id: '',
    fecha_programada: new Date().toISOString().split('T')[0],
    horas_estimadas: null,
  }
}
const form = ref(formVacio())

watch(() => props.show, (val) => {
  if (!val) return
  errorGlobal.value = ''
  conRepeticion.value = false
  repeticion.value = { frecuencia: 'semanal', veces: 4, hasta: '' }
  if (props.tareaInicial) {
    const t = props.tareaInicial
    // Inferir sede desde la sala
    const sala = props.salas.find(s => s.id == (t.sala_id || t.sala?.id))
    const sedeId = sala?.sede_id || sala?.sede?.id || ''
    form.value = {
      titulo:           t.titulo || '',
      descripcion:      t.descripcion || '',
      tipo:             t.tipo || 'riego',
      prioridad:        t.prioridad || 'normal',
      asignada_a_id:    t.asignada_a?.id || '',
      sede_id:          sedeId,
      sala_id:          t.sala_id || t.sala?.id || '',
      lote_id:          t.lote_id || t.lote?.id || '',
      fecha_programada: t.fecha_programada || new Date().toISOString().split('T')[0],
      horas_estimadas:  t.horas_estimadas || null,
    }
  } else {
    form.value = formVacio()
  }
})

async function guardar() {
  errorGlobal.value = ''
  const tipoLabel  = TIPOS.find(t => t.value === form.value.tipo)?.label || 'Tarea'
  const salaNombre = salaSeleccionada.value?.nombre || ''
  const payload = {
    ...form.value,
    titulo:          form.value.titulo?.trim() || (tipoLabel + (salaNombre ? ` — ${salaNombre}` : '')),
    asignada_a_id:   form.value.asignada_a_id || null,
    sala_id:         form.value.sala_id || null,
    lote_id:         form.value.lote_id || null,
    horas_estimadas: form.value.horas_estimadas || null,
  }
  // No enviar sede_id al backend (no es un campo de la tarea)
  delete payload.sede_id

  guardando.value = true
  try {
    if (editando.value) {
      const res = await tareasStore.update(props.tareaInicial.id, payload)
      emit('guardada', res)
    } else if (conRepeticion.value && fechasGeneradas.value.length > 1) {
      for (const fecha of fechasGeneradas.value) {
        await tareasStore.create({ ...payload, fecha_programada: fecha })
      }
      emit('guardada', null)
    } else {
      const res = await tareasStore.create(payload)
      emit('guardada', res)
    }
  } catch (e) {
    const msgs = e.response?.data?.errors
    errorGlobal.value = msgs ? msgs.join(', ') : (e.response?.data?.error || 'Error al guardar')
  } finally {
    guardando.value = false
  }
}
</script>

<style scoped>
.mt-overlay { position: fixed; inset: 0; background: rgba(0,0,0,.4); display: flex; align-items: center; justify-content: center; z-index: 2000; padding: 1rem; backdrop-filter: blur(3px); }
.mt-panel { background: #fff; border-radius: 18px; width: 100%; max-width: 560px; max-height: 92vh; overflow-y: auto; box-shadow: 0 24px 60px rgba(27,94,32,.18); display: flex; flex-direction: column; }

/* Header */
.mt-header { display: flex; align-items: center; justify-content: space-between; padding: 1.25rem 1.5rem; border-bottom: 1px solid #e8f0e9; position: sticky; top: 0; background: #fff; z-index: 1; border-radius: 18px 18px 0 0; }
.mt-header-left { display: flex; align-items: center; gap: .85rem; }
.mt-header-icon { width: 44px; height: 44px; border-radius: 12px; display: flex; align-items: center; justify-content: center; font-size: 1.3rem; flex-shrink: 0; transition: background .2s; }
.mt-title { font-size: 1.05rem; font-weight: 700; color: #1a1a1a; margin: 0; }
.mt-subtitle { font-size: .72rem; color: #60725d; margin: .1rem 0 0; }
.mt-close { background: #e8f0e9; border: none; width: 32px; height: 32px; border-radius: 8px; cursor: pointer; display: flex; align-items: center; justify-content: center; color: #60725d; font-size: .8rem; }
.mt-close:hover { background: #c8e6c9; color: #1b5e20; }

/* Body */
.mt-body { padding: 1.25rem 1.5rem; display: flex; flex-direction: column; gap: 1.1rem; flex: 1; }

/* Fields */
.mt-field { display: flex; flex-direction: column; gap: .4rem; }
.mt-label { font-size: .72rem; font-weight: 700; color: #60725d; text-transform: uppercase; letter-spacing: .05em; }
.mt-label-sm { font-size: .72rem; font-weight: 600; color: #60725d; }
.mt-opt { font-size: .68rem; font-weight: 400; color: #94a3b8; text-transform: none; letter-spacing: 0; }
.mt-hint { font-size: .72rem; color: #94a3b8; margin-top: .2rem; }
.mt-row { display: grid; grid-template-columns: 1fr 1fr; gap: .85rem; }
.mt-row--3 { grid-template-columns: 1fr 80px 1fr; }
@media (max-width: 480px) { .mt-row { grid-template-columns: 1fr; } .mt-row--3 { grid-template-columns: 1fr 1fr; } }

/* Inputs */
.mt-input { background: #f4f8f4; border: 1.5px solid #d4e6d4; border-radius: 10px; padding: .65rem .9rem; font-size: .875rem; color: #1a1a1a; width: 100%; box-sizing: border-box; transition: border .15s, background .15s; outline: none; }
.mt-input:focus { border-color: #1b5e20; background: #fff; }
.mt-input--sm { padding: .5rem .75rem; font-size: .8rem; border-radius: 8px; }
.mt-textarea { resize: vertical; min-height: 64px; }
.mt-input-group { display: flex; }
.mt-input-group .mt-input { border-radius: 10px 0 0 10px; }
.mt-input-suffix { background: #e8f0e9; border: 1.5px solid #d4e6d4; border-left: none; padding: .65rem .85rem; font-size: .8rem; font-weight: 600; color: #60725d; border-radius: 0 10px 10px 0; white-space: nowrap; }

/* Tipo */
.mt-tipos { display: grid; grid-template-columns: repeat(4, 1fr); gap: .5rem; }
@media (max-width: 440px) { .mt-tipos { grid-template-columns: repeat(2, 1fr); } }
.mt-tipo { display: flex; flex-direction: column; align-items: center; gap: .3rem; padding: .65rem .4rem; background: #f4f8f4; border: 1.5px solid #d4e6d4; border-radius: 10px; cursor: pointer; transition: all .15s; }
.mt-tipo:hover { border-color: #66bb6a; background: #e8f5e9; }
.mt-tipo--active { transform: translateY(-1px); box-shadow: 0 2px 8px rgba(27,94,32,.12); }
.mt-tipo-emoji { font-size: 1.2rem; }
.mt-tipo-label { font-size: .67rem; font-weight: 600; text-align: center; color: #1a1a1a; }

/* Prioridad */
.mt-prioridades { display: flex; gap: .5rem; flex-wrap: wrap; }
.mt-prioridad { display: flex; align-items: center; gap: .35rem; padding: .45rem .85rem; border: 1.5px solid #d4e6d4; border-radius: 999px; background: #f4f8f4; font-size: .78rem; font-weight: 600; cursor: pointer; transition: all .15s; }
.mt-prioridad:hover { border-color: #66bb6a; }
.mt-prioridad--active { transform: translateY(-1px); box-shadow: 0 2px 8px rgba(27,94,32,.1); }

/* Divider */
.mt-divider { display: flex; align-items: center; gap: .75rem; margin: .25rem 0; }
.mt-divider::before, .mt-divider::after { content: ''; flex: 1; height: 1px; background: #e8f0e9; }
.mt-divider span { font-size: .67rem; font-weight: 700; color: #94a3b8; text-transform: uppercase; letter-spacing: .07em; white-space: nowrap; }

/* Info box sede social */
.mt-info-box { display: flex; align-items: center; gap: .6rem; background: #eff6ff; border: 1px solid #bfdbfe; color: #1e40af; padding: .75rem 1rem; border-radius: 10px; font-size: .82rem; }
.mt-info-box i { font-size: 1rem; flex-shrink: 0; }

/* Usuarios */
.mt-usuarios { display: flex; flex-direction: column; gap: .4rem; }
.mt-usuario { display: flex; align-items: center; gap: .75rem; padding: .65rem .875rem; border: 1.5px solid #e2e8f0; border-radius: 10px; cursor: pointer; transition: all .15s; background: #fafbfc; }
.mt-usuario:hover { border-color: #d4e6d4; background: #f0fdf4; }
.mt-usuario--active { border-color: #1b5e20; background: #f0fdf4; }
.mt-usuario-avatar { width: 36px; height: 36px; border-radius: 9px; display: flex; align-items: center; justify-content: center; color: #fff; font-size: .75rem; font-weight: 800; flex-shrink: 0; }
.mt-usuario-info { flex: 1; min-width: 0; }
.mt-usuario-nombre { font-size: .82rem; font-weight: 600; color: #0f172a; }
.mt-usuario-rol { font-size: .7rem; color: #64748b; text-transform: capitalize; }
.mt-usuario-check { width: 22px; height: 22px; border-radius: 50%; background: #1b5e20; color: #fff; display: flex; align-items: center; justify-content: center; font-size: .7rem; flex-shrink: 0; }

/* Toggle */
.mt-toggle { display: flex; align-items: center; gap: .65rem; cursor: pointer; }
.mt-toggle-chk { display: none; }
.mt-toggle-track { width: 38px; height: 21px; background: #d4e6d4; border-radius: 999px; position: relative; transition: background .2s; flex-shrink: 0; }
.mt-toggle-chk:checked + .mt-toggle-track { background: #1b5e20; }
.mt-toggle-thumb { position: absolute; width: 15px; height: 15px; background: #fff; border-radius: 50%; top: 3px; left: 3px; transition: left .2s; box-shadow: 0 1px 3px rgba(0,0,0,.2); }
.mt-toggle-chk:checked + .mt-toggle-track .mt-toggle-thumb { left: 20px; }
.mt-toggle-label { font-size: .875rem; font-weight: 500; color: #1a1a1a; }

/* Repetición */
.mt-repeticion { background: #f4f8f4; border: 1.5px solid #d4e6d4; border-radius: 12px; padding: 1rem; margin-top: .5rem; display: flex; flex-direction: column; gap: .75rem; }
.mt-fechas-preview { }
.mt-fechas-label { font-size: .72rem; color: #60725d; font-weight: 600; display: block; margin-bottom: .4rem; }
.mt-fechas-chips { display: flex; flex-wrap: wrap; gap: .35rem; }
.mt-fecha-chip { font-size: .7rem; font-weight: 600; color: #1b5e20; background: #e8f5e9; border: 1px solid #c8e6c9; padding: .2em .6em; border-radius: 6px; }
.mt-fecha-chip--more { background: #f1f8e9; color: #60725d; border-color: #d4e6d4; }

/* Error */
.mt-error { background: #ffebee; border: 1.5px solid #ffcdd2; color: #b71c1c; padding: .75rem 1rem; border-radius: 10px; font-size: .85rem; display: flex; align-items: center; gap: .5rem; }

/* Footer */
.mt-footer { display: flex; justify-content: flex-end; gap: .75rem; padding: 1rem 1.5rem; border-top: 1px solid #e8f0e9; position: sticky; bottom: 0; background: #fff; border-radius: 0 0 18px 18px; }
.mt-btn-ghost { background: transparent; color: #60725d; border: 1.5px solid #d4e6d4; padding: .65rem 1.25rem; border-radius: 10px; font-size: .875rem; font-weight: 500; cursor: pointer; }
.mt-btn-ghost:hover { background: #e8f0e9; color: #1b5e20; }
.mt-btn-primary { display: inline-flex; align-items: center; gap: .4rem; background: #1b5e20; color: #fff; border: none; padding: .65rem 1.4rem; border-radius: 10px; font-size: .875rem; font-weight: 700; cursor: pointer; white-space: nowrap; }
.mt-btn-primary:hover { background: #104417; }
.mt-btn-primary:disabled { opacity: .6; cursor: not-allowed; }

/* Spinner */
.mt-spinner { width: 14px; height: 14px; border: 2px solid rgba(255,255,255,.3); border-top-color: #fff; border-radius: 50%; animation: mt-spin .6s linear infinite; }
@keyframes mt-spin { to { transform: rotate(360deg); } }
</style>


