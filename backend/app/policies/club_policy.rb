class ClubPolicy < ApplicationPolicy
  def show?
    user.present?
  end

  def update?
    user.role.in?(%w[admin super_admin])
  end

  def upload_logo?
    update?
  end
end
