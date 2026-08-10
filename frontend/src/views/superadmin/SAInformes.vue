<script setup>
// Informes de plataforma.
//
// Acá aterrizan los agregados que antes ocupaban el panel: cuántas plantas, cuántos lotes,
// cuántos pacientes sumando todos los clubes. Para abrir a la mañana no servían —no es el
// cultivo de uno—, pero como informe sí: dicen qué tamaño tiene la plataforma.
//
// Sigue el criterio de los informes del club: cada uno arranca diciendo QUÉ PREGUNTA contesta.
// Sin eso, dos informes que cortan el mismo dato distinto parecen contradecirse.
import { ref, computed, onMounted } from 'vue'
import DsSpinner from '../../design-system/components/Spinner.vue'
import { getInformePlataforma } from '../../lib/api.js'

const informe  = ref(null)
const cargando = ref(true)
const error    = ref(null)

const clubes   = computed(() => informe.value?.clubes || {})
const volumen  = computed(() => informe.value?.volumen || {})
const promedio = computed(() => informe.value?.promedio_por_club || {})
const dispensa = computed(() => informe.value?.dispensacion_mes || {})

const VOLUMEN_LABEL = {
  usuarios: 'Usuarios', pacientes: 'Pacientes', sedes: 'Sedes',
  salas: 'Salas', lotes: 'Lotes', plantas: 'Plantas',
}

function fecha(f) {
  if (!f) return '—'
  return new Date(f + 'T00:00:00').toLocaleDateString('es-AR', { day: '2-digit', month: 'long' })
}

onMounted(async () => {
  try {
    const { data } = await getInformePlataforma()
    informe.value = data
  } catch {
    error.value = 'No se pudo cargar el informe.'
  } finally {
    cargando.value = false
  }
})
</script>

<template>
  <div class="sai">
    <h1 class="sai__title">Informes</h1>

    <div v-if="cargando" class="sai__cargando"><DsSpinner :size="22" /><span>Cargando…</span></div>
    <div v-else-if="error" class="sai__error">{{ error }}</div>

    <template v-else-if="informe">
      <section class="sai__card">
        <div class="sai__card-head">
          <h2 class="sai__card-title">Tamaño de la plataforma</h2>
          <p class="sai__resena">{{ informe.reseña }}</p>
        </div>

        <div class="sai__bloque">
          <div class="sai__bloque-title">Clubes</div>
          <div class="sai__grid">
            <div class="sai__dato"><span class="sai__n">{{ clubes.operando }}</span><span class="sai__l">operando</span></div>
            <div class="sai__dato"><span class="sai__n">{{ clubes.suspendidos }}</span><span class="sai__l">suspendidos</span></div>
            <div class="sai__dato"><span class="sai__n">{{ clubes.eliminados }}</span><span class="sai__l">eliminados</span></div>
            <div class="sai__dato"><span class="sai__n">{{ clubes.demo }}</span><span class="sai__l">demo (no cuentan)</span></div>
          </div>
        </div>

        <div class="sai__bloque">
          <div class="sai__bloque-title">Volumen</div>
          <div class="sai__grid">
            <div v-for="(n, k) in volumen" :key="k" class="sai__dato">
              <span class="sai__n">{{ n }}</span>
              <span class="sai__l">{{ VOLUMEN_LABEL[k] || k }}</span>
            </div>
          </div>
        </div>

        <div class="sai__bloque">
          <div class="sai__bloque-title">Club promedio</div>
          <p class="sai__nota">El promedio dice más que el total: así es un club mediano de la plataforma.</p>
          <div class="sai__grid">
            <div class="sai__dato"><span class="sai__n">{{ promedio.pacientes }}</span><span class="sai__l">pacientes</span></div>
            <div class="sai__dato"><span class="sai__n">{{ promedio.lotes }}</span><span class="sai__l">lotes</span></div>
            <div class="sai__dato"><span class="sai__n">{{ promedio.usuarios }}</span><span class="sai__l">usuarios</span></div>
          </div>
        </div>

        <div class="sai__bloque">
          <div class="sai__bloque-title">Dispensación del mes</div>
          <p class="sai__nota">Desde el {{ fecha(dispensa.desde) }}, sin las canceladas.</p>
          <div class="sai__grid">
            <div class="sai__dato"><span class="sai__n">{{ dispensa.cantidad }}</span><span class="sai__l">entregas</span></div>
            <div class="sai__dato"><span class="sai__n">{{ Math.round(dispensa.gramos || 0) }}</span><span class="sai__l">gramos</span></div>
          </div>
        </div>
      </section>
    </template>
  </div>
</template>

<style scoped>
.sai { padding: 1.75rem 2rem 3rem; max-width: 1000px; }
.sai__title { font-size: 1.6rem; font-weight: 800; color: var(--c-slate-900); margin: 0 0 1.5rem; letter-spacing: -.03em; }

.sai__cargando { display: flex; align-items: center; justify-content: center; gap: .75rem; padding: 4rem 0; color: var(--c-slate-500); font-size: .85rem; }
.sai__error { padding: 1rem; border-radius: 10px; background: #fef2f2; color: #b91c1c; font-size: .85rem; }

.sai__card { background: #fff; border: 1px solid var(--c-slate-200); border-radius: 14px; overflow: hidden; }
.sai__card-head { padding: 1.125rem 1.25rem; border-bottom: 1px solid var(--c-slate-100); background: var(--c-slate-50); }
.sai__card-title { font-size: 1rem; font-weight: 800; color: var(--c-slate-900); margin: 0 0 .3rem; }
/* Qué pregunta contesta: sin esto, dos informes que cortan el mismo dato distinto parecen
   contradecirse. */
.sai__resena { font-size: .78rem; color: var(--c-slate-500); line-height: 1.5; margin: 0; }

.sai__bloque { padding: 1.125rem 1.25rem; border-bottom: 1px solid var(--c-slate-100); }
.sai__bloque:last-child { border-bottom: none; }
.sai__bloque-title { font-size: .72rem; font-weight: 800; text-transform: uppercase; letter-spacing: .07em; color: var(--c-slate-500); margin-bottom: .75rem; }
.sai__nota { font-size: .74rem; color: var(--c-slate-400); margin: -.4rem 0 .75rem; }

.sai__grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(130px, 1fr)); gap: .5rem; }
.sai__dato { display: grid; gap: .15rem; padding: .75rem .85rem; border: 1px solid var(--c-slate-100); border-radius: 10px; }
.sai__n { font-size: 1.4rem; font-weight: 800; color: var(--c-slate-900); line-height: 1; }
.sai__l { font-size: .68rem; color: var(--c-slate-500); }
</style>
