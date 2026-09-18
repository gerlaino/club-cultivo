<script setup>
// Solapa «Direcciones» de la ficha (Germán, 17-sep-2026): todas las direcciones de entrega del
// paciente, con nombre, agregar / corregir / borrar, y una POR DEFECTO que el modal de dispensa
// preselecciona. El domicilio REPROCANN se muestra arriba pero se edita con la ficha: es del
// trámite, no una dirección más.
import { ref, computed, onMounted } from 'vue'
import { useToast } from '../../composables/useToast.js'
import { useConfirm } from '../../composables/useConfirm.js'
import { getDireccionesPaciente, crearDireccionPaciente, editarDireccionPaciente, borrarDireccionPaciente, direccionPorDefecto } from '../../lib/api.js'
import { MapPin, House, Plus, Pencil, Trash2, Star } from 'lucide-vue-next'

const props = defineProps({ socioId: { type: Number, required: true } })
const { success: toastOk, error: toastErr } = useToast()
const { confirm } = useConfirm()

const datos    = ref({ domicilio: null, guardadas: [] })
const cargando = ref(true)

async function cargar() {
  try {
    const { data } = await getDireccionesPaciente(props.socioId)
    datos.value = data
  } catch { toastErr('No se pudieron cargar las direcciones') }
  finally { cargando.value = false }
}
onMounted(cargar)

const guardadas = computed(() => datos.value.guardadas || [])

// ── Alta / edición (mismo formulario) ──
const vacia = () => ({ id: null, etiqueta: '', calle: '', altura: '', piso: '', depto: '', barrio: '', ciudad: '', por_defecto: false })
const form     = ref(null)
const guardando = ref(false)
const formError = ref('')

function nueva() { formError.value = ''; form.value = { ...vacia(), por_defecto: !guardadas.value.length } }
function editar(d) { formError.value = ''; form.value = { ...vacia(), ...d } }
function cancelar() { form.value = null }

async function guardar() {
  const f = form.value
  if (!f.calle?.trim() || !f.altura?.trim() || !f.ciudad?.trim()) { formError.value = 'Completá calle, altura y ciudad.'; return }
  guardando.value = true
  formError.value = ''
  const payload = { etiqueta: f.etiqueta || null, calle: f.calle, altura: f.altura, piso: f.piso || null, depto: f.depto || null,
                    barrio: f.barrio || null, ciudad: f.ciudad, por_defecto: f.por_defecto }
  try {
    if (f.id) await editarDireccionPaciente(props.socioId, f.id, payload)
    else      await crearDireccionPaciente(props.socioId, payload)
    form.value = null
    await cargar()
    toastOk(f.id ? 'Dirección corregida' : 'Dirección agregada')
  } catch (e) {
    formError.value = e?.response?.data?.errors?.join(', ') || e?.response?.data?.error || 'No se pudo guardar'
  } finally { guardando.value = false }
}

async function marcarPorDefecto(d) {
  try {
    await direccionPorDefecto(props.socioId, d.id)
    await cargar()
    toastOk(`«${d.etiqueta || d.texto}» es ahora la dirección por defecto`)
  } catch (e) { toastErr(e?.response?.data?.error || 'No se pudo cambiar') }
}

async function borrar(d) {
  const ok = await confirm({
    title: `Borrar «${d.etiqueta || d.texto}»`,
    message: 'Las dispensas que ya salieron a esta dirección no cambian: el paquete guarda su propia copia.',
    confirmText: 'Borrar', variant: 'danger',
  })
  if (!ok) return
  try {
    await borrarDireccionPaciente(props.socioId, d.id)
    await cargar()
  } catch (e) { toastErr(e?.response?.data?.error || 'No se pudo borrar') }
}
</script>

<template>
  <div class="std">
    <!-- El domicilio del trámite: se ve, se edita en la ficha. -->
    <div class="std__card">
      <div class="std__hd">
        <div class="std__hd-ico"><House :size="15" /></div>
        <div>
          <div class="std__title">Domicilio REPROCANN</div>
          <div class="std__sub">El del trámite. Se corrige editando la ficha.</div>
        </div>
      </div>
      <div v-if="datos.domicilio" class="std__dir-texto">{{ datos.domicilio.texto }}</div>
      <div v-else class="std__vacio">Sin domicilio cargado en la ficha.</div>
    </div>

    <div class="std__card">
      <div class="std__hd">
        <div class="std__hd-ico"><MapPin :size="15" /></div>
        <div>
          <div class="std__title">Direcciones de entrega</div>
          <div class="std__sub">A dónde se le mandan los paquetes. La <strong>por defecto</strong> es la que aparece elegida al dispensar.</div>
        </div>
        <button v-if="!form" type="button" class="std__btn std__btn--primary" @click="nueva">
          <Plus :size="14" :stroke-width="2.5" /> Agregar
        </button>
      </div>

      <div v-if="cargando" class="std__vacio">Cargando…</div>
      <div v-else-if="!guardadas.length && !form" class="std__vacio">
        Todavía no tiene ninguna. Agregá una, o cargala al dispensar con «Otra dirección» y «guardar en la ficha».
      </div>

      <ul v-if="guardadas.length" class="std__list">
        <li v-for="d in guardadas" :key="d.id" class="std__item" :class="{ 'std__item--def': d.por_defecto }">
          <div class="std__item-txt">
            <div class="std__item-top">
              <span class="std__etq">{{ d.etiqueta || 'Sin nombre' }}</span>
              <span v-if="d.por_defecto" class="std__def"><Star :size="11" :stroke-width="2.5" /> Por defecto</span>
            </div>
            <div class="std__dir-texto">{{ d.texto }}</div>
          </div>
          <div class="std__acts">
            <button v-if="!d.por_defecto" type="button" class="std__btn" title="Usar por defecto" @click="marcarPorDefecto(d)">
              <Star :size="13" /> Usar por defecto
            </button>
            <button type="button" class="std__btn std__btn--ico" title="Corregir" @click="editar(d)"><Pencil :size="13" /></button>
            <button type="button" class="std__btn std__btn--ico std__btn--danger" title="Borrar" @click="borrar(d)"><Trash2 :size="13" /></button>
          </div>
        </li>
      </ul>

      <!-- Alta / edición -->
      <form v-if="form" class="std__form" @submit.prevent="guardar">
        <div class="std__form-title">{{ form.id ? 'Corregir dirección' : 'Nueva dirección' }}</div>
        <div v-if="formError" class="std__error">{{ formError }}</div>
        <div class="std__grid">
          <label class="std__field std__field--full">
            <span class="std__lbl">Nombre <span class="std__opt">ej. Trabajo, casa de la madre</span></span>
            <input v-model.trim="form.etiqueta" class="std__input" placeholder="Trabajo" maxlength="60" />
          </label>
          <label class="std__field std__field--2">
            <span class="std__lbl">Calle *</span>
            <input v-model.trim="form.calle" class="std__input" placeholder="Av. Siempreviva" />
          </label>
          <label class="std__field">
            <span class="std__lbl">Altura *</span>
            <input v-model.trim="form.altura" class="std__input" placeholder="742" />
          </label>
          <label class="std__field">
            <span class="std__lbl">Piso</span>
            <input v-model.trim="form.piso" class="std__input" placeholder="3" />
          </label>
          <label class="std__field">
            <span class="std__lbl">Depto</span>
            <input v-model.trim="form.depto" class="std__input" placeholder="B" />
          </label>
          <label class="std__field">
            <span class="std__lbl">Barrio</span>
            <input v-model.trim="form.barrio" class="std__input" placeholder="Palermo" />
          </label>
          <label class="std__field std__field--2">
            <span class="std__lbl">Ciudad *</span>
            <input v-model.trim="form.ciudad" class="std__input" placeholder="CABA" />
          </label>
          <label class="std__check std__field--full">
            <input v-model="form.por_defecto" type="checkbox" /> Usar por defecto al dispensar
          </label>
        </div>
        <div class="std__form-acts">
          <button type="button" class="std__btn" :disabled="guardando" @click="cancelar">Cancelar</button>
          <button type="submit" class="std__btn std__btn--primary" :disabled="guardando">{{ guardando ? 'Guardando…' : 'Guardar' }}</button>
        </div>
      </form>
    </div>
  </div>
</template>

<style scoped>
.std { display: flex; flex-direction: column; gap: 1rem; }
.std__card { background: #fff; border: 1px solid var(--c-slate-200); border-radius: 12px; padding: 1.25rem; }
.std__hd { display: flex; align-items: flex-start; gap: .7rem; margin-bottom: 1rem; }
.std__hd-ico { width: 30px; height: 30px; border-radius: 8px; flex-shrink: 0; display: flex; align-items: center; justify-content: center; background: var(--c-slate-100); color: var(--c-slate-600); }
.std__title { font-size: .95rem; font-weight: 700; color: var(--c-slate-900); }
.std__sub { font-size: .78rem; color: var(--c-slate-500); }
.std__hd > .std__btn { margin-left: auto; }
.std__dir-texto { font-size: .9rem; color: var(--c-slate-800); }
.std__vacio { font-size: .82rem; color: var(--c-slate-500); }
.std__list { list-style: none; margin: 0; padding: 0; display: grid; gap: .5rem; }
.std__item { display: flex; align-items: center; gap: .75rem; padding: .7rem .85rem; border: 1.5px solid var(--c-slate-200); border-radius: 10px; }
.std__item--def { border-color: #15803d; background: #f0fdf4; }
.std__item-txt { min-width: 0; flex: 1; display: grid; gap: .15rem; }
.std__item-top { display: flex; align-items: center; gap: .5rem; }
.std__etq { font-size: .84rem; font-weight: 700; color: var(--c-slate-900); }
.std__def { display: inline-flex; align-items: center; gap: .25rem; font-size: .66rem; font-weight: 800; text-transform: uppercase; letter-spacing: .04em; color: #15803d; }
.std__acts { display: flex; gap: .35rem; flex-shrink: 0; }
.std__btn { display: inline-flex; align-items: center; gap: .35rem; padding: .4rem .7rem; border: 1.5px solid var(--c-slate-200); border-radius: 8px; background: #fff; font-size: .78rem; font-weight: 600; color: var(--c-slate-700); cursor: pointer; }
.std__btn:hover:not(:disabled) { border-color: var(--c-slate-400); }
.std__btn:disabled { opacity: .55; cursor: not-allowed; }
.std__btn--ico { padding: .4rem .5rem; }
.std__btn--danger { color: #b91c1c; }
.std__btn--primary { background: #1b5e20; border-color: #1b5e20; color: #fff; }
.std__btn--primary:hover:not(:disabled) { background: #166534; }
.std__form { margin-top: 1rem; padding: 1rem; border: 1px dashed var(--c-slate-300); border-radius: 10px; display: grid; gap: .75rem; }
.std__form-title { font-size: .82rem; font-weight: 700; color: var(--c-slate-800); }
.std__error { font-size: .8rem; color: #b91c1c; }
.std__grid { display: grid; grid-template-columns: repeat(4, 1fr); gap: .6rem; }
.std__field { display: flex; flex-direction: column; gap: .25rem; }
.std__field--2 { grid-column: span 2; }
.std__field--full { grid-column: 1 / -1; }
.std__lbl { font-size: .68rem; font-weight: 700; text-transform: uppercase; letter-spacing: .05em; color: var(--c-slate-600); }
.std__opt { font-weight: 500; text-transform: none; letter-spacing: 0; color: var(--c-slate-400); }
.std__input { border: 1.5px solid var(--c-slate-200); border-radius: 8px; padding: .5rem .65rem; font-size: .86rem; color: var(--c-slate-900); outline: none; }
.std__input:focus { border-color: #15803d; box-shadow: 0 0 0 3px rgba(21,128,61,.1); }
.std__check { display: inline-flex; align-items: center; gap: .4rem; font-size: .8rem; color: var(--c-slate-700); cursor: pointer; }
.std__form-acts { display: flex; justify-content: flex-end; gap: .5rem; }
@media (max-width: 640px) {
  .std__grid { grid-template-columns: 1fr 1fr; }
  .std__item { flex-wrap: wrap; }
}
</style>
