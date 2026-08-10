<script setup>
// Catálogo de Finanzas — mapa por ÁREA: cada sector de la organización se despliega y muestra TODO lo suyo
// junto (sus categorías madre→sub y sus depósitos). El sector es el eje: tanto las categorías como
// los depósitos responden a un sector. Los depósitos se ven acá (read-only) y se gestionan en el hub
// "Depósito". Las categorías sin sector caen en el bucket "Sin sector" (así ninguna queda huérfana).
import { ref, reactive, computed, onMounted } from 'vue'
import { useCatalogoFinanzasStore } from '../../stores/catalogoFinanzas.js'
import { useConfirm } from '../../composables/useConfirm.js'
import { useToast } from '../../composables/useToast.js'
import { listDepositos } from '../../lib/api.js'
import CategoriaFila from '../../components/contabilidad/CategoriaFila.vue'

const store = useCatalogoFinanzasStore()
const { confirm } = useConfirm()
const toast = useToast()

const TIPOS_SUGERIDOS = ['cultivo', 'dispensario', 'bar', 'social', 'administracion', 'general']
const COLORES = ['#1b5e20', '#15803d', '#b45309', '#8a4b2f', '#dc2626', '#3b82f6', '#64748b', '#7c3aed']
const FAMILIA_LABEL = { insumo: 'insumos de cultivo', insumo_general: 'insumos generales', mercaderia: 'mercadería', general: 'general' }

const depositos = ref([])
async function cargarDepositos() { try { depositos.value = (await listDepositos()).data || [] } catch { depositos.value = [] } }
onMounted(async () => { await store.fetchAll(); await cargarDepositos() })

// La explicación de la pantalla, a demanda: ver `cat-ayuda` en el template.
const verAyuda = ref(false)

// ── Acordeón (qué sectores están abiertos) ───────────────────────
const abiertas = reactive({})
function toggle(id) { abiertas[id] = !abiertas[id] }
const abierta = (id) => !!abiertas[id]

// ── Agrupaciones por sector ─────────────────────────────────────
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
// El tipo viene de la columna desde la que se apretó "+ Categoría": si estás mirando los
// ingresos, la nueva nace como ingreso y no hay que acordarse de cambiar el select.
function nuevaMadre(area = null, tipo = 'egreso') {
  catForm.value = { parent_id: null, nombre: '', tipo, unidad_negocio_id: area?.id ?? null,
                    color: area?.color || COLORES[0], areaNombre: area?.nombre }
}
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

// ── Sectores (CRUD) ──────────────────────────────────────────────
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
      toast.success('Sector guardado')
    } else {
      await store.crearUnidad({ nombre: f.nombre.trim(), tipo, color: f.color, activa: f.activa }, { crear_deposito: !!f.crear_deposito })
      toast.success(f.crear_deposito ? 'Sector y depósito creados' : 'Sector creado')
      await cargarDepositos()
    }
    uniForm.value = null
  } catch { toast.error(store.saveError) }
}
async function borrarUnidad(u) {
  if (!(await confirm({ title: 'Eliminar sector', message: `¿Eliminar "${u.nombre}"?`, variant: 'danger' }))) return
  try { await store.eliminarUnidad(u.id); toast.success('Sector eliminado') }
  catch (e) { toast.error(e?.response?.data?.error || 'No se pudo eliminar') }
}
</script>

<template>
  <div class="cat-view">
    <div v-if="store.loading" class="cat-loading">Cargando catálogo…</div>

    <template v-else>
      <!-- Header. La explicación de la pantalla vive detrás de "¿Cómo funciona?": un párrafo
           de cuatro líneas fijo arriba es la confesión de que la pantalla no se lee sola, y lo
           paga todos los días el que ya sabe cómo funciona. -->
      <div class="cat-head">
        <h2>Sectores de la organización</h2>
        <div class="cat-head__acciones">
          <button class="lnk cat-ayuda-btn" @click="verAyuda = !verAyuda">
            <i class="bi bi-question-circle"></i> ¿Cómo funciona?
          </button>
          <button class="btn btn--primary" @click="nuevaUnidad">+ Sector</button>
        </div>
      </div>

      <div v-if="verAyuda" class="cat-ayuda">
        <p>
          Cada <b>sector</b> (Cultivo, Buffet, Dispensario…) tiene su propio resultado. Adentro
          viven sus <b>categorías</b> —con las que se clasifica cada movimiento del libro— y sus
          <b>depósitos</b>, donde está el inventario.
        </p>
        <p>
          Los depósitos se ven acá pero se gestionan en <b>Depósito</b>. Lo que trae el sistema no
          se borra, se desactiva; lo que creás vos sí se puede borrar mientras no tenga movimientos.
        </p>
      </div>

      <!-- Form ÁREA (al crear/editar) -->
      <form v-if="uniForm" class="cat-form" @submit.prevent="guardarUnidad">
        <div class="cat-form__title">{{ uniForm.id ? 'Editar' : 'Nuevo' }} sector</div>
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
          <span>Crear un depósito para este sector <small>(podés sumarle más después)</small></span>
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
            <label class="fld">Sector
              <select v-model="catForm.unidad_negocio_id" class="inp">
                <option :value="null">— Sin sector —</option>
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

      <!-- Acordeón de sectores -->
      <div class="acc">
        <div v-for="area in store.unidades" :key="area.id" class="acc-item" :class="{ 'is-off': !area.activa }">
          <button class="acc-head" @click="toggle(area.id)">
            <i class="bi acc-chev" :class="abierta(area.id) ? 'bi-chevron-down' : 'bi-chevron-right'"></i>
            <span class="dot" :style="{ background: area.color || '#cbd5e1' }"></span>
            <span class="acc-name">{{ area.nombre }}</span>
            <!-- Igual que en las categorías: se marca lo que creó la organización, que es la
                 excepción, no lo que trae el sistema, que es casi todo. -->
            <span v-if="!area.es_sistema" class="tag">propio</span>
            <span class="acc-sum">{{ nCatsDe(area.id) }} categorías · {{ depsDe(area.id).length }} depósito{{ depsDe(area.id).length !== 1 ? 's' : '' }}</span>
          </button>

          <div v-if="abierta(area.id)" class="acc-body">
            <!-- Egresos e ingresos, uno al lado del otro. Antes iban encadenados en una sola
                 columna angosta contra el margen izquierdo, con media pantalla vacía a la
                 derecha y dos títulos ("CATEGORÍAS" y "EGRESOS") antes de llegar al dato. -->
            <div class="cat-cols">
              <section v-for="tipo in ['egreso','ingreso']" :key="tipo" class="cat-col">
                <header class="cat-col__head" :class="tipo === 'ingreso' ? 'is-in' : 'is-out'">
                  {{ tipo === 'ingreso' ? 'Ingresos' : 'Egresos' }}
                </header>

                <template v-for="m in catsDe(area.id, tipo)" :key="m.id">
                  <CategoriaFila
                    :cat="m"
                    @nueva-sub="nuevaSub(m)"
                    @editar="editar(m)"
                    @toggle-activa="toggleActiva(m)"
                    @borrar="borrarCat(m)"
                  />
                  <CategoriaFila
                    v-for="s in m.subcategorias || []" :key="s.id"
                    :cat="s" sub
                    @editar="editar(s, m)"
                    @toggle-activa="toggleActiva(s)"
                    @borrar="borrarCat(s)"
                  />
                </template>

                <p v-if="!catsDe(area.id, tipo).length" class="cat-col__vacio">
                  Sin {{ tipo === 'ingreso' ? 'ingresos' : 'egresos' }} todavía.
                </p>
                <button class="lnk cat-col__add" @click="nuevaMadre(area, tipo)">
                  <i class="bi bi-plus-lg"></i> Categoría
                </button>
              </section>
            </div>

            <!-- Depósitos: una línea al pie. Son de sólo lectura acá, no merecen una sección
                 con título propio compitiendo con las categorías. -->
            <div class="cat-deps">
              <span class="cat-deps__lbl"><i class="bi bi-box-seam"></i> Depósitos</span>
              <template v-if="depsDe(area.id).length">
                <span v-for="d in depsDe(area.id)" :key="d.id" class="cat-deps__item">
                  {{ d.nombre }}<small v-if="d.sede_nombre"> · {{ d.sede_nombre }}</small>
                </span>
              </template>
              <span v-else class="cat-deps__vacio">este sector no tiene depósitos</span>
            </div>

            <!-- Acciones del sector -->
            <div class="acc-actions">
              <button class="lnk" @click="editarUnidad(area)">Editar sector</button>
              <button v-if="!area.es_sistema" class="lnk lnk--danger" @click="borrarUnidad(area)">Borrar sector</button>
            </div>
          </div>
        </div>

        <!-- Bucket "Sin sector" (categorías sin sector asignado) -->
        <div v-if="sinArea.total" class="acc-item acc-item--sin">
          <button class="acc-head" @click="toggle('sin')">
            <i class="bi acc-chev" :class="abierta('sin') ? 'bi-chevron-down' : 'bi-chevron-right'"></i>
            <span class="dot" style="background:#cbd5e1"></span>
            <span class="acc-name">Sin sector</span>
            <span class="acc-sum">{{ sinArea.total }} categoría{{ sinArea.total !== 1 ? 's' : '' }} sin sector</span>
          </button>
          <div v-if="abierta('sin')" class="acc-body">
            <p class="acc-hint">Estas categorías no tienen sector. Editá cada una y asignale uno para que aparezca donde corresponde.</p>
            <!-- Mismas dos columnas y la misma fila que en un sector: antes esto era una copia
                 del markup y las acciones ya habían divergido (acá faltaba "Agregar sub"). -->
            <div class="cat-cols">
              <section v-for="tipo in ['egreso','ingreso']" :key="tipo" class="cat-col">
                <template v-if="sinArea[tipo].length">
                  <header class="cat-col__head" :class="tipo === 'ingreso' ? 'is-in' : 'is-out'">
                    {{ tipo === 'ingreso' ? 'Ingresos' : 'Egresos' }}
                  </header>
                  <CategoriaFila
                    v-for="m in sinArea[tipo]" :key="m.id"
                    :cat="m"
                    @nueva-sub="nuevaSub(m)"
                    @editar="editar(m)"
                    @toggle-activa="toggleActiva(m)"
                    @borrar="borrarCat(m)"
                  />
                </template>
              </section>
            </div>
          </div>
        </div>
      </div>
    </template>
  </div>
</template>

<style scoped>
.cat-view { padding: 1.5rem 1.75rem 3rem; max-width: 900px; margin: 0 auto; color: var(--c-slate-900); }
.cat-loading { color: var(--c-slate-500); padding: 2rem; text-align: center; }

/* Ayuda a demanda: la misma información, pero sólo cuando alguien la pide. */
.cat-ayuda { background: var(--c-slate-50); border: 1px solid var(--c-slate-200); border-left: 3px solid #b45309; border-radius: 10px; padding: .9rem 1.1rem; margin-bottom: 1rem; }
.cat-ayuda p { font-size: .84rem; color: var(--c-slate-600); line-height: 1.55; margin: 0 0 .5rem; max-width: 78ch; }
.cat-ayuda p:last-child { margin-bottom: 0; }
.cat-ayuda-btn { font-size: .8rem; }
.cat-head__acciones { display: flex; align-items: center; gap: .8rem; }

/* Egresos e ingresos, lado a lado: usan el ancho que antes quedaba vacío a la derecha. */
.cat-cols { display: grid; grid-template-columns: 1fr 1fr; gap: 1.2rem 2rem; }
.cat-col { min-width: 0; }
.cat-col__head {
  font-size: .66rem; font-weight: 800; text-transform: uppercase; letter-spacing: .07em;
  padding-bottom: .3rem; margin-bottom: .25rem; border-bottom: 1px solid #eef2f6;
}
.cat-col__head.is-in  { color: #15803d; border-bottom-color: #dcfce7; }
.cat-col__head.is-out { color: #b45309; border-bottom-color: #fef3c7; }
.cat-col__vacio { font-size: .8rem; color: var(--c-slate-400); margin: .5rem 0 .2rem .5rem; }
.cat-col__add { margin-top: .35rem; font-size: .8rem; }

/* Los depósitos son de sólo lectura acá: una línea al pie, sin sección propia. */
.cat-deps {
  display: flex; align-items: center; flex-wrap: wrap; gap: .5rem;
  margin-top: 1.1rem; padding-top: .8rem; border-top: 1px dashed #eef2f6;
}
.cat-deps__lbl { font-size: .72rem; font-weight: 800; text-transform: uppercase; letter-spacing: .06em; color: var(--c-slate-500); }
.cat-deps__lbl .bi { color: #8a4b2f; margin-right: .25rem; }
.cat-deps__item { font-size: .8rem; color: var(--c-slate-700); background: var(--c-slate-50); border: 1px solid #eef2f6; border-radius: 999px; padding: .2rem .65rem; }
.cat-deps__item small { color: var(--c-slate-400); }
.cat-deps__vacio { font-size: .8rem; color: var(--c-slate-400); font-style: italic; }

@media (max-width: 860px) { .cat-cols { grid-template-columns: 1fr; } }

.cat-head { display: flex; align-items: center; justify-content: space-between; gap: .75rem; margin: 0 .15rem 1rem; }
.cat-head h2 { font-size: 1.05rem; font-weight: 750; margin: 0; }

/* Acordeón */
.acc { display: flex; flex-direction: column; gap: .6rem; }
.acc-item { background: #fff; border: 1px solid var(--c-slate-200); border-radius: 12px; overflow: hidden; }
.acc-item.is-off { opacity: .6; }
.acc-item--sin { border-style: dashed; }
.acc-head { display: flex; align-items: center; gap: .6rem; width: 100%; padding: .9rem 1.1rem; background: none; border: none; cursor: pointer; text-align: left; }
.acc-head:hover { background: #fafbfc; }
.acc-chev { color: var(--c-slate-400); font-size: .8rem; }
.dot { width: 12px; height: 12px; border-radius: 4px; flex-shrink: 0; }
.acc-name { font-size: .95rem; font-weight: 700; color: var(--c-slate-900); }
.acc-sum { margin-left: auto; font-size: .76rem; color: var(--c-slate-400); white-space: nowrap; }
.acc-body { padding: .3rem 1.1rem 1.1rem; border-top: 1px solid var(--c-slate-100); }
.acc-hint { font-size: .8rem; color: var(--c-slate-400); margin: .6rem 0; }

.acc-actions { display: flex; gap: .5rem; margin-top: 1rem; padding-top: .7rem; border-top: 1px dashed #eef2f6; }

.off-tag { font-size: 10px; font-weight: 700; text-transform: uppercase; letter-spacing: .04em; color: #b45309; background: #fef3c7; padding: 1px 6px; border-radius: 999px; }
.tag { font-size: 10px; text-transform: uppercase; letter-spacing: .05em; font-weight: 700; padding: 2px 7px; border-radius: 999px; background: var(--c-slate-100); color: var(--c-slate-500); flex-shrink: 0; }


/* Forms (reusados) */
.cat-form { display: flex; flex-direction: column; gap: .6rem; background: #fff; border: 1px solid var(--c-slate-200); border-radius: 12px; padding: 1rem; margin-bottom: 1rem; }
.cat-form__title { font-size: .84rem; font-weight: 700; color: var(--c-slate-900); }
.cat-form__sub { font-weight: 400; color: var(--c-slate-500); }
.cat-form__actions { display: flex; gap: .5rem; justify-content: flex-end; margin-top: .25rem; }
.fld { display: flex; flex-direction: column; gap: .3rem; font-size: .78rem; color: var(--c-slate-600); font-weight: 600; }
.fld-row { display: grid; grid-template-columns: 1fr 1fr; gap: .6rem; }
@media (max-width: 520px) { .fld-row { grid-template-columns: 1fr; } }
.fld-hint { font-weight: 400; color: var(--c-slate-400); font-size: .72rem; }
.fld-check { display: flex; align-items: flex-start; gap: .5rem; font-size: .82rem; color: var(--c-slate-700); font-weight: 600; cursor: pointer; }
.fld-check input { margin-top: .15rem; width: 15px; height: 15px; accent-color: #1b5e20; flex-shrink: 0; }
.fld-check small { display: block; font-weight: 400; color: var(--c-slate-400); }
.uni-tipo-ro { font-weight: 500; color: var(--c-slate-700); text-transform: capitalize; }
.uni-tipo-ro small { color: var(--c-slate-400); font-weight: 400; text-transform: none; }
.inp { width: 100%; padding: .5rem .65rem; border: 1.5px solid var(--c-slate-200); border-radius: 8px; font-size: .84rem; background: #fff; color: var(--c-slate-900); }
.inp:focus { border-color: #1b5e20; outline: none; }
.swatches { display: flex; gap: 6px; flex-wrap: wrap; }
.sw { width: 24px; height: 24px; border-radius: 6px; border: 2px solid transparent; cursor: pointer; }
.sw--on { border-color: var(--c-slate-900); box-shadow: 0 0 0 2px #fff inset; }

.btn { border: 1.5px solid var(--c-slate-200); background: #fff; color: var(--c-slate-700); border-radius: 9px; padding: .5rem .85rem; font-size: .82rem; font-weight: 600; cursor: pointer; }
.btn:hover { border-color: var(--c-slate-300); }
.btn--primary { background: #1b5e20; border-color: #1b5e20; color: #fff; }
.btn--primary:hover { background: #144a18; }
.btn:disabled { opacity: .5; cursor: default; }
.lnk { background: none; border: none; color: var(--c-slate-500); font-size: .78rem; font-weight: 600; cursor: pointer; padding: .1rem .3rem; white-space: nowrap; }
.lnk:hover { color: var(--c-slate-900); }
.lnk--warn:hover { color: #b45309; }
.lnk--danger:hover { color: #dc2626; }
</style>
