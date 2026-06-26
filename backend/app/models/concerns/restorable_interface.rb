# Interfaz uniforme de soft-delete/restauración para la papelera, que abstrae las dos
# implementaciones que conviven en el código: la gema `paranoia` (acts_as_paranoid) y el
# patrón manual (deleted_at + default_scope) de los modelos legacy (club/lote/plant/sala/sede).
# La papelera y los Restorers hablan SOLO con esta interfaz, sin saber cuál usa cada modelo.
module RestorableInterface
  extend ActiveSupport::Concern

  class_methods do
    # Scope de registros borrados, salteando el default_scope que normalmente los oculta.
    def soft_deleted_records
      if respond_to?(:only_deleted) # paranoia
        only_deleted
      else                          # manual: default_scope filtra deleted_at: nil
        unscope(where: :deleted_at).where.not(deleted_at: nil)
      end
    end

    def find_soft_deleted(id)
      soft_deleted_records.find(id)
    end
  end

  def soft_deleted?
    deleted_at.present?
  end

  # Restaura el registro (y sus dependientes borrados en la misma operación, si la gema lo
  # soporta). NO valida efectos colaterales: eso es responsabilidad de los Restorers (Fase 3).
  def restore_record!
    if self.class.respond_to?(:restore) # paranoia
      self.class.restore(id, recursive: true)
    else                                # manual
      update_column(:deleted_at, nil)
    end
    self
  end
end
