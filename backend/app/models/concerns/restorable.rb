# Soft-delete estándar para los modelos del set restaurable que NO tenían borrado lógico.
# Suma la gema paranoia (`.destroy` borra lógico, `restore`, `with_deleted`, `only_deleted`),
# el rastro de quién borró (`deleted_by`) y la interfaz uniforme de la papelera.
#
# Los modelos legacy con soft-delete propio (club/lote/plant/sala/sede) NO incluyen esto
# —ya tienen su default_scope manual— solo incluyen RestorableInterface.
module Restorable
  extend ActiveSupport::Concern
  include RestorableInterface

  included do
    acts_as_paranoid
    belongs_to :deleted_by, class_name: "User", optional: true
  end
end
