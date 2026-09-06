<template>
  <div class="mmo">
    <!-- Un repartidor esperando que le reciban la caja: acá es donde está el cajón. -->
    <RendicionCajaCard @recibida="cargar" />

    <!-- ══ SIN SEDE NO HAY MOSTRADOR ═══════════════════════════════════════════
         Va en lugar de la caja, no al lado: ofrecer "Abrir caja" cuando no hay sede donde
         abrirla es dejar apretar para que el backend rechace, y parece culpa suya. Dice quién
         lo arregla, porque no es él. -->
    <section v-if="faltaSede" class="mmo__sinsede">
      <i class="bi bi-exclamation-triangle"></i>
      <div>
        <b>Todavía no podés abrir la caja.</b>
        <p v-if="motivoSinSede === 'asignacion'">
          Las sedes que tenés asignadas no atienden público, así que no hay mostrador al que
          entrar. Pedile a administración que te asigne la sede donde atendés.
        </p>
        <p v-else>
          Esta organización no tiene ninguna sede de atención activa, que es donde vive el
          mostrador. Avisale a administración.
        </p>
      </div>
    </section>

    <!-- ══ LA CAJA ═══════════════════════════════════════════════════════════════
         Lo primero y lo último del día, y por eso va arriba con la acción a ancho
         completo: el que atiende llega, abre contando, y a la noche cierra contando. -->
    <section v-else class="mmo__caja" :class="`is-${estado}`">
      <div class="mmo__caja-txt">
        <span class="mmo__caja-estado">
          <span class="mmo__dot" />{{ turno ? 'Caja abierta' : 'Caja cerrada' }}
        </span>
        <span v-if="turno" class="mmo__caja-pie">
          {{ esMia ? 'Vos' : turno.abierto_por }}, desde las {{ hora(turno.abierto_at) }}
        </span>
        <!-- CUÁNTO DEBERÍA HABER EN EL CAJÓN, a la vista todo el día. Se sabe lo que cuesta —el
             número delante invita a escribir ése en vez de terminar de contar— pero la
             practicidad gana: viendo que faltan $300 se sale a buscar el vuelto mal dado AHORA,
             con la jornada fresca, en vez de descubrirlo mañana cuando ya nadie se acuerda.
             Lo que se anota al arquear sigue siendo lo CONTADO. -->
        <span v-if="turno?.caja" class="mmo__caja-esperado">
          En el cajón tendría que haber <b>${{ pesos(turno.caja.esperado_ars) }}</b>
        </span>
        <span v-else class="mmo__caja-pie">
          {{ mesa.length ? 'Hay mercadería sobre la mesa esperando que abras.' : 'La mesa está vacía.' }}
        </span>
      </div>
      <button class="mmo__btn" @click="conteo = turno ? 'cierre' : 'apertura'">
        {{ turno ? 'Cerrar caja' : 'Abrir caja' }}
      </button>
    </section>

    <select v-if="sedes.length > 1" v-model="sedeId" class="mmo__sede" aria-label="Sede">
      <option v-for="s in sedes" :key="s.id" :value="s.id">{{ s.nombre }}</option>
    </select>

    <!-- Todo lo que sigue necesita una sede: envuelto en un solo `v-if` y no uno por bloque,
         que además rompía el encadenado del `v-else` de las solapas. -->
    <template v-if="!faltaSede">
    <nav class="mmo__tabs">
      <button class="mmo__tab" :class="{ 'is-on': tab === 'hoy' }" @click="tab = 'hoy'">Hoy</button>
      <button class="mmo__tab" :class="{ 'is-on': tab === 'turnos' }" @click="tab = 'turnos'">
        Mis arqueos
      </button>
    </nav>

    <MostradorTurnos v-if="tab === 'turnos'" :sede-id="sedeId" />

    <template v-else>
      <p v-if="turno?.notas_apertura" class="mmo__aviso">
        Al abrir: {{ turno.notas_apertura }}
      </p>

      <!-- Lo que administración tocó mientras la caja estuvo abierta. Se muestra COLAPSADO: hay
           que poder verlo —si no, se cierra con un faltante que no es suyo y no lo puede
           explicar— pero desplegado empuja la mesa hacia abajo, que es lo que se vino a mirar. -->
      <div v-if="movimientosDelTurno.length" class="mmo__movs">
        <button class="mmo__movs-hd" @click="movsAbiertos = !movsAbiertos">
          <span>Administración movió la mesa ({{ movimientosDelTurno.length }})</span>
          <i class="bi" :class="movsAbiertos ? 'bi-chevron-up' : 'bi-chevron-down'"></i>
        </button>
        <p v-for="(m, i) in (movsAbiertos ? movimientosDelTurno : [])" :key="i" class="mmo__mov">
          <b>{{ m.usuario }}</b> {{ m.cantidad > 0 ? 'subió' : 'bajó' }}
          <b>{{ fmt(Math.abs(m.cantidad)) }} {{ m.unidad }}</b>
          de {{ formaLabel(m.forma) }}<template v-if="m.motivo"> — {{ m.motivo }}</template>
          <span class="mmo__mov-hora">{{ hora(m.cuando) }}</span>
        </p>
      </div>

      <div v-if="cargando" class="mmo__skel-wrap">
        <div v-for="n in 4" :key="n" class="mmo__skel" />
      </div>

      <p v-else-if="error" class="mmo__aviso mmo__aviso--error">{{ error }}</p>

      <template v-else>
        <!-- Buscar va en el mismo lugar que en Dispensar, donde su mano ya va: la pregunta que
             más veces contesta por día es "¿tenés de esto?", con el paciente enfrente. -->
        <input v-model.trim="busqueda" type="search" class="mmo__buscar"
               placeholder="Buscar producto, variedad o lote…" aria-label="Buscar" />

        <p v-if="!mesa.length" class="mmo__vacio">
          La mesa está vacía. La carga administración: pedile lo que necesites.
        </p>
        <p v-else-if="!visibles.length" class="mmo__vacio">Nada coincide con «{{ busqueda }}».</p>

        <div v-else class="mmo__list">
          <!-- Una línea útil por producto: qué es y cuánto hay. El resto —lote, elaborado,
               precio, depósito— está a un toque, en la hoja: parado con alguien enfrente, siete
               renglones por frasco son cien renglones de scroll para contestar una pregunta. -->
          <button v-for="s in visibles" :key="s.stock_id" class="mmo__card" @click="detalle = s">
            <span class="mmo__card-main">
              <span class="mmo__card-prod">{{ formaLabel(s.forma) }}</span>
              <span class="mmo__card-meta">{{ s.genetica || 'Sin variedad' }} · {{ s.numero }}</span>
            </span>
            <span class="mmo__card-cant">
              <b>{{ fmt(s.mostrador) }}</b><small>{{ s.unidad }}</small>
            </span>
            <i class="bi bi-chevron-right mmo__card-arr"></i>
          </button>
        </div>
      </template>
    </template>

    </template>

    <!-- ══ La hoja del producto: el resto de los datos, y contarlo ══════════════ -->
    <SheetBottom v-model="hojaAbierta" :title="detalle ? formaLabel(detalle.forma) : ''">
      <div v-if="detalle" class="mmo__sheet">
        <div class="mmo__datos">
          <div class="mmo__dato">
            <span class="mmo__dato-lbl">Sobre la mesa</span>
            <span class="mmo__dato-val">{{ fmt(detalle.mostrador) }} {{ detalle.unidad }}</span>
          </div>
          <div class="mmo__dato">
            <span class="mmo__dato-lbl">Variedad</span>
            <span class="mmo__dato-val">{{ detalle.genetica || '—' }}</span>
          </div>
          <div class="mmo__dato">
            <span class="mmo__dato-lbl">Precio</span>
            <span class="mmo__dato-val">{{ detalle.precio_ars ? `$${pesos(detalle.precio_ars)}` : '—' }}</span>
          </div>
          <div class="mmo__dato">
            <span class="mmo__dato-lbl">Lote</span>
            <span class="mmo__dato-val">{{ detalle.lote || '—' }}</span>
          </div>
          <div class="mmo__dato">
            <span class="mmo__dato-lbl">Elaborado</span>
            <span class="mmo__dato-val">{{ fecha(detalle.fecha) }}</span>
          </div>
          <!-- El depósito NO se le tapa: ya lo ve en su pantalla de Stock con más columnas, y
               esconderlo en un lado y dejarlo en el otro sería teatro. -->
          <div class="mmo__dato">
            <span class="mmo__dato-lbl">En el depósito</span>
            <span class="mmo__dato-val">{{ fmt(detalle.disponible) }} {{ detalle.unidad }}</span>
          </div>
        </div>

        <!-- Contar ESTE frasco sin cerrar la caja: con quince productos, el arqueo entero para
             verificar uno son veinte minutos, y el control que cuesta eso no se hace. Con la
             caja cerrada el gesto es abrir, que ya cuenta todo. -->
        <button v-if="turno" class="mmo__btn" @click="contarEste">
          Contar {{ formaLabel(detalle.forma).toLowerCase() }}
        </button>
        <p v-else class="mmo__sheet-nota">
          Para contar un producto suelto hay que tener la caja abierta.
        </p>
      </div>
    </SheetBottom>

    <ModalContarItem v-if="itemAContar" :item="itemAContar" :guardando="guardando"
                     @cerrar="itemAContar = null" @confirmar="onConfirmarConteoDeUno" />

    <ModalConteo v-if="conteo" :mesa="mesa" :es-cierre="conteo === 'cierre'"
                 :esperado-efectivo="esperadoEfectivo" :otros-ingresos-efectivo="otrosIngresosEfectivo"
                 :puede-retirar="false" :gestiona="false" :guardando="guardando"
                 :fondo-obligatorio="conteo === 'apertura' && fondoSugerido == null"
                 @cerrar="conteo = null" @confirmar="onConfirmarConteo" />
  </div>
</template>

<script setup>
// EL MOSTRADOR EN EL TELÉFONO, para QUIEN ATIENDE.
//
// Es una pantalla de CONSULTA y de ARQUEO, no de operación: acá mira cómo está la caja, busca si
// tiene tal producto porque el paciente preguntó, y cuenta —al abrir, al cerrar, o un frasco
// suelto—. Dispensar sigue por su flujo de siempre, en Dispensar.
//
// No es la de escritorio apretada. Esa está hecha para administración, que gobierna la mesa
// sentada: siete campos por producto, que en el teléfono se apilan en una tarjeta de siete
// renglones. Con quince frascos son cien renglones de scroll para contestar "¿tenés Northern?",
// que es la pregunta que más veces se contesta por día, de pie y con alguien enfrente.
//
// EL ESTADO ES EL MISMO (`useMostrador`), compartido con la de escritorio: son la misma mesa y
// la misma caja. Lo único que cambia acá es cómo se muestra — si la regla viviera dos veces, un
// día las dos pantallas dirían distinto de la misma mesa.
//
// LO ESPERADO SE MUESTRA — los gramos y el efectivo, acá y en los modales de conteo (sep-2026,
// decisión de Germán, que conoce la operación real). Antes se escondía hasta que el conteo
// estuviera escrito, para que nadie escribiera el número que tenía delante en vez de terminar de
// contar. Ese riesgo existe y no desapareció; lo que pesó más es que una diferencia vista EN EL
// MOMENTO se sale a buscar —el vuelto mal dado, el frasco que quedó en el depósito— y una
// descubierta al día siguiente ya no la puede explicar nadie. Lo que se anota sigue siendo lo
// CONTADO, la diferencia queda con su nombre, y no frena el cierre.
import { ref, computed } from 'vue'
import RendicionCajaCard from '../../components/RendicionCajaCard.vue'
import MostradorTurnos from '../../components/mostrador/MostradorTurnos.vue'
import ModalContarItem from '../../components/mostrador/ModalContarItem.vue'
import ModalConteo from '../../components/mostrador/ModalConteo.vue'
import SheetBottom from '../../components/cultivador/SheetBottom.vue'
import { formaLabel } from '../../lib/formatters.js'
import { useAuthStore } from '../../stores/auth.js'
import { useMostrador } from '../../composables/useMostrador.js'

const auth = useAuthStore()
const {
  sedeId, sedes, faltaSede, motivoSinSede, cargando, guardando, error, turno, mesa, estado,
  fondoSugerido, esperadoEfectivo, otrosIngresosEfectivo, movimientosDelTurno,
  cargar, confirmarConteo, confirmarConteoDeUno,
} = useMostrador()

const tab          = ref('hoy')
const busqueda     = ref('')
const detalle      = ref(null)
const conteo       = ref(null)   // 'apertura' | 'cierre'
const itemAContar  = ref(null)
const movsAbiertos = ref(false)

// La hoja se cierra con el gesto de arrastrar, que sólo sabe de un booleano: sin esto, cerrarla
// dejaba `detalle` puesto y el próximo toque abría la anterior por un instante.
const hojaAbierta = computed({
  get: () => !!detalle.value,
  set: (v) => { if (!v) detalle.value = null },
})

const esMia = computed(() => turno.value?.abierto_por_id === auth.user?.id)

// Ordenado por producto y variedad, que es como se busca cuando alguien pregunta. Dentro del
// mismo producto, lo más viejo arriba: es lo que sale primero.
const visibles = computed(() => {
  const q = busqueda.value.toLowerCase()
  return mesa.value
    .filter(s => !q || [formaLabel(s.forma), s.genetica, s.lote, s.numero]
      .some(v => String(v || '').toLowerCase().includes(q)))
    .slice()
    .sort((a, b) =>
      formaLabel(a.forma).localeCompare(formaLabel(b.forma)) ||
      String(a.genetica || '').localeCompare(String(b.genetica || '')) ||
      String(a.fecha || '').localeCompare(String(b.fecha || '')))
})

const fmt   = (n) => Number(n ?? 0).toLocaleString('es-AR', { maximumFractionDigits: 1 })
const pesos = (n) => Math.round(Number(n ?? 0)).toLocaleString('es-AR')
const hora  = (iso) => (iso ? new Date(iso).toLocaleTimeString('es-AR', { hour: '2-digit', minute: '2-digit', hourCycle: 'h23' }) : '')
const fecha = (f) => (f ? new Date(`${f}T12:00:00`).toLocaleDateString('es-AR', { day: '2-digit', month: '2-digit', year: '2-digit' }) : '—')

// Se cierra la hoja ANTES de abrir el modal: dos capas encimadas en un teléfono dejan al de
// atrás asomando por los costados y el gesto de arrastrar cierra la que no es.
function contarEste () {
  itemAContar.value = detalle.value
  detalle.value = null
}

async function onConfirmarConteo (payload) {
  if (await confirmarConteo(payload, { esCierre: conteo.value === 'cierre' })) conteo.value = null
}

async function onConfirmarConteoDeUno (payload) {
  if (await confirmarConteoDeUno(payload)) itemAContar.value = null
}
</script>

<style scoped>
.mmo { padding: .75rem; display: flex; flex-direction: column; gap: .75rem; }

/* ── La caja ── */
.mmo__caja {
  display: flex; flex-direction: column; gap: .7rem;
  background: #fff; border: 1px solid var(--c-slate-200); border-radius: 14px;
  padding: .9rem;
}
.mmo__caja.is-abierto { border-color: var(--c-leaf-600); }
.mmo__caja-txt { display: flex; flex-direction: column; gap: 2px; }
.mmo__caja-estado {
  display: flex; align-items: center; gap: .45rem;
  font-weight: 700; font-size: 1.05rem; color: var(--c-ink-900);
}
.mmo__dot {
  width: 9px; height: 9px; border-radius: 50%; background: var(--c-slate-300);
}
.mmo__caja.is-abierto .mmo__dot { background: var(--c-leaf-600); }
.mmo__caja-pie { font-size: .82rem; color: var(--c-slate-500); }
/* En segundo plano: es referencia, no el número que se va a escribir. */
.mmo__caja-esperado { font-size: .82rem; color: var(--c-slate-500); margin-top: 2px; }
.mmo__caja-esperado b { color: var(--c-ink-900); font-variant-numeric: tabular-nums; }

.mmo__btn {
  width: 100%; border: 0; border-radius: 12px; padding: .85rem;
  background: var(--c-leaf-600); color: #fff;
  font-size: 1rem; font-weight: 600; cursor: pointer; font-family: inherit;
}
.mmo__btn:active { filter: brightness(.94); }

.mmo__sede {
  width: 100%; border: 1px solid var(--c-slate-200); border-radius: 12px;
  padding: .7rem .8rem; font-size: .95rem; background: #fff; font-family: inherit;
}

/* Ámbar, no rojo: falta un dato de configuración, no se rompió nada ni hizo nada mal. */
.mmo__sinsede {
  display: flex; gap: .7rem; align-items: flex-start;
  background: var(--c-amber-100); color: var(--c-amber-500);
  border-radius: 14px; padding: .9rem;
}
.mmo__sinsede b { display: block; margin-bottom: 2px; font-size: .95rem; }
.mmo__sinsede p { margin: 0; font-size: .85rem; line-height: 1.4; }

/* ── Tabs ── */
.mmo__tabs { display: flex; gap: .4rem; }
.mmo__tab {
  flex: 1; border: 1px solid var(--c-slate-200); background: #fff; border-radius: 10px;
  padding: .55rem; font-size: .88rem; color: var(--c-slate-600);
  cursor: pointer; font-family: inherit;
}
.mmo__tab.is-on {
  background: var(--c-ink-900); border-color: var(--c-ink-900); color: #fff;
  font-weight: 600;
}

/* ── Avisos y movimientos ── */
.mmo__aviso {
  margin: 0; background: var(--c-amber-100); color: var(--c-amber-500);
  border-radius: 10px; padding: .65rem .8rem; font-size: .85rem;
}
.mmo__aviso--error { background: var(--c-rust-100); color: var(--c-rust-600); }

.mmo__movs {
  background: #fff; border: 1px solid var(--c-slate-200); border-radius: 12px; overflow: hidden;
}
.mmo__movs-hd {
  display: flex; align-items: center; justify-content: space-between; width: 100%;
  border: 0; background: transparent; padding: .7rem .8rem;
  font-size: .85rem; font-weight: 600; color: var(--c-ink-900);
  cursor: pointer; font-family: inherit;
}
.mmo__mov {
  margin: 0; padding: .55rem .8rem; font-size: .82rem; color: var(--c-slate-600);
  border-top: 1px solid var(--c-slate-100);
}
.mmo__mov-hora { color: var(--c-slate-400); margin-left: .35rem; }

/* ── Buscador y lista ── */
.mmo__buscar {
  width: 100%; border: 1px solid var(--c-slate-200); border-radius: 12px;
  padding: .75rem .9rem; font-size: 1rem; box-sizing: border-box; font-family: inherit;
}
.mmo__buscar:focus { outline: none; border-color: var(--c-leaf-600); }

.mmo__vacio {
  text-align: center; padding: 2rem 1rem; color: var(--c-slate-500); font-size: .88rem; margin: 0;
}

.mmo__list { display: flex; flex-direction: column; gap: .4rem; }
.mmo__card {
  display: flex; align-items: center; gap: .6rem; width: 100%;
  background: #fff; border: 1px solid var(--c-slate-100); border-radius: 12px;
  padding: .8rem .9rem; text-align: left; cursor: pointer; font: inherit;
}
.mmo__card:active { background: var(--c-slate-50); }
.mmo__card-main { flex: 1; min-width: 0; display: flex; flex-direction: column; }
.mmo__card-prod { font-weight: 600; color: var(--c-ink-900); }
.mmo__card-meta {
  font-size: .75rem; color: var(--c-slate-400); margin-top: 2px;
  overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
}
/* El número es lo que se vino a leer: grande, tabular y con la unidad pegada. */
.mmo__card-cant { display: flex; align-items: baseline; gap: 2px; white-space: nowrap; }
.mmo__card-cant b {
  font-size: 1.15rem; font-weight: 700; color: var(--c-ink-900);
  font-variant-numeric: tabular-nums;
}
.mmo__card-cant small { font-size: .75rem; color: var(--c-slate-400); }
.mmo__card-arr { color: var(--c-slate-300); }

/* ── La hoja del producto ── */
.mmo__sheet { display: flex; flex-direction: column; gap: 1rem; padding-bottom: .5rem; }
.mmo__datos { display: flex; flex-direction: column; }
.mmo__dato {
  display: flex; justify-content: space-between; gap: 1rem; padding: .55rem 0;
  border-bottom: 1px solid var(--c-slate-100); font-size: .88rem;
}
.mmo__dato-lbl { color: var(--c-slate-500); }
.mmo__dato-val { font-weight: 600; color: var(--c-ink-900); text-align: right; }
.mmo__sheet-nota { margin: 0; font-size: .82rem; color: var(--c-slate-500); text-align: center; }

/* ── Esqueleto ── */
.mmo__skel-wrap { display: flex; flex-direction: column; gap: .4rem; }
.mmo__skel {
  height: 60px; border-radius: 12px; background: var(--c-slate-100);
  animation: mmo-pulse 1.2s ease-in-out infinite;
}
@keyframes mmo-pulse { 50% { opacity: .5; } }
</style>
