<script setup>
import { ref, computed, watch, onMounted } from 'vue'
import { useAuthStore } from '../../stores/auth.js'

const auth = useAuthStore()

// ── Datos por rol ────────────────────────────────────────────────────────────

const CHECKLISTS = {
  admin: [
    {
      id: 'sede',
      emoji: '🏢',
      titulo: 'Configurá tu sede',
      descripcion: 'Nombre, dirección, CUIT y número REPROCANN del club.',
      pasos: [
        'Andá a Sedes en el menú lateral izquierdo.',
        'Hacé clic en "Nueva sede".',
        'Completá nombre, dirección, CUIT y el número REPROCANN del club.',
        'Guardá — ya aparece activa en tu dashboard.',
      ],
      tip: 'El REPROCANN lo emite el Ministerio de Salud de la Nación. Lo vas a necesitar para el Informe Semestral.',
      ruta: '/sedes',
      rutaLabel: 'Ir a Sedes',
    },
    {
      id: 'salas',
      emoji: '🌱',
      titulo: 'Creá las salas de cultivo',
      descripcion: 'Cada sala es un grow room o espacio físico de producción.',
      pasos: [
        'Andá a Salas en el menú lateral.',
        'Hacé clic en "Nueva sala".',
        'Asignale un nombre descriptivo y su tipo (vegetativo, floración…).',
        'Asigná el cultivador responsable de esa sala.',
        'Repetí por cada espacio activo del club.',
      ],
      tip: 'Podés organizar las salas por estadío (veg / floración) o por espacio físico. Lo que mejor refleje tu operación.',
      ruta: '/salas/nueva',
      rutaLabel: 'Crear primera sala',
    },
    {
      id: 'usuarios',
      emoji: '👥',
      titulo: 'Sumá a tu equipo',
      descripcion: 'Invitá cultivadores, dispensadores, médicos y más.',
      pasos: [
        'Andá a Usuarios en el menú lateral.',
        'Hacé clic en "Invitar usuario".',
        'Ingresá el email y elegí el rol: cultivador, dispensador, médico, manicuro, etc.',
        'El usuario recibe un mail con su acceso.',
      ],
      tip: 'Cada rol ve solo lo que necesita — el cultivador no ve contabilidad, el dispensador no ve el cultivo.',
      ruta: '/usuarios',
      rutaLabel: 'Gestionar usuarios',
    },
    {
      id: 'socio',
      emoji: '🪪',
      titulo: 'Registrá el primer paciente',
      descripcion: 'DNI, REPROCANN, documentación y vencimiento de autorización.',
      pasos: [
        'Andá a Pacientes en el menú lateral.',
        'Hacé clic en "Nuevo paciente".',
        'Completá nombre, apellido, DNI y fecha de nacimiento.',
        'Cargá la fecha de vencimiento del REPROCANN y el estado de la autorización.',
        'Desde la ficha del paciente podés agregar documentos y notas clínicas.',
      ],
      tip: 'El sistema avisa 30 días antes de que venza el REPROCANN de cualquier paciente — sin seguimiento manual de tu parte.',
      ruta: '/pacientes/nuevo',
      rutaLabel: 'Nuevo paciente',
    },
    {
      id: 'contabilidad',
      emoji: '📊',
      titulo: 'Revisá el balance contable',
      descripcion: 'Libro de movimientos, ingresos, egresos y balance del mes.',
      pasos: [
        'Andá a Contabilidad en el menú lateral.',
        'Cada dispensación se registra automáticamente como movimiento.',
        'Agregá ingresos y egresos manuales: cuotas, gastos operativos, etc.',
        'Exportá el libro en CSV para tu contador.',
      ],
      tip: 'Los movimientos de dispensación se generan solos. Solo tenés que agregar lo que no sea automatizable.',
      ruta: '/contabilidad',
      rutaLabel: 'Ver contabilidad',
    },
    {
      id: 'informe',
      emoji: '📋',
      titulo: 'Generá el Informe Semestral',
      descripcion: 'El informe que el club presenta ante la autoridad sanitaria cada 6 meses.',
      pasos: [
        'Andá a Informe Semestral en el menú lateral.',
        'Seleccioná el período (semestre 1 o 2) y el año.',
        'Revisá el preview — el sistema detecta datos faltantes que podrían observarte.',
        'Completá los campos faltantes y descargá el PDF final.',
      ],
      tip: 'Cuantos más datos tengas cargados (dispensaciones, lotes, pacientes), más completo y preciso sale el informe.',
      ruta: '/informe-semestral',
      rutaLabel: 'Ir al Informe Semestral',
    },
  ],

  cultivador: [
    {
      id: 'salas',
      emoji: '🏠',
      titulo: 'Conocé tus salas',
      descripcion: 'Las salas que el admin te asignó y su estado actual.',
      pasos: [
        'En tu dashboard ya ves las salas que tenés asignadas.',
        'Hacé clic en una sala para ver los lotes activos y las condiciones ambientales.',
        'Si no aparece ninguna sala, pedile al admin que te asigne una.',
      ],
      tip: 'Cada sala tiene su propio historial ambiental. Podés ver temperatura, humedad y alertas de las últimas horas.',
      ruta: '/salas',
      rutaLabel: 'Ver mis salas',
    },
    {
      id: 'lote',
      emoji: '🌿',
      titulo: 'Creá el primer lote',
      descripcion: 'Un lote es un grupo de plantas de la misma genética en el mismo cultivo.',
      pasos: [
        'Andá a Lotes en el menú lateral.',
        'Hacé clic en "Crear lote".',
        'Elegí la genética, la sala, la cantidad de plantas y la fecha de inicio.',
        'El lote arranca en estadío Vegetativo — podés avanzarlo cuando corresponda.',
      ],
      tip: 'Si cultivás varias genéticas en la misma sala, creá un lote separado por cada una. Así el rendimiento queda trazado por genética.',
      ruta: '/lotes',
      rutaLabel: 'Ir a Lotes',
    },
    {
      id: 'plantas',
      emoji: '🌱',
      titulo: 'Agregá plantas al lote',
      descripcion: 'Cada planta tiene su registro propio y un QR único de trazabilidad.',
      pasos: [
        'Entrá al lote que acabás de crear.',
        'Hacé clic en "Agregar plantas".',
        'Indicá el origen (semilla o esqueje) y la cantidad.',
        'El sistema genera un QR único por planta para su seguimiento físico.',
      ],
      tip: 'Podés imprimir el QR y pegarlo en la maceta. Escaneándolo desde el celular abrís la ficha de esa planta directamente.',
      ruta: '/plantas/nueva',
      rutaLabel: 'Nueva planta',
    },
    {
      id: 'ambiente',
      emoji: '🌡️',
      titulo: 'Registrá condiciones ambientales',
      descripcion: 'Temperatura, humedad, pH y EC de la sala.',
      pasos: [
        'Entrá a la sala y hacé clic en "Registrar lectura".',
        'Ingresá temperatura, humedad relativa, pH y EC si corresponde.',
        'El historial queda guardado y podés ver la evolución en el tiempo.',
        'Si tenés sensores conectados, las lecturas entran automáticamente.',
      ],
      tip: 'Lo ideal es al menos una lectura por día. El sistema genera alertas si algún parámetro se sale del rango configurado.',
      ruta: '/salas',
      rutaLabel: 'Ir a mis salas',
    },
    {
      id: 'fase',
      emoji: '⏩',
      titulo: 'Avanzá la fase del lote',
      descripcion: 'Cuando el lote esté listo, pasalo a la siguiente etapa.',
      pasos: [
        'Entrá al lote desde la vista de Lotes.',
        'Hacé clic en "Avanzar fase".',
        'Confirmá el cambio — queda registrado con fecha y hora.',
        'Cultivo completo: Vegetativo → Floración → Cosecha → Secado → Manicura → Curado → Finalizado.',
      ],
      tip: 'Cada transición queda en el historial del lote y alimenta la analítica de cultivos: días promedio por fase y por genética.',
      ruta: '/lotes',
      rutaLabel: 'Ver mis lotes',
    },
  ],

  dispensador: [
    {
      id: 'stock',
      emoji: '📦',
      titulo: 'Conocé el stock disponible',
      descripcion: 'El stock dispensable aparece en tu dashboard, agrupado por forma de producto.',
      pasos: [
        'En tu dashboard ves el stock disponible por forma de producto (flor, aceite, etc.).',
        'El stock lo asigna el admin — vos ves lo que ya está habilitado para dispensar.',
        'Si hay stock bajo aparece una alerta en la tarjeta correspondiente.',
      ],
      tip: 'Si el stock está en cero o muy bajo, avisale al admin para que asigne producto desde los lotes finalizados.',
    },
    {
      id: 'dispensacion',
      emoji: '🤝',
      titulo: 'Hacé tu primera dispensación',
      descripcion: 'Buscá al paciente, elegí producto y cantidad, y confirmá.',
      pasos: [
        'Hacé clic en "Nueva dispensación" en el header del dashboard.',
        'Buscá al paciente por nombre o DNI.',
        'Seleccioná el producto y la cantidad a entregar.',
        'Confirmá — queda registrada con fecha, hora y operador.',
      ],
      tip: 'Cada dispensación se guarda automáticamente en el historial del paciente y en el libro contable.',
      ruta: '/historial',
      rutaLabel: 'Nueva dispensación',
    },
    {
      id: 'historial',
      emoji: '🕐',
      titulo: 'Revisá el historial del día',
      descripcion: 'Todo lo dispensado hoy aparece en la tabla de tu dashboard.',
      pasos: [
        'Scrolleá hacia abajo en tu dashboard — vas a ver "Última actividad".',
        'Aparece cada dispensación del día con hora, paciente, producto y cantidad.',
        'Para buscar dispensaciones anteriores, andá a Historial en el menú lateral.',
      ],
      tip: 'La tabla del dashboard muestra solo el día actual. El historial completo con filtros de fecha está en la sección Historial.',
      ruta: '/historial',
      rutaLabel: 'Ver historial completo',
    },
  ],

  medico: [
    {
      id: 'pacientes',
      emoji: '👤',
      titulo: 'Revisá tus pacientes',
      descripcion: 'Pacientes con seguimiento médico activo y estado de sus autorizaciones.',
      pasos: [
        'Andá a Pacientes en el menú lateral.',
        'Ves los pacientes que tienen seguimiento médico activo.',
        'Filtrá por estado de REPROCANN: al día, por vencer o vencido.',
        'El badge de color en cada fila indica la urgencia del vencimiento.',
      ],
      tip: 'Si un paciente no aparece, el admin no le asignó seguimiento médico todavía. Coordiná con él.',
      ruta: '/medico/pacientes',
      rutaLabel: 'Ver pacientes',
    },
    {
      id: 'historia',
      emoji: '📁',
      titulo: 'Abrí una historia clínica',
      descripcion: 'Cada paciente tiene su ficha completa: historial, dispensaciones y documentos.',
      pasos: [
        'Hacé clic en cualquier paciente de tu lista.',
        'En la ficha vas a ver datos personales, historia clínica, dispensaciones históricas y documentos.',
        'Podés editar la historia clínica directamente desde la ficha.',
        'Los cambios quedan guardados con fecha y hora.',
      ],
      tip: 'Las dispensaciones las carga el dispensador. Tu rol es el seguimiento clínico, las indicaciones y el control de autorizaciones.',
      ruta: '/medico/pacientes',
      rutaLabel: 'Ir a pacientes',
    },
    {
      id: 'indicaciones',
      emoji: '📝',
      titulo: 'Cargá indicaciones médicas',
      descripcion: 'Dosis, producto y frecuencia para cada paciente.',
      pasos: [
        'Andá a Indicaciones en el menú lateral.',
        'Hacé clic en "Nueva indicación".',
        'Seleccioná el paciente, indicá producto, dosis y frecuencia.',
        'Establecé la fecha de vencimiento — el sistema te avisa antes de que venza.',
      ],
      tip: 'Las indicaciones vencidas quedan marcadas en rojo en tu dashboard. Revisalas regularmente para no dejar pacientes sin cobertura.',
      ruta: '/medico/indicaciones',
      rutaLabel: 'Ver indicaciones',
    },
    {
      id: 'vencimientos',
      emoji: '⏰',
      titulo: 'Controlá vencimientos de REPROCANN',
      descripcion: 'Alertas de autorizaciones próximas a vencer o ya vencidas.',
      pasos: [
        'En tu dashboard ves el resumen de vencimientos críticos.',
        'En Pacientes usá el filtro "Por vencer" para ver los próximos 30 días.',
        'Para cada paciente con vencimiento próximo, coordiná la renovación con el admin.',
        'Podés mandar un correo directo desde la ficha del paciente.',
      ],
      tip: 'Cada dispensación requiere REPROCANN vigente. Un paciente con la autorización vencida no debería recibir producto.',
      ruta: '/medico/pacientes',
      rutaLabel: 'Ver vencimientos',
    },
  ],

  auditor: [
    {
      id: 'dashboard',
      emoji: '🔍',
      titulo: 'Explorá el panel de auditoría',
      descripcion: 'Vista de solo lectura de todos los módulos del club.',
      pasos: [
        'Desde tu dashboard tenés acceso directo a todos los informes.',
        'Tu rol es de solo lectura — no podés modificar ningún dato.',
        'Cada sección muestra datos en tiempo real del club.',
      ],
      tip: 'Si encontrás inconsistencias, coordinalas con el admin del club. No podés editar datos desde este rol.',
    },
    {
      id: 'reprocann',
      emoji: '📋',
      titulo: 'Revisá el Informe REPROCANN',
      descripcion: 'Estado de habilitaciones médicas de todos los pacientes.',
      pasos: [
        'Andá a REPROCANN en el menú lateral.',
        'Ves el estado de cada paciente: vigente, por vencer o vencido.',
        'El informe incluye nombre, DNI y fecha de vencimiento de cada autorización.',
        'Podés exportar el informe completo a PDF.',
      ],
      tip: 'Este informe verifica que cada paciente que recibió producto tenía su autorización vigente al momento de la dispensación.',
      ruta: '/auditor/reprocann',
      rutaLabel: 'Ver informe REPROCANN',
    },
    {
      id: 'produccion',
      emoji: '🌿',
      titulo: 'Analizá producción y dispensaciones',
      descripcion: 'Lotes, rendimiento y entrega de producto a pacientes.',
      pasos: [
        'Andá a Producción para ver lotes, plantas, estados y rendimiento.',
        'Andá a Dispensaciones para ver el historial completo de entregas.',
        'Cada dispensación tiene fecha, paciente, producto, cantidad y operador.',
        'Podés filtrar por período y exportar a CSV.',
      ],
      tip: 'La trazabilidad cierra cuando podés seguir cada gramo: desde qué lote salió, en qué stock quedó, y a qué paciente se entregó.',
      ruta: '/auditor/produccion',
      rutaLabel: 'Ver producción',
    },
    {
      id: 'trazabilidad',
      emoji: '🔗',
      titulo: 'Revisá la trazabilidad completa',
      descripcion: 'Historial íntegro de cada movimiento del club.',
      pasos: [
        'Andá a Trazabilidad en el menú lateral.',
        'Buscá por lote, paciente, fecha o tipo de evento.',
        'Cada evento muestra quién lo registró, cuándo y en qué contexto.',
        'Para auditorías formales usá el informe de Cumplimiento, que consolida todo.',
      ],
      tip: 'La trazabilidad es tu aliada ante cualquier control. Cuanto más completa es la carga de datos del club, más sólido es el registro.',
      ruta: '/auditor/trazabilidad',
      rutaLabel: 'Ver trazabilidad',
    },
  ],
}

// ── Estado ───────────────────────────────────────────────────────────────────

const completados = ref(new Set())
const expandido   = ref(null)
const minimizado  = ref(false)
const mostrar     = ref(true)

const pasos = computed(() => CHECKLISTS[auth.user?.role] ?? [])

const progresoPct = computed(() =>
  pasos.value.length === 0 ? 100 : Math.round((completados.value.size / pasos.value.length) * 100)
)

const visible = computed(() => mostrar.value && pasos.value.length > 0)

// ── Persistencia ─────────────────────────────────────────────────────────────

function storageKey() {
  return `oc_${auth.user?.role}_${auth.user?.id}`
}

function cargarEstado() {
  if (!auth.user) return
  try {
    const raw = localStorage.getItem(storageKey())
    if (!raw) return
    const estado = JSON.parse(raw)
    completados.value = new Set(estado.completados || [])
    minimizado.value  = estado.minimizado ?? false
    if (estado.cerrado && progresoPct.value === 100) mostrar.value = false
  } catch {}
}

function guardarEstado(cerrado = false) {
  if (!auth.user) return
  localStorage.setItem(storageKey(), JSON.stringify({
    completados: [...completados.value],
    minimizado:  minimizado.value,
    cerrado,
  }))
}

// ── Acciones ─────────────────────────────────────────────────────────────────

function toggleExpand(id) {
  expandido.value = expandido.value === id ? null : id
}

function toggleCompletado(id) {
  const set = new Set(completados.value)
  if (set.has(id)) {
    set.delete(id)
  } else {
    set.add(id)
    const idx  = pasos.value.findIndex(p => p.id === id)
    const next = pasos.value[idx + 1]
    if (next && !set.has(next.id)) {
      setTimeout(() => { expandido.value = next.id }, 320)
    } else {
      setTimeout(() => { expandido.value = null }, 320)
    }
  }
  completados.value = set
  guardarEstado()
}

function toggleMinimizar() {
  minimizado.value = !minimizado.value
  guardarEstado()
}

function cerrar() {
  mostrar.value = false
  guardarEstado(true)
}

// ── Init ─────────────────────────────────────────────────────────────────────

onMounted(cargarEstado)

watch(() => auth.user, (u) => {
  if (!u) return
  cargarEstado()
  const first = pasos.value.find(p => !completados.value.has(p.id))
  if (first && !minimizado.value) expandido.value = first.id
}, { immediate: true })
</script>

<template>
  <div v-if="visible" class="oc" :class="{ 'oc--min': minimizado }">

    <!-- ── Header ────────────────────────────────────────────────────────── -->
    <div class="oc__header" @click="minimizado ? toggleMinimizar() : undefined">
      <div class="oc__header-left">
        <span class="oc__leaf">🌿</span>
        <div class="oc__header-text">
          <span class="oc__title">Primeros pasos en Cultivo Espacial</span>
          <span class="oc__prog-label">
            <template v-if="progresoPct < 100">
              {{ completados.size }} de {{ pasos.length }} completados
            </template>
            <template v-else>¡Todo listo!</template>
          </span>
        </div>
      </div>
      <div class="oc__header-right">
        <div class="oc__prog-wrap">
          <div class="oc__prog-track">
            <div class="oc__prog-bar" :style="{ width: progresoPct + '%' }"></div>
          </div>
          <span class="oc__prog-pct">{{ progresoPct }}%</span>
        </div>
        <button class="oc__btn-icon" @click.stop="toggleMinimizar" :title="minimizado ? 'Expandir' : 'Minimizar'">
          <i class="bi" :class="minimizado ? 'bi-chevron-down' : 'bi-chevron-up'"></i>
        </button>
        <button v-if="progresoPct === 100" class="oc__btn-icon oc__btn-icon--close" @click.stop="cerrar" title="Cerrar">
          <i class="bi bi-x-lg"></i>
        </button>
      </div>
    </div>

    <!-- ── Cuerpo ─────────────────────────────────────────────────────────── -->
    <div v-show="!minimizado" class="oc__body">

      <!-- Estado completado -->
      <div v-if="progresoPct === 100" class="oc__done">
        <span class="oc__done-emoji">🎉</span>
        <div>
          <p class="oc__done-title">¡Completaste todos los pasos!</p>
          <p class="oc__done-sub">Ya conocés las funciones principales. Podés cerrar este panel cuando quieras.</p>
        </div>
        <button class="oc__done-close" @click="cerrar">Cerrar <i class="bi bi-x"></i></button>
      </div>

      <!-- Lista de pasos -->
      <div v-else class="oc__pasos">
        <div
          v-for="(paso, i) in pasos"
          :key="paso.id"
          class="oc__paso"
          :class="{
            'oc__paso--done':   completados.has(paso.id),
            'oc__paso--open':   expandido === paso.id,
            'oc__paso--active': expandido === paso.id && !completados.has(paso.id),
          }"
        >
          <!-- Fila principal del paso -->
          <button class="oc__paso-hdr" @click="toggleExpand(paso.id)">
            <span class="oc__num" :class="{ 'oc__num--done': completados.has(paso.id) }">
              <i v-if="completados.has(paso.id)" class="bi bi-check-lg"></i>
              <span v-else>{{ i + 1 }}</span>
            </span>
            <span class="oc__paso-emoji">{{ paso.emoji }}</span>
            <div class="oc__paso-text">
              <span class="oc__paso-titulo">{{ paso.titulo }}</span>
              <span class="oc__paso-desc">{{ paso.descripcion }}</span>
            </div>
            <i
              class="bi oc__chevron"
              :class="expandido === paso.id ? 'bi-chevron-up' : 'bi-chevron-down'"
            ></i>
          </button>

          <!-- Contenido expandible -->
          <div class="oc__paso-body" :class="{ 'oc__paso-body--open': expandido === paso.id }">
            <ol class="oc__steps">
              <li v-for="s in paso.pasos" :key="s" class="oc__step">{{ s }}</li>
            </ol>
            <div v-if="paso.tip" class="oc__tip">
              <span class="oc__tip-ico">💡</span>
              <span class="oc__tip-text">{{ paso.tip }}</span>
            </div>
            <div class="oc__paso-actions">
              <RouterLink v-if="paso.ruta" :to="paso.ruta" class="oc__btn-ir">
                {{ paso.rutaLabel || 'Ir →' }}
                <i class="bi bi-arrow-right"></i>
              </RouterLink>
              <button
                class="oc__btn-marcar"
                :class="{ 'oc__btn-marcar--done': completados.has(paso.id) }"
                @click="toggleCompletado(paso.id)"
              >
                <i class="bi" :class="completados.has(paso.id) ? 'bi-check-circle-fill' : 'bi-circle'"></i>
                {{ completados.has(paso.id) ? 'Desmarcar' : 'Marcar como hecho' }}
              </button>
            </div>
          </div>
        </div>
      </div>

    </div>
  </div>
</template>

<style scoped>
/* ── Wrapper ───────────────────────────────────────────────────────────────── */
.oc {
  background: #fff;
  border: 1px solid #e8f0e9;
  border-radius: 14px;
  overflow: hidden;
  box-shadow: 0 2px 12px rgba(27, 94, 32, .07);
  max-width: 860px;
  margin: 0 auto 1.75rem;
  transition: box-shadow .2s;
}
.oc:hover { box-shadow: 0 4px 20px rgba(27, 94, 32, .10); }
@media (max-width: 767px) { .oc { margin: 0 0 1.25rem; border-radius: 10px; } }

/* ── Header ────────────────────────────────────────────────────────────────── */
.oc__header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 1rem 1.25rem;
  background: linear-gradient(135deg, #f0fdf4 0%, #fafffe 100%);
  border-bottom: 1px solid #e8f0e9;
  gap: .75rem;
}
.oc--min .oc__header {
  cursor: pointer;
  border-bottom: none;
}
.oc--min .oc__header:hover { background: #e8f5e9; }

.oc__header-left { display: flex; align-items: center; gap: .75rem; min-width: 0; }
.oc__leaf { font-size: 1.3rem; flex-shrink: 0; }
.oc__header-text { display: flex; flex-direction: column; gap: .1rem; min-width: 0; }
.oc__title { font-size: .9rem; font-weight: 700; color: #0f2611; white-space: nowrap; }
.oc__prog-label { font-size: .75rem; color: #60725d; }

.oc__header-right { display: flex; align-items: center; gap: .5rem; flex-shrink: 0; }

.oc__prog-wrap { display: flex; align-items: center; gap: .5rem; }
.oc__prog-track { width: 100px; height: 6px; background: #d1e8d3; border-radius: 999px; overflow: hidden; }
@media (max-width: 480px) { .oc__prog-track { width: 60px; } }
.oc__prog-bar {
  height: 100%;
  background: linear-gradient(90deg, #1b5e20, #2e7d32);
  border-radius: 999px;
  transition: width .5s cubic-bezier(.4, 0, .2, 1);
}
.oc__prog-pct { font-size: .72rem; font-weight: 700; color: #1b5e20; min-width: 30px; text-align: right; }

.oc__btn-icon {
  width: 28px; height: 28px;
  border: 1px solid #e8f0e9;
  border-radius: 7px;
  background: #fff;
  color: #60725d;
  cursor: pointer;
  display: flex; align-items: center; justify-content: center;
  font-size: .75rem;
  transition: all .15s;
  flex-shrink: 0;
}
.oc__btn-icon:hover { background: #e8f0e9; color: #1b5e20; border-color: #c8e6c9; }
.oc__btn-icon--close:hover { background: #fef2f2; color: #dc2626; border-color: #fecaca; }

/* ── Body ──────────────────────────────────────────────────────────────────── */
.oc__body { padding: .5rem 0 .25rem; }

/* ── Done state ────────────────────────────────────────────────────────────── */
.oc__done {
  display: flex;
  align-items: center;
  gap: 1rem;
  padding: 1.25rem 1.5rem;
  flex-wrap: wrap;
}
.oc__done-emoji { font-size: 2rem; flex-shrink: 0; }
.oc__done-title { font-size: .9rem; font-weight: 700; color: #0f2611; margin: 0 0 .2rem; }
.oc__done-sub   { font-size: .8rem; color: #60725d; margin: 0; }
.oc__done-close {
  margin-left: auto;
  background: #f0fdf4;
  border: 1.5px solid #c8e6c9;
  border-radius: 8px;
  padding: .45rem 1rem;
  font-size: .8rem;
  font-weight: 600;
  color: #1b5e20;
  cursor: pointer;
  display: flex; align-items: center; gap: .35rem;
  transition: all .15s;
  flex-shrink: 0;
}
.oc__done-close:hover { background: #dcfce7; border-color: #1b5e20; }

/* ── Pasos ─────────────────────────────────────────────────────────────────── */
.oc__pasos { display: flex; flex-direction: column; }

.oc__paso { border-top: 1px solid #f1f5f9; }
.oc__paso:first-child { border-top: none; }
.oc__paso--done { opacity: .65; }
.oc__paso--active { background: #fafffe; }

/* Fila del paso */
.oc__paso-hdr {
  width: 100%;
  display: flex;
  align-items: center;
  gap: .75rem;
  padding: .875rem 1.25rem;
  background: none;
  border: none;
  cursor: pointer;
  text-align: left;
  transition: background .12s;
}
.oc__paso-hdr:hover { background: #f6fbf6; }
.oc__paso--active .oc__paso-hdr { background: #f0fdf4; }

/* Círculo numerado */
.oc__num {
  width: 26px; height: 26px;
  border-radius: 50%;
  background: #e8f0e9;
  color: #60725d;
  font-size: .72rem;
  font-weight: 800;
  display: flex; align-items: center; justify-content: center;
  flex-shrink: 0;
  transition: all .2s;
}
.oc__num--done {
  background: #1b5e20;
  color: #fff;
}

.oc__paso-emoji { font-size: 1.1rem; flex-shrink: 0; }

.oc__paso-text { flex: 1; min-width: 0; display: flex; flex-direction: column; gap: .1rem; }
.oc__paso-titulo { font-size: .85rem; font-weight: 700; color: #0f2611; }
.oc__paso--done .oc__paso-titulo { color: #60725d; text-decoration: line-through; text-decoration-color: #a8c5a0; }
.oc__paso-desc { font-size: .75rem; color: #94a3b8; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
@media (max-width: 540px) { .oc__paso-desc { display: none; } }

.oc__chevron { color: #b0c4b1; font-size: .75rem; flex-shrink: 0; transition: transform .2s; }
.oc__paso--open .oc__chevron { transform: none; }

/* Cuerpo expandible */
.oc__paso-body {
  max-height: 0;
  overflow: hidden;
  transition: max-height .3s cubic-bezier(.4, 0, .2, 1);
}
.oc__paso-body--open { max-height: 600px; }

/* Lista de pasos internos */
.oc__steps {
  margin: 0;
  padding: .5rem 1.25rem .75rem 3.25rem;
  display: flex;
  flex-direction: column;
  gap: .4rem;
}
.oc__step {
  font-size: .82rem;
  color: #374151;
  line-height: 1.55;
  padding-left: .25rem;
}

/* Tip */
.oc__tip {
  display: flex;
  align-items: flex-start;
  gap: .5rem;
  margin: 0 1.25rem .75rem;
  background: #f0fdf4;
  border: 1px solid #c8e6c9;
  border-radius: 8px;
  padding: .65rem .875rem;
}
.oc__tip-ico  { flex-shrink: 0; font-size: .9rem; margin-top: .05rem; }
.oc__tip-text { font-size: .78rem; color: #1b5e20; line-height: 1.55; }

/* Acciones */
.oc__paso-actions {
  display: flex;
  align-items: center;
  gap: .5rem;
  padding: .25rem 1.25rem 1rem;
  flex-wrap: wrap;
}

.oc__btn-ir {
  display: inline-flex;
  align-items: center;
  gap: .35rem;
  padding: .45rem 1rem;
  background: #1b5e20;
  color: #fff;
  border-radius: 8px;
  font-size: .78rem;
  font-weight: 700;
  text-decoration: none;
  transition: background .15s;
  white-space: nowrap;
}
.oc__btn-ir:hover { background: #155224; }
.oc__btn-ir .bi { font-size: .7rem; }

.oc__btn-marcar {
  display: inline-flex;
  align-items: center;
  gap: .35rem;
  padding: .45rem 1rem;
  background: #f8fafc;
  border: 1.5px solid #e2e8f0;
  border-radius: 8px;
  font-size: .78rem;
  font-weight: 600;
  color: #64748b;
  cursor: pointer;
  transition: all .15s;
  white-space: nowrap;
}
.oc__btn-marcar:hover { background: #f0fdf4; border-color: #c8e6c9; color: #1b5e20; }
.oc__btn-marcar--done { background: #f0fdf4; border-color: #a8c5a0; color: #1b5e20; }
.oc__btn-marcar--done:hover { background: #fef2f2; border-color: #fecaca; color: #dc2626; }
</style>
