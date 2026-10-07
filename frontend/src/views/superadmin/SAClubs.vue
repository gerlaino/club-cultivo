<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { formatPrecio } from '../../lib/formatters.js'
import DsSpinner from '../../design-system/components/Spinner.vue'
import { useRouter } from 'vue-router'
import { listSuperAdminClubs } from '../../lib/api.js'

const router  = useRouter()
const clubs   = ref([])
const loading = ref(true)
const search  = ref('')
const filterPlan = ref('todos')
const verEliminados = ref(false)
// «Para mirar»: lo que pide atención (plan vencido, sin suites, módulos a medias, suspendida),
// como el filtro del mostrador. La lista se abre para saber quién necesita algo.
const soloParaMirar = ref(false)
// Orden por columna. Por defecto, quién entró hace más tiempo primero: es la pregunta de churn.
const orden = ref({ col: 'ultimo_ingreso', asc: true })

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

// Cómo le va, en una palabra. `estado` dice si la cuenta está viva; esto dice si necesita algo,
// que es la pregunta con la que se abre esta lista. Antes había que cruzar plan, vencimiento,
// suites y módulos a ojo, fila por fila. "Operando" no se muestra: lo normal no necesita
// etiqueta — sólo se marca lo que pide atención.
const SALUD_META = {
  vencida:    { label: 'Plan vencido',      color: '#b91c1c', bg: '#fee2e2' },
  sin_suites: { label: 'Sin suites',        color: '#b91c1c', bg: '#fee2e2' },
  a_medias:   { label: 'Módulos a medias',  color: '#b45309', bg: '#fffbeb' },
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
// Los extras contratados, por nombre (los manda el backend: lo incluido no se cuenta).
function addonsDe(c) {
  return c.extras || []
}

function formatDate(d) {
  if (!d) return '—'
  return new Date(d).toLocaleDateString('es-AR', { day: 'numeric', month: 'short', year: 'numeric' })
}

// «hace 3 días» se lee más rápido que una fecha cuando la pregunta es si siguen entrando.
function hace(iso) {
  if (!iso) return 'nunca'
  const dias = Math.floor((Date.now() - new Date(iso).getTime()) / 86400000)
  if (dias <= 0) return 'hoy'
  if (dias === 1) return 'ayer'
  if (dias < 30) return `hace ${dias} días`
  const meses = Math.floor(dias / 30)
  return meses === 1 ? 'hace un mes' : `hace ${meses} meses`
}

function usoPct(t) { return t?.limite ? Math.round((t.uso / t.limite) * 100) : 0 }

function paraMirar(c) {
  return (c.estado && c.estado !== 'activo') || !!SALUD_META[c.salud]
}

function ordenarPor(col) {
  if (orden.value.col === col) orden.value.asc = !orden.value.asc
  else orden.value = { col, asc: col === 'name' || col === 'ultimo_ingreso' }
}

const VALOR = {
  name:           c => (c.name || '').toLowerCase(),
  precio_mensual: c => c.precio_mensual || 0,
  // Sin fecha va al final en cualquier sentido: "no vence" no es ni antes ni después.
  plan_activo_hasta: c => c.plan_activo_hasta ? new Date(c.plan_activo_hasta).getTime() : Infinity,
  ultimo_ingreso: c => c.ultimo_ingreso ? new Date(c.ultimo_ingreso).getTime() : -Infinity,
}

const filtrados = computed(() => {
  let list = clubs.value
  if (filterPlan.value === 'cultivo')  list = list.filter(c => c.features?.cultivo === true)
  if (filterPlan.value === 'dispensa') list = list.filter(c => c.features?.produccion_dispensa === true)
  if (filterPlan.value === 'completo') list = list.filter(c => c.features?.cultivo === true && c.features?.produccion_dispensa === true)
  if (soloParaMirar.value) list = list.filter(paraMirar)
  if (search.value.trim()) {
    const q = search.value.toLowerCase()
    list = list.filter(c =>
      c.name?.toLowerCase().includes(q) ||
      c.slug?.toLowerCase().includes(q) ||
      c.email?.toLowerCase().includes(q) ||
      c.city?.toLowerCase().includes(q)
    )
  }
  const val = VALOR[orden.value.col] || VALOR.name
  const dir = orden.value.asc ? 1 : -1
  return [...list].sort((a, b) => {
    const x = val(a), y = val(b)
    return x < y ? -dir : x > y ? dir : 0
  })
})

const cuantosParaMirar = computed(() => clubs.value.filter(paraMirar).length)

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
  <!-- Rediseño 7-oct-2026: una tabla de verdad, con las barras de uso del plan (pasando el 90%
       es el momento de ofrecer un pack). Filtros y orden, los mismos de antes. -->
  <div class="sa-page sac">
    <div class="sa-head">
      <div class="sa-head__txt">
        <div class="sa-sup">{{ clubs.length }} {{ clubs.length === 1 ? 'organización' : 'organizaciones' }}</div>
        <h1 class="sa-h1">Organizaciones</h1>
      </div>
      <button class="sa-btn sa-btn--primario" @click="router.push({ name: 'sa-club-nuevo' })">
        <i class="bi bi-plus-lg"></i> Nueva organización
      </button>
    </div>

    <div class="sa-filtros">
      <label for="sac-buscar" class="visually-hidden">Buscar organización</label>
      <input id="sac-buscar" v-model="search" class="sa-buscar" placeholder="Buscar por nombre, slug, mail o ciudad" />
      <div class="sa-filtros" role="group" aria-label="Filtrar por lo contratado">
        <button v-for="(meta, k) in FILTROS" :key="k" class="sa-chip" :class="{ 'sa-chip--on': filterPlan === k }"
                :aria-pressed="filterPlan === k" @click="filterPlan = k">{{ meta.label }}</button>
        <button class="sa-chip" :class="{ 'sa-chip--on': soloParaMirar }" :aria-pressed="soloParaMirar"
                @click="soloParaMirar = !soloParaMirar">
          Para mirar<template v-if="cuantosParaMirar"> · {{ cuantosParaMirar }}</template>
        </button>
        <label class="sac__ver-elim"><input v-model="verEliminados" type="checkbox" /> Ver eliminadas</label>
      </div>
    </div>

    <div v-if="loading" class="sac__loading"><DsSpinner /></div>
    <p v-else-if="!filtrados.length" class="sa-vacio">Ninguna organización coincide con la búsqueda.</p>

    <div v-else class="sa-tabla-wrap">
      <table class="sa-tabla">
        <thead>
          <tr>
            <th><button class="sac__th" @click="ordenarPor('name')">Organización <span v-if="orden.col === 'name'">{{ orden.asc ? '↑' : '↓' }}</span></button></th>
            <th><button class="sac__th" @click="ordenarPor('precio_mensual')">Plan y precio <span v-if="orden.col === 'precio_mensual'">{{ orden.asc ? '↑' : '↓' }}</span></button></th>
            <th>Pacientes</th>
            <th>Plantas en floración</th>
            <th><button class="sac__th" @click="ordenarPor('plan_activo_hasta')">Vence <span v-if="orden.col === 'plan_activo_hasta'">{{ orden.asc ? '↑' : '↓' }}</span></button></th>
            <th><button class="sac__th" @click="ordenarPor('ultimo_ingreso')">Último ingreso <span v-if="orden.col === 'ultimo_ingreso'">{{ orden.asc ? '↑' : '↓' }}</span></button></th>
            <th><span class="visually-hidden">Abrir</span></th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="c in filtrados" :key="c.id" class="sa-fila-link" :class="{ 'sac__fila--baja': c.estado && c.estado !== 'activo' }"
              @click="router.push({ name: 'sa-club-detail', params: { id: c.id } })">
            <td>
              <span class="sa-fuerte">{{ c.name }}</span>
              <span v-if="ESTADO_META[c.estado]" class="sa-tag" :class="c.estado === 'eliminado' ? 'sa-tag--mal' : 'sa-tag--atencion'" style="margin-left:.4rem">{{ ESTADO_META[c.estado].label }}</span>
              <span v-else-if="SALUD_META[c.salud]" class="sa-tag" :class="c.salud === 'a_medias' ? 'sa-tag--atencion' : 'sa-tag--mal'" style="margin-left:.4rem">{{ SALUD_META[c.salud].label }}</span>
              <br><span class="sa-tenue">{{ c.email || c.slug }}<template v-if="c.city"> · {{ c.city }}</template></span>
            </td>
            <td>
              <span v-if="c.personal" class="sa-tag sa-tag--ok">Autocultivo</span>
              <template v-else>
                <span v-for="k in suitesDe(c)" :key="k" class="sa-tag sa-tag--info" style="margin-right:.25rem">{{ SUITE_META[k].label }}</span>
                <span v-if="!suitesDe(c).length" class="sa-tag sa-tag--mal">Sin suites</span>
              </template>
              <span v-if="addonsDe(c).length" class="sa-tenue" :title="addonsDe(c).join(', ')"> +{{ addonsDe(c).length }}</span>
              <br><span class="sa-tenue">{{ formatPrecio(c.precio_mensual, c.moneda) }}/mes<template v-if="c.plan_trial"> · en prueba</template></span>
            </td>
            <td v-for="r in ['pacientes', 'plantas']" :key="r">
              <template v-if="c.topes?.[r] && !(r === 'pacientes' && c.personal)">
                <span class="sa-num">{{ c.topes[r].uso }}<template v-if="c.topes[r].limite"> / {{ c.topes[r].limite }}</template></span>
                <span v-if="c.topes[r].limite" class="sa-barra" :class="{ 'sa-barra--alta': usoPct(c.topes[r]) >= 90 }">
                  <span :style="{ width: `${Math.min(100, usoPct(c.topes[r]))}%` }"></span>
                </span>
              </template>
              <span v-else class="sa-tenue">—</span>
            </td>
            <td :class="{ 'sac__vencida': c.salud === 'vencida' }">{{ c.plan_activo_hasta ? formatDate(c.plan_activo_hasta) : 'sin vencimiento' }}</td>
            <td :class="{ 'sac__silencio': !c.ultimo_ingreso }" :title="c.ultimo_ingreso ? formatDate(c.ultimo_ingreso) : ''">{{ hace(c.ultimo_ingreso) }}</td>
            <td class="sa-der">
              <RouterLink :to="{ name: 'sa-club-detail', params: { id: c.id } }" class="sac__abrir" @click.stop>Abrir</RouterLink>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    <p class="sa-tenue">Las barras se ponen naranjas al pasar el 90% del tope: es el momento de ofrecer un pack.</p>
  </div>
</template>

<style scoped>
.sac__th { border: 0; background: none; padding: 0; font: inherit; color: inherit; letter-spacing: inherit; text-transform: inherit; cursor: pointer; }
.sac__ver-elim { display: inline-flex; align-items: center; gap: .35rem; font-size: .8rem; color: var(--c-slate-600); }
.sac__loading { display: flex; justify-content: center; padding: 3rem; }
.sac__fila--baja td { opacity: .7; }
.sac__vencida { color: var(--c-rust-600); font-weight: 600; }
.sac__silencio { color: var(--c-gold-500); }
.sac__abrir { font-weight: 600; font-size: .82rem; color: var(--c-leaf-800); }
.visually-hidden { position: absolute; width: 1px; height: 1px; overflow: hidden; clip: rect(0 0 0 0); white-space: nowrap; }
</style>
