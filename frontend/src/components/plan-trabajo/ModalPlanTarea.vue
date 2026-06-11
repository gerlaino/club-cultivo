<script setup>
import { ref, computed, watch, onMounted } from 'vue'
import { listUsers } from '../../lib/api.js'

const props = defineProps({
  tarea: { type: Object, default: null },
})
const emit = defineEmits(['close', 'saved'])

const isEdit = computed(() => !!props.tarea)

// ── Catálogos ───────────────────────────────────────────────────
const TIPOS = [
  { value: 'riego',           label: 'Riego',           emoji: '💧', bg: '#e8f5e9', campos: ['ph', 'ec', 'fertilizante', 'volumen'] },
  { value: 'poda',            label: 'Poda',            emoji: '✂️', bg: '#f3e5f5', campos: ['tecnica'] },
  { value: 'medicion',        label: 'Medición',        emoji: '📏', bg: '#e0f7fa', campos: ['ph', 'ec', 'temperatura', 'humedad', 'vpd'] },
  { value: 'limpieza',        label: 'Limpieza',        emoji: '🧹', bg: '#e8f5e9', campos: [] },
  { value: 'cosecha',         label: 'Cosecha',         emoji: '🌿', bg: '#dcedc8', campos: [] },
  { value: 'transplante',     label: 'Trasplante',      emoji: '🪴', bg: '#fff8e1', campos: ['sustrato'] },
  { value: 'inspeccion',      label: 'Inspección',      emoji: '🔍', bg: '#fff3e0', campos: ['plagas', 'deficiencias'] },
  { value: 'nutricion',       label: 'Nutrición',       emoji: '🧪', bg: '#e3f2fd', campos: ['ph', 'ec', 'fertilizante'] },
  { value: 'defoliacion',     label: 'Defoliación',     emoji: '🍃', bg: '#f1f8e9', campos: [] },
  { value: 'scrog_lst',       label: 'SCROG/LST',       emoji: '🕸️', bg: '#fce4ec', campos: [] },
  { value: 'ajuste_luz',      label: 'Ajuste de luz',   emoji: '💡', bg: '#fff9c4', campos: ['ppfd', 'fotoperiodo'] },
  { value: 'revision_plagas', label: 'Revisión plagas', emoji: '🔬', bg: '#fbe9e7', campos: ['plagas', 'deficiencias'] },
  { value: 'otro',            label: 'Otro',            emoji: '📋', bg: '#f1f8e9', campos: [] },
]

const PRIORIDADES = [
  { value: 'baja',    label: 'Baja',    dot: '🟢', color: '#15803d', bg: '#f0fdf4' },
  { value: 'normal',  label: 'Normal',  dot: '🔵', color: '#0369a1', bg: '#eff6ff' },
  { value: 'alta',    label: 'Alta',    dot: '🟠', color: '#d97706', bg: '#fffbeb' },
  { value: 'urgente', label: 'Urgente', dot: '🔴', color: '#dc2626', bg: '#fef2f2' },
]

const ROLES = [
  { value: 'cultivador',  label: 'Cultivador',  emoji: '🌱' },
  { value: 'manicura',    label: 'Manicura',    emoji: '✂️' },
  { value: 'supervisor',  label: 'Supervisor',  emoji: '👁' },
  { value: 'admin',       label: 'Admin',       emoji: '⚙️' },
  { value: 'dispensador', label: 'Dispensador', emoji: '🏪' },
]

const CAMPO_META = {
  ph:           { label: 'pH objetivo',          placeholder: '6.0 – 6.5',             unidad: '' },
  ec:           { label: 'EC objetivo',           placeholder: '1.2 – 1.8',             unidad: 'mS/cm' },
  temperatura:  { label: 'Temperatura objetivo',  placeholder: '22 – 26',               unidad: '°C' },
  humedad:      { label: 'Humedad relativa obj.', placeholder: '55 – 65',               unidad: '%' },
  vpd:          { label: 'VPD objetivo',          placeholder: '0.8 – 1.2',             unidad: 'kPa' },
  ppfd:         { label: 'PPFD objetivo',         placeholder: '400 – 800',             unidad: 'μmol/m²/s' },
  fotoperiodo:  { label: 'Fotoperiodo',           placeholder: '18/6 o 12/12',          unidad: '' },
  volumen:      { label: 'Volumen de riego',      placeholder: 'ej: 1L por planta',     unidad: '' },
  fertilizante: { label: 'Fertilizante',          placeholder: 'ej: Flora Bloom 5ml/L', unidad: '' },
  sustrato:     { label: 'Sustrato',              placeholder: 'ej: tierra + perlita',  unidad: '' },
  tecnica:      { label: 'Técnica',               placeholder: 'ej: LST, topping…',    unidad: '' },
  plagas:       { label: 'Qué revisar (plagas)',  placeholder: 'ej: trips, arañuela',   unidad: '' },
  deficiencias: { label: 'Qué revisar (defic.)',  placeholder: 'ej: déficit N, K…',    unidad: '' },
}

// ── Helpers ─────────────────────────────────────────────────────
function diaASemanaDia(dia) {
  const d = Math.max(0, dia ?? 0)
  return { semana: Math.floor(d / 7) + 1, diaSemana: (d % 7) + 1 }
}
function semanaDiaADia(semana, diaSemana) {
  return (Math.max(1, semana) - 1) * 7 + (Math.max(1, diaSemana) - 1)
}
function diaLabel(dia) {
  const { semana, diaSemana } = diaASemanaDia(dia)
  return `S${semana}D${diaSemana}`
}

// ── Descripción ─────────────────────────────────────────────────
function parseExtras(desc) {
  const extras = {}
  const libre  = []
  let enExtras = true
  for (const linea of (desc || '').split('\n')) {
    if (linea === '---') { enExtras = false; continue }
    if (enExtras) {
      const m = linea.match(/^([^:]+):\s*(.+)$/)
      if (m) {
        const clave = Object.keys(CAMPO_META).find(k =>
          CAMPO_META[k].label.toLowerCase() === m[1].trim().toLowerCase()
        )
        if (clave) { extras[clave] = m[2].trim(); continue }
      }
    }
    libre.push(linea)
  }
  extras._libre = libre.join('\n').replace(/^\n+|\n+$/g, '')
  return extras
}
function serializarDescripcion(tipo, extras) {
  const campos = TIPOS.find(t => t.value === tipo)?.campos ?? []
  const lineas = []
  for (const c of campos) {
    if (extras[c]?.trim()) lineas.push(`${CAMPO_META[c].label}: ${extras[c].trim()}`)
  }
  if (lineas.length && extras._libre?.trim()) lineas.push('---')
  if (extras._libre?.trim()) lineas.push(extras._libre.trim())
  return lineas.join('\n')
}

// ── Usuarios del club ────────────────────────────────────────────
const usuarios = ref([])
onMounted(async () => {
  try {
    const { data } = await listUsers({ per_page: 200 })
    usuarios.value = Array.isArray(data) ? data : (data.usuarios ?? data.data ?? [])
  } catch {}
})

// ── Form compartido ──────────────────────────────────────────────
const form = ref({
  tipo:           props.tarea?.tipo            ?? 'riego',
  titulo:         props.tarea?.titulo          ?? '',
  prioridad:      props.tarea?.prioridad       ?? 'normal',
  responsable_id: props.tarea?.responsable?.id ?? props.tarea?.responsable_id ?? null,
  extras:         parseExtras(props.tarea?.descripcion ?? ''),
})
const rolesSeleccionados = ref(
  props.tarea?.rol_sugerido
    ? props.tarea.rol_sugerido.split(',').map(s => s.trim()).filter(Boolean)
    : []
)
const tipoActual  = computed(() => TIPOS.find(t => t.value === form.value.tipo) || TIPOS[0])
const camposExtra = computed(() => tipoActual.value.campos)

watch(() => form.value.tipo, () => {
  const libre = form.value.extras._libre
  form.value.extras = { _libre: libre }
})

function toggleRol(rol) {
  const idx = rolesSeleccionados.value.indexOf(rol)
  if (idx >= 0) rolesSeleccionados.value.splice(idx, 1)
  else rolesSeleccionados.value.push(rol)
}

// ── EDIT: un solo día ────────────────────────────────────────────
const { semana: semanaEdit, diaSemana: diaSemanaEdit } = diaASemanaDia(props.tarea?.dia_relativo ?? 0)
const semanaE    = ref(semanaEdit)
const diaSemanaE = ref(diaSemanaEdit)
const diaRelativoEdit = computed(() => semanaDiaADia(semanaE.value, diaSemanaE.value))

// ── NEW: multi-día ───────────────────────────────────────────────
const diasSeleccionados = ref([])
const semanaAdd         = ref(1)
const diasAddActivos    = ref([])

function toggleDiaAdd(d) {
  const idx = diasAddActivos.value.indexOf(d)
  if (idx >= 0) diasAddActivos.value.splice(idx, 1)
  else diasAddActivos.value.push(d)
}
function agregarDias() {
  if (!diasAddActivos.value.length) return
  for (const d of diasAddActivos.value) {
    const dia = semanaDiaADia(semanaAdd.value, d)
    if (!diasSeleccionados.value.includes(dia)) diasSeleccionados.value.push(dia)
  }
  diasSeleccionados.value.sort((a, b) => a - b)
  diasAddActivos.value = []
}
function quitarDia(dia) {
  diasSeleccionados.value = diasSeleccionados.value.filter(d => d !== dia)
}

// ── Guardar ──────────────────────────────────────────────────────
const canSave = computed(() => isEdit.value || diasSeleccionados.value.length > 0)

function guardar() {
  const descripcion    = serializarDescripcion(form.value.tipo, form.value.extras)
  const rol_sugerido   = rolesSeleccionados.value.join(',') || null
  const responsable_id = form.value.responsable_id || null
  const base = { tipo: form.value.tipo, titulo: form.value.titulo, descripcion, prioridad: form.value.prioridad, rol_sugerido, responsable_id }

  if (isEdit.value) {
    emit('saved', { ...props.tarea, ...base, dia_relativo: diaRelativoEdit.value })
  } else {
    emit('saved', diasSeleccionados.value.map(dia => ({ ...base, dia_relativo: dia })))
  }
}
</script>

<template>
  <Teleport to="body">
    <div class="mpt__overlay">
      <div class="mpt__panel">

        <!-- Header -->
        <div class="mpt__hdr" :style="{ background: tipoActual.bg }">
          <span class="mpt__hdr-emoji">{{ tipoActual.emoji }}</span>
          <div class="mpt__hdr-info">
            <h2 class="mpt__title">{{ isEdit ? 'Editar tarea' : 'Nueva tarea de plantilla' }}</h2>
            <p class="mpt__hdr-sub">
              <template v-if="isEdit">
                Sem. {{ semanaE }} · Día {{ diaSemanaE }}
                <span class="mpt__hdr-total">= Día {{ diaRelativoEdit + 1 }} del plan</span>
              </template>
              <template v-else>
                <span v-if="!diasSeleccionados.length" class="mpt__hdr-hint">Seleccioná los días abajo</span>
                <span v-else class="mpt__hdr-total">{{ diasSeleccionados.length }} día{{ diasSeleccionados.length !== 1 ? 's' : '' }} seleccionado{{ diasSeleccionados.length !== 1 ? 's' : '' }}</span>
              </template>
            </p>
          </div>
          <button class="mpt__close" @click="$emit('close')"><i class="bi bi-x-lg"></i></button>
        </div>

        <!-- Body -->
        <div class="mpt__body">

          <!-- ══ EDIT: un solo día ══ -->
          <template v-if="isEdit">
            <div class="mpt__dia-section">
              <div class="mpt__dia-col">
                <div class="mpt__dia-label">Semana</div>
                <div class="mpt__semana-ctrl">
                  <button class="mpt__semana-btn" @click="semanaE = Math.max(1, semanaE - 1)" :disabled="semanaE <= 1"><i class="bi bi-dash"></i></button>
                  <span class="mpt__semana-num">{{ semanaE }}</span>
                  <button class="mpt__semana-btn" @click="semanaE++"><i class="bi bi-plus"></i></button>
                </div>
              </div>
              <div class="mpt__dia-col mpt__dia-col--flex">
                <div class="mpt__dia-label">Día de la semana</div>
                <div class="mpt__dias-row">
                  <button v-for="d in 7" :key="d" class="mpt__dia-btn" :class="{ 'mpt__dia-btn--active': diaSemanaE === d }" @click="diaSemanaE = d">{{ d }}</button>
                </div>
              </div>
              <div class="mpt__dia-total">
                <i class="bi bi-arrow-right-short"></i>
                Día <strong>{{ diaRelativoEdit + 1 }}</strong> del plan
              </div>
            </div>
          </template>

          <!-- ══ NEW: multi-día ══ -->
          <template v-else>
            <div class="mpt__multidia">

              <!-- Picker -->
              <div class="mpt__add-row">
                <div class="mpt__dia-col">
                  <div class="mpt__dia-label">Semana</div>
                  <div class="mpt__semana-ctrl">
                    <button class="mpt__semana-btn" @click="semanaAdd = Math.max(1, semanaAdd - 1)" :disabled="semanaAdd <= 1"><i class="bi bi-dash"></i></button>
                    <span class="mpt__semana-num">{{ semanaAdd }}</span>
                    <button class="mpt__semana-btn" @click="semanaAdd++"><i class="bi bi-plus"></i></button>
                  </div>
                </div>
                <div class="mpt__dia-col mpt__dia-col--flex">
                  <div class="mpt__dia-label">Días <span class="mpt__opt">podés marcar varios</span></div>
                  <div class="mpt__dias-row">
                    <button
                      v-for="d in 7" :key="d"
                      class="mpt__dia-btn"
                      :class="{ 'mpt__dia-btn--active': diasAddActivos.includes(d) }"
                      @click="toggleDiaAdd(d)"
                    >{{ d }}</button>
                  </div>
                </div>
                <button class="mpt__btn-agregar" :disabled="!diasAddActivos.length" @click="agregarDias">
                  <i class="bi bi-plus-lg"></i> Agregar
                </button>
              </div>

              <!-- Chips -->
              <div v-if="diasSeleccionados.length" class="mpt__chips-wrap">
                <div class="mpt__chips-hdr">
                  <span class="mpt__dia-label">{{ diasSeleccionados.length }} día{{ diasSeleccionados.length !== 1 ? 's' : '' }} agregado{{ diasSeleccionados.length !== 1 ? 's' : '' }}</span>
                  <button class="mpt__chips-clear" @click="diasSeleccionados = []">Limpiar todo</button>
                </div>
                <div class="mpt__chips">
                  <span v-for="dia in diasSeleccionados" :key="dia" class="mpt__chip">
                    {{ diaLabel(dia) }}
                    <button class="mpt__chip-x" @click="quitarDia(dia)"><i class="bi bi-x"></i></button>
                  </span>
                </div>
              </div>
              <div v-else class="mpt__chips-empty">
                <i class="bi bi-calendar-plus"></i> Seleccioná semana y días, luego "Agregar"
              </div>

            </div>
          </template>

          <!-- ── Tipo ── -->
          <div class="mpt__field">
            <label class="mpt__label">Tipo de tarea</label>
            <div class="mpt__tipos">
              <button
                v-for="t in TIPOS" :key="t.value" type="button"
                class="mpt__tipo"
                :class="{ 'mpt__tipo--active': form.tipo === t.value }"
                :style="form.tipo === t.value ? { background: t.bg, borderColor: '#1b5e20' } : {}"
                @click="form.tipo = t.value"
              >
                <span class="mpt__tipo-emoji">{{ t.emoji }}</span>
                <span class="mpt__tipo-label">{{ t.label }}</span>
              </button>
            </div>
          </div>

          <!-- ── Título ── -->
          <div class="mpt__field">
            <label class="mpt__label">Título <span class="mpt__opt">opcional</span></label>
            <input class="mpt__input" v-model="form.titulo" :placeholder="`${tipoActual.label}…`" />
          </div>

          <!-- ── Campos técnicos ── -->
          <template v-if="camposExtra.length">
            <div class="mpt__divider"><span>Parámetros técnicos objetivo</span></div>
            <div class="mpt__extras-grid">
              <div v-for="campo in camposExtra" :key="campo" class="mpt__extra-field">
                <label class="mpt__label">{{ CAMPO_META[campo].label }}</label>
                <div class="mpt__input-group">
                  <input class="mpt__input" v-model="form.extras[campo]" :placeholder="CAMPO_META[campo].placeholder" />
                  <span v-if="CAMPO_META[campo].unidad" class="mpt__input-suffix">{{ CAMPO_META[campo].unidad }}</span>
                </div>
              </div>
            </div>
            <p class="mpt__extras-hint"><i class="bi bi-info-circle"></i> Estos valores quedan en la descripción como guía.</p>
          </template>

          <!-- ── Instrucciones ── -->
          <div class="mpt__field">
            <label class="mpt__label">Instrucciones <span class="mpt__opt">opcional</span></label>
            <textarea class="mpt__input mpt__textarea" v-model="form.extras._libre" rows="2" placeholder="Instrucciones adicionales…"></textarea>
          </div>

          <!-- ── Prioridad ── -->
          <div class="mpt__field">
            <label class="mpt__label">Prioridad</label>
            <div class="mpt__prioridades">
              <button
                v-for="p in PRIORIDADES" :key="p.value" type="button"
                class="mpt__prioridad"
                :class="{ 'mpt__prioridad--active': form.prioridad === p.value }"
                :style="form.prioridad === p.value ? { background: p.bg, borderColor: p.color, color: p.color } : {}"
                @click="form.prioridad = p.value"
              >
                <span>{{ p.dot }}</span><span>{{ p.label }}</span>
              </button>
            </div>
          </div>

          <!-- ── Roles ── -->
          <div class="mpt__field">
            <label class="mpt__label">
              Roles que ejecutan esta tarea
              <span class="mpt__opt">referencia informativa</span>
            </label>
            <div class="mpt__roles">
              <button
                v-for="r in ROLES" :key="r.value" type="button"
                class="mpt__rol-btn"
                :class="{ 'mpt__rol-btn--active': rolesSeleccionados.includes(r.value) }"
                @click="toggleRol(r.value)"
              >
                <span>{{ r.emoji }}</span>
                <span>{{ r.label }}</span>
                <i v-if="rolesSeleccionados.includes(r.value)" class="bi bi-check-lg mpt__rol-check"></i>
              </button>
            </div>
          </div>

          <!-- ── Responsable ── -->
          <div class="mpt__field">
            <label class="mpt__label">Responsable <span class="mpt__opt">usuario específico — opcional</span></label>
            <select class="mpt__input" v-model="form.responsable_id">
              <option :value="null">— Sin asignar —</option>
              <option v-for="u in usuarios" :key="u.id" :value="u.id">{{ u.nombre_completo || u.email }}</option>
            </select>
          </div>

        </div>

        <!-- Footer -->
        <div class="mpt__footer">
          <button class="mpt__btn-ghost" @click="$emit('close')">Cancelar</button>
          <button class="mpt__btn-primary" :disabled="!canSave" @click="guardar">
            <i class="bi bi-check-lg"></i>
            <template v-if="isEdit">Guardar cambios</template>
            <template v-else-if="!diasSeleccionados.length">Seleccioná días primero</template>
            <template v-else>Agregar {{ diasSeleccionados.length }} tarea{{ diasSeleccionados.length !== 1 ? 's' : '' }}</template>
          </button>
        </div>

      </div>
    </div>
  </Teleport>
</template>

<style scoped>
.mpt__overlay { position: fixed; inset: 0; background: rgba(0,0,0,.45); display: flex; align-items: center; justify-content: center; z-index: 1070; padding: 1rem; backdrop-filter: blur(4px); }
.mpt__panel   { background: #fff; border-radius: 20px; width: 100%; max-width: 580px; display: flex; flex-direction: column; box-shadow: 0 28px 64px rgba(0,0,0,.18); max-height: 92vh; }

/* Header */
.mpt__hdr      { display: flex; align-items: center; gap: .875rem; padding: 1rem 1.25rem; border-radius: 20px 20px 0 0; flex-shrink: 0; transition: background .2s; }
.mpt__hdr-emoji { font-size: 1.6rem; flex-shrink: 0; }
.mpt__hdr-info  { flex: 1; min-width: 0; }
.mpt__title     { font-size: .95rem; font-weight: 800; color: #1a1a1a; margin: 0 0 .1rem; }
.mpt__hdr-sub   { font-size: .75rem; color: #60725d; margin: 0; display: flex; align-items: center; gap: .4rem; flex-wrap: wrap; }
.mpt__hdr-total { font-weight: 800; color: #1b5e20; background: rgba(27,94,32,.12); padding: .1em .4em; border-radius: 5px; }
.mpt__hdr-hint  { color: #94a3b8; }
.mpt__close     { background: rgba(0,0,0,.08); border: none; width: 30px; height: 30px; border-radius: 8px; cursor: pointer; display: flex; align-items: center; justify-content: center; color: #374151; flex-shrink: 0; }
.mpt__close:hover { background: rgba(0,0,0,.15); }

/* Body */
.mpt__body { padding: 1.25rem 1.5rem; display: flex; flex-direction: column; gap: 1rem; overflow-y: auto; flex: 1; }

/* Día (edit) */
.mpt__dia-section { display: flex; align-items: flex-start; gap: 1rem; background: #f0fdf4; border: 1.5px solid #c8e6c9; border-radius: 12px; padding: .875rem 1rem; flex-wrap: wrap; }
.mpt__dia-col { display: flex; flex-direction: column; gap: .35rem; }
.mpt__dia-col--flex { flex: 1; }
.mpt__dia-label { font-size: .65rem; font-weight: 800; color: #60725d; text-transform: uppercase; letter-spacing: .05em; }
.mpt__semana-ctrl { display: flex; align-items: center; gap: .35rem; }
.mpt__semana-btn  { width: 30px; height: 30px; border-radius: 8px; border: 1.5px solid #c8e6c9; background: #fff; color: #1b5e20; cursor: pointer; display: flex; align-items: center; justify-content: center; transition: all .12s; font-size: .9rem; }
.mpt__semana-btn:hover:not(:disabled) { background: #1b5e20; color: #fff; border-color: #1b5e20; }
.mpt__semana-btn:disabled { opacity: .35; cursor: not-allowed; }
.mpt__semana-num  { font-size: 1.3rem; font-weight: 900; color: #1b5e20; min-width: 28px; text-align: center; }
.mpt__semana-num--sm { font-size: 1rem; }
.mpt__dias-row { display: flex; gap: .3rem; flex-wrap: wrap; }
.mpt__dia-btn  { width: 34px; height: 34px; border-radius: 8px; border: 1.5px solid #c8e6c9; background: #fff; font-size: .82rem; font-weight: 700; color: #60725d; cursor: pointer; display: flex; align-items: center; justify-content: center; transition: all .12s; }
.mpt__dia-btn:hover { border-color: #1b5e20; color: #1b5e20; }
.mpt__dia-btn--active { background: #1b5e20; border-color: #1b5e20; color: #fff; box-shadow: 0 2px 6px rgba(27,94,32,.3); }
.mpt__dia-total { display: flex; align-items: center; gap: .25rem; font-size: .8rem; color: #475569; align-self: flex-end; padding-bottom: .1rem; white-space: nowrap; }
.mpt__dia-total strong { color: #1b5e20; font-size: .95rem; }

/* Multi-día (new) */
.mpt__multidia { display: flex; flex-direction: column; gap: .75rem; background: #f0fdf4; border: 1.5px solid #c8e6c9; border-radius: 14px; padding: .875rem 1rem; }
.mpt__chips-wrap { display: flex; flex-direction: column; gap: .35rem; border-top: 1px solid #c8e6c9; padding-top: .65rem; }
.mpt__chips-hdr { display: flex; align-items: center; justify-content: space-between; }
.mpt__chips-clear { background: none; border: none; font-size: .72rem; color: #dc2626; cursor: pointer; font-weight: 600; }
.mpt__chips-clear:hover { text-decoration: underline; }
.mpt__chips-empty { font-size: .78rem; color: #94a3b8; display: flex; align-items: center; gap: .4rem; border-top: 1px solid #c8e6c9; padding-top: .65rem; }
.mpt__chips { display: flex; flex-wrap: wrap; gap: .3rem; }
.mpt__chip  { display: inline-flex; align-items: center; gap: .2rem; background: #1b5e20; color: #fff; font-size: .7rem; font-weight: 800; padding: .2em .45em .2em .6em; border-radius: 999px; }
.mpt__chip-x { background: rgba(255,255,255,.25); border: none; color: #fff; cursor: pointer; width: 15px; height: 15px; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-size: .6rem; padding: 0; transition: background .1s; }
.mpt__chip-x:hover { background: rgba(255,255,255,.45); }

.mpt__add-row { display: flex; align-items: flex-end; gap: .65rem; flex-wrap: wrap; }
.mpt__btn-agregar { display: inline-flex; align-items: center; gap: .3rem; background: #1b5e20; color: #fff; border: none; padding: .5rem .875rem; border-radius: 8px; font-size: .78rem; font-weight: 700; cursor: pointer; white-space: nowrap; align-self: flex-end; }
.mpt__btn-agregar:hover:not(:disabled) { background: #144a18; }
.mpt__btn-agregar:disabled { opacity: .4; cursor: not-allowed; }

/* Fields */
.mpt__field { display: flex; flex-direction: column; gap: .4rem; }
.mpt__label { font-size: .7rem; font-weight: 700; color: #60725d; text-transform: uppercase; letter-spacing: .05em; }
.mpt__opt   { font-size: .67rem; font-weight: 400; color: #94a3b8; text-transform: none; letter-spacing: 0; }
.mpt__input { background: #f4f8f4; border: 1.5px solid #d4e6d4; border-radius: 10px; padding: .65rem .9rem; font-size: .875rem; color: #1a1a1a; width: 100%; box-sizing: border-box; outline: none; transition: border .15s; }
.mpt__input:focus { border-color: #1b5e20; background: #fff; }
.mpt__textarea { resize: vertical; min-height: 64px; }
.mpt__input-group { display: flex; }
.mpt__input-group .mpt__input { border-radius: 10px 0 0 10px; }
.mpt__input-suffix { background: #e8f0e9; border: 1.5px solid #d4e6d4; border-left: none; padding: .65rem .75rem; font-size: .75rem; font-weight: 600; color: #60725d; border-radius: 0 10px 10px 0; white-space: nowrap; display: flex; align-items: center; }

/* Tipo */
.mpt__tipos { display: grid; grid-template-columns: repeat(4, 1fr); gap: .4rem; }
.mpt__tipo  { display: flex; flex-direction: column; align-items: center; gap: .3rem; padding: .65rem .3rem; background: #f4f8f4; border: 1.5px solid #d4e6d4; border-radius: 11px; cursor: pointer; transition: all .15s; }
.mpt__tipo:hover { border-color: #66bb6a; background: #e8f5e9; }
.mpt__tipo--active { box-shadow: 0 2px 8px rgba(27,94,32,.14); transform: translateY(-1px); }
.mpt__tipo-emoji { font-size: 1.3rem; }
.mpt__tipo-label { font-size: .62rem; font-weight: 600; color: #1a1a1a; text-align: center; line-height: 1.2; }

/* Divider */
.mpt__divider { display: flex; align-items: center; gap: .75rem; }
.mpt__divider::before, .mpt__divider::after { content: ''; flex: 1; height: 1px; background: #e8f0e9; }
.mpt__divider span { font-size: .65rem; font-weight: 700; color: #94a3b8; text-transform: uppercase; letter-spacing: .07em; white-space: nowrap; }

/* Extras */
.mpt__extras-grid { display: grid; grid-template-columns: 1fr 1fr; gap: .65rem; }
.mpt__extra-field { display: flex; flex-direction: column; gap: .3rem; }
.mpt__extras-hint { display: flex; align-items: flex-start; gap: .4rem; font-size: .72rem; color: #94a3b8; }

/* Prioridades */
.mpt__prioridades { display: flex; gap: .35rem; flex-wrap: wrap; }
.mpt__prioridad { display: flex; align-items: center; gap: .35rem; padding: .4rem .75rem; border: 1.5px solid #d4e6d4; border-radius: 999px; background: #f4f8f4; font-size: .78rem; font-weight: 600; cursor: pointer; transition: all .15s; }
.mpt__prioridad:hover { border-color: #66bb6a; }
.mpt__prioridad--active { transform: translateY(-1px); box-shadow: 0 2px 8px rgba(0,0,0,.08); }

/* Roles */
.mpt__roles { display: flex; flex-wrap: wrap; gap: .4rem; }
.mpt__rol-btn { display: inline-flex; align-items: center; gap: .35rem; padding: .45rem .875rem; border: 1.5px solid #e2e8f0; border-radius: 999px; background: #f8fafc; font-size: .8rem; font-weight: 600; color: #475569; cursor: pointer; transition: all .15s; }
.mpt__rol-btn:hover { border-color: #1b5e20; color: #1b5e20; background: #f0fdf4; }
.mpt__rol-btn--active { border-color: #1b5e20; background: #f0fdf4; color: #1b5e20; box-shadow: 0 0 0 3px rgba(27,94,32,.08); }
.mpt__rol-check { font-size: .7rem; }
.mpt__roles-hint { font-size: .72rem; color: #94a3b8; margin: 0; }
.mpt__roles-hint--ok { color: #1b5e20; font-weight: 600; }

/* Footer */
.mpt__footer { display: flex; align-items: center; justify-content: flex-end; gap: .75rem; padding: 1rem 1.25rem; border-top: 1px solid #e8f0e9; flex-shrink: 0; }
.mpt__btn-ghost   { background: transparent; color: #60725d; border: 1.5px solid #d4e6d4; padding: .65rem 1.1rem; border-radius: 10px; font-size: .875rem; font-weight: 500; cursor: pointer; }
.mpt__btn-ghost:hover { background: #e8f0e9; color: #1b5e20; }
.mpt__btn-primary { display: inline-flex; align-items: center; gap: .4rem; background: #1b5e20; color: #fff; border: none; padding: .65rem 1.4rem; border-radius: 10px; font-size: .875rem; font-weight: 700; cursor: pointer; transition: background .15s; }
.mpt__btn-primary:hover:not(:disabled) { background: #104417; }
.mpt__btn-primary:disabled { opacity: .45; cursor: not-allowed; }
</style>
