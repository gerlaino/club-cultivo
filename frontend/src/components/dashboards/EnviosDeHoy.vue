<script setup>
// Los envíos que despachó HOY quien mira, y cómo van. El dispensador armaba el paquete y después
// no sabía si llegó: acá ve pendiente · en viaje · entregado · fallido, y la lista se actualiza
// sola cuando el repartidor lo marca — el timbre viaja por el canal del club que ya existe
// (`envio_actualizado`, ver `Dispensacion#broadcast_envio_actualizado`), no se abre otro.
//
// `compacto` (teléfono): un renglón con el resumen, y la lista al tocarlo. Esa pantalla es
// para buscar a un paciente con alguien enfrente; la lista no puede empujar el buscador.
import { ref, computed, onMounted } from 'vue'
import { useClubStore } from '../../stores/club'
import { getEnviosDelDia } from '../../lib/api.js'
import { useStockChannel } from '../../composables/useStockChannel.js'

const props = defineProps({
  compacto: { type: Boolean, default: false },
  // Administración ve los de todo el equipo; quien atiende, los suyos.
  todos:    { type: Boolean, default: false },
})

const club = useClubStore()
const tieneDelivery = computed(() => club.data?.features?.delivery === true)

const envios   = ref([])
const cargando = ref(true)
const abierto  = ref(!props.compacto)

async function cargar() {
  if (!tieneDelivery.value) { cargando.value = false; return }
  try {
    const { data } = await getEnviosDelDia(props.todos ? { todos: 1 } : {})
    envios.value = data || []
  } catch { /* sin respuesta se queda lo que había */ }
  finally { cargando.value = false }
}

onMounted(cargar)
useStockChannel(null, (ev) => { if (ev?.tipo === 'envio_actualizado') cargar() })

const ESTADO = {
  pendiente: { label: 'Pendiente',  clase: 'pend' },
  en_viaje:  { label: 'En viaje',   clase: 'viaje' },
  entregado: { label: 'Entregado',  clase: 'ok' },
  fallido:   { label: 'No se pudo', clase: 'mal' },
  cancelada: { label: 'Cancelado',  clase: 'mal' },
}
const meta = (e) => ESTADO[e.estado_envio] || { label: e.estado_envio, clase: 'pend' }

const resumen = computed(() => {
  const n = (est) => envios.value.filter(e => e.estado_envio === est).length
  return { total: envios.value.length, viaje: n('en_viaje'), ok: n('entregado'), mal: n('fallido'), pend: n('pendiente') }
})

const hora = (iso) => iso ? new Date(iso).toLocaleTimeString('es-AR', { hour: '2-digit', minute: '2-digit' }) : ''
const fmt  = (n) => new Intl.NumberFormat('es-AR', { style: 'currency', currency: 'ARS', maximumFractionDigits: 0 }).format(n || 0)

defineExpose({ cargar })
</script>

<template>
  <section v-if="tieneDelivery && (cargando || envios.length)" class="edh" :class="{ 'edh--compacto': compacto }">
    <button type="button" class="edh__hd" :class="{ 'edh__hd--btn': compacto }" :aria-expanded="abierto" @click="compacto && (abierto = !abierto)">
      <i class="bi bi-truck edh__ico"></i>
      <span class="edh__title">Envíos de hoy</span>
      <span v-if="!cargando" class="edh__resumen">
        {{ resumen.total }} ·
        <span v-if="resumen.viaje" class="edh__n edh__n--viaje">{{ resumen.viaje }} en viaje</span>
        <span v-if="resumen.ok" class="edh__n edh__n--ok">{{ resumen.ok }} entregado{{ resumen.ok === 1 ? '' : 's' }}</span>
        <span v-if="resumen.mal" class="edh__n edh__n--mal">{{ resumen.mal }} fallido{{ resumen.mal === 1 ? '' : 's' }}</span>
        <span v-if="resumen.pend" class="edh__n">{{ resumen.pend }} pendiente{{ resumen.pend === 1 ? '' : 's' }}</span>
      </span>
      <span v-if="compacto" class="edh__chev">{{ abierto ? '▾' : '▸' }}</span>
    </button>

    <div v-if="cargando" class="edh__muted">Cargando…</div>
    <ul v-else-if="abierto" class="edh__list">
      <li v-for="e in envios" :key="e.id" class="edh__item">
        <span class="edh__estado" :class="`edh__estado--${meta(e).clase}`">{{ meta(e).label }}</span>
        <div class="edh__txt">
          <div class="edh__quien">
            {{ e.paciente?.nombre }}
            <span v-if="e.direccion_etiqueta" class="edh__etq">{{ e.direccion_etiqueta }}</span>
          </div>
          <div class="edh__dir">{{ e.direccion_envio || 'Sin dirección' }}</div>
          <div class="edh__meta">
            <template v-if="e.delivery">{{ e.delivery.nombre }}</template>
            <template v-else>sin repartidor</template>
            <template v-if="e.entregado_at"> · entregado {{ hora(e.entregado_at) }}</template>
            <template v-else-if="e.fallido_at"> · {{ hora(e.fallido_at) }}<template v-if="e.motivo_fallo"> · {{ e.motivo_fallo }}</template></template>
            <template v-else> · despachado {{ hora(e.creada_at) }}</template>
            <template v-if="e.cobrar_en_entrega && e.saldo_pendiente > 0"> · cobra {{ fmt(e.saldo_pendiente) }}</template>
            <template v-if="todos && e.despachado_por"> · {{ e.despachado_por }}</template>
          </div>
        </div>
      </li>
    </ul>
  </section>
</template>

<style scoped>
.edh { background: #fff; border: 1px solid var(--c-slate-200); border-radius: 14px; margin-bottom: 1rem; overflow: hidden; }
.edh__hd { display: flex; align-items: center; gap: .5rem; width: 100%; padding: .8rem 1rem; background: none; border: none; text-align: left; font: inherit; color: inherit; cursor: default; }
.edh__hd--btn { cursor: pointer; }
.edh__ico { color: var(--c-slate-500); }
.edh__title { font-size: .8rem; font-weight: 800; text-transform: uppercase; letter-spacing: .05em; color: var(--c-slate-600); }
.edh__resumen { font-size: .78rem; color: var(--c-slate-500); display: inline-flex; gap: .45rem; flex-wrap: wrap; align-items: baseline; }
.edh__n { font-weight: 700; color: var(--c-slate-600); }
.edh__n--viaje { color: #0369a1; }
.edh__n--ok    { color: #15803d; }
.edh__n--mal   { color: #b91c1c; }
.edh__chev { margin-left: auto; color: var(--c-slate-400); font-size: .8rem; }
.edh__muted { padding: 0 1rem .8rem; font-size: .8rem; color: var(--c-slate-400); }
.edh__list { list-style: none; margin: 0; padding: 0 .6rem .6rem; display: grid; gap: .35rem; }
.edh__item { display: flex; gap: .7rem; align-items: flex-start; padding: .55rem .6rem; border-radius: 10px; background: var(--c-slate-50); }
.edh__estado { flex-shrink: 0; min-width: 78px; text-align: center; font-size: .66rem; font-weight: 800; text-transform: uppercase; letter-spacing: .04em; padding: .25rem .4rem; border-radius: 6px; margin-top: .1rem; }
.edh__estado--pend  { background: var(--c-slate-200); color: var(--c-slate-600); }
.edh__estado--viaje { background: #e0f2fe; color: #0369a1; }
.edh__estado--ok    { background: #dcfce7; color: #15803d; }
.edh__estado--mal   { background: #fee2e2; color: #b91c1c; }
.edh__txt { min-width: 0; display: grid; gap: .1rem; }
.edh__quien { font-size: .84rem; font-weight: 700; color: var(--c-slate-900); }
.edh__etq { margin-left: .35rem; font-size: .66rem; font-weight: 800; text-transform: uppercase; color: #b45309; background: #fef3c7; border-radius: 5px; padding: .05rem .35rem; }
.edh__dir { font-size: .78rem; color: var(--c-slate-600); }
.edh__meta { font-size: .72rem; color: var(--c-slate-400); }
.edh--compacto .edh__hd { padding: .6rem .8rem; }
</style>
