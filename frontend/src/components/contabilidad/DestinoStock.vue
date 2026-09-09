<script setup>
// ¿DÓNDE QUEDA LO QUE COMPRASTE?
//
// EL DEPÓSITO NO SE ELIGE: SE DEDUCE. Sale de la categoría (qué clase de cosa es) por la sede
// (dónde estás), y las dos ya están contestadas más arriba. Antes esto era una grilla con los diez
// depósitos del club —sin filtrar por la categoría, y el backend tampoco validaba— más una
// pregunta de sede aparte que el depósito después pisaba en silencio: dos preguntas para una sola
// decisión, con dos respuestas que podían contradecirse. Germán, cargando una compra: «es como que
// estoy ingresando por duplicado, ya arriba al elegir la categoría me indicaba el depósito».
//
// Lo que SÍ sigue siendo una decisión, y por eso sigue estando: que ESTA compra puntual no entre
// («es sólo un gasto»), y qué entró. Pero no pesan lo mismo: si la categoría guarda cosas, lo
// normal es que entre, así que la excepción va como salida y no como una de dos opciones en
// igualdad.
//
// Presentacional: el estado lo tiene el modal (v-model), la lógica vive en movimientoFlows.js.
import { computed, ref, watch } from 'vue'
import { listBarProductos } from '../../lib/api.js'
import { esDepositoSalon, UNIDADES_INSUMO,
         depositosDeFamiliaEnSede, sedesConDeposito } from './movimientoFlows.js'

const props = defineProps({
  modelValue: { type: Object,  required: true },  // destino (ver destinoVacio())
  // La familia de depósito que manda la categoría: 'insumo' | 'insumo_general' | 'mercaderia'.
  // null = esta categoría no guarda nada, es un gasto y listo.
  familia:    { type: String,  default: null },
  depositos:  { type: Array,   default: () => [] },
  sedes:      { type: Array,   default: () => [] },
  sedeId:     { type: [String, Number], default: null },
  insumos:    { type: Array,   default: () => [] },
  bares:      { type: Array,   default: () => [] },
  // Lo que ya escribió arriba: se propone como nombre del insumo nuevo en vez de pedirlo de nuevo.
  descripcion: { type: String, default: '' },
  unidad:     { type: String,  default: 'unidad' },
  // La cantidad se carga UNA vez, arriba, en el cuerpo del movimiento: acá se muestra para que
  // se vea qué va a entrar, pero no se vuelve a pedir.
  cantidad:   { type: Number,  default: null },
  // Una organización de una sola sede no tiene nada que elegir: no se le pregunta.
  multiSede:  { type: Boolean, default: false },
  errores:    { type: Object,  default: () => ({}) },
})
const emit = defineEmits(['update:modelValue', 'update:sedeId'])

const d = computed(() => props.modelValue)
function set(patch) { emit('update:modelValue', { ...d.value, ...patch }) }

// ── El depósito, deducido ───────────────────────────────────────────────────────
const candidatosSede = computed(() =>
  depositosDeFamiliaEnSede(props.depositos, props.familia, props.sedeId))
const sedesPosibles = computed(() => {
  const ids = sedesConDeposito(props.depositos, props.familia)
  return props.sedes.filter(s => ids.some(x => String(x) === String(s.id)))
})
const hayDeposito = computed(() => candidatosSede.value.length > 0)
const deposito = computed(() =>
  props.depositos.find(x => String(x.id) === String(d.value.deposito_id)) || null)
const esSalon = computed(() => esDepositoSalon(deposito.value))

// «Esta vez no entra»: la excepción, y es del usuario. Se recuerda mientras el modal está abierto
// para que cambiar de sede no la deshaga sola.
const descartado = ref(false)
const entra = computed(() => !!d.value.deposito_id)

// Cuál es el depósito de esta sede para esta familia. Con más de uno —el club creó uno propio de
// la misma familia— no se adivina: se pregunta, que es la misma regla que en el mostrador.
const nombreDeposito = computed(() =>
  candidatosSede.value[0]?.nombre ||
  ({ insumo: 'Cultivo', insumo_general: 'General', mercaderia: 'Salón' })[props.familia] || 'depósito')

function sincronizar() {
  if (!props.familia || descartado.value) {
    if (d.value.deposito_id) set({ deposito_id: '' })
    return
  }
  // Si una sola sede tiene depósito de esta familia, no hay nada que adivinar: se adopta. Sin
  // esto, una organización de una sola sede tenía que elegirla para algo que ya estaba decidido.
  if ((props.sedeId == null || props.sedeId === '') && sedesPosibles.value.length === 1) {
    return emit('update:sedeId', sedesPosibles.value[0].id)
  }
  // SIEMPRE QUEDA UNO ELEGIDO. Con dos depósitos de la misma familia en la sede —General y Otro,
  // que es lo que trae cualquier organización— dejarlo sin elegir mostraba un desplegable en
  // blanco Y el resumen diciendo «no entra nada al depósito», justo debajo de la línea que dice
  // que sí entra. El primero queda puesto y el desplegable lo cambia.
  const sigueValido = candidatosSede.value.some(x => String(x.id) === String(d.value.deposito_id))
  if (sigueValido) return
  if (candidatosSede.value.length) return elegirDeposito(candidatosSede.value[0].id)
  if (d.value.deposito_id) elegirDeposito('')
}
watch(() => [props.familia, props.sedeId, props.depositos.length], sincronizar, { immediate: true })

// Cambiar de depósito invalida lo elegido antes (otro depósito, otros ítems).
function elegirDeposito(id) {
  emit('update:modelValue', {
    ...d.value,
    deposito_id: id,
    insumo_id: '', nombre: '', unidad_medida: props.unidad || 'unidad',
    bar_id: '', bar_producto_id: '', precio_ars: null, no_vender: false,
  })
}

function noEntra() { descartado.value = true; elegirDeposito('') }
function siEntra()  { descartado.value = false; sincronizar() }
function cambiarSede(id) { emit('update:sedeId', id === '' ? null : id) }

// ── Qué entró ───────────────────────────────────────────────────────────────────
// Solo los insumos DE ESE depósito: reponer uno de otro dejaba el stock en un depósito y el
// asiento en la sede de otro (el backend también lo rechaza).
const insumosDelDeposito = computed(() => {
  if (!deposito.value) return []
  return props.insumos.filter(i => String(i.deposito_id) === String(deposito.value.id))
})

// Ídem con los bares: el depósito Salón es de una sede, el bar tiene que ser de la misma (el
// backend rechaza la combinación cruzada). `bares#index` manda la sede anidada; toleramos las dos.
const sedeDeBar = (b) => b.sede_id ?? b.sede?.id ?? null
const baresDeLaSede = computed(() => {
  if (!deposito.value?.sede_id) return props.bares
  return props.bares.filter(b => String(sedeDeBar(b)) === String(deposito.value.sede_id))
})

const barProductos = ref([])
watch(() => d.value.bar_id, async (id) => {
  barProductos.value = []
  if (!id) return
  try { barProductos.value = (await listBarProductos(id, { activos: 'true' })).data || [] } catch { /* lista vacía */ }
})

// El nombre del insumo nuevo NO se vuelve a escribir: es lo que ya pusiste arriba. Queda editable
// por si el renglón del ticket dice una cosa y el frasco otra.
const nombrePropuesto = computed(() => d.value.nombre?.trim() || props.descripcion?.trim() || '')
const editandoNombre = ref(false)
watch(() => props.descripcion, () => { if (!editandoNombre.value && !d.value.insumo_id) set({ nombre: '' }) })

const nombreSede = (id) => props.sedes.find(s => String(s.id) === String(id))?.nombre || ''
</script>

<template>
  <div class="dst">
    <!-- UN GASTO QUE NO GUARDA NADA sólo tiene una pregunta: de qué sede es. Y ninguna si la
         organización tiene una sola. -->
    <template v-if="!familia">
      <template v-if="multiSede">
        <span class="dst__q">De qué sede es</span>
        <label class="dst__fld dst__fld--md">
          <span class="dst__lbl">Sede</span>
          <select class="dst__inp" :value="sedeId ?? ''" @change="cambiarSede($event.target.value)">
            <option value="">Toda la organización</option>
            <option v-for="s in sedes" :key="s.id" :value="s.id">{{ s.nombre }}</option>
          </select>
        </label>
        <p class="dst__hint">
          Para que el gasto aparezca en el resultado de esa sede. Si es de todo el club —el
          contador, un seguro— dejalo en «toda la organización».
        </p>
      </template>
    </template>

    <template v-else>
      <span class="dst__q">Dónde queda</span>

      <!-- NO ENTRA: la excepción. Sigue existiendo —una categoría que guarda cosas no obliga a que
           ESTA compra entre— pero no se ofrece como si fueran dos caminos iguales. -->
      <template v-if="!entra && descartado">
        <p class="dst__afirma dst__afirma--no">
          <span><b>No entra al depósito:</b> es sólo un gasto. Se consume ahora y no hay nada que
          contar después.</span>
          <button type="button" class="dst__link" @click="siEntra">
            Sí entra, al depósito {{ nombreDeposito }}
          </button>
        </p>
        <label v-if="multiSede" class="dst__fld dst__fld--md">
          <span class="dst__lbl">De qué sede es</span>
          <select class="dst__inp" :value="sedeId ?? ''" @change="cambiarSede($event.target.value)">
            <option value="">Toda la organización</option>
            <option v-for="s in sedes" :key="s.id" :value="s.id">{{ s.nombre }}</option>
          </select>
        </label>
      </template>

      <!-- LA SEDE ELEGIDA NO TIENE ESE DEPÓSITO. Es el único caso en que el sistema no puede
           deducir, y entonces sí pregunta — pero entre las sedes que lo tienen, no entre todas. -->
      <p v-else-if="!hayDeposito" class="dst__afirma dst__afirma--falta">
        <template v-if="sedesPosibles.length">
          <span>
            Entra a un depósito <b>{{ nombreDeposito }}</b><template v-if="sedeId">, y
            {{ nombreSede(sedeId) }} no tiene</template>. ¿En cuál lo guardás?
          </span>
          <select class="dst__sede-inline" :value="sedeId ?? ''"
                  aria-label="Sede del depósito" @change="cambiarSede($event.target.value)">
            <option value="" disabled>Elegí una sede</option>
            <option v-for="s in sedesPosibles" :key="s.id" :value="s.id">{{ s.nombre }}</option>
          </select>
        </template>
        <span v-else>
          Todavía no hay ningún depósito donde guardar esto. Se crea en
          <b>Configuración → Depósitos</b>; mientras tanto se puede cargar como gasto.
        </span>
        <button type="button" class="dst__link" @click="noEntra">No entra: es sólo un gasto</button>
      </p>

      <!-- LO NORMAL: el depósito deducido, afirmado, con la sede editable adentro de la oración. -->
      <template v-else>
        <p class="dst__afirma">
          <span>Entra al depósito</span>
          <!-- Con más de un depósito de la misma familia en la sede, el nombre va SÓLO en el
               desplegable: escrito además al lado aparecía dos veces en la misma oración. -->
          <b v-if="candidatosSede.length === 1" class="dst__dep">{{ nombreDeposito }}</b>
          <select v-else class="dst__sede-inline" aria-label="En qué depósito"
                  :value="d.deposito_id" @change="elegirDeposito($event.target.value)">
            <option v-for="dep in candidatosSede" :key="dep.id" :value="dep.id">{{ dep.nombre }}</option>
          </select>
          <template v-if="multiSede">
            <span>de</span>
            <select class="dst__sede-inline" :value="sedeId ?? ''"
                    aria-label="Sede del depósito" @change="cambiarSede($event.target.value)">
              <option v-for="s in sedesPosibles" :key="s.id" :value="s.id">{{ s.nombre }}</option>
            </select>
          </template>
          <span class="dst__afirma-sub">Queda contado, y se descuenta cuando lo uses.</span>
        </p>

        <div class="dst__box">
          <!-- Insumos (Cultivo / General / propios) -->
          <template v-if="!esSalon">
            <div class="dst__row">
              <label class="dst__fld dst__fld--grow">
                <span class="dst__lbl">Qué entró</span>
                <select class="dst__inp" :class="{ 'dst__inp--err': errores.destino_item }"
                        :value="d.insumo_id" @change="set({ insumo_id: $event.target.value, nombre: '' })">
                  <option value="">＋ Es nuevo{{ nombrePropuesto ? `: «${nombrePropuesto}»` : '' }}</option>
                  <option v-for="i in insumosDelDeposito" :key="i.id" :value="i.id">
                    {{ i.nombre }} — hay {{ i.stock_actual }} {{ i.unidad_medida }}
                  </option>
                </select>
              </label>
              <div class="dst__fld dst__fld--sm">
                <span class="dst__lbl">Cantidad</span>
                <!-- Se carga arriba, con el monto: acá se refleja. Preguntarla dos veces dejaba dos
                     números distintos y ganaba el de abajo sin que nadie lo supiera. -->
                <div class="dst__ro" :class="{ 'dst__ro--err': errores.destino_cantidad }">
                  {{ cantidad ?? '—' }}
                </div>
              </div>
            </div>

            <!-- QUÉ SIGNIFICA ELEGIR DE LA LISTA, con la palabra que usa el admin. Sin esto hay
                 que deducir para qué sirve el desplegable. -->
            <p v-if="!d.insumo_id" class="dst__hint">
              <template v-if="insumosDelDeposito.length">
                Si es <b>reposición</b> de algo que ya tenés, elegilo de la lista: se suma a lo que
                hay y se recalcula el costo.
              </template>
              <template v-else>
                En el depósito {{ nombreDeposito }} todavía no hay nada cargado.
              </template>
            </p>
            <p v-else class="dst__hint">
              Se suma a lo que ya había y se recalcula el costo promedio.
            </p>

            <!-- El nombre y la unidad ya se escribieron arriba: se reusan. Editable por si el
                 renglón del ticket dice una cosa y el frasco otra. -->
            <template v-if="!d.insumo_id">
              <p v-if="!editandoNombre" class="dst__hint">
                Se crea como <b>«{{ nombrePropuesto || '—' }}»</b><template v-if="unidad && unidad !== 'unidad'">, medido en {{ unidad }}</template>.
                <button type="button" class="dst__link" @click="editandoNombre = true">
                  Ponerle otro nombre
                </button>
              </p>
              <div v-else class="dst__row">
                <label class="dst__fld dst__fld--grow">
                  <span class="dst__lbl">Nombre del insumo</span>
                  <input type="text" class="dst__inp" :class="{ 'dst__inp--err': errores.destino_item }"
                         :value="d.nombre" @input="set({ nombre: $event.target.value })"
                         placeholder="Ej: Fertilizante base" maxlength="60" />
                </label>
                <label class="dst__fld dst__fld--sm">
                  <span class="dst__lbl">Unidad</span>
                  <select class="dst__inp" :value="d.unidad_medida"
                          @change="set({ unidad_medida: $event.target.value })">
                    <option v-for="u in UNIDADES_INSUMO" :key="u" :value="u">{{ u }}</option>
                  </select>
                </label>
              </div>
            </template>
          </template>

          <!-- Salón: mercadería del buffet -->
          <template v-else>
            <div class="dst__row">
              <label class="dst__fld dst__fld--grow">
                <span class="dst__lbl">En qué buffet se vende</span>
                <select class="dst__inp" :class="{ 'dst__inp--err': errores.destino_item }"
                        :value="d.bar_id" @change="set({ bar_id: $event.target.value, bar_producto_id: '', nombre: '' })">
                  <option value="">— Elegir —</option>
                  <option v-for="b in baresDeLaSede" :key="b.id" :value="b.id">{{ b.nombre }}</option>
                </select>
              </label>
              <div class="dst__fld dst__fld--sm">
                <span class="dst__lbl">Cantidad</span>
                <div class="dst__ro" :class="{ 'dst__ro--err': errores.destino_cantidad }">
                  {{ cantidad ?? '—' }}
                </div>
              </div>
            </div>
            <div v-if="d.bar_id" class="dst__row">
              <label class="dst__fld dst__fld--grow">
                <span class="dst__lbl">Qué producto es</span>
                <select class="dst__inp" :value="d.bar_producto_id"
                        @change="set({ bar_producto_id: $event.target.value, nombre: '' })">
                  <option value="">＋ Es nuevo{{ nombrePropuesto ? `: «${nombrePropuesto}»` : '' }}</option>
                  <option v-for="p in barProductos" :key="p.id" :value="p.id">
                    {{ p.nombre }} — hay {{ p.stock_actual }}
                  </option>
                </select>
              </label>
              <label v-if="!d.bar_producto_id" class="dst__fld dst__fld--sm">
                <span class="dst__lbl">Precio de venta</span>
                <input type="number" min="0" step="1" class="dst__inp" :value="d.precio_ars"
                       @input="set({ precio_ars: $event.target.value === '' ? null : Number($event.target.value) })"
                       placeholder="0" />
              </label>
            </div>
            <p v-if="d.bar_id && !d.bar_producto_id" class="dst__hint">
              Se crea como <b>«{{ nombrePropuesto || '—' }}»</b> en la carta del buffet.
            </p>
          </template>

          <p class="dst__salida">
            <button type="button" class="dst__link" @click="noEntra">
              Esta vez no entra al depósito: es sólo un gasto
            </button>
          </p>
        </div>
      </template>
    </template>
  </div>
</template>

<style scoped>
.dst { display: flex; flex-direction: column; gap: 10px; }
.dst__q {
  font-size: var(--fs-11, .7rem); font-weight: 600; letter-spacing: .06em; text-transform: uppercase;
  color: var(--c-ink-500);
}

/* LO QUE PASA, AFIRMADO — no preguntado. Lo editable va adentro de la oración. */
.dst__afirma {
  margin: 0; font-size: var(--fs-14); color: var(--c-ink-900); line-height: 1.7;
  background: var(--c-leaf-50); border-radius: 11px; padding: 12px 14px;
  display: flex; flex-wrap: wrap; align-items: center; gap: 4px 6px;
}
.dst__afirma b { font-weight: 600; }
.dst__dep { color: var(--c-leaf-800); }
.dst__afirma-sub { flex: 1 0 100%; font-size: var(--fs-12); color: var(--c-ink-500); line-height: 1.4; }
.dst__afirma--no    { background: var(--c-slate-50); }
.dst__afirma--falta { background: var(--c-amber-100); }

.dst__sede-inline {
  font: inherit; font-size: var(--fs-13); font-weight: 600; color: var(--c-ink-900);
  background: #fff; border: 1px solid var(--c-slate-300); border-radius: 7px; padding: 3px 6px;
  max-width: 100%;
}

.dst__box {
  border-left: 2px solid var(--c-slate-200); margin-left: 8px; padding-left: 16px;
  display: flex; flex-direction: column; gap: 10px;
}
.dst__row { display: flex; gap: 10px; flex-wrap: wrap; }
.dst__fld { display: flex; flex-direction: column; gap: 4px; min-width: 0; }
.dst__fld--grow { flex: 1 1 200px; }
.dst__fld--sm { flex: 0 0 110px; }
.dst__fld--md { flex: 0 0 190px; }
.dst__lbl { font-size: var(--fs-12); font-weight: 600; color: var(--c-ink-700); }
.dst__inp {
  font: inherit; font-size: var(--fs-14); color: var(--c-ink-900);
  background: #fff; border: 1px solid var(--c-slate-300); border-radius: 9px;
  padding: 9px 11px; width: 100%; min-width: 0;
}
.dst__inp:focus { outline: 2px solid var(--c-leaf-300); outline-offset: 1px; border-color: var(--c-leaf-500); }
.dst__inp--err { border-color: #dc2626; }
.dst__ro {
  font-family: var(--font-mono); font-size: var(--fs-14); color: var(--c-ink-500);
  background: var(--c-slate-50); border: 1px dashed var(--c-slate-300);
  border-radius: 9px; padding: 9px 11px;
}
.dst__ro--err { border-color: #dc2626; color: #b91c1c; }
.dst__hint { margin: 0; font-size: var(--fs-12); color: var(--c-ink-500); line-height: 1.45; }
.dst__hint b { color: var(--c-ink-700); }
.dst__salida { margin: 2px 0 0; }
.dst__link {
  font: inherit; font-size: var(--fs-12); color: var(--c-leaf-800); background: none; border: 0;
  padding: 0; cursor: pointer; text-decoration: underline; text-underline-offset: 2px;
}
.dst__link:hover { color: var(--c-leaf-600); }
</style>
