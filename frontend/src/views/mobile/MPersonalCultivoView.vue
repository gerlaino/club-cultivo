<template>
  <!-- Despacho: el cultivador de casa tiene UNA sede (su casa, sembrada con el alta) y no la
       elige. La solapa "Cultivo" entra directo a sus salas —la pantalla de la sede, que ya lista
       salas, deja crear la primera y abre cada una—, sin pasar por una lista de una sola tarjeta.
       Sin sede (no debería pasar: la siembra el alta) se explica en vez de quedar en blanco. -->
  <div class="mpc">
    <div v-if="cargando" class="mpc__loading"><i class="bi bi-arrow-repeat mpc__spin"></i> Cargando…</div>
    <div v-else class="mpc__empty">
      <i class="bi bi-house"></i>
      <p class="mpc__empty-title">Tu cultivo no tiene dónde vivir todavía</p>
      <p class="mpc__empty-hint">Falta la sede de tu casa. Escribinos y la creamos.</p>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { listSedes } from '../../lib/api'

const router   = useRouter()
const cargando = ref(true)

onMounted(async () => {
  try {
    const { data } = await listSedes()
    const sede = (data || [])[0]
    if (sede) { router.replace(`/m/sede/${sede.id}`); return }
  } catch { /* sin red: se muestra el vacío */ }
  cargando.value = false
})
</script>

<style scoped>
.mpc { padding: 1rem; }
.mpc__loading { display: flex; align-items: center; gap: .5rem; justify-content: center; padding: 2.5rem; color: var(--c-slate-400); font-size: .875rem; }
.mpc__spin { animation: mpc-spin .8s linear infinite; }
@keyframes mpc-spin { to { transform: rotate(360deg); } }
.mpc__empty { display: flex; flex-direction: column; align-items: center; gap: .4rem; padding: 3rem 1rem; text-align: center; color: var(--c-slate-500); }
.mpc__empty i { font-size: 2.2rem; color: var(--c-leaf-500, #5A8A72); }
.mpc__empty-title { margin: .4rem 0 0; font-size: .95rem; font-weight: 700; color: var(--c-slate-900); }
.mpc__empty-hint { margin: 0; font-size: .82rem; }
</style>
