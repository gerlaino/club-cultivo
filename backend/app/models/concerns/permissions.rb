module Permissions
  extend ActiveSupport::Concern

  PERMISSIONS = {
    admin: {
      all: true
    },
    medico: {
      socios: [:index, :show, :create, :update],
      socio_notas: [:index, :create, :destroy],
      indicaciones: [:index, :show, :create, :update],
      dispensaciones: [:index, :show],
      reportes_medicos: [:index, :show]
    },
    cultivador: {
      plantas: [:index, :show, :create, :update, :destroy],
      plant_activities: [:index, :create, :destroy],
      lotes: [:index, :show, :create, :update, :destroy],
      salas: [:index, :show, :create, :update, :destroy],
      geneticas: [:index, :show],
      plan_trabajo: [:index, :show, :create, :update],
      reportes_cultivo: [:index, :show],
      mediciones: [:index, :create],
      dispositivos: [:index, :show, :create, :update, :destroy],
      lecturas_ambientales: [:index, :show, :create, :destroy],
      setpoints_fase: [:index, :show, :create, :update, :destroy],
      reglas_ambientales: [:index, :show, :create, :update, :destroy],
      alertas: [:index, :show, :update],
    },
    supervisor: {
      salas: [:index, :show],
      lotes: [:index, :show],
      plantas: [:index, :show],
      plant_activities: [:index, :show],
      sedes: [:index, :show],
      geneticas: [:index, :show],
      tareas: [:index, :show, :create, :update, :destroy],
    },
    abogado: {
      socios: [:index, :show],
      reportes_legales: [:index, :show],
      informes_reprocann: [:index, :show],
      trazabilidad: [:index, :show]
    },
    auditor: {
      read_only: true,
      informes_reprocann: [:index, :show],
      reportes_oficiales: [:index, :show],
      trazabilidad: [:index, :show],
      plantas: [:index, :show],
      lotes: [:index, :show],
      socios: [:index, :show],
      lecturas_ambientales: [:index, :show],
      alertas: [:index, :show],
    },
    dispensador: {
      socios: [:index, :show],
      dispensaciones: [:index, :show, :create],
      sede_inventario: [:index, :show],
      socio_notas: [:index, :create],
      sedes: [:index, :show],
      tareas: [:index, :show],
    },
    manicura: {
      sede_inventario: [:index, :show],
      inventario_movimientos: [:index, :show, :create],
      lotes: [:index, :show],
      geneticas: [:index, :show],
      sedes: [:index, :show],
      manicura: [:access],
    },
    paciente: {
      mi_perfil: [:show, :update],
      mis_dispensaciones: [:index, :show],
      eventos: [:index, :show]
    },
    delivery: {
      dispensaciones: [:index, :show, :create],
      socios: [:index, :show],
      sedes: [:index, :show],
    }
  }.freeze

  def can?(resource, action)
    return true if admin?
    return true if auditor? && PERMISSIONS[:auditor][:read_only] && action.to_sym == :show

    role_permissions = PERMISSIONS[role.to_sym]
    return false unless role_permissions
    return true if role_permissions[:all]

    resource_permissions = role_permissions[resource.to_sym]
    return false unless resource_permissions

    resource_permissions.include?(action.to_sym)
  end

  def admin?
    role == 'admin'
  end

  def medico?
    role == 'medico'
  end

  def cultivador?
    role == 'cultivador'
  end

  def supervisor?
    role == 'supervisor'
  end

  def abogado?
    role == 'abogado'
  end

  def auditor?
    role == 'auditor'
  end

  def socio?
    role == 'paciente'
  end

  def dispensador?
    role == 'dispensador'
  end

  def manicura?
    role == 'manicura'
  end

  def paciente?
    role == 'paciente'
  end

  def delivery?
    role == 'delivery'
  end

  def super_admin?
    role == 'super_admin'
  end

  def admin_or_cultivador?
    admin? || cultivador?
  end
end