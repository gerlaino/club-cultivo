<script setup>
import { ref, computed, watch } from 'vue'
import AppDatePicker from '../ui/AppDatePicker.vue'
import { useToast } from '../../composables/useToast.js'
import DsSpinner from '../../design-system/components/Spinner.vue'
import { updateDispensacion, agregarEnvioDispensacion, listEntregadores } from '../../lib/api.js'
import { useAuthStore } from '../../stores/auth'
import { useClubStore } from '../../stores/club'
import SelectorDireccionEntrega from './SelectorDireccionEntrega.vue'

const auth = useAuthStore()
// Solo admin/supervisor pueden pisar el precio por ítem; el resto edita cantidades.
const puedeEditarPrecio = computed(() => ['admin', 'supervisor'].includes(auth.user?.role))

const props = defineProps({
  modelValue:     { type: Boolean, required: true },
  dispensacion:   { type: Object,  default: null },
  saldoCc:        { type: Number,  default: null },
  limiteCc:       { type: Number,  default: null },
})

const emit = defineEmits(['update:modelValue', 'saved'])

const toast      = useToast()
const saving     = ref(false)
const formError  = ref(null)

const FORMA_LABEL = {
  flor_seca: 'Flor seca', hash: 'Hash', aceite: 'Aceite',
  preroll: 'Preroll', crema: 'Crema', descarte: 'Descarte', otro: 'Otro',
}
const FORMA_EMOJI = {
  flor_seca: '🌿', hash: '🟤', aceite: '🫙',
  preroll: '🚬', crema: '💊', descarte: '🗑️', otro: '📦',
}

const fmt = n => n == null ? '—' :
  new Intl.NumberFormat('es-AR', { style: 'currency', currency: 'ARS', minimumFractionDigits: 0 }).format(n)

// ── Cuenta corriente ───────────────────────────────────────
// LA CC SALE DE LA DISPENSA, no de quién montó el modal. Las props existen desde antes y se
// respetan si vienen, pero el historial no las pasaba: al paciente con crédito recién habilitado
// el desplegable le decía "Cuenta corriente (sin límite)" y no lo dejaba elegirla, mientras el
// MISMO modal abierto desde la ficha del paciente sí. Un dato del paciente no puede depender de
// por qué puerta se abrió la pantalla.
const limiteCc = computed(() => props.limiteCc ?? props.dispensacion?.paciente_limite_cc ?? null)
const saldoCc  = computed(() => props.saldoCc  ?? props.dispensacion?.paciente_saldo_cc  ?? null)
const tieneCc  = computed(() => limiteCc.value !== null && limiteCc.value > 0)
const ccMargen = computed(() => (saldoCc.value ?? 0) + (limiteCc.value ?? 0))

const ccInsuficiente = computed(() => {
  if (!tieneCc.value || form.value.medio_pago !== 'cuenta_corriente') return false
  if (form.value.aporte_socio_ars == null) return false
  return Number(form.value.aporte_socio_ars) > ccMargen.value
})

const estadoCc = computed(() => {
  if (!tieneCc.value) return null
  if (ccMargen.value <= 0)  return 'agotado'
  if (ccInsuficiente.value) return 'insuficiente'
  if (ccMargen.value < (limiteCc.value ?? 0) * 0.2) return 'critico'
  return 'ok'
})

// ── Envío ─────────────────────────────────────────────────
// Se dispensó y no se tildó «con envío» (Germán, 16-sep): acá se le agrega el paquete —
// repartidor y dirección con la misma regla que al crear— sin tocar lo cobrado. Si ya va por
// delivery, se dice y no se edita desde acá: el paquete se maneja en Despachos.
const club = useClubStore()
const tieneDelivery = computed(() => club.data?.features?.delivery === true)
const agregarEnvio  = ref(false)
const envio = ref({})
const entregadores = ref([])
const selectorDireccion = ref(null)

function envioVacio() {
  return { delivery_id: null, direccion_origen: 'domicilio', envio_calle: '', envio_altura: '', envio_piso: '',
           envio_depto: '', envio_barrio: '', envio_ciudad: '', envio_etiqueta: '', guardar_como_envio: false,
           contacto_nombre: '', contacto_telefono: '', notas_envio: '',
           // Obligatorio también al mandarla después (23-sep-2026): 0 = bonificado.
           costo_envio: '' }
}

async function mandarPorDelivery() {
  const e = envio.value
  await agregarEnvioDispensacion(props.dispensacion.id, {
    delivery_id: e.delivery_id, direccion_origen: e.direccion_origen,
    envio_calle: e.envio_calle || undefined, envio_altura: e.envio_altura || undefined,
    envio_piso: e.envio_piso || undefined, envio_depto: e.envio_depto || undefined,
    envio_barrio: e.envio_barrio || undefined, envio_ciudad: e.envio_ciudad || undefined,
    envio_etiqueta: e.envio_etiqueta || undefined,
    guardar_como_envio: e.direccion_origen === 'otra' && e.guardar_como_envio,
    contacto_nombre: e.contacto_nombre || undefined, contacto_telefono: e.contacto_telefono || undefined,
    notas_envio: e.notas_envio || undefined,
    costo_envio_ars: Number(e.costo_envio).toFixed(2),
  })
}

watch(agregarEnvio, async (on) => {
  if (!on && !props.dispensacion?.con_envio && form.value.medio_pago === 'contra_entrega') form.value.medio_pago = 'efectivo'
  if (!on || entregadores.value.length) return
  try { const { data } = await listEntregadores(); entregadores.value = data?.data || data || [] } catch { /* el select queda vacío y se ve */ }
})

// ── Form ──────────────────────────────────────────────────
const form = ref({})

// Contra entrega se puede poner si va por delivery (o se lo manda en esta misma edición) y el
// paquete no cerró; y sacar sólo si el repartidor todavía no cobró.
const paqueteCerrado = computed(() => ['entregado', 'fallido', 'cancelada'].includes(props.dispensacion?.estado_envio))
const puedeContraEntrega = computed(() =>
  (props.dispensacion?.con_envio || agregarEnvio.value) && !paqueteCerrado.value)

function buildForm(d) {
  if (!d) return { items: [], fecha_dispensacion: '', medio_pago: 'efectivo', aporte_socio_ars: null, observaciones: '' }
  const items = (d.items?.length ? d.items : []).map(it => ({
    stock_id: it.stock_id,
    forma:    it.stock?.forma_producto,
    genetica: it.genetica_nombre || it.stock?.lote?.genetica?.nombre,
    unidad:   it.stock?.unidad || 'g',
    cantidad: Number(it.cantidad) || 0,
    precio:   Number(it.precio_unitario_ars) || 0,
  }))
  return {
    items,
    fecha_dispensacion: d.fecha_dispensacion || '',
    // Una contra entrega sin cobrar se muestra como tal, no como el «efectivo» placeholder.
    medio_pago:         (d.cobrar_en_entrega && !(d.cobros?.length)) ? 'contra_entrega' : (d.medio_pago || 'efectivo'),
    // SÓLO LOS PRODUCTOS: el total de la dispensa trae adentro el envío, y el backend suma el
    // envío sobre lo que se mande acá. Precargado con el total, guardar sin tocar nada contaba
    // el envío dos veces.
    aporte_socio_ars:   d.subtotal_productos_ars ?? d.aporte_socio_ars ?? null,
    // El valor del envío, si va por delivery (null en las anteriores al 23-sep).
    costo_envio:        d.costo_envio_ars ?? '',
    observaciones:      d.observaciones || '',
  }
}

// ¿Se puede corregir el valor del envío? Si va por delivery y el paquete no cerró.
const editaEnvio = computed(() => !!props.dispensacion?.con_envio && !paqueteCerrado.value)
const envioActual = computed(() => {
  if (agregarEnvio.value) return Math.max(0, Number(envio.value.costo_envio) || 0)
  if (props.dispensacion?.con_envio) return Math.max(0, Number(form.value.costo_envio) || 0)
  return 0
})
const conEnvioEnForm = computed(() => !!props.dispensacion?.con_envio || agregarEnvio.value)
// Lo que paga el paciente: productos + envío.
const totalConEnvio = computed(() => (Number(form.value.aporte_socio_ars) || 0) + envioActual.value)

// Total sugerido = suma de (cantidad × precio) por ítem. El aporte lo pre-llena pero el
// admin puede pisarlo (override).
const totalSugerido = computed(() =>
  Math.round((form.value.items || []).reduce((s, it) => s + (Number(it.cantidad) || 0) * (Number(it.precio) || 0), 0))
)
function recalc() { form.value.aporte_socio_ars = totalSugerido.value }
function quitarItem(i) {
  if (form.value.items.length <= 1) return
  form.value.items.splice(i, 1)
  recalc()
}

watch(() => props.modelValue, (open) => {
  if (open && props.dispensacion) {
    form.value  = buildForm(props.dispensacion)
    formError.value = null
    agregarEnvio.value = false
    envio.value = envioVacio()
  }
}, { immediate: true })

watch(() => props.dispensacion, (d) => {
  if (props.modelValue && d) form.value = buildForm(d)
})

function cerrar() { emit('update:modelValue', false) }

async function handleSubmit() {
  if (saving.value) return
  saving.value = true
  formError.value = null

  if (form.value.medio_pago === 'cuenta_corriente' && !(Number(form.value.aporte_socio_ars) > 0)) {
    formError.value = 'El aporte debe ser mayor a $0 cuando el medio de pago es cuenta corriente'
    saving.value = false; return
  }

  if (!form.value.items?.length) {
    formError.value = 'La dispensación debe tener al menos un producto'
    saving.value = false; return
  }

  if (agregarEnvio.value) {
    if (!envio.value.delivery_id) { formError.value = 'Elegí un repartidor para el envío'; saving.value = false; return }
    if (envio.value.costo_envio === '' || envio.value.costo_envio == null) { formError.value = 'Poné el valor del envío: 0 si va bonificado.'; saving.value = false; return }
    if (Number(envio.value.costo_envio) < 0) { formError.value = 'El valor del envío no puede ser negativo.'; saving.value = false; return }
    const errorDireccion = selectorDireccion.value?.validar?.()
    if (errorDireccion) { formError.value = errorDireccion; saving.value = false; return }
  }

  if (editaEnvio.value && form.value.costo_envio !== '' && Number(form.value.costo_envio) < 0) {
    formError.value = 'El valor del envío no puede ser negativo.'
    saving.value = false; return
  }

  // Contra entrega pide que la dispensa YA vaya por delivery: si se la manda en esta misma
  // edición, el envío va primero. En el resto de los casos, primero lo financiero.
  const envioPrimero = agregarEnvio.value && form.value.medio_pago === 'contra_entrega'

  try {
    if (envioPrimero) await mandarPorDelivery()
    await updateDispensacion(props.dispensacion.id, {
      items: form.value.items.map(it => ({
        stock_id: it.stock_id,
        cantidad: it.cantidad,
        ...(puedeEditarPrecio.value ? { precio_manual_ars: it.precio } : {}),
      })),
      fecha_dispensacion: form.value.fecha_dispensacion,
      medio_pago:         form.value.medio_pago,
      aporte_socio_ars:   form.value.aporte_socio_ars,
      observaciones:      form.value.observaciones || null,
      // El envío sólo si va por delivery y hay un valor (las viejas pueden no tenerlo).
      ...(editaEnvio.value && form.value.costo_envio !== '' ? { costo_envio_ars: Number(form.value.costo_envio).toFixed(2) } : {}),
    })
    // Después de guardar lo financiero: si eso rebotó, no se manda nada a la calle.
    if (agregarEnvio.value && !envioPrimero) await mandarPorDelivery()
    cerrar()
    toast.success(agregarEnvio.value ? 'Dispensación actualizada y mandada por delivery' : 'Dispensación actualizada')
    emit('saved')
  } catch (e) {
    formError.value = e.response?.data?.errors?.[0] || e.response?.data?.error || 'Error al guardar'
  } finally { saving.value = false }
}
</script>

<template>
  <Teleport to="body">
    <div v-modal="cerrar" v-if="modelValue && dispensacion" class="med__overlay">
      <div class="med__modal">

        <div class="med__modal-header">
          <h3 class="med__modal-title">
            Editar dispensación
            <span v-if="dispensacion.paciente_nombre" class="med__modal-title-paciente">— {{ dispensacion.paciente_nombre }}</span>
          </h3>
          <button class="med__modal-close" @click="cerrar"><i class="bi bi-x-lg"></i></button>
        </div>

        <div class="med__modal-body">
          <div v-if="formError" class="med__error"><i class="bi bi-exclamation-triangle-fill"></i> {{ formError }}</div>

          <!-- Productos de la dispensa -->
          <div class="med__section-label">Producto{{ form.items?.length > 1 ? 's' : '' }}</div>
          <div class="med__items">
            <div v-for="(it, i) in form.items" :key="i" class="med__item">
              <span class="med__item-emoji">{{ FORMA_EMOJI[it.forma] || '📦' }}</span>
              <div class="med__item-detail">
                <span class="med__item-nombre">{{ FORMA_LABEL[it.forma] || it.forma || '—' }}</span>
                <span v-if="it.genetica" class="med__item-gen">{{ it.genetica }}</span>
              </div>
              <div class="med__qty-edit">
                <input v-model.number="it.cantidad" type="number" min="0.01" step="0.01" class="med__qty-input" @input="recalc" />
                <span class="med__qty-unit">{{ it.unidad }}</span>
              </div>
              <div v-if="puedeEditarPrecio" class="med__price-edit" title="Precio por unidad">
                <span class="med__price-prefix">$</span>
                <input v-model.number="it.precio" type="number" min="0" step="1" class="med__price-input" @input="recalc" />
              </div>
              <span v-else class="med__item-price">{{ fmt(it.precio) }}</span>
              <button v-if="form.items.length > 1" class="med__item-del" @click="quitarItem(i)" title="Quitar ítem">
                <i class="bi bi-trash"></i>
              </button>
            </div>
          </div>
          <div class="med__items-total">Total productos <strong>{{ fmt(totalSugerido) }}</strong></div>

          <div class="med__divider"></div>

          <!-- Aporte -->
          <div class="med__field">
            <label class="med__label">{{ conEnvioEnForm ? 'Aporte por los productos' : 'Aporte del paciente' }} <span class="med__opt">ARS{{ conEnvioEnForm ? ', sin el envío' : '' }}</span></label>
            <div class="med__input-suffix-wrap">
              <span class="med__input-prefix">$</span>
              <input v-model.number="form.aporte_socio_ars" type="number" min="0" step="1"
                     class="med__input med__input--with-prefix" placeholder="0" />
            </div>
          </div>

          <!-- El valor del envío, corregible mientras el paquete no cerró (23-sep-2026). -->
          <div v-if="editaEnvio" class="med__field">
            <label class="med__label" for="med-costo-envio">Valor del envío <span class="med__opt">0 = bonificado</span></label>
            <div class="med__input-suffix-wrap">
              <span class="med__input-prefix">$</span>
              <input id="med-costo-envio" v-model="form.costo_envio" type="number" min="0" step="1" inputmode="numeric"
                     class="med__input med__input--with-prefix" placeholder="0" />
            </div>
          </div>
          <div v-if="conEnvioEnForm" class="med__items-total">
            Total con envío <strong>{{ fmt(totalConEnvio) }}</strong>
            <span v-if="envioActual === 0 && (editaEnvio ? form.costo_envio !== '' : envio.costo_envio !== '')" class="med__opt">(envío bonificado)</span>
          </div>

          <!-- CC info -->
          <div v-if="tieneCc" class="med__cc-panel" :class="`med__cc-panel--${estadoCc || 'ok'}`">
            <div class="med__cc-row">
              <span class="med__cc-label"><i class="bi bi-wallet2"></i> Crédito disponible</span>
              <span class="med__cc-saldo" :class="{ 'med__cc-saldo--bajo': ccMargen <= 0 }">{{ fmt(ccMargen) }}</span>
            </div>
            <div v-if="ccInsuficiente" class="med__cc-warn">
              <i class="bi bi-exclamation-triangle-fill"></i>
              Crédito insuficiente (disponible: {{ fmt(ccMargen) }})
            </div>
          </div>

          <!-- Fecha + pago -->
          <div class="med__form-row">
            <div class="med__field">
              <label class="med__label">Fecha</label>
              <AppDatePicker v-model="form.fecha_dispensacion" />
            </div>
            <div class="med__field">
              <label class="med__label">Medio de pago</label>
              <select v-model="form.medio_pago" class="med__input">
                <option value="efectivo">Efectivo</option>
                <option value="transferencia">Transferencia</option>
                <option value="cuenta_corriente" :disabled="!tieneCc">Cuenta corriente{{ !tieneCc ? ' (sin límite configurado)' : '' }}</option>
                <option value="no_abona">No abona</option>
                <!-- Contra entrega: lo cobra el repartidor en la puerta. Sólo si va (o se va a
                     mandar) por delivery y el paquete todavía no cerró; y sacarla sólo mientras
                     no se cobró. -->
                <option v-if="tieneDelivery" value="contra_entrega" :disabled="!puedeContraEntrega">
                  Contra entrega (lo cobra el repartidor){{ puedeContraEntrega ? '' : ' — mandala por delivery primero' }}
                </option>
              </select>
              <p v-if="form.medio_pago === 'contra_entrega' && dispensacion.medio_pago !== 'contra_entrega'" class="med__opt" style="margin-top:.3rem">
                Se deshace lo cobrado: el repartidor cobra {{ fmt(totalConEnvio) }} en la puerta.
              </p>
            </div>
          </div>

          <!-- Observaciones -->
          <div class="med__field">
            <label class="med__label">Observaciones <span class="med__opt">opcional</span></label>
            <textarea v-model.trim="form.observaciones" class="med__input med__textarea" rows="2"
                      placeholder="Notas adicionales…"></textarea>
          </div>

          <!-- Envío. Si salió sin tildar «con envío», acá se manda por delivery. -->
          <template v-if="tieneDelivery">
            <div class="med__divider"></div>
            <div v-if="dispensacion.con_envio" class="med__envio-info">
              <i class="bi bi-truck"></i>
              Va por delivery<template v-if="dispensacion.delivery_nombre"> con {{ dispensacion.delivery_nombre }}</template>
              <template v-if="dispensacion.direccion_envio"> a {{ dispensacion.direccion_envio }}</template>.
              El paquete se maneja desde Despachos.
            </div>
            <template v-else>
              <div class="med__envio-toggle" @click="agregarEnvio = !agregarEnvio">
                <div>
                  <div class="med__envio-toggle-title">Mandar por delivery</div>
                  <div class="med__opt">Salió sin envío: se le agrega el paquete sin tocar lo cobrado</div>
                </div>
                <div class="med__switch" :class="{ 'med__switch--on': agregarEnvio }"><div class="med__switch-knob"></div></div>
              </div>
              <div v-if="agregarEnvio" class="med__envio">
                <div class="med__field">
                  <label class="med__label">Repartidor <span class="med__req">*</span></label>
                  <select v-model="envio.delivery_id" class="med__input">
                    <option :value="null">Seleccioná un repartidor…</option>
                    <option v-for="u in entregadores" :key="u.id" :value="u.id">{{ u.nombre || u.email }}</option>
                  </select>
                </div>
                <div class="med__field">
                  <label class="med__label" for="med-envio-costo">Valor del envío <span class="med__req">*</span></label>
                  <div class="med__input-suffix-wrap">
                    <span class="med__input-prefix">$</span>
                    <input id="med-envio-costo" v-model="envio.costo_envio" type="number" min="0" step="1" inputmode="numeric"
                           class="med__input med__input--with-prefix" placeholder="0 si va bonificado" />
                  </div>
                  <p class="med__opt" style="margin-top:.3rem">
                    <template v-if="envio.costo_envio === ''">Obligatorio. Poné 0 si va bonificado.</template>
                    <template v-else-if="Number(envio.costo_envio) > 0">Lo cobrado no se toca: el envío lo cobra el repartidor en la puerta.</template>
                    <template v-else>Envío bonificado: no se le cobra.</template>
                  </p>
                </div>
                <SelectorDireccionEntrega ref="selectorDireccion" :model-value="envio" :socio-id="dispensacion.paciente_id"
                                          @update:model-value="Object.assign(envio, $event)" />
                <div class="med__form-row">
                  <div class="med__field">
                    <label class="med__label">Contacto <span class="med__opt">si no es el paciente</span></label>
                    <input v-model.trim="envio.contacto_nombre" type="text" class="med__input" placeholder="Quien recibe" />
                  </div>
                  <div class="med__field">
                    <label class="med__label">Teléfono <span class="med__opt">opcional</span></label>
                    <input v-model.trim="envio.contacto_telefono" type="tel" class="med__input" placeholder="+54 11 …" />
                  </div>
                </div>
                <div class="med__field">
                  <label class="med__label">Notas de envío <span class="med__opt">opcional</span></label>
                  <textarea v-model.trim="envio.notas_envio" class="med__input med__textarea" rows="2" placeholder="Instrucciones para el delivery…"></textarea>
                </div>
              </div>
            </template>
          </template>

        </div>

        <div class="med__modal-footer">
          <button class="med__btn-ghost" :disabled="saving" @click="cerrar">Cancelar</button>
          <button class="med__btn-primary" :disabled="saving" @click="handleSubmit">
            <DsSpinner v-if="saving" :size="14" />
            <i v-else class="bi bi-check-lg"></i>
            Guardar cambios
          </button>
        </div>

      </div>
    </div>
  </Teleport>
</template>

<style scoped>
.med__overlay { position: fixed; inset: 0; background: rgba(0,0,0,.45); display: flex; align-items: center; justify-content: center; z-index: 1050; padding: 1rem; backdrop-filter: blur(3px); }
.med__modal { background: #fff; border-radius: 18px; width: 100%; max-width: 540px; max-height: 92vh; overflow-y: auto; box-shadow: 0 24px 64px rgba(0,0,0,.18); display: flex; flex-direction: column; }

.med__modal-header { display: flex; align-items: center; justify-content: space-between; gap: 1rem; padding: 1.1rem 1.25rem .9rem; border-bottom: 1px solid var(--c-slate-100); position: sticky; top: 0; background: #fff; z-index: 1; }
.med__modal-title { font-size: .95rem; font-weight: 800; color: var(--c-slate-900); margin: 0; }
.med__modal-title-paciente { color: #15803d; font-weight: 600; }
.med__modal-close { background: var(--c-slate-100); border: none; width: 28px; height: 28px; border-radius: 7px; cursor: pointer; display: flex; align-items: center; justify-content: center; color: var(--c-slate-500); }
.med__modal-close:hover { background: var(--c-slate-200); }

.med__modal-body { padding: 1.1rem 1.25rem; flex: 1; display: flex; flex-direction: column; gap: .9rem; background: var(--c-slate-50); }
.med__modal-footer { display: flex; justify-content: flex-end; gap: .75rem; padding: .875rem 1.25rem; border-top: 1px solid var(--c-slate-100); position: sticky; bottom: 0; background: #fff; }

.med__error { background: #fef2f2; color: #dc2626; border: 1px solid #fecaca; border-radius: 9px; padding: .6rem .875rem; font-size: .82rem; display: flex; align-items: center; gap: .4rem; }

/* Stock info (readonly) */
.med__section-label { font-size: .72rem; font-weight: 700; color: #374151; text-transform: uppercase; letter-spacing: .05em; }
.med__stock-info { display: flex; align-items: center; gap: .75rem; padding: .7rem .875rem; border-radius: 10px; border: 1.5px solid var(--c-slate-200); background: #fff; }
.med__stock-emoji { font-size: 1.2rem; flex-shrink: 0; }
.med__stock-detail { flex: 1; min-width: 0; display: flex; flex-direction: column; gap: .1rem; }
.med__stock-nombre { font-size: .82rem; font-weight: 700; color: var(--c-slate-900); }
.med__stock-gen { font-size: .72rem; color: var(--c-slate-500); font-style: italic; }
.med__stock-cantidad { display: flex; flex-direction: column; align-items: flex-end; gap: .2rem; flex-shrink: 0; }
.med__stock-qty { font-size: .95rem; font-weight: 800; color: #1b5e20; font-family: monospace; }
.med__stock-readonly-badge { font-size: .62rem; color: var(--c-slate-400); background: var(--c-slate-100); border-radius: 4px; padding: .1em .4em; }
.med__qty-edit { display: flex; align-items: center; gap: .3rem; }
.med__qty-input { width: 72px; text-align: right; background: var(--c-slate-50); border: 1.5px solid var(--c-slate-200); border-radius: 7px; padding: .35rem .5rem; font-size: .85rem; font-weight: 700; color: var(--c-slate-900); outline: none; }
.med__qty-unit { font-size: .78rem; color: var(--c-slate-500); font-weight: 600; }

/* Ítems editables */
.med__items { display: flex; flex-direction: column; gap: .5rem; }
.med__item { display: flex; align-items: center; gap: .6rem; padding: .6rem .75rem; border-radius: 10px; border: 1.5px solid var(--c-slate-200); background: #fff; }
.med__item-emoji { font-size: 1.15rem; flex-shrink: 0; }
.med__item-detail { flex: 1; min-width: 0; display: flex; flex-direction: column; gap: .1rem; }
.med__item-nombre { font-size: .82rem; font-weight: 700; color: var(--c-slate-900); }
.med__item-gen { font-size: .72rem; color: var(--c-slate-500); font-style: italic; }
.med__price-edit { display: flex; align-items: center; gap: .15rem; flex-shrink: 0; }
.med__price-prefix { font-size: .78rem; color: var(--c-slate-500); font-weight: 600; }
.med__price-input { width: 76px; text-align: right; background: var(--c-slate-50); border: 1.5px solid var(--c-slate-200); border-radius: 7px; padding: .35rem .5rem; font-size: .85rem; font-weight: 700; color: var(--c-slate-900); outline: none; }
.med__item-price { font-size: .82rem; font-weight: 700; color: #15803d; flex-shrink: 0; }
.med__item-del { background: none; border: none; color: #dc2626; cursor: pointer; padding: .2rem; flex-shrink: 0; font-size: .85rem; }
.med__items-total { text-align: right; font-size: .8rem; color: var(--c-slate-500); margin-top: .5rem; }
.med__items-total strong { color: #15803d; font-size: .95rem; margin-left: .3rem; }

/* Form */
.med__divider { height: 1px; background: var(--c-slate-200); }
/* Envío */
.med__envio-info { display: flex; gap: .5rem; align-items: flex-start; font-size: .82rem; color: var(--c-slate-600); background: var(--c-slate-50); border-radius: 9px; padding: .6rem .8rem; }
.med__envio-toggle { display: flex; align-items: center; justify-content: space-between; gap: .75rem; padding: .7rem .85rem; border: 1.5px solid var(--c-slate-200); border-radius: 10px; cursor: pointer; }
.med__envio-toggle-title { font-size: .86rem; font-weight: 700; color: var(--c-slate-900); }
.med__switch { width: 40px; height: 22px; border-radius: 11px; background: var(--c-slate-300); position: relative; flex-shrink: 0; transition: background .15s; }
.med__switch--on { background: #15803d; }
.med__switch-knob { position: absolute; top: 2px; left: 2px; width: 18px; height: 18px; border-radius: 50%; background: #fff; transition: left .15s; }
.med__switch--on .med__switch-knob { left: 20px; }
.med__envio { display: flex; flex-direction: column; gap: .75rem; padding: .75rem; background: var(--c-slate-50); border: 1px solid var(--c-slate-200); border-radius: 10px; }
.med__req { color: #dc2626; }
.med__form-row { display: grid; grid-template-columns: 1fr 1fr; gap: .75rem; }
@media (max-width: 400px) { .med__form-row { grid-template-columns: 1fr; } }
.med__field { display: flex; flex-direction: column; gap: .3rem; }
.med__label { font-size: .72rem; font-weight: 700; color: #374151; text-transform: uppercase; letter-spacing: .05em; }
.med__opt { font-size: .67rem; font-weight: 400; color: var(--c-slate-400); text-transform: none; letter-spacing: 0; }
.med__input { background: #fff; border: 1.5px solid var(--c-slate-300); border-radius: 9px; padding: .6rem .8rem; font-size: .875rem; color: var(--c-slate-900); width: 100%; box-sizing: border-box; outline: none; transition: border-color .15s, box-shadow .15s; }
.med__input:focus { border-color: #2D8A6B; box-shadow: 0 0 0 3px rgba(45,138,107,.12); background: #fff; }
.med__textarea { resize: vertical; min-height: 58px; }
.med__input-suffix-wrap { display: flex; }
.med__input--with-prefix { border-radius: 0 9px 9px 0; flex: 1; }
.med__input-prefix { background: var(--c-slate-100); border: 1.5px solid var(--c-slate-300); border-right: none; border-radius: 9px 0 0 9px; padding: .6rem .7rem; font-size: .8rem; color: var(--c-slate-500); display: flex; align-items: center; }

/* CC panel */
.med__cc-panel { border-radius: 10px; padding: .7rem .9rem; border: 1.5px solid var(--c-slate-200); display: flex; flex-direction: column; gap: .3rem; }
.med__cc-panel--ok           { background: #f0fdf4; border-color: #bbf7d0; }
.med__cc-panel--insuficiente { background: #fef2f2; border-color: #fecaca; }
.med__cc-panel--agotado      { background: #fef2f2; border-color: #fecaca; }
.med__cc-panel--critico      { background: #fffbeb; border-color: #fde68a; }
.med__cc-row { display: flex; align-items: center; justify-content: space-between; }
.med__cc-label { font-size: .75rem; font-weight: 700; color: #374151; display: flex; align-items: center; gap: .35rem; }
.med__cc-saldo { font-size: .9rem; font-weight: 800; color: #15803d; }
.med__cc-saldo--bajo { color: #dc2626; }
.med__cc-warn { font-size: .75rem; font-weight: 600; color: #dc2626; display: flex; align-items: center; gap: .3rem; }

/* Buttons */
.med__btn-primary { display: inline-flex; align-items: center; gap: .4rem; background: #1b5e20; color: #fff; border: none; padding: .6rem 1.1rem; border-radius: 9px; font-size: .82rem; font-weight: 600; cursor: pointer; transition: background .15s; white-space: nowrap; }
.med__btn-primary:hover:not(:disabled) { background: #144a18; }
.med__btn-primary:disabled { opacity: .5; cursor: not-allowed; }
.med__btn-ghost { background: #fff; color: var(--c-slate-500); border: 1.5px solid var(--c-slate-200); padding: .6rem 1.1rem; border-radius: 9px; font-size: .875rem; font-weight: 500; cursor: pointer; }
.med__btn-ghost:hover { background: var(--c-slate-50); }
</style>
