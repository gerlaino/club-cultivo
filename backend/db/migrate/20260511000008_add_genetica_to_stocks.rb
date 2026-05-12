class AddGeneticaToStocks < ActiveRecord::Migration[7.1]
  def change
    add_reference :stocks, :genetica, null: true, foreign_key: true
  end
end
