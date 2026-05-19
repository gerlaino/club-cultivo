class AddIaToClubs < ActiveRecord::Migration[7.1]
  def change
    add_column :clubs, :ia_habilitada,  :boolean, default: false, null: false
    add_column :clubs, :ia_tier,        :string,  default: 'basico', null: false
    add_column :clubs, :ia_limite_hora, :integer, default: 20,    null: false
  end
end
