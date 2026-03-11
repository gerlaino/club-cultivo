class AddReprocannFieldsToSocios < ActiveRecord::Migration[7.2]
  def change
    add_column :socios, :reprocann_numero, :string
    add_column :socios, :reprocann_vencimiento, :date
    add_column :socios, :reprocann_adjunto, :string
  end
end
