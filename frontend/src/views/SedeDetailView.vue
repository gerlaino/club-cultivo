<script setup>
import { ref, computed, onMounted } from "vue"
import { useRoute, useRouter } from "vue-router"
import { useAuthStore } from "../stores/auth"
import { getSede, listSalas } from "../lib/api"
import ModalCrearSala from '../components/salas/ModalCrearSala.vue'

const route  = useRoute()
const router = useRouter()
const auth   = useAuthStore()

const sedeId        = Number(route.params.id)
const sede          = ref(null)
const salas         = ref([])
const loading       = ref(true)
const error         = ref(null)
const showCrearSala = ref(false)

const canEdit = computed(() => ["admin", "agricultor"].includes(auth.role))

const TIPO_META = {
  produccion: { label: "Producción",  icon: "bi-flower2",         color: "#15803d", bg: "rgba(21,128,61,.1)"  },
  social:     { label: "Dispensario", icon: "bi-shop",             color: "#0369a1", bg: "rgba(3,105,161,.1)"  },
  mixta:      { label: "Mixta",       icon: "bi-arrow-left-right", color: "#7c3aed", bg: "rgba(124,58,237,.1)" },
}
function tipoMeta(tipo) { return TIPO_META[tipo] || TIPO_META.produccion }

const kpis = computed(() => ({
  total:     salas.value.length,
  activas:   salas.value.filter(s => s.state === "activa").length,
  plantas:   salas.value.reduce((a, s) => a + Number(s.plantas_totales || 0), 0),
  capacidad: salas.value.reduce((a, s) => a + Number(s.pots_count || s.plants_max || 0), 0),
}))

function ocupacionColor(pct) {
  if (pct >= 90) return "#dc2626"
  if (pct >= 70) return "#f59e0b"
  return "#15803d"
}

function formatDate(d) {
  if (!d) return "—"
  return new Date(d).toLocaleDateString("es-AR", { day: "numeric", month: "short", year: "numeric" })
}

async function recargarSalas() {
  const r = await listSalas()
  salas.value = (r.data || []).filter(s => s.sede?.id === sedeId)
}

function onSalaCreada() {
  showCrearSala.value = false
  recargarSalas()
}

onMounted(async () => {
  try {
    const [sedeRes, salasRes] = await Promise.all([getSede(sedeId), listSalas()])
    sede.value  = sedeRes.data
    salas.value = (salasRes.data || []).filter(s => s.sede?.id === sedeId)
  } catch (e) {
    error.value = "No se pudo cargar la sede."
  } finally {
    loading.value = false
  }
})
</script>

<template>
  <div class="sdv">

    <div v-if="loading" class="sdv__loading">
      <div class="sdv__ring"></div>
      <span>Cargando sede…</span>
    </div>

    <div v-else-if="error" class="sdv__error">
      <i class="bi bi-exclamation-triangle-fill"></i> {{ error }}
    </div>

    <template v-else-if="sede">

      <!-- Breadcrumb -->
      <div class="sdv__breadcrumb">
        <RouterLink :to="{ name: 'sedes' }" class="sdv__breadcrumb-link">Sedes</RouterLink>
        <i class="bi bi-chevron-right sdv__breadcrumb-sep"></i>
        <span>{{ sede.nombre }}</span>
      </div>

      <!-- Header -->
      <div class="sdv__header">
        <div class="sdv__header-left">
          <div class="sdv__tipo-icon" :style="{ background: tipoMeta(sede.tipo).bg, color: tipoMeta(sede.tipo).color }">
            <i :class="['bi', tipoMeta(sede.tipo).icon]"></i>
          </div>
          <div>
            <div class="sdv__title-row">
              <h1 class="sdv__title">{{ sede.nombre }}</h1>
              <span class="sdv__tipo-badge" :style="{ background: tipoMeta(sede.tipo).bg, color: tipoMeta(sede.tipo).color }">
                {{ tipoMeta(sede.tipo).label }}
              </span>
              <span v-if="sede.declarada_reprocann" class="sdv__reprocann-badge">
                <i class="bi bi-patch-check-fill"></i> REPROCANN
              </span>
            </div>
            <p v-if="sede.direccion_completa" class="sdv__subtitle">
              <i class="bi bi-geo-alt"></i> {{ sede.direccion_completa }}
            </p>
          </div>
        </div>
        <div class="sdv__header-actions">
          <button v-if="canEdit" class="sdv__btn-primary" @click="showCrearSala = true">
            <i class="bi bi-plus-lg"></i> Nueva sala aquí
          </button>
          <button class="sdv__btn-ghost" @click="router.back()">
            <i class="bi bi-arrow-left"></i> Volver
          </button>
        </div>
      </div>

      <!-- KPIs -->
      <div class="sdv__kpis">
        <div class="sdv__kpi">
          <div class="sdv__kpi-val">{{ kpis.total }}</div>
          <div class="sdv__kpi-lbl">Salas totales</div>
        </div>
        <div class="sdv__kpi">
          <div class="sdv__kpi-val" style="color:#15803d">{{ kpis.activas }}</div>
          <div class="sdv__kpi-lbl">Activas</div>
        </div>
        <div class="sdv__kpi">
          <div class="sdv__kpi-val">{{ kpis.plantas }}</div>
          <div class="sdv__kpi-lbl">Plantas totales</div>
        </div>
        <div class="sdv__kpi">
          <div class="sdv__kpi-val">{{ kpis.capacidad }}</div>
          <div class="sdv__kpi-lbl">Capacidad total</div>
        </div>
      </div>

      <!-- Layout -->
      <div class="sdv__layout">

        <!-- Salas -->
        <div class="sdv__col-main">
          <div class="sdv__card">
            <div class="sdv__card-header">
              <div class="sdv__card-title-wrap">
                <span class="sdv__card-icon" style="background:rgba(27,94,32,.1);color:#1b5e20">
                  <i class="bi bi-grid-3x3-gap"></i>
                </span>
                <span class="sdv__card-title">Salas de esta sede</span>
                <span class="sdv__pill">{{ salas.length }}</span>
              </div>
              <RouterLink :to="{ name: 'salas' }" class="sdv__card-btn">
                Ver todas →
              </RouterLink>
            </div>

            <div v-if="!salas.length" class="sdv__empty">
              <i class="bi bi-building-slash sdv__empty-icon"></i>
              <p>Esta sede no tiene salas asignadas todavía.</p>
              <button v-if="canEdit" class="sdv__btn-sm-green" @click="showCrearSala = true">
                Crear primera sala
              </button>
            </div>

            <div v-else class="sdv__salas">
              <RouterLink
                v-for="s in salas"
                :key="s.id"
                :to="{ name: 'sala-detail', params: { id: s.id } }"
                class="sdv__sala"
              >
                <div class="sdv__sala-state"
                     :style="{ background: s.state === 'activa' ? '#15803d' : s.state === 'mantenimiento' ? '#f59e0b' : '#94a3b8' }">
                </div>
                <div class="sdv__sala-body">
                  <div class="sdv__sala-header">
                    <span class="sdv__sala-nombre">{{ s.nombre }}</span>
                    <div class="sdv__sala-badges">
                      <span class="sdv__state-badge"
                            :style="s.state === 'activa' ? 'background:#dcfce7;color:#15803d' : s.state === 'mantenimiento' ? 'background:#fffbeb;color:#b45309' : 'background:#f1f5f9;color:#64748b'">
                        {{ s.state }}
                      </span>
                      <span v-if="s.kind" class="sdv__kind-badge">{{ s.kind }}</span>
                    </div>
                  </div>
                  <div class="sdv__sala-meta">
                    <span><i class="bi bi-flower1"></i> {{ s.plantas_totales ?? 0 }} plantas</span>
                    <span><i class="bi bi-box-seam"></i> cap. {{ s.pots_count ?? s.plants_max ?? 0 }}</span>
                    <span v-if="s.lotes_count !== undefined"><i class="bi bi-collection"></i> {{ s.lotes_count }} lotes</span>
                  </div>
                </div>
                <div class="sdv__sala-ocupacion">
                  <div class="sdv__ocu-pct" :style="{ color: ocupacionColor(s.porcentaje_ocupacion || 0) }">
                    {{ (s.porcentaje_ocupacion || 0).toFixed(0) }}%
                  </div>
                  <div class="sdv__ocu-bar">
                    <div class="sdv__ocu-fill"
                         :style="{ width: Math.min(s.porcentaje_ocupacion || 0, 100) + '%', background: ocupacionColor(s.porcentaje_ocupacion || 0) }">
                    </div>
                  </div>
                  <div class="sdv__ocu-label">ocupación</div>
                </div>
                <i class="bi bi-arrow-right sdv__sala-arrow"></i>
              </RouterLink>
            </div>
          </div>
        </div>

        <!-- Sidebar — solo info -->
        <div class="sdv__col-side">
          <div class="sdv__card">
            <div class="sdv__card-header">
              <div class="sdv__card-title-wrap">
                <span class="sdv__card-icon" style="background:rgba(3,105,161,.1);color:#0369a1">
                  <i class="bi bi-info-circle"></i>
                </span>
                <span class="sdv__card-title">Información</span>
              </div>
            </div>
            <dl class="sdv__dl">
              <dt>Tipo</dt>
              <dd>
                <span class="sdv__tipo-badge sdv__tipo-badge--sm"
                      :style="{ background: tipoMeta(sede.tipo).bg, color: tipoMeta(sede.tipo).color }">
                  {{ tipoMeta(sede.tipo).label }}
                </span>
              </dd>
              <dt>Estado</dt>
              <dd>
                <span class="sdv__state-badge"
                      :style="sede.activa ? 'background:#dcfce7;color:#15803d' : 'background:#fffbeb;color:#b45309'">
                  {{ sede.activa ? "Activa" : "Inactiva" }}
                </span>
              </dd>
              <dt>REPROCANN</dt>
              <dd>
                <span class="sdv__state-badge"
                      :style="sede.declarada_reprocann ? 'background:#dcfce7;color:#15803d' : 'background:#f1f5f9;color:#64748b'">
                  {{ sede.declarada_reprocann ? "Declarada ✓" : "No declarada" }}
                </span>
              </dd>
              <template v-if="sede.direccion">
                <dt>Dirección</dt><dd>{{ sede.direccion }}</dd>
              </template>
              <template v-if="sede.ciudad">
                <dt>Ciudad</dt><dd>{{ sede.ciudad }}</dd>
              </template>
              <template v-if="sede.provincia">
                <dt>Provincia</dt><dd>{{ sede.provincia }}</dd>
              </template>
              <dt>Registrada</dt>
              <dd>{{ formatDate(sede.created_at) }}</dd>
            </dl>
          </div>

          <div v-if="sede.notas" class="sdv__card sdv__card--mt">
            <div class="sdv__card-header">
              <div class="sdv__card-title-wrap">
                <span class="sdv__card-icon" style="background:rgba(180,83,9,.1);color:#b45309">
                  <i class="bi bi-journal-text"></i>
                </span>
                <span class="sdv__card-title">Notas</span>
              </div>
            </div>
            <p class="sdv__notas">{{ sede.notas }}</p>
          </div>
        </div>

      </div>

    </template>

    <!-- Modal crear sala con sede pre-seleccionada y oculta -->
    <ModalCrearSala
      v-if="showCrearSala"
      :sede-id-fija="sedeId"
      @close="showCrearSala = false"
      @created="onSalaCreada"
    />

  </div>
</template>

<style scoped>
.sdv { padding: 1.75rem 1.75rem 3rem; max-width: 1200px; margin: 0 auto; }
@media (max-width: 768px) { .sdv { padding: 1.25rem 1rem 2rem; } }

.sdv__loading { display: flex; align-items: center; justify-content: center; gap: .75rem; padding: 5rem; color: #94a3b8; }
.sdv__ring { width: 22px; height: 22px; border: 2px solid #e2e8f0; border-top-color: #1b5e20; border-radius: 50%; animation: sdv-spin .7s linear infinite; }
@keyframes sdv-spin { to { transform: rotate(360deg); } }
.sdv__error { background: #fef2f2; border: 1px solid #fecaca; color: #dc2626; padding: 1rem; border-radius: 10px; display: flex; gap: .5rem; align-items: center; }

.sdv__breadcrumb { display: flex; align-items: center; gap: .4rem; font-size: .8rem; color: #94a3b8; margin-bottom: 1.25rem; }
.sdv__breadcrumb-link { color: #0369a1; text-decoration: none; font-weight: 600; }
.sdv__breadcrumb-link:hover { text-decoration: underline; }
.sdv__breadcrumb-sep { font-size: .65rem; }

.sdv__header { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; margin-bottom: 1.75rem; flex-wrap: wrap; }
.sdv__header-left { display: flex; align-items: flex-start; gap: 1rem; }
.sdv__tipo-icon { width: 52px; height: 52px; border-radius: 14px; display: flex; align-items: center; justify-content: center; font-size: 1.3rem; flex-shrink: 0; }
.sdv__title-row { display: flex; align-items: center; gap: .6rem; flex-wrap: wrap; margin-bottom: .25rem; }
.sdv__title { font-size: 1.75rem; font-weight: 800; color: #0f172a; margin: 0; letter-spacing: -.03em; }
.sdv__tipo-badge { font-size: .72rem; font-weight: 700; padding: .2em .65em; border-radius: 6px; }
.sdv__tipo-badge--sm { font-size: .72rem; font-weight: 700; padding: .2em .55em; border-radius: 5px; }
.sdv__reprocann-badge { display: inline-flex; align-items: center; gap: .3rem; font-size: .72rem; font-weight: 700; background: #dcfce7; color: #15803d; padding: .2em .6em; border-radius: 6px; }
.sdv__subtitle { font-size: .83rem; color: #64748b; margin: 0; display: flex; align-items: center; gap: .35rem; }
.sdv__header-actions { display: flex; gap: .6rem; flex-wrap: wrap; align-items: center; }

.sdv__kpis { display: grid; grid-template-columns: repeat(4, 1fr); gap: 1rem; margin-bottom: 1.75rem; }
@media (max-width: 640px) { .sdv__kpis { grid-template-columns: repeat(2, 1fr); } }
.sdv__kpi { background: #fff; border: 1px solid #e2e8f0; border-radius: 12px; padding: 1.1rem 1rem; text-align: center; }
.sdv__kpi-val { font-size: 2rem; font-weight: 800; color: #0f172a; line-height: 1; letter-spacing: -.04em; }
.sdv__kpi-lbl { font-size: .72rem; font-weight: 600; color: #94a3b8; text-transform: uppercase; letter-spacing: .04em; margin-top: .35rem; }

.sdv__layout { display: grid; grid-template-columns: 1fr 280px; gap: 1.25rem; align-items: start; }
@media (max-width: 900px) { .sdv__layout { grid-template-columns: 1fr; } }
.sdv__col-side { display: flex; flex-direction: column; position: sticky; top: 1.5rem; }
.sdv__card--mt { margin-top: 1.25rem; }

.sdv__card { background: #fff; border: 1px solid #e2e8f0; border-radius: 14px; overflow: hidden; }
.sdv__card-header { display: flex; align-items: center; justify-content: space-between; padding: .875rem 1.1rem; border-bottom: 1px solid #f1f5f9; background: #fafbfc; }
.sdv__card-title-wrap { display: flex; align-items: center; gap: .6rem; }
.sdv__card-icon { width: 30px; height: 30px; border-radius: 7px; display: flex; align-items: center; justify-content: center; font-size: .8rem; flex-shrink: 0; }
.sdv__card-title { font-size: .875rem; font-weight: 700; color: #0f172a; }
.sdv__card-btn { font-size: .78rem; font-weight: 600; color: #0369a1; background: none; border: none; cursor: pointer; padding: 0; text-decoration: none; }
.sdv__card-btn:hover { text-decoration: underline; }
.sdv__pill { font-size: .65rem; font-weight: 800; background: #f1f5f9; color: #475569; padding: .15em .5em; border-radius: 999px; }

.sdv__empty { text-align: center; padding: 3rem 1rem; color: #94a3b8; }
.sdv__empty-icon { font-size: 2.5rem; display: block; margin-bottom: .75rem; opacity: .4; }
.sdv__empty p { font-size: .875rem; margin: 0 0 .75rem; }

.sdv__salas { display: flex; flex-direction: column; }
.sdv__sala { display: flex; align-items: center; gap: .875rem; padding: .875rem 1.1rem; border-bottom: 1px solid #f8fafc; text-decoration: none; color: inherit; transition: background .12s; }
.sdv__sala:last-child { border-bottom: none; }
.sdv__sala:hover { background: #fafbfc; }
.sdv__sala-state { width: 3px; height: 40px; border-radius: 999px; flex-shrink: 0; }
.sdv__sala-body { flex: 1; min-width: 0; }
.sdv__sala-header { display: flex; align-items: center; gap: .5rem; flex-wrap: wrap; margin-bottom: .25rem; }
.sdv__sala-nombre { font-size: .9rem; font-weight: 700; color: #0f172a; }
.sdv__sala-badges { display: flex; gap: .35rem; }
.sdv__state-badge { font-size: .68rem; font-weight: 700; padding: .2em .5em; border-radius: 5px; }
.sdv__kind-badge { font-size: .68rem; font-weight: 600; background: #f1f5f9; color: #64748b; padding: .2em .5em; border-radius: 5px; text-transform: capitalize; }
.sdv__sala-meta { display: flex; gap: .75rem; font-size: .75rem; color: #94a3b8; flex-wrap: wrap; }
.sdv__sala-meta i { margin-right: .2rem; }
.sdv__sala-ocupacion { display: flex; flex-direction: column; align-items: flex-end; gap: .2rem; min-width: 70px; flex-shrink: 0; }
.sdv__ocu-pct { font-size: .78rem; font-weight: 700; }
.sdv__ocu-bar { width: 70px; height: 4px; background: #f1f5f9; border-radius: 999px; overflow: hidden; }
.sdv__ocu-fill { height: 100%; border-radius: 999px; transition: width .4s; }
.sdv__ocu-label { font-size: .62rem; color: #94a3b8; }
.sdv__sala-arrow { color: #cbd5e1; font-size: .85rem; flex-shrink: 0; transition: color .15s, transform .15s; }
.sdv__sala:hover .sdv__sala-arrow { color: #0f172a; transform: translateX(2px); }

.sdv__dl { display: grid; grid-template-columns: 100px 1fr; gap: .4rem .5rem; padding: 1rem 1.1rem; margin: 0; }
.sdv__dl dt { font-size: .75rem; color: #94a3b8; font-weight: 500; display: flex; align-items: center; }
.sdv__dl dd { font-size: .82rem; color: #0f172a; font-weight: 500; margin: 0; display: flex; align-items: center; }
.sdv__notas { padding: .875rem 1.1rem; font-size: .85rem; color: #475569; margin: 0; line-height: 1.6; }

.sdv__btn-primary { display: inline-flex; align-items: center; gap: .4rem; background: var(--brand-primary, #1b5e20); color: #fff; border: none; padding: .6rem 1.1rem; border-radius: 8px; font-size: .875rem; font-weight: 700; cursor: pointer; text-decoration: none; transition: background .15s, transform .1s; white-space: nowrap; }
.sdv__btn-primary:hover { background: #144a18; transform: translateY(-1px); }
.sdv__btn-ghost { display: inline-flex; align-items: center; gap: .4rem; background: #fff; color: #64748b; border: 1.5px solid #e2e8f0; padding: .6rem 1rem; border-radius: 8px; font-size: .875rem; font-weight: 600; cursor: pointer; transition: all .15s; white-space: nowrap; }
.sdv__btn-ghost:hover { background: #f8fafc; color: #0f172a; }
.sdv__btn-sm-green { display: inline-flex; align-items: center; gap: .35rem; background: rgba(27,94,32,.08); color: #1b5e20; border: 1.5px solid rgba(27,94,32,.2); padding: .45rem .875rem; border-radius: 7px; font-size: .8rem; font-weight: 600; cursor: pointer; transition: all .15s; }
.sdv__btn-sm-green:hover { background: rgba(27,94,32,.14); }
</style>
