<template>
  <div class="inf">
    <div class="inf__header">
      <h1 class="inf__title"><FileCheck :size="20" :stroke-width="1.75" /> Informe REPROCANN</h1>
      <div class="inf__acciones">
        <SelectorPeriodo @change="cambiarPeriodo" />
        <button class="inf__btn" :disabled="descargando" @click="descargar('pdf')">
          <FileDown :size="15" :stroke-width="2" /> PDF
        </button>
        <button class="inf__btn" :disabled="descargando" @click="descargar('xlsx')">
          <Sheet :size="15" :stroke-width="2" /> Excel
        </button>
        <!-- Presentar es un acto aparte y la app no lo hace: sólo este botón valida el INASE. -->
        <button class="inf__btn" :disabled="descargando"
                title="Valida que todas las variedades estén acreditadas ante el INASE"
                @click="descargar('pdf', true)">
          <FileCheck :size="15" :stroke-width="2" /> Para presentar
        </button>
      </div>
    </div>

    <div v-if="loading" class="inf__loading">Cargando…</div>

    <div v-else-if="data">
      <!-- Qué contesta este informe. Sin esto hay que deducirlo de los números, y
           dos informes que cortan el mismo dato distinto parecen contradecirse. -->
      <p v-if="data.resena" class="inf__resena">{{ data.resena }}</p>
      <div class="inf__kpis">
        <div class="inf__kpi">
          <span class="inf__kpi-valor">{{ data.total_pacientes }}</span>
          <span class="inf__kpi-label">Total pacientes</span>
        </div>
        <div class="inf__kpi inf__kpi--ok">
          <span class="inf__kpi-valor">{{ data.con_reprocann_vigente }}</span>
          <span class="inf__kpi-label">Con REPROCANN vigente</span>
        </div>
        <div class="inf__kpi inf__kpi--warn">
          <span class="inf__kpi-valor">{{ data.vencen_30d }}</span>
          <span class="inf__kpi-label">Vencen en 30 días</span>
        </div>
        <div class="inf__kpi inf__kpi--err">
          <span class="inf__kpi-valor">{{ data.vencidos }}</span>
          <span class="inf__kpi-label">Vencidos</span>
        </div>
        <div v-if="data.pendientes" class="inf__kpi inf__kpi--warn">
          <span class="inf__kpi-valor">{{ data.pendientes }}</span>
          <span class="inf__kpi-label">Trámite pendiente</span>
        </div>
      </div>

      <!-- Qué se entregó y a quién, DEL PERÍODO, por unidad. «Sin vigente» se juzga el día de la
           entrega, no hoy. Nada de cultivo: eso está en Producción. -->
      <div v-if="data.dispensaciones" class="inf__section">
        <h2 class="inf__section-title">Entregas a esta población <span class="inf__section-marco">{{ data.periodo }}</span></h2>
        <div class="inf__kpis">
          <div class="inf__kpi">
            <span class="inf__kpi-valor">{{ data.dispensaciones.total }}</span>
            <span class="inf__kpi-label">Entregas</span>
          </div>
          <div v-for="u in data.dispensaciones.por_unidad" :key="u.unidad" class="inf__kpi">
            <span class="inf__kpi-valor">{{ cant(u.cantidad, u.unidad) }}</span>
            <span class="inf__kpi-label">{{ nombreUnidad(u.unidad) }}</span>
          </div>
          <div class="inf__kpi">
            <span class="inf__kpi-valor">{{ data.dispensaciones.pacientes_atendidos }}</span>
            <span class="inf__kpi-label">Pacientes atendidos</span>
          </div>
          <div class="inf__kpi" :class="data.dispensaciones.entregas_sin_vigente ? 'inf__kpi--err' : 'inf__kpi--ok'">
            <span class="inf__kpi-valor">{{ data.dispensaciones.entregas_sin_vigente }}</span>
            <span class="inf__kpi-label">Entregas sin REPROCANN vigente ese día</span>
            <span v-if="data.dispensaciones.sin_reprocann_vigente" class="inf__kpi-sub">a {{ data.dispensaciones.sin_reprocann_vigente }} {{ data.dispensaciones.sin_reprocann_vigente === 1 ? 'paciente' : 'pacientes' }}</span>
          </div>
        </div>
      </div>

      <!-- LO QUE HAY QUE HACER, con nombre: la parte del admin. No va al PDF que se presenta. -->
      <div class="inf__section">
        <h2 class="inf__section-title">Lo que hay que hacer <span class="inf__section-marco">para el admin, con nombres · no va al PDF que se presenta</span></h2>
        <table v-if="data.lista_pendientes?.length" class="inf__table">
          <thead><tr><th>Pendiente</th><th>Paciente</th><th>DNI</th><th>Vence / venció</th><th>Última entrega</th><th></th></tr></thead>
          <tbody>
            <tr v-for="(p, i) in data.lista_pendientes" :key="i">
              <td><span class="inf__badge" :class="`inf__badge--${p.pendiente}`">{{ PENDIENTES[p.pendiente] || p.pendiente }}</span></td>
              <td>{{ p.paciente }}</td>
              <td class="inf__mono">···{{ p.dni_ultimos_3 }}</td>
              <td :class="{ 'inf__vencido': p.dias != null && p.dias < 0 }">{{ vence(p) }}</td>
              <td>{{ p.ultima_entrega ? formatDate(p.ultima_entrega) : '—' }}</td>
              <td><RouterLink :to="`/pacientes/${p.paciente_id}`" class="inf__link">ficha</RouterLink></td>
            </tr>
          </tbody>
        </table>
        <p v-else class="inf__ok">Nada pendiente: toda la población registrada está en regla.</p>
      </div>

      <!-- Sin corte por sede: un PACIENTE ES DEL CLUB, no de una sede. Lo que había agrupaba
           por la sede de su última dispensación, una dimensión inventada que dejaba a los que
           nunca retiraron en una fila que parecía una sede. La actividad por sede es otra
           pregunta y vive en el informe de dispensaciones. -->
      <p v-if="data.pacientes_sin_registro" class="inf__pendiente">
        La organización tiene además <strong>{{ data.pacientes_sin_registro }}</strong>
        paciente{{ data.pacientes_sin_registro === 1 ? '' : 's' }} activo{{ data.pacientes_sin_registro === 1 ? '' : 's' }}
        sin REPROCANN iniciado. No integran esta nómina —declara la población registrada— y se
        gestionan desde <RouterLink to="/pacientes">Pacientes</RouterLink>.
      </p>

      <div class="inf__section">
        <h2 class="inf__section-title">Nómina de pacientes <span class="inf__section-marco">lo que se presenta · ordenada por vencimiento</span></h2>
        <table class="inf__table">
          <thead><tr><th>Paciente</th><th>DNI</th><th>Estado REPROCANN</th><th>Vencimiento</th></tr></thead>
          <tbody>
            <tr v-for="(p, i) in nomina" :key="i">
              <td>{{ p.nombre_completo || p.iniciales }}</td>
              <td class="inf__mono">···{{ p.dni_ultimos_3 }}</td>
              <td><span class="inf__badge" :class="`inf__badge--${p.reprocann_estado}`">{{ estadoLabel(p.reprocann_estado) }}</span></td>
              <td>{{ p.reprocann_vencimiento ? formatDate(p.reprocann_vencimiento) : '—' }}</td>
            </tr>
            <tr v-if="data.lista_omitidos"><td colspan="4" class="inf__mas">… {{ data.lista_omitidos }} pacientes más. El PDF y el Excel los llevan completos.</td></tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { RouterLink } from 'vue-router'
import { FileCheck, FileDown, Sheet } from 'lucide-vue-next'
import api from '../../lib/api.js'
import { descargarArchivo } from '../../lib/descargas.js'
import { useToast } from '../../composables/useToast.js'
import { hoyISO } from '../../utils/dates.js'
import SelectorPeriodo from '../../components/informes/SelectorPeriodo.vue'

const toast = useToast()
// Los MISMOS parámetros para la pantalla y para la descarga.
const params = ref({ periodo: 'mes_actual' })
const loading = ref(false)
const data    = ref(null)
const descargando = ref(false)

// `paraPresentar`: sólo entonces se valida que las variedades estén acreditadas ante el INASE.
// Para mirar, sale siempre con la salvedad impresa — la app no es un canal oficial.
async function descargar(formato, paraPresentar = false) {
  descargando.value = true
  try {
    await descargarArchivo(`/informes/reprocann.${formato}`, {
      params: { ...params.value, para_presentar: paraPresentar ? 1 : undefined },
      filename: `informe_reprocann_${hoyISO()}.${formato}`,
    })
  } catch (e) {
    // Antes: `catch {}` con un mensaje genérico que tapaba lo que el backend explicaba.
    toast.error(e.message, { timeout: e.conMotivo ? 9000 : 5000 })
  } finally {
    descargando.value = false
  }
}

async function cargar() {
  loading.value = true
  try {
    const res = await api.get('/informes/reprocann', { params: params.value })
    data.value = res.data
  } finally {
    loading.value = false
  }
}

function cambiarPeriodo(p) { params.value = p; cargar() }
// La nómina es la población registrada ENTERA (vencidos incluidos: están registrados), por
// vencimiento. Los sin registro se informan aparte.
const ORDEN = { vencido: 0, por_vencer: 1, pendiente: 2, vigente: 3, vigente_sin_vencimiento: 4 }
const nomina = computed(() => [...(data.value?.lista_anonimizada || [])]
  .filter(p => p.reprocann_estado !== 'sin_reprocann')
  .sort((a, b) => (ORDEN[a.reprocann_estado] ?? 9) - (ORDEN[b.reprocann_estado] ?? 9) || String(a.reprocann_vencimiento || '9').localeCompare(String(b.reprocann_vencimiento || '9'))))
const PENDIENTES = { vencido_retiro: 'Venció y sigue retirando', vencido: 'Vencido', por_vencer: 'Vence en ≤30 días', pendiente: 'Trámite pendiente', sin_seguimiento: 'Sin seguimiento médico' }
const vence = (p) => p.dias == null ? '—' : p.dias < 0 ? `hace ${-p.dias} días` : p.dias === 0 ? 'hoy' : `en ${p.dias} días`
const UNIDADES = { g: 'En gramos', un: 'En unidades', ml: 'En mililitros' }
const nombreUnidad = (u) => UNIDADES[u] || `En ${u}`
const cant = (c, u) => `${Number(c).toLocaleString('es-AR', { maximumFractionDigits: 1 })} ${u}`
const ESTADO_LABELS = { vigente: 'Vigente', vencido: 'Vencido', por_vencer: 'Por vencer', pendiente: 'Trámite pendiente', sin_reprocann: 'Sin REPROCANN', vigente_sin_vencimiento: 'Vigente s/venc.' }
const estadoLabel = (e) => ESTADO_LABELS[e] || e
const formatDate = (d) => d ? new Date(d).toLocaleDateString('es-AR') : '—'

onMounted(cargar)
</script>

<style scoped>
.inf { padding: var(--sp-6); max-width: 900px; margin: 0 auto; }
.inf__header { display: flex; align-items: center; justify-content: space-between; margin-bottom: var(--sp-6); gap: var(--sp-4); flex-wrap: wrap; }
.inf__acciones { display: flex; align-items: center; gap: var(--sp-2); flex-wrap: wrap; }
.inf__btn { display: inline-flex; align-items: center; gap: 5px; background: #15803d; color: #fff; border: none; border-radius: var(--r-md); padding: 7px 12px; font-size: var(--fs-13); font-weight: 600; cursor: pointer; transition: background .15s; }
.inf__btn:hover:not(:disabled) { background: #166534; }
.inf__btn:disabled { opacity: .55; cursor: wait; }
.inf__title { font-size: var(--fs-20); font-weight: 700; color: var(--c-ink-900); display: flex; align-items: center; gap: var(--sp-2); margin: 0; }
.inf__periodo { background: var(--c-ink-50); border: 1.5px solid var(--c-ink-200); border-radius: var(--r-md); padding: 6px 12px; font-size: var(--fs-14); color: var(--c-ink-900); }
.inf__loading { color: var(--c-ink-500); padding: var(--sp-8); text-align: center; }
.inf__resena {
  margin: 0 0 var(--sp-4); padding: .7rem .9rem;
  background: var(--c-slate-50); border-left: 3px solid var(--c-slate-300); border-radius: 0 8px 8px 0;
  font-size: var(--fs-13); color: var(--c-slate-600); line-height: 1.55; max-width: 80ch;
}
.inf__kpis { display: grid; grid-template-columns: repeat(auto-fill, minmax(140px, 1fr)); gap: var(--sp-4); margin-bottom: var(--sp-6); }
.inf__kpi { background: var(--c-paper); border: 1px solid var(--c-ink-100); border-radius: var(--r-lg); padding: var(--sp-4); text-align: center; }
.inf__kpi-valor { display: block; font-size: var(--fs-28); font-weight: 800; color: var(--c-ink-900); line-height: 1; }
.inf__kpi-label { display: block; font-size: var(--fs-12); color: var(--c-ink-500); margin-top: var(--sp-1); }
.inf__kpi--ok .inf__kpi-valor { color: #2D8A6B; }
.inf__kpi--warn .inf__kpi-valor { color: #B85C00; }
.inf__kpi--err .inf__kpi-valor { color: var(--c-rust-600); }
.inf__section-title { font-size: var(--fs-16); font-weight: 700; color: var(--c-ink-900); margin-bottom: var(--sp-3); }
/* Qué está contando la tabla: sin esto, dos informes que cuentan cosas distintas parecen
   contradecirse (uno cuenta pacientes, el otro entregas del período). */
.inf__pendiente {
  margin: 0 0 var(--sp-5); padding: .7rem .9rem; border-radius: 8px;
  background: #fffbeb; border: 1px solid #fef3c7;
  font-size: var(--fs-13); color: #92400e; line-height: 1.5;
}
.inf__pendiente a { color: #92400e; font-weight: 700; }
.inf__section-hint { margin: calc(var(--sp-3) * -1) 0 var(--sp-3); font-size: var(--fs-12); color: var(--c-ink-500); line-height: 1.5; }
.inf__table { width: 100%; border-collapse: collapse; font-size: var(--fs-14); }
.inf__table th { text-align: left; padding: var(--sp-2) var(--sp-3); background: var(--c-ink-50); font-weight: 600; color: var(--c-ink-600); border-bottom: 1px solid var(--c-ink-100); }
.inf__table td { padding: var(--sp-2) var(--sp-3); border-bottom: 1px solid var(--c-ink-50); color: var(--c-ink-800); }
.inf__badge { display: inline-block; padding: 2px 8px; border-radius: 999px; font-size: var(--fs-11); font-weight: 600; background: var(--c-ink-100); color: var(--c-ink-600); }
.inf__badge--vigente { background: rgba(45,138,107,.1); color: #2D8A6B; }
.inf__badge--vencido { background: rgba(180,40,40,.1); color: var(--c-rust-600); }
.inf__badge--por_vencer { background: rgba(184,92,0,.1); color: #B85C00; }
.inf__badge--vencido_retiro { background: rgba(180,40,40,.15); color: var(--c-rust-600); }
.inf__badge--pendiente { background: rgba(184,92,0,.1); color: #B85C00; }
.inf__badge--sin_seguimiento { background: var(--c-ink-100); color: var(--c-ink-600); }
.inf__section-marco { font-size: var(--fs-12); color: var(--c-ink-500); font-weight: 400; margin-left: var(--sp-2); }
.inf__kpi-sub { display: block; font-size: var(--fs-12); color: var(--c-ink-500); margin-top: 2px; }
.inf__mono { font-family: var(--font-mono, monospace); font-size: var(--fs-13); }
.inf__vencido { color: var(--c-rust-600); font-weight: 600; }
.inf__link { color: #15803d; font-size: var(--fs-13); }
.inf__ok { color: #2D8A6B; font-size: var(--fs-14); }
.inf__mas { color: var(--c-ink-500); font-size: var(--fs-13); font-style: italic; }
</style>
