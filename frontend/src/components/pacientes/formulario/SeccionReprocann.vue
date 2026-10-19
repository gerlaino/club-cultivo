<script setup>
// Su REPROCANN. Primero DE QUIÉN es (vinculado / adherente), después CÓMO está. Al vinculado se le
// pregunta en palabras de quien lo carga («todavía no tiene», «está en trámite»…) y el sistema
// calcula el estado; al adherente se le carga tal como figura en su organización.
import { computed, watch } from 'vue'
import AppDatePicker from '../../ui/AppDatePicker.vue'
import { OPCIONES_VINCULADO, ESTADOS_ADHERENTE, esAdherente, reprocannCerrado } from './pacienteForm.js'
import { REPROCANN_SITUACION } from '../../../composables/useSituacionPaciente.js'

const props = defineProps({
  form:    { type: Object, required: true },
  errores: { type: Object, default: () => ({}) },
  // En la edición: el motivo y la fecha de un «No indicado» / «Rechazado», para decir por qué está trabado.
  resultado: { type: Object, default: null },
})

const ICONOS = { sin: 'bi-person-plus', tramite: 'bi-hourglass-split', aprobado: 'bi-patch-check', vencido: 'bi-calendar-x' }
const adherente = computed(() => esAdherente(props.form))
const cerrado   = computed(() => reprocannCerrado(props.form))
const pideDatos = computed(() => adherente.value || ['aprobado', 'vencido'].includes(props.form.opcion_reprocann))

// Pasar a adherente arranca «vigente»: es lo que tiene quien viene de otra organización.
watch(() => props.form.reprocann_vinculo, (v) => {
  if (v === 'otra_organizacion' && !ESTADOS_ADHERENTE.some(e => e.value === props.form.reprocann_estado)) {
    props.form.reprocann_estado = 'activo'
  }
})

function elegirVinculo(v) { props.form.reprocann_vinculo = v }
</script>

<template>
  <div class="pf-seccion">
    <div v-if="cerrado" class="pf-aviso pf-aviso--warn">
      <i class="bi bi-lock"></i>
      <div>
        Su REPROCANN está <strong>{{ REPROCANN_SITUACION[form._estado_original]?.label }}</strong>
        <template v-if="resultado?.el"> desde el {{ resultado.el }}</template> y el paciente quedó inactivo.
        <template v-if="resultado?.motivo"><br /><em>«{{ resultado.motivo }}»</em><br /></template>
        Para cambiarlo, usá <strong>Volver a entrevistar</strong> en la ficha.
      </div>
    </div>

    <template v-else>
      <div class="pf-campo">
        <span class="pf-label">¿De quién es su REPROCANN?</span>
        <div class="pf-opciones" role="radiogroup" aria-label="De quién es su REPROCANN">
          <button type="button" role="radio" :aria-checked="!adherente" class="pf-opcion" :class="{ 'pf-opcion--on': !adherente }"
                  @click="elegirVinculo('organizacion')">
            <span class="pf-opcion__ico"><i class="bi bi-building-check"></i></span>
            <span>
              <span class="pf-opcion__t">Vinculado</span>
              <span class="pf-opcion__d">Lo tiene (o lo va a tramitar) con la organización.</span>
            </span>
            <i v-if="!adherente" class="bi bi-check-circle-fill pf-opcion__check"></i>
          </button>
          <button type="button" role="radio" :aria-checked="adherente" class="pf-opcion" :class="{ 'pf-opcion--on': adherente }"
                  @click="elegirVinculo('otra_organizacion')">
            <span class="pf-opcion__ico"><i class="bi bi-arrow-left-right"></i></span>
            <span>
              <span class="pf-opcion__t">Adherente</span>
              <span class="pf-opcion__d">Lo tiene vigente con otra organización. Puede retirar.</span>
            </span>
            <i v-if="adherente" class="bi bi-check-circle-fill pf-opcion__check"></i>
          </button>
        </div>
      </div>

      <!-- Vinculado: cómo está, en palabras de quien lo carga. -->
      <div v-if="!adherente" class="pf-campo">
        <span class="pf-label">¿Cómo está su REPROCANN?</span>
        <div class="pf-opciones pf-opciones--4" role="radiogroup" aria-label="Cómo está su REPROCANN">
          <button v-for="o in OPCIONES_VINCULADO" :key="o.value" type="button" role="radio"
                  :aria-checked="form.opcion_reprocann === o.value"
                  class="pf-opcion" :class="{ 'pf-opcion--on': form.opcion_reprocann === o.value }"
                  @click="form.opcion_reprocann = o.value">
            <span class="pf-opcion__ico"><i class="bi" :class="ICONOS[o.value]"></i></span>
            <span>
              <span class="pf-opcion__t">{{ o.label }}</span>
              <span class="pf-opcion__d">{{ o.ayuda }}</span>
            </span>
            <i v-if="form.opcion_reprocann === o.value" class="bi bi-check-circle-fill pf-opcion__check"></i>
          </button>
        </div>
      </div>

      <!-- Adherente: tal como figura en su organización. -->
      <div v-else class="pf-campo">
        <span class="pf-label">¿Cómo figura en su organización?</span>
        <div class="pf-chips" role="radiogroup" aria-label="Estado del REPROCANN del adherente">
          <button v-for="e in ESTADOS_ADHERENTE" :key="e.value" type="button" role="radio"
                  :aria-checked="form.reprocann_estado === e.value"
                  class="pf-chip" :class="{ 'pf-chip--on': form.reprocann_estado === e.value }"
                  @click="form.reprocann_estado = e.value">{{ e.label }}</button>
        </div>
        <span class="pf-hint">No le pedimos entrevista ni lo tramitamos: lo hace su organización. Cuando se vincule con
          nosotros, se cambia acá y el sistema empieza a seguir su REPROCANN.</span>
      </div>

      <div v-if="pideDatos" class="pf-grid">
        <div class="pf-campo pf-full-m">
          <label class="pf-label" for="pf-rep-num">
            Número de REPROCANN
            <span v-if="adherente || form.opcion_reprocann === 'vencido'" class="pf-opc">opcional</span>
          </label>
          <input id="pf-rep-num" v-model.trim="form.reprocann_numero" class="pf-input pf-input--mono"
                 :class="{ 'pf-input--err': errores.reprocann_numero }" autocomplete="off" placeholder="Como figura en el certificado" />
          <span v-if="errores.reprocann_numero" class="pf-err">{{ errores.reprocann_numero }}</span>
        </div>
        <div class="pf-campo pf-full-m">
          <label class="pf-label">
            Vencimiento
            <span v-if="adherente || form.opcion_reprocann === 'vencido'" class="pf-opc">opcional</span>
          </label>
          <AppDatePicker v-model="form.reprocann_vencimiento"
                         :input-class="['pf-input', { 'pf-input--err': errores.reprocann_vencimiento }]" />
          <span v-if="errores.reprocann_vencimiento" class="pf-err">{{ errores.reprocann_vencimiento }}</span>
        </div>
      </div>

    </template>
  </div>
</template>
