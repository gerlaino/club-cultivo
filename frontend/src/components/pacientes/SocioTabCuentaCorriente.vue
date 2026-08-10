<template>
  <div>
    <div v-if="loadingCC" class="scc__loading"><DsSpinner :size="40" /></div>
    <template v-else-if="cc">

      <!-- ── Tarjeta Configuración ──────────────────────────── -->
      <div class="scc__config-card">
        <div class="scc__config-card-title">Configuración financiera</div>

        <!-- Crédito en pesos -->
        <div class="scc__config-row">
          <div class="scc__config-info">
            <div class="scc__config-label">
              <i class="bi bi-cash-coin"></i>
              Crédito en pesos
            </div>
            <div v-if="creditoOn" class="scc__draft-input">
              <input type="number" min="0" step="100" v-model.number="draftLimite"
                class="scc__input" placeholder="ej: 50000" />
              <span class="scc__input-unit">ARS</span>
            </div>
            <span v-else class="scc__config-val-off">Sin crédito configurado</span>
          </div>
          <button v-if="!readonly"
            class="scc__toggle"
            :class="creditoOn ? 'scc__toggle--on' : 'scc__toggle--off'"
            @click="toggleCredito"
          >
            <span class="scc__toggle-knob"></span>
          </button>
          <span v-else-if="(cc.limite_credito ?? 0) > 0" class="scc__badge-activo">Activo</span>
        </div>

        <div class="scc__config-divider"></div>

        <!-- Descuento -->
        <div class="scc__config-row">
          <div class="scc__config-info">
            <div class="scc__config-label">
              <i class="bi bi-tag"></i>
              Descuento en dispensaciones
            </div>
            <div v-if="descuentoOn" class="scc__draft-input">
              <input type="number" min="0" max="100" step="1" v-model.number="draftDescuento"
                class="scc__input scc__input--sm" placeholder="ej: 10" />
              <span class="scc__input-unit">%</span>
            </div>
            <span v-else class="scc__config-val-off">Sin descuento</span>
          </div>
          <button v-if="!readonly"
            class="scc__toggle"
            :class="descuentoOn ? 'scc__toggle--on' : 'scc__toggle--off'"
            @click="toggleDescuento"
          >
            <span class="scc__toggle-knob"></span>
          </button>
          <span v-else-if="descuentoPorcentaje > 0" class="scc__badge-activo">{{ descuentoPorcentaje }}%</span>
        </div>

        <!-- Guardar cambios -->
        <Transition name="scc-save">
          <div v-if="hasChanges && !readonly" class="scc__save-row">
            <button class="scc__save-btn" :disabled="saving" @click="guardarCambios">
              {{ saving ? 'Guardando…' : 'Guardar cambios' }}
            </button>
            <button class="scc__discard-btn" :disabled="saving" @click="resetDraft">
              Descartar
            </button>
          </div>
        </Transition>
      </div>

      <!-- ── Estado de cuenta ───────────────────────────────── -->
      <div v-if="(cc.limite_credito ?? 0) > 0" class="scc__estado-card">
        <div class="scc__estado-row">
          <div class="scc__estado-block" :class="cc.saldo_disponible < 0 ? 'scc__estado-block--deuda' : ''">
            <span class="scc__estado-label">{{ cc.saldo_disponible < 0 ? 'Deuda actual' : 'Saldo a favor' }}</span>
            <span class="scc__estado-val" :class="cc.saldo_disponible < 0 ? 'scc__val--deuda' : cc.saldo_disponible > 0 ? 'scc__val--ok' : 'scc__val--zero'">
              {{ cc.saldo_disponible < 0 ? '−' : '' }}{{ fmtARS(Math.abs(cc.saldo_disponible)) }}
            </span>
          </div>
          <div class="scc__estado-block">
            <span class="scc__estado-label">Puede retirar aún</span>
            <span class="scc__estado-val" :class="!cc.limite_credito ? 'scc__val--zero' : ccMargen <= 0 ? 'scc__val--deuda' : ccMargen < cc.limite_credito * 0.2 ? 'scc__val--warn' : 'scc__val--ok'">
              {{ fmtARS(Math.max(0, ccMargen)) }}
            </span>
          </div>
        </div>

        <div v-if="cc.limite_credito > 0 && ccDeudaActual > 0" class="scc__progreso-wrap">
          <div class="scc__progreso-bar">
            <div class="scc__progreso-fill"
              :style="{ width: ccPorcentaje + '%' }"
              :class="ccPorcentaje >= 90 ? 'scc__progreso-fill--danger' : ccPorcentaje >= 70 ? 'scc__progreso-fill--warn' : ''">
            </div>
          </div>
          <span class="scc__progreso-pct">{{ ccPorcentaje }}% del crédito utilizado</span>
        </div>

        <!-- Registrar pago — disponible para admin y dispensador -->
        <button v-if="puedeCobrar" class="scc__pago-btn" @click="abrirPago">
          <i class="bi bi-cash-coin"></i> Registrar pago
        </button>
      </div>

      <!-- ── Historial ──────────────────────────────────────── -->
      <div class="scc__historial">
        <div class="scc__historial-title">Historial de movimientos</div>
        <div v-if="!cc.movimientos?.length" class="scc__empty">Sin movimientos registrados</div>
        <div v-else class="scc__movs">
          <div v-for="m in cc.movimientos" :key="m.id" class="scc__mov">
            <div class="scc__mov-tipo" :class="`scc__mov-tipo--${m.tipo}`">{{ m.tipo_label }}</div>
            <div class="scc__mov-desc">{{ m.descripcion || '—' }}</div>
            <div class="scc__mov-monto" :class="m.monto >= 0 ? 'scc__mov--pos' : 'scc__mov--neg'">
              {{ m.monto >= 0 ? '+' : '' }}{{ fmtARS(m.monto) }}
            </div>
            <div class="scc__mov-saldo">Saldo: {{ fmtARS(m.saldo_nuevo) }}</div>
            <div class="scc__mov-meta">{{ m.created_by }} · {{ new Date(m.created_at).toLocaleDateString('es-AR', { day:'numeric', month:'short', year:'numeric' }) }}</div>
          </div>
        </div>
      </div>

    </template>
    <div v-else class="scc__empty">No se pudo cargar la cuenta corriente.</div>

    <!-- Modal registrar pago -->
    <Teleport to="body">
      <div v-if="pagoOpen" class="scc__modal-overlay" @click.self="pagoOpen = false">
        <div class="scc__modal">
          <h3 class="scc__modal-title">Registrar pago</h3>
          <p v-if="ccDeudaActual > 0" class="scc__modal-deuda">
            Deuda actual: <strong>{{ fmtARS(ccDeudaActual) }}</strong>
          </p>
          <label class="scc__modal-label">Monto recibido</label>
          <div class="scc__draft-input">
            <input type="number" min="0" step="100" v-model.number="pagoMonto" class="scc__input" placeholder="0" autofocus />
            <span class="scc__input-unit">ARS</span>
          </div>
          <label class="scc__modal-label">Medio de pago</label>
          <select v-model="pagoMedio" class="scc__input">
            <option value="efectivo">Efectivo</option>
            <option value="transferencia">Transferencia</option>
            <option value="mercado_pago">Mercado Pago</option>
          </select>
          <p v-if="pagoMonto > ccDeudaActual && ccDeudaActual >= 0" class="scc__modal-hint">
            Quedará <strong>{{ fmtARS(pagoMonto - ccDeudaActual) }}</strong> a favor del paciente.
          </p>
          <div class="scc__modal-actions">
            <button class="scc__discard-btn" :disabled="pagando" @click="pagoOpen = false">Cancelar</button>
            <button class="scc__save-btn" :disabled="pagando || !(pagoMonto > 0)" @click="confirmarPago">
              {{ pagando ? 'Registrando…' : 'Registrar pago' }}
            </button>
          </div>
        </div>
      </div>
    </Teleport>
  </div>
</template>

<script setup>
import { ref, computed, watch, onMounted } from 'vue'
import DsSpinner from '../../design-system/components/Spinner.vue'
import { useSocioCuentaCorriente } from '../../composables/useSocioCuentaCorriente.js'
import { useToast } from '../../composables/useToast.js'
import { setLimiteCC, updatePaciente, registrarPagoCC } from '../../lib/api.js'
import { usePacientesStore } from '../../stores/pacientes'
import { useAuthStore } from '../../stores/auth.js'

const props = defineProps({
  socioId:    { type: Number,  required: true },
  refreshKey: { type: Number,  default: 0 },
  readonly:   { type: Boolean, default: false },
})

const { success: toastOk, error: toastErr } = useToast()
const store = usePacientesStore()
const auth  = useAuthStore()

const {
  cc, loadingCC,
  descuentoPorcentaje,
  fmtARS, ccDeudaActual, ccMargen, ccPorcentaje,
  loadCC,
} = useSocioCuentaCorriente(props.socioId)

// ── Registrar pago (admin + dispensador) ───────────────────
const puedeCobrar = computed(() => ['admin', 'super_admin', 'dispensador', 'supervisor'].includes(auth.user?.role))
const pagoOpen    = ref(false)
const pagoMonto   = ref(null)
const pagoMedio   = ref('efectivo')
const pagando     = ref(false)

function abrirPago() {
  pagoMonto.value = ccDeudaActual.value > 0 ? ccDeudaActual.value : null
  pagoMedio.value = 'efectivo'
  pagoOpen.value  = true
}

async function confirmarPago() {
  if (!(pagoMonto.value > 0)) return
  pagando.value = true
  try {
    const { data } = await registrarPagoCC(props.socioId, { monto: pagoMonto.value, medio_pago: pagoMedio.value })
    cc.value = data
    pagoOpen.value = false
    await store.fetchOne(props.socioId)
    toastOk('Pago registrado')
  } catch (e) {
    toastErr(e?.response?.data?.error || 'No se pudo registrar el pago')
  } finally {
    pagando.value = false
  }
}

// ── Draft state ────────────────────────────────────────────
// El on/off es estado explícito (ref), no se deriva del valor: si fuera
// derivado, encender el toggle con valor 0 no tendría ningún efecto visible.
const draftLimite    = ref(0)
const draftDescuento = ref(0)
const creditoOn      = ref(false)
const descuentoOn    = ref(false)
const saving         = ref(false)

// Inicializar draft cuando carga cc
watch(cc, (val) => {
  if (val) {
    draftLimite.value    = val.limite_credito ?? 0
    draftDescuento.value = store.current?.descuento_porcentaje ?? 0
    creditoOn.value      = (val.limite_credito ?? 0) > 0
    descuentoOn.value    = (store.current?.descuento_porcentaje ?? 0) > 0
  }
}, { immediate: true })

watch(descuentoPorcentaje, (val) => {
  if (!hasChanges.value) {
    draftDescuento.value = val
    descuentoOn.value    = (val ?? 0) > 0
  }
})

// Valor efectivo que se guardaría: toggle apagado = 0
const limiteEfectivo    = computed(() => creditoOn.value   ? (draftLimite.value    || 0) : 0)
const descuentoEfectivo = computed(() => descuentoOn.value ? (draftDescuento.value || 0) : 0)

const hasChanges = computed(() =>
  limiteEfectivo.value    !== (cc.value?.limite_credito ?? 0) ||
  descuentoEfectivo.value !== (descuentoPorcentaje.value ?? 0)
)

function toggleCredito() {
  creditoOn.value = !creditoOn.value
  if (creditoOn.value) {
    // Restaurar valor previo si existía; si no, dejar el input vacío para tipear
    draftLimite.value = (cc.value?.limite_credito ?? 0) > 0 ? cc.value.limite_credito : null
  }
}

function toggleDescuento() {
  descuentoOn.value = !descuentoOn.value
  if (descuentoOn.value) {
    draftDescuento.value = (descuentoPorcentaje.value ?? 0) > 0 ? descuentoPorcentaje.value : null
  }
}

function resetDraft() {
  draftLimite.value    = cc.value?.limite_credito ?? 0
  draftDescuento.value = descuentoPorcentaje.value ?? 0
  creditoOn.value      = (cc.value?.limite_credito ?? 0) > 0
  descuentoOn.value    = (descuentoPorcentaje.value ?? 0) > 0
}

async function guardarCambios() {
  saving.value = true
  try {
    const limiteChanged    = limiteEfectivo.value    !== (cc.value?.limite_credito ?? 0)
    const descuentoChanged = descuentoEfectivo.value !== (descuentoPorcentaje.value ?? 0)

    const promises = []
    if (limiteChanged)    promises.push(setLimiteCC(props.socioId, limiteEfectivo.value))
    if (descuentoChanged) promises.push(updatePaciente(props.socioId, { descuento_porcentaje: descuentoEfectivo.value }))

    const results = await Promise.all(promises)

    // Actualizar cc con la respuesta del setLimiteCC si aplica
    if (limiteChanged && results[0]?.data) cc.value = results[0].data

    await store.fetchOne(props.socioId)
    // Refrescar cc completo para que saldo/historial sean frescos
    cc.value = null
    await loadCC()

    toastOk('Configuración guardada')
  } catch (e) {
    toastErr(e?.response?.data?.error || 'Error al guardar')
  } finally {
    saving.value = false
  }
}

onMounted(() => loadCC())
watch(() => props.refreshKey, (v, old) => { if (v !== old) loadCC() })
</script>

<style scoped>
.scc__loading { display: flex; align-items: center; justify-content: center; padding: 2rem; }
.scc__empty   { text-align: center; color: var(--c-slate-400); font-size: .875rem; padding: 1.5rem; }

/* ── Configuración ──────────────────────────────────────── */
.scc__config-card {
  background: #fff; border: 1.5px solid var(--c-slate-200); border-radius: 14px;
  overflow: hidden; margin-bottom: 1rem;
}
.scc__config-card-title {
  font-size: .7rem; font-weight: 700; text-transform: uppercase; letter-spacing: .07em;
  color: var(--c-slate-400); padding: .875rem 1.1rem .5rem;
}
.scc__config-divider { height: 1px; background: var(--c-slate-100); margin: 0 1.1rem; }

.scc__config-row {
  display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem;
  padding: .875rem 1.1rem;
}
.scc__config-info { flex: 1; min-width: 0; display: flex; flex-direction: column; gap: .35rem; }
.scc__config-label {
  font-size: .82rem; font-weight: 700; color: var(--c-slate-700);
  display: flex; align-items: center; gap: .4rem;
}
.scc__config-label i { color: var(--c-slate-400); font-size: .85rem; }
.scc__config-val-off { font-size: .82rem; color: var(--c-slate-400); }

/* Draft input */
.scc__draft-input {
  display: flex; align-items: center; gap: .4rem;
}
.scc__input {
  font-size: .92rem; font-weight: 600; font-variant-numeric: tabular-nums;
  border: 1.5px solid var(--c-slate-300); border-radius: 8px;
  padding: .35rem .6rem; width: 9rem; color: #1e293b; background: var(--c-slate-50); outline: none;
  transition: border-color .15s, box-shadow .15s;
}
.scc__input--sm { width: 5rem; }
.scc__input:focus { border-color: #2D8A6B; box-shadow: 0 0 0 3px rgba(45,138,107,.12); background: #fff; }
.scc__input-unit { font-size: .78rem; font-weight: 700; color: var(--c-slate-500); }

/* Guardar cambios */
.scc__save-row {
  display: flex; align-items: center; gap: .75rem;
  padding: .875rem 1.1rem;
  background: #f0fdf4; border-top: 1px solid #bbf7d0;
}
.scc__save-btn {
  background: #15803d; color: #fff; border: none; border-radius: 8px;
  padding: .45rem 1.2rem; font-size: .82rem; font-weight: 700; cursor: pointer;
  transition: background .15s;
}
.scc__save-btn:hover:not(:disabled) { background: #166534; }
.scc__save-btn:disabled { opacity: .55; cursor: not-allowed; }
.scc__discard-btn {
  background: none; color: var(--c-slate-500); border: 1px solid var(--c-slate-300); border-radius: 8px;
  padding: .4rem .9rem; font-size: .82rem; cursor: pointer; transition: all .15s;
}
.scc__discard-btn:hover:not(:disabled) { background: var(--c-slate-100); color: var(--c-slate-700); }
.scc__discard-btn:disabled { opacity: .5; cursor: not-allowed; }

/* Registrar pago */
.scc__pago-btn {
  margin-top: 1rem; width: 100%; display: inline-flex; align-items: center; justify-content: center; gap: .5rem;
  background: #15803d; color: #fff; border: none; border-radius: 9px;
  padding: .6rem 1rem; font-size: .85rem; font-weight: 700; cursor: pointer; transition: background .15s;
}
.scc__pago-btn:hover { background: #166534; }
.scc__modal-overlay {
  position: fixed; inset: 0; background: rgba(15,23,42,.45); z-index: 900;
  display: flex; align-items: center; justify-content: center; padding: 1rem;
}
.scc__modal { background: #fff; border-radius: 14px; padding: 1.5rem; width: 100%; max-width: 380px; box-shadow: 0 20px 60px rgba(0,0,0,.2); }
.scc__modal-title { font-size: 1.05rem; font-weight: 800; color: var(--c-slate-900); margin: 0 0 .5rem; }
.scc__modal-deuda { font-size: .82rem; color: #b45309; margin: 0 0 1rem; }
.scc__modal-label { display: block; font-size: .75rem; font-weight: 700; color: var(--c-slate-500); margin: .75rem 0 .3rem; }
.scc__modal-hint { font-size: .78rem; color: #15803d; margin: .6rem 0 0; }
.scc__modal-actions { display: flex; justify-content: flex-end; gap: .5rem; margin-top: 1.25rem; }

/* Save transition */
.scc-save-enter-active, .scc-save-leave-active { transition: all .25s ease; }
.scc-save-enter-from, .scc-save-leave-to { opacity: 0; transform: translateY(-6px); }

/* Toggle switch */
.scc__toggle {
  position: relative; width: 38px; height: 22px; border-radius: 999px;
  border: none; cursor: pointer; transition: background .2s; padding: 0; flex-shrink: 0;
  margin-top: 2px;
}
.scc__toggle--off { background: var(--c-slate-300); }
.scc__toggle--on  { background: #15803d; }
.scc__toggle:disabled { opacity: .6; cursor: not-allowed; }
.scc__toggle-knob {
  position: absolute; top: 3px; width: 16px; height: 16px;
  background: #fff; border-radius: 50%; transition: left .2s;
  box-shadow: 0 1px 3px rgba(0,0,0,.2);
}
.scc__toggle--off .scc__toggle-knob { left: 3px; }
.scc__toggle--on  .scc__toggle-knob { left: 19px; }

.scc__badge-activo {
  font-size: .68rem; font-weight: 700; background: #dcfce7; color: #15803d;
  padding: .2rem .55rem; border-radius: 999px; white-space: nowrap;
}

/* ── Estado de cuenta ───────────────────────────────────── */
.scc__estado-card {
  background: var(--c-slate-50); border: 1.5px solid var(--c-slate-200); border-radius: 14px;
  padding: 1rem 1.1rem; margin-bottom: 1rem; display: flex; flex-direction: column; gap: .875rem;
}
.scc__estado-row { display: flex; gap: 1rem; }
.scc__estado-block { flex: 1; display: flex; flex-direction: column; gap: .2rem; }
.scc__estado-label { font-size: .7rem; font-weight: 600; color: var(--c-slate-500); text-transform: uppercase; letter-spacing: .04em; }
.scc__estado-val   { font-size: 1.4rem; font-weight: 800; letter-spacing: -.03em; font-variant-numeric: tabular-nums; color: var(--c-slate-900); }
.scc__val--ok   { color: #15803d; }
.scc__val--zero { color: var(--c-slate-400); }
.scc__val--deuda { color: #dc2626; }
.scc__val--warn  { color: #d97706; }

/* Progress */
.scc__progreso-wrap { display: flex; align-items: center; gap: .75rem; }
.scc__progreso-bar  { flex: 1; height: 6px; background: var(--c-slate-200); border-radius: 999px; overflow: hidden; }
.scc__progreso-fill { height: 100%; background: #15803d; border-radius: 999px; transition: width .4s; }
.scc__progreso-fill--warn   { background: #d97706; }
.scc__progreso-fill--danger { background: #dc2626; }
.scc__progreso-pct  { font-size: .72rem; color: var(--c-slate-400); white-space: nowrap; font-variant-numeric: tabular-nums; }

/* ── Historial ───────────────────────────────────────────── */
.scc__historial       { margin-top: 1rem; }
.scc__historial-title { font-size: .7rem; font-weight: 700; color: var(--c-slate-400); text-transform: uppercase; letter-spacing: .07em; margin-bottom: .75rem; }
.scc__movs { display: flex; flex-direction: column; gap: 0; border: 1.5px solid var(--c-slate-200); border-radius: 12px; overflow: hidden; }
.scc__mov {
  display: grid; grid-template-columns: auto 1fr auto;
  grid-template-rows: auto auto; gap: .1rem .75rem;
  padding: .8rem 1rem; border-bottom: 1px solid var(--c-slate-100); font-size: .82rem;
}
.scc__mov:last-child { border-bottom: none; }
.scc__mov-tipo { grid-column: 1; grid-row: 1; font-size: .68rem; font-weight: 700; padding: .15rem .5rem; border-radius: 999px; white-space: nowrap; align-self: center; }
.scc__mov-tipo--carga  { background: #f0fdf4; color: #15803d; }
.scc__mov-tipo--debito { background: #fef2f2; color: #dc2626; }
.scc__mov-tipo--ajuste { background: #fffbeb; color: #b45309; }
.scc__mov-tipo--pago   { background: #eff6ff; color: #2563eb; }
.scc__mov-desc   { grid-column: 2; grid-row: 1; color: var(--c-slate-600); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.scc__mov-monto  { grid-column: 3; grid-row: 1; font-weight: 700; font-variant-numeric: tabular-nums; letter-spacing: -.01em; text-align: right; white-space: nowrap; }
.scc__mov--pos   { color: #15803d; }
.scc__mov--neg   { color: #dc2626; }
.scc__mov-saldo  { grid-column: 2; grid-row: 2; font-variant-numeric: tabular-nums; font-size: .72rem; color: var(--c-slate-400); }
.scc__mov-meta   { grid-column: 3; grid-row: 2; font-size: .7rem; color: var(--c-slate-400); text-align: right; }
</style>
