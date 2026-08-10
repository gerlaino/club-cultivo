<script setup>
// Una fila del catálogo de categorías (madre o subcategoría).
//
// Existía cuatro veces copiada en FinanzasCatalogoView (madre, sub, y las dos otra vez en el
// bucket "Sin sector"), y por eso las acciones divergían entre una y otra.
//
// Dos decisiones de lectura:
//   · Las acciones viven en un menú "⋯" y no como cuatro links de texto por fila. Con veinte
//     filas, "Editar Desactivar Editar Desactivar…" ocupaba media pantalla y competía con lo
//     único que importa, que es el nombre.
//   · Se marca lo PROPIO, no lo del sistema. Casi todo el catálogo es del sistema: ponerle un
//     badge a cada fila es ruido en veinte filas para no decir nada. Lo que la organización creó es la
//     excepción y es lo que conviene poder encontrar de un vistazo.
import { ref } from 'vue'
import DsDropdown from '../../design-system/components/Dropdown.vue'

defineProps({
  cat:  { type: Object, required: true },
  sub:  { type: Boolean, default: false },   // es subcategoría (se indenta)
})
const emit = defineEmits(['nueva-sub', 'editar', 'toggle-activa', 'borrar'])

const abierto = ref(false)
function accion(evento) {
  abierto.value = false
  emit(evento)
}
</script>

<template>
  <div class="cf" :class="{ 'cf--sub': sub, 'cf--off': !cat.activa }">
    <span class="cf__nombre">{{ cat.nombre }}</span>
    <span v-if="!cat.activa" class="cf__chip cf__chip--off">oculta</span>
    <span v-if="!cat.es_sistema" class="cf__chip cf__chip--propia">propia</span>

    <DsDropdown v-model="abierto" align="right">
      <template #anchor>
        <button class="cf__mas" :aria-label="`Acciones de ${cat.nombre}`" @click="abierto = !abierto">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
            <circle cx="5" cy="12" r="1.7" /><circle cx="12" cy="12" r="1.7" /><circle cx="19" cy="12" r="1.7" />
          </svg>
        </button>
      </template>
      <template #panel>
        <nav class="cf__menu">
          <button v-if="!sub" class="cf__menu-item" @click="accion('nueva-sub')">Agregar subcategoría</button>
          <button class="cf__menu-item" @click="accion('editar')">Editar</button>
          <button class="cf__menu-item" @click="accion('toggle-activa')">
            {{ cat.activa ? 'Desactivar' : 'Reactivar' }}
          </button>
          <!-- Las del sistema no se borran: se desactivan. Por eso el ítem NO aparece, en vez
               de aparecer y fallar cuando lo tocás. -->
          <template v-if="!cat.es_sistema">
            <div class="cf__menu-sep"></div>
            <button class="cf__menu-item cf__menu-item--danger" @click="accion('borrar')">Eliminar</button>
          </template>
        </nav>
      </template>
    </DsDropdown>
  </div>
</template>

<style scoped>
.cf {
  display: flex; align-items: center; gap: .5rem;
  min-height: 34px; padding: .1rem .25rem .1rem .5rem;
  border-radius: 7px;
}
.cf:hover { background: var(--c-slate-50); }
.cf--sub { padding-left: 1.5rem; }
.cf--sub .cf__nombre { font-weight: 400; color: var(--c-slate-600); font-size: .84rem; }
.cf--off { opacity: .55; }

.cf__nombre {
  flex: 1; min-width: 0;
  font-size: .875rem; font-weight: 600; color: var(--c-ink-800, #1e293b);
  overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
}
.cf__chip {
  flex-shrink: 0; font-size: .62rem; font-weight: 700; letter-spacing: .04em;
  text-transform: uppercase; padding: .12em .45em; border-radius: 999px;
}
.cf__chip--propia { color: #1e40af; background: #dbeafe; }
.cf__chip--off    { color: #92400e; background: #fef3c7; }

/* El "⋯" sólo aparece al pasar por encima (o al enfocarlo con teclado): la fila en reposo
   muestra el nombre y nada más. En touch no hay hover, así que ahí queda siempre visible. */
.cf__mas {
  flex-shrink: 0; width: 28px; height: 28px; display: flex; align-items: center; justify-content: center;
  background: none; border: none; border-radius: 6px; cursor: pointer;
  color: var(--c-slate-400); opacity: 0; transition: opacity .12s, background .12s;
}
.cf:hover .cf__mas, .cf__mas:focus-visible { opacity: 1; }
.cf__mas:hover { background: var(--c-slate-100); color: var(--c-slate-700); }
@media (hover: none) { .cf__mas { opacity: 1; } }

.cf__menu { display: flex; flex-direction: column; padding: .25rem 0; min-width: 190px; }
.cf__menu-item {
  display: block; width: 100%; text-align: left;
  padding: .45rem .85rem; background: none; border: none; cursor: pointer;
  font-size: .84rem; color: var(--c-slate-700);
}
.cf__menu-item:hover { background: var(--c-leaf-50, #f4f8f5); color: var(--c-slate-900); }
.cf__menu-item--danger { color: #dc2626; }
.cf__menu-item--danger:hover { background: #fee2e2; color: #b91c1c; }
.cf__menu-sep { height: 1px; margin: .25rem 0; background: var(--c-slate-100); }
</style>
