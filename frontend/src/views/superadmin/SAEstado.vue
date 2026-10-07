<script setup>
// EL ESTADO DE LA PLATAFORMA: ¿anda todo? Y si no, qué y qué hacer.
//
// Pensada para que la entienda cualquiera que la abra, no sólo quien programa: arriba una frase y
// un semáforo; debajo, cada aviso con lo que pasa en castellano y qué hacer; después el detalle
// (servidores, backups, trabajos en segundo plano, cuánto pesa cada organización).
//
// El cálculo vive en el backend (`Infra::Estado`); acá sólo se muestra. Se actualiza sola cada
// minuto. Si la app se cae, esta pantalla se cae con ella: para enterarse de eso está el monitor
// externo (docs/INFRA.md).
import { ref, computed, onMounted, onBeforeUnmount } from 'vue'
import DsSpinner from '../../design-system/components/Spinner.vue'
import { getSuperAdminEstado } from '../../lib/api.js'
import {
  CheckCircle2, AlertTriangle, XCircle, Info, PowerOff, RefreshCw, Server, Database,
  HardDrive, Cpu, Clock, Archive, ExternalLink, Building2, ListChecks,
} from 'lucide-vue-next'

const datos    = ref(null)
const cargando = ref(true)
const error    = ref(null)
const verOtros = ref(false)
// Lo técnico arranca cerrado: quien no programa lee las cuatro preguntas y listo (7-oct-2026).
const verDetalle = ref(false)
let timer = null

async function cargar () {
  try {
    const { data } = await getSuperAdminEstado()
    datos.value = data
    error.value = null
  } catch (e) {
    error.value = e?.response?.status === 403 ? 'Sólo el super admin puede ver esta pantalla.' : 'No se pudo cargar el estado. ¿Está andando la app?'
  } finally {
    cargando.value = false
  }
}

onMounted(() => {
  cargar()
  timer = setInterval(cargar, 60_000)
})
onBeforeUnmount(() => clearInterval(timer))

// ── Cómo se nombra cada estado: siempre con ícono y palabra, nunca sólo color ──
const NIVELES = {
  ok:          { label: 'Funcionando', icono: CheckCircle2 },
  atencion:    { label: 'Para mirar',  icono: AlertTriangle },
  mal:         { label: 'No funciona', icono: XCircle },
  info:        { label: 'Sugerencia',  icono: Info },
  apagado:     { label: 'Apagado',     icono: PowerOff },
  desconocido: { label: 'Sin datos',   icono: Info },
}
const nivel = (n) => NIVELES[n] || NIVELES.desconocido

const TIPO_ICONO = { web: Server, worker: Cpu, cron: Clock, base: Database, redis: HardDrive, estatico: Server }

const servidores  = computed(() => datos.value?.servidores?.servidores || [])
const produccion  = computed(() => servidores.value.filter(s => s.en_produccion))
const otros       = computed(() => servidores.value.filter(s => !s.en_produccion))
const chequeos    = computed(() => datos.value?.chequeos || {})
const trabajos    = computed(() => datos.value?.cola?.trabajos || {})
const cron        = computed(() => datos.value?.cola?.cron || [])
const backup      = computed(() => datos.value?.backup || {})
const orgs        = computed(() => datos.value?.organizaciones || {})
const monitoreo   = computed(() => datos.value?.monitoreo || {})
const preguntas   = computed(() => datos.value?.preguntas || [])
const lentitud    = computed(() => datos.value?.lentitud || { lentas: [], por_hora: [] })

// «3,1 s» o «420 ms»: como lo diría una persona.
const tiempo = (ms) => ms == null ? '—' : ms < 1000 ? `${ms} ms` : `${(ms / 1000).toLocaleString('es-AR', { maximumFractionDigits: 1 })} s`
const tonoMs = (ms) => ms == null ? 'ok' : ms >= (lentitud.value.lento_ms || 1500) ? 'mal' : ms >= (lentitud.value.normal_ms || 500) ? 'atencion' : 'ok'
// La barra de cada fila, contra 4 segundos (más que eso ya está lleno de lento).
const anchoMs = (ms) => `${Math.max(3, Math.min(100, ((ms || 0) / 4000) * 100))}%`
const barrasHora = computed(() => {
  const lista = lentitud.value.por_hora || []
  const tope = Math.max(...lista.map(h => h.ms || 0), lentitud.value.lento_ms || 1500)
  return lista.map(h => ({
    h: h.ms ? Math.max(4, (h.ms / tope) * 100) : 2,
    tono: tonoMs(h.ms),
    titulo: `${hora(h.hora)}: ${h.pedidos} pedidos${h.ms ? `, la mayoría en ${tiempo(h.ms)}` : ''}`,
  }))
})
const SEMAFORO = { ok: 'Todo funciona', atencion: 'Funciona, con cosas para mirar', mal: 'Algo no funciona' }

// ── Formatos ──
const num = (n, dec = 0) => Number(n ?? 0).toLocaleString('es-AR', { maximumFractionDigits: dec })
function hace (fecha) {
  if (!fecha) return 'nunca'
  const min = Math.round((Date.now() - new Date(fecha).getTime()) / 60000)
  if (min < 1) return 'recién'
  if (min < 60) return `hace ${min} min`
  const h = Math.round(min / 60)
  if (h < 48) return `hace ${h} h`
  return `hace ${Math.round(h / 24)} días`
}
const hora = (f) => f ? new Date(f).toLocaleTimeString('es-AR', { hour: '2-digit', minute: '2-digit' }) : ''
const fechaCorta = (f) => f ? new Date(f).toLocaleDateString('es-AR', { day: '2-digit', month: '2-digit' }) : '—'

// Uso de un recurso contra lo que da el plan: el tono lo dice el porcentaje.
const tonoUso = (pct) => pct == null ? 'ok' : pct >= 90 ? 'mal' : pct >= 75 ? 'atencion' : 'ok'
function textoMedida (m) {
  if (!m) return '—'
  const u = m.unidad === 'MB' ? 'MB' : 'CPU'
  const actual = u === 'MB' ? `${num(m.actual)} MB` : `${num(m.actual, 2)} CPU`
  return m.limite ? `${actual} de ${u === 'MB' ? `${num(m.limite)} MB` : `${num(m.limite, 1)} CPU`}` : actual
}
// Una barra por hora, de las últimas 24. Altura relativa al límite del plan si lo hay (así «lleno»
// se ve lleno), o al pico si no.
function barras (m) {
  if (!m?.serie?.length) return []
  const tope = m.limite || Math.max(...m.serie, 0.0001)
  const n = m.serie.length
  return m.serie.map((v, i) => ({
    h: Math.max(2, Math.min(100, (v / tope) * 100)),
    titulo: `${n - i === 1 ? 'Última hora' : `Hace ${n - i} h`}: ${m.unidad === 'MB' ? `${num(v)} MB` : `${num(v, 2)} CPU`}`,
  }))
}
function barrasBackup (lista) {
  const l = [...(lista || [])].reverse()
  const tope = Math.max(...l.map(b => b.tamano_mb), 0.1)
  return l.map(b => ({ h: Math.max(4, (b.tamano_mb / tope) * 100), titulo: `${fechaCorta(b.fecha)}: ${num(b.tamano_mb, 1)} MB` }))
}
</script>

<template>
  <div class="est">
    <header class="est__head">
      <div>
        <h1 class="sa-h1">Estado de la plataforma</h1>
        <p class="sa-ayuda">Se actualiza sola cada minuto<template v-if="datos"> · última vez a las {{ hora(datos.generado_at) }}</template>.</p>
      </div>
      <button class="est__btn" :disabled="cargando" @click="cargando = true; cargar()">
        <RefreshCw :size="15" :class="{ 'est__girando': cargando }" /> Actualizar
      </button>
    </header>

    <div v-if="cargando && !datos" class="est__cargando"><DsSpinner :size="22" /> Mirando todo…</div>
    <div v-else-if="error" class="est__error"><XCircle :size="18" /> {{ error }}</div>

    <template v-else-if="datos">
      <!-- ── El semáforo: una frase, sin jerga ─────────────────────────── -->
      <section class="est__semaforo" :class="`est__semaforo--${datos.estado}`" aria-live="polite">
        <div class="est__luces" aria-hidden="true">
          <span :class="{ 'is-on': datos.estado === 'mal' }"></span>
          <span :class="{ 'is-on': datos.estado === 'atencion' }"></span>
          <span :class="{ 'is-on': datos.estado === 'ok' }"></span>
        </div>
        <div>
          <div class="est__semaforo-tit">{{ SEMAFORO[datos.estado] || datos.frase }}</div>
          <div class="est__semaforo-txt">{{ datos.frase }}</div>
        </div>
      </section>

      <!-- ── Las cuatro preguntas ───────────────────────────────────────── -->
      <div class="est__preguntas">
        <article v-for="p in preguntas" :key="p.clave" class="est__pregunta" :class="`est__pregunta--${p.estado}`">
          <div class="est__pregunta-head">
            <span class="sa-punto" :class="`sa-punto--${p.estado}`"></span>
            <h2 class="est__pregunta-tit">{{ p.titulo }}</h2>
            <span class="sa-tag" :class="`sa-tag--${p.estado === 'desconocido' ? 'info' : p.estado}`">{{ p.etiqueta }}</span>
          </div>
          <p class="est__pregunta-frase">{{ p.frase }}</p>
          <p v-if="p.significa || p.hacer" class="est__pregunta-mas">
            <span v-if="p.significa" class="est__pregunta-parte"><b>Qué significa:</b> {{ p.significa }}</span>
            <span v-if="p.hacer" class="est__pregunta-parte"><b>Qué hacer:</b> {{ p.hacer }}</span>
          </p>
        </article>
      </div>

      <!-- ── Lo más lento de hoy ────────────────────────────────────────── -->
      <section class="sa-card">
        <div class="est__sec-head">
          <h2 class="sa-h2">Lo más lento de hoy</h2>
          <span class="sa-tenue">Normal: menos de {{ tiempo(lentitud.normal_ms) }} · Lento: más de {{ tiempo(lentitud.lento_ms) }}</span>
        </div>
        <p v-if="!lentitud.lentas?.length" class="sa-vacio">
          {{ lentitud.estado === 'desconocido' ? 'Todavía no hay tiempos medidos.' : 'Hoy todavía no hay suficiente movimiento para decir qué es lento.' }}
        </p>
        <div v-else class="sa-tabla-wrap est__tabla-lenta">
          <table class="sa-tabla">
            <thead><tr><th>Qué se abre</th><th>Dónde</th><th>Cuánto tarda (la mayoría de las veces)</th><th class="sa-der">Veces hoy</th></tr></thead>
            <tbody>
              <tr v-for="f in lentitud.lentas" :key="`${f.endpoint}-${f.donde}`">
                <td><span class="sa-fuerte">{{ f.que }}</span><br><span class="sa-tenue">{{ f.endpoint }}</span></td>
                <td>{{ f.donde }}</td>
                <td>
                  <span class="est__lento">
                    <span class="est__lento-barra"><span :class="`est__lento--${tonoMs(f.ms)}`" :style="{ width: anchoMs(f.ms) }"></span></span>
                    <span class="sa-num est__lento-n" :class="`est__lento-n--${tonoMs(f.ms)}`">{{ tiempo(f.ms) }}</span>
                  </span>
                </td>
                <td class="sa-num sa-der">{{ num(f.veces) }}</td>
              </tr>
            </tbody>
          </table>
        </div>
        <div v-if="barrasHora.length" class="est__horas">
          <div class="est__horas-tit">Velocidad en las últimas 24 horas</div>
          <div class="est__horas-barras" role="img" :aria-label="'Velocidad por hora, últimas 24 horas'">
            <span v-for="(b, i) in barrasHora" :key="i" :class="`est__hb--${b.tono}`" :style="{ height: `${b.h}%` }" :title="b.titulo"></span>
          </div>
          <div class="est__spark-pie"><span>hace 24 h</span><span>ahora</span></div>
        </div>
      </section>

      <!-- ── Lo técnico, guardado ───────────────────────────────────────── -->
      <button class="est__detalle-btn" :aria-expanded="verDetalle" @click="verDetalle = !verDetalle">
        <span><b>Detalle técnico</b> <span class="sa-tenue">— todos los avisos, servidores, base, backups, tareas programadas, uso por organización</span></span>
        <span>{{ verDetalle ? '▲' : '▼' }}</span>
      </button>
      <template v-if="verDetalle">
      <!-- ── Qué pasa y qué hacer ───────────────────────────────────────── -->
      <section v-if="datos.avisos.length" class="est__sec">
        <h2 class="est__h2">Qué hay que mirar</h2>
        <ul class="est__avisos">
          <li v-for="(a, i) in datos.avisos" :key="i" class="est__aviso" :class="`est__aviso--${a.nivel}`">
            <span class="est__pill" :class="`est__pill--${a.nivel}`"><component :is="nivel(a.nivel).icono" :size="13" /> {{ nivel(a.nivel).label }}</span>
            <div class="est__aviso-txt">
              <div class="est__aviso-que">{{ a.que }}</div>
              <div class="est__aviso-hacer">Qué hacer: {{ a.hacer }}</div>
            </div>
          </li>
        </ul>
      </section>

      <!-- ── Servidores (Render) ────────────────────────────────────────── -->
      <section class="est__sec">
        <div class="est__sec-head">
          <h2 class="est__h2">Servidores</h2>
          <span v-if="datos.servidores.configurado && !datos.servidores.error" class="est__marco">
            Costo estimado: <strong>US$ {{ num(datos.servidores.costo_usd_mes) }}/mes</strong> · precio de lista, la factura está en Render
          </span>
        </div>

        <div v-if="!datos.servidores.configurado" class="est__vacio">
          <Info :size="16" /> Todavía no está conectado a Render. Cuando se cargue la llave (RENDER_API_KEY), acá aparecen los
          servidores, su último cambio, cuánta memoria y CPU usan y el costo. Pasos en docs/INFRA.md.
        </div>
        <div v-else-if="datos.servidores.error" class="est__vacio est__vacio--atencion"><AlertTriangle :size="16" /> {{ datos.servidores.error }}</div>

        <div v-else class="est__grid">
          <article v-for="s in produccion" :key="s.id" class="est__card">
            <div class="est__card-top">
              <component :is="TIPO_ICONO[s.tipo] || Server" :size="18" class="est__card-ico" />
              <div class="est__card-tit">
                <div class="est__card-nombre">{{ s.titulo }}</div>
                <div class="est__card-render">{{ s.nombre }} · plan {{ s.plan || '—' }}<template v-if="s.precio_usd != null"> · US$ {{ num(s.precio_usd) }}/mes</template></div>
              </div>
            </div>
            <span class="est__pill est__pill--card" :class="`est__pill--${s.estado}`"><component :is="nivel(s.estado).icono" :size="13" /> {{ s.estado_texto }}</span>
            <p v-if="s.que_hace" class="est__card-que">{{ s.que_hace }}</p>

            <div v-if="s.deploy" class="est__deploy">
              <Clock :size="13" /> Último cambio {{ hace(s.deploy.fecha) }}<template v-if="s.deploy.mensaje">: «{{ s.deploy.mensaje }}»</template>
            </div>
            <div v-if="s.disco_gb" class="est__deploy"><HardDrive :size="13" /> Disco de {{ s.disco_gb }} GB · Postgres {{ s.version }}</div>

            <div v-if="s.recursos" class="est__recursos">
              <div v-for="(m, k) in { Memoria: s.recursos.memoria, CPU: s.recursos.cpu }" :key="k" class="est__medida">
                <template v-if="m">
                  <div class="est__medida-head">
                    <span>{{ k }}</span>
                    <span class="est__medida-val">{{ m.pct != null ? `${m.pct} %` : textoMedida(m) }}</span>
                  </div>
                  <div v-if="m.pct != null" class="est__medida-det">{{ textoMedida(m) }}</div>
                  <div class="est__barra"><div class="est__barra-uso" :class="`est__barra-uso--${tonoUso(m.pct)}`" :style="{ width: `${Math.min(100, m.pct ?? 0)}%` }"></div></div>
                  <div class="est__spark" role="img" :aria-label="`${k}, últimas 24 horas`">
                    <span v-for="(b, i) in barras(m)" :key="i" class="est__spark-b" :style="{ height: `${b.h}%` }" :title="b.titulo"></span>
                  </div>
                  <div class="est__spark-pie"><span>hace 24 h</span><span>pico {{ m.unidad === 'MB' ? `${num(m.pico)} MB` : `${num(m.pico, 2)} CPU` }}</span><span>ahora</span></div>
                </template>
              </div>
            </div>
            <a v-if="s.panel_url" :href="s.panel_url" target="_blank" rel="noopener" class="est__link">Abrir en Render <ExternalLink :size="12" /></a>
          </article>
        </div>

        <div v-if="otros.length" class="est__otros">
          <button class="est__otros-btn" @click="verOtros = !verOtros">
            {{ verOtros ? 'Ocultar' : 'Ver' }} {{ otros.length }} servicio{{ otros.length === 1 ? '' : 's' }} que no son de producción
          </button>
          <table v-if="verOtros" class="est__tabla">
            <thead><tr><th>Servicio</th><th>Qué es</th><th>Estado</th><th class="num">US$/mes</th></tr></thead>
            <tbody>
              <tr v-for="s in otros" :key="s.id">
                <td class="mono">{{ s.nombre }}</td>
                <td>{{ s.que_hace || s.tipo }}</td>
                <td><span class="est__pill est__pill--sm" :class="`est__pill--${s.estado}`"><component :is="nivel(s.estado).icono" :size="12" /> {{ s.estado_texto }}</span></td>
                <td class="num">{{ s.precio_usd == null ? '—' : num(s.precio_usd) }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>

      <!-- ── Desde adentro de la app ────────────────────────────────────── -->
      <section class="est__sec">
        <h2 class="est__h2">Lo que la app necesita para atender</h2>
        <div class="est__mini-grid">
          <div class="est__mini" :class="`est__mini--${chequeos.base?.estado}`">
            <Database :size="16" /><div><div class="est__mini-l">Base de datos</div>
            <div class="est__mini-v">{{ chequeos.base?.estado === 'mal' ? 'No responde' : `Responde en ${num(chequeos.base?.ms, 1)} ms` }}</div></div>
          </div>
          <div class="est__mini" :class="`est__mini--${chequeos.redis?.estado}`">
            <HardDrive :size="16" /><div><div class="est__mini-l">Redis</div>
            <div class="est__mini-v">
              <template v-if="chequeos.redis?.estado === 'mal'">No responde</template>
              <template v-else>{{ num(chequeos.redis?.memoria_mb, 1) }} MB usados<template v-if="chequeos.redis?.memoria_pct != null"> ({{ chequeos.redis.memoria_pct }} %)</template> · {{ chequeos.redis?.politica === 'noeviction' ? 'no borra trabajos' : `política ${chequeos.redis?.politica}` }}</template>
            </div></div>
          </div>
          <div class="est__mini" :class="`est__mini--${chequeos.worker?.estado}`">
            <Cpu :size="16" /><div><div class="est__mini-l">Trabajos en segundo plano</div>
            <div class="est__mini-v">{{ chequeos.worker?.estado === 'ok' ? `${chequeos.worker.procesos} worker andando · ${chequeos.worker.hilos} hilos` : 'Ningún worker andando' }}</div></div>
          </div>
          <div class="est__mini" :class="`est__mini--${trabajos.estado}`">
            <ListChecks :size="16" /><div><div class="est__mini-l">Fila de trabajos</div>
            <div class="est__mini-v">
              <template v-if="!trabajos.disponible">Sin datos</template>
              <template v-else>{{ num(trabajos.encolados) }} esperando<template v-if="trabajos.espera_seg"> (el más viejo, {{ Math.round(trabajos.espera_seg / 60) }} min)</template> · {{ num(trabajos.muertos) }} fallidos del todo</template>
            </div></div>
          </div>
        </div>
      </section>

      <!-- ── Backups ────────────────────────────────────────────────────── -->
      <section class="est__sec">
        <h2 class="est__h2"><Archive :size="17" /> Backups de la base</h2>
        <div v-if="!backup.disponible" class="est__vacio"><Info :size="16" /> {{ backup.motivo }}</div>
        <div v-else class="est__backup">
          <div class="est__backup-col">
            <span class="est__pill" :class="`est__pill--${backup.estado}`"><component :is="nivel(backup.estado).icono" :size="13" /> {{ backup.ultimo ? `Último: ${hace(backup.ultimo)}` : 'Nunca corrió' }}</span>
            <div class="est__backup-dato" v-if="backup.ultimo">{{ num(backup.tamano_mb, 1) }} MB · se guardan {{ backup.retencion_dias }} días ({{ backup.total }} copias)</div>
            <div class="est__backup-dato">
              <template v-if="!backup.verificacion">Todavía no se verificó ninguno.</template>
              <template v-else-if="backup.verificacion.ok"><CheckCircle2 :size="13" class="est__ok-ico" /> Verificado {{ hace(backup.verificacion.verificado_at) }}: se lee bien y trae {{ backup.verificacion.tablas }} tablas.</template>
              <template v-else><XCircle :size="13" class="est__mal-ico" /> La última verificación falló{{ backup.verificacion.faltan?.length ? ` (faltan ${backup.verificacion.faltan.join(', ')})` : '' }}.</template>
            </div>
            <div v-if="backup.bucket_compartido" class="est__backup-dato est__backup-dato--info"><Info :size="13" /> Comparten bucket con las fotos de los pacientes.</div>
          </div>
          <div v-if="backup.ultimos?.length" class="est__backup-col">
            <div class="est__mini-l">Tamaño de las últimas {{ backup.ultimos.length }} copias</div>
            <div class="est__spark est__spark--backup" role="img" aria-label="Tamaño de las últimas copias">
              <span v-for="(b, i) in barrasBackup(backup.ultimos)" :key="i" class="est__spark-b" :style="{ height: `${b.h}%` }" :title="b.titulo"></span>
            </div>
            <div class="est__spark-pie"><span>{{ fechaCorta(backup.ultimos[backup.ultimos.length - 1]?.fecha) }}</span><span>{{ fechaCorta(backup.ultimos[0]?.fecha) }}</span></div>
          </div>
        </div>
      </section>

      <!-- ── Tareas programadas ─────────────────────────────────────────── -->
      <section v-if="cron.length" class="est__sec">
        <h2 class="est__h2"><Clock :size="17" /> Tareas programadas</h2>
        <table class="est__tabla">
          <thead><tr><th>Tarea</th><th>Qué hace</th><th>Última vez</th><th>Estado</th></tr></thead>
          <tbody>
            <tr v-for="c in cron" :key="c.nombre">
              <td class="mono">{{ c.nombre }}</td>
              <td>{{ c.descripcion || '—' }}</td>
              <td>{{ hace(c.ultima) }}</td>
              <td><span class="est__pill est__pill--sm" :class="c.atrasado ? 'est__pill--atencion' : 'est__pill--ok'">
                <component :is="c.atrasado ? AlertTriangle : CheckCircle2" :size="12" /> {{ c.atrasado ? 'No corrió a tiempo' : 'Al día' }}</span></td>
            </tr>
          </tbody>
        </table>
      </section>

      <!-- ── Cuánto pesa cada organización ──────────────────────────────── -->
      <section class="est__sec">
        <div class="est__sec-head">
          <h2 class="est__h2"><Building2 :size="17" /> Cuánto usa cada organización</h2>
          <span class="est__marco">Base: <strong>{{ num(orgs.base?.tamano_mb, 1) }} MB</strong> · Archivos: <strong>{{ num(orgs.archivos?.cantidad) }}</strong> ({{ num(orgs.archivos?.tamano_mb, 1) }} MB)</span>
        </div>
        <table class="est__tabla">
          <thead><tr><th>Organización</th><th>Plan</th><th class="num">Pacientes</th><th class="num">Usuarios</th><th class="num">Dispensas (30 días)</th><th class="num">Lotes</th><th>Último uso</th></tr></thead>
          <tbody>
            <tr v-for="o in orgs.organizaciones || []" :key="o.id">
              <td>{{ o.nombre }}</td><td>{{ o.plan || '—' }}</td>
              <td class="num">{{ num(o.pacientes) }}</td><td class="num">{{ num(o.usuarios) }}</td>
              <td class="num">{{ num(o.dispensas_30d) }}</td><td class="num">{{ num(o.lotes) }}</td>
              <td>{{ hace(o.ultimo_uso) }}</td>
            </tr>
          </tbody>
        </table>
        <details v-if="orgs.base?.tablas?.length" class="est__detalle">
          <summary>Las tablas más grandes de la base</summary>
          <ul><li v-for="t in orgs.base.tablas" :key="t.nombre"><span class="mono">{{ t.nombre }}</span> · {{ num(t.tamano_mb, 1) }} MB</li></ul>
        </details>
      </section>

      <!-- ── Monitoreo ─────────────────────────────────────────────────── -->
      <section class="est__sec">
        <h2 class="est__h2">Monitoreo</h2>
        <ul class="est__monit">
          <li>
            <span class="est__pill est__pill--sm" :class="monitoreo.sentry ? 'est__pill--ok' : 'est__pill--info'"><component :is="monitoreo.sentry ? CheckCircle2 : Info" :size="12" /> {{ monitoreo.sentry ? 'Prendido' : 'Apagado' }}</span>
            Sentry: tiempos de cada pantalla y errores de producción.
            <a v-if="monitoreo.sentry_url" :href="monitoreo.sentry_url" target="_blank" rel="noopener" class="est__link">Abrir <ExternalLink :size="12" /></a>
          </li>
          <li>
            <span class="est__pill est__pill--sm est__pill--info"><Info :size="12" /> Afuera</span>
            El aviso por mail si se cae la app lo manda el monitor externo (UptimeRobot), contra <span class="mono">/salud</span> y <span class="mono">/salud/backup</span>.
          </li>
        </ul>
      </section>
      </template>
    </template>
  </div>
</template>

<style scoped>
.est { display: flex; flex-direction: column; gap: 1.2rem; }
.est > * { margin-top: 0 !important; margin-bottom: 0 !important; }
.est__semaforo { display: flex; gap: 1.1rem; align-items: center; border-radius: 16px; padding: 1.1rem 1.4rem; border: 1.5px solid #86EFAC; background: #F0FDF4; flex-wrap: wrap; }
.est__semaforo--atencion { border-color: #FCD34D; background: #FFFBEB; }
.est__semaforo--mal { border-color: #FCA5A5; background: #FEF2F2; }
.est__luces { display: flex; flex-direction: column; gap: 5px; background: #1f2937; border-radius: 12px; padding: 8px 7px; }
.est__luces span { width: 15px; height: 15px; border-radius: 15px; background: #4b5563; }
.est__luces span:nth-child(1).is-on { background: #DC2626; box-shadow: 0 0 10px #DC2626; }
.est__luces span:nth-child(2).is-on { background: #F59E0B; box-shadow: 0 0 10px #F59E0B; }
.est__luces span:nth-child(3).is-on { background: #16A34A; box-shadow: 0 0 10px #16A34A; }
.est__semaforo-tit { font-size: 1.3rem; font-weight: 800; color: var(--c-slate-900); }
.est__semaforo-txt { font-size: .92rem; color: var(--c-slate-700); margin-top: .15rem; }
.est__preguntas { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: .9rem; }
@media (max-width: 760px) { .est__preguntas { grid-template-columns: 1fr; } }
.est__pregunta { background: #fff; border: 1px solid var(--c-slate-200); border-radius: 14px; padding: 1rem 1.15rem; display: flex; flex-direction: column; gap: .45rem; }
.est__pregunta--atencion { border-color: #FCD34D; }
.est__pregunta--mal { border-color: #FCA5A5; }
.est__pregunta-head { display: flex; align-items: center; gap: .6rem; }
.est__pregunta-tit { margin: 0; flex: 1; font-size: 1rem; font-weight: 700; color: var(--c-slate-900); }
.est__pregunta-frase { margin: 0; font-size: .9rem; color: var(--c-slate-700); line-height: 1.5; }
.est__pregunta-mas { margin: 0; font-size: .82rem; color: var(--c-slate-500); line-height: 1.5; }
.est__pregunta-mas b { color: var(--c-slate-700); }
.est__pregunta-parte { display: block; }
.est__tabla-lenta { margin-top: .8rem; border: 0; }
.est__lento { display: flex; align-items: center; gap: .6rem; min-width: 200px; }
.est__lento-barra { flex: 1; height: 8px; background: var(--c-slate-100); border-radius: 8px; }
.est__lento-barra > span { display: block; height: 8px; border-radius: 8px; }
.est__lento--ok { background: var(--c-leaf-500); }
.est__lento--atencion { background: #F59E0B; }
.est__lento--mal { background: #DC2626; }
.est__lento-n { font-weight: 700; min-width: 54px; text-align: right; }
.est__lento-n--mal { color: #991B1B; }
.est__lento-n--atencion { color: #92400E; }
.est__horas { margin-top: 1rem; }
.est__horas-tit { font-size: .82rem; font-weight: 600; color: var(--c-slate-700); margin-bottom: .4rem; }
.est__horas-barras { display: flex; align-items: flex-end; gap: 3px; height: 72px; border-bottom: 1px solid var(--c-slate-200); }
.est__horas-barras span { flex: 1; border-radius: 3px 3px 0 0; }
.est__hb--ok { background: var(--c-leaf-300); }
.est__hb--atencion { background: #F59E0B; }
.est__hb--mal { background: #DC2626; }
.est__detalle-btn { display: flex; justify-content: space-between; align-items: center; gap: 1rem; width: 100%; text-align: left; background: #fff; border: 1px solid var(--c-slate-200); border-radius: 14px; padding: .9rem 1.2rem; cursor: pointer; font-size: .92rem; color: var(--c-slate-900); }
.est__head { display: flex; align-items: flex-start; justify-content: space-between; gap: var(--sp-4); flex-wrap: wrap; margin-bottom: var(--sp-5); }
.est__title { display: flex; align-items: center; gap: var(--sp-2); font-size: var(--fs-20); font-weight: 700; color: var(--c-ink-900); margin: 0; }
.est__sub { margin: var(--sp-1) 0 0; font-size: var(--fs-14); color: var(--c-slate-500); }
.est__btn { display: inline-flex; align-items: center; gap: .4rem; background: #fff; border: 1.5px solid var(--c-ink-300); border-radius: var(--r-md); padding: 6px 14px; font-size: var(--fs-14); font-weight: 600; color: var(--c-leaf-700); cursor: pointer; }
.est__btn:disabled { opacity: .6; cursor: default; }
.est__girando { animation: est-giro 1s linear infinite; }
@keyframes est-giro { to { transform: rotate(360deg); } }
.est__cargando, .est__error { display: flex; align-items: center; gap: var(--sp-2); padding: var(--sp-8); justify-content: center; color: var(--c-slate-500); }
.est__error { color: var(--c-rust-600); }

/* La respuesta en una frase: lo primero que se ve. */
.est__hero { display: flex; align-items: center; gap: var(--sp-4); padding: var(--sp-5) var(--sp-6); border-radius: var(--r-xl); border: 1.5px solid; margin-bottom: var(--sp-6); }
.est__hero--ok       { background: var(--c-leaf-100); border-color: var(--c-leaf-300); color: var(--c-leaf-700); }
.est__hero--atencion { background: var(--c-amber-100); border-color: var(--c-amber-500); color: var(--c-gold-500); }
.est__hero--mal      { background: var(--c-rust-100); border-color: var(--c-rust-600); color: var(--c-rust-600); }
.est__frase { font-size: var(--fs-24); font-weight: 700; color: var(--c-ink-900); line-height: var(--lh-tight); }
.est__actualizado { font-size: var(--fs-13); color: var(--c-slate-500); margin-top: 2px; }

.est__sec { background: #fff; border: 1px solid var(--c-slate-200); border-radius: var(--r-xl); padding: var(--sp-5); margin-bottom: var(--sp-5); }
.est__sec-head { display: flex; align-items: baseline; justify-content: space-between; gap: var(--sp-3); flex-wrap: wrap; margin-bottom: var(--sp-3); }
.est__sec-head .est__h2 { margin: 0; }
.est__h2 { display: flex; align-items: center; gap: var(--sp-2); font-size: var(--fs-16); font-weight: 700; color: var(--c-ink-900); margin: 0 0 var(--sp-3); }
.est__marco { font-size: var(--fs-13); color: var(--c-slate-500); }
.est__marco strong { color: var(--c-ink-900); }

/* Pastillas de estado: SIEMPRE ícono + palabra. */
.est__pill { display: inline-flex; align-items: center; gap: 4px; padding: 3px 9px; border-radius: var(--r-pill); font-size: var(--fs-12); font-weight: 600; white-space: nowrap; }
.est__pill--sm { padding: 2px 7px; font-size: 11px; }
.est__pill--ok          { background: var(--c-leaf-100); color: var(--c-leaf-700); }
.est__pill--atencion    { background: var(--c-amber-100); color: var(--c-gold-500); }
.est__pill--mal         { background: var(--c-rust-100); color: var(--c-rust-600); }
.est__pill--info        { background: var(--c-sky-100); color: var(--c-sky-600); }
.est__pill--apagado, .est__pill--desconocido { background: var(--c-slate-100); color: var(--c-slate-500); }

.est__avisos { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: var(--sp-2); }
.est__aviso { display: flex; gap: var(--sp-3); align-items: flex-start; padding: var(--sp-3); border-radius: var(--r-lg); border: 1px solid var(--c-slate-200); }
.est__aviso--mal { border-color: var(--c-rust-600); background: var(--c-rust-100); }
.est__aviso--atencion { border-color: var(--c-amber-500); background: var(--c-amber-100); }
.est__aviso-txt { min-width: 0; }
.est__aviso-que { font-size: var(--fs-14); font-weight: 600; color: var(--c-ink-900); }
.est__aviso-hacer { font-size: var(--fs-13); color: var(--c-ink-700); margin-top: 2px; }

.est__vacio { display: flex; gap: var(--sp-2); align-items: flex-start; font-size: var(--fs-14); color: var(--c-slate-600); background: var(--c-slate-50); border: 1px dashed var(--c-slate-300); border-radius: var(--r-lg); padding: var(--sp-3) var(--sp-4); }
.est__vacio--atencion { background: var(--c-amber-100); border-color: var(--c-amber-500); color: var(--c-ink-900); }

.est__grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(320px, 1fr)); gap: var(--sp-4); }
.est__card { border: 1px solid var(--c-slate-200); border-radius: var(--r-lg); padding: var(--sp-4); display: flex; flex-direction: column; gap: var(--sp-2); min-width: 0; }
.est__card-top { display: flex; align-items: flex-start; gap: var(--sp-2); }
.est__card-ico { color: var(--c-leaf-600); margin-top: 2px; flex-shrink: 0; }
.est__card-tit { flex: 1; min-width: 0; }
.est__card-nombre { font-weight: 700; color: var(--c-ink-900); font-size: var(--fs-14); }
.est__card-render { font-size: var(--fs-12); color: var(--c-slate-500); font-family: var(--font-mono); overflow-wrap: anywhere; }
.est__card-que { margin: 0; font-size: var(--fs-13); color: var(--c-ink-700); }
.est__deploy { display: flex; gap: 6px; align-items: flex-start; font-size: var(--fs-12); color: var(--c-slate-600); overflow-wrap: anywhere; }
.est__recursos { display: grid; grid-template-columns: 1fr 1fr; gap: var(--sp-3); margin-top: var(--sp-1); }
.est__medida { min-width: 0; }
.est__medida-head { display: flex; justify-content: space-between; gap: var(--sp-1); font-size: var(--fs-12); color: var(--c-slate-600); flex-wrap: wrap; }
.est__medida-val { color: var(--c-ink-900); font-weight: 700; font-size: var(--fs-14); }
.est__medida-det { font-size: 11px; color: var(--c-slate-500); }
/* El estado va debajo del nombre y puede ocupar dos líneas: al costado, un texto largo aplastaba el título. */
.est__pill--card { align-self: flex-start; white-space: normal; line-height: 1.3; }
.est__barra { height: 6px; border-radius: var(--r-pill); background: var(--c-slate-100); overflow: hidden; margin: 4px 0 6px; }
.est__barra-uso { height: 100%; border-radius: var(--r-pill); }
.est__barra-uso--ok { background: var(--c-leaf-500); }
.est__barra-uso--atencion { background: var(--c-amber-500); }
.est__barra-uso--mal { background: var(--c-rust-600); }
/* Las últimas 24 horas, una barra por hora. Pasar el mouse dice el valor. */
.est__spark { display: flex; align-items: flex-end; gap: 2px; height: 34px; }
.est__spark--backup { height: 44px; max-width: 220px; }
.est__spark-b { flex: 1; min-width: 3px; background: var(--c-leaf-300); border-radius: 2px 2px 0 0; }
.est__spark-b:hover { background: var(--c-leaf-600); }
.est__spark-pie { display: flex; justify-content: space-between; font-size: 10px; color: var(--c-slate-400); margin-top: 2px; }
.est__link { display: inline-flex; align-items: center; gap: 3px; font-size: var(--fs-12); font-weight: 600; color: var(--c-leaf-700); text-decoration: none; margin-top: auto; }
.est__link:hover { text-decoration: underline; }

.est__otros { margin-top: var(--sp-4); }
.est__otros-btn { background: none; border: none; padding: 0; color: var(--c-leaf-700); font-weight: 600; font-size: var(--fs-13); cursor: pointer; }

.est__mini-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(230px, 1fr)); gap: var(--sp-3); }
.est__mini { display: flex; gap: var(--sp-2); align-items: flex-start; padding: var(--sp-3); border-radius: var(--r-lg); border: 1px solid var(--c-slate-200); border-left-width: 4px; }
.est__mini--ok { border-left-color: var(--c-leaf-500); }
.est__mini--atencion { border-left-color: var(--c-amber-500); }
.est__mini--mal { border-left-color: var(--c-rust-600); }
.est__mini-l { font-size: var(--fs-12); color: var(--c-slate-500); }
.est__mini-v { font-size: var(--fs-14); color: var(--c-ink-900); font-weight: 600; }

.est__backup { display: flex; gap: var(--sp-6); flex-wrap: wrap; }
.est__backup-col { display: flex; flex-direction: column; align-items: flex-start; gap: var(--sp-2); min-width: 0; }
.est__backup-col .est__spark { width: 220px; }
.est__backup-dato { display: flex; align-items: center; gap: 5px; font-size: var(--fs-13); color: var(--c-ink-700); }
.est__backup-dato--info { color: var(--c-sky-600); }
.est__ok-ico { color: var(--c-leaf-600); }
.est__mal-ico { color: var(--c-rust-600); }

.est__tabla { width: 100%; border-collapse: collapse; font-size: var(--fs-13); margin-top: var(--sp-2); }
.est__tabla th { text-align: left; padding: var(--sp-2); background: var(--c-slate-50); color: var(--c-slate-600); font-weight: 600; font-size: var(--fs-12); border-bottom: 1px solid var(--c-slate-200); }
.est__tabla td { padding: var(--sp-2); border-bottom: 1px solid var(--c-slate-100); color: var(--c-ink-900); }
.est__tabla .num { text-align: right; font-variant-numeric: tabular-nums; }
.mono { font-family: var(--font-mono); font-size: var(--fs-12); }
.est__detalle { margin-top: var(--sp-3); font-size: var(--fs-13); color: var(--c-ink-700); }
.est__detalle summary { cursor: pointer; color: var(--c-leaf-700); font-weight: 600; }
.est__monit { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: var(--sp-2); font-size: var(--fs-13); color: var(--c-ink-700); }
.est__monit li { display: flex; align-items: center; gap: var(--sp-2); flex-wrap: wrap; }

@media (max-width: 640px) {
  .est { padding: var(--sp-4); }
  .est__frase { font-size: var(--fs-18); }
  .est__recursos { grid-template-columns: 1fr; }
  .est__grid { grid-template-columns: 1fr; }
  /* Las tablas anchas se deslizan adentro de su caja, nunca empujan la página. */
  .est__sec { overflow-x: auto; }
}
</style>
