<template>
  <div class="mlo">
    <div class="mlo__topbar">
      <div class="mlo__tabs">
        <button class="mlo__tab" :class="{ 'mlo__tab--active': tab === 'activos' }" @click="tab = 'activos'">
          Activos <span class="mlo__tab-n">{{ activos.length }}</span>
        </button>
        <button class="mlo__tab" :class="{ 'mlo__tab--active': tab === 'finalizados' }" @click="tab = 'finalizados'">
          Finalizados <span class="mlo__tab-n">{{ finalizados.length }}</span>
        </button>
      </div>
      <button v-if="canCreate" class="mlo__fab" @click="showCreate = true">
        <i class="bi bi-plus-lg"></i>
      </button>
    </div>

    <div v-if="lotesStore.loading" class="mlo__loading">Cargando…</div>
    <div v-else-if="!listaMostrada.length" class="mlo__empty">
      <i class="bi bi-layers"></i>
      <p>Sin lotes {{ tab === 'activos' ? 'activos' : 'finalizados' }}</p>
    </div>

    <div v-else class="mlo__list">
      <RouterLink
        v-for="lote in listaMostrada"
        :key="lote.id"
        :to="`/m/lote/${lote.id}`"
        class="mlo__card"
      >
        <div class="mlo__card-dot" :style="{ background: estadoColor(lote.estado) }"></div>
        <div class="mlo__card-body">
          <div class="mlo__card-top">
            <span class="mlo__codigo">{{ lote.codigo }}</span>
            <span class="mlo__badge" :style="{ background: estadoColor(lote.estado) + '20', color: estadoColor(lote.estado) }">
              {{ estadoLabel(lote.estado) }}
            </span>
          </div>
          <div class="mlo__card-meta">
            <span>{{ lote.genetica?.nombre || lote.strain || '—' }}</span>
            <span class="mlo__meta-sep">·</span>
            <span>{{ lote.plants_count || 0 }} plantas</span>
            <template v-if="lote.sala?.nombre">
              <span class="mlo__meta-sep">·</span>
              <span class="mlo__sala">{{ lote.sala.nombre }}</span>
            </template>
          </div>
        </div>
        <i class="bi bi-chevron-right mlo__chevron"></i>
      </RouterLink>
    </div>

    <!-- Modal crear lote -->
    <Teleport to="body">
      <div v-if="showCreate" class="mlo__modal-overlay" @click.self="showCreate = false">
        <div class="mlo__modal">
          <div class="mlo__modal-header">
            <h3 class="mlo__modal-title">Nuevo lote</h3>
            <button class="mlo__modal-close" @click="showCreate = false"><i class="bi bi-x-lg"></i></button>
          </div>
          <div class="mlo__modal-body">
            <div class="mlo__field">
              <label class="mlo__label">Sala</label>
              <select v-model="form.sala_id" class="mlo__input">
                <option :value="null" disabled>Seleccioná una sala</option>
                <option v-for="s in salasActivas" :key="s.id" :value="s.id">{{ s.nombre }}</option>
              </select>
            </div>
            <div class="mlo__field">
              <label class="mlo__label">Genética</label>
              <select v-model="form.genetica_id" class="mlo__input">
                <option :value="null">Sin especificar</option>
                <option v-for="g in geneticas" :key="g.id" :value="g.id">{{ g.nombre }}</option>
              </select>
            </div>
            <div class="mlo__field">
              <label class="mlo__label">Estado inicial</label>
              <select v-model="form.estado" class="mlo__input">
                <option value="semilla">Semilla</option>
                <option value="esqueje">Esqueje</option>
                <option value="vegetativo">Vegetativo</option>
                <option value="floracion">Floración</option>
              </select>
            </div>
            <div class="mlo__field">
              <label class="mlo__label">Cantidad de plantas</label>
              <input v-model.number="form.plants_count" type="number" min="1" class="mlo__input" placeholder="Ej: 10" />
            </div>
            <div v-if="createError" class="mlo__error">{{ createError }}</div>
            <div class="mlo__modal-actions">
              <button class="mlo__btn-ghost" @click="showCreate = false">Cancelar</button>
              <button class="mlo__btn-primary" :disabled="saving" @click="crearLote">
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
import { useLotesStore } from '../../stores/lotes'
import { useSalasStore } from '../../stores/salas'
import { useAuthStore }  from '../../stores/auth'
import { listGeneticas, createLote, getLoteProximoCodigo } from '../../lib/api'

const router     = useRouter()
const lotesStore = useLotesStore()
const salasStore = useSalasStore()
const auth       = useAuthStore()

const tab        = ref('activos')
const showCreate = ref(false)
const saving     = ref(false)
const createError = ref(null)
const geneticas  = ref([])

const canCreate = computed(() => ['admin', 'supervisor', 'cultivador'].includes(auth.role))

const form = ref({ sala_id: null, genetica_id: null, estado: 'vegetativo', plants_count: 1 })

const activos     = computed(() => lotesStore.items.filter(l => l.estado !== 'finalizado'))
const finalizados = computed(() => lotesStore.items.filter(l => l.estado === 'finalizado'))
const listaMostrada = computed(() => tab.value === 'activos' ? activos.value : finalizados.value)

const salasActivas = computed(() => salasStore.items.filter(s => s.state === 'activa'))

const ESTADO_COLORS = {
  semilla: '#64748b', esqueje: '#0891b2', vegetativo: '#16a34a',
  floracion: '#9333ea', cosecha: '#dc2626', en_manicura: '#d97706',
  secado: '#d97706', curado: '#2563eb', finalizado: '#1a3d2e',
}
const ESTADO_LABELS = {
  semilla: 'Semilla', esqueje: 'Esqueje', vegetativo: 'Vegetativo',
  floracion: 'Floración', cosecha: 'Cosecha', en_manicura: 'Manicura',
  secado: 'Secado', curado: 'Curado', finalizado: 'Finalizado',
}
function estadoColor(e) { return ESTADO_COLORS[e] || '#64748b' }
function estadoLabel(e)  { return ESTADO_LABELS[e] || e || '—' }

async function crearLote() {
  if (!form.value.sala_id) { createError.value = 'Seleccioná una sala'; return }
  saving.value = true; createError.value = null
  try {
    const { data: codigoData } = await getLoteProximoCodigo()
    const { data: lote } = await createLote({
      sala_id:      form.value.sala_id,
      genetica_id:  form.value.genetica_id || undefined,
      estado:       form.value.estado,
      plants_count: form.value.plants_count || 1,
      codigo:       codigoData.codigo,
      start_date:   new Date().toISOString().slice(0, 10),
    })
    await lotesStore.fetchAll?.()
    showCreate.value = false
    router.push(`/m/lote/${lote.id}`)
  } catch (e) {
    createError.value = e?.response?.data?.error || 'Error al crear el lote'
  } finally {
    saving.value = false
  }
}

onMounted(async () => {
  await Promise.all([
    lotesStore.fetchAll?.(),
    salasStore.fetchAll?.(),
    listGeneticas({ limite: 100 }).then(r => { geneticas.value = r.data?.data || r.data || [] }).catch(() => {}),
  ])
})
</script>

<style scoped>
.mlo { padding: 0 0 1rem; }

.mlo__topbar { display: flex; align-items: center; justify-content: space-between; padding: .75rem 1rem; gap: .75rem; }
.mlo__tabs { display: flex; gap: .25rem; background: #f1f5f1; border-radius: 10px; padding: .2rem; flex: 1; }
.mlo__tab {
  flex: 1; padding: .45rem .5rem; border: none; background: none; border-radius: 8px;
  font-size: .75rem; font-weight: 600; color: #64748b; cursor: pointer; display: flex; align-items: center; justify-content: center; gap: .3rem;
  transition: all .15s;
}
.mlo__tab--active { background: #fff; color: #1b5e20; box-shadow: 0 1px 3px rgba(0,0,0,.1); }
.mlo__tab-n { background: #e8f0e9; color: #1b5e20; font-size: .65rem; font-weight: 700; padding: .1em .4em; border-radius: 999px; }
.mlo__tab--active .mlo__tab-n { background: #1b5e20; color: #fff; }
.mlo__fab { width: 38px; height: 38px; border-radius: 12px; background: #1b5e20; color: #fff; border: none; display: flex; align-items: center; justify-content: center; font-size: 1.1rem; cursor: pointer; flex-shrink: 0; }

.mlo__loading, .mlo__empty { display: flex; flex-direction: column; align-items: center; gap: .5rem; padding: 3rem 1rem; color: #94a3b8; font-size: .875rem; }
.mlo__empty i { font-size: 2rem; }

.mlo__list { display: flex; flex-direction: column; gap: .5rem; padding: 0 1rem; }
.mlo__card { display: flex; align-items: center; background: #fff; border-radius: 14px; box-shadow: 0 1px 4px rgba(0,0,0,.07); text-decoration: none; overflow: hidden; -webkit-tap-highlight-color: transparent; }
.mlo__card-dot { width: 5px; align-self: stretch; flex-shrink: 0; }
.mlo__card-body { flex: 1; padding: .875rem .875rem .875rem .75rem; min-width: 0; }
.mlo__card-top { display: flex; align-items: center; gap: .5rem; margin-bottom: .3rem; }
.mlo__codigo { font-size: .95rem; font-weight: 800; color: #0f172a; font-family: monospace; }
.mlo__badge { font-size: .65rem; font-weight: 700; padding: .2em .6em; border-radius: 999px; white-space: nowrap; }
.mlo__card-meta { font-size: .72rem; color: #64748b; display: flex; align-items: center; gap: .35rem; flex-wrap: wrap; }
.mlo__meta-sep { color: #cbd5e1; }
.mlo__sala { color: #94a3b8; }
.mlo__chevron { color: #d4e6d4; font-size: .8rem; padding-right: .875rem; flex-shrink: 0; }

/* Modal */
.mlo__modal-overlay { position: fixed; inset: 0; z-index: 200; background: rgba(0,0,0,.5); display: flex; align-items: flex-end; }
.mlo__modal { width: 100%; background: #fff; border-radius: 20px 20px 0 0; max-height: 90vh; overflow-y: auto; }
.mlo__modal-header { display: flex; align-items: center; justify-content: space-between; padding: 1rem 1.25rem; border-bottom: 1px solid #f1f5f9; }
.mlo__modal-title { font-size: 1rem; font-weight: 700; color: #0f172a; margin: 0; }
.mlo__modal-close { background: none; border: none; font-size: 1rem; color: #94a3b8; cursor: pointer; }
.mlo__modal-body { padding: 1.25rem; display: flex; flex-direction: column; gap: .875rem; }
.mlo__field { display: flex; flex-direction: column; gap: .3rem; }
.mlo__label { font-size: .72rem; font-weight: 700; color: #374151; text-transform: uppercase; letter-spacing: .04em; }
.mlo__input { background: #f8fafc; border: 1.5px solid #e2e8f0; border-radius: 9px; padding: .65rem .875rem; font-size: .9rem; color: #0f172a; outline: none; }
.mlo__input:focus { border-color: #1b5e20; }
.mlo__error { background: #fef2f2; color: #dc2626; border: 1px solid #fecaca; border-radius: 8px; padding: .5rem .75rem; font-size: .8rem; }
.mlo__modal-actions { display: flex; gap: .75rem; justify-content: flex-end; padding-top: .25rem; }
.mlo__btn-primary { background: #1b5e20; color: #fff; border: none; padding: .65rem 1.25rem; border-radius: 9px; font-size: .875rem; font-weight: 700; cursor: pointer; }
.mlo__btn-primary:disabled { opacity: .6; }
.mlo__btn-ghost { background: transparent; color: #64748b; border: 1.5px solid #e2e8f0; padding: .65rem 1rem; border-radius: 9px; font-size: .875rem; cursor: pointer; }
</style>
