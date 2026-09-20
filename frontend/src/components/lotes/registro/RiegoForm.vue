<template>
  <div class="rf__wrap">
    <div class="rf__grid">
      <div class="rf__field">
        <label class="rf__label">Volumen <span class="rf__unit">L</span></label>
        <input type="number" step="0.5" min="0" class="rf__input" v-model.number="f.volumen" placeholder="20" />
      </div>
      <div class="rf__field">
        <label class="rf__label">pH entrada</label>
        <input type="number" step="0.1" min="0" max="14" class="rf__input" v-model.number="f.ph" placeholder="6.2" />
      </div>
      <div class="rf__field">
        <label class="rf__label">pH runoff</label>
        <input type="number" step="0.1" min="0" max="14" class="rf__input" v-model.number="f.ph_runoff" placeholder="6.0" />
      </div>
      <div class="rf__field">
        <label class="rf__label">EC <span class="rf__unit">mS/cm</span></label>
        <input type="number" step="0.1" min="0" class="rf__input" v-model.number="f.ec" placeholder="1.8" />
      </div>
    </div>

    <label class="rf__toggle-row">
      <div class="rf__toggle-track" :class="{ 'rf__toggle-track--on': f.fertilizo }">
        <input type="checkbox" v-model="f.fertilizo" class="rf__toggle-input" />
        <div class="rf__toggle-thumb"></div>
      </div>
      <span class="rf__toggle-label">¿Se fertilizó?</span>
    </label>

    <div v-if="f.fertilizo" class="rf__fertilizacion">
      <!-- Cómo se fertilizó: con una receta (descuenta del depósito y cuesta al lote),
           productos sueltos (ídem, sin receta), o sin especificar (queda como texto). -->
      <div class="rf__modos">
        <button v-for="m in MODOS" :key="m.value" type="button" class="rf__radio-btn"
                :class="{ 'rf__radio-btn--sel': modo === m.value }" @click="setModo(m.value)">
          {{ m.label }}
        </button>
      </div>

      <!-- Con receta -->
      <template v-if="modo === 'receta'">
        <div class="rf__grid">
          <div class="rf__field rf__field--full">
            <label class="rf__label">Receta</label>
            <select class="rf__input" :value="f.receta_id || ''" @change="elegirReceta($event.target.value)">
              <option value="" disabled>{{ recetas.length ? 'Elegí una receta' : 'Todavía no armaste ninguna receta' }}</option>
              <option v-for="r in recetas" :key="r.id" :value="r.id">{{ r.nombre }}{{ r.fase_label ? ` · ${r.fase_label}` : '' }}</option>
            </select>
            <span v-if="!recetas.length" class="rf__hint">Se arman en {{ esPersonal ? 'Cultivo → Nutrientes y recetas' : 'Depósito → Recetas' }}.</span>
          </div>
          <div class="rf__field">
            <label class="rf__label">Litros preparados</label>
            <input type="number" step="0.5" min="0" class="rf__input" :value="litros" placeholder="20" @input="setLitros($event.target.value)" />
          </div>
          <div v-if="receta && (receta.ph_objetivo || receta.ec_objetivo)" class="rf__field">
            <label class="rf__label">Objetivo de la receta</label>
            <div class="rf__objetivo">{{ [receta.ph_objetivo ? `pH ${receta.ph_objetivo}` : null, receta.ec_objetivo ? `EC ${receta.ec_objetivo}` : null].filter(Boolean).join(' · ') }}</div>
          </div>
        </div>
      </template>

      <!-- Productos sueltos -->
      <template v-else-if="modo === 'sueltos'">
        <div class="rf__field rf__field--full">
          <label class="rf__label">{{ esPersonal ? 'Nutriente' : 'Producto del depósito' }}</label>
          <select class="rf__input" value="" @change="agregarSuelto($event.target.value); $event.target.value = ''">
            <option value="" disabled>{{ insumos.length ? 'Agregar…' : (esPersonal ? 'Todavía no cargaste nutrientes' : 'No hay insumos de cultivo en el depósito') }}</option>
            <option v-for="i in insumosDisponibles" :key="i.id" :value="i.id">{{ i.nombre }} · quedan {{ num(i.stock_actual) }} {{ u(i.unidad_medida) }}</option>
          </select>
        </div>
      </template>

      <!-- Lo que se va a descontar (receta o sueltos): cantidad editable, y qué hacer si falta. -->
      <div v-if="modo !== 'sin' && lineas.length" class="rf__lineas">
        <div v-for="l in lineas" :key="l.insumo_id" class="rf__linea" :class="{ 'rf__linea--falta': l.faltante > 0 }">
          <div class="rf__linea-main">
            <span class="rf__linea-nombre">{{ l.nombre }}<span v-if="l.dosis" class="rf__linea-dosis"> · {{ num(l.dosis) }} {{ l.unidad_label }}</span></span>
            <span class="rf__linea-stock">quedan {{ num(l.stock_actual) }} {{ u(l.unidad_insumo) }}</span>
          </div>
          <div class="rf__linea-cant">
            <input type="number" step="0.1" min="0" class="rf__input rf__input--sm" :value="l.cantidad" @input="setCantidad(l.insumo_id, $event.target.value)" />
            <span class="rf__linea-unidad">{{ u(l.unidad_insumo) }}</span>
            <button v-if="modo === 'sueltos'" type="button" class="rf__quitar" @click="quitarSuelto(l.insumo_id)"><i class="bi bi-x"></i></button>
          </div>
          <div v-if="l.faltante > 0" class="rf__falta">
            Faltan {{ num(l.faltante) }} {{ u(l.unidad_insumo) }} en el {{ esPersonal ? 'stock' : 'depósito' }}. ¿Qué hacemos?
            <div class="rf__falta-ops">
              <button type="button" class="rf__radio-btn rf__radio-btn--xs" :class="{ 'rf__radio-btn--sel': l.modo_faltante !== 'no_descontar' }" @click="setModoFaltante(l.insumo_id, 'descontar_disponible')">Descontar lo que hay y dejar en 0</button>
              <button type="button" class="rf__radio-btn rf__radio-btn--xs" :class="{ 'rf__radio-btn--sel': l.modo_faltante === 'no_descontar' }" @click="setModoFaltante(l.insumo_id, 'no_descontar')">No descontar este</button>
            </div>
            <span class="rf__hint">El riego se registra igual: si el envase está en la mesada, cargá la compra después.</span>
          </div>
        </div>
        <div v-if="costoEstimado" class="rf__costo">≈ {{ formatARS(costoEstimado) }} en nutrientes para este riego</div>
      </div>

      <!-- Sin especificar: queda como texto, no toca el depósito -->
      <template v-if="modo === 'sin'">
        <p class="rf__hint">Queda anotado que se fertilizó, sin descontar nada. Si querés, decí con qué:</p>
        <div class="rf__grid">
          <div class="rf__field rf__field--full">
            <label class="rf__label">Producto <span class="rf__optional">opcional</span></label>
            <input type="text" class="rf__input" v-model.trim="f.producto" placeholder="Ej: Canna Coco A+B, BioBizz Bloom…" />
          </div>
          <div class="rf__field">
            <label class="rf__label">Dosis <span class="rf__unit">ml/g por L</span></label>
            <input type="number" step="0.1" min="0" class="rf__input" v-model.number="f.dosis" placeholder="10" />
          </div>
          <div class="rf__field">
            <label class="rf__label">Semana de programa</label>
            <input type="number" step="1" min="1" class="rf__input" v-model.number="f.semana_nutricion" placeholder="3" />
          </div>
        </div>
      </template>

      <div class="rf__field rf__field--full">
        <label class="rf__label">Método de aplicación</label>
        <div class="rf__radios">
          <button v-for="m in METODOS" :key="m.value" type="button"
                  class="rf__radio-btn" :class="{ 'rf__radio-btn--sel': f.metodo_nutricion === m.value }"
                  @click="setMetodo(m.value)">
            {{ m.emoji }} {{ m.label }}
          </button>
        </div>
      </div>
    </div>

    <div class="rf__field rf__field--full">
      <label class="rf__label">Observaciones <span class="rf__optional">opcional</span></label>
      <textarea class="rf__textarea" rows="2" v-model.trim="f.observaciones" placeholder="Runoff con raíces, goteros limpios…"></textarea>
    </div>
  </div>
</template>

<script setup>
// El riego, y cómo se fertilizó. «Con receta» y «productos sueltos» descuentan del depósito y
// cuestan al lote (el backend aplica: `Nutricion::Aplicar`); «sin especificar» deja el texto
// de siempre. Acá se calcula la lista para mostrarla y dejarla corregir; el número final lo
// pone el backend con lo que mande este formulario (`f.nutricion`).
import { computed, ref, watch, onMounted } from 'vue'
import { listRecetas, listInsumos } from '../../../lib/api.js'
import { formatARS } from '../../../lib/formatters.js'
import { useUsoPersonal } from '../../../composables/useUsoPersonal.js'

const props = defineProps({ modelValue: { type: Object, default: () => ({}) } })
const emit  = defineEmits(['update:modelValue'])
const f     = computed({
  get: () => props.modelValue,
  set: v  => emit('update:modelValue', v),
})
const { esPersonal } = useUsoPersonal()

const MODOS = [
  { value: 'receta',  label: '📋 Con receta' },
  { value: 'sueltos', label: '🧪 Productos sueltos' },
  { value: 'sin',     label: 'Sin especificar' },
]
const METODOS = [
  { value: 'foliar',     label: 'Foliar',     emoji: '🌿' },
  { value: 'suelo',      label: 'Suelo',      emoji: '🪱' },
  { value: 'hidroponico',label: 'Hidropónico', emoji: '💧' },
]

const recetas = ref([])
const insumos = ref([])
const cargado = ref(false)
async function cargar() {
  if (cargado.value) return
  cargado.value = true
  try {
    const [r, i] = await Promise.all([listRecetas(), listInsumos({ tipo: 'cultivo', activos: 'true' })])
    recetas.value = (r.data || []).filter(x => x.activa !== false)
    insumos.value = i.data?.insumos || i.data || []
    // Sin recetas ni productos no hay nada que descontar: el modo por defecto es «sin especificar».
    if (!f.value.modo_nutricion) patch({ modo_nutricion: recetas.value.length ? 'receta' : (insumos.value.length ? 'sueltos' : 'sin') })
  } catch { recetas.value = []; insumos.value = [] }
}
watch(() => f.value.fertilizo, (v) => { if (v) cargar() }, { immediate: true })
onMounted(() => { if (f.value.fertilizo) cargar() })

function patch(cambios) { emit('update:modelValue', { ...props.modelValue, ...cambios }) }
const modo   = computed(() => f.value.modo_nutricion || 'sin')
const receta = computed(() => recetas.value.find(r => String(r.id) === String(f.value.receta_id)) || null)
// Los litros de la mezcla son el volumen del riego, salvo que se diga otra cosa.
const litros = computed(() => f.value.litros ?? f.value.volumen ?? null)
const num = v => (v == null || v === '' ? '—' : Number(v).toLocaleString('es-AR', { maximumFractionDigits: 2 }))
const U = { mililitro: 'ml', gramo: 'g', litro: 'L', kilogramo: 'kg', unidad: 'un' }
const u = x => U[x] || x || ''

function setModo(m) { patch({ modo_nutricion: m, items: m === 'sueltos' ? (f.value.items || []) : [], receta_id: m === 'receta' ? f.value.receta_id : null }) }
function setMetodo(val) { patch({ metodo_nutricion: val }) }
function setLitros(v) { patch({ litros: v === '' ? null : Number(v), items: [] }) }
function elegirReceta(id) { patch({ receta_id: id ? Number(id) : null, items: [] }) }
function agregarSuelto(id) {
  if (!id) return
  const items = [...(f.value.items || [])]
  if (!items.some(x => String(x.insumo_id) === String(id))) items.push({ insumo_id: Number(id), cantidad: null, modo_faltante: 'descontar_disponible' })
  patch({ items })
}
function quitarSuelto(id) { patch({ items: (f.value.items || []).filter(x => x.insumo_id !== id) }) }
function setCantidad(id, v) {
  const items = [...(f.value.items || [])]
  const i = items.findIndex(x => x.insumo_id === id)
  const nuevo = { insumo_id: id, cantidad: v === '' ? null : Number(v), modo_faltante: items[i]?.modo_faltante || 'descontar_disponible' }
  if (i >= 0) items[i] = nuevo; else items.push(nuevo)
  patch({ items })
}
function setModoFaltante(id, m) {
  const items = [...(f.value.items || [])]
  const i = items.findIndex(x => x.insumo_id === id)
  if (i >= 0) items[i] = { ...items[i], modo_faltante: m }
  else { const l = lineas.value.find(x => x.insumo_id === id); items.push({ insumo_id: id, cantidad: l?.cantidad ?? null, modo_faltante: m }) }
  patch({ items })
}

const insumosDisponibles = computed(() => insumos.value.filter(i => !(f.value.items || []).some(x => x.insumo_id === i.id)))

// La lista que se ve y que viaja: por receta (dosis × litros) o sueltos, con lo corregido a mano.
const lineas = computed(() => {
  const l = Number(litros.value) || 0
  const base = modo.value === 'receta' && receta.value
    ? receta.value.items.map(it => ({ insumo_id: it.insumo_id, nombre: it.nombre, dosis: it.dosis, unidad_label: it.unidad_label, unidad_insumo: it.unidad_insumo, stock_actual: it.stock_actual, calculada: l ? +(Number(it.dosis) * l).toFixed(2) : null }))
    : modo.value === 'sueltos'
      ? (f.value.items || []).map(x => { const i = insumos.value.find(y => y.id === x.insumo_id) || {}; return { insumo_id: x.insumo_id, nombre: i.nombre, dosis: null, unidad_label: null, unidad_insumo: i.unidad_medida, stock_actual: i.stock_actual, calculada: null } })
      : []
  return base.map(b => {
    const ov = (f.value.items || []).find(x => x.insumo_id === b.insumo_id)
    const cantidad = ov?.cantidad ?? b.calculada
    const faltante = cantidad != null && Number(b.stock_actual) < Number(cantidad) ? +(Number(cantidad) - Number(b.stock_actual)).toFixed(2) : 0
    return { ...b, cantidad, faltante, modo_faltante: ov?.modo_faltante || 'descontar_disponible' }
  })
})
const costoEstimado = computed(() => lineas.value.reduce((t, l) => {
  const i = insumos.value.find(y => y.id === l.insumo_id)
  return t + (l.cantidad && i?.costo_promedio_ars ? Number(l.cantidad) * Number(i.costo_promedio_ars) : 0)
}, 0))

// Lo que el modal manda al backend como `nutricion`. Null = «se fertilizó sin especificar cómo».
watch([lineas, litros, modo, receta], () => {
  if (!f.value.fertilizo || modo.value === 'sin' || !lineas.value.length) { if (f.value.nutricion) patch({ nutricion: null }); return }
  const nutricion = {
    receta_id: modo.value === 'receta' ? f.value.receta_id : null,
    litros: litros.value,
    items: lineas.value.filter(l => l.cantidad != null && Number(l.cantidad) > 0).map(l => ({ insumo_id: l.insumo_id, cantidad: l.cantidad, modo_faltante: l.modo_faltante })),
  }
  if (JSON.stringify(nutricion) !== JSON.stringify(f.value.nutricion)) patch({ nutricion })
}, { deep: true })
</script>

<style scoped>
.rf__grid { display: grid; grid-template-columns: 1fr 1fr; gap: var(--sp-3); margin-bottom: var(--sp-3); }
.rf__field { display: flex; flex-direction: column; gap: .3rem; }
.rf__field--full { grid-column: 1 / -1; }
.rf__label { font-size: .72rem; font-weight: 700; color: var(--c-ink-700); text-transform: uppercase; letter-spacing: .04em; display: flex; align-items: baseline; gap: 4px; }
.rf__unit { font-size: .65rem; color: var(--c-ink-500); font-weight: 400; text-transform: none; letter-spacing: 0; }
.rf__optional { font-size: .65rem; font-weight: 500; color: var(--c-ink-500); text-transform: none; letter-spacing: 0; }
.rf__input { background: var(--c-ink-100, #F3F4F6); border: 1.5px solid var(--c-ink-300, #D1D5DB); border-radius: var(--r-md, 6px); padding: .5rem .75rem; font-size: var(--fs-14); color: var(--c-ink-900); width: 100%; box-sizing: border-box; transition: border .15s; }
.rf__input:focus { outline: none; border-color: var(--brand-primary, #1b5e20); background: #fff; }
.rf__textarea { background: var(--c-ink-100); border: 1.5px solid var(--c-ink-300); border-radius: var(--r-md); padding: .5rem .75rem; font-size: var(--fs-14); color: var(--c-ink-900); width: 100%; box-sizing: border-box; resize: vertical; transition: border .15s; }
.rf__textarea:focus { outline: none; border-color: var(--brand-primary); background: #fff; }
.rf__toggle-row { display: flex; align-items: center; gap: var(--sp-3); cursor: pointer; margin-bottom: var(--sp-3); }
.rf__toggle-input { position: absolute; opacity: 0; width: 0; height: 0; }
.rf__toggle-track { position: relative; width: 40px; height: 22px; background: var(--c-ink-300); border-radius: 99px; transition: background .2s; flex-shrink: 0; }
.rf__toggle-track--on { background: var(--brand-primary, #1b5e20); }
.rf__toggle-thumb { position: absolute; top: 3px; left: 3px; width: 16px; height: 16px; background: #fff; border-radius: 50%; transition: transform .2s; box-shadow: 0 1px 3px rgba(0,0,0,.2); }
.rf__toggle-track--on .rf__toggle-thumb { transform: translateX(18px); }
.rf__toggle-label { font-size: var(--fs-14); font-weight: 500; color: var(--c-ink-700); user-select: none; }
.rf__modos { display: flex; flex-wrap: wrap; gap: var(--sp-2); margin-bottom: var(--sp-3); }
.rf__hint { font-size: .74rem; color: var(--c-ink-500); }
.rf__objetivo { font-size: var(--fs-14); color: var(--c-ink-700); padding: .5rem 0; font-weight: 600; }
.rf__lineas { display: flex; flex-direction: column; gap: .4rem; margin: var(--sp-2) 0 var(--sp-3); }
.rf__linea { background: #fff; border: 1px solid var(--c-ink-100); border-radius: var(--r-md); padding: .5rem .65rem; display: grid; grid-template-columns: 1fr auto; gap: .4rem .75rem; align-items: center; }
.rf__linea--falta { border-color: #fcd34d; background: #fffbeb; }
.rf__linea-main { display: flex; flex-direction: column; min-width: 0; }
.rf__linea-nombre { font-weight: 600; font-size: var(--fs-14); color: var(--c-ink-900); }
.rf__linea-dosis { font-weight: 500; color: var(--c-ink-500); }
.rf__linea-stock { font-size: .72rem; color: var(--c-ink-500); }
.rf__linea-cant { display: flex; align-items: center; gap: .35rem; }
.rf__input--sm { width: 92px; padding: .35rem .5rem; text-align: right; }
.rf__linea-unidad { font-size: .74rem; color: var(--c-ink-500); }
.rf__quitar { background: none; border: 0; color: var(--c-ink-500); cursor: pointer; font-size: 1rem; }
.rf__falta { grid-column: 1 / -1; font-size: .78rem; color: #92400e; display: flex; flex-direction: column; gap: .35rem; }
.rf__falta-ops { display: flex; flex-wrap: wrap; gap: .35rem; }
.rf__radio-btn--xs { padding: .3rem .6rem; font-size: .76rem; }
.rf__costo { font-size: .78rem; color: var(--c-ink-700); text-align: right; }
.rf__fertilizacion { background: var(--c-leaf-50, #F4F8F5); border: 1px solid var(--c-leaf-100, #E8F0EB); border-radius: var(--r-lg); padding: var(--sp-3); margin-bottom: var(--sp-3); }

/* Estas tres nunca se escribieron: los botones de método de aplicación salían con el borde
   crudo del navegador, cuadrados y pegados, en medio de un formulario con todo lo demás
   estilado. Compilaba perfecto — por eso ahora hay un test que barre el markup contra el
   <style> de cada componente. */
.rf__wrap { display: block; }
.rf__radios { display: flex; flex-wrap: wrap; gap: var(--sp-2); }
.rf__radio-btn {
  display: inline-flex; align-items: center; gap: .35rem;
  padding: .45rem .8rem; cursor: pointer;
  background: #fff; border: 1.5px solid var(--c-ink-300, #D1D5DB);
  border-radius: var(--r-md, 6px);
  font-size: var(--fs-14); font-weight: 500; color: var(--c-ink-700);
  transition: all .15s;
}
.rf__radio-btn:hover { border-color: var(--brand-primary, #1b5e20); background: var(--c-leaf-50, #F4F8F5); }
.rf__radio-btn--sel {
  background: var(--brand-primary, #1b5e20); border-color: var(--brand-primary, #1b5e20);
  color: #fff; font-weight: 600;
}
</style>
