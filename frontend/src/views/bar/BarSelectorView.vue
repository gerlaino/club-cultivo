<script setup>
// Selector de bar (Capa 1): lista los bares del club (uno por sede social/mixta) con su
// resultado del mes. Elegís uno para entrar. El admin puede crear/editar/borrar bares.
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
const form  = ref(null) // { id?, sede_id, nombre }

const fmt = (n) => `$${Math.round(n || 0).toLocaleString('es-AR')}`
// Sedes social/mixta sin bar todavía (para el alta)
const sedesDisponibles = computed(() => {
  const conBar = new Set(store.bares.map(b => b.sede?.id))
  return sedes.value.filter(s => ['social', 'mixta'].includes(s.tipo) && (form.value?.id || !conBar.has(s.id)))
})

onMounted(async () => {
  await store.fetchBares()
  if (esAdmin.value) listSedes().then(r => { sedes.value = r.data || [] }).catch(() => {})
})

function entrar(bar) {
  const destino = esGestion.value ? `/bar/${bar.id}/panel` : `/bar/${bar.id}/vender`
  router.push(destino)
}

function nuevo() { form.value = { sede_id: null, nombre: '' } }
function editar(bar) { form.value = { id: bar.id, sede_id: bar.sede?.id, nombre: bar.nombre } }
async function guardar() {
  const f = form.value
  if (!f.nombre?.trim()) { toast.warning('Poné un nombre'); return }
  if (!f.id && !f.sede_id) { toast.warning('Elegí la sede'); return }
  try {
    if (f.id) await store.actualizarBar(f.id, { nombre: f.nombre.trim() })
    else      await store.crearBar({ sede_id: f.sede_id, nombre: f.nombre.trim() })
    toast.success('Bar guardado'); form.value = null
  } catch { toast.error(store.saveError) }
}
async function borrar(bar) {
  if (!(await confirm({ title: 'Eliminar bar', message: `¿Eliminar "${bar.nombre}"? Se puede recuperar desde la papelera.`, variant: 'danger' }))) return
  try { await store.eliminarBar(bar.id); toast.success('Bar eliminado') }
  catch (e) { toast.error(e?.response?.data?.error || 'No se pudo eliminar') }
}
</script>

<template>
  <div class="bs">
    <header class="bs__head">
      <div>
        <h1>Bares</h1>
        <p>Cada bar vive en su sede, con su caja y su resultado. Elegí uno para gestionarlo.</p>
      </div>
      <button v-if="esAdmin" class="btn btn--primary" @click="nuevo">+ Nuevo bar</button>
    </header>

    <form v-if="form" class="bs__form" @submit.prevent="guardar">
      <input v-model.trim="form.nombre" class="inp" placeholder="Nombre (ej: La Terraza)" maxlength="50" />
      <select v-if="!form.id" v-model="form.sede_id" class="inp">
        <option :value="null">— Elegí la sede (social/mixta) —</option>
        <option v-for="s in sedesDisponibles" :key="s.id" :value="s.id">{{ s.nombre }} ({{ s.tipo }})</option>
      </select>
      <div class="bs__form-actions">
        <button type="button" class="btn" @click="form = null">Cancelar</button>
        <button type="submit" class="btn btn--primary" :disabled="store.saving">Guardar</button>
      </div>
    </form>

    <div v-if="store.loading" class="bs__loading">Cargando…</div>
    <div v-else-if="!store.bares.length" class="bs__empty">
      Todavía no hay bares.<span v-if="esAdmin"> Creá el primero en una sede social o mixta.</span>
    </div>

    <div v-else class="bs__grid">
      <div v-for="b in store.bares" :key="b.id" class="barcard" :class="{ 'is-off': !b.activo }">
        <div class="barcard__top" @click="entrar(b)">
          <div class="barcard__name">🍺 {{ b.nombre }}</div>
          <div class="barcard__loc">{{ b.sede?.nombre }} · {{ b.sede?.tipo }}</div>
          <div class="barcard__res" v-if="b.resultado_mes">
            <span class="barcard__res-l">Resultado del mes</span>
            <strong :class="b.resultado_mes.resultado >= 0 ? 'pos' : 'neg'">{{ fmt(b.resultado_mes.resultado) }}</strong>
          </div>
        </div>
        <div class="barcard__actions">
          <button class="lnk" @click="entrar(b)">Entrar →</button>
          <span class="barcard__spacer"></span>
          <button v-if="esAdmin" class="lnk" @click="editar(b)">Editar</button>
          <button v-if="esAdmin" class="lnk lnk--danger" @click="borrar(b)">Borrar</button>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.bs { padding: var(--sp-6, 24px); max-width: 960px; margin: 0 auto; }
.bs__head { display: flex; align-items: flex-start; justify-content: space-between; gap: var(--sp-3, 12px); }
.bs__head h1 { font-size: var(--fs-24, 24px); font-weight: 700; color: var(--c-ink-900); margin: 0; }
.bs__head p { color: var(--c-ink-500); margin: 4px 0 0; font-size: var(--fs-14, 14px); }
.bs__form { display: flex; gap: 8px; flex-wrap: wrap; align-items: center; background: var(--c-ink-50, #f6f7f5); border: 1px solid var(--c-ink-100); border-radius: var(--r-md, 10px); padding: var(--sp-3, 12px); margin-top: var(--sp-4, 16px); }
.bs__form-actions { display: flex; gap: 8px; margin-left: auto; }
.bs__loading, .bs__empty { color: var(--c-ink-500); padding: var(--sp-8, 32px); text-align: center; }

.bs__grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(240px, 1fr)); gap: 14px; margin-top: var(--sp-5, 20px); }
.barcard { background: var(--c-paper, #fff); border: 1px solid var(--c-ink-100); border-radius: var(--r-lg, 14px); box-shadow: var(--sh-1); overflow: hidden; }
.barcard.is-off { opacity: .6; }
.barcard__top { padding: 18px; cursor: pointer; }
.barcard__name { font-weight: 650; font-size: 1.05rem; color: var(--c-ink-900); }
.barcard__loc { font-size: .8rem; color: var(--c-ink-400); margin-top: 2px; }
.barcard__res { margin-top: 16px; }
.barcard__res-l { display: block; font-size: .68rem; text-transform: uppercase; letter-spacing: .05em; color: var(--c-ink-400); }
.barcard__res strong { font-size: 1.6rem; font-weight: 700; letter-spacing: -.02em; }
.barcard__res .pos { color: var(--c-leaf-700, #2f6b3d); }
.barcard__res .neg { color: var(--c-rust-600, #b23b2e); }
.barcard__actions { display: flex; align-items: center; gap: 10px; padding: 10px 16px; border-top: 1px solid var(--c-ink-100); }
.barcard__spacer { flex: 1; }
.lnk { background: none; border: none; color: var(--c-ink-600); font-size: var(--fs-13, 13px); cursor: pointer; font-weight: 600; padding: 2px 4px; }
.lnk:hover { color: var(--c-ink-900); }
.lnk--danger:hover { color: var(--c-rust-600, #b23b2e); }

.inp { padding: 8px 10px; border: 1px solid var(--c-ink-200); border-radius: var(--r-sm, 8px); font-size: var(--fs-14, 14px); background: var(--c-paper, #fff); color: var(--c-ink-900); }
.btn { border: 1px solid var(--c-ink-200); background: var(--c-paper, #fff); color: var(--c-ink-800); border-radius: var(--r-sm, 8px); padding: 8px 14px; font-size: var(--fs-13, 13px); font-weight: 600; cursor: pointer; }
.btn--primary { background: var(--c-leaf-700, #2f6b3d); border-color: var(--c-leaf-700, #2f6b3d); color: #fff; }
.btn:disabled { opacity: .5; cursor: default; }
</style>
