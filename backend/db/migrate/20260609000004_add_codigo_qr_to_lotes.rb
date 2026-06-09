class AddCodigoQrToLotes < ActiveRecord::Migration[7.0]
  def up
    add_column :lotes, :codigo_qr, :string
    add_index  :lotes, :codigo_qr, unique: true, where: "codigo_qr IS NOT NULL"

    # Backfill para lotes existentes
    Lote.where(codigo_qr: nil).find_each do |lote|
      lote.update_column(:codigo_qr, "L-#{lote.club_id}-#{lote.created_at.to_i}-#{SecureRandom.hex(4)}")
    end
  end

  def down
    remove_index  :lotes, :codigo_qr
    remove_column :lotes, :codigo_qr
  end
end
