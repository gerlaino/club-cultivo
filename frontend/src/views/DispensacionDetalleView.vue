<script setup>
import { ref, computed, onMounted } from 'vue'
import { RouterLink, useRouter } from 'vue-router'
import { getDispensacion } from '../lib/api.js'
import { formaLabel, formatARS, formatFecha } from '../lib/formatters.js'
import DsSpinner from '../design-system/components/Spinner.vue'

const props = defineProps({ id: { type: Number, required: true } })
const router = useRouter()

const disp    = ref(null)
const loading = ref(true)
const error   = ref('')

async function cargar() {
  loading.value = true; error.value = ''
  try {
    const { data } = await getDispensacion(props.id)
    disp.value = data
  } catch {
    error.value = 'No se pudo cargar la dispensación.'
  } finally {
    loading.value = false
  }
}
onMounted(cargar)

const items   = computed(() => disp.value?.items?.length ? disp.value.items : [])
const resenas = computed(() => disp.value?.resenas || [])

const MEDIO_PAGO = {
  efectivo:         { label: 'Efectivo',          cls: 'is-efectivo' },
  transferencia:    { label: 'Transferencia',     cls: 'is-transf' },
  cuenta_corriente: { label: 'Cuenta corriente',  cls: 'is-cc' },
  no_abona:         { label: 'No abona',           cls: 'is-cc' },
  contra_entrega:   { label: 'Contra entrega',     cls: 'is-transf' },
}
const medioPago = computed(() => MEDIO_PAGO[disp.value?.medio_pago] || { label: disp.value?.medio_pago || '—', cls: 'is-cc' })

const ENVIO = {
  pendiente: 'Pendiente', en_viaje: 'En viaje', entregado: 'Entregado', fallido: 'Fallido', reprogramado: 'Reprogramado',
}
const estadoEnvio = computed(() => ENVIO[disp.value?.estado_envio] || disp.value?.estado_envio)

const total    = computed(() => Number(disp.value?.aporte_socio_ars || 0))
const cobrado  = computed(() => Number(disp.value?.monto_efectivo_ars ?? disp.value?.total_cobrado ?? 0))
const credito  = computed(() => Number(disp.value?.monto_credito_ars || 0))

const fechaResena = (f) => f ? new Date(f).toLocaleDateString('es-AR', { day: '2-digit', month: 'short', year: 'numeric' }) : ''
function lineaProducto(it) {
  const forma = formaLabel(it.stock?.forma_producto)
  const gen   = it.genetica_nombre ? ` · ${it.genetica_nombre}` : ''
  return `${forma}${gen}`
}
</script>

<template>
  <div class="dd">
    <div class="dd__wrap">

      <button class="dd__back" @click="router.back()">← Volver</button>

      <div v-if="loading" class="dd__center"><DsSpinner :size="28" /></div>
      <div v-else-if="error" class="dd__center dd__error">{{ error }}</div>

      <template v-else-if="disp">
        <!-- Header -->
        <header class="dd__head">
          <div>
            <div class="dd__eyebrow">Dispensación</div>
            <h1 class="dd__title">{{ formatFecha(disp.fecha_dispensacion) }}</h1>
            <div class="dd__head-meta">
              <RouterLink :to="{ name: 'paciente-detail', params: { id: disp.paciente_id } }" class="dd__pac">
                {{ disp.paciente_nombre }}
              </RouterLink>
              <span v-if="disp.sede" class="dd__dot">·</span>
              <span v-if="disp.sede" class="dd__muted">{{ disp.sede.nombre }}</span>
            </div>
          </div>
          <div class="dd__head-badges">
            <span v-if="disp.es_regalo" class="dd__badge dd__badge--regalo">🎁 Regalo</span>
            <span class="dd__badge" :class="medioPago.cls">{{ medioPago.label }}</span>
            <span v-if="disp.con_envio" class="dd__badge is-envio">🚚 {{ estadoEnvio }}</span>
          </div>
        </header>

        <!-- Resumen financiero -->
        <section class="dd__kpis">
          <div class="dd__kpi">
            <span class="dd__kpi-lbl">Total</span>
            <span class="dd__kpi-val">{{ formatARS(total) }}</span>
          </div>
          <div class="dd__kpi">
            <span class="dd__kpi-lbl">Cobrado</span>
            <span class="dd__kpi-val dd__kpi-val--green">{{ formatARS(cobrado) }}</span>
          </div>
          <div class="dd__kpi" v-if="credito > 0">
            <span class="dd__kpi-lbl">A cuenta corriente</span>
            <span class="dd__kpi-val dd__kpi-val--amber">{{ formatARS(credito) }}</span>
          </div>
          <div class="dd__kpi" v-if="Number(disp.saldo_pendiente) > 0">
            <span class="dd__kpi-lbl">Saldo pendiente</span>
            <span class="dd__kpi-val dd__kpi-val--red">{{ formatARS(disp.saldo_pendiente) }}</span>
          </div>
        </section>

        <!-- Productos -->
        <section class="dd__card">
          <h2 class="dd__card-title">Productos ({{ items.length }})</h2>
          <ul class="dd__items">
            <li v-for="(it, i) in items" :key="i" class="dd__item">
              <div class="dd__item-main">
                <span class="dd__item-name">{{ lineaProducto(it) }}</span>
                <span class="dd__item-sub">
                  <span v-if="it.stock?.externo" class="dd__ext">Externo</span>
                  <template v-else-if="it.lote_codigo">Lote {{ it.lote_codigo }}</template>
                </span>
              </div>
              <div class="dd__item-nums">
                <span class="dd__item-cant">{{ it.cantidad }}{{ it.stock?.unidad || 'g' }}</span>
                <span class="dd__item-money">
                  <template v-if="it.precio_unitario_ars">{{ formatARS(it.precio_unitario_ars) }}/u · </template>
                  <strong>{{ formatARS(it.subtotal_ars) }}</strong>
                </span>
              </div>
            </li>
          </ul>
          <div class="dd__items-total">
            <span>Total</span><strong>{{ formatARS(total) }}</strong>
          </div>
        </section>

        <!-- Reseñas del paciente -->
        <section class="dd__card">
          <h2 class="dd__card-title">⭐ Reseñas del paciente</h2>
          <div v-if="!resenas.length" class="dd__empty">El paciente todavía no dejó reseñas de estos productos.</div>
          <ul v-else class="dd__resenas">
            <li v-for="r in resenas" :key="r.genetica_id" class="dd__resena">
              <div class="dd__resena-top">
                <span class="dd__resena-gen">{{ r.genetica_nombre }}</span>
                <span class="dd__resena-fecha">{{ fechaResena(r.fecha) }}</span>
              </div>
              <div class="dd__resena-stars">
                {{ '★'.repeat(r.estrellas) }}<span class="dd__resena-off">{{ '★'.repeat(5 - r.estrellas) }}</span>
              </div>
              <div v-if="r.sabor || r.aroma || r.efecto" class="dd__resena-axes">
                <span v-if="r.sabor">Sabor {{ r.sabor }}/5</span>
                <span v-if="r.aroma">Aroma {{ r.aroma }}/5</span>
                <span v-if="r.efecto">Efecto {{ r.efecto }}/5</span>
              </div>
              <p v-if="r.comentario" class="dd__resena-com">“{{ r.comentario }}”</p>
            </li>
          </ul>
        </section>

        <!-- Envío -->
        <section v-if="disp.con_envio" class="dd__card">
          <h2 class="dd__card-title">🚚 Entrega</h2>
          <dl class="dd__rows">
            <div class="dd__row"><dt>Estado</dt><dd>{{ estadoEnvio }}</dd></div>
            <div class="dd__row" v-if="disp.codigo_paquete"><dt>Paquete</dt><dd class="dd__mono">{{ disp.codigo_paquete }}</dd></div>
            <div class="dd__row" v-if="disp.direccion_envio"><dt>Dirección</dt><dd>{{ disp.direccion_envio }}</dd></div>
            <div class="dd__row" v-if="disp.contacto_nombre"><dt>Contacto</dt><dd>{{ disp.contacto_nombre }}<template v-if="disp.contacto_telefono"> · {{ disp.contacto_telefono }}</template></dd></div>
            <div class="dd__row" v-if="disp.delivery_nombre"><dt>Repartidor</dt><dd>{{ disp.delivery_nombre }}</dd></div>
            <div class="dd__row" v-if="disp.entregado_at"><dt>Entregado</dt><dd>{{ formatFecha(disp.entregado_at, true) }}</dd></div>
          </dl>
          <a v-if="disp.comprobante_entrega_url" :href="disp.comprobante_entrega_url" target="_blank" class="dd__link-out">Ver comprobante de entrega →</a>
        </section>

        <!-- Meta -->
        <section class="dd__card">
          <dl class="dd__rows">
            <div class="dd__row"><dt>Dispensador</dt><dd>{{ disp.usuario?.nombre || '—' }}</dd></div>
            <div class="dd__row" v-if="disp.descuento_dispensa_pct"><dt>Descuento</dt><dd>-{{ disp.descuento_dispensa_pct }}%<template v-if="disp.descuento_otorgado_por"> (por {{ disp.descuento_otorgado_por }})</template></dd></div>
            <div class="dd__row" v-if="disp.observaciones"><dt>Observaciones</dt><dd>{{ disp.observaciones }}</dd></div>
            <div class="dd__row"><dt>Registrada</dt><dd>{{ formatFecha(disp.created_at, true) }}</dd></div>
          </dl>
          <a v-if="disp.token" :href="`/d/${disp.token}`" target="_blank" class="dd__link-out">Ver pasaporte público del paciente →</a>
        </section>

      </template>
    </div>
  </div>
</template>

<style scoped>
.dd { min-height: 100dvh; background: #f6f8f6; padding: 1.5rem 1rem 3rem; }
.dd__wrap { max-width: 720px; margin: 0 auto; display: flex; flex-direction: column; gap: 1rem; }
.dd__back { align-self: flex-start; background: none; border: none; color: #56635b; font-weight: 600; font-size: .85rem; cursor: pointer; padding: .2rem 0; }
.dd__back:hover { color: #1b5e20; }
.dd__center { padding: 4rem 1rem; display: grid; place-items: center; }
.dd__error { color: #dc2626; }

.dd__head { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; flex-wrap: wrap; }
.dd__eyebrow { font-size: .64rem; font-weight: 700; text-transform: uppercase; letter-spacing: .12em; color: #9aa79f; }
.dd__title { font-size: 1.5rem; font-weight: 800; color: #12251b; letter-spacing: -.02em; margin: .15rem 0 .3rem; }
.dd__head-meta { display: flex; align-items: center; gap: .4rem; flex-wrap: wrap; font-size: .86rem; }
.dd__pac { color: #1b5e20; font-weight: 700; text-decoration: none; }
.dd__pac:hover { text-decoration: underline; }
.dd__muted { color: #6b7770; }
.dd__dot { color: #c7d0c7; }
.dd__head-badges { display: flex; gap: .4rem; flex-wrap: wrap; }
.dd__badge { font-size: .7rem; font-weight: 700; padding: .3rem .6rem; border-radius: 999px; white-space: nowrap; }
.dd__badge.is-efectivo { background: #dcfce7; color: #15803d; }
.dd__badge.is-transf   { background: #dbeafe; color: #1d4ed8; }
.dd__badge.is-cc       { background: #fef3c7; color: #b45309; }
.dd__badge.is-envio    { background: #ede9fe; color: #6d28d9; }
.dd__badge--regalo     { background: #fce7f3; color: #be185d; }

.dd__kpis { display: grid; grid-template-columns: repeat(auto-fit, minmax(130px, 1fr)); gap: .75rem; }
.dd__kpi { background: #fff; border: 1px solid #e6ede6; border-radius: 14px; padding: .85rem 1rem; }
.dd__kpi-lbl { display: block; font-size: .66rem; text-transform: uppercase; letter-spacing: .06em; color: #9aa79f; font-weight: 600; }
.dd__kpi-val { display: block; font-size: 1.3rem; font-weight: 800; color: #12251b; letter-spacing: -.02em; font-variant-numeric: tabular-nums; margin-top: .15rem; }
.dd__kpi-val--green { color: #15803d; }
.dd__kpi-val--amber { color: #b45309; }
.dd__kpi-val--red   { color: #dc2626; }

.dd__card { background: #fff; border: 1px solid #e6ede6; border-radius: 16px; padding: 1.1rem 1.25rem; }
.dd__card-title { font-size: .82rem; font-weight: 800; color: #14442e; margin: 0 0 .8rem; }

.dd__items { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; }
.dd__item { display: flex; align-items: center; justify-content: space-between; gap: 1rem; padding: .7rem 0; border-bottom: 1px solid #f0f4f0; }
.dd__item:last-child { border-bottom: none; }
.dd__item-name { display: block; font-weight: 650; color: #14251b; font-size: .92rem; }
.dd__item-sub { font-size: .74rem; color: #9aa79f; }
.dd__ext { background: #fef3c7; color: #b45309; padding: 1px 7px; border-radius: 999px; font-weight: 700; font-size: .66rem; }
.dd__item-nums { text-align: right; white-space: nowrap; }
.dd__item-cant { display: block; font-weight: 700; color: #12251b; font-variant-numeric: tabular-nums; }
.dd__item-money { font-size: .78rem; color: #6b7770; font-variant-numeric: tabular-nums; }
.dd__items-total { display: flex; justify-content: space-between; padding-top: .75rem; margin-top: .3rem; border-top: 1.5px solid #eef2ee; font-size: .9rem; color: #12251b; }

.dd__resenas { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: .9rem; }
.dd__resena { border-left: 3px solid #f5a623; padding: .1rem 0 .1rem .8rem; }
.dd__resena-top { display: flex; align-items: baseline; justify-content: space-between; gap: .5rem; }
.dd__resena-gen { font-weight: 700; color: #14251b; font-size: .86rem; }
.dd__resena-fecha { font-size: .7rem; color: #9aa79f; }
.dd__resena-stars { color: #f5a623; font-size: 1.05rem; letter-spacing: 1px; margin: .2rem 0; }
.dd__resena-off { color: #e2e8e2; }
.dd__resena-axes { display: flex; flex-wrap: wrap; gap: .55rem; font-size: .74rem; color: #56635b; font-weight: 600; }
.dd__resena-com { margin: .35rem 0 0; font-size: .85rem; color: #374151; font-style: italic; line-height: 1.45; }

.dd__empty { font-size: .84rem; color: #9aa79f; }

.dd__rows { margin: 0; display: flex; flex-direction: column; gap: .5rem; }
.dd__row { display: flex; justify-content: space-between; gap: 1rem; font-size: .85rem; }
.dd__row dt { color: #9aa79f; font-weight: 600; }
.dd__row dd { margin: 0; color: #14251b; text-align: right; }
.dd__mono { font-family: ui-monospace, monospace; }
.dd__link-out { display: inline-block; margin-top: .8rem; color: #1b5e20; font-weight: 700; font-size: .82rem; text-decoration: none; }
.dd__link-out:hover { text-decoration: underline; }
</style>
