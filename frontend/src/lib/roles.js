// Fuente única de la metadata de roles del club.
//
// Esto vivía duplicado en UsuariosView y en UsuarioDetail, con descripciones DISTINTAS del
// mismo rol según dónde mirara el admin ("Acceso total al club" vs "Acceso total al sistema",
// "Supervisa las sedes asignadas" vs "Supervisa las sedes que le asigne el admin"). Cuando el
// texto que explica un permiso depende de la pantalla, deja de ser confiable.
//
// El color sale de los tokens del design system (`--c-role-<rol>`), no de hexadecimales sueltos.

export const ROLES = [
  {
    value: 'admin', label: 'Administrador', icon: 'bi-shield-fill-check',
    desc: 'Acceso total: todos los módulos, el equipo y la configuración del club.',
    permisos: [
      { ok: true,  label: 'Todos los módulos' },
      { ok: true,  label: 'Equipo y configuración' },
      { ok: true,  label: 'Contabilidad' },
      { ok: true,  label: 'Aprobar pesajes y stock' },
    ],
  },
  {
    value: 'medico', label: 'Médico', icon: 'bi-heart-pulse-fill',
    desc: 'Pacientes, historia clínica, indicaciones y turnos. Sin acceso a producción.',
    sedes: { pide: false, hint: 'Sin sedes asignadas ve los pacientes de todo el club.' },
    permisos: [
      { ok: true,  label: 'Gestionar pacientes' },
      { ok: true,  label: 'Historia clínica e indicaciones' },
      { ok: true,  label: 'Turnos' },
      { ok: false, label: 'Cultivo y producción' },
    ],
  },
  {
    value: 'cultivador', label: 'Cultivador', icon: 'bi-flower1',
    desc: 'Salas, lotes y plantas de las sedes que le asignes. Sin acceso a pacientes.',
    // Sin sedes ve TODO el cultivo del club, no nada: es lo que necesita un club de una sola
    // sede, que si no tendría que asignársela a cada persona para que la app le sirva.
    sedes: { pide: false, hint: 'Sin sedes asignadas ve el cultivo de todo el club.' },
    permisos: [
      { ok: true,  label: 'Salas, lotes y plantas' },
      { ok: true,  label: 'Registrar ambiente y tareas' },
      { ok: true,  label: 'Genéticas' },
      { ok: false, label: 'Pacientes y dispensaciones' },
    ],
  },
  {
    value: 'supervisor', label: 'Supervisor', icon: 'bi-binoculars-fill',
    desc: 'Ve el cultivo de sus sedes y gestiona tareas. Además dispensa y maneja reservas.',
    sedes: { pide: false, hint: 'Sin sedes asignadas supervisa todo el club.' },
    permisos: [
      { ok: true,  label: 'Ver cultivo de sus sedes' },
      { ok: true,  label: 'Crear y asignar tareas' },
      { ok: true,  label: 'Dispensar y gestionar reservas' },
      { ok: false, label: 'Equipo y configuración' },
    ],
  },
  {
    value: 'manicura', label: 'Manicura', icon: 'bi-scissors',
    desc: 'Pesa los lotes en manicura que el admin le asigna. El peso lo confirma el admin.',
    permisos: [
      { ok: true,  label: 'Pesar los lotes asignados' },
      { ok: true,  label: 'Inventario de post-cosecha' },
      { ok: false, label: 'Confirmar su propio pesaje' },
      { ok: false, label: 'Pacientes y dispensaciones' },
    ],
  },
  {
    value: 'dispensador', label: 'Dispensador', icon: 'bi-bag-check-fill',
    desc: 'Dispensa, cobra y consulta el stock. Ve a los pacientes, sin su historia clínica.',
    sedes: { pide: false, hint: 'Sin sedes asignadas puede dispensar en todas.' },
    permisos: [
      { ok: true,  label: 'Registrar dispensaciones' },
      { ok: true,  label: 'Entregar reservas' },
      { ok: true,  label: 'Ver stock y pacientes' },
      { ok: false, label: 'Historia clínica y REPROCANN' },
    ],
  },
  {
    value: 'delivery', label: 'Delivery', icon: 'bi-bicycle',
    desc: 'Sus paquetes asignados: iniciar viaje, entregar y reportar fallos.',
    sedes: { pide: false, hint: 'Sin sedes asignadas recibe entregas de todas.' },
    permisos: [
      { ok: true,  label: 'Sus entregas asignadas' },
      { ok: true,  label: 'Firma de entrega' },
      { ok: false, label: 'Crear dispensaciones' },
      { ok: false, label: 'Cultivo y stock' },
    ],
  },
  {
    value: 'abogado', label: 'Abogado', icon: 'bi-briefcase-fill',
    desc: 'Informes legales y de REPROCANN. Lectura de pacientes, sin la historia clínica.',
    permisos: [
      { ok: true,  label: 'Informes legales y REPROCANN' },
      { ok: true,  label: 'Documentos' },
      { ok: true,  label: 'Trazabilidad' },
      { ok: false, label: 'Modificar datos' },
    ],
  },
  {
    value: 'auditor', label: 'Auditor', icon: 'bi-clipboard-data-fill',
    desc: 'Solo lectura de todo el club. No puede modificar absolutamente nada.',
    sedes: { pide: false, hint: 'Sin sedes asignadas ve los informes de todo el club.' },
    permisos: [
      { ok: true,  label: 'Lectura de todos los módulos' },
      { ok: true,  label: 'Todos los informes' },
      { ok: false, label: 'Crear o modificar' },
      { ok: false, label: 'Gestionar el equipo' },
    ],
  },
]

const POR_VALOR = Object.fromEntries(ROLES.map(r => [r.value, r]))

// Los roles que se OFRECEN al dar de alta a alguien. `ROLES` sigue teniendo los nueve porque se
// usa para mostrar el rol de un usuario que ya existe; esto es sólo la lista de alta.
//
// Quedan afuera supervisor, abogado y auditor: son casos puntuales que hoy no se ofrecen (y el
// backend los rechaza — ver `Club::ROLES_ALTA`). Un usuario que ya los tenga se sigue viendo
// normal; lo que no se puede es crear uno nuevo desde la pantalla.
export const ROLES_ALTA = ['admin', 'medico', 'cultivador', 'dispensador', 'manicura', 'delivery']

export function rolesParaAlta() {
  return ROLES.filter(r => ROLES_ALTA.includes(r.value))
}

export function rolInfo(valor) {
  return POR_VALOR[valor] || { value: valor, label: valor, icon: 'bi-person', desc: '', permisos: [] }
}

export function rolPermisos(valor) { return rolInfo(valor).permisos || [] }

// Qué roles se limitan por sede, y si la sede es obligatoria para que puedan trabajar.
export function rolSedes(valor)      { return rolInfo(valor).sedes || null }
export function rolPideSede(valor)   { return !!rolInfo(valor).sedes?.pide }
export function rolHintSede(valor)   { return rolInfo(valor).sedes?.hint || '' }

// Colores desde los tokens del DS, con un gris de respaldo.
export function rolColor(valor)  { return `var(--c-role-${valor}, #475569)` }
export function rolBg(valor)     { return `color-mix(in srgb, ${rolColor(valor)} 12%, white)` }
export function rolBorde(valor)  { return `color-mix(in srgb, ${rolColor(valor)} 30%, white)` }
export function rolEstilo(valor) {
  return { color: rolColor(valor), background: rolBg(valor), borderColor: rolBorde(valor) }
}
