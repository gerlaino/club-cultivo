<template>
  <div class="stn__card">
    <div class="stn__header">
      <div class="stn__header-icon"><component :is="BookOpen" :size="15" /></div>
      <div>
        <div class="stn__title">Notas del equipo</div>
        <div class="stn__subtitle">Registros internos — no visibles para el paciente</div>
      </div>
    </div>

    <div v-if="canEdit" class="stn__nota-form">
      <textarea
        v-model.trim="notaTexto"
        class="stn__textarea"
        rows="3"
        placeholder="Agregar nota, observación o seguimiento…"
      ></textarea>
      <div class="stn__form-foot">
        <span class="stn__char-count">{{ notaTexto.length }} caracteres</span>
        <button class="stn__btn-primary" :disabled="store.creandoNota || !notaTexto" @click="agregarNota">
          <Plus :size="13" />
          Agregar nota
        </button>
      </div>
    </div>

    <div v-if="store.notasLoading" class="stn__loading"><DsSpinner :size="40" /></div>
    <div v-else-if="!store.notas.length" class="stn__empty">
      <div class="stn__empty-icon"><BookOpen :size="28" /></div>
      <div class="stn__empty-title">Sin notas registradas</div>
    </div>
    <div v-else class="stn__notas">
      <div v-for="n in store.notas" :key="n.id" class="stn__nota">
        <div class="stn__nota-header">
          <div class="stn__nota-meta">{{ formatDateTime(n.created_at) }}</div>
          <button v-if="canEdit" class="stn__btn-danger" @click="borrarNota(n)">
            <Trash2 :size="13" />
          </button>
        </div>
        <p class="stn__nota-text">{{ n.contenido }}</p>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref } from 'vue'
import { BookOpen, Plus, Trash2 } from 'lucide-vue-next'
import { usePacientesStore } from '../../stores/pacientes.js'
import { useConfirm } from '../../composables/useConfirm.js'
import DsSpinner from '../../design-system/components/Spinner.vue'

const props = defineProps({
  socioId: { type: Number, required: true },
  canEdit: { type: Boolean, default: false },
})

const store = usePacientesStore()
const { confirm } = useConfirm()

const notaTexto = ref('')

async function agregarNota() {
  const txt = notaTexto.value.trim()
  if (!txt) return
  try { await store.addNota(props.socioId, txt); notaTexto.value = '' } catch {}
}

async function borrarNota(n) {
  const ok = await confirm({ title: '¿Eliminar esta nota?', confirmText: 'Eliminar' })
  if (!ok) return
  try { await store.removeNota(n.id) } catch {}
}

function formatDateTime(d) {
  if (!d) return '—'
  return new Date(d).toLocaleString('es-AR', { day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' })
}
</script>

<style scoped>
.stn__card { background: #fff; border: 1px solid #e2e8f0; border-radius: 14px; overflow: hidden; }
.stn__header { display: flex; align-items: flex-start; gap: .65rem; padding: 1rem 1.25rem; border-bottom: 1px solid #f1f5f9; background: #fafbfc; }
.stn__header-icon { width: 32px; height: 32px; border-radius: 9px; background: rgba(180,83,9,.1); color: #b45309; display: flex; align-items: center; justify-content: center; flex-shrink: 0; }
.stn__title { font-size: .875rem; font-weight: 700; color: #0f172a; margin-top: .15rem; }
.stn__subtitle { font-size: .72rem; color: #64748b; margin-top: .1rem; }
.stn__nota-form { padding: 1.25rem; border-bottom: 1px solid #f1f5f9; }
.stn__textarea { width: 100%; background: #f8fafc; border: 1.5px solid #e2e8f0; border-radius: 10px; padding: .75rem 1rem; font-size: .875rem; color: #0f172a; outline: none; resize: vertical; min-height: 80px; transition: border-color .15s; box-sizing: border-box; font-family: inherit; }
.stn__textarea:focus { border-color: #1b5e20; background: #fff; }
.stn__form-foot { display: flex; justify-content: space-between; align-items: center; margin-top: .65rem; }
.stn__char-count { font-size: .72rem; color: #94a3b8; }
.stn__loading { display: flex; justify-content: center; padding: 2rem; }
.stn__empty { text-align: center; padding: 3rem 1rem; color: #94a3b8; }
.stn__empty-icon { display: flex; justify-content: center; margin-bottom: .5rem; opacity: .4; }
.stn__empty-title { font-size: .875rem; font-weight: 600; color: #64748b; }
.stn__notas { display: flex; flex-direction: column; }
.stn__nota { padding: .875rem 1.25rem; border-bottom: 1px solid #f8fafc; }
.stn__nota:last-child { border-bottom: none; }
.stn__nota-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: .4rem; }
.stn__nota-meta { font-size: .72rem; color: #94a3b8; }
.stn__nota-text { font-size: .85rem; color: #374151; margin: 0; line-height: 1.6; border-left: 2px solid #d4e6d4; padding-left: .75rem; }
.stn__btn-primary { display: inline-flex; align-items: center; gap: .4rem; background: #1b5e20; color: #fff; border: none; padding: .6rem 1.1rem; border-radius: 9px; font-size: .82rem; font-weight: 600; cursor: pointer; transition: background .15s; }
.stn__btn-primary:hover:not(:disabled) { background: #144a18; }
.stn__btn-primary:disabled { opacity: .5; cursor: not-allowed; }
.stn__btn-danger { background: none; border: none; color: #94a3b8; cursor: pointer; padding: .2rem .4rem; border-radius: 5px; display: flex; align-items: center; transition: all .12s; }
.stn__btn-danger:hover { background: #fef2f2; color: #dc2626; }
</style>
