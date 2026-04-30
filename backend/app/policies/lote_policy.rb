class LotePolicy < ApplicationPolicy
  def show?    = mismo_club?
  def create?  = mismo_club?
  def update?  = mismo_club?
  def destroy? = mismo_club?

  def avanzar_fase?
    mismo_club? && puede_avanzar_fase_actual?
  end

  def cerrar_curado?
    mismo_club? && (admin? || manicura?)
  end

  class Scope < Scope
    def resolve
      scope.where(club_id: user.club_id)
    end
  end

  private

  def mismo_club?
    user.club_id == record.club_id
  end

  def puede_avanzar_fase_actual?
    case record.estado
    when 'vegetativo', 'floracion'
      admin? || cultivador?
    when 'cosecha', 'secado'
      admin? || cultivador? || manicura?
    else
      admin?
    end
  end

  def manicura?
    user&.role == 'manicura'
  end
end
