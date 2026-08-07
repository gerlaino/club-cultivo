<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import DsSpinner from '../../design-system/components/Spinner.vue'
import { useRouter } from 'vue-router'
import { listSuperAdminClubs } from '../../lib/api.js'
import { Trash2, PauseCircle } from 'lucide-vue-next'

const router  = useRouter()
const clubs   = ref([])
const loading = ref(true)
const search  = ref('')
const filterPlan = ref('todos')
const verEliminados = ref(false)

const FILTROS = {
  todos:    { label: 'Todos',            color: '#0f172a', bg: '#f1f5f9' },
  completo: { label: 'Las dos suites',   color: '#7c3aed', bg: '#ede9fe' },
  cultivo:  { label: 'Sólo Cultivo',     color: '#15803d', bg: '#dcfce7' },
  dispensa: { label: 'Sólo Dispensa',    color: '#0369a1', bg: '#dbeafe' },
}

const ESTADO_META = {
  suspendido: { label: 'Suspendido', color: '#92400e', bg: '#fef3c7' },
  eliminado:  { label: 'Eliminado',  color: '#b91c1c', bg: '#fee2e2' },
}

// Ya no se vende por "planes" (Semilla/Brote/Cosecha/Federación) sino por SUITES: Cultivo y
// Producción/Dispensa, más add-ons. Lo que importa de un club en la lista es qué contrató,
// no en qué escalón de una tabla de precios vieja quedó.
const SUITE_META = {
  cultivo:             { label: 'Cultivo',  color: '#15803d', bg: '#dcfce7' },
  produccion_dispensa: { label: 'Dispensa', color: '#0369a1', bg: '#dbeafe' },
}
function suitesDe(c) {
  return Object.keys(SUITE_META).filter(k => c.features?.[k] === true)
}
function addonsDe(c) {
  const f = c.features || {}
  return Object.keys(f).filter(k => f[k] === true && !SUITE_META[k])
}

function formatDate(d) {
  if (!d) return '—'
  return new Date(d).toLocaleDateString('es-AR', { day: 'numeric', month: 'short', year: 'numeric' })
}

const filtrados = computed(() => {
  let list = clubs.value
  if (filterPlan.value === 'cultivo')  list = list.filter(c => c.features?.cultivo === true)
  if (filterPlan.value === 'dispensa') list = list.filter(c => c.features?.produccion_dispensa === true)
  if (filterPlan.value === 'completo') list = list.filter(c => c.features?.cultivo === true && c.features?.produccion_dispensa === true)
  if (search.value.trim()) {
    const q = search.value.toLowerCase()
    list = list.filter(c =>
      c.name?.toLowerCase().includes(q) ||
      c.slug?.toLowerCase().includes(q) ||
      c.email?.toLowerCase().includes(q) ||
      c.city?.toLowerCase().includes(q)
    )
  }
  return list
})

async function cargar() {
  loading.value = true
  try {
    const { data } = await listSuperAdminClubs(verEliminados.value ? { eliminados: true } : {})
    clubs.value = data
  } finally {
    loading.value = false
  }
}
watch(verEliminados, cargar)

onMounted(async () => {
  try {
    const { data } = await listSuperAdminClubs()
    clubs.value = data
  } finally {
    loading.value = false
  }
})
</script>

<template>
  <div class="sac">

    <div class="sac__header">
      <div>
        <div class="sac__eyebrow">Gestión global</div>
        <h1 class="sac__title">Clubs</h1>
      </div>
      <button class="sac__btn-primary" @click="router.push({ name: 'sa-club-nuevo' })">
        <i class="bi bi-plus-lg"></i> Nuevo club
      </button>
    </div>

    <!-- Filtros -->
    <div class="sac__toolbar">
      <div class="sac__search-wrap">
        <i class="bi bi-search sac__search-icon"></i>
        <input v-model="search" class="sac__search" placeholder="Buscar por nombre, slug, email, ciudad…" />
      </div>
      <div class="sac__plan-filters">
        <button
          v-for="(meta, k) in FILTROS"
          :key="k"
          class="sac__plan-filter"
          :class="{ 'sac__plan-filter--active': filterPlan === k }"
          :style="filterPlan === k ? { background: meta.bg, color: meta.color, borderColor: meta.color + '60' } : {}"
          @click="filterPlan = k"
        >
          {{ meta.label }}
        </button>
        <label class="sac__ver-elim">
          <input v-model="verEliminados" type="checkbox" />
          Ver eliminados
        </label>
      </div>
    </div>

    <div v-if="loading" class="sac__loading">
      <DsSpinner />
    </div>

    <div v-else-if="!filtrados.length" class="sac__empty">
      <i class="bi bi-building-slash sac__empty-icon"></i>
      <p>Sin clubs que coincidan con la búsqueda</p>
    </div>

    <div v-else class="sac__list">
      <div class="sac__list-header">
        <span>Club</span>
        <span>Contacto</span>
        <span>Plan</span>
        <span>Métricas</span>
        <span>Registrado</span>
        <span></span>
      </div>

      <RouterLink
        v-for="c in filtrados"
        :key="c.id"
        :to="{ name: 'sa-club-detail', params: { id: c.id } }"
        class="sac__row"
        :class="{ 'sac__row--baja': c.estado && c.estado !== 'activo' }"
      >
        <div class="sac__club-cell">
          <div class="sac__avatar">{{ c.name?.[0]?.toUpperCase() }}</div>
          <div>
            <div class="sac__name">
              {{ c.name }}
              <span v-if="ESTADO_META[c.estado]" class="sac__estado"
                    :style="{ background: ESTADO_META[c.estado].bg, color: ESTADO_META[c.estado].color }">
                <component :is="c.estado === 'eliminado' ? Trash2 : PauseCircle" :size="10" :stroke-width="2.5" />
                {{ ESTADO_META[c.estado].label }}
              </span>
            </div>
            <div class="sac__slug">{{ c.slug }}</div>
          </div>
        </div>

        <div class="sac__contact">
          <div v-if="c.email" class="sac__email">{{ c.email }}</div>
          <div v-if="c.city" class="sac__city">
            <i class="bi bi-geo-alt"></i> {{ c.city }}<span v-if="c.state">, {{ c.state }}</span>
          </div>
        </div>

        <!-- Qué contrató: las suites, y cuántos add-ons encima. -->
        <div class="sac__suites">
          <span v-for="k in suitesDe(c)" :key="k" class="sac__plan-pill"
                :style="{ background: SUITE_META[k].bg, color: SUITE_META[k].color }">
            {{ SUITE_META[k].label }}
          </span>
          <span v-if="!suitesDe(c).length" class="sac__plan-pill sac__plan-pill--none">Sin suites</span>
          <span v-if="addonsDe(c).length" class="sac__addons" :title="addonsDe(c).join(', ')">
            +{{ addonsDe(c).length }}
          </span>
          <div v-if="c.plan_activo_hasta" class="sac__hasta">hasta {{ formatDate(c.plan_activo_hasta) }}</div>
        </div>

        <div class="sac__metricas">
          <span class="sac__metrica"><i class="bi bi-people"></i> {{ c.usuarios_count }}</span>
          <span class="sac__metrica"><i class="bi bi-heart-pulse"></i> {{ c.pacientes_count }}</span>
          <span class="sac__metrica"><i class="bi bi-boxes"></i> {{ c.lotes_count }}</span>
        </div>

        <div class="sac__date">{{ formatDate(c.created_at) }}</div>

        <div class="sac__arrow"><i class="bi bi-arrow-right"></i></div>
      </RouterLink>
    </div>

    <div v-if="filtrados.length" class="sac__footer">
      {{ filtrados.length }} club{{ filtrados.length !== 1 ? 's' : '' }}
    </div>

  </div>
</template>

<style scoped>
.sac { padding: 2rem 2.5rem 3rem; }
.sac__header { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; margin-bottom: 1.75rem; flex-wrap: wrap; }
.sac__eyebrow { font-size: .72rem; font-weight: 800; text-transform: uppercase; letter-spacing: .1em; color: #94a3b8; margin-bottom: .35rem; }
.sac__title { font-size: 2rem; font-weight: 800; color: #0f172a; margin: 0; letter-spacing: -.04em; }

.sac__toolbar { display: flex; gap: 1rem; margin-bottom: 1.5rem; flex-wrap: wrap; align-items: center; }
.sac__search-wrap { position: relative; flex: 1; min-width: 240px; }
.sac__search-icon { position: absolute; left: .875rem; top: 50%; transform: translateY(-50%); color: #94a3b8; pointer-events: none; }
.sac__search { width: 100%; background: #fff; border: 1.5px solid #e2e8f0; border-radius: 10px; padding: .65rem .875rem .65rem 2.5rem; font-size: .875rem; color: #0f172a; box-sizing: border-box; transition: border .15s; }
.sac__search:focus { outline: none; border-color: #1b5e20; box-shadow: 0 0 0 3px rgba(27,94,32,.1); }
.sac__plan-filters { display: flex; gap: .4rem; flex-wrap: wrap; }
.sac__plan-filter { padding: .4rem .875rem; border-radius: 8px; border: 1.5px solid #e2e8f0; background: #fff; font-size: .78rem; font-weight: 600; cursor: pointer; color: #64748b; transition: all .15s; }
.sac__plan-filter:hover { border-color: #94a3b8; }

.sac__loading { display: flex; align-items: center; justify-content: center; padding: 4rem; }

.sac__empty { text-align: center; padding: 4rem; background: #fafbfc; border: 1.5px dashed #e2e8f0; border-radius: 14px; color: #94a3b8; }
.sac__empty-icon { font-size: 2.5rem; display: block; margin-bottom: .75rem; }

.sac__list { background: #fff; border: 1px solid #e2e8f0; border-radius: 14px; overflow: hidden; }
.sac__list-header { display: grid; grid-template-columns: 2fr 1.5fr 1fr 1fr 100px 40px; padding: .65rem 1.1rem; font-size: .7rem; font-weight: 700; text-transform: uppercase; letter-spacing: .05em; color: #94a3b8; border-bottom: 1px solid #f1f5f9; background: #fafbfc; }
.sac__row { display: grid; grid-template-columns: 2fr 1.5fr 1fr 1fr 100px 40px; align-items: center; padding: .875rem 1.1rem; border-bottom: 1px solid #f8fafc; text-decoration: none; color: inherit; transition: background .12s; }
.sac__row--baja { opacity: .6; }
.sac__suites { display: flex; flex-wrap: wrap; align-items: center; gap: .3rem; }
.sac__plan-pill--none { background: #f1f5f9; color: #94a3b8; }
.sac__addons { font-size: .7rem; font-weight: 700; color: #64748b; background: #f1f5f9; border-radius: 999px; padding: .1em .45em; cursor: help; }
.sac__estado { display: inline-flex; align-items: center; gap: .2rem; font-size: .62rem; font-weight: 700; padding: .1em .45em; border-radius: 5px; margin-left: .4rem; vertical-align: middle; }
.sac__ver-elim { display: inline-flex; align-items: center; gap: .35rem; font-size: .75rem; color: #64748b; cursor: pointer; margin-left: .5rem; }
.sac__row:last-child { border-bottom: none; }
.sac__row:hover { background: #fafbfc; }

.sac__club-cell { display: flex; align-items: center; gap: .75rem; }
.sac__avatar { width: 36px; height: 36px; border-radius: 9px; background: linear-gradient(135deg, rgba(27,94,32,.15), rgba(3,105,161,.15)); color: #1b5e20; font-size: .85rem; font-weight: 800; display: flex; align-items: center; justify-content: center; flex-shrink: 0; }
.sac__name { font-size: .875rem; font-weight: 700; color: #0f172a; }
.sac__slug { font-size: .7rem; color: #94a3b8; font-family: monospace; }

.sac__contact { min-width: 0; }
.sac__email { font-size: .78rem; color: #475569; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.sac__city  { font-size: .72rem; color: #94a3b8; margin-top: .1rem; display: flex; align-items: center; gap: .25rem; }

.sac__plan-pill { display: inline-block; font-size: .72rem; font-weight: 700; padding: .2em .6em; border-radius: 6px; }
.sac__trial { font-size: .65rem; font-weight: 600; color: #b45309; margin-top: .2rem; }
.sac__hasta { font-size: .68rem; color: #94a3b8; margin-top: .1rem; }

.sac__metricas { display: flex; gap: .75rem; flex-wrap: wrap; }
.sac__metrica { display: inline-flex; align-items: center; gap: .25rem; font-size: .75rem; color: #64748b; }

.sac__date { font-size: .75rem; color: #94a3b8; }
.sac__arrow { color: #cbd5e1; text-align: right; transition: color .15s, transform .15s; }
.sac__row:hover .sac__arrow { color: #0f172a; transform: translateX(2px); }
.sac__footer { text-align: right; font-size: .75rem; color: #94a3b8; margin-top: .75rem; }

.sac__btn-primary { display: inline-flex; align-items: center; gap: .4rem; background: var(--brand-primary, #1b5e20); color: #fff; border: none; padding: .65rem 1.25rem; border-radius: 9px; font-size: .875rem; font-weight: 700; cursor: pointer; transition: background .15s, transform .1s; white-space: nowrap; }
.sac__btn-primary:hover { background: #144a18; transform: translateY(-1px); }
</style>
