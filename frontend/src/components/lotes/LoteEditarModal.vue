<template>
  <Teleport to="body">
    <div v-if="open" class="lem__overlay" @click.self="emit('update:open', false)">
      <div class="lem__modal">
        <div class="lem__header">
          <div>
            <h3 class="lem__title">Editar lote</h3>
            <p v-if="lote?.codigo" class="lem__sub">{{ lote.codigo }}</p>
          </div>
          <button class="lem__close" @click="emit('update:open', false)"><i class="bi bi-x-lg"></i></button>
        </div>

        <div class="lem__body">
          <div v-if="editLoteError" class="lem__alert">{{ editLoteError }}</div>

          <!-- Código (readonly) -->
          <div class="lem__field">
            <label class="lem__label">Código</label>
            <input type="text" class="lem__input lem__input--ro" :value="editLoteForm.codigo || '—'" readonly />
            <span class="lem__hint">Asignado automáticamente · no editable</span>
          </div>

          <div class="lem__grid">
            <div class="lem__field">
              <label class="lem__label">Estado</label>
              <select class="lem__input" v-model="editLoteForm.estado">
                <option value="semilla">Germinación / Plántula</option>
                <option value="esqueje">Esqueje</option>
                <option value="vegetativo">Vegetativo</option>
                <option value="floracion">Floración</option>
                <option value="cosecha">Cosechado</option>
                <option v-for="e in ESTADOS_EXTRA" :key="e.v" :value="e.v">{{ e.l }}</option>
              </select>
            </div>

            <div class="lem__field">
              <label class="lem__label">Cantidad de plantas</label>
              <input type="number" min="0" max="5000" step="1" class="lem__input"
                     v-model.number="editLoteForm.plants_count" />
            </div>
          </div>

          <!-- Aviso: editar el número no toca las plantas reales -->
          <div v-if="cantidadCambiada" class="lem__warn">
            <i class="bi bi-exclamation-triangle-fill"></i>
            <span>
              Cambiaste la cantidad de <strong>{{ lote?.plants_count ?? '—' }}</strong> a <strong>{{ editLoteForm.plants_count }}</strong>.
              Esto solo cambia el número del lote — <strong>no agrega ni elimina plantas</strong>.
              Agregá o eliminá las plantas (con su QR) desde la sección <strong>Plantas</strong> del lote para que coincidan.
            </span>
          </div>

          <div class="lem__grid">

            <div class="lem__field">
              <label class="lem__label">Genética / Variedad</label>
              <select class="lem__input" v-model="editLoteForm.genetica_id" :disabled="!geneticas.length">
                <option value="">{{ geneticas.length ? 'Sin especificar' : 'Sin genéticas disponibles' }}</option>
                <option v-for="g in geneticas" :key="g.id" :value="g.id">{{ g.nombre }}{{ g.registrada_inase ? ' 🏛️' : '' }} — {{ g.tipo }}</option>
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
              <label class="lem__label">Tamaño de maceta</label>
              <select class="lem__input" v-model="editLoteForm.tamanio_maceta">
                <option value="">Sin especificar</option>
                <option value="0.5">Vaso (0.5L)</option>
                <option value="1">1 litro</option><option value="3">3 litros</option>
                <option value="5">5 litros</option><option value="7">7 litros</option>
                <option value="10">10 litros</option><option value="12">12 litros</option>
                <option value="15">15 litros</option>
              </select>
            </div>

            <div class="lem__field">
              <label class="lem__label">Tipo de luz</label>
              <select class="lem__input" v-model="editLoteForm.light_type">
                <option value="">Sin especificar</option>
                <option value="led">LED</option><option value="hps">HPS</option>
                <option value="cmh">CMH</option><option value="natural">Natural</option><option value="mixta">Mixta</option>
              </select>
            </div>

            <div class="lem__field">
              <label class="lem__label">Semanas de floración <span class="lem__opt">estimadas</span></label>
              <input type="number" min="1" max="24" step="1" class="lem__input"
                     v-model.number="editLoteForm.semanas_floracion"
                     placeholder="Ej: 9" @input="editLoteForm.tiene_semanas = true" />
            </div>

            <div class="lem__field lem__field--full">
              <label class="lem__label">Notas</label>
              <textarea class="lem__input lem__textarea" rows="2" v-model.trim="editLoteForm.notes"
                        placeholder="Observaciones internas…"></textarea>
            </div>
          </div>

          <!-- Estado e historia: fechas de inicio de cada fase -->
          <div class="lem__seccion-titulo">📅 Fechas de inicio por fase</div>
          <div class="lem__grid">
            <div class="lem__field">
              <label class="lem__label">Inicio <span class="lem__opt">germinación / esqueje</span></label>
              <AppDatePicker v-model="editLoteForm.start_date" />
            </div>
            <div class="lem__field">
              <label class="lem__label">Inicio vegetativo</label>
              <AppDatePicker v-model="editLoteForm.fecha_vegetativo" />
            </div>
            <div class="lem__field">
              <label class="lem__label">Inicio floración</label>
              <AppDatePicker v-model="editLoteForm.fecha_floracion" />
            </div>
            <div class="lem__field">
              <label class="lem__label">Cosechado</label>
              <AppDatePicker v-model="editLoteForm.fecha_cosecha" />
            </div>
          </div>
          <div class="lem__nota">
            <i class="bi bi-info-circle"></i>
            Corrección del registro: ajusta el estado y las fechas históricas del lote (alimentan los días por fase de la analítica). No mueve plantas entre salas ni genera dispensaciones.
          </div>
        </div>

        <div class="lem__footer">
          <button class="lem__btn-ghost" :disabled="savingEditLote" @click="emit('update:open', false)">Cancelar</button>
          <button class="lem__btn-primary" :disabled="savingEditLote" @click="doSave">
            <DsSpinner v-if="savingEditLote" :size="14" />
            <template v-else><i class="bi bi-check-lg"></i> Guardar cambios</template>
          </button>
        </div>
      </div>
    </div>
  </Teleport>
</template>

<script setup>
import { watch, computed } from 'vue'
import { useLoteEditar } from '../../composables/useLoteEditar.js'
import DsSpinner from '../../design-system/components/Spinner.vue'
import AppDatePicker from '../ui/AppDatePicker.vue'

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

const cantidadCambiada = computed(() =>
  editLoteForm.value.plants_count != null &&
  Number(editLoteForm.value.plants_count) !== Number(props.lote?.plants_count)
)

// Si el lote ya está en un estado post-cosecha, lo mostramos para no perderlo
// (pero las opciones editables son las fases de cultivo).
const ESTADOS_EXTRA = computed(() => {
  const base = ['semilla', 'esqueje', 'vegetativo', 'floracion', 'cosecha']
  const cur = editLoteForm.value.estado
  const labels = { en_manicura: 'En manicura', secado: 'Secado / Manicura', manicura_pendiente: 'Manicura pendiente', curado: 'Curado', finalizado: 'Finalizado' }
  return (cur && !base.includes(cur)) ? [{ v: cur, l: labels[cur] || cur }] : []
})

watch(() => props.open, async (v) => {
  if (v) { await cargarGeneticas(); openEditLote() }
})

async function doSave() {
  // semanas_floracion: si quedó vacío, no definimos semanas.
  editLoteForm.value.tiene_semanas = !!(Number(editLoteForm.value.semanas_floracion) > 0)
  await saveEditLote()
  if (!editLoteError.value) { emit('update:open', false); emit('saved') }
}
</script>

<style scoped>
.lem__overlay { position: fixed; inset: 0; background: rgba(15,23,42,.45); z-index: 1050; display: flex; align-items: center; justify-content: center; padding: 1rem; }
.lem__modal { background: #fff; border-radius: 16px; width: 100%; max-width: 620px; max-height: 92vh; display: flex; flex-direction: column; box-shadow: 0 20px 60px rgba(0,0,0,.2); }
.lem__header { display: flex; align-items: flex-start; justify-content: space-between; padding: 1.1rem 1.4rem; border-bottom: 1px solid #f1f5f9; }
.lem__title { font-size: 1.05rem; font-weight: 800; color: #0f172a; margin: 0; }
.lem__sub { font-size: .8rem; color: #64748b; margin: .2rem 0 0; }
.lem__close { background: none; border: none; color: #94a3b8; cursor: pointer; font-size: 1rem; }
.lem__body { padding: 1.2rem 1.4rem; overflow-y: auto; }
.lem__alert { background: #fef2f2; border: 1px solid #fecaca; color: #b91c1c; border-radius: 8px; padding: .55rem .8rem; font-size: .82rem; margin-bottom: .9rem; }
.lem__grid { display: grid; grid-template-columns: 1fr 1fr; gap: .85rem; }
@media (max-width: 520px) { .lem__grid { grid-template-columns: 1fr; } }
.lem__field { display: flex; flex-direction: column; gap: .3rem; margin-bottom: .85rem; }
.lem__grid .lem__field { margin-bottom: 0; }
.lem__field--full { grid-column: 1 / -1; }
.lem__label { font-size: .74rem; font-weight: 700; color: #64748b; }
.lem__opt { font-weight: 400; color: #94a3b8; }
.lem__input { padding: .5rem .7rem; border: 1.5px solid #e2e8f0; border-radius: 8px; font-size: .85rem; color: #0f172a; outline: none; width: 100%; box-sizing: border-box; }
.lem__input:focus { border-color: #15803d; }
.lem__input--ro { opacity: .75; cursor: default; background: #f8fafc; font-family: monospace; }
.lem__textarea { resize: vertical; }
.lem__hint { font-size: .72rem; color: #94a3b8; }
.lem__warn { display: flex; gap: .5rem; align-items: flex-start; background: #fffbeb; border: 1px solid #fde68a; color: #92400e; border-radius: 9px; padding: .6rem .8rem; font-size: .78rem; line-height: 1.4; margin: .85rem 0; }
.lem__warn i { margin-top: 1px; flex-shrink: 0; }
.lem__seccion-titulo { font-size: .8rem; font-weight: 800; color: #0f172a; margin: 1.1rem 0 .6rem; padding-top: .9rem; border-top: 1px solid #f1f5f9; }
.lem__nota { display: flex; gap: .5rem; align-items: flex-start; background: #eff6ff; border: 1px solid #bfdbfe; color: #1e40af; border-radius: 9px; padding: .55rem .8rem; font-size: .74rem; line-height: 1.4; margin-top: .7rem; }
.lem__nota i { margin-top: 1px; flex-shrink: 0; }
.lem__footer { display: flex; justify-content: flex-end; gap: .6rem; padding: 1rem 1.4rem; border-top: 1px solid #f1f5f9; }
.lem__btn-ghost { background: none; border: 1.5px solid #cbd5e1; color: #64748b; border-radius: 9px; padding: .5rem 1rem; font-size: .85rem; font-weight: 700; cursor: pointer; }
.lem__btn-primary { display: inline-flex; align-items: center; gap: .4rem; background: #15803d; color: #fff; border: none; border-radius: 9px; padding: .5rem 1.2rem; font-size: .85rem; font-weight: 700; cursor: pointer; }
.lem__btn-primary:disabled, .lem__btn-ghost:disabled { opacity: .6; cursor: wait; }
</style>
