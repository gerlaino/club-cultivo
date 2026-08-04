<template>
  <div class="mdis">
    <!-- Buscar es LO PRIMERO: el dispensador está de pie con alguien enfrente, no navegando. -->
    <div class="mdis__search-wrap">
      <input
        ref="inputBuscar"
        v-model.trim="query"
        type="search"
        class="mdis__search"
        placeholder="Nombre o DNI…"
        autocomplete="off"
      />
      <button class="mdis__scan" title="Escanear el carnet del paciente" @click="router.push('/m/scan')">
        <i class="bi bi-qr-code-scan"></i>
      </button>
    </div>

    <div v-if="loading" class="mdis__muted">Cargando…</div>

    <div v-else-if="!pacientes.length" class="mdis__empty">
      <span class="mdis__empty-ico">👤</span>
      <p v-if="query">Ningún paciente coincide con «{{ query }}».</p>
      <p v-else>Todavía no hay pacientes cargados.</p>
    </div>

    <div v-else class="mdis__list">
      <button
        v-for="p in pacientes" :key="p.id"
        class="mdis__card"
        @click="abrir(p)"
      >
        <div class="mdis__card-main">
          <div class="mdis__card-nombre">{{ p.nombre }} {{ p.apellido }}</div>
          <div class="mdis__card-meta">
            <span>{{ p.dni || '—' }}</span>
            <span v-if="p.ultima_dispensacion" class="mdis__card-ultima">
              · última {{ fechaCorta(p.ultima_dispensacion) }}
            </span>
          </div>
        </div>
        <i class="bi bi-chevron-right mdis__card-arr"></i>
      </button>
    </div>

    <!-- Ficha corta: lo mínimo para decidir, sin abrir la ficha completa -->
    <SheetBottom v-model="fichaOpen" :title="seleccionado ? `${seleccionado.nombre} ${seleccionado.apellido}` : ''">
      <div v-if="seleccionado" class="mdis__sheet">
        <div class="mdis__datos">
          <div class="mdis__dato">
            <span class="mdis__dato-lbl">DNI</span>
            <span class="mdis__dato-val">{{ seleccionado.dni || '—' }}</span>
          </div>
          <!-- El crédito SÍ le corresponde: es lo que define si puede llevarse algo sin pagar. -->
          <div v-if="ficha?.limite_cc" class="mdis__dato">
            <span class="mdis__dato-lbl">Crédito</span>
            <span class="mdis__dato-val" :class="{ 'mdis__dato-val--rojo': saldoNegativo }">
              {{ fmtARS(ficha.saldo_cc) }} <small>de {{ fmtARS(ficha.limite_cc) }}</small>
            </span>
          </div>
          <div v-if="ficha?.descuento_porcentaje" class="mdis__dato">
            <span class="mdis__dato-lbl">Descuento</span>
            <span class="mdis__dato-val">{{ ficha.descuento_porcentaje }}%</span>
          </div>
        </div>

        <div v-if="ultimas.length" class="mdis__ultimas">
          <div class="mdis__ultimas-tit">Se llevó</div>
          <div v-for="d in ultimas" :key="d.id" class="mdis__ultima-row">
            <span>{{ fechaCorta(d.fecha_dispensacion) }}</span>
            <span class="mdis__ultima-prod">{{ d.cantidad }}{{ d.stock?.unidad || 'g' }} {{ formaLabel(d.stock?.forma_producto) }}</span>
          </div>
        </div>

        <button class="mdis__btn" @click="dispensar">
          <i class="bi bi-bag-plus"></i> Dispensar
        </button>
      </div>
    </SheetBottom>

    <ModalNuevaDispensacion
      v-if="seleccionado"
      v-model="dispensaOpen"
      :socio-id="seleccionado.id"
      :paciente-nombre="`${seleccionado.nombre} ${seleccionado.apellido}`"
      :saldo-cc="ficha?.saldo_cc"
      :limite-cc="ficha?.limite_cc"
      :descuento-porcentaje="ficha?.descuento_porcentaje || 0"
      @created="onDispensado"
    />
  </div>
</template>

<script setup>
import { ref, computed, watch, onMounted } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { listPacientes, getPaciente, listDispensaciones, getPacientePorCarnet } from '../../lib/api.js'
import { formaLabel, formatARS } from '../../lib/formatters.js'
import SheetBottom from '../../components/cultivador/SheetBottom.vue'
import ModalNuevaDispensacion from '../../components/pacientes/ModalNuevaDispensacion.vue'
import { useToast } from '../../composables/useToast.js'

const router = useRouter()
const route  = useRoute()
const toast  = useToast()

const query     = ref('')
const loading   = ref(false)
const pacientes = ref([])
const inputBuscar = ref(null)

const fichaOpen    = ref(false)
const dispensaOpen = ref(false)
const seleccionado = ref(null)
const ficha        = ref(null)
const ultimas      = ref([])

const saldoNegativo = computed(() => Number(ficha.value?.saldo_cc ?? 0) < 0)

let t = null
watch(query, () => { clearTimeout(t); t = setTimeout(buscar, 300) })
onMounted(() => {
  buscar()
  // Si se llegó escaneando un carnet, se abre esa ficha directo: el que escanea ya tiene a la
  // persona enfrente y no debería volver a buscarla en la lista.
  if (route.query.carnet) abrirPorCarnet(String(route.query.carnet))
  else inputBuscar.value?.focus()
})

async function abrirPorCarnet(token) {
  try {
    const { data } = await getPacientePorCarnet(token)
    const p = data.data ?? data
    if (p?.id) { await abrir(p); return }
  } catch {
    toast.error('Ese carnet no es de este club')
  }
  // La URL se limpia igual: si se recarga la pantalla, no vuelve a abrir la misma ficha sola.
  router.replace('/m/dispensar')
}

async function buscar() {
  loading.value = true
  try {
    const params = { limite: 60, orden: 'apellido', dir: 'asc' }
    if (query.value) params.query = query.value
    const { data } = await listPacientes(params)
    pacientes.value = data.data ?? []
  } catch { pacientes.value = [] } finally { loading.value = false }
}

async function abrir(p) {
  seleccionado.value = p
  ficha.value = null
  ultimas.value = []
  fichaOpen.value = true
  try {
    const { data } = await getPaciente(p.id)
    ficha.value = data.data ?? data
  } catch {}
  try {
    const { data } = await listDispensaciones({ paciente_id: p.id, limite: 3 })
    ultimas.value = (data.data ?? data ?? []).slice(0, 3)
  } catch {}
}

function dispensar() {
  fichaOpen.value = false
  dispensaOpen.value = true
}

function onDispensado() {
  dispensaOpen.value = false
  toast.success('Dispensación registrada')
  buscar()
}

function fmtARS(v) { return v == null ? '—' : formatARS(v) }
function fechaCorta(f) {
  if (!f) return ''
  const d = new Date(f)
  return `${String(d.getDate()).padStart(2, '0')}/${String(d.getMonth() + 1).padStart(2, '0')}`
}
</script>

<style scoped>
.mdis { padding: .75rem; display: flex; flex-direction: column; gap: .75rem; }

.mdis__search-wrap { display: flex; gap: .5rem; }
.mdis__search {
  flex: 1; border: 1px solid var(--c-ink-200, #e2e8f0); border-radius: 12px;
  padding: .75rem .9rem; font-size: 1rem; box-sizing: border-box;
}
.mdis__search:focus { outline: none; border-color: var(--c-leaf-600, #16a34a); }
.mdis__scan {
  border: 1px solid var(--c-ink-200, #e2e8f0); background: #fff; border-radius: 12px;
  width: 48px; font-size: 1.15rem; color: var(--c-ink-600, #475569); cursor: pointer;
}

.mdis__muted { color: var(--c-ink-400, #94a3b8); font-size: .85rem; padding: 1rem 0; text-align: center; }
.mdis__empty { text-align: center; padding: 2rem 1rem; color: var(--c-ink-500, #64748b); }
.mdis__empty-ico { font-size: 2rem; display: block; margin-bottom: .5rem; }

.mdis__list { display: flex; flex-direction: column; gap: .4rem; }
.mdis__card {
  display: flex; align-items: center; gap: .6rem; width: 100%;
  background: #fff; border: 1px solid var(--c-ink-100, #f1f5f9); border-radius: 12px;
  padding: .8rem .9rem; text-align: left; cursor: pointer; font: inherit;
}
.mdis__card:active { background: var(--c-ink-50, #f8fafc); }
.mdis__card-main { flex: 1; min-width: 0; }
.mdis__card-nombre { font-weight: 600; color: var(--c-ink-800, #1e293b); }
.mdis__card-meta { font-size: .75rem; color: var(--c-ink-400, #94a3b8); margin-top: 2px; }
.mdis__card-arr { color: var(--c-ink-300, #cbd5e1); }

.mdis__sheet { display: flex; flex-direction: column; gap: 1rem; padding-bottom: .5rem; }
.mdis__datos { display: flex; flex-direction: column; gap: .1rem; }
.mdis__dato {
  display: flex; justify-content: space-between; padding: .5rem 0;
  border-bottom: 1px solid var(--c-ink-100, #f1f5f9); font-size: .88rem;
}
.mdis__dato-lbl { color: var(--c-ink-500, #64748b); }
.mdis__dato-val { font-weight: 600; color: var(--c-ink-800, #1e293b); }
.mdis__dato-val--rojo { color: #dc2626; }
.mdis__dato-val small { font-weight: 400; color: var(--c-ink-400, #94a3b8); }

.mdis__ultimas-tit { font-size: .75rem; color: var(--c-ink-400, #94a3b8); margin-bottom: .3rem; }
.mdis__ultima-row {
  display: flex; justify-content: space-between; font-size: .82rem;
  color: var(--c-ink-600, #475569); padding: .25rem 0;
}
.mdis__ultima-prod { font-weight: 500; }

.mdis__btn {
  border: none; border-radius: 12px; padding: .9rem; cursor: pointer;
  background: var(--c-leaf-600, #16a34a); color: #fff; font-size: 1rem; font-weight: 600;
  display: flex; align-items: center; justify-content: center; gap: .5rem;
}
</style>
