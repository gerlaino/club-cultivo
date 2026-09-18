<script setup>
// A dónde va el paquete: las direcciones del paciente CON EL TEXTO, y «otra». El que dispensa
// tiene que ver a dónde va antes de confirmar; un botón que dice «domicilio» y manda a otro
// lado es cómo un paquete termina en la dirección equivocada (socio de Germán, sep-2026).
//
// Vive en su componente porque lo usan DOS modales —dispensar/reservar y editar una dispensa
// para mandarla por delivery— y la misma regla en dos lugares es lo que se nos viene rompiendo.
// Los campos son los del `form` del padre (`direccion_origen`, `envio_*`, `envio_etiqueta`,
// `guardar_como_envio`), que es el objeto que después arma el payload: se reciben por
// `modelValue` y cada cambio sale como un PARCHE (`update:modelValue` con sólo la clave que
// cambió) para que el padre lo asigne encima — sin copiar el form entero por cada tecla.
//
// Se piden al montar (el padre lo monta recién al prender «con envío»). Por defecto la de envío
// si la tiene —es para eso que la cargó—, si no el domicilio, y si no tiene ninguna, «otra».
import { ref, computed, onMounted } from 'vue'
import { getDireccionesPaciente } from '../../lib/api.js'

const props = defineProps({
  modelValue: { type: Object, required: true },
  socioId:    { type: Number, required: true },
})
const emit = defineEmits(['update:modelValue'])
const form = computed(() => props.modelValue)
const set  = (clave, valor) => emit('update:modelValue', { [clave]: valor })

const direcciones = ref(null)          // { domicilio: {...}|null, guardadas: [...] }
const cargando    = ref(false)

// Por defecto: la guardada marcada como tal (es para eso que existe); si no hay guardadas, el
// domicilio; y sin nada, «otra».
async function cargar() {
  cargando.value = true
  try {
    const { data } = await getDireccionesPaciente(props.socioId)
    direcciones.value = { domicilio: null, guardadas: [], ...(data || {}) }
    const d = direcciones.value
    const def = (d.guardadas || []).find(g => g.por_defecto) || (d.guardadas || [])[0]
    set('direccion_origen', def ? String(def.id) : (d.domicilio ? 'domicilio' : 'otra'))
  } catch {
    // Sin respuesta no se sabe qué tiene cargado: se dejan elegibles las dos de la ficha y el
    // backend decide. Marcarlas como "no cargadas" por un request que no salió sería mentir.
    direcciones.value = null
  } finally {
    cargando.value = false
  }
}
onMounted(cargar)

const opciones = computed(() => {
  const d = direcciones.value
  const sinDatos = d === null   // no se pudieron consultar: no se marca nada como faltante
  const guardadas = (d?.guardadas || []).map(g => ({
    origen: String(g.id), label: g.etiqueta || 'Dirección de entrega', icono: 'bi-box-seam', texto: g.texto,
    disponible: true, porDefecto: g.por_defecto,
  }))
  return [
    { origen: 'domicilio', label: 'Domicilio REPROCANN', icono: 'bi-house', texto: d?.domicilio?.texto, disponible: sinDatos || !!d?.domicilio },
    ...guardadas,
    { origen: 'otra',      label: 'Otra dirección',      icono: 'bi-geo-alt', texto: null, disponible: true },
  ]
})

// Lo que el backend va a rechazar, dicho antes: null si está bien, o el motivo.
function validar() {
  const f = props.modelValue
  if (f.direccion_origen === 'otra') {
    if (!f.envio_calle?.trim() || !f.envio_altura?.trim() || !f.envio_ciudad?.trim()) {
      return 'Completá calle, altura y ciudad de la dirección de entrega'
    }
    return null
  }
  if (direcciones.value) {
    const existe = f.direccion_origen === 'domicilio'
      ? !!direcciones.value.domicilio
      : (direcciones.value.guardadas || []).some(g => String(g.id) === String(f.direccion_origen))
    if (!existe) return 'El paciente no tiene cargada esa dirección. Cargala en su ficha o elegí «Otra dirección».'
  }
  return null
}

defineExpose({ validar, direcciones })
</script>

<template>
  <div class="sde">
    <div class="sde__field">
      <label class="sde__label">Dirección de entrega</label>
      <div v-if="cargando && !direcciones" class="sde__hint">Buscando las direcciones del paciente…</div>
      <div v-else class="sde__dirs">
        <button v-for="o in opciones" :key="o.origen" type="button"
                class="sde__dir" :class="{ 'sde__dir--on': form.direccion_origen === o.origen, 'sde__dir--off': !o.disponible }"
                :disabled="!o.disponible" @click="set('direccion_origen', o.origen)">
          <i class="bi" :class="o.icono"></i>
          <span class="sde__dir-txt">
            <span class="sde__dir-label">{{ o.label }} <span v-if="o.porDefecto" class="sde__def">por defecto</span></span>
            <span v-if="o.texto" class="sde__dir-dir">{{ o.texto }}</span>
            <span v-else-if="o.origen !== 'otra' && !direcciones" class="sde__dir-dir sde__dir-dir--falta">No se pudo consultar la ficha</span>
            <span v-else-if="o.origen !== 'otra'" class="sde__dir-dir sde__dir-dir--falta">No está cargada en la ficha</span>
            <span v-else class="sde__dir-dir">Escribirla ahora</span>
          </span>
        </button>
      </div>
    </div>

    <template v-if="form.direccion_origen === 'otra'">
      <div class="sde__row">
        <div class="sde__field" style="flex:2">
          <label class="sde__label">Calle <span class="sde__req">*</span></label>
          <input :value="form.envio_calle" type="text" class="sde__input" placeholder="Av. Siempreviva" @input="set('envio_calle', $event.target.value.trim())" />
        </div>
        <div class="sde__field">
          <label class="sde__label">Altura <span class="sde__req">*</span></label>
          <input :value="form.envio_altura" type="text" class="sde__input" placeholder="742" @input="set('envio_altura', $event.target.value.trim())" />
        </div>
      </div>
      <div class="sde__row">
        <div class="sde__field">
          <label class="sde__label">Piso <span class="sde__opt">opc.</span></label>
          <input :value="form.envio_piso" type="text" class="sde__input" placeholder="3" @input="set('envio_piso', $event.target.value.trim())" />
        </div>
        <div class="sde__field">
          <label class="sde__label">Depto <span class="sde__opt">opc.</span></label>
          <input :value="form.envio_depto" type="text" class="sde__input" placeholder="B" @input="set('envio_depto', $event.target.value.trim())" />
        </div>
      </div>
      <div class="sde__row">
        <div class="sde__field">
          <label class="sde__label">Barrio <span class="sde__opt">opc.</span></label>
          <input :value="form.envio_barrio" type="text" class="sde__input" placeholder="Palermo" @input="set('envio_barrio', $event.target.value.trim())" />
        </div>
        <div class="sde__field">
          <label class="sde__label">Ciudad <span class="sde__req">*</span></label>
          <input :value="form.envio_ciudad" type="text" class="sde__input" placeholder="CABA" @input="set('envio_ciudad', $event.target.value.trim())" />
        </div>
      </div>
      <!-- Para no tipearla de nuevo la próxima vez: queda en la ficha como dirección de envío,
           con nombre. El repartidor lo lee en el paquete: «Trabajo · Directorio 1602». -->
      <div class="sde__row">
        <div class="sde__field" style="flex:2">
          <label class="sde__label">Nombre de la dirección <span class="sde__opt">ej. Trabajo</span></label>
          <input :value="form.envio_etiqueta" type="text" class="sde__input" placeholder="Trabajo, casa de la madre…" @input="set('envio_etiqueta', $event.target.value.trim())" />
        </div>
      </div>
      <label class="sde__check">
        <input :checked="form.guardar_como_envio" type="checkbox" @change="set('guardar_como_envio', $event.target.checked)" />
        Guardarla en la ficha (queda en sus direcciones)
      </label>
    </template>
  </div>
</template>

<style scoped>
.sde { display: flex; flex-direction: column; gap: .75rem; }
.sde__field { display: flex; flex-direction: column; gap: .3rem; flex: 1; min-width: 0; }
.sde__row { display: flex; gap: .6rem; }
.sde__label { font-size: .68rem; font-weight: 700; text-transform: uppercase; letter-spacing: .05em; color: var(--c-slate-600); }
.sde__req { color: #dc2626; }
.sde__opt { font-weight: 500; text-transform: none; letter-spacing: 0; color: var(--c-slate-400); }
.sde__input { width: 100%; border: 1.5px solid var(--c-slate-200); border-radius: 9px; padding: .55rem .7rem; font-size: .86rem; color: var(--c-slate-900); background: #fff; outline: none; box-sizing: border-box; }
.sde__input:focus { border-color: #15803d; box-shadow: 0 0 0 3px rgba(21,128,61,.1); }
.sde__hint { font-size: .72rem; color: var(--c-slate-400); }
.sde__dirs { display: grid; gap: .4rem; }
.sde__dir { display: flex; align-items: flex-start; gap: .6rem; width: 100%; text-align: left; padding: .55rem .7rem; border: 1.5px solid var(--c-slate-200); border-radius: 10px; background: #fff; cursor: pointer; font: inherit; color: var(--c-slate-700); transition: border-color .15s, background .15s; }
.sde__dir i { margin-top: .1rem; color: var(--c-slate-400); }
.sde__dir--on { border-color: #15803d; background: #f0fdf4; color: var(--c-slate-900); }
.sde__dir--on i { color: #15803d; }
.sde__dir--off { opacity: .55; cursor: not-allowed; }
.sde__dir-txt { display: flex; flex-direction: column; gap: .1rem; min-width: 0; }
.sde__dir-label { font-size: .8rem; font-weight: 700; }
.sde__def { margin-left: .3rem; font-size: .62rem; font-weight: 800; text-transform: uppercase; letter-spacing: .04em; color: #15803d; }
.sde__dir-dir { font-size: .78rem; color: var(--c-slate-600); }
.sde__dir-dir--falta { color: var(--c-slate-400); font-style: italic; }
.sde__check { display: inline-flex; align-items: center; gap: .4rem; font-size: .78rem; color: var(--c-slate-600); cursor: pointer; }
</style>
