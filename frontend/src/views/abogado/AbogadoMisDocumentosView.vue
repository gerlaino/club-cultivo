<template>
  <div class="abd">
    <div class="abd__header">
      <h1 class="abd__title"><Files :size="20" :stroke-width="1.75" /> Mis Documentos</h1>
      <button class="abd__btn-subir" @click="modalAbierto = true">
        <Upload :size="15" /> Subir documento
      </button>
    </div>

    <div v-if="loading" class="abd__loading">Cargando…</div>

    <template v-else>
      <div v-if="!documentos.length" class="abd__empty">No hay documentos cargados aún.</div>
      <table v-else class="abd__table">
        <thead>
          <tr><th>Tipo</th><th>Nombre</th><th>Vencimiento</th><th></th></tr>
        </thead>
        <tbody>
          <tr v-for="d in documentos" :key="d.id">
            <td><span class="abd__badge">{{ d.tipo }}</span></td>
            <td>{{ d.nombre || '—' }}</td>
            <td>{{ formatDate(d.fecha_vencimiento) }}</td>
            <td>
              <button class="abd__dl" @click="descargar(d.id)" :disabled="!d.tiene_archivo">
                <Download :size="14" />
              </button>
            </td>
          </tr>
        </tbody>
      </table>
    </template>

    <!-- Modal subir documento -->
    <div v-modal="() => modalAbierto = false" v-if="modalAbierto" class="abd__overlay" @click.self="modalAbierto = false">
      <div class="abd__modal">
        <h2 class="abd__modal-title">Subir documento legal</h2>
        <div class="abd__form-group">
          <label class="abd__label">Tipo</label>
          <select v-model="form.tipo" class="abd__select">
            <option v-for="t in TIPOS_LEGALES" :key="t" :value="t">{{ t }}</option>
          </select>
        </div>
        <div class="abd__form-group">
          <label class="abd__label">Nombre / descripción</label>
          <input v-model="form.nombre" class="abd__input" placeholder="Ej: Estatuto actualizado 2026" />
        </div>
        <div class="abd__form-group">
          <label class="abd__label">Vencimiento (opcional)</label>
          <AppDatePicker v-model="form.fecha_vencimiento" />
        </div>
        <div class="abd__form-group">
          <label class="abd__label">Archivo</label>
          <input type="file" @change="onFile" class="abd__file" />
        </div>
        <div class="abd__modal-actions">
          <button class="abd__btn-cancel" @click="modalAbierto = false">Cancelar</button>
          <button class="abd__btn-ok" @click="subir" :disabled="subiendo">
            {{ subiendo ? 'Subiendo…' : 'Guardar' }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import AppDatePicker from '../../components/ui/AppDatePicker.vue'
import { Files, Upload, Download } from 'lucide-vue-next'
import api from '../../lib/api.js'

const TIPOS_LEGALES = ['contrato_socio', 'estatuto', 'acta_asamblea', 'reglamento_interno', 'plan_trabajo', 'informe_semestral', 'otro']

const loading     = ref(false)
const documentos  = ref([])
const modalAbierto = ref(false)
const subiendo    = ref(false)
const form        = ref({ tipo: 'estatuto', nombre: '', fecha_vencimiento: '' })
const archivo     = ref(null)

async function cargar() {
  loading.value = true
  try {
    const res = await api.get('/documentos')
    documentos.value = res.data
  } finally {
    loading.value = false
  }
}

function onFile(e) {
  archivo.value = e.target.files[0] || null
}

async function subir() {
  subiendo.value = true
  try {
    const res = await api.post('/documentos', {
      documento: { tipo: form.value.tipo, nombre: form.value.nombre, fecha_vencimiento: form.value.fecha_vencimiento || null }
    })
    if (archivo.value) {
      const fd = new FormData()
      fd.append('archivo', archivo.value)
      await api.post(`/documentos/${res.data.id}/subir_archivo`, fd, { headers: { 'Content-Type': 'multipart/form-data' } })
    }
    modalAbierto.value = false
    form.value = { tipo: 'estatuto', nombre: '', fecha_vencimiento: '' }
    archivo.value = null
    await cargar()
  } finally {
    subiendo.value = false
  }
}

async function descargar(id) {
  const res = await api.get(`/documentos/${id}/descargar`, { responseType: 'blob' })
  const url = URL.createObjectURL(res.data)
  const a   = document.createElement('a')
  a.href = url; a.download = `documento_${id}`; a.click()
  URL.revokeObjectURL(url)
}

const formatDate = (d) => d ? new Date(d).toLocaleDateString('es-AR') : '—'

onMounted(cargar)
</script>

<style scoped>
.abd { padding: var(--sp-6); max-width: 800px; }
.abd__header { display: flex; align-items: center; justify-content: space-between; margin-bottom: var(--sp-5); gap: var(--sp-4); flex-wrap: wrap; }
.abd__title { font-size: var(--fs-20); font-weight: 700; color: var(--c-ink-900); display: flex; align-items: center; gap: var(--sp-2); margin: 0; }
.abd__btn-subir { display: flex; align-items: center; gap: var(--sp-2); background: #5B6473; color: #fff; border: none; border-radius: var(--r-md); padding: 8px 16px; font-size: var(--fs-14); font-weight: 600; cursor: pointer; }
.abd__btn-subir:hover { background: #4a525f; }
.abd__loading, .abd__empty { color: var(--c-ink-500); padding: var(--sp-8); text-align: center; font-size: var(--fs-14); }
.abd__table { width: 100%; border-collapse: collapse; font-size: var(--fs-14); }
.abd__table th { text-align: left; padding: var(--sp-2) var(--sp-3); background: var(--c-ink-50); font-weight: 600; color: var(--c-ink-600); border-bottom: 1px solid var(--c-ink-100); }
.abd__table td { padding: var(--sp-2) var(--sp-3); border-bottom: 1px solid var(--c-ink-50); color: var(--c-ink-800); }
.abd__badge { display: inline-block; padding: 2px 8px; border-radius: 999px; font-size: var(--fs-11); font-weight: 600; background: rgba(91,100,115,.1); color: #5B6473; }
.abd__dl { background: none; border: 1px solid var(--c-ink-200); border-radius: var(--r-sm); padding: 4px 6px; cursor: pointer; color: var(--c-ink-600); display: flex; align-items: center; }
.abd__dl:disabled { opacity: .35; cursor: default; }
.abd__dl:not(:disabled):hover { background: var(--c-ink-50); }
/* Modal */
.abd__overlay { position: fixed; inset: 0; background: rgba(0,0,0,.4); display: flex; align-items: center; justify-content: center; z-index: 100; }
.abd__modal { background: var(--c-paper); border-radius: var(--r-xl); padding: var(--sp-6); width: min(480px, 90vw); display: flex; flex-direction: column; gap: var(--sp-4); }
.abd__modal-title { font-size: var(--fs-18); font-weight: 700; color: var(--c-ink-900); margin: 0; }
.abd__form-group { display: flex; flex-direction: column; gap: var(--sp-1); }
.abd__label { font-size: var(--fs-13); font-weight: 600; color: var(--c-ink-700); }
.abd__input, .abd__select { border: 1.5px solid var(--c-ink-200); border-radius: var(--r-md); padding: 8px 12px; font-size: var(--fs-14); color: var(--c-ink-900); background: var(--c-ink-50); }
.abd__file { font-size: var(--fs-13); color: var(--c-ink-700); }
.abd__modal-actions { display: flex; justify-content: flex-end; gap: var(--sp-3); }
.abd__btn-cancel { background: none; border: 1.5px solid var(--c-ink-200); border-radius: var(--r-md); padding: 8px 16px; font-size: var(--fs-14); cursor: pointer; color: var(--c-ink-700); }
.abd__btn-ok { background: #5B6473; color: #fff; border: none; border-radius: var(--r-md); padding: 8px 20px; font-size: var(--fs-14); font-weight: 600; cursor: pointer; }
.abd__btn-ok:disabled { opacity: .6; cursor: default; }
</style>
