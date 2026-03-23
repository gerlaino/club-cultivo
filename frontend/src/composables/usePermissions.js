import { computed } from 'vue'
import { useAuthStore } from '../stores/auth'

export function usePermissions() {
  const auth = useAuthStore()

  const PERMISSIONS = {
    admin: {
      all: true
    },
    medico: {
      socios: ['index', 'show', 'create', 'update'],
      socio_notas: ['index', 'create', 'destroy'],
      indicaciones: ['index', 'show', 'create', 'update'],
      dispensaciones: ['index', 'show'],
      reportes_medicos: ['index', 'show']
    },
    agricultor: {
      plantas: ['index', 'show', 'create', 'update', 'destroy'],
      lotes: ['index', 'show', 'create', 'update', 'destroy'],
      salas: ['index', 'show', 'create', 'update', 'destroy'],
      sedes: ['index', 'show', 'create', 'update', 'destroy'],
      geneticas: ['index', 'show'],
      plan_trabajo: ['index', 'show', 'create', 'update'],
      reportes_cultivo: ['index', 'show']
    },
    cultivador: {
      plantas: ['index', 'show', 'update'],
      plant_activities: ['index', 'create', 'destroy'],
      lotes: ['index', 'show'],
      salas: ['index', 'show'],
      sedes: ['index', 'show'],
      mediciones: ['index', 'create']
    },
    abogado: {
      socios: ['index', 'show'],
      reportes_legales: ['index', 'show'],
      informes_reprocann: ['index', 'show'],
      trazabilidad: ['index', 'show'],
      movimientos_contables: ['index', 'show', 'create', 'update', 'destroy'],
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
    },
    socio: {
      mi_perfil: ['show', 'update'],
      mis_dispensaciones: ['index', 'show'],
      eventos: ['index', 'show']
    }
  }

  const can = (resource, action) => {
    const userRole = auth.user?.role
    if (!userRole) return false
    if (userRole === 'admin') return true

    // Auditor puede ver todo (read-only)
    if (userRole === 'auditor' && PERMISSIONS.auditor.read_only && action === 'show') {
      return true
    }

    const rolePermissions = PERMISSIONS[userRole]
    if (!rolePermissions) return false
    if (rolePermissions.all) return true

    const resourcePermissions = rolePermissions[resource]
    if (!resourcePermissions) return false

    return resourcePermissions.includes(action)
  }

  const isAdmin = computed(() => auth.user?.role === 'admin')
  const isMedico = computed(() => auth.user?.role === 'medico')
  const isAgricultor = computed(() => auth.user?.role === 'agricultor')
  const isCultivador = computed(() => auth.user?.role === 'cultivador')
  const isAbogado = computed(() => auth.user?.role === 'abogado')
  const isAuditor = computed(() => auth.user?.role === 'auditor')
  const isSocio = computed(() => auth.user?.role === 'socio')

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
