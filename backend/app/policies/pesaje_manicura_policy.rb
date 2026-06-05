class PesajeManicuraPolicy < ApplicationPolicy
  def index?   = mismo_club?
  def show?    = mismo_club?
  def create?  = mismo_club? && (admin? || supervisor? || manicura?)
  def enviar?  = mismo_club? && (admin? || supervisor? || es_manicurador_del_pesaje?)
  def confirmar? = mismo_club? && (admin? || supervisor?)

  private

  def mismo_club?
    user.club_id == record.club_id
  end

  def es_manicurador_del_pesaje?
    user.manicura? && record.manicurador_id == user.id
  end

  def admin?      = user.admin?
  def supervisor? = user.supervisor?
  def manicura?   = user.manicura?
end
