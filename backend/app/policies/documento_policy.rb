class DocumentoPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      base = scope.where(club_id: user.club_id)
      if user.medico?
        pacientes_con_seg = Paciente.for_club(user.club_id).where(con_seguimiento_medico: true).pluck(:id)
        base.clinicos.where(paciente_id: pacientes_con_seg)
      elsif user.abogado?
        base.where(subido_por_id: user.id)
      elsif user.admin? || user.super_admin?
        base
      else
        scope.none
      end
    end
  end

  def index?
    user&.admin? || user&.medico? || user&.abogado?
  end

  def show?
    return false unless user.present?
    return true if user.admin? && record.club_id == user.club_id
    if user.medico?
      record.club_id == user.club_id &&
        record.categoria == 'clinico' &&
        (record.paciente_id.nil? || record.paciente&.con_seguimiento_medico?)
    elsif user.abogado?
      record.subido_por_id == user.id
    else
      false
    end
  end

  def create?
    return false unless user.present?
    return true if user.admin?
    if user.medico?
      params_tipo = record.tipo.to_s
      Documento::TIPOS_CLINICOS.include?(params_tipo)
    elsif user.abogado?
      true
    else
      false
    end
  end

  def update?
    user&.admin? && record.club_id == user.club_id
  end

  def destroy?
    user&.admin? && record.club_id == user.club_id
  end

  def subir_archivo?
    return true if user&.admin? && record.club_id == user.club_id
    user&.abogado? && record.club_id == user.club_id
  end

  def descargar?
    show?
  end
end
