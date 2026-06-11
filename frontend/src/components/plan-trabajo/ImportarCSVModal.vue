<script setup>
import { ref } from 'vue'
import DsSpinner from '../../design-system/components/Spinner.vue'
import { importPlanCSV } from '../../lib/api.js'
import { useToast } from '../../composables/useToast.js'

const emit = defineEmits(['close', 'imported'])
const toast = useToast()

const fileInputRef = ref(null)
const archivo      = ref(null)
const titulo       = ref('')
const notas        = ref('')
const importando   = ref(false)
const error        = ref(null)
const resultado    = ref(null)   // { plan, importadas, errores }
const dragOver     = ref(false)

function onFileChange(e) {
  const f = e.target.files[0]
  if (f) setArchivo(f)
  e.target.value = ''
}
function onDrop(e) {
  dragOver.value = false
  const f = e.dataTransfer?.files[0]
  if (f) setArchivo(f)
}
function setArchivo(f) {
  if (!f.name.match(/\.(csv|xlsx|xls)$/i)) {
    error.value = 'El archivo debe ser .csv, .xlsx o .xls'
    return
  }
  archivo.value = f
  if (!titulo.value) titulo.value = f.name.replace(/\.csv$/i, '').replace(/[-_]/g, ' ')
  error.value = null
}

async function importar() {
  if (!archivo.value) return
  importando.value = true; error.value = null; resultado.value = null
  try {
    const fd = new FormData()
    fd.append('archivo', archivo.value)
    fd.append('titulo',  titulo.value || 'Plan importado')
    if (notas.value) fd.append('notas', notas.value)

    const { data } = await importPlanCSV(fd)
    resultado.value = data
  } catch (e) {
    error.value = e?.response?.data?.error || 'Error al importar el archivo'
  } finally {
    importando.value = false
  }
}

function confirmar() {
  emit('imported', resultado.value.plan)
}

function reset() {
  archivo.value    = null
  titulo.value     = ''
  notas.value      = ''
  error.value      = null
  resultado.value  = null
}

// Descarga template de ejemplo
function descargarTemplate() {
  const rows = [
    ['dia', 'tipo', 'titulo', 'descripcion', 'rol_sugerido', 'prioridad'],
    [0,  'riego',    'Riego inicial',       'pH objetivo: 6.2\nEC objetivo: 1.4', 'cultivador', 'normal'],
    [1,  'medicion', 'Medición ambiental',  'Temperatura, humedad, VPD',           'cultivador', 'normal'],
    [3,  'poda',     'Defoliación',         'Remover hojas amarillas',              'cultivador', 'alta'],
    [7,  'inspeccion','Control de plagas',  'Revisar envés de las hojas',          'supervisor', 'alta'],
    [14, 'riego',    'Riego con fertilizante', 'pH: 6.0, EC: 1.8, Flora Bloom 5ml/L', 'cultivador', 'normal'],
  ]
  const csv = rows.map(r => r.map(c => `"${String(c ?? '').replace(/"/g, '""')}"`).join(',')).join('\n')
  const blob = new Blob(['\xEF\xBB\xBF' + csv], { type: 'text/csv;charset=utf-8' })
  const url  = URL.createObjectURL(blob)
  const a    = document.createElement('a')
  a.href = url; a.download = 'plantilla-ejemplo.csv'
  document.body.appendChild(a); a.click()
  document.body.removeChild(a); URL.revokeObjectURL(url)
}
</script>

<template>
  <Teleport to="body">
    <div class="icm__overlay" @click.self="$emit('close')">
      <div class="icm__panel">

        <!-- Header -->
        <div class="icm__hdr">
          <div class="icm__hdr-ico"><i class="bi bi-filetype-csv"></i></div>
          <div>
            <h2 class="icm__title">Importar plantilla</h2>
            <p class="icm__sub">Cargá un CSV o Excel con las tareas del plan</p>
          </div>
          <button class="icm__close" @click="$emit('close')"><i class="bi bi-x-lg"></i></button>
        </div>

        <!-- Body -->
        <div class="icm__body">

          <!-- Resultado exitoso -->
          <template v-if="resultado">
            <div class="icm__resultado">
              <div class="icm__resultado-ico"><i class="bi bi-check-circle-fill"></i></div>
              <div class="icm__resultado-info">
                <div class="icm__resultado-title">{{ resultado.importadas }} tarea{{ resultado.importadas !== 1 ? 's' : '' }} importada{{ resultado.importadas !== 1 ? 's' : '' }}</div>
                <div class="icm__resultado-plan">Plan: "{{ resultado.plan.titulo }}"</div>
              </div>
            </div>

            <div v-if="resultado.errores?.length" class="icm__errores">
              <div class="icm__errores-title">{{ resultado.errores.length }} fila{{ resultado.errores.length !== 1 ? 's' : '' }} omitida{{ resultado.errores.length !== 1 ? 's' : '' }}:</div>
              <ul class="icm__errores-list">
                <li v-for="(e, i) in resultado.errores" :key="i">{{ e }}</li>
              </ul>
            </div>
          </template>

          <!-- Formulario de importación -->
          <template v-else>
            <div v-if="error" class="icm__alert">{{ error }}</div>

            <!-- Formato esperado -->
            <div class="icm__formato">
              <div class="icm__formato-hdr">
                <span class="icm__formato-title">Formato esperado</span>
                <button class="icm__btn-template" @click="descargarTemplate">
                  <i class="bi bi-download"></i> Descargar ejemplo (.csv)
                </button>
              </div>
              <div class="icm__chips">
                <span class="icm__chip icm__chip--req">dia</span>
                <span class="icm__chip icm__chip--req">tipo</span>
                <span class="icm__chip">titulo</span>
                <span class="icm__chip">descripcion</span>
                <span class="icm__chip">rol_sugerido</span>
                <span class="icm__chip">prioridad</span>
              </div>
              <div class="icm__tipos-validos">
                Tipos válidos: <code>riego · poda · medicion · limpieza · cosecha · transplante · inspeccion · nutricion · defoliacion · scrog_lst · ajuste_luz · revision_plagas · otro</code>
              </div>
            </div>

            <!-- Dropzone -->
            <div
              v-if="!archivo"
              class="icm__dropzone"
              :class="{ 'icm__dropzone--drag': dragOver }"
              @dragover.prevent="dragOver = true"
              @dragleave.prevent="dragOver = false"
              @drop.prevent="onDrop"
              @click="fileInputRef.click()"
            >
              <input ref="fileInputRef" type="file" accept=".csv,.xlsx,.xls" style="display:none" @change="onFileChange" />
              <i class="bi bi-cloud-arrow-up icm__drop-ico"></i>
              <p class="icm__drop-main">Arrastrá tu CSV acá</p>
              <p class="icm__drop-sub">o hacé click para seleccionar · .csv · .xlsx · .xls</p>
            </div>

            <!-- Archivo seleccionado -->
            <div v-else class="icm__archivo">
              <i class="bi bi-file-earmark-spreadsheet icm__archivo-ico"></i>
              <div class="icm__archivo-info">
                <div class="icm__archivo-nombre">{{ archivo.name }}</div>
                <div class="icm__archivo-size">{{ (archivo.size / 1024).toFixed(1) }} KB</div>
              </div>
              <button class="icm__archivo-quitar" @click="reset">
                <i class="bi bi-x-lg"></i>
              </button>
            </div>

            <!-- Título y notas del plan -->
            <div v-if="archivo" class="icm__fields">
              <div class="icm__field">
                <label class="icm__label">Título de la plantilla</label>
                <input class="icm__input" v-model="titulo" placeholder="Plan importado…" />
              </div>
              <div class="icm__field">
                <label class="icm__label">Notas <span class="icm__hint">(opcional)</span></label>
                <input class="icm__input" v-model="notas" placeholder="Descripción general…" />
              </div>
            </div>
          </template>

        </div>

        <!-- Footer -->
        <div class="icm__footer">
          <button class="icm__btn-ghost" @click="resultado ? reset() : $emit('close')">
            {{ resultado ? 'Importar otro' : 'Cancelar' }}
          </button>
          <button
            v-if="!resultado"
            class="icm__btn-primary"
            :disabled="!archivo || importando"
            @click="importar"
          >
            <DsSpinner v-if="importando" :size="14" />
            <i v-else class="bi bi-upload"></i>
            {{ importando ? 'Importando…' : 'Importar' }}
          </button>
          <button
            v-else
            class="icm__btn-primary"
            @click="confirmar"
          >
            <i class="bi bi-check-lg"></i>
            Listo, ver plantilla
          </button>
        </div>

      </div>
    </div>
  </Teleport>
</template>

<style scoped>
.icm__overlay { position: fixed; inset: 0; background: rgba(0,0,0,.45); display: flex; align-items: center; justify-content: center; z-index: 1065; padding: 1rem; backdrop-filter: blur(3px); }
.icm__panel   { background: #fff; border-radius: 16px; width: 100%; max-width: 480px; display: flex; flex-direction: column; box-shadow: 0 24px 64px rgba(0,0,0,.15); max-height: 90vh; }

.icm__hdr     { display: flex; align-items: center; gap: .875rem; padding: 1.25rem 1.4rem 1rem; border-bottom: 1px solid #f1f5f9; flex-shrink: 0; }
.icm__hdr-ico { width: 38px; height: 38px; border-radius: 10px; background: #f0fdf4; color: #1b5e20; display: flex; align-items: center; justify-content: center; font-size: 1.1rem; flex-shrink: 0; }
.icm__title   { font-size: 1rem; font-weight: 800; color: #0f172a; margin: 0 0 .1rem; }
.icm__sub     { font-size: .75rem; color: #94a3b8; margin: 0; }
.icm__close   { margin-left: auto; background: #f1f5f1; border: none; width: 30px; height: 30px; border-radius: 8px; cursor: pointer; display: flex; align-items: center; justify-content: center; color: #64748b; flex-shrink: 0; }
.icm__close:hover { background: #c8e6c9; color: #1b5e20; }

.icm__body  { padding: 1.25rem 1.4rem; display: flex; flex-direction: column; gap: 1rem; overflow-y: auto; flex: 1; }
.icm__alert { background: #fef2f2; border: 1px solid #fecaca; color: #dc2626; padding: .65rem .875rem; border-radius: 8px; font-size: .82rem; }

/* Formato */
.icm__formato { background: #f8fafc; border: 1.5px solid #e2e8f0; border-radius: 10px; padding: .875rem 1rem; display: flex; flex-direction: column; gap: .5rem; }
.icm__formato-hdr { display: flex; align-items: center; justify-content: space-between; gap: .5rem; }
.icm__formato-title { font-size: .72rem; font-weight: 700; color: #374151; text-transform: uppercase; letter-spacing: .04em; }
.icm__btn-template { display: inline-flex; align-items: center; gap: .3rem; background: none; border: 1.5px solid #e2e8f0; color: #475569; padding: .25rem .65rem; border-radius: 6px; font-size: .72rem; font-weight: 700; cursor: pointer; }
.icm__btn-template:hover { border-color: #1b5e20; color: #1b5e20; }
.icm__chips { display: flex; flex-wrap: wrap; gap: .3rem; }
.icm__chip  { font-size: .7rem; font-weight: 700; color: #475569; background: #e2e8f0; padding: .2em .55em; border-radius: 5px; font-family: monospace; }
.icm__chip--req { background: #dcfce7; color: #1b5e20; }
.icm__tipos-validos { font-size: .68rem; color: #94a3b8; line-height: 1.5; }
.icm__tipos-validos code { font-family: monospace; font-size: .67rem; }

/* Dropzone */
.icm__dropzone { border: 2px dashed #c8e6c9; border-radius: 12px; padding: 2rem 1.5rem; display: flex; flex-direction: column; align-items: center; gap: .4rem; cursor: pointer; transition: all .15s; background: #fafcfa; text-align: center; }
.icm__dropzone:hover, .icm__dropzone--drag { border-color: #1b5e20; background: #f0fdf4; }
.icm__drop-ico  { font-size: 2rem; color: #1b5e20; }
.icm__drop-main { font-size: .875rem; font-weight: 700; color: #0f172a; margin: 0; }
.icm__drop-sub  { font-size: .78rem; color: #64748b; margin: 0; }

/* Archivo seleccionado */
.icm__archivo { display: flex; align-items: center; gap: .75rem; padding: .75rem 1rem; background: #f0fdf4; border: 1.5px solid #c8e6c9; border-radius: 10px; }
.icm__archivo-ico { font-size: 1.5rem; color: #1b5e20; flex-shrink: 0; }
.icm__archivo-info { flex: 1; min-width: 0; }
.icm__archivo-nombre { font-size: .875rem; font-weight: 700; color: #0f172a; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.icm__archivo-size { font-size: .72rem; color: #64748b; }
.icm__archivo-quitar { background: none; border: none; color: #94a3b8; cursor: pointer; padding: .25rem; border-radius: 5px; display: flex; align-items: center; }
.icm__archivo-quitar:hover { color: #dc2626; background: #fef2f2; }

/* Fields */
.icm__fields { display: flex; flex-direction: column; gap: .6rem; }
.icm__field  { display: flex; flex-direction: column; gap: .25rem; }
.icm__label  { font-size: .72rem; font-weight: 700; color: #374151; text-transform: uppercase; letter-spacing: .04em; }
.icm__hint   { font-weight: 400; text-transform: none; color: #94a3b8; }
.icm__input  { background: #f8fafc; border: 1.5px solid #e2e8f0; border-radius: 9px; padding: .6rem .875rem; font-size: .875rem; color: #0f172a; width: 100%; box-sizing: border-box; }
.icm__input:focus { outline: none; border-color: #1b5e20; box-shadow: 0 0 0 3px rgba(27,94,32,.08); }

/* Resultado */
.icm__resultado { display: flex; align-items: center; gap: .875rem; padding: 1rem 1.1rem; background: #f0fdf4; border: 1.5px solid #c8e6c9; border-radius: 12px; }
.icm__resultado-ico { font-size: 1.75rem; color: #1b5e20; flex-shrink: 0; }
.icm__resultado-title { font-size: 1rem; font-weight: 800; color: #0f172a; }
.icm__resultado-plan { font-size: .78rem; color: #60725d; margin-top: .15rem; }
.icm__errores { background: #fffbeb; border: 1.5px solid #fde68a; border-radius: 10px; padding: .75rem 1rem; }
.icm__errores-title { font-size: .72rem; font-weight: 700; color: #b45309; margin-bottom: .35rem; }
.icm__errores-list { margin: 0; padding-left: 1.1rem; display: flex; flex-direction: column; gap: .2rem; }
.icm__errores-list li { font-size: .75rem; color: #92400e; }

/* Footer */
.icm__footer { display: flex; align-items: center; justify-content: flex-end; gap: .75rem; padding: 1rem 1.4rem; border-top: 1px solid #f1f5f9; flex-shrink: 0; }
.icm__btn-ghost   { background: transparent; color: #64748b; border: 1.5px solid #e2e8f0; padding: .6rem 1rem; border-radius: 9px; font-size: .875rem; font-weight: 600; cursor: pointer; }
.icm__btn-primary { display: inline-flex; align-items: center; gap: .4rem; background: #1b5e20; color: #fff; border: none; padding: .6rem 1.25rem; border-radius: 9px; font-size: .875rem; font-weight: 700; cursor: pointer; }
.icm__btn-primary:hover:not(:disabled) { background: #144a18; }
.icm__btn-primary:disabled { opacity: .55; cursor: not-allowed; }
</style>
