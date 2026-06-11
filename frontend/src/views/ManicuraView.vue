<script setup>
import { ref, computed, onMounted } from 'vue'
import { getInventarioPendiente, aprobarMovimiento, rechazarMovimiento } from '../lib/api.js'
import EmptyState from '../components/ui/EmptyState.vue'
import { useToast } from '../composables/useToast.js'
import DsSpinner from '../design-system/components/Spinner.vue'

const toast = useToast()

const movimientos    = ref([])
const loading        = ref(true)
const procesando     = ref(null)
const showRechazo    = ref(false)
const rechazoTarget  = ref(null)
const rechazoMotivo  = ref('')
const rechazando     = ref(false)

const pendientes  = computed(() => movimientos.value.filter(m => m.estado === 'pendiente'))
const historial   = computed(() =>
  movimientos.value
    .filter(m => m.estado !== 'pendiente')
    .sort((a, b) => new Date(b.aprobado_at || b.created_at) - new Date(a.aprobado_at || a.created_at))
)

function fmtDate(d) {
  if (!d) return '—'
  return new Date(d).toLocaleString('es-AR', { day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' })
}

async function cargar() {
  loading.value = true
  try {
    const { data } = await getInventarioPendiente()
    movimientos.value = data || []
  } catch { movimientos.value = [] }
  finally { loading.value = false }
}

async function aprobar(m) {
  procesando.value = m.id
  try {
    await aprobarMovimiento(m.id)
    await cargar()
  } catch (e) {
    toast.error(e.response?.data?.errors?.[0] || 'Error al aprobar')
  } finally { procesando.value = null }
}

function abrirRechazo(m) {
  rechazoTarget.value = m
  rechazoMotivo.value = ''
  showRechazo.value   = true
}

async function confirmarRechazo() {
  rechazando.value = true
  try {
    await rechazarMovimiento(rechazoTarget.value.id, rechazoMotivo.value || 'Rechazado por administración')
    showRechazo.value = false
    await cargar()
  } catch (e) {
    toast.error(e.response?.data?.errors?.[0] || 'Error al rechazar')
  } finally { rechazando.value = false }
}

onMounted(cargar)
</script>

<template>
  <div class="mv">

    <!-- Header -->
    <div class="mv__header">
      <div class="mv__header-left">
        <div class="mv__eyebrow"><span class="mv__dot"></span> Control de stock</div>
        <h1 class="mv__title">Panel de Manicura</h1>
        <p class="mv__sub">Aprobá o rechazá los ingresos de stock registrados por el equipo</p>
      </div>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="mv__loading">
      <DsSpinner />
    </div>

    <template v-else>

      <!-- ── Pendientes ── -->
      <section class="mv__section">
        <div class="mv__section-header">
          <div class="mv__section-title">
            <i class="bi bi-hourglass-split"></i> Pendientes de aprobación
            <span v-if="pendientes.length" class="mv__badge mv__badge--warn">{{ pendientes.length }}</span>
          </div>
        </div>

        <EmptyState v-if="!pendientes.length" icon="bi-check-circle" title="Todo al día" message="No hay movimientos pendientes." compact />

        <div v-else class="mv__cards">
          <div v-for="m in pendientes" :key="m.id" class="mv__card mv__card--pending">
            <div class="mv__card-stripe mv__card-stripe--warn"></div>
            <div class="mv__card-body">
              <div class="mv__card-head">
                <span class="mv__card-genetica">{{ m.genetica_nombre }}</span>
                <span class="mv__badge mv__badge--warn">Pendiente</span>
              </div>
              <div class="mv__card-meta">
                <span><i class="bi bi-geo-alt"></i> {{ m.sede?.nombre }}</span>
                <span v-if="m.lote_codigo"><i class="bi bi-box-seam"></i> Lote {{ m.lote_codigo }}</span>
                <span><i class="bi bi-person"></i> {{ m.created_by?.nombre }}</span>
                <span><i class="bi bi-calendar3"></i> {{ fmtDate(m.created_at) }}</span>
              </div>
              <div v-if="m.motivo" class="mv__card-motivo">{{ m.motivo }}</div>
            </div>
            <div class="mv__card-cantidad">
              <span class="mv__cantidad-val">{{ m.cantidad > 0 ? '+' : '' }}{{ m.cantidad }}g</span>
            </div>
            <div class="mv__card-actions">
              <button class="mv__btn-aprobar" :disabled="procesando === m.id" @click="aprobar(m)">
                <DsSpinner v-if="procesando === m.id" :size="13" />
                <i v-else class="bi bi-check-lg"></i>
                Aprobar
              </button>
              <button class="mv__btn-rechazar" :disabled="procesando === m.id" @click="abrirRechazo(m)">
                <i class="bi bi-x-lg"></i>
                Rechazar
              </button>
            </div>
          </div>
        </div>
      </section>

      <!-- ── Historial ── -->
      <section class="mv__section mv__section--mt">
        <div class="mv__section-header">
          <div class="mv__section-title">
            <i class="bi bi-clock-history"></i> Historial
          </div>
        </div>

        <EmptyState v-if="!historial.length" icon="bi-clock-history" title="Sin historial" message="Sin movimientos procesados aún." compact />

        <div v-else class="mv__table-wrap">
          <table class="mv__table">
            <thead>
              <tr>
                <th>Genética</th>
                <th>Sede</th>
                <th>Lote</th>
                <th>Cantidad</th>
                <th>Registrado por</th>
                <th>Fecha ingreso</th>
                <th>Estado</th>
                <th>Procesado por</th>
                <th>Fecha proceso</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="m in historial" :key="m.id">
                <td class="mv__td-genetica">{{ m.genetica_nombre }}</td>
                <td>{{ m.sede?.nombre || '—' }}</td>
                <td>{{ m.lote_codigo || '—' }}</td>
                <td class="mv__td-cantidad" :class="m.cantidad > 0 ? 'mv__td-cantidad--pos' : 'mv__td-cantidad--neg'">
                  {{ m.cantidad > 0 ? '+' : '' }}{{ m.cantidad }}g
                </td>
                <td>{{ m.created_by?.nombre }}</td>
                <td class="mv__td-date">{{ fmtDate(m.created_at) }}</td>
                <td>
                  <span class="mv__badge" :class="m.estado === 'aprobado' ? 'mv__badge--ok' : 'mv__badge--danger'">
                    {{ m.estado === 'aprobado' ? 'Aprobado' : 'Rechazado' }}
                  </span>
                </td>
                <td>{{ m.aprobado_por?.nombre || '—' }}</td>
                <td class="mv__td-date">{{ fmtDate(m.aprobado_at) }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>

    </template>

    <!-- ── Modal rechazo ── -->
    <Teleport to="body">
      <div v-if="showRechazo" class="mv__overlay" @click.self="showRechazo=false">
        <div class="mv__modal">
          <div class="mv__modal-icon"><i class="bi bi-x-circle-fill"></i></div>
          <h3 class="mv__modal-title">Rechazar movimiento</h3>
          <p class="mv__modal-desc">
            {{ rechazoTarget?.genetica_nombre }} · {{ rechazoTarget?.cantidad }}g
            <span v-if="rechazoTarget?.lote_codigo"> · Lote {{ rechazoTarget.lote_codigo }}</span>
          </p>
          <textarea
            v-model="rechazoMotivo"
            class="mv__textarea"
            rows="3"
            placeholder="Motivo del rechazo (opcional)…"
          ></textarea>
          <div class="mv__modal-actions">
            <button class="mv__btn-ghost" :disabled="rechazando" @click="showRechazo=false">Cancelar</button>
            <button class="mv__btn-rechazar" :disabled="rechazando" @click="confirmarRechazo">
              <DsSpinner v-if="rechazando" :size="13" />
              <i v-else class="bi bi-x-lg"></i>
              Confirmar rechazo
            </button>
          </div>
        </div>
      </div>
    </Teleport>

  </div>
</template>

<style scoped>
.mv { padding: 2rem 1.75rem 3rem; max-width: 1200px; margin: 0 auto; }
@media (max-width: 768px) { .mv { padding: 1.25rem 1rem 2rem; } }

.mv__header { margin-bottom: 2rem; }
.mv__eyebrow { display: flex; align-items: center; gap: .4rem; font-size: .72rem; font-weight: 700; text-transform: uppercase; letter-spacing: .1em; color: #b45309; margin-bottom: .35rem; }
.mv__dot { width: 6px; height: 6px; border-radius: 50%; background: #b45309; animation: mv-pulse 2s ease-in-out infinite; }
@keyframes mv-pulse { 0%,100%{opacity:1;transform:scale(1)} 50%{opacity:.4;transform:scale(.7)} }
.mv__title { font-size: 2rem; font-weight: 800; color: #0f172a; margin: 0 0 .2rem; letter-spacing: -.04em; }
.mv__sub { font-size: .84rem; color: #64748b; margin: 0; }

.mv__loading { display: flex; align-items: center; justify-content: center; min-height: calc(100vh - 56px); }

.mv__section { }
.mv__section--mt { margin-top: 2.5rem; }
.mv__section-header { margin-bottom: 1rem; }
.mv__section-title { display: flex; align-items: center; gap: .6rem; font-size: 1rem; font-weight: 700; color: #0f172a; }

.mv__badge { font-size: .65rem; font-weight: 800; padding: .2em .6em; border-radius: 999px; text-transform: uppercase; letter-spacing: .04em; }
.mv__badge--warn   { background: #fffbeb; color: #b45309; border: 1px solid #fde68a; }
.mv__badge--ok     { background: #f0fdf4; color: #15803d; border: 1px solid #bbf7d0; }
.mv__badge--danger { background: #fef2f2; color: #dc2626; border: 1px solid #fecaca; }


.mv__cards { display: flex; flex-direction: column; gap: .75rem; }
.mv__card { display: flex; align-items: stretch; background: #fff; border: 1px solid #e2e8f0; border-radius: 14px; overflow: hidden; transition: box-shadow .15s; }
.mv__card:hover { box-shadow: 0 4px 16px rgba(0,0,0,.07); }
.mv__card--pending { border-color: #fde68a; }
.mv__card-stripe { width: 4px; flex-shrink: 0; }
.mv__card-stripe--warn { background: #f59e0b; }
.mv__card-body { flex: 1; padding: 1rem 1.1rem; }
.mv__card-head { display: flex; align-items: center; gap: .75rem; margin-bottom: .5rem; }
.mv__card-genetica { font-size: .95rem; font-weight: 700; color: #0f172a; }
.mv__card-meta { display: flex; flex-wrap: wrap; gap: .5rem 1rem; font-size: .75rem; color: #64748b; margin-bottom: .35rem; }
.mv__card-meta span { display: flex; align-items: center; gap: .3rem; }
.mv__card-motivo { font-size: .78rem; color: #475569; font-style: italic; background: #f8fafc; padding: .4rem .65rem; border-radius: 6px; margin-top: .35rem; }
.mv__card-cantidad { display: flex; align-items: center; padding: 0 1.5rem; border-left: 1px solid #f1f5f9; flex-shrink: 0; }
.mv__cantidad-val { font-size: 1.4rem; font-weight: 900; color: #b45309; letter-spacing: -.04em; font-family: monospace; white-space: nowrap; }
.mv__card-actions { display: flex; flex-direction: column; gap: .5rem; justify-content: center; padding: 1rem; border-left: 1px solid #f1f5f9; flex-shrink: 0; }
@media (max-width: 640px) {
  .mv__card { flex-direction: column; }
  .mv__card-stripe { width: 100%; height: 4px; }
  .mv__card-cantidad { border-left: none; border-top: 1px solid #f1f5f9; padding: .75rem 1.1rem; }
  .mv__card-actions { border-left: none; border-top: 1px solid #f1f5f9; flex-direction: row; padding: .75rem 1.1rem; }
}

.mv__btn-aprobar { display: inline-flex; align-items: center; gap: .35rem; background: #15803d; color: #fff; border: none; padding: .55rem 1rem; border-radius: 8px; font-size: .8rem; font-weight: 700; cursor: pointer; white-space: nowrap; transition: background .15s; }
.mv__btn-aprobar:hover:not(:disabled) { background: #14532d; }
.mv__btn-aprobar:disabled { opacity: .5; cursor: not-allowed; }
.mv__btn-rechazar { display: inline-flex; align-items: center; gap: .35rem; background: #fff; color: #dc2626; border: 1.5px solid #fecaca; padding: .55rem 1rem; border-radius: 8px; font-size: .8rem; font-weight: 700; cursor: pointer; white-space: nowrap; transition: all .15s; }
.mv__btn-rechazar:hover:not(:disabled) { background: #fef2f2; }
.mv__btn-rechazar:disabled { opacity: .5; cursor: not-allowed; }
.mv__btn-ghost { background: #fff; color: #64748b; border: 1.5px solid #e2e8f0; padding: .6rem 1.1rem; border-radius: 9px; font-size: .875rem; font-weight: 500; cursor: pointer; }
.mv__btn-ghost:hover { background: #f8fafc; }



.mv__table-wrap { background: #fff; border: 1px solid #e2e8f0; border-radius: 14px; overflow-x: auto; }
.mv__table { width: 100%; border-collapse: collapse; font-size: .8rem; }
.mv__table th { font-size: .68rem; font-weight: 700; text-transform: uppercase; letter-spacing: .05em; color: #94a3b8; padding: .75rem 1rem; border-bottom: 1px solid #f1f5f9; text-align: left; white-space: nowrap; background: #fafbfc; }
.mv__table td { padding: .75rem 1rem; border-bottom: 1px solid #f8fafc; color: #374151; vertical-align: middle; }
.mv__table tbody tr:last-child td { border-bottom: none; }
.mv__table tbody tr:hover td { background: #fafbfc; }
.mv__td-genetica { font-weight: 700; color: #0f172a; }
.mv__td-cantidad { font-weight: 800; font-family: monospace; }
.mv__td-cantidad--pos { color: #15803d; }
.mv__td-cantidad--neg { color: #dc2626; }
.mv__td-date { white-space: nowrap; color: #64748b; font-size: .75rem; }

.mv__overlay { position: fixed; inset: 0; background: rgba(0,0,0,.4); display: flex; align-items: center; justify-content: center; z-index: 1050; padding: 1rem; backdrop-filter: blur(3px); }
.mv__modal { background: #fff; border-radius: 18px; width: 100%; max-width: 420px; padding: 2rem; box-shadow: 0 24px 64px rgba(0,0,0,.15); text-align: center; }
.mv__modal-icon { width: 56px; height: 56px; border-radius: 50%; background: #fef2f2; color: #dc2626; font-size: 1.5rem; display: flex; align-items: center; justify-content: center; margin: 0 auto .875rem; }
.mv__modal-title { font-size: 1.1rem; font-weight: 800; color: #0f172a; margin: 0 0 .4rem; }
.mv__modal-desc { font-size: .875rem; color: #64748b; margin: 0 0 1.25rem; }
.mv__textarea { width: 100%; box-sizing: border-box; background: #f8fafc; border: 1.5px solid #e2e8f0; border-radius: 9px; padding: .65rem .875rem; font-size: .875rem; color: #0f172a; resize: vertical; margin-bottom: 1.25rem; }
.mv__textarea:focus { outline: none; border-color: #dc2626; }
.mv__modal-actions { display: flex; gap: .65rem; justify-content: center; }
</style>
