<template>
  <Teleport to="body">
    <div v-if="modelValue" class="cmm__overlay" @mousedown.self="cerrar">
      <div class="cmm__panel">

        <div class="cmm__header">
          <div class="cmm__header-left">
            <div class="cmm__icon-wrap"><CheckCheck :size="18" :stroke-width="2" /></div>
            <div>
              <div class="cmm__title">Completar Manicura</div>
              <div class="cmm__sub">Lote {{ lote?.codigo }}</div>
            </div>
          </div>
          <button class="cmm__close" @click="cerrar"><X :size="16" /></button>
        </div>

        <div class="cmm__body">
          <div v-if="error" class="cmm__alert">{{ error }}</div>

          <!-- Peso seco -->
          <div class="cmm__field">
            <label class="cmm__label">
              Peso seco (g)
              <span class="cmm__required">requerido</span>
            </label>
            <div class="cmm__input-row">
              <input
                type="number" step="0.1" min="0.1"
                class="cmm__input" v-model.number="form.peso_seco_g"
                placeholder="ej: 350.0"
                autofocus
              />
              <span class="cmm__unit">g</span>
            </div>
          </div>

          <!-- Sede destino -->
          <div class="cmm__field">
            <label class="cmm__label">
              Sede destino
              <span class="cmm__required">requerido</span>
            </label>
            <select v-model="form.sede_id" class="cmm__select" :disabled="loadingSedes">
              <option :value="null">— Seleccioná una sede —</option>
              <option v-for="s in sedes" :key="s.id" :value="s.id">{{ s.nombre }}</option>
            </select>
          </div>

          <!-- Forma producto -->
          <div class="cmm__field">
            <label class="cmm__label">
              Forma de producto
              <span class="cmm__optional">opcional</span>
            </label>
            <select v-model="form.forma_producto" class="cmm__select">
              <option value="flor_seca">Flor seca</option>
              <option value="resina">Resina</option>
              <option value="extracto">Extracto</option>
              <option value="otro">Otro</option>
            </select>
          </div>

          <!-- Notas -->
          <div class="cmm__field">
            <label class="cmm__label">
              Notas
              <span class="cmm__optional">opcional</span>
            </label>
            <textarea
              class="cmm__input cmm__textarea" rows="2"
              v-model="form.notas"
              placeholder="Observaciones del proceso de manicura…"
            />
          </div>

          <div class="cmm__info">
            El stock se generará automáticamente en la sede seleccionada. El lote quedará finalizado.
          </div>
        </div>

        <div class="cmm__footer">
          <button class="cmm__btn-ghost" :disabled="saving" @click="cerrar">Cancelar</button>
          <button class="cmm__btn-primary" :disabled="saving || !canSubmit" @click="confirmar">
            <span v-if="saving" class="cmm__spinner" />
            <CheckCheck v-else :size="14" :stroke-width="2" />
            Completar y finalizar
          </button>
        </div>

      </div>
    </div>
  </Teleport>
</template>

<script setup>
import { ref, computed, watch } from 'vue'
import { CheckCheck, X } from 'lucide-vue-next'
import { completarManicura, listSedes } from '../../lib/api.js'

const props = defineProps({
  modelValue: { type: Boolean, required: true },
  lote:       { type: Object,  default: null },
})
const emit = defineEmits(['update:modelValue', 'completado'])

const form = ref({ peso_seco_g: null, sede_id: null, forma_producto: 'flor_seca', notas: '' })
const error       = ref(null)
const saving      = ref(false)
const sedes       = ref([])
const loadingSedes = ref(false)

const canSubmit = computed(() => form.value.peso_seco_g > 0 && form.value.sede_id)

watch(() => props.modelValue, async (visible) => {
  if (!visible) return
  resetForm()
  await cargarSedes()
})

function resetForm() {
  form.value = { peso_seco_g: null, sede_id: null, forma_producto: 'flor_seca', notas: '' }
  error.value = null
}

async function cargarSedes() {
  loadingSedes.value = true
  try {
    const { data } = await listSedes()
    sedes.value = data || []
    if (sedes.value.length === 1) form.value.sede_id = sedes.value[0].id
  } catch {
    sedes.value = []
  } finally {
    loadingSedes.value = false
  }
}

async function confirmar() {
  if (!props.lote || !canSubmit.value) return
  saving.value = true
  error.value  = null
  try {
    const { data } = await completarManicura(props.lote.id, {
      peso_seco_g:    form.value.peso_seco_g,
      sede_id:        form.value.sede_id,
      forma_producto: form.value.forma_producto,
      notas:          form.value.notas || undefined,
    })
    emit('completado', data)
    cerrar()
  } catch (e) {
    error.value = e?.response?.data?.error
      || e?.response?.data?.errors?.join(', ')
      || 'Error al completar manicura'
  } finally {
    saving.value = false
  }
}

function cerrar() {
  emit('update:modelValue', false)
}
</script>

<style scoped>
.cmm__overlay {
  position: fixed; inset: 0; z-index: 9000;
  background: rgba(0,0,0,.45);
  display: flex; align-items: center; justify-content: center;
  padding: 1rem;
}
.cmm__panel {
  background: var(--c-paper);
  border-radius: var(--r-2xl);
  box-shadow: 0 24px 64px rgba(0,0,0,.18);
  width: 100%; max-width: 460px;
  display: flex; flex-direction: column;
  overflow: hidden;
}

/* Header */
.cmm__header {
  display: flex; align-items: center; justify-content: space-between;
  padding: 1.25rem 1.5rem 1rem;
  border-bottom: 1px solid var(--c-ink-100);
}
.cmm__header-left { display: flex; align-items: center; gap: .75rem; }
.cmm__icon-wrap {
  width: 36px; height: 36px; border-radius: var(--r-lg);
  background: #ecfdf5; color: #059669;
  display: flex; align-items: center; justify-content: center;
  flex-shrink: 0;
}
.cmm__title { font-size: var(--fs-16); font-weight: 700; color: var(--c-ink-900); }
.cmm__sub   { font-size: var(--fs-12); color: var(--c-ink-400); font-family: var(--font-mono); }
.cmm__close {
  width: 28px; height: 28px; border-radius: var(--r-md);
  border: none; background: transparent; color: var(--c-ink-400);
  cursor: pointer; display: flex; align-items: center; justify-content: center;
  transition: background var(--t-fast), color var(--t-fast);
}
.cmm__close:hover { background: var(--c-ink-100); color: var(--c-ink-700); }

/* Body */
.cmm__body { padding: 1.25rem 1.5rem; display: flex; flex-direction: column; gap: 1.1rem; }

.cmm__alert {
  padding: .6rem .875rem; border-radius: var(--r-md);
  background: #fef2f2; color: #b91c1c;
  font-size: var(--fs-13); border: 1px solid #fecaca;
}

.cmm__field { display: flex; flex-direction: column; gap: .35rem; }
.cmm__label {
  font-size: var(--fs-13); font-weight: 600; color: var(--c-ink-700);
  display: flex; align-items: center; gap: .4rem;
}
.cmm__required {
  font-size: 11px; font-weight: 500; color: #059669;
  background: #ecfdf5; padding: 1px 7px; border-radius: 99px;
}
.cmm__optional {
  font-size: 11px; font-weight: 500; color: var(--c-ink-400);
  background: var(--c-ink-100); padding: 1px 7px; border-radius: 99px;
}

.cmm__select,
.cmm__input {
  width: 100%;
  padding: .5rem .75rem;
  border: 1.5px solid var(--c-ink-200);
  border-radius: var(--r-md);
  background: var(--c-paper);
  font-size: var(--fs-14); color: var(--c-ink-900);
  outline: none; transition: border-color var(--t-fast);
  box-sizing: border-box;
}
.cmm__select:focus,
.cmm__input:focus  { border-color: #059669; }
.cmm__select:disabled { opacity: .6; cursor: not-allowed; }

.cmm__input-row { display: flex; align-items: center; gap: .5rem; }
.cmm__input-row .cmm__input { flex: 1; }
.cmm__unit { font-size: var(--fs-13); color: var(--c-ink-400); font-weight: 500; flex-shrink: 0; }

.cmm__textarea { resize: vertical; min-height: 60px; }

.cmm__info {
  font-size: var(--fs-12); color: var(--c-ink-400); line-height: 1.5;
  padding: .5rem .75rem;
  background: var(--c-ink-50); border-radius: var(--r-md);
}

/* Footer */
.cmm__footer {
  display: flex; justify-content: flex-end; gap: .75rem;
  padding: 1rem 1.5rem 1.25rem;
  border-top: 1px solid var(--c-ink-100);
}
.cmm__btn-ghost {
  padding: .5rem 1rem; border-radius: var(--r-md);
  border: 1.5px solid var(--c-ink-200); background: transparent;
  color: var(--c-ink-600); font-size: var(--fs-14); font-weight: 500;
  cursor: pointer; transition: all var(--t-fast);
}
.cmm__btn-ghost:hover:not(:disabled) { background: var(--c-ink-50); }
.cmm__btn-ghost:disabled { opacity: .5; cursor: not-allowed; }

.cmm__btn-primary {
  display: inline-flex; align-items: center; gap: .4rem;
  padding: .5rem 1.25rem; border-radius: var(--r-md);
  border: none; background: #059669; color: #fff;
  font-size: var(--fs-14); font-weight: 600;
  cursor: pointer; transition: opacity var(--t-fast);
}
.cmm__btn-primary:hover:not(:disabled) { opacity: .88; }
.cmm__btn-primary:disabled { opacity: .5; cursor: not-allowed; }

.cmm__spinner {
  width: 14px; height: 14px;
  border: 2px solid rgba(255,255,255,.35);
  border-top-color: #fff;
  border-radius: 50%;
  animation: cmm-spin .6s linear infinite;
}
@keyframes cmm-spin { to { transform: rotate(360deg); } }
</style>
