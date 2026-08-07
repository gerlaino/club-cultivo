<template>
  <Teleport to="body">
    <Transition name="hd-fade">
      <div v-if="modelValue" class="hd-overlay" @click="close" />
    </Transition>
    <Transition name="hd-slide">
      <aside v-if="modelValue" class="hd-drawer" role="dialog" aria-modal="true" aria-label="Ayuda rápida">

        <div class="hd-head">
          <div class="hd-head-left">
            <HelpCircle :size="17" :stroke-width="1.75" />
            <span class="hd-head-title">Ayuda rápida</span>
          </div>
          <button class="hd-close" @click="close" aria-label="Cerrar ayuda">
            <X :size="18" :stroke-width="1.75" />
          </button>
        </div>

        <div class="hd-body">
          <div v-for="(section, si) in sections" :key="si" class="hd-acc">
            <button
              class="hd-acc-hd"
              :class="{ 'hd-acc-hd--open': openSet.has(si) }"
              @click="toggle(si)"
            >
              <span>{{ section.title }}</span>
              <ChevronDown :size="15" :stroke-width="2" class="hd-chevron" :class="{ 'hd-chevron--open': openSet.has(si) }" />
            </button>
            <Transition name="hd-expand">
              <div v-if="openSet.has(si)" class="hd-acc-body">
                <div v-for="(item, ii) in section.items" :key="ii" class="hd-item">
                  <span class="hd-item-label">{{ item.label }}</span>
                  <p class="hd-item-text">{{ item.text }}</p>
                </div>
              </div>
            </Transition>
          </div>
        </div>

        <div class="hd-foot">
          <p>¿Necesitás más ayuda? Contactá al administrador del club.</p>
        </div>

      </aside>
    </Transition>
  </Teleport>
</template>

<script setup>
import { ref, computed, watch, onUnmounted } from 'vue'
import { useAuthStore } from '../stores/auth.js'
import { HelpCircle, X, ChevronDown } from 'lucide-vue-next'

const props = defineProps({ modelValue: Boolean })
const emit  = defineEmits(['update:modelValue'])

const auth    = useAuthStore()
const openSet = ref(new Set([0]))

function close() { emit('update:modelValue', false) }

function toggle(i) {
  const s = new Set(openSet.value)
  s.has(i) ? s.delete(i) : s.add(i)
  openSet.value = s
}

function onKeydown(e) { if (e.key === 'Escape') close() }

watch(() => props.modelValue, (open) => {
  if (open) {
    openSet.value = new Set([0])
    document.addEventListener('keydown', onKeydown)
  } else {
    document.removeEventListener('keydown', onKeydown)
  }
})
onUnmounted(() => document.removeEventListener('keydown', onKeydown))

const CONTENT = {
  admin: [
    {
      title: 'Pacientes y dispensaciones',
      items: [
        { label: 'Dar de alta un paciente', text: 'Ir a Pacientes → Nuevo paciente. Completá nombre, DNI y datos básicos. El paciente queda activo de inmediato.' },
        { label: 'Crédito y cuenta corriente', text: 'No hay límite mensual de gramos: el control es financiero. Podés habilitarle crédito de cuenta corriente a un paciente para que dispense y pague después; el saldo se ve en su ficha.' },
        { label: 'Historial del paciente', text: 'Desde la ficha del paciente → pestaña Timeline podés ver todas las dispensaciones, notas e indicaciones.' },
      ]
    },
    {
      title: 'Usuarios y sedes',
      items: [
        { label: 'Crear usuario', text: 'En Usuarios → Nuevo usuario. Elegí el rol primero: cada rol tiene campos específicos. El supervisor requiere sede asignada.' },
        { label: 'Asignar sede a supervisor', text: 'Al crear un supervisor podés seleccionar la sede en el mismo wizard. También desde el detalle del usuario.' },
        { label: 'Sedes', text: 'Creá y gestioná sedes desde el menú Sedes. Cada sede puede tener sus propios usuarios, salas y stocks.' },
      ]
    },
    {
      title: 'Reportes y correo',
      items: [
        { label: 'Exportar pacientes a CSV', text: 'En el listado de Pacientes, el botón Exportar genera un CSV con todos los datos.' },
        { label: 'Informe REPROCANN', text: 'En Reportes → Informe REPROCANN encontrás el estado de vencimientos para presentar ante ARICCAME.' },
        { label: 'Correo a pacientes', text: 'Desde la ficha de un paciente → pestaña Correo podés enviar emails. Configurá el servidor SMTP en Preferencias → Correo.' },
      ]
    },
  ],
  dispensador: [
    {
      title: 'Cómo dispensar',
      items: [
        { label: 'Abrir el carrito', text: 'Desde la ficha del paciente (o el Historial) tocá "Nueva dispensación". La dispensa es un carrito: podés sumar varios productos/stocks en una misma entrega.' },
        { label: 'Agregar productos', text: 'Buscá el paciente por nombre, apellido o DNI. Elegí el stock y la cantidad de cada línea; la disponibilidad se valida al confirmar. Podés aplicar un descuento sobre el total.' },
        { label: 'Confirmar', text: 'Revisá el medio de pago y confirmá. El stock de cada línea se descuenta automáticamente.' },
      ]
    },
    {
      title: 'Medios de pago',
      items: [
        { label: 'Efectivo / Transferencia', text: 'Registra la forma de pago a modo informativo. El sistema no procesa el cobro.' },
        { label: 'Cuenta corriente / No abona', text: 'Para pacientes con crédito habilitado por el admin: la dispensa queda como saldo en su cuenta corriente. Si el botón está deshabilitado, el paciente no tiene crédito disponible.' },
      ]
    },
    {
      title: 'Reservas y historial',
      items: [
        { label: 'Entregar una reserva', text: 'Podés convertir una reserva en dispensa (Entregar), cobrando el resto. Las reservas las crea y gestiona el admin/supervisor.' },
        { label: 'Ver dispensaciones', text: 'En Historial consultás todas las dispensaciones, con filtros por fecha o por paciente.' },
      ]
    },
  ],
  medico: [
    {
      title: 'Indicaciones médicas',
      items: [
        { label: 'Crear indicación', text: 'Desde la ficha del paciente → pestaña Indicaciones → Nueva indicación. Completá diagnóstico, dosis y vigencia.' },
        { label: 'Vincular a dispensación', text: 'Al registrar una dispensación, el dispensador puede asociarla a una indicación activa del paciente.' },
      ]
    },
    {
      title: 'Notas clínicas',
      items: [
        { label: 'Historial clínico', text: 'La historia clínica la pueden VER admin, médico y supervisor; editarla, solo médico y admin. Accedé desde la ficha del paciente → Notas.' },
        { label: 'Seguimiento médico', text: 'Marcá "Con seguimiento médico" en la ficha para supervisar clínicamente al paciente.' },
      ]
    },
  ],
  supervisor: [
    {
      title: 'Gestión de sedes',
      items: [
        { label: 'Ver tu sede', text: 'Desde el dashboard podés ver el resumen de actividad de las sedes asignadas a tu usuario.' },
        { label: 'Asignación de usuarios', text: 'Solo el admin puede asignar usuarios a sedes. Solicitáselo si necesitás agregar alguien a una sede.' },
      ]
    },
    {
      title: 'Monitoreo',
      items: [
        { label: 'Reportes por sede', text: 'En el menú de cada sede podés ver dispensaciones, stocks y pacientes asociados.' },
      ]
    },
    {
      title: 'Comercial y clínico',
      items: [
        { label: 'Dispensás y reservás', text: 'Además de la supervisión del cultivo, podés dispensar y crear/gestionar reservas de stock para pacientes.' },
        { label: 'Historia clínica (lectura)', text: 'Podés ver la historia clínica de los pacientes, pero no editarla (eso es de médico y admin).' },
      ]
    },
  ],
  manicura: [
    {
      title: 'Flujo post-cosecha',
      items: [
        { label: 'Lote asignado', text: 'El admin te asigna un lote cosechado para manicurar. Aparece en tu cola de trabajo (Pendientes).' },
        { label: 'Registrar el peso', text: 'Escaneá el QR de cada planta, o usá "Registrar por lote" para cargar el peso de varias a la vez. Si el lote está asignado a vos, solo vos registrás su peso.' },
        { label: 'Cerrar y enviar', text: 'Cuando terminaste, cerrá la jornada y enviala a confirmar. El admin la aprueba y ahí se genera el stock de flor seca.' },
        { label: '¿Seguir una jornada?', text: 'Si volvés a un lote que ya enviaste sin confirmar, el sistema te pregunta si seguir esa jornada o empezar una nueva.' },
      ]
    },
  ],
  cultivador: [
    {
      title: 'Salas y lotes',
      items: [
        { label: 'Crear lote', text: 'Entrá a una sala → Crear lote. Asigná genética y cantidad de plantas. Si la sala es de floración/cosecha, el lote se carga como "existente" indicando los días previos (esqueje/vegetativo) y el sistema calcula la fecha de inicio.' },
        { label: 'Cambiar fase', text: 'En el detalle del lote avanzá la fase: Vegetativo → Floración → Cosecha.' },
        { label: 'Registrar costos', text: 'En cada lote podés registrar costos: insumos, mano de obra, energía para calcular el costo por gramo.' },
      ]
    },
    {
      title: 'Ambiente',
      items: [
        { label: 'Alertas ambientales', text: 'La campana en el header muestra alertas de temperatura, humedad, CO₂ y VPD de tus salas.' },
        { label: 'Historial', text: 'En el detalle de cada sala → pestaña Ambiente podés ver el historial de mediciones.' },
      ]
    },
  ],
  auditor: [
    {
      title: 'Informes disponibles',
      items: [
        { label: 'Solo lectura', text: 'El rol auditor puede ver todos los informes pero no puede modificar datos.' },
        { label: 'Tipos de informes', text: 'REPROCANN, producción, dispensaciones, sedes, cumplimiento, plan vs real, INASE y trazabilidad. Cada informe tiene filtros de fecha y descarga en PDF.' },
        { label: 'Acceso por sede', text: 'Si tenés sedes asignadas, solo ves datos de esas sedes. Sin sedes asignadas, ves el club completo.' },
      ]
    },
  ],
}

const FALLBACK = [
  {
    title: 'Navegación',
    items: [
      { label: 'Mi perfil', text: 'Desde el menú de usuario (arriba a la derecha) podés editar tus datos personales.' },
      { label: 'Soporte', text: 'Para cualquier consulta, contactá al administrador del club.' },
    ]
  },
]

const sections = computed(() => CONTENT[auth.role] || FALLBACK)
</script>

<style scoped>
.hd-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, .22);
  z-index: 1000;
}

.hd-drawer {
  position: fixed;
  top: 0; right: 0; bottom: 0;
  width: 380px;
  max-width: 100vw;
  background: var(--c-paper);
  border-left: 1px solid var(--c-ink-200);
  box-shadow: -8px 0 32px rgba(0, 0, 0, .1);
  z-index: 1001;
  display: flex;
  flex-direction: column;
  overflow: hidden;
}
@media (max-width: 480px) { .hd-drawer { width: 100vw; } }

.hd-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: var(--sp-4) var(--sp-5);
  border-bottom: 1px solid var(--c-ink-100);
  flex-shrink: 0;
}
.hd-head-left { display: flex; align-items: center; gap: var(--sp-2); color: var(--c-ink-600); }
.hd-head-title { font-size: var(--fs-15); font-weight: 700; color: var(--c-ink-900); }

.hd-close {
  width: 32px; height: 32px;
  border-radius: var(--r-md);
  border: 1px solid var(--c-ink-200);
  background: transparent;
  color: var(--c-ink-500);
  display: flex; align-items: center; justify-content: center;
  cursor: pointer;
  transition: background var(--t-fast), color var(--t-fast);
}
.hd-close:hover { background: var(--c-ink-100); color: var(--c-ink-900); }

.hd-body { flex: 1; overflow-y: auto; }

.hd-acc { border-bottom: 1px solid var(--c-ink-100); }
.hd-acc:last-child { border-bottom: none; }

.hd-acc-hd {
  width: 100%;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--sp-2);
  padding: var(--sp-3) var(--sp-5);
  background: none;
  border: none;
  cursor: pointer;
  font-size: var(--fs-14);
  font-weight: 600;
  color: var(--c-ink-800);
  text-align: left;
  transition: background var(--t-fast), color var(--t-fast);
}
.hd-acc-hd:hover  { background: var(--c-ink-50); color: var(--c-ink-900); }
.hd-acc-hd--open  { color: var(--c-leaf-700); background: var(--c-leaf-50); }

.hd-chevron { color: var(--c-ink-400); transition: transform .2s ease; flex-shrink: 0; }
.hd-chevron--open { transform: rotate(180deg); color: var(--c-leaf-600); }

.hd-acc-body { padding: var(--sp-1) var(--sp-5) var(--sp-4); }

.hd-item { margin-bottom: var(--sp-3); }
.hd-item:last-child { margin-bottom: 0; }
.hd-item-label { display: block; font-size: var(--fs-13); font-weight: 600; color: var(--c-ink-900); margin-bottom: 3px; }
.hd-item-text  { font-size: var(--fs-13); color: var(--c-ink-600); line-height: 1.55; margin: 0; }

.hd-foot {
  padding: var(--sp-3) var(--sp-5);
  border-top: 1px solid var(--c-ink-100);
  background: var(--c-ink-50);
  flex-shrink: 0;
}
.hd-foot p { font-size: var(--fs-12); color: var(--c-ink-500); margin: 0; }

/* Transitions */
.hd-fade-enter-active,
.hd-fade-leave-active { transition: opacity .2s ease; }
.hd-fade-enter-from,
.hd-fade-leave-to     { opacity: 0; }

.hd-slide-enter-active { transition: transform .22s ease-out; }
.hd-slide-leave-active { transition: transform .18s ease-in; }
.hd-slide-enter-from,
.hd-slide-leave-to     { transform: translateX(100%); }

.hd-expand-enter-active,
.hd-expand-leave-active { transition: opacity .12s ease; }
.hd-expand-enter-from,
.hd-expand-leave-to     { opacity: 0; }
</style>
