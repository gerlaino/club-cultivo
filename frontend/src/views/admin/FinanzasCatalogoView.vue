<script setup>
// Gestión del catálogo de Finanzas: categorías contables + unidades de negocio.
// Ambas editables por el club. Las de sistema (es_sistema) no se borran; sí se
// renombran, recolorean, reasignan de unidad o se desactivan.
import { ref, computed, onMounted } from 'vue'
import { useCatalogoFinanzasStore } from '../../stores/catalogoFinanzas.js'
import { useConfirm } from '../../composables/useConfirm.js'
import { useToast } from '../../composables/useToast.js'

const store   = useCatalogoFinanzasStore()
const { confirm } = useConfirm()
const toast   = useToast()

const TIPOS_UNIDAD = [
  { value: 'cultivo',        label: 'Cultivo' },
  { value: 'dispensario',    label: 'Dispensario' },
  { value: 'bar',            label: 'Bar' },
  { value: 'social',         label: 'Social' },
  { value: 'administracion', label: 'Administración' },
  { value: 'general',        label: 'General' },
]
const COLORES = ['#2f6b3d', '#40915a', '#b7791f', '#8a4b2f', '#b23b2e', '#3b82f6', '#6b7280', '#7c3aed']

onMounted(() => store.fetchAll())

// ── Categorías ────────────────────────────────────────────────
const catForm = ref(null) // null = cerrado; {} = nueva; {id,...} = edición
function nuevaCategoria() {
  catForm.value = { nombre: '', tipo: 'egreso', unidad_negocio_id: null, color: COLORES[0], activa: true }
}
function editarCategoria(c) {
  catForm.value = { id: c.id, nombre: c.nombre, tipo: c.tipo, unidad_negocio_id: c.unidad_negocio_id, color: c.color || COLORES[0], activa: c.activa, es_sistema: c.es_sistema }
}
async function guardarCategoria() {
  const f = catForm.value
  if (!f.nombre?.trim()) { toast.warning('Poné un nombre'); return }
  const payload = { nombre: f.nombre.trim(), tipo: f.tipo, unidad_negocio_id: f.unidad_negocio_id, color: f.color, activa: f.activa }
  try {
    if (f.id) { await store.actualizarCategoria(f.id, payload); toast.success('Categoría actualizada') }
    else      { await store.crearCategoria(payload);            toast.success('Categoría creada') }
    catForm.value = null
  } catch { toast.error(store.saveError || 'No se pudo guardar') }
}
async function borrarCategoria(c) {
  if (!(await confirm({ title: 'Eliminar categoría', message: `¿Eliminar "${c.nombre}"?`, variant: 'danger' }))) return
  try { await store.eliminarCategoria(c.id); toast.success('Categoría eliminada') }
  catch (e) { toast.error(e?.response?.data?.error || 'No se pudo eliminar') }
}

const categoriasPorTipo = computed(() => ({
  ingreso: store.categorias.filter(c => c.tipo === 'ingreso'),
  egreso:  store.categorias.filter(c => c.tipo === 'egreso'),
}))

// ── Unidades ──────────────────────────────────────────────────
const uniForm = ref(null)
function nuevaUnidad()  { uniForm.value = { nombre: '', tipo: 'general', color: COLORES[0], activa: true } }
function editarUnidad(u) { uniForm.value = { id: u.id, nombre: u.nombre, tipo: u.tipo, color: u.color || COLORES[0], activa: u.activa, es_sistema: u.es_sistema } }
async function guardarUnidad() {
  const f = uniForm.value
  if (!f.nombre?.trim()) { toast.warning('Poné un nombre'); return }
  const payload = { nombre: f.nombre.trim(), tipo: f.tipo, color: f.color, activa: f.activa }
  try {
    if (f.id) { await store.actualizarUnidad(f.id, payload); toast.success('Unidad actualizada') }
    else      { await store.crearUnidad(payload);            toast.success('Unidad creada') }
    uniForm.value = null
  } catch { toast.error(store.saveError || 'No se pudo guardar') }
}
async function borrarUnidad(u) {
  if (!(await confirm({ title: 'Eliminar unidad', message: `¿Eliminar "${u.nombre}"?`, variant: 'danger' }))) return
  try { await store.eliminarUnidad(u.id); toast.success('Unidad eliminada') }
  catch (e) { toast.error(e?.response?.data?.error || 'No se pudo eliminar') }
}

function nombreUnidad(id) { return store.unidadPorId(id)?.nombre || '—' }
</script>

<template>
  <div class="cat-view">
    <header class="cat-head">
      <div>
        <h1>Catálogo de Finanzas</h1>
        <p>Categorías y unidades de negocio propias del club. La base para el P&amp;L por unidad.</p>
      </div>
    </header>

    <div v-if="store.loading" class="cat-loading">Cargando catálogo…</div>

    <div v-else class="cat-grid">
      <!-- UNIDADES DE NEGOCIO -->
      <section class="cat-card">
        <div class="cat-card__head">
          <h2>Unidades de negocio</h2>
          <button class="btn btn--primary" @click="nuevaUnidad">+ Unidad</button>
        </div>
        <p class="cat-card__hint">Ejes analíticos: cultivo, dispensario, bar, administración… El resultado se desglosa por unidad.</p>

        <form v-if="uniForm" class="cat-form" @submit.prevent="guardarUnidad">
          <input v-model.trim="uniForm.nombre" class="inp" placeholder="Nombre (ej: Bar)" maxlength="40" />
          <select v-model="uniForm.tipo" class="inp" :disabled="uniForm.es_sistema">
            <option v-for="t in TIPOS_UNIDAD" :key="t.value" :value="t.value">{{ t.label }}</option>
          </select>
          <div class="swatches">
            <button v-for="c in COLORES" :key="c" type="button" class="sw" :class="{ 'sw--on': uniForm.color === c }" :style="{ background: c }" @click="uniForm.color = c" :aria-label="c"></button>
          </div>
          <label class="chk"><input type="checkbox" v-model="uniForm.activa" /> Activa</label>
          <div class="cat-form__actions">
            <button type="button" class="btn" @click="uniForm = null">Cancelar</button>
            <button type="submit" class="btn btn--primary" :disabled="store.saving">Guardar</button>
          </div>
        </form>

        <ul class="cat-list">
          <li v-for="u in store.unidades" :key="u.id" class="cat-item" :class="{ 'cat-item--off': !u.activa }">
            <span class="dot" :style="{ background: u.color || 'var(--c-ink-300)' }"></span>
            <span class="cat-item__name">{{ u.nombre }}<small>{{ u.tipo }}</small></span>
            <span v-if="u.es_sistema" class="tag">sistema</span>
            <span v-if="!u.activa" class="tag tag--off">inactiva</span>
            <div class="cat-item__actions">
              <button class="lnk" @click="editarUnidad(u)">Editar</button>
              <button v-if="!u.es_sistema" class="lnk lnk--danger" @click="borrarUnidad(u)">Borrar</button>
            </div>
          </li>
        </ul>
      </section>

      <!-- CATEGORÍAS -->
      <section class="cat-card">
        <div class="cat-card__head">
          <h2>Categorías</h2>
          <button class="btn btn--primary" @click="nuevaCategoria">+ Categoría</button>
        </div>
        <p class="cat-card__hint">Qué es cada movimiento. Asigná cada categoría a una unidad para que aporte a su resultado.</p>

        <form v-if="catForm" class="cat-form" @submit.prevent="guardarCategoria">
          <input v-model.trim="catForm.nombre" class="inp" placeholder="Nombre (ej: Mercadería bar)" maxlength="40" />
          <select v-model="catForm.tipo" class="inp">
            <option value="egreso">Egreso</option>
            <option value="ingreso">Ingreso</option>
          </select>
          <select v-model="catForm.unidad_negocio_id" class="inp">
            <option :value="null">— Sin unidad —</option>
            <option v-for="u in store.unidadesActivas" :key="u.id" :value="u.id">{{ u.nombre }}</option>
          </select>
          <div class="swatches">
            <button v-for="c in COLORES" :key="c" type="button" class="sw" :class="{ 'sw--on': catForm.color === c }" :style="{ background: c }" @click="catForm.color = c" :aria-label="c"></button>
          </div>
          <label class="chk"><input type="checkbox" v-model="catForm.activa" /> Activa</label>
          <div class="cat-form__actions">
            <button type="button" class="btn" @click="catForm = null">Cancelar</button>
            <button type="submit" class="btn btn--primary" :disabled="store.saving">Guardar</button>
          </div>
        </form>

        <div v-for="tipo in ['ingreso','egreso']" :key="tipo" class="cat-group">
          <h3 class="cat-group__title" :class="tipo === 'ingreso' ? 'is-in' : 'is-out'">
            {{ tipo === 'ingreso' ? 'Ingresos' : 'Egresos' }}
          </h3>
          <ul class="cat-list">
            <li v-for="c in categoriasPorTipo[tipo]" :key="c.id" class="cat-item" :class="{ 'cat-item--off': !c.activa }">
              <span class="dot" :style="{ background: c.color || 'var(--c-ink-300)' }"></span>
              <span class="cat-item__name">{{ c.nombre }}<small>{{ nombreUnidad(c.unidad_negocio_id) }}</small></span>
              <span v-if="c.es_sistema" class="tag">sistema</span>
              <span v-if="!c.activa" class="tag tag--off">inactiva</span>
              <div class="cat-item__actions">
                <button class="lnk" @click="editarCategoria(c)">Editar</button>
                <button v-if="!c.es_sistema" class="lnk lnk--danger" @click="borrarCategoria(c)">Borrar</button>
              </div>
            </li>
            <li v-if="!categoriasPorTipo[tipo].length" class="cat-empty">Sin categorías de este tipo.</li>
          </ul>
        </div>
      </section>
    </div>
  </div>
</template>

<style scoped>
.cat-view { padding: var(--sp-6, 24px); max-width: 1080px; margin: 0 auto; }
.cat-head h1 { font-size: var(--fs-24, 24px); font-weight: 700; color: var(--c-ink-900); margin: 0; }
.cat-head p  { color: var(--c-ink-500); margin: 4px 0 0; font-size: var(--fs-14, 14px); }
.cat-loading { color: var(--c-ink-500); padding: var(--sp-8, 32px); text-align: center; }

.cat-grid { display: grid; grid-template-columns: 1fr 1.3fr; gap: var(--sp-4, 16px); margin-top: var(--sp-6, 24px); align-items: start; }
@media (max-width: 860px) { .cat-grid { grid-template-columns: 1fr; } }

.cat-card { background: var(--c-paper, #fff); border: 1px solid var(--c-ink-100); border-radius: var(--r-lg, 14px); padding: var(--sp-5, 20px); box-shadow: var(--sh-1); }
.cat-card__head { display: flex; align-items: center; justify-content: space-between; gap: var(--sp-3, 12px); }
.cat-card__head h2 { font-size: var(--fs-18, 18px); font-weight: 650; color: var(--c-ink-900); margin: 0; }
.cat-card__hint { color: var(--c-ink-500); font-size: var(--fs-13, 13px); margin: 6px 0 var(--sp-4, 16px); }

.cat-form { display: flex; flex-direction: column; gap: var(--sp-2, 8px); background: var(--c-ink-50, #f6f7f5); border: 1px solid var(--c-ink-100); border-radius: var(--r-md, 10px); padding: var(--sp-3, 12px); margin-bottom: var(--sp-4, 16px); }
.inp { width: 100%; padding: 8px 10px; border: 1px solid var(--c-ink-200); border-radius: var(--r-sm, 8px); font-size: var(--fs-14, 14px); background: var(--c-paper, #fff); color: var(--c-ink-900); }
.cat-form__actions { display: flex; gap: var(--sp-2, 8px); justify-content: flex-end; margin-top: 4px; }

.swatches { display: flex; gap: 6px; flex-wrap: wrap; }
.sw { width: 24px; height: 24px; border-radius: 6px; border: 2px solid transparent; cursor: pointer; }
.sw--on { border-color: var(--c-ink-900); box-shadow: 0 0 0 2px var(--c-paper, #fff) inset; }
.chk { display: flex; align-items: center; gap: 6px; font-size: var(--fs-13, 13px); color: var(--c-ink-600); }

.cat-group { margin-top: var(--sp-4, 16px); }
.cat-group__title { font-size: var(--fs-12, 12px); text-transform: uppercase; letter-spacing: .06em; font-weight: 700; margin: 0 0 6px; }
.cat-group__title.is-in  { color: var(--c-leaf-700, #2f6b3d); }
.cat-group__title.is-out { color: var(--c-rust-600, #b23b2e); }

.cat-list { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; }
.cat-item { display: flex; align-items: center; gap: var(--sp-3, 12px); padding: 10px 4px; border-bottom: 1px solid var(--c-ink-100); }
.cat-item:last-child { border-bottom: none; }
.cat-item--off { opacity: .55; }
.dot { width: 11px; height: 11px; border-radius: 4px; flex-shrink: 0; }
.cat-item__name { font-size: var(--fs-14, 14px); font-weight: 550; color: var(--c-ink-900); display: flex; flex-direction: column; }
.cat-item__name small { color: var(--c-ink-400); font-weight: 400; font-size: var(--fs-12, 12px); }
.tag { font-size: 10px; text-transform: uppercase; letter-spacing: .05em; font-weight: 700; padding: 2px 7px; border-radius: 999px; background: var(--c-ink-100); color: var(--c-ink-500); }
.tag--off { background: var(--c-amber-100, #f6ecd8); color: var(--c-amber-500, #b7791f); }
.cat-item__actions { margin-left: auto; display: flex; gap: var(--sp-2, 8px); }
.cat-empty { color: var(--c-ink-400); font-size: var(--fs-13, 13px); padding: 8px 4px; }

.btn { border: 1px solid var(--c-ink-200); background: var(--c-paper, #fff); color: var(--c-ink-800); border-radius: var(--r-sm, 8px); padding: 7px 13px; font-size: var(--fs-13, 13px); font-weight: 600; cursor: pointer; }
.btn--primary { background: var(--c-leaf-700, #2f6b3d); border-color: var(--c-leaf-700, #2f6b3d); color: #fff; }
.btn:disabled { opacity: .5; cursor: default; }
.lnk { background: none; border: none; color: var(--c-ink-500); font-size: var(--fs-13, 13px); cursor: pointer; padding: 2px 4px; }
.lnk:hover { color: var(--c-ink-900); }
.lnk--danger:hover { color: var(--c-rust-600, #b23b2e); }
</style>
