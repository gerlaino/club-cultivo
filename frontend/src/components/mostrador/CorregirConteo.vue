<template>
  <div class="cc__back" @click.self="$emit('cerrar')">
    <div class="cc__modal">
      <h3 class="cc__title">Corregir el conteo</h3>
      <p class="cc__sub">
        Cierre del {{ fecha(turno.cerrado_at) }}. Escribí lo que había de verdad: el movimiento
        equivocado no se borra, se asienta la diferencia.
      </p>

      <p v-if="cargando" class="cc__vacio">Buscando el conteo…</p>

      <template v-else>
        <div class="cc__lista">
          <div v-for="c in items" :key="c.item_id" class="cc__row">
            <div class="cc__prod">
              <span class="cc__nombre">{{ c.etiqueta }}</span>
              <span class="cc__meta">se había contado {{ fmt(c.original) }} {{ c.unidad }}</span>
            </div>
            <div class="cc__cant">
              <input v-model.number="c.contado" type="number" min="0" step="0.1"
                     class="cc__input cc__input--cant" :aria-label="`Contado de ${c.etiqueta}`" />
              <span class="cc__unidad">{{ c.unidad }}</span>
            </div>
          </div>
        </div>

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
import { ref, onMounted } from 'vue'
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
const fecha = (iso) => (iso ? new Date(iso).toLocaleDateString('es-AR', { day: '2-digit', month: '2-digit' }) : '')

onMounted(async () => {
  try {
    const { data } = await getTurnoMostrador(props.sedeId, props.turno.id)
    items.value = (data.items || []).map(it => ({
      item_id: it.id, etiqueta: it.etiqueta, unidad: it.unidad,
      original: it.contado, contado: it.contado,
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

.cc__lista { display: flex; flex-direction: column; }
.cc__row {
  display: flex; align-items: center; gap: 12px;
  padding: 11px 0; border-top: 1px solid var(--c-slate-100);
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
