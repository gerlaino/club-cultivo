<template>
  <div class="ab">
    <i class="bi bi-shield-lock-fill ab__icon"></i>
    <span>Vista de auditoría — solo lectura</span>
  </div>
</template>

<style scoped>
.ab {
  display: flex;
  align-items: center;
  gap: .5rem;
  background: var(--c-amber-50, #fffbeb);
  border-bottom: 1px solid var(--c-amber-200, #fde68a);
  color: var(--c-amber-700, #b45309);
  font-size: .75rem;
  font-weight: 700;
  padding: .4rem 1.25rem;
  text-transform: uppercase;
  letter-spacing: .05em;
  user-select: none;
}
.ab__icon { font-size: .8rem; opacity: .85; }
</style>
