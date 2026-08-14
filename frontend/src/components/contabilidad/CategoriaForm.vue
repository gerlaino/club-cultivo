<script setup>
// Formulario de alta/edición de una categoría contable.
//
// Vive en su propio componente porque se renderiza EN EL LUGAR: dentro de la columna del sector
// desde la que se apretó "+ Categoría". Antes había un único formulario arriba de todo y la
// pantalla te llevaba ahí: terminabas creando una categoría "de General" a diez centímetros de
// distancia del sector General, sin verlo, confiando en un renglón que lo dice con letra chica.
import { computed } from 'vue'

const props = defineProps({
  // { id?, parent_id, nombre, tipo, unidad_negocio_id, sede_id, va_a_deposito, color, madreNombre?, areaNombre? }
  modelValue: { type: Object, required: true },
  unidades:   { type: Array,  default: () => [] },
  // Sedes de la organización. Sin elegir ninguna, la categoría vale para todas.
  sedes:      { type: Array,  default: () => [] },
  colores:    { type: Array,  default: () => [] },
  guardando:  { type: Boolean, default: false },
  // Cuando el alta salió de la columna de un sector, el sector YA está decidido: mostrarlo como
  // un select invita a cambiarlo y a crear la categoría en otro lado sin querer.
  sectorFijo: { type: Boolean, default: false },
})
const emit = defineEmits(['update:modelValue', 'guardar', 'cancelar'])

const f = computed({
  get: () => props.modelValue,
  set: (v) => emit('update:modelValue', v),
})

const esMadre = computed(() => !f.value.parent_id)

// Un sector tiene su depósito: elegido el sector, no hay una segunda decisión. Se nombra en el
// texto del switch para que se vea a dónde va a parar la compra antes de tildarlo.
const DEPOSITO_POR_TIPO_SECTOR = { cultivo: 'de Cultivo', bar: 'del Salón', social: 'del Salón' }
const depositoDelSector = computed(() => {
  const u = props.unidades.find(x => String(x.id) === String(f.value.unidad_negocio_id))
  return DEPOSITO_POR_TIPO_SECTOR[u?.tipo] || 'General'
})
const titulo  = computed(() => {
  const que = f.value.parent_id ? 'subcategoría' : 'categoría'
  return `${f.value.id ? 'Editar' : 'Nueva'} ${que}`
})
</script>

<template>
  <form class="cf" @submit.prevent="emit('guardar')">
    <div class="cf__title">
      {{ titulo }}
      <span v-if="f.parent_id" class="cf__sub">de <b>{{ f.madreNombre }}</b></span>
      <span v-else-if="f.areaNombre" class="cf__sub">en <b>{{ f.areaNombre }}</b></span>
    </div>

    <label class="fld">Nombre
      <input v-model.trim="f.nombre" class="inp" autofocus
             :placeholder="f.parent_id ? 'Ej: Fertilizante' : 'Ej: Insumos'" maxlength="50" />
    </label>

    <template v-if="esMadre">
      <div class="fld-row">
        <label class="fld">Tipo
          <select v-model="f.tipo" class="inp">
            <option value="egreso">Egreso (gasto)</option>
            <option value="ingreso">Ingreso</option>
          </select>
        </label>
        <!-- Con el sector fijado se muestra como dato, no como campo. -->
        <div v-if="sectorFijo" class="fld">Sector
          <div class="cf__fijo">{{ f.areaNombre || 'Sin sector' }}</div>
        </div>
        <label v-else class="fld">Sector
          <select v-model="f.unidad_negocio_id" class="inp">
            <option :value="null">— Sin sector —</option>
            <option v-for="u in unidades" :key="u.id" :value="u.id">{{ u.nombre }}</option>
          </select>
        </label>
      </div>
      <div class="fld-row">
        <!-- La sede es física y el sector es analítico: son ejes distintos. Sin sede, la
             categoría vale para toda la organización, que es como venían todas. -->
        <label class="fld">Sede
          <select v-model="f.sede_id" class="inp">
            <option :value="null">— Todas las sedes —</option>
            <option v-for="s in sedes" :key="s.id" :value="s.id">{{ s.nombre }}</option>
          </select>
        </label>
        <!-- A QUÉ depósito va no se pregunta: lo decide el sector (uno por sector). Acá sólo se
             dice SI la compra entra a un inventario o es puro gasto. -->
        <label class="fld">Al comprar
          <label class="cf__chk">
            <input type="checkbox" v-model="f.va_a_deposito" />
            <span>Entra al depósito {{ depositoDelSector }}</span>
          </label>
        </label>
      </div>

      <div class="fld"><span>Color</span>
        <div class="swatches">
          <button v-for="c in colores" :key="c" type="button" class="sw"
                  :class="{ 'sw--on': f.color === c }" :style="{ background: c }"
                  @click="f.color = c"></button>
        </div>
      </div>
    </template>

    <div class="cf__actions">
      <button type="button" class="btn" @click="emit('cancelar')">Cancelar</button>
      <button type="submit" class="btn btn--primary" :disabled="guardando">Guardar</button>
    </div>
  </form>
</template>

<style scoped>
.cf { display: flex; flex-direction: column; gap: .65rem; background: var(--c-slate-50); border: 1px solid var(--c-slate-200); border-radius: 10px; padding: .875rem; margin-top: .5rem; }
.cf__title { font-size: .82rem; font-weight: 700; color: var(--c-slate-900); }
.cf__sub { font-weight: 400; color: var(--c-slate-500); }
/* El sector, cuando ya está decidido: se lee, no se toca. */
.cf__fijo { padding: .45rem .6rem; background: #fff; border: 1.5px solid var(--c-slate-200); border-radius: 8px; font-size: .82rem; color: var(--c-slate-500); }
.cf__actions { display: flex; justify-content: flex-end; gap: .5rem; }
.cf__chk { display: flex; align-items: center; gap: .4rem; padding: .45rem .6rem; background: #fff; border: 1.5px solid var(--c-slate-200); border-radius: 8px; font-size: .78rem; font-weight: 400; color: var(--c-slate-600); cursor: pointer; }

.fld { display: flex; flex-direction: column; gap: .25rem; font-size: .75rem; font-weight: 600; color: var(--c-slate-600); }
.fld-row { display: grid; grid-template-columns: 1fr 1fr; gap: .65rem; }
@media (max-width: 560px) { .fld-row { grid-template-columns: 1fr; } }
.inp { width: 100%; box-sizing: border-box; background: #fff; border: 1.5px solid var(--c-slate-200); border-radius: 8px; padding: .45rem .6rem; font-size: .82rem; color: var(--c-slate-900); font-weight: 400; font-family: inherit; }
.inp:focus { outline: none; border-color: var(--brand-primary, #1b5e20); }
.swatches { display: flex; flex-wrap: wrap; gap: .3rem; }
.sw { width: 20px; height: 20px; border-radius: 6px; border: 2px solid transparent; cursor: pointer; padding: 0; }
.sw--on { border-color: var(--c-slate-900); }
.btn { background: #fff; border: 1.5px solid var(--c-slate-200); border-radius: 8px; padding: .4rem .8rem; font-size: .8rem; font-weight: 600; color: var(--c-slate-600); cursor: pointer; }
.btn:hover { background: var(--c-slate-100); }
.btn--primary { background: var(--brand-primary, #1b5e20); border-color: var(--brand-primary, #1b5e20); color: #fff; }
.btn--primary:hover { background: #144a18; }
.btn--primary:disabled { opacity: .55; cursor: not-allowed; }
</style>
