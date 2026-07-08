<script setup>
// Gestión del catálogo de Finanzas: unidades de negocio + categorías jerárquicas (madre →
// subcategoría) con comportamiento y unidad. Estilo alineado a ContabilidadView.
import { ref, computed, onMounted } from 'vue'
import { useCatalogoFinanzasStore } from '../../stores/catalogoFinanzas.js'
import { useConfirm } from '../../composables/useConfirm.js'
import { useToast } from '../../composables/useToast.js'

const store = useCatalogoFinanzasStore()
const { confirm } = useConfirm()
const toast = useToast()

const TIPOS_UNIDAD = [
  { value: 'cultivo', label: 'Cultivo' }, { value: 'dispensario', label: 'Dispensario' },
  { value: 'bar', label: 'Bar' }, { value: 'social', label: 'Social' },
  { value: 'administracion', label: 'Administración' }, { value: 'general', label: 'General' },
]
const COMPORTAMIENTOS = [
  { value: 'general',    label: 'General (gasto común)' },
  { value: 'insumo',     label: 'Insumo → va al depósito' },
  { value: 'mercaderia', label: 'Mercadería → va al salón' },
]
const COMP_LABEL = { insumo: 'depósito', mercaderia: 'salón' }
const COLORES = ['#1b5e20', '#15803d', '#b45309', '#8a4b2f', '#dc2626', '#3b82f6', '#64748b', '#7c3aed']

onMounted(() => store.fetchAll())

// ── Categorías ────────────────────────────────────────────────
const catForm = ref(null) // { id?, parent_id, nombre, tipo, comportamiento, unidad_negocio_id, color }
function nuevaMadre() { catForm.value = { parent_id: null, nombre: '', tipo: 'egreso', comportamiento: 'general', unidad_negocio_id: null, color: COLORES[0] } }
function nuevaSub(madre) { catForm.value = { parent_id: madre.id, nombre: '', tipo: madre.tipo, madreNombre: madre.nombre } }
function editar(c, madre = null) {
  catForm.value = {
    id: c.id, parent_id: c.parent_id, nombre: c.nombre, tipo: c.tipo,
    comportamiento: c.comportamiento, unidad_negocio_id: c.unidad_negocio_id, color: c.color || COLORES[0],
    es_sistema: c.es_sistema, madreNombre: madre?.nombre,
  }
}
const esMadreForm = computed(() => catForm.value && !catForm.value.parent_id)

async function guardarCat() {
  const f = catForm.value
  if (!f.nombre?.trim()) { toast.warning('Poné un nombre'); return }
  const payload = { nombre: f.nombre.trim(), tipo: f.tipo, parent_id: f.parent_id }
  if (esMadreForm.value) { payload.comportamiento = f.comportamiento; payload.unidad_negocio_id = f.unidad_negocio_id; payload.color = f.color }
  try {
    if (f.id) await store.actualizarCategoria(f.id, payload)
    else      await store.crearCategoria(payload)
    toast.success('Categoría guardada'); catForm.value = null
  } catch { toast.error(store.saveError) }
}
async function borrarCat(c) {
  if (!(await confirm({ title: 'Eliminar categoría', message: `¿Eliminar "${c.nombre}"?`, variant: 'danger' }))) return
  try { await store.eliminarCategoria(c.id); toast.success('Eliminada') }
  catch (e) { toast.error(e?.response?.data?.error || 'No se pudo eliminar') }
}

const porTipo = computed(() => ({
  egreso:  store.categorias.filter(c => c.tipo === 'egreso'),
  ingreso: store.categorias.filter(c => c.tipo === 'ingreso'),
}))

// ── Unidades ──────────────────────────────────────────────────
const uniForm = ref(null)
function nuevaUnidad()  { uniForm.value = { nombre: '', tipo: 'general', color: COLORES[0], activa: true } }
function editarUnidad(u) { uniForm.value = { id: u.id, nombre: u.nombre, tipo: u.tipo, color: u.color || COLORES[0], activa: u.activa, es_sistema: u.es_sistema } }
async function guardarUnidad() {
  const f = uniForm.value
  if (!f.nombre?.trim()) { toast.warning('Poné un nombre'); return }
  try {
    if (f.id) await store.actualizarUnidad(f.id, { nombre: f.nombre.trim(), tipo: f.tipo, color: f.color, activa: f.activa })
    else      await store.crearUnidad({ nombre: f.nombre.trim(), tipo: f.tipo, color: f.color, activa: f.activa })
    toast.success('Unidad guardada'); uniForm.value = null
  } catch { toast.error(store.saveError) }
}
async function borrarUnidad(u) {
  if (!(await confirm({ title: 'Eliminar unidad', message: `¿Eliminar "${u.nombre}"?`, variant: 'danger' }))) return
  try { await store.eliminarUnidad(u.id); toast.success('Eliminada') }
  catch (e) { toast.error(e?.response?.data?.error || 'No se pudo eliminar') }
}
</script>

<template>
  <div class="cat-view">
    <div v-if="store.loading" class="cat-loading">Cargando catálogo…</div>

    <div v-else class="cat-grid">
      <!-- UNIDADES -->
      <section class="cat-card">
        <div class="cat-card__head">
          <h2>Unidades de negocio</h2>
          <button class="btn btn--primary" @click="nuevaUnidad">+ Unidad</button>
        </div>
        <p class="cat-card__hint">Las áreas del club (Cultivo, Bar…). El resultado se desglosa por unidad.</p>

        <form v-if="uniForm" class="cat-form" @submit.prevent="guardarUnidad">
          <input v-model.trim="uniForm.nombre" class="inp" placeholder="Nombre" maxlength="40" />
          <select v-model="uniForm.tipo" class="inp" :disabled="uniForm.es_sistema"><option v-for="t in TIPOS_UNIDAD" :key="t.value" :value="t.value">{{ t.label }}</option></select>
          <div class="cat-form__actions"><button type="button" class="btn" @click="uniForm = null">Cancelar</button><button type="submit" class="btn btn--primary" :disabled="store.saving">Guardar</button></div>
        </form>

        <ul class="cat-list">
          <li v-for="u in store.unidades" :key="u.id" class="cat-item" :class="{ 'cat-item--off': !u.activa }">
            <span class="dot" :style="{ background: u.color || '#cbd5e1' }"></span>
            <span class="cat-item__name">{{ u.nombre }}<small>{{ u.tipo }}</small></span>
            <span v-if="u.es_sistema" class="tag">sistema</span>
            <div class="cat-item__actions"><button class="lnk" @click="editarUnidad(u)">Editar</button><button v-if="!u.es_sistema" class="lnk lnk--danger" @click="borrarUnidad(u)">Borrar</button></div>
          </li>
        </ul>
      </section>

      <!-- CATEGORÍAS -->
      <section class="cat-card">
        <div class="cat-card__head">
          <h2>Categorías</h2>
          <button class="btn btn--primary" @click="nuevaMadre">+ Categoría</button>
        </div>
        <p class="cat-card__hint">Madre → subcategoría. La madre define área y comportamiento; las hijas lo heredan.</p>

        <!-- Form categoría (madre o subcategoría) -->
        <form v-if="catForm" class="cat-form" @submit.prevent="guardarCat">
          <div v-if="catForm.parent_id" class="cat-form__sub">Subcategoría de <b>{{ catForm.madreNombre }}</b></div>
          <input v-model.trim="catForm.nombre" class="inp" placeholder="Nombre (ej: Insumos, o Fertilizante)" maxlength="50" />
          <template v-if="esMadreForm">
            <select v-model="catForm.tipo" class="inp"><option value="egreso">Egreso</option><option value="ingreso">Ingreso</option></select>
            <select v-model="catForm.comportamiento" class="inp"><option v-for="c in COMPORTAMIENTOS" :key="c.value" :value="c.value">{{ c.label }}</option></select>
            <select v-model="catForm.unidad_negocio_id" class="inp">
              <option :value="null">— Unidad (opcional) —</option>
              <option v-for="u in store.unidadesActivas" :key="u.id" :value="u.id">{{ u.nombre }}</option>
            </select>
            <div class="swatches"><button v-for="c in COLORES" :key="c" type="button" class="sw" :class="{ 'sw--on': catForm.color === c }" :style="{ background: c }" @click="catForm.color = c"></button></div>
          </template>
          <div class="cat-form__actions"><button type="button" class="btn" @click="catForm = null">Cancelar</button><button type="submit" class="btn btn--primary" :disabled="store.saving">Guardar</button></div>
        </form>

        <div v-for="tipo in ['egreso','ingreso']" :key="tipo" class="cat-group">
          <h3 class="cat-group__title" :class="tipo === 'ingreso' ? 'is-in' : 'is-out'">{{ tipo === 'ingreso' ? 'Ingresos' : 'Egresos' }}</h3>
          <div v-for="m in porTipo[tipo]" :key="m.id" class="cat-madre">
            <div class="cat-item cat-item--madre">
              <span class="dot" :style="{ background: m.color || '#cbd5e1' }"></span>
              <span class="cat-item__name">
                {{ m.nombre }}
                <small>{{ m.unidad_negocio?.nombre || 'sin unidad' }}<template v-if="COMP_LABEL[m.comportamiento]"> · → {{ COMP_LABEL[m.comportamiento] }}</template></small>
              </span>
              <span v-if="m.es_sistema" class="tag">sistema</span>
              <div class="cat-item__actions">
                <button class="lnk" @click="nuevaSub(m)">+ Sub</button>
                <button class="lnk" @click="editar(m)">Editar</button>
                <button v-if="!m.es_sistema" class="lnk lnk--danger" @click="borrarCat(m)">Borrar</button>
              </div>
            </div>
            <ul v-if="m.subcategorias?.length" class="cat-subs">
              <li v-for="s in m.subcategorias" :key="s.id" class="cat-item cat-item--sub">
                <span class="cat-sub-dash"></span>
                <span class="cat-item__name">{{ s.nombre }}</span>
                <div class="cat-item__actions"><button class="lnk" @click="editar(s, m)">Editar</button><button v-if="!s.es_sistema" class="lnk lnk--danger" @click="borrarCat(s)">Borrar</button></div>
              </li>
            </ul>
          </div>
          <div v-if="!porTipo[tipo].length" class="cat-empty">Sin categorías de este tipo.</div>
        </div>
      </section>
    </div>
  </div>
</template>

<style scoped>
.cat-view { padding: 2rem 1.75rem 3rem; max-width: 1080px; margin: 0 auto; color: #0f172a; }
.cat-loading { color: #64748b; padding: 2rem; text-align: center; }
.cat-grid { display: grid; grid-template-columns: 1fr 1.4fr; gap: 1rem; align-items: start; }
@media (max-width: 860px) { .cat-grid { grid-template-columns: 1fr; } }

.cat-card { background: #fff; border: 1px solid #e2e8f0; border-radius: 14px; padding: 1.25rem; }
.cat-card__head { display: flex; align-items: center; justify-content: space-between; gap: .75rem; }
.cat-card__head h2 { font-size: 1rem; font-weight: 700; color: #0f172a; margin: 0; }
.cat-card__hint { color: #64748b; font-size: .8rem; margin: .35rem 0 1rem; }

.cat-form { display: flex; flex-direction: column; gap: .5rem; background: #f8fafc; border: 1px solid #f1f5f9; border-radius: 10px; padding: .75rem; margin-bottom: 1rem; }
.cat-form__sub { font-size: .78rem; color: #64748b; }
.cat-form__actions { display: flex; gap: .5rem; justify-content: flex-end; margin-top: .25rem; }
.inp { width: 100%; padding: .5rem .65rem; border: 1.5px solid #e2e8f0; border-radius: 8px; font-size: .84rem; background: #fff; color: #0f172a; }
.inp:focus { border-color: #1b5e20; outline: none; }
.swatches { display: flex; gap: 6px; flex-wrap: wrap; }
.sw { width: 24px; height: 24px; border-radius: 6px; border: 2px solid transparent; cursor: pointer; }
.sw--on { border-color: #0f172a; box-shadow: 0 0 0 2px #fff inset; }

.cat-group { margin-top: 1rem; }
.cat-group__title { font-size: .7rem; text-transform: uppercase; letter-spacing: .06em; font-weight: 800; margin: 0 0 .35rem; }
.cat-group__title.is-in { color: #15803d; } .cat-group__title.is-out { color: #b45309; }

.cat-list { list-style: none; margin: 0; padding: 0; }
.cat-madre { border-bottom: 1px solid #f1f5f9; padding: .15rem 0; }
.cat-madre:last-child { border-bottom: none; }
.cat-item { display: flex; align-items: center; gap: .7rem; padding: .55rem .15rem; }
.cat-item--off { opacity: .55; }
.cat-item--madre { font-weight: 600; }
.dot { width: 11px; height: 11px; border-radius: 4px; flex-shrink: 0; }
.cat-item__name { font-size: .86rem; color: #0f172a; display: flex; flex-direction: column; }
.cat-item__name small { color: #94a3b8; font-weight: 400; font-size: .72rem; }
.tag { font-size: 10px; text-transform: uppercase; letter-spacing: .05em; font-weight: 700; padding: 2px 7px; border-radius: 999px; background: #f1f5f9; color: #64748b; }
.cat-item__actions { margin-left: auto; display: flex; gap: .5rem; }
.cat-subs { list-style: none; margin: 0 0 .3rem; padding: 0 0 0 .5rem; }
.cat-item--sub { padding: .4rem .15rem; }
.cat-sub-dash { width: 14px; height: 1px; background: #cbd5e1; flex-shrink: 0; }
.cat-item--sub .cat-item__name { font-weight: 500; font-size: .84rem; }
.cat-empty { color: #94a3b8; font-size: .8rem; padding: .5rem 0; }

.btn { border: 1.5px solid #e2e8f0; background: #fff; color: #334155; border-radius: 9px; padding: .5rem .85rem; font-size: .82rem; font-weight: 600; cursor: pointer; }
.btn:hover { border-color: #cbd5e1; }
.btn--primary { background: #1b5e20; border-color: #1b5e20; color: #fff; }
.btn--primary:hover { background: #144a18; }
.btn:disabled { opacity: .5; cursor: default; }
.lnk { background: none; border: none; color: #64748b; font-size: .8rem; font-weight: 600; cursor: pointer; padding: .1rem .3rem; }
.lnk:hover { color: #0f172a; }
.lnk--danger:hover { color: #dc2626; }
</style>
