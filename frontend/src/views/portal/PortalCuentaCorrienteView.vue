<template>
  <div class="pcc">
    <header class="pcc__hd">
      <h1 class="pcc__title">Cuenta corriente</h1>
      <p class="pcc__sub">Tu saldo con la organización y los movimientos que lo explican.</p>
    </header>

    <div v-if="cargando" class="pcc__estado"><DsSpinner :size="36" /></div>

    <div v-else-if="!cc?.tiene" class="pcc__estado">
      <div class="pcc__vacio-ico">💳</div>
      <p class="pcc__vacio-txt">
        Tu organización no te abrió cuenta corriente. Abonás cada retiro en el momento.
      </p>
    </div>

    <template v-else>
      <section class="pcc__resumen" :class="{ 'pcc__resumen--debe': cc.debe > 0 }">
        <div class="pcc__monto-lbl">{{ cc.debe > 0 ? 'Debés' : 'Tenés a favor' }}</div>
        <div class="pcc__monto">{{ pesos(cc.debe > 0 ? cc.debe : cc.saldo) }}</div>

        <div v-if="cc.tiene_credito" class="pcc__limite">
          <div class="pcc__barra">
            <div class="pcc__barra-fill" :style="{ width: cc.porcentaje_usado + '%' }"></div>
          </div>
          <div class="pcc__limite-txt">
            Usaste {{ cc.porcentaje_usado }}% de tu límite de {{ pesos(cc.limite) }}
          </div>
        </div>
      </section>

      <section class="pcc__movs">
        <h2 class="pcc__h2">Movimientos</h2>

        <p v-if="!cc.movimientos.length" class="pcc__vacio-txt">Todavía no hay movimientos.</p>

        <ul v-else class="pcc__lista">
          <li v-for="m in cc.movimientos" :key="m.id" class="pcc__mov">
            <div class="pcc__mov-txt">
              <span class="pcc__mov-label">{{ m.label }}</span>
              <span class="pcc__mov-fecha">{{ fecha(m.fecha) }}</span>
            </div>
            <span class="pcc__mov-monto" :class="m.suma ? 'pcc__mov-monto--suma' : 'pcc__mov-monto--resta'">
              {{ m.suma ? '+' : '−' }}{{ pesos(Math.abs(m.monto)) }}
            </span>
          </li>
        </ul>
      </section>
    </template>
  </div>
</template>

<script setup>
// Lo que el paciente ve de su cuenta corriente. Hoy es lectura: más adelante acredita saldo desde
// acá mismo.
//
// El saldo interno arranca en 0 y se va a NEGATIVO a medida que usa el crédito. Acá se traduce a
// "debés" o "tenés a favor": un número con signo obliga a interpretarlo, y quien lo lee no está
// mirando un libro contable, está mirando cuánto tiene.
import { ref, onMounted } from 'vue'
import { getPortalCuentaCorriente } from '@/lib/portalApi'
import DsSpinner from '@/design-system/components/Spinner.vue'

const cc       = ref(null)
const cargando = ref(true)

const pesos = (n) =>
  new Intl.NumberFormat('es-AR', { style: 'currency', currency: 'ARS', maximumFractionDigits: 0 }).format(n || 0)
const fecha = (f) =>
  new Date(f).toLocaleDateString('es-AR', { day: 'numeric', month: 'short', year: 'numeric' })

onMounted(async () => {
  try {
    cc.value = await getPortalCuentaCorriente()
  } catch {
    cc.value = { tiene: false }
  } finally {
    cargando.value = false
  }
})
</script>

<style scoped>
.pcc { max-width: 620px; margin: 0 auto; padding: 2rem 1.25rem 3rem; }
.pcc__hd { margin-bottom: 1.75rem; }
.pcc__title { font-size: 1.5rem; font-weight: 800; color: var(--p-tinta); margin: 0 0 .25rem; }
.pcc__sub { color: var(--p-suave); font-size: .9rem; margin: 0; }

.pcc__estado {
  display: flex; flex-direction: column; align-items: center; justify-content: center;
  gap: .75rem; padding: 3rem 1rem; text-align: center; color: var(--p-suave);
}
.pcc__vacio-ico { font-size: 2.5rem; }
.pcc__vacio-txt { margin: 0; max-width: 340px; color: var(--p-suave); }

.pcc__resumen {
  border: 1px solid var(--p-linea); border-radius: 14px; padding: 1.5rem; background: var(--p-hundido);
  margin-bottom: 1.5rem;
}
.pcc__resumen--debe { background: var(--p-atencion-bg); border-color: color-mix(in srgb, var(--p-atencion) 35%, transparent); }
.pcc__monto-lbl {
  font-size: .72rem; text-transform: uppercase; letter-spacing: .07em; font-weight: 700;
  color: var(--p-suave); margin-bottom: .3rem;
}
.pcc__monto { font-size: 2rem; font-weight: 800; color: var(--p-tinta); line-height: 1.1; }
.pcc__resumen--debe .pcc__monto { color: var(--p-atencion); }

.pcc__limite { margin-top: 1.1rem; }
.pcc__barra { height: 7px; background: var(--p-linea); border-radius: 20px; overflow: hidden; }
.pcc__barra-fill { height: 100%; background: var(--p-marca); border-radius: 20px; }
.pcc__resumen--debe .pcc__barra-fill { background: var(--p-atencion); }
.pcc__limite-txt { font-size: .8rem; color: var(--p-suave); margin-top: .4rem; }

.pcc__movs { margin-top: .5rem; }
.pcc__h2 { font-size: 1rem; font-weight: 700; color: var(--p-tinta); margin: 0 0 .75rem; }
.pcc__lista { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: .4rem; }
.pcc__mov {
  display: flex; align-items: center; justify-content: space-between; gap: 1rem;
  border: 1px solid var(--p-linea); border-radius: 10px; padding: .7rem .9rem; background: #fff;
}
.pcc__mov-txt { display: flex; flex-direction: column; min-width: 0; }
.pcc__mov-label { font-weight: 600; color: var(--p-tinta); font-size: .9rem; }
.pcc__mov-fecha { font-size: .78rem; color: var(--p-suave); }
.pcc__mov-monto { font-weight: 700; font-size: .95rem; white-space: nowrap; }
.pcc__mov-monto--suma  { color: var(--p-ok); }
.pcc__mov-monto--resta { color: var(--p-atencion); }
</style>
