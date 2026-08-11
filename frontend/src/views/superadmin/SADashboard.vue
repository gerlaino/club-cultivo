<script setup>
// El panel de quien VENDE la plataforma.
//
// Antes esto era un recuento: cuántas plantas, cuántos lotes y cuántos pacientes sumando todos
// los clubes. Nada de eso le sirve al dueño del software —no es su cultivo— y tapaba lo único
// accionable. Ahora contesta tres preguntas, en orden: quién vence, quién necesita algo hoy y
// quién se está por ir. Los agregados se mudaron a Informes.
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import DsSpinner from '../../design-system/components/Spinner.vue'
import { getSuperAdminPulso } from '../../lib/api.js'
import { AlertTriangle, CalendarClock, MoonStar, Activity, Plus } from 'lucide-vue-next'

const router  = useRouter()
const pulso   = ref(null)
const cargando = ref(true)
const error   = ref(null)

const susc     = computed(() => pulso.value?.suscripciones || {})
const atencion = computed(() => pulso.value?.atencion || {})
const salud    = computed(() => pulso.value?.salud || {})

// Lo que hay que resolver hoy, junto y ordenado por cuánto duele.
//
// Antes cada fila decía sólo qué PASA ("Correo al paciente: falta cargar el SMTP") y había que
// deducir qué hacer con eso. Ahora cada una lleva su ACCIÓN en el botón: quien abre el panel a
// la mañana tiene que poder bajar la lista sin interpretar nada.
//
// El orden es por plata: primero lo que ya se está perdiendo (plan vencido, organización que
// entra y no puede trabajar), después lo que se paga y no funciona, y al final lo que avisa
// con tiempo.
const GRUPOS = [
  { clave: 'perdiendo', titulo: 'Se está perdiendo plata', tono: 'rojo' },
  { clave: 'roto',      titulo: 'Paga y no le funciona',   tono: 'ambar' },
  { clave: 'avisar',    titulo: 'Avisar con tiempo',       tono: 'azul' },
]

const pendientes = computed(() => {
  const p = []
  const add = (items, grupo, texto, accion) =>
    (items || []).forEach(c => p.push({ ...c, grupo, texto: texto(c), accion }))

  add(susc.value.vencidos, 'perdiendo',
    () => 'El plan venció y sigue operando', 'Cobrar y renovar')
  add(atencion.value.sin_suites, 'perdiendo',
    () => 'Sin ninguna suite: entra pero no puede trabajar', 'Asignar suite')
  add(atencion.value.suspendidos, 'perdiendo',
    () => 'Suspendida: es plata que no entra', 'Reactivar')

  add(atencion.value.modulos_a_medias, 'roto',
    c => `${c.modulo_label}: ${c.falta}`, 'Completar configuración')
  add(salud.value.iot_mudo, 'roto',
    c => c.ultima_lectura
      ? 'Paga IoT y sus sondas no reportan hace más de dos días'
      : 'Paga IoT y nunca reportó una lectura',
    'Revisar sensores')

  add(susc.value.vencen_7, 'avisar',
    c => `Vence el ${fecha(c.plan_activo_hasta)}`, 'Renovar')

  return p
})

// Se muestran sólo los grupos con algo adentro: un encabezado vacío es ruido.
const gruposConPendientes = computed(() =>
  GRUPOS.map(g => ({ ...g, items: pendientes.value.filter(p => p.grupo === g.clave) }))
        .filter(g => g.items.length)
)

const sinActividad = computed(() => pulso.value?.sin_actividad || [])
const adopcion     = computed(() => (pulso.value?.adopcion || []).filter(a => a.tienen > 0))
const sidekiq      = computed(() => salud.value.sidekiq || {})

function fecha(f) {
  if (!f) return '—'
  return new Date(f + 'T00:00:00').toLocaleDateString('es-AR', { day: '2-digit', month: 'short' })
}

function irAlClub(id) { router.push({ name: 'sa-club-detail', params: { id } }) }

onMounted(async () => {
  try {
    const { data } = await getSuperAdminPulso()
    pulso.value = data
  } catch {
    error.value = 'No se pudo cargar el panel.'
  } finally {
    cargando.value = false
  }
})
</script>

<template>
  <div class="sad">

    <div class="sad__head">
      <div>
        <h1 class="sad__title">Panel</h1>
        <p class="sad__sub" v-if="pulso">
          {{ pulso.totales.clubes_operando }}
          {{ pulso.totales.clubes_operando === 1 ? "organización" : "organizaciones" }} operando
        </p>
      </div>
      <button class="sad__btn-primary" @click="router.push({ name: 'sa-club-nuevo' })">
        <Plus :size="16" :stroke-width="2.5" /> Nueva organización
      </button>
    </div>

    <div v-if="cargando" class="sad__cargando"><DsSpinner :size="22" /><span>Cargando…</span></div>
    <div v-else-if="error" class="sad__error">{{ error }}</div>

    <template v-else-if="pulso">

      <!-- 1 · Lo que hay que hacer hoy. Va primero porque es lo único accionable. -->
      <section class="sad__section">
        <div class="sad__section-head">
          <AlertTriangle :size="15" :stroke-width="2" />
          <span class="sad__section-title">Necesita que hagas algo</span>
          <span class="sad__section-count">{{ pendientes.length }}</span>
        </div>

        <div v-if="!pendientes.length" class="sad__vacio">
          Nada pendiente. Ningún plan vencido, ningún módulo prendido a medias.
        </div>
        <template v-else>
          <div v-for="g in gruposConPendientes" :key="g.clave" class="sad__grupo">
            <div class="sad__grupo-title" :class="`sad__grupo-title--${g.tono}`">
              {{ g.titulo }} <span class="sad__grupo-n">{{ g.items.length }}</span>
            </div>
            <ul class="sad__pend-list">
              <li
                v-for="(p, i) in g.items" :key="`${p.id}-${p.modulo || i}`"
                class="sad__pend" :class="`sad__pend--${g.tono}`"
                @click="irAlClub(p.id)"
              >
                <span class="sad__pend-club">{{ p.nombre }}</span>
                <span class="sad__pend-txt">{{ p.texto }}</span>
                <span v-if="p.trial" class="sad__chip">trial</span>
                <!-- La acción, no sólo el síntoma: se baja la lista sin interpretar nada. -->
                <span class="sad__pend-accion">{{ p.accion }} →</span>
              </li>
            </ul>
          </div>
        </template>
      </section>

      <div class="sad__cols">

        <!-- 2 · Vencimientos -->
        <section class="sad__section">
          <div class="sad__section-head">
            <CalendarClock :size="15" :stroke-width="2" />
            <span class="sad__section-title">Vencimientos</span>
          </div>
          <div class="sad__mini-grid">
            <div class="sad__mini sad__mini--rojo">
              <span class="sad__mini-n">{{ (susc.vencidos || []).length }}</span>
              <span class="sad__mini-l">vencidos</span>
            </div>
            <div class="sad__mini sad__mini--ambar">
              <span class="sad__mini-n">{{ (susc.vencen_7 || []).length }}</span>
              <span class="sad__mini-l">esta semana</span>
            </div>
            <div class="sad__mini">
              <span class="sad__mini-n">{{ (susc.vencen_30 || []).length }}</span>
              <span class="sad__mini-l">este mes</span>
            </div>
            <div class="sad__mini">
              <span class="sad__mini-n">{{ (susc.trials || []).length }}</span>
              <span class="sad__mini-l">en prueba</span>
            </div>
          </div>
          <p class="sad__pie">
            {{ susc.sin_vencimiento }} sin fecha de vencimiento ·
            <template v-for="(n, plan) in (susc.por_plan || {})" :key="plan">{{ n }} {{ plan }} </template>
          </p>
        </section>

        <!-- 3 · Quién se está por ir -->
        <section class="sad__section">
          <div class="sad__section-head">
            <MoonStar :size="15" :stroke-width="2" />
            <span class="sad__section-title">En silencio</span>
            <span class="sad__section-count">{{ sinActividad.length }}</span>
          </div>
          <div v-if="!sinActividad.length" class="sad__vacio">Todas las organizaciones tocaron algo hace poco.</div>
          <ul v-else class="sad__silencio">
            <li v-for="c in sinActividad" :key="c.id" @click="irAlClub(c.id)">
              <span class="sad__pend-club">{{ c.nombre }}</span>
              <span class="sad__pend-txt">
                <template v-if="c.dias_en_silencio">hace {{ c.dias_en_silencio }} días</template>
                <template v-else>nunca registró actividad</template>
              </span>
            </li>
          </ul>
          <p class="sad__pie">Sin dispensaciones ni lotes nuevos en las últimas tres semanas.</p>
        </section>

      </div>

      <!-- 4 · Salud de la plataforma -->
      <section class="sad__section">
        <div class="sad__section-head">
          <Activity :size="15" :stroke-width="2" />
          <span class="sad__section-title">Salud</span>
        </div>
        <div class="sad__salud">
          <div class="sad__salud-item" :class="{ 'sad__salud-item--mal': !sidekiq.disponible }">
            <span class="sad__salud-l">Trabajos en segundo plano</span>
            <span v-if="sidekiq.disponible" class="sad__salud-v">
              {{ sidekiq.workers }} worker{{ sidekiq.workers === 1 ? '' : 's' }} ·
              {{ sidekiq.encolados }} en cola · {{ sidekiq.muertos }} muertos
            </span>
            <span v-else class="sad__salud-v">Sin respuesta de la cola</span>
          </div>
          <!-- El IoT mudo NO va acá: ya está arriba, en la cola, con la organización y el botón
               para resolverlo. Repetirlo como "3 sin señal" agregaba un número que no lleva a
               ningún lado y hacía parecer que eran dos problemas distintos. -->
        </div>
      </section>

      <!-- 5 · Adopción: la diferencia entre tener y usar es el trabajo pendiente -->
      <section v-if="adopcion.length" class="sad__section">
        <div class="sad__section-head">
          <span class="sad__section-title">Qué se usa</span>
          <span class="sad__section-sub">contratado · andando</span>
        </div>
        <div class="sad__adopcion">
          <div v-for="a in adopcion" :key="a.clave" class="sad__adop">
            <span class="sad__adop-l">{{ a.label }}</span>
            <span class="sad__adop-v" :class="{ 'sad__adop-v--gap': a.andando < a.tienen }">
              {{ a.tienen }} · {{ a.andando }}
            </span>
          </div>
        </div>
      </section>

    </template>
  </div>
</template>

<style scoped>
/* El ancho y el centrado los pone `.sa-main` del shell, para todas las pantallas por igual. */
.sad { padding: 1.75rem 2rem 3rem; }

.sad__head { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; margin-bottom: 1.5rem; }
.sad__title { font-size: 1.6rem; font-weight: 800; color: var(--c-slate-900); margin: 0; letter-spacing: -.03em; }
.sad__sub { font-size: .82rem; color: var(--c-slate-500); margin: .2rem 0 0; }
.sad__btn-primary {
  display: inline-flex; align-items: center; gap: .4rem; flex-shrink: 0;
  padding: .55rem .95rem; border: none; border-radius: 9px;
  background: var(--c-role-superadmin); color: #fff;
  font-size: .82rem; font-weight: 700; cursor: pointer; transition: opacity .15s;
}
.sad__btn-primary:hover { opacity: .88; }

.sad__cargando { display: flex; align-items: center; justify-content: center; gap: .75rem; padding: 4rem 0; color: var(--c-slate-500); font-size: .85rem; }
.sad__error { padding: 1rem; border-radius: 10px; background: #fef2f2; color: #b91c1c; font-size: .85rem; }

.sad__cols { display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; }
@media (max-width: 900px) { .sad__cols { grid-template-columns: 1fr; } }

.sad__section {
  background: #fff; border: 1px solid var(--c-slate-200); border-radius: 14px;
  padding: 1rem 1.125rem 1.125rem; margin-bottom: 1rem;
}
.sad__section-head { display: flex; align-items: center; gap: .45rem; margin-bottom: .875rem; color: var(--c-slate-500); }
.sad__section-title { font-size: .74rem; font-weight: 800; text-transform: uppercase; letter-spacing: .07em; }
.sad__section-sub { font-size: .68rem; color: var(--c-slate-400); margin-left: auto; }
.sad__section-count {
  font-size: .68rem; font-weight: 800; color: var(--c-slate-600);
  background: var(--c-slate-100); border-radius: 20px; padding: .1rem .45rem;
}

.sad__vacio { font-size: .82rem; color: var(--c-slate-500); padding: .5rem 0; }
.sad__pie { font-size: .7rem; color: var(--c-slate-400); margin: .75rem 0 0; }

/* Pendientes — una fila por cosa que hacer, con el club adelante */
.sad__pend-list, .sad__silencio { list-style: none; margin: 0; padding: 0; display: grid; gap: .3rem; }
.sad__pend, .sad__silencio li {
  display: flex; align-items: baseline; gap: .55rem; flex-wrap: wrap;
  padding: .55rem .7rem; border-radius: 9px; cursor: pointer;
  border-left: 3px solid var(--c-slate-200); background: var(--c-slate-50);
  transition: background .12s;
}
.sad__pend:hover, .sad__silencio li:hover { background: var(--c-slate-100); }
.sad__pend--rojo  { border-left-color: #dc2626; background: #fef2f2; }
.sad__pend--ambar { border-left-color: #f59e0b; background: #fffbeb; }
.sad__pend--azul  { border-left-color: #0284c7; background: #f0f9ff; }
.sad__pend--gris  { border-left-color: var(--c-slate-400); }
.sad__pend-club { font-size: .82rem; font-weight: 700; color: var(--c-slate-900); }
.sad__pend-txt  { font-size: .76rem; color: var(--c-slate-600); }

/* Encabezado por urgencia: dice POR QUÉ el bloque está donde está. Sin esto, el color de la
   franja era la única pista y había que saber qué significaba cada uno. */
.sad__grupo { margin-bottom: .9rem; }
.sad__grupo:last-child { margin-bottom: 0; }
.sad__grupo-title {
  display: flex; align-items: center; gap: .4rem;
  font-size: .68rem; font-weight: 800; text-transform: uppercase; letter-spacing: .07em;
  margin-bottom: .4rem; color: var(--c-slate-500);
}
.sad__grupo-title--rojo  { color: #b91c1c; }
.sad__grupo-title--ambar { color: #b45309; }
.sad__grupo-title--azul  { color: #0369a1; }
.sad__grupo-n {
  font-weight: 700; font-size: .66rem; color: var(--c-slate-500);
  background: var(--c-slate-100); border-radius: 20px; padding: .05rem .4rem;
}

/* La acción, alineada a la derecha: se lee la columna entera de un barrido. */
.sad__pend-accion {
  margin-left: auto; font-size: .72rem; font-weight: 700; color: var(--c-slate-700);
  white-space: nowrap;
}
.sad__pend:hover .sad__pend-accion { color: var(--c-slate-900); }
.sad__chip {
  font-size: .62rem; font-weight: 800; text-transform: uppercase; letter-spacing: .05em;
  background: var(--c-slate-200); color: var(--c-slate-600); border-radius: 5px; padding: .1rem .35rem;
}

/* Vencimientos */
.sad__mini-grid { display: grid; grid-template-columns: repeat(4, 1fr); gap: .5rem; }
.sad__mini {
  display: grid; gap: .1rem; padding: .65rem .5rem; text-align: center;
  border: 1px solid var(--c-slate-100); border-radius: 10px;
}
.sad__mini--rojo  { border-color: #fecaca; background: #fef2f2; }
.sad__mini--ambar { border-color: #fde68a; background: #fffbeb; }
.sad__mini-n { font-size: 1.3rem; font-weight: 800; color: var(--c-slate-900); line-height: 1; }
.sad__mini-l { font-size: .66rem; color: var(--c-slate-500); }

/* Salud */
.sad__salud { display: grid; grid-template-columns: repeat(auto-fit, minmax(260px, 1fr)); gap: .5rem; }
.sad__salud-item {
  display: grid; gap: .2rem; padding: .7rem .85rem;
  border: 1px solid var(--c-slate-100); border-radius: 10px; background: var(--c-slate-50);
}
.sad__salud-item--mal { border-color: #fde68a; background: #fffbeb; }
.sad__salud-l { font-size: .72rem; font-weight: 700; color: var(--c-slate-600); }
.sad__salud-v { font-size: .78rem; color: var(--c-slate-500); }

/* Adopción */
.sad__adopcion { display: grid; grid-template-columns: repeat(auto-fill, minmax(200px, 1fr)); gap: .4rem; }
.sad__adop {
  display: flex; align-items: baseline; justify-content: space-between; gap: .5rem;
  padding: .55rem .75rem; border: 1px solid var(--c-slate-100); border-radius: 9px;
}
.sad__adop-l { font-size: .76rem; color: var(--c-slate-600); }
.sad__adop-v { font-size: .8rem; font-weight: 800; color: var(--c-slate-900); }
/* Contratado pero sin andar: la diferencia es el trabajo pendiente. */
.sad__adop-v--gap { color: #b45309; }
</style>
