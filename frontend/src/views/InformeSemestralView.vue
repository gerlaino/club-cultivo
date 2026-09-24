<script setup>
// LA DECLARACIÓN JURADA SEMESTRAL: el documento que se presenta ante REPROCANN.
//
// La pantalla lee el mismo hash que el PDF (`Informes::Semestral`, que compone REPROCANN,
// Producción, Dispensaciones e INASE con el semestre como período). Era un diseño aparte de los
// otros seis informes, con colores a mano, una tabla lote por lote con una columna siempre vacía,
// «por vencer» calculado desde hoy en el informe de cualquier semestre y los aportes en pesos en
// una declaración sanitaria. Ahora es el mismo esqueleto `inf__` que el resto, con lo único suyo:
// el selector de semestre.
import { ref, computed, onMounted } from 'vue'
import { FileSignature } from 'lucide-vue-next'
import { getInformeSemestral } from '../lib/api'
import { descargarArchivo } from '../lib/descargas.js'
import { useToast } from '../composables/useToast.js'
import { semestreActual, formatFechaCorta, formatFechaLarga } from '../utils/dates.js'

const toast   = useToast()
const informe = ref(null)
const loading = ref(false)
const error   = ref(null)

const { year: anioActual, semestre: semActual } = semestreActual()
const anio     = ref(anioActual)
const semestre = ref(semActual)
const anios    = computed(() => Array.from({ length: 4 }, (_, i) => anioActual - i))

async function cargar() {
  loading.value = true
  error.value   = null
  try {
    const { data } = await getInformeSemestral({ anio: anio.value, semestre: semestre.value })
    informe.value = data
  } catch (e) {
    error.value = e?.response?.data?.error || 'No se pudo generar la declaración'
  } finally {
    loading.value = false
  }
}

const generando = ref(false)
// `paraPresentar`: éste es EL documento que va ante la autoridad, y sólo en ese caso se valida que
// lo que aparece esté vinculado al INASE. Para mirar la realidad sale siempre, con la salvedad.
async function descargar(formato = 'pdf', paraPresentar = false) {
  generando.value = true
  try {
    const slug = (informe.value?.club?.nombre_legal || informe.value?.club?.nombre || 'organizacion').replace(/\s+/g, '_')
    await descargarArchivo(`/informe_semestral.${formato}`, {
      params: { anio: anio.value, semestre: semestre.value, para_presentar: paraPresentar ? 1 : undefined },
      filename: `declaracion_semestral_${semestre.value}S_${anio.value}_${slug}.${formato}`,
    })
  } catch (e) {
    toast.error(e.message, { timeout: e.conMotivo ? 9000 : 5000 })
  } finally {
    generando.value = false
  }
}

const ESTADO = { vigente: 'Vigente', por_vencer: 'Vigente', vencido: 'Vencido', pendiente: 'Pendiente de aprobación', sin_reprocann: 'Sin número' }
const estadoLabel = (e) => ESTADO[e] || e
const estadoClase = (e) => ({ vigente: 'ok', por_vencer: 'ok', vencido: 'bad', pendiente: 'warn', sin_reprocann: 'warn' }[e] || '')
const fmtG = (g) => `${Number(g || 0).toLocaleString('es-AR', { maximumFractionDigits: 1 })} g`
const UNIDAD = { g: 'Gramos', un: 'Unidades', ml: 'Mililitros' }
const cantidad = (u) => `${Number(u.cantidad).toLocaleString('es-AR', { maximumFractionDigits: 2 })}${u.unidad === 'un' ? '' : ` ${u.unidad}`}`
const alCierre = computed(() => informe.value?.periodo?.cerrado
  ? `al ${formatFechaCorta(informe.value.periodo.al)}`
  : `a hoy (semestre en curso)`)

onMounted(cargar)
</script>

<template>
  <div class="inf">
    <div class="inf__header">
      <h1 class="inf__title"><FileSignature :size="20" :stroke-width="1.75" /> Declaración jurada semestral</h1>
      <div class="inf__head-actions">
        <select class="inf__select" v-model.number="semestre" @change="cargar">
          <option :value="1">1° semestre — ene / jun</option>
          <option :value="2">2° semestre — jul / dic</option>
        </select>
        <select class="inf__select" v-model.number="anio" @change="cargar">
          <option v-for="y in anios" :key="y" :value="y">{{ y }}</option>
        </select>
        <button class="inf__pdf" :disabled="!informe || generando" @click="descargar('pdf')">
          <i class="bi bi-filetype-pdf"></i> {{ generando ? 'Generando…' : 'PDF' }}
        </button>
        <button class="inf__pdf" :disabled="!informe || generando"
                title="Valida que todas las variedades de la declaración estén vinculadas al INASE"
                @click="descargar('pdf', true)">
          <i class="bi bi-patch-check"></i> Para presentar
        </button>
        <button class="inf__pdf" :disabled="!informe || generando" @click="descargar('xlsx')">
          <i class="bi bi-file-earmark-spreadsheet"></i> Excel
        </button>
      </div>
    </div>

    <div v-if="loading" class="inf__loading">Cargando…</div>
    <div v-else-if="error" class="inf__error">{{ error }}</div>

    <div v-else-if="informe" class="inf__hoja">
      <p class="inf__resena">
        Lo que la organización presenta ante REPROCANN por el {{ informe.periodo.semestre }}° semestre {{ informe.periodo.anio }}
        ({{ formatFechaLarga(informe.periodo.desde) }} al {{ formatFechaLarga(informe.periodo.hasta) }}):
        la población registrada {{ alCierre }} con su vigencia ese día, lo cosechado en el semestre por variedad
        acreditada ante el INASE y las entregas a esa población. Sale de los mismos cálculos que los informes
        REPROCANN, Producción, Dispensaciones e INASE.
      </p>

      <!-- Mismo aviso que el INASE, sobre lo que aparece en ESTE documento. -->
      <div v-if="informe.sin_vincular?.length" class="inf__aviso">
        <strong>{{ informe.sin_vincular.length === 1 ? '1 genética sale' : `${informe.sin_vincular.length} genéticas salen` }}
          en la declaración sin vinculación con el INASE:</strong>
        {{ informe.sin_vincular.map(g => g.nombre).join(', ') }}.
        El PDF sale con la salvedad impresa; «Para presentar» no sale hasta declararlas.
        <RouterLink :to="`/geneticas?edit=${informe.sin_vincular[0].id}`" class="inf__aviso-link">Declararlas →</RouterLink>
      </div>

      <!-- ── Establecimiento ─────────────────────────────────────────────── -->
      <section class="inf__section">
        <div class="inf__section-head"><h2 class="inf__section-title">Establecimiento</h2></div>
        <dl class="inf__fields">
          <div><dt>Denominación</dt><dd>{{ informe.club.nombre_legal || informe.club.nombre }}</dd></div>
          <div v-if="informe.club.direccion"><dt>Domicilio</dt><dd>{{ [informe.club.direccion, informe.club.ciudad, informe.club.provincia].filter(Boolean).join(', ') }}</dd></div>
          <div v-if="informe.club.email || informe.club.telefono"><dt>Contacto</dt><dd>{{ [informe.club.email, informe.club.telefono].filter(Boolean).join(' · ') }}</dd></div>
          <div>
            <dt>Resol. REPROCANN</dt>
            <dd v-if="informe.club.numero_resolucion_reprocann">N.º {{ informe.club.numero_resolucion_reprocann }}</dd>
            <dd v-else class="inf__falta">sin cargar · <RouterLink to="/configuracion" class="inf__aviso-link">Configuración</RouterLink></dd>
          </div>
          <div v-if="informe.club.sedes_reprocann?.length">
            <dt>Sedes declaradas</dt>
            <dd>{{ informe.club.sedes_reprocann.map(s => `${s.nombre} (${s.tipo})`).join(' · ') }}</dd>
          </div>
        </dl>
      </section>

      <!-- ── Pacientes ───────────────────────────────────────────────────── -->
      <section class="inf__section">
        <div class="inf__section-head">
          <h2 class="inf__section-title">Pacientes registrados en REPROCANN</h2>
          <span class="inf__section-marco">{{ alCierre }} · la misma población que el informe REPROCANN</span>
        </div>
        <div class="inf__kpis">
          <div class="inf__kpi"><span class="inf__kpi-valor">{{ informe.pacientes.registrados }}</span><span class="inf__kpi-label">Registrados</span></div>
          <div class="inf__kpi inf__kpi--ok"><span class="inf__kpi-valor">{{ informe.pacientes.vigentes }}</span><span class="inf__kpi-label">Vigentes al cierre</span></div>
          <div class="inf__kpi" :class="{ 'inf__kpi--bad': informe.pacientes.vencidos > 0 }"><span class="inf__kpi-valor">{{ informe.pacientes.vencidos }}</span><span class="inf__kpi-label">Vencidos al cierre</span></div>
          <div class="inf__kpi"><span class="inf__kpi-valor">{{ informe.pacientes.en_tramite }}</span><span class="inf__kpi-label">Pendientes de aprobación</span></div>
          <div class="inf__kpi"><span class="inf__kpi-valor">{{ informe.pacientes.sin_registro }}</span><span class="inf__kpi-label">Sin registro<br><small>no se presentan; se informa el número</small></span></div>
        </div>

        <table v-if="informe.pacientes.nomina.length" class="inf__table">
          <thead>
            <tr><th>Paciente</th><th>DNI</th><th>N° REPROCANN</th><th>Vence</th><th>Estado al cierre</th></tr>
          </thead>
          <tbody>
            <tr v-for="p in informe.pacientes.nomina" :key="p.paciente_id">
              <td>{{ p.nombre_completo }}</td>
              <!-- Tres dígitos en pantalla; el archivo lleva el documento entero. -->
              <td class="mono">···{{ p.dni_ultimos_3 }}</td>
              <td class="mono">{{ p.reprocann_numero || '—' }}</td>
              <td>{{ p.reprocann_vencimiento ? formatFechaCorta(p.reprocann_vencimiento) : '—' }}</td>
              <td><span class="inf__estado" :class="`inf__estado--${estadoClase(p.reprocann_estado)}`">{{ estadoLabel(p.reprocann_estado) }}</span></td>
            </tr>
          </tbody>
        </table>
        <p v-else class="inf__nota">La organización no tenía pacientes registrados al cierre del período.</p>
        <p v-if="informe.pacientes.nomina_omitidos" class="inf__nota">
          … y {{ informe.pacientes.nomina_omitidos }} más. El PDF y el Excel llevan la nómina completa.
        </p>
      </section>

      <!-- ── Cultivo ─────────────────────────────────────────────────────── -->
      <section class="inf__section">
        <div class="inf__section-head">
          <h2 class="inf__section-title">Cultivo del semestre</h2>
          <span class="inf__section-marco">cosechado entre el {{ formatFechaCorta(informe.periodo.desde) }} y el {{ formatFechaCorta(informe.periodo.hasta) }} · en pie {{ alCierre }}</span>
        </div>
        <div class="inf__kpis">
          <div class="inf__kpi"><span class="inf__kpi-valor">{{ informe.cultivo.cosechados.lotes }}</span><span class="inf__kpi-label">Lotes cosechados</span></div>
          <div class="inf__kpi"><span class="inf__kpi-valor">{{ informe.cultivo.cosechados.plantas }}</span><span class="inf__kpi-label">Plantas cosechadas</span></div>
          <div class="inf__kpi inf__kpi--ok"><span class="inf__kpi-valor">{{ fmtG(informe.cultivo.cosechados.gramos) }}</span><span class="inf__kpi-label">Flor seca<small v-if="informe.cultivo.cosechados.gramos_por_planta"><br>{{ informe.cultivo.cosechados.gramos_por_planta }} g por planta</small></span></div>
          <div class="inf__kpi"><span class="inf__kpi-valor">{{ informe.cultivo.en_pie.plantas }}</span><span class="inf__kpi-label">Plantas en pie {{ alCierre }}<br><small>{{ informe.cultivo.en_pie.lotes }} lotes</small></span></div>
        </div>

        <table v-if="informe.cultivo.variedades.length" class="inf__table">
          <thead>
            <tr>
              <th>Variedad (Catálogo Nacional)</th><th>Obtentor</th>
              <th class="num">Lotes</th><th class="num">Plantas</th>
              <th class="num" title="De dónde vino el material de propagación de cada planta">Semilla / esqueje</th>
              <th class="num">Flor seca</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="v in informe.cultivo.variedades" :key="v.nombre">
              <td>
                <strong>{{ v.nombre }}</strong>
                <span v-if="!v.vinculada" class="inf__sin-vinculo">sin vinculación</span>
                <div v-if="v.acredita.length" class="inf__acredita">acredita: {{ v.acredita.join(', ') }}</div>
              </td>
              <td class="inf__obtentor">{{ v.criador || '—' }}</td>
              <td class="num">{{ v.lotes }}</td>
              <td class="num">{{ v.plantas }}</td>
              <td class="num">{{ v.origen.semilla }} / {{ v.origen.esqueje }}</td>
              <td class="num">{{ fmtG(v.gramos) }}</td>
            </tr>
          </tbody>
        </table>
        <p v-else class="inf__nota">No se cosechó ningún lote en el semestre.</p>
      </section>

      <!-- ── Entregas ────────────────────────────────────────────────────── -->
      <section class="inf__section">
        <div class="inf__section-head">
          <h2 class="inf__section-title">Entregas del semestre</h2>
          <span class="inf__section-marco">a la población registrada · por línea y por unidad, nunca sumadas entre sí</span>
        </div>
        <div class="inf__kpis">
          <div class="inf__kpi"><span class="inf__kpi-valor">{{ informe.entregas.entregas }}</span><span class="inf__kpi-label">Entregas</span></div>
          <div class="inf__kpi"><span class="inf__kpi-valor">{{ informe.entregas.pacientes }}</span><span class="inf__kpi-label">Pacientes atendidos</span></div>
          <div v-for="u in informe.entregas.por_unidad" :key="u.unidad" class="inf__kpi inf__kpi--ok">
            <span class="inf__kpi-valor">{{ cantidad(u) }}</span><span class="inf__kpi-label">{{ UNIDAD[u.unidad] || u.unidad }}</span>
          </div>
        </div>
        <p v-if="informe.entregas.sin_reprocann_vigente" class="inf__nota">
          {{ informe.entregas.sin_reprocann_vigente }} entregas se hicieron a pacientes sin REPROCANN vigente el día de la entrega.
          Quiénes, en <RouterLink to="/auditor/reprocann" class="inf__aviso-link">REPROCANN → Lo que hay que hacer</RouterLink>.
        </p>
        <p v-if="!informe.entregas.entregas" class="inf__nota">Sin entregas registradas en el semestre.</p>
      </section>

      <p class="inf__pie">
        Declaración jurada semestral<template v-if="informe.club.numero_resolucion_reprocann"> conforme Resol. REPROCANN N.º {{ informe.club.numero_resolucion_reprocann }}</template>
        · generada el {{ formatFechaCorta(informe.generado_en) }} por {{ informe.generado_por }}. El PDF lleva el espacio para la firma del responsable legal.
      </p>
    </div>
  </div>
</template>

<style scoped>
.inf { padding: var(--sp-6); max-width: 1100px; margin: 0 auto; }
.inf__header { display: flex; align-items: center; justify-content: space-between; margin-bottom: var(--sp-6); gap: var(--sp-4); flex-wrap: wrap; }
.inf__head-actions { display: flex; align-items: center; gap: var(--sp-2); flex-wrap: wrap; }
.inf__title { font-size: var(--fs-20); font-weight: 700; color: var(--c-ink-900); display: flex; align-items: center; gap: var(--sp-2); margin: 0; }
.inf__select { background: var(--c-paper); border: 1.5px solid var(--c-ink-300); border-radius: var(--r-md); padding: 6px 10px; font-size: var(--fs-14); color: var(--c-ink-900); font-family: inherit; }
.inf__pdf { display: inline-flex; align-items: center; gap: .4rem; background: var(--c-paper); border: 1.5px solid var(--c-ink-300); border-radius: var(--r-md); padding: 6px 14px; font-size: var(--fs-14); font-weight: 600; color: var(--c-leaf-700); cursor: pointer; }
.inf__pdf:disabled { opacity: .5; cursor: not-allowed; }
.inf__loading { color: var(--c-ink-500); padding: var(--sp-8); text-align: center; }
.inf__error { color: var(--c-rust-600); padding: var(--sp-4); }
.inf__hoja { background: var(--c-paper); }
.inf__resena {
  margin: 0 0 var(--sp-4); padding: .7rem .9rem;
  background: var(--c-slate-50); border-left: 3px solid var(--c-slate-300); border-radius: 0 8px 8px 0;
  font-size: var(--fs-13); color: var(--c-slate-600); line-height: 1.55; max-width: 90ch;
}
.inf__aviso {
  margin: 0 0 var(--sp-4); padding: .7rem .9rem;
  background: var(--c-amber-100); border-left: 3px solid var(--c-amber-500); border-radius: 0 8px 8px 0;
  font-size: var(--fs-13); color: var(--c-ink-800); line-height: 1.55;
}
.inf__aviso-link { color: var(--c-leaf-700); font-weight: 600; text-decoration: underline; }
.inf__section { margin-bottom: var(--sp-8); }
.inf__section-head { display: flex; align-items: baseline; gap: var(--sp-3); flex-wrap: wrap; margin-bottom: var(--sp-3); }
.inf__section-title { font-size: var(--fs-16); font-weight: 700; color: var(--c-ink-900); margin: 0; }
.inf__section-marco { font-size: var(--fs-12); color: var(--c-ink-500); }
.inf__fields { display: grid; grid-template-columns: repeat(auto-fit, minmax(240px, 1fr)); gap: var(--sp-3) var(--sp-5); margin: 0; }
.inf__fields dt { font-size: var(--fs-11); text-transform: uppercase; letter-spacing: .05em; color: var(--c-ink-500); }
.inf__fields dd { margin: 2px 0 0; font-size: var(--fs-14); color: var(--c-ink-900); }
.inf__falta { color: var(--c-amber-500); }
.inf__kpis { display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: var(--sp-3); margin-bottom: var(--sp-4); }
.inf__kpi { background: var(--c-paper); border: 1px solid var(--c-ink-100); border-radius: var(--r-lg); padding: var(--sp-3) var(--sp-4); }
.inf__kpi-valor { display: block; font-size: var(--fs-24); font-weight: 800; color: var(--c-ink-900); line-height: 1.1; font-variant-numeric: tabular-nums; }
.inf__kpi-label { display: block; font-size: var(--fs-12); color: var(--c-ink-700); margin-top: var(--sp-1); }
.inf__kpi-label small { color: var(--c-ink-500); font-weight: 400; }
.inf__kpi--ok .inf__kpi-valor  { color: var(--c-leaf-600); }
.inf__kpi--bad .inf__kpi-valor { color: var(--c-rust-600); }
.inf__nota { color: var(--c-ink-500); font-size: var(--fs-13); margin: var(--sp-2) 0 0; }
.inf__table { width: 100%; border-collapse: collapse; font-size: var(--fs-13); }
.inf__table th { text-align: left; padding: var(--sp-2) var(--sp-3); background: var(--c-ink-50); font-weight: 600; color: var(--c-ink-600); border-bottom: 1px solid var(--c-ink-100); }
.inf__table td { padding: var(--sp-2) var(--sp-3); border-bottom: 1px solid var(--c-ink-50); color: var(--c-ink-800); vertical-align: top; }
.inf__table .num { text-align: right; width: 1%; white-space: nowrap; font-variant-numeric: tabular-nums; }
.inf__table .mono { font-family: var(--font-mono); font-size: var(--fs-13); }
.inf__table th:first-child, .inf__table td:first-child { width: auto; }
.inf__obtentor { color: var(--c-ink-500); }
.inf__acredita { font-size: var(--fs-12); color: var(--c-ink-500); margin-top: 2px; }
.inf__sin-vinculo { display: inline-block; margin-left: var(--sp-2); padding: 1px 7px; border-radius: 999px; background: var(--c-amber-100); color: var(--c-amber-500); font-size: var(--fs-11); font-weight: 600; text-transform: uppercase; letter-spacing: .03em; }
.inf__estado { display: inline-block; padding: 1px 8px; border-radius: 999px; font-size: var(--fs-12); font-weight: 600; background: var(--c-ink-100); color: var(--c-ink-700); }
.inf__estado--ok   { background: var(--c-leaf-100); color: var(--c-leaf-800); }
.inf__estado--warn { background: var(--c-amber-100); color: var(--c-amber-500); }
.inf__estado--bad  { background: var(--c-rust-100); color: var(--c-rust-600); }
.inf__pie { margin-top: var(--sp-6); padding-top: var(--sp-4); border-top: 1px solid var(--c-ink-100); font-size: var(--fs-12); color: var(--c-ink-500); }
</style>
