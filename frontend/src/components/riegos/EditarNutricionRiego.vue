<template>
  <Teleport to="body">
    <div class="enr__overlay" v-modal="{ cerrar: () => emit('cerrar'), sucio: () => tocado }">
      <div class="enr" role="dialog" aria-modal="true" aria-labelledby="enr-titulo">
        <header class="enr__head">
          <h3 id="enr-titulo" class="enr__titulo">Corregir los nutrientes del riego</h3>
          <button type="button" class="enr__x" aria-label="Cerrar" @click="emit('cerrar')"><i class="bi bi-x-lg"></i></button>
        </header>

        <div class="enr__body">
          <div v-if="cargando" class="enr__cargando"><DsSpinner :size="18" /></div>
          <p v-else-if="error" class="enr__error">{{ error }}</p>
          <!-- Lo que el backend va a rechazar no se ofrece: se dice por qué. -->
          <p v-else-if="bloqueo" class="enr__bloqueo"><i class="bi bi-lock"></i> {{ bloqueo }}</p>
          <template v-else>
            <p class="enr__ayuda">
              Lo que se había descontado vuelve {{ esPersonal ? 'a tus nutrientes' : 'al depósito' }} y se
              descuenta lo que pongas acá.
              <template v-if="!esPersonal && lotes.length > 1">Corrige el riego entero: {{ lotes.join(', ') }}.</template>
            </p>
            <InsumosAplicados v-model="nutricion" uso="riego" :sala-id="salaId" @update:model-value="tocado = true" />
          </template>
        </div>

        <footer class="enr__foot">
          <button type="button" class="enr__btn" @click="emit('cerrar')">Cancelar</button>
          <button v-if="!cargando && !bloqueo && !error" type="button" class="enr__btn enr__btn--primary"
                  :disabled="guardando" @click="guardar">
            <DsSpinner v-if="guardando" :size="14" /><span v-else>Guardar</span>
          </button>
        </footer>
      </div>
    </div>
  </Teleport>
</template>

<script setup>
// CORREGIR LOS NUTRIENTES DE UN RIEGO YA GUARDADO (13-oct-2026). Uno solo para los tres lugares
// donde se ve un riego: el historial del lote, la ficha de la planta en la compu y en el
// teléfono. El backend deshace lo aplicado (vuelve al depósito) y aplica lo nuevo
// (`Nutricion::Editar`); acá sólo se elige qué y cuánto, con el mismo editor del riego.
import { ref, onMounted } from 'vue'
import DsSpinner from '../../design-system/components/Spinner.vue'
import InsumosAplicados from '../camas/InsumosAplicados.vue'
import { getNutricionRiego, updateNutricionRiego } from '../../lib/api.js'
import { useToast } from '../../composables/useToast.js'
import { useUsoPersonal } from '../../composables/useUsoPersonal.js'

const props = defineProps({
  loteId:     { type: [Number, String], required: true },
  registroId: { type: [Number, String], required: true },
})
const emit = defineEmits(['cerrar', 'guardado'])
const toast = useToast()
const { esPersonal } = useUsoPersonal()

const cargando  = ref(true)
const guardando = ref(false)
const error     = ref(null)
const bloqueo   = ref(null)
const nutricion = ref({})
const salaId    = ref(null)
const lotes     = ref([])
const tocado    = ref(false)

onMounted(async () => {
  try {
    const { data } = await getNutricionRiego(props.loteId, props.registroId)
    nutricion.value = data.nutricion || { modo: 'ninguno', items: [] }
    salaId.value    = data.sala_id
    lotes.value     = data.lotes || []
    bloqueo.value   = data.bloqueo
  } catch (e) {
    error.value = e?.response?.data?.error || 'No se pudo abrir el riego.'
  } finally { cargando.value = false }
})

async function guardar () {
  guardando.value = true
  try {
    const { data } = await updateNutricionRiego(props.loteId, props.registroId, nutricion.value)
    const faltan = (data.faltantes || []).map(f => f.nombre)
    toast.success(faltan.length ? `Riego corregido · faltó stock de ${faltan.join(', ')}` : 'Riego corregido')
    emit('guardado')
  } catch (e) {
    toast.error(e?.response?.data?.error || 'No se pudo corregir el riego.')
  } finally { guardando.value = false }
}
</script>

<style scoped>
.enr__overlay { position: fixed; inset: 0; background: rgba(15, 23, 42, .45); display: flex; align-items: center; justify-content: center; padding: 16px; z-index: 1200; }
.enr { background: #fff; border-radius: 14px; width: 100%; max-width: 520px; max-height: 90vh; display: flex; flex-direction: column; }
.enr__head { display: flex; align-items: center; justify-content: space-between; padding: 14px 18px; border-bottom: 1px solid var(--c-slate-200); }
.enr__titulo { margin: 0; font-size: var(--fs-16, 1rem); font-weight: 700; color: var(--c-ink-900); }
.enr__x { border: 0; background: none; font-size: 1rem; cursor: pointer; color: var(--c-ink-500); }
.enr__body { padding: 16px 18px; overflow-y: auto; display: flex; flex-direction: column; gap: 12px; }
.enr__ayuda { margin: 0; font-size: var(--fs-13); color: var(--c-ink-500); }
.enr__bloqueo { margin: 0; font-size: var(--fs-14); color: var(--c-amber-500); }
.enr__error { margin: 0; font-size: var(--fs-14); color: var(--c-rust-600); }
.enr__cargando { display: flex; justify-content: center; padding: 24px; }
.enr__foot { display: flex; justify-content: flex-end; gap: 8px; padding: 12px 18px; border-top: 1px solid var(--c-slate-200); }
.enr__btn { padding: 8px 14px; border-radius: 8px; border: 1px solid var(--c-slate-200); background: #fff; font: inherit; font-weight: 600; cursor: pointer; }
.enr__btn--primary { background: var(--c-leaf-800); color: #fff; border-color: transparent; }
.enr__btn:disabled { opacity: .6; cursor: default; }
@media (max-width: 480px) { .enr__overlay { align-items: flex-end; padding: 0; } .enr { border-radius: 14px 14px 0 0; max-height: 92vh; } }
</style>
