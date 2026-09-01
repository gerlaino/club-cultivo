<template>
  <section v-if="visible" class="rnd">
    <!-- ══ HISTORIAL: lo que ya pasó ═════════════════════════════════════════ -->
    <template v-if="historial">
      <p v-if="!cerradas.length" class="rnd__vacio">Todavía no se rindió ninguna caja.</p>
      <div v-else class="rnd__tabla-wrap">
        <table class="rnd__tabla tabla-cards">
          <thead>
            <tr>
              <th>Repartidor</th>
              <th>Recibió</th>
              <th class="rnd__th-num">Cobró</th>
              <th class="rnd__th-num">Entregó</th>
              <th class="rnd__th-num">Diferencia</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="r in cerradas" :key="r.id">
              <td data-col="Repartidor">
                <div class="rnd__td-fuerte">{{ r.delivery }}</div>
                <div class="rnd__td-mut">{{ fecha(r.recibida_at) }}</div>
              </td>
              <td data-col="Recibió">{{ r.receptor }}</td>
              <td class="rnd__td-num rnd__td-mut" data-col="Cobró">${{ fmt(r.declarado_ars) }}</td>
              <td class="rnd__td-num rnd__td-fuerte" data-col="Entregó">${{ fmt(r.recibido_ars) }}</td>
              <td class="rnd__td-num" data-col="Diferencia">
                <span v-if="r.diferencia_ars" class="rnd__dif">−${{ fmt(Math.abs(r.diferencia_ars)) }}</span>
                <span v-else class="rnd__td-mut">—</span>
              </td>
              <td data-col="">
                <!-- La conformidad es constancia, no candado: la plata entró igual. -->
                <span v-if="r.conforme === false" class="rnd__chip rnd__chip--espera">Sin conformar</span>
                <span v-else-if="r.conforme === true" class="rnd__chip rnd__chip--ok">Conformada</span>
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
        Tenés <b>${{ fmt(miSaldo) }}</b> del club de rendiciones anteriores. Se descuenta cuando
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
          <button class="rnd__btn" :disabled="guardando" @click="noConforme(miAjustada)">No</button>
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
      <div v-for="r in porRecibir" :key="r.id" class="rnd__box rnd__box--recibir">
        <div>
          <p class="rnd__titulo">{{ r.delivery }} te está rindiendo</p>
          <p class="rnd__sub">
            {{ r.cobros }} entrega{{ r.cobros === 1 ? '' : 's' }} · declara ${{ fmt(r.declarado_ars) }}
          </p>
        </div>
        <div class="rnd__acc">
          <!-- Se cuenta primero. Lo declarado ya está a la vista porque no es la medición: es lo
               que la otra persona dice que trae, y contra eso se contrasta. -->
          <input v-model.number="contado[r.id]" type="number" min="0" step="100"
                 class="rnd__input" placeholder="Cuento" :aria-label="`Contado de ${r.delivery}`" />
          <input v-if="falta(r)" v-model="motivo[r.id]" type="text" class="rnd__input rnd__input--motivo"
                 placeholder="Por qué falta" />
          <button class="rnd__btn rnd__btn--primary" :disabled="guardando" @click="recibir(r)">
            Recibir
          </button>
        </div>
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
          </p>
          <p class="rnd__paquetes-hint">
            Se desarman y el producto vuelve al mostrador. Cuando se despache de nuevo, se arma
            en el momento.
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
import { ref, computed, onMounted } from 'vue'
import { listRendiciones, receptoresRendicion, crearRendicion, recibirRendicion,
         conformarRendicion } from '../lib/api.js'
import { useAuthStore } from '../stores/auth.js'
import { useToast } from '../composables/useToast.js'

const props = defineProps({ historial: { type: Boolean, default: false } })
// Recibir una rendición cambia la MESA: entra la plata al cajón y sube el producto que volvió.
// La tarjeta se recarga sola, pero la pantalla que la contiene no se enteraba — el paquete
// aparecía en el sistema y no en la pantalla del que lo acababa de recibir en la mano.
const emit = defineEmits(['recibida'])

const auth  = useAuthStore()
const toast = useToast()

const rendiciones = ref([])
const receptores  = ref([])
const receptorId  = ref('')
const contado     = ref({})
// Lo que ESTA persona tiene del club: el backend lo calcula para quien pregunta.
const miSaldo     = ref(0)
const motivo      = ref({})
const guardando   = ref(false)

const soyRepartidor = computed(() => auth.user?.role === 'delivery')
const miPendiente   = computed(() => rendiciones.value.find(r => r.estado === 'pendiente'))
const miAjustada    = computed(() => rendiciones.value.find(r => r.puedo_conformar))
const porRecibir    = computed(() => rendiciones.value.filter(r => r.puedo_recibir))
const cerradas      = computed(() => rendiciones.value.filter(r => r.estado === 'recibida'))
const visible       = computed(() => {
  if (props.historial) return true
  return soyRepartidor.value
    ? (receptores.value.length > 0 || !!miPendiente.value || !!miAjustada.value || miSaldo.value > 0)
    : porRecibir.value.length > 0
})

const fmt     = (n) => Number(n ?? 0).toLocaleString('es-AR', { maximumFractionDigits: 0 })
const fmtCant = (n) => Number(n ?? 0).toLocaleString('es-AR', { maximumFractionDigits: 1 })
const fecha   = (iso) => (iso ? new Date(iso).toLocaleDateString('es-AR', { day: '2-digit', month: '2-digit' }) : '')

// Cuánto falta respecto de lo declarado. nil mientras no haya contado.
function falta (r) {
  const c = contado.value[r.id]
  if (c === null || c === undefined || c === '') return 0
  return Math.min(Number(c) - r.declarado_ars, 0)
}

async function cargar () {
  try {
    const { data } = await listRendiciones()
    rendiciones.value = data.rendiciones || []
    miSaldo.value     = data.mi_saldo_ars || 0
  } catch { rendiciones.value = [] }
}

async function rendir () {
  guardando.value = true
  try {
    await crearRendicion({ receptor_id: receptorId.value })
    receptorId.value = ''
    toast.success('Caja rendida')
    await cargar()
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
  guardando.value = true
  try {
    await recibirRendicion(r.id, {
      monto_recibido_ars: c,
      motivo: motivo.value[r.id] || undefined,
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
    await cargar()
  } catch (e) {
    toast.error(e?.response?.data?.error || 'No se pudo registrar.')
  } finally { guardando.value = false }
}

// No estar de acuerdo NO devuelve la plata ni reabre nada: queda escrito y se habla.
function noConforme (r) {
  const notas = window.prompt('¿Qué pasó? Queda anotado para que lo vea administración.')
  if (notas === null) return
  conformar(r, false, notas)
}

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
.rnd__paquetes-hint { margin: 6px 0 0; font-size: var(--fs-12); color: var(--c-ink-500); }

/* No se da por perdida: existe y está con una persona. El texto tiene que decir eso. */
.rnd__falta {
  flex-basis: 100%; margin: 0; font-size: var(--fs-13); color: var(--c-amber-500); font-weight: 600;
}

@media (max-width: 640px) {
  .rnd__box { flex-direction: column; align-items: stretch; }
  .rnd__acc { justify-content: stretch; }
  .rnd__input, .rnd__select, .rnd__btn { flex: 1; }
}
</style>
