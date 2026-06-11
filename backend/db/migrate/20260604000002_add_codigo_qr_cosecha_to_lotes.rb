class AddCodigoQrCosechaToLotes < ActiveRecord::Migration[7.1]
  def change
    add_column :lotes, :codigo_qr_cosecha, :string
    add_index  :lotes, :codigo_qr_cosecha, unique: true
  end
end
