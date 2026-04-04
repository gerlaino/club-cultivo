<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { createPlant, listLotes, listGeneticas } from '../lib/api.js'
import api from '../lib/api.js'

const router = useRouter()
const route  = useRoute()

const lotes     = ref([])
const geneticas = ref([])
const saving    = ref(false)
const errors    = ref({})

// Foto
const fotoFile    = ref(null)
const fotoPreview = ref(null)
const fotoInput   = ref(null)

const today = new Date().toISOString().split('T')[0]

// Estados correctos según el modelo
const STATE_META = {
  esqueje:    { label: 'Esqueje',    icon: '✂️',  color: '#7c3aed' },
  germinacion:{ label: 'Semilla',    icon: '🌰',  color: '#92400e' },
  vegetativo: { label: 'Vegetativo', icon: '🌱',  color: '#15803d' },
  floracion:  { label: 'Floración',  icon: '🌸',  color: '#b45309' },
  secado:     { label: 'Secado',     icon: '🍂',  color: '#64748b' },
  cosechado:  { label: 'Cosechado',  icon: '✅',  color: '#0369a1' },
}

const ORIGEN_META = {
  semilla:  { label: 'Semilla',  icon: '🌰' },
  esqueje:  { label: 'Esqueje',  icon: '✂️'  },
  division: { label: 'División', icon: '🪴'  },
}

const form = ref({
  lote_id:           route.query.lote_id ? Number(route.query.lote_id) : '',
  genetica_id:       '',
  state:             'vegetativo',
  origen:            'semilla',
  fecha_germinacion: today,
  fecha_vegetativo:  '',
  fecha_floracion:   '',
  fecha_cosecha:     '',
  peso_seco:         null,
  notas:             '',
})

const loteSeleccionado = computed(() =>
  lotes.value.find(l => l.id === Number(form.value.lote_id)) || null
)

const diasDesdeGerminacion = computed(() => {
  if (!form.value.fecha_germinacion) return null
  const diff = Math.floor((new Date() - new Date(form.value.fecha_germinacion)) / 86400000)
  return diff >= 0 ? diff : null
})

// Nombre autogenerado para el preview
const nombrePreview = computed(() => {
  if (!loteSeleccionado.value) return '—'
  const count = (loteSeleccionado.value.plants_count || 0) + 1
  return `${loteSeleccionado.value.codigo}-P${String(count).padStart(3, '0')}`
})

function onFotoChange(e) {
  const file = e.target.files?.[0]
  if (!file) return
  fotoFile.value    = file
  fotoPreview.value = URL.createObjectURL(file)
}

function quitarFoto() {
  fotoFile.value    = null
  fotoPreview.value = null
  if (fotoInput.value) fotoInput.value.value = ''
}

function validate() {
  const e = {}
  if (!form.value.lote_id) e.lote_id = 'Seleccioná un lote'
  errors.value = e
  return !Object.keys(e).length
}

async function handleSubmit() {
  if (!validate()) return
  saving.value = true
  errors.value = {}
  try {
    let data
    if (fotoFile.value) {
      const fd = new FormData()
      Object.entries(form.value).forEach(([k, v]) => {
        if (v !== '' && v !== null && v !== undefined) fd.append(`plant[${k}]`, v)
      })
      fd.append('foto', fotoFile.value)
      const res = await api.post('/plants', fd, { headers: { 'Content-Type': 'multipart/form-data' } })
      data = res.data
    } else {
      const payload = {}
      Object.entries(form.value).forEach(([k, v]) => {
        if (v !== '' && v !== null && v !== undefined) payload[k] = v
      })
      const res = await api.post('/plants', { plant: payload })
      data = res.data
    }
    router.push(`/plantas/${data.id}`)
  } catch (e) {
    errors.value.general = e.response?.data?.errors?.join(', ') || 'Error al crear la planta'
  } finally {
    saving.value = false
  }
}

onMounted(async () => {
  const [lotesRes, genRes] = await Promise.allSettled([
    listLotes(),
    listGeneticas({ activa: true, disponible: true }),
  ])
  if (lotesRes.status === 'fulfilled') lotes.value    = lotesRes.value.data
  if (genRes.status   === 'fulfilled') geneticas.value = genRes.value.data
})
</script>

<template>
  <div class="pnv container-fluid py-4 px-3 px-md-4">

    <!-- Header -->
    <div class="pnv__header">
      <div>
        <h1 class="pnv__title">Nueva planta</h1>
        <p class="pnv__sub">Registrá una planta en el sistema de trazabilidad</p>
      </div>
      <button class="pnv__btn-ghost" @click="router.back()">
        <i class="bi bi-arrow-left me-1"></i>Volver
      </button>
    </div>

    <div class="pnv__layout">

      <!-- Formulario -->
      <div class="pnv__main">

        <div v-if="errors.general" class="pnv__alert">
          <i class="bi bi-exclamation-triangle-fill"></i>
          {{ errors.general }}
        </div>

        <!-- Lote y genética -->
        <div class="pnv__card">
          <div class="pnv__card-title">Asignación</div>
          <div class="pnv__grid">

            <div class="pnv__field pnv__field--full">
              <label class="pnv__label">Lote <span class="pnv__req">*</span></label>
              <select
                v-model="form.lote_id"
                class="pnv__select"
                :class="{ 'pnv__select--err': errors.lote_id }"
              >
                <option value="">Seleccioná un lote…</option>
                <option v-for="l in lotes" :key="l.id" :value="l.id">
                  {{ l.codigo }} — {{ l.sala?.nombre || 'Sin sala' }} ({{ l.estado }})
                </option>
              </select>
              <span v-if="errors.lote_id" class="pnv__err">{{ errors.lote_id }}</span>
              <div v-if="loteSeleccionado" class="pnv__hint pnv__hint--ok">
                ✓ {{ loteSeleccionado.plants_count }} plantas registradas · ID autogenerado: <strong>{{ nombrePreview }}</strong>
              </div>
            </div>

            <div class="pnv__field pnv__field--full">
              <label class="pnv__label">Genética <span class="pnv__opt">(opcional)</span></label>
              <select v-model="form.genetica_id" class="pnv__select">
                <option value="">Sin genética asignada</option>
                <option v-for="g in geneticas" :key="g.id" :value="g.id">
                  {{ g.nombre }}{{ g.registrada_inase ? ' 🏛️' : '' }} — {{ g.tipo }}
                </option>
              </select>
              <div class="pnv__hint" v-if="!geneticas.length">
                No hay genéticas disponibles para cultivo. Activá alguna en la sección Genéticas.
              </div>
            </div>

          </div>
        </div>

        <!-- Origen y estado -->
        <div class="pnv__card">
          <div class="pnv__card-title">Estado y origen</div>

          <div class="pnv__field">
            <label class="pnv__label">Origen</label>
            <div class="pnv__btn-group">
              <button
                v-for="(meta, key) in ORIGEN_META" :key="key"
                type="button"
                class="pnv__toggle"
                :class="{ 'pnv__toggle--active': form.origen === key }"
                @click="form.origen = key"
              >
                {{ meta.icon }} {{ meta.label }}
              </button>
            </div>
          </div>

          <div class="pnv__field" style="margin-top:1rem">
            <label class="pnv__label">Estado inicial</label>
            <div class="pnv__states">
              <button
                v-for="(meta, key) in STATE_META" :key="key"
                type="button"
                class="pnv__state"
                :class="{ 'pnv__state--active': form.state === key }"
                :style="form.state === key ? { background: meta.color + '18', borderColor: meta.color, color: meta.color } : {}"
                @click="form.state = key"
              >
                <span>{{ meta.icon }}</span>
                <span>{{ meta.label }}</span>
              </button>
            </div>
          </div>
        </div>

        <!-- Foto -->
        <div class="pnv__card">
          <div class="pnv__card-title">Foto <span class="pnv__opt">(opcional)</span></div>
          <div class="pnv__foto-wrap">
            <div v-if="fotoPreview" class="pnv__foto-preview">
              <img :src="fotoPreview" alt="Preview" />
              <button type="button" class="pnv__foto-remove" @click="quitarFoto">
                <i class="bi bi-x-lg"></i>
              </button>
            </div>
            <label v-else class="pnv__foto-placeholder" for="foto-planta">
              <i class="bi bi-camera" style="font-size:1.75rem;color:#94a3b8"></i>
              <span class="pnv__hint" style="margin-top:.5rem">Subir foto de la planta</span>
            </label>
            <input
              id="foto-planta"
              ref="fotoInput"
              type="file"
              accept="image/*"
              class="d-none"
              @change="onFotoChange"
            />
          </div>
        </div>

        <!-- Timeline -->
        <div class="pnv__card">
          <div class="pnv__card-title">Fechas del ciclo</div>
          <p class="pnv__hint" style="margin-bottom:1rem">Completá solo las fechas que ya ocurrieron.</p>
          <div class="pnv__grid">

            <div class="pnv__field">
              <label class="pnv__label">🌰 Germinación / inicio</label>
              <input v-model="form.fecha_germinacion" type="date" class="pnv__input" :max="today" />
              <div v-if="diasDesdeGerminacion !== null" class="pnv__hint pnv__hint--ok">
                {{ diasDesdeGerminacion }} días desde el inicio
              </div>
            </div>

            <div class="pnv__field" v-if="!['esqueje','germinacion'].includes(form.state)">
              <label class="pnv__label">🌱 Inicio vegetativo</label>
              <input v-model="form.fecha_vegetativo" type="date" class="pnv__input" :max="today" />
            </div>

            <div class="pnv__field" v-if="['floracion','secado','cosechado'].includes(form.state)">
              <label class="pnv__label">🌸 Inicio floración</label>
              <input v-model="form.fecha_floracion" type="date" class="pnv__input" :max="today" />
            </div>

            <div class="pnv__field" v-if="form.state === 'cosechado'">
              <label class="pnv__label">✂️ Fecha cosecha</label>
              <input v-model="form.fecha_cosecha" type="date" class="pnv__input" :max="today" />
            </div>

            <div class="pnv__field" v-if="form.state === 'cosechado'">
              <label class="pnv__label">⚖️ Peso seco (g)</label>
              <input v-model.number="form.peso_seco" type="number" step="0.1" min="0" class="pnv__input" placeholder="0.0" />
            </div>

          </div>
        </div>

        <!-- Notas -->
        <div class="pnv__card">
          <div class="pnv__card-title">Notas <span class="pnv__opt">(opcional)</span></div>
          <textarea
            v-model.trim="form.notas"
            class="pnv__input pnv__textarea"
            rows="3"
            placeholder="Observaciones, particularidades, tratamientos…"
          ></textarea>
        </div>

        <!-- Botones -->
        <div class="pnv__footer">
          <button class="pnv__btn-primary" :disabled="saving" @click="handleSubmit">
            <span v-if="saving" class="pnv__spinner"></span>
            <i v-else class="bi bi-check-circle"></i>
            {{ saving ? 'Creando...' : 'Crear planta' }}
          </button>
          <button class="pnv__btn-ghost" :disabled="saving" @click="router.back()">Cancelar</button>
        </div>

      </div>

      <!-- Panel lateral -->
      <div class="pnv__aside">

        <div class="pnv__card pnv__card--preview">
          <div class="pnv__card-title">Preview</div>
          <div class="pnv__preview">
            <div class="pnv__preview-icon">{{ STATE_META[form.state]?.icon }}</div>
            <div class="pnv__preview-id">{{ nombrePreview }}</div>
            <div class="pnv__preview-state" :style="{ color: STATE_META[form.state]?.color }">
              {{ STATE_META[form.state]?.label }}
            </div>
          </div>
          <div class="pnv__preview-meta">
            <div v-if="loteSeleccionado">
              <span class="pnv__meta-label">Lote</span>
              <span>{{ loteSeleccionado.codigo }}</span>
            </div>
            <div v-if="form.genetica_id">
              <span class="pnv__meta-label">Genética</span>
              <span>{{ geneticas.find(g => g.id === Number(form.genetica_id))?.nombre }}</span>
            </div>
            <div>
              <span class="pnv__meta-label">Origen</span>
              <span>{{ ORIGEN_META[form.origen]?.label }}</span>
            </div>
            <div v-if="diasDesdeGerminacion !== null">
              <span class="pnv__meta-label">Días</span>
              <span>{{ diasDesdeGerminacion }}</span>
            </div>
          </div>
        </div>

        <div class="pnv__card pnv__card--info">
          <div class="pnv__card-title">ℹ️ A tener en cuenta</div>
          <ul class="pnv__info-list">
            <li>El <strong>ID de la planta</strong> se genera automáticamente para garantizar trazabilidad</li>
            <li>El <strong>código QR</strong> también se genera solo y podés imprimirlo después</li>
            <li>Las <strong>genéticas</strong> disponibles son las que el club habilitó para cultivo</li>
            <li>Podés cambiar el estado desde el detalle de la planta</li>
          </ul>
        </div>

      </div>
    </div>
  </div>
</template>

<style scoped>
.pnv { font-family: system-ui, -apple-system, sans-serif; color: #0f172a; }
.pnv__header { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; margin-bottom: 2rem; flex-wrap: wrap; }
.pnv__title { font-size: 1.75rem; font-weight: 800; margin: 0 0 .2rem; letter-spacing: -.04em; }
.pnv__sub { font-size: .85rem; color: #64748b; margin: 0; }

.pnv__layout { display: grid; grid-template-columns: 1fr 280px; gap: 1.5rem; align-items: start; }
@media (max-width: 900px) { .pnv__layout { grid-template-columns: 1fr; } }
.pnv__main { display: flex; flex-direction: column; gap: 1.25rem; }
.pnv__aside { display: flex; flex-direction: column; gap: 1.25rem; position: sticky; top: 1.5rem; }

.pnv__card { background: #fff; border: 1px solid #e2e8f0; border-radius: 14px; padding: 1.25rem; }
.pnv__card--preview { text-align: center; }
.pnv__card--info { background: #f8fafc; }
.pnv__card-title { font-size: .875rem; font-weight: 700; color: #0f172a; margin-bottom: .875rem; }

.pnv__grid { display: grid; grid-template-columns: 1fr 1fr; gap: .875rem; }
@media (max-width: 640px) { .pnv__grid { grid-template-columns: 1fr; } }
.pnv__field { display: flex; flex-direction: column; gap: .35rem; }
.pnv__field--full { grid-column: 1 / -1; }

.pnv__label { font-size: .78rem; font-weight: 600; color: #374151; }
.pnv__req { color: #ef4444; }
.pnv__opt { font-size: .72rem; font-weight: 400; color: #94a3b8; }
.pnv__err { font-size: .75rem; color: #ef4444; }
.pnv__hint { font-size: .75rem; color: #64748b; }
.pnv__hint--ok { color: #15803d; font-weight: 500; }

.pnv__input { background: #f8fafc; border: 1.5px solid #e2e8f0; border-radius: 9px; padding: .625rem .875rem; font-size: .875rem; color: #0f172a; width: 100%; box-sizing: border-box; transition: border-color .15s; outline: none; }
.pnv__input:focus { border-color: #1b5e20; background: #fff; }
.pnv__select { background: #f8fafc; border: 1.5px solid #e2e8f0; border-radius: 9px; padding: .625rem .875rem; font-size: .875rem; color: #0f172a; width: 100%; box-sizing: border-box; outline: none; cursor: pointer; }
.pnv__select:focus { border-color: #1b5e20; }
.pnv__select--err { border-color: #ef4444; }
.pnv__textarea { resize: vertical; min-height: 80px; }

.pnv__btn-group { display: flex; gap: .5rem; flex-wrap: wrap; }
.pnv__toggle { padding: .45rem .875rem; border-radius: 8px; border: 1.5px solid #e2e8f0; background: #f8fafc; font-size: .82rem; font-weight: 500; cursor: pointer; color: #475569; transition: all .15s; }
.pnv__toggle--active { background: #1b5e20; border-color: #1b5e20; color: #fff; }

.pnv__states { display: flex; gap: .5rem; flex-wrap: wrap; }
.pnv__state { padding: .5rem .875rem; border-radius: 9px; border: 1.5px solid #e2e8f0; background: #f8fafc; font-size: .8rem; cursor: pointer; display: flex; align-items: center; gap: .4rem; color: #475569; transition: all .15s; }
.pnv__state--active { font-weight: 600; }

.pnv__foto-wrap { display: flex; align-items: center; gap: 1rem; }
.pnv__foto-preview { position: relative; width: 140px; height: 105px; border-radius: 10px; overflow: hidden; border: 1.5px solid #e2e8f0; flex-shrink: 0; }
.pnv__foto-preview img { width: 100%; height: 100%; object-fit: cover; }
.pnv__foto-remove { position: absolute; top: 4px; right: 4px; width: 22px; height: 22px; border-radius: 50%; background: rgba(0,0,0,.6); color: #fff; border: none; display: flex; align-items: center; justify-content: center; font-size: .65rem; cursor: pointer; }
.pnv__foto-placeholder { width: 140px; height: 105px; border-radius: 10px; border: 1.5px dashed #d1d5db; display: flex; flex-direction: column; align-items: center; justify-content: center; cursor: pointer; transition: border-color .15s; flex-shrink: 0; }
.pnv__foto-placeholder:hover { border-color: #1b5e20; }

.pnv__alert { display: flex; align-items: center; gap: .75rem; background: #fef2f2; border: 1px solid #fecaca; color: #dc2626; padding: .875rem 1rem; border-radius: 10px; font-size: .875rem; }

.pnv__footer { display: flex; gap: .75rem; }
.pnv__btn-primary { display: inline-flex; align-items: center; gap: .5rem; background: #1b5e20; color: #fff; border: none; padding: .75rem 1.5rem; border-radius: 10px; font-size: .9rem; font-weight: 600; cursor: pointer; transition: background .15s; }
.pnv__btn-primary:hover:not(:disabled) { background: #144a18; }
.pnv__btn-primary:disabled { opacity: .6; cursor: not-allowed; }
.pnv__btn-ghost { display: inline-flex; align-items: center; gap: .4rem; background: #fff; color: #64748b; border: 1.5px solid #e2e8f0; padding: .75rem 1.25rem; border-radius: 10px; font-size: .875rem; font-weight: 500; cursor: pointer; }
.pnv__btn-ghost:hover { background: #f8fafc; }

.pnv__spinner { width: 16px; height: 16px; border: 2px solid rgba(255,255,255,.3); border-top-color: #fff; border-radius: 50%; animation: pnv-spin .6s linear infinite; }
@keyframes pnv-spin { to { transform: rotate(360deg); } }

.pnv__preview { padding: 1rem 0; }
.pnv__preview-icon { font-size: 2.5rem; margin-bottom: .5rem; }
.pnv__preview-id { font-size: 1.1rem; font-weight: 800; letter-spacing: -.02em; color: #0f172a; margin-bottom: .25rem; }
.pnv__preview-state { font-size: .8rem; font-weight: 700; text-transform: uppercase; letter-spacing: .06em; }
.pnv__preview-meta { display: flex; flex-direction: column; gap: .4rem; border-top: 1px solid #f1f5f9; padding-top: .875rem; margin-top: .875rem; text-align: left; }
.pnv__preview-meta > div { display: flex; justify-content: space-between; font-size: .78rem; }
.pnv__meta-label { color: #94a3b8; font-weight: 500; }

.pnv__info-list { margin: 0; padding-left: 1.25rem; display: flex; flex-direction: column; gap: .5rem; }
.pnv__info-list li { font-size: .8rem; color: #475569; line-height: 1.5; }
</style>
