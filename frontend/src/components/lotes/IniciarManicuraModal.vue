<template>
  <Teleport to="body">
    <div v-if="modelValue" class="imm__overlay" @mousedown.self="cerrar">
      <div class="imm__panel">

        <div class="imm__header">
          <div class="imm__header-left">
            <div class="imm__icon-wrap"><Scissors :size="18" :stroke-width="2" /></div>
            <div>
              <div class="imm__title">Iniciar Manicura</div>
              <div class="imm__sub">Lote {{ lote?.codigo }}</div>
            </div>
          </div>
          <button class="imm__close" @click="cerrar"><X :size="16" /></button>
        </div>

        <div class="imm__body">
          <div v-if="error" class="imm__alert">{{ error }}</div>

          <!-- Sala destino -->
          <div class="imm__field">
            <label class="imm__label">
              Sala de manicura
              <span class="imm__optional">recomendado</span>
            </label>
            <select v-model="form.sala_id" class="imm__select" @change="onSalaChange">
              <option :value="null">— Sin cambio de sala —</option>
              <option v-for="s in salasManicura" :key="s.id" :value="s.id">
                {{ s.nombre }}{{ s.responsable_nombre ? ` · ${s.responsable_nombre}` : '' }}
              </option>
            </select>
          </div>

          <!-- Responsable -->
          <div class="imm__field">
            <label class="imm__label">
              Responsable
              <span class="imm__optional">opcional</span>
            </label>
            <select v-model="form.responsable_id" class="imm__select" :disabled="loadingUsuarios">
              <option :value="null">— Sin asignar (lote libre) —</option>
              <option v-for="u in usuarios" :key="u.id" :value="u.id">
                {{ u.nombre_completo || [u.first_name, u.last_name].filter(Boolean).join(' ') || u.email }}
                ({{ roleLabel(u.role) }})
              </option>
            </select>
            <p class="imm__hint" :class="form.responsable_id ? 'imm__hint--info' : 'imm__hint--muted'">
              <template v-if="form.responsable_id">
                El responsable recibirá una notificación y podrá ver el lote en su panel.
              </template>
              <template v-else>
                Sin responsable: el lote queda disponible para cualquier manicurador del club.
              </template>
            </p>
          </div>

          <!-- Peso húmedo -->
          <div class="imm__field">
            <label class="imm__label">
              Peso húmedo (g)
              <span class="imm__optional">opcional</span>
            </label>
            <div class="imm__input-row">
              <input
                type="number" step="0.1" min="0"
                class="imm__input" v-model.number="form.peso_humedo_g"
                placeholder="ej: 1200.5"
              />
              <span class="imm__unit">g</span>
            </div>
          </div>

          <!-- Notas -->
          <div class="imm__field">
            <label class="imm__label">
              Notas
              <span class="imm__optional">opcional</span>
            </label>
            <textarea
              class="imm__input imm__textarea" rows="2"
              v-model="form.notas"
              placeholder="Observaciones del inicio de manicura…"
            />
          </div>
        </div>

        <div class="imm__footer">
          <button class="imm__btn-ghost" :disabled="saving" @click="cerrar">Cancelar</button>
          <button class="imm__btn-primary" :disabled="saving" @click="confirmar">
            <span v-if="saving" class="imm__spinner" />
            <Scissors v-else :size="14" :stroke-width="2" />
            Iniciar Manicura
          </button>
        </div>

      </div>
    </div>
  </Teleport>
</template>

<script setup>
import { ref, computed, watch } from 'vue'
import { Scissors, X } from 'lucide-vue-next'
import { listUsers, asignarManicurador, transicionarLote } from '../../lib/api.js'

const props = defineProps({
  modelValue:    { type: Boolean, required: true },
  lote:          { type: Object,  default: null },
  salasDestino:  { type: Array,   default: () => [] },
})
const emit = defineEmits(['update:modelValue', 'avanzado'])

const form = ref({ sala_id: null, responsable_id: null, peso_humedo_g: null, notas: '' })
const error         = ref(null)
const saving        = ref(false)
const usuarios      = ref([])
const loadingUsuarios = ref(false)

const ROLE_LABELS = { manicura: 'Manicura', admin: 'Admin', supervisor: 'Supervisor' }
const roleLabel = (r) => ROLE_LABELS[r] || r

const salasManicura = computed(() =>
  props.salasDestino.filter(s => ['manicura', 'secado'].includes(s.kind))
)

watch(() => props.modelValue, async (visible) => {
  if (!visible) return
  resetForm()
  await cargarUsuarios()
})

function resetForm() {
  form.value = { sala_id: null, responsable_id: null, peso_humedo_g: null, notas: '' }
  error.value = null
}

async function cargarUsuarios() {
  loadingUsuarios.value = true
  try {
    const { data } = await listUsers({ role: 'manicura,admin,supervisor' })
    usuarios.value = (data?.usuarios || data || [])
      .filter(u => ['manicura', 'admin', 'supervisor'].includes(u.role))
  } catch {
    usuarios.value = []
  } finally {
    loadingUsuarios.value = false
  }
}

function onSalaChange() {
  const sala = props.salasDestino.find(s => s.id === form.value.sala_id)
  if (sala?.responsable_id) {
    form.value.responsable_id = sala.responsable_id
  }
}

async function confirmar() {
  if (!props.lote) return
  saving.value = true
  error.value  = null
  try {
    let data
    if (form.value.responsable_id) {
      // Con responsable → en_manicura
      const res = await asignarManicurador(props.lote.id, form.value.responsable_id, {
        sala_id:       form.value.sala_id   || undefined,
        peso_humedo_g: form.value.peso_humedo_g || undefined,
        notas:         form.value.notas        || undefined,
      })
      data = res.data
    } else {
      // Sin responsable → secado (libre)
      const res = await transicionarLote(props.lote.id, {
        nueva_fase: 'secado',
        sala_id:    form.value.sala_id || undefined,
        pesada: {
          peso_humedo_g: form.value.peso_humedo_g || undefined,
          notas:         form.value.notas        || undefined,
        },
      })
      data = res.data
    }
    emit('avanzado', data)
    cerrar()
  } catch (e) {
    error.value = e?.response?.data?.error
      || e?.response?.data?.errors?.join(', ')
      || 'Error al iniciar manicura'
  } finally {
    saving.value = false
  }
}

function cerrar() {
  emit('update:modelValue', false)
}
</script>

<style scoped>
.imm__overlay {
  position: fixed; inset: 0; z-index: 9000;
  background: rgba(0,0,0,.45);
  display: flex; align-items: center; justify-content: center;
  padding: 1rem;
}
.imm__panel {
  background: var(--c-paper);
  border-radius: var(--r-2xl);
  box-shadow: 0 24px 64px rgba(0,0,0,.18);
  width: 100%; max-width: 480px;
  display: flex; flex-direction: column;
  overflow: hidden;
}

/* Header */
.imm__header {
  display: flex; align-items: center; justify-content: space-between;
  padding: 1.25rem 1.5rem 1rem;
  border-bottom: 1px solid var(--c-ink-100);
}
.imm__header-left { display: flex; align-items: center; gap: .75rem; }
.imm__icon-wrap {
  width: 36px; height: 36px; border-radius: var(--r-lg);
  background: #f0ebff; color: #7c3aed;
  display: flex; align-items: center; justify-content: center;
  flex-shrink: 0;
}
.imm__title { font-size: var(--fs-16); font-weight: 700; color: var(--c-ink-900); }
.imm__sub   { font-size: var(--fs-12); color: var(--c-ink-400); font-family: var(--font-mono); }
.imm__close {
  width: 28px; height: 28px; border-radius: var(--r-md);
  border: none; background: transparent; color: var(--c-ink-400);
  cursor: pointer; display: flex; align-items: center; justify-content: center;
  transition: background var(--t-fast), color var(--t-fast);
}
.imm__close:hover { background: var(--c-ink-100); color: var(--c-ink-700); }

/* Body */
.imm__body { padding: 1.25rem 1.5rem; display: flex; flex-direction: column; gap: 1.1rem; }

.imm__alert {
  padding: .6rem .875rem; border-radius: var(--r-md);
  background: #fef2f2; color: #b91c1c;
  font-size: var(--fs-13); border: 1px solid #fecaca;
}

.imm__field { display: flex; flex-direction: column; gap: .35rem; }
.imm__label {
  font-size: var(--fs-13); font-weight: 600; color: var(--c-ink-700);
  display: flex; align-items: center; gap: .4rem;
}
.imm__optional {
  font-size: 11px; font-weight: 500; color: var(--c-ink-400);
  background: var(--c-ink-100); padding: 1px 7px; border-radius: 99px;
}

.imm__select,
.imm__input {
  width: 100%;
  padding: .5rem .75rem;
  border: 1.5px solid var(--c-ink-200);
  border-radius: var(--r-md);
  background: var(--c-paper);
  font-size: var(--fs-14); color: var(--c-ink-900);
  outline: none; transition: border-color var(--t-fast);
  box-sizing: border-box;
}
.imm__select:focus,
.imm__input:focus  { border-color: #7c3aed; }
.imm__select:disabled { opacity: .6; cursor: not-allowed; }

.imm__input-row { display: flex; align-items: center; gap: .5rem; }
.imm__input-row .imm__input { flex: 1; }
.imm__unit { font-size: var(--fs-13); color: var(--c-ink-400); font-weight: 500; flex-shrink: 0; }

.imm__textarea { resize: vertical; min-height: 60px; }

.imm__hint {
  font-size: var(--fs-12); line-height: 1.45;
  margin: 0;
}
.imm__hint--muted { color: var(--c-ink-400); }
.imm__hint--info  { color: #6d28d9; }

/* Footer */
.imm__footer {
  display: flex; justify-content: flex-end; gap: .75rem;
  padding: 1rem 1.5rem 1.25rem;
  border-top: 1px solid var(--c-ink-100);
}
.imm__btn-ghost {
  padding: .5rem 1rem; border-radius: var(--r-md);
  border: 1.5px solid var(--c-ink-200); background: transparent;
  color: var(--c-ink-600); font-size: var(--fs-14); font-weight: 500;
  cursor: pointer; transition: all var(--t-fast);
}
.imm__btn-ghost:hover:not(:disabled) { background: var(--c-ink-50); }
.imm__btn-ghost:disabled { opacity: .5; cursor: not-allowed; }

.imm__btn-primary {
  display: inline-flex; align-items: center; gap: .4rem;
  padding: .5rem 1.25rem; border-radius: var(--r-md);
  border: none; background: #7c3aed; color: #fff;
  font-size: var(--fs-14); font-weight: 600;
  cursor: pointer; transition: opacity var(--t-fast);
}
.imm__btn-primary:hover:not(:disabled) { opacity: .88; }
.imm__btn-primary:disabled { opacity: .5; cursor: not-allowed; }

.imm__spinner {
  width: 14px; height: 14px;
  border: 2px solid rgba(255,255,255,.35);
  border-top-color: #fff;
  border-radius: 50%;
  animation: imm-spin .6s linear infinite;
}
@keyframes imm-spin { to { transform: rotate(360deg); } }
</style>
