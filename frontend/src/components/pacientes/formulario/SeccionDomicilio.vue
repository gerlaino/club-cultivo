<script setup>
// Dónde vive. Opcional: se anota a la persona con lo que hay y la dirección se completa después
// (donde sí hace falta es al despachar un envío, y ahí se pide).
defineProps({
  form:       { type: Object, required: true },
  // En el alta se puede anotar una segunda dirección de entrega; en la edición viven en la solapa
  // «Direcciones» de la ficha (varias, con nombre).
  conEntrega: { type: Boolean, default: false },
})
</script>

<template>
  <div class="pf-seccion">
    <p class="pf-intro">El domicilio del trámite. Es también la dirección de entrega por defecto si se le manda un envío.</p>
    <div class="pf-grid pf-grid--3">
      <div class="pf-campo pf-full-m">
        <label class="pf-label" for="pf-calle">Calle</label>
        <input id="pf-calle" v-model.trim="form.domicilio_calle" class="pf-input" autocomplete="off" placeholder="Av. Corrientes" />
      </div>
      <div class="pf-campo">
        <label class="pf-label" for="pf-altura">Altura</label>
        <input id="pf-altura" v-model.trim="form.domicilio_altura" class="pf-input" inputmode="numeric" autocomplete="off" placeholder="1234" />
      </div>
      <div class="pf-campo">
        <label class="pf-label" for="pf-piso">Piso / depto</label>
        <div style="display:flex;gap:.4rem">
          <input id="pf-piso" v-model.trim="form.domicilio_piso" class="pf-input" autocomplete="off" placeholder="3" aria-label="Piso" />
          <input v-model.trim="form.domicilio_depto" class="pf-input" autocomplete="off" placeholder="B" aria-label="Depto" />
        </div>
      </div>
    </div>
    <div class="pf-grid">
      <div class="pf-campo pf-full-m">
        <label class="pf-label" for="pf-barrio">Barrio</label>
        <input id="pf-barrio" v-model.trim="form.domicilio_barrio" class="pf-input" autocomplete="off" placeholder="Almagro" />
      </div>
      <div class="pf-campo pf-full-m">
        <label class="pf-label" for="pf-ciudad">Ciudad</label>
        <input id="pf-ciudad" v-model.trim="form.domicilio_ciudad" class="pf-input" autocomplete="off" placeholder="CABA" />
      </div>
    </div>

    <details v-if="conEntrega" class="pf-entrega">
      <summary><i class="bi bi-truck"></i> Recibe en otra dirección <span class="pf-opc">opcional</span></summary>
      <div class="pf-seccion" style="margin-top:1rem">
        <div class="pf-campo">
          <label class="pf-label" for="pf-env-nombre">Nombre de la dirección</label>
          <input id="pf-env-nombre" v-model.trim="form.envio_etiqueta" class="pf-input" autocomplete="off" placeholder="Trabajo" />
        </div>
        <div class="pf-grid pf-grid--3">
          <div class="pf-campo pf-full-m">
            <label class="pf-label">Calle</label>
            <input v-model.trim="form.envio_calle" class="pf-input" autocomplete="off" />
          </div>
          <div class="pf-campo">
            <label class="pf-label">Altura</label>
            <input v-model.trim="form.envio_altura" class="pf-input" inputmode="numeric" autocomplete="off" />
          </div>
          <div class="pf-campo">
            <label class="pf-label">Piso / depto</label>
            <div style="display:flex;gap:.4rem">
              <input v-model.trim="form.envio_piso" class="pf-input" aria-label="Piso" autocomplete="off" />
              <input v-model.trim="form.envio_depto" class="pf-input" aria-label="Depto" autocomplete="off" />
            </div>
          </div>
        </div>
        <div class="pf-grid">
          <div class="pf-campo pf-full-m">
            <label class="pf-label">Barrio</label>
            <input v-model.trim="form.envio_barrio" class="pf-input" autocomplete="off" />
          </div>
          <div class="pf-campo pf-full-m">
            <label class="pf-label">Ciudad</label>
            <input v-model.trim="form.envio_ciudad" class="pf-input" autocomplete="off" />
          </div>
        </div>
      </div>
    </details>
  </div>
</template>

<style scoped>
.pf-entrega { border-top: 1px dashed var(--c-slate-200); padding-top: 1rem; }
.pf-entrega summary { cursor: pointer; font-weight: 700; font-size: .88rem; color: var(--c-slate-700); display: flex; gap: .5rem; align-items: center; list-style: none; }
.pf-entrega summary::-webkit-details-marker { display: none; }
.pf-entrega summary::after { content: '+'; margin-left: auto; font-weight: 800; color: var(--c-slate-400); }
.pf-entrega[open] summary::after { content: '−'; }
</style>
