<script setup>
import { ref, onMounted, computed } from 'vue'
import DsSpinner from '../../design-system/components/Spinner.vue'
import ModalPlanTarea from './ModalPlanTarea.vue'
import PlanCalendario from './PlanCalendario.vue'
import {
  createPlanTrabajo, updatePlanTrabajo,
  createPlanTarea, updatePlanTarea, deletePlanTarea,
} from '../../lib/api.js'

const props = defineProps({
  plan: { type: Object, default: null },
})
const emit = defineEmits(['close', 'saved'])

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

// Las tareas agrupadas por semana del ciclo: así se arma un plan en la cabeza («la semana 3
// defolio») y así se ve en el calendario de al lado (7-oct-2026).
const porSemana = computed(() => {
  const grupos = new Map()
  for (const t of tareasVisibles.value) {
    const s = Math.floor(Math.max(0, t.dia_relativo ?? 0) / 7) + 1
    if (!grupos.has(s)) grupos.set(s, [])
    grupos.get(s).push(t)
  }
  return [...grupos.entries()].sort((a, b) => a[0] - b[0]).map(([semana, ts]) => ({ semana, tareas: ts }))
})
const resumenTareas = computed(() => {
  const n = tareasVisibles.value.length
  const sem = porSemana.value.length ? porSemana.value[porSemana.value.length - 1].semana : 0
  return `${n} ${n === 1 ? 'tarea' : 'tareas'}` + (sem ? ` en ${sem} ${sem === 1 ? 'semana' : 'semanas'}` : '')
})
// «día 3» dentro de la semana; el plan no tiene fechas, así que no es un día de la semana real.
const diaDeSemana = (t) => `día ${(Math.max(0, t.dia_relativo ?? 0) % 7) + 1}`

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
  <!-- Rediseño 7-oct-2026: el mismo lenguaje que la dispensa. A la izquierda se arma (nombre y
       tareas por semana); a la derecha «Así queda», el calendario del plan en vivo. -->
  <Teleport to="body">
    <div v-modal="() => $emit('close')" class="ep__overlay">
      <div class="ep__panel" role="dialog" aria-labelledby="ep-titulo">

        <div class="ep__hdr">
          <div class="ep__hdr-txt">
            <span class="ep__sup">{{ isEdit ? 'Editar plan' : 'Plan nuevo' }}</span>
            <h2 id="ep-titulo" class="ep__title">{{ form.titulo || 'Sin nombre todavía' }}</h2>
          </div>
          <button class="ep__close" aria-label="Cerrar" @click="$emit('close')"><i class="bi bi-x-lg"></i></button>
        </div>

        <div class="ep__cuerpo">
          <div class="ep__body">
            <div v-if="error" class="ep__alert">{{ error }}</div>

            <section class="ep__section">
              <div class="ep__field">
                <label class="ep__label" for="ep-nombre">Nombre del plan</label>
                <input id="ep-nombre" class="ep__input" v-model="form.titulo" placeholder="Ej: Floración 9 semanas, Vege 4 semanas…" />
              </div>
              <div class="ep__field">
                <label class="ep__label" for="ep-notas">Para qué es <span class="ep__hint">(opcional)</span></label>
                <textarea id="ep-notas" class="ep__input ep__textarea" v-model="form.notas" rows="2" placeholder="Ej: genéticas fotoperiódicas en sustrato, desde el cambio a 12/12"></textarea>
              </div>
              <p class="ep__nota">No tiene fechas: el día 1 es el día que lo aplicás a un lote (o el que elijas al aplicarlo).</p>
            </section>

            <section class="ep__section">
              <div class="ep__section-hdr">
                <h3 class="ep__section-title">Tareas</h3>
                <span class="ep__section-count">{{ tareasVisibles.length }}</span>
                <button class="ep__btn-add" @click="abrirNuevaTarea"><i class="bi bi-plus-lg"></i> Agregar tarea</button>
              </div>

              <button v-if="!tareasVisibles.length" type="button" class="ep__tareas-empty" @click="abrirNuevaTarea">
                <i class="bi bi-list-task ep__empty-ico"></i>
                <span><span class="ep__empty-msg">Todavía no tiene tareas</span><br>
                <span class="ep__empty-sub">Agregá la primera: qué, qué día del ciclo, y si se repite.</span></span>
              </button>

              <div v-for="g in porSemana" :key="g.semana" class="ep__semana">
                <div class="ep__semana-tit">Semana {{ g.semana }}</div>
                <div v-for="t in g.tareas" :key="t._tmpId" class="ep__tarea">
                  <button type="button" class="ep__tarea-main" @click="abrirEditarTarea(t)">
                    <span class="ep__tarea-dia">{{ diaDeSemana(t) }}</span>
                    <span class="ep__tarea-emoji">{{ TIPO_EMOJI[t.tipo] || '📋' }}</span>
                    <span class="ep__tarea-info">
                      <span class="ep__tarea-nombre">{{ t.titulo || TIPO_LABEL[t.tipo] || t.tipo }}</span>
                      <span v-if="t.descripcion" class="ep__tarea-desc">{{ descripcionPreview(t) }}</span>
                    </span>
                    <span v-if="t.prioridad === 'alta' || t.prioridad === 'urgente'" class="ep__tarea-prio">{{ t.prioridad }}</span>
                  </button>
                  <button class="ep__tarea-del" :aria-label="`Sacar ${t.titulo || TIPO_LABEL[t.tipo]}`" @click="eliminarTarea(t)">
                    <i class="bi bi-trash3"></i>
                  </button>
                </div>
              </div>
            </section>
          </div>

          <aside class="ep__resumen" aria-label="Así queda">
            <div class="ep__resumen-tit">Así queda</div>
            <PlanCalendario :tareas="tareasVisibles" />
            <p class="ep__resumen-pie">
              {{ resumenTareas }}. Al aplicarlo, cada tarea aparece en la lista 7 días antes de su fecha.
            </p>
          </aside>
        </div>

        <div class="ep__footer">
          <button class="ep__btn-ghost" @click="$emit('close')">Cancelar</button>
          <button class="ep__btn-primary" :disabled="saving" @click="guardar">
            <DsSpinner v-if="saving" :size="14" />
            {{ saving ? 'Guardando…' : (isEdit ? 'Guardar cambios' : 'Crear plan') }}
          </button>
        </div>
      </div>
    </div>

    <ModalPlanTarea
      v-if="showModalTarea"
      :tarea="tareaEdicion"
      @close="showModalTarea = false; tareaEdicion = null"
      @saved="onTareaGuardada"
    />
  </Teleport>
</template>

<style scoped>
.ep__overlay { position: fixed; inset: 0; background: rgba(15,23,42,.45); display: flex; align-items: center; justify-content: center; z-index: 1050; padding: 1rem; }
.ep__panel { background: #fff; border-radius: 18px; width: 100%; max-width: 1080px; height: 90vh; display: flex; flex-direction: column; overflow: hidden; box-shadow: 0 24px 64px rgba(15,42,30,.25); }
.ep__hdr { display: flex; align-items: flex-start; gap: 1rem; padding: 1.1rem 1.5rem; border-bottom: 1px solid var(--c-slate-200); }
.ep__hdr-txt { flex: 1; min-width: 0; }
.ep__sup { font-size: .7rem; font-weight: 700; letter-spacing: .06em; text-transform: uppercase; color: var(--c-slate-500); }
.ep__title { margin: .1rem 0 0; font-size: 1.25rem; font-weight: 800; color: var(--c-slate-900); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.ep__close { width: 40px; height: 40px; border-radius: 10px; border: 1px solid var(--c-slate-200); background: #fff; color: var(--c-slate-500); cursor: pointer; }
.ep__cuerpo { flex: 1; min-height: 0; display: flex; }
.ep__body { flex: 1; min-width: 0; overflow-y: auto; padding: 1.25rem 1.5rem; display: flex; flex-direction: column; gap: 1.2rem; }
.ep__alert { background: var(--c-rust-100); color: #991B1B; border-radius: 10px; padding: .6rem .8rem; font-size: .85rem; }
.ep__section { display: flex; flex-direction: column; gap: .7rem; }
.ep__field { display: flex; flex-direction: column; gap: .3rem; }
.ep__label { font-size: .8rem; font-weight: 700; color: var(--c-slate-700); }
.ep__hint { font-weight: 400; color: var(--c-slate-400); }
.ep__input { border: 1.5px solid var(--c-slate-300); border-radius: 10px; padding: .65rem .8rem; font-size: .9rem; font-family: inherit; }
.ep__input:focus { outline: none; border-color: var(--c-leaf-800); }
.ep__textarea { resize: vertical; }
.ep__nota { margin: 0; font-size: .8rem; color: var(--c-slate-500); }
.ep__section-hdr { display: flex; align-items: center; gap: .5rem; }
.ep__section-title { margin: 0; font-size: 1rem; font-weight: 700; }
.ep__section-count { font-size: .72rem; font-weight: 700; background: var(--c-slate-100); color: var(--c-slate-600); border-radius: 999px; padding: .1rem .5rem; }
.ep__btn-add { margin-left: auto; height: 38px; padding: 0 .9rem; border-radius: 10px; border: 1.5px solid var(--c-leaf-800); background: #fff; color: var(--c-leaf-800); font-weight: 700; font-size: .82rem; cursor: pointer; }
.ep__tareas-empty { display: flex; align-items: center; gap: .9rem; border: 1.5px dashed var(--c-leaf-300); background: var(--c-paper); border-radius: 12px; padding: 1rem; cursor: pointer; text-align: left; font: inherit; }
.ep__empty-ico { font-size: 1.4rem; color: var(--c-leaf-600); }
.ep__empty-msg { font-weight: 700; font-size: .9rem; }
.ep__empty-sub { font-size: .8rem; color: var(--c-slate-500); }
.ep__semana { display: flex; flex-direction: column; gap: .35rem; }
.ep__semana-tit { font-size: .7rem; font-weight: 700; letter-spacing: .06em; text-transform: uppercase; color: var(--c-leaf-800); margin-top: .3rem; }
.ep__tarea { display: flex; align-items: center; gap: .3rem; border: 1px solid var(--c-slate-200); border-radius: 11px; background: #fff; }
.ep__tarea:hover { border-color: var(--c-leaf-300); }
.ep__tarea-main { flex: 1; min-width: 0; display: flex; align-items: center; gap: .6rem; padding: .6rem .75rem; border: 0; background: none; cursor: pointer; text-align: left; font: inherit; }
.ep__tarea-dia { font-family: var(--font-mono); font-size: .72rem; color: var(--c-slate-500); width: 44px; flex-shrink: 0; }
.ep__tarea-emoji { flex-shrink: 0; }
.ep__tarea-info { display: flex; flex-direction: column; min-width: 0; }
.ep__tarea-nombre { font-weight: 600; font-size: .88rem; color: var(--c-slate-900); }
.ep__tarea-desc { font-size: .75rem; color: var(--c-slate-500); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.ep__tarea-prio { margin-left: auto; font-size: .68rem; font-weight: 700; text-transform: uppercase; color: var(--c-gold-500); background: var(--c-amber-100); border-radius: 999px; padding: .1rem .5rem; }
.ep__tarea-del { width: 40px; height: 40px; border: 0; background: none; color: var(--c-slate-400); cursor: pointer; border-radius: 8px; flex-shrink: 0; }
.ep__tarea-del:hover { color: var(--c-rust-600); background: var(--c-rust-100); }
.ep__resumen { width: 380px; flex-shrink: 0; border-left: 1px solid var(--c-slate-200); background: var(--c-paper); padding: 1.25rem; overflow-y: auto; display: flex; flex-direction: column; gap: .8rem; }
.ep__resumen-tit { font-size: .7rem; font-weight: 700; letter-spacing: .06em; text-transform: uppercase; color: var(--c-slate-500); }
.ep__resumen-pie { margin: 0; font-size: .8rem; color: var(--c-slate-600); line-height: 1.5; }
.ep__footer { display: flex; justify-content: flex-end; gap: .7rem; padding: .9rem 1.5rem; border-top: 1px solid var(--c-slate-200); }
.ep__btn-ghost { height: 44px; padding: 0 1.1rem; border-radius: 10px; border: 1px solid var(--c-slate-300); background: #fff; font-weight: 600; cursor: pointer; }
.ep__btn-primary { height: 44px; padding: 0 1.3rem; border-radius: 10px; border: 0; background: var(--c-leaf-800); color: #fff; font-weight: 700; cursor: pointer; display: inline-flex; align-items: center; gap: .4rem; }
.ep__btn-primary:disabled { opacity: .6; cursor: not-allowed; }
@media (max-width: 900px) {
  .ep__resumen { display: none; }
  .ep__panel { max-width: 640px; }
}
@media (max-width: 480px) {
  .ep__overlay { padding: 0; }
  .ep__panel { height: 100%; border-radius: 0; }
}
</style>
