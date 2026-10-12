<template>
  <!-- EL PANEL DE CONDUCCIÓN (12-oct-2026): el inicio del administrador. Quien conduce no riega
       ni atiende: necesita saber en un minuto qué requiere atención, cuánto hay en juego y quién
       se tiene que encargar. Todo lo calcula `Panel::Conduccion`; acá sólo se muestra. -->
  <div class="pc" :class="{ 'pc--compacto': compacto }">
    <header class="pc__hd">
      <div class="pc__hd-txt">
        <span class="pc__fecha">{{ fechaLarga }} · {{ horaActual }} · datos en tiempo real</span>
        <h1 class="pc__veredicto">
          <template v-if="!data">Cargando el estado de la organización…</template>
          <template v-else-if="atencion.length">
            <span class="pc__veredicto-warn">{{ atencion.length }} {{ atencion.length === 1 ? 'asunto requiere' : 'asuntos requieren' }} atención</span>.
            El resto de la operación, dentro de parámetros.
          </template>
          <template v-else>La operación está dentro de parámetros.</template>
        </h1>
      </div>
      <div class="pc__filtros">
        <div v-if="sedes.length > 1" class="pc__seg" role="group" aria-label="Sede">
          <button type="button" class="pc__seg-btn" :class="{ 'is-on': !sedeId }" @click="elegirSede(null)">Toda la organización</button>
          <button v-for="s in sedes" :key="s.id" type="button" class="pc__seg-btn"
                  :class="{ 'is-on': sedeId === s.id }" @click="elegirSede(s.id)">{{ s.nombre }}</button>
        </div>
        <div class="pc__seg" role="group" aria-label="Período">
          <button v-for="p in PERIODOS" :key="p.id" type="button" class="pc__seg-btn"
                  :class="{ 'is-on': periodo === p.id }" @click="elegirPeriodo(p.id)">{{ p.label }}</button>
        </div>
      </div>
    </header>

    <p v-if="error" class="pc__error" role="alert">{{ error }}</p>

    <div v-if="!data && cargando" class="pc__skel" aria-hidden="true">
      <div class="pc__skel-b pc__skel-b--alto" /><div class="pc__skel-b" /><div class="pc__skel-b" />
    </div>

    <template v-if="data">
      <!-- ══ Requiere atención + Dentro de parámetros ═══════════════════════ -->
      <section class="pc__fila pc__fila--atencion">
        <div class="pc__card pc__atencion">
          <div class="pc__card-hd">
            <h2 class="pc__h2">Requiere atención</h2>
            <span class="pc__sub">ordenado por impacto</span>
          </div>
          <p v-if="!atencion.length" class="pc__vacio">No hay asuntos pendientes.</p>
          <button v-for="a in atencion" :key="a.id" type="button" class="pc__asunto" @click="abrir(a)">
            <span class="pc__punto" :class="`pc__punto--${a.severidad}`" aria-hidden="true"></span>
            <span class="pc__asunto-txt">
              <span class="pc__asunto-tit">{{ a.titulo }}</span>
              <span class="pc__asunto-det">{{ a.detalle }}</span>
            </span>
            <span class="pc__asunto-val num" :class="{ 'is-neg': a.unidad === 'ars' && a.valor < 0 }">{{ valorAsunto(a) }}</span>
            <span class="pc__asunto-acc">{{ a.accion }}</span>
          </button>
          <div v-if="data.seguimiento.length" class="pc__seguimiento">
            <span class="pc__seg-lbl">En seguimiento:</span>
            <RouterLink v-for="s in data.seguimiento" :key="s.clave" :to="ruta(s.ruta)" class="pc__seg-item">
              <b>{{ s.cantidad }}</b> {{ s.texto }}
            </RouterLink>
          </div>
        </div>

        <div class="pc__card pc__orden">
          <h2 class="pc__h2 pc__h2--claro">Dentro de parámetros</h2>
          <ul v-if="data.en_orden.length" class="pc__orden-lista">
            <li v-for="o in data.en_orden" :key="o.clave">
              <svg aria-hidden="true" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor"
                   stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12l5 5 9-10" /></svg>
              <span><b>{{ o.titulo }}</b>: {{ o.texto }}</span>
            </li>
          </ul>
          <p v-else class="pc__orden-vacio">Ningún control alcanza todavía su umbral de cumplimiento.</p>
          <span class="pc__orden-pie">Los controles que se cumplen se listan como constancia del monitoreo.</span>
        </div>
      </section>

      <!-- ══ Los cuatro números que conducen ═════════════════════════════════ -->
      <section class="pc__kpis" aria-label="Finanzas, inventario, pacientes y cultivo">
        <RouterLink :to="ruta('/contabilidad')" class="pc__card pc__kpi">
          <span class="pc__kpi-eje">Finanzas</span>
          <span class="pc__kpi-num num">{{ pesos(f.resultado_ars) }}</span>
          <span class="pc__kpi-txt">
            Resultado operativo · {{ PERIODO_TXT[periodo] }}
            <b v-if="f.variacion_pct !== null" :class="f.variacion_pct >= 0 ? 'is-pos' : 'is-neg'">
              {{ f.variacion_pct >= 0 ? '+' : '' }}{{ f.variacion_pct }} %</b>
            <template v-if="f.variacion_pct !== null"> vs. {{ ANTERIOR_TXT[periodo] }}</template>
          </span>
          <dl class="pc__dl">
            <dt>Efectivo en cajas</dt><dd class="num">{{ pesos(f.efectivo_en_cajas_ars) }}</dd>
            <dt>Cuentas por cobrar ({{ f.cuentas_por_cobrar }})</dt><dd class="num">{{ pesos(f.cuentas_por_cobrar_ars) }}</dd>
          </dl>
        </RouterLink>

        <RouterLink :to="ruta('/admin/stock')" class="pc__card pc__kpi">
          <span class="pc__kpi-eje">Inventario</span>
          <span class="pc__kpi-num num">{{ gramos(inv.flor_seca_disponible_g) }}</span>
          <span class="pc__kpi-txt">
            Flor seca disponible<template v-if="inv.cobertura_dias !== null"> · cobertura de <b>{{ inv.cobertura_dias }} días</b></template>
          </span>
          <div v-if="inv.cobertura_dias !== null" class="pc__barra" role="img" :aria-label="`Cobertura: ${inv.cobertura_dias} días`">
            <div class="pc__barra-in" :class="{ 'is-warn': inv.cobertura_dias < 10 }" :style="{ width: `${Math.min(100, inv.cobertura_dias / 30 * 100)}%` }" />
          </div>
          <dl class="pc__dl">
            <dt>Dispensa promedio diaria</dt><dd class="num">{{ gramos(inv.dispensa_promedio_diaria_g) }}</dd>
            <dt>Vencimientos a 30 días</dt><dd class="num">{{ inv.vencimientos_30d }}</dd>
          </dl>
        </RouterLink>

        <RouterLink :to="ruta('/pacientes')" class="pc__card pc__kpi">
          <span class="pc__kpi-eje">Pacientes</span>
          <span class="pc__kpi-num num">{{ entero(pac.atendidos) }}</span>
          <span class="pc__kpi-txt">Atendidos · {{ PERIODO_TXT[periodo] }} · <b>{{ entero(pac.activos) }} activos</b></span>
          <dl class="pc__dl">
            <dt>REPROCANN vigente</dt><dd class="num">{{ pac.reprocann_vigente_pct === null ? '—' : `${pac.reprocann_vigente_pct} %` }}</dd>
            <dt>Turnos médicos (semana)</dt><dd class="num">{{ pac.turnos_semana }}</dd>
          </dl>
        </RouterLink>

        <RouterLink :to="ruta('/salas')" class="pc__card pc__kpi">
          <span class="pc__kpi-eje">Cultivo</span>
          <span class="pc__kpi-num num">{{ cul.proxima_cosecha ? diasTxt(cul.proxima_cosecha.faltan_dias) : '—' }}</span>
          <span class="pc__kpi-txt">
            <template v-if="cul.proxima_cosecha">
              {{ cul.proxima_cosecha.faltan_dias < 0 ? 'De atraso en la próxima cosecha' : 'A la próxima cosecha' }} · {{ cul.proxima_cosecha.codigo }}<template v-if="cul.proxima_cosecha.rendimiento_estimado_g">
              · rendimiento estimado <b>{{ gramos(cul.proxima_cosecha.rendimiento_estimado_g) }}</b></template>
            </template>
            <template v-else>Sin cosechas programadas</template>
          </span>
          <div v-if="cul.capacidad_floracion" class="pc__barra" role="img"
               :aria-label="`Plantas en floración: ${cul.en_floracion} de ${cul.capacidad_floracion} habilitadas por el plan`">
            <div class="pc__barra-in" :class="{ 'is-warn': cul.en_floracion / cul.capacidad_floracion > 0.9 }"
                 :style="{ width: `${Math.min(100, cul.en_floracion / cul.capacidad_floracion * 100)}%` }" />
          </div>
          <dl class="pc__dl">
            <dt>Floración / capacidad del plan</dt><dd class="num">{{ cul.en_floracion }} / {{ cul.capacidad_floracion ?? 'sin tope' }}</dd>
            <dt>Tareas vencidas</dt><dd class="num">{{ cul.tareas_vencidas }}</dd>
          </dl>
        </RouterLink>
      </section>

      <!-- ══ Trazabilidad del producto ═══════════════════════════════════════ -->
      <section class="pc__card pc__traza" aria-labelledby="pc-traza">
        <div class="pc__card-hd">
          <h2 id="pc-traza" class="pc__h2">Trazabilidad del producto · {{ PERIODO_TXT[periodo] }}</h2>
          <span class="pc__sub">Del cultivo a la dispensa: volumen de flor seca por etapa y pérdidas registradas</span>
        </div>
        <div class="pc__etapas">
          <div v-for="e in etapas" :key="e.clave" class="pc__etapa">
            <div class="pc__etapa-barra-wrap"><div class="pc__etapa-barra" :class="`pc__etapa-barra--${e.clave}`" :style="{ '--alto': `${e.alto}%` }" /></div>
            <span class="pc__etapa-lbl">{{ e.label }}</span>
            <span class="pc__etapa-num num" :class="{ 'is-neg': e.clave === 'diferencias' && e.valor > 0 }">{{ gramos(e.valor) }}</span>
            <span v-if="e.nota" class="pc__etapa-nota">{{ e.nota }}</span>
          </div>
        </div>
      </section>

      <!-- ══ Estado de las sedes + Actividad del equipo ══════════════════════ -->
      <section class="pc__fila pc__fila--sedes">
        <div class="pc__card pc__sedes">
          <h2 class="pc__h2 pc__pad">Estado de las sedes</h2>
          <div class="pc__tabla-wrap">
            <table class="pc__tabla">
              <thead>
                <tr><th scope="col">Sede</th><th scope="col">Caja</th><th scope="col" class="r">Dispensado hoy</th>
                  <th scope="col" class="r">En mostrador</th><th scope="col" class="r">Último cierre</th></tr>
              </thead>
              <tbody>
                <tr v-for="s in data.estado_sedes" :key="s.id">
                  <td><RouterLink :to="ruta(`/mostrador?sede=${s.id}`)" class="pc__sede-link">{{ s.nombre }}</RouterLink></td>
                  <td>
                    <span class="pc__estado">
                      <span class="pc__punto" :class="s.caja ? 'pc__punto--ok' : 'pc__punto--off'" aria-hidden="true"></span>
                      <template v-if="s.caja">Abierta {{ cuando(s.caja.abierta_at) }} · {{ s.caja.responsable }}</template>
                      <template v-else>Cerrada</template>
                    </span>
                  </td>
                  <td class="r num">{{ s.dispensado_hoy_ars || s.dispensado_hoy_g ? `${pesos(s.dispensado_hoy_ars)} · ${gramos(s.dispensado_hoy_g)}` : '—' }}</td>
                  <td class="r num">{{ gramos(s.en_mostrador_g) }}</td>
                  <td class="r num" :class="{ 'is-neg': s.ultimo_cierre?.diferencia_ars < 0 }">
                    <template v-if="!s.ultimo_cierre">—</template>
                    <template v-else-if="!s.ultimo_cierre.diferencia_ars">Sin diferencias</template>
                    <template v-else>{{ s.ultimo_cierre.diferencia_ars < 0 ? '−' : '+' }} {{ pesos(Math.abs(s.ultimo_cierre.diferencia_ars)) }}</template>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <div class="pc__card pc__equipo">
          <h2 class="pc__h2">Actividad del equipo · hoy</h2>
          <p v-if="!data.equipo.length" class="pc__vacio">Sin actividad registrada hoy.</p>
          <ul class="pc__equipo-lista">
            <li v-for="p in data.equipo" :key="p.id" class="pc__persona">
              <span class="pc__avatar" :class="{ 'is-warn': p.alertas.length }" aria-hidden="true">{{ iniciales(p.nombre) }}</span>
              <span class="pc__persona-txt">
                <b>{{ p.nombre }}</b> · {{ ROL[p.rol] || p.rol }}
                <span v-if="p.actividad.length" class="pc__persona-act">{{ p.actividad.join(' · ') }}</span>
                <span v-if="p.alertas.length" class="pc__persona-alerta">{{ p.alertas.join(' · ') }}</span>
              </span>
            </li>
          </ul>
        </div>
      </section>

      <!-- ══ Ingresos y egresos diarios ══════════════════════════════════════ -->
      <section class="pc__card pc__serie" aria-labelledby="pc-serie">
        <div class="pc__card-hd">
          <h2 id="pc-serie" class="pc__h2">Ingresos y egresos diarios · {{ mesNombre }}</h2>
          <span class="pc__leyenda">
            <span><i class="pc__ley pc__ley--ing" />Ingresos</span>
            <span><i class="pc__ley pc__ley--egr" />Egresos</span>
            <span><i class="pc__ley pc__ley--ant" />Ingresos del mes anterior</span>
          </span>
        </div>
        <p v-if="!serie.hayDatos" class="pc__vacio">Sin movimientos contables registrados en {{ mesNombre }}.</p>
        <svg v-else class="pc__serie-svg" role="img" :aria-label="`Ingresos y egresos diarios de ${mesNombre}`"
             :viewBox="`0 0 ${serie.ancho} 160`" preserveAspectRatio="none">
          <line x1="0" y1="150" :x2="serie.ancho" y2="150" class="pc__serie-base" />
          <g v-for="d in serie.dias" :key="d.dia">
            <rect :x="d.x" :y="150 - d.hIng" :width="serie.barra" :height="d.hIng" rx="2" class="pc__serie-ing" />
            <rect :x="d.x + serie.barra + 1" :y="150 - d.hEgr" :width="serie.barra" :height="d.hEgr" rx="2" class="pc__serie-egr" />
          </g>
          <polyline v-if="serie.lineaAnt" :points="serie.lineaAnt" class="pc__serie-ant" />
        </svg>
        <div class="pc__serie-tot">
          <span>Ingresos <b class="num">{{ pesos(f.ingresos_ars) }}</b></span>
          <span>Egresos <b class="num">{{ pesos(f.egresos_ars) }}</b></span>
          <span>Resultado <b class="num">{{ pesos(f.resultado_ars) }}</b></span>
          <span class="pc__sub">({{ PERIODO_TXT[periodo] }})</span>
        </div>
      </section>
    </template>

    <DetalleCierrePanel v-if="cierreAbierto" :asunto="cierreAbierto" :ruta="ruta" @close="cierreAbierto = null" @revisado="alRevisar" />
  </div>
</template>

<script setup>
import { computed, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import { getPanelConduccion } from '../../lib/api.js'
import { useRecargaEnCambios } from '../../composables/useRecargaEnCambios.js'
import DetalleCierrePanel from './DetalleCierrePanel.vue'

const props = defineProps({
  // En el teléfono: una columna, y los enlaces van a las pantallas del teléfono.
  compacto: { type: Boolean, default: false },
})

// Adónde lleva cada enlace en el teléfono: la pantalla de escritorio dentro del shell `/m` sale
// cortada. Lo que no tiene pantalla de teléfono va a la de escritorio.
const MOVIL = {
  '/tareas': '/m/admin/tareas', '/admin/pesajes-manicura': '/m/admin/aprobar', '/pacientes': '/m/pacientes',
  '/mostrador': '/m/mostrador', '/delivery/rendiciones': '/m/mostrador', '/admin/stock': '/m/stock',
  '/salas': '/m/admin/sedes',
}
function ruta (path) {
  if (!props.compacto || !path) return path
  const [base, query] = path.split('?')
  if (base.startsWith('/dispensaciones/')) return '/m/historial'
  return MOVIL[base] ? MOVIL[base] + (query ? `?${query}` : '') : path
}

const router = useRouter()

const PERIODOS = [{ id: 'hoy', label: 'Hoy' }, { id: 'semana', label: 'Semana' }, { id: 'mes', label: 'Mes' }]
const PERIODO_TXT = { hoy: 'hoy', semana: 'esta semana', mes: 'en el mes' }
const ANTERIOR_TXT = { hoy: 'ayer', semana: 'la semana anterior', mes: 'el mes anterior' }
const ROL = {
  admin: 'Administración', cultivador: 'Cultivo', supervisor: 'Supervisión', manicura: 'Manicura',
  dispensador: 'Mostrador', delivery: 'Delivery', medico: 'Consultorio',
}

const data     = ref(null)
const cargando = ref(false)
const error    = ref('')
const sedeId   = ref(null)
const periodo  = ref('mes')
const cierreAbierto = ref(null)

async function cargar () {
  cargando.value = true
  try {
    const { data: d } = await getPanelConduccion({ sede_id: sedeId.value || undefined, periodo: periodo.value })
    data.value = d
    error.value = ''
  } catch {
    error.value = 'No se pudo cargar el panel. Se reintentará con el próximo cambio.'
  } finally {
    cargando.value = false
  }
}

function elegirSede (id) { sedeId.value = id; cargar() }
function elegirPeriodo (p) { periodo.value = p; cargar() }

// Un cierre (caja o inventario) se analiza en el panel lateral; el resto lleva a su pantalla.
function abrir (a) {
  if (a.turno_id) cierreAbierto.value = a
  else if (a.ruta) router.push(ruta(a.ruta))
}
function alRevisar () { cierreAbierto.value = null; cargar() }

onMounted(cargar)
useRecargaEnCambios(['stocks', 'lotes', 'plantas', 'pesajes', 'dispensaciones', 'mostrador', 'cajas',
                     'contabilidad', 'tareas', 'pacientes', 'turnos'], cargar)

const sedes    = computed(() => data.value?.sedes || [])
const atencion = computed(() => data.value?.atencion || [])
const f   = computed(() => data.value?.finanzas || {})
const inv = computed(() => data.value?.inventario || {})
const pac = computed(() => data.value?.pacientes || {})
const cul = computed(() => data.value?.cultivo || {})

// Las cinco etapas, con el alto relativo a la mayor. Las notas dicen la diferencia entre etapas.
const etapas = computed(() => {
  const t = data.value?.trazabilidad || {}
  const lista = [
    { clave: 'cosecha', label: 'Cosecha (peso seco)', valor: t.cosecha_g },
    { clave: 'stock', label: 'Ingreso a stock', valor: t.ingreso_stock_g,
      nota: t.cosecha_g > t.ingreso_stock_g && t.ingreso_stock_g > 0
        ? `Merma de curado y manicura: − ${gramos(t.cosecha_g - t.ingreso_stock_g)} (${pct(t.cosecha_g - t.ingreso_stock_g, t.cosecha_g)})` : null },
    { clave: 'mostrador', label: 'Asignado a mostrador', valor: t.a_mostrador_g },
    { clave: 'dispensado', label: 'Dispensado', valor: t.dispensado_g,
      nota: t.pacientes ? `${t.pacientes} paciente${t.pacientes === 1 ? '' : 's'}` : null },
    { clave: 'diferencias', label: 'Diferencias de inventario', valor: t.diferencias_g,
      nota: t.a_mostrador_g > 0 && t.diferencias_g > 0 ? `${pct(t.diferencias_g, t.a_mostrador_g)} del volumen en mostrador` : null },
  ]
  const max = Math.max(1, ...lista.map(e => Number(e.valor) || 0))
  return lista.map(e => ({ ...e, alto: Math.max(e.valor > 0 ? 3 : 0, (Number(e.valor) || 0) / max * 100) }))
})

const serie = computed(() => {
  const dias = data.value?.serie_mes || []
  const ancho = 1000
  const paso = dias.length ? ancho / dias.length : ancho
  const barra = Math.max(2, paso / 2 - 2)
  const max = Math.max(1, ...dias.flatMap(d => [d.ingresos, d.egresos, d.ingresos_mes_anterior || 0]))
  const h = (v) => (Number(v) || 0) / max * 140
  const conAnt = dias.filter(d => d.ingresos_mes_anterior !== null)
  return {
    ancho, barra, hayDatos: dias.some(d => d.ingresos || d.egresos || d.ingresos_mes_anterior),
    dias: dias.map((d, i) => ({ dia: d.dia, x: i * paso + 1, hIng: h(d.ingresos), hEgr: h(d.egresos) })),
    lineaAnt: conAnt.length > 1
      ? conAnt.map((d) => `${(d.dia - 1) * paso + barra},${150 - h(d.ingresos_mes_anterior)}`).join(' ') : '',
  }
})

const ahora = new Date()
const fechaLarga = ahora.toLocaleDateString('es-AR', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' })
  .replace(/^./, c => c.toUpperCase())
const horaActual = ahora.toLocaleTimeString('es-AR', { hour: '2-digit', minute: '2-digit', hourCycle: 'h23' })
const mesNombre = ahora.toLocaleDateString('es-AR', { month: 'long' })

const entero = (n) => Number(n || 0).toLocaleString('es-AR', { maximumFractionDigits: 0 })
const pesos  = (n) => `$ ${Math.round(Number(n || 0)).toLocaleString('es-AR')}`
const gramos = (n) => {
  const v = Number(n || 0)
  return v >= 10000 ? `${(v / 1000).toLocaleString('es-AR', { maximumFractionDigits: 1 })} kg`
                    : `${v.toLocaleString('es-AR', { maximumFractionDigits: 1 })} g`
}
const pct = (a, b) => `${(b ? a / b * 100 : 0).toLocaleString('es-AR', { maximumFractionDigits: 1 })} %`
const diasTxt = (d) => d === 0 ? 'Hoy' : `${Math.abs(d)} ${Math.abs(d) === 1 ? 'día' : 'días'}`

function valorAsunto (a) {
  if (a.valor === null || a.valor === undefined) return ''
  if (a.unidad === 'ars') return `${a.valor < 0 ? '− ' : ''}${pesos(Math.abs(a.valor))}`
  if (a.unidad === 'dias') return `${a.valor} ${a.valor === 1 ? 'día' : 'días'}`
  return `${Number(a.valor).toLocaleString('es-AR', { maximumFractionDigits: 2 })} ${a.unidad}`
}

function cuando (iso) {
  const d = new Date(iso)
  const hoy = new Date()
  const hh = d.toLocaleTimeString('es-AR', { hour: '2-digit', minute: '2-digit', hourCycle: 'h23' })
  return d.toDateString() === hoy.toDateString() ? hh : `${d.toLocaleDateString('es-AR', { day: '2-digit', month: '2-digit' })} ${hh}`
}

const iniciales = (n) => String(n || '').split(/\s+/).filter(Boolean).slice(0, 2).map(p => p[0].toUpperCase()).join('')
</script>

<style scoped>
.pc { display: flex; flex-direction: column; gap: 24px; max-width: 1180px; margin: 0 auto; width: 100%; }
.num { font-family: var(--font-mono); font-variant-numeric: tabular-nums; }
.is-neg { color: var(--c-rust-600); }
.is-pos { color: var(--c-leaf-600); }

/* Encabezado */
.pc__hd { display: flex; flex-wrap: wrap; align-items: flex-end; justify-content: space-between; gap: 16px; }
.pc__hd-txt { display: flex; flex-direction: column; gap: 6px; min-width: 0; flex: 1 1 520px; }
.pc__fecha { font-size: var(--fs-13); color: var(--c-ink-500); }
.pc__veredicto { margin: 0; font-family: var(--font-display); font-size: 30px; font-weight: 600; line-height: 1.2; color: var(--c-ink-900); }
.pc__veredicto-warn { color: var(--c-amber-500); }
.pc__filtros { display: flex; flex-wrap: wrap; gap: 8px; }
.pc__seg { display: flex; flex-wrap: wrap; background: white; border: 1px solid var(--c-leaf-100); border-radius: 10px; padding: 3px; }
.pc__seg-btn { border: 0; background: transparent; border-radius: 8px; padding: 8px 14px; min-height: 36px; font: 600 var(--fs-13) var(--font-ui); color: var(--c-ink-700); cursor: pointer; }
.pc__seg-btn.is-on { background: var(--c-leaf-800); color: white; }
.pc__error { margin: 0; color: var(--c-rust-600); font-size: var(--fs-13); }

/* Tarjetas */
.pc__card { background: white; border: 1px solid var(--c-leaf-100); border-radius: 16px; }
.pc__card-hd { display: flex; flex-wrap: wrap; align-items: baseline; justify-content: space-between; gap: 6px 16px; padding: 18px 22px 12px; }
.pc__h2 { margin: 0; font-family: var(--font-display); font-size: 18px; font-weight: 600; color: var(--c-ink-900); }
.pc__h2--claro { color: white; }
.pc__pad { padding: 18px 22px 12px; }
.pc__sub { font-size: var(--fs-12); color: var(--c-ink-500); }
.pc__vacio { margin: 0; padding: 14px 22px 20px; font-size: var(--fs-13); color: var(--c-ink-500); }
.pc__fila { display: grid; gap: 20px; }
.pc__fila--atencion { grid-template-columns: minmax(0, 2fr) minmax(0, 1fr); }
.pc__fila--sedes { grid-template-columns: minmax(0, 3fr) minmax(0, 2fr); }

/* Requiere atención */
.pc__atencion { overflow: hidden; }
.pc__asunto {
  display: grid; grid-template-columns: 10px minmax(0, 1fr) auto auto; gap: 16px; align-items: center;
  width: 100%; padding: 16px 22px; border: 0; border-top: 1px solid var(--c-leaf-50); background: none;
  text-align: left; font: inherit; color: inherit; cursor: pointer;
}
.pc__asunto:hover { background: var(--c-leaf-50); }
.pc__punto { width: 10px; height: 10px; border-radius: 50%; display: inline-block; flex: 0 0 auto; }
.pc__punto--alta { background: var(--c-rust-600); }
.pc__punto--media { background: var(--c-amber-500); }
.pc__punto--baja { background: var(--c-ink-300); }
.pc__punto--ok { background: var(--c-leaf-500); width: 8px; height: 8px; }
.pc__punto--off { background: var(--c-ink-300); width: 8px; height: 8px; }
.pc__asunto-txt { display: flex; flex-direction: column; gap: 3px; min-width: 0; }
.pc__asunto-tit { font-weight: 600; font-size: 15px; color: var(--c-ink-900); }
.pc__asunto-det { font-size: var(--fs-13); color: var(--c-ink-700); }
.pc__asunto-val { font-size: 17px; font-weight: 600; white-space: nowrap; color: var(--c-ink-900); }
.pc__asunto-val.is-neg { color: var(--c-rust-600); }
.pc__asunto-acc {
  font-size: var(--fs-13); font-weight: 600; color: var(--c-leaf-800); border: 1px solid var(--c-leaf-300);
  border-radius: 8px; padding: 8px 12px; white-space: nowrap;
}
.pc__seguimiento {
  display: flex; flex-wrap: wrap; gap: 6px 18px; padding: 14px 22px 18px; border-top: 1px solid var(--c-leaf-50);
  background: var(--c-paper); font-size: var(--fs-13); color: var(--c-ink-700);
}
.pc__seg-lbl { font-weight: 600; }
.pc__seg-item { color: var(--c-ink-700); text-decoration: none; }
.pc__seg-item:hover { text-decoration: underline; }
.pc__seg-item b { color: var(--c-ink-900); }

/* Dentro de parámetros */
.pc__orden { background: var(--c-leaf-800); border-color: var(--c-leaf-800); color: var(--c-leaf-100); padding: 20px 22px; display: flex; flex-direction: column; gap: 14px; }
.pc__orden-lista { margin: 0; padding: 0; list-style: none; display: flex; flex-direction: column; gap: 12px; font-size: 14px; }
.pc__orden-lista li { display: flex; gap: 10px; align-items: flex-start; }
.pc__orden-lista svg { flex: 0 0 auto; margin-top: 1px; color: var(--c-leaf-300); }
.pc__orden-lista b { color: white; }
.pc__orden-vacio { margin: 0; font-size: var(--fs-13); }
.pc__orden-pie { margin-top: auto; font-size: var(--fs-12); color: var(--c-leaf-300); }

/* KPIs */
.pc__kpis { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 16px; }
.pc__kpi { padding: 18px 20px; display: flex; flex-direction: column; gap: 8px; text-decoration: none; color: inherit; }
.pc__kpi:hover { border-color: var(--c-leaf-300); }
.pc__kpi-eje { font-size: var(--fs-12); font-weight: 600; letter-spacing: .08em; text-transform: uppercase; color: var(--c-leaf-600); }
.pc__kpi-num { font-size: 26px; font-weight: 600; letter-spacing: -.02em; color: var(--c-ink-900); }
.pc__kpi-txt { font-size: var(--fs-13); color: var(--c-ink-700); }
.pc__kpi-txt b { color: var(--c-ink-900); }
.pc__barra { height: 8px; background: var(--c-leaf-50); border-radius: 99px; overflow: hidden; margin: 4px 0; }
.pc__barra-in { height: 100%; background: var(--c-leaf-500); border-radius: 99px; }
.pc__barra-in.is-warn { background: var(--c-amber-500); }
.pc__dl { margin: auto 0 0; display: grid; grid-template-columns: minmax(0, 1fr) auto; gap: 6px 10px; font-size: var(--fs-13); border-top: 1px solid var(--c-leaf-50); padding-top: 10px; }
.pc__dl dt { color: var(--c-ink-500); }
.pc__dl dd { margin: 0; font-weight: 600; color: var(--c-ink-900); }

/* Trazabilidad */
.pc__traza { padding-bottom: 22px; }
.pc__etapas { display: grid; grid-template-columns: repeat(5, minmax(0, 1fr)); gap: 12px; padding: 4px 22px 0; align-items: end; }
.pc__etapa { display: flex; flex-direction: column; gap: 6px; }
.pc__etapa-barra-wrap { height: 120px; display: flex; align-items: flex-end; }
.pc__etapa-barra { width: 100%; height: var(--alto); border-radius: 8px; }
.pc__etapa-barra--cosecha { background: var(--c-leaf-900); }
.pc__etapa-barra--stock { background: var(--c-leaf-700); }
.pc__etapa-barra--mostrador { background: var(--c-leaf-600); }
.pc__etapa-barra--dispensado { background: var(--c-leaf-500); }
.pc__etapa-barra--diferencias { background: var(--c-rust-600); }
.pc__etapa-lbl { font-size: var(--fs-13); color: var(--c-ink-700); }
.pc__etapa-num { font-size: 19px; font-weight: 600; color: var(--c-ink-900); }
.pc__etapa-nota { font-size: var(--fs-12); color: var(--c-ink-500); }

/* Sedes */
.pc__sedes { overflow: hidden; }
.pc__tabla-wrap { overflow-x: auto; }
.pc__tabla { width: 100%; border-collapse: collapse; font-size: var(--fs-13); min-width: 560px; }
.pc__tabla th { text-align: left; color: var(--c-ink-500); font-size: var(--fs-12); font-weight: 600; padding: 10px 12px; border-top: 1px solid var(--c-leaf-50); }
.pc__tabla td { padding: 14px 12px; border-top: 1px solid var(--c-leaf-50); color: var(--c-ink-900); }
.pc__tabla th:first-child, .pc__tabla td:first-child { padding-left: 22px; }
.pc__tabla th:last-child, .pc__tabla td:last-child { padding-right: 22px; }
.pc__tabla .r { text-align: right; }
.pc__sede-link { font-weight: 600; color: var(--c-ink-900); text-decoration: none; }
.pc__sede-link:hover { text-decoration: underline; }
.pc__estado { display: inline-flex; align-items: center; gap: 6px; }

/* Equipo */
.pc__equipo { padding: 18px 22px; display: flex; flex-direction: column; gap: 14px; }
.pc__equipo-lista { margin: 0; padding: 0; list-style: none; display: flex; flex-direction: column; gap: 12px; }
.pc__persona { display: grid; grid-template-columns: 34px minmax(0, 1fr); gap: 12px; align-items: center; font-size: var(--fs-13); }
.pc__avatar { width: 34px; height: 34px; border-radius: 50%; background: var(--c-leaf-100); color: var(--c-leaf-800); font-weight: 600; display: flex; align-items: center; justify-content: center; }
.pc__avatar.is-warn { background: var(--c-amber-100); color: var(--c-ink-900); }
.pc__persona-txt { display: flex; flex-direction: column; gap: 2px; color: var(--c-ink-900); }
.pc__persona-act { color: var(--c-ink-700); }
.pc__persona-alerta { color: var(--c-rust-600); }

/* Serie */
.pc__serie { padding-bottom: 18px; }
.pc__leyenda { display: flex; flex-wrap: wrap; gap: 14px; font-size: var(--fs-12); color: var(--c-ink-700); }
.pc__leyenda span { display: inline-flex; align-items: center; gap: 6px; }
.pc__ley { width: 12px; height: 12px; border-radius: 3px; display: inline-block; }
.pc__ley--ing { background: var(--c-leaf-600); }
.pc__ley--egr { background: var(--c-amber-500); }
.pc__ley--ant { height: 0; border-top: 2px dashed var(--c-ink-300); border-radius: 0; width: 14px; }
.pc__serie-svg { width: 100%; height: 160px; display: block; padding: 0 22px; box-sizing: border-box; }
.pc__serie-base { stroke: var(--c-leaf-100); }
.pc__serie-ing { fill: var(--c-leaf-600); }
.pc__serie-egr { fill: var(--c-amber-500); opacity: .75; }
.pc__serie-ant { fill: none; stroke: var(--c-ink-300); stroke-width: 2; stroke-dasharray: 5 5; vector-effect: non-scaling-stroke; }
.pc__serie-tot { display: flex; flex-wrap: wrap; gap: 8px 22px; padding: 10px 22px 0; font-size: var(--fs-13); color: var(--c-ink-700); align-items: baseline; }
.pc__serie-tot b { color: var(--c-ink-900); }

/* Carga */
.pc__skel { display: flex; flex-direction: column; gap: 16px; }
.pc__skel-b { height: 140px; border-radius: 16px; background: var(--c-leaf-50); }
.pc__skel-b--alto { height: 260px; }

/* Dentro del shell del teléfono (también en una tablet): una columna, sea cual sea el ancho. */
.pc--compacto .pc__kpis { grid-template-columns: repeat(2, minmax(0, 1fr)); }
.pc--compacto .pc__fila--atencion, .pc--compacto .pc__fila--sedes { grid-template-columns: minmax(0, 1fr); }
.pc--compacto .pc__veredicto { font-size: 22px; }

/* Pantallas angostas y teléfono */
@media (max-width: 1100px) {
  .pc__kpis { grid-template-columns: repeat(2, minmax(0, 1fr)); }
  .pc__fila--atencion, .pc__fila--sedes { grid-template-columns: minmax(0, 1fr); }
}
@media (max-width: 640px) {
  .pc { gap: 16px; }
  .pc__veredicto { font-size: 22px; }
  .pc__asunto { grid-template-columns: 8px minmax(0, 1fr) auto; gap: 10px; padding: 14px 16px; }
  .pc__asunto-acc { display: none; }
  .pc__card-hd, .pc__pad { padding: 14px 16px 8px; }
  .pc__kpis { gap: 10px; }
  .pc__kpi { padding: 14px; }
  .pc__kpi-num { font-size: 19px; }
  .pc__dl { display: none; }
  .pc__etapas { grid-template-columns: minmax(0, 1fr); padding: 4px 16px 0; gap: 10px; }
  .pc__etapa { display: grid; grid-template-columns: 120px minmax(0, 1fr) auto; align-items: center; gap: 8px; }
  .pc__etapa-barra-wrap { order: 2; height: 10px; }
  .pc__etapa-lbl { order: 1; }
  .pc__etapa-num { order: 3; font-size: 14px; }
  .pc__etapa-nota { grid-column: 1 / -1; order: 4; }
  .pc__etapa-barra { height: 10px; width: var(--alto); border-radius: 99px; }
  .pc__seguimiento { padding: 12px 16px 14px; }
}
</style>
