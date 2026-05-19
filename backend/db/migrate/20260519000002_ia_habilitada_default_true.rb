class IaHabilitadaDefaultTrue < ActiveRecord::Migration[7.1]
  def up
    change_column_default :clubs, :ia_habilitada, from: false, to: true
    Club.update_all(ia_habilitada: true)
  end

  def down
    change_column_default :clubs, :ia_habilitada, from: true, to: false
  end
end
