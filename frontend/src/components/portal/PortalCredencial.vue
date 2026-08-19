<template>
  <section class="pcr" :class="`pcr--${cat}`">
    <!-- La tarjeta. Tocarla la abre a pantalla completa: es lo que se muestra en la puerta. -->
    <button class="pcr__card" type="button" @click="abierta = true">
      <span class="pcr__top">
        <span class="pcr__club">
          <img v-if="club?.logo_url" :src="club.logo_url" :alt="club.name" class="pcr__logo" />
          <LeafSeal v-else :size="18" class="pcr__hoja" />
          <span class="pcr__club-n">{{ club?.name || 'Mi organización' }}</span>
        </span>
        <span class="pcr__nro">N.º {{ c.numero_socio }}</span>
      </span>

      <span class="pcr__nombre">{{ c.nombre }} {{ c.apellido }}</span>
      <span class="pcr__dni">DNI {{ c.dni }}</span>

      <span class="pcr__estado">
        <span class="pcr__punto" aria-hidden="true"></span>
        <span class="pcr__estado-t">{{ ESTADOS[cat].titulo }}</span>
        <span class="pcr__estado-b">{{ detalle }}</span>
      </span>

      <span class="pcr__ver"><Maximize2 :size="13" :stroke-width="2" /> Mostrar</span>
    </button>

    <!-- Pantalla completa: brillo al máximo mental, nada más que lo que el que atiende necesita
         leer. Sin scroll, sin navegación, sin nada que tocar por accidente. -->
    <Teleport to="body">
      <div v-if="abierta" class="pcr__full portal" role="dialog" aria-label="Mi credencial" @click="abierta = false">
        <button class="pcr__cerrar" type="button" aria-label="Cerrar" @click.stop="abierta = false">
          <X :size="22" :stroke-width="1.75" />
        </button>

        <div class="pcr__full-in" @click.stop>
          <img v-if="club?.logo_url" :src="club.logo_url" :alt="club.name" class="pcr__full-logo" />
          <p class="pcr__full-club">{{ club?.name }}</p>

          <p class="pcr__full-nombre">{{ c.nombre }} {{ c.apellido }}</p>
          <p class="pcr__full-dni">DNI {{ c.dni }} · Socio N.º {{ c.numero_socio }}</p>

          <div class="pcr__full-qr">
            <img v-if="qr" :src="qr" alt="Código del carnet" />
            <DsSpinner v-else :size="28" />
          </div>

          <p class="pcr__full-estado" :class="`pcr__full-estado--${cat}`">{{ ESTADOS[cat].titulo }}</p>
          <p class="pcr__full-detalle">{{ detalle }}</p>
          <p v-if="c.reprocann_numero" class="pcr__full-rep">REPROCANN {{ c.reprocann_numero }}</p>
        </div>
      </div>
    </Teleport>
  </section>
</template>

<script setup>
// La credencial: la pantalla que el paciente más abre, y la única que usa PARADO, en la puerta.
//
// Hasta hoy esto vivía sólo en `/c/:token` —un link que le mandan y que probablemente perdió— y el
// portal no la mostraba en ningún lado. Ahora es lo primero del inicio.
//
// El estado del REPROCANN vive ACÁ y no en una franja aparte, que es donde estaba. Motivo: es el
// mismo dato que el que atiende va a mirar cuando le muestre la tarjeta, y separarlo obligaba a
// leer dos cosas en dos lugares para contestar una sola pregunta —¿puede retirar?—. La franja de
// arriba se quedó sólo con lo urgente.
//
// El QR se genera contra el mismo `/c/:token` público: el que atiende lo escanea y ve la ficha
// anonimizada sin que el paciente tenga que tener nada instalado.
import { ref, computed, watch } from 'vue'
import { storeToRefs } from 'pinia'
import { Maximize2, X } from 'lucide-vue-next'
import LeafSeal from '@/design-system/icons/LeafSeal.vue'
import DsSpinner from '@/design-system/components/Spinner.vue'
import { usePortalClubStore } from '@/stores/portalClub'

const props = defineProps({
  credencial: { type: Object, required: true },
})

const { club } = storeToRefs(usePortalClubStore())
const abierta = ref(false)
const qr = ref(null)

const c = computed(() => props.credencial)

// Las cinco categorías son las MISMAS del informe REPROCANN, y las manda el backend. Que la
// tarjeta del paciente y el informe del auditor no puedan discrepar es el punto.
const ESTADOS = {
  vigente:       { titulo: 'Podés retirar' },
  por_vencer:    { titulo: 'Se te vence pronto' },
  vencido:       { titulo: 'No podés retirar' },
  pendiente:     { titulo: 'Trámite en curso' },
  sin_reprocann: { titulo: 'Sin REPROCANN' },
}

const cat = computed(() => (ESTADOS[c.value?.reprocann_categoria] ? c.value.reprocann_categoria : 'sin_reprocann'))

// La bajada dice la FECHA, no sólo el estado: "vence el 3 de septiembre" es accionable, "vigente"
// no. Con el vencimiento cerca se agrega cuántos días faltan, que es lo que hace levantar el
// teléfono.
const detalle = computed(() => {
  const dias  = c.value?.dias_para_vencer
  const vence = c.value?.reprocann_vencimiento
  const f = vence
    ? new Date(vence).toLocaleDateString('es-AR', { day: 'numeric', month: 'long', year: 'numeric' })
    : null

  if (cat.value === 'vencido')       return f ? `Venció el ${f}. Renovalo para poder retirar.` : 'Renovalo para poder retirar.'
  if (cat.value === 'por_vencer')    return `Vence el ${f}${dias > 0 ? ` · faltan ${dias} ${dias === 1 ? 'día' : 'días'}` : ' · vence hoy'}. El trámite tarda, empezalo ya.`
  if (cat.value === 'pendiente')     return 'Tu organización cargó el trámite. Todavía no tenés certificado.'
  if (cat.value === 'sin_reprocann') return 'Hablá con tu organización para iniciar el trámite.'
  return f ? `REPROCANN vigente hasta el ${f}.` : 'REPROCANN vigente.'
})

// El QR se arma sólo cuando se abre la pantalla completa: es la única vez que se ve, y cargar la
// librería en el inicio le costaba el arranque a todos los que nunca la abren.
watch(abierta, async (v) => {
  if (!v || qr.value || !c.value?.carnet_token) return
  try {
    const QR = (await import('qrcode')).default
    qr.value = await QR.toDataURL(`${window.location.origin}/c/${c.value.carnet_token}`, {
      width: 320, margin: 1, errorCorrectionLevel: 'M',
    })
  } catch { /* sin QR la credencial sigue sirviendo: el nombre y el DNI están a la vista */ }
})
</script>

<style scoped>
/* ── La tarjeta ── */
.pcr__card {
  display: flex; flex-direction: column; width: 100%; text-align: left;
  gap: var(--sp-1); cursor: pointer; position: relative;
  padding: var(--sp-5); border: 0; border-radius: var(--p-radio);
  background: var(--p-marca-fuerte); color: #fff;
  font-family: inherit; font-size: inherit;
  box-shadow: var(--sh-2);
}

.pcr__top { display: flex; align-items: center; gap: var(--sp-3); margin-bottom: var(--sp-4); }
.pcr__club { display: flex; align-items: center; gap: var(--sp-2); min-width: 0; }
.pcr__logo { width: 22px; height: 22px; border-radius: var(--r-pill); object-fit: cover; flex: 0 0 auto; }
.pcr__hoja { color: rgb(255 255 255 / .6); flex: 0 0 auto; }
.pcr__club-n {
  font-size: var(--fs-13); color: rgb(255 255 255 / .75);
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
}
.pcr__nro {
  margin-left: auto; flex: 0 0 auto;
  font-family: var(--font-mono); font-size: var(--fs-12); color: rgb(255 255 255 / .6);
}

.pcr__nombre {
  font-family: var(--p-display);
  font-size: var(--fs-24); font-weight: 600; letter-spacing: -.02em; line-height: var(--lh-tight);
}
.pcr__dni {
  font-family: var(--font-mono); font-size: var(--fs-13);
  color: rgb(255 255 255 / .65); margin-bottom: var(--sp-4);
}

/* El estado: el bloque que el que atiende va a mirar. */
.pcr__estado {
  display: grid; grid-template-columns: auto 1fr; gap: 0 var(--sp-2); align-items: center;
  padding-top: var(--sp-4); border-top: 1px solid rgb(255 255 255 / .15);
}
.pcr__punto { width: 8px; height: 8px; border-radius: var(--r-pill); }
.pcr__estado-t { font-weight: 600; font-size: var(--fs-16); }
.pcr__estado-b {
  grid-column: 2; font-size: var(--fs-13); color: rgb(255 255 255 / .7);
  line-height: var(--lh-base);
}

.pcr--vigente       .pcr__punto { background: var(--p-ok); }
.pcr--por_vencer    .pcr__punto { background: var(--p-atencion); }
.pcr--vencido       .pcr__punto { background: var(--p-urgente); }
.pcr--pendiente     .pcr__punto { background: var(--p-atencion); }
.pcr--sin_reprocann .pcr__punto { background: var(--p-atencion); }

/* Vencido: la tarjeta entera cambia de color. Es el único estado que impide retirar, y si se ve
   igual que "vigente" con un puntito distinto, no se ve. */
.pcr--vencido .pcr__card { background: var(--p-urgente); }

.pcr__ver {
  position: absolute; top: var(--sp-4); right: var(--sp-4);
  display: inline-flex; align-items: center; gap: var(--sp-1);
  font-size: var(--fs-12); font-weight: 600; color: rgb(255 255 255 / .7);
}
.pcr__card:hover .pcr__ver { color: #fff; }
.pcr__top .pcr__nro { margin-right: 84px; }

/* ── Pantalla completa ── */
.pcr__full {
  position: fixed; inset: 0; z-index: 100;
  background: var(--p-papel);
  display: flex; align-items: center; justify-content: center;
  padding: var(--sp-6) var(--sp-4);
  overflow-y: auto;
}
.pcr__cerrar {
  position: absolute; top: var(--sp-3); right: var(--sp-3);
  background: none; border: 0; color: var(--p-tenue); cursor: pointer;
  display: flex; padding: var(--sp-2);
}
.pcr__full-in { text-align: center; max-width: 340px; width: 100%; }
.pcr__full-logo { width: 44px; height: 44px; border-radius: var(--r-pill); object-fit: cover; }
.pcr__full-club { font-size: var(--fs-13); color: var(--p-tenue); margin: var(--sp-2) 0 var(--sp-6); }
.pcr__full-nombre {
  font-family: var(--p-display); font-size: var(--fs-32); font-weight: 600;
  letter-spacing: -.02em; line-height: var(--lh-tight); margin: 0;
}
.pcr__full-dni { font-family: var(--font-mono); font-size: var(--fs-14); color: var(--p-suave); margin: var(--sp-2) 0 var(--sp-6); }

.pcr__full-qr {
  display: flex; align-items: center; justify-content: center;
  min-height: 220px; margin-bottom: var(--sp-6);
}
.pcr__full-qr img { width: 220px; height: 220px; }

.pcr__full-estado { font-size: var(--fs-18); font-weight: 600; margin: 0; }
.pcr__full-estado--vigente { color: var(--p-ok); }
.pcr__full-estado--vencido { color: var(--p-urgente); }
.pcr__full-estado--por_vencer,
.pcr__full-estado--pendiente,
.pcr__full-estado--sin_reprocann { color: var(--p-atencion); }
.pcr__full-detalle { color: var(--p-suave); font-size: var(--fs-14); margin: var(--sp-1) 0 0; line-height: var(--lh-base); }
.pcr__full-rep { font-family: var(--font-mono); font-size: var(--fs-13); color: var(--p-tenue); margin: var(--sp-3) 0 0; }
</style>
