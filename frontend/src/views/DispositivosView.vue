<script setup>
import { onMounted, ref, computed } from 'vue'
import { useAmbienteStore } from '../stores/ambiente.js'
import { useToast } from '../composables/useToast.js'
import { listSalas } from '../lib/api.js'

// La URL a la que el sensor manda los datos sale de la misma base que usa la app.
const API_BASE = import.meta.env.VITE_API_URL || 'http://localhost:3001/api'
import DispositivoCard from '../components/ambiente/DispositivoCard.vue'

const store = useAmbienteStore()
const toast = useToast()

const loading   = ref(false)
const showForm  = ref(false)
const guardando = ref(false)
const form      = ref(emptyForm())
const formError = ref(null)
const salas     = ref([])

const TIPOS_DISPOSITIVO = [
  // Los dos "Pulse" son de empresas distintas y miden cosas distintas. Estaban los dos
  // etiquetados como "Bluelab Pulse", así que se elegía el equivocado y después se esperaban
  // lecturas que nunca iban a llegar.
  { value: 'pulse',      label: 'Pulse Grow (Pulse One / Pro)', auto: true,
    ayuda: 'Monitor de sala con WiFi: temperatura, humedad y luz, todo el día sin tocar nada.' },
  { value: 'sonoff_th',  label: 'Sonoff TH Elite', auto: true,
    ayuda: 'Temperatura y humedad vía eWeLink.' },
  { value: 'bluelab',    label: 'Bluelab Pulse (medidor de sustrato)', auto: false,
    ayuda: 'Medidor de mano: se clava en la maceta y se lee por Bluetooth. No sube datos solo — sus mediciones se cargan a mano desde la sala.' },
  { value: 'tuya_plug',  label: 'Tuya / Smart Life', auto: true, ayuda: 'Enchufe inteligente.' },
  { value: 'shelly_plug',label: 'Shelly', auto: true, ayuda: 'Enchufe inteligente.' },
  { value: 'daikin',     label: 'Daikin AC', auto: true, ayuda: 'Aire acondicionado.' },
  { value: 'melcloud_ac',label: 'Mitsubishi MelCloud', auto: true, ayuda: 'Aire acondicionado.' },
  { value: 'generic',    label: 'Otro (envía datos por HTTP)', auto: true,
    ayuda: 'Cualquier equipo que pueda hacer una llamada HTTP con los datos.' },
]

function emptyForm() {
  return { nombre_amigable: '', tipo: 'sonoff_th', sala_id: null }
}

onMounted(async () => {
  loading.value = true
  await Promise.all([
    store.cargarDispositivos(),
    listSalas().then(r => { salas.value = r.data || [] }),
  ])
  loading.value = false
})

// Tipo elegido, para saber si el equipo manda datos solo o se carga a mano.
const tipoElegido = computed(() => TIPOS_DISPOSITIVO.find(t => t.value === form.value.tipo))

// Datos de conexión del sensor recién creado: se muestran UNA vez, listos para pegar.
const conexion = ref(null)
async function copiarConexion() {
  const c = conexion.value
  await navigator.clipboard.writeText(`URL: ${c.url}\nToken: ${c.token}`)
  toast.success('Copiado')
}

async function guardar() {
  formError.value = null
  if (!form.value.nombre_amigable.trim()) { formError.value = 'El nombre es obligatorio'; return }
  if (!form.value.sala_id) { formError.value = 'Seleccioná una sala'; return }
  guardando.value = true
  try {
    const creado = await store.createDispositivo({ ...form.value })
    showForm.value = false

    // Conectar era de DOS pasos: crear, y después buscar la card para generar el token. El
    // que conecta un sensor quiere terminar, no cazar un botón. Si el equipo manda datos
    // solo, el token se genera acá y se muestran las instrucciones listas para copiar.
    if (tipoElegido.value?.auto && creado?.id) {
      try {
        const { token } = await store.regenerarToken(creado.id)
        conexion.value = {
          nombre: form.value.nombre_amigable,
          tipo:   tipoElegido.value.label,
          url:    `${API_BASE}/webhooks/lecturas/${creado.id}`,
          token,
        }
      } catch {
        toast.warning('Sensor creado. Generá el token desde su tarjeta para terminar de conectarlo.')
      }
    } else {
      toast.success('Medidor agregado. Sus mediciones se cargan a mano desde la sala.')
    }
    form.value = emptyForm()
  } catch (e) {
    formError.value = e?.response?.data?.errors?.[0] || 'Error al crear'
  } finally {
    guardando.value = false
  }
}

function cancelar() {
  showForm.value = false
  form.value = emptyForm()
  formError.value = null
}
</script>

<template>
  <div class="dv">
    <!-- Header -->
    <div class="dv__header">
      <div>
        <h1 class="dv__title">📡 Dispositivos IoT</h1>
        <p class="dv__sub">Sensores y actuadores conectados al módulo ambiente.</p>
      </div>
      <button class="dv__btn-primary" @click="showForm = !showForm">
        <i class="bi bi-plus-lg"></i> Nuevo dispositivo
      </button>
    </div>

    <!-- Formulario -->
    <div v-if="showForm" class="dv__form-card">
      <div class="dv__form-title">Nuevo dispositivo</div>
      <div v-if="formError" class="dv__alert">{{ formError }}</div>
      <div class="dv__form-grid">
        <div class="dv__field">
          <label class="dv__label">Nombre <span class="dv__req">*</span></label>
          <input class="dv__input" v-model="form.nombre_amigable" placeholder="Ej: Sensor Sala Vegetativo" />
        </div>
        <div class="dv__field">
          <label class="dv__label">Tipo de dispositivo <span class="dv__req">*</span></label>
          <select class="dv__input" v-model="form.tipo">
            <option v-for="t in TIPOS_DISPOSITIVO" :key="t.value" :value="t.value">{{ t.label }}</option>
          </select>
        </div>
        <div class="dv__field dv__field--full">
          <label class="dv__label">Sala asignada <span class="dv__req">*</span></label>
          <select class="dv__input" v-model.number="form.sala_id">
            <option :value="null" disabled>Seleccioná una sala…</option>
            <option v-for="s in salas" :key="s.id" :value="s.id">{{ s.nombre }}</option>
          </select>
        </div>
      </div>

      <!-- Hint Sonoff -->
      <div v-if="form.tipo === 'sonoff_th'" class="dv__hint-box">
        <i class="bi bi-info-circle-fill"></i>
        Después de crear, generá el token y configurá el webhook de eWeLink apuntando a la URL que aparece en la card.
      </div>

      <div class="dv__form-actions">
        <button class="dv__btn-ghost" @click="cancelar">Cancelar</button>
        <button class="dv__btn-primary" :disabled="guardando" @click="guardar">
          {{ guardando ? 'Guardando…' : 'Crear dispositivo' }}
        </button>
      </div>
    </div>

    <!-- Lista -->
    <div v-if="loading" class="dv__loading">Cargando dispositivos…</div>
    <div v-else-if="!store.dispositivos.length" class="dv__empty">
      <div class="dv__empty-icon">📡</div>
      <div class="dv__empty-title">Sin dispositivos todavía</div>
      <div class="dv__empty-sub">Registrá el primer sensor para empezar a recibir lecturas automáticas.</div>
    </div>
    <div v-else class="dv__grid">
      <DispositivoCard
        v-for="d in store.dispositivos"
        :key="d.id"
        :dispositivo="d"
        @deleted="store.cargarDispositivos()"
      />
    </div>
  </div>

    <!-- Datos de conexión del sensor recién creado. El token se ve UNA sola vez. -->
    <Teleport to="body">
      <div v-if="conexion" class="dv-cx-ov" @click.self="conexion = null">
        <div class="dv-cx">
          <h3 class="dv-cx__title">{{ conexion.nombre }} está listo</h3>
          <p class="dv-cx__sub">
            Cargá estos dos datos en la app de {{ conexion.tipo }} y las lecturas empiezan a
            llegar solas. El token se muestra una sola vez.
          </p>
          <div class="dv-cx__row">
            <span class="dv-cx__lbl">URL</span>
            <code class="dv-cx__val">{{ conexion.url }}</code>
          </div>
          <div class="dv-cx__row">
            <span class="dv-cx__lbl">Token</span>
            <code class="dv-cx__val">{{ conexion.token }}</code>
          </div>
          <p class="dv-cx__hint">
            Si se pierde, se genera uno nuevo desde la tarjeta del sensor (el anterior deja de servir).
          </p>
          <div class="dv-cx__acts">
            <button class="dv__btn-ghost" @click="copiarConexion"><i class="bi bi-clipboard"></i> Copiar</button>
            <button class="dv__btn-primary" @click="conexion = null">Listo</button>
          </div>
        </div>
      </div>
    </Teleport>
</template>

<style scoped>
.dv { padding: 1.75rem 1.5rem; max-width: 1000px; margin: 0 auto; font-family: system-ui, -apple-system, sans-serif; }
@media (max-width: 640px) { .dv { padding: 1rem; } }

.dv__header { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; margin-bottom: 1.5rem; flex-wrap: wrap; }
.dv__title { font-size: 1.6rem; font-weight: 800; margin: 0; letter-spacing: -.04em; }
.dv__sub { font-size: .82rem; color: #60725d; margin: .25rem 0 0; }

.dv__form-card { background: #fff; border: 1px solid #d4e6d4; border-radius: 14px; padding: 1.25rem; margin-bottom: 1.5rem; }
.dv__form-title { font-size: .9rem; font-weight: 700; margin-bottom: 1rem; }
.dv__form-grid { display: grid; grid-template-columns: 1fr 1fr; gap: .75rem; }
@media (max-width: 480px) { .dv__form-grid { grid-template-columns: 1fr; } }
.dv__field { display: flex; flex-direction: column; gap: .3rem; }
.dv__field--full { grid-column: 1/-1; }
.dv__label { font-size: .75rem; font-weight: 600; color: #374151; }
.dv__req { color: #dc2626; }
.dv__input {
  background: #f4f8f4; border: 1.5px solid #d4e6d4; border-radius: 8px;
  padding: .55rem .75rem; font-size: .875rem; color: #1a1a1a;
  width: 100%; box-sizing: border-box;
}
.dv__input:focus { outline: none; border-color: #1b5e20; background: #fff; }
.dv__form-actions { display: flex; justify-content: flex-end; gap: .6rem; margin-top: 1rem; }
.dv__alert { background: #fef2f2; border: 1px solid #fecaca; color: #dc2626; padding: .6rem .9rem; border-radius: 8px; font-size: .82rem; margin-bottom: .75rem; }

.dv__hint-box {
  display: flex; align-items: flex-start; gap: .5rem;
  background: #eff6ff; border: 1px solid #bfdbfe; color: #1d4ed8;
  border-radius: 9px; padding: .65rem .875rem; font-size: .8rem; margin-top: .75rem;
}

.dv__loading { padding: 3rem; text-align: center; color: var(--c-slate-400); font-size: .875rem; }
.dv__empty { text-align: center; padding: 4rem 1rem; }
.dv__empty-icon { font-size: 3rem; margin-bottom: .75rem; }
.dv__empty-title { font-size: 1rem; font-weight: 700; color: #1a1a1a; margin-bottom: .35rem; }
.dv__empty-sub { font-size: .82rem; color: var(--c-slate-400); }

.dv__grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(320px, 1fr)); gap: 1rem; }

.dv__btn-primary {
  display: inline-flex; align-items: center; gap: .4rem;
  background: #1b5e20; color: #fff; border: none;
  padding: .6rem 1.25rem; border-radius: 8px; font-size: .875rem; font-weight: 600; cursor: pointer;
}
.dv__btn-primary:hover:not(:disabled) { background: #104417; }
.dv__btn-primary:disabled { opacity: .5; cursor: not-allowed; }
.dv__btn-ghost {
  background: transparent; color: #60725d; border: 1px solid #d4e6d4;
  padding: .6rem 1.1rem; border-radius: 8px; font-size: .875rem;
  font-weight: 500; cursor: pointer; transition: all .15s;
}
.dv__btn-ghost:hover { background: #f0fdf4; }

/* Datos de conexión */
.dv-cx-ov { position: fixed; inset: 0; background: rgba(15,23,42,.5); display: flex; align-items: center; justify-content: center; z-index: 1200; padding: 1rem; }
.dv-cx { background: #fff; border-radius: 16px; max-width: 520px; width: 100%; padding: 1.5rem; box-shadow: 0 24px 64px rgba(0,0,0,.2); }
.dv-cx__title { font-size: 1.05rem; font-weight: 800; color: var(--c-slate-900); margin: 0 0 .35rem; }
.dv-cx__sub { font-size: .85rem; color: var(--c-slate-500); margin: 0 0 1.15rem; line-height: 1.5; }
.dv-cx__row { display: flex; align-items: center; gap: .75rem; margin-bottom: .5rem; }
.dv-cx__lbl { font-size: .7rem; color: var(--c-slate-500); width: 56px; flex-shrink: 0; text-transform: uppercase; letter-spacing: .04em; font-weight: 700; }
.dv-cx__val { font-family: monospace; font-size: .82rem; background: var(--c-slate-50); border: 1px solid var(--c-slate-200); border-radius: 7px; padding: .4rem .65rem; color: var(--c-slate-900); user-select: all; flex: 1; word-break: break-all; }
.dv-cx__hint { font-size: .75rem; color: var(--c-slate-400); margin: .9rem 0 0; }
.dv-cx__acts { display: flex; gap: .6rem; justify-content: flex-end; margin-top: 1.35rem; }
</style>
