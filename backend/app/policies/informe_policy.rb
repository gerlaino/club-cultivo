class InformePolicy < ApplicationPolicy
  def show?
    user&.admin? || user&.auditor?
  end
end
