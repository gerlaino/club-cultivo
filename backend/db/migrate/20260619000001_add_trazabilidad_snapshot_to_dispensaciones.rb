class AddTrazabilidadSnapshotToDispensaciones < ActiveRecord::Migration[7.2]
  # Snapshot inmutable de trazabilidad: el código de lote y la genética se copian al
  # crear la dispensación. Así el registro queda auto-contenido y sigue siendo trazable
  # aunque más adelante se elimine el stock de origen (que con dependent: :nullify ya
  # conserva la dispensación, pero perdería el FK al lote).
  def change
    change_table :dispensaciones, bulk: true do |t|
      t.string :lote_codigo
      t.string :genetica_nombre
    end
  end
end
