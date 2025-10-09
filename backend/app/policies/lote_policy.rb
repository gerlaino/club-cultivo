class LotePolicy < ApplicationPolicy
  def show?     = user.club_id == record.club_id
  def create?   = user.club_id == record.club_id
  def update?   = user.club_id == record.club_id
  def destroy?  = user.club_id == record.club_id

  class Scope < Scope
    def resolve
      scope.where(club_id: user.club_id)
    end
  end
end

