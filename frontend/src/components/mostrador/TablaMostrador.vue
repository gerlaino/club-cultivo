<template>
  <div class="tmo">
    <div class="tmo__barra">
      <input v-model="busqueda" type="search" class="tmo__buscar"
             placeholder="Buscar por producto, variedad, lote o número…" aria-label="Buscar" />
      <span class="tmo__conteo">{{ visibles.length }} de {{ filas.length }}</span>
    </div>

    <p v-if="!filas.length" class="tmo__vacio">{{ vacioTexto }}</p>
    <p v-else-if="!visibles.length" class="tmo__vacio">Nada coincide con «{{ busqueda }}».</p>

    <div v-else class="tmo__wrap">
      <table class="tmo__table tabla-cards">
        <thead>
          <tr>
            <th v-for="c in columnas" :key="c.campo"
                :class="['tmo__th', c.num ? 'tmo__th--num' : '', orden.campo === c.campo ? 'is-activa' : '']"
                :aria-sort="orden.campo === c.campo ? (orden.dir === 'asc' ? 'ascending' : 'descending') : 'none'">
              <button type="button" class="tmo__th-btn" @click="ordenarPor(c.campo)">
                {{ c.label }}
                <span v-if="orden.campo === c.campo" class="tmo__caret">{{ orden.dir === 'asc' ? '▲' : '▼' }}</span>
              </button>
            </th>
            <th class="tmo__th tmo__th--num tmo__th--fija">{{ tituloColumna }}</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="s in visibles" :key="s.stock_id" :class="{ 'is-en-mesa': enLaMesa(s) }">
            <!-- El PRODUCTO es la forma, y la VARIEDAD va en su columna. Antes la primera decía
                 "LO (flor seca)" y la de al lado "LO": el mismo dato dos veces, y la forma —que
                 es lo que distingue un frasco de un preroll— escondida entre paréntesis. -->
            <td data-col="Producto">
              <div class="tmo__prod">{{ formaLabel(s.forma) }}</div>
              <div class="tmo__meta">{{ s.numero }}</div>
            </td>
            <td class="tmo__mut" data-col="Variedad">{{ s.genetica || '—' }}</td>
            <td class="tmo__mut" data-col="Lote">{{ s.lote || '—' }}</td>
            <td class="tmo__mut" data-col="Elaborado">{{ fecha(s.fecha) }}</td>
            <td class="tmo__num tmo__mut" data-col="Precio">{{ s.precio_ars ? `$${fmt(s.precio_ars)}` : '—' }}</td>
            <td v-if="muestraCosto" class="tmo__num tmo__mut" data-col="Costo">
              {{ s.costo_ars ? `$${fmt(s.costo_ars)}` : '—' }}
            </td>
            <td class="tmo__num tmo__mut" data-col="Depósito">{{ fmt(s.disponible) }} {{ s.unidad }}</td>
            <td class="tmo__num tmo__td-input" :data-col="tituloColumna">
              <template v-if="editable">
                <input :value="valores[s.stock_id] ?? ''" type="number" min="0" step="0.1"
                       class="tmo__input" :class="{ 'is-mal': excede(s) }"
                       :aria-label="`${tituloColumna} de ${formaLabel(s.forma)}`"
                       @input="escribir(s, $event.target.value)" />
                <span class="tmo__unidad">{{ s.unidad }}</span>
                <span v-if="excede(s)" class="tmo__error">quedan {{ fmt(s.disponible) }}</span>
              </template>
              <template v-else>
                <span class="tmo__mesa">{{ contando ? '—' : fmt(s.mostrador) }}</span>
                <span class="tmo__unidad">{{ s.unidad }}</span>
              </template>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Con buscador de por medio, lo cargado puede no estar en pantalla: sin este resumen, el
         que filtra cree que perdió lo que ya había escrito. -->
    <div v-if="editable && hayCambios" class="tmo__pie">
      <span class="tmo__pie-txt">
        <b>{{ cambios.length }}</b> cambio{{ cambios.length === 1 ? '' : 's' }} sin guardar
        · {{ resumenCambios }}
      </span>
      <button class="tmo__limpiar" @click="descartar">Descartar</button>
    </div>
  </div>
</template>

<script setup>
// QUÉ HAY SOBRE LA MESA DEL MOSTRADOR, y cuánto de cada cosa.
//
// Dos columnas al lado: **Depósito** (lo libre en el inventario) y **Mostrador** (lo que está
// sobre la mesa). De un vistazo se ve dónde está cada producto — que es la pregunta del admin
// que administra a distancia.
//
// La columna editable dice **Mostrador**, no "cuánto baja": se escribe el TOTAL que tiene que
// quedar arriba, no la diferencia. Pedirle al usuario que calcule el delta es pedirle la cuenta
// que hace la máquina.
import { ref, computed } from 'vue'
import { formaLabel } from '../../lib/formatters.js'

const props = defineProps({
  // Todo el stock apto para dispensa de la sede, con `disponible` (depósito) y `mostrador`.
  stocks:       { type: Array,  default: () => [] },
  // { stock_id: cantidad } — lo que va a quedar sobre la mesa. Vive en el padre para sobrevivir
  // al buscador y al orden.
  modelValue:   { type: Object, default: () => ({}) },
  editable:     { type: Boolean, default: false },
  muestraCosto: { type: Boolean, default: false },
  tituloColumna:{ type: String,  default: 'Mostrador' },
  vacioTexto:   { type: String,  default: 'No hay stock habilitado para dispensar en esta sede.' },
  // Con el modal de conteo abierto (solo en la vista de LECTURA — quien atiende, no quien
  // edita la mesa), no se muestra cuánto dice el sistema. Misma regla que el efectivo esperado:
  // con el número puesto al lado, se escribe ese y el conteo es teatro.
  contando:     { type: Boolean, default: false },
})
const emit = defineEmits(['update:modelValue'])

const busqueda = ref('')
// Por defecto lo que YA está sobre la mesa primero, y dentro de eso lo más viejo: lo viejo sale
// primero.
const orden = ref({ campo: 'fecha', dir: 'asc' })

const COLUMNAS = [
  { campo: 'forma',    label: 'Producto' },
  { campo: 'genetica', label: 'Variedad' },
  { campo: 'lote',     label: 'Lote' },
  { campo: 'fecha',    label: 'Elaborado' },
  { campo: 'precio',   label: 'Precio', num: true },
]
const columnas = computed(() => {
  const base = props.muestraCosto ? [...COLUMNAS, { campo: 'costo', label: 'Costo', num: true }] : COLUMNAS
  return [...base, { campo: 'disponible', label: 'Depósito', num: true }]
})

const valores = computed(() => props.modelValue)
const filas   = computed(() => props.stocks)

const fmt = (n) => Number(n ?? 0).toLocaleString('es-AR', { maximumFractionDigits: 1 })
const fecha = (f) => (f ? new Date(`${f}T12:00:00`).toLocaleDateString('es-AR', { day: '2-digit', month: '2-digit', year: '2-digit' }) : '—')

const enLaMesa = (s) => Number(valores.value[s.stock_id] ?? s.mostrador) > 0
// No se puede subir a la mesa lo que no está libre. El backend lo rechaza igual, pero decirlo en
// la fila evita llenar la tabla entera para que rebote al final.
const excede = (s) => {
  const nueva = Number(valores.value[s.stock_id] || 0)
  const sube  = nueva - Number(s.mostrador || 0)
  return sube > Number(s.disponible || 0)
}

// Sólo lo que cambió: mandar la tabla entera haría que el backend evalúe productos que nadie tocó.
const cambios = computed(() =>
  filas.value.filter(s => {
    const v = valores.value[s.stock_id]
    return v !== undefined && Number(v) !== Number(s.mostrador || 0)
  })
)
const hayCambios = computed(() => cambios.value.length > 0)
const hayExceso  = computed(() => filas.value.some(excede))
const resumenCambios = computed(() => {
  const sube = cambios.value.filter(s => Number(valores.value[s.stock_id]) > Number(s.mostrador || 0)).length
  const baja = cambios.value.length - sube
  return [sube ? `${sube} sube${sube === 1 ? '' : 'n'}` : null,
          baja ? `${baja} baja${baja === 1 ? '' : 'n'}` : null].filter(Boolean).join(' · ')
})

function valorOrden (s, campo) {
  switch (campo) {
    case 'forma':      return formaLabel(s.forma).toLowerCase()
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
    ? filas.value.filter(s => [formaLabel(s.forma), s.genetica, s.lote, s.numero]
        .some(v => (v || '').toLowerCase().includes(term)))
    : [...filas.value]

  const { campo, dir } = orden.value
  const signo = dir === 'asc' ? 1 : -1
  return lista.sort((a, b) => {
    // Lo que ya está sobre la mesa va arriba: es lo que se está mirando.
    const ma = Number(a.mostrador || 0) > 0 ? 0 : 1
    const mb = Number(b.mostrador || 0) > 0 ? 0 : 1
    if (ma !== mb) return ma - mb

    const va = valorOrden(a, campo), vb = valorOrden(b, campo)
    return va < vb ? -signo : va > vb ? signo : 0
  })
})

function escribir (s, valor) {
  const copia = { ...valores.value }
  const n = Number(valor)
  if (valor === '' || Number.isNaN(n) || n < 0) delete copia[s.stock_id]
  else copia[s.stock_id] = n
  emit('update:modelValue', copia)
}

function descartar () { emit('update:modelValue', {}) }

defineExpose({ cambios, hayCambios, hayExceso })
</script>

<style scoped>
.tmo { display: flex; flex-direction: column; gap: 12px; }

.tmo__barra { display: flex; align-items: center; gap: 12px; flex-wrap: wrap; }
.tmo__buscar {
  flex: 1; min-width: 240px;
  border: 1px solid var(--c-slate-300); border-radius: 9px; padding: 9px 12px;
  font-size: var(--fs-14); background: #fff; color: var(--c-ink-900);
}
.tmo__buscar:focus { outline: 2px solid var(--c-leaf-300); outline-offset: 1px; border-color: var(--c-leaf-500); }
.tmo__conteo { font-size: var(--fs-12); color: var(--c-ink-500); font-family: var(--font-mono); }
.tmo__vacio  { margin: 0; font-size: var(--fs-14); color: var(--c-ink-500); }

.tmo__wrap {
  border: 1px solid var(--c-slate-200); border-radius: 12px;
  overflow: auto; max-height: 56vh; background: #fff;
}
.tmo__table { width: 100%; border-collapse: collapse; }
.tmo__th {
  position: sticky; top: 0; z-index: 1; background: #fff;
  text-align: left; padding: 0; border-bottom: 1px solid var(--c-slate-200); white-space: nowrap;
}
.tmo__th--num { text-align: right; }
.tmo__th-btn {
  width: 100%; border: 0; background: transparent; cursor: pointer;
  padding: 11px 14px; text-align: inherit;
  font-size: var(--fs-12); font-weight: 600; text-transform: uppercase;
  letter-spacing: .04em; color: var(--c-ink-500);
}
.tmo__th-btn:hover { color: var(--c-ink-900); }
.tmo__th.is-activa .tmo__th-btn { color: var(--c-leaf-800); }
.tmo__caret { font-size: 9px; margin-left: 3px; }
/* La columna que se completa no ordena: es un campo, no un dato. */
.tmo__th--fija {
  padding: 11px 14px; font-size: var(--fs-12); font-weight: 700; text-transform: uppercase;
  letter-spacing: .04em; color: var(--c-leaf-800);
}

.tmo__table td { padding: 10px 14px; border-bottom: 1px solid var(--c-slate-100); vertical-align: middle; }
.tmo__table tbody tr:last-child td { border-bottom: 0; }
.tmo__table tbody tr.is-en-mesa { background: var(--c-leaf-50); }

.tmo__num { text-align: right; }
.tmo__mut { color: var(--c-ink-500); font-size: var(--fs-13); font-family: var(--font-mono); }
.tmo__prod { font-size: var(--fs-14); font-weight: 600; color: var(--c-ink-900); }
.tmo__meta { font-size: var(--fs-12); color: var(--c-ink-500); margin-top: 2px; }

.tmo__td-input { white-space: nowrap; }
.tmo__input {
  width: 92px; text-align: right;
  border: 1px solid var(--c-slate-300); border-radius: 8px; padding: 7px 9px;
  font-size: var(--fs-14); font-family: var(--font-mono); background: #fff; color: var(--c-ink-900);
}
.tmo__input:focus { outline: 2px solid var(--c-leaf-300); outline-offset: 1px; border-color: var(--c-leaf-500); }
.tmo__input.is-mal { border-color: var(--c-amber-500); }
.tmo__unidad { font-size: var(--fs-12); color: var(--c-ink-500); margin-left: 5px; }
.tmo__error  { display: block; font-size: var(--fs-12); color: var(--c-amber-500); margin-top: 2px; }
/* El número que se lee de un vistazo: es la única pregunta del que atiende. */
.tmo__mesa { font-family: var(--font-mono); font-size: var(--fs-16); font-weight: 700; color: var(--c-leaf-800); }

.tmo__pie {
  position: sticky; bottom: 0;
  display: flex; align-items: center; justify-content: space-between; gap: 12px;
  background: var(--c-amber-100); border-radius: 11px; padding: 11px 16px;
}
.tmo__pie-txt { font-size: var(--fs-13); color: var(--c-ink-700); }
.tmo__pie-txt b { font-family: var(--font-mono); color: var(--c-ink-900); }
.tmo__limpiar {
  border: 0; background: transparent; color: var(--c-ink-500);
  font-size: var(--fs-13); cursor: pointer; text-decoration: underline;
}

@media (max-width: 767px) {
  .tmo__wrap { max-height: none; border: 0; background: transparent; }
  .tmo__td-input { white-space: normal; }
  .tmo__error { display: inline; margin-left: 6px; }
}
</style>
