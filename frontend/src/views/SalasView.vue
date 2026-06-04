<script setup>
import { ref, computed, watch, onMounted } from "vue";
import { useSalasStore } from "../stores/salas";
import { useAuthStore } from "../stores/auth";
import { listSedes } from "../lib/api";
import ModalCrearSala from '../components/salas/ModalCrearSala.vue'
import { useConfirm } from '../composables/useConfirm.js'
import DsSpinner from '../design-system/components/Spinner.vue'

const salas = useSalasStore();
const auth  = useAuthStore();
const sedes = ref([]);
const { confirm } = useConfirm();

onMounted(async () => {
  salas.fetch();
  const { data } = await listSedes();
  sedes.value = data || [];
});

const canEdit   = computed(() => ["admin","cultivador","supervisor"].includes(auth.role));
const canCreate = computed(() => ["admin","supervisor"].includes(auth.role));

function kindLabel(k) {
  const map = {
    vegetativo: "Vegetativo", floracion: "Floración", cosecha: "Cosecha",
    mixta: "Mixta", madre: "Madres", clon: "Clones", secado: "Secado",
    curado: "Curado", manicura: "Manicura",
  };
  return map[k] || k || "—";
}

function stateStyle(state) {
  if (state === 'activa')        return { bg: 'rgba(21,128,61,.1)',  color: '#15803d' };
  if (state === 'mantenimiento') return { bg: 'rgba(180,83,9,.1)',   color: '#b45309' };
  return { bg: 'rgba(100,116,139,.1)', color: '#475569' };
}

function stateLabel(state) {
  if (state === 'activa')        return 'Activa';
  if (state === 'mantenimiento') return 'Mantenimiento';
  return 'Cerrada';
}

function kindColor(k) {
  const map = {
    vegetativo: '#15803d', floracion: '#9333ea', cosecha: '#dc2626',
    secado: '#b45309', curado: '#0369a1', manicura: '#db2777',
    madre: '#16a34a', clon: '#2563eb', mixta: '#7c3aed',
  };
  return map[k] || '#64748b';
}

function kindEmoji(k) {
  const map = {
    vegetativo: '🍃', floracion: '🌸', cosecha: '🌾', secado: '💨',
    curado: '🫙', manicura: '✂️', madre: '🌱', clon: '🔁', mixta: '🔀',
  };
  return map[k] || '🏠';
}

// ── Filtros ──────────────────────────────────────────────────
const q           = ref("");
const filterState = ref("");
const filterKind  = ref("");
const sortBy      = ref("nombre_asc");
const viewMode    = ref("grid");
const page        = ref(1);
const perPage     = ref(9);

const KIND_TABS = [
  { value: '',           emoji: '🏠', label: 'Todas'      },
  { value: 'vegetativo', emoji: '🍃', label: 'Vegetativo' },
  { value: 'floracion',  emoji: '🌸', label: 'Floración'  },
  { value: 'cosecha',    emoji: '🌾', label: 'Cosecha'    },
  { value: 'secado',     emoji: '💨', label: 'Secado'     },
  { value: 'curado',     emoji: '🫙', label: 'Curado'     },
  { value: 'mixta',      emoji: '🔀', label: 'Mixta'      },
  { value: 'madre',      emoji: '🌱', label: 'Madres'     },
  { value: 'clon',       emoji: '🔁', label: 'Clones'     },
  { value: 'manicura',   emoji: '✂️', label: 'Manicura'   },
];

const kindTabs = computed(() =>
  KIND_TABS.map(t => ({
    ...t,
    count: t.value === '' ? salas.items.length : salas.items.filter(s => s.kind === t.value || s.tipo === t.value).length,
  })).filter(t => t.value === '' || t.count > 0)
);

const filtered = computed(() => {
  const q2 = q.value.trim().toLowerCase();
  return salas.items.filter(s => {
    const matchText  = !q2 || (s.nombre || '').toLowerCase().includes(q2) || (s.notes || '').toLowerCase().includes(q2);
    const matchState = !filterState.value || s.state === filterState.value;
    const matchKind  = !filterKind.value  || s.kind === filterKind.value || s.tipo === filterKind.value;
    return matchText && matchState && matchKind;
  });
});

const sorted = computed(() => {
  const arr = [...filtered.value];
  arr.sort((a, b) => {
    const nA = (a.nombre || '').toLowerCase(), nB = (b.nombre || '').toLowerCase();
    const oA = Number(a.porcentaje_ocupacion ?? 0), oB = Number(b.porcentaje_ocupacion ?? 0);
    const pA = Number(a.plantas_totales ?? 0), pB = Number(b.plantas_totales ?? 0);
    switch (sortBy.value) {
      case 'nombre_desc':    return nA < nB ? 1 : -1;
      case 'plantas_desc':   return pB - pA;
      case 'updated_desc':   return new Date(b.updated_at) - new Date(a.updated_at);
      default:               return nA > nB ? 1 : -1;
    }
  });
  return arr;
});

const totalItems = computed(() => sorted.value.length);
const totalPages = computed(() => Math.max(1, Math.ceil(totalItems.value / perPage.value)));
const paginated  = computed(() => sorted.value.slice((page.value - 1) * perPage.value, page.value * perPage.value));
watch([sorted, perPage], () => { if (page.value > totalPages.value) page.value = 1; });

// ── KPIs ─────────────────────────────────────────────────────
const stats = computed(() => {
  const all = salas.items;
  return {
    total:     all.length,
    activas:   all.filter(s => s.state === 'activa').length,
    plantas:   all.reduce((a, s) => a + Number(s.plantas_totales || 0), 0),
  };
});

// ── Modal Crear ───────────────────────────────────────────────
const showCreate = ref(false);

// ── Modal Editar ──────────────────────────────────────────────
const showEdit   = ref(false);
const editForm   = ref({ id: null, nombre: '', state: 'activa', kind: '', notes: '', sede_id: null });
const editErrors = ref({});

function startEdit(s) {
  editForm.value = {
    id: s.id, nombre: s.nombre || '', state: s.state || 'activa',
    kind: s.kind || '', notes: s.notes || '', sede_id: s.sede?.id || null,
  };
  editErrors.value = {};
  showEdit.value   = true;
}

async function submitEdit() {
  const e = {};
  if (!editForm.value.nombre?.trim()) e.nombre = 'Obligatorio';
  if (!editForm.value.sede_id) e.sede_id = 'La sede es obligatoria';
  editErrors.value = e;
  if (Object.keys(e).length) return;
  try {
    const { id, ...payload } = editForm.value;
    await salas.update(id, payload);
    showEdit.value = false;
  } catch {}
}

// ── Eliminar ──────────────────────────────────────────────────
async function confirmDelete(s) {
  const ok = await confirm({
    title: `Eliminar "${s.nombre}"`,
    message: 'La sala quedará archivada (soft delete). Sus lotes y plantas permanecen en la base de datos y pueden recuperarse.',
    confirmText: 'Archivar',
    variant: 'danger',
  });
  if (!ok) return;
  try { await salas.remove(s.id); } catch {}
}
</script>

<template>
  <div class="slv">

    <!-- Header -->
    <div class="slv__header">
      <div class="slv__header-left">
        <h1 class="slv__title">Salas de cultivo</h1>
        <p class="slv__sub">Gestioná los espacios físicos del club</p>
      </div>
      <button v-if="canCreate" class="slv__btn-primary" @click="showCreate = true">
        <i class="bi bi-plus-lg"></i> Nueva sala
      </button>
    </div>

    <!-- KPIs -->
    <div class="slv__kpis">
      <div class="slv__kpi">
        <div class="slv__kpi-icon">🏠</div>
        <div class="slv__kpi-body">
          <div class="slv__kpi-val">{{ stats.total }}</div>
          <div class="slv__kpi-lbl">Total salas</div>
        </div>
      </div>
      <div class="slv__kpi slv__kpi--accent">
        <div class="slv__kpi-icon">🟢</div>
        <div class="slv__kpi-body">
          <div class="slv__kpi-val" style="color:#15803d">{{ stats.activas }}</div>
          <div class="slv__kpi-lbl">Activas</div>
        </div>
      </div>
      <div class="slv__kpi">
        <div class="slv__kpi-icon">🌿</div>
        <div class="slv__kpi-body">
          <div class="slv__kpi-val">{{ stats.plantas }}</div>
          <div class="slv__kpi-lbl">Plantas totales</div>
        </div>
      </div>
    </div>

    <!-- Tabs por tipo -->
    <div class="slv__tabs">
      <button
        v-for="tab in kindTabs" :key="tab.value"
        class="slv__tab"
        :class="{ 'slv__tab--active': filterKind === tab.value }"
        @click="filterKind = tab.value; page = 1"
      >
        {{ tab.emoji }} {{ tab.label }}
        <span class="slv__tab-count">{{ tab.count }}</span>
      </button>
    </div>

    <!-- Toolbar -->
    <div class="slv__toolbar">
      <input type="search" class="slv__search" placeholder="Buscar sala…" v-model.trim="q" />
      <select class="slv__select" v-model="filterState">
        <option value="">Todos los estados</option>
        <option value="activa">Activa</option>
        <option value="mantenimiento">Mantenimiento</option>
        <option value="cerrada">Cerrada</option>
      </select>
      <select class="slv__select" v-model="sortBy">
        <option value="nombre_asc">Nombre A→Z</option>
        <option value="nombre_desc">Nombre Z→A</option>
        <option value="plantas_desc">Más plantas</option>
        <option value="updated_desc">Más recientes</option>
      </select>
      <div class="slv__view-toggle">
        <button class="slv__view-btn" :class="{ 'slv__view-btn--on': viewMode === 'grid' }" @click="viewMode = 'grid'" title="Grilla">
          <i class="bi bi-grid-3x3-gap"></i>
        </button>
        <button class="slv__view-btn" :class="{ 'slv__view-btn--on': viewMode === 'list' }" @click="viewMode = 'list'" title="Lista">
          <i class="bi bi-list-ul"></i>
        </button>
      </div>
      <span class="slv__count-label">{{ paginated.length }} de {{ totalItems }}</span>
    </div>

    <!-- Loading / Error / Empty -->
    <div v-if="salas.loading" class="slv__loading">
      <DsSpinner />
    </div>
    <div v-else-if="salas.error" class="slv__alert">{{ salas.error }}</div>
    <div v-else-if="!salas.items.length" class="slv__empty">
      <div class="slv__empty-icon">🏗️</div>
      <p class="slv__empty-title">No hay salas todavía</p>
      <p v-if="canCreate" class="slv__empty-sub">Creá la primera sala para organizar el cultivo.</p>
      <button v-if="canCreate" class="slv__btn-primary" @click="showCreate = true">
        <i class="bi bi-plus-lg"></i> Nueva sala
      </button>
    </div>
    <div v-else-if="!paginated.length" class="slv__empty">
      <div class="slv__empty-icon">🔍</div>
      <p class="slv__empty-title">Sin resultados</p>
      <p class="slv__empty-sub">Probá con otros filtros.</p>
    </div>

    <!-- Grid -->
    <div v-else-if="viewMode === 'grid'" class="slv__grid">
      <RouterLink
        v-for="s in paginated" :key="s.id"
        class="slv__card"
        :to="{ name: 'sala-detail', params: { id: s.id } }"
      >
        <div class="slv__card-top-bar" :style="{ background: kindColor(s.kind || s.tipo) }"></div>
        <div class="slv__card-body">

          <div class="slv__card-head">
            <div class="slv__card-kind-icon">{{ kindEmoji(s.kind || s.tipo) }}</div>
            <div class="slv__card-meta">
              <div class="slv__card-nombre">{{ s.nombre }}</div>
              <div class="slv__card-tipo">{{ kindLabel(s.kind) }}</div>
            </div>
            <span class="slv__state-pill" :style="stateStyle(s.state)">{{ stateLabel(s.state) }}</span>
          </div>

          <div v-if="s.sede" class="slv__card-sede">
            <i class="bi bi-building"></i> {{ s.sede.nombre }}
          </div>

          <div class="slv__card-stats">
            <span class="slv__card-stat">
              <i class="bi bi-layers"></i>
              {{ s.lotes_count ?? 0 }} lote{{ s.lotes_count !== 1 ? 's' : '' }}
            </span>
            <span class="slv__card-stat-sep">·</span>
            <span class="slv__card-stat">
              <i class="bi bi-flower2"></i>
              {{ s.plantas_totales ?? 0 }} planta{{ s.plantas_totales !== 1 ? 's' : '' }}
            </span>
          </div>

          <p v-if="s.notes" class="slv__card-notes">{{ s.notes }}</p>

          <div class="slv__card-footer">
            <span v-if="s.created_by_name" class="slv__card-author">
              <i class="bi bi-person"></i> {{ s.created_by_name }}
            </span>
            <div v-if="canEdit" class="slv__card-actions" @click.prevent>
              <button class="slv__icon-btn" title="Editar" @click.stop="startEdit(s)">
                <i class="bi bi-pencil"></i>
              </button>
              <button class="slv__icon-btn slv__icon-btn--danger" title="Eliminar" @click.stop="confirmDelete(s)" :disabled="salas.removing">
                <i class="bi bi-trash3"></i>
              </button>
            </div>
          </div>
        </div>
      </RouterLink>
    </div>

    <!-- Lista -->
    <div v-else class="slv__table-wrap">
      <table class="slv__table">
        <thead>
          <tr>
            <th>Sala</th>
            <th>Estado</th>
            <th>Plantas</th>
            <th>Sede</th>
            <th></th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="s in paginated" :key="s.id">
            <td>
              <RouterLink :to="{ name: 'sala-detail', params: { id: s.id } }" class="slv__table-link">
                <span class="slv__table-emoji">{{ kindEmoji(s.kind) }}</span>
                <span>
                  <div class="slv__table-nombre">{{ s.nombre }}</div>
                  <div class="slv__table-kind">{{ kindLabel(s.kind) }}</div>
                </span>
              </RouterLink>
            </td>
            <td>
              <span class="slv__state-pill" :style="stateStyle(s.state)">{{ stateLabel(s.state) }}</span>
            </td>
            <td class="slv__table-nums">{{ s.plantas_totales ?? 0 }}</td>
            <td class="slv__table-sede">{{ s.sede?.nombre || '—' }}</td>
            <td>
              <div v-if="canEdit" class="slv__table-acts">
                <button class="slv__icon-btn" @click="startEdit(s)"><i class="bi bi-pencil"></i></button>
                <button class="slv__icon-btn slv__icon-btn--danger" @click="confirmDelete(s)" :disabled="salas.removing"><i class="bi bi-trash3"></i></button>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Paginación -->
    <div v-if="totalPages > 1" class="slv__pagination">
      <button class="slv__page-btn" :disabled="page <= 1" @click="page--">‹</button>
      <button
        v-for="p in totalPages" :key="p"
        class="slv__page-btn"
        :class="{ 'slv__page-btn--active': p === page }"
        @click="page = p"
      >{{ p }}</button>
      <button class="slv__page-btn" :disabled="page >= totalPages" @click="page++">›</button>
    </div>

    <!-- Modal Crear -->
    <ModalCrearSala
      v-if="showCreate"
      @close="showCreate = false"
      @created="salas.fetch(); showCreate = false"
    />

    <!-- Modal Editar -->
    <Teleport to="body">
      <Transition name="slv-modal">
        <div v-if="showEdit" class="slv__modal-overlay">
          <div class="slv__modal">
            <div class="slv__modal-header">
              <h3 class="slv__modal-title">Editar sala</h3>
              <button class="slv__modal-close" @click="showEdit = false"><i class="bi bi-x-lg"></i></button>
            </div>
            <div class="slv__modal-body">
              <div class="slv__field">
                <label class="slv__label">Nombre <span class="slv__required">*</span></label>
                <input class="slv__input" :class="{ 'slv__input--err': editErrors.nombre }" v-model.trim="editForm.nombre" />
                <span v-if="editErrors.nombre" class="slv__err">{{ editErrors.nombre }}</span>
              </div>
              <div class="slv__field-row">
                <div class="slv__field">
                  <label class="slv__label">Estado</label>
                  <select class="slv__input" v-model="editForm.state">
                    <option value="activa">Activa</option>
                    <option value="mantenimiento">Mantenimiento</option>
                    <option value="cerrada">Cerrada</option>
                  </select>
                </div>
                <div class="slv__field">
                  <label class="slv__label">Tipo</label>
                  <select class="slv__input" v-model="editForm.kind">
                    <option value="">Sin especificar</option>
                    <option value="vegetativo">Vegetativo</option>
                    <option value="floracion">Floración</option>
                    <option value="cosecha">Cosecha</option>
                    <option value="secado">Secado</option>
                    <option value="curado">Curado</option>
                    <option value="mixta">Mixta</option>
                    <option value="madre">Madres</option>
                    <option value="clon">Clones</option>
                    <option value="manicura">Manicura</option>
                  </select>
                </div>
              </div>
              <div class="slv__field-row">
                <div class="slv__field">
                  <label class="slv__label">Sede <span class="slv__required">*</span></label>
                  <select class="slv__input" :class="{ 'slv__input--err': editErrors.sede_id }" v-model="editForm.sede_id">
                    <option :value="null" disabled>Seleccioná una sede</option>
                    <option v-for="sede in sedes.filter(s => ['produccion','mixta'].includes(s.tipo))" :key="sede.id" :value="sede.id">{{ sede.nombre }}</option>
                  </select>
                  <span v-if="editErrors.sede_id" class="slv__err">{{ editErrors.sede_id }}</span>
                </div>
              </div>
              <div class="slv__field">
                <label class="slv__label">Notas</label>
                <textarea class="slv__input slv__textarea" rows="2" v-model.trim="editForm.notes"></textarea>
              </div>
            </div>
            <div class="slv__modal-footer">
              <button class="slv__btn-ghost" @click="showEdit = false">Cancelar</button>
              <button class="slv__btn-primary" :disabled="salas.updating" @click="submitEdit">
                <DsSpinner v-if="salas.updating" :size="14" />
                Guardar cambios
              </button>
            </div>
          </div>
        </div>
      </Transition>
    </Teleport>

  </div>
</template>

<style scoped>
/* ── Layout ───────────────────────────────────────────── */
.slv { padding: 1.5rem 1.25rem; max-width: 1280px; margin: 0 auto; }

/* ── Header ───────────────────────────────────────────── */
.slv__header { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; margin-bottom: 1.5rem; }
.slv__title  { font-size: 1.5rem; font-weight: 700; color: #0f2611; margin: 0 0 .25rem; }
.slv__sub    { font-size: .85rem; color: #60725d; margin: 0; }

/* ── KPIs ─────────────────────────────────────────────── */
.slv__kpis { display: grid; grid-template-columns: repeat(4, 1fr); gap: .75rem; margin-bottom: 1.25rem; }
@media (max-width: 640px) { .slv__kpis { grid-template-columns: repeat(2, 1fr); } }
.slv__kpi { background: #fff; border: 1px solid #e8f0e9; border-radius: 12px; padding: 1rem; display: flex; align-items: center; gap: .75rem; }
.slv__kpi--accent { border-color: #bbf7d0; background: #f0fdf4; }
.slv__kpi-icon { font-size: 1.4rem; line-height: 1; }
.slv__kpi-val  { font-size: 1.5rem; font-weight: 700; color: #0f2611; line-height: 1; }
.slv__kpi-lbl  { font-size: .75rem; color: #60725d; margin-top: .2rem; }

/* ── Tabs ─────────────────────────────────────────────── */
.slv__tabs { display: flex; flex-wrap: wrap; gap: .4rem; margin-bottom: 1rem; }
.slv__tab  { display: inline-flex; align-items: center; gap: .35rem; padding: .4rem .85rem; border: 1.5px solid #e2e8f0; border-radius: 999px; background: #f8fafc; font-size: .8rem; font-weight: 600; color: #64748b; cursor: pointer; transition: all .15s; white-space: nowrap; }
.slv__tab:hover { border-color: #94a3b8; color: #0f172a; }
.slv__tab--active { border-color: #1b5e20; background: #f0fdf4; color: #1b5e20; }
.slv__tab-count { background: #e2e8f0; color: #64748b; font-size: .68rem; padding: .1em .45em; border-radius: 999px; }
.slv__tab--active .slv__tab-count { background: #dcfce7; color: #15803d; }

/* ── Toolbar ──────────────────────────────────────────── */
.slv__toolbar { display: flex; flex-wrap: wrap; align-items: center; gap: .5rem; margin-bottom: 1.25rem; background: #fff; border: 1px solid #e8f0e9; border-radius: 10px; padding: .75rem 1rem; }
.slv__search  { flex: 1 1 180px; padding: .5rem .8rem; border: 1px solid #d4e6d4; border-radius: 8px; font-size: .85rem; outline: none; }
.slv__search:focus { border-color: #1b5e20; }
.slv__select  { padding: .5rem .75rem; border: 1px solid #d4e6d4; border-radius: 8px; font-size: .85rem; background: #fff; outline: none; }
.slv__view-toggle { display: flex; gap: .25rem; }
.slv__view-btn { padding: .45rem .6rem; border: 1px solid #d4e6d4; border-radius: 7px; background: transparent; color: #60725d; cursor: pointer; font-size: .85rem; transition: all .15s; }
.slv__view-btn--on { background: #f0fdf4; border-color: #1b5e20; color: #1b5e20; }
.slv__count-label { font-size: .8rem; color: #60725d; margin-left: auto; }

/* ── States ───────────────────────────────────────────── */
.slv__loading { display: flex; align-items: center; justify-content: center; min-height: calc(100vh - 56px); }
.slv__alert   { padding: 1rem; background: #fef2f2; border: 1px solid #fecaca; border-radius: 10px; color: #dc2626; }
.slv__empty   { text-align: center; padding: 4rem 1rem; }
.slv__empty-icon  { font-size: 3rem; margin-bottom: .75rem; }
.slv__empty-title { font-size: 1.1rem; font-weight: 600; color: #0f2611; margin: 0 0 .5rem; }
.slv__empty-sub   { color: #60725d; font-size: .9rem; margin: 0 0 1rem; }

/* ── Grid ─────────────────────────────────────────────── */
.slv__grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(280px, 1fr)); gap: 1rem; margin-bottom: 1.25rem; }

.slv__card { background: #fff; border: 1px solid #e8f0e9; border-radius: 12px; overflow: hidden; text-decoration: none; color: inherit; display: flex; flex-direction: column; transition: transform .15s, box-shadow .15s, border-color .15s; }
.slv__card:hover { transform: translateY(-2px); box-shadow: 0 6px 20px rgba(0,0,0,.08); border-color: #c8e6c9; }

.slv__card-top-bar { height: 4px; width: 100%; flex-shrink: 0; }
.slv__card-body    { padding: 1rem; display: flex; flex-direction: column; gap: .6rem; flex: 1; }

.slv__card-head { display: flex; align-items: flex-start; gap: .6rem; }
.slv__card-kind-icon { font-size: 1.5rem; line-height: 1; flex-shrink: 0; }
.slv__card-meta { flex: 1; min-width: 0; }
.slv__card-nombre { font-weight: 700; color: #0f2611; font-size: .95rem; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.slv__card-tipo   { font-size: .75rem; color: #60725d; }
.slv__card-sede   { font-size: .78rem; color: #60725d; display: flex; align-items: center; gap: .3rem; }

.slv__state-pill { display: inline-flex; align-items: center; padding: .2rem .6rem; border-radius: 999px; font-size: .72rem; font-weight: 600; flex-shrink: 0; white-space: nowrap; }

.slv__ocu       { display: flex; flex-direction: column; gap: .25rem; }
.slv__ocu-row   { display: flex; justify-content: space-between; font-size: .78rem; }
.slv__ocu-label { color: #60725d; }
.slv__ocu-nums  { font-weight: 600; color: #0f2611; }
.slv__ocu-bar   { height: 6px; background: #e8f0e9; border-radius: 999px; overflow: hidden; }
.slv__ocu-fill  { height: 100%; border-radius: 999px; transition: width .3s; }
.slv__ocu-pct   { font-size: .75rem; font-weight: 600; text-align: right; }

.slv__card-stats { display: flex; align-items: center; gap: .35rem; font-size: .78rem; color: #60725d; }
.slv__card-stat { display: flex; align-items: center; gap: .25rem; }
.slv__card-stat-sep { color: #c8d5c0; }
.slv__card-notes { font-size: .78rem; color: #60725d; margin: 0; display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical; overflow: hidden; flex: 1; }

.slv__card-footer { display: flex; align-items: center; justify-content: space-between; margin-top: auto; padding-top: .5rem; border-top: 1px solid #f0f4f0; }
.slv__card-author { font-size: .75rem; color: #60725d; display: flex; align-items: center; gap: .3rem; }
.slv__card-actions { display: flex; gap: .3rem; }

/* ── Table (list view) ────────────────────────────────── */
.slv__table-wrap { background: #fff; border: 1px solid #e8f0e9; border-radius: 12px; overflow: hidden; margin-bottom: 1.25rem; }
.slv__table { width: 100%; border-collapse: collapse; font-size: .85rem; }
.slv__table th { padding: .75rem 1rem; background: #f6faf6; font-weight: 600; color: #0f2611; text-align: left; border-bottom: 1px solid #e8f0e9; font-size: .78rem; }
.slv__table td { padding: .75rem 1rem; border-bottom: 1px solid #f0f4f0; vertical-align: middle; }
.slv__table tr:last-child td { border-bottom: none; }
.slv__table tr:hover td { background: #f8fdf8; }

.slv__table-link  { display: flex; align-items: center; gap: .6rem; text-decoration: none; color: inherit; }
.slv__table-emoji { font-size: 1.2rem; flex-shrink: 0; }
.slv__table-nombre { font-weight: 600; color: #0f2611; }
.slv__table-kind   { font-size: .75rem; color: #60725d; }
.slv__table-nums   { font-weight: 600; font-variant-numeric: tabular-nums; }
.slv__table-sede   { color: #60725d; }
.slv__table-acts   { display: flex; gap: .3rem; justify-content: flex-end; }

/* ── Buttons ──────────────────────────────────────────── */
.slv__btn-primary { display: inline-flex; align-items: center; gap: .4rem; background: #1b5e20; color: #fff; border: none; padding: .6rem 1.2rem; border-radius: 9px; font-size: .875rem; font-weight: 600; cursor: pointer; transition: background .15s; white-space: nowrap; }
.slv__btn-primary:hover:not(:disabled) { background: #104417; }
.slv__btn-primary:disabled { opacity: .5; cursor: not-allowed; }
.slv__btn-ghost { background: transparent; color: #60725d; border: 1px solid #d4e6d4; padding: .6rem 1.1rem; border-radius: 8px; font-size: .875rem; font-weight: 500; cursor: pointer; transition: all .15s; }
.slv__btn-ghost:hover { background: #f0fdf4; color: #1b5e20; }

.slv__icon-btn { display: inline-flex; align-items: center; justify-content: center; width: 30px; height: 30px; border-radius: 7px; border: 1px solid #d4e6d4; background: transparent; color: #60725d; cursor: pointer; font-size: .8rem; transition: all .15s; }
.slv__icon-btn:hover { background: #f0fdf4; border-color: #1b5e20; color: #1b5e20; }
.slv__icon-btn--danger:hover { background: #fef2f2; border-color: #fca5a5; color: #dc2626; }
.slv__icon-btn:disabled { opacity: .4; cursor: not-allowed; }

/* ── Pagination ───────────────────────────────────────── */
.slv__pagination { display: flex; gap: .3rem; justify-content: center; margin-top: .5rem; }
.slv__page-btn { min-width: 34px; height: 34px; padding: 0 .5rem; border: 1px solid #e8f0e9; border-radius: 8px; background: #fff; color: #60725d; font-size: .85rem; cursor: pointer; transition: all .15s; }
.slv__page-btn:hover:not(:disabled) { background: #f0fdf4; border-color: #1b5e20; color: #1b5e20; }
.slv__page-btn--active { background: #1b5e20; color: #fff; border-color: #1b5e20; font-weight: 600; }
.slv__page-btn:disabled { opacity: .4; cursor: not-allowed; }

/* ── Spinner ──────────────────────────────────────────── */

/* ── Modal ────────────────────────────────────────────── */
.slv__modal-overlay { position: fixed; inset: 0; background: rgba(0,0,0,.4); z-index: 2000; display: flex; align-items: center; justify-content: center; padding: 1rem; }
.slv__modal { background: #fff; border-radius: 16px; width: 100%; max-width: 480px; max-height: 90vh; overflow-y: auto; box-shadow: 0 20px 60px rgba(0,0,0,.2); }
.slv__modal-header { display: flex; align-items: center; justify-content: space-between; padding: 1.25rem 1.5rem 1rem; border-bottom: 1px solid #e8f0e9; }
.slv__modal-title  { font-size: 1.05rem; font-weight: 700; color: #0f2611; margin: 0; }
.slv__modal-close  { background: none; border: none; font-size: 1rem; color: #60725d; cursor: pointer; padding: .25rem; border-radius: 6px; }
.slv__modal-close:hover { background: #f0f4f0; }
.slv__modal-body   { padding: 1.25rem 1.5rem; display: flex; flex-direction: column; gap: .9rem; }
.slv__modal-footer { padding: 1rem 1.5rem; border-top: 1px solid #e8f0e9; display: flex; justify-content: flex-end; gap: .6rem; }

.slv__field     { display: flex; flex-direction: column; gap: .3rem; flex: 1; }
.slv__field-row { display: flex; gap: .75rem; }
.slv__label     { font-size: .8rem; font-weight: 600; color: #0f2611; }
.slv__required  { color: #dc2626; }
.slv__input     { padding: .55rem .75rem; border: 1px solid #d4e6d4; border-radius: 8px; font-size: .875rem; outline: none; width: 100%; }
.slv__input:focus { border-color: #1b5e20; }
.slv__input--err  { border-color: #fca5a5; }
.slv__textarea  { resize: vertical; min-height: 64px; }
.slv__err       { font-size: .75rem; color: #dc2626; }

/* ── Transition ───────────────────────────────────────── */
.slv-modal-enter-active, .slv-modal-leave-active { transition: opacity .2s; }
.slv-modal-enter-active .slv__modal, .slv-modal-leave-active .slv__modal { transition: transform .2s; }
.slv-modal-enter-from, .slv-modal-leave-to { opacity: 0; }
.slv-modal-enter-from .slv__modal, .slv-modal-leave-to .slv__modal { transform: scale(.95) translateY(-10px); }

@media (max-width: 640px) {
  .slv { padding: 1rem .75rem; }
  .slv__grid { grid-template-columns: 1fr; }
  .slv__toolbar { gap: .4rem; }
  .slv__field-row { flex-direction: column; }
}
</style>
