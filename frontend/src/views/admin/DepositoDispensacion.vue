<script setup>
// Depósito de Dispensación (solo lectura): la flor seca y sus derivados (modelo Stock). NO se
// edita acá — el stock entra por Cosecha/Manicura y sale por Dispensación. Esta vista lo trae a
// la pantalla de Depósito para verlo junto a los demás. Respeta el filtro de sede del padre.
import { ref, computed, watch, onMounted } from 'vue'
import { listStocks } from '../../lib/api.js'

const props = defineProps({ sedeId: { type: [Number, null], default: null } })

const stocks  = ref([])
const loading = ref(false)

const FORMA_LABEL = {
  flor_seca: 'Flor seca', hash: 'Hash', aceite: 'Aceite', tintura: 'Tintura',
  crema: 'Crema', capsula: 'Cápsulas', comestible: 'Comestible', prensado: 'Prensado',
  preroll: 'Prerolls', otro: 'Otro', externo: 'Externo',
}
const formaLabel = (f) => FORMA_LABEL[f] || f || '—'
const nOf = (n) => Number(n || 0)
const fmtG = (n) => `${nOf(n).toLocaleString('es-AR', { maximumFractionDigits: 1 })}`

async function cargar() {
  loading.value = true
  try {
    const { data } = await listStocks(props.sedeId != null ? { sede_id: props.sedeId } : {})
    stocks.value = Array.isArray(data) ? data : (data?.stocks || [])
  } catch { stocks.value = [] }
  finally { loading.value = false }
}
onMounted(cargar)
watch(() => props.sedeId, cargar)

// Nombre legible de cada renglón: genética/lote cuando hay; si no, la descripción.
function nombre(s) {
  return s.genetica_nombre || s.descripcion || (s.lote_codigo ? `Lote ${s.lote_codigo}` : formaLabel(s.forma_producto))
}

const flor = computed(() => stocks.value.filter(s => s.forma_producto === 'flor_seca'))
const derivados = computed(() => stocks.value.filter(s => s.forma_producto !== 'flor_seca'))

const kpis = computed(() => ({
  florDisponible: flor.value.reduce((a, s) => a + nOf(s.cantidad_disponible_real), 0),
  florReservada:  flor.value.reduce((a, s) => a + nOf(s.gramos_reservados), 0),
  derivados:      derivados.value.length,
}))

// Orden de presentación: flor seca primero, después derivados; dentro, por vencimiento próximo.
const ordenados = computed(() =>
  [...stocks.value].sort((a, b) => {
    if ((a.forma_producto === 'flor_seca') !== (b.forma_producto === 'flor_seca'))
      return a.forma_producto === 'flor_seca' ? -1 : 1
    return (a.dias_para_vencimiento ?? 1e9) - (b.dias_para_vencimiento ?? 1e9)
  }))

const vencCls = (s) =>
  s.estado_vencimiento === 'vencido' ? 'is-venc'
  : s.estado_vencimiento === 'por_vencer' ? 'is-porvencer' : ''
</script>

<template>
  <div class="dd">
    <div class="dd__banner">
      <i class="bi bi-lock"></i>
      <span>Solo lectura. La flor entra por <b>Cosecha/Manicura</b> y sale por <b>Dispensación</b> — desde acá no se edita.</span>
    </div>

    <div class="dd__summary">
      <div class="dd__kpi">
        <span class="dd__kpi-label">Flor seca disponible</span>
        <span class="dd__kpi-val">{{ fmtG(kpis.florDisponible) }} <small>g</small></span>
      </div>
      <div class="dd__kpi">
        <span class="dd__kpi-label">Reservada</span>
        <span class="dd__kpi-val">{{ fmtG(kpis.florReservada) }} <small>g</small></span>
      </div>
      <div class="dd__kpi">
        <span class="dd__kpi-label">Derivados</span>
        <span class="dd__kpi-val">{{ kpis.derivados }} <small>items</small></span>
      </div>
    </div>

    <div v-if="loading" class="dd__empty">Cargando flor…</div>
    <div v-else-if="!stocks.length" class="dd__empty dd__empty--box">
      No hay stock de dispensación en este alcance. La flor aparece acá cuando se cosecha y asigna.
    </div>

    <div v-else class="dd__table-wrap">
      <table class="dd__table">
        <thead>
          <tr>
            <th>Producto</th>
            <th>Forma</th>
            <th>Lote / origen</th>
            <th class="ta-r">Disponible</th>
            <th class="ta-r">Reservado</th>
            <th>Vencimiento</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="s in ordenados" :key="s.id">
            <td><span class="dd__name">{{ nombre(s) }}</span></td>
            <td><span class="dd__forma">{{ formaLabel(s.forma_producto) }}</span></td>
            <td class="mut">{{ s.lote_codigo || (s.origen === 'compra_externa' ? 'Externo' : '—') }}</td>
            <td class="ta-r num"><b>{{ fmtG(s.cantidad_disponible_real) }}</b> <small class="mut">{{ s.unidad || 'g' }}</small></td>
            <td class="ta-r num mut">{{ nOf(s.gramos_reservados) ? fmtG(s.gramos_reservados) + ' ' + (s.unidad || 'g') : '—' }}</td>
            <td :class="vencCls(s)">
              <template v-if="s.fecha_vencimiento_est">
                {{ s.fecha_vencimiento_est }}
                <small v-if="s.estado_vencimiento === 'vencido'"> · vencido</small>
                <small v-else-if="s.estado_vencimiento === 'por_vencer'"> · {{ s.dias_para_vencimiento }}d</small>
              </template>
              <span v-else class="mut">—</span>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>

<style scoped>
.dd { display: flex; flex-direction: column; gap: 1rem; }
.dd__banner { display: flex; align-items: center; gap: .5rem; font-size: .8rem; color: #475569; background: #f1f5f9; border: 1px solid #e2e8f0; border-radius: 10px; padding: .6rem .85rem; line-height: 1.4; }
.dd__banner .bi { color: #64748b; }

.dd__summary { display: flex; gap: 2.5rem; background: #fff; border: 1px solid #e8edf2; border-radius: 13px; padding: 1rem 1.4rem; box-shadow: 0 1px 2px rgb(15 23 42 / .04); }
.dd__kpi { display: flex; flex-direction: column; gap: .15rem; }
.dd__kpi-label { font-size: .64rem; text-transform: uppercase; letter-spacing: .08em; color: #94a3b8; font-weight: 700; }
.dd__kpi-val { font-size: 1.35rem; font-weight: 800; letter-spacing: -.03em; color: #0f172a; font-variant-numeric: tabular-nums; }
.dd__kpi-val small { font-size: .8rem; font-weight: 600; color: #94a3b8; }

.dd__table-wrap { overflow-x: auto; border: 1px solid #e8edf2; border-radius: 13px; box-shadow: 0 1px 2px rgb(15 23 42 / .04); }
.dd__table { width: 100%; border-collapse: collapse; font-size: .88rem; background: #fff; }
.dd__table thead th { text-align: left; font-size: .68rem; text-transform: uppercase; letter-spacing: .05em; color: #94a3b8; font-weight: 700; padding: .7rem 1rem; border-bottom: 1.5px solid #eef2f6; white-space: nowrap; }
.dd__table td { padding: .7rem 1rem; border-bottom: 1px solid #f1f5f9; vertical-align: middle; }
.dd__table tbody tr:hover { background: #f8fafc; }
.dd__table tbody tr:last-child td { border-bottom: none; }
.dd__table .ta-r { text-align: right; }
.dd__name { font-weight: 650; color: #0f172a; }
.dd__forma { display: inline-block; font-size: .72rem; font-weight: 600; color: #1b5e20; background: rgb(27 94 32 / .07); border-radius: 999px; padding: .15rem .55rem; }
.num { font-variant-numeric: tabular-nums; }
.mut { color: #94a3b8; }
.is-porvencer { color: #b45309; font-weight: 600; }
.is-venc { color: #dc2626; font-weight: 600; }

.dd__empty { color: #94a3b8; padding: 2.5rem; text-align: center; font-size: .9rem; }
.dd__empty--box { background: #fbfcfd; border: 1px dashed #e2e8f0; border-radius: 14px; }
</style>
