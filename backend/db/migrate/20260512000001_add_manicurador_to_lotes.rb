class AddManicuradorToLotes < ActiveRecord::Migration[7.2]
  def change
    add_reference :lotes, :manicurador, foreign_key: { to_table: :users }, null: true
  end
end
