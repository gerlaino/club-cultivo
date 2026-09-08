<template>
  <div class="cc__back" @click.self="$emit('cerrar')">
    <div class="cc__modal">
      <h3 class="cc__title">Corregir el conteo</h3>
      <p class="cc__sub">
        Cierre del {{ fecha(turno.cerrado_at) }}. Escribí lo que de verdad había: el conteo
        equivocado no se borra, se anota la corrección al lado.
      </p>

      <p v-if="cargando" class="cc__vacio">Buscando el conteo…</p>

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

        <!-- QUÉ VA A PASAR CON EL INVENTARIO, mientras se escribe. Corregir un conteo mueve
             stock real: enterarse después de guardar es enterarse tarde. -->
        <p class="cc__efecto" v-html="efecto"></p>

        <label class="cc__campo">
          <span class="cc__campo-lbl">Por qué se corrige</span>
          <input v-model="motivo" type="text" class="cc__input"
                 placeholder="Ej: se cargó 21 en vez de 215" />
        </label>
      </template>

      <div class="cc__acc">
        <button class="cc__btn cc__btn--ghost" @click="$emit('cerrar')">Cancelar</button>
        <button class="cc__btn cc__btn--primary" :disabled="guardando || cargando" @click="confirmar">
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
import { getTurnoMostrador, corregirTurnoMostrador } from '../../lib/api.js'
import { useToast } from '../../composables/useToast.js'

const props = defineProps({
  sedeId: { type: Number, required: true },
  turno:  { type: Object, required: true },
})
const emit = defineEmits(['cerrar', 'corregido'])

const toast     = useToast()
const items     = ref([])
const motivo    = ref('')
const cargando  = ref(true)
const guardando = ref(false)

const fmt = (n) => Number(n ?? 0).toLocaleString('es-AR', { maximumFractionDigits: 1 })

// ¿Este renglón ya venía con diferencia? Es lo que hace que la columna «Se contó» se pinte: sin
// eso hay que restar de a ojo entre dos columnas para encontrar cuál es el que está mal.
const difOriginal = (c) => c.esperado != null && Number(c.original) !== Number(c.esperado)

// QUÉ VA A PASAR CON EL INVENTARIO, en castellano y mientras se escribe. Corregir un conteo mueve
// stock real: enterarse recién después de guardar es enterarse tarde.
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
  } catch (e) {
    toast.error(e?.response?.data?.error || 'No se pudo abrir el turno.')
    emit('cerrar')
  } finally {
    cargando.value = false
  }
})

async function confirmar () {
  if (!motivo.value.trim()) return toast.error('Escribí por qué se corrige.')

  const cambiados = items.value
    .filter(c => Number(c.contado) !== Number(c.original))
    .map(c => ({ item_id: c.item_id, contado: c.contado }))
  if (!cambiados.length) return toast.error('No cambiaste ningún número.')

  guardando.value = true
  try {
    await corregirTurnoMostrador(props.sedeId, props.turno.id, { conteos: cambiados, motivo: motivo.value })
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
.cc__row--head {
  font-size: var(--fs-11, .7rem); letter-spacing: .06em; text-transform: uppercase;
  color: var(--c-ink-500); font-weight: 600;
}
.cc__col { text-align: right; }
.cc__num { font-family: var(--font-mono); font-variant-numeric: tabular-nums; font-size: var(--fs-14); color: var(--c-ink-500); }
/* El renglón que no cerró: el que hay que mirar. Ámbar, no rojo — no es culpa de nadie. */
.cc__num--dif { color: var(--c-amber-700, #b45309); font-weight: 700; }
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

.cc__acc { display: flex; gap: 10px; justify-content: flex-end; }
.cc__btn {
  border-radius: 9px; padding: 10px 18px; font-size: var(--fs-14); font-weight: 600;
  cursor: pointer; border: 1px solid transparent;
}
.cc__btn:disabled { opacity: .5; cursor: not-allowed; }
.cc__btn--primary { background: var(--c-leaf-800); color: #fff; }
.cc__btn--ghost   { background: #fff; color: var(--c-ink-700); border-color: var(--c-slate-300); }
</style>
