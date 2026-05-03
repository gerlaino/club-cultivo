<script setup>
import { onMounted, ref, computed } from 'vue'
import { useAmbienteStore } from '../stores/ambiente.js'
import { useToast } from '../composables/useToast.js'
import { useConfirm } from '../composables/useConfirm.js'
import { listSalas } from '../lib/api.js'

const store   = useAmbienteStore()
const toast   = useToast()
const confirm = useConfirm()

const loading   = ref(false)
const showForm  = ref(false)
const guardando = ref(false)
const editando  = ref(null)
const formError = ref(null)
const salas     = ref([])

const TIPOS = [
  { value: 'temperatura', label: 'Temperatura' },
  { value: 'humedad',     label: 'Humedad' },
  { value: 'vpd',         label: 'VPD' },
  { value: 'co2',         label: 'CO₂' },
  { value: 'ppfd',        label: 'PPFD' },
  { value: 'ec',          label: 'EC' },
  { value: 'ph',          label: 'pH' },
]

const CONDICIONES = [
  { value: 'gt',            label: '> mayor que' },
  { value: 'lt',            label: '< menor que' },
  { value: 'gte',           label: '≥ mayor o igual' },
  { value: 'lte',           label: '≤ menor o igual' },
  { value: 'between',       label: 'entre (rango OK)' },
  { value: 'out_of_range',  label: 'fuera de rango' },
]

const ACCIONES = [
  { value: 'notificar',   label: 'Notificar' },
  { value: 'crear_tarea', label: 'Crear tarea' },
  { value: 'webhook',     label: 'Webhook externo' },
  { value: 'todas',       label: 'Todas' },
]

const PRIORIDADES = [
  { value: 'baja',    label: 'Baja' },
  { value: 'media',   label: 'Media' },
  { value: 'alta',    label: 'Alta' },
  { value: 'critica', label: 'Crítica' },
]

function emptyForm() {
  return {
    nombre: '', tipo_lectura: 'temperatura', condicion: 'gt',
    umbral_a: '', umbral_b: '', prioridad: 'media', duracion_minutos: '',
    accion: 'notificar', sala_id: '', activa: true,
  }
}

const form = ref(emptyForm())

const usaDobleUmbral = computed(() =>
  ['between', 'out_of_range'].includes(form.value.condicion)
)

onMounted(async () => {
  loading.value = true
  const [_, salasRes] = await Promise.all([
    store.cargarReglas(),
    listSalas(),
  ])
  salas.value  = salasRes.data || []
  loading.value = false
})

function abrirCrear() {
  editando.value = null
  form.value     = emptyForm()
  formError.value = null
  showForm.value = true
}

function abrirEditar(regla) {
  editando.value = regla
  form.value = {
    nombre:           regla.nombre,
    tipo_lectura:     regla.tipo_lectura,
    condicion:        regla.condicion,
    umbral_a:         regla.umbral_a,
    umbral_b:         regla.umbral_b || '',
    prioridad:        regla.prioridad || 'media',
    duracion_minutos: regla.duracion_minutos || '',
    accion:           regla.accion,
    sala_id:          regla.sala_id || '',
    activa:           regla.activa,
  }
  formError.value = null
  showForm.value = true
}

function cerrarForm() {
  showForm.value = false
  editando.value = null
  form.value = emptyForm()
}

async function guardar() {
  if (!form.value.nombre)           { formError.value = 'El nombre es obligatorio'; return }
  if (!form.value.umbral_a)         { formError.value = 'El umbral es obligatorio'; return }
  if (!form.value.prioridad)        { formError.value = 'La prioridad es obligatoria'; return }
  if (!form.value.duracion_minutos) { formError.value = 'La duración mínima es obligatoria'; return }
  guardando.value = true
  formError.value = null
  try {
    const payload = { ...form.value }
    payload.umbral_a = parseFloat(payload.umbral_a)
    payload.duracion_minutos = parseInt(payload.duracion_minutos, 10)
    if (!payload.sala_id) delete payload.sala_id
    if (!usaDobleUmbral.value || !payload.umbral_b) delete payload.umbral_b
    else payload.umbral_b = parseFloat(payload.umbral_b)

    if (editando.value) {
      await store.updateRegla(editando.value.id, payload)
      toast.success('Regla actualizada')
    } else {
      await store.createRegla(payload)
      toast.success('Regla creada')
    }
    cerrarForm()
  } catch (e) {
    formError.value = e?.response?.data?.errors?.[0] || 'Error al guardar'
  } finally {
    guardando.value = false
  }
}

async function eliminar(regla) {
  const ok = await confirm(`¿Eliminar la regla "${regla.nombre}"?`)
  if (!ok) return
  try {
    await store.deleteRegla(regla.id)
    toast.success('Regla eliminada')
  } catch {
    toast.error('Error al eliminar')
  }
}

function condicionLabel(v) { return CONDICIONES.find(c => c.value === v)?.label || v }
function tipoLabel(v)      { return TIPOS.find(t => t.value === v)?.label || v }
</script>

<template>
  <div class="rav">
    <div class="rav__header">
      <div>
        <h1 class="rav__title">⚙️ Reglas Ambientales</h1>
        <p class="rav__sub">Condiciones automáticas que generan alertas o tareas.</p>
      </div>
      <button class="rav__btn-primary" @click="abrirCrear">
        <i class="bi bi-plus-lg"></i> Nueva regla
      </button>
    </div>

    <!-- Form -->
    <div v-if="showForm" class="rav__form-card">
      <div class="rav__form-title">{{ editando ? 'Editar regla' : 'Nueva regla' }}</div>
      <div v-if="formError" class="rav__alert">{{ formError }}</div>
      <div class="rav__form-grid">
        <div class="rav__field rav__field--full">
          <label class="rav__label">Nombre <span class="rav__req">*</span></label>
          <input class="rav__input" v-model="form.nombre" placeholder="Ej: Temperatura máxima floración" />
        </div>
        <div class="rav__field">
          <label class="rav__label">Parámetro</label>
          <select class="rav__input" v-model="form.tipo_lectura">
            <option v-for="t in TIPOS" :key="t.value" :value="t.value">{{ t.label }}</option>
          </select>
        </div>
        <div class="rav__field">
          <label class="rav__label">Condición</label>
          <select class="rav__input" v-model="form.condicion">
            <option v-for="c in CONDICIONES" :key="c.value" :value="c.value">{{ c.label }}</option>
          </select>
        </div>
        <div class="rav__field">
          <label class="rav__label">Umbral{{ usaDobleUmbral ? ' mínimo' : '' }} <span class="rav__req">*</span></label>
          <input type="number" step="0.01" class="rav__input" v-model="form.umbral_a" />
        </div>
        <div v-if="usaDobleUmbral" class="rav__field">
          <label class="rav__label">Umbral máximo</label>
          <input type="number" step="0.01" class="rav__input" v-model="form.umbral_b" />
        </div>
        <div class="rav__field">
          <label class="rav__label">Prioridad <span class="rav__req">*</span></label>
          <select class="rav__input" v-model="form.prioridad">
            <option v-for="p in PRIORIDADES" :key="p.value" :value="p.value">{{ p.label }}</option>
          </select>
        </div>
        <div class="rav__field">
          <label class="rav__label">Duración mínima (min) <span class="rav__req">*</span></label>
          <input type="number" min="1" step="1" class="rav__input" v-model="form.duracion_minutos" placeholder="Ej: 5" />
        </div>
        <div class="rav__field">
          <label class="rav__label">Acción</label>
          <select class="rav__input" v-model="form.accion">
            <option v-for="a in ACCIONES" :key="a.value" :value="a.value">{{ a.label }}</option>
          </select>
        </div>
        <div class="rav__field">
          <label class="rav__label">Sala (opcional)</label>
          <select class="rav__input" v-model="form.sala_id">
            <option value="">Todas las salas</option>
            <option v-for="s in salas" :key="s.id" :value="s.id">{{ s.nombre }}</option>
          </select>
        </div>
        <div class="rav__field rav__field--check">
          <label class="rav__check-label">
            <input type="checkbox" v-model="form.activa" /> Regla activa
          </label>
        </div>
      </div>
      <div class="rav__form-actions">
        <button class="rav__btn-ghost" @click="cerrarForm">Cancelar</button>
        <button class="rav__btn-primary" :disabled="guardando" @click="guardar">
          {{ guardando ? 'Guardando…' : (editando ? 'Actualizar' : 'Crear regla') }}
        </button>
      </div>
    </div>

    <!-- Lista -->
    <div v-if="loading" class="rav__loading">Cargando reglas…</div>
    <div v-else-if="!store.reglas.length && !showForm" class="rav__empty">
      <div class="rav__empty-icon">⚙️</div>
      <div class="rav__empty-title">Sin reglas configuradas</div>
      <div class="rav__empty-sub">Creá la primera regla para automatizar alertas ambientales.</div>
    </div>
    <div v-else class="rav__table-wrap">
      <table class="rav__table">
        <thead>
          <tr>
            <th>Nombre</th>
            <th>Parámetro</th>
            <th>Condición</th>
            <th>Umbral</th>
            <th>Acción</th>
            <th>Sala</th>
            <th>Estado</th>
            <th></th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="r in store.reglas" :key="r.id">
            <td class="rav__td-nombre">{{ r.nombre }}</td>
            <td>{{ tipoLabel(r.tipo_lectura) }}</td>
            <td>{{ condicionLabel(r.condicion) }}</td>
            <td>
              {{ r.umbral_a }}
              <span v-if="r.umbral_b"> – {{ r.umbral_b }}</span>
            </td>
            <td>{{ r.accion }}</td>
            <td>{{ r.sala_nombre || '—' }}</td>
            <td>
              <span class="rav__badge" :class="r.activa ? 'rav__badge--green' : 'rav__badge--gray'">
                {{ r.activa ? 'activa' : 'inactiva' }}
              </span>
            </td>
            <td class="rav__td-actions">
              <button class="rav__btn-sm" @click="abrirEditar(r)" title="Editar">
                <i class="bi bi-pencil"></i>
              </button>
              <button class="rav__btn-sm rav__btn-sm--danger" @click="eliminar(r)" title="Eliminar">
                <i class="bi bi-trash"></i>
              </button>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>

<style scoped>
.rav { padding: 1.75rem 1.5rem; max-width: 1100px; margin: 0 auto; font-family: system-ui, -apple-system, sans-serif; }
@media (max-width: 640px) { .rav { padding: 1rem; } }

.rav__header { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; margin-bottom: 1.5rem; flex-wrap: wrap; }
.rav__title { font-size: 1.6rem; font-weight: 800; margin: 0; letter-spacing: -.04em; }
.rav__sub { font-size: .82rem; color: #60725d; margin: .25rem 0 0; }

.rav__form-card { background: #fff; border: 1px solid #d4e6d4; border-radius: 14px; padding: 1.25rem; margin-bottom: 1.5rem; }
.rav__form-title { font-size: .9rem; font-weight: 700; margin-bottom: 1rem; }
.rav__form-grid { display: grid; grid-template-columns: 1fr 1fr; gap: .75rem; }
@media (max-width: 640px) { .rav__form-grid { grid-template-columns: 1fr; } }
.rav__field { display: flex; flex-direction: column; gap: .3rem; }
.rav__field--full { grid-column: 1/-1; }
.rav__field--check { justify-content: flex-end; }
.rav__label { font-size: .75rem; font-weight: 600; color: #374151; }
.rav__req { color: #dc2626; }
.rav__check-label { display: flex; align-items: center; gap: .4rem; font-size: .82rem; cursor: pointer; }
.rav__input {
  background: #f4f8f4; border: 1.5px solid #d4e6d4; border-radius: 8px;
  padding: .55rem .75rem; font-size: .875rem; color: #1a1a1a;
  width: 100%; box-sizing: border-box;
}
.rav__input:focus { outline: none; border-color: #1b5e20; background: #fff; }
.rav__form-actions { display: flex; justify-content: flex-end; gap: .6rem; margin-top: 1rem; }
.rav__alert { background: #fef2f2; border: 1px solid #fecaca; color: #dc2626; padding: .6rem .9rem; border-radius: 8px; font-size: .82rem; margin-bottom: .75rem; }

.rav__loading { padding: 3rem; text-align: center; color: #94a3b8; }
.rav__empty { text-align: center; padding: 4rem 1rem; }
.rav__empty-icon { font-size: 3rem; margin-bottom: .75rem; }
.rav__empty-title { font-size: 1rem; font-weight: 700; color: #1a1a1a; margin-bottom: .35rem; }
.rav__empty-sub { font-size: .82rem; color: #94a3b8; }

.rav__table-wrap { overflow-x: auto; }
.rav__table { width: 100%; border-collapse: collapse; font-size: .82rem; }
.rav__table th {
  background: #f4f8f4; padding: .6rem .85rem;
  text-align: left; font-size: .72rem; font-weight: 700;
  color: #60725d; text-transform: uppercase; letter-spacing: .04em;
  border-bottom: 2px solid #d4e6d4;
}
.rav__table td { padding: .65rem .85rem; border-bottom: 1px solid #f0f4f0; color: #1a1a1a; vertical-align: middle; }
.rav__table tbody tr:hover { background: #f9fdf9; }
.rav__td-nombre { font-weight: 600; }

.rav__badge {
  font-size: .65rem; font-weight: 800; text-transform: uppercase; letter-spacing: .05em;
  padding: .2em .55em; border-radius: 6px;
}
.rav__badge--green { background: #dcfce7; color: #15803d; }
.rav__badge--gray  { background: #f1f5f9; color: #64748b; }

.rav__td-actions { display: flex; gap: .35rem; }
.rav__btn-sm {
  width: 28px; height: 28px; border-radius: 6px; border: 1px solid #e2e8f0;
  background: #f8fafc; color: #64748b; cursor: pointer;
  display: flex; align-items: center; justify-content: center; font-size: .8rem; transition: all .15s;
}
.rav__btn-sm:hover { background: #e8f5e9; color: #1b5e20; border-color: #d4e6d4; }
.rav__btn-sm--danger:hover { background: #fef2f2; color: #dc2626; border-color: #fca5a5; }

.rav__btn-primary {
  display: inline-flex; align-items: center; gap: .4rem;
  background: #1b5e20; color: #fff; border: none;
  padding: .6rem 1.25rem; border-radius: 8px; font-size: .875rem; font-weight: 600; cursor: pointer;
}
.rav__btn-primary:hover:not(:disabled) { background: #104417; }
.rav__btn-primary:disabled { opacity: .5; cursor: not-allowed; }
.rav__btn-ghost {
  background: transparent; color: #60725d; border: 1px solid #d4e6d4;
  padding: .6rem 1.1rem; border-radius: 8px; font-size: .875rem; font-weight: 500; cursor: pointer;
}
.rav__btn-ghost:hover { background: #f0fdf4; }
</style>
