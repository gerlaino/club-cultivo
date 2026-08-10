<template>
  <Teleport to="body">
    <Transition name="mct-fade">
      <div v-if="show" class="mct__overlay">
        <div class="mct__modal" role="dialog" aria-modal="true">

          <div class="mct__header">
            <h5 class="mct__title">
              <i class="bi bi-check-circle-fill text-success me-2"></i>
              Completar tarea
            </h5>
            <button class="mct__close" @click="cerrar"><i class="bi bi-x-lg"></i></button>
          </div>

          <div class="mct__body" v-if="tarea">
            <div class="mct__tarea-name">
              <strong>{{ tarea.titulo }}</strong>
              <div v-if="tarea.lote" class="mct__tarea-sub">
                <i class="bi bi-box me-1"></i>Lote: {{ tarea.lote.codigo }}
              </div>
            </div>

            <div class="mct__field">
              <label class="mct__label">
                Horas trabajadas <span class="mct__opt">(opcional)</span>
              </label>
              <div class="mct__input-group">
                <input
                  v-model.number="horas"
                  type="number"
                  class="mct__input"
                  min="0.25" max="24" step="0.25"
                  placeholder="0.0"
                />
                <span class="mct__input-addon">hs</span>
              </div>
              <div v-if="tarea.horas_estimadas" class="mct__hint">
                <i class="bi bi-clock me-1"></i>Estimado: {{ tarea.horas_estimadas }} hs
              </div>
            </div>

            <div v-if="tarea.lote && horas > 0" class="mct__info">
              <i class="bi bi-info-circle-fill me-2"></i>
              Se registrarán <strong>{{ horas }}h</strong> para el lote <strong>{{ tarea.lote.codigo }}</strong>.
            </div>

            <div v-if="esTrasplante" class="mct__trasplante">
              <div class="mct__trasplante-titulo">
                <i class="bi bi-flower1 me-1"></i>¿De qué maceta a qué maceta?
              </div>
              <div class="mct__trasplante-row">
                <div class="mct__field mct__field--inline">
                  <label class="mct__label">Origen <span class="mct__opt">(L)</span></label>
                  <input v-model.number="macetaOrigen" type="number" min="0" step="0.5" class="mct__input" placeholder="ej: 1" />
                </div>
                <div class="mct__trasplante-arrow">→</div>
                <div class="mct__field mct__field--inline">
                  <label class="mct__label">Destino <span class="mct__opt">(L)</span></label>
                  <input v-model.number="macetaDestino" type="number" min="0.1" step="0.5" class="mct__input" placeholder="ej: 3" />
                </div>
              </div>
              <div class="mct__hint"><i class="bi bi-info-circle me-1"></i>Queda en la timeline del lote. Opcional.</div>
            </div>

            <div class="mct__field">
              <label class="mct__label">Notas de completado</label>
              <textarea
                v-model="notas"
                class="mct__textarea"
                rows="3"
                placeholder="¿Cómo salió? ¿Algo a destacar?"
              ></textarea>
            </div>

            <div v-if="error" class="mct__error">
              <i class="bi bi-exclamation-triangle me-2"></i>{{ error }}
            </div>
          </div>

          <div class="mct__footer">
            <button class="mct__btn-ghost" @click="cerrar" :disabled="guardando">Cancelar</button>
            <button class="mct__btn-primary" @click="confirmar" :disabled="guardando">
              <DsSpinner v-if="guardando" :size="14" />
              <i v-else class="bi bi-check-lg me-1"></i>
              Marcar como completada
            </button>
          </div>

        </div>
      </div>
    </Transition>
  </Teleport>
</template>

<script setup>
import { ref, watch, computed } from 'vue'
import { useTareasStore } from '../stores/tareas.js'
import { useModalEscape } from '../composables/useModalEscape.js'
import DsSpinner from '../design-system/components/Spinner.vue'

const props = defineProps({
  show:  { type: Boolean, default: false },
  tarea: { type: Object,  default: null  },
})

const emit = defineEmits(['completada', 'cerrar'])

const tareasStore = useTareasStore()
const horas         = ref(null)
const notas         = ref('')
const error         = ref('')
const guardando     = ref(false)
const macetaOrigen  = ref(null)
const macetaDestino = ref(null)

const esTrasplante = computed(() => props.tarea?.tipo === 'trasplante' && !!props.tarea?.lote)

watch(() => props.tarea, (val) => {
  if (val) {
    horas.value  = val.horas_estimadas || null
    notas.value  = ''
    error.value  = ''
    macetaOrigen.value  = null
    macetaDestino.value = null
  }
})

useModalEscape(() => cerrar())

function cerrar() {
  if (!guardando.value) emit('cerrar')
}

async function confirmar() {
  error.value   = ''
  guardando.value = true
  try {
    const extra = esTrasplante.value && macetaDestino.value > 0
      ? { maceta_origen_l: macetaOrigen.value || undefined, maceta_destino_l: macetaDestino.value }
      : {}
    const resultado = await tareasStore.completar(
      props.tarea.id,
      horas.value  || null,
      notas.value  || null,
      extra
    )
    emit('completada', resultado)
  } catch (e) {
    error.value = e.response?.data?.error || 'Error al completar la tarea'
  } finally {
    guardando.value = false
  }
}
</script>

<style scoped>
.mct__trasplante {
  background: #f0fdf4; border: 1px solid #bbf7d0; border-radius: 12px;
  padding: .75rem .85rem; margin-bottom: 1rem;
}
.mct__trasplante-titulo { font-size: .82rem; font-weight: 700; color: #166534; margin-bottom: .6rem; }
.mct__trasplante-row { display: flex; align-items: flex-end; gap: .5rem; }
.mct__field--inline { flex: 1; min-width: 0; margin-bottom: 0; }
.mct__trasplante-arrow { padding-bottom: .55rem; color: #16a34a; font-weight: 800; }

.mct__overlay {
  position: fixed; inset: 0;
  background: rgba(0,0,0,.45);
  display: flex; align-items: center; justify-content: center;
  z-index: 1055; padding: 1rem;
  backdrop-filter: blur(3px);
}

.mct__modal {
  background: #fff;
  border-radius: 16px;
  box-shadow: 0 20px 60px rgba(0,0,0,.2);
  width: 100%; max-width: 440px;
  display: flex; flex-direction: column;
  overflow: hidden;
}

.mct__header {
  display: flex; align-items: center; justify-content: space-between;
  padding: 1.25rem 1.5rem 1rem;
  border-bottom: 1px solid var(--c-slate-100);
}
.mct__title { font-size: 1rem; font-weight: 700; margin: 0; color: var(--c-slate-900); }
.mct__close {
  width: 30px; height: 30px; border: none; background: transparent;
  border-radius: 8px; color: var(--c-slate-400); cursor: pointer;
  display: flex; align-items: center; justify-content: center;
  transition: background .15s, color .15s;
}
.mct__close:hover { background: var(--c-slate-100); color: var(--c-slate-900); }

.mct__body { padding: 1.25rem 1.5rem; display: flex; flex-direction: column; gap: 1rem; }

.mct__tarea-name {
  background: var(--c-slate-50); border: 1px solid var(--c-slate-200);
  border-radius: 10px; padding: .75rem 1rem;
  font-size: .9rem; color: var(--c-slate-900);
}
.mct__tarea-sub { font-size: .78rem; color: var(--c-slate-500); margin-top: .2rem; }

.mct__field { display: flex; flex-direction: column; gap: .35rem; }
.mct__label { font-size: .82rem; font-weight: 600; color: #374151; }
.mct__opt { font-weight: 400; color: var(--c-slate-400); }
.mct__hint { font-size: .75rem; color: var(--c-slate-500); }

.mct__input-group { display: flex; border: 1.5px solid #d1d5db; border-radius: 10px; overflow: hidden; }
.mct__input {
  flex: 1; border: none; outline: none; padding: .65rem .9rem;
  font-size: .95rem; background: #fff;
}
.mct__input:focus { outline: none; }
.mct__input-group:focus-within { border-color: #1b5e20; box-shadow: 0 0 0 3px rgba(27,94,32,.1); }
.mct__input-addon {
  background: var(--c-slate-50); color: var(--c-slate-500);
  padding: .65rem .875rem; font-size: .82rem; font-weight: 600;
  border-left: 1.5px solid #d1d5db; white-space: nowrap;
}

.mct__textarea {
  border: 1.5px solid #d1d5db; border-radius: 10px;
  padding: .65rem .9rem; font-size: .875rem; resize: vertical;
  font-family: inherit; transition: border-color .15s;
  width: 100%; box-sizing: border-box;
}
.mct__textarea:focus { outline: none; border-color: #1b5e20; box-shadow: 0 0 0 3px rgba(27,94,32,.1); }

.mct__info {
  background: #eff6ff; border: 1px solid #bfdbfe; color: #1e40af;
  border-radius: 8px; padding: .6rem .875rem; font-size: .8rem;
}

.mct__error {
  background: #fef2f2; border: 1px solid #fecaca; color: #991b1b;
  border-radius: 8px; padding: .6rem .875rem; font-size: .8rem;
}

.mct__footer {
  display: flex; align-items: center; justify-content: flex-end; gap: .75rem;
  padding: 1rem 1.5rem; border-top: 1px solid var(--c-slate-100);
}

.mct__btn-ghost {
  height: 40px; padding: 0 1.1rem; border: 1.5px solid #d1d5db;
  border-radius: 8px; background: transparent; color: #374151;
  font-size: .85rem; font-weight: 500; cursor: pointer; transition: background .15s;
}
.mct__btn-ghost:hover:not(:disabled) { background: var(--c-slate-50); }
.mct__btn-ghost:disabled { opacity: .5; cursor: not-allowed; }

.mct__btn-primary {
  height: 40px; padding: 0 1.25rem; border: none;
  border-radius: 8px; background: #1b5e20; color: #fff;
  font-size: .85rem; font-weight: 600; cursor: pointer;
  display: inline-flex; align-items: center; gap: .35rem;
  transition: opacity .15s;
}
.mct__btn-primary:hover:not(:disabled) { opacity: .88; }
.mct__btn-primary:disabled { opacity: .5; cursor: not-allowed; }

.mct-fade-enter-active { animation: mct-appear .2s ease; }
.mct-fade-leave-active { animation: mct-appear .15s ease reverse; }
@keyframes mct-appear {
  from { opacity: 0; transform: scale(.96) translateY(8px); }
  to   { opacity: 1; transform: scale(1)   translateY(0);   }
}
</style>
