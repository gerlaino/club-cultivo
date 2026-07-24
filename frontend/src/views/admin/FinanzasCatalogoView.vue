<script setup>
// Catálogo de Finanzas: unidades de negocio + categorías jerárquicas (madre → subcategoría)
// dentro de un área. Explicado y con acciones claras: editar, desactivar/reactivar
// (para las del sistema, que no se borran) y borrar (para las propias sin movimientos).
import { ref, computed, onMounted } from 'vue'
import { useCatalogoFinanzasStore } from '../../stores/catalogoFinanzas.js'
import { useConfirm } from '../../composables/useConfirm.js'
import { useToast } from '../../composables/useToast.js'

const store = useCatalogoFinanzasStore()
const { confirm } = useConfirm()
const toast = useToast()

// Tipos sugeridos para el área (el club puede escribir uno propio). Es solo una etiqueta.
const TIPOS_SUGERIDOS = ['cultivo', 'dispensario', 'bar', 'social', 'administracion', 'general']
const COLORES = ['#1b5e20', '#15803d', '#b45309', '#8a4b2f', '#dc2626', '#3b82f6', '#64748b', '#7c3aed']

onMounted(() => store.fetchAll())

// ── Categorías ────────────────────────────────────────────────
const catForm = ref(null)
function nuevaMadre() { catForm.value = { parent_id: null, nombre: '', tipo: 'egreso', unidad_negocio_id: null, color: COLORES[0] } }
function nuevaSub(madre) { catForm.value = { parent_id: madre.id, nombre: '', tipo: madre.tipo, madreNombre: madre.nombre } }
function editar(c, madre = null) {
  catForm.value = {
    id: c.id, parent_id: c.parent_id, nombre: c.nombre, tipo: c.tipo,
    unidad_negocio_id: c.unidad_negocio_id, color: c.color || COLORES[0],
    es_sistema: c.es_sistema, madreNombre: madre?.nombre,
  }
}
const esMadreForm = computed(() => catForm.value && !catForm.value.parent_id)

async function guardarCat() {
  const f = catForm.value
  if (!f.nombre?.trim()) { toast.warning('Poné un nombre'); return }
  const payload = { nombre: f.nombre.trim(), tipo: f.tipo, parent_id: f.parent_id }
  if (esMadreForm.value) { payload.unidad_negocio_id = f.unidad_negocio_id; payload.color = f.color }
  try {
    if (f.id) await store.actualizarCategoria(f.id, payload)
    else      await store.crearCategoria(payload)
    toast.success('Categoría guardada'); catForm.value = null
  } catch { toast.error(store.saveError) }
}

// Desactivar/reactivar: la vía para "sacar" una categoría del sistema (no se borra, se oculta
// al cargar movimientos, conservando el histórico).
async function toggleActiva(c) {
  try {
    await store.actualizarCategoria(c.id, { activa: !c.activa })
    toast.success(c.activa ? 'Categoría desactivada' : 'Categoría reactivada')
  } catch { toast.error(store.saveError || 'No se pudo actualizar') }
}

// Borrar: solo categorías propias sin subcategorías ni movimientos. El backend valida y, si no
// se puede, devuelve un mensaje claro (ej: "tiene movimientos, desactivala").
async function borrarCat(c) {
  const ok = await confirm({
    title: 'Eliminar categoría',
    message: `¿Eliminar "${c.nombre}"? Solo se puede si no tiene subcategorías ni movimientos. Si los tiene, desactivala.`,
    variant: 'danger', confirmText: 'Eliminar',
  })
  if (!ok) return
  try { await store.eliminarCategoria(c.id); toast.success('Categoría eliminada') }
  catch (e) { toast.error(e?.response?.data?.error || 'No se pudo eliminar') }
}

const porTipo = computed(() => ({
  egreso:  store.categorias.filter(c => c.tipo === 'egreso'),
  ingreso: store.categorias.filter(c => c.tipo === 'ingreso'),
}))

// ── Unidades (áreas) ──────────────────────────────────────────
const uniForm = ref(null)
function nuevaUnidad()  { uniForm.value = { nombre: '', tipo: '', color: COLORES[0], activa: true, crear_deposito: true } }
function editarUnidad(u) { uniForm.value = { id: u.id, nombre: u.nombre, tipo: u.tipo, color: u.color || COLORES[0], activa: u.activa, es_sistema: u.es_sistema } }
async function guardarUnidad() {
  const f = uniForm.value
  if (!f.nombre?.trim()) { toast.warning('Poné un nombre'); return }
  const tipo = (f.tipo?.trim() || 'general')
  try {
    if (f.id) {
      await store.actualizarUnidad(f.id, { nombre: f.nombre.trim(), tipo, color: f.color, activa: f.activa })
      toast.success('Área guardada')
    } else {
      await store.crearUnidad({ nombre: f.nombre.trim(), tipo, color: f.color, activa: f.activa }, { crear_deposito: !!f.crear_deposito })
      toast.success(f.crear_deposito ? 'Área y depósito creados' : 'Área creada')
    }
    uniForm.value = null
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

    <template v-else>
      <!-- Explicación -->
      <div class="cat-intro">
        <h2 class="cat-intro__title">Cómo funciona el catálogo</h2>
        <p class="cat-intro__lead">
          Las <b>áreas</b> son las líneas de negocio del club (Cultivo, Bar, Dispensario…) y cada una
          tiene su propio resultado. Las <b>categorías</b> clasifican cada movimiento del libro dentro
          de un área, en <b>categoría madre → subcategoría</b> (ej: <i>Fertilizantes → Base A</i>).
        </p>
        <p class="cat-intro__note">
          <i class="bi bi-info-circle"></i>
          Un área puede tener uno o varios <b>depósitos</b>. Al cargar un movimiento con una categoría
          de un área con depósito, la app te pregunta si esa compra es mercadería y en qué depósito
          guardarla — así sabés dónde vas a verla después.
        </p>
        <p class="cat-intro__note">
          <i class="bi bi-info-circle"></i>
          Las categorías y áreas del <b>sistema</b> no se borran (para no romper el histórico): se
          <b>desactivan</b>. Las que creás vos se pueden <b>borrar</b> si no tienen movimientos.
        </p>
      </div>

      <div class="cat-grid">
        <!-- CATEGORÍAS -->
        <section class="cat-card cat-card--main">
          <div class="cat-card__head">
            <h2>Categorías</h2>
            <button class="btn btn--primary" @click="nuevaMadre">+ Categoría madre</button>
          </div>

          <!-- Form categoría (madre o subcategoría) -->
          <form v-if="catForm" class="cat-form" @submit.prevent="guardarCat">
            <div class="cat-form__title">
              {{ catForm.id ? 'Editar' : 'Nueva' }}
              {{ catForm.parent_id ? 'subcategoría' : 'categoría madre' }}
              <span v-if="catForm.parent_id" class="cat-form__sub">de <b>{{ catForm.madreNombre }}</b></span>
            </div>
            <label class="fld">Nombre
              <input v-model.trim="catForm.nombre" class="inp" :placeholder="catForm.parent_id ? 'Ej: Fertilizante' : 'Ej: Insumos'" maxlength="50" />
            </label>
            <template v-if="esMadreForm">
              <div class="fld-row">
                <label class="fld">Tipo
                  <select v-model="catForm.tipo" class="inp"><option value="egreso">Egreso (gasto)</option><option value="ingreso">Ingreso</option></select>
                </label>
                <label class="fld">Área
                  <select v-model="catForm.unidad_negocio_id" class="inp">
                    <option :value="null">— Sin área —</option>
                    <option v-for="u in store.unidadesActivas" :key="u.id" :value="u.id">{{ u.nombre }}</option>
                  </select>
                </label>
              </div>
              <div class="fld">
                <span>Color</span>
                <div class="swatches"><button v-for="c in COLORES" :key="c" type="button" class="sw" :class="{ 'sw--on': catForm.color === c }" :style="{ background: c }" @click="catForm.color = c"></button></div>
              </div>
            </template>
            <div class="cat-form__actions"><button type="button" class="btn" @click="catForm = null">Cancelar</button><button type="submit" class="btn btn--primary" :disabled="store.saving">Guardar</button></div>
          </form>

          <div v-for="tipo in ['egreso','ingreso']" :key="tipo" class="cat-group">
            <h3 class="cat-group__title" :class="tipo === 'ingreso' ? 'is-in' : 'is-out'">
              {{ tipo === 'ingreso' ? 'Ingresos' : 'Egresos' }}
            </h3>
            <div v-for="m in porTipo[tipo]" :key="m.id" class="cat-madre" :class="{ 'is-off': !m.activa }">
              <div class="cat-item cat-item--madre">
                <span class="dot" :style="{ background: m.color || '#cbd5e1' }"></span>
                <span class="cat-item__name">
                  <span class="cat-item__label">{{ m.nombre }}<span v-if="!m.activa" class="off-tag">oculta</span></span>
                  <small>{{ m.unidad_negocio?.nombre || 'sin área' }}</small>
                </span>
                <span v-if="m.es_sistema" class="tag" title="Categoría del sistema: no se borra, se desactiva">sistema</span>
                <div class="cat-item__actions">
                  <button class="lnk" @click="nuevaSub(m)"><i class="bi bi-plus-lg"></i> Sub</button>
                  <button class="lnk" @click="editar(m)">Editar</button>
                  <button class="lnk" :class="{ 'lnk--warn': m.activa }" @click="toggleActiva(m)">{{ m.activa ? 'Desactivar' : 'Reactivar' }}</button>
                  <button v-if="!m.es_sistema" class="lnk lnk--danger" @click="borrarCat(m)">Borrar</button>
                </div>
              </div>
              <ul v-if="m.subcategorias?.length" class="cat-subs">
                <li v-for="s in m.subcategorias" :key="s.id" class="cat-item cat-item--sub" :class="{ 'is-off': !s.activa }">
                  <span class="cat-sub-dash"></span>
                  <span class="cat-item__name">
                    <span class="cat-item__label">{{ s.nombre }}<span v-if="!s.activa" class="off-tag">oculta</span></span>
                  </span>
                  <span v-if="s.es_sistema" class="tag tag--sm">sistema</span>
                  <div class="cat-item__actions">
                    <button class="lnk" @click="editar(s, m)">Editar</button>
                    <button class="lnk" :class="{ 'lnk--warn': s.activa }" @click="toggleActiva(s)">{{ s.activa ? 'Desactivar' : 'Reactivar' }}</button>
                    <button v-if="!s.es_sistema" class="lnk lnk--danger" @click="borrarCat(s)">Borrar</button>
                  </div>
                </li>
              </ul>
            </div>
            <div v-if="!porTipo[tipo].length" class="cat-empty">Sin categorías de este tipo.</div>
          </div>
        </section>

        <!-- UNIDADES -->
        <section class="cat-card">
          <div class="cat-card__head">
            <h2>Áreas del club</h2>
            <button class="btn btn--primary" @click="nuevaUnidad">+ Área</button>
          </div>
          <p class="cat-card__hint">Unidades de negocio (Cultivo, Bar, Dispensario…). El resultado del club se desglosa por área.</p>

          <form v-if="uniForm" class="cat-form" @submit.prevent="guardarUnidad">
            <div class="cat-form__title">{{ uniForm.id ? 'Editar' : 'Nueva' }} área</div>
            <label class="fld">Nombre<input v-model.trim="uniForm.nombre" class="inp" placeholder="Ej: Cultivo" maxlength="40" /></label>
            <!-- Tipo del área: solo una etiqueta agrupadora. Libre (o elegir uno sugerido). Las de
                 sistema no lo cambian (viene con la app). -->
            <template v-if="uniForm.es_sistema">
              <div class="fld">Tipo<span class="uni-tipo-ro">{{ uniForm.tipo }} <small>(del sistema, no editable)</small></span></div>
            </template>
            <label v-else class="fld">Tipo <small class="fld-hint">— etiqueta libre; podés elegir uno o escribir el tuyo</small>
              <input v-model.trim="uniForm.tipo" class="inp" list="uni-tipos" placeholder="Ej: eventos, cultivo…" maxlength="30" />
              <datalist id="uni-tipos"><option v-for="t in TIPOS_SUGERIDOS" :key="t" :value="t" /></datalist>
            </label>
            <label v-if="!uniForm.id" class="fld-check">
              <input type="checkbox" v-model="uniForm.crear_deposito" />
              <span>Crear un depósito para esta área <small>(podés sumarle más después)</small></span>
            </label>
            <div class="cat-form__actions"><button type="button" class="btn" @click="uniForm = null">Cancelar</button><button type="submit" class="btn btn--primary" :disabled="store.saving">Guardar</button></div>
          </form>

          <ul class="cat-list">
            <li v-for="u in store.unidades" :key="u.id" class="cat-item" :class="{ 'is-off': !u.activa }">
              <span class="dot" :style="{ background: u.color || '#cbd5e1' }"></span>
              <span class="cat-item__name"><span class="cat-item__label">{{ u.nombre }}</span><small>{{ u.tipo }}</small></span>
              <span v-if="u.es_sistema" class="tag">sistema</span>
              <div class="cat-item__actions">
                <button class="lnk" @click="editarUnidad(u)">Editar</button>
                <button v-if="!u.es_sistema" class="lnk lnk--danger" @click="borrarUnidad(u)">Borrar</button>
              </div>
            </li>
          </ul>
        </section>
      </div>
    </template>
  </div>
</template>

<style scoped>
.cat-view { padding: 1.5rem 1.75rem 3rem; max-width: 1080px; margin: 0 auto; color: #0f172a; }
.cat-loading { color: #64748b; padding: 2rem; text-align: center; }

/* Intro */
.cat-intro { background: #fff; border: 1px solid #e2e8f0; border-radius: 14px; padding: 1.25rem 1.4rem; margin-bottom: 1rem; }
.cat-intro__title { font-size: 1rem; font-weight: 750; margin: 0 0 .4rem; }
.cat-intro__lead { font-size: .86rem; color: #475569; margin: 0 0 .9rem; line-height: 1.5; max-width: 72ch; }
.cat-intro__note { font-size: .8rem; color: #64748b; margin: .3rem 0 0; line-height: 1.5; }
.cat-intro__note .bi { color: #b45309; margin-right: .2rem; }

/* Tipo de área read-only (sistema) + checkbox crear depósito */
.uni-tipo-ro { font-weight: 500; color: #334155; text-transform: capitalize; }
.uni-tipo-ro small { color: #94a3b8; font-weight: 400; text-transform: none; }
.fld-check { display: flex; align-items: flex-start; gap: .5rem; font-size: .82rem; color: #334155; font-weight: 600; cursor: pointer; }
.fld-check input { margin-top: .15rem; width: 15px; height: 15px; accent-color: #1b5e20; flex-shrink: 0; }
.fld-check small { display: block; font-weight: 400; color: #94a3b8; }

.cat-grid { display: grid; grid-template-columns: 1.5fr 1fr; gap: 1rem; align-items: start; }
@media (max-width: 860px) { .cat-grid { grid-template-columns: 1fr; } }

.cat-card { background: #fff; border: 1px solid #e2e8f0; border-radius: 14px; padding: 1.25rem; }
.cat-card__head { display: flex; align-items: center; justify-content: space-between; gap: .75rem; margin-bottom: .5rem; }
.cat-card__head h2 { font-size: 1rem; font-weight: 700; color: #0f172a; margin: 0; }
.cat-card__hint { color: #64748b; font-size: .8rem; margin: 0 0 1rem; }

.cat-form { display: flex; flex-direction: column; gap: .6rem; background: #f8fafc; border: 1px solid #e8edf2; border-radius: 10px; padding: .9rem; margin: .5rem 0 1rem; }
.cat-form__title { font-size: .84rem; font-weight: 700; color: #0f172a; }
.cat-form__sub { font-weight: 400; color: #64748b; }
.cat-form__actions { display: flex; gap: .5rem; justify-content: flex-end; margin-top: .25rem; }
.fld { display: flex; flex-direction: column; gap: .3rem; font-size: .78rem; color: #475569; font-weight: 600; }
.fld-row { display: grid; grid-template-columns: 1fr 1fr; gap: .6rem; }
@media (max-width: 520px) { .fld-row { grid-template-columns: 1fr; } }
.fld-hint { font-weight: 400; color: #94a3b8; font-size: .72rem; }
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
.cat-item.is-off, .cat-madre.is-off > .cat-item--madre { opacity: .5; }
.cat-item--madre { font-weight: 600; }
.dot { width: 11px; height: 11px; border-radius: 4px; flex-shrink: 0; }
.cat-item__name { font-size: .86rem; color: #0f172a; display: flex; flex-direction: column; min-width: 0; }
.cat-item__label { display: inline-flex; align-items: center; gap: .4rem; }
.cat-item__name small { color: #94a3b8; font-weight: 400; font-size: .72rem; display: inline-flex; align-items: center; }
.off-tag { font-size: 10px; font-weight: 700; text-transform: uppercase; letter-spacing: .04em; color: #b45309; background: #fef3c7; padding: 1px 6px; border-radius: 999px; }
.tag { font-size: 10px; text-transform: uppercase; letter-spacing: .05em; font-weight: 700; padding: 2px 7px; border-radius: 999px; background: #f1f5f9; color: #64748b; flex-shrink: 0; }
.tag--sm { font-size: 9px; padding: 1px 6px; }
.cat-item__actions { margin-left: auto; display: flex; gap: .4rem; flex-wrap: wrap; justify-content: flex-end; }
.cat-subs { list-style: none; margin: 0 0 .3rem; padding: 0 0 0 .5rem; }
.cat-item--sub { padding: .4rem .15rem; }
.cat-sub-dash { width: 14px; height: 1px; background: #cbd5e1; flex-shrink: 0; }
.cat-item--sub .cat-item__name { font-weight: 500; }
.cat-empty { color: #94a3b8; font-size: .8rem; padding: .5rem 0; }

.btn { border: 1.5px solid #e2e8f0; background: #fff; color: #334155; border-radius: 9px; padding: .5rem .85rem; font-size: .82rem; font-weight: 600; cursor: pointer; }
.btn:hover { border-color: #cbd5e1; }
.btn--primary { background: #1b5e20; border-color: #1b5e20; color: #fff; }
.btn--primary:hover { background: #144a18; }
.btn:disabled { opacity: .5; cursor: default; }
.lnk { background: none; border: none; color: #64748b; font-size: .78rem; font-weight: 600; cursor: pointer; padding: .1rem .3rem; white-space: nowrap; }
.lnk:hover { color: #0f172a; }
.lnk--warn:hover { color: #b45309; }
.lnk--danger:hover { color: #dc2626; }
</style>
