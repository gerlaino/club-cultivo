class PlantPolicy < ApplicationPolicy
  def show?    = record.lote.club_id == user.club_id
  def update?  = show?
  def destroy? = show?
end
