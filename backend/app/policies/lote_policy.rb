class LotePolicy < ApplicationPolicy
  def show?    = mismo_club?
  def create?  = mismo_club?
  def update?  = mismo_club?
  def destroy? = mismo_club?

  def avanzar_fase?
    mismo_club? && puede_avanzar_fase_actual?
  end

  def asignar_manicurador?
    mismo_club? && admin?
  end

  # Devolver a cosecha: el manicura asignado, o admin/supervisor.
  def devolver_manicura?
    return false unless mismo_club?
    admin? || supervisor? || (manicura? && record.manicurador_id == user.id)
  end

  class Scope < Scope
    def resolve
      base = scope.where(club_id: user.club_id)
      if user.manicura?
        # El manicura solo ve los lotes en manicura que el admin le asignó.
        base.where(estado: 'en_manicura', manicurador_id: user.id)
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
    when 'germinacion', 'esqueje', 'vegetativo', 'floracion', 'cosecha', 'secado'
      admin? || cultivador?
    else
      admin?
    end
  end

  def manicura?
    user&.role == 'manicura'
  end
end
