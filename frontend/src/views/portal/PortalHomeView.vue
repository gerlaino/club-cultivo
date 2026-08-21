<template>
  <div class="pmi">

    <div v-if="cargando" class="pmi__cargando"><DsSpinner :size="32" /></div>

    <template v-else>
      <!-- ── A · La credencial ──────────────────────────────────────────────
           Lo primero, sin título arriba: no necesita que le expliquen qué es. -->
      <PortalCredencial v-if="credencial" :credencial="credencial" />

      <p class="pmi__hola" v-else>
        Hola{{ credencial?.nombre ? `, ${credencial.nombre}` : '' }}. Tu organización todavía no
        terminó de cargar tu ficha.
      </p>

      <!-- ── B · Lo mío ─────────────────────────────────────────────────── -->
      <section class="pmi__sec">
        <h2 class="pmi__sec-t">Lo mío</h2>

        <!-- Turno. Lo primero porque es lo único con hora. -->
        <RouterLink v-if="turno" to="/portal/mi-salud" class="pmi__ficha">
          <span class="pmi__ico"><CalendarClock :size="18" :stroke-width="1.75" /></span>
          <span class="pmi__ficha-c">
            <span class="pmi__ficha-l">Próximo turno</span>
            <span class="pmi__ficha-v">{{ fechaHora(turno.fecha_hora) }}</span>
            <span class="pmi__ficha-b">
              {{ turno.tipo_label }}<template v-if="turno.medico"> · {{ turno.medico }}</template>
            </span>
          </span>
          <ChevronRight :size="16" :stroke-width="1.75" class="pmi__chev" />
        </RouterLink>

        <!-- Indicación médica vigente. -->
        <RouterLink v-if="indicacion" to="/portal/mi-salud" class="pmi__ficha">
          <span class="pmi__ico" :class="{ 'pmi__ico--alerta': indicacion.vencida || indicacion.por_vencer }">
            <ClipboardList :size="18" :stroke-width="1.75" />
          </span>
          <span class="pmi__ficha-c">
            <span class="pmi__ficha-l">Mi indicación</span>
            <span class="pmi__ficha-v">{{ indicacion.dosificacion }}</span>
            <span class="pmi__ficha-b">{{ vigenciaIndicacion }}</span>
          </span>
          <ChevronRight :size="16" :stroke-width="1.75" class="pmi__chev" />
        </RouterLink>

        <!-- Cuenta corriente, sólo si la organización se la abrió. -->
        <RouterLink v-if="cc?.tiene" to="/portal/cuenta-corriente" class="pmi__ficha">
          <span class="pmi__ico" :class="{ 'pmi__ico--alerta': cc.debe > 0 }">
            <Wallet :size="18" :stroke-width="1.75" />
          </span>
          <span class="pmi__ficha-c">
            <span class="pmi__ficha-l">Mi cuenta</span>
            <span class="pmi__ficha-v">{{ cc.debe > 0 ? `Debés ${pesos(cc.debe)}` : `Tenés ${pesos(cc.saldo)} a favor` }}</span>
            <span class="pmi__ficha-b">Ver los movimientos</span>
          </span>
          <ChevronRight :size="16" :stroke-width="1.75" class="pmi__chev" />
        </RouterLink>

        <!-- Último retiro. Siempre está, aunque sea para decir que no retiró nunca. -->
        <RouterLink to="/portal/historial" class="pmi__ficha">
          <span class="pmi__ico"><PackageCheck :size="18" :stroke-width="1.75" /></span>
          <span class="pmi__ficha-c">
            <span class="pmi__ficha-l">Mis retiros</span>
            <span class="pmi__ficha-v">
              {{ ultimoRetiro ? `Último: ${fechaCorta(ultimoRetiro.fecha)}` : 'Todavía no retiraste nada' }}
            </span>
            <span v-if="ultimoRetiro" class="pmi__ficha-b">{{ resumenRetiro }}</span>
          </span>
          <ChevronRight :size="16" :stroke-width="1.75" class="pmi__chev" />
        </RouterLink>
      </section>

      <!-- ── C · Mi organización ─────────────────────────────────────────
           El boletín en dos renglones. Todo lo demás está en su sección. -->
      <section v-if="destacado || evento" class="pmi__sec">
        <div class="pmi__sec-hd">
          <h2 class="pmi__sec-t">Mi organización</h2>
          <RouterLink to="/portal/organizacion" class="pmi__mas">Ver todo</RouterLink>
        </div>

        <RouterLink v-if="evento" :to="`/portal/eventos/${evento.id}`" class="pmi__nota">
          <span class="pmi__nota-k">Próximo evento</span>
          <span class="pmi__nota-t">{{ evento.titulo }}</span>
          <span class="pmi__nota-b">{{ fechaHora(evento.fecha_inicio) }}<template v-if="evento.lugar"> · {{ evento.lugar }}</template></span>
        </RouterLink>

        <RouterLink v-if="destacado" :to="`/portal/noticias/${destacado.id}`" class="pmi__nota">
          <span class="pmi__nota-k">Novedades</span>
          <span class="pmi__nota-t">{{ destacado.titulo }}</span>
          <span v-if="destacado.preview" class="pmi__nota-b">{{ destacado.preview }}</span>
        </RouterLink>
      </section>
    </template>

  </div>
</template>

<script setup>
// EL INICIO DEL PORTAL ES EL ESTADO DEL PACIENTE.
//
// Hasta acá el inicio era el boletín de la organización —portada de novedades, agenda, catálogo—
// con este razonamiento: "entra a mirar qué hay de nuevo, no a revisar lo que ya hizo". El
// razonamiento tenía un error: trata lo del paciente como PASADO. Casi nada de lo suyo lo es. El
// REPROCANN vigente, el próximo turno, la indicación vigente y el saldo son presente y futuro, y
// son las cuatro cosas que un paciente entra a preguntar. Y hay un problema práctico encima: el
// boletín está VACÍO en cualquier organización que no publique —que son casi todas, casi todas las
// semanas—. Su estado no está vacío nunca.
//
// Así que el orden es: quién soy y si puedo retirar (la credencial) · lo mío que viene (turno,
// indicación, cuenta, retiros) · lo que publica el club, en dos renglones y con "ver todo".
//
// El boletín no se perdió: es `/portal/organizacion`, la misma pantalla, con su entrada en la barra.
import { ref, computed, onMounted } from 'vue'
import { CalendarClock, ClipboardList, Wallet, PackageCheck, ChevronRight } from 'lucide-vue-next'
import {
  getPortalMiEstado, getPortalMiSalud, getPortalCuentaCorriente,
  getPortalHistorial, getPortalNoticias, getPortalEventos,
} from '@/lib/portalApi'
import PortalCredencial from '@/components/portal/PortalCredencial.vue'
import DsSpinner from '@/design-system/components/Spinner.vue'

const cargando   = ref(true)
const credencial = ref(null)
const turno      = ref(null)
const indicacion = ref(null)
const cc         = ref(null)
const retiros    = ref([])
const noticias   = ref([])
const eventos    = ref([])

const ultimoRetiro = computed(() => retiros.value[0] || null)
const destacado    = computed(() => noticias.value[0] || null)
const evento       = computed(() => eventos.value[0] || null)

const resumenRetiro = computed(() => {
  const r = ultimoRetiro.value
  if (!r) return ''
  const nombres = (r.items || []).map(i => i.genetica).filter(Boolean)
  const gramos  = r.gramos ? `${r.gramos} g` : ''
  const que = nombres.length > 1 ? `${nombres[0]} y ${nombres.length - 1} más` : nombres[0] || ''
  return [gramos, que].filter(Boolean).join(' · ')
})

const vigenciaIndicacion = computed(() => {
  const i = indicacion.value
  if (!i) return ''
  if (i.vencida)    return `Venció el ${fechaCorta(i.fecha_vencimiento)}. Pedí una nueva.`
  if (i.por_vencer) return `Vence el ${fechaCorta(i.fecha_vencimiento)}`
  return i.medico ? `Indicada por ${i.medico}` : 'Vigente'
})

const d = (f) => new Date(f)
const fechaCorta = (f) => (f ? d(f).toLocaleDateString('es-AR', { day: 'numeric', month: 'short' }) : '')
const fechaHora  = (f) => (f
  ? d(f).toLocaleString('es-AR', { weekday: 'long', day: 'numeric', month: 'long', hour: '2-digit', minute: '2-digit' })
  : '')
const pesos = (n) => new Intl.NumberFormat('es-AR', { style: 'currency', currency: 'ARS', maximumFractionDigits: 0 }).format(n || 0)

onMounted(async () => {
  // Seis llamadas y ninguna hace caer a las otras: sin módulo médico no hay turno, y el resto de
  // la pantalla tiene que salir igual.
  const [est, sal, cta, his, not, eve] = await Promise.allSettled([
    getPortalMiEstado(), getPortalMiSalud(), getPortalCuentaCorriente(),
    getPortalHistorial(), getPortalNoticias(), getPortalEventos(),
  ])

  if (est.status === 'fulfilled') credencial.value = est.value?.credencial || null
  if (sal.status === 'fulfilled') {
    turno.value      = sal.value?.proximo_turno || null
    indicacion.value = sal.value?.indicacion || null
  }
  if (cta.status === 'fulfilled') cc.value       = cta.value || null
  if (his.status === 'fulfilled') retiros.value  = his.value || []
  if (not.status === 'fulfilled') noticias.value = not.value || []
  if (eve.status === 'fulfilled') eventos.value  = eve.value || []

  cargando.value = false
})
</script>

<style scoped>
/* Mobile-first: se diseña a 360 y se ensancha. El resto de la app es al revés porque se usa
   sentado en el club; esto se usa parado, en la puerta. */
.pmi { max-width: var(--p-ancho); margin: 0 auto; padding: var(--sp-6) var(--sp-4) var(--sp-12); }
.pmi__cargando { display: flex; justify-content: center; padding: var(--sp-12); }
.pmi__hola { color: var(--p-suave); line-height: var(--lh-base); margin: 0 0 var(--sp-8); }

.pmi__sec { margin-top: var(--sp-10); }
.pmi__sec-hd { display: flex; align-items: baseline; justify-content: space-between; gap: var(--sp-4); }
.pmi__sec-t {
  font-family: var(--p-display);
  font-size: var(--fs-18); font-weight: 600; margin: 0 0 var(--sp-3); letter-spacing: -.01em;
}
.pmi__sec-hd .pmi__sec-t { margin-bottom: var(--sp-3); }
.pmi__mas { font-size: var(--fs-13); font-weight: 600; color: var(--p-marca); text-decoration: none; white-space: nowrap; }
.pmi__mas:hover { text-decoration: underline; }

/* Las fichas de "lo mío": una línea por pregunta, todas iguales, todas tocables entera. */
.pmi__ficha {
  display: flex; align-items: center; gap: var(--sp-4);
  padding: var(--sp-4); margin-bottom: var(--sp-2);
  background: var(--p-papel); border: 1px solid var(--p-linea);
  border-radius: var(--p-radio-sm);
  text-decoration: none; color: inherit;
  transition: border-color var(--t-fast), box-shadow var(--t-fast);
}
.pmi__ficha:hover { border-color: var(--p-marca-linea); box-shadow: var(--sh-1); }

.pmi__ico {
  width: 38px; height: 38px; flex: 0 0 auto;
  display: flex; align-items: center; justify-content: center;
  background: var(--p-marca-suave); color: var(--p-marca); border-radius: var(--r-pill);
}
.pmi__ico--alerta { background: var(--p-atencion-bg); color: var(--p-atencion); }

.pmi__ficha-c { display: flex; flex-direction: column; min-width: 0; flex: 1; }
.pmi__ficha-l {
  font-size: var(--fs-12); text-transform: uppercase; letter-spacing: .08em; color: var(--p-tenue);
}
.pmi__ficha-v {
  font-weight: 600; line-height: var(--lh-tight);
  overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
}
.pmi__ficha-b {
  font-size: var(--fs-13); color: var(--p-suave); line-height: var(--lh-base);
  overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
}
.pmi__chev { color: var(--p-tenue); flex: 0 0 auto; }

/* Mi organización: texto, sin foto. La foto está en la sección; acá compite con la credencial. */
.pmi__nota {
  display: flex; flex-direction: column; gap: 2px;
  padding: var(--sp-3) 0; text-decoration: none; color: inherit;
  border-bottom: 1px dotted var(--p-linea);
}
.pmi__sec .pmi__nota:last-child { border-bottom: 0; }
.pmi__nota-k {
  font-size: var(--fs-12); text-transform: uppercase; letter-spacing: .08em; color: var(--p-tenue);
}
.pmi__nota-t { font-weight: 600; }
.pmi__nota-b {
  font-size: var(--fs-13); color: var(--p-suave); line-height: var(--lh-base);
  display: -webkit-box; -webkit-line-clamp: 2; line-clamp: 2; -webkit-box-orient: vertical; overflow: hidden;
}
.pmi__nota:hover .pmi__nota-t { text-decoration: underline; text-underline-offset: 3px; }

@media (min-width: 640px) {
  .pmi { padding: var(--sp-10) var(--sp-4) var(--sp-12); }
}
</style>
