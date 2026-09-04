<template>
  <div class="cmm__back" @click.self="$emit('cerrar')">
    <div class="cmm__modal" role="dialog" aria-modal="true" aria-label="Confirmar los cambios de la mesa">
      <header class="cmm__hd">
        <h3 class="cmm__title">Confirmá los cambios de la mesa</h3>
        <p class="cmm__sub">
          Lo que subís queda apartado para dispensar. No se descuenta del inventario: sale recién
          cuando se entrega a un paciente.
        </p>
      </header>

      <!-- De un vistazo: cuánto se mueve y con cuánto queda la mesa. Es la pregunta del admin que
           administra a distancia y no tiene el frasco delante. -->
      <div class="cmm__resumen">
        <div v-if="suben.length" class="cmm__stat cmm__stat--sube">
          <span class="cmm__stat-num">{{ suben.length }}</span>
          <span class="cmm__stat-lbl">sube{{ suben.length === 1 ? '' : 'n' }}</span>
        </div>
        <div v-if="bajan.length" class="cmm__stat cmm__stat--baja">
          <span class="cmm__stat-num">{{ bajan.length }}</span>
          <span class="cmm__stat-lbl">baja{{ bajan.length === 1 ? '' : 'n' }}</span>
        </div>
        <div v-if="valorDespues != null" class="cmm__stat cmm__stat--valor">
          <span class="cmm__stat-num">${{ fmt(valorDespues) }}</span>
          <span class="cmm__stat-lbl">queda sobre la mesa</span>
        </div>
      </div>

      <ul class="cmm__lista">
        <li v-for="c in ordenados" :key="c.stock_id" class="cmm__row" :class="c.sube ? 'is-sube' : 'is-baja'">
          <span class="cmm__flecha" aria-hidden="true">{{ c.sube ? '▲' : '▼' }}</span>
          <div class="cmm__prod">
            <span class="cmm__nombre">
              {{ formaLabel(c.forma) }}
              <span v-if="c.ahora === 0" class="cmm__chip-sale">sale de la mesa</span>
            </span>
            <span class="cmm__meta">{{ [c.genetica, c.numero].filter(Boolean).join(' · ') || '—' }}</span>
          </div>
          <div class="cmm__nums">
            <span class="cmm__antes">{{ fmt(c.antes) }}</span>
            <span class="cmm__hasta" aria-hidden="true">→</span>
            <span class="cmm__ahora">{{ fmt(c.ahora) }} {{ c.unidad }}</span>
          </div>
          <span class="cmm__delta">{{ c.sube ? '+' : '−' }}{{ fmt(Math.abs(c.ahora - c.antes)) }} {{ c.unidad }}</span>
        </li>
      </ul>

      <!-- El motivo va ACÁ y no antes de abrir: recién con los renglones a la vista se sabe qué
           escribir. Es obligatorio — "hay 300 g" sin por qué es un número que apareció. -->
      <div class="cmm__campo">
        <span class="cmm__campo-lbl">Por qué se cambia</span>
        <div class="cmm__sugeridos">
          <button v-for="s in sugeridos" :key="s" type="button" class="cmm__chip"
                  :class="{ 'is-on': motivo === s }" @click="elegir(s)">{{ s }}</button>
        </div>
        <input ref="campoMotivo" v-model="motivo" type="text" class="cmm__input"
               placeholder="O escribilo con tus palabras" aria-label="Por qué se cambia la mesa"
               @keyup.enter="puedeGuardar && $emit('confirmar', { motivo: motivo.trim() })" />
      </div>

      <p class="cmm__nota">
        Queda anotado con tu nombre y la hora. Si hay alguien atendiendo, lo ve en el acto y sin
        recargar: así no cierra con un faltante que no es suyo.
      </p>

      <div class="cmm__acc">
        <button class="cmm__btn cmm__btn--ghost" @click="$emit('cerrar')">Cancelar</button>
        <button class="cmm__btn cmm__btn--primary" :disabled="!puedeGuardar"
                @click="$emit('confirmar', { motivo: motivo.trim() })">
          {{ guardando ? 'Guardando…' : 'Guardar cambios' }}
        </button>
      </div>
    </div>
  </div>
</template>

<script setup>
// CONFIRMAR LO QUE CAMBIA SOBRE LA MESA.
//
// La tabla tiene buscador y orden, así que lo que se tocó puede no estar todo en pantalla al
// momento de guardar: acá se ve la lista completa de lo que se mueve, con el antes y el después
// de cada producto, y recién entonces se escribe el motivo.
//
// El motivo vivía en una barra angosta ARRIBA del botón: se escribía a ciegas, antes de ver qué
// se estaba cambiando, y por eso terminaba diciendo "carga" en todos los renglones — que es lo
// mismo que no decir nada, y el historial de la mesa es justamente lo que se quería guardar.
//
// LO QUE SUBE SE APARTA, NO SE DESCUENTA: la fila de Stock sigue siendo una sola con su ST-xx.
// Lo trazable sale del inventario por dispensación y nunca por cambiar de mesa.
import { ref, computed, onMounted } from 'vue'
import { formaLabel } from '../../lib/formatters.js'

const props = defineProps({
  // Lo que cambia: { stock_id, forma, genetica, numero, unidad, antes, ahora }
  cambios:   { type: Array,  default: () => [] },
  // Con cuánta plata queda la mesa después del cambio. Sólo lo ve administración, que es quien
  // abre este modal.
  valorDespues: { type: Number, default: null },
  guardando: { type: Boolean, default: false },
})
defineEmits(['cerrar', 'confirmar'])

const motivo      = ref('')
const campoMotivo = ref(null)

const fmt = (n) => Number(n ?? 0).toLocaleString('es-AR', { maximumFractionDigits: 1 })

const conSentido = computed(() =>
  props.cambios.map(c => ({ ...c, sube: Number(c.ahora) > Number(c.antes) }))
)
const suben = computed(() => conSentido.value.filter(c => c.sube))
const bajan = computed(() => conSentido.value.filter(c => !c.sube))
// Lo que sube primero: es lo que se está por poner enfrente del paciente.
const ordenados = computed(() => [...suben.value, ...bajan.value])

// Los motivos de siempre, a un click. Sin esto se escribe la palabra más corta que cierre el
// modal. Cambian según lo que se esté haciendo: ofrecer "cierre de la jornada" cuando se está
// reponiendo es ruido.
const sugeridos = computed(() => {
  if (!bajan.value.length) return ['Reposición del turno', 'Carga de apertura', 'Se pidió del depósito']
  if (!suben.value.length) return ['Vuelve al depósito', 'Cierre de la jornada', 'Se lleva a otra sede']
  return ['Reposición del turno', 'Corrección de carga', 'Recambio de producto']
})

const puedeGuardar = computed(() => !props.guardando && motivo.value.trim().length > 0)

function elegir (s) {
  motivo.value = motivo.value === s ? '' : s
}

// El motivo es el único campo: que el cursor ya esté ahí ahorra el click que separa mirar de
// confirmar.
onMounted(() => campoMotivo.value?.focus())
</script>

<style scoped>
.cmm__back {
  position: fixed; inset: 0; background: rgba(15, 42, 30, .45);
  display: flex; align-items: center; justify-content: center; padding: 20px; z-index: 1000;
}
.cmm__modal {
  background: #fff; border-radius: 14px; padding: 24px;
  width: 100%; max-width: 560px; max-height: 88vh; overflow-y: auto;
  display: flex; flex-direction: column; gap: 16px;
}
.cmm__hd { display: flex; flex-direction: column; gap: 4px; }
.cmm__title {
  font-family: var(--font-display); font-size: var(--fs-18); font-weight: 700;
  color: var(--c-leaf-900); margin: 0;
}
.cmm__sub { margin: 0; font-size: var(--fs-13); color: var(--c-ink-500); }

/* ── Resumen de un vistazo ──────────────────────────────────────────────────── */
.cmm__resumen { display: flex; gap: 10px; flex-wrap: wrap; }
.cmm__stat {
  flex: 1; min-width: 120px;
  display: flex; flex-direction: column; gap: 2px;
  padding: 11px 14px; border-radius: 11px; background: var(--c-slate-50);
}
.cmm__stat-num { font-family: var(--font-mono); font-size: var(--fs-18); font-weight: 700; color: var(--c-ink-900); }
.cmm__stat-lbl { font-size: var(--fs-12); color: var(--c-ink-500); }
.cmm__stat--sube  { background: var(--c-leaf-100); }
.cmm__stat--sube  .cmm__stat-num { color: var(--c-leaf-800); }
/* Ámbar y no rojo: bajar producto de la mesa es una decisión normal, no un problema. */
.cmm__stat--baja  { background: var(--c-amber-100); }
.cmm__stat--baja  .cmm__stat-num { color: var(--c-amber-500); }
.cmm__stat--valor { background: var(--c-leaf-50); }

/* ── Los renglones que se mueven ────────────────────────────────────────────── */
.cmm__lista { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; }
.cmm__row {
  display: flex; align-items: center; gap: 12px;
  padding: 11px 0; border-top: 1px solid var(--c-slate-100);
}
.cmm__row:first-child { border-top: 0; }
.cmm__flecha { font-size: var(--fs-12); width: 14px; text-align: center; }
.cmm__row.is-sube .cmm__flecha  { color: var(--c-leaf-600); }
.cmm__row.is-baja .cmm__flecha  { color: var(--c-amber-500); }

.cmm__prod   { flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 2px; }
.cmm__nombre { font-size: var(--fs-14); font-weight: 600; color: var(--c-ink-900); }
.cmm__meta   { font-size: var(--fs-12); color: var(--c-ink-500); }
/* Bajar a cero NO borra el producto: deja de listarse, y su historial queda. Decirlo acá evita
   que parezca que se está eliminando algo. */
.cmm__chip-sale {
  margin-left: 6px; padding: 1px 7px; border-radius: 999px;
  background: var(--c-ink-100); color: var(--c-ink-500);
  font-size: var(--fs-12); font-weight: 600;
}

.cmm__nums  { display: inline-flex; align-items: baseline; gap: 6px; white-space: nowrap; }
.cmm__antes { font-family: var(--font-mono); font-size: var(--fs-13); color: var(--c-ink-500); }
.cmm__hasta { font-size: var(--fs-12); color: var(--c-ink-300); }
.cmm__ahora { font-family: var(--font-mono); font-size: var(--fs-14); font-weight: 700; color: var(--c-ink-900); }
.cmm__delta {
  font-family: var(--font-mono); font-size: var(--fs-13); font-weight: 700;
  min-width: 78px; text-align: right; white-space: nowrap;
}
.cmm__row.is-sube .cmm__delta { color: var(--c-leaf-600); }
.cmm__row.is-baja .cmm__delta { color: var(--c-amber-500); }

/* ── El motivo ──────────────────────────────────────────────────────────────── */
.cmm__campo { display: flex; flex-direction: column; gap: 7px; }
.cmm__campo-lbl { font-size: var(--fs-13); font-weight: 600; color: var(--c-ink-900); }
.cmm__sugeridos { display: flex; gap: 6px; flex-wrap: wrap; }
.cmm__chip {
  border: 1px solid var(--c-slate-300); background: #fff; color: var(--c-ink-700);
  border-radius: 999px; padding: 5px 12px; font-size: var(--fs-12); font-weight: 600;
  cursor: pointer; transition: background var(--t-fast), border-color var(--t-fast);
}
.cmm__chip:hover  { background: var(--c-leaf-50); border-color: var(--c-leaf-300); }
.cmm__chip.is-on  { background: var(--c-leaf-800); border-color: var(--c-leaf-800); color: #fff; }

.cmm__input {
  border: 1px solid var(--c-slate-300); border-radius: 9px; padding: 9px 11px;
  font-size: var(--fs-14); width: 100%; background: #fff; color: var(--c-ink-900);
}
.cmm__input:focus { outline: 2px solid var(--c-leaf-300); outline-offset: 1px; border-color: var(--c-leaf-500); }

.cmm__nota { margin: 0; font-size: var(--fs-12); color: var(--c-ink-500); }

.cmm__acc { display: flex; gap: 10px; justify-content: flex-end; }
.cmm__btn {
  border-radius: 9px; padding: 10px 18px; font-size: var(--fs-14); font-weight: 600;
  cursor: pointer; border: 1px solid transparent;
}
.cmm__btn:disabled { opacity: .5; cursor: not-allowed; }
.cmm__btn--primary { background: var(--c-leaf-800); color: #fff; }
.cmm__btn--primary:not(:disabled):hover { background: var(--c-leaf-900); }
.cmm__btn--ghost   { background: #fff; color: var(--c-ink-700); border-color: var(--c-slate-300); }
.cmm__btn--ghost:not(:disabled):hover { background: var(--c-slate-50); }

@media (max-width: 640px) {
  .cmm__row   { flex-wrap: wrap; }
  .cmm__delta { min-width: 0; }
}
</style>
