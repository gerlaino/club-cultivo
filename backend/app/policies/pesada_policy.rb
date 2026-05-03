class PesadaPolicy < ApplicationPolicy
  ROLES_LECTURA = %w[admin cultivador manicura auditor].freeze
  ROLES_ESCRITURA = %w[admin cultivador manicura].freeze

  def index?  = mismo_club? && ROLES_LECTURA.include?(user&.role)
  def show?   = mismo_club? && ROLES_LECTURA.include?(user&.role)
  def create? = mismo_club? && ROLES_ESCRITURA.include?(user&.role)
  def destroy? = mismo_club? && admin?

  private

  def mismo_club?
    user.present? && record.lote.club_id == user.club_id
  end
end
