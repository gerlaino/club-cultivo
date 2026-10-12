<script setup>
// RESUMEN DE STOCK POR PRODUCTO (12-oct-2026, en lugar de las tarjetas de KPI). Una fila por
// producto y unidad: los gramos nunca se suman con las unidades. Todo lo calcula
// `Stocks::ResumenPorProducto` en el servidor; acá sólo se muestra.
import { formaLabel } from '../../lib/formatters.js'

defineProps({
  filas:     { type: Array, default: () => [] },
  // En autocultivo no hay mostrador ni reservas: esas columnas no dicen nada.
  personal:  { type: Boolean, default: false },
})

const cant = (n, u) => `${Number(n || 0).toLocaleString('es-AR', { maximumFractionDigits: 1 })} ${u === 'un' ? 'un' : u || ''}`.trim()
function alcanza (f) {
  if (f.alcanza_dias == null) return 'Sin salidas'
  if (f.alcanza_dias > 365) return 'Más de un año'
  return `${f.alcanza_dias} ${f.alcanza_dias === 1 ? 'día' : 'días'}`
}
</script>

<template>
  <section class="rpp">
    <header class="rpp__hd">
      <h2 class="rpp__h2">Resumen por producto</h2>
      <span class="rpp__sub">Una fila por producto y unidad: nunca se suman entre sí</span>
    </header>
    <p v-if="!filas.length" class="rpp__vacio">No hay stock en inventario.</p>
    <div v-else class="rpp__wrap">
      <table class="rpp__tabla">
        <thead>
          <tr>
            <th scope="col">Producto</th>
            <th scope="col" class="der" title="Cuántos lotes de stock hay de este producto">Stocks</th>
            <th scope="col" class="der" title="Guardado, fuera de la mesa del mostrador">En depósito</th>
            <th v-if="!personal" scope="col" class="der" title="Sobre la mesa de los mostradores, listo para dispensar">En mostrador</th>
            <th v-if="!personal" scope="col" class="der" title="Prometido a reservas de pacientes y a eventos">Comprometido</th>
            <th scope="col" class="der" title="Depósito + mostrador − comprometido: lo que se puede entregar">Disponible</th>
            <th scope="col" class="der" title="Cuántos días dura lo disponible al ritmo de lo dispensado en los últimos 28 días">Alcanza para</th>
            <th scope="col" title="Vencimientos y sedes por debajo del umbral de stock bajo">Atención</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="f in filas" :key="`${f.forma}-${f.unidad}`">
            <td><b>{{ formaLabel(f.forma) }}</b> <span class="rpp__u">({{ f.unidad }})</span></td>
            <td class="der num">{{ f.stocks }}</td>
            <td class="der num">{{ cant(f.en_deposito, f.unidad) }}</td>
            <td v-if="!personal" class="der num">{{ cant(f.en_mostrador, f.unidad) }}</td>
            <td v-if="!personal" class="der num">{{ cant(f.comprometido, f.unidad) }}</td>
            <td class="der num rpp__disp">{{ cant(f.disponible, f.unidad) }}</td>
            <td class="der num" :class="{ 'rpp__muted': f.alcanza_dias == null, 'rpp__corto': f.alcanza_dias != null && f.alcanza_dias < 14 }"
                :title="f.alcanza_dias != null ? `Promedio dispensado: ${cant(f.dispensa_diaria, f.unidad)} por día` : 'No hubo dispensas en los últimos 28 días'">
              {{ alcanza(f) }}
            </td>
            <td :class="f.atencion?.length ? 'rpp__aviso' : 'rpp__muted'">{{ f.atencion?.length ? f.atencion.join(' · ') : '—' }}</td>
          </tr>
        </tbody>
      </table>
    </div>
    <p class="rpp__pie">Disponible = en depósito{{ personal ? '' : ' + en mostrador − comprometido (reservas y eventos)' }}. «Alcanza para» usa el ritmo de los últimos 28 días.</p>
  </section>
</template>

<style scoped>
.rpp { background: white; border: 1px solid var(--c-leaf-100); border-radius: 16px; margin-bottom: 1.5rem; overflow: hidden; }
.rpp__hd { display: flex; flex-wrap: wrap; align-items: baseline; justify-content: space-between; gap: 4px 16px; padding: 16px 20px 10px; }
.rpp__h2 { margin: 0; font-family: var(--font-display); font-size: 17px; font-weight: 600; color: var(--c-ink-900); }
.rpp__sub, .rpp__pie { font-size: var(--fs-12); color: var(--c-ink-500); }
.rpp__pie { margin: 0; padding: 10px 20px 14px; }
.rpp__vacio { margin: 0; padding: 4px 20px 16px; font-size: var(--fs-13); color: var(--c-ink-500); }
.rpp__wrap { overflow-x: auto; }
.rpp__tabla { width: 100%; border-collapse: collapse; font-size: var(--fs-13); }
.rpp__tabla th { padding: 9px 12px; text-align: left; font-size: var(--fs-12); font-weight: 600; color: var(--c-ink-500); border-top: 1px solid var(--c-leaf-50); border-bottom: 1px solid var(--c-leaf-100); white-space: nowrap; cursor: help; }
.rpp__tabla td { padding: 11px 12px; border-bottom: 1px solid var(--c-leaf-50); color: var(--c-ink-900); white-space: nowrap; }
.rpp__tabla th:first-child, .rpp__tabla td:first-child { padding-left: 20px; }
.rpp__tabla th:last-child, .rpp__tabla td:last-child { padding-right: 20px; white-space: normal; min-width: 180px; }
.rpp__tabla th.der, .der { text-align: right; }
.num { font-family: var(--font-mono); font-variant-numeric: tabular-nums; }
.rpp__u { color: var(--c-ink-500); font-weight: 400; }
.rpp__disp { font-weight: 600; }
.rpp__muted { color: var(--c-ink-500); }
.rpp__corto { color: var(--c-gold-500); font-weight: 600; }
.rpp__aviso { color: var(--c-gold-500); }
</style>
