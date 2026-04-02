<template>
  <div class="tl">

    <div v-if="loading" class="tl__loading">
      <div class="tl__spinner"></div>
      <span>Cargando tareas…</span>
    </div>

    <div v-else-if="tareasPendientes.length === 0" class="tl__empty">
      <span>🎉</span>
      <p>Sin tareas pendientes para este lote</p>
    </div>

    <div v-else class="tl__lista">
      <div
        v-for="t in tareasPendientes"
        :key="t.id"
        class="tl__tarea"
        :class="`tl__tarea--${t.prioridad}`"
      >
        <div class="tl__tarea-left">
          <div class="tl__tarea-titulo">{{ t.titulo }}</div>
          <div class="tl__tarea-meta">
            {{ TIPO_LABELS[t.tipo] || t.tipo }}
            <span v-if="t.fecha_programada"> · {{ t.fecha_programada }}</span>
            <span v-if="t.asignada_a"> · {{ t.asignada_a.nombre }}</span>
          </div>
        </div>
        <div class="tl__tarea-right">
          <span class="tl__prioridad" :class="`tl__prioridad--${t.prioridad}`">{{ t.prioridad }}</span>
          <button
            v-if="t.estado === 'pendiente'"
            class="tl__btn-iniciar"
            @click="iniciar(t)"
            :disabled="procesando === t.id"
          >
            <i class="bi bi-play-fill"></i>
          </button>
          <button
            v-else-if="t.estado === 'en_progreso'"
            class="tl__btn-completar"
            @click="completar(t)"
            :disabled="procesando === t.id"
          >
            <i class="bi bi-check-lg"></i>
          </button>
        </div>
      </div>
    </div>

    <!-- Modal completar tarea normal -->
    <Teleport to="body">
      <div v-if="tareaCompletando && !esRegistroLote(tareaCompletando)" class="tl__overlay" @click.self="tareaCompletando = null">
        <div class="tl__modal">
          <div class="tl__modal-header">
            <h3 class="tl__modal-title">Completar tarea</h3>
            <button class="tl__modal-close" @click="tareaCompletando = null"><i class="bi bi-x-lg"></i></button>
          </div>
          <div class="tl__modal-body">
            <p class="tl__modal-nombre">{{ tareaCompletando.titulo }}</p>
            <div class="tl__field">
              <label class="tl__label">Horas trabajadas <span class="tl__optional">opcional</span></label>
              <div class="tl__input-group">
                <input v-model.number="horasForm" type="number" class="tl__input" min="0.25" max="24" step="0.25" placeholder="0.0" />
                <span class="tl__input-suffix">hs</span>
              </div>
            </div>
            <div class="tl__field">
              <label class="tl__label">Notas <span class="tl__optional">opcional</span></label>
              <textarea v-model="notasForm" class="tl__input tl__textarea" rows="2" placeholder="¿Algo a destacar?"></textarea>
            </div>
          </div>
          <div class="tl__modal-footer">
            <button class="tl__btn-ghost" @click="tareaCompletando = null">Cancelar</button>
            <button class="tl__btn-success" @click="confirmarCompletar" :disabled="guardando">
              <span v-if="guardando" class="tl__spinner tl__spinner--sm"></span>
              <i v-else class="bi bi-check-lg"></i>Completar
            </button>
          </div>
        </div>
      </div>
    </Teleport>

    <!-- Modal completar tarea de tipo registro_lote -->
    <Teleport to="body">
      <div v-if="tareaCompletando && esRegistroLote(tareaCompletando)" class="tl__overlay" @click.self="tareaCompletando = null">
        <div class="tl__modal tl__modal--wide">
          <div class="tl__modal-header">
            <div>
              <h3 class="tl__modal-title">📋 Registro del lote</h3>
              <p class="tl__modal-sub">{{ lote.codigo }} · {{ new Date().toLocaleDateString('es-AR') }}</p>
            </div>
            <button class="tl__modal-close" @click="tareaCompletando = null"><i class="bi bi-x-lg"></i></button>
          </div>
          <div class="tl__modal-body">
            <div v-if="registroError" class="tl__alert">{{ registroError }}</div>

            <!-- Estado y plagas -->
            <div class="tl__section-title">Estado general</div>
            <div class="tl__grid">
              <div class="tl__field tl__field--full">
                <label class="tl__label">Estado de las plantas</label>
                <div class="tl__selector">
                  <button v-for="(meta, key) in ESTADO_SALUD_META" :key="key" type="button"
                          class="tl__sel-btn"
                          :class="{ 'tl__sel-btn--active': registroForm.estado_general === key }"
                          :style="registroForm.estado_general===key ? {borderColor:meta.color,background:meta.color+'15',color:meta.color} : {}"
                          @click="registroForm.estado_general = key">
                    {{ meta.emoji }} {{ key }}
                  </button>
                </div>
              </div>
              <div class="tl__field tl__field--full">
                <label class="tl__label">Plagas</label>
                <div class="tl__selector">
                  <button v-for="(meta, key) in PLAGAS_META" :key="key" type="button"
                          class="tl__sel-btn"
                          :class="{ 'tl__sel-btn--active': registroForm.plagas_observadas === key }"
                          :style="registroForm.plagas_observadas===key ? {borderColor:meta.color,background:meta.color+'15',color:meta.color} : {}"
                          @click="registroForm.plagas_observadas = key">
                    {{ meta.emoji }} {{ key }}
                  </button>
                </div>
              </div>
            </div>

            <div class="tl__section-title">Ambiente</div>
            <div class="tl__grid">
              <div class="tl__field">
                <label class="tl__label">Temperatura aire (°C)</label>
                <input type="number" step="0.1" class="tl__input" v-model.number="registroForm.temperatura" placeholder="24.5" />
              </div>
              <div class="tl__field">
                <label class="tl__label">Temperatura sustrato (°C)</label>
                <input type="number" step="0.1" class="tl__input" v-model.number="registroForm.temperatura_sustrato" placeholder="22.0" />
              </div>
              <div class="tl__field">
                <label class="tl__label">Humedad (%)</label>
                <input type="number" step="0.1" class="tl__input" v-model.number="registroForm.humedad" placeholder="60" />
              </div>
              <div class="tl__field">
                <label class="tl__label">CO₂ (ppm)</label>
                <input type="number" step="1" class="tl__input" v-model.number="registroForm.co2" placeholder="1200" />
              </div>
            </div>

            <div class="tl__section-title">Agua</div>
            <div class="tl__grid">
              <div class="tl__field">
                <label class="tl__label">pH entrada</label>
                <input type="number" step="0.1" class="tl__input" v-model.number="registroForm.ph" placeholder="6.2" />
              </div>
              <div class="tl__field">
                <label class="tl__label">EC (mS/cm)</label>
                <input type="number" step="0.1" class="tl__input" v-model.number="registroForm.ec" placeholder="1.8" />
              </div>
            </div>

            <!-- Fertilización -->
            <div class="tl__section-title">Fertilización</div>
            <div class="tl__field tl__field--full">
              <label class="tl__toggle">
                <input type="checkbox" v-model="registroForm.fertilizacion" class="tl__toggle-input" />
                <div class="tl__toggle-track"><div class="tl__toggle-thumb"></div></div>
                <span class="tl__toggle-label">Se realizó fertilización</span>
              </label>
              <textarea v-if="registroForm.fertilizacion" class="tl__input tl__textarea"
                        style="margin-top:.6rem" rows="2"
                        v-model.trim="registroForm.notas_fertilizacion"
                        placeholder="Ej: Base A 10ml/L + Base B 10ml/L"></textarea>
            </div>

            <!-- Avanzar ciclo -->
            <div class="tl__section-title">Ciclo <span class="tl__optional">opcional</span></div>
            <div class="tl__field tl__field--full">
              <label class="tl__label">¿Avanzar a la siguiente etapa?</label>
              <div class="tl__selector">
                <button type="button" class="tl__sel-btn"
                        :class="{ 'tl__sel-btn--active': registroForm.nuevo_estado === '' }"
                        :style="registroForm.nuevo_estado==='' ? {borderColor:'#64748b',background:'#f1f5f9',color:'#64748b'} : {}"
                        @click="registroForm.nuevo_estado = ''">
                  Sin cambio
                </button>
                <button v-for="etapa in estadosSiguientes" :key="etapa" type="button"
                        class="tl__sel-btn"
                        :class="{ 'tl__sel-btn--active': registroForm.nuevo_estado === etapa }"
                        :style="registroForm.nuevo_estado===etapa ? {borderColor:em(etapa).color,background:em(etapa).bg,color:em(etapa).color} : {}"
                        @click="registroForm.nuevo_estado = etapa">
                  {{ em(etapa).emoji }} {{ em(etapa).label }}
                </button>
              </div>
            </div>

            <!-- Observaciones -->
            <div class="tl__field tl__field--full" style="margin-top:.75rem">
              <label class="tl__label">Observaciones <span class="tl__optional">opcional</span></label>
              <textarea class="tl__input tl__textarea" rows="2" v-model.trim="registroForm.observaciones" placeholder="Cualquier observación relevante…"></textarea>
            </div>
          </div>
          <div class="tl__modal-footer">
            <button class="tl__btn-ghost" @click="tareaCompletando = null">Cancelar</button>
            <button class="tl__btn-success" @click="confirmarRegistroLote" :disabled="guardando">
              <span v-if="guardando" class="tl__spinner tl__spinner--sm"></span>
              <i v-else class="bi bi-check-lg"></i>Guardar y completar tarea
            </button>
          </div>
        </div>
      </div>
    </Teleport>

  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { listTareas, updateTarea, createRegistroAmbiental, createLoteEvento } from '../lib/api.js'
import { useTareasStore } from '../stores/tareas'

const props = defineProps({
  lote: { type: Object, required: true }
})
const emit = defineEmits(['tarea-completada', 'horas-aplicadas'])

const tareasStore = useTareasStore()
const tareas      = ref([])
const loading     = ref(false)
const procesando  = ref(null)
const guardando   = ref(false)

// Modal completar normal
const tareaCompletando = ref(null)
const horasForm        = ref(null)
const notasForm        = ref('')

// Modal registro lote
const registroError = ref(null)
const registroForm  = ref(emptyRegistroForm())

function emptyRegistroForm() {
  return {
    temperatura:null, humedad:null, temperatura_sustrato:null, co2:null,
    ph:null, ec:null, fertilizacion:false, notas_fertilizacion:'',
    plagas_observadas:'ninguna', estado_general:'bueno',
    observaciones:'', nuevo_estado:''
  }
}

const TIPO_LABELS = {
  riego:'💧 Riego', poda:'✂️ Poda', medicion:'📏 Medición',
  limpieza:'🧹 Limpieza', cosecha:'🌿 Cosecha', transplante:'🪴 Trasplante',
  inspeccion:'🔍 Inspección', registrar_lote:'📋 Registrar lote',
  registrar_planta:'🌱 Registrar planta', otro:'📋 Otro'
}

const ESTADO_SALUD_META = {
  excelente:{color:"#16a34a",emoji:"🟢"}, bueno:{color:"#65a30d",emoji:"🟡"},
  regular:{color:"#d97706",emoji:"🟠"},   malo:{color:"#dc2626",emoji:"🔴"},
  critico:{color:"#991b1b",emoji:"🚨"},
}
const PLAGAS_META = {
  ninguna:{color:"#16a34a",emoji:"✅"}, leve:{color:"#d97706",emoji:"⚠️"},
  moderada:{color:"#ea580c",emoji:"🐛"}, severa:{color:"#dc2626",emoji:"🚨"},
}
const CICLO = ["semilla","vegetativo","floracion","cosecha","curado","finalizado"]
const ESTADO_META = {
  semilla:    {label:"Semilla",    color:"#64748b",bg:"#f1f5f9", emoji:"🌱"},
  vegetativo: {label:"Vegetativo", color:"#16a34a",bg:"#dcfce7", emoji:"🍃"},
  floracion:  {label:"Floración",  color:"#d97706",bg:"#fef3c7", emoji:"🌸"},
  cosecha:    {label:"Cosecha",    color:"#92400e",bg:"#fff7ed", emoji:"✂️"},
  curado:     {label:"Curado",     color:"#2563eb",bg:"#dbeafe", emoji:"🫙"},
  finalizado: {label:"Finalizado", color:"#1b5e20",bg:"#dcfce7", emoji:"✅"},
}
function em(e) { return ESTADO_META[e] || {label:e,color:"#64748b",bg:"#f1f5f9",emoji:"•"} }

const estadosSiguientes = computed(() => {
  const idx = CICLO.indexOf(props.lote?.estado)
  return CICLO.filter((_,i) => i > idx)
})

const tareasPendientes = computed(() =>
  tareas.value.filter(t => ['pendiente','en_progreso'].includes(t.estado))
    .sort((a,b) => {
      const orden = {urgente:0,alta:1,normal:2,baja:3}
      return (orden[a.prioridad]||2) - (orden[b.prioridad]||2)
    })
)

function esRegistroLote(t) {
  return t.tipo === 'registrar_lote' || t.titulo?.toLowerCase().includes('registrar lote') || t.titulo?.toLowerCase().includes('registro lote')
}

onMounted(() => cargarTareas())

async function cargarTareas() {
  loading.value = true
  try {
    const res = await listTareas({ lote_id: props.lote.id })
    tareas.value = res.data
  } catch {}
  finally { loading.value = false }
}

async function iniciar(t) {
  procesando.value = t.id
  try {
    await tareasStore.iniciar(t.id)
    const found = tareas.value.find(x => x.id === t.id)
    if (found) found.estado = 'en_progreso'
  } catch {}
  finally { procesando.value = null }
}

function completar(t) {
  tareaCompletando.value = t
  horasForm.value        = t.horas_estimadas || null
  notasForm.value        = ''
  registroForm.value     = emptyRegistroForm()
  registroError.value    = null
}

async function confirmarCompletar() {
  if (!tareaCompletando.value) return
  guardando.value = true
  try {
    await tareasStore.completar(tareaCompletando.value.id, horasForm.value, notasForm.value)
    tareas.value = tareas.value.filter(t => t.id !== tareaCompletando.value.id)
    emit('tarea-completada', tareaCompletando.value)
    tareaCompletando.value = null
  } catch {}
  finally { guardando.value = false }
}

async function confirmarRegistroLote() {
  if (!tareaCompletando.value) return
  guardando.value = true; registroError.value = null
  try {
    // 1. Crear registro ambiental
    const payload = { ...registroForm.value }
    delete payload.nuevo_estado
    await createRegistroAmbiental(props.lote.id, payload)

    // 2. Avanzar ciclo si corresponde
    if (registroForm.value.nuevo_estado) {
      await createLoteEvento(props.lote.id, {
        tipo: 'cambio_estado',
        estado_nuevo: registroForm.value.nuevo_estado,
        descripcion: `Cambio desde registro del lote`
      })
      // Actualizar estado local
      props.lote.estado = registroForm.value.nuevo_estado
    }

    // 3. Completar la tarea
    await tareasStore.completar(tareaCompletando.value.id, horasForm.value, registroForm.value.observaciones)
    tareas.value = tareas.value.filter(t => t.id !== tareaCompletando.value.id)
    emit('tarea-completada', tareaCompletando.value)
    tareaCompletando.value = null
  } catch(e) {
    registroError.value = e?.response?.data?.errors?.join(', ') || 'Error al guardar'
  }
  finally { guardando.value = false }
}
</script>

<style scoped>
.tl { font-family: system-ui, -apple-system, sans-serif; }
.tl__loading { display: flex; align-items: center; gap: .5rem; padding: 1.5rem; color: #94a3b8; font-size: .875rem; }
.tl__spinner { width: 16px; height: 16px; border: 2px solid #d4e6d4; border-top-color: #1b5e20; border-radius: 50%; animation: tl-spin .6s linear infinite; }
.tl__spinner--sm { width: 13px; height: 13px; border-color: rgba(255,255,255,.3); border-top-color: #fff; }
@keyframes tl-spin { to { transform: rotate(360deg); } }
.tl__empty { display: flex; align-items: center; gap: .75rem; padding: 1.5rem 1.1rem; color: #60725d; font-size: .875rem; }
.tl__lista { display: flex; flex-direction: column; }
.tl__tarea { display: flex; align-items: center; justify-content: space-between; gap: .75rem; padding: .85rem 1.1rem; border-bottom: 1px solid #f0fdf4; border-left: 3px solid #d4e6d4; transition: background .15s; }
.tl__tarea:last-child { border-bottom: none; }
.tl__tarea:hover { background: #f9fdf9; }
.tl__tarea--urgente { border-left-color: #dc2626; }
.tl__tarea--alta    { border-left-color: #ea580c; }
.tl__tarea--normal  { border-left-color: #2563eb; }
.tl__tarea--baja    { border-left-color: #94a3b8; }
.tl__tarea-left { flex: 1; min-width: 0; }
.tl__tarea-titulo { font-size: .875rem; font-weight: 600; color: #1a1a1a; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.tl__tarea-meta { font-size: .72rem; color: #94a3b8; margin-top: .1rem; }
.tl__tarea-right { display: flex; align-items: center; gap: .5rem; flex-shrink: 0; }
.tl__prioridad { font-size: .62rem; font-weight: 700; text-transform: uppercase; letter-spacing: .05em; padding: .2em .55em; border-radius: 6px; }
.tl__prioridad--urgente { background: #fef2f2; color: #dc2626; }
.tl__prioridad--alta    { background: #fff7ed; color: #ea580c; }
.tl__prioridad--normal  { background: #eff6ff; color: #2563eb; }
.tl__prioridad--baja    { background: #f0fdf4; color: #16a34a; }
.tl__btn-iniciar, .tl__btn-completar { width: 32px; height: 32px; border-radius: 50%; border: none; cursor: pointer; display: flex; align-items: center; justify-content: center; font-size: .85rem; flex-shrink: 0; transition: all .15s; }
.tl__btn-iniciar  { background: #e8f5e9; color: #1b5e20; }
.tl__btn-iniciar:hover  { background: #1b5e20; color: #fff; }
.tl__btn-completar { background: #fef3c7; color: #b45309; }
.tl__btn-completar:hover { background: #16a34a; color: #fff; }
.tl__btn-iniciar:disabled, .tl__btn-completar:disabled { opacity: .5; cursor: not-allowed; }
/* Modal */
.tl__overlay { position: fixed; inset: 0; background: rgba(0,0,0,.4); display: flex; align-items: center; justify-content: center; z-index: 1060; padding: 1rem; backdrop-filter: blur(3px); }
.tl__modal { background: #fff; border-radius: 16px; width: 100%; max-width: 440px; max-height: 90vh; overflow-y: auto; box-shadow: 0 24px 64px rgba(27,94,32,.15); display: flex; flex-direction: column; }
.tl__modal--wide { max-width: 580px; }
.tl__modal-header { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; padding: 1.1rem 1.5rem 1rem; border-bottom: 1px solid #e8f0e9; position: sticky; top: 0; background: #fff; z-index: 1; }
.tl__modal-title { font-size: 1rem; font-weight: 700; color: #1a1a1a; margin: 0; }
.tl__modal-sub { font-size: .75rem; color: #60725d; margin: .2rem 0 0; }
.tl__modal-close { background: #e8f5e9; border: none; width: 28px; height: 28px; border-radius: 7px; cursor: pointer; display: flex; align-items: center; justify-content: center; color: #60725d; transition: all .15s; flex-shrink: 0; }
.tl__modal-close:hover { background: #c8e6c9; color: #1b5e20; }
.tl__modal-body { padding: 1.1rem 1.5rem; flex: 1; }
.tl__modal-nombre { font-size: .9rem; font-weight: 600; background: #f4f8f4; padding: .65rem .9rem; border-radius: 8px; margin-bottom: 1rem; color: #1a1a1a; }
.tl__modal-footer { display: flex; justify-content: flex-end; gap: .75rem; padding: .9rem 1.5rem; border-top: 1px solid #e8f0e9; position: sticky; bottom: 0; background: #fff; }
.tl__section-title { font-size: .7rem; font-weight: 800; color: #60725d; text-transform: uppercase; letter-spacing: .06em; margin: 1rem 0 .5rem; padding-bottom: .35rem; border-bottom: 1px solid #e8f0e9; }
.tl__grid { display: grid; grid-template-columns: 1fr 1fr; gap: .85rem; }
@media (max-width: 480px) { .tl__grid { grid-template-columns: 1fr; } }
.tl__field { display: flex; flex-direction: column; gap: .3rem; }
.tl__field--full { grid-column: 1 / -1; }
.tl__label { font-size: .75rem; font-weight: 700; color: #374151; text-transform: uppercase; letter-spacing: .04em; }
.tl__optional { font-size: .65rem; font-weight: 400; color: #94a3b8; text-transform: none; letter-spacing: 0; }
.tl__input { background: #f4f8f4; border: 1.5px solid #d4e6d4; border-radius: 8px; padding: .55rem .8rem; font-size: .875rem; color: #1a1a1a; width: 100%; box-sizing: border-box; transition: border .15s; }
.tl__input:focus { outline: none; border-color: #1b5e20; background: #fff; }
.tl__input-group { display: flex; }
.tl__input-group .tl__input { border-radius: 8px 0 0 8px; }
.tl__input-suffix { background: #e8f5e9; border: 1.5px solid #d4e6d4; border-left: none; padding: .55rem .7rem; font-size: .8rem; font-weight: 600; color: #1b5e20; border-radius: 0 8px 8px 0; }
.tl__textarea { resize: vertical; min-height: 56px; }
.tl__selector { display: flex; gap: .4rem; flex-wrap: wrap; }
.tl__sel-btn { display: flex; align-items: center; gap: .3rem; padding: .38rem .75rem; border: 1.5px solid #d4e6d4; border-radius: 8px; background: #f4f8f4; font-size: .78rem; font-weight: 600; cursor: pointer; transition: all .15s; text-transform: capitalize; }
.tl__sel-btn:hover { border-color: #1b5e20; }
.tl__sel-btn--active { transform: translateY(-1px); box-shadow: 0 2px 8px rgba(0,0,0,.08); }
.tl__toggle { display: flex; align-items: center; gap: .6rem; cursor: pointer; }
.tl__toggle-input { display: none; }
.tl__toggle-track { width: 36px; height: 20px; background: #d4e6d4; border-radius: 999px; position: relative; transition: background .2s; flex-shrink: 0; }
.tl__toggle-input:checked + .tl__toggle-track { background: #1b5e20; }
.tl__toggle-thumb { position: absolute; width: 14px; height: 14px; background: #fff; border-radius: 50%; top: 3px; left: 3px; transition: left .2s; box-shadow: 0 1px 3px rgba(0,0,0,.2); }
.tl__toggle-input:checked + .tl__toggle-track .tl__toggle-thumb { left: 19px; }
.tl__toggle-label { font-size: .875rem; font-weight: 500; color: #1a1a1a; }
.tl__alert { background: #fef2f2; border: 1px solid #fecaca; color: #dc2626; padding: .65rem .9rem; border-radius: 8px; font-size: .82rem; margin-bottom: .75rem; }
.tl__btn-ghost { background: transparent; color: #60725d; border: 1px solid #d4e6d4; padding: .55rem 1rem; border-radius: 8px; font-size: .875rem; font-weight: 500; cursor: pointer; transition: all .15s; }
.tl__btn-ghost:hover { background: #f0fdf4; color: #1b5e20; }
.tl__btn-success { display: inline-flex; align-items: center; gap: .4rem; background: #1b5e20; color: #fff; border: none; padding: .55rem 1.1rem; border-radius: 8px; font-size: .875rem; font-weight: 600; cursor: pointer; transition: background .15s; }
.tl__btn-success:hover { background: #104417; }
.tl__btn-success:disabled { opacity: .6; cursor: not-allowed; }
</style>
