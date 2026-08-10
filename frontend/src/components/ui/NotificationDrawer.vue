<template>
  <Teleport to="body">

    <!-- Backdrop -->
    <Transition name="nd-fade">
      <div
        v-if="modelValue"
        class="nd-backdrop"
        @click="close"
      />
    </Transition>

    <!-- Panel -->
    <Transition name="nd-slide">
      <div
        v-if="modelValue"
        class="nd-panel"
        role="dialog"
        aria-modal="true"
        aria-label="Notificaciones"
      >

        <!-- ── Header ── -->
        <header class="nd-header">
          <div class="nd-header__left">
            <span class="nd-header__title">Notificaciones</span>
            <span v-if="noLeidas.length" class="nd-header__badge">{{ noLeidas.length }}</span>
          </div>
          <div class="nd-header__actions">
            <button
              v-if="noLeidas.length"
              class="nd-btn-text"
              @click="handleMarcarTodas"
            >
              Leer todas
            </button>
            <button class="nd-close" @click="close" aria-label="Cerrar panel">
              <X :size="18" :stroke-width="1.75" />
            </button>
          </div>
        </header>

        <!-- ── Content ── -->
        <div class="nd-body">

          <!-- Loading skeletons -->
          <template v-if="loading">
            <div class="nd-group">
              <div class="nd-group__label nd-skel nd-skel--label" />
              <div v-for="n in 3" :key="n" class="nd-card nd-card--skel">
                <div class="nd-skel nd-skel--icon" />
                <div class="nd-card__body">
                  <div class="nd-skel nd-skel--title" />
                  <div class="nd-skel nd-skel--msg" />
                </div>
              </div>
            </div>
          </template>

          <!-- Empty state -->
          <div v-else-if="!alertas?.length" class="nd-empty">
            <div class="nd-empty__icon-wrap">
              <Bell :size="28" :stroke-width="1.5" />
            </div>
            <p class="nd-empty__title">Todo al día</p>
            <p class="nd-empty__sub">No tenés notificaciones pendientes</p>
          </div>

          <!-- Grupos por fecha -->
          <template v-else>
            <div
              v-for="grupo in grupos"
              :key="grupo.label"
              class="nd-group"
            >
              <div class="nd-group__label">{{ grupo.label }}</div>

              <div
                v-for="alerta in grupo.items"
                :key="alerta.id"
                class="nd-card"
                :class="{
                  'nd-card--unread': !alerta.leida,
                  'nd-card--link':   !!resolverRuta(alerta),
                }"
                @click="handleClick(alerta)"
              >
                <!-- Icon circle -->
                <div
                  class="nd-card__icon"
                  :style="{ background: meta(alerta.tipo).bg }"
                >
                  <component
                    :is="meta(alerta.tipo).component"
                    :size="15"
                    :stroke-width="2"
                    :style="{ color: meta(alerta.tipo).color }"
                  />
                </div>

                <!-- Body -->
                <div class="nd-card__body">
                  <div class="nd-card__label">{{ label(alerta.tipo) }}</div>
                  <div class="nd-card__msg">{{ alerta.mensaje }}</div>
                  <div class="nd-card__footer">
                    <span class="nd-card__time">{{ timeAgo(alerta.created_at) }}</span>
                    <span
                      v-if="alerta.severidad !== 'info'"
                      class="nd-card__sev"
                      :class="`nd-card__sev--${alerta.severidad}`"
                    >{{ alerta.severidad }}</span>
                  </div>
                </div>

                <!-- Right indicators -->
                <div class="nd-card__right">
                  <span v-if="!alerta.leida" class="nd-dot" />
                  <ChevronRight
                    v-if="resolverRuta(alerta)"
                    :size="14"
                    :stroke-width="2"
                    class="nd-card__chevron"
                  />
                </div>
              </div>
            </div>
          </template>

        </div>

        <!-- ── Ambient alerts footer ── -->
        <div v-if="alertasAmbientales.length" class="nd-ambient">
          <AlertTriangle :size="13" :stroke-width="2" class="nd-ambient__icon" />
          <span class="nd-ambient__text">
            {{ alertasAmbientales.length }} alerta{{ alertasAmbientales.length !== 1 ? 's' : '' }} ambiental{{ alertasAmbientales.length !== 1 ? 'es' : '' }} activa{{ alertasAmbientales.length !== 1 ? 's' : '' }}
          </span>
          <RouterLink to="/sedes" class="nd-ambient__link" @click="close">
            Ver salas <ChevronRight :size="12" :stroke-width="2" style="vertical-align:middle" />
          </RouterLink>
        </div>

      </div>
    </Transition>

  </Teleport>
</template>

<script setup>
import { computed } from 'vue'
import { useRouter } from 'vue-router'
import { X, ChevronRight, Bell, AlertTriangle } from 'lucide-vue-next'
import { useAlertasInternas } from '../../composables/useAlertasInternas.js'
import { useAmbienteStore } from '../../stores/ambiente.js'
import { resolverRutaAlerta, tipoLabel, tipoMeta } from '../../utils/alertaRuta.js'

const props = defineProps({
  modelValue: { type: Boolean, default: false },
})
const emit = defineEmits(['update:modelValue'])

const router = useRouter()
const ambStore = useAmbienteStore()

const { alertas, noLeidas, marcarLeida, marcarTodas } = useAlertasInternas()

const loading = computed(() => alertas.value === null)
const alertasAmbientales = computed(() => ambStore.alertasActivas)

function close() {
  emit('update:modelValue', false)
}

function meta(tipo)  { return tipoMeta(tipo) }
function label(tipo) { return tipoLabel(tipo) }
function resolverRuta(alerta) {
  return resolverRutaAlerta(alerta.tipo, alerta.contexto)
}

// ─── Click handler: mark read + navigate + close ─────────────────────────────
async function handleClick(alerta) {
  const ruta = resolverRuta(alerta)
  if (!alerta.leida) await marcarLeida(alerta.id)
  if (ruta) {
    close()
    router.push(ruta)
  }
}

async function handleMarcarTodas() {
  await marcarTodas()
}

// ─── Date grouping ────────────────────────────────────────────────────────────
const GRUPOS_ORDER = ['Hoy', 'Ayer', 'Esta semana', 'Anteriores']

const grupos = computed(() => {
  const now     = new Date()
  const hoy     = startOfDay(now)
  const ayer    = startOfDay(new Date(now - 86400000))
  const semana  = startOfDay(new Date(now - 6 * 86400000))

  const map = {}

  for (const a of (alertas.value ?? [])) {
    const d = new Date(a.created_at)
    let g
    if (d >= hoy)   g = 'Hoy'
    else if (d >= ayer)   g = 'Ayer'
    else if (d >= semana) g = 'Esta semana'
    else                  g = 'Anteriores'
    if (!map[g]) map[g] = []
    map[g].push(a)
  }

  return GRUPOS_ORDER
    .filter(l => map[l])
    .map(l => ({ label: l, items: map[l] }))
})

function startOfDay(date) {
  const d = new Date(date)
  d.setHours(0, 0, 0, 0)
  return d
}

// ─── Time formatting ─────────────────────────────────────────────────────────
function timeAgo(ts) {
  if (!ts) return ''
  const diff = Date.now() - new Date(ts).getTime()
  const mins = Math.floor(diff / 60_000)
  if (mins < 1)    return 'ahora'
  if (mins < 60)   return `hace ${mins}m`
  const hrs = Math.floor(mins / 60)
  if (hrs < 24)    return `hace ${hrs}h`
  const dias = Math.floor(hrs / 24)
  if (dias === 1)  return 'ayer'
  if (dias < 7)    return `hace ${dias} días`
  return new Date(ts).toLocaleDateString('es-AR', { day: 'numeric', month: 'short' })
}
</script>

<style scoped>
/* ── Backdrop ─────────────────────────────────────────────────────────────── */
.nd-backdrop {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.35);
  z-index: 990;
  cursor: pointer;
}

/* ── Panel ────────────────────────────────────────────────────────────────── */
.nd-panel {
  position: fixed;
  top: 0;
  right: 0;
  bottom: 0;
  width: 420px;
  max-width: 100vw;
  background: var(--c-paper, #fff);
  z-index: 1000;
  display: flex;
  flex-direction: column;
  box-shadow: -8px 0 40px rgba(0, 0, 0, 0.12), -2px 0 8px rgba(0, 0, 0, 0.06);
  overflow: hidden;
}

/* ── Header ───────────────────────────────────────────────────────────────── */
.nd-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 var(--sp-5, 1.25rem);
  height: 60px;
  flex-shrink: 0;
  border-bottom: 1px solid var(--c-ink-200, #e5e7eb);
  background: var(--c-paper, #fff);
}

.nd-header__left {
  display: flex;
  align-items: center;
  gap: .5rem;
}

.nd-header__title {
  font-size: var(--fs-15, .9375rem);
  font-weight: 700;
  color: var(--c-slate-900);
  letter-spacing: -.01em;
}

.nd-header__badge {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 20px;
  height: 20px;
  padding: 0 6px;
  background: #16a34a;
  color: #fff;
  font-size: 11px;
  font-weight: 800;
  border-radius: 999px;
  line-height: 1;
}

.nd-header__actions {
  display: flex;
  align-items: center;
  gap: .25rem;
}

.nd-btn-text {
  background: none;
  border: none;
  color: var(--c-ink-500, #6b7280);
  font-size: var(--fs-13, .8125rem);
  font-weight: 500;
  cursor: pointer;
  padding: .3rem .5rem;
  border-radius: var(--r-sm, 4px);
  transition: color .15s, background .15s;
}
.nd-btn-text:hover { color: var(--c-slate-900); background: var(--c-ink-100, #f3f4f6); }

.nd-close {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 32px;
  height: 32px;
  background: none;
  border: none;
  color: var(--c-ink-500, #6b7280);
  border-radius: var(--r-md, 6px);
  cursor: pointer;
  transition: background .15s, color .15s;
}
.nd-close:hover { background: var(--c-ink-100, #f3f4f6); color: var(--c-slate-900); }

/* ── Body ─────────────────────────────────────────────────────────────────── */
.nd-body {
  flex: 1;
  overflow-y: auto;
  overflow-x: hidden;
  padding-bottom: .5rem;
  /* Smooth momentum scroll on iOS */
  -webkit-overflow-scrolling: touch;
  scrollbar-width: thin;
  scrollbar-color: var(--c-ink-200, #e5e7eb) transparent;
}
.nd-body::-webkit-scrollbar { width: 4px; }
.nd-body::-webkit-scrollbar-thumb { background: var(--c-ink-200, #e5e7eb); border-radius: 2px; }

/* ── Group ────────────────────────────────────────────────────────────────── */
.nd-group {
  padding-top: .5rem;
}

.nd-group__label {
  padding: .5rem 1rem .375rem;
  font-size: 10px;
  font-weight: 800;
  letter-spacing: .08em;
  text-transform: uppercase;
  color: var(--c-ink-400, #9ca3af);
}

/* ── Card ─────────────────────────────────────────────────────────────────── */
.nd-card {
  display: flex;
  align-items: flex-start;
  gap: .75rem;
  padding: .75rem 1rem;
  position: relative;
  transition: background .12s;
  border-left: 3px solid transparent;
}

.nd-card--unread {
  border-left-color: #16a34a;
  background: #fafffe;
}

.nd-card--link {
  cursor: pointer;
}
.nd-card--link:hover {
  background: var(--c-ink-50, #f9fafb);
}
.nd-card--unread.nd-card--link:hover {
  background: #f0fdf4;
}

/* Icon circle */
.nd-card__icon {
  flex-shrink: 0;
  width: 36px;
  height: 36px;
  border-radius: 9px;
  display: flex;
  align-items: center;
  justify-content: center;
  margin-top: 1px;
}

/* Body */
.nd-card__body {
  flex: 1;
  min-width: 0;
}

.nd-card__label {
  font-size: 11px;
  font-weight: 700;
  letter-spacing: .02em;
  text-transform: uppercase;
  color: var(--c-ink-400, #9ca3af);
  margin-bottom: 2px;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.nd-card__msg {
  font-size: var(--fs-13, .8125rem);
  color: var(--c-ink-800, #1e293b);
  line-height: 1.45;
  font-weight: 500;
}

.nd-card--unread .nd-card__msg {
  color: var(--c-slate-900);
  font-weight: 600;
}

.nd-card__footer {
  display: flex;
  align-items: center;
  gap: .5rem;
  margin-top: 4px;
}

.nd-card__time {
  font-size: 11px;
  color: var(--c-ink-400, #9ca3af);
  font-variant-numeric: tabular-nums;
}

.nd-card__sev {
  font-size: 10px;
  font-weight: 700;
  letter-spacing: .04em;
  text-transform: uppercase;
  padding: 1px 5px;
  border-radius: 3px;
}
.nd-card__sev--warning { background: #fef3c7; color: #b45309; }
.nd-card__sev--error   { background: #fee2e2; color: #b91c1c; }

/* Right */
.nd-card__right {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: .4rem;
  flex-shrink: 0;
  padding-top: 6px;
}

.nd-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background: #16a34a;
  flex-shrink: 0;
}

.nd-card__chevron {
  color: var(--c-ink-300, #d1d5db);
}
.nd-card--link:hover .nd-card__chevron {
  color: var(--c-ink-500, #6b7280);
}

/* ── Empty state ──────────────────────────────────────────────────────────── */
.nd-empty {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 4rem 2rem;
  text-align: center;
}

.nd-empty__icon-wrap {
  width: 56px;
  height: 56px;
  border-radius: 16px;
  background: var(--c-ink-100, #f3f4f6);
  color: var(--c-ink-400, #9ca3af);
  display: flex;
  align-items: center;
  justify-content: center;
  margin-bottom: 1rem;
}

.nd-empty__title {
  font-size: var(--fs-15, .9375rem);
  font-weight: 700;
  color: var(--c-ink-800, #1e293b);
  margin: 0 0 .25rem;
}

.nd-empty__sub {
  font-size: var(--fs-13, .8125rem);
  color: var(--c-ink-400, #9ca3af);
  margin: 0;
}

/* ── Ambient footer ───────────────────────────────────────────────────────── */
.nd-ambient {
  display: flex;
  align-items: center;
  gap: .5rem;
  padding: .75rem 1rem;
  border-top: 1px solid var(--c-ink-200, #e5e7eb);
  background: #fffbeb;
  flex-shrink: 0;
}

.nd-ambient__icon {
  color: #d97706;
  flex-shrink: 0;
}

.nd-ambient__text {
  flex: 1;
  font-size: var(--fs-13, .8125rem);
  color: #92400e;
  font-weight: 500;
}

.nd-ambient__link {
  font-size: var(--fs-13, .8125rem);
  color: #d97706;
  font-weight: 600;
  text-decoration: none;
  white-space: nowrap;
  display: flex;
  align-items: center;
  gap: 2px;
}
.nd-ambient__link:hover { text-decoration: underline; }

/* ── Skeletons ────────────────────────────────────────────────────────────── */
.nd-card--skel {
  pointer-events: none;
}

.nd-skel {
  background: linear-gradient(90deg, var(--c-ink-100, #f3f4f6) 25%, #e9eaec 50%, var(--c-ink-100, #f3f4f6) 75%);
  background-size: 200% 100%;
  animation: nd-shimmer 1.4s ease-in-out infinite;
  border-radius: 4px;
}

.nd-skel--label  { height: 10px; width: 48px; }
.nd-skel--icon   { flex-shrink: 0; width: 36px; height: 36px; border-radius: 9px; }
.nd-skel--title  { height: 10px; width: 80px; margin-bottom: 6px; }
.nd-skel--msg    { height: 12px; width: 200px; max-width: 100%; }

@keyframes nd-shimmer {
  0%   { background-position:  200% 0; }
  100% { background-position: -200% 0; }
}

/* ── Transitions ──────────────────────────────────────────────────────────── */
.nd-fade-enter-active, .nd-fade-leave-active   { transition: opacity .2s ease; }
.nd-fade-enter-from,   .nd-fade-leave-to       { opacity: 0; }

.nd-slide-enter-active { transition: transform .28s cubic-bezier(0.16, 1, 0.3, 1); }
.nd-slide-leave-active { transition: transform .22s cubic-bezier(0.4, 0, 1, 1); }
.nd-slide-enter-from,
.nd-slide-leave-to     { transform: translateX(100%); }

/* ── Mobile ───────────────────────────────────────────────────────────────── */
@media (max-width: 480px) {
  .nd-panel { width: 100%; }
}
</style>
