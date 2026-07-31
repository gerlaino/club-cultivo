<template>
  <div class="cln">
    <div v-if="loading" class="cln__placeholder">Cargando clonadores…</div>

    <div v-else-if="!items.length" class="cln__empty">
      <span class="cln__empty-emoji">🌱</span>
      <div>
        <div class="cln__empty-title">Sin clonadores en esta sala</div>
        <p class="cln__empty-msg">
          Un clonador es un domo con su propio clima: la sala marca 60% de humedad y adentro hay 90%.
          El lote que enraíza adentro recibe ese clima, no el del cuarto.
        </p>
      </div>
      <button v-if="puedeEditar" class="cln__btn" @click="abrirNuevo">
        <i class="bi bi-plus-lg"></i> Crear el primero
      </button>
    </div>

    <template v-else>
      <div class="cln__grid">
        <div v-for="c in items" :key="c.id" class="cln__card" :class="{ 'cln__card--off': !c.activo }">
          <div class="cln__card-head">
            <div class="cln__card-title">
              <span class="cln__emoji">🌱</span>
              <strong>{{ c.nombre }}</strong>
              <span v-if="!c.activo" class="cln__badge cln__badge--off">Inactivo</span>
              <span v-else-if="c.libre" class="cln__badge cln__badge--libre">Libre</span>
              <span v-else class="cln__badge cln__badge--ocupado">Ocupado</span>
            </div>
            <div v-if="puedeEditar" class="cln__card-actions">
              <button class="cln__icon-btn" title="Editar" @click="abrirEditar(c)"><i class="bi bi-pencil"></i></button>
              <button class="cln__icon-btn cln__icon-btn--danger" title="Eliminar" @click="pedirBorrar(c)"><i class="bi bi-trash"></i></button>
            </div>
          </div>

          <!-- Qué tiene adentro. Un clonador aloja UN lote a la vez. -->
          <div class="cln__row">
            <template v-if="c.lote_adentro">
              <RouterLink :to="{ name: 'lote-detail', params: { id: c.lote_adentro.id } }" class="cln__lote">
                {{ c.lote_adentro.codigo }}
              </RouterLink>
              <span class="cln__muted">
                {{ c.ocupados }}<template v-if="c.capacidad"> / {{ c.capacidad }}</template> plantas
              </span>
            </template>
            <span v-else class="cln__muted">
              Vacío<template v-if="c.capacidad"> · {{ c.capacidad }} alvéolos</template>
            </span>
          </div>

          <!-- Ambiente del domo, con su antigüedad: sin sensores el dato puede ser de hace días,
               y mostrarlo pelado haría creer que es de ahora. -->
          <div class="cln__amb">
            <template v-if="c.ambiente_actual">
              <span v-if="c.ambiente_actual.temperatura != null" class="cln__metric">
                🌡️ {{ c.ambiente_actual.temperatura }}°
              </span>
              <span v-if="c.ambiente_actual.humedad != null" class="cln__metric">
                💧 {{ c.ambiente_actual.humedad }}%
              </span>
              <span v-if="c.ambiente_actual.temperatura_sustrato != null" class="cln__metric">
                🪴 {{ c.ambiente_actual.temperatura_sustrato }}°
              </span>
              <span class="cln__ago">{{ hace(c.ambiente_actual.registrado_en) }}</span>
            </template>
            <span v-else class="cln__muted cln__muted--sm">Sin registros de ambiente</span>
          </div>

          <button v-if="puedeEditar" class="cln__btn cln__btn--ghost" :disabled="!c.lote_adentro"
                  :title="c.lote_adentro ? '' : 'Sin lote adentro no hay a quién registrarle el ambiente'"
                  @click="abrirRegistro(c)">
            <i class="bi bi-thermometer-half"></i> Registrar ambiente
          </button>
        </div>
      </div>

      <button v-if="puedeEditar" class="cln__add" @click="abrirNuevo">
        <i class="bi bi-plus-lg"></i> Agregar clonador
      </button>
    </template>

    <!-- ══ Alta / edición ══ -->
    <Teleport to="body">
      <div v-if="showForm" class="cln__overlay" @click.self="showForm = false">
        <div class="cln__modal">
          <div class="cln__modal-head">
            <h3>{{ editando ? 'Editar clonador' : 'Nuevo clonador' }}</h3>
            <button class="cln__modal-close" @click="showForm = false"><i class="bi bi-x-lg"></i></button>
          </div>
          <div class="cln__modal-body">
            <div v-if="formError" class="cln__alert">{{ formError }}</div>
            <div class="cln__field">
              <label class="cln__label">Nombre <span class="cln__req">*</span></label>
              <input v-model.trim="form.nombre" type="text" class="cln__input" placeholder="Ej. Domo 1"
                     @keydown.enter="guardar" />
            </div>
            <div class="cln__field">
              <label class="cln__label">Capacidad <span class="cln__opt">(opcional)</span></label>
              <input v-model.number="form.capacidad" type="number" min="1" class="cln__input" placeholder="Alvéolos" />
              <span class="cln__hint">Solo informativo: avisa si se pasa, no lo impide.</span>
            </div>
            <label v-if="editando" class="cln__check">
              <input type="checkbox" v-model="form.activo" /> Activo
            </label>
          </div>
          <div class="cln__modal-foot">
            <button class="cln__btn cln__btn--ghost" @click="showForm = false">Cancelar</button>
            <button class="cln__btn" :disabled="saving || !form.nombre" @click="guardar">
              {{ saving ? 'Guardando…' : 'Guardar' }}
            </button>
          </div>
        </div>
      </div>
    </Teleport>

    <!-- ══ Registro ambiental del domo ══ -->
    <Teleport to="body">
      <div v-if="showRegistro" class="cln__overlay" @click.self="showRegistro = false">
        <div class="cln__modal">
          <div class="cln__modal-head">
            <div>
              <h3>Ambiente del domo</h3>
              <p class="cln__modal-sub">{{ registroClonador?.nombre }} · {{ registroClonador?.lote_adentro?.codigo }}</p>
            </div>
            <button class="cln__modal-close" @click="showRegistro = false"><i class="bi bi-x-lg"></i></button>
          </div>
          <div class="cln__modal-body">
            <div v-if="registroError" class="cln__alert">{{ registroError }}</div>
            <!-- Cuatro campos y nada más: adentro de un domo no hay riego, ni EC, ni pH. Un esqueje
                 sin raíz no absorbe, así que pedir esos datos sería pedir algo que no existe. -->
            <div class="cln__grid2">
              <div class="cln__field">
                <label class="cln__label">Temperatura (°C)</label>
                <input v-model.number="registro.temperatura" type="number" step="0.1" class="cln__input" placeholder="24" />
              </div>
              <div class="cln__field">
                <label class="cln__label">Humedad (%)</label>
                <input v-model.number="registro.humedad" type="number" step="1" class="cln__input" placeholder="90" />
              </div>
              <div class="cln__field">
                <label class="cln__label">Temp. de sustrato (°C)</label>
                <input v-model.number="registro.temperatura_sustrato" type="number" step="0.1" class="cln__input" placeholder="25" />
                <span class="cln__hint">Decide el prendimiento más que la del aire.</span>
              </div>
              <div class="cln__field">
                <label class="cln__label">Enraizante</label>
                <select v-model="registro.producto_enraizante" class="cln__input">
                  <option value="">— Sin especificar —</option>
                  <option v-for="e in ENRAIZANTES" :key="e.v" :value="e.v">{{ e.l }}</option>
                </select>
              </div>
            </div>
          </div>
          <div class="cln__modal-foot">
            <button class="cln__btn cln__btn--ghost" @click="showRegistro = false">Cancelar</button>
            <button class="cln__btn" :disabled="savingRegistro" @click="guardarRegistro">
              {{ savingRegistro ? 'Guardando…' : 'Registrar' }}
            </button>
          </div>
        </div>
      </div>
    </Teleport>

    <ConfirmDialog
      v-model="showBorrar"
      title="Eliminar clonador"
      :message="`¿Eliminar ${aBorrar?.nombre}? El lote que tenga adentro queda en la sala, sin domo.`"
      confirm-text="Eliminar"
      danger
      @confirm="borrar"
    />
  </div>
</template>

<script setup>
import { ref, onMounted, watch } from 'vue'
import { RouterLink } from 'vue-router'
import { listClonadores, createClonador, updateClonador, deleteClonador, registrarClonador } from '../../lib/api.js'
import { useToast } from '../../composables/useToast.js'
import ConfirmDialog from '../ui/ConfirmDialog.vue'

const props = defineProps({
  salaId:      { type: [Number, String], required: true },
  puedeEditar: { type: Boolean, default: false },
})
const emit = defineEmits(['changed'])

const toast   = useToast()
const items   = ref([])
const loading = ref(false)

// Enraizantes: estructurado, no texto libre. Distintos geles/polvos prenden distinto, y así se
// puede cruzar con el % de prendimiento. Espeja RegistroAmbiental::ENRAIZANTES.
const ENRAIZANTES = [
  { v: 'gel',         l: 'Gel' },
  { v: 'polvo',       l: 'Polvo' },
  { v: 'liquido',     l: 'Líquido' },
  { v: 'miel_canela', l: 'Miel / canela' },
  { v: 'ninguno',     l: 'Ninguno' },
  { v: 'otro',        l: 'Otro' },
]

async function cargar() {
  loading.value = true
  try {
    const { data } = await listClonadores(props.salaId)
    items.value = data || []
  } catch { items.value = [] } finally { loading.value = false }
}
onMounted(cargar)
watch(() => props.salaId, cargar)

// ── Alta / edición ─────────────────────────────────────────
const showForm  = ref(false)
const editando  = ref(null)
const form      = ref({ nombre: '', capacidad: null, activo: true })
const saving    = ref(false)
const formError = ref(null)

function abrirNuevo() {
  editando.value  = null
  form.value      = { nombre: `Domo ${items.value.length + 1}`, capacidad: null, activo: true }
  formError.value = null
  showForm.value  = true
}
function abrirEditar(c) {
  editando.value  = c
  form.value      = { nombre: c.nombre, capacidad: c.capacidad, activo: c.activo }
  formError.value = null
  showForm.value  = true
}
async function guardar() {
  if (!form.value.nombre) return
  saving.value = true; formError.value = null
  try {
    if (editando.value) await updateClonador(editando.value.id, form.value)
    else                await createClonador(props.salaId, form.value)
    showForm.value = false
    await cargar()
    emit('changed')
  } catch (e) {
    formError.value = e?.response?.data?.errors?.join(', ') || e?.response?.data?.error || 'No se pudo guardar'
  } finally { saving.value = false }
}

// ── Borrar ─────────────────────────────────────────────────
const showBorrar = ref(false)
const aBorrar    = ref(null)
function pedirBorrar(c) { aBorrar.value = c; showBorrar.value = true }
async function borrar() {
  try {
    await deleteClonador(aBorrar.value.id)
    toast.success('Clonador eliminado')
    await cargar()
    emit('changed')
  } catch (e) {
    toast.error(e?.response?.data?.error || 'No se pudo eliminar')
  }
}

// ── Registro ambiental ─────────────────────────────────────
const showRegistro     = ref(false)
const registroClonador = ref(null)
const registro         = ref({})
const savingRegistro   = ref(false)
const registroError    = ref(null)

function abrirRegistro(c) {
  registroClonador.value = c
  registro.value = { temperatura: null, humedad: null, temperatura_sustrato: null, producto_enraizante: '' }
  registroError.value = null
  showRegistro.value  = true
}
async function guardarRegistro() {
  savingRegistro.value = true; registroError.value = null
  try {
    const payload = { ...registro.value }
    Object.keys(payload).forEach(k => { if (payload[k] === null || payload[k] === '') delete payload[k] })
    await registrarClonador(registroClonador.value.id, payload)
    showRegistro.value = false
    toast.success('Ambiente del domo registrado')
    await cargar()
  } catch (e) {
    registroError.value = e?.response?.data?.errors?.join(', ') || e?.response?.data?.error || 'No se pudo registrar'
  } finally { savingRegistro.value = false }
}

// Antigüedad del dato: "hace 2 h" pesa distinto que "hace 3 días".
function hace(ts) {
  if (!ts) return ''
  const min = Math.floor((Date.now() - new Date(ts).getTime()) / 60000)
  if (min < 1)    return 'recién'
  if (min < 60)   return `hace ${min} min`
  const h = Math.floor(min / 60)
  if (h < 24)     return `hace ${h} h`
  const d = Math.floor(h / 24)
  return `hace ${d} día${d === 1 ? '' : 's'}`
}
</script>

<style scoped>
.cln__placeholder { padding: 1rem; color: #94a3b8; font-size: .85rem; }

.cln__empty { display: flex; align-items: flex-start; gap: .9rem; padding: 1.1rem; flex-wrap: wrap; }
.cln__empty-emoji { font-size: 1.6rem; }
.cln__empty-title { font-weight: 700; color: #1e293b; font-size: .92rem; }
.cln__empty-msg { margin: .25rem 0 0; font-size: .8rem; color: #64748b; max-width: 46ch; line-height: 1.45; }

.cln__grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(250px, 1fr)); gap: .75rem; padding: .9rem; }
.cln__card {
  border: 1px solid #e2e8f0; border-radius: 12px; padding: .8rem;
  display: flex; flex-direction: column; gap: .55rem; background: #fff;
}
.cln__card--off { opacity: .6; }
.cln__card-head { display: flex; align-items: center; justify-content: space-between; gap: .4rem; }
.cln__card-title { display: flex; align-items: center; gap: .4rem; font-size: .9rem; color: #1e293b; min-width: 0; }
.cln__card-title strong { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.cln__emoji { font-size: 1rem; }
.cln__card-actions { display: flex; gap: .15rem; flex-shrink: 0; }
.cln__icon-btn {
  border: none; background: none; cursor: pointer; color: #94a3b8;
  padding: .25rem; border-radius: 6px; font-size: .8rem;
}
.cln__icon-btn:hover { background: #f1f5f9; color: #475569; }
.cln__icon-btn--danger:hover { background: #fee2e2; color: #dc2626; }

.cln__badge { font-size: .62rem; font-weight: 700; padding: .12rem .4rem; border-radius: 999px; text-transform: uppercase; }
.cln__badge--libre   { background: #dcfce7; color: #15803d; }
.cln__badge--ocupado { background: #dbeafe; color: #1d4ed8; }
.cln__badge--off     { background: #f1f5f9; color: #64748b; }

.cln__row { display: flex; align-items: center; gap: .5rem; flex-wrap: wrap; font-size: .8rem; }
.cln__lote { font-weight: 700; color: #16a34a; text-decoration: none; }
.cln__lote:hover { text-decoration: underline; }
.cln__muted { color: #94a3b8; }
.cln__muted--sm { font-size: .75rem; }

.cln__amb { display: flex; align-items: center; gap: .55rem; flex-wrap: wrap; font-size: .8rem; color: #475569; }
.cln__metric { font-variant-numeric: tabular-nums; }
.cln__ago { font-size: .7rem; color: #94a3b8; }

.cln__add {
  margin: 0 .9rem .9rem; padding: .5rem .8rem; border: 1px dashed #cbd5e1; border-radius: 10px;
  background: none; cursor: pointer; color: #64748b; font-size: .8rem; width: calc(100% - 1.8rem);
}
.cln__add:hover { border-color: #16a34a; color: #16a34a; }

.cln__btn {
  border: none; border-radius: 8px; padding: .45rem .8rem; cursor: pointer;
  background: #16a34a; color: #fff; font-size: .8rem; font-weight: 600;
  display: inline-flex; align-items: center; gap: .35rem;
}
.cln__btn:disabled { opacity: .5; cursor: not-allowed; }
.cln__btn--ghost { background: none; color: #64748b; border: 1px solid #e2e8f0; }
.cln__btn--ghost:hover:not(:disabled) { background: #f8fafc; }

/* Modales */
.cln__overlay {
  position: fixed; inset: 0; background: rgba(15,23,42,.45); z-index: 1200;
  display: flex; align-items: center; justify-content: center; padding: 1rem;
}
.cln__modal { background: #fff; border-radius: 14px; width: 100%; max-width: 430px; overflow: hidden; }
.cln__modal-head {
  display: flex; align-items: flex-start; justify-content: space-between;
  padding: .9rem 1rem; border-bottom: 1px solid #f1f5f9;
}
.cln__modal-head h3 { margin: 0; font-size: .95rem; color: #1e293b; }
.cln__modal-sub { margin: .15rem 0 0; font-size: .75rem; color: #94a3b8; }
.cln__modal-close { border: none; background: none; cursor: pointer; color: #94a3b8; font-size: .85rem; }
.cln__modal-body { padding: 1rem; display: flex; flex-direction: column; gap: .75rem; }
.cln__modal-foot { display: flex; justify-content: flex-end; gap: .5rem; padding: .8rem 1rem; border-top: 1px solid #f1f5f9; }

.cln__grid2 { display: grid; grid-template-columns: 1fr 1fr; gap: .75rem; }
@media (max-width: 460px) { .cln__grid2 { grid-template-columns: 1fr; } }

.cln__field { display: flex; flex-direction: column; gap: .25rem; }
.cln__label { font-size: .75rem; font-weight: 600; color: #475569; }
.cln__req { color: #dc2626; }
.cln__opt { font-weight: 400; color: #94a3b8; }
.cln__input {
  border: 1px solid #e2e8f0; border-radius: 8px; padding: .5rem .65rem; font-size: .85rem;
  width: 100%; box-sizing: border-box;
}
.cln__input:focus { outline: none; border-color: #16a34a; }
.cln__hint { font-size: .7rem; color: #94a3b8; }
.cln__check { display: flex; align-items: center; gap: .4rem; font-size: .8rem; color: #475569; }
.cln__alert { background: #fee2e2; color: #b91c1c; padding: .5rem .7rem; border-radius: 8px; font-size: .78rem; }
</style>
