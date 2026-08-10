<script setup>
// Selector de bar (Capa 1): lista los bares del club (uno por sede social/mixta) con su
// resultado del mes. Estilo alineado a ContabilidadView.
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useBarStore } from '../../stores/bar.js'
import { useAuthStore } from '../../stores/auth.js'
import { listSedes } from '../../lib/api.js'
import { useToast } from '../../composables/useToast.js'
import { useConfirm } from '../../composables/useConfirm.js'

const store  = useBarStore()
const auth   = useAuthStore()
const router = useRouter()
const toast  = useToast()
const { confirm } = useConfirm()

const esAdmin = computed(() => auth.user?.role === 'admin')
const esGestion = computed(() => ['admin', 'supervisor'].includes(auth.user?.role))
const sedes = ref([])
const form  = ref(null)

const fmt = (n) => `$${Math.round(n || 0).toLocaleString('es-AR')}`
const sedesDisponibles = computed(() => {
  const conBar = new Set(store.bares.map(b => b.sede?.id))
  return sedes.value.filter(s => ['social', 'mixta'].includes(s.tipo) && (form.value?.id || !conBar.has(s.id)))
})

onMounted(async () => {
  await store.fetchBares()
  if (esAdmin.value) listSedes().then(r => { sedes.value = r.data || [] }).catch(() => {})
})

function entrar(bar) { router.push(esGestion.value ? `/bar/${bar.id}/panel` : `/bar/${bar.id}/vender`) }
function nuevo() { form.value = { sede_id: null, nombre: '' } }
function editar(bar) { form.value = { id: bar.id, sede_id: bar.sede?.id, nombre: bar.nombre } }
async function guardar() {
  const f = form.value
  if (!f.nombre?.trim()) { toast.warning('Poné un nombre'); return }
  if (!f.id && !f.sede_id) { toast.warning('Elegí la sede'); return }
  try {
    if (f.id) {
      await store.actualizarBar(f.id, { nombre: f.nombre.trim() })
      toast.success('Bar guardado'); form.value = null
    } else {
      const nuevo = await store.crearBar({ sede_id: f.sede_id, nombre: f.nombre.trim() })
      form.value = null; toast.success('Bar creado')
      if (nuevo?.id) entrar(nuevo) // entra directo al bar real recién creado (evita ids fantasma)
    }
  } catch { toast.error(store.saveError) }
}
async function borrar(bar) {
  if (!(await confirm({ title: 'Eliminar bar', message: `¿Eliminar "${bar.nombre}"? Se puede recuperar desde la papelera.`, variant: 'danger' }))) return
  try { await store.eliminarBar(bar.id); toast.success('Bar eliminado') }
  catch (e) { toast.error(e?.response?.data?.error || 'No se pudo eliminar') }
}
</script>

<template>
  <div class="cv">
    <div class="cv__header">
      <div class="cv__header-left">
        <h1 class="cv__title">Bares</h1>
        <p class="cv__sub">Cada bar vive en su sede, con su caja y su resultado. Elegí uno para gestionarlo.</p>
      </div>
      <div class="cv__header-right">
        <button v-if="esAdmin" class="cv__btn-primary" @click="nuevo">+ Nuevo bar</button>
      </div>
    </div>

    <div v-if="form" class="cv__card cv__card--form">
      <div class="cv__form-row">
        <input v-model.trim="form.nombre" class="cv__filtro-input" placeholder="Nombre (ej: La Terraza)" maxlength="50" />
        <select v-if="!form.id" v-model="form.sede_id" class="cv__filtro-input">
          <option :value="null">— Elegí la sede (social/mixta) —</option>
          <option v-for="s in sedesDisponibles" :key="s.id" :value="s.id">{{ s.nombre }} ({{ s.tipo }})</option>
        </select>
        <div class="cv__form-actions">
          <button class="cv__btn-ghost" @click="form = null">Cancelar</button>
          <button class="cv__btn-primary" :disabled="store.saving" @click="guardar">Guardar</button>
        </div>
      </div>
    </div>

    <div v-if="store.loading" class="cv__empty-sm" style="padding:3rem 0;">Cargando…</div>
    <div v-else-if="!store.bares.length" class="cv__empty-lg">
      Todavía no hay bares.<span v-if="esAdmin"> Creá el primero en una sede social o mixta.</span>
    </div>

    <div v-else class="cv__bars">
      <div v-for="b in store.bares" :key="b.id" class="cv__barcard" :class="{ 'cv__barcard--off': !b.activo }">
        <button class="cv__barcard-body" @click="entrar(b)">
          <div class="cv__barcard-name">{{ b.nombre }}</div>
          <div class="cv__barcard-loc">{{ b.sede?.nombre }} · {{ b.sede?.tipo }}</div>
          <div v-if="b.resultado_mes" class="cv__barcard-res">
            <span class="cv__kpi-label">Resultado del mes</span>
            <strong :class="b.resultado_mes.resultado >= 0 ? 'cv__kpi-val--green' : 'cv__kpi-val--red'">{{ fmt(b.resultado_mes.resultado) }}</strong>
          </div>
        </button>
        <div class="cv__barcard-actions">
          <button class="cv__link" @click="entrar(b)">Entrar →</button>
          <span style="flex:1"></span>
          <button v-if="esAdmin" class="cv__link" @click="editar(b)">Editar</button>
          <button v-if="esAdmin" class="cv__link cv__link--danger" @click="borrar(b)">Borrar</button>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.cv { padding: 2rem 1.75rem 3rem; max-width: 1280px; margin: 0 auto; color: var(--c-slate-900); }
.cv__header { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; flex-wrap: wrap; margin-bottom: 1.75rem; }
.cv__title { font-size: 1.75rem; font-weight: 800; margin: 0 0 .15rem; letter-spacing: -.04em; }
.cv__sub { font-size: .82rem; color: var(--c-slate-500); margin: 0; max-width: 60ch; }

.cv__btn-primary { display: inline-flex; align-items: center; gap: .4rem; background: #1b5e20; color: #fff; border: none; padding: .65rem 1.25rem; border-radius: 10px; font-size: .875rem; font-weight: 600; cursor: pointer; }
.cv__btn-primary:hover:not(:disabled) { background: #144a18; }
.cv__btn-primary:disabled { opacity: .55; cursor: default; }
.cv__btn-ghost { background: #fff; color: var(--c-slate-500); border: 1.5px solid var(--c-slate-200); padding: .65rem 1.1rem; border-radius: 10px; font-size: .875rem; font-weight: 500; cursor: pointer; }
.cv__btn-ghost:hover { border-color: var(--c-slate-300); color: var(--c-slate-700); }

.cv__card--form { background: #fff; border: 1px solid var(--c-slate-200); border-radius: 14px; overflow: hidden; margin-bottom: 1.25rem; }
.cv__form-row { display: flex; gap: .5rem; flex-wrap: wrap; align-items: center; padding: 1rem 1.25rem; }
.cv__form-actions { display: flex; gap: .5rem; margin-left: auto; }
.cv__filtro-input { background: #fff; border: 1.5px solid var(--c-slate-200); border-radius: 9px; padding: .55rem .8rem; font-size: .82rem; color: var(--c-slate-900); min-width: 180px; }
.cv__filtro-input:focus { border-color: #1b5e20; outline: none; }

.cv__empty-sm { color: var(--c-slate-400); font-size: .82rem; text-align: center; }
.cv__empty-lg { color: var(--c-slate-500); font-size: .95rem; text-align: center; padding: 3rem 1rem; background: #fff; border: 1px dashed var(--c-slate-200); border-radius: 14px; }

.cv__bars { display: grid; grid-template-columns: repeat(auto-fill, minmax(260px, 1fr)); gap: 1rem; }
.cv__barcard { background: #fff; border: 1px solid var(--c-slate-200); border-radius: 14px; overflow: hidden; transition: border-color .15s, box-shadow .15s; }
.cv__barcard:hover { border-color: var(--c-slate-300); box-shadow: 0 4px 12px rgb(0 0 0 / .06); }
.cv__barcard--off { opacity: .6; }
.cv__barcard-body { display: block; width: 100%; text-align: left; background: none; border: none; padding: 1.25rem; cursor: pointer; }
.cv__barcard-name { font-size: 1.05rem; font-weight: 700; color: var(--c-slate-900); }
.cv__barcard-loc { font-size: .78rem; color: var(--c-slate-400); margin-top: .1rem; }
.cv__barcard-res { margin-top: 1.1rem; display: flex; flex-direction: column; gap: .2rem; }
.cv__kpi-label { font-size: .68rem; color: var(--c-slate-500); font-weight: 500; text-transform: uppercase; letter-spacing: .04em; }
.cv__barcard-res strong { font-size: 1.7rem; font-weight: 800; letter-spacing: -.03em; }
.cv__kpi-val--green { color: #15803d; } .cv__kpi-val--red { color: #dc2626; }
.cv__barcard-actions { display: flex; align-items: center; gap: .6rem; padding: .7rem 1.25rem; border-top: 1px solid var(--c-slate-100); }
.cv__link { background: none; border: none; color: var(--c-slate-500); font-size: .8rem; font-weight: 600; cursor: pointer; padding: .1rem .35rem; }
.cv__link:hover { color: var(--c-slate-900); }
.cv__link--danger:hover { color: #dc2626; }
</style>
