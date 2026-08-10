<script setup>
// Caja del turno con confirmación entre roles (B5 del rediseño del Salón).
// Una sola pantalla, reachable desde el chip de caja de BarNav en cualquier vista del bar.
// La acción disponible depende del rol y del estado de la caja:
//   sin caja      → gestión abre (fondo);            operador espera.
//   abierta !conf → operador confirma el fondo;       gestión espera / cierra directo.
//   abierta  conf → operador envía el cierre (cuenta);gestión cierra directo.
//   pendiente     → gestión confirma el cierre;       operador espera el visto.
import { ref, computed, onMounted } from 'vue'
import { useBarStore } from '../../stores/bar.js'
import { useAuthStore } from '../../stores/auth.js'
import { useToast } from '../../composables/useToast.js'

const props = defineProps({ barId: { type: [String, Number], required: true } })
const emit = defineEmits(['close'])

const store = useBarStore()
const auth = useAuthStore()
const toast = useToast()

const esGestion = computed(() => ['admin', 'supervisor'].includes(auth.user?.role))
const caja = computed(() => store.cajaActiva)
const rol = computed(() => auth.user?.role)

const fmt = (n) => `$${Math.round(n || 0).toLocaleString('es-AR')}`

// ── Formularios locales ──
const fondo = ref(null)              // abrir: fondo inicial
const contado = ref(null)            // enviar/cerrar: efectivo contado
const notas = ref('')

const diferencia = computed(() => {
  if (contado.value === null || contado.value === '' || !caja.value) return null
  return Number(contado.value) - (caja.value.efectivo_esperado_ars || 0)
})
const difLabel = (d) => d === 0 ? 'Cuadra exacto' : (d > 0 ? `Sobra ${fmt(d)}` : `Falta ${fmt(Math.abs(d))}`)
const difClase = (d) => d === 0 ? 'ok' : (d > 0 ? 'sobra' : 'falta')

onMounted(() => { if (!store.cajaLoading) store.fetchCajaActual(props.barId) })

async function accion(fn, ok) {
  try { await fn(); toast.success(ok) }
  catch { toast.error(store.saveError || 'No se pudo completar') }
}

const abrir = () => {
  const m = Number(fondo.value) || 0
  return accion(() => store.abrirCaja(props.barId, m), 'Caja abierta').then(() => { fondo.value = null })
}
const confirmarFondo = () => accion(() => store.confirmarApertura(props.barId, caja.value.id), 'Fondo confirmado')
const enviarCierre = () => {
  if (contado.value === null || contado.value === '') { toast.warning('Ingresá el efectivo contado'); return }
  return accion(() => store.solicitarCierre(props.barId, caja.value.id, { efectivo_declarado_ars: Number(contado.value), notas: notas.value || undefined }), 'Cierre enviado para confirmar')
}
const confirmarCierre = () => accion(() => store.confirmarCierre(props.barId, caja.value.id), 'Caja cerrada')
const cerrarDirecto = () => {
  if (contado.value === null || contado.value === '') { toast.warning('Ingresá el efectivo contado'); return }
  return accion(() => store.cerrarCaja(props.barId, caja.value.id, { efectivo_declarado_ars: Number(contado.value), notas: notas.value || undefined }), 'Caja cerrada')
}

// Qué "escena" mostrar
const escena = computed(() => {
  const c = caja.value
  if (!c) return 'sin_caja'
  if (c.estado === 'pendiente_cierre') return 'pendiente'
  if (c.estado === 'abierta' && !c.apertura_confirmada) return 'sin_confirmar'
  return 'abierta' // abierta + confirmada
})
</script>

<template>
  <div class="cs__ov" @click.self="emit('close')">
    <div class="cs">
      <div class="cs__head">
        <h3 class="cs__title">Caja del turno</h3>
        <button class="cs__x" @click="emit('close')" aria-label="Cerrar">×</button>
      </div>

      <!-- Resumen del estado actual (siempre que haya caja) -->
      <div v-if="caja" class="cs__estado" :class="`is-${escena}`">
        <span class="cs__dot"></span>
        <span>
          {{ escena === 'pendiente' ? 'Cierre pendiente de confirmar'
             : escena === 'sin_confirmar' ? 'Abierta — falta confirmar el fondo'
             : 'Caja abierta' }}
        </span>
      </div>

      <!-- SIN CAJA ------------------------------------------------->
      <template v-if="escena === 'sin_caja'">
        <template v-if="esGestion">
          <p class="cs__hint">El fondo inicial es el efectivo con el que arranca la caja. Al cerrar se cuenta y se compara.</p>
          <label class="cs__fld">Fondo inicial (efectivo)
            <input v-model.number="fondo" type="number" min="0" step="any" class="cs__inp" placeholder="$0" />
          </label>
          <button class="cs__btn cs__btn--brand cs__btn--wide" :disabled="store.saving" @click="abrir">Abrir caja</button>
        </template>
        <p v-else class="cs__wait">Todavía no hay una caja abierta. La abre el encargado del salón.</p>
      </template>

      <!-- ABIERTA, SIN CONFIRMAR EL FONDO ------------------------->
      <template v-else-if="escena === 'sin_confirmar'">
        <div class="cs__box">
          <div class="cs__row"><span>Fondo declarado por {{ caja.abierta_por || 'gestión' }}</span><b class="num">{{ fmt(caja.monto_inicial_ars) }}</b></div>
        </div>
        <template v-if="!esGestion">
          <p class="cs__hint">Contá el efectivo del cajón. Si coincide con el fondo, confirmá para arrancar el turno.</p>
          <button class="cs__btn cs__btn--brand cs__btn--wide" :disabled="store.saving" @click="confirmarFondo">Confirmar fondo ({{ fmt(caja.monto_inicial_ars) }})</button>
        </template>
        <p v-else class="cs__wait">Esperando que el dispensador confirme el fondo.</p>
        <div v-if="esGestion" class="cs__sep">o cerrá directo</div>
        <template v-if="esGestion">
          <label class="cs__fld">Efectivo contado
            <input v-model.number="contado" type="number" min="0" step="any" class="cs__inp" placeholder="$0" />
          </label>
          <button class="cs__btn cs__btn--wide" :disabled="store.saving" @click="cerrarDirecto">Cerrar caja</button>
        </template>
      </template>

      <!-- ABIERTA Y CONFIRMADA: arqueo / envío de cierre ---------->
      <template v-else-if="escena === 'abierta'">
        <div class="cs__box">
          <div class="cs__row"><span>Fondo inicial</span><b class="num">{{ fmt(caja.monto_inicial_ars) }}</b></div>
          <div class="cs__row"><span>Ventas en efectivo</span><b class="num">{{ fmt(caja.total_efectivo_ars) }}</b></div>
          <div class="cs__row cs__row--tot"><span>Efectivo esperado</span><b class="num">{{ fmt(caja.efectivo_esperado_ars) }}</b></div>
        </div>
        <label class="cs__fld">Efectivo contado
          <input v-model.number="contado" type="number" min="0" step="any" class="cs__inp" placeholder="$0" />
        </label>
        <div v-if="diferencia !== null" class="cs__dif" :class="difClase(diferencia)">{{ difLabel(diferencia) }}</div>
        <label class="cs__fld">Notas (opcional)
          <input v-model.trim="notas" class="cs__inp" placeholder="Ej: diferencia por vuelto" maxlength="120" />
        </label>
        <!-- El operador ENVÍA el cierre (queda pendiente); gestión cierra directo. -->
        <button v-if="esGestion" class="cs__btn cs__btn--brand cs__btn--wide" :disabled="store.saving" @click="cerrarDirecto">Cerrar caja</button>
        <button v-else class="cs__btn cs__btn--brand cs__btn--wide" :disabled="store.saving" @click="enviarCierre">Enviar cierre para confirmar</button>
      </template>

      <!-- PENDIENTE DE CIERRE ------------------------------------->
      <template v-else-if="escena === 'pendiente'">
        <div class="cs__box">
          <div class="cs__row"><span>Efectivo esperado</span><b class="num">{{ fmt(caja.efectivo_esperado_ars) }}</b></div>
          <div class="cs__row"><span>Efectivo contado {{ caja.cierre_solicitado_por ? `por ${caja.cierre_solicitado_por}` : '' }}</span><b class="num">{{ fmt(caja.efectivo_declarado_ars) }}</b></div>
          <div class="cs__row cs__row--tot">
            <span>Diferencia</span>
            <b class="num" :class="difClase(caja.diferencia_ars)">{{ difLabel(caja.diferencia_ars) }}</b>
          </div>
        </div>
        <p v-if="caja.notas" class="cs__notas">“{{ caja.notas }}”</p>
        <template v-if="esGestion">
          <p class="cs__hint">Revisá el arqueo y confirmá el cierre para asentarlo.</p>
          <button class="cs__btn cs__btn--brand cs__btn--wide" :disabled="store.saving" @click="confirmarCierre">Confirmar cierre</button>
        </template>
        <p v-else class="cs__wait">Cierre enviado. Esperando el visto del encargado del salón.</p>
      </template>
    </div>
  </div>
</template>

<style scoped>
.num { font-variant-numeric: tabular-nums; }
.cs__ov { position: fixed; inset: 0; background: rgb(15 23 42 / .5); backdrop-filter: blur(2px); display: grid; place-items: center; z-index: 1100; padding: 1rem; }
.cs { background: #fff; border-radius: 16px; padding: 1.4rem 1.5rem 1.5rem; width: 100%; max-width: 400px; box-shadow: 0 20px 50px rgb(15 23 42 / .25); }
.cs__head { display: flex; align-items: center; justify-content: space-between; margin-bottom: 1rem; }
.cs__title { margin: 0; font-size: 1.15rem; font-weight: 750; letter-spacing: -.02em; color: var(--c-slate-900); }
.cs__x { background: none; border: none; font-size: 1.5rem; line-height: 1; color: var(--c-slate-400); cursor: pointer; padding: 0 .2rem; }
.cs__x:hover { color: var(--c-slate-700); }

.cs__estado { display: inline-flex; align-items: center; gap: .5rem; font-size: .78rem; font-weight: 650; padding: .35rem .75rem; border-radius: 999px; margin-bottom: 1rem; }
.cs__dot { width: 8px; height: 8px; border-radius: 50%; }
.cs__estado.is-abierta { background: #effaf1; color: #15803d; }
.cs__estado.is-abierta .cs__dot { background: #15803d; }
.cs__estado.is-sin_confirmar { background: #fef3c7; color: #b45309; }
.cs__estado.is-sin_confirmar .cs__dot { background: #d97706; }
.cs__estado.is-pendiente { background: #eff6ff; color: #1d4ed8; }
.cs__estado.is-pendiente .cs__dot { background: #2563eb; }

.cs__box { background: var(--c-slate-50); border: 1px solid var(--c-slate-100); border-radius: 10px; padding: .7rem .9rem; margin-bottom: 1rem; }
.cs__row { display: flex; justify-content: space-between; gap: 1rem; font-size: .84rem; color: var(--c-slate-600); padding: .25rem 0; }
.cs__row b { color: var(--c-slate-900); font-weight: 700; }
.cs__row--tot { border-top: 1px solid var(--c-slate-200); margin-top: .25rem; padding-top: .5rem; font-weight: 700; }
.cs__row--tot b.ok { color: #15803d; } .cs__row--tot b.sobra { color: #1d4ed8; } .cs__row--tot b.falta { color: #dc2626; }

.cs__fld { display: flex; flex-direction: column; gap: .35rem; font-size: .82rem; color: var(--c-slate-600); margin-bottom: .9rem; font-weight: 600; }
.cs__inp { background: #fff; border: 1.5px solid var(--c-slate-200); border-radius: 9px; padding: .55rem .75rem; font-size: .9rem; color: var(--c-slate-900); outline: none; }
.cs__inp:focus { border-color: #9a5b34; }
.cs__hint { color: var(--c-slate-500); font-size: .82rem; margin: 0 0 1rem; line-height: 1.45; }
.cs__wait { color: var(--c-slate-500); font-size: .86rem; margin: .4rem 0 0; line-height: 1.5; text-align: center; background: var(--c-slate-50); border: 1px dashed var(--c-slate-200); border-radius: 10px; padding: .9rem; }
.cs__notas { font-size: .82rem; color: var(--c-slate-500); font-style: italic; margin: -.4rem 0 1rem; }
.cs__sep { text-align: center; font-size: .74rem; color: var(--c-slate-400); text-transform: uppercase; letter-spacing: .05em; margin: 1rem 0 .8rem; position: relative; }

.cs__dif { text-align: center; font-size: .85rem; font-weight: 700; padding: .55rem; border-radius: 9px; margin-bottom: .9rem; }
.cs__dif.ok { background: #effaf1; color: #15803d; }
.cs__dif.sobra { background: #eff6ff; color: #1d4ed8; }
.cs__dif.falta { background: #fdecec; color: #dc2626; }

.cs__btn { display: inline-flex; align-items: center; justify-content: center; gap: .35rem; background: #fff; color: var(--c-slate-600); border: 1.5px solid var(--c-slate-200); padding: .6rem 1rem; border-radius: 10px; font-size: .88rem; font-weight: 650; cursor: pointer; }
.cs__btn:hover { border-color: var(--c-slate-300); color: var(--c-slate-700); }
.cs__btn--brand { background: #9a5b34; border-color: #9a5b34; color: #fff; }
.cs__btn--brand:hover { background: #824b2c; color: #fff; }
.cs__btn--wide { width: 100%; }
.cs__btn:disabled { opacity: .55; cursor: default; }
</style>
