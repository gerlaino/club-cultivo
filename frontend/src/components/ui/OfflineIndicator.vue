<script setup>
import { useNetwork } from '../../composables/useNetwork.js'
import { useOfflineSync } from '../../composables/useOfflineSync.js'
import { useSyncQueueStore } from '../../stores/syncQueue.js'

const { isOnline }       = useNetwork()
const { syncing, procesarCola } = useOfflineSync()
const queue              = useSyncQueueStore()
</script>

<template>
  <!-- Sin conexión -->
  <Transition name="oi-slide">
    <div v-if="!isOnline" class="oi oi--offline">
      <i class="bi bi-wifi-off"></i>
      <span>Sin conexión — los registros se guardan localmente</span>
    </div>
  </Transition>

  <!-- Con conexión y hay pendientes -->
  <Transition name="oi-slide">
    <div v-if="isOnline && queue.total > 0" class="oi oi--pending">
      <i v-if="!syncing" class="bi bi-arrow-repeat"></i>
      <span v-if="!syncing" class="oi-spin"><i class="bi bi-arrow-clockwise"></i></span>
      <span>
        {{ syncing ? 'Sincronizando…' : `${queue.total} pendiente${queue.total > 1 ? 's' : ''}` }}
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
  background: #1e293b; color: #f8fafc;
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
