<template>
  <!-- EL DETALLE DE UN CIERRE QUE PIDE ATENCIÓN. «Faltan $ 12.400» no se puede revisar sin la
       cuenta: de dónde sale el esperado, qué dijo quien cerró, qué pudo causarlo y qué pasó en la
       jornada. Lo arma `Panel::DetalleCierre`; acá se muestra y se ofrecen los arreglos que ya
       existen (marcar como revisado, ir al cierre, ir a la dispensa señalada). -->
  <Teleport to="body">
    <div v-modal="() => emit('close')" class="dcp__overlay" @click.self="emit('close')">
      <aside class="dcp" role="dialog" aria-modal="true" aria-labelledby="dcp-titulo">
        <header class="dcp__hd">
          <div class="dcp__hd-txt">
            <span class="dcp__tipo" :class="{ 'is-neg': negativo }">{{ tipoLabel }}</span>
            <h2 id="dcp-titulo" class="dcp__titulo">
              {{ d ? `${d.sede.nombre} · cierre del ${fecha(d.cerrado_at)}` : 'Cargando…' }}
            </h2>
            <span v-if="d" class="dcp__meta">
              Responsable: {{ d.responsable || '—' }} · Apertura {{ hora(d.abierto_at) }} · Cierre {{ hora(d.cerrado_at) }}
            </span>
          </div>
          <button type="button" class="dcp__cerrar" aria-label="Cerrar" @click="emit('close')">
            <svg aria-hidden="true" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor"
                 stroke-width="2" stroke-linecap="round"><path d="M6 6l12 12M18 6L6 18" /></svg>
          </button>
        </header>

        <div class="dcp__cuerpo">
          <p v-if="error" class="dcp__error" role="alert">{{ error }}</p>
          <template v-if="d">
            <section v-if="d.conciliacion" aria-label="Conciliación del efectivo" class="dcp__conc">
              <dl>
                <template v-for="(l, i) in d.conciliacion.lineas" :key="i">
                  <dt>{{ i === 0 ? '' : l.monto < 0 ? '− ' : '+ ' }}{{ l.concepto }}</dt>
                  <dd class="num">{{ pesos(Math.abs(l.monto)) }}</dd>
                </template>
                <dt class="dcp__tot">Saldo esperado</dt><dd class="dcp__tot num">{{ pesos(d.conciliacion.esperado) }}</dd>
                <dt class="dcp__tot">Saldo declarado al cierre</dt>
                <dd class="dcp__tot num">{{ d.conciliacion.declarado === null ? '—' : pesos(d.conciliacion.declarado) }}</dd>
                <dt class="dcp__dif" :class="{ 'is-neg': d.conciliacion.diferencia < 0 }">Diferencia</dt>
                <dd class="dcp__dif num" :class="{ 'is-neg': d.conciliacion.diferencia < 0 }">
                  {{ d.conciliacion.diferencia ? `${d.conciliacion.diferencia < 0 ? '− ' : '+ '}${pesos(Math.abs(d.conciliacion.diferencia))}` : 'Sin diferencia' }}
                </dd>
              </dl>
            </section>

            <section v-if="d.inventario.length" class="dcp__sec" aria-labelledby="dcp-inv">
              <h3 id="dcp-inv" class="dcp__h3">Diferencias de inventario</h3>
              <table class="dcp__tabla">
                <thead><tr><th scope="col">Producto</th><th scope="col" class="r">Esperado</th><th scope="col" class="r">Contado</th>
                  <th scope="col" class="r">Diferencia</th><th scope="col" class="r">Costo</th></tr></thead>
                <tbody>
                  <tr v-for="(it, i) in d.inventario" :key="i">
                    <td>{{ it.producto }}<span v-if="it.motivo" class="dcp__motivo">{{ it.motivo }}</span></td>
                    <td class="r num">{{ cant(it.esperado, it.unidad) }}</td>
                    <td class="r num">{{ cant(it.contado, it.unidad) }}</td>
                    <td class="r num" :class="{ 'is-neg': it.diferencia < 0 }">{{ it.diferencia > 0 ? '+' : '' }}{{ cant(it.diferencia, it.unidad) }}</td>
                    <td class="r num">{{ pesos(it.costo_ars) }}</td>
                  </tr>
                </tbody>
              </table>
            </section>

            <section v-if="d.observacion" class="dcp__sec" aria-labelledby="dcp-obs">
              <h3 id="dcp-obs" class="dcp__h3">Observación del responsable</h3>
              <blockquote class="dcp__obs">«{{ d.observacion }}»</blockquote>
            </section>

            <section v-if="d.causas.length" class="dcp__sec" aria-labelledby="dcp-causas">
              <h3 id="dcp-causas" class="dcp__h3">Posibles causas detectadas</h3>
              <div v-for="(c, i) in d.causas" :key="i" class="dcp__causa" :class="{ 'dcp__causa--fuerte': c.tipo === 'mismo_importe' }">
                <span>{{ c.texto }}</span>
                <RouterLink v-if="c.dispensacion_id" :to="ruta(`/dispensaciones/${c.dispensacion_id}`)" class="dcp__causa-link">
                  Ver la dispensa
                </RouterLink>
              </div>
            </section>

            <section v-if="d.jornada.length" class="dcp__sec" aria-labelledby="dcp-jornada">
              <h3 id="dcp-jornada" class="dcp__h3">Registro de la jornada</h3>
              <ol class="dcp__jornada">
                <li v-for="(e, i) in d.jornada" :key="i"><span class="num dcp__hora">{{ e.hora }}</span><span>{{ e.texto }}</span></li>
              </ol>
            </section>
          </template>
        </div>

        <footer v-if="d" class="dcp__pie">
          <p v-if="d.revisado" class="dcp__revisado">Revisado por {{ d.revisado_por || 'administración' }}.</p>
          <div class="dcp__acciones">
            <button v-if="!d.revisado" type="button" class="dcp__btn dcp__btn--pri" :disabled="guardando" @click="marcarRevisado">
              {{ guardando ? 'Guardando…' : 'Marcar como revisado' }}
            </button>
            <RouterLink :to="ruta(`/mostrador?sede=${d.sede.id}&solapa=cierres`)" class="dcp__btn">Ver el cierre completo</RouterLink>
          </div>
          <p class="dcp__nota">Marcar como revisado congela el cierre: desde el cierre completo se puede corregir antes.</p>
        </footer>
      </aside>
    </div>
  </Teleport>
</template>

<script setup>
import { computed, onMounted, ref } from 'vue'
import { getDetalleCierrePanel, revisarTurnoMostrador } from '../../lib/api.js'
import { useToast } from '../../composables/useToast.js'

const props = defineProps({
  // El asunto del panel: { tipo: 'caja' | 'inventario', turno_id, sede_id, valor }.
  asunto: { type: Object, required: true },
  // Traduce un enlace a la pantalla que corresponde (escritorio o teléfono); la da el panel.
  ruta: { type: Function, default: (p) => p },
})
const emit = defineEmits(['close', 'revisado'])
const toast = useToast()

const d = ref(null)
const error = ref('')
const guardando = ref(false)

const negativo = computed(() => props.asunto.tipo === 'inventario' || Number(props.asunto.valor) < 0)
const tipoLabel = computed(() => props.asunto.tipo === 'inventario' ? 'Diferencia de inventario'
  : Number(props.asunto.valor) < 0 ? 'Faltante de caja' : 'Sobrante de caja')

onMounted(async () => {
  try {
    const { data } = await getDetalleCierrePanel(props.asunto.turno_id)
    d.value = data
  } catch {
    error.value = 'No se pudo cargar el detalle del cierre.'
  }
})

async function marcarRevisado () {
  guardando.value = true
  try {
    await revisarTurnoMostrador(d.value.sede.id, d.value.turno_id)
    toast.success('Cierre marcado como revisado')
    emit('revisado')
  } catch {
    toast.error('No se pudo marcar como revisado')
  } finally {
    guardando.value = false
  }
}

const pesos = (n) => `$ ${Math.round(Number(n || 0)).toLocaleString('es-AR')}`
const cant = (n, u) => n === null || n === undefined ? '—' : `${Number(n).toLocaleString('es-AR', { maximumFractionDigits: 2 })} ${u}`
const hora = (iso) => iso ? new Date(iso).toLocaleTimeString('es-AR', { hour: '2-digit', minute: '2-digit', hourCycle: 'h23' }) : '—'
const fecha = (iso) => iso ? new Date(iso).toLocaleDateString('es-AR', { day: '2-digit', month: '2-digit', year: 'numeric' }) : '—'
</script>

<style scoped>
.num { font-family: var(--font-mono); font-variant-numeric: tabular-nums; }
.is-neg { color: var(--c-rust-600); }
.r { text-align: right; }
.dcp__overlay { position: fixed; inset: 0; background: rgba(14, 16, 17, .45); z-index: 1500; display: flex; justify-content: flex-end; }
.dcp { width: min(600px, 100%); height: 100%; background: white; display: flex; flex-direction: column; box-shadow: -24px 0 60px rgba(14, 16, 17, .18); }
.dcp__hd { padding: 22px 26px 16px; border-bottom: 1px solid var(--c-leaf-50); display: flex; gap: 16px; align-items: flex-start; }
.dcp__hd-txt { flex: 1; display: flex; flex-direction: column; gap: 6px; min-width: 0; }
.dcp__tipo { font-size: var(--fs-12); font-weight: 600; letter-spacing: .08em; text-transform: uppercase; color: var(--c-amber-500); }
.dcp__tipo.is-neg { color: var(--c-rust-600); }
.dcp__titulo { margin: 0; font-family: var(--font-display); font-size: 22px; font-weight: 600; color: var(--c-ink-900); }
.dcp__meta { font-size: var(--fs-13); color: var(--c-ink-700); }
.dcp__cerrar { width: 44px; height: 44px; border-radius: 10px; border: 1px solid var(--c-leaf-100); background: white; color: var(--c-ink-700); display: flex; align-items: center; justify-content: center; cursor: pointer; flex: 0 0 auto; }
.dcp__cuerpo { flex: 1; overflow: auto; padding: 20px 26px; display: flex; flex-direction: column; gap: 22px; }
/* Dentro de una columna con scroll, una sección no se encoge: se cortaba la diferencia. */
.dcp__cuerpo > * { flex-shrink: 0; }
.dcp__error { margin: 0; color: var(--c-rust-600); }
.dcp__conc { border: 1px solid var(--c-leaf-100); border-radius: 14px; overflow: hidden; }
.dcp__conc dl { margin: 0; display: grid; grid-template-columns: minmax(0, 1fr) auto; font-size: 14px; }
.dcp__conc dt, .dcp__conc dd { margin: 0; padding: 11px 16px; border-top: 1px solid var(--c-leaf-50); }
.dcp__conc dt:first-of-type, .dcp__conc dd:first-of-type { border-top: 0; }
.dcp__conc dt { color: var(--c-ink-700); font-weight: 400; }
.dcp__conc dd { text-align: right; color: var(--c-ink-900); }
.dcp__tot { font-weight: 600; background: var(--c-paper); color: var(--c-ink-900) !important; }
.dcp__dif { font-weight: 700; background: var(--c-paper); color: var(--c-ink-900); }
.dcp__dif.is-neg { background: var(--c-rust-100); color: var(--c-rust-600); }
.dcp__sec { display: flex; flex-direction: column; gap: 10px; }
.dcp__h3 { margin: 0; font-size: 14px; font-weight: 600; color: var(--c-ink-900); }
.dcp__tabla { width: 100%; border-collapse: collapse; font-size: var(--fs-13); }
.dcp__tabla th { text-align: left; font-size: var(--fs-12); color: var(--c-ink-500); font-weight: 600; padding: 6px 8px; }
.dcp__tabla th.r { text-align: right; }
.dcp__tabla td { padding: 8px; border-top: 1px solid var(--c-leaf-50); color: var(--c-ink-900); }
.dcp__motivo { display: block; color: var(--c-ink-500); font-size: var(--fs-12); }
.dcp__obs { margin: 0; padding: 14px 16px; background: var(--c-paper); border-radius: 12px; font-size: 14px; color: var(--c-ink-700); }
.dcp__causa { display: flex; flex-wrap: wrap; gap: 8px 14px; align-items: baseline; justify-content: space-between; padding: 12px 14px; border: 1px solid var(--c-leaf-100); border-radius: 12px; font-size: 14px; color: var(--c-ink-700); }
.dcp__causa--fuerte { border-color: var(--c-amber-500); background: var(--c-amber-100); color: var(--c-ink-900); }
.dcp__causa-link { font-weight: 600; color: var(--c-leaf-800); white-space: nowrap; }
.dcp__jornada { margin: 0; padding: 0; list-style: none; font-size: var(--fs-13); }
.dcp__jornada li { display: grid; grid-template-columns: 52px minmax(0, 1fr); gap: 12px; padding: 8px 0; border-bottom: 1px solid var(--c-leaf-50); color: var(--c-ink-900); }
.dcp__jornada li:last-child { border-bottom: 0; }
.dcp__hora { color: var(--c-ink-500); }
.dcp__pie { padding: 14px 26px 20px; border-top: 1px solid var(--c-leaf-50); display: flex; flex-direction: column; gap: 10px; }
.dcp__revisado { margin: 0; font-size: var(--fs-13); color: var(--c-leaf-600); font-weight: 600; }
.dcp__acciones { display: flex; flex-wrap: wrap; gap: 10px; }
.dcp__btn { flex: 1 1 180px; min-height: 44px; border: 1px solid var(--c-leaf-300); border-radius: 10px; background: white; color: var(--c-leaf-800); font: 600 14px var(--font-ui); cursor: pointer; display: inline-flex; align-items: center; justify-content: center; text-decoration: none; padding: 0 14px; }
.dcp__btn--pri { background: var(--c-leaf-800); border-color: var(--c-leaf-800); color: white; }
.dcp__btn:disabled { opacity: .6; cursor: default; }
.dcp__nota { margin: 0; font-size: var(--fs-12); color: var(--c-ink-500); }
@media (max-width: 640px) {
  .dcp__hd, .dcp__cuerpo, .dcp__pie { padding-left: 16px; padding-right: 16px; }
}
</style>
