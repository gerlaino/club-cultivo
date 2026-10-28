<template>
  <div class="phv">
    <header class="phv__hd">
      <h1 class="phv__title">Mis dispensas</h1>
      <p class="phv__sub">Todo lo que retiraste, con de dónde viene cada producto.</p>
    </header>

    <div v-if="cargando" class="phv__estado"><DsSpinner :size="36" /></div>

    <div v-else-if="error" class="phv__estado phv__estado--error">
      No pudimos traer tu historial. Probá de nuevo en un rato.
    </div>

    <div v-else-if="!dispensas.length" class="phv__estado">
      <PackageCheck :size="36" :stroke-width="1.5" class="phv__vacio-ico" aria-hidden="true" />
      <p class="phv__vacio-txt">Todavía no retiraste nada. Cuando lo hagas, va a aparecer acá.</p>
    </div>

    <template v-else>
      <!-- Lo de este mes, en un número: cuánto retiró (28-oct-2026). -->
      <section v-if="esteMes" class="phv__mes-resumen" data-testid="resumen-mes">
        <div>
          <p class="phv__mes-k">{{ esteMes.nombre }}</p>
          <p class="phv__mes-v">{{ esteMes.gramos ? `${fmt(esteMes.gramos)} g` : `${esteMes.cantidad} ${esteMes.cantidad === 1 ? 'retiro' : 'retiros'}` }}</p>
        </div>
        <p class="phv__mes-s">{{ esteMes.cantidad === 1 ? 'en 1 retiro' : `en ${esteMes.cantidad} retiros` }}</p>
      </section>

      <section v-for="g in grupos" :key="g.clave" class="phv__grupo">
        <h2 class="phv__grupo-t">{{ g.nombre }}</h2>
        <ul class="phv__lista">
          <li v-for="d in g.dispensas" :key="d.id">
            <RouterLink :to="{ name: 'portal-dispensa', params: { id: d.id } }" class="phv__item" :class="{ 'phv__item--anulada': d.anulada }">
              <div class="phv__fecha">
                <span class="phv__dia">{{ dia(d.fecha) }}</span>
                <span class="phv__mes">{{ mes(d.fecha) }}</span>
              </div>
              <div class="phv__cuerpo">
                <div class="phv__geneticas">
                  <span v-for="(i, n) in d.items" :key="n" class="phv__genetica">
                    {{ i.genetica || 'Producto' }}
                    <span class="phv__cant">{{ i.cantidad }} {{ i.unidad || 'g' }}</span>
                  </span>
                </div>
                <div class="phv__meta">
                  <span v-if="d.sede">{{ d.sede }}</span>
                  <span v-if="lotes(d)">· lote {{ lotes(d) }}</span>
                  <span v-if="d.total > 0">· {{ pesos(d.total) }}</span>
                  <span v-if="d.anulada" class="phv__anulada">· Anulada</span>
                </div>
              </div>
              <span class="phv__ver">De dónde salió <ChevronRight :size="16" :stroke-width="2" aria-hidden="true" /></span>
            </RouterLink>
          </li>
        </ul>
      </section>
    </template>
  </div>
</template>

<script setup>
// Lo primero que un paciente busca cuando entra: qué retiró y cuándo. Por mes, con lo de este mes
// en un número, y cada dispensa entera se toca para ver de dónde salió (28-oct-2026).
//
// «Ver detalle» abre la dispensa adentro del portal (27-oct-2026), con la trazabilidad de cada
// frasco: era el pasaporte público (`/d/:token`), que pide el DNI aunque ya esté logueado. El
// pasaporte sigue existiendo para el QR de la etiqueta, y el detalle lo enlaza.
import { ref, computed, onMounted } from 'vue'
import { ChevronRight, PackageCheck } from 'lucide-vue-next'
import { getPortalHistorial } from '@/lib/portalApi'
import DsSpinner from '@/design-system/components/Spinner.vue'

const dispensas = ref([])
const cargando  = ref(true)
const error     = ref(false)

const MESES = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic']
const fecha = (f) => new Date(String(f) + 'T00:00:00')
const dia   = (f) => (f ? fecha(f).getDate() : '')
const mes   = (f) => (f ? MESES[fecha(f).getMonth()] : '')
const lotes = (d) => [...new Set((d.items || []).map(i => i.lote).filter(Boolean))].join(', ')
const fmt = (n) => Number(n).toLocaleString('es-AR', { maximumFractionDigits: 1 })
const NOMBRES_MES = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre']
const claveMes = (f) => String(f).slice(0, 7)

// Agrupadas por mes (28-oct-2026): «¿cuándo fue la última vez que llevé esto?» se busca por mes.
const grupos = computed(() => {
  const por = new Map()
  for (const d of dispensas.value) {
    const k = claveMes(d.fecha)
    if (!por.has(k)) {
      const [y, m] = k.split('-').map(Number)
      const nombre = y === new Date().getFullYear() ? NOMBRES_MES[m - 1] : `${NOMBRES_MES[m - 1]} ${y}`
      por.set(k, { clave: k, nombre, dispensas: [] })
    }
    por.get(k).dispensas.push(d)
  }
  return [...por.values()]
})

// Lo que retiró este mes: los gramos de lo que no se anuló.
const esteMes = computed(() => {
  const hoy = new Date()
  const k = `${hoy.getFullYear()}-${String(hoy.getMonth() + 1).padStart(2, '0')}`
  const del = dispensas.value.filter(d => claveMes(d.fecha) === k && !d.anulada)
  if (!del.length) return null
  const gramos = del.flatMap(d => d.items || []).filter(i => (i.unidad || 'g') === 'g').reduce((s, i) => s + Number(i.cantidad || 0), 0)
  return { nombre: NOMBRES_MES[hoy.getMonth()], cantidad: del.length, gramos }
})
const pesos = (n) => new Intl.NumberFormat('es-AR', { style: 'currency', currency: 'ARS', maximumFractionDigits: 0 }).format(n)

onMounted(async () => {
  try {
    dispensas.value = await getPortalHistorial()
  } catch {
    error.value = true
  } finally {
    cargando.value = false
  }
})
</script>

<style scoped>
.phv { max-width: 720px; margin: 0 auto; padding: 2rem 1.25rem 3rem; }
.phv__hd { margin-bottom: 1.75rem; }
.phv__title { font-size: 1.5rem; font-weight: 800; color: var(--p-tinta); margin: 0 0 .25rem; }
.phv__sub { color: var(--p-suave); font-size: .9rem; margin: 0; }

.phv__estado {
  display: flex; flex-direction: column; align-items: center; justify-content: center;
  gap: .75rem; padding: 3rem 1rem; text-align: center; color: var(--p-suave);
}
.phv__estado--error { color: var(--p-atencion); }
.phv__vacio-txt { margin: 0; max-width: 320px; }

.phv__mes-resumen {
  display: flex; justify-content: space-between; align-items: flex-end; gap: 1rem; margin-bottom: 1.5rem;
  padding: 1.1rem 1.25rem; border-radius: 16px; background: var(--p-marca-fuerte); color: var(--p-papel);
}
.phv__mes-k { margin: 0; font-size: .85rem; opacity: .85; }
.phv__mes-v { margin: .2rem 0 0; font-size: 1.8rem; font-weight: 800; line-height: 1; }
.phv__mes-s { margin: 0; font-size: .85rem; opacity: .85; }
.phv__grupo { margin-bottom: 1.5rem; }
.phv__grupo-t { margin: 0 0 .6rem; font-size: .85rem; font-weight: 700; color: var(--p-suave); text-transform: none; }
.phv__lista { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: .6rem; }
.phv__item {
  display: flex; align-items: center; gap: 1rem; min-height: 64px; text-decoration: none; color: inherit;
  border: 1px solid var(--p-linea); border-radius: 12px; padding: .85rem 1rem; background: var(--p-papel);
  transition: border-color var(--t-fast, .15s);
}
.phv__item:hover { border-color: var(--p-marca-linea); }
.phv__fecha {
  display: flex; flex-direction: column; align-items: center; justify-content: center;
  width: 46px; flex-shrink: 0; background: var(--p-marca-suave); border-radius: 9px; padding: .35rem 0;
}
.phv__dia { font-size: 1.1rem; font-weight: 800; color: var(--p-marca); line-height: 1; }
.phv__mes { font-size: .68rem; text-transform: uppercase; letter-spacing: .05em; color: var(--p-suave); }

.phv__cuerpo { flex: 1; min-width: 0; }
.phv__geneticas { display: flex; flex-wrap: wrap; gap: .4rem .75rem; margin-bottom: .2rem; }
.phv__genetica { font-weight: 600; color: var(--p-tinta); font-size: .92rem; }
.phv__cant { font-weight: 400; color: var(--p-suave); }
.phv__meta { font-size: .8rem; color: var(--p-suave); display: flex; gap: .3rem; flex-wrap: wrap; }

.phv__item--anulada { opacity: .7; }
.phv__anulada { color: var(--p-urgente); font-weight: 600; }
.phv__ver { flex-shrink: 0; display: inline-flex; align-items: center; gap: 2px; font-size: .85rem; font-weight: 600; color: var(--p-marca); }
.phv__item:hover .phv__ver { text-decoration: underline; }
.phv__vacio-ico { color: var(--p-tenue); }
@media (max-width: 520px) { .phv__ver { font-size: 0; gap: 0; } .phv__ver svg { width: 20px; height: 20px; } }


</style>
