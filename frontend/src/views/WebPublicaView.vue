<template>
  <div class="wpv">

    <!-- Header -->
    <div class="wpv__header">
      <div>
        <h1 class="wpv__title">Web pública</h1>
        <p class="wpv__subtitle">Gestioná el contenido de la web de tu club</p>
      </div>
      <a :href="webUrl" target="_blank" class="wpv__preview-btn">
        <i class="bi bi-box-arrow-up-right"></i>
        Ver web
      </a>
    </div>

    <!-- Tabs -->
    <div class="wpv__tabs">
      <button v-for="tab in tabs" :key="tab.key" class="wpv__tab"
              :class="{ 'wpv__tab--active': activeTab === tab.key }" @click="activeTab = tab.key">
        <i :class="`bi ${tab.icon}`"></i>
        {{ tab.label }}
      </button>
    </div>

    <!-- TAB: VARIEDADES -->
    <div v-if="activeTab === 'geneticas'" class="wpv__section">
      <div class="wpv__section-header">
        <div>
          <h2 class="wpv__section-title">Variedades visibles en la web</h2>
          <p class="wpv__section-sub">Activá las genéticas que querés mostrar en la web pública del club.</p>
        </div>
      </div>
      <div v-if="loadingGeneticas" class="wpv__loading"><div class="wpv__spinner"></div></div>
      <div v-else class="wpv__geneticas-table">
        <div class="wpv__table-header">
          <span>Genética</span>
          <span>Tipo</span>
          <span>THC / CBD</span>
          <span>Disp. cultivo</span>
          <span>Visible web</span>
        </div>
        <div v-for="g in geneticas" :key="g.id" class="wpv__table-row"
             :class="{ 'wpv__table-row--active': g.visible_web }">
          <div class="wpv__genetica-name">
            <span class="wpv__genetica-nombre">{{ g.nombre }}</span>
            <span v-if="g.registrada_inase" class="wpv__inase-badge">INASE</span>
          </div>
          <span class="wpv__tipo-badge" :class="`wpv__tipo-badge--${g.tipo}`">{{ formatTipo(g.tipo) }}</span>
          <span class="wpv__thc-cbd">THC {{ g.thc }}% · CBD {{ g.cbd }}%</span>
          <div>
            <span class="wpv__pill" :class="g.disponible ? 'wpv__pill--green' : 'wpv__pill--gray'">
              {{ g.disponible ? 'Sí' : 'No' }}
            </span>
          </div>
          <div class="wpv__toggle-col">
            <button class="wpv__toggle" :class="{ 'wpv__toggle--on': g.visible_web }"
                    @click="toggleVisibleWeb(g)" :disabled="savingId === g.id">
              <span class="wpv__toggle-thumb"></span>
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- TAB: NOTICIAS -->
    <div v-if="activeTab === 'noticias'" class="wpv__section">
      <div class="wpv__section-header">
        <h2 class="wpv__section-title">Noticias</h2>
        <button class="wpv__add-btn" @click="abrirModalNoticia()">
          <i class="bi bi-plus-lg"></i> Nueva noticia
        </button>
      </div>
      <div v-if="loadingNoticias" class="wpv__loading"><div class="wpv__spinner"></div></div>
      <div v-else-if="noticias.length === 0" class="wpv__empty">
        <i class="bi bi-newspaper" style="font-size:2rem;opacity:.3;display:block;margin-bottom:.75rem"></i>
        No hay noticias todavía. Creá la primera.
      </div>
      <div v-else class="wpv__cards-grid">
        <div v-for="n in noticias" :key="n.id" class="wpv__news-card">
          <div class="wpv__news-card-img" :style="n.cover_url ? `background-image:url(${n.cover_url})` : ''">
            <span v-if="!n.cover_url" class="wpv__news-card-img-placeholder"><i class="bi bi-image"></i></span>
            <div class="wpv__news-card-badges">
              <span class="wpv__pill" :class="n.publicada ? 'wpv__pill--green' : 'wpv__pill--gray'">
                {{ n.publicada ? 'Publicada' : 'Borrador' }}
              </span>
            </div>
          </div>
          <div class="wpv__news-card-body">
            <div class="wpv__news-card-date">{{ formatFecha(n.publicada_at || n.created_at) }}</div>
            <div class="wpv__news-card-title">{{ n.titulo }}</div>
            <div class="wpv__news-card-preview">{{ truncate(n.contenido, 100) }}</div>
          </div>
          <div class="wpv__news-card-footer">
            <button class="wpv__card-btn" @click="abrirModalNoticia(n)">
              <i class="bi bi-pencil"></i> Editar
            </button>
            <button class="wpv__card-btn wpv__card-btn--danger" @click="eliminarNoticia(n)">
              <i class="bi bi-trash"></i>
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- TAB: EVENTOS -->
    <div v-if="activeTab === 'eventos'" class="wpv__section">
      <div class="wpv__section-header">
        <h2 class="wpv__section-title">Eventos</h2>
        <button class="wpv__add-btn" @click="abrirModalEvento()">
          <i class="bi bi-plus-lg"></i> Nuevo evento
        </button>
      </div>
      <div v-if="loadingEventos" class="wpv__loading"><div class="wpv__spinner"></div></div>
      <div v-else class="wpv__eventos-layout">
        <div class="wpv__eventos-list">
          <div v-if="eventos.length === 0" class="wpv__empty">
            <i class="bi bi-calendar-event" style="font-size:2rem;opacity:.3;display:block;margin-bottom:.75rem"></i>
            No hay eventos cargados todavía.
          </div>
          <div v-for="e in eventos" :key="e.id" class="wpv__evento-card"
               :class="{ 'wpv__evento-card--inactivo': !e.activo }">
            <div class="wpv__evento-card-fecha">
              <div class="wpv__evento-dia">{{ getDia(e.fecha_inicio) }}</div>
              <div class="wpv__evento-mes">{{ getMes(e.fecha_inicio) }}</div>
            </div>
            <div class="wpv__evento-card-body">
              <div class="wpv__evento-titulo">{{ e.titulo }}</div>
              <div class="wpv__evento-meta">
                <span v-if="e.lugar"><i class="bi bi-geo-alt"></i> {{ e.lugar }}</span>
                <span><i class="bi bi-clock"></i> {{ getHora(e.fecha_inicio) }}</span>
              </div>
              <div v-if="e.descripcion" class="wpv__evento-desc">{{ truncate(e.descripcion, 80) }}</div>
            </div>
            <div class="wpv__evento-card-actions">
              <span class="wpv__pill" :class="e.activo ? 'wpv__pill--green' : 'wpv__pill--gray'">
                {{ e.activo ? 'Activo' : 'Inactivo' }}
              </span>
              <button class="wpv__icon-btn" @click="abrirModalEvento(e)"><i class="bi bi-pencil"></i></button>
              <button class="wpv__icon-btn wpv__icon-btn--danger" @click="eliminarEvento(e)"><i class="bi bi-trash"></i></button>
            </div>
          </div>
        </div>

        <!-- Mini calendario -->
        <div class="wpv__calendario">
          <div class="wpv__cal-header">
            <button class="wpv__cal-nav" @click="mesAnterior">&#8249;</button>
            <span class="wpv__cal-titulo">{{ nombreMes(calMes) }} {{ calAnio }}</span>
            <button class="wpv__cal-nav" @click="mesSiguiente">&#8250;</button>
          </div>
          <div class="wpv__cal-grid-header">
            <span v-for="d in ['Do','Lu','Ma','Mi','Ju','Vi','Sa']" :key="d">{{ d }}</span>
          </div>
          <div class="wpv__cal-grid">
            <div v-for="(dia, i) in diasDelMes" :key="i" class="wpv__cal-dia"
                 :class="{
                'wpv__cal-dia--vacio': !dia,
                'wpv__cal-dia--hoy': dia && esHoy(dia),
                'wpv__cal-dia--evento': dia && tieneEvento(dia),
              }">
              <span v-if="dia">{{ dia }}</span>
              <div v-if="dia && tieneEvento(dia)" class="wpv__cal-dot"></div>
            </div>
          </div>
          <div class="wpv__cal-leyenda">
            <span class="wpv__cal-dot-lg"></span> Eventos programados
          </div>
        </div>
      </div>
    </div>

    <!-- TAB: CONFIGURACIÓN -->
    <div v-if="activeTab === 'config'" class="wpv__section">
      <div class="wpv__section-header">
        <h2 class="wpv__section-title">Configuración de la web</h2>
      </div>
      <div class="wpv__config-grid">
        <div class="wpv__config-field wpv__config-field--full">
          <label class="wpv__label">Descripción del club</label>
          <textarea v-model="configForm.descripcion_web" class="wpv__textarea" rows="4"
                    placeholder="Contá quiénes son y qué hacen..."></textarea>
        </div>
        <div class="wpv__config-field">
          <label class="wpv__label">WhatsApp</label>
          <input v-model="configForm.whatsapp" class="wpv__input" placeholder="+54 9 11 xxxx-xxxx" />
        </div>
        <div class="wpv__config-field">
          <label class="wpv__label">Instagram</label>
          <input v-model="configForm.instagram_url" class="wpv__input" placeholder="https://instagram.com/..." />
        </div>
        <div class="wpv__config-field">
          <label class="wpv__label">Facebook</label>
          <input v-model="configForm.facebook_url" class="wpv__input" placeholder="https://facebook.com/..." />
        </div>
        <div class="wpv__config-field">
          <label class="wpv__label">Horarios de atención</label>
          <textarea v-model="configForm.horarios_atencion" class="wpv__textarea" rows="3"
                    placeholder="Lunes a viernes 10-18hs..."></textarea>
        </div>
        <div class="wpv__config-field wpv__config-field--full">
          <label class="wpv__label">Estado de la web</label>
          <div class="wpv__web-status-card" :class="{ 'wpv__web-status-card--on': configForm.web_activa }">
            <div class="wpv__web-status-info">
              <div class="wpv__web-status-dot" :class="{ 'wpv__web-status-dot--on': configForm.web_activa }"></div>
              <div>
                <div class="wpv__web-status-label">
                  {{ configForm.web_activa ? 'Web activa y visible al público' : 'Web desactivada' }}
                </div>
                <div class="wpv__web-status-sub">
                  {{ configForm.web_activa ? 'Los visitantes pueden ver tu sitio web.' : 'Tu sitio no es accesible públicamente.' }}
                </div>
              </div>
            </div>
            <button class="wpv__toggle" :class="{ 'wpv__toggle--on': configForm.web_activa }"
                    @click="configForm.web_activa = !configForm.web_activa">
              <span class="wpv__toggle-thumb"></span>
            </button>
          </div>
        </div>
      </div>
      <div class="wpv__config-footer">
        <button class="wpv__save-btn" @click="guardarConfig" :disabled="savingConfig">
          <span v-if="savingConfig">Guardando...</span>
          <span v-else><i class="bi bi-check-lg"></i> Guardar cambios</span>
        </button>
        <transition name="fade">
          <span v-if="configSaved" class="wpv__saved-msg"><i class="bi bi-check-circle-fill"></i> Cambios guardados</span>
        </transition>
      </div>
    </div>

    <!-- MODAL NOTICIA -->
    <Teleport to="body">
      <transition name="modal">
        <div v-if="modalNoticia" class="wpv__modal-backdrop" @click.self="modalNoticia = false">
          <div class="wpv__modal wpv__modal--lg">
            <div class="wpv__modal-header">
              <div class="wpv__modal-header-icon wpv__modal-header-icon--news">
                <i class="bi bi-newspaper"></i>
              </div>
              <div>
                <h3 class="wpv__modal-title">{{ formNoticia.id ? 'Editar noticia' : 'Nueva noticia' }}</h3>
                <p class="wpv__modal-subtitle">{{ formNoticia.id ? 'Modificá el contenido de esta noticia' : 'Creá una nueva noticia para tu web' }}</p>
              </div>
              <button class="wpv__modal-close" @click="modalNoticia = false">
                <i class="bi bi-x-lg"></i>
              </button>
            </div>
            <div class="wpv__modal-body">
              <div class="wpv__modal-two-col">
                <div class="wpv__modal-col">
                  <div class="wpv__field-group">
                    <label class="wpv__label">Título *</label>
                    <input v-model="formNoticia.titulo" class="wpv__input" placeholder="Título de la noticia" />
                  </div>
                  <div class="wpv__field-group">
                    <label class="wpv__label">Contenido *</label>
                    <textarea v-model="formNoticia.contenido" class="wpv__textarea wpv__textarea--tall"
                              rows="8" placeholder="Escribí el contenido de la noticia..."></textarea>
                  </div>
                  <div class="wpv__field-group">
                    <div class="wpv__toggle-row">
                      <button class="wpv__toggle" :class="{ 'wpv__toggle--on': formNoticia.publicada }"
                              @click="formNoticia.publicada = !formNoticia.publicada">
                        <span class="wpv__toggle-thumb"></span>
                      </button>
                      <div>
                        <div class="wpv__label" style="margin-bottom:0">Publicar noticia</div>
                        <div style="font-size:12px;color:#6b8f71">
                          {{ formNoticia.publicada ? 'Visible en la web pública' : 'Guardada como borrador' }}
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
                <div class="wpv__modal-col">
                  <div class="wpv__field-group">
                    <label class="wpv__label">Imagen de portada</label>
                    <div class="wpv__upload-zone" :class="{ 'wpv__upload-zone--has-img': noticiaImgPreview }"
                         @click="$refs.noticiaImgInput.click()"
                         @dragover.prevent @drop.prevent="onDropNoticia">
                      <img v-if="noticiaImgPreview" :src="noticiaImgPreview" class="wpv__upload-preview" />
                      <div v-else class="wpv__upload-placeholder">
                        <i class="bi bi-cloud-arrow-up"></i>
                        <span>Arrastrá una imagen o hacé click</span>
                        <span class="wpv__upload-hint">JPG, PNG o WebP · Máx 5MB</span>
                      </div>
                      <div v-if="noticiaImgPreview" class="wpv__upload-overlay">
                        <i class="bi bi-camera"></i> Cambiar imagen
                      </div>
                    </div>
                    <input ref="noticiaImgInput" type="file" accept="image/*" style="display:none"
                           @change="onSelectNoticiaImg" />
                    <button v-if="noticiaImgPreview" class="wpv__remove-img-btn"
                            @click.stop="noticiaImgPreview = null; noticiaImgFile = null">
                      <i class="bi bi-x"></i> Quitar imagen
                    </button>
                  </div>
                </div>
              </div>
            </div>
            <div class="wpv__modal-footer">
              <button class="wpv__cancel-btn" @click="modalNoticia = false">Cancelar</button>
              <button class="wpv__save-btn" @click="guardarNoticia" :disabled="savingNoticia">
                <span v-if="savingNoticia">Guardando...</span>
                <span v-else><i class="bi bi-check-lg"></i> {{ formNoticia.id ? 'Guardar cambios' : 'Crear noticia' }}</span>
              </button>
            </div>
          </div>
        </div>
      </transition>
    </Teleport>

    <!-- MODAL EVENTO -->
    <Teleport to="body">
      <transition name="modal">
        <div v-if="modalEvento" class="wpv__modal-backdrop" @click.self="modalEvento = false">
          <div class="wpv__modal wpv__modal--lg">
            <div class="wpv__modal-header">
              <div class="wpv__modal-header-icon wpv__modal-header-icon--event">
                <i class="bi bi-calendar-event"></i>
              </div>
              <div>
                <h3 class="wpv__modal-title">{{ formEvento.id ? 'Editar evento' : 'Nuevo evento' }}</h3>
                <p class="wpv__modal-subtitle">{{ formEvento.id ? 'Modificá los datos de este evento' : 'Agregá un evento a tu calendario público' }}</p>
              </div>
              <button class="wpv__modal-close" @click="modalEvento = false">
                <i class="bi bi-x-lg"></i>
              </button>
            </div>
            <div class="wpv__modal-body">
              <div class="wpv__modal-two-col">
                <div class="wpv__modal-col">
                  <div class="wpv__field-group">
                    <label class="wpv__label">Título del evento *</label>
                    <input v-model="formEvento.titulo" class="wpv__input" placeholder="Ej: Taller de cultivo medicinal" />
                  </div>
                  <div class="wpv__field-group">
                    <label class="wpv__label">Descripción</label>
                    <textarea v-model="formEvento.descripcion" class="wpv__textarea" rows="4"
                              placeholder="Describí de qué trata el evento..."></textarea>
                  </div>
                  <div class="wpv__form-row">
                    <div class="wpv__field-group">
                      <label class="wpv__label">Fecha de inicio *</label>
                      <input v-model="formEvento.fecha_inicio" type="datetime-local" class="wpv__input" />
                    </div>
                    <div class="wpv__field-group">
                      <label class="wpv__label">Fecha de fin</label>
                      <input v-model="formEvento.fecha_fin" type="datetime-local" class="wpv__input" />
                    </div>
                  </div>
                  <div class="wpv__field-group">
                    <label class="wpv__label">Lugar</label>
                    <input v-model="formEvento.lugar" class="wpv__input" placeholder="Dirección o nombre del lugar" />
                  </div>
                  <div class="wpv__field-group">
                    <div class="wpv__toggle-row">
                      <button class="wpv__toggle" :class="{ 'wpv__toggle--on': formEvento.activo }"
                              @click="formEvento.activo = !formEvento.activo">
                        <span class="wpv__toggle-thumb"></span>
                      </button>
                      <div>
                        <div class="wpv__label" style="margin-bottom:0">Evento activo</div>
                        <div style="font-size:12px;color:#6b8f71">
                          {{ formEvento.activo ? 'Visible en la web pública' : 'Oculto para los visitantes' }}
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
                <div class="wpv__modal-col">
                  <div class="wpv__field-group">
                    <label class="wpv__label">Imagen del evento</label>
                    <div class="wpv__upload-zone" :class="{ 'wpv__upload-zone--has-img': eventoImgPreview }"
                         @click="$refs.eventoImgInput.click()"
                         @dragover.prevent @drop.prevent="onDropEvento">
                      <img v-if="eventoImgPreview" :src="eventoImgPreview" class="wpv__upload-preview" />
                      <div v-else class="wpv__upload-placeholder">
                        <i class="bi bi-cloud-arrow-up"></i>
                        <span>Arrastrá una imagen o hacé click</span>
                        <span class="wpv__upload-hint">JPG, PNG o WebP · Máx 5MB</span>
                      </div>
                      <div v-if="eventoImgPreview" class="wpv__upload-overlay">
                        <i class="bi bi-camera"></i> Cambiar imagen
                      </div>
                    </div>
                    <input ref="eventoImgInput" type="file" accept="image/*" style="display:none"
                           @change="onSelectEventoImg" />
                    <button v-if="eventoImgPreview" class="wpv__remove-img-btn"
                            @click.stop="eventoImgPreview = null; eventoImgFile = null">
                      <i class="bi bi-x"></i> Quitar imagen
                    </button>
                  </div>
                </div>
              </div>
            </div>
            <div class="wpv__modal-footer">
              <button class="wpv__cancel-btn" @click="modalEvento = false">Cancelar</button>
              <button class="wpv__save-btn" @click="guardarEvento" :disabled="savingEvento">
                <span v-if="savingEvento">Guardando...</span>
                <span v-else><i class="bi bi-check-lg"></i> {{ formEvento.id ? 'Guardar cambios' : 'Crear evento' }}</span>
              </button>
            </div>
          </div>
        </div>
      </transition>
    </Teleport>

  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useClubStore } from '../stores/club'
import { storeToRefs } from 'pinia'
import api from '../lib/api'

const clubStore = useClubStore()
const { data: club } = storeToRefs(clubStore)
const webUrl = import.meta.env.VITE_PUBLIC_WEB_URL || 'http://localhost:5174'

const activeTab = ref('geneticas')
const tabs = [
  { key: 'geneticas', label: 'Variedades',   icon: 'bi-diagram-3'      },
  { key: 'noticias',  label: 'Noticias',      icon: 'bi-newspaper'      },
  { key: 'eventos',   label: 'Eventos',       icon: 'bi-calendar-event' },
  { key: 'config',    label: 'Configuración', icon: 'bi-gear'           },
]

const geneticas        = ref([])
const loadingGeneticas = ref(true)
const savingId         = ref(null)

const noticias         = ref([])
const loadingNoticias  = ref(true)
const modalNoticia     = ref(false)
const savingNoticia    = ref(false)
const noticiaImgPreview = ref(null)
const noticiaImgFile   = ref(null)
const noticiaImgInput  = ref(null)
const formNoticia      = ref({ id: null, titulo: '', contenido: '', publicada: false })

const eventos          = ref([])
const loadingEventos   = ref(true)
const modalEvento      = ref(false)
const savingEvento     = ref(false)
const eventoImgPreview = ref(null)
const eventoImgFile    = ref(null)
const eventoImgInput   = ref(null)
const formEvento       = ref({ id: null, titulo: '', descripcion: '', fecha_inicio: '', fecha_fin: '', lugar: '', activo: true })

const configForm   = ref({ descripcion_web: '', whatsapp: '', instagram_url: '', facebook_url: '', horarios_atencion: '', web_activa: false })
const savingConfig = ref(false)
const configSaved  = ref(false)

const hoy     = new Date()
const calMes  = ref(hoy.getMonth())
const calAnio = ref(hoy.getFullYear())
const MESES   = ['Enero','Febrero','Marzo','Abril','Mayo','Junio','Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre']

function nombreMes(m) { return MESES[m] }
function mesAnterior() {
  if (calMes.value === 0) { calMes.value = 11; calAnio.value-- } else calMes.value--
}
function mesSiguiente() {
  if (calMes.value === 11) { calMes.value = 0; calAnio.value++ } else calMes.value++
}
const diasDelMes = computed(() => {
  const primerDia = new Date(calAnio.value, calMes.value, 1).getDay()
  const totalDias = new Date(calAnio.value, calMes.value + 1, 0).getDate()
  const celdas = []
  for (let i = 0; i < primerDia; i++) celdas.push(null)
  for (let d = 1; d <= totalDias; d++) celdas.push(d)
  return celdas
})
function esHoy(dia) {
  return dia === hoy.getDate() && calMes.value === hoy.getMonth() && calAnio.value === hoy.getFullYear()
}
function tieneEvento(dia) {
  return eventos.value.some(e => {
    if (!e.fecha_inicio) return false
    const f = new Date(e.fecha_inicio)
    return f.getDate() === dia && f.getMonth() === calMes.value && f.getFullYear() === calAnio.value
  })
}

function formatTipo(tipo) { return { indica: 'Índica', sativa: 'Sativa', hibrida: 'Híbrida' }[tipo] || tipo }
function formatFecha(fecha) {
  if (!fecha) return ''
  return new Date(fecha).toLocaleDateString('es-AR', { day: 'numeric', month: 'short', year: 'numeric' })
}
function getDia(fecha) { return fecha ? new Date(fecha).getDate() : '' }
function getMes(fecha) { return fecha ? new Date(fecha).toLocaleDateString('es-AR', { month: 'short' }).toUpperCase() : '' }
function getHora(fecha) { return fecha ? new Date(fecha).toLocaleTimeString('es-AR', { hour: '2-digit', minute: '2-digit' }) : '' }
function truncate(text, len) { return text && text.length > len ? text.slice(0, len) + '...' : text }

function onSelectNoticiaImg(e) {
  const file = e.target.files[0]
  if (!file) return
  noticiaImgFile.value = file
  noticiaImgPreview.value = URL.createObjectURL(file)
}
function onDropNoticia(e) {
  const file = e.dataTransfer.files[0]
  if (!file || !file.type.startsWith('image/')) return
  noticiaImgFile.value = file
  noticiaImgPreview.value = URL.createObjectURL(file)
}
function onSelectEventoImg(e) {
  const file = e.target.files[0]
  if (!file) return
  eventoImgFile.value = file
  eventoImgPreview.value = URL.createObjectURL(file)
}
function onDropEvento(e) {
  const file = e.dataTransfer.files[0]
  if (!file || !file.type.startsWith('image/')) return
  eventoImgFile.value = file
  eventoImgPreview.value = URL.createObjectURL(file)
}

async function toggleVisibleWeb(g) {
  savingId.value = g.id
  try {
    const { data } = await api.patch(`/geneticas/${g.id}`, { genetica: { visible_web: !g.visible_web } })
    g.visible_web = data.visible_web
  } catch (e) { console.error(e) }
  finally { savingId.value = null }
}

function abrirModalNoticia(n = null) {
  formNoticia.value = n
    ? { id: n.id, titulo: n.titulo, contenido: n.contenido, publicada: n.publicada }
    : { id: null, titulo: '', contenido: '', publicada: false }
  noticiaImgPreview.value = n?.cover_url || null
  noticiaImgFile.value = null
  modalNoticia.value = true
}
async function guardarNoticia() {
  savingNoticia.value = true
  try {
    const fd = new FormData()
    fd.append('noticia[titulo]', formNoticia.value.titulo)
    fd.append('noticia[contenido]', formNoticia.value.contenido)
    fd.append('noticia[publicada]', formNoticia.value.publicada)
    if (noticiaImgFile.value) fd.append('cover_image', noticiaImgFile.value)
    const headers = { 'Content-Type': 'multipart/form-data' }
    if (formNoticia.value.id) {
      await api.patch(`/noticias/${formNoticia.value.id}`, fd, { headers })
    } else {
      await api.post('/noticias', fd, { headers })
    }
    await cargarNoticias()
    modalNoticia.value = false
  } catch (e) { console.error(e) }
  finally { savingNoticia.value = false }
}
async function eliminarNoticia(n) {
  if (!confirm(`¿Eliminar "${n.titulo}"?`)) return
  await api.delete(`/noticias/${n.id}`)
  await cargarNoticias()
}

function abrirModalEvento(e = null) {
  formEvento.value = e
    ? { id: e.id, titulo: e.titulo, descripcion: e.descripcion, fecha_inicio: e.fecha_inicio?.slice(0,16), fecha_fin: e.fecha_fin?.slice(0,16), lugar: e.lugar, activo: e.activo }
    : { id: null, titulo: '', descripcion: '', fecha_inicio: '', fecha_fin: '', lugar: '', activo: true }
  eventoImgPreview.value = e?.imagen_url || null
  eventoImgFile.value = null
  modalEvento.value = true
}
async function guardarEvento() {
  savingEvento.value = true
  try {
    const fd = new FormData()
    fd.append('evento[titulo]', formEvento.value.titulo)
    fd.append('evento[descripcion]', formEvento.value.descripcion || '')
    fd.append('evento[fecha_inicio]', formEvento.value.fecha_inicio)
    fd.append('evento[fecha_fin]', formEvento.value.fecha_fin || '')
    fd.append('evento[lugar]', formEvento.value.lugar || '')
    fd.append('evento[activo]', formEvento.value.activo)
    if (eventoImgFile.value) fd.append('imagen', eventoImgFile.value)
    const headers = { 'Content-Type': 'multipart/form-data' }
    if (formEvento.value.id) {
      await api.patch(`/eventos/${formEvento.value.id}`, fd, { headers })
    } else {
      await api.post('/eventos', fd, { headers })
    }
    await cargarEventos()
    modalEvento.value = false
  } catch (e) { console.error(e) }
  finally { savingEvento.value = false }
}
async function eliminarEvento(e) {
  if (!confirm(`¿Eliminar "${e.titulo}"?`)) return
  await api.delete(`/eventos/${e.id}`)
  await cargarEventos()
}

async function guardarConfig() {
  savingConfig.value = true
  try {
    await api.put('/preferences', { club: { ...configForm.value } })
    // Actualizar el store local para que refleje los cambios
    if (club.value) {
      Object.assign(club.value, configForm.value)
    }
    configSaved.value = true
    setTimeout(() => { configSaved.value = false }, 3000)
  } catch (e) { console.error(e) }
  finally { savingConfig.value = false }
}

async function cargarGeneticas() {
  loadingGeneticas.value = true
  try {
    const { data } = await api.get('/geneticas')
    geneticas.value = data.data || data
  } catch (e) { console.error(e) }
  finally { loadingGeneticas.value = false }
}
async function cargarNoticias() {
  loadingNoticias.value = true
  try {
    const { data } = await api.get('/noticias')
    noticias.value = data.data || data
  } catch (e) { console.error(e) }
  finally { loadingNoticias.value = false }
}
async function cargarEventos() {
  loadingEventos.value = true
  try {
    const { data } = await api.get('/eventos')
    eventos.value = data.data || data
  } catch (e) { console.error(e) }
  finally { loadingEventos.value = false }
}

onMounted(async () => {
  await Promise.all([cargarGeneticas(), cargarNoticias(), cargarEventos()])
  // Siempre traer la config fresca del backend
  try {
    const { data } = await api.get('/preferences')
    configForm.value = {
      descripcion_web:   data.descripcion_web   || '',
      whatsapp:          data.whatsapp           || '',
      instagram_url:     data.instagram_url      || '',
      facebook_url:      data.facebook_url       || '',
      horarios_atencion: data.horarios_atencion  || '',
      web_activa:        data.web_activa         || false,
    }
  } catch (e) { console.error(e) }
})
</script>

<style scoped>
.wpv { max-width: 1100px; margin: 0 auto; padding: 2rem 1.5rem; }

.wpv__header { display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 2rem; }
.wpv__title { font-size: 22px; font-weight: 600; color: #1a2e1b; margin-bottom: 4px; }
.wpv__subtitle { font-size: 14px; color: #6b8f71; margin: 0; }
.wpv__preview-btn {
  display: flex; align-items: center; gap: 8px;
  background: linear-gradient(135deg, #1b5e20, #2e7d32);
  color: #e8f5e9; padding: 10px 20px; border-radius: 10px;
  font-size: 13px; text-decoration: none; transition: opacity .2s;
  box-shadow: 0 2px 8px #1b5e2030;
}
.wpv__preview-btn:hover { opacity: .88; color: #e8f5e9; }

.wpv__tabs { display: flex; gap: 4px; border-bottom: 1px solid #e2e8f0; margin-bottom: 2rem; }
.wpv__tab {
  display: flex; align-items: center; gap: 6px;
  padding: 10px 18px; border: none; background: none;
  font-size: 14px; color: #6b8f71; cursor: pointer;
  border-bottom: 2px solid transparent; margin-bottom: -1px; transition: color .2s;
}
.wpv__tab:hover { color: #1b5e20; }
.wpv__tab--active { color: #1b5e20; font-weight: 500; border-bottom-color: #1b5e20; }

.wpv__section-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 1.5rem; }
.wpv__section-title { font-size: 16px; font-weight: 600; color: #1a2e1b; margin-bottom: 4px; }
.wpv__section-sub { font-size: 13px; color: #6b8f71; margin: 0; }

.wpv__loading { display: flex; justify-content: center; padding: 3rem; }
.wpv__spinner {
  width: 28px; height: 28px; border: 2px solid #e8f5e9; border-top-color: #1b5e20;
  border-radius: 50%; animation: spin .7s linear infinite;
}
@keyframes spin { to { transform: rotate(360deg); } }
.wpv__empty {
  text-align: center; color: #6b8f71; padding: 3rem; font-size: 14px;
  background: #f8fdf8; border-radius: 14px; border: 1px dashed #c8e6c9;
}

.wpv__geneticas-table { border: 1px solid #e8f5e9; border-radius: 14px; overflow: hidden; }
.wpv__table-header {
  display: grid; grid-template-columns: 2fr 1fr 1.5fr 1fr 80px;
  padding: 10px 16px; background: #f0fdf4;
  font-size: 11px; font-weight: 600; color: #4a7c59;
  text-transform: uppercase; letter-spacing: .07em;
}
.wpv__table-row {
  display: grid; grid-template-columns: 2fr 1fr 1.5fr 1fr 80px;
  padding: 14px 16px; align-items: center;
  border-top: 1px solid #e8f5e9; transition: background .15s;
}
.wpv__table-row:hover { background: #f8fdf8; }
.wpv__table-row--active { background: #f0fdf4; }
.wpv__genetica-name { display: flex; align-items: center; gap: 8px; }
.wpv__genetica-nombre { font-size: 14px; font-weight: 500; color: #1a2e1b; }
.wpv__inase-badge { background: #fff3e0; color: #bf360c; font-size: 10px; padding: 2px 7px; border-radius: 4px; font-weight: 600; }
.wpv__tipo-badge { display: inline-block; font-size: 11px; padding: 3px 10px; border-radius: 5px; }
.wpv__tipo-badge--indica  { background: #e8eaf6; color: #3949ab; }
.wpv__tipo-badge--sativa  { background: #fff8e1; color: #f57f17; }
.wpv__tipo-badge--hibrida { background: #e8f5e9; color: #2e7d32; }
.wpv__thc-cbd { font-size: 13px; color: #4a7c59; }
.wpv__pill { display: inline-block; font-size: 11px; padding: 3px 10px; border-radius: 20px; font-weight: 500; }
.wpv__pill--green { background: #e8f5e9; color: #1b5e20; }
.wpv__pill--gray  { background: #f1f5f9; color: #94a3b8; }
.wpv__toggle-col { display: flex; justify-content: center; }
.wpv__toggle {
  width: 46px; height: 26px; border-radius: 13px; background: #e2e8f0;
  border: none; cursor: pointer; position: relative; transition: background .25s; padding: 0; flex-shrink: 0;
}
.wpv__toggle--on { background: #1b5e20; }
.wpv__toggle:disabled { opacity: .5; cursor: not-allowed; }
.wpv__toggle-thumb {
  position: absolute; top: 3px; left: 3px; width: 20px; height: 20px;
  border-radius: 50%; background: white; transition: transform .25s; display: block;
  box-shadow: 0 1px 3px rgba(0,0,0,.2);
}
.wpv__toggle--on .wpv__toggle-thumb { transform: translateX(20px); }
.wpv__toggle-row { display: flex; align-items: center; gap: 12px; }

.wpv__cards-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 20px; }
.wpv__news-card {
  background: white; border: 1px solid #e8f5e9; border-radius: 14px; overflow: hidden;
  transition: transform .2s, box-shadow .2s; display: flex; flex-direction: column;
}
.wpv__news-card:hover { transform: translateY(-3px); box-shadow: 0 8px 24px #1b5e2012; }
.wpv__news-card-img {
  height: 160px; background: linear-gradient(135deg, #e8f5e9, #c8e6c9);
  position: relative; background-size: cover; background-position: center;
  display: flex; align-items: center; justify-content: center;
}
.wpv__news-card-img-placeholder { font-size: 2.5rem; opacity: .3; }
.wpv__news-card-badges { position: absolute; top: 10px; left: 10px; }
.wpv__news-card-body { padding: 14px; flex: 1; }
.wpv__news-card-date { font-size: 11px; color: #1b5e20; margin-bottom: 6px; }
.wpv__news-card-title { font-size: 15px; font-weight: 500; color: #1a2e1b; margin-bottom: 6px; line-height: 1.3; }
.wpv__news-card-preview { font-size: 13px; color: #6b8f71; line-height: 1.5; }
.wpv__news-card-footer {
  padding: 10px 14px; border-top: 1px solid #f0fdf4;
  display: flex; justify-content: space-between; align-items: center;
}
.wpv__card-btn {
  display: flex; align-items: center; gap: 5px; background: none;
  border: 1px solid #e2e8f0; color: #4a7c59; font-size: 12px;
  padding: 5px 12px; border-radius: 7px; cursor: pointer; transition: all .15s;
}
.wpv__card-btn:hover { background: #f0fdf4; border-color: #1b5e20; color: #1b5e20; }
.wpv__card-btn--danger:hover { background: #fef2f2; border-color: #fecaca; color: #dc2626; }

.wpv__eventos-layout { display: grid; grid-template-columns: 1fr 280px; gap: 24px; align-items: start; }
.wpv__eventos-list { display: flex; flex-direction: column; gap: 12px; }
.wpv__evento-card {
  background: white; border: 1px solid #e8f5e9; border-radius: 14px;
  padding: 16px; display: flex; gap: 16px; align-items: flex-start;
  transition: box-shadow .2s; position: relative; overflow: hidden;
}
.wpv__evento-card::before {
  content: ''; position: absolute; left: 0; top: 0; bottom: 0;
  width: 4px; background: linear-gradient(180deg, #1b5e20, #2e7d32);
}
.wpv__evento-card:hover { box-shadow: 0 4px 16px #1b5e2010; }
.wpv__evento-card--inactivo { opacity: .6; }
.wpv__evento-card--inactivo::before { background: #e2e8f0; }
.wpv__evento-card-fecha {
  background: linear-gradient(135deg, #1b5e20, #2e7d32);
  border-radius: 10px; padding: 10px 14px; text-align: center; flex-shrink: 0; min-width: 54px;
}
.wpv__evento-dia { color: #e8f5e9; font-size: 22px; font-weight: 600; line-height: 1; }
.wpv__evento-mes { color: #a5d6a7; font-size: 10px; margin-top: 3px; text-transform: uppercase; }
.wpv__evento-card-body { flex: 1; }
.wpv__evento-titulo { font-size: 15px; font-weight: 500; color: #1a2e1b; margin-bottom: 6px; }
.wpv__evento-meta { display: flex; gap: 14px; font-size: 12px; color: #4a7c59; margin-bottom: 6px; }
.wpv__evento-desc { font-size: 13px; color: #6b8f71; line-height: 1.5; }
.wpv__evento-card-actions { display: flex; flex-direction: column; gap: 8px; align-items: flex-end; flex-shrink: 0; }
.wpv__icon-btn {
  width: 32px; height: 32px; border-radius: 8px; border: 1px solid #e2e8f0;
  background: white; cursor: pointer; display: flex; align-items: center; justify-content: center;
  font-size: 14px; color: #64748b; transition: all .15s;
}
.wpv__icon-btn:hover { background: #f8fafc; color: #1b5e20; border-color: #c8e6c9; }
.wpv__icon-btn--danger:hover { background: #fef2f2; color: #dc2626; border-color: #fecaca; }
.wpv__add-btn {
  display: flex; align-items: center; gap: 7px;
  background: linear-gradient(135deg, #1b5e20, #2e7d32);
  color: #e8f5e9; border: none; padding: 10px 18px; border-radius: 10px;
  font-size: 13px; cursor: pointer; transition: opacity .2s; box-shadow: 0 2px 8px #1b5e2030;
}
.wpv__add-btn:hover { opacity: .88; }

.wpv__calendario {
  background: white; border: 1px solid #e8f5e9; border-radius: 16px;
  padding: 1.25rem; box-shadow: 0 2px 12px #1b5e2008; position: sticky; top: 80px;
}
.wpv__cal-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 1rem; }
.wpv__cal-titulo { font-size: 14px; font-weight: 600; color: #1a2e1b; }
.wpv__cal-nav {
  width: 28px; height: 28px; border-radius: 7px; border: 1px solid #e2e8f0;
  background: white; font-size: 16px; color: #4a7c59; cursor: pointer;
  display: flex; align-items: center; justify-content: center; transition: all .15s;
}
.wpv__cal-nav:hover { background: #f0fdf4; border-color: #c8e6c9; color: #1b5e20; }
.wpv__cal-grid-header { display: grid; grid-template-columns: repeat(7, 1fr); margin-bottom: .5rem; }
.wpv__cal-grid-header span {
  text-align: center; font-size: 10px; font-weight: 600;
  color: #94a3b8; text-transform: uppercase; padding: 4px 0;
}
.wpv__cal-grid { display: grid; grid-template-columns: repeat(7, 1fr); gap: 2px; }
.wpv__cal-dia {
  aspect-ratio: 1; display: flex; flex-direction: column; align-items: center;
  justify-content: center; font-size: 13px; color: #4a7c59;
  border-radius: 8px; position: relative; cursor: default; transition: background .15s;
}
.wpv__cal-dia:not(.wpv__cal-dia--vacio):hover { background: #f0fdf4; }
.wpv__cal-dia--vacio { opacity: 0; pointer-events: none; }
.wpv__cal-dia--hoy { background: #1b5e20; color: white; font-weight: 600; }
.wpv__cal-dia--evento { font-weight: 600; color: #1b5e20; }
.wpv__cal-dot { width: 4px; height: 4px; border-radius: 50%; background: #1b5e20; position: absolute; bottom: 3px; }
.wpv__cal-dia--hoy .wpv__cal-dot { background: #a5d6a7; }
.wpv__cal-leyenda {
  display: flex; align-items: center; gap: 8px; margin-top: 1rem; font-size: 11px; color: #94a3b8;
  padding-top: 1rem; border-top: 1px solid #f0fdf4;
}
.wpv__cal-dot-lg { width: 6px; height: 6px; border-radius: 50%; background: #1b5e20; flex-shrink: 0; }

.wpv__config-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 1.25rem; }
.wpv__config-field { display: flex; flex-direction: column; gap: 6px; }
.wpv__config-field--full { grid-column: 1 / -1; }
.wpv__label { font-size: 13px; font-weight: 500; color: #4a7c59; margin-bottom: 2px; }
.wpv__input {
  padding: 10px 13px; border: 1.5px solid #e2e8f0; border-radius: 10px;
  font-size: 14px; background: #f8fafc; color: #1a2e1b; outline: none; transition: border-color .15s, box-shadow .15s;
}
.wpv__input:focus { border-color: #1b5e20; box-shadow: 0 0 0 3px #1b5e2015; }
.wpv__textarea {
  padding: 10px 13px; border: 1.5px solid #e2e8f0; border-radius: 10px;
  font-size: 14px; background: #f8fafc; color: #1a2e1b; outline: none;
  resize: vertical; transition: border-color .15s, box-shadow .15s; font-family: inherit; line-height: 1.5;
}
.wpv__textarea:focus { border-color: #1b5e20; box-shadow: 0 0 0 3px #1b5e2015; }
.wpv__textarea--tall { min-height: 180px; }
.wpv__web-status-card {
  display: flex; justify-content: space-between; align-items: center;
  padding: 16px 20px; border: 1.5px solid #e2e8f0; border-radius: 12px;
  background: #f8fafc; transition: all .2s;
}
.wpv__web-status-card--on { border-color: #a5d6a7; background: #f0fdf4; }
.wpv__web-status-info { display: flex; align-items: center; gap: 12px; }
.wpv__web-status-dot { width: 10px; height: 10px; border-radius: 50%; background: #e2e8f0; flex-shrink: 0; transition: background .3s; }
.wpv__web-status-dot--on { background: #1b5e20; box-shadow: 0 0 0 3px #1b5e2020; }
.wpv__web-status-label { font-size: 14px; font-weight: 500; color: #1a2e1b; }
.wpv__web-status-sub { font-size: 12px; color: #6b8f71; margin-top: 2px; }
.wpv__config-footer { display: flex; align-items: center; gap: 1rem; margin-top: 1.5rem; }
.wpv__save-btn {
  background: linear-gradient(135deg, #1b5e20, #2e7d32); color: #e8f5e9;
  border: none; padding: 11px 26px; border-radius: 10px; font-size: 14px;
  cursor: pointer; transition: opacity .2s; box-shadow: 0 2px 8px #1b5e2030;
}
.wpv__save-btn:hover { opacity: .88; }
.wpv__save-btn:disabled { opacity: .5; cursor: not-allowed; }
.wpv__cancel-btn {
  background: #f1f5f9; color: #64748b; border: none; padding: 11px 22px;
  border-radius: 10px; font-size: 14px; cursor: pointer; transition: background .15s;
}
.wpv__cancel-btn:hover { background: #e2e8f0; }
.wpv__saved-msg { display: flex; align-items: center; gap: 6px; color: #1b5e20; font-size: 14px; font-weight: 500; }

.wpv__modal-backdrop {
  position: fixed; inset: 0; background: rgba(0,0,0,.45);
  backdrop-filter: blur(6px); display: flex; align-items: center;
  justify-content: center; z-index: 1000; padding: 1rem;
}
.wpv__modal {
  background: white; border-radius: 20px; width: 100%; max-width: 480px;
  max-height: 92vh; overflow-y: auto; box-shadow: 0 24px 64px rgba(0,0,0,.18);
}
.wpv__modal--lg { max-width: 780px; }
.wpv__modal-header {
  display: flex; align-items: center; gap: 14px;
  padding: 22px 24px 18px; border-bottom: 1px solid #f0fdf4;
  position: sticky; top: 0; background: white; z-index: 1; border-radius: 20px 20px 0 0;
}
.wpv__modal-header-icon {
  width: 42px; height: 42px; border-radius: 11px;
  display: flex; align-items: center; justify-content: center; font-size: 18px; flex-shrink: 0;
}
.wpv__modal-header-icon--news { background: #e8f5e9; color: #1b5e20; }
.wpv__modal-header-icon--event { background: #e8eaf6; color: #3949ab; }
.wpv__modal-title { font-size: 17px; font-weight: 600; color: #1a2e1b; margin: 0 0 3px; }
.wpv__modal-subtitle { font-size: 13px; color: #6b8f71; margin: 0; }
.wpv__modal-close {
  margin-left: auto; background: #f1f5f9; border: none; width: 34px; height: 34px;
  border-radius: 9px; display: flex; align-items: center; justify-content: center;
  cursor: pointer; color: #64748b; font-size: 14px; transition: all .15s; flex-shrink: 0;
}
.wpv__modal-close:hover { background: #e2e8f0; color: #1a2e1b; }
.wpv__modal-body { padding: 22px 24px; }
.wpv__modal-footer {
  padding: 16px 24px; border-top: 1px solid #f0fdf4;
  display: flex; justify-content: flex-end; gap: 10px;
  position: sticky; bottom: 0; background: white; border-radius: 0 0 20px 20px;
}
.wpv__modal-two-col { display: grid; grid-template-columns: 1fr 1fr; gap: 24px; }
.wpv__modal-col { display: flex; flex-direction: column; gap: 16px; }
.wpv__field-group { display: flex; flex-direction: column; gap: 6px; }
.wpv__form-row { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; }

.wpv__upload-zone {
  border: 2px dashed #c8e6c9; border-radius: 12px; min-height: 180px;
  cursor: pointer; position: relative; overflow: hidden;
  transition: border-color .2s, background .2s;
  display: flex; align-items: center; justify-content: center; background: #f8fdf8;
}
.wpv__upload-zone:hover { border-color: #1b5e20; background: #f0fdf4; }
.wpv__upload-zone--has-img { border-style: solid; border-color: #a5d6a7; }
.wpv__upload-placeholder { display: flex; flex-direction: column; align-items: center; gap: 8px; color: #4a7c59; padding: 1rem; }
.wpv__upload-placeholder i { font-size: 2.5rem; opacity: .5; }
.wpv__upload-placeholder span { font-size: 13px; text-align: center; }
.wpv__upload-hint { font-size: 11px; color: #94a3b8; }
.wpv__upload-preview { width: 100%; height: 100%; object-fit: cover; position: absolute; inset: 0; }
.wpv__upload-overlay {
  position: absolute; inset: 0; background: rgba(0,0,0,.4);
  display: flex; align-items: center; justify-content: center;
  color: white; font-size: 13px; gap: 6px; opacity: 0; transition: opacity .2s;
}
.wpv__upload-zone:hover .wpv__upload-overlay { opacity: 1; }
.wpv__remove-img-btn {
  display: flex; align-items: center; gap: 4px; background: none; border: none;
  color: #94a3b8; font-size: 12px; cursor: pointer; padding: 4px 0; margin-top: 4px; transition: color .15s;
}
.wpv__remove-img-btn:hover { color: #dc2626; }

.modal-enter-active, .modal-leave-active { transition: all .25s ease; }
.modal-enter-from, .modal-leave-to { opacity: 0; transform: scale(.96) translateY(8px); }
.fade-enter-active, .fade-leave-active { transition: opacity .3s; }
.fade-enter-from, .fade-leave-to { opacity: 0; }

@media (max-width: 900px) {
  .wpv__cards-grid { grid-template-columns: repeat(2, 1fr); }
  .wpv__eventos-layout { grid-template-columns: 1fr; }
  .wpv__calendario { position: static; }
}
@media (max-width: 640px) {
  .wpv__cards-grid { grid-template-columns: 1fr; }
  .wpv__modal-two-col { grid-template-columns: 1fr; }
  .wpv__config-grid { grid-template-columns: 1fr; }
  .wpv__config-field--full { grid-column: 1; }
  .wpv__table-header, .wpv__table-row { grid-template-columns: 2fr 1fr 80px; }
  .wpv__table-header span:nth-child(3),
  .wpv__table-header span:nth-child(4),
  .wpv__table-row > span:nth-child(3),
  .wpv__table-row > div:nth-child(4) { display: none; }
}
</style>
