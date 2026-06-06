class AddUmbralStockGToClubs < ActiveRecord::Migration[7.2]
  def change
    add_column :clubs, :umbral_stock_g, :integer, default: 50, null: false
  end
end
