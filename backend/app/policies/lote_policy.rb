class LotePolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      scope.where(club_id: user.club_id)
    end
  end

  def index?
    logged_in?
  end

  def show?
    same_club?
  end

  def create?
    super_admin? || admin? || cultivador?
  end

  def update?
    super_admin? || admin? || cultivador?
  end

  def destroy?
    super_admin? || admin?
  end

  private
  def logged_in?
    user.present?
  end

  def same_club?
    logged_in? && record.club_id == user.club_id
  end
end
