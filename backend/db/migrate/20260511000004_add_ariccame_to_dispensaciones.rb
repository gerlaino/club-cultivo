class AddAriccameToDispensaciones < ActiveRecord::Migration[7.2]
  def change
    add_column :dispensaciones, :ariccame_reportada, :boolean, default: false, null: false
    add_index  :dispensaciones, :ariccame_reportada, where: 'ariccame_reportada = false'
  end
end
