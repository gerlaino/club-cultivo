<template>
  <Teleport to="body">
    <Transition name="mp-fade">
      <div v-if="modelValue" class="mp-overlay" @click.self="$emit('update:modelValue', false)">
        <div class="mp-modal" role="dialog" aria-modal="true">

          <div class="mp-header">
            <div class="mp-header-ico">
              <Scale :size="20" :stroke-width="1.75" />
            </div>
            <div>
              <h2 class="mp-title">Registrar pesada</h2>
              <p class="mp-subtitle">
                Lote <strong>{{ lote?.codigo }}</strong> ·
                <span class="mp-fase-tag">{{ config.label }}</span>
              </p>
            </div>
            <button class="mp-close" @click="$emit('update:modelValue', false)" aria-label="Cerrar">
              <X :size="18" :stroke-width="2" />
            </button>
          </div>

          <form class="mp-body" @submit.prevent="submit">

            <!-- Peso principal según fase_destino -->
            <div class="mp-field">
              <label class="mp-label">{{ config.pesoLabel }} <span class="mp-req">*</span></label>
              <input
                v-model.number="form.peso"
                type="number"
                step="0.1"
                min="0.1"
                class="mp-input"
                placeholder="0.0 g"
                required
                autofocus
              />
            </div>

            <!-- Checkbox manicurado (solo para fase curado) -->
            <div v-if="config.showManicurado" class="mp-field mp-field--row">
              <input
                id="mp-manicurado"
                v-model="form.manicurado"
                type="checkbox"
                class="mp-checkbox"
              />
              <label for="mp-manicurado" class="mp-label mp-label--inline">
                Material manicurado
              </label>
            </div>

            <!-- Notas -->
            <div class="mp-field">
              <label class="mp-label">Notas <span class="mp-opt">opcional</span></label>
              <textarea
                v-model="form.notas"
                class="mp-textarea"
                rows="2"
                placeholder="Observaciones del proceso…"
              ></textarea>
            </div>

            <div v-if="error" class="mp-error">
              <AlertCircle :size="15" :stroke-width="2" />
              {{ error }}
            </div>

            <div class="mp-actions">
              <button type="button" class="mp-btn-cancel" @click="$emit('update:modelValue', false)">
                Cancelar
              </button>
              <button type="submit" class="mp-btn-submit" :disabled="saving">
                <div v-if="saving" class="mp-spinner"></div>
                <Scale v-else :size="15" :stroke-width="2" />
                Guardar pesada
              </button>
            </div>

          </form>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>

<script setup>
import { ref, computed, watch } from 'vue'
import { Scale, X, AlertCircle } from 'lucide-vue-next'
import { createPesada } from '../../lib/api.js'
import { useModalEscape } from '../../composables/useModalEscape.js'

const props = defineProps({
  modelValue: Boolean,
  lote: Object,
})
const emit = defineEmits(['update:modelValue', 'saved'])
useModalEscape(() => emit('update:modelValue', false))

// Derivar fase_origen / fase_destino / label y campo de peso según estado del lote
const FASE_CONFIG = {
  cosecha: {
    fase_origen:  'cosecha',
    fase_destino: 'secado',
    label:        'Cosecha → Manicura',
    pesoLabel:    'Peso húmedo (g)',
    pesoKey:      'peso_humedo_g',
    showManicurado: false,
  },
  secado: {
    fase_origen:  'secado',
    fase_destino: 'curado',
    label:        'Manicura → Curado',
    pesoLabel:    'Peso seco (g)',
    pesoKey:      'peso_seco_g',
    showManicurado: true,
  },
  curado: {
    fase_origen:  'curado',
    fase_destino: 'finalizado',
    label:        'Curado → Finalizado',
    pesoLabel:    'Peso curado (g)',
    pesoKey:      'peso_curado_g',
    showManicurado: false,
  },
}

const config = computed(() => FASE_CONFIG[props.lote?.estado] || {
  fase_origen: '', fase_destino: '', label: 'Pesada', pesoLabel: 'Peso (g)', pesoKey: 'peso_humedo_g', showManicurado: false,
})

const form   = ref({ peso: null, manicurado: false, notas: '' })
const saving = ref(false)
const error  = ref('')

watch(() => props.modelValue, (open) => {
  if (open) {
    form.value = { peso: null, manicurado: false, notas: '' }
    error.value = ''
  }
})

async function submit() {
  if (!props.lote?.id) return
  const cfg = config.value
  saving.value = true
  error.value  = ''

  const body = {
    fase_origen:  cfg.fase_origen,
    fase_destino: cfg.fase_destino,
    [cfg.pesoKey]: form.value.peso,
    notas: form.value.notas || undefined,
  }
  if (cfg.showManicurado) body.manicurado = form.value.manicurado

  try {
    const { data } = await createPesada(props.lote.id, body)
    emit('saved', data)
    emit('update:modelValue', false)
  } catch (e) {
    error.value = e.response?.data?.errors?.[0] || e.response?.data?.error || 'Error al guardar pesada'
  } finally {
    saving.value = false
  }
}
</script>

<style scoped>
.mp-overlay {
  position: fixed; inset: 0;
  background: rgba(0, 0, 0, 0.45);
  z-index: 1050;
  display: flex; align-items: center; justify-content: center;
  padding: var(--sp-4);
  backdrop-filter: blur(3px);
}
.mp-modal {
  background: var(--c-paper);
  border-radius: var(--r-xl);
  width: 100%;
  max-width: 420px;
  box-shadow: 0 24px 64px rgba(0, 0, 0, 0.18);
  overflow: hidden;
}

.mp-header {
  display: flex;
  align-items: center;
  gap: var(--sp-3);
  padding: var(--sp-5) var(--sp-6);
  border-bottom: 1px solid var(--c-ink-200);
}
.mp-header-ico {
  width: 40px; height: 40px;
  border-radius: var(--r-lg);
  background: rgba(107, 79, 190, 0.1);
  color: #6B4FBE;
  display: flex; align-items: center; justify-content: center;
  flex-shrink: 0;
}
.mp-title { font-size: var(--fs-16); font-weight: 700; color: var(--c-ink-900); margin: 0; }
.mp-subtitle { font-size: var(--fs-13); color: var(--c-ink-500); margin: 2px 0 0; }
.mp-fase-tag {
  background: rgba(107,79,190,.1);
  color: #6B4FBE;
  font-size: var(--fs-12);
  font-weight: 600;
  padding: 1px 7px;
  border-radius: 999px;
}
.mp-close {
  margin-left: auto;
  background: none; border: none;
  color: var(--c-ink-400); cursor: pointer; padding: var(--sp-1);
  border-radius: var(--r-sm); display: flex; align-items: center;
  transition: color var(--t-fast), background var(--t-fast);
  flex-shrink: 0;
}
.mp-close:hover { color: var(--c-ink-900); background: var(--c-ink-100); }

.mp-body { padding: var(--sp-5) var(--sp-6) var(--sp-6); display: flex; flex-direction: column; gap: var(--sp-4); }

.mp-field { display: flex; flex-direction: column; gap: var(--sp-1); }
.mp-field--row { flex-direction: row; align-items: center; gap: var(--sp-2); }

.mp-label { font-size: var(--fs-13); font-weight: 600; color: var(--c-ink-700); }
.mp-label--inline { font-weight: 500; cursor: pointer; }
.mp-req { color: var(--c-rust-500); }
.mp-opt { font-weight: 400; color: var(--c-ink-400); }

.mp-input, .mp-textarea {
  width: 100%; box-sizing: border-box;
  background: var(--c-ink-50);
  border: 1.5px solid var(--c-ink-200);
  border-radius: var(--r-md);
  padding: 9px 12px;
  font-size: var(--fs-14); color: var(--c-ink-900);
  transition: border-color var(--t-fast);
  font-family: inherit;
}
.mp-input:focus, .mp-textarea:focus {
  outline: none; border-color: #6B4FBE; background: var(--c-paper);
}
.mp-textarea { resize: vertical; min-height: 60px; }
.mp-checkbox { width: 16px; height: 16px; cursor: pointer; flex-shrink: 0; accent-color: #6B4FBE; }

.mp-error {
  display: flex; align-items: center; gap: var(--sp-2);
  background: var(--c-rust-50); border: 1px solid var(--c-rust-200);
  border-radius: var(--r-md); padding: var(--sp-3) var(--sp-4);
  font-size: var(--fs-13); color: var(--c-rust-700);
}

.mp-actions {
  display: flex; gap: var(--sp-3); justify-content: flex-end;
  padding-top: var(--sp-2); border-top: 1px solid var(--c-ink-100);
}
.mp-btn-cancel {
  background: transparent; border: 1.5px solid var(--c-ink-200);
  color: var(--c-ink-600); padding: var(--sp-2) var(--sp-5);
  border-radius: var(--r-md); font-size: var(--fs-14); font-weight: 500;
  cursor: pointer; transition: all var(--t-fast);
}
.mp-btn-cancel:hover { background: var(--c-ink-50); border-color: var(--c-ink-300); }
.mp-btn-submit {
  display: flex; align-items: center; gap: var(--sp-2);
  background: #6B4FBE; color: #fff;
  border: none; padding: var(--sp-2) var(--sp-5);
  border-radius: var(--r-md); font-size: var(--fs-14); font-weight: 600;
  cursor: pointer; transition: opacity var(--t-fast);
}
.mp-btn-submit:hover:not(:disabled) { opacity: 0.88; }
.mp-btn-submit:disabled { opacity: 0.5; cursor: not-allowed; }
.mp-spinner {
  width: 14px; height: 14px;
  border: 2px solid rgba(255,255,255,0.3);
  border-top-color: #fff;
  border-radius: 50%;
  animation: mp-spin .6s linear infinite;
}
@keyframes mp-spin { to { transform: rotate(360deg); } }

.mp-fade-enter-active, .mp-fade-leave-active { transition: opacity .2s; }
.mp-fade-enter-from, .mp-fade-leave-to { opacity: 0; }
</style>
