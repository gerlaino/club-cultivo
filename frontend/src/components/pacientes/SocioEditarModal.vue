<template>
  <Teleport to="body">
    <Transition name="sem-modal">
      <div v-if="open" class="sem__overlay" @click.self="emit('update:open', false)">
        <div class="sem__modal">
          <div class="sem__header">
            <h2 class="sem__title">Editar paciente</h2>
            <button class="sem__close" @click="emit('update:open', false)"><X :size="18" /></button>
          </div>
          <div class="sem__body">
            <div class="sem__grid">
              <div class="sem__field">
                <label class="sem__label">Nombre</label>
                <input v-model="editForm.nombre" class="sem__input" type="text" />
              </div>
              <div class="sem__field">
                <label class="sem__label">Apellido</label>
                <input v-model="editForm.apellido" class="sem__input" type="text" />
              </div>
              <div class="sem__field">
                <label class="sem__label">DNI</label>
                <input v-model="editForm.dni" class="sem__input" type="text" />
              </div>
              <div class="sem__field">
                <label class="sem__label">Fecha de nacimiento</label>
                <AppDatePicker v-model="editForm.fecha_nacimiento" />
              </div>
              <div class="sem__field">
                <label class="sem__label">Email</label>
                <input v-model="editForm.email" class="sem__input" type="email" />
              </div>
              <div class="sem__field">
                <label class="sem__label">Teléfono</label>
                <input v-model="editForm.telefono" class="sem__input" type="tel" />
              </div>
              <div class="sem__field">
                <label class="sem__label">N° REPROCANN</label>
                <input v-model="editForm.reprocann_numero" class="sem__input" type="text" />
              </div>
              <div class="sem__field">
                <label class="sem__label">Vencimiento REPROCANN</label>
                <AppDatePicker v-model="editForm.reprocann_vencimiento" />
              </div>
              <div class="sem__field sem__field--full">
                <label class="sem__label" style="margin-bottom:.4rem">Estado REPROCANN</label>
                <div class="sem__repro-estados">
                  <button
                    v-for="opt in REPROCANN_ESTADOS" :key="opt.value"
                    type="button"
                    class="sem__repro-btn"
                    :style="editForm.reprocann_estado === opt.value ? { background: opt.bg, borderColor: opt.color, color: opt.color } : {}"
                    @click="editForm.reprocann_estado = opt.value"
                  >{{ opt.label }}</button>
                </div>
              </div>
              <div v-if="isAdmin" class="sem__field sem__field--full">
                <label class="sem__label" style="margin-bottom:.4rem">
                  Descuento por defecto
                  <span class="sem__opt">en dispensaciones — opcional</span>
                </label>
                <div class="sem__limit-wrap">
                  <input
                    v-model.number="editForm.descuento_porcentaje"
                    class="sem__input sem__input--limit"
                    type="number" step="1" min="0" max="100"
                    placeholder="0"
                  />
                  <span class="sem__limit-unit">%</span>
                </div>
                <span class="sem__hint">Se aplica automáticamente al calcular el precio en cada dispensación. 0 = sin descuento.</span>
              </div>
              <div class="sem__field sem__field--full">
                <label class="sem__label" style="margin-bottom:.4rem">
                  Domicilio <span class="sem__opt">para entregas a domicilio — opcional</span>
                </label>
                <div class="sem__domicilio-grid">
                  <input v-model.trim="editForm.domicilio_calle"  class="sem__input" type="text" placeholder="Calle" style="grid-column: span 2" />
                  <input v-model.trim="editForm.domicilio_altura" class="sem__input" type="text" placeholder="Altura" />
                  <input v-model.trim="editForm.domicilio_piso"   class="sem__input" type="text" placeholder="Piso" />
                  <input v-model.trim="editForm.domicilio_depto"  class="sem__input" type="text" placeholder="Depto" />
                  <input v-model.trim="editForm.domicilio_barrio" class="sem__input" type="text" placeholder="Barrio" />
                  <input v-model.trim="editForm.domicilio_ciudad" class="sem__input" type="text" placeholder="Ciudad" style="grid-column: span 2" />
                </div>
              </div>
              <div class="sem__field sem__field--full">
                <label class="sem__label">
                  <input v-model="editForm.es_paciente" type="checkbox" class="sem__check" />
                  En tratamiento activo
                </label>
              </div>
            </div>
            <div v-if="editError" class="sem__error">{{ editError }}</div>
          </div>
          <div class="sem__footer">
            <button class="sem__btn-ghost" :disabled="editSaving" @click="emit('update:open', false)">Cancelar</button>
            <button class="sem__btn-primary" :disabled="editSaving" @click="doSave">
              <Save :size="13" :stroke-width="2" />
              {{ editSaving ? 'Guardando…' : 'Guardar cambios' }}
            </button>
          </div>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>

<script setup>
import { watch, computed } from 'vue'
import AppDatePicker from '../ui/AppDatePicker.vue'
import { X, Save } from 'lucide-vue-next'
import { useSocioEditar, REPROCANN_ESTADOS } from '../../composables/useSocioEditar.js'
import { useAuthStore } from '../../stores/auth.js'

const props = defineProps({
  open:    { type: Boolean, default: false },
  socioId: { type: Number, required: true },
})
const emit = defineEmits(['update:open', 'saved'])

const { editForm, editSaving, editError, openEdit, saveEdit } = useSocioEditar(props.socioId)

const auth    = useAuthStore()
const isAdmin = computed(() => ['admin', 'super_admin'].includes(auth.user?.role))

watch(() => props.open, (v) => { if (v) openEdit() })

async function doSave() {
  await saveEdit()
  if (!editError.value) {
    emit('saved')
    emit('update:open', false)
  }
}
</script>

<style scoped>
.sem__overlay { position: fixed; inset: 0; background: rgba(15,23,42,.45); display: flex; align-items: center; justify-content: center; z-index: 800; padding: 1rem; }
.sem__modal { background: #fff; border-radius: 16px; width: 100%; max-width: 600px; max-height: 90vh; display: flex; flex-direction: column; box-shadow: 0 20px 60px rgba(0,0,0,.2); overflow-y: auto; }
.sem__header { display: flex; align-items: center; justify-content: space-between; padding: 1.25rem 1.5rem; border-bottom: 1px solid #f1f5f9; position: sticky; top: 0; background: #fff; z-index: 1; }
.sem__title { font-size: 1rem; font-weight: 700; margin: 0; color: #0f172a; }
.sem__close { background: none; border: none; color: #94a3b8; cursor: pointer; padding: .25rem; border-radius: 6px; display: flex; transition: all .15s; }
.sem__close:hover { background: #f1f5f9; color: #0f172a; }
.sem__body { padding: 1.5rem; flex: 1; }
.sem__grid { display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; }
@media (max-width: 480px) { .sem__grid { grid-template-columns: 1fr; } }
.sem__field { display: flex; flex-direction: column; gap: .4rem; }
.sem__field--full { grid-column: 1 / -1; }
.sem__domicilio-grid { display: grid; grid-template-columns: repeat(4, 1fr); gap: .5rem; }
@media (max-width: 480px) { .sem__domicilio-grid { grid-template-columns: 1fr 1fr; } }
.sem__label { font-size: .75rem; font-weight: 600; color: #64748b; display: flex; align-items: center; gap: .4rem; }
.sem__input { padding: .55rem .75rem; border: 1.5px solid #e2e8f0; border-radius: 8px; font-size: .875rem; color: #0f172a; outline: none; transition: border-color .15s; width: 100%; box-sizing: border-box; }
.sem__input:focus { border-color: #1b5e20; }
.sem__check { width: 15px; height: 15px; accent-color: #1b5e20; }
.sem__repro-estados { display: flex; gap: .4rem; flex-wrap: wrap; }
.sem__repro-btn { padding: .4rem .8rem; border-radius: 7px; border: 1.5px solid #e2e8f0; background: #f8fafc; color: #64748b; font-size: .75rem; font-weight: 600; cursor: pointer; transition: all .15s; }
.sem__repro-btn:hover { border-color: #94a3b8; }
.sem__opt { font-size: .68rem; font-weight: 400; color: #94a3b8; text-transform: none; letter-spacing: 0; margin-left: .35rem; }
.sem__limit-wrap { display: flex; align-items: center; gap: .4rem; }
.sem__input--limit { max-width: 140px; }
.sem__limit-unit { font-size: .8rem; font-weight: 600; color: #64748b; white-space: nowrap; }
.sem__hint { font-size: .72rem; color: #94a3b8; margin-top: .2rem; display: block; }
.sem__error { margin-top: .875rem; padding: .75rem 1rem; background: #fef2f2; border: 1px solid #fecaca; border-radius: 8px; font-size: .8rem; color: #dc2626; }
.sem__footer { display: flex; justify-content: flex-end; gap: .75rem; padding: 1.25rem 1.5rem; border-top: 1px solid #f1f5f9; position: sticky; bottom: 0; background: #fff; }
.sem__btn-primary { display: inline-flex; align-items: center; gap: .4rem; background: #1b5e20; color: #fff; border: none; padding: .6rem 1.1rem; border-radius: 9px; font-size: .82rem; font-weight: 600; cursor: pointer; transition: background .15s; }
.sem__btn-primary:hover:not(:disabled) { background: #144a18; }
.sem__btn-primary:disabled { opacity: .5; cursor: not-allowed; }
.sem__btn-ghost { display: inline-flex; align-items: center; gap: .4rem; background: none; color: #475569; border: 1.5px solid #e2e8f0; padding: .6rem 1.1rem; border-radius: 9px; font-size: .82rem; font-weight: 600; cursor: pointer; transition: all .15s; }
.sem__btn-ghost:hover { border-color: #94a3b8; }
.sem__btn-ghost:disabled { opacity: .5; cursor: not-allowed; }
.sem-modal-enter-active, .sem-modal-leave-active { transition: opacity .2s; }
.sem-modal-enter-from, .sem-modal-leave-to { opacity: 0; pointer-events: none; }
.sem-modal-enter-active .sem__modal, .sem-modal-leave-active .sem__modal { transition: transform .2s; }
.sem-modal-enter-from .sem__modal, .sem-modal-leave-to .sem__modal { transform: translateY(-12px); }
</style>
