<template>
  <section v-if="visible" class="rnd">
    <!-- ══ HISTORIAL: lo que ya pasó ═════════════════════════════════════════ -->
    <template v-if="historial">
      <p v-if="!rendiciones.length" class="rnd__vacio">No hay rendiciones en {{ nombreMes || 'este mes' }}.</p>
      <div v-else class="rnd__tabla-wrap">
        <table class="rnd__tabla tabla-cards">
          <thead>
            <tr>
              <th>Estado</th>
              <th>Repartidor</th>
              <th>Recibe</th>
              <th class="rnd__th-num">Cobró</th>
              <th class="rnd__th-num">Entregó</th>
              <th class="rnd__th-num">Diferencia</th>
              <th>Conformidad</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="r in rendiciones" :key="r.id" :class="{ 'rnd__fila--pend': r.estado === 'pendiente' }">
              <td data-col="Estado">
                <span class="rnd__chip" :class="estadoDe(r).clase">{{ estadoDe(r).texto }}</span>
              </td>
              <td data-col="Repartidor">
                <div class="rnd__td-fuerte">{{ r.delivery }}</div>
                <div class="rnd__td-mut">Rindió el {{ fechaHora(r.rendida_at) }}</div>
              </td>
              <td data-col="Recibe">
                <div class="rnd__td-fuerte">{{ r.receptor || '—' }}</div>
                <div v-if="r.estado === 'recibida'" class="rnd__td-mut">Recibió el {{ fechaHora(r.recibida_at) }}</div>
                <div v-else-if="r.estado === 'pendiente'" class="rnd__td-mut rnd__td-espera">
                  Esperando {{ esperando(r.rendida_at) }}
                </div>
                <!-- Si nadie la recibe, administración la dirige a otra persona, que la cuenta.
                     No se recibe en nombre de otro (`Rendiciones::Reasignar`). -->
                <div v-if="r.puedo_reasignar" class="rnd__reasignar">
                  <select v-model="reasignarA[r.id]" class="rnd__select rnd__select--sm" :aria-label="`Reasignar la rendición de ${r.delivery}`">
                    <option value="">Reasignar a…</option>
                    <option v-for="p in receptoresPara(r)" :key="p.id" :value="p.id">{{ p.nombre }}</option>
                  </select>
                  <button type="button" class="rnd__btn rnd__btn--sm" :disabled="!reasignarA[r.id] || guardando"
                          @click="reasignar(r)">Reasignar</button>
                </div>
              </td>
              <td class="rnd__td-num rnd__td-mut" data-col="Cobró">${{ fmt(r.declarado_ars) }}</td>
              <td class="rnd__td-num rnd__td-fuerte" data-col="Entregó">
                <template v-if="r.recibido_ars != null">${{ fmt(r.recibido_ars) }}</template>
                <span v-else class="rnd__td-mut">—</span>
              </td>
              <td class="rnd__td-num" data-col="Diferencia">
                <span v-if="r.diferencia_ars" class="rnd__dif">{{ r.diferencia_ars < 0 ? '−' : '+' }}${{ fmt(Math.abs(r.diferencia_ars)) }}</span>
                <span v-else class="rnd__td-mut">—</span>
              </td>
              <td data-col="Conformidad">
                <!-- La conformidad es constancia, no candado: la plata entró igual. Sólo se pide
                     cuando hubo ajuste; si cuadró, no hay nada que conformar. -->
                <template v-if="r.estado === 'recibida' && r.diferencia_ars">
                  <span v-if="r.conforme === false" class="rnd__chip rnd__chip--espera">Sin conformar</span>
                  <span v-else-if="r.conforme === true" class="rnd__chip rnd__chip--ok">Conformada</span>
                  <div v-if="r.motivo" class="rnd__td-mut rnd__motivo">{{ r.motivo }}</div>
                </template>
                <span v-else class="rnd__td-mut">—</span>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </template>

    <!-- ══ REPARTIDOR: rendir lo que cobró ═══════════════════════════════════ -->
    <template v-else-if="soyRepartidor">
      <!-- Lo que tiene del club y todavía no devolvió. No lo veía en ningún lado: si le
           anotaron $20.000 tenía que preguntar, y así es como una diferencia chica se convierte
           en una discusión. No es una deuda ni una pérdida: es plata suya que quedó con él. -->
      <p v-if="miSaldo > 0" class="rnd__saldo">
        Tenés <b>${{ fmt(miSaldo) }}</b> de la organización de rendiciones anteriores. Se descuenta cuando
        los entregás.
      </p>
      <div v-if="miPendiente" class="rnd__box rnd__box--espera">
        <div>
          <p class="rnd__titulo">Rendiste ${{ fmt(miPendiente.declarado_ars) }}</p>
          <p class="rnd__sub">Esperando que {{ miPendiente.receptor }} la reciba y la cuente.</p>
        </div>
      </div>

      <div v-else-if="miAjustada" class="rnd__box rnd__box--ajuste">
        <div>
          <p class="rnd__titulo">
            {{ miAjustada.receptor }} recibió ${{ fmt(miAjustada.recibido_ars) }}
            de los ${{ fmt(miAjustada.declarado_ars) }} que cobraste
          </p>
          <p class="rnd__sub">{{ miAjustada.motivo }}</p>
        </div>
        <div class="rnd__acc">
          <button class="rnd__btn rnd__btn--primary" :disabled="guardando" @click="conformar(miAjustada, true)">
            Estoy de acuerdo
          </button>
          <button class="rnd__btn" :disabled="guardando" @click="desacuerdo = ''">No</button>
        </div>
        <!-- No estar de acuerdo NO devuelve la plata ni reabre nada: queda escrito y se habla. -->
        <div v-if="desacuerdo !== null" class="rnd__desacuerdo">
          <label class="rnd__campo rnd__campo--motivo">
            <span class="rnd__campo-lbl">¿Qué pasó? Lo ve administración</span>
            <input v-model="desacuerdo" type="text" class="rnd__input rnd__input--motivo" maxlength="300" />
          </label>
          <button class="rnd__btn" :disabled="guardando" @click="desacuerdo = null">Cancelar</button>
          <button class="rnd__btn rnd__btn--primary" :disabled="guardando || !desacuerdo.trim()"
                  @click="conformar(miAjustada, false, desacuerdo.trim())">Enviar</button>
        </div>
      </div>

      <div v-else class="rnd__box">
        <div>
          <p class="rnd__titulo">Rendir la caja</p>
          <p class="rnd__sub">Entregá lo que cobraste en efectivo. El monto lo pone el sistema.</p>
        </div>
        <div class="rnd__acc">
          <select v-model="receptorId" class="rnd__select">
            <option value="">¿A quién se la das?</option>
            <option v-for="r in receptores" :key="r.id" :value="r.id">{{ r.nombre }}</option>
          </select>
          <button class="rnd__btn rnd__btn--primary" :disabled="!receptorId || guardando" @click="rendir">
            Rendir
          </button>
        </div>
      </div>
    </template>

    <!-- ══ RECEPTOR: contar y recibir ════════════════════════════════════════ -->
    <template v-else>
      <div v-for="r in porRecibir" :key="r.id" class="rnd__box rnd__box--recibir rnd__box--col">
        <!-- Arriba quién y cuánto dice que trae; abajo, en UNA fila alineada por la base, lo que
             hace quien recibe: dónde entra, cuánto contó y (si falta) por qué. -->
        <div class="rnd__head">
          <div>
            <p class="rnd__titulo">{{ r.delivery }} te está rindiendo</p>
            <p class="rnd__sub">{{ r.cobros }} entrega{{ r.cobros === 1 ? '' : 's' }} cobrada{{ r.cobros === 1 ? '' : 's' }} en efectivo</p>
          </div>
          <div class="rnd__declara">
            <span class="rnd__declara-lbl">Declara</span>
            <span class="rnd__declara-n">${{ fmt(r.declarado_ars) }}</span>
          </div>
        </div>

        <div class="rnd__form">
          <!-- DÓNDE ENTRA EL EFECTIVO. El que atiende no elige: cae en la caja de su mostrador,
               que es el cajón que tiene abierto adelante. Administración sí — puede haber varios
               mostradores abiertos, y puede no querer ninguno (se lo lleva y queda asentado como
               ingreso del club). Antes esto se DEDUCÍA de las sedes del que recibía, y con dos
               cajas abiertas la plata no entraba a ninguna. -->
          <label v-if="r.elijo_destino" class="rnd__campo rnd__campo--destino">
            <span class="rnd__campo-lbl">¿En qué caja entra?</span>
            <select v-model="destino[r.id]" class="rnd__select">
              <option value="">Elegí la caja</option>
              <option v-for="c in cajasAbiertas" :key="c.sede_id" :value="String(c.sede_id)">
                Caja de {{ c.sede }}{{ c.abierta_por ? ` — la abrió ${c.abierta_por}` : '' }}
              </option>
              <!-- SÓLO cuando no hay ninguna abierta. Con una caja disponible, el efectivo entra
                   ahí: si después te lo llevás, lo sacás del cajón y queda a tu nombre. Dejarlo
                   como una opción más era ofrecer que la plata no la tuviera nadie. -->
              <option v-if="!cajasAbiertas.length" value="club">
                No hay ninguna caja abierta — queda asentada en la organización
              </option>
            </select>
          </label>
          <!-- Se cuenta primero. Lo declarado ya está a la vista porque no es la medición: es lo
               que la otra persona dice que trae, y contra eso se contrasta. -->
          <label class="rnd__campo rnd__campo--monto">
            <span class="rnd__campo-lbl">Contaste</span>
            <input v-model.number="contado[r.id]" type="number" min="0" step="100"
                   class="rnd__input" placeholder="$" :aria-label="`Contado de ${r.delivery}`" />
          </label>
          <label v-if="falta(r)" class="rnd__campo rnd__campo--motivo">
            <span class="rnd__campo-lbl">Por qué falta</span>
            <input v-model="motivo[r.id]" type="text" class="rnd__input rnd__input--motivo"
                   placeholder="Ej: dio vuelto de más" />
          </label>
          <button class="rnd__btn rnd__btn--primary" :disabled="guardando" @click="recibir(r)">
            Recibir
          </button>
        </div>
        <p v-if="r.elijo_destino && cajasAbiertas.length" class="rnd__destino-hint">
          ¿Te la llevás? Recibila igual en la caja y después sacala del cajón: así queda registrado
          quién la tiene.
        </p>
        <p v-if="falta(r)" class="rnd__falta">
          Faltan ${{ fmt(Math.abs(falta(r))) }} — quedan a cuenta de {{ r.delivery }}, no se dan por perdidos.
        </p>

        <!-- TODO paquete que vuelve SE DESARMA. No se elige: es una decisión de calidad. Uno
             que estuvo en la calle no se guarda armado esperando otro intento — cuando se
             despache de nuevo se arma en el momento, y para entonces puede haber cambiado hasta
             la forma de entrega. Se listan para que el que recibe sepa qué entra. -->
        <div v-if="r.devoluciones?.length" class="rnd__paquetes">
          <p class="rnd__paquetes-lbl">
            Trae {{ r.devoluciones.length }} paquete{{ r.devoluciones.length === 1 ? '' : 's' }} sin entregar
          </p>
          <p v-for="p in r.devoluciones" :key="p.id" class="rnd__paquete">
            <b>{{ fmtCant(p.cantidad) }} {{ p.unidad }}</b> de {{ p.producto }} — {{ p.paciente }}
            <em v-if="p.motivo_fallo">· {{ p.motivo_fallo }}</em>
            <!-- Lo que ya había pagado no se borra: le queda a favor. Quien recibe no decide nada,
                 pero es lo que le va a decir al paciente cuando vuelva. -->
            <span v-if="p.pagado_ars > 0" class="rnd__paquete-favor">
              Había pagado ${{ fmt(p.pagado_ars) }}: le quedan a favor.
            </span>
          </p>
          <p class="rnd__paquetes-hint">
            Se desarman y el producto vuelve al mostrador. Cuando se despache de nuevo, se arma
            en el momento.
            <template v-if="r.devoluciones.some(p => p.pagado_ars > 0)">
              Lo que ya se pagó queda a favor de cada paciente y se le descuenta solo en la
              próxima; si hay que devolverlo, lo hace administración desde su cuenta corriente.
            </template>
          </p>
        </div>
      </div>
    </template>
  </section>
</template>

<script setup>
// `historial` cambia qué muestra: la TARJETA es la acción de ahora (alguien te está rindiendo,
// con el campo para contar); el HISTORIAL es lo que ya pasó. Son la misma información en dos
// momentos distintos y por eso viven en el mismo componente — dos fuentes serían dos verdades.
// La entrega de la recaudación del repartidor, con las dos personas adentro.
//
// La plata NUNCA queda en el aire: es efectivo, el que cuenta es el que la tiene en la mano y ese
// número entra al cajón. No hay estado "en disputa". Si el receptor ajusta, lo que queda es la
// CONFORMIDAD del repartidor — constancia, no candado.
import { ref, computed, onMounted, watch } from 'vue'
import { listRendiciones, receptoresRendicion, crearRendicion, recibirRendicion,
         conformarRendicion, reasignarRendicion } from '../lib/api.js'
import { useAuthStore } from '../stores/auth.js'
import { useToast } from '../composables/useToast.js'

const props = defineProps({
  historial: { type: Boolean, default: false },
  // Sólo en el historial: el mes que se mira ('2026-09'). Las pendientes vienen siempre, arriba.
  mes:       { type: String, default: '' },
  nombreMes: { type: String, default: '' },
})
// Recibir una rendición cambia la MESA: entra la plata al cajón y sube el producto que volvió.
// La tarjeta se recarga sola, pero la pantalla que la contiene no se enteraba — el paquete
// aparecía en el sistema y no en la pantalla del que lo acababa de recibir en la mano.
// `rendida` la escucha la pantalla de Caja del repartidor: al rendir, lo que lleva encima pasa a
// cero y el punto de la solapa tiene que apagarse solo.
const emit = defineEmits(['recibida', 'rendida', 'reasignada'])

const auth  = useAuthStore()
const toast = useToast()

const rendiciones = ref([])
const receptores  = ref([])
const receptorId  = ref('')
const contado     = ref({})
// Dónde entra el efectivo de cada rendición (id de sede, o 'club'). Sólo lo elige administración.
const destino       = ref({})
const cajasAbiertas = ref([])
// Lo que ESTA persona tiene del club: el backend lo calcula para quien pregunta.
const miSaldo     = ref(0)
const motivo      = ref({})
const guardando   = ref(false)
// El «No» de la conformidad: null = cerrado; '' = abierto esperando el motivo.
const desacuerdo  = ref(null)

const soyRepartidor = computed(() => auth.user?.role === 'delivery')
const miPendiente   = computed(() => rendiciones.value.find(r => r.estado === 'pendiente'))
const miAjustada    = computed(() => rendiciones.value.find(r => r.puedo_conformar))
const porRecibir    = computed(() => rendiciones.value.filter(r => r.puedo_recibir))
const visible       = computed(() => {
  if (props.historial) return true
  return soyRepartidor.value
    ? (receptores.value.length > 0 || !!miPendiente.value || !!miAjustada.value || miSaldo.value > 0)
    : porRecibir.value.length > 0
})

const fmt     = (n) => Number(n ?? 0).toLocaleString('es-AR', { maximumFractionDigits: 0 })
const fmtCant = (n) => Number(n ?? 0).toLocaleString('es-AR', { maximumFractionDigits: 1 })
const fecha   = (iso) => (iso ? new Date(iso).toLocaleDateString('es-AR', { day: '2-digit', month: '2-digit' }) : '')
// «31/08 19:00», armado a mano: `toLocaleString` con hora sale «31/8, 07:00 p. m.» según el
// navegador, y en una tabla de plata la hora tiene que leerse igual en todas las filas.
const dos = (n) => String(n).padStart(2, '0')
function fechaHora (iso) {
  if (!iso) return '—'
  const d = new Date(iso)
  return `${dos(d.getDate())}/${dos(d.getMonth() + 1)} ${dos(d.getHours())}:${dos(d.getMinutes())}`
}

// Cuánto lleva esperando una pendiente: es lo que hace saltar que está trabada.
function esperando (iso) {
  if (!iso) return ''
  const dias = Math.floor((Date.now() - new Date(iso).getTime()) / 86400000)
  if (dias < 1) return 'desde hoy'
  return `hace ${dias} día${dias === 1 ? '' : 's'}`
}

function estadoDe (r) {
  if (r.estado === 'pendiente') return { texto: 'Sin recibir', clase: 'rnd__chip--espera' }
  if (r.estado === 'anulada')   return { texto: 'Anulada', clase: 'rnd__chip--neutro' }
  if (r.diferencia_ars)         return { texto: 'Con diferencia', clase: 'rnd__chip--espera' }
  return { texto: 'Recibida', clase: 'rnd__chip--ok' }
}

// A quién se le puede reasignar: los que pueden recibir (lo manda el backend), menos el que ya
// la tiene y el repartidor.
const receptoresHist = ref([])
const reasignarA     = ref({})
const receptoresPara = (r) => receptoresHist.value.filter(p => p.id !== r.receptor_id && p.id !== r.delivery_id)

async function reasignar (r) {
  guardando.value = true
  try {
    await reasignarRendicion(r.id, { receptor_id: reasignarA.value[r.id] })
    const nombre = receptoresHist.value.find(p => p.id === reasignarA.value[r.id])?.nombre
    reasignarA.value[r.id] = ''
    toast.success(`Ahora la recibe ${nombre || 'otra persona'}`)
    await cargar()
    emit('reasignada')
  } catch (e) {
    toast.error(e?.response?.data?.error || 'No se pudo reasignar.')
  } finally { guardando.value = false }
}

// Cuánto falta respecto de lo declarado. nil mientras no haya contado.
function falta (r) {
  const c = contado.value[r.id]
  if (c === null || c === undefined || c === '') return 0
  return Math.min(Number(c) - r.declarado_ars, 0)
}

async function cargar () {
  try {
    const { data } = await listRendiciones(props.historial && props.mes ? { mes: props.mes } : {})
    rendiciones.value  = data.rendiciones || []
    receptoresHist.value = data.receptores || []
    miSaldo.value      = data.mi_saldo_ars || 0
    cajasAbiertas.value = data.cajas_abiertas || []
    // En '' y no sin clave: un `v-model` apuntando a `undefined` no matchea NINGUNA opción, y el
    // desplegable se dibuja VACÍO — sin el "Elegí dónde" que es todo el aviso de que falta
    // contestarlo. Se ve sólo con la pantalla delante.
    rendiciones.value.forEach(r => { if (r.elijo_destino) destino.value[r.id] ??= '' })
  } catch { rendiciones.value = [] }
}

async function rendir () {
  guardando.value = true
  try {
    await crearRendicion({ receptor_id: receptorId.value })
    receptorId.value = ''
    toast.success('Caja rendida')
    await cargar()
    emit('rendida')
  } catch (e) {
    toast.error(e?.response?.data?.error || 'No se pudo rendir la caja.')
  } finally { guardando.value = false }
}

async function recibir (r) {
  const c = contado.value[r.id]
  if (c === null || c === undefined || c === '') return toast.error('Contá la plata antes de recibir.')
  if (falta(r) && !(motivo.value[r.id] || '').trim()) {
    return toast.error('Falta plata: escribí el motivo.')
  }
  if (r.elijo_destino && !destino.value[r.id]) {
    return toast.error('Elegí dónde entra el efectivo.')
  }
  guardando.value = true
  try {
    await recibirRendicion(r.id, {
      monto_recibido_ars: c,
      motivo: motivo.value[r.id] || undefined,
      destino: destino.value[r.id] || undefined,
    })
    toast.success('Caja recibida')
    await cargar()
    emit('recibida')
  } catch (e) {
    toast.error(e?.response?.data?.error || 'No se pudo recibir la caja.')
  } finally { guardando.value = false }
}

async function conformar (r, ok, notas) {
  guardando.value = true
  try {
    await conformarRendicion(r.id, { conforme: ok, notas })
    toast.success(ok ? 'Conformado' : 'Quedó anotado que no estás de acuerdo')
    desacuerdo.value = null
    await cargar()
  } catch (e) {
    toast.error(e?.response?.data?.error || 'No se pudo registrar.')
  } finally { guardando.value = false }
}


// En el historial, cambiar de mes es volver a pedir.
watch(() => props.mes, () => { if (props.historial) cargar() })

onMounted(async () => {
  await cargar()
  if (soyRepartidor.value) {
    try {
      const { data } = await receptoresRendicion()
      receptores.value = data || []
    } catch { receptores.value = [] }
  }
})
</script>

<style scoped>
.rnd { display: flex; flex-direction: column; gap: 10px; margin-bottom: 16px; }

/* ── Historial ─────────────────────────────────────────────────────────────── */
.rnd__saldo {
  margin: 0 0 10px; padding: 11px 14px; border-radius: 10px;
  background: #fef3c7; color: #92400e; font-size: .85rem;
}
.rnd__saldo b { font-variant-numeric: tabular-nums; }
.rnd__vacio { margin: 0; font-size: var(--fs-14); color: var(--c-ink-500); }
.rnd__tabla-wrap {
  background: #fff; border: 1px solid var(--c-slate-200); border-radius: 14px; overflow-x: auto;
}
.rnd__tabla { width: 100%; border-collapse: collapse; }
.rnd__tabla th {
  text-align: left; font-size: var(--fs-12); font-weight: 600; text-transform: uppercase;
  letter-spacing: .04em; color: var(--c-ink-500);
  padding: 13px 16px; border-bottom: 1px solid var(--c-slate-200); white-space: nowrap;
}
.rnd__tabla td { padding: 13px 16px; border-bottom: 1px solid var(--c-slate-100); vertical-align: middle; }
.rnd__tabla tbody tr:last-child td { border-bottom: 0; }
.rnd__th-num, .rnd__td-num { text-align: right; }
.rnd__td-fuerte { font-weight: 600; color: var(--c-ink-900); }
.rnd__td-mut    { font-size: var(--fs-13); color: var(--c-ink-500); }
.rnd__dif { font-family: var(--font-mono); font-weight: 600; color: var(--c-amber-500); }
.rnd__chip {
  display: inline-block; padding: 2px 9px; border-radius: 999px;
  font-size: var(--fs-12); font-weight: 600;
}
.rnd__chip--espera { background: var(--c-amber-100); color: var(--c-amber-500); }
.rnd__chip--ok     { background: var(--c-leaf-100);  color: var(--c-leaf-700); }
.rnd__chip--neutro { background: var(--c-slate-100); color: var(--c-ink-500); }
/* Una pendiente es lo que hay que mirar: va arriba y se distingue sin leer. */
.rnd__fila--pend td { background: color-mix(in srgb, var(--c-amber-100) 45%, transparent); }
.rnd__td-espera { color: var(--c-amber-500); font-weight: 600; }
.rnd__motivo { margin-top: 4px; max-width: 28ch; }
.rnd__reasignar { display: flex; gap: 6px; margin-top: 8px; flex-wrap: wrap; }
.rnd__select--sm { min-width: 150px; padding: 5px 8px; font-size: var(--fs-13); }
.rnd__btn--sm { padding: 5px 10px; font-size: var(--fs-13); }
.rnd__box {
  background: #fff; border: 1px solid var(--c-slate-200); border-left: 3px solid var(--c-leaf-600);
  border-radius: 12px; padding: 14px 16px;
  display: flex; align-items: center; justify-content: space-between; gap: 12px; flex-wrap: wrap;
}
.rnd__box--espera  { border-left-color: var(--c-ink-300); }
.rnd__box--ajuste  { border-left-color: var(--c-amber-500); }
.rnd__box--recibir { border-left-color: var(--c-sky-600); }

.rnd__titulo { margin: 0; font-size: var(--fs-14); font-weight: 700; color: var(--c-ink-900); }
.rnd__sub    { margin: 3px 0 0; font-size: var(--fs-13); color: var(--c-ink-500); }
.rnd__acc    { display: flex; align-items: center; gap: 8px; flex-wrap: wrap; }

.rnd__input, .rnd__select {
  border: 1px solid var(--c-slate-300); border-radius: 9px; padding: 8px 11px;
  font-size: var(--fs-14); background: #fff; color: var(--c-ink-900);
}
.rnd__input { width: 120px; text-align: right; font-family: var(--font-mono); }
.rnd__input--motivo { width: 180px; text-align: left; font-family: var(--font-ui); }
.rnd__select { min-width: 170px; }
.rnd__destino-hint { margin: 0; font-size: var(--fs-12); color: var(--c-slate-500); line-height: 1.35; }

/* Tarjeta de quien recibe: cabecera (quién · cuánto declara) y una fila de campos alineada. */
.rnd__box--col { flex-direction: column; align-items: stretch; gap: 12px; }
.rnd__head { display: flex; justify-content: space-between; align-items: flex-start; gap: 12px; }
.rnd__declara { display: flex; flex-direction: column; align-items: flex-end; flex-shrink: 0; }
.rnd__declara-lbl { font-size: var(--fs-12); font-weight: 600; text-transform: uppercase; letter-spacing: .04em; color: var(--c-ink-500); }
.rnd__declara-n { font-family: var(--font-mono); font-size: 1.25rem; font-weight: 700; color: var(--c-ink-900); font-variant-numeric: tabular-nums; }
.rnd__form { display: flex; align-items: flex-end; gap: 10px; flex-wrap: wrap; }
.rnd__campo { display: flex; flex-direction: column; gap: 4px; min-width: 0; }
.rnd__campo-lbl { font-size: var(--fs-12); font-weight: 600; color: var(--c-slate-600); }
.rnd__campo--destino { flex: 2 1 240px; }
.rnd__campo--monto { flex: 0 0 140px; }
.rnd__campo--motivo { flex: 1 1 200px; }
.rnd__campo .rnd__select, .rnd__campo .rnd__input { width: 100%; min-width: 0; }
.rnd__desacuerdo { flex-basis: 100%; display: flex; align-items: flex-end; gap: 8px; flex-wrap: wrap; }

.rnd__btn {
  border-radius: 9px; padding: 9px 16px; font-size: var(--fs-14); font-weight: 600;
  cursor: pointer; border: 1px solid var(--c-slate-300); background: #fff; color: var(--c-ink-700);
}
.rnd__btn:disabled { opacity: .5; cursor: not-allowed; }
.rnd__btn--primary { background: var(--c-leaf-800); color: #fff; border-color: transparent; }

/* Los paquetes que vuelven */
.rnd__paquetes {
  flex-basis: 100%; margin-top: 4px; padding-top: 10px;
  border-top: 1px solid var(--c-slate-100);
}
.rnd__paquetes-lbl  { margin: 0 0 6px; font-size: var(--fs-13); font-weight: 600; color: var(--c-ink-900); }
.rnd__paquete { margin: 0; padding: 3px 0; font-size: var(--fs-13); color: var(--c-ink-700); }
.rnd__paquete em { font-style: normal; color: var(--c-ink-500); }
.rnd__paquete-favor { display: block; font-size: var(--fs-12, .75rem); color: var(--c-leaf-800); font-weight: 600; }
.rnd__paquetes-hint { margin: 6px 0 0; font-size: var(--fs-12); color: var(--c-ink-500); }

/* No se da por perdida: existe y está con una persona. El texto tiene que decir eso. */
.rnd__falta {
  flex-basis: 100%; margin: 0; font-size: var(--fs-13); color: var(--c-amber-500); font-weight: 600;
}

@media (max-width: 640px) {
  .rnd__box { flex-direction: column; align-items: stretch; }
  .rnd__acc { justify-content: stretch; }
  .rnd__acc .rnd__input, .rnd__acc .rnd__select, .rnd__acc .rnd__btn { flex: 1; }
  .rnd__form { flex-direction: column; align-items: stretch; }
  .rnd__campo--destino, .rnd__campo--monto, .rnd__campo--motivo { flex: none; }
}
</style>
