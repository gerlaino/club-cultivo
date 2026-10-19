<script setup>
// Quién es: identidad y contacto. La misma sección en el alta (paso 1) y en la edición (solapa).
import { computed } from 'vue'
import AppDatePicker from '../../ui/AppDatePicker.vue'
import { edad } from './pacienteForm.js'

const props = defineProps({
  form:    { type: Object, required: true },
  errores: { type: Object, default: () => ({}) },
  // Si el DNI ya es de otro paciente de la organización: { id, nombre }.
  duplicado: { type: Object, default: null },
  autofocus: { type: Boolean, default: false },
})
const emit = defineEmits(['dni-listo'])

const hoyISO = new Date().toLocaleDateString('en-CA')
const anios = computed(() => edad(props.form.fecha_nacimiento))
</script>

<template>
  <div class="pf-seccion">
    <div class="pf-grid">
      <div class="pf-campo pf-full-m">
        <label class="pf-label" for="pf-nombre">Nombre</label>
        <input id="pf-nombre" v-model.trim="form.nombre" class="pf-input" :class="{ 'pf-input--err': errores.nombre }"
               autocomplete="off" :autofocus="autofocus" placeholder="Juan Martín" />
        <span v-if="errores.nombre" class="pf-err">{{ errores.nombre }}</span>
      </div>
      <div class="pf-campo pf-full-m">
        <label class="pf-label" for="pf-apellido">Apellido</label>
        <input id="pf-apellido" v-model.trim="form.apellido" class="pf-input" :class="{ 'pf-input--err': errores.apellido }"
               autocomplete="off" placeholder="García" />
        <span v-if="errores.apellido" class="pf-err">{{ errores.apellido }}</span>
      </div>
      <div class="pf-campo pf-full-m">
        <label class="pf-label" for="pf-dni">DNI</label>
        <input id="pf-dni" v-model.trim="form.dni" class="pf-input pf-input--mono"
               :class="{ 'pf-input--err': errores.dni || duplicado }" inputmode="numeric" autocomplete="off"
               placeholder="Sin puntos" @blur="emit('dni-listo')" />
        <span v-if="errores.dni" class="pf-err">{{ errores.dni }}</span>
      </div>
      <div class="pf-campo pf-full-m">
        <label class="pf-label">Fecha de nacimiento <span v-if="anios !== null" class="pf-opc">· {{ anios }} años</span></label>
        <AppDatePicker v-model="form.fecha_nacimiento" :max="hoyISO"
                       :input-class="['pf-input', { 'pf-input--err': errores.fecha_nacimiento }]" />
        <span v-if="errores.fecha_nacimiento" class="pf-err">{{ errores.fecha_nacimiento }}</span>
      </div>
    </div>

    <div v-if="duplicado" class="pf-aviso pf-aviso--danger" role="alert">
      <i class="bi bi-person-exclamation"></i>
      <div>
        Ese DNI ya es de <strong>{{ duplicado.nombre }}</strong>, paciente de la organización.
        <RouterLink :to="`/pacientes/${duplicado.id}`">Ver su ficha</RouterLink>
      </div>
    </div>

    <div class="pf-campo">
      <label class="pf-label" for="pf-apodo">Apodo <span class="pf-opc">opcional · cómo le dicen, para encontrarlo en el mostrador</span></label>
      <input id="pf-apodo" v-model.trim="form.apodo" class="pf-input" maxlength="60" autocomplete="off" placeholder="El Tano" />
    </div>

    <hr class="pf-sep" />
    <p class="pf-sub">Contacto</p>
    <div class="pf-grid">
      <div class="pf-campo pf-full-m">
        <label class="pf-label" for="pf-tel">Teléfono <span class="pf-opc">opcional</span></label>
        <input id="pf-tel" v-model.trim="form.telefono" class="pf-input" type="tel" inputmode="tel" autocomplete="off" placeholder="11 1234-5678" />
      </div>
      <div class="pf-campo pf-full-m">
        <label class="pf-label" for="pf-mail">Mail <span class="pf-opc">opcional · para el portal y los avisos</span></label>
        <input id="pf-mail" v-model.trim="form.email" class="pf-input" :class="{ 'pf-input--err': errores.email }"
               type="email" inputmode="email" autocomplete="off" placeholder="nombre@mail.com" />
        <span v-if="errores.email" class="pf-err">{{ errores.email }}</span>
      </div>
    </div>
  </div>
</template>
