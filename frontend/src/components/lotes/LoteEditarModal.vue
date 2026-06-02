<template>
  <Teleport to="body">
    <div v-if="open" class="lem__overlay">
      <div class="lem__modal">
        <div class="lem__header">
          <div>
            <h3 class="lem__title">✏️ Editar lote</h3>
            <p class="lem__sub">{{ lote?.codigo }}</p>
          </div>
          <button class="lem__close" @click="emit('update:open', false)"><i class="bi bi-x-lg"></i></button>
        </div>
        <div class="lem__body">
          <div v-if="editLoteError" class="lem__alert">{{ editLoteError }}</div>
          <div class="lem__grid">
            <div class="lem__field">
              <label class="lem__label">Código <span class="lem__note">autogenerado · inmutable</span></label>
              <div class="lem__input lem__input--readonly">{{ editLoteForm.codigo }}</div>
            </div>
            <div class="lem__field">
              <label class="lem__label">Fecha de inicio</label>
              <input type="date" class="lem__input" v-model="editLoteForm.start_date" />
            </div>
            <div class="lem__field">
              <label class="lem__label">Genética / Variedad</label>
              <select class="lem__input" v-model="editLoteForm.genetica_id">
                <option value="">Sin especificar</option>
                <option v-for="g in geneticas" :key="g.id" :value="g.id">
                  {{ g.nombre }}{{ g.registrada_inase ? ' 🏛️' : '' }} — {{ g.tipo }}
                </option>
              </select>
            </div>
            <div class="lem__field">
              <label class="lem__label">Tipo de cultivo</label>
              <select class="lem__input" v-model="editLoteForm.grow_type">
                <option value="">Sin especificar</option>
                <option value="sustrato">Sustrato</option>
                <option value="hidroponia">Hidroponia</option>
                <option value="aeroponia">Aeroponia</option>
              </select>
            </div>
            <div class="lem__field">
              <label class="lem__label">Tipo de luz</label>
              <select class="lem__input" v-model="editLoteForm.light_type">
                <option value="">Sin especificar</option>
                <option value="led">LED</option>
                <option value="hps">HPS</option>
                <option value="cmh">CMH</option>
                <option value="natural">Natural</option>
                <option value="mixta">Mixta</option>
              </select>
            </div>
            <div class="lem__field">
              <label class="lem__label">Semanas de floración</label>
              <label class="lem__check-row">
                <input type="checkbox" v-model="editLoteForm.tiene_semanas" />
                <span>Definir semanas</span>
              </label>
              <input v-if="editLoteForm.tiene_semanas" type="number" min="1" max="24" step="1"
                     class="lem__input" v-model.number="editLoteForm.semanas_floracion"
                     placeholder="Ej: 9" style="margin-top:.35rem" />
            </div>
            <div class="lem__field">
              <label class="lem__label">Tamaño de maceta (L)</label>
              <select class="lem__input" v-model="editLoteForm.tamanio_maceta">
                <option value="">Sin especificar</option>
                <option value="1">1 litro</option>
                <option value="3">3 litros</option>
                <option value="5">5 litros</option>
                <option value="7">7 litros</option>
                <option value="10">10 litros</option>
                <option value="12">12 litros</option>
                <option value="15">15 litros</option>
              </select>
            </div>
            <div class="lem__field lem__field--full">
              <label class="lem__label">Notas</label>
              <textarea class="lem__input lem__textarea" rows="3" v-model.trim="editLoteForm.notes"
                        placeholder="Observaciones internas…"></textarea>
            </div>
          </div>
        </div>
        <div class="lem__footer">
          <button class="lem__btn-ghost" :disabled="savingEditLote" @click="emit('update:open', false)">Cancelar</button>
          <button class="lem__btn-primary" :disabled="savingEditLote" @click="doSave">
            <DsSpinner v-if="savingEditLote" :size="14" />
            <i v-else class="bi bi-check-lg"></i>Guardar cambios
          </button>
        </div>
      </div>
    </div>
  </Teleport>
</template>

<script setup>
import { watch } from 'vue'
import { useLoteEditar } from '../../composables/useLoteEditar.js'
import DsSpinner from '../../design-system/components/Spinner.vue'

const props = defineProps({
  open:   { type: Boolean, default: false },
  lote:   { type: Object,  default: null },
  loteId: { type: Number,  required: true },
})
const emit = defineEmits(['update:open', 'saved'])

const {
  geneticas, editLoteForm, editLoteError, savingEditLote,
  cargarGeneticas, openEditLote, saveEditLote,
} = useLoteEditar(props.loteId)

watch(() => props.open, async (v) => {
  if (v) { await cargarGeneticas(); openEditLote() }
})

async function doSave() {
  await saveEditLote()
  if (!editLoteError.value) { emit('update:open', false); emit('saved') }
}
</script>

<style scoped>
.lem__overlay { position: fixed; inset: 0; background: rgba(0,0,0,.4); display: flex; align-items: center; justify-content: center; z-index: 1050; padding: 1rem; backdrop-filter: blur(3px); }
.lem__modal { background: #fff; border-radius: 16px; width: 100%; max-width: 600px; max-height: 92vh; overflow-y: auto; box-shadow: 0 24px 64px rgba(27,94,32,.15); display: flex; flex-direction: column; }
.lem__header { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; padding: 1.25rem 1.5rem 1rem; border-bottom: 1px solid #e8f0e9; position: sticky; top: 0; background: #fff; z-index: 1; }
.lem__title { font-size: 1.05rem; font-weight: 700; color: #1a1a1a; margin: 0; }
.lem__sub { font-size: .78rem; color: #60725d; margin: .2rem 0 0; }
.lem__close { background: #e8f5e9; border: none; width: 30px; height: 30px; border-radius: 8px; cursor: pointer; display: flex; align-items: center; justify-content: center; color: #60725d; transition: all .15s; flex-shrink: 0; }
.lem__close:hover { background: #c8e6c9; }
.lem__body { padding: 1.25rem 1.5rem; flex: 1; }
.lem__footer { display: flex; justify-content: flex-end; gap: .75rem; padding: 1rem 1.5rem; border-top: 1px solid #e8f0e9; position: sticky; bottom: 0; background: #fff; }
.lem__grid { display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; }
@media (max-width: 480px) { .lem__grid { grid-template-columns: 1fr; } }
.lem__field { display: flex; flex-direction: column; gap: .35rem; }
.lem__field--full { grid-column: 1 / -1; }
.lem__label { font-size: .78rem; font-weight: 700; color: #374151; text-transform: uppercase; letter-spacing: .04em; }
.lem__note { font-size: .68rem; font-weight: 500; color: #94a3b8; text-transform: none; letter-spacing: 0; margin-left: .3rem; }
.lem__input { background: #f4f8f4; border: 1.5px solid #d4e6d4; border-radius: 8px; padding: .6rem .85rem; font-size: .875rem; color: #1a1a1a; width: 100%; box-sizing: border-box; transition: border .15s; }
.lem__input:focus { outline: none; border-color: #1b5e20; background: #fff; }
.lem__input--readonly { color: #64748b; cursor: default; background: #f8fafc; font-family: monospace; }
.lem__textarea { resize: vertical; min-height: 60px; }
.lem__check-row { display: flex; align-items: center; gap: .5rem; font-size: .82rem; color: #374151; cursor: pointer; user-select: none; }
.lem__check-row input[type="checkbox"] { width: 15px; height: 15px; accent-color: #1b5e20; cursor: pointer; }
.lem__alert { background: #fef2f2; border: 1px solid #fecaca; color: #dc2626; padding: .75rem 1rem; border-radius: 8px; font-size: .85rem; margin-bottom: 1rem; }
.lem__btn-primary { display: inline-flex; align-items: center; gap: .4rem; background: #1b5e20; color: #fff; border: none; padding: .6rem 1.25rem; border-radius: 8px; font-size: .875rem; font-weight: 600; cursor: pointer; transition: background .15s; }
.lem__btn-primary:hover { background: #104417; }
.lem__btn-primary:disabled { opacity: .6; cursor: not-allowed; }
.lem__btn-ghost { background: transparent; color: #60725d; border: 1px solid #d4e6d4; padding: .6rem 1.1rem; border-radius: 8px; font-size: .875rem; font-weight: 500; cursor: pointer; transition: all .15s; }
.lem__btn-ghost:hover { background: #f0fdf4; }
.lem__btn-ghost:disabled { opacity: .5; cursor: not-allowed; }
</style>
