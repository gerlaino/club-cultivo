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
            <div class="scc__config-value">
              <template v-if="(cc.limite_credito ?? 0) > 0">
                <template v-if="!limiteEditOpen">
                  <span class="scc__config-val-text">{{ fmtARS(cc.limite_credito) }}</span>
                  <button v-if="!readonly" class="scc__config-edit-btn" @click="openLimiteEdit" title="Editar">
                    <Pencil :size="12" :stroke-width="2" />
                  </button>
                </template>
                <div v-else class="scc__inline-form">
                  <input type="number" min="0" step="100" v-model.number="limiteEditVal"
                    class="scc__inline-input" placeholder="0"
                    @keydown.enter="saveLimite" @keydown.esc="limiteEditOpen = false" autofocus />
                  <button class="scc__inline-ok" :disabled="savingLimite" @click="saveLimite">
                    {{ savingLimite ? '…' : 'OK' }}
                  </button>
                  <button class="scc__inline-cancel" @click="limiteEditOpen = false">✕</button>
                </div>
              </template>
              <span v-else class="scc__config-val-off">Sin crédito configurado</span>
            </div>
          </div>
          <button v-if="!readonly"
            class="scc__toggle"
            :class="(cc.limite_credito ?? 0) > 0 ? 'scc__toggle--on' : 'scc__toggle--off'"
            :disabled="savingLimite"
            @click="toggleLimite"
            :title="(cc.limite_credito ?? 0) > 0 ? 'Desactivar crédito' : 'Activar crédito'"
          >
            <span class="scc__toggle-knob"></span>
          </button>
          <div v-else>
            <span v-if="(cc.limite_credito ?? 0) > 0" class="scc__badge-activo">Activo</span>
          </div>
        </div>

        <div class="scc__config-divider"></div>

        <!-- Cupo en gramos -->
        <div class="scc__config-row">
          <div class="scc__config-info">
            <div class="scc__config-label">
              <i class="bi bi-flower1"></i>
              Cupo en gramos
            </div>
            <div class="scc__config-value">
              <template v-if="cc.credito_gramos_activo">
                <!-- Límite -->
                <div class="scc__config-gramos-row">
                  <template v-if="!limiteGOpen">
                    <span class="scc__config-val-text">{{ cc.limite_credito_g ? cc.limite_credito_g.toFixed(1) + 'g máx.' : 'Sin tope' }}</span>
                    <button v-if="!readonly" class="scc__config-edit-btn" @click="limiteGOpen = true; limiteGVal = cc.limite_credito_g ?? null" title="Editar tope">
                      <Pencil :size="12" :stroke-width="2" />
                    </button>
                  </template>
                  <div v-else class="scc__inline-form">
                    <input type="number" min="0" step="0.5" v-model.number="limiteGVal"
                      class="scc__inline-input scc__inline-input--sm" placeholder="ej: 40"
                      @keydown.enter="saveLimiteG" @keydown.esc="limiteGOpen = false" autofocus />
                    <span class="scc__inline-unit">g</span>
                    <button class="scc__inline-ok" :disabled="savingLimiteG" @click="saveLimiteG">
                      {{ savingLimiteG ? '…' : 'OK' }}
                    </button>
                    <button class="scc__inline-cancel" @click="limiteGOpen = false">✕</button>
                  </div>
                </div>
                <!-- Saldo disponible + acreditar -->
                <div class="scc__config-gramos-saldo">
                  <span class="scc__config-saldo-val" :class="cc.saldo_disponible_g <= 0 ? 'scc__saldo--agotado' : 'scc__saldo--ok'">
                    {{ (cc.saldo_disponible_g ?? 0).toFixed(1) }}g disponibles
                  </span>
                  <template v-if="!readonly">
                    <template v-if="!cargarGOpen">
                      <button class="scc__acreditar-btn" @click="cargarGOpen = true; cargarGVal = null">
                        + Acreditar gramos
                      </button>
                    </template>
                    <div v-else class="scc__inline-form">
                      <input type="number" min="0.1" step="0.5" v-model.number="cargarGVal"
                        class="scc__inline-input scc__inline-input--sm" placeholder="ej: 20"
                        @keydown.enter="doCargarG" @keydown.esc="cargarGOpen = false" />
                      <span class="scc__inline-unit">g</span>
                      <button class="scc__inline-ok" :disabled="savingCargarG" @click="doCargarG">
                        {{ savingCargarG ? '…' : 'OK' }}
                      </button>
                      <button class="scc__inline-cancel" @click="cargarGOpen = false">✕</button>
                    </div>
                  </template>
                </div>
              </template>
              <span v-else class="scc__config-val-off">Sin cupo configurado</span>
            </div>
          </div>
          <button v-if="!readonly"
            class="scc__toggle"
            :class="cc.credito_gramos_activo ? 'scc__toggle--on' : 'scc__toggle--off'"
            :disabled="togglingGramos"
            @click="toggleGramos"
            :title="cc.credito_gramos_activo ? 'Desactivar cupo en gramos' : 'Activar cupo en gramos'"
          >
            <span class="scc__toggle-knob"></span>
          </button>
          <span v-else-if="cc.credito_gramos_activo" class="scc__badge-activo">Activo</span>
        </div>

        <div class="scc__config-divider"></div>

        <!-- Descuento -->
        <div class="scc__config-row">
          <div class="scc__config-info">
            <div class="scc__config-label">
              <i class="bi bi-tag"></i>
              Descuento en dispensaciones
            </div>
            <div class="scc__config-value">
              <template v-if="descuentoPorcentaje > 0">
                <template v-if="!descuentoEditOpen">
                  <span class="scc__config-val-text scc__config-val-text--discount">{{ descuentoPorcentaje }}%</span>
                  <button v-if="!readonly" class="scc__config-edit-btn" @click="openDescuentoEdit" title="Editar descuento">
                    <Pencil :size="12" :stroke-width="2" />
                  </button>
                </template>
                <div v-else class="scc__inline-form">
                  <input type="number" min="0" max="100" step="1" v-model.number="descuentoEditVal"
                    class="scc__inline-input scc__inline-input--sm" placeholder="0"
                    @keydown.enter="saveDescuento" @keydown.esc="descuentoEditOpen = false" autofocus />
                  <span class="scc__inline-unit">%</span>
                  <button class="scc__inline-ok" :disabled="savingDescuento" @click="saveDescuento">
                    {{ savingDescuento ? '…' : 'OK' }}
                  </button>
                  <button class="scc__inline-cancel" @click="descuentoEditOpen = false">✕</button>
                </div>
              </template>
              <span v-else class="scc__config-val-off">Sin descuento</span>
            </div>
          </div>
          <button v-if="!readonly"
            class="scc__toggle"
            :class="descuentoPorcentaje > 0 ? 'scc__toggle--on' : 'scc__toggle--off'"
            :disabled="savingDescuento"
            @click="toggleDescuento"
            :title="descuentoPorcentaje > 0 ? 'Quitar descuento' : 'Activar descuento'"
          >
            <span class="scc__toggle-knob"></span>
          </button>
          <span v-else-if="descuentoPorcentaje > 0" class="scc__badge-activo">{{ descuentoPorcentaje }}%</span>
        </div>
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
  </div>
</template>

<script setup>
import { onMounted, watch } from 'vue'
import { Pencil } from 'lucide-vue-next'
import DsSpinner from '../../design-system/components/Spinner.vue'
import { useSocioCuentaCorriente } from '../../composables/useSocioCuentaCorriente.js'

const props = defineProps({
  socioId:    { type: Number,  required: true },
  refreshKey: { type: Number,  default: 0 },
  readonly:   { type: Boolean, default: false },
})

const {
  cc, loadingCC,
  limiteEditOpen, limiteEditVal, savingLimite,
  togglingGramos,
  limiteGOpen, limiteGVal, savingLimiteG,
  cargarGOpen, cargarGVal, savingCargarG,
  descuentoPorcentaje, descuentoEditOpen, descuentoEditVal, savingDescuento,
  fmtARS, ccDeudaActual, ccMargen, ccPorcentaje,
  loadCC, toggleLimite, openLimiteEdit, saveLimite,
  toggleGramos, saveLimiteG, doCargarG,
  toggleDescuento, openDescuentoEdit, saveDescuento,
} = useSocioCuentaCorriente(props.socioId)

onMounted(() => loadCC())
watch(() => props.refreshKey, (v, old) => { if (v !== old) loadCC() })
</script>

<style scoped>
.scc__loading { display: flex; align-items: center; justify-content: center; padding: 2rem; }
.scc__empty   { text-align: center; color: #94a3b8; font-size: .875rem; padding: 1.5rem; }

/* ── Configuración ──────────────────────────────────────── */
.scc__config-card {
  background: #fff; border: 1.5px solid #e2e8f0; border-radius: 14px;
  overflow: hidden; margin-bottom: 1rem;
}
.scc__config-card-title {
  font-size: .7rem; font-weight: 700; text-transform: uppercase; letter-spacing: .07em;
  color: #94a3b8; padding: .875rem 1.1rem .5rem;
}
.scc__config-divider { height: 1px; background: #f1f5f9; margin: 0 1.1rem; }

.scc__config-row {
  display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem;
  padding: .875rem 1.1rem;
}
.scc__config-info { flex: 1; min-width: 0; display: flex; flex-direction: column; gap: .35rem; }
.scc__config-label {
  font-size: .82rem; font-weight: 700; color: #334155;
  display: flex; align-items: center; gap: .4rem;
}
.scc__config-label i { color: #94a3b8; font-size: .85rem; }
.scc__config-value { display: flex; flex-direction: column; gap: .3rem; }

.scc__config-val-text {
  font-size: .95rem; font-weight: 700; color: #0f172a;
  display: flex; align-items: center; gap: .4rem;
}
.scc__config-val-text--discount { color: #15803d; }
.scc__config-val-off { font-size: .82rem; color: #94a3b8; }

.scc__config-edit-btn {
  background: none; border: none; color: #94a3b8; cursor: pointer;
  padding: .1rem .2rem; border-radius: 4px; display: inline-flex; align-items: center;
  transition: color .15s;
}
.scc__config-edit-btn:hover { color: #334155; }

/* Inline edit form */
.scc__inline-form { display: flex; align-items: center; gap: .35rem; flex-wrap: wrap; }
.scc__inline-input {
  font-family: monospace; font-size: .9rem; font-weight: 600;
  border: 1.5px solid #6366f1; border-radius: 7px;
  padding: .3rem .55rem; width: 7rem; color: #1e293b; background: #fff; outline: none;
}
.scc__inline-input--sm { width: 5rem; }
.scc__inline-input:focus { border-color: #4f46e5; box-shadow: 0 0 0 3px rgba(99,102,241,.15); }
.scc__inline-unit { font-size: .78rem; font-weight: 700; color: #64748b; }
.scc__inline-ok {
  background: #15803d; color: #fff; border: none; border-radius: 6px;
  padding: .3rem .65rem; font-size: .78rem; font-weight: 700; cursor: pointer;
}
.scc__inline-ok:disabled { opacity: .5; cursor: not-allowed; }
.scc__inline-cancel {
  background: #f1f5f9; color: #475569; border: none; border-radius: 6px;
  padding: .3rem .55rem; font-size: .78rem; cursor: pointer;
}

/* Gramos extras */
.scc__config-gramos-row { display: flex; align-items: center; gap: .4rem; }
.scc__config-gramos-saldo {
  display: flex; align-items: center; gap: .75rem; flex-wrap: wrap;
  padding-top: .25rem;
}
.scc__config-saldo-val { font-size: .82rem; font-weight: 600; }
.scc__saldo--ok      { color: #15803d; }
.scc__saldo--agotado { color: #dc2626; }
.scc__acreditar-btn {
  font-size: .75rem; font-weight: 700; color: #15803d;
  background: #f0fdf4; border: 1px solid #bbf7d0; border-radius: 6px;
  padding: .2rem .6rem; cursor: pointer; transition: all .15s;
}
.scc__acreditar-btn:hover { background: #dcfce7; }

/* Toggle switch */
.scc__toggle {
  position: relative; width: 38px; height: 22px; border-radius: 999px;
  border: none; cursor: pointer; transition: background .2s; padding: 0; flex-shrink: 0;
}
.scc__toggle--off { background: #cbd5e1; }
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
  background: #f8fafc; border: 1.5px solid #e2e8f0; border-radius: 14px;
  padding: 1rem 1.1rem; margin-bottom: 1rem; display: flex; flex-direction: column; gap: .875rem;
}
.scc__estado-row { display: flex; gap: 1rem; }
.scc__estado-block { flex: 1; display: flex; flex-direction: column; gap: .2rem; }
.scc__estado-block--deuda { /* no special style needed */ }
.scc__estado-label { font-size: .7rem; font-weight: 600; color: #64748b; text-transform: uppercase; letter-spacing: .04em; }
.scc__estado-val   { font-family: monospace; font-size: 1.35rem; font-weight: 800; color: #0f172a; }
.scc__val--ok   { color: #15803d; }
.scc__val--zero { color: #94a3b8; }
.scc__val--deuda { color: #dc2626; }
.scc__val--warn  { color: #d97706; }

/* Progress */
.scc__progreso-wrap { display: flex; align-items: center; gap: .75rem; }
.scc__progreso-bar  { flex: 1; height: 6px; background: #e2e8f0; border-radius: 999px; overflow: hidden; }
.scc__progreso-fill { height: 100%; background: #15803d; border-radius: 999px; transition: width .4s; }
.scc__progreso-fill--warn   { background: #d97706; }
.scc__progreso-fill--danger { background: #dc2626; }
.scc__progreso-pct  { font-size: .72rem; color: #94a3b8; white-space: nowrap; font-family: monospace; }

/* ── Historial ───────────────────────────────────────────── */
.scc__historial       { margin-top: 1rem; }
.scc__historial-title { font-size: .7rem; font-weight: 700; color: #94a3b8; text-transform: uppercase; letter-spacing: .07em; margin-bottom: .75rem; }
.scc__movs { display: flex; flex-direction: column; gap: 0; border: 1.5px solid #e2e8f0; border-radius: 12px; overflow: hidden; }
.scc__mov {
  display: grid; grid-template-columns: auto 1fr auto;
  grid-template-rows: auto auto; gap: .1rem .75rem;
  padding: .8rem 1rem; border-bottom: 1px solid #f1f5f9; font-size: .82rem;
}
.scc__mov:last-child { border-bottom: none; }
.scc__mov-tipo { grid-column: 1; grid-row: 1; font-size: .68rem; font-weight: 700; padding: .15rem .5rem; border-radius: 999px; white-space: nowrap; align-self: center; }
.scc__mov-tipo--carga  { background: #f0fdf4; color: #15803d; }
.scc__mov-tipo--debito { background: #fef2f2; color: #dc2626; }
.scc__mov-tipo--ajuste { background: #fffbeb; color: #b45309; }
.scc__mov-tipo--pago   { background: #eff6ff; color: #2563eb; }
.scc__mov-desc   { grid-column: 2; grid-row: 1; color: #475569; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.scc__mov-monto  { grid-column: 3; grid-row: 1; font-family: monospace; font-weight: 700; text-align: right; white-space: nowrap; }
.scc__mov--pos   { color: #15803d; }
.scc__mov--neg   { color: #dc2626; }
.scc__mov-saldo  { grid-column: 2; grid-row: 2; font-family: monospace; font-size: .72rem; color: #94a3b8; }
.scc__mov-meta   { grid-column: 3; grid-row: 2; font-size: .7rem; color: #94a3b8; text-align: right; }
</style>
