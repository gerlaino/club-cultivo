<script setup>
// LA TABLA DEL INVENTARIO DE STOCK, UNA SOLA. La usan la pantalla de Stock y la solapa
// Dispensación del Depósito: eran dos tablas del mismo stock con columnas distintas, y la del
// Depósito calculaba «En depósito» por su cuenta en el navegador. Ahora las dos muestran lo mismo,
// con los números que manda el backend (`en_deposito_g`, `reservado`, `en_mostrador_g`,
// `disponible_para_entregar`).
//
// No pide nada: recibe la página de filas y el orden, y avisa cuando se toca un cabezal
// (`update:orden`) o una fila (`abrir`). Ordenar y paginar lo hace el servidor.
import { computed } from 'vue'
import { formaLabel, formatARS } from '../../lib/formatters.js'

const props = defineProps({
  stocks:     { type: Array, required: true },
  // { campo, dir }; campo vacío = como viene del servidor (lo último que entró arriba).
  orden:      { type: Object, default: () => ({ campo: '', dir: 'desc' }) },
  esPersonal: { type: Boolean, default: false },
  // Umbral de stock bajo de flor seca, en gramos. Sin umbral no se pinta nada en rojo.
  umbral:     { type: Number, default: null },
  flashIds:   { type: Set, default: () => new Set() },
  // Si tocar una fila abre la ficha. Sólo el admin tiene la ficha del stock.
  abrible:    { type: Boolean, default: false },
})
const emit = defineEmits(['update:orden', 'abrir'])

// LAS COLUMNAS DE LA TABLA, Y POR CUÁL SE PUEDE ORDENAR. `campo` es el nombre que entiende el
// backend (lista blanca en `ORDEN_INVENTARIO`): un cabezal que no ordena, entre nueve que sí, se
// lee como que esa columna está rota.
//
// `dir` es hacia dónde ordena la PRIMERA vez que se toca. Los números y las fechas arrancan al
// revés que el texto porque la pregunta también es al revés: de un nombre se busca la A, de una
// cantidad y de una fecha se busca lo más grande y lo más nuevo.
// Origen (propio/externo), Sede, Depósito, Reserva y Mostrador son columnas de una organización
// (`org`): en uso personal todo es propio, hay una sola sede y no hay mesa. Al revés, «Cantidad
// inicial» es sólo de uso personal (`personal`): sin mesa, lo que se mira es cuánto entró contra
// cuánto queda. La fila las esconde con la misma condición.
const COLUMNAS_INV_TODAS = [
  { campo: 'codigo',           label: 'Código',          dir: 'asc' },
  { campo: 'tipo',             label: 'Tipo',            dir: 'asc' },
  { campo: 'origen',           label: 'Origen',          dir: 'asc',  org: true },
  { campo: 'genetica',         label: 'Genética',        dir: 'asc' },
  { campo: 'lote',             label: 'Lote',            dir: 'asc' },
  { campo: 'sede',             label: 'Sede',            dir: 'asc',  org: true },
  { campo: 'ingreso',          label: 'Ingresó',         dir: 'desc' },
  { campo: 'observaciones',    label: 'Observaciones',   dir: 'asc' },
  { campo: 'precio',           label: '$ sugerido',      dir: 'desc', num: true, org: true },
  { campo: 'cantidad_inicial', label: 'Cantidad inicial', dir: 'desc', num: true, personal: true },
  { campo: 'deposito',         label: 'Depósito',        dir: 'desc', num: true, org: true },
  { campo: 'reserva',          label: 'Reserva',         dir: 'desc', num: true, org: true },
  { campo: 'mostrador',        label: 'Mostrador',       dir: 'desc', num: true, org: true },
  { campo: 'actual',           label: 'Actual',          dir: 'desc', num: true },
]
const columnas = computed(() => COLUMNAS_INV_TODAS.filter(c => props.esPersonal ? !c.org : !c.personal))

// LO QUE SE PUEDE ENTREGAR HOY: el mismo número que valida el backend y que muestra el carrito.
// La mesa NO se resta —es un LUGAR, no un compromiso: administración dispensa igual de un frasco
// que está arriba, y la dispensa baja la mesa sola—. Restándola, un stock entero cargado al
// mostrador se leía como "0.0g" en rojo mientras el KPI de arriba decía que había 18: la pantalla
// contradiciéndose consigo misma. Dónde está cada gramo lo dice la columna Mostrador.
const disponible = s => s.disponible_para_entregar ?? s.cantidad_disponible_real ?? s.cantidad ?? 0

// ¿Se está ordenando por cantidad con unidades distintas en la lista? Es el caso en que el orden
// no significa nada, y el único momento en que hace falta decirlo.
const mezclaUnidades = computed(() => {
  if (!['actual', 'cantidad_inicial', 'deposito', 'reserva', 'mostrador'].includes(props.orden.campo)) return false
  const unidades = new Set(props.stocks.map(s => s.unidad || 'g'))
  return unidades.size > 1
})

function ordenar (campo) {
  const col = columnas.value.find(c => c.campo === campo)
  emit('update:orden', props.orden.campo === campo
    ? { campo, dir: props.orden.dir === 'asc' ? 'desc' : 'asc' }
    : { campo, dir: col?.dir || 'asc' })
}

function formatDate (dateStr) {
  return new Date(dateStr).toLocaleDateString('es-AR', { day: '2-digit', month: '2-digit', year: '2-digit' })
}
</script>

<template>
  <div>
  <div class="stk__inv-table-wrap">
    <table class="stk__inv-table">
      <!-- TODAS LAS COLUMNAS ORDENAN, y el orden lo hace el SERVIDOR: esta tabla la
           pagina el backend, así que ordenar en el navegador acomodaría los 25 renglones
           de la página y diría «ordenado por cantidad» mostrando los 25 de siempre.
           · El código va primero: es lo único que identifica una fila. Sin él, tres
             compras externas de flor seca son tres renglones idénticos.
           · «Observaciones» es lo que se escribió al cargar el producto (`descripcion`). -->
      <thead>
        <tr>
          <th v-for="c in columnas" :key="c.campo"
              :class="['stk__inv-th', c.num ? 'stk__inv-num' : '',
                       orden.campo === c.campo ? 'is-activa' : '']"
              :aria-sort="orden.campo === c.campo
                          ? (orden.dir === 'asc' ? 'ascending' : 'descending') : 'none'">
            <button type="button" class="stk__inv-th-btn" @click="ordenar(c.campo)">
              {{ c.label }}
              <span v-if="orden.campo === c.campo" class="stk__inv-caret">{{ orden.dir === 'asc' ? '▲' : '▼' }}</span>
            </button>
          </th>
        </tr>
      </thead>
      <tbody>
        <tr
          v-for="s in stocks" :key="s.id"
          class="stk__inv-trow" :class="{ 'stk__inv-trow--flash': flashIds.has(s.id), 'stk__inv-trow--abrible': abrible }"
          @click="abrible && emit('abrir', s)"
        >
          <td class="stk__inv-td-cod">{{ s.numero_lote_producto || '—' }}</td>
          <td class="stk__inv-td-tipo">{{ formaLabel(s.forma_producto) }}</td>
          <td v-if="!esPersonal">
            <span class="stk__chip" :class="s.regulatorio ? 'stk__chip--propio' : 'stk__chip--ext'">
              {{ s.regulatorio ? 'Propio' : 'Externo' }}
            </span>
          </td>
          <td class="stk__inv-td-cepa">{{ s.lote?.genetica?.nombre || s.genetica?.nombre || '—' }}</td>
          <td>
            <span v-if="s.lote" class="stk__chip stk__chip--lote">{{ s.lote.codigo }}</span>
            <span v-else-if="!s.regulatorio || s.origen === 'compra_externa'" class="stk__chip stk__chip--ext">Externo</span>
            <span v-else class="stk__inv-td-mono">—</span>
          </td>
          <td v-if="!esPersonal">{{ s.sede?.nombre || 'Sin asignar' }}</td>
          <td class="stk__inv-td-fecha">{{ formatDate(s.created_at) }}</td>
          <td class="stk__inv-td-obs" :title="s.descripcion || ''">
            <span v-if="s.descripcion">{{ s.descripcion }}</span>
            <span v-else class="stk__inv-td-mono">—</span>
          </td>
          <!-- EL PRECIO SUGERIDO, POR UNIDAD: el mismo que usa el carrito de la dispensa. Sin
               precio se dice, apagado: es justo lo que el admin viene a buscar mirando. -->
          <td v-if="!esPersonal" class="stk__inv-num stk__inv-td-precio" :class="{ 'stk__inv-td-precio--sin': !s.precio_sugerido_ars }">
            <template v-if="s.precio_sugerido_ars">{{ formatARS(s.precio_sugerido_ars) }}/{{ s.unidad || 'g' }}</template>
            <template v-else>Sin precio</template>
          </td>
          <!-- En uso personal no hay mesa: todo está guardado, y lo que se mira es cuánto
               entró contra cuánto queda. -->
          <td v-if="esPersonal" class="stk__inv-num stk__inv-td-cosechado">
            {{ s.cantidad_inicial != null ? s.cantidad_inicial.toFixed(1) + (s.unidad || 'g') : '—' }}
          </td>
          <!-- DÓNDE ESTÁ CADA GRAMO: Depósito + Mostrador = lo que hay. «Depósito» NO es la
               cantidad inicial —eso es lo que entró y no baja nunca—: es el frasco menos la
               mesa, y lo calcula el backend. La reserva sale de la mesa, así que está ADENTRO
               de Mostrador; va al lado para que se lea qué parte de la mesa ya tiene dueño. -->
          <td v-if="!esPersonal" class="stk__inv-num stk__inv-td-mesa stk__inv-td-deposito" :class="{ 'stk__inv-td-mesa--cero': !s.en_deposito_g }">
            {{ (s.en_deposito_g || 0).toFixed(1) }}{{ s.unidad || 'g' }}
          </td>
          <td v-if="!esPersonal" class="stk__inv-num stk__inv-td-mesa stk__inv-td-reserva" :class="{ 'stk__inv-td-mesa--cero': !s.reservado }">
            {{ (s.reservado || 0).toFixed(1) }}{{ s.unidad || 'g' }}
          </td>
          <!-- DÓNDE ESTÁ EL PRODUCTO, que es otra pregunta que cuánto hay. Siempre, y
               también en cero apagado: un número que aparece de la nada el día que alguien
               carga la mesa no se aprende a mirar. -->
          <td v-if="!esPersonal" class="stk__inv-num stk__inv-td-mesa" :class="{ 'stk__inv-td-mesa--cero': !s.en_mostrador_g }">
            {{ (s.en_mostrador_g || 0).toFixed(1) }}{{ s.unidad || 'g' }}
          </td>
          <td class="stk__inv-num stk__inv-td-actual" :class="{ 'stk__inv-td-bajo': s.forma_producto === 'flor_seca' && umbral != null && disponible(s) < umbral }">
            {{ disponible(s).toFixed(1) }}{{ s.unidad || 'g' }}
          </td>
        </tr>
      </tbody>
    </table>
  </div>

  <!-- ORDENAR NÚMEROS DE COSAS DISTINTAS NO CONTESTA NADA. 2.278 g de flor arriba de 320
       prerolls no es «más»: son dos cosas que no se comparan, y el orden se lee como que
       está roto. No se bloquea —a veces se ordena igual, para agrupar— pero se dice, y se
       dice dónde se arregla: el filtro de tipo está tres centímetros más arriba. -->
  <p v-if="mezclaUnidades" class="stk__inv-aviso">
    Estás ordenando por cantidad con <strong>gramos y unidades mezclados</strong>: 300 g y
    300 prerolls no se comparan. Filtrá por tipo para que el orden signifique algo.
  </p>
  </div>
</template>

<style scoped>
.stk__chip {
  font-size: .68rem; font-weight: 600; padding: .2em .6em; border-radius: 5px;
  background: var(--c-slate-100); color: var(--c-slate-600); border: 1px solid var(--c-slate-200);
}
.stk__chip--lote { background: #eff6ff; color: #1d4ed8; border-color: #bfdbfe; }
.stk__chip--ext  { background: #fef3c7; color: #92400e; border-color: #fde68a; }
.stk__chip--propio { background: #dcfce7; color: #15803d; border-color: #bbf7d0; }
.stk__inv-table-wrap {
  border: 1px solid var(--c-slate-200); border-radius: 12px;
  overflow: hidden; overflow-x: auto; margin-bottom: 1rem;
}
.stk__inv-table { width: 100%; border-collapse: collapse; font-size: .84rem; }
.stk__inv-table th {
  text-align: left; font-size: .68rem; font-weight: 700; text-transform: uppercase; letter-spacing: .04em;
  color: var(--c-slate-500); background: var(--c-slate-50); border-bottom: 2px solid var(--c-slate-200); white-space: nowrap;
}
/* El padding pasa al botón para que TODO el ancho del cabezal sea clickeable: un área de click
   más chica que la celda se siente como que a veces no anda. */
.stk__inv-th { padding: 0; }
.stk__inv-th-btn {
  width: 100%; border: 0; background: transparent; cursor: pointer;
  padding: .6rem .6rem; text-align: inherit;
  font: inherit; color: inherit; text-transform: inherit; letter-spacing: inherit;
}
.stk__inv-th-btn:hover { color: var(--c-slate-700); }
.stk__inv-th.is-activa .stk__inv-th-btn { color: var(--c-leaf-800); }
.stk__inv-caret { font-size: 9px; margin-left: 3px; }
/* El aviso de unidades mezcladas: es una aclaración, no una alarma. */
.stk__inv-aviso {
  margin: .6rem 0 0; font-size: .78rem; color: var(--c-slate-600);
  background: var(--c-slate-50); border-left: 3px solid var(--c-slate-300);
  border-radius: 0 8px 8px 0; padding: .5rem .7rem;
}
.stk__inv-aviso strong { color: var(--c-slate-700); }
.stk__inv-table td { padding: .6rem .6rem; border-bottom: 1px solid var(--c-slate-100); color: var(--c-slate-700); vertical-align: middle; }
.stk__inv-table tbody tr:last-child td { border-bottom: none; }
.stk__inv-num { text-align: right; }
.stk__inv-trow { transition: background .12s; }
.stk__inv-trow--abrible { cursor: pointer; }
.stk__inv-trow--abrible:hover { background: #f6faf4; }
.stk__inv-trow--flash { animation: stkRowFlash .6s ease-out; }
@keyframes stkRowFlash { 0% { background: #dcfce7; } 100% { background: transparent; } }
.stk__inv-td-cod  { font-family: var(--font-mono, monospace); font-size: .8rem; font-weight: 700; color: var(--c-slate-900); white-space: nowrap; }
.stk__inv-td-tipo { font-weight: 600; color: var(--c-slate-900); white-space: nowrap; }
.stk__inv-td-cepa { font-style: italic; color: var(--c-slate-600); }
.stk__inv-td-obs { max-width: 160px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; color: var(--c-slate-500); font-size: .78rem; }
.stk__inv-td-mono { font-family: var(--font-mono, monospace); font-size: .8rem; color: var(--c-slate-600); }
.stk__inv-td-fecha { white-space: nowrap; color: var(--c-slate-500); }
.stk__inv-td-cosechado { color: var(--c-slate-500); font-weight: 600; white-space: nowrap; }
.stk__inv-td-actual { font-weight: 800; color: #15803d; white-space: nowrap; }
.stk__inv-td-mesa, .stk__inv-td-deposito, .stk__inv-td-reserva { font-weight: 700; color: var(--c-slate-700); white-space: nowrap; }
.stk__inv-td-mesa--cero { font-weight: 500; color: var(--c-slate-400); }
.stk__inv-td-precio { font-weight: 700; color: var(--c-slate-700); white-space: nowrap; }
.stk__inv-td-precio--sin { font-weight: 500; color: var(--c-slate-400); }
.stk__inv-td-bajo { color: #dc2626 !important; }
@media (max-width: 640px) {
  /* 5, no 4: la columna Código se sumó adelante y corrió a Lote un lugar. */
  .stk__inv-td-mono, .stk__inv-table th:nth-child(5) { display: none; }
}
</style>
