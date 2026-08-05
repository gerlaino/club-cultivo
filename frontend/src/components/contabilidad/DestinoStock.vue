<script setup>
// ¿La compra entra al inventario? El depósito se elige PRIMERO: define la sede del asiento y filtra
// qué puede entrar. Presentacional: el estado lo tiene el modal (v-model), la lógica vive en
// movimientoFlows.js.
import { computed, ref, watch } from 'vue'
import { listBarProductos } from '../../lib/api.js'
import { esDepositoSalon, UNIDADES_INSUMO, costoUnitario, fmtARS } from './movimientoFlows.js'

const props = defineProps({
  modelValue: { type: Object,  required: true },  // destino (ver destinoVacio())
  depositos:  { type: Array,   default: () => [] },
  insumos:    { type: Array,   default: () => [] },
  bares:      { type: Array,   default: () => [] },
  monto:      { type: Number,  default: null },   // para el costo unitario
  errores:    { type: Object,  default: () => ({}) },
})
const emit = defineEmits(['update:modelValue'])

const d = computed(() => props.modelValue)
function set(patch) { emit('update:modelValue', { ...d.value, ...patch }) }

const depositosDisponibles = computed(() => props.depositos.filter(x => x.activo))
const deposito = computed(() => depositosDisponibles.value.find(x => String(x.id) === String(d.value.deposito_id)) || null)
const esSalon  = computed(() => esDepositoSalon(deposito.value))

// Solo los insumos DE ESE depósito: reponer uno de otro dejaba el stock en un depósito y el
// asiento en la sede de otro (el backend ahora también lo rechaza).
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

// Cambiar de depósito invalida lo elegido antes (otro depósito, otros ítems).
function elegirDeposito(id) {
  const mismo = String(d.value.deposito_id) === String(id)
  emit('update:modelValue', {
    ...d.value,
    deposito_id: mismo ? '' : id,
    insumo_id: '', nombre: '', unidad_medida: 'unidad',
    bar_id: '', bar_producto_id: '', precio_ars: null, no_vender: false,
  })
  if (mismo) set({ cantidad: null })
}

const unitario = computed(() => costoUnitario(props.monto, d.value.cantidad))
const unidadItem = computed(() => {
  if (esSalon.value) return 'u'
  const ins = insumosDelDeposito.value.find(i => String(i.id) === String(d.value.insumo_id))
  return ins?.unidad_medida || d.value.unidad_medida || 'u'
})
</script>

<template>
  <div class="dst">
    <span class="dst__q">¿Entra al inventario?</span>

    <div class="dst__chips">
      <button
        type="button" class="dst__chip"
        :class="{ 'dst__chip--on': !d.deposito_id }"
        @click="elegirDeposito('')"
      >
        <i class="bi bi-dash-circle"></i> No, es solo un gasto
      </button>
      <button
        v-for="dep in depositosDisponibles" :key="dep.id"
        type="button" class="dst__chip"
        :class="{ 'dst__chip--on': String(d.deposito_id) === String(dep.id) }"
        @click="elegirDeposito(dep.id)"
      >
        <i class="bi bi-box-seam"></i> {{ dep.nombre }}
        <small v-if="dep.sede_nombre">· {{ dep.sede_nombre }}</small>
      </button>
    </div>

    <!-- Entrada al depósito elegido -->
    <div v-if="deposito" class="dst__box">

      <!-- Insumos (Cultivo / General / propios) -->
      <template v-if="!esSalon">
        <div class="dst__row">
          <label class="dst__fld dst__fld--grow">
            <span class="dst__lbl">¿Qué entró?</span>
            <select class="dst__inp" :class="{ 'dst__inp--err': errores.destino_item }"
                    :value="d.insumo_id" @change="set({ insumo_id: $event.target.value, nombre: '' })">
              <option value="">＋ Es nuevo, lo creo ahora</option>
              <option v-for="i in insumosDelDeposito" :key="i.id" :value="i.id">
                {{ i.nombre }} — hay {{ i.stock_actual }} {{ i.unidad_medida }}
              </option>
            </select>
          </label>
          <label class="dst__fld dst__fld--sm">
            <span class="dst__lbl">Cantidad</span>
            <input type="number" min="0" step="any" class="dst__inp"
                   :class="{ 'dst__inp--err': errores.destino_cantidad }"
                   :value="d.cantidad" @input="set({ cantidad: $event.target.value === '' ? null : Number($event.target.value) })"
                   placeholder="0" />
          </label>
        </div>

        <div v-if="!d.insumo_id" class="dst__row">
          <label class="dst__fld dst__fld--grow">
            <span class="dst__lbl">Nombre del insumo</span>
            <input type="text" class="dst__inp" :class="{ 'dst__inp--err': errores.destino_item }"
                   :value="d.nombre" @input="set({ nombre: $event.target.value })"
                   placeholder="Ej: Fertilizante base" maxlength="60" />
          </label>
          <label class="dst__fld dst__fld--sm">
            <span class="dst__lbl">Unidad</span>
            <select class="dst__inp" :value="d.unidad_medida" @change="set({ unidad_medida: $event.target.value })">
              <option v-for="u in UNIDADES_INSUMO" :key="u" :value="u">{{ u }}</option>
            </select>
          </label>
        </div>
      </template>

      <!-- Salón: mercadería del bar -->
      <template v-else>
        <div class="dst__row">
          <label class="dst__fld dst__fld--grow">
            <span class="dst__lbl">Buffet</span>
            <select class="dst__inp" :class="{ 'dst__inp--err': errores.destino_item }"
                    :value="d.bar_id" @change="set({ bar_id: $event.target.value, bar_producto_id: '', nombre: '' })">
              <option value="">— Elegí el bar —</option>
              <option v-for="b in baresDeLaSede" :key="b.id" :value="b.id">{{ b.nombre }}</option>
            </select>
          </label>
          <label class="dst__fld dst__fld--sm">
            <span class="dst__lbl">Cantidad</span>
            <input type="number" min="0" step="any" class="dst__inp"
                   :class="{ 'dst__inp--err': errores.destino_cantidad }"
                   :value="d.cantidad" @input="set({ cantidad: $event.target.value === '' ? null : Number($event.target.value) })"
                   placeholder="0" />
          </label>
        </div>

        <label v-if="d.bar_id" class="dst__fld">
          <span class="dst__lbl">¿Qué entró?</span>
          <select class="dst__inp" :value="d.bar_producto_id"
                  @change="set({ bar_producto_id: $event.target.value, nombre: '' })">
            <option value="">＋ Es nuevo, lo creo ahora</option>
            <option v-for="p in barProductos" :key="p.id" :value="p.id">{{ p.nombre }} — hay {{ p.stock }}</option>
          </select>
        </label>

        <div v-if="d.bar_id && !d.bar_producto_id" class="dst__row">
          <label class="dst__fld dst__fld--grow">
            <span class="dst__lbl">Nombre del producto</span>
            <input type="text" class="dst__inp" :class="{ 'dst__inp--err': errores.destino_item }"
                   :value="d.nombre" @input="set({ nombre: $event.target.value })"
                   placeholder="Ej: Cerveza IPA" maxlength="50" />
          </label>
          <label class="dst__fld dst__fld--sm">
            <span class="dst__lbl">Precio de venta</span>
            <input type="number" min="0" step="any" class="dst__inp"
                   :value="d.precio_ars" @input="set({ precio_ars: $event.target.value === '' ? null : Number($event.target.value) })"
                   placeholder="$" />
          </label>
        </div>

        <label v-if="d.bar_id && !d.bar_producto_id" class="dst__chk">
          <input type="checkbox" :checked="d.no_vender" @change="set({ no_vender: $event.target.checked })" />
          <span>No vender <small>— queda en el salón pero fuera del mostrador (uso interno)</small></span>
        </label>
      </template>

      <p class="dst__hint">
        <template v-if="unitario">
          Costo unitario: <strong>{{ fmtARS(unitario) }}</strong> por {{ unidadItem }}.
          Sube el stock {{ d.cantidad }} y se recalcula el costo promedio.
        </template>
        <template v-else>
          El monto de la compra es el costo total: al dividirlo por la cantidad sale el costo unitario.
        </template>
      </p>
      <p v-if="deposito.sede_nombre" class="dst__hint">
        <i class="bi bi-geo-alt-fill"></i> Queda en <strong>{{ deposito.sede_nombre }}</strong>, la sede del depósito.
      </p>
    </div>
  </div>
</template>

<style scoped>
.dst { display: flex; flex-direction: column; gap: var(--sp-2); }
.dst__q { font-size: var(--fs-13); font-weight: 600; color: var(--c-ink-700); }
.dst__chips { display: flex; flex-wrap: wrap; gap: var(--sp-2); }
.dst__chip {
  display: inline-flex; align-items: center; gap: 6px;
  padding: 7px 12px; border-radius: var(--r-pill);
  border: 1.5px solid var(--c-ink-300); background: #fff;
  font-size: var(--fs-13); font-weight: 500; color: var(--c-ink-700);
  cursor: pointer; transition: all var(--t-fast);
}
.dst__chip:hover { border-color: var(--c-leaf-500); color: var(--c-leaf-800); }
.dst__chip--on {
  border-color: var(--c-leaf-800); background: var(--c-leaf-100); color: var(--c-leaf-900); font-weight: 600;
}
.dst__chip small { font-weight: 400; opacity: .7; }

.dst__box {
  display: flex; flex-direction: column; gap: var(--sp-3);
  padding: var(--sp-3); border-radius: var(--r-lg);
  background: var(--c-leaf-50); border: 1px solid var(--c-leaf-100);
}
.dst__row { display: flex; gap: var(--sp-3); flex-wrap: wrap; }
.dst__fld { display: flex; flex-direction: column; gap: 4px; min-width: 0; }
.dst__fld--grow { flex: 1 1 220px; }
.dst__fld--sm { flex: 0 0 130px; }
.dst__lbl { font-size: var(--fs-12); font-weight: 600; color: var(--c-ink-500); }
.dst__inp {
  height: 38px; padding: 0 10px; border-radius: var(--r-md);
  border: 1.5px solid var(--c-ink-300); background: #fff;
  font-size: var(--fs-14); font-family: var(--font-ui); color: var(--c-ink-900);
  outline: none; transition: border-color var(--t-fast); width: 100%;
}
.dst__inp:focus { border-color: var(--c-leaf-600); }
.dst__inp--err { border-color: var(--c-rust-600); }
.dst__chk { display: flex; align-items: flex-start; gap: var(--sp-2); font-size: var(--fs-13); color: var(--c-ink-700); cursor: pointer; }
.dst__chk small { color: var(--c-ink-500); }
.dst__hint { margin: 0; font-size: var(--fs-12); color: var(--c-ink-500); line-height: var(--lh-base); }
</style>
