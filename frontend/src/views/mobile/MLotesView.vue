<template>
  <div class="ml">
    <div class="ml__header">
      <div class="ml__tabs">
        <button class="ml__tab" :class="{ 'ml__tab--on': tab === 'activos' }" @click="tab = 'activos'">
          Activos <span class="ml__n" :class="{ 'ml__n--on': tab === 'activos' }">{{ activos.length }}</span>
        </button>
        <button class="ml__tab" :class="{ 'ml__tab--on': tab === 'finalizados' }" @click="tab = 'finalizados'">
          Finalizados <span class="ml__n">{{ finalizados.length }}</span>
        </button>
      </div>
      <button v-if="canCreate" class="ml__add-btn" @click="showCrear = true">
        <i class="bi bi-plus-lg"></i>
      </button>
    </div>

    <div v-if="loading" class="ml__loading">
      <i class="bi bi-arrow-repeat ml__spin"></i> Cargando…
    </div>
    <div v-else-if="!listaMostrada.length" class="ml__empty">
      <i class="bi bi-layers ml__empty-icon"></i>
      <p>Sin lotes {{ tab === 'activos' ? 'activos' : 'finalizados' }}</p>
    </div>

    <div v-else class="ml__list">
      <RouterLink
        v-for="lote in listaMostrada"
        :key="lote.id"
        :to="`/m/lote/${lote.id}`"
        class="ml__card"
      >
        <div class="ml__card-stripe" :style="{ background: estadoColor(lote.estado) }"></div>
        <div class="ml__card-body">
          <div class="ml__card-top">
            <span class="ml__codigo">{{ lote.codigo }}</span>
            <span class="ml__badge" :style="{ background: estadoColor(lote.estado) + '22', color: estadoColor(lote.estado) }">
              {{ estadoLabel(lote.estado) }}
            </span>
          </div>
          <div class="ml__card-meta">
            <span>{{ lote.genetica?.nombre || '—' }}</span>
            <span class="ml__dot">·</span>
            <span>{{ lote.plants_count || 0 }} plantas</span>
            <template v-if="lote.sala?.nombre">
              <span class="ml__dot">·</span>
              <span class="ml__sala">{{ lote.sala.nombre }}</span>
            </template>
          </div>
        </div>
        <i class="bi bi-chevron-right ml__chevron"></i>
      </RouterLink>
    </div>

    <!-- Sheet crear lote -->
    <Teleport to="body">
      <div v-if="showCrear" class="ml__overlay" @click.self="showCrear = false">
        <div class="ml__sheet">
          <div class="ml__sheet-handle"></div>
          <div class="ml__sheet-header">
            <h3 class="ml__sheet-title">Crear lote</h3>
            <button class="ml__sheet-close" @click="showCrear = false"><i class="bi bi-x-lg"></i></button>
          </div>
          <div class="ml__sheet-body">
            <div class="ml__field">
              <label class="ml__label">Sala <span class="ml__req">*</span></label>
              <select v-model="form.sala_id" class="ml__input">
                <option :value="null" disabled>Seleccioná una sala</option>
                <option v-for="s in salas" :key="s.id" :value="s.id">{{ s.nombre }}</option>
              </select>
            </div>
            <div class="ml__field">
              <label class="ml__label">Genética</label>
              <select v-model="form.genetica_id" class="ml__input">
                <option :value="null">Sin especificar</option>
                <option v-for="g in geneticas" :key="g.id" :value="g.id">{{ g.nombre }}</option>
              </select>
            </div>
            <div class="ml__field">
              <label class="ml__label">Estado inicial</label>
              <select v-model="form.estado" class="ml__input">
                <option value="enraizado">Enraizado</option>
                <option value="vegetativo">Vegetativo</option>
                <option value="floracion">Floración</option>
              </select>
            </div>
            <div class="ml__field">
              <label class="ml__label">Cantidad de plantas</label>
              <input v-model.number="form.plants_count" type="number" min="1" class="ml__input" placeholder="Ej: 10" />
            </div>
            <div v-if="createError" class="ml__error">{{ createError }}</div>
            <div class="ml__sheet-actions">
              <button class="ml__btn-ghost" @click="showCrear = false">Cancelar</button>
              <button class="ml__btn-primary" :disabled="saving" @click="crearLote">
                <i v-if="!saving" class="bi bi-plus-lg"></i>
                {{ saving ? 'Creando…' : 'Crear lote' }}
              </button>
            </div>
          </div>
        </div>
      </div>
    </Teleport>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { listLotes, listSalas, listGeneticas, getLoteProximoCodigo, createLote } from '../../lib/api'
import { useAuthStore } from '../../stores/auth'

const router = useRouter()
const auth   = useAuthStore()

const lotes      = ref([])
const salas      = ref([])
const geneticas  = ref([])
const loading    = ref(false)
const showCrear  = ref(false)
const saving     = ref(false)
const createError = ref(null)
const tab        = ref('activos')

const canCreate  = computed(() => ['admin', 'supervisor', 'cultivador'].includes(auth.role))

const activos     = computed(() => lotes.value.filter(l => l.estado !== 'finalizado'))
const finalizados = computed(() => lotes.value.filter(l => l.estado === 'finalizado'))
const listaMostrada = computed(() => tab.value === 'activos' ? activos.value : finalizados.value)

const form = ref({ sala_id: null, genetica_id: null, estado: 'vegetativo', plants_count: 1 })

const EC = { semilla:'#64748b', esqueje:'#0891b2', vegetativo:'#16a34a', floracion:'#9333ea', cosecha:'#dc2626', en_manicura:'#d97706', curado:'#2563eb', finalizado:'#1a3d2e' }
const EL = { enraizado: 'Enraizado', vegetativo:'Vegetativo', floracion:'Floración', cosecha:'Cosecha', en_manicura:'Manicura', curado:'Curado', finalizado:'Finalizado' }
const estadoColor = e => EC[e] || '#64748b'
const estadoLabel = e => EL[e] || e || '—'

async function crearLote() {
  if (!form.value.sala_id) { createError.value = 'Seleccioná una sala'; return }
  saving.value = true; createError.value = null
  try {
    const { data: cd } = await getLoteProximoCodigo()
    const { data: lote } = await createLote({
      sala_id:      form.value.sala_id,
      genetica_id:  form.value.genetica_id || undefined,
      estado:       form.value.estado,
      plants_count: form.value.plants_count || 1,
      codigo:       cd.codigo,
      start_date:   new Date().toISOString().slice(0, 10),
    })
    showCrear.value = false
    router.push(`/m/lote/${lote.id}`)
  } catch (e) {
    createError.value = e?.response?.data?.error || 'Error al crear el lote'
  } finally { saving.value = false }
}

async function load() {
  loading.value = true
  try {
    const { data } = await listLotes()
    lotes.value = data || []
  } catch {} finally { loading.value = false }
}

onMounted(async () => {
  await load()
  listSalas().then(r => { salas.value = r.data || [] }).catch(() => {})
  listGeneticas({ limite: 100 }).then(r => { geneticas.value = r.data?.data || r.data || [] }).catch(() => {})
})
</script>

<style scoped>
.ml { padding: 0 0 1.5rem; }
.ml__header { display: flex; align-items: center; gap: .75rem; padding: .75rem 1rem; }
.ml__tabs { display: flex; gap: .2rem; background: #f1f5f1; border-radius: 10px; padding: .2rem; flex: 1; }
.ml__tab { flex: 1; padding: .45rem; border: none; background: none; border-radius: 8px; font-size: .75rem; font-weight: 600; color: var(--c-slate-500); cursor: pointer; display: flex; align-items: center; justify-content: center; gap: .3rem; transition: all .15s; }
.ml__tab--on { background: #fff; color: #1b5e20; box-shadow: 0 1px 3px rgba(0,0,0,.1); }
.ml__n { background: #f1f5f1; color: var(--c-slate-400); font-size: .62rem; font-weight: 700; padding: .1em .4em; border-radius: 999px; }
.ml__n--on { background: #1b5e20; color: #fff; }
.ml__add-btn { width: 36px; height: 36px; border-radius: 10px; background: #1b5e20; color: #fff; border: none; font-size: 1rem; display: flex; align-items: center; justify-content: center; cursor: pointer; flex-shrink: 0; }

.ml__loading { display: flex; align-items: center; gap: .5rem; justify-content: center; padding: 2.5rem; color: var(--c-slate-400); font-size: .875rem; }
.ml__spin { animation: spin .8s linear infinite; }
@keyframes spin { to { transform: rotate(360deg); } }
.ml__empty { display: flex; flex-direction: column; align-items: center; gap: .5rem; padding: 3rem 1rem; color: var(--c-slate-400); font-size: .875rem; }
.ml__empty-icon { font-size: 2.5rem; }

.ml__list { display: flex; flex-direction: column; gap: .5rem; padding: 0 1rem; }
.ml__card { display: flex; align-items: center; background: #fff; border-radius: 14px; box-shadow: 0 1px 4px rgba(0,0,0,.07); text-decoration: none; overflow: hidden; -webkit-tap-highlight-color: transparent; }
.ml__card-stripe { width: 4px; align-self: stretch; flex-shrink: 0; }
.ml__card-body { flex: 1; padding: .875rem .75rem; min-width: 0; }
.ml__card-top { display: flex; align-items: center; gap: .5rem; margin-bottom: .25rem; }
.ml__codigo { font-size: .95rem; font-weight: 800; color: var(--c-slate-900); font-family: monospace; }
.ml__badge { font-size: .62rem; font-weight: 700; padding: .2em .55em; border-radius: 999px; white-space: nowrap; }
.ml__card-meta { font-size: .72rem; color: var(--c-slate-500); display: flex; align-items: center; gap: .3rem; flex-wrap: wrap; }
.ml__dot { color: #d1d5db; }
.ml__sala { color: var(--c-slate-400); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; max-width: 100px; }
.ml__chevron { color: #d1d5db; font-size: .8rem; padding-right: .875rem; flex-shrink: 0; }

/* Sheet */
.ml__overlay { position: fixed; inset: 0; z-index: 200; background: rgba(0,0,0,.5); display: flex; align-items: flex-end; }
.ml__sheet { width: 100%; background: #fff; border-radius: 20px 20px 0 0; max-height: 90vh; overflow-y: auto; }
.ml__sheet-handle { width: 40px; height: 4px; background: var(--c-slate-200); border-radius: 999px; margin: .75rem auto .25rem; }
.ml__sheet-header { display: flex; align-items: center; justify-content: space-between; padding: .5rem 1.25rem 1rem; }
.ml__sheet-title { font-size: 1rem; font-weight: 700; margin: 0; color: var(--c-slate-900); }
.ml__sheet-close { background: none; border: none; color: var(--c-slate-400); font-size: 1rem; cursor: pointer; }
.ml__sheet-body { padding: 0 1.25rem 2rem; display: flex; flex-direction: column; gap: .875rem; }
.ml__field { display: flex; flex-direction: column; gap: .3rem; }
.ml__label { font-size: .72rem; font-weight: 700; color: #374151; text-transform: uppercase; letter-spacing: .04em; }
.ml__req { color: #dc2626; }
.ml__input { background: var(--c-slate-50); border: 1.5px solid var(--c-slate-200); border-radius: 9px; padding: .65rem .875rem; font-size: .9rem; color: var(--c-slate-900); outline: none; width: 100%; box-sizing: border-box; }
.ml__input:focus { border-color: #1b5e20; }
.ml__error { background: #fef2f2; color: #dc2626; border: 1px solid #fecaca; border-radius: 8px; padding: .5rem .75rem; font-size: .8rem; }
.ml__sheet-actions { display: flex; gap: .75rem; justify-content: flex-end; padding-top: .25rem; }
.ml__btn-primary { display: flex; align-items: center; gap: .4rem; background: #1b5e20; color: #fff; border: none; padding: .7rem 1.25rem; border-radius: 9px; font-size: .875rem; font-weight: 700; cursor: pointer; }
.ml__btn-primary:disabled { opacity: .6; }
.ml__btn-ghost { background: transparent; color: var(--c-slate-500); border: 1.5px solid var(--c-slate-200); padding: .7rem 1rem; border-radius: 9px; font-size: .875rem; cursor: pointer; }
</style>
