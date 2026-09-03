<template>
  <section v-if="sede" class="cjm" :class="`cjm--${estado}`">
    <div class="cjm-hd">
      <span class="cjm-title"><i class="bi bi-shop"></i> Mostrador</span>
      <span class="cjm-sede">{{ sede.nombre }}</span>
    </div>

    <p v-if="cargando" class="cjm-msg">Cargando…</p>

    <template v-else>
      <!-- En el teléfono, arriba del buscador de pacientes, el detalle empuja lo que se usa: se
           muestra el estado en un renglón y el detalle está a un toque. -->
      <div v-if="!compacto" class="cjm-nums">
        <div>
          <span class="cjm-n">{{ productos }}</span>
          <span class="cjm-l">producto{{ productos === 1 ? '' : 's' }} sobre la mesa</span>
        </div>
        <template v-if="caja">
          <div>
            <span class="cjm-n">{{ fmtARS(caja.fondo_ars) }}</span><span class="cjm-l">fondo</span>
          </div>
          <div>
            <span class="cjm-n">{{ fmtARS(caja.cobrado_efectivo_ars) }}</span>
            <span class="cjm-l">efectivo cobrado</span>
          </div>
          <div>
            <span class="cjm-n cjm-n--fuerte">{{ fmtARS(caja.esperado_ars) }}</span>
            <span class="cjm-l">esperado en caja</span>
          </div>
        </template>
      </div>

      <p class="cjm-msg">
        <template v-if="turno">
          <strong>{{ turno.abierto_por }}</strong> abrió la caja a las {{ hora(turno.abierto_at) }}.
        </template>
        <template v-else-if="productos">
          La caja está cerrada. Hay mercadería sobre la mesa esperando que alguien abra.
        </template>
        <template v-else>
          La mesa está vacía. Cargala para que se pueda dispensar.
        </template>
      </p>

      <!-- UNA sola puerta. Esta tarjeta muestra cómo viene; contar, abrir, cargar y cerrar pasan
           en el Mostrador, que es donde está el gesto completo. Tener acá un "abrir caja" que
           sólo pide el fondo salteaba el conteo del stock, que es la mitad del arqueo. -->
      <RouterLink class="cjm-link" to="/mostrador">Ir al mostrador →</RouterLink>
    </template>

    <p v-if="error" class="cjm-error">{{ error }}</p>
  </section>
</template>

<script setup>
// EL MOSTRADOR DE UNA SEDE, COMO RESUMEN.
//
// Antes era una segunda implementación del flujo entero —abrir con el fondo, confirmar el fondo,
// enviar el cierre, confirmarlo— viviendo en la ficha de la sede y en dos tableros. Dos puertas
// al mismo hecho es cómo dejan de coincidir, y encima ésta abría la caja **sin contar el stock**:
// declaraba un fondo y listo, salteando la mitad del arqueo.
//
// Ahora informa y manda a Mostrador, que es donde el gesto está completo.
import { ref, computed, watch } from 'vue'
import { RouterLink } from 'vue-router'
import { getMostrador } from '../../lib/api.js'
import { formatARS as fmtARS } from '../../lib/formatters.js'

const props = defineProps({
  sede:     { type: Object, default: null },
  // Quedó de cuando la tarjeta abría y cerraba la caja. Hoy no tiene acciones —todas viven en
  // Mostrador— así que no cambia nada; se acepta para no romper a quien todavía lo pase.
  puedeGestionar: { type: Boolean, default: false },
  compacto: { type: Boolean, default: false },
})

const cargando = ref(true)
const error    = ref('')
const mesa     = ref([])
const turno    = ref(null)

const caja      = computed(() => turno.value?.caja || null)
const productos = computed(() => mesa.value.length)
const estado    = computed(() => (turno.value ? 'abierta' : productos.value ? 'cargado' : 'vacio'))

const hora = (iso) => (iso ? new Date(iso).toLocaleTimeString('es-AR', { hour: '2-digit', minute: '2-digit' }) : '')

async function cargar () {
  if (!props.sede?.id) { cargando.value = false; return }
  cargando.value = true
  error.value = ''
  try {
    const { data } = await getMostrador(props.sede.id)
    mesa.value  = data.mesa || []
    turno.value = data.turno
  } catch (e) {
    error.value = e?.response?.data?.error || 'No se pudo cargar el mostrador.'
  } finally {
    cargando.value = false
  }
}

watch(() => props.sede?.id, cargar, { immediate: true })
defineExpose({ cargar })
</script>

<style scoped>
.cjm {
  background: #fff; border: 1px solid var(--c-slate-200); border-radius: 14px;
  padding: 18px 20px; display: flex; flex-direction: column; gap: 12px;
}
.cjm--abierta { border-left: 3px solid var(--c-leaf-600); }
.cjm--cargado { border-left: 3px solid var(--c-amber-500); }

.cjm-hd    { display: flex; align-items: baseline; justify-content: space-between; gap: 10px; }
.cjm-title { font-size: .95rem; font-weight: 700; color: var(--c-leaf-900); }
.cjm-sede  { font-size: .78rem; color: var(--c-ink-500); }
.cjm-msg   { margin: 0; font-size: .85rem; color: var(--c-ink-700); }
.cjm-error { margin: 0; font-size: .8rem; color: var(--c-rust-600); }

.cjm-nums  { display: flex; gap: 18px; flex-wrap: wrap; }
.cjm-nums > div { display: flex; flex-direction: column; }
.cjm-n     { font-size: 1.05rem; font-weight: 700; font-variant-numeric: tabular-nums; color: var(--c-ink-900); }
.cjm-n--fuerte { color: var(--c-leaf-800); }
.cjm-l     { font-size: .72rem; color: var(--c-ink-500); }

.cjm-link  {
  align-self: flex-start; font-size: .82rem; font-weight: 600;
  color: var(--c-leaf-800); text-decoration: none;
}
.cjm-link:hover { text-decoration: underline; }
</style>
