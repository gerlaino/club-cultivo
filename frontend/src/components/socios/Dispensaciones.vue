<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { useAuthStore } from '../../stores/auth'
import {
  listDispensaciones, createDispensacion, updateDispensacion, deleteDispensacion,
  listIndicaciones, listLotes,
} from '../../lib/api.js'

const props = defineProps({
  socioId: { type: Number, required: true }
})

const auth           = useAuthStore()
const dispensaciones = ref([])
const indicaciones   = ref([])
const lotes          = ref([])
const loading        = ref(true)
const showModal      = ref(false)
const editingId      = ref(null)
const saving         = ref(false)
const deleting       = ref(false)
const showDelete     = ref(false)
const deleteTarget   = ref(null)
const formError      = ref(null)

const canCreate = computed(() => ['admin'].includes(auth.user?.role))
const canEdit   = computed(() => ['admin', 'medico', 'agricultor'].includes(auth.user?.role))

const today = new Date().toISOString().split('T')[0]

function fmt(n) {
  if (!n && n !== 0) return '—'
  return new Intl.NumberFormat('es-AR', { style: 'currency', currency: 'ARS', minimumFractionDigits: 0 }).format(n)
}
function formatDate(d) {
  if (!d) return '—'
  return new Date(d).toLocaleDateString('es-AR', { day: 'numeric', month: 'short', year: 'numeric' })
}

function tipoMeta(tipo) {
  return {
    flores:   { label: 'Flores',   color: '#15803d', bg: 'rgba(21,128,61,.1)'  },
    aceite:   { label: 'Aceite',   color: '#d97706', bg: 'rgba(217,119,6,.1)'  },
    extracto: { label: 'Extracto', color: '#7c3aed', bg: 'rgba(124,58,237,.1)' },
    crema:    { label: 'Crema',    color: '#0891b2', bg: 'rgba(8,145,178,.1)'  },
  }[tipo] || { label: tipo, color: '#64748b', bg: 'rgba(100,116,139,.1)' }
}

// Total general dispensado
const totalGramos = computed(() =>
  dispensaciones.value.reduce((s, d) => s + (parseFloat(d.cantidad_gramos) || 0), 0)
)

function emptyForm() {
  return {
    cantidad_gramos:      null,
    tipo_producto:        'flores',
    fecha_dispensacion:   today,
    lote_id:              null,
    indicacion_medica_id: null,
    aporte_socio_ars:     null,
    observaciones:        '',
  }
}
const form = ref(emptyForm())

function openCreate() {
  editingId.value = null; form.value = emptyForm(); formError.value = null; showModal.value = true
}
function openEdit(disp) {
  editingId.value = disp.id
  form.value = {
    cantidad_gramos:      disp.cantidad_gramos,
    tipo_producto:        disp.tipo_producto,
    fecha_dispensacion:   disp.fecha_dispensacion,
    lote_id:              disp.lote?.id              || null,
    indicacion_medica_id: disp.indicacion_medica?.id || null,
    aporte_socio_ars:     disp.aporte_socio_ars      || null,
    observaciones:        disp.observaciones         || '',
  }
  formError.value = null; showModal.value = true
}

async function loadDispensaciones() {
  loading.value = true
  try {
    const { data } = await listDispensaciones(props.socioId)
    dispensaciones.value = data.dispensaciones || data || []
  } catch (e) { console.error('Error cargando dispensaciones:', e) }
  finally { loading.value = false }
}

async function handleSubmit() {
  if (!form.value.cantidad_gramos || form.value.cantidad_gramos <= 0) {
    formError.value = 'La cantidad debe ser mayor a 0'; return
  }
  saving.value = true; formError.value = null
  try {
    const payload = { ...form.value }
    Object.keys(payload).forEach(k => {
      if (payload[k] === '' || payload[k] === null || payload[k] === undefined) delete payload[k]
    })
    if (editingId.value) await updateDispensacion(editingId.value, payload)
    else await createDispensacion(props.socioId, payload)
    await loadDispensaciones(); showModal.value = false
  } catch (e) {
    formError.value = e.response?.data?.errors?.[0] || 'Error al guardar'
  } finally { saving.value = false }
}

async function handleDelete() {
  deleting.value = true
  try {
    await deleteDispensacion(deleteTarget.value.id)
    await loadDispensaciones(); showDelete.value = false
  } catch { } finally { deleting.value = false }
}

onMounted(async () => {
  const [, indRes, lotesRes] = await Promise.allSettled([
    loadDispensaciones(),
    listIndicaciones(props.socioId),
    listLotes(),
  ])
  if (indRes.status   === 'fulfilled') indicaciones.value = (indRes.value.data || []).filter(i => i.activa)
  if (lotesRes.status === 'fulfilled') lotes.value        = lotesRes.value.data || []
})
</script>

<template>
  <div class="dv">

    <!-- Header -->
    <div class="dv__header">
      <div>
        <div class="dv__header-title">
          <i class="bi bi-capsule"></i> Dispensaciones
        </div>
        <div class="dv__header-sub">
          Registro de entregas al paciente
          <span v-if="dispensaciones.length"> · <strong>{{ totalGramos.toFixed(1) }}g</strong> dispensados en total</span>
        </div>
      </div>
      <button v-if="canCreate" class="dv__btn-primary" @click="openCreate">
        <i class="bi bi-plus-lg"></i> Nueva dispensación
      </button>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="dv__loading">
      <div class="dv__ring"></div><span>Cargando…</span>
    </div>

    <!-- Vacío -->
    <div v-else-if="!dispensaciones.length" class="dv__empty">
      <div class="dv__empty-icon"><i class="bi bi-capsule"></i></div>
      <div class="dv__empty-title">Sin dispensaciones registradas</div>
      <p class="dv__empty-desc">Las entregas al paciente aparecerán aquí.</p>
      <button v-if="canCreate" class="dv__btn-primary" @click="openCreate">
        <i class="bi bi-plus-lg"></i> Registrar primera dispensación
      </button>
    </div>

    <!-- Lista -->
    <div v-else class="dv__list">
      <div v-for="d in dispensaciones" :key="d.id" class="dv__item">
        <div class="dv__item-left">
          <div class="dv__item-fecha">{{ formatDate(d.fecha_dispensacion) }}</div>
          <div class="dv__item-desc">
            <span class="dv__tipo-pill" :style="{ background: tipoMeta(d.tipo_producto).bg, color: tipoMeta(d.tipo_producto).color }">
              {{ tipoMeta(d.tipo_producto).label }}
            </span>
            <span v-if="d.lote?.codigo" class="dv__lote-ref">
              <i class="bi bi-box-seam"></i> {{ d.lote.codigo }}
            </span>
          </div>
          <div v-if="d.observaciones" class="dv__item-obs">{{ d.observaciones }}</div>
        </div>
        <div class="dv__item-center">
          <div class="dv__item-gramos">{{ d.cantidad_gramos }}g</div>
          <div v-if="d.aporte_socio_ars" class="dv__item-aporte">{{ fmt(d.aporte_socio_ars) }}</div>
        </div>
        <div class="dv__item-meta">
          <div v-if="d.usuario?.nombre" class="dv__item-usuario">{{ d.usuario.nombre }}</div>
        </div>
        <div v-if="canEdit" class="dv__item-actions">
          <button class="dv__icon-btn" @click="openEdit(d)" title="Editar"><i class="bi bi-pencil"></i></button>
          <button class="dv__icon-btn dv__icon-btn--danger" @click="deleteTarget=d; showDelete=true" title="Eliminar">
            <i class="bi bi-trash"></i>
          </button>
        </div>
      </div>
    </div>

    <!-- ══ Modal crear/editar ══ -->
    <Teleport to="body">
      <div v-if="showModal" class="dv__overlay" @click.self="showModal=false">
        <div class="dv__modal">
          <div class="dv__modal-header">
            <div>
              <h3 class="dv__modal-title">{{ editingId ? 'Editar dispensación' : 'Nueva dispensación' }}</h3>
              <p class="dv__modal-sub">{{ editingId ? 'Modificá los datos' : 'Registrá una entrega al paciente' }}</p>
            </div>
            <button class="dv__modal-close" @click="showModal=false"><i class="bi bi-x-lg"></i></button>
          </div>
          <div class="dv__modal-body">

            <div v-if="formError" class="dv__error">
              <i class="bi bi-exclamation-triangle-fill"></i> {{ formError }}
            </div>

            <div class="dv__form-grid">

              <!-- Cantidad -->
              <div class="dv__field">
                <label class="dv__label">Cantidad (gramos) <span class="dv__req">*</span></label>
                <div class="dv__input-suffix-wrap">
                  <input v-model.number="form.cantidad_gramos" type="number" step="0.01" min="0.01"
                         class="dv__input dv__input--with-suffix" placeholder="Ej: 10" />
                  <span class="dv__input-suffix">g</span>
                </div>
              </div>

              <!-- Tipo producto -->
              <div class="dv__field">
                <label class="dv__label">Tipo de producto <span class="dv__req">*</span></label>
                <select v-model="form.tipo_producto" class="dv__input">
                  <option value="flores">Flores</option>
                  <option value="aceite">Aceite</option>
                  <option value="extracto">Extracto</option>
                  <option value="crema">Crema</option>
                </select>
              </div>

              <!-- Fecha -->
              <div class="dv__field">
                <label class="dv__label">Fecha <span class="dv__req">*</span></label>
                <input v-model="form.fecha_dispensacion" type="date" class="dv__input" :max="today" />
              </div>

              <!-- Aporte socio -->
              <div class="dv__field">
                <label class="dv__label">Aporte del socio (ARS) <span class="dv__opt">opcional</span></label>
                <div class="dv__input-prefix-wrap">
                  <span class="dv__input-prefix">$</span>
                  <input v-model.number="form.aporte_socio_ars" type="number" min="0" step="0.01"
                         class="dv__input dv__input--prefixed" placeholder="0" />
                </div>
              </div>

              <!-- Lote -->
              <div class="dv__field">
                <label class="dv__label">Lote <span class="dv__opt">opcional</span></label>
                <select v-model="form.lote_id" class="dv__input">
                  <option :value="null">Sin lote asignado</option>
                  <option v-for="l in lotes" :key="l.id" :value="l.id">
                    {{ l.codigo }}
                  </option>
                </select>
              </div>

              <!-- Indicación -->
              <div class="dv__field">
                <label class="dv__label">Indicación médica <span class="dv__opt">opcional</span></label>
                <select v-model="form.indicacion_medica_id" class="dv__input">
                  <option :value="null">Sin indicación asociada</option>
                  <option v-for="i in indicaciones" :key="i.id" :value="i.id">{{ i.patologia }}</option>
                </select>
              </div>

              <!-- Observaciones -->
              <div class="dv__field dv__field--full">
                <label class="dv__label">Observaciones <span class="dv__opt">opcional</span></label>
                <textarea v-model.trim="form.observaciones" class="dv__input dv__textarea" rows="2"
                          placeholder="Notas adicionales…"></textarea>
              </div>

            </div>
          </div>
          <div class="dv__modal-footer">
            <button class="dv__btn-ghost" :disabled="saving" @click="showModal=false">Cancelar</button>
            <button class="dv__btn-primary" :disabled="saving" @click="handleSubmit">
              <div v-if="saving" class="dv__spinner"></div>
              <i v-else class="bi bi-check-lg"></i>
              {{ editingId ? 'Guardar cambios' : 'Registrar dispensación' }}
            </button>
          </div>
        </div>
      </div>
    </Teleport>

    <!-- ══ Modal eliminar ══ -->
    <Teleport to="body">
      <div v-if="showDelete" class="dv__overlay" @click.self="showDelete=false">
        <div class="dv__modal dv__modal--sm">
          <div class="dv__delete-icon"><i class="bi bi-exclamation-triangle-fill"></i></div>
          <h3 class="dv__delete-title">¿Eliminar dispensación?</h3>
          <p class="dv__delete-desc">
            <strong>{{ deleteTarget?.cantidad_gramos }}g</strong> de {{ deleteTarget?.tipo_producto }}
            · {{ formatDate(deleteTarget?.fecha_dispensacion) }}
          </p>
          <div class="dv__delete-actions">
            <button class="dv__btn-ghost" :disabled="deleting" @click="showDelete=false">Cancelar</button>
            <button class="dv__btn-danger" :disabled="deleting" @click="handleDelete">
              <div v-if="deleting" class="dv__spinner dv__spinner--white"></div>
              <i v-else class="bi bi-trash"></i> Eliminar
            </button>
          </div>
        </div>
      </div>
    </Teleport>

  </div>
</template>

<style scoped>
.dv { font-family: system-ui, -apple-system, sans-serif; color: #0f172a; }

/* Header */
.dv__header { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; padding: 1.1rem 1.25rem; border-bottom: 1px solid #f1f5f9; }
.dv__header-title { font-size: .9rem; font-weight: 700; color: #0f172a; margin-bottom: .2rem; }
.dv__header-sub { font-size: .75rem; color: #64748b; }

/* Loading / Empty */
.dv__loading { display: flex; align-items: center; justify-content: center; gap: .65rem; padding: 3rem; color: #94a3b8; font-size: .875rem; }
.dv__ring { width: 18px; height: 18px; border: 2px solid #e2e8f0; border-top-color: #1b5e20; border-radius: 50%; animation: dv-spin .7s linear infinite; }
@keyframes dv-spin { to { transform: rotate(360deg); } }
.dv__empty { text-align: center; padding: 3rem 1rem; color: #94a3b8; }
.dv__empty-icon { font-size: 2.5rem; margin-bottom: .75rem; opacity: .4; }
.dv__empty-title { font-size: .9rem; font-weight: 700; color: #0f172a; margin-bottom: .4rem; }
.dv__empty-desc { font-size: .82rem; margin-bottom: 1.25rem; }

/* Lista */
.dv__list { display: flex; flex-direction: column; }
.dv__item { display: flex; align-items: center; gap: 1rem; padding: .875rem 1.25rem; border-bottom: 1px solid #f8fafc; transition: background .1s; }
.dv__item:last-child { border-bottom: none; }
.dv__item:hover { background: #fafbfc; }
.dv__item-left { flex: 1; min-width: 0; }
.dv__item-fecha { font-size: .75rem; color: #94a3b8; font-family: monospace; margin-bottom: .25rem; }
.dv__item-desc { display: flex; align-items: center; gap: .5rem; flex-wrap: wrap; margin-bottom: .2rem; }
.dv__tipo-pill { font-size: .68rem; font-weight: 700; padding: .2em .65em; border-radius: 6px; }
.dv__lote-ref { font-size: .72rem; color: #64748b; display: flex; align-items: center; gap: .25rem; }
.dv__item-obs { font-size: .73rem; color: #94a3b8; font-style: italic; }
.dv__item-center { text-align: right; flex-shrink: 0; min-width: 70px; }
.dv__item-gramos { font-size: 1.05rem; font-weight: 800; color: #1b5e20; letter-spacing: -.03em; }
.dv__item-aporte { font-size: .72rem; color: #64748b; margin-top: .1rem; }
.dv__item-meta { flex-shrink: 0; min-width: 100px; text-align: right; }
.dv__item-usuario { font-size: .72rem; color: #94a3b8; }
.dv__item-actions { display: flex; gap: .3rem; flex-shrink: 0; }
.dv__icon-btn { width: 28px; height: 28px; border-radius: 7px; border: 1px solid #e2e8f0; background: #f8fafc; color: #64748b; display: flex; align-items: center; justify-content: center; cursor: pointer; font-size: .75rem; transition: all .15s; }
.dv__icon-btn:hover { background: #e2e8f0; color: #0f172a; }
.dv__icon-btn--danger:hover { background: #fef2f2; border-color: #fecaca; color: #dc2626; }

/* Botones */
.dv__btn-primary { display: inline-flex; align-items: center; gap: .4rem; background: #1b5e20; color: #fff; border: none; padding: .6rem 1.1rem; border-radius: 9px; font-size: .82rem; font-weight: 600; cursor: pointer; transition: background .15s; white-space: nowrap; }
.dv__btn-primary:hover:not(:disabled) { background: #144a18; }
.dv__btn-primary:disabled { opacity: .5; cursor: not-allowed; }
.dv__btn-ghost { background: #fff; color: #64748b; border: 1.5px solid #e2e8f0; padding: .6rem 1.1rem; border-radius: 9px; font-size: .875rem; font-weight: 500; cursor: pointer; }
.dv__btn-ghost:hover { background: #f8fafc; }
.dv__btn-danger { display: inline-flex; align-items: center; gap: .35rem; background: #dc2626; color: #fff; border: none; padding: .65rem 1.25rem; border-radius: 9px; font-size: .875rem; font-weight: 600; cursor: pointer; }
.dv__btn-danger:hover:not(:disabled) { background: #b91c1c; }
.dv__btn-danger:disabled { opacity: .55; }

/* Spinner */
.dv__spinner { width: 14px; height: 14px; border: 2px solid rgba(27,94,32,.2); border-top-color: #1b5e20; border-radius: 50%; animation: dv-spin .6s linear infinite; }
.dv__spinner--white { border-color: rgba(255,255,255,.3); border-top-color: #fff; }

/* Modal */
.dv__overlay { position: fixed; inset: 0; background: rgba(0,0,0,.4); display: flex; align-items: center; justify-content: center; z-index: 1050; padding: 1rem; backdrop-filter: blur(3px); }
.dv__modal { background: #fff; border-radius: 18px; width: 100%; max-width: 580px; max-height: 90vh; overflow-y: auto; box-shadow: 0 24px 64px rgba(0,0,0,.15); display: flex; flex-direction: column; }
.dv__modal--sm { max-width: 400px; text-align: center; padding: 2.5rem 2rem; }
.dv__modal-header { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; padding: 1.5rem 1.5rem 1.25rem; border-bottom: 1px solid #f1f5f9; position: sticky; top: 0; background: #fff; z-index: 1; }
.dv__modal-title { font-size: 1.05rem; font-weight: 700; color: #0f172a; margin: 0; }
.dv__modal-sub { font-size: .78rem; color: #64748b; margin: .2rem 0 0; }
.dv__modal-close { background: #f1f5f9; border: none; width: 30px; height: 30px; border-radius: 8px; cursor: pointer; display: flex; align-items: center; justify-content: center; color: #64748b; flex-shrink: 0; }
.dv__modal-close:hover { background: #e2e8f0; }
.dv__modal-body { padding: 1.5rem; flex: 1; }
.dv__modal-footer { display: flex; justify-content: flex-end; gap: .75rem; padding: 1.1rem 1.5rem; border-top: 1px solid #f1f5f9; position: sticky; bottom: 0; background: #fff; }

/* Form */
.dv__form-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; }
@media (max-width: 480px) { .dv__form-grid { grid-template-columns: 1fr; } }
.dv__field { display: flex; flex-direction: column; gap: .35rem; }
.dv__field--full { grid-column: 1 / -1; }
.dv__label { font-size: .72rem; font-weight: 700; color: #374151; text-transform: uppercase; letter-spacing: .05em; }
.dv__req { color: #ef4444; }
.dv__opt { font-size: .67rem; font-weight: 400; color: #94a3b8; text-transform: none; letter-spacing: 0; }
.dv__input { background: #f8fafc; border: 1.5px solid #e2e8f0; border-radius: 9px; padding: .65rem .875rem; font-size: .875rem; color: #0f172a; width: 100%; box-sizing: border-box; outline: none; transition: border-color .15s; }
.dv__input:focus { border-color: #1b5e20; background: #fff; }
.dv__textarea { resize: vertical; min-height: 65px; }
.dv__input-prefix-wrap { display: flex; }
.dv__input-prefix { background: #f1f5f9; border: 1.5px solid #e2e8f0; border-right: none; padding: .65rem .75rem; font-size: .82rem; font-weight: 700; color: #1b5e20; border-radius: 9px 0 0 9px; }
.dv__input--prefixed { border-radius: 0 9px 9px 0; border-left: none; }
.dv__input-suffix-wrap { display: flex; }
.dv__input--with-suffix { border-radius: 9px 0 0 9px; }
.dv__input-suffix { background: #f1f5f9; border: 1.5px solid #e2e8f0; border-left: none; padding: .65rem .75rem; font-size: .82rem; font-weight: 700; color: #64748b; border-radius: 0 9px 9px 0; }
.dv__error { display: flex; align-items: center; gap: .45rem; background: #fef2f2; border: 1px solid #fecaca; color: #dc2626; padding: .65rem .875rem; border-radius: 9px; font-size: .82rem; margin-bottom: 1rem; }

/* Delete modal */
.dv__delete-icon { width: 56px; height: 56px; border-radius: 50%; background: #fef2f2; color: #dc2626; font-size: 1.4rem; display: flex; align-items: center; justify-content: center; margin: 0 auto 1rem; }
.dv__delete-title { font-size: 1.1rem; font-weight: 800; color: #0f172a; margin: 0 0 .65rem; letter-spacing: -.03em; }
.dv__delete-desc { font-size: .875rem; color: #64748b; margin: 0 0 1.5rem; line-height: 1.6; }
.dv__delete-actions { display: flex; gap: .65rem; justify-content: center; }
</style>
