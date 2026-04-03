<script setup>
import { ref, computed, onMounted } from 'vue'
import { useAuthStore } from '../stores/auth'
import { getDocumentos, createDocumento, deleteDocumento } from '../lib/api.js'

const auth    = useAuthStore()
const loading = ref(true)
const docs    = ref([])
const busqueda= ref('')
const filtroTipo = ref('')
const showModal  = ref(false)
const guardando  = ref(false)
const docError   = ref(null)
const docFile    = ref(null)
const docFileInput = ref(null)
const docForm = ref({ tipo: '', titulo: '', fecha_vencimiento: '', descripcion: '' })

// ── Mapeo rol → tipos permitidos ─────────────────────────
const TIPOS_POR_ROL = {
  admin:      ['plan_trabajo','reprocann','informe_semestral','contrato','habilitacion','otro'],
  agricultor: ['plan_trabajo','reprocann','informe_semestral','otro'],
  medico:     ['indicacion','historia_clinica','consentimiento','certificado','otro'],
  abogado:    ['contrato','habilitacion','poder','acta','otro'],
  auditor:    [], // solo lectura
  cultivador: [],
}

const DOC_META = {
  plan_trabajo:      { label:'Plan de trabajo',    emoji:'📋', color:'#1b5e20' },
  reprocann:         { label:'REPROCANN',           emoji:'🏛️', color:'#2563eb' },
  informe_semestral: { label:'Informe semestral',   emoji:'📊', color:'#7c3aed' },
  indicacion:        { label:'Indicación médica',   emoji:'💊', color:'#0891b2' },
  historia_clinica:  { label:'Historia clínica',    emoji:'📁', color:'#0891b2' },
  consentimiento:    { label:'Consentimiento',       emoji:'✍️', color:'#0891b2' },
  certificado:       { label:'Certificado',          emoji:'🏅', color:'#d97706' },
  contrato:          { label:'Contrato',             emoji:'📜', color:'#64748b' },
  habilitacion:      { label:'Habilitación',         emoji:'✅', color:'#16a34a' },
  poder:             { label:'Poder notarial',       emoji:'⚖️', color:'#64748b' },
  acta:              { label:'Acta',                 emoji:'📝', color:'#64748b' },
  otro:              { label:'Otro',                 emoji:'📄', color:'#94a3b8' },
}

const ESTADOS_META = {
  vigente:  { label:'Vigente',  color:'#16a34a', bg:'#dcfce7' },
  vencido:  { label:'Vencido',  color:'#dc2626', bg:'#fef2f2' },
  pendiente:{ label:'Pendiente',color:'#d97706', bg:'#fef3c7' },
}

const userRole      = computed(() => auth.user?.role || '')
const tiposPermitidos = computed(() => TIPOS_POR_ROL[userRole.value] || [])
const puedeSubir    = computed(() => tiposPermitidos.value.length > 0)

// Docs filtrados según rol + búsqueda + tipo
const docsFiltrados = computed(() => {
  let lista = docs.value

  // Si no es admin, filtrar por tipos del rol
  if (userRole.value !== 'admin') {
    lista = lista.filter(d => tiposPermitidos.value.includes(d.tipo))
  }

  if (filtroTipo.value) {
    lista = lista.filter(d => d.tipo === filtroTipo.value)
  }

  if (busqueda.value.trim()) {
    const q = busqueda.value.toLowerCase()
    lista = lista.filter(d =>
      d.titulo.toLowerCase().includes(q) ||
      d.descripcion?.toLowerCase().includes(q) ||
      DOC_META[d.tipo]?.label.toLowerCase().includes(q)
    )
  }

  return lista.sort((a,b) => new Date(b.created_at) - new Date(a.created_at))
})

// Tipos visibles para filtros (según rol)
const tiposDisponibles = computed(() => {
  const enDocs = [...new Set(docs.value.map(d => d.tipo))]
  if (userRole.value === 'admin') return enDocs
  return enDocs.filter(t => tiposPermitidos.value.includes(t))
})

function diasParaVencer(d) {
  if (!d.fecha_vencimiento) return null
  return Math.floor((new Date(d.fecha_vencimiento) - new Date()) / 86400000)
}
function formatFecha(f) {
  if (!f) return '—'
  return new Date(f).toLocaleDateString('es-AR', { day:'numeric', month:'long', year:'numeric' })
}
function formatDateTime(f) {
  if (!f) return '—'
  return new Date(f).toLocaleString('es-AR', { day:'numeric', month:'short', year:'numeric', hour:'2-digit', minute:'2-digit' })
}

function abrirModal() {
  docForm.value = { tipo: tiposPermitidos.value[0] || '', titulo: '', fecha_vencimiento: '', descripcion: '' }
  docError.value = null
  docFile.value  = null
  showModal.value = true
}

function handleDocFile(e) { docFile.value = e.target.files?.[0] || null }

async function subirDocumento() {
  if (!docForm.value.titulo || !docForm.value.tipo) return
  guardando.value = true; docError.value = null
  try {
    const fd = new FormData()
    fd.append('documento[tipo]',   docForm.value.tipo)
    fd.append('documento[titulo]', docForm.value.titulo)
    if (docForm.value.descripcion)       fd.append('documento[descripcion]',       docForm.value.descripcion)
    if (docForm.value.fecha_vencimiento) fd.append('documento[fecha_vencimiento]', docForm.value.fecha_vencimiento)
    if (docFile.value) fd.append('archivo', docFile.value)
    const { data } = await createDocumento(fd)
    docs.value.unshift(data)
    showModal.value = false
  } catch(e) {
    docError.value = e?.response?.data?.errors?.join(', ') || 'Error al guardar'
  }
  finally { guardando.value = false }
}

async function eliminar(doc) {
  if (!confirm(`¿Eliminás "${doc.titulo}"?`)) return
  try {
    await deleteDocumento(doc.id)
    docs.value = docs.value.filter(d => d.id !== doc.id)
  } catch {}
}

onMounted(async () => {
  try {
    const { data } = await getDocumentos()
    docs.value = data || []
  } catch {}
  finally { loading.value = false }
})
</script>

<template>
  <div class="dv">

    <!-- Header -->
    <div class="dv__header">
      <div>
        <h1 class="dv__title">📁 Documentos</h1>
        <p class="dv__subtitle">Gestión documental del club</p>
      </div>
      <button v-if="puedeSubir" class="dv__btn-primary" @click="abrirModal">
        <i class="bi bi-file-earmark-arrow-up"></i> Subir documento
      </button>
    </div>

    <!-- Buscador y filtros -->
    <div class="dv__filtros">
      <div class="dv__search-wrap">
        <i class="bi bi-search dv__search-icon"></i>
        <input
          v-model="busqueda"
          type="text"
          class="dv__search"
          placeholder="Buscar por título, descripción o tipo…"
        />
        <button v-if="busqueda" class="dv__search-clear" @click="busqueda = ''">
          <i class="bi bi-x"></i>
        </button>
      </div>
      <div class="dv__tipo-filtros">
        <button
          class="dv__tipo-pill"
          :class="{ 'dv__tipo-pill--active': filtroTipo === '' }"
          @click="filtroTipo = ''"
        >Todos <span class="dv__pill-count">{{ docsFiltrados.length }}</span></button>
        <button
          v-for="tipo in tiposDisponibles"
          :key="tipo"
          class="dv__tipo-pill"
          :class="{ 'dv__tipo-pill--active': filtroTipo === tipo }"
          :style="filtroTipo === tipo ? { borderColor: DOC_META[tipo]?.color, color: DOC_META[tipo]?.color, background: DOC_META[tipo]?.color + '12' } : {}"
          @click="filtroTipo = filtroTipo === tipo ? '' : tipo"
        >
          {{ DOC_META[tipo]?.emoji }} {{ DOC_META[tipo]?.label }}
        </button>
      </div>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="dv__loading">
      <div class="dv__spinner"></div>
      <span>Cargando documentos…</span>
    </div>

    <!-- Sin resultados -->
    <div v-else-if="docsFiltrados.length === 0" class="dv__empty">
      <div class="dv__empty-icon">📭</div>
      <p>{{ busqueda || filtroTipo ? 'Sin documentos con ese criterio' : 'Sin documentos todavía' }}</p>
      <button v-if="puedeSubir && !busqueda && !filtroTipo" class="dv__btn-outline" @click="abrirModal">
        <i class="bi bi-file-earmark-arrow-up"></i> Subir primer documento
      </button>
    </div>

    <!-- Grid de documentos -->
    <div v-else class="dv__grid">
      <div v-for="d in docsFiltrados" :key="d.id" class="dv__doc"
           :class="{ 'dv__doc--vencido': d.estado === 'vencido' }">

        <!-- Tipo y estado -->
        <div class="dv__doc-top">
          <div class="dv__doc-tipo" :style="{ background: (DOC_META[d.tipo]?.color || '#94a3b8') + '15', color: DOC_META[d.tipo]?.color || '#94a3b8' }">
            {{ DOC_META[d.tipo]?.emoji }} {{ DOC_META[d.tipo]?.label || d.tipo }}
          </div>
          <span class="dv__doc-estado"
                :style="{ background: ESTADOS_META[d.estado]?.bg, color: ESTADOS_META[d.estado]?.color }">
            {{ ESTADOS_META[d.estado]?.label || d.estado }}
          </span>
        </div>

        <!-- Título y descripción -->
        <div class="dv__doc-titulo">{{ d.titulo }}</div>
        <div v-if="d.descripcion" class="dv__doc-desc">{{ d.descripcion }}</div>

        <!-- Vencimiento -->
        <div v-if="d.fecha_vencimiento" class="dv__doc-vence"
             :class="{ 'dv__doc-vence--warn': diasParaVencer(d) !== null && diasParaVencer(d) <= 30 && diasParaVencer(d) > 0, 'dv__doc-vence--danger': diasParaVencer(d) !== null && diasParaVencer(d) <= 0 }">
          <i class="bi bi-calendar-event"></i>
          <span v-if="diasParaVencer(d) <= 0">Venció el {{ formatFecha(d.fecha_vencimiento) }}</span>
          <span v-else-if="diasParaVencer(d) <= 30">Vence en {{ diasParaVencer(d) }} días</span>
          <span v-else>Vence {{ formatFecha(d.fecha_vencimiento) }}</span>
        </div>

        <!-- Footer -->
        <div class="dv__doc-footer">
          <div class="dv__doc-meta">
            <span>{{ d.usuario }}</span>
            <span class="dv__dot">·</span>
            <span>{{ formatDateTime(d.created_at) }}</span>
          </div>
          <div class="dv__doc-actions">
            <a v-if="d.tiene_archivo && d.archivo_url"
               :href="d.archivo_url" target="_blank"
               class="dv__action-btn dv__action-btn--dl" title="Descargar">
              <i class="bi bi-download"></i>
            </a>
            <button v-if="userRole === 'admin' || d.usuario === auth.user?.nombre_completo"
                    class="dv__action-btn dv__action-btn--del" title="Eliminar"
                    @click="eliminar(d)">
              <i class="bi bi-trash3"></i>
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- Modal subir documento -->
    <Teleport to="body">
      <div v-if="showModal" class="dv__overlay" @click.self="showModal = false">
        <div class="dv__modal">
          <div class="dv__modal-header">
            <div>
              <h3 class="dv__modal-title">📁 Subir documento</h3>
              <p class="dv__modal-sub">El documento quedará visible para los roles correspondientes</p>
            </div>
            <button class="dv__modal-close" @click="showModal = false"><i class="bi bi-x-lg"></i></button>
          </div>
          <div class="dv__modal-body">
            <div v-if="docError" class="dv__alert">{{ docError }}</div>

            <div class="dv__field">
              <label class="dv__label">Tipo de documento <span class="dv__req">*</span></label>
              <div class="dv__selector">
                <button v-for="tipo in tiposPermitidos" :key="tipo" type="button"
                        class="dv__sel-btn"
                        :class="{ 'dv__sel-btn--active': docForm.tipo === tipo }"
                        :style="docForm.tipo === tipo ? { borderColor: DOC_META[tipo]?.color, background: DOC_META[tipo]?.color + '15', color: DOC_META[tipo]?.color } : {}"
                        @click="docForm.tipo = tipo">
                  {{ DOC_META[tipo]?.emoji }} {{ DOC_META[tipo]?.label }}
                </button>
              </div>
            </div>

            <div class="dv__field">
              <label class="dv__label">Título <span class="dv__req">*</span></label>
              <input type="text" class="dv__input" v-model="docForm.titulo"
                     placeholder="Ej: Plan de trabajo 2026 · Club Mitocondria" />
            </div>

            <div class="dv__field">
              <label class="dv__label">Fecha de vencimiento <span class="dv__optional">si aplica</span></label>
              <input type="date" class="dv__input" v-model="docForm.fecha_vencimiento" />
            </div>

            <div class="dv__field">
              <label class="dv__label">Descripción <span class="dv__optional">opcional</span></label>
              <textarea class="dv__input dv__textarea" rows="2" v-model="docForm.descripcion"
                        placeholder="Notas adicionales, período que cubre, observaciones…"></textarea>
            </div>

            <div class="dv__field">
              <label class="dv__label">Archivo <span class="dv__optional">PDF, DOC, imagen</span></label>
              <div class="dv__file-upload" @click="docFileInput?.click()">
                <i class="bi bi-file-earmark-arrow-up" style="font-size:1.25rem"></i>
                <div>
                  <div v-if="docFile" class="dv__file-name">{{ docFile.name }}</div>
                  <div v-else>Hacer clic para seleccionar archivo</div>
                  <div class="dv__file-hint">PDF, DOC, DOCX, JPG, PNG · Máx. 10MB</div>
                </div>
              </div>
              <input ref="docFileInput" type="file"
                     accept=".pdf,.doc,.docx,.png,.jpg,.jpeg"
                     style="display:none" @change="handleDocFile" />
            </div>
          </div>
          <div class="dv__modal-footer">
            <button class="dv__btn-ghost" @click="showModal = false">Cancelar</button>
            <button class="dv__btn-primary" @click="subirDocumento"
                    :disabled="guardando || !docForm.titulo || !docForm.tipo">
              <span v-if="guardando" class="dv__spinner dv__spinner--sm"></span>
              <i v-else class="bi bi-check-lg"></i>Guardar documento
            </button>
          </div>
        </div>
      </div>
    </Teleport>

  </div>
</template>

<style scoped>
.dv { padding: 2rem 1.5rem; max-width: 1100px; margin: 0 auto; font-family: system-ui, -apple-system, sans-serif; color: #1a1a1a; }
@media (max-width: 640px) { .dv { padding: 1.25rem 1rem; } }

/* Header */
.dv__header { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; margin-bottom: 1.75rem; flex-wrap: wrap; }
.dv__title    { font-size: 1.65rem; font-weight: 800; margin: 0 0 .2rem; letter-spacing: -.03em; }
.dv__subtitle { font-size: .82rem; color: #60725d; margin: 0; }

/* Filtros */
.dv__filtros { display: flex; flex-direction: column; gap: .75rem; margin-bottom: 1.5rem; }
.dv__search-wrap { position: relative; }
.dv__search-icon { position: absolute; left: .9rem; top: 50%; transform: translateY(-50%); color: #94a3b8; font-size: .9rem; pointer-events: none; }
.dv__search { width: 100%; box-sizing: border-box; padding: .7rem 2.5rem .7rem 2.5rem; border: 1.5px solid #d4e6d4; border-radius: 10px; background: #f4f8f4; font-size: .875rem; color: #1a1a1a; transition: border .15s; }
.dv__search:focus { outline: none; border-color: #1b5e20; background: #fff; }
.dv__search-clear { position: absolute; right: .75rem; top: 50%; transform: translateY(-50%); background: none; border: none; color: #94a3b8; cursor: pointer; font-size: 1rem; padding: 0; }
.dv__search-clear:hover { color: #1b5e20; }
.dv__tipo-filtros { display: flex; gap: .4rem; flex-wrap: wrap; }
.dv__tipo-pill { display: inline-flex; align-items: center; gap: .35rem; padding: .35rem .85rem; border: 1.5px solid #d4e6d4; border-radius: 999px; background: #f4f8f4; font-size: .75rem; font-weight: 600; cursor: pointer; transition: all .15s; color: #60725d; }
.dv__tipo-pill:hover { border-color: #1b5e20; color: #1b5e20; }
.dv__tipo-pill--active { background: #e8f5e9; border-color: #1b5e20; color: #1b5e20; }
.dv__pill-count { background: #d4e6d4; color: #1b5e20; font-size: .62rem; font-weight: 800; padding: .1em .45em; border-radius: 999px; }

/* Loading / empty */
.dv__loading { display: flex; align-items: center; justify-content: center; gap: .75rem; padding: 5rem; color: #94a3b8; font-size: .875rem; }
.dv__spinner { width: 20px; height: 20px; border: 2.5px solid #d4e6d4; border-top-color: #1b5e20; border-radius: 50%; animation: dv-spin .6s linear infinite; }
.dv__spinner--sm { width: 14px; height: 14px; border-width: 2px; border-color: rgba(255,255,255,.3); border-top-color: #fff; }
@keyframes dv-spin { to { transform: rotate(360deg); } }
.dv__empty { text-align: center; padding: 4rem 1rem; color: #60725d; }
.dv__empty-icon { font-size: 3rem; margin-bottom: .75rem; }
.dv__empty p { font-size: .95rem; margin: 0 0 1rem; }

/* Grid documentos */
.dv__grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(300px, 1fr)); gap: 1rem; }
@media (max-width: 640px) { .dv__grid { grid-template-columns: 1fr; } }

.dv__doc { background: #fff; border: 1px solid #d4e6d4; border-radius: 14px; padding: 1.1rem 1.15rem; display: flex; flex-direction: column; gap: .5rem; transition: box-shadow .15s; }
.dv__doc:hover { box-shadow: 0 4px 16px rgba(27,94,32,.1); }
.dv__doc--vencido { border-color: #fecaca; background: #fff5f5; }

.dv__doc-top { display: flex; align-items: center; justify-content: space-between; gap: .5rem; }
.dv__doc-tipo { display: inline-flex; align-items: center; gap: .3rem; font-size: .72rem; font-weight: 700; padding: .25em .65em; border-radius: 6px; }
.dv__doc-estado { font-size: .65rem; font-weight: 700; text-transform: uppercase; letter-spacing: .05em; padding: .2em .6em; border-radius: 999px; }
.dv__doc-titulo { font-size: .95rem; font-weight: 700; color: #1a1a1a; line-height: 1.3; }
.dv__doc-desc { font-size: .78rem; color: #60725d; line-height: 1.5; }
.dv__doc-vence { display: flex; align-items: center; gap: .35rem; font-size: .75rem; font-weight: 600; color: #60725d; }
.dv__doc-vence--warn   { color: #b45309; }
.dv__doc-vence--danger { color: #dc2626; }
.dv__doc-footer { display: flex; align-items: center; justify-content: space-between; margin-top: .25rem; padding-top: .65rem; border-top: 1px solid #e8f0e9; }
.dv__doc-meta { font-size: .7rem; color: #94a3b8; display: flex; align-items: center; gap: .3rem; flex-wrap: wrap; }
.dv__dot { color: #d4e6d4; }
.dv__doc-actions { display: flex; gap: .35rem; }
.dv__action-btn { width: 28px; height: 28px; border-radius: 7px; border: 1px solid #d4e6d4; background: #f4f8f4; cursor: pointer; display: flex; align-items: center; justify-content: center; font-size: .8rem; transition: all .15s; text-decoration: none; color: #60725d; }
.dv__action-btn--dl:hover  { background: #e8f5e9; color: #1b5e20; border-color: #1b5e20; }
.dv__action-btn--del:hover { background: #fef2f2; color: #dc2626; border-color: #fecaca; }

/* Modal */
.dv__overlay { position: fixed; inset: 0; background: rgba(0,0,0,.4); display: flex; align-items: center; justify-content: center; z-index: 1050; padding: 1rem; backdrop-filter: blur(3px); }
.dv__modal { background: #fff; border-radius: 16px; width: 100%; max-width: 520px; max-height: 92vh; overflow-y: auto; box-shadow: 0 24px 64px rgba(27,94,32,.15); display: flex; flex-direction: column; }
.dv__modal-header { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; padding: 1.25rem 1.5rem 1rem; border-bottom: 1px solid #e8f0e9; position: sticky; top: 0; background: #fff; z-index: 1; }
.dv__modal-title { font-size: 1rem; font-weight: 700; color: #1a1a1a; margin: 0; }
.dv__modal-sub   { font-size: .75rem; color: #60725d; margin: .2rem 0 0; }
.dv__modal-close { background: #e8f5e9; border: none; width: 28px; height: 28px; border-radius: 7px; cursor: pointer; display: flex; align-items: center; justify-content: center; color: #60725d; transition: all .15s; }
.dv__modal-close:hover { background: #c8e6c9; color: #1b5e20; }
.dv__modal-body { padding: 1.25rem 1.5rem; flex: 1; display: flex; flex-direction: column; gap: .9rem; }
.dv__modal-footer { display: flex; justify-content: flex-end; gap: .75rem; padding: 1rem 1.5rem; border-top: 1px solid #e8f0e9; position: sticky; bottom: 0; background: #fff; }
.dv__field { display: flex; flex-direction: column; gap: .35rem; }
.dv__label { font-size: .78rem; font-weight: 700; color: #374151; text-transform: uppercase; letter-spacing: .04em; }
.dv__optional { font-size: .65rem; font-weight: 400; color: #94a3b8; text-transform: none; letter-spacing: 0; }
.dv__req { color: #dc2626; }
.dv__input { background: #f4f8f4; border: 1.5px solid #d4e6d4; border-radius: 8px; padding: .6rem .85rem; font-size: .875rem; color: #1a1a1a; width: 100%; box-sizing: border-box; transition: border .15s; }
.dv__input:focus { outline: none; border-color: #1b5e20; background: #fff; }
.dv__textarea { resize: vertical; min-height: 60px; }
.dv__selector { display: flex; gap: .4rem; flex-wrap: wrap; }
.dv__sel-btn { display: flex; align-items: center; gap: .3rem; padding: .4rem .8rem; border: 1.5px solid #d4e6d4; border-radius: 8px; background: #f4f8f4; font-size: .78rem; font-weight: 600; cursor: pointer; transition: all .15s; }
.dv__sel-btn:hover { border-color: #1b5e20; }
.dv__sel-btn--active { transform: translateY(-1px); box-shadow: 0 2px 8px rgba(0,0,0,.08); }
.dv__file-upload { display: flex; align-items: center; gap: .85rem; padding: 1rem 1.1rem; border: 1.5px dashed #d4e6d4; border-radius: 10px; background: #f4f8f4; cursor: pointer; font-size: .85rem; color: #60725d; transition: all .15s; }
.dv__file-upload:hover { border-color: #1b5e20; background: #f0fdf4; color: #1b5e20; }
.dv__file-name { font-weight: 600; color: #1b5e20; margin-bottom: .15rem; }
.dv__file-hint { font-size: .7rem; color: #94a3b8; }
.dv__alert { background: #fef2f2; border: 1px solid #fecaca; color: #dc2626; padding: .65rem .9rem; border-radius: 8px; font-size: .82rem; }
.dv__btn-primary { display: inline-flex; align-items: center; gap: .4rem; background: #1b5e20; color: #fff; border: none; padding: .6rem 1.25rem; border-radius: 8px; font-size: .875rem; font-weight: 600; cursor: pointer; transition: background .15s; white-space: nowrap; }
.dv__btn-primary:hover { background: #104417; }
.dv__btn-primary:disabled { opacity: .6; cursor: not-allowed; }
.dv__btn-ghost { background: transparent; color: #60725d; border: 1px solid #d4e6d4; padding: .6rem 1.1rem; border-radius: 8px; font-size: .875rem; font-weight: 500; cursor: pointer; transition: all .15s; }
.dv__btn-ghost:hover { background: #f0fdf4; color: #1b5e20; }
.dv__btn-outline { display: inline-flex; align-items: center; gap: .3rem; background: transparent; color: #1b5e20; border: 1.5px solid #d4e6d4; padding: .5rem 1.1rem; border-radius: 8px; font-size: .8rem; font-weight: 600; cursor: pointer; transition: all .15s; }
.dv__btn-outline:hover { border-color: #1b5e20; background: #f0fdf4; }
</style>
