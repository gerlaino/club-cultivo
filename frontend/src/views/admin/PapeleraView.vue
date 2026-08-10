<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { getPapelera, restaurarPapelera } from '../../lib/api.js'
import { useToast } from '../../composables/useToast.js'
import { useConfirm } from '../../composables/useConfirm.js'
import DsSpinner from '../../design-system/components/Spinner.vue'

const toast = useToast()
const { confirm } = useConfirm()

const filas      = ref([])
const meta       = ref({ total: 0, pagina: 1, limite: 30, por_grupo: {} })
const loading    = ref(true)
const restaurando = ref(null)

const filtros = ref({ q: '', desde: '', hasta: '', pagina: 1 })
let debounce = null

onMounted(cargar)
watch(() => [filtros.value.desde, filtros.value.hasta, filtros.value.pagina], cargar)
watch(() => filtros.value.q, () => {
  clearTimeout(debounce)
  debounce = setTimeout(() => { filtros.value.pagina = 1; cargar() }, 350)
})

async function cargar() {
  loading.value = true
  try {
    const params = { pagina: filtros.value.pagina }
    if (filtros.value.q)     params.q     = filtros.value.q
    if (filtros.value.desde) params.desde = filtros.value.desde
    if (filtros.value.hasta) params.hasta = filtros.value.hasta
    const { data } = await getPapelera(params)
    filas.value = data.data ?? []
    meta.value  = data.meta ?? meta.value
  } catch {
    filas.value = []
    toast.error('No se pudo cargar la papelera')
  } finally {
    loading.value = false
  }
}

const totalPaginas = computed(() => Math.max(1, Math.ceil(meta.value.total / meta.value.limite)))

async function restaurar(fila) {
  if (!fila.restaurable) return
  const ok = await confirm({
    title: `¿Restaurar ${fila.tipo_label.toLowerCase()}?`,
    message: `"${fila.descripcion}" volverá a estar activo junto con su historial.`,
    confirmText: 'Restaurar',
  })
  if (!ok) return

  restaurando.value = `${fila.tipo}-${fila.id}`
  try {
    const { data } = await restaurarPapelera(fila.tipo, fila.id)
    toast.success(data.mensaje || 'Restaurado')
    await cargar()
  } catch (e) {
    const resp = e?.response?.data
    const conflictos = resp?.conflictos
    if (conflictos?.length) {
      // Bloqueo por conflictos con el estado actual: mostramos el motivo exacto.
      conflictos.forEach(c => toast.error(c.mensaje, { timeout: 7000 }))
    } else {
      toast.error(resp?.error || 'No se pudo restaurar')
    }
  } finally {
    restaurando.value = null
  }
}

function limpiar() {
  filtros.value = { q: '', desde: '', hasta: '', pagina: 1 }
  cargar()
}

const hayFiltros = computed(() => filtros.value.q || filtros.value.desde || filtros.value.hasta)

function formatFecha(ts) {
  if (!ts) return '—'
  return new Date(ts).toLocaleString('es-AR', { day: '2-digit', month: '2-digit', year: '2-digit', hour: '2-digit', minute: '2-digit' })
}
</script>

<template>
  <div class="pap">
    <div class="pap__header">
      <div>
        <h1 class="pap__title">Papelera</h1>
        <p class="pap__sub">Historial de borrados. Restaurá lo eliminado por error junto con su historial.</p>
      </div>
    </div>

    <!-- Filtros -->
    <div class="pap__filtros">
      <div class="pap__search">
        <i class="bi bi-search"></i>
        <input v-model="filtros.q" type="text" placeholder="Buscar por nombre, código…" />
      </div>
      <label class="pap__fecha">
        <span>Desde</span>
        <input v-model="filtros.desde" type="date" />
      </label>
      <label class="pap__fecha">
        <span>Hasta</span>
        <input v-model="filtros.hasta" type="date" />
      </label>
      <button v-if="hayFiltros" class="pap__clear" @click="limpiar">
        <i class="bi bi-x-lg"></i> Limpiar
      </button>
    </div>

    <div v-if="loading" class="pap__loading"><DsSpinner /></div>

    <div v-else-if="!filas.length" class="pap__empty">
      <i class="bi bi-trash3"></i>
      <p>{{ hayFiltros ? 'Sin resultados para el filtro.' : 'La papelera está vacía.' }}</p>
    </div>

    <div v-else class="pap__table-wrap">
      <table class="pap__table">
        <thead>
          <tr>
            <th>Tipo</th>
            <th>Descripción</th>
            <th>Grupo</th>
            <th>Borrado</th>
            <th>Por</th>
            <th></th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="f in filas" :key="`${f.tipo}-${f.id}`">
            <td><span class="pap__badge">{{ f.tipo_label }}</span></td>
            <td class="pap__desc">{{ f.descripcion }}</td>
            <td class="pap__muted">{{ f.grupo }}</td>
            <td class="pap__muted">{{ formatFecha(f.deleted_at) }}</td>
            <td class="pap__muted">{{ f.deleted_by || '—' }}</td>
            <td class="pap__td-accion">
              <button
                v-if="f.restaurable"
                class="pap__btn-restaurar"
                :disabled="restaurando === `${f.tipo}-${f.id}`"
                @click="restaurar(f)">
                <i class="bi bi-arrow-counterclockwise"></i> Restaurar
              </button>
              <span v-else class="pap__pendiente" title="Restauración con validación de conflictos — próximamente">
                <i class="bi bi-shield-lock"></i> Con validación
              </span>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <div v-if="totalPaginas > 1" class="pap__pagination">
      <button :disabled="filtros.pagina <= 1" @click="filtros.pagina--">‹</button>
      <span>{{ filtros.pagina }} / {{ totalPaginas }}</span>
      <button :disabled="filtros.pagina >= totalPaginas" @click="filtros.pagina++">›</button>
    </div>
  </div>
</template>

<style scoped>
.pap { padding: 1.5rem; max-width: 1100px; margin: 0 auto; }
.pap__header { margin-bottom: 1.25rem; }
.pap__title { font-size: 1.4rem; font-weight: 700; color: #1e293b; margin: 0; }
.pap__sub { color: var(--c-slate-500); font-size: .88rem; margin: .25rem 0 0; }

.pap__filtros { display: flex; gap: .75rem; align-items: flex-end; flex-wrap: wrap; margin-bottom: 1.25rem; }
.pap__search { position: relative; flex: 1; min-width: 220px; }
.pap__search i { position: absolute; left: .7rem; top: 50%; transform: translateY(-50%); color: var(--c-slate-400); }
.pap__search input { width: 100%; padding: .55rem .75rem .55rem 2rem; border: 1px solid var(--c-slate-200); border-radius: 8px; font-size: .88rem; }
.pap__fecha { display: flex; flex-direction: column; gap: .2rem; font-size: .72rem; color: var(--c-slate-500); }
.pap__fecha input { padding: .45rem .6rem; border: 1px solid var(--c-slate-200); border-radius: 8px; font-size: .85rem; }
.pap__clear { background: var(--c-slate-50); border: 1px solid var(--c-slate-200); border-radius: 8px; padding: .5rem .8rem; font-size: .82rem; color: var(--c-slate-600); cursor: pointer; }
.pap__clear:hover { background: var(--c-slate-100); }

.pap__loading, .pap__empty { text-align: center; padding: 3rem 1rem; color: var(--c-slate-400); }
.pap__empty i { font-size: 2.2rem; display: block; margin-bottom: .5rem; }
.pap__empty p { margin: 0; font-size: .9rem; }

.pap__table-wrap { border: 1px solid var(--c-slate-200); border-radius: 12px; overflow: hidden; }
.pap__table { width: 100%; border-collapse: collapse; font-size: .86rem; }
.pap__table thead th { background: var(--c-slate-50); text-align: left; padding: .65rem .9rem; font-size: .72rem; text-transform: uppercase; letter-spacing: .03em; color: var(--c-slate-500); border-bottom: 1px solid var(--c-slate-200); }
.pap__table tbody td { padding: .7rem .9rem; border-bottom: 1px solid var(--c-slate-100); vertical-align: middle; }
.pap__table tbody tr:last-child td { border-bottom: none; }
.pap__badge { display: inline-block; background: #eff6ff; color: #2563eb; border-radius: 6px; padding: .15rem .5rem; font-size: .76rem; font-weight: 600; }
.pap__desc { font-weight: 500; color: #1e293b; }
.pap__muted { color: var(--c-slate-500); }
.pap__td-accion { text-align: right; white-space: nowrap; }
.pap__btn-restaurar { display: inline-flex; align-items: center; gap: .35rem; background: #16a34a; border: 1px solid #16a34a; color: #fff; border-radius: 7px; padding: .4rem .75rem; font-size: .8rem; font-weight: 600; cursor: pointer; transition: all .15s; }
.pap__btn-restaurar:hover { background: #15803d; }
.pap__btn-restaurar:disabled { opacity: .6; cursor: default; }
.pap__pendiente { display: inline-flex; align-items: center; gap: .35rem; color: var(--c-slate-400); font-size: .78rem; }

.pap__pagination { display: flex; align-items: center; justify-content: center; gap: 1rem; margin-top: 1.25rem; color: var(--c-slate-600); font-size: .85rem; }
.pap__pagination button { background: var(--c-slate-50); border: 1px solid var(--c-slate-200); border-radius: 7px; width: 32px; height: 32px; cursor: pointer; font-size: 1rem; }
.pap__pagination button:disabled { opacity: .4; cursor: default; }
</style>
