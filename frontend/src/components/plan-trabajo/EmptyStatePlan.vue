<template>
  <div class="esp">
    <div class="esp__icon">📋</div>
    <h2 class="esp__title">No hay plan para este período</h2>
    <p class="esp__sub">Creá un plan de trabajo para organizar las tareas del equipo semana a semana.</p>
    <div class="esp__actions">
      <button class="esp__btn esp__btn--primary" @click="$emit('nuevo')">
        <i class="bi bi-plus-lg"></i> Nuevo plan
      </button>
    </div>
    <div v-if="planesAnteriores.length" class="esp__anteriores">
      <p class="esp__ant-title">Planes anteriores</p>
      <div class="esp__ant-list">
        <div v-for="p in planesAnteriores" :key="p.id" class="esp__ant-item" @click="$emit('ver', p)">
          <div class="esp__ant-info">
            <span class="esp__ant-nombre">{{ p.titulo }}</span>
            <span class="esp__ant-meta">{{ p.fecha_inicio }} · {{ p.total_plan_tareas }} tareas · {{ p.porcentaje_completado }}% completado</span>
          </div>
          <span class="esp__ant-badge" :class="`esp__ant-badge--${p.estado}`">{{ estadoLabel(p.estado) }}</span>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
defineProps({ planesAnteriores: { type: Array, default: () => [] } })
defineEmits(['nuevo', 'ver'])
function estadoLabel(e) { return { borrador: 'Borrador', publicado: 'Publicado', archivado: 'Archivado' }[e] || e }
</script>

<style scoped>
.esp { display: flex; flex-direction: column; align-items: center; gap: 1rem; padding: 4rem 1.5rem; text-align: center; }
.esp__icon  { font-size: 3rem; line-height: 1; }
.esp__title { font-size: 1.25rem; font-weight: 700; color: #0f2611; margin: 0; }
.esp__sub   { font-size: .875rem; color: #60725d; margin: 0; max-width: 440px; line-height: 1.6; }
.esp__actions { display: flex; gap: .75rem; flex-wrap: wrap; justify-content: center; }
.esp__btn { display: inline-flex; align-items: center; gap: .4rem; padding: .65rem 1.25rem; border-radius: 9px; font-size: .875rem; font-weight: 600; cursor: pointer; border: none; transition: all .15s; }
.esp__btn--primary { background: #1b5e20; color: #fff; }
.esp__btn--primary:hover { background: #144a18; }
.esp__anteriores { width: 100%; max-width: 600px; margin-top: 1rem; }
.esp__ant-title  { font-size: .75rem; font-weight: 700; color: #60725d; text-transform: uppercase; letter-spacing: .05em; margin: 0 0 .75rem; text-align: left; }
.esp__ant-list   { display: flex; flex-direction: column; gap: .4rem; }
.esp__ant-item   { display: flex; align-items: center; justify-content: space-between; gap: 1rem; background: #fff; border: 1px solid #e8f0e9; border-radius: 10px; padding: .75rem 1rem; cursor: pointer; transition: border-color .15s; text-align: left; }
.esp__ant-item:hover { border-color: #c8e6c9; }
.esp__ant-info   { display: flex; flex-direction: column; gap: 2px; min-width: 0; }
.esp__ant-nombre { font-weight: 600; color: #0f2611; font-size: .875rem; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.esp__ant-meta   { font-size: .75rem; color: #60725d; }
.esp__ant-badge  { font-size: .68rem; font-weight: 700; padding: .2em .6em; border-radius: 5px; flex-shrink: 0; }
.esp__ant-badge--publicado { background: #f0fdf4; color: #15803d; }
.esp__ant-badge--borrador  { background: var(--c-slate-50); color: var(--c-slate-500); }
.esp__ant-badge--archivado { background: var(--c-slate-100); color: var(--c-slate-400); }
</style>
