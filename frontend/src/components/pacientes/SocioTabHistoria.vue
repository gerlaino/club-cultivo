<template>
  <div class="sth__card">
    <div class="sth__header">
      <div class="sth__header-icon"><component :is="ClipboardList" :size="15" /></div>
      <div>
        <div class="sth__title">Historia clínica estructurada</div>
        <div class="sth__subtitle">Solo visible para admin y médico</div>
      </div>
    </div>
    <div class="sth__body">

      <div class="sth__section">
        <div class="sth__section-title">Datos básicos</div>
        <div class="sth__grid">
          <div class="sth__field">
            <label class="sth__label">Grupo sanguíneo</label>
            <input v-model="hcForm.grupo_sanguineo" class="sth__input" placeholder="Ej: A+, O-" style="max-width:120px" />
          </div>
          <div class="sth__field">
            <label class="sth__label">Alergias</label>
            <input v-model="hcForm.alergias" class="sth__input" placeholder="Alergias conocidas" />
          </div>
          <div class="sth__field sth__field--full">
            <label class="sth__label">Medicación habitual</label>
            <input v-model="hcForm.medicacion_habitual" class="sth__input" placeholder="Medicamentos que toma regularmente" />
          </div>
        </div>
      </div>

      <div class="sth__section">
        <div class="sth__section-title">Consulta</div>
        <div class="sth__field sth__field--full">
          <label class="sth__label">Motivo de consulta</label>
          <textarea v-model="hcForm.motivo_consulta" class="sth__textarea" rows="3" placeholder="Razón por la que el paciente consulta…" />
        </div>
        <div class="sth__field sth__field--full">
          <label class="sth__label">Anamnesis</label>
          <textarea v-model="hcForm.anamnesis" class="sth__textarea" rows="4" placeholder="Historia de la enfermedad actual, síntomas, evolución…" />
        </div>
      </div>

      <div class="sth__section">
        <div class="sth__section-title">Antecedentes</div>
        <div class="sth__field sth__field--full">
          <label class="sth__label">Antecedentes personales</label>
          <textarea v-model="hcForm.antecedentes_personales" class="sth__textarea" rows="3" placeholder="Enfermedades previas, cirugías, hospitalizaciones…" />
        </div>
        <div class="sth__field sth__field--full">
          <label class="sth__label">Antecedentes familiares</label>
          <textarea v-model="hcForm.antecedentes_familiares" class="sth__textarea" rows="3" placeholder="Enfermedades en familiares directos…" />
        </div>
      </div>

      <div class="sth__section">
        <div class="sth__section-title">Diagnóstico</div>
        <div class="sth__grid">
          <div class="sth__field">
            <label class="sth__label">Diagnóstico principal</label>
            <input v-model="hcForm.diagnostico_principal" class="sth__input" placeholder="CIE-10 o descripción libre" />
          </div>
          <div class="sth__field">
            <label class="sth__label">Diagnóstico secundario</label>
            <input v-model="hcForm.diagnostico_secundario" class="sth__input" placeholder="Opcional" />
          </div>
        </div>
        <div class="sth__field sth__field--full">
          <label class="sth__label">Evolución clínica</label>
          <textarea v-model="hcForm.evolucion_clinica" class="sth__textarea" rows="4" placeholder="Evolución del paciente, respuesta al tratamiento, observaciones…" />
        </div>
      </div>

      <div class="sth__section sth__section--last">
        <div class="sth__section-title">Notas adicionales</div>
        <div class="sth__field sth__field--full">
          <label class="sth__label">Notas libres</label>
          <textarea v-model="notasClinicas" class="sth__textarea" rows="5" placeholder="Cualquier otra observación clínica…" />
        </div>
      </div>

      <div class="sth__foot">
        <span v-if="notasClinicasSaved" class="sth__save-ok">
          <CheckCircle :size="13" /> Guardado
        </span>
        <span v-else class="sth__save-pending">Sin guardar</span>
        <button class="sth__btn-primary" :disabled="notasClinicasSaving || notasClinicasSaved" @click="saveNotasClinicas">
          <Save :size="13" :stroke-width="2" />
          {{ notasClinicasSaving ? 'Guardando…' : 'Guardar historia' }}
        </button>
      </div>
    </div>
  </div>
</template>

<script setup>
import { toRef } from 'vue'
import { ClipboardList, CheckCircle, Save } from 'lucide-vue-next'
import { useSocioHistoriaClinica } from '../../composables/useSocioHistoriaClinica.js'

const props = defineProps({
  socioId: { type: Number, required: true },
  s:       { type: Object, default: null },
})

const s = toRef(props, 's')

const {
  notasClinicas, notasClinicasSaved, notasClinicasSaving,
  hcForm, saveNotasClinicas,
} = useSocioHistoriaClinica(props.socioId, { s })
</script>

<style scoped>
.sth__card { background: #fff; border: 1px solid var(--c-slate-200); border-radius: 14px; overflow: hidden; }
.sth__header { display: flex; align-items: flex-start; gap: .65rem; padding: 1rem 1.25rem; border-bottom: 1px solid var(--c-slate-100); background: #fafbfc; }
.sth__header-icon { width: 32px; height: 32px; border-radius: 9px; background: rgba(180,83,9,.1); color: #b45309; display: flex; align-items: center; justify-content: center; flex-shrink: 0; }
.sth__title { font-size: .875rem; font-weight: 700; color: var(--c-slate-900); margin-top: .15rem; }
.sth__subtitle { font-size: .72rem; color: var(--c-slate-500); margin-top: .1rem; }
.sth__body { padding: 1rem 1.25rem 1.25rem; display: flex; flex-direction: column; gap: 1.25rem; }
.sth__section { display: flex; flex-direction: column; gap: .75rem; padding-bottom: 1rem; border-bottom: 1px solid #f0f4f0; }
.sth__section--last { border-bottom: none; padding-bottom: 0; }
.sth__section-title { font-size: .7rem; font-weight: 700; text-transform: uppercase; letter-spacing: .08em; color: #8a9a8a; }
.sth__grid { display: grid; grid-template-columns: 1fr 1fr; gap: .75rem; }
@media (max-width: 540px) { .sth__grid { grid-template-columns: 1fr; } }
.sth__field { display: flex; flex-direction: column; gap: .35rem; }
.sth__field--full { grid-column: 1 / -1; }
.sth__label { font-size: .75rem; font-weight: 600; color: var(--c-slate-500); }
.sth__input { padding: .55rem .75rem; border: 1.5px solid var(--c-slate-200); border-radius: 8px; font-size: .875rem; color: var(--c-slate-900); outline: none; transition: border-color .15s; width: 100%; box-sizing: border-box; }
.sth__input:focus { border-color: #1b5e20; }
.sth__textarea { width: 100%; background: var(--c-slate-50); border: 1.5px solid var(--c-slate-200); border-radius: 10px; padding: .75rem 1rem; font-size: .875rem; color: var(--c-slate-900); outline: none; resize: vertical; min-height: 80px; transition: border-color .15s; box-sizing: border-box; font-family: inherit; }
.sth__textarea:focus { border-color: #1b5e20; background: #fff; }
.sth__foot { display: flex; justify-content: space-between; align-items: center; }
.sth__save-ok { font-size: .75rem; color: #15803d; display: flex; align-items: center; gap: .3rem; }
.sth__save-pending { font-size: .75rem; color: var(--c-slate-400); }
.sth__btn-primary { display: inline-flex; align-items: center; gap: .4rem; background: #1b5e20; color: #fff; border: none; padding: .6rem 1.1rem; border-radius: 9px; font-size: .82rem; font-weight: 600; cursor: pointer; transition: background .15s; }
.sth__btn-primary:hover:not(:disabled) { background: #144a18; }
.sth__btn-primary:disabled { opacity: .5; cursor: not-allowed; }
</style>
