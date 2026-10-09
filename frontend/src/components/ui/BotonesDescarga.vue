<script setup>
// Las descargas de un listado: PDF (para leer o presentar) y Excel (para trabajar los números),
// los dos con el membrete de la organización (9-oct-2026: «ningún archivo descargado puede ser
// así», al abrir un CSV). El archivo lo arma el backend (`DescargaProfesional`); esto sólo pide.
defineProps({
  disabled:  { type: Boolean, default: false },
  generando: { type: String, default: null }, // 'pdf' | 'xlsx' mientras se arma
})
defineEmits(['descargar'])
</script>

<template>
  <div class="bdes" role="group" aria-label="Descargar">
    <button type="button" class="bdes__btn" :disabled="disabled || !!generando" @click="$emit('descargar', 'pdf')">
      <i class="bi bi-filetype-pdf" aria-hidden="true"></i>{{ generando === 'pdf' ? 'Generando…' : 'PDF' }}
    </button>
    <button type="button" class="bdes__btn" :disabled="disabled || !!generando" @click="$emit('descargar', 'xlsx')">
      <i class="bi bi-file-earmark-spreadsheet" aria-hidden="true"></i>{{ generando === 'xlsx' ? 'Generando…' : 'Excel' }}
    </button>
  </div>
</template>

<style scoped>
.bdes { display: inline-flex; gap: .4rem; flex-wrap: wrap; }
.bdes__btn {
  display: inline-flex; align-items: center; gap: .35rem;
  background: var(--c-paper, #fff); border: 1.5px solid var(--c-ink-300); border-radius: var(--r-md);
  padding: 6px 12px; font-size: var(--fs-14); font-weight: 600; color: var(--c-leaf-700); cursor: pointer;
}
.bdes__btn:hover:not(:disabled) { background: var(--c-leaf-50, var(--c-slate-50)); }
.bdes__btn:disabled { opacity: .5; cursor: not-allowed; }
</style>
