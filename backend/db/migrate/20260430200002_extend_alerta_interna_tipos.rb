class ExtendAlertaInternaTipos < ActiveRecord::Migration[7.2]
  def up
    # Nada que migrar en DB — los TIPOS son constante del modelo.
    # Esta migración documenta que se extendieron los tipos válidos.
    # Los tipos nuevos: manicura_aprobacion_pendiente, manicura_aprobada, manicura_rechazada.
  end

  def down; end
end
