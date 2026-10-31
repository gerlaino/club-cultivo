<template>
  <div class="dfr">
    <div class="dfr__field">
      <label class="dfr__label" :for="`${uid}-frasco`">Frasco</label>
      <!-- Arranca donde fue la planta anterior de este lote (`useUltimoDestino`): se dice, para que
           nadie mande a un frasco sin darse cuenta. -->
      <p v-if="!cargando && modelValue.recordado" class="dfr__recordado" data-testid="dfr-recordado">
        Igual que la planta anterior de este lote. Cambialo si esta va a otro frasco.
      </p>
      <div v-if="cargando" class="dfr__hint"><DsSpinner :size="14" /> Cargando frascos…</div>
      <template v-else-if="modelValue.repartir">
        <RepartoFrascos ref="repartoRef" :model-value="modelValue.reparto" :contenedores="contenedores" :peso-total="Number(pesoTotal) || 0"
                        @update:model-value="set({ reparto: $event })" />
        <button type="button" class="dfr__link" @click="set({ repartir: false })">Mandar todo a un solo frasco</button>
      </template>
      <template v-else>
        <select :id="`${uid}-frasco`" class="dfr__select dfr__select--frasco" :value="modelValue.stock_id ?? ''"
                @change="set({ stock_id: $event.target.value ? Number($event.target.value) : null })">
          <option value="">Frasco nuevo</option>
          <optgroup v-if="contenedores.length" label="Frascos de este lote">
            <option v-for="c in contenedores" :key="c.id" :value="c.id">
              {{ etiquetaFrasco(c) }} · {{ fmtG(c.cantidad) }} g{{ c.estado === 'agotado' || Number(c.cantidad) <= 0 ? ' · vacío' : '' }}
            </option>
          </optgroup>
        </select>
        <!-- Lo que no entra en la línea del selector: cuándo nació y dónde está. -->
        <p v-if="elegido" class="dfr__detalle" data-testid="dfr-detalle">{{ detalleFrasco(elegido) }}</p>
        <!-- Va a un frasco nuevo: nace con la calidad de su flor. -->
        <CalidadFrascoNuevo v-if="!modelValue.stock_id" :calidad="modelValue.calidad" :descripcion="modelValue.descripcion"
                            @update:calidad="set({ calidad: $event })" @update:descripcion="set({ descripcion: $event })" />
        <button type="button" class="dfr__link" @click="empezarReparto">Repartir en varios frascos (copones, bajos…)</button>
      </template>
    </div>

    <!-- La sede es del frasco que nace: a uno que ya existe no se le cambia acá. -->
    <div v-if="sedes.length && (modelValue.repartir || !modelValue.stock_id)" class="dfr__field">
      <label class="dfr__label" :for="`${uid}-sede`">Sede del frasco nuevo <span class="dfr__opt">opcional</span></label>
      <select :id="`${uid}-sede`" class="dfr__select dfr__select--sede" :value="modelValue.sede_id ?? ''"
              @change="set({ sede_id: $event.target.value ? Number($event.target.value) : null })">
        <option value="">Sin sede por ahora</option>
        <option v-for="se in sedes" :key="se.id" :value="se.id">{{ se.nombre }}</option>
      </select>
      <p v-if="!modelValue.sede_id" class="dfr__hint">Se le asigna después en Stock.</p>
    </div>
  </div>
</template>

<script>
// El estado vacío del destino, para el v-model del que lo usa.
export const destinoVacio = () => ({ stock_id: null, calidad: '', descripcion: '', sede_id: null, repartir: false, reparto: [] })

// Si el destino se puede mandar con este peso: sin reparto, siempre; con reparto, dos o más frascos,
// todos con gramos, y la suma igual al peso. (La calidad la dice `falta()` al tocar el botón.)
export function destinoListo(destino, pesoTotal) {
  if (!destino?.repartir) return true
  const r = destino.reparto || []
  const suma = r.reduce((s, f) => s + (Number(f.gramos) || 0), 0)
  return r.length > 1 && r.every(f => Number(f.gramos) > 0) && Math.abs(suma - (Number(pesoTotal) || 0)) < 0.01
}
</script>

<script setup>
// A QUÉ FRASCO VA UN PESAJE DEL ADMIN (Germán, 30-oct-2026: «el admin, al registrar el pesaje, tiene
// que poder dividir esa planta en uno o más frascos, existentes o nuevos»). Una sola pieza para toda
// pantalla donde el admin o el supervisor pesa y confirma en un paso (`registrar_directo`): el
// «Registrar pesaje» del lote y el pesaje por QR de una planta. Frasco nuevo (con su calidad), uno de
// flor seca del lote (también los vacíos, que se reabren) o repartido en varios; y la sede del nuevo.
// El backend valida lo mismo (`PesajeManicura#normalizar_destinos`); acá se arma y se avisa antes.
import { ref, computed, watch, onMounted } from 'vue'
import { listStocks, listSedes } from '../../lib/api.js'
import { useCalidadFlor } from '../../composables/useCalidadFlor.js'
import CalidadFrascoNuevo from './CalidadFrascoNuevo.vue'
import RepartoFrascos from './RepartoFrascos.vue'
import DsSpinner from '../../design-system/components/Spinner.vue'

const props = defineProps({
  loteId:     { type: Number, required: true },
  pesoTotal:  { type: Number, default: 0 },
  // { stock_id, calidad, descripcion, sede_id, repartir, reparto }
  modelValue: { type: Object, required: true },
})
const emit = defineEmits(['update:modelValue'])
const { calidades, faltaCalidad, etiquetaFrasco, detalleFrasco } = useCalidadFlor()
const uid = `dfr-${Math.random().toString(36).slice(2, 8)}`

const contenedores = ref([])
const sedes        = ref([])
const cargando     = ref(false)
const repartoRef   = ref(null)
const fmtG = v => Number(v || 0).toLocaleString('es-AR', { maximumFractionDigits: 1 })

// Cambiar de frasco (o de reparto a uno solo) ya no es «igual que la planta anterior».
function set(cambios) {
  const sigueIgual = !('stock_id' in cambios) && !('repartir' in cambios)
  emit('update:modelValue', { ...props.modelValue, ...cambios, recordado: sigueIgual && !!props.modelValue.recordado })
}
const elegido = computed(() => contenedores.value.find(c => c.id === props.modelValue.stock_id) || null)
function empezarReparto() {
  set({ repartir: true, reparto: [
    { stock_id: null, descripcion: 'Copones', calidad: 'altos', gramos: null },
    { stock_id: null, descripcion: 'Bajos',   calidad: 'bajos', gramos: null },
  ] })
}

async function cargar() {
  if (!props.loteId) return
  cargando.value = true
  try {
    const [cs, ss] = await Promise.all([listStocks({ lote_id: props.loteId, incluir_vacios: 1 }), listSedes()])
    contenedores.value = (cs.data || []).filter(s => s.forma_producto === 'flor_seca')
    sedes.value = ss.data || []
    sanear()
  } catch {
    contenedores.value = []
    sedes.value = []
  } finally {
    cargando.value = false
  }
}
// Un destino recordado cuyo frasco ya no está entre los del lote (se cerró, se borró, se deshizo)
// vuelve a «Frasco nuevo»: nunca se manda a un frasco que la pantalla no muestra.
function sanear() {
  const d = props.modelValue
  const hay = id => contenedores.value.some(c => c.id === id)
  const falta = d.repartir ? (d.reparto || []).some(f => f.stock_id && !hay(f.stock_id)) : (d.stock_id && !hay(d.stock_id))
  if (falta) emit('update:modelValue', destinoVacio())
}

onMounted(cargar)
watch(() => props.loteId, cargar)

// Lo que le falta a algún frasco nuevo (la calidad, o qué es si es «Otro»), o null.
function falta() {
  const d = props.modelValue
  if (d.repartir) return (d.reparto || []).filter(f => !f.stock_id).map(f => faltaCalidad(f)).find(Boolean) || null
  return d.stock_id ? null : faltaCalidad(d)
}

// Las claves del destino para `registrar_directo`.
function payload() {
  const d = props.modelValue
  const out = {}
  if (d.repartir) {
    out.destinos = d.reparto.map(f => ({
      stock_id: f.stock_id || undefined, gramos: f.gramos,
      descripcion: f.stock_id ? undefined : (f.descripcion?.trim() || undefined),
      calidad: f.stock_id ? undefined : (f.calidad || undefined),
    }))
  } else if (d.stock_id) {
    out.stock_id = d.stock_id
  } else {
    if (d.calidad) out.calidad = d.calidad
    if (d.descripcion?.trim()) out.descripcion = d.descripcion.trim()
  }
  if (d.sede_id) out.sede_id = d.sede_id
  return out
}

// Cómo quedó, para contarlo al terminar («20 g a ST-26-0003 · 10 g a Bajos»).
function resumen() {
  const d = props.modelValue
  const nombre = id => { const c = contenedores.value.find(x => x.id === id); return c ? etiquetaFrasco(c) : `frasco #${id}` }
  if (d.repartir) return d.reparto.map(f => `${fmtG(f.gramos)} g a ${f.stock_id ? nombre(f.stock_id) : `un frasco nuevo${f.descripcion ? ` («${f.descripcion.trim()}»)` : ''}`}`).join(' · ')
  const cal = calidades.value.find(c => c.value === d.calidad)?.label
  return d.stock_id ? `al frasco ${nombre(d.stock_id)}` : `a un frasco nuevo${cal ? ` de ${cal}` : ''}`
}

defineExpose({ falta, payload, resumen })
</script>

<style scoped>
.dfr { display: flex; flex-direction: column; gap: 1rem; }
.dfr__field { display: flex; flex-direction: column; gap: .35rem; }
.dfr__label { font-size: var(--fs-13); font-weight: 600; color: var(--c-ink-700); display: flex; align-items: center; gap: .4rem; }
.dfr__opt { font-size: 11px; font-weight: 500; color: var(--c-ink-400); background: var(--c-ink-100); padding: 1px 7px; border-radius: 99px; }
.dfr__hint { font-size: var(--fs-13); color: var(--c-ink-400); display: flex; align-items: center; gap: .4rem; }
.dfr__select {
  width: 100%; padding: .55rem .75rem; box-sizing: border-box;
  border: 1.5px solid var(--c-ink-200); border-radius: var(--r-md);
  background: var(--c-paper); font-size: var(--fs-14); color: var(--c-ink-900);
}
.dfr__select:focus { outline: none; border-color: var(--brand-primary); }
.dfr__select--frasco { font-weight: 600; }
.dfr__select--sede { color: var(--c-ink-700); }
.dfr__recordado { margin: 0; font-size: var(--fs-12); color: var(--c-leaf-700); font-weight: 600; }
.dfr__detalle { margin: 0; font-size: var(--fs-12); color: var(--c-ink-500); }
.dfr__link { align-self: flex-start; background: none; border: 0; padding: 0; margin-top: .25rem; color: var(--brand-primary); font-size: var(--fs-13); font-weight: 600; cursor: pointer; text-decoration: underline; }
</style>
