<script setup>
import { ref, onMounted, computed } from 'vue'
import DsSpinner from '../../design-system/components/Spinner.vue'
import ModalPlanTarea from './ModalPlanTarea.vue'
import {
  createPlanTrabajo, updatePlanTrabajo,
  createPlanTarea, updatePlanTarea, deletePlanTarea,
} from '../../lib/api.js'

const props = defineProps({
  plan: { type: Object, default: null },
})
const emit = defineEmits(['close', 'saved'])

const ROL_EMOJI = {
  cultivador: '🌱', manicura: '✂️', supervisor: '👁', admin: '⚙️', dispensador: '🏪',
}

function diaALabel(dia) {
  const d = Math.max(0, dia ?? 0)
  const sem = Math.floor(d / 7) + 1
  const ds  = (d % 7) + 1
  return `S${sem}D${ds}`
}

function rolesArray(rol_sugerido) {
  if (!rol_sugerido) return []
  return rol_sugerido.split(',').map(s => s.trim()).filter(Boolean)
}

const TIPO_EMOJI = {
  riego: '💧', poda: '✂️', medicion: '📏', limpieza: '🧹', cosecha: '🌿',
  trasplante: '🪴', inspeccion: '🔍', nutricion: '🧪', defoliacion: '🍃',
  scrog_lst: '🕸️', ajuste_luz: '💡', revision_plagas: '🔬', otro: '📋',
}
const TIPO_LABEL = {
  riego: 'Riego', poda: 'Poda', medicion: 'Medición', limpieza: 'Limpieza',
  cosecha: 'Cosecha', trasplante: 'Trasplante', inspeccion: 'Inspección',
  nutricion: 'Nutrición', defoliacion: 'Defoliación', scrog_lst: 'SCROG/LST',
  ajuste_luz: 'Ajuste de luz', revision_plagas: 'Revisión de plagas', otro: 'Otro',
}
const PRIO_DOT = { baja: '🟢', normal: '🔵', alta: '🟠', urgente: '🔴' }

const isEdit = computed(() => !!props.plan)
const saving = ref(false)
const error  = ref(null)

const form = ref({
  titulo: props.plan?.titulo ?? '',
  notas:  props.plan?.notas  ?? '',
})

let nextTmp = 0
const tareas = ref([])

// tarea en edición dentro del modal hijo
const tareaEdicion = ref(null)   // null = modal cerrado
const showModalTarea = ref(false)

function makeTarea(pt = null) {
  return {
    _tmpId:         nextTmp++,
    id:             pt?.id             ?? null,
    tipo:           pt?.tipo           ?? 'riego',
    titulo:         pt?.titulo         ?? '',
    descripcion:    pt?.descripcion    ?? '',
    dia_relativo:   pt?.dia_relativo   ?? 0,
    prioridad:      pt?.prioridad      ?? 'normal',
    rol_sugerido:   pt?.rol_sugerido   ?? '',
    responsable_id: pt?.responsable?.id ?? pt?.responsable_id ?? null,
    responsable:    pt?.responsable    ?? null,
    _deleted:       false,
  }
}

onMounted(() => {
  const pts = props.plan?.plan_tareas ?? []
  tareas.value = [...pts]
    .sort((a, b) => (a.dia_relativo ?? 0) - (b.dia_relativo ?? 0))
    .map(makeTarea)
})

const tareasVisibles = computed(() =>
  tareas.value
    .filter(t => !t._deleted)
    .sort((a, b) => (a.dia_relativo ?? 0) - (b.dia_relativo ?? 0))
)

function abrirNuevaTarea() {
  tareaEdicion.value = null
  showModalTarea.value = true
}

function abrirEditarTarea(t) {
  tareaEdicion.value = t
  showModalTarea.value = true
}

function onTareaGuardada(datos) {
  showModalTarea.value = false
  if (tareaEdicion.value) {
    // edit: datos es un objeto individual
    const idx = tareas.value.findIndex(t => t._tmpId === tareaEdicion.value._tmpId)
    if (idx >= 0) Object.assign(tareas.value[idx], datos)
  } else {
    // nueva: datos es un array (un objeto por cada día seleccionado)
    for (const d of datos) tareas.value.push(makeTarea(d))
  }
  tareaEdicion.value = null
}

function eliminarTarea(t) {
  if (t.id) {
    t._deleted = true
  } else {
    tareas.value = tareas.value.filter(x => x._tmpId !== t._tmpId)
  }
}

function descripcionPreview(t) {
  if (!t.descripcion) return ''
  const primera = t.descripcion.split('\n')[0]
  return primera.length > 60 ? primera.slice(0, 58) + '…' : primera
}

async function guardar() {
  if (!form.value.titulo.trim()) { error.value = 'El título es obligatorio'; return }
  saving.value = true; error.value = null
  try {
    let planId
    if (isEdit.value) {
      await updatePlanTrabajo(props.plan.id, {
        plan_trabajo: { titulo: form.value.titulo, notas: form.value.notas, es_plantilla: true }
      })
      planId = props.plan.id
    } else {
      const { data } = await createPlanTrabajo({
        plan_trabajo: { titulo: form.value.titulo, notas: form.value.notas, es_plantilla: true }
      })
      planId = data.id
    }

    for (const t of tareas.value) {
      const payload = {
        tipo:           t.tipo,
        titulo:         t.titulo,
        descripcion:    t.descripcion,
        dia_relativo:   t.dia_relativo ?? 0,
        prioridad:      t.prioridad,
        rol_sugerido:   t.rol_sugerido   || null,
        responsable_id: t.responsable_id || null,
      }
      if (t._deleted && t.id) {
        await deletePlanTarea(planId, t.id)
      } else if (t.id && !t._deleted) {
        await updatePlanTarea(planId, t.id, payload)
      } else if (!t._deleted && !t.id) {
        await createPlanTarea(planId, payload)
      }
    }

    emit('saved')
  } catch (e) {
    error.value = e?.response?.data?.errors?.join(', ') || e?.response?.data?.error || 'Error al guardar'
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <Teleport to="body">
    <div class="ep__overlay" @click.self="$emit('close')">
      <div class="ep__panel">

        <!-- Header -->
        <div class="ep__hdr">
          <div class="ep__hdr-ico"><i class="bi bi-clipboard2-check"></i></div>
          <div>
            <h2 class="ep__title">{{ isEdit ? 'Editar plantilla' : 'Nueva plantilla' }}</h2>
            <p class="ep__sub">Plantillas reutilizables sin fechas fijas</p>
          </div>
          <button class="ep__close" @click="$emit('close')"><i class="bi bi-x-lg"></i></button>
        </div>

        <!-- Body -->
        <div class="ep__body">
          <div v-if="error" class="ep__alert">{{ error }}</div>

          <!-- Datos básicos -->
          <div class="ep__section">
            <div class="ep__field">
              <label class="ep__label">Título de la plantilla</label>
              <input class="ep__input" v-model="form.titulo" placeholder="Ej: Plan floración Sherbet, Plan semanal vegetativo…" />
            </div>
            <div class="ep__field">
              <label class="ep__label">Notas <span class="ep__hint">(opcional)</span></label>
              <textarea class="ep__input ep__textarea" v-model="form.notas" rows="2" placeholder="Descripción general del plan…"></textarea>
            </div>
          </div>

          <!-- Tareas -->
          <div class="ep__section">
            <div class="ep__section-hdr">
              <span class="ep__section-title">Tareas</span>
              <span class="ep__section-count">{{ tareasVisibles.length }}</span>
              <button class="ep__btn-add" @click="abrirNuevaTarea">
                <i class="bi bi-plus-lg"></i> Agregar tarea
              </button>
            </div>

            <!-- Empty -->
            <div v-if="tareasVisibles.length === 0" class="ep__tareas-empty" @click="abrirNuevaTarea">
              <i class="bi bi-list-task ep__empty-ico"></i>
              <div>
                <div class="ep__empty-msg">Sin tareas configuradas</div>
                <div class="ep__empty-sub">Hacé click para agregar la primera tarea</div>
              </div>
            </div>

            <!-- Lista de tareas -->
            <div v-else class="ep__tareas-list">
              <div
                v-for="t in tareasVisibles"
                :key="t._tmpId"
                class="ep__tarea-card"
                @click="abrirEditarTarea(t)"
              >
                <!-- Día badge -->
                <div class="ep__tarea-dia">
                  <div class="ep__dia-num">{{ diaALabel(t.dia_relativo) }}</div>
                  <div class="ep__dia-sub">Día {{ (t.dia_relativo ?? 0) + 1 }}</div>
                </div>

                <!-- Info -->
                <div class="ep__tarea-info">
                  <div class="ep__tarea-top">
                    <span class="ep__tarea-emoji">{{ TIPO_EMOJI[t.tipo] || '📋' }}</span>
                    <span class="ep__tarea-nombre">{{ t.titulo || TIPO_LABEL[t.tipo] || t.tipo }}</span>
                    <template v-for="rol in rolesArray(t.rol_sugerido)" :key="rol">
                      <span class="ep__tarea-rol">{{ ROL_EMOJI[rol] || '' }} {{ rol }}</span>
                    </template>
                  </div>
                  <div v-if="t.descripcion" class="ep__tarea-desc">{{ descripcionPreview(t) }}</div>
                </div>

                <!-- Prioridad + acciones -->
                <div class="ep__tarea-meta">
                  <span class="ep__prio-dot">{{ PRIO_DOT[t.prioridad] || '🔵' }}</span>
                  <button class="ep__tarea-del" @click.stop="eliminarTarea(t)" title="Eliminar">
                    <i class="bi bi-trash3"></i>
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Footer -->
        <div class="ep__footer">
          <button class="ep__btn-ghost" @click="$emit('close')">Cancelar</button>
          <button class="ep__btn-primary" :disabled="saving" @click="guardar">
            <DsSpinner v-if="saving" :size="14" />
            {{ saving ? 'Guardando…' : (isEdit ? 'Guardar cambios' : 'Crear plantilla') }}
          </button>
        </div>

      </div>
    </div>

    <!-- Modal de tarea (se monta sobre el overlay) -->
    <ModalPlanTarea
      v-if="showModalTarea"
      :tarea="tareaEdicion"
      @close="showModalTarea = false; tareaEdicion = null"
      @saved="onTareaGuardada"
    />

  </Teleport>
</template>

<style scoped>
.ep__overlay { position: fixed; inset: 0; background: rgba(0,0,0,.45); display: flex; align-items: center; justify-content: center; z-index: 1060; padding: 1rem; backdrop-filter: blur(3px); }
.ep__panel   { background: #fff; border-radius: 16px; width: 100%; max-width: 580px; display: flex; flex-direction: column; box-shadow: 0 24px 64px rgba(0,0,0,.15); max-height: 92vh; }

/* Header */
.ep__hdr     { display: flex; align-items: center; gap: .875rem; padding: 1.25rem 1.4rem 1rem; border-bottom: 1px solid #f1f5f9; flex-shrink: 0; }
.ep__hdr-ico { width: 38px; height: 38px; border-radius: 10px; background: #f0fdf4; color: #1b5e20; display: flex; align-items: center; justify-content: center; font-size: 1.1rem; flex-shrink: 0; }
.ep__title   { font-size: 1rem; font-weight: 800; color: #0f2611; margin: 0 0 .1rem; }
.ep__sub     { font-size: .75rem; color: #94a3b8; margin: 0; }
.ep__close   { margin-left: auto; background: #f1f5f1; border: none; width: 30px; height: 30px; border-radius: 8px; cursor: pointer; display: flex; align-items: center; justify-content: center; color: #64748b; flex-shrink: 0; }
.ep__close:hover { background: #c8e6c9; color: #1b5e20; }

/* Body */
.ep__body  { padding: 1.25rem 1.4rem; display: flex; flex-direction: column; gap: 1.25rem; overflow-y: auto; flex: 1; }
.ep__alert { background: #fef2f2; border: 1px solid #fecaca; color: #dc2626; padding: .65rem .875rem; border-radius: 8px; font-size: .82rem; }

/* Sections */
.ep__section { display: flex; flex-direction: column; gap: .75rem; }
.ep__section-hdr { display: flex; align-items: center; gap: .5rem; }
.ep__section-title { font-size: .78rem; font-weight: 800; color: #374151; text-transform: uppercase; letter-spacing: .05em; }
.ep__section-count { font-size: .72rem; font-weight: 700; color: #1b5e20; background: #f0fdf4; padding: .15em .5em; border-radius: 999px; }
.ep__btn-add { margin-left: auto; display: inline-flex; align-items: center; gap: .3rem; background: #1b5e20; color: #fff; border: none; padding: .4rem .875rem; border-radius: 8px; font-size: .78rem; font-weight: 700; cursor: pointer; transition: background .12s; }
.ep__btn-add:hover { background: #144a18; }

/* Fields */
.ep__field { display: flex; flex-direction: column; gap: .3rem; }
.ep__label { font-size: .72rem; font-weight: 700; color: #374151; text-transform: uppercase; letter-spacing: .04em; }
.ep__hint  { font-weight: 400; text-transform: none; color: #94a3b8; }
.ep__input { background: #f8fafc; border: 1.5px solid #e2e8f0; border-radius: 9px; padding: .6rem .875rem; font-size: .875rem; color: #0f2611; width: 100%; box-sizing: border-box; }
.ep__input:focus { outline: none; border-color: #1b5e20; box-shadow: 0 0 0 3px rgba(27,94,32,.08); }
.ep__textarea { resize: vertical; min-height: 60px; }

/* Empty */
.ep__tareas-empty { display: flex; align-items: center; gap: .875rem; padding: 1.5rem 1.1rem; background: #f8fafc; border: 2px dashed #e2e8f0; border-radius: 12px; cursor: pointer; transition: all .15s; }
.ep__tareas-empty:hover { border-color: #1b5e20; background: #f0fdf4; }
.ep__empty-ico { font-size: 1.5rem; color: #94a3b8; }
.ep__empty-msg { font-size: .875rem; font-weight: 700; color: #0f172a; }
.ep__empty-sub { font-size: .75rem; color: #94a3b8; margin-top: .1rem; }

/* Task list */
.ep__tareas-list { display: flex; flex-direction: column; gap: .4rem; }
.ep__tarea-card  { display: flex; align-items: center; gap: .75rem; padding: .75rem .875rem; background: #fff; border: 1.5px solid #e2e8f0; border-radius: 10px; cursor: pointer; transition: all .15s; }
.ep__tarea-card:hover { border-color: #1b5e20; background: #f9fefb; box-shadow: 0 2px 8px rgba(27,94,32,.06); }

.ep__tarea-dia  { flex-shrink: 0; display: flex; flex-direction: column; align-items: center; gap: .15rem; }
.ep__dia-num    { font-size: .7rem; font-weight: 800; color: #1b5e20; background: #dcfce7; padding: .25em .5em; border-radius: 6px; min-width: 36px; text-align: center; }
.ep__dia-sub    { font-size: .6rem; color: #94a3b8; text-align: center; }

.ep__tarea-info { flex: 1; min-width: 0; }
.ep__tarea-top  { display: flex; align-items: center; gap: .4rem; flex-wrap: wrap; }
.ep__tarea-emoji { font-size: 1rem; flex-shrink: 0; }
.ep__tarea-nombre { font-size: .875rem; font-weight: 700; color: #0f172a; }
.ep__tarea-rol  { font-size: .68rem; font-weight: 600; color: #1b5e20; background: #f0fdf4; padding: .1em .45em; border-radius: 4px; flex-shrink: 0; }
.ep__tarea-desc { font-size: .75rem; color: #64748b; margin-top: .2rem; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }

.ep__tarea-meta { display: flex; align-items: center; gap: .4rem; flex-shrink: 0; }
.ep__prio-dot   { font-size: .85rem; }
.ep__tarea-del  { background: none; border: none; color: #dc2626; cursor: pointer; padding: .25rem; border-radius: 5px; display: flex; align-items: center; opacity: .6; }
.ep__tarea-del:hover { opacity: 1; background: #fef2f2; }

/* Footer */
.ep__footer { display: flex; align-items: center; justify-content: flex-end; gap: .75rem; padding: 1rem 1.4rem; border-top: 1px solid #f1f5f9; flex-shrink: 0; }
.ep__btn-ghost   { background: transparent; color: #64748b; border: 1.5px solid #e2e8f0; padding: .6rem 1rem; border-radius: 9px; font-size: .875rem; font-weight: 600; cursor: pointer; }
.ep__btn-primary { display: inline-flex; align-items: center; gap: .4rem; background: #1b5e20; color: #fff; border: none; padding: .6rem 1.25rem; border-radius: 9px; font-size: .875rem; font-weight: 700; cursor: pointer; }
.ep__btn-primary:hover:not(:disabled) { background: #144a18; }
.ep__btn-primary:disabled { opacity: .55; cursor: not-allowed; }
</style>
