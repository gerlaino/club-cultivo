<script setup>
import { ref, computed, watch, onMounted, onUnmounted } from "vue";
import AppDatePicker from '../components/ui/AppDatePicker.vue'
import { useLotesStore } from "../stores/lotes";
import { useSalasStore } from "../stores/salas";
import { useAuthStore }  from "../stores/auth";
import Paginator from '../components/ui/Paginator.vue';
import EmptyState from '../components/ui/EmptyState.vue';
import { useConfirm } from '../composables/useConfirm.js';
import { exportLotesCSV } from '../lib/api.js';
import DsSpinner from '../design-system/components/Spinner.vue'
import NuevoLoteModal from '../components/lotes/NuevoLoteModal.vue'
import BloqueoProgreso from '../components/ui/BloqueoProgreso.vue'
import { useSeleccion } from '../composables/useSeleccion.js'
import { useEtiquetasQR } from '../composables/useEtiquetasQR.js'
import { useClubStore } from '../stores/club.js'
import { useToast } from '../composables/useToast.js'
import { LAYOUT_LOTE, dibujarEtiquetaLote } from '../lib/pdfEtiquetas.js'

const store = useLotesStore();
const salas = useSalasStore();
const auth  = useAuthStore();
const club  = useClubStore();
const toast = useToast();
const { confirm } = useConfirm();

function lotesEscapeHandler(e) {
  if (e.key === 'Escape') { showCreate.value = false; showEdit.value = false; }
}
onMounted(() => {
  store.fetch();
  if (!salas.items.length) salas.fetch();
  document.addEventListener('keydown', lotesEscapeHandler, true);
});
onUnmounted(() => document.removeEventListener('keydown', lotesEscapeHandler, true));

const canEdit = computed(() => ["admin","cultivador"].includes(auth.role));
const canExport = computed(() => ["admin","auditor","supervisor","cultivador"].includes(auth.role));

// ---------- Estado meta ----------
// Estados canónicos del lote (Lote::ESTADOS). 'cosecha' es el estado del lote cosechado
// (no 'cosechado', que es estado de PLANTA).
const ESTADOS = ["germinacion","esqueje","vegetativo","floracion","cosecha","en_manicura","curado","finalizado"];

const ESTADO_META = {
  germinacion:     { label:"Germinación",     dot:"#64748b", bg:"#f1f5f9", text:"#475569", bar:"#64748b", icon:"🌰" },
  esqueje:     { label:"Esqueje",     dot:"#0891b2", bg:"#e0f2fe", text:"#0369a1", bar:"#0891b2", icon:"🪴" },
  vegetativo:  { label:"Vegetativo",  dot:"#3F6452", bg:"#E8F0EB", text:"#2D4A3E", bar:"#5A8A72", icon:"🌱" },
  floracion:   { label:"Floración",   dot:"#D97706", bg:"#FEF3C7", text:"#92400e", bar:"#D97706", icon:"🌸" },
  cosecha:     { label:"Cosecha",     dot:"#5A8A72", bg:"#F4F8F5", text:"#1A3D2E", bar:"#3F6452", icon:"✂️" },
  en_manicura: { label:"En manicura", dot:"#7c3aed", bg:"#ede9fe", text:"#5b21b6", bar:"#7c3aed", icon:"✂️" },
  curado:      { label:"Curado",      dot:"#2563eb", bg:"#dbeafe", text:"#1e40af", bar:"#2563eb", icon:"🫙" },
  finalizado:  { label:"Finalizado",  dot:"#1A3D2E", bg:"#E8F0EB", text:"#0F2A1E", bar:"#1A3D2E", icon:"✅" },
};

// "Cosechado" es todo lo que ya salió de floración: cortado y en secado (cosecha),
// asignado a manicura (en_manicura), guardado en frasco (curado) y cerrado (finalizado).
const COSECHADOS = ["cosecha","en_manicura","curado","finalizado"];
// "En ciclo activo": el lote sigue activo hasta que pasa a curado (cuando ya se
// transformó en stock). Cosecha y en_manicura todavía cuentan como ciclo activo.
const EN_CICLO = ["germinacion","esqueje","vegetativo","floracion","cosecha","en_manicura"];

function em(e)           { return ESTADO_META[e] || { label: e||"—", dot:"#94a3b8", bg:"#f1f5f9", text:"#64748b", bar:"#94a3b8", icon:"•" }; }
function estadoLabel(e)  { return em(e).label; }
function growLabel(g)    { return { sustrato:"Sustrato", hidroponia:"Hidroponia" }[g] || g || "—"; }
function tipoLabel(t)    { return { sativa:"Sativa", indica:"Índica", hibrida:"Híbrida" }[t] || t; }
// L1: nivel de avance de la fase actual vs objetivo de la genética (verde/amarillo/rojo).
const FASE_OBJ = { vegetativo: "dias_vegetativo_objetivo", floracion: "dias_floracion_objetivo", cosecha: "dias_cosecha_objetivo" };
const FASE_LBL = { vegetativo: "vegetativo", floracion: "floración", cosecha: "cosecha" };
function objetivoFase(l) { return FASE_OBJ[l.estado] ? l[FASE_OBJ[l.estado]] : null; }
function diasNivel(l) {
  const obj = objetivoFase(l), d = l.dias_en_estado;
  if (!obj || obj <= 0 || d == null) return null;
  const r = d / obj;
  return r > 1.1 ? "rojo" : (r >= 0.9 ? "amarillo" : "verde");
}
function diasTitle(l) {
  const obj = objetivoFase(l);
  return obj ? `${l.dias_en_estado}/${obj} días en ${FASE_LBL[l.estado] || l.estado}` : "";
}
function lightLabel(l)   { return { led:"LED", hps:"HPS", cmh:"CMH", natural:"Natural", mixta:"Mixta" }[l] || l || "—"; }
function salaName(id)    { return salas.items.find(s => String(s.id) === String(id))?.nombre || `Sala #${id}`; }
// Post-cosecha el lote no vive en una sala: mostramos su etapa como "ubicación".
const SALA_POST = { cosecha: "Cosechado", en_manicura: "En manicura", curado: "Curado", finalizado: "Finalizado" };
function salaCelda(l)    { return l.sala_id ? salaName(l.sala_id) : (SALA_POST[l.estado] || "—"); }
function diasDesdeInicio(d) { return d ? Math.floor((Date.now() - new Date(d)) / 86_400_000) : null; }

// ---------- Stats ----------
const stats = computed(() => {
  const all = store.items;
  return {
    total:      all.length,
    enCiclo:    all.filter(l => EN_CICLO.includes(l.estado)).length,
    plantas:    all.reduce((a,l) => a + Number(l.plants_count||0), 0),
    cosechados: all.filter(l => COSECHADOS.includes(l.estado)).length,
  };
});

// ---------- Filtros ----------
const tab          = ref("activos"); // 'activos' | 'finalizados'
const q            = ref("");
const filterEstado = ref("");
const filterSala   = ref("");
const filterGrow   = ref("");
const sortBy       = ref("fecha_desc");
const page         = ref(1);
const perPage      = ref(10);

function setTab(t) {
  tab.value          = t;
  filterEstado.value = "";
  filterSala.value   = "";
  filterGrow.value   = "";
  q.value            = "";
  page.value         = 1;
}

const filtered = computed(() => {
  const query = q.value.trim().toLowerCase();
  return store.items.filter(l => {
    const esActivo     = l.estado !== "finalizado";
    const matchTab     = tab.value === "activos" ? esActivo : !esActivo;
    const matchText    = !query
      || (l.codigo||"").toLowerCase().includes(query)
      || (l.strain||"").toLowerCase().includes(query)
      || (l.genetica?.nombre||"").toLowerCase().includes(query); // el nombre real vive en genetica, no en strain (legacy)
    const matchEstado  = !filterEstado.value
      || (filterEstado.value === "cosechados" ? COSECHADOS.includes(l.estado)
          : filterEstado.value === "en_ciclo" ? EN_CICLO.includes(l.estado)
          : l.estado === filterEstado.value);
    const matchSala    = !filterSala.value   || String(l.sala_id) === filterSala.value;
    const matchGrow    = !filterGrow.value   || l.grow_type === filterGrow.value;
    return matchTab && matchText && matchEstado && matchSala && matchGrow;
  });
});

const sorted = computed(() => {
  const arr = [...filtered.value];
  arr.sort((a,b) => {
    const cA = (a.codigo||"").toLowerCase(), cB = (b.codigo||"").toLowerCase();
    const fA = new Date(a.start_date||a.created_at||0), fB = new Date(b.start_date||b.created_at||0);
    const pA = Number(a.plants_count??0), pB = Number(b.plants_count??0);
    switch (sortBy.value) {
      case "codigo_asc":   return cA > cB ? 1 : -1;
      case "fecha_asc":    return fA - fB;
      case "plantas_desc": return pB - pA;
      case "estado":       return ESTADOS.indexOf(a.estado) - ESTADOS.indexOf(b.estado);
      default:             return fB - fA;
    }
  });
  return arr;
});

const totalItems = computed(() => sorted.value.length);
const totalPages = computed(() => Math.max(1, Math.ceil(totalItems.value / perPage.value)));
const paginated  = computed(() => sorted.value.slice((page.value-1)*perPage.value, page.value*perPage.value));
watch([sorted, perPage], () => { if (page.value > totalPages.value) page.value = 1; });

// ---------- Etiquetas QR en tanda ----------
// Se etiqueta lo SELECCIONADO, y "seleccionar todo" toma todo lo filtrado (no la página): recién
// creaste 12 lotes, filtrás y los imprimís de una en vez de entrar a cada uno.
const sel = useSeleccion(computed(() => store.items), sorted);
const etiquetas = useEtiquetasQR();

async function configEtiquetas() {
  if (!club.data) { try { await club.fetch() } catch { /* el club es opcional en la etiqueta */ } }
  return {
    items:   sel.seleccionados.value.filter(l => l.codigo_qr),
    urlDe:   (l) => `${window.location.origin}/l/${l.codigo_qr}`,
    layout:  LAYOUT_LOTE,
    dibujar: dibujarEtiquetaLote,
    ordenPor: (l) => [l.codigo ?? ''],
    datosDe: (l, qr) => ({
      qrDataUrl: qr,
      codigo:    l.codigo,
      genetica:  l.genetica?.nombre || l.strain,
      estado:    estadoLabel(l.estado),
      inicio:    l.start_date,
      plantas:   l.plants_count ?? 0,
      clubName:  club.data?.name || '',
    }),
    archivo: `etiquetas-lotes-${sel.cantidad.value}`,
  };
}

// Los lotes sin codigo_qr no pueden etiquetarse (no hay a dónde apuntar el QR).
const seleccionSinQR = computed(() => sel.seleccionados.value.filter(l => !l.codigo_qr).length);

// Se pasa la FUNCIÓN (no el config resuelto) para que el composable abra la ventana de impresión
// antes de cualquier await; si no, el bloqueador de popups se la come.
async function imprimirEtiquetas() {
  const r = await etiquetas.imprimir(configEtiquetas);
  if (r.vacio) toast.warning('Ningún lote seleccionado tiene código QR');
  else if (!r.ok && r.error) toast.error('No se pudieron generar las etiquetas');
  else if (r.viaDescarga) toast.warning('El navegador bloqueó la ventana: se descargó el PDF');
  if (r.ok) sel.limpiar();   // el trabajo terminó: la selección (y su barra) no tienen más razón de estar
}
async function descargarEtiquetas() {
  const r = await etiquetas.descargar(configEtiquetas);
  if (r.vacio) toast.warning('Ningún lote seleccionado tiene código QR');
  else if (!r.ok && r.error) toast.error('No se pudieron generar las etiquetas');
  else if (r.ok) { toast.success('PDF descargado'); sel.limpiar(); }
}

// ---------- Form ----------
function emptyForm() {
  return {
    estado: "vegetativo", plants_count: 0,
    start_date: new Date().toISOString().slice(0,10),
    genetica_id: null, strain: "", grow_type: "sustrato", light_type: "", notes: "",
    sala_id: salas.items[0]?.id ?? "",
    tamanio_maceta: null,
  };
}

const showCreate = ref(false);

function openCreate() { showCreate.value = true; }
async function onLoteCreado() {
  await store.fetch();
  showCreate.value = false;
}

const showEdit   = ref(false);
const editForm   = ref({ id: null, ...emptyForm() });
const editErrors = ref({});

function validateForm(form) {
  const e = {};
  if (!ESTADOS.includes(form.estado))  e.estado = "Estado inválido";
  const n = Number(form.plants_count);
  if (!Number.isInteger(n) || n < 0 || n > 5000) e.plants_count = "Debe ser 0–5000";
  if (!form.sala_id) e.sala_id = "Seleccioná una sala";
  return e;
}

function startEdit(l) {
  editForm.value = {
    id: l.id, codigo: l.codigo||"", estado: l.estado||"vegetativo",
    plants_count: l.plants_count??0,
    start_date: l.start_date ? l.start_date.slice(0,10) : new Date().toISOString().slice(0,10),
    strain: l.strain||"", grow_type: l.grow_type||"sustrato", light_type: l.light_type||"",
    notes: l.notes||"", sala_id: l.sala_id||"",
    tamanio_maceta: l.tamanio_maceta ?? null,
  };
  editErrors.value = {};
  showEdit.value = true;
}

async function submitEdit() {
  const e = {};
  if (!ESTADOS.includes(editForm.value.estado)) e.estado = "Estado inválido";
  const n = Number(editForm.value.plants_count);
  if (!Number.isInteger(n) || n < 0 || n > 5000) e.plants_count = "Debe ser 0–5000";
  if (!editForm.value.sala_id) e.sala_id = "Seleccioná una sala";
  editErrors.value = e;
  if (Object.keys(e).length) return;
  try {
    const { id, codigo, sala_id, ...payload } = editForm.value;
    await store.update(id, payload, sala_id);
    showEdit.value = false;
  } catch {}
}

async function confirmDelete(l) {
  const ok = await confirm({
    title: `¿Eliminar "${l.codigo}"?`,
    message: 'Esta acción no se puede deshacer.',
    confirmText: 'Eliminar',
    variant: 'danger',
  });
  if (!ok) return;
  try { await store.remove(l.id, l.sala_id); } catch {}
}

const exporting = ref(false);
async function exportarCSV() {
  if (exporting.value) return;
  exporting.value = true;
  try {
    const params = {};
    if (filterEstado.value) params.estado = filterEstado.value;
    const { data } = await exportLotesCSV(params);
    const url  = URL.createObjectURL(new Blob([data], { type: 'text/csv;charset=utf-8;' }));
    const link = document.createElement('a');
    link.href  = url;
    link.setAttribute('download', `lotes_${new Date().toISOString().slice(0,10)}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(url);
  } catch {
    alert('Error al exportar');
  } finally {
    exporting.value = false;
  }
}
</script>

<template>
  <div class="lv">

    <!-- Header -->
    <div class="lv__header">
      <div>
        <h1 class="lv__title">Lotes de cultivo</h1>
        <p class="lv__sub">Trazabilidad de cultivos</p>
      </div>
      <div class="lv__header-actions">
        <button v-if="canExport" class="lv__btn-export" :disabled="exporting" @click="exportarCSV">
          <i class="bi bi-download"></i>
          {{ exporting ? 'Exportando…' : 'CSV' }}
        </button>
        <button v-if="canEdit" class="lv__btn-primary" @click="openCreate">
          <i class="bi bi-plus-lg"></i> Nuevo lote
        </button>
      </div>
    </div>

    <!-- Tabs -->
    <div class="lv__tabs">
      <button class="lv__tab" :class="{ 'lv__tab--active': tab === 'activos' }" @click="setTab('activos')">
        🌱 Lotes activos
        <span class="lv__tab-count">{{ store.items.filter(l => l.estado !== 'finalizado').length }}</span>
      </button>
      <button class="lv__tab" :class="{ 'lv__tab--active': tab === 'finalizados' }" @click="setTab('finalizados')">
        ✅ Finalizados
        <span class="lv__tab-count">{{ store.items.filter(l => l.estado === 'finalizado').length }}</span>
      </button>
    </div>

    <!-- KPIs -->
    <div class="lv__kpis" v-if="tab === 'activos'">
      <button class="lv__kpi" :class="{ 'lv__kpi--active': filterEstado === '' }" @click="filterEstado = ''">
        <div class="lv__kpi-val">{{ stats.total }}</div>
        <div class="lv__kpi-lbl">Total</div>
      </button>
      <button class="lv__kpi lv__kpi--green" :class="{ 'lv__kpi--active': filterEstado === 'en_ciclo' }" @click="filterEstado = filterEstado === 'en_ciclo' ? '' : 'en_ciclo'">
        <div class="lv__kpi-val">{{ stats.enCiclo }}</div>
        <div class="lv__kpi-lbl">En cultivo activo</div>
      </button>
      <button class="lv__kpi lv__kpi--neutral" :class="{ 'lv__kpi--active-neutral': filterEstado === '' }" @click="filterEstado = ''">
        <div class="lv__kpi-val">{{ stats.plantas }}</div>
        <div class="lv__kpi-lbl">Plantas totales</div>
      </button>
      <button class="lv__kpi lv__kpi--amber" :class="{ 'lv__kpi--active': filterEstado === 'cosechados' }" @click="filterEstado = filterEstado === 'cosechados' ? '' : 'cosechados'">
        <div class="lv__kpi-val">{{ stats.cosechados }}</div>
        <div class="lv__kpi-lbl">Cosechados</div>
      </button>
    </div>

    <!-- Toolbar -->
    <div class="lv__toolbar">
      <div class="lv__search-wrap">
        <i class="bi bi-search lv__search-icon"></i>
        <input
          v-model.trim="q"
          type="search"
          class="lv__search"
          placeholder="Código, variedad…"
        />
        <span v-if="q" class="lv__search-count">{{ filtered.length }}</span>
      </div>
      <select v-if="tab === 'activos'" class="lv__select" v-model="filterEstado">
        <option value="">Todos los estados</option>
        <option v-for="e in ESTADOS.filter(e => e !== 'finalizado')" :key="e" :value="e">{{ estadoLabel(e) }}</option>
      </select>
      <select class="lv__select" v-model="filterSala">
        <option value="">Todas las salas</option>
        <option v-for="s in salas.items" :key="s.id" :value="String(s.id)">{{ s.nombre }}</option>
      </select>
      <select class="lv__select lv__select--sm" v-model="filterGrow">
        <option value="">Todos los sistemas</option>
        <option value="sustrato">Sustrato</option>
        <option value="hidroponia">Hidroponia</option>
      </select>
      <select class="lv__select lv__select--sm" v-model="sortBy">
        <option value="fecha_desc">Más recientes</option>
        <option value="fecha_asc">Más antiguos</option>
        <option value="estado">Por estado</option>
        <option value="codigo_asc">Código A→Z</option>
        <option value="plantas_desc">Más plantas</option>
      </select>
    </div>

    <!-- Loading -->
    <div v-if="store.loading" class="lv__loading">
      <DsSpinner />
    </div>
    <div v-else-if="store.error" class="lv__alert">{{ store.error }}</div>
    <EmptyState v-else-if="!store.items.length" icon="🌱" title="No hay lotes todavía" message="Creá el primer lote para comenzar la trazabilidad" />
    <EmptyState v-else-if="!paginated.length" icon="🔍" title="Sin resultados" message="Probá ajustando los filtros" />

    <!-- Tabla -->
    <div v-else class="lv__table-wrap">
      <table class="lv-table">
        <thead>
          <tr>
            <th class="lv-th--cb">
              <input
                type="checkbox" class="lv-cb"
                :checked="sel.todoFiltradoElegido.value"
                :indeterminate.prop="sel.algoFiltradoElegido.value"
                :disabled="etiquetas.ocupado.value"
                :title="sel.todoFiltradoElegido.value ? 'Deseleccionar' : `Seleccionar los ${sorted.length} lotes filtrados`"
                @change="sel.alternarTodoFiltrado()"
              />
            </th>
            <th>Estado</th>
            <th class="lv-th--sort" @click="sortBy = sortBy === 'codigo_asc' ? 'fecha_desc' : 'codigo_asc'">
              Código <span class="lv-sort-icon">{{ sortBy === 'codigo_asc' ? '↑' : '↕' }}</span>
            </th>
            <th>Genética</th>
            <th>Sala</th>
            <th class="lv-th--sort" @click="sortBy = sortBy === 'plantas_desc' ? 'fecha_desc' : 'plantas_desc'">
              Plantas <span class="lv-sort-icon">{{ sortBy === 'plantas_desc' ? '↓' : '↕' }}</span>
            </th>
            <th>Maceta</th>
            <th class="lv-th--sort" @click="sortBy = sortBy === 'fecha_asc' ? 'fecha_desc' : 'fecha_asc'">
              Días <span class="lv-sort-icon">{{ sortBy.startsWith('fecha') ? (sortBy === 'fecha_asc' ? '↑' : '↓') : '↕' }}</span>
            </th>
            <th v-if="canEdit"></th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="l in paginated"
            :key="l.id"
            class="lv-table__row"
            @click="$router.push({ name: 'lote-detail', params: { id: l.id } })"
          >
            <td class="lv-td--cb" @click.stop>
              <input
                type="checkbox" class="lv-cb"
                :checked="sel.esta(l.id)"
                :disabled="etiquetas.ocupado.value"
                :aria-label="`Seleccionar ${l.codigo}`"
                @change="sel.alternar(l.id)"
              />
            </td>
            <td data-label="Estado">
              <span class="lv-badge" :style="{ background: em(l.estado).bg, color: em(l.estado).text }">
                {{ em(l.estado).icon }} {{ estadoLabel(l.estado) }}
              </span>
            </td>
            <td data-label="Código">
              <span class="lv-codigo">{{ l.codigo }}</span>
            </td>
            <td data-label="Genética">
              <span v-if="l.genetica?.nombre" class="lv-genetica">{{ l.genetica.nombre }}</span>
              <span v-else-if="l.strain" class="lv-strain">{{ l.strain }}</span>
              <span v-else class="lv-empty">—</span>
              <span v-if="l.genetica?.tipo" class="lv-tipo" :class="`lv-tipo--${l.genetica.tipo}`">{{ tipoLabel(l.genetica.tipo) }}</span>
            </td>
            <td data-label="Sala">
              <span class="lv-sala">{{ salaCelda(l) }}</span>
            </td>
            <td data-label="Plantas">
              <span class="lv-num">{{ l.plants_count ?? 0 }}</span>
            </td>
            <td data-label="Maceta">
              <span v-if="l.tamanio_maceta" class="lv-num">{{ l.tamanio_maceta }}L</span>
              <span v-else class="lv-empty">—</span>
            </td>
            <td data-label="Días">
              <span v-if="diasDesdeInicio(l.start_date) !== null" class="lv-num">
                <span v-if="diasNivel(l)" class="lv-dias-dot" :class="`lv-dias-dot--${diasNivel(l)}`" :title="diasTitle(l)"></span>
                {{ diasDesdeInicio(l.start_date) }}d
              </span>
              <span v-else class="lv-empty">—</span>
            </td>
            <td v-if="canEdit" @click.stop>
              <div class="lv-actions">
                <button class="lv-action-btn" title="Editar" @click="startEdit(l)">
                  <i class="bi bi-pencil"></i>
                </button>
                <button class="lv-action-btn lv-action-btn--danger" title="Eliminar" @click="confirmDelete(l)">
                  <i class="bi bi-trash"></i>
                </button>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
      <div class="lv__table-footer">
        <div class="lv__pagination" v-if="totalPages > 1">
          <button class="lv__page-btn" :disabled="page <= 1" @click="page--">«</button>
          <span class="lv__page-info">{{ page }} / {{ totalPages }}</span>
          <button class="lv__page-btn" :disabled="page >= totalPages" @click="page++">»</button>
        </div>
        <div class="lv__count">{{ filtered.length }} lotes</div>
      </div>
    </div>

    <!-- MODAL Crear (componente compartido con SalaDetail) -->
    <NuevoLoteModal :show="showCreate" :salas="salas.items" @close="showCreate = false" @created="onLoteCreado" />

    <!-- MODAL Editar -->
    <Teleport to="body">
      <div v-if="showEdit" class="lm-overlay">
        <div class="lm-modal">
          <div class="lm-modal__header">
            <div>
              <h2 class="lm-modal__title">Editar lote</h2>
              <p class="lm-modal__sub lm-modal__sub--code">{{ editForm.codigo }}</p>
            </div>
            <button class="lm-modal__close" @click="showEdit = false"><i class="bi bi-x-lg"></i></button>
          </div>
          <div class="lm-modal__body">
            <div v-if="store.updateError" class="lm-alert">{{ store.updateError }}</div>
            <div class="lm-grid">
              <div class="lm-field">
                <label class="lm-label">Código</label>
                <input class="lm-input" :value="editForm.codigo" disabled style="opacity:.6;cursor:not-allowed;background:#f8fafc;font-family:monospace" />
              </div>
              <div class="lm-field">
                <label class="lm-label">Sala</label>
                <select class="lm-input" v-model="editForm.sala_id">
                  <option v-for="s in salas.items" :key="s.id" :value="s.id">{{ s.nombre }}</option>
                </select>
              </div>
              <div class="lm-field">
                <label class="lm-label">Estado</label>
                <select class="lm-input" v-model="editForm.estado">
                  <option v-for="e in ESTADOS" :key="e" :value="e">{{ estadoLabel(e) }}</option>
                </select>
              </div>
              <div class="lm-field">
                <label class="lm-label">Cantidad de plantas</label>
                <input type="number" min="0" max="5000" class="lm-input" :class="{ 'lm-input--err': editErrors.plants_count }"
                       v-model.number="editForm.plants_count" />
                <span v-if="editErrors.plants_count" class="lm-err">{{ editErrors.plants_count }}</span>
              </div>
              <div class="lm-field">
                <label class="lm-label">Fecha de inicio</label>
                <AppDatePicker v-model="editForm.start_date" />
              </div>
              <div class="lm-field">
                <label class="lm-label">Variedad / Strain</label>
                <input class="lm-input" v-model.trim="editForm.strain" />
              </div>
              <div class="lm-field">
                <label class="lm-label">Sistema de cultivo</label>
                <select class="lm-input" v-model="editForm.grow_type">
                  <option value="sustrato">Sustrato</option>
                  <option value="hidroponia">Hidroponia</option>
                </select>
              </div>
              <div class="lm-field">
                <label class="lm-label">Tipo de luz</label>
                <select class="lm-input" v-model="editForm.light_type">
                  <option value="">Sin especificar</option>
                  <option value="led">LED</option>
                  <option value="hps">HPS</option>
                  <option value="cmh">CMH</option>
                  <option value="natural">Natural</option>
                  <option value="mixta">Mixta</option>
                </select>
              </div>
              <div class="lm-field">
                <label class="lm-label">Maceta <span class="lm-unit">litros</span></label>
                <input type="number" step="0.5" min="0" class="lm-input" v-model.number="editForm.tamanio_maceta" placeholder="Ej: 11" />
              </div>
              <div class="lm-field lm-field--full">
                <label class="lm-label">Notas</label>
                <textarea class="lm-input lm-textarea" rows="2" v-model.trim="editForm.notes"></textarea>
              </div>
            </div>
          </div>
          <div class="lm-modal__footer">
            <button class="lm-btn-ghost" @click="showEdit = false">Cancelar</button>
            <button class="lm-btn-primary" :disabled="store.updating" @click="submitEdit">
              <DsSpinner v-if="store.updating" :size="14" />
              Guardar cambios
            </button>
          </div>
        </div>
      </div>
    </Teleport>

    <!-- Barra de acción de la selección -->
    <Teleport to="body">
      <div v-if="sel.cantidad.value" class="lv-selbar">
        <span class="lv-selbar__txt">
          {{ sel.cantidad.value }} {{ sel.cantidad.value === 1 ? 'lote' : 'lotes' }}
          <small v-if="sel.fueraDelFiltro.value">({{ sel.fueraDelFiltro.value }} fuera del filtro actual)</small>
        </span>
        <span v-if="seleccionSinQR" class="lv-selbar__warn" :title="`${seleccionSinQR} sin código QR: no se pueden etiquetar`">
          <i class="bi bi-exclamation-triangle-fill"></i> {{ seleccionSinQR }} sin QR
        </span>
        <button class="lv-selbar__ghost" :disabled="etiquetas.ocupado.value" @click="sel.limpiar()">Limpiar</button>
        <button class="lv-selbar__btn" :disabled="etiquetas.ocupado.value" @click="descargarEtiquetas">
          <i class="bi bi-download"></i> Descargar
        </button>
        <button class="lv-selbar__btn lv-selbar__btn--main" :disabled="etiquetas.ocupado.value" @click="imprimirEtiquetas">
          <i class="bi bi-printer"></i> Imprimir etiquetas
        </button>
      </div>
    </Teleport>

    <!-- Mientras genera no se puede tocar nada (ni cambiar el filtro a mitad de camino) -->
    <BloqueoProgreso
      :visible="etiquetas.ocupado.value"
      :titulo="etiquetas.titulo.value"
      :hechas="etiquetas.hechas.value"
      :total="etiquetas.total.value"
    />

  </div>
</template>

<style scoped>
/* Selección para etiquetas en tanda */
.lv-th--cb, .lv-td--cb { width: 34px; padding-right: 0; }
.lv-cb { width: 15px; height: 15px; accent-color: #1b5e20; cursor: pointer; margin: 0; }
.lv-cb:disabled { cursor: default; opacity: .5; }

.lv-selbar {
  position: fixed; bottom: 1.25rem; left: 50%; transform: translateX(-50%); z-index: 1035;
  display: flex; align-items: center; gap: .75rem; flex-wrap: wrap; justify-content: center;
  max-width: calc(100vw - 2rem);
  background: #0f172a; color: #fff; padding: .6rem .75rem .6rem 1.1rem;
  border-radius: 12px; box-shadow: 0 8px 28px rgba(0,0,0,.25); font-size: .82rem;
}
.lv-selbar__txt { font-weight: 600; white-space: nowrap; }
.lv-selbar__txt small { font-weight: 400; color: #94a3b8; }
.lv-selbar__warn { color: #fbbf24; font-weight: 600; white-space: nowrap; }
.lv-selbar__ghost { background: none; border: none; color: #94a3b8; font-size: .8rem; font-weight: 600; cursor: pointer; }
.lv-selbar__ghost:hover:not(:disabled) { color: #fff; }
.lv-selbar__btn {
  display: inline-flex; align-items: center; gap: .35rem;
  background: rgba(255,255,255,.1); color: #fff; border: none;
  padding: .45rem .85rem; border-radius: 9px; font-size: .8rem; font-weight: 600; cursor: pointer;
}
.lv-selbar__btn:hover:not(:disabled) { background: rgba(255,255,255,.2); }
.lv-selbar__btn--main { background: #22c55e; color: #052e16; }
.lv-selbar__btn--main:hover:not(:disabled) { background: #16a34a; color: #fff; }
.lv-selbar__btn:disabled, .lv-selbar__ghost:disabled { opacity: .5; cursor: default; }

/* ── Layout ──────────────────────────────────────────── */
.lv { padding: 2rem 1.5rem; max-width: 1100px; margin: 0 auto; }
@media (max-width: 768px) { .lv { padding: 1.25rem 1rem; overflow-x: hidden; } }

/* ── Header ──────────────────────────────────────────── */
.lv__header { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; margin-bottom: 1.75rem; flex-wrap: wrap; }
.lv__title  { font-size: 2rem; font-weight: 800; color: #0f172a; margin: 0 0 .2rem; letter-spacing: -.04em; line-height: 1; }
.lv__sub    { font-size: .83rem; color: #94a3b8; margin: 0; }
.lv__header-actions { display: flex; gap: .5rem; align-items: center; }

.lv__btn-primary {
  display: inline-flex; align-items: center; gap: .4rem;
  background: #1b5e20; color: #fff; border: none;
  padding: .65rem 1.25rem; border-radius: 9px;
  font-size: .875rem; font-weight: 700; cursor: pointer;
  transition: background .15s, transform .1s; white-space: nowrap;
}
.lv__btn-primary:hover { background: #144a18; transform: translateY(-1px); }

.lv__btn-export {
  display: inline-flex; align-items: center; gap: .35rem;
  padding: .6rem .9rem; background: transparent; color: #475569;
  border: 1.5px solid #e2e8f0; border-radius: 9px;
  font-size: .84rem; font-weight: 600; cursor: pointer;
  transition: all .15s; white-space: nowrap;
}
.lv__btn-export:hover:not(:disabled) { border-color: #1b5e20; color: #1b5e20; background: #f0fdf4; }
.lv__btn-export:disabled { opacity: .5; cursor: default; }

/* ── KPIs ─────────────────────────────────────────────── */
.lv__tabs { display: flex; gap: .5rem; margin-bottom: 1.25rem; border-bottom: 2px solid #e8f0e9; }
.lv__tab { background: none; border: none; border-bottom: 2px solid transparent; margin-bottom: -2px; padding: .55rem 1rem; font-size: .875rem; font-weight: 600; color: #60725d; cursor: pointer; display: flex; align-items: center; gap: .4rem; transition: all .15s; }
.lv__tab:hover { color: #1b5e20; }
.lv__tab--active { color: #1b5e20; border-bottom-color: #1b5e20; }
.lv__tab-count { background: #e8f0e9; color: #1b5e20; font-size: .7rem; font-weight: 700; padding: .1em .45em; border-radius: 999px; }
.lv__tab--active .lv__tab-count { background: #1b5e20; color: #fff; }
.lv__kpis { display: grid; grid-template-columns: repeat(4, 1fr); gap: .75rem; margin-bottom: 1.5rem; }
@media (max-width: 700px) { .lv__kpis { grid-template-columns: repeat(2, 1fr); } }

.lv__kpi {
  background: #fff; border: 1.5px solid #e2e8f0; border-radius: 12px;
  padding: 1rem; text-align: left; cursor: pointer; transition: all .15s;
}
.lv__kpi:hover { border-color: #94a3b8; }
.lv__kpi--active { border-color: #1b5e20 !important; box-shadow: 0 0 0 1px #1b5e20; }
.lv__kpi--green .lv__kpi-val { color: #1b5e20; }
.lv__kpi--green.lv__kpi--active { border-color: #1b5e20 !important; box-shadow: 0 0 0 1px #1b5e20; }
.lv__kpi--amber .lv__kpi-val { color: #b45309; }
.lv__kpi--amber.lv__kpi--active { border-color: #b45309 !important; box-shadow: 0 0 0 1px #b45309; }
.lv__kpi--neutral .lv__kpi-val { color: #64748b; }

.lv__kpi-val { font-size: 1.8rem; font-weight: 800; color: #0f172a; line-height: 1; letter-spacing: -.04em; margin-bottom: .2rem; }
.lv__kpi-lbl { font-size: .72rem; font-weight: 600; text-transform: uppercase; letter-spacing: .04em; color: #94a3b8; }

/* ── Toolbar ──────────────────────────────────────────── */
.lv__toolbar {
  display: flex; gap: .5rem; align-items: center; margin-bottom: 1.5rem; flex-wrap: wrap;
}
.lv__search-wrap { flex: 1; min-width: 180px; position: relative; display: flex; align-items: center; }
.lv__search-icon { position: absolute; left: .875rem; color: #94a3b8; font-size: .875rem; pointer-events: none; }
.lv__search {
  width: 100%; background: #fff; border: 1.5px solid #e2e8f0; border-radius: 10px;
  padding: .65rem .875rem .65rem 2.4rem; font-size: .9rem; color: #0f172a;
  transition: border .15s, box-shadow .15s; box-sizing: border-box;
}
.lv__search:focus { outline: none; border-color: #1b5e20; box-shadow: 0 0 0 3px rgba(27,94,32,.1); }
.lv__search-count { position: absolute; right: .875rem; font-size: .72rem; font-weight: 600; color: #94a3b8; }

.lv__select {
  background: #fff; border: 1.5px solid #e2e8f0; border-radius: 10px;
  padding: .62rem .85rem; font-size: .875rem; color: #0f172a; cursor: pointer;
  transition: border .15s; min-width: 140px;
}
.lv__select--sm { min-width: 120px; }
.lv__select:focus { outline: none; border-color: #1b5e20; }

@media (max-width: 640px) {
  .lv__toolbar { gap: .4rem; }
  .lv__search-wrap { flex: 1 1 100%; }
  .lv__select { flex: 1 1 calc(50% - .2rem); min-width: 0; font-size: .82rem; padding: .58rem .7rem; }
  .lv__select--sm { flex: 1 1 calc(50% - .2rem); }
}

/* ── Loading / Error ─────────────────────────────────── */
.lv__loading { display: flex; align-items: center; justify-content: center; min-height: calc(100vh - 56px); }
.lv__alert   { background: #fef2f2; border: 1px solid #fecaca; color: #dc2626; padding: .875rem 1rem; border-radius: 10px; font-size: .875rem; margin-bottom: 1rem; }

/* ── Tabla ───────────────────────────────────────────── */
.lv__table-wrap { background: #fff; border: 1px solid #e5e7eb; border-radius: 12px; overflow: hidden; margin-bottom: 0; }
.lv-table { width: 100%; border-collapse: collapse; font-size: .875rem; }
.lv-table thead th { padding: 10px 12px; text-align: left; font-weight: 600; color: #6b7280; border-bottom: 2px solid #e5e7eb; white-space: nowrap; background: #fafafa; }
.lv-th--sort { cursor: pointer; user-select: none; }
.lv-th--sort:hover { color: #1b5e20; }
.lv-sort-icon { font-size: .75rem; color: #cbd5e1; margin-left: .2rem; }
.lv-table tbody tr { border-bottom: 1px solid #f3f4f6; transition: background .1s; cursor: pointer; }
.lv-table tbody tr:last-child { border-bottom: none; }
.lv-table tbody tr:hover { background: #f8fafc; }
.lv-table td { padding: 10px 12px; vertical-align: middle; }

.lv-badge { display: inline-flex; align-items: center; gap: .25rem; padding: 3px 8px; border-radius: 5px; font-size: .75rem; font-weight: 700; white-space: nowrap; }
.lv-codigo { font-weight: 700; color: #0f172a; font-family: monospace; font-size: .85rem; }
.lv-genetica { font-weight: 600; color: #3F6452; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.lv-strain { font-style: italic; color: #64748b; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.lv-tipo { display: inline-block; margin-left: .4rem; font-size: .62rem; font-weight: 700; text-transform: uppercase; letter-spacing: .04em; padding: .1em .45em; border-radius: 999px; vertical-align: middle; }
.lv-tipo--sativa { background: #fef3c7; color: #b45309; }
.lv-tipo--indica { background: #ede9fe; color: #6d28d9; }
.lv-tipo--hibrida { background: #dcfce7; color: #15803d; }
.lv-dias-dot { display: inline-block; width: 7px; height: 7px; border-radius: 50%; margin-right: 5px; vertical-align: middle; }
.lv-dias-dot--verde { background: #16a34a; }
.lv-dias-dot--amarillo { background: #f59e0b; }
.lv-dias-dot--rojo { background: #dc2626; }
.lv-sala { color: #64748b; font-size: .82rem; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.lv-num { font-weight: 600; color: #374151; }
.lv-empty { color: #cbd5e1; }

.lv-actions { display: flex; align-items: center; gap: .25rem; opacity: 0; transition: opacity .15s; }
.lv-table tbody tr:hover .lv-actions { opacity: 1; }
.lv-action-btn { background: none; border: none; cursor: pointer; padding: 5px 7px; border-radius: 6px; color: #6b7280; font-size: .875rem; transition: all .15s; }
.lv-action-btn:hover { background: #f1f5f9; color: #0f172a; }
.lv-action-btn--danger:hover { background: #fef2f2; color: #dc2626; }

.lv__table-footer { display: flex; align-items: center; justify-content: space-between; padding: .6rem 1rem; border-top: 1px solid #f1f5f9; }
.lv__pagination { display: flex; align-items: center; gap: .5rem; }
.lv__page-btn { background: #fff; border: 1.5px solid #e2e8f0; border-radius: 7px; padding: .3rem .65rem; font-size: .82rem; color: #374151; cursor: pointer; transition: all .15s; }
.lv__page-btn:hover:not(:disabled) { border-color: #1b5e20; color: #1b5e20; }
.lv__page-btn:disabled { opacity: .4; cursor: not-allowed; }
.lv__page-info { font-size: .8rem; color: #64748b; font-weight: 600; }
.lv__count { font-size: .75rem; color: #94a3b8; }

/* ── Mobile: tabla → cards ───────────────────────────── */
@media (max-width: 640px) {
  .lv__table-wrap { background: transparent; border: none; border-radius: 0; overflow: visible; }
  .lv-table { display: block; }
  .lv-table thead { display: none; }
  .lv-table tbody { display: flex; flex-direction: column; gap: .6rem; }

  .lv-table tbody tr {
    display: block;
    background: #fff;
    border: 1px solid #e5e7eb !important;
    border-bottom: 1px solid #e5e7eb !important;
    border-radius: 12px;
    padding: .875rem 1rem .875rem 1rem;
    position: relative;
    transition: box-shadow .15s;
  }
  .lv-table tbody tr:hover { background: #fff; box-shadow: 0 2px 12px rgba(0,0,0,.07); }

  /* Todas las celdas: flex con label */
  .lv-table td {
    display: flex;
    align-items: center;
    gap: .4rem;
    padding: .18rem 0;
    border: none;
    font-size: .84rem;
    min-width: 0;
    width: 100%;
  }
  .lv-table td::before {
    content: attr(data-label);
    font-size: .65rem;
    font-weight: 700;
    color: #94a3b8;
    text-transform: uppercase;
    letter-spacing: .04em;
    min-width: 68px;
    flex-shrink: 0;
  }

  /* Estado: sin label, badge prominente */
  .lv-table td[data-label="Estado"] {
    padding-bottom: .45rem;
    margin-bottom: .1rem;
    border-bottom: 1px solid #f1f5f9;
  }
  .lv-table td[data-label="Estado"]::before { content: none; }

  /* Código: sin label, grande */
  .lv-table td[data-label="Código"]::before { content: none; }
  .lv-codigo { font-size: .95rem; }

  /* Acciones: posición absoluta top-right */
  .lv-table td:last-child {
    position: absolute;
    top: .75rem;
    right: .75rem;
    padding: 0;
    display: flex;
    align-items: center;
  }
  .lv-table td:last-child::before { content: none; }
  .lv-actions { opacity: 1; }

  /* Padding-right para que el contenido no choque con acciones */
  .lv-table td[data-label="Estado"],
  .lv-table td[data-label="Código"] { padding-right: 5rem; }

  .lv__table-footer { padding: .6rem .25rem; }
}

/* ── Modal ───────────────────────────────────────────── */
.lm-overlay {
  position: fixed; inset: 0; background: rgba(0,0,0,.45);
  display: flex; align-items: center; justify-content: center;
  z-index: 1060; padding: 1rem; backdrop-filter: blur(3px);
}
.lm-modal {
  background: #fff; border-radius: 18px; width: 100%; max-width: 640px;
  max-height: 92vh; overflow-y: auto; display: flex; flex-direction: column;
  box-shadow: 0 24px 64px rgba(0,0,0,.15);
}
.lm-modal__header {
  display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem;
  padding: 1.5rem 1.5rem 1.1rem; border-bottom: 1px solid #f1f5f9;
  position: sticky; top: 0; background: #fff; z-index: 1;
}
.lm-modal__title { font-size: 1.2rem; font-weight: 800; color: #0f172a; margin: 0 0 .2rem; letter-spacing: -.02em; }
.lm-modal__sub   { font-size: .8rem; color: #64748b; margin: 0; }
.lm-modal__sub--code { font-family: monospace; color: #3F6452; font-weight: 700; }
.lm-modal__close {
  background: #f1f5f9; border: none; width: 32px; height: 32px;
  border-radius: 8px; cursor: pointer; display: flex; align-items: center; justify-content: center;
  color: #64748b; flex-shrink: 0; transition: all .15s;
}
.lm-modal__close:hover { background: #e2e8f0; color: #0f172a; }
.lm-modal__body   { padding: 1.4rem 1.5rem; flex: 1; }
.lm-modal__footer {
  display: flex; justify-content: flex-end; gap: .75rem;
  padding: 1rem 1.5rem; border-top: 1px solid #f1f5f9;
  position: sticky; bottom: 0; background: #fff;
}

.lm-alert { background: #fef2f2; border: 1px solid #fecaca; color: #dc2626; padding: .75rem 1rem; border-radius: 9px; font-size: .85rem; margin-bottom: 1.25rem; }

.lm-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; }
@media (max-width: 520px) { .lm-grid { grid-template-columns: 1fr; } }

.lm-field        { display: flex; flex-direction: column; gap: .35rem; }
.lm-field--full  { grid-column: 1 / -1; }
.lm-label        { font-size: .78rem; font-weight: 700; color: #374151; text-transform: uppercase; letter-spacing: .04em; }
.lm-req          { color: #dc2626; }
.lm-unit         { font-size: .68rem; font-weight: 400; color: #94a3b8; text-transform: none; letter-spacing: 0; margin-left: .2rem; }
.lm-input {
  background: #f8fafc; border: 1.5px solid #e2e8f0; border-radius: 9px;
  padding: .65rem .9rem; font-size: .875rem; color: #0f172a;
  width: 100%; box-sizing: border-box; transition: border .15s, box-shadow .15s;
}
.lm-input:focus     { outline: none; border-color: #1b5e20; box-shadow: 0 0 0 3px rgba(27,94,32,.1); background: #fff; }
.lm-input--err      { border-color: #dc2626; }
.lm-textarea        { resize: vertical; min-height: 68px; }
.lm-err             { font-size: .72rem; color: #dc2626; font-weight: 600; }

.lm-btn-primary {
  display: inline-flex; align-items: center; gap: .4rem;
  background: #1b5e20; color: #fff; border: none;
  padding: .65rem 1.4rem; border-radius: 9px; font-size: .875rem; font-weight: 700;
  cursor: pointer; transition: background .15s;
}
.lm-btn-primary:hover:not(:disabled) { background: #144a18; }
.lm-btn-primary:disabled { opacity: .6; cursor: not-allowed; }

.lm-btn-ghost {
  background: transparent; color: #64748b; border: 1.5px solid #e2e8f0;
  padding: .65rem 1.2rem; border-radius: 9px; font-size: .875rem; font-weight: 600;
  cursor: pointer; transition: all .15s;
}
.lm-btn-ghost:hover { background: #f8fafc; color: #0f172a; }

</style>
