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
      documentos: ['index', 'show', 'create', 'update', 'delete']
    },
    agricultor: {
      plantas: ['index', 'show', 'create', 'update', 'destroy'],
      lotes: ['index', 'show', 'create', 'update', 'destroy'],
      salas: ['index', 'show', 'create', 'update', 'destroy'],
      sedes: ['index', 'show', 'create', 'update', 'destroy'],
      geneticas: ['index', 'show'],
      plan_trabajo: ['index', 'show', 'create', 'update'],
      tareas: ['index', 'show', 'create', 'update', 'destroy'],
      reportes_cultivo: ['index', 'show'],
      documentos: ['index', 'show', 'create', 'update', 'delete']
    },
    cultivador: {
      plantas: ['index', 'show', 'update'],
      plant_activities: ['index', 'create', 'destroy'],
      lotes: ['index', 'show'],
      salas: ['index', 'show'],
      mediciones: ['index', 'create']
    },
    abogado: {
      socios: ['index', 'show'],
      reportes_legales: ['index', 'show'],
      informes_reprocann: ['index', 'show'],
      trazabilidad: ['index', 'show'],
      movimientos_contables: ['index', 'show', 'create', 'update', 'destroy'],
      informe_semestral: ['show'],
      tareas: ['index', 'show', 'create', 'update', 'destroy'],
    },
    auditor: {
      read_only: true,
      informes_reprocann: ['index', 'show'],
      reportes_oficiales: ['index', 'show'],
      trazabilidad: ['index', 'show'],
      plantas: ['index', 'show'],
      lotes: ['index', 'show'],
      socios: ['index', 'show'],
      movimientos_contables: ['index', 'show'],
      informe_semestral: ['show'],
    },
    socio: {
      mi_perfil: ['show', 'update'],
      mis_dispensaciones: ['index', 'show'],
      eventos: ['index', 'show']
    }
  }

  const userRole = computed(() => auth.user?.role)

  const can = (resource, action) => {
    const role = userRole.value
    if (!role) return false
    if (role === 'admin') return true

    if (role === 'auditor' && PERMISSIONS.auditor.read_only && action === 'show') {
      return true
    }

    const rolePermissions = PERMISSIONS[role]
    if (!rolePermissions) return false
    if (rolePermissions.all) return true

    const resourcePermissions = rolePermissions[resource]
    if (!resourcePermissions) return false

    return resourcePermissions.includes(action)
  }

  const isAdmin      = computed(() => userRole.value === 'admin')
  const isMedico     = computed(() => userRole.value === 'medico')
  const isAgricultor = computed(() => userRole.value === 'agricultor')
  const isCultivador = computed(() => userRole.value === 'cultivador')
  const isAbogado    = computed(() => userRole.value === 'abogado')
  const isAuditor    = computed(() => userRole.value === 'auditor')
  const isSocio      = computed(() => userRole.value === 'socio')

  return {
    can,
    isAdmin,
    isMedico,
    isAgricultor,
    isCultivador,
    isAbogado,
    isAuditor,
    isSocio
  }
}
