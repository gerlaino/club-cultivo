class ApplicationPolicy

  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  class Scope

    attr_reader :user, :scope

    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      scope.none
    end
  end

  def super_admin?
    user&.role == "super_admin"
  end

  def admin?
    user&.role == "admin"
  end

  def medico?
    user&.role == "medico"
  end

  def cultivador?
    user&.role == "cultivador"
  end

  def index?
    false
  end

  def show?
    false
  end

  def create?
    false
  end

  def update?
    false
  end

  def destroy?
    false
  end

end
