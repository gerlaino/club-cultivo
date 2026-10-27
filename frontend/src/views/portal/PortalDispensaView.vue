<template>
  <div class="pdv">
    <RouterLink to="/portal/historial" class="pdv__volver">← Mis dispensas</RouterLink>

    <div v-if="cargando" class="pdv__estado"><DsSpinner :size="36" /></div>
    <div v-else-if="error" class="pdv__estado pdv__estado--error">{{ error }}</div>

    <template v-else-if="d">
      <header class="pdv__hd">
        <div>
          <span class="pdv__num">Dispensa Nº {{ d.numero }}</span>
          <h1 class="pdv__title">{{ fechaLarga(d.fecha) }}</h1>
          <p class="pdv__sub">
            <span v-if="d.sede">{{ d.sede }}</span>
            <span v-if="d.hora"> · {{ hora(d.hora) }}</span>
            <span v-if="d.envio"> · con envío</span>
          </p>
          <p v-if="d.anulada" class="pdv__anulada">Esta dispensa fue anulada por la organización.</p>
        </div>
        <a v-if="d.token" :href="`/d/${d.token}`" class="pdv__btn" target="_blank" rel="noopener">Ver el pasaporte</a>
      </header>

      <div class="pdv__grid">
        <div class="pdv__col">
          <section v-for="(it, n) in d.items" :key="n" class="pdv__card" :data-testid="`item-${n}`">
            <div class="pdv__prod">
              <div>
                <h2 class="pdv__prod-t">{{ it.nombre }}</h2>
                <p class="pdv__prod-s">
                  {{ it.forma }} · {{ cantidad(it) }}<span v-if="it.frasco?.numero"> · frasco {{ it.frasco.numero }}</span>
                </p>
                <RouterLink v-if="it.genetica?.id" :to="{ name: 'portal-genetica', params: { id: it.genetica.id } }" class="pdv__link">
                  Ver la genética {{ it.genetica.nombre }} ›
                </RouterLink>
              </div>
              <span v-if="it.precio" class="pdv__precio">{{ pesos(it.precio) }}</span>
            </div>

            <template v-if="it.lote">
              <div class="pdv__traza-hd">
                <h3 class="pdv__h3">Trazabilidad del lote <span class="pdv__mono">{{ it.lote.codigo }}</span></h3>
                <span class="pdv__nota">
                  <template v-if="it.lote.origen">{{ it.lote.origen }}</template>
                  <template v-if="it.lote.plantas"> · {{ it.lote.plantas }} plantas</template>
                </span>
              </div>
              <ol class="pdv__linea">
                <li v-for="(e, k) in it.lote.etapas" :key="k" class="pdv__etapa" :class="{ 'pdv__etapa--fin': e.es_entrega }">
                  <span class="pdv__punto" aria-hidden="true"></span>
                  <span class="pdv__etapa-txt">
                    <b>{{ e.etapa }}</b>
                    <span v-if="e.detalle" class="pdv__nota">{{ e.detalle }}</span>
                  </span>
                  <span class="pdv__etapa-f">{{ fechaCorta(e.fecha) }}</span>
                </li>
              </ol>

              <div class="pdv__datos">
                <div class="pdv__dato">
                  <h4 class="pdv__h4">Análisis de laboratorio</h4>
                  <template v-if="it.lote.analisis">
                    <p class="pdv__nota">{{ it.lote.analisis.laboratorio || 'Laboratorio' }}<span v-if="it.lote.analisis.fecha"> · {{ fechaCorta(it.lote.analisis.fecha) }}</span></p>
                    <p class="pdv__cannab">
                      <span v-if="it.lote.analisis.thc != null">THC <b>{{ pct(it.lote.analisis.thc) }}</b></span>
                      <span v-if="it.lote.analisis.cbd != null">CBD <b>{{ pct(it.lote.analisis.cbd) }}</b></span>
                      <span v-if="it.lote.analisis.cbg != null">CBG <b>{{ pct(it.lote.analisis.cbg) }}</b></span>
                    </p>
                    <p v-if="it.lote.analisis.terpenos" class="pdv__nota">Terpenos: {{ it.lote.analisis.terpenos }}</p>
                  </template>
                  <p v-else class="pdv__nota">Este lote todavía no tiene un análisis cargado.</p>
                </div>
                <div class="pdv__dato">
                  <h4 class="pdv__h4">Lo que recibió el cultivo</h4>
                  <p class="pdv__nota">
                    <b>Nutrición:</b>&nbsp;{{ it.lote.nutricion.length ? it.lote.nutricion.join(', ') : 'sin registros cargados' }}<span v-if="it.lote.suelo_vivo"> · en suelo vivo</span>.
                  </p>
                  <p class="pdv__nota">
                    <b>Aplicaciones:</b>&nbsp;<template v-if="it.lote.fitosanitarios.length">
                      <span v-for="(f, j) in it.lote.fitosanitarios" :key="j">
                        {{ f.producto }}<template v-if="f.motivo"> ({{ f.motivo }})</template><template v-if="f.carencia_dias"> · carencia {{ f.carencia_dias }} días</template><template v-if="j < it.lote.fitosanitarios.length - 1">; </template>
                      </span>.
                    </template>
                    <template v-else>ninguna registrada.</template>
                  </p>
                </div>
              </div>
            </template>
            <p v-else class="pdv__nota pdv__sin-lote">Este producto no viene de un lote de la organización.</p>
          </section>
        </div>

        <aside class="pdv__col pdv__col--lado">
          <section class="pdv__card">
            <h3 class="pdv__h3">Cómo se pagó</h3>
            <div v-for="(p, n) in d.pagos" :key="n" class="pdv__fila"><span>{{ p.medio }}</span><b>{{ pesos(p.monto) }}</b></div>
            <div v-if="d.descuento" class="pdv__fila pdv__fila--suave">
              <span>Descuento</span>
              <span>{{ d.descuento.pct ? `${pct(d.descuento.pct)}` : '' }}{{ d.descuento.pct && d.descuento.ars ? ' + ' : '' }}{{ d.descuento.ars ? pesos(d.descuento.ars) : '' }}</span>
            </div>
            <div v-if="d.envio?.costo" class="pdv__fila pdv__fila--suave"><span>Envío</span><span>{{ pesos(d.envio.costo) }}</span></div>
            <div class="pdv__fila pdv__fila--total"><span>Total</span><b>{{ pesos(d.total) }}</b></div>
          </section>
          <section class="pdv__card">
            <h3 class="pdv__h3">¿Tenés una consulta?</h3>
            <p class="pdv__nota">Escribile a la organización por esta dispensa.</p>
            <RouterLink :to="{ path: '/portal/mensajes', query: { dispensa: d.id } }" class="pdv__btn pdv__btn--lleno">Consultar</RouterLink>
          </section>
        </aside>
      </div>
    </template>
  </div>
</template>

<script setup>
// El detalle de una dispensa, adentro del portal (27-oct-2026, Germán: «cada dispensa debería
// tener su detalle, desde donde se podría llegar a la genética y a la trazabilidad del lote del
// stock dispensado, algo realmente profesional»). Lo arma el backend (`Portal::DetalleDispensa`):
// sólo lo suyo, sin costo ni otros pacientes.
import { onMounted, ref } from 'vue'
import { useRoute } from 'vue-router'
import { getPortalDispensa } from '@/lib/portalApi'
import DsSpinner from '@/design-system/components/Spinner.vue'

const route = useRoute()
const d = ref(null)
const cargando = ref(true)
const error = ref(null)

const MESES = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre']
const DIAS = ['Domingo', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado']
// Las fechas sin hora («2026-10-21») son del día: se leen en hora local, no como UTC.
const aFecha = (f) => (/^\d{4}-\d{2}-\d{2}$/.test(String(f)) ? new Date(`${f}T00:00:00`) : new Date(f))
const fechaLarga = (f) => { const x = aFecha(f); return `${DIAS[x.getDay()]} ${x.getDate()} de ${MESES[x.getMonth()]}` }
const fechaCorta = (f) => { if (!f) return ''; const x = aFecha(f); return `${x.getDate()} ${MESES[x.getMonth()].slice(0, 3)}` }
const hora = (f) => new Date(f).toLocaleTimeString('es-AR', { hour: '2-digit', minute: '2-digit' })
const pesos = (n) => new Intl.NumberFormat('es-AR', { style: 'currency', currency: 'ARS', maximumFractionDigits: 0 }).format(n || 0)
const pct = (n) => `${String(Number(n).toFixed(1)).replace('.', ',').replace(',0', '')}%`
const cantidad = (it) => `${String(it.cantidad).replace('.', ',')} ${it.unidad === 'g' ? 'g' : (it.unidad || '')}`.trim()

onMounted(async () => {
  try {
    d.value = await getPortalDispensa(route.params.id)
  } catch (e) {
    error.value = e?.response?.status === 404
      ? 'No encontramos esa dispensa.'
      : 'No pudimos traer el detalle. Probá de nuevo en un rato.'
  } finally {
    cargando.value = false
  }
})
</script>

<style scoped>
.pdv { max-width: 1040px; margin: 0 auto; padding: 1.5rem 1.25rem 3rem; }
.pdv__volver { display: inline-block; margin-bottom: 1rem; color: var(--p-marca); font-weight: 600; text-decoration: none; font-size: .9rem; }
.pdv__estado { display: flex; justify-content: center; padding: 3rem 1rem; color: var(--p-suave); }
.pdv__estado--error { color: var(--p-atencion); }

.pdv__hd { display: flex; flex-wrap: wrap; justify-content: space-between; align-items: flex-end; gap: 1rem; margin-bottom: 1.25rem; }
.pdv__num { font-family: var(--font-mono); font-size: .8rem; color: var(--p-suave); letter-spacing: .04em; }
.pdv__title { font-family: var(--p-display); font-size: 1.7rem; font-weight: 700; color: var(--p-tinta); margin: .15rem 0; }
.pdv__sub { margin: 0; color: var(--p-suave); font-size: .92rem; }
.pdv__anulada { margin: .5rem 0 0; color: var(--p-urgente); font-weight: 600; font-size: .9rem; }

.pdv__btn {
  display: inline-flex; align-items: center; justify-content: center; min-height: 42px; padding: 0 1rem;
  border-radius: 10px; border: 1px solid var(--p-linea); background: var(--p-papel); color: var(--p-tinta);
  font-weight: 600; font-size: .88rem; text-decoration: none;
}
.pdv__btn--lleno { background: var(--p-marca); border-color: var(--p-marca); color: var(--p-papel); width: 100%; }

.pdv__grid { display: flex; flex-wrap: wrap; gap: 1.25rem; align-items: flex-start; }
.pdv__col { flex: 3 1 480px; min-width: 0; display: flex; flex-direction: column; gap: 1.25rem; }
.pdv__col--lado { flex: 1 1 260px; }
.pdv__card { background: var(--p-papel); border: 1px solid var(--p-linea); border-radius: 16px; padding: 1.1rem 1.2rem; }

.pdv__prod { display: flex; justify-content: space-between; gap: 1rem; padding-bottom: 1rem; border-bottom: 1px solid var(--p-linea); }
.pdv__prod-t { font-size: 1.15rem; font-weight: 700; color: var(--p-tinta); margin: 0; }
.pdv__prod-s { margin: .15rem 0 .35rem; color: var(--p-suave); font-size: .9rem; }
.pdv__link { color: var(--p-marca); font-weight: 700; font-size: .88rem; text-decoration: none; }
.pdv__link:hover { text-decoration: underline; }
.pdv__precio { font-weight: 700; color: var(--p-tinta); white-space: nowrap; }

.pdv__traza-hd { display: flex; flex-wrap: wrap; justify-content: space-between; align-items: baseline; gap: .5rem; margin: 1rem 0 .6rem; }
.pdv__h3 { font-size: .98rem; font-weight: 700; color: var(--p-tinta); margin: 0 0 .5rem; }
.pdv__traza-hd .pdv__h3 { margin: 0; }
.pdv__h4 { font-size: .88rem; font-weight: 700; color: var(--p-tinta); margin: 0 0 .3rem; }
.pdv__mono { font-family: var(--font-mono); font-weight: 600; }
.pdv__nota { font-size: .86rem; color: var(--p-suave); margin: 0 0 .25rem; line-height: 1.5; }

.pdv__linea { list-style: none; margin: 0 0 1rem; padding: 0; }
.pdv__etapa { position: relative; display: grid; grid-template-columns: 22px minmax(0, 1fr) auto; gap: .6rem; padding-bottom: .8rem; }
.pdv__etapa:not(:last-child)::before {
  content: ''; position: absolute; left: 10px; top: 14px; bottom: 0; width: 2px; background: var(--p-linea);
}
.pdv__punto { width: 12px; height: 12px; border-radius: 50%; margin: 4px 0 0 5px; background: var(--p-marca-linea); position: relative; }
.pdv__etapa--fin .pdv__punto { background: var(--p-marca); box-shadow: 0 0 0 4px var(--p-marca-suave); }
.pdv__etapa-txt { display: flex; flex-direction: column; font-size: .92rem; color: var(--p-tinta); }
.pdv__etapa-txt .pdv__nota { margin: 0; }
.pdv__etapa-f { font-size: .85rem; color: var(--p-suave); white-space: nowrap; }

.pdv__datos { display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: .75rem; }
.pdv__dato { background: var(--p-hundido); border-radius: 12px; padding: .85rem .95rem; }
.pdv__cannab { display: flex; flex-wrap: wrap; gap: .9rem; margin: .1rem 0 .3rem; font-size: .92rem; color: var(--p-tinta); }
.pdv__sin-lote { margin-top: .8rem; }

.pdv__fila { display: flex; justify-content: space-between; gap: .5rem; font-size: .92rem; color: var(--p-tinta); padding: .25rem 0; }
.pdv__fila--suave { color: var(--p-suave); }
.pdv__fila--total { border-top: 1px solid var(--p-linea); margin-top: .35rem; padding-top: .55rem; font-size: 1rem; }
</style>
