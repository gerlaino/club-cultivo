<template>
  <div class="rc">
    <header class="rc__head">
      <div>
        <h1 class="rc__title">{{ esPersonal ? 'Nutrientes y recetas' : 'Recetas de nutrientes' }}</h1>
        <p class="rc__sub">
          {{ esPersonal
            ? 'Lo que tenés y cómo lo mezclás. Al regar, aplicás la receta y se descuenta solo.'
            : 'Se arman con los productos del depósito. Al regar, aplicar la receta descuenta del depósito y le cuesta al lote.' }}
        </p>
      </div>
      <div class="rc__head-right">
        <RouterLink v-if="!esPersonal" to="/insumos" class="rc__btn-ghost"><i class="bi bi-box-seam"></i> Depósito</RouterLink>
        <button class="rc__btn-primary" @click="nueva"><i class="bi bi-plus-lg"></i> Nueva receta</button>
      </div>
    </header>

    <!-- ── Uso personal: los nutrientes (los insumos del depósito, sin el vocabulario) ── -->
    <section v-if="esPersonal" class="rc__card">
      <div class="rc__card-head">
        <div>
          <h2 class="rc__card-title">Mis nutrientes</h2>
          <p class="rc__card-sub">Cuánto queda de cada uno. Comprar es un gasto: lo cargás acá o desde Gastos, y queda en los dos lados.</p>
        </div>
        <button class="rc__btn-ghost" @click="nuevoNutriente"><i class="bi bi-plus-lg"></i> Nutriente</button>
      </div>
      <!-- Solapas: los que se usan y los archivados (se archiva lo que ya se usó o está en una
           receta y no se puede borrar). Desde «Archivados» se vuelven a activar. -->
      <div class="rc__tabs" role="tablist">
        <button role="tab" class="rc__tab" :class="{ 'rc__tab--on': solapa === 'activos' }" :aria-selected="solapa === 'activos'" @click="solapa = 'activos'">
          En uso <span class="rc__tab-n">{{ insumos.length }}</span>
        </button>
        <button role="tab" class="rc__tab" :class="{ 'rc__tab--on': solapa === 'archivados' }" :aria-selected="solapa === 'archivados'" @click="solapa = 'archivados'">
          Archivados <span class="rc__tab-n">{{ archivados.length }}</span>
        </button>
      </div>
      <template v-if="solapa === 'archivados'">
        <div v-if="!archivados.length" class="rc__empty">No hay nutrientes archivados. Se archiva uno cuando ya lo usaste y no se puede borrar.</div>
        <div v-else class="rc__nutrientes">
          <div v-for="i in archivados" :key="i.id" class="rc__nutriente rc__nutriente--archivado">
            <div class="rc__nutriente-main">
              <span class="rc__nutriente-nombre">{{ i.nombre }}</span>
              <span class="rc__nutriente-stock">quedan <b>{{ num(i.stock_actual) }} {{ u(i.unidad_medida) }}</b></span>
            </div>
            <button class="rc__btn-ghost rc__btn-ghost--sm" :disabled="reactivando === i.id" @click="reactivarNutriente(i)">
              <i class="bi bi-arrow-counterclockwise"></i> Reactivar
            </button>
          </div>
        </div>
      </template>
      <div v-else-if="!insumos.length" class="rc__empty">Todavía no cargaste ninguno. Con «Nutriente» lo das de alta; con «Repuse» cargás lo que compraste.</div>
      <div v-else class="rc__nutrientes">
        <div v-for="i in insumos" :key="i.id" class="rc__nutriente" :class="{ 'rc__nutriente--bajo': i.stock_bajo }">
          <div class="rc__nutriente-main">
            <span class="rc__nutriente-nombre">{{ i.nombre }}</span>
            <span class="rc__nutriente-stock">
              quedan <b>{{ num(i.stock_actual) }} {{ u(i.unidad_medida) }}</b>
              <template v-if="i.aplicaciones_estimadas != null"> · alcanza para ~{{ i.aplicaciones_estimadas }} riego{{ i.aplicaciones_estimadas === 1 ? '' : 's' }}</template>
              <template v-if="i.stock_bajo"> · <span class="rc__bajo">queda poco</span></template>
            </span>
          </div>
          <div class="rc__nutriente-acts">
            <button class="rc__btn-ghost rc__btn-ghost--sm" @click="reponer(i)"><i class="bi bi-cart-plus"></i> Repuse</button>
            <button class="rc__icon" title="Editar" :aria-label="`Editar ${i.nombre}`" @click="editarNutriente(i)"><i class="bi bi-pencil"></i></button>
            <button class="rc__icon" title="Corregir cantidad" :aria-label="`Corregir cantidad de ${i.nombre}`" @click="corregirNutriente(i)"><i class="bi bi-clipboard-check"></i></button>
            <button class="rc__icon rc__icon--danger" title="Eliminar" :aria-label="`Eliminar ${i.nombre}`" @click="eliminarNutriente(i)"><i class="bi bi-trash"></i></button>
          </div>
        </div>
      </div>
    </section>

    <!-- ── Recetas ── -->
    <div v-if="cargando" class="rc__empty"><DsSpinner :size="18" /></div>
    <div v-else-if="!recetas.length" class="rc__card rc__empty">
      Ninguna receta todavía. Una receta es la mezcla que usás para una fase: qué productos y cuánto por litro. Al regar la aplicás con los litros que preparaste.
    </div>
    <div v-else class="rc__grid">
      <article v-for="r in recetas" :key="r.id" class="rc__receta" :class="{ 'rc__receta--off': !r.activa }">
        <div class="rc__receta-head">
          <div>
            <h3 class="rc__receta-nombre">{{ r.nombre }}</h3>
            <div class="rc__receta-meta">
              <span v-if="r.fase_label" class="rc__chip">{{ r.fase_label }}</span>
              <span v-if="r.ph_objetivo" class="rc__chip rc__chip--soft">pH {{ r.ph_objetivo }}</span>
              <span v-if="r.ec_objetivo" class="rc__chip rc__chip--soft">EC {{ r.ec_objetivo }}</span>
              <span v-if="!r.activa" class="rc__chip rc__chip--off">Archivada</span>
            </div>
          </div>
          <div class="rc__receta-acts">
            <button class="rc__icon" title="Editar" @click="editar(r)"><i class="bi bi-pencil"></i></button>
            <button class="rc__icon" title="Duplicar" @click="duplicar(r)"><i class="bi bi-files"></i></button>
            <button class="rc__icon" :title="r.activa ? 'Archivar' : 'Reactivar'" @click="archivar(r)"><i class="bi" :class="r.activa ? 'bi-archive' : 'bi-arrow-counterclockwise'"></i></button>
          </div>
        </div>
        <ul class="rc__items">
          <li v-for="it in r.items" :key="it.id"><span>{{ it.nombre }}</span><b>{{ num(it.dosis) }} {{ it.unidad_label }}</b></li>
        </ul>
        <!-- Calculadora: para cuántos litros -->
        <div class="rc__calc">
          <label>Para <input type="number" min="0" step="0.5" class="rc__calc-input" v-model.number="litrosPor[r.id]" placeholder="20" /> L</label>
          <span v-if="litrosPor[r.id]" class="rc__calc-res">
            <template v-for="(it, i) in r.items" :key="it.id">{{ i ? ' · ' : '' }}{{ it.nombre }} {{ num(Number(it.dosis) * litrosPor[r.id]) }} {{ it.unidad_insumo === 'gramo' ? 'g' : 'ml' }}</template>
          </span>
        </div>
        <p v-if="r.notas" class="rc__notas">{{ r.notas }}</p>
        <button class="rc__link" @click="verUso(r)"><i class="bi bi-graph-up"></i> Dónde se usó</button>
      </article>
    </div>

    <!-- ── Modal receta ── -->
    <Teleport to="body">
      <div v-modal="cerrar" v-if="form" class="rc__overlay">
        <div class="rc__modal">
          <div class="rc__modal-head">
            <h3 class="rc__modal-title">{{ form.id ? 'Editar receta' : 'Nueva receta' }}</h3>
            <button class="rc__x" @click="cerrar"><i class="bi bi-x-lg"></i></button>
          </div>
          <div class="rc__modal-body">
            <div v-if="formError" class="rc__error">{{ formError }}</div>
            <div class="rc__row">
              <label class="rc__field rc__field--grow">
                <span class="rc__label">Nombre</span>
                <input v-model.trim="form.nombre" class="rc__input" placeholder="Vege semana 2" maxlength="80" />
              </label>
              <label class="rc__field">
                <span class="rc__label">Fase</span>
                <select v-model="form.fase" class="rc__input">
                  <option value="">—</option>
                  <option value="vegetativo">Vegetativo</option>
                  <option value="floracion">Floración</option>
                  <option value="lavado">Lavado</option>
                  <option value="otra">Otra</option>
                </select>
              </label>
            </div>
            <div class="rc__field">
              <span class="rc__label">Productos y dosis por litro</span>
              <div v-for="(it, i) in form.items" :key="i" class="rc__item-row">
                <select v-model="it.insumo_id" class="rc__input rc__input--grow">
                  <option value="" disabled>{{ esPersonal ? 'Nutriente' : 'Producto del depósito' }}</option>
                  <option v-for="ins in opcionesDeReceta" :key="ins.id" :value="ins.id">{{ ins.nombre }}{{ ins.activo === false ? ' (archivado)' : '' }}</option>
                </select>
                <input v-model.number="it.dosis" type="number" step="0.01" min="0" class="rc__input rc__input--num" placeholder="2" />
                <select v-model="it.unidad" class="rc__input rc__input--u">
                  <option value="ml_l">ml/L</option>
                  <option value="g_l">g/L</option>
                </select>
                <button type="button" class="rc__icon" @click="quitarItem(i)"><i class="bi bi-x"></i></button>
              </div>
              <button type="button" class="rc__link" @click="agregarItem"><i class="bi bi-plus"></i> Agregar producto</button>
              <span v-if="!insumos.length" class="rc__hint">{{ esPersonal ? 'Primero cargá un nutriente (arriba).' : 'Primero cargá los productos en el depósito.' }}</span>
            </div>
            <div class="rc__row">
              <label class="rc__field">
                <span class="rc__label">pH objetivo <span class="rc__opt">opcional</span></span>
                <input v-model.number="form.ph_objetivo" type="number" step="0.1" min="0" max="14" class="rc__input" placeholder="6.0" />
              </label>
              <label class="rc__field">
                <span class="rc__label">EC objetivo <span class="rc__opt">opcional</span></span>
                <input v-model.number="form.ec_objetivo" type="number" step="0.1" min="0" class="rc__input" placeholder="1.6" />
              </label>
            </div>
            <label class="rc__field">
              <span class="rc__label">Notas <span class="rc__opt">opcional</span></span>
              <input v-model.trim="form.notas" class="rc__input" placeholder="Cada 2 riegos, alternar con agua sola" maxlength="300" />
            </label>
          </div>
          <div class="rc__modal-foot">
            <button class="rc__btn-ghost" @click="cerrar">Cancelar</button>
            <button class="rc__btn-primary" :disabled="guardando" @click="guardar">
              <DsSpinner v-if="guardando" :size="14" /><span v-else>{{ form.id ? 'Guardar' : 'Crear receta' }}</span>
            </button>
          </div>
        </div>
      </div>
    </Teleport>

    <!-- ── Modal dónde se usó ── -->
    <Teleport to="body">
      <div v-modal="() => uso = null" v-if="uso" class="rc__overlay">
        <div class="rc__modal">
          <div class="rc__modal-head">
            <h3 class="rc__modal-title">{{ uso.nombre }} · dónde se usó</h3>
            <button class="rc__x" @click="uso = null"><i class="bi bi-x-lg"></i></button>
          </div>
          <div class="rc__modal-body">
            <p v-if="!uso.uso.lotes.length" class="rc__hint">Todavía no se aplicó en ningún riego.</p>
            <template v-else>
              <p class="rc__hint">{{ uso.uso.aplicaciones }} aplicaciones · {{ formatARS(uso.uso.costo_total_ars) }} en total</p>
              <table class="rc__table">
                <thead><tr><th>Lote</th><th>Estado</th><th>Riegos</th><th>Litros</th><th>$ nutrientes</th><th>$ / planta</th></tr></thead>
                <tbody>
                  <tr v-for="l in uso.uso.lotes" :key="l.id">
                    <td><RouterLink :to="`/lotes/${l.id}`">{{ l.codigo }}</RouterLink></td>
                    <td>{{ l.estado }}</td><td>{{ l.aplicaciones }}</td><td>{{ num(l.litros) }}</td>
                    <td>{{ formatARS(l.costo_ars) }}</td>
                    <td>{{ l.plantas ? formatARS(l.costo_ars / l.plantas) : '—' }}</td>
                  </tr>
                </tbody>
              </table>
            </template>
          </div>
        </div>
      </div>
    </Teleport>

    <!-- ── Modal nutriente / repuse (uso personal) ── -->
    <Teleport to="body">
      <div v-modal="() => nutForm = null" v-if="nutForm" class="rc__overlay">
        <div class="rc__modal rc__modal--sm">
          <div class="rc__modal-head">
            <h3 class="rc__modal-title">{{ nutForm.id ? `Repuse ${nutForm.nombre}` : 'Nuevo nutriente' }}</h3>
            <button class="rc__x" @click="nutForm = null"><i class="bi bi-x-lg"></i></button>
          </div>
          <div class="rc__modal-body">
            <div v-if="formError" class="rc__error">{{ formError }}</div>
            <template v-if="!nutForm.id">
              <label class="rc__field">
                <span class="rc__label">Nombre</span>
                <input v-model.trim="nutForm.nombre" class="rc__input" placeholder="Bio-Grow" maxlength="80" />
              </label>
              <label class="rc__field">
                <span class="rc__label">Se mide en</span>
                <select v-model="nutForm.unidad_medida" class="rc__input">
                  <option value="mililitro">mililitros (líquido)</option>
                  <option value="gramo">gramos (polvo)</option>
                </select>
              </label>
              <label class="rc__field">
                <span class="rc__label">Avisame cuando queden menos de <span class="rc__opt">opcional</span></span>
                <input v-model.number="nutForm.stock_minimo" type="number" min="0" class="rc__input" placeholder="100" />
              </label>
            </template>
            <div class="rc__row">
              <label class="rc__field">
                <span class="rc__label">{{ nutForm.id ? 'Cuánto compraste' : 'Cuánto tenés' }} ({{ nutForm.unidad_medida === 'gramo' ? 'g' : 'ml' }})</span>
                <input v-model.number="nutForm.cantidad" type="number" min="0" step="1" class="rc__input" placeholder="1000" />
              </label>
              <label class="rc__field">
                <span class="rc__label">Cuánto pagaste ($) <span class="rc__opt">queda como gasto</span></span>
                <input v-model.number="nutForm.costo" type="number" min="0" step="1" class="rc__input" placeholder="18000" />
              </label>
            </div>
            <span class="rc__hint">Si ya lo tenías y no sabés cuánto pagaste, dejá el precio en 0: sólo carga la cantidad.</span>
          </div>
          <div class="rc__modal-foot">
            <button class="rc__btn-ghost" @click="nutForm = null">Cancelar</button>
            <button class="rc__btn-primary" :disabled="guardando" @click="guardarNutriente">
              <DsSpinner v-if="guardando" :size="14" /><span v-else>{{ nutForm.id ? 'Cargar' : 'Crear' }}</span>
            </button>
          </div>
        </div>
      </div>
    </Teleport>

    <!-- ── Modal editar nutriente ── -->
    <Teleport to="body">
      <div v-modal="() => nutEdit = null" v-if="nutEdit" class="rc__overlay">
        <div class="rc__modal rc__modal--sm">
          <div class="rc__modal-head">
            <h3 class="rc__modal-title">Editar {{ nutEdit.nombreOriginal }}</h3>
            <button class="rc__x" @click="nutEdit = null"><i class="bi bi-x-lg"></i></button>
          </div>
          <div class="rc__modal-body">
            <div v-if="formError" class="rc__error">{{ formError }}</div>
            <label class="rc__field">
              <span class="rc__label">Nombre</span>
              <input v-model.trim="nutEdit.nombre" class="rc__input" maxlength="80" />
            </label>
            <label class="rc__field">
              <span class="rc__label">Se mide en</span>
              <select v-model="nutEdit.unidad_medida" class="rc__input" :disabled="nutEdit.con_movimientos">
                <option value="mililitro">mililitros (líquido)</option>
                <option value="gramo">gramos (polvo)</option>
              </select>
              <!-- Con compras o riegos cargados el backend no deja cambiarla: lo cargado se leería en otra medida. -->
              <span v-if="nutEdit.con_movimientos" class="rc__hint">No se puede cambiar: ya tiene compras o riegos cargados en esta unidad.</span>
            </label>
            <label class="rc__field">
              <span class="rc__label">Avisame cuando queden menos de <span class="rc__opt">opcional</span></span>
              <input v-model.number="nutEdit.stock_minimo" type="number" min="0" class="rc__input" placeholder="100" />
            </label>
          </div>
          <div class="rc__modal-foot">
            <button class="rc__btn-ghost" @click="nutEdit = null">Cancelar</button>
            <button class="rc__btn-primary" :disabled="guardando" @click="guardarEdicionNutriente">
              <DsSpinner v-if="guardando" :size="14" /><span v-else>Guardar</span>
            </button>
          </div>
        </div>
      </div>
    </Teleport>

    <!-- ── Modal corregir cantidad ── -->
    <Teleport to="body">
      <div v-modal="() => nutConteo = null" v-if="nutConteo" class="rc__overlay">
        <div class="rc__modal rc__modal--sm">
          <div class="rc__modal-head">
            <h3 class="rc__modal-title">Corregir cantidad de {{ nutConteo.nombre }}</h3>
            <button class="rc__x" @click="nutConteo = null"><i class="bi bi-x-lg"></i></button>
          </div>
          <div class="rc__modal-body">
            <div v-if="formError" class="rc__error">{{ formError }}</div>
            <span class="rc__hint">Hoy figura que quedan <b>{{ num(nutConteo.actual) }} {{ u(nutConteo.unidad_medida) }}</b>.</span>
            <label class="rc__field">
              <span class="rc__label">¿Cuánto queda de verdad? ({{ u(nutConteo.unidad_medida) }})</span>
              <input v-model.number="nutConteo.nuevo" type="number" min="0" step="any" class="rc__input" />
            </label>
            <div class="rc__field">
              <span class="rc__label">¿Por qué?</span>
              <label class="rc__radio"><input v-model="nutConteo.motivo" type="radio" value="correccion" /> Me equivoqué al cargar</label>
              <label class="rc__radio"><input v-model="nutConteo.motivo" type="radio" value="merma" /> Se derramó, se venció o se tiró</label>
            </div>
            <!-- La merma sólo baja (el backend la rechaza si sube): si hay más, es un error de carga. -->
            <span v-if="conteoMermaSube" class="rc__hint rc__hint--warn">Si hay más de lo que figura no es una pérdida: elegí «Me equivoqué al cargar».</span>
          </div>
          <div class="rc__modal-foot">
            <button class="rc__btn-ghost" @click="nutConteo = null">Cancelar</button>
            <button class="rc__btn-primary" :disabled="guardando || !conteoValido" @click="guardarConteo">
              <DsSpinner v-if="guardando" :size="14" /><span v-else>Corregir</span>
            </button>
          </div>
        </div>
      </div>
    </Teleport>
  </div>
</template>

<script setup>
// Recetas de nutrientes: armar, duplicar, archivar, calcular para N litros y ver dónde se usó.
// En uso personal la misma pantalla lleva arriba «Mis nutrientes»: los insumos del depósito con
// otras palabras (el cultivador de casa no tiene «depósito»), con «Repuse» que carga la compra
// y la deja como gasto.
import { ref, computed, onMounted } from 'vue'
import DsSpinner from '../design-system/components/Spinner.vue'
import { useToast } from '../composables/useToast.js'
import { useUsoPersonal } from '../composables/useUsoPersonal.js'
import { useRecargaEnCambios } from '../composables/useRecargaEnCambios.js'
import { formatARS } from '../lib/formatters.js'
import { listRecetas, getReceta, createReceta, updateReceta, listInsumos, createInsumo, comprarInsumo, updateInsumo, reconteoInsumo, deleteInsumo } from '../lib/api.js'
import { useConfirm } from '../composables/useConfirm.js'

const toast = useToast()
const { confirm } = useConfirm()
const { esPersonal } = useUsoPersonal()

const recetas  = ref([])
const todosInsumos = ref([])
const insumos    = computed(() => todosInsumos.value.filter(i => i.activo !== false))
const archivados = computed(() => todosInsumos.value.filter(i => i.activo === false))
const solapa     = ref('activos')
const cargando = ref(true)
const litrosPor = ref({})
const num = v => (v == null ? '—' : Number(v).toLocaleString('es-AR', { maximumFractionDigits: 2 }))
const U = { mililitro: 'ml', gramo: 'g', litro: 'L', kilogramo: 'kg', unidad: 'un' }
const u = x => U[x] || x || ''

async function cargar() {
  try {
    // Todos, activos y archivados: la solapa «Archivados» los muestra para reactivarlos.
    const [r, i] = await Promise.all([listRecetas(), listInsumos({ tipo: 'cultivo' })])
    recetas.value = r.data || []
    todosInsumos.value = i.data?.insumos || i.data || []
  } catch { toast.error('No se pudieron cargar las recetas') } finally { cargando.value = false }
}
onMounted(cargar)
useRecargaEnCambios(['recetas', 'stocks'], cargar)

// ── Receta ──
const form = ref(null)
const formError = ref(null)
const guardando = ref(false)
const vacio = () => ({ id: null, nombre: '', fase: '', ph_objetivo: null, ec_objetivo: null, notas: '', items: [{ insumo_id: '', dosis: null, unidad: 'ml_l' }] })
function nueva() { formError.value = null; form.value = vacio() }
function editar(r) {
  formError.value = null
  form.value = { id: r.id, nombre: r.nombre, fase: r.fase || '', ph_objetivo: r.ph_objetivo, ec_objetivo: r.ec_objetivo, notas: r.notas || '',
                 items: r.items.map(it => ({ id: it.id, insumo_id: it.insumo_id, dosis: Number(it.dosis), unidad: it.unidad })) }
}
function duplicar(r) {
  formError.value = null
  form.value = { ...vacio(), nombre: `${r.nombre} (copia)`, fase: r.fase || '', ph_objetivo: r.ph_objetivo, ec_objetivo: r.ec_objetivo, notas: r.notas || '',
                 items: r.items.map(it => ({ insumo_id: it.insumo_id, dosis: Number(it.dosis), unidad: it.unidad })) }
}
function agregarItem() { form.value.items.push({ insumo_id: '', dosis: null, unidad: 'ml_l' }) }
function quitarItem(i) { const it = form.value.items[i]; if (it.id) { it._destroy = true; form.value.items = form.value.items.filter(x => x !== it).concat([it]) } else form.value.items.splice(i, 1) }
function cerrar() { form.value = null }
async function guardar() {
  formError.value = null
  const vivos = form.value.items.filter(it => !it._destroy)
  if (!form.value.nombre) { formError.value = 'Ponele un nombre'; return }
  if (!vivos.length || vivos.some(it => !it.insumo_id || !it.dosis)) { formError.value = 'Cada producto lleva su dosis por litro'; return }
  guardando.value = true
  try {
    const payload = { nombre: form.value.nombre, fase: form.value.fase || null, ph_objetivo: form.value.ph_objetivo || null, ec_objetivo: form.value.ec_objetivo || null, notas: form.value.notas || null,
                      receta_items_attributes: form.value.items.map((it, i) => ({ id: it.id, insumo_id: it.insumo_id, dosis: it.dosis, unidad: it.unidad, orden: i, _destroy: it._destroy || false })) }
    if (form.value.id) await updateReceta(form.value.id, payload); else await createReceta(payload)
    toast.success(form.value.id ? 'Receta guardada' : 'Receta creada')
    form.value = null
    await cargar()
  } catch (e) { formError.value = e?.response?.data?.errors?.join(', ') || e?.response?.data?.error || 'No se pudo guardar' }
  finally { guardando.value = false }
}
async function archivar(r) {
  try { await updateReceta(r.id, { activa: !r.activa }); toast.success(r.activa ? 'Receta archivada' : 'Receta reactivada'); await cargar() }
  catch { toast.error('No se pudo') }
}
const uso = ref(null)
async function verUso(r) { try { uso.value = (await getReceta(r.id)).data } catch { toast.error('No se pudo cargar') } }

// ── Nutrientes (uso personal) ──
const nutForm = ref(null)
function nuevoNutriente() { formError.value = null; nutForm.value = { id: null, nombre: '', unidad_medida: 'mililitro', stock_minimo: null, cantidad: null, costo: null } }
function reponer(i) { formError.value = null; nutForm.value = { id: i.id, nombre: i.nombre, unidad_medida: i.unidad_medida, cantidad: null, costo: null } }
async function guardarNutriente() {
  formError.value = null
  guardando.value = true
  try {
    let id = nutForm.value.id
    if (!id) {
      if (!nutForm.value.nombre) { formError.value = 'Ponele un nombre'; return }
      const { data } = await createInsumo({ nombre: nutForm.value.nombre, unidad_medida: nutForm.value.unidad_medida, tipo: 'cultivo', stock_minimo: nutForm.value.stock_minimo || 0 })
      id = data.id ?? data.insumo?.id
    }
    if (nutForm.value.cantidad > 0) {
      // Con precio es una compra (queda como gasto); sin precio, sólo se carga lo que hay.
      await comprarInsumo(id, { cantidad: nutForm.value.cantidad, costo_total_ars: nutForm.value.costo || 0, generar_egreso: !!nutForm.value.costo })
    }
    toast.success(nutForm.value.id ? 'Cargado' : 'Nutriente creado')
    nutForm.value = null
    await cargar()
  } catch (e) { formError.value = e?.response?.data?.errors?.join(', ') || e?.response?.data?.error || 'No se pudo guardar' }
  finally { guardando.value = false }
}
// Editar: nombre, unidad (sólo sin movimientos) y el aviso de «queda poco».
const nutEdit = ref(null)
function editarNutriente(i) {
  formError.value = null
  nutEdit.value = { id: i.id, nombreOriginal: i.nombre, nombre: i.nombre, unidad_medida: i.unidad_medida,
                    stock_minimo: i.stock_minimo || null, con_movimientos: i.con_movimientos }
}
async function guardarEdicionNutriente() {
  formError.value = null
  if (!nutEdit.value.nombre) { formError.value = 'Ponele un nombre'; return }
  guardando.value = true
  try {
    const payload = { nombre: nutEdit.value.nombre, stock_minimo: nutEdit.value.stock_minimo || 0 }
    if (!nutEdit.value.con_movimientos) payload.unidad_medida = nutEdit.value.unidad_medida
    await updateInsumo(nutEdit.value.id, payload)
    toast.success('Nutriente guardado')
    nutEdit.value = null
    await cargar()
  } catch (e) { formError.value = e?.response?.data?.errors?.join(', ') || e?.response?.data?.error || 'No se pudo guardar' }
  finally { guardando.value = false }
}

// Corregir la cantidad: queda como reconteo con motivo, no como un número pisado a mano.
const nutConteo = ref(null)
function corregirNutriente(i) {
  formError.value = null
  nutConteo.value = { id: i.id, nombre: i.nombre, unidad_medida: i.unidad_medida, actual: Number(i.stock_actual), nuevo: Number(i.stock_actual), motivo: 'correccion' }
}
const conteoMermaSube = computed(() => nutConteo.value?.motivo === 'merma' && Number(nutConteo.value.nuevo) > nutConteo.value.actual)
const conteoValido = computed(() => {
  const c = nutConteo.value
  return c && c.nuevo !== '' && c.nuevo != null && Number(c.nuevo) >= 0 && Number(c.nuevo) !== c.actual && !conteoMermaSube.value
})
async function guardarConteo() {
  formError.value = null
  guardando.value = true
  try {
    await reconteoInsumo(nutConteo.value.id, { nuevo_stock: nutConteo.value.nuevo, motivo: nutConteo.value.motivo })
    toast.success('Cantidad corregida')
    nutConteo.value = null
    await cargar()
  } catch (e) { formError.value = e?.response?.data?.error || e?.response?.data?.errors?.join(', ') || 'No se pudo corregir' }
  finally { guardando.value = false }
}

// Eliminar: si nunca se usó, se borra. Si ya se usó o está en una receta, el backend no deja
// (se perdería el historial, o la receta quedaría con un producto menos) y se ofrece archivar.
async function eliminarNutriente(i) {
  const ok = await confirm({ title: `¿Eliminar ${i.nombre}?`, message: 'Si nunca lo usaste, se borra. Si lo compraste con precio, el gasto se anula.', confirmText: 'Eliminar' })
  if (!ok) return
  try {
    await deleteInsumo(i.id)
    toast.success('Nutriente eliminado')
    await cargar()
  } catch (e) {
    const data = e?.response?.data || {}
    if (!data.puede_archivar) { toast.error(data.error || 'No se pudo eliminar'); return }
    const archivar = await confirm({
      title: `${i.nombre} no se puede eliminar`,
      message: `${data.error}\n\nArchivado deja de aparecer en la lista y no se ofrece en recetas nuevas; lo que ya se registró queda como estaba.`,
      confirmText: 'Archivar', variant: 'warning',
    })
    if (!archivar) return
    try {
      await updateInsumo(i.id, { activo: false })
      toast.success('Nutriente archivado')
      await cargar()
    } catch { toast.error('No se pudo archivar') }
  }
}
// Una receta nueva ofrece sólo los que están en uso; una que ya tiene uno archivado lo sigue
// mostrando, o la fila de ese producto quedaba en blanco al editarla.
const opcionesDeReceta = computed(() => {
  const enLaReceta = new Set((form.value?.items || []).map(it => it.insumo_id))
  return todosInsumos.value.filter(i => i.activo !== false || enLaReceta.has(i.id))
})

const reactivando = ref(null)
async function reactivarNutriente(i) {
  reactivando.value = i.id
  try {
    await updateInsumo(i.id, { activo: true })
    toast.success(`${i.nombre} vuelve a estar en uso`)
    await cargar()
    if (!archivados.value.length) solapa.value = 'activos'
  } catch { toast.error('No se pudo reactivar') }
  finally { reactivando.value = null }
}
</script>

<style scoped>
.rc { max-width: 1100px; margin: 0 auto; padding: 1.5rem 1.25rem 3rem; display: flex; flex-direction: column; gap: 1rem; }
.rc__head { display: flex; justify-content: space-between; align-items: flex-start; gap: 1rem; flex-wrap: wrap; }
.rc__head-right { display: flex; gap: .5rem; }
.rc__title { font-size: 1.5rem; font-weight: 800; letter-spacing: -.03em; margin: 0 0 .2rem; }
.rc__sub { margin: 0; color: var(--c-ink-500); font-size: .9rem; max-width: 60ch; }
.rc__btn-primary { display: inline-flex; align-items: center; gap: .4rem; background: var(--c-leaf-800, #1A3D2E); color: #fff; border: 0; border-radius: 10px; padding: .55rem .95rem; font-weight: 700; font-size: .86rem; cursor: pointer; }
.rc__btn-ghost { display: inline-flex; align-items: center; gap: .4rem; background: #fff; color: var(--c-ink-700); border: 1.5px solid var(--c-ink-300); border-radius: 10px; padding: .5rem .8rem; font-weight: 600; font-size: .84rem; cursor: pointer; text-decoration: none; }
.rc__btn-ghost--sm { padding: .35rem .6rem; font-size: .78rem; }
.rc__btn-primary:disabled { opacity: .6; }
.rc__card { background: #fff; border: 1.5px solid var(--c-ink-100); border-radius: 14px; padding: 1rem 1.15rem; }
.rc__card-head { display: flex; justify-content: space-between; gap: 1rem; align-items: flex-start; margin-bottom: .75rem; }
.rc__card-title { margin: 0; font-size: 1rem; font-weight: 800; }
.rc__card-sub { margin: .15rem 0 0; font-size: .8rem; color: var(--c-ink-500); }
.rc__empty { color: var(--c-ink-500); font-size: .9rem; padding: 1rem; text-align: center; }
.rc__nutrientes { display: flex; flex-direction: column; gap: .4rem; }
.rc__nutriente { display: flex; justify-content: space-between; align-items: center; gap: .75rem; padding: .55rem .75rem; border: 1px solid var(--c-ink-100); border-radius: 10px; }
.rc__nutriente--bajo { border-color: #fcd34d; background: #fffbeb; }
.rc__tabs { display: flex; gap: .25rem; border-bottom: 1.5px solid var(--c-ink-100); margin: 0 0 .6rem; }
.rc__tab { background: none; border: 0; border-bottom: 2.5px solid transparent; margin-bottom: -1.5px; padding: .4rem .7rem; font-size: .84rem; font-weight: 600; color: var(--c-ink-500); cursor: pointer; display: inline-flex; align-items: center; gap: .35rem; }
.rc__tab--on { color: var(--c-leaf-800, #1A3D2E); border-bottom-color: var(--c-leaf-800, #1A3D2E); }
.rc__tab-n { background: var(--c-ink-100); color: var(--c-ink-700); border-radius: 999px; padding: 0 .45rem; font-size: .72rem; }
.rc__nutriente--archivado { background: var(--c-ink-100); }
.rc__nutriente--archivado .rc__nutriente-nombre { color: var(--c-ink-700); }
.rc__nutriente-acts { display: flex; align-items: center; gap: .15rem; flex-shrink: 0; }
.rc__icon--danger:hover { background: #fef2f2; color: #dc2626; }
.rc__radio { display: flex; align-items: center; gap: .45rem; font-size: .88rem; cursor: pointer; }
.rc__hint--warn { color: #b45309; font-weight: 600; }
.rc__nutriente-main { display: flex; flex-direction: column; }
.rc__nutriente-nombre { font-weight: 700; }
.rc__nutriente-stock { font-size: .8rem; color: var(--c-ink-500); }
.rc__bajo { color: #b45309; font-weight: 700; }
.rc__grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(300px, 1fr)); gap: .85rem; }
.rc__receta { background: #fff; border: 1.5px solid var(--c-ink-100); border-radius: 14px; padding: 1rem; display: flex; flex-direction: column; gap: .6rem; }
.rc__receta--off { opacity: .6; }
.rc__receta-head { display: flex; justify-content: space-between; gap: .5rem; align-items: flex-start; }
.rc__receta-nombre { margin: 0; font-size: 1.05rem; font-weight: 800; }
.rc__receta-meta { display: flex; gap: .3rem; flex-wrap: wrap; margin-top: .3rem; }
.rc__chip { background: var(--c-leaf-100, #E5EFE9); color: var(--c-leaf-800); border-radius: 999px; padding: .1rem .55rem; font-size: .72rem; font-weight: 700; }
.rc__chip--soft { background: var(--c-ink-100); color: var(--c-ink-700); }
.rc__chip--off { background: #fee2e2; color: #991b1b; }
.rc__receta-acts { display: flex; gap: .2rem; }
.rc__icon { background: none; border: 0; color: var(--c-ink-500); cursor: pointer; font-size: 1rem; padding: .2rem .35rem; border-radius: 6px; }
.rc__icon:hover { background: var(--c-ink-100); color: var(--c-ink-900); }
.rc__items { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: .25rem; }
.rc__items li { display: flex; justify-content: space-between; font-size: .88rem; border-bottom: 1px dashed var(--c-ink-100); padding: .2rem 0; }
.rc__calc { display: flex; flex-direction: column; gap: .3rem; font-size: .82rem; color: var(--c-ink-700); background: var(--c-leaf-50, #F4F8F5); border-radius: 8px; padding: .5rem .65rem; }
.rc__calc-input { width: 64px; border: 1.5px solid var(--c-ink-300); border-radius: 6px; padding: .2rem .4rem; margin: 0 .3rem; }
.rc__calc-res { font-weight: 600; color: var(--c-leaf-800); }
.rc__notas { margin: 0; font-size: .8rem; color: var(--c-ink-500); }
.rc__link { background: none; border: 0; color: var(--c-leaf-700); font-weight: 600; font-size: .82rem; cursor: pointer; padding: 0; text-align: left; display: inline-flex; align-items: center; gap: .3rem; }
.rc__overlay { position: fixed; inset: 0; background: rgba(0,0,0,.5); z-index: 9500; display: flex; align-items: center; justify-content: center; padding: 1rem; }
.rc__modal { background: #fff; border-radius: 14px; width: min(96vw, 620px); max-height: 92vh; display: flex; flex-direction: column; overflow: hidden; }
.rc__modal--sm { width: min(96vw, 480px); }
.rc__modal-head { display: flex; justify-content: space-between; align-items: center; padding: .85rem 1rem; border-bottom: 1px solid var(--c-ink-100); }
.rc__modal-title { margin: 0; font-size: 1rem; }
.rc__modal-body { padding: .9rem 1rem; display: flex; flex-direction: column; gap: .75rem; overflow: auto; }
.rc__modal-foot { display: flex; justify-content: flex-end; gap: .5rem; padding: .75rem 1rem; border-top: 1px solid var(--c-ink-100); }
.rc__x { background: none; border: 0; font-size: 1rem; cursor: pointer; color: var(--c-ink-500); }
.rc__row { display: grid; grid-template-columns: 1fr 1fr; gap: .6rem; }
@media (max-width: 480px) { .rc__row { grid-template-columns: 1fr; } }
.rc__field { display: flex; flex-direction: column; gap: .3rem; }
.rc__field--grow { flex: 1; }
.rc__label { font-size: .7rem; font-weight: 700; text-transform: uppercase; letter-spacing: .04em; color: var(--c-ink-700); }
.rc__opt { font-weight: 500; text-transform: none; letter-spacing: 0; color: var(--c-ink-500); }
.rc__input { border: 1.5px solid var(--c-ink-300); border-radius: 10px; padding: .5rem .7rem; font-size: .88rem; width: 100%; box-sizing: border-box; }
.rc__input--grow { flex: 1; min-width: 0; }
.rc__input--num { width: 90px; }
.rc__input--u { width: 84px; }
.rc__item-row { display: flex; gap: .4rem; align-items: center; margin-bottom: .4rem; }
.rc__hint { font-size: .76rem; color: var(--c-ink-500); }
.rc__error { background: #fee2e2; color: #991b1b; border-radius: 8px; padding: .5rem .7rem; font-size: .84rem; }
.rc__table { width: 100%; border-collapse: collapse; font-size: .84rem; }
.rc__table th, .rc__table td { text-align: left; padding: .4rem .5rem; border-bottom: 1px solid var(--c-ink-100); }
.rc__table th { font-size: .7rem; text-transform: uppercase; letter-spacing: .04em; color: var(--c-ink-500); }
</style>
