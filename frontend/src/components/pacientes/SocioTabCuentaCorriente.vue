<template>
  <div>
    <div v-if="loadingCC" class="scc__loading"><DsSpinner :size="40" /></div>
    <template v-else-if="cc">

      <div class="scc__header">
        <div class="scc__saldo-block" :class="cc.saldo_disponible < 0 ? 'scc__saldo-block--deuda' : ''">
          <span class="scc__label">{{ cc.saldo_disponible < 0 ? 'Deuda actual' : 'Saldo a favor' }}</span>
          <span class="scc__saldo-valor"
                :class="cc.saldo_disponible < 0 ? 'scc__saldo--deuda' : cc.saldo_disponible > 0 ? 'scc__saldo--ok' : 'scc__saldo--zero'">
            {{ cc.saldo_disponible < 0 ? '−' : '' }}{{ fmtARS(Math.abs(cc.saldo_disponible)) }}
          </span>
          <span class="scc__hint">
            {{ cc.saldo_disponible < 0 ? 'El socio nos debe este monto' : cc.saldo_disponible > 0 ? 'Pagó por adelantado' : 'Sin saldo ni deuda' }}
          </span>
        </div>

        <div class="scc__margen-block" :class="cc.limite_credito > 0 && ccMargen <= 0 ? 'scc__margen-block--agotado' : ''">
          <span class="scc__label">Puede retirar aún</span>
          <span class="scc__margen-valor"
                :class="!cc.limite_credito ? 'scc__margen--zero' : ccMargen <= 0 ? 'scc__margen--agotado' : ccMargen < cc.limite_credito * 0.2 ? 'scc__margen--bajo' : 'scc__margen--ok'">
            {{ fmtARS(Math.max(0, ccMargen)) }}
          </span>
          <span class="scc__hint">
            {{ ccMargen <= 0 ? (cc.limite_credito === 0 ? 'Sin límite configurado' : 'Límite agotado — bloqueado') : 'Antes de ser bloqueado' }}
          </span>
        </div>

        <div class="scc__limite-block">
          <span class="scc__label">Límite de crédito</span>
          <template v-if="!limiteEditOpen">
            <div class="scc__limite-valor-row">
              <span class="scc__limite-valor">{{ fmtARS(cc.limite_credito) }}</span>
              <button v-if="!readonly" class="scc__limite-edit-btn" @click="openLimiteEdit" title="Editar límite">
                <Pencil :size="12" :stroke-width="1.75" />
              </button>
            </div>
          </template>
          <template v-else>
            <div class="scc__limite-form">
              <input type="number" min="0" step="100" v-model.number="limiteEditVal"
                     class="scc__numInput" placeholder="0"
                     @keydown.enter="saveLimite" @keydown.esc="limiteEditOpen = false" />
              <button class="scc__btn scc__btn--primary scc__btn--sm" :disabled="savingLimite" @click="saveLimite">
                {{ savingLimite ? '…' : 'Guardar' }}
              </button>
              <button class="scc__btn scc__btn--ghost scc__btn--sm" @click="limiteEditOpen = false">Cancelar</button>
            </div>
          </template>
        </div>
      </div>

      <!-- Crédito en gramos -->
      <div class="scc__gramos-section">
        <div class="scc__gramos-header">
          <div class="scc__gramos-title"><i class="bi bi-flower1"></i> Crédito en gramos</div>
          <button v-if="!readonly"
            class="scc__toggle"
            :class="cc.credito_gramos_activo ? 'scc__toggle--on' : 'scc__toggle--off'"
            :disabled="togglingGramos"
            @click="toggleGramos"
            :title="cc.credito_gramos_activo ? 'Desactivar crédito en gramos' : 'Activar crédito en gramos'"
          >
            <span class="scc__toggle-knob"></span>
          </button>
          <span v-else-if="cc.credito_gramos_activo" class="scc__badge-activo">Activo</span>
        </div>

        <template v-if="cc.credito_gramos_activo">
          <div class="scc__gramos-stats">
            <div class="scc__gramos-stat">
              <span class="scc__gramos-stat-label">Disponible</span>
              <span class="scc__gramos-stat-val" :class="cc.saldo_disponible_g <= 0 ? 'scc__gramos--agotado' : 'scc__gramos--ok'">
                {{ (cc.saldo_disponible_g ?? 0).toFixed(1) }}g
              </span>
            </div>
            <div class="scc__gramos-stat">
              <span class="scc__gramos-stat-label">Límite</span>
              <span class="scc__gramos-stat-val">{{ cc.limite_credito_g ? cc.limite_credito_g.toFixed(1) + 'g' : '—' }}</span>
            </div>
          </div>

          <div v-if="!readonly" class="scc__gramos-actions">
            <template v-if="!limiteGOpen">
              <button class="scc__btn scc__btn--ghost scc__btn--sm" @click="limiteGOpen = true; limiteGVal = cc.limite_credito_g ?? null">
                <Pencil :size="11" :stroke-width="2" /> Límite
              </button>
            </template>
            <template v-else>
              <div class="scc__gramos-form">
                <input type="number" min="0.1" step="0.5" v-model.number="limiteGVal"
                       class="scc__numInput" placeholder="ej: 50"
                       @keydown.enter="saveLimiteG" @keydown.esc="limiteGOpen = false" />
                <span class="scc__gramos-unit">g</span>
                <button class="scc__btn scc__btn--primary scc__btn--sm" :disabled="savingLimiteG" @click="saveLimiteG">
                  {{ savingLimiteG ? '…' : 'OK' }}
                </button>
                <button class="scc__btn scc__btn--ghost scc__btn--sm" @click="limiteGOpen = false">✕</button>
              </div>
            </template>

            <template v-if="!cargarGOpen">
              <button class="scc__btn scc__btn--primary scc__btn--sm" @click="cargarGOpen = true; cargarGVal = null">
                + Cargar gramos
              </button>
            </template>
            <template v-else>
              <div class="scc__gramos-form">
                <input type="number" min="0.1" step="0.5" v-model.number="cargarGVal"
                       class="scc__numInput" placeholder="ej: 20"
                       @keydown.enter="doCargarG" @keydown.esc="cargarGOpen = false" />
                <span class="scc__gramos-unit">g</span>
                <button class="scc__btn scc__btn--primary scc__btn--sm" :disabled="savingCargarG" @click="doCargarG">
                  {{ savingCargarG ? '…' : 'Cargar' }}
                </button>
                <button class="scc__btn scc__btn--ghost scc__btn--sm" @click="cargarGOpen = false">✕</button>
              </div>
            </template>
          </div>
        </template>
        <p v-else class="scc__gramos-hint">Activá para permitir que el socio dispense sin pagar en el momento, descontando de un cupo en gramos.</p>
      </div>

      <div v-if="cc.limite_credito > 0 && ccDeudaActual > 0" class="scc__bar-wrap">
        <div class="scc__bar">
          <div class="scc__bar-fill"
               :style="{ width: ccPorcentaje + '%' }"
               :class="ccPorcentaje >= 90 ? 'scc__bar-fill--danger' : ccPorcentaje >= 70 ? 'scc__bar-fill--warn' : ''">
          </div>
        </div>
        <span class="scc__bar-pct">{{ ccPorcentaje }}% del crédito utilizado</span>
      </div>

      <div class="scc__historial">
        <div class="scc__historial-title">Historial</div>
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
  fmtARS, ccDeudaActual, ccMargen, ccPorcentaje,
  openLimiteEdit, loadCC, saveLimite, toggleGramos, saveLimiteG, doCargarG,
} = useSocioCuentaCorriente(props.socioId)

onMounted(() => loadCC())
watch(() => props.refreshKey, (v, old) => { if (v !== old) loadCC() })
</script>

<style scoped>
.scc__loading { display: flex; align-items: center; justify-content: center; padding: 2rem; }
.scc__empty { text-align: center; color: #94a3b8; font-size: .875rem; padding: 1.5rem; }

/* Header: 3 blocks */
.scc__header { display: flex; align-items: stretch; gap: 1rem; margin-bottom: 1rem; }
.scc__saldo-block, .scc__margen-block, .scc__limite-block { flex: 1; background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 12px; padding: 1rem 1.25rem; display: flex; flex-direction: column; gap: .2rem; }
.scc__saldo-block { background: #f0fdf4; border-color: #bbf7d0; }
.scc__saldo-block--deuda { background: #fef2f2; border-color: #fecaca; }
.scc__margen-block { background: #eff6ff; border-color: #bfdbfe; }
.scc__margen-block--agotado { background: #fef2f2; border-color: #fecaca; }
.scc__label { font-size: .72rem; font-weight: 600; color: #64748b; text-transform: uppercase; letter-spacing: .04em; }
.scc__hint { font-size: .7rem; color: #94a3b8; margin-top: .1rem; }
.scc__saldo-valor { font-family: monospace; font-size: 1.6rem; font-weight: 800; color: #0f172a; }
.scc__saldo--ok   { color: #15803d; }
.scc__saldo--zero { color: #94a3b8; }
.scc__saldo--deuda { color: #dc2626; }
.scc__margen-valor { font-family: monospace; font-size: 1.6rem; font-weight: 800; }
.scc__margen--ok      { color: #2563eb; }
.scc__margen--bajo    { color: #d97706; }
.scc__margen--agotado { color: #dc2626; }
.scc__margen--zero    { color: #94a3b8; }
.scc__limite-valor { font-family: monospace; font-size: 1.3rem; font-weight: 700; color: #475569; }
.scc__limite-valor-row { display: flex; align-items: center; gap: .35rem; }
.scc__limite-edit-btn { background: none; border: none; cursor: pointer; color: #94a3b8; padding: .1rem .2rem; border-radius: 4px; display: inline-flex; align-items: center; transition: color .15s; flex-shrink: 0; }
.scc__limite-edit-btn:hover { color: #475569; }
.scc__limite-form { display: flex; align-items: center; gap: .4rem; margin-top: .25rem; flex-wrap: wrap; }
.scc__numInput { font-family: monospace; font-size: 1rem; font-weight: 600; border: 1.5px solid #6366f1; border-radius: 8px; padding: .35rem .6rem; width: 8rem; color: #1e293b; background: #fff; outline: none; }
.scc__numInput:focus { border-color: #4f46e5; box-shadow: 0 0 0 3px rgba(99,102,241,.15); }

/* Gramos */
.scc__gramos-section { border: 1.5px solid #e2e8f0; border-radius: 12px; padding: .9rem 1rem; margin-bottom: 1rem; }
.scc__gramos-header { display: flex; align-items: center; justify-content: space-between; margin-bottom: .5rem; }
.scc__gramos-title { font-size: .78rem; font-weight: 700; color: #374151; display: flex; align-items: center; gap: .4rem; }
.scc__gramos-hint { font-size: .75rem; color: #94a3b8; margin: .25rem 0 0; }
.scc__gramos-stats { display: flex; gap: 1.5rem; margin-bottom: .75rem; }
.scc__gramos-stat { display: flex; flex-direction: column; gap: .15rem; }
.scc__gramos-stat-label { font-size: .68rem; color: #94a3b8; text-transform: uppercase; letter-spacing: .05em; }
.scc__gramos-stat-val { font-size: 1.1rem; font-weight: 800; font-family: monospace; color: #0f172a; }
.scc__gramos--ok { color: #15803d; }
.scc__gramos--agotado { color: #dc2626; }
.scc__gramos-actions { display: flex; align-items: center; gap: .5rem; flex-wrap: wrap; }
.scc__gramos-form { display: flex; align-items: center; gap: .4rem; }
.scc__gramos-unit { font-size: .8rem; font-weight: 700; color: #64748b; }
.scc__badge-activo { font-size: .7rem; font-weight: 700; background: #dcfce7; color: #15803d; padding: .2rem .55rem; border-radius: 999px; }

/* Toggle switch */
.scc__toggle { position: relative; width: 36px; height: 20px; border-radius: 999px; border: none; cursor: pointer; transition: background .2s; padding: 0; flex-shrink: 0; }
.scc__toggle--off { background: #cbd5e1; }
.scc__toggle--on  { background: #15803d; }
.scc__toggle:disabled { opacity: .6; cursor: not-allowed; }
.scc__toggle-knob { position: absolute; top: 2px; width: 16px; height: 16px; background: #fff; border-radius: 50%; transition: left .2s; box-shadow: 0 1px 3px rgba(0,0,0,.2); }
.scc__toggle--off .scc__toggle-knob { left: 2px; }
.scc__toggle--on  .scc__toggle-knob { left: 18px; }

/* Progress bar */
.scc__bar-wrap { display: flex; align-items: center; gap: .75rem; margin-bottom: 1rem; }
.scc__bar { flex: 1; height: 8px; background: #e2e8f0; border-radius: 999px; overflow: hidden; }
.scc__bar-fill { height: 100%; background: #15803d; border-radius: 999px; transition: width .4s; }
.scc__bar-fill--warn { background: #d97706; }
.scc__bar-fill--danger { background: #dc2626; }
.scc__bar-pct { font-size: .72rem; color: #94a3b8; white-space: nowrap; font-family: monospace; }

/* Buttons */
.scc__btn { display: inline-flex; align-items: center; gap: .4rem; padding: .5rem 1rem; border-radius: 8px; font-size: .8rem; font-weight: 600; cursor: pointer; border: none; transition: all .15s; }
.scc__btn--primary { background: #15803d; color: #fff; }
.scc__btn--primary:hover { background: #166534; }
.scc__btn--primary:disabled { opacity: .5; cursor: not-allowed; }
.scc__btn--ghost { background: #f1f5f9; color: #475569; border: 1px solid #e2e8f0; }
.scc__btn--ghost:hover { background: #e2e8f0; }
.scc__btn--sm { padding: .3rem .7rem; font-size: .78rem; }

/* Historial */
.scc__historial { margin-top: 1.25rem; }
.scc__historial-title { font-size: .75rem; font-weight: 700; color: #94a3b8; text-transform: uppercase; letter-spacing: .06em; margin-bottom: .75rem; }
.scc__movs { display: flex; flex-direction: column; gap: 0; border: 1px solid #e2e8f0; border-radius: 12px; overflow: hidden; }
.scc__mov { display: grid; grid-template-columns: auto 1fr auto; grid-template-rows: auto auto; gap: .1rem .75rem; padding: .8rem 1rem; border-bottom: 1px solid #f1f5f9; font-size: .82rem; }
.scc__mov:last-child { border-bottom: none; }
.scc__mov-tipo { grid-column: 1; grid-row: 1; font-size: .7rem; font-weight: 700; padding: .15rem .5rem; border-radius: 999px; white-space: nowrap; align-self: center; }
.scc__mov-tipo--carga  { background: #f0fdf4; color: #15803d; }
.scc__mov-tipo--debito { background: #fef2f2; color: #dc2626; }
.scc__mov-tipo--ajuste { background: #fffbeb; color: #b45309; }
.scc__mov-tipo--pago   { background: #eff6ff; color: #2563eb; }
.scc__mov-desc { grid-column: 2; grid-row: 1; color: #475569; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.scc__mov-monto { grid-column: 3; grid-row: 1; font-family: monospace; font-weight: 700; text-align: right; white-space: nowrap; }
.scc__mov--pos { color: #15803d; }
.scc__mov--neg { color: #dc2626; }
.scc__mov-saldo { grid-column: 2; grid-row: 2; font-family: monospace; font-size: .72rem; color: #94a3b8; }
.scc__mov-meta  { grid-column: 3; grid-row: 2; font-size: .7rem; color: #94a3b8; text-align: right; }
</style>
