<script setup>
import { ref, computed, watch, onMounted } from 'vue'
import AppDatePicker from '../ui/AppDatePicker.vue'
import DsSpinner from '../../design-system/components/Spinner.vue'
import { createAplicacion, previewAplicacion, listLotes, listSalas } from '../../lib/api.js'
import { useUsoPersonal } from '../../composables/useUsoPersonal.js'
import { useToast } from '../../composables/useToast.js'
import { hoyISO } from '../../utils/dates.js'

const props = defineProps({
  plan: { type: Object, required: true },
})
const emit = defineEmits(['close', 'applied'])
const toast = useToast()

const TIPO_LABEL = {
  riego: 'Riego', poda: 'Poda', medicion: 'Medición', limpieza: 'Limpieza',
  cosecha: 'Cosecha', trasplante: 'Trasplante', inspeccion: 'Inspección',
  nutricion: 'Nutrición', defoliacion: 'Defoliación', scrog_lst: 'SCROG/LST',
  ajuste_luz: 'Ajuste de luz', revision_plagas: 'Revisión de plagas', otro: 'Otro',
}

const TIPO_SALA_LABEL = {
  cultivo:     'Cultivo',
  vegetativo:  'Vegetativo',
  floracion:   'Floración',
  cosecha:     'Cosecha',
  curado:      'Curado',
  madre:       'Madre',
  clones:      'Clones',
  manicura:    'Manicura',
  enraizado: 'Enraizado',
}

function isoHoy() { return hoyISO() }
function formatFecha(iso) {
  const [y, m, d] = iso.split('-')
  return `${d}/${m}/${y}`
}

// ── State ──
const saving = ref(false)
const error  = ref(null)

const objetivoTipo = ref('')          // '' | 'Lote' | 'Sala'
const objetivoId   = ref(null)
const fechaInicio  = ref(isoHoy())

const lotes = ref([])
const salas = ref([])
const cargando = ref(false)

// Las fechas las calcula el backend (`Planes::Calendario`, la misma cuenta que al aplicar). Antes
// esta pantalla las calculaba por su cuenta: la regla vivía en dos lados.
const { esPersonal } = useUsoPersonal()
const preview = ref(null)
const tareasPreview = computed(() => preview.value?.tareas || [])
async function pedirPreview() {
  if (!fechaInicio.value) { preview.value = null; return }
  try {
    const { data } = await previewAplicacion({
      plan_trabajo_id: props.plan.id, fecha_inicio: fechaInicio.value,
      objetivo_tipo: objetivoTipo.value || undefined, objetivo_id: objetivoId.value || undefined,
    })
    preview.value = data
  } catch { preview.value = null }
}
watch([fechaInicio, objetivoTipo, objetivoId], pedirPreview, { immediate: true })

// Computed: objetivo seleccionado (para mostrar nombre)
const objetivoSeleccionado = computed(() => {
  if (!objetivoTipo.value || !objetivoId.value) return null
  const lista = objetivoTipo.value === 'Lote' ? lotes.value : salas.value
  return lista.find(x => x.id === objetivoId.value) ?? null
})

const puedeAplicar = computed(() => !!fechaInicio.value)

// «Así va a quedar», agrupado por semana del plan: las fechas son reales (las calcula el backend,
// `Planes::Calendario`) y la semana sale de cuántos días pasaron desde el inicio (7-oct-2026).
const DIA_MS = 86400000
const porSemana = computed(() => {
  if (!fechaInicio.value) return []
  const inicio = new Date(fechaInicio.value + 'T00:00:00').getTime()
  const grupos = new Map()
  for (const t of tareasPreview.value) {
    const dias = Math.round((new Date(t.fecha + 'T00:00:00').getTime() - inicio) / DIA_MS)
    const s = Math.floor(Math.max(0, dias) / 7) + 1
    if (!grupos.has(s)) grupos.set(s, [])
    grupos.get(s).push(t)
  }
  return [...grupos.entries()].sort((a, b) => a[0] - b[0]).map(([semana, tareas]) => ({ semana, tareas }))
})
// La fecha de la tarea es lo principal; cuándo se suma a las listas va chico y dicho entero («aparece
// el 16/10» al lado de una tarea del 23 se leía como su fecha, 9-oct-2026).
const cuandoSeSuma = (t) => t.en_el_pasado ? 'ya pasó: no se crea'
  : t.aparece_el === isoHoy() ? 'ya está en tus tareas' : `se suma a tus tareas el ${formatFecha(t.aparece_el)}`
const diaCorto = (iso) => new Date(iso + 'T00:00:00').toLocaleDateString('es-AR', { weekday: 'short', day: 'numeric', month: 'numeric' })

// Las semanas del plan son las del ciclo del lote: al elegir un lote, el plan cuenta desde su inicio
// (lo que ya pasó no se crea). Elegir otra fecha a mano sigue pudiéndose.
watch(objetivoId, (id) => {
  if (objetivoTipo.value !== 'Lote' || !id) return
  const inicio = lotes.value.find(l => l.id === id)?.start_date
  if (inicio) fechaInicio.value = String(inicio).slice(0, 10)
})

async function cargarLotes() {
  const { data } = await listLotes()
  lotes.value = (data?.lotes ?? data ?? [])
    .filter(l => !l.archivado && l.estado !== 'archivado')
}
async function cargarSalas() {
  const { data } = await listSalas()
  salas.value = data ?? []
}

watch(objetivoTipo, async (tipo) => {
  objetivoId.value = null
  if (tipo === 'Lote' && !lotes.value.length) {
    cargando.value = true
    await cargarLotes().catch(() => {})
    cargando.value = false
  }
  if (tipo === 'Sala' && !salas.value.length) {
    cargando.value = true
    await cargarSalas().catch(() => {})
    cargando.value = false
  }
})

async function aplicar() {
  if (!fechaInicio.value) { error.value = 'Elegí una fecha de inicio'; return }

  saving.value = true; error.value = null
  try {
    const { data } = await createAplicacion({
      plan_trabajo_id: props.plan.id,
      fecha_inicio:    fechaInicio.value,
      objetivo_tipo:   objetivoTipo.value || null,
      objetivo_id:     objetivoId.value   || null,
    })
    const ahora = data?.tareas?.length || 0
    const resto = data?.proximas?.length || 0
    toast.success(`Plan aplicado: ${ahora} tarea${ahora !== 1 ? 's' : ''} para esta semana` +
                  (resto ? `; las otras ${resto} van apareciendo ${data.ventana_dias || 7} días antes de su fecha` : ''))
    emit('applied')
  } catch (e) {
    error.value = e?.response?.data?.error || 'Error al aplicar el plan'
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <Teleport to="body">
    <div v-modal="() => $emit('close')" class="apm__overlay">
      <div class="apm__panel">

        <!-- Header -->
        <div class="apm__hdr">
          <div class="apm__hdr-ico"><i class="bi bi-play-circle"></i></div>
          <div>
            <h2 class="apm__title">Aplicar un plan</h2>
            <p class="apm__sub">{{ plan.titulo }}</p>
          </div>
          <button class="apm__close" @click="$emit('close')"><i class="bi bi-x-lg"></i></button>
        </div>

        <!-- Rediseño 7-oct-2026: a la izquierda qué y desde cuándo; a la derecha cómo queda, con las
             fechas reales, antes de confirmar. -->
        <div class="apm__cuerpo">
        <div class="apm__body">
          <div v-if="error" class="apm__alert">{{ error }}</div>

          <!-- Fecha de inicio -->
          <div class="apm__field">
            <label class="apm__label">Fecha de inicio del plan</label>
            <AppDatePicker v-model="fechaInicio" />
            <p class="apm__field-hint">El día 0 del plan corresponde a esta fecha. Cada tarea se programa desde ahí.</p>
          </div>

          <!-- Objetivo (opcional) -->
          <div class="apm__field">
            <label class="apm__label">Aplicar a <span class="apm__hint">(opcional)</span></label>
            <div class="apm__objetivo-btns">
              <button
                class="apm__obj-btn"
                :class="{ 'apm__obj-btn--active': objetivoTipo === '' }"
                @click="objetivoTipo = ''"
              >
                <i class="bi bi-building"></i>
                <span>Toda la organización</span>
              </button>
              <button
                class="apm__obj-btn"
                :class="{ 'apm__obj-btn--active': objetivoTipo === 'Lote' }"
                @click="objetivoTipo = 'Lote'"
              >
                <i class="bi bi-flower1"></i>
                <span>Un lote</span>
              </button>
              <button
                class="apm__obj-btn"
                :class="{ 'apm__obj-btn--active': objetivoTipo === 'Sala' }"
                @click="objetivoTipo = 'Sala'"
              >
                <i class="bi bi-grid-1x2"></i>
                <span>Una sala</span>
              </button>
            </div>
          </div>

          <!-- Selector de Lote -->
          <div v-if="objetivoTipo === 'Lote'" class="apm__field">
            <label class="apm__label">Seleccionar lote</label>
            <div v-if="cargando" class="apm__loading-sm"><DsSpinner :size="16" /> Cargando lotes…</div>
            <select v-else class="apm__input" v-model="objetivoId">
              <option :value="null">— Elegir lote —</option>
              <option v-for="l in lotes" :key="l.id" :value="l.id">
                {{ l.nombre || l.codigo || `Lote #${l.id}` }}
                <template v-if="l.cepa"> — {{ l.cepa }}</template>
              </option>
            </select>
          </div>

          <!-- Selector de Sala -->
          <div v-if="objetivoTipo === 'Sala'" class="apm__field">
            <label class="apm__label">Seleccionar sala</label>
            <div v-if="cargando" class="apm__loading-sm"><DsSpinner :size="16" /> Cargando salas…</div>
            <div v-else class="apm__sala-list">
              <label
                v-for="s in salas" :key="s.id"
                class="apm__sala-opt"
                :class="{ 'apm__sala-opt--active': objetivoId === s.id }"
                @click="objetivoId = s.id"
              >
                <div class="apm__sala-nombre">{{ s.nombre }}</div>
                <div v-if="s.kind || s.tipo" class="apm__sala-tipo">{{ TIPO_SALA_LABEL[s.kind || s.tipo] || s.kind || s.tipo }}</div>
                <i v-if="objetivoId === s.id" class="bi bi-check-circle-fill apm__sala-check"></i>
              </label>
            </div>
          </div>

        </div>
          <aside class="apm__preview-section" aria-label="Así va a quedar">
            <div class="apm__preview-hdr">
              <i class="bi bi-calendar3"></i>
              <span>{{ preview?.total ?? 0 }} tarea{{ (preview?.total ?? 0) !== 1 ? 's' : '' }}</span>
              <span v-if="objetivoSeleccionado" class="apm__preview-objetivo">
                en {{ objetivoSeleccionado.nombre || objetivoSeleccionado.codigo }}
              </span>
            </div>

            <div v-if="!tareasPreview.length" class="apm__preview-empty">
              Esta plantilla no tiene tareas configuradas.
            </div>

            <div v-else class="apm__preview-list">
              <template v-for="g in porSemana" :key="g.semana">
              <div class="apm__preview-semana">Semana {{ g.semana }}</div>
              <div v-for="(t, i) in g.tareas" :key="`${g.semana}-${i}`" class="apm__preview-row" :class="{ 'apm__preview-row--pasada': t.en_el_pasado }">
                <div class="apm__preview-fecha">{{ diaCorto(t.fecha) }}</div>
                <div class="apm__preview-info">
                  <span class="apm__preview-tipo">{{ TIPO_LABEL[t.tipo] || t.tipo }}</span>
                  <span v-if="t.titulo" class="apm__preview-subtitulo"> — {{ t.titulo }}</span>
                </div>
                <div v-if="t.responsable && !esPersonal" class="apm__preview-rol">{{ t.responsable }}</div>
                <div class="apm__preview-cuando">{{ cuandoSeSuma(t) }}</div>
              </div>
              </template>
            </div>
            <p v-if="tareasPreview.length" class="apm__preview-nota">
              La fecha de la izquierda es el día de cada tarea. Se suma a tus tareas
              {{ preview?.ventana_dias || 7 }} días antes, y en el calendario se ve desde ya.
              <template v-if="preview?.en_el_pasado">{{ preview.en_el_pasado }} quedan antes de hoy y no se crean.</template>
            </p>
          </aside>
        </div>

        <!-- Footer -->
        <div class="apm__footer">
          <button class="apm__btn-ghost" @click="$emit('close')">Cancelar</button>
          <button
            class="apm__btn-primary"
            :disabled="saving || !puedeAplicar"
            @click="aplicar"
          >
            <DsSpinner v-if="saving" :size="14" />
            {{ saving ? 'Aplicando…' : `Aplicar · ${preview?.total ?? 0} tareas` }}
          </button>
        </div>

      </div>
    </div>
  </Teleport>
</template>

<style scoped>
.apm__cuerpo { display: flex; flex: 1; min-height: 0; }
.apm__cuerpo > .apm__body { flex: 1; min-width: 0; overflow-y: auto; }
.apm__cuerpo > .apm__preview-section { width: 420px; flex-shrink: 0; border-left: 1px solid var(--c-slate-200); background: var(--c-paper); padding: 1.1rem 1.2rem; overflow-y: auto; margin: 0 !important; border-radius: 0 !important; }
/* La lista de fechas ocupa el alto de la columna: con el tope viejo de 220 px se cortaba en la
   semana 2. */
.apm__cuerpo .apm__preview-list { max-height: none; overflow: visible; }
.apm__panel { height: min(88vh, 760px); }
@media (max-width: 860px) { .apm__panel { height: auto; } }
.apm__preview-semana { font-size: .7rem; font-weight: 700; letter-spacing: .06em; text-transform: uppercase; color: var(--c-leaf-800); padding: .6rem 0 .2rem; }
@media (max-width: 860px) {
  .apm__cuerpo { flex-direction: column; overflow-y: auto; }
  .apm__cuerpo > .apm__body { overflow: visible; }
  .apm__cuerpo > .apm__preview-section { width: auto; border-left: 0; border-top: 1px solid var(--c-slate-200); overflow: visible; }
}
.apm__preview-nota { margin: .6rem 0 0; font-size: .78rem; color: var(--c-slate-500); }
.apm__preview-row--pasada { opacity: .45; }
.apm__preview-cuando { flex-shrink: 0; font-size: .7rem; color: var(--c-slate-500); text-align: right; max-width: 9.5rem; line-height: 1.25; }
.apm__overlay { position: fixed; inset: 0; background: rgba(0,0,0,.45); display: flex; align-items: center; justify-content: center; z-index: 1060; padding: 1rem; backdrop-filter: blur(3px); }
.apm__panel   { background: #fff; border-radius: 16px; width: 100%; max-width: 1000px; display: flex; flex-direction: column; overflow: hidden; box-shadow: 0 24px 64px rgba(0,0,0,.15); max-height: 92vh; }

/* Header */
.apm__hdr     { display: flex; align-items: center; gap: .875rem; padding: 1.25rem 1.4rem 1rem; border-bottom: 1px solid var(--c-slate-100); flex-shrink: 0; }
.apm__hdr-ico { width: 38px; height: 38px; border-radius: 10px; background: #f0fdf4; color: #1b5e20; display: flex; align-items: center; justify-content: center; font-size: 1.1rem; flex-shrink: 0; }
.apm__title   { font-size: 1rem; font-weight: 800; color: #0f2611; margin: 0 0 .1rem; }
.apm__sub     { font-size: .78rem; color: #60725d; margin: 0; font-weight: 600; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; max-width: 280px; }
.apm__close   { margin-left: auto; background: var(--c-slate-100); border: none; width: 30px; height: 30px; border-radius: 8px; cursor: pointer; display: flex; align-items: center; justify-content: center; color: var(--c-slate-500); flex-shrink: 0; }

/* Body */
.apm__body  { padding: 1.25rem 1.4rem; display: flex; flex-direction: column; gap: 1.1rem; overflow-y: auto; flex: 1; }
.apm__alert { background: #fef2f2; border: 1px solid #fecaca; color: #dc2626; padding: .65rem .875rem; border-radius: 8px; font-size: .82rem; }

.apm__field { display: flex; flex-direction: column; gap: .3rem; }
.apm__label { font-size: .72rem; font-weight: 700; color: #374151; text-transform: uppercase; letter-spacing: .04em; }
.apm__hint  { font-weight: 400; text-transform: none; color: var(--c-slate-400); }
.apm__field-hint { font-size: .72rem; color: var(--c-slate-400); margin: 0; }
.apm__input { background: var(--c-slate-50); border: 1.5px solid var(--c-slate-200); border-radius: 9px; padding: .6rem .875rem; font-size: .875rem; color: #0f2611; width: 100%; box-sizing: border-box; }
.apm__input:focus { outline: none; border-color: #1b5e20; box-shadow: 0 0 0 3px rgba(27,94,32,.08); }

/* Objetivo buttons */
.apm__objetivo-btns { display: flex; gap: .5rem; }
.apm__obj-btn { flex: 1; display: flex; flex-direction: column; align-items: center; gap: .3rem; padding: .65rem .5rem; border: 1.5px solid var(--c-slate-200); border-radius: 10px; background: var(--c-slate-50); cursor: pointer; font-size: .78rem; font-weight: 600; color: var(--c-slate-500); transition: all .12s; }
.apm__obj-btn i { font-size: 1.15rem; }
.apm__obj-btn--active { border-color: #1b5e20; background: #f0fdf4; color: #1b5e20; }

/* Loading inline */
.apm__loading-sm { display: flex; align-items: center; gap: .4rem; font-size: .82rem; color: #60725d; padding: .5rem; }

/* Sala list */
.apm__sala-list { display: flex; flex-direction: column; gap: .3rem; max-height: 200px; overflow-y: auto; }
.apm__sala-opt  { display: flex; align-items: center; gap: .75rem; padding: .55rem .875rem; border: 1.5px solid var(--c-slate-200); border-radius: 9px; cursor: pointer; transition: all .12s; background: var(--c-slate-50); }
.apm__sala-opt:hover { border-color: #1b5e20; background: #f0fdf4; }
.apm__sala-opt--active { border-color: #1b5e20; background: #f0fdf4; }
.apm__sala-nombre { font-size: .875rem; font-weight: 700; color: var(--c-slate-900); flex: 1; }
.apm__sala-tipo   { font-size: .72rem; font-weight: 600; color: #1b5e20; background: #dcfce7; padding: .15em .55em; border-radius: 4px; white-space: nowrap; }
.apm__sala-check  { color: #1b5e20; font-size: .9rem; flex-shrink: 0; }

/* Preview */
.apm__preview-section { background: var(--c-slate-50); border: 1.5px solid var(--c-slate-200); border-radius: 10px; overflow: hidden; }
.apm__preview-hdr { display: flex; align-items: center; gap: .4rem; padding: .65rem .875rem; font-size: .8rem; font-weight: 700; color: #0f2611; border-bottom: 1px solid var(--c-slate-200); background: #fff; }
.apm__preview-objetivo { color: #1b5e20; margin-left: .25rem; }
.apm__preview-empty { padding: 1rem .875rem; font-size: .8rem; color: var(--c-slate-400); text-align: center; }
.apm__preview-list { max-height: 220px; overflow-y: auto; }
.apm__preview-row  { display: flex; align-items: center; gap: .6rem; padding: .5rem .875rem; border-bottom: 1px solid var(--c-slate-100); font-size: .8rem; }
.apm__preview-row:last-child { border-bottom: none; }
.apm__preview-fecha { font-size: .72rem; font-weight: 800; color: var(--c-slate-600); background: var(--c-slate-100); padding: .15em .5em; border-radius: 5px; flex-shrink: 0; min-width: 58px; text-align: center; font-family: monospace; }
.apm__preview-info  { flex: 1; min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.apm__preview-tipo  { font-weight: 700; color: var(--c-slate-900); }
.apm__preview-subtitulo { color: var(--c-slate-500); }
.apm__preview-rol   { font-size: .7rem; color: #1b5e20; background: #f0fdf4; padding: .1em .45em; border-radius: 4px; flex-shrink: 0; font-weight: 600; }

/* Footer */
.apm__footer { display: flex; align-items: center; justify-content: flex-end; gap: .75rem; padding: 1rem 1.4rem; border-top: 1px solid var(--c-slate-100); flex-shrink: 0; }
.apm__btn-ghost   { background: transparent; color: var(--c-slate-500); border: 1.5px solid var(--c-slate-200); padding: .6rem 1rem; border-radius: 9px; font-size: .875rem; font-weight: 600; cursor: pointer; }
.apm__btn-primary { display: inline-flex; align-items: center; gap: .4rem; background: #1b5e20; color: #fff; border: none; padding: .6rem 1.25rem; border-radius: 9px; font-size: .875rem; font-weight: 700; cursor: pointer; }
.apm__btn-primary:hover:not(:disabled) { background: #144a18; }
.apm__btn-primary:disabled { opacity: .55; cursor: not-allowed; }
</style>
