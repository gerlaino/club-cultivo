class UnifySalaKindCosechadoToCosecha < ActiveRecord::Migration[7.1]
  def up
    Sala.unscoped.where(kind: 'cosechado').update_all(kind: 'cosecha')
    Sala.unscoped.where(tipo: 'cosechado').update_all(tipo: 'cosecha')
  end

  def down
    # No revertimos: cosecha es el valor canónico
  end
end
