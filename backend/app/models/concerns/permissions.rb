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
    agricultor: {
      plantas: [:index, :show, :create, :update, :destroy],
      lotes: [:index, :show, :create, :update, :destroy],
      salas: [:index, :show, :create, :update, :destroy],
      geneticas: [:index, :show],
      plan_trabajo: [:index, :show, :create, :update],
      reportes_cultivo: [:index, :show]
    },
    cultivador: {
      plantas: [:index, :show, :update],
      plant_activities: [:index, :create, :destroy],
      lotes: [:index, :show],
      salas: [:index, :show],
      mediciones: [:index, :create]
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
      socios: [:index, :show]
    },
    socio: {
      mi_perfil: [:show, :update],
      mis_dispensaciones: [:index, :show],
      eventos: [:index, :show]
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

  def agricultor?
    role == 'agricultor'
  end

  def cultivador?
    role == 'cultivador'
  end

  def abogado?
    role == 'abogado'
  end

  def auditor?
    role == 'auditor'
  end

  def socio?
    role == 'socio'
  end
end