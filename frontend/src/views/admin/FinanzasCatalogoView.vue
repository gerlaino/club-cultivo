<script setup>
// Catálogo de Finanzas — mapa por ÁREA: cada área del club se despliega y muestra TODO lo suyo
// junto (sus categorías madre→sub y sus depósitos). El área es el eje: tanto las categorías como
// los depósitos responden a un área. Los depósitos se ven acá (read-only) y se gestionan en el hub
// "Depósito". Las categorías sin área caen en el bucket "Sin área" (así ninguna queda huérfana).
import { ref, reactive, computed, onMounted } from 'vue'
import { useCatalogoFinanzasStore } from '../../stores/catalogoFinanzas.js'
import { useConfirm } from '../../composables/useConfirm.js'
import { useToast } from '../../composables/useToast.js'
import { listDepositos } from '../../lib/api.js'

const store = useCatalogoFinanzasStore()
const { confirm } = useConfirm()
const toast = useToast()

const TIPOS_SUGERIDOS = ['cultivo', 'dispensario', 'bar', 'social', 'administracion', 'general']
const COLORES = ['#1b5e20', '#15803d', '#b45309', '#8a4b2f', '#dc2626', '#3b82f6', '#64748b', '#7c3aed']
const FAMILIA_LABEL = { insumo: 'insumos de cultivo', insumo_general: 'insumos generales', mercaderia: 'mercadería', general: 'general' }

const depositos = ref([])
async function cargarDepositos() { try { depositos.value = (await listDepositos()).data || [] } catch { depositos.value = [] } }
onMounted(async () => { await store.fetchAll(); await cargarDepositos() })

// ── Acordeón (qué áreas están abiertas) ───────────────────────
const abiertas = reactive({})
function toggle(id) { abiertas[id] = !abiertas[id] }
const abierta = (id) => !!abiertas[id]

// ── Agrupaciones por área ─────────────────────────────────────
const catsDe   = (areaId, tipo) => store.categorias.filter(m => m.unidad_negocio_id === areaId && m.tipo === tipo)
const nCatsDe  = (areaId) => store.categorias.filter(m => m.unidad_negocio_id === areaId).length
const depsDe   = (areaId) => depositos.value.filter(d => d.unidad_negocio_id === areaId)
const sinArea  = computed(() => ({
  egreso:  store.categorias.filter(c => !c.unidad_negocio_id && c.tipo === 'egreso'),
  ingreso: store.categorias.filter(c => !c.unidad_negocio_id && c.tipo === 'ingreso'),
  total:   store.categorias.filter(c => !c.unidad_negocio_id).length,
}))
const familiaLabel = (d) => FAMILIA_LABEL[d.familia] || d.familia || 'general'

// ── Categorías (CRUD) ─────────────────────────────────────────
const catForm = ref(null)
function nuevaMadre(area = null) { catForm.value = { parent_id: null, nombre: '', tipo: 'egreso', unidad_negocio_id: area?.id ?? null, color: area?.color || COLORES[0], areaNombre: area?.nombre } }
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
async function toggleActiva(c) {
  try {
    await store.actualizarCategoria(c.id, { activa: !c.activa })
    toast.success(c.activa ? 'Categoría desactivada' : 'Categoría reactivada')
  } catch { toast.error(store.saveError || 'No se pudo actualizar') }
}
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

// ── Áreas (CRUD) ──────────────────────────────────────────────
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
      await cargarDepositos()
    }
    uniForm.value = null
  } catch { toast.error(store.saveError) }
}
async function borrarUnidad(u) {
  if (!(await confirm({ title: 'Eliminar área', message: `¿Eliminar "${u.nombre}"?`, variant: 'danger' }))) return
  try { await store.eliminarUnidad(u.id); toast.success('Eliminada') }
  catch (e) { toast.error(e?.response?.data?.error || 'No se pudo eliminar') }
}
</script>

<template>
  <div class="cat-view">
    <div v-if="store.loading" class="cat-loading">Cargando catálogo…</div>

    <template v-else>
      <!-- Intro -->
      <div class="cat-intro">
        <h2 class="cat-intro__title">El club por áreas</h2>
        <p class="cat-intro__lead">
          Cada <b>área</b> (línea de negocio: Cultivo, Bar, Dispensario…) tiene su propio resultado.
          Desplegá un área para ver todo lo suyo: sus <b>categorías</b> (madre → subcategoría, para
          clasificar los movimientos del libro) y sus <b>depósitos</b> (dónde vive su inventario).
        </p>
        <p class="cat-intro__note">
          <i class="bi bi-info-circle"></i>
          Los <b>depósitos</b> se ven acá pero se gestionan en la sección <b>Depósito</b>. Las categorías
          y áreas del <b>sistema</b> no se borran (se desactivan); las que creás vos, sí (sin movimientos).
        </p>
      </div>

      <!-- Header -->
      <div class="cat-head">
        <h2>Áreas del club</h2>
        <button class="btn btn--primary" @click="nuevaUnidad">+ Área</button>
      </div>

      <!-- Form ÁREA (al crear/editar) -->
      <form v-if="uniForm" class="cat-form" @submit.prevent="guardarUnidad">
        <div class="cat-form__title">{{ uniForm.id ? 'Editar' : 'Nueva' }} área</div>
        <label class="fld">Nombre<input v-model.trim="uniForm.nombre" class="inp" placeholder="Ej: Cultivo" maxlength="40" /></label>
        <template v-if="uniForm.es_sistema">
          <div class="fld">Tipo<span class="uni-tipo-ro">{{ uniForm.tipo }} <small>(del sistema, no editable)</small></span></div>
        </template>
        <label v-else class="fld">Tipo <small class="fld-hint">— etiqueta libre</small>
          <input v-model.trim="uniForm.tipo" class="inp" list="uni-tipos" placeholder="Ej: eventos, cultivo…" maxlength="30" />
          <datalist id="uni-tipos"><option v-for="t in TIPOS_SUGERIDOS" :key="t" :value="t" /></datalist>
        </label>
        <div class="fld"><span>Color</span>
          <div class="swatches"><button v-for="c in COLORES" :key="c" type="button" class="sw" :class="{ 'sw--on': uniForm.color === c }" :style="{ background: c }" @click="uniForm.color = c"></button></div>
        </div>
        <label v-if="!uniForm.id" class="fld-check">
          <input type="checkbox" v-model="uniForm.crear_deposito" />
          <span>Crear un depósito para esta área <small>(podés sumarle más después)</small></span>
        </label>
        <div class="cat-form__actions"><button type="button" class="btn" @click="uniForm = null">Cancelar</button><button type="submit" class="btn btn--primary" :disabled="store.saving">Guardar</button></div>
      </form>

      <!-- Form CATEGORÍA (al crear/editar) -->
      <form v-if="catForm" class="cat-form" @submit.prevent="guardarCat">
        <div class="cat-form__title">
          {{ catForm.id ? 'Editar' : 'Nueva' }} {{ catForm.parent_id ? 'subcategoría' : 'categoría madre' }}
          <span v-if="catForm.parent_id" class="cat-form__sub">de <b>{{ catForm.madreNombre }}</b></span>
          <span v-else-if="catForm.areaNombre" class="cat-form__sub">en <b>{{ catForm.areaNombre }}</b></span>
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
          <div class="fld"><span>Color</span>
            <div class="swatches"><button v-for="c in COLORES" :key="c" type="button" class="sw" :class="{ 'sw--on': catForm.color === c }" :style="{ background: c }" @click="catForm.color = c"></button></div>
          </div>
        </template>
        <div class="cat-form__actions"><button type="button" class="btn" @click="catForm = null">Cancelar</button><button type="submit" class="btn btn--primary" :disabled="store.saving">Guardar</button></div>
      </form>

      <!-- Acordeón de áreas -->
      <div class="acc">
        <div v-for="area in store.unidades" :key="area.id" class="acc-item" :class="{ 'is-off': !area.activa }">
          <button class="acc-head" @click="toggle(area.id)">
            <i class="bi acc-chev" :class="abierta(area.id) ? 'bi-chevron-down' : 'bi-chevron-right'"></i>
            <span class="dot" :style="{ background: area.color || '#cbd5e1' }"></span>
            <span class="acc-name">{{ area.nombre }}</span>
            <span v-if="area.es_sistema" class="tag">sistema</span>
            <span class="acc-sum">{{ nCatsDe(area.id) }} categorías · {{ depsDe(area.id).length }} depósito{{ depsDe(area.id).length !== 1 ? 's' : '' }}</span>
          </button>

          <div v-if="abierta(area.id)" class="acc-body">
            <!-- Categorías del área -->
            <div class="acc-sub">
              <span class="acc-sub__title">Categorías</span>
              <button class="lnk" @click="nuevaMadre(area)"><i class="bi bi-plus-lg"></i> Categoría</button>
            </div>
            <div v-for="tipo in ['egreso','ingreso']" :key="tipo">
              <template v-if="catsDe(area.id, tipo).length">
                <h5 class="cat-group__title" :class="tipo === 'ingreso' ? 'is-in' : 'is-out'">{{ tipo === 'ingreso' ? 'Ingresos' : 'Egresos' }}</h5>
                <div v-for="m in catsDe(area.id, tipo)" :key="m.id" class="cat-madre" :class="{ 'is-off': !m.activa }">
                  <div class="cat-item cat-item--madre">
                    <span class="cat-item__label">{{ m.nombre }}<span v-if="!m.activa" class="off-tag">oculta</span></span>
                    <span v-if="m.es_sistema" class="tag tag--sm">sistema</span>
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
                      <span class="cat-item__label">{{ s.nombre }}<span v-if="!s.activa" class="off-tag">oculta</span></span>
                      <span v-if="s.es_sistema" class="tag tag--sm">sistema</span>
                      <div class="cat-item__actions">
                        <button class="lnk" @click="editar(s, m)">Editar</button>
                        <button class="lnk" :class="{ 'lnk--warn': s.activa }" @click="toggleActiva(s)">{{ s.activa ? 'Desactivar' : 'Reactivar' }}</button>
                        <button v-if="!s.es_sistema" class="lnk lnk--danger" @click="borrarCat(s)">Borrar</button>
                      </div>
                    </li>
                  </ul>
                </div>
              </template>
            </div>
            <div v-if="!nCatsDe(area.id)" class="cat-empty">Sin categorías todavía.</div>

            <!-- Depósitos del área (read-only) -->
            <div class="acc-sub acc-sub--mt"><span class="acc-sub__title">Depósitos</span><small class="acc-sub__hint">se gestionan en Depósito</small></div>
            <div v-if="depsDe(area.id).length" class="dep-list">
              <div v-for="d in depsDe(area.id)" :key="d.id" class="dep-item">
                <i class="bi bi-box-seam"></i> <b>{{ d.nombre }}</b>
                <small v-if="d.sede_nombre"> · 📍 {{ d.sede_nombre }}</small>
                <small> · {{ familiaLabel(d) }}</small>
              </div>
            </div>
            <div v-else class="cat-empty">Esta área no tiene depósitos.</div>

            <!-- Acciones del área -->
            <div class="acc-actions">
              <button class="lnk" @click="editarUnidad(area)">Editar área</button>
              <button v-if="!area.es_sistema" class="lnk lnk--danger" @click="borrarUnidad(area)">Borrar área</button>
            </div>
          </div>
        </div>

        <!-- Bucket "Sin área" (categorías sin área asignada) -->
        <div v-if="sinArea.total" class="acc-item acc-item--sin">
          <button class="acc-head" @click="toggle('sin')">
            <i class="bi acc-chev" :class="abierta('sin') ? 'bi-chevron-down' : 'bi-chevron-right'"></i>
            <span class="dot" style="background:#cbd5e1"></span>
            <span class="acc-name">Sin área</span>
            <span class="acc-sum">{{ sinArea.total }} categoría{{ sinArea.total !== 1 ? 's' : '' }} sin área</span>
          </button>
          <div v-if="abierta('sin')" class="acc-body">
            <p class="acc-hint">Estas categorías no tienen área. Editá cada una y asignale una para que aparezca donde corresponde.</p>
            <div v-for="tipo in ['egreso','ingreso']" :key="tipo">
              <template v-if="sinArea[tipo].length">
                <h5 class="cat-group__title" :class="tipo === 'ingreso' ? 'is-in' : 'is-out'">{{ tipo === 'ingreso' ? 'Ingresos' : 'Egresos' }}</h5>
                <div v-for="m in sinArea[tipo]" :key="m.id" class="cat-madre" :class="{ 'is-off': !m.activa }">
                  <div class="cat-item cat-item--madre">
                    <span class="cat-item__label">{{ m.nombre }}</span>
                    <span v-if="m.es_sistema" class="tag tag--sm">sistema</span>
                    <div class="cat-item__actions">
                      <button class="lnk" @click="editar(m)">Editar</button>
                      <button class="lnk" :class="{ 'lnk--warn': m.activa }" @click="toggleActiva(m)">{{ m.activa ? 'Desactivar' : 'Reactivar' }}</button>
                      <button v-if="!m.es_sistema" class="lnk lnk--danger" @click="borrarCat(m)">Borrar</button>
                    </div>
                  </div>
                </div>
              </template>
            </div>
          </div>
        </div>
      </div>
    </template>
  </div>
</template>

<style scoped>
.cat-view { padding: 1.5rem 1.75rem 3rem; max-width: 900px; margin: 0 auto; color: #0f172a; }
.cat-loading { color: #64748b; padding: 2rem; text-align: center; }

.cat-intro { background: #fff; border: 1px solid #e2e8f0; border-radius: 14px; padding: 1.25rem 1.4rem; margin-bottom: 1rem; }
.cat-intro__title { font-size: 1rem; font-weight: 750; margin: 0 0 .4rem; }
.cat-intro__lead { font-size: .86rem; color: #475569; margin: 0 0 .8rem; line-height: 1.5; max-width: 74ch; }
.cat-intro__note { font-size: .8rem; color: #64748b; margin: 0; line-height: 1.5; }
.cat-intro__note .bi { color: #b45309; margin-right: .2rem; }

.cat-head { display: flex; align-items: center; justify-content: space-between; gap: .75rem; margin: 0 .15rem 1rem; }
.cat-head h2 { font-size: 1.05rem; font-weight: 750; margin: 0; }

/* Acordeón */
.acc { display: flex; flex-direction: column; gap: .6rem; }
.acc-item { background: #fff; border: 1px solid #e2e8f0; border-radius: 12px; overflow: hidden; }
.acc-item.is-off { opacity: .6; }
.acc-item--sin { border-style: dashed; }
.acc-head { display: flex; align-items: center; gap: .6rem; width: 100%; padding: .9rem 1.1rem; background: none; border: none; cursor: pointer; text-align: left; }
.acc-head:hover { background: #fafbfc; }
.acc-chev { color: #94a3b8; font-size: .8rem; }
.dot { width: 12px; height: 12px; border-radius: 4px; flex-shrink: 0; }
.acc-name { font-size: .95rem; font-weight: 700; color: #0f172a; }
.acc-sum { margin-left: auto; font-size: .76rem; color: #94a3b8; white-space: nowrap; }
.acc-body { padding: .3rem 1.1rem 1.1rem; border-top: 1px solid #f1f5f9; }
.acc-hint { font-size: .8rem; color: #94a3b8; margin: .6rem 0; }

.acc-sub { display: flex; align-items: center; gap: .5rem; margin: .8rem 0 .3rem; }
.acc-sub--mt { margin-top: 1.1rem; padding-top: .8rem; border-top: 1px dashed #eef2f6; }
.acc-sub__title { font-size: .72rem; font-weight: 800; text-transform: uppercase; letter-spacing: .06em; color: #334155; }
.acc-sub__hint { font-size: .72rem; color: #cbd5e1; }
.acc-actions { display: flex; gap: .5rem; margin-top: 1rem; padding-top: .7rem; border-top: 1px dashed #eef2f6; }

.cat-group__title { font-size: .66rem; text-transform: uppercase; letter-spacing: .06em; font-weight: 800; margin: .6rem 0 .2rem; }
.cat-group__title.is-in { color: #15803d; } .cat-group__title.is-out { color: #b45309; }
.cat-madre { border-bottom: 1px solid #f6f8fa; padding: .1rem 0; }
.cat-madre:last-child { border-bottom: none; }
.cat-item { display: flex; align-items: center; gap: .6rem; padding: .5rem .1rem; }
.cat-item.is-off, .cat-madre.is-off > .cat-item--madre { opacity: .5; }
.cat-item--madre { font-weight: 600; }
.cat-item__label { display: inline-flex; align-items: center; gap: .4rem; font-size: .86rem; color: #0f172a; min-width: 0; }
.off-tag { font-size: 10px; font-weight: 700; text-transform: uppercase; letter-spacing: .04em; color: #b45309; background: #fef3c7; padding: 1px 6px; border-radius: 999px; }
.tag { font-size: 10px; text-transform: uppercase; letter-spacing: .05em; font-weight: 700; padding: 2px 7px; border-radius: 999px; background: #f1f5f9; color: #64748b; flex-shrink: 0; }
.tag--sm { font-size: 9px; padding: 1px 6px; }
.cat-item__actions { margin-left: auto; display: flex; gap: .35rem; flex-wrap: wrap; justify-content: flex-end; }
.cat-subs { list-style: none; margin: 0 0 .3rem; padding: 0 0 0 .4rem; }
.cat-item--sub { padding: .35rem .1rem; }
.cat-sub-dash { width: 14px; height: 1px; background: #cbd5e1; flex-shrink: 0; }
.cat-item--sub .cat-item__label { font-weight: 500; }
.cat-empty { color: #94a3b8; font-size: .8rem; padding: .4rem 0; }

.dep-list { display: flex; flex-direction: column; gap: .3rem; }
.dep-item { font-size: .84rem; color: #334155; background: #f8fafc; border: 1px solid #eef2f6; border-radius: 8px; padding: .5rem .7rem; }
.dep-item .bi { color: #8a4b2f; margin-right: .2rem; }
.dep-item small { color: #94a3b8; }

/* Forms (reusados) */
.cat-form { display: flex; flex-direction: column; gap: .6rem; background: #fff; border: 1px solid #e2e8f0; border-radius: 12px; padding: 1rem; margin-bottom: 1rem; }
.cat-form__title { font-size: .84rem; font-weight: 700; color: #0f172a; }
.cat-form__sub { font-weight: 400; color: #64748b; }
.cat-form__actions { display: flex; gap: .5rem; justify-content: flex-end; margin-top: .25rem; }
.fld { display: flex; flex-direction: column; gap: .3rem; font-size: .78rem; color: #475569; font-weight: 600; }
.fld-row { display: grid; grid-template-columns: 1fr 1fr; gap: .6rem; }
@media (max-width: 520px) { .fld-row { grid-template-columns: 1fr; } }
.fld-hint { font-weight: 400; color: #94a3b8; font-size: .72rem; }
.fld-check { display: flex; align-items: flex-start; gap: .5rem; font-size: .82rem; color: #334155; font-weight: 600; cursor: pointer; }
.fld-check input { margin-top: .15rem; width: 15px; height: 15px; accent-color: #1b5e20; flex-shrink: 0; }
.fld-check small { display: block; font-weight: 400; color: #94a3b8; }
.uni-tipo-ro { font-weight: 500; color: #334155; text-transform: capitalize; }
.uni-tipo-ro small { color: #94a3b8; font-weight: 400; text-transform: none; }
.inp { width: 100%; padding: .5rem .65rem; border: 1.5px solid #e2e8f0; border-radius: 8px; font-size: .84rem; background: #fff; color: #0f172a; }
.inp:focus { border-color: #1b5e20; outline: none; }
.swatches { display: flex; gap: 6px; flex-wrap: wrap; }
.sw { width: 24px; height: 24px; border-radius: 6px; border: 2px solid transparent; cursor: pointer; }
.sw--on { border-color: #0f172a; box-shadow: 0 0 0 2px #fff inset; }

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
