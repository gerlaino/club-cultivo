<template>
  <div class="pms">
    <PortalCabecera titulo="Mi salud" bajada="Tus turnos y lo que te indicó tu médico." />

    <div v-if="cargando" class="pms__cargando"><DsSpinner :size="32" /></div>

    <template v-else>
      <PortalVacio v-if="!datos?.tiene_modulo"
                   titulo="Tu organización no tiene el módulo médico"
                   texto="Cuando lo active vas a ver acá tus turnos y tus indicaciones." />

      <template v-else>
        <!-- ── Indicación vigente ──────────────────────────────────────────
             Va primera: es lo que consulta cuando no se acuerda cuánto tomar. -->
        <section class="pms__sec">
          <h2 class="pms__sec-t">Mi indicación</h2>

          <article v-if="i" class="pms__ind" :class="{ 'pms__ind--vencida': i.vencida }">
            <p class="pms__dosis">{{ i.dosificacion }}</p>

            <dl class="pms__datos">
              <div class="pms__dato">
                <dt>Vía</dt>
                <dd>{{ VIAS[i.via_administracion] || i.via_administracion }}</dd>
              </div>
              <div class="pms__dato">
                <dt>Indicada para</dt>
                <dd>{{ i.patologia }}</dd>
              </div>
              <div class="pms__dato">
                <dt>Emitida</dt>
                <dd>{{ fecha(i.fecha_emision) }}<template v-if="i.medico"> · {{ i.medico }}</template></dd>
              </div>
              <div v-if="i.fecha_vencimiento" class="pms__dato">
                <dt>Vigencia</dt>
                <dd>{{ vigencia }}</dd>
              </div>
            </dl>

            <p v-if="i.observaciones" class="pms__obs">{{ i.observaciones }}</p>

            <p v-if="i.vencida || i.por_vencer" class="pms__nota" :class="{ 'pms__nota--urgente': i.vencida }">
              {{ i.vencida
                 ? 'Tu indicación venció. Pedí un turno para renovarla.'
                 : 'Tu indicación está por vencer. Sacá turno con tiempo.' }}
            </p>
          </article>

          <PortalVacio v-else
                       titulo="Todavía no tenés una indicación cargada"
                       texto="Cuando tu médico te la cargue, la vas a ver acá con la dosis y la vía." />
        </section>

        <!-- ── Turnos ─────────────────────────────────────────────────── -->
        <section class="pms__sec">
          <h2 class="pms__sec-t">Mis turnos</h2>

          <ul v-if="turnos.length" class="pms__turnos">
            <li v-for="t in turnos" :key="t.id" class="pms__turno">
              <span class="pms__cal">
                <span class="pms__cal-m">{{ mes(t.fecha_hora) }}</span>
                <span class="pms__cal-d">{{ dia(t.fecha_hora) }}</span>
              </span>
              <span class="pms__turno-c">
                <span class="pms__turno-h">{{ diaYhora(t.fecha_hora) }}</span>
                <span class="pms__turno-m">
                  {{ t.tipo_label }}<template v-if="t.medico"> · {{ t.medico }}</template>
                </span>
                <span v-if="t.motivo" class="pms__turno-mo">{{ t.motivo }}</span>
              </span>
              <span class="pms__chip" :class="`pms__chip--${t.estado}`">{{ ESTADOS[t.estado] || t.estado }}</span>
            </li>
          </ul>

          <PortalVacio v-else
                       titulo="No tenés turnos agendados"
                       texto="Cuando tu organización te agende uno, lo vas a ver acá." />
        </section>

        <!-- Lo único que el portal NO puede hacer, dicho una vez y sin vueltas. Sacar turno pide
             disponibilidad del médico y confirmación, y eso todavía se maneja adentro. -->
        <p class="pms__pie">
          Los turnos los agenda tu organización. Si necesitás uno, escribile o llamala.
        </p>
      </template>
    </template>
  </div>
</template>

<script setup>
// Lo clínico del paciente, visto por él: su indicación y sus turnos.
//
// El módulo médico existe desde hace meses y el portal no lo leía: el paciente tenía que llamar
// para saber cuándo era su turno o cuánto le habían indicado tomar. Es justamente lo que separa
// "el catálogo de mi club" de un portal de salud.
//
// La indicación va ARRIBA de los turnos aunque el turno tenga hora: la indicación se consulta
// muchas veces (cuánto tomo, por qué vía) y el turno una.
import { ref, computed, onMounted } from 'vue'
import { getPortalMiSalud } from '@/lib/portalApi'
import PortalCabecera from '@/components/portal/PortalCabecera.vue'
import PortalVacio from '@/components/portal/PortalVacio.vue'
import DsSpinner from '@/design-system/components/Spinner.vue'

const datos    = ref(null)
const cargando = ref(true)

const i      = computed(() => datos.value?.indicacion || null)
const turnos = computed(() => datos.value?.turnos || [])

const VIAS = {
  oral: 'Oral', sublingual: 'Sublingual', inhalada: 'Inhalada',
  topica: 'Tópica', vaporizacion: 'Vaporización',
}
const ESTADOS = {
  programado: 'Programado', confirmado: 'Confirmado',
  realizado: 'Realizado', cancelado: 'Cancelado', ausente: 'Ausente',
}
const MESES = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic']

const d = (f) => new Date(f)
const fecha    = (f) => (f ? d(f).toLocaleDateString('es-AR', { day: 'numeric', month: 'long', year: 'numeric' }) : '')
const mes      = (f) => (f ? MESES[d(f).getMonth()] : '')
const dia      = (f) => (f ? d(f).getDate() : '')
const diaYhora = (f) => (f ? d(f).toLocaleString('es-AR', { weekday: 'long', hour: '2-digit', minute: '2-digit' }) : '')

const vigencia = computed(() => {
  if (!i.value?.fecha_vencimiento) return ''
  const dias = i.value.dias_hasta_vencimiento
  if (i.value.vencida) return `Venció el ${fecha(i.value.fecha_vencimiento)}`
  return `Hasta el ${fecha(i.value.fecha_vencimiento)}${dias != null ? ` · ${dias} ${dias === 1 ? 'día' : 'días'}` : ''}`
})

onMounted(async () => {
  try { datos.value = await getPortalMiSalud() } catch { datos.value = null }
  cargando.value = false
})
</script>

<style scoped>
.pms { max-width: var(--p-ancho); margin: 0 auto; padding: var(--sp-6) var(--sp-4) var(--sp-12); }
.pms__cargando { display: flex; justify-content: center; padding: var(--sp-12); }

.pms__sec { margin-bottom: var(--sp-10); }
.pms__sec-t {
  font-family: var(--p-display);
  font-size: var(--fs-18); font-weight: 600; margin: 0 0 var(--sp-3); letter-spacing: -.01em;
  border-bottom: 1px solid var(--p-linea); padding-bottom: var(--sp-2);
}

/* ── Indicación ── */
.pms__ind {
  background: var(--p-papel); border: 1px solid var(--p-linea);
  border-left: 3px solid var(--p-marca);
  border-radius: var(--p-radio-sm); padding: var(--sp-5);
}
.pms__ind--vencida { border-left-color: var(--p-urgente); }

/* La dosis en grande: es LA línea que vino a buscar. */
.pms__dosis {
  font-family: var(--p-display);
  font-size: var(--fs-20); font-weight: 600; line-height: var(--lh-tight);
  margin: 0 0 var(--sp-4); letter-spacing: -.01em; text-wrap: balance;
}

.pms__datos { display: grid; gap: var(--sp-3); margin: 0; }
.pms__dato { display: flex; flex-direction: column; }
.pms__dato dt {
  font-size: var(--fs-12); text-transform: uppercase; letter-spacing: .08em; color: var(--p-tenue);
}
.pms__dato dd { margin: 0; font-weight: 500; line-height: var(--lh-base); }

.pms__obs {
  margin: var(--sp-4) 0 0; padding-top: var(--sp-4);
  border-top: 1px solid var(--p-linea);
  color: var(--p-suave); line-height: var(--lh-base); white-space: pre-line;
}

.pms__nota {
  margin: var(--sp-4) 0 0; padding: var(--sp-3);
  background: var(--p-atencion-bg); border-radius: var(--p-radio-sm);
  font-size: var(--fs-13); font-weight: 500;
  color: color-mix(in srgb, var(--p-atencion) 80%, #000 20%);
}
.pms__nota--urgente {
  background: var(--p-urgente-bg);
  color: color-mix(in srgb, var(--p-urgente) 75%, #000 25%);
}

/* ── Turnos ── */
.pms__turnos { list-style: none; margin: 0; padding: 0; }
.pms__turno {
  display: flex; align-items: center; gap: var(--sp-4);
  padding: var(--sp-3) 0; border-bottom: 1px dotted var(--p-linea);
}
.pms__turnos li:last-child { border-bottom: 0; }

.pms__cal {
  width: 46px; flex: 0 0 auto; text-align: center;
  background: var(--p-marca-suave); color: var(--p-marca-fuerte);
  border-radius: var(--p-radio-sm); padding: var(--sp-1) 0;
}
.pms__cal-m { display: block; font-size: 10px; text-transform: uppercase; letter-spacing: .08em; font-weight: 700; }
.pms__cal-d { display: block; font-family: var(--p-display); font-size: var(--fs-20); font-weight: 600; line-height: 1.1; }

.pms__turno-c { display: flex; flex-direction: column; min-width: 0; flex: 1; }
.pms__turno-h { font-weight: 600; }
.pms__turno-h::first-letter { text-transform: uppercase; }
.pms__turno-m { font-size: var(--fs-13); color: var(--p-suave); }
.pms__turno-mo { font-size: var(--fs-13); color: var(--p-tenue); }

.pms__chip {
  flex: 0 0 auto; font-size: var(--fs-12); font-weight: 600;
  padding: 2px var(--sp-3); border-radius: var(--r-pill);
  background: var(--p-hundido); color: var(--p-suave);
}
.pms__chip--confirmado { background: var(--p-marca-suave); color: var(--p-marca-fuerte); }
.pms__chip--cancelado,
.pms__chip--ausente { background: var(--p-urgente-bg); color: var(--p-urgente); }

.pms__pie { font-size: var(--fs-13); color: var(--p-tenue); line-height: var(--lh-base); margin: 0; }

@media (min-width: 640px) {
  .pms { padding: var(--sp-10) var(--sp-4) var(--sp-12); }
  .pms__datos { grid-template-columns: 1fr 1fr; gap: var(--sp-4); }
}
</style>
