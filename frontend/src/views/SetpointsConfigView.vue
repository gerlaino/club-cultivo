<template>
  <div class="spc">
    <div class="spc__header">
      <h1 class="spc__title">Configuración de alertas</h1>
      <p class="spc__subtitle">Definí los umbrales ambientales por fase y los parámetros de detección automática.</p>
    </div>

    <div class="spc__tabs">
      <button
        v-for="t in TABS"
        :key="t.key"
        class="spc__tab"
        :class="{ 'spc__tab--active': tabActivo === t.key }"
        @click="tabActivo = t.key"
      >{{ t.label }}</button>
    </div>

    <!-- Tab: Umbrales ambientales -->
    <section v-if="tabActivo === 'setpoints'" class="spc__section">
      <div class="spc__section-top">
        <p class="spc__section-desc">
          Umbrales de temperatura, humedad, pH, EC y más por fase de cultivo. Se usan para disparar alertas cuando las lecturas ambientales salen de rango.
        </p>
        <button class="spc__btn-primary" @click="abrirNuevo">+ Nuevo umbral</button>
      </div>

      <div v-if="loadingSp" class="spc__loading">Cargando…</div>
      <div v-else-if="!setpoints.length" class="spc__empty">
        Sin umbrales configurados. El sistema usará los valores por defecto.
      </div>
      <div v-else>
        <div v-for="fase in fasesConSetpoints" :key="fase" class="spc__fase-group">
          <div class="spc__fase-header">{{ FASES_LABELS[fase] || fase }}</div>
          <table class="spc__table">
            <thead>
              <tr>
                <th>Parámetro</th>
                <th>Mín</th>
                <th>Máx</th>
                <th>Ideal</th>
                <th>Unidad</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="sp in setpointsPorFase(fase)" :key="sp.id">
                <td class="spc__td-param">{{ TIPO_LABELS[sp.tipo_lectura] || sp.tipo_lectura }}</td>
                <td>{{ sp.valor_min ?? '—' }}</td>
                <td>{{ sp.valor_max ?? '—' }}</td>
                <td>{{ sp.valor_ideal ?? '—' }}</td>
                <td class="spc__td-unit">{{ sp.unidad }}</td>
                <td class="spc__td-actions">
                  <button class="spc__btn-icon" title="Editar" @click="abrirEdicion(sp)">
                    <i class="bi bi-pencil"></i>
                  </button>
                  <button class="spc__btn-icon spc__btn-icon--danger" title="Eliminar" @click="eliminar(sp)">
                    <i class="bi bi-trash3"></i>
                  </button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </section>

    <!-- Tab: Parámetros de alerta -->
    <section v-if="tabActivo === 'alertas'" class="spc__section">
      <p class="spc__section-desc">
        Controlá cuándo el sistema genera alertas automáticas. Estos valores aplican a todos los lotes del club.
      </p>

      <div v-if="loadingPrefs" class="spc__loading">Cargando…</div>
      <form v-else class="spc__form" @submit.prevent="guardarAlertas">

        <fieldset class="spc__fieldset">
          <legend class="spc__legend">Días sin registro ambiental</legend>
          <p class="spc__field-desc">Máximo de días sin registrar lectura ambiental antes de generar una alerta.</p>
          <div class="spc__field-grid">
            <div v-for="fase in FASES_SIN_REGISTRO" :key="fase.key" class="spc__field">
              <label class="spc__label">{{ fase.label }}</label>
              <div class="spc__input-wrap">
                <input
                  v-model.number="configForm.dias_sin_registro[fase.key]"
                  type="number"
                  min="1"
                  max="30"
                  class="spc__input"
                />
                <span class="spc__input-suffix">días</span>
              </div>
            </div>
          </div>
        </fieldset>

        <fieldset class="spc__fieldset">
          <legend class="spc__legend">Alerta de cosecha pendiente</legend>
          <p class="spc__field-desc">Días <strong>después</strong> de la fecha estimada de cosecha para generar alerta.</p>
          <div class="spc__field">
            <label class="spc__label">Umbral de días</label>
            <div class="spc__input-wrap">
              <input
                v-model.number="configForm.cosecha_pendiente_umbral_dias"
                type="number"
                min="0"
                max="60"
                class="spc__input spc__input--sm"
              />
              <span class="spc__input-suffix">días después de la fecha estimada</span>
            </div>
          </div>
        </fieldset>

        <div class="spc__form-footer">
          <button type="submit" class="spc__btn-primary" :disabled="guardandoAlertas">
            {{ guardandoAlertas ? 'Guardando…' : 'Guardar configuración' }}
          </button>
        </div>
      </form>
    </section>

    <!-- Modal nuevo/edición setpoint -->
    <Teleport to="body">
      <div v-if="modalOpen" class="spc__modal-overlay" @click.self="cerrarModal">
        <div class="spc__modal">
          <div class="spc__modal-header">
            <h3 class="spc__modal-title">{{ editandoSp ? 'Editar umbral' : 'Nuevo umbral ambiental' }}</h3>
            <button class="spc__modal-close" @click="cerrarModal"><i class="bi bi-x-lg"></i></button>
          </div>
          <form class="spc__modal-body" @submit.prevent="guardarSetpoint">
            <div class="spc__mfield">
              <label class="spc__label">Fase</label>
              <select v-model="spForm.fase" class="spc__select" :disabled="!!editandoSp">
                <option value="">— Seleccioná —</option>
                <option v-for="f in FASES" :key="f.key" :value="f.key">{{ f.label }}</option>
              </select>
            </div>
            <div class="spc__mfield">
              <label class="spc__label">Parámetro</label>
              <select v-model="spForm.tipo_lectura" class="spc__select" :disabled="!!editandoSp">
                <option value="">— Seleccioná —</option>
                <option v-for="t in TIPOS" :key="t.key" :value="t.key">{{ t.label }} ({{ t.unidad }})</option>
              </select>
            </div>
            <div class="spc__mrow">
              <div class="spc__mfield">
                <label class="spc__label">Mínimo</label>
                <input v-model.number="spForm.valor_min" type="number" step="0.01" class="spc__input" />
              </div>
              <div class="spc__mfield">
                <label class="spc__label">Máximo</label>
                <input v-model.number="spForm.valor_max" type="number" step="0.01" class="spc__input" />
              </div>
              <div class="spc__mfield">
                <label class="spc__label">Ideal <span class="spc__opt">(opcional)</span></label>
                <input v-model.number="spForm.valor_ideal" type="number" step="0.01" class="spc__input" />
              </div>
            </div>
            <div v-if="modalError" class="spc__modal-error">{{ modalError }}</div>
            <div class="spc__modal-footer">
              <button type="button" class="spc__btn-ghost" @click="cerrarModal">Cancelar</button>
              <button type="submit" class="spc__btn-primary" :disabled="guardandoSp">
                {{ guardandoSp ? 'Guardando…' : (editandoSp ? 'Guardar cambios' : 'Crear umbral') }}
              </button>
            </div>
          </form>
        </div>
      </div>
    </Teleport>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useToast } from '../composables/useToast.js'
import { useConfirm } from '../composables/useConfirm.js'
import {
  listSetpointsFase, createSetpointFase, updateSetpointFase, deleteSetpointFase,
  getPreferences, updatePreferences,
} from '../lib/api.js'

const toast   = useToast()
const confirm = useConfirm()

const TABS = [
  { key: 'setpoints', label: 'Umbrales ambientales' },
  { key: 'alertas',   label: 'Parámetros de alerta' },
]
const tabActivo = ref('setpoints')

const FASES_LABELS = {
  vegetativo: 'Vegetativo',
  floracion:  'Floración',
  clon:       'Clones',
  madre:      'Madres',
  lavado:     'Lavado',
  secado:     'Secado',
  curado:     'Curado',
}

const FASES = Object.entries(FASES_LABELS).map(([key, label]) => ({ key, label }))

const TIPOS = [
  { key: 'temperatura',          label: 'Temperatura',         unidad: '°C'       },
  { key: 'humedad',              label: 'Humedad',             unidad: '%'        },
  { key: 'vpd',                  label: 'VPD',                 unidad: 'kPa'      },
  { key: 'co2',                  label: 'CO₂',                 unidad: 'ppm'      },
  { key: 'ph',                   label: 'pH',                  unidad: 'pH'       },
  { key: 'ec',                   label: 'EC',                  unidad: 'mS/cm'    },
  { key: 'ppfd',                 label: 'PPFD',                unidad: 'µmol/m²s' },
  { key: 'ec_runoff',            label: 'EC runoff',           unidad: 'mS/cm'    },
  { key: 'ph_runoff',            label: 'pH runoff',           unidad: 'pH'       },
  { key: 'temperatura_sustrato', label: 'Temperatura sustrato',unidad: '°C'       },
  { key: 'humedad_sustrato',     label: 'Humedad sustrato',    unidad: '%'        },
]

const TIPO_LABELS = Object.fromEntries(TIPOS.map(t => [t.key, t.label]))

const FASES_SIN_REGISTRO = [
  { key: 'vegetativo', label: 'Vegetativo' },
  { key: 'floracion',  label: 'Floración'  },
  { key: 'cosecha',    label: 'Cosecha'    },
]

// ── Setpoints ────────────────────────────────────────────────
const setpoints  = ref([])
const loadingSp  = ref(false)
const modalOpen  = ref(false)
const editandoSp = ref(null)
const guardandoSp = ref(false)
const modalError  = ref(null)

function emptySpForm() {
  return { fase: '', tipo_lectura: '', valor_min: '', valor_max: '', valor_ideal: '' }
}
const spForm = ref(emptySpForm())

const fasesConSetpoints = computed(() =>
  [...new Set(setpoints.value.map(s => s.fase))]
    .sort((a, b) => FASES.findIndex(f => f.key === a) - FASES.findIndex(f => f.key === b))
)

function setpointsPorFase(fase) {
  return setpoints.value
    .filter(s => s.fase === fase)
    .sort((a, b) => TIPOS.findIndex(t => t.key === a.tipo_lectura) - TIPOS.findIndex(t => t.key === b.tipo_lectura))
}

async function cargarSetpoints() {
  loadingSp.value = true
  try {
    const { data } = await listSetpointsFase()
    setpoints.value = data || []
  } finally {
    loadingSp.value = false
  }
}

function abrirNuevo() {
  editandoSp.value = null
  spForm.value = emptySpForm()
  modalError.value = null
  modalOpen.value = true
}

function abrirEdicion(sp) {
  editandoSp.value = sp
  spForm.value = {
    fase:         sp.fase,
    tipo_lectura: sp.tipo_lectura,
    valor_min:    sp.valor_min,
    valor_max:    sp.valor_max,
    valor_ideal:  sp.valor_ideal,
  }
  modalError.value = null
  modalOpen.value = true
}

function cerrarModal() {
  modalOpen.value = false
  editandoSp.value = null
}

async function guardarSetpoint() {
  if (!spForm.value.fase || !spForm.value.tipo_lectura) {
    modalError.value = 'Fase y parámetro son obligatorios.'
    return
  }
  guardandoSp.value = true
  modalError.value = null
  try {
    const payload = {
      fase:         spForm.value.fase,
      tipo_lectura: spForm.value.tipo_lectura,
      valor_min:    spForm.value.valor_min === '' ? null : spForm.value.valor_min,
      valor_max:    spForm.value.valor_max === '' ? null : spForm.value.valor_max,
      valor_ideal:  spForm.value.valor_ideal === '' ? null : spForm.value.valor_ideal,
    }
    if (editandoSp.value) {
      const { data } = await updateSetpointFase(editandoSp.value.id, payload)
      const idx = setpoints.value.findIndex(s => s.id === editandoSp.value.id)
      if (idx !== -1) setpoints.value[idx] = data
      toast.success('Umbral actualizado')
    } else {
      const { data } = await createSetpointFase(payload)
      setpoints.value.push(data)
      toast.success('Umbral creado')
    }
    cerrarModal()
  } catch (e) {
    modalError.value = e?.response?.data?.errors?.join(', ') || 'No se pudo guardar'
  } finally {
    guardandoSp.value = false
  }
}

async function eliminar(sp) {
  const ok = await confirm.show({
    title:   'Eliminar umbral',
    message: `¿Eliminar el umbral de ${TIPO_LABELS[sp.tipo_lectura] || sp.tipo_lectura} en ${FASES_LABELS[sp.fase] || sp.fase}?`,
    confirm: 'Eliminar',
    danger:  true,
  })
  if (!ok) return
  try {
    await deleteSetpointFase(sp.id)
    setpoints.value = setpoints.value.filter(s => s.id !== sp.id)
    toast.success('Umbral eliminado')
  } catch {
    toast.error('No se pudo eliminar el umbral')
  }
}

// ── Alertas config ──────────────────────────────────────────
const loadingPrefs    = ref(false)
const guardandoAlertas = ref(false)
const configForm = ref({
  dias_sin_registro: { vegetativo: 3, floracion: 2, cosecha: 1 },
  cosecha_pendiente_umbral_dias: 0,
})

async function cargarPreferences() {
  loadingPrefs.value = true
  try {
    const { data } = await getPreferences()
    const ac = data.alertas_config || {}
    if (ac.dias_sin_registro) {
      configForm.value.dias_sin_registro = {
        vegetativo: ac.dias_sin_registro.vegetativo ?? 3,
        floracion:  ac.dias_sin_registro.floracion  ?? 2,
        cosecha:    ac.dias_sin_registro.cosecha     ?? 1,
      }
    }
    if (ac.cosecha_pendiente_umbral_dias !== undefined) {
      configForm.value.cosecha_pendiente_umbral_dias = ac.cosecha_pendiente_umbral_dias
    }
  } finally {
    loadingPrefs.value = false
  }
}

async function guardarAlertas() {
  guardandoAlertas.value = true
  try {
    await updatePreferences({
      alertas_config: {
        dias_sin_registro: configForm.value.dias_sin_registro,
        cosecha_pendiente_umbral_dias: configForm.value.cosecha_pendiente_umbral_dias,
      },
    })
    toast.success('Configuración guardada')
  } catch {
    toast.error('No se pudo guardar la configuración')
  } finally {
    guardandoAlertas.value = false
  }
}

onMounted(() => {
  cargarSetpoints()
  cargarPreferences()
})
</script>

<style scoped>
.spc { max-width: 900px; margin: 0 auto; padding: 1.5rem 1.25rem; display: flex; flex-direction: column; gap: 1.75rem; }
@media (max-width: 640px) { .spc { padding: 1rem .75rem 80px; gap: 1.25rem; } }

.spc__header {}
.spc__title    { font-size: 1.4rem; font-weight: 700; color: #0f2611; margin: 0 0 .25rem; letter-spacing: -.025em; }
.spc__subtitle { font-size: .875rem; color: #60725d; margin: 0; }

/* Tabs */
.spc__tabs { display: flex; gap: .25rem; border-bottom: 2px solid #e8f0e9; }
.spc__tab { background: none; border: none; padding: .55rem 1rem; font-size: .85rem; font-weight: 600; color: #60725d; cursor: pointer; border-bottom: 2px solid transparent; margin-bottom: -2px; transition: all .15s; }
.spc__tab:hover { color: #0f2611; }
.spc__tab--active { color: #1b5e20; border-bottom-color: #1b5e20; }

/* Section */
.spc__section { display: flex; flex-direction: column; gap: 1.25rem; }
.spc__section-top { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; flex-wrap: wrap; }
.spc__section-desc { font-size: .85rem; color: #60725d; margin: 0; line-height: 1.6; max-width: 600px; }
.spc__loading { font-size: .85rem; color: #60725d; padding: 1rem 0; }
.spc__empty   { font-size: .875rem; color: #60725d; background: #f6faf6; border: 1px dashed #c8e6c9; border-radius: 10px; padding: 1.5rem; text-align: center; }

/* Fase groups */
.spc__fase-group { background: #fff; border: 1px solid #e8f0e9; border-radius: 12px; overflow: hidden; }
.spc__fase-header { padding: .65rem 1rem; font-size: .8rem; font-weight: 700; text-transform: uppercase; letter-spacing: .05em; color: #15803d; background: #f6faf6; border-bottom: 1px solid #e8f0e9; }

/* Table */
.spc__table { width: 100%; border-collapse: collapse; font-size: .82rem; }
.spc__table th { padding: .5rem 1rem; text-align: left; font-size: .7rem; font-weight: 600; text-transform: uppercase; letter-spacing: .04em; color: #60725d; background: #fafcfa; border-bottom: 1px solid #e8f0e9; }
.spc__table td { padding: .55rem 1rem; color: #0f2611; border-bottom: 1px solid #f6faf6; }
.spc__table tr:last-child td { border-bottom: none; }
.spc__table tr:hover td { background: #fafcfa; }
.spc__td-param  { font-weight: 600; }
.spc__td-unit   { color: #60725d; font-size: .75rem; }
.spc__td-actions { display: flex; align-items: center; gap: .35rem; justify-content: flex-end; }

.spc__btn-icon { background: #f6faf6; border: 1px solid #e8f0e9; border-radius: 6px; width: 28px; height: 28px; display: flex; align-items: center; justify-content: center; cursor: pointer; color: #60725d; font-size: .8rem; transition: all .12s; }
.spc__btn-icon:hover { background: #e8f0e9; color: #0f2611; }
.spc__btn-icon--danger:hover { background: #fef2f2; border-color: #fca5a5; color: #dc2626; }

/* Buttons */
.spc__btn-primary { background: #1b5e20; color: #fff; border: none; border-radius: 9px; padding: .55rem 1.1rem; font-size: .875rem; font-weight: 600; cursor: pointer; transition: background .15s; white-space: nowrap; }
.spc__btn-primary:hover:not(:disabled) { background: #144a18; }
.spc__btn-primary:disabled { opacity: .6; cursor: not-allowed; }
.spc__btn-ghost { background: #f8fafc; color: #475569; border: 1.5px solid #e2e8f0; border-radius: 9px; padding: .55rem 1.1rem; font-size: .875rem; font-weight: 600; cursor: pointer; transition: all .15s; }
.spc__btn-ghost:hover { background: #e2e8f0; }

/* Form */
.spc__form { display: flex; flex-direction: column; gap: 1.5rem; }
.spc__fieldset { border: 1px solid #e8f0e9; border-radius: 12px; padding: 1.25rem; margin: 0; display: flex; flex-direction: column; gap: 1rem; }
.spc__legend { font-size: .875rem; font-weight: 700; color: #0f2611; padding: 0 .25rem; }
.spc__field-desc { font-size: .82rem; color: #60725d; margin: 0; line-height: 1.5; }
.spc__field-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 1rem; }
.spc__field { display: flex; flex-direction: column; gap: .35rem; }
.spc__label { font-size: .78rem; font-weight: 600; color: #475569; }
.spc__opt   { font-weight: 400; color: #94a3b8; }
.spc__input-wrap { display: flex; align-items: center; gap: .5rem; }
.spc__input { border: 1.5px solid #e8f0e9; border-radius: 8px; padding: .45rem .65rem; font-size: .875rem; color: #0f2611; background: #fff; transition: border-color .15s; width: 80px; }
.spc__input:focus { outline: none; border-color: #1b5e20; }
.spc__input--sm { width: 80px; }
.spc__input-suffix { font-size: .78rem; color: #60725d; white-space: nowrap; }
.spc__form-footer { display: flex; justify-content: flex-end; padding-top: .5rem; }

/* Modal */
.spc__modal-overlay { position: fixed; inset: 0; background: rgba(0,0,0,.35); z-index: 1040; display: flex; align-items: center; justify-content: center; padding: 1rem; }
.spc__modal { background: #fff; border-radius: 16px; width: 100%; max-width: 520px; box-shadow: 0 20px 60px rgba(0,0,0,.18); display: flex; flex-direction: column; animation: spc-pop .18s ease; }
@keyframes spc-pop { from { opacity: 0; transform: scale(.95); } to { opacity: 1; transform: scale(1); } }
.spc__modal-header { display: flex; align-items: center; justify-content: space-between; padding: 1.25rem 1.5rem; border-bottom: 1px solid #f1f5f9; }
.spc__modal-title  { font-size: .95rem; font-weight: 700; color: #0f172a; margin: 0; }
.spc__modal-close  { background: #f1f5f9; border: none; width: 30px; height: 30px; border-radius: 8px; cursor: pointer; display: flex; align-items: center; justify-content: center; color: #64748b; }
.spc__modal-close:hover { background: #e2e8f0; }
.spc__modal-body { padding: 1.5rem; display: flex; flex-direction: column; gap: 1rem; }
.spc__mfield { display: flex; flex-direction: column; gap: .35rem; }
.spc__select { border: 1.5px solid #e8f0e9; border-radius: 8px; padding: .45rem .65rem; font-size: .875rem; color: #0f2611; background: #fff; transition: border-color .15s; width: 100%; }
.spc__select:focus { outline: none; border-color: #1b5e20; }
.spc__select:disabled { background: #f6faf6; color: #60725d; }
.spc__mrow { display: grid; grid-template-columns: 1fr 1fr 1fr; gap: .75rem; }
.spc__mrow .spc__input { width: 100%; box-sizing: border-box; }
.spc__modal-error { font-size: .8rem; color: #dc2626; background: #fef2f2; border: 1px solid #fca5a5; border-radius: 8px; padding: .5rem .75rem; }
.spc__modal-footer { display: flex; justify-content: flex-end; gap: .5rem; padding-top: .25rem; }
</style>
