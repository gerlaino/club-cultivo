<template>
  <div class="av">

    <div class="av__header">
      <div class="av__eyebrow">
        <ClipboardCheck :size="14" :stroke-width="2" />
        Administración
      </div>
      <h1 class="av__title">Aprobaciones de manicura</h1>
      <p class="av__sub">Lotes procesados por manicura que esperan tu revisión antes de pasar a curado.</p>
    </div>

    <div v-if="loading" class="av__loading">
      <div class="av__ring"></div>
      <span>Cargando lotes…</span>
    </div>

    <div v-else-if="!lotes.length" class="av__empty">
      <div class="av__empty-ico"><ClipboardCheck :size="40" :stroke-width="1.25" /></div>
      <p class="av__empty-title">Sin aprobaciones pendientes</p>
      <p class="av__empty-sub">Cuando manicura complete un lote aparecerá aquí para tu revisión.</p>
    </div>

    <div v-else class="av__cards">
      <div v-for="lote in lotes" :key="lote.id" class="av__card">
        <div class="av__card-stripe"></div>
        <div class="av__card-body">
          <div class="av__card-head">
            <span class="av__card-codigo">{{ lote.codigo }}</span>
            <span class="av__badge">
              <Clock :size="11" :stroke-width="2.5" />
              Pendiente aprobación
            </span>
          </div>
          <div class="av__card-meta">
            <span v-if="lote.genetica"><Leaf :size="13" :stroke-width="2" /> {{ lote.genetica.nombre }}</span>
            <span><MapPin :size="13" :stroke-width="2" /> {{ lote.sala?.nombre }}</span>
            <span><Package :size="13" :stroke-width="2" /> {{ lote.plants_count }} plantas</span>
          </div>
          <!-- Última pesada de manicura -->
          <div v-if="lote.ultima_pesada_manicura" class="av__pesada">
            <Scale :size="13" :stroke-width="2" />
            <strong>{{ lote.ultima_pesada_manicura.peso_seco_g }}g</strong>
            <span v-if="lote.ultima_pesada_manicura.plantas_manicuradas">
              · {{ lote.ultima_pesada_manicura.plantas_manicuradas }} plantas
            </span>
            <span v-if="lote.ultima_pesada_manicura.registrado_por">
              · {{ lote.ultima_pesada_manicura.registrado_por }}
            </span>
            · {{ fmtDate(lote.ultima_pesada_manicura.registrado_at) }}
          </div>
        </div>
        <div class="av__card-actions">
          <RouterLink :to="`/lotes/${lote.id}`" class="av__btn-secondary">
            <Eye :size="14" :stroke-width="2" /> Ver lote
          </RouterLink>
          <button class="av__btn-danger" @click="abrirRechazo(lote)">
            <XCircle :size="14" :stroke-width="2" /> Rechazar
          </button>
          <button class="av__btn-success" :disabled="aprobando === lote.id" @click="aprobar(lote)">
            <div v-if="aprobando === lote.id" class="av__spinner"></div>
            <CheckCircle v-else :size="14" :stroke-width="2" />
            Aprobar
          </button>
        </div>
      </div>
    </div>

    <!-- Modal rechazo -->
    <Teleport to="body">
      <Transition name="av-fade">
        <div v-if="modalRechazo" class="av-overlay" @click.self="cerrarRechazo">
          <div class="av-modal" role="dialog" aria-modal="true">

            <div class="av-modal__header">
              <div class="av-modal__ico">
                <XCircle :size="20" :stroke-width="1.75" />
              </div>
              <div>
                <h2 class="av-modal__title">Rechazar manicura</h2>
                <p class="av-modal__sub">Lote <strong>{{ loteRechazo?.codigo }}</strong></p>
              </div>
              <button class="av-modal__close" @click="cerrarRechazo" aria-label="Cerrar">
                <X :size="18" :stroke-width="2" />
              </button>
            </div>

            <form class="av-modal__body" @submit.prevent="confirmarRechazo">
              <div class="av-field">
                <label class="av-label">Motivo del rechazo <span class="av-req">*</span></label>
                <textarea
                  v-model="motivoRechazo"
                  class="av-textarea"
                  rows="3"
                  placeholder="Explicá por qué se rechaza la manicura…"
                  required
                  autofocus
                ></textarea>
              </div>

              <div v-if="rechazoError" class="av-error">
                <AlertCircle :size="15" :stroke-width="2" />
                {{ rechazoError }}
              </div>

              <div class="av-actions">
                <button type="button" class="av-btn-cancel" @click="cerrarRechazo">Cancelar</button>
                <button type="submit" class="av-btn-danger-solid" :disabled="rechazando">
                  <div v-if="rechazando" class="av-spinner"></div>
                  <XCircle v-else :size="15" :stroke-width="2" />
                  Confirmar rechazo
                </button>
              </div>
            </form>

          </div>
        </div>
      </Transition>
    </Teleport>

  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { ClipboardCheck, Clock, Leaf, MapPin, Package, Scale, Eye, CheckCircle, XCircle, X, AlertCircle } from 'lucide-vue-next'
import { listLotes, aprobarManicura, rechazarManicura } from '../../lib/api.js'
import { useToast } from '../../composables/useToast.js'

const toast = useToast()
const lotes = ref([])
const loading = ref(true)
const aprobando = ref(null)

const modalRechazo = ref(false)
const loteRechazo = ref(null)
const motivoRechazo = ref('')
const rechazando = ref(false)
const rechazoError = ref('')

function fmtDate(d) {
  if (!d) return '—'
  return new Date(d).toLocaleString('es-AR', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' })
}

async function cargar() {
  loading.value = true
  try {
    const { data } = await listLotes({ estado: 'manicura_pendiente' })
    lotes.value = data
  } catch {
    lotes.value = []
  } finally {
    loading.value = false
  }
}

async function aprobar(lote) {
  aprobando.value = lote.id
  try {
    await aprobarManicura(lote.id)
    toast.success(`Lote ${lote.codigo} aprobado — pasa a curado`)
    cargar()
  } catch (e) {
    toast.error(e.response?.data?.error || 'Error al aprobar')
  } finally {
    aprobando.value = null
  }
}

function abrirRechazo(lote) {
  loteRechazo.value = lote
  motivoRechazo.value = ''
  rechazoError.value = ''
  modalRechazo.value = true
}

function cerrarRechazo() {
  modalRechazo.value = false
  loteRechazo.value = null
}

async function confirmarRechazo() {
  if (!loteRechazo.value || !motivoRechazo.value.trim()) return
  rechazando.value = true
  rechazoError.value = ''
  try {
    await rechazarManicura(loteRechazo.value.id, motivoRechazo.value.trim())
    toast.success(`Lote ${loteRechazo.value.codigo} rechazado — vuelve a secado`)
    cerrarRechazo()
    cargar()
  } catch (e) {
    rechazoError.value = e.response?.data?.error || 'Error al rechazar'
  } finally {
    rechazando.value = false
  }
}

onMounted(cargar)
</script>

<style scoped>
.av { padding: 2rem 1.75rem 3rem; max-width: 1000px; margin: 0 auto; }
@media (max-width: 768px) { .av { padding: 1.25rem 1rem 2rem; } }

.av__header { margin-bottom: 2rem; }
.av__eyebrow {
  display: inline-flex; align-items: center; gap: .4rem;
  font-size: var(--fs-12); font-weight: 700; text-transform: uppercase; letter-spacing: .08em;
  color: var(--c-role-admin); margin-bottom: .4rem;
}
.av__title { font-size: 1.75rem; font-weight: 800; color: var(--c-ink-900); margin: 0 0 .2rem; letter-spacing: -.03em; }
.av__sub { font-size: var(--fs-14); color: var(--c-ink-500); margin: 0; }

.av__loading { display: flex; align-items: center; gap: .75rem; padding: 4rem; justify-content: center; color: var(--c-ink-500); }
.av__ring {
  width: 20px; height: 20px;
  border: 2px solid var(--c-ink-200); border-top-color: var(--c-role-admin);
  border-radius: 50%; animation: av-spin .7s linear infinite;
}
@keyframes av-spin { to { transform: rotate(360deg); } }

.av__empty { text-align: center; padding: 4rem 2rem; }
.av__empty-ico { color: var(--c-ink-300); margin-bottom: 1rem; display: flex; justify-content: center; }
.av__empty-title { font-size: var(--fs-16); font-weight: 700; color: var(--c-ink-700); margin: 0 0 .4rem; }
.av__empty-sub { font-size: var(--fs-14); color: var(--c-ink-500); margin: 0; }

.av__cards { display: flex; flex-direction: column; gap: .75rem; }
.av__card {
  display: flex; align-items: stretch;
  background: var(--c-paper); border: 1px solid var(--c-ink-200);
  border-radius: var(--r-xl); overflow: hidden;
  transition: box-shadow var(--t-fast);
}
.av__card:hover { box-shadow: 0 4px 20px rgba(0,0,0,.07); }

.av__card-stripe { width: 4px; flex-shrink: 0; background: var(--c-amber-500); }

.av__card-body { flex: 1; padding: 1rem 1.25rem; min-width: 0; }
.av__card-head { display: flex; align-items: center; gap: .75rem; margin-bottom: .5rem; }
.av__card-codigo { font-size: var(--fs-16); font-weight: 800; color: var(--c-ink-900); font-family: var(--font-mono); }

.av__badge {
  display: inline-flex; align-items: center; gap: .3rem;
  font-size: 11px; font-weight: 700; padding: 2px 10px;
  border-radius: 999px; text-transform: uppercase; letter-spacing: .04em;
  background: var(--c-amber-100); color: var(--c-amber-500); border: 1px solid #fde68a;
}

.av__card-meta { display: flex; flex-wrap: wrap; gap: .5rem 1.25rem; font-size: var(--fs-13); color: var(--c-ink-500); }
.av__card-meta span { display: inline-flex; align-items: center; gap: .3rem; }

.av__pesada {
  display: inline-flex; align-items: center; gap: .4rem;
  margin-top: .625rem; font-size: var(--fs-13); color: var(--c-ink-600);
  background: var(--c-ink-100); border-radius: var(--r-md); padding: .375rem .75rem;
}

.av__card-actions {
  display: flex; flex-direction: column; gap: .5rem;
  justify-content: center; padding: 1rem 1.25rem;
  border-left: 1px solid var(--c-ink-100); flex-shrink: 0;
}
@media (max-width: 640px) {
  .av__card { flex-direction: column; }
  .av__card-stripe { width: 100%; height: 4px; }
  .av__card-actions { border-left: none; border-top: 1px solid var(--c-ink-100); flex-direction: row; flex-wrap: wrap; }
}

.av__btn-secondary {
  display: inline-flex; align-items: center; gap: .35rem;
  background: transparent; color: var(--c-ink-600);
  border: 1.5px solid var(--c-ink-200); padding: .5rem .875rem;
  border-radius: var(--r-md); font-size: var(--fs-13); font-weight: 500;
  cursor: pointer; white-space: nowrap; transition: all var(--t-fast); text-decoration: none;
}
.av__btn-secondary:hover { background: var(--c-ink-100); border-color: var(--c-ink-300); color: var(--c-ink-900); }
.av__btn-danger {
  display: inline-flex; align-items: center; gap: .35rem;
  background: transparent; color: var(--c-rust-600);
  border: 1.5px solid #fca5a5; padding: .5rem .875rem;
  border-radius: var(--r-md); font-size: var(--fs-13); font-weight: 600;
  cursor: pointer; white-space: nowrap; transition: all var(--t-fast);
}
.av__btn-danger:hover { background: var(--c-rust-100); }
.av__btn-success {
  display: inline-flex; align-items: center; gap: .35rem;
  background: var(--c-leaf-600); color: #fff;
  border: none; padding: .5rem .875rem;
  border-radius: var(--r-md); font-size: var(--fs-13); font-weight: 600;
  cursor: pointer; white-space: nowrap; transition: opacity var(--t-fast);
}
.av__btn-success:hover:not(:disabled) { opacity: .88; }
.av__btn-success:disabled { opacity: .5; cursor: not-allowed; }
.av__spinner {
  width: 13px; height: 13px;
  border: 2px solid rgba(255,255,255,.3); border-top-color: #fff;
  border-radius: 50%; animation: av-spin .6s linear infinite;
}

/* Modal */
.av-overlay {
  position: fixed; inset: 0; background: rgba(0,0,0,.45); z-index: 1050;
  display: flex; align-items: center; justify-content: center;
  padding: var(--sp-4); backdrop-filter: blur(3px);
}
.av-modal {
  background: var(--c-paper); border-radius: var(--r-xl);
  width: 100%; max-width: 440px;
  box-shadow: 0 24px 64px rgba(0,0,0,.18); overflow: hidden;
}
.av-modal__header {
  display: flex; align-items: center; gap: var(--sp-3);
  padding: var(--sp-5) var(--sp-6); border-bottom: 1px solid var(--c-ink-200);
}
.av-modal__ico {
  width: 40px; height: 40px; border-radius: var(--r-lg);
  background: var(--c-rust-100); color: var(--c-rust-600);
  display: flex; align-items: center; justify-content: center; flex-shrink: 0;
}
.av-modal__title { font-size: var(--fs-16); font-weight: 700; color: var(--c-ink-900); margin: 0; }
.av-modal__sub { font-size: var(--fs-13); color: var(--c-ink-500); margin: 2px 0 0; }
.av-modal__close {
  margin-left: auto; background: none; border: none;
  color: var(--c-ink-400); cursor: pointer; padding: var(--sp-1);
  border-radius: var(--r-sm); display: flex; align-items: center;
  transition: color var(--t-fast), background var(--t-fast); flex-shrink: 0;
}
.av-modal__close:hover { color: var(--c-ink-900); background: var(--c-ink-100); }

.av-modal__body { padding: var(--sp-5) var(--sp-6) var(--sp-6); display: flex; flex-direction: column; gap: var(--sp-4); }
.av-field { display: flex; flex-direction: column; gap: var(--sp-1); }
.av-label { font-size: var(--fs-13); font-weight: 600; color: var(--c-ink-700); }
.av-req { color: var(--c-rust-600); }
.av-textarea {
  width: 100%; box-sizing: border-box;
  background: var(--c-ink-100); border: 1.5px solid var(--c-ink-200);
  border-radius: var(--r-md); padding: 9px 12px;
  font-size: var(--fs-14); color: var(--c-ink-900); transition: border-color var(--t-fast);
  font-family: inherit; resize: vertical; min-height: 80px;
}
.av-textarea:focus { outline: none; border-color: var(--c-rust-600); background: var(--c-paper); }
.av-error {
  display: flex; align-items: center; gap: var(--sp-2);
  background: var(--c-rust-100); border: 1px solid #fca5a5;
  border-radius: var(--r-md); padding: var(--sp-3) var(--sp-4);
  font-size: var(--fs-13); color: var(--c-rust-600);
}
.av-actions {
  display: flex; gap: var(--sp-3); justify-content: flex-end;
  padding-top: var(--sp-2); border-top: 1px solid var(--c-ink-100);
}
.av-btn-cancel {
  background: transparent; border: 1.5px solid var(--c-ink-200);
  color: var(--c-ink-600); padding: var(--sp-2) var(--sp-5);
  border-radius: var(--r-md); font-size: var(--fs-14); font-weight: 500;
  cursor: pointer; transition: all var(--t-fast);
}
.av-btn-cancel:hover { background: var(--c-ink-100); border-color: var(--c-ink-300); }
.av-btn-danger-solid {
  display: flex; align-items: center; gap: var(--sp-2);
  background: var(--c-rust-600); color: #fff;
  border: none; padding: var(--sp-2) var(--sp-5);
  border-radius: var(--r-md); font-size: var(--fs-14); font-weight: 600;
  cursor: pointer; transition: opacity var(--t-fast);
}
.av-btn-danger-solid:hover:not(:disabled) { opacity: .88; }
.av-btn-danger-solid:disabled { opacity: .5; cursor: not-allowed; }

.av-fade-enter-active, .av-fade-leave-active { transition: opacity .2s; }
.av-fade-enter-from, .av-fade-leave-to { opacity: 0; }
</style>
