<template>
  <div class="spa" data-testid="precio-autocultivo">
    <span class="spa__lbl">Autocultivo · suscripción mensual</span>
    <template v-if="!editando">
      <strong class="spa__v">{{ monto ? formatARS(monto) : 'sin precio' }}</strong>
      <button type="button" class="sa-btn sa-btn--chico" @click="editar">{{ monto ? 'Cambiar' : 'Cargar precio' }}</button>
    </template>
    <template v-else>
      <input v-model.number="nuevo" type="number" min="1" step="100" class="spa__input" aria-label="Precio mensual del autocultivo en pesos" />
      <button type="button" class="sa-btn sa-btn--chico" @click="editando = false">Cancelar</button>
      <button type="button" class="sa-btn sa-btn--chico sa-btn--primario" :disabled="guardando || !(nuevo > 0)" @click="guardar">Guardar</button>
    </template>
    <span v-if="editando" class="spa__nota">Rige para las suscripciones nuevas; las que ya cobran siguen con su monto.</span>
    <span v-else-if="!mpConfigurado" class="spa__nota spa__nota--warn">Mercado Pago sin configurar: nadie puede suscribirse todavía.</span>
  </div>
</template>

<script setup>
// El precio fijo del autocultivo en pesos (12-oct-2026): lo carga super admin y es lo que cobra
// la suscripción de Mercado Pago a quien se suscribe solo.
import { ref, onMounted } from 'vue'
import { getPrecioAutocultivo, guardarPrecioAutocultivo } from '../../lib/api.js'
import { formatARS } from '../../lib/formatters.js'
import { useToast } from '../../composables/useToast.js'

const toast = useToast()
const monto = ref(null)
const mpConfigurado = ref(true)
const editando = ref(false)
const nuevo = ref(null)
const guardando = ref(false)

onMounted(async () => {
  try { const { data } = await getPrecioAutocultivo(); monto.value = data.monto_ars; mpConfigurado.value = data.mp_configurado } catch { /* la lista se ve igual */ }
})
function editar() { nuevo.value = monto.value; editando.value = true }
async function guardar() {
  guardando.value = true
  try { monto.value = (await guardarPrecioAutocultivo(nuevo.value)).data.monto_ars; editando.value = false; toast.success('Precio guardado') }
  catch (e) { toast.error(e?.response?.data?.errors?.join(', ') || 'No se pudo guardar') }
  finally { guardando.value = false }
}
</script>

<style scoped>
.spa { display: flex; flex-wrap: wrap; align-items: center; gap: .5rem .75rem; padding: .6rem .9rem; border: 1px solid var(--c-slate-200); border-radius: 12px; background: #fff; }
.spa__lbl { font-size: .8rem; font-weight: 600; color: var(--c-slate-600); }
.spa__v { font-size: .95rem; color: var(--c-ink-900); }
.spa__input { width: 130px; border: 1px solid var(--c-slate-300); border-radius: 8px; padding: .35rem .6rem; font-size: .85rem; }
.spa__nota { flex-basis: 100%; font-size: .75rem; color: var(--c-slate-500); }
.spa__nota--warn { color: var(--c-gold-500); }
</style>
