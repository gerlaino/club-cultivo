<script setup>
// El cartel de "sin conexión". Decía **"los registros se guardan localmente"**, y eso es cierto
// sólo para TRES cosas: dispensar, registrar ambiente y las entregas del repartidor. Para todo lo
// demás —el pesaje del manicura, una tarea, la edición de un lote— es falso: la request falla y no
// queda nada. Un manicura sin señal leía esa promesa, cargaba el pesaje, le fallaba y se iba
// pensando que había quedado guardado.
//
// Por eso el cartel **dejó de prometer**. Dice dos cosas que siempre son verdad: que no hay
// conexión, y cuántas cosas hay esperando irse. Qué se guarda y qué no lo dice cada pantalla, que
// es la única que lo sabe: el modal de dispensación avisa "guardada localmente", el repartidor ve
// su contador. Una lista de excepciones acá arriba sería la misma regla escrita en dos lugares, y
// se desincronizaría con el primer flujo que se sume o se saque.
//
// Cuenta las DOS colas: la genérica (`syncQueue`, que llena `lib/offlineApi.js`) y la de entregas,
// que vive en su propio localStorage. Contando sólo la primera, el repartidor no veía nada fuera
// de su pantalla.
import { computed } from 'vue'
import { useNetwork } from '../../composables/useNetwork.js'
import { useOfflineSync } from '../../composables/useOfflineSync.js'
import { useEntregasOffline } from '../../composables/useEntregasOffline.js'
import { useSyncQueueStore } from '../../stores/syncQueue.js'

const { isOnline }              = useNetwork()
const { syncing, procesarCola } = useOfflineSync()
const queue                     = useSyncQueueStore()
const { pendientes: entregas }  = useEntregasOffline()

// Lo que existe de verdad esperando irse al servidor.
const guardados = computed(() => queue.total + entregas.value.length)
</script>

<template>
  <!-- Sin conexión -->
  <Transition name="oi-slide">
    <div v-if="!isOnline" class="oi oi--offline">
      <i class="bi bi-wifi-off"></i>
      <span v-if="guardados">
        Sin conexión — {{ guardados }} sin enviar, se mandan solos al volver la señal
      </span>
      <span v-else>Sin conexión</span>
    </div>
  </Transition>

  <!-- Con conexión y hay pendientes -->
  <Transition name="oi-slide">
    <div v-if="isOnline && guardados > 0" class="oi oi--pending">
      <i v-if="!syncing" class="bi bi-arrow-repeat"></i>
      <span v-if="!syncing" class="oi-spin"><i class="bi bi-arrow-clockwise"></i></span>
      <span>
        {{ syncing ? 'Sincronizando…' : `${guardados} sin enviar` }}
      </span>
      <button v-if="!syncing && queue.fallidos.length" class="oi__retry" @click="procesarCola">
        Reintentar
      </button>
    </div>
  </Transition>
</template>

<style scoped>
.oi {
  position: fixed; bottom: 1rem; left: 50%; transform: translateX(-50%);
  display: inline-flex; align-items: center; gap: .5rem;
  padding: .5rem 1rem; border-radius: 999px;
  font-size: .78rem; font-weight: 600; z-index: 9999;
  box-shadow: 0 4px 16px rgba(0,0,0,.15);
  white-space: nowrap;
}
.oi--offline {
  background: #1e293b; color: var(--c-slate-50);
}
.oi--pending {
  background: #1b5e20; color: #fff;
}
.oi__retry {
  background: rgba(255,255,255,.2); border: none; color: #fff;
  padding: .2rem .6rem; border-radius: 999px; font-size: .72rem;
  font-weight: 700; cursor: pointer; margin-left: .25rem;
}
.oi__retry:hover { background: rgba(255,255,255,.3); }

/* Spinner animation */
.oi-spin i { animation: oi-rotate .8s linear infinite; display: inline-block; }
@keyframes oi-rotate { from { transform: rotate(0deg); } to { transform: rotate(360deg); } }

/* Transition */
.oi-slide-enter-active, .oi-slide-leave-active { transition: opacity .3s, transform .3s; }
.oi-slide-enter-from, .oi-slide-leave-to { opacity: 0; transform: translateX(-50%) translateY(12px); }
</style>
