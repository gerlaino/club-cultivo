<template>
  <Teleport to="body">
    <div class="npm__overlay">
      <div class="npm__panel">

        <!-- Header -->
        <div class="npm__header">
          <div class="npm__header-ico"><i class="bi bi-clipboard-plus"></i></div>
          <div>
            <h2 class="npm__title">Nuevo plan de trabajo</h2>
            <p class="npm__sub">Paso {{ paso }} de 3 — {{ PASO_LABELS[paso - 1] }}</p>
          </div>
          <button class="npm__close" @click="$emit('close')"><i class="bi bi-x-lg"></i></button>
        </div>

        <!-- Stepper -->
        <div class="npm__stepper">
          <div v-for="i in 3" :key="i" class="npm__step" :class="{ 'npm__step--done': paso > i, 'npm__step--active': paso === i }">
            <div class="npm__step-dot">{{ paso > i ? '✓' : i }}</div>
            <span class="npm__step-label">{{ PASO_LABELS[i - 1] }}</span>
          </div>
        </div>

        <!-- Body -->
        <div class="npm__body">
          <div v-if="error" class="npm__alert">{{ error }}</div>

          <!-- ── PASO 1: Configuración (sin cambios) ── -->
          <template v-if="paso === 1">
            <div class="npm__field">
              <label class="npm__label">Título del plan</label>
              <input class="npm__input" v-model="form.titulo" placeholder="Ej: Plan semana del 12 al 18 de mayo" />
            </div>

            <div class="npm__field">
              <label class="npm__label">Período</label>
              <div class="npm__tipo-btns">
                <button v-for="t in TIPOS_PERIODO" :key="t.value" class="npm__tipo-btn" :class="{ 'npm__tipo-btn--active': form.periodo_tipo === t.value }" @click="setPeriodo(t.value)">
                  <span class="npm__tipo-ico">{{ t.ico }}</span>
                  <span class="npm__tipo-lbl">{{ t.label }}</span>
                </button>
              </div>
            </div>

            <div class="npm__row">
              <div class="npm__field">
                <label class="npm__label">Desde</label>
                <AppDatePicker v-model="form.fecha_inicio" @update:model-value="ajustarFechaFin" />
              </div>
              <div class="npm__field">
                <label class="npm__label">Hasta</label>
                <AppDatePicker v-model="form.fecha_fin" :min="form.fecha_inicio" />
              </div>
            </div>

            <div class="npm__field">
              <label class="npm__label">Notas <span class="npm__hint">(opcional)</span></label>
              <textarea class="npm__input npm__textarea" v-model="form.notas" rows="2" placeholder="Observaciones generales del plan…"></textarea>
            </div>
          </template>

          <!-- ── PASO 2: Tareas ── -->
          <template v-if="paso === 2">

            <!-- Selector de modo -->
            <div class="npm__modo-tabs">
              <button
                class="npm__modo-tab"
                :class="{ 'npm__modo-tab--active': modoP2 === 'archivo' }"
                @click="modoP2 = 'archivo'"
              >
                📎 Importar desde archivo
              </button>
              <button
                class="npm__modo-tab"
                :class="{ 'npm__modo-tab--active': modoP2 === 'manual' }"
                @click="switchManual"
              >
                ✏️ Agregar manualmente
              </button>
            </div>

            <!-- ── MODO A: Importar archivo ── -->
            <template v-if="modoP2 === 'archivo'">

              <!-- Drop zone (sin preview aún) -->
              <div
                v-if="!preview"
                key="dropzone"
                class="npm__dropzone"
                :class="{ 'npm__dropzone--drag': dragOver }"
                @dragover.prevent="dragOver = true"
                @dragleave.prevent="dragOver = false"
                @drop.prevent="onDrop"
                @click="fileInputRef.click()"
              >
                <input
                  ref="fileInputRef"
                  type="file"
                  accept=".xlsx,.xls,.csv,.docx,.pdf"
                  style="display:none"
                  @change="onFileChange"
                />
                <template v-if="!interpretando">
                  <i class="bi bi-cloud-arrow-up npm__drop-ico"></i>
                  <p class="npm__drop-main">Arrastrá tu archivo acá</p>
                  <p class="npm__drop-sub">o hacé clic para seleccionar</p>
                  <p class="npm__drop-formats">.xlsx &nbsp;.xls &nbsp;.csv &nbsp;.docx &nbsp;.pdf</p>
                </template>
                <template v-else>
                  <DsSpinner :size="28" />
                  <p class="npm__drop-main">{{ archivoNombre }}</p>
                  <p class="npm__drop-sub">Interpretando…</p>
                </template>
              </div>

              <!-- Vista previa -->
              <div v-else key="preview" class="npm__preview">
                <!-- Header de preview -->
                <div class="npm__preview-hdr">
                  <div>
                    <span class="npm__preview-title">Tareas detectadas</span>
                    <span class="npm__preview-count">{{ preview.total }} tareas · {{ preview.recurrentes }} recurrentes</span>
                  </div>
                  <button class="npm__btn-ghost npm__btn-ghost--sm" @click="resetArchivo">
                    <i class="bi bi-arrow-counterclockwise"></i> Cambiar archivo
                  </button>
                </div>

                <!-- Tareas confirmadas -->
                <div v-if="preview.tareas.length > 0">
                  <p class="npm__preview-sep npm__preview-sep--ok">✅ {{ preview.tareas.length }} confirmada{{ preview.tareas.length !== 1 ? 's' : '' }}</p>
                  <div class="npm__tareas-list">
                    <div v-for="(t, i) in preview.tareas" :key="'c-' + i" class="npm__tarea-row npm__tarea-row--confirmed">
                      <div class="npm__tarea-row-main">
                        <select class="npm__input npm__input--sm" v-model="t.tipo">
                          <option v-for="tp in TIPOS" :key="tp.value" :value="tp.value">{{ tp.label }}</option>
                        </select>
                        <input class="npm__input" v-model="t.titulo" placeholder="Título (opcional)" />
                        <div class="npm__resp-wrap">
                          <input class="npm__input" v-model="t._resp_texto" @input="onRespInput(t)" @focus="t._resp_abierto = true" @blur="cerrarRespDropdown(t)" placeholder="Responsable…" :class="{ 'npm__input--resp-ok': t.responsable_id }" />
                          <div v-if="t._resp_abierto" class="npm__resp-drop">
                            <div v-for="u in filtrarUsuarios(t._resp_texto)" :key="u.id" class="npm__resp-opcion" :class="{ 'npm__resp-opcion--sel': t.responsable_id === u.id }" @mousedown.prevent="seleccionarResponsable(t, u)">{{ u.nombre_completo || u.nombre }}</div>
                            <div v-if="filtrarUsuarios(t._resp_texto).length === 0 && t._resp_texto" class="npm__resp-none">Sin coincidencias</div>
                            <div v-if="t.responsable_id" class="npm__resp-clear" @mousedown.prevent="limpiarResponsable(t)">✕ Quitar asignación</div>
                          </div>
                        </div>
                        <button class="npm__tarea-del" @click="preview.tareas.splice(i, 1)"><i class="bi bi-trash3"></i></button>
                      </div>
                      <div class="npm__tarea-row-extra">
                        <div class="npm__toggle-row">
                          <button class="npm__toggle" :class="{ 'npm__toggle--on': !t.es_recurrente }" @click="t.es_recurrente = false">Única</button>
                          <button class="npm__toggle" :class="{ 'npm__toggle--on': t.es_recurrente }"  @click="t.es_recurrente = true">Recurrente</button>
                        </div>
                        <template v-if="t.es_recurrente">
                          <div class="npm__dias">
                            <button v-for="d in DIAS" :key="d.value" class="npm__dia" :class="{ 'npm__dia--on': diasArrFromApi(t).includes(d.value) }" @click="toggleDiaApi(t, d.value)">{{ d.label }}</button>
                          </div>
                        </template>
                        <template v-else>
                          <AppDatePicker v-model="t.fecha_especifica" :min="form.fecha_inicio" :max="form.fecha_fin" />
                        </template>
                        <input class="npm__input npm__input--xs" type="time" v-model="t.hora" />
                        <div class="npm__prio-row">
                          <button v-for="p in PRIORIDADES" :key="p.value" type="button" class="npm__prio-pill" :class="[`npm__prio-pill--${p.value}`, { 'npm__prio-pill--on': t.prioridad === p.value }]" @click="t.prioridad = p.value" :title="p.label">{{ p.ico }}</button>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>

                <!-- Tareas ambiguas -->
                <div v-if="preview.ambiguas.length > 0">
                  <p class="npm__preview-sep npm__preview-sep--warn">⚠️ {{ preview.ambiguas.length }} con datos incompletos</p>
                  <div class="npm__tareas-list">
                    <div v-for="(a, i) in preview.ambiguas" :key="'a-' + i" class="npm__tarea-row npm__tarea-row--ambigua">
                      <div class="npm__ambigua-info">
                        <span class="npm__ambigua-titulo">{{ a.tarea?.titulo || a.tarea?.tipo || 'Tarea' }}</span>
                        <span class="npm__ambigua-desc">{{ a.descripcion }}</span>
                      </div>
                      <div class="npm__ambigua-actions">
                        <select class="npm__input npm__input--sm" v-model="a._responsable_id">
                          <option :value="null">Omitir esta tarea</option>
                          <option v-for="u in usuarios" :key="u.id" :value="u.id">{{ u.nombre_completo || u.nombre }}</option>
                        </select>
                        <button class="npm__tarea-del" @click="preview.ambiguas.splice(i, 1)"><i class="bi bi-trash3"></i></button>
                      </div>
                    </div>
                  </div>
                </div>

                <div v-if="preview.tareas.length === 0 && preview.ambiguas.length === 0" class="npm__tareas-empty">
                  <p>No se detectaron tareas en el archivo.</p>
                  <button class="npm__btn-agregar" @click="resetArchivo">Intentar con otro archivo</button>
                </div>
              </div>
            </template>

            <!-- ── MODO B: Manual ── -->
            <template v-else>
              <div class="npm__tareas-hdr">
                <span class="npm__tareas-count">{{ tareas.length }} tarea{{ tareas.length !== 1 ? 's' : '' }}</span>
                <button class="npm__btn-agregar" @click="agregarTarea">+ Agregar tarea</button>
              </div>

              <div v-if="tareas.length === 0" class="npm__tareas-empty">
                <p>Todavía no hay tareas. Podés agregarlas ahora o hacerlo después desde el plan.</p>
                <button class="npm__btn-agregar npm__btn-agregar--lg" @click="agregarTarea">+ Agregar primera tarea</button>
              </div>

              <div v-else class="npm__tareas-list">
                <div v-for="(t, i) in tareas" :key="i" class="npm__tarea-row">
                  <div class="npm__tarea-row-main">
                    <select class="npm__input npm__input--sm" v-model="t.tipo">
                      <option v-for="tp in TIPOS" :key="tp.value" :value="tp.value">{{ tp.label }}</option>
                    </select>
                    <input class="npm__input" v-model="t.titulo" placeholder="Título (opcional)" />
                    <div class="npm__resp-wrap">
                      <input class="npm__input" v-model="t._resp_texto" @input="onRespInput(t)" @focus="t._resp_abierto = true" @blur="cerrarRespDropdown(t)" placeholder="Responsable…" :class="{ 'npm__input--resp-ok': t.responsable_id }" />
                      <div v-if="t._resp_abierto" class="npm__resp-drop">
                        <div v-for="u in filtrarUsuarios(t._resp_texto)" :key="u.id" class="npm__resp-opcion" :class="{ 'npm__resp-opcion--sel': t.responsable_id === u.id }" @mousedown.prevent="seleccionarResponsable(t, u)">{{ u.nombre_completo || u.nombre }}</div>
                        <div v-if="filtrarUsuarios(t._resp_texto).length === 0 && t._resp_texto" class="npm__resp-none">Sin coincidencias</div>
                        <div v-if="t.responsable_id" class="npm__resp-clear" @mousedown.prevent="limpiarResponsable(t)">✕ Quitar asignación</div>
                      </div>
                    </div>
                    <button class="npm__tarea-del" @click="tareas.splice(i, 1)"><i class="bi bi-trash3"></i></button>
                  </div>
                  <div class="npm__tarea-row-extra">
                    <div class="npm__toggle-row">
                      <button class="npm__toggle" :class="{ 'npm__toggle--on': !t.es_recurrente }" @click="t.es_recurrente = false">Única</button>
                      <button class="npm__toggle" :class="{ 'npm__toggle--on': t.es_recurrente }" @click="t.es_recurrente = true">Recurrente</button>
                    </div>
                    <template v-if="t.es_recurrente">
                      <div class="npm__dias">
                        <button v-for="d in DIAS" :key="d.value" class="npm__dia" :class="{ 'npm__dia--on': diasArr(t).includes(d.value) }" @click="toggleDia(t, d.value)">{{ d.label }}</button>
                      </div>
                    </template>
                    <template v-else>
                      <AppDatePicker v-model="t.fecha_especifica" :min="form.fecha_inicio" :max="form.fecha_fin" />
                    </template>
                    <input class="npm__input npm__input--xs" type="time" v-model="t.hora" placeholder="Hora" />
                    <div class="npm__prio-row">
                      <button v-for="p in PRIORIDADES" :key="p.value" type="button" class="npm__prio-pill" :class="[`npm__prio-pill--${p.value}`, { 'npm__prio-pill--on': t.prioridad === p.value }]" @click="t.prioridad = p.value" :title="p.label">{{ p.ico }}</button>
                    </div>
                  </div>
                </div>
              </div>

              <!-- Copiar plan anterior -->
              <div v-if="planesAnteriores.length > 0" class="npm__copiar">
                <p class="npm__label">Copiar plan anterior</p>
                <div v-for="p in planesAnteriores" :key="p.id" class="npm__plan-copy-row">
                  <div class="npm__plan-copy-info">
                    <span class="npm__plan-copy-titulo">{{ p.titulo || 'Plan sin título' }}</span>
                    <span class="npm__plan-copy-meta">{{ p.fecha_inicio }} · {{ p.total_plan_tareas || 0 }} tareas</span>
                  </div>
                  <button
                    class="npm__btn-copiar"
                    :disabled="copiandoPlan === p.id"
                    @click="copiarPlan(p)"
                  >
                    <DsSpinner v-if="copiandoPlan === p.id" :size="10" />
                    {{ copiandoPlan === p.id ? '…' : 'Copiar' }}
                  </button>
                </div>
              </div>
              <div v-else-if="cargandoPlanes" class="npm__plan-copy-loading">Cargando planes…</div>
            </template>

          </template>

          <!-- ── PASO 3: Revisión (sin cambios) ── -->
          <template v-if="paso === 3">
            <div class="npm__resumen">
              <div class="npm__res-block">
                <span class="npm__res-label">Título</span>
                <span class="npm__res-val">{{ form.titulo }}</span>
              </div>
              <div class="npm__res-block">
                <span class="npm__res-label">Período</span>
                <span class="npm__res-val">{{ TIPOS_PERIODO.find(t => t.value === form.periodo_tipo)?.label }}</span>
              </div>
              <div class="npm__res-block">
                <span class="npm__res-label">Fechas</span>
                <span class="npm__res-val">{{ form.fecha_inicio }} → {{ form.fecha_fin }}</span>
              </div>
              <div class="npm__res-block">
                <span class="npm__res-label">Tareas</span>
                <span class="npm__res-val">{{ tareas.length }} tareas configuradas</span>
              </div>
              <div v-if="form.notas" class="npm__res-block">
                <span class="npm__res-label">Notas</span>
                <span class="npm__res-val">{{ form.notas }}</span>
              </div>
            </div>

            <div class="npm__pub-opts">
              <label class="npm__pub-opt" :class="{ 'npm__pub-opt--active': publicarAlCrear }">
                <input type="radio" v-model="publicarAlCrear" :value="true" />
                <div>
                  <div class="npm__pub-opt-title">Publicar ahora</div>
                  <div class="npm__pub-opt-sub">Se generan las tareas y el equipo puede verlas.</div>
                </div>
              </label>
              <label class="npm__pub-opt" :class="{ 'npm__pub-opt--active': !publicarAlCrear }">
                <input type="radio" v-model="publicarAlCrear" :value="false" />
                <div>
                  <div class="npm__pub-opt-title">Guardar como borrador</div>
                  <div class="npm__pub-opt-sub">Podés seguir editando antes de publicar.</div>
                </div>
              </label>
            </div>
          </template>
        </div>

        <!-- Footer -->
        <div class="npm__footer">
          <button v-if="paso > 1" class="npm__btn-ghost" @click="paso--">Atrás</button>
          <div v-else></div>
          <div class="npm__footer-right">
            <button class="npm__btn-ghost" @click="$emit('close')">Cancelar</button>
            <button v-if="paso < 3" class="npm__btn-primary" :disabled="interpretando" @click="siguientePaso">
              Siguiente →
            </button>
            <button v-else class="npm__btn-primary" :disabled="saving" @click="guardar">
              <DsSpinner v-if="saving" :size="14" />
              {{ saving ? 'Creando…' : (publicarAlCrear ? 'Crear y publicar' : 'Guardar borrador') }}
            </button>
          </div>
        </div>
      </div>
    </div>
  </Teleport>
</template>

<script setup>
import { ref } from 'vue'
import AppDatePicker from '../ui/AppDatePicker.vue'
import {
  createPlanTrabajo, createPlanTarea, publicarPlanTrabajo,
  interpretarArchivoPlan, listPlanTrabajos, listPlanTareas,
} from '../../lib/api.js'
import DsSpinner from '../../design-system/components/Spinner.vue'

const props = defineProps({
  usuarios: { type: Array, default: () => [] },
  salas:    { type: Array, default: () => [] },
})
const emit = defineEmits(['close', 'created'])

const PASO_LABELS = ['Configuración', 'Tareas', 'Revisión']
const TIPOS_PERIODO = [
  { value: 'semanal',    label: 'Semanal',    ico: '📅' },
  { value: 'mensual',    label: 'Mensual',    ico: '🗓️' },
  { value: 'trimestral', label: 'Trimestral', ico: '📊' },
]
const TIPOS = [
  { value: 'riego', label: '💧 Riego' }, { value: 'poda', label: '✂️ Poda' },
  { value: 'medicion', label: '📏 Medición' }, { value: 'limpieza', label: '🧹 Limpieza' },
  { value: 'cosecha', label: '🌿 Cosecha' }, { value: 'trasplante', label: '🪴 Trasplante' },
  { value: 'inspeccion', label: '🔍 Inspección' }, { value: 'otro', label: '📋 Otro' },
]
const PRIORIDADES = [
  { value: 'baja', label: 'Baja', ico: '↓' },
  { value: 'normal', label: 'Normal', ico: '●' },
  { value: 'alta', label: 'Alta', ico: '↑' },
  { value: 'urgente', label: 'Urgente', ico: '⚡' },
]
const DIAS = [
  { value: 'lun', label: 'L' }, { value: 'mar', label: 'M' }, { value: 'mie', label: 'M' },
  { value: 'jue', label: 'J' }, { value: 'vie', label: 'V' }, { value: 'sab', label: 'S' }, { value: 'dom', label: 'D' },
]

function isoHoy() { return new Date().toISOString().slice(0, 10) }
function addDays(iso, n) {
  const d = new Date(iso); d.setDate(d.getDate() + n); return d.toISOString().slice(0, 10)
}

// ── State ──
const paso  = ref(1)
const error = ref(null)
const saving = ref(false)
const publicarAlCrear = ref(true)
const tareas = ref([])   // lista final que va al backend

const form = ref({
  titulo:       '',
  periodo_tipo: 'semanal',
  fecha_inicio: isoHoy(),
  fecha_fin:    addDays(isoHoy(), 6),
  notas:        '',
})

// ── Paso 2: modo ──
const modoP2       = ref('archivo')
const dragOver     = ref(false)
const archivoNombre = ref('')
const interpretando = ref(false)
const preview       = ref(null)   // { tareas:[], ambiguas:[], total, recurrentes }
const fileInputRef  = ref(null)

// Copiar plan anterior
const planesAnteriores = ref([])
const cargandoPlanes   = ref(false)
const copiandoPlan     = ref(null)

// ── Paso 1 helpers ──
function setPeriodo(tipo) {
  form.value.periodo_tipo = tipo
  ajustarFechaFin()
}
function ajustarFechaFin() {
  const inicio = form.value.fecha_inicio
  if (!inicio) return
  const dias = form.value.periodo_tipo === 'semanal' ? 6 : form.value.periodo_tipo === 'mensual' ? 29 : 89
  form.value.fecha_fin = addDays(inicio, dias)
}

// ── Manual task helpers ──
function agregarTarea() {
  tareas.value.push({
    tipo: 'riego', titulo: '', responsable_id: null, prioridad: 'normal',
    es_recurrente: true, dias_semana: 'lun,mie,vie', hora: '', fecha_especifica: form.value.fecha_inicio,
    _resp_texto: '', _resp_abierto: false,
  })
}

// ── Responsable autocomplete ──
function nombreResponsable(id) {
  if (!id) return ''
  const u = props.usuarios.find(u => u.id === id)
  return u ? (u.nombre_completo || u.nombre) : ''
}
function filtrarUsuarios(query) {
  if (!query) return props.usuarios.slice(0, 6)
  const q = query.toLowerCase()
  return props.usuarios.filter(u => (u.nombre_completo || u.nombre || '').toLowerCase().includes(q)).slice(0, 6)
}
function onRespInput(t) {
  t._resp_abierto = true
  if (!t._resp_texto) t.responsable_id = null
}
function seleccionarResponsable(t, u) {
  t.responsable_id = u.id
  t._resp_texto = u.nombre_completo || u.nombre
  t._resp_abierto = false
}
function limpiarResponsable(t) {
  t.responsable_id = null
  t._resp_texto = ''
  t._resp_abierto = false
}
function cerrarRespDropdown(t) {
  setTimeout(() => { t._resp_abierto = false }, 150)
}
function diasArr(t) {
  return t.dias_semana ? t.dias_semana.split(',').map(s => s.trim()) : []
}
function toggleDia(t, d) {
  const arr = diasArr(t)
  const idx = arr.indexOf(d)
  if (idx >= 0) arr.splice(idx, 1); else arr.push(d)
  t.dias_semana = arr.join(',')
}

// ── Import helpers ──
// Las tareas de la API tienen dias_semana como array; las manuales como string CSV
function diasArrFromApi(t) {
  if (Array.isArray(t.dias_semana)) return t.dias_semana
  return t.dias_semana ? t.dias_semana.split(',').map(s => s.trim()) : []
}
function toggleDiaApi(t, d) {
  const arr = diasArrFromApi(t)
  const idx = arr.indexOf(d)
  if (idx >= 0) arr.splice(idx, 1); else arr.push(d)
  t.dias_semana = arr
}

function normalizarTareaApi(t) {
  return {
    tipo:             t.tipo || 'otro',
    titulo:           t.titulo || '',
    responsable_id:   t.responsable_id || null,
    prioridad:        t.prioridad || 'normal',
    es_recurrente:    t.es_recurrente ?? true,
    dias_semana:      Array.isArray(t.dias_semana) ? t.dias_semana.join(',') : (t.dias_semana || ''),
    hora:             t.hora || '',
    fecha_especifica: t.fecha_especifica || form.value.fecha_inicio,
  }
}

// ── Drag & drop ──
function onDrop(e) {
  dragOver.value = false
  const file = e.dataTransfer?.files[0]
  if (file) handleFile(file)
}
function onFileChange(e) {
  const file = e.target.files[0]
  if (file) handleFile(file)
  // Reset input so the same file can be re-selected
  e.target.value = ''
}
async function handleFile(file) {
  archivoNombre.value = file.name
  interpretando.value = true
  preview.value = null
  error.value = null
  try {
    const formData = new FormData()
    formData.append('archivo', file)
    const { data } = await interpretarArchivoPlan(formData)
    if (data.error) {
      error.value = data.error
      archivoNombre.value = ''
    } else {
      preview.value = {
        tareas:     (data.tareas || []).map(t => ({ ...t, _resp_texto: nombreResponsable(t.responsable_id) || t.responsable_nombre || '', _resp_abierto: false })),
        ambiguas:   (data.ambiguas || []).map(a => ({ ...a, _responsable_id: null })),
        total:      data.total || 0,
        recurrentes: data.recurrentes || 0,
      }
    }
  } catch (e) {
    error.value = e?.response?.data?.error || 'Error al interpretar el archivo'
    archivoNombre.value = ''
  } finally {
    interpretando.value = false
  }
}
function resetArchivo() {
  preview.value = null
  archivoNombre.value = ''
  error.value = null
}

// ── Copiar plan anterior ──
async function switchManual() {
  modoP2.value = 'manual'
  if (planesAnteriores.value.length === 0 && !cargandoPlanes.value) {
    cargandoPlanes.value = true
    try {
      const { data } = await listPlanTrabajos({ per_page: 5 })
      planesAnteriores.value = data?.planes || data || []
    } catch {} finally {
      cargandoPlanes.value = false
    }
  }
}
async function copiarPlan(plan) {
  copiandoPlan.value = plan.id
  try {
    const { data } = await listPlanTareas(plan.id)
    const nuevas = (data || []).map(pt => ({
      tipo:             pt.tipo || 'otro',
      titulo:           pt.titulo || '',
      responsable_id:   pt.responsable?.id || null,
      prioridad:        pt.prioridad || 'normal',
      es_recurrente:    pt.es_recurrente ?? true,
      dias_semana:      pt.dias_semana || '',
      hora:             pt.hora || '',
      fecha_especifica: pt.fecha_especifica || form.value.fecha_inicio,
    }))
    tareas.value.push(...nuevas)
  } catch {
    error.value = 'Error al copiar el plan'
  } finally {
    copiandoPlan.value = null
  }
}

// ── Navegación ──
function siguientePaso() {
  error.value = null

  if (paso.value === 1) {
    if (!form.value.titulo.trim()) { error.value = 'El título es obligatorio'; return }
    if (!form.value.fecha_inicio || !form.value.fecha_fin) { error.value = 'Completá las fechas'; return }
    if (form.value.fecha_fin < form.value.fecha_inicio) { error.value = 'La fecha fin debe ser posterior al inicio'; return }
  }

  if (paso.value === 2 && modoP2.value === 'archivo' && preview.value) {
    const confirmadas = preview.value.tareas.map(normalizarTareaApi)
    const resueltas   = preview.value.ambiguas
      .filter(a => a._responsable_id !== null)
      .map(a => normalizarTareaApi({ ...a.tarea, responsable_id: a._responsable_id }))
    const sinResolver = preview.value.ambiguas.filter(a => a._responsable_id === null).length

    tareas.value = [...confirmadas, ...resueltas]

    if (sinResolver > 0) {
      // Avisa pero no bloquea
      error.value = `${sinResolver} tarea${sinResolver !== 1 ? 's' : ''} sin responsable serán omitidas.`
    }
  }

  paso.value++
}

// ── Guardar ──
async function guardar() {
  saving.value = true; error.value = null
  try {
    const { data: plan } = await createPlanTrabajo({
      plan_trabajo: {
        titulo:       form.value.titulo,
        periodo_tipo: form.value.periodo_tipo,
        fecha_inicio: form.value.fecha_inicio,
        fecha_fin:    form.value.fecha_fin,
        notas:        form.value.notas,
      },
    })

    for (const t of tareas.value) {
      await createPlanTarea(plan.id, {
        tipo: t.tipo, titulo: t.titulo, responsable_id: t.responsable_id, prioridad: t.prioridad,
        es_recurrente: t.es_recurrente, dias_semana: t.dias_semana, hora: t.hora,
        fecha_especifica: t.fecha_especifica,
      })
    }

    if (publicarAlCrear.value) {
      await publicarPlanTrabajo(plan.id)
    }

    emit('created', plan)
    emit('close')
  } catch (e) {
    error.value = e?.response?.data?.errors?.join(', ') || 'Error al crear el plan'
  } finally { saving.value = false }
}
</script>

<style scoped>
.npm__overlay { position: fixed; inset: 0; background: rgba(0,0,0,.45); display: flex; align-items: center; justify-content: center; z-index: 1060; padding: 1rem; backdrop-filter: blur(3px); }
.npm__panel   { background: #fff; border-radius: 16px; width: 100%; max-width: 560px; display: flex; flex-direction: column; box-shadow: 0 24px 64px rgba(0,0,0,.15); max-height: 92vh; overflow-y: auto; }
.npm__header  { display: flex; align-items: center; gap: .875rem; padding: 1.25rem 1.4rem 1rem; border-bottom: 1px solid var(--c-slate-100); position: sticky; top: 0; background: #fff; z-index: 1; }
.npm__header-ico { width: 38px; height: 38px; border-radius: 10px; background: rgba(27,94,32,.1); color: #1b5e20; display: flex; align-items: center; justify-content: center; flex-shrink: 0; font-size: 1.1rem; }
.npm__title { font-size: 1rem; font-weight: 800; color: #0f2611; margin: 0 0 .1rem; }
.npm__sub   { font-size: .75rem; color: var(--c-slate-400); margin: 0; }
.npm__close { margin-left: auto; background: var(--c-slate-100); border: none; width: 30px; height: 30px; border-radius: 8px; cursor: pointer; display: flex; align-items: center; justify-content: center; color: var(--c-slate-500); flex-shrink: 0; }

.npm__stepper { display: flex; padding: .875rem 1.4rem; gap: 0; border-bottom: 1px solid var(--c-slate-100); }
.npm__step { display: flex; align-items: center; gap: .5rem; flex: 1; }
.npm__step:not(:last-child)::after { content: ''; flex: 1; height: 1px; background: var(--c-slate-200); margin: 0 .5rem; }
.npm__step-dot { width: 22px; height: 22px; border-radius: 50%; background: var(--c-slate-200); color: var(--c-slate-500); font-size: .72rem; font-weight: 700; display: flex; align-items: center; justify-content: center; flex-shrink: 0; }
.npm__step--active .npm__step-dot { background: #1b5e20; color: #fff; }
.npm__step--done   .npm__step-dot { background: #86efac; color: #1b5e20; }
.npm__step-label { font-size: .72rem; font-weight: 600; color: var(--c-slate-400); white-space: nowrap; }
.npm__step--active .npm__step-label { color: #1b5e20; }
.npm__step--done   .npm__step-label { color: #60725d; }

.npm__body  { padding: 1.25rem 1.4rem; display: flex; flex-direction: column; gap: .875rem; flex: 1; }
.npm__alert { background: #fef2f2; border: 1px solid #fecaca; color: #dc2626; padding: .65rem .875rem; border-radius: 8px; font-size: .82rem; }
.npm__field { display: flex; flex-direction: column; gap: .3rem; }
.npm__label { font-size: .72rem; font-weight: 700; color: #374151; text-transform: uppercase; letter-spacing: .04em; }
.npm__hint  { font-weight: 400; text-transform: none; color: var(--c-slate-400); }
.npm__input { background: var(--c-slate-50); border: 1.5px solid var(--c-slate-200); border-radius: 9px; padding: .6rem .875rem; font-size: .875rem; color: #0f2611; width: 100%; box-sizing: border-box; }
.npm__input:focus { outline: none; border-color: #1b5e20; box-shadow: 0 0 0 3px rgba(27,94,32,.08); }
.npm__input--sm { max-width: 140px; flex-shrink: 0; }
.npm__input--xs { max-width: 100px; flex-shrink: 0; }
.npm__textarea { resize: vertical; min-height: 60px; }
.npm__row { display: flex; gap: .75rem; }
.npm__row .npm__field { flex: 1; }

.npm__tipo-btns { display: flex; gap: .5rem; }
.npm__tipo-btn  { flex: 1; display: flex; flex-direction: column; align-items: center; gap: .25rem; padding: .65rem .5rem; border: 1.5px solid var(--c-slate-200); border-radius: 9px; background: var(--c-slate-50); cursor: pointer; font-size: .8rem; color: #60725d; font-weight: 600; transition: all .12s; }
.npm__tipo-btn--active { border-color: #1b5e20; background: #f0fdf4; color: #1b5e20; }
.npm__tipo-ico { font-size: 1.25rem; }

/* ── Paso 2: modo tabs ── */
.npm__modo-tabs { display: flex; background: var(--c-slate-100); border-radius: 10px; padding: 3px; gap: 0; }
.npm__modo-tab  { flex: 1; padding: .5rem .75rem; border-radius: 8px; border: none; background: none; font-size: .82rem; font-weight: 600; color: var(--c-slate-500); cursor: pointer; transition: all .12s; }
.npm__modo-tab--active { background: #fff; color: #1b5e20; box-shadow: 0 1px 4px rgba(0,0,0,.1); }

/* ── Drop zone ── */
.npm__dropzone { border: 2px dashed #c8e6c9; border-radius: 12px; padding: 2.5rem 1.5rem; display: flex; flex-direction: column; align-items: center; gap: .5rem; cursor: pointer; transition: border-color .15s, background .15s; background: #fafcfa; text-align: center; }
.npm__dropzone:hover, .npm__dropzone--drag { border-color: #1b5e20; background: #f0fdf4; }
.npm__drop-ico  { font-size: 2.25rem; color: #1b5e20; }
.npm__drop-main { font-size: .9rem; font-weight: 700; color: #0f2611; margin: 0; }
.npm__drop-sub  { font-size: .8rem; color: #60725d; margin: 0; }
.npm__drop-formats { font-size: .72rem; color: var(--c-slate-400); background: var(--c-slate-100); padding: .2em .75em; border-radius: 5px; margin: .25rem 0 0; letter-spacing: .03em; }

/* ── Preview ── */
.npm__preview { display: flex; flex-direction: column; gap: .75rem; }
.npm__preview-hdr { display: flex; align-items: center; justify-content: space-between; gap: .5rem; background: #f6faf6; border: 1px solid #e8f0e9; border-radius: 9px; padding: .65rem .875rem; }
.npm__preview-title { font-size: .875rem; font-weight: 700; color: #0f2611; }
.npm__preview-count { font-size: .75rem; color: #60725d; margin-left: .4rem; }
.npm__preview-sep { font-size: .75rem; font-weight: 700; color: #374151; margin: .25rem 0 .1rem; padding: 0; }
.npm__preview-sep--ok   { color: #15803d; }
.npm__preview-sep--warn { color: #b45309; }

/* ── Task rows ── */
.npm__tareas-hdr { display: flex; align-items: center; justify-content: space-between; }
.npm__tareas-count { font-size: .8rem; color: #60725d; font-weight: 600; }
.npm__btn-agregar { background: #1b5e20; color: #fff; border: none; padding: .4rem .875rem; border-radius: 7px; font-size: .8rem; font-weight: 600; cursor: pointer; }
.npm__btn-agregar--lg { padding: .6rem 1.25rem; font-size: .875rem; }
.npm__tareas-empty { text-align: center; padding: 2rem; color: #60725d; font-size: .875rem; display: flex; flex-direction: column; align-items: center; gap: .75rem; }

.npm__tareas-list { display: flex; flex-direction: column; gap: .5rem; }
.npm__tarea-row { background: var(--c-slate-50); border: 1.5px solid var(--c-slate-200); border-radius: 10px; padding: .65rem .875rem; display: flex; flex-direction: column; gap: .5rem; }
.npm__tarea-row--confirmed { border-left: 3px solid #86efac; }
.npm__tarea-row--ambigua   { border-left: 3px solid #fcd34d; background: #fffdf5; }
.npm__tarea-row-main { display: flex; align-items: center; gap: .5rem; }
.npm__tarea-row-main .npm__input { flex: 1; }
.npm__tarea-del { background: none; border: none; color: #dc2626; cursor: pointer; padding: .25rem; border-radius: 5px; display: flex; align-items: center; }
.npm__tarea-row-extra { display: flex; align-items: center; gap: .5rem; flex-wrap: wrap; }

/* Ambiguous rows */
.npm__ambigua-info    { display: flex; flex-direction: column; gap: .15rem; flex: 1; min-width: 0; }
.npm__ambigua-titulo  { font-size: .8rem; font-weight: 700; color: #0f2611; }
.npm__ambigua-desc    { font-size: .75rem; color: #b45309; }
.npm__ambigua-actions { display: flex; align-items: center; gap: .4rem; flex-wrap: wrap; }

/* Copiar plan anterior */
.npm__copiar { display: flex; flex-direction: column; gap: .4rem; border-top: 1px solid var(--c-slate-100); padding-top: .875rem; margin-top: .25rem; }
.npm__plan-copy-row { display: flex; align-items: center; gap: .75rem; padding: .5rem .75rem; background: var(--c-slate-50); border: 1px solid #e8f0e9; border-radius: 8px; }
.npm__plan-copy-info { flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 1px; }
.npm__plan-copy-titulo { font-size: .8rem; font-weight: 600; color: #0f2611; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.npm__plan-copy-meta   { font-size: .72rem; color: #60725d; }
.npm__btn-copiar { background: #f0fdf4; border: 1.5px solid #c8e6c9; color: #1b5e20; font-size: .78rem; font-weight: 700; padding: .3rem .75rem; border-radius: 7px; cursor: pointer; display: flex; align-items: center; gap: .3rem; flex-shrink: 0; }
.npm__btn-copiar:disabled { opacity: .55; cursor: not-allowed; }
.npm__plan-copy-loading { font-size: .8rem; color: var(--c-slate-400); text-align: center; padding: .5rem; }

/* Shared buttons */
.npm__btn-ghost { background: transparent; color: var(--c-slate-500); border: 1.5px solid var(--c-slate-200); padding: .6rem 1rem; border-radius: 9px; font-size: .875rem; font-weight: 600; cursor: pointer; display: inline-flex; align-items: center; gap: .35rem; }
.npm__btn-ghost--sm { padding: .35rem .7rem; font-size: .78rem; }

/* Revisión */
.npm__toggle-row { display: flex; background: var(--c-slate-100); border-radius: 7px; padding: 2px; }
.npm__toggle { padding: .3rem .7rem; border-radius: 5px; border: none; background: none; font-size: .75rem; font-weight: 600; color: var(--c-slate-500); cursor: pointer; }
.npm__toggle--on { background: #fff; color: #1b5e20; box-shadow: 0 1px 3px rgba(0,0,0,.1); }
.npm__dias { display: flex; gap: .2rem; }
.npm__dia { width: 28px; height: 28px; border-radius: 50%; border: 1.5px solid var(--c-slate-200); background: var(--c-slate-50); font-size: .72rem; font-weight: 700; color: #60725d; cursor: pointer; display: flex; align-items: center; justify-content: center; }
.npm__dia--on { border-color: #1b5e20; background: #1b5e20; color: #fff; }

.npm__resumen { display: flex; flex-direction: column; gap: .65rem; background: var(--c-slate-50); border: 1.5px solid var(--c-slate-200); border-radius: 10px; padding: 1rem 1.1rem; }
.npm__res-block { display: flex; gap: .75rem; align-items: baseline; }
.npm__res-label { font-size: .72rem; font-weight: 700; color: var(--c-slate-400); text-transform: uppercase; letter-spacing: .04em; min-width: 70px; }
.npm__res-val { font-size: .875rem; color: #0f2611; font-weight: 500; }

.npm__pub-opts { display: flex; flex-direction: column; gap: .5rem; }
.npm__pub-opt { display: flex; align-items: flex-start; gap: .75rem; padding: .875rem 1rem; border: 1.5px solid var(--c-slate-200); border-radius: 10px; cursor: pointer; }
.npm__pub-opt input { margin-top: .15rem; accent-color: #1b5e20; }
.npm__pub-opt--active { border-color: #1b5e20; background: #f0fdf4; }
.npm__pub-opt-title { font-size: .875rem; font-weight: 700; color: #0f2611; }
.npm__pub-opt-sub   { font-size: .78rem; color: #60725d; margin-top: .15rem; }

/* Footer */
.npm__footer { display: flex; align-items: center; justify-content: space-between; padding: 1rem 1.4rem; border-top: 1px solid var(--c-slate-100); position: sticky; bottom: 0; background: #fff; }
.npm__footer-right { display: flex; gap: .75rem; }
.npm__btn-primary { display: inline-flex; align-items: center; gap: .4rem; background: #1b5e20; color: #fff; border: none; padding: .6rem 1.1rem; border-radius: 9px; font-size: .875rem; font-weight: 700; cursor: pointer; }
.npm__btn-primary:hover:not(:disabled) { background: #144a18; }
.npm__btn-primary:disabled { opacity: .55; cursor: not-allowed; }

/* Responsable autocomplete */
.npm__resp-wrap { position: relative; flex: 1; }
.npm__resp-wrap .npm__input { width: 100%; }
.npm__resp-drop { position: absolute; top: calc(100% + 4px); left: 0; right: 0; background: #fff; border: 1.5px solid var(--c-slate-200); border-radius: 9px; box-shadow: 0 4px 16px rgba(0,0,0,.1); z-index: 100; overflow: hidden; }
.npm__resp-opcion { padding: .5rem .875rem; font-size: .82rem; color: #0f2611; cursor: pointer; transition: background .1s; }
.npm__resp-opcion:hover, .npm__resp-opcion--sel { background: #f0fdf4; color: #1b5e20; }
.npm__resp-none { padding: .5rem .875rem; font-size: .82rem; color: var(--c-slate-400); }
.npm__resp-clear { padding: .4rem .875rem; font-size: .78rem; color: #dc2626; cursor: pointer; border-top: 1px solid var(--c-slate-100); }
.npm__resp-clear:hover { background: #fef2f2; }
.npm__input--resp-ok { border-color: #86efac; }

/* Priority pills */
.npm__prio-row { display: flex; gap: .2rem; }
.npm__prio-pill { width: 28px; height: 28px; border-radius: 50%; border: 1.5px solid var(--c-slate-200); background: var(--c-slate-50); font-size: .82rem; font-weight: 700; color: var(--c-slate-500); cursor: pointer; display: flex; align-items: center; justify-content: center; transition: all .12s; padding: 0; }
.npm__prio-pill--on.npm__prio-pill--baja    { border-color: #60a5fa; background: #eff6ff; color: #2563eb; }
.npm__prio-pill--on.npm__prio-pill--normal  { border-color: #1b5e20; background: #f0fdf4; color: #1b5e20; }
.npm__prio-pill--on.npm__prio-pill--alta    { border-color: #f59e0b; background: #fffbeb; color: #d97706; }
.npm__prio-pill--on.npm__prio-pill--urgente { border-color: #dc2626; background: #fef2f2; color: #dc2626; }
</style>
