import { computed } from 'vue'
import { useAuthStore } from '../stores/auth'

export function usePermissions() {
  const auth = useAuthStore()

  const PERMISSIONS = {
    admin: { all: true },

    medico: {
      socios: ['index', 'show', 'create', 'update'],
      socio_notas: ['index', 'create', 'destroy'],
      indicaciones: ['index', 'show', 'create', 'update'],
      dispensaciones: ['index', 'show'],
      tareas: ['index', 'show'],
      reportes_medicos: ['index', 'show'],
      documentos: ['index', 'show', 'create', 'update', 'delete'],
    },

    supervisor: {
      salas: ['index', 'show'],
      lotes: ['index', 'show'],
      plantas: ['index', 'show'],
      plant_activities: ['index', 'show'],
      sedes: ['index', 'show'],
      geneticas: ['index', 'show'],
      tareas: ['index', 'show', 'create', 'update', 'destroy'],
    },

    cultivador: {
      plantas: ['index', 'show', 'create', 'update', 'destroy'],
      plant_activities: ['index', 'create', 'destroy'],
      lotes: ['index', 'show', 'create', 'update', 'destroy'],
      salas: ['index', 'show', 'create', 'update', 'destroy'],
      geneticas: ['index', 'show'],
      plan_trabajo: ['index', 'show', 'create', 'update'],
      tareas: ['index', 'show', 'create', 'update', 'destroy'],
      reportes_cultivo: ['index', 'show'],
      mediciones: ['index', 'create'],
      ambiente: ['index', 'show'],
      lecturas_ambientales: ['index', 'show', 'create'],
      registros_ambientales: ['index', 'create', 'destroy'],
      setpoints_fase: ['index', 'show'],
      alertas: ['index', 'show'],
    },

    abogado: {
      // Solo documentos del club — sin acceso clínico ni productivo
      documentos: ['index', 'show', 'create'],
    },

    auditor: {
      // Solo lectura absoluta
      read_only: true,
      informes_reprocann: ['index', 'show'],
      reportes_oficiales: ['index', 'show'],
      trazabilidad: ['index', 'show'],
      plantas: ['index', 'show'],
      lotes: ['index', 'show'],
      socios: ['index', 'show'],
      movimientos_contables: ['index', 'show'],
      informe_semestral: ['show'],
      documentos: ['index', 'show'],
    },

    dispensador: {
      socios: ['index', 'show'],
      dispensaciones: ['index', 'show', 'create'],
      sede_inventario: ['index', 'show'],
      sedes: ['index', 'show'],
      tareas: ['index', 'show'],
      // Sin acceso a notas, indicaciones ni documentos del paciente
    },

    manicura: {
      sede_inventario: ['index', 'show'],
      inventario_movimientos: ['index', 'show', 'create'],
      lotes: ['index', 'show'],
      plantas: ['index', 'show', 'update'],
      geneticas: ['index', 'show'],
      sedes: ['index', 'show'],
      tareas: ['index', 'show'],
      manicura: ['access'],
    },

    paciente: {
      mi_perfil: ['show', 'update'],
      mis_dispensaciones: ['index', 'show'],
      eventos: ['index', 'show'],
    },

    delivery: {
      // Sin acceso a listado general de pacientes — solo via pedido asignado (futuro)
      dispensaciones: ['index', 'show'],
      sedes: ['index', 'show'],
    },

    socio: {
      mi_perfil: ['show', 'update'],
      mis_dispensaciones: ['index', 'show'],
      eventos: ['index', 'show'],
    },
  }

  const userRole = computed(() => auth.user?.role)

  const can = (resource, action) => {
    const role = userRole.value
    if (!role) return false
    if (role === 'admin' || role === 'super_admin') return true

    if (role === 'auditor' && action === 'show') return true

    const rolePermissions = PERMISSIONS[role]
    if (!rolePermissions) return false
    if (rolePermissions.all) return true

    const resourcePermissions = rolePermissions[resource]
    if (!resourcePermissions) return false

    return resourcePermissions.includes(action)
  }

  const isAdmin       = computed(() => userRole.value === 'admin')
  const isSuperAdmin  = computed(() => userRole.value === 'super_admin')
  const isMedico      = computed(() => userRole.value === 'medico')
  const isCultivador  = computed(() => userRole.value === 'cultivador')
  const isSupervisor  = computed(() => userRole.value === 'supervisor')
  const isAbogado     = computed(() => userRole.value === 'abogado')
  const isAuditor     = computed(() => userRole.value === 'auditor')
  const isDispensador = computed(() => userRole.value === 'dispensador')
  const isManicura    = computed(() => userRole.value === 'manicura')
  const isPaciente    = computed(() => userRole.value === 'paciente')
  const isDelivery    = computed(() => userRole.value === 'delivery')
  const isSocio       = computed(() => userRole.value === 'socio')

  return {
    can,
    isAdmin,
    isSuperAdmin,
    isMedico,
    isCultivador,
    isSupervisor,
    isAbogado,
    isAuditor,
    isDispensador,
    isManicura,
    isPaciente,
    isDelivery,
    isSocio,
  }
}
