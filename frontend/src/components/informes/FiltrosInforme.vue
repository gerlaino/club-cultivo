<template>
  <div class="fin">
    <div class="fin__barra">
      <button type="button" class="fin__toggle" :class="{ 'fin__toggle--on': cantidad }" @click="abrir = !abrir">
        <i class="bi bi-funnel"></i> Filtros<span v-if="cantidad" class="fin__count">{{ cantidad }}</span>
        <i class="bi" :class="abrir ? 'bi-chevron-up' : 'bi-chevron-down'"></i>
      </button>
      <!-- Lo aplicado, a la vista y de a uno para sacar: el informe dice qué recorte es. -->
      <span v-for="c in chips" :key="c.clave" class="fin__chip">
        {{ c.texto }}
        <button type="button" class="fin__chip-x" :aria-label="`Quitar ${c.texto}`" @click="quitar(c.grupo, c.valor)">×</button>
      </span>
      <button v-if="cantidad" type="button" class="fin__limpiar" @click="limpiar">Limpiar</button>
    </div>

    <div v-if="abrir" class="fin__panel">
      <div v-if="cargando" class="fin__cargando">Cargando opciones…</div>
      <div v-else-if="error" class="fin__error">
        No se pudieron traer las opciones. <button type="button" class="fin__link" @click="cargarOpciones">Reintentar</button>
      </div>
      <template v-else>
        <div class="fin__grid">
          <div v-if="usa.includes('origen')" class="fin__bloque">
            <div class="fin__titulo">Origen</div>
            <label v-for="o in ORIGENES" :key="o.v" class="fin__opt">
              <input v-model="borrador.origen" type="radio" :value="o.v" /> {{ o.l }}
            </label>
          </div>

          <div v-if="usa.includes('saldo')" class="fin__bloque">
            <div class="fin__titulo">Saldo</div>
            <label v-for="o in SALDOS" :key="o.v" class="fin__opt">
              <input v-model="borrador.saldo" type="radio" :value="o.v" /> {{ o.l }}
            </label>
          </div>

          <div v-for="g in gruposVisibles" :key="g.clave" class="fin__bloque">
            <div class="fin__titulo">
              {{ g.titulo }}
              <span v-if="borrador[g.clave].size" class="fin__sub">{{ borrador[g.clave].size }} de {{ g.items.length }}</span>
            </div>
            <input v-if="g.items.length > 8" v-model="busqueda[g.clave]" class="fin__buscar" :placeholder="`Buscar ${g.titulo.toLowerCase()}…`" />
            <div class="fin__lista">
              <label v-for="it in filtrados(g)" :key="it.valor" class="fin__opt">
                <input type="checkbox" :checked="borrador[g.clave].has(it.valor)" @change="alternar(g.clave, it.valor)" />
                <span>{{ it.texto }}<small v-if="it.sub" class="fin__muted"> · {{ it.sub }}</small></span>
              </label>
              <div v-if="!g.items.length" class="fin__muted">No hay para elegir.</div>
            </div>
          </div>
        </div>
        <p class="fin__nota">Sin nada tildado en un grupo, entra todo. Un informe filtrado lo dice en la pantalla, el PDF y el Excel.</p>
        <div class="fin__acciones">
          <button type="button" class="fin__btn-ghost" @click="abrir = false">Cancelar</button>
          <button type="button" class="fin__btn" @click="aplicar">Aplicar</button>
        </div>
      </template>
    </div>
  </div>
</template>

<script setup>
import { ref, reactive, computed, watch } from 'vue'
import api from '../../lib/api.js'

// LOS FILTROS DE UN INFORME, uno solo para todos (ver `Informes::Filtros` en el backend). Cada
// informe dice cuáles le aplican (`usa`) y la barra ofrece sólo esos: un filtro que el informe
// ignora es peor que no tenerlo. Emite los PARÁMETROS —los mismos van a la pantalla y a la descarga.
//
// Se arma en borrador y se aplica con «Aplicar»: tildar diez pacientes no tiene que pedir diez
// informes. Sacar un chip o «Limpiar» aplican al toque.
const props = defineProps({
  usa: { type: Array, required: true },   // 'lotes' | 'pacientes' | 'geneticas' | 'sedes' | 'dispensadores' | 'formas' | 'origen' | 'saldo'
})
const emit = defineEmits(['change'])

const ORIGENES = [
  { v: 'todo',     l: 'Todo' },
  { v: 'propio',   l: 'Stock propio' },
  { v: 'externo',  l: 'Stock externo' },
]
// Del informe de stock: todo, sólo lo que tiene saldo hoy, o sólo lo agotado.
const SALDOS = [
  { v: '',          l: 'Todo' },
  { v: 'con_saldo', l: 'Con saldo' },
  { v: 'agotados',  l: 'Agotados' },
]
// grupo → parámetro de la API y título
const GRUPOS = {
  lotes:         { param: 'lote_ids',        titulo: 'Lotes' },
  pacientes:     { param: 'paciente_ids',    titulo: 'Pacientes' },
  geneticas:     { param: 'genetica_ids',    titulo: 'Genéticas' },
  sedes:         { param: 'sede_ids',        titulo: 'Sedes' },
  dispensadores: { param: 'dispensador_ids', titulo: 'Quién dispensó' },
  formas:        { param: 'formas',          titulo: 'Productos' },
}

const abrir    = ref(false)
const cargando = ref(false)
const error    = ref(false)
const opciones = ref(null)

const vacio = () => ({ ...Object.fromEntries(Object.keys(GRUPOS).map(k => [k, new Set()])), origen: 'todo', saldo: '' })
const aplicado = ref(vacio())
const borrador = reactive(vacio())
const busqueda = reactive({})

async function cargarOpciones() {
  cargando.value = true
  error.value = false
  try {
    const { data } = await api.get('/informes/filtros')
    opciones.value = data
  } catch {
    error.value = true
  } finally {
    cargando.value = false
  }
}

// Al abrir: el borrador arranca desde lo aplicado, y las opciones se piden la primera vez.
watch(abrir, (a) => {
  if (!a) return
  copiar(aplicado.value, borrador)
  if (!opciones.value) cargarOpciones()
})

function copiar(de, a) {
  for (const k of Object.keys(GRUPOS)) a[k] = new Set(de[k])
  a.origen = de.origen
  a.saldo  = de.saldo
}

// Cada opción como { valor, texto, sub }: la lista y los chips hablan igual.
function items(clave) {
  const o = opciones.value || {}
  switch (clave) {
    case 'lotes':         return (o.lotes || []).map(l => ({ valor: l.id, texto: l.codigo, sub: l.genetica }))
    case 'pacientes':     return (o.pacientes || []).map(p => ({ valor: p.id, texto: p.nombre, sub: p.dni_ultimos_3 ? `DNI …${p.dni_ultimos_3}` : null }))
    case 'geneticas':     return (o.geneticas || []).map(g => ({ valor: g.id, texto: g.nombre }))
    case 'sedes':         return (o.sedes || []).map(s => ({ valor: s.id, texto: s.nombre }))
    case 'dispensadores': return (o.dispensadores || []).map(u => ({ valor: u.id, texto: u.nombre }))
    case 'formas':        return (o.formas || []).map(f => ({ valor: f.valor, texto: f.nombre }))
    default:              return []
  }
}

const gruposVisibles = computed(() =>
  Object.keys(GRUPOS).filter(k => props.usa.includes(k)).map(k => ({ clave: k, titulo: GRUPOS[k].titulo, items: items(k) })))

function filtrados(g) {
  const q = (busqueda[g.clave] || '').trim().toLowerCase()
  if (!q) return g.items
  return g.items.filter(it => `${it.texto} ${it.sub || ''}`.toLowerCase().includes(q))
}

function alternar(clave, valor) {
  const s = new Set(borrador[clave])
  s.has(valor) ? s.delete(valor) : s.add(valor)
  borrador[clave] = s
}

// Los chips salen de lo APLICADO. Si las opciones todavía no llegaron, el valor crudo.
const chips = computed(() => {
  const out = []
  for (const k of Object.keys(GRUPOS)) {
    if (!props.usa.includes(k)) continue
    const lista = items(k)
    for (const v of aplicado.value[k]) {
      out.push({ clave: `${k}-${v}`, grupo: k, valor: v, texto: lista.find(i => i.valor === v)?.texto ?? v })
    }
  }
  if (aplicado.value.origen !== 'todo') {
    out.push({ clave: 'origen', grupo: 'origen', valor: null, texto: ORIGENES.find(o => o.v === aplicado.value.origen).l })
  }
  if (aplicado.value.saldo) {
    out.push({ clave: 'saldo', grupo: 'saldo', valor: null, texto: SALDOS.find(o => o.v === aplicado.value.saldo).l })
  }
  return out
})
const cantidad = computed(() => chips.value.length)

function params(estado) {
  const p = {}
  for (const [k, g] of Object.entries(GRUPOS)) {
    if (props.usa.includes(k) && estado[k].size) p[g.param] = [...estado[k]]
  }
  if (props.usa.includes('origen') && estado.origen !== 'todo') p.origen = estado.origen
  if (props.usa.includes('saldo') && estado.saldo) p.saldo = estado.saldo
  return p
}

function publicar(nuevo) {
  aplicado.value = nuevo
  emit('change', params(nuevo))
}

function aplicar() {
  const nuevo = vacio()
  copiar(borrador, nuevo)
  abrir.value = false
  publicar(nuevo)
}

function quitar(grupo, valor) {
  const nuevo = vacio()
  copiar(aplicado.value, nuevo)
  if (grupo === 'origen') nuevo.origen = 'todo'
  else if (grupo === 'saldo') nuevo.saldo = ''
  else nuevo[grupo].delete(valor)
  publicar(nuevo)
}

function limpiar() {
  abrir.value = false
  publicar(vacio())
}

defineExpose({ params: () => params(aplicado.value) })
</script>

<style scoped>
.fin { width: 100%; }
.fin__barra { display: flex; align-items: center; gap: var(--sp-2); flex-wrap: wrap; }
.fin__toggle {
  display: inline-flex; align-items: center; gap: .4rem; background: var(--c-ink-100); border: 1.5px solid var(--c-ink-300);
  border-radius: var(--r-md); padding: 6px 12px; font-size: var(--fs-14); color: var(--c-ink-900); cursor: pointer; font-family: inherit;
}
.fin__toggle--on { border-color: var(--c-leaf-600); color: var(--c-leaf-700); }
.fin__count { background: var(--c-leaf-600); color: #fff; border-radius: 999px; font-size: var(--fs-12); padding: 0 7px; font-weight: 700; }
.fin__chip {
  display: inline-flex; align-items: center; gap: 4px; background: var(--c-leaf-100); color: var(--c-leaf-800);
  border-radius: 999px; padding: 2px 4px 2px 10px; font-size: var(--fs-12); font-weight: 600;
}
.fin__chip-x { background: none; border: none; color: inherit; cursor: pointer; font-size: 14px; line-height: 1; padding: 0 4px; }
.fin__limpiar, .fin__link { background: none; border: none; color: var(--c-ink-500); font-size: var(--fs-12); font-weight: 600; cursor: pointer; text-decoration: underline; padding: 0; }

.fin__panel { margin-top: var(--sp-3); background: #fff; border: 1px solid var(--c-ink-300); border-radius: var(--r-lg); padding: var(--sp-4); box-shadow: 0 8px 24px rgb(15 23 42 / .08); }
.fin__grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(210px, 1fr)); gap: var(--sp-4); }
.fin__bloque { min-width: 0; }
.fin__titulo { font-size: var(--fs-12); font-weight: 700; color: var(--c-ink-700); text-transform: uppercase; letter-spacing: .04em; margin-bottom: var(--sp-2); display: flex; justify-content: space-between; }
.fin__sub { text-transform: none; letter-spacing: 0; color: var(--c-leaf-700); }
.fin__buscar { width: 100%; box-sizing: border-box; border: 1px solid var(--c-ink-300); border-radius: var(--r-md); padding: 5px 9px; font-size: var(--fs-13); margin-bottom: var(--sp-2); font-family: inherit; }
.fin__lista { max-height: 200px; overflow-y: auto; display: flex; flex-direction: column; gap: 2px; }
.fin__opt { display: flex; align-items: flex-start; gap: 6px; font-size: var(--fs-13); color: var(--c-ink-900); cursor: pointer; padding: 2px 0; }
.fin__opt input { margin-top: 3px; }
.fin__muted { color: var(--c-ink-500); font-size: var(--fs-12); }
.fin__nota { font-size: var(--fs-12); color: var(--c-ink-500); margin: var(--sp-3) 0 0; }
.fin__acciones { display: flex; justify-content: flex-end; gap: var(--sp-2); margin-top: var(--sp-3); }
.fin__btn { background: var(--c-leaf-700); color: #fff; border: none; border-radius: var(--r-md); padding: 6px 16px; font-weight: 600; font-size: var(--fs-14); cursor: pointer; }
.fin__btn-ghost { background: none; border: none; color: var(--c-ink-500); font-weight: 600; font-size: var(--fs-14); cursor: pointer; }
.fin__cargando, .fin__error { font-size: var(--fs-13); color: var(--c-ink-500); }
</style>
