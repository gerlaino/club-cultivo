class AddResponsableToSalas < ActiveRecord::Migration[7.1]
  def change
    add_reference :salas, :responsable, null: true, foreign_key: { to_table: :users }
  end
end
