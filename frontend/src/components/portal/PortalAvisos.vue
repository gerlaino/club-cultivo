<template>
  <div v-if="avisos.length" class="pav pav--urgente">
    <div class="pav__inner">
      <span class="pav__punto" aria-hidden="true"></span>
      <p class="pav__txt">
        <span v-for="(a, i) in avisos" :key="a.tipo">
          <template v-if="i > 0"> · </template>{{ a.texto }}
        </span>
      </p>
      <RouterLink to="/portal" class="pav__bt">Mi credencial</RouterLink>
    </div>
  </div>
</template>

<script setup>
// La franja de arriba: SÓLO lo que impide retirar. Hoy eso es una cosa sola, el REPROCANN vencido.
//
// Antes mostraba también lo de nivel `atencion` —vence en 20 días, debés $8.000— y eso pasó a la
// credencial y a las fichas del inicio, que están tres centímetros más abajo y dicen lo mismo con
// la fecha y el monto. Repetirlo acá arriba lo convertía en decoración: una franja que aparece casi
// siempre se deja de leer a la semana, y el día que dice "no podés retirar" ya nadie la mira.
//
// El backend sigue mandando los dos niveles porque los usa el inicio; el filtro es de acá.
import { ref, computed, onMounted } from 'vue'
import { RouterLink } from 'vue-router'
import { getPortalMiEstado } from '@/lib/portalApi'

const todos = ref([])

const avisos = computed(() => todos.value.filter(a => a.nivel === 'urgente'))

onMounted(async () => {
  try {
    todos.value = (await getPortalMiEstado())?.avisos || []
  } catch { /* la franja es un extra: si falla, el portal se usa igual */ }
})
</script>

<style scoped>
.pav { border-bottom: 1px solid transparent; }
.pav--urgente  { background: var(--p-urgente-bg);  border-bottom-color: color-mix(in srgb, var(--p-urgente) 30%, transparent); }

.pav__inner {
  max-width: var(--p-ancho);
  margin: 0 auto;
  display: flex;
  align-items: center;
  gap: var(--sp-2);
  padding: var(--sp-2) var(--sp-4);
}

.pav__punto { width: 7px; height: 7px; border-radius: var(--r-pill); flex: 0 0 auto; }
.pav--urgente  .pav__punto { background: var(--p-urgente); }

.pav__txt { margin: 0; font-size: var(--fs-13); line-height: var(--lh-base); }
.pav--urgente  .pav__txt { color: color-mix(in srgb, var(--p-urgente) 75%, #000 25%); }

.pav__bt {
  margin-left: auto;
  flex: 0 0 auto;
  font-size: var(--fs-12);
  font-weight: 600;
  text-decoration: none;
  color: var(--p-marca-fuerte);
  border: 1px solid currentColor;
  border-radius: var(--r-pill);
  padding: 2px var(--sp-3);
  white-space: nowrap;
}
.pav__bt:hover { background: rgb(255 255 255 / .55); }

@media (max-width: 520px) {
  .pav__inner { flex-wrap: wrap; }
  .pav__bt { margin-left: calc(7px + var(--sp-2)); }
}
</style>
