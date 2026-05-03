<template>
  <div class="pv">

    <div class="pv__header">
      <div class="pv__eyebrow">
        <Scissors :size="14" :stroke-width="2" />
        Manicura
      </div>
      <h1 class="pv__title">Cosechas pendientes</h1>
      <p class="pv__sub">Cosechas en secado listas para manicurar. Registrá el peso y las plantas procesadas para enviar a aprobación.</p>
    </div>

    <div v-if="loading" class="pv__loading">
      <div class="pv__ring"></div>
      <span>Cargando cosechas…</span>
    </div>

    <div v-else-if="!lotes.length" class="pv__empty">
      <div class="pv__empty-ico"><Wind :size="40" :stroke-width="1.25" /></div>
      <p class="pv__empty-title">Sin cosechas pendientes</p>
      <p class="pv__empty-sub">Cuando una cosecha complete el secado aparecerá aquí para manicurar.</p>
    </div>

    <div v-else class="pv__cards">
      <div v-for="lote in lotes" :key="lote.id" class="pv__card">
        <div class="pv__card-stripe"></div>
        <div class="pv__card-body">
          <div class="pv__card-head">
            <span class="pv__card-codigo">{{ lote.codigo }}</span>
            <span class="pv__badge pv__badge--secado">Secado</span>
          </div>
          <div class="pv__card-meta">
            <span v-if="lote.genetica"><Leaf :size="13" :stroke-width="2" /> {{ lote.genetica.nombre }}</span>
            <span><MapPin :size="13" :stroke-width="2" /> {{ lote.sala?.nombre }}</span>
            <span><Package :size="13" :stroke-width="2" /> {{ lote.plants_count }} plantas</span>
          </div>
        </div>
        <div class="pv__card-actions">
          <button class="pv__btn-accent" @click="abrirModal(lote)">
            <Scale :size="14" :stroke-width="2" /> Registrar manicura
          </button>
        </div>
      </div>
    </div>

    <!-- Modal de manicura -->
    <Teleport to="body">
      <Transition name="pv-fade">
        <div v-if="modalOpen" class="pv-overlay" @click.self="cerrarModal">
          <div class="pv-modal" role="dialog" aria-modal="true">

            <div class="pv-modal__header">
              <div class="pv-modal__ico">
                <Scissors :size="20" :stroke-width="1.75" />
              </div>
              <div>
                <h2 class="pv-modal__title">Registrar manicura</h2>
                <p class="pv-modal__sub">
                  Cosecha <strong>{{ loteSeleccionado?.codigo }}</strong>
                  <span v-if="loteSeleccionado?.genetica"> · {{ loteSeleccionado.genetica.nombre }}</span>
                  <span class="pv-modal__tag">→ Aprobación admin</span>
                </p>
              </div>
              <button class="pv-modal__close" @click="cerrarModal" aria-label="Cerrar">
                <X :size="18" :stroke-width="2" />
              </button>
            </div>

            <form class="pv-modal__body" @submit.prevent="submit">

              <!-- Plantas manicuradas -->
              <div class="pv-field">
                <label class="pv-label">
                  Plantas manicuradas <span class="pv-req">*</span>
                </label>
                <div class="pv-input-group">
                  <input
                    v-model.number="form.plantas_manicuradas"
                    type="number"
                    step="1"
                    min="1"
                    :max="loteSeleccionado?.plants_count"
                    class="pv-input"
                    placeholder="0"
                    required
                    autofocus
                  />
                  <span class="pv-input-suffix">de {{ loteSeleccionado?.plants_count }}</span>
                </div>
                <span class="pv-hint">Cantidad de plantas procesadas en esta sesión de manicura</span>
              </div>

              <!-- Peso seco post-manicura -->
              <div class="pv-field">
                <label class="pv-label">
                  Peso neto post-manicura (g) <span class="pv-req">*</span>
                </label>
                <div class="pv-input-group">
                  <input
                    v-model.number="form.peso_seco_g"
                    type="number"
                    step="0.1"
                    min="0.1"
                    class="pv-input"
                    placeholder="0.0"
                    required
                  />
                  <span class="pv-input-suffix">g</span>
                </div>
                <span class="pv-hint">Peso del producto listo después de manicura, sin tallos ni hojas</span>
              </div>

              <!-- Notas -->
              <div class="pv-field">
                <label class="pv-label">Notas <span class="pv-opt">opcional</span></label>
                <textarea
                  v-model="form.notas"
                  class="pv-textarea"
                  rows="2"
                  placeholder="Observaciones del proceso, calidad del material, incidencias…"
                ></textarea>
              </div>

              <div v-if="modalError" class="pv-error">
                <AlertCircle :size="15" :stroke-width="2" />
                {{ modalError }}
              </div>

              <p class="pv-info">
                <CheckCircle :size="14" :stroke-width="2" />
                La cosecha pasará a <strong>Pendiente de aprobación</strong>. El admin revisará los datos y creará el stock.
              </p>

              <div class="pv-actions">
                <button type="button" class="pv-btn-cancel" @click="cerrarModal">Cancelar</button>
                <button type="submit" class="pv-btn-submit" :disabled="saving || !form.plantas_manicuradas || !form.peso_seco_g">
                  <div v-if="saving" class="pv-spinner"></div>
                  <Scale v-else :size="15" :stroke-width="2" />
                  Enviar a aprobación
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
import { Scissors, Wind, Leaf, MapPin, Package, Scale, X, AlertCircle, CheckCircle } from 'lucide-vue-next'
import { listLotes, transicionarLote } from '../../lib/api.js'
import { useToast } from '../../composables/useToast.js'

const toast = useToast()
const lotes = ref([])
const loading = ref(true)
const modalOpen = ref(false)
const loteSeleccionado = ref(null)
const form = ref({ plantas_manicuradas: null, peso_seco_g: null, notas: '' })
const saving = ref(false)
const modalError = ref('')

async function cargar() {
  loading.value = true
  try {
    const { data } = await listLotes({ estado: 'secado' })
    lotes.value = data
  } catch {
    lotes.value = []
  } finally {
    loading.value = false
  }
}

function abrirModal(lote) {
  loteSeleccionado.value = lote
  form.value = { plantas_manicuradas: lote.plants_count || null, peso_seco_g: null, notas: '' }
  modalError.value = ''
  modalOpen.value = true
}

function cerrarModal() {
  modalOpen.value = false
  loteSeleccionado.value = null
}

async function submit() {
  if (!loteSeleccionado.value?.id) return
  if (!form.value.plantas_manicuradas || form.value.plantas_manicuradas < 1) {
    modalError.value = 'Ingresá la cantidad de plantas manicuradas'
    return
  }
  if (!form.value.peso_seco_g || form.value.peso_seco_g <= 0) {
    modalError.value = 'Ingresá el peso neto post-manicura'
    return
  }
  saving.value = true
  modalError.value = ''
  try {
    await transicionarLote(loteSeleccionado.value.id, {
      pesada: {
        manicurado:           true,
        peso_seco_g:          form.value.peso_seco_g,
        plantas_manicuradas:  form.value.plantas_manicuradas,
        notas:                form.value.notas || undefined,
      },
    })
    toast.success(`Cosecha ${loteSeleccionado.value.codigo} enviada a aprobación`)
    cerrarModal()
    cargar()
  } catch (e) {
    modalError.value = e.response?.data?.errors?.[0] || e.response?.data?.error || 'Error al registrar manicura'
  } finally {
    saving.value = false
  }
}

onMounted(cargar)
</script>

<style scoped>
.pv { padding: 2rem 1.75rem 3rem; max-width: 1000px; margin: 0 auto; }
@media (max-width: 768px) { .pv { padding: 1.25rem 1rem 2rem; } }

.pv__header { margin-bottom: 2rem; }
.pv__eyebrow {
  display: inline-flex; align-items: center; gap: .4rem;
  font-size: .7rem; font-weight: 700; text-transform: uppercase; letter-spacing: .07em;
  color: var(--c-role-manicura, #5C7A4A); margin-bottom: .5rem;
}
.pv__title { font-size: 1.6rem; font-weight: 800; color: var(--c-ink); letter-spacing: -.04em; margin: 0 0 .3rem; }
.pv__sub { font-size: .875rem; color: var(--c-muted); margin: 0; }

.pv__loading { display: flex; align-items: center; gap: .75rem; padding: 4rem 0; justify-content: center; color: var(--c-muted); }
.pv__ring { width: 20px; height: 20px; border: 2px solid #e2e8f0; border-top-color: var(--c-role-manicura, #5C7A4A); border-radius: 50%; animation: pv-spin .7s linear infinite; }
@keyframes pv-spin { to { transform: rotate(360deg); } }

.pv__empty { text-align: center; padding: 4rem 2rem; }
.pv__empty-ico { display: flex; justify-content: center; color: #cbd5e1; margin-bottom: 1rem; }
.pv__empty-title { font-size: 1rem; font-weight: 700; color: var(--c-ink); margin: 0 0 .4rem; }
.pv__empty-sub { font-size: .875rem; color: var(--c-muted); margin: 0; }

.pv__cards { display: grid; grid-template-columns: repeat(auto-fill, minmax(300px, 1fr)); gap: 1rem; }
.pv__card {
  background: #fff;
  border: 1px solid #e2e8f0;
  border-radius: 14px;
  display: flex;
  flex-direction: column;
  overflow: hidden;
  transition: box-shadow .15s;
}
.pv__card:hover { box-shadow: 0 4px 20px rgba(0,0,0,.07); }
.pv__card-stripe { height: 4px; background: var(--c-role-manicura, #5C7A4A); }
.pv__card-body { padding: 1rem 1.1rem; flex: 1; }
.pv__card-head { display: flex; align-items: center; justify-content: space-between; margin-bottom: .5rem; }
.pv__card-codigo { font-size: .9rem; font-weight: 800; color: #0f172a; font-family: monospace; letter-spacing: -.02em; }
.pv__badge { font-size: .65rem; font-weight: 700; padding: .2em .65em; border-radius: 999px; text-transform: uppercase; letter-spacing: .05em; }
.pv__badge--secado { background: #fffbeb; color: #b45309; }
.pv__card-meta { display: flex; flex-wrap: wrap; gap: .4rem .75rem; font-size: .76rem; color: #64748b; }
.pv__card-meta span { display: flex; align-items: center; gap: .3rem; }
.pv__card-actions { display: flex; gap: .5rem; padding: .75rem 1.1rem; border-top: 1px solid #f1f5f9; flex-wrap: wrap; }

.pv__btn-accent {
  flex: 1;
  display: inline-flex; align-items: center; justify-content: center; gap: .4rem;
  background: var(--c-role-manicura, #5C7A4A); color: #fff;
  border: none; padding: .55rem .9rem; border-radius: 8px;
  font-size: .8rem; font-weight: 600; cursor: pointer; transition: opacity .15s;
}
.pv__btn-accent:hover { opacity: .9; }

/* Modal */
.pv-overlay {
  position: fixed; inset: 0;
  background: rgba(0,0,0,.45);
  display: flex; align-items: center; justify-content: center;
  z-index: 1050; padding: 1rem;
  backdrop-filter: blur(3px);
}
.pv-modal {
  background: #fff; border-radius: 18px;
  width: 100%; max-width: 460px;
  max-height: 92vh; overflow-y: auto;
  box-shadow: 0 24px 64px rgba(0,0,0,.18);
}
.pv-modal__header {
  display: flex; align-items: flex-start; gap: .875rem;
  padding: 1.25rem 1.5rem 1rem;
  border-bottom: 1px solid #f1f5f9;
}
.pv-modal__ico {
  width: 40px; height: 40px; border-radius: 12px;
  background: rgba(92,122,74,.12); color: var(--c-role-manicura, #5C7A4A);
  display: flex; align-items: center; justify-content: center;
  flex-shrink: 0;
}
.pv-modal__title { font-size: 1rem; font-weight: 800; color: #0f172a; margin: 0 0 .2rem; }
.pv-modal__sub { font-size: .78rem; color: #64748b; margin: 0; }
.pv-modal__tag {
  display: inline-block; margin-left: .35rem;
  font-size: .68rem; font-weight: 700;
  background: #f0fdf4; color: #15803d;
  padding: .1em .5em; border-radius: 5px;
}
.pv-modal__close {
  margin-left: auto; background: #f1f5f9; border: none;
  width: 28px; height: 28px; border-radius: 7px;
  cursor: pointer; display: flex; align-items: center; justify-content: center;
  color: #64748b; flex-shrink: 0;
}
.pv-modal__close:hover { background: #e2e8f0; }

.pv-modal__body { padding: 1.25rem 1.5rem; display: flex; flex-direction: column; gap: 1rem; }

.pv-field { display: flex; flex-direction: column; gap: .3rem; }
.pv-label { font-size: .72rem; font-weight: 700; color: #374151; text-transform: uppercase; letter-spacing: .05em; }
.pv-req { color: #ef4444; }
.pv-opt { font-size: .67rem; font-weight: 400; color: #94a3b8; text-transform: none; letter-spacing: 0; }
.pv-hint { font-size: .7rem; color: #94a3b8; }

.pv-input-group { display: flex; }
.pv-input {
  flex: 1;
  background: #f8fafc; border: 1.5px solid #e2e8f0;
  border-radius: 9px 0 0 9px; padding: .65rem .875rem;
  font-size: .9rem; color: #0f172a;
  outline: none; transition: border-color .15s;
}
.pv-input:focus { border-color: var(--c-role-manicura, #5C7A4A); background: #fff; }
.pv-input-suffix {
  background: #f1f5f9; border: 1.5px solid #e2e8f0; border-left: none;
  padding: .65rem .75rem; font-size: .82rem; font-weight: 700;
  color: #64748b; border-radius: 0 9px 9px 0; white-space: nowrap;
}

.pv-textarea {
  background: #f8fafc; border: 1.5px solid #e2e8f0;
  border-radius: 9px; padding: .65rem .875rem;
  font-size: .875rem; color: #0f172a;
  outline: none; resize: vertical; min-height: 60px;
  transition: border-color .15s; font-family: inherit;
}
.pv-textarea:focus { border-color: var(--c-role-manicura, #5C7A4A); background: #fff; }

.pv-error {
  display: flex; align-items: center; gap: .45rem;
  background: #fef2f2; border: 1px solid #fecaca;
  color: #dc2626; padding: .65rem .875rem;
  border-radius: 9px; font-size: .82rem;
}
.pv-info {
  display: flex; align-items: flex-start; gap: .5rem;
  font-size: .78rem; color: #475569;
  background: #f0fdf4; border: 1px solid #bbf7d0;
  padding: .75rem .875rem; border-radius: 9px; margin: 0;
}

.pv-actions { display: flex; justify-content: flex-end; gap: .6rem; padding-top: .25rem; }
.pv-btn-cancel {
  background: #fff; color: #64748b; border: 1.5px solid #e2e8f0;
  padding: .6rem 1.1rem; border-radius: 9px;
  font-size: .875rem; font-weight: 500; cursor: pointer;
}
.pv-btn-cancel:hover { background: #f8fafc; }
.pv-btn-submit {
  display: inline-flex; align-items: center; gap: .45rem;
  background: var(--c-role-manicura, #5C7A4A); color: #fff;
  border: none; padding: .65rem 1.25rem; border-radius: 9px;
  font-size: .875rem; font-weight: 700; cursor: pointer; transition: opacity .15s;
}
.pv-btn-submit:hover:not(:disabled) { opacity: .9; }
.pv-btn-submit:disabled { opacity: .5; cursor: not-allowed; }
.pv-spinner {
  width: 14px; height: 14px;
  border: 2px solid rgba(255,255,255,.3); border-top-color: #fff;
  border-radius: 50%; animation: pv-spin .6s linear infinite;
}

.pv-fade-enter-active, .pv-fade-leave-active { transition: opacity .2s; }
.pv-fade-enter-from, .pv-fade-leave-to { opacity: 0; }
</style>
