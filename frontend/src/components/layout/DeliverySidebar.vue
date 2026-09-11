<template>
  <aside class="dlv-sidebar">
    <div class="dlv-logo">
      <img src="/logo-ce-icono.png" class="dlv-logo-img" alt="Cultivo Espacial" />
      <span>Delivery</span>
    </div>

    <nav class="dlv-nav">
      <RouterLink to="/delivery" class="dlv-link" exact-active-class="dlv-link--active">
        <Home :size="18" :stroke-width="1.75" /><span>Inicio</span>
      </RouterLink>
      <!-- La caja del repartidor: salió del inicio y tiene su pantalla. Es la MISMA vista que
           sirve la PWA — una sola, dos envoltorios. Al admin no le sirve (no lleva efectivo en
           la calle), así que sólo la ve quien reparte. -->
      <RouterLink v-if="soyRepartidor" to="/delivery/caja" class="dlv-link" active-class="dlv-link--active">
        <Wallet :size="18" :stroke-width="1.75" /><span>Caja</span>
        <span v-if="cajaDelivery.llevaEfectivo" class="dlv-punto" aria-label="Tenés efectivo sin rendir"></span>
      </RouterLink>
      <RouterLink v-if="canSeeDespachos" to="/delivery/despachos" class="dlv-link" active-class="dlv-link--active">
        <PackageCheck :size="18" :stroke-width="1.75" /><span>Despachos</span>
      </RouterLink>
    </nav>

  </aside>
</template>

<script setup>
import { computed, onMounted } from 'vue'
import { Home, PackageCheck, Wallet } from 'lucide-vue-next'
import { useAuthStore } from '../../stores/auth'
import { useCajaDeliveryStore } from '../../stores/cajaDelivery.js'
// El logout vive en el menú de usuario de DeliveryTopBar, como en el resto de los roles.
const auth = useAuthStore()
const canSeeDespachos = computed(() => ['admin', 'supervisor'].includes(auth.user?.role))
const soyRepartidor   = computed(() => auth.user?.role === 'delivery')
// El mismo punto que la barra del teléfono, por lo mismo: la plata salió del inicio y algo tiene
// que decirle que la tiene. El store se carga solo en el shell móvil; acá se pide al entrar.
const cajaDelivery = useCajaDeliveryStore()
onMounted(() => { if (soyRepartidor.value) cajaDelivery.cargar() })
</script>

<style scoped>
.dlv-sidebar {
  width: 200px; min-width: 200px;
  background: var(--c-role-delivery);
  display: flex; flex-direction: column;
  padding: var(--sp-4) 0; flex-shrink: 0;
}
.dlv-logo {
  display: flex; align-items: center; gap: var(--sp-2);
  padding: var(--sp-3) var(--sp-5) var(--sp-5);
  color: rgba(255,255,255,.65); font-weight: 700; font-size: var(--fs-16);
}
.dlv-logo-img { width: 28px; height: 28px; border-radius: 50%; object-fit: cover; flex-shrink: 0; }
.dlv-nav { flex: 1; display: flex; flex-direction: column; gap: 2px; padding: 0 var(--sp-3); }
.dlv-link {
  display: flex; align-items: center; gap: var(--sp-3);
  padding: var(--sp-2) var(--sp-3);
  color: rgba(255,255,255,.55);
  border-radius: var(--r-md); text-decoration: none;
  font-size: var(--fs-14); font-weight: 500; transition: all .15s;
}
.dlv-link:hover { color: #fff; background: rgba(255,255,255,.1); }
.dlv-link--active { color: #fff; background: rgba(255,255,255,.18); }
.dlv-punto { width: 7px; height: 7px; border-radius: 50%; background: #f59e0b; margin-left: auto; }
@media (max-width: 1023px) { .dlv-sidebar { display: none; } }
</style>
