<template>
  <!-- SIN CERRAR AL TOCAR AFUERA. Acá se cuenta plata y mercadería: un click al costado
       —el que se te va buscando el scroll— borraba todo lo escrito sin preguntar nada, y no hay
       forma de recuperarlo. Se sale por Cancelar o con Escape, que son gestos deliberados. -->
  <div class="cc__back">
    <div class="cc__modal">
      <!-- ES LA FICHA DEL CIERRE, y a veces además se corrige. Titularla siempre «Corregir el
           conteo» le prometía a quien atiende —y a cualquier cierre ya congelado— algo que ahí
           adentro no va a poder hacer. -->
      <h3 class="cc__title">{{ titulo }}</h3>
      <p class="cc__sub">{{ subtitulo }}</p>

      <!-- QUÉ PASÓ, ANTES DE PEDIR NADA. Estas oraciones vivían en la fila de la lista y el modal
           te pedía un número sin contexto. Son el mismo gesto: mirás el cierre y, si algo está
           mal, lo corregís sin cambiar de pantalla. -->
      <div v-if="hechos.length" class="cc__hechos">
        <p v-for="(h, i) in hechos" :key="i" class="cc__hecho" :class="`cc__hecho--${h.tono}`"
           v-html="h.texto"></p>
      </div>

      <p v-if="cargando" class="cc__vacio">Buscando el conteo…</p>

      <!-- POR QUÉ ESTE CIERRE YA NO SE CORRIGE. Se DICE, no se esconde el botón: son tres
           arreglos distintos en tres lugares distintos, y uno de ellos —el visto— tiene llave
           acá mismo. La regla vive en el backend; la pantalla sólo la muestra. -->
      <p v-else-if="bloqueo" class="cc__bloqueo">{{ bloqueo.texto }}</p>

      <template v-else-if="!gestiona">
        <p class="cc__vacio">
          El conteo lo corrige administración. Si contaste mal alguno, avisales: no se borra nada
          — se asienta la diferencia.
        </p>
      </template>

      <template v-else>
        <p v-if="!items.length" class="cc__vacio">Este cierre no tiene productos contados.</p>

        <!-- LAS TRES COLUMNAS, no una sola.
             Antes decía «se había contado 23 g» y un campo: te pedía corregir un número sin
             mostrarte contra qué estaba mal. Sin saber que la mesa decía 46 no hay forma de
             saber qué escribir. -->
        <div v-else class="cc__lista">
          <div class="cc__row cc__row--head">
            <span>Producto</span>
            <span class="cc__col">Tenía que haber</span>
            <span class="cc__col">Se contó</span>
            <span class="cc__col">De verdad había</span>
          </div>
          <div v-for="c in items" :key="c.item_id" class="cc__row">
            <span class="cc__nombre">{{ c.etiqueta }}</span>
            <span class="cc__col cc__num">{{ c.esperado == null ? '—' : fmt(c.esperado) }}</span>
            <span class="cc__col cc__num" :class="{ 'cc__num--dif': difOriginal(c) }">{{ fmt(c.original) }}</span>
            <span class="cc__col cc__cant">
              <input v-model.number="c.contado" type="number" min="0" step="0.1"
                     class="cc__input cc__input--cant" :aria-label="`Lo que de verdad había de ${c.etiqueta}`" />
              <span class="cc__unidad">{{ c.unidad }}</span>
            </span>
          </div>
        </div>

        <!-- LA PLATA TAMBIÉN SE CUENTA MAL. Se dejaba corregir los gramos y el efectivo quedaba
             con el número equivocado para siempre, con su asiento de faltante en el libro. -->
        <div v-if="caja" class="cc__row cc__row--plata">
          <span class="cc__nombre">Plata en la caja</span>
          <span class="cc__col cc__num">{{ pesos(caja.esperado_ars) }}</span>
          <span class="cc__col cc__num" :class="{ 'cc__num--dif': difPlataOriginal }">{{ pesos(caja.contado_ars) }}</span>
          <span class="cc__col cc__cant">
            <input v-model.number="efectivo" type="number" min="0" step="1"
                   class="cc__input cc__input--cant" aria-label="Lo que de verdad había en la caja" />
          </span>
        </div>

        <!-- QUÉ VA A PASAR CON EL INVENTARIO Y CON EL LIBRO, mientras se escribe. Corregir mueve
             stock real y asienta plata: enterarse después de guardar es enterarse tarde. -->
        <p class="cc__efecto" v-html="efecto"></p>

        <label class="cc__campo">
          <span class="cc__campo-lbl">Por qué se corrige</span>
          <input v-model="motivo" type="text" class="cc__input"
                 placeholder="Ej: se cargó 21 en vez de 215" />
        </label>
      </template>

      <div class="cc__acc">
        <!-- SE MIRA, SE MARCA Y SE ARCHIVA: es lo que vacía la lista de trabajo, y desde el
             rediseño de la solapa había quedado SIN BOTÓN — el badge contaba pendientes que no
             se podían sacar de ninguna forma. Va acá, que es donde se mira el cierre. -->
        <button v-if="gestiona && !bloqueo && !visto" class="cc__btn cc__btn--ghost cc__btn--izq"
                :disabled="marcando || cargando" @click="marcarVisto">
          {{ marcando ? 'Guardando…' : 'Ya lo miré' }}
        </button>
        <!-- LA LLAVE. Marcar visto congela la corrección: sin poder reabrir, un clic de más sería
             permanente y nadie se animaría a marcar. -->
        <button v-if="gestiona && bloqueo?.motivo === 'visto'" class="cc__btn cc__btn--ghost cc__btn--izq"
                :disabled="marcando" @click="reabrir">
          {{ marcando ? 'Reabriendo…' : 'Reabrir para revisión' }}
        </button>
        <button class="cc__btn cc__btn--ghost" @click="$emit('cerrar')">
          {{ bloqueo || !gestiona ? 'Cerrar' : 'Cancelar' }}
        </button>
        <button v-if="gestiona && !bloqueo" class="cc__btn cc__btn--primary"
                :disabled="guardando || cargando" @click="confirmar">
          Corregir
        </button>
      </div>
    </div>
  </div>
</template>

<script setup>
// Corregir el conteo de un cierre YA HECHO.
//
// Es el único lugar del módulo donde un dedazo ajusta el inventario real: 21 en vez de 215 cierra
// con un faltante de 194 g que después nadie entiende. Vive en su propio componente porque se
// abre desde dos lados —la solapa de Merma y la lista de turnos— y tener el mismo modal escrito
// dos veces es cómo se empiezan a contradecir.
import { ref, computed, onMounted } from 'vue'
import { useEscape } from '../../composables/useEscape.js'
import { getTurnoMostrador, corregirTurnoMostrador, revisarTurnoMostrador,
         reabrirRevisionTurnoMostrador } from '../../lib/api.js'
import { useToast } from '../../composables/useToast.js'
import { hechosDelCierre } from '../../lib/hechosDelCierre.js'

const props = defineProps({
  sedeId: { type: Number, required: true },
  turno:  { type: Object, required: true },
  // Quien atiende abre esta ficha para MIRAR su cierre; corregir es de administración. Sin esto
  // la pantalla le ofrecía los campos y el botón, y el backend se lo rechazaba con un 403.
  gestiona: { type: Boolean, default: false },
})
const emit = defineEmits(['cerrar', 'corregido', 'revisado'])

useEscape(() => emit('cerrar'))

const toast     = useToast()
const items     = ref([])
const caja      = ref(null)
const efectivo  = ref(null)
const motivo    = ref('')
const cargando  = ref(true)
const guardando = ref(false)
const marcando  = ref(false)
// Por qué no se puede corregir, si es que no se puede. Lo decide el backend —el mismo lugar que
// lo aplica—, así que la pantalla nunca puede ofrecer algo que después va a rebotar.
const bloqueo   = ref(null)
const visto     = ref(false)

const fmt = (n) => Number(n ?? 0).toLocaleString('es-AR', { maximumFractionDigits: 1 })

const titulo = computed(() => (props.gestiona && !bloqueo.value ? 'Corregir el conteo' : 'El cierre'))

// ¿Este renglón ya venía con diferencia? Es lo que hace que la columna «Se contó» se pinte: sin
// eso hay que restar de a ojo entre dos columnas para encontrar cuál es el que está mal.
const difOriginal = (c) => c.esperado != null && Number(c.original) !== Number(c.esperado)

const cambioPlata = computed(() =>
  !!caja.value && efectivo.value != null && Number(efectivo.value) !== Number(caja.value.contado_ars))

// QUÉ VA A PASAR CON EL INVENTARIO, en castellano y mientras se escribe. Corregir un conteo mueve
// stock real: enterarse recién después de guardar es enterarse tarde.
const DIAS  = ['domingo', 'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado']
const MESES = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto',
               'septiembre', 'octubre', 'noviembre', 'diciembre']
const hora = (iso) => (iso ? new Date(iso).toLocaleTimeString('es-AR',
  { hour: '2-digit', minute: '2-digit', hourCycle: 'h23' }) : '')

const subtitulo = computed(() => {
  const t = props.turno
  const c = t.cerrado_at ? new Date(t.cerrado_at) : null
  if (!c) return ''
  const dia = `${DIAS[c.getDay()]} ${c.getDate()} de ${MESES[c.getMonth()]}`
  const a = t.abierto_at ? new Date(t.abierto_at) : null
  const otroDia = a && a.toDateString() !== c.toDateString()
  const quien = (t.atendio && t.cerrado_por && t.atendio !== t.cerrado_por)
    ? `abrió ${t.atendio}, cerró ${t.cerrado_por}`
    : (t.atendio || t.cerrado_por || '')
  // El día que se nombra es el de APERTURA: el título ya dice el del cierre, así que «a las 12:03
  // del sábado» repetía lo de arriba y escondía lo único que faltaba — que abrió el viernes.
  return `${dia.charAt(0).toUpperCase() + dia.slice(1)}, de ${hora(t.abierto_at)}` +
         `${otroDia ? ` del ${DIAS[a.getDay()]}` : ''} a ${hora(t.cerrado_at)}` +
         (quien ? ` · ${quien}` : '')
})

// Las oraciones viven en `lib/hechosDelCierre.js`: las lee también el panel del día del
// calendario, y escritas dos veces un día dirían distinto del mismo cierre.
const hechos = computed(() => hechosDelCierre(props.turno))

const pesos = (n) => n == null ? '—' :
  new Intl.NumberFormat('es-AR', { style: 'currency', currency: 'ARS', maximumFractionDigits: 0 }).format(n)

const difPlataOriginal = computed(() =>
  !!caja.value && Number(caja.value.contado_ars) !== Number(caja.value.esperado_ars))

const efecto = computed(() => {
  let falta = 0, sobra = 0
  for (const c of items.value) {
    if (c.esperado == null) continue
    const d = Number(c.contado) - Number(c.esperado)
    if (d < 0) falta += -d; else sobra += d
  }
  const r = (n) => Math.round(n * 10) / 10
  const partes = []
  if (falta) partes.push(`con estos números <b>faltan ${r(falta)}</b>, que salen del inventario`)
  if (sobra) partes.push(`hay <b>${r(sobra)} de más</b>, que no se cargan: el mostrador descuenta producto, nunca lo suma`)
  // La plata va aparte del producto: son dos arqueos distintos y se explican distinto.
  if (caja.value && efectivo.value != null) {
    const dif = Number(efectivo.value) - Number(caja.value.esperado_ars || 0)
    if (Math.abs(dif) >= 1) {
      partes.push(`en la caja ${dif < 0 ? 'faltan' : 'sobran'} <b>${pesos(Math.abs(dif))}</b>, que se asientan en el libro`)
    }
  }
  if (!partes.length) return 'Con estos números <b>no falta nada</b>: vuelve al inventario lo que se había descontado.'
  return partes.join(' y ') + '.'
})
const fecha = (iso) => (iso ? new Date(iso).toLocaleDateString('es-AR', { day: '2-digit', month: '2-digit' }) : '')

onMounted(async () => {
  try {
    const { data } = await getTurnoMostrador(props.sedeId, props.turno.id)
    // `items` y no `conteo_apertura`: son el mismo array. Y lo que se corrige es el conteo del
    // CIERRE, no el de la apertura — leía `it.contado`, que es lo que se contó al ABRIR.
    items.value = (data.items || data.conteo_apertura || []).map(it => ({
      item_id: it.id, etiqueta: it.etiqueta, unidad: it.unidad,
      esperado: it.esperado_cierre,
      original: it.contado_cierre ?? it.contado,
      contado:  it.contado_cierre ?? it.contado,
    }))
    caja.value = data.caja || null
    efectivo.value = caja.value?.contado_ars ?? null
    aplicar(data)
  } catch (e) {
    toast.error(e?.response?.data?.error || 'No se pudo abrir el turno.')
    emit('cerrar')
  } finally {
    cargando.value = false
  }
})

function aplicar (data) {
  bloqueo.value = data.correccion?.permitida === false ? data.correccion : null
  visto.value   = !!data.revisado
}

// Se marca y se archiva. Congela la corrección —por eso lo de al lado es la llave—, pero el gesto
// tiene que seguir siendo liviano: la lista está para vaciarse.
async function marcarVisto () {
  marcando.value = true
  try {
    await revisarTurnoMostrador(props.sedeId, props.turno.id)
    visto.value = true
    emit('revisado', { id: props.turno.id, revisado: true })
    toast.success('Marcado como visto')
    emit('cerrar')
  } catch (e) {
    toast.error(e?.response?.data?.error || 'No se pudo marcar como visto.')
  } finally {
    marcando.value = false
  }
}

async function reabrir () {
  marcando.value = true
  try {
    const { data } = await reabrirRevisionTurnoMostrador(props.sedeId, props.turno.id)
    aplicar(data)
    emit('revisado', { id: props.turno.id, revisado: false })
    toast.success('Reabierto para revisión')
  } catch (e) {
    toast.error(e?.response?.data?.error || 'No se pudo reabrir el cierre.')
  } finally {
    marcando.value = false
  }
}

async function confirmar () {
  if (!motivo.value.trim()) return toast.error('Escribí por qué se corrige.')

  const cambiados = items.value
    .filter(c => Number(c.contado) !== Number(c.original))
    .map(c => ({ item_id: c.item_id, contado: c.contado }))
  if (!cambiados.length && !cambioPlata.value) return toast.error('No cambiaste ningún número.')

  guardando.value = true
  try {
    await corregirTurnoMostrador(props.sedeId, props.turno.id, {
      conteos: cambiados, motivo: motivo.value,
      ...(cambioPlata.value ? { efectivo_contado_ars: efectivo.value } : {}),
    })
    toast.success('Conteo corregido')
    emit('corregido')
    emit('cerrar')
  } catch (e) {
    toast.error(e?.response?.data?.error || 'No se pudo corregir el conteo.')
  } finally {
    guardando.value = false
  }
}
</script>

<style scoped>
.cc__back {
  position: fixed; inset: 0; background: rgba(15, 42, 30, .45);
  display: flex; align-items: center; justify-content: center; padding: 20px; z-index: 1000;
}
.cc__modal {
  background: #fff; border-radius: 14px; padding: 24px;
  width: 100%; max-width: 560px; max-height: 88vh; overflow-y: auto;
  display: flex; flex-direction: column; gap: 14px;
}
.cc__title {
  font-family: var(--font-display); font-size: var(--fs-16); font-weight: 700;
  color: var(--c-leaf-900); margin: 0;
}
.cc__sub   { margin: 0; font-size: var(--fs-13); color: var(--c-ink-500); }
.cc__vacio { margin: 0; font-size: var(--fs-14); color: var(--c-ink-500); }

/* Qué pasó, antes de pedir nada. La barra de color dice qué clase de hecho es, sin gritar. */
.cc__hechos { display: flex; flex-direction: column; gap: 10px; }
.cc__hecho {
  margin: 0; padding-left: 12px; border-left: 3px solid var(--c-slate-200);
  font-size: var(--fs-14); color: var(--c-ink-700); line-height: 1.5;
}
.cc__hecho :deep(b) { color: var(--c-ink-900); font-weight: 600; }
.cc__hecho :deep(small) { display: block; color: var(--c-ink-500); font-size: var(--fs-13); margin-top: 2px; }
.cc__hecho--warn { border-left-color: var(--c-amber-500, #f59e0b); }
.cc__hecho--ok   { border-left-color: var(--c-leaf-600, #16a34a); }
.cc__row--head {
  font-size: var(--fs-11, .7rem); letter-spacing: .06em; text-transform: uppercase;
  color: var(--c-ink-500); font-weight: 600;
}
.cc__col { text-align: right; }
.cc__num { font-family: var(--font-mono); font-variant-numeric: tabular-nums; font-size: var(--fs-14); color: var(--c-ink-500); }
/* El renglón que no cerró: el que hay que mirar. Ámbar, no rojo — no es culpa de nadie. */
.cc__num--dif { color: var(--c-amber-700, #b45309); font-weight: 700; }
/* La plata, separada del producto por una línea: son dos arqueos distintos. */
.cc__row--plata { border-top: 2px solid var(--c-slate-200); margin-top: 4px; }
.cc__efecto {
  margin: 0; font-size: var(--fs-13); color: var(--c-ink-700);
  background: var(--c-leaf-50, #f0fdf4); border-radius: 9px; padding: 10px 12px;
}
.cc__efecto b { color: var(--c-ink-900); }

.cc__lista { display: flex; flex-direction: column; }
/* Cuatro columnas: producto · lo que tenía que haber · lo que se contó · lo que de verdad había.
   Grid y no flex porque los tres números tienen que alinearse entre filas — es lo que deja
   encontrar de un vistazo el renglón que no cerró. */
.cc__row {
  display: grid; grid-template-columns: minmax(0,1fr) 78px 68px 104px;
  align-items: center; gap: 10px;
  padding: 11px 0; border-top: 1px solid var(--c-slate-100);
}
@media (max-width: 480px) {
  .cc__row { grid-template-columns: minmax(0,1fr) 58px 54px 92px; gap: 6px; }
}
.cc__prod   { flex: 1; min-width: 0; }
.cc__nombre { display: block; font-size: var(--fs-14); font-weight: 600; color: var(--c-ink-900); }
.cc__meta   { display: block; font-size: var(--fs-12); color: var(--c-ink-500); margin-top: 2px; }
.cc__cant   { display: inline-flex; align-items: baseline; gap: 6px; }
.cc__unidad { font-size: var(--fs-13); color: var(--c-ink-500); width: 22px; }

.cc__input {
  border: 1px solid var(--c-slate-300); border-radius: 9px; padding: 9px 11px;
  font-size: var(--fs-14); font-family: var(--font-mono); width: 100%;
  background: #fff; color: var(--c-ink-900);
}
.cc__input:focus { outline: 2px solid var(--c-leaf-300); outline-offset: 1px; border-color: var(--c-leaf-500); }
.cc__input--cant { width: 96px; text-align: right; }

.cc__campo { display: flex; flex-direction: column; gap: 5px; }
.cc__campo-lbl { font-size: var(--fs-13); font-weight: 600; color: var(--c-amber-500); }

.cc__bloqueo {
  margin: 0; font-size: var(--fs-14); color: var(--c-ink-700); line-height: 1.5;
  background: var(--c-slate-50, #f8fafc); border-left: 3px solid var(--c-slate-300);
  border-radius: 0 9px 9px 0; padding: 10px 12px;
}
.cc__acc { display: flex; gap: 10px; justify-content: flex-end; }
/* La acción sobre el cierre —verlo, reabrirlo— vive del otro lado del pie: no es cancelar ni
   confirmar lo que se está escribiendo. */
.cc__btn--izq { margin-right: auto; }
.cc__btn {
  border-radius: 9px; padding: 10px 18px; font-size: var(--fs-14); font-weight: 600;
  cursor: pointer; border: 1px solid transparent;
}
.cc__btn:disabled { opacity: .5; cursor: not-allowed; }
.cc__btn--primary { background: var(--c-leaf-800); color: #fff; }
.cc__btn--ghost   { background: #fff; color: var(--c-ink-700); border-color: var(--c-slate-300); }
</style>
