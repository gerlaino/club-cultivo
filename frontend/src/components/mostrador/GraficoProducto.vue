<template>
  <figure class="gpr">
    <figcaption class="gpr__hd">
      <span class="gpr__t">
        {{ producto.etiqueta }}
        <span v-if="producto.numero" class="gpr__num">{{ producto.numero }}</span>
      </span>
      <span v-if="producto.sin_diferencias" class="gpr__n gpr__n--ok">está todo</span>
      <span v-else class="gpr__n">
        −{{ fmt(producto.falta) }} {{ producto.unidad }}
        <em v-if="producto.peor">el peor día {{ fecha(producto.peor.fecha) }}</em>
      </span>
    </figcaption>
    <svg :viewBox="`0 0 ${ANCHO} ${ALTO}`" class="gpr__svg" role="img" :aria-label="rotulo">
      <polygon v-if="!producto.sin_diferencias" :points="hueco" fill="var(--c-amber-500, #f59e0b)" opacity=".25" />
      <polyline :points="linea('esperado')" fill="none" stroke="var(--c-ink-400, #9aa0aa)"
                stroke-width="1.4" stroke-dasharray="4 3" />
      <polyline :points="linea('contado')" fill="none" stroke="var(--c-leaf-600, #16a34a)" stroke-width="2" />
      <circle v-for="(pt, i) in puntosPeores" :key="i" :cx="pt.x" :cy="pt.y" r="3.4" fill="var(--c-amber-600, #d97706)" />
      <text :x="8" :y="ALTO - 3" fill="var(--c-ink-400, #9aa0aa)" font-size="8.5">
        {{ fecha(producto.puntos[0]?.fecha) }}
      </text>
      <text :x="ANCHO - 8" :y="ALTO - 3" text-anchor="end" fill="var(--c-ink-700, #374151)" font-size="8.5" font-weight="600">
        {{ fecha(producto.puntos[producto.puntos.length - 1]?.fecha) }}
      </text>
    </svg>
  </figure>
</template>

<script setup>
// LO QUE TENÍA QUE HABER CONTRA LO QUE SE CONTÓ, para UN frasco, cierre por cierre.
//
// Idea de Germán, y resuelve el problema de fondo: un total tendría que sumar gramos de flor con
// unidades de preroll, y eso da un número que no significa nada — es la razón por la que el resto
// del módulo mide en plata.
//
// Y cada frasco con SU ESCALA, que es lo que decide el diseño. En un eje compartido con la flor a
// 400 g, el gramo que gotea la Northern todos los días NO EXISTE — y ése es justamente el que
// sangra sin disparar ninguna alarma. El desplome de 23 g se ve en cualquier gráfico; el goteo
// sólo se ve así.
//
// Vivía en una solapa propia («Producto por producto») con su propio filtro de fecha. Era Merma
// con otro corte: ahora es el DETALLE de cada fila de Merma, que se abre donde se está mirando el
// número que hay que explicar.
import { computed } from 'vue'

const props = defineProps({ producto: { type: Object, required: true } })

const ANCHO = 260
const ALTO  = 96
const MARGEN = { x: 10, arriba: 10, abajo: 22 }

const fmt = (n) => Number(n ?? 0).toLocaleString('es-AR', { maximumFractionDigits: 1 })
const fecha = (iso) => (iso ? new Date(`${iso}T12:00:00`).toLocaleDateString('es-AR', { day: '2-digit', month: '2-digit' }) : '')

// LA ESCALA ES DE CADA PRODUCTO. Se toma el rango de sus dos series con un respiro arriba y
// abajo: sin ese margen, el día más alto queda pegado al borde y el hueco se corta.
const escala = computed(() => {
  const p = props.producto
  const vals = p.puntos.flatMap(x => [x.esperado, x.contado])
  const min = Math.min(...vals), max = Math.max(...vals)
  const aire = (max - min) * 0.15 || Math.max(max * 0.02, 1)
  const lo = min - aire, hi = max + aire
  const alto = ALTO - MARGEN.arriba - MARGEN.abajo
  const paso = p.puntos.length > 1 ? (ANCHO - MARGEN.x * 2) / (p.puntos.length - 1) : 0
  return {
    x: (i) => MARGEN.x + i * paso,
    y: (v) => MARGEN.arriba + (hi === lo ? alto / 2 : (hi - v) / (hi - lo) * alto),
  }
})

const linea = (campo) => {
  const e = escala.value
  return props.producto.puntos.map((pt, i) => `${e.x(i).toFixed(1)},${e.y(pt[campo]).toFixed(1)}`).join(' ')
}

// El hueco entre las dos: se cierra el polígono con la serie de vuelta. Es lo que se viene a ver.
const hueco = computed(() => {
  const e = escala.value
  const arriba = props.producto.puntos.map((pt, i) => `${e.x(i).toFixed(1)},${e.y(pt.esperado).toFixed(1)}`)
  const abajo  = props.producto.puntos.map((pt, i) => `${e.x(i).toFixed(1)},${e.y(pt.contado).toFixed(1)}`).reverse()
  return [...arriba, ...abajo].join(' ')
})

// El peor día marcado: es adónde va el ojo, y sin eso hay que recorrer la línea buscándolo.
const puntosPeores = computed(() => {
  const p = props.producto
  if (!p.peor) return []
  const e = escala.value
  const i = p.puntos.findIndex(x => x.fecha === p.peor.fecha)
  return i < 0 ? [] : [{ x: e.x(i), y: e.y(p.puntos[i].contado) }]
})

const rotulo = computed(() => {
  const p = props.producto
  if (p.sin_diferencias) return `${p.etiqueta}: lo contado coincidió con lo que tenía que haber todos los días.`
  return `${p.etiqueta}: faltaron ${fmt(p.falta)} ${p.unidad} en el período` +
    (p.peor ? `, ${fmt(p.peor.falta)} ${p.unidad} el ${fecha(p.peor.fecha)}.` : '.')
})
</script>

<style scoped>
.gpr {
  margin: 0; border: 1px solid var(--c-slate-200); border-radius: 11px;
  padding: 11px 12px 4px; background: #fff;
}
.gpr__hd { display: flex; justify-content: space-between; align-items: baseline; gap: 10px; flex-wrap: wrap; margin-bottom: 2px; }
.gpr__t { font-size: var(--fs-13); font-weight: 700; color: var(--c-ink-900); }
.gpr__num { font-family: var(--font-mono); font-weight: 500; color: var(--c-ink-500); margin-left: 6px; font-size: var(--fs-12); }
.gpr__n {
  font-family: var(--font-mono); font-size: var(--fs-12); font-weight: 700;
  color: var(--c-amber-700, #b45309); white-space: nowrap;
}
/* La merma es un dato, no una falta de alguien: ámbar, nunca rojo. */
.gpr__n em { font-style: normal; font-weight: 400; color: var(--c-ink-500); margin-left: 4px; }
.gpr__n--ok { color: var(--c-leaf-600, #16a34a); }
.gpr__svg { width: 100%; height: auto; display: block; }
</style>
