<template>
  <Teleport to="body">
    <div class="cmb__overlay" v-modal="{ cerrar: () => $emit('close'), sucio }">
      <div class="cmb__panel" role="dialog" aria-modal="true" :aria-label="titulo">
        <header class="cmb__header">
          <div class="cmb__icon"><i :class="['bi', icono]"></i></div>
          <div class="cmb__titles">
            <h2 class="cmb__title">{{ titulo }}</h2>
            <p v-if="sub" class="cmb__sub">{{ sub }}</p>
          </div>
          <button type="button" class="cmb__close" aria-label="Cerrar" @click="$emit('close')"><i class="bi bi-x-lg"></i></button>
        </header>
        <div class="cmb__body">
          <div v-if="error" class="cmb__alert" role="alert"><i class="bi bi-exclamation-triangle-fill"></i> {{ error }}</div>
          <slot />
        </div>
        <footer class="cmb__footer">
          <button type="button" class="cmb__btn cmb__btn--ghost" :disabled="guardando" @click="$emit('close')">Cancelar</button>
          <button type="button" class="cmb__btn cmb__btn--primary" :disabled="guardando || deshabilitado" @click="$emit('guardar')">
            <span v-if="guardando" class="spinner-border spinner-border-sm" aria-hidden="true"></span>
            {{ guardando ? 'Guardando…' : textoGuardar }}
          </button>
        </footer>
      </div>
    </div>
  </Teleport>
</template>

<script setup>
// El envoltorio común de los modales de cama. En el teléfono sube como hoja desde abajo (es donde
// se usan todos los días); en escritorio, centrado. No se cierra tocando afuera: sólo con la X,
// Cancelar o ESC (`v-modal`, que además pregunta si había algo escrito).
defineProps({
  titulo:        { type: String, required: true },
  sub:           { type: String, default: null },
  icono:         { type: String, default: 'bi-grid' },
  error:         { type: String, default: null },
  guardando:     { type: Boolean, default: false },
  deshabilitado: { type: Boolean, default: false },
  textoGuardar:  { type: String, default: 'Guardar' },
  sucio:         { type: Function, default: null },
})
defineEmits(['close', 'guardar'])
</script>

<style scoped>
.cmb__overlay {
  position: fixed; inset: 0; background: rgba(15, 23, 42, .45); backdrop-filter: blur(3px);
  display: flex; align-items: center; justify-content: center; z-index: 1060; padding: 1rem;
}
.cmb__panel {
  background: var(--c-paper); border-radius: var(--r-xl); width: 100%; max-width: 560px;
  max-height: 92vh; display: flex; flex-direction: column; box-shadow: var(--sh-3); overflow: hidden;
}
.cmb__header { display: flex; align-items: center; gap: .8rem; padding: 1rem 1.2rem; border-bottom: 1px solid var(--c-slate-100); }
.cmb__icon {
  width: 38px; height: 38px; border-radius: var(--r-md); background: var(--c-leaf-50); color: var(--c-leaf-800);
  display: flex; align-items: center; justify-content: center; flex-shrink: 0; font-size: 1.05rem;
}
.cmb__titles { min-width: 0; }
.cmb__title { font-size: var(--fs-16); font-weight: 800; color: var(--c-slate-900); margin: 0; }
.cmb__sub { font-size: var(--fs-13); color: var(--c-slate-500); margin: .1rem 0 0; }
.cmb__close {
  margin-left: auto; background: var(--c-slate-100); border: none; width: 32px; height: 32px; border-radius: var(--r-md);
  color: var(--c-slate-600); cursor: pointer; flex-shrink: 0;
}
.cmb__body { padding: 1rem 1.2rem; display: flex; flex-direction: column; gap: .9rem; overflow-y: auto; }
.cmb__alert {
  background: var(--c-rust-100); color: var(--c-rust-600); border-radius: var(--r-md);
  padding: .6rem .8rem; font-size: var(--fs-13); display: flex; gap: .5rem; align-items: flex-start;
}
.cmb__footer { display: flex; justify-content: flex-end; gap: .6rem; padding: .85rem 1.2rem; border-top: 1px solid var(--c-slate-100); }
.cmb__btn { border-radius: var(--r-md); padding: .6rem 1.1rem; font-size: var(--fs-14); font-weight: 700; cursor: pointer; display: inline-flex; align-items: center; gap: .4rem; }
.cmb__btn--ghost { background: transparent; border: 1.5px solid var(--c-slate-200); color: var(--c-slate-600); }
.cmb__btn--primary { background: var(--c-leaf-700); border: none; color: var(--c-paper); }
.cmb__btn--primary:disabled { opacity: .55; cursor: not-allowed; }

/* Lo que va adentro de cada modal (el contenido es del slot: `:slotted`). */
:slotted(.cm-grid) { display: grid; grid-template-columns: 1fr 1fr; gap: .75rem; }
:slotted(.cm-grid--3) { grid-template-columns: 1fr 1fr 1fr; }
:slotted(.cm-field) { display: flex; flex-direction: column; gap: .3rem; min-width: 0; }
:slotted(.cm-field--full) { grid-column: 1 / -1; }
:slotted(.cm-label) { font-size: var(--fs-12); font-weight: 700; color: var(--c-slate-700); text-transform: uppercase; letter-spacing: .04em; }
:slotted(.cm-opt) { font-weight: 500; text-transform: none; letter-spacing: 0; color: var(--c-slate-400); }
:slotted(.cm-input) {
  background: var(--c-slate-50); border: 1.5px solid var(--c-slate-200); border-radius: var(--r-md);
  padding: .6rem .8rem; font-size: var(--fs-14); color: var(--c-slate-900); width: 100%; box-sizing: border-box;
}
:slotted(.cm-input:focus) { outline: none; border-color: var(--c-leaf-700); background: var(--c-paper); }
:slotted(.cm-hint) { font-size: var(--fs-12); color: var(--c-slate-500); }
:slotted(.cm-aviso) {
  background: var(--c-amber-100); color: var(--c-slate-900); border-radius: var(--r-md);
  padding: .6rem .8rem; font-size: var(--fs-13); display: flex; gap: .5rem; align-items: flex-start;
}
:slotted(.cm-info) {
  background: var(--c-leaf-50); color: var(--c-leaf-900); border-radius: var(--r-md);
  padding: .6rem .8rem; font-size: var(--fs-13); display: flex; gap: .5rem; align-items: flex-start;
}
:slotted(.cm-chips) { display: flex; flex-wrap: wrap; gap: .4rem; }
:slotted(.cm-chip) {
  padding: .45rem .8rem; border: 1.5px solid var(--c-slate-200); border-radius: var(--r-md);
  background: var(--c-slate-50); font-size: var(--fs-13); font-weight: 600; color: var(--c-slate-600); cursor: pointer;
}
:slotted(.cm-chip--on) { border-color: var(--c-leaf-700); background: var(--c-leaf-50); color: var(--c-leaf-800); }
:slotted(.cm-check) { display: flex; gap: .5rem; align-items: center; font-size: var(--fs-14); color: var(--c-slate-700); }
:slotted(.cm-seccion) { font-size: var(--fs-13); font-weight: 800; color: var(--c-slate-700); margin: .25rem 0 0; }

@media (max-width: 600px) {
  :slotted(.cm-grid), :slotted(.cm-grid--3) { grid-template-columns: 1fr 1fr; }
  .cmb__overlay { align-items: flex-end; padding: 0; }
  .cmb__panel { max-width: none; border-radius: var(--r-xl) var(--r-xl) 0 0; max-height: 94vh; }
  .cmb__footer { padding-bottom: calc(.85rem + env(safe-area-inset-bottom)); }
  .cmb__btn { flex: 1; justify-content: center; }
}
</style>
