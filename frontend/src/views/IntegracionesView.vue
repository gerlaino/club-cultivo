<template>
  <div class="int">

    <div class="int__header">
      <div>
        <h1 class="int__title">Integraciones</h1>
        <p class="int__sub">Webhooks salientes — notificá sistemas externos cuando ocurren eventos en el club</p>
      </div>
      <button class="int__btn-nuevo" @click="abrirFormNuevo">
        <Plus :size="16" :stroke-width="2" /> Nuevo webhook
      </button>
    </div>

    <!-- Eventos disponibles (info) -->
    <div class="int__eventos-info">
      <span class="int__eventos-label">Eventos disponibles:</span>
      <span v-for="e in EVENTS_DISPONIBLES" :key="e.key" class="int__evento-chip">
        {{ e.key }}
      </span>
    </div>

    <!-- Lista -->
    <div v-if="loading" class="int__loading">
      <DsSpinner :size="28" />
    </div>

    <div v-else-if="!webhooks.length" class="int__empty">
      <div class="int__empty-ico">🔗</div>
      <div class="int__empty-titulo">Sin webhooks configurados</div>
      <div class="int__empty-sub">Creá uno para notificar tu sistema externo en tiempo real.</div>
    </div>

    <div v-else class="int__list">
      <div
        v-for="wh in webhooks"
        :key="wh.id"
        class="int__card"
        :class="{ 'int__card--inactive': !wh.active }"
      >
        <div class="int__card-header">
          <div class="int__card-left">
            <div class="int__card-dot" :class="wh.active ? 'int__card-dot--on' : 'int__card-dot--off'"></div>
            <div>
              <div class="int__card-nombre">{{ wh.nombre }}</div>
              <div class="int__card-url">{{ wh.url }}</div>
            </div>
          </div>
          <div class="int__card-actions">
            <button class="int__btn-icon" @click="verLog(wh)" title="Ver entregas">
              <Activity :size="15" :stroke-width="1.75" />
            </button>
            <button class="int__btn-icon" @click="abrirFormEditar(wh)" title="Editar">
              <Pencil :size="15" :stroke-width="1.75" />
            </button>
            <button class="int__btn-icon int__btn-icon--danger" @click="confirmarEliminar(wh)" title="Eliminar">
              <Trash2 :size="15" :stroke-width="1.75" />
            </button>
          </div>
        </div>

        <div class="int__card-events">
          <span v-for="ev in wh.events" :key="ev" class="int__ev-badge">{{ ev }}</span>
        </div>

        <div class="int__card-meta">
          <span v-if="wh.last_delivery_at">
            Último envío {{ timeAgo(wh.last_delivery_at) }}
          </span>
          <span v-else class="int__card-meta--dim">Sin entregas aún</span>
          <span class="int__card-meta-sep">·</span>
          <span>{{ wh.deliveries_count }} entregas totales</span>
        </div>

        <!-- Secret colapsable -->
        <div class="int__secret-row">
          <span class="int__secret-label">Secret:</span>
          <code class="int__secret-val" :class="{ 'int__secret-val--hidden': !showSecret[wh.id] }">
            {{ showSecret[wh.id] ? wh.secret : '••••••••••••••••' }}
          </code>
          <button class="int__secret-toggle" @click="showSecret[wh.id] = !showSecret[wh.id]">
            {{ showSecret[wh.id] ? 'Ocultar' : 'Mostrar' }}
          </button>
        </div>
      </div>
    </div>

    <!-- Modal form crear/editar -->
    <Transition name="modal-fade">
      <div v-if="showForm" class="int__overlay" @click.self="cerrarForm">
        <div class="int__modal">
          <div class="int__modal-header">
            <h2 class="int__modal-title">{{ editando ? 'Editar webhook' : 'Nuevo webhook' }}</h2>
            <button class="int__modal-close" @click="cerrarForm">
              <X :size="18" :stroke-width="1.75" />
            </button>
          </div>

          <div class="int__modal-body">
            <div v-if="formError" class="int__alert">{{ formError }}</div>

            <div class="int__field">
              <label class="int__label">Nombre <span class="int__req">*</span></label>
              <input v-model.trim="form.nombre" class="int__input" placeholder="Ej: ERP interno, Sistema contable..." />
            </div>

            <div class="int__field">
              <label class="int__label">URL de destino <span class="int__req">*</span></label>
              <input v-model.trim="form.url" class="int__input" placeholder="https://tu-sistema.com/webhook" />
            </div>

            <div class="int__field">
              <label class="int__label">Eventos a escuchar <span class="int__req">*</span></label>
              <div class="int__events-check">
                <label
                  v-for="e in EVENTS_DISPONIBLES"
                  :key="e.key"
                  class="int__check-item"
                  :class="{ 'int__check-item--on': form.events.includes(e.key) }"
                >
                  <input
                    type="checkbox"
                    :value="e.key"
                    v-model="form.events"
                    class="int__check-input"
                  />
                  <span class="int__check-label">
                    <span class="int__check-key">{{ e.key }}</span>
                    <span class="int__check-desc">{{ e.desc }}</span>
                  </span>
                </label>
              </div>
            </div>

            <div class="int__field int__field--row">
              <label class="int__label">Activo</label>
              <button
                type="button"
                class="int__switch"
                :class="{ 'int__switch--on': form.active }"
                @click="form.active = !form.active"
              >
                <div class="int__switch-thumb"></div>
              </button>
            </div>
          </div>

          <div class="int__modal-footer">
            <button class="int__btn-ghost" @click="cerrarForm" :disabled="saving">Cancelar</button>
            <button class="int__btn-primary" @click="guardar" :disabled="saving">
              <DsSpinner v-if="saving" :size="16" />
              <span v-else>{{ editando ? 'Guardar cambios' : 'Crear webhook' }}</span>
            </button>
          </div>
        </div>
      </div>
    </Transition>

    <!-- Drawer log de entregas -->
    <Transition name="drawer-slide">
      <div v-if="showLog" class="int__overlay" @click.self="showLog = false">
        <div class="int__drawer">
          <div class="int__drawer-header">
            <h2 class="int__modal-title">Entregas — {{ logWebhook?.nombre }}</h2>
            <button class="int__modal-close" @click="showLog = false">
              <X :size="18" :stroke-width="1.75" />
            </button>
          </div>
          <div class="int__drawer-body">
            <div v-if="loadingLog" class="int__loading"><DsSpinner :size="24" /></div>
            <div v-else-if="!deliveries.length" class="int__empty-log">Sin entregas registradas</div>
            <div v-else class="int__log-list">
              <div
                v-for="d in deliveries"
                :key="d.id"
                class="int__log-row"
                :class="`int__log-row--${d.status}`"
              >
                <div class="int__log-status">
                  <CheckCircle2 v-if="d.status === 'success'" :size="14" :stroke-width="2" />
                  <XCircle      v-else-if="d.status === 'failed'" :size="14" :stroke-width="2" />
                  <Clock        v-else :size="14" :stroke-width="2" />
                </div>
                <div class="int__log-info">
                  <div class="int__log-event">{{ d.event }}</div>
                  <div class="int__log-meta">
                    {{ d.http_code ? `HTTP ${d.http_code}` : '—' }}
                    <span v-if="d.duration_ms">· {{ d.duration_ms }}ms</span>
                    · {{ timeAgo(d.created_at) }}
                    <span v-if="d.attempts > 1"> · {{ d.attempts }} intentos</span>
                  </div>
                  <div v-if="d.error_message" class="int__log-error">{{ d.error_message }}</div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Transition>

  </div>
</template>

<script setup>
import { ref, reactive, onMounted } from 'vue'
import { Plus, Pencil, Trash2, X, Activity, CheckCircle2, XCircle, Clock } from 'lucide-vue-next'
import DsSpinner from '../design-system/components/Spinner.vue'
import api from '../lib/api.js'

const EVENTS_DISPONIBLES = [
  { key: 'dispensacion.creada',  desc: 'Cada vez que se registra una dispensación' },
  { key: 'paciente.creado',      desc: 'Cuando se da de alta un nuevo paciente' },
  { key: 'lote.avanzado',        desc: 'Cuando un lote cambia de estado' },
  { key: 'cosecha.completada',   desc: 'Cuando un lote llega a finalizado' },
]

const webhooks    = ref([])
const loading     = ref(true)
const saving      = ref(false)
const showForm    = ref(false)
const showLog     = ref(false)
const loadingLog  = ref(false)
const editando    = ref(null)
const logWebhook  = ref(null)
const deliveries  = ref([])
const formError   = ref(null)
const showSecret  = reactive({})

const form = reactive({ nombre: '', url: '', events: [], active: true })

async function cargar() {
  loading.value = true
  try {
    const { data } = await api.get('/webhooks')
    webhooks.value = data
  } finally {
    loading.value = false
  }
}

function abrirFormNuevo() {
  editando.value = null
  Object.assign(form, { nombre: '', url: '', events: [], active: true })
  formError.value = null
  showForm.value  = true
}

function abrirFormEditar(wh) {
  editando.value = wh.id
  Object.assign(form, { nombre: wh.nombre, url: wh.url, events: [...wh.events], active: wh.active })
  formError.value = null
  showForm.value  = true
}

function cerrarForm() { showForm.value = false }

async function guardar() {
  if (!form.nombre.trim() || !form.url.trim() || !form.events.length) {
    formError.value = 'Completá nombre, URL y al menos un evento.'
    return
  }
  saving.value   = true
  formError.value = null
  try {
    if (editando.value) {
      const { data } = await api.patch(`/webhooks/${editando.value}`, { webhook: { ...form } })
      const idx = webhooks.value.findIndex(w => w.id === editando.value)
      if (idx >= 0) webhooks.value[idx] = data
    } else {
      const { data } = await api.post('/webhooks', { webhook: { ...form } })
      webhooks.value.unshift(data)
    }
    cerrarForm()
  } catch (e) {
    formError.value = e.response?.data?.errors?.join(', ') || 'Error al guardar. Verificá la URL.'
  } finally {
    saving.value = false
  }
}

async function confirmarEliminar(wh) {
  if (!confirm(`¿Eliminar el webhook "${wh.nombre}"? Se perderá el historial de entregas.`)) return
  await api.delete(`/webhooks/${wh.id}`)
  webhooks.value = webhooks.value.filter(w => w.id !== wh.id)
}

async function verLog(wh) {
  logWebhook.value = wh
  showLog.value    = true
  loadingLog.value = true
  deliveries.value = []
  try {
    const { data } = await api.get(`/webhooks/${wh.id}`)
    deliveries.value = data.deliveries || []
  } finally {
    loadingLog.value = false
  }
}

function timeAgo(ts) {
  if (!ts) return ''
  const diff = Math.floor((Date.now() - new Date(ts)) / 1000)
  if (diff < 60)    return 'hace un momento'
  if (diff < 3600)  return `hace ${Math.floor(diff / 60)}min`
  if (diff < 86400) return `hace ${Math.floor(diff / 3600)}h`
  return `hace ${Math.floor(diff / 86400)}d`
}

onMounted(cargar)
</script>

<style scoped>
.int {
  max-width: 860px;
  margin: 0 auto;
  padding: var(--sp-8) var(--sp-6);
  display: flex;
  flex-direction: column;
  gap: var(--sp-6);
}

.int__header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: var(--sp-4);
}
.int__title {
  font-size: var(--fs-22);
  font-weight: 700;
  color: var(--c-ink-900);
  letter-spacing: -.02em;
  margin: 0 0 var(--sp-1);
}
.int__sub { font-size: var(--fs-13); color: var(--c-ink-500); margin: 0; }

.int__btn-nuevo {
  display: flex; align-items: center; gap: var(--sp-2);
  background: var(--c-leaf-700); color: #fff;
  border: none; border-radius: var(--r-md);
  padding: var(--sp-2) var(--sp-4);
  font-size: var(--fs-13); font-weight: 600;
  cursor: pointer; white-space: nowrap;
  transition: background var(--t-fast);
  flex-shrink: 0;
}
.int__btn-nuevo:hover { background: var(--c-leaf-800); }

/* Eventos info */
.int__eventos-info {
  display: flex; align-items: center; gap: var(--sp-2); flex-wrap: wrap;
  padding: var(--sp-3) var(--sp-4);
  background: var(--c-ink-50);
  border: 1px solid var(--c-ink-200);
  border-radius: var(--r-md);
  font-size: var(--fs-12);
}
.int__eventos-label { color: var(--c-ink-500); font-weight: 600; }
.int__evento-chip {
  background: var(--c-ink-100); color: var(--c-ink-700);
  padding: 2px 8px; border-radius: var(--r-pill); font-family: monospace; font-size: 11px;
}

/* Loading / empty */
.int__loading { display: flex; justify-content: center; padding: var(--sp-10); }
.int__empty { text-align: center; padding: var(--sp-12) var(--sp-6); }
.int__empty-ico   { font-size: 2.5rem; margin-bottom: var(--sp-3); }
.int__empty-titulo { font-size: var(--fs-16); font-weight: 600; color: var(--c-ink-700); margin-bottom: var(--sp-1); }
.int__empty-sub { font-size: var(--fs-13); color: var(--c-ink-400); }

/* Card */
.int__list { display: flex; flex-direction: column; gap: var(--sp-3); }
.int__card {
  background: var(--c-paper);
  border: 1px solid var(--c-ink-200);
  border-radius: var(--r-lg);
  padding: var(--sp-4) var(--sp-5);
  display: flex; flex-direction: column; gap: var(--sp-3);
  transition: border-color var(--t-fast);
}
.int__card:hover { border-color: var(--c-ink-300); }
.int__card--inactive { opacity: .65; }

.int__card-header { display: flex; align-items: flex-start; justify-content: space-between; gap: var(--sp-3); }
.int__card-left   { display: flex; align-items: flex-start; gap: var(--sp-3); }
.int__card-dot {
  width: 8px; height: 8px; border-radius: 50%; margin-top: 5px; flex-shrink: 0;
}
.int__card-dot--on  { background: var(--c-leaf-500); box-shadow: 0 0 0 3px rgba(22,163,74,.15); }
.int__card-dot--off { background: var(--c-ink-300); }

.int__card-nombre { font-size: var(--fs-14); font-weight: 600; color: var(--c-ink-900); }
.int__card-url    { font-size: var(--fs-12); color: var(--c-ink-500); font-family: monospace; margin-top: 2px; word-break: break-all; }

.int__card-actions { display: flex; gap: var(--sp-1); flex-shrink: 0; }
.int__btn-icon {
  width: 30px; height: 30px;
  display: flex; align-items: center; justify-content: center;
  border: 1px solid var(--c-ink-200); border-radius: var(--r-md);
  background: transparent; color: var(--c-ink-500);
  cursor: pointer; transition: all var(--t-fast);
}
.int__btn-icon:hover { background: var(--c-ink-100); color: var(--c-ink-900); }
.int__btn-icon--danger:hover { background: var(--c-rust-50); border-color: var(--c-rust-200); color: var(--c-rust-600); }

.int__card-events { display: flex; gap: var(--sp-2); flex-wrap: wrap; }
.int__ev-badge {
  font-size: 11px; font-family: monospace;
  background: var(--c-leaf-50); color: var(--c-leaf-700);
  border: 1px solid var(--c-leaf-200);
  padding: 2px 8px; border-radius: var(--r-pill);
}

.int__card-meta {
  font-size: var(--fs-12); color: var(--c-ink-400);
  display: flex; gap: var(--sp-2); align-items: center;
}
.int__card-meta-sep { opacity: .4; }
.int__card-meta--dim { color: var(--c-ink-300); }

.int__secret-row {
  display: flex; align-items: center; gap: var(--sp-2);
  padding: var(--sp-2) var(--sp-3);
  background: var(--c-ink-50); border-radius: var(--r-sm);
}
.int__secret-label { font-size: var(--fs-11); color: var(--c-ink-500); font-weight: 600; }
.int__secret-val {
  flex: 1; font-size: 11px; font-family: monospace;
  color: var(--c-ink-700); overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
}
.int__secret-val--hidden { letter-spacing: .1em; }
.int__secret-toggle {
  font-size: var(--fs-11); color: var(--c-leaf-600); background: none; border: none; cursor: pointer;
  white-space: nowrap; flex-shrink: 0;
}

/* Modal / overlay */
.int__overlay {
  position: fixed; inset: 0; z-index: 500;
  background: rgba(0,0,0,.45);
  display: flex; align-items: center; justify-content: center;
  padding: var(--sp-4);
}
.int__modal {
  background: var(--c-paper);
  border-radius: var(--r-xl);
  width: 100%; max-width: 520px;
  box-shadow: 0 24px 60px rgba(0,0,0,.2);
  display: flex; flex-direction: column;
  max-height: 90vh; overflow: hidden;
}
.int__modal-header {
  display: flex; align-items: center; justify-content: space-between;
  padding: var(--sp-5) var(--sp-6) var(--sp-4);
  border-bottom: 1px solid var(--c-ink-100);
  flex-shrink: 0;
}
.int__modal-title { font-size: var(--fs-16); font-weight: 700; color: var(--c-ink-900); margin: 0; }
.int__modal-close {
  width: 32px; height: 32px; display: flex; align-items: center; justify-content: center;
  border: none; background: none; color: var(--c-ink-400); cursor: pointer; border-radius: var(--r-md);
}
.int__modal-close:hover { background: var(--c-ink-100); color: var(--c-ink-700); }

.int__modal-body { padding: var(--sp-5) var(--sp-6); overflow-y: auto; display: flex; flex-direction: column; gap: var(--sp-4); }
.int__modal-footer {
  display: flex; justify-content: flex-end; gap: var(--sp-3);
  padding: var(--sp-4) var(--sp-6);
  border-top: 1px solid var(--c-ink-100);
  flex-shrink: 0;
}

/* Form fields */
.int__field { display: flex; flex-direction: column; gap: var(--sp-2); }
.int__field--row { flex-direction: row; align-items: center; justify-content: space-between; }
.int__label { font-size: var(--fs-12); font-weight: 600; color: var(--c-ink-600); }
.int__req { color: var(--c-rust-500); }
.int__input {
  background: var(--c-ink-50); border: 1.5px solid var(--c-ink-200);
  border-radius: var(--r-md); padding: var(--sp-2) var(--sp-3);
  font-size: var(--fs-13); color: var(--c-ink-900); outline: none; width: 100%; box-sizing: border-box;
}
.int__input:focus { border-color: var(--c-leaf-500); background: var(--c-paper); }

.int__events-check { display: flex; flex-direction: column; gap: var(--sp-2); }
.int__check-item {
  display: flex; align-items: flex-start; gap: var(--sp-3);
  padding: var(--sp-2) var(--sp-3);
  border: 1.5px solid var(--c-ink-200); border-radius: var(--r-md);
  cursor: pointer; transition: all var(--t-fast);
}
.int__check-item:hover { background: var(--c-ink-50); }
.int__check-item--on { background: var(--c-leaf-50); border-color: var(--c-leaf-300); }
.int__check-input { margin-top: 2px; flex-shrink: 0; accent-color: var(--c-leaf-600); }
.int__check-key { display: block; font-size: var(--fs-12); font-family: monospace; font-weight: 700; color: var(--c-ink-800); }
.int__check-desc { display: block; font-size: var(--fs-11); color: var(--c-ink-500); margin-top: 1px; }

/* Switch */
.int__switch {
  width: 44px; height: 24px; border-radius: 12px;
  background: var(--c-ink-200); border: none; cursor: pointer;
  position: relative; transition: background .2s; flex-shrink: 0;
}
.int__switch--on { background: var(--c-leaf-500); }
.int__switch-thumb {
  position: absolute; top: 3px; left: 3px;
  width: 18px; height: 18px; border-radius: 50%; background: #fff;
  transition: transform .2s; box-shadow: 0 1px 3px rgba(0,0,0,.2);
}
.int__switch--on .int__switch-thumb { transform: translateX(20px); }

/* Botones modal */
.int__btn-ghost {
  padding: var(--sp-2) var(--sp-4); border-radius: var(--r-md);
  background: transparent; border: 1px solid var(--c-ink-200);
  color: var(--c-ink-600); font-size: var(--fs-13); font-weight: 500; cursor: pointer;
}
.int__btn-ghost:hover { background: var(--c-ink-50); }
.int__btn-primary {
  display: flex; align-items: center; gap: var(--sp-2);
  padding: var(--sp-2) var(--sp-5); border-radius: var(--r-md);
  background: var(--c-leaf-700); color: #fff; border: none;
  font-size: var(--fs-13); font-weight: 600; cursor: pointer;
}
.int__btn-primary:hover { background: var(--c-leaf-800); }
.int__btn-primary:disabled, .int__btn-ghost:disabled { opacity: .6; cursor: not-allowed; }

/* Alert */
.int__alert {
  background: var(--c-rust-50); border: 1px solid var(--c-rust-200);
  color: var(--c-rust-700); border-radius: var(--r-md);
  padding: var(--sp-2) var(--sp-3); font-size: var(--fs-12);
}

/* Drawer log */
.int__drawer {
  position: fixed; right: 0; top: 0; bottom: 0;
  width: 480px; max-width: 95vw;
  background: var(--c-paper);
  box-shadow: -4px 0 24px rgba(0,0,0,.12);
  display: flex; flex-direction: column;
}
.int__drawer-header {
  display: flex; align-items: center; justify-content: space-between;
  padding: var(--sp-5) var(--sp-6);
  border-bottom: 1px solid var(--c-ink-100);
  flex-shrink: 0;
}
.int__drawer-body { flex: 1; overflow-y: auto; padding: var(--sp-4) var(--sp-5); }
.int__empty-log { text-align: center; color: var(--c-ink-400); font-size: var(--fs-13); padding: var(--sp-8); }

.int__log-list { display: flex; flex-direction: column; gap: var(--sp-2); }
.int__log-row {
  display: flex; gap: var(--sp-3); align-items: flex-start;
  padding: var(--sp-3); border-radius: var(--r-md);
  border: 1px solid var(--c-ink-100);
}
.int__log-row--success .int__log-status { color: var(--c-leaf-500); }
.int__log-row--failed  .int__log-status { color: var(--c-rust-500); }
.int__log-row--pending .int__log-status { color: var(--c-ink-400); }
.int__log-status { flex-shrink: 0; margin-top: 1px; }
.int__log-event { font-size: var(--fs-13); font-weight: 600; font-family: monospace; color: var(--c-ink-800); }
.int__log-meta  { font-size: var(--fs-11); color: var(--c-ink-400); margin-top: 2px; }
.int__log-error { font-size: var(--fs-11); color: var(--c-rust-600); margin-top: 4px; word-break: break-all; }

/* Transiciones */
.modal-fade-enter-active, .modal-fade-leave-active { transition: opacity .2s ease; }
.modal-fade-enter-from, .modal-fade-leave-to { opacity: 0; }
.drawer-slide-enter-active, .drawer-slide-leave-active { transition: opacity .2s ease; }
.drawer-slide-enter-from, .drawer-slide-leave-to { opacity: 0; }
</style>
