<template>
  <SheetBottom :model-value="modelValue" title="Nueva planta" @update:model-value="v => !v && cerrar()">
    <div class="np">
      <!-- Genética: se elige o se crea acá mismo, sin salir (nombre + cómo florece + días). -->
      <template v-if="!creandoGenetica">
        <label class="np__label" for="np-gen">Genética</label>
        <select id="np-gen" v-model="form.genetica_id" class="np__input">
          <option value="" disabled>{{ geneticas.length ? 'Elegí una' : 'Todavía no cargaste ninguna' }}</option>
          <option v-for="g in geneticas" :key="g.id" :value="g.id">{{ g.nombre }}{{ g.automatica ? ' · auto' : '' }}</option>
        </select>
        <button type="button" class="np__link" @click="abrirGenetica">+ Genética nueva</button>
      </template>

      <div v-else class="np__gen">
        <div class="np__gen-cab">Genética nueva</div>
        <label class="np__label" for="np-gen-nombre">Nombre</label>
        <input id="np-gen-nombre" v-model.trim="gen.nombre" class="np__input" placeholder="Ej: Fruti Punchi" />
        <span class="np__label">¿Cómo florece?</span>
        <div class="np__dos">
          <button type="button" class="np__opcion" :class="{ 'is-on': gen.automatica }" @click="gen.automatica = true">
            Automática<small>florece sola</small>
          </button>
          <button type="button" class="np__opcion" :class="{ 'is-on': !gen.automatica }" @click="gen.automatica = false">
            Fotoperiódica<small>con el cambio a 12/12</small>
          </button>
        </div>
        <label class="np__label" for="np-gen-dias">
          {{ gen.automatica ? 'Días de semilla a cosecha' : 'Días de floración' }} <span class="np__opt">opcional · lo dice el banco</span>
        </label>
        <input id="np-gen-dias" v-model.number="gen.dias" type="number" min="1" max="400" inputmode="numeric" class="np__input"
               :placeholder="gen.automatica ? '75' : '60'" />
        <p v-if="genError" class="np__error">{{ genError }}</p>
        <div class="np__dos">
          <button type="button" class="np__btn np__btn--linea" @click="creandoGenetica = false">Cancelar</button>
          <button type="button" class="np__btn" :disabled="guardandoGen || !gen.nombre" @click="guardarGenetica">
            {{ guardandoGen ? 'Guardando…' : 'Guardar y seguir' }}
          </button>
        </div>
      </div>

      <template v-if="!creandoGenetica">
        <span class="np__label">¿Cuántas?</span>
        <div class="np__stepper">
          <button type="button" class="np__step" aria-label="Una menos" :disabled="form.cantidad <= 1" @click="form.cantidad--">−</button>
          <span class="np__cant">{{ form.cantidad }}</span>
          <button type="button" class="np__step" aria-label="Una más" :disabled="form.cantidad >= 50" @click="form.cantidad++">+</button>
        </div>
        <p v-if="nombresPreview" class="np__hint">Se van a llamar <strong>{{ nombresPreview }}</strong>. Después les cambiás el nombre si querés.</p>

        <span class="np__label">Arranca de</span>
        <div class="np__dos">
          <button type="button" class="np__opcion" :class="{ 'is-on': form.origen === 'semilla' }" @click="form.origen = 'semilla'">Semilla</button>
          <button type="button" class="np__opcion" :class="{ 'is-on': form.origen === 'esqueje' }" @click="form.origen = 'esqueje'">Esqueje</button>
        </div>

        <span class="np__label">¿En qué está?</span>
        <div class="np__tres">
          <button v-for="f in FASES" :key="f.value" type="button" class="np__opcion np__opcion--chica"
                  :class="{ 'is-on': form.fase === f.value }" @click="form.fase = f.value">
            {{ f.value === 'enraizado' ? (form.origen === 'esqueje' ? 'Enraizando' : 'Germinando') : f.label }}
          </button>
        </div>

        <template v-if="form.fase !== 'enraizado'">
          <label class="np__label" for="np-maceta">Maceta <span class="np__opt">litros, opcional</span></label>
          <div class="np__maceta">
            <input id="np-maceta" v-model.number="form.maceta" type="number" min="0" step="0.001" inputmode="decimal" class="np__input" placeholder="7" />
            <button type="button" class="np__chip" :class="{ 'is-on': form.maceta === VASO }" @click="form.maceta = VASO">Vaso</button>
          </div>
        </template>

        <div class="np__dos">
          <div>
            <label class="np__label" for="np-sala">Dónde</label>
            <select id="np-sala" v-model="form.sala_id" class="np__input">
              <option value="" disabled>{{ salasOfrecidas.length ? 'Elegí' : 'Ningún espacio sirve' }}</option>
              <option v-for="s in salasOfrecidas" :key="s.id" :value="s.id">{{ s.nombre }}</option>
            </select>
          </div>
          <div>
            <label class="np__label" for="np-dias">{{ form.fase === 'enraizado' && !yaLaTenia ? 'Desde' : 'Días que lleva' }}</label>
            <input v-if="form.fase === 'enraizado' && !yaLaTenia" id="np-dias" v-model="form.fecha" type="date" :max="hoy" class="np__input" />
            <input v-else id="np-dias" v-model.number="form.dias" type="number" min="0" max="400" inputmode="numeric" class="np__input" placeholder="0" />
          </div>
        </div>
        <p v-if="motivoSinSala" class="np__hint">{{ motivoSinSala }}</p>
        <button v-if="form.fase === 'enraizado'" type="button" class="np__link" @click="yaLaTenia = !yaLaTenia">
          {{ yaLaTenia ? 'Arranca hoy (o en una fecha)' : '¿Ya lleva unos días? Contá cuántos' }}
        </button>

        <p v-if="error" class="np__error">{{ error }}</p>
        <button type="button" class="np__btn np__btn--grande" :disabled="guardando || !puedeGuardar" @click="guardar">
          {{ guardando ? 'Agregando…' : `Agregar ${form.cantidad === 1 ? 'la planta' : `${form.cantidad} plantas`}` }}
        </button>
      </template>
    </div>
  </SheetBottom>
</template>

<script setup>
// «NUEVA PLANTA» (autocultivo, 9-oct-2026). Quien cultiva en casa piensa en plantas: una o varias,
// de una genética, en un espacio. Por debajo se crea el lote con el alta de siempre
// (`POST /salas/:id/lotes`, `Lotes::Plantar`): la regla de qué espacio admite qué fase, el nombre
// de las plantas y la carga «ya la tenía» son las del backend. Esta hoja no decide nada de eso:
// ofrece lo que el backend va a aceptar (la tabla viaja en /me) y muestra lo que responde.
import { ref, computed, watch } from 'vue'
import SheetBottom from '../cultivador/SheetBottom.vue'
import { listGeneticas, createGenetica, listPlants, createLote, createLoteHeredado } from '../../lib/api'
import { useAuthStore } from '../../stores/auth'
import { useToast } from '../../composables/useToast'
import { hoyISO } from '../../utils/dates.js'

const props = defineProps({
  modelValue: { type: Boolean, required: true },
  salas:      { type: Array, default: () => [] },
  salaId:     { type: [Number, String], default: null },
})
const emit = defineEmits(['update:modelValue', 'creada'])

const auth  = useAuthStore()
const toast = useToast()
const hoy   = hoyISO()
const VASO  = 0.335
const FASES = [
  { value: 'enraizado',  label: 'Germinando' },
  { value: 'vegetativo', label: 'En maceta' },
  { value: 'floracion',  label: 'Floreciendo' },
]

const geneticas = ref([])
const plantas   = ref([])
const form      = ref(vacio())
const yaLaTenia = ref(false)
const guardando = ref(false)
const error     = ref('')

function vacio() {
  return { genetica_id: '', cantidad: 1, origen: 'semilla', fase: 'enraizado', maceta: null,
           sala_id: props.salaId || '', fecha: hoyISO(), dias: null }
}

watch(() => props.modelValue, async (abierta) => {
  if (!abierta) return
  form.value = vacio()
  yaLaTenia.value = false
  error.value = ''
  creandoGenetica.value = false
  try { geneticas.value = (await listGeneticas()).data || [] } catch { geneticas.value = [] }
  try { plantas.value = (await listPlants()).data || [] } catch { plantas.value = [] }
  if (geneticas.value.length === 1) form.value.genetica_id = geneticas.value[0].id
  if (!form.value.sala_id && salasOfrecidas.value.length === 1) form.value.sala_id = salasOfrecidas.value[0].id
}, { immediate: true })

const genetica = computed(() => geneticas.value.find(g => String(g.id) === String(form.value.genetica_id)))

// Los espacios donde puede estar: la tabla sala⇔fase la manda el backend (las autos de casa entran
// en cualquier espacio; una foto germinando no entra en 12/12).
const salasOfrecidas = computed(() => {
  const reglas = auth.user?.reglas_cultivo || {}
  const tabla = (genetica.value?.automatica ? reglas.kinds_sala_por_estado_automatica : reglas.kinds_sala_por_estado) || {}
  const ok = tabla[form.value.fase]
  return props.salas.filter(s => !ok || ok.includes(s.kind))
})
watch(salasOfrecidas, (lista) => {
  if (form.value.sala_id && !lista.some(s => String(s.id) === String(form.value.sala_id))) form.value.sala_id = ''
  if (!form.value.sala_id && lista.length === 1) form.value.sala_id = lista[0].id
})
const motivoSinSala = computed(() => {
  if (salasOfrecidas.value.length || !props.salas.length) return ''
  return form.value.fase === 'floracion'
    ? 'Para cargarla floreciendo hace falta un espacio en 12/12.'
    : 'Germinando o en vege, una fotoperiódica necesita un espacio en 18/6.'
})

// Cómo se van a llamar: la misma cuenta que hace el backend (sigue la numeración de esa genética).
const nombresPreview = computed(() => {
  const base = genetica.value?.nombre
  if (!base) return ''
  const patron = new RegExp(`^${base.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')} (\\d+)$`)
  const ultimo = Math.max(0, ...plantas.value.map(p => Number((p.nombre || '').match(patron)?.[1] || 0)))
  const n = form.value.cantidad
  const nombres = Array.from({ length: Math.min(n, 3) }, (_, i) => `${base} ${ultimo + i + 1}`)
  if (n > 3) return `${nombres.join(', ')}… hasta ${base} ${ultimo + n}`
  return nombres.length > 1 ? `${nombres.slice(0, -1).join(', ')} y ${nombres.at(-1)}` : nombres[0]
})

const puedeGuardar = computed(() => form.value.genetica_id && form.value.sala_id && form.value.cantidad >= 1)

async function guardar() {
  guardando.value = true
  error.value = ''
  const f = form.value
  const payload = { genetica_id: f.genetica_id, origen: f.origen, estado: f.fase, plants_count: f.cantidad }
  if (f.fase !== 'enraizado' && Number(f.maceta) > 0) payload.tamanio_maceta = Number(f.maceta)
  const heredada = f.fase !== 'enraizado' || yaLaTenia.value
  try {
    let data
    if (heredada) {
      const dias = Number(f.dias) || 0
      ;({ data } = await createLoteHeredado(f.sala_id, payload, {
        dias_semilla_esqueje: f.fase === 'enraizado' ? dias : 0,
        dias_vegetativo:      f.fase === 'vegetativo' ? dias : 0,
        dias_floracion:       f.fase === 'floracion' ? dias : 0,
      }))
    } else {
      ;({ data } = await createLote(f.sala_id, { ...payload, start_date: f.fecha || hoyISO() }))
    }
    const nombres = (data.plants || []).map(p => p.nombre)
    toast.success(nombres.length ? `Listo: ${nombres.join(', ')}` : 'Planta agregada')
    emit('creada', data)
    cerrar()
  } catch (e) {
    const d = e?.response?.data
    error.value = d?.mensaje || d?.errors?.join(', ') || d?.error || 'No se pudo agregar'
  } finally {
    guardando.value = false
  }
}

// ── Genética nueva, sin salir ─────────────────────────────────────────────────────────────────
// Lo mínimo para plantar: nombre, si es automática y cuántos días. El resto (banco, tipo, THC,
// foto) se completa cuando quieras desde Genéticas.
const creandoGenetica = ref(false)
const gen = ref({ nombre: '', automatica: false, dias: null })
const genError = ref('')
const guardandoGen = ref(false)

function abrirGenetica() {
  gen.value = { nombre: '', automatica: false, dias: null }
  genError.value = ''
  creandoGenetica.value = true
}

async function guardarGenetica() {
  guardandoGen.value = true
  genError.value = ''
  try {
    const g = gen.value
    const payload = { nombre: g.nombre, automatica: g.automatica }
    if (Number(g.dias) > 0) payload[g.automatica ? 'dias_ciclo_objetivo' : 'tiempo_floracion'] = Number(g.dias)
    const { data } = await createGenetica(payload)
    geneticas.value = [...geneticas.value, data].sort((a, b) => a.nombre.localeCompare(b.nombre))
    form.value.genetica_id = data.id
    creandoGenetica.value = false
  } catch (e) {
    const d = e?.response?.data
    genError.value = d?.errors?.join(', ') || d?.error || 'No se pudo guardar la genética'
  } finally {
    guardandoGen.value = false
  }
}

function cerrar() { emit('update:modelValue', false) }
</script>

<style scoped>
.np { display: flex; flex-direction: column; gap: 10px; padding: 4px 2px 8px; }
.np__label { font-size: .82rem; font-weight: 600; color: var(--c-ink-700); margin-top: 4px; }
.np__opt { font-weight: 400; color: var(--c-ink-500); }
.np__input {
  width: 100%; min-height: 46px; padding: 0 12px; border: 1px solid var(--c-ink-300); border-radius: 12px;
  font: inherit; font-size: 1rem; background: var(--c-slate-50); color: var(--c-ink-900); box-sizing: border-box;
}
.np__link { align-self: flex-start; background: none; border: 0; padding: 4px 0; font: inherit; font-size: .9rem; font-weight: 600; color: var(--c-leaf-700); cursor: pointer; }
.np__dos { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 8px; }
.np__tres { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 6px; }
.np__opcion {
  min-height: 46px; border-radius: 12px; border: 1px solid var(--c-ink-300); background: var(--c-slate-50);
  font: inherit; font-weight: 600; font-size: .92rem; color: var(--c-ink-900); display: flex; flex-direction: column;
  align-items: center; justify-content: center; gap: 1px; cursor: pointer; padding: 6px;
}
.np__opcion small { font-weight: 400; font-size: .74rem; color: var(--c-ink-500); }
.np__opcion--chica { font-size: .84rem; }
.np__opcion.is-on { border: 2px solid var(--c-leaf-700); background: var(--c-leaf-100); color: var(--c-leaf-800); }
.np__stepper { display: flex; align-items: center; gap: 14px; }
.np__step { width: 46px; height: 46px; border-radius: 12px; border: 1px solid var(--c-ink-300); background: var(--c-slate-50); font-size: 1.4rem; color: var(--c-ink-900); cursor: pointer; }
.np__step:disabled { opacity: .4; }
.np__cant { font-size: 1.6rem; font-weight: 800; min-width: 32px; text-align: center; }
.np__hint { margin: 0; font-size: .84rem; color: var(--c-ink-700); line-height: 1.4; }
.np__maceta { display: grid; grid-template-columns: minmax(0, 1fr) auto; gap: 8px; }
.np__chip { min-height: 46px; padding: 0 14px; border-radius: 12px; border: 1px solid var(--c-ink-300); background: var(--c-slate-50); font: inherit; font-weight: 600; cursor: pointer; }
.np__chip.is-on { border: 2px solid var(--c-leaf-700); background: var(--c-leaf-100); }
.np__gen { display: flex; flex-direction: column; gap: 8px; padding: 12px; border-radius: 14px; background: var(--c-leaf-50); border: 1px solid var(--c-leaf-300); }
.np__gen-cab { font-weight: 800; color: var(--c-leaf-800); }
.np__btn {
  min-height: 48px; border-radius: 12px; border: 0; background: var(--c-leaf-700); color: var(--c-slate-50);
  font: inherit; font-weight: 700; cursor: pointer;
}
.np__btn:disabled { opacity: .5; }
.np__btn--linea { background: var(--c-slate-50); color: var(--c-ink-900); border: 1px solid var(--c-ink-300); }
.np__btn--grande { min-height: 54px; font-size: 1rem; margin-top: 6px; }
.np__error { margin: 0; color: var(--c-rust-600); font-size: .86rem; }
</style>
