<template>
  <div class="evo">
    <div class="evo__filtros">
      <label class="evo__campo">Desde
        <input v-model="rango.desde" type="date" class="evo__inp" @change="cargar" />
      </label>
      <label class="evo__campo">Hasta
        <input v-model="rango.hasta" type="date" class="evo__inp" @change="cargar" />
      </label>
    </div>

    <p v-if="cargando" class="evo__vacio">Buscando…</p>
    <p v-else-if="!conDiferencia.length && !sinDiferencia.length" class="evo__vacio">
      Todavía no hay cierres en este período.
    </p>

    <template v-else>
      <p class="evo__intro">
        Cada producto con <b>su propia escala</b>: la línea punteada es lo que tenía que haber, la
        llena lo que se contó, y el hueco entre las dos es lo que faltó.
      </p>

      <p v-if="!conDiferencia.length" class="evo__vacio">
        No falta nada en este período.
      </p>

      <div v-else class="evo__grid">
        <figure v-for="p in conDiferencia" :key="p.stock_id" class="evo__mini">
          <figcaption class="evo__mini-hd">
            <span class="evo__mini-t">{{ p.etiqueta }}</span>
            <span class="evo__mini-n">
              −{{ fmt(p.falta) }} {{ p.unidad }}
              <em v-if="p.peor">el peor día {{ fecha(p.peor.fecha) }}</em>
            </span>
          </figcaption>
          <svg :viewBox="`0 0 ${ANCHO} ${ALTO}`" class="evo__svg" role="img" :aria-label="rotulo(p)">
            <polygon :points="hueco(p)" fill="var(--c-amber-500, #f59e0b)" opacity=".25" />
            <polyline :points="linea(p, 'esperado')" fill="none" stroke="var(--c-ink-400, #9aa0aa)"
                      stroke-width="1.4" stroke-dasharray="4 3" />
            <polyline :points="linea(p, 'contado')" fill="none" stroke="var(--c-leaf-600, #16a34a)"
                      stroke-width="2" />
            <circle v-for="(pt, i) in puntosPeores(p)" :key="i" :cx="pt.x" :cy="pt.y" r="3.4"
                    fill="var(--c-amber-600, #d97706)" />
            <text :x="8" :y="ALTO - 3" fill="var(--c-ink-400, #9aa0aa)" font-size="8.5">
              {{ fecha(p.puntos[0]?.fecha) }}
            </text>
            <text :x="ANCHO - 8" :y="ALTO - 3" text-anchor="end" fill="var(--c-ink-700, #374151)"
                  font-size="8.5" font-weight="600">
              {{ fecha(p.puntos[p.puntos.length - 1]?.fecha) }}
            </text>
          </svg>
        </figure>
      </div>

      <!-- Lo que siempre cuadra no ocupa lugar: si no, la pantalla son doce gráficos planos y hay
           que mirarlos todos para descubrir que no pasa nada. -->
      <button v-if="sinDiferencia.length" class="evo__mas" :aria-expanded="String(verTodos)"
              @click="verTodos = !verTodos">
        <i :class="verTodos ? 'bi bi-chevron-down' : 'bi bi-chevron-right'"></i>
        {{ sinDiferencia.length }}
        producto{{ sinDiferencia.length === 1 ? '' : 's' }} más, sin diferencias en el período
      </button>
      <div v-if="verTodos" class="evo__grid evo__grid--planos">
        <figure v-for="p in sinDiferencia" :key="p.stock_id" class="evo__mini">
          <figcaption class="evo__mini-hd">
            <span class="evo__mini-t">{{ p.etiqueta }}</span>
            <span class="evo__mini-n evo__mini-n--ok">está todo</span>
          </figcaption>
          <svg :viewBox="`0 0 ${ANCHO} ${ALTO}`" class="evo__svg" role="img"
               :aria-label="`${p.etiqueta}: lo contado coincidió con lo que tenía que haber todos los días.`">
            <polyline :points="linea(p, 'contado')" fill="none" stroke="var(--c-leaf-600, #16a34a)"
                      stroke-width="2" />
          </svg>
        </figure>
      </div>
    </template>
  </div>
</template>

<script setup>
// LO QUE TENÍA QUE HABER CONTRA LO QUE SE CONTÓ, PRODUCTO POR PRODUCTO.
//
// Idea de Germán, y resuelve el problema de fondo: un total tendría que sumar gramos de flor con
// unidades de preroll, y eso da un número que no significa nada — es la razón por la que el resto
// del módulo mide en plata.
//
// Y cada uno con SU ESCALA, que es lo que decide el diseño. En un eje compartido con la flor a
// 400 g, el gramo que gotea la Northern todos los días NO EXISTE — y ése es justamente el que
// sangra sin disparar ninguna alarma. El desplome de 23 g se ve en cualquier gráfico; el goteo
// sólo se ve así.
import { ref, computed, watch } from 'vue'
import { getEvolucionMostrador } from '../../lib/api.js'
import { useToast } from '../../composables/useToast.js'

const props = defineProps({ sedeId: { type: Number, default: null } })

const toast    = useToast()
const productos = ref([])
const cargando = ref(false)
const verTodos = ref(false)

// El rango arranca VACÍO y lo completa el backend con el mes en curso en SU zona horaria: con el
// navegador en otra zona, calcularlo acá pedía un mañana donde todavía no cerró nadie.
const rango = ref({ desde: '', hasta: '' })

const conDiferencia = computed(() => productos.value.filter(p => !p.sin_diferencias))
const sinDiferencia = computed(() => productos.value.filter(p => p.sin_diferencias))

const ANCHO = 260
const ALTO  = 96
const MARGEN = { x: 10, arriba: 10, abajo: 22 }

const fmt = (n) => Number(n ?? 0).toLocaleString('es-AR', { maximumFractionDigits: 1 })
const fecha = (iso) => (iso ? new Date(`${iso}T12:00:00`).toLocaleDateString('es-AR', { day: '2-digit', month: '2-digit' }) : '')

// LA ESCALA ES DE CADA PRODUCTO. Se toma el rango de sus dos series con un respiro arriba y
// abajo: sin ese margen, el día más alto queda pegado al borde y el hueco se corta.
function escala (p) {
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
}

const linea = (p, campo) => {
  const e = escala(p)
  return p.puntos.map((pt, i) => `${e.x(i).toFixed(1)},${e.y(pt[campo]).toFixed(1)}`).join(' ')
}

// El hueco entre las dos: se cierra el polígono con la serie de vuelta. Es lo que se viene a ver.
const hueco = (p) => {
  const e = escala(p)
  const arriba = p.puntos.map((pt, i) => `${e.x(i).toFixed(1)},${e.y(pt.esperado).toFixed(1)}`)
  const abajo  = p.puntos.map((pt, i) => `${e.x(i).toFixed(1)},${e.y(pt.contado).toFixed(1)}`).reverse()
  return [...arriba, ...abajo].join(' ')
}

// El peor día marcado: es adónde va el ojo, y sin eso hay que recorrer la línea buscándolo.
function puntosPeores (p) {
  if (!p.peor) return []
  const e = escala(p)
  const i = p.puntos.findIndex(x => x.fecha === p.peor.fecha)
  return i < 0 ? [] : [{ x: e.x(i), y: e.y(p.puntos[i].contado) }]
}

const rotulo = (p) =>
  `${p.etiqueta}: faltaron ${fmt(p.falta)} ${p.unidad} en el período` +
  (p.peor ? `, ${fmt(p.peor.falta)} ${p.unidad} el ${fecha(p.peor.fecha)}.` : '.')

async function cargar () {
  if (!props.sedeId) return
  cargando.value = true
  try {
    const { data } = await getEvolucionMostrador(props.sedeId, { ...rango.value })
    productos.value = data.productos || []
    if (data.desde) rango.value = { desde: data.desde, hasta: data.hasta }
  } catch (e) {
    toast.error(e?.response?.data?.error || 'No se pudo calcular la evolución.')
    productos.value = []
  } finally {
    cargando.value = false
  }
}

watch(() => props.sedeId, cargar, { immediate: true })
</script>

<style scoped>
.evo { display: flex; flex-direction: column; gap: 14px; }
.evo__filtros { display: flex; gap: 12px; flex-wrap: wrap; align-items: flex-end; }
.evo__campo { display: flex; flex-direction: column; gap: 4px; font-size: var(--fs-12); color: var(--c-ink-500); }
.evo__inp {
  font: inherit; font-size: var(--fs-13); padding: 7px 10px;
  border: 1px solid var(--c-slate-200); border-radius: 9px; background: #fff; color: var(--c-ink-900);
}
.evo__vacio { margin: 0; font-size: var(--fs-14); color: var(--c-ink-500); }
.evo__intro { margin: 0; font-size: var(--fs-13); color: var(--c-ink-500); max-width: 72ch; }

.evo__grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(260px, 1fr)); gap: 14px; }
.evo__grid--planos { margin-top: 10px; }
.evo__mini {
  margin: 0; border: 1px solid var(--c-slate-200); border-radius: 11px;
  padding: 11px 12px 4px; background: var(--c-slate-50, #f8fafc);
}
.evo__mini-hd { display: flex; justify-content: space-between; align-items: baseline; gap: 10px; flex-wrap: wrap; margin-bottom: 2px; }
.evo__mini-t { font-size: var(--fs-13); font-weight: 700; color: var(--c-ink-900); }
.evo__mini-n {
  font-family: var(--font-mono); font-size: var(--fs-12); font-weight: 700;
  color: var(--c-amber-700, #b45309); white-space: nowrap;
}
/* La merma es un dato, no una falta de alguien: ámbar, nunca rojo. */
.evo__mini-n em { font-style: normal; font-weight: 400; color: var(--c-ink-500); margin-left: 4px; }
.evo__mini-n--ok { color: var(--c-leaf-600, #16a34a); }
.evo__svg { width: 100%; height: auto; display: block; }

.evo__mas {
  appearance: none; border: 0; background: none; font: inherit; cursor: pointer;
  padding: 6px 2px 0; font-size: var(--fs-13); font-weight: 600; color: var(--c-ink-500);
  display: flex; align-items: center; gap: 8px; text-align: left;
}
.evo__mas:hover { color: var(--c-ink-900); }
</style>
