<script setup>
import { ref, computed, onMounted } from 'vue'
import QRCode from 'qrcode'
import { useRoute } from 'vue-router'
import { usePlantsStore } from '../stores/plants'
import { useAuthStore }   from '../stores/auth'
import { getPlantActivities, createPlantActivity } from '../lib/api'

const route  = useRoute()
const plants = usePlantsStore()
const auth   = useAuthStore()

const id           = Number(route.params.id)
const error        = ref(null)
const loading      = ref(true)
const planta       = computed(() => plants.current)

const activities       = ref([])
const loadingActs      = ref(false)
const fotosExpanded    = ref(false)
const historialExpanded= ref(true)
const fotos            = ref([])
const fotoInput        = ref(null)
const uploadingFoto    = ref(false)
const qrDataUrl        = ref(null)

async function generarQR() {
  if (!planta.value?.codigo_qr) return
  const url = `https://club.example.com/p/${planta.value.codigo_qr}`
  try {
    qrDataUrl.value = await QRCode.toDataURL(url, {
      width: 200, margin: 2,
      color: { dark: '#1b5e20', light: '#ffffff' }
    })
  } catch {}
}
function descargarQR() {
  if (!qrDataUrl.value) return
  const a = document.createElement('a')
  a.href = qrDataUrl.value
  a.download = `planta-${planta.value.codigo_qr}.png`
  a.click()
}

// Modal registro
const showModal   = ref(false)
const guardando   = ref(false)
const modalError  = ref(null)

function emptyForm() {
  return {
    altura_cm:    null,
    num_colas:    null,
    estado_salud: 'bueno',
    color_hojas:  'verde_oscuro',
    plagas:       'ninguna',
    deficiencias: '',
    notas:        ''
  }
}
const form = ref(emptyForm())

// ── Constantes visuales ───────────────────────────────────
const CICLO_PLANTA = ['semilla', 'vegetativo', 'floracion', 'cosecha', 'finalizado']
const ESTADO_META = {
  semilla:    { label:'Semilla',    color:'#64748b', bg:'#f1f5f9', emoji:'🌰' },
  vegetativo: { label:'Vegetativo', color:'#16a34a', bg:'#dcfce7', emoji:'🍃' },
  floracion:  { label:'Floración',  color:'#d97706', bg:'#fef3c7', emoji:'🌸' },
  cosecha:    { label:'Cosecha',    color:'#92400e', bg:'#fff7ed', emoji:'✂️'  },
  finalizado: { label:'Finalizado', color:'#1b5e20', bg:'#dcfce7', emoji:'✅' },
}
const SALUD_META = {
  excelente: { color:'#16a34a', emoji:'🟢', label:'Excelente' },
  bueno:     { color:'#65a30d', emoji:'🟡', label:'Bueno'     },
  regular:   { color:'#d97706', emoji:'🟠', label:'Regular'   },
  malo:      { color:'#dc2626', emoji:'🔴', label:'Malo'      },
  critico:   { color:'#991b1b', emoji:'🚨', label:'Crítico'   },
}
const COLOR_HOJAS_META = {
  verde_oscuro: { emoji:'🟢', label:'Verde oscuro', hint:'Óptimo'    },
  verde_claro:  { emoji:'🟩', label:'Verde claro',  hint:'Normal'    },
  amarillo:     { emoji:'🟡', label:'Amarillo',     hint:'Atención'  },
  marron:       { emoji:'🟤', label:'Marrón',       hint:'Problema'  },
}
const PLAGAS_META = {
  ninguna:  { color:'#16a34a', emoji:'✅', label:'Ninguna'  },
  leve:     { color:'#d97706', emoji:'⚠️', label:'Leve'     },
  moderada: { color:'#ea580c', emoji:'🐛', label:'Moderada' },
  severa:   { color:'#dc2626', emoji:'🚨', label:'Severa'   },
}

function em(e)  { return ESTADO_META[e]    || { label:e||'—', color:'#64748b', bg:'#f1f5f9', emoji:'🌿' } }
function sm(s)  { return SALUD_META[s]     || { color:'#94a3b8', emoji:'⚪', label:s||'—' } }
function pgm(p) { return PLAGAS_META[p]    || { color:'#94a3b8', emoji:'—', label:p||'—' } }
function chm(c) { return COLOR_HOJAS_META[c] || { emoji:'🌿', label:c||'—', hint:'' } }

function growLabel(g)  { return { sustrato:'Sustrato', hidroponia:'Hidroponia', aeroponia:'Aeroponia' }[g]||g||'—' }
function origenLabel(o){ return { semilla:'Semilla', esqueje:'Esqueje', clonacion:'Clonación' }[o]||o||'—' }
function formatDate(d) {
  if (!d) return '—'
  return new Date(d).toLocaleDateString('es-AR', { day:'numeric', month:'long', year:'numeric' })
}
function formatDateTime(d) {
  if (!d) return '—'
  return new Date(d).toLocaleString('es-AR', { day:'numeric', month:'short', hour:'2-digit', minute:'2-digit' })
}

// ── Datos computados ──────────────────────────────────────
const cicloIndex = computed(() => {
  if (!planta.value) return -1
  return CICLO_PLANTA.indexOf(planta.value.state)
})

const diasEnCiclo = computed(() => {
  if (!planta.value?.created_at) return 0
  return Math.floor((Date.now() - new Date(planta.value.created_at)) / 86400000)
})

const ultimoRegistro = computed(() => {
  return activities.value.find(a => a.activity_type === 'registro_planta') || null
})

const alturaActual = computed(() => {
  const r = ultimoRegistro.value
  return r?.metadata?.altura_cm || planta.value?.altura_actual || null
})

// ── Acciones ──────────────────────────────────────────────
async function loadActivities() {
  loadingActs.value = true
  try {
    const { data } = await getPlantActivities(id)
    activities.value = data || []
  } catch { activities.value = [] }
  finally { loadingActs.value = false }
}

function abrirModal() {
  const last = ultimoRegistro.value?.metadata
  form.value = {
    altura_cm:    last?.altura_cm    || null,
    num_colas:    last?.num_colas    || null,
    estado_salud: last?.estado_salud || 'bueno',
    color_hojas:  last?.color_hojas  || 'verde_oscuro',
    plagas:       last?.plagas       || 'ninguna',
    deficiencias: '',
    notas:        ''
  }
  modalError.value = null
  showModal.value = true
}

async function guardarRegistro() {
  guardando.value = true; modalError.value = null
  try {
    const { data } = await createPlantActivity(id, {
      activity_type: 'registro_planta',
      description:   form.value.notas || null,
      metadata: {
        altura_cm:    form.value.altura_cm,
        num_colas:    form.value.num_colas,
        estado_salud: form.value.estado_salud,
        color_hojas:  form.value.color_hojas,
        plagas:       form.value.plagas,
        deficiencias: form.value.deficiencias,
      }
    })
    activities.value.unshift(data)
    if (plants.current) {
      plants.current.altura_actual = form.value.altura_cm
      plants.current.estado_salud  = form.value.estado_salud
    }
    showModal.value = false
  } catch(e) {
    modalError.value = e?.response?.data?.errors?.join(', ') || 'Error al guardar'
  }
  finally { guardando.value = false }
}

function toggleFotos() {
  fotosExpanded.value = !fotosExpanded.value
}

onMounted(async () => {
  try {
    await plants.fetchOne(id)
    await generarQR()
  } catch { error.value = 'No se pudo cargar la planta.' }
  await loadActivities()
  loading.value = false
})
</script>

<template>
  <div class="pd">

    <div v-if="loading" class="pd__loading">
      <div class="pd__spinner"></div>
      <span>Cargando planta…</span>
    </div>
    <div v-else-if="error" class="pd__error">{{ error }}</div>
    <div v-else-if="!planta" class="pd__error">Planta no encontrada.</div>

    <template v-else>

      <!-- Breadcrumb -->
      <nav class="pd__breadcrumb">
        <RouterLink v-if="planta.lote?.sala" :to="{ name:'sala-detail', params:{ id: planta.lote.sala.id } }" class="pd__bc-link">
          {{ planta.lote.sala.nombre }}
        </RouterLink>
        <span class="pd__bc-sep">›</span>
        <RouterLink v-if="planta.lote" :to="{ name:'lote-detail', params:{ id: planta.lote.id } }" class="pd__bc-link">
          {{ planta.lote.codigo }}
        </RouterLink>
        <span class="pd__bc-sep">›</span>
        <span class="pd__bc-current">{{ planta.nombre || planta.codigo_qr }}</span>
      </nav>

      <!-- Hero -->
      <div class="pd__hero">
        <div class="pd__hero-left">
          <div class="pd__hero-row">
            <span class="pd__hero-emoji">{{ em(planta.state).emoji }}</span>
            <h1 class="pd__title">{{ planta.nombre || `Planta #${planta.id}` }}</h1>
            <span class="pd__estado-pill" :style="{ background: em(planta.state).bg, color: em(planta.state).color }">
              {{ em(planta.state).label }}
            </span>
            <span v-if="planta.estado_salud" class="pd__salud-pill" :style="{ color: sm(planta.estado_salud).color }">
              {{ sm(planta.estado_salud).emoji }} {{ sm(planta.estado_salud).label }}
            </span>
          </div>
          <div class="pd__hero-meta">
            <span class="pd__qr-code">{{ planta.codigo_qr }}</span>
            <span class="pd__bc-sep">·</span>
            <span>{{ planta.lote?.strain || planta.genetica?.nombre || '—' }}</span>
            <span class="pd__bc-sep">·</span>
            <span>Día {{ diasEnCiclo }}</span>
          </div>
        </div>
        <button class="pd__btn-primary" @click="abrirModal">
          <i class="bi bi-clipboard2-pulse"></i>Registrar planta
        </button>
      </div>

      <!-- Timeline ciclo -->
      <div class="pd__ciclo">
        <div class="pd__ciclo-track">
          <div v-for="(etapa, i) in CICLO_PLANTA" :key="etapa" class="pd__ciclo-step"
               :class="{ 'pd__ciclo-step--done': i < cicloIndex, 'pd__ciclo-step--current': i === cicloIndex, 'pd__ciclo-step--pending': i > cicloIndex }">
            <div class="pd__ciclo-dot">
              <span>{{ em(etapa).emoji }}</span>
            </div>
            <div class="pd__ciclo-label">{{ em(etapa).label }}</div>
            <div v-if="i < CICLO_PLANTA.length - 1" class="pd__ciclo-line"
                 :class="{ 'pd__ciclo-line--done': i < cicloIndex }"></div>
          </div>
        </div>
      </div>

      <!-- KPIs rápidos -->
      <div class="pd__kpis">
        <div class="pd__kpi" :class="{ 'pd__kpi--ok': alturaActual }">
          <div class="pd__kpi-icon">📏</div>
          <div class="pd__kpi-body">
            <div class="pd__kpi-value">{{ alturaActual ? alturaActual + ' cm' : '—' }}</div>
            <div class="pd__kpi-label">Altura actual</div>
          </div>
        </div>
        <div class="pd__kpi">
          <div class="pd__kpi-icon">🌿</div>
          <div class="pd__kpi-body">
            <div class="pd__kpi-value">{{ planta.num_colas || ultimoRegistro?.metadata?.num_colas || '—' }}</div>
            <div class="pd__kpi-label">Colas</div>
          </div>
        </div>
        <div class="pd__kpi">
          <div class="pd__kpi-icon">📋</div>
          <div class="pd__kpi-body">
            <div class="pd__kpi-value">{{ activities.filter(a => a.activity_type === 'registro_planta').length }}</div>
            <div class="pd__kpi-label">Registros</div>
          </div>
        </div>
        <div class="pd__kpi">
          <div class="pd__kpi-icon">📅</div>
          <div class="pd__kpi-body">
            <div class="pd__kpi-value">{{ diasEnCiclo }}</div>
            <div class="pd__kpi-label">Días</div>
          </div>
        </div>
      </div>

      <!-- Layout -->
      <div class="pd__layout">
        <div class="pd__main">

          <!-- Historial completo -->
          <div class="pd__section">
            <button class="pd__section-toggle" @click="historialExpanded = !historialExpanded">
              <div class="pd__stl">
                <span class="pd__s-emoji">📜</span>
                <span class="pd__s-title">Historial de la planta</span>
              </div>
              <i class="bi pd__chevron" :class="historialExpanded ? 'bi-chevron-up' : 'bi-chevron-down'"></i>
            </button>
            <div v-show="historialExpanded" class="pd__section-body pd__section-body--flush">
              <div v-if="loadingActs" class="pd__placeholder">Cargando historial…</div>
              <div v-else-if="activities.length === 0" class="pd__empty">
                <div class="pd__empty-icon">📋</div>
                <p>Sin registros todavía</p>
                <button class="pd__btn-outline" @click="abrirModal">Hacer primer registro</button>
              </div>
              <div v-else class="pd__actividades">
                <div v-for="a in activities" :key="a.id" class="pd__actividad">
                  <div class="pd__act-dot"
                       :style="{ background: a.activity_type === 'registro_planta' ? '#0891b2' : '#64748b' }">
                  </div>
                  <div class="pd__act-content">
                    <div class="pd__act-head">
                      <template v-if="a.activity_type === 'registro_planta'">
                        <div class="pd__act-titulo">
                          🌱 Registro de planta
                          <span v-if="a.metadata?.estado_salud" :style="{ color: sm(a.metadata.estado_salud).color }">
                            · {{ sm(a.metadata.estado_salud).emoji }} {{ sm(a.metadata.estado_salud).label }}
                          </span>
                          <span v-if="a.metadata?.plagas && a.metadata.plagas !== 'ninguna'"
                                :style="{ color: pgm(a.metadata.plagas).color }">
                            · {{ pgm(a.metadata.plagas).emoji }} {{ pgm(a.metadata.plagas).label }}
                          </span>
                        </div>
                        <div class="pd__act-metricas">
                          <div v-if="a.metadata?.altura_cm"   class="pd__metrica"><span>📏</span><span>{{ a.metadata.altura_cm }} cm</span></div>
                          <div v-if="a.metadata?.num_colas"   class="pd__metrica"><span>🌿</span><span>{{ a.metadata.num_colas }} colas</span></div>
                          <div v-if="a.metadata?.color_hojas" class="pd__metrica">
                            <span>{{ chm(a.metadata.color_hojas).emoji }}</span>
                            <span>{{ chm(a.metadata.color_hojas).label }}</span>
                          </div>
                        </div>
                        <div v-if="a.metadata?.deficiencias" class="pd__act-desc">
                          <strong>Deficiencias:</strong> {{ a.metadata.deficiencias }}
                        </div>
                        <div v-if="a.description" class="pd__act-desc">{{ a.description }}</div>
                      </template>
                      <template v-else>
                        <div class="pd__act-titulo">{{ a.activity_type }} <span v-if="a.description">· {{ a.description }}</span></div>
                      </template>
                    </div>
                    <div class="pd__act-footer">
                      <span class="pd__act-usuario">{{ a.usuario }}</span>
                      <span class="pd__act-fecha">{{ formatDateTime(a.occurred_at) }}</span>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <!-- Fotos de la planta -->
          <div class="pd__section pd__section--mt">
            <button class="pd__section-toggle" @click="toggleFotos">
              <div class="pd__stl">
                <span class="pd__s-emoji">📷</span>
                <span class="pd__s-title">Fotos de la planta</span>
                <span v-if="fotos.length > 0" class="pd__pill">{{ fotos.length }}</span>
              </div>
              <div class="pd__str">
                <button class="pd__btn-sm" @click.stop="fotoInput?.click()" :disabled="uploadingFoto">
                  <span v-if="uploadingFoto" class="pd__spinner" style="width:12px;height:12px;border-width:1.5px"></span>
                  <i v-else class="bi bi-camera-fill"></i>
                </button>
                <i class="bi pd__chevron" :class="fotosExpanded ? 'bi-chevron-up' : 'bi-chevron-down'"></i>
              </div>
            </button>
            <input ref="fotoInput" type="file" accept="image/*" style="display:none" @change="handleFotoUpload" />
            <div v-show="fotosExpanded" class="pd__section-body">
              <div v-if="fotos.length === 0" class="pd__empty pd__empty--sm">
                <div class="pd__empty-icon" style="font-size:2rem">📷</div>
                <p>Sin fotos todavía</p>
                <button class="pd__btn-outline" @click="fotoInput?.click()">
                  <i class="bi bi-camera-fill"></i> Subir primera foto
                </button>
              </div>
              <div v-else class="pd__fotos-grid">
                <div v-for="f in fotos" :key="f.id" class="pd__foto">
                  <img :src="f.url" :alt="f.filename" class="pd__foto-img" />
                  <div class="pd__foto-meta">{{ f.created_at_label }}</div>
                </div>
              </div>
            </div>
          </div>

        </div>

        <!-- Aside -->
        <div class="pd__aside">

          <!-- Datos técnicos -->
          <div class="pd__card">
            <div class="pd__card-header"><span class="pd__card-title">⚙️ Datos técnicos</span></div>
            <dl class="pd__dl">
              <dt>Código</dt><dd class="pd__mono">{{ planta.codigo_qr || '—' }}</dd>
              <dt>Origen</dt><dd>{{ origenLabel(planta.origen) }}</dd>
              <dt>Genética</dt><dd>{{ planta.lote?.strain || planta.genetica?.nombre || '—' }}</dd>
              <dt>Tipo cultivo</dt><dd>{{ growLabel(planta.lote?.grow_type) }}</dd>
              <dt>Maceta</dt><dd>{{ planta.lote?.tamanio_maceta ? planta.lote.tamanio_maceta + 'L' : '—' }}</dd>
              <dt>Sustrato</dt><dd>{{ planta.lote?.sustrato_especifico || '—' }}</dd>
              <dt>Ingreso lote</dt><dd>{{ formatDate(planta.created_at) }}</dd>
            </dl>
          </div>

          <!-- Estado actual -->
          <div class="pd__card pd__card--mt" v-if="ultimoRegistro">
            <div class="pd__card-header"><span class="pd__card-title">📊 Último estado</span></div>
            <div class="pd__estado-card">
              <div class="pd__estado-row">
                <span class="pd__estado-label">Salud</span>
                <span :style="{ color: sm(ultimoRegistro.metadata?.estado_salud).color }">
                  {{ sm(ultimoRegistro.metadata?.estado_salud).emoji }}
                  {{ sm(ultimoRegistro.metadata?.estado_salud).label }}
                </span>
              </div>
              <div class="pd__estado-row">
                <span class="pd__estado-label">Hojas</span>
                <span>{{ chm(ultimoRegistro.metadata?.color_hojas).emoji }} {{ chm(ultimoRegistro.metadata?.color_hojas).label }}</span>
              </div>
              <div class="pd__estado-row">
                <span class="pd__estado-label">Plagas</span>
                <span :style="{ color: pgm(ultimoRegistro.metadata?.plagas).color }">
                  {{ pgm(ultimoRegistro.metadata?.plagas).emoji }} {{ pgm(ultimoRegistro.metadata?.plagas).label }}
                </span>
              </div>
              <div v-if="ultimoRegistro.metadata?.deficiencias" class="pd__estado-row">
                <span class="pd__estado-label">Deficiencias</span>
                <span class="pd__estado-val-sm">{{ ultimoRegistro.metadata.deficiencias }}</span>
              </div>
              <div class="pd__estado-fecha">
                Actualizado {{ formatDateTime(ultimoRegistro.occurred_at) }}
              </div>
            </div>
          </div>

          <!-- Peso seco si está cosechada -->
          <div v-if="planta.peso_seco" class="pd__card pd__card--mt pd__card--harvest">
            <div class="pd__card-header"><span class="pd__card-title">⚖️ Cosecha</span></div>
            <div class="pd__harvest-val">{{ planta.peso_seco }}g</div>
            <div class="pd__harvest-sub">peso seco</div>
          </div>

          <!-- QR -->
          <div class="pd__card pd__card--mt">
            <div class="pd__card-header"><span class="pd__card-title">📱 Código QR</span></div>
            <div class="pd__qr-body">
              <img v-if="qrDataUrl" :src="qrDataUrl" alt="QR" class="pd__qr-img" />
              <div v-else class="pd__qr-placeholder">Generando…</div>
              <div class="pd__qr-hint">Escaneá para ver info pública de la planta</div>
              <button v-if="qrDataUrl" class="pd__btn-outline pd__btn-qr-dl" @click="descargarQR">
                <i class="bi bi-download"></i> Descargar QR
              </button>
            </div>
          </div>

        </div>
      </div>

    </template>

    <!-- ══ Modal Registro de Planta ══ -->
    <Teleport to="body">
      <div v-if="showModal" class="pd__overlay" @click.self="showModal = false">
        <div class="pd__modal">
          <div class="pd__modal-header">
            <div>
              <h3 class="pd__modal-title">🌱 Registrar planta</h3>
              <p class="pd__modal-sub">{{ planta?.nombre || planta?.codigo_qr }} · hoy {{ new Date().toLocaleDateString('es-AR') }}</p>
            </div>
            <button class="pd__modal-close" @click="showModal = false"><i class="bi bi-x-lg"></i></button>
          </div>
          <div class="pd__modal-body">
            <div v-if="modalError" class="pd__alert">{{ modalError }}</div>

            <!-- Estado de salud -->
            <div class="pd__msection">Estado general</div>
            <div class="pd__field pd__field--full">
              <div class="pd__selector">
                <button v-for="(meta, key) in SALUD_META" :key="key" type="button"
                        class="pd__sel-btn"
                        :class="{ 'pd__sel-btn--active': form.estado_salud === key }"
                        :style="form.estado_salud===key ? { borderColor:meta.color, background:meta.color+'15', color:meta.color } : {}"
                        @click="form.estado_salud = key">
                  {{ meta.emoji }} {{ meta.label }}
                </button>
              </div>
            </div>

            <!-- Métricas -->
            <div class="pd__msection">Métricas</div>
            <div class="pd__mgrid">
              <div class="pd__field">
                <label class="pd__label">Altura (cm)</label>
                <div class="pd__input-group">
                  <input type="number" step="0.5" min="0" class="pd__input" v-model.number="form.altura_cm" placeholder="45.0" />
                  <span class="pd__input-suffix">cm</span>
                </div>
              </div>
              <div class="pd__field">
                <label class="pd__label">Colas / ramas</label>
                <input type="number" min="1" step="1" class="pd__input" v-model.number="form.num_colas" placeholder="4" />
              </div>
            </div>

            <!-- Color de hojas -->
            <div class="pd__msection">Color de hojas</div>
            <div class="pd__field pd__field--full">
              <div class="pd__selector">
                <button v-for="(meta, key) in COLOR_HOJAS_META" :key="key" type="button"
                        class="pd__sel-btn"
                        :class="{ 'pd__sel-btn--active': form.color_hojas === key }"
                        :style="form.color_hojas===key ? { borderColor:'#1b5e20', background:'#e8f5e9', color:'#1b5e20' } : {}"
                        @click="form.color_hojas = key">
                  {{ meta.emoji }} {{ meta.label }}
                  <span class="pd__sel-hint">{{ meta.hint }}</span>
                </button>
              </div>
            </div>

            <!-- Plagas -->
            <div class="pd__msection">Plagas observadas</div>
            <div class="pd__field pd__field--full">
              <div class="pd__selector">
                <button v-for="(meta, key) in PLAGAS_META" :key="key" type="button"
                        class="pd__sel-btn"
                        :class="{ 'pd__sel-btn--active': form.plagas === key }"
                        :style="form.plagas===key ? { borderColor:meta.color, background:meta.color+'15', color:meta.color } : {}"
                        @click="form.plagas = key">
                  {{ meta.emoji }} {{ meta.label }}
                </button>
              </div>
            </div>

            <!-- Deficiencias -->
            <div class="pd__msection">Observaciones <span class="pd__optional">opcional</span></div>
            <div class="pd__mgrid">
              <div class="pd__field pd__field--full">
                <label class="pd__label">Deficiencias observadas</label>
                <input type="text" class="pd__input" v-model.trim="form.deficiencias"
                       placeholder="Ej: déficit de nitrógeno en hojas bajas" />
              </div>
              <div class="pd__field pd__field--full">
                <label class="pd__label">Notas libres</label>
                <textarea class="pd__input pd__textarea" rows="2" v-model.trim="form.notas"
                          placeholder="Cualquier observación relevante…"></textarea>
              </div>
            </div>
          </div>
          <div class="pd__modal-footer">
            <button class="pd__btn-ghost" @click="showModal = false">Cancelar</button>
            <button class="pd__btn-primary" @click="guardarRegistro" :disabled="guardando">
              <span v-if="guardando" class="pd__spinner pd__spinner--sm"></span>
              <i v-else class="bi bi-check-lg"></i>Guardar registro
            </button>
          </div>
        </div>
      </div>
    </Teleport>

  </div>
</template>

<style scoped>
.pd { padding: 1.75rem 1.5rem; max-width: 1200px; margin: 0 auto; font-family: system-ui, -apple-system, sans-serif; color: #1a1a1a; }
@media (max-width: 640px) { .pd { padding: 1rem; } }

/* Loading / Error */
.pd__loading { display: flex; align-items: center; justify-content: center; gap: .75rem; padding: 5rem; color: #94a3b8; font-size: .875rem; }
.pd__error   { padding: 1rem 1.25rem; background: #fef2f2; border: 1px solid #fecaca; color: #dc2626; border-radius: 10px; font-size: .875rem; }
.pd__spinner { width: 20px; height: 20px; border: 2.5px solid rgba(27,94,32,.2); border-top-color: #1b5e20; border-radius: 50%; animation: pd-spin .6s linear infinite; flex-shrink: 0; }
.pd__spinner--sm { width: 13px; height: 13px; border-color: rgba(255,255,255,.3); border-top-color: #fff; }
@keyframes pd-spin { to { transform: rotate(360deg); } }

/* Breadcrumb */
.pd__breadcrumb { display: flex; align-items: center; gap: .4rem; font-size: .78rem; margin-bottom: 1.25rem; flex-wrap: wrap; }
.pd__bc-link    { color: #94a3b8; text-decoration: none; transition: color .15s; }
.pd__bc-link:hover { color: #1b5e20; }
.pd__bc-sep     { color: #cbd5e1; }
.pd__bc-current { color: #1a1a1a; font-weight: 600; }

/* Hero */
.pd__hero { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; margin-bottom: 1.5rem; flex-wrap: wrap; }
.pd__hero-row { display: flex; align-items: center; gap: .6rem; flex-wrap: wrap; margin-bottom: .3rem; }
.pd__hero-emoji { font-size: 1.8rem; }
.pd__title { font-size: 1.75rem; font-weight: 800; margin: 0; letter-spacing: -.04em; }
.pd__estado-pill { font-size: .68rem; font-weight: 800; text-transform: uppercase; letter-spacing: .08em; padding: .28em .75em; border-radius: 999px; }
.pd__salud-pill  { font-size: .75rem; font-weight: 700; }
.pd__hero-meta { font-size: .82rem; color: #60725d; display: flex; align-items: center; gap: .4rem; flex-wrap: wrap; }
.pd__qr-code { font-family: monospace; font-size: .75rem; color: #94a3b8; }

/* Ciclo */
.pd__ciclo { background: #fff; border: 1px solid #d4e6d4; border-radius: 14px; padding: 1.1rem 1.5rem .9rem; margin-bottom: 1.5rem; overflow-x: auto; }
.pd__ciclo-track { display: flex; align-items: flex-start; min-width: 380px; }
.pd__ciclo-step  { display: flex; flex-direction: column; align-items: center; flex: 1; position: relative; }
.pd__ciclo-dot   { width: 34px; height: 34px; border-radius: 50%; background: #e8f5e9; border: 2px solid #d4e6d4; display: flex; align-items: center; justify-content: center; margin-bottom: .35rem; font-size: .85rem; position: relative; z-index: 1; transition: all .2s; }
.pd__ciclo-label { font-size: .6rem; font-weight: 600; color: #94a3b8; text-transform: uppercase; letter-spacing: .04em; text-align: center; }
.pd__ciclo-step--done .pd__ciclo-dot   { background: #dcfce7; border-color: #16a34a; }
.pd__ciclo-step--done .pd__ciclo-label { color: #16a34a; }
.pd__ciclo-step--current .pd__ciclo-dot { background: #1b5e20; border-color: #1b5e20; box-shadow: 0 0 0 4px rgba(27,94,32,.15); }
.pd__ciclo-step--current .pd__ciclo-label { color: #1b5e20; font-weight: 800; }
.pd__ciclo-step--pending { opacity: .4; }
.pd__ciclo-line { position: absolute; top: 16px; left: 50%; width: 100%; height: 2px; background: #d4e6d4; }
.pd__ciclo-line--done { background: #16a34a; }

/* KPIs */
.pd__kpis { display: grid; grid-template-columns: repeat(4,1fr); gap: 1rem; margin-bottom: 1.75rem; }
@media (max-width: 640px) { .pd__kpis { grid-template-columns: repeat(2,1fr); } }
.pd__kpi { background: #fff; border: 1px solid #d4e6d4; border-radius: 14px; padding: 1rem; display: flex; align-items: center; gap: .75rem; transition: box-shadow .15s; }
.pd__kpi:hover { box-shadow: 0 4px 16px rgba(27,94,32,.1); }
.pd__kpi--ok { border-color: #a7d7a9; background: #f0fdf4; }
.pd__kpi-icon { font-size: 1.4rem; flex-shrink: 0; }
.pd__kpi-body { flex: 1; min-width: 0; }
.pd__kpi-value { font-size: 1.4rem; font-weight: 800; color: #1a1a1a; line-height: 1; letter-spacing: -.03em; }
.pd__kpi-label { font-size: .68rem; color: #60725d; font-weight: 600; text-transform: uppercase; letter-spacing: .04em; margin-top: .2rem; }

/* Layout */
.pd__layout { display: grid; grid-template-columns: 1fr 280px; gap: 1.25rem; align-items: start; }
@media (max-width: 900px) { .pd__layout { grid-template-columns: 1fr; } }

/* Sections */
.pd__section { background: #fff; border: 1px solid #d4e6d4; border-radius: 14px; overflow: hidden; }
.pd__section--mt { margin-top: 1.25rem; }
.pd__section-toggle { width: 100%; display: flex; align-items: center; justify-content: space-between; padding: .9rem 1.1rem; background: transparent; border: none; cursor: pointer; transition: background .15s; text-align: left; }
.pd__section-toggle:hover { background: #f0fdf4; }
.pd__stl { display: flex; align-items: center; gap: .6rem; }
.pd__str { display: flex; align-items: center; gap: .5rem; }
.pd__s-emoji { font-size: 1rem; }
.pd__s-title { font-size: .9rem; font-weight: 700; color: #1a1a1a; }
.pd__pill { background: #e8f5e9; color: #1b5e20; font-size: .68rem; font-weight: 700; padding: .15em .55em; border-radius: 999px; }
.pd__chevron { color: #60725d; font-size: .75rem; }
.pd__section-body { border-top: 1px solid #e8f0e9; padding: 1rem 1.1rem; }
.pd__section-body--flush { border-top: 1px solid #e8f0e9; padding: 0; }
.pd__placeholder { padding: 1rem 1.1rem; color: #94a3b8; font-size: .875rem; }
.pd__empty { text-align: center; padding: 2rem 1rem; color: #60725d; }
.pd__empty--sm { padding: 1.25rem 1rem; }
.pd__empty-icon { font-size: 2.5rem; margin-bottom: .5rem; }
.pd__empty p { font-size: .875rem; margin: 0 0 .75rem; }

/* Actividades / historial */
.pd__actividades { display: flex; flex-direction: column; }
.pd__actividad   { display: flex; gap: .75rem; padding: .9rem 1.1rem; border-bottom: 1px solid #f0fdf4; }
.pd__actividad:last-child { border-bottom: none; }
.pd__act-dot { width: 10px; height: 10px; border-radius: 50%; flex-shrink: 0; margin-top: .3rem; }
.pd__act-content { flex: 1; min-width: 0; }
.pd__act-head { margin-bottom: .35rem; }
.pd__act-titulo { font-size: .875rem; font-weight: 600; color: #1a1a1a; margin-bottom: .3rem; }
.pd__act-metricas { display: flex; flex-wrap: wrap; gap: .4rem; margin-bottom: .25rem; }
.pd__metrica { display: flex; align-items: center; gap: .25rem; background: #f4f8f4; border: 1px solid #d4e6d4; border-radius: 6px; padding: .2em .55em; font-size: .72rem; font-weight: 600; color: #1a1a1a; }
.pd__act-desc { font-size: .75rem; color: #60725d; font-style: italic; margin-top: .2rem; }
.pd__act-footer { display: flex; align-items: center; justify-content: space-between; margin-top: .35rem; }
.pd__act-usuario { font-size: .7rem; color: #94a3b8; }
.pd__act-fecha   { font-size: .7rem; color: #94a3b8; }

/* Fotos */
.pd__fotos-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(130px, 1fr)); gap: .75rem; }
.pd__foto { border-radius: 10px; overflow: hidden; border: 1px solid #d4e6d4; }
.pd__foto-img { width: 100%; height: 110px; object-fit: cover; display: block; }
.pd__foto-meta { font-size: .65rem; color: #94a3b8; padding: .3rem .5rem; background: #f4f8f4; text-align: center; }

/* Aside */
.pd__aside {}
.pd__card { background: #fff; border: 1px solid #d4e6d4; border-radius: 14px; overflow: hidden; }
.pd__card--mt { margin-top: 1rem; }
.pd__card--harvest { border-color: #a7d7a9; border-left: 4px solid #16a34a; text-align: center; padding: 1rem; }
.pd__card-header { display: flex; align-items: center; justify-content: space-between; padding: .75rem 1rem; border-bottom: 1px solid #e8f0e9; }
.pd__card-title  { font-size: .85rem; font-weight: 700; color: #1a1a1a; }
.pd__dl { display: grid; grid-template-columns: auto 1fr; gap: .4rem .75rem; padding: .9rem 1rem; margin: 0; }
.pd__dl dt { font-size: .73rem; color: #60725d; font-weight: 500; white-space: nowrap; }
.pd__dl dd { font-size: .78rem; color: #1a1a1a; font-weight: 500; margin: 0; }
.pd__mono { font-family: monospace; font-size: .72rem; color: #94a3b8; }
.pd__estado-card { padding: .85rem 1rem; display: flex; flex-direction: column; gap: .5rem; }
.pd__estado-row  { display: flex; align-items: center; justify-content: space-between; font-size: .8rem; }
.pd__estado-label { color: #60725d; font-weight: 500; }
.pd__estado-val-sm { font-size: .72rem; color: #1a1a1a; text-align: right; max-width: 120px; }
.pd__estado-fecha { font-size: .68rem; color: #94a3b8; margin-top: .25rem; text-align: right; }
.pd__harvest-val { font-size: 2rem; font-weight: 800; color: #1b5e20; }
.pd__harvest-sub { font-size: .75rem; color: #60725d; }

/* Modal */
.pd__overlay { position: fixed; inset: 0; background: rgba(0,0,0,.4); display: flex; align-items: center; justify-content: center; z-index: 1050; padding: 1rem; backdrop-filter: blur(3px); }
.pd__modal { background: #fff; border-radius: 16px; width: 100%; max-width: 520px; max-height: 92vh; overflow-y: auto; box-shadow: 0 24px 64px rgba(27,94,32,.15); display: flex; flex-direction: column; }
.pd__modal-header { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; padding: 1.1rem 1.5rem 1rem; border-bottom: 1px solid #e8f0e9; position: sticky; top: 0; background: #fff; z-index: 1; }
.pd__modal-title  { font-size: 1rem; font-weight: 700; color: #1a1a1a; margin: 0; }
.pd__modal-sub    { font-size: .75rem; color: #60725d; margin: .2rem 0 0; }
.pd__modal-close  { background: #e8f5e9; border: none; width: 28px; height: 28px; border-radius: 7px; cursor: pointer; display: flex; align-items: center; justify-content: center; color: #60725d; transition: all .15s; flex-shrink: 0; }
.pd__modal-close:hover { background: #c8e6c9; color: #1b5e20; }
.pd__modal-body   { padding: 1.1rem 1.5rem; flex: 1; }
.pd__modal-footer { display: flex; justify-content: flex-end; gap: .75rem; padding: .9rem 1.5rem; border-top: 1px solid #e8f0e9; position: sticky; bottom: 0; background: #fff; }
.pd__msection { font-size: .7rem; font-weight: 800; color: #60725d; text-transform: uppercase; letter-spacing: .06em; margin: .9rem 0 .5rem; padding-bottom: .35rem; border-bottom: 1px solid #e8f0e9; }
.pd__mgrid { display: grid; grid-template-columns: 1fr 1fr; gap: .85rem; }
@media (max-width: 480px) { .pd__mgrid { grid-template-columns: 1fr; } }
.pd__field { display: flex; flex-direction: column; gap: .3rem; }
.pd__field--full { grid-column: 1 / -1; }
.pd__label { font-size: .75rem; font-weight: 700; color: #374151; text-transform: uppercase; letter-spacing: .04em; }
.pd__optional { font-size: .65rem; font-weight: 400; color: #94a3b8; text-transform: none; letter-spacing: 0; }
.pd__input { background: #f4f8f4; border: 1.5px solid #d4e6d4; border-radius: 8px; padding: .55rem .8rem; font-size: .875rem; color: #1a1a1a; width: 100%; box-sizing: border-box; transition: border .15s; }
.pd__input:focus { outline: none; border-color: #1b5e20; background: #fff; }
.pd__input-group { display: flex; }
.pd__input-group .pd__input { border-radius: 8px 0 0 8px; }
.pd__input-suffix { background: #e8f5e9; border: 1.5px solid #d4e6d4; border-left: none; padding: .55rem .7rem; font-size: .8rem; font-weight: 600; color: #1b5e20; border-radius: 0 8px 8px 0; white-space: nowrap; }
.pd__textarea { resize: vertical; min-height: 56px; }
.pd__selector { display: flex; gap: .4rem; flex-wrap: wrap; }
.pd__sel-btn { display: flex; align-items: center; gap: .3rem; padding: .38rem .75rem; border: 1.5px solid #d4e6d4; border-radius: 8px; background: #f4f8f4; font-size: .78rem; font-weight: 600; cursor: pointer; transition: all .15s; }
.pd__sel-btn:hover { border-color: #1b5e20; }
.pd__sel-btn--active { transform: translateY(-1px); box-shadow: 0 2px 8px rgba(0,0,0,.08); }
.pd__sel-hint { font-size: .62rem; font-weight: 400; color: #94a3b8; }
.pd__alert { background: #fef2f2; border: 1px solid #fecaca; color: #dc2626; padding: .65rem .9rem; border-radius: 8px; font-size: .82rem; margin-bottom: .75rem; }
/* Buttons */
.pd__btn-primary { display: inline-flex; align-items: center; gap: .4rem; background: #1b5e20; color: #fff; border: none; padding: .6rem 1.25rem; border-radius: 8px; font-size: .875rem; font-weight: 600; cursor: pointer; transition: background .15s; white-space: nowrap; }
.pd__btn-primary:hover { background: #104417; }
.pd__btn-primary:disabled { opacity: .6; cursor: not-allowed; }
.pd__btn-ghost { background: transparent; color: #60725d; border: 1px solid #d4e6d4; padding: .55rem 1rem; border-radius: 8px; font-size: .875rem; font-weight: 500; cursor: pointer; transition: all .15s; }
.pd__btn-ghost:hover { background: #f0fdf4; color: #1b5e20; }
.pd__btn-outline { display: inline-flex; align-items: center; gap: .3rem; background: transparent; color: #1b5e20; border: 1.5px solid #d4e6d4; padding: .45rem 1rem; border-radius: 8px; font-size: .8rem; font-weight: 600; cursor: pointer; transition: all .15s; }
.pd__btn-outline:hover { border-color: #1b5e20; background: #f0fdf4; }
.pd__btn-sm { display: inline-flex; align-items: center; gap: .3rem; background: #e8f5e9; color: #1b5e20; border: 1px solid #d4e6d4; padding: .3rem .6rem; border-radius: 7px; font-size: .75rem; font-weight: 600; cursor: pointer; transition: all .15s; }
.pd__btn-sm:hover { background: #1b5e20; color: #fff; }
.pd__qr-body { display: flex; flex-direction: column; align-items: center; gap: .6rem; padding: 1rem; }
.pd__qr-img  { width: 160px; height: 160px; border-radius: 8px; border: 1px solid #d4e6d4; }
.pd__qr-placeholder { width: 160px; height: 160px; background: #f4f8f4; border-radius: 8px; display: flex; align-items: center; justify-content: center; color: #94a3b8; font-size: .8rem; }
.pd__qr-hint { font-size: .72rem; color: #94a3b8; text-align: center; max-width: 160px; }
.pd__btn-qr-dl { width: 100%; justify-content: center; }
</style>

