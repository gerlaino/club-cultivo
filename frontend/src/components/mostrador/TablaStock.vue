<template>
  <div class="tst">
    <div class="tst__barra">
      <input v-model="busqueda" type="search" class="tst__buscar"
             placeholder="Buscar por producto, variedad, lote o número…" aria-label="Buscar" />
      <span class="tst__conteo">{{ visibles.length }} de {{ filas.length }}</span>
    </div>

    <p v-if="!filas.length" class="tst__vacio">
      No hay stock habilitado para dispensar en esta sede.
    </p>
    <p v-else-if="!visibles.length" class="tst__vacio">Nada coincide con «{{ busqueda }}».</p>

    <div v-else class="tst__wrap">
      <!-- `tabla-cards`: en el teléfono cada fila pasa a ser una tarjeta con la etiqueta de la
           columna delante del dato (sale de los `data-col`). Ocho columnas con scroll horizontal
           no se leen paradas frente a alguien, que es cómo se usa esta pantalla. -->
      <table class="tst__table tabla-cards">
        <thead>
          <tr>
            <th v-for="c in columnas" :key="c.campo"
                :class="['tst__th', c.num ? 'tst__th--num' : '', orden.campo === c.campo ? 'is-activa' : '']"
                :aria-sort="orden.campo === c.campo ? (orden.dir === 'asc' ? 'ascending' : 'descending') : 'none'">
              <button type="button" class="tst__th-btn" @click="ordenarPor(c.campo)">
                {{ c.label }}
                <span v-if="orden.campo === c.campo" class="tst__caret">{{ orden.dir === 'asc' ? '▲' : '▼' }}</span>
              </button>
            </th>
            <th class="tst__th tst__th--num tst__th--cant">Cuánto baja</th>
          </tr>
        </thead>
        <tbody>
          <!-- La fila elegida se pinta sola: la CANTIDAD es la marca. Un tilde aparte crearía el
               estado sin sentido "marcado en 0" y serían dos gestos para uno. -->
          <tr v-for="s in visibles" :key="s.stock_id" :class="{ 'is-elegida': elegido(s) }">
            <td data-col="Producto">
              <div class="tst__prod">{{ s.etiqueta }}</div>
              <div class="tst__meta">
                {{ s.numero }}
                <span v-if="heredados.has(s.stock_id)" class="tst__pill">viene del turno anterior</span>
              </div>
            </td>
            <td class="tst__mut" data-col="Variedad">{{ s.genetica || '—' }}</td>
            <td class="tst__mut" data-col="Lote">{{ s.lote || '—' }}</td>
            <td class="tst__mut" data-col="Elaborado">{{ fecha(s.fecha) }}</td>
            <td class="tst__num tst__mut" data-col="Libre">{{ fmt(s.disponible) }} {{ s.unidad }}</td>
            <td class="tst__num tst__mut" data-col="Precio">{{ s.precio_ars ? `$${fmt(s.precio_ars)}` : '—' }}</td>
            <td v-if="muestraCosto" class="tst__num tst__mut" data-col="Costo">
              {{ s.costo_ars ? `$${fmt(s.costo_ars)}` : '—' }}
            </td>
            <td class="tst__num tst__td-cant" data-col="Cuánto baja">
              <input :value="cantidades[s.stock_id] ?? ''" type="number" min="0" step="0.1"
                     class="tst__input" :class="{ 'is-mal': excede(s) }"
                     :aria-label="`Cuánto baja de ${s.etiqueta}`"
                     @input="escribir(s, $event.target.value)" />
              <span class="tst__unidad">{{ s.unidad }}</span>
              <span v-if="excede(s)" class="tst__error">quedan {{ fmt(s.disponible) }}</span>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Fijo al pie: con buscador de por medio, lo elegido puede no estar en pantalla. Sin este
         resumen, el que filtra cree que perdió lo que ya había cargado. -->
    <div v-if="elegidos.length" class="tst__pie">
      <span class="tst__pie-txt">
        <b>{{ elegidos.length }}</b> producto{{ elegidos.length === 1 ? '' : 's' }}
        · {{ totalPorUnidad }}
        <template v-if="muestraCosto && totalCosto"> · ${{ fmt(totalCosto) }} a costo</template>
      </span>
      <button class="tst__limpiar" @click="limpiar">Vaciar</button>
    </div>
  </div>
</template>

<script setup>
// QUÉ BAJA DEL DEPÓSITO A LA MESA.
//
// Era un desplegable, y un `<select>` con cuarenta frascos no deja ver nada: elegir qué se pone
// sobre la mesa no es buscar un ítem, es REVISAR el inventario y decidir — de qué lote, de
// cuándo, cuánto queda y a cuánto se vende.
//
// Es la misma tabla con la que después se dispensa (`ModalNuevaDispensacion`), y a propósito:
// armar la mesa y dispensar de ella son la misma pregunta, y contestarla con dos tablas
// distintas es cómo empiezan a contradecirse.
//
// NO es una lista informativa: lo que se elige acá se APARTA — bloquea esa cantidad y baja el
// disponible de todas las demás pantallas. No descuenta, que es distinto de no hacer nada.
import { ref, computed } from 'vue'

const props = defineProps({
  // Todo el stock habilitado de la sede, tal cual lo sirve el backend.
  stocks:       { type: Array,  default: () => [] },
  // { stock_id: cantidad } — vive en el padre para que sobreviva al buscador y al orden.
  modelValue:   { type: Object, default: () => ({}) },
  // Lo que dejó contado el cierre anterior: va arriba y con su número puesto. Nunca "anoche":
  // el mostrador se cierra y se reabre varias veces por día, y a las tres de la tarde el turno
  // anterior fue hace dos horas.
  heredados:    { type: Set,    default: () => new Set() },
  muestraCosto: { type: Boolean, default: false },
})
const emit = defineEmits(['update:modelValue'])

const busqueda = ref('')
// Por defecto, lo heredado primero y después lo más viejo: lo viejo sale primero.
const orden = ref({ campo: 'fecha', dir: 'asc' })

const COLUMNAS = [
  { campo: 'etiqueta', label: 'Producto' },
  { campo: 'genetica', label: 'Variedad' },
  { campo: 'lote',     label: 'Lote' },
  { campo: 'fecha',    label: 'Elaborado' },
  { campo: 'disponible', label: 'Libre',  num: true },
  { campo: 'precio',   label: 'Precio',   num: true },
]
const columnas = computed(() =>
  props.muestraCosto ? [...COLUMNAS, { campo: 'costo', label: 'Costo', num: true }] : COLUMNAS
)

const cantidades = computed(() => props.modelValue)
const filas = computed(() => props.stocks)

const fmt = (n) => Number(n ?? 0).toLocaleString('es-AR', { maximumFractionDigits: 1 })
const fecha = (f) => (f ? new Date(`${f}T12:00:00`).toLocaleDateString('es-AR', { day: '2-digit', month: '2-digit', year: '2-digit' }) : '—')

const elegido = (s) => Number(cantidades.value[s.stock_id]) > 0
// No se puede bajar lo que no está. El backend lo rechaza igual, pero decirlo en la fila evita
// llenar el formulario entero para que rebote al final.
const excede  = (s) => Number(cantidades.value[s.stock_id] || 0) > Number(s.disponible)

const elegidos = computed(() => filas.value.filter(elegido))
const totalCosto = computed(() =>
  elegidos.value.reduce((t, s) => t + Number(cantidades.value[s.stock_id]) * Number(s.costo_ars || 0), 0)
)
// Gramos y unidades no se suman: 300 g y 12 prerolls no son 312 de nada.
const totalPorUnidad = computed(() => {
  const por = {}
  for (const s of elegidos.value) {
    por[s.unidad] = (por[s.unidad] || 0) + Number(cantidades.value[s.stock_id])
  }
  return Object.entries(por).map(([u, n]) => `${fmt(n)} ${u}`).join(' · ')
})

function valorOrden (s, campo) {
  switch (campo) {
    case 'etiqueta':   return (s.etiqueta || '').toLowerCase()
    case 'genetica':   return (s.genetica || '').toLowerCase()
    case 'lote':       return (s.lote || '').toLowerCase()
    case 'fecha':      return s.fecha || ''
    case 'disponible': return Number(s.disponible) || 0
    case 'precio':     return Number(s.precio_ars) || 0
    case 'costo':      return Number(s.costo_ars) || 0
    default:           return ''
  }
}

function ordenarPor (campo) {
  const o = orden.value
  orden.value = { campo, dir: o.campo === campo && o.dir === 'asc' ? 'desc' : 'asc' }
}

const visibles = computed(() => {
  const term = busqueda.value.trim().toLowerCase()
  const lista = term
    ? filas.value.filter(s => [s.etiqueta, s.genetica, s.lote, s.numero]
        .some(v => (v || '').toLowerCase().includes(term)))
    : [...filas.value]

  const { campo, dir } = orden.value
  const signo = dir === 'asc' ? 1 : -1
  return lista.sort((a, b) => {
    // Lo heredado va arriba siempre: es el número que no hay que volver a declarar, y perderlo
    // entre cuarenta filas es perder la mitad del valor del módulo.
    const ha = props.heredados.has(a.stock_id) ? 0 : 1
    const hb = props.heredados.has(b.stock_id) ? 0 : 1
    if (ha !== hb) return ha - hb

    const va = valorOrden(a, campo), vb = valorOrden(b, campo)
    return va < vb ? -signo : va > vb ? signo : 0
  })
})

function escribir (s, valor) {
  const copia = { ...cantidades.value }
  const n = Number(valor)
  if (valor === '' || Number.isNaN(n) || n <= 0) delete copia[s.stock_id]
  else copia[s.stock_id] = n
  emit('update:modelValue', copia)
}

function limpiar () { emit('update:modelValue', {}) }

</script>

<style scoped>
.tst { display: flex; flex-direction: column; gap: 12px; }

.tst__barra { display: flex; align-items: center; gap: 12px; flex-wrap: wrap; }
.tst__buscar {
  flex: 1; min-width: 240px;
  border: 1px solid var(--c-slate-300); border-radius: 9px; padding: 9px 12px;
  font-size: var(--fs-14); background: #fff; color: var(--c-ink-900);
}
.tst__buscar:focus { outline: 2px solid var(--c-leaf-300); outline-offset: 1px; border-color: var(--c-leaf-500); }
.tst__conteo { font-size: var(--fs-12); color: var(--c-ink-500); font-family: var(--font-mono); }
.tst__vacio  { margin: 0; font-size: var(--fs-14); color: var(--c-ink-500); }

.tst__wrap {
  border: 1px solid var(--c-slate-200); border-radius: 12px;
  overflow: auto; max-height: 52vh; background: #fff;
}
.tst__table { width: 100%; border-collapse: collapse; }
.tst__th {
  position: sticky; top: 0; z-index: 1; background: #fff;
  text-align: left; padding: 0; border-bottom: 1px solid var(--c-slate-200); white-space: nowrap;
}
.tst__th--num { text-align: right; }
.tst__th-btn {
  width: 100%; border: 0; background: transparent; cursor: pointer;
  padding: 11px 14px; text-align: inherit;
  font-size: var(--fs-12); font-weight: 600; text-transform: uppercase;
  letter-spacing: .04em; color: var(--c-ink-500);
}
.tst__th-btn:hover { color: var(--c-ink-900); }
.tst__th.is-activa .tst__th-btn { color: var(--c-leaf-800); }
.tst__caret { font-size: 9px; margin-left: 3px; }
/* La columna que se completa no ordena: es un campo, no un dato. */
.tst__th--cant { padding: 11px 14px; font-size: var(--fs-12); font-weight: 600;
                 text-transform: uppercase; letter-spacing: .04em; color: var(--c-ink-500); }

.tst__table td { padding: 10px 14px; border-bottom: 1px solid var(--c-slate-100); vertical-align: middle; }
.tst__table tbody tr:last-child td { border-bottom: 0; }
.tst__table tbody tr.is-elegida { background: var(--c-leaf-50); }

.tst__num { text-align: right; }
.tst__mut { color: var(--c-ink-500); font-size: var(--fs-13); font-family: var(--font-mono); }
.tst__prod { font-size: var(--fs-14); font-weight: 600; color: var(--c-ink-900); }
.tst__meta { font-size: var(--fs-12); color: var(--c-ink-500); margin-top: 2px; display: flex; gap: 6px; align-items: center; flex-wrap: wrap; }
.tst__pill { background: var(--c-sky-100); color: var(--c-sky-600); border-radius: 999px; padding: 1px 7px; font-weight: 600; }

.tst__td-cant { white-space: nowrap; }
.tst__input {
  width: 92px; text-align: right;
  border: 1px solid var(--c-slate-300); border-radius: 8px; padding: 7px 9px;
  font-size: var(--fs-14); font-family: var(--font-mono); background: #fff; color: var(--c-ink-900);
}
.tst__input:focus { outline: 2px solid var(--c-leaf-300); outline-offset: 1px; border-color: var(--c-leaf-500); }
.tst__input.is-mal { border-color: var(--c-amber-500); }
.tst__unidad { font-size: var(--fs-12); color: var(--c-ink-500); margin-left: 5px; }
.tst__error  { display: block; font-size: var(--fs-12); color: var(--c-amber-500); margin-top: 2px; }

.tst__pie {
  position: sticky; bottom: 0;
  display: flex; align-items: center; justify-content: space-between; gap: 12px;
  background: var(--c-leaf-50); border-radius: 11px; padding: 11px 16px;
}
.tst__pie-txt { font-size: var(--fs-13); color: var(--c-ink-700); }
.tst__pie-txt b { font-family: var(--font-mono); color: var(--c-ink-900); }
.tst__limpiar {
  border: 0; background: transparent; color: var(--c-ink-500);
  font-size: var(--fs-13); cursor: pointer; text-decoration: underline;
}
.tst__limpiar:hover { color: var(--c-rust-600); }

@media (max-width: 767px) {
  /* Ya son tarjetas: el alto fijo y el scroll propio sobran, y el sticky del encabezado no
     aplica porque el encabezado no se muestra. */
  .tst__wrap { max-height: none; border: 0; background: transparent; }
  .tst__td-cant { white-space: normal; }
  .tst__error { display: inline; margin-left: 6px; }
}
</style>
