<script setup>
import { ref, computed, watch, onMounted } from 'vue'
import { useSalasStore } from '../../stores/salas'
import { listSedes } from '../../lib/api'
import DsSpinner from '../../design-system/components/Spinner.vue'

const props = defineProps({
  sedeIdFija: { type: Number, default: null }, // Si viene de SedeDetailView, la sede está fija
})

const emit = defineEmits(['created', 'close'])

const salas = useSalasStore()
const sedes = ref([])
const saving = ref(false)
const error  = ref(null)

// Las salas son SOLO de cultivo. 'cosecha' y 'manicura' se retiraron del alta: la cosecha
// es un evento → post-cosecha, y la manicura se trabaja por estado del lote (en_manicura),
// no en una sala. Esos kinds siguen válidos en el backend para salas ya existentes.
const KINDS = [
  { value: 'vegetativo', label: 'Vegetativo' },
  { value: 'floracion',  label: 'Floración'  },
]

const form = ref({
  nombre:     '',
  state:      'activa',
  kind:       'vegetativo',
  sede_id:    props.sedeIdFija || null,
  notes:      '',
})

const errors = ref({})

// Sede seleccionada — para mostrar capacidad actual
const sedeSeleccionada = computed(() =>
  sedes.value.find(s => s.id === form.value.sede_id) || null
)

function validate() {
  const e = {}
  if (!form.value.nombre.trim()) e.nombre = 'El nombre es obligatorio'
  if (!props.sedeIdFija && !form.value.sede_id) e.sede_id = 'La sede es obligatoria'
  errors.value = e
  return !Object.keys(e).length
}

async function handleSubmit() {
  if (!validate()) return
  saving.value = true
  error.value  = null
  try {
    await salas.create(form.value)
    emit('created')
    emit('close')
  } catch (e) {
    error.value = e?.response?.data?.errors?.join(', ') || 'Error al crear la sala'
  } finally {
    saving.value = false
  }
}

onMounted(async () => {
  const { data } = await listSedes()
  sedes.value = data || []
  if (props.sedeIdFija) form.value.sede_id = props.sedeIdFija
})
</script>

<template>
  <Teleport to="body">
    <div v-modal="() => $emit('close')" class="mcr__overlay" >
      <div class="mcr__panel">

        <!-- Header -->
        <div class="mcr__header">
          <div class="mcr__header-icon">
            <i class="bi bi-grid-3x3-gap"></i>
          </div>
          <div>
            <h2 class="mcr__title">Nueva sala</h2>
            <p class="mcr__sub">
              <template v-if="sedeIdFija && sedeSeleccionada">
                En <strong>{{ sedeSeleccionada.nombre }}</strong>
              </template>
              <template v-else>Completá los datos de la sala</template>
            </p>
          </div>
          <button class="mcr__close" @click="$emit('close')">
            <i class="bi bi-x-lg"></i>
          </button>
        </div>

        <!-- Body -->
        <div class="mcr__body">
          <div v-if="error" class="mcr__alert">
            <i class="bi bi-exclamation-triangle-fill"></i> {{ error }}
          </div>

          <!-- Nombre -->
          <div class="mcr__field mcr__field--full">
            <label class="mcr__label">Nombre <span class="mcr__req">*</span></label>
            <input
              class="mcr__input" :class="{ 'mcr__input--err': errors.nombre }"
              v-model.trim="form.nombre"
              placeholder="Ej: Sala A — Vegetativo"
              autofocus
            />
            <span v-if="errors.nombre" class="mcr__err">{{ errors.nombre }}</span>
          </div>

          <!-- Tipo de sala (selector visual) -->
          <div class="mcr__field mcr__field--full">
            <label class="mcr__label">Tipo de sala</label>
            <div class="mcr__kinds">
              <button
                v-for="k in KINDS"
                :key="k.value"
                type="button"
                class="mcr__kind-btn"
                :class="{ 'mcr__kind-btn--active': form.kind === k.value }"
                @click="form.kind = k.value"
              >{{ k.label }}</button>
            </div>
          </div>

          <!-- Estado + Pots en grilla -->
          <div class="mcr__grid">
            <div class="mcr__field">
              <label class="mcr__label">Estado inicial</label>
              <select class="mcr__input" v-model="form.state">
                <option value="activa">Activa</option>
                <option value="mantenimiento">En mantenimiento</option>
                <option value="cerrada">Cerrada</option>
              </select>
            </div>
          </div>

          <!-- Sede (solo si no está fija) -->
          <div v-if="!sedeIdFija" class="mcr__field mcr__field--full">
            <label class="mcr__label">Sede <span class="mcr__req">*</span></label>
            <select class="mcr__input" :class="{ 'mcr__input--err': errors.sede_id }" v-model="form.sede_id">
              <option :value="null" disabled>Seleccioná una sede</option>
              <option v-for="s in sedes.filter(s => ['produccion','mixta'].includes(s.tipo))" :key="s.id" :value="s.id">
                {{ s.nombre }}
              </option>
            </select>
            <span v-if="errors.sede_id" class="mcr__err">{{ errors.sede_id }}</span>
          </div>

          <!-- Notas -->
          <div class="mcr__field mcr__field--full">
            <label class="mcr__label">Notas</label>
            <textarea
              class="mcr__input mcr__textarea"
              v-model.trim="form.notes"
              rows="2"
              placeholder="Observaciones opcionales…"
            ></textarea>
          </div>
        </div>

        <!-- Footer -->
        <div class="mcr__footer">
          <button class="mcr__btn-ghost" :disabled="saving" @click="$emit('close')">
            Cancelar
          </button>
          <button class="mcr__btn-primary" :disabled="saving" @click="handleSubmit">
            <DsSpinner v-if="saving" :size="14" />
            <i v-else class="bi bi-plus-lg"></i>
            {{ saving ? 'Creando…' : 'Crear sala' }}
          </button>
        </div>

      </div>
    </div>
  </Teleport>
</template>

<style scoped>
.mcr__overlay {
  position: fixed; inset: 0;
  background: rgba(0,0,0,.45);
  display: flex; align-items: center; justify-content: center;
  z-index: 1060; padding: 1rem;
  backdrop-filter: blur(3px);
}
.mcr__panel {
  background: #fff; border-radius: 16px;
  width: 100%; max-width: 520px;
  display: flex; flex-direction: column;
  box-shadow: 0 24px 64px rgba(0,0,0,.15);
  max-height: 90vh; overflow-y: auto;
}

/* Header */
.mcr__header {
  display: flex; align-items: center; gap: .875rem;
  padding: 1.25rem 1.4rem 1rem;
  border-bottom: 1px solid var(--c-slate-100);
  position: sticky; top: 0; background: #fff; z-index: 1;
}
.mcr__header-icon {
  width: 40px; height: 40px; border-radius: 10px;
  background: rgba(27,94,32,.1); color: #1b5e20;
  display: flex; align-items: center; justify-content: center;
  font-size: 1rem; flex-shrink: 0;
}
.mcr__title { font-size: 1.05rem; font-weight: 800; color: var(--c-slate-900); margin: 0 0 .1rem; }
.mcr__sub   { font-size: .78rem; color: var(--c-slate-400); margin: 0; }
.mcr__close {
  margin-left: auto; background: var(--c-slate-100); border: none;
  width: 30px; height: 30px; border-radius: 8px;
  cursor: pointer; display: flex; align-items: center; justify-content: center;
  color: var(--c-slate-500); flex-shrink: 0; transition: all .15s;
}
.mcr__close:hover { background: var(--c-slate-200); color: var(--c-slate-900); }

/* Body */
.mcr__body {
  padding: 1.25rem 1.4rem;
  display: flex; flex-direction: column; gap: 1rem;
}
.mcr__alert {
  background: #fef2f2; border: 1px solid #fecaca; color: #dc2626;
  padding: .75rem 1rem; border-radius: 9px;
  font-size: .85rem; display: flex; gap: .5rem; align-items: flex-start;
}

/* Fields */
.mcr__grid { display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; }
@media (max-width: 480px) { .mcr__grid { grid-template-columns: 1fr; } }
.mcr__field { display: flex; flex-direction: column; gap: .35rem; }
.mcr__field--full { grid-column: 1 / -1; }
.mcr__label { font-size: .75rem; font-weight: 700; color: #374151; text-transform: uppercase; letter-spacing: .04em; }
.mcr__req   { color: #dc2626; }
.mcr__input {
  background: var(--c-slate-50); border: 1.5px solid var(--c-slate-200);
  border-radius: 9px; padding: .65rem .9rem;
  font-size: .875rem; color: var(--c-slate-900);
  width: 100%; box-sizing: border-box;
  transition: border .15s, box-shadow .15s;
}
.mcr__input:focus { outline: none; border-color: #1b5e20; box-shadow: 0 0 0 3px rgba(27,94,32,.1); background: #fff; }
.mcr__input--err { border-color: #dc2626 !important; }
.mcr__textarea { resize: vertical; min-height: 68px; }
.mcr__err  { font-size: .72rem; color: #dc2626; font-weight: 600; }
.mcr__hint { font-size: .72rem; color: var(--c-slate-400); }
.mcr__hint { font-size: .72rem; color: var(--c-slate-400); }

/* Kinds selector */
.mcr__kinds { display: flex; flex-wrap: wrap; gap: .4rem; }
.mcr__kind-btn {
  padding: .4rem .85rem; border: 1.5px solid var(--c-slate-200);
  border-radius: 8px; background: var(--c-slate-50);
  font-size: .78rem; font-weight: 600; color: var(--c-slate-600);
  cursor: pointer; transition: all .15s;
}
.mcr__kind-btn:hover { border-color: var(--c-slate-400); background: var(--c-slate-100); }
.mcr__kind-btn--active {
  border-color: #1b5e20; background: rgba(27,94,32,.08);
  color: #1b5e20;
}

/* Capacity info */
.mcr__capacity-info {
  background: #f0fdf4; border: 1px solid #bbf7d0;
  border-radius: 9px; padding: .65rem .9rem;
  font-size: .8rem; color: #14532d;
  display: flex; align-items: center; gap: .5rem;
}

/* Footer */
.mcr__footer {
  display: flex; justify-content: flex-end; gap: .75rem;
  padding: 1rem 1.4rem;
  border-top: 1px solid var(--c-slate-100);
  position: sticky; bottom: 0; background: #fff;
}
.mcr__btn-primary {
  display: inline-flex; align-items: center; gap: .4rem;
  background: var(--brand-primary, #1b5e20); color: #fff;
  border: none; padding: .65rem 1.25rem; border-radius: 9px;
  font-size: .875rem; font-weight: 700; cursor: pointer;
  transition: background .15s;
}
.mcr__btn-primary:hover:not(:disabled) { background: #144a18; }
.mcr__btn-primary:disabled { opacity: .55; cursor: not-allowed; }
.mcr__btn-ghost {
  background: transparent; color: var(--c-slate-500);
  border: 1.5px solid var(--c-slate-200); padding: .65rem 1.1rem;
  border-radius: 9px; font-size: .875rem; font-weight: 600;
  cursor: pointer; transition: all .15s;
}
.mcr__btn-ghost:hover:not(:disabled) { background: var(--c-slate-50); }
</style>
