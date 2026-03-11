class AddStateToLotes < ActiveRecord::Migration[7.2]
  def change
    add_column :lotes, :state, :string
  end
end
