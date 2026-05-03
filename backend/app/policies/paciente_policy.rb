class PacientePolicy < ApplicationPolicy
  ROLES_LECTURA = %w[admin medico dispensador].freeze
  ROLES_CLINICA = %w[admin medico].freeze

  class Scope < ApplicationPolicy::Scope
    def resolve
      base = scope.for_club(user.club_id)
      if user.medico?
        base.where(es_paciente: true, con_seguimiento_medico: true)
      elsif user.dispensador?
        base.where(es_paciente: true)
      else
        base
      end
    end
  end

  def index?
    mismo_club? && ROLES_LECTURA.include?(user&.role)
  end

  def show?
    mismo_club? && ROLES_LECTURA.include?(user&.role)
  end

  def create?
    mismo_club? && (admin? || medico? || user&.dispensador?)
  end

  def update?
    mismo_club? && ROLES_CLINICA.include?(user&.role)
  end

  def destroy?
    mismo_club? && admin?
  end

  def update_notas_clinicas?
    mismo_club? && ROLES_CLINICA.include?(user&.role)
  end

  def ver_notas_clinicas?
    mismo_club? && ROLES_CLINICA.include?(user&.role)
  end

  def timeline?
    mismo_club? && ROLES_CLINICA.include?(user&.role)
  end

  private

  def mismo_club?
    user.present? && record.club_id == user.club_id
  end
end
