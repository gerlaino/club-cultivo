<template>
  <section class="pcr" :class="[`pcr--${estado.clave}`, { 'pcr--bloqueado': !c.puede_retirar }]">
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
        <span class="pcr__estado-t">{{ estado.titulo }}</span>
        <span class="pcr__estado-b">{{ estado.detalle }}</span>
      </span>

      <!-- El REPROCANN es un dato SUYO, no el que decide si puede retirar. Se muestra igual —con
           su fecha y su color— porque renovarlo lleva semanas y es lo único que el portal le
           avisa a tiempo. -->
      <span v-if="reprocann" class="pcr__rep" :class="`pcr__rep--${reprocann.nivel}`">
        <span class="pcr__rep-k">REPROCANN</span>
        <span class="pcr__rep-v">{{ reprocann.texto }}</span>
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

          <p class="pcr__full-estado" :class="`pcr__full-estado--${estado.clave}`">{{ estado.titulo }}</p>
          <p class="pcr__full-detalle">{{ estado.detalle }}</p>
          <p v-if="reprocann" class="pcr__full-rep">
            REPROCANN<template v-if="c.reprocann_numero"> {{ c.reprocann_numero }}</template>
            · {{ reprocann.texto }}
          </p>
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
// La tarjeta contesta UNA pregunta —¿puede retirar?— y la contesta con lo que el sistema exige de
// verdad. Debajo, como dato aparte, va el REPROCANN con su fecha: es su trámite, tarda semanas en
// renovarse, y el portal es lo único que se lo avisa antes de que venza. La franja de arriba se
// quedó sólo con lo urgente.
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

// ── ¿Puede retirar? ────────────────────────────────────────────────────────────────────────
//
// Lo contesta el BACKEND (`credencial.puede_retirar`), y sale de lo que `Dispensacion` valida de
// verdad: que la persona esté activa en la organización y aprobada. El REPROCANN no participa.
//
// Antes esto se calculaba acá a partir del REPROCANN, y mentía en los dos sentidos: al vencido le
// decía "no podés retirar" cuando sí podía, y a uno vigente pero dado de baja o pendiente de
// aprobación le decía que sí, y lo rebotaban en la puerta. La segunda es peor: lo hace viajar al
// vicio. Es el mismo error de siempre —la regla escrita en dos lugares— con la agravante de que
// acá el otro lugar era el que manda.
const MOTIVOS = {
  baja:      { titulo: 'Tu cuenta está dada de baja',
               detalle: 'Hablá con tu organización para reactivarla.' },
  pendiente: { titulo: 'Todavía no estás habilitado',
               detalle: 'Tu alta está esperando que la aprueben. Hablá con tu organización.' },
}

const estado = computed(() => {
  if (c.value?.puede_retirar) {
    return { clave: 'ok', titulo: 'Podés retirar', detalle: 'Tu cuenta está activa y aprobada.' }
  }
  const m = MOTIVOS[c.value?.motivo_bloqueo] || MOTIVOS.pendiente
  return { clave: 'bloqueado', ...m }
})

// ── El REPROCANN, como dato propio ─────────────────────────────────────────────────────────
//
// Ya no decide nada, pero se muestra igual y con color: renovarlo lleva semanas, es SU trámite, y
// es lo único que el portal le avisa antes de que pase. Dice la FECHA y no sólo el estado —
// "vence el 3 de septiembre" es accionable, "vigente" no.
const REPROCANN = {
  vigente:       { nivel: 'ok' },
  por_vencer:    { nivel: 'atencion' },
  vencido:       { nivel: 'urgente' },
  pendiente:     { nivel: 'atencion' },
  sin_reprocann: { nivel: 'atencion' },
}

const reprocann = computed(() => {
  const cat  = c.value?.reprocann_categoria
  const meta = REPROCANN[cat]
  if (!meta) return null

  const dias  = c.value?.dias_para_vencer
  const vence = c.value?.reprocann_vencimiento
  const f = vence
    ? new Date(vence).toLocaleDateString('es-AR', { day: 'numeric', month: 'long', year: 'numeric' })
    : null

  const texto = {
    vigente:       f ? `Vigente hasta el ${f}` : 'Vigente',
    por_vencer:    `Vence el ${f}${dias > 0 ? ` · faltan ${dias} ${dias === 1 ? 'día' : 'días'}` : ' · vence hoy'}`,
    vencido:       f ? `Venció el ${f} · renovalo` : 'Vencido · renovalo',
    pendiente:     'Trámite en curso',
    sin_reprocann: 'Sin cargar · hablá con tu organización',
  }[cat]

  return { ...meta, texto }
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

.pcr--ok        .pcr__punto { background: var(--p-ok); }
.pcr--bloqueado .pcr__punto { background: var(--p-urgente); }

/* No poder retirar cambia la tarjeta ENTERA de color. Es lo único que le impide llevarse su
   medicación, y con un puntito distinto no se ve. */
.pcr--bloqueado .pcr__card { background: var(--p-urgente); }

/* ── El REPROCANN, debajo de la línea ── */
.pcr__rep {
  display: flex; align-items: baseline; gap: var(--sp-2); flex-wrap: wrap;
  margin-top: var(--sp-3); padding-top: var(--sp-3);
  border-top: 1px solid rgb(255 255 255 / .12);
  font-size: var(--fs-13);
}
.pcr__rep-k {
  font-size: var(--fs-12); letter-spacing: .08em; text-transform: uppercase;
  color: rgb(255 255 255 / .5);
}
.pcr__rep-v { color: rgb(255 255 255 / .8); }
/* Vencido o por vencer se marcan, pero sin gritar: no impiden retirar. */
.pcr__rep--atencion .pcr__rep-v { color: var(--p-atencion); font-weight: 600; }
.pcr__rep--urgente  .pcr__rep-v { color: #fff; font-weight: 600; }

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
.pcr__full-estado--ok        { color: var(--p-ok); }
.pcr__full-estado--bloqueado { color: var(--p-urgente); }
.pcr__full-detalle { color: var(--p-suave); font-size: var(--fs-14); margin: var(--sp-1) 0 0; line-height: var(--lh-base); }
.pcr__full-rep { font-family: var(--font-mono); font-size: var(--fs-13); color: var(--p-tenue); margin: var(--sp-3) 0 0; }
</style>
