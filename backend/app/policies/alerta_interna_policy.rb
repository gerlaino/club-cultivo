class AlertaInternaPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless user&.admin?
      scope.where(club_id: user.club_id)
    end
  end

  def index?
    user&.admin? && record == AlertaInterna
  end

  def show?
    user&.admin? && record.club_id == user.club_id
  end

  def marcar_leida?
    user&.admin? && record.club_id == user.club_id
  end
end
