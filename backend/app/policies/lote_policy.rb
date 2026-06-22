class LotePolicy < ApplicationPolicy
  def show?    = mismo_club?
  def create?  = mismo_club?
  def update?  = mismo_club?
  def destroy? = mismo_club?

  def avanzar_fase?
    mismo_club? && puede_avanzar_fase_actual?
  end

  def cerrar_curado?
    mismo_club? && admin?
  end

  def asignar_manicurador?
    mismo_club? && admin?
  end

  class Scope < Scope
    def resolve
      base = scope.where(club_id: user.club_id)
      if user.manicura?
        # Flujo único: el manicura ve sus lotes en manicura y los de secado sin asignar.
        base.where(estado: 'en_manicura', manicurador_id: user.id)
           .or(base.where(estado: 'secado'))
      else
        base
      end
    end
  end

  private

  def mismo_club?
    user.club_id == record.club_id
  end

  def puede_avanzar_fase_actual?
    case record.estado
    when 'semilla', 'esqueje', 'vegetativo', 'floracion', 'cosecha', 'secado'
      admin? || cultivador?
    else
      admin?
    end
  end

  def manicura?
    user&.role == 'manicura'
  end
end
